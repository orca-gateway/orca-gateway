import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_gateway_cli/src/utils/marker.dart';

/// Patches an `Info.plist` file with key/value entries from an [IosConfig].
class PlistPatcher {
  /// Applies the given [config] to the Info.plist at [plistPath].
  ///
  /// Inserts `<key>/<string>` (or other typed) pairs before the closing
  /// `</dict>` of the root dictionary. All inserted content is wrapped in
  /// XML comment markers for idempotent add/remove.
  static void apply(
    String plistPath,
    String pluginName,
    IosConfig config,
  ) {
    final file = File(plistPath);
    if (!file.existsSync()) {
      throw FileSystemException('Info.plist not found', plistPath);
    }

    var content = file.readAsStringSync();

    // Skip if already applied.
    if (hasMarker(content, pluginName)) return;

    if (config.plist.isEmpty) return;

    // Build the plist entries. `entry.value` may be a scalar String / bool
    // / int, a YamlMap (for type: dict) or a YamlList (for type: array).
    // `_plistValueTag` picks the right rendering strategy per entry.
    final entries = config.plist.map((entry) {
      final valueTag = _plistValueTag(entry.type, entry.value, '\t');
      return '\t<key>${entry.key}</key>\n\t$valueTag';
    }).join('\n');

    final wrapped = wrapWithXmlMarker(pluginName, entries);

    // Insert before the last </dict> (root dict closing tag).
    final closeDictIndex = content.lastIndexOf('</dict>');
    if (closeDictIndex == -1) {
      throw FormatException('Could not find closing </dict> in Info.plist');
    }

    content =
        '${content.substring(0, closeDictIndex)}$wrapped\n${content.substring(closeDictIndex)}';

    file.writeAsStringSync(content);
  }

  /// Removes all marker sections for [pluginName] from the plist file.
  static void remove(String plistPath, String pluginName) {
    final file = File(plistPath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    content = removeMarker(content, pluginName);
    file.writeAsStringSync(content);
  }

  /// Returns `true` if markers for [pluginName] are present in the plist.
  static bool isApplied(String plistPath, String pluginName) {
    final file = File(plistPath);
    if (!file.existsSync()) return false;
    return hasMarker(file.readAsStringSync(), pluginName);
  }

  /// Returns the appropriate plist XML tag for the given [type] and [value].
  ///
  /// [value] is accepted as [dynamic] because YAML may express a plist entry
  /// as a scalar (`value: foo`), a bool (`value: true`), a nested map (for
  /// `type: dict`), or a list (for `type: array`). [indent] is the current
  /// per-line indent and is only used for `dict`/`array` so nested output
  /// lines up with the surrounding entry block.
  static String _plistValueTag(String type, dynamic value, String indent) {
    switch (type) {
      case 'bool':
        // Accept either a raw YAML boolean or a "true"/"false" string. Older
        // manifests authored before this parser supported native booleans
        // often quote the value; we keep both code paths for compatibility.
        final isTrue = value is bool ? value : value.toString().toLowerCase() == 'true';
        return isTrue ? '<true/>' : '<false/>';
      case 'integer':
        return '<integer>$value</integer>';
      case 'array':
        // If the author wrote `value: [a, b]` as a YAML list, render each
        // element individually. A scalar is still accepted for
        // backward-compatibility with the pre-fix single-string array form.
        if (value is YamlList || value is List) {
          final inner = (value as Iterable)
              .map((e) => _inferredValueTag(e, '$indent\t'))
              .map((tag) => '$indent\t$tag')
              .join('\n');
          return '<array>\n$inner\n$indent</array>';
        }
        return '<array>\n$indent\t<string>$value</string>\n$indent</array>';
      case 'dict':
        // Nested dict — render each child key/value pair. We infer child
        // types from the runtime YAML types since authors don't typically
        // declare `type:` on nested entries.
        if (value is YamlMap || value is Map) {
          final mapValue = value as Map;
          final inner = mapValue.entries.map((e) {
            final childTag = _inferredValueTag(e.value, '$indent\t');
            return '$indent\t<key>${e.key}</key>\n$indent\t$childTag';
          }).join('\n');
          return '<dict>\n$inner\n$indent</dict>';
        }
        // Author declared `type: dict` but passed a scalar — degrade to an
        // empty dict so the file stays valid. Real plugins should catch
        // this in their own tests; the CLI's job is not to crash.
        return '<dict/>';
      default:
        return '<string>$value</string>';
    }
  }

  /// Picks a plist XML tag for [value] when no explicit `type:` was declared
  /// (e.g. inside a nested dict). Maps runtime YAML types onto the closest
  /// plist primitive. Unknown / complex types that don't have a clear plist
  /// analog fall through to `<string>value</string>` so output stays valid.
  static String _inferredValueTag(dynamic value, String indent) {
    if (value is bool) return value ? '<true/>' : '<false/>';
    if (value is int) return '<integer>$value</integer>';
    if (value is double) return '<real>$value</real>';
    if (value is YamlMap || value is Map) {
      return _plistValueTag('dict', value, indent);
    }
    if (value is YamlList || value is List) {
      return _plistValueTag('array', value, indent);
    }
    return '<string>$value</string>';
  }
}
