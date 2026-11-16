package com.orcagateway.core.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A6.1-A6.3, the core half of Checkbox, Radio and Slider: what a tap or a
 * drag makes of the control's value, against Flutter's builders
 * (sdk/lib/src/builders/input_builders.dart: Radio :139-194, Checkbox
 * :196-244, Slider :296-348). A Checkbox tap is Toggleable's `_handleTap`
 * (widgets/toggleable.dart:247-252): false → true, true → null when
 * tristate else false, null → false. A Radio is selected iff its value and
 * the group value are the same string, a missing one being ''
 * (builder_helpers.dart:440). A Slider fraction (0 at min, 1 at max) is
 * clamped, then lerped, snapped to `divisions` when there are more than 0
 * (material slider.dart:811-819, :1317); a value's fraction is its clamped
 * distance from min over the range, 0 for an empty range (:838-842). The
 * same cases and numbers as Swift's FormControlsTests.
 */
class FormControlsTest {
    private fun value(fraction: Double, min: Double, max: Double, divisions: Int? = null): Double =
        FormControls.sliderValue(fraction, min, max, divisions)

    private fun fraction(value: Double, min: Double, max: Double): Double = FormControls.sliderFraction(value, min, max)

    // A6.1 Checkbox

    /** A6.1: a two-state Checkbox flips between false and true. */
    @Test
    fun a6_1_aCheckboxTogglesBetweenFalseAndTrue() {
        assertEquals(true, FormControls.checkboxNext(false, tristate = false))
        assertEquals(false, FormControls.checkboxNext(true, tristate = false))
    }

    /** A6.1: a tristate Checkbox cycles false → true → null → false. */
    @Test
    fun a6_1_aTristateCheckboxCyclesFalseTrueNull() {
        assertEquals(true, FormControls.checkboxNext(false, tristate = true))
        assertNull(FormControls.checkboxNext(true, tristate = true))
        assertEquals(false, FormControls.checkboxNext(null, tristate = true))
    }

    /**
     * A6.1: null goes to false whether or not the Checkbox is tristate
     * (Toggleable's null case does not read `tristate`).
     */
    @Test
    fun a6_1_aNullCheckboxGoesToFalse() {
        assertEquals(false, FormControls.checkboxNext(null, tristate = false))
    }

    // A6.2 Radio

    /**
     * A6.2: a Radio is selected when its value is the group value, so of a
     * group sharing one value exactly one is.
     */
    @Test
    fun a6_2_aRadioIsSelectedWhenItsValueEqualsTheGroup() {
        assertTrue(FormControls.radioSelected("a", "a"))
        assertFalse(FormControls.radioSelected("a", "b"))
        assertEquals(listOf("b"), listOf("a", "b", "c").filter { FormControls.radioSelected(it, "b") })
    }

    /**
     * A6.2: the comparison is exact string equality: no case folding, no
     * trimming, no reading numbers ("1" is not "1.0").
     */
    @Test
    fun a6_2_aRadioComparesExactStrings() {
        assertTrue(FormControls.radioSelected("1.0", "1.0"))
        assertFalse(FormControls.radioSelected("A", "a"))
        assertFalse(FormControls.radioSelected(" a", "a"))
        assertFalse(FormControls.radioSelected("1", "1.0"))
    }

    /** A6.2: a missing value and a missing group are both '', so they select; '' against a set one does not. */
    @Test
    fun a6_2_aMissingValueAndEmptyGroupSelect() {
        assertTrue(FormControls.radioSelected("", ""))
        assertFalse(FormControls.radioSelected("a", ""))
        assertFalse(FormControls.radioSelected("", "a"))
    }

    // A6.3 Slider

    /** A6.3: a continuous Slider's value is min plus the fraction of the range; the builder's defaults are min 0, max 1. */
    @Test
    fun a6_3_aContinuousSliderValueIsMinPlusTheFraction() {
        assertEquals(25.0, value(0.25, 0.0, 100.0), 1e-9)
        assertEquals(0.0, value(0.5, -1.0, 1.0), 1e-9)
        assertEquals(20.0, value(1.0, 10.0, 20.0), 1e-9)
        assertEquals(10.0, value(0.0, 10.0, 20.0), 1e-9)
        assertEquals(0.3, value(0.3, 0.0, 1.0), 1e-9)
    }

