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

        fade.observe(116, metrics(10.0, 200.0, 100.0), inProgress = true)
        assertFalse(fade.isSettled(116), "fading in")
        assertEquals(0.7756, fade.opacity(266), 0.01, "half way in: fastOutSlowIn(0.5)")
        assertEquals(1.0, fade.opacity(416), "shown 300 ms after the first move")
        assertEquals(1.0, fade.opacity(5000), "shown for as long as the drag lasts")
        assertTrue(fade.isSettled(5000), "shown and no timer while the drag lasts")
    }

    /**
     * A5.7 (kt core): a scroll under way that does not move the offset, a
     * drag against either edge (Flutter's OverscrollNotification, handled as
     * a ScrollUpdateNotification), shows the thumb and stops the timer as a
     * move does; it fades 600 ms after the scroll ends. Content that cannot
     * scroll still shows none.
     */
    @Test
    fun a5_7_kt_aScrollAgainstAnEdgeShowsTheThumb() {
        for (edge in listOf(0.0, 200.0)) {
            val fade = ScrollbarFade(thumbVisibility = false)
            fade.observe(0, metrics(edge, 200.0, 100.0), inProgress = false)
            fade.observe(100, metrics(edge, 200.0, 100.0), inProgress = true)
            assertEquals(0.7756, fade.opacity(250), 0.01, "at $edge, half way in: fastOutSlowIn(0.5)")
            assertEquals(1.0, fade.opacity(400), "at $edge, shown 300 ms after the scroll began")
            fade.observe(1000, metrics(edge, 200.0, 100.0), inProgress = false)
            fade.observe(1400, metrics(edge, 200.0, 100.0), inProgress = true)
            assertEquals(1.0, fade.opacity(2000), "at $edge, a scroll during the wait stops the timer")
            fade.observe(2000, metrics(edge, 200.0, 100.0), inProgress = false)
            assertEquals(1.0, fade.opacity(2599), "at $edge, kept 600 ms after the scroll ended")
            assertEquals(0.0, fade.opacity(2900), "at $edge, gone 900 ms after it")
        }

        val fits = ScrollbarFade(thumbVisibility = false)
        fits.observe(0, metrics(0.0, 0.0, 100.0), inProgress = false)
        fits.observe(100, metrics(0.0, 0.0, 100.0), inProgress = true)
        assertEquals(0.0, fits.opacity(400), "content that fits: no thumb while a scroll is under way")
        assertTrue(fits.isSettled(400), "content that fits: settled")
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

    /**
     * A5.7 (kt core): turning thumbVisibility off hides the thumb over 300 ms
     * with no wait; turning it on during the wait shows it and stops the
     * timer (Flutter `didUpdateWidget`).
     */
    @Test
    fun a5_7_kt_turningThumbVisibilityOffFadesTheThumb() {
        val fade = ScrollbarFade(thumbVisibility = true)
        fade.observe(0, metrics(0.0, 200.0, 100.0), inProgress = false)
        assertEquals(1.0, fade.opacity(300), "shown")
        fade.setThumbVisibility(1000, false)
        assertEquals(1.0, fade.opacity(1000), "still shown as it is turned off")
        assertEquals(0.7756, fade.opacity(1150), 0.01, "half way out with no wait: fastOutSlowIn(0.5)")
        assertEquals(0.0, fade.opacity(1300), "gone 300 ms later")
        assertTrue(fade.isSettled(1300), "gone and settled")

        val waiting = shownAndEndedAt(2000)
        waiting.setThumbVisibility(2100, true)
        assertEquals(1.0, waiting.opacity(5000), "turned on during the wait: the timer is stopped")
        assertTrue(waiting.isSettled(5000), "shown and no timer")
        waiting.setThumbVisibility(5000, true)
        assertEquals(1.0, waiting.opacity(5300), "the same value changes nothing")
    }

    /**
     * A5.7 (kt core): when the opacity next changes with no new sample: at
     * once while it fades, at the timer's end while it only waits, never
     * once settled.
     */
    @Test
    fun a5_7_kt_theNextChangeIsTheTimersEndDuringTheWait() {
        val fade = shownAndEndedAt(1000)
        assertEquals(1600L, fade.nextChange(1000), "waiting: the fade starts at 1600")
        assertEquals(1600L, fade.nextChange(1599), "still waiting")
        assertEquals(1700L, fade.nextChange(1700), "fading out")
        assertNull(fade.nextChange(1900), "gone and settled")

        val showing = ScrollbarFade(thumbVisibility = false)
        showing.observe(0, metrics(0.0, 200.0, 100.0), inProgress = false)
        showing.observe(100, metrics(80.0, 200.0, 100.0), inProgress = false)
        assertEquals(200L, showing.nextChange(200), "a jump: fading in")
        assertEquals(700L, showing.nextChange(400), "shown, then waiting until 600 ms after the jump")
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
