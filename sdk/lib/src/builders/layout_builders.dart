import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart'
    show
        InteractiveViewer,
        Material,
        MaterialType,
        InkWell,
        RefreshIndicator,
        ReorderableListView,
        Scrollbar,
        Table,
        TableRow,
        Tooltip;
import 'package:flutter/widgets.dart';
import '../rendering/component_context.dart';
import '../rendering/component_registry.dart';
import 'animated_builder_widget.dart';
import 'builder_helpers.dart';
import 'sub_page_widget.dart';

/// Register all layout component builders.
void registerLayoutBuilders(ComponentRegistry registry) {
  registry.register('Column', _buildColumn);
  registry.register('Row', _buildRow);
  registry.register('Container', _buildContainer);
  registry.register('Stack', _buildStack);
  registry.register('Wrap', _buildWrap);
  registry.register('SingleChildScrollView', _buildScrollView);
  registry.register('Expanded', _buildExpanded);
  registry.register('Flexible', _buildFlexible);
  registry.register('Padding', _buildPadding);
  registry.register('SizedBox', _buildSizedBox);
  registry.register('Center', _buildCenter);
  registry.register('Align', _buildAlign);
  registry.register('FittedBox', _buildFittedBox);
  registry.register('AspectRatio', _buildAspectRatio);
  registry.register('Opacity', _buildOpacity);
  registry.register('SafeArea', _buildSafeArea);
  registry.register('GestureDetector', _buildGestureDetector);
  registry.register('Positioned', _buildPositioned);
  registry.register('AnimatedContainer', _buildAnimatedContainer);
  registry.register('AnimatedOpacity', _buildAnimatedOpacity);
  registry.register('AnimatedAlign', _buildAnimatedAlign);
  registry.register('AnimatedSwitcher', _buildAnimatedSwitcher);
  registry.register('AnimatedBuilder', _buildAnimatedBuilder);
  registry.register('Hero', _buildHero);
  registry.register('ClipRRect', _buildClipRRect);
  registry.register('PullToRefresh', _buildPullToRefresh);
  registry.register('BackdropFilter', _buildBackdropFilter);
  registry.register('BlurView', _buildBlurView);
  registry.register('SubPage', _buildSubPage);
  // Tier 1 — trivial wrappers
  registry.register('ClipRect', _buildClipRect);
  registry.register('ClipOval', _buildClipOval);
  registry.register('IntrinsicHeight', _buildIntrinsicHeight);
  registry.register('IntrinsicWidth', _buildIntrinsicWidth);
  registry.register('Offstage', _buildOffstage);
  registry.register('AbsorbPointer', _buildAbsorbPointer);
  registry.register('IgnorePointer', _buildIgnorePointer);
  registry.register('Baseline', _buildBaseline);
  registry.register('Form', _buildForm);
  // Tier 2 — small builders
  registry.register('ConstrainedBox', _buildConstrainedBox);
  registry.register('LimitedBox', _buildLimitedBox);
  registry.register('FractionallySizedBox', _buildFractionallySizedBox);
  registry.register('RotatedBox', _buildRotatedBox);
  registry.register('DecoratedBox', _buildDecoratedBox);
  registry.register('ColorFiltered', _buildColorFiltered);
  registry.register('Transform', _buildTransform);
  registry.register('Tooltip', _buildTooltip);
  registry.register('DefaultTextStyle', _buildDefaultTextStyle);
  registry.register('Scrollbar', _buildScrollbar);
  // Tier 3 — medium builders
  registry.register('InkWell', _buildInkWell);
  registry.register('InteractiveViewer', _buildInteractiveViewer);
  registry.register('Table', _buildTable);
  registry.register('PageView', _buildPageView);
  registry.register('ReorderableListView', _buildReorderableListView);
}

Widget _buildColumn(OrcaComponentContext ctx) {
  final gap = (ctx.prop<num>('gap'))?.toDouble();
  final children = renderChildren(ctx);

  return Column(
    mainAxisAlignment: parseMainAxisAlignment(
      ctx.prop<String>('mainAxisAlignment'),
    ),
    crossAxisAlignment: parseCrossAxisAlignment(
      ctx.prop<String>('crossAxisAlignment'),
    ),
    mainAxisSize: parseMainAxisSize(ctx.prop<String>('mainAxisSize')),
    textDirection: parseTextDirection(ctx.prop<String>('textDirection')),
    verticalDirection: parseVerticalDirection(
      ctx.prop<String>('verticalDirection'),
    ),
    textBaseline: parseTextBaseline(ctx.prop<String>('textBaseline')),
    children: gap != null ? _addGaps(children, gap, Axis.vertical) : children,
  );
}

