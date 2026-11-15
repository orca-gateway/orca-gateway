package com.orcagateway.sdk

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.CompletableDeferred
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * OrcaApp end to end against a stub engine: the 412 handshake, the device
 * headers filled from this device, the counter drawn and counting, and the
 * error page with its retry.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class OrcaAppTest {
    @get:Rule
    val compose = createComposeRule()

    /** Answers like the engine: 412 to an unknown caps hash, the page to the POST retry. */
    private class StubEngine(var failWith: Int? = null) : HttpTransport {
        val requests = mutableListOf<HttpRequest>()
        private val page = requireNotNull(javaClass.getResource("/pages/counter-home.json")).readBytes()

        override suspend fun send(request: HttpRequest): HttpResponse {
            requests += request
            failWith?.let { return HttpResponse(it, body = """{"error":"boom"}""".toByteArray()) }
            return if (request.method == "GET") {
                HttpResponse(412, body = """{"error":"caps_vector_unknown"}""".toByteArray())
            } else {
                HttpResponse(200, mapOf("content-type" to "application/json"), page)
            }
        }
    }

    private fun client(engine: StubEngine) =
        OrcaClient(URI("http://engine.invalid"), appId = "counter", apiKey = "demo-key", transport = engine)

    @Test
    fun theCounterLoadsThroughTheHandshakeAndCounts() {
        val engine = StubEngine()
        compose.setContent { OrcaApp(client(engine)) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("Counter Example") > 0 }
        compose.onNodeWithText("Counter Example").assertIsDisplayed()
        compose.onNodeWithText("+").performClick()
        compose.onNodeWithText("1").assertIsDisplayed()

        assertEquals(listOf("GET", "POST"), engine.requests.map { it.method })
        val headers = engine.requests.first().headers
        assertEquals("Android", headers["x-orca-platform"])
        assertEquals("393", headers["x-orca-screen-width"])
        assertEquals("2.0", headers["x-orca-pixel-density"])
        assertTrue(engine.requests.first().url.toString().endsWith("/api/v1/app/counter/page/home"))
    }

    @Test
    fun aFailedLoadShowsTheErrorAndRetries() {
        val engine = StubEngine(failWith = 500)
        compose.setContent { OrcaApp(client(engine)) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("Could not load this page") > 0 }
        compose.onNodeWithText("HTTP 500: {\"error\":\"boom\"}").assertIsDisplayed()

        engine.failWith = null
        compose.onNodeWithText("Try again").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("Counter Example") > 0 }
        compose.onNodeWithText("0").assertIsDisplayed()
    }

    // MARK: Boot from the server config (B9.1, B9.5, B9.8)

    @Test
    fun b9_1_bootFetchesTheConfigOnceAndOpensItsInitialRoute() {
        val engine = ConfigEngine(config(initialRoute = "/welcome"))
        compose.setContent { OrcaApp(engine.client, path = null) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("welcome page") > 0 }
        compose.onNodeWithText("welcome page").assertIsDisplayed()

        assertEquals(1, engine.configRequests.size)
        assertEquals(listOf("welcome"), engine.pageRequests)
        // The config is asked for with this device's headers, as a page is.
        assertEquals("Android", engine.configRequests.single().headers["x-orca-platform"])
        assertEquals("393", engine.configRequests.single().headers["x-orca-screen-width"])
    }

    @Test
    fun b9_1_aHostPathSkipsTheConfig() {
        val engine = ConfigEngine(config(initialRoute = "/welcome"))
        val byDefault = ConfigEngine(config(initialRoute = "/welcome"))
        val events = mutableListOf<RouteChangeEvent>()
        var explicit by mutableStateOf(true)
        compose.setContent {
            if (explicit) {
                OrcaApp(engine.client, path = "settings", onRouteChanged = { events += it })
            } else {
                // No path at all: the page `home`, as before the config boot existed.
                OrcaApp(byDefault.client, onRouteChanged = { events += it })
            }
        }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("settings page") > 0 }

        assertEquals(0, engine.configRequests.size)
        assertEquals(listOf("settings"), engine.pageRequests)

        explicit = false
        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("home page") > 0 }

        assertEquals(0, byDefault.configRequests.size)
        assertEquals(listOf("home"), byDefault.pageRequests)

        // The host's listener is on the router: the page's button pushes a route.
        compose.onNodeWithText("Go").performClick()
        compose.waitUntil(5_000) { byDefault.pageRequests == listOf("home", "settings") }
        assertEquals(listOf("/settings"), events.map { it.location })
        assertEquals(0, byDefault.configRequests.size)
    }

    @Test
    fun b9_1_aFailedConfigFetchCanBeRetried() {
        val engine = ConfigEngine(config(initialRoute = "/welcome"), failConfigWith = 500)
        compose.setContent { OrcaApp(engine.client, path = null) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("Could not load this app") > 0 }
        compose.onNodeWithText("HTTP 500: {\"error\":\"boom\"}").assertIsDisplayed()
        assertEquals(emptyList(), engine.pageRequests)

        engine.failConfigWith = null
        compose.onNodeWithText("Try again").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("welcome page") > 0 }
        assertEquals(2, engine.configRequests.size)
        assertEquals(listOf("welcome"), engine.pageRequests)
    }

    @Test
    fun b9_5_initialAppStateIsSeededBeforeTheFirstPageAndSentWithIt() {
        val engine = ConfigEngine(config(initialRoute = "/welcome", initialAppState = """{"loggedIn":false,"cart":2}"""))
        compose.setContent { OrcaApp(engine.client, path = null) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("welcome page") > 0 }

        assertEquals(listOf("welcome"), engine.pageRequests)
        assertEquals(
            JsonValue.Object(mapOf("loggedIn" to JsonValue.Bool(false), "cart" to JsonValue.Int(2))),
            engine.appStateOfPage(0),
        )
    }

    @Test
    fun b9_8_aNonTabRouteHasATopBarWithBackAndTheLiveTitle() {
        val gate = CompletableDeferred<Unit>()
        val engine = ConfigEngine(
            config(initialRoute = "/home", tabs = """[{"id":"home","label":"Home","icon":"home","initialRoute":"/home"}]"""),
            holds = mapOf("settings" to gate),
        )
        compose.setContent { OrcaApp(engine.client, path = null) }
        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("home page") > 0 }
        // A tab's page has no bar.
        assertEquals(0, compose.onAllNodesWithTagCount(ORCA_ROUTE_TITLE_TAG))

        compose.onNodeWithText("Go").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTagCount(ORCA_ROUTE_TITLE_TAG) > 0 }
        // The page is still loading: the fallback title, and a way back.
        compose.onNodeWithTag(ORCA_ROUTE_TITLE_TAG).assertTextEquals("Settings")
        compose.onNodeWithContentDescription("Back").assertIsDisplayed()

        gate.complete(Unit)
        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("settings page") > 0 }
        compose.onNodeWithTag(ORCA_ROUTE_TITLE_TAG).assertTextEquals("Title of settings")

        compose.onNodeWithContentDescription("Back").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTagCount(ORCA_ROUTE_TITLE_TAG) == 0 }
        compose.onNodeWithText("home page").assertIsDisplayed()
        assertEquals(listOf("home", "settings"), engine.pageRequests)
    }

    // MARK: Tabs (B10.1)

    /** B10.1-K: a config boot whose initial route is a tab lands in the tab shell, with its bar. */
    @Test
    fun b10_1_bootingIntoATabShowsTheShell() {
        val tabs = """[{"id":"home","label":"Home","icon":"home","initialRoute":"/home"},""" +
            """{"id":"welcome","label":"Welcome","icon":"star","initialRoute":"/welcome"}]"""
        val engine = ConfigEngine(config(initialRoute = "/home", tabs = tabs))
        compose.setContent { OrcaApp(engine.client, path = null) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("home page") > 0 }
        compose.onNodeWithTag("orca-tab-0").assertIsDisplayed()
        compose.onNodeWithTag("orca-tab-1").assertIsDisplayed()
        compose.onNodeWithText("Welcome").assertIsDisplayed()
        // Only the tab on screen was asked for.
        assertEquals(listOf("home"), engine.pageRequests)

        compose.onNodeWithTag("orca-tab-1").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("welcome page") > 0 }
        compose.onNodeWithText("welcome page").assertIsDisplayed()
        assertEquals(1, engine.configRequests.size)
        assertEquals(listOf("home", "welcome"), engine.pageRequests)
    }

    @Test
    fun aNotFoundRouteRequestsNoPage() {
        val engine = ConfigEngine(config(initialRoute = "/nowhere"))
        compose.setContent { OrcaApp(engine.client, path = null) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("Page not found") > 0 }
        compose.onNodeWithText("/nowhere").assertIsDisplayed()
        compose.waitForIdle()

        assertEquals(1, engine.configRequests.size)
        assertEquals(emptyList(), engine.pageRequests)
    }
}

