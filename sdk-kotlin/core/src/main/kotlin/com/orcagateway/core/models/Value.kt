package com.orcagateway.core.models

import com.orcagateway.core.json.JsonValue
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException

/**
 * A typed wire `Value` (schema/value.schema.json, engine/src/types/value.ts).
 *
 * Props on a [ComponentNode] stay [JsonValue], because a prop may be a plain
 * literal, a nested map, or a Value anywhere inside it; the resolver works on
 * that JSON directly, as the Dart SDK does. This typed form is for code that
 * knows a field holds a Value and for round-trip tests.
 */
@Serializable(with = ValueSerializer::class)
public sealed class Value {
    public data class Static(public val value: JsonValue) : Value()

    public data class State(public val key: String, public val scope: StateScope) : Value()

    public data class Info(public val key: String) : Value()

    public data class Request(public val key: String) : Value()

    public data class Event(public val key: String) : Value()

    public data class Transform(
        public val input: Value,
        public val by: List<com.orcagateway.core.models.Transform>,
    ) : Value()

    /** `elseValue` is the wire's `else`. */
    public data class Conditional(
        public val branches: List<ConditionalBranch>,
        public val elseValue: Value? = null,
    ) : Value()

    public data class Tween(
        public val begin: JsonValue,
        public val end: JsonValue,
        public val animationId: String? = null,
    ) : Value()

    public data class TweenSequence(
        public val items: List<TweenSequenceItem>,
        public val animationId: String? = null,
    ) : Value()

    public val kind: String
        get() = when (this) {
            is Static -> "static"
            is State -> "state"
            is Info -> "info"
            is Request -> "request"
            is Event -> "event"
            is Transform -> "transform"
            is Conditional -> "conditional"
            is Tween -> "tween"
            is TweenSequence -> "tweenSequence"
        }

    /** This Value as wire JSON ([JsonValue.Null] if it cannot be encoded). */
    public val json: JsonValue get() = bridge(ValueSerializer, this)

    public companion object {
        /** The nine `type` discriminators, in schema order. */
        public val kinds: List<String> = listOf(
            "static", "state", "info", "request", "event",
            "transform", "conditional", "tween", "tweenSequence",
        )
    }
}

public enum class StateScope(public val wire: String) {
    Page("page"),
    App("app"),
    ;

    public companion object {
        public fun fromWire(wire: String): StateScope? = entries.firstOrNull { it.wire == wire }
    }
}

/** One branch of a `conditional` Value; `condition` is the wire's `when`. */
@Serializable(with = ConditionalBranchSerializer::class)
public data class ConditionalBranch(public val condition: BoolExpr, public val then: Value)

@Serializable(with = TweenSequenceItemSerializer::class)
public data class TweenSequenceItem(public val value: JsonValue, public val duration: Double)

// MARK: - Transform

/**
 * One step of a `transform` Value's `by` pipeline. The 31 kinds of the engine
 * (value.ts) plus `toggle`, which the Dart SDK also registers. A kind this
 * build does not know decodes to [Unknown] and the resolver skips it, as the
 * Dart registry does. Wire integers are Long (Swift's Int is 64-bit).
 */
@Serializable(with = TransformSerializer::class)
public sealed class Transform {
    // String
    public data object ToString : Transform()
    public data object ToUpperCase : Transform()
    public data object ToLowerCase : Transform()
    public data object Trim : Transform()
    public data class Template(
        public val template: String,
        public val params: kotlin.collections.Map<String, JsonValue>? = null,
    ) : Transform()
    public data class Regex(
        public val pattern: String,
        public val flags: String? = null,
        public val replacement: String? = null,
        public val params: kotlin.collections.Map<String, JsonValue>? = null,
    ) : Transform()
    public data class Substring(public val start: Long, public val length: Long? = null) : Transform()
    public data class Split(public val separator: String) : Transform()
    public data class Join(public val separator: String) : Transform()

