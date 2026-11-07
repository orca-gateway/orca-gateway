package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.AlignmentLine
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasurePolicy
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.layout.Placeable
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.ParentDataModifierNode
import androidx.compose.ui.platform.InspectorInfo
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Column and Row (Flutter `Flex`), drawn by [FlexMeasurePolicy] so the
 * layout follows Flutter's `RenderFlex` rather than Compose's Column and
 * Row, which differ in ways pages would see (they bound a child's main axis
 * by the space left, and have no `spaceAround` with a gap).
 *
 * `gap` is the Flutter SDK's: a box `gap` long between two children, which
 * `mainAxisAlignment` spaces like any child. An Expanded or Spacer child
 * ([ExpandedWidget], [SpacerWidget]) takes a share of the space the others
 * leave; every other child takes its own size.
 */
@Composable
internal fun FlexWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier, vertical: Boolean) {
    val policy = remember(vertical, node) {
        FlexMeasurePolicy(
            vertical = vertical,
            main = Props.mainAxis(node["mainAxisAlignment"]),
            cross = Props.crossAxis(node["crossAxisAlignment"]),
            fill = Props.fillsMainAxis(node["mainAxisSize"]),
            gap = Props.length(node["gap"]),
        )
    }
    Layout(
        content = { for (id in node.childIds) NodeView(id, model) },
        modifier = modifier,
        measurePolicy = policy,
    )
}

/**
 * Flutter `Expanded` (`flex`, 1 by default): its child gets exactly the
 * share of the main axis [FlexMeasurePolicy] gives it, starting at the
 * leading edge. With no child it is an empty box of that share.
 */
@Composable
internal fun ExpandedWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    Box(modifier.flex(flexOf(node)), propagateMinConstraints = true) {
        ChildView(node, model)
    }
}

/**
 * Flutter `Spacer` (`flex`, 1 by default): an Expanded with an empty child,
 * as long as its share. It has no size of its own, so it never widens a
 * Row's cross axis.
 */
@Composable
internal fun SpacerWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    Spacer(modifier.flex(flexOf(node)))
}

/** Flutter `propOr<int>('flex', 1)`, never below 0. */
private fun flexOf(node: ResolvedNode): Int =
    (node["flex"]?.intValue ?: 1).coerceIn(0, Int.MAX_VALUE.toLong()).toInt()

/**
 * Marks a Flex child with Flutter's `flex` for [FlexMeasurePolicy]; 0 (or
 * no mark) is an ordinary child, and a negative flex counts as 0.
 */
internal fun Modifier.flex(flex: Int): Modifier = this then FlexFactorElement(max(flex, 0))

private class FlexFactorElement(val flex: Int) : ModifierNodeElement<FlexFactorNode>() {
    override fun create(): FlexFactorNode = FlexFactorNode(flex)

    override fun update(node: FlexFactorNode) {
        node.flex = flex
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "flex"
        value = flex
    }

    override fun equals(other: Any?): Boolean = other is FlexFactorElement && other.flex == flex

    override fun hashCode(): Int = flex
}

/** The parent data [FlexMeasurePolicy] reads: the child's `flex`. */
private class FlexFactorNode(var flex: Int) : Modifier.Node(), ParentDataModifierNode {
    override fun Density.modifyParentData(parentData: Any?): Any = this@FlexFactorNode
}

/**
 * Flutter's `RenderFlex.performLayout`:
 *
 * 1. Each child without flex is measured with no limit on the main axis and
 *    the Flex's limit on the cross axis: tight under `stretch` (when that
 *    limit is finite), loose otherwise.
 * 2. The main-axis space left after them and the gaps is shared by the
 *    children with flex (see [Modifier.flex]) in proportion to it, each held
 *    to exactly its share (Expanded's tight fit), on the same cross axis.
 *    Shares are rounded to whole pixels so they add up to the space left,
 *    which leaves nothing for `mainAxisAlignment` to place. When the main
 *    axis has no limit (a Column in a scroll view), where Flutter throws, a
 *    flex child is measured like the others and takes its own size, as the
 *    Swift SDK's `FlexLayout` does.
 * 3. The Flex is as long as it may be when `mainAxisSize` is `max` and the
 *    main axis is bounded, else as long as its children (and gaps); as wide
 *    as its widest child (or its baseline extent in a Row).
 * 4. Space left over is placed by `mainAxisAlignment` over the items, gap
 *    boxes included; each child sits on the cross axis by
 *    `crossAxisAlignment`. `baseline` aligns the first baselines in a Row,
 *    a child without one sitting at the top; in a Column it is `start`.
 *
 * Positions are relative, so a right-to-left layout mirrors a Row's main
 * axis and a Column's cross axis, as Flutter's text direction does.
 */
