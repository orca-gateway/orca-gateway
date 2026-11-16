package com.orcagateway.core.render

import com.orcagateway.core.json.JsonValue
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * B13.3-K: a drop on a ReorderableListView as Flutter reports it
 * (layout_builders.dart:707-712): `newIndex` is the raw value, the insertion
 * index before the dragged item is removed, and a drop that leaves the item
 * where it was reports nothing. The table is the one the Swift twin pins
 * (ReorderDropTests.swift).
 */
class ReorderDropTest {
    /** Three rows 40 long, one after the other. */
    private val rows = listOf(ItemSpan(0, 0.0, 40.0), ItemSpan(1, 40.0, 40.0), ItemSpan(2, 80.0, 40.0))

    /** B13.3-K: the shared table, slot to raw newIndex. */
    @Test
    fun b13_3_newIndexIsTheRawInsertionIndex() {
        assertEquals(2, ReorderDrop.newIndex(from = 0, slot = 2, count = 3))
        assertEquals(3, ReorderDrop.newIndex(from = 0, slot = 3, count = 3))
        assertEquals(0, ReorderDrop.newIndex(from = 2, slot = 0, count = 3))
        assertEquals(1, ReorderDrop.newIndex(from = 2, slot = 1, count = 3))
        assertEquals(3, ReorderDrop.newIndex(from = 1, slot = 3, count = 3))
    }

    /** B13.3-K: the slot before the item and the one after it are where it already is. */
    @Test
    fun b13_3_aDropWhereTheItemWasMovesNothing() {
        assertNull(ReorderDrop.newIndex(from = 1, slot = 1, count = 3))
        assertNull(ReorderDrop.newIndex(from = 1, slot = 2, count = 3))
        assertNull(ReorderDrop.newIndex(from = 0, slot = 0, count = 3))
        assertNull(ReorderDrop.newIndex(from = 2, slot = 3, count = 3))
    }

    /** B13.3-K: an index or a slot outside the list moves nothing. */
    @Test
    fun b13_3_outOfRangeMovesNothing() {
        assertNull(ReorderDrop.newIndex(from = -1, slot = 2, count = 3))
        assertNull(ReorderDrop.newIndex(from = 3, slot = 0, count = 3))
        assertNull(ReorderDrop.newIndex(from = 0, slot = -1, count = 3))
        assertNull(ReorderDrop.newIndex(from = 0, slot = 4, count = 3))
    }

    /** B13.3-K: a list of none or one has nowhere to move to. */
    @Test
    fun b13_3_aListOfNoneOrOneMovesNothing() {
        assertNull(ReorderDrop.newIndex(from = 0, slot = 0, count = 0))
        assertNull(ReorderDrop.newIndex(from = 0, slot = 1, count = 1))
        assertNull(ReorderDrop.newIndex(from = 0, slot = 2, count = 1))
    }

    /** B13.3-K: the payload `V.event` reads is {oldIndex, newIndex}, whole numbers. */
    @Test
    fun b13_3_theEventIsOldIndexAndNewIndex() {
        assertEquals(
            mapOf("oldIndex" to JsonValue.Int(0), "newIndex" to JsonValue.Int(3)),
            ReorderDrop.event(from = 0, slot = 3, count = 3),
        )
        assertEquals(
            mapOf("oldIndex" to JsonValue.Int(2), "newIndex" to JsonValue.Int(0)),
            ReorderDrop.event(from = 2, slot = 0, count = 3),
        )
        assertNull(ReorderDrop.event(from = 1, slot = 2, count = 3))
        assertNull(ReorderDrop.event(from = 0, slot = 1, count = 1))
    }

