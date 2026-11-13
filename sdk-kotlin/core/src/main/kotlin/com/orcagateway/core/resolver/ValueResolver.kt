package com.orcagateway.core.resolver

import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.SwiftText
import com.orcagateway.core.models.BoolExpr
import com.orcagateway.core.models.Value
import kotlin.math.max
import kotlin.math.min

/**
 * Resolves wire Values against state, a port of the Flutter SDK's
 * `sdk/lib/src/state/value_resolver.dart` (the reference client), by way of
 * the Swift SDK's `ValueResolver`.
 *
 * It works on raw [JsonValue] exactly as the Dart one works on
 * `Map<String, dynamic>`: literals pass through, a map whose `type` is a
 * client-side Value kind resolves, anything else is returned unchanged
 * (including `info` and `request`, which the engine resolves before sending).
 *
 * One deliberate difference from Dart: where Dart throws a TypeError or
 * RangeError (an `add` on a string, `substring` past the end, `round` on
 * null) the widget build fails in Flutter; here the step yields
 * [JsonValue.Null] instead, because a crash would take the whole app down.
 * Everything else, including the null semantics of the BoolExpr ops, follows
 * Dart line by line.
 *
 * Text follows Dart (row 23b.33): `eq`, `neq`, `contains`, `startsWith`
 * and `split` compare and cut UTF-16 code units with no normalization, a
 * string contains the empty string, an empty regex matches everywhere and
 * regex `\d`/`\w` are ASCII. Still Swift's: sort order, the whitespace set
 * of `trim`, per-scalar lowercasing, ASCII-only integer parsing, and the
 * Characters of the tween colour test and of `$n` backrefs (SwiftText).
 */
