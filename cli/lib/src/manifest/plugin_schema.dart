import 'package:yaml/yaml.dart';

/// Schema for a single prop (widget prop or action param).
class PropSchema {
  final String type; // "string", "number", "boolean", "object", "array", "widget"
  final bool required;
  final List<String>? enumValues;
  final PropSchema? items; // for arrays
  final String? objectName; // extracted interface name for objects
  final Map<String, PropSchema>? objectProps; // for inline objects

  PropSchema({
    required this.type,
    this.required = false,
    this.enumValues,
    this.items,
    this.objectName,
    this.objectProps,
  });

  /// Parses a prop from YAML. Handles two forms:
  /// - Short: `{ type: number, required: true }`
  /// - Expanded: `{ type: array, items: { type: object, name: Foo, props: {...} } }`
  factory PropSchema.fromYaml(dynamic value) {
    if (value is YamlMap) {
      final type = value['type'] as String? ?? 'string';
      final required = value['required'] as bool? ?? false;

      List<String>? enumValues;
      if (value['enum'] is YamlList) {
        enumValues =
            (value['enum'] as YamlList).map((e) => e.toString()).toList();
      }

      PropSchema? items;
      if (type == 'array' && value['items'] != null) {
        items = PropSchema.fromYaml(value['items']);
      }

      String? objectName;
      Map<String, PropSchema>? objectProps;
      if (type == 'object') {
        objectName = value['name'] as String?;
        if (value['props'] is YamlMap) {
          objectProps = _parsePropsMap(value['props'] as YamlMap);
        }
      }

      return PropSchema(
        type: type,
        required: required,
        enumValues: enumValues,
        items: items,
        objectName: objectName,
        objectProps: objectProps,
      );
    }

    // Bare string shorthand: `myProp: string`
    if (value is String) {
      return PropSchema(type: value);
    }

    return PropSchema(type: 'string');
  }
}

/// Schema for a widget definition.
class WidgetSchema {
  final String kind; // "primitive", "input", "button", "layout-single", "layout-multi"
  final Map<String, PropSchema> props;
  final List<String> triggers;

  WidgetSchema({
    required this.kind,
    this.props = const {},
    this.triggers = const [],
  });

  factory WidgetSchema.fromYaml(YamlMap map) {
    final kind = map['kind'] as String? ?? 'primitive';
    final props = map['props'] is YamlMap
        ? _parsePropsMap(map['props'] as YamlMap)
        : <String, PropSchema>{};
    final triggers = (map['triggers'] as YamlList?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return WidgetSchema(kind: kind, props: props, triggers: triggers);
  }
}

/// Schema for a custom action definition.
class ActionSchema {
  final Map<String, PropSchema> params;

  ActionSchema({this.params = const {}});

  factory ActionSchema.fromYaml(YamlMap map) {
    final params = map['params'] is YamlMap
        ? _parsePropsMap(map['params'] as YamlMap)
        : <String, PropSchema>{};
    return ActionSchema(params: params);
  }
}

/// Top-level schema section of an `orca_plugin.yaml`.
class PluginSchema {
  final Map<String, WidgetSchema> widgets;
  final Map<String, ActionSchema> actions;

  PluginSchema({
    this.widgets = const {},
    this.actions = const {},
  });

  /// Returns true if the schema has any widgets or actions to generate.
  bool get isEmpty => widgets.isEmpty && actions.isEmpty;

  factory PluginSchema.fromYaml(YamlMap? map) {
    if (map == null) return PluginSchema();

    final widgets = <String, WidgetSchema>{};
    if (map['widgets'] is YamlMap) {
      for (final entry in (map['widgets'] as YamlMap).entries) {
        widgets[entry.key as String] =
            WidgetSchema.fromYaml(entry.value as YamlMap);
      }
    }

    final actions = <String, ActionSchema>{};
    if (map['actions'] is YamlMap) {
      for (final entry in (map['actions'] as YamlMap).entries) {
        actions[entry.key as String] =
            ActionSchema.fromYaml(entry.value as YamlMap);
      }
    }

    return PluginSchema(widgets: widgets, actions: actions);
  }
}

/// Parse a YAML map of prop name → prop definition.
Map<String, PropSchema> _parsePropsMap(YamlMap map) {
  final result = <String, PropSchema>{};
  for (final entry in map.entries) {
    result[entry.key as String] = PropSchema.fromYaml(entry.value);
  }
  return result;
}