    /** B13.3-K: the slot is how many other rows have their middle before the dragged row's centre. */
    @Test
    fun b13_3_theSlotComesFromTheDraggedCentre() {
        // Row 0 (centre 20) dragged down: past row 1's middle (60), then past row 2's (100).
        assertEquals(0, ReorderDrop.slot(rows, from = 0, centre = 20.0))
        assertEquals(0, ReorderDrop.slot(rows, from = 0, centre = 59.0))
        assertEquals(2, ReorderDrop.slot(rows, from = 0, centre = 61.0))
        assertEquals(3, ReorderDrop.slot(rows, from = 0, centre = 101.0))
        // Row 2 dragged up.
        assertEquals(2, ReorderDrop.slot(rows, from = 2, centre = 100.0))
        assertEquals(1, ReorderDrop.slot(rows, from = 2, centre = 59.0))
        assertEquals(0, ReorderDrop.slot(rows, from = 2, centre = 19.0))
        // Row 1 either way.
        assertEquals(1, ReorderDrop.slot(rows, from = 1, centre = 60.0))
        assertEquals(0, ReorderDrop.slot(rows, from = 1, centre = 19.0))
        assertEquals(3, ReorderDrop.slot(rows, from = 1, centre = 101.0))
    }

    /** B13.3-K: slot and newIndex together give the pinned moves. */
    @Test
    fun b13_3_aDragBelowRow1Gives0To2AndLastToTopGives2To0() {
        val below = ReorderDrop.slot(rows, from = 0, centre = 80.0)
        assertEquals(2, ReorderDrop.newIndex(0, below, 3))
        val top = ReorderDrop.slot(rows, from = 2, centre = 0.0)
        assertEquals(0, ReorderDrop.newIndex(2, top, 3))
        val tiny = ReorderDrop.slot(rows, from = 1, centre = 70.0)
        assertNull(ReorderDrop.newIndex(1, tiny, 3))
    }

    /** B13.3-K: a lazy list knows only the rows on screen; the rows scrolled away before them count as before. */
    @Test
    fun b13_3_theSlotCountsTheRowsScrolledAway() {
        // Rows 2, 3, 4 of five on screen, the list scrolled by 100.
        val seen = listOf(ItemSpan(2, -20.0, 40.0), ItemSpan(3, 20.0, 40.0), ItemSpan(4, 60.0, 40.0))
        assertEquals(3, ReorderDrop.slot(seen, from = 3, centre = 40.0))
        assertEquals(5, ReorderDrop.slot(seen, from = 3, centre = 90.0))
        // Row 0 was dragged from the top and is no longer among them.
        assertEquals(5, ReorderDrop.slot(seen, from = 0, centre = 100.0))
        assertEquals(4, ReorderDrop.slot(seen, from = 0, centre = 50.0))
        // Its own span, when the list still reports it, is not counted.
        assertEquals(5, ReorderDrop.slot(seen + ItemSpan(0, -100.0, 40.0), from = 0, centre = 100.0))
        // With no other row known the item stays.
        assertEquals(1, ReorderDrop.slot(emptyList(), from = 1, centre = 500.0))
    }

    /** B13.3-K: during the drag the rows between the item and its slot make room, one item's length. */
    @Test
    fun b13_3_theRowsBetweenMakeRoom() {
        // Row 0 over slot 3: rows 1 and 2 move toward the start.
        assertEquals(listOf(0, -1, -1), (0..2).map { ReorderDrop.displacement(it, from = 0, slot = 3) })
        // Row 2 over slot 0: rows 0 and 1 move toward the end.
        assertEquals(listOf(1, 1, 0), (0..2).map { ReorderDrop.displacement(it, from = 2, slot = 0) })
        // Row 1 over slot 0, then where it was, then no drag at all.
        assertEquals(listOf(1, 0, 0), (0..2).map { ReorderDrop.displacement(it, from = 1, slot = 0) })
        assertEquals(listOf(0, 0, 0), (0..2).map { ReorderDrop.displacement(it, from = 1, slot = 2) })
        assertEquals(listOf(0, 0, 0), (0..2).map { ReorderDrop.displacement(it, from = -1, slot = -1) })
    }

