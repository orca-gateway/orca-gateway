package com.orcagateway.sdk.widgets

import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.sdk.style.TextStyleProps
import com.orcagateway.sdk.style.TextStyleProps.DecorationStyle

// What Flutter's paragraph draws and Compose's Text does not: word spacing,
// a decoration line in its own colour and style (Skia's skparagraph
// `Decorations`), and the `fade` overflow (`RenderParagraph`'s shader).
// The lines and the fade are built once per layout (a Text's drawWithCache)
// and only drawn per frame.

/** Compose's font size when none is set, in sp. */
private const val DEFAULT_FONT_SIZE = 14f

/** Roboto's x-height, in em: a line-through runs at half of it. */
private const val X_HEIGHT = 0.53f

private val FADE = listOf(Color.White, Color.Transparent)
private val FADE_RTL = FADE.reversed()

/**
 * Flutter `wordSpacing`: [text] with [extra] added to the letter spacing
 * of each space, over the letter spacing [style] already has.
 */
internal fun wordSpaced(text: String, extra: Double, style: TextStyle): AnnotatedString {
    val letterSpacing = style.letterSpacing
    val base = when {
        letterSpacing.isSp -> letterSpacing.value
        letterSpacing.isEm -> letterSpacing.value * (style.fontSize.takeIf { it.isSp }?.value ?: DEFAULT_FONT_SIZE)
        else -> 0f
    }
    val space = SpanStyle(letterSpacing = (base + extra).toFloat().sp)
    return buildAnnotatedString {
        append(text)
        text.forEachIndexed { i, c -> if (c == ' ') addStyle(space, i, i + 1) }
    }
}

/** A text's decoration on all its lines, as one stroked path: what [drawDecoration] draws. */
internal class DecorationLines(val path: Path, val color: Color, val stroke: Stroke)

/**
 * The font's ascent for [style] ([layout]'s unless given; a RichText run's
 * own), in px: the baseline of a line no taller than the font. Measured by
 * [measurer] (cached there) at [layout]'s density.
 */
internal fun fontAscent(
    measurer: TextMeasurer,
    layout: TextLayoutResult,
    style: TextStyle = layout.layoutInput.style,
): Float =
    measurer.measure(
        "H",
        style.copy(lineHeight = TextUnit.Unspecified),
        density = layout.layoutInput.density,
    ).firstBaseline

/**
 * The style's decoration on every line of [layout], in [color], as Skia
 * paints Flutter's: an underline below the baseline, an overline at the
 * font's [ascent] above it (below the top half-leading of a line taller than
 * the font), a line-through at half the x-height. One unit is the font
 * size / 14: the line is a unit thick, `dashed` is 4 units on and 2 off,
 * `dotted` 1 on and 1.5 off, `double` adds a second line 3 below, `wavy` is
 * a wave of quarter-waves a unit long and high.
 */
internal fun Density.decorationLines(
    layout: TextLayoutResult,
    props: TextStyleProps,
    color: Color,
    ascent: Float,
): DecorationLines {
    val fontSize = layout.layoutInput.style.fontSize.takeIf { it.isSp }?.toPx() ?: DEFAULT_FONT_SIZE.sp.toPx()
    val stretches = (0 until layout.lineCount).map { line ->
        Stretch(layout.getLineLeft(line), layout.getLineRight(line), layout.getLineBaseline(line))
    }
    return strokedLines(stretches, props, fontSize, color, ascent, overlineDrop = fontSize / 14f / 2)
}

/**
 * [decorationLines]' range form, for one RichText run: the line of [props]
 * under (an overline: over) the characters [start] until [end] of [layout]
 * alone, on each line they wrap onto (less the line's trailing spaces),
 * from that line's baseline, as SkParagraph paints a decoration per style
 * run (Skia modules/skparagraph Decorations.cpp). Placed, sized and
 * stroked as a Text's for a font of [fontSize] (the run's), except the
 * overline: centred on the run's top edge, the run font's [ascent] above
 * the baseline, half of it above (Skia's `-ascent` from the run's top).
 */
