package com.orcagateway.core.debug

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.PageRenderer
import com.orcagateway.core.resolver.TransformRegistry
import com.orcagateway.core.resolver.ValueResolver
import com.orcagateway.core.state.StoreState
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * C19.1/K: `ValueResolver.resolveWithTrace` gives Flutter's steps
 * (sdk/lib/src/state/value_resolver.dart:374-410, run on the same files by
 * sdk/test/conformance/trace_fixtures_test.dart), and the renderer reports a
 * watched node's traced props as `widget_rebuild` on every resolution, as
 * Flutter's WatchBuilder does (component_renderer.dart:206-228).
 */
class PropTraceTest {
    /** What the renderer reported, in order. */
    private class Rebuilds : DevToolsReporter {
        private val lock = Any()
        private val recorded = ArrayList<DevToolsEvent>()

        val events: List<DevToolsEvent> get() = synchronized(lock) { recorded.toList() }

        override fun report(event: DevToolsEvent) {
            synchronized(lock) { recorded.add(event) }
        }
    }

    private val recorder = Rebuilds()

    @AfterTest
    fun resetReporter() {
        OrcaDebug.reporter = null
    }

    private val countRef = obj("type" to "state", "key" to "count", "scope" to "page")

    /**
     * widget_rebuild-traced.json's node, as the counter page sends it: Text#5
     * watching `count`, `data` a toString over it, and a plain-map `style`
     * whose empty trace is left out.
     */
    private val countText = ComponentNode(
        "5", "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
        props = mapOf(
            "data" to obj("type" to "transform", "input" to countRef, "by" to arr(obj("type" to "toString"))),
            "style" to obj("fontSize" to 48, "fontWeight" to "bold"),
        ),
        watches = listOf("count"),
    )

    private fun countTrace(value: String): List<TraceStep> =
        listOf(TraceStep("state", "count", value), TraceStep("input", null, value), TraceStep("toString", value, value))

    /** Every file in schema/fixtures/traces, one case each: its value and its trace. */
    @TestFactory
    fun c19_1_k_everyTraceFixtureGivesItsValueAndItsTrace(): List<DynamicTest> {
        val files = Fixtures.files("traces")
        assertTrue(files.size >= 4, "the trace fixtures: ${files.map { it.first }}")
        return files.map { (name, fixture) ->
            DynamicTest.dynamicTest("c19_1_k_trace_$name") {
                val state = fixture["state"].decode(StoreState.serializer())
                val resolver = state.resolver(eventData = fixture["event"].objectValue)
                val (value, trace) = resolver.resolveWithTrace(fixture["value"])
                assertJsonEqual(value, fixture["expected"]["value"], "$name: value")
                assertJsonEqual(JsonValue.Array(trace.map { it.json }), fixture["expected"]["trace"], "$name: trace")
            }
        }
    }

    @Test
    fun c19_1_k_aWatchedNodeReportsItsTracedPropsOnEveryResolution() {
        val renderer = PageRenderer(PageResponse("home", "Home", components = listOf(countText)))
        val one = StoreState(page = mapOf("count" to j(1)))
        val untraced = assertNotNull(renderer.resolve("5", one))

        OrcaDebug.reporter = recorder
        val first = assertNotNull(renderer.resolve("5", one))
        assertEquals(untraced.props, first.props, "the same props as untraced")
        assertEquals(j("1"), first.props["data"])
        val fixture = Fixtures.json("schema/fixtures/devtools/widget_rebuild-traced.json")
        assertEquals(1, recorder.events.size, "the first render reports")
        assertEquals(fixture["type"].stringValue, recorder.events[0].type)
        assertJsonEqual(JsonValue.Object(recorder.events[0].payload), fixture["payload"], "the first render")

        val two = one.setting("count", j(2), StateScope.Page)
        assertEquals(j("2"), renderer.resolve("5", two)?.props?.get("data"))
        assertEquals(
            listOf(DevToolsEvent.widgetRebuild("5", "Text", listOf("count"), mapOf("data" to countTrace("2")))),
            recorder.events.drop(1),
            "again after count changes, with the new value",
        )
    }

    @Test
    fun c19_1_k_nothingIsReportedWithoutDebugWatchesOrAValueProp() {
        val page = PageResponse(
            "p", "P",
            components = listOf(
                countText,
                countText.copy(id = "6", watches = emptyList()),
                ComponentNode(
                    "7", "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
                    props = mapOf("data" to j("hi"), "style" to obj("fontSize" to 48)),
                    watches = listOf("count"),
                ),
            ),
        )
        val renderer = PageRenderer(page)
        val state = StoreState(page = mapOf("count" to j(1)))
        assertEquals(j("1"), renderer.resolve("5", state)?.props?.get("data"), "debug off")

        OrcaDebug.reporter = recorder
        assertEquals(j("1"), renderer.resolve("6", state)?.props?.get("data"), "no watches")
        assertEquals(j("hi"), renderer.resolve("7", state)?.props?.get("data"), "no Value prop")
        assertEquals(emptyList(), recorder.events)
    }

    @Test
    fun c19_1_k_resolveWithTraceIsNotReentrantAndLeavesNothingBehind() {
        val transforms = TransformRegistry.defaults.with("nested") { _, current, resolver ->
            resolver.resolveWithTrace(current).first
        }
        val resolver = ValueResolver(state = mapOf("count" to j(1)), transforms = transforms)
        val nested = obj("type" to "transform", "input" to countRef, "by" to arr(obj("type" to "nested")))
        assertFailsWith<IllegalStateException> { resolver.resolveWithTrace(nested) }

        assertEquals(j(1), resolver.resolve(countRef))
        assertEquals(j(1) to listOf(TraceStep("state", "count", "1")), resolver.resolveWithTrace(countRef))
    }
}
