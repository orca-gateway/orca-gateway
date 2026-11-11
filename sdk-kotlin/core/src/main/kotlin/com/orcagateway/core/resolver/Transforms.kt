package com.orcagateway.core.resolver

import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.SwiftText
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone
import java.util.regex.Pattern
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor

/**
 * A pipeline step: (its definition, the value so far, the resolver for
 * nested Values) to the next value. Mirrors Dart's `PipeTransform`.
 */
public typealias PipeTransform = (definition: Map<String, JsonValue>, current: JsonValue, resolver: ValueResolver) -> JsonValue

/**
 * Transform kinds by name. [defaults] holds the engine's 31 kinds plus the
 * Dart SDK's `toggle`; plugins may add more with [with]. Unknown kinds are
 * skipped by the resolver, as in Dart. Immutable (Swift's is a value type),
 * so [defaults] cannot be changed under other resolvers.
 */
public class TransformRegistry(table: Map<String, PipeTransform> = emptyMap()) {
    private val table: Map<String, PipeTransform> = table.toMap()

    public operator fun get(type: String): PipeTransform? = table[type]

    /** This registry plus (or with a replaced) [type]. */
    public fun with(type: String, transform: PipeTransform): TransformRegistry = TransformRegistry(table + (type to transform))

    public val kinds: List<String> get() = table.keys.sortedWith(SwiftText.stringOrder)

    public companion object {
        public val defaults: TransformRegistry = Transforms.defaults()
    }
}

/**
 * The built-in transforms, each a port of the Dart closure of the same name
 * in `PipeTransformRegistry.registerDefaults`.
 */
internal object Transforms {
    fun defaults(): TransformRegistry {
        val r = LinkedHashMap<String, PipeTransform>()
        fun register(type: String, transform: PipeTransform) {
            r[type] = transform
        }

        fun by(def: Map<String, JsonValue>, resolver: ValueResolver): JsonValue = resolver.resolve(def["by"] ?: JsonValue.Null)

        // Numbers: `(current ?? 0) as num <op> (by as num)`.
        register("add") { def, current, resolver -> DartNum.binary(current, by(def, resolver), DartNum.Op.Add) }
        register("subtract") { def, current, resolver -> DartNum.binary(current, by(def, resolver), DartNum.Op.Subtract) }
        register("multiply") { def, current, resolver -> DartNum.binary(current, by(def, resolver), DartNum.Op.Multiply) }
        register("divide") { def, current, resolver -> DartNum.binary(current, by(def, resolver), DartNum.Op.Divide) }
        register("modulo") { def, current, resolver -> DartNum.binary(current, by(def, resolver), DartNum.Op.Modulo) }
        register("round") { _, current, _ -> DartNum.toInt(current, ::roundHalfAwayFromZero) }
        register("floor") { _, current, _ -> DartNum.toInt(current, ::floor) }
        register("ceil") { _, current, _ -> DartNum.toInt(current, ::ceil) }
        register("abs") { _, current, _ ->
            when (current) {
                is JsonValue.Int -> JsonValue.Int(if (current.value == Long.MIN_VALUE) current.value else abs(current.value))
                is JsonValue.Double -> JsonValue.Double(abs(current.value))
                else -> JsonValue.Null
            }
        }
        register("toFixed") { def, current, _ ->
            val decimals = def["decimals"]?.dartInt ?: 2
            val s = if (current.isNumber) DartFormat.fixed(current, decimals) else null
            if (s == null) JsonValue.Null else JsonValue.String(s)
        }

        // Strings: `'$current'` first, so null reads "null" as in Dart.
        register("toString") { _, current, _ -> JsonValue.String(DartFormat.string(current)) }
        register("toUpperCase") { _, current, _ -> JsonValue.String(SwiftText.uppercased(DartFormat.string(current))) }
        register("toLowerCase") { _, current, _ -> JsonValue.String(SwiftText.lowercased(DartFormat.string(current))) }
        register("trim") { _, current, _ -> JsonValue.String(SwiftText.trimmed(DartFormat.string(current))) }
        register("template") { def, current, resolver ->
            val template = def["template"]?.stringValue ?: ""
            JsonValue.String(Placeholders.expand(template, current, def["params"]?.objectValue, resolver))
        }
        register("regex") { def, current, resolver -> regexTransform(def, current, resolver) }
        register("substring") { def, current, _ -> substring(def, current) }
        register("split") { def, current, _ ->
            val separator = def["separator"]?.stringValue ?: ""
            val s = DartFormat.string(current)
            // "" cuts every UTF-16 code unit apart, as Dart's split('').
            val parts = if (separator.isEmpty()) s.map { it.toString() } else s.split(separator)
            JsonValue.Array(parts.map { JsonValue.String(it) })
        }
        register("join") { def, current, _ ->
            val separator = def["separator"]?.stringValue ?: ""
            if (current is JsonValue.Array) {
                JsonValue.String(current.items.joinToString(separator) { DartFormat.string(it) })
            } else {
                JsonValue.String(DartFormat.string(current))
            }
        }

        // Booleans
        register("not") { _, current, _ -> JsonValue.Bool(current != JsonValue.Bool(true)) }
        register("toBool") { _, current, _ ->
            val falsy = when (current) {
                JsonValue.Null -> true
                is JsonValue.Bool -> !current.value
                is JsonValue.Int -> current.value == 0L
                is JsonValue.Double -> current.value == 0.0
                is JsonValue.String -> current.value.isEmpty()
                else -> false
            }
            JsonValue.Bool(!falsy)
        }
        register("toggle") { _, current, _ ->
            when (current) {
                JsonValue.Null -> JsonValue.Bool(true)
                is JsonValue.Bool -> JsonValue.Bool(!current.value)
                else -> JsonValue.Null
            }
        }

        // Collections
        register("length") { _, current, _ ->
            when (current) {
                is JsonValue.Array -> JsonValue.Int(current.items.size.toLong())
                is JsonValue.String -> JsonValue.Int(current.value.length.toLong()) // UTF-16 units, as Dart
                else -> JsonValue.Int(0)
            }
        }
        register("at") { def, current, _ ->
            val index = def["index"]?.dartInt ?: 0
            val items = current.arrayValue
            if (items == null || index >= items.size || index < 0) JsonValue.Null else items[index.toInt()]
        }
        register("first") { _, current, _ -> current.arrayValue?.firstOrNull() ?: JsonValue.Null }
        register("last") { _, current, _ -> current.arrayValue?.lastOrNull() ?: JsonValue.Null }
        register("map") { def, current, resolver ->
            val items = current.arrayValue
            val step = def["transform"]?.objectValue
            val op = step?.get("type")?.stringValue?.let { resolver.transforms[it] }
            if (items == null || step == null || op == null) current else JsonValue.Array(items.map { op(step, it, resolver) })
        }
        register("filter") { def, current, resolver ->
            // Dart evaluates the expression once per item without binding the
            // item, so the result is all items or none. Kept for parity.
            val items = current.arrayValue
            val expr = def["expr"]?.objectValue
            if (items == null || expr == null) current else JsonValue.Array(items.filter { resolver.evaluate(expr) })
        }
        register("contains") { def, current, resolver ->
            val value = resolver.resolve(def["value"] ?: JsonValue.Null)
            when (current) {
                is JsonValue.Array -> JsonValue.Bool(current.items.contains(value))
                is JsonValue.String -> JsonValue.Bool(current.value.contains(DartFormat.string(value)))
                else -> JsonValue.Bool(false)
            }
        }

        // Formatting
        register("formatCurrency") { def, current, _ ->
            val currency = def["currency"]?.stringValue ?: "USD"
            val decimals = def["decimals"]?.dartInt ?: 2
            val value = if (current.isNull) JsonValue.Int(0) else current
            val s = if (value.isNumber) DartFormat.fixed(value, decimals) else null
            if (s == null) JsonValue.Null else JsonValue.String(currencySymbol(currency) + s)
        }
        register("formatNumber") { def, current, _ ->
            val value = if (current.isNull) JsonValue.Int(0) else current
            val decimals = def["decimals"]?.dartInt
            when {
                !value.isNumber -> JsonValue.Null
                decimals != null -> DartFormat.fixed(value, decimals)?.let { JsonValue.String(it) } ?: JsonValue.Null
                else -> JsonValue.String(DartFormat.string(value))
            }
        }
        register("formatDate") { def, current, _ -> formatDate(def["format"]?.stringValue ?: "", current) }

        return TransformRegistry(r)
    }

