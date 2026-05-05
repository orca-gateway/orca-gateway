import 'dart:io';

import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';

/// Reads an existing `.env` file at [path] and returns a map of KEY=VALUE
/// pairs. Blank lines and lines starting with `#` are ignored.
Map<String, String> readEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};

  final vars = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final index = trimmed.indexOf('=');
    if (index == -1) continue;

    final key = trimmed.substring(0, index).trim();
    final value = trimmed.substring(index + 1).trim();
    vars[key] = value;
  }
  return vars;
}

/// Writes the given [vars] map as KEY=VALUE lines to the file at [path].
void writeEnvFile(String path, Map<String, String> vars) {
  final buffer = StringBuffer();
  for (final entry in vars.entries) {
    buffer.writeln('${entry.key}=${entry.value}');
  }
  File(path).writeAsStringSync(buffer.toString());
}

/// Prompts the user for any missing required environment variables defined by
/// [vars], merging them with values already present in the `.env` file at
/// [envFilePath].
///
/// Returns the complete map of env vars (existing + newly prompted).
Future<Map<String, String>> promptEnvVars(
  List<EnvVar> vars,
  String envFilePath,
) async {
  final existing = readEnvFile(envFilePath);

  for (final envVar in vars) {
    if (existing.containsKey(envVar.key)) {
      stdout.writeln(
        '  ${envVar.key} already set (${existing[envVar.key]!.substring(0, (existing[envVar.key]!.length).clamp(0, 8))}...)',
      );
      continue;
    }

    if (!envVar.required) continue;

    stdout.writeln('');
    stdout.writeln('  ${envVar.key}');
    if (envVar.description.isNotEmpty) {
      stdout.writeln('  ${envVar.description}');
    }
    stdout.write('  > ');

    final input = stdin.readLineSync()?.trim() ?? '';
    if (input.isNotEmpty) {
      existing[envVar.key] = input;
    }
  }

  writeEnvFile(envFilePath, existing);
  return existing;
}
