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
 * `\d`, `\w`, `\b` and their negations, the case folding of the letters
 * of [DartFoldTable] and, with `u`, the `\p{…}` names are rewritten to
 * Dart's ([asciiClasses]); the pattern is then compiled with
 * UNICODE_CHARACTER_CLASS where the runtime has it (learned once: the JVM
 * does, Android's ICU regex is Unicode-aware already), so `\s` is Unicode as
 * Dart's is.
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
     * - `\d`, `\w`, `\D`, `\W` are ASCII classes. Inside a character class
     *   they nest, which both engines read as a union (`[a\D]` is `[a[^0-9]]`).
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
     * group names, a modifier group's flags (`(?ms-i:`), the digits of `\xHH` and
     * `\uHHHH`, and what follows `\c`, `\k<` and, without `u`, `\p{`. An `\xHH`,
     * `\uHHHH` or with `u` `\u{H…}` that spells a letter of the table is that
     * letter (`\x73` under `i` is `(?-i:[sS])`); inside a class the members test
     * reads it. With `u`, `\u{H…}` is written `\x{H…}`, in a class too, and one
     * Dart rejects (`\u{}`, `\u{g}`, `\u{110000}`) gives null; without `u` it is
     * left as it is. Backreferences keep the engine's folding.
     *
     * With `u`, `\p{name}` and `\P{name}` take only the names Dart takes
     * ([RegexPropertyNames]): any other name, or `\p` or `\P` without `{…}`,
     * gives null, in a class too. On the JVM an accepted name is written the
     * way java.util.regex reads Dart's set (`Lowercase_Letter` as `Ll`,
     * `Alphabetic` as `IsAlphabetic`, `Any` as a class), and one it has no such
     * spelling of (`Script_Extensions`, `Cased`, `Math` …) gives null; on
     * Android the name stays as written. Without `u`, `\p{…}` is left as it is.
     */
    fun asciiClasses(pattern: String, ignoreCase: Boolean = false, unicode: Boolean = false): String? {
        if (!ignoreCase && pattern.none { it == '\\' || it == '[' || it == '(' }) return pattern
        val open = ArrayList<Boolean>() // the `i` of each open group
        val out = StringBuilder(pattern.length + 16)
        var i = 0
        while (i < pattern.length) {
            val c = pattern[i]
            val fold = open.lastOrNull() ?: ignoreCase
            val word = if (fold && unicode) "A-Za-z0-9_\u017F\u212A" else "A-Za-z0-9_"
            val w = "(?-i:[$word])"
            val folded = if (fold) DartFoldTable.set(c, unicode) else null
            when {
                c == '\\' -> {
                    val piece = when (pattern.getOrNull(i + 1)) {
                        'd' -> "[0-9]"
                        'D' -> "[^0-9]"
                        'w' -> w
                        'W' -> "(?-i:[^$word])"
                        'b' -> "(?:(?<=$w)(?!$w)|(?<!$w)(?=$w))"
                        'B' -> "(?:(?<=$w)(?=$w)|(?<!$w)(?!$w))"
                        else -> null
                    }
                    if (piece != null) {
                        out.append(piece)
                        i += 2
                    } else {
                        val escape = escape(pattern, i, unicode) ?: return null
                        val letter = escape.codePoint?.takeIf { fold && it <= 0xFFFF }?.let { DartFoldTable.set(it.toChar(), unicode) }
                        if (letter != null) out.append("(?-i:[").append(letter).append("])") else out.append(escape.text)
                        i = escape.end
                    }
                }
                c == '[' -> i = characterClass(pattern, i, word, fold, unicode, out) ?: return null
                c == '(' -> {
                    val (end, inner) = groupOpening(pattern, i, fold) ?: return null
                    open.add(inner)
                    out.append(pattern, i, end) // a group name, or `(?ms-i:` whose flags the engine reads as Dart does
                    i = end
                }
                c == ')' -> {
                    open.removeLastOrNull()
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

    /**
     * The end of the group opening at [i] and the group's `i`: [fold], the
     * enclosing one, unless modifiers add or remove it. Null for a `(?` form
     * Dart rejects.
     */
    private fun groupOpening(pattern: String, i: Int, fold: Boolean): Pair<Int, Boolean>? {
        if (pattern.getOrNull(i + 1) != '?') return i + 1 to fold
        val next = pattern.getOrNull(i + 2)
        return when {
            next == ':' || next == '=' || next == '!' -> i + 3 to fold
            next == '<' && pattern.getOrNull(i + 3).let { it == '=' || it == '!' } -> i + 4 to fold
            next == '<' -> pattern.indexOf('>', i).let { if (it < 0) pattern.length else it + 1 } to fold
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
                e + 1 to if (at < 0) fold else dash < 0 || at < dash
            }
        }
    }

    /**
     * The class opening at [start], up to its first unescaped `]` as in
     * ECMAScript, appended to [out]; returns the index after it, or null for a
     * `\u{…}` Dart rejects. [fold] is the group's `i`, [unicode] the `u` flag.
     * Unclosed, it is copied as it is and fails to compile, as in Dart.
     */
    private fun characterClass(pattern: String, start: Int, word: String, fold: Boolean, unicode: Boolean, out: StringBuilder): Int? {
        val negated = pattern.getOrNull(start + 1) == '^'
        val body = StringBuilder()
        var j = if (negated) start + 2 else start + 1
        while (j < pattern.length && pattern[j] != ']') {
            val c = pattern[j]
            if (c != '\\') {
                if (c == '[') body.append("\\[") else body.append(c)
                j += 1
                continue
            }
            val piece = when (pattern.getOrNull(j + 1)) {
                'b' -> "\\x08"
                'd' -> "[0-9]"
                'D' -> "[^0-9]"
                'w' -> "[$word]"
                'W' -> "[^$word]"
                else -> null
            }
            if (piece != null) {
                body.append(piece)
                j += 2
            } else {
                val escape = escape(pattern, j, unicode) ?: return null
                body.append(escape.text)
                j = escape.end
            }
        }
        if (j >= pattern.length) {
            out.append(pattern, start, pattern.length)
            return pattern.length
        }
        val exact = "[${if (negated) "^" else ""}$body]"
        // A leading `^` of the body is a member (`[^^a]`), not a negation.
        val literal = if (body.startsWith('^')) "\\$body" else body
        val members = if (!fold || body.isEmpty()) null else compileIcuLike("[$literal]", 0)
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
     * The end of the escape at [i]: two characters, or with `\cX`, `\xHH`,
     * `\uHHHH`, `\k<…>`, `\p{…}`, `\P{…}` the argument too.
     */
    private fun escapeEnd(pattern: String, i: Int): Int {
        val close = when (pattern.getOrNull(i + 1)) {
            'c' -> return minOf(i + 3, pattern.length)
            'x', 'u' -> {
                val end = i + if (pattern[i + 1] == 'x') 4 else 6
                return if (end <= pattern.length && (i + 2 until end).all { pattern[it] in HEX_DIGITS }) end else i + 2
            }
            'k' -> '>'.takeIf { pattern.getOrNull(i + 2) == '<' }
            'p', 'P' -> '}'.takeIf { pattern.getOrNull(i + 2) == '{' }
            else -> null
        } ?: return minOf(i + 2, pattern.length)
        val end = pattern.indexOf(close, i + 3)
        return if (end < 0) pattern.length else end + 1
    }

    /** An escape: where it ends, the text the engine gets, and the code point it spells, if it spells one. */
    private class Escape(val end: Int, val text: String, val codePoint: Int?)

    /**
     * The escape at [i]. `\xHH` and `\uHHHH` spell their code point and stay
     * as written; with [unicode], `\u{H…}` spells its own and is written
     * `\x{H…}` without leading zeros (both engines refuse `\u{`, ICU reads at
     * most six digits). Null for a `\u{…}` Dart rejects under `u`: no digit, a
     * non-hex one, no `}`, or past 10FFFF; with [unicode], `\p` and `\P`
     * are [property]'s.
     */
    private fun escape(pattern: String, i: Int, unicode: Boolean): Escape? {
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
