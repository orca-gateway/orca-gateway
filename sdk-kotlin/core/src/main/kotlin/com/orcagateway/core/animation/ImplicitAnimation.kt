package com.orcagateway.core.animation

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.resolver.roundHalfAwayFromZero

/**
 * What Flutter's implicitly animated widgets do (AnimatedContainer,
 * AnimatedOpacity, AnimatedAlign), with no timer inside: it holds where a
 * run came from, where it goes and when it began, and [value] mixes the two
 * at the time given. For a widget [T] is its resolved props and [mix] is
 * [AnimationMix.props]; a route transition can run a plain number.
 *
 * The first target is shown as it is. A new target starts a run of the full
 * [durationMs] from the value on screen, also in the middle of a run. With
 * [reduceMotion], or a duration of 0 or less, a new target is shown at once.
 * A live run keeps the [durationMs] and [curve] it began with: a change of
 * either applies from the next [retarget].
 */
public class ImplicitAnimation<T : Any>(
    public var durationMs: Double = AnimationDuration.DEFAULT_MS,
    public var curve: String? = null,
    public var reduceMotion: Boolean = false,
    private val mix: (from: T, to: T, t: Double) -> T,
) {
    private var from: T? = null
    private var start = 0.0
    private var runDurationMs = 0.0
    private var runCurve: String? = null

    /** The latest target; null before the first [retarget]. */
    public var target: T? = null
        private set

    /** Sets what the widget's props resolve to at [now]; the same target again changes nothing. */
    public fun retarget(to: T, now: Double) {
        if (to == target) return
        from = value(now)
        target = to
        start = now
        runDurationMs = durationMs
        runCurve = curve
    }

    /** What to draw at [now]; null before the first target. */
    public fun value(now: Double): T? {
        val to = target ?: return null
        val origin = from
        if (origin == null || !isRunning(now)) return to
        return mix(origin, to, Curves.apply(runCurve, (now - start) / runDurationMs))
    }

    /** Whether the value still moves at [now]: the UI ticks only while true. */
    public fun isRunning(now: Double): Boolean =
        from != null && !reduceMotion && runDurationMs > 0 && now < start + runDurationMs
}

/** Flutter's `Alignment(x, y)`: -1 is left or top, 0 the centre, 1 right or bottom. */
public data class AlignmentBias(public val x: Double, public val y: Double) {
    /** The form a mixed alignment has in sampled props: `{x, y}`. */
    public val json: JsonValue
        get() = JsonValue.Object(mapOf("x" to JsonValue.Double(x), "y" to JsonValue.Double(y)))

    public companion object {
        public val center: AlignmentBias = AlignmentBias(0.0, 0.0)

        private val names: Map<String, AlignmentBias> = mapOf(
            "topLeft" to AlignmentBias(-1.0, -1.0),
            "topCenter" to AlignmentBias(0.0, -1.0),
            "topRight" to AlignmentBias(1.0, -1.0),
            "centerLeft" to AlignmentBias(-1.0, 0.0),
            "center" to center,
            "centerRight" to AlignmentBias(1.0, 0.0),
            "bottomLeft" to AlignmentBias(-1.0, 1.0),
            "bottomCenter" to AlignmentBias(0.0, 1.0),
            "bottomRight" to AlignmentBias(1.0, 1.0),
        )

        /** Flutter `parseAlignment`: the nine names, anything else the centre. */
        public fun named(name: String?): AlignmentBias = names[name] ?: center

        /** A prop value: one of the nine names, or the `{x, y}` of a mixed alignment; anything else the centre. */
        public fun of(value: JsonValue?): AlignmentBias {
            val o = value?.objectValue ?: return named(value?.stringValue)
            return AlignmentBias(o["x"]?.doubleValue ?: 0.0, o["y"]?.doubleValue ?: 0.0)
        }

        /**
         * What a mix accepts: a name (one outside the nine is the centre) or
         * a complete `{x, y}`; null for anything else, which snaps.
         */
        internal fun mixable(value: JsonValue?): AlignmentBias? {
            value?.stringValue?.let { return named(it) }
            val o = value?.objectValue ?: return null
            return AlignmentBias(o["x"]?.doubleValue ?: return null, o["y"]?.doubleValue ?: return null)
        }
    }
}

/**
 * The mixes of an implicit animation, each at a curved time [t] (0 the old
 * value, 1 the new one; an elastic or back curve leaves 0...1). What cannot
 * be mixed snaps: it is the new value from the start.
 */
public object AnimationMix {
    private val numbers = setOf("width", "height", "opacity", "widthFactor", "heightFactor")
    private val insets = setOf("padding", "margin")
    private val sides = listOf("top", "right", "bottom", "left")
    private val corners = listOf("topLeft", "topRight", "bottomLeft", "bottomRight")

    public fun number(from: Double, to: Double, t: Double): Double = from + (to - from) * t

    /**
     * Two widget colours (`#RRGGBB` or `#RRGGBBAA`, as the builders read
     * them) mixed channel by channel, as `#RRGGBBAA`; null when either is
     * not such a colour. Each channel stays within 0...255.
     */
    public fun color(from: String, to: String, t: Double): String? {
        val a = channels(from) ?: return null
        val b = channels(to) ?: return null
        return "#" + a.indices.joinToString("") { i ->
            val v = roundHalfAwayFromZero(number(a[i].toDouble(), b[i].toDouble(), t))
            val channel = if (v.isFinite()) v.coerceIn(0.0, 255.0).toInt() else 0
            channel.toString(16).uppercase().padStart(2, '0')
        }
    }

