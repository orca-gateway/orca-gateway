package com.orcagateway.core.resolver

import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.SwiftText
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone
import java.util.regex.Pattern
import java.util.regex.PatternSyntaxException
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
            val parts = if (separator.isEmpty()) SwiftText.graphemes(s) else s.split(separator)
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
                is JsonValue.String -> JsonValue.Bool(SwiftText.contains(current.value, DartFormat.string(value)))
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
 * java.util.regex standing in for Swift's NSRegularExpression (ICU), itself
 * standing in for Dart's ECMAScript `RegExp`, with the same guard rails:
 * patterns over 200 UTF-16 units are refused and the input is clipped to
 * 10 000 units. Compiled with UNICODE_CHARACTER_CLASS where the runtime has
 * it, so `\d`, `\w`, `\s` and `\b` are Unicode-aware as in ICU.
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
        var options = 0
        if (flags != null) {
            if (flags.contains('i')) options = options or Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE
            if (flags.contains('m')) options = options or Pattern.MULTILINE
            if (flags.contains('s')) options = options or Pattern.DOTALL
        }
        return compileIcuLike(pattern, options)
    }

    /**
     * Null for an invalid pattern, and for the empty pattern, which
     * NSRegularExpression refuses (Dart's `RegExp('')` matches everywhere).
     */
    fun compileIcuLike(pattern: String, options: Int): Pattern? = if (pattern.isEmpty()) null else try {
        Pattern.compile(pattern, options or Pattern.UNICODE_CHARACTER_CLASS)
    } catch (_: PatternSyntaxException) {
        null
    } catch (_: IllegalArgumentException) {
        // A runtime without UNICODE_CHARACTER_CLASS (Android, whose regex is
        // ICU and Unicode-aware already).
        try {
            Pattern.compile(pattern, options)
        } catch (_: IllegalArgumentException) {
            null
        }
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
