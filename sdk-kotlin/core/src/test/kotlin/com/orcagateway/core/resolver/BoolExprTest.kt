package com.orcagateway.core.resolver

import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.BoolExpr
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * T1.4: the 13 BoolExpr ops, with the cases of the Dart groups "11.9:
 * BoolExpr evaluation" and "11.7: ConditionalValue resolution" in
 * sdk/test/orca_gateway_test.dart, plus the null semantics Dart's code has.
 */
class BoolExprTest {
    private fun s(v: Any?): JsonValue = obj("type" to "static", "value" to v)
    private fun st(key: String): JsonValue = obj("type" to "state", "key" to key, "scope" to "page")
    private fun cmp(op: String, l: Any?, r: Any?): JsonValue = obj("op" to op, "left" to l, "right" to r)

    private fun eval(expr: JsonValue, state: Map<String, JsonValue> = emptyMap()): Boolean =
        ValueResolver(state = state).evaluate(expr.objectValue ?: emptyMap())

    private fun resolver(vararg state: Pair<String, Any?>, progress: Double? = null): ValueResolver =
        ValueResolver(state = props(*state), animationProgress = progress)

    // MARK: lifted from the Dart group 11.9

    @Test
    fun dartCases() {
        assertTrue(eval(cmp("eq", s(5), s(5))))
        assertFalse(eval(cmp("eq", s(5), s(3))))
        assertTrue(eval(cmp("neq", s(5), s(3))))
        assertFalse(eval(cmp("neq", s(5), s(5))))
        assertTrue(eval(cmp("gt", s(10), s(5))))
        assertFalse(eval(cmp("gt", s(5), s(5))))
        assertTrue(eval(cmp("gte", s(5), s(5))))
        assertTrue(eval(cmp("lt", s(3), s(5))))
        assertTrue(eval(cmp("lte", s(5), s(5))))
        assertTrue(eval(obj("op" to "and", "exprs" to arr(cmp("eq", s(1), s(1)), cmp("gt", s(5), s(3))))))
        assertFalse(eval(obj("op" to "and", "exprs" to arr(cmp("eq", s(1), s(1)), cmp("gt", s(3), s(5))))))
        assertTrue(eval(obj("op" to "or", "exprs" to arr(cmp("eq", s(1), s(2)), cmp("gt", s(5), s(3))))))
        assertTrue(eval(obj("op" to "not", "expr" to cmp("eq", s(1), s(2)))))
        assertTrue(eval(obj("op" to "isNull", "value" to s(null))))
        assertFalse(eval(obj("op" to "isNull", "value" to s(42))))
        assertTrue(eval(obj("op" to "isNull", "value" to st("missing"))))
        assertTrue(eval(obj("op" to "contains", "haystack" to s("hello world"), "needle" to s("world"))))
        assertTrue(eval(obj("op" to "contains", "haystack" to s(arr(1, 2, 3)), "needle" to s(2))))
        assertTrue(eval(obj("op" to "startsWith", "str" to s("hello"), "prefix" to s("hel"))))
        assertTrue(eval(obj("op" to "matches", "str" to s("abc123"), "regex" to "\\d+")))
        assertFalse(eval(obj("op" to "matches", "str" to s("abc"), "regex" to "\\d+")))
        assertTrue(eval(cmp("gt", st("count"), s(3)), props("count" to 5)))
    }

    // MARK: null and type semantics of the Dart code

    @Test
    fun comparisonsWithNonNumbersCompareAsEqual() {
        // `_compareNum` returns 0 unless both sides are numbers.
        assertFalse(eval(cmp("gt", st("missing"), s(1))))
        assertFalse(eval(cmp("lt", st("missing"), s(1))))
        assertTrue(eval(cmp("gte", st("missing"), s(1))))
        assertTrue(eval(cmp("lte", s("b"), s("a"))))
        assertTrue(eval(cmp("gte", s(1), s(1.0))))
        assertTrue(eval(cmp("lt", s(1), s(1.5))))
    }

    @Test
    fun equalityFollowsDartNumbersAndNull() {
        assertTrue(eval(cmp("eq", s(1), s(1.0))))
        assertTrue(eval(cmp("eq", st("missing"), s(null))))
        assertFalse(eval(cmp("eq", s(1), s("1"))))
        assertFalse(eval(cmp("eq", s(true), s(1))))
        assertTrue(eval(cmp("neq", st("missing"), s(0))))
        // Operands may be literals, not only Values.
        assertTrue(eval(cmp("eq", 2, s(2))))
    }