    /** B13.3-K: a dragged row sticking out of the view scrolls it that way, a step at most. */
    @Test
    fun b13_3_aRowDraggedPastAnEdgeScrollsTheList() {
        assertEquals(0.0, ReorderDrop.autoScroll(start = 30.0, size = 40.0, viewportStart = 0.0, viewportEnd = 100.0, step = 12.0))
        assertEquals(5.0, ReorderDrop.autoScroll(start = 65.0, size = 40.0, viewportStart = 0.0, viewportEnd = 100.0, step = 12.0))
        assertEquals(12.0, ReorderDrop.autoScroll(start = 90.0, size = 40.0, viewportStart = 0.0, viewportEnd = 100.0, step = 12.0))
        assertEquals(-12.0, ReorderDrop.autoScroll(start = -30.0, size = 40.0, viewportStart = 0.0, viewportEnd = 100.0, step = 12.0))
        assertEquals(-4.0, ReorderDrop.autoScroll(start = -12.0, size = 40.0, viewportStart = -8.0, viewportEnd = 92.0, step = 12.0))
    }

    /** B13.3-K: the scroll triggers of a lazy list read their payload off the rows on screen. */
    @Test
    fun b13_3_scrollMetricsOfAListComeFromTheRowsOnScreen() {
        // Five rows of 40 in a view of 100: at the top, in the middle, at the end.
        val top = listOf(ItemSpan(0, 0.0, 40.0), ItemSpan(1, 40.0, 40.0), ItemSpan(2, 80.0, 40.0))
        assertEquals(
            ScrollMetrics(offset = 0.0, maxExtent = 100.0, viewportDimension = 100.0),
            ScrollMetrics.ofItems(top, count = 5, viewportStart = 0.0, viewportEnd = 100.0),
        )
        val middle = listOf(ItemSpan(1, -10.0, 40.0), ItemSpan(2, 30.0, 40.0), ItemSpan(3, 70.0, 40.0))
        assertEquals(
            ScrollMetrics(offset = 50.0, maxExtent = 100.0, viewportDimension = 100.0),
            ScrollMetrics.ofItems(middle, count = 5, viewportStart = 0.0, viewportEnd = 100.0),
        )
        val end = listOf(ItemSpan(2, -20.0, 40.0), ItemSpan(3, 20.0, 40.0), ItemSpan(4, 60.0, 40.0))
        val atEnd = ScrollMetrics.ofItems(end, count = 5, viewportStart = 0.0, viewportEnd = 100.0)
        assertEquals(ScrollMetrics(offset = 100.0, maxExtent = 100.0, viewportDimension = 100.0), atEnd)
        assertEquals(JsonValue.Bool(true), atEnd.eventData["atEnd"])
    }

    /** B13.3-K: padding is part of what scrolls; rows that fit do not scroll; no row, no extent. */
    @Test
    fun b13_3_scrollMetricsWithPaddingAndShortLists() {
        // Padding 8 before and after: the view starts 8 before row 0, and 216 of content scroll by 116.
        val padded = listOf(ItemSpan(0, 0.0, 40.0), ItemSpan(1, 40.0, 40.0), ItemSpan(2, 80.0, 40.0))
        assertEquals(
            ScrollMetrics(offset = 0.0, maxExtent = 116.0, viewportDimension = 100.0),
            ScrollMetrics.ofItems(padded, count = 5, viewportStart = -8.0, viewportEnd = 92.0, paddingAfter = 8.0),
        )
        val short = listOf(ItemSpan(0, 0.0, 40.0), ItemSpan(1, 40.0, 40.0))
        val fits = ScrollMetrics.ofItems(short, count = 2, viewportStart = 0.0, viewportEnd = 100.0)
        assertEquals(ScrollMetrics(offset = 0.0, maxExtent = 0.0, viewportDimension = 100.0), fits)
        assertEquals(JsonValue.Bool(true), fits.eventData["atStart"])
        assertEquals(JsonValue.Bool(true), fits.eventData["atEnd"])
        assertEquals(
            ScrollMetrics(offset = 0.0, maxExtent = 0.0, viewportDimension = 100.0),
            ScrollMetrics.ofItems(emptyList(), count = 0, viewportStart = 0.0, viewportEnd = 100.0),
        )
    }
}
