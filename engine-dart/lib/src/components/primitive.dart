import '../types/widget.dart';

// ── Text ────────────────────────────────────────────────────

class Text extends PrimitiveWidget {
  @override
  String get type => 'Text';
  final Map<String, dynamic> _props;

  Text({
    required dynamic data,
    dynamic style,
    dynamic textAlign,
    dynamic maxLines,
    dynamic overflow,
    Map<String, dynamic>? actions,
  }) : _props = {
          'data': data,
          if (style != null) 'style': style,
          if (textAlign != null) 'textAlign': textAlign,
          if (maxLines != null) 'maxLines': maxLines,
          if (overflow != null) 'overflow': overflow,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Icon ────────────────────────────────────────────────────

class Icon extends PrimitiveWidget {
  @override
  String get type => 'Icon';
  final Map<String, dynamic> _props;

  /// At least one of [icon] (Material name) or [src] (network URL) is required.
  /// When [src] is provided it takes precedence on the client side.
  Icon({
    dynamic icon,
    dynamic src,
    dynamic size,
    dynamic color,
    Map<String, dynamic>? actions,
  })  : assert(icon != null || src != null,
            'Icon requires at least one of `icon` or `src`.'),
        _props = {
          if (icon != null) 'icon': icon,
          if (src != null) 'src': src,
          if (size != null) 'size': size,
          if (color != null) 'color': color,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Image ───────────────────────────────────────────────────

class Image extends PrimitiveWidget {
  @override
  String get type => 'Image';
  final Map<String, dynamic> _props;

  Image({
    required dynamic src,
    dynamic fit,
    dynamic width,
    dynamic height,
    dynamic borderRadius,
    Map<String, dynamic>? actions,
  }) : _props = {
          'src': src,
          if (fit != null) 'fit': fit,
          if (width != null) 'width': width,
          if (height != null) 'height': height,
          if (borderRadius != null) 'borderRadius': borderRadius,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Spacer ──────────────────────────────────────────────────

class Spacer extends PrimitiveWidget {
  @override
  String get type => 'Spacer';
  final Map<String, dynamic> _props;

  Spacer({dynamic flex}) : _props = {if (flex != null) 'flex': flex};

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Divider ─────────────────────────────────────────────────

class Divider extends PrimitiveWidget {
  @override
  String get type => 'Divider';
  final Map<String, dynamic> _props;

  Divider({dynamic height, dynamic thickness, dynamic color, dynamic indent})
      : _props = {
          if (height != null) 'height': height,
          if (thickness != null) 'thickness': thickness,
          if (color != null) 'color': color,
          if (indent != null) 'indent': indent,
        };

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}
