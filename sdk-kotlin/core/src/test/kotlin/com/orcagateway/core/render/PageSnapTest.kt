package com.orcagateway.core.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * A5.4, the core half of PageView: where a snapping PageView settles when
 * the finger lets go, Flutter's `PageScrollPhysics._getTargetPixels`
 * (widgets/page_view.dart:603-611) as its builder makes it
 * (layout_builders.dart:668-684: no controller, so page = offset / viewport
 * extent). A release velocity reaches the physics only when the drag
 * recogniser judges it a fling (`isFlingGesture`, gestures/monodrag.dart,
 * both `>`): its speed past the minimum fling velocity, on Android
 * ClampingScrollPhysics' kMinFlingVelocity = 50 dp a second
 * (gestures/constants.dart:90), and the finger's travel along the axis in
 * the velocity window (the last 100 ms, velocity_tracker.dart) past the
 * minimum fling distance, kTouchSlop = 18 dp (constants.dart:65); else the
 * velocity is 0. A fling adds half a page in its direction, then the
 * page is rounded half away from zero (Dart's `roundToDouble`), and kept
 * within the pages. Offsets and velocities count toward later pages,
 * whichever way the axis is drawn. A 200 dp viewport over five pages
 * and 100 dp of travel unless said. The same cases as Swift's PageSnapTests, with Android's
 * minimum where they test the threshold.
 */
class PageSnapTest {
    private fun target(
        offset: Double,
        velocity: Double = 0.0,
        travel: Double = 100.0,
        extent: Double = 200.0,
        count: Int = 5,
        snapping: Boolean = true,
        minFling: Double = PageSnap.MIN_FLING_VELOCITY,
        minDistance: Double = PageSnap.MIN_FLING_DISTANCE,
    ): Int? = PageSnap.target(
        offset = offset, viewportExtent = extent, velocity = velocity, travel = travel, pageCount = count,
        pageSnapping = snapping, minFlingVelocity = minFling, minFlingDistance = minDistance,
    )

    /** A5.4: let go at rest on a page, the view stays on it. */
    @Test
    fun a5_4_atRestOnAPageItStaysThere() {
        assertEquals(0, target(0.0))
        assertEquals(2, target(400.0))
        assertEquals(3, target(375.0 * 3, extent = 375.0))
    }

    /**
     * A5.4: a slow release settles on the nearest page; exactly half way
     * rounds away from zero, to the later page (Dart's `roundToDouble`).
     */
    @Test
    fun a5_4_aSlowReleaseSettlesOnTheNearestPage() {
        assertEquals(1, target(290.0))
        assertEquals(2, target(310.0))
        assertEquals(2, target(300.0))
        assertEquals(3, target(375.0 * 2.6, extent = 375.0))
        assertEquals(1, target(290.0, 50.0))
        assertEquals(2, target(310.0, -50.0))
    }

    /**
     * A5.4: a fling past the minimum velocity goes half a page further in
     * its direction, then rounds: from page 1.05 a forward fling settles on
     * 2 and a backward one on 1; from 1.75 a backward fling settles on 1.
     */
    @Test
    fun a5_4_aFlingGoesHalfAPageFurtherInItsDirectionThenRounds() {
        assertEquals(2, target(210.0, 101.0))
        assertEquals(1, target(210.0, -101.0))
        assertEquals(1, target(290.0, -101.0))
        assertEquals(2, target(290.0, 101.0))
        assertEquals(1, target(350.0, -101.0))
    }

    /**
     * A5.4: however fast, a fling moves at most one page from where the
     * finger let go: from 1.95 forward it settles on 2, backward on 1;
     * from 0.05 forward on 1.
     */
    @Test
    fun a5_4_atMostOnePagePerFlingFromWhereTheFingerLetGo() {
        assertEquals(2, target(390.0, 8000.0))
        assertEquals(1, target(390.0, -8000.0))
        assertEquals(1, target(10.0, 8000.0))
    }

    /**
     * A5.4: the velocity must pass the minimum, not reach it: 50 dp a
     * second on Android is no fling, 50.5 is; a higher minimum (iOS's 100)
     * keeps 60 from flinging.
     */
    @Test
    fun a5_4_theVelocityMustPassTheMinimumFlingVelocity() {
        assertEquals(50.0, PageSnap.MIN_FLING_VELOCITY)
        assertEquals(1, target(210.0, 50.0))
        assertEquals(1, target(210.0, -50.0))
        assertEquals(2, target(210.0, 50.5))
        assertEquals(2, target(210.0, 60.0))
        assertEquals(1, target(210.0, 60.0, minFling = 100.0))
    }

    /**
     * A5.4: a fling must also travel past the minimum distance (kTouchSlop,
     * 18 dp) in its last 100 ms, not reach it: 100 dp a second with 10 dp
     * of travel settles on the nearest page, 300 with 30 turns it; 18 is
     * no fling, 18.5 is; a backward travel counts by its length; a smaller
     * minimum lets 10 dp fling.
     */
    @Test
    fun a5_4_aFlingMustAlsoTravelPastTheMinimumFlingDistance() {
        assertEquals(18.0, PageSnap.MIN_FLING_DISTANCE)
        assertEquals(1, target(210.0, 100.0, travel = 10.0))
        assertEquals(2, target(210.0, 300.0, travel = 30.0))
        assertEquals(1, target(210.0, 300.0, travel = 18.0))
        assertEquals(2, target(210.0, 300.0, travel = 18.5))
        assertEquals(1, target(310.0, -300.0, travel = -30.0))
        assertEquals(2, target(310.0, -300.0, travel = -10.0))
        assertEquals(2, target(210.0, 100.0, travel = 10.0, minDistance = 5.0))
    }

    /**
     * A5.4: the target stays within the pages: a fling back from the first
     * page or on from the last stays there, and a drag let go past either
     * end comes back to it.
     */
    @Test
    fun a5_4_theTargetIsKeptWithinThePages() {
        assertEquals(0, target(0.0, -1000.0))
        assertEquals(4, target(800.0, 1000.0))
        assertEquals(0, target(-30.0))
        assertEquals(0, target(-30.0, 1000.0))
        assertEquals(4, target(830.0))
        assertEquals(0, target(0.0, 1000.0, count = 1))
    }

    /**
     * A5.4: nothing to settle on with pageSnapping false (the view scrolls
     * freely), with no pages or before the viewport has an extent.
     */
    @Test
    fun a5_4_noTargetWhenSnappingIsOffOrThereIsNothingToSnapTo() {
        assertNull(target(210.0, 101.0, snapping = false))
        assertNull(target(0.0, count = 0))
        assertNull(target(210.0, 101.0, extent = 0.0))
    }
}
