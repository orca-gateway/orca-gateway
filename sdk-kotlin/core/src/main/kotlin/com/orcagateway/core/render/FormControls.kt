package com.orcagateway.core.render

import com.orcagateway.core.resolver.roundHalfAwayFromZero

/**
 * What a tap or a drag does to Checkbox, Radio and Slider, Flutter's
 * builders (input_builders.dart:139-348) with the Material controls they
 * make. The UI layers only measure, draw and feed gestures; the stateKey
 * write and onChange are theirs. The same cases as Swift's FormControls.
 */
public object FormControls {
    /**
     * The value a tap on a Checkbox showing [value] gives: Toggleable's
     * `_handleTap` (widgets/toggleable.dart:247-252), false → true, true →
     * null with [tristate] or false without, null → false. The builder
     * (input_builders.dart:208-218) writes it to its stateKey, then fires
     * onChange with it; a two-state Checkbox never gets null, as it draws
     * a missing value as false (`value ?? false`, :224), so its UI passes
     * the value it draws.
     */
    public fun checkboxNext(value: Boolean?, tristate: Boolean): Boolean? = when (value) {
        false -> true
        true -> if (tristate) null else false
        null -> false
    }

    /**
     * Whether the Radio with [value] is the selected one of the [group]:
     * equal as strings (input_builders.dart:142-148). A missing value and a
     * missing group are both '' (builder_helpers.dart:440), so they select.
     */
    public fun radioSelected(value: String, group: String): Boolean = value == group

    /**
     * The value a Slider takes with the finger at [fraction] of its track:
     * Flutter's `_lerp` (material slider.dart:811-819) on the fraction
     * clamped to 0..1, min + t x (max - min), or with [divisions] above 0
     * (the render object's `isDiscrete`; Flutter asserts on 0 and below,
     * read here as continuous) the nearest of the d + 1 stops, min +
     * round(t x d) x (max - min) / d, half rounded away from zero as Dart's
     * `round`. An empty or reversed range (Flutter's builder throws on
     * the reversed one in `clamp`) stays at [min].
     */
    public fun sliderValue(fraction: Double, min: Double, max: Double, divisions: Int?): Double {
        if (!(max > min)) return min
        val t = fraction.coerceIn(0.0, 1.0)
        if (divisions != null && divisions > 0) return min + roundHalfAwayFromZero(t * divisions) * (max - min) / divisions
        return t * (max - min) + min
    }

    /**
     * Where along its track a Slider draws [value]: the builder clamps it
     * to [min]..[max] (input_builders.dart:312), then Flutter's `_unlerp`
     * (material slider.dart:838-842), (value - min) / (max - min), 0 when
     * the range is empty or reversed.
     */
    public fun sliderFraction(value: Double, min: Double, max: Double): Double {
        if (!(max > min)) return 0.0
        return (value.coerceIn(min, max) - min) / (max - min)
    }
}
