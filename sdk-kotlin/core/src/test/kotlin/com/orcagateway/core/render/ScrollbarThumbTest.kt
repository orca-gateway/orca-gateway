package com.orcagateway.core.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A5.7, the core half of Scrollbar on Android: Flutter's Material thumb as
 * the builder makes it (layout_builders.dart:603-611, both props null) on
 * Android (material_ui scrollbar.dart: thickness 8 / 2, minimum length 48,
 * no margins; it fades after 600 ms over 300 ms), drawn by
 * `ScrollbarPainter` (widgets/scrollbar.dart:422-460 `_setThumbExtent`,
 * :697-706 `_getScrollToTrack`, :546-549 `_needPaint`) and faded by
 * `RawScrollbarState` (:1477-1482 the fastOutSlowIn fade, :1675-1682 the
 * timer, :1981-2042 the notifications). Lengths are logical pixels (dp),
 * times milliseconds.
 */
class ScrollbarThumbTest {
    private fun metrics(offset: Double, maxExtent: Double, viewport: Double) =
        ScrollMetrics(offset = offset, maxExtent = maxExtent, viewportDimension = viewport)

    private fun assertSpan(offset: Double, extent: Double, actual: ThumbSpan?, label: String) {
        val span = requireNotNull(actual) { "$label: no thumb" }
        assertEquals(offset, span.offset, 1e-9, "$label offset")
        assertEquals(extent, span.extent, 1e-9, "$label extent")
    }

    /** A5.7 (kt core): Material's Android defaults, a 4 dp thumb at least 48 long, 600 ms before a 300 ms fade. */
    @Test
    fun a5_7_kt_materialAndroidDefaults() {
        assertEquals(4.0, ScrollbarThumb.THICKNESS)
        assertEquals(48.0, ScrollbarThumb.MIN_LENGTH)
        assertEquals(600L, ScrollbarThumb.TIME_TO_FADE)
        assertEquals(300L, ScrollbarThumb.FADE_DURATION)
    }

    /**
     * A5.7 (kt core): the thumb is the visible fraction of the track (the
     * viewport): 400 of 800 is half of it, and it travels the rest as the
     * offset goes from 0 to maxExtent.
     */
    @Test
    fun a5_7_kt_theThumbIsTheVisibleFractionAndFollowsTheOffset() {
        assertSpan(0.0, 200.0, ScrollbarThumb.span(metrics(0.0, 400.0, 400.0)), "at the start")
        assertSpan(100.0, 200.0, ScrollbarThumb.span(metrics(200.0, 400.0, 400.0)), "half way")
        assertSpan(200.0, 200.0, ScrollbarThumb.span(metrics(400.0, 400.0, 400.0)), "at the end")
    }

    /** A5.7 (kt core): a long content's thumb is no shorter than 48: 100 of 300 would be 33.3. */
    @Test
    fun a5_7_kt_theThumbIsAtLeastTheMinimumLength() {
        assertSpan(0.0, 48.0, ScrollbarThumb.span(metrics(0.0, 200.0, 100.0)), "at the start")
        assertSpan(52.0, 48.0, ScrollbarThumb.span(metrics(200.0, 200.0, 100.0)), "at the end")
    }

    /** A5.7 (kt core): a track shorter than 48 is all thumb, which then cannot move. */
    @Test
    fun a5_7_kt_aShortTrackIsAllThumb() {
        assertSpan(0.0, 30.0, ScrollbarThumb.span(metrics(500.0, 1000.0, 30.0)), "short track")
    }

    /** A5.7 (kt core): reversed (offset 0 at the far end), the thumb starts at the far end of the track. */
    @Test
    fun a5_7_kt_reversedTheThumbStartsAtTheFarEnd() {
        assertSpan(200.0, 200.0, ScrollbarThumb.span(metrics(0.0, 400.0, 400.0), reverse = true), "at the start")
        assertSpan(0.0, 200.0, ScrollbarThumb.span(metrics(400.0, 400.0, 400.0), reverse = true), "at the end")
    }

    /** A5.7 (kt core): content that does not scroll, or no viewport, has no thumb. */
    @Test
    fun a5_7_kt_noThumbWhenNothingScrolls() {
        assertNull(ScrollbarThumb.span(metrics(0.0, 0.0, 400.0)), "content that fits")
        assertNull(ScrollbarThumb.span(metrics(0.0, 1e-11, 400.0)), "within precisionErrorTolerance")
        assertNull(ScrollbarThumb.span(metrics(0.0, 400.0, 0.0)), "no viewport")
        assertNull(ScrollbarThumb.span(metrics(0.0, Double.POSITIVE_INFINITY, 400.0)), "infinite content")
    }