    private fun substring(def: Map<String, JsonValue>, current: JsonValue): JsonValue {
        val units = DartFormat.string(current)
        val start = def["start"]?.dartInt ?: 0
        // Dart throws a RangeError outside 0 <= start <= end <= length.
        if (start < 0 || start > units.length) return JsonValue.Null
        var end = units.length.toLong()
        val length = def["length"]?.dartInt
        if (length != null) {
            if (length < 0 || length > units.length - start) return JsonValue.Null
            end = start + length
        }
        return JsonValue.String(SwiftText.repairingSurrogates(units.substring(start.toInt(), end.toInt())))
    }

    fun currencySymbol(currency: String): String = when (SwiftText.uppercased(currency)) {
        "USD" -> "$"
        "EUR" -> "€"
        "GBP" -> "£"
        "JPY" -> "¥"
        else -> "$currency "
    }

    /**
     * `regex`: match-only returns match 0 or null; with `replacement`,
     * `$1`-`$9` backrefs then `{{value}}` (the match) and named params expand,
     * first match only unless the flags hold `g`. Invalid patterns give null.
     */
    fun regexTransform(def: Map<String, JsonValue>, current: JsonValue, resolver: ValueResolver): JsonValue {
        val pattern = def["pattern"]?.stringValue ?: ""
        if (pattern.length > RegexSupport.MAX_PATTERN_LENGTH) return JsonValue.Null
        val flags = def["flags"]?.stringValue
        val re = RegexSupport.compile(pattern, flags) ?: return JsonValue.Null
        val input = RegexSupport.clip(if (current.isNull) "" else DartFormat.string(current))

        val replacement = def["replacement"]?.stringValue
        if (replacement == null) {
            val m = RegexSupport.firstMatch(re, input) ?: return JsonValue.Null
            return JsonValue.String(m.group(0) ?: "")
        }
        val params = def["params"]?.objectValue
        val global = flags?.contains('g') ?: false
        val matches = if (global) RegexSupport.allMatches(re, input) else listOfNotNull(RegexSupport.firstMatch(re, input))

        val out = StringBuilder()
        var cursor = 0
        for (m in matches) {
            out.append(input, cursor, m.start)
            val matched = m.group(0) ?: ""
            val backreffed = RegexSupport.expandBackrefs(replacement, m)
            out.append(Placeholders.expand(backreffed, JsonValue.String(matched), params, resolver))
            cursor = m.end
        }
        out.append(input, cursor, input.length)
        return JsonValue.String(out.toString())
    }

    /**
     * `formatDate` exists in the engine but not in the Dart SDK (which skips
     * it). This follows the Dart engine: an ISO-8601 string keeps the fields
     * as written (UTC when it carries an offset), a number is epoch
     * milliseconds in UTC; `yyyy MM dd HH mm ss` are replaced. An unparseable
     * input is returned unchanged rather than rendering "now".
     */
    fun formatDate(format: String, current: JsonValue): JsonValue {
        val parts = DateParts.of(current) ?: return current
        fun pad(n: Int): String = if (n < 10) "0$n" else n.toString()
        val out = format
            .replace("yyyy", parts.year.toString())
            .replace("MM", pad(parts.month))
            .replace("dd", pad(parts.day))
            .replace("HH", pad(parts.hour))
            .replace("mm", pad(parts.minute))
            .replace("ss", pad(parts.second))
        return JsonValue.String(out)
    }
}

// MARK: - Dart number semantics

internal object DartNum {
    enum class Op { Add, Subtract, Multiply, Divide, Modulo }

    /**
     * `((current ?? 0) as num) <op> (by as num)`: int with int stays int
     * (wrapping like the Dart VM), `/` always gives a double, `%` is
     * Euclidean. A non-number operand, or int `% 0`, is where Dart throws.
     */
    fun binary(current: JsonValue, by: JsonValue, op: Op): JsonValue {
        val left = if (current.isNull) JsonValue.Int(0) else current
        if (left is JsonValue.Int && by is JsonValue.Int) {
            val a = left.value
            val b = by.value
            return when (op) {
                Op.Add -> JsonValue.Int(a + b)
                Op.Subtract -> JsonValue.Int(a - b)
                Op.Multiply -> JsonValue.Int(a * b)
                Op.Divide -> JsonValue.Double(a.toDouble() / b.toDouble())
                Op.Modulo -> when (b) {
                    0L -> JsonValue.Null
                    -1L -> JsonValue.Int(0) // Long.MIN_VALUE % -1, kept apart as in Swift
                    else -> {
                        val r = a % b
                        // r + |b| without computing |Long.MIN_VALUE|.
                        JsonValue.Int(if (r < 0) (if (b < 0) r - b else r + b) else r)
                    }
                }
            }
        }
        val a = left.doubleValue ?: return JsonValue.Null
        val b = by.doubleValue ?: return JsonValue.Null
        return when (op) {
            Op.Add -> JsonValue.Double(a + b)
            Op.Subtract -> JsonValue.Double(a - b)
            Op.Multiply -> JsonValue.Double(a * b)
            Op.Divide -> JsonValue.Double(a / b)
            Op.Modulo -> {
                val r = a % b // C fmod
                JsonValue.Double(if (r < 0) r + abs(b) else r)
            }
        }
    }

