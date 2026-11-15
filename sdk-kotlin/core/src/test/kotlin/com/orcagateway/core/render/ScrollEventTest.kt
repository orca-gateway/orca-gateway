package com.orcagateway.core.render

import com.orcagateway.core.json.JsonValue
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * A2.4: the scroll triggers' payload and order, against Flutter's
 * `_scrollEventData` and `wrapScrollNotifier` (sdk/lib/src/builders/
 * builder_helpers.dart:32-71) and fixture 19_scroll_event_values: a view of
 * 400 over content 1000 long, so maxExtent 600.
 */
class ScrollEventTest {
    private fun at(offset: Double, maxExtent: Double = 600.0) = ScrollMetrics(offset, maxExtent, viewportDimension = 400.0)

    private fun payload(offset: Double, atStart: Boolean, atEnd: Boolean, delta: Double? = null): Map<String, JsonValue> =
        buildMap {
            put("offset", JsonValue.Double(offset))
            put("maxExtent", JsonValue.Double(600.0))
            put("minExtent", JsonValue.Double(0.0))
            put("viewportDimension", JsonValue.Double(400.0))
            put("atStart", JsonValue.Bool(atStart))
            put("atEnd", JsonValue.Bool(atEnd))
            delta?.let { put("delta", JsonValue.Double(it)) }
        }

    private fun ScrollObserver.feed(vararg samples: Pair<Double, Boolean>): List<ScrollEvent> =
        samples.flatMap { (offset, inProgress) -> observe(at(offset), inProgress) }

    /** A2.4 (kt core): at offset 0 the view is at its start, as Flutter's `atEdge && pixels <= min`. */
    @Test
    fun a2_4_kt_payloadAtTheStart() {
        assertEquals(payload(0.0, atStart = true, atEnd = false), at(0.0).eventData)
    }

    /** A2.4 (kt core): between the edges it is at neither. */
    @Test
    fun a2_4_kt_payloadInTheMiddle() {
        assertEquals(payload(250.5, atStart = false, atEnd = false), at(250.5).eventData)
    }

    /** A2.4 (kt core): at maxExtent it is at its end. */
    @Test
    fun a2_4_kt_payloadAtTheEnd() {
        assertEquals(payload(600.0, atStart = false, atEnd = true), at(600.0).eventData)
    }

    /** A2.4 (kt core): content shorter than the view (maxExtent 0) is at both edges, as in Flutter. */
    @Test
    fun a2_4_kt_contentThatFitsIsAtBothEdges() {
        val data = at(0.0, maxExtent = 0.0).eventData
        assertEquals(JsonValue.Bool(true), data["atStart"])
        assertEquals(JsonValue.Bool(true), data["atEnd"])
    }

    /**
     * A2.4 (kt core): a scroll in progress (a drag, an animation) runs
     * onScrollBegin where it starts, onScrolling per offset with the change
     * since the last, and onScrollEnd where it settles.
     */
    @Test
    fun a2_4_kt_aScrollRunsBeginThenScrollingThenEnd() {
        val events = ScrollObserver().feed(0.0 to false, 0.0 to true, 250.5 to true, 600.0 to true, 600.0 to false)
        assertEquals(
            listOf(
                ScrollEvent("onScrollBegin", payload(0.0, atStart = true, atEnd = false)),
                ScrollEvent("onScrolling", payload(250.5, atStart = false, atEnd = false, delta = 250.5)),
                ScrollEvent("onScrolling", payload(600.0, atStart = false, atEnd = true, delta = 349.5)),
                ScrollEvent("onScrollEnd", payload(600.0, atStart = false, atEnd = true)),
            ),
            events,
        )
    }

    /**
     * A2.4 (kt core): onScrollBegin carries where the scroll started even
     * when the first sample in progress has already moved (Flutter's drag
     * start comes before its first update).
     */
    @Test
    fun a2_4_kt_beginCarriesWhereTheScrollStarted() {
        val events = ScrollObserver().feed(0.0 to false, 100.0 to true)
        assertEquals(
            listOf(
                ScrollEvent("onScrollBegin", payload(0.0, atStart = true, atEnd = false)),
                ScrollEvent("onScrolling", payload(100.0, atStart = false, atEnd = false, delta = 100.0)),
            ),
            events,
        )
    }

    /**
     * A2.4 (kt core): an offset that changes with no scroll in progress is a
     * jump, which Flutter's `jumpTo` reports as begin, one update and end,
     * all at the new offset.
     */
    @Test
    fun a2_4_kt_aJumpRunsAllThreeAtTheNewOffset() {
        val events = ScrollObserver().feed(0.0 to false, 600.0 to false)
        assertEquals(
            listOf(
                ScrollEvent("onScrollBegin", payload(600.0, atStart = false, atEnd = true)),
                ScrollEvent("onScrolling", payload(600.0, atStart = false, atEnd = true, delta = 600.0)),
                ScrollEvent("onScrollEnd", payload(600.0, atStart = false, atEnd = true)),
            ),
            events,
        )
    }

    /** A2.4 (kt core): a sample with the same offset runs no onScrolling, and a new extent alone runs nothing. */
    @Test
    fun a2_4_kt_anUnchangedOffsetRunsNothing() {
        val observer = ScrollObserver()
        observer.feed(0.0 to false, 0.0 to true, 50.0 to true)
        assertEquals(emptyList(), observer.feed(50.0 to true))
        assertEquals(emptyList(), ScrollObserver().run { observe(at(0.0), false) + observe(at(0.0, maxExtent = 900.0), false) })
    }

    /** A2.4 (kt core): delta is negative when the offset goes back toward the start. */
    @Test
    fun a2_4_kt_deltaIsNegativeTowardTheStart() {
        val events = ScrollObserver().feed(600.0 to false, 600.0 to true, 450.0 to true)
        assertEquals(JsonValue.Double(-150.0), events.last().eventData["delta"])
        assertEquals("onScrolling", events.last().trigger)
    }

    /** A2.4 (kt core): the triggers a node must set for its scroll view to be watched. */
    @Test
    fun a2_4_kt_theThreeTriggers() {
        assertEquals(setOf("onScrollBegin", "onScrolling", "onScrollEnd"), ScrollEvent.TRIGGERS)
    }
}
