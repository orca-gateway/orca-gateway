import '../types/context.dart';
import '../types/node.dart';
import '../types/widget.dart' show Widget, flatten;

// ── Response Actions (what the action author returns) ────

typedef ResponseAction = Map<String, dynamic>;

// ── Wire format (what the client receives) ──

/// Resolve ResponseAction[] into wire format.
/// Auto-flattens Widget instances in addComponent/replaceComponent.
List<Map<String, dynamic>> resolveResponseActions(
    List<ResponseAction> actions) {
  return actions.map((action) {
    final type = action['type'] as String?;
    if (type == 'addComponent') {
      final widget = action['widget'];
      final keyPrefix = action['keyPrefix'] as String? ?? '';
      if (widget is Widget) {
        final components = _prefixComponents(flatten(widget), keyPrefix);
        return <String, dynamic>{
          'type': 'addComponent',
          'parentId': action['parentId'],
          'components': components.map((c) => c.toJson()).toList(),
          if (action['position'] != null) 'position': action['position'],
        };
      }
    }
    if (type == 'replaceComponent') {
      final widget = action['widget'];
      final keyPrefix = action['keyPrefix'] as String? ?? '';
      if (widget is Widget) {
        final components = _prefixComponents(flatten(widget), keyPrefix);
        return <String, dynamic>{
          'type': 'replaceComponent',
          'targetId': action['targetId'],
          'components': components.map((c) => c.toJson()).toList(),
        };
      }
    }
    return action;
  }).toList();
}

// ── ID prefixing ────────────────────────────────────────────

bool _isAutoId(String id) => RegExp(r'^\d+$').hasMatch(id);

List<ComponentNode> _prefixComponents(
    List<ComponentNode> components, String prefix) {
  if (prefix.isEmpty) return components;

  // Build remap: auto IDs get prefixed, stable keys stay.
  final idMap = <String, String>{};
  for (final node in components) {
    idMap[node.id] = _isAutoId(node.id) ? '${prefix}_${node.id}' : node.id;
  }

  final oldIds = components.map((n) => n.id).toSet();
  return components.map((node) {
    final newId = idMap[node.id]!;
    final newChildren = node.children.map((cid) => idMap[cid] ?? cid).toList();
    // Remap slot references in props.
    final newProps = <String, dynamic>{};
    for (final entry in node.props.entries) {
      final v = entry.value;
      newProps[entry.key] =
          (v is String && oldIds.contains(v)) ? (idMap[v] ?? v) : v;
    }
    return ComponentNode(
      id: newId,
      type: node.type,
      kind: node.kind,
      childMode: node.childMode,
      props: newProps,
      children: newChildren,
      watches: node.watches,
      actions: node.actions,
    );
  }).toList();
}

// ── Schema Validation ───────────────────────────────────────

class SchemaField {
  final String type; // "string" | "number" | "boolean" | "object" | "array"
  final bool required;

  const SchemaField({required this.type, this.required = true});
}

typedef RequestSchema = Map<String, SchemaField>;

String? validateParams(Map<String, dynamic> params, RequestSchema schema) {
  for (final entry in schema.entries) {
    final value = params[entry.key];
    if (value == null) {
      if (entry.value.required) {
        return 'Missing required parameter: "${entry.key}"';
      }
      continue;
    }

    final actualType = value is List
        ? 'array'
        : value is Map
            ? 'object'
            : value is bool
                ? 'boolean'
                : value is num
                    ? 'number'
                    : value is String
                        ? 'string'
                        : 'unknown';

    if (actualType != entry.value.type) {
      return 'Parameter "${entry.key}" must be of type "${entry.value.type}", got "$actualType"';
    }
  }
  return null;
}

// ── Server Action Definition ────────────────────────────────

typedef ExecuteFn = Future<List<ResponseAction>> Function(ActionContext context);

class ServerActionConfig {
  final String id;
  final RequestSchema? schema;
  final ExecuteFn execute;

  const ServerActionConfig({
    required this.id,
    this.schema,
    required this.execute,
  });
}

class ServerActionDefinition {
  final String id;
  final RequestSchema? schema;
  final ExecuteFn execute;

  ServerActionDefinition._({
    required this.id,
    this.schema,
    required this.execute,
  });

  factory ServerActionDefinition.create(ServerActionConfig config) =>
      ServerActionDefinition._(
        id: config.id,
        schema: config.schema,
        execute: config.execute,
      );
}
