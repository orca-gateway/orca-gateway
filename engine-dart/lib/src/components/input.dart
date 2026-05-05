import '../types/widget.dart';

// ── TextField ───────────────────────────────────────────────

class TextField extends InputWidget {
  @override
  String get type => 'TextField';
  final Map<String, dynamic> _props;

  TextField({
    Map<String, dynamic>? actions,
    dynamic value,
    dynamic placeholder,
    dynamic inputType,
    dynamic obscureText,
    dynamic maxLines,
    dynamic maxLength,
    dynamic enabled,
    dynamic style,
  }) : _props = {
          if (value != null) 'value': value,
          if (placeholder != null) 'placeholder': placeholder,
          if (inputType != null) 'inputType': inputType,
          if (obscureText != null) 'obscureText': obscureText,
          if (maxLines != null) 'maxLines': maxLines,
          if (maxLength != null) 'maxLength': maxLength,
          if (enabled != null) 'enabled': enabled,
          if (style != null) 'style': style,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}
