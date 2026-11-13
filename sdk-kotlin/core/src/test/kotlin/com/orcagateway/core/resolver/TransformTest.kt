package com.orcagateway.core.resolver

import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import java.util.regex.Pattern
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * T1.3: every transform kind, table-tested against the Dart closures in
 * sdk/lib/src/state/value_resolver.dart (Dart's output in the comments where
 * it is not obvious). Where Dart throws, Kotlin yields null.
 */
class TransformTest {
    private class Row(val step: JsonValue, input: Any?, expected: Any?) {
        val input: JsonValue = j(input)
        val expected: JsonValue = j(expected)
        val kind: String get() = step["type"].stringValue ?: ""
    }

    private fun s(v: Any?): JsonValue = obj("type" to "static", "value" to v)

    private val state = props("n" to 3, "name" to "Amr", "suffix" to "!", "flag" to true)

    private val rows: List<Row> = listOf(
        // Numbers: int op int stays int, `/` is always double, `%` Euclidean.
        Row(obj("type" to "add", "by" to s(3)), 5, 8),
        Row(obj("type" to "add", "by" to s(0.5)), 5, 5.5),
        Row(obj("type" to "add", "by" to s(2)), null, 2), // (current ?? 0)
        Row(obj("type" to "add", "by" to obj("type" to "state", "key" to "n")), 1, 4),
        Row(obj("type" to "add", "by" to s("x")), 1, null), // Dart: TypeError
        Row(obj("type" to "add", "by" to s(1)), "1", null), // Dart: TypeError
        Row(obj("type" to "subtract", "by" to s(4)), 10, 6),
        Row(obj("type" to "subtract", "by" to s(1.5)), 1, -0.5),
        Row(obj("type" to "multiply", "by" to s(2)), 5, 10),
        Row(obj("type" to "multiply", "by" to s(2)), 49.99, 99.98),
        Row(obj("type" to "divide", "by" to s(2)), 6, 3.0),
        Row(obj("type" to "divide", "by" to s(0)), 1, Double.POSITIVE_INFINITY),
        Row(obj("type" to "modulo", "by" to s(3)), 7, 1),
        Row(obj("type" to "modulo", "by" to s(3)), -7, 2), // Euclidean
        Row(obj("type" to "modulo", "by" to s(-3)), -7, 2),
        Row(obj("type" to "modulo", "by" to s(2)), -7.5, 0.5),
        Row(obj("type" to "modulo", "by" to s(0)), 7, null), // Dart: IntegerDivisionByZero
        Row(obj("type" to "round"), 2.5, 3),
        Row(obj("type" to "round"), -2.5, -3),
        Row(obj("type" to "round"), 7, 7),
        Row(obj("type" to "round"), null, null), // Dart: TypeError
        Row(obj("type" to "floor"), -1.5, -2),
        Row(obj("type" to "ceil"), 1.2, 2),
        Row(obj("type" to "abs"), -4, 4),
        Row(obj("type" to "abs"), -4.5, 4.5),
        Row(obj("type" to "toFixed", "decimals" to 2), 99.98, "99.98"),
        Row(obj("type" to "toFixed", "decimals" to 2), 5, "5.00"),
        Row(obj("type" to "toFixed"), 1.005, "1.00"), // binary 1.00499…
        Row(obj("type" to "toFixed", "decimals" to 2), 0.125, "0.13"), // exact tie, away from zero
        Row(obj("type" to "toFixed", "decimals" to 0), 2.5, "3"),
        Row(obj("type" to "toFixed", "decimals" to 1), -0.25, "-0.3"),
        Row(obj("type" to "toFixed", "decimals" to 2), 9.999, "10.00"),
        Row(obj("type" to "toFixed", "decimals" to 21), 1, null), // Dart: RangeError

        // Strings: '$current' first, so null reads "null".
        Row(obj("type" to "toString"), 42, "42"),
        Row(obj("type" to "toString"), 4.0, "4.0"),
        Row(obj("type" to "toString"), 1e21, "1e+21"),
        Row(obj("type" to "toString"), 0.0000015, "0.0000015"),
        Row(obj("type" to "toString"), 1.5e-7, "1.5e-7"),
        Row(obj("type" to "toString"), null, "null"),
        Row(obj("type" to "toString"), arr(1, "a", true), "[1, a, true]"),
        Row(obj("type" to "toUpperCase"), "straße", "STRASSE"),
        Row(obj("type" to "toUpperCase"), null, "NULL"),
        Row(obj("type" to "toLowerCase"), "HeLLo", "hello"),
        Row(obj("type" to "trim"), "  padded \n", "padded"),
        Row(obj("type" to "template", "template" to "Total: \${{value}}"), "99.98", "Total: $99.98"),
        Row(obj("type" to "template", "template" to "[{{value}}|{{missing}}]"), "x", "[x|]"),
        Row(obj("type" to "template", "template" to "{{ value }}"), null, ""),
        Row(
            obj(
                "type" to "template", "template" to "{{greeting}}: {{value}}, {{name}}",
                "params" to obj("greeting" to s("Welcome"), "name" to obj("type" to "state", "key" to "name")),
            ),
            "Hi", "Welcome: Hi, Amr",
        ),
        Row(obj("type" to "template", "template" to "{{a.b}} {{1x}}"), "v", "{{a.b}} {{1x}}"), // not identifiers
        Row(obj("type" to "regex", "pattern" to "\\d+"), "abc123def", "123"),
        Row(obj("type" to "regex", "pattern" to "\\d+"), "abc", null),
        Row(
            obj(
                "type" to "regex", "pattern" to "(\\w+) (\\w+)", "replacement" to "$2 $1 ({{value}}){{suffix}}",
                "params" to obj("suffix" to obj("type" to "state", "key" to "suffix")),
            ),
            "hello world", "world hello (hello world)!",
        ),
        Row(obj("type" to "regex", "pattern" to "a", "flags" to "g", "replacement" to "b"), "a a a", "b b b"),
        Row(obj("type" to "regex", "pattern" to "a", "replacement" to "b"), "a a a", "b a a"),
        Row(obj("type" to "regex", "pattern" to "A", "flags" to "gi", "replacement" to "_"), "aAa", "___"),
        Row(obj("type" to "regex", "pattern" to "(a)", "replacement" to "$2$1"), "xa", "xa"), // $2 past groups
        Row(obj("type" to "regex", "pattern" to "("), "x", null), // invalid pattern
        Row(obj("type" to "regex", "pattern" to "a".repeat(201)), "a", null),
        Row(obj("type" to "substring", "start" to 1, "length" to 3), "abcdef", "bcd"),
        Row(obj("type" to "substring", "start" to 2), "abcdef", "cdef"),
        Row(obj("type" to "substring", "start" to 4, "length" to 5), "abcdef", null), // Dart: RangeError
        Row(obj("type" to "split", "separator" to ","), "a,b,,c", arr("a", "b", "", "c")),
        Row(obj("type" to "split", "separator" to ""), "abc", arr("a", "b", "c")),
        Row(obj("type" to "split", "separator" to ","), "", arr("")),
        Row(obj("type" to "join", "separator" to "-"), arr("a", 1, null), "a-1-null"),
        Row(obj("type" to "join", "separator" to "-"), "solo", "solo"),

        // Booleans
        Row(obj("type" to "not"), true, false),
        Row(obj("type" to "not"), "true", true), // only bool true is true
        Row(obj("type" to "not"), null, true),
        Row(obj("type" to "toBool"), 0, false),
        Row(obj("type" to "toBool"), 0.0, false),
        Row(obj("type" to "toBool"), "", false),
        Row(obj("type" to "toBool"), null, false),
        Row(obj("type" to "toBool"), "0", true),
        Row(obj("type" to "toBool"), arr(), true),
        Row(obj("type" to "toggle"), true, false),
        Row(obj("type" to "toggle"), null, true),
        Row(obj("type" to "toggle"), 1, null), // Dart: TypeError

        // Collections
        Row(obj("type" to "length"), arr(1, 2, 3), 3),
        Row(obj("type" to "length"), "héllo", 5),
        Row(obj("type" to "length"), "🙂", 2), // UTF-16 units, as Dart
        Row(obj("type" to "length"), 42, 0),
        Row(obj("type" to "at", "index" to 1), arr("a", "b"), "b"),
        Row(obj("type" to "at", "index" to 5), arr("a", "b"), null),
        Row(obj("type" to "at", "index" to -1), arr("a", "b"), null),
        Row(obj("type" to "first"), arr(7, 8), 7),
        Row(obj("type" to "first"), arr(), null),
        Row(obj("type" to "last"), arr(7, 8), 8),
        Row(obj("type" to "last"), "ab", null),
        Row(obj("type" to "map", "transform" to obj("type" to "add", "by" to s(1))), arr(1, 2), arr(2, 3)),
        Row(obj("type" to "map", "transform" to obj("type" to "toUpperCase")), arr("a", "b"), arr("A", "B")),
        Row(obj("type" to "map", "transform" to obj("type" to "nope")), arr(1), arr(1)),
        Row(obj("type" to "map", "transform" to obj("type" to "add", "by" to s(1))), "x", "x"),
        // filter: Dart evaluates the expression without binding the item.
        Row(obj("type" to "filter", "expr" to obj("op" to "eq", "left" to s(1), "right" to s(1))), arr(1, 2), arr(1, 2)),
        Row(obj("type" to "filter", "expr" to obj("op" to "eq", "left" to s(1), "right" to s(2))), arr(1, 2), arr()),
        Row(obj("type" to "contains", "value" to s(2)), arr(1, 2, 3), true),
        Row(obj("type" to "contains", "value" to s("ell")), "hello", true),
        Row(obj("type" to "contains", "value" to s(1)), 10, false),

        // Formatting (Flutter SDK: symbol + toStringAsFixed, no grouping)
        Row(obj("type" to "formatCurrency", "currency" to "USD"), 1234.5, "$1234.50"),
        Row(obj("type" to "formatCurrency", "currency" to "eur", "decimals" to 0), 3, "€3"),
        Row(obj("type" to "formatCurrency", "currency" to "SEK"), null, "SEK 0.00"),
        Row(obj("type" to "formatCurrency"), 2, "$2.00"),
        Row(obj("type" to "formatNumber", "decimals" to 1), 3.14159, "3.1"),
        Row(obj("type" to "formatNumber"), 3.5, "3.5"),
        Row(obj("type" to "formatNumber"), 7, "7"),
        Row(obj("type" to "formatNumber"), "x", null),
        Row(obj("type" to "formatDate", "format" to "yyyy-MM-dd HH:mm:ss"), "2024-03-05T07:08:09", "2024-03-05 07:08:09"),
        Row(obj("type" to "formatDate", "format" to "dd/MM/yyyy"), "2024-03-05T23:30:00Z", "05/03/2024"),
        Row(obj("type" to "formatDate", "format" to "HH:mm"), "2024-03-05T23:30:00+02:00", "21:30"),
        Row(obj("type" to "formatDate", "format" to "yyyy-MM-dd"), 0, "1970-01-01"),
        Row(obj("type" to "formatDate", "format" to "yyyy"), "not a date", "not a date"),
    )

    @Test
    fun transformTable() {
        val resolver = ValueResolver(state = state)
        val failures = mutableListOf<String>()
        for ((i, row) in rows.withIndex()) {
            val value = obj("type" to "transform", "input" to s(row.input), "by" to arr(row.step))
            val got = resolver.resolve(value)
            if (got != row.expected || got.isNumber != row.expected.isNumber) {
                failures += "row $i ${row.step}: ${row.kind} on ${DartFormat.string(row.input)}: got " +
                    "${DartFormat.string(got)}, expected ${DartFormat.string(row.expected)}"
            }
        }
        if (failures.isNotEmpty()) fail(failures.joinToString("\n"))
    }

    @Test
    fun intAndDoubleTypesFollowDart() {
        val r = ValueResolver(state = emptyMap())
        fun run(input: Any?, step: JsonValue): JsonValue =
            r.resolve(obj("type" to "transform", "input" to s(input), "by" to arr(step)))
        assertNotNull(run(5, obj("type" to "add", "by" to s(3))).intValue)
        assertTrue(run(6, obj("type" to "divide", "by" to s(2))) is JsonValue.Double, "6/2 is a double in Dart")
        assertNotNull(run(2.5, obj("type" to "round")).intValue)
        assertEquals("3.0", DartFormat.string(run(6, obj("type" to "divide", "by" to s(2)))))
    }

    @Test
    fun everyAdvertisedTransformHasRows() {
        val covered = rows.map { it.kind }.toSet()
        val advertised = GeneratedCapabilities.transformKinds.toSet()
        assertEquals(31, advertised.size)
        assertEquals(emptySet(), advertised - covered, "transforms without a table row")
        for (kind in advertised) {
            assertNotNull(TransformRegistry.defaults[kind], "$kind not registered")
        }
        assertNotNull(TransformRegistry.defaults["toggle"], "Dart SDK extra")
    }

    @Test
    fun pipelineSkipsUnknownStepsAndChains() {
        val r = ValueResolver(state = props("price" to 49.99, "quantity" to 2))
        val value = obj(
            "type" to "transform",
            "input" to obj("type" to "state", "key" to "price", "scope" to "page"),
            "by" to arr(
                obj("type" to "multiply", "by" to obj("type" to "state", "key" to "quantity", "scope" to "page")),
                obj("type" to "sparkle"),
                "not a step",
                obj("type" to "toFixed", "decimals" to 2),
                obj("type" to "template", "template" to "Total: \${{value}}"),
            ),
        )
        assertEquals(j("Total: $99.98"), r.resolve(value))
        // No `by` at all: the input comes back.
        assertEquals(j(1), r.resolve(obj("type" to "transform", "input" to s(1))))
    }

    @Test
    fun hostileInputsYieldNullInsteadOfThrowing() {
        // Each of these makes Dart throw; a crash here would kill the app.
        val r = ValueResolver(state = emptyMap())
        fun run(input: Any?, step: JsonValue): JsonValue =
            r.resolve(obj("type" to "transform", "input" to s(input), "by" to arr(step)))
        assertEquals(j(0), run(Long.MIN_VALUE, obj("type" to "modulo", "by" to s(-1))))
        assertEquals(j(0), run(Long.MIN_VALUE, obj("type" to "modulo", "by" to s(Long.MIN_VALUE))))
        assertEquals(j(Long.MAX_VALUE), run(-1, obj("type" to "modulo", "by" to s(Long.MIN_VALUE))))
        assertEquals(j(Long.MIN_VALUE), run(Long.MIN_VALUE, obj("type" to "abs"))) // wraps, as the Dart VM
        assertEquals(j(Long.MIN_VALUE), run(Long.MAX_VALUE, obj("type" to "add", "by" to s(1))))
        assertEquals(JsonValue.Null, run(arr("a"), obj("type" to "at", "index" to 1e300)))
        assertEquals(JsonValue.Null, run(arr("a"), obj("type" to "at", "index" to -1e300)))
        assertEquals(JsonValue.Null, run("abc", obj("type" to "substring", "start" to 1e300)))
        assertEquals(JsonValue.Null, run("abc", obj("type" to "substring", "start" to 1, "length" to Long.MAX_VALUE)))
        assertEquals(JsonValue.Null, run("abc", obj("type" to "substring", "start" to -1)))
        assertEquals(JsonValue.Null, run(1, obj("type" to "toFixed", "decimals" to 1e300)))
        assertEquals(JsonValue.Null, run(1, obj("type" to "formatNumber", "decimals" to -1e300)))
        assertEquals(j(Long.MAX_VALUE), run(1e300, obj("type" to "round")))
        assertEquals(JsonValue.Null, run(Double.NaN, obj("type" to "floor")))
        assertEquals(j(1e300), run(1e300, obj("type" to "formatDate", "format" to "yyyy")))
        assertEquals(
            j("#00000000"),
            ValueResolver(state = emptyMap(), animationProgress = Double.NaN)
                .resolve(obj("type" to "tween", "begin" to "#000000", "end" to "#FFFFFF")),
        )
    }

    // MARK: Dart's corners (row 23b.33; render fixtures 25-29)

    private fun run(input: Any?, step: JsonValue, state: Map<String, JsonValue> = emptyMap()): JsonValue =
        ValueResolver(state = state).resolve(obj("type" to "transform", "input" to s(input), "by" to arr(step)))

    private fun holds(expr: JsonValue, state: Map<String, JsonValue> = emptyMap()): Boolean =
        ValueResolver(state = state).evaluate(expr.objectValue ?: emptyMap())

    private fun wrap(pattern: String, flags: String = "g"): JsonValue =
        obj("type" to "regex", "pattern" to pattern, "flags" to flags, "replacement" to "[{{value}}]")

    @Test
    fun p1_containsAnEmptyNeedleIsTrue() {
        // Dart: 'abc'.contains('') and ''.contains('') are true.
        assertEquals(j(true), run("abc", obj("type" to "contains", "value" to s(""))))
        assertEquals(j(true), run("", obj("type" to "contains", "value" to s(""))))
        assertTrue(holds(obj("op" to "contains", "haystack" to s("abc"), "needle" to s(""))))
        assertTrue(holds(obj("op" to "contains", "haystack" to s(""), "needle" to s(""))))
    }

    @Test
    fun p2_stringsCompareByUtf16CodeUnits() {
        val composed = "é"
        val decomposed = "é"
        assertFalse(JsonValue.String(composed) == JsonValue.String(decomposed))
        assertTrue(holds(obj("op" to "neq", "left" to s(composed), "right" to s(decomposed))))
        assertFalse(holds(obj("op" to "eq", "left" to s(composed), "right" to s(decomposed))))
        assertFalse(holds(obj("op" to "contains", "haystack" to s(composed), "needle" to s(decomposed))))
        assertFalse(holds(obj("op" to "contains", "haystack" to s(arr(composed)), "needle" to s(decomposed))))
        assertFalse(holds(obj("op" to "startsWith", "str" to s(composed), "prefix" to s(decomposed))))
        assertEquals(j(false), run(composed, obj("type" to "contains", "value" to s(decomposed))))
        // A prefix that cuts a Character in two still starts the string, as in Dart.
        assertTrue(holds(obj("op" to "startsWith", "str" to s(decomposed), "prefix" to s("e"))))
        assertTrue(holds(obj("op" to "contains", "haystack" to s(decomposed), "needle" to s("́"))))
        // split(""): one string per UTF-16 code unit, a surrogate pair cut in two.
        assertEquals(arr("e", "́"), run(decomposed, obj("type" to "split", "separator" to "")))
        assertEquals(arr("\uD83D", "\uDE42"), run("🙂", obj("type" to "split", "separator" to "")))
        assertEquals(arr("a", "\r", "\n"), run("a\r\n", obj("type" to "split", "separator" to "")))
        assertEquals(arr(), run("", obj("type" to "split", "separator" to "")))
    }

    @Test
    fun p3_anEmptyRegexPatternMatchesEverywhere() {
        val global = obj("type" to "regex", "pattern" to "", "flags" to "g", "replacement" to "-")
        val first = obj("type" to "regex", "pattern" to "", "replacement" to "-")
        assertEquals(j("-a-b-"), run("ab", global))
        assertEquals(j("-ab"), run("ab", first))
        assertEquals(j("-"), run("", global))
        assertEquals(j(""), run("ab", obj("type" to "regex", "pattern" to ""))) // match-only: group 0
        // Dart: RegExp('').hasMatch(x) is true, for an empty x too.
        assertTrue(holds(obj("op" to "matches", "str" to s("abc"), "regex" to "")))
        assertTrue(holds(obj("op" to "matches", "str" to s(""), "regex" to "")))
    }

    @Test
    fun p4_regexDigitAndWordClassesAreAscii() {
        val digits = "٣ 4" // ARABIC-INDIC DIGIT THREE, space, 4
        val word = "café_1"
        assertEquals(j("٣ [4]"), run(digits, wrap("\\d+")))
        assertEquals(j("[٣ ]4"), run(digits, wrap("\\D+")))
        assertEquals(j("[caf]é[_1]"), run(word, wrap("\\w+")))
        assertEquals(j("caf[é]_1"), run(word, wrap("\\W+")))
        // Inside a character class, negated or not.
        assertEquals(j("[caf]é[_1]"), run(word, wrap("[\\w]+")))
        assertEquals(j("caf[é]_1"), run(word, wrap("[^\\w]+")))
        assertEquals(j("[٣ ]4"), run(digits, wrap("[^\\d]+")))
        assertEquals(j("٣[ 4]"), run(digits, wrap("[ \\d]+")))
        assertEquals(j("[٣ ]4"), run(digits, wrap("[x\\D]+")))
        assertEquals(j("[caf]é[_1]"), run(word, wrap("[^\\W]+")))
        // Case-insensitive: still ASCII.
        assertEquals(j("[CAF]É[_1]"), run("CAFÉ_1", wrap("\\w+", "gi")))
        // An escaped backslash before d is a backslash and a d.
        assertEquals(j("\\d"), run("x\\d1", obj("type" to "regex", "pattern" to "\\\\d")))
        assertEquals(j("[\\\\d]1"), run("\\\\d1", wrap("\\\\\\\\d")))
        // \s stays Unicode, as Dart's: a no-break space and an em space are whitespace.
        assertEquals(j("a[  ]b"), run("a  b", wrap("\\s+")))
        // The matches op too.
        assertFalse(holds(obj("op" to "matches", "str" to s("٣٤٥"), "regex" to "^\\d+$")))
        assertTrue(holds(obj("op" to "matches", "str" to s("345"), "regex" to "^\\d+$")))
        assertFalse(holds(obj("op" to "matches", "str" to s("é"), "regex" to "\\w")))
        assertTrue(holds(obj("op" to "matches", "str" to s("é"), "regex" to "\\W")))
    }

    @Test
    fun p5_aJsonDoubleInStateStaysADouble() {
        val state = JsonValue.parse("""{"d": 4.0, "i": 4, "e": 1e2, "big": 12345678901234567890}""").objectValue!!
        assertTrue(state.getValue("d") is JsonValue.Double, "4.0 is a double in Dart's jsonDecode")
        assertTrue(state.getValue("i") is JsonValue.Int)
        assertTrue(state.getValue("e") is JsonValue.Double, "1e2 is a double in Dart's jsonDecode")
        assertTrue(state.getValue("big") is JsonValue.Double, "an integer past Int64 is a double in Dart")
        assertTrue(JsonValue.parse("-0") is JsonValue.Int)
        fun toStringOf(key: String): JsonValue = ValueResolver(state = state).resolve(
            obj("type" to "transform", "input" to obj("type" to "state", "key" to key), "by" to arr(obj("type" to "toString"))),
        )
        assertEquals(j("4.0"), toStringOf("d"))
        assertEquals(j("4"), toStringOf("i"))
        assertEquals(j("100.0"), run(state.getValue("e"), obj("type" to "toString")))
        // 4 == 4.0 still, with equal hash codes.
        assertEquals(state.getValue("i"), state.getValue("d"))
        assertEquals(state.getValue("i").hashCode(), state.getValue("d").hashCode())
        assertTrue(holds(obj("op" to "eq", "left" to obj("type" to "state", "key" to "d"), "right" to s(4)), state))
    }

    @Test
    fun doubleToStringMatchesDart() {
        val cases = listOf(
            0.0 to "0.0", -0.0 to "-0.0", 1.0 to "1.0", -2.5 to "-2.5", 0.1 to "0.1", 100.0 to "100.0",
            1.2345678901234568e20 to "123456789012345680000.0", 1e21 to "1e+21", 1.5e300 to "1.5e+300",
            0.000001 to "0.000001", 0.0000001 to "1e-7", 1.25e-7 to "1.25e-7",
            Double.NaN to "NaN", Double.POSITIVE_INFINITY to "Infinity", Double.NEGATIVE_INFINITY to "-Infinity",
            4.9e-324 to "5e-324",
        )
        for ((d, expected) in cases) {
            assertEquals(expected, DartFormat.double(d), "$d")
        }
    }

    // MARK: Dart's ASCII word edges and case folding (R1, R2; render fixtures 31-32)
    // Expected values from the Dart VM. The four letters Unicode folds into
    // ASCII: ſ U+017F, K U+212A, ı U+0131, İ U+0130.

    private val four = "\u017F\u212A\u0131\u0130"

    private fun rep(pattern: String, flags: String, with: String): JsonValue =
        obj("type" to "regex", "pattern" to pattern, "flags" to flags, "replacement" to with)

    @Test
    fun r1_wordEdgesAreAsciiUnderEveryFlag() {
        for (flags in listOf("g", "gi", "gu", "gm", "gs", "giu")) {
            assertEquals(j("|caf|é |x|"), run("café x", rep("\\b", flags, "|")), flags)
            assertEquals(j("c|a|fé|"), run("café", rep("\\B", flags, "|")), flags)
        }
    }

    @Test
    fun r1_withIAndUTheLongSAndKelvinAreWordCharacters() {
        val sk = "\u017F\u212A"
        assertEquals(j("|$sk|"), run(sk, rep("\\b", "giu", "|")))
        assertEquals(j("\u017F|\u212A"), run(sk, rep("\\B", "giu", "|")))
        for (flags in listOf("g", "gi", "gu")) {
            assertEquals(j(sk), run(sk, rep("\\b", flags, "|")), flags)
            assertEquals(j("|\u017F|\u212A|"), run(sk, rep("\\B", flags, "|")), flags)
        }
        // ı and İ have no simple case folding: never word characters.
        assertEquals(j("\u0131\u0130"), run("\u0131\u0130", rep("\\b", "giu", "|")))
    }

    @Test
    fun r1_insideAClassBackslashBIsABackspace() {
        assertEquals(j("a-b"), run("a\u0008b", rep("[\\b]", "g", "-")))
        assertEquals(j("--b"), run("a\u0008b", rep("[a\\b]", "g", "-")))
        assertEquals(j("a\u0008-"), run("a\u0008b", rep("[^a\\b]", "g", "-")))
        assertEquals(j("a-b"), run("a\u0008b", rep("[\\b]", "gi", "-")))
    }

