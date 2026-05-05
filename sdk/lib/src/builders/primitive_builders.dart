import 'package:flutter/material.dart' show SelectableText, ImageIcon;
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../rendering/component_context.dart';
import '../rendering/component_registry.dart';
import 'builder_helpers.dart';

const _safeUrlSchemes = {'http', 'https', 'tel', 'mailto', 'sms'};

/// Register all primitive component builders.
void registerPrimitiveBuilders(ComponentRegistry registry) {
  registry.register('Text', _buildText);
  registry.register('Image', _buildImage);
  registry.register('Icon', _buildIcon);
  registry.register('Divider', _buildDivider);
  registry.register('Spacer', _buildSpacer);
  registry.register('CircularProgressIndicator', _buildCircularProgress);
  registry.register('FallbackPrompt', _buildFallbackPrompt);
  registry.register(
    'UnsupportedWidgetPlaceholder',
    _buildUnsupportedWidgetPlaceholder,
  );
  registry.register('RichText', _buildRichText);
  registry.register('SelectableText', _buildSelectableText);
  registry.register('LinearProgressIndicator', _buildLinearProgressIndicator);
  registry.register('ImageIcon', _buildImageIcon);
}

Widget _buildText(OrcaComponentContext ctx) {
  final data = resolveStringValue(ctx.prop('data'), ctx.state);
  final style = parseTextStyle(ctx.prop('style'));
  final textAlign = _parseTextAlign(ctx.prop<String>('textAlign'));
  final maxLines = ctx.prop<int>('maxLines');
  final overflow = _parseOverflow(ctx.prop<String>('overflow'));
  final softWrap = ctx.prop<bool>('softWrap');
  final semanticsLabel = ctx.prop<String>('semanticsLabel');

  return Text(
    data,
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel,
  );
}

Widget _buildImage(OrcaComponentContext ctx) {
  final src = resolveStringValue(ctx.prop('src'), ctx.state);
  final fit = _parseBoxFit(ctx.prop<String>('fit'));
  final width = (ctx.prop<num>('width'))?.toDouble();
  final height = (ctx.prop<num>('height'))?.toDouble();
  final alt = ctx.prop<String>('alt');
  final alignment = ctx.prop<String>('alignment') != null
      ? parseAlignment(ctx.prop<String>('alignment'))
      : Alignment.center;
  final repeat = _parseImageRepeat(ctx.prop<String>('repeat'));
  final color = parseColor(ctx.prop('color'));

  Widget image = Image.network(
    src,
    fit: fit,
    width: width,
    height: height,
    semanticLabel: alt,
    alignment: alignment,
    repeat: repeat,
    color: color,
    errorBuilder: (_, _, _) => SizedBox(
      width: width,
      height: height,
      child: const Center(child: Text('!')),
    ),
  );

  return image;
}

ImageRepeat _parseImageRepeat(String? value) {
  return switch (value) {
    'repeat' => ImageRepeat.repeat,
    'repeatX' => ImageRepeat.repeatX,
    'repeatY' => ImageRepeat.repeatY,
    'noRepeat' => ImageRepeat.noRepeat,
    _ => ImageRepeat.noRepeat,
  };
}

Widget _buildIcon(OrcaComponentContext ctx) {
  final size = (ctx.prop<num>('size'))?.toDouble() ?? 24;
  final color = parseColor(ctx.prop('color'));

  // Network raster icon via `src` takes precedence over Material icon `name`.
  final src = ctx.prop('src');
  if (src != null) {
    final resolvedSrc = resolveStringValue(src, ctx.state);
    return ImageIcon(
      NetworkImage(resolvedSrc),
      size: size,
      color: color,
    );
  }

  final name = ctx.prop<String>('name') ?? ctx.prop<String>('icon');
  final iconData = resolveIconData(name);
  return Icon(iconData, size: size, color: color);
}

Widget _buildDivider(OrcaComponentContext ctx) {
  final thickness = (ctx.prop<num>('thickness'))?.toDouble() ?? 1;
  final color = parseColor(ctx.prop('color')) ?? const Color(0xFFE0E0E0);
  final indent = (ctx.prop<num>('indent'))?.toDouble() ?? 0;
  final endIndent = (ctx.prop<num>('endIndent'))?.toDouble() ?? 0;

  return Padding(
    padding: EdgeInsets.only(left: indent, right: endIndent),
    child: Container(height: thickness, color: color),
  );
}

Widget _buildSpacer(OrcaComponentContext ctx) {
  return Expanded(
    flex: ctx.propOr<int>('flex', 1),
    child: const SizedBox.shrink(),
  );
}

