package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.toRect
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.IntrinsicMeasurable
import androidx.compose.ui.layout.IntrinsicMeasureScope
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasurePolicy
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.unit.Constraints
import com.orcagateway.core.render.OrcaBlendMode
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.BoxDecorationProps
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.style.boxDecoration
import com.orcagateway.sdk.style.foregroundDecoration

/*
 * Flutter's paint and clip wrappers (layout_builders.dart). Each but
 * RotatedBox is a proxy box as in Flutter: its child laid out with the
 * constraints the box is given, its size the child's (the smallest size
 * without one), and no tap of its own unless said.
 */

/**
 * Flutter `Opacity` (`_buildOpacity`): the child drawn at `opacity` (1 by
 * default, kept within 0 and 1). As Flutter's RenderOpacity, which has no
 * hit test of its own, the child still takes taps at 0.
 */
@Composable
internal fun OpacityWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val opacity = (Props.number(node["opacity"]) ?: 1.0).coerceIn(0.0, 1.0).toFloat()
    Box(modifier.graphicsLayer { alpha = opacity }, propagateMinConstraints = true) {
        ChildView(node, model)
    }
}

/**
 * Flutter `RotatedBox` (`_buildRotatedBox`, RenderRotatedBox): the child
 * turned `quarterTurns` quarter turns clockwise (0 by default, an integer;
 * negative turns as Dart's `% 4`) about the box's centre. On odd turns the
 * child is laid out with the constraints flipped and the box takes its
 * size swapped, so the turn changes the layout, and its intrinsic sizes
 * are swapped too; taps go through the turn.
 */
@Composable
internal fun RotatedBoxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val turns = Math.floorMod(node["quarterTurns"]?.intValue ?: 0L, 4L).toInt()
    val policy = remember(turns) { RotatedBoxMeasurePolicy(turns) }
    Layout(content = { ChildView(node, model) }, modifier = modifier, measurePolicy = policy)
}

/**
 * Flutter's `RenderRotatedBox` layout for [turns] (0 to 3): on odd turns the
 * child measured with the constraints flipped, the size and the intrinsic
 * sizes swapped (`_isVertical`); the child turned about the centre. No
 * child: the smallest size, intrinsics 0.
 */
private class RotatedBoxMeasurePolicy(private val turns: Int) : MeasurePolicy {
    private val odd = turns % 2 == 1

    override fun MeasureScope.measure(measurables: List<Measurable>, constraints: Constraints): MeasureResult {
        val flipped = if (odd) {
            Constraints(constraints.minHeight, constraints.maxHeight, constraints.minWidth, constraints.maxWidth)
        } else {
            constraints
        }
        val child = measurables.firstOrNull()?.measure(flipped)
            ?: return layout(constraints.minWidth, constraints.minHeight) {}
        val width = if (odd) child.height else child.width
        val height = if (odd) child.width else child.height
        return layout(width, height) {
            if (turns == 0) {
                child.place(0, 0)
            } else {
                child.placeWithLayer(0, 0) {
                    rotationZ = 90f * turns
                    translationX = (width - child.width) / 2f
                    translationY = (height - child.height) / 2f
                }
            }
        }
    }

    override fun IntrinsicMeasureScope.minIntrinsicWidth(measurables: List<IntrinsicMeasurable>, height: Int): Int {
        val child = measurables.firstOrNull() ?: return 0
        return if (odd) child.minIntrinsicHeight(height) else child.minIntrinsicWidth(height)
    }

    override fun IntrinsicMeasureScope.maxIntrinsicWidth(measurables: List<IntrinsicMeasurable>, height: Int): Int {
        val child = measurables.firstOrNull() ?: return 0
        return if (odd) child.maxIntrinsicHeight(height) else child.maxIntrinsicWidth(height)
    }

    override fun IntrinsicMeasureScope.minIntrinsicHeight(measurables: List<IntrinsicMeasurable>, width: Int): Int {
        val child = measurables.firstOrNull() ?: return 0
        return if (odd) child.minIntrinsicWidth(width) else child.minIntrinsicHeight(width)
    }

    override fun IntrinsicMeasureScope.maxIntrinsicHeight(measurables: List<IntrinsicMeasurable>, width: Int): Int {
        val child = measurables.firstOrNull() ?: return 0
        return if (odd) child.maxIntrinsicWidth(width) else child.maxIntrinsicHeight(width)
    }
}

/**
 * Flutter `ClipRect` (`_buildClipRect`): the child cut to the box, hard
 * edged. What overflows takes no taps either: Flutter's render boxes are
 * never hit outside their size.
 */
@Composable
internal fun ClipRectWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    Box(modifier.clipToBounds(), propagateMinConstraints = true) {
        ChildView(node, model)
    }
}

