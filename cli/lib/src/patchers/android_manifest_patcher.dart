import 'dart:io';

import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_gateway_cli/src/utils/marker.dart';

/// Patches an `AndroidManifest.xml` file with permissions and meta-data
/// entries from an [AndroidConfig].
class AndroidManifestPatcher {
  /// Applies the given [config] to the AndroidManifest.xml at [manifestPath].
  ///
  /// - Permissions (`<uses-permission>`) are inserted before the `<application`
  ///   tag.
  /// - Meta-data (`<meta-data>`) entries are inserted inside `<application>`
  ///   before its closing `</application>` tag.
  ///
  /// All inserted content is wrapped in XML comment markers for idempotent
  /// add/remove.
  static void apply(
    String manifestPath,
    String pluginName,
    AndroidConfig config,
  ) {
    final file = File(manifestPath);
    if (!file.existsSync()) {
      throw FileSystemException('AndroidManifest.xml not found', manifestPath);
    }

    var content = file.readAsStringSync();

    // Skip if already applied.
    if (hasMarker(content, pluginName)) return;

    // --- Permissions ---
    if (config.permissions.isNotEmpty) {
      final permLines = config.permissions
          .map((p) => '    <uses-permission android:name="$p" />')
          .join('\n');
      final wrappedPerms = wrapWithXmlMarker(pluginName, permLines);

      // Insert before <application
      final appIndex = content.indexOf('<application');
      if (appIndex == -1) {
        throw FormatException(
          'Could not find <application tag in AndroidManifest.xml',
        );
      }
      content = '${content.substring(0, appIndex)}$wrappedPerms\n    ${ content.substring(appIndex)}';
    }

    // --- Meta-data ---
    if (config.manifestMeta.isNotEmpty) {
      final metaLines = config.manifestMeta
          .map(
            (m) =>
                '        <meta-data\n'
                '            android:name="${m.name}"\n'
                '            android:value="${m.value}" />',
          )
          .join('\n');
      final wrappedMeta = wrapWithXmlMarker(pluginName, metaLines);

      // Insert before </application>
      final closeAppIndex = content.lastIndexOf('</application>');
      if (closeAppIndex == -1) {
        throw FormatException(
          'Could not find </application> in AndroidManifest.xml',
        );
      }
      content =
          '${content.substring(0, closeAppIndex)}    $wrappedMeta\n    ${content.substring(closeAppIndex)}';
    }

    file.writeAsStringSync(content);
  }

  /// Removes all marker sections for [pluginName] from the manifest file.
  static void remove(String manifestPath, String pluginName) {
    final file = File(manifestPath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    content = removeMarker(content, pluginName);
    file.writeAsStringSync(content);
  }

  /// Returns `true` if markers for [pluginName] are present in the manifest.
  static bool isApplied(String manifestPath, String pluginName) {
    final file = File(manifestPath);
    if (!file.existsSync()) return false;
    return hasMarker(file.readAsStringSync(), pluginName);
  }
}