    public fun alignment(from: AlignmentBias, to: AlignmentBias, t: Double): AlignmentBias =
        AlignmentBias(number(from.x, to.x, t), number(from.y, to.y, t))

    /** Two `{top, right, bottom, left}` (a missing side is 0) mixed side by side; else [to]. */
    public fun edgeInsets(from: JsonValue?, to: JsonValue?, t: Double): JsonValue? {
        val a = from?.objectValue ?: return to
        val b = to?.objectValue ?: return to
        return JsonValue.Object(sides.associateWith { JsonValue.Double(number(part(a, it), part(b, it), t)) })
    }

    /**
     * Two decorations: `color`, `borderRadius` (a number, or four corners)
     * and the border's `width` and `color` are mixed when both have them;
     * everything else (gradient, shadows, a part only one side has) is
     * [to]'s. Not two objects: [to].
     */
    public fun decoration(from: JsonValue?, to: JsonValue?, t: Double): JsonValue? {
        val a = from?.objectValue ?: return to
        val b = to?.objectValue ?: return to
        val mixed = b.toMutableMap()
        colorValue(a["color"], b["color"], t)?.let { mixed["color"] = it }
        radius(a["borderRadius"], b["borderRadius"], t)?.let { mixed["borderRadius"] = it }
        border(a["border"], b["border"], t)?.let { mixed["border"] = it }
        return JsonValue.Object(mixed)
    }

    /**
     * The props of an animated widget between [from] and [to]: `width`,
     * `height`, `opacity`, `widthFactor`, `heightFactor` as numbers, `color`
     * as a colour, `padding` and `margin` as insets, `decoration` by parts,
     * and `alignment` as a point, written `{x, y}` ([AlignmentBias.of] reads
     * it), when each side is a name or a complete `{x, y}` and the two
     * differ. Every other prop, and one a side lacks, is [to]'s.
     */
    public fun props(from: Map<String, JsonValue>, to: Map<String, JsonValue>, t: Double): Map<String, JsonValue> {
        val mixed = to.toMutableMap()
        for ((key, b) in to) {
            val a = from[key] ?: continue
            when (key) {
                in numbers -> {
                    val x = a.doubleValue
                    val y = b.doubleValue
                    if (x != null && y != null) mixed[key] = JsonValue.Double(number(x, y, t))
                }
                "color" -> colorValue(a, b, t)?.let { mixed[key] = it }
                in insets -> edgeInsets(a, b, t)?.let { mixed[key] = it }
                "decoration" -> decoration(a, b, t)?.let { mixed[key] = it }
                "alignment" -> if (a != b) {
                    val p = AlignmentBias.mixable(a)
                    val q = AlignmentBias.mixable(b)
                    if (p != null && q != null) mixed[key] = alignment(p, q, t).json
                }
            }
        }
        return mixed
    }

    private fun part(o: Map<String, JsonValue>, key: String): Double = o[key]?.doubleValue ?: 0.0

    private fun colorValue(from: JsonValue?, to: JsonValue?, t: Double): JsonValue? {
        val a = from?.stringValue ?: return null
        val b = to?.stringValue ?: return null
        return color(a, b, t)?.let { JsonValue.String(it) }
    }

    /** Red, green, blue, alpha of `#RRGGBB` or `#RRGGBBAA`; hex digits only. */
    private fun channels(text: String): List<Int>? {
        if (!text.startsWith("#")) return null
        val hex = text.substring(1)
        if (hex.length != 6 && hex.length != 8) return null
        if (!hex.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }) return null
        return (if (hex.length == 6) hex + "FF" else hex).chunked(2).map { it.toInt(16) }
    }

    private fun radius(from: JsonValue?, to: JsonValue?, t: Double): JsonValue? {
        val x = from?.doubleValue
        val y = to?.doubleValue
        if (x != null && y != null) return JsonValue.Double(number(x, y, t))
        val a = cornersOf(from) ?: return null
        val b = cornersOf(to) ?: return null
        return JsonValue.Object(corners.indices.associate { corners[it] to JsonValue.Double(number(a[it], b[it], t)) })
    }

    private fun cornersOf(value: JsonValue?): List<Double>? {
        value?.doubleValue?.let { all -> return corners.map { all } }
        val o = value?.objectValue ?: return null
        return corners.map { part(o, it) }
    }

    /** As the builders read a border: no `width` is 1, no `color` is black, `style: none` is no border. */
    private fun border(from: JsonValue?, to: JsonValue?, t: Double): JsonValue? {
        val a = from?.objectValue?.takeIf { it["style"]?.stringValue != "none" } ?: return null
        val b = to?.objectValue?.takeIf { it["style"]?.stringValue != "none" } ?: return null
        val mixed = b.toMutableMap()
        mixed["width"] = JsonValue.Double(number(a["width"]?.doubleValue ?: 1.0, b["width"]?.doubleValue ?: 1.0, t))
        val black = JsonValue.String("#000000")
        colorValue(a["color"] ?: black, b["color"] ?: black, t)?.let { mixed["color"] = it }
        return JsonValue.Object(mixed)
    }
}