Widget _buildRow(OrcaComponentContext ctx) {
  final gap = (ctx.prop<num>('gap'))?.toDouble();
  final children = renderChildren(ctx);

  return Row(
    mainAxisAlignment: parseMainAxisAlignment(
      ctx.prop<String>('mainAxisAlignment'),
    ),
    crossAxisAlignment: parseCrossAxisAlignment(
      ctx.prop<String>('crossAxisAlignment'),
    ),
    mainAxisSize: parseMainAxisSize(ctx.prop<String>('mainAxisSize')),
    textDirection: parseTextDirection(ctx.prop<String>('textDirection')),
    verticalDirection: parseVerticalDirection(
      ctx.prop<String>('verticalDirection'),
    ),
    textBaseline: parseTextBaseline(ctx.prop<String>('textBaseline')),
    children: gap != null ? _addGaps(children, gap, Axis.horizontal) : children,
  );
}

Widget _buildContainer(OrcaComponentContext ctx) {
  return Container(
    padding: parseEdgeInsets(ctx.prop('padding')),
    margin: parseEdgeInsets(ctx.prop('margin')),
    decoration: parseBoxDecoration(ctx.prop('decoration')),
    width: (ctx.prop<num>('width'))?.toDouble(),
    height: (ctx.prop<num>('height'))?.toDouble(),
    alignment: ctx.prop<String>('alignment') != null
        ? parseAlignment(ctx.prop<String>('alignment'))
        : null,
    color: ctx.prop('decoration') == null
        ? parseColor(ctx.prop('color'))
        : null,
    clipBehavior: parseClip(ctx.prop<String>('clipBehavior')),
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : null,
  );
}

Widget _buildStack(OrcaComponentContext ctx) {
  return Stack(
    fit: parseStackFit(ctx.prop<String>('fit')),
    alignment: parseAlignment(ctx.prop<String>('alignment')),
    textDirection: parseTextDirection(ctx.prop<String>('textDirection')),
    clipBehavior: parseClip(ctx.prop<String>('clipBehavior')),
    children: renderChildren(ctx),
  );
}

Widget _buildWrap(OrcaComponentContext ctx) {
  return Wrap(
    direction: ctx.prop<String>('direction') == 'vertical'
        ? Axis.vertical
        : Axis.horizontal,
    spacing: (ctx.prop<num>('spacing'))?.toDouble() ?? 0,
    runSpacing: (ctx.prop<num>('runSpacing'))?.toDouble() ?? 0,
    alignment: _parseWrapAlignment(ctx.prop<String>('alignment')),
    crossAxisAlignment: _parseWrapCrossAlignment(
      ctx.prop<String>('crossAxisAlignment'),
    ),
    children: renderChildren(ctx),
  );
}

Widget _buildScrollView(OrcaComponentContext ctx) {
  final scrollView = SingleChildScrollView(
    scrollDirection: ctx.prop<String>('scrollDirection') == 'horizontal'
        ? Axis.horizontal
        : Axis.vertical,
    reverse: ctx.propOr<bool>('reverse', false),
    padding: parseEdgeInsets(ctx.prop('padding')),
    primary: ctx.prop<bool>('primary'),
    child: renderChild(ctx),
  );

  final shrinkWrap = ctx.propOr<bool>('shrinkWrap', false);
  // SingleChildScrollView has no shrinkWrap prop — Flutter's sizing is
  // content-driven by default. The authoring contract exposes `shrinkWrap`
  // for parity with ListView/GridView; when set, wrap in an IntrinsicHeight
  // (for vertical scroll) to emulate the tighter layout behavior. For
  // horizontal scrolls the IntrinsicWidth equivalent fires, and for the
  // default (false) we leave the widget untouched.
  final wrapped = shrinkWrap
      ? (ctx.prop<String>('scrollDirection') == 'horizontal'
          ? IntrinsicWidth(child: scrollView)
          : IntrinsicHeight(child: scrollView))
      : scrollView;

  return wrapScrollNotifier(ctx, wrapped);
}

Widget _buildExpanded(OrcaComponentContext ctx) {
  return Expanded(flex: ctx.propOr<int>('flex', 1), child: renderChild(ctx));
}

