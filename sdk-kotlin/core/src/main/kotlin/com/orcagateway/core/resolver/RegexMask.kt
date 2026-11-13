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
 * keeps apart. Nor does the JVM join the letters of a class its Unicode
 * lacks ([DartFoldClasses.lagging]: ƛ U+019B and U+A7DC on JDK 21, with `u`
 * 𐵐 U+10D50 and 𐵰 U+10D70 too). Where the pattern writes a backreference
 * under `i`, [withLetters] masks each of these letters the input holds as
 * well, those of the lagging classes without `u` in the BMP only (above
 * U+FFFF a letter is two halves there): one stand-in for each of Dart's fold
 * classes under the flags ([RegexSupport.dartSet]), which has no case, so
 * that a reference matches it only to itself, as Dart matches the letters
 * of the class. Two letters of one class share it, so a part of the pattern
 * read without `i` can't tell them apart (a known limit).
 * [RegexSupport.asciiClasses] writes the letter in the pattern, and in
 * Dart's set of a letter it is in, as the stand-in, and a class, escape or
 * property takes the stand-in where Dart takes the letter.
 *
 * Stand-ins are private-use characters: no letter, digit, space or line
 * terminator, and no case, as the halves have none. They are the lowest
 * such characters that neither the input nor the pattern holds, as a
 * character or as the value of a `\uHHHH`, `\u{…}` or `\x{…}` anywhere in the
 * pattern (read conservatively; a high half's `\uHHHH` and a low half's right
 * after it as the character they spell too), taken per call from one [StandInPool]: units
 * U+E000-F8FF for the halves, in their order, so that a range over halves
 * stays a range, then for the letters' classes in the BMP, and for a class
 * above U+FFFF a character of two units, from U+F0000-FFFFD then
 * U+100000-10FFFD, as its letters are (no class has letters of both). So
 * the copy keeps the input's UTF-16 length. When the pool runs out (an input
 * of more than about 4 350 distinct private-use characters) the call runs
 * unmasked, as it did before, or without the letters' stand-ins.
 */
