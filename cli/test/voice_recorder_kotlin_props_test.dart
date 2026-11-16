// C17.5/K (drift): the voice recorder's Kotlin props, params and trigger
// names, committed as generated in its Android package
// (plugins/orca_voice_recorder/android/voice-recorder/src/main/kotlin/com/
// orcagateway/plugins/voicerecorder/OrcaVoiceRecorderTypes.kt), which the
// package's Gradle build compiles and VoiceRecorderPropsTest pins against the
// Flutter plugin, are exactly what `orca plugin generate --lang kotlin
// --types-only --package com.orcagateway.plugins.voicerecorder` writes for
// plugins/orca_voice_recorder/orca_plugin.yaml today.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:orca_gateway_cli/src/commands/plugin_generate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Paths from the cli package root (tests run from cli/).
final _manifest = p.normalize(
    p.absolute('..', 'plugins', 'orca_voice_recorder', 'orca_plugin.yaml'));
final _committed = p.normalize(p.absolute(
    '..',
    'plugins',
    'orca_voice_recorder',
    'android',
    'voice-recorder',
    'src',
    'main',
    'kotlin',
    'com',
    'orcagateway',
    'plugins',
    'voicerecorder',
    'OrcaVoiceRecorderTypes.kt'));

const _regenerate = 'Regenerate it from cli/: dart run bin/orca.dart plugin '
    'generate --lang kotlin --types-only '
    '--package com.orcagateway.plugins.voicerecorder '
    '--manifest ../plugins/orca_voice_recorder/orca_plugin.yaml '
    '--output ../plugins/orca_voice_recorder/android/voice-recorder/src/main/'
    'kotlin/com/orcagateway/plugins/voicerecorder';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('orca_cli_voice_kotlin_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('C17.5/K the committed Kotlin voice recorder types are the generator '
      'output byte for byte', () async {
    final runner = CommandRunner<void>('orca', 'test')
      ..addCommand(PluginGenerateCommand(root: tempDir.path));
    await runner.run([
      'generate', '--lang', 'kotlin', '--types-only', //
      '--package', 'com.orcagateway.plugins.voicerecorder',
      '--manifest', _manifest,
    ]);
    final out = Directory(p.join(tempDir.path, 'generated'));
    expect([for (final f in out.listSync()) p.basename(f.path)],
        ['OrcaVoiceRecorderTypes.kt']);
    final generated =
        File(p.join(out.path, 'OrcaVoiceRecorderTypes.kt')).readAsStringSync();

    // Strict UTF-8 on both sides, so equal strings are equal bytes; a string
    // mismatch prints a readable diff.
    final committed = File(_committed);
    expect(committed.existsSync(), isTrue,
        reason: 'No types at $_committed. $_regenerate');
    expect(committed.readAsStringSync(), generated,
        reason: 'The committed types drifted from the generator. $_regenerate');
  });
}
