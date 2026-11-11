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
}
