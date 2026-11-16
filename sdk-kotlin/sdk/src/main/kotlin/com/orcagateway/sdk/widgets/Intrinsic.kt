package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.constrain
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.ceil
import kotlin.math.roundToInt

// The intrinsic and baseline boxes of layout_builders.dart. A Row or Column
// child answers its intrinsic sizes with Flutter's numbers
// (FlexMeasurePolicy). A missing child is Flutter's SizedBox.shrink(): no
// measurable, sized as a 0 by 0 child would be.

/**
 * Flutter `IntrinsicHeight` (`RenderIntrinsicHeight`): unless the parent
 * forces its height, the child gets a tight height, its max intrinsic
 * height at the parent's maximum width, brought within the parent's
 * constraints; the box is the child's size. Compose's
 * `height(IntrinsicSize.Max)` does just this, so a stretched Row inside
 * makes its children as tall as the tallest.
 */
@Composable
internal fun IntrinsicHeightWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    Box(modifier.height(IntrinsicSize.Max), propagateMinConstraints = true) { ChildView(node, model) }
}

/**
 * Flutter `IntrinsicWidth` (`RenderIntrinsicWidth`): unless the parent
 * forces its width, the child gets a tight width, its max intrinsic width
 * at the parent's maximum height rounded up to a multiple of `stepWidth`;
 * with `stepHeight` its height is made tight too, at its max intrinsic
 * height for the parent's maximum width rounded up to a multiple of that.
 * Both are brought within the parent's constraints (Flutter's `tighten`),
 * and the box is the child's size. A step that is not positive (Flutter
 * asserts) is none. Compose's `width(IntrinsicSize.Max)` has no steps,
 * hence the policy.
 */
@Composable
internal fun IntrinsicWidthWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val stepWidth = step(node["stepWidth"])
    val stepHeight = step(node["stepHeight"])
    val policy = remember(stepWidth, stepHeight) {
        MeasurePolicy { measurables, constraints ->
            val child = measurables.firstOrNull()
            val width = if (constraints.hasFixedWidth) {
                null
            } else {
                val intrinsic = child?.maxIntrinsicWidth(constraints.maxHeight) ?: 0
                constraints.constrainWidth(stepped(intrinsic, stepWidth?.dp?.toPx()))
            }
            val height = stepHeight?.let {
                constraints.constrainHeight(stepped(child?.maxIntrinsicHeight(constraints.maxWidth) ?: 0, it.dp.toPx()))
            }
            val inner = Constraints(
                minWidth = width ?: constraints.minWidth,
                maxWidth = width ?: constraints.maxWidth,
                minHeight = height ?: constraints.minHeight,
                maxHeight = height ?: constraints.maxHeight,
            )
            val placeable = child?.measure(inner)
            val size = inner.constrain(placeable?.let { IntSize(it.width, it.height) } ?: IntSize.Zero)
            layout(size.width, size.height) { placeable?.place(0, 0) }
        }
    }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

/** A positive step in dp, or none. */
private fun step(value: JsonValue?): Float? = Props.number(value)?.takeIf { it > 0 && it.isFinite() }?.toFloat()

/** Flutter `RenderIntrinsicWidth._applyStep`: [input] rounded up to a multiple of [step] (px). */
private fun stepped(input: Int, step: Float?): Int =
    if (step == null) input else (ceil(input / step) * step).roundToInt()

/**
 * Flutter `Baseline` (`RenderBaseline`): the child laid out loosely within
 * the parent's maximum and placed so its first text baseline is `baseline`
 * (0 by default) below the box's top, or, with no baseline (a box), so its
 * bottom is; a negative top lifts it above the box. The box is the child's
 * width by that top plus the child's height, within the parent's
 * constraints. It aligns nothing beside it: two texts in Baselines with the
 * same value line up because each is placed alike. `baselineType`
 * `ideographic` is drawn as alphabetic, the only baseline Compose measures
 * ([FirstBaseline]; decision s3-baseline-ideographic).
 */
@Composable
internal fun BaselineWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val baseline = (Props.number(node["baseline"]) ?: 0.0).toFloat()
    val policy = remember(baseline) { BaselineMeasurePolicy(baseline) }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

/**
 * [BaselineWidget]'s layout, [baseline] in dp. Its intrinsic sizes are the
 * child's (Flutter's `RenderShiftedBox`), not derived from [measure], where
 * an intrinsic child has no baseline and every box would answer [baseline].
 */
private class BaselineMeasurePolicy(private val baseline: Float) : MeasurePolicy {
    override fun MeasureScope.measure(measurables: List<Measurable>, constraints: Constraints): MeasureResult {
        val child = measurables.firstOrNull()?.measure(constraints.copy(minWidth = 0, minHeight = 0))
        val width = child?.width ?: 0
        val height = child?.height ?: 0
        val childBaseline = child?.get(FirstBaseline)?.takeIf { it != AlignmentLine.Unspecified } ?: height
        val top = (baseline.dp.toPx() - childBaseline).roundToInt()
        return layout(constraints.constrainWidth(width), constraints.constrainHeight(top + height)) {
            child?.place(0, top)
        }
    }

    override fun IntrinsicMeasureScope.minIntrinsicWidth(measurables: List<IntrinsicMeasurable>, height: Int): Int =
        measurables.firstOrNull()?.minIntrinsicWidth(height) ?: 0

    override fun IntrinsicMeasureScope.maxIntrinsicWidth(measurables: List<IntrinsicMeasurable>, height: Int): Int =
        measurables.firstOrNull()?.maxIntrinsicWidth(height) ?: 0

    override fun IntrinsicMeasureScope.minIntrinsicHeight(measurables: List<IntrinsicMeasurable>, width: Int): Int =
        measurables.firstOrNull()?.minIntrinsicHeight(width) ?: 0

    override fun IntrinsicMeasureScope.maxIntrinsicHeight(measurables: List<IntrinsicMeasurable>, width: Int): Int =
        measurables.firstOrNull()?.maxIntrinsicHeight(width) ?: 0
}
