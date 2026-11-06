package com.orcagateway.core.json

import java.text.Normalizer
import java.util.Locale

/**
 * The places where the Swift SDK's behaviour comes from Swift's String model
 * rather than from its code, reproduced on JVM strings: canonical
 * equivalence (string equality), Characters (extended grapheme clusters) in
 * `hasPrefix`, `contains` and `split("")`, sort order, Foundation's
 * whitespace set, per-scalar lowercasing and ASCII-only integer parsing.
 *
 * Map keys and splitting by a separator stay UTF-16 code-unit based, as in
 * Dart (see the port notes in ValueResolver).
 */
internal object SwiftText {
    private val grapheme = Regex("\\X")

    /** Swift's `Array(string)`: one string per Character (grapheme cluster). */
    fun graphemes(s: String): List<String> =
        if (isPlain(s)) {
            s.map { it.toString() }
        } else {
            grapheme.findAll(s).map { it.value }.toList()
        }

    private fun isPlain(s: String): Boolean = s.all { it.code < 0x80 && it != '\r' }

    /** The NFC form: equal for canonically equivalent strings (Swift's `String ==`). */
    fun canonical(s: String): String =
        if (s.all { it.code < 0x80 } || Normalizer.isNormalized(s, Normalizer.Form.NFC)) s else Normalizer.normalize(s, Normalizer.Form.NFC)

    /** Characters compared by canonical equivalence (their NFC forms), as Swift's `Character ==`. */
    private fun characters(s: String): List<String> =
        graphemes(s).map { if (isPlain(it)) it else Normalizer.normalize(it, Normalizer.Form.NFC) }

    /**
     * Swift's `hasPrefix`: whole Characters, compared by canonical
     * equivalence ("é" starts with "é" but "é" does not start
     * with "e").
     */
    fun hasPrefix(s: String, prefix: String): Boolean {
        if (isPlain(s) && isPlain(prefix)) return s.startsWith(prefix)
        val a = characters(s)
        val b = characters(prefix)
        return b.size <= a.size && b.indices.all { a[it] == b[it] }
    }

    /**
     * Foundation's `String.contains(String)`: a run of whole Characters,
     * compared by canonical equivalence; an empty needle is never found
     * (Dart's `contains('')` is true).
     */
    fun contains(haystack: String, needle: String): Boolean {
        if (needle.isEmpty()) return false
        if (isPlain(haystack) && isPlain(needle)) return haystack.contains(needle)
        val a = characters(haystack)
        val b = characters(needle)
        for (i in 0..a.size - b.size) {
            if (b.indices.all { a[i + it] == b[it] }) return true
        }
        return false
    }

    /**
     * Swift's `String <`: Unicode scalar order of the NFC forms (so "Z" <
     * "a" < "é" < U+FF5E < U+1F642, unlike UTF-16 order).
     */
    val stringOrder: Comparator<String> = Comparator { a, b ->
        if (a.all { it.code < 0x80 } && b.all { it.code < 0x80 }) {
            a.compareTo(b)
        } else {
            compareCodePoints(Normalizer.normalize(a, Normalizer.Form.NFC), Normalizer.normalize(b, Normalizer.Form.NFC))
        }
    }

    private fun compareCodePoints(a: String, b: String): Int {
        var i = 0
        var j = 0
        while (i < a.length && j < b.length) {
            val ca = a.codePointAt(i)
            val cb = b.codePointAt(j)
            if (ca != cb) return ca.compareTo(cb)
            i += Character.charCount(ca)
            j += Character.charCount(cb)
        }
        return (a.length - i).compareTo(b.length - j)
    }

    /**
     * Foundation's `CharacterSet.whitespacesAndNewlines`: general category
     * Z*, U+0009 to U+000D and U+0085.
     */
    fun isWhitespaceOrNewline(c: Char): Boolean {
        if (c == '\t' || c in '\n'..'\r' || c == '\u0085') return true
        return when (Character.getType(c).toByte()) {
            Character.SPACE_SEPARATOR, Character.LINE_SEPARATOR, Character.PARAGRAPH_SEPARATOR -> true
            else -> false
        }
    }

    /** `trimmingCharacters(in: .whitespacesAndNewlines)`. */
    fun trimmed(s: String): String = s.trim(::isWhitespaceOrNewline)

    /**
     * Swift's `lowercased()`: each scalar's full lowercase mapping, with no
     * context rules (a word-final capital sigma becomes σ, not ς).
     */
    fun lowercased(s: String): String {
        if (s.all { it.code < 0x80 }) return s.lowercase(Locale.ROOT)
        val out = StringBuilder(s.length)
        var i = 0
        while (i < s.length) {
            val cp = s.codePointAt(i)
            out.append(String(Character.toChars(cp)).lowercase(Locale.ROOT))
            i += Character.charCount(cp)
        }
        return out.toString()
    }

    /** Swift's `uppercased()` (no context rules apply to uppercasing). */
    fun uppercased(s: String): String = s.uppercase(Locale.ROOT)

    /**
     * Swift's `Int(string)`: an optional sign and ASCII digits only, in the
     * Int64 range; Kotlin's own parser also accepts non-ASCII digits.
     */
    fun parseInt(s: String): Long? {
        val body = if (s.startsWith("+") || s.startsWith("-")) s.substring(1) else s
        if (body.isEmpty() || !body.all { it in '0'..'9' }) return null
        return s.removePrefix("+").toLongOrNull()
    }

    /**
     * Swift's `UInt32(string, radix: 16)`: an optional sign, ASCII hex digits,
     * at most 0xFFFFFFFF; a minus sign only on zero.
     */
    fun parseHexUInt32(s: String): Long? {
        val negative = s.startsWith("-")
        val body = if (negative || s.startsWith("+")) s.substring(1) else s
        if (body.isEmpty() || !body.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }) return null
        var value = 0L
        for (c in body) {
            value = value * 16 + Character.digit(c, 16)
            if (value > 0xFFFF_FFFFL) return null
        }
        if (negative && value != 0L) return null
        return value
    }

    /**
     * Swift's `String(decoding: utf16Units, as: UTF16.self)`: an unpaired
     * surrogate (a cut through a pair) becomes U+FFFD.
     */
    fun repairingSurrogates(s: String): String {
        if (s.none { it.isSurrogate() }) return s
        val out = StringBuilder(s.length)
        var i = 0
        while (i < s.length) {
            val c = s[i]
            when {
                c.isHighSurrogate() && i + 1 < s.length && s[i + 1].isLowSurrogate() -> {
                    out.append(c).append(s[i + 1])
                    i += 2
                    continue
                }
                c.isSurrogate() -> out.append('�')
                else -> out.append(c)
            }
            i += 1
        }
        return out.toString()
    }
}
