package com.orcagateway.core.debug

import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.PageRenderer
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.StubEngine
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import java.net.ConnectException
import java.net.URI
import kotlin.coroutines.cancellation.CancellationException
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/** Collects what the SDK reports to DevTools (Swift `EventRecorder`). */
private class EventRecorder : DevToolsReporter {
    private val lock = Any()
    private val recorded = ArrayList<DevToolsEvent>()

    val events: List<DevToolsEvent> get() = synchronized(lock) { recorded.toList() }

    fun of(type: String): List<DevToolsEvent> = events.filter { it.type == type }

    override fun report(event: DevToolsEvent) {
        synchronized(lock) { recorded.add(event) }
    }
}

/** A transport that never reaches a server (Swift `DownTransport`). */
private object DownTransport : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse = throw ConnectException("Connection refused")
}

/**
 * T6.4.5, who reports what: the store, the executor, the renderer and the
 * client send their DevTools events, as Swift's DevToolsEventTests 6 to 10
 * check (sdk-swift/Tests/OrcaGatewayCoreTests/DevToolsEventTests.swift).
 */
class DevToolsReportingTest {
    private val recorder = EventRecorder()

    private fun counterPage(): ByteArray = Fixtures.text("sdk-swift/Tests/Pages/counter-home.json").encodeToByteArray()

    @AfterTest
    fun resetReporter() {
        OrcaDebug.reporter = null
    }

    /** Swift `testTheStoreReportsChangedKeysOfItsPage`. */
    @Test
    fun e6_theStoreReportsChangedKeysOfItsPage() {
        OrcaDebug.reporter = recorder
        val anonymous = ElmStore(props("n" to 0))
        anonymous.dispatch(props("n" to 1))
        assertEquals(emptyList<DevToolsEvent>(), recorder.events, "a store without a page reports nothing")

        val store = ElmStore(props("n" to 0))
        store.pageId = "home"
        store.dispatch(props("n" to 1, "same" to null))
        store.dispatch(props("cart" to 2), StateScope.App)
        assertEquals(
            listOf(
                DevToolsEvent.stateChange(StateScope.Page, "home", "n", j(0), j(1)),
                DevToolsEvent.stateChange(StateScope.App, "home", "cart", JsonValue.Null, j(2)),
            ),
            recorder.events,
        )
    }

    /** Swift `testTheExecutorReportsEveryActionRun`. */
    @Test
    fun e7_theExecutorReportsEveryActionRun() = runSuspend {
        OrcaDebug.reporter = recorder
        val store = ElmStore(props("n" to 0))
        store.pageId = "home"
        val executor = ActionExecutor(store)
        executor.execute(
            Action.ActionGroup(
                actions = listOf(Action.SetState(key = "n", value = j(1)), Action.ShowToast(message = j("hi"))),
            ),
        )
        val actions = recorder.of("action")
        assertEquals(
            listOf(j("setState"), j("showToast"), j("actionGroup")),
            actions.map { it.payload["actionType"] },
            "children finish first, as in Dart",
        )
        assertEquals(listOf(j("home"), j("home"), j("home")), actions.map { it.payload["pageId"] })
        assertJsonEqual(assertNotNull(actions[0].payload["data"]), obj("type" to "setState", "key" to "n", "value" to 1))
        assertNotNull(actions[2].payload["durationMs"]?.doubleValue)
        assertEquals(1, recorder.of("state_change").size)
    }

    /**
     * Cancellation is not a failure (the lifecycle action, `OrcaApp.reload`):
     * a cancelled run goes up with no `action` event, its group neither; a
     * run that fails is still reported, as Swift's `defer` does.
     */
    @Test
    fun e7_aCancelledActionRunIsNotReported() = runSuspend {
        OrcaDebug.reporter = recorder
        val store = ElmStore(props("n" to 0))
        store.pageId = "home"
        val executor = ActionExecutor(store)
        var failure: Exception = IllegalStateException("no toast here")
        executor.perform = { throw failure }
        assertFailsWith<IllegalStateException> { executor.execute(Action.ShowToast(message = j("hi"))) }
        assertEquals(listOf(j("showToast")), recorder.of("action").map { it.payload["actionType"] }, "a failed run is reported")

        failure = CancellationException("left the screen")
        assertFailsWith<CancellationException> {
            executor.execute(Action.ActionGroup(actions = listOf(Action.ShowToast(message = j("hi")))))
        }
        assertEquals(1, recorder.of("action").size, "neither the cancelled toast nor its group is reported")
    }

