package com.orcagateway.core.json

import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode

/**
 * String conversions that reproduce Dart's `'$value'` and `toStringAsFixed`,
 * because the Flutter SDK is the reference client: a `toString`, `template`
 * or `formatNumber` transform must render the same text on every SDK.
 */
public object DartFormat {
    /**
     * Dart's `'$value'` for a JSON value: `null`, `true`, `42`, `4.0`,
     * `1e+21`, `[1, a]`, `{k: v}` (object keys sorted, as Swift prints them).
     */
    public fun string(value: JsonValue): String = when (value) {
        JsonValue.Null -> "null"
        is JsonValue.Bool -> if (value.value) "true" else "false"
        is JsonValue.Int -> value.value.toString()
        is JsonValue.Double -> double(value.value)
        is JsonValue.String -> value.value
        is JsonValue.Array -> value.items.joinToString(", ", "[", "]") { string(it) }
        is JsonValue.Object -> value.members.keys.sortedWith(SwiftText.stringOrder)
            .joinToString(", ", "{", "}") { "$it: ${string(value.members.getValue(it))}" }
    }

    /**
     * Dart's `double.toString()`: the shortest digits that round-trip, in
     * fixed notation for 1e-6 <= |x| < 1e21 (with a trailing `.0` when
     * integral) and exponential notation (`1e+21`, `1.5e-7`) otherwise.
     */
    public fun double(d: Double): String {
        if (d.isNaN()) return "NaN"
        if (d.isInfinite()) return if (d < 0) "-Infinity" else "Infinity"
        if (d == 0.0) return if (d.toRawBits() < 0) "-0.0" else "0.0"

        val (digits, n) = shortestDigits(Math.abs(d)) // value = 0.d1d2...dk × 10^n
        val sign = if (d < 0) "-" else ""
        val k = digits.length

        if (n in k..21) return sign + digits + "0".repeat(n - k) + ".0"
        if (n in 1..21) return sign + digits.substring(0, n) + "." + digits.substring(n)
        if (n in -5..0) return sign + "0." + "0".repeat(-n) + digits
        val e = n - 1
        val expPart = "e" + (if (e >= 0) "+" else "-") + Math.abs(e)
        if (k == 1) return sign + digits + expPart
        return sign + digits.substring(0, 1) + "." + digits.substring(1) + expPart
    }

    /**
     * The shortest significant digits that read back as [magnitude] (finite,
     * positive), and the closest to its exact value among those, as Swift's
     * `description` gives them; with the decimal point position
     * (value = 0.digits × 10^pointPos). Independent of the JVM's own
     * `Double.toString`, which is not shortest before JDK 19.
     */
    private fun shortestDigits(magnitude: Double): Pair<String, Int> {
        val exact = BigDecimal(magnitude)
        for (precision in 1..17) {
            val down = exact.round(MathContext(precision, RoundingMode.FLOOR))
            val up = exact.round(MathContext(precision, RoundingMode.CEILING))
            val downOk = readsBack(down, magnitude)
            val upOk = readsBack(up, magnitude)
            val pick = when {
                downOk && upOk -> {
                    val below = exact.subtract(down)
                    val above = up.subtract(exact)
                    when {
                        below < above -> down
                        above < below -> up
                        else -> exact.round(MathContext(precision, RoundingMode.HALF_EVEN))
                    }
                }
                downOk -> down
                upOk -> up
                else -> continue
            }
            val stripped = pick.stripTrailingZeros()
            val digits = stripped.unscaledValue().toString()
            return digits to (digits.length - stripped.scale())
        }
        // 17 significant digits always round-trip; not reached.
        val stripped = exact.round(MathContext(17, RoundingMode.HALF_EVEN)).stripTrailingZeros()
        val digits = stripped.unscaledValue().toString()
        return digits to (digits.length - stripped.scale())
    }

    private fun readsBack(candidate: BigDecimal, d: Double): Boolean =
        java.lang.Double.parseDouble(candidate.toString()) == d

    /**
     * Dart's `num.toStringAsFixed(fractionDigits)`: rounds half away from
     * zero on the exact binary value (`0.125` gives `0.13`, `2.5` gives `3`),
     * falls back to `toString()` for |x| >= 1e21. Returns null where Dart
     * throws (fractionDigits outside 0..20).
     */
    public fun fixed(value: Double, fractionDigits: Long): String? {
        if (fractionDigits !in 0L..20L) return null
        if (value.isNaN()) return "NaN"
        if (value.isInfinite()) return if (value < 0) "-Infinity" else "Infinity"
        if (Math.abs(value) >= 1e21) return double(value)
        val n = fractionDigits.toInt()

        // Print well past the cut (C's "%.{n+25}f", exact and half-even); the
        // extra digits show which side of the half the exact value lies on.
        val long = BigDecimal(Math.abs(value)).setScale(n + 25, RoundingMode.HALF_EVEN).toPlainString()
        val dot = long.indexOf('.')
        var intDigits = if (dot < 0) long else long.substring(0, dot)
        val frac = if (dot < 0) "" else long.substring(dot + 1)
        var kept = frac.take(n)
        val roundUp = frac.length > n && frac[n] >= '5'

        if (roundUp) {
            val all = (intDigits + kept).toCharArray()
            var i = all.size - 1
            var carry = true
            while (carry && i >= 0) {
                if (all[i] == '9') {
                    all[i] = '0'
                    i -= 1
                } else {
                    all[i] = all[i] + 1
                    carry = false
                }
            }
            val joined = (if (carry) "1" else "") + String(all)
            intDigits = joined.substring(0, joined.length - kept.length)
            kept = joined.substring(joined.length - kept.length)
        }

        val sign = if (value.toRawBits() < 0) "-" else ""
        return sign + intDigits + (if (n > 0) ".$kept" else "")
    }

    /** `toStringAsFixed` for a JSON number (Dart converts an int to double). */
    public fun fixed(value: JsonValue, fractionDigits: Long): String? {
        val d = value.doubleValue ?: return null
        return fixed(d, fractionDigits)
    }
}