internal fun Density.decorationLines(
    layout: TextLayoutResult,
    props: TextStyleProps,
    color: Color,
    ascent: Float,
    fontSize: TextUnit,
    start: Int,
    end: Int,
): DecorationLines {
    val px = fontSize.takeIf { it.isSp }?.toPx() ?: DEFAULT_FONT_SIZE.sp.toPx()
    val stretches = if (end <= start) {
        emptyList()
    } else {
        (layout.getLineForOffset(start)..layout.getLineForOffset(end - 1)).mapNotNull { line ->
            val from = maxOf(start, layout.getLineStart(line))
            val to = minOf(end, layout.getLineEnd(line, visibleEnd = true))
            if (to <= from) return@mapNotNull null
            val box = layout.getPathForRange(from, to).getBounds()
            Stretch(box.left, box.right, layout.getLineBaseline(line))
        }
    }
    return strokedLines(stretches, props, px, color, ascent, overlineDrop = 0f)
}

/** A piece of one text line, from [left] to [right], on the line whose baseline is at [baseline]. */
private class Stretch(val left: Float, val right: Float, val baseline: Float)

/**
 * [props]' line along each of [stretches] for a font of [fontSize] px: an
 * overline [overlineDrop] below the font's [ascent] above the baseline, an
 * underline a unit below it, a line-through at half the x-height above it.
 */
private fun Density.strokedLines(
    stretches: List<Stretch>,
    props: TextStyleProps,
    fontSize: Float,
    color: Color,
    ascent: Float,
    overlineDrop: Float,
): DecorationLines {
    val unit = fontSize / 14f
    val effect = when (props.decorationStyle) {
        DecorationStyle.Dashed -> PathEffect.dashPathEffect(floatArrayOf(4 * unit, 2 * unit))
        DecorationStyle.Dotted -> PathEffect.dashPathEffect(floatArrayOf(unit, 1.5f * unit))
        else -> null
    }
    val gap = 3.dp.toPx()
    val path = Path()
    for (stretch in stretches) {
        val left = stretch.left
        val right = stretch.right
        if (right <= left) continue
        val baseline = stretch.baseline
        val y = when {
            props.overline -> baseline - ascent + overlineDrop
            props.underline -> baseline + unit
            else -> baseline - fontSize * X_HEIGHT / 2
        }
        when (props.decorationStyle) {
            DecorationStyle.Wavy -> path.wave(left, right, y, unit)
            DecorationStyle.Double -> {
                path.segment(left, right, y)
                path.segment(left, right, y + gap)
            }
            else -> path.segment(left, right, y)
        }
    }
    return DecorationLines(path, color, Stroke(width = unit, pathEffect = effect))
}

/** Draws [lines], built by [decorationLines]. */
internal fun DrawScope.drawDecoration(lines: DecorationLines) {
    drawPath(lines.path, lines.color, style = lines.stroke)
}

private fun Path.segment(left: Float, right: Float, y: Float) {
    moveTo(left, y)
    lineTo(right, y)
}

/** Skia's wave: quadratic quarter-waves [quarter] long, alternately up and down, while they fit. */
private fun Path.wave(left: Float, right: Float, y: Float, quarter: Float) {
    moveTo(left, y)
    var x = left
    var up = true
    while (x + 2 * quarter <= right) {
        relativeQuadraticTo(quarter, if (up) -quarter else quarter, 2 * quarter, 0f)
        x += 2 * quarter
        up = !up
    }
}

/**
 * Flutter `TextOverflow.fade` for [layout] in a box of [size]: the shader
 * [fadeOverflow] draws over the text's layer. A line cut at the width fades
 * out over the last ellipsis width of the box (the first, right to left);
 * lines cut by maxLines fade out over the bottom half ellipsis height. Null
 * when the text fits. The ellipsis is measured by [measurer].
 */
internal fun fadeBrush(measurer: TextMeasurer, layout: TextLayoutResult, size: Size, direction: LayoutDirection): Brush? {
    if (!layout.didOverflowWidth && !layout.didOverflowHeight) return null
    val ellipsis = measurer.measure("…", layout.layoutInput.style, density = layout.layoutInput.density).size
    return when {
        layout.didOverflowWidth && direction == LayoutDirection.Rtl ->
            Brush.horizontalGradient(FADE_RTL, startX = 0f, endX = ellipsis.width.toFloat())
        layout.didOverflowWidth -> Brush.horizontalGradient(FADE, startX = size.width - ellipsis.width, endX = size.width)
        else -> Brush.verticalGradient(FADE, startY = size.height - ellipsis.height / 2f, endY = size.height)
    }
}

/** Fades the text's layer out with [brush], built by [fadeBrush] (DstIn). */
internal fun DrawScope.fadeOverflow(brush: Brush) {
    drawRect(brush, blendMode = BlendMode.DstIn)
}