    // Number
    public data class Multiply(public val by: JsonValue) : Transform()
    public data class Divide(public val by: JsonValue) : Transform()
    public data class Add(public val by: JsonValue) : Transform()
    public data class Subtract(public val by: JsonValue) : Transform()
    public data class Modulo(public val by: JsonValue) : Transform()
    public data object Round : Transform()
    public data object Floor : Transform()
    public data object Ceil : Transform()
    public data object Abs : Transform()
    public data class ToFixed(public val decimals: Long? = null) : Transform()

    // Boolean
    public data object Not : Transform()
    public data object ToBool : Transform()
    public data object Toggle : Transform()

    // Collection
    public data object Length : Transform()
    public data class At(public val index: Long) : Transform()
    public data object First : Transform()
    public data object Last : Transform()
    public data class Map(public val transform: Transform) : Transform()
    public data class Filter(public val expr: BoolExpr) : Transform()
    public data class Contains(public val value: JsonValue) : Transform()

    // Format
    public data class FormatCurrency(public val currency: String? = null, public val decimals: Long? = null) : Transform()
    public data class FormatDate(public val format: String) : Transform()
    public data class FormatNumber(public val decimals: Long? = null, public val useGrouping: Boolean? = null) : Transform()

    /** A kind this build does not implement, kept verbatim. */
    public data class Unknown(public val raw: JsonValue) : Transform()

    public val kind: String
        get() = when (this) {
            ToString -> "toString"
            ToUpperCase -> "toUpperCase"
            ToLowerCase -> "toLowerCase"
            Trim -> "trim"
            is Template -> "template"
            is Regex -> "regex"
            is Substring -> "substring"
            is Split -> "split"
            is Join -> "join"
            is Multiply -> "multiply"
            is Divide -> "divide"
            is Add -> "add"
            is Subtract -> "subtract"
            is Modulo -> "modulo"
            Round -> "round"
            Floor -> "floor"
            Ceil -> "ceil"
            Abs -> "abs"
            is ToFixed -> "toFixed"
            Not -> "not"
            ToBool -> "toBool"
            Toggle -> "toggle"
            Length -> "length"
            is At -> "at"
            First -> "first"
            Last -> "last"
            is Map -> "map"
            is Filter -> "filter"
            is Contains -> "contains"
            is FormatCurrency -> "formatCurrency"
            is FormatDate -> "formatDate"
            is FormatNumber -> "formatNumber"
            is Unknown -> raw["type"].stringValue ?: ""
        }

    public val json: JsonValue get() = bridge(TransformSerializer, this)
}

// MARK: - BoolExpr

/**
 * A boolean expression used by `conditional` Values, `filter` transforms and
 * `conditionalAction`. Operands are [JsonValue] because the wire allows a
 * Value or a literal in each slot.
 */
@Serializable(with = BoolExprSerializer::class)
public sealed class BoolExpr {
    public data class Eq(public val left: JsonValue, public val right: JsonValue) : BoolExpr()
    public data class Neq(public val left: JsonValue, public val right: JsonValue) : BoolExpr()
    public data class Gt(public val left: JsonValue, public val right: JsonValue) : BoolExpr()
    public data class Gte(public val left: JsonValue, public val right: JsonValue) : BoolExpr()
    public data class Lt(public val left: JsonValue, public val right: JsonValue) : BoolExpr()
    public data class Lte(public val left: JsonValue, public val right: JsonValue) : BoolExpr()
    public data class And(public val exprs: List<BoolExpr>) : BoolExpr()
    public data class Or(public val exprs: List<BoolExpr>) : BoolExpr()
    public data class Not(public val expr: BoolExpr) : BoolExpr()
    public data class IsNull(public val value: JsonValue) : BoolExpr()
    public data class Contains(public val haystack: JsonValue, public val needle: JsonValue) : BoolExpr()
    public data class StartsWith(public val str: JsonValue, public val prefix: JsonValue) : BoolExpr()
    public data class Matches(public val str: JsonValue, public val regex: String) : BoolExpr()

    /** An op this build does not know; evaluates to false, as in Dart. */
    public data class Unknown(public val raw: JsonValue) : BoolExpr()

