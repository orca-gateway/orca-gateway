import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../utils/marker.dart';
import '../patchers/android_manifest_patcher.dart';
import '../patchers/plist_patcher.dart';
import '../patchers/gradle_patcher.dart';

/// Removes an Orca Gateway plugin from the current Flutter project and cleans
/// up any marker-delimited native configuration that was injected.
class PluginRemoveCommand extends Command<void> {
  @override
  final name = 'remove';

  @override
  final description = 'Remove an Orca Gateway plugin and clean up native config.';

  @override
  String get invocation => '${runner!.executableName} plugin remove <plugin_name>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide the plugin name to remove (e.g. orca_google_map).');
    }

    final pluginName = argResults!.rest.first;
    final projectRoot = Directory.current.path;

    stdout.writeln('Removing plugin "$pluginName" ...');

    final removed = <String>[];

    // ------------------------------------------------------------------
    // 1. Remove marker sections from Android files
    // ------------------------------------------------------------------
    final androidManifest = File(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    );
    if (androidManifest.existsSync()) {
      final content = androidManifest.readAsStringSync();
      if (hasMarker(content, pluginName)) {
        AndroidManifestPatcher.remove(androidManifest.path, pluginName);
        removed.add('AndroidManifest.xml');
      }
    }

    final buildGradle = File(
      p.join(projectRoot, 'android', 'app', 'build.gradle'),
    );
    if (buildGradle.existsSync()) {
      final content = buildGradle.readAsStringSync();
      if (hasMarker(content, pluginName)) {
        GradlePatcher.remove(buildGradle.path, pluginName);
        removed.add('build.gradle');
      }
    }

    // ------------------------------------------------------------------
    // 2. Remove marker sections from iOS files
    // ------------------------------------------------------------------
    final infoPlist = File(
      p.join(projectRoot, 'ios', 'Runner', 'Info.plist'),
    );
    if (infoPlist.existsSync()) {
      final content = infoPlist.readAsStringSync();
      if (hasMarker(content, pluginName)) {
        PlistPatcher.remove(infoPlist.path, pluginName);
        removed.add('Info.plist');
      }
    }

    // ------------------------------------------------------------------
    // 3. Remove plugin from pubspec.yaml
    // ------------------------------------------------------------------
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      _removeDependency(pubspecFile, pluginName);
    }

    // ------------------------------------------------------------------
    // 4. Run flutter pub get
    // ------------------------------------------------------------------
    stdout.writeln('Running flutter pub get ...');
    final pubGetResult = await Process.run(
      'flutter',
      ['pub', 'get'],
      workingDirectory: projectRoot,
    );
    if (pubGetResult.exitCode != 0) {
      stderr.writeln('flutter pub get failed:');
      stderr.writeln(pubGetResult.stderr);
    }

    // ------------------------------------------------------------------
    // 5. Print summary
    // ------------------------------------------------------------------
    stdout.writeln('');
    stdout.writeln('--- Summary ---');
    stdout.writeln('Plugin:  $pluginName');

    if (removed.isNotEmpty) {
      stdout.writeln('Cleaned: ${removed.join(', ')}');
    } else {
      stdout.writeln('No native marker sections found.');
    }

    stdout.writeln('Removed from pubspec.yaml dependencies.');
    stdout.writeln('');
    stdout.writeln('Done.');
  }

  // ====================================================================
  // Helpers
  // ====================================================================

  /// Removes [pluginName] from the `dependencies:` section of [pubspecFile].
  ///
  /// Handles both single-line (`  pkg: ^1.0.0`) and multi-line (git/path)
  /// dependency declarations.
  void _removeDependency(File pubspecFile, String pluginName) {
    final lines = pubspecFile.readAsStringSync().split('\n');

    final depIndex = lines.indexWhere((l) => l.trimRight() == 'dependencies:');
    if (depIndex == -1) return;

    // Find the line where this dependency starts
    final startIndex = lines.indexWhere(
      (l) => l.trimLeft().startsWith('$pluginName:'),
      depIndex + 1,
    );
    if (startIndex == -1) return;

    // Determine the indentation level of this dependency entry
    final entryIndent = lines[startIndex].indexOf(RegExp(r'\S'));

    // Collect consecutive lines that belong to this entry (nested blocks are
    // indented further than the key line).
    var endIndex = startIndex + 1;
    while (endIndex < lines.length) {
      final line = lines[endIndex];
      // Empty lines inside a block are unusual in pubspec but handle them.
      if (line.trim().isEmpty) {
        endIndex++;
        continue;
      }
      final lineIndent = line.indexOf(RegExp(r'\S'));
      if (lineIndent > entryIndent) {
        endIndex++;
      } else {
        break;
      }
    }

    lines.removeRange(startIndex, endIndex);
    pubspecFile.writeAsStringSync(lines.join('\n'));
  }
}
