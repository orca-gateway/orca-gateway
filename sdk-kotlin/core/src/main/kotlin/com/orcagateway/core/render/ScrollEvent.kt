package com.orcagateway.core.render

import com.orcagateway.core.json.JsonValue

/**
 * Where a scroll view stands, Flutter's `ScrollMetrics`, in logical pixels:
 * Flutter's logical pixel is Android's dp, so an Android view divides its
 * ScrollState pixels by the density first. A SingleChildScrollView's
 * [minExtent] is 0.
 */
public data class ScrollMetrics(
    public val offset: Double,
    public val maxExtent: Double,
    public val viewportDimension: Double,
    public val minExtent: Double = 0.0,
) {
    /**
     * The payload `V.event` reads, Flutter `_scrollEventData`
     * (builder_helpers.dart:32-41): at an edge, at the start when at or
     * before [minExtent], at the end when at or past [maxExtent] (content
     * that fits is at both).
     */
    public val eventData: Map<String, JsonValue>
        get() {
            val atEdge = offset == minExtent || offset == maxExtent
            return mapOf(
                "offset" to JsonValue.Double(offset),
                "maxExtent" to JsonValue.Double(maxExtent),
                "minExtent" to JsonValue.Double(minExtent),
                "viewportDimension" to JsonValue.Double(viewportDimension),
                "atStart" to JsonValue.Bool(atEdge && offset <= minExtent),
                "atEnd" to JsonValue.Bool(atEdge && offset >= maxExtent),
            )
        }

    public companion object {
        /**
         * The metrics of a lazy list, which knows only the items in view:
         * [items] in order, where they lie, in a view from [viewportStart]
         * to [viewportEnd] (both in the items' origin: with padding before
         * the first item the view starts before 0), over [count] items and
         * [paddingAfter] past the last one. Items out of view are taken to
         * be as long as the ones in view on average, so the numbers are
         * exact for items of one length and at both ends of any list.
         */
        public fun ofItems(
            items: List<ItemSpan>,
            count: Int,
            viewportStart: Double,
            viewportEnd: Double,
            paddingAfter: Double = 0.0,
        ): ScrollMetrics {
            val viewport = viewportEnd - viewportStart
            val first = items.firstOrNull() ?: return ScrollMetrics(0.0, 0.0, viewport)
            val last = items.last()
            val average = items.sumOf { it.size } / items.size
            val offset = (first.index * average - first.start).coerceAtLeast(0.0)
            val unseen = (count - 1 - last.index).coerceAtLeast(0) * average
            val remaining = (unseen + last.start + last.size + paddingAfter - viewportEnd).coerceAtLeast(0.0)
            return ScrollMetrics(offset, offset + remaining, viewport)
        }
    }
}

/** A scroll trigger to fire on the view's node, with its payload. */
public data class ScrollEvent(public val trigger: String, public val eventData: Map<String, JsonValue>) {
    public companion object {
        /** The triggers a scroll view fires; a view whose node sets none is not watched. */
        public val TRIGGERS: Set<String> = setOf("onScrollBegin", "onScrolling", "onScrollEnd")
    }
}

/**
 * Turns samples of one scroll view into its triggers, Flutter
 * `wrapScrollNotifier` (builder_helpers.dart:46-71), no throttling:
 *
 * - onScrollBegin when a scroll starts (a drag, an animation), with the
 *   metrics from before it moved, as Flutter's ScrollStartNotification.
 * - onScrolling for each sample whose offset changed, with `delta`, the
 *   change since the sample before (negative toward the start).
 * - onScrollEnd when the scroll is no longer in progress, where it settled.
 * - An offset that changes with no scroll in progress is a jump: begin,
 *   scrolling and end at once, all at the new offset, as Flutter's `jumpTo`.
 * - A new extent or viewport alone runs nothing (Flutter's
 *   ScrollMetricsNotification is not a scroll notification).
 */
public class ScrollObserver {
    private var last: ScrollMetrics? = null
    private var scrolling = false

    /** The triggers sample [metrics] runs, in order; [inProgress] is whether a scroll is under way. */
    public fun observe(metrics: ScrollMetrics, inProgress: Boolean): List<ScrollEvent> {
        val previous = last
        last = metrics
        val events = ArrayList<ScrollEvent>(3)
        val moved = previous != null && metrics.offset != previous.offset
        if (!scrolling && (inProgress || moved)) {
            scrolling = true
            val start = if (inProgress) previous ?: metrics else metrics
            events += ScrollEvent("onScrollBegin", start.eventData)
        }
        if (moved) {
            val delta = metrics.offset - previous.offset
            events += ScrollEvent("onScrolling", metrics.eventData + ("delta" to JsonValue.Double(delta)))
        }
        if (scrolling && !inProgress) {
            scrolling = false
            events += ScrollEvent("onScrollEnd", metrics.eventData)
        }
        return events
    }
}
