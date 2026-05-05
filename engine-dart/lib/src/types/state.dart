/// Declares initial state for a page.
class StateDefinition {
  final String key;
  final String scope; // "page" | "app"
  final dynamic initial;

  const StateDefinition({
    required this.key,
    required this.scope,
    required this.initial,
  });

  factory StateDefinition.fromJson(Map<String, dynamic> json) {
    return StateDefinition(
      key: json['key'] as String,
      scope: json['scope'] as String,
      initial: json['initial'],
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'scope': scope,
        'initial': initial,
      };
}
