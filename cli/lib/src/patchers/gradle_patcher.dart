import 'dart:io';

import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_gateway_cli/src/utils/marker.dart';

/// Patches a `build.gradle` or `build.gradle.kts` file with dependencies
/// from an [AndroidConfig].
class GradlePatcher {
  /// Applies the given [config] to the Gradle build file at [gradlePath].
  ///
  /// Inserts `gradle_dependencies` entries inside the `dependencies { }` block,
  /// wrapped in `// ORCA:` line comment markers.
  static void apply(
    String gradlePath,
    String pluginName,
    AndroidConfig config,
  ) {
    final file = File(gradlePath);
    if (!file.existsSync()) {
      throw FileSystemException('Gradle build file not found', gradlePath);
    }

    var content = file.readAsStringSync();

    // Skip if already applied.
    if (hasMarker(content, pluginName)) return;

    if (config.gradleDependencies.isEmpty) return;

    final depLines =
        config.gradleDependencies.map((d) => '    $d').join('\n');
    final wrapped = wrapWithLineMarker(pluginName, depLines);

    // Find the dependencies { } block and insert before its closing brace.
    // We look for the last `}` that closes a `dependencies` block.
    final depsPattern = RegExp(r'dependencies\s*\{');
    final match = depsPattern.firstMatch(content);
    if (match == null) {
      throw FormatException(
        'Could not find dependencies { } block in $gradlePath',
      );
    }

    // Walk from the opening brace to find the matching closing brace.
    final openIndex = match.end - 1; // index of '{'
    final closeIndex = _findMatchingBrace(content, openIndex);
    if (closeIndex == -1) {
      throw FormatException(
        'Could not find closing brace of dependencies block in $gradlePath',
      );
    }

    content =
        '${content.substring(0, closeIndex)}    $wrapped\n${content.substring(closeIndex)}';

    file.writeAsStringSync(content);
  }

  /// Removes all marker sections for [pluginName] from the Gradle file.
  static void remove(String gradlePath, String pluginName) {
    final file = File(gradlePath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    content = removeMarker(content, pluginName);
    file.writeAsStringSync(content);
  }

  /// Returns `true` if markers for [pluginName] are present in the Gradle file.
  static bool isApplied(String gradlePath, String pluginName) {
    final file = File(gradlePath);
    if (!file.existsSync()) return false;
    return hasMarker(file.readAsStringSync(), pluginName);
  }

  /// Finds the index of the closing `}` that matches the opening `{` at
  /// [openIndex] in [content]. Returns -1 if not found.
  static int _findMatchingBrace(String content, int openIndex) {
    var depth = 0;
    for (var i = openIndex; i < content.length; i++) {
      if (content[i] == '{') {
        depth++;
      } else if (content[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}