    @Test
    fun r1_theMatchesOpHasAsciiWordEdgesToo() {
        // No flags: a word edge falls between f and é.
        assertTrue(holds(obj("op" to "matches", "str" to s("café"), "regex" to "\\bcaf\\b")))
        assertFalse(holds(obj("op" to "matches", "str" to s("café"), "regex" to "caf\\B")))
        assertFalse(holds(obj("op" to "matches", "str" to s("\u017F\u212A"), "regex" to "\\b")))
    }

    @Test
    fun r2_withIAloneTheFourLettersMatchNoAsciiLetter() {
        assertEquals(j("$four##"), run("${four}sk", rep("[a-z]", "gi", "#")))
        assertEquals(j("$four##"), run("${four}SK", rep("[A-Z]", "gi", "#")))
        assertEquals(j("\u017F#"), run("\u017FS", rep("s", "gi", "#")))
        assertEquals(j("\u212A#"), run("\u212Ak", rep("k", "gi", "#")))
        assertEquals(j("\u0131\u0130##"), run("\u0131\u0130iI", rep("i", "gi", "#")))
        assertEquals(j("\u0131\u0130##"), run("\u0131\u0130iI", rep("I", "gi", "#")))
        assertEquals(j("$four#"), run("${four}x", rep("\\w", "gi", "#")))
        assertEquals(j("$four#"), run("${four}x", rep("[\\w]", "gi", "#")))
        assertEquals(j("####x"), run("${four}x", rep("\\W", "gi", "#")))
        assertEquals(j("####a"), run("${four}a", rep("[^a-z]", "gi", "#")))
        // Named in the pattern, each matches only itself.
        assertEquals(j("#sS"), run("\u017FsS", rep("\u017F", "gi", "#")))
        assertEquals(j("#kK"), run("\u212AkK", rep("\u212A", "gi", "#")))
        assertEquals(j("#iI\u0130"), run("\u0131iI\u0130", rep("\u0131", "gi", "#")))
        assertEquals(j("#iI"), run("\u0131iI", rep("[\u0131]", "gi", "#")))
        assertEquals(j("\u017F##"), run("\u017FsS", rep("[^\u017F]", "gi", "#")))
    }

    @Test
    fun r2_withIAndUOnlyTheLongSAndKelvinFoldIntoAscii() {
        assertEquals(j("##\u0131\u0130##"), run("${four}sk", rep("[a-z]", "giu", "#")))
        assertEquals(j("##\u0131\u0130##"), run("${four}SK", rep("[A-Z]", "giu", "#")))
        assertEquals(j("##"), run("\u017FS", rep("s", "giu", "#")))
        assertEquals(j("##"), run("\u212Ak", rep("k", "giu", "#")))
        assertEquals(j("\u0131\u0130##"), run("\u0131\u0130iI", rep("i", "giu", "#")))
        assertEquals(j("\u0131\u0130##"), run("\u0131\u0130iI", rep("I", "giu", "#")))
        assertEquals(j("##\u0131\u0130#"), run("${four}x", rep("\\w", "giu", "#")))
        assertEquals(j("##\u0131\u0130#"), run("${four}x", rep("[\\w]", "giu", "#")))
        assertEquals(j("\u017F\u212A##x"), run("${four}x", rep("\\W", "giu", "#")))
        assertEquals(j("\u017F\u212A##a"), run("${four}a", rep("[^a-z]", "giu", "#")))
        assertEquals(j("###"), run("\u017FsS", rep("\u017F", "giu", "#")))
        assertEquals(j("#iI\u0130"), run("\u0131iI\u0130", rep("\u0131", "giu", "#")))
        assertEquals(j("#iI"), run("\u0131iI", rep("[\u0131]", "giu", "#")))
        assertEquals(j("\u0131##"), run("\u0131iI", rep("[^\u0131]", "giu", "#")))
    }

    @Test
    fun r2_guard_otherLettersKeepFoldingUnderI() {
        for (flags in listOf("gi", "giu")) {
            assertEquals(j("##"), run("Éé", rep("é", flags, "#")), flags)
            assertEquals(j("##"), run("Éé", rep("[é]", flags, "#")), flags)
            assertEquals(j("###"), run("Σςσ", rep("σ", flags, "#")), flags)
            assertEquals(j("##"), run("Дд", rep("д", flags, "#")), flags)
            // A class that holds ı and İ itself still matches them; its negation does not.
            assertEquals(j("##"), run("\u0131\u0130", rep("[a-zà-ž]", flags, "#")), flags)
            assertEquals(j("\u0131\u0130a"), run("\u0131\u0130a", rep("[^a-zà-ž]", flags, "#")), flags)
            // Group names and the letters after \k and \c are not folded letters.
            assertEquals(j("x#"), run("x12", rep("(?<min>\\d+)", flags, "#")), flags)
            assertEquals(j("#x"), run("sSx", rep("(?<sik>s)\\k<sik>", flags, "#")), flags)
            assertEquals(j("a#b"), run("a\tb", rep("\\cI", flags, "#")), flags)
        }
    }

    /** A pattern under flags on an input, each match replaced by `#`, and Dart's output (null where Dart throws). */
    private class Rx(val pattern: String, val flags: String, val input: String, val expected: String?)

    private fun assertDart(rows: List<Rx>) {
        fun shown(s: String?): String =
            s?.map { if (it in ' '..'~') "$it" else "\\u%04X".format(it.code) }?.joinToString("") ?: "null"
        val failures = rows.mapNotNull { r ->
            val got = run(r.input, rep(r.pattern, r.flags, "#"))
            if (got == j(r.expected)) {
                null
            } else {
                "${shown(r.pattern)} /${r.flags} on ${shown(r.input)}: got ${shown(got.stringValue)}, expected ${shown(r.expected)}"
            }
        }
        if (failures.isNotEmpty()) fail(failures.joinToString("\n"))
    }

    @Test
    fun r2_aModifierGroupKeepsItsFlagLettersUnderI() {
        // The i, m and s of `(?ms-i:` are flags, not letters to fold. Each body
        // below matches the same whatever flags the group's letters follow.
        assertDart(
            listOf(
                Rx("(?i:a)", "gi", "aA", "##"),
                Rx("(?-i:a)", "gi", "aA", "#A"),
                Rx("(?-i:a)", "giu", "aA", "#A"),
                Rx("(?-i:a)(b)", "gi", "abAB", "#AB"),
                Rx("(?-i:\u00E9)", "gi", "\u00E9\u00C9", "#\u00C9"),
                Rx("(?-i:\u00E9)", "giu", "\u00E9\u00C9", "#\u00C9"),
                Rx("(?-i:[a-z])", "gi", "aZ", "#Z"),
                Rx("(?i:[a-z])", "gi", "aZ\u017F", "##\u017F"),
                Rx("(?i:[a-z])", "giu", "aZ\u017F", "###"),
                Rx("(?i:k)", "gi", "kK\u212A", "##\u212A"),
                Rx("(?i:k)", "giu", "kK\u212A", "###"),
                Rx("(?s:a.b)", "gi", "a\nb", "#"),
                Rx("(?s:.)", "giu", "\n", "#"),
                Rx("(?-s:a.)", "gis", "a\nab", "a\n#"),
                Rx("(?-s:a.)", "gisu", "a\nab", "a\n#"),
                Rx("(?i-s:a.)", "gis", "a\nAb", "a\n#"),
                Rx("(?ims:x)", "giu", "xX", "##"),
                Rx("(?ms-i:^a.)", "gi", "aA\nA\n", "#\nA\n"),
                Rx("(?i)s", "gi", "sS", null), // bare inline flags are not Dart syntax: a `(?` form it rejects
                Rx("(?i:s)", "g", "sS", "##"), // without i the group's i still folds s, to Dart's set
            ),
        )
    }

    @Test
    fun r2_aClassNamingOneOfTheFourFollowsDartUnderI() {
        // Swift's T6 rows of the same name, run through Kotlin.
        val (longS, kelvin, dotless, dotted) = listOf("\u017F", "\u212A", "\u0131", "\u0130")
        val iDot = "i\u0307" // what Unicode's full folding turns the dotted I into
        // Without `u` a class naming one of the four holds that letter alone, and its negation all else.
        val gi = listOf(
            Rx("[$longS]", "gi", "${longS}sS", "#sS"),
            Rx("[^$longS]", "gi", "${longS}sS", "$longS##"),
            Rx("[$kelvin]", "gi", "${kelvin}kK", "#kK"),
            Rx("[^$kelvin]", "gi", "${kelvin}kK", "$kelvin##"),
            Rx("[\\u017F]", "gi", "${longS}sS", "#sS"),
            Rx("[^\\u017F]", "gi", "${longS}sS", "$longS##"),
            Rx("[s$longS]", "gi", "${longS}sS", "###"),
            Rx("[^s$longS]", "gi", "${longS}sSx", "${longS}sS#"),
            Rx("[^s]", "gi", "${longS}sSx", "#sS#"),
            Rx("[$longS$kelvin]", "gi", "$longS${kelvin}sSkK", "##sSkK"),
            Rx("[$longS-\u0180]", "gi", "${longS}sS", "#sS"),
            Rx("[$dotless]", "gi", "${dotless}iI", "#iI"),
            Rx("[^$dotless]", "gi", "${dotless}iI", "$dotless##"),
            Rx("[i]", "gi", "$dotless${dotted}iI", "$dotless$dotted##"),
            Rx("[^i]", "gi", "$dotless${dotted}iI", "##iI"),
            Rx("[$dotted]", "gi", "$iDot$dotted", "$iDot#"),
            Rx("[^$dotted]", "gi", "${dotted}iI", "$dotted##"),
            Rx("[${dotted}a]", "gi", "$iDot${dotted}A", "$iDot##"),
        )
        // With `u` the class holds the letter's simple case folding: long s with s, Kelvin with k, the i's alone.
        val giu = listOf(
            Rx("[$longS]", "giu", "${longS}sS", "###"),
            Rx("[^$longS]", "giu", "${longS}sSx", "${longS}sS#"),
            Rx("[$kelvin]", "giu", "${kelvin}kK", "###"),
            Rx("[^$kelvin]", "giu", "${kelvin}kKx", "${kelvin}kK#"),
            Rx("[\u0100-$longS]", "giu", "${longS}sS", "###"),
            Rx("[$dotless]", "giu", "${dotless}iI", "#iI"),
            Rx("[$dotted]", "giu", "$iDot${dotted}iI", "$iDot#iI"),
            Rx("[^$dotted]", "giu", "${dotted}iI", "$dotted##"),
            Rx(dotted, "giu", "$iDot${dotted}iI", "$iDot#iI"),
            Rx(dotless, "giu", "${dotless}iI", "#iI"),
            Rx("i", "giu", "$dotted${dotless}iI", "$dotted$dotless##"),
            Rx("[i]", "giu", "$dotted${dotless}iI", "$dotted$dotless##"),
            Rx("[^i]", "giu", "$dotted${dotless}iI", "##iI"),
            Rx("\\p{Script=Latin}", "giu", "a\u0391B", "#\u0391#"),
            Rx("[\\p{Script=Latin}]", "giu", "a\u0391B", "#\u0391#"),
            Rx("\\p{Lowercase_Letter}", "giu", "aB1", "##1"),
        )
        // Guard: the flag letters of a modifier group are not letters to fold.
        val modifiers = listOf(
            Rx("(?i:a)", "gi", "aA", "##"),
            Rx("(?-i:a)", "gi", "aA", "#A"),
            Rx("(?-i:a)", "giu", "aA", "#A"),
            Rx("(?s:.)", "giu", "\n", "#"),
            Rx("(?ms-i:^a.)", "gi", "aA\nA\n", "#\nA\n"),
        )
        assertDart(gi + giu + modifiers)
    }

    // MARK: S14 — modifier scope and (? forms (row 23b.36)
    // Expected values from Dart 3.12.2. A modifier group's letters, classes and
    // word edges follow the group's `i`, not the pattern's.

    @Test
    fun m1_aModifierGroupScopesTheIFlag() {
        val (longS, kelvin, dotless, dotted) = listOf("\u017F", "\u212A", "\u0131", "\u0130")
        assertDart(
            listOf(
                Rx("(?-i:s)", "gi", "sS", "#S"),
                Rx("(?-i:s)", "giu", "sS", "#S"),
                Rx("(?i:s)", "g", "${longS}sS", "$longS##"),
                Rx("(?i:s)", "gu", "${longS}sS", "###"),
                Rx("(?i:k)", "g", "kK$kelvin", "##$kelvin"),
                Rx("(?-i:k)", "gi", "kK$kelvin", "#K$kelvin"),
                Rx("(?i:$longS)", "g", "sS$longS", "sS#"),
                Rx("(?-i:$longS)", "giu", "sS$longS", "sS#"),
                Rx("(?-i:S)", "gi", "sS", "s#"),
                Rx("(?i:S)", "g", "sS$longS", "##$longS"),
                Rx("(?-i:i)", "gi", "iI$dotless$dotted", "#I$dotless$dotted"),
                Rx("(?i:i)", "g", "iI$dotless$dotted", "##$dotless$dotted"),
                Rx("(?-i:[^s])", "gi", "sS${longS}x", "s###"),
                Rx("(?i:[^s])", "g", "sS${longS}x", "sS##"),
                Rx("(?i:\\W)", "gu", "sS$longS$kelvin!", "sS$longS$kelvin#"),
                Rx("(?-i:\\b)", "giu", "$longS a", "$longS #a#"),
            ),
        )
    }

    @Test
    fun m1_nestedGroupsFollowTheInnermostAndTheScopeEndsAtItsParen() {
        val longS = "\u017F"
        assertDart(
            listOf(
                Rx("(?i:(?-i:s))", "gi", "sS", "#S"),
                Rx("(?-i:(?i:s))", "g", "sS$longS", "##$longS"),
                Rx("(?i:a(?-i:s)S)", "g", "AsS ASs AsS", "# ASs #"),
                Rx("(?-i:a)s", "gi", "aS AS as", "# AS #"),
                Rx("(?-i:s)(s)", "gi", "sS SS", "# SS"),
                Rx("(?i:a)s", "g", "As AS a$longS", "# AS a$longS"),
                // Modifiers that leave `i` as it is still open a group.
                Rx("(?m:^a)", "gm", "b\na", "b\n#"),
                Rx("(?s:a.b)", "g", "a\nb", "#"),
                // A `)` in a class or escaped closes no group.
                Rx("(?-i:[)]s)", "gi", ")s )S", "# )S"),
                Rx("(?-i:\\)s)", "gi", ")s )S", "# )S"),
            ),
        )
    }

    @Test
    fun m2_parenQuestionFormsDartRejectsAreInvalid() {
        val rejected = listOf(
            "(?i)a", "(?im)a", "(?i)", "((?i)s)", "(?-:a)", "(?u:a)", "(?x:a)", "(?ii:a)", "(?i-i:a)",
            "(?-i-m:a)", "(?>a)", "(?#c)a", "(?P<n>a)", "(?'n'a)", "(?^:a)",
        )
        assertDart(rejected.flatMap { p -> listOf(Rx(p, "g", "aA", null), Rx(p, "gi", "aA", null)) })
        // The matches op compiles with no flags; Dart's is false on an invalid pattern.
        assertFalse(holds(obj("op" to "matches", "str" to s("a"), "regex" to "(?i)a")))
    }

    @Test
    fun m2_guard_parenQuestionFormsDartAcceptsStayValid() {
        assertDart(
            listOf(
                Rx("(?:a)", "g", "aA", "#A"),
                Rx("(?:a)", "gi", "aA", "##"),
                Rx("(?=a)", "g", "aA", "#aA"),
                Rx("(?=a)", "gi", "aA", "#a#A"),
                Rx("(?!a)", "g", "aA", "a#A#"),
                Rx("(?!a)", "gi", "aA", "aA#"),
                Rx("(?<=a)b", "g", "abAB", "a#AB"),
                Rx("(?<=a)b", "gi", "abAB", "a#A#"),
                Rx("(?<!a)b", "g", "abcb", "abc#"),
                Rx("(?<!a)b", "gi", "abcb", "abc#"),
                Rx("(?<n>a)\\k<n>", "g", "aa", "#"),
                Rx("(?<n>a)\\k<n>", "gi", "aa", "#"),
                Rx("(?ms-i:a)", "g", "aA", "#A"),
                Rx("(?ms-i:a)", "gi", "aA", "#A"),
                Rx("(?i-ms:a)", "g", "aA", "##"),
                Rx("(?i-ms:a)", "gi", "aA", "##"),
                Rx("(?i-:a)", "g", "aA", "##"),
                Rx("(?i-:a)", "gi", "aA", "##"),
            ),
        )
    }

    // MARK: S14 — Dart's fold table (row 23b.36)
    // Expected values from Dart 3.12.2. Under `i` the letters of
    // DartFoldTable match Dart's sets, not the engine's folding.

    @Test
    fun f1_lettersThatMatchOnlyThemselvesWithoutU() {
        val (angstrom, ohm, theta) = listOf("\u212B", "\u2126", "\u03F4")
        val thetas = "$theta \u03B8 \u0398 \u03D1"
        assertDart(
            listOf(
                Rx(angstrom, "gi", "$angstrom \u00E5 \u00C5", "# \u00E5 \u00C5"),
                Rx(angstrom, "giu", "$angstrom \u00E5 \u00C5", "# # #"),
                Rx(ohm, "gi", "$ohm \u03C9 \u03A9", "# \u03C9 \u03A9"),
                Rx(ohm, "giu", "$ohm \u03C9 \u03A9", "# # #"),
                Rx(theta, "gi", thetas, "# \u03B8 \u0398 \u03D1"),
                Rx(theta, "giu", thetas, "# # # #"),
                Rx("\u1E9E", "gi", "\u1E9E \u00DF", "# \u00DF"),
                Rx("\u1E9E", "giu", "\u1E9E \u00DF", "# #"),
                Rx("\u1F80", "gi", "\u1F80 \u1F88", "# \u1F88"),
                Rx("\u1F80", "giu", "\u1F80 \u1F88", "# #"),
                Rx("\u00E5", "gi", "\u00E5\u00C5$angstrom", "##$angstrom"),
                Rx("\u00E5", "giu", "\u00E5\u00C5$angstrom", "###"),
                Rx("[\u00E5]", "gi", "\u00E5\u00C5$angstrom", "##$angstrom"),
            ),
        )
    }

    @Test
    fun f1_aLetterWithAFullFoldingMatchesNoRunOfLetters() {
        val (sharpS, capitalSharpS, ff, st, longSt) = listOf("\u00DF", "\u1E9E", "\uFB00", "\uFB05", "\uFB06")
        assertDart(
            listOf(
                Rx(sharpS, "gi", "$sharpS ss SS $capitalSharpS", "# ss SS $capitalSharpS"),
                Rx(sharpS, "giu", "$sharpS ss SS $capitalSharpS", "# ss SS #"),
                Rx("[$sharpS]", "gi", "$sharpS ss $capitalSharpS", "# ss $capitalSharpS"),
                Rx("[$sharpS]", "giu", "$sharpS ss $capitalSharpS", "# ss #"),
                Rx(ff, "gi", "$ff ff FF", "# ff FF"),
                Rx("ff", "gi", "$ff ff FF", "$ff # #"),
                Rx("FF", "gi", "$ff ff FF", "$ff # #"),
                Rx("[$ff]", "gi", "$ff ff FF", "# ff FF"),
                Rx(st, "gi", "$st st $longSt", "# st $longSt"),
                Rx(st, "giu", "$st st $longSt", "# st #"),
                Rx("\u02BCn", "gi", "\u0149 \u02BCn", "\u0149 #"),
                Rx("\u03B1\u03B9", "gi", "\u1FB3 \u03B1\u03B9", "\u1FB3 #"),
                Rx("[a-z]+", "gi", "$ff ff \u017F", "$ff # \u017F"),
                Rx("[^a-z]", "gi", "$ff\u212Aa", "##a"),
            ),
        )
    }

    @Test
    fun f1_theTableFollowsTheModifierScope() {
        assertDart(
            listOf(
                Rx("(?i:\u00DF)", "g", "\u00DF ss \u1E9E", "# ss \u1E9E"),
                Rx("(?-i:\u00DF)", "giu", "\u00DF ss \u1E9E", "# ss \u1E9E"),
                Rx("(?i:ff)", "g", "\uFB00 ff FF", "\uFB00 # #"),
            ),
        )
    }

    @Test
    fun f1_aNegatedClassWhoseBodyStartsWithACaretKeepsItsMembers() {
        // In `[^^a]` the second `^` is a literal member, not a second negation.
        val longS = "ſ"
        assertDart(
            listOf(
                Rx("[^^a]", "gi", "^aAfFsS", "^aA####"),
                Rx("[^^a]", "giu", "^aAfFsS", "^aA####"),
                Rx("[^^a]", "g", "^aAfFsS", "^a#####"),
                Rx("[^^s]", "gi", "^sS$longS", "^sS#"),
                Rx("[^^s]", "giu", "^sS$longS", "^sS$longS"),
                Rx("[^a]", "gi", "aAfF", "aA##"),
                Rx("[\\^a]", "gi", "^aAf", "###f"),
            ),
        )
    }

    @Test
    fun f1_guard_lettersOutsideTheTableKeepTheEnginesFolding() {
        assertDart(
            listOf(
                Rx("\u00E9", "gi", "\u00E9\u00C9", "##"),
                Rx("\u03C3", "gi", "\u03C3\u03C2\u03A3", "###"),
            ),
        )
    }

    @Test
    fun f1_guard_hexEscapesAreReadWhole() {
        // Their digits a-f and A-F are table letters, not letters to fold.
        assertDart(
            listOf(
                Rx("\\x0a", "gi", "a\nb", "a#b"),
                Rx("\\x7F", "gi", "a\u007Fb", "a#b"),
                Rx("\\xff", "gi", "\u00FF\u0178", "##"),
                Rx("\\xFF", "giu", "\u00FF\u0178", "##"),
                Rx("\\u00ff", "gi", "\u00FF\u0178", "##"),
                Rx("\\u00FF", "giu", "\u00FF\u0178", "##"),
                Rx("\\x4a", "gi", "jJ\u01F0", "##\u01F0"),
                Rx("\\u004a", "gi", "jJ\u01F0", "##\u01F0"),
                Rx("\\xAF", "gi", "\u00AF", "#"),
                Rx("[\\x41-\\x46]+", "gi", "abcdefg", "#g"),
                Rx("[\\u0041-\\u0046]+", "gi", "abcdefg", "#g"),
                Rx("\\uFFFF", "gi", "\uFFFF", "#"),
                Rx("\\uffff", "gi", "\uFFFF", "#"),
                Rx("\\cA", "gi", "\u0001", "#"),
            ),
        )
    }

    @Test
    fun f1_everyTableLetterAloneAndInAClassMatchesDartsSet() {
        // Among the table's letters, each one's pattern matches its set as
        // Dart printed it, without `u` and with.
        val all = DartFoldTable.letters
        assertEquals(217, all.length)
        val rows = all.flatMap { c ->
            listOf(false, true).flatMap { unicode ->
                val set = DartFoldTable.set(c, unicode)!!
                val flags = if (unicode) "giu" else "gi"
                val expected = all.map { if (it in set) '#' else it }.joinToString("")
                listOf(Rx("$c", flags, all, expected), Rx("[$c]", flags, all, expected))
            }
        }
        assertDart(rows)
    }

    // MARK: S14 — escaped letters and \u{…} (row 23b.36)
    // Expected values from Dart 3.12.2. Under `i` an escape spelling a table
    // letter matches that letter's set; with `u`, `\u{H…}` is its code point.

    /** s S ſ k K K ß ẞ, the letters the escapes below spell. */
    private val spelled = "s S \u017F k K \u212A \u00DF \u1E9E"

    @Test
    fun e1_anEscapeSpellingATableLetterFoldsAsTheLetter() {
        val (longS, kelvin, sharpS, capitalSharpS, ff) = listOf("\u017F", "\u212A", "\u00DF", "\u1E9E", "\uFB00")
        val (dotless, dotted, angstrom) = listOf("\u0131", "\u0130", "\u212B")
        assertDart(
            listOf(
                Rx("\\x73", "gi", spelled, "# # $longS k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\x53", "gi", spelled, "# # $longS k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u0073", "gi", spelled, "# # $longS k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u017F", "gi", spelled, "s S # k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u017f", "giu", spelled, "# # # k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u212A", "gi", spelled, "s S $longS k K # $sharpS $capitalSharpS"),
                Rx("\\x6b", "gi", spelled, "s S $longS # # $kelvin $sharpS $capitalSharpS"),
                Rx("\\xdf", "gi", spelled, "s S $longS k K $kelvin # $capitalSharpS"),
                Rx("\\xdf", "giu", spelled, "s S $longS k K $kelvin # #"),
                Rx("\\u1E9E", "gi", spelled, "s S $longS k K $kelvin $sharpS #"),
                Rx("\\u1E9E", "giu", spelled, "s S $longS k K $kelvin # #"),
                Rx("\\uFB00", "gi", "$ff ff FF", "# ff FF"),
                Rx("\\x66\\x66", "gi", "$ff ff FF", "$ff # #"),
                Rx("\\x73\\u017F", "gi", "s$longS S$longS ss", "# # ss"),
                Rx("\\u0130", "gi", "i I $dotted $dotless", "i I # $dotless"),
                Rx("\\u0131", "gi", "i I $dotted $dotless", "i I $dotted #"),
                Rx("\\x41", "gi", "aA", "##"),
                Rx("\\u00C5", "gi", "\u00E5\u00C5$angstrom", "##$angstrom"),
            ),
        )
    }

    @Test
    fun e1_anEscapedLetterFollowsTheModifierScope() {
        assertDart(
            listOf(
                Rx("(?-i:\\x73)", "gi", "sS", "#S"),
                Rx("(?i:\\x73)", "g", "sS\u017F", "##\u017F"),
            ),
        )
    }

