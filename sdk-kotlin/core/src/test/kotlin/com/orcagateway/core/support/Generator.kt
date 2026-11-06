package com.orcagateway.core.support

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ActionList
import com.orcagateway.core.models.BoolExpr
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.ConditionalBranch
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.models.Transform
import com.orcagateway.core.models.TweenSequenceItem
import com.orcagateway.core.models.Value

/**
 * A seeded random generator for the property tests. SplitMix64: tiny,
 * deterministic on every platform, so a failing seed reproduces anywhere.
 * No shrinking; a failure prints its seed and iteration instead.
 */
class Gen(seed: Long) {
    private var state: Long = seed

    fun next(): Long {
        state += -0x61c8864680b583ebL // 0x9E3779B97F4A7C15
        var z = state
        z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L // 0xBF58476D1CE4E5B9
        z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L // 0x94D049BB133111EB
        return z xor (z ushr 31)
    }

    /** Uniform in [range], by rejection (no modulo bias). */
    fun long(range: LongRange): Long {
        val span = range.last - range.first + 1
        val limit = Long.MAX_VALUE - (Long.MAX_VALUE % span)
        while (true) {
            val r = next() ushr 1
            if (r < limit) return range.first + r % span
        }
    }

    fun int(range: IntRange): Int = long(range.first.toLong()..range.last.toLong()).toInt()

    fun bool(): Boolean = next() < 0

    fun <T> pick(items: List<T>): T = items[int(0..items.size - 1)]

    fun <T> maybe(make: (Gen) -> T): T? = if (bool()) make(this) else null

    private fun unit(): Double = (next() ushr 11) * (1.0 / (1L shl 53))

    private fun uniform(lo: Double, hi: Double): Double = lo + (hi - lo) * unit()

    fun string(maxLength: Int = 8): String {
        val alphabet = listOf(
            "a", "b", "c", "X", "Y", "Z", "0", "1", "9", " ", "_", "-", ".", ",", "é", "漢", "🙂", "\"", "\\", "/", "\n",
        )
        return (0 until int(0..maxLength)).joinToString("") { pick(alphabet) }
    }

    fun key(): String = (0 until int(1..6)).joinToString("") { pick("abcdefghij".map { c -> c.toString() }) }

    /** A finite double that survives a JSON round trip. */
    fun double(): Double = when (int(0..3)) {
        0 -> int(-1000..1000).toDouble() / 8
        1 -> int(-1_000_000..1_000_000).toDouble() * 1e-3
        2 -> uniform(-1e12, 1e12)
        else -> uniform(-1.0, 1.0)
    }

    // MARK: JSON

    fun json(depth: Int = 3): JsonValue {
        val leafOnly = depth <= 0
        return when (int(0..(if (leafOnly) 4 else 6))) {
            0 -> JsonValue.Null
            1 -> JsonValue.Bool(bool())
            2 -> JsonValue.Int(long(Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong()))
            3 -> JsonValue.Double(double())
            4 -> JsonValue.String(string())
            5 -> JsonValue.Array((0 until int(0..3)).map { json(depth - 1) })
            else -> {
                val o = LinkedHashMap<String, JsonValue>()
                repeat(int(0..3)) { o[key()] = json(depth - 1) }
                JsonValue.Object(o)
            }
        }
    }

    // MARK: Values

    fun value(depth: Int = 2): Value {
        val n = if (depth <= 0) int(0..4) else int(0..8)
        return when (n) {
            0 -> Value.Static(json(1))
            1 -> Value.State(key() + (if (bool()) ".x" else ""), pick(StateScope.entries))
            2 -> Value.Info(key())
            3 -> Value.Request(key())
            4 -> Value.Event(key())
            5 -> Value.Transform(value(depth - 1), (0 until int(0..3)).map { transform(depth - 1) })
            6 -> Value.Conditional(
                (0 until int(1..2)).map { ConditionalBranch(boolExpr(depth - 1), value(depth - 1)) },
                maybe { it.value(depth - 1) },
            )
            7 -> Value.Tween(JsonValue.Int(int(0..10).toLong()), JsonValue.String("#FF0000"), maybe { it.key() })
            else -> Value.TweenSequence(
                (0 until int(1..3)).map { TweenSequenceItem(JsonValue.Int(int(0..5).toLong()), int(0..600).toDouble()) },
                maybe { it.key() },
            )
        }
    }

