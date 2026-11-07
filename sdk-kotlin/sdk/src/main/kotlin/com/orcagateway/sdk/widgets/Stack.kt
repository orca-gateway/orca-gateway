package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
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
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.max

/**
 * Flutter `Stack` as the Flutter SDK builds it, drawn by
 * [StackMeasurePolicy] (Flutter's `RenderStack`) rather than Compose's Box,
 * which sizes and places differently. `alignment` places the ordinary
 * children and a Positioned child on an axis it leaves open (center when
 * absent, as the Flutter SDK's `parseAlignment` gives); `fit` is
 * [StackFit]; `clipBehavior` clips to the Stack's box only when asked
 * (`parseClip` gives `none` when absent). Later children draw on top.
 * `textDirection` is not read: the alignment and Positioned's edges are
 * absolute.
 */
@Composable
internal fun StackWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val policy = remember(node) { StackMeasurePolicy(Props.alignment(node["alignment"]), StackFit.of(node["fit"])) }
    Layout(
        content = { for (id in node.childIds) NodeView(id, model) },
        modifier = if (Props.clips(node["clipBehavior"])) modifier.clipToBounds() else modifier,
        measurePolicy = policy,
    )
}

/**
 * Flutter `Positioned`: its child, carrying the [PositionedSpec] its Stack
 * reads (see [Modifier.positioned]). The child takes exactly the width and
 * height the spec fixes, and its own size on an axis left open. Outside a
 * Stack it only draws its child.
 */
@Composable
internal fun PositionedWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    Box(modifier.positioned(PositionedSpec.of(node)), propagateMinConstraints = true) {
        ChildView(node, model)
    }
}

/**
 * Flutter `StackFit`, the constraints a Stack gives its ordinary children:
 * `loose` (the default; its own, with no minimum), `expand` (tight to the
 * largest it may be) or `passthrough` (its own, unchanged).
 */
internal enum class StackFit(val wire: String) {
    Loose("loose"),
    Expand("expand"),
    Passthrough("passthrough"),
    ;

    companion object {
        /** Flutter `parseStackFit`: anything unknown is `loose`. */
        fun of(value: JsonValue?): StackFit = entries.firstOrNull { it.wire == value?.stringValue } ?: Loose
    }
}

/**
 * Where a Positioned child sits in its Stack (Flutter
 * `StackParentData`), in dp as sent. The edges may be negative, so a child
 * hangs over the Stack's side as in Flutter; `width` and `height` are
 * lengths ([Props.length]). Left and right are absolute sides.
 */
internal data class PositionedSpec(
    val top: Dp? = null,
    val right: Dp? = null,
    val bottom: Dp? = null,
    val left: Dp? = null,
    val width: Dp? = null,
    val height: Dp? = null,
) {
    /**
     * Flutter `positionedChildConstraints`: both edges on an axis fix the
     * child's length there (the [stack]'s less both, never below 0), else
     * `width` or `height` does; an axis with neither has no limit at all.
     */
    fun constraints(stack: IntSize, density: Density): Constraints = with(density) {
        val w = if (left != null && right != null) {
            stack.width - left.roundToPx() - right.roundToPx()
        } else {
            width?.roundToPx()
        }
        val h = if (top != null && bottom != null) {
            stack.height - top.roundToPx() - bottom.roundToPx()
        } else {
            height?.roundToPx()
        }
        val fixedW = w?.coerceAtLeast(0)
        val fixedH = h?.coerceAtLeast(0)
        Constraints(
            minWidth = fixedW ?: 0,
            maxWidth = fixedW ?: Constraints.Infinity,
            minHeight = fixedH ?: 0,
            maxHeight = fixedH ?: Constraints.Infinity,
        )
    }

    /**
     * Flutter `RenderStack.layoutPositionedChild`: on each axis the child
     * sits by `left` (`top`), else by `right` (`bottom`), else where the
     * Stack's [alignment] puts a child of its [child] size.
     */
    fun offset(
        child: IntSize,
        stack: IntSize,
        alignment: Alignment,
        direction: LayoutDirection,
        density: Density,
    ): IntOffset = with(density) {
        val aligned = alignment.align(child, stack, direction)
        IntOffset(
            x = left?.roundToPx() ?: right?.let { stack.width - it.roundToPx() - child.width } ?: aligned.x,
            y = top?.roundToPx() ?: bottom?.let { stack.height - it.roundToPx() - child.height } ?: aligned.y,
        )
    }

    companion object {
        /** A Positioned node's six props; an edge is capped like a length, its sign kept. */
        fun of(node: ResolvedNode): PositionedSpec {
            val cap = Props.MAX_LENGTH.toDouble()
            fun edge(key: String): Dp? = Props.number(node[key])?.coerceIn(-cap, cap)?.toFloat()?.dp
            return PositionedSpec(
                top = edge("top"),
                right = edge("right"),
                bottom = edge("bottom"),
                left = edge("left"),
                width = Props.length(node["width"]),
                height = Props.length(node["height"]),
            )
        }
    }
}