    /**
     * `round`, `floor`, `ceil` return an int; Dart throws on null, NaN and
     * infinity.
     */
    fun toInt(value: JsonValue, rule: (Double) -> Double): JsonValue = when (value) {
        is JsonValue.Int -> value
        is JsonValue.Double -> {
            val d = value.value
            if (!d.isFinite()) {
                JsonValue.Null
            } else {
                val r = rule(d)
                when {
                    r >= 9.223372036854775807e18 -> JsonValue.Int(Long.MAX_VALUE)
                    r <= -9.223372036854775808e18 -> JsonValue.Int(Long.MIN_VALUE)
                    else -> JsonValue.Int(r.toLong())
                }
            }
        }
        else -> JsonValue.Null
    }
}

// MARK: - Placeholders

internal object Placeholders {
    /**
     * `{{name}}`, identifier-only, byte for byte with the TS, engine-dart and
     * Flutter implementations.
     */
    private val pattern: Pattern = RegexSupport.compileIcuLike("\\{\\{\\s*([A-Za-z_$][A-Za-z0-9_$]*)\\s*\\}\\}", 0)!!

    /**
     * `{{value}}` is the previous pipeline output, other names come from
     * `params` (resolved); unknown names render as "".
     */
    fun expand(template: String, current: JsonValue, params: Map<String, JsonValue>?, resolver: ValueResolver): String {
        val m = pattern.matcher(template)
        val out = StringBuilder()
        var cursor = 0
        while (m.find()) {
            out.append(template, cursor, m.start())
            val name = m.group(1)
            if (name == "value") {
                out.append(if (current.isNull) "" else DartFormat.string(current))
            } else {
                val raw = params?.get(name)
                if (raw != null) {
                    val resolved = resolver.resolve(raw)
                    out.append(if (resolved.isNull) "" else DartFormat.string(resolved))
                }
            }
            cursor = m.end()
        }
        out.append(template, cursor, template.length)
        return out.toString()
    }
}

// MARK: - Regex

/**
 * java.util.regex standing in for Dart's ECMAScript `RegExp`, with the same
 * guard rails: patterns over 200 UTF-16 units are refused and the input is
 * clipped to 10 000 units. The empty pattern is valid and matches everywhere.
 * `\d`, `\w`, `\s`, `\b` and their negations, `\v`, the case folding of the
 * letters of [DartFoldTable] and, with `u`, the `\p{…}` names are rewritten
 * to Dart's ([asciiClasses]); the pattern is then compiled with
 * UNICODE_CHARACTER_CLASS where the runtime has it (learned once: the JVM
 * does, Android's ICU regex is Unicode-aware already), so the engine's own
 * case folding and property names are Unicode as Dart's are.
 */
internal object RegexSupport {
    const val MAX_PATTERN_LENGTH: Int = 200
    const val MAX_INPUT_LENGTH: Int = 10_000

    class Match(private val result: java.util.regex.MatchResult) {
        val start: Int get() = result.start()
        val end: Int get() = result.end()
        val groupCount: Int get() = result.groupCount()

        fun group(i: Int): String? = if (i > result.groupCount()) null else result.group(i)
    }

    fun compile(pattern: String, flags: String?): Pattern? {
        val f = flags ?: ""
        var options = 0
        if ('i' in f) options = options or Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE
        if ('m' in f) options = options or Pattern.MULTILINE
        if ('s' in f) options = options or Pattern.DOTALL
        val rewritten = asciiClasses(pattern, ignoreCase = 'i' in f, unicode = 'u' in f) ?: return null
        return compileIcuLike(rewritten, options)
    }