Widget _buildFlexible(OrcaComponentContext ctx) {
  return Flexible(
    flex: ctx.propOr<int>('flex', 1),
    fit: ctx.prop<String>('fit') == 'tight' ? FlexFit.tight : FlexFit.loose,
    child: renderChild(ctx),
  );
}

Widget _buildPadding(OrcaComponentContext ctx) {
  return Padding(
    padding: parseEdgeInsets(ctx.prop('padding')) ?? EdgeInsets.zero,
    child: renderChild(ctx),
  );
}

Widget _buildSizedBox(OrcaComponentContext ctx) {
  return SizedBox(
    width: (ctx.prop<num>('width'))?.toDouble(),
    height: (ctx.prop<num>('height'))?.toDouble(),
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : null,
  );
}

Widget _buildCenter(OrcaComponentContext ctx) {
  return Center(
    widthFactor: (ctx.prop<num>('widthFactor'))?.toDouble(),
    heightFactor: (ctx.prop<num>('heightFactor'))?.toDouble(),
    child: renderChild(ctx),
  );
}

Widget _buildAlign(OrcaComponentContext ctx) {
  return Align(
    alignment: parseAlignment(ctx.prop<String>('alignment')),
    widthFactor: (ctx.prop<num>('widthFactor'))?.toDouble(),
    heightFactor: (ctx.prop<num>('heightFactor'))?.toDouble(),
    child: renderChild(ctx),
  );
}

Widget _buildFittedBox(OrcaComponentContext ctx) {
  return FittedBox(
    fit: _parseBoxFit(ctx.prop<String>('fit')),
    child: renderChild(ctx),
  );
}

Widget _buildAspectRatio(OrcaComponentContext ctx) {
  return AspectRatio(
    aspectRatio: (ctx.prop<num>('aspectRatio'))?.toDouble() ?? 1,
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : null,
  );
}

Widget _buildOpacity(OrcaComponentContext ctx) {
  return Opacity(
    opacity: (ctx.prop<num>('opacity'))?.toDouble() ?? 1,
    child: renderChild(ctx),
  );
}

Widget _buildSafeArea(OrcaComponentContext ctx) {
  return SafeArea(
    top: ctx.propOr<bool>('top', true),
    bottom: ctx.propOr<bool>('bottom', true),
    left: ctx.propOr<bool>('left', true),
    right: ctx.propOr<bool>('right', true),
    child: renderChild(ctx),
  );
}

Widget _buildGestureDetector(OrcaComponentContext ctx) {
  // Only register the gesture callbacks the author actually attached.
  // Registering an unused onTap callback still puts a TapGestureRecognizer
  // in the arena, which can shadow child widgets' own gesture handling.
  //
  // behavior defaults to HitTestBehavior.opaque when ANY handler is set:
  // the default (deferToChild) only claims hits where the child's painted
  // pixels are, so taps in padding/margin around a small child (an Icon
  // glyph, a caption) fall through and never fire. Opaque claims the
  // entire rendered bounds, matching what an author who wraps their UI in
  // a GestureDetector almost always wants.
  final actions = ctx.node.actions;
  final hasOnTap = actions?.containsKey('onTap') ?? false;
  final hasOnLongPress = actions?.containsKey('onLongPress') ?? false;
  final hasOnDoubleTap = actions?.containsKey('onDoubleTap') ?? false;
  final hasAny = hasOnTap || hasOnLongPress || hasOnDoubleTap;

  if (!hasAny) {
    // Pass-through — don't introduce a recognizer that would interfere
    // with whatever's below.
    return renderChild(ctx);
  }

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: hasOnTap ? () => ctx.fireAction('onTap') : null,
    onLongPress: hasOnLongPress ? () => ctx.fireAction('onLongPress') : null,
    onDoubleTap: hasOnDoubleTap ? () => ctx.fireAction('onDoubleTap') : null,
    child: renderChild(ctx),
  );
}

Widget _buildClipRRect(OrcaComponentContext ctx) {
  final radius = ctx.prop<num>('borderRadius')?.toDouble() ?? 0;
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: renderChild(ctx),
  );
}

Widget _buildBackdropFilter(OrcaComponentContext ctx) {
  final blurX = ctx.prop<num>('blurX')?.toDouble() ?? 10.0;
  final blurY = ctx.prop<num>('blurY')?.toDouble() ?? 10.0;
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
    child: renderChild(ctx),
  );
}

