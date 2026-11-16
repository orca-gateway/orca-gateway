package com.orcagateway.core.animation

import com.orcagateway.core.json.JsonValue
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.sin

/**
 * Flutter's named curves (`Curves.*` in
 * packages/flutter/lib/src/animation/curves.dart), with Flutter's own
 * formulas so a midpoint is the same number on every SDK: the names the
 * Flutter SDK's `_parseCurve` knows (builders/layout_builders.dart), which
 * are the engine's `Curves` enum. One table for widgets and route
 * transitions.
 */
public object Curves {
    private fun interface Curve {
        /** The value for a time strictly between 0 and 1. */
        fun transform(t: Double): Double
    }

    /** Flutter `Cubic(a, b, c, d)`: a Bézier from (0, 0) to (1, 1) solved by bisection on x. */
    private class Cubic(val a: Double, val b: Double, val c: Double, val d: Double) : Curve {
        override fun transform(t: Double): Double {
            var start = 0.0
            var end = 1.0
            var midpoint = 0.5
            // Flutter loops until it converges; the bound only guards a curve whose x is not monotonic.
            repeat(CUBIC_MAX_STEPS) {
                midpoint = (start + end) / 2
                val estimate = evaluate(a, c, midpoint)
                if (abs(t - estimate) < CUBIC_ERROR_BOUND) return evaluate(b, d, midpoint)
                if (estimate < t) start = midpoint else end = midpoint
            }
            return evaluate(b, d, midpoint)
        }

        private fun evaluate(a: Double, b: Double, m: Double): Double =
            3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m
    }

    /** Flutter `ThreePointCubic`: two cubics that meet at ([midX], [midY]). */
    private class ThreePointCubic(
        val a1x: Double,
        val a1y: Double,
        val b1x: Double,
        val b1y: Double,
        val midX: Double,
        val midY: Double,
        val a2x: Double,
        val a2y: Double,
        val b2x: Double,
        val b2y: Double,
    ) : Curve {
        override fun transform(t: Double): Double {
            val first = t < midX
            val scaleX = if (first) midX else 1.0 - midX
            val scaleY = if (first) midY else 1.0 - midY
            val scaledT = (t - (if (first) 0.0 else midX)) / scaleX
            return if (first) {
                at(Cubic(a1x / scaleX, a1y / scaleY, b1x / scaleX, b1y / scaleY), scaledT) * scaleY
            } else {
                at(
                    Cubic((a2x - midX) / scaleX, (a2y - midY) / scaleY, (b2x - midX) / scaleX, (b2y - midY) / scaleY),
                    scaledT,
                ) * scaleY + midY
            }
        }
    }

    private const val CUBIC_ERROR_BOUND = 0.001
    private const val CUBIC_MAX_STEPS = 64

    /** The period of Flutter's three elastic curves. */
    private const val PERIOD = 0.4

    /** Flutter `Curve.transform`: 0 and 1 are themselves, whatever the formula says. */
    private fun at(curve: Curve, t: Double): Double = if (t == 0.0 || t == 1.0) t else curve.transform(t)

    private fun bounce(time: Double): Double {
        var t = time
        if (t < 1.0 / 2.75) return 7.5625 * t * t
        if (t < 2 / 2.75) {
            t -= 1.5 / 2.75
            return 7.5625 * t * t + 0.75
        }
        if (t < 2.5 / 2.75) {
            t -= 2.25 / 2.75
            return 7.5625 * t * t + 0.9375
        }
        t -= 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    }

    private fun elastic(t: Double): Double = sin((t - PERIOD / 4.0) * (PI * 2.0) / PERIOD)

