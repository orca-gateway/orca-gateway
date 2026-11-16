package com.orcagateway.core.debug

import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.StubEngine
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import java.net.ConnectException
import java.net.URI
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Collects what the SDK reports to DevTools. */
private class Recorder : DevToolsReporter {
    private val lock = Any()
    private val recorded = ArrayList<DevToolsEvent>()

    val events: List<DevToolsEvent> get() = synchronized(lock) { recorded.toList() }

    fun of(type: String): List<DevToolsEvent> = events.filter { it.type == type }

    override fun report(event: DevToolsEvent) {
        synchronized(lock) { recorded.add(event) }
    }
}

/** A transport that answers every request with [answer]. */
private class Answering(val answer: (HttpRequest) -> HttpResponse) : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse = answer(request)
}

/** A transport that never reaches a server. */
private object Down : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse = throw ConnectException("Connection refused")
}

/**
 * Step 19, rows C19.3 and C19.4: the core debug options with Flutter's names
 * and defaults (sdk/lib/src/debug/orca_debug.dart OrcaDebugConfig), the two
 * capture gates, and the network bodies a host opts into.
 */
class DebugOptionsTest {
    private val recorder = Recorder()
    private val base = URI("http://localhost:8080")

    /** network-bodies.json, Flutter's page fetch with bodies on. */
    private val fixture: JsonValue = Fixtures.json("schema/fixtures/devtools/network-bodies.json")["payload"]
    private val appState: Map<String, JsonValue> = assertNotNull(fixture["requestBody"].objectValue)
    private val page: ByteArray = fixture["responseBody"].encoded().encodeToByteArray()

    private fun pageServer(): HttpTransport = Answering {
        HttpResponse(200, headers = mapOf("content-type" to "application/json", "set-cookie" to "sid=1"), body = page)
    }

    @AfterTest
    fun reset() {
        OrcaDebug.reporter = null
        OrcaDebug.options = OrcaDebugOptions()
    }

    // C19.3: bodies

    @Test
    fun c19_3_aPageFetchCarriesTheFixtureBodies() = runSuspend {
        OrcaDebug.reporter = recorder
        OrcaDebug.options = OrcaDebugOptions(includeBodies = true)
        val client = OrcaClient(base, "counter", apiKey = "demo-key", transport = pageServer())
        client.fetchPage("home", appState)
        val event = recorder.of("network").single().payload
        assertEquals(j("POST"), event["method"])
        assertJsonEqual(assertNotNull(event["requestBody"]), fixture["requestBody"], "the appState sent, not the wire body")
        assertJsonEqual(assertNotNull(event["responseBody"]), fixture["responseBody"], "the page, parsed")
        assertEquals(j("<redacted>"), event["requestHeaders"]?.get("Authorization"), "redacted with bodies on")
        assertEquals(j("<redacted>"), event["responseHeaders"]?.get("set-cookie"), "redacted with bodies on")
    }

    @Test
    fun c19_3_bothHandshakeRequestsReportTheAppStateNotTheWireBody() = runSuspend {
        OrcaDebug.reporter = recorder
        OrcaDebug.options = OrcaDebugOptions(includeBodies = true)
        val stub = StubEngine(page)
        val client = OrcaClient(base, "counter", transport = stub)
        client.fetchPage("home", appState)
        val network = recorder.of("network").map { it.payload }
        assertEquals(listOf(j(412), j(200)), network.map { it["statusCode"] })
        assertTrue(JsonValue.parse(assertNotNull(stub.requests[1].body))["_orcaCapsVector"] is JsonValue.Object)
        for (event in network) assertJsonEqual(assertNotNull(event["requestBody"]), fixture["requestBody"])
        assertEquals(j("caps_vector_unknown"), network[0]["responseBody"]?.get("error"))
        assertJsonEqual(assertNotNull(network[1]["responseBody"]), fixture["responseBody"])
    }