Widget _buildBlurView(OrcaComponentContext ctx) {
  final blurX = ctx.prop<num>('blurX')?.toDouble() ?? 10.0;
  final blurY = ctx.prop<num>('blurY')?.toDouble() ?? 10.0;
  final overlayColor = parseColor(ctx.prop('overlayColor'));
  final radius = ctx.prop<num>('borderRadius')?.toDouble() ?? 0;
  Widget child = ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
      child: Container(
        color: overlayColor ?? const Color(0x00000000),
        child: renderChild(ctx),
      ),
    ),
  );
  return child;
}

Widget _buildPullToRefresh(OrcaComponentContext ctx) {
  final color = parseColor(ctx.prop('color'));
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final displacement = ctx.prop<num>('displacement')?.toDouble() ?? 40.0;
  return RefreshIndicator(
    color: color,
    backgroundColor: bgColor,
    displacement: displacement,
    onRefresh: () async {
      // Await the action so RefreshIndicator keeps spinning until complete.
      final action = ctx.node.actions?['onRefresh'];
      if (action != null && ctx.actionExecutor != null) {
        if (action is List) {
          await ctx.actionExecutor!.executeAll(action);
        } else if (action is Map<String, dynamic>) {
          await ctx.actionExecutor!.execute(action);
        }
      }
    },
    child: renderChild(ctx),
  );
}

Widget _buildPositioned(OrcaComponentContext ctx) {
  return Positioned(
    top: (ctx.prop<num>('top'))?.toDouble(),
    right: (ctx.prop<num>('right'))?.toDouble(),
    bottom: (ctx.prop<num>('bottom'))?.toDouble(),
    left: (ctx.prop<num>('left'))?.toDouble(),
    width: (ctx.prop<num>('width'))?.toDouble(),
    height: (ctx.prop<num>('height'))?.toDouble(),
    child: renderChild(ctx),
  );
}

Widget _buildSubPage(OrcaComponentContext ctx) {
  final pageId = ctx.prop<String>('pageId') ?? '';
  final params = ctx.prop<Map<String, dynamic>>('params');

  // Render the onLoading child if present.
  final loadingWidget = ctx.childIds.isNotEmpty ? renderChild(ctx) : null;

  return OrcaSubPageWidget(
    key: ValueKey('sub_page_${ctx.node.id}'),
    subPageKey: ctx.node.id,
    pageId: pageId,
    params: params,
    parentContext: ctx,
    loadingWidget: loadingWidget,
  );
}

// ── Tier 1: Trivial wrappers ────────────────────────────────

Widget _buildClipRect(OrcaComponentContext ctx) {
  return ClipRect(child: renderChild(ctx));
}

Widget _buildClipOval(OrcaComponentContext ctx) {
  return ClipOval(child: renderChild(ctx));
}

Widget _buildIntrinsicHeight(OrcaComponentContext ctx) {
  return IntrinsicHeight(child: renderChild(ctx));
}

Widget _buildIntrinsicWidth(OrcaComponentContext ctx) {
  final stepWidth = (ctx.prop<num>('stepWidth'))?.toDouble();
  final stepHeight = (ctx.prop<num>('stepHeight'))?.toDouble();
  return IntrinsicWidth(
    stepWidth: stepWidth,
    stepHeight: stepHeight,
    child: renderChild(ctx),
  );
}

Widget _buildOffstage(OrcaComponentContext ctx) {
  return Offstage(
    offstage: ctx.propOr<bool>('offstage', true),
    child: renderChild(ctx),
  );
}

Widget _buildAbsorbPointer(OrcaComponentContext ctx) {
  return AbsorbPointer(
    absorbing: ctx.propOr<bool>('absorbing', true),
    child: renderChild(ctx),
  );
}

Widget _buildIgnorePointer(OrcaComponentContext ctx) {
  return IgnorePointer(
    ignoring: ctx.propOr<bool>('ignoring', true),
    child: renderChild(ctx),
  );
}

Widget _buildBaseline(OrcaComponentContext ctx) {
  final baseline = (ctx.prop<num>('baseline'))?.toDouble() ?? 0;
  final type = ctx.prop<String>('baselineType') == 'ideographic'
      ? TextBaseline.ideographic
      : TextBaseline.alphabetic;
  return Baseline(
    baseline: baseline,
    baselineType: type,
    child: renderChild(ctx),
  );
}

Widget _buildForm(OrcaComponentContext ctx) {
  return renderChild(ctx);
}

// ── Tier 2: Small builders ──────────────────────────────────

