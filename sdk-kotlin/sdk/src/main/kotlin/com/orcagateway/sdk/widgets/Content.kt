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
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.style.TextStyleProps

/**
 * Flutter `Text`: `data` printed the Dart way, `style` merged over the
 * surrounding text style, `textAlign`, `maxLines`, `softWrap`, `overflow`
 * (clip by default, as Flutter) and `semanticsLabel`. Where the parent
 * forces the width (a stretched Column), the text spans it and `textAlign`
 * places the lines, as Flutter lays a Text out in a tight box.
 */
@Composable
internal fun TextWidget(node: ResolvedNode, modifier: Modifier) {
    val data = Props.text(node["data"])
    var style = LocalTextStyle.current.merge(TextStyleProps(node["style"]).textStyle())
    Props.textAlign(node["textAlign"])?.let { style = style.merge(TextStyle(textAlign = it)) }
    val maxLines = node["maxLines"]?.intValue?.takeIf { it > 0 }?.coerceAtMost(Int.MAX_VALUE.toLong())?.toInt()
    val label = node["semanticsLabel"]?.stringValue
    Text(
        text = data,
        modifier = if (label != null) modifier.clearAndSetSemantics { contentDescription = label } else modifier,
        overflow = Props.overflow(node["overflow"]),
        softWrap = node["softWrap"]?.boolValue ?: true,
        maxLines = maxLines ?: Int.MAX_VALUE,
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
