// GENERATED FILE — DO NOT EDIT
// Source: schema/widget-registry.json
// Run: dart run tool/gen_widget_builders.dart
// For typed builders, see hand-written files in lib/src/components/.

import '../types/widget.dart';

/// A value prop. Accepts either a literal of type [T] or a `V.*` map.
typedef ValueOf<T> = Object;

/// AbsorbPointer widget (generated shell).
class AbsorbPointer extends SingleChildLayout {
  @override
  String get type => 'AbsorbPointer';
  final Map<String, dynamic> _props;

  AbsorbPointer({
    Widget? child,
    ValueOf<bool>? absorbing,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (absorbing != null) 'absorbing': absorbing,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Align widget (generated shell).
class Align extends SingleChildLayout {
  @override
  String get type => 'Align';
  final Map<String, dynamic> _props;

  Align({
    Widget? child,
    ValueOf<String>? alignment,
    ValueOf<num>? widthFactor,
    ValueOf<num>? heightFactor,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (alignment != null) 'alignment': alignment,
          if (widthFactor != null) 'widthFactor': widthFactor,
          if (heightFactor != null) 'heightFactor': heightFactor,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// AnimatedAlign widget (generated shell).
class AnimatedAlign extends SingleChildLayout {
  @override
  String get type => 'AnimatedAlign';
  final Map<String, dynamic> _props;

  AnimatedAlign({
    Widget? child,
    required ValueOf<String> alignment,
    required ValueOf<num> duration,
    ValueOf<String>? curve,
    ValueOf<num>? widthFactor,
    ValueOf<num>? heightFactor,
    Map<String, dynamic>? actions,
  })  : _props = {
          'alignment': alignment,
          'duration': duration,
          if (curve != null) 'curve': curve,
          if (widthFactor != null) 'widthFactor': widthFactor,
          if (heightFactor != null) 'heightFactor': heightFactor,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// AnimatedBuilder widget (generated shell).
class AnimatedBuilder extends MultiChildLayout {
  @override
  String get type => 'AnimatedBuilder';
  final Map<String, dynamic> _props;

  AnimatedBuilder({
    List<Widget> children = const [],
    String? animationId,
    required ValueOf<num> duration,
    ValueOf<String>? curve,
    ValueOf<bool>? repeat,
    ValueOf<bool>? reverse,
    ValueOf<bool>? autoStart,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (animationId != null) 'animationId': animationId,
          'duration': duration,
          if (curve != null) 'curve': curve,
          if (repeat != null) 'repeat': repeat,
          if (reverse != null) 'reverse': reverse,
          if (autoStart != null) 'autoStart': autoStart,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// AnimatedContainer widget (generated shell).
class AnimatedContainer extends SingleChildLayout {
  @override
  String get type => 'AnimatedContainer';
  final Map<String, dynamic> _props;

  AnimatedContainer({
    Widget? child,
    required ValueOf<num> duration,
    ValueOf<String>? curve,
    ValueOf<Map<String, dynamic>>? padding,
    ValueOf<Map<String, dynamic>>? margin,
    ValueOf<Map<String, dynamic>>? decoration,
    ValueOf<num>? width,
    ValueOf<num>? height,
    ValueOf<String>? alignment,
    ValueOf<String>? color,
    Map<String, dynamic>? actions,
  })  : _props = {
          'duration': duration,
          if (curve != null) 'curve': curve,
          if (padding != null) 'padding': padding,
          if (margin != null) 'margin': margin,
          if (decoration != null) 'decoration': decoration,
          if (width != null) 'width': width,
          if (height != null) 'height': height,
          if (alignment != null) 'alignment': alignment,
          if (color != null) 'color': color,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// AnimatedOpacity widget (generated shell).
class AnimatedOpacity extends SingleChildLayout {
  @override
  String get type => 'AnimatedOpacity';
  final Map<String, dynamic> _props;

  AnimatedOpacity({
    Widget? child,
    required ValueOf<num> opacity,
    required ValueOf<num> duration,
    ValueOf<String>? curve,
    Map<String, dynamic>? actions,
  })  : _props = {
          'opacity': opacity,
          'duration': duration,
          if (curve != null) 'curve': curve,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// AnimatedSwitcher widget (generated shell).
class AnimatedSwitcher extends SingleChildLayout {
  @override
  String get type => 'AnimatedSwitcher';
  final Map<String, dynamic> _props;

  AnimatedSwitcher({
    Widget? child,
    required ValueOf<num> duration,
    Map<String, dynamic>? actions,
  })  : _props = {
          'duration': duration,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// AspectRatio widget (generated shell).
class AspectRatio extends SingleChildLayout {
  @override
  String get type => 'AspectRatio';
  final Map<String, dynamic> _props;

  AspectRatio({
    Widget? child,
    required ValueOf<num> aspectRatio,
    Map<String, dynamic>? actions,
  })  : _props = {
          'aspectRatio': aspectRatio,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// BackdropFilter widget (generated shell).
class BackdropFilter extends SingleChildLayout {
  @override
  String get type => 'BackdropFilter';
  final Map<String, dynamic> _props;

  BackdropFilter({
    Widget? child,
    ValueOf<num>? blurX,
    ValueOf<num>? blurY,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (blurX != null) 'blurX': blurX,
          if (blurY != null) 'blurY': blurY,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Baseline widget (generated shell).
class Baseline extends SingleChildLayout {
  @override
  String get type => 'Baseline';
  final Map<String, dynamic> _props;

  Baseline({
    Widget? child,
    required ValueOf<num> baseline,
    required ValueOf<String> baselineType,
    Map<String, dynamic>? actions,
  })  : _props = {
          'baseline': baseline,
          'baselineType': baselineType,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// BlurView widget (generated shell).
class BlurView extends SingleChildLayout {
  @override
  String get type => 'BlurView';
  final Map<String, dynamic> _props;

  BlurView({
    Widget? child,
    ValueOf<num>? blurX,
    ValueOf<num>? blurY,
    ValueOf<String>? overlayColor,
    ValueOf<num>? borderRadius,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (blurX != null) 'blurX': blurX,
          if (blurY != null) 'blurY': blurY,
          if (overlayColor != null) 'overlayColor': overlayColor,
          if (borderRadius != null) 'borderRadius': borderRadius,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// BottomSheet widget (generated shell).
class BottomSheet extends SingleChildLayout {
  @override
  String get type => 'BottomSheet';
  final Map<String, dynamic> _props;

  BottomSheet({
    Widget? child,
    ValueOf<bool>? dismissible,
    ValueOf<String>? backgroundColor,
    ValueOf<num>? borderRadius,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (dismissible != null) 'dismissible': dismissible,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (borderRadius != null) 'borderRadius': borderRadius,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Checkbox widget (generated shell).
class Checkbox extends InputWidget {
  @override
  String get type => 'Checkbox';
  final Map<String, dynamic> _props;

  Checkbox({
    ValueOf<bool>? value,
    ValueOf<String>? label,
    ValueOf<String>? activeColor,
    ValueOf<bool>? enabled,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (value != null) 'value': value,
          if (label != null) 'label': label,
          if (activeColor != null) 'activeColor': activeColor,
          if (enabled != null) 'enabled': enabled,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// CircularProgressIndicator widget (generated shell).
class CircularProgressIndicator extends PrimitiveWidget {
  @override
  String get type => 'CircularProgressIndicator';
  final Map<String, dynamic> _props;

  CircularProgressIndicator({
    ValueOf<String>? color,
    ValueOf<num>? strokeWidth,
    ValueOf<num>? value,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (color != null) 'color': color,
          if (strokeWidth != null) 'strokeWidth': strokeWidth,
          if (value != null) 'value': value,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// ClipOval widget (generated shell).
class ClipOval extends SingleChildLayout {
  @override
  String get type => 'ClipOval';
  final Map<String, dynamic> _props;

  ClipOval({
    Widget? child,
    Map<String, dynamic>? actions,
  })  : _props = {
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// ClipRect widget (generated shell).
class ClipRect extends SingleChildLayout {
  @override
  String get type => 'ClipRect';
  final Map<String, dynamic> _props;

  ClipRect({
    Widget? child,
    Map<String, dynamic>? actions,
  })  : _props = {
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// ClipRRect widget (generated shell).
class ClipRRect extends SingleChildLayout {
  @override
  String get type => 'ClipRRect';
  final Map<String, dynamic> _props;

  ClipRRect({
    Widget? child,
    ValueOf<Object>? borderRadius,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (borderRadius != null) 'borderRadius': borderRadius,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// ColorFiltered widget (generated shell).
class ColorFiltered extends SingleChildLayout {
  @override
  String get type => 'ColorFiltered';
  final Map<String, dynamic> _props;

  ColorFiltered({
    Widget? child,
    ValueOf<String>? color,
    ValueOf<String>? blendMode,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (color != null) 'color': color,
          if (blendMode != null) 'blendMode': blendMode,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// ConstrainedBox widget (generated shell).
class ConstrainedBox extends SingleChildLayout {
  @override
  String get type => 'ConstrainedBox';
  final Map<String, dynamic> _props;

  ConstrainedBox({
    Widget? child,
    required ValueOf<Map<String, dynamic>> constraints,
    Map<String, dynamic>? actions,
  })  : _props = {
          'constraints': constraints,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// CustomScrollView widget (generated shell).
class CustomScrollView extends MultiChildLayout {
  @override
  String get type => 'CustomScrollView';
  final Map<String, dynamic> _props;

  CustomScrollView({
    List<Widget> slivers = const [],
    ValueOf<String>? scrollDirection,
    ValueOf<bool>? reverse,
    ValueOf<bool>? shrinkWrap,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (scrollDirection != null) 'scrollDirection': scrollDirection,
          if (reverse != null) 'reverse': reverse,
          if (shrinkWrap != null) 'shrinkWrap': shrinkWrap,
        } {
    this.children = slivers;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// DecoratedBox widget (generated shell).
class DecoratedBox extends SingleChildLayout {
  @override
  String get type => 'DecoratedBox';
  final Map<String, dynamic> _props;

  DecoratedBox({
    Widget? child,
    required ValueOf<Map<String, dynamic>> decoration,
    ValueOf<String>? position,
    Map<String, dynamic>? actions,
  })  : _props = {
          'decoration': decoration,
          if (position != null) 'position': position,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// DefaultTextStyle widget (generated shell).
class DefaultTextStyle extends SingleChildLayout {
  @override
  String get type => 'DefaultTextStyle';
  final Map<String, dynamic> _props;

  DefaultTextStyle({
    Widget? child,
    required ValueOf<Map<String, dynamic>> style,
    ValueOf<String>? textAlign,
    ValueOf<num>? maxLines,
    ValueOf<String>? overflow,
    Map<String, dynamic>? actions,
  })  : _props = {
          'style': style,
          if (textAlign != null) 'textAlign': textAlign,
          if (maxLines != null) 'maxLines': maxLines,
          if (overflow != null) 'overflow': overflow,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Dialog widget (generated shell).
class Dialog extends SingleChildLayout {
  @override
  String get type => 'Dialog';
  final Map<String, dynamic> _props;

  Dialog({
    Widget? child,
    ValueOf<bool>? dismissible,
    ValueOf<String>? backgroundColor,
    ValueOf<num>? borderRadius,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (dismissible != null) 'dismissible': dismissible,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (borderRadius != null) 'borderRadius': borderRadius,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// FallbackPrompt widget (generated shell).
class FallbackPrompt extends PrimitiveWidget {
  @override
  String get type => 'FallbackPrompt';
  final Map<String, dynamic> _props;

  FallbackPrompt({
    required ValueOf<String> title,
    required ValueOf<String> body,
    ValueOf<String>? ctaLabel,
    ValueOf<String>? ctaUrl,
    required ValueOf<String> severity,
    Map<String, dynamic>? actions,
  })  : _props = {
          'title': title,
          'body': body,
          if (ctaLabel != null) 'ctaLabel': ctaLabel,
          if (ctaUrl != null) 'ctaUrl': ctaUrl,
          'severity': severity,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// FittedBox widget (generated shell).
class FittedBox extends SingleChildLayout {
  @override
  String get type => 'FittedBox';
  final Map<String, dynamic> _props;

  FittedBox({
    Widget? child,
    ValueOf<String>? fit,
    ValueOf<String>? alignment,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (fit != null) 'fit': fit,
          if (alignment != null) 'alignment': alignment,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// FloatingActionButton widget (generated shell).
class FloatingActionButton extends ButtonWidget {
  @override
  String get type => 'FloatingActionButton';
  final Map<String, dynamic> _props;

  FloatingActionButton({
    Widget? child,
    ValueOf<bool>? enabled,
    ValueOf<String>? backgroundColor,
    ValueOf<num>? elevation,
    ValueOf<bool>? mini,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (enabled != null) 'enabled': enabled,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (elevation != null) 'elevation': elevation,
          if (mini != null) 'mini': mini,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Form widget (generated shell).
class Form extends SingleChildLayout {
  @override
  String get type => 'Form';
  final Map<String, dynamic> _props;

  Form({
    Widget? child,
    Map<String, dynamic>? actions,
  })  : _props = {
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// FractionallySizedBox widget (generated shell).
class FractionallySizedBox extends SingleChildLayout {
  @override
  String get type => 'FractionallySizedBox';
  final Map<String, dynamic> _props;

  FractionallySizedBox({
    Widget? child,
    ValueOf<num>? widthFactor,
    ValueOf<num>? heightFactor,
    ValueOf<String>? alignment,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (widthFactor != null) 'widthFactor': widthFactor,
          if (heightFactor != null) 'heightFactor': heightFactor,
          if (alignment != null) 'alignment': alignment,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// GestureDetector widget (generated shell).
class GestureDetector extends SingleChildLayout {
  @override
  String get type => 'GestureDetector';
  final Map<String, dynamic> _props;

  GestureDetector({
    Widget? child,
    Map<String, dynamic>? actions,
  })  : _props = {
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// GridView widget (generated shell).
class GridView extends MultiChildLayout {
  @override
  String get type => 'GridView';
  final Map<String, dynamic> _props;

  GridView({
    List<Widget> children = const [],
    required ValueOf<num> crossAxisCount,
    ValueOf<num>? mainAxisSpacing,
    ValueOf<num>? crossAxisSpacing,
    ValueOf<num>? childAspectRatio,
    ValueOf<String>? scrollDirection,
    ValueOf<Map<String, dynamic>>? padding,
    ValueOf<bool>? shrinkWrap,
    Map<String, dynamic>? actions,
  })  : _props = {
          'crossAxisCount': crossAxisCount,
          if (mainAxisSpacing != null) 'mainAxisSpacing': mainAxisSpacing,
          if (crossAxisSpacing != null) 'crossAxisSpacing': crossAxisSpacing,
          if (childAspectRatio != null) 'childAspectRatio': childAspectRatio,
          if (scrollDirection != null) 'scrollDirection': scrollDirection,
          if (padding != null) 'padding': padding,
          if (shrinkWrap != null) 'shrinkWrap': shrinkWrap,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Hero widget (generated shell).
class Hero extends SingleChildLayout {
  @override
  String get type => 'Hero';
  final Map<String, dynamic> _props;

  Hero({
    Widget? child,
    required ValueOf<String> tag,
    Map<String, dynamic>? actions,
  })  : _props = {
          'tag': tag,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// IgnorePointer widget (generated shell).
class IgnorePointer extends SingleChildLayout {
  @override
  String get type => 'IgnorePointer';
  final Map<String, dynamic> _props;

  IgnorePointer({
    Widget? child,
    ValueOf<bool>? ignoring,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (ignoring != null) 'ignoring': ignoring,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// ImageIcon widget (generated shell).
class ImageIcon extends PrimitiveWidget {
  @override
  String get type => 'ImageIcon';
  final Map<String, dynamic> _props;

  ImageIcon({
    required ValueOf<String> src,
    ValueOf<num>? size,
    ValueOf<String>? color,
    Map<String, dynamic>? actions,
  })  : _props = {
          'src': src,
          if (size != null) 'size': size,
          if (color != null) 'color': color,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// InkWell widget (generated shell).
class InkWell extends SingleChildLayout {
  @override
  String get type => 'InkWell';
  final Map<String, dynamic> _props;

  InkWell({
    Widget? child,
    ValueOf<num>? borderRadius,
    ValueOf<String>? splashColor,
    ValueOf<String>? highlightColor,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (borderRadius != null) 'borderRadius': borderRadius,
          if (splashColor != null) 'splashColor': splashColor,
          if (highlightColor != null) 'highlightColor': highlightColor,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// InteractiveViewer widget (generated shell).
class InteractiveViewer extends SingleChildLayout {
  @override
  String get type => 'InteractiveViewer';
  final Map<String, dynamic> _props;

  InteractiveViewer({
    Widget? child,
    ValueOf<num>? minScale,
    ValueOf<num>? maxScale,
    ValueOf<bool>? panEnabled,
    ValueOf<bool>? scaleEnabled,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (minScale != null) 'minScale': minScale,
          if (maxScale != null) 'maxScale': maxScale,
          if (panEnabled != null) 'panEnabled': panEnabled,
          if (scaleEnabled != null) 'scaleEnabled': scaleEnabled,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// IntrinsicHeight widget (generated shell).
class IntrinsicHeight extends SingleChildLayout {
  @override
  String get type => 'IntrinsicHeight';
  final Map<String, dynamic> _props;

  IntrinsicHeight({
    Widget? child,
    Map<String, dynamic>? actions,
  })  : _props = {
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// IntrinsicWidth widget (generated shell).
class IntrinsicWidth extends SingleChildLayout {
  @override
  String get type => 'IntrinsicWidth';
  final Map<String, dynamic> _props;

  IntrinsicWidth({
    Widget? child,
    ValueOf<num>? stepWidth,
    ValueOf<num>? stepHeight,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (stepWidth != null) 'stepWidth': stepWidth,
          if (stepHeight != null) 'stepHeight': stepHeight,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// LimitedBox widget (generated shell).
class LimitedBox extends SingleChildLayout {
  @override
  String get type => 'LimitedBox';
  final Map<String, dynamic> _props;

  LimitedBox({
    Widget? child,
    ValueOf<num>? maxWidth,
    ValueOf<num>? maxHeight,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (maxWidth != null) 'maxWidth': maxWidth,
          if (maxHeight != null) 'maxHeight': maxHeight,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// LinearProgressIndicator widget (generated shell).
class LinearProgressIndicator extends PrimitiveWidget {
  @override
  String get type => 'LinearProgressIndicator';
  final Map<String, dynamic> _props;

  LinearProgressIndicator({
    ValueOf<num>? value,
    ValueOf<String>? color,
    ValueOf<String>? backgroundColor,
    ValueOf<num>? minHeight,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (value != null) 'value': value,
          if (color != null) 'color': color,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (minHeight != null) 'minHeight': minHeight,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Offstage widget (generated shell).
class Offstage extends SingleChildLayout {
  @override
  String get type => 'Offstage';
  final Map<String, dynamic> _props;

  Offstage({
    Widget? child,
    ValueOf<bool>? offstage,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (offstage != null) 'offstage': offstage,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// PageView widget (generated shell).
class PageView extends MultiChildLayout {
  @override
  String get type => 'PageView';
  final Map<String, dynamic> _props;

  PageView({
    List<Widget> children = const [],
    ValueOf<String>? scrollDirection,
    ValueOf<bool>? pageSnapping,
    ValueOf<bool>? reverse,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (scrollDirection != null) 'scrollDirection': scrollDirection,
          if (pageSnapping != null) 'pageSnapping': pageSnapping,
          if (reverse != null) 'reverse': reverse,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// PullToRefresh widget (generated shell).
class PullToRefresh extends SingleChildLayout {
  @override
  String get type => 'PullToRefresh';
  final Map<String, dynamic> _props;

  PullToRefresh({
    Widget? child,
    ValueOf<String>? color,
    ValueOf<String>? backgroundColor,
    ValueOf<num>? displacement,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (color != null) 'color': color,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (displacement != null) 'displacement': displacement,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Radio widget (generated shell).
class Radio extends InputWidget {
  @override
  String get type => 'Radio';
  final Map<String, dynamic> _props;

  Radio({
    ValueOf<String>? value,
    ValueOf<String>? groupValue,
    ValueOf<String>? activeColor,
    ValueOf<bool>? enabled,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (value != null) 'value': value,
          if (groupValue != null) 'groupValue': groupValue,
          if (activeColor != null) 'activeColor': activeColor,
          if (enabled != null) 'enabled': enabled,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// ReorderableListView widget (generated shell).
class ReorderableListView extends MultiChildLayout {
  @override
  String get type => 'ReorderableListView';
  final Map<String, dynamic> _props;

  ReorderableListView({
    List<Widget> children = const [],
    ValueOf<String>? scrollDirection,
    ValueOf<Map<String, dynamic>>? padding,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (scrollDirection != null) 'scrollDirection': scrollDirection,
          if (padding != null) 'padding': padding,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// RichText widget (generated shell).
class RichText extends PrimitiveWidget {
  @override
  String get type => 'RichText';
  final Map<String, dynamic> _props;

  RichText({
    required ValueOf<Map<String, dynamic>> text,
    ValueOf<String>? textAlign,
    ValueOf<num>? maxLines,
    ValueOf<String>? overflow,
    Map<String, dynamic>? actions,
  })  : _props = {
          'text': text,
          if (textAlign != null) 'textAlign': textAlign,
          if (maxLines != null) 'maxLines': maxLines,
          if (overflow != null) 'overflow': overflow,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// RotatedBox widget (generated shell).
class RotatedBox extends SingleChildLayout {
  @override
  String get type => 'RotatedBox';
  final Map<String, dynamic> _props;

  RotatedBox({
    Widget? child,
    required ValueOf<num> quarterTurns,
    Map<String, dynamic>? actions,
  })  : _props = {
          'quarterTurns': quarterTurns,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// SafeArea widget (generated shell).
class SafeArea extends SingleChildLayout {
  @override
  String get type => 'SafeArea';
  final Map<String, dynamic> _props;

  SafeArea({
    Widget? child,
    ValueOf<bool>? top,
    ValueOf<bool>? bottom,
    ValueOf<bool>? left,
    ValueOf<bool>? right,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (top != null) 'top': top,
          if (bottom != null) 'bottom': bottom,
          if (left != null) 'left': left,
          if (right != null) 'right': right,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Scrollbar widget (generated shell).
class Scrollbar extends SingleChildLayout {
  @override
  String get type => 'Scrollbar';
  final Map<String, dynamic> _props;

  Scrollbar({
    Widget? child,
    ValueOf<bool>? thumbVisibility,
    ValueOf<num>? thickness,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (thumbVisibility != null) 'thumbVisibility': thumbVisibility,
          if (thickness != null) 'thickness': thickness,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// SelectableText widget (generated shell).
class SelectableText extends PrimitiveWidget {
  @override
  String get type => 'SelectableText';
  final Map<String, dynamic> _props;

  SelectableText({
    required ValueOf<String> data,
    ValueOf<Map<String, dynamic>>? style,
    ValueOf<String>? textAlign,
    ValueOf<num>? maxLines,
    Map<String, dynamic>? actions,
  })  : _props = {
          'data': data,
          if (style != null) 'style': style,
          if (textAlign != null) 'textAlign': textAlign,
          if (maxLines != null) 'maxLines': maxLines,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Slider widget (generated shell).
class Slider extends InputWidget {
  @override
  String get type => 'Slider';
  final Map<String, dynamic> _props;

  Slider({
    ValueOf<num>? value,
    ValueOf<num>? min,
    ValueOf<num>? max,
    ValueOf<num>? divisions,
    ValueOf<String>? activeColor,
    ValueOf<bool>? enabled,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (value != null) 'value': value,
          if (min != null) 'min': min,
          if (max != null) 'max': max,
          if (divisions != null) 'divisions': divisions,
          if (activeColor != null) 'activeColor': activeColor,
          if (enabled != null) 'enabled': enabled,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// SliverAppBar widget (generated shell).
class SliverAppBar extends StructureWidget {
  @override
  String get type => 'SliverAppBar';
  @override
  String get childMode => 'none';
  final Map<String, dynamic> _props;
  final Widget? _title;
  final Widget? _leading;
  final Widget? _flexibleSpace;

  SliverAppBar({
    Widget? title,
    Widget? leading,
    Widget? flexibleSpace,
    ValueOf<String>? backgroundColor,
    ValueOf<num>? elevation,
    ValueOf<bool>? centerTitle,
    ValueOf<bool>? floating,
    ValueOf<bool>? pinned,
    ValueOf<bool>? snap,
    ValueOf<num>? expandedHeight,
    ValueOf<num>? collapsedHeight,
    Map<String, dynamic>? actionTriggers,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (elevation != null) 'elevation': elevation,
          if (centerTitle != null) 'centerTitle': centerTitle,
          if (floating != null) 'floating': floating,
          if (pinned != null) 'pinned': pinned,
          if (snap != null) 'snap': snap,
          if (expandedHeight != null) 'expandedHeight': expandedHeight,
          if (collapsedHeight != null) 'collapsedHeight': collapsedHeight,
          if (actionTriggers != null) 'actionTriggers': actionTriggers,
        },
        _title = title,
        _leading = leading,
        _flexibleSpace = flexibleSpace {
    this.actions = actions;
  }

  @override
  List<SlotEntry> getSlotWidgets() {
    final slots = <SlotEntry>[];
    if (_title != null) slots.add(SlotEntry('title', _title));
    if (_leading != null) slots.add(SlotEntry('leading', _leading));
    if (_flexibleSpace != null) slots.add(SlotEntry('flexibleSpace', _flexibleSpace));
    return slots;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// SliverGrid widget (generated shell).
class SliverGrid extends MultiChildLayout {
  @override
  String get type => 'SliverGrid';
  final Map<String, dynamic> _props;

  SliverGrid({
    List<Widget> children = const [],
    required ValueOf<num> crossAxisCount,
    ValueOf<num>? mainAxisSpacing,
    ValueOf<num>? crossAxisSpacing,
    ValueOf<num>? childAspectRatio,
    Map<String, dynamic>? actions,
  })  : _props = {
          'crossAxisCount': crossAxisCount,
          if (mainAxisSpacing != null) 'mainAxisSpacing': mainAxisSpacing,
          if (crossAxisSpacing != null) 'crossAxisSpacing': crossAxisSpacing,
          if (childAspectRatio != null) 'childAspectRatio': childAspectRatio,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// SliverList widget (generated shell).
class SliverList extends MultiChildLayout {
  @override
  String get type => 'SliverList';
  final Map<String, dynamic> _props;

  SliverList({
    List<Widget> children = const [],
    Map<String, dynamic>? actions,
  })  : _props = {
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// SliverToBoxAdapter widget (generated shell).
class SliverToBoxAdapter extends SingleChildLayout {
  @override
  String get type => 'SliverToBoxAdapter';
  final Map<String, dynamic> _props;

  SliverToBoxAdapter({
    Widget? child,
    Map<String, dynamic>? actions,
  })  : _props = {
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// SnackBar widget (generated shell).
class SnackBar extends PrimitiveWidget {
  @override
  String get type => 'SnackBar';
  final Map<String, dynamic> _props;

  SnackBar({
    required ValueOf<String> content,
    ValueOf<num>? duration,
    ValueOf<String>? actionLabel,
    ValueOf<String>? backgroundColor,
    Map<String, dynamic>? actions,
  })  : _props = {
          'content': content,
          if (duration != null) 'duration': duration,
          if (actionLabel != null) 'actionLabel': actionLabel,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// SubPage widget (generated shell).
class SubPage extends SingleChildLayout {
  @override
  String get type => 'SubPage';
  final Map<String, dynamic> _props;

  SubPage({
    Widget? child,
    required String key,
    required ValueOf<String> pageId,
    Map<String, dynamic>? params,
    Map<String, dynamic>? actions,
  })  : _props = {
          'key': key,
          'pageId': pageId,
          if (params != null) 'params': params,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Switch widget (generated shell).
class SwitchWidget extends InputWidget {
  @override
  String get type => 'Switch';
  final Map<String, dynamic> _props;

  SwitchWidget({
    ValueOf<bool>? value,
    ValueOf<String>? activeColor,
    ValueOf<bool>? enabled,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (value != null) 'value': value,
          if (activeColor != null) 'activeColor': activeColor,
          if (enabled != null) 'enabled': enabled,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Table widget (generated shell).
class Table extends MultiChildLayout {
  @override
  String get type => 'Table';
  final Map<String, dynamic> _props;

  Table({
    List<Widget> children = const [],
    ValueOf<Map<num, num>>? columnWidths,
    ValueOf<num>? defaultColumnWidth,
    ValueOf<Map<String, dynamic>>? border,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (columnWidths != null) 'columnWidths': columnWidths,
          if (defaultColumnWidth != null) 'defaultColumnWidth': defaultColumnWidth,
          if (border != null) 'border': border,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// TextFormField widget (generated shell).
class TextFormField extends InputWidget {
  @override
  String get type => 'TextFormField';
  final Map<String, dynamic> _props;

  TextFormField({
    ValueOf<String>? value,
    ValueOf<String>? placeholder,
    ValueOf<String>? inputType,
    ValueOf<bool>? obscureText,
    ValueOf<num>? maxLines,
    ValueOf<num>? maxLength,
    ValueOf<bool>? enabled,
    ValueOf<Map<String, dynamic>>? style,
    ValueOf<String>? validator,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (value != null) 'value': value,
          if (placeholder != null) 'placeholder': placeholder,
          if (inputType != null) 'inputType': inputType,
          if (obscureText != null) 'obscureText': obscureText,
          if (maxLines != null) 'maxLines': maxLines,
          if (maxLength != null) 'maxLength': maxLength,
          if (enabled != null) 'enabled': enabled,
          if (style != null) 'style': style,
          if (validator != null) 'validator': validator,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Tooltip widget (generated shell).
class Tooltip extends SingleChildLayout {
  @override
  String get type => 'Tooltip';
  final Map<String, dynamic> _props;

  Tooltip({
    Widget? child,
    required ValueOf<String> message,
    Map<String, dynamic>? actions,
  })  : _props = {
          'message': message,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Transform widget (generated shell).
class Transform extends SingleChildLayout {
  @override
  String get type => 'Transform';
  final Map<String, dynamic> _props;

  Transform({
    Widget? child,
    ValueOf<List<num>>? transform,
    ValueOf<String>? alignment,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (transform != null) 'transform': transform,
          if (alignment != null) 'alignment': alignment,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// UnsupportedWidgetPlaceholder widget (generated shell).
class UnsupportedWidgetPlaceholder extends PrimitiveWidget {
  @override
  String get type => 'UnsupportedWidgetPlaceholder';
  final Map<String, dynamic> _props;

  UnsupportedWidgetPlaceholder({
    required ValueOf<String> widgetType,
    ValueOf<String>? displayName,
    ValueOf<String>? iconName,
    ValueOf<String>? docsUrl,
    ValueOf<String>? reason,
    Map<String, dynamic>? actions,
  })  : _props = {
          'widgetType': widgetType,
          if (displayName != null) 'displayName': displayName,
          if (iconName != null) 'iconName': iconName,
          if (docsUrl != null) 'docsUrl': docsUrl,
          if (reason != null) 'reason': reason,
        } {
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

/// Wrap widget (generated shell).
class Wrap extends MultiChildLayout {
  @override
  String get type => 'Wrap';
  final Map<String, dynamic> _props;

  Wrap({
    List<Widget> children = const [],
    ValueOf<num>? spacing,
    ValueOf<num>? runSpacing,
    ValueOf<String>? alignment,
    ValueOf<String>? crossAxisAlignment,
    Map<String, dynamic>? actions,
  })  : _props = {
          if (spacing != null) 'spacing': spacing,
          if (runSpacing != null) 'runSpacing': runSpacing,
          if (alignment != null) 'alignment': alignment,
          if (crossAxisAlignment != null) 'crossAxisAlignment': crossAxisAlignment,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map<String, dynamic>.from(_props);
}