Widget _buildConstrainedBox(OrcaComponentContext ctx) {
  final constraints = ctx.prop<Map>('constraints');
  return ConstrainedBox(
    constraints: constraints != null
        ? BoxConstraints(
            minWidth: (constraints['minWidth'] as num?)?.toDouble() ?? 0,
            maxWidth:
                (constraints['maxWidth'] as num?)?.toDouble() ??
                double.infinity,
            minHeight: (constraints['minHeight'] as num?)?.toDouble() ?? 0,
            maxHeight:
                (constraints['maxHeight'] as num?)?.toDouble() ??
                double.infinity,
          )
        : const BoxConstraints(),
    child: renderChild(ctx),
  );
}

Widget _buildLimitedBox(OrcaComponentContext ctx) {
  return LimitedBox(
    maxWidth: (ctx.prop<num>('maxWidth'))?.toDouble() ?? double.infinity,
    maxHeight: (ctx.prop<num>('maxHeight'))?.toDouble() ?? double.infinity,
    child: renderChild(ctx),
  );
}

Widget _buildFractionallySizedBox(OrcaComponentContext ctx) {
  return FractionallySizedBox(
    widthFactor: (ctx.prop<num>('widthFactor'))?.toDouble(),
    heightFactor: (ctx.prop<num>('heightFactor'))?.toDouble(),
    alignment: parseAlignment(ctx.prop<String>('alignment')),
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : null,
  );
}

Widget _buildRotatedBox(OrcaComponentContext ctx) {
  return RotatedBox(
    quarterTurns: ctx.propOr<int>('quarterTurns', 0),
    child: renderChild(ctx),
  );
}

Widget _buildDecoratedBox(OrcaComponentContext ctx) {
  final decoration =
      parseBoxDecoration(ctx.prop('decoration')) ?? const BoxDecoration();
  final position = ctx.prop<String>('position') == 'foreground'
      ? DecorationPosition.foreground
      : DecorationPosition.background;
  return DecoratedBox(
    decoration: decoration,
    position: position,
    child: renderChild(ctx),
  );
}

Widget _buildColorFiltered(OrcaComponentContext ctx) {
  final color = parseColor(ctx.prop('color')) ?? const Color(0x00000000);
  final blendMode = _parseBlendMode(ctx.prop<String>('blendMode'));
  return ColorFiltered(
    colorFilter: ColorFilter.mode(color, blendMode),
    child: renderChild(ctx),
  );
}

Widget _buildTransform(OrcaComponentContext ctx) {
  final transform = ctx.prop<Map>('transform');
  final alignment = parseAlignment(ctx.prop<String>('alignment'));

  if (transform == null) return renderChild(ctx);

  final type = transform['type'] as String?;
  final child = renderChild(ctx);

  switch (type) {
    case 'rotate':
      final angle = (transform['angle'] as num?)?.toDouble() ?? 0;
      return Transform.rotate(angle: angle, alignment: alignment, child: child);
    case 'scale':
      final scaleX = (transform['scaleX'] as num?)?.toDouble() ?? 1;
      final scaleY = (transform['scaleY'] as num?)?.toDouble() ?? 1;
      return Transform.scale(
        scaleX: scaleX,
        scaleY: scaleY,
        alignment: alignment,
        child: child,
      );
    case 'translate':
      final dx = (transform['dx'] as num?)?.toDouble() ?? 0;
      final dy = (transform['dy'] as num?)?.toDouble() ?? 0;
      return Transform.translate(offset: Offset(dx, dy), child: child);
    default:
      return child;
  }
}

Widget _buildTooltip(OrcaComponentContext ctx) {
  final message = resolveStringValue(ctx.prop('message'), ctx.state);
  return Tooltip(message: message, child: renderChild(ctx));
}

Widget _buildDefaultTextStyle(OrcaComponentContext ctx) {
  final style = parseTextStyle(ctx.prop('style')) ?? const TextStyle();
  final textAlign = ctx.prop<String>('textAlign');
  final maxLines = ctx.prop<int>('maxLines');
  final overflow = _parseTextOverflow(ctx.prop<String>('overflow'));

  return DefaultTextStyle(
    style: style,
    textAlign: textAlign != null ? _parseTextAlignLayout(textAlign) : null,
    maxLines: maxLines,
    overflow: overflow ?? TextOverflow.clip,
    child: renderChild(ctx),
  );
}

