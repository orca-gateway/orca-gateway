package com.orcagateway.core.render

import kotlin.math.PI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A7.3, the core half of CircularProgressIndicator and
 * LinearProgressIndicator as Flutter's builders paint them
 * (sdk/lib/src/builders/primitive_builders.dart: Circular :302-323 and its
 * painter :465-513, Linear :364-384 and its painter :435-463), not
 * Material's: nothing animates. A Circular is 36 square, its stroke
 * `strokeWidth ?? 3` (not above 0 → 3), its rect the box inset by half the
 * stroke; without a value (or NaN) one arc from -0.5 rad sweeping 4.5 rad,
 * else the value clamped to 0..1, a full track in the colour at alpha 0x33
 * and an arc from 12 o'clock of 2π·v, none at 0. A Linear is `minHeight ??
 * 4` high with a radius of half that; without a value the bare track, else
 * a bar of the width times the clamped value from the left. The same cases
 * and numbers as Swift's ProgressGeometryTests.
 */
class ProgressGeometryTest {
    private val eps = 1e-12

    // Circular

    /** A7.3: the stroke is strokeWidth, 3 when unset, 0, negative or NaN. */
    @Test
    fun a7_3_circularStrokeDefaultsTo3AndNonPositiveIs3() {
        assertEquals(3.0, ProgressGeometry.circularStroke(null))
        assertEquals(6.0, ProgressGeometry.circularStroke(6.0))
        assertEquals(0.5, ProgressGeometry.circularStroke(0.5))
        assertEquals(3.0, ProgressGeometry.circularStroke(0.0))
        assertEquals(3.0, ProgressGeometry.circularStroke(-2.0))
        assertEquals(3.0, ProgressGeometry.circularStroke(Double.NaN))
    }

    /**
     * A7.3: the box is 36 x 36; the arc's rect is it inset by half the
     * stroke, never narrower than 0, a forced non-square box an ellipse.
     */
    @Test
    fun a7_3_theCircularIs36SquareAndInsetByHalfTheStroke() {
        assertEquals(36.0, ProgressGeometry.CIRCULAR_SIZE)
        assertEquals(ProgressRect(1.5, 1.5, 33.0, 33.0), ProgressGeometry.circularRect(36.0, 36.0, 3.0))
        assertEquals(ProgressRect(5.0, 5.0, 40.0, 26.0), ProgressGeometry.circularRect(50.0, 36.0, 10.0))
        assertEquals(ProgressRect(20.0, 20.0, 0.0, 0.0), ProgressGeometry.circularRect(36.0, 36.0, 40.0))
        assertEquals(ProgressRect(3.0, 3.0, 30.0, 30.0), ProgressGeometry.circularRect(36.0, 36.0, 6.0))
        assertEquals(ProgressRect(2.0, 2.0, 76.0, 32.0), ProgressGeometry.circularRect(80.0, 36.0, 4.0))
        assertEquals(ProgressRect(2.0, 2.0, 0.0, 0.0), ProgressGeometry.circularRect(2.0, 2.0, 4.0))
    }

    /** A7.3: no value or NaN is one static arc, -0.5 rad sweeping 4.5 rad, over no track. */
    @Test
    fun a7_3_anIndeterminateCircularIsOneStaticArc() {
        for (value in listOf(null, Double.NaN)) {
            val arc = ProgressGeometry.circularArc(value)
            assertEquals(CircularArc(-0.5, 4.5, track = false), arc)
            assertTrue(arc.drawsArc)
        }
    }

    /** A7.3: 0.4 sweeps 0.8π (144°) from 12 o'clock, over the full track. */
    @Test
    fun a7_3_aDeterminateCircularSweepsFromTwelveOClock() {
        val arc = ProgressGeometry.circularArc(0.4)
        assertEquals(-PI / 2, arc.startRad, eps)
        assertEquals(0.8 * PI, arc.sweepRad, eps)
        assertEquals(144.0, Math.toDegrees(arc.sweepRad), 1e-9)
        assertTrue(arc.track)
        assertTrue(arc.drawsArc)
    }

    /** A7.3: the value is clamped to 0..1; at 0 only the track is drawn. */
    @Test
    fun a7_3_theCircularValueIsClampedAndZeroDrawsNoArc() {
        for (value in listOf(-1.0, 0.0)) {
            val arc = ProgressGeometry.circularArc(value)
            assertEquals(CircularArc(-PI / 2, 0.0, track = true), arc)
            assertFalse(arc.drawsArc)
        }
        val full = ProgressGeometry.circularArc(2.0)
        assertEquals(CircularArc(-PI / 2, 2 * PI, track = true), full)
        assertTrue(full.drawsArc)
    }

    /** A7.3: the track is the colour with its alpha replaced by 0x33; the default colour is #2196F3. */
    @Test
    fun a7_3_theTrackIsTheColourAtAlpha0x33() {
        assertEquals(0x33FF0000, ProgressGeometry.trackColor(0x80FF0000.toInt()))
        assertEquals(0x33FF0000, ProgressGeometry.trackColor(0xFFFF0000.toInt()))
        assertEquals(0x33FF0000, ProgressGeometry.trackColor(0x00FF0000))
        assertEquals(0x33123456, ProgressGeometry.trackColor(0x00123456))
        assertEquals(0xFF2196F3.toInt(), ProgressGeometry.DEFAULT_COLOR)
        assertEquals(0x332196F3, ProgressGeometry.trackColor(ProgressGeometry.DEFAULT_COLOR))
    }

    // Linear

    /**
     * A7.3: the height is minHeight, 4 when unset (0 stays 0, a negative one
     * or NaN is 0), its corner radius half of it; the track is #E0E0E0.
     */
    @Test
    fun a7_3_linearHeightDefaultsTo4WithRadiusHalfOfIt() {
        assertEquals(4.0, ProgressGeometry.linearHeight(null))
        assertEquals(2.0, ProgressGeometry.linearRadius(ProgressGeometry.linearHeight(null)))
        assertEquals(10.0, ProgressGeometry.linearHeight(10.0))
        assertEquals(5.0, ProgressGeometry.linearRadius(10.0))
        assertEquals(0.0, ProgressGeometry.linearHeight(0.0))
        assertEquals(0.0, ProgressGeometry.linearRadius(0.0))
        assertEquals(0.0, ProgressGeometry.linearHeight(-3.0))
        assertEquals(0.0, ProgressGeometry.linearHeight(-2.0))
        assertEquals(0.0, ProgressGeometry.linearHeight(Double.NaN))
        assertEquals(0xFFE0E0E0.toInt(), ProgressGeometry.LINEAR_TRACK_COLOR)
    }

    /** A7.3: without a value a Linear draws the bare track. */
    @Test
    fun a7_3_anIndeterminateLinearHasNoBar() {
        assertNull(ProgressGeometry.linearBar(200.0, null))
        assertEquals(0xFFE0E0E0.toInt(), ProgressGeometry.LINEAR_TRACK_COLOR)
    }

    /**
     * A7.3: with a value the bar is the width times the value clamped to
     * 0..1, from the left; NaN is a full bar (Dart's `clamp` puts NaN above
     * every number).
     */
    @Test
    fun a7_3_aDeterminateLinearBarIsTheClampedFractionOfTheWidthFromTheLeft() {
        assertEquals(80.0, ProgressGeometry.linearBar(200.0, 0.4)!!, eps)
        assertEquals(0.0, ProgressGeometry.linearBar(200.0, 0.0))
        assertEquals(0.0, ProgressGeometry.linearBar(200.0, -0.5))
        assertEquals(200.0, ProgressGeometry.linearBar(200.0, 1.5))
        assertEquals(200.0, ProgressGeometry.linearBar(200.0, Double.NaN))
        assertEquals(0xFF2196F3.toInt(), ProgressGeometry.DEFAULT_COLOR)
    }
}
