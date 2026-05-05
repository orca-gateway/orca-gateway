import 'package:flutter/material.dart'
    show
        BorderSide,
        ButtonStyle,
        ElevatedButton,
        TextButton,
        OutlinedButton,
        FloatingActionButton,
        WidgetStateProperty,
        WidgetState,
        RoundedRectangleBorder,
        Theme,
        ThemeData,
        Tooltip;
import 'package:flutter/widgets.dart';
import '../rendering/component_context.dart';
import '../rendering/component_registry.dart';
import 'builder_helpers.dart';

/// Register all button component builders.
void registerButtonBuilders(ComponentRegistry registry) {
  registry.register('ElevatedButton', _buildElevatedButton);
  registry.register('TextButton', _buildTextButton);
  registry.register('IconButton', _buildIconButton);
  registry.register('OutlinedButton', _buildOutlinedButton);
  registry.register('FloatingActionButton', _buildFAB);
}

Widget _buildElevatedButton(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final fgColor = parseColor(ctx.prop('foregroundColor'));
  final borderRadius = ctx.prop<num>('borderRadius')?.toDouble();
  final elevation = ctx.prop<num>('elevation')?.toDouble();
  final padding = parseEdgeInsets(ctx.prop('padding'));
  final splashColor = parseColor(ctx.prop('splashColor'));
  final highlightColor = parseColor(ctx.prop('highlightColor'));
  final autofocus = ctx.propOr<bool>('autofocus', false);

  final baseStyle =
      (bgColor != null ||
          fgColor != null ||
          borderRadius != null ||
          elevation != null ||
          padding != null)
      ? ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: elevation,
          padding: padding,
          shape: borderRadius != null
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                )
              : null,
        )
      : null;
  final style = _applyOverlay(baseStyle, splashColor, highlightColor);

  return ElevatedButton(
    onPressed: enabled ? () => ctx.fireAction('onTap') : null,
    onLongPress: enabled ? () => ctx.fireAction('onLongPress') : null,
    autofocus: autofocus,
    style: style,
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : null,
  );
}

Widget _buildTextButton(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final color = parseColor(ctx.prop('color'));
  final splashColor = parseColor(ctx.prop('splashColor'));
  final highlightColor = parseColor(ctx.prop('highlightColor'));
  final autofocus = ctx.propOr<bool>('autofocus', false);

  final baseStyle = color != null
      ? TextButton.styleFrom(foregroundColor: color)
      : null;
  final style = _applyOverlay(baseStyle, splashColor, highlightColor);

  return Theme(
    data: ThemeData(),
    child: TextButton(
      onPressed: enabled ? () => ctx.fireAction('onTap') : null,
      onLongPress: enabled ? () => ctx.fireAction('onLongPress') : null,
      autofocus: autofocus,
      style: style,
      child: ctx.childIds.isNotEmpty ? renderChild(ctx) : const Text(''),
    ),
  );
}

Widget _buildIconButton(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final size = (ctx.prop<num>('size'))?.toDouble() ?? 24;
  final color = parseColor(ctx.prop('color'));
  final tooltipText = ctx.prop<String>('tooltip');
  final padding = parseEdgeInsets(ctx.prop('padding'));
  final alignment = ctx.prop<String>('alignment') != null
      ? parseAlignment(ctx.prop<String>('alignment'))
      : Alignment.center;
  final constraints = parseBoxConstraints(ctx.prop('constraints'));

  Widget child = ctx.childIds.isNotEmpty
      ? renderChild(ctx)
      : SizedBox(width: size, height: size);

  if (color != null) {
    child = IconTheme(
      data: IconThemeData(color: color, size: size),
      child: child,
    );
  }

  final innerBox = SizedBox(
    width: size + 16,
    height: size + 16,
    child: padding != null
        ? Padding(padding: padding, child: Align(alignment: alignment, child: child))
        : Center(child: child),
  );

  Widget button = Opacity(
    opacity: enabled ? 1.0 : 0.38,
    child: innerBox,
  );

  // Only wrap in a GestureDetector when the author actually attached tap
  // or long-press actions to THIS node. Previously the builder always
  // registered onTap/onLongPress callbacks — even when node.actions was
  // empty — and set HitTestBehavior.opaque, which made the IconButton's
  // internal GestureDetector absorb every tap. Outer wrappers (e.g. an
  // author wrapping IconButton in GestureDetector to put Sequential(
  // DebugLog, ServerAction) on onTap) then never received the event, and
  // the author's action chain never ran.
  //
  // With this gate: an IconButton whose actions map is empty behaves as a
  // pass-through, and the outer GestureDetector in the author's tree
  // receives the tap and fires normally. An IconButton that DOES carry
  // actions still uses HitTestBehavior.opaque so the whole hit-box fires
  // onTap (not just the icon glyph pixels).
  final actions = ctx.node.actions;
  final hasOnTap = actions?.containsKey('onTap') ?? false;
  final hasOnLongPress = actions?.containsKey('onLongPress') ?? false;
  if (enabled && (hasOnTap || hasOnLongPress)) {
    button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasOnTap ? () => ctx.fireAction('onTap') : null,
      onLongPress: hasOnLongPress ? () => ctx.fireAction('onLongPress') : null,
      child: button,
    );
  }

  if (constraints != null) {
    button = ConstrainedBox(constraints: constraints, child: button);
  }

  if (tooltipText != null && tooltipText.isNotEmpty) {
    button = Tooltip(message: tooltipText, child: button);
  }

  return button;
}