    /**
     * Dart's (ECMAScript) classes, word edges and case folding, spelled out
     * so that neither java.util.regex nor Android's ICU applies its own:
     *
     * - `\d`, `\w`, `\D`, `\W` are ASCII classes, `\s` and `\S` ECMAScript's
     *   WhiteSpace and LineTerminator ([SPACE]: not U+0085, but U+FEFF), and
     *   `\v` is U+000B alone, where both engines read every vertical space.
     *   Inside a character class the classes nest, which both engines read as
     *   a union (`[a\D]` is `[a[^0-9]]`).
     * - `\b` and `\B` are lookarounds on the same word set. Inside a class
     *   `\b` is the backspace U+0008, and `[` is a literal.
     * - The word set is `[A-Za-z0-9_]`, with `i` and `u` together also ſ U+017F
     *   and K U+212A (they fold to s and k), and is always case-sensitive.
     * - Under `i`, Dart folds none of ſ, K, ı U+0131, İ U+0130 into ASCII, or
     *   with `u` only ſ and K; the JVM folds all four (but not K into `[A-Z]`),
     *   ICU ſ and K. Without `u` Dart matches Å U+212B, Ω U+2126 or ẞ U+1E9E
     *   only to itself, where both engines fold them, and it never matches ß
     *   or a ligature to a run of letters, where ICU does ("ss", "ff"). So the
     *   217 letters of [DartFoldTable] never go to the engine's folding.
     *   Outside a class each is the case-sensitive set Dart folds it
     *   to: `s` is `(?-i:[sS])`, with `u` `(?-i:[sSſ])`, `ß` is `(?-i:[ß])`,
     *   with `u` `(?-i:[ßẞ])`. A class C becomes `(?:(?!T)C|(?-i:[M]))`, T the
     *   table's letters and M those C matches in Dart, found by testing each
     *   letter once against C case-sensitively. Every other letter keeps the
     *   engine's folding.
     * - `i` above is the group's, as in Dart: a modifier group `(?i:` or
     *   `(?-i:` sets it up to its `)`, any other group keeps the enclosing one
     *   (the pattern's at the top). Inside `(?-i:` the table's letters stay as
     *   written, the engine reading them case-sensitively; inside `(?i:` they
     *   become Dart's sets as under the pattern's `i`. `u` is the pattern's.
     *
     * After `(?` Dart takes only `:`, `=`, `!`, `<=`, `<!`, a group name
     * `<name>` or modifiers: flags from `i`, `m`, `s`, each at most once, at
     * most one `-`, then `:`, not empty on both sides of the `-`. Any other
     * form (`(?i)`, `(?-:`, `(?ii:`, `(?x:`, `(?>`, `(?#`, `(?P<`) gives null.
     *
     * An escaped character stays as it is (`\\d` is a backslash and a d), as do
     * a modifier group's flags (`(?ms-i:`) and the digits of `\xHH` and
     * `\uHHHH`. An `\xHH`, `\uHHHH` or with `u` `\u{H…}` that spells a letter
     * of the table is that letter (`\x73` under `i` is `(?-i:[sS])`); inside a
     * class the members test reads it. With `u`, `\u{H…}` is written `\x{H…}`,
     * in a class too, and one Dart rejects (`\u{}`, `\u{g}`, `\u{110000}`)
     * gives null. `\0` before no digit is NUL and `\c` and an ASCII letter its
     * control character, with `u` and without, each written as its code point.
     * Backreferences keep the engine's folding.
     *
     * Group names are dropped, with `u` and without: `(?<name>X)` is written
     * `(X)`, the same number (ECMAScript, ICU and the JVM number named groups
     * in order with the others), and `\k<name>` is `(?:\N)`, N its group's
     * number, or for a name two alternatives hold `(?:\1|\2)`, the group that
     * took part matching. So names Dart takes and the engine refuses work
     * (`(?<$a>x)`, `(?<é>x)`; Dart's are [groupName]'s). Null, as in Dart: a
     * name twice where both groups may take part (`(?<a>x)(?<a>y)`,
     * `(?<a>(?<a>x))`), and where the pattern has a named group any `\k` but
     * `\k<name>` of one of its names, in a class too (`\k<b>`, `\k<a`, `[\k]`).
     *
     * A backreference that can only see its group unset matches empty in
     * Dart, where both engines fail it or, in a repeat, see the last
     * iteration's value (ECMAScript resets a quantified atom's groups each
     * time). It is written `(?:)` when it stands before its group closes
     * (`\1(a)`, `(a\1)`, `(?:\1b|(a))+`) or in another alternative of a
     * disjunction that holds the group (`(a)|\1b`); a `\k<name>` keeps only
     * the groups it may see set. Inside a lookbehind, which Dart reads right
     * to left, none is emptied: `\N` stays, `\k<name>` keeps all its groups
     * (and the JVM refuses a reference there). Not reached: a group that takes
     * part or not only at run time (`(?:(a)|b)\1`), as neither engine tells
     * "unset" from "set elsewhere".
     *
     * Without `u` Dart reads Annex B's grammar, and so does this:
     *
     * - An escaped letter ECMAScript gives no meaning (all but `b B d D w W s S
     *   f n r t v c x u k p P`) is that letter, folded as one under `i` (`\A`
     *   is A, `\K` under `i` is `(?-i:[kK])`). So are `\p` and `\P`, the `{L}`
     *   after them ordinary text, `\k` when the pattern has no named group,
     *   `\x` without two hex digits and `\u` without four (`\u{3}` is uuu).
     * - Any other `\c` is a backslash, the `c` read next; in a class `\c` and a
     *   digit or `_` is a control character too (`[\c1]` is U+0011).
     * - A decimal escape is a backreference when its whole number is at most
     *   the pattern's count of capturing groups, counted before the pattern
     *   is read; otherwise, and always in a class, it is a legacy octal escape
     *   of at most three octal digits up to 0o377, the rest literal (`\400` is
     *   U+0020 then "0"), or from 8 or 9 that digit.
     * - A `{` that starts no brace quantifier, a lone `}` and a lone `]` are
     *   literal (`x{,3}`, `a{1`).
     *
     * With `u` Dart reads ECMAScript's strict grammar and refuses, so null:
     *
     * - An identity escape of anything but a syntax character `^ $ \ . * + ?
     *   ( ) [ ] { } |` or `/`, and `-` in a class (`\A`, `\-`, `\_`, `[\a]`,
     *   `[\B]`, `[\k]`); `\c` without an ASCII letter, `\x` without two hex
     *   digits, `\u` without four or `{…}`.
     * - `\0` before a digit; a decimal escape past the group count, and in a
     *   class any but `\0` (`\8`, `(a)\2`, `[\1]`).
     * - `\k` but for `\k<name>` of a named group the pattern has.
     * - A lone `{`, `}` or `]` (`a{1`, `[]a]`).
     *
     * A class ends at its first unescaped `]`, one right after `[` or `[^`
     * too, with `u` and without: `[]` matches nothing and is written
     * `(?:(?!))`, which takes a quantifier on ICU too (`[]*`), `[^]` any unit.
     * Its members are ECMAScript's, not the engine's set syntax (`[a&&b]` is a,
     * & and b). A range with a class escape at either end (with `u` a property
     * too) is, without `u`, its two ends and the `-` as members (`[a-\d]` is a,
     * - and a digit), and with `u` null; a `-` at either end of the class is a
     * member in both modes (`[\d-]`). Without `u` an escaped letter or digit is
     * the character as above.
     *
     * With `u`, `\p{name}` and `\P{name}` take only the names Dart takes
     * ([RegexPropertyNames]): any other name, or `\p` or `\P` without `{…}`,
     * gives null, in a class too. On the JVM an accepted name is written the
     * way java.util.regex reads Dart's set (`Lowercase_Letter` as `Ll`,
     * `Alphabetic` as `IsAlphabetic`, `Any` as a class), and one it has no such
     * spelling of (`Script_Extensions`, `Cased`, `Math` …) gives null; on
     * Android the name stays as written. Without `u`, `\p{…}` is a p and text.
     *
     * A quantifier, `*`, `+`, `?` or a brace form `{n}`, `{n,}`, `{n,m}` of
     * digits, gives null where Dart finds nothing to repeat, with `u` and
     * without: at the start, after a group opening or `|`, after an assertion
     * (`^`, `$`, `\b`, `\B`, a lookbehind), and after another quantifier but
     * for one `?` that makes it lazy (`a+?` stays, `a++`, `a{1}{2}`, `a+??`
     * give null). With `u` a lookahead is an assertion too; without, Annex B
     * lets it take a quantifier and it is written as a group that does, which
     * ICU needs (`(?=a)*` is `(?:(?=a))*`).
     */
    fun asciiClasses(pattern: String, ignoreCase: Boolean = false, unicode: Boolean = false): String? {
        val captures = captures(pattern)
        val named = captures.names.isNotEmpty()
        val open = ArrayList<Group>()
        val top = HashSet<Int>() // the capturing groups closed in the top level's alternative being read
        var opened = 0
        val out = StringBuilder(pattern.length + 16)
        var last = Last.None

        /** The capturing groups closed in the innermost alternative being read. */
        fun alternative() = open.lastOrNull()?.closed ?: top

        /** Whether group [n] may be set here: closed in an alternative still being read. */
        fun seen(n: Int) = n in top || open.any { n in it.closed }
        var i = 0
        while (i < pattern.length) {
            val c = pattern[i]
            val fold = open.lastOrNull()?.fold ?: ignoreCase
            val word = if (fold && unicode) "A-Za-z0-9_\u017F\u212A" else "A-Za-z0-9_"
            val w = "(?-i:[$word])"
            val folded = if (fold) DartFoldTable.set(c, unicode) else null
            val quantifier = quantifierEnd(pattern, i)
            val atom = last
            last = Last.Atom
            when {
                quantifier > i -> {
                    last = when {
                        atom == Last.Atom -> Last.Quantifier
                        atom == Last.Quantifier && c == '?' -> Last.Lazy
                        else -> return null
                    }
                    out.append(pattern, i, quantifier)
                    i = quantifier
                }
                c == '\\' -> {
                    val next = pattern.getOrNull(i + 1)
                    if (next == 'b' || next == 'B') last = Last.Assertion
                    val piece = when (next) {
                        'd' -> "[0-9]"
                        'D' -> "[^0-9]"
                        's' -> "[$SPACE]"
                        'S' -> "[^$SPACE]"
                        'w' -> w
                        'W' -> "(?-i:[^$word])"
                        'b' -> "(?:(?<=$w)(?!$w)|(?<!$w)(?=$w))"
                        'B' -> "(?:(?<=$w)(?=$w)|(?<!$w)(?!$w))"
                        else -> null
                    }
                    // A reference's end and the groups it names: all of the name's for `\k<name>`, one for `\N`.
                    val reference = when {
                        piece != null -> null
                        named && next == 'k' -> {
                            val (end, name) = (if (pattern.getOrNull(i + 2) == '<') groupName(pattern, i + 3) else null) ?: return null
                            end to (captures.names[name] ?: return null)
                        }
                        else -> backreference(pattern, i, captures.count)?.let { (end, n) -> end to listOf(n) }
                    }
                    when {
                        piece != null -> {
                            out.append(piece)
                            i += 2
                        }
                        reference != null -> {
                            val (end, numbers) = reference
                            // Dart reads a lookbehind right to left: in one, a reference keeps all its groups.
                            val set = if (open.any { it.kind == GroupKind.Lookbehind }) numbers else numbers.filter(::seen)
                            out.append(
                                when {
                                    set.isEmpty() -> "(?:)"
                                    next == 'k' -> set.joinToString("|", "(?:", ")") { "\\$it" }
                                    else -> pattern.substring(i, end)
                                },
                            )
                            i = end
                        }
                        else -> {
                            val escape = spelled(pattern, i, unicode, inClass = false, named) ?: escape(pattern, i, unicode, inClass = false) ?: return null
                            val letter = escape.codePoint?.takeIf { fold && it <= 0xFFFF }?.let { DartFoldTable.set(it.toChar(), unicode) }
                            if (letter != null) out.append("(?-i:[").append(letter).append("])") else out.append(escape.text)
                            i = escape.end
                        }
                    }
                }
                c == '{' || c == '}' || c == ']' -> {
                    if (unicode) return null
                    out.append('\\').append(c)
                    i += 1
                }
                c == '[' -> i = characterClass(pattern, i, word, fold, unicode, named, out) ?: return null
                c == '(' -> {
                    val (end, group) = groupOpening(pattern, i, fold, out.length, opened) ?: return null
                    if (group.kind == GroupKind.Capturing) {
                        opened += 1
                        // A name twice where both groups may take part, one inside the other too, is Dart's error.
                        val earlier = group.name?.let { captures.names[it] }.orEmpty().filter { it < opened }
                        if (earlier.any { n -> seen(n) || open.any { it.number == n } }) return null
                    }
                    open.add(group)
                    // The name is dropped; `(?ms-i:` is copied, its flags the engine reads as Dart does.
                    out.append(if (group.kind == GroupKind.Capturing) "(" else pattern.substring(i, end))
                    i = end
                    last = Last.None
                }
                c == ')' -> {
                    val group = open.removeLastOrNull()
                    out.append(c)
                    i += 1
                    // Its capturing groups, itself among them if it is one, are closed in the enclosing alternative.
                    if (group != null) alternative().addAll(group.before + 1..opened)
                    if (group?.kind == GroupKind.Lookbehind || group?.kind == GroupKind.Lookahead && unicode) {
                        last = Last.Assertion
                    } else if (group != null && group.kind == GroupKind.Lookahead && i < pattern.length && quantifierEnd(pattern, i) > i) {
                        out.insert(group.start, "(?:").append(')') // ICU quantifies a group, not a lookahead
                    }
                }
                c == '^' || c == '$' || c == '|' -> {
                    last = if (c == '|') Last.None else Last.Assertion
                    if (c == '|') alternative().clear()
                    out.append(c)
                    i += 1
                }
                folded != null -> {
                    out.append("(?-i:[").append(folded).append("])")
                    i += 1
                }
                else -> {
                    out.append(c)
                    i += 1
                }
            }
        }
        return out.toString()
    }

