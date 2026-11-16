package com.orcagateway.sdk

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.navigation.DeeplinkEvent
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import java.io.File
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Deep links (plan step 11, cases L2 to L6 of the design brief) on the
 * config of schema/fixtures/navigation/15_deep_links.json: tabs `home` and
 * `search`, `settings`, `login`, `order/:id`, `home/product/:id`, and
 * `account`, which redirects to `/login` while `loggedIn` is false.
 *
 * At the router ([OrcaRouter.handleDeeplink], [OrcaRouter.handleIntent]) and
 * in an activity: the launch Intent (cold), a new Intent (warm), a
 * recreation and a restore from saved state.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class DeeplinkTest {
    @get:Rule
    val compose = createComposeRule()

    /** Route changes and links, in the order the host heard of them. */
    private val log = mutableListOf<String>()
    private val events = mutableListOf<DeeplinkEvent>()

    private val onLink: (DeeplinkEvent) -> Unit = {
        events += it
        log += "link ${it.resolvedLocation}"
    }

    @After
    fun emptyTheHost() {
        HostActivity.content = {}
    }

    private fun view(link: String) = Intent(Intent.ACTION_VIEW, Uri.parse(link))

    /** An app's activity, launched by [intent] (the launcher's when null), showing [content]. */
    private fun host(intent: Intent? = null, content: @Composable () -> Unit): ActivityController<HostActivity> {
        HostActivity.content = content
        return Robolectric.buildActivity(HostActivity::class.java, intent).setup()
    }

    /** The app as a host writes it: `OrcaApp(client)` with both callbacks. */
    private fun app(engine: LinkEngine, intent: Intent? = null, path: String? = null): ActivityController<HostActivity> =
        host(intent) {
            OrcaApp(engine.client, path = path, onRouteChanged = { log += "route ${it.location}" }, onDeeplink = onLink)
        }

    /** A router for the fixture's config, shown at [startAt], that logs like [app]. */
    private fun router(engine: LinkEngine, startAt: String? = null): OrcaRouter {
        val config = runBlocking { engine.client.fetchConfig() }
        val router = OrcaRouter(engine.client, config)
        if (startAt != null) router.navigate(startAt, replace = true)
        router.onRouteChanged = { log += "route ${it.location}" }
        router.onDeeplink = onLink
        return router
    }

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    private fun shows(text: String) {
        compose.waitUntil(5_000) { count(text) > 0 }
    }

    // MARK: B11.2 the router: a link is a go, and the event comes after the route change (L2, L6)

    @Test
    fun b11_2_aWarmLinkIsAGoAndTheEventComesOnceAfterTheRouteChange() {
        val router = router(LinkEngine())

        router.handleDeeplink("https://shop.example/settings?tab=2&ref=mail#top")

        assertEquals(listOf("route /settings?tab=2&ref=mail", "link /settings?tab=2&ref=mail"), log)
        assertEquals(
            DeeplinkEvent(
                incoming = "https://shop.example/settings?tab=2&ref=mail#top",
                resolvedLocation = "/settings?tab=2&ref=mail",
                pathParameters = emptyMap(),
                queryParameters = mapOf("tab" to "2", "ref" to "mail"),
                wasRedirected = false,
                isColdStart = false,
            ),
            events.single(),
        )
        // A go: the route is the only page, outside the tabs.
        assertEquals("settings", router.root.path)
        assertEquals(emptyList(), router.stack)
        assertFalse(router.hasShell)
    }

    @Test
    fun b11_2_aLinkIntoATabSelectsTheTabAndANestedRouteComesOverItsParent() {
        val router = router(LinkEngine(), startAt = "/settings")

        router.handleDeeplink("https://shop.example/search")
        assertEquals(1, router.currentTab)
        assertEquals("/search", router.top.location)

        router.handleDeeplink("orcashop://open/home/product/42")
        assertEquals(0, router.currentTab)
        assertEquals(listOf("home", "home/product/42"), (listOf(router.root) + router.stack).map { it.path })
        assertEquals(mapOf("id" to "42"), events.last().pathParameters)
        assertEquals(listOf("route /search", "link /search", "route /home/product/42", "link /home/product/42"), log)
    }

    @Test
    fun b11_2_aLinkToTheLocationOnScreenNavigatesNowhereAndStillCallsBack() {
        val router = router(LinkEngine(), startAt = "/settings")
        val top = router.top

        router.handleDeeplink("https://shop.example/settings")
        router.handleDeeplink("/settings")

        assertEquals(listOf("link /settings", "link /settings"), log)
        assertTrue(top === router.top)
        assertEquals(listOf(false, false), events.map { it.wasRedirected })
    }

    @Test
    fun b11_2_inPathModeEveryPathIsAPage() {
        val router = OrcaRouter(LinkEngine().client, "home")
        router.onRouteChanged = { log += "route ${it.location}" }
        router.onDeeplink = onLink

        router.handleDeeplink("orcashop://open/settings?tab=2")

        assertEquals(listOf("route /settings?tab=2", "link /settings?tab=2"), log)
        assertEquals("settings", router.root.path)
        assertEquals(emptyList(), router.stack)
        assertEquals(mapOf("tab" to "2"), events.single().queryParameters)
        assertFalse(events.single().wasRedirected)

        // The location on screen: no navigation, the callback fires.
        val root = router.root
        router.handleDeeplink("https://shop.example/settings?tab=2")
        assertTrue(root === router.root)
        assertEquals(listOf("route /settings?tab=2", "link /settings?tab=2", "link /settings?tab=2"), log)
    }

    @Test
    fun b11_2_inPathModeAQueryMarkBeforeACombiningCharStillEndsThePagePath() {
        val engine = LinkEngine()
        val router = OrcaRouter(engine.client, "home")
        router.handleDeeplink("orcashop://open/a?\u0301x=1")
        assertEquals("a", router.root.path)
        assertEquals("/a?\u0301x=1", router.root.location)
    }

    @Test
    fun b11_2_inPathModeTheQueryIsDecodedAsWithAConfig() {
        val link = "https://shop.example/settings?q=%FF&name=a+b%20c&caf%C3%A9=1"
        router(LinkEngine()).handleDeeplink(link)
        val path = OrcaRouter(LinkEngine().client, "home")
        path.onDeeplink = onLink
        path.handleDeeplink(link)

        // Not valid UTF-8: the text stays as it is, no U+FFFD.
        assertEquals(mapOf("q" to "%FF", "name" to "a b c", "caf\u00e9" to "1"), events[0].queryParameters)
        assertEquals(events[0].queryParameters, events[1].queryParameters)
        assertEquals("/settings?q=%FF&name=a+b%20c&caf%C3%A9=1", events[1].resolvedLocation)
        assertEquals(emptyMap(), events[1].pathParameters)
        assertFalse(events[1].wasRedirected)
        assertEquals("settings", path.root.path)
        assertFalse(path.root.isNotFound)
    }

    @Test
    fun b11_2_handleIntentTakesTheLinkOfAViewIntentOnly() {
        val router = router(LinkEngine())

        assertTrue(router.handleIntent(view("https://shop.example/order/7?gift=1")))
        assertEquals("/order/7?gift=1", router.top.location)
        assertEquals(mapOf("id" to "7"), events.single().pathParameters)
        assertEquals(mapOf("gift" to "1"), events.single().queryParameters)
        assertFalse(events.single().isColdStart)

        assertFalse(router.handleIntent(Intent(Intent.ACTION_MAIN)))
        assertFalse(router.handleIntent(Intent(Intent.ACTION_SEND, Uri.parse("https://shop.example/settings"))))
        assertEquals(1, events.size)
        assertEquals("/order/7?gift=1", router.top.location)
    }

    // MARK: B11.3 a protected route (L3)

    @Test
    fun b11_3_aProtectedRouteWhileLoggedOutIsRedirectedAndTheAskedQueryDropped() {
        val router = router(LinkEngine())

        router.handleDeeplink("https://shop.example/account?from=mail")

        assertEquals(listOf("route /login", "link /login"), log)
        val event = events.single()
        assertEquals("/login", event.resolvedLocation)
        assertEquals(emptyMap(), event.queryParameters)
        assertTrue(event.wasRedirected)
        assertFalse(event.isColdStart)

        // Logged in, the same link is not redirected and keeps its query.
        router.setAppState("loggedIn", JsonValue.Bool(true))
        router.handleDeeplink("https://shop.example/account?from=mail")
        assertEquals("/account?from=mail", events.last().resolvedLocation)
        assertEquals(mapOf("from" to "mail"), events.last().queryParameters)
        assertFalse(events.last().wasRedirected)
    }

    @Test
    fun b11_3_aColdLinkToAProtectedRouteBootsAtTheRedirectTarget() {
        val engine = LinkEngine()
        app(engine, view("https://shop.example/account?from=mail"))
        shows("login page")
        compose.waitForIdle()

        assertEquals(listOf("login"), engine.pageRequests)
        assertEquals(listOf("route /login", "link /login"), log)
        val event = events.single()
        assertEquals("https://shop.example/account?from=mail", event.incoming)
        assertEquals(emptyMap(), event.queryParameters)
        assertTrue(event.wasRedirected)
        assertTrue(event.isColdStart)
        // The redirect read the config's initial app state, which the page request carries.
        assertEquals(JsonValue.Bool(false), engine.appStateOfPage(0)?.get("loggedIn"))
    }

    @Test
    fun b11_3_aWarmLinkToAProtectedRouteIsRedirectedInTheApp() {
        val engine = LinkEngine()
        val activity = app(engine)
        shows("home page")

        activity.newIntent(view("https://shop.example/account?from=mail"))
        shows("login page")

        assertEquals(listOf("home", "login"), engine.pageRequests)
        assertEquals(listOf("route /home", "route /login", "link /login"), log)
        assertTrue(events.single().wasRedirected)
        assertFalse(events.single().isColdStart)
    }

    // MARK: B11.4 an unknown link (L4)

    @Test
    fun b11_4_anUnknownLinkShowsNotFoundRequestsNothingAndTheButtonGoesHome() {
        val engine = LinkEngine()
        val activity = app(engine)
        shows("home page")

        activity.newIntent(view("https://shop.example/nowhere?x=1"))
        shows("Page not found")
        compose.onNodeWithText("/nowhere?x=1").assertIsDisplayed()
        compose.waitForIdle()

        assertEquals(listOf("home"), engine.pageRequests)
        val event = events.single()
        assertEquals("/nowhere?x=1", event.resolvedLocation)
        assertEquals(emptyMap(), event.pathParameters)
        assertEquals(mapOf("x" to "1"), event.queryParameters)
        assertFalse(event.wasRedirected)
        assertFalse(event.isColdStart)

        // Flutter's default screen: the button is a go to "/" (no route of this config, so not found again).
        compose.onNodeWithText("Go to home page").performClick()
        compose.waitUntil(5_000) { log.last() == "route /" }
        compose.onNodeWithText("/").assertIsDisplayed()
        assertEquals(listOf("route /home", "route /nowhere?x=1", "link /nowhere?x=1", "route /"), log)
        assertEquals(listOf("home"), engine.pageRequests)
    }

    @Test
    fun b11_4_aColdUnknownLinkBootsAtNotFoundAndRequestsNoPage() {
        val engine = LinkEngine()
        app(engine, view("https://shop.example/nowhere?x=1"))
        shows("Page not found")
        compose.waitForIdle()

        assertEquals(1, engine.configRequests.size)
        assertEquals(emptyList(), engine.pageRequests)
        assertEquals(listOf("route /nowhere?x=1", "link /nowhere?x=1"), log)
        assertFalse(events.single().wasRedirected)
        assertTrue(events.single().isColdStart)
    }

    // MARK: B11.1 the activity: the launch Intent, new Intents, a recreation (L5, L2, L6)

    @Test
    fun b11_1_aColdLinkBootsTheRouterAtItWithOnePageRequestAndIsNotHandledAgainAfterARecreation() {
        val engine = LinkEngine()
        val activity = app(engine, view("https://shop.example/settings?tab=2"))
        shows("settings page")
        compose.waitForIdle()

        assertEquals(1, engine.configRequests.size)
        // The initial route's page was never asked for.
        assertEquals(listOf("settings"), engine.pageRequests)
        assertEquals(listOf("route /settings?tab=2", "link /settings?tab=2"), log)
        assertEquals(
            DeeplinkEvent(
                incoming = "https://shop.example/settings?tab=2",
                resolvedLocation = "/settings?tab=2",
                pathParameters = emptyMap(),
                queryParameters = mapOf("tab" to "2"),
                wasRedirected = false,
                isColdStart = true,
            ),
            events.single(),
        )

        activity.recreate()
        compose.waitForIdle()
        compose.onNodeWithText("settings page").assertIsDisplayed()
        activity.recreate()
        compose.waitForIdle()

        assertEquals(1, events.size)
        assertEquals(listOf("route /settings?tab=2", "link /settings?tab=2"), log)
        assertEquals(listOf("settings"), engine.pageRequests)
        assertEquals(1, engine.configRequests.size)
    }

    @Test
    fun b11_1_aColdLinkToANestedRouteRequestsTheChildOverItsParentInTheTab() {
        val engine = LinkEngine()
        app(engine, view("orcashop://open/home/product/42"))
        shows("home/product/42 page")
        compose.waitForIdle()

        compose.onNodeWithTag("orca-tab-0").assertIsDisplayed()
        // The parent page is requested when it is first shown (the SDK's lazy rule, as for a `go`).
        assertEquals(listOf("home/product/42"), engine.pageRequests)
        assertEquals(mapOf("id" to "42"), events.single().pathParameters)
        assertTrue(events.single().isColdStart)
    }

    @Test
    fun b11_1_aColdLinkIsNotHandledAgainWhenTheActivityIsRestoredFromSavedState() {
        val engine = LinkEngine()
        val intent = view("https://shop.example/settings")
        val activity = app(engine, intent)
        shows("settings page")
        compose.waitForIdle()
        assertEquals(1, events.size)

        // The process died: a new activity, the same Intent, the saved state, no kept router.
        val state = Bundle()
        activity.saveInstanceState(state).pause().stop().destroy()
        // HostActivity shows the same content, so what it saved is found again.
        Robolectric.buildActivity(HostActivity::class.java, intent).setup(state)
        shows("home page")
        compose.waitForIdle()

        assertEquals(1, events.size)
        assertEquals(listOf("route /settings", "link /settings", "route /home"), log)
    }

    @Test
    fun b11_1_aColdLinkIsNotHandledAgainWhenOrcaAppIsHiddenAndShownInTheSameActivity() {
        val engine = LinkEngine()
        val show = mutableStateOf(true)
        val activity = host(view("https://shop.example/settings?tab=2")) {
            if (show.value) {
                OrcaApp(engine.client, onRouteChanged = { log += "route ${it.location}" }, onDeeplink = onLink)
            }
        }
        shows("settings page")
        activity.newIntent(view("https://shop.example/search"))
        shows("search page")
        compose.waitForIdle()
        val before = listOf("route /settings?tab=2", "link /settings?tab=2", "route /search", "link /search")
        assertEquals(before, log)

        // The boot stays with the activity; what OrcaApp saved while composed does not.
        show.value = false
        compose.waitForIdle()
        assertEquals(0, count("search page"))
        show.value = true
        shows("search page")
        compose.waitForIdle()

        assertEquals(before, log)
        assertEquals(2, events.size)
        assertEquals(listOf("settings", "search"), engine.pageRequests)
        assertEquals(1, engine.configRequests.size)
    }

    @Test
    fun b11_1_anActivityBroughtBackFromRecentsDoesNotHandleItsOldLink() {
        val engine = LinkEngine()
        app(engine, view("https://shop.example/settings").addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY))
        shows("home page")
        compose.waitForIdle()

        assertEquals(emptyList(), events)
        assertEquals(listOf("home"), engine.pageRequests)
    }

    @Test
    fun b11_1_aLinkThatArrivesDuringTheConfigFetchIsHeldAndOpensTheApp() {
        val gate = CompletableDeferred<Unit>()
        val engine = LinkEngine(configGate = gate)
        val activity = app(engine)
        compose.waitUntil(5_000) { engine.configRequests.isNotEmpty() }

        activity.newIntent(view("https://shop.example/settings?tab=2"))
        compose.waitForIdle()
        assertEquals(emptyList(), log)

        gate.complete(Unit)
        shows("settings page")
        compose.waitForIdle()

        assertEquals(1, engine.configRequests.size)
        assertEquals(listOf("settings"), engine.pageRequests)
        assertEquals(listOf("route /settings?tab=2", "link /settings?tab=2"), log)
        // It arrived before the router showed its first route: it is what opened the app.
        assertTrue(events.single().isColdStart)
    }

    @Test
    fun b11_1_aColdLinkSurvivesAFailedConfigFetch() {
        val engine = LinkEngine(failConfigWith = 500)
        app(engine, view("https://shop.example/settings"))
        // Step 18's boot error screen (C18.2): OrcaErrorInfo's words for a 500.
        shows("Server Error")
        assertEquals(emptyList(), events)

        engine.failConfigWith = null
        compose.onNodeWithText("Try again").performClick()
        shows("settings page")
        compose.waitForIdle()

        assertEquals(listOf("settings"), engine.pageRequests)
        assertEquals(listOf("route /settings", "link /settings"), log)
        assertTrue(events.single().isColdStart)
    }

    @Test
    fun b11_1_aColdLinkInPathModeReplacesTheHostsPath() {
        val engine = LinkEngine()
        val activity = app(engine, view("orcashop://open/settings?tab=2"), path = "home")
        shows("settings page")
        compose.waitForIdle()

        assertEquals(0, engine.configRequests.size)
        assertEquals(listOf("settings"), engine.pageRequests)
        assertEquals(listOf("link /settings?tab=2"), log)
        val event = events.single()
        assertEquals("orcashop://open/settings?tab=2", event.incoming)
        assertEquals(mapOf("tab" to "2"), event.queryParameters)
        assertFalse(event.wasRedirected)
        assertTrue(event.isColdStart)

        activity.recreate()
        compose.waitForIdle()
        compose.onNodeWithText("settings page").assertIsDisplayed()
        assertEquals(1, events.size)
        assertEquals(listOf("settings"), engine.pageRequests)

        // A new Intent is a warm link, in path mode too.
        activity.newIntent(view("orcashop://open/search"))
        shows("search page")
        assertEquals(listOf("settings", "search"), engine.pageRequests)
        assertEquals(listOf("link /settings?tab=2", "route /search", "link /search"), log)
        assertFalse(events.last().isColdStart)
    }

    @Test
    fun b11_1_aNewIntentIsAWarmLinkAndStillIsAfterARecreation() {
        val engine = LinkEngine()
        val activity = app(engine)
        shows("home page")

        activity.newIntent(view("https://shop.example/search"))
        shows("search page")
        compose.onNodeWithTag("orca-tab-1").assertIsDisplayed()
        assertEquals(listOf("home", "search"), engine.pageRequests)
        assertEquals(listOf("route /home", "route /search", "link /search"), log)
        assertFalse(events.single().isColdStart)

        // An Intent that carries no link is not one.
        activity.newIntent(Intent(Intent.ACTION_MAIN))
        compose.waitForIdle()
        assertEquals(1, events.size)

        // The recreated activity listens, and the old one's listener is gone: one event per link.
        activity.recreate()
        compose.waitForIdle()
        activity.newIntent(view("https://shop.example/settings"))
        shows("settings page")
        compose.waitForIdle()
        assertEquals(2, events.size)
        assertEquals(listOf("home", "search", "settings"), engine.pageRequests)
    }

    @Test
    fun b11_1_withTabsALinkToANonTabRouteLeavesTheShellForATitledPage() {
        val engine = LinkEngine()
        val activity = app(engine)
        shows("home page")
        compose.onNodeWithTag("orca-tab-0").assertIsDisplayed()

        activity.newIntent(view("https://shop.example/settings"))
        shows("settings page")
        compose.waitForIdle()

        assertEquals(0, compose.onAllNodes(hasTestTag("orca-tab-0")).fetchSemanticsNodes().size)
        compose.onNodeWithTag("orca-route-title").assertTextEquals("Title of settings")
        assertEquals(listOf("home", "settings"), engine.pageRequests)
    }

    @Test
    fun b11_1_aLinkToTheLocationOnScreenRequestsNothingInTheApp() {
        val engine = LinkEngine()
        val activity = app(engine)
        shows("home page")

        activity.newIntent(view("https://shop.example/home/"))
        compose.waitForIdle()

        compose.onNodeWithText("home page").assertIsDisplayed()
        assertEquals(listOf("home"), engine.pageRequests)
        assertEquals(listOf("route /home", "link /home"), log)
        assertFalse(events.single().wasRedirected)
    }

    @Test
    fun b11_1_aHostsRouterGetsTheLaunchLinkOnceAndNewIntents() {
        val engine = LinkEngine()
        val router = router(engine)
        val activity = host(view("https://shop.example/settings?tab=2")) { OrcaApp(router) }
        shows("settings page")
        compose.waitForIdle()

        // Handled before the first page was drawn: the initial route's page was not asked for.
        assertEquals(listOf("settings"), engine.pageRequests)
        assertEquals(listOf("route /settings?tab=2", "link /settings?tab=2"), log)
        assertTrue(events.single().isColdStart)

        activity.recreate()
        compose.waitForIdle()
        assertEquals(1, events.size)

        activity.newIntent(view("https://shop.example/search"))
        shows("search page")
        assertEquals(1, router.currentTab)
        assertEquals(2, events.size)
        assertFalse(events.last().isColdStart)
        assertEquals(listOf("settings", "search"), engine.pageRequests)
    }

    @Test
    fun b11_1_aHostsRouterDoesNotGetTheLaunchLinkAgainWhenOrcaAppIsHiddenAndShownInTheSameActivity() {
        val engine = LinkEngine()
        val router = router(engine)
        val show = mutableStateOf(true)
        val activity = host(view("https://shop.example/settings?tab=2")) {
            if (show.value) OrcaApp(router)
        }
        shows("settings page")
        activity.newIntent(view("https://shop.example/search"))
        shows("search page")
        compose.waitForIdle()
        val before = listOf("route /settings?tab=2", "link /settings?tab=2", "route /search", "link /search")
        assertEquals(before, log)

        // The router stays with the host; what OrcaApp saved while composed does not.
        show.value = false
        compose.waitForIdle()
        assertEquals(0, count("search page"))
        show.value = true
        shows("search page")
        compose.waitForIdle()

        assertEquals(before, log)
        assertEquals(2, events.size)
        assertEquals(listOf("settings", "search"), engine.pageRequests)
    }

    /** Previews and tests draw OrcaApp with no link in the launch Intent: nothing is handled. */
    @Test
    fun b11_1_withoutALinkTheAppBootsAtTheInitialRoute() {
        val engine = LinkEngine()
        compose.setContent { OrcaApp(engine.client, onDeeplink = onLink) }
        shows("home page")
        compose.waitForIdle()

        assertEquals(emptyList(), events)
        assertEquals(listOf("home"), engine.pageRequests)
    }
}

/** The `config` of schema/fixtures/navigation/15_deep_links.json, as `/config` answers it. */
private val fixtureConfig: String by lazy {
    val file = File(System.getProperty("orca.repoRoot"), "schema/fixtures/navigation/15_deep_links.json")
    Json.parseToJsonElement(file.readText()).jsonObject.getValue("config").toString()
}

/**
 * An engine with a navigation config: `/config` answers [config] (or
 * [failConfigWith], and only once [configGate] is opened), and page `name`
 * is titled "Title of name" and shows "name page".
 */
private class LinkEngine(
    private val config: String = fixtureConfig,
    var failConfigWith: Int? = null,
    private val configGate: CompletableDeferred<Unit>? = null,
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
            configGate?.await()
            failConfigWith?.let { return HttpResponse(it, body = """{"error":"boom"}""".toByteArray()) }
            return HttpResponse(200, mapOf("content-type" to "application/json"), config.toByteArray())
        }
        val name = path.substringAfterLast("/page/")
        val page = PageResponse(pageId = name, title = "Title of $name", state = emptyList(), components = listOf(text("0", "$name page")))
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }
}