/// FallbackPrompt — frozen v1 "something needs your attention" primitive
/// (Epic 25b, task 25b.5). Props: title, body, ctaLabel?, ctaUrl?, severity.
/// Also the substitution widget for the SDK safe-degrade path (task 25b.9) —
/// when an unknown component type shows up, the renderer synthesizes a
/// FallbackPrompt with the frozen shape so the user sees actionable text
/// instead of a blank region or a red error overlay.
///
/// Keep this builder's behavior conservative: no network calls, no state
/// mutation, no assumptions about the outer Material theme beyond what
/// `DefaultTextStyle.of` and `Theme.of` already provide through Flutter's
/// baseline widgets. The contract is that this renders on every SDK version
/// that ever shipped, under every conceivable outer widget tree.
Widget _buildFallbackPrompt(OrcaComponentContext ctx) {
  final title = resolveStringValue(ctx.prop('title'), ctx.state);
  final body = resolveStringValue(ctx.prop('body'), ctx.state);
  final ctaLabel = ctx.prop<String>('ctaLabel');
  final ctaUrl = ctx.prop<String>('ctaUrl');
  final severity = ctx.prop<String>('severity') ?? 'info';

  final accent = switch (severity) {
    'blocking' => const Color(0xFFD32F2F),
    'warn' => const Color(0xFFF57C00),
    _ => const Color(0xFF1976D2),
  };

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      border: Border.all(color: accent, width: 1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        ),
        if (ctaLabel != null && ctaUrl != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              final uri = Uri.tryParse(ctaUrl);
              if (uri != null && _safeUrlSchemes.contains(uri.scheme.toLowerCase())) {
                launchUrl(uri);
              }
            },
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                ctaLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// UnsupportedWidgetPlaceholder — "this widget cannot render here" card
/// (Epic 38 task 38.2). Fires automatically on web when a plugin widget is
/// marked `isSupportedOnWeb: false` and no web stub was registered, and can
/// also be emitted deliberately from a declarative plugin stub tree. Keep
/// this builder visually distinct from _buildFallbackPrompt so a reader can
/// tell "this is a known widget that can't run here" apart from "this SDK
/// has never heard of this widget".
Widget _buildUnsupportedWidgetPlaceholder(OrcaComponentContext ctx) {
  final widgetType = resolveStringValue(ctx.prop('widgetType'), ctx.state);
  final displayNameRaw = ctx.prop<String>('displayName');
  final displayName =
      (displayNameRaw != null && displayNameRaw.isNotEmpty)
          ? displayNameRaw
          : widgetType;
  final iconName = ctx.prop<String>('iconName');
  final docsUrl = ctx.prop<String>('docsUrl');
  final reason = ctx.prop<String>('reason') ??
      'This widget runs in the compiled mobile app and cannot preview here.';

  const accent = Color(0xFF6B7280);
  final iconData = iconName != null ? resolveIconData(iconName) : null;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.06),
      border: Border.all(
        color: accent.withValues(alpha: 0.35),
        width: 1,
        style: BorderStyle.solid,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null) ...[
              Icon(iconData, size: 20, color: accent),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          reason,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        if (docsUrl != null && docsUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              final uri = Uri.tryParse(docsUrl);
              if (uri != null &&
                  _safeUrlSchemes.contains(uri.scheme.toLowerCase())) {
                launchUrl(uri);
              }
            },
            child: const Text(
              'Learn more',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildCircularProgress(OrcaComponentContext ctx) {
  final size = (ctx.prop<num>('size'))?.toDouble() ?? 36;
  final color = parseColor(ctx.prop('color'));

  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _CircularProgressPainter(
        color: color ?? const Color(0xFF2196F3),
      ),
    ),
  );
}

Widget _buildRichText(OrcaComponentContext ctx) {
  final textData = ctx.prop<Map>('text');
  final textAlign = _parseTextAlign(ctx.prop<String>('textAlign'));
  final maxLines = ctx.prop<int>('maxLines');
  final overflow = _parseOverflow(ctx.prop<String>('overflow'));

  return RichText(
    text: textData != null ? _buildTextSpan(textData, ctx.state) : const TextSpan(),
    textAlign: textAlign ?? TextAlign.start,
    maxLines: maxLines,
    overflow: overflow ?? TextOverflow.clip,
  );
}

TextSpan _buildTextSpan(Map data, [Map<String, dynamic> state = const {}]) {
  final text = resolveStringValue(data['text'], state);
  final style = parseTextStyle(data['style']);
  final childrenData = data['children'] as List?;
  final children = childrenData
      ?.map((c) => c is Map ? _buildTextSpan(c, state) : TextSpan(text: '$c'))
      .toList();

  return TextSpan(text: text, style: style, children: children);
}

Widget _buildSelectableText(OrcaComponentContext ctx) {
  final data = resolveStringValue(ctx.prop('data'), ctx.state);
  final style = parseTextStyle(ctx.prop('style'));
  final textAlign = _parseTextAlign(ctx.prop<String>('textAlign'));
  final maxLines = ctx.prop<int>('maxLines');

  return SelectableText(
    data,
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
  );
}

Widget _buildLinearProgressIndicator(OrcaComponentContext ctx) {
  final value = (ctx.prop<num>('value'))?.toDouble();
  final color = parseColor(ctx.prop('color'));
  final bgColor = parseColor(ctx.prop('backgroundColor'));
  final minHeight = (ctx.prop<num>('minHeight'))?.toDouble() ?? 4;

  return SizedBox(
    height: minHeight,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(minHeight / 2),
      child: CustomPaint(
        size: Size(double.infinity, minHeight),
        painter: _LinearProgressPainter(
          value: value,
          color: color ?? const Color(0xFF2196F3),
          backgroundColor: bgColor ?? const Color(0xFFE0E0E0),
        ),
      ),
    ),
  );
}

Widget _buildImageIcon(OrcaComponentContext ctx) {
  final src = resolveStringValue(ctx.prop('src'), ctx.state);
  final size = (ctx.prop<num>('size'))?.toDouble() ?? 24;
  final color = parseColor(ctx.prop('color'));

  return ImageIcon(
    NetworkImage(src),
    size: size,
    color: color,
  );
}

// ── Helpers ─────────────────────────────────────────────────

TextAlign? _parseTextAlign(String? value) {
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

TextOverflow? _parseOverflow(String? value) {
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
    _ => BoxFit.cover,
  };
}

class _LinearProgressPainter extends CustomPainter {
  final double? value;
  final Color color;
  final Color backgroundColor;

  _LinearProgressPainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (value != null) {
      final fgPaint = Paint()..color = color;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * value!.clamp(0, 1), size.height),
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinearProgressPainter old) =>
      old.value != value || old.color != color || old.backgroundColor != backgroundColor;
}

class _CircularProgressPainter extends CustomPainter {
  final Color color;
  _CircularProgressPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      -0.5,
      4.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
