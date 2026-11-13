package com.orcagateway.core.resolver

/**
 * A masked run (row 23b.38): the stand-ins one regex call searches with.
 *
 * Without `u` Dart reads a pattern and its input as UTF-16 code units, so
 * each half of a surrogate pair is one character to it: `.` matches 😀
 * twice, `[😀]` is a class of two halves, `^.$` misses it, and a match may
 * hold one half alone. java.util.regex and Android's ICU read code points
 * and join the input's pairs, so no rewrite of the pattern alone gets there.
 * The engine searches [text] instead, a copy of the input of the same UTF-16
 * length in which each surrogate unit is its stand-in, and
 * [RegexSupport.asciiClasses] writes each surrogate the pattern names (a
 * literal half, a `\uHHHH` escape, a class member, a range end) as the same
 * stand-in. A match is a range of units, the same in the copy and in the
 * input, and its text is read back from the input ([RegexSupport.Match]), a
 * lone half kept as Dart keeps it.
 *
 * Stand-ins are private-use units, U+E000-F8FF: no letter, digit, space or
 * line terminator, and no case, as the halves have none. They are the
 * lowest such units that neither the input nor the pattern holds, as a
 * character or as the value of a `\uHHHH`, `\u{…}` or `\x{…}` anywhere in the
 * pattern (read conservatively), taken per call from one [StandInPool] and
 * given in the halves' order, so that a range over halves stays a range.
 * When the pool runs out (an input of more than about 4 350 distinct
 * private-use characters) the call runs unmasked, as it did before.
 */
internal class RegexMask private constructor(
    /** The input with each masked unit replaced by its stand-in: the text the engine searches. */
    val text: String,
    /** The masked units in order, and at the same index each one's stand-in (in order too). */
    private val units: CharArray,
    private val standIns: CharArray,
) {
    /** The stand-in of [unit], or null when [unit] is not masked. */
    fun standIn(unit: Int): Char? {
        if (unit !in 0..0xFFFF) return null
        val n = units.binarySearch(unit.toChar())
        return if (n >= 0) standIns[n] else null
    }

    /**
     * The range [from]-[to] of Dart's units as the ranges of units the engine
     * reads it with on [text]: its parts outside the surrogate block, less
     * the stand-ins in them, and the stand-ins of the masked units it covers.
     * Null when it meets neither the surrogate block nor a stand-in, the
     * range then read as written.
     */
    fun ranges(from: Int, to: Int): List<IntRange>? {
        val block = from <= SURROGATE_LAST && to >= SURROGATE_FIRST
        if (!block && standIns.none { it.code in from..to }) return null
        val parts = ArrayList<IntRange>()
        fun outside(a: Int, b: Int) {
            var start = a
            for (s in standIns) {
                val c = s.code
                if (c < a || c > b) continue
                if (c > start) parts.add(start until c)
                start = c + 1
            }
            if (start <= b) parts.add(start..b)
        }
        if (from < SURROGATE_FIRST) outside(from, minOf(to, SURROGATE_FIRST - 1))
        if (to > SURROGATE_LAST) outside(maxOf(from, SURROGATE_LAST + 1), to)
        units.indices.filter { units[it].code in from..to }.forEach { parts.add(standIns[it].code..standIns[it].code) }
        parts.sortBy { it.first }
        val merged = ArrayList<IntRange>()
        for (r in parts) {
            val last = merged.lastOrNull()
            if (last != null && r.first <= last.last + 1) merged[merged.lastIndex] = last.first..maxOf(last.last, r.last) else merged.add(r)
        }
        return merged
    }

    companion object {
        private const val SURROGATE_FIRST = 0xD800
        private const val SURROGATE_LAST = 0xDFFF

        /**
         * The mask for [pattern] under [flags] on [input], or null where the
         * call runs as it always has: with `u` (Dart reads code points then),
         * when neither the input nor the pattern holds a surrogate unit (as a
         * character, a half of one above U+FFFF, or a `\uHHHH` value), or when
         * the pool runs out.
         */
        fun of(pattern: String, flags: String, input: String): RegexMask? {
            if ('u' in flags) return null
            val seen = BooleanArray(SURROGATE_LAST - SURROGATE_FIRST + 1)
            for (c in input) if (c.isSurrogate()) seen[c.code - SURROGATE_FIRST] = true
            for (c in pattern) if (c.isSurrogate()) seen[c.code - SURROGATE_FIRST] = true
            escapedValues(pattern) { if (it in SURROGATE_FIRST..SURROGATE_LAST) seen[it - SURROGATE_FIRST] = true }
            val units = seen.indices.filter { seen[it] }.map { (it + SURROGATE_FIRST).toChar() }.toCharArray()
            if (units.isEmpty()) return null
            val pool = StandInPool(pattern, input)
            val standIns = CharArray(units.size)
            for (n in units.indices) standIns[n] = pool.take() ?: return null
            val text = StringBuilder(input.length)
            for (c in input) text.append(if (c.isSurrogate()) standIns[units.binarySearch(c)] else c)
            return RegexMask(text.toString(), units, standIns)
        }
    }
}

/**
 * The private-use units, U+E000-F8FF, that neither the input nor the
 * pattern holds ([escapedValues] reads the pattern's escapes), handed out
 * lowest first: the stand-ins of one masked run, whatever units it masks.
 */
private class StandInPool(pattern: String, input: String) {
    private val held = BooleanArray(LAST - FIRST + 1)
    private var next = 0

    init {
        for (c in input) hold(c.code)
        for (c in pattern) hold(c.code)
        escapedValues(pattern, ::hold)
    }

    private fun hold(unit: Int) {
        if (unit in FIRST..LAST) held[unit - FIRST] = true
    }

    /** The lowest free unit not yet taken, or null when none is left. */
    fun take(): Char? {
        while (next < held.size && held[next]) next += 1
        if (next >= held.size) return null
        next += 1
        return (FIRST + next - 1).toChar()
    }

    private companion object {
        const val FIRST = 0xE000
        const val LAST = 0xF8FF
    }
}

/** Calls [each] with the value of every `\uHHHH`, `\u{…}` and `\x{…}` in [pattern], escaped or not. */
private fun escapedValues(pattern: String, each: (Int) -> Unit) {
    var i = pattern.indexOf('\\')
    while (i >= 0 && i + 1 < pattern.length) {
        val kind = pattern[i + 1]
        val digits = when {
            (kind == 'u' || kind == 'x') && pattern.getOrNull(i + 2) == '{' ->
                pattern.indexOf('}', i + 3).takeIf { it > i + 3 }?.let { pattern.substring(i + 3, it) }
            kind == 'u' && i + 6 <= pattern.length -> pattern.substring(i + 2, i + 6)
            else -> null
        }
        if (digits != null && digits.length <= 6 && digits.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }) each(digits.toInt(16))
        i = pattern.indexOf('\\', i + 1)
    }
}