internal class FlexMeasurePolicy(
    private val vertical: Boolean,
    private val main: Props.MainAxis,
    private val cross: Props.CrossAxis,
    private val fill: Boolean,
    /** The gap box between two children; null sends none. */
    private val gap: Dp?,
) : MeasurePolicy {
    override fun MeasureScope.measure(measurables: List<Measurable>, constraints: Constraints): MeasureResult {
        val maxMain = if (vertical) constraints.maxHeight else constraints.maxWidth
        val minMain = if (vertical) constraints.minHeight else constraints.minWidth
        val maxCross = if (vertical) constraints.maxWidth else constraints.maxHeight
        val minCross = if (vertical) constraints.minWidth else constraints.minHeight
        val boundedMain = maxMain != Constraints.Infinity
        val boundedCross = maxCross != Constraints.Infinity
        val stretch = cross == Props.CrossAxis.Stretch && boundedCross

        val childMinCross = if (stretch) maxCross else 0
        val childConstraints = if (vertical) {
            Constraints(minWidth = childMinCross, maxWidth = maxCross)
        } else {
            Constraints(minHeight = childMinCross, maxHeight = maxCross)
        }
        val flexes = measurables.map { if (boundedMain) (it.parentData as? FlexFactorNode)?.flex ?: 0 else 0 }
        val fixed = measurables.mapIndexed { i, m -> if (flexes[i] == 0) m.measure(childConstraints) else null }

        val gapPx = gap?.toPx() ?: 0f
        val gaps = if (gap != null) max(measurables.size - 1, 0) else 0
        val totalFlex = flexes.sumOf { it.toLong() }
        val free = max(0f, maxMain - fixed.sumOf { if (it != null) mainOf(it) else 0 } - gapPx * gaps)
        var flexBefore = 0L
        val placeables = measurables.mapIndexed { i, m ->
            fixed[i] ?: run {
                val start = (free * flexBefore / totalFlex).roundToInt()
                flexBefore += flexes[i]
                val share = (free * flexBefore / totalFlex).roundToInt() - start
                m.measure(
                    if (vertical) {
                        childConstraints.copy(minHeight = share, maxHeight = share)
                    } else {
                        childConstraints.copy(minWidth = share, maxWidth = share)
                    },
                )
            }
        }

        val items = placeables.size + gaps
        val allocated = placeables.sumOf { mainOf(it) }.toFloat() + gapPx * gaps

        val baseline = !vertical && cross == Props.CrossAxis.Baseline
        val baselines = if (baseline) placeables.map { it[FirstBaseline] } else emptyList()
        var crossSize = placeables.maxOfOrNull { crossOf(it) } ?: 0
        var maxAbove = 0
        if (baseline) {
            var maxBelow = 0
            placeables.forEachIndexed { i, p ->
                val b = baselines[i]
                if (b != AlignmentLine.Unspecified) {
                    maxAbove = max(maxAbove, b)
                    maxBelow = max(maxBelow, p.height - b)
                }
            }
            crossSize = max(crossSize, maxAbove + maxBelow)
        }
        if (stretch) crossSize = maxCross

        val ideal = if (fill && boundedMain) maxMain.toFloat() else allocated
        val mainSize = ideal.roundToInt().coerceIn(minMain, maxMain)
        val crossLength = crossSize.coerceIn(minCross, maxCross)

        val remaining = max(0f, mainSize - allocated)
        val (leading, between) = spacing(remaining, items)

        val width = if (vertical) crossLength else mainSize
        val height = if (vertical) mainSize else crossLength
        return layout(width, height) {
            var position = leading
            placeables.forEachIndexed { i, p ->
                if (i > 0 && gap != null) position += gapPx + between
                val offset = when {
                    baseline -> baselines[i].let { if (it == AlignmentLine.Unspecified) 0 else maxAbove - it }
                    cross == Props.CrossAxis.End -> crossLength - crossOf(p)
                    cross == Props.CrossAxis.Center -> (crossLength - crossOf(p)) / 2
                    else -> 0
                }
                val at = position.roundToInt()
                if (vertical) p.placeRelative(offset, at) else p.placeRelative(at, offset)
                position += mainOf(p) + between
            }
        }
    }

    /**
     * Flutter's leading space and space between items for the free space
     * left on the main axis.
     */
    private fun spacing(remaining: Float, items: Int): Pair<Float, Float> = when (main) {
        Props.MainAxis.Start -> 0f to 0f
        Props.MainAxis.End -> remaining to 0f
        Props.MainAxis.Center -> remaining / 2 to 0f
        Props.MainAxis.SpaceBetween -> 0f to (if (items > 1) remaining / (items - 1) else 0f)
        Props.MainAxis.SpaceAround -> {
            val between = if (items > 0) remaining / items else 0f
            between / 2 to between
        }
        Props.MainAxis.SpaceEvenly -> {
            val between = if (items > 0) remaining / (items + 1) else 0f
            between to between
        }
    }

    private fun mainOf(p: Placeable): Int = if (vertical) p.height else p.width

    private fun crossOf(p: Placeable): Int = if (vertical) p.width else p.height
}