Widget _buildScrollbar(OrcaComponentContext ctx) {
  final thumbVisibility = ctx.prop<bool>('thumbVisibility');
  final thickness = (ctx.prop<num>('thickness'))?.toDouble();
  return Scrollbar(
    thumbVisibility: thumbVisibility,
    thickness: thickness,
    child: renderChild(ctx),
  );
}

// ── Tier 3: Medium builders ─────────────────────────────────

Widget _buildInkWell(OrcaComponentContext ctx) {
  final borderRadius = ctx.prop<num>('borderRadius')?.toDouble();
  final splashColor = parseColor(ctx.prop('splashColor'));
  final highlightColor = parseColor(ctx.prop('highlightColor'));

  return Material(
    type: MaterialType.transparency,
    child: InkWell(
      borderRadius: borderRadius != null
          ? BorderRadius.circular(borderRadius)
          : null,
      splashColor: splashColor,
      highlightColor: highlightColor,
      onTap: () => ctx.fireAction('onTap'),
      onLongPress: () => ctx.fireAction('onLongPress'),
      onDoubleTap: () => ctx.fireAction('onDoubleTap'),
      child: renderChild(ctx),
    ),
  );
}

Widget _buildInteractiveViewer(OrcaComponentContext ctx) {
  return InteractiveViewer(
    minScale: (ctx.prop<num>('minScale'))?.toDouble() ?? 0.8,
    maxScale: (ctx.prop<num>('maxScale'))?.toDouble() ?? 2.5,
    panEnabled: ctx.propOr<bool>('panEnabled', true),
    scaleEnabled: ctx.propOr<bool>('scaleEnabled', true),
    child: renderChild(ctx),
  );
}

Widget _buildTable(OrcaComponentContext ctx) {
  final borderData = ctx.prop<Map>('border');
  final borderColor = borderData != null
      ? parseColor(borderData['color'])
      : null;
  final borderWidth = borderData != null
      ? (borderData['width'] as num?)?.toDouble() ?? 1
      : 1.0;
  final border = borderData != null
      ? TableBorder.all(
          color: borderColor ?? const Color(0xFF000000),
          width: borderWidth,
        )
      : null;

  // Children are treated as rows; each row's children are cells.
  final children = renderChildren(ctx);
  final rows = children.map((child) => TableRow(children: [child])).toList();

  return Table(border: border, children: rows);
}

Widget _buildPageView(OrcaComponentContext ctx) {
  final scrollDirection = ctx.prop<String>('scrollDirection') == 'vertical'
      ? Axis.vertical
      : Axis.horizontal;
  final pageSnapping = ctx.propOr<bool>('pageSnapping', true);
  final reverse = ctx.propOr<bool>('reverse', false);

  return wrapScrollNotifier(
    ctx,
    PageView(
      scrollDirection: scrollDirection,
      pageSnapping: pageSnapping,
      reverse: reverse,
      children: renderChildren(ctx),
    ),
  );
}

Widget _buildReorderableListView(OrcaComponentContext ctx) {
  final scrollDirection = ctx.prop<String>('scrollDirection') == 'horizontal'
      ? Axis.horizontal
      : Axis.vertical;
  final padding = parseEdgeInsets(ctx.prop('padding'));
  final children = renderChildren(ctx);

  // ReorderableListView requires keyed children.
  final keyed = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    keyed.add(KeyedSubtree(key: ValueKey(i), child: children[i]));
  }

  return wrapScrollNotifier(
    ctx,
    ReorderableListView(
      scrollDirection: scrollDirection,
      padding: padding,
      onReorder: (oldIndex, newIndex) {
        ctx.fireAction(
          'onReorder',
          eventData: {'oldIndex': oldIndex, 'newIndex': newIndex},
        );
      },
      children: keyed,
    ),
  );
}

// ── Helpers ─────────────────────────────────────────────────

List<Widget> _addGaps(List<Widget> children, double gap, Axis axis) {
  if (children.isEmpty) return children;
  final result = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    result.add(children[i]);
    if (i < children.length - 1) {
      result.add(
        SizedBox(
          width: axis == Axis.horizontal ? gap : null,
          height: axis == Axis.vertical ? gap : null,
        ),
      );
    }
  }
  return result;
}

WrapAlignment _parseWrapAlignment(String? value) {
  return switch (value) {
    'start' => WrapAlignment.start,
    'end' => WrapAlignment.end,
    'center' => WrapAlignment.center,
    'spaceBetween' => WrapAlignment.spaceBetween,
    'spaceAround' => WrapAlignment.spaceAround,
    'spaceEvenly' => WrapAlignment.spaceEvenly,
    _ => WrapAlignment.start,
  };
}

