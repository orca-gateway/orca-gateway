package com.orcagateway.core.render

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.sign

/**
 * Where a PageView with `pageSnapping` settles when the finger lets go,
 * Flutter's `PageScrollPhysics` (widgets/page_view.dart:603-611) for the
 * PageView its builder makes (layout_builders.dart:668-684): no controller,
 * so viewportFraction 1 and page = offset / viewport extent. Offsets and
 * velocities count toward later pages along the scroll axis, whichever way
 * the axis is drawn (reverse, right-to-left), as Flutter's scroll offset
 * does; a UI maps its finger to them. The same cases as Swift's PageSnap.
 */
public object PageSnap {
    /**
     * The speed, in dp (Flutter's logical pixels) a second, a release must
     * pass to be a fling: Android's, ClampingScrollPhysics'
     * `minFlingVelocity`, kMinFlingVelocity (gestures/constants.dart:90).
     * iOS's doubles it. A release must also pass [MIN_FLING_DISTANCE];
     * failing either, the drag recogniser hands the physics a velocity of 0
     * (`isFlingGesture`, gestures/monodrag.dart).
     */
    public const val MIN_FLING_VELOCITY: Double = 50.0

    /**
     * The travel, in dp, the finger must pass along the axis within the
     * velocity window (the newest sample minus the oldest within 100 ms,
     * gestures/velocity_tracker.dart) for a release to be a fling: the
     * physics' `minFlingDistance`, kTouchSlop (gestures/constants.dart:65).
     */
    public const val MIN_FLING_DISTANCE: Double = 18.0

    /**
     * The page to settle on from [offset] with the release [velocity]
     * (positive toward later pages) and the finger's [travel] along the
     * axis in its last 100 ms: a fling (speed past [minFlingVelocity] and
     * travel past [minFlingDistance]) adds half a page in its direction,
     * then the page is rounded half away from zero (Dart's `roundToDouble`),
     * so it moves at most one page from where the finger let go; kept within 0 .. [pageCount] - 1 (Flutter's parent physics
     * brings a view let go past an end back to it). Null with
     * [pageSnapping] false (the view scrolls freely), no pages or no extent.
     */
    public fun target(
        offset: Double,
        viewportExtent: Double,
        velocity: Double,
        travel: Double,
        pageCount: Int,
        pageSnapping: Boolean = true,
        minFlingVelocity: Double = MIN_FLING_VELOCITY,
        minFlingDistance: Double = MIN_FLING_DISTANCE,
    ): Int? {
        if (!pageSnapping || pageCount <= 0 || viewportExtent <= 0.0 || !offset.isFinite()) return null
        var page = offset / viewportExtent
        if (abs(velocity) > minFlingVelocity && abs(travel) > minFlingDistance) page += if (velocity > 0) 0.5 else -0.5
        val rounded = sign(page) * floor(abs(page) + 0.5)
        return rounded.toInt().coerceIn(0, pageCount - 1)
    }
}
