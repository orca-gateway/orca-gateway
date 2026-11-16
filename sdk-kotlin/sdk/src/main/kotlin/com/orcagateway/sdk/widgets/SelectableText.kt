package com.orcagateway.sdk.widgets

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.absolutePadding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.TextStyles
import com.orcagateway.sdk.style.ENGINE_TEXT_STYLE
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.style.TextStyleProps

/** Flutter's caret margin: the cursor's 2 and a gap of 1 (rendering/editable.dart:25, :1272). */
private val CARET_MARGIN = 3.dp

/**
 * Flutter `SelectableText` as the builder makes it (primitive_builders.dart:
 * 350-362): Material's SelectableText, a read-only EditableText
 * (selectable_text.dart:705-799), drawn here as [TextWidget]'s text
 * ([DrawnText]) in a [SelectionContainer]: a long press or a double tap
 * selects a word, with handles and the system's Copy toolbar. The style is
 * the DefaultTextStyle's with its own fields over it, on the engine's
 * defaults, or its own on the ambient style outside any DTS (Flutter reads
 * `DefaultTextStyle.of(context)`, the Material's there); textAlign own ??
 * DTS ?? start, maxLines own ?? DTS ([TextStyles.layer], :753-785). No
 * overflow: nothing is ellipsized. It scales with the font scale, as
 * EditableText's textScaler. Laid out as RenderEditable: the text's width
 * plus the 3 px caret margin on the right (:2272, :2407); maxLines 1 one
 * line on an unbounded width that scrolls sideways (:2276-2279); maxLines
 * n > 1 a box n lines tall, however short the text (minLines is maxLines,
 * :1943-1944, :2412-2416), whose text wraps and scrolls up and down.
 */
@Composable
internal fun SelectableTextWidget(node: ResolvedNode, modifier: Modifier) {
    val dts = LocalOrcaDefaultTextStyle.current?.let { TextStyles.layer(it, node.props) }
    val props = TextStyleProps(if (dts != null) dts.style else node["style"])
    val base = if (dts != null) ENGINE_TEXT_STYLE else LocalTextStyle.current
    val style = drawnStyle(base, props, if (dts != null) JsonValue.String(dts.textAlign) else node["textAlign"])
    val maxLines = lineLimit(if (dts != null) dts.maxLines else node["maxLines"]?.intValue)
    val scroll = rememberScrollState()
    val box = when (maxLines) {
        null -> Modifier
        1 -> Modifier.horizontalScroll(scroll)
        else -> Modifier.height(linesHeight(style, maxLines)).verticalScroll(scroll)
    }
    SelectionContainer(modifier) {
        DrawnText(
            data = Props.text(node["data"]),
            props = props,
            style = style,
            maxLines = if (maxLines == 1) 1 else Int.MAX_VALUE,
            overflowValue = null,
            softWrap = maxLines != 1,
            modifier = box.absolutePadding(right = CARET_MARGIN),
        )
    }
}

/**
 * The height of [lines] lines of [style]: Flutter's preferredLineHeight
 * times maxLines, measured as a paragraph of that many blank lines so it
 * matches a Text cut at that many lines.
 */
@Composable
private fun linesHeight(style: TextStyle, lines: Int): Dp {
    val measurer = rememberTextMeasurer()
    val height = remember(measurer, style, lines) {
        measurer.measure(List(lines) { " " }.joinToString("\n"), style).size.height
    }
    return with(LocalDensity.current) { height.toDp() }
}