    @Test
    fun logicalEdges() {
        assertTrue(eval(obj("op" to "and", "exprs" to arr())))
        assertFalse(eval(obj("op" to "or", "exprs" to arr())))
        assertTrue(eval(obj("op" to "and"))) // missing exprs reads as []
        assertFalse(eval(obj("op" to "and", "exprs" to arr(cmp("eq", s(1), s(1)), "junk"))))
        assertTrue(eval(obj("op" to "not"))) // no inner expression
        assertFalse(eval(obj("op" to "xor")))
        assertFalse(eval(obj("left" to s(1))))
    }

    @Test
    fun stringOpsStringifyLikeDart() {
        assertTrue(eval(obj("op" to "startsWith", "str" to st("missing"), "prefix" to s("nu")))) // "null"
        assertTrue(eval(obj("op" to "startsWith", "str" to s(123), "prefix" to s(12))))
        assertTrue(eval(obj("op" to "contains", "haystack" to s("a null b"), "needle" to st("missing"))))
        assertFalse(eval(obj("op" to "contains", "haystack" to s(42), "needle" to s(4))))
        assertFalse(eval(obj("op" to "contains", "haystack" to st("missing"), "needle" to s("x"))))
        assertFalse(eval(obj("op" to "matches", "str" to s("x"), "regex" to "("))) // invalid
        assertFalse(eval(obj("op" to "matches", "str" to s("a"), "regex" to "a".repeat(201))))
        assertTrue(eval(obj("op" to "matches", "str" to s(42), "regex" to "^4")))
    }

    @Test
    fun typedExpressionsEvaluateTheSame() {
        val r = resolver("count" to 5)
        assertTrue(r.evaluate(BoolExpr.Gt(obj("type" to "state", "key" to "count", "scope" to "page"), j(3))))
        assertTrue(r.evaluate(BoolExpr.And(listOf(BoolExpr.IsNull(JsonValue.Null), BoolExpr.Not(BoolExpr.Eq(j(1), j(2)))))))
        assertFalse(r.evaluate(BoolExpr.Unknown(obj("op" to "xor"))))
    }

    @Test
    fun everyAdvertisedOpIsHandled() {
        assertEquals(BoolExpr.ops.toSet(), GeneratedCapabilities.boolExprOps.toSet())
        assertEquals(13, BoolExpr.ops.size)
    }

    // MARK: lifted from the Dart group 11.7

    @Test
    fun conditionalValues() {
        val stock = obj(
            "type" to "conditional",
            "branches" to arr(obj("when" to cmp("gt", st("stock"), s(0)), "then" to s("In Stock"))),
            "else" to s("Out of Stock"),
        )
        assertEquals(j("In Stock"), resolver("stock" to 5).resolve(stock))
        assertEquals(j("Out of Stock"), resolver("stock" to 0).resolve(stock))

        val never = obj(
            "type" to "conditional",
            "branches" to arr(obj("when" to cmp("eq", s(1), s(2)), "then" to s("never"))),
        )
        assertEquals(JsonValue.Null, resolver().resolve(never))

        val temp = obj(
            "type" to "conditional",
            "branches" to arr(
                obj("when" to cmp("lt", st("temp"), s(0)), "then" to s("Freezing")),
                obj("when" to cmp("lt", st("temp"), s(20)), "then" to s("Cold")),
            ),
            "else" to s("Warm"),
        )
        assertEquals(j("Freezing"), resolver("temp" to -5).resolve(temp))
        assertEquals(j("Cold"), resolver("temp" to 10).resolve(temp))
        assertEquals(j("Warm"), resolver("temp" to 25).resolve(temp))

        val inner = obj(
            "type" to "conditional",
            "branches" to arr(obj("when" to cmp("eq", st("tier"), s("premium")), "then" to s("Free Shipping"))),
            "else" to s("$9.99 Shipping"),
        )
        val outer = obj(
            "type" to "conditional",
            "branches" to arr(obj("when" to cmp("gt", st("total"), s(100)), "then" to s("Free Shipping"))),
            "else" to inner,
        )
        assertEquals(j("Free Shipping"), resolver("total" to 150, "tier" to "basic").resolve(outer))
        assertEquals(j("Free Shipping"), resolver("total" to 50, "tier" to "premium").resolve(outer))
        assertEquals(j("$9.99 Shipping"), resolver("total" to 50, "tier" to "basic").resolve(outer))
    }

