package com.orcagateway.sdk.widgets

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasurePolicy
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Insets
import com.orcagateway.sdk.style.Props
import kotlin.math.max
import kotlin.math.roundToInt

// Compose passes constraints down the way Flutter does, so these widgets
// keep Flutter's sizing with plain modifiers. A pass-through box keeps the
// parent's minimum (`propagateMinConstraints`), so a size the parent forces
// reaches the child, as a tight constraint passes through Padding and
// SizedBox in Flutter. Swift's `TightAxes` environment stands in for this
// on SwiftUI and has no Compose port.

/**
 * Flutter `Center` (`RenderPositionedBox`): the child loose in the middle.
 * On an axis with a factor (`widthFactor`, `heightFactor`) or no limit it is
 * the child's size times the factor (1 when absent); on the others as big
 * as it may be.
 */
@Composable
internal fun CenterWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val widthFactor = Props.number(node["widthFactor"])
    val heightFactor = Props.number(node["heightFactor"])
    val policy = remember(widthFactor, heightFactor) { CenterMeasurePolicy(widthFactor, heightFactor) }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

private class CenterMeasurePolicy(
    private val widthFactor: Double?,
    private val heightFactor: Double?,
) : MeasurePolicy {
    override fun MeasureScope.measure(measurables: List<Measurable>, constraints: Constraints): MeasureResult {
        val child = measurables.firstOrNull()?.measure(constraints.copy(minWidth = 0, minHeight = 0))
        val width = side(child?.width ?: 0, widthFactor, constraints.hasBoundedWidth, constraints.maxWidth)
            .coerceIn(constraints.minWidth, constraints.maxWidth)
        val height = side(child?.height ?: 0, heightFactor, constraints.hasBoundedHeight, constraints.maxHeight)
            .coerceIn(constraints.minHeight, constraints.maxHeight)
        return layout(width, height) {
            child?.place(
                Alignment.Center.align(IntSize(child.width, child.height), IntSize(width, height), layoutDirection),
            )
        }
    }

    /** Flutter's shrink-wrapped side (the child's times the factor) with a factor or no limit, else the limit. */
    private fun side(child: Int, factor: Double?, bounded: Boolean, max: Int): Int =
        if (factor != null || !bounded) (child * (factor ?: 1.0)).roundToInt() else max
}

/** Flutter `Padding`: the child inset by `padding`; with no child, a box of the padding. */
@Composable
internal fun PaddingWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val insets = Props.insets(node["padding"]) ?: Insets.Zero
    Box(modifier.padding(insets.paddingValues()), propagateMinConstraints = true) {
        ChildView(node, model)
    }
}

/**
 * Flutter `SizedBox`: a fixed size on the axes it names, forced on its
 * child; with no child, an empty box of that size (the parent's minimum on
 * an axis it leaves out, 0 in a loose parent).
 */
@Composable
internal fun SizedBoxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    var sized = modifier
    Props.length(node["width"])?.let { sized = sized.width(it) }
    Props.length(node["height"])?.let { sized = sized.height(it) }
    if (node.childIds.isEmpty()) {
        Spacer(sized)
    } else {
        Box(sized, propagateMinConstraints = true) { ChildView(node, model) }
    }
}

/**
 * Flutter `SingleChildScrollView`: `scrollDirection` (`vertical` by default)
 * and `padding` inside the scrolled content. On an axis with no limit (a
 * scroll view inside a Column) it takes its child's size and does not
 * scroll, as Flutter's viewport does; Compose would throw there.
 *
 * As in Flutter's viewport the content has no minimum on the scroll axis:
 * shorter than the view, it keeps its length and sits at the start, or at
 * the far end with `reverse`, which also puts scroll offset 0 at the far
 * end (Compose's `reverseScrolling`). `shrinkWrap` is Flutter's
 * IntrinsicHeight (IntrinsicWidth) around the view, which then hugs its
 * content within its limits; this view already does, so it changes
 * nothing. `primary` hands the view to the iOS status-bar tap in Flutter
 * and has no Android counterpart: it is ignored.
 */
@Composable
internal fun ScrollWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val horizontal = node["scrollDirection"]?.stringValue == "horizontal"
    val reverse = Props.bool(node["reverse"]) ?: false
    val insets = Props.insets(node["padding"]) ?: Insets.Zero
    BoxWithConstraints(modifier, propagateMinConstraints = true) {
        val bounded = if (horizontal) constraints.hasBoundedWidth else constraints.hasBoundedHeight
        val state = rememberScrollState()
        val scroll = when {
            !bounded -> Modifier
            horizontal -> Modifier.horizontalScroll(state, reverseScrolling = reverse)
            else -> Modifier.verticalScroll(state, reverseScrolling = reverse)
        }
        val content = scroll.scrolledContent(horizontal, reverse).padding(insets.paddingValues())
        Box(content, propagateMinConstraints = true) {
            ChildView(node, model)
        }
    }
}

/**
 * The scrolled content measured with no minimum on the scroll axis, in a
 * box that still fills the view: the content at the box's start, or at its
 * far end when [reverse].
 */
private fun Modifier.scrolledContent(horizontal: Boolean, reverse: Boolean): Modifier =
    layout { measurable, constraints ->
        val content = measurable.measure(
            if (horizontal) constraints.copy(minWidth = 0) else constraints.copy(minHeight = 0),
        )
        val width = max(content.width, constraints.minWidth)
        val height = max(content.height, constraints.minHeight)
        layout(width, height) {
            val far = if (horizontal) IntOffset(width - content.width, 0) else IntOffset(0, height - content.height)
            content.placeRelative(if (reverse) far else IntOffset.Zero)
        }
    }
