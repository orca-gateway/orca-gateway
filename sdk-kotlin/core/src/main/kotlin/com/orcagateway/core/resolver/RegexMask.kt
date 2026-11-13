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
 * Under `i` the two compare a backreference otherwise: Dart canonicalizes
 * without `u` by upper case (and maps no letter outside ASCII into it), with
 * `u` by simple case folding, where the JVM compares by upper case and by
 * the lower case of that. So without `u` Dart keeps ſ, the Kelvin, Ångström
 * and ohm signs and ϴ U+03F4 apart from s, k, å, ω and θ, ß and ẞ apart
 * from each other and the Greek letters with iota subscript apart from
 * their capitals, which the JVM all folds together; under both it keeps ı
 * and İ alone, which the JVM pairs with I and i; and with `u` it joins ΐ
 * U+0390 with U+1FD3, ΰ U+03B0 with U+1FE3 and ﬅ with ﬆ, which the JVM
 * keeps apart. Where the pattern writes a backreference under `i`,
 * [withLetters] masks each of these letters the input holds as well: one
 * stand-in for each of Dart's fold classes under the flags
 * ([DartFoldTable]), which has no case, so that a reference matches it only
 * to itself, as Dart matches the letters of the class. Two letters of one
 * class share it, so a part of the pattern read without `i` can't tell them
 * apart (a known limit). [RegexSupport.asciiClasses] writes the letter in
 * the pattern, and in Dart's set of a letter it is in, as the stand-in, and
 * a class, escape or property takes the stand-in where Dart takes the
 * letter.
 *
 * Stand-ins are private-use units, U+E000-F8FF: no letter, digit, space or
 * line terminator, and no case, as the halves have none. They are the
 * lowest such units that neither the input nor the pattern holds, as a
 * character or as the value of a `\uHHHH`, `\u{…}` or `\x{…}` anywhere in the
 * pattern (read conservatively), taken per call from one [StandInPool] and
 * given in the halves' order, so that a range over halves stays a range,
 * then to the letters' classes. When the pool runs out (an input of more
 * than about 4 350 distinct private-use characters) the call runs unmasked,
 * as it did before, or without the letters' stand-ins.
 */