    // MARK: other Value kinds and the resolver's pass-through rules

    @Test
    fun valueKinds() {
        val r = ValueResolver(
            state = props("count" to 10, "theme" to obj("color" to "red"), "items" to arr(obj("name" to "a")), "a.b" to "flat"),
            eventData = props("value" to "typed"),
        )
        assertEquals(j(42), r.resolve(s(42)))
        assertEquals(JsonValue.Null, r.resolve(obj("type" to "static")))
        assertEquals(j(10), r.resolve(st("count")))
        assertEquals(j("red"), r.resolve(st("theme.color")))
        assertEquals(j("a"), r.resolve(st("items.0.name")))
        assertEquals(JsonValue.Null, r.resolve(st("items.3.name")))
        assertEquals(j("flat"), r.resolve(st("a.b"))) // flat key wins
        assertEquals(JsonValue.Null, r.resolve(obj("type" to "state")))
        assertEquals(j("typed"), r.resolve(obj("type" to "event", "key" to "value")))
        assertEquals(JsonValue.Null, ValueResolver(state = emptyMap()).resolve(obj("type" to "event", "key" to "value")))
        // info and request are resolved by the engine; the client leaves them.
        val info = obj("type" to "info", "key" to "user.name")
        assertEquals(info, r.resolve(info))
        assertEquals(obj("type" to "request", "key" to "q"), r.resolve(obj("type" to "request", "key" to "q")))
        // Literals and plain maps pass through `resolve`.
        assertEquals(j("hello"), r.resolve(j("hello")))
        assertEquals(JsonValue.Null, r.resolve(JsonValue.Null))
        assertEquals(obj("padding" to 8), r.resolve(obj("padding" to 8)))
        assertEquals("", r.resolveToString(st("missing")))
        assertEquals("10", r.resolveToString(st("count")))
        // resolveDeep descends into plain maps and lists.
        assertEquals(
            obj("style" to obj("color" to "red", "sizes" to arr(1, 2))),
            r.resolveDeep(obj("style" to obj("color" to st("theme.color"), "sizes" to arr(s(1), 2)))),
        )
    }

    @Test
    fun tweens() {
        val tween = obj("type" to "tween", "begin" to 0, "end" to 10)
        assertEquals(JsonValue.Double(0.0), resolver().resolve(tween))
        assertEquals(j(2.5), resolver(progress = 0.25).resolve(tween))
        val color = obj("type" to "tween", "begin" to "#000000", "end" to "#FFFFFF")
        assertEquals(j("#FF808080"), resolver(progress = 0.5).resolve(color))
        val alpha = obj("type" to "tween", "begin" to "#00000000", "end" to "#FF000000")
        assertEquals(j("#FF000000"), resolver(progress = 1.0).resolve(alpha))
        val snap = obj("type" to "tween", "begin" to "left", "end" to "right")
        assertEquals(j("left"), resolver(progress = 0.49).resolve(snap))
        assertEquals(j("right"), resolver(progress = 0.5).resolve(snap))
        val targeted = obj("type" to "tween", "begin" to 0, "end" to 100, "animationId" to "fade")
        val r = ValueResolver(
            state = emptyMap(), animationProgress = 0.9,
            animationProgressFor = { if (it == "fade") 0.1 else null },
        )
        assertEquals(j(10), r.resolve(targeted))

        val seq = obj(
            "type" to "tweenSequence",
            "items" to arr(
                obj("value" to 0, "duration" to 100),
                obj("value" to 10, "duration" to 100),
                obj("value" to 0, "duration" to 200),
            ),
        )
        assertEquals(j(0), resolver(progress = 0.25).resolve(seq))
        assertEquals(j(5), resolver(progress = 0.375).resolve(seq))
        assertEquals(j(5), resolver(progress = 0.75).resolve(seq))
        assertEquals(JsonValue.Null, resolver().resolve(obj("type" to "tweenSequence", "items" to arr())))
        assertEquals(
            j(7),
            resolver().resolve(obj("type" to "tweenSequence", "items" to arr(obj("value" to 7, "duration" to 0)))),
        )
    }
}
