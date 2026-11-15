package com.orcagateway.sdk

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.navigation.NavBackStackEntry
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.sdk.navigation.LocalOrcaNavigation
import com.orcagateway.sdk.navigation.OrcaNavigation
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import com.orcagateway.sdk.system.SystemActions
import kotlinx.coroutines.CompletableDeferred
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNotSame
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * OrcaApp end to end against a stub engine: the 412 handshake, the device
 * headers filled from this device, the counter drawn and counting, and the
 * error page with its retry. Then A1.13: the page stack through an activity
 * recreated by a rotation, and what a page knows of the stack it is on.
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

    // MARK: A1.13 the page stack through a recreation, and what a page knows of it

    /** Pages by path: `home` has a Go button that pushes `about`; any other page is one Text of its name. */
    private class PathPages : HttpTransport {
        val requests = mutableListOf<String>()

        override suspend fun send(request: HttpRequest): HttpResponse {
            val name = request.url.path.substringAfterLast("/page/")
            requests += name
            val go = Action.Navigate(route = JsonValue.String("/about"))
            val nodes = if (name == "home") {
                listOf(button("0", "TextButton", "1", mapOf("onTap" to go)), text("1", "Go"))
            } else {
                listOf(text("0", name))
            }
            val page = PageResponse(pageId = name, title = name, components = nodes)
            return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
        }

        val client: OrcaClient
            get() = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", device = DeviceInfo(osVersion = "test"), transport = this)
    }

    /** What a Text saw the last time it was drawn: its page's navigation, its NavHost entry, its page. */
    private class Seen(val navigation: OrcaNavigation, val entry: String?, val model: OrcaPageModel)

    private val seen = HashMap<String, Seen>()
    private val plainText = checkNotNull(WidgetBuilders.shared["Text"])

    /** From now on every Text drawn records what it saw in [seen], by its data. */
    private fun probe() {
        WidgetBuilders.shared.register("Text") { node, model, modifier ->
            val entry = LocalViewModelStoreOwner.current as? NavBackStackEntry
            node["data"]?.stringValue?.let { seen[it] = Seen(LocalOrcaNavigation.current, entry?.id, model) }
            plainText(node, model, modifier)
        }
    }

    @After
    fun putTextBack() {
        WidgetBuilders.shared.register("Text", plainText)
        HostActivity.content = {}
    }

    /** An app's activity, set up and resumed: its onCreate shows [content], made again by a recreation. */
    private fun host(content: @Composable () -> Unit): ActivityController<HostActivity> {
        HostActivity.content = content
        return Robolectric.buildActivity(HostActivity::class.java).setup()
    }

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    /**
     * A1.13 (kt): an activity recreated by a rotation, with no router of the
     * host's, still shows the pushed page: the same page (not fetched again)
     * on the same NavHost entry (no pop to the root and push), and back
     * returns home.
     */
    @Test
    fun a1_13_kt_aPushedPageSurvivesARecreationAndBackReturnsHome() {
        probe()
        val pages = PathPages()
        val activity = host { OrcaApp(pages.client) }
        compose.waitUntil(5_000) { count("Go") > 0 }
        compose.onNodeWithText("Go").performClick()
        compose.waitUntil(5_000) { count("about") > 0 }
        compose.waitForIdle()
        val before = seen.getValue("about")
        seen.clear()

        activity.recreate()
        compose.waitForIdle()
        compose.onNodeWithText("about").assertIsDisplayed()
        val after = seen.getValue("about")
        assertSame(before.model, after.model)
        assertEquals(before.entry, after.entry)
        assertEquals(listOf("home", "about"), pages.requests)

        compose.runOnIdle { activity.get().onBackPressedDispatcher.onBackPressed() }
        compose.waitUntil(5_000) { count("about") == 0 }
        compose.onNodeWithText("Go").assertIsDisplayed()
        assertEquals(listOf("home", "about"), pages.requests)
    }

    /**
     * A1.13 (kt): OrcaApp(client)'s router is the same object after a
     * recreation, its pages not closed, and the new activity's system
     * actions replace the old one's; it is closed once the activity finishes.
     */
    @Test
    fun a1_13_kt_theRouterOutlivesARecreationAndClosesWhenTheActivityFinishes() {
        probe()
        val activity = host { OrcaApp(PathPages().client) }
        compose.waitUntil(5_000) { count("Go") > 0 }
        compose.waitForIdle()
        val router = checkNotNull(seen.getValue("Go").navigation.router)
        val home = router.loader(router.root)
        val firstSystem = assertNotNull(router.system)

        activity.recreate()
        compose.waitUntil(5_000) { count("Go") > 0 }
        compose.waitForIdle()
        assertSame(router, seen.getValue("Go").navigation.router)
        assertSame(home, router.loader(router.root))
        assertNotNull(router.system)
        assertNotSame(firstSystem, router.system)

        activity.get().finish()
        activity.pause().stop().destroy()
        assertNotSame(home, router.loader(router.root)) // closed: the pages it held are gone
        assertNull(router.system)
    }

    /**
     * A1.13 (kt): system actions the host passes (they may hold the activity)
     * are the router's only while that activity shows it: a recreated
     * activity's own replace them, and none are left once it finishes.
     */
    @Test
    fun a1_13_kt_aHostsSystemActionsAreTheRoutersOnlyWhileShown() {
        probe()
        val made = mutableListOf<SystemActions>()
        val activity = host {
            val own = remember { SystemActions(open = {}, copy = {}, share = { _, _ -> }).also { made += it } }
            OrcaApp(PathPages().client, system = own)
        }
        compose.waitUntil(5_000) { count("Go") > 0 }
        val router = checkNotNull(seen.getValue("Go").navigation.router)
        assertSame(made.single(), router.system)

        activity.recreate()
        compose.waitUntil(5_000) { count("Go") > 0 }
        compose.waitForIdle()
        assertEquals(2, made.size)
        assertSame(router, seen.getValue("Go").navigation.router)
        assertSame(made.last(), router.system)

        activity.get().finish()
        activity.pause().stop().destroy()
        assertNull(router.system)
    }

    /** A1.13 (kt): two OrcaApp(client) in one activity keep a router each, through a recreation. */
    @Test
    fun a1_13_kt_twoAppsInOneActivityKeepARouterEach() {
        probe()
        val pages = PathPages()
        val activity = host {
            Column {
                Box(Modifier.weight(1f)) { OrcaApp(pages.client, path = "left") }
                Box(Modifier.weight(1f)) { OrcaApp(pages.client, path = "right") }
            }
        }
        compose.waitUntil(5_000) { count("left") > 0 && count("right") > 0 }

        activity.recreate()
        compose.waitUntil(5_000) { count("left") > 0 && count("right") > 0 }
        compose.waitForIdle()
        val left = assertNotNull(seen.getValue("left").navigation.router)
        assertNotSame(left, seen.getValue("right").navigation.router)
        assertEquals(listOf("left", "right"), pages.requests.sorted())
    }

    /**
     * A1.13 (kt): OrcaApp(client, path = null) keeps its boot through a
     * recreation: the pushed page stays, `/config` is fetched once and no
     * page again, and route changes go to the shown activity's listener.
     */
    @Test
    fun a1_13_kt_aConfigBootKeepsThePushedPageThroughARecreationAndFetchesTheConfigOnce() {
        val engine = ConfigEngine(config(initialRoute = "/home"))
        val events = mutableListOf<String>()
        var made = 0
        val activity = host {
            val activityNo = remember { ++made }
            OrcaApp(engine.client, path = null, onRouteChanged = { events += "$activityNo ${it.location}" })
        }
        compose.waitUntil(5_000) { count("Go") > 0 }
        compose.onNodeWithText("Go").performClick()
        compose.waitUntil(5_000) { count("settings page") > 0 }

        activity.recreate()
        compose.waitForIdle()
        compose.onNodeWithText("settings page").assertIsDisplayed()
        assertEquals(1, engine.configRequests.size)
        assertEquals(listOf("home", "settings"), engine.pageRequests)

        compose.runOnIdle { activity.get().onBackPressedDispatcher.onBackPressed() }
        compose.waitUntil(5_000) { count("settings page") == 0 }
        compose.onNodeWithText("home page").assertIsDisplayed()
        assertEquals(listOf("home", "settings"), engine.pageRequests)
        assertEquals(listOf("1 /home", "1 /settings", "2 /home"), events)
    }

    /**
     * A1.13 (kt): a router the host keeps across the recreation behaves the
     * same: the NavHost keeps the entries it restored (no pop to the root and
     * push), the page under the top one too.
     */
    @Test
    fun a1_13_kt_aHostRouterKeepsTheRestoredEntriesThroughARecreation() {
        probe()
        val router = OrcaRouter(PathPages().client)
        val activity = host { OrcaApp(router) }
        compose.waitUntil(5_000) { count("Go") > 0 }
        compose.runOnIdle { router.navigate("about") }
        compose.waitUntil(5_000) { count("about") > 0 }
        compose.runOnIdle { router.navigate("third") }
        compose.waitUntil(5_000) { count("third") > 0 }
        compose.waitForIdle()
        val about = seen.getValue("about").entry
        val third = seen.getValue("third").entry
        seen.clear()

        activity.recreate()
        compose.waitUntil(5_000) { count("third") > 0 }
        compose.waitForIdle()
        assertEquals(third, seen.getValue("third").entry)

        compose.runOnIdle { router.goBack() }
        compose.waitUntil(5_000) { count("third") == 0 }
        compose.waitForIdle()
        assertEquals(about, seen.getValue("about").entry)
        assertEquals(listOf("about"), router.stack.map { it.path })
    }

    /** D6 (provider): the root cannot pop; a pushed page can, and its goBack pops the router. */
    @Test
    fun a1_13_kt_aPushedPageCanPopAndTheRootCannot() {
        probe()
        val router = OrcaRouter(PathPages().client)
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { count("Go") > 0 }
        assertFalse(seen.getValue("Go").navigation.canPop)

        compose.onNodeWithText("Go").performClick()
        compose.waitUntil(5_000) { count("about") > 0 }
        val about = seen.getValue("about").navigation
        assertTrue(about.canPop)
        assertSame(router, about.router)

        compose.runOnIdle { about.goBack() }
        compose.waitUntil(5_000) { count("about") == 0 }
        assertEquals(emptyList(), router.stack)
    }

    /** D6 (provider): a page shown outside OrcaApp cannot pop, and its goBack does nothing. */
    @Test
    fun a1_13_kt_aPageOutsideOrcaAppCannotPop() {
        probe()
        compose.setContent { OrcaPageView(OrcaPageModel(page(text("0", "alone")))) }
        compose.waitUntil(5_000) { count("alone") > 0 }
        val alone = seen.getValue("alone").navigation
        assertFalse(alone.canPop)
        assertNull(alone.router)
        alone.goBack()
    }
}

/** An app's activity: its onCreate shows [content], as `setContent { OrcaApp(client) }` does in an app. */
class HostActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { content() }
    }

    companion object {
        var content: @Composable () -> Unit = {}
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
