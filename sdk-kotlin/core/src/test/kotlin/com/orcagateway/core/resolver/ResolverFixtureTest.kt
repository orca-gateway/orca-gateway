package com.orcagateway.core.resolver

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.decodeModel
import com.orcagateway.core.support.j
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * T1.2: for every render fixture with a `resolved` map, resolving each listed
 * prop against the fixture's app+page state gives the pinned value. Same
 * procedure as sdk/test/conformance/render_resolved_test.dart.
 */
class ResolverFixtureTest {
    @Test
    fun resolvedMapsMatch() {
        val covered = mutableListOf<String>()
        for ((name, fixture) in Fixtures.files("render")) {
            val resolved = fixture["resolved"].objectValue ?: continue
            covered.add(name)
            val context = fixture["context"]
            val resolver = ValueResolver(
                page = context["pageState"].objectValue ?: emptyMap(),
                app = context["appState"].objectValue ?: emptyMap(),
            )
            val nodes = decodeModel<List<ComponentNode>>(fixture["expected"])
            val byId = LinkedHashMap<String, ComponentNode>()
            for (node in nodes) byId.putIfAbsent(node.id, node)

            for ((id, props) in resolved) {
                val node = byId[id] ?: fail("$name: node $id missing")
                for ((prop, expected) in props.objectValue.orEmpty()) {
                    val got = resolver.resolveDeep(node.props[prop] ?: JsonValue.Null)
                    assertJsonEqual(got, expected, "$name $id.$prop")
                }
            }
        }
        // 03, 05, 06, 09, 18, 22 carry resolved maps (S0, 23b.6).
        assertTrue(covered.size >= 6, "$covered")
    }

    @Test
    fun tweenFixtureResolvesAtBothEnds() {
        // Fixture 24 has no resolved map (it needs animation progress); pin
        // its value at progress 0 and 1 from the Dart semantics instead.
        val fixture = Fixtures.json("schema/fixtures/render/24_tween_transform.json")
        val node = decodeModel<List<ComponentNode>>(fixture["expected"])[0]
        val data = node.props["data"] ?: JsonValue.Null
        assertEquals(j(0), ValueResolver(state = emptyMap(), animationProgress = 0.0).resolve(data))
        assertEquals(j(42), ValueResolver(state = emptyMap(), animationProgress = 1.0).resolve(data))
        assertEquals(j(21), ValueResolver(state = emptyMap(), animationProgress = 0.5).resolve(data))
    }
}