WrapCrossAlignment _parseWrapCrossAlignment(String? value) {
  return switch (value) {
    'start' => WrapCrossAlignment.start,
    'end' => WrapCrossAlignment.end,
    'center' => WrapCrossAlignment.center,
    _ => WrapCrossAlignment.start,
  };
}

BlendMode _parseBlendMode(String? value) {
  return switch (value) {
    'srcOver' => BlendMode.srcOver,
    'srcIn' => BlendMode.srcIn,
    'srcATop' => BlendMode.srcATop,
    'dstOver' => BlendMode.dstOver,
    'dstIn' => BlendMode.dstIn,
    'dstATop' => BlendMode.dstATop,
    'multiply' => BlendMode.multiply,
    'screen' => BlendMode.screen,
    'overlay' => BlendMode.overlay,
    'darken' => BlendMode.darken,
    'lighten' => BlendMode.lighten,
    'colorDodge' => BlendMode.colorDodge,
    'colorBurn' => BlendMode.colorBurn,
    'hardLight' => BlendMode.hardLight,
    'softLight' => BlendMode.softLight,
    'difference' => BlendMode.difference,
    'exclusion' => BlendMode.exclusion,
    'hue' => BlendMode.hue,
    'saturation' => BlendMode.saturation,
    'color' => BlendMode.color,
    'luminosity' => BlendMode.luminosity,
    _ => BlendMode.srcATop,
  };
}

TextAlign? _parseTextAlignLayout(String? value) {
  return switch (value) {
    'left' => TextAlign.left,
    'right' => TextAlign.right,
    'center' => TextAlign.center,
    'justify' => TextAlign.justify,
    'start' => TextAlign.start,
    'end' => TextAlign.end,
    _ => null,
  };
}

TextOverflow? _parseTextOverflow(String? value) {
  return switch (value) {
    'clip' => TextOverflow.clip,
    'fade' => TextOverflow.fade,
    'ellipsis' => TextOverflow.ellipsis,
    'visible' => TextOverflow.visible,
    _ => null,
  };
}

BoxFit _parseBoxFit(String? value) {
  return switch (value) {
    'fill' => BoxFit.fill,
    'contain' => BoxFit.contain,
    'cover' => BoxFit.cover,
    'fitWidth' => BoxFit.fitWidth,
    'fitHeight' => BoxFit.fitHeight,
    'none' => BoxFit.none,
    'scaleDown' => BoxFit.scaleDown,
    _ => BoxFit.contain,
  };
}

// ── Animation Builders ────────────────────────────────────

Curve _parseCurve(String? value) {
  return switch (value) {
    // Original List
    'linear' => Curves.linear,
    'easeIn' => Curves.easeIn,
    'easeOut' => Curves.easeOut,
    'easeInOut' => Curves.easeInOut,
    'decelerate' => Curves.decelerate,
    'bounceIn' => Curves.bounceIn,
    'bounceOut' => Curves.bounceOut,
    'bounceInOut' => Curves.bounceInOut,
    'elasticIn' => Curves.elasticIn,
    'elasticOut' => Curves.elasticOut,
    'elasticInOut' => Curves.elasticInOut,
    'fastOutSlowIn' => Curves.fastOutSlowIn,

    // Ease Extensions
    'ease' => Curves.ease,
    'easeInSine' => Curves.easeInSine,
    'easeOutSine' => Curves.easeOutSine,
    'easeInOutSine' => Curves.easeInOutSine,
    'easeInQuad' => Curves.easeInQuad,
    'easeOutQuad' => Curves.easeOutQuad,
    'easeInOutQuad' => Curves.easeInOutQuad,
    'easeInCubic' => Curves.easeInCubic,
    'easeOutCubic' => Curves.easeOutCubic,
    'easeInOutCubic' => Curves.easeInOutCubic,
    'easeInQuart' => Curves.easeInQuart,
    'easeOutQuart' => Curves.easeOutQuart,
    'easeInOutQuart' => Curves.easeInOutQuart,
    'easeInQuint' => Curves.easeInQuint,
    'easeOutQuint' => Curves.easeOutQuint,
    'easeInOutQuint' => Curves.easeInOutQuint,
    'easeInExpo' => Curves.easeInExpo,
    'easeOutExpo' => Curves.easeOutExpo,
    'easeInOutExpo' => Curves.easeInOutExpo,
    'easeInCirc' => Curves.easeInCirc,
    'easeOutCirc' => Curves.easeOutCirc,
    'easeInOutCirc' => Curves.easeInOutCirc,

    // Back (Overhead) Curves
    'easeInBack' => Curves.easeInBack,
    'easeOutBack' => Curves.easeOutBack,
    'easeInOutBack' => Curves.easeInOutBack,

    // Specialized & Material
    'fastLinearToSlowEaseIn' => Curves.fastLinearToSlowEaseIn,
    'slowMiddle' => Curves.slowMiddle,
    'fastEaseInToSlowEaseOut' => Curves.fastEaseInToSlowEaseOut,
    'linearToEaseOut' => Curves.linearToEaseOut,
    'easeInToLinear' => Curves.easeInToLinear,
    _ => Curves.easeInOut,
  };
}

