package com.orcagateway.core.render

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** A point in an InteractiveViewer's own coordinates (the viewport's, where gestures land) or in its child's (the scene's). */
public data class ViewerPoint(public val x: Double, public val y: Double)

/** A width and a height: an InteractiveViewer's viewport or its child. */
public data class ViewerSize(public val width: Double, public val height: Double)

/**
 * What an InteractiveViewer draws its child through: Flutter's
 * TransformationController value as InteractiveViewer moves it with
 * rotation off, a uniform [scale] about the child's top-left corner and
 * then a translation ([x], [y]), so scene point p is drawn at
 * scale·p + (x, y).
 */
public data class ViewerTransform(public val scale: Double, public val x: Double, public val y: Double) {
    /** Flutter `TransformationController.toScene`: the scene point drawn at [point]. */
    public fun toScene(point: ViewerPoint): ViewerPoint = ViewerPoint((point.x - x) / scale, (point.y - y) / scale)

    public companion object {
        /** At rest: nothing scaled or moved. */
        public val identity: ViewerTransform = ViewerTransform(scale = 1.0, x = 0.0, y = 0.0)
    }
}

/**
 * What bounds an InteractiveViewer's transform: its [viewport] (its own
 * box) and its [child]'s size, and the Flutter builder's props with its
 * defaults (layout_builders.dart:636-644). The framework's boundaryMargin
 * is zero, so the bound is the child's rect (`_boundaryRect`,
 * interactive_viewer.dart:515-526), and its panAxis free.
 */
public data class ViewerLimits(
    public val viewport: ViewerSize,
    public val child: ViewerSize,
    public val minScale: Double = 0.8,
    public val maxScale: Double = 2.5,
    public val panEnabled: Boolean = true,
    public val scaleEnabled: Boolean = true,
) {
    /**
     * Flutter `_matrixScale` (:646-660): [transform] scaled by [change]
     * about the top-left corner, the total first raised to the scale at
     * which the child covers the viewport, then clamped to minScale ..
     * maxScale (`clampDouble`, so the clamp wins). A change of 1 changes
     * nothing.
     */
    internal fun scaled(transform: ViewerTransform, change: Double): ViewerTransform {
        if (change == 1.0) return transform
        val total = max(transform.scale * change, max(viewport.width / child.width, viewport.height / child.height))
        val clamped = if (total < minScale) minScale else if (total > maxScale) maxScale else total
        return transform.copy(scale = clamped)
    }

    /**
     * Flutter `_matrixTranslate` (:547-640): [transform] moved by
     * [translation] in scene units. When the viewport, mapped into the
     * scene, would leave the child's rect, the move goes to the nearest
     * place inside instead; when no place fits, it does not move; when only
     * one axis fits, only that axis keeps its translation (the other is 0,
     * as Flutter sets it).
     */
    internal fun translated(transform: ViewerTransform, translation: ViewerPoint): ViewerTransform {
        if (translation.x == 0.0 && translation.y == 0.0) return transform
        val scale = transform.scale
        val next = transform.copy(x = transform.x + scale * translation.x, y = transform.y + scale * translation.y)
        val offending = exceeds(next)
        if (offending.x == 0.0 && offending.y == 0.0) return next
        val corrected = next.copy(x = next.x - offending.x * scale, y = next.y - offending.y * scale)
        val still = exceeds(corrected)
        if (still.x == 0.0 && still.y == 0.0) return corrected
        if (still.x != 0.0 && still.y != 0.0) return transform
        return corrected.copy(x = if (still.x == 0.0) corrected.x else 0.0, y = if (still.y == 0.0) corrected.y else 0.0)
    }

    /**
     * Flutter `_exceedsBy` (:1252-1272) with the child's rect as the
     * boundary: on each axis, the largest of the viewport's four corners'
     * distances (in the scene, through [transform]) to the nearest point
     * inside the rect, rounded to 9 places (`_round`); zero inside.
     */
    private fun exceeds(transform: ViewerTransform): ViewerPoint {
        val corners = listOf(0.0 to 0.0, viewport.width to 0.0, viewport.width to viewport.height, 0.0 to viewport.height)
            .map { (x, y) -> transform.toScene(ViewerPoint(x, y)) }
        var largestX = 0.0
        var largestY = 0.0
        for (corner in corners) {
            val x = min(max(corner.x, 0.0), child.width) - corner.x
            val y = min(max(corner.y, 0.0), child.height) - corner.y
            if (abs(x) > abs(largestX)) largestX = x
            if (abs(y) > abs(largestY)) largestY = y
        }
        return ViewerPoint(round(largestX), round(largestY))
    }

    internal companion object {
        /** Flutter `_round`: to 9 decimal places. */
        fun round(value: Double): Double = Math.rint(value * 1e9) / 1e9
    }
}

/**
 * One gesture on an InteractiveViewer, Flutter's scale gesture (one
 * recogniser pans and pinches, interactive_viewer.dart :700-805): [start]
 * where it begins, then each [update] with its scale since the start and
 * its focal point (in the viewer's coordinates) gives the next transform.
 * Fling inertia at the end (`_onScaleEnd`) is not ported.
 */
public class ViewerGesture {
    /** Flutter `_GestureType` with rotation off. */
    public enum class Kind { Pan, Scale }

    /** Decided at the first update, and again while it is a pan. */
    public var kind: Kind? = null
        private set

    /** The scale when the gesture began. */
    public var scaleStart: Double = 1.0
        private set

    /** The scene point that should stay under the focal point. */
    public var reference: ViewerPoint = ViewerPoint(0.0, 0.0)
        private set

    /** Flutter `_onScaleStart`. */
    public fun start(focal: ViewerPoint, transform: ViewerTransform) {
        kind = null
        scaleStart = transform.scale
        reference = transform.toScene(focal)
    }

    /**
     * Flutter `_onScaleUpdate`: a scale (any scale but 1, while
     * scaleEnabled) zooms by [scale] since the start and then moves so the
     * reference is back under [focal] (bounded, the reference following
     * when the bound stops it); a pan (scale 1) moves by the focal point's
     * travel in the scene. A kind its flag turns off changes nothing, as
     * does a pan whose scale is not 1.
     */
    public fun update(scale: Double, focal: ViewerPoint, transform: ViewerTransform, limits: ViewerLimits): ViewerTransform {
        if (kind == null || kind == Kind.Pan) {
            kind = if (abs((if (limits.scaleEnabled) scale else 1.0) - 1) > 0) Kind.Scale else Kind.Pan
        }
        return if (kind == Kind.Scale) {
            if (!limits.scaleEnabled) return transform
            val scaled = limits.scaled(transform, scaleStart * scale / transform.scale)
            val next = limits.translated(scaled, scaled.toScene(focal) - reference)
            val check = next.toScene(focal)
            if (ViewerLimits.round(check.x) != ViewerLimits.round(reference.x) ||
                ViewerLimits.round(check.y) != ViewerLimits.round(reference.y)
            ) {
                reference = check
            }
            next
        } else {
            if (!limits.panEnabled || scale != 1.0) return transform
            val next = limits.translated(transform, transform.toScene(focal) - reference)
            reference = next.toScene(focal)
            next
        }
    }

    private operator fun ViewerPoint.minus(other: ViewerPoint): ViewerPoint = ViewerPoint(x - other.x, y - other.y)
}