    /** What the reader wrote last, as a quantifier after it sees it. */
    private enum class Last { None, Assertion, Atom, Quantifier, Lazy }

    private enum class GroupKind { Capturing, NonCapturing, Lookahead, Lookbehind }

    /**
     * An open group: its `i`, its kind, the output offset its text starts at,
     * how many capturing groups open [before] it, its name if it has one, and
     * the capturing groups [closed] in its alternative being read.
     */
    private class Group(val fold: Boolean, val kind: GroupKind, val start: Int, val before: Int, val name: String?) {
        val number: Int get() = if (kind == GroupKind.Capturing) before + 1 else 0
        val closed = HashSet<Int>()
    }

    /** The pattern's capturing groups: how many, and each name with its groups' numbers, in order. */
    private class Captures(val count: Int, val names: Map<String, List<Int>>)

    /**
     * The capturing groups of the whole pattern, as Dart counts them before
     * it reads it: each `(` that [groupOpening] opens a capturing group with,
     * a plain `(` or `(?<name>`, outside classes and escapes, and each name
     * as [groupName] spells it.
     */
    private fun captures(pattern: String): Captures {
        var count = 0
        val names = LinkedHashMap<String, MutableList<Int>>()
        var i = 0
        while (i < pattern.length) {
            when (pattern[i]) {
                '\\' -> i += 2
                '[' -> i = classEnd(pattern, i)
                '(' -> {
                    val group = groupOpening(pattern, i, fold = false, start = 0, before = count)?.second
                    if (group?.kind == GroupKind.Capturing) {
                        count += 1
                        group.name?.let { names.getOrPut(it) { ArrayList() }.add(count) }
                    }
                    i += 1
                }
                else -> i += 1
            }
        }
        return Captures(count, names)
    }

    /**
     * The index after the class opening at [start], ECMAScript's way: a `]`
     * right after `[` or `[^` ends it, and an escape is skipped whole.
     * The pattern's length when it is not closed.
     */
    private fun classEnd(pattern: String, start: Int): Int {
        var j = if (pattern.getOrNull(start + 1) == '^') start + 2 else start + 1
        if (pattern.getOrNull(j) == ']') return j + 1
        while (j < pattern.length && pattern[j] != ']') j += if (pattern[j] == '\\') 2 else 1
        return minOf(j + 1, pattern.length)
    }

    /**
     * The backreference at [i], with `u` and without, as its end and its
     * number: `\` and a run of digits, not from 0, whose number is at most
     * [count]; null for none. A decimal escape from 1 past [count] the caller
     * then reads, without `u`, as [spelled]'s legacy octal escape or digit,
     * and with `u` refuses, so null.
     */
    private fun backreference(pattern: String, i: Int, count: Int): Pair<Int, Int>? {
        if (pattern.getOrNull(i + 1)?.let { it in '1'..'9' } != true) return null
        var end = i + 1
        var n = 0
        while (end < pattern.length && pattern[end] in '0'..'9') {
            if (n <= count) n = n * 10 + (pattern[end] - '0')
            end += 1
        }
        return if (n <= count) end to n else null
    }