    @Test
    fun c19_3_otherRequestsReportTheirJsonBodyAndRawTextAnswers() = runSuspend {
        OrcaDebug.reporter = recorder
        OrcaDebug.options = OrcaDebugOptions(includeBodies = true)
        val server = Answering { request ->
            if (request.url.path.endsWith("/action")) {
                HttpResponse(200, body = """{"actions":[]}""".encodeToByteArray())
            } else {
                HttpResponse(503, body = "down for maintenance".encodeToByteArray())
            }
        }
        val client = OrcaClient(base, "counter", transport = server)
        client.executeAction("increment", props("by" to 1), null, null)
        val action = recorder.of("network").last().payload
        assertJsonEqual(assertNotNull(action["requestBody"]), obj("action" to "increment", "params" to mapOf("by" to 1)))
        assertJsonEqual(assertNotNull(action["responseBody"]), obj("actions" to emptyList<Any>()))

        assertFailsWith<OrcaClientException.Http> { client.fetchConfig() }
        val config = recorder.of("network").last().payload
        assertFalse("requestBody" in config, "a GET has no body")
        assertEquals(j("down for maintenance"), config["responseBody"], "not JSON: the raw text, a non-200 too")

        val down = OrcaClient(base, "counter", transport = Down)
        assertFailsWith<ConnectException> { down.executeAction("increment", null, null, null) }
        val failed = recorder.of("network").last().payload
        assertEquals(j(0), failed["statusCode"])
        assertJsonEqual(assertNotNull(failed["requestBody"]), obj("action" to "increment"))
        assertFalse("responseBody" in failed, "a transport failure has no response")
    }

    @Test
    fun c19_3_theDefaultsAreFlutterSAndSendNoBodies() = runSuspend {
        assertEquals(OrcaDebugOptions(), OrcaDebug.options)
        val defaults = OrcaDebugOptions()
        assertTrue(defaults.captureStateChanges)
        assertTrue(defaults.captureNetworkRequests)
        assertFalse(defaults.includeBodies)
        assertFalse(defaults.logTimings)

        OrcaDebug.reporter = recorder
        val client = OrcaClient(base, "counter", apiKey = "demo-key", transport = pageServer())
        client.fetchPage("home", appState)
        val event = recorder.of("network").single().payload
        assertNull(event["requestBody"])
        assertNull(event["responseBody"])
        assertEquals(j("<redacted>"), event["requestHeaders"]?.get("Authorization"))
    }

    // C19.4: the capture gates

    @Test
    fun c19_4_stateChangesOffStopsOnlyStateChanges() = runSuspend {
        OrcaDebug.reporter = recorder
        OrcaDebug.options = OrcaDebugOptions(captureStateChanges = false)
        val store = ElmStore(props("n" to 0))
        store.pageId = "home"
        ActionExecutor(store).execute(Action.SetState(key = "n", value = j(1)))
        store.dispatch(props("n" to 2))
        OrcaClient(base, "counter", transport = pageServer()).fetchPage("home")
        assertEquals(j(2), store.value("n"), "the store still changes")
        assertEquals(emptyList(), recorder.of("state_change"))
        assertEquals(listOf(j("setState")), recorder.of("action").map { it.payload["actionType"] })
        assertEquals(1, recorder.of("network").size)

        OrcaDebug.options = OrcaDebugOptions()
        store.dispatch(props("n" to 3))
        assertEquals(1, recorder.of("state_change").size, "on again: reported again")
    }

    @Test
    fun c19_4_networkOffStopsOnlyNetworkEvents() = runSuspend {
        OrcaDebug.reporter = recorder
        OrcaDebug.options = OrcaDebugOptions(captureNetworkRequests = false, includeBodies = true)
        OrcaClient(base, "counter", transport = pageServer()).fetchPage("home", appState)
        val failing = OrcaClient(base, "counter", transport = Answering { HttpResponse(500, body = "boom".encodeToByteArray()) })
        assertFailsWith<OrcaClientException.Http> { failing.fetchPage("home") }
        assertFailsWith<ConnectException> { OrcaClient(base, "counter", transport = Down).fetchPage("home") }
        val store = ElmStore(props("n" to 0))
        store.pageId = "home"
        ActionExecutor(store).execute(Action.SetState(key = "n", value = j(1)))

        assertEquals(emptyList(), recorder.of("network"))
        assertEquals(2, recorder.of("error").size, "the 500 and the refused connection are still errors")
        assertEquals(1, recorder.of("state_change").size)
        assertEquals(1, recorder.of("action").size)

        OrcaDebug.options = OrcaDebugOptions()
        OrcaClient(base, "counter", transport = pageServer()).fetchPage("home")
        assertEquals(1, recorder.of("network").size, "on again: reported again")
    }
}