    fun operand(depth: Int): JsonValue = if (bool()) json(1) else value(depth).json

    /**
     * For optional fields: an explicit JSON null decodes as absent (as a
     * Dart `action['x']` read does), so optional fields never hold Null.
     */
    fun someOperand(depth: Int): JsonValue {
        val v = operand(depth)
        return if (v.isNull) JsonValue.String("n") else v
    }

    fun someJson(depth: Int): JsonValue {
        val v = json(depth)
        return if (v.isNull) JsonValue.Int(0) else v
    }

    fun transform(depth: Int = 1): Transform = when (int(0..32)) {
        0 -> Transform.ToString
        1 -> Transform.ToUpperCase
        2 -> Transform.ToLowerCase
        3 -> Transform.Trim
        4 -> Transform.Template("{{value}} " + string(), maybe { g -> mapOf(g.key() to g.value(0).json) })
        5 -> Transform.Regex("a+", maybe { it.pick(listOf("g", "gi", "m")) }, maybe { it.string() }, null)
        6 -> Transform.Substring(int(0..3).toLong(), maybe { it.int(0..3).toLong() })
        7 -> Transform.Split(pick(listOf(",", "", " ")))
        8 -> Transform.Join(pick(listOf(",", "")))
        9 -> Transform.Multiply(operand(depth))
        10 -> Transform.Divide(operand(depth))
        11 -> Transform.Add(operand(depth))
        12 -> Transform.Subtract(operand(depth))
        13 -> Transform.Modulo(operand(depth))
        14 -> Transform.Round
        15 -> Transform.Floor
        16 -> Transform.Ceil
        17 -> Transform.Abs
        18 -> Transform.ToFixed(maybe { it.int(0..4).toLong() })
        19 -> Transform.Not
        20 -> Transform.ToBool
        21 -> Transform.Toggle
        22 -> Transform.Length
        23 -> Transform.At(int(0..3).toLong())
        24 -> Transform.First
        25 -> Transform.Last
        26 -> Transform.Map(if (depth > 0) transform(depth - 1) else Transform.ToString)
        27 -> Transform.Filter(boolExpr(depth - 1))
        28 -> Transform.Contains(operand(depth))
        29 -> Transform.FormatCurrency(maybe { it.pick(listOf("USD", "EUR", "SEK")) }, maybe { it.int(0..3).toLong() })
        30 -> Transform.FormatDate("yyyy-MM-dd")
        31 -> Transform.FormatNumber(maybe { it.int(0..3).toLong() }, maybe { it.bool() })
        else -> Transform.Unknown(obj("type" to "sparkle", "level" to int(0..9)))
    }

    fun boolExpr(depth: Int = 1): BoolExpr {
        val leaf = depth <= 0
        return when (int(0..(if (leaf) 10 else 13))) {
            0 -> BoolExpr.Eq(operand(0), operand(0))
            1 -> BoolExpr.Neq(operand(0), operand(0))
            2 -> BoolExpr.Gt(operand(0), operand(0))
            3 -> BoolExpr.Gte(operand(0), operand(0))
            4 -> BoolExpr.Lt(operand(0), operand(0))
            5 -> BoolExpr.Lte(operand(0), operand(0))
            6 -> BoolExpr.IsNull(operand(0))
            7 -> BoolExpr.Contains(operand(0), operand(0))
            8 -> BoolExpr.StartsWith(operand(0), operand(0))
            9 -> BoolExpr.Matches(operand(0), "^[a-z]+$")
            10 -> BoolExpr.Unknown(obj("op" to "xor", "a" to 1))
            11 -> BoolExpr.And((0 until int(0..2)).map { boolExpr(depth - 1) })
            12 -> BoolExpr.Or((0 until int(0..2)).map { boolExpr(depth - 1) })
            else -> BoolExpr.Not(boolExpr(depth - 1))
        }
    }

    // MARK: Actions and nodes