    /**
     * The character the escape at [i] stands for, as an [Escape] of its code
     * point written [plain], where Dart reads one the engine does not: in both
     * modes `\0` before no digit is NUL, `\c` and an ASCII letter its control
     * character, and `\v` U+000B alone. Without [unicode], as Annex B: any
     * other `\c` is a backslash, the `c` read next, but [inClass] `\c` and a
     * digit or `_` is a control character too; a decimal escape is legacy
     * octal, at most three octal digits up to 0o377, or from 8 or 9 that
     * digit; `\x` without two hex digits, `\u` without four, `\p`, `\P`, `\k`
     * when the pattern has no [named] group, and every letter ECMAScript gives
     * no meaning are that letter. Null for any other escape; `\b`, `\B`
     * outside a class, `\d`, `\D`, `\w`, `\W`, `\s`, `\S` and a backreference
     * are the caller's.
     */
    private fun spelled(pattern: String, i: Int, unicode: Boolean, inClass: Boolean, named: Boolean): Escape? {
        val next = pattern.getOrNull(i + 1) ?: return null
        val after = pattern.getOrNull(i + 2)
        fun hex(n: Int) = (i + 2 until i + 2 + n).all { pattern.getOrNull(it)?.let { d -> d in HEX_DIGITS } == true }
        val (end, codePoint) = when {
            next == '0' && after?.let { it in '0'..'9' } != true -> i + 2 to 0
            next == 'c' && after != null && (after in 'a'..'z' || after in 'A'..'Z') -> i + 3 to after.code % 32
            next == 'v' -> i + 2 to 0x0B
            unicode -> null
            next == 'c' -> if (inClass && after != null && (after in '0'..'9' || after == '_')) i + 3 to after.code % 32 else i + 1 to '\\'.code
            next in '0'..'9' -> octal(pattern, i)
            next == 'x' -> if (hex(2)) null else i + 2 to 'x'.code
            next == 'u' -> if (hex(4)) null else i + 2 to 'u'.code
            next == 'k' -> if (named) null else i + 2 to 'k'.code
            next in 'a'..'z' || next in 'A'..'Z' -> if (next in "fnrt") null else i + 2 to next.code
            else -> null
        } ?: return null
        return Escape(end, plain(codePoint), codePoint)
    }

    /**
     * The legacy octal escape at [i], `\` and a digit, as its end and its
     * code point: up to three octal digits while the value stays at most
     * 0o377 (`\400` is U+0020 and then "0"); `\8` and `\9` are the digit.
     */
    private fun octal(pattern: String, i: Int): Pair<Int, Int> {
        val first = pattern[i + 1]
        if (first > '7') return i + 2 to first.code
        fun digit(at: Int) = pattern.getOrNull(at)?.takeIf { it in '0'..'7' }?.let { it - '0' }
        var value = first - '0'
        var end = i + 2
        digit(end)?.let {
            value = value * 8 + it
            end += 1
            if (value < 32) {
                digit(end)?.let { third ->
                    value = value * 8 + third
                    end += 1
                }
            }
        }
        return end to value
    }

    /** [codePoint] in the engine's text: an ASCII letter as it is, any other character as `\x{H}`. */
    private fun plain(codePoint: Int): String =
        if (codePoint in 'a'.code..'z'.code || codePoint in 'A'.code..'Z'.code) codePoint.toChar().toString() else "\\x{${Integer.toHexString(codePoint)}}"

    /**
     * The end of the quantifier at [i]: `*`, `+`, `?`, or a brace form `{n}`,
     * `{n,}` or `{n,m}` of digits. -1 for none, a `{` of no such form too.
     */
    private fun quantifierEnd(pattern: String, i: Int): Int {
        if (pattern[i] == '*' || pattern[i] == '+' || pattern[i] == '?') return i + 1
        if (pattern[i] != '{') return -1
        fun digits(from: Int): Int {
            var e = from
            while (e < pattern.length && pattern[e] in '0'..'9') e += 1
            return e
        }
        val n = digits(i + 1)
        if (n == i + 1) return -1
        val m = if (pattern.getOrNull(n) == ',') digits(n + 1) else n
        return if (pattern.getOrNull(m) == '}') m + 1 else -1
    }

    /**
     * The end of the group opening at [i] and the group it opens, its text
     * starting at [start] in the output, [before] capturing groups opened
     * before it. The group's `i` is [fold], the enclosing one, unless
     * modifiers add or remove it. Null for a `(?` form Dart rejects, a group
     * name [groupName] refuses too.
     */
    private fun groupOpening(pattern: String, i: Int, fold: Boolean, start: Int, before: Int): Pair<Int, Group>? {
        fun group(kind: GroupKind, inner: Boolean = fold, name: String? = null) = Group(inner, kind, start, before, name)
        if (pattern.getOrNull(i + 1) != '?') return i + 1 to group(GroupKind.Capturing)
        val next = pattern.getOrNull(i + 2)
        return when {
            next == ':' -> i + 3 to group(GroupKind.NonCapturing)
            next == '=' || next == '!' -> i + 3 to group(GroupKind.Lookahead)
            next == '<' && pattern.getOrNull(i + 3).let { it == '=' || it == '!' } -> i + 4 to group(GroupKind.Lookbehind)
            next == '<' -> groupName(pattern, i + 3)?.let { (end, name) -> end to group(GroupKind.Capturing, name = name) }
            else -> {
                var e = i + 2
                while (e < pattern.length && pattern[e] in "ims-") e += 1
                val flags = pattern.substring(i + 2, e)
                val letters = flags.filter { it != '-' }
                val dart = pattern.getOrNull(e) == ':' && flags != "-" && flags.length - letters.length <= 1 &&
                    letters.toSet().size == letters.length
                if (!dart) return null
                val dash = flags.indexOf('-')
                val at = flags.indexOf('i')
                e + 1 to group(GroupKind.NonCapturing, if (at < 0) fold else dash < 0 || at < dash)
            }
        }
    }

    /**
     * The group name at [from], up to its `>`, as Dart reads one with `u` and
     * without (RegExpIdentifierName), as the end after the `>` and the name it
     * spells: [identifier] characters, each written as itself (a surrogate pair
     * too) or as a `\u` escape [escape] reads with `u` (`\u0062`, `\u{62}`).
     * Null for an empty name, any other character, or no `>`. Two `\uHHHH`
     * that spell a surrogate pair, one character to Dart, are two halves here.
     */
    private fun groupName(pattern: String, from: Int): Pair<Int, String>? {
        val name = StringBuilder()
        var j = from
        while (j < pattern.length && pattern[j] != '>') {
            val escaped = if (pattern.startsWith("\\u", j)) escape(pattern, j, unicode = true, inClass = false) ?: return null else null
            val c = escaped?.codePoint ?: pattern.codePointAt(j)
            if (!identifier(c, first = name.isEmpty())) return null
            name.appendCodePoint(c)
            j = escaped?.end ?: (j + Character.charCount(c))
        }
        return if (j < pattern.length && name.isNotEmpty()) j + 1 to name.toString() else null
    }

    /**
     * Whether [c] may stand in a group name, [first] or after it: ID_Start,
     * `$` or `_` first, then ID_Continue, `$`, ZWNJ or ZWJ. These are the
     * runtime's identifier sets, less the format and control characters they
     * let through and U+2E2F, which they hold and Unicode's do not.
     */
    private fun identifier(c: Int, first: Boolean): Boolean = when {
        c == '$'.code -> true
        c == 0x2E2F -> false
        first -> c == '_'.code || Character.isUnicodeIdentifierStart(c)
        else -> c == 0x200C || c == 0x200D || Character.isUnicodeIdentifierPart(c) && !Character.isIdentifierIgnorable(c)
    }

