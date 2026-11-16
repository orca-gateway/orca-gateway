package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.MeasurePolicy
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.constrain
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.roundToInt

// The sizing boxes of layout_builders.dart. Where Compose has a modifier
// that sizes as the Flutter render object does (ConstrainedBox) it is used;
// the others differ from Compose's (`aspectRatio` tries the sizes in
// another order, `fillMaxWidth(fraction)` cannot overflow or align, nothing
// reads whether a limit is unbounded) and get a measure policy that follows
// Flutter's. A missing child is Flutter's SizedBox.shrink(): no measurable,
// sized as a 0 by 0 child would be.

/**
 * Flutter `Align` (`RenderPositionedBox`): the child loose, placed by
 * `alignment` (Flutter `parseAlignment`, center by default). An axis with a
 * factor (`widthFactor`, `heightFactor`) is the child's size times it; with
 * none, it fills a bounded axis and takes the child's size on an unbounded
 * one. Center is this at center ([CenterMeasurePolicy]).
 */
@Composable
internal fun AlignWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val widthFactor = Props.number(node["widthFactor"])
    val heightFactor = Props.number(node["heightFactor"])
    val alignment = Props.alignment(node["alignment"])
    val policy = remember(widthFactor, heightFactor, alignment) {
        CenterMeasurePolicy(widthFactor, heightFactor, alignment)
    }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

/**
 * Flutter `AspectRatio` (`RenderAspectRatio._applyAspectRatio`): `width /
 * height` = `aspectRatio` (1 by default). A tight parent gives its size;
 * otherwise the width is the parent's maximum (or, unbounded, the height is
 * and the width follows), then brought within the maximum and minimum
 * width and height in Flutter's order. The child is forced to that size.
 * A ratio that is not positive and finite (Flutter asserts) is 1; with
 * neither axis bounded (Flutter throws) it is the parent's minimum.
 */
@Composable
internal fun AspectRatioWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val ratio = Props.number(node["aspectRatio"])?.takeIf { it > 0 && it.isFinite() } ?: 1.0
    val policy = remember(ratio) {
        MeasurePolicy { measurables, constraints ->
            val size = constraints.aspectSize(ratio)
            val child = measurables.firstOrNull()?.measure(Constraints.fixed(size.width, size.height))
            layout(size.width, size.height) { child?.place(0, 0) }
        }
    }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

/**
 * Flutter's starting size, the parent's maximum width (or, with that
 * unbounded, its maximum height) at [ratio], fitted as RenderImage fits
 * ([fitting]): the same clamps in the same order.
 */
private fun Constraints.aspectSize(ratio: Double): IntSize = when {
    hasBoundedWidth -> fitting(maxWidth.toFloat(), (maxWidth / ratio).toFloat())
    hasBoundedHeight -> fitting((maxHeight * ratio).toFloat(), maxHeight.toFloat())
    else -> IntSize(minWidth, minHeight)
}

/**
 * Flutter `ConstrainedBox` (`RenderConstrainedBox`): the child gets
 * `constraints` (a missing min 0, a missing max no limit) enforced within
 * the parent's, so a tight parent wins, and the box is the child's size.
 * Compose's `sizeIn` constrains exactly as `BoxConstraints.enforce` (each
 * bound clamped to the parent's range); the box passes its minimum on.
 */
@Composable
internal fun ConstrainedBoxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val box = node["constraints"]?.objectValue
    val bounds = modifier.sizeIn(
        minWidth = Props.length(box?.get("minWidth")) ?: Dp.Unspecified,
        minHeight = Props.length(box?.get("minHeight")) ?: Dp.Unspecified,
        maxWidth = Props.length(box?.get("maxWidth")) ?: Dp.Unspecified,
        maxHeight = Props.length(box?.get("maxHeight")) ?: Dp.Unspecified,
    )
    Box(bounds, propagateMinConstraints = true) { ChildView(node, model) }
}

/**
 * Flutter `LimitedBox` (`RenderLimitedBox`): `maxWidth` and `maxHeight` (no
 * limit when missing) cap only an axis whose incoming maximum is unbounded,
 * as in a scroll view; under a bounded parent it passes the constraints
 * through. The box is the child's size within the parent's constraints.
 */
@Composable
internal fun LimitedBoxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val maxWidth = Props.length(node["maxWidth"]) ?: Dp.Infinity
    val maxHeight = Props.length(node["maxHeight"]) ?: Dp.Infinity
    val policy = remember(maxWidth, maxHeight) {
        MeasurePolicy { measurables, constraints ->
            val limited = constraints.copy(
                maxWidth = if (constraints.hasBoundedWidth) {
                    constraints.maxWidth
                } else {
                    constraints.constrainWidth(maxWidth.roundToPx())
                },
                maxHeight = if (constraints.hasBoundedHeight) {
                    constraints.maxHeight
                } else {
                    constraints.constrainHeight(maxHeight.roundToPx())
                },
            )
            val child = measurables.firstOrNull()?.measure(limited)
            val size = constraints.constrain(child?.let { IntSize(it.width, it.height) } ?: limited.constrain(IntSize.Zero))
            layout(size.width, size.height) { child?.place(0, 0) }
        }
    }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

