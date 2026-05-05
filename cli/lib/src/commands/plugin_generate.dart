import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../generators/typescript_generator.dart';
import '../manifest/plugin_manifest.dart';
import '../utils/package_resolver.dart';

/// Generates TypeScript types for all installed Orca Gateway plugins that
/// have a `schema` section in their `orca_plugin.yaml`.
///
/// Run from the root of a Flutter project:
/// ```
/// orca plugin generate
/// orca plugin generate --output src/generated
/// orca plugin generate --plugin orca_google_map
/// ```
class PluginGenerateCommand extends Command<void> {
  @override
  final name = 'generate';

  @override
  final description =
      'Generate TypeScript types from installed plugin schemas.';

  PluginGenerateCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for generated .ts files.',
      defaultsTo: 'generated',
    );
    argParser.addOption(
      'plugin',
      abbr: 'p',
      help: 'Generate for a specific plugin only.',
    );
  }

  @override
  Future<void> run() async {
    final projectRoot = Directory.current.path;
    final outputDir = argResults!['output'] as String;
    final singlePlugin = argResults!['plugin'] as String?;

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
      if (manifest.schema == null || manifest.schema!.isEmpty) continue;

      // Generate TypeScript
      final ts =
          TypeScriptGenerator.generate(packageName, manifest.schema!);

      // Write output file
      final outDir = Directory(p.join(projectRoot, outputDir));
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      final outFile = File(p.join(outDir.path, '$packageName.ts'));
      outFile.writeAsStringSync(ts);
      stdout.writeln('  Generated ${p.relative(outFile.path)}');
      generated++;
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