    /**
     * The class opening at [start], up to its first unescaped `]` as in
     * ECMAScript, appended to [out]; returns the index after it, or null for an
     * escape Dart rejects or a class Dart leaves unclosed. [fold] is the
     * group's `i`, [unicode] the `u` flag, [named] whether the pattern has a
     * named group. A `]` right after `[` or `[^` ends the class: `[]` matches
     * nothing and is written `(?:(?!))` (ICU quantifies no `(?!)`), `[^]` any
     * unit and is written `[\s\S]`. The engine's set syntax (nested classes,
     * `&&`) means nothing here, so ASCII punctuation is written escaped, and a
     * `-` between two members is a range only when neither is a class escape:
     * without `u` it is then a member (`[a-\d]` is a, - and a digit), with `u`
     * null, a property on either side too; a range out of order fails to
     * compile, as in Dart.
     */
    private fun characterClass(pattern: String, start: Int, word: String, fold: Boolean, unicode: Boolean, named: Boolean, out: StringBuilder): Int? {
        val negated = pattern.getOrNull(start + 1) == '^'
        var j = if (negated) start + 2 else start + 1
        if (pattern.getOrNull(j) == ']') {
            out.append(if (negated) "[\\s\\S]" else "(?:(?!))")
            return j + 1
        }
        val sets = if (unicode) "dDwWsSpP" else "dDwWsS"
        fun classEscape(at: Int) = pattern[at] == '\\' && pattern.getOrNull(at + 1)?.let { it in sets } == true
        val body = StringBuilder()
        while (j < pattern.length && pattern[j] != ']') {
            val from = j
            val first = classAtom(pattern, j, word, unicode, named) ?: return null
            j = first.end
            if (pattern.getOrNull(j) != '-' || j + 1 >= pattern.length || pattern[j + 1] == ']') {
                body.append(first.text)
                continue
            }
            val second = classAtom(pattern, j + 1, word, unicode, named) ?: return null
            val union = classEscape(from) || classEscape(j + 1)
            if (union && unicode) return null
            body.append(first.text).append(if (union) "\\-" else "-").append(second.text)
            j = second.end
        }
        if (j >= pattern.length) return null
        val exact = "[${if (negated) "^" else ""}$body]"
        val members = if (!fold) null else compileIcuLike("[$body]", 0)
        if (members == null) {
            out.append(exact)
        } else {
            val letters = DartFoldTable.letters
            val probe = members.matcher("")
            val inClass = letters.filter { probe.reset(it.toString()).matches() }.toSet()
            val matched = letters.filter { c -> DartFoldTable.set(c, unicode)!!.any { it in inClass } != negated }
            out.append("(?:(?!(?-i:[$letters]))").append(exact)
            if (matched.isNotEmpty()) out.append("|(?-i:[").append(matched).append("])")
            out.append(')')
        }
        return j + 1
    }

    /**
     * The class member at [j] as the engine's text: a character (ASCII
     * punctuation escaped), a class escape, or an escape for one character,
     * read as [spelled], then [escape], reads it. Null for an escape Dart rejects.
     */
    private fun classAtom(pattern: String, j: Int, word: String, unicode: Boolean, named: Boolean): Escape? {
        val c = pattern[j]
        if (c != '\\') {
            val end = if (unicode) j + Character.charCount(pattern.codePointAt(j)) else j + 1
            val text = if (c in '!'..'~' && !c.isLetterOrDigit()) "\\$c" else pattern.substring(j, end)
            return Escape(end, text, null)
        }
        val piece = when (pattern.getOrNull(j + 1)) {
            'b' -> "\\x08"
            'd' -> "[0-9]"
            'D' -> "[^0-9]"
            's' -> "[$SPACE]"
            'S' -> "[^$SPACE]"
            'w' -> "[$word]"
            'W' -> "[^$word]"
            else -> null
        }
        if (piece != null) return Escape(j + 2, piece, null)
        return spelled(pattern, j, unicode, inClass = true, named) ?: escape(pattern, j, unicode, inClass = true)
    }

    /** The end of the escape at [i]: two characters, or with `\xHH` and `\uHHHH` the digits too. */
    private fun escapeEnd(pattern: String, i: Int): Int {
        val end = i + when (pattern.getOrNull(i + 1)) {
            'x' -> 4
            'u' -> 6
            else -> return minOf(i + 2, pattern.length)
        }
        return if (end <= pattern.length && (i + 2 until end).all { pattern[it] in HEX_DIGITS }) end else i + 2
    }

    /** An escape: where it ends, the text the engine gets, and the code point it spells, if it spells one. */
    private class Escape(val end: Int, val text: String, val codePoint: Int?)

    /**
     * The escape at [i]. `\xHH` and `\uHHHH` spell their code point and stay
     * as written; with [unicode], `\u{H…}` spells its own and is written
     * `\x{H…}` without leading zeros (both engines refuse `\u{`, ICU reads at
     * most six digits). Null for a `\u{…}` Dart rejects under `u`: no digit, a
     * non-hex one, no `}`, or past 10FFFF; with [unicode], `\p` and `\P`
     * are [property]'s. With [unicode] the rest is null but for `\f`, `\n`,
     * `\r`, `\t`, `\xHH`, `\uHHHH`, a syntax character `^ $ \ . * + ? ( ) [ ]
     * { } | /` and [inClass] a `-`. `\k` is null in both modes: a `\k<name>`
     * Dart takes is the caller's, and the letter k [spelled]'s.
     */
    private fun escape(pattern: String, i: Int, unicode: Boolean, inClass: Boolean): Escape? {
        if (pattern.getOrNull(i + 1) == 'k') return null
        if (unicode && pattern.startsWith("u{", i + 1)) {
            val close = pattern.indexOf('}', i + 3)
            if (close < 0) return null
            val digits = pattern.substring(i + 3, close)
            if (digits.isEmpty() || digits.any { it !in HEX_DIGITS }) return null
            val hex = digits.trimStart('0').ifEmpty { "0" }
            if (hex.length > 6) return null
            val value = hex.toInt(16)
            return if (value > 0x10FFFF) null else Escape(close + 1, "\\x{$hex}", value)
        }
        if (unicode && pattern.getOrNull(i + 1).let { it == 'p' || it == 'P' }) return property(pattern, i)
        val end = escapeEnd(pattern, i)
        val digits = when (pattern.getOrNull(i + 1)) {
            'x' -> 2
            'u' -> 4
            else -> null
        }
        val spelled = digits != null && end - i == digits + 2
        if (unicode) {
            val next = pattern.getOrNull(i + 1)
            val strict = when (next) {
                null -> false
                'x', 'u' -> spelled
                'f', 'n', 'r', 't' -> true
                '-' -> inClass
                else -> next in "^$\\.*+?()[]{}|/"
            }
            if (!strict) return null
        }
        return Escape(end, pattern.substring(i, end), if (spelled) pattern.substring(i + 2, end).toInt(16) else null)
    }

