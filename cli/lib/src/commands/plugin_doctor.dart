import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../manifest/plugin_manifest.dart';
import '../utils/core_widget_types.dart';
import '../utils/engine_resolver.dart';
import '../utils/png_reader.dart';

/// Checks that every installed Orca Gateway plugin (`orca_*`) is properly
/// configured across Android, iOS, and environment variables.
class PluginDoctorCommand extends Command<void> {
  @override
  final name = 'doctor';

  @override
  final description = 'Check that all Orca Gateway plugins are properly configured.';

  @override
  Future<void> run() async {
    final projectRoot = Directory.current.path;

    // ------------------------------------------------------------------
    // 1. Read pubspec.yaml and collect orca_* dependencies
    // ------------------------------------------------------------------
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      stderr.writeln('Error: No pubspec.yaml found in the current directory.');
      exit(1);
    }

    final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    final deps = pubspec['dependencies'] as YamlMap? ?? YamlMap();
    final orcaPackages = deps.keys
        .cast<String>()
        .where((name) => name.startsWith('orca_'))
        .toList()
      ..sort();

    if (orcaPackages.isEmpty) {
      stdout.writeln('No Orca Gateway plugins (orca_*) found in dependencies.');
      return;
    }

    // ------------------------------------------------------------------
    // Pre-load native file contents once
    // ------------------------------------------------------------------
    final androidManifestFile = File(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    );
    final androidManifestContent =
        androidManifestFile.existsSync() ? androidManifestFile.readAsStringSync() : null;

    final infoPlistFile = File(
      p.join(projectRoot, 'ios', 'Runner', 'Info.plist'),
    );
    final infoPlistContent =
        infoPlistFile.existsSync() ? infoPlistFile.readAsStringSync() : null;

    final envVars = _loadEnvFile(p.join(projectRoot, '.env'));

