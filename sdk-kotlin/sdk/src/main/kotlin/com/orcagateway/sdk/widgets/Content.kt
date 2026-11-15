package com.orcagateway.sdk.widgets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.absolutePadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.toRect
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.takeOrElse
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.style.TextStyleProps

/**
 * Flutter `Text`: `data` printed the Dart way, `style` merged over the
 * surrounding text style, `textAlign`, `maxLines`, `softWrap`, `overflow`
 * (the style's when the Text sends none, then clip, as Flutter) and
 * `semanticsLabel`. Where the parent forces the width (a stretched Column),
 * the text spans it and `textAlign` places the lines, as Flutter lays a
 * Text out in a tight box. Word spacing, the decorations Compose cannot draw
 * and the `fade` overflow are drawn here (TextDecorations.kt).
 */
@Composable
internal fun TextWidget(node: ResolvedNode, modifier: Modifier) {
    val data = Props.text(node["data"])
    val props = TextStyleProps(node["style"])
    var style = LocalTextStyle.current.merge(props.textStyle())
    Props.textAlign(node["textAlign"])?.let { style = style.merge(TextStyle(textAlign = it)) }
    if (props.drawsDecoration) style = style.merge(TextStyle(textDecoration = TextDecoration.None))
    val maxLines = node["maxLines"]?.intValue?.takeIf { it > 0 }?.coerceAtMost(Int.MAX_VALUE.toLong())?.toInt()
    val label = node["semanticsLabel"]?.stringValue
    val overflowValue = node["overflow"]?.takeUnless { it.isNull } ?: props.overflow
    val overflow = Props.overflow(overflowValue)
    val fade = overflowValue?.stringValue == "fade"
    val decorationColor = props.decorationColor ?: style.color.takeOrElse { LocalContentColor.current }
    val measurer = if (fade || props.overline) rememberTextMeasurer() else null
    var layout by remember { mutableStateOf<TextLayoutResult?>(null) }
    val drawn = if (!fade && !props.drawsDecoration) {
        Modifier
    } else {
        Modifier.drawWithCache {
            // Read here, the layout rebuilds the cache whenever the Text lays out anew.
            val result = layout ?: return@drawWithCache onDrawWithContent { drawContent() }
            val ascent = if (props.overline && measurer != null) fontAscent(measurer, result) else 0f
            val lines = if (props.drawsDecoration) decorationLines(result, props, decorationColor, ascent) else null
            val clip = overflow != TextOverflow.Visible
            val brush = if (fade && measurer != null) fadeBrush(measurer, result, size, layoutDirection) else null
            val bounds = size.toRect()
            val layer = brush?.let { Paint() }
            onDrawWithContent {
                if (layer != null) drawContext.canvas.saveLayer(bounds, layer)
                drawContent()
                if (lines != null) {
                    if (clip) clipRect { drawDecoration(lines) } else drawDecoration(lines)
                }
                if (brush != null) {
                    fadeOverflow(brush)
                    drawContext.canvas.restore()
                }
            }
        }
    }
    Text(
        text = props.wordSpacing?.let { wordSpaced(data, it, style) } ?: AnnotatedString(data),
        modifier = (if (label != null) modifier.clearAndSetSemantics { contentDescription = label } else modifier).then(drawn),
        overflow = overflow,
        softWrap = node["softWrap"]?.boolValue ?: true,
        maxLines = maxLines ?: Int.MAX_VALUE,
        onTextLayout = { layout = it },
        style = style,
    )
}

/**
 * A line as thick as `thickness` (default 1, colour #E0E0E0) across the
 * width, inset by `indent` on the left and `endIndent` on the right; no
 * extra vertical space, as the Flutter builder draws it.
 */
@Composable
internal fun DividerWidget(node: ResolvedNode, modifier: Modifier) {
    HorizontalDivider(
        modifier = modifier.absolutePadding(
            left = Props.length(node["indent"]) ?: 0.dp,
            right = Props.length(node["endIndent"]) ?: 0.dp,
        ),
        thickness = Props.length(node["thickness"]) ?: 1.dp,
        color = Props.color(node["color"]) ?: Props.hex("#E0E0E0"),
    )
}

/**
 * The frozen v1 FallbackPrompt, as the Flutter builder draws it: an accent
 * per severity (blocking red, warn orange, info blue), tinted background,
 * title, body, and a link-style button that opens `ctaUrl` through the URL
 * policy (http, https, mailto only), as [OrcaPageModel.openLink]: an
 * `openUrl` effect to the host, or the platform's URI handler when the page
 * has no host.
 */
@Composable
internal fun FallbackPromptWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val accent = when (node["severity"]?.stringValue) {
        "blocking" -> Props.hex("#D32F2F")
        "warn" -> Props.hex("#F57C00")
        else -> Props.hex("#1976D2")
    }
    val shape = RoundedCornerShape(8.dp)
    val uriHandler = LocalUriHandler.current
    val base = LocalTextStyle.current
    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(accent.copy(alpha = 0.08f))
            .border(1.dp, accent, shape)
            .padding(16.dp),
    ) {
        Text(
            Props.text(node["title"]),
            style = base.merge(TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = accent)),
        )
        Text(
            Props.text(node["body"]),
            modifier = Modifier.padding(top = 8.dp),
            style = base.merge(TextStyle(fontSize = 14.sp, color = Props.hex("#333333"))),
        )
        val label = node["ctaLabel"]?.stringValue
        val url = node["ctaUrl"]?.stringValue
        if (label != null && url != null) {
            Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.End) {
                Text(
                    label,
                    modifier = Modifier.clickable(role = Role.Button) {
                        model.openLink(url) { link ->
                            // No app on the device opens it: nothing to do.
                            try {
                                uriHandler.openUri(link)
                            } catch (_: IllegalArgumentException) {
                            }
                        }
                    },
                    style = base.merge(
                        TextStyle(
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = accent,
                            textDecoration = TextDecoration.Underline,
                        ),
                    ),
                )
            }
        }
    }
}
