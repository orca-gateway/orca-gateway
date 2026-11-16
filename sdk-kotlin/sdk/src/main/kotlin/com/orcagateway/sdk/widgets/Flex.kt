package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.AlignmentLine
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.IntrinsicMeasurable
import androidx.compose.ui.layout.IntrinsicMeasureScope
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
import androidx.compose.ui.unit.LayoutDirection
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Column and Row (Flutter `Flex`), drawn by [FlexMeasurePolicy] so the
 * layout follows Flutter's `RenderFlex` rather than Compose's Column and
 * Row, which differ in ways pages would see (they bound a child's main axis
 * by the space left, and have no `spaceAround` with a gap).
 *
 * `gap` is the Flutter SDK's: a box `gap` long between two children, which
 * `mainAxisAlignment` spaces like any child. An Expanded, Flexible or
 * Spacer child ([ExpandedWidget], [FlexibleWidget], [SpacerWidget]) takes
 * a share of the space the others leave; every other child takes its own
 * size.
 *
 * `textDirection` (`ltr` or `rtl`; the page's direction when absent) and
 * `verticalDirection` (`up` or `down`) order the Flex's own layout only:
 * its children keep the page's layout direction, as Flutter's Flex sets no
 * Directionality for them.
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
            textDirection = when (node["textDirection"]?.stringValue) {
                "ltr" -> LayoutDirection.Ltr
                "rtl" -> LayoutDirection.Rtl
                else -> null
            },
            up = node["verticalDirection"]?.stringValue == "up",
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
 * Flutter `Flexible` (`flex`, 1 by default; `fit`, loose unless `tight`):
 * inside a Row or Column it takes a share of the main axis as Expanded
 * does, but a loose child is held only to at most its share
 * (`RenderFlex._constraintsForFlexChild`, `FlexFit.loose`): it keeps its
 * own size and what it leaves of the share is placed by
 * `mainAxisAlignment`. Outside a Row or Column the flex is not read and it
 * just draws its child, as Flutter does in release builds.
 */
@Composable
internal fun FlexibleWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val fill = node["fit"]?.stringValue == "tight"
    Box(modifier.flex(flexOf(node), fill), propagateMinConstraints = true) {
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
 * no mark) is an ordinary child, and a negative flex counts as 0. [fill]
 * is Flutter's `FlexFit`: tight (Expanded, Spacer) forces the child to its
 * share, loose (Flexible) lets it be smaller.
 */
internal fun Modifier.flex(flex: Int, fill: Boolean = true): Modifier = this then FlexFactorElement(max(flex, 0), fill)

private class FlexFactorElement(val flex: Int, val fill: Boolean) : ModifierNodeElement<FlexFactorNode>() {
    override fun create(): FlexFactorNode = FlexFactorNode(flex, fill)

    override fun update(node: FlexFactorNode) {
        node.flex = flex
        node.fill = fill
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "flex"
        value = flex
        properties["fill"] = fill
    }

    override fun equals(other: Any?): Boolean = other is FlexFactorElement && other.flex == flex && other.fill == fill

    override fun hashCode(): Int = 31 * flex + fill.hashCode()
}

/** The parent data [FlexMeasurePolicy] reads: the child's `flex` and fit. */
private class FlexFactorNode(var flex: Int, var fill: Boolean) : Modifier.Node(), ParentDataModifierNode {
    override fun Density.modifyParentData(parentData: Any?): Any = this@FlexFactorNode
}

/**
 * Flutter's `RenderFlex.performLayout`:
 *
 * 1. Each child without flex is measured with no limit on the main axis and
 *    the Flex's limit on the cross axis: tight under `stretch` (when that
 *    limit is finite), loose otherwise.
 * 2. The main-axis space left after them and the gaps is shared by the
 *    children with flex (see [Modifier.flex]) in proportion to it, on the
 *    same cross axis: a tight child (Expanded) is held to exactly its share,
 *    a loose one (Flexible) to at most it, what it leaves going to
 *    `mainAxisAlignment`, not to the others (`_constraintsForFlexChild`).
 *    Shares are rounded to whole pixels so they add up to the space left,
 *    which leaves nothing to place when every flex child is tight. When the
 *    main axis has no limit (a Column in a scroll view), where Flutter
 *    throws, a flex child is measured like the others and takes its own
 *    size, as the Swift SDK's `FlexLayout` does.
 * 3. The Flex is as long as it may be when `mainAxisSize` is `max` and the
 *    main axis is bounded, else as long as its children (and gaps); as wide
 *    as its widest child (or its baseline extent in a Row).
 * 4. Space left over is placed by `mainAxisAlignment` over the items, gap
 *    boxes included; each child sits on the cross axis by
 *    `crossAxisAlignment`. `baseline` aligns the first baselines in a Row,
 *    a child without one sitting at the top; in a Column it is the left
 *    edge (Flutter's offset 0).
 *
 * Flutter's `_flipMainAxis` and `_flipCrossAxis`: a right-to-left
 * [textDirection] (the layout direction when null) mirrors a Row's main
 * axis and a Column's cross axis; [up] mirrors a Column's main axis (its
 * first child at the bottom) and a Row's cross axis (`start` at the
 * bottom). Positions are absolute, so nothing else mirrors them.
 */
internal class FlexMeasurePolicy(
    private val vertical: Boolean,
    private val main: Props.MainAxis,
    private val cross: Props.CrossAxis,
    private val fill: Boolean,
    /** The gap box between two children; null sends none. */
    private val gap: Dp?,
    /** Flutter's `textDirection`; null follows the layout direction. */
    private val textDirection: LayoutDirection? = null,
    /** Flutter's `verticalDirection: up`. */
    private val up: Boolean = false,
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
        val free = max(0f, maxMain - fixed.sumOf { if (it != null) mainOf(it) else 0 } - gapPx * gaps)
        val shares = shares(free, flexes)
        val placeables = measurables.mapIndexed { i, m ->
            fixed[i] ?: run {
                val share = shares[i]
                val least = if ((m.parentData as? FlexFactorNode)?.fill == false) 0 else share
                m.measure(
                    if (vertical) {
                        childConstraints.copy(minHeight = least, maxHeight = share)
                    } else {
                        childConstraints.copy(minWidth = least, maxWidth = share)
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

        val rtl = (textDirection ?: layoutDirection) == LayoutDirection.Rtl
        val flipMain = if (vertical) up else rtl
        val flipCross = if (vertical) rtl else up
        val width = if (vertical) crossLength else mainSize
        val height = if (vertical) mainSize else crossLength
        return layout(width, height) {
            var position = leading
            placeables.forEachIndexed { i, p ->
                if (i > 0 && gap != null) position += gapPx + between
                val free = crossLength - crossOf(p)
                val offset = when {
                    baseline -> baselines[i].let { if (it == AlignmentLine.Unspecified) 0 else maxAbove - it }
                    cross == Props.CrossAxis.Start -> if (flipCross) free else 0
                    cross == Props.CrossAxis.End -> if (flipCross) 0 else free
                    cross == Props.CrossAxis.Center -> free / 2
                    else -> 0
                }
                val at = position.roundToInt().let { if (flipMain) mainSize - it - mainOf(p) else it }
                if (vertical) p.place(offset, at) else p.place(at, offset)
                position += mainOf(p) + between
            }
        }
    }

    override fun IntrinsicMeasureScope.minIntrinsicWidth(measurables: List<IntrinsicMeasurable>, height: Int): Int =
        intrinsic(measurables, height, horizontal = true, min = true)

    override fun IntrinsicMeasureScope.maxIntrinsicWidth(measurables: List<IntrinsicMeasurable>, height: Int): Int =
        intrinsic(measurables, height, horizontal = true, min = false)

    override fun IntrinsicMeasureScope.minIntrinsicHeight(measurables: List<IntrinsicMeasurable>, width: Int): Int =
        intrinsic(measurables, width, horizontal = false, min = true)

    override fun IntrinsicMeasureScope.maxIntrinsicHeight(measurables: List<IntrinsicMeasurable>, width: Int): Int =
        intrinsic(measurables, width, horizontal = false, min = false)

    /**
     * Flutter's `RenderFlex._getIntrinsicSize`, the [min] or max intrinsic
     * width ([horizontal]) or height for [extent] on the other axis. Compose would
     * derive it from [measure], which gives a flex child no share.
     *
     * Along the main axis: the children without flex and the gaps, plus the
     * largest intrinsic length per flex among the flex children times the
     * total flex (rounded up). Across: the largest child, each child without
     * flex taken at its max intrinsic main length, each flex child at its
     * share of what they leave of [extent] (none when it is unbounded). A
     * Row aligned on `baseline` answers its tallest child's height, not
     * Flutter's ascent plus descent: intrinsics carry no baselines.
     */
    private fun IntrinsicMeasureScope.intrinsic(
        measurables: List<IntrinsicMeasurable>,
        extent: Int,
        horizontal: Boolean,
        min: Boolean,
    ): Int {
        val size = { m: IntrinsicMeasurable, other: Int ->
            when {
                horizontal && min -> m.minIntrinsicWidth(other)
                horizontal -> m.maxIntrinsicWidth(other)
                min -> m.minIntrinsicHeight(other)
                else -> m.maxIntrinsicHeight(other)
            }
        }
        val gaps = (gap?.toPx() ?: 0f) * if (gap != null) max(measurables.size - 1, 0) else 0
        if (horizontal != vertical) {
            var totalFlex = 0L
            var inflexible = gaps
            var perFlex = 0f
            for (m in measurables) {
                val flex = (m.parentData as? FlexFactorNode)?.flex ?: 0
                totalFlex += flex
                if (flex > 0) {
                    perFlex = max(perFlex, size(m, extent).toFloat() / flex)
                } else {
                    inflexible += size(m, extent)
                }
            }
            return ceil(perFlex * totalFlex + inflexible).toInt()
        }
        val bounded = extent != Constraints.Infinity
        val flexes = measurables.map { if (bounded) (it.parentData as? FlexFactorNode)?.flex ?: 0 else 0 }
        var used = gaps
        var crossSize = 0
        measurables.forEachIndexed { i, m ->
            if (flexes[i] == 0) {
                val main = if (vertical) {
                    m.maxIntrinsicHeight(Constraints.Infinity)
                } else {
                    m.maxIntrinsicWidth(Constraints.Infinity)
                }
                used += main
                crossSize = max(crossSize, size(m, main))
            }
        }
        val shares = shares(max(0f, extent - used), flexes)
        measurables.forEachIndexed { i, m -> if (flexes[i] > 0) crossSize = max(crossSize, size(m, shares[i])) }
        return crossSize
    }

    /**
     * Each flex child's share of [free] in proportion to its flex (0 for a
     * child without), rounded to whole pixels so the shares add up to it.
     */
    private fun shares(free: Float, flexes: List<Int>): List<Int> {
        val totalFlex = flexes.sumOf { it.toLong() }
        var flexBefore = 0L
        return flexes.map { flex ->
            if (flex == 0) {
                0
            } else {
                val start = (free * flexBefore / totalFlex).roundToInt()
                flexBefore += flex
                (free * flexBefore / totalFlex).roundToInt() - start
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
