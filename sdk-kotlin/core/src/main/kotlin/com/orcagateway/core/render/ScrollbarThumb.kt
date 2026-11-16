package com.orcagateway.core.render

import kotlin.math.abs
import kotlin.math.min

/**
 * The thumb along its track, which is the scroll view's viewport on its
 * main axis: [offset] from the track's leading edge and [extent] long, in
 * logical pixels (dp).
 */
public data class ThumbSpan(public val offset: Double, public val extent: Double)

/**
 * Flutter's Scrollbar on Android as the builder makes it (layout_builders
 * .dart:603-611): material_ui's thumb (scrollbar.dart:12-18, 336, 379-386:
 * 8 / 2 thick, at least 48 long, no margins, square) drawn by
 * `ScrollbarPainter` (widgets/scrollbar.dart). iOS draws its system
 * indicator instead and has no port of this.
 */
public object ScrollbarThumb {
    /** `_kScrollbarThickness / 2`, the Android thumb's thickness when the node sets none. */
    public const val THICKNESS: Double = 4.0

    /** `_kScrollbarMinLength`, the shortest thumb while the view is not overscrolled. */
    public const val MIN_LENGTH: Double = 48.0

    /** `_kScrollbarTimeToFade`: how long the thumb stays once a scroll ends, in ms. */
    public const val TIME_TO_FADE: Long = 600L

    /** `_kScrollbarFadeDuration`: how long it takes to show or hide, in ms. */
    public const val FADE_DURATION: Long = 300L

    /** Flutter's `precisionErrorTolerance`: a view that scrolls no further than this has no thumb (`_needPaint`). */
    private const val PRECISION_ERROR_TOLERANCE: Double = 1e-10

    /**
     * `ScrollbarPainter.paint` (:645-664, `_needPaint` :546-549) with no
     * padding or margin: no thumb when the view does not scroll, has no
     * viewport or no end; else `_setThumbExtent` (:422-460), the visible
     * fraction of the track
     * but no shorter than [MIN_LENGTH] (or the track), and
     * `_getScrollToTrack` (:697-706), the offset's fraction of the rest,
     * from the far end when [reverse] (offset 0 at the far end). Compose
     * keeps offsets within the ends, so Flutter's overscroll shrink
     * (`fractionOverscrolled`) never applies.
     */
    public fun span(metrics: ScrollMetrics, reverse: Boolean = false): ThumbSpan? {
        val scrollable = metrics.maxExtent - metrics.minExtent
        val track = metrics.viewportDimension
        if (scrollable <= PRECISION_ERROR_TOLERANCE || track <= 0.0 || scrollable.isInfinite()) return null
        val visible = (track / (scrollable + track)).coerceIn(0.0, 1.0)
        val extent = (track * visible).coerceIn(min(MIN_LENGTH, track), track)
        val past = ((metrics.offset - metrics.minExtent) / scrollable).coerceIn(0.0, 1.0)
        return ThumbSpan(offset = (if (reverse) 1 - past else past) * (track - extent), extent = extent)
    }
}

/**
 * When the thumb shows, Flutter `RawScrollbarState`'s fade controller with
 * Material's Android timing, fed samples of the scroll view and asked for
 * the opacity at a time in ms (a frame's):
 *
 * - each sample while a scroll is under way, and each move, shows it over
 *   [ScrollbarThumb.FADE_DURATION] and cancels the timer: Flutter handles
 *   ScrollUpdateNotification and OverscrollNotification alike (:2027-2037),
 *   and a scroll under way (past the touch slop) sends one or the other,
 *   so a drag against an edge shows it too; the end of a scroll starts the
 *   timer, which hides it over the same time
 *   [ScrollbarThumb.TIME_TO_FADE] later (:2038-2041, :1675-1682);
 * - with [thumbVisibility] every sample shows it and no timer runs
 *   (:1981-1988, :1676); turning it on shows it and stops the timer,
 *   turning it off hides it with no wait ([setThumbVisibility]);
 * - content that does not scroll hides it with no wait (:2014-2024).
 *
 * The opacity is the controller's value on `Curves.fastOutSlowIn`
 * (:1479-1482). Scrolls are told apart as [ScrollObserver] does for the
 * scroll triggers.
 */
