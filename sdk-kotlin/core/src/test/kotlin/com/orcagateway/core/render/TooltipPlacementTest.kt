package com.orcagateway.core.render

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * A8.3, the core half of Tooltip on Android: where Material's Tooltip puts
 * its bubble (material_ui tooltip.dart:413-414 verticalOffset 24,
 * preferBelow; :474-496 the position delegate) by the framework's
 * `positionDependentBox` (painting/geometry.dart:42-68, margin 10) around
 * the child's centre (widgets/raw_tooltip.dart:881-884), and its timings
 * (gestures/constants.dart:29, tooltip.dart:416, raw_tooltip.dart:27-31).
 * Lengths are logical pixels (dp) in the overlay's coordinates, times
 * milliseconds.
 */
class TooltipPlacementTest {
    private val overlay = TooltipSize(width = 400.0, height = 800.0)

    private fun assertOrigin(x: Double, y: Double, actual: TooltipOrigin, label: String) {
        assertEquals(x, actual.x, 1e-9, "$label x")
        assertEquals(y, actual.y, 1e-9, "$label y")
    }

    /** A8.3 (kt core): x puts the bubble's centre on the child's: a 100-wide bubble over a child centred at 200 starts at 150. */
    @Test
    fun a8_3_theBubbleIsCentredOnTheChild() {
        val child = TooltipRect(left = 180.0, top = 100.0, width = 40.0, height = 40.0)
        val bubble = TooltipSize(width = 100.0, height = 32.0)
        assertEquals(150.0, TooltipPlacement.origin(child, bubble, overlay).x, 1e-9)
        val wide = TooltipRect(left = 50.0, top = 100.0, width = 200.0, height = 40.0)
        assertEquals(100.0, TooltipPlacement.origin(wide, bubble, overlay).x, 1e-9, "a child wider than the bubble")
        fun x(left: Double, top: Double, width: Double, height: Double, bubbleWidth: Double = 100.0): Double =
            TooltipPlacement.origin(TooltipRect(left, top, width, height), TooltipSize(bubbleWidth, 32.0), overlay).x
        assertEquals(150.0, x(150.0, 100.0, 100.0, 40.0), 1e-9, "Swift's: a child as wide as the bubble")
        assertEquals(150.0, x(190.0, 100.0, 20.0, 20.0), 1e-9, "a child narrower than the bubble")
        assertEquals(150.0, x(50.0, 100.0, 300.0, 40.0), 1e-9, "a 300-wide child")
        assertEquals(50.0, x(60.0, 300.0, 80.0, 40.0), 1e-9, "a child left of the middle: centre 100")
        assertEquals(170.0, x(150.0, 100.0, 100.0, 40.0, bubbleWidth = 60.0), 1e-9, "a 60-wide bubble")
    }

    /** A8.3 (kt core): the bubble's top sits 24 below the child's centre (not its bottom edge). */
    @Test
    fun a8_3_theBubbleSits24BelowTheChildsCentre() {
        val child = TooltipRect(left = 180.0, top = 100.0, width = 40.0, height = 60.0)
        val bubble = TooltipSize(width = 100.0, height = 32.0)
        assertOrigin(150.0, 154.0, TooltipPlacement.origin(child, bubble, overlay), "centre 130")
        fun at(top: Double, height: Double) = TooltipPlacement.origin(TooltipRect(150.0, top, 100.0, height), bubble, overlay)
        assertOrigin(150.0, 144.0, at(100.0, 40.0), "centre 120")
        assertOrigin(150.0, 224.0, at(100.0, 200.0), "a tall child: centre 200")
        assertOrigin(150.0, 34.0, at(0.0, 20.0), "at the top: above cannot fit")
    }

    /**
     * A8.3 (kt core): geometry.dart:51-59. Below fits while its bottom is no
     * lower than the overlay's height less 10; one past and the bubble goes
     * above, its bottom 24 over the child's centre. When neither side fits,
     * preferBelow keeps it below, its top no lower than the height less 10.
     */
    @Test
    fun a8_3_theBubbleGoesAboveWhenBelowDoesNotFit() {
        val bubble = TooltipSize(width = 100.0, height = 32.0)
        val fits = TooltipRect(left = 180.0, top = 714.0, width = 40.0, height = 40.0)
        assertOrigin(150.0, 758.0, TooltipPlacement.origin(fits, bubble, overlay), "centre 734, bottom exactly at 790")
        val past = TooltipRect(left = 180.0, top = 715.0, width = 40.0, height = 40.0)
        assertOrigin(150.0, 679.0, TooltipPlacement.origin(past, bubble, overlay), "centre 735, bottom at 791: above")
        val atBottom = TooltipRect(left = 150.0, top = 760.0, width = 100.0, height = 40.0)
        assertOrigin(150.0, 724.0, TooltipPlacement.origin(atBottom, bubble, overlay), "a child at the bottom")
        val tall = TooltipSize(width = 100.0, height = 780.0)
        val middle = TooltipRect(left = 180.0, top = 380.0, width = 40.0, height = 40.0)
        assertOrigin(150.0, 424.0, TooltipPlacement.origin(middle, tall, overlay), "neither side fits: below")
        val low = TooltipRect(left = 180.0, top = 760.0, width = 40.0, height = 40.0)
        assertOrigin(150.0, 790.0, TooltipPlacement.origin(low, tall, overlay), "neither fits, top kept at 790, not 804")
        val short = TooltipSize(width = 400.0, height = 100.0)
        val shortChild = TooltipRect(left = 150.0, top = 60.0, width = 100.0, height = 20.0)
        assertOrigin(
            150.0,
            90.0,
            TooltipPlacement.origin(shortChild, TooltipSize(width = 100.0, height = 80.0), short),
            "neither fits in a 100-high overlay: below, top held at 100 - 10 (Swift's short row)",
        )
    }

