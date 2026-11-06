package com.orcagateway.sdk.widgets

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
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import com.orcagateway.core.render.ResolvedNode
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
 * `mainAxisAlignment` spaces like any child. Expanded and Spacer are not
 * drawn yet (slice S9), so every child takes its own size.
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
 * Flutter's `RenderFlex.performLayout` for children without flex:
 *
 * 1. Each child is measured with no limit on the main axis and the Flex's
 *    limit on the cross axis: tight under `stretch` (when that limit is
 *    finite), loose otherwise.
 * 2. The Flex is as long as it may be when `mainAxisSize` is `max` and the
 *    main axis is bounded, else as long as its children (and gaps); as wide
 *    as its widest child (or its baseline extent in a Row).
 * 3. Space left over is placed by `mainAxisAlignment` over the items, gap
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
        val placeables = measurables.map { it.measure(childConstraints) }

        val gapPx = gap?.toPx() ?: 0f
        val gaps = if (gap != null) max(placeables.size - 1, 0) else 0
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
