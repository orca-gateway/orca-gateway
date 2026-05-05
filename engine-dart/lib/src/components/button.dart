import '../types/widget.dart';

// ── ElevatedButton ──────────────────────────────────────────

class ElevatedButton extends ButtonWidget {
  @override
  String get type => 'ElevatedButton';
  final Map<String, dynamic> _props;

  ElevatedButton({
    Widget? child,
    Map<String, dynamic>? actions,
    dynamic enabled,
    dynamic color,
    dynamic backgroundColor,
    dynamic foregroundColor,
    dynamic elevation,
    dynamic borderRadius,
    dynamic padding,
  }) : _props = {
          if (enabled != null) 'enabled': enabled,
          if (color != null) 'color': color,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (foregroundColor != null) 'foregroundColor': foregroundColor,
          if (elevation != null) 'elevation': elevation,
          if (borderRadius != null) 'borderRadius': borderRadius,
          if (padding != null) 'padding': padding,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── TextButton ──────────────────────────────────────────────

class TextButton extends ButtonWidget {
  @override
  String get type => 'TextButton';
  final Map<String, dynamic> _props;

  TextButton({
    Widget? child,
    Map<String, dynamic>? actions,
    dynamic enabled,
    dynamic foregroundColor,
    dynamic padding,
  }) : _props = {
          if (enabled != null) 'enabled': enabled,
          if (foregroundColor != null) 'foregroundColor': foregroundColor,
          if (padding != null) 'padding': padding,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── OutlinedButton ──────────────────────────────────────────

class OutlinedButton extends ButtonWidget {
  @override
  String get type => 'OutlinedButton';
  final Map<String, dynamic> _props;

  OutlinedButton({
    Widget? child,
    Map<String, dynamic>? actions,
    dynamic enabled,
    dynamic foregroundColor,
    dynamic borderColor,
    dynamic borderRadius,
    dynamic padding,
  }) : _props = {
          if (enabled != null) 'enabled': enabled,
          if (foregroundColor != null) 'foregroundColor': foregroundColor,
          if (borderColor != null) 'borderColor': borderColor,
          if (borderRadius != null) 'borderRadius': borderRadius,
          if (padding != null) 'padding': padding,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── IconButton ──────────────────────────────────────────────

class IconButton extends ButtonWidget {
  @override
  String get type => 'IconButton';
  final Map<String, dynamic> _props;

  IconButton({
    Widget? child,
    Map<String, dynamic>? actions,
    dynamic icon,
    dynamic size,
    dynamic color,
    dynamic splashRadius,
  }) : _props = {
          if (icon != null) 'icon': icon,
          if (size != null) 'size': size,
          if (color != null) 'color': color,
          if (splashRadius != null) 'splashRadius': splashRadius,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}