    /**
     * A8.3 (kt core): a child near an edge keeps the bubble 10 from it: left
     * at 10, right at the width less 10; a child centred at 60 puts it
     * exactly at 10, one at 61 at 11 (Swift's inputs).
     */
    @Test
    fun a8_3_theBubbleIsClampedTenFromTheEdges() {
        val bubble = TooltipSize(width = 100.0, height = 32.0)
        val atLeft = TooltipRect(left = 0.0, top = 100.0, width = 20.0, height = 20.0)
        assertOrigin(10.0, 134.0, TooltipPlacement.origin(atLeft, bubble, overlay), "at the left edge")
        val atRight = TooltipRect(left = 380.0, top = 100.0, width = 20.0, height = 20.0)
        assertOrigin(290.0, 134.0, TooltipPlacement.origin(atRight, bubble, overlay), "at the right edge")
        val centre60 = TooltipRect(left = 40.0, top = 100.0, width = 40.0, height = 40.0)
        assertEquals(10.0, TooltipPlacement.origin(centre60, bubble, overlay).x, 1e-9, "centre 60: exactly 10")
        val centre61 = TooltipRect(left = 41.0, top = 100.0, width = 40.0, height = 40.0)
        assertEquals(11.0, TooltipPlacement.origin(centre61, bubble, overlay).x, 1e-9, "centre 61: inside the margin")
    }

    /**
     * A8.3 (kt core): geometry.dart:61-66. A bubble with no room for 10 on
     * each side (the overlay's width less the bubble's at most 20) is centred
     * in the overlay, wherever the child is; with 21 spare it is clamped, not
     * centred. The 420-wide row is the formula's arithmetic only: Flutter
     * never lays a bubble out wider than the overlay (raw_tooltip.dart:993).
     */
    @Test
    fun a8_3_aBubbleWiderThanTheOverlayLessTwentyIsCentredInTheOverlay() {
        val child = TooltipRect(left = 0.0, top = 100.0, width = 20.0, height = 20.0)
        assertEquals(10.0, TooltipPlacement.origin(child, TooltipSize(380.0, 32.0), overlay).x, 1e-9, "exactly 20 spare")
        assertEquals(5.0, TooltipPlacement.origin(child, TooltipSize(390.0, 32.0), overlay).x, 1e-9, "10 spare")
        assertEquals(-10.0, TooltipPlacement.origin(child, TooltipSize(420.0, 32.0), overlay).x, 1e-9, "20 too wide")
        val right = TooltipRect(left = 380.0, top = 100.0, width = 20.0, height = 20.0)
        assertEquals(5.0, TooltipPlacement.origin(right, TooltipSize(390.0, 32.0), overlay).x, 1e-9, "the child at the right")
        assertEquals(11.0, TooltipPlacement.origin(right, TooltipSize(379.0, 32.0), overlay).x, 1e-9, "21 spare: clamped, not centred")
    }

    /**
     * A8.3 (kt core): a 500 ms long press (gestures/constants.dart:29
     * kLongPressTimeout), gone 1500 ms after release (tooltip.dart:416
     * `_defaultShowDuration` as touchDelay, raw_tooltip.dart:762-767), a fade
     * in of 150 ms and out of 75 (raw_tooltip.dart:27-31); 24 and 10 above.
     */
    @Test
    fun a8_3_theTimingsAreFlutters() {
        assertEquals(500L, TooltipPlacement.LONG_PRESS)
        assertEquals(1500L, TooltipPlacement.SHOW_DURATION)
        assertEquals(150L, TooltipPlacement.FADE_IN)
        assertEquals(75L, TooltipPlacement.FADE_OUT)
        assertEquals(24.0, TooltipPlacement.VERTICAL_OFFSET)
        assertEquals(10.0, TooltipPlacement.MARGIN)
    }
}