Widget _buildAnimatedContainer(OrcaComponentContext ctx) {
  final duration = ctx.propOr<int>('duration', 300);
  final curve = _parseCurve(ctx.prop<String>('curve'));
  final padding = parseEdgeInsets(ctx.prop('padding'));
  final margin = parseEdgeInsets(ctx.prop('margin'));
  final decoration = parseBoxDecoration(ctx.prop('decoration'));
  final width = (ctx.prop<num>('width'))?.toDouble();
  final height = (ctx.prop<num>('height'))?.toDouble();
  final color = parseColor(ctx.prop('color'));
  final alignment = parseAlignment(ctx.prop<String>('alignment'));

  return AnimatedContainer(
    duration: Duration(milliseconds: duration),
    curve: curve,
    padding: padding,
    margin: margin,
    decoration:
        decoration ?? (color != null ? BoxDecoration(color: color) : null),
    width: width,
    height: height,
    alignment: alignment != Alignment.center ? alignment : null,
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : null,
  );
}

Widget _buildAnimatedOpacity(OrcaComponentContext ctx) {
  final opacity = (ctx.prop<num>('opacity'))?.toDouble() ?? 1.0;
  final duration = ctx.propOr<int>('duration', 300);
  final curve = _parseCurve(ctx.prop<String>('curve'));

  return AnimatedOpacity(
    opacity: opacity,
    duration: Duration(milliseconds: duration),
    curve: curve,
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : const SizedBox.shrink(),
  );
}

Widget _buildAnimatedAlign(OrcaComponentContext ctx) {
  final alignment = parseAlignment(ctx.prop<String>('alignment'));
  final duration = ctx.propOr<int>('duration', 300);
  final curve = _parseCurve(ctx.prop<String>('curve'));
  final widthFactor = (ctx.prop<num>('widthFactor'))?.toDouble();
  final heightFactor = (ctx.prop<num>('heightFactor'))?.toDouble();

  return AnimatedAlign(
    alignment: alignment,
    duration: Duration(milliseconds: duration),
    curve: curve,
    widthFactor: widthFactor,
    heightFactor: heightFactor,
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : null,
  );
}

Widget _buildAnimatedSwitcher(OrcaComponentContext ctx) {
  final duration = ctx.propOr<int>('duration', 300);

  return AnimatedSwitcher(
    duration: Duration(milliseconds: duration),
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : const SizedBox.shrink(),
  );
}

Widget _buildAnimatedBuilder(OrcaComponentContext ctx) {
  final duration = ctx.propOr<int>('duration', 300);
  final curve = _parseCurve(ctx.prop<String>('curve'));
  final repeat = ctx.propOr<bool>('repeat', false);
  final reverse = ctx.propOr<bool>('reverse', false);
  final autoStart = ctx.propOr<bool>('autoStart', true);
  final animationId = ctx.prop<String>('animationId');

  return OrcaAnimatedBuilder(
    key: ValueKey('animated_builder_${ctx.node.id}'),
    duration: duration,
    curve: curve,
    repeat: repeat,
    reverse: reverse,
    autoStart: autoStart,
    animationId: animationId,
    parentContext: ctx,
    store: ctx.store,
  );
}

Widget _buildHero(OrcaComponentContext ctx) {
  final tag = ctx.prop<String>('tag') ?? '';
  if (tag.isEmpty) {
    return ctx.childIds.isNotEmpty ? renderChild(ctx) : const SizedBox.shrink();
  }

  return Hero(
    tag: tag,
    child: ctx.childIds.isNotEmpty ? renderChild(ctx) : const SizedBox.shrink(),
  );
}
