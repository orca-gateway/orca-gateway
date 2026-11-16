package com.orcagateway.sdk.widgets

import android.provider.Settings
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import com.orcagateway.core.animation.AnimationController
import com.orcagateway.core.animation.AnimationDuration
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.LocalOrcaAnimationProgress
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props

/**
 * Whether animations jump to their end state (D14): null (the default)
 * follows the system setting ([rememberSystemReduceMotion]); a test provides
 * true or false. Internal, as Swift's twin: a host has no switch of its own.
 * Every animated widget reads it through [orcaReduceMotion].
 */
internal val LocalOrcaReduceMotion: ProvidableCompositionLocal<Boolean?> = compositionLocalOf { null }

/**
 * The system's "remove animations" setting: the animator duration scale is
 * 0. Compose's own duration scale does not reach a `withFrameNanos` loop,
 * so the widgets ask here. Read once per composition.
 */
@Composable
internal fun rememberSystemReduceMotion(): Boolean {
    val resolver = LocalContext.current.contentResolver
    return remember(resolver) { Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f }
}

/** [LocalOrcaReduceMotion], or the system setting when nothing provides it. */
@Composable
internal fun orcaReduceMotion(): Boolean = LocalOrcaReduceMotion.current ?: rememberSystemReduceMotion()

/**
 * Flutter `OrcaAnimatedBuilder` (sdk/lib/src/builders/animated_builder_widget.dart),
 * as Swift's AnimatedBuilderView: a core [AnimationController] of `duration`
 * ms (300) shaped by `curve` (the core's [com.orcagateway.core.animation.Curves];
 * missing or unknown is easeInOut), stepped by the page's frame clock. With
 * `autoStart` (true) it runs once or, with `repeat`, forever (back and forth
 * with `reverse`); without, it rests at 0 until an action forwards it. Every
 * frame of a run its descendants are resolved again with the curved value
 * ([LocalOrcaAnimationProgress]), so their `tween` props move.
 *
 * With an `animationId` it is registered in the page's
 * [OrcaPageModel.animations] while composed, so `animateForward` and
 * `animateReverse` reach it; the last builder to register an id owns it and
 * a builder leaving removes only its own entry. `onComplete` fires each
 * time a run reaches 1 or reaches 0, never for a cycle of a repeat. It
 * takes frames only while a run is live. Reduced motion ([orcaReduceMotion]):
 * a run ends the moment it starts.
 *
 * `duration`, `curve`, `repeat`, `reverse`, `autoStart` and reduced motion
 * are read when the builder is first composed: a later update of them does
 * not rebuild the controller, which keeps its value (Flutter builds it in
 * `initState`); they apply to a builder that is composed anew.
 */
@Composable
internal fun AnimatedBuilderWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val durationMs = AnimationDuration.milliseconds(node["duration"])
    val repeats = node["repeat"]?.boolValue ?: false
    val reverses = node["reverse"]?.boolValue ?: false
    val autoStart = node["autoStart"]?.boolValue ?: true
    val curve = node["curve"]?.stringValue
    val animationId = node["animationId"]?.stringValue
    val reduceMotion = orcaReduceMotion()

    // Built once, as Flutter's in `initState` and Swift's on appear: it lives as
    // long as the builder is composed, so an update of the props or reduced
    // motion toggling keeps its value and does not replay it.
    val controller = remember(node.id) { AnimationController(durationMs, curve, repeats, reverses, reduceMotion) }
    val startsOnAppear = remember(node.id) { autoStart }
    var progress by remember(controller) { mutableDoubleStateOf(0.0) }
    val current by rememberUpdatedState(node)

    // Registered before the clock starts, so an action of the first frame finds it.
    val owner = remember(node.id) { Any() }
    DisposableEffect(model, owner, animationId, controller) {
        if (animationId != null) model.animations.register(animationId, owner, controller)
        onDispose { if (animationId != null) model.animations.unregister(animationId, owner) }
    }

    LaunchedEffect(model, controller) {
        // One frame: the value to draw in it, then an `onComplete` per run that ended by it.
        suspend fun frame(starting: Boolean = false) {
            val ended = model.withAnimationFrame { now ->
                if (starting) controller.start(now)
                progress = controller.progress(now)
                var runs = 0
                while (controller.takeCompletion(now)) runs += 1
                runs
            }
            repeat(ended) { model.fire("onComplete", current) }
        }
        if (startsOnAppear) frame(starting = true)
        while (true) {
            val seen = model.animationRequestCount
            if (!controller.isRunning(model.animationFrameMs) && !model.hasPendingAnimation) {
                model.awaitAnimationRequest(seen)
            }
            frame()
        }
    }

    CompositionLocalProvider(LocalOrcaAnimationProgress provides progress) {
        if (node.childIds.size == 1) {
            NodeView(node.childIds[0], model, modifier)
        } else {
            // Several children are stacked, as Dart's `Stack(fit: expand)`.
            Box(modifier) { node.childIds.forEach { NodeView(it, model) } }
        }
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
