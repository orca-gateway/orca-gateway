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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
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
 * `maxLines`.
 */
@Composable
internal fun RichTextWidget(node: ResolvedNode, modifier: Modifier) {
    val text = buildAnnotatedString {
        for (run in TextStyles.spans(node["text"], base = null)) {
            val start = length
            append(run.text)
            val props = run.style?.let(::TextStyleProps) ?: continue
            addStyle(props.spanStyle(), start, length)
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
    val fade = node["overflow"]?.stringValue == "fade"
    val measurer = if (fade) rememberTextMeasurer() else null
    var layout by remember { mutableStateOf<TextLayoutResult?>(null) }
    val faded = if (measurer == null) {
        Modifier
    } else {
        Modifier.drawWithCache {
            // Read here, the layout rebuilds the cache whenever the text lays out anew.
            val brush = layout?.let { fadeBrush(measurer, it, size, layoutDirection) }
                ?: return@drawWithCache onDrawWithContent { drawContent() }
            val bounds = size.toRect()
            onDrawWithContent {
                drawContext.canvas.saveLayer(bounds, Paint())
                drawContent()
                fadeOverflow(brush)
                drawContext.canvas.restore()
            }
        }
    }
    CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale = 1f)) {
        Text(
            text = text,
            modifier = modifier.then(faded),
            overflow = Props.overflow(node["overflow"]),
            softWrap = true,
            maxLines = maxLines ?: Int.MAX_VALUE,
            onTextLayout = { layout = it },
            style = style,
        )
    }
}