/** Marks a Stack child as positioned by [spec] for [StackMeasurePolicy]; an unmarked child is ordinary. */
internal fun Modifier.positioned(spec: PositionedSpec): Modifier = this then PositionedElement(spec)

private class PositionedElement(val spec: PositionedSpec) : ModifierNodeElement<PositionedNode>() {
    override fun create(): PositionedNode = PositionedNode(spec)

    override fun update(node: PositionedNode) {
        node.spec = spec
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "positioned"
        value = spec
    }

    override fun equals(other: Any?): Boolean = other is PositionedElement && other.spec == spec

    override fun hashCode(): Int = spec.hashCode()
}

/** The parent data [StackMeasurePolicy] reads: the child's [PositionedSpec]. */
private class PositionedNode(var spec: PositionedSpec) : Modifier.Node(), ParentDataModifierNode {
    override fun Density.modifyParentData(parentData: Any?): Any = this@PositionedNode
}

/**
 * Flutter's `RenderStack.performLayout`:
 *
 * 1. Each ordinary child (not marked by [Modifier.positioned]) is measured
 *    with the constraints [fit] gives. `expand` holds it to the Stack's
 *    maximum on a bounded axis; on an unbounded one, where Flutter throws,
 *    it is loose.
 * 2. The Stack is as big as its largest ordinary child, and at least its
 *    minimum. With none, it is as big as it may be; on an unbounded axis,
 *    where Flutter throws, its minimum (Swift's `StackLayout` takes 0).
 * 3. Each Positioned child is measured with [PositionedSpec.constraints]
 *    of the Stack's size, and so never sizes the Stack.
 * 4. Ordinary children sit where [alignment] puts them, Positioned ones at
 *    [PositionedSpec.offset], in order, so a later child draws on top.
 */
internal class StackMeasurePolicy(private val alignment: Alignment, private val fit: StackFit) : MeasurePolicy {
    override fun MeasureScope.measure(measurables: List<Measurable>, constraints: Constraints): MeasureResult {
        val ordinary = when (fit) {
            StackFit.Loose -> constraints.copy(minWidth = 0, minHeight = 0)
            StackFit.Passthrough -> constraints
            StackFit.Expand -> Constraints(
                minWidth = if (constraints.hasBoundedWidth) constraints.maxWidth else 0,
                maxWidth = constraints.maxWidth,
                minHeight = if (constraints.hasBoundedHeight) constraints.maxHeight else 0,
                maxHeight = constraints.maxHeight,
            )
        }
        val specs = measurables.map { (it.parentData as? PositionedNode)?.spec }
        val placeables = arrayOfNulls<Placeable>(measurables.size)
        var width = constraints.minWidth
        var height = constraints.minHeight
        var hasOrdinary = false
        measurables.forEachIndexed { i, m ->
            if (specs[i] == null) {
                val p = m.measure(ordinary)
                placeables[i] = p
                width = max(width, p.width)
                height = max(height, p.height)
                hasOrdinary = true
            }
        }
        if (hasOrdinary) {
            width = width.coerceAtMost(constraints.maxWidth)
            height = height.coerceAtMost(constraints.maxHeight)
        } else {
            if (constraints.hasBoundedWidth) width = constraints.maxWidth
            if (constraints.hasBoundedHeight) height = constraints.maxHeight
        }
        val size = IntSize(width, height)
        val density: Density = this
        val direction = layoutDirection
        measurables.forEachIndexed { i, m ->
            val spec = specs[i] ?: return@forEachIndexed
            placeables[i] = m.measure(spec.constraints(size, density))
        }
        return layout(width, height) {
            placeables.forEachIndexed { i, p ->
                if (p == null) return@forEachIndexed
                val childSize = IntSize(p.width, p.height)
                val at = specs[i]?.offset(childSize, size, alignment, direction, density)
                    ?: alignment.align(childSize, size, direction)
                p.place(at)
            }
        }
    }
}
