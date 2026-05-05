import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Loads the set of core widget type names from the engine's
/// `widget-registry.json` manifest.
///
/// The manifest lives at `<enginePath>/../schema/widget-registry.json` in the
/// Orca Gateway monorepo (schema is a sibling of engine, not a child). Returns an
/// empty set if the file cannot be read — callers treat that as "cannot
/// validate the stub" and typically warn rather than hard-fail, since a
/// missing registry usually means the CLI is running outside a monorepo
/// checkout.
///
/// Used by `orca plugin doctor` to enforce the Epic 38 Slice B rule that
/// declarative preview stubs may reference ONLY core widgets — if a stub
/// pulled in another plugin's widget type, the compiled JSON would cease to
/// be renderable by the stock preview editor, which is the whole point of
/// the "declarative" mode.
Set<String> loadCoreWidgetTypes(String enginePath) {
  // The widget-registry.json lives next to the engine directory, at
  // <enginePath>/../schema/widget-registry.json. Compute that and fall back
  // to returning an empty set on any error so doctor runs gracefully in
  // partial checkouts.
  final schemaDir = p.normalize(p.join(enginePath, '..', 'schema'));
  final manifestFile =
      File(p.join(schemaDir, 'widget-registry.json'));
  if (!manifestFile.existsSync()) return <String>{};

  try {
    final json = jsonDecode(manifestFile.readAsStringSync())
        as Map<String, dynamic>;
    final widgets = json['widgets'] as List<dynamic>? ?? <dynamic>[];
    return widgets
        .map((w) => (w as Map<String, dynamic>)['type'] as String)
        .toSet();
  } catch (_) {
    return <String>{};
  }
}

/// Walks a compiled stub JSON (as written by `orca plugin build`) and
/// collects every widget type it references. The compiled JSON is shaped as
/// `{ "<widgetType>": ComponentNode[] }`, so the walk recurses through every
/// node's `type` field across every stub entry.
Set<String> collectStubWidgetTypes(Map<String, dynamic> compiled) {
  final types = <String>{};
  for (final entry in compiled.entries) {
    final nodes = entry.value;
    if (nodes is! List) continue;
    for (final node in nodes) {
      if (node is Map<String, dynamic>) {
        final type = node['type'];
        if (type is String) types.add(type);
      }
    }
  }
  return types;
}
