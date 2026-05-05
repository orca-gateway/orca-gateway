import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Resolves the on-disk path for [packageName] from
/// `.dart_tool/package_config.json`.
String? resolvePackagePath(String projectRoot, String packageName) {
  final configFile = File(
    p.join(projectRoot, '.dart_tool', 'package_config.json'),
  );
  if (!configFile.existsSync()) return null;

  final json =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
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

/// Reads `pubspec.yaml` at [projectRoot] and returns all `orca_*` dependency
/// names, sorted alphabetically.
List<String> findOrcaPlugins(String projectRoot) {
  final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) return [];

  final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
  final deps = pubspec['dependencies'] as YamlMap? ?? YamlMap();
  return deps.keys
      .cast<String>()
      .where((name) => name.startsWith('orca_'))
      .toList()
    ..sort();
}
