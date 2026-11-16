// C17.5/S (Swift drift): the voice recorder's Swift props, params and trigger
// names, committed in its SwiftPM package
// (plugins/orca_voice_recorder/ios/Sources/OrcaVoiceRecorder/Generated), are
// exactly what `orca plugin generate --lang swift --types-only` writes for
// plugins/orca_voice_recorder/orca_plugin.yaml today. The package's
// VoiceRecorderPropsTests.swift pins what those types read.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:orca_gateway_cli/src/commands/plugin_generate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Paths from the cli package root (tests run from cli/).
final _manifest = p.normalize(
    p.absolute('..', 'plugins', 'orca_voice_recorder', 'orca_plugin.yaml'));
final _committed = p.normalize(p.absolute('..', 'plugins',
    'orca_voice_recorder', 'ios', 'Sources', 'OrcaVoiceRecorder', 'Generated',
    'OrcaVoiceRecorderTypes.swift'));

const _regenerate = 'Regenerate it from cli/: dart run bin/orca.dart plugin '
    'generate --lang swift --types-only '
    '--manifest ../plugins/orca_voice_recorder/orca_plugin.yaml '
    '--output ../plugins/orca_voice_recorder/ios/Sources/OrcaVoiceRecorder/Generated';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('orca_cli_voice_swift_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('C17.5/S the committed Swift voice recorder types are the generator '
      'output byte for byte', () async {
    // The manifest path is absolute, and so is the output under the temp
    // root: the run never writes into the repo.
    final runner = CommandRunner<void>('orca', 'test')
      ..addCommand(PluginGenerateCommand(root: tempDir.path));
    await runner.run(
        ['generate', '--lang', 'swift', '--types-only', '--manifest', _manifest]);
    final generated = File(
            p.join(tempDir.path, 'generated', 'OrcaVoiceRecorderTypes.swift'))
        .readAsStringSync();

    // Strict UTF-8 on both sides, so equal strings are equal bytes; a string
    // mismatch prints a readable diff.
    final committed = File(_committed);
    expect(committed.existsSync(), isTrue,
        reason: 'No types at $_committed. $_regenerate');
    expect(committed.readAsStringSync(), generated,
        reason: 'The committed types drifted from the generator. $_regenerate');
  });
}
