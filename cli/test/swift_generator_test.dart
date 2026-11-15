// C16.6 (Swift drift): the google_map Swift stub committed in the SwiftUI
// test target (sdk-swift/Tests/OrcaGatewayTests/Generated), which the Swift
// suite compiles and exercises, is exactly what `orca plugin generate --lang
// swift` writes for plugins/orca_google_map/orca_plugin.yaml today.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:orca_gateway_cli/src/commands/plugin_generate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Paths from the cli package root (tests run from cli/).
final _googleMap = p.normalize(
    p.absolute('..', 'plugins', 'orca_google_map', 'orca_plugin.yaml'));
final _committed = p.normalize(p.absolute('..', 'sdk-swift', 'Tests',
    'OrcaGatewayTests', 'Generated', 'OrcaGoogleMapPlugin.swift'));

const _regenerate = 'Regenerate it from cli/: dart run bin/orca.dart plugin '
    'generate --lang swift --manifest ../plugins/orca_google_map/orca_plugin.yaml '
    '--output ../sdk-swift/Tests/OrcaGatewayTests/Generated';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('orca_cli_swift_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('C16.6 the committed Swift google_map stub is the generator output '
      'byte for byte', () async {
    final runner = CommandRunner<void>('orca', 'test')
      ..addCommand(PluginGenerateCommand(root: tempDir.path));
    await runner.run(['generate', '--lang', 'swift', '--manifest', _googleMap]);
    final generated = File(
            p.join(tempDir.path, 'generated', 'OrcaGoogleMapPlugin.swift'))
        .readAsStringSync();

    // Strict UTF-8 on both sides, so equal strings are equal bytes; a string
    // mismatch prints a readable diff.
    final committed = File(_committed);
    expect(committed.existsSync(), isTrue,
        reason: 'No stub at $_committed. $_regenerate');
    expect(committed.readAsStringSync(), generated,
        reason: 'The committed stub drifted from the generator. $_regenerate');
  });
}