internal class RegexMask private constructor(
    /** The input with each masked unit and letter replaced by its stand-in: the text the engine searches. */
    val text: String,
    /** The masked units in order, and at the same index each one's stand-in (in order too). */
    private val units: CharArray,
    private val standIns: CharArray,
    /**
     * The masked letters in code point order, none unless [withLetters] made the mask, and at the
     * same index each one's stand-in, one per Dart fold class.
     */
    val letters: IntArray,
    val letterStandIns: IntArray,
) {
    /** The stand-in of [codePoint], a surrogate unit or a letter, or null when it is not masked. */
    fun standIn(codePoint: Int): Int? = half(codePoint)?.code ?: letter(codePoint)

    /** The stand-in of the surrogate unit [unit], or null when it is not masked (with `u` none is). */
    fun half(unit: Int): Char? {
        if (unit !in 0..0xFFFF) return null
        val n = units.binarySearch(unit.toChar())
        return if (n >= 0) standIns[n] else null
    }

    private fun letter(codePoint: Int): Int? {
        val n = letters.binarySearch(codePoint)
        return if (n >= 0) letterStandIns[n] else null
    }

    /** Whether surrogate units are masked: without `u`, when the input or the pattern holds one. */
    val masksUnits: Boolean get() = units.isNotEmpty()

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
         * [lettersWithU], and each letter of a lagging class ([letterSets]), that
         * the input holds, and the other letters of its Dart fold class, take one
         * stand-in. Null when the input holds none of them, or when the pool
         * runs out.
         */
        fun withLetters(pattern: String, flags: String, input: String): RegexMask? = build(pattern, flags, input, letters = true)

        private fun build(pattern: String, flags: String, input: String, letters: Boolean): RegexMask? {
            val unicode = 'u' in flags
            val units = if (unicode) CharArray(0) else halves(pattern, input)
            val classes = if (letters) letterSets(input, unicode) else emptyList()
            if (classes.isEmpty() && (letters || units.isEmpty())) return null
            val pool = StandInPool(pattern, input)
            val standIns = CharArray(units.size)
            for (n in units.indices) {
                val standIn = pool.take()
                if (standIn < 0) return null
                standIns[n] = standIn.toChar()
            }
            // Each letter with its class's stand-in, the letter in the high bits, sorted by letter.
            val byLetter = LongArray(classes.sumOf { it.codePointCount(0, it.length) })
            var count = 0
            for (k in classes) {
                val standIn = if (k.codePointAt(0) > 0xFFFF) pool.takeWide() else pool.take()
                if (standIn < 0) return null
                var j = 0
                while (j < k.length) {
                    val c = k.codePointAt(j)
                    byLetter[count++] = c.toLong() shl 32 or standIn.toLong()
                    j += Character.charCount(c)
                }
            }
            byLetter.sort()
            val masked = IntArray(count) { (byLetter[it] ushr 32).toInt() }
            val maskedStandIns = IntArray(count) { byLetter[it].toInt() }
            val text = StringBuilder(input.length)
            var i = 0
            while (i < input.length) {
                val c = if (unicode) input.codePointAt(i) else input[i].code
                val n = if (count == 0) -1 else masked.binarySearch(c)
                when {
                    units.isNotEmpty() && input[i].isSurrogate() -> text.append(standIns[units.binarySearch(input[i])])
                    n >= 0 -> text.appendCodePoint(maskedStandIns[n])
                    else -> text.appendCodePoint(c)
                }
                i += Character.charCount(c)
            }
            return RegexMask(text.toString(), units, standIns, masked, maskedStandIns)
        }

        /**
         * Dart's set ([RegexSupport.dartSet]) of each letter [input] holds that the engine's
         * backreference under `i` compares otherwise, each set once, in order: a letter of
         * [lettersWithoutU], with `u` of [lettersWithU], or of a class the engine does not fold in
         * full ([DartFoldClasses.lagging]), without `u` one in the BMP, as Dart reads units there.
         * Each class is tested against the lagging ones, and its set built, once: its first letter
         * met stands for the rest, as the set of a lagging class is the class.
         */
        private fun letterSets(input: String, unicode: Boolean): List<String> {
            val candidates = if (unicode) lettersWithU else lettersWithoutU
            val lagging = DartFoldClasses.lagging
            val met = if (lagging.isEmpty()) null else BooleanArray(DartFoldClasses.classes.size)
            val sets = HashSet<String>()
            var i = 0
            while (i < input.length) {
                val c = if (unicode) input.codePointAt(i) else input[i].code
                i += Character.charCount(c)
                if (c <= 0xFFFF && candidates.binarySearch(c.toChar()) >= 0) {
                    RegexSupport.dartSet(c, unicode)?.let(sets::add)
                    continue
                }
                if (met == null) continue
                val n = DartFoldClasses.letters.binarySearch(c)
                if (n < 0) continue
                val k = DartFoldClasses.classOf[n]
                if (met[k]) continue
                met[k] = true
                if (k in lagging) RegexSupport.dartSet(c, unicode)?.let(sets::add)
            }
            return sets.sorted()
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
        private val lettersWithoutU: CharArray by lazy { listed("00DF 0130 0131 017F 03F4 1E9E 1F80-1FAF 1FB3 1FBC 1FC3 1FCC 1FF3 1FFC 2126 212A 212B") }

        /**
         * With `u`, the letters whose Dart fold class the JVM's backreference
         * draws otherwise: İ and ı (each alone in Dart), and ΐ U+0390 with
         * U+1FD3, ΰ U+03B0 with U+1FE3, ﬅ with ﬆ (Dart's classes, which have no
         * case mapping between their letters for the JVM to join).
         * Printed by Dart 3.14.0 for every pair of each class of [DartFoldClasses].
         */
        private val lettersWithU: CharArray by lazy { listed("0130 0131 0390 03B0 1FD3 1FE3 FB05 FB06") }

        /** The letters [hex] lists, a run written `first-last`, in order. */
        private fun listed(hex: String): CharArray = hex.split(' ').flatMap { part ->
            val (first, last) = if ('-' in part) part.split('-') else listOf(part, part)
            (first.toInt(16)..last.toInt(16)).map { it.toChar() }
        }.sorted().toCharArray()
    }
}