    /**
     * With `u`, the property escape `\p{name}` or `\P{name}` at [i], its
     * name written the JVM's way on the JVM and as it is on Android. Null
     * without `{…}`, for a name Dart refuses, or on the JVM for one it has
     * no spelling of.
     */
    private fun property(pattern: String, i: Int): Escape? {
        val close = if (pattern.getOrNull(i + 2) == '{') pattern.indexOf('}', i + 3) else -1
        if (close < 0) return null
        val name = pattern.substring(i + 3, close)
        if (!RegexPropertyNames.accepts(name)) return null
        val text = if (unicodeClasses) RegexPropertyNames.jvm(name, negated = pattern[i + 1] == 'P') else pattern.substring(i, close + 1)
        return text?.let { Escape(close + 1, it, null) }
    }

    private const val HEX_DIGITS = "0123456789abcdefABCDEF"

    /**
     * `\s` as Dart reads it, ECMAScript's WhiteSpace and LineTerminator, under
     * every flag: the JVM's and ICU's take U+0085 and leave U+FEFF out.
     */
    private const val SPACE = "\\t-\\r\\x{20}\\x{a0}\\x{1680}\\x{2000}-\\x{200a}\\x{2028}\\x{2029}\\x{202f}\\x{205f}\\x{3000}\\x{feff}"

    /**
     * Whether the runtime has UNICODE_CHARACTER_CLASS: the JVM does, Android,
     * whose regex is ICU and Unicode-aware already, does not.
     */
    private val unicodeClasses: Boolean = try {
        Pattern.compile("", Pattern.UNICODE_CHARACTER_CLASS)
        true
    } catch (_: IllegalArgumentException) {
        false
    }

    /** Null for an invalid pattern. */
    fun compileIcuLike(pattern: String, options: Int): Pattern? = try {
        Pattern.compile(pattern, if (unicodeClasses) options or Pattern.UNICODE_CHARACTER_CLASS else options)
    } catch (_: IllegalArgumentException) {
        null
    }

    fun clip(s: String): String =
        if (s.length <= MAX_INPUT_LENGTH) s else SwiftText.repairingSurrogates(s.substring(0, MAX_INPUT_LENGTH))

    /**
     * Java's multiline `^` never matches at the end of input, not even at
     * the start of an empty one, where ICU's does; with no line in the input
     * the flag changes nothing else, so an empty input drops it.
     */
    private fun matcher(re: Pattern, input: String) =
        if (input.isEmpty() && re.flags() and Pattern.MULTILINE != 0) {
            Pattern.compile(re.pattern(), re.flags() and Pattern.MULTILINE.inv()).matcher(input)
        } else {
            re.matcher(input)
        }

    fun firstMatch(re: Pattern, input: String): Match? {
        val m = matcher(re, input)
        return if (m.find()) Match(m.toMatchResult()) else null
    }

    fun allMatches(re: Pattern, input: String): List<Match> {
        val m = matcher(re, input)
        val out = ArrayList<Match>()
        while (m.find()) out.add(Match(m.toMatchResult()))
        return out
    }

    /**
     * Dart: `replacement.replaceAllMapped(RegExp(r'\$([1-9])'), ...)`; a group
     * past the pattern's count, or one that did not take part, is "". Walks
     * Characters, as Swift does.
     */
    fun expandBackrefs(replacement: String, m: Match): String {
        val chars = SwiftText.graphemes(replacement)
        val out = StringBuilder()
        var i = 0
        while (i < chars.size) {
            val c = chars[i]
            val d = chars.getOrNull(i + 1)
            if (c == "$" && d != null && d.length == 1 && d[0] in '1'..'9') {
                val n = d[0] - '0'
                out.append(if (n > m.groupCount) "" else (m.group(n) ?: ""))
                i += 2
            } else {
                out.append(c)
                i += 1
            }
        }
        return out.toString()
    }
}

// MARK: - Dates

internal data class DateParts(
    val year: Int,
    val month: Int,
    val day: Int,
    val hour: Int,
    val minute: Int,
    val second: Int,
) {
    companion object {
        private val iso: Pattern = RegexSupport.compileIcuLike(
            "^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[T ](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,]\\d+)?)?)?)?\\s*(Z|[+-]\\d\\d(?::?\\d\\d)?)?$",
            Pattern.CASE_INSENSITIVE,
        )!!

        fun of(value: JsonValue): DateParts? = when (value) {
            is JsonValue.Int, is JsonValue.Double -> {
                // JS Dates span ±8.64e15 ms; outside that is an Invalid Date.
                val ms = value.doubleValue
                if (ms == null || !ms.isFinite() || abs(ms) > 8.64e15) null else fromEpochMillis(ms)
            }
            is JsonValue.String -> fromIso(value.value)
            else -> null
        }

        /**
         * UTC fields of an instant, on the Gregorian calendar with the Julian
         * cutover of 1582 (Foundation's `.gregorian` calendar, as Swift uses).
         */
        fun fromEpochMillis(ms: Double): DateParts {
            val calendar = GregorianCalendar(TimeZone.getTimeZone("UTC"))
            calendar.timeInMillis = floor(ms).toLong()
            return DateParts(
                calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH) + 1, calendar.get(Calendar.DAY_OF_MONTH),
                calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), calendar.get(Calendar.SECOND),
            )
        }

        /**
         * `YYYY-MM-DD[(T| )HH:MM[:SS[.fff]]][Z|±HH[:]MM]`, as Dart's
         * `DateTime.tryParse` reads it.
         */
        fun fromIso(s: String): DateParts? {
            val m = iso.matcher(s)
            if (!m.find()) return null
            fun group(i: Int): String? = m.group(i)
            fun int(text: String?): Int? = text?.let(SwiftText::parseInt)?.takeIf { it in Int.MIN_VALUE..Int.MAX_VALUE }?.toInt()
            val y = int(group(1)) ?: return null
            val mo = int(group(2)) ?: return null
            val d = int(group(3)) ?: return null
            val h = int(group(4) ?: "0") ?: 0
            val mi = int(group(5) ?: "0") ?: 0
            val sec = int(group(6) ?: "0") ?: 0
            if (mo !in 1..12 || d !in 1..31 || h > 24 || mi >= 60 || sec >= 60) return null

            val zone = group(7)
            if (zone != null && SwiftText.uppercased(zone) != "Z") {
                val sign = if (zone.startsWith("-")) -1 else 1
                val digits = zone.drop(1).filter { Character.isDigit(it) }
                val oh = int(digits.take(2)) ?: 0
                val om = int(digits.drop(2)) ?: 0
                val calendar = GregorianCalendar(TimeZone.getTimeZone("UTC"))
                calendar.clear()
                calendar.set(y, mo - 1, d, h, mi, sec)
                val utc = calendar.timeInMillis - sign * (oh * 3600L + om * 60L) * 1000L
                return fromEpochMillis(utc.toDouble())
            }
            return DateParts(y, mo, d, h, mi, sec)
        }
    }
}