    public val op: String
        get() = when (this) {
            is Eq -> "eq"
            is Neq -> "neq"
            is Gt -> "gt"
            is Gte -> "gte"
            is Lt -> "lt"
            is Lte -> "lte"
            is And -> "and"
            is Or -> "or"
            is Not -> "not"
            is IsNull -> "isNull"
            is Contains -> "contains"
            is StartsWith -> "startsWith"
            is Matches -> "matches"
            is Unknown -> raw["op"].stringValue ?: ""
        }

    public val json: JsonValue get() = bridge(BoolExprSerializer, this)

    public companion object {
        /** The 13 `op` discriminators. */
        public val ops: List<String> = listOf(
            "eq", "neq", "gt", "gte", "lt", "lte", "and", "or", "not",
            "isNull", "contains", "startsWith", "matches",
        )
    }
}

/**
 * Swift's `(try? JSONValue(encoding: self)) ?? .null`: the model written out
 * and read back, or Null when it holds a number JSON cannot carry.
 */
internal fun <T> bridge(serializer: JsonTreeSerializer<T>, value: T): JsonValue = try {
    JsonValue.encoding(serializer, value)
} catch (_: SerializationException) {
    JsonValue.Null
}

// MARK: - Serializers

internal fun scopeFromTree(tree: JsonValue): StateScope {
    val wire = tree.stringValue ?: throw SerializationException("StateScope: expected a string, got $tree")
    return StateScope.fromWire(wire) ?: throw SerializationException("Cannot initialize StateScope from invalid value $wire")
}

internal object ValueSerializer : JsonTreeSerializer<Value>("com.orcagateway.core.models.Value") {
    override fun fromTree(tree: JsonValue): Value {
        val f = Fields.of(tree, "Value")
        return when (val type = f.string("type")) {
            "static" -> Value.Static(f.jsonOrNull("value") ?: JsonValue.Null)
            "state" -> Value.State(f.string("key"), f.decodeOrNull("scope", ::scopeFromTree) ?: StateScope.Page)
            "info" -> Value.Info(f.string("key"))
            "request" -> Value.Request(f.string("key"))
            "event" -> Value.Event(f.string("key"))
            "transform" -> Value.Transform(f.decode("input", ::fromTree), f.list("by", TransformSerializer::fromTree))
            "conditional" -> Value.Conditional(
                f.list("branches", ConditionalBranchSerializer::fromTree),
                f.decodeOrNull("else", ::fromTree),
            )
            "tween" -> Value.Tween(
                f.jsonOrNull("begin") ?: JsonValue.Null,
                f.jsonOrNull("end") ?: JsonValue.Null,
                f.stringOrNull("animationId"),
            )
            "tweenSequence" -> Value.TweenSequence(
                f.list("items", TweenSequenceItemSerializer::fromTree),
                f.stringOrNull("animationId"),
            )
            else -> throw SerializationException("Unknown Value type '$type'")
        }
    }

    override fun toTree(value: Value): JsonValue = tree {
        put("type", value.kind)
        when (value) {
            is Value.Static -> put("value", value.value)
            is Value.State -> {
                put("key", value.key)
                put("scope", value.scope.wire)
            }
            is Value.Info -> put("key", value.key)
            is Value.Request -> put("key", value.key)
            is Value.Event -> put("key", value.key)
            is Value.Transform -> {
                put("input", toTree(value.input))
                put("by", JsonValue.Array(value.by.map(TransformSerializer::toTree)))
            }
            is Value.Conditional -> {
                put("branches", JsonValue.Array(value.branches.map(ConditionalBranchSerializer::toTree)))
                putIfPresent("else", value.elseValue?.let(::toTree))
            }
            is Value.Tween -> {
                put("begin", value.begin)
                put("end", value.end)
                putIfPresent("animationId", value.animationId)
            }
            is Value.TweenSequence -> {
                put("items", JsonValue.Array(value.items.map(TweenSequenceItemSerializer::toTree)))
                putIfPresent("animationId", value.animationId)
            }
        }
    }
}

