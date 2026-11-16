package com.orcagateway.sdk.debug

import android.content.Context
import android.util.Log
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.DevToolsReporter
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.debug.OrcaDebugOptions
import com.orcagateway.core.json.DartFormat
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.navigation.OrcaRouter
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog
import java.net.InetAddress
import java.net.ServerSocket
import java.net.URI
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.fail

/** Keeps every event it is given, in order, from any thread. */
private class EventRecorder : DevToolsReporter {
    private val events = mutableListOf<DevToolsEvent>()

    override fun report(event: DevToolsEvent) {
        synchronized(events) { events += event }
    }

    fun of(type: String): List<DevToolsEvent> = synchronized(events) { events.filter { it.type == type } }
}

/** The engine's counter page (16 nodes, pageId `home`) for every request. */
private class CounterEngine : HttpTransport {
    private val page = requireNotNull(javaClass.getResource("/pages/counter-home.json")).readBytes()

    override suspend fun send(request: HttpRequest): HttpResponse =
        HttpResponse(200, mapOf("content-type" to "application/json"), page)
}

/** The counter page's node count, as the wire sends it. */
private const val COUNTER_NODES = 16

/**
 * C19.5/K, the unit part: Flutter's OrcaDebugOverlay
 * (sdk/lib/src/debug/debug_overlay.dart, drawn by orca_page.dart:396-403)
 * over each server page while DevTools is on and showOverlay is set; the
 * host's debug config reaching the core's options (C19.3/C19.4 from the
 * host); logTimings' line (orca_debug.dart:57-63).
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class DebugOverlayTest {
    @get:Rule
    val compose = createComposeRule()

    @After
    fun reset() {
        OrcaDebug.stop()
    }

    private fun router() = OrcaRouter(
        OrcaClient(URI("http://engine.invalid"), appId = "counter", transport = CounterEngine()),
        path = "home",
    )

    /** A port on this machine nothing listens on: the DevTools client is refused and retries until stopped. */
    private fun refusedPort(): Int = ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { it.localPort }

    /** DevTools on as a host turns it on, with [config]'s debug options. */
    private fun startDevTools(config: OrcaDebugConfig) {
        assertNotNull(OrcaDebug.start(config.copy(enabled = true, host = "127.0.0.1", port = refusedPort())))
    }

    /** OrcaApp over [router], once its page is drawn. */
    private fun show(router: OrcaRouter) {
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { compose.onAllNodes(hasText("Counter Example")).fetchSemanticsNodes().isNotEmpty() }
    }

    /** The loaded page's request start to render complete, in ms. */
    private fun loadMs(router: OrcaRouter): Double {
        val phase = router.loader(router.root).phase as? OrcaPageLoader.Phase.Loaded ?: fail("not loaded")
        return assertNotNull(phase.renderCompleteMs, "the loader measured the page")
    }

    private fun overlays(): Int = compose.onAllNodes(hasTestTag(DEBUG_OVERLAY_TAG)).fetchSemanticsNodes().size

    @Test
    fun c19_5_k_aDefaultConfigDrawsNoOverlay() {
        assertNull(OrcaDebug.start(OrcaDebugConfig()))
        show(router())
        assertEquals(0, overlays())
    }

    @Test
    fun c19_5_k_devToolsWithoutShowOverlayDrawsNoOverlay() {
        startDevTools(OrcaDebugConfig())
        show(router())
        assertEquals(0, overlays())
    }

    @Test
    fun c19_5_k_devToolsWithShowOverlayDrawsTheLoadChipAtTheBottomRight() {
        startDevTools(OrcaDebugConfig(showOverlay = true))
        val router = router()
        show(router)

        val load = assertNotNull(DartFormat.fixed(loadMs(router), 0))
        compose.onNodeWithText("${load}ms").assertIsDisplayed()
        assertEquals(1, overlays())
        // Flutter's Positioned(right: 8, bottom: 8) over the page.
        val root = compose.onRoot().getUnclippedBoundsInRoot()
        val chip = compose.onNodeWithTag(DEBUG_OVERLAY_TAG).getUnclippedBoundsInRoot()
        assertTrue(abs((root.right - chip.right - 8.dp).value) < 0.5f, "right inset: $root $chip")
        assertTrue(abs((root.bottom - chip.bottom - 8.dp).value) < 0.5f, "bottom inset: $root $chip")
    }

    @Test
    fun c19_5_k_aTapExpandsTheChipAndASecondCollapsesIt() {
        startDevTools(OrcaDebugConfig(showOverlay = true))
        val router = router()
        show(router)
        val ms = loadMs(router)
        val collapsed = "${DartFormat.fixed(ms, 0)}ms"

        compose.onNodeWithTag(DEBUG_OVERLAY_TAG).performClick()
        compose.onNodeWithText("Load: ${DartFormat.fixed(ms, 1)}ms").assertIsDisplayed()
        compose.onNodeWithText("Components: $COUNTER_NODES").assertIsDisplayed()
        compose.onNodeWithText("Cache: -").assertIsDisplayed()
        assertEquals(0, compose.onAllNodes(hasText(collapsed)).fetchSemanticsNodes().size)

        compose.onNodeWithTag(DEBUG_OVERLAY_TAG).performClick()
        compose.onNodeWithText(collapsed).assertIsDisplayed()
        assertEquals(0, compose.onAllNodes(hasText("Cache: -")).fetchSemanticsNodes().size)
    }

    @Test
    fun c19_5_k_theOverlayLeavesThePageTouchable() {
        startDevTools(OrcaDebugConfig(showOverlay = true))
        show(router())
        compose.onNodeWithText("+").performClick()
        compose.onNodeWithText("1").assertIsDisplayed()
        assertEquals(1, overlays())
    }

    @Test
    fun c19_5_k_aPageWithoutTimingShowsDashMs() {
        compose.setContent {
            Box(Modifier.fillMaxSize()) { DebugOverlayChip(loadMs = null, componentCount = 3) }
        }
        compose.onNodeWithText("-ms").assertIsDisplayed()
        compose.onNodeWithTag(DEBUG_OVERLAY_TAG).performClick()
        compose.onNodeWithText("Load: -ms").assertIsDisplayed()
        compose.onNodeWithText("Components: 3").assertIsDisplayed()
        compose.onNodeWithText("Cache: -").assertIsDisplayed()
    }

    @Test
    fun c19_5_k_startCopiesTheHostsOptionsAndStopResetsThem() {
        // Flutter's defaults, and the existing positional call sites still compile.
        val defaults = OrcaDebugConfig(true, "10.0.2.2", 6363, "Counter", "2.0.0")
        assertEquals(
            listOf(false, false, true, true, false),
            with(defaults) { listOf(showOverlay, logTimings, captureStateChanges, captureNetworkRequests, includeBodies) },
        )

        val all = OrcaDebugConfig(
            showOverlay = true,
            logTimings = true,
            captureStateChanges = false,
            captureNetworkRequests = false,
            includeBodies = true,
        )
        startDevTools(all)
        assertEquals(
            OrcaDebugOptions(captureStateChanges = false, captureNetworkRequests = false, includeBodies = true, logTimings = true),
            OrcaDebug.options,
        )
        assertTrue(DebugOverlaySwitch.showOverlay)

        OrcaDebug.stop()
        assertFalse(OrcaDebug.isEnabled)
        assertEquals(OrcaDebugOptions(), OrcaDebug.options)
        assertFalse(DebugOverlaySwitch.showOverlay)

        // A disabled config connects nothing and leaves the defaults.
        assertNull(OrcaDebug.start(all))
        assertEquals(OrcaDebugOptions(), OrcaDebug.options)
        assertFalse(DebugOverlaySwitch.showOverlay)
    }

    /** The router's page loaded, before its first frame. */
    private fun loaded(router: OrcaRouter): OrcaPageModel = runBlocking {
        val loader = router.loader(router.root)
        loader.loadIfNeeded(ApplicationProvider.getApplicationContext<Context>())
        (loader.phase as? OrcaPageLoader.Phase.Loaded)?.model ?: fail("not loaded: ${loader.phase}")
    }

    private fun timingLines() = ShadowLog.getLogsForTag(WidgetBuilders.LOG_TAG).filter { it.msg.startsWith("[OrcaDebug]") }

    @Test
    fun c19_5_k_logTimingsWritesFluttersLineOncePerTimingEvent() {
        ShadowLog.clear()
        val recorder = EventRecorder()
        OrcaDebug.reporter = recorder
        OrcaDebug.options = OrcaDebugOptions(logTimings = true)
        val model = loaded(router())
        assertEquals(emptyList(), timingLines(), "with the event, on the first frame")
        model.appeared()
        model.appeared()

        assertEquals(1, recorder.of("timing").size)
        val line = timingLines().single()
        assertEquals("[OrcaDebug] Timing: home - home", line.msg)
        assertEquals(Log.INFO, line.type)
    }

    @Test
    fun c19_5_k_withoutLogTimingsNoLineIsWritten() {
        ShadowLog.clear()
        val recorder = EventRecorder()
        OrcaDebug.reporter = recorder
        val model = loaded(router())
        model.appeared()

        assertEquals(1, recorder.of("timing").size)
        assertEquals(emptyList(), timingLines())
    }
}
