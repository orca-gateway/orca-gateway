package com.orcagateway.sdk.widgets

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** AnimatedBuilder's clock (Flutter `forward` / `repeat(reverse:)`) and curves, as Swift's MotionTests. */
class MotionTest {
    @Test
    fun oneShotClampsAtTheEnd() {
        assertEquals(0.5, animationClock(500.0, 1000.0, repeats = false, reverse = false, autoStart = true))
        assertEquals(1.0, animationClock(3000.0, 1000.0, repeats = false, reverse = false, autoStart = true))
    }

    @Test
    fun repeatWrapsAndReverseBouncesBack() {
        assertEquals(0.25, animationClock(1250.0, 1000.0, repeats = true, reverse = false, autoStart = true), 1e-9)
        assertEquals(0.75, animationClock(1250.0, 1000.0, repeats = true, reverse = true, autoStart = true), 1e-9)
    }

    @Test
    fun noAutoStartHoldsAtZero() {
        assertEquals(0.0, animationClock(5000.0, 1000.0, repeats = true, reverse = false, autoStart = false))
    }

    @Test
    fun curvesKeepTheirEndsAndShape() {
        for (name in listOf("linear", "easeIn", "easeOut", "easeInOut", "fastOutSlowIn")) {
            assertEquals(0.0, OrcaCurves.apply(name, 0.0))
            assertEquals(1.0, OrcaCurves.apply(name, 1.0))
        }
        assertTrue(OrcaCurves.apply("easeIn", 0.5) < 0.5)
        assertTrue(OrcaCurves.apply("easeOut", 0.5) > 0.5)
        assertEquals(0.5, OrcaCurves.apply("easeInOut", 0.5), 1e-3)
    }
}