internal object ConditionalBranchSerializer :
    JsonTreeSerializer<ConditionalBranch>("com.orcagateway.core.models.ConditionalBranch") {
    override fun fromTree(tree: JsonValue): ConditionalBranch {
        val f = Fields.of(tree, "ConditionalBranch")
        return ConditionalBranch(f.decode("when", BoolExprSerializer::fromTree), f.decode("then", ValueSerializer::fromTree))
    }

    override fun toTree(value: ConditionalBranch): JsonValue = tree {
        put("when", BoolExprSerializer.toTree(value.condition))
        put("then", ValueSerializer.toTree(value.then))
    }
}

internal object TweenSequenceItemSerializer :
    JsonTreeSerializer<TweenSequenceItem>("com.orcagateway.core.models.TweenSequenceItem") {
    override fun fromTree(tree: JsonValue): TweenSequenceItem {
        val f = Fields.of(tree, "TweenSequenceItem")
        return TweenSequenceItem(f.json("value"), f.double("duration"))
    }

    override fun toTree(value: TweenSequenceItem): JsonValue = tree {
        put("value", value.value)
        put("duration", JsonValue.Double(value.duration))
    }
}

internal object TransformSerializer : JsonTreeSerializer<Transform>("com.orcagateway.core.models.Transform") {
    override fun fromTree(tree: JsonValue): Transform {
        val f = Fields.of(tree, "Transform")
        fun by(): JsonValue = f.jsonOrNull("by") ?: JsonValue.Null
        return when (f.string("type")) {
            "toString" -> Transform.ToString
            "toUpperCase" -> Transform.ToUpperCase
            "toLowerCase" -> Transform.ToLowerCase
            "trim" -> Transform.Trim
            "template" -> Transform.Template(f.stringOrNull("template") ?: "", f.objOrNull("params"))
            "regex" -> Transform.Regex(
                f.stringOrNull("pattern") ?: "",
                f.stringOrNull("flags"),
                f.stringOrNull("replacement"),
                f.objOrNull("params"),
            )
            "substring" -> Transform.Substring(f.longOrNull("start") ?: 0, f.longOrNull("length"))
            "split" -> Transform.Split(f.stringOrNull("separator") ?: "")
            "join" -> Transform.Join(f.stringOrNull("separator") ?: "")
            "multiply" -> Transform.Multiply(by())
            "divide" -> Transform.Divide(by())
            "add" -> Transform.Add(by())
            "subtract" -> Transform.Subtract(by())
            "modulo" -> Transform.Modulo(by())
            "round" -> Transform.Round
            "floor" -> Transform.Floor
            "ceil" -> Transform.Ceil
            "abs" -> Transform.Abs
            "toFixed" -> Transform.ToFixed(f.longOrNull("decimals"))
            "not" -> Transform.Not
            "toBool" -> Transform.ToBool
            "toggle" -> Transform.Toggle
            "length" -> Transform.Length
            "at" -> Transform.At(f.longOrNull("index") ?: 0)
            "first" -> Transform.First
            "last" -> Transform.Last
            "map" -> Transform.Map(f.decode("transform", ::fromTree))
            "filter" -> Transform.Filter(f.decode("expr", BoolExprSerializer::fromTree))
            "contains" -> Transform.Contains(f.jsonOrNull("value") ?: JsonValue.Null)
            "formatCurrency" -> Transform.FormatCurrency(f.stringOrNull("currency"), f.longOrNull("decimals"))
            "formatDate" -> Transform.FormatDate(f.stringOrNull("format") ?: "")
            "formatNumber" -> Transform.FormatNumber(f.longOrNull("decimals"), f.boolOrNull("useGrouping"))
            else -> Transform.Unknown(tree)
        }
    }

