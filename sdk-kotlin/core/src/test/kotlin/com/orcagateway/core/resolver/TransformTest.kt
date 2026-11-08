package com.orcagateway.core.resolver

import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
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
}
