import 'dart:io';

import 'package:orca_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_cli/src/utils/marker.dart';

/// Patches a `Podfile` for a plugin.
///
/// Currently a stub -- most plugins do not need Podfile changes, but the
/// marker infrastructure is in place for future use.
class PodfilePatcher {
  /// Applies the given [config] to the Podfile at [podfilePath].
  ///
  /// Currently a no-op. Reserved for future use when plugins require custom
  /// pod entries.
  static void apply(
    String podfilePath,
    String pluginName,
    IosConfig config,
  ) {
    // No-op stub. If a plugin ever needs Podfile entries, add them here
    // wrapped in `# ORCA:pluginName` markers using wrapWithLineMarker.
  }

  /// Removes all marker sections for [pluginName] from the Podfile.
  static void remove(String podfilePath, String pluginName) {
    final file = File(podfilePath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    if (!hasMarker(content, pluginName)) return;

    content = removeMarker(content, pluginName);
    file.writeAsStringSync(content);
  }

  /// Returns `true` if markers for [pluginName] are present in the Podfile.
  static bool isApplied(String podfilePath, String pluginName) {
    final file = File(podfilePath);
    if (!file.existsSync()) return false;
    return hasMarker(file.readAsStringSync(), pluginName);
  }
}
