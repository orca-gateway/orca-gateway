// C16.6 (Kotlin drift): the google_map Kotlin stub committed in the Android
// SDK's test source set (sdk-kotlin/sdk/src/test/kotlin/orca/plugins), which
// the Gradle build compiles and GeneratedPluginTest exercises, is exactly what
// `orca plugin generate --lang kotlin` writes for
// plugins/orca_google_map/orca_plugin.yaml today (default package
// orca.plugins).

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:orca_gateway_cli/src/commands/plugin_generate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Paths from the cli package root (tests run from cli/).
final _googleMap = p.normalize(
    p.absolute('..', 'plugins', 'orca_google_map', 'orca_plugin.yaml'));
final _committed = p.normalize(p.absolute('..', 'sdk-kotlin', 'sdk', 'src',
    'test', 'kotlin', 'orca', 'plugins', 'OrcaGoogleMapPlugin.kt'));

const _regenerate = 'Regenerate it from cli/: dart run bin/orca.dart plugin '
    'generate --lang kotlin --manifest ../plugins/orca_google_map/orca_plugin.yaml '
    '--output ../sdk-kotlin/sdk/src/test/kotlin/orca/plugins';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('orca_cli_kotlin_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('C16.6 the committed Kotlin google_map stub is the generator output '
      'byte for byte', () async {
    final runner = CommandRunner<void>('orca', 'test')
      ..addCommand(PluginGenerateCommand(root: tempDir.path));
    await runner
        .run(['generate', '--lang', 'kotlin', '--manifest', _googleMap]);
    final generated =
        File(p.join(tempDir.path, 'generated', 'OrcaGoogleMapPlugin.kt'))
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
