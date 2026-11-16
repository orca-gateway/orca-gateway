package com.orcagateway.sdk.widgets

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.toRect
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.TextStyles
import com.orcagateway.sdk.style.ENGINE_TEXT_STYLE
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.style.TextStyleProps

/**
 * Flutter `RichText` (primitive_builders.dart:325-348), the raw widget, not
 * `Text.rich`: the `text` span tree as runs ([TextStyles.spans]), each in
 * its style merged down the tree ([TextStyleProps.spanStyle]), a run's
 * `wordSpacing` added to the letter spacing of each of its spaces (as a
 * Text's `wordSpaced`), drawn as one Text. The paragraph is the root span's
 * style over [ENGINE_TEXT_STYLE] (the `fade` ellipsis is the root's, as
 * Flutter's); the root span's `height` applies to every line, as Compose
 * sets line height per paragraph, and a span's own height is not drawn;
 * no ambient style, no DefaultTextStyle, and no text scaling (the font scale
 * is 1 inside, Flutter's `TextScaler.noScaling`). textAlign start unless
 * sent, soft wrap, `overflow` clip unless sent (`fade` fades as a Text's),
 * `maxLines`. A run's solid underline or line-through in its own colour is
 * the SpanStyle's; any other line (an overline; a double, wavy, dotted or
 * dashed line; a decorationColor) is drawn under (an overline: over) that
 * run alone ([RunLine]), in decorationColor else the run's colour, clipped
 * only when the text overflows (Flutter's `RenderParagraph`).
 */
@Composable
internal fun RichTextWidget(node: ResolvedNode, modifier: Modifier) {
    val lines = mutableListOf<RunLine>()
    val text = buildAnnotatedString {
        for (run in TextStyles.spans(node["text"], base = null)) {
            val start = length
            append(run.text)
            val props = run.style?.let(::TextStyleProps) ?: continue
            val span = props.spanStyle()
            if (props.drawsDecoration) {
                // The line is the RunLine's: the span draws none of the paragraph's or its own.
                addStyle(span.copy(textDecoration = TextDecoration.None), start, length)
                if (length > start) lines += RunLine(start, length, props, span)
            } else {
                addStyle(span, start, length)
            }
            // After the run's style, so a space's letter spacing wins.
            props.wordSpacing?.let { extra ->
                val space = SpanStyle(letterSpacing = ((props.letterSpacing ?: 0.0) + extra).sp)
                run.text.forEachIndexed { i, c -> if (c == ' ') addStyle(space, start + i, start + i + 1) }
            }
        }
    }
    val style = ENGINE_TEXT_STYLE.merge(TextStyleProps(node["text"]?.get("style")).textStyle())
        .merge(TextStyle(textAlign = Props.textAlign(node["textAlign"]) ?: TextAlign.Start))
    val maxLines = node["maxLines"]?.intValue?.takeIf { it > 0 }?.coerceAtMost(Int.MAX_VALUE.toLong())?.toInt()
    val overflow = Props.overflow(node["overflow"])
    val fade = node["overflow"]?.stringValue == "fade"
    val measurer = if (fade || lines.any { it.props.overline }) rememberTextMeasurer() else null
    var layout by remember { mutableStateOf<TextLayoutResult?>(null) }
    val drawn = if (!fade && lines.isEmpty()) {
        Modifier
    } else {
        Modifier.drawWithCache {
            // Read here, the layout rebuilds the cache whenever the text lays out anew.
            val result = layout ?: return@drawWithCache onDrawWithContent { drawContent() }
            val strokes = lines.map { it.lines(this, result, style, measurer) }
            val clip = result.hasVisualOverflow && overflow != TextOverflow.Visible
            val brush = if (fade && measurer != null) fadeBrush(measurer, result, size, layoutDirection) else null
            val bounds = size.toRect()
            onDrawWithContent {
                if (brush != null) drawContext.canvas.saveLayer(bounds, Paint())
                drawContent()
                if (clip) clipRect { strokes.forEach { drawDecoration(it) } } else strokes.forEach { drawDecoration(it) }
                if (brush != null) {
                    fadeOverflow(brush)
                    drawContext.canvas.restore()
                }
            }
        }
    }
    CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale = 1f)) {
        Text(
            text = text,
            modifier = modifier.then(drawn),
            overflow = overflow,
            softWrap = true,
            maxLines = maxLines ?: Int.MAX_VALUE,
            onTextLayout = { layout = it },
            style = style,
        )
    }
}

/**
 * A RichText run's line that its SpanStyle cannot draw: the characters
 * [start] until [end], in [props] (the run's merged style), whose
 * [span] lies over the paragraph's style.
 */
private class RunLine(val start: Int, val end: Int, val props: TextStyleProps, val span: SpanStyle) {
    /**
     * The line on [layout] (decorationLines' range form) for the run in
     * [paragraph] under its [span]: in decorationColor else the run's
     * colour, an overline at the run font's ascent ([measurer]'s).
     */
    fun lines(density: Density, layout: TextLayoutResult, paragraph: TextStyle, measurer: TextMeasurer?): DecorationLines {
        val run = paragraph.merge(span)
        val ascent = if (props.overline && measurer != null) fontAscent(measurer, layout, run) else 0f
        return density.decorationLines(layout, props, props.decorationColor ?: run.color, ascent, run.fontSize, start, end)
    }
}