    fun action(depth: Int = 2): Action {
        val leaf = depth <= 0
        return when (int(0..(if (leaf) 22 else 28))) {
            0 -> Action.Navigate(
                route = someOperand(0),
                params = maybe { g -> mapOf(g.key() to g.value(0).json) },
                replace = maybe { it.bool() },
            )
            1 -> Action.GoBack
            2 -> Action.SwitchTab(key())
            3 -> Action.OpenDrawer
            4 -> Action.OpenDialog(key(), maybe { it.double() })
            5 -> Action.CloseDialog
            6 -> Action.SetState(key(), maybe { it.pick(StateScope.entries) }, operand(1))
            7 -> Action.ClearState(key(), maybe { it.pick(StateScope.entries) })
            8 -> Action.PersistState(key(), StateScope.App, maybe { it.pick(listOf("local", "session")) })
            9 -> Action.ServerAction(key(), maybe { g -> mapOf(g.key() to g.operand(0)) })
            10 -> Action.ShowSnackbar(someOperand(0), maybe { it.int(0..9000).toLong() }, maybe { it.string() })
            11 -> Action.ShowToast(someOperand(0), maybe { it.int(0..9000).toLong() })
            12 -> Action.UpdateComponent(key(), mapOf(key() to json(1)))
            13 -> Action.DeleteComponent(key())
            14 -> Action.AddComponent(key(), node = someJson(2), position = maybe { it.int(0..5).toLong() })
            15 -> Action.CopyToClipboard(someOperand(0))
            16 -> Action.Share(title = JsonValue.String(string()), message = someOperand(0), url = maybe { it.someJson(0) })
            17 -> Action.OpenUrl(someOperand(0))
            18 -> Action.AnimateForward(key())
            19 -> Action.AnimateReverse(key())
            20 -> Action.RefetchPage
            21 -> Action.UpdateSubPage(JsonValue.String(key()), operand(0), mode = maybe { JsonValue.String("join") })
            22 -> Action.DebugLog(
                level = maybe { it.pick(listOf("debug", "info")) },
                message = maybe { it.someOperand(0) },
                includeState = maybe { it.bool() },
            )
            23 -> Action.ActionGroup(
                maybe { it.pick(listOf("sequential", "parallel")) },
                (0 until int(0..3)).map { action(depth - 1) },
            )
            24 -> Action.ConditionalAction(
                (0 until int(1..2)).map { Action.ConditionalAction.Branch(boolExpr(1), action(depth - 1)) },
                maybe { it.action(depth - 1) },
            )
            25 -> Action.Lifecycle(
                action = action(depth - 1),
                onLoading = maybe { ActionList.Single(it.action(depth - 1)) },
                onSuccess = maybe { g -> ActionList.Many((0 until g.int(0..2)).map { g.action(depth - 1) }) },
                onError = null,
                onComplete = maybe { ActionList.Single(it.action(depth - 1)) },
            )
            26 -> Action.Once(action(depth - 1))
            27 -> Action.Always(action(depth - 1))
            else -> Action.Custom(JsonValue.Object(linkedMapOf("type" to JsonValue.String("custom:" + key()), key() to json(1))))
        }
    }

    /** Props mix plain JSON and Value objects at any depth, as on the wire. */
    fun props(depth: Int = 2): Map<String, JsonValue> {
        val o = LinkedHashMap<String, JsonValue>()
        repeat(int(0..4)) {
            if (depth > 0 && int(0..3) == 0) {
                o[key()] = JsonValue.Object(props(depth - 1))
            } else {
                o[key()] = if (bool()) json(1) else value().json
            }
        }
        return o
    }

    fun node(): ComponentNode = ComponentNode(
        id = key(),
        type = pick(listOf("Text", "Column", "Row", "Scaffold", "MiniMap")),
        kind = pick(ComponentNode.Kind.entries),
        childMode = pick(ComponentNode.ChildMode.entries),
        props = props(),
        children = (0 until int(0..3)).map { key() },
        watches = (0 until int(0..3)).map { key() },
        actions = maybe { g -> mapOf("onTap" to g.action(), "onLongPress" to g.action(0)) },
    )
}
