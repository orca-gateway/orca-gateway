package com.orcagateway.sdk.widgets

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculateCentroidSize
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEvent
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.ViewerGesture
import com.orcagateway.core.render.ViewerLimits
import com.orcagateway.core.render.ViewerPoint
import com.orcagateway.core.render.ViewerSize
import com.orcagateway.core.render.ViewerTransform
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Flutter `InteractiveViewer` (`_buildInteractiveViewer`: `minScale` 0.8,
 * `maxScale` 2.5, `panEnabled` and `scaleEnabled` true; the framework's
 * boundaryMargin zero, constrained true, clipBehavior hardEdge, no
 * alignment). Its build (interactive_viewer.dart:1052-1140) is all
 * proxies, so the child is laid out with the viewer's constraints and the
 * viewer is its size. The child is drawn, and hit, through the core's
 * [ViewerTransform] (the scale about its top-left corner, then the
 * translation) and cut to the viewer's box, which takes touches all over
 * (Flutter's opaque GestureDetector) while the child's own taps still
 * work. Pinches and drags are fed to the core's [ViewerGesture] by a
 * [ViewerFeed], which takes a move only while it can change the transform,
 * so at rest a one-finger drag goes on to a scroll view around the viewer.
 * Zoomed in it takes a drag in any direction, as Swift's does, which is
 * not Flutter's: there a vertical scroll view around the viewer wins a
 * vertical drag (its slop, kTouchSlop, is half the scale recogniser's,
 * kPanSlop). The transform is kept through a saved state, as a scroll
 * view keeps its offset; a prop change takes effect within a gesture.
 * Fling inertia (`_onScaleEnd`) is not ported. Under [LocalPointerBlocked]
 * it takes no touches.
 */
@Composable
internal fun InteractiveViewerWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val minScale = Props.number(node["minScale"]) ?: 0.8
    val maxScale = Props.number(node["maxScale"]) ?: 2.5
    val panEnabled = Props.bool(node["panEnabled"]) ?: true
    val scaleEnabled = Props.bool(node["scaleEnabled"]) ?: true
    var transform by rememberSaveable(stateSaver = ViewerTransformSaver) { mutableStateOf(ViewerTransform.identity) }
    // The loop never restarts; new props reach it through this state.
    val limits = rememberUpdatedState { box: ViewerSize ->
        // The child is laid out with the viewer's constraints and the viewer takes its size.
        ViewerLimits(box, box, minScale, maxScale, panEnabled, scaleEnabled)
    }
    val touch = if (LocalPointerBlocked.current) {
        Modifier
    } else {
        Modifier.pointerInput(Unit) {
            feedViewer(read = { transform }, write = { transform = it }, limits = { limits.value(it) })
        }
    }
    Box(modifier.clipToBounds().then(touch), propagateMinConstraints = true) {
        ChildView(
            node, model,
            Modifier.graphicsLayer {
                transformOrigin = TransformOrigin(0f, 0f)
                scaleX = transform.scale.toFloat()
                scaleY = transform.scale.toFloat()
                translationX = transform.x.toFloat()
                translationY = transform.y.toFloat()
            },
        )
    }
}

/** The transform as (scale, x, y), for a saved state. */
private val ViewerTransformSaver = listSaver<ViewerTransform, Double>(
    save = { listOf(it.scale, it.x, it.y) },
    restore = { ViewerTransform(scale = it[0], x = it[1], y = it[2]) },
)

/**
 * The viewer's pointer loop: each event fed to a [ViewerFeed], in pixels
 * as the box's size; a move the feed takes is consumed and its transform
 * kept. Something inside consuming a change of a finger already down (a
 * scroll view's drag, a detector's tap) ends the gesture; a new finger's
 * down taken by an idle GestureDetector inside does not, as Flutter's
 * scale recogniser wins over the tap there.
 */