/**
 * Flutter `ClipOval` (`_buildClipOval`): the child cut to the ellipse
 * inscribed in the box, anti-aliased. Taps outside the ellipse miss, as
 * RenderClipOval hit tests inside it only. Compose's 48 dp minimum touch
 * target can still give a child smaller than 48 dp a tap just outside its
 * shape when nothing else is hit there, as it does across the SDK.
 */
@Composable
internal fun ClipOvalWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    Box(modifier.clip(OvalShape), propagateMinConstraints = true) {
        ChildView(node, model)
    }
}

/** The ellipse inscribed in a box. */
private val OvalShape = GenericShape { size, _ -> addOval(size.toRect()) }

/**
 * Flutter `DecoratedBox` (`_buildDecoratedBox`): `decoration` read as a
 * Container's ([BoxDecorationProps.of]; absent or not an object, none)
 * drawn at the child's size, behind the child or, with `position:
 * foreground`, over it. Unlike a Container it adds no padding for the
 * border. As RenderDecoratedBox (`hitTestSelf` is BoxDecoration.hitTest) it
 * takes every tap in its box, or in its rounded box with a borderRadius,
 * filled or not, so nothing behind it gets one there; its child still
 * takes its own, outside the corners too.
 */
@Composable
internal fun DecoratedBoxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val decoration = BoxDecorationProps.of(node["decoration"]) ?: BoxDecorationProps()
    val drawn = if (node["position"]?.stringValue == "foreground") {
        modifier.foregroundDecoration(decoration)
    } else {
        modifier.boxDecoration(decoration)
    }
    Box(drawn, propagateMinConstraints = true) {
        if (!LocalPointerBlocked.current) Box(Modifier.matchParentSize().clip(decoration.shape).pointerInput(Unit) {})
        ChildView(node, model)
    }
}

/**
 * Flutter `ColorFiltered` (`_buildColorFiltered`): `ColorFilter.mode(color,
 * blendMode)`, `color` (the source, transparent by default) blended with
 * each pixel the child draws (the destination) by `blendMode` (Flutter's 21
 * names, [OrcaBlendMode.of]; srcATop otherwise), so the defaults leave the
 * child unchanged. The child is drawn into an offscreen layer the box's
 * size and the colour over it with the mode: what the child draws outside
 * its box is cut, where Flutter's filter layer has no bound. Below Android
 * 10 (API 29) Android blends only its PorterDuff modes (srcOver, srcIn,
 * srcATop, dstOver, dstIn, dstATop, screen, overlay, darken, lighten); the
 * others draw the colour over the child (srcOver).
 */
@Composable
internal fun ColorFilteredWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val color = Props.color(node["color"]) ?: Color.Transparent
    val mode = OrcaBlendMode.of(node["blendMode"]?.stringValue).compose
    Box(
        modifier
            .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
            .drawWithContent {
                drawContent()
                drawRect(color, blendMode = mode)
            },
        propagateMinConstraints = true,
    ) {
        ChildView(node, model)
    }
}

/** Compose's mode of the same name: the same formulas as Flutter's (both Skia's). */
private val OrcaBlendMode.compose: BlendMode
    get() = when (this) {
        OrcaBlendMode.SrcOver -> BlendMode.SrcOver
        OrcaBlendMode.SrcIn -> BlendMode.SrcIn
        OrcaBlendMode.SrcATop -> BlendMode.SrcAtop
        OrcaBlendMode.DstOver -> BlendMode.DstOver
        OrcaBlendMode.DstIn -> BlendMode.DstIn
        OrcaBlendMode.DstATop -> BlendMode.DstAtop
        OrcaBlendMode.Multiply -> BlendMode.Multiply
        OrcaBlendMode.Screen -> BlendMode.Screen
        OrcaBlendMode.Overlay -> BlendMode.Overlay
        OrcaBlendMode.Darken -> BlendMode.Darken
        OrcaBlendMode.Lighten -> BlendMode.Lighten
        OrcaBlendMode.ColorDodge -> BlendMode.ColorDodge
        OrcaBlendMode.ColorBurn -> BlendMode.ColorBurn
        OrcaBlendMode.HardLight -> BlendMode.Hardlight
        OrcaBlendMode.SoftLight -> BlendMode.Softlight
        OrcaBlendMode.Difference -> BlendMode.Difference
        OrcaBlendMode.Exclusion -> BlendMode.Exclusion
        OrcaBlendMode.Hue -> BlendMode.Hue
        OrcaBlendMode.Saturation -> BlendMode.Saturation
        OrcaBlendMode.Color -> BlendMode.Color
        OrcaBlendMode.Luminosity -> BlendMode.Luminosity
    }
