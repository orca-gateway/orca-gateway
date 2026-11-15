package com.orcagateway.core.telemetry

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.render.PageRenderer
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.StoreState
import com.orcagateway.core.support.TestWidgets
import java.util.Collections
import java.util.concurrent.CountDownLatch
import kotlin.concurrent.thread
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

/**
 * C15.6 on the Kotlin core: the telemetry sink receives
 * `unknown_widget_type` once per type per process, whatever registry saw it.
 * Ports sdk/test/safe_degrade_test.dart's telemetry cases (Dart
 * sdk/lib/src/telemetry/orca_telemetry.dart). [OrcaTelemetry] is global, so
 * the sink and the dedup set are reset around each test.
 */
class OrcaTelemetryTest {
    private data class Event(val name: String, val data: Map<String, JsonValue>)

    private val events: MutableList<Event> = Collections.synchronizedList(ArrayList())

    private fun record(name: String, data: Map<String, JsonValue>) {
        events.add(Event(name, data))
    }

    private fun unknown(type: String): Event = Event("unknown_widget_type", mapOf("type" to JsonValue.String(type)))

    private fun page(type: String): PageResponse = PageResponse(
        "p", "P",
        components = listOf(
            ComponentNode("0", "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, children = listOf("1", "2")),
            ComponentNode("1", type, ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None),
            ComponentNode("2", type, ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None),
        ),
    )

    @BeforeTest
    @AfterTest
    fun reset() {
        OrcaTelemetry.onEvent = null
        OrcaTelemetry.resetForTesting()
    }

    @Test
    fun c15_6_anUnknownTypeOnAPageReportsUnknownWidgetTypeOnce() {
        OrcaTelemetry.onEvent = ::record
        val renderer = PageRenderer(page("HoloDeck"), TestWidgets.registry())

        val tree = assertNotNull(renderer.tree(StoreState()))

        assertEquals(listOf("FallbackPrompt", "FallbackPrompt"), tree.children.map { it.type })
        assertEquals(listOf(unknown("HoloDeck")), events.toList())
    }

    @Test
    fun c15_6_aSecondRenderOrASecondRegistryReportsNothingMore() {
        OrcaTelemetry.onEvent = ::record
        val page = page("HoloDeck")
        val renderer = PageRenderer(page, TestWidgets.registry())
        renderer.tree(StoreState())
        renderer.tree(StoreState())

        val perRegistry = ArrayList<String>()
        val second = TestWidgets.registry(onUnknownType = { perRegistry.add(it) })
        PageRenderer(page, second).tree(StoreState())
        WidgetRegistry(types = emptySet()).reportUnknown("HoloDeck")

        assertEquals(listOf(unknown("HoloDeck")), events.toList())
        // The registry's own callback and set are unchanged: it still hears its first sighting.
        assertEquals(listOf("HoloDeck"), perRegistry)
        assertEquals(setOf("HoloDeck"), second.reportedTypes)
    }

    @Test
    fun c15_6_dedupRunsWithNoSinkSet() {
        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        OrcaTelemetry.onEvent = ::record

        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        assertEquals(emptyList(), events.toList())

        OrcaTelemetry.reportUnknownWidgetOnce("Teleporter")
        assertEquals(listOf(unknown("Teleporter")), events.toList())
    }

    @Test
    fun c15_6_resetForTestingLetsATypeReportAgain() {
        OrcaTelemetry.onEvent = ::record
        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        assertEquals(listOf(unknown("HoloDeck")), events.toList())

        OrcaTelemetry.resetForTesting()
        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        assertEquals(listOf(unknown("HoloDeck"), unknown("HoloDeck")), events.toList())
    }

    @Test
    fun c15_6_manyThreadsReportingOneTypeReportItOnce() {
        OrcaTelemetry.onEvent = ::record
        val start = CountDownLatch(1)
        val threads = (1..16).map {
            thread {
                start.await()
                repeat(100) { OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck") }
            }
        }
        start.countDown()
        threads.forEach { it.join() }

        assertEquals(listOf(unknown("HoloDeck")), events.toList())
    }
}