    // ------------------------------------------------------------------
    // 2. For each plugin, resolve path and check manifest
    // ------------------------------------------------------------------
    for (final packageName in orcaPackages) {
      stdout.writeln(packageName);

      final packagePath = _resolvePackagePath(projectRoot, packageName);
      if (packagePath == null) {
        stdout.writeln('  [?] Could not resolve package path (run flutter pub get)');
        stdout.writeln('');
        continue;
      }

      final manifestPath = p.join(packagePath, 'orca_plugin.yaml');
      if (!File(manifestPath).existsSync()) {
        stdout.writeln('  [--] No orca_plugin.yaml found — nothing to check');
        stdout.writeln('');
        continue;
      }

      final manifest = PluginManifest.fromYamlFile(manifestPath);

      // ---- Android checks ----
      if (manifest.android != null) {
        final android = manifest.android!;

        // Permissions
        if (android.permissions.isNotEmpty) {
          if (androidManifestContent == null) {
            stdout.writeln('  [\u2717] Android permissions — AndroidManifest.xml not found');
          } else {
            final missing = android.permissions
                .where((perm) => !androidManifestContent.contains(perm))
                .toList();
            if (missing.isEmpty) {
              stdout.writeln('  [\u2713] Android permissions');
            } else {
              stdout.writeln('  [\u2717] Android permissions — missing ${missing.join(', ')}');
            }
          }
        }

        // Manifest meta-data
        if (android.manifestMeta.isNotEmpty) {
          if (androidManifestContent == null) {
            stdout.writeln('  [\u2717] Android manifest meta-data — AndroidManifest.xml not found');
          } else {
            final missing = android.manifestMeta
                .where((m) => !androidManifestContent.contains(m.name))
                .toList();
            if (missing.isEmpty) {
              stdout.writeln('  [\u2713] Android manifest meta-data');
            } else {
              stdout.writeln(
                '  [\u2717] Android manifest meta-data — missing '
                '${missing.map((m) => m.name).join(', ')}',
              );
            }
          }
        }
      }

      // ---- iOS checks ----
      if (manifest.ios != null) {
        final ios = manifest.ios!;

        if (ios.plist.isNotEmpty) {
          if (infoPlistContent == null) {
            stdout.writeln('  [\u2717] iOS plist entries — Info.plist not found');
          } else {
            final missing = ios.plist
                .where((entry) => !infoPlistContent.contains(entry.key))
                .toList();
            if (missing.isEmpty) {
              stdout.writeln('  [\u2713] iOS plist entries');
            } else {
              stdout.writeln(
                '  [\u2717] iOS plist entries — missing '
                '${missing.map((e) => e.key).join(', ')}',
              );
            }
          }
        }
      }

      // ---- Env checks ----
      if (manifest.env.isNotEmpty) {
        final requiredEnv = manifest.env.where((e) => e.required).toList();
        if (requiredEnv.isNotEmpty) {
          final missing = requiredEnv
              .where((e) => !envVars.containsKey(e.key))
              .toList();
          if (missing.isEmpty) {
            stdout.writeln('  [\u2713] Environment');
          } else {
            stdout.writeln(
              '  [\u2717] Environment — missing '
              '${missing.map((e) => e.key).join(', ')}',
            );
          }
        }
      }

      // ---- Marketplace checks (Epic 38 Slice B) ----
      if (manifest.marketplace != null) {
        _checkMarketplace(packagePath, manifest.marketplace!);
      }

      // ---- Preview checks (Epic 38 Slice B) ----
      if (manifest.preview != null) {
        _checkPreview(packagePath, manifest.preview!);
      }

      stdout.writeln('');
    }
  }

  /// Marketplace asset validation. All three icon sizes must exist as valid
  /// PNG files with exact pixel dimensions (32, 64, 128). At least one
  /// screenshot must exist as a valid PNG. Dimension and signature checks
  /// come from [readPngDimensions]; no extra dependencies are needed.
  void _checkMarketplace(String packagePath, MarketplaceConfig marketplace) {
    void checkIcon(String label, String relPath, int expectedSize) {
      final full = p.join(packagePath, relPath);
      final dims = readPngDimensions(full);
      if (dims == null) {
        if (!File(full).existsSync()) {
          stdout.writeln('  [\u2717] Marketplace $label — missing $relPath');
        } else {
          stdout.writeln(
            '  [\u2717] Marketplace $label — $relPath is not a valid PNG',
          );
        }
        return;
      }
      if (dims.width != expectedSize || dims.height != expectedSize) {
        stdout.writeln(
          '  [\u2717] Marketplace $label — $relPath must be '
          '${expectedSize}x$expectedSize (got ${dims.width}x${dims.height})',
        );
        return;
      }
      stdout.writeln('  [\u2713] Marketplace $label');
    }

    checkIcon('icon 32x32', marketplace.icons.small, 32);
    checkIcon('icon 64x64', marketplace.icons.medium, 64);
    checkIcon('icon 128x128', marketplace.icons.large, 128);

    var screenshotsOk = true;
    for (final shot in marketplace.screenshots) {
      final full = p.join(packagePath, shot.path);
      final dims = readPngDimensions(full);
      if (dims == null) {
        if (!File(full).existsSync()) {
          stdout.writeln(
            '  [\u2717] Marketplace screenshot — missing ${shot.path}',
          );
        } else {
          stdout.writeln(
            '  [\u2717] Marketplace screenshot — ${shot.path} is not a valid PNG',
          );
        }
        screenshotsOk = false;
      }
    }
    if (screenshotsOk && marketplace.screenshots.isNotEmpty) {
      final count = marketplace.screenshots.length;
      stdout.writeln(
        '  [\u2713] Marketplace screenshots ($count)',
      );
    }
  }

  /// Preview section validation. For declarative mode:
  ///
  ///   1. The stub file exists.
  ///   2. The compiled stub file exists (warn — author may not have run
  ///      `orca plugin build` yet).
  ///   3. The compiled stub references ONLY core widgets. Plugin widgets
  ///      referencing other plugins are a hard error because it would mean
  ///      the compiled JSON cannot be rendered by the stock preview editor
  ///      — which defeats the whole "no rebuild needed" property.
  ///
  /// For web_native and none modes, doctor just acknowledges the choice.
  void _checkPreview(String packagePath, PreviewConfig preview) {
    switch (preview.kind) {
      case PreviewKind.none:
        stdout.writeln('  [\u2013] Preview kind = none (opted out)');
        return;

      case PreviewKind.webNative:
        if (preview.entry == null) {
          stdout.writeln('  [\u2717] Preview web_native — preview.entry is required');
          return;
        }
        final entryFile = File(p.join(packagePath, preview.entry!));
        if (!entryFile.existsSync()) {
          stdout.writeln(
            '  [\u2717] Preview web_native entry — missing ${preview.entry}',
          );
          return;
        }
        stdout.writeln('  [\u2713] Preview web_native entry');
        return;

      case PreviewKind.declarative:
        final stubFile = File(p.join(packagePath, preview.stubPath));
        if (!stubFile.existsSync()) {
          stdout.writeln(
            '  [\u2717] Preview declarative stub — missing ${preview.stubPath}',
          );
          return;
        }
        stdout.writeln('  [\u2713] Preview declarative stub');

        final compiledFile = File(p.join(packagePath, preview.compiledStubPath));
        if (!compiledFile.existsSync()) {
          stdout.writeln(
            '  [\u2717] Preview compiled stub — missing ${preview.compiledStubPath} '
            '(run "orca plugin build")',
          );
          return;
        }

        final Map<String, dynamic> compiled;
        try {
          compiled = jsonDecode(compiledFile.readAsStringSync())
              as Map<String, dynamic>;
        } catch (e) {
          stdout.writeln(
            '  [\u2717] Preview compiled stub — ${preview.compiledStubPath} is '
            'not valid JSON: $e',
          );
          return;
        }

        // Core-widgets-only enforcement. Resolve the engine, load the widget
        // registry, walk the compiled JSON, and fail if any referenced type
        // is missing from the core set. A plugin may freely reference its
        // OWN widget types at the top level of the stub map (those are the
        // keys — the things being stubbed), but the VALUES must be trees
        // composed of core widgets only.
        final enginePath = findEnginePath(packagePath);
        if (enginePath == null) {
          stdout.writeln(
            '  [?] Preview compiled stub — cannot locate engine to validate '
            'core-widgets-only rule (set ORCA_ENGINE_PATH to enforce)',
          );
          return;
        }

        final coreTypes = loadCoreWidgetTypes(enginePath);
        if (coreTypes.isEmpty) {
          stdout.writeln(
            '  [?] Preview compiled stub — widget-registry.json not found, '
            'skipping core-widgets-only validation',
          );
          return;
        }

        final referenced = collectStubWidgetTypes(compiled);
        final nonCore = referenced.difference(coreTypes).toList()..sort();
        if (nonCore.isEmpty) {
          stdout.writeln(
            '  [\u2713] Preview compiled stub — core widgets only',
          );
        } else {
          stdout.writeln(
            '  [\u2717] Preview compiled stub — declarative mode may only '
            'reference core widgets, but found: ${nonCore.join(', ')}',
          );
        }
    }
  }

  // ====================================================================
  // Helpers
  // ====================================================================

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

  /// Reads a `.env` file and returns a map of key-value pairs.
  Map<String, String> _loadEnvFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return {};

    final vars = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex == -1) continue;
      final key = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();
      vars[key] = value;
    }
    return vars;
  }
}
