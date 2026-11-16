package com.orcagateway.core.debug

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.state.StoreState
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull

/**
 * T6.4.5: the Kotlin SDK builds every event in schema/fixtures/devtools
 * exactly as the Flutter SDK does (sdk/test/conformance/devtools_events_test.dart)
 * and the Swift SDK does (sdk-swift/Tests/OrcaGatewayCoreTests/DevToolsEventTests.swift).
 * Who reports what (E6 to E10) is DevToolsReportingTest.
 */
class DevToolsEventTest {
    @AfterTest
    fun resetReporter() {
        OrcaDebug.reporter = null
    }

    // The fixtures

    /** Swift `testSwiftBuildsEveryFixture`. */
    @Test
    fun e1_everyFixtureIsRebuilt() {
        fun action(file: String): Action =
            Fixtures.json("schema/fixtures/devtools/$file.json")["payload"]["data"].decode(Action.serializer())
        // Flutter's traces (ValueResolver.resolveWithTrace) of the fixtures' values.
        val countPlusOne = listOf(TraceStep("state", "count", "0"), TraceStep("input", null, "0"), TraceStep("add", "0", "1"))
        val countText = listOf(TraceStep("state", "count", "1"), TraceStep("input", null, "1"), TraceStep("toString", "1", "1"))
        val built: Map<String, DevToolsEvent> = mapOf(
            "device_info" to DevToolsEvent.deviceInfo(platform = "iOS", deviceModel = "iPhone17,1", appName = "Orca Counter"),
            "timing" to DevToolsEvent.timing(
                pageId = "home",
                path = "home",
                server = obj(
                    "path" to "/api/v1/app/counter/page/home",
                    "method" to "GET",
                    "stages" to mapOf("getInfo" to 0.12, "getState" to 0.05, "render" to 0.41, "flatten" to 0.2),
                    "componentCount" to 16,
                    "responseSizeBytes" to 2048,
                    "cacheStatus" to "miss",
                    "totalMs" to 1.5,
                    "timestamp" to 1_793_980_799_990L,
                ),
                client = DevToolsEvent.ClientTiming(
                    responseReceivedMs = 12.5,
                    parseCompleteMs = 13.25,
                    renderStartMs = 13.5,
                    renderCompleteMs = 20.75,
                    firstFrameMs = 21.5,
                ),
            ),
            "state_change" to DevToolsEvent.stateChange(StateScope.Page, "home", "count", j(0), j(1)),
            "action" to DevToolsEvent.action(action("action"), pageId = "home", durationMs = 0.75),
            "action-traced" to DevToolsEvent.action(
                action("action-traced"),
                pageId = "home",
                durationMs = 1.25,
                transformTrace = countPlusOne,
                affectedWidgets = listOf(
                    obj("id" to "5", "type" to "Text", "watches" to listOf("count")),
                    obj("id" to "8", "type" to "Container", "watches" to listOf("count", "theme")),
                ),
            ),
            "network" to DevToolsEvent.network(
                method = "GET",
                url = "http://localhost:8080/api/v1/app/counter/page/home",
                statusCode = 200,
                durationMs = 12.5,
                responseSizeBytes = 2048,
                requestHeaders = DevToolsEvent.sanitize(mapOf("accept" to "application/json", "x-api-key" to "demo-key")),
                responseHeaders = mapOf("content-type" to "application/json"),
                phases = listOf(DevToolsEvent.NetworkPhase("wait", 12.5)),
            ),
            "network-bodies" to DevToolsEvent.network(
                method = "POST",
                url = "http://localhost:8080/api/v1/app/counter/page/home",
                statusCode = 200,
                durationMs = 14.25,
                responseSizeBytes = 316,
                requestHeaders = DevToolsEvent.sanitize(
                    linkedMapOf(
                        "accept" to "application/json", "authorization" to "Bearer k", "cookie" to "a=1",
                        "proxy-authorization" to "p", "x-api-key" to "demo-key",
                    ),
                ),
                responseHeaders = DevToolsEvent.sanitize(
                    linkedMapOf("content-type" to "application/json", "set-cookie" to "s=1"),
                ),
                phases = listOf(DevToolsEvent.NetworkPhase("wait", 14.25)),
                requestBody = obj("theme" to "dark", "cartCount" to 2),
                responseBody = obj(
                    "pageId" to "home",
                    "title" to "Home",
                    "state" to listOf(mapOf("key" to "count", "scope" to "page", "initial" to 0)),
                    "components" to listOf(
                        mapOf(
                            "id" to "5",
                            "type" to "Text",
                            "kind" to "primitive",
                            "childMode" to "none",
                            "props" to mapOf(
                                "data" to mapOf(
                                    "type" to "transform",
                                    "input" to mapOf("type" to "state", "key" to "count", "scope" to "page"),
                                    "by" to listOf(mapOf("type" to "toString")),
                                ),
                            ),
                            "children" to emptyList<String>(),
                            "watches" to listOf("count"),
                        ),
                    ),
                ),
            ),
            "widget_rebuild" to DevToolsEvent.widgetRebuild(
                widgetId = "5",
                widgetType = "Text",
                watches = listOf("count"),
                propTraces = mapOf("data" to listOf(TraceStep("toString", "1", "1"))),
            ),
            "widget_rebuild-traced" to DevToolsEvent.widgetRebuild(
                widgetId = "5",
                widgetType = "Text",
                watches = listOf("count"),
                propTraces = mapOf("data" to countText),
            ),
            "error" to DevToolsEvent.error(
                message = "HTTP 500 /api/v1/app/counter/page/home",
                stackTrace = """{"error":"boom"}""",
                context = "GET http://localhost:8080/api/v1/app/counter/page/home",
            ),
            "error-fallback-prompt" to DevToolsEvent.fallbackPrompt("Checkbox"),
        )
        val files = Fixtures.files("devtools").map { (name, json) -> name.removeSuffix(".json") to json }
        assertEquals(built.keys, files.map { it.first }.toSet())
        for ((name, fixture) in files) {
            val event = assertNotNull(built[name], name)
            // Through JSON text, as the WebSocket sends it.
            val sent = JsonValue.parse(event.envelope(deviceId = "fixture-device", timestamp = 1_793_980_800_000L).encoded())
            assertJsonEqual(sent, fixture, name)
        }
    }