public class ValueResolver(
    /** Merged state, app first and page on top, as the Dart SDK builds it. */
    public val state: Map<String, JsonValue>,
    /** Event payload of the trigger that fired the current action, if any. */
    public val eventData: Map<String, JsonValue>? = null,
    /** Progress (0..1) of the enclosing animation; null outside one. */
    public val animationProgress: Double? = null,
    /** Progress of a targeted animation by id (Dart's AnimationRegistry). */
    public val animationProgressFor: ((String) -> Double?)? = null,
    public val transforms: TransformRegistry = TransformRegistry.defaults,
) {
    /** Merge app and page scopes the way every Dart call site does: page wins. */
    public constructor(
        page: Map<String, JsonValue>,
        app: Map<String, JsonValue>,
        eventData: Map<String, JsonValue>? = null,
    ) : this(state = app + page, eventData = eventData)

    // MARK: resolve

    /**
     * Resolve one value expression (Dart `resolve`). Does not descend into
     * plain maps or lists; use [resolveDeep] for props.
     */
    public fun resolve(value: JsonValue): JsonValue {
        val map = value.objectValue ?: return value
        return when (map["type"]?.stringValue) {
            "static" -> map["value"] ?: JsonValue.Null
            "state" -> resolveState(map)
            "event" -> resolveEvent(map)
            "transform" -> resolveTransform(map)
            "conditional" -> resolveConditional(map)
            "tween" -> resolveTween(map)
            "tweenSequence" -> resolveTweenSequence(map)
            else -> value
        }
    }

    public fun resolve(value: Value): JsonValue = resolve(value.json)

    /** Resolve and render as text: null becomes "", everything else Dart's `'$value'`. */
    public fun resolveToString(value: JsonValue): String {
        val resolved = resolve(value)
        return if (resolved.isNull) "" else DartFormat.string(resolved)
    }

    /** Resolve every Value nested in plain maps and lists (Dart `resolveDeep`). */
    public fun resolveDeep(value: JsonValue): JsonValue = when (value) {
        is JsonValue.Array -> JsonValue.Array(value.items.map(::resolveDeep))
        is JsonValue.Object -> {
            val type = value.members["type"]?.stringValue
            if (type != null && type in valueTypes) {
                resolve(value)
            } else {
                JsonValue.Object(value.members.mapValues { resolveDeep(it.value) })
            }
        }
        else -> value
    }

    // MARK: kinds

    private fun resolveState(map: Map<String, JsonValue>): JsonValue {
        val key = map["key"]?.stringValue ?: return JsonValue.Null
        return StatePath.lookup(state, key)
    }

    private fun resolveEvent(map: Map<String, JsonValue>): JsonValue {
        val key = map["key"]?.stringValue ?: return JsonValue.Null
        val eventData = eventData ?: return JsonValue.Null
        return eventData[key] ?: JsonValue.Null
    }

    private fun resolveConditional(map: Map<String, JsonValue>): JsonValue {
        map["branches"]?.arrayValue?.let { branches ->
            for (branch in branches) {
                val b = branch.objectValue ?: continue
                val condition = b["when"]?.objectValue
                if (condition != null && evaluate(condition)) {
                    return resolve(b["then"] ?: JsonValue.Null)
                }
            }
        }
        val elseValue = map["else"] ?: JsonValue.Null
        return if (elseValue.isNull) JsonValue.Null else resolve(elseValue)
    }

    private fun resolveTransform(map: Map<String, JsonValue>): JsonValue {
        var current = resolve(map["input"] ?: JsonValue.Null)
        val pipeline = map["by"]?.arrayValue ?: return current
        for (step in pipeline) {
            val def = step.objectValue ?: continue
            val type = def["type"]?.stringValue ?: continue
            val op = transforms[type] ?: continue
            current = op(def, current, this)
        }
        return current
    }

    // MARK: tweens

    private fun progress(map: Map<String, JsonValue>): Double {
        val id = map["animationId"]?.stringValue
        val lookup = animationProgressFor
        if (id != null && lookup != null) return lookup(id) ?: 0.0
        return animationProgress ?: 0.0
    }

    private fun resolveTween(map: Map<String, JsonValue>): JsonValue {
        val t = progress(map)
        return lerp(map["begin"] ?: JsonValue.Null, map["end"] ?: JsonValue.Null, t)
    }

    private fun resolveTweenSequence(map: Map<String, JsonValue>): JsonValue {
        val t = progress(map)
        val items = map["items"]?.arrayValue
        if (items.isNullOrEmpty()) return JsonValue.Null

        var total = 0.0
        for (item in items) {
            if (item is JsonValue.Object) total += item["duration"].doubleValue ?: 0.0
        }
        if (total <= 0) return items[0]["value"]

        val currentTime = t * total
        var elapsed = 0.0
        for ((i, item) in items.withIndex()) {
            val duration = item["duration"].doubleValue ?: 0.0
            val value = item["value"]
            if (duration <= 0) continue
            if (currentTime <= elapsed + duration) {
                val segment = (currentTime - elapsed) / duration
                val previous = if (i > 0) items[i - 1]["value"] else value
                return lerp(previous, value, segment)
            }
            elapsed += duration
        }
        return items[items.size - 1]["value"]
    }

    // MARK: BoolExpr

    /** Evaluate a wire BoolExpr (Dart `evaluateBoolExpr`). */
    public fun evaluate(expr: Map<String, JsonValue>): Boolean {
        val op = expr["op"]?.stringValue ?: return false
        fun operand(key: String): JsonValue = resolve(expr[key] ?: JsonValue.Null)

        return when (op) {
            "eq" -> operand("left") == operand("right")
            "neq" -> operand("left") != operand("right")
            "gt" -> compareNum(expr) > 0
            "gte" -> compareNum(expr) >= 0
            "lt" -> compareNum(expr) < 0
            "lte" -> compareNum(expr) <= 0
            "and" -> (expr["exprs"]?.arrayValue ?: emptyList()).all { e -> e.objectValue?.let(::evaluate) ?: false }
            "or" -> (expr["exprs"]?.arrayValue ?: emptyList()).any { e -> e.objectValue?.let(::evaluate) ?: false }
            "not" -> {
                val inner = expr["expr"]?.objectValue ?: return true
                !evaluate(inner)
            }
            "isNull" -> operand("value").isNull
            "contains" -> {
                val haystack = operand("haystack")
                val needle = operand("needle")
                when (haystack) {
                    is JsonValue.String -> haystack.value.contains(DartFormat.string(needle))
                    is JsonValue.Array -> haystack.items.contains(needle)
                    else -> false
                }
            }
            "startsWith" -> DartFormat.string(operand("str")).startsWith(DartFormat.string(operand("prefix")))
            "matches" -> {
                val pattern = expr["regex"]?.stringValue ?: ""
                if (pattern.length > RegexSupport.MAX_PATTERN_LENGTH) return false
                val input = RegexSupport.clip(DartFormat.string(operand("str")))
                val search = RegexSupport.search(pattern, null, input) ?: return false
                RegexSupport.firstMatch(search) != null
            }
            else -> false
        }
    }

    public fun evaluate(expr: BoolExpr): Boolean {
        val map = expr.json.objectValue ?: return false
        return evaluate(map)
    }

    /**
     * Dart `_compareNum`: compares when both sides are numbers, else 0, so
     * `gte` and `lte` hold for a missing operand while `gt` and `lt` do not.
     */
    private fun compareNum(expr: Map<String, JsonValue>): Int {
        val l = resolve(expr["left"] ?: JsonValue.Null)
        val r = resolve(expr["right"] ?: JsonValue.Null)
        if (l is JsonValue.Int && r is JsonValue.Int) return l.value.compareTo(r.value)
        val a = l.doubleValue ?: return 0
        val b = r.doubleValue ?: return 0
        if (a < b) return -1
        if (a > b) return 1
        if (a == b) return 0
        // Dart's compareTo puts NaN above everything, itself included.
        return if (a.isNaN()) (if (b.isNaN()) 0 else 1) else -1
    }

    public companion object {
        /** The nine Value kinds; a map with one of these `type`s is a Value. */
        public val valueTypes: Set<String> = Value.kinds.toSet()

        /**
         * Numbers interpolate (always to a double, as Dart's
         * `num + num * double`), `#hex` colours interpolate per channel,
         * anything else snaps at 0.5.
         */
        internal fun lerp(a: JsonValue, b: JsonValue, t: Double): JsonValue {
            val x = a.doubleValue
            val y = b.doubleValue
            if (x != null && y != null) return JsonValue.Double(x + (y - x) * t)
            if (a is JsonValue.String && b is JsonValue.String && SwiftText.hasPrefix(a.value, "#") &&
                SwiftText.hasPrefix(b.value, "#")
            ) {
                val color = lerpColor(a.value, b.value, t) ?: return JsonValue.Null
                return JsonValue.String(color)
            }
            return if (t < 0.5) a else b
        }

        internal fun lerpColor(hexA: String, hexB: String, t: Double): String? {
            fun parse(hex: String): Long? {
                // Swift drops the first Character and counts Characters.
                val characters = SwiftText.graphemes(hex).drop(1)
                val h = characters.joinToString("")
                return when (characters.size) {
                    6 -> SwiftText.parseHexUInt32("FF$h")
                    8 -> SwiftText.parseHexUInt32(h)
                    else -> 0xFF00_0000L
                }
            }
            val a = parse(hexA) ?: return null
            val b = parse(hexB) ?: return null
            fun channel(shift: Int): Long {
                val ca = ((a shr shift) and 0xFF).toDouble()
                val cb = ((b shr shift) and 0xFF).toDouble()
                val v = roundHalfAwayFromZero(ca + (cb - ca) * t)
                if (!v.isFinite()) return 0
                return min(max(v, 0.0), 255.0).toLong()
            }
            val value = (channel(24) shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
            return "#" + value.toString(16).uppercase().padStart(8, '0')
        }
    }
}

/** Swift's `rounded(.toNearestOrAwayFromZero)`. */
internal fun roundHalfAwayFromZero(d: Double): Double {
    if (!d.isFinite()) return d
    val t = kotlin.math.truncate(d)
    val frac = d - t
    return when {
        frac >= 0.5 -> t + 1
        frac <= -0.5 -> t - 1
        else -> t
    }
}

/** Dotted state paths, shared by the resolver and the store's watch snapshots. */
public object StatePath {
    /**
     * Dart `lookupStatePath`: the flat key wins when present; otherwise walk
     * `theme.color` or `items.0.name` through nested objects and arrays.
     * Matches the engine's `getByDotPath`; pinned by render fixture 06.
     */
    public fun lookup(state: Map<String, JsonValue>, key: String): JsonValue {
        state[key]?.let { return it }
        if (!key.contains(".")) return JsonValue.Null
        var current: JsonValue = JsonValue.Object(state)
        for (segment in key.split(".")) {
            current = when (current) {
                is JsonValue.Object -> current.members[segment] ?: JsonValue.Null
                is JsonValue.Array -> {
                    val i = SwiftText.parseInt(segment) ?: return JsonValue.Null
                    if (i < 0 || i >= current.items.size) return JsonValue.Null
                    current.items[i.toInt()]
                }
                else -> return JsonValue.Null
            }
            if (current.isNull) return JsonValue.Null
        }
        return current
    }
}