    /** Swift `testAFallbackPromptIsReportedOncePerType`. */
    @Test
    fun e8_aFallbackPromptIsReportedOncePerType() {
        OrcaDebug.reporter = recorder
        val page = PageResponse(
            "p", "P",
            components = listOf(
                ComponentNode("0", "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, children = listOf("1", "2")),
                ComponentNode("1", "Checkbox", ComponentNode.Kind.Input, ComponentNode.ChildMode.None),
                ComponentNode("2", "Checkbox", ComponentNode.Kind.Input, ComponentNode.ChildMode.None),
            ),
        )
        val renderer = PageRenderer(page, WidgetRegistry())
        assertEquals("FallbackPrompt", renderer.resolve("1", StoreState())?.type)
        assertEquals("FallbackPrompt", renderer.resolve("2", StoreState())?.type)
        assertEquals(listOf(DevToolsEvent.fallbackPrompt("Checkbox")), recorder.events)
    }

    /** Swift `testTheClientReportsRequestsAndFailures`. */
    @Test
    fun e9_theClientReportsRequestsAndFailures() = runSuspend {
        OrcaDebug.reporter = recorder
        val stub = StubEngine(counterPage())
        val client = OrcaClient(URI("http://localhost:8080"), "counter", apiKey = "demo-key", transport = stub)
        client.fetchPage("home")
        val network = recorder.of("network")
        assertEquals(listOf(j(412), j(200)), network.map { it.payload["statusCode"] }, "the handshake, then the page")
        assertEquals(j("<redacted>"), network[1].payload["requestHeaders"]?.get("Authorization"))
        assertEquals(j("wait"), network[1].payload["phases"]?.arrayValue?.first()?.get("phase"))
        assertEquals(emptyList<DevToolsEvent>(), recorder.of("error"), "the handshake's 412 is expected")

        stub.forced = HttpResponse(500, body = """{"error":"boom"}""".encodeToByteArray())
        assertFailsWith<OrcaClientException.Http>("a 500 throws") { client.fetchPage("home") }
        assertEquals(
            DevToolsEvent.error(
                message = "HTTP 500 /api/v1/app/counter/page/home",
                stackTrace = """{"error":"boom"}""",
                context = "GET http://localhost:8080/api/v1/app/counter/page/home",
            ),
            recorder.of("error").last(),
        )

        val down = OrcaClient(URI("http://localhost:9"), "counter", transport = DownTransport)
        assertFailsWith<ConnectException>("a dead transport throws") { down.fetchPage("home") }
        assertEquals(j(0), recorder.of("network").last().payload["statusCode"])
        assertEquals(
            j("GET http://localhost:9/api/v1/app/counter/page/home"),
            recorder.of("error").last().payload["context"],
        )
        assertTrue(recorder.of("error").last().payload["message"]?.stringValue?.startsWith("Network request failed: ") == true)
    }

    /**
     * A request cancelled while it waits (someone left the loading screen)
     * is not a failure: the cancellation goes up, with no `network` and no
     * `error` event. A refused connection is still both (the test above).
     */
    @Test
    fun e9_aCancelledRequestIsNotReported() = runSuspend {
        OrcaDebug.reporter = recorder
        val left = object : HttpTransport {
            override suspend fun send(request: HttpRequest): HttpResponse = throw CancellationException("left the screen")
        }
        val client = OrcaClient(URI("http://localhost:8080"), "counter", transport = left)
        assertFailsWith<CancellationException> { client.fetchPage("home") }
        assertFailsWith<CancellationException> { client.executeAction("increment", null, null, null) }
        assertEquals(emptyList<DevToolsEvent>(), recorder.of("network"))
        assertEquals(emptyList<DevToolsEvent>(), recorder.of("error"))
    }

    /**
     * Trade-off 3 (native-sdk-s8, gate 08): a refused capability vector, the
     * 412 caps_vector_unknown that answers the retry, is an error, as Dart
     * reports it (`_reportHttpErrorResponse`); Swift files it as a handshake.
     */
    @Test
    fun e9_theRefusedVectorIsReportedAsAnError() = runSuspend {
        OrcaDebug.reporter = recorder
        val stub = StubEngine(counterPage())
        stub.refuseVectors = true
        val client = OrcaClient(URI("http://localhost:8080"), "counter", transport = stub)
        assertFailsWith<OrcaClientException.Http> { client.fetchPage("home") }
        assertEquals(listOf(j(412), j(412)), recorder.of("network").map { it.payload["statusCode"] })
        val errors = recorder.of("error")
        assertEquals(1, errors.size, "the first 412 is the handshake, the second one the refusal")
        assertEquals(j("HTTP 412 /api/v1/app/counter/page/home"), errors[0].payload["message"])
        assertEquals(j("POST http://localhost:8080/api/v1/app/counter/page/home"), errors[0].payload["context"])
        assertEquals(
            "caps_vector_unknown",
            errors[0].payload["stackTrace"]?.stringValue?.let { JsonValue.parse(it)["error"].stringValue },
        )
    }

    /** Swift `testATimedFetchReadsTheServerTiming`. */
    @Test
    fun e10_aTimedFetchReadsTheServerTiming() = runSuspend {
        val header = """{"path":"/x","method":"GET","stages":{"render":0.5},"componentCount":3,""" +
            """"responseSizeBytes":10,"cacheStatus":"hit","totalMs":1,"timestamp":1}"""
        val page = counterPage()
        val timed = object : HttpTransport {
            override suspend fun send(request: HttpRequest): HttpResponse =
                HttpResponse(200, headers = mapOf("x-orca-timing" to header), body = page)
        }
        val client = OrcaClient(URI("http://localhost:8080"), "counter", transport = timed)
        val (fetched, timing) = client.fetchPageTimed("home")
        assertEquals(j("hit"), timing.server?.get("cacheStatus"))
        assertTrue(timing.responseReceivedMs <= timing.parseCompleteMs)
        val event = timing.event(
            pageId = fetched.pageId, path = "home", renderStartMs = 1.0, renderCompleteMs = 2.0, firstFrameMs = 3.0,
        )
        assertEquals(j(3), event.payload["server"]?.get("componentCount"))
        assertEquals(j(3), event.payload["client"]?.get("firstFrameMs"))
        assertEquals(j(0), event.payload["client"]?.get("requestStartMs"))
    }
}
