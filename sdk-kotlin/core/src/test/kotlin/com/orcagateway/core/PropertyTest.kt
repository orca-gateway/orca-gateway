package com.orcagateway.core

import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.models.Value
import com.orcagateway.core.resolver.ValueResolver
import com.orcagateway.core.support.Gen
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.decodeModel
import com.orcagateway.core.support.j
import com.orcagateway.core.support.jsonOf
import com.orcagateway.core.support.obj
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

/**
 * Properties over seeded random inputs (learning/property-based-testing.md).
 * Seeds are fixed so CI is deterministic; bump [iterations] locally to hunt.
 */
class PropertyTest {
    private val seeds: List<Long> = listOf(1, 23, 2026, 0xC0FFEE)
    private val iterations = 150

    private fun forAll(body: (Gen, String) -> Unit) {
        for (seed in seeds) {
            val gen = Gen(seed)
            for (i in 0 until iterations) body(gen, "seed $seed #$i")
        }
    }

    // T1.1 property: decode(encode(n)) == n

    @Test
    fun componentNodeRoundTrip() = forAll { gen, label ->
        val node = gen.node()
        val back = decodeModel<ComponentNode>(jsonOf(node))
        assertEquals(node, back, label)
    }

    @Test
    fun pageResponseRoundTrip() = forAll { gen, label ->
        val page = PageResponse(
            pageId = gen.key(),
            title = gen.string(),
            state = (0 until gen.int(0..3)).map {
                StateDefinition(gen.key(), gen.pick(StateScope.entries), gen.json(2))
            },
            components = (0 until gen.int(0..3)).map { gen.node() },
            extra = if (gen.bool()) mapOf("_debug" to gen.json(2)) else emptyMap(),
        )
        assertEquals(page, decodeModel<PageResponse>(jsonOf(page)), label)
    }

    @Test
    fun valueRoundTrip() = forAll { gen, label ->
        val value = gen.value(3)
        assertEquals(value, decodeModel<Value>(value.json), label)
    }

    @Test
    fun actionRoundTrip() = forAll { gen, label ->
        val action = gen.action(3)
        assertEquals(action, decodeModel<Action>(action.json), label)
    }

    @Test
    fun jsonValueRoundTripThroughText() = forAll { gen, label ->
        val json = gen.json(4)
        assertEquals(json, JsonValue.parse(json.encoded()), label)
    }

    // T1.3 properties

    @Test
    fun addThenSubtractIsIdentityOnInts() = forAll { gen, label ->
        val x = gen.int(-1_000_000..1_000_000)
        val k = gen.int(-1_000_000..1_000_000)
        val r = ValueResolver(state = mapOf("x" to j(x)))
        val out = r.resolve(
            obj(
                "type" to "transform", "input" to obj("type" to "state", "key" to "x"),
                "by" to arr(
                    obj("type" to "add", "by" to obj("type" to "static", "value" to k)),
                    obj("type" to "subtract", "by" to obj("type" to "static", "value" to k)),
                ),
            ),
        )
        assertEquals(j(x), out, label)
        assertNotNull(out.intValue, "int stays int: $label")
    }

    @Test
    fun splitThenJoinRoundTrips() = forAll { gen, label ->
        val s = gen.string(12)
        val sep = gen.pick(listOf(",", " ", "", "ab"))
        val r = ValueResolver(state = emptyMap())
        val out = r.resolve(
            obj(
                "type" to "transform", "input" to obj("type" to "static", "value" to s),
                "by" to arr(obj("type" to "split", "separator" to sep), obj("type" to "join", "separator" to sep)),
            ),
        )
        assertEquals(j(s), out, label)
    }

    @Test
    fun trimIsIdempotent() = forAll { gen, label ->
        val s = " ".repeat(gen.int(0..2)) + gen.string() + "\n"
        val r = ValueResolver(state = emptyMap())
        val once = r.resolve(obj("type" to "transform", "input" to obj("type" to "static", "value" to s), "by" to arr(obj("type" to "trim"))))
        val twice = r.resolve(obj("type" to "transform", "input" to obj("type" to "static", "value" to once), "by" to arr(obj("type" to "trim"))))
        assertEquals(once, twice, label)
    }

    @Test
    fun resolverNeverThrowsOnRandomValues() = forAll { gen, _ ->
        // Where Dart throws, Kotlin yields null; nothing may crash the app.
        val state = mapOf("a" to gen.json(2), "b" to gen.json(1))
        val r = ValueResolver(state = state, animationProgress = gen.int(0..10) / 10.0)
        r.resolveDeep(JsonValue.Object(gen.props()))
        r.evaluate(gen.boolExpr(2))
    }

    @Test
    fun doubleFormattingRoundTrips() = forAll { gen, label ->
        val d = gen.double()
        val text = DartFormat.double(d)
        assertEquals(d, text.toDouble(), "$label: $text")
    }
}
