package com.orcagateway.sdk.widgets

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.LocalOrcaAnimationProgress
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.min

/**
 * Flutter `OrcaAnimatedBuilder` (sdk/lib/src/builders/animated_builder_widget.dart),
 * as Swift's AnimatedBuilderView: a frame clock of `duration` ms shaped by
 * `curve`, running once or, with `repeat`, forever (back and forth with
 * `reverse`). Every frame its descendants are resolved again with the
 * clock's value ([LocalOrcaAnimationProgress]), so their `tween` props move.
 * `autoStart: false` holds it at 0. `onComplete` fires when a one-shot run
 * ends.
 *
 * Not ported yet: `animationId` targeting from actions (Dart's
 * AnimationRegistry); a tween naming an id resolves against the nearest
 * builder like an unnamed one.
 */
@Composable
internal fun AnimatedBuilderWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val durationMs = maxOf(node["duration"]?.doubleValue ?: 300.0, 1.0)
    val repeats = node["repeat"]?.boolValue ?: false
    val reverse = node["reverse"]?.boolValue ?: false
    val autoStart = node["autoStart"]?.boolValue ?: true
    val curve = node["curve"]?.stringValue ?: "linear"

    var raw by remember(node.id) { mutableDoubleStateOf(0.0) }
    LaunchedEffect(node.id, durationMs, repeats, reverse, autoStart) {
        raw = 0.0
        if (!autoStart) return@LaunchedEffect
        val start = withFrameNanos { it }
        while (true) {
            val now = withFrameNanos { it }
            val elapsed = (now - start) / 1_000_000.0
            raw = animationClock(elapsed, durationMs, repeats, reverse, autoStart)
            if (!repeats && elapsed >= durationMs) break
        }
        model.fire("onComplete", node)
    }

    CompositionLocalProvider(LocalOrcaAnimationProgress provides OrcaCurves.apply(curve, raw)) {
        if (node.childIds.size == 1) {
            NodeView(node.childIds[0], model, modifier)
        } else {
            // Several children are stacked, as Dart's `Stack(fit: expand)`.
            Box(modifier) { node.childIds.forEach { NodeView(it, model) } }
        }
    }
}

/**
 * The controller's raw value at [elapsedMs] (Flutter's `forward()` and
 * `repeat(reverse:)`).
 */
internal fun animationClock(
    elapsedMs: Double,
    durationMs: Double,
    repeats: Boolean,
    reverse: Boolean,
    autoStart: Boolean,
): Double {
    if (!autoStart) return 0.0
    val cycles = maxOf(elapsedMs, 0.0) / durationMs
    if (!repeats) return min(cycles, 1.0)
    val phase = cycles % 1.0
    if (!reverse) return phase
    return if (cycles.toLong() % 2 == 0L) phase else 1 - phase
}

/** Flutter's named curves (the `Curve` the engine sends), as Swift's OrcaCurve. */
internal object OrcaCurves {
    private val curves = mapOf(
        "easeIn" to CubicBezierEasing(0.42f, 0f, 1f, 1f),
        "easeOut" to CubicBezierEasing(0f, 0f, 0.58f, 1f),
        "easeInOut" to CubicBezierEasing(0.42f, 0f, 0.58f, 1f),
        "ease" to CubicBezierEasing(0.25f, 0.1f, 0.25f, 1f),
        "fastOutSlowIn" to CubicBezierEasing(0.4f, 0f, 0.2f, 1f),
        "easeInCubic" to CubicBezierEasing(0.55f, 0.055f, 0.675f, 0.19f),
        "easeOutCubic" to CubicBezierEasing(0.215f, 0.61f, 0.355f, 1f),
        "easeInOutCubic" to CubicBezierEasing(0.645f, 0.045f, 0.355f, 1f),
    )

    fun apply(name: String, t: Double): Double {
        if (t <= 0) return 0.0
        if (t >= 1) return 1.0
        if (name == "decelerate") return 1 - (1 - t) * (1 - t)
        val easing = curves[name] ?: return t
        return easing.transform(t.toFloat()).toDouble()
    }
}

/**
 * Flutter `Transform` (layout_builders.dart `_buildTransform`): `transform`
 * is `{type: translate, dx, dy}`, `{type: rotate, angle}` (radians) or
 * `{type: scale, scaleX, scaleY}`, about `alignment` (default center). It
 * is drawn in the graphics layer, so it moves the pixels and not the
 * layout, as Flutter's.
 *
 * As in Swift, a translated child is measured unbounded along the moved
 * axis (keyed on `dx` / `dy` being sent, so a tween through 0 does not
 * change the layout) while the Transform keeps the size it is offered, so
 * text can slide inside a clipping parent (a ticker): Flutter's OverflowBox.
 */
@Composable
internal fun TransformWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val t = node["transform"]
    val child = node.childIds.firstOrNull()
    val origin = Props.unitPoint(node["alignment"]).let { TransformOrigin(it.x, it.y) }
    val layer = when (t?.get("type")?.stringValue) {
        "translate" -> {
            val dx = t["dx"].doubleValue ?: 0.0
            val dy = t["dy"].doubleValue ?: 0.0
            modifier
                .overflowAxes(horizontal = !t["dx"].isNull, vertical = !t["dy"].isNull)
                .graphicsLayer {
                    translationX = (dx * density).toFloat()
                    translationY = (dy * density).toFloat()
                }
        }
        "rotate" -> {
            val degrees = Math.toDegrees(t["angle"].doubleValue ?: 0.0).toFloat()
            modifier.graphicsLayer {
                rotationZ = degrees
                transformOrigin = origin
            }
        }
        "scale" -> {
            val base = t["scale"].doubleValue ?: 1.0
            val sx = (t["scaleX"].doubleValue ?: base).toFloat()
            val sy = (t["scaleY"].doubleValue ?: base).toFloat()
            modifier.graphicsLayer {
                scaleX = sx
                scaleY = sy
                transformOrigin = origin
            }
        }
        else -> modifier
    }
    if (child != null) NodeView(child, model, layer) else Box(layer)
}

/**
 * Measures the content without a maximum on the chosen axes, takes no more
 * than the offered size itself and pins the content top left: what
 * overflows is drawn outside the bounds (Flutter's OverflowBox).
 */
private fun Modifier.overflowAxes(horizontal: Boolean, vertical: Boolean): Modifier = layout { measurable, constraints ->
    val loose = Constraints(
        minWidth = if (horizontal) 0 else constraints.minWidth,
        maxWidth = if (horizontal) Constraints.Infinity else constraints.maxWidth,
        minHeight = if (vertical) 0 else constraints.minHeight,
        maxHeight = if (vertical) Constraints.Infinity else constraints.maxHeight,
    )
    val placeable = measurable.measure(loose)
    val width = if (horizontal) constraints.constrainWidth(placeable.width) else placeable.width
    val height = if (vertical) constraints.constrainHeight(placeable.height) else placeable.height
    layout(width, height) { placeable.placeRelative(0, 0) }
}