private suspend fun PointerInputScope.feedViewer(
    read: () -> ViewerTransform,
    write: (ViewerTransform) -> Unit,
    limits: (ViewerSize) -> ViewerLimits,
) {
    awaitEachGesture {
        awaitFirstDown(requireUnconsumed = false)
        val feed = ViewerFeed(viewConfiguration.touchSlop.toDouble(), currentEvent.changes.count { it.pressed })
        do {
            val event = awaitPointerEvent()
            if (event.changes.any { it.isConsumed && it.previousPressed }) break
            if (size.width == 0 || size.height == 0) continue
            val next = feed.step(event.viewerPointers(), read(), limits(ViewerSize(size.width.toDouble(), size.height.toDouble())))
            if (next != null) {
                event.changes.forEach { if (it.positionChanged()) it.consume() }
                write(next)
            }
        } while (event.changes.any { it.pressed })
    }
}

/**
 * One pointer event as [ViewerFeed] reads it: how many fingers are down,
 * the centroid of those down before and after it and how far they were
 * spread before it, and the zoom it made (Compose's `calculateCentroid`,
 * `calculateCentroidSize` and `calculateZoom`, which count the fingers
 * down both before and after; no centroid when there are none).
 */
internal data class ViewerPointers(
    val count: Int,
    val previous: ViewerPoint?,
    val current: ViewerPoint?,
    val spread: Double,
    val zoom: Double,
)

private fun PointerEvent.viewerPointers(): ViewerPointers {
    fun Offset.point(): ViewerPoint? = if (this == Offset.Unspecified) null else ViewerPoint(x.toDouble(), y.toDouble())
    return ViewerPointers(
        count = changes.count { it.pressed },
        previous = calculateCentroid(useCurrent = false).point(),
        current = calculateCentroid(useCurrent = true).point(),
        spread = calculateCentroidSize(useCurrent = false).toDouble(),
        zoom = calculateZoom().toDouble(),
    )
}

/**
 * Compose's pointer events fed to Flutter's one scale gesture
 * ([ViewerGesture]) for one touch, from the first finger down. Nothing
 * starts until the fingers pass [touchSlop], by their zoom or their
 * centroid's travel (as `detectTransformGestures` measures them). The
 * gesture then starts at the crossing event's previous centroid and takes
 * that event's own zoom and travel, as `detectTransformGestures` reports
 * them; what moved before it is not applied. (Flutter's recogniser starts
 * at the crossing event's current focal point, with a first update of
 * scale 1.) A finger landing or lifting starts the gesture anew from where
 * the fingers then are (ScaleGestureRecognizer `_reconfigure`). Each [step]
 * gives the next transform when the move is taken: a pinch, or a drag
 * that can pan (zoomed in, pan on); otherwise null, and the move goes on to
 * whatever is around the viewer.
 */
internal class ViewerFeed(private val touchSlop: Double, pointers: Int) {
    private var count = pointers
    private var gesture: ViewerGesture? = null
    private var restart = true
    private var zoom = 1.0
    private var slopZoom = 1.0
    private var slopX = 0.0
    private var slopY = 0.0

    fun step(pointers: ViewerPointers, transform: ViewerTransform, limits: ViewerLimits): ViewerTransform? {
        val previous = pointers.previous
        val current = pointers.current
        if (pointers.count != count || previous == null || current == null) {
            count = pointers.count
            restart = true
            return null
        }
        val gesture = this.gesture ?: run {
            slopZoom *= pointers.zoom
            slopX += current.x - previous.x
            slopY += current.y - previous.y
            if (abs(1 - slopZoom) * pointers.spread <= touchSlop && hypot(slopX, slopY) <= touchSlop) return null
            ViewerGesture().also { this.gesture = it }
        }
        if (restart) {
            gesture.start(previous, transform)
            zoom = 1.0
            restart = false
        }
        zoom *= pointers.zoom
        val next = gesture.update(zoom, current, transform, limits)
        return if (takes(gesture.kind, transform, limits)) next else null
    }

    /**
     * Whether an update of [kind] can move [transform]: a pinch always (its
     * kind is a pan when scaleEnabled is false); a drag only zoomed in with
     * pan on, as at 1 and below Flutter's bound leaves no room.
     */
    private fun takes(kind: ViewerGesture.Kind?, transform: ViewerTransform, limits: ViewerLimits): Boolean = when (kind) {
        ViewerGesture.Kind.Scale -> true
        ViewerGesture.Kind.Pan -> limits.panEnabled && transform.scale > 1
        null -> false
    }
}