    /** A6.3: a fraction past either end of the track is held at it. */
    @Test
    fun a6_3_aSliderFractionIsClampedToTheTrack() {
        assertEquals(0.0, value(-0.5, 0.0, 100.0), 1e-9)
        assertEquals(100.0, value(1.5, 0.0, 100.0), 1e-9)
        assertEquals(100.0, value(1.5, 0.0, 100.0, 4), 1e-9)
    }

    /** A6.3: with divisions the value snaps to the nearest of divisions + 1 stops, min + round(t · d) · (max − min) / d. */
    @Test
    fun a6_3_aDiscreteSliderSnapsToTheNearestDivision() {
        assertEquals(25.0, value(0.3, 0.0, 100.0, 4), 1e-9)
        assertEquals(50.0, value(0.4, 0.0, 100.0, 4), 1e-9)
        assertEquals(100.0, value(0.9, 0.0, 100.0, 4), 1e-9)
        assertEquals(10 + 10.0 / 3, value(0.33, 10.0, 20.0, 3), 1e-9)
        assertEquals(0.0, value(0.1, 0.0, 1.0, 1), 1e-9)
    }

    /** A6.3: half way between two stops goes to the later one, Dart's `round` (half away from zero), not half to even. */
    @Test
    fun a6_3_aHalfWayBetweenStopsRoundsAwayFromZero() {
        assertEquals(25.0, value(0.125, 0.0, 100.0, 4), 1e-9)
        assertEquals(75.0, value(0.625, 0.0, 100.0, 4), 1e-9)
    }

    /**
     * A6.3: divisions 0 or below, which Flutter only asserts on (slider
     * .dart:223), are a continuous Slider, as its render object takes only
     * more than 0 as discrete (:1317).
     */
    @Test
    fun a6_3_aDivisionsZeroOrBelowAreContinuous() {
        assertEquals(30.0, value(0.3, 0.0, 100.0, 0), 1e-9)
        assertEquals(30.0, value(0.3, 0.0, 100.0, -2), 1e-9)
    }

    /**
     * A6.3: a value's fraction is its distance from min over the range, the
     * value first held within the range (the builder's `value.clamp(min, max)`).
     */
    @Test
    fun a6_3_aValueFractionIsClampedOverTheRange() {
        assertEquals(0.25, fraction(25.0, 0.0, 100.0), 1e-9)
        assertEquals(0.5, fraction(0.0, -1.0, 1.0), 1e-9)
        assertEquals(1.0, fraction(150.0, 0.0, 100.0), 1e-9)
        assertEquals(0.0, fraction(-5.0, 0.0, 100.0), 1e-9)
    }

    /**
     * A6.3: an empty range (max == min) is fraction 0 and every fraction
     * gives min; so is a reversed one (max < min), which Flutter asserts on
     * and whose `clamp` throws.
     */
    @Test
    fun a6_3_anEmptyOrReversedRangeIsFractionZeroAndValueMin() {
        assertEquals(0.0, fraction(5.0, 5.0, 5.0))
        assertEquals(0.0, fraction(3.0, 10.0, 0.0))
        assertEquals(5.0, value(0.7, 5.0, 5.0))
        assertEquals(5.0, value(0.7, 5.0, 5.0, 4))
        assertEquals(10.0, value(0.7, 10.0, 0.0))
        assertEquals(10.0, value(0.7, 10.0, 0.0, 4))
    }

    /**
     * A6.3: a discrete Slider draws its thumb at the stop nearest its value
     * (Flutter's `_convert`, slider.dart:829-836): the value's fraction,
     * snapped through sliderValue, then that value's fraction.
     */
    @Test
    fun a6_3_aDiscreteThumbIsDrawnAtTheNearestStop() {
        val snapped = value(fraction(30.0, 0.0, 100.0), 0.0, 100.0, 4)
        assertEquals(25.0, snapped, 1e-9)
        assertEquals(0.25, fraction(snapped, 0.0, 100.0), 1e-9)
    }
}
