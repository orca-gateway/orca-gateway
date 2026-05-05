import 'dart:io';

import 'package:orca_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_cli/src/patchers/plist_patcher.dart';
import 'package:test/test.dart';

/// Minimal valid Info.plist stub. Only contains what `PlistPatcher.apply`
/// needs: a root `<dict>` it can splice into.
const _infoPlistStub = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleName</key>
\t<string>Runner</string>
</dict>
</plist>
''';

void main() {
  group('PlistPatcher', () {
    late Directory tmp;
    late File plistFile;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('plist_patcher_test_');
      plistFile = File('${tmp.path}/Info.plist');
      plistFile.writeAsStringSync(_infoPlistStub);
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('type: dict with a nested YamlMap value renders a nested <dict>',
        () {
      // This is the exact shape orca_video_player/orca_plugin.yaml ships —
      // NSAppTransportSecurity: { NSAllowsArbitraryLoads: true } — which
      // previously crashed the add command with "YamlMap is not a subtype
      // of String".
      final cfg = IosConfig(
        plist: [
          PlistEntry(
            key: 'NSAppTransportSecurity',
            type: 'dict',
            value: {'NSAllowsArbitraryLoads': true},
          ),
        ],
      );

      PlistPatcher.apply(plistFile.path, 'orca_video_player', cfg);

      final out = plistFile.readAsStringSync();
      // Outer key + nested dict wrapper
      expect(out, contains('<key>NSAppTransportSecurity</key>'));
      expect(out, contains('<dict>'));
      // Nested key + bool child rendered via inferred-type path
      expect(out, contains('<key>NSAllowsArbitraryLoads</key>'));
      expect(out, contains('<true/>'));
    });

    test('type: string entries still render as scalars (back-compat)', () {
      final cfg = IosConfig(
        plist: [
          PlistEntry(
            key: 'NSMicrophoneUsageDescription',
            type: 'string',
            value: 'Record voice notes',
          ),
        ],
      );
      PlistPatcher.apply(plistFile.path, 'orca_voice_recorder', cfg);
      final out = plistFile.readAsStringSync();
      expect(out, contains('<key>NSMicrophoneUsageDescription</key>'));
      expect(out, contains('<string>Record voice notes</string>'));
    });

    test('type: bool accepts raw YAML boolean (not just "true" string)', () {
      final cfg = IosConfig(
        plist: [
          PlistEntry(key: 'UIRequiresFullScreen', type: 'bool', value: true),
        ],
      );
      PlistPatcher.apply(plistFile.path, 'plugin_a', cfg);
      expect(plistFile.readAsStringSync(), contains('<true/>'));
    });

    test('type: array with YamlList of strings renders multiple entries', () {
      final cfg = IosConfig(
        plist: [
          PlistEntry(
            key: 'UIBackgroundModes',
            type: 'array',
            value: ['audio', 'location'],
          ),
        ],
      );
      PlistPatcher.apply(plistFile.path, 'plugin_b', cfg);
      final out = plistFile.readAsStringSync();
      expect(out, contains('<array>'));
      expect(out, contains('<string>audio</string>'));
      expect(out, contains('<string>location</string>'));
    });
  });
}
