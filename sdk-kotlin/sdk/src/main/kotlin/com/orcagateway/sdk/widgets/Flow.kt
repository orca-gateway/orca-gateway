package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.IntrinsicMeasurable
import androidx.compose.ui.layout.IntrinsicMeasureScope
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasurePolicy
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.LayoutDirection
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.WrapAlignment
import com.orcagateway.core.render.WrapCrossAlignment
import com.orcagateway.core.render.WrapRuns
import com.orcagateway.core.render.WrapSize
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.min
import kotlin.math.roundToInt

// The flow wrappers of layout_builders.dart: Wrap, Offstage and SafeArea.

/**
 * Flutter `Wrap` (`RenderWrap`) as the Flutter builder makes it: children
 * in runs along `direction` (horizontal unless "vertical"), `spacing`
 * between them and `runSpacing` between runs (0 by default), each run's
 * free space shared by `alignment` and each child placed in its run by
 * `crossAxisAlignment` ([WrapAlignment.of], [WrapCrossAlignment.of]).
 * Top down, and in the ambient direction (the builder sets no
 * textDirection): right to left the whole layout is the mirror image of
 * left to right, as Flutter's `_areAxesFlipped` makes it. Each child is
 * laid out loosely (main axis up to the incoming maximum, cross axis
 * unbounded), then [WrapRuns] breaks the runs and places them; the Wrap
 * hugs them within the parent's constraints. Its intrinsic sizes are
 * RenderWrap's.
 */
@Composable
internal fun WrapWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val vertical = node["direction"]?.stringValue == "vertical"
    val spacing = Props.number(node["spacing"]) ?: 0.0
    val runSpacing = Props.number(node["runSpacing"]) ?: 0.0
    val alignment = WrapAlignment.of(node["alignment"]?.stringValue)
    val crossAlignment = WrapCrossAlignment.of(node["crossAxisAlignment"]?.stringValue)
    val policy = remember(vertical, spacing, runSpacing, alignment, crossAlignment) {
        WrapMeasurePolicy(vertical, spacing, runSpacing, alignment, crossAlignment)
    }
    Layout(content = { for (id in node.childIds) NodeView(id, model) }, modifier = modifier, measurePolicy = policy)
}

/**
 * [WrapRuns] in pixels: the payload's dp spacings are converted once, the
 * result rounded to whole pixels, mirrored right to left.
 */
private class WrapMeasurePolicy(
    private val vertical: Boolean,
    private val spacing: Double,
    private val runSpacing: Double,
    private val alignment: WrapAlignment,
    private val crossAlignment: WrapCrossAlignment,
) : MeasurePolicy {
    override fun MeasureScope.measure(measurables: List<Measurable>, constraints: Constraints): MeasureResult {
        val loose = if (vertical) {
            Constraints(maxHeight = constraints.maxHeight)
        } else {
            Constraints(maxWidth = constraints.maxWidth)
        }
        val placeables = measurables.map { it.measure(loose) }
        val sizes = placeables.map {
            val (main, cross) = if (vertical) it.height to it.width else it.width to it.height
            WrapSize(main.toDouble(), cross.toDouble())
        }
        val c = constraints
        val layout = WrapRuns.layout(
            sizes,
            minMain = (if (vertical) c.minHeight else c.minWidth).toDouble(),
            maxMain = pixels(if (vertical) c.maxHeight else c.maxWidth),
            minCross = (if (vertical) c.minWidth else c.minHeight).toDouble(),
            maxCross = pixels(if (vertical) c.maxWidth else c.maxHeight),
            spacing = spacing * density,
            runSpacing = runSpacing * density,
            alignment = alignment,
            crossAlignment = crossAlignment,
        )
        val main = layout.size.main.roundToInt()
        val cross = layout.size.cross.roundToInt()
        val width = if (vertical) cross else main
        val rtl = layoutDirection == LayoutDirection.Rtl
        return layout(width, if (vertical) main else cross) {
            placeables.forEachIndexed { index, placeable ->
                val offset = layout.offsets[index]
                val along = offset.main.roundToInt()
                val across = offset.cross.roundToInt()
                val x = if (vertical) across else along
                placeable.place(if (rtl) width - x - placeable.width else x, if (vertical) along else across)
            }
        }
    }

    // RenderWrap's intrinsics (computeMinIntrinsicWidth and the three
    // others): along the main axis the widest child's minimum and the
    // children's maxima summed (no spacing), across it the extent of the
    // runs at that main-axis maximum ([runsCross]).

    override fun IntrinsicMeasureScope.minIntrinsicWidth(measurables: List<IntrinsicMeasurable>, height: Int): Int =
        if (vertical) {
            runsCross(measurables, height)
        } else {
            measurables.maxOfOrNull { it.minIntrinsicWidth(Constraints.Infinity) } ?: 0
        }

    override fun IntrinsicMeasureScope.maxIntrinsicWidth(measurables: List<IntrinsicMeasurable>, height: Int): Int =
        if (vertical) runsCross(measurables, height) else measurables.sumOf { it.maxIntrinsicWidth(Constraints.Infinity) }

    override fun IntrinsicMeasureScope.minIntrinsicHeight(measurables: List<IntrinsicMeasurable>, width: Int): Int =
        if (vertical) {
            measurables.maxOfOrNull { it.minIntrinsicHeight(Constraints.Infinity) } ?: 0
        } else {
            runsCross(measurables, width)
        }

    override fun IntrinsicMeasureScope.maxIntrinsicHeight(measurables: List<IntrinsicMeasurable>, width: Int): Int =
        if (vertical) measurables.sumOf { it.maxIntrinsicHeight(Constraints.Infinity) } else runsCross(measurables, width)

    /**
     * The cross extent of RenderWrap's dry layout with the main axis up to
     * [main]: each child at its max intrinsic main extent (no more than
     * [main]) and its max intrinsic cross extent there, broken into runs.
     */
    private fun IntrinsicMeasureScope.runsCross(measurables: List<IntrinsicMeasurable>, main: Int): Int {
        val sizes = measurables.map {
            if (vertical) {
                val height = min(it.maxIntrinsicHeight(Constraints.Infinity), main)
                WrapSize(height.toDouble(), it.maxIntrinsicWidth(height).toDouble())
            } else {
                val width = min(it.maxIntrinsicWidth(Constraints.Infinity), main)
                WrapSize(width.toDouble(), it.maxIntrinsicHeight(width).toDouble())
            }
        }
        val layout = WrapRuns.layout(
            sizes,
            minMain = 0.0,
            maxMain = pixels(main),
            minCross = 0.0,
            maxCross = Double.POSITIVE_INFINITY,
            spacing = spacing * density,
            runSpacing = runSpacing * density,
        )
        return layout.size.cross.roundToInt()
    }

    /** A constraint's maximum, Compose's Infinity as an infinite one. */
    private fun pixels(max: Int): Double = if (max == Constraints.Infinity) Double.POSITIVE_INFINITY else max.toDouble()
}