    /**
     * A5.7 (kt core): at rest the thumb is hidden; the first move shows it
     * over 300 ms on Flutter's fastOutSlowIn curve, while the drag goes on.
     */
    @Test
    fun a5_7_kt_aScrollShowsTheThumb() {
        val fade = ScrollbarFade(thumbVisibility = false)
        fade.observe(0, metrics(0.0, 200.0, 100.0), inProgress = false)
        assertEquals(0.0, fade.opacity(0), "at rest")
        assertTrue(fade.isSettled(0), "at rest it is settled")

        fade.observe(100, metrics(0.0, 200.0, 100.0), inProgress = true)
        assertEquals(0.0, fade.opacity(100), "a touch alone shows nothing")
        fade.observe(116, metrics(10.0, 200.0, 100.0), inProgress = true)
        assertFalse(fade.isSettled(116), "fading in")
        assertEquals(0.7756, fade.opacity(266), 0.01, "half way in: fastOutSlowIn(0.5)")
        assertEquals(1.0, fade.opacity(416), "shown 300 ms after the first move")
        assertEquals(1.0, fade.opacity(5000), "shown for as long as the drag lasts")
        assertTrue(fade.isSettled(5000), "shown and no timer while the drag lasts")
    }

    /** A5.7 (kt core): once the scroll ends the thumb stays 600 ms, then fades over 300 ms. */
    @Test
    fun a5_7_kt_theThumbFadesAfterTheScrollEnds() {
        val fade = shownAndEndedAt(1000)
        assertFalse(fade.isSettled(1000), "the fade timer runs")
        assertEquals(1.0, fade.opacity(1599), "still shown before 600 ms")
        assertEquals(1.0, fade.opacity(1600), "the fade starts at 600 ms")
        assertEquals(0.7756, fade.opacity(1750), 0.01, "half way out: fastOutSlowIn(0.5)")
        assertEquals(0.0, fade.opacity(1900), "gone 300 ms later")
        assertTrue(fade.isSettled(1900), "gone and settled")
    }

    /** A5.7 (kt core): a scroll during the wait keeps the thumb and starts the wait again from its end. */
    @Test
    fun a5_7_kt_aScrollDuringTheWaitKeepsTheThumb() {
        val fade = shownAndEndedAt(1000)
        fade.observe(1400, metrics(60.0, 200.0, 100.0), inProgress = true)
        assertEquals(1.0, fade.opacity(2000), "the first timer is cancelled")
        fade.observe(2000, metrics(60.0, 200.0, 100.0), inProgress = false)
        assertEquals(1.0, fade.opacity(2599), "still shown before 600 ms from the new end")
        assertEquals(0.0, fade.opacity(2900), "gone 900 ms after the new end")
    }

    /** A5.7 (kt core): a jump (an offset change with no scroll in progress) shows the thumb, which then fades. */
    @Test
    fun a5_7_kt_aJumpShowsTheThumbThenFades() {
        val fade = ScrollbarFade(thumbVisibility = false)
        fade.observe(0, metrics(0.0, 200.0, 100.0), inProgress = false)
        fade.observe(100, metrics(80.0, 200.0, 100.0), inProgress = false)
        assertEquals(1.0, fade.opacity(400), "shown 300 ms after the jump")
        assertEquals(1.0, fade.opacity(699), "kept until 600 ms after it")
        assertEquals(0.0, fade.opacity(1000), "gone 900 ms after it")
    }

    /** A5.7 (kt core): with thumbVisibility the thumb shows without a scroll and never fades. */
    @Test
    fun a5_7_kt_thumbVisibilityKeepsTheThumb() {
        val fade = ScrollbarFade(thumbVisibility = true)
        fade.observe(0, metrics(0.0, 200.0, 100.0), inProgress = false)
        assertEquals(1.0, fade.opacity(300), "shown 300 ms after the first layout")
        fade.observe(400, metrics(0.0, 200.0, 100.0), inProgress = true)
        fade.observe(416, metrics(50.0, 200.0, 100.0), inProgress = true)
        fade.observe(500, metrics(50.0, 200.0, 100.0), inProgress = false)
        assertEquals(1.0, fade.opacity(10_000), "still shown long after the scroll ended")
        assertTrue(fade.isSettled(500), "no fade timer")
    }

    /** A5.7 (kt core): content that stops scrolling hides a shown thumb over 300 ms, with no wait. */
    @Test
    fun a5_7_kt_contentThatStopsScrollingHidesTheThumb() {
        val fade = ScrollbarFade(thumbVisibility = false)
        fade.observe(0, metrics(0.0, 200.0, 100.0), inProgress = true)
        fade.observe(16, metrics(20.0, 200.0, 100.0), inProgress = true)
        assertEquals(1.0, fade.opacity(400), "shown")
        fade.observe(400, metrics(0.0, 0.0, 100.0), inProgress = false)
        assertEquals(0.0, fade.opacity(700), "gone 300 ms later")
    }

    /** A thumb shown by a drag from 0 to 50 that ended at [end] (shown since 316). */
    private fun shownAndEndedAt(end: Long): ScrollbarFade {
        val fade = ScrollbarFade(thumbVisibility = false)
        fade.observe(0, metrics(0.0, 200.0, 100.0), inProgress = false)
        fade.observe(16, metrics(0.0, 200.0, 100.0), inProgress = true)
        fade.observe(32, metrics(50.0, 200.0, 100.0), inProgress = true)
        fade.observe(end, metrics(50.0, 200.0, 100.0), inProgress = false)
        assertEquals(1.0, fade.opacity(end), "shown when the scroll ends")
        return fade
    }
}