internal class RegexMask private constructor(
    /** The input with each masked unit replaced by its stand-in: the text the engine searches. */
    val text: String,
    /** The masked units in order, and at the same index each one's stand-in (in order too). */
    private val units: CharArray,
    private val standIns: CharArray,
    /** The masked letters in order, and at the same index each one's stand-in, one per Dart fold class. */
    private val letters: CharArray,
    private val letterStandIns: CharArray,
) {
    /** The stand-in of [unit], a surrogate unit or a letter, or null when [unit] is not masked. */
    fun standIn(unit: Int): Char? = half(unit) ?: letter(unit)

    /** The stand-in of the surrogate unit [unit], or null when it is not masked (with `u` none is). */
    fun half(unit: Int): Char? {
        if (unit !in 0..0xFFFF) return null
        val n = units.binarySearch(unit.toChar())
        return if (n >= 0) standIns[n] else null
    }

    private fun letter(unit: Int): Char? {
        if (unit !in 0..0xFFFF) return null
        val n = letters.binarySearch(unit.toChar())
        return if (n >= 0) letterStandIns[n] else null
    }

    /** Whether surrogate units are masked: without `u`, when the input or the pattern holds one. */
    val masksUnits: Boolean get() = units.isNotEmpty()

    /** The masked letters, each with its stand-in, in code point order; none unless [withLetters] made the mask. */
    val maskedLetters: List<Pair<Char, Char>> get() = letters.indices.map { letters[it] to letterStandIns[it] }

    /**
     * The range [from]-[to] of Dart's units as the ranges of units the engine
     * reads it with on [text]: its parts outside the surrogate block, less
     * the halves' stand-ins in them, and the stand-ins of the masked units it
     * covers. Null when it meets neither the surrogate block nor a half's
     * stand-in, the range then read as written. A letter's stand-in in it the
     * class leaves out ([RegexSupport.asciiClasses]).
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
        fun of(pattern: String, flags: String, input: String): RegexMask? = build(pattern, flags, input, letters = false)

        /**
         * [of]'s mask with the letters too, for a pattern that writes a
         * backreference under `i`: each letter of [lettersWithoutU], with `u` of
         * [lettersWithU], that the input holds, and the other letters of its Dart
         * fold class, take one stand-in. Null when the input holds none of
         * them, or when the pool runs out.
         */
        fun withLetters(pattern: String, flags: String, input: String): RegexMask? = build(pattern, flags, input, letters = true)

        private fun build(pattern: String, flags: String, input: String, letters: Boolean): RegexMask? {
            val unicode = 'u' in flags
            val units = if (unicode) CharArray(0) else halves(pattern, input)
            val candidates = if (unicode) lettersWithU else lettersWithoutU
            // Dart's fold class of each such letter the input holds, its set in DartFoldTable.
            val classes = if (letters) input.filter { it in candidates }.map { DartFoldTable.set(it, unicode)!! }.distinct().sorted() else emptyList()
            if (classes.isEmpty() && (letters || units.isEmpty())) return null
            val pool = StandInPool(pattern, input)
            val standIns = CharArray(units.size)
            for (n in units.indices) standIns[n] = pool.take() ?: return null
            val byLetter = HashMap<Char, Char>()
            for (k in classes) {
                val standIn = pool.take() ?: return null
                for (c in k) byLetter[c] = standIn
            }
            val masked = byLetter.keys.sorted().toCharArray()
            val text = StringBuilder(input.length)
            for (c in input) text.append(if (c.isSurrogate() && units.isNotEmpty()) standIns[units.binarySearch(c)] else byLetter[c] ?: c)
            return RegexMask(text.toString(), units, standIns, masked, CharArray(masked.size) { byLetter.getValue(masked[it]) })
        }

        /** The surrogate units, in order, that [input] holds or [pattern] holds or spells. */
        private fun halves(pattern: String, input: String): CharArray {
            val seen = BooleanArray(SURROGATE_LAST - SURROGATE_FIRST + 1)
            for (c in input) if (c.isSurrogate()) seen[c.code - SURROGATE_FIRST] = true
            for (c in pattern) if (c.isSurrogate()) seen[c.code - SURROGATE_FIRST] = true
            escapedValues(pattern) { if (it in SURROGATE_FIRST..SURROGATE_LAST) seen[it - SURROGATE_FIRST] = true }
            return seen.indices.filter { seen[it] }.map { (it + SURROGATE_FIRST).toChar() }.toCharArray()
        }

        /**
         * Without `u`, the letters Dart's backreference under `i` matches only
         * to themselves and the JVM's to others: ß, İ, ı, ſ, ϴ, ẞ, the Greek
         * letters with iota subscript (U+1F80-1FAF, ᾳ, ᾼ, ῃ, ῌ, ῳ, ῼ), and the
         * ohm, Kelvin and Ångström signs. Printed by Dart 3.14.0 for every pair
         * of letters a simple case mapping joins.
         */
        private val lettersWithoutU: Set<Char> by lazy { listed("00DF 0130 0131 017F 03F4 1E9E 1F80-1FAF 1FB3 1FBC 1FC3 1FCC 1FF3 1FFC 2126 212A 212B") }

        /**
         * With `u`, the letters whose Dart fold class the JVM's backreference
         * draws otherwise: İ and ı (each alone in Dart), and ΐ U+0390 with
         * U+1FD3, ΰ U+03B0 with U+1FE3, ﬅ with ﬆ (Dart's classes, which have no
         * case mapping between their letters for the JVM to join).
         * Printed by Dart 3.14.0 for every pair of each class of [DartFoldClasses].
         */
        private val lettersWithU: Set<Char> by lazy { listed("0130 0131 0390 03B0 1FD3 1FE3 FB05 FB06") }

        /** The letters [hex] lists, a run written `first-last`. */
        private fun listed(hex: String): Set<Char> = hex.split(' ').flatMap { part ->
            val (first, last) = if ('-' in part) part.split('-') else listOf(part, part)
            (first.toInt(16)..last.toInt(16)).map { it.toChar() }
        }.toSet()
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
