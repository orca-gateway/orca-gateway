import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../manifest/plugin_manifest.dart';
import '../utils/env_prompt.dart';
import '../patchers/android_manifest_patcher.dart';
import 'plugin_generate.dart';
import '../patchers/plist_patcher.dart';
import '../patchers/gradle_patcher.dart';

/// Adds an Orca Gateway plugin to the current Flutter project and applies
/// native platform configuration (Android manifest, Gradle, iOS plist).
class PluginAddCommand extends Command<void> {
  @override
  final name = 'add';

  @override
  final description = 'Add an Orca Gateway plugin and configure native platforms.';

  @override
  String get invocation => '${runner!.executableName} plugin add <source>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a plugin source (pub name, git URL, or local path).');
    }

    final source = argResults!.rest.first;
    final projectRoot = Directory.current.path;

    // ------------------------------------------------------------------
    // 1. Determine dependency type and package name
    // ------------------------------------------------------------------
    final _DepInfo depInfo = _resolveDependency(source);
    final packageName = depInfo.packageName;

    stdout.writeln('Adding plugin "$packageName" ...');

    // ------------------------------------------------------------------
    // 2. Validate Flutter project
    // ------------------------------------------------------------------
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      stderr.writeln('Error: No pubspec.yaml found in the current directory.');
      stderr.writeln('Run this command from the root of a Flutter project.');
      exit(1);
    }

    // ------------------------------------------------------------------
    // 3. Add the dependency to pubspec.yaml
    // ------------------------------------------------------------------
    try {
      _addDependency(pubspecFile, packageName, depInfo);
    } catch (e) {
      stderr.writeln('Error updating pubspec.yaml: $e');
      exit(1);
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
      exit(1);
    }

    // ------------------------------------------------------------------
    // 5. Resolve the package path from .dart_tool/package_config.json
    // ------------------------------------------------------------------
    final packagePath = _resolvePackagePath(projectRoot, packageName);
    if (packagePath == null) {
      stderr.writeln(
        'Error: Could not find resolved path for "$packageName" in '
        '.dart_tool/package_config.json.',
      );
      exit(1);
    }

    // ------------------------------------------------------------------
    // 6. Read orca_plugin.yaml manifest
    // ------------------------------------------------------------------
    final manifestPath = p.join(packagePath, 'orca_plugin.yaml');
    if (!File(manifestPath).existsSync()) {
      stdout.writeln(
        'Note: "$packageName" does not contain an orca_plugin.yaml. '
        'No native configuration applied.',
      );
      return;
    }

    final PluginManifest manifest;
    try {
      manifest = PluginManifest.fromYamlFile(manifestPath);
    } catch (e) {
      stderr.writeln('Error reading plugin manifest: $e');
      exit(1);
    }

    // ------------------------------------------------------------------
    // 7. Apply Android patches
    // ------------------------------------------------------------------
    final androidDir = Directory(p.join(projectRoot, 'android'));
    final patchedAndroid = <String>[];

    if (androidDir.existsSync() && manifest.android != null) {
      final androidConfig = manifest.android!;

      final manifestXml = File(
        p.join(projectRoot, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      );
      if (manifestXml.existsSync()) {
        AndroidManifestPatcher.apply(
          manifestXml.path,
          packageName,
          androidConfig,
        );
        patchedAndroid.add('AndroidManifest.xml');
      }

      final buildGradle = File(p.join(projectRoot, 'android', 'app', 'build.gradle'));
      if (buildGradle.existsSync()) {
        GradlePatcher.apply(
          buildGradle.path,
          packageName,
          androidConfig,
        );
        patchedAndroid.add('build.gradle');
      }
    }

    // ------------------------------------------------------------------
    // 8. Apply iOS patches
    // ------------------------------------------------------------------
    final iosDir = Directory(p.join(projectRoot, 'ios'));
    var patchedIos = false;

    if (iosDir.existsSync() && manifest.ios != null) {
      final iosConfig = manifest.ios!;

      final plistFile = File(p.join(projectRoot, 'ios', 'Runner', 'Info.plist'));
      if (plistFile.existsSync() && iosConfig.plist.isNotEmpty) {
        PlistPatcher.apply(
          plistFile.path,
          packageName,
          iosConfig,
        );
        patchedIos = true;
      }
    }

    // ------------------------------------------------------------------
    // 9. Prompt for environment variables
    // ------------------------------------------------------------------
    if (manifest.env.isNotEmpty) {
      stdout.writeln('');
      final envFilePath = p.join(projectRoot, '.env');
      await promptEnvVars(manifest.env, envFilePath);
    }

    // ------------------------------------------------------------------
    // 10. Generate TypeScript types (if plugin has a schema)
    // ------------------------------------------------------------------
    generateForPlugin(projectRoot, packageName, manifest);

    // ------------------------------------------------------------------
    // 11. Print summary
    // ------------------------------------------------------------------
    stdout.writeln('');
    stdout.writeln('--- Summary ---');
    stdout.writeln('Plugin:  ${manifest.displayName} ($packageName)');

    if (patchedAndroid.isNotEmpty) {
      stdout.writeln('Android: patched ${patchedAndroid.join(', ')}');
    }
    if (patchedIos) {
      stdout.writeln('iOS:     patched Info.plist');
    }

    if (manifest.setupSteps.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln('Additional setup steps:');
      for (final step in manifest.setupSteps) {
        stdout.writeln('  - $step');
      }
    }

    stdout.writeln('');
    stdout.writeln('Done.');
  }

  // ====================================================================
  // Helpers
  // ====================================================================

  /// Inserts the dependency into [pubspecFile] using string manipulation.
  void _addDependency(File pubspecFile, String packageName, _DepInfo dep) {
    var content = pubspecFile.readAsStringSync();
    final lines = content.split('\n');

    // Find the `dependencies:` section
    final depIndex = lines.indexWhere((l) => l.trimRight() == 'dependencies:');
    if (depIndex == -1) {
      throw StateError('Could not find "dependencies:" section in pubspec.yaml');
    }

    // Build the YAML snippet to insert
    String snippet;
    switch (dep.type) {
      case _DepType.pub:
        snippet = '  $packageName: ^0.1.0';
        break;
      case _DepType.git:
        snippet = '  $packageName:\n'
            '    git:\n'
            '      url: ${dep.source}';
        break;
      case _DepType.path:
        snippet = '  $packageName:\n'
            '    path: ${dep.source}';
        break;
    }

    // Check if the dependency already exists
    final existingIndex = lines.indexWhere(
      (l) => l.trimLeft().startsWith('$packageName:'),
      depIndex + 1,
    );
    if (existingIndex != -1) {
      stdout.writeln('Dependency "$packageName" already present in pubspec.yaml.');
      return;
    }

    // Insert after the `dependencies:` line
    lines.insert(depIndex + 1, snippet);
    pubspecFile.writeAsStringSync(lines.join('\n'));
  }

  /// Resolves the on-disk path for [packageName] from
  /// `.dart_tool/package_config.json`.
  String? _resolvePackagePath(String projectRoot, String packageName) {
    final configFile = File(
      p.join(projectRoot, '.dart_tool', 'package_config.json'),
    );
    if (!configFile.existsSync()) return null;

    final json = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final packages = json['packages'] as List<dynamic>? ?? [];

    for (final pkg in packages) {
      final map = pkg as Map<String, dynamic>;
      if (map['name'] == packageName) {
        final rootUri = map['rootUri'] as String;
        // rootUri can be absolute or relative to .dart_tool/
        if (rootUri.startsWith('file://')) {
          return Uri.parse(rootUri).toFilePath();
        }
        return p.normalize(
          p.join(projectRoot, '.dart_tool', rootUri),
        );
      }
    }
    return null;
  }

  /// Determines the dependency type and package name from [source].
  _DepInfo _resolveDependency(String source) {
    // Git URL
    if (source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('git@')) {
      // Extract package name: last path segment without .git
      var name = source.split('/').last;
      if (name.endsWith('.git')) {
        name = name.substring(0, name.length - 4);
      }
      return _DepInfo(type: _DepType.git, packageName: name, source: source);
    }

    // Local path
    if (source.startsWith('/') ||
        source.startsWith('./') ||
        source.startsWith('../')) {
      final name = p.basename(p.absolute(source));
      return _DepInfo(type: _DepType.path, packageName: name, source: source);
    }

    // Default: pub.dev package name
    return _DepInfo(type: _DepType.pub, packageName: source, source: source);
  }
}

enum _DepType { pub, git, path }

class _DepInfo {
  final _DepType type;
  final String packageName;
  final String source;

  _DepInfo({
    required this.type,
    required this.packageName,
    required this.source,
  });
}