    /**
     * C19.7: what Dart's toJson leaves out is left out: an empty trace or
     * widget list, a body that is null (a JSON null too, which Dart reads as
     * null), a step's `in` when it has none.
     */
    @Test
    fun c19_7_emptyTracesNullBodiesAndMissingInAreLeftOut() {
        val setState = Action.SetState("count", StateScope.Page, j(1))
        val bare = DevToolsEvent.action(setState, pageId = "home", durationMs = 0.5)
        val empty = DevToolsEvent.action(
            setState,
            pageId = "home",
            durationMs = 0.5,
            transformTrace = emptyList(),
            affectedWidgets = emptyList(),
        )
        assertEquals(bare, empty)
        assertEquals(setOf("actionType", "family", "pageId", "data", "durationMs"), empty.payload.keys)

        val network = DevToolsEvent.network("GET", "http://x", 0, 1.0, requestBody = JsonValue.Null, responseBody = null)
        assertEquals(setOf("method", "url", "statusCode", "durationMs"), network.payload.keys)

        val rebuild = DevToolsEvent.widgetRebuild("1", "Text", listOf("k"), mapOf("data" to listOf(TraceStep("input", null, "x"))))
        assertEquals(obj("data" to listOf(mapOf("op" to "input", "out" to "x"))), rebuild.payload["propTraces"])
    }

    /** Swift `testActionFamiliesFollowDart`. */
    @Test
    fun e2_actionFamiliesFollowDart() {
        val expected = mapOf(
            "setState" to "state", "navigate" to "navigation", "goBack" to "navigation",
            "showSnackbar" to "ui-feedback", "share" to "ui-feedback", "serverAction" to "data",
            "actionGroup" to "lifecycle", "conditionalAction" to "data", "lifecycle" to "lifecycle",
            "addComponent" to "state", "replaceComponent" to "state", "NAVIGATE_HOME" to "navigation",
            "SET_THEME" to "state", "SHOW_MODAL" to "ui-feedback", "FETCH_CART" to "data",
            "somethingElse" to "custom",
        )
        for ((type, family) in expected) {
            assertEquals(family, DevToolsEvent.family(type), type)
        }
    }

    /** Swift `testHeadersAreRedacted`. */
    @Test
    fun e3_headersAreRedacted() {
        assertEquals(
            mapOf(
                "Authorization" to "<redacted>", "Cookie" to "<redacted>", "set-cookie" to "<redacted>",
                "X-Api-Key" to "<redacted>", "Proxy-Authorization" to "<redacted>", "x-orca-caps-hash" to "h",
            ),
            DevToolsEvent.sanitize(
                mapOf(
                    "Authorization" to "Bearer k", "Cookie" to "a", "set-cookie" to "b", "X-Api-Key" to "k",
                    "Proxy-Authorization" to "p", "x-orca-caps-hash" to "h",
                ),
            ),
        )
    }

    /** Swift `testStateChangesDiffBothScopes`. */
    @Test
    fun e4_stateChangesDiffBothScopes() {
        val old = StoreState(page = props("a" to 1, "b" to 2), app = props("cart" to 0))
        val new = StoreState(page = props("a" to 1, "b" to 3, "c" to true), app = emptyMap())
        assertEquals(
            listOf(
                DevToolsEvent.stateChange(StateScope.Page, "p", "b", j(2), j(3)),
                DevToolsEvent.stateChange(StateScope.Page, "p", "c", JsonValue.Null, j(true)),
                DevToolsEvent.stateChange(StateScope.App, "p", "cart", j(0), JsonValue.Null),
            ),
            DevToolsEvent.stateChanges(from = old, to = new, pageId = "p"),
        )
    }

    // Who reports what

    /** Swift `testNothingIsBuiltWithoutAReporter`. */
    @Test
    fun e5_nothingIsBuiltWithoutAReporter() {
        var built = false
        OrcaDebug.report {
            built = true
            DevToolsEvent.error(message = "x")
        }
        assertFalse(built)
        assertFalse(OrcaDebug.isEnabled)
    }
}