/**
 * Flutter `Offstage` (`RenderOffstage`), offstage unless `offstage` is
 * false. Offstage, the child is still composed and laid out with the
 * parent's constraints, so it keeps its state, but it is not placed: it
 * draws nothing, takes no input and accessibility skips it (Compose leaves
 * unplaced nodes out), and the box is the parent's smallest size (none in a
 * Column). On stage it is its
 * child, sized and placed as the child is. Both are the same layout, so
 * turning `offstage` on and off keeps the child.
 */
@Composable
internal fun OffstageWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val offstage = Props.bool(node["offstage"]) ?: true
    Layout(
        content = { ChildView(node, model) },
        modifier = modifier,
        measurePolicy = if (offstage) OffstagePolicy else OnstagePolicy,
    )
}

private val OffstagePolicy = MeasurePolicy { measurables, constraints ->
    measurables.firstOrNull()?.measure(constraints)
    layout(constraints.minWidth, constraints.minHeight) {}
}

private val OnstagePolicy = MeasurePolicy { measurables, constraints ->
    val child = measurables.firstOrNull()?.measure(constraints)
    layout(child?.width ?: constraints.minWidth, child?.height ?: constraints.minHeight) { child?.place(0, 0) }
}

/**
 * Flutter `SafeArea`: each edge flagged true (`top`, `bottom`, `left`,
 * `right`, all true by default) is padded by the device inset that still
 * reaches it, the safe drawing area (system bars, display cutout,
 * keyboard); an edge flagged false is not, so the content reaches it.
 * Insets an ancestor already took (a Scaffold's body, an enclosing
 * SafeArea) are not added again, and the edges this one takes are taken
 * for its descendants, as Flutter's `MediaQuery.removePadding`. `left` and
 * `right` are absolute edges.
 */
@Composable
internal fun SafeAreaWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val sides = listOfNotNull(
        WindowInsetsSides.Top.takeIf { Props.bool(node["top"]) ?: true },
        WindowInsetsSides.Bottom.takeIf { Props.bool(node["bottom"]) ?: true },
        WindowInsetsSides.Left.takeIf { Props.bool(node["left"]) ?: true },
        WindowInsetsSides.Right.takeIf { Props.bool(node["right"]) ?: true },
    ).reduceOrNull { all, side -> all + side }
    val padded = if (sides == null) modifier else modifier.windowInsetsPadding(WindowInsets.safeDrawing.only(sides))
    Box(padded, propagateMinConstraints = true) { ChildView(node, model) }
}