Widget _buildOutlinedButton(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final borderColor = parseColor(ctx.prop('borderColor'));
  final color = parseColor(ctx.prop('color'));
  final splashColor = parseColor(ctx.prop('splashColor'));
  final highlightColor = parseColor(ctx.prop('highlightColor'));
  final autofocus = ctx.propOr<bool>('autofocus', false);

  final baseStyle = (borderColor != null || color != null)
      ? OutlinedButton.styleFrom(
          foregroundColor: color,
          side: borderColor != null ? BorderSide(color: borderColor) : null,
        )
      : null;
  final style = _applyOverlay(baseStyle, splashColor, highlightColor);

  return Theme(
    data: ThemeData(),
    child: OutlinedButton(
      onPressed: enabled ? () => ctx.fireAction('onTap') : null,
      onLongPress: enabled ? () => ctx.fireAction('onLongPress') : null,
      autofocus: autofocus,
      style: style,
      child: ctx.childIds.isNotEmpty ? renderChild(ctx) : const Text(''),
    ),
  );
}

Widget _buildFAB(OrcaComponentContext ctx) {
  final enabled = ctx.propOr<bool>('enabled', true);
  final mini = ctx.propOr<bool>('mini', false);
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final elevation = ctx.prop<num>('elevation')?.toDouble();
  final tooltipText = ctx.prop<String>('tooltip');
  final splashColor = parseColor(ctx.prop('splashColor'));
  final focusColor = parseColor(ctx.prop('focusColor'));
  final hoverColor = parseColor(ctx.prop('hoverColor'));
  final heroTag = ctx.prop<String>('heroTag');
  final isExtended = ctx.propOr<bool>('isExtended', false);

  final fab = FloatingActionButton(
    onPressed: enabled ? () => ctx.fireAction('onTap') : null,
    mini: mini,
    backgroundColor: bgColor,
    elevation: elevation,
    tooltip: tooltipText,
    splashColor: splashColor,
    focusColor: focusColor,
    hoverColor: hoverColor,
    heroTag: heroTag,
    isExtended: isExtended,
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : null,
  );

  return GestureDetector(
    onLongPress: enabled ? () => ctx.fireAction('onLongPress') : null,
    child: Theme(data: ThemeData(), child: fab),
  );
}

/// Apply optional splash/highlight overlay colors on top of a button style.
/// Flutter Material 3 merges both through `overlayColor` resolving on state
/// (pressed = splash, hovered = highlight). Returns the base style when no
/// overlay colors are set so callers don't force a style when none is wanted.
ButtonStyle? _applyOverlay(
  ButtonStyle? base,
  Color? splashColor,
  Color? highlightColor,
) {
  if (splashColor == null && highlightColor == null) return base;
  final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.pressed)) {
      return splashColor ?? highlightColor;
    }
    if (states.contains(WidgetState.hovered)) {
      return highlightColor ?? splashColor;
    }
    return null;
  });
  return (base ?? const ButtonStyle()).copyWith(overlayColor: overlay);
}