    @Test
    fun e1_withUABracedEscapeIsItsCodePoint() {
        val (longS, kelvin, sharpS, capitalSharpS) = listOf("\u017F", "\u212A", "\u00DF", "\u1E9E")
        val (grin, last, angstrom) = listOf("\uD83D\uDE00", "\uDBFF\uDFFF", "\u212B")
        assertDart(
            listOf(
                Rx("\\u{73}", "gu", spelled, "# S $longS k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u{73}", "giu", spelled, "# # # k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u{17F}", "gu", spelled, "s S # k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u{17F}", "giu", spelled, "# # # k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u{0000073}", "giu", spelled, "# # # k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u{10FFFF}", "gu", last, "#"),
                Rx("\\u{1F600}", "gu", "x$grin", "x#"),
                Rx("\\u{1F600}+", "gu", "$grin$grin", "#"),
                Rx("[\\u{1F600}a]", "gu", "a${grin}b", "##b"),
                Rx("\\u{61}", "gu", "aA", "#A"),
                Rx("\\u{61}", "giu", "aA", "##"),
                Rx("[\\u{17F}]", "giu", spelled, "# # # k K $kelvin $sharpS $capitalSharpS"),
                Rx("[\\u{17F}]", "gu", spelled, "s S # k K $kelvin $sharpS $capitalSharpS"),
                Rx("\\u{212B}", "giu", "\u00E5\u00C5$angstrom", "###"),
            ),
        )
    }

    @Test
    fun e1_withUABracedEscapeDartRejectsIsInvalid() {
        assertDart(
            listOf(
                Rx("\\u{110000}", "gu", "a", null),
                Rx("\\u{}", "gu", "a", null),
                Rx("\\u{g}", "gu", "a", null),
            ),
        )
    }

    @Test
    fun e1_guard_otherEscapesKeepTheEnginesReading() {
        // Expected values from Dart 3.12.2 too: a letter outside the table keeps
        // the engine's folding, ranges and quantifiers take the code point, and
        // an unclosed or out-of-range `\u{` is invalid in a class as well.
        val grin = "\uD83D\uDE00"
        assertDart(
            listOf(
                Rx("\\xe9", "gi", "\u00E9\u00C9", "##"),
                Rx("\\u00e9", "gi", "\u00E9\u00C9", "##"),
                Rx("\\u{e9}", "giu", "\u00E9\u00C9", "##"),
                Rx("\\u{e9}", "gu", "\u00E9\u00C9", "#\u00C9"),
                Rx("\\x73+", "gi", "sSs\u017F", "#\u017F"),
                Rx("(?-i:\\u{73})", "giu", "sS\u017F", "#S\u017F"),
                Rx("(?i:\\u{73})", "gu", "sS\u017F", "###"),
                Rx("[\\u{1F600}a]", "giu", "aA${grin}b", "###b"),
                Rx("[\\u{61}-\\u{63}]+", "gu", "abcd", "#d"),
                Rx("[\\u{61}-\\u{63}]+", "giu", "aBcD", "#D"),
                Rx("\\u{0}", "gu", "a\u0000b", "a#b"),
                Rx("\\u{0010FFFF}", "gu", "\uDBFF\uDFFF", "#"),
                Rx("\\u{73", "gu", "s", null),
                Rx("\\u{", "gu", "a", null),
                Rx("a\\", "gi", "a", null),
                Rx("[a\\", "giu", "a", null),
                Rx("[\\u{110000}]", "gu", "a", null),
                Rx("[\\u{}]", "gu", "a", null),
                Rx("[\\u{g}]", "gu", "a", null),
            ),
        )
    }

    // MARK: S14 — property names (row 23b.36)
    // Expected values from Dart 3.12.2. With `u`, `\p{…}` and `\P{…}` take
    // ECMAScript's names only, and on the JVM each reads the set it reads in Dart.

    /** Latin, Greek, Cyrillic and Han letters, digits, punctuation and spaces. */
    private val props = "aB1\u017F_ p{L} \u03B1 \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"

    @Test
    fun p1_namesDartRefusesAreInvalidWithU() {
        // The JVM's own names (`Is…`, `In…`, `java…`, POSIX, `blk=`), bare scripts, other
        // spellings or key cases, and `\p` without braces: a syntax error in Dart, in a class too.
        val rejected = listOf(
            "\\p{IsLatin}", "\\p{InGreek}", "\\p{IsAlphabetic}", "\\p{IsL}", "\\p{IsLu}", "\\p{IsWhite_Space}",
            "\\p{IsEmoji}", "\\p{Latin}", "\\p{Greek}", "\\p{Han}", "\\p{javaLowerCase}", "\\p{Javalowercase}",
            "\\p{javaMirrored}", "\\p{L&}", "\\p{L1}", "\\p{LD}", "\\p{all}", "\\p{Alnum}", "\\p{alpha}", "\\p{lower}",
            "\\p{XDigit}", "\\p{Punct}", "\\p{Space}", "\\p{script=Latin}", "\\p{script=latin}", "\\p{SC=Latn}",
            "\\p{Sc=Latn}", "\\p{general_category=Ll}", "\\p{GC=Ll}", "\\p{Gc=Ll}", "\\p{gc=Alphabetic}",
            "\\p{gc=Lowercase}", "\\p{blk=Greek}", "\\p{block=Greek}", "\\p{InBasic_Latin}", "\\p{Lowercase_letter}",
            "\\p{ll}", "\\p{Script}", "\\p{Script=}", "\\p{sc=}", "\\p{scx=}", "\\p{=Ll}", "\\p{ASCII=Y}",
            "\\p{Alphabetic=Yes}", "\\p{ L}", "\\p{L }", "\\p{}", "\\p{Changes_When_NFKC_Casefolded}", "\\p{Basic_Emoji}",
            "\\P{IsLatin}", "[\\p{IsLatin}]", "[^\\p{Han}]", "[\\P{InGreek}a]", "[a\\p{javaLowerCase}]",
            "\\pL", "\\PL", "\\p", "\\P", "[\\pL]", "\\p{L", "[\\p{L]", "[\\p{IsL]}", "\\p{\\u004C}",
        )
        assertDart(rejected.flatMap { p -> listOf(Rx(p, "gu", "a", null), Rx(p, "giu", "a", null)) })
    }