/**
 * The private-use characters that neither the input nor the pattern holds
 * ([escapedValues] reads the pattern's escapes), handed out lowest first:
 * the stand-ins of one masked run, whatever it masks. [take] hands out units,
 * U+E000-F8FF, [takeWide] characters of two units, U+F0000-FFFFD then
 * U+100000-10FFFD.
 */
private class StandInPool(pattern: String, input: String) {
    private val held = BooleanArray(LAST - FIRST + 1)
    private var next = 0

    /** The held characters of two units, by their offset from [WIDE_FIRST]; null while none is. */
    private var heldWide: java.util.BitSet? = null
    private var nextWide = 0

    init {
        holdAll(input)
        holdAll(pattern)
        escapedValues(pattern, ::hold)
    }

    private fun holdAll(s: String) {
        var i = 0
        while (i < s.length) {
            val c = s.codePointAt(i)
            hold(c)
            i += Character.charCount(c)
        }
    }

    private fun hold(c: Int) {
        if (c in FIRST..LAST) held[c - FIRST] = true
        if (c in WIDE_FIRST..WIDE_LAST) (heldWide ?: java.util.BitSet().also { heldWide = it }).set(c - WIDE_FIRST)
    }

    /** The lowest free unit not yet taken, or -1 when none is left. */
    fun take(): Int {
        while (next < held.size && held[next]) next += 1
        if (next >= held.size) return -1
        next += 1
        return FIRST + next - 1
    }

    /** The lowest free character of two units not yet taken, or -1 when none is left. */
    fun takeWide(): Int {
        while (WIDE_FIRST + nextWide <= WIDE_LAST) {
            val c = WIDE_FIRST + nextWide
            nextWide += 1
            // U+FFFFE and U+FFFFF are no private-use characters.
            if ((c and 0xFFFF) < 0xFFFE && heldWide?.get(c - WIDE_FIRST) != true) return c
        }
        return -1
    }

    private companion object {
        const val FIRST = 0xE000
        const val LAST = 0xF8FF
        const val WIDE_FIRST = 0xF0000
        const val WIDE_LAST = 0x10FFFD
    }
}

/**
 * Calls [each] with the value of every `\uHHHH`, `\u{…}` and `\x{…}` in [pattern], escaped or not,
 * and for a high half's `\uHHHH` with a low half's `\uHHHH` right after it with the character above
 * U+FFFF the two spell as well, as the engine reads them.
 */
private fun escapedValues(pattern: String, each: (Int) -> Unit) {
    var i = pattern.indexOf('\\')
    while (i >= 0 && i + 1 < pattern.length) {
        val kind = pattern[i + 1]
        val braced = (kind == 'u' || kind == 'x') && pattern.getOrNull(i + 2) == '{'
        val digits = when {
            braced -> pattern.indexOf('}', i + 3).takeIf { it > i + 3 }?.let { pattern.substring(i + 3, it) }
            kind == 'u' && i + 6 <= pattern.length -> pattern.substring(i + 2, i + 6)
            else -> null
        }
        if (digits != null && digits.length <= 6 && digits.all(::isHexDigit)) {
            val value = digits.toInt(16)
            each(value)
            if (!braced && value in 0xD800..0xDBFF) {
                val low = if (pattern.startsWith("\\u", i + 6) && i + 12 <= pattern.length) pattern.substring(i + 8, i + 12) else null
                if (low != null && low.all(::isHexDigit) && low.toInt(16) in 0xDC00..0xDFFF) {
                    each(Character.toCodePoint(value.toChar(), low.toInt(16).toChar()))
                }
            }
        }
        i = pattern.indexOf('\\', i + 1)
    }
}

private fun isHexDigit(c: Char): Boolean = c in '0'..'9' || c in 'a'..'f' || c in 'A'..'F'