public class ScrollbarFade(private var thumbVisibility: Boolean) {
    private val observer = ScrollObserver()

    /** The controller's value at [since]; it then moves toward 1 ([direction] 1) or 0 (-1), linearly. */
    private var value = 0.0
    private var since = 0L
    private var direction = -1

    /** When the fade timer runs out, if it runs. */
    private var fadeAt: Long? = null

    /** A sample of the scroll view at [now]; [inProgress] is whether a scroll is under way. */
    public fun observe(now: Long, metrics: ScrollMetrics, inProgress: Boolean) {
        runTimer(now)
        val events = observer.observe(metrics, inProgress).map { it.trigger }
        when {
            thumbVisibility -> animate(now, 1)
            metrics.maxExtent <= metrics.minExtent -> animate(now, -1)
            else -> {
                if (inProgress || "onScrolling" in events) {
                    animate(now, 1)
                    fadeAt = null
                }
                if ("onScrollEnd" in events) fadeAt = now + ScrollbarThumb.TIME_TO_FADE
            }
        }
    }

    /**
     * The node's thumbVisibility from [now] on, Flutter `didUpdateWidget`
     * (:1657-1667): turned on, the thumb shows and the timer stops; turned
     * off, it hides over [ScrollbarThumb.FADE_DURATION] with no wait. The
     * same value changes nothing.
     */
    public fun setThumbVisibility(now: Long, thumbVisibility: Boolean) {
        runTimer(now)
        if (thumbVisibility == this.thumbVisibility) return
        this.thumbVisibility = thumbVisibility
        if (thumbVisibility) fadeAt = null
        animate(now, if (thumbVisibility) 1 else -1)
    }

    /** How opaque the thumb is at [now], 0 (hidden) to 1. */
    public fun opacity(now: Long): Double {
        runTimer(now)
        return fastOutSlowIn(valueAt(now))
    }

    /**
     * When the opacity next changes with no new sample: [now] while a fade
     * is under way, the timer's end while it only waits, null when settled.
     */
    public fun nextChange(now: Long): Long? {
        runTimer(now)
        return if (valueAt(now) != if (direction > 0) 1.0 else 0.0) now else fadeAt
    }

    /** Whether the opacity stays as it is after [now] until the next sample: no fade under way, no timer. */
    public fun isSettled(now: Long): Boolean = nextChange(now) == null

    private fun valueAt(now: Long): Double =
        (value + direction * (now - since).toDouble() / ScrollbarThumb.FADE_DURATION).coerceIn(0.0, 1.0)

    /** Flutter's `forward()` when not forward or completed ([to] 1), `reverse()` when it is (-1). */
    private fun animate(now: Long, to: Int) {
        if (direction == to) return
        value = valueAt(now)
        since = now
        direction = to
    }

    private fun runTimer(now: Long) {
        val at = fadeAt ?: return
        if (now < at) return
        animate(at, -1)
        fadeAt = null
    }

    private companion object {
        /** Flutter `Cubic.transform` (animation/curves.dart) for `Curves.fastOutSlowIn`, Cubic(0.4, 0.0, 0.2, 1.0). */
        fun fastOutSlowIn(t: Double): Double {
            if (t <= 0.0 || t >= 1.0) return t
            var start = 0.0
            var end = 1.0
            while (true) {
                val midpoint = (start + end) / 2
                val estimate = cubic(0.4, 0.2, midpoint)
                if (abs(t - estimate) < 0.001) return cubic(0.0, 1.0, midpoint)
                if (estimate < t) start = midpoint else end = midpoint
            }
        }

        fun cubic(a: Double, b: Double, m: Double): Double =
            3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m
    }
}