    @Test
    fun p1_generalCategoryLongNamesAndAliasesMatchAsDart() {
        val other = "a\u0001\u0378b" // a control and an unassigned code point
        assertDart(
            listOf(
                Rx("\\p{Lowercase_Letter}", "gu", props, "#B1#_ #{L} # \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{Letter}", "gu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("\\p{Cased_Letter}", "gu", props, "##1#_ #{#} # # \u4E2D \u0663 ! \u00A0 #"),
                Rx("\\p{Uppercase_Letter}", "gu", props, "a#1\u017F_ p{#} \u03B1 # \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{Titlecase_Letter}", "gu", props, "aB1\u017F_ p{L} \u03B1 \u0416 \u4E2D \u0663 ! \u00A0 #"),
                Rx("\\p{Other_Letter}", "gu", props, "aB1\u017F_ p{L} \u03B1 \u0416 # \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{Modifier_Letter}", "gu", "a\u02B0b", "a#b"),
                Rx("\\p{Decimal_Number}", "gu", props, "aB#\u017F_ p{L} \u03B1 \u0416 \u4E2D # ! \u00A0 \u01C5"),
                Rx("\\p{digit}", "gu", props, "aB#\u017F_ p{L} \u03B1 \u0416 \u4E2D # ! \u00A0 \u01C5"),
                Rx("\\p{Number}", "gu", props, "aB#\u017F_ p{L} \u03B1 \u0416 \u4E2D # ! \u00A0 \u01C5"),
                Rx("\\p{Punctuation}", "gu", props, "aB1\u017F# p#L# \u03B1 \u0416 \u4E2D \u0663 # \u00A0 \u01C5"),
                Rx("\\p{punct}", "gu", props, "aB1\u017F# p#L# \u03B1 \u0416 \u4E2D \u0663 # \u00A0 \u01C5"),
                Rx("\\p{Connector_Punctuation}", "gu", props, "aB1\u017F# p{L} \u03B1 \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{Space_Separator}", "gu", props, "aB1\u017F_#p{L}#\u03B1#\u0416#\u4E2D#\u0663#!###\u01C5"),
                Rx("\\p{Separator}", "gu", props, "aB1\u017F_#p{L}#\u03B1#\u0416#\u4E2D#\u0663#!###\u01C5"),
                Rx("\\p{cntrl}", "gu", "a\u0001b", "a#b"),
                Rx("\\p{Control}", "gu", "a\u0001b", "a#b"),
                Rx("\\p{Combining_Mark}", "gu", "e\u0301", "e#"),
                Rx("\\p{Mark}", "gu", "e\u0301", "e#"),
                Rx("\\p{Format}", "gu", "a\u200Db", "a#b"),
                Rx("\\p{Other}", "gu", other, "a##b"),
                Rx("\\p{Unassigned}", "gu", other, "a\u0001#b"),
                // After `General_Category=` or `gc=`.
                Rx("\\p{General_Category=Lowercase_Letter}", "gu", props, "#B1#_ #{L} # \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{General_Category=Ll}", "gu", props, "#B1#_ #{L} # \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{General_Category=L}", "gu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("\\p{gc=Ll}", "gu", props, "#B1#_ #{L} # \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{gc=L}", "gu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("\\p{gc=Cased_Letter}", "gu", props, "##1#_ #{#} # # \u4E2D \u0663 ! \u00A0 #"),
                Rx("\\p{gc=punct}", "gu", props, "aB1\u017F# p#L# \u03B1 \u0416 \u4E2D \u0663 # \u00A0 \u01C5"),
                Rx("\\p{gc=Other}", "gu", other, "a##b"),
                Rx("\\P{General_Category=Other}", "gu", other, "#\u0001\u0378#"),
                // Negated, in classes, quantified, and under `i`.
                Rx("\\P{Lowercase_Letter}", "gu", props, "a##\u017F##p####\u03B1############"),
                Rx("\\P{Letter}", "gu", props, "aB#\u017F##p#L##\u03B1#\u0416#\u4E2D#######\u01C5"),
                Rx("[^\\p{Lowercase_Letter}]", "gu", props, "a##\u017F##p####\u03B1############"),
                Rx("[\\p{Uppercase_Letter}\\d]", "gu", props, "a##\u017F_ p{#} \u03B1 # \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("[\\P{Letter}a]", "gu", props, "#B#\u017F##p#L##\u03B1#\u0416#\u4E2D#######\u01C5"),
                Rx("\\p{Lowercase_Letter}+", "gu", props, "#B1#_ #{L} # \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{Lowercase_Letter}", "giu", props, "##1#_ #{#} # # \u4E2D \u0663 ! \u00A0 #"),
                Rx("\\p{Letter}", "giu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("\\p{Uppercase_Letter}", "giu", props, "##1#_ #{#} # # \u4E2D \u0663 ! \u00A0 #"),
                Rx("\\p{Decimal_Number}", "giu", props, "aB#\u017F_ p{L} \u03B1 \u0416 \u4E2D # ! \u00A0 \u01C5"),
                Rx("\\p{Punctuation}", "giu", props, "aB1\u017F# p#L# \u03B1 \u0416 \u4E2D \u0663 # \u00A0 \u01C5"),
                Rx("\\p{General_Category=Lowercase_Letter}", "giu", props, "##1#_ #{#} # # \u4E2D \u0663 ! \u00A0 #"),
                Rx("\\p{gc=L}", "giu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("[\\p{Uppercase_Letter}\\d]", "giu", props, "####_ #{#} # # \u4E2D \u0663 ! \u00A0 #"),
                Rx("[\\p{Lowercase_Letter}]", "giu", props, "##1#_ #{#} # # \u4E2D \u0663 ! \u00A0 #"),
            ),
        )
    }

    @Test
    fun p1_binaryPropertiesMatchAsDart() {
        val spaces = "a\u0009b\u00A0c d\u2028e_"
        val cased = "aB\u2160\u01C5\u00AA" // Roman numeral one, a titlecase letter, the feminine ordinal
        // Hex_Digit is ASCII's and the fullwidth forms, not the Arabic-Indic three.
        val hex = "09afAFgG\u0663\uFF10\uFF21\uFF41\uFF47"
        val any = "a\u0378\uD83D\uDE00"
        val assigned = "a\u0378b\uFFFE"
        assertDart(
            listOf(
                Rx("\\p{Alphabetic}", "gu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("\\p{Alpha}", "gu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("\\p{Alphabetic}", "giu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("\\p{Alpha}", "giu", props, "##1#_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("\\p{White_Space}", "gu", spaces, "a#b#c#d#e_"),
                Rx("\\p{space}", "gu", spaces, "a#b#c#d#e_"),
                Rx("\\p{Uppercase}", "gu", cased, "a##\u01C5\u00AA"),
                Rx("\\p{Upper}", "gu", cased, "a##\u01C5\u00AA"),
                Rx("\\p{Lowercase}", "gu", cased, "#B\u2160\u01C5#"),
                Rx("\\p{Lower}", "gu", cased, "#B\u2160\u01C5#"),
                Rx("\\p{Hex_Digit}", "gu", hex, "######gG\u0663###\uFF47"),
                Rx("\\p{Hex}", "gu", hex, "######gG\u0663###\uFF47"),
                Rx("\\p{ASCII_Hex_Digit}", "gu", hex, "######gG\u0663\uFF10\uFF21\uFF41\uFF47"),
                Rx("\\p{AHex}", "gu", hex, "######gG\u0663\uFF10\uFF21\uFF41\uFF47"),
                Rx("\\P{Hex_Digit}", "gu", hex, "09afAF###\uFF10\uFF21\uFF41#"),
                Rx("[\\P{AHex}]", "gu", hex, "09afAF#######"),
                Rx("[^\\p{Hex}g]", "gu", hex, "09afAFg##\uFF10\uFF21\uFF41#"),
                Rx("\\p{Hex_Digit}", "giu", hex, "######gG\u0663###\uFF47"),
                Rx("\\p{Any}", "gu", any, "###"),
                Rx("\\P{Any}", "gu", any, any),
                Rx("[\\P{Any}a]", "gu", any, "#\u0378\uD83D\uDE00"),
                Rx("[^\\P{Any}]", "gu", any, "###"),
                Rx("\\p{Any}", "giu", any, "###"),
                Rx("\\p{Assigned}", "gu", assigned, "#\u0378#\uFFFE"),
                Rx("\\P{Assigned}", "gu", assigned, "a#b#"),
                Rx("[^\\p{Assigned}]", "gu", assigned, "a#b#"),
                Rx("\\p{Assigned}", "giu", assigned, "#\u0378#\uFFFE"),
                Rx("\\p{Ideographic}", "gu", "a\u4E2D\u3006\u3041", "a##\u3041"),
                Rx("\\p{Ideo}", "gu", "a\u4E2D\u3006\u3041", "a##\u3041"),
                Rx("\\p{Join_Control}", "gu", "a\u200C\u200Db", "a##b"),
                Rx("\\p{Join_C}", "gu", "a\u200C\u200Db", "a##b"),
                Rx("\\p{Noncharacter_Code_Point}", "gu", "a\uFFFE\uFDD0\uFFFD", "a##\uFFFD"),
                Rx("\\p{NChar}", "gu", "a\uFFFE\uFDD0\uFFFD", "a##\uFFFD"),
                Rx("\\p{Bidi_Mirrored}", "gu", "a(<)\u00AB\u2208-", "a#####-"),
                Rx("\\p{Bidi_M}", "gu", "a(<)\u00AB\u2208-", "a#####-"),
                Rx("[\\p{Alphabetic}\\d]", "gu", props, "####_ #{#} # # # \u0663 ! \u00A0 #"),
                Rx("[^\\p{White_Space}]", "gu", "a\u0009b\u00A0c", "#\u0009#\u00A0#"),
                Rx("[\\P{Lowercase}]", "gu", cased, "a###\u00AA"),
            ),
        )
    }

    @Test
    fun p1_emojiPropertiesMatchAsDartWhereTheRuntimeHasThem() {
        // java.util.regex has the emoji properties from JDK 21; on JDK 17 these stay invalid.
        val jvmHasThem = runCatching { Regex("\\p{IsEmoji}") }.isSuccess
        val e = "a1#\u263A\uD83D\uDE00\uD83D\uDC4D\uD83C\uDFFB" // a smiley, a grinning face, a thumbs-up, a skin tone
        fun dart(s: String) = s.takeIf { jvmHasThem }
        assertDart(
            listOf(
                Rx("\\p{Emoji}", "gu", e, dart("a######")),
                Rx("\\p{Emoji_Presentation}", "gu", e, dart("a1#\u263A###")),
                Rx("\\p{EPres}", "gu", e, dart("a1#\u263A###")),
                Rx("\\p{Emoji_Modifier}", "gu", e, dart("a1#\u263A\uD83D\uDE00\uD83D\uDC4D#")),
                Rx("\\p{EMod}", "gu", e, dart("a1#\u263A\uD83D\uDE00\uD83D\uDC4D#")),
                Rx("\\p{Emoji_Modifier_Base}", "gu", e, dart("a1#\u263A\uD83D\uDE00#\uD83C\uDFFB")),
                Rx("\\p{EBase}", "gu", e, dart("a1#\u263A\uD83D\uDE00#\uD83C\uDFFB")),
                Rx("\\p{Emoji_Component}", "gu", e, dart("a##\u263A\uD83D\uDE00\uD83D\uDC4D#")),
                Rx("\\p{EComp}", "gu", e, dart("a##\u263A\uD83D\uDE00\uD83D\uDC4D#")),
                Rx("\\p{Extended_Pictographic}", "gu", e, dart("a1####\uD83C\uDFFB")),
                Rx("\\p{ExtPict}", "gu", e, dart("a1####\uD83C\uDFFB")),
                Rx("\\P{Emoji}", "gu", e, dart("#1#\u263A\uD83D\uDE00\uD83D\uDC4D\uD83C\uDFFB")),
                Rx("[\\p{Emoji}a]", "gu", e, dart("#######")),
            ),
        )
    }

    @Test
    fun p1_guard_scriptKeysLeaveTheValueToTheEngine() {
        assertDart(
            listOf(
                Rx("\\p{Script=Latin}", "gu", props, "##1#_ #{#} \u03B1 \u0416 \u4E2D \u0663 ! \u00A0 #"),
                Rx("\\p{sc=Latn}", "gu", props, "##1#_ #{#} \u03B1 \u0416 \u4E2D \u0663 ! \u00A0 #"),
                Rx("\\p{Script=Greek}", "gu", props, "aB1\u017F_ p{L} # \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{sc=Grek}", "gu", props, "aB1\u017F_ p{L} # \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\P{Script=Latin}", "gu", props, "aB#\u017F##p#L##############\u01C5"),
                Rx("[\\p{sc=Grek}a]", "gu", props, "#B1\u017F_ p{L} # \u0416 \u4E2D \u0663 ! \u00A0 \u01C5"),
                Rx("\\p{Script=Latin}", "giu", props, "##1#_ #{#} \u03B1 \u0416 \u4E2D \u0663 ! \u00A0 #"),
            ),
        )
    }

    // MARK: S15 \u2014 quantifiers (row 23b.37)
    // Expected values from Dart 3.12.2. A quantifier repeats the atom before it:
    // after another quantifier (but for one lazy `?`), after an assertion, or
    // with nothing before it, Dart refuses the pattern, with `u` and without.

    /** Each pattern under `g` and `gu` on "aaa", where Dart throws. */
    private fun refused(vararg patterns: String): List<Rx> =
        patterns.flatMap { p -> listOf(Rx(p, "g", "aaa", null), Rx(p, "gu", "aaa", null)) }

    @Test
    fun a3_aQuantifierOnAQuantifierIsInvalid() {
        assertDart(
            refused("a++", "a*+", "a?+", "a{1,2}+", "a{1}{2}", "a**", "a{2,1}", "a+?+", "a+??") +
                listOf(
                    Rx("a{1,}+", "g", "aaa", null),
                    Rx("(?=a)**", "g", "aaa", null),
                    Rx("a{1,2}+", "gi", "aaa", null),
                    Rx("s++", "gi", "sss", null),
                ),
        )
    }

    @Test
    fun a3_aQuantifierOnAnAssertionIsInvalid() {
        assertDart(
            refused("^*", "$+", "\\b*", "\\B+", "(?<=a)*", "(?<!a)+", "(?<=a){2}", "\\b{2}", "^?", "$*") +
                listOf(
                    Rx("(?<!a)?", "g", "aaa", null),
                    Rx("\\b+a", "g", "aaa", null),
                    Rx("\\B+", "gi", "aaa", null),
                ),
        )
    }

    @Test
    fun a3_aQuantifierWithNothingToRepeatIsInvalid() {
        assertDart(
            refused("{3}", "*a", "+a", "?a") +
                listOf("(?:*a)", "(*a)", "a|*b", "(?<n>*a)").map { Rx(it, "g", "aaa", null) },
        )
    }

    @Test
    fun a3_aLazyQuestionMarkAndAQuantifiedGroupStayValid() {
        assertDart(
            listOf(
                Rx("a+?", "g", "aaa", "###"),
                Rx("a??", "g", "aaa", "#a#a#a#"),
                Rx("a{1,2}?", "g", "aaa", "###"),
                Rx("a{0}?", "g", "aaa", "#a#a#a#"),
                Rx("a{1,}?", "g", "aaa", "###"),
                Rx("(?:)*", "g", "aaa", "#a#a#a#"),
                Rx("()+", "g", "aaa", "#a#a#a#"),
            ),
        )
    }

    @Test
    fun a3_guard_quantifiersAndAssertionsDartAcceptsKeepTheirMatches() {
        assertDart(
            listOf(
                Rx("a{1,2}", "g", "aaa", "##"),
                Rx("a{2}", "g", "aaa", "#a"),
                Rx("(a)+", "g", "aaa", "#"),
                Rx("(?:ab)*", "g", "abab", "##"),
                Rx("(?:a|)*", "g", "aaa", "##"),
                Rx("(?i:a)+", "gi", "aAa", "#"),
                Rx("[a]+", "g", "aaa", "#"),
                Rx("\\d+", "g", "a12", "a#"),
                Rx("\\b", "g", "a b", "#a# #b#"),
                Rx("^a", "g", "aaa", "#aa"),
                Rx("a$", "g", "aaa", "aa#"),
                Rx("(?<=a)a+", "g", "aaa", "a#"),
                Rx("(?=a)a", "g", "aaa", "###"),
                // A quantified lookahead without `u` is Annex B's, and the engine already reads it so.
                Rx("(?=a)*", "g", "ab", "#a#b#"),
            ),
        )
    }

    // MARK: S15 — Annex B without u (row 23b.37)
    // Expected values from Dart 3.12.2. Without `u` Dart reads Annex B's
    // lenient grammar: an escape with no meaning is its character, a brace
    // that starts no quantifier is a literal, a decimal escape past the group
    // count is a legacy octal one. Classes follow ECMAScript in both modes.

    @Test
    fun a1_anEscapedLetterWithNoMeaningIsThatLetterWithoutU() {
        assertDart(
            listOf(
                Rx("\\A", "g", "aA", "a#"),
                Rx("\\Qa\\E", "g", "QaE a", "# a"),
                Rx("\\z", "g", "z", "#"),
                Rx("\\h", "g", "h", "#"),
                Rx("\\e", "g", "e", "#"),
                Rx("\\a", "g", "a", "#"),
                Rx("\\K", "g", "kK\u212A", "k#\u212A"),
                Rx("\\K", "gi", "kK\u212A", "##\u212A"),
                Rx("\\K+", "gi", "kKkK\u212A", "#\u212A"),
                Rx("\\o{2}", "g", "oo", "#"),
                Rx("\\N{LATIN SMALL LETTER A}", "g", "N{LATIN SMALL LETTER A}", "#"),
                // \p and \P are letters, and what follows them is ordinary text.
                Rx("\\p{L}", "g", "p{L} a", "# a"),
                Rx("\\P{L}", "g", "P{L} a", "# a"),
                Rx("\\p{L}", "gi", "p{L} P{l}", "# #"),
                // \k is the letter k when the pattern has no named group.
                Rx("\\k", "g", "k", "#"),
                Rx("\\k<a>", "g", "k<a>", "#"),
                Rx("\\ka", "g", "ka", "#"),
            ),
        )
    }

    @Test
    fun a1_aBraceThatStartsNoQuantifierIsALiteralWithoutU() {
        assertDart(
            listOf(
                Rx("{", "g", "{x}", "#x}"),
                Rx("}", "g", "{x}", "{x#"),
                Rx("x{,3}", "g", "x{,3} x", "# x"),
                Rx("a{1", "g", "a{1 a", "# a"),
                Rx("a{1,", "g", "a{1, a", "# a"),
                Rx("]", "g", "a]", "a#"),
                Rx("p{L}", "g", "p{L}", "#"),
                Rx("x{1}{", "g", "x{", "#"),
                Rx("{*", "g", "{{a", "##a#"),
                Rx("]+", "g", "]]a", "#a"),
                Rx("{1,2}", "g", "a", null),
            ),
        )
    }

    @Test
    fun a1_hexAndUnicodeEscapesWithoutTheirDigitsAreLettersWithoutU() {
        assertDart(
            listOf(
                Rx("\\u61", "g", "u61 a", "# a"),
                Rx("\\u{3}", "g", "uuu u", "# u"),
                Rx("\\u{61}", "g", "u{61} a", "u{61} a"),
                Rx("\\x6", "g", "x6", "#"),
                Rx("\\x{2}", "g", "xx x", "# x"),
                Rx("\\xG1", "g", "xG1", "#"),
                Rx("\\x*", "g", "xa", "##a#"),
                Rx("[\\x6]", "g", "x6", "##"),
                Rx("[\\u{61}]", "g", "u{61}", "#####"),
            ),
        )
    }

    @Test
    fun a1_aControlEscapeWithoutALetterIsABackslashWithoutU() {
        assertDart(
            listOf(
                Rx("\\c1", "g", "\\c1", "#"),
                Rx("\\c", "g", "\\c", "#"),
                Rx("\\c!", "g", "\\c!", "#"),
                Rx("\\c*", "g", "\\ccc \\", "# #"),
                Rx("\\c1", "gi", "\\C1 \\c1", "# #"),
                Rx("\\ca", "g", "\u0001a!", "#a!"),
                // In a class \c and a digit or _ is the control character, anything else the members \ and c.
                Rx("[\\c1]", "g", "\u0011 c 1", "# c 1"),
                Rx("[\\c_]", "g", "\u001F_c", "#_c"),
                Rx("[\\c]", "g", "\\c", "##"),
                Rx("[\\c-e]", "g", "\\cde-", "####-"),
                Rx("[\\ca]", "g", "\u0001a!", "#a!"),
            ),
        )
    }

    @Test
    fun a1_aDecimalEscapePastTheGroupCountIsLegacyOctalWithoutU() {
        assertDart(
            listOf(
                Rx("\\0", "g", "a\u0000", "a#"),
                Rx("\\01", "g", "\u0001 1", "# 1"),
                Rx("\\377", "g", "\u00FF", "#"),
                Rx("\\400", "g", " 0", "#"),
                Rx("\\8", "g", "8", "#"),
                Rx("\\18", "g", "\u00018", "#"),
                Rx("\\08", "g", "\u00008", "#"),
                Rx("\\012", "g", "\n", "#"),
                Rx("\\163", "gi", "sS\u017F", "##\u017F"),
                Rx("(a)\\8", "g", "a8", "#"),
                Rx("(a)\\2", "g", "a\u0002", "#"),
                Rx("(a)\\10", "g", "a\u0008", "#"),
                Rx("(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\\10", "g", "abcdefghijj abcdefghija0", "# abcdefghija0"),
                // Groups are counted over the whole pattern, not in a class or after an escaped (.
                Rx("[(]\\1", "g", "(\u0001", "#"),
                Rx("\\(\\1", "g", "(\u0001", "#"),
                Rx("(?:a)\\1", "g", "a\u0001", "#"),
                Rx("(?<n>a)\\1", "g", "aa", "#"),
                Rx("[^]](a)\\1", "g", "x]aa", "#"),
            ),
        )
    }

    @Test
    fun a2_backslashZeroIsNulWithU() {
        assertDart(
            listOf(
                Rx("\\0", "gu", "a\u0000", "a#"),
                Rx("[\\0]", "gu", "a\u0000", "a#"),
            ),
        )
    }

    @Test
    fun a1_aClassEndsAtItsFirstBracketAndHoldsNoSetSyntax() {
        assertDart(
            listOf(
                Rx("[]", "g", "ab", "ab"),
                Rx("[^]", "g", "a\nb", "###"),
                Rx("[]a]", "g", "a]", "a]"),
                Rx("[^]a]", "g", "a]", "a]"),
                Rx("[]*", "g", "ab", "#a#b#"),
                Rx("[^]", "gi", "aB", "##"),
                Rx("[[:alpha:]]", "g", "a:] a", "a# a"),
                Rx("[a&&b]", "g", "a&b", "###"),
                Rx("[a~~b]", "g", "~", "#"),
                Rx("[a-z&&[aeiou]]", "g", "a&[]", "a&#"),
                Rx("[a--b]", "g", "a-b", null),
                Rx("[--0]", "g", "-./0a", "####a"),
                Rx("[a-z-0]", "g", "a-0z1", "####1"),
                Rx("[\\x5a-\\x41]", "g", "A", null),
                Rx("[a-\\c]", "g", "a", null),
            ),
        )
    }

    @Test
    fun a1_classEscapesFollowAnnexBWithoutU() {
        assertDart(
            listOf(
                // A range with a class escape on either side is a union.
                Rx("[a-\\d]", "g", "a-1b", "###b"),
                Rx("[\\d-z]", "g", "1-z y", "### y"),
                Rx("[\\w-\\d]", "g", "a-1%", "###%"),
                Rx("[a-\\s]", "g", "a- b", "###b"),
                Rx("[a-\\d]", "gi", "A-1b", "###b"),
                // An identity escape is the character, a decimal one octal.
                Rx("[\\B]", "g", "Bb", "#b"),
                Rx("[\\1]", "g", "\u0001 1", "# 1"),
                Rx("[\\8]", "g", "8", "#"),
                Rx("[\\k]", "g", "k", "#"),
                Rx("[\\a]", "g", "a", "#"),
                Rx("[\\K]", "gi", "kK\u212A", "##\u212A"),
                Rx("[\\18]", "g", "\u00018", "##"),
                Rx("[\\0-\\x1f]", "g", "\u0000\u001F ", "## "),
                Rx("[\\p{L}-z]", "g", "a", null),
                Rx("[a-\\p{L}]", "g", "a-p{L}b", "#-#####"),
            ),
        )
    }

    @Test
    fun a1_guard_aLookaheadMayBeQuantifiedWithoutU() {
        assertDart(
            listOf(
                Rx("(?=a)*", "g", "ab", "#a#b#"),
                Rx("(?!a)+", "g", "ab", "a#b#"),
                Rx("(?=a){2}", "g", "ab", "#ab"),
            ),
        )
    }

    // MARK: S15 — strict u (row 23b.37)
    // Expected values from Dart 3.12.2. With `u` Dart reads ECMAScript's strict
    // grammar and refuses what Annex B lets through: an identity escape of
    // anything but a syntax character, a lone brace or bracket, a decimal
    // escape past the group count, `\c`, `\x` or `\u` without their argument,
    // a class range on a class escape, a quantified lookahead, `\k` naming no
    // group. In both modes `\v` is U+000B alone and `\s` ECMAScript's set.

    /** The A2 rows' input. */
    private val strictInput = "a-%_{}]"

    /** Each pattern under [flags] on [strictInput], where Dart throws. */
    private fun refusedWithU(flags: String, vararg patterns: String): List<Rx> = patterns.map { Rx(it, flags, strictInput, null) }

    @Test
    fun a2_anIdentityEscapeOfAnythingButASyntaxCharacterIsInvalidWithU() {
        assertDart(
            refusedWithU(
                "gu", "\\A", "\\z", "\\-", "\\%", "\\_", "\\a", "\\V", "\\h", "\\H", "\\R", "\\G", "\\Z", "\\Q", "\\X",
                "\\e", "\\N", "\\ ", "\\,", "\\é", "a\\", "[\\_]", "[\\a]", "[\\B]", "[\\k]", "[\\ ]", "[\\é]",
            ) + refusedWithU("giu", "\\A", "\\-", "\\a", "[\\_]", "[\\B]"),
        )
    }

    @Test
    fun a2_aLoneBraceOrBracketIsInvalidWithU() {
        assertDart(
            refusedWithU("gu", "{", "}", "]", "a{1", "a{1,", "x{,3}", "[]a]", "[[a]]") +
                refusedWithU("giu", "{", "}", "]", "a{1"),
        )
    }

    @Test
    fun a2_aDecimalEscapePastTheGroupCountIsInvalidWithU() {
        assertDart(
            refusedWithU(
                "gu", "\\00", "\\01", "\\1", "\\8", "\\9", "\\10", "(a)\\2", "(a)\\8", "(a)\\10", "(a)\\01",
                "[\\00]", "[\\01]", "[\\1]", "[\\8]", "[\\9]",
            ) + refusedWithU("giu", "\\8", "\\00"),
        )
    }

    @Test
    fun a2_controlHexAndUnicodeEscapesWithoutTheirArgumentAreInvalidWithU() {
        assertDart(
            refusedWithU("gu", "\\c", "\\c1", "\\c!", "[\\c_]", "[\\c1]", "[\\c]", "\\x", "\\x6", "\\x{73}", "\\u", "\\u61", "\\u{", "\\u{}") +
                refusedWithU("giu", "\\c1", "[\\c_]") +
                listOf(Rx("[\\c_]", "gu", "\u001F", null)),
        )
    }

    @Test
    fun a2_aClassRangeOnAClassEscapeOrAPropertyIsInvalidWithU() {
        assertDart(
            refusedWithU(
                "gu", "[a-\\d]", "[\\d-z]", "[\\w-a]", "[\\p{L}-z]", "[a-\\p{L}]", "[\\s-a]", "[\\w-\\d]", "[a-\\s]",
                "[\\D-z]", "[a-\\P{L}]", "[\\S-z]", "[\\W-a]",
            ) + refusedWithU("giu", "[a-\\d]"),
        )
    }

    @Test
    fun a2_aQuantifiedLookaheadIsInvalidWithU() {
        assertDart(refusedWithU("gu", "(?=a)*", "(?!a)?", "(?=a){2}", "(?!a)+", "(?=a)?") + refusedWithU("giu", "(?=a)*"))
    }

    @Test
    fun a2_backslashKNamingNoGroupIsInvalidWithU() {
        assertDart(
            refusedWithU("gu", "\\k", "\\k<a>", "\\ka", "(?<a>x)\\k<b>", "(?<a>x)\\k", "(?<a>x)\\k<a", "(?<a>x)[\\k]") +
                refusedWithU("giu", "\\k"),
        )
    }

    @Test
    fun a2_theRewriterItselfRefusesWhatDartRefusesWithU() {
        // Not the engine: the desktop JVM reads `\A`, `\x{73}` or `[\c_]`, and which of the rest it refuses is its own business.
        val refused = listOf(
            "\\A", "\\z", "\\-", "\\%", "\\_", "\\a", "\\V", "\\h", "\\H", "\\R", "{", "}", "]", "a{1", "x{,3}", "[]a]",
            "\\00", "\\01", "\\8", "(a)\\2", "(a)\\10", "\\c1", "\\c", "[\\c_]", "\\x6", "\\x{73}", "\\u61", "\\u{}",
            "[a-\\d]", "[\\d-z]", "[\\p{L}-z]", "[a-\\p{L}]", "[\\w-a]", "(?=a)*", "(?!a)?", "\\k", "\\k<a>", "(?<a>x)\\k<b>",
            "[\\k]", "[\\B]", "[\\a]", "[\\_]", "\\p", "\\pL", "[\\8]", "[\\1]", "[\\00]",
        )
        assertEquals(emptyList(), refused.filter { RegexSupport.asciiClasses(it, unicode = true) != null })
    }

    @Test
    fun a2_guard_syntaxAndCharacterEscapesStayValidWithU() {
        val syntax = ".*+?()[]{}|\\/^$-"
        assertDart(
            listOf(
                Rx("\\/", "gu", "a/", "a#"),
                Rx("\\^", "gu", "^", "#"),
                Rx("[\\-]", "gu", "-a", "#a"),
                Rx("\\$", "gu", "$", "#"),
                Rx("[\\^]", "gu", "^", "#"),
                Rx("[\\/]", "gu", "/", "#"),
                Rx("\\0", "gu", "a\u0000", "a#"),
                Rx("[\\0]", "gu", "a\u0000", "a#"),
                Rx("[\\b]", "gu", "\bb", "#b"),
                Rx("\\cA", "gu", "\u0001", "#"),
                Rx("\\cA", "giu", "\u0001", "#"),
                Rx("\\0a", "gu", "\u0000a", "#"),
                Rx("\\ca", "gu", "\u0001a", "#a"),
                Rx("\\cZ", "gu", "\u001AZ", "#Z"),
                Rx("[\\cZ]", "gu", "\u001AZ", "#Z"),
                Rx("\\f\\n\\r\\t", "gu", "a\u000C\n\r\tb", "a#b"),
                Rx("\\x41", "gu", "aA", "a#"),
                Rx("\\u0041", "gu", "aA", "a#"),
                Rx("[\\x41-\\x43]", "gu", "ABCD", "###D"),
                Rx("[\\-a]", "gu", "-ab", "##b"),
                Rx("[a\\-z]", "gu", "a-mz", "##m#"),
                Rx("\\.", "gu", syntax, "#*+?()[]{}|\\/^$-"),
                Rx("\\*", "gu", syntax, ".#+?()[]{}|\\/^$-"),
                Rx("\\+", "gu", syntax, ".*#?()[]{}|\\/^$-"),
                Rx("\\?", "gu", syntax, ".*+#()[]{}|\\/^$-"),
                Rx("\\(", "gu", syntax, ".*+?#)[]{}|\\/^$-"),
                Rx("\\)", "gu", syntax, ".*+?(#[]{}|\\/^$-"),
                Rx("\\[", "gu", syntax, ".*+?()#]{}|\\/^$-"),
                Rx("\\]", "gu", syntax, ".*+?()[#{}|\\/^$-"),
                Rx("\\{", "gu", syntax, ".*+?()[]#}|\\/^$-"),
                Rx("\\}", "gu", syntax, ".*+?()[]{#|\\/^$-"),
                Rx("\\|", "gu", syntax, ".*+?()[]{}#\\/^$-"),
                Rx("\\\\", "gu", syntax, ".*+?()[]{}|#/^$-"),
                Rx("[\\]]", "gu", syntax, ".*+?()[#{}|\\/^$-"),
                Rx("[\\[]", "gu", syntax, ".*+?()#]{}|\\/^$-"),
                Rx("[\\{]", "gu", syntax, ".*+?()[]#}|\\/^$-"),
                Rx("[\\}]", "gu", syntax, ".*+?()[]{#|\\/^$-"),
                Rx("[\\.]", "gu", syntax, "#*+?()[]{}|\\/^$-"),
                Rx("[\\$]", "gu", syntax, ".*+?()[]{}|\\/^#-"),
                Rx("[\\|]", "gu", syntax, ".*+?()[]{}#\\/^$-"),
                Rx("[\\\\]", "gu", syntax, ".*+?()[]{}|#/^$-"),
                // A backreference to a group that exists, by number or by name.
                Rx("(a)\\1", "gu", "aa a", "# a"),
                Rx("(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\\10", "gu", "abcdefghijj abcdefghija0", "# abcdefghija0"),
                Rx("(?<a>x)\\k<a>", "gu", "xx x", "# x"),
                // Without `u` the same escapes are Annex B's characters.
                Rx("\\-", "g", "a-b", "a#b"),
                Rx("\\%", "g", "a%b", "a#b"),
                Rx("\\8", "g", "8", "#"),
            ),
        )
    }

    /** ECMAScript's WhiteSpace and LineTerminator, after the five controls U+0009-000D. */
    private val spaces = " \u00A0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF"

    /** The whole set, 25 characters. */
    private val white = "\t\n\u000B\u000C\r$spaces"

    /** NEL, the Mongolian vowel separator and the zero-width space are not in it. */
    private val notWhite = "\u0085\u180E\u200Ba"

    @Test
    fun a2_backslashVIsTheLineTabulationAloneInBothModes() {
        val ctl = "a\u000B\n\u000C\r\t\u0085\u2028\u2029 b"
        assertDart(
            listOf("g", "gu", "gi", "giu").flatMap { f ->
                listOf(
                    Rx("\\v", f, white + notWhite, "\t\n#\u000C\r$spaces$notWhite"),
                    Rx("[\\v]", f, white + notWhite, "\t\n#\u000C\r$spaces$notWhite"),
                    Rx("[^\\v]", f, white + notWhite, "##\u000B##########################"),
                    Rx("[\\v-\\r]", f, white + notWhite, "\t\n###$spaces$notWhite"),
                )
            } + listOf("g", "gu").flatMap { f ->
                listOf(
                    Rx("\\v", f, ctl, "a#\n\u000C\r\t\u0085\u2028\u2029 b"),
                    Rx("[\\v]", f, ctl, "a#\n\u000C\r\t\u0085\u2028\u2029 b"),
                    Rx("[^\\v]", f, ctl, "#\u000B#########"),
                )
            } + Rx("\\V", "g", white + notWhite, white + notWhite),
        )
    }

    @Test
    fun a2_backslashSIsEcmaScriptsWhiteSpaceInBothModes() {
        val all = white + notWhite
        assertDart(
            listOf("g", "gu", "gi", "giu").flatMap { f ->
                listOf(
                    Rx("\\s", f, all, "#########################$notWhite"),
                    Rx("[\\s]", f, all, "#########################$notWhite"),
                    Rx("[^\\S]", f, all, "#########################$notWhite"),
                    Rx("[\\s\\d]", f, all, "#########################$notWhite"),
                    Rx("\\s+", f, all, "#$notWhite"),
                    Rx("\\S", f, all, "$white####"),
                    Rx("[\\S]", f, all, "$white####"),
                    Rx("[^\\s]", f, all, "$white####"),
                    Rx("[^\\s\\d]", f, all, "$white####"),
                    Rx("[a\\S]", f, all, "$white####"),
                )
            } + listOf("g", "gu").flatMap { f ->
                listOf(
                    Rx("\\s", f, "a\uFEFFb\u180E\u200Bc\u00A0d", "a#b\u180E\u200Bc#d"),
                    Rx("[\\S]", f, "a\uFEFF\u0085", "#\uFEFF#"),
                    Rx("\\S", f, "\uFEFF\u0085", "\uFEFF#"),
                    Rx("\\s", f, "a\u000B\n\u000C\r\t\u0085\u2028\u2029 b", "a#####\u0085###b"),
                    Rx("[\\s]", f, "a\u000B\n\u000C\r\t\u0085\u2028\u2029 b", "a#####\u0085###b"),
                )
            },
        )
    }

    @Test
    fun a2_anEmptyClassTakesAQuantifierInBothModes() {
        assertDart(
            listOf("g", "gu").flatMap { f ->
                listOf(
                    Rx("[]*", f, "ab", "#a#b#"),
                    Rx("[]+", f, "ab", "ab"),
                    Rx("[]?", f, "ab", "#a#b#"),
                    Rx("[]{2}", f, "ab", "ab"),
                    Rx("[]{0}", f, "ab", "#a#b#"),
                    Rx("[]*?", f, "ab", "#a#b#"),
                    Rx("(?:[])*", f, "ab", "#a#b#"),
                    Rx("a[]?b", f, "ab", "#"),
                    Rx("a[]*b", f, "ab", "#"),
                    Rx("[^]*", f, "ab", "##"),
                    Rx("[]|a", f, "ab", "#b"),
                )
            },
        )
    }

    @Test
    fun a2_guard_aQuantifiedLookaheadWithoutUKeepsAnnexBsMatches() {
        assertDart(
            listOf(
                Rx("(?=a)*", "g", "xab", "#x#a#b#"),
                Rx("(?=a)+", "g", "xab", "x#ab"),
                Rx("(?!a)*", "g", "xab", "#x#a#b#"),
                Rx("(?=a){0}", "g", "xab", "#x#a#b#"),
                Rx("(?=a)*?", "g", "xab", "#x#a#b#"),
                Rx("x(?=a)*", "g", "xab", "#ab"),
                Rx("(?=a)?b", "g", "xab", "xa#"),
                Rx("(?=a)*a", "g", "xab", "x#b"),
                Rx("((?=a))*", "g", "xab", "#x#a#b#"),
                Rx("(?:(?=a))*", "g", "xab", "#x#a#b#"),
            ),
        )
    }

    @Test
    fun a2_anEmptyClassAndAQuantifiedLookaheadAreWrittenAsGroupsAQuantifierTakesOnIcu() {
        // Android's java.util.regex is ICU, which refuses `(?!)*` and `(?=a)*`; the desktop JVM takes either.
        assertEquals("(?:(?!))", RegexSupport.asciiClasses("[]"))
        assertEquals("(?:(?!))*", RegexSupport.asciiClasses("[]*"))
        assertEquals("(?:(?!))*", RegexSupport.asciiClasses("[]*", unicode = true))
        assertEquals("(?:(?=a))*", RegexSupport.asciiClasses("(?=a)*"))
        assertEquals("(?:(?!a)){2}", RegexSupport.asciiClasses("(?!a){2}"))
        assertEquals("x(?:(?=a))+?y", RegexSupport.asciiClasses("x(?=a)+?y"))
        assertEquals("((?:(?=a))*)", RegexSupport.asciiClasses("((?=a)*)"))
        assertEquals("(?=a)b", RegexSupport.asciiClasses("(?=a)b"))
        assertEquals(null, RegexSupport.asciiClasses("(?=a)*", unicode = true))
    }

    // MARK: S15 — group names, unset references (row 23b.37)
    // Expected values from Dart 3.12.2, the same with `u` and without. Group
    // names are dropped, so names the engine refuses work and a name may stand
    // in two alternatives; `\k<name>` is its groups' numbers. A reference that
    // can only see its group unset matches empty in Dart, where both engines
    // fail it. Not reached: a group unset only at run time (`(?:(a)|b)\1`).

    /** The pattern under `g` and `gu` on [input]. */
    private fun named(pattern: String, input: String, expected: String?): List<Rx> =
        listOf(Rx(pattern, "g", input, expected), Rx(pattern, "gu", input, expected))

    /** Group names Dart refuses, and each `\k` it refuses where the pattern has a named group. */
    private val refusedNames = listOf(
        "(?<1a>x)", "(?<a-b>x)", "(?<>x)", "(?<😀>x)", "(?<a😀>x)", "(?<a b>x)", "(?<a", "(?<a\\>x)", "(?<a\\x62>x)",
        "(?<١>x)", "(?<\u0301>x)", "(?<\u200Cx>x)", "(?<a\u00AD>x)", "(?<a\u0001>x)", "(?<ⸯ>x)", "(?<aⸯ>x)", "(?<‿>x)",
        "(?<a\u2028>x)", "(?<a\\u{}>x)", "(?<a\\u{110000}>x)", "(?<a\\u62>x)", "(?<\\u0031>x)", "(?<a\\u002d>x)",
        "(?<\\u{1F600}>x)", "(?<a\\U0062>x)", "(?<a\\uD835>x)",
        "(?<a>x)(?<a>y)", "(?:(?<a>x)|y)(?<a>z)", "(?<a>(?<a>x))", "(?<a>x|(?<a>y))", "(?:(?<a>x)|(?<a>y))(?<a>z)",
        "(?<=(?<a>x)(?<a>y))", "(?<a>x)\\k<b>", "(?<a>x)\\k", "(?<a>x)\\k<a", "(?<a>x)[\\k]", "(?<a>x)[\\k<a>]",
        "(?<A>x)\\k<a>", "(?<a>x)\\ka", "(?<a>x)\\k<>", "(?<a>x)\\k<1>", "(?<a>x)\\k<a\\u{62}>",
    )

    @Test
    fun g3_groupNamesAreDroppedSoNamesTheEngineRefusesWork() {
        assertDart(
            listOf(
                "(?<\$a>x)", "(?<é>x)", "(?<a>x)", "(?<_a>x)", "(?<a\$>x)", "(?<\$>x)", "(?<_>x)", "(?<a1>x)", "(?<ª>x)",
                "(?<a·>x)", "(?<a١>x)", "(?<a\u0301>x)", "(?<a\u200C>x)", "(?<a\u200D>x)", "(?<𝐀>x)", "(?<\u212A>x)",
                "(?<℘>x)", "(?<a\\u{62}>x)", "(?<a\\u0062>x)", "(?<\\u0024>x)", "(?<a\\u{0062}>x)", "(?<a\\u{000000062}>x)",
                "(?<\\u{1D400}>x)", "(?<a\\u200C>x)", "(?<a\\u{200c}>x)", "(?<a\\u00e9>x)",
            ).flatMap { named(it, "x", "#") } +
                named("(?<a\\u0062>x)\\k<ab>", "xx x", "# x") +
                named("(?<ab>x)\\k<a\\u{62}>", "xx x", "# x") +
                named("(?<𝐀>x)\\k<\\u{1D400}>", "xx x", "# x"),
        )
    }

    @Test
    fun g3_aNameInTwoAlternativesNamesTheGroupThatTookPart() {
        assertDart(
            named("(?<a>x)|(?<a>y)", "xy", "##") +
                named("(?:(?<a>x)|(?<a>y))\\k<a>", "xx yy xy", "# # xy") +
                named("(?:(?<a>x)|(?<a>y))+\\k<a>", "xyy yxx xx", "# # #") +
                named("(?<a>x)|(?:(?<a>y)|(?<a>z))\\k<a>", "x yy zz yz", "# # # yz") +
                named("(?:(?<a>x)\\k<a>|(?<a>y))", "xx y yy", "# # ##") +
                named("(?:(?<a>x)|(?<a>y))(?:(?<b>x)|(?<b>y))\\k<a>\\k<b>", "xyxy yyyy", "# #") +
                named("(?<a>x)|(?<a>y)\\k<a>", "x yy yx", "# # y#") +
                named("(?:(?<a>x)|(?<a>y)|(?<a>z))\\k<a>", "xx yy zz xy", "# # # xy") +
                named("(?<a>x)|(?<b>y)|(?<a>z)", "xyz", "###") +
                named("(?<a>x)(?:(?<b>y)|(?<b>z))", "xy xz", "# #") +
                named("(?<a>x)\\k<a>0", "xx0 x0", "# x0") +
                named("(?<a>x)\\k<a>1", "xx1", "#"),
        )
    }

    @Test
    fun g3_namesDartRefusesAreInvalid() {
        assertDart(refusedNames.flatMap { named(it, "xy", null) })
    }

    @Test
    fun g3_theRewriterItselfRefusesTheNamesDartRefuses() {
        // Not the engine: names are dropped, so it never sees one.
        val accepted = listOf(false, true).flatMap { u -> refusedNames.filter { RegexSupport.asciiClasses(it, unicode = u) != null }.map { "$it u=$u" } }
        assertEquals(emptyList(), accepted)
    }

    @Test
    fun g3_aReferenceThatCanOnlySeeItsGroupUnsetMatchesEmpty() {
        val fwd = "a ab aab b ba aba abab"
        assertDart(
            named("\\1(a)", "aa", "##") +
                named("(a\\1)", "aa", "##") +
                named("(\\1a)", fwd, "# #b ##b b b# #b# #b#b") +
                named("(?:\\1b|(a))+", "ab", "#") +
                named("\\2(a)(b)", "ab", "#") +
                named("(a)(?:\\2(b))", "ab", "#") +
                named("\\k<a>(?<a>x)", "xx", "##") +
                named("\\k<a>(?:(?<a>x)|(?<a>y))", "x y", "# #") +
                named("(a)|\\1b", "ab b", "## #") +
                named("(a)|b\\1", "ab b", "## #") +
                named("(?:(a)|\\1b)+", "ab b aab", "# # #") +
                named("(?:\\1(a))+", "aa a", "# #") +
                named("((a)|b\\2)", "ab b", "## #") +
                named("(a)|(?:b|\\1)c", "ac c bc", "## # #") +
                named("(?:(a)|b)|\\1c", "ac c", "## #") +
                named("(a)\\1|\\1b", "aa b ab", "# # a#") +
                named("(?=\\1(a))a", "aa a", "## #") +
                named("(a)(b)(c)(d)(e)(f)(g)(h)(i)\\10(j)", "abcdefghij", "#") +
                named("\\1*(a)", "aa", "##") +
                named("\\k<a>*(?<a>x)", "xx", "##") +
                named("(a)|\\1*b", "ab b", "## #") +
                named("\\1(?<=(a))", "aa", "a#a#"),
        )
    }

    @Test
    fun g3_guard_referencesThatCanSeeTheirGroupKeepTheirMatches() {
        assertDart(
            named("(?<a>x)\\1", "xx", "#") +
                named("(?<a>x)(?<b>y)\\k<b>\\k<a>", "xyyx", "#") +
                named("(?<a>.)\\k<a>(?<b>.)\\2", "aabb", "#") +
                named("(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\\10", "abcdefghijj", "#") +
                named("(a)(?:\\1)+", "aaa", "#") +
                named("(?<=(a))\\1", "aa", "a#") +
                listOf(
                    Rx("(a)\\2", "g", "a\u0002", "#"),
                    Rx("(a)\\2", "gu", "a\u0002", null),
                    Rx("(a)\\10", "g", "a\b", "#"),
                    Rx("(a)\\10", "gu", "a\b", null),
                    Rx("(a)\\8", "g", "a8", "#"),
                    Rx("(a)\\8", "gu", "a8", null),
                ),
        )
    }

    @Test
    fun g3_referencesAreWrittenAsTheirGroupsNumbersOrAsAnEmptyGroup() {
        assertEquals("(x)(?:\\1)", RegexSupport.asciiClasses("(?<a>x)\\k<a>"))
        assertEquals("(x)(?:\\1)", RegexSupport.asciiClasses("(?<a>x)\\k<a>", unicode = true))
        assertEquals("(?:(x)|(y))(?:\\1|\\2)", RegexSupport.asciiClasses("(?:(?<a>x)|(?<a>y))\\k<a>"))
        // An alternative that can only be unset is left out, and with none left the group is empty.
        assertEquals("(x)|(?:(y)|(z))(?:\\2|\\3)", RegexSupport.asciiClasses("(?<a>x)|(?:(?<a>y)|(?<a>z))\\k<a>"))
        assertEquals("(?:)(x)", RegexSupport.asciiClasses("\\k<a>(?<a>x)"))
        assertEquals("(?:)(a)", RegexSupport.asciiClasses("\\1(a)"))
        assertEquals("(a|(?:))", RegexSupport.asciiClasses("(a|\\1)", unicode = true))
        assertEquals("(a)|(?:)b", RegexSupport.asciiClasses("(a)|\\1b"))
        // A reference that can see its group set is copied, and so is one in a lookbehind.
        assertEquals("(a)\\1", RegexSupport.asciiClasses("(a)\\1"))
        assertEquals("(?<=\\1(a))b", RegexSupport.asciiClasses("(?<=\\1(a))b"))
        assertEquals("(x)(?<=(?:\\1))", RegexSupport.asciiClasses("(?<a>x)(?<=\\k<a>)"))
    }

    @Test
    fun g3_aGroupInANegativeLookaroundIsUnsetAfterIt() {
        // A negative lookaround succeeds only when its body fails, so after it
        // Dart sees each of its groups unset, through any enclosing group too.
        // Inside it a reference sees its group as usual, a positive lookaround
        // leaves its groups set, and a name stays taken by a group inside one.
        val neg = "b ab aa ba bb abb aab c ac bc abc aac xy y x"
        assertDart(
            named("(?!(a))\\1b", neg, "# a# aa #a ## a## aa# c ac #c a#c aac xy y x") +
                named("(?!(a))\\1", neg, "#b# a#b# aa# #ba# #b#b# a#b#b# aa#b# #c# a#c# #b#c# a#b#c# aa#c# #x#y# #y# #x#") +
                named("(?!(?=(a)))\\1", neg, "#b# a#b# aa# #ba# #b#b# a#b#b# aa#b# #c# a#c# #b#c# a#b#c# aa#c# #x#y# #y# #x#") +
                named("(?=(?!(a)))\\1b", neg, "# a# aa #a ## a## aa# c ac #c a#c aac xy y x") +
                named("(?<=(?!(a)))\\1b", neg, "# a# aa #a ## a## aa# c ac #c a#c aac xy y x") +
                named("(?!(?!(a)))\\1", neg, "b #ab #a#a b#a bb #abb #a#ab c #ac bc #abc #a#ac xy y x") +
                named("(?!(a)|(b))\\1\\2c", neg, "b ab aa ba bb abb aab # a# b# ab# aa# xy y x") +
                named("(a)(?!(b))\\1\\2", neg, "b ab # ba bb abb #b c ac bc abc #c xy y x") +
                named("((?!(a)))\\2b", neg, "# a# aa #a ## a## aa# c ac #c a#c aac xy y x") +
                named("(?:(?!(a)))\\1b", neg, "# a# aa #a ## a## aa# c ac #c a#c aac xy y x") +
                named("(?:(?!(a))|(a))\\1", neg, "#b# ##b# ### #b## #b#b# ##b#b# ###b# #c# ##c# #b#c# ##b#c# ###c# #x#y# #y# #x#") +
                named("(?:(?!(a))\\1b)+", neg, "# a# aa #a # a# aa# c ac #c a#c aac xy y x") +
                named("(?:(?!(a))b)+\\1", neg, "# a# aa #a # a# aa# c ac #c a#c aac xy y x") +
                named("(?!(a))(?:\\1)b", neg, "# a# aa #a ## a## aa# c ac #c a#c aac xy y x") +
                named("(?!(a))(?=\\1b)", neg, "#b a#b aa #ba #b#b a#b#b aa#b c ac #bc a#bc aac xy y x") +
                named("(?!(?!(a))\\1b)c", neg, "b ab aa ba bb abb aab # a# b# ab# aa# xy y x") +
                named("(?<!(a))\\1b", neg, "# ab aa #a ## ab# aab c ac #c abc aac xy y x") +
                named("(?!(?<n>a))\\k<n>b", neg, "# a# aa #a ## a## aa# c ac #c a#c aac xy y x") +
                named("(?!(a)(?<n>b))\\k<n>c", neg, "b ab aa ba bb abb aab # a# b# ab# aa# xy y x") +
                named("(?=(a))\\1", neg, "b #b ## b# bb #bb ##b c #c bc #bc ##c xy y x") +
                named("(?!(a)\\1)b", neg, "# a# aa #a ## a## aa# c ac #c a#c aac xy y x") +
                named("(?!(?<n>a))|(?<n>b)\\k<n>", neg, "#b# a#b# aa# #ba# #b#b# a#b#b# aa#b# #c# a#c# #b#c# a#b#c# aa#c# #x#y# #y# #x#") +
                named("(?!(?<n>a)|(?<n>b))c", neg, "b ab aa ba bb abb aab # a# b# ab# aa# xy y x") +
                named("(?!(?<n>a))(?<n>b)", neg, null) +
                named("(?<n>a)(?!(?<n>b))", neg, null) +
                named("(?<!(?<n>a))(?<n>b)", neg, null),
        )
        assertEquals("(?!(a))(?:)b", RegexSupport.asciiClasses("(?!(a))\\1b"))
        assertEquals("(?!(a)\\1)b", RegexSupport.asciiClasses("(?!(a)\\1)b"))
        // A `\k<name>` drops only the groups a negative lookaround holds.
        assertEquals("(?:(a)|(?!(b)))(?:\\1)c", RegexSupport.asciiClasses("(?:(?<n>a)|(?!(?<n>b)))\\k<n>c"))
    }

    // MARK: S15 — iu properties, script values (row 23b.37)
    // Expected values from Dart 3.12.2. Under `i` with `u` Dart builds a
    // class's set first and folds after: a character matches a class when a
    // member of its simple case-fold class (DartFoldClasses) is in the set,
    // and a negated class when none is. So `\P{Ll}` matches s, whose partner
    // S is not Ll, and `[^\P{Ll}]` no letter with a partner; both engines
    // fold the property first and negate after. Script values are ECMA-262's,
    // case-sensitive, under every key.

    /** The G4 rows' input: s S ſ, k K and the Kelvin sign, punctuation, é É, ǅ Ǆ ǆ, ß ẞ. */
    private val iuLetters = "sS\u017FkK\u212A_!\u00E9\u00C9\u01C5\u01C4\u01C6\u00DF\u1E9E"

    /** The probe's: a digit, ſ and K after the ASCII pairs, Σ σ ς, ẞ ß. */
    private val iuMore = "sSkK_!\u00E9\u00C91\u01C5\u01C4\u01C6\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"

    /** Capital and small letters above U+FFFF, Deseret, Osage and Adlam, then a and 1. */
    private val iuAstral = "\uD801\uDC00\uD801\uDC28\uD801\uDCB0\uD801\uDCD8\uD83A\uDD00\uD83A\uDD22a1"

    /** Latin a, Greek α, a combining grave (Inherited), Coptic ⲁ, the voiced sound mark (Common), Devanagari's stress sign (Inherited). */
    private val scriptLetters = "a\u03B1\u0300\u2C81\u309B\u0951"

    /** The 336 script values Dart 3.12.2 accepts after `Script=`: four-letter codes and long names (Unicode 16), Qaai and Qaac. */
    private val dartScriptValues = """
        Adlam Adlm Aghb Ahom Anatolian_Hieroglyphs Arab Arabic Armenian Armi Armn Avestan Avst Bali Balinese
        Bamu Bamum Bass Bassa_Vah Batak Batk Beng Bengali Bhaiksuki Bhks Bopo Bopomofo Brah Brahmi Brai Braille
        Bugi Buginese Buhd Buhid Cakm Canadian_Aboriginal Cans Cari Carian Caucasian_Albanian Chakma Cham Cher
        Cherokee Chorasmian Chrs Common Copt Coptic Cpmn Cprt Cuneiform Cypriot Cypro_Minoan Cyrillic Cyrl
        Deseret Deva Devanagari Diak Dives_Akuru Dogr Dogra Dsrt Dupl Duployan Egyp Egyptian_Hieroglyphs Elba
        Elbasan Elym Elymaic Ethi Ethiopic Gara Garay Geor Georgian Glag Glagolitic Gong Gonm Goth Gothic Gran
        Grantha Greek Grek Gujarati Gujr Gukh Gunjala_Gondi Gurmukhi Guru Gurung_Khema Han Hang Hangul Hani
        Hanifi_Rohingya Hano Hanunoo Hatr Hatran Hebr Hebrew Hira Hiragana Hluw Hmng Hmnp Hung Imperial_Aramaic
        Inherited Inscriptional_Pahlavi Inscriptional_Parthian Ital Java Javanese Kaithi Kali Kana Kannada
        Katakana Kawi Kayah_Li Khar Kharoshthi Khitan_Small_Script Khmer Khmr Khoj Khojki Khudawadi Kirat_Rai
        Kits Knda Krai Kthi Lana Lao Laoo Latin Latn Lepc Lepcha Limb Limbu Lina Linb Linear_A Linear_B Lisu
        Lyci Lycian Lydi Lydian Mahajani Mahj Maka Makasar Malayalam Mand Mandaic Mani Manichaean Marc Marchen
        Masaram_Gondi Medefaidrin Medf Meetei_Mayek Mend Mende_Kikakui Merc Mero Meroitic_Cursive
        Meroitic_Hieroglyphs Miao Mlym Modi Mong Mongolian Mro Mroo Mtei Mult Multani Myanmar Mymr Nabataean
        Nag_Mundari Nagm Nand Nandinagari Narb Nbat New_Tai_Lue Newa Nko Nkoo Nshu Nushu Nyiakeng_Puachue_Hmong
        Ogam Ogham Ol_Chiki Ol_Onal Olck Old_Hungarian Old_Italic Old_North_Arabian Old_Permic Old_Persian
        Old_Sogdian Old_South_Arabian Old_Turkic Old_Uyghur Onao Oriya Orkh Orya Osage Osge Osma Osmanya Ougr
        Pahawh_Hmong Palm Palmyrene Pau_Cin_Hau Pauc Perm Phag Phags_Pa Phli Phlp Phnx Phoenician Plrd Prti
        Psalter_Pahlavi Qaac Qaai Rejang Rjng Rohg Runic Runr Samaritan Samr Sarb Saur Saurashtra Sgnw Sharada
        Shavian Shaw Shrd Sidd Siddham SignWriting Sind Sinh Sinhala Sogd Sogdian Sogo Sora Sora_Sompeng Soyo
        Soyombo Sund Sundanese Sunu Sunuwar Sylo Syloti_Nagri Syrc Syriac Tagalog Tagb Tagbanwa Tai_Le Tai_Tham
        Tai_Viet Takr Takri Tale Talu Tamil Taml Tang Tangsa Tangut Tavt Telu Telugu Tfng Tglg Thaa Thaana Thai
        Tibetan Tibt Tifinagh Tirh Tirhuta Tnsa Todhri Todr Toto Tulu_Tigalari Tutg Ugar Ugaritic Unknown Vai
        Vaii Vith Vithkuqi Wancho Wara Warang_Citi Wcho Xpeo Xsux Yezi Yezidi Yi Yiii Zanabazar_Square Zanb Zinh
        Zyyy Zzzz
    """.trim().split(' ', '\n').filter(String::isNotEmpty)

    @Test
    fun g4_aNegatedPropertyUnderIuMatchesEveryLetterWithAPartnerOutsideIt() {
        assertDart(
            listOf(
                Rx("\\P{Ll}", "giu", iuLetters, "###############"),
                Rx("\\P{Lu}", "giu", iuLetters, "###############"),
                Rx("\\P{Lt}", "giu", iuLetters, "###############"),
                Rx("[\\P{Ll}]", "giu", iuLetters, "###############"),
                Rx("[^\\P{Ll}]", "giu", iuLetters, iuLetters),
                Rx("[\\P{Ll}\\d]", "giu", iuLetters, "###############"),
                Rx("\\P{Lowercase}", "giu", iuLetters, "###############"),
                Rx("\\P{ASCII}", "giu", iuLetters, "######_!#######"),
                Rx("\\P{Ll}", "giu", iuMore, "###################"),
                Rx("\\P{Lu}", "giu", iuMore, "###################"),
                Rx("[\\P{Ll}]", "giu", iuMore, "###################"),
                Rx("[^\\P{Ll}]", "giu", iuMore, iuMore),
                Rx("\\P{Lt}", "giu", iuMore, "###################"),
                Rx("\\P{Lowercase}", "giu", iuMore, "###################"),
                Rx("\\P{Uppercase}", "giu", iuMore, "###################"),
                Rx("[^\\P{Lu}]", "giu", iuMore, iuMore),
                Rx("[\\P{Ll}\\d]", "giu", iuMore, "###################"),
                Rx("[^\\P{Ll}\\d]", "giu", iuMore, iuMore),
            ),
        )
    }

    @Test
    fun g4_onTheJvmLtAndAsciiUnderIuMatchAsDart() {
        // The JVM folds `\p{Lt}` into every cased letter and leaves ſ and K out of `\p{ASCII}`.
        assertDart(
            listOf(
                Rx("\\p{Lt}", "giu", iuLetters, "sS\u017FkK\u212A_!\u00E9\u00C9###\u00DF\u1E9E"),
                Rx("\\p{ASCII}", "giu", iuLetters, "########\u00E9\u00C9\u01C5\u01C4\u01C6\u00DF\u1E9E"),
                Rx("[\\p{Lt}x]", "giu", iuLetters, "sS\u017FkK\u212A_!\u00E9\u00C9###\u00DF\u1E9E"),
                Rx("\\p{Lt}", "giu", iuMore, "sSkK_!\u00E9\u00C91###\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"),
            ),
        )
    }

    @Test
    fun g4_aLetterAboveTheBmpMatchesByItsFoldClass() {
        assertDart(
            listOf(
                Rx("\\P{Ll}", "giu", iuAstral, "########"),
                Rx("\\P{Lu}", "giu", iuAstral, "########"),
                Rx("[\\P{Ll}]", "giu", iuAstral, "########"),
                Rx("[^\\P{Ll}]", "giu", iuAstral, iuAstral),
                Rx("\\p{Lu}", "giu", iuAstral, "#######1"),
                Rx("\\p{Ll}", "giu", iuAstral, "#######1"),
                Rx("\\p{Lt}", "giu", iuAstral, iuAstral),
                Rx("[^\\p{Lu}]", "giu", iuAstral, "\uD801\uDC00\uD801\uDC28\uD801\uDCB0\uD801\uDCD8\uD83A\uDD00\uD83A\uDD22a#"),
                Rx("\\P{Script=Deseret}", "giu", iuAstral, "\uD801\uDC00\uD801\uDC28######"),
                Rx("\\p{Script=Osage}", "giu", iuAstral, "\uD801\uDC00\uD801\uDC28##\uD83A\uDD00\uD83A\uDD22a1"),
                Rx("\\p{sc=Dsrt}", "giu", iuAstral, "##\uD801\uDCB0\uD801\uDCD8\uD83A\uDD00\uD83A\uDD22a1"),
                Rx("[\\p{sc=Dsrt}a]", "giu", iuAstral, "##\uD801\uDCB0\uD801\uDCD8\uD83A\uDD00\uD83A\uDD22#1"),
                Rx("[^\\p{sc=Adlm}\\d]", "giu", iuAstral, "####\uD83A\uDD00\uD83A\uDD22#1"),
                Rx("\\p{ASCII}", "giu", iuAstral, "\uD801\uDC00\uD801\uDC28\uD801\uDCB0\uD801\uDCD8\uD83A\uDD00\uD83A\uDD22##"),
                Rx("\\P{ASCII}", "giu", iuAstral, "######a1"),
                Rx("\\P{Ll}+", "giu", iuAstral, "#"),
                Rx("\\p{Lu}{2}", "giu", iuAstral, "###a1"),
            ),
        )
    }

    @Test
    fun g4_everyFoldClassMatchesAsDartUnderIu() {
        // Every letter with a partner, each one's class tried: Dart matches all of them
        // to `\P{Lu}` and `\p{Any}`, and to `\P{Ll}` all but the three classes whose letters are all Ll.
        val letters = DartFoldClasses.letters.joinToString("") { String(Character.toChars(it)) }
        val allLl = setOf(0x0390, 0x1FD3, 0x03B0, 0x1FE3, 0xFB05, 0xFB06) // ΐ ΐ, ΰ ΰ, ﬅ ﬆ
        fun marked(match: (Int) -> Boolean) = DartFoldClasses.letters.joinToString("") { if (match(it)) "#" else String(Character.toChars(it)) }
        assertDart(
            listOf(
                Rx("\\P{Lu}", "giu", letters, marked { true }),
                Rx("[^\\P{Lu}]", "giu", letters, letters),
                Rx("\\P{Ll}", "giu", letters, marked { it !in allLl }),
                Rx("[^\\P{Ll}]", "giu", letters, marked { it in allLl }),
                Rx("\\p{Any}", "giu", letters, marked { true }),
                Rx("[^\\p{Any}]", "giu", letters, letters),
            ),
        )
    }

    @Test
    fun g4_theFoldClassesHoldTheTablesSetsWithU() {
        val classes = DartFoldClasses.classes
        assertEquals(1454, classes.size)
        assertEquals(2938, DartFoldClasses.letters.size)
        assertEquals(2938, DartFoldClasses.letters.toSet().size)
        assertEquals(282, classes.count { k -> k.any { it > 0xFFFF } })
        assertEquals(564, DartFoldClasses.letters.count { it > 0xFFFF })
        // Each of DartFoldTable's letters matches with `u` its fold class, or itself
        // alone where it has no partner (ı, İ, ŉ, ʼ, the ligatures, …): 44 of them.
        val classOf = classes.flatMap { k -> k.map { it to k.toSet() } }.toMap()
        val differ = DartFoldTable.letters.filter { c -> DartFoldTable.set(c, unicode = true)!!.map(Char::code).toSet() != (classOf[c.code] ?: setOf(c.code)) }
        assertEquals("", differ)
        assertEquals(44, DartFoldTable.letters.count { it.code !in classOf })
    }

    @Test
    fun g4_guard_propertiesTheEngineFoldsAsDartKeepTheirMatches() {
        assertDart(
            listOf(
                Rx("\\P{Script=Latin}", "giu", iuLetters, "sS\u017FkK\u212A##\u00E9\u00C9\u01C5\u01C4\u01C6\u00DF\u1E9E"),
                Rx("\\p{Lu}", "giu", iuLetters, "######_!#######"),
                Rx("[^\\p{Ll}]", "giu", iuLetters, "sS\u017FkK\u212A##\u00E9\u00C9\u01C5\u01C4\u01C6\u00DF\u1E9E"),
                Rx("\\p{Lowercase_Letter}", "giu", iuLetters, "######_!#######"),
                Rx("\\p{LC}", "giu", iuLetters, "######_!#######"),
                Rx("[^\\p{Ll}]", "giu", iuMore, "sSkK##\u00E9\u00C9#\u01C5\u01C4\u01C6\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"),
                Rx("\\P{Script=Latin}", "giu", iuMore, "sSkK##\u00E9\u00C9#\u01C5\u01C4\u01C6\u017F\u212A###\u1E9E\u00DF"),
                Rx("[^\\p{Lu}a]", "giu", iuMore, "sSkK##\u00E9\u00C9#\u01C5\u01C4\u01C6\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"),
                Rx("\\p{Ll}", "giu", iuMore, "####_!##1##########"),
                Rx("\\p{Lu}", "giu", iuMore, "####_!##1##########"),
                Rx("[^a-z]", "giu", iuMore, "sSkK########\u017F\u212A#####"),
                Rx("[^\\p{L}]", "giu", iuMore, "sSkK##\u00E9\u00C9#\u01C5\u01C4\u01C6\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"),
                Rx("\\P{L}", "giu", iuMore, "sSkK##\u00E9\u00C9#\u01C5\u01C4\u01C6\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"),
                Rx("\\P{Ll}", "gu", iuMore, "s#k###\u00E9####\u01C6\u017F##\u03C3\u03C2#\u00DF"),
                Rx("\\P{Lu}", "gu", iuMore, "#S#K###\u00C9##\u01C4##\u212A\u03A3##\u1E9E#"),
                Rx("[^\\p{Ll}]", "gu", iuMore, "s#k###\u00E9####\u01C6\u017F##\u03C3\u03C2#\u00DF"),
                Rx("[\\P{Ll}]", "gu", iuMore, "s#k###\u00E9####\u01C6\u017F##\u03C3\u03C2#\u00DF"),
                Rx("[^\\P{Ll}]", "gu", iuMore, "#S#K_!#\u00C91\u01C5\u01C4##\u212A\u03A3##\u1E9E#"),
                Rx("\\P{Lt}", "gu", iuMore, "#########\u01C5#########"),
                Rx("\\P{Lowercase}", "gu", iuMore, "s#k###\u00E9####\u01C6\u017F##\u03C3\u03C2#\u00DF"),
                Rx("\\P{Uppercase}", "gu", iuMore, "#S#K###\u00C9##\u01C4##\u212A\u03A3##\u1E9E#"),
                Rx("\\P{Script=Latin}", "gu", iuMore, "sSkK##\u00E9\u00C9#\u01C5\u01C4\u01C6\u017F\u212A###\u1E9E\u00DF"),
                Rx("[^\\p{Lu}a]", "gu", iuMore, "#S#K###\u00C9##\u01C4##\u212A\u03A3##\u1E9E#"),
                Rx("\\p{Ll}", "gu", iuMore, "#S#K_!#\u00C91\u01C5\u01C4##\u212A\u03A3##\u1E9E#"),
                Rx("\\p{Lu}", "gu", iuMore, "s#k#_!\u00E9#1\u01C5#\u01C6\u017F##\u03C3\u03C2#\u00DF"),
                Rx("\\p{Lt}", "gu", iuMore, "sSkK_!\u00E9\u00C91#\u01C4\u01C6\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"),
                Rx("[^a-z]", "gu", iuMore, "s#k################"),
                Rx("[^\\p{L}]", "gu", iuMore, "sSkK##\u00E9\u00C9#\u01C5\u01C4\u01C6\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"),
                Rx("\\P{L}", "gu", iuMore, "sSkK##\u00E9\u00C9#\u01C5\u01C4\u01C6\u017F\u212A\u03A3\u03C3\u03C2\u1E9E\u00DF"),
                Rx("[^\\P{Lu}]", "gu", iuMore, "s#k#_!\u00E9#1\u01C5#\u01C6\u017F##\u03C3\u03C2#\u00DF"),
                Rx("[\\P{Ll}\\d]", "gu", iuMore, "s#k###\u00E9####\u01C6\u017F##\u03C3\u03C2#\u00DF"),
                Rx("[^\\P{Ll}\\d]", "gu", iuMore, "#S#K_!#\u00C91\u01C5\u01C4##\u212A\u03A3##\u1E9E#"),
                Rx("\\P{Ll}", "gu", iuAstral, "#\uD801\uDC28#\uD801\uDCD8#\uD83A\uDD22a#"),
                Rx("[^\\P{Ll}]", "gu", iuAstral, "\uD801\uDC00#\uD801\uDCB0#\uD83A\uDD00##1"),
                Rx("\\p{Lu}", "gu", iuAstral, "#\uD801\uDC28#\uD801\uDCD8#\uD83A\uDD22a1"),
                Rx("[^\\p{Lu}]", "gu", iuAstral, "\uD801\uDC00#\uD801\uDCB0#\uD83A\uDD00###"),
            ),
        )
    }

    @Test
    fun g4_scriptValuesAreDartsExactly() {
        // Case-sensitive, no spaces, the long name's underscores, and Hrkt is not one.
        assertDart(
            listOf(
                Rx("\\p{Script=latin}", "gu", scriptLetters, null),
                Rx("\\p{Script=latin}", "giu", scriptLetters, null),
                Rx("\\p{sc=latn}", "gu", scriptLetters, null),
                Rx("\\p{sc=latn}", "giu", scriptLetters, null),
                Rx("\\p{Script=Latin }", "gu", scriptLetters, null),
                Rx("\\p{Script=Latin }", "giu", scriptLetters, null),
                Rx("\\p{Script= Latin}", "gu", scriptLetters, null),
                Rx("\\p{Script= Latin}", "giu", scriptLetters, null),
                Rx("\\p{Script=OldItalic}", "gu", scriptLetters, null),
                Rx("\\p{Script=OldItalic}", "giu", scriptLetters, null),
                Rx("\\p{Script=Hrkt}", "gu", scriptLetters, null),
                Rx("\\p{Script=Hrkt}", "giu", scriptLetters, null),
                Rx("\\p{Script=Katakana_Or_Hiragana}", "gu", scriptLetters, null),
                Rx("\\p{Script=Katakana_Or_Hiragana}", "giu", scriptLetters, null),
                Rx("\\p{scx=latin}", "gu", scriptLetters, null),
                Rx("\\p{scx=latin}", "giu", scriptLetters, null),
                Rx("\\p{Script=}", "gu", scriptLetters, null),
                Rx("\\p{Script=}", "giu", scriptLetters, null),
                Rx("\\p{Script=LATIN}", "gu", scriptLetters, null),
                Rx("\\p{Script=LATIN}", "giu", scriptLetters, null),
                Rx("\\p{Script=old_italic}", "gu", scriptLetters, null),
                Rx("\\p{Script=old_italic}", "giu", scriptLetters, null),
                Rx("\\p{Script_Extensions=latin}", "gu", scriptLetters, null),
                Rx("\\p{Script_Extensions=latin}", "giu", scriptLetters, null),
                Rx("\\p{Script=Qaaa}", "gu", scriptLetters, null),
                Rx("\\p{Script=Qaaa}", "giu", scriptLetters, null),
                Rx("\\p{Script=Latn}", "gu", scriptLetters, "#\u03B1\u0300\u2C81\u309B\u0951"),
                Rx("\\p{Script=Latn}", "giu", scriptLetters, "#\u03B1\u0300\u2C81\u309B\u0951"),
                Rx("\\p{Script=Old_Italic}", "gu", scriptLetters, scriptLetters),
                Rx("\\p{Script=Old_Italic}", "giu", scriptLetters, scriptLetters),
                Rx("\\p{Script=Ital}", "gu", scriptLetters, scriptLetters),
                Rx("\\p{Script=Ital}", "giu", scriptLetters, scriptLetters),
                Rx("\\p{Script=Zzzz}", "gu", scriptLetters, scriptLetters),
                Rx("\\p{Script=Zzzz}", "giu", scriptLetters, scriptLetters),
                Rx("\\p{Script=Unknown}", "gu", scriptLetters, scriptLetters),
                Rx("\\p{Script=Unknown}", "giu", scriptLetters, scriptLetters),
                Rx("\\p{Script=Zyyy}", "gu", scriptLetters, "a\u03B1\u0300\u2C81#\u0951"),
                Rx("\\p{Script=Zyyy}", "giu", scriptLetters, "a\u03B1\u0300\u2C81#\u0951"),
                Rx("\\p{sc=Common}", "gu", scriptLetters, "a\u03B1\u0300\u2C81#\u0951"),
                Rx("\\p{sc=Common}", "giu", scriptLetters, "a\u03B1\u0300\u2C81#\u0951"),
                Rx("\\p{Script=Greek}", "gu", scriptLetters, "a#\u0300\u2C81\u309B\u0951"),
                Rx("\\p{Script=Greek}", "giu", scriptLetters, "a#\u0300\u2C81\u309B\u0951"),
                Rx("\\P{sc=Latn}", "gu", scriptLetters, "a#####"),
                Rx("\\P{sc=Latn}", "giu", scriptLetters, "a#####"),
                Rx("[\\p{sc=Grek}a]", "gu", scriptLetters, "##\u0300\u2C81\u309B\u0951"),
                Rx("[\\p{sc=Grek}a]", "giu", scriptLetters, "##\u0300\u2C81\u309B\u0951"),
            ),
        )
    }

    @Test
    fun g4_onTheJvmQaaiAndQaacReadAsInheritedAndCoptic() {
        assertDart(
            listOf(
                Rx("\\p{Script=Qaai}", "gu", scriptLetters, "a\u03B1#\u2C81\u309B#"),
                Rx("\\p{Script=Qaai}", "giu", scriptLetters, "a\u03B1#\u2C81\u309B#"),
                Rx("\\p{sc=Qaai}", "gu", scriptLetters, "a\u03B1#\u2C81\u309B#"),
                Rx("\\p{sc=Qaai}", "giu", scriptLetters, "a\u03B1#\u2C81\u309B#"),
                Rx("\\p{Script=Zinh}", "gu", scriptLetters, "a\u03B1#\u2C81\u309B#"),
                Rx("\\p{Script=Zinh}", "giu", scriptLetters, "a\u03B1#\u2C81\u309B#"),
                Rx("\\p{sc=Inherited}", "gu", scriptLetters, "a\u03B1#\u2C81\u309B#"),
                Rx("\\p{sc=Inherited}", "giu", scriptLetters, "a\u03B1#\u2C81\u309B#"),
                Rx("\\P{Script=Qaai}", "gu", scriptLetters, "##\u0300##\u0951"),
                Rx("\\P{Script=Qaai}", "giu", scriptLetters, "##\u0300##\u0951"),
                Rx("[\\p{Script=Qaai}a]", "gu", scriptLetters, "#\u03B1#\u2C81\u309B#"),
                Rx("[\\p{Script=Qaai}a]", "giu", scriptLetters, "#\u03B1#\u2C81\u309B#"),
                Rx("\\p{Script=Qaac}", "gu", scriptLetters, "a\u03B1\u0300#\u309B\u0951"),
                Rx("\\p{Script=Qaac}", "giu", scriptLetters, "a\u03B1\u0300#\u309B\u0951"),
                Rx("\\p{sc=Qaac}", "gu", scriptLetters, "a\u03B1\u0300#\u309B\u0951"),
                Rx("\\p{sc=Qaac}", "giu", scriptLetters, "a\u03B1\u0300#\u309B\u0951"),
                Rx("\\P{sc=Qaac}", "gu", scriptLetters, "###\u2C81##"),
                Rx("\\P{sc=Qaac}", "giu", scriptLetters, "###\u2C81##"),
                Rx("[^\\p{Script=Qaac}]", "gu", scriptLetters, "###\u2C81##"),
                Rx("[^\\p{Script=Qaac}]", "giu", scriptLetters, "###\u2C81##"),
                Rx("\\p{sc=Copt}", "gu", scriptLetters, "a\u03B1\u0300#\u309B\u0951"),
                Rx("\\p{sc=Copt}", "giu", scriptLetters, "a\u03B1\u0300#\u309B\u0951"),
                Rx("\\p{Script=Coptic}", "gu", scriptLetters, "a\u03B1\u0300#\u309B\u0951"),
                Rx("\\p{Script=Coptic}", "giu", scriptLetters, "a\u03B1\u0300#\u309B\u0951"),
            ),
        )
    }

    @Test
    fun g4_theScriptValuesAreEcma262sUnderEveryKey() {
        assertEquals(336, dartScriptValues.size)
        val keys = listOf("Script", "sc", "Script_Extensions", "scx")
        assertEquals(emptyList(), keys.flatMap { k -> dartScriptValues.map { "$k=$it" } }.filterNot(RegexPropertyNames::accepts))
        // Another case, a space, no underscore, and codes ECMA-262 leaves out.
        val others = dartScriptValues.flatMap { listOf(it.lowercase(), it.uppercase(), " $it", "$it ", it.replace("_", "")) } +
            listOf("Hrkt", "Katakana_Or_Hiragana", "Qaaa", "Qabx", "Zxxx", "Zsym", "Zmth", "")
        val refused = others.filter { it !in dartScriptValues }
        assertEquals(emptyList(), keys.flatMap { k -> refused.map { "$k=$it" } }.filter(RegexPropertyNames::accepts))
    }

    @Test
    fun g4_everyScriptValueTheRuntimeKnowsCompiles() {
        // java.util.regex reads the scripts of its Unicode version, so a newer one stays
        // invalid; Qaai and Qaac, which it lacks, are read as Inherited and Coptic.
        val known = dartScriptValues.filter { runCatching { Character.UnicodeScript.forName(it) }.isSuccess } + listOf("Qaai", "Qaac")
        val patterns = known.flatMap { listOf("\\p{Script=$it}", "[\\P{sc=$it}]") }
        assertEquals(emptyList(), listOf("gu", "giu").flatMap { f -> patterns.filter { RegexSupport.compile(it, f) == null }.map { "$it /$f" } })
    }

    // MARK: S16 — UTF-16 units without u (row 23b.38)
    // Expected values from Dart 3.14.0. Without `u` Dart reads the pattern and the input as UTF-16
    // code units: each half of a surrogate pair is one character, a match may hold one half alone,
    // and no letter above U+FFFF folds. With `u`, after an empty match at a pair's first half, the
    // next search starts after the pair.

    /** 😀 U+1F600 and 😂 U+1F602, and 😀's two halves. */
    private val e = String(Character.toChars(0x1F600))
    private val e2 = String(Character.toChars(0x1F602))
    private val eHi = Char(0xD83D).toString()
    private val eLo = Char(0xDE00).toString()

    /** 𐐨 U+10428 and 𐐀 U+10400, one Deseret fold class, and their halves. */
    private val d = String(Character.toChars(0x10428))
    private val dHi = Char(0xD801).toString()
    private val dLo = Char(0xDC28).toString()
    private val dU = String(Character.toChars(0x10400))

    /** Private-use characters, from the block a masked run takes its stand-ins from. */
    private val p0 = Char(0xE000).toString()
    private val p1 = Char(0xE001).toString()
    private val p2 = Char(0xE002).toString()

    /** Every private-use character of the BMP, U+E000-F8FF. */
    private val allPua = (0xE000..0xF8FF).joinToString("") { Char(it).toString() }

    /** A backslash, `u` and the four hex digits [hex], as pattern text. */
    private fun esc(hex: String): String = "\\u" + hex

    private val noU = listOf("g", "gi", "gm", "gs")
    private val withU = listOf("gu", "giu")

    /** The unit rows' inputs: E, "aEb", "EE", 𐐨 and "a\nE". */
    private val unitInputs = listOf(e, "a${e}b", e + e, d, "a\n$e")

    /** Inputs with private-use characters next to E, for classes and ranges. */
    private val classInputs = listOf(e, "a${e}b", "$p0$e$p1", "b$p2$e")
    private val puaInputs = listOf("$p0$e", "$e$p0$p1", "$p0$p0$e")
    private val stepInputs = listOf(e, e + e, "a$e", "${e}a")

    /**
     * [pattern] on each of [inputs] under each of [flags], with Dart's output for each input in
     * order (null where Dart throws). On "a\nE", the last of [unitInputs], [gm] and [gs] are
     * Dart's under `gm` and `gs` where they differ from the others.
     */
    private fun units(
        pattern: String,
        vararg expected: String?,
        inputs: List<String> = unitInputs,
        flags: List<String> = noU,
        gm: String? = null,
        gs: String? = null,
    ): List<Rx> {
        assertEquals(inputs.size, expected.size, pattern)
        return flags.flatMap { f ->
            inputs.mapIndexed { n, input ->
                val out = when {
                    inputs !== unitInputs || n < inputs.lastIndex -> expected[n]
                    f == "gm" -> gm ?: expected[n]
                    f == "gs" -> gs ?: expected[n]
                    else -> expected[n]
                }
                Rx(pattern, f, input, out)
            }
        }
    }

    /** A regex step on an input, and Dart's output. */
    private class Step(val input: String, val step: JsonValue, val expected: String?)

    private fun assertSteps(rows: List<Step>) {
        val failures = rows.mapNotNull { r ->
            val got = run(r.input, r.step)
            if (got == j(r.expected)) null else "${r.step} on ${codes(r.input)}: got ${got.stringValue?.let(::codes)}, expected ${r.expected?.let(::codes)}"
        }
        if (failures.isNotEmpty()) fail(failures.joinToString("\n"))
    }

    /** The UTF-16 units of [s] in hex, for a failure message. */
    private fun codes(s: String): String = s.map { "%04X".format(it.code) }.joinToString(" ")

    @Test
    fun u1_withoutUEachHalfOfAPairIsOneUnit() {
        assertDart(
            listOf(
                units(".", "##", "####", "####", "##", "#\n##", gs = "####"),
                units("[^a]", "##", "a###", "####", "##", "a###"),
                units("\\S", "##", "####", "####", "##", "#\n##"),
                units("\\W", "##", "a##b", "####", "##", "a###"),
                units("\\D", "##", "####", "####", "##", "####"),
                units("[^]", "##", "####", "####", "##", "####"),
                units(".{2}", "#", "##", "##", "#", "a\n#", gs = "##"),
                units("^.\$", e, "a${e}b", "$e$e", d, "a\n$e", gm = "#\n$e"),
                units("^..\$", "#", "a${e}b", "$e$e", "#", "a\n$e", gm = "a\n#"),
                units("(.)", "##", "####", "####", "##", "#\n##", gs = "####"),
                units(".?", "###", "#####", "#####", "###", "##\n###", gs = "#####"),
                units("[$e]", "##", "a##b", "####", d, "a\n##"),
                units("[^$e]", e, "#$e#", "$e$e", "##", "##$e"),
                units("$e+", "#", "a#b", "##", d, "a\n#"),
                units("[${esc("D83D")}]", "#$eLo", "a#${eLo}b", "#$eLo#$eLo", d, "a\n#$eLo"),
                units(esc("D83D"), "#$eLo", "a#${eLo}b", "#$eLo#$eLo", d, "a\n#$eLo"),
                units(esc("DE00"), "$eHi#", "a$eHi#b", "$eHi#$eHi#", d, "a\n$eHi#"),
                units("[${esc("D800")}-${esc("DBFF")}]", "#$eLo", "a#${eLo}b", "#$eLo#$eLo", "#$dLo", "a\n#$eLo"),
                units("[${esc("DC00")}-${esc("DFFF")}]", "$eHi#", "a$eHi#b", "$eHi#$eHi#", "$dHi#", "a\n$eHi#"),
                units("[${esc("D83D")}${esc("DE00")}]", "##", "a##b", "####", d, "a\n##"),
                units(".(?=.)", "#$eLo", "###b", "###$eLo", "#$dLo", "a\n#$eLo", gs = "###$eLo"),
                units("(?<=.).", "$eHi#", "a###", "$eHi###", "$dHi#", "a\n$eHi#", gs = "a###"),
                units(".\$", "$eHi#", "a$e#", "$e$eHi#", "$dHi#", "a\n$eHi#", gm = "#\n$eHi#"),
                units("[$d]", e, "a${e}b", "$e$e", "##", "a\n$e"),
            ).flatten(),
        )
    }

    @Test
    fun u1_guard_withoutUEmptyMatchesEdgesAndWholePairsKeepTheirMatches() {
        // Kotlin's already: an empty match steps one unit, `\b` and `^` find no edge inside a pair,
        // and a pair written whole matches a pair.
        assertDart(
            listOf(
                units("a??", "#$eHi#$eLo#", "#a#$eHi#$eLo#b#", "#$eHi#$eLo#$eHi#$eLo#", "#$dHi#$dLo#", "#a#\n#$eHi#$eLo#"),
                units("", "#$eHi#$eLo#", "#a#$eHi#$eLo#b#", "#$eHi#$eLo#$eHi#$eLo#", "#$dHi#$dLo#", "#a#\n#$eHi#$eLo#"),
                units("(?:)", "#$eHi#$eLo#", "#a#$eHi#$eLo#b#", "#$eHi#$eLo#$eHi#$eLo#", "#$dHi#$dLo#", "#a#\n#$eHi#$eLo#"),
                units("x*", "#$eHi#$eLo#", "#a#$eHi#$eLo#b#", "#$eHi#$eLo#$eHi#$eLo#", "#$dHi#$dLo#", "#a#\n#$eHi#$eLo#"),
                units("\\b", e, "#a#$e#b#", "$e$e", d, "#a#\n$e"),
                units("\\B", "#$eHi#$eLo#", "a$eHi#${eLo}b", "#$eHi#$eLo#$eHi#$eLo#", "#$dHi#$dLo#", "a\n#$eHi#$eLo#"),
                units("\$", "$e#", "a${e}b#", "$e$e#", "$d#", "a\n$e#", gm = "a#\n$e#"),
                units("^", "#$e", "#a${e}b", "#$e$e", "#$d", "#a\n$e", gm = "#a\n#$e"),
                units(e, "#", "a#b", "##", d, "a\n#"),
                units("(?:$e)+", "#", "a#b", "#", d, "a\n#"),
                units("${esc("D83D")}${esc("DE00")}", "#", "a#b", "##", d, "a\n#"),
                units(d, e, "a${e}b", "$e$e", "#", "a\n$e"),
            ).flatten(),
        )
    }

    @Test
    fun u1_withoutUClassesAndRangesHoldUnits() {
        // A range is read on Dart's units: `[a-E]` is a to the high half, then the low half; the
        // halves a range covers are in it, a private-use character the input holds is itself.
        assertDart(
            listOf(
                units("[a-${esc("D83D")}]", "#$eLo", "##$eLo#", "$p0#$eLo$p1", "#$p2#$eLo", inputs = classInputs),
                units("[${esc("D83D")}-${esc("DE00")}]", "##", "a##b", "$p0##$p1", "b$p2##", inputs = classInputs),
                units("[${esc("D83D")}-${esc("E000")}]", "##", "a##b", "###$p1", "b$p2##", inputs = classInputs),
                units("[^${esc("E000")}-${esc("F8FF")}]", "##", "####", "$p0##$p1", "#$p2##", inputs = classInputs),
                units("[$e-$e2]", null, null, null, null, inputs = classInputs),
                units("[a-$e]", "##", "####", "$p0##$p1", "#$p2##", inputs = classInputs),
                units("[^${esc("D83D")}]", "$eHi#", "#$eHi##", "#$eHi##", "##$eHi#", inputs = classInputs),
                units("[${esc("0000")}-${esc("FFFF")}]", "##", "####", "####", "####", inputs = classInputs),
                units("[^${esc("0000")}-${esc("FFFF")}]", e, "a${e}b", "$p0$e$p1", "b$p2$e", inputs = classInputs),
                units("[${esc("D800")}-${esc("DFFF")}]+", "#", "a#b", "$p0#$p1", "b$p2#", inputs = classInputs),
                units("[$eHi-$eLo]", "##", "a##b", "$p0##$p1", "b$p2##", inputs = classInputs),
                units("[$eHi]", "#$eLo", "a#${eLo}b", "$p0#$eLo$p1", "b$p2#$eLo", inputs = classInputs),
                units(eHi, "#$eLo", "a#${eLo}b", "$p0#$eLo$p1", "b$p2#$eLo", inputs = classInputs),
                units("$eLo|$eHi", "##", "a##b", "$p0##$p1", "b$p2##", inputs = classInputs),
                units("[\\d-${esc("D83D")}]", "#$eLo", "a#${eLo}b", "$p0#$eLo$p1", "b$p2#$eLo", inputs = classInputs),
                units("[${esc("D83D")}-\\w]", "#$eLo", "##$eLo#", "$p0#$eLo$p1", "#$p2#$eLo", inputs = classInputs),
                units("[\\$e]", "##", "a##b", "$p0##$p1", "b$p2##", inputs = classInputs),
                units(".", "###", "####", "####", inputs = puaInputs),
                units("[^a]", "###", "####", "####", inputs = puaInputs),
                units("\\S", "###", "####", "####", inputs = puaInputs),
                units(".{2}", "#$eLo", "##", "##", inputs = puaInputs),
            ).flatten(),
        )
    }

    @Test
    fun u1_guard_withoutUPrivateUseCharactersAndReversedRangesStayDarts() {
        // A reversed range is Dart's error on units too, and a private-use character in the input or
        // the pattern is only itself; an input that holds every one of them runs unmasked.
        assertDart(
            listOf(
                units("[${esc("E000")}-${esc("F8FF")}]", e, "a${e}b", "#$e#", "b#$e", inputs = classInputs),
                units("[${esc("E000")}-${esc("D83D")}]", null, null, null, null, inputs = classInputs),
                units("[${esc("DE00")}-${esc("D83D")}]", null, null, null, null, inputs = classInputs),
                units("[a$e]+", "#", "#b", "$p0#$p1", "b$p2#", inputs = classInputs),
                units("[^${e}a]", e, "a$e#", "#$e#", "##$e", inputs = classInputs),
                units("\\$e", "#", "a#b", "$p0#$p1", "b$p2#", inputs = classInputs),
                units("[${esc("E001")}]", e, "a${e}b", "$p0$e#", "b$p2$e", inputs = classInputs),
                units(esc("E000"), e, "a${e}b", "#$e$p1", "b$p2$e", inputs = classInputs),
                units("[$p0-$p1]", e, "a${e}b", "#$e#", "b$p2$e", inputs = classInputs),
                units("[$p0-${esc("E002")}]", e, "a${e}b", "#$e#", "b#$e", inputs = classInputs),
                units(esc("E000"), "#$e", "$e#$p1", "##$e", inputs = puaInputs),
                units("[${esc("E000")}]", "#$e", "$e#$p1", "##$e", inputs = puaInputs),
                units(p0, "#$e", "$e#$p1", "##$e", inputs = puaInputs),
                units("[$p0]", "#$e", "$e#$p1", "##$e", inputs = puaInputs),
                units("^.\$", "$p0$e", "$e$p0$p1", "$p0$p0$e", inputs = puaInputs),
                units("(.)\\1", "$p0$e", "$e$p0$p1", "#$e", inputs = puaInputs),
            ).flatten() +
                listOf(
                    Rx("[${esc("E000")}-${esc("F8FF")}]+", "g", allPua + e, "#$e"),
                    Rx("x", "g", allPua + e, allPua + e),
                ),
        )
    }

    @Test
    fun u1_theGroupsAndTheMatchAreReadFromTheInput() {
        // `$1`, `{{value}}`, the text between matches and the match-only result are the input's
        // units, a lone half among them.
        assertSteps(
            listOf(
                Step(e, rep("(.)", "g", "[\$1]"), "[$eHi][$eLo]"),
                Step(e, rep("(.)", "gi", "[\$1]"), "[$eHi][$eLo]"),
                Step(e, rep("(.)", "", "[\$1]"), "[$eHi]$eLo"),
                Step(e, rep("(.)(.)", "g", "\$2\$1"), "$eLo$eHi"),
                Step(e, rep("(.)(.)", "gi", "\$2\$1"), "$eLo$eHi"),
                Step(e, rep("(.)(.)", "", "\$2\$1"), "$eLo$eHi"),
                Step("a$e", rep(".", "g", "<{{value}}>"), "<a><$eHi><$eLo>"),
                Step("a$e", rep(".", "gi", "<{{value}}>"), "<a><$eHi><$eLo>"),
                Step("a$e", rep(".", "", "<{{value}}>"), "<a>$e"),
                Step("${e}b", rep("(${esc("D83D")})", "g", "[\$1]"), "[$eHi]${eLo}b"),
                Step("${e}b", rep("(${esc("D83D")})", "gi", "[\$1]"), "[$eHi]${eLo}b"),
                Step("${e}b", rep("(${esc("D83D")})", "", "[\$1]"), "[$eHi]${eLo}b"),
                Step("${e}b", rep("(${esc("DE00")})(b)", "g", "[\$2\$1]"), "$eHi[b$eLo]"),
                Step("${e}b", rep("(${esc("DE00")})(b)", "gi", "[\$2\$1]"), "$eHi[b$eLo]"),
                Step("${e}b", rep("(${esc("DE00")})(b)", "", "[\$2\$1]"), "$eHi[b$eLo]"),
                Step(e, obj("type" to "regex", "pattern" to ".", "flags" to "g"), eHi),
                Step(e, obj("type" to "regex", "pattern" to ".", "flags" to "gi"), eHi),
                Step(e, obj("type" to "regex", "pattern" to ".", "flags" to ""), eHi),
                Step(e, obj("type" to "regex", "pattern" to esc("DE00"), "flags" to "g"), eLo),
                Step(e, obj("type" to "regex", "pattern" to esc("DE00"), "flags" to "gi"), eLo),
                Step(e, obj("type" to "regex", "pattern" to esc("DE00"), "flags" to ""), eLo),
                Step("$e$e", rep("(.)\\1", "g", "[\$1]"), "$e$e"),
                Step("$e$e", rep("(.)\\1", "gi", "[\$1]"), "$e$e"),
                Step("$e$e", rep("(.)\\1", "", "[\$1]"), "$e$e"),
            ),
        )
    }

    @Test
    fun u1_theMatchesOpReadsUnitsToo() {
        // `matches` takes no flags: Dart's `RegExp(regex).hasMatch`, without `u`.
        val rows = listOf(
            Triple(e, "^.\$", false),
            Triple(d, "^.\$", false),
            Triple("x", "^.\$", true),
            Triple(e, "^..\$", true),
            Triple(d, "^..\$", true),
            Triple("x", "^..\$", false),
            Triple(e, "^${esc("D83D")}", true),
            Triple(d, "^${esc("D83D")}", false),
            Triple(e, "${esc("DE00")}\$", true),
            Triple(d, "${esc("DE00")}\$", false),
            Triple(e, "^$e\$", true),
            Triple(d, "^$e\$", false),
            Triple(e, "^[$e]\$", false),
            Triple(d, "^[$e]\$", false),
            Triple(e, "^[$e]{2}\$", true),
            Triple(d, "^[$e]{2}\$", false),
            Triple(e, "^$dU\$", false),
            Triple(d, "^$dU\$", false),
        )
        val wrong = rows.filter { (input, regex, want) -> holds(obj("op" to "matches", "str" to s(input), "regex" to regex)) != want }
        assertEquals(emptyList(), wrong.map { (input, regex, want) -> "$regex on ${codes(input)}: expected $want" })
    }

    /** Each ordered pair of two letters of a fold class above U+FFFF, as strings (282 classes, 564 pairs). */
    private val astralPairs: List<Pair<String, String>> by lazy {
        DartFoldClasses.classes.filter { k -> k.any { it > 0xFFFF } }.flatMap { k ->
            k.flatMap { a -> k.filter { it != a }.map { b -> String(Character.toChars(a)) to String(Character.toChars(b)) } }
        }
    }

    @Test
    fun u2_withoutULettersAboveTheBmpDoNotFold() {
        // Dart folds units under `i` without `u`, and a half has no partner: 𐐀 matches only itself,
        // `[𐐀]` the high half it shares with 𐐨, and no reference repeats the other letter.
        assertDart(
            listOf(
                Rx(dU, "gi", d, d),
                Rx("[$dU]", "gi", d, "#$dLo"),
                Rx("($dU)\\1", "gi", dU + d, dU + d),
                Rx("(.)\\1", "gi", dU + d, dU + d),
            ),
        )
        // Every class above U+FFFF, both orders: the probe's 2 256 rows for x and y, each printed by
        // Dart as this rule, `[x]` marking the units of y that x holds.
        assertDart(
            astralPairs.flatMap { (x, y) ->
                listOf(
                    Rx(x, "gi", y, y),
                    Rx("[$x]", "gi", y, y.map { if (it in x) "#" else "$it" }.joinToString("")),
                    Rx("($x)\\1", "gi", x + y, x + y),
                    Rx("(.)\\1", "gi", x + y, x + y),
                )
            },
        )
    }

    @Test
    fun u2_guard_withULettersAboveTheBmpFold() {
        // With `u` the JVM folds these letters itself. JDK 21 (Unicode 15) and 17 (Unicode 13) fold
        // only the pairs their Unicode has, and JDK 17's case-insensitive backreference never repeats
        // a capture above U+FFFF (it throws at the input's end): the platform's difference, not the
        // SDK's, so those rows are left out there.
        val ci = Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE
        fun jvmFolds(x: String, y: String) = Pattern.compile(Pattern.quote(x), ci).matcher(y).matches()
        val jvmRepeats = runCatching { Pattern.compile("(.)\\1", ci).matcher(dU + dU).find() }.getOrDefault(false)
        var leftOut = 0
        fun kept(runs: Boolean, rows: List<Rx>): List<Rx> = if (runs) rows else emptyList<Rx>().also { leftOut += rows.size }
        val rows = listOf(Rx(dU, "giu", d, "#"), Rx("[$dU]", "giu", d, "#")) +
            kept(jvmRepeats, listOf(Rx("($dU)\\1", "giu", dU + d, "#"), Rx("(.)\\1", "giu", dU + d, "#"))) +
            astralPairs.flatMap { (x, y) ->
                val folds = jvmFolds(x, y)
                kept(folds, listOf(Rx(x, "giu", y, "#"), Rx("[$x]", "giu", y, "#"))) +
                    kept(folds && jvmRepeats, listOf(Rx("($x)\\1", "giu", x + y, "#"), Rx("(.)\\1", "giu", x + y, "#")))
            }
        if (Runtime.version().feature() >= 24) assertEquals(0, leftOut, "rows left out on a JDK with Unicode 16")
        assertDart(rows)
    }

    @Test
    fun k1_withUAnEmptyMatchAtAPairSkipsItsSecondHalf() {
        assertDart(
            listOf(
                units("a??", "#$e#", "#a#$e#b#", "#$e#$e#", "#$d#", "#a#\n#$e#", flags = withU),
                units("", "#$e#", "#a#$e#b#", "#$e#$e#", "#$d#", "#a#\n#$e#", flags = withU),
                units("(?:)", "#$e#", "#a#$e#b#", "#$e#$e#", "#$d#", "#a#\n#$e#", flags = withU),
                units("x*", "#$e#", "#a#$e#b#", "#$e#$e#", "#$d#", "#a#\n#$e#", flags = withU),
                units("\\B", "#$e#", "a$eHi#${eLo}b", "#$e#$e#", "#$d#", "a\n#$e#", flags = withU),
                units("^|x*", "#$e#", "#$e#$e#", "#a#$e#", "#$e#a#", inputs = stepInputs, flags = withU),
                units("(?<=a)|x*", "#$e#", "#$e#$e#", "#a#$e#", "#$e#a#", inputs = stepInputs, flags = withU),
                units("(?:)|$e", "#$e#", "#$e#$e#", "#a#$e#", "#$e#a#", inputs = stepInputs, flags = withU),
                units("x*|.", "#$e#", "#$e#$e#", "#a#$e#", "#$e#a#", inputs = stepInputs, flags = withU),
                units("(x*)", "#$e#", "#$e#$e#", "#a#$e#", "#$e#a#", inputs = stepInputs, flags = withU),
            ).flatten(),
        )
        assertSteps(
            listOf(
                Step(e, rep("(x*)", "gu", "[\$1]"), "[]$e[]"),
                Step(e, rep("(x*)", "giu", "[\$1]"), "[]$e[]"),
                Step(e, rep("x*", "gu", "[{{value}}]"), "[]$e[]"),
                Step(e, rep("x*", "giu", "[{{value}}]"), "[]$e[]"),
            ),
        )
    }

    @Test
    fun k1_guard_withUTheSearchStillTriesEveryUnit() {
        // Dart's search tries every unit, so `\B` finds the edge between a pair's halves; only the
        // step after an empty match skips a pair, and `^` and lookbehinds read the whole input.
        assertDart(
            listOf(
                listOf(Rx("\\B", "gu", "a${e}b", "a$eHi#${eLo}b"), Rx("\\B", "giu", "a${e}b", "a$eHi#${eLo}b")),
                units(".", "#", "###", "##", "#", "#\n#", flags = withU),
                units("[^a]", "#", "a##", "##", "#", "a##", flags = withU),
                units("\\S", "#", "###", "##", "#", "#\n#", flags = withU),
                units("\\W", "#", "a#b", "##", "#", "a##", flags = withU),
                units("\\D", "#", "###", "##", "#", "###", flags = withU),
                units("[^]", "#", "###", "##", "#", "###", flags = withU),
                units(".{2}", e, "#b", "#", d, "a\n$e", flags = withU),
                units("^.\$", "#", "a${e}b", "$e$e", "#", "a\n$e", flags = withU),
                units("^..\$", e, "a${e}b", "#", d, "a\n$e", flags = withU),
                units("(.)", "#", "###", "##", "#", "#\n#", flags = withU),
                units(".?", "##", "####", "###", "##", "##\n##", flags = withU),
                units("\\b", e, "#a#$e#b#", "$e$e", d, "#a#\n$e", flags = withU),
                units("\$", "$e#", "a${e}b#", "$e$e#", "$d#", "a\n$e#", flags = withU),
                units("^", "#$e", "#a${e}b", "#$e$e", "#$d", "#a\n$e", flags = withU),
                units("[$e]", "#", "a#b", "##", d, "a\n#", flags = withU),
                units("[^$e]", e, "#$e#", "$e$e", "#", "##$e", flags = withU),
                units(e, "#", "a#b", "##", d, "a\n#", flags = withU),
                units("$e+", "#", "a#b", "#", d, "a\n#", flags = withU),
                units("(?:$e)+", "#", "a#b", "#", d, "a\n#", flags = withU),
                units("[${esc("D83D")}]", e, "a${e}b", "$e$e", d, "a\n$e", flags = withU),
                units(esc("D83D"), e, "a${e}b", "$e$e", d, "a\n$e", flags = withU),
                units(esc("DE00"), e, "a${e}b", "$e$e", d, "a\n$e", flags = withU),
                units("[${esc("D800")}-${esc("DBFF")}]", e, "a${e}b", "$e$e", d, "a\n$e", flags = withU),
                units("[${esc("DC00")}-${esc("DFFF")}]", e, "a${e}b", "$e$e", d, "a\n$e", flags = withU),
                units("${esc("D83D")}${esc("DE00")}", "#", "a#b", "##", d, "a\n#", flags = withU),
                units("[${esc("D83D")}${esc("DE00")}]", "#", "a#b", "##", d, "a\n#", flags = withU),
                units(".(?=.)", e, "##b", "#$e", d, "a\n$e", flags = withU),
                units("(?<=.).", e, "a##", "$e#", d, "a\n$e", flags = withU),
                units(".\$", "#", "a$e#", "$e#", "#", "a\n#", flags = withU),
                units("[$d]", e, "a${e}b", "$e$e", "#", "a\n$e", flags = withU),
                units(d, e, "a${e}b", "$e$e", "#", "a\n$e", flags = withU),
                units("(?<=$e)|^", "#$e#", "#$e#$e#", "#a$e#", "#$e#a", inputs = stepInputs, flags = withU),
                units("(?<=.)", "$e#", "$e#$e#", "a#$e#", "$e#a#", inputs = stepInputs, flags = withU),
                units("x*(?=$e)", "#$e", "#$e#$e", "a#$e", "#${e}a", inputs = stepInputs, flags = withU),
            ).flatten(),
        )
    }

    // MARK: S16 — backreferences under i (row 23b.38)
    // Expected values from Dart 3.14.0. Under `i` Dart compares a backreference by upper case without
    // `u` and by simple case folding with it; the JVM compares by upper case and by the lower case of
    // that. So without `u` Dart keeps the Kelvin, Ångström and ohm signs, ſ, ϴ, ß, ẞ and the Greek
    // letters with iota subscript apart from the letters the JVM folds them with, under both ı and İ
    // meet no I or i, and with `u` Dart joins ΐ with ΐ, ΰ with ΰ and ﬅ with ﬆ, which the JVM keeps apart.

    /** The code points [hex], space-separated, as a string. */
    private fun cps(hex: String): String = hex.split(' ').joinToString("") { String(Character.toChars(it.toInt(16))) }

    /** The engine's fold classes Dart splits without `u`, 33: Dart's classes in each, `|` between them. */
    private val splitWithoutU: List<List<String>> = listOf(
        "004B 006B | 212A", "0053 0073 | 017F", "00C5 00E5 | 212B", "0398 03B8 03D1 | 03F4", "03A9 03C9 | 2126",
        "00DF | 1E9E", "1FB3 | 1FBC", "1FC3 | 1FCC", "1FF3 | 1FFC",
    ).plus(listOf(0x1F80, 0x1F90, 0x1FA0).flatMap { base -> (0..7).map { "%04X | %04X".format(base + it, base + 8 + it) } })
        .map { row -> row.split(" | ").map(::cps) }

    /** Each ordered pair of letters from two of Dart's classes in one of [splitWithoutU]: 78. */
    private val splitPairs: List<Pair<String, String>> = splitWithoutU.flatMap { parts ->
        parts.flatMap { a -> parts.filter { it != a }.flatMap { b -> a.flatMap { x -> b.map { y -> "$x" to "$y" } } } }
    }

    @Test
    fun b1_withoutUDartKeepsTheseLettersApartInABackreference() {
        assertEquals(78, splitPairs.size)
        assertDart(splitPairs.flatMap { (x, y) -> listOf(Rx("($x)\\1", "gi", x + y, x + y), Rx("(.)\\1", "gi", x + y, x + y)) })
        // `i` from a modifier group and `\k<name>` compare so too, and a pair's halves are masked beside the letters.
        val sLong = "s" + cps("017F")
        assertDart(
            listOf(
                Rx("(?i:(.)\\1)", "g", sLong, sLong),
                Rx("(.)(?i:\\1)", "g", sLong, sLong),
                Rx("(?<a>.)\\k<a>", "gi", sLong, sLong),
                Rx("(?i:(.)\\1)", "g", cps("00DF 1E9E"), cps("00DF 1E9E")),
                Rx("(.)\\1", "gi", e + sLong, e + sLong),
                Rx("(.)\\1", "gi", "a$e${cps("212A")}k", "a$e${cps("212A")}k"),
            ),
        )
    }

    @Test
    fun b1_guard_withUAndWithinDartsClassesTheyStillMatch() {
        // Kotlin's already: with `u` Dart folds them simply, and the letters it does fold together still match.
        val within = splitWithoutU.flatMap { parts -> parts.filter { it.length > 1 } }
            .flatMap { k -> k.flatMap { x -> k.filter { it != x }.map { y -> "$x$y" } } }
        val sLong = "s" + cps("017F")
        assertDart(
            splitPairs.flatMap { (x, y) -> listOf(Rx("($x)\\1", "giu", x + y, "#"), Rx("(.)\\1", "giu", x + y, "#")) } +
                within.flatMap { xy -> listOf(Rx("(${xy[0]})\\1", "gi", xy, "#"), Rx("(.)\\1", "gi", xy, "#")) } +
                listOf(
                    Rx("(?i:(.)\\1)", "gu", sLong, "#"),
                    Rx("(.)\\1", "g", sLong, sLong),
                    Rx("(?-i:(.)\\1)", "gi", sLong, sLong),
                    Rx("(?-i:(.)\\1)", "gi", "sS", "sS"),
                    Rx("(.)\\1", "gi", cps("017F 017F"), "#"),
                    Rx("(.)\\1", "gi", "$e$e${cps("017F 017F")}", "$e$e#"),
                    // An input that holds every private-use character leaves no stand-in, so the run is unmasked:
                    // Dart's here, a known difference on "sſ" (Kotlin "#").
                    Rx("(.)\\1", "gi", allPua + cps("017F 017F"), "$allPua#"),
                ),
        )
    }

    @Test
    fun b1_withUDartJoinsLettersTheJvmKeepsApart() {
        // ΐ U+0390 and U+1FD3, ΰ U+03B0 and U+1FE3, ﬅ U+FB05 and ﬆ U+FB06: one simple fold class each in
        // Dart, no case mapping between them on the JVM. Without `u` Dart keeps them apart too.
        val pairs = listOf("0390 1FD3", "1FD3 0390", "03B0 1FE3", "1FE3 03B0", "FB05 FB06", "FB06 FB05").map(::cps)
        assertDart(pairs.flatMap { xy -> listOf(Rx("(${xy[0]})\\1", "giu", xy, "#"), Rx("(.)\\1", "giu", xy, "#")) })
        assertDart(pairs.flatMap { xy -> listOf(Rx("(${xy[0]})\\1", "gi", xy, xy), Rx("(.)\\1", "gi", xy, xy)) })
        // A known limit (gate 08): the two letters share a stand-in, so in a masked run a `(?-i:…)` group, or a
        // part outside a `(?i:` group, can't tell them apart. Dart leaves U+1FD3 unchanged; Kotlin matches it.
        assertDart(listOf(Rx("(x)\\1|(?-i:${cps("0390")})", "giu", cps("1FD3"), "#")))
    }

    @Test
    fun b2_dotlessAndDottedIMeetNoIInABackreference() {
        // The JVM pairs ı U+0131 with I (its upper case) and İ U+0130 with i (its lower case); Dart pairs neither.
        val pairs = listOf("Iı", "iı", "ıI", "ıi", "iİ", "İi", "Iİ", "İI", "İi${Char(0x307)}")
        assertDart(
            listOf("gi", "giu").flatMap { f ->
                pairs.flatMap { xy -> listOf(Rx("(${xy[0]})\\1", f, xy, xy), Rx("(.)\\1", f, xy, xy)) }
            },
        )
    }

    @Test
    fun b2_guard_eachStillMatchesItself() {
        assertDart(
            listOf("gi", "giu").flatMap { f ->
                listOf("ıı", "İİ", "ii", "II").flatMap { xx -> listOf(Rx("(${xx[0]})\\1", f, xx, "#"), Rx("(.)\\1", f, xx, "#")) } +
                    Rx("(i)\\1", f, "iI", "#")
            },
        )
    }

    @Test
    fun b3_guard_noLetterMatchesTheLettersItFoldsToInABackreference() {
        // Kotlin's already (ICU, Swift's engine, compares by full folding): ß, ﬀ U+FB00 and ŉ U+0149 against
        // the letters they fold to, i and U+0307 against İ.
        val ff = cps("FB00")
        val napostrophe = cps("0149")
        val apostropheN = cps("02BC") + "n"
        val rows = listOf(
            Triple("(ß)\\1", "ßss", "ßss"),
            Triple("(ss)\\1", "ssß", "ssß"),
            Triple("(.)\\1", "ßss", "ß#"),
            Triple("($ff)\\1", "${ff}ff", "${ff}ff"),
            Triple("(ff)\\1", "ff$ff", "ff$ff"),
            Triple("(.)\\1", "${ff}ff", "$ff#"),
            Triple("($napostrophe)\\1", napostrophe + apostropheN, napostrophe + apostropheN),
            Triple("($apostropheN)\\1", apostropheN + napostrophe, apostropheN + napostrophe),
            Triple("(.)\\1", napostrophe + apostropheN, napostrophe + apostropheN),
            Triple("(i${Char(0x307)})\\1", "i${Char(0x307)}İ", "i${Char(0x307)}İ"),
        )
        assertDart(listOf("gi", "giu").flatMap { f -> rows.map { (p, input, out) -> Rx(p, f, input, out) } })
        // With `u` Dart folds ß and ẞ together.
        assertDart(listOf(Rx("(ß)\\1", "giu", "ßẞ", "#"), Rx("(ẞ)\\1", "giu", "ẞß", "#")))
    }

    /** Inputs for masked runs: the letters masked without `u` and with it, beside those they fold with. */
    private val maskedInputs = listOf("0073 0053 017F 006B 004B 212A", "0069 0049 0131 0130", "00DF 1E9E 03B8 03F4 1F80 1F88", "0390 1FD3 03B0 1FE3 FB05 FB06")
        .map(::cps)

    /**
     * [construct] in a run masked for a backreference under `i`, after `(x)\1|` under `gi` and `giu` and
     * after `(?i:(x)\1)|` under `g` and `gu`, on each of [maskedInputs]. [marks] holds one entry per flags
     * in [flags], a word per input: `#` where Dart replaces that letter, `.` where it keeps it.
     */
    private fun masked(construct: String, vararg marks: String, flags: List<String> = listOf("gi", "giu", "g", "gu")): List<Rx> {
        assertEquals(flags.size, marks.size, construct)
        return flags.zip(marks).flatMap { (f, m) ->
            val prefix = if ('i' in f) "(x)\\1|" else "(?i:(x)\\1)|"
            maskedInputs.zip(m.split(' ')).map { (input, word) ->
                Rx(prefix + construct, f, input, input.indices.joinToString("") { if (word[it] == '#') "#" else "${input[it]}" })
            }
        }
    }

    @Test
    fun b1_guard_inAMaskedRunLettersClassesEscapesAndPropertiesStayDarts() {
        // Kotlin's already, unmasked: in a masked run each stand-in matches where Dart matches its letter. Under
        // `gu` a `(?i:` group gives Dart's `\w` outside it ſ and the Kelvin sign too, a difference of its own, and
        // outside it U+0390 is the known limit above (it shares U+1FD3's stand-in).
        assertDart(
            listOf(
                masked("ſ", "..#... .... ...... ......", "###... .... ...... ......", "..#... .... ...... ......", "..#... .... ...... ......"),
                masked("s", "##.... .... ...... ......", "###... .... ...... ......", "#..... .... ...... ......", "#..... .... ...... ......"),
                masked("${cps("212A")}", ".....# .... ...... ......", "...### .... ...... ......", ".....# .... ...... ......", ".....# .... ...... ......"),
                masked("ı", "...... ..#. ...... ......", "...... ..#. ...... ......", "...... ..#. ...... ......", "...... ..#. ...... ......"),
                masked("İ", "...... ...# ...... ......", "...... ...# ...... ......", "...... ...# ...... ......", "...... ...# ...... ......"),
                masked("I", "...... ##.. ...... ......", "...... ##.. ...... ......", "...... .#.. ...... ......", "...... .#.. ...... ......"),
                masked("ß", "...... .... #..... ......", "...... .... ##.... ......", "...... .... #..... ......", "...... .... #..... ......"),
                masked("${cps("03F4")}", "...... .... ...#.. ......", "...... .... ..##.. ......", "...... .... ...#.. ......", "...... .... ...#.. ......"),
                masked("${cps("1F88")}", "...... .... .....# ......", "...... .... ....## ......", "...... .... .....# ......", "...... .... .....# ......"),
                masked("${cps("0390")}", "...... .... ...... #.....", "...... .... ...... ##....", "...... .... ...... #.....", flags = listOf("gi", "giu", "g")),
                masked("${esc("017F")}", "..#... .... ...... ......", "###... .... ...... ......", "..#... .... ...... ......", "..#... .... ...... ......"),
                masked("${esc("0131")}", "...... ..#. ...... ......", "...... ..#. ...... ......", "...... ..#. ...... ......", "...... ..#. ...... ......"),
                masked("\\xDF", "...... .... #..... ......", "...... .... ##.... ......", "...... .... #..... ......", "...... .... #..... ......"),
                masked("[ſ]", "..#... .... ...... ......", "###... .... ...... ......", "..#... .... ...... ......", "..#... .... ...... ......"),
                masked("[^ſ]", "##.### #### ###### ######", "...### #### ###### ######", "##.### #### ###### ######", "##.### #### ###### ######"),
                masked("[^s]", "..#### #### ###### ######", "...### #### ###### ######", ".##### #### ###### ######", ".##### #### ###### ######"),
                masked("[ı]", "...... ..#. ...... ......", "...... ..#. ...... ......", "...... ..#. ...... ......", "...... ..#. ...... ......"),
                masked("[^ı]", "###### ##.# ###### ######", "###### ##.# ###### ######", "###### ##.# ###### ######", "###### ##.# ###### ######"),
                masked("[^I]", "###### ..## ###### ######", "###### ..## ###### ######", "###### #.## ###### ######", "###### #.## ###### ######"),
                masked("[^${cps("0390")}]", "###### #### ###### .#####", "###### #### ###### ..####", "###### #### ###### .#####", flags = listOf("gi", "giu", "g")),
                masked("[a-z]", "##.##. ##.. ...... ......", "###### ##.. ...... ......", "#..#.. #... ...... ......", "#..#.. #... ...... ......"),
                masked("[^a]", "###### #### ###### ######", "###### #### ###### ######", "###### #### ###### ######", "###### #### ###### ######"),
                masked("[${esc("0100")}-${esc("017F")}]", "..#... ..## ...... ......", "###... ..## ...... ......", "..#... ..## ...... ......", "..#... ..## ...... ......"),
                masked("[${esc("0130")}-${esc("0131")}]", "...... ..## ...... ......", "...... ..## ...... ......", "...... ..## ...... ......", "...... ..## ...... ......"),
                masked("\\W", "..#..# ..## ###### ######", "...... ..## ###### ######", "..#..# ..## ###### ######", flags = listOf("gi", "giu", "g")),
                masked("\\w", "##.##. ##.. ...... ......", "###### ##.. ...... ......", "##.##. ##.. ...... ......", flags = listOf("gi", "giu", "g")),
                masked(".", "###### #### ###### ######", "###### #### ###### ######", "###### #### ###### ######", "###### #### ###### ######"),
                masked("[\\W]", "..#..# ..## ###### ######", "...... ..## ###### ######", "..#..# ..## ###### ######", flags = listOf("gi", "giu", "g")),
                masked("(?-i:ſ)", "..#... .... ...... ......", "..#... .... ...... ......", "..#... .... ...... ......", "..#... .... ...... ......"),
                masked("(?-i:[^ı])", "###### ##.# ###### ######", "###### ##.# ###### ######", "###### ##.# ###### ######", "###### ##.# ###### ######"),
                masked("(?i:ſ)", "..#... .... ...... ......", "###... .... ...... ......", "..#... .... ...... ......", "###... .... ...... ......"),
                masked("\\p{L}", "###### #### ###### ######", "###### #### ###### ######", flags = listOf("giu", "gu")),
                masked("\\P{L}", "...... .... ...... ......", "...... .... ...... ......", flags = listOf("giu", "gu")),
                masked("[\\p{Ll}]", "###### ###. ###### ######", "#.##.. #.#. #.#.#. ######", flags = listOf("giu", "gu")),
                masked("[^\\p{L}]", "...... .... ...... ......", "...... .... ...... ......", flags = listOf("giu", "gu")),
                masked("\\p{Lu}", "###### ##.# ####.. ......", ".#..## .#.# .#.#.. ......", flags = listOf("giu", "gu")),
            ).flatten(),
        )
    }

    @Test
    fun b1_theGroupsAndTheMatchAreTheInputsLetters() {
        val longS = cps("017F")
        val kelvin = cps("212A")
        assertSteps(
            listOf(
                Step("$longS$longS", rep("(.)\\1", "gi", "[\$1]"), "[$longS]"),
                Step("s$longS$longS", rep("(.)\\1", "gi", "[\$1]"), "s[$longS]"),
                Step("ııI", rep("(ı)\\1", "gi", "[\$1]"), "[ı]I"),
                Step("İİ", rep("(İ)\\1", "giu", "[\$1]"), "[İ]"),
                Step("ẞẞß", rep("(.)\\1", "gi", "<{{value}}>"), "<ẞẞ>ß"),
                Step(cps("0390 1FD3"), rep("(.)\\1", "giu", "[\$1|{{value}}]"), "[${cps("0390")}|${cps("0390 1FD3")}]"),
                Step("$e$kelvin$kelvin", rep("(.)\\1", "gi", "[\$1]"), "$e[$kelvin]"),
                Step("$kelvin$kelvin", obj("type" to "regex", "pattern" to "(.)\\1", "flags" to "gi"), "$kelvin$kelvin"),
            ),
        )
    }

    // MARK: S17 — letters the platform's Unicode lacks (row 23b.40)
    // Expected values from Dart 3.14.0. Under `i` the JVM folds only the case pairs its own Unicode
    // has: JDK 21 (Unicode 15) lacks 27 of Dart's fold classes, 5 in the BMP and Garay's 22, and
    // JDK 17 (Unicode 13) 67, 5 more in the BMP and Vithkuqi's 35 too. The SDK learns them on first
    // use and writes their letters as Dart's sets. JDK 24 and later lack none: there the seam sets
    // them, so that the same paths run.

    @AfterTest
    fun learnTheLaggingClassesAgain() {
        DartFoldClasses.laggingForTests = null
    }

    /** Sets the SDK's lagging classes to [classes], by their index in [DartFoldClasses.classes]. */
    private fun lagging(classes: List<IntArray>) {
        DartFoldClasses.laggingForTests = classes.map { DartFoldClasses.classOf[DartFoldClasses.letters.binarySearch(it[0])] }.toIntArray()
    }

    private fun hex(k: IntArray): String = k.joinToString(" ") { "%04X".format(it) }

    /**
     * [rows] as the SDK writes each pattern, run with the engine's own folding off: where the engine
     * folds a pair itself, only the SDK's writing then matches the letters as Dart does.
     */
    private fun assertWritten(rows: List<Rx>) {
        fun shown(s: String?): String = s?.map { if (it in ' '..'~') "$it" else "\\u%04X".format(it.code) }?.joinToString("") ?: "null"
        val failures = rows.mapNotNull { r ->
            val written = RegexSupport.asciiClasses(r.pattern, ignoreCase = 'i' in r.flags, unicode = 'u' in r.flags)
            val got = written?.let { Pattern.compile(it).matcher(r.input).replaceAll("#") }
            if (got == r.expected) null else "${shown(r.pattern)} /${r.flags} on ${shown(r.input)}: written ${shown(written)}, got ${shown(got)}"
        }
        if (failures.isNotEmpty()) fail(failures.joinToString("\n"))
    }

    /** The BMP classes of Unicode 16, which JDK 21 lacks, and of Unicode 14, which JDK 17 lacks too, in hex. */
    private val unicode16 = listOf("019B A7DC", "0264 A7CB", "1C89 1C8A", "A7CC A7CD", "A7DA A7DB")
    private val unicode14 = listOf("2C2F 2C5F", "A7C0 A7C1", "A7D0 A7D1", "A7D6 A7D7", "A7D8 A7D9")

    /** Dart's fold classes whose first letter is in [range]: Vithkuqi's 35 in U+10570-105BC, Garay's 22 in U+10D50-10D85. */
    private fun classesIn(range: IntRange): List<IntArray> = DartFoldClasses.classes.filter { it[0] in range }

    private fun codePoints(hex: String): IntArray = hex.split(' ').map { it.toInt(16) }.toIntArray()

    /** The classes JDK 21 does not fold in full, and those JDK 17 does not. */
    private val lacks21: List<IntArray> by lazy { unicode16.map(::codePoints) + classesIn(0x10D50..0x10D85) }
    private val lacks17: List<IntArray> by lazy {
        (unicode16 + unicode14).map(::codePoints) + classesIn(0x10570..0x105BC) + classesIn(0x10D50..0x10D85)
    }

    /** Each ordered pair of two letters of one of [classes], as strings. */
    private fun pairsOf(classes: List<IntArray>): List<Pair<String, String>> = classes.flatMap { k ->
        k.flatMap { a -> k.filter { it != a }.map { b -> String(Character.toChars(a)) to String(Character.toChars(b)) } }
    }

    /** ƛ U+019B and its capital U+A7DC (Unicode 16); 𐵐 U+10D50 and its small letter 𐵰 U+10D70 (Garay). */
    private val lambda = cps("019B")
    private val lambdaCap = cps("A7DC")
    private val garayA = cps("10D50")
    private val garaySmallA = cps("10D70")

    /** [s] as the `\uHHHH` escapes of its units: a letter above U+FFFF as a high half's then a low half's. */
    private fun escapes(s: String): String = s.map { esc("%04X".format(it.code)) }.joinToString("")

    /**
     * L1: a letter of a class the JVM lacks, as a letter, an escape or in `(?i:`, matches under `i`
     * each other letter of its class, one above U+FFFF only with `u` (without it two units, as at
     * S16), there as a letter, `\u{…}` or a pair of `\uHHHH` escapes, a high half's then a low
     * half's. The 724 rows over the classes JDK 17 lacks were each printed by Dart as this rule.
     */
    private val l1Rows: List<Rx> by lazy {
        listOf(
            Rx(lambda, "gi", lambdaCap, "#"),
            Rx(lambda, "giu", lambdaCap, "#"),
            Rx(lambdaCap, "gi", lambda, "#"),
            Rx(esc("019B"), "gi", lambdaCap, "#"),
            Rx(esc("019B"), "giu", lambdaCap, "#"),
            Rx(esc("A7DC"), "gi", lambda, "#"),
            Rx("(?i:$lambda)", "g", lambdaCap, "#"),
            Rx("(?-i:$lambda)", "gi", lambdaCap, lambdaCap),
            Rx("(?-i:$lambda)", "giu", lambdaCap, lambdaCap),
            Rx("$lambda+", "gi", lambdaCap + lambda + lambdaCap, "#"),
            Rx("$lambda+", "giu", lambdaCap + lambda + lambdaCap, "#"),
            Rx(garayA, "giu", garaySmallA, "#"),
            Rx("(?i:$garayA)", "gu", garaySmallA, "#"),
            Rx(garayA, "gi", garaySmallA, garaySmallA),
            Rx("\\u{10D50}", "giu", garaySmallA, "#"),
            Rx("\\u{10D70}", "giu", garayA, "#"),
            Rx("\\u{10570}", "giu", cps("10597"), "#"),
            Rx("(?-i:$garayA)", "giu", garaySmallA, garaySmallA),
            Rx("$garayA+", "giu", "$garaySmallA${garayA}b", "#b"),
            // With `u` a high half's escape and a low half's after it are one letter, as `\u{…}` is.
            Rx(escapes(garayA), "giu", garaySmallA, "#"),
            Rx("(?i:${escapes(garayA)})", "gu", garaySmallA, "#"),
            Rx("[${escapes(garayA)}]", "giu", garaySmallA, "#"),
            Rx(escapes(garayA), "giu", garayA, "#"),
            Rx("${escapes(garayA)}+", "giu", "$garaySmallA${garayA}b", "#b"),
            Rx(escapes(garayA), "gu", garaySmallA, garaySmallA),
            Rx("(?-i:${escapes(garayA)})", "giu", garaySmallA, garaySmallA),
            Rx(escapes(garayA), "gi", garaySmallA, garaySmallA),
            // A lone half, a low half before a high one, or a high half before `\u{…}` stays two halves.
            Rx(esc("D803"), "giu", garaySmallA, garaySmallA),
            Rx(esc("DD50") + esc("D803"), "giu", garaySmallA, garaySmallA),
            Rx(esc("DD50") + esc("D803"), "giu", "${Char(0xDD50)}${Char(0xD803)}", "#"),
            Rx(esc("D803") + "\\u{DD50}", "giu", garaySmallA, garaySmallA),
        ) + pairsOf(lacks17).flatMap { (x, y) ->
            if (x.length == 1) {
                listOf(Rx(x, "gi", y, "#"), Rx(x, "giu", y, "#"))
            } else {
                listOf(
                    Rx(x, "giu", y, "#"),
                    Rx("(?i:$x)", "gu", y, "#"),
                    Rx(x, "gi", y, y),
                    Rx(escapes(x), "giu", y, "#"),
                    Rx("(?i:${escapes(x)})", "gu", y, "#"),
                    Rx(escapes(x), "gi", y, y),
                )
            }
        }
    }

    /**
     * C1: a class under `i` that holds a letter of a class the JVM lacks matches each letter of that
     * class, a negated one none, a range the same. The 462 rows over the classes JDK 17 lacks were
     * each printed by Dart as this rule (without `u` the classes above U+FFFF are S16's units).
     */
    private val c1Rows: List<Rx> by lazy {
        val from = esc("0190")
        val to = esc("01A0")
        listOf(
            Rx("[$lambda]", "gi", lambdaCap, "#"),
            Rx("[$lambda]", "giu", lambdaCap, "#"),
            Rx("[^$lambda]", "giu", lambdaCap, lambdaCap),
            Rx("[$lambda-${cps("019C")}]", "giu", lambdaCap, "#"),
            Rx("[a$lambda]", "gi", lambdaCap, "#"),
            Rx("[a$lambda]", "giu", lambdaCap, "#"),
            Rx("[^a$lambda]", "gi", lambdaCap, lambdaCap),
            Rx("[^a$lambda]", "giu", "b", "#"),
            Rx("(?-i:[$lambda])", "gi", lambdaCap, lambdaCap),
            Rx("(?i:[$lambda])", "g", lambdaCap, "#"),
            Rx("(?i:[^$lambda])", "g", lambdaCap, lambdaCap),
            Rx("[$from-$to]", "gi", lambdaCap, "#"),
            Rx("[^$from-$to]", "gi", "${lambdaCap}a", "$lambdaCap#"),
            Rx("[$garayA]", "giu", garaySmallA, "#"),
            Rx("[^$garayA]", "giu", garaySmallA, garaySmallA),
            Rx("[$garayA-${cps("10D51")}]", "giu", garaySmallA, "#"),
            Rx("[\\u{10D50}]", "giu", garaySmallA, "#"),
            Rx("[^\\u{10D50}]", "giu", garaySmallA, garaySmallA),
            Rx("[a$garayA]", "giu", garaySmallA, "#"),
            Rx("[^a$garayA]", "giu", garaySmallA, garaySmallA),
            Rx("[^$garayA]", "giu", "b$garaySmallA", "#$garaySmallA"),
            Rx("(?i:[$garayA])", "gu", garaySmallA, "#"),
            Rx("(?i:[^$garayA])", "gu", garaySmallA, garaySmallA),
            Rx("[\\u{10D40}-\\u{10D5F}]", "giu", cps("10D7A"), "#"),
            Rx("[^\\u{10D40}-\\u{10D5F}]", "giu", cps("10D7A 10D80"), "${cps("10D7A")}#"),
        ) + pairsOf(lacks17).flatMap { (x, y) ->
            val next = String(Character.toChars(x.codePointAt(0) + 1))
            val flags = if (x.length == 1) listOf("gi", "giu") else listOf("giu")
            flags.flatMap { f -> listOf(Rx("[$x]", f, y, "#"), Rx("[^$x]", f, y, y), Rx("[$x-$next]", f, y, "#")) }
        }
    }

    @Test
    fun l1_theSdkLearnsTheClassesItsJvmDoesNotFoldInFull() {
        // Of Dart's classes, those with a letter the JVM's case-insensitive one-letter match does not
        // join to another of its class, less the table's: the JVM never joins U+0390 and U+1FD3, U+03B0
        // and U+1FE3, U+FB05 and U+FB06, whose letters the table writes as Dart's sets already.
        val learned = DartFoldClasses.lagging.map { hex(DartFoldClasses.classes[it]) }.sorted()
        val feature = Runtime.version().feature()
        when {
            feature == 17 -> assertEquals(lacks17.map(::hex).sorted(), learned)
            feature == 21 -> assertEquals(lacks21.map(::hex).sorted(), learned)
            feature >= 24 -> assertEquals(emptyList(), learned)
            else -> assertTrue(lacks17.map(::hex).containsAll(learned), learned.toString())
        }
    }

    @Test
    fun l1_lettersOfALaggingClassFoldAsInDart() {
        assertDart(l1Rows)
    }

    @Test
    fun l1_seam_theLettersOfTheClassesSetAreWrittenAsDartsSets() {
        // With the classes JDK 17 lacks set, every JVM runs the lagging paths, and the rows hold with
        // the engine's own folding off too.
        lagging(lacks17)
        assertDart(l1Rows)
        assertWritten(l1Rows)
    }

    @Test
    fun c1_aClassTakesTheLettersOfTheLaggingClassesItMeets() {
        assertDart(c1Rows)
    }

    @Test
    fun c1_seam_aClassTakesTheLettersOfTheClassesSet() {
        lagging(lacks17)
        assertDart(c1Rows)
        assertWritten(c1Rows)
    }

    @Test
    fun c1_seam_whatMeetsNoLaggingClassIsWrittenAsToday() {
        // A letter or class that meets no lagging class, and any pattern without `i`, is written the
        // same with the classes set as with none.
        val patterns = listOf("a", "ß", d, "[a]", "[^a-z]", "[\\d\\s]", "[ß]", "[^ß]", "[${esc("0100")}-${esc("017F")}]", "[$d]", "[^$d]", "\\p{Lu}", "[\\p{Ll}z]")
        val withoutI = listOf(lambda, "[$lambda]", "[^$lambda]", garayA, "[$garayA]", "[^$garayA]")
        fun written() = listOf(false, true).flatMap { u ->
            patterns.map { RegexSupport.asciiClasses(it, ignoreCase = true, unicode = u) } + withoutI.map { RegexSupport.asciiClasses(it, unicode = u) }
        }
        lagging(emptyList())
        val today = written()
        lagging(lacks17)
        assertEquals(today, written())
    }

    /**
     * R1: under `i` a backreference matches a letter of a class the JVM lacks to each other letter of
     * its class, as Dart does: `(x)\1` and `(.)\1` on x then y, mid-input too, and in `(?i:`, in the
     * BMP with `u` and without, above U+FFFF with `u` (without it two units, S16's). The 770 rows
     * over the classes JDK 17 lacks were each printed by Dart as this rule.
     */
    private val r1Rows: List<Rx> by lazy {
        pairsOf(lacks17).flatMap { (x, y) ->
            val bmp = x.length == 1
            (if (bmp) listOf("gi", "giu") else listOf("giu")).flatMap { f ->
                listOf(Rx("($x)\\1", f, x + y, "#"), Rx("(.)\\1", f, x + y, "#"), Rx("($x)\\1", f, "$x${y}z", "#z"), Rx("(.)\\1", f, "z$x${y}z", "z#z"))
            } + (if (bmp) listOf("g", "gu") else listOf("gu")).map { f -> Rx("(?i:($x)\\1)", f, x + y, "#") }
        }
    }

    /** R1 through escapes, classes and names, beside the other parts of a masked run and other masked characters. */
    private val r1Parts: List<Rx> by lazy {
        val supplementaryPua = cps("F0000")
        val longS = cps("017F")
        listOf(
            Rx("(${esc("019B")})\\1", "gi", lambda + lambdaCap, "#"),
            Rx("(${esc("019B")})\\1", "giu", lambda + lambdaCap, "#"),
            Rx("(\\u{10D50})\\1", "giu", garayA + garaySmallA, "#"),
            Rx("(${escapes(garayA)})\\1", "giu", garayA + garaySmallA, "#"),
            Rx("([$garayA])\\1", "giu", garayA + garaySmallA, "#"),
            Rx("([$lambda])\\1", "gi", lambda + lambdaCap, "#"),
            Rx("([^a])\\1", "giu", garayA + garaySmallA, "#"),
            Rx("(?<n>.)\\k<n>", "giu", garayA + garaySmallA, "#"),
            Rx("(?<n>.)\\k<n>", "gi", lambda + lambdaCap, "#"),
            Rx("(.)\\1", "giu", garayA + garayA, "#"),
            Rx("(.)\\1", "giu", garaySmallA + garaySmallA, "#"),
            Rx("(.)\\1", "gi", lambdaCap + lambdaCap, "#"),
            Rx("(.)\\1", "giu", garayA + garaySmallA + garaySmallA + garayA, "##"),
            Rx("(.)\\1+", "giu", "$garayA$garaySmallA${garayA}b", "#b"),
            // Letters of two classes: no reference joins them.
            Rx("(.)\\1", "giu", garayA + cps("10D51"), garayA + cps("10D51")),
            Rx("(.)\\1", "gi", lambda + cps("019C"), lambda + cps("019C")),
            // In a masked run the pattern's letters, escapes and classes match the stand-ins where Dart matches the letters.
            Rx("(.)\\1|(?-i:$garayA)", "giu", garayA, "#"),
            Rx("(.)\\1|(?-i:\\u{10D50})", "giu", garayA, "#"),
            Rx("(.)\\1|(?-i:${escapes(garayA)})", "giu", garayA, "#"),
            Rx("(.)\\1|(?-i:$lambda)", "gi", lambda, "#"),
            Rx("(.)\\1|(?-i:${esc("019B")})", "gi", lambda, "#"),
            Rx("(.)\\1|$garayA", "giu", garaySmallA, "#"),
            Rx("(.)\\1|\\u{10D50}", "giu", garaySmallA, "#"),
            Rx("(.)\\1|[$garayA]", "giu", garaySmallA, "#"),
            Rx("(.)\\1|[^$garayA]", "giu", "${garaySmallA}a", "$garaySmallA#"),
            Rx("(.)\\1|(?-i:[$garayA])", "giu", garayA, "#"),
            Rx("(.)\\1|[\\u{10D40}-\\u{10D5F}]", "giu", garaySmallA, "#"),
            Rx("(.)\\1|.", "giu", garayA, "#"),
            Rx("(.)\\1|[^a]", "giu", garayA, "#"),
            Rx("(.)\\1|^.\$", "giu", garayA, "#"),
            Rx("(.)\\1|$lambda", "gi", lambdaCap, "#"),
            Rx("(.)\\1|[$lambda]", "gi", lambdaCap, "#"),
            Rx("(.)\\1|[^$lambda]", "gi", "${lambdaCap}a", "$lambdaCap#"),
            Rx("(.)\\1|[${esc("0190")}-${esc("01A0")}]", "gi", lambdaCap, "#"),
            Rx("(?i:(.)\\1)|(?-i:$garayA)", "gu", garayA, "#"),
            Rx("(?i:(.)\\1)", "gu", "a$garayA${garaySmallA}b", "a#b"),
            // The stand-ins are characters neither the input nor the pattern holds; other masked characters keep theirs.
            Rx("(.)\\1", "giu", supplementaryPua + garayA + garaySmallA, "$supplementaryPua#"),
            Rx("(.)\\1", "giu", garayA + supplementaryPua + garaySmallA, garayA + supplementaryPua + garaySmallA),
            Rx("\\u{F0000}|(.)\\1", "giu", garayA + garaySmallA, "#"),
            Rx("[\\u{F0000}]|(.)\\1", "giu", garayA + garaySmallA, "#"),
            // A high half's escape and a low half's right after it spell one character the pattern holds.
            Rx("(a)\\1|${escapes(supplementaryPua)}", "giu", garayA, garayA),
            Rx("(.)\\1", "giu", p0 + garayA + garaySmallA, "$p0#"),
            Rx("(.)\\1", "gi", p0 + lambda + lambdaCap, "$p0#"),
            Rx("(.)\\1", "giu", e + garayA + garaySmallA, "$e#"),
            Rx("(.)\\1", "gi", e + lambda + lambdaCap, "$e#"),
            Rx("(.)\\1", "gi", "${longS}s$lambda$lambdaCap", "${longS}s#"),
            Rx("(.)\\1", "giu", "ı$lambda${lambdaCap}ıI", "ı#ıI"),
            // Without `u` a letter above U+FFFF is two units (S16), and without `i` no letter folds.
            Rx("($garayA)\\1", "gi", garayA + garaySmallA, garayA + garaySmallA),
            Rx("(.)\\1", "gi", garayA + garaySmallA, garayA + garaySmallA),
            Rx("(.)\\1", "gu", garayA + garaySmallA, garayA + garaySmallA),
            Rx("(.)\\1", "g", lambda + lambdaCap, lambda + lambdaCap),
        )
    }

    /** R1 where the engine's own folding takes part too: the letters the run leaves unmasked. */
    private val r1Folded: List<Rx> by lazy {
        val longS = cps("017F")
        listOf(
            Rx("(.)\\1", "giu", "$longS$garayA$garaySmallA${longS}s", "$longS##"),
            Rx("(.)\\1", "giu", "Aa$garayA$garaySmallA", "##"),
            Rx("(.)\\1", "gi", "Aa$lambda$lambdaCap", "##"),
        )
    }

    /** R1: `$1` and the match are the input's letters, read back from it by range. */
    private val r1Steps: List<Step> by lazy {
        val both = "[\$1|{{value}}]"
        val vithkuqi = cps("10570")
        val vithkuqiSmall = cps("10597")
        listOf(
            Step(garayA + garaySmallA, rep("(.)\\1", "giu", both), "[$garayA|$garayA$garaySmallA]"),
            Step(garaySmallA + garayA, rep("(.)\\1", "giu", both), "[$garaySmallA|$garaySmallA$garayA]"),
            Step("z$garayA${garaySmallA}z", rep("(.)\\1", "giu", both), "z[$garayA|$garayA$garaySmallA]z"),
            Step(garaySmallA + garayA + garaySmallA, rep("($garayA)\\1", "giu", both), "[$garaySmallA|$garaySmallA$garayA]$garaySmallA"),
            Step(vithkuqi + vithkuqiSmall, rep("(.)\\1", "giu", both), "[$vithkuqi|$vithkuqi$vithkuqiSmall]"),
            Step(vithkuqiSmall + vithkuqi, rep("(?i:(.)\\1)", "gu", both), "[$vithkuqiSmall|$vithkuqiSmall$vithkuqi]"),
            Step(lambda + lambdaCap, rep("(.)\\1", "gi", both), "[$lambda|$lambda$lambdaCap]"),
            Step(lambdaCap + lambda, rep("(.)\\1", "gi", both), "[$lambdaCap|$lambdaCap$lambda]"),
            Step(lambda + lambdaCap, rep("(.)\\1", "giu", both), "[$lambda|$lambda$lambdaCap]"),
        )
    }

    /** Whether the JVM's case-insensitive backreference repeats a capture above U+FFFF: JDK 17's never does (T5's). */
    private val jvmRepeats: Boolean by lazy {
        runCatching { Pattern.compile("(.)\\1", Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE).matcher(dU + dU).find() }.getOrDefault(false)
    }

    /** Whether a row's reference compares, under `i` and `u`, a character above U+FFFF: left out where the JVM never repeats one. */
    private fun aboveFfff(pattern: String, flags: String, input: String): Boolean =
        'u' in flags && ('i' in flags || "(?i:" in pattern) && input.any(Char::isSurrogate)

    /** [rows] as the JVM runs them: all where it repeats a capture above U+FFFF, else those that compare none. */
    private fun r1Kept(rows: List<Rx>): List<Rx> = keptWhereTheJvmRepeats(rows) { aboveFfff(it.pattern, it.flags, it.input) }

    /** [r1Steps] as the JVM runs them: each holds a letter above U+FFFF under `i` and `u`, or none. */
    private fun r1StepsKept(): List<Step> = keptWhereTheJvmRepeats(r1Steps) { s -> s.input.any(Char::isSurrogate) }

    /** [rows] less those [comparesAboveFfff] where the JVM never repeats such a capture; none left out on JDK 21 and later. */
    private fun <T> keptWhereTheJvmRepeats(rows: List<T>, comparesAboveFfff: (T) -> Boolean): List<T> {
        val kept = rows.filter { jvmRepeats || !comparesAboveFfff(it) }
        if (Runtime.version().feature() >= 21) assertEquals(rows.size, kept.size, "rows left out on a JDK whose backreference repeats a letter above U+FFFF")
        return kept
    }

    /**
     * [rows] searched as the SDK searches each ([RegexSupport.search]) with the engine's own case
     * folding off: where the engine folds a pair itself, only the run's stand-ins then match the
     * letters as Dart does.
     */
    private fun assertSearched(rows: List<Rx>) {
        fun shown(s: String?): String = s?.map { if (it in ' '..'~') "$it" else "\\u%04X".format(it.code) }?.joinToString("") ?: "null"
        val folding = (Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE).inv()
        val failures = rows.mapNotNull { r ->
            val search = RegexSupport.search(r.pattern, r.flags, r.input)
            val got = search?.let { s ->
                val m = Pattern.compile(s.re.pattern(), s.re.flags() and folding).matcher(s.text)
                val out = StringBuilder()
                var at = 0
                while (m.find()) {
                    out.append(s.input, at, m.start()).append('#')
                    at = m.end()
                }
                out.append(s.input, at, s.input.length).toString()
            }
            if (got == r.expected) null else "${shown(r.pattern)} /${r.flags} on ${shown(r.input)}: written ${shown(search?.re?.pattern())}, got ${shown(got)}"
        }
        if (failures.isNotEmpty()) fail(failures.joinToString("\n"))
    }

    @Test
    fun r1_aBackreferenceMatchesTheLettersOfALaggingClassAsDart() {
        assertDart(r1Kept(r1Rows + r1Parts + r1Folded))
        assertSteps(r1StepsKept())
    }

    @Test
    fun r1_seam_aBackreferenceComparesTheStandInsOfTheClassesSet() {
        // With the classes JDK 17 lacks set, every JVM masks their letters, and the rows hold with the
        // engine's own folding off too.
        lagging(lacks17)
        assertDart(r1Kept(r1Rows + r1Parts + r1Folded))
        assertSearched(r1Kept(r1Rows + r1Parts))
        assertSteps(r1StepsKept())
    }
}