    // In the order of the Flutter SDK's `_parseCurve`.
    private val table: Map<String, Curve> = linkedMapOf(
        "linear" to Curve { it },
        "easeIn" to Cubic(0.42, 0.0, 1.0, 1.0),
        "easeOut" to Cubic(0.0, 0.0, 0.58, 1.0),
        "easeInOut" to Cubic(0.42, 0.0, 0.58, 1.0),
        "decelerate" to Curve { 1.0 - (1.0 - it) * (1.0 - it) },
        "bounceIn" to Curve { 1.0 - bounce(1.0 - it) },
        "bounceOut" to Curve { bounce(it) },
        "bounceInOut" to Curve {
            if (it < 0.5) (1.0 - bounce(1.0 - it * 2.0)) * 0.5 else bounce(it * 2.0 - 1.0) * 0.5 + 0.5
        },
        "elasticIn" to Curve { -(2.0.pow(10.0 * (it - 1.0))) * elastic(it - 1.0) },
        "elasticOut" to Curve { 2.0.pow(-10 * it) * elastic(it) + 1.0 },
        "elasticInOut" to Curve {
            val t = 2.0 * it - 1.0
            if (t < 0.0) -0.5 * 2.0.pow(10.0 * t) * elastic(t) else 2.0.pow(-10.0 * t) * elastic(t) * 0.5 + 1.0
        },
        "fastOutSlowIn" to Cubic(0.4, 0.0, 0.2, 1.0),
        "ease" to Cubic(0.25, 0.1, 0.25, 1.0),
        "easeInSine" to Cubic(0.47, 0.0, 0.745, 0.715),
        "easeOutSine" to Cubic(0.39, 0.575, 0.565, 1.0),
        "easeInOutSine" to Cubic(0.445, 0.05, 0.55, 0.95),
        "easeInQuad" to Cubic(0.55, 0.085, 0.68, 0.53),
        "easeOutQuad" to Cubic(0.25, 0.46, 0.45, 0.94),
        "easeInOutQuad" to Cubic(0.455, 0.03, 0.515, 0.955),
        "easeInCubic" to Cubic(0.55, 0.055, 0.675, 0.19),
        "easeOutCubic" to Cubic(0.215, 0.61, 0.355, 1.0),
        "easeInOutCubic" to Cubic(0.645, 0.045, 0.355, 1.0),
        "easeInQuart" to Cubic(0.895, 0.03, 0.685, 0.22),
        "easeOutQuart" to Cubic(0.165, 0.84, 0.44, 1.0),
        "easeInOutQuart" to Cubic(0.77, 0.0, 0.175, 1.0),
        "easeInQuint" to Cubic(0.755, 0.05, 0.855, 0.06),
        "easeOutQuint" to Cubic(0.23, 1.0, 0.32, 1.0),
        "easeInOutQuint" to Cubic(0.86, 0.0, 0.07, 1.0),
        "easeInExpo" to Cubic(0.95, 0.05, 0.795, 0.035),
        "easeOutExpo" to Cubic(0.19, 1.0, 0.22, 1.0),
        "easeInOutExpo" to Cubic(1.0, 0.0, 0.0, 1.0),
        "easeInCirc" to Cubic(0.6, 0.04, 0.98, 0.335),
        "easeOutCirc" to Cubic(0.075, 0.82, 0.165, 1.0),
        "easeInOutCirc" to Cubic(0.785, 0.135, 0.15, 0.86),
        "easeInBack" to Cubic(0.6, -0.28, 0.735, 0.045),
        "easeOutBack" to Cubic(0.175, 0.885, 0.32, 1.275),
        "easeInOutBack" to Cubic(0.68, -0.55, 0.265, 1.55),
        "fastLinearToSlowEaseIn" to Cubic(0.18, 1.0, 0.04, 1.0),
        "slowMiddle" to Cubic(0.15, 0.85, 0.85, 0.15),
        "fastEaseInToSlowEaseOut" to ThreePointCubic(0.056, 0.024, 0.108, 0.3085, 0.198, 0.541, 0.3655, 1.0, 0.5465, 0.989),
        "linearToEaseOut" to Cubic(0.35, 0.91, 0.33, 0.97),
        "easeInToLinear" to Cubic(0.67, 0.03, 0.65, 0.09),
    )

    private val easeInOut: Curve = table.getValue("easeInOut")

    /** Every name a `curve` prop may carry. */
    public val names: List<String> = table.keys.toList()

    /**
     * The curve [name] at time [t]. A missing or unknown name is
     * `easeInOut`, as in Flutter. [t] is clamped to 0...1 (NaN is 0), where
     * every curve is 0 and 1; in between the elastic and back curves leave
     * 0...1 in value.
     */
    public fun apply(name: String?, t: Double): Double {
        if (t.isNaN() || t <= 0.0) return 0.0
        if (t >= 1.0) return 1.0
        return (table[name] ?: easeInOut).transform(t)
    }
}

/** The `duration` prop of an animated widget or a route transition. */
public object AnimationDuration {
    /** Flutter's default for every animated widget and route transition. */
    public const val DEFAULT_MS: Double = 300.0

    /**
     * [value] in whole milliseconds, read as Dart's int (a fraction is cut
     * off), a negative one being 0 (a duration of 0 or less jumps to the end
     * state); anything else is [default].
     */
    public fun milliseconds(value: JsonValue?, default: Double = DEFAULT_MS): Double {
        val whole = value?.dartInt ?: return default
        return maxOf(whole.toDouble(), 0.0)
    }
}
