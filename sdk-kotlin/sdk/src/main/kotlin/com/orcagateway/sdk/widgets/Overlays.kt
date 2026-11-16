package com.orcagateway.sdk.widgets

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.TextStyles
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.ENGINE_TEXT_STYLE
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.style.TextStyleProps

/**
 * BottomSheet as Flutter's `_buildBottomSheet` (structure_builders.dart)
 * builds it, a plain Container drawn where it stands: padding 16 around its
 * child (an empty box without one), `backgroundColor` (white when absent)
 * behind, the top corners rounded by `borderRadius` (16 when absent), the
 * bottom ones square. No Material, elevation or drag; `dismissible` is not
 * read. A size its parent forces passes through to the child, as through a
 * Container's padding. The decorated box takes the touches on it, as
 * Flutter's DecoratedBox is hit over its box, unless under
 * [LocalPointerBlocked]. In a Scaffold's `bottomSheet` slot the Scaffold
 * lays it on its own sheet (Structure.kt `ScaffoldBottomSheet`).
 */
@Composable
internal fun BottomSheetWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val radius = Props.length(node["borderRadius"]) ?: 16.dp
    val color = Props.color(node["backgroundColor"]) ?: Color.White
    Box(
        modifier.background(color, RoundedCornerShape(topStart = radius, topEnd = radius))
            .decorationHit(LocalPointerBlocked.current)
            .padding(16.dp),
        propagateMinConstraints = true,
    ) {
        ChildView(node, model)
    }
}

/**
 * The SnackBar widget as Flutter's `_buildSnackBar` (structure_builders.dart)
 * builds it, a static Container drawn where it stands: `backgroundColor`
 * (#323232 when absent) with corners of 4, padding 16 across and 12 down,
 * around a row of the `content` (white, 14) taking all the width left and,
 * when `actionLabel` is not empty, an 8 gap and the label (#BB86FC, 14,
 * w600) whose tap fires `onAction`, without a ripple (Flutter's
 * GestureDetector). Both texts are Flutter Texts ([FixedStyleText]): a
 * DefaultTextStyle above lies under them. As wide as its parent lets it
 * be, so it needs a bounded width. `duration` is not read: no timer, no
 * animation. The decorated box takes the touches on it, as Flutter's
 * DecoratedBox; under [LocalPointerBlocked] neither it nor the label takes
 * any.
 */
@Composable
internal fun SnackBarWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val label = node["actionLabel"]?.stringValue?.takeIf { it.isNotEmpty() }
    val blocked = LocalPointerBlocked.current
    Row(
        modifier
            .background(Props.color(node["backgroundColor"]) ?: SNACK_BAR_GREY, RoundedCornerShape(4.dp))
            .decorationHit(blocked)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FixedStyleText(Props.text(node["content"]), TextStyle(color = Color.White, fontSize = 14.sp), Modifier.weight(1f))
        if (label != null) {
            Spacer(Modifier.width(8.dp))
            val tap = if (blocked) {
                Modifier
            } else {
                Modifier.clickable(interactionSource = null, indication = null) { model.fire("onAction", on = node) }
            }
            FixedStyleText(label, TextStyle(color = SNACK_BAR_LABEL, fontSize = 14.sp, fontWeight = FontWeight.W600), tap)
        }
    }
}

/**
 * A Flutter `Text(data, style: own)` whose style is a constant of the
 * builder, not parsed from the wire (widgets/text.dart:723-797): [own] laid
 * over `DefaultTextStyle.of(context)`. Under a DefaultTextStyle node
 * ([LocalOrcaDefaultTextStyle]) that is its style on the engine's defaults,
 * with its textAlign, maxLines and overflow ([TextStyles.layer] with no
 * props of the Text's); else the surrounding style, as [TextWidget] draws a
 * Text. Not through a Text node: a parsed style always sets fontStyle
 * ([TextStyles.merge]), a constant one leaves the DTS's italic.
 */
@Composable
private fun FixedStyleText(data: String, own: TextStyle, modifier: Modifier) {
    val dts = LocalOrcaDefaultTextStyle.current?.let { TextStyles.layer(it, emptyMap()) }
    val props = TextStyleProps(dts?.style)
    val base = if (dts != null) ENGINE_TEXT_STYLE else LocalTextStyle.current
    DrawnText(
        data = data,
        props = props,
        style = drawnStyle(base, props, dts?.let { JsonValue.String(it.textAlign) }).merge(own),
        maxLines = lineLimit(dts?.maxLines) ?: Int.MAX_VALUE,
        overflowValue = dts?.let { JsonValue.String(it.overflow) },
        softWrap = true,
        modifier = modifier,
    )
}

/** Flutter's DecoratedBox is hit over its whole box: an empty pointer input, none when [blocked] ([LocalPointerBlocked]). */
private fun Modifier.decorationHit(blocked: Boolean): Modifier = if (blocked) this else pointerInput(Unit) {}

/**
 * Dialog where it stands, Flutter's `_buildDialog`: `SizedBox.shrink()`, an
 * empty box (zero, or the size its parent forces) that still counts as a
 * child of a Flex. Its children are never drawn here: `openDialog` shows
 * them. None of its props are read.
 */
@Composable
internal fun DialogWidget(modifier: Modifier) {
    Box(modifier)
}

private val SNACK_BAR_GREY = Color(0xFF323232)

private val SNACK_BAR_LABEL = Color(0xFFBB86FC)