/** The tag of the top bar's title, as OrcaApp sets it. */
private const val ORCA_ROUTE_TITLE_TAG = "orca-route-title"

/** A `/config` body with the routes `welcome`, `home` and `settings`. */
private fun config(initialRoute: String, initialAppState: String = "{}", tabs: String = "[]"): String =
    """{"initialRoute":"$initialRoute","tabs":$tabs,"initialAppState":$initialAppState,""" +
        """"flows":[{"name":"main","routes":[{"path":"welcome"},{"path":"home"},{"path":"settings"}]}]}"""

/**
 * An engine with a navigation config: `/config` answers [config] (or
 * [failConfigWith]), and page `name` is titled "Title of name" and shows
 * "name page"; `home` also has a "Go" button that navigates to `/settings`.
 * A page in [holds] is answered only once its gate is opened.
 */
private class ConfigEngine(
    private val config: String,
    var failConfigWith: Int? = null,
    private val holds: Map<String, CompletableDeferred<Unit>> = emptyMap(),
) : HttpTransport {
    val requests = mutableListOf<HttpRequest>()

    val configRequests: List<HttpRequest> get() = requests.filter { it.url.path.endsWith("/config") }

    private val pageCalls: List<HttpRequest> get() = requests.filter { "/page/" in it.url.path }

    /** The page paths asked for, in order. */
    val pageRequests: List<String> get() = pageCalls.map { it.url.path.substringAfterLast("/page/") }

    /** The app state page request [index] carried (a POST body), or null for a GET. */
    fun appStateOfPage(index: Int): JsonValue? {
        val request = pageCalls[index]
        val body = request.body ?: return null
        return if (request.method == "POST") JsonValue.parse(body)["appState"] else null
    }

    val client: OrcaClient
        get() = OrcaClient(URI("http://engine.invalid"), appId = "navigation", transport = this)

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests += request
        val path = request.url.path
        if (path.endsWith("/config")) {
            failConfigWith?.let { return HttpResponse(it, body = """{"error":"boom"}""".toByteArray()) }
            return HttpResponse(200, mapOf("content-type" to "application/json"), config.toByteArray())
        }
        val name = path.substringAfterLast("/page/")
        holds[name]?.await()
        val nodes: List<ComponentNode> = if (name == "home") {
            val go = Action.Navigate(route = JsonValue.String("/settings"))
            listOf(
                ComponentNode("c", "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, emptyMap(), listOf("t", "b")),
                text("t", "home page"),
                button("b", "TextButton", "l", mapOf("onTap" to go)),
                text("l", "Go"),
            )
        } else {
            listOf(text("0", "$name page"))
        }
        val page = PageResponse(pageId = name, title = "Title of $name", state = emptyList(), components = nodes)
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }
}

private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithTextCount(text: String): Int =
    onAllNodes(androidx.compose.ui.test.hasText(text)).fetchSemanticsNodes().size

private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithTagCount(tag: String): Int =
    onAllNodes(androidx.compose.ui.test.hasTestTag(tag)).fetchSemanticsNodes().size
