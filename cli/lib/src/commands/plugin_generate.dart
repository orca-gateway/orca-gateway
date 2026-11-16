import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../generators/kotlin_generator.dart';
import '../generators/swift_generator.dart';
import '../generators/typescript_generator.dart';
import '../manifest/plugin_manifest.dart';
import '../utils/package_resolver.dart';

/// Generates TypeScript types for all installed Orca Gateway plugins that
/// have a `schema` section in their `orca_plugin.yaml`, or, with `--lang`,
/// a Swift or Kotlin plugin stub for each.
///
/// Run from the root of a Flutter project:
/// ```
/// orca plugin generate
/// orca plugin generate --output src/generated
/// orca plugin generate --plugin orca_google_map
/// ```
///
/// Or, for a native host with no pubspec.yaml, from one manifest:
/// ```
/// orca plugin generate --lang swift --manifest path/to/orca_plugin.yaml
/// orca plugin generate --lang kotlin --manifest path/to/orca_plugin.yaml --package com.example.plugins
/// ```
///
/// `--types-only` (Swift, Kotlin) writes the props, params and trigger-name
/// types alone, as `<Pascal>Types.swift` / `.kt`, for a plugin package to
/// compile as is.
class PluginGenerateCommand extends Command<void> {
  @override
  final name = 'generate';

  @override
  final description =
      'Generate TypeScript types (or Swift/Kotlin plugin stubs) from plugin schemas.';

  /// The project root; the current directory when null.
  final String? _root;

  PluginGenerateCommand({String? root}) : _root = root {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for the generated files.',
      defaultsTo: 'generated',
    );
    argParser.addOption(
      'plugin',
      abbr: 'p',
      help: 'Generate for a specific plugin only.',
    );
    argParser.addOption(
      'lang',
      help: 'Output language.',
      allowed: ['ts', 'swift', 'kotlin'],
      defaultsTo: 'ts',
    );
    argParser.addOption(
      'manifest',
      help: 'Generate from this orca_plugin.yaml only; no pubspec.yaml needed.',
    );
    argParser.addOption(
      'package',
      help: 'Package of the generated Kotlin file.',
      defaultsTo: 'orca.plugins',
    );
    argParser.addFlag(
      'types-only',
      help: 'Swift/Kotlin: write only the props, params and trigger-name '
          'types, as <Pascal>Types.swift / .kt (no plugin stub).',
      negatable: false,
    );
  }

  @override
  Future<void> run() async {
    final projectRoot = _root ?? Directory.current.path;
    final outputDir = argResults!['output'] as String;
    final singlePlugin = argResults!['plugin'] as String?;
    final lang = argResults!['lang'] as String;
    final manifestArg = argResults!['manifest'] as String?;
    final kotlinPackage = argResults!['package'] as String;
    final typesOnly = argResults!['types-only'] as bool;

    if (manifestArg != null) {
      final manifestPath = p.join(projectRoot, manifestArg);
      if (!File(manifestPath).existsSync()) {
        stderr.writeln('Error: No manifest found at $manifestArg.');
        exit(1);
      }
      final manifest = PluginManifest.fromYamlFile(manifestPath);
      final written = _write(projectRoot, outputDir, manifest.name, manifest,
          lang, kotlinPackage, typesOnly);
      if (!written) {
        stdout.writeln('No schema section in $manifestArg. Nothing to generate.');
      }
      return;
    }

    // Validate Flutter project
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      stderr.writeln('Error: No pubspec.yaml found in the current directory.');
      stderr.writeln('Run this command from the root of a Flutter project.');
      exit(1);
    }

    // Find plugins
    var plugins = findOrcaPlugins(projectRoot);
    if (singlePlugin != null) {
      if (!plugins.contains(singlePlugin)) {
        stderr.writeln(
            'Error: Plugin "$singlePlugin" not found in dependencies.');
        exit(1);
      }
      plugins = [singlePlugin];
    }

    if (plugins.isEmpty) {
      stdout.writeln('No Orca Gateway plugins (orca_*) found in dependencies.');
      return;
    }

    var generated = 0;

    for (final packageName in plugins) {
      final packagePath = resolvePackagePath(projectRoot, packageName);
      if (packagePath == null) {
        stderr.writeln(
            'Warning: Could not resolve "$packageName" — run flutter pub get');
        continue;
      }

      final manifestPath = p.join(packagePath, 'orca_plugin.yaml');
      if (!File(manifestPath).existsSync()) continue;

      final manifest = PluginManifest.fromYamlFile(manifestPath);
      if (_write(projectRoot, outputDir, packageName, manifest, lang,
          kotlinPackage, typesOnly)) {
        generated++;
      }
    }

    if (generated == 0) {
      stdout.writeln(
          'No plugins with a schema section found. Nothing to generate.');
    } else {
      stdout.writeln('');
      stdout.writeln('Generated $generated file(s) in $outputDir/');
    }
  }
}

/// Writes the [lang] output for [manifest] under [outputDir]: `<name>.ts`, or
/// `<Pascal(name)>Plugin.swift` / `.kt`, or with [typesOnly]
/// `<Pascal(name)>Types.swift` / `.kt` (TypeScript ignores it). TypeScript
/// and [typesOnly] need a schema section (false without one, nothing
/// written); the Swift and Kotlin stubs always write.
bool _write(String projectRoot, String outputDir, String name,
    PluginManifest manifest, String lang, String kotlinPackage,
    bool typesOnly) {
  final schema = manifest.schema;
  final noSchema = schema == null || schema.isEmpty;
  if (noSchema && (typesOnly || lang == 'ts')) return false;
  final suffix = typesOnly ? 'Types' : 'Plugin';
  final String fileName;
  final String source;
  switch (lang) {
    case 'swift':
      source = SwiftGenerator.generate(name, schema, typesOnly: typesOnly);
      fileName = '${_pascal(name)}$suffix.swift';
    case 'kotlin':
      source = KotlinGenerator.generate(name, schema,
          packageName: kotlinPackage, typesOnly: typesOnly);
      fileName = '${_pascal(name)}$suffix.kt';
    default:
      source = TypeScriptGenerator.generate(name, schema!);
      fileName = '$name.ts';
  }

  final outDir = Directory(p.join(projectRoot, outputDir));
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final outFile = File(p.join(outDir.path, fileName));
  outFile.writeAsStringSync(source);
  stdout.writeln('  Generated ${p.relative(outFile.path)}');
  return true;
}

/// `orca_google_map` → `OrcaGoogleMap`.
String _pascal(String name) => name
    .split(RegExp('[_-]'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join();

/// Generate TypeScript for a single plugin manifest and write to [outputDir].
/// Used by `plugin add` for auto-generation after installation.
void generateForPlugin(
    String projectRoot, String packageName, PluginManifest manifest,
    {String outputDir = 'generated'}) {
  if (manifest.schema == null || manifest.schema!.isEmpty) return;

  final ts = TypeScriptGenerator.generate(packageName, manifest.schema!);

  final outDir = Directory(p.join(projectRoot, outputDir));
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final outFile = File(p.join(outDir.path, '$packageName.ts'));
  outFile.writeAsStringSync(ts);
  stdout.writeln('TypeScript types generated at ${p.relative(outFile.path)}');
}
