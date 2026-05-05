import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Walks upward from [startDir] looking for a directory named `engine` whose
/// `package.json` declares `"name": "orcagateway-engine"`. Returns the
/// absolute path to that directory, or null if none is found before the
/// filesystem root.
///
/// Used by `orca plugin build` and `orca plugin create --preview=declarative`
/// to bake relative imports into generated files. Walking upward (rather than
/// taking an env var) is the right default for the monorepo case where every
/// Phase 1 plugin lives under `open-source/plugins/` — the resolver finds the
/// engine automatically with no extra setup.
///
/// For external plugins that live outside the Orca Gateway tree, this returns null;
/// callers should fall back to honoring the `ORCA_ENGINE_PATH` environment
/// variable and then surface an actionable error when neither is set.
String? findEnginePath(String startDir) {
  final envOverride = Platform.environment['ORCA_ENGINE_PATH'];
  if (envOverride != null && envOverride.isNotEmpty) {
    final candidate = Directory(envOverride);
    if (candidate.existsSync() &&
        _looksLikeEngine(candidate.absolute.path)) {
      return candidate.absolute.path;
    }
  }

  var dir = Directory(startDir).absolute;
  // Cap the walk at 20 levels — enough for any realistic monorepo layout and
  // prevents runaway loops on weird symlink setups.
  for (var i = 0; i < 20; i++) {
    final candidate = p.join(dir.path, 'engine');
    if (Directory(candidate).existsSync() && _looksLikeEngine(candidate)) {
      return candidate;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

bool _looksLikeEngine(String dirPath) {
  final pkgFile = File(p.join(dirPath, 'package.json'));
  if (!pkgFile.existsSync()) return false;
  try {
    final json = jsonDecode(pkgFile.readAsStringSync()) as Map<String, dynamic>;
    return json['name'] == 'orcagateway-engine';
  } catch (_) {
    return false;
  }
}
