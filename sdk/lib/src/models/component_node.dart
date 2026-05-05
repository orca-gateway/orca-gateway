/// Thrown when server JSON cannot be parsed into a model.
class OrcaParseException implements Exception {
  final String message;
  final Object? source;
  const OrcaParseException(this.message, [this.source]);
  @override
  String toString() => 'OrcaParseException: $message';
}

/// Wire format for a single component in the flat node array.
class ComponentNode {
  final String id;
  final String type;
  final String kind;
  final String childMode;
  final Map<String, dynamic> props;
  final List<String> children;
  final List<String> watches;
  final Map<String, dynamic>? actions;

  const ComponentNode({
    required this.id,
    required this.type,
    required this.kind,
    required this.childMode,
    required this.props,
    required this.children,
    required this.watches,
    this.actions,
  });

  factory ComponentNode.fromJson(Map<String, dynamic> json) {
    try {
      return ComponentNode(
        id: json['id'] as String,
        type: json['type'] as String,
        kind: json['kind'] as String,
        childMode: json['childMode'] as String,
        props: Map<String, dynamic>.from(json['props'] as Map),
        children: List<String>.from(json['children'] as List),
        watches: List<String>.from(json['watches'] as List),
        actions: json['actions'] != null
            ? Map<String, dynamic>.from(json['actions'] as Map)
            : null,
      );
    } catch (e) {
      throw OrcaParseException(
        'Failed to parse ComponentNode: $e',
        json,
      );
    }
  }

  ComponentNode copyWith({
    String? id,
    String? type,
    String? kind,
    String? childMode,
    Map<String, dynamic>? props,
    List<String>? children,
    List<String>? watches,
    Map<String, dynamic>? actions,
  }) {
    return ComponentNode(
      id: id ?? this.id,
      type: type ?? this.type,
      kind: kind ?? this.kind,
      childMode: childMode ?? this.childMode,
      props: props ?? this.props,
      children: children ?? this.children,
      watches: watches ?? this.watches,
      actions: actions ?? this.actions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'kind': kind,
        'childMode': childMode,
        'props': props,
        'children': children,
        'watches': watches,
        if (actions != null) 'actions': actions,
      };
}
