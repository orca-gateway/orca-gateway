// C17.5/K (drift): the Google map's Kotlin props, params and trigger names,
// committed as generated in its Android package
// (plugins/orca_google_map/android/google-map/src/main/kotlin/com/
// orcagateway/plugins/googlemap/OrcaGoogleMapTypes.kt), which the package's
// Gradle build compiles and GoogleMapPropsTest pins against the Flutter
// plugin, are exactly what `orca plugin generate --lang kotlin --types-only
// --package com.orcagateway.plugins.googlemap` writes for
// plugins/orca_google_map/orca_plugin.yaml today.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:orca_gateway_cli/src/commands/plugin_generate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Paths from the cli package root (tests run from cli/).
final _manifest = p.normalize(
    p.absolute('..', 'plugins', 'orca_google_map', 'orca_plugin.yaml'));
final _committed = p.normalize(p.absolute(
    '..',
    'plugins',
    'orca_google_map',
    'android',
    'google-map',
    'src',
    'main',
    'kotlin',
    'com',
    'orcagateway',
    'plugins',
    'googlemap',
    'OrcaGoogleMapTypes.kt'));

const _regenerate = 'Regenerate it from cli/: dart run bin/orca.dart plugin '
    'generate --lang kotlin --types-only '
    '--package com.orcagateway.plugins.googlemap '
    '--manifest ../plugins/orca_google_map/orca_plugin.yaml '
    '--output ../plugins/orca_google_map/android/google-map/src/main/'
    'kotlin/com/orcagateway/plugins/googlemap';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('orca_cli_map_kotlin_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('C17.5/K the committed Kotlin Google map types are the generator '
      'output byte for byte', () async {
    final runner = CommandRunner<void>('orca', 'test')
      ..addCommand(PluginGenerateCommand(root: tempDir.path));
    await runner.run([
      'generate', '--lang', 'kotlin', '--types-only', //
      '--package', 'com.orcagateway.plugins.googlemap',
      '--manifest', _manifest,
    ]);
    final out = Directory(p.join(tempDir.path, 'generated'));
    expect([for (final f in out.listSync()) p.basename(f.path)],
        ['OrcaGoogleMapTypes.kt']);
    final generated =
        File(p.join(out.path, 'OrcaGoogleMapTypes.kt')).readAsStringSync();

    // Strict UTF-8 on both sides, so equal strings are equal bytes; a string
    // mismatch prints a readable diff.
    final committed = File(_committed);
    expect(committed.existsSync(), isTrue,
        reason: 'No types at $_committed. $_regenerate');
    expect(committed.readAsStringSync(), generated,
        reason: 'The committed types drifted from the generator. $_regenerate');
  });
}