    override fun toTree(value: Transform): JsonValue {
        if (value is Transform.Unknown) return value.raw
        return tree {
            put("type", value.kind)
            when (value) {
                is Transform.Template -> {
                    put("template", value.template)
                    putIfPresent("params", value.params)
                }
                is Transform.Regex -> {
                    put("pattern", value.pattern)
                    putIfPresent("flags", value.flags)
                    putIfPresent("replacement", value.replacement)
                    putIfPresent("params", value.params)
                }
                is Transform.Substring -> {
                    put("start", value.start)
                    putIfPresent("length", value.length)
                }
                is Transform.Split -> put("separator", value.separator)
                is Transform.Join -> put("separator", value.separator)
                is Transform.Multiply -> put("by", value.by)
                is Transform.Divide -> put("by", value.by)
                is Transform.Add -> put("by", value.by)
                is Transform.Subtract -> put("by", value.by)
                is Transform.Modulo -> put("by", value.by)
                is Transform.ToFixed -> putIfPresent("decimals", value.decimals)
                is Transform.At -> put("index", value.index)
                is Transform.Map -> put("transform", toTree(value.transform))
                is Transform.Filter -> put("expr", BoolExprSerializer.toTree(value.expr))
                is Transform.Contains -> put("value", value.value)
                is Transform.FormatCurrency -> {
                    putIfPresent("currency", value.currency)
                    putIfPresent("decimals", value.decimals)
                }
                is Transform.FormatDate -> put("format", value.format)
                is Transform.FormatNumber -> {
                    putIfPresent("decimals", value.decimals)
                    putIfPresent("useGrouping", value.useGrouping)
                }
                else -> Unit
            }
        }
    }
}

internal object BoolExprSerializer : JsonTreeSerializer<BoolExpr>("com.orcagateway.core.models.BoolExpr") {
    override fun fromTree(tree: JsonValue): BoolExpr {
        val f = Fields.of(tree, "BoolExpr")
        fun operand(key: String): JsonValue = f.jsonOrNull(key) ?: JsonValue.Null
        return when (f.string("op")) {
            "eq" -> BoolExpr.Eq(operand("left"), operand("right"))
            "neq" -> BoolExpr.Neq(operand("left"), operand("right"))
            "gt" -> BoolExpr.Gt(operand("left"), operand("right"))
            "gte" -> BoolExpr.Gte(operand("left"), operand("right"))
            "lt" -> BoolExpr.Lt(operand("left"), operand("right"))
            "lte" -> BoolExpr.Lte(operand("left"), operand("right"))
            "and" -> BoolExpr.And(f.listOrNull("exprs", ::fromTree) ?: emptyList())
            "or" -> BoolExpr.Or(f.listOrNull("exprs", ::fromTree) ?: emptyList())
            "not" -> BoolExpr.Not(f.decode("expr", ::fromTree))
            "isNull" -> BoolExpr.IsNull(operand("value"))
            "contains" -> BoolExpr.Contains(operand("haystack"), operand("needle"))
            "startsWith" -> BoolExpr.StartsWith(operand("str"), operand("prefix"))
            "matches" -> BoolExpr.Matches(operand("str"), f.stringOrNull("regex") ?: "")
            else -> BoolExpr.Unknown(tree)
        }
    }

    override fun toTree(value: BoolExpr): JsonValue {
        if (value is BoolExpr.Unknown) return value.raw
        return tree {
            put("op", value.op)
            when (value) {
                is BoolExpr.Eq -> comparison(value.left, value.right)
                is BoolExpr.Neq -> comparison(value.left, value.right)
                is BoolExpr.Gt -> comparison(value.left, value.right)
                is BoolExpr.Gte -> comparison(value.left, value.right)
                is BoolExpr.Lt -> comparison(value.left, value.right)
                is BoolExpr.Lte -> comparison(value.left, value.right)
                is BoolExpr.And -> put("exprs", JsonValue.Array(value.exprs.map(::toTree)))
                is BoolExpr.Or -> put("exprs", JsonValue.Array(value.exprs.map(::toTree)))
                is BoolExpr.Not -> put("expr", toTree(value.expr))
                is BoolExpr.IsNull -> put("value", value.value)
                is BoolExpr.Contains -> {
                    put("haystack", value.haystack)
                    put("needle", value.needle)
                }
                is BoolExpr.StartsWith -> {
                    put("str", value.str)
                    put("prefix", value.prefix)
                }
                is BoolExpr.Matches -> {
                    put("str", value.str)
                    put("regex", value.regex)
                }
                is BoolExpr.Unknown -> Unit
            }
        }
    }

    private fun TreeBuilder.comparison(left: JsonValue, right: JsonValue) {
        put("left", left)
        put("right", right)
    }
}