/**
 * Flutter `FractionallySizedBox` (`RenderFractionallySizedOverflowBox`): an
 * axis with a factor (`widthFactor`, `heightFactor`) is forced on the child
 * at the parent's maximum times it, an axis without keeps the parent's
 * constraints. The box is the child's size within the parent's
 * constraints, the child placed in it by `alignment` (center by default)
 * and free to overflow it. A factor on an unbounded axis (Flutter fails
 * there) keeps the parent's constraints.
 */
@Composable
internal fun FractionallySizedBoxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val widthFactor = Props.number(node["widthFactor"])
    val heightFactor = Props.number(node["heightFactor"])
    val alignment = Props.alignment(node["alignment"])
    val policy = remember(widthFactor, heightFactor, alignment) {
        MeasurePolicy { measurables, constraints ->
            val width = widthFactor?.takeIf { constraints.hasBoundedWidth }
                ?.let { (constraints.maxWidth * it).roundToInt().coerceAtLeast(0) }
            val height = heightFactor?.takeIf { constraints.hasBoundedHeight }
                ?.let { (constraints.maxHeight * it).roundToInt().coerceAtLeast(0) }
            val inner = Constraints(
                minWidth = width ?: constraints.minWidth,
                maxWidth = width ?: constraints.maxWidth,
                minHeight = height ?: constraints.minHeight,
                maxHeight = height ?: constraints.maxHeight,
            )
            val child = measurables.firstOrNull()?.measure(inner)
            val childSize = child?.let { IntSize(it.width, it.height) } ?: inner.constrain(IntSize.Zero)
            val size = constraints.constrain(childSize)
            layout(size.width, size.height) { child?.place(alignment.align(childSize, size, layoutDirection)) }
        }
    }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

/**
 * Flutter `FittedBox` (`RenderFittedBox`) as the Flutter builder makes it:
 * the child laid out with no constraints, the box its size brought within
 * the parent's keeping its aspect ratio
 * (`constrainSizeAndAttemptToPreserveAspectRatio`, [preservingAspectRatio];
 * for scaleDown within the loosened constraints, then the parent's), and
 * the child drawn scaled by `fit` (Flutter `applyBoxFit`, [imageFit]'s
 * maths; contain by default) about the box's centre. The builder does not
 * read `alignment`, so it is always centred, and Flutter's default
 * `Clip.none` lets a cover or none child overflow the box unclipped. A box
 * or child with no area draws nothing, as Flutter's paint.
 */
@Composable
internal fun FittedBoxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val fit = boxFit(node["fit"])
    val policy = remember(fit) {
        MeasurePolicy { measurables, constraints ->
            val child = measurables.firstOrNull()?.measure(Constraints())
            val width = (child?.width ?: 0).toFloat()
            val height = (child?.height ?: 0).toFloat()
            val size = if (fit == ContentScale.Inside) {
                constraints.constrain(constraints.copy(minWidth = 0, minHeight = 0).fitting(width, height))
            } else {
                constraints.fitting(width, height)
            }
            layout(size.width, size.height) {
                if (child == null || size.width == 0 || size.height == 0 || child.width == 0 || child.height == 0) {
                    return@layout
                }
                val scale = fit.computeScaleFactor(
                    Size(child.width.toFloat(), child.height.toFloat()),
                    Size(size.width.toFloat(), size.height.toFloat()),
                )
                child.placeWithLayer(0, 0) {
                    transformOrigin = TransformOrigin(0f, 0f)
                    scaleX = scale.scaleX
                    scaleY = scale.scaleY
                    translationX = (size.width - child.width * scale.scaleX) / 2
                    translationY = (size.height - child.height * scale.scaleY) / 2
                }
            }
        }
    }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

/**
 * Flutter's `constrainSizeAndAttemptToPreserveAspectRatio`
 * ([preservingAspectRatio]), which constrains a size with no area as it is.
 */
private fun Constraints.fitting(width: Float, height: Float): IntSize =
    if (width == 0f || height == 0f) {
        constrain(IntSize(width.roundToInt(), height.roundToInt()))
    } else {
        preservingAspectRatio(width, height)
    }

/** Flutter `_parseBoxFit`: the seven `BoxFit` names as [imageFit] reads them, anything else contain. */
private fun boxFit(value: JsonValue?): ContentScale =
    if (value?.stringValue in BOX_FITS) imageFit(value) else ContentScale.Fit

private val BOX_FITS = setOf("fill", "contain", "cover", "fitWidth", "fitHeight", "none", "scaleDown")
