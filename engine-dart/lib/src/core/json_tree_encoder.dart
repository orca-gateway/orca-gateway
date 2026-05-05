import '../types/context.dart';
import '../types/node.dart';
import '../types/value.dart';
import 'value_resolver.dart';
import 'widget_registry.g.dart';

// ── Types ───────────────────────────────────────────────────

class JsonTreeEncoderOptions {
  final Map<String, WidgetRegistryEntry> extraWidgets;

  const JsonTreeEncoderOptions({this.extraWidgets = const {}});
}

// ── Encoder ─────────────────────────────────────────────────

class JsonTreeEncoder {
  final List<ComponentNode> _nodes = [];
  int _nextId = 0;
  final ValueResolver _resolver;
  final Map<String, WidgetRegistryEntry> _extraWidgets;

  JsonTreeEncoder(this._resolver, [JsonTreeEncoderOptions? options])
      : _extraWidgets = options?.extraWidgets ?? const {};

  /// Flatten a JSON tree into a ComponentNode list with the root first.
  List<ComponentNode> encode(Map<String, dynamic> tree) {
    _addNode(tree);
    // Children-first → root-first. Mirrors the .reverse() in flatten().
    return _nodes.reversed.toList();
  }

  WidgetRegistryEntry? _lookupWidget(String wireType) {
    return widgetRegistry[wireType] ?? _extraWidgets[wireType];
  }

  String _addNode(Map<String, dynamic> tree) {
    final wireType = tree['type'] as String?;
    if (wireType == null || wireType.isEmpty) {
      throw StateError('json-tree-encoder: tree node missing `type`');
    }

    final meta = _lookupWidget(wireType);
    if (meta == null) {
      throw StateError(
        'json-tree-encoder: unknown widget type "$wireType" '
        '(regenerate registry: dart run tool/gen_widget_registry.dart)',
      );
    }

    // Assign id: prefer author-supplied key, else monotonic counter.
    final key = tree['key'] as String?;
    final id = (key != null && key.isNotEmpty) ? key : '${_nextId++}';

    // Walk children first so the flat array ends up child-first / root-last.
    final childIds = <String>[];
    final children = tree['children'] as List?;
    if (children != null) {
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        if (child is! Map<String, dynamic>) {
          throw StateError(
              'json-tree-encoder: $wireType.children[$i] is not an object');
        }
        childIds.add(_addNode(child));
      }
    }

    // Resolve props now so slot id injection operates on the resolved copy.
    final rawProps = tree['props'] as Map<String, dynamic>? ?? {};
    final resolvedProps = _resolver.resolveProps(Map<String, dynamic>.from(rawProps));

    // Walk slots (structure widgets only).
    final slots = tree['slots'] as List?;
    if (slots != null) {
      if (meta.kind != 'structure') {
        throw StateError(
          'json-tree-encoder: $wireType declares slots but kind=${meta.kind} '
          '(slots are only valid on structure widgets)',
        );
      }
      for (var i = 0; i < slots.length; i++) {
        final slot = slots[i];
        if (slot is! Map || slot['name'] == null || slot['widget'] == null) {
          throw StateError(
              'json-tree-encoder: $wireType.slots[$i] malformed');
        }
        final sid = _addNode(Map<String, dynamic>.from(slot['widget'] as Map));
        childIds.add(sid);
        resolvedProps[slot['name'] as String] = sid;
      }
    }

    // Watches from the resolved props.
    final watches = _extractPropsWatches(resolvedProps);

    final actions = tree['actions'] as Map<String, dynamic>?;
    _nodes.add(ComponentNode(
      id: id,
      type: meta.type,
      kind: meta.kind,
      childMode: meta.childMode,
      props: resolvedProps,
      children: childIds,
      watches: watches,
      actions: actions,
    ));

    return id;
  }
}

/// Convenience entry point.
List<ComponentNode> encodeJsonTree(
  Map<String, dynamic> tree,
  ValueResolverContext ctx, [
  JsonTreeEncoderOptions? options,
]) {
  return JsonTreeEncoder(ValueResolver(ctx), options).encode(tree);
}

// ── Watch extraction ────────────────────────────────────────

List<String> _extractPropsWatches(Map<String, dynamic> props) {
  final keys = <String>{};
  _walkForValues(props, keys);
  // Sorted output for deterministic comparison.
  return keys.toList()..sort();
}

void _walkForValues(dynamic obj, Set<String> keys) {
  if (obj == null) return;

  if (isValue(obj)) {
    for (final k in V.extractWatches(obj)) {
      keys.add(k);
    }
    return;
  }

  if (obj is List) {
    for (final item in obj) {
      _walkForValues(item, keys);
    }
    return;
  }

  if (obj is Map) {
    for (final val in obj.values) {
      _walkForValues(val, keys);
    }
  }
}
