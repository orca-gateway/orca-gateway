package com.orcagateway.sdk.navigation

import android.content.ClipboardManager
import android.content.Context
import androidx.activity.ComponentActivity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.DrawerItemDef
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.RedirectRule
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.models.TabDef
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.core.navigation.RouteChangeType
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.text
import com.orcagateway.sdk.system.SystemActions
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNotSame
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * Pages by path and the `/action` route, for router tests (Swift's
 * `PageStub`): a page is `{pageId, title, state, components}` with one Text
 * node unless [nodes] gives it others, and every request is kept so a test
 * can read the app state a fetch carried. A page in [holds] is answered only
 * once its gate is opened.
 */
private class PageStub(
    private val state: Map<String, List<StateDefinition>> = emptyMap(),
    private val nodes: Map<String, List<ComponentNode>> = emptyMap(),
    private val holds: Map<String, CompletableDeferred<Unit>> = emptyMap(),
) : HttpTransport {
    val requests = mutableListOf<HttpRequest>()

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests += request
        val path = request.url.path
        if (path.endsWith("/action")) return HttpResponse(200, body = """{"actions":[]}""".encodeToByteArray())
        val name = path.substringAfterLast("/page/")
        holds[name]?.await()
        val page = PageResponse(
            pageId = name, title = name, state = state[name].orEmpty(),
            components = nodes[name] ?: listOf(text("0", name)),
        )
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    /** The app state request [index] carried (a POST body), or null for a GET. */
    fun appState(index: Int): JsonValue? {
        val request = requests[index]
        val body = request.body ?: return null
        return if (request.method == "POST") JsonValue.parse(body)["appState"] else null
    }

    val client: OrcaClient
        get() = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", device = DeviceInfo(osVersion = "test"), transport = this)
}

private fun state(key: String, scope: StateScope, initial: Long) = StateDefinition(key, scope, JsonValue.Int(initial))

/**
 * A `/config` body for the config router tests: `welcome`, `login`, `home`
 * with the child `home/product/:id`, `account` (sent to `/login` while
 * `loggedIn` is false) and `settings` (with a transition).
 */
private fun navConfig(
    initialRoute: String = "/welcome",
    initialAppState: Map<String, JsonValue> = mapOf("loggedIn" to JsonValue.Bool(false)),
    tabs: List<TabDef> = emptyList(),
) = NavConfig(
    initialRoute = initialRoute,
    tabs = tabs,
    initialAppState = initialAppState,
    flows = listOf(
        NavFlow(
            name = "main",
            routes = listOf(
                NavRoute("welcome"),
                NavRoute("login"),
                NavRoute("home", children = listOf(NavRoute("home/product/:id"))),
                NavRoute("account", redirect = RedirectRule("loggedIn", JsonValue.Bool(false), "/login")),
                NavRoute("settings", transition = RouteTransitionDef("fade")),
            ),
        ),
    ),
)

/**
 * T6.4.2: navigation through the router, as the effects a page's actions
 * report (Swift's `RouterTests`, the five navigation and app-state cases),
 * then the router on screen: a tap pushes a page on the NavHost, and the
 * system back gesture pops it from both.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class RouterTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private fun router(stub: PageStub = PageStub()) = OrcaRouter(stub.client, path = "home")

    private suspend fun loaded(router: OrcaRouter, route: OrcaRoute): OrcaPageModel {
        val loader = router.loader(route)
        loader.loadIfNeeded(ApplicationProvider.getApplicationContext<Context>())
        return (loader.phase as? OrcaPageLoader.Phase.Loaded)?.model
            ?: fail("page ${route.path} did not load: ${loader.phase}")
    }

    /** Swift `testNavigatePushesReplaceResetsGoBackPops`. */
    @Test
    fun r1_navigatePushesReplaceResetsGoBackPops() {
        val router = router()
        val home = router.root
        assertEquals("home", home.path)

        router.navigate("/about")
        router.navigate("product")
        assertEquals(listOf("about", "product"), router.stack.map { it.path })
        assertEquals("product", router.top.path)

        router.goBack()
        assertEquals(listOf("about"), router.stack.map { it.path })

        router.navigate("checkout", replace = true)
        assertEquals("checkout", router.root.path)
        assertNotEquals(home.id, router.root.id)
        assertEquals(emptyList(), router.stack)

        router.goBack()
        router.navigate("")
        assertEquals(emptyList(), router.stack)
        assertEquals("checkout", router.root.path)
    }

    /** Swift `testTheSamePathTwiceIsTwoPages`. */
    @Test
    fun r2_theSamePathTwiceIsTwoPages() {
        val router = router()
        router.navigate("product")
        router.navigate("product")
        assertEquals(2, router.stack.size)
        assertNotEquals(router.stack[0].id, router.stack[1].id)
        assertNotSame(router.loader(router.stack[0]), router.loader(router.stack[1]))
        assertSame(router.loader(router.stack[0]), router.loader(router.stack[0]))
    }

    /** Swift `testAPoppedRouteLosesItsPage`. */
    @Test
    fun r3_aPoppedRouteLosesItsPage() {
        val router = router()
        router.navigate("about")
        val about = router.stack[0]
        val first = router.loader(about)
        router.stack = emptyList() // a host may set the stack directly
        assertNotSame(first, router.loader(about))
    }

    /** Swift `testPageActionsDriveTheRouter`. */
    @Test
    fun r4_pageActionsDriveTheRouter() = runBlocking {
        val router = router()
        val home = loaded(router, router.root)
        home.run(Action.Navigate(route = JsonValue.String("/about")))
        assertEquals(listOf("about"), router.stack.map { it.path })

        val about = loaded(router, router.stack[0])
        about.run(Action.GoBack)
        assertEquals(emptyList(), router.stack)

        home.run(Action.Navigate(path = JsonValue.String("checkout"), replace = true))
        assertEquals("checkout", router.root.path)
    }

    /**
     * Swift `testAppStateIsSharedAcrossPages`. App state is one scope: the
     * next page's fetch carries it, the page starts from it, and the page
     * revealed by a pop sees later writes.
     */
    @Test
    fun r5_appStateIsSharedAcrossPages() = runBlocking {
        val stub = PageStub(
            state = mapOf(
                "home" to listOf(state("cart", StateScope.App, 0)),
                "product" to listOf(state("cart", StateScope.App, 99), state("qty", StateScope.Page, 1)),
            ),
        )
        val router = router(stub)
        val home = loaded(router, router.root)
        assertNull(stub.appState(0))
        assertEquals(mapOf("cart" to JsonValue.Int(0)), router.appState)

        home.run(Action.SetState(key = "cart", scope = StateScope.App, value = JsonValue.Int(2)))
        router.navigate("product")
        val product = loaded(router, router.stack[0])
        assertEquals(JsonValue.obj("cart" to 2), stub.appState(1))
        // The app key was already set, so the page's own initial is ignored.
        assertEquals(mapOf("cart" to JsonValue.Int(2)), product.store.state.app)
        assertEquals(mapOf("qty" to JsonValue.Int(1)), product.store.state.page)

        product.run(Action.SetState(key = "cart", scope = StateScope.App, value = JsonValue.Int(3)))
        assertEquals(JsonValue.Int(2), home.store.value("cart"))
        router.goBack()
        assertEquals(JsonValue.Int(3), home.store.value("cart"))
        assertEquals(emptyMap(), home.store.state.page)
    }

    /**
     * R4 on screen, under OrcaApp's NavHost: a tap pushes the next page, and
     * the system back gesture shows the first page again and pops the router.
     */
    @Test
    fun r4_onScreen_aTapPushesAPageAndSystemBackPopsIt() {
        val go = Action.Navigate(route = JsonValue.String("/about"))
        val stub = PageStub(nodes = mapOf("home" to listOf(button("0", "TextButton", "1", mapOf("onTap" to go)), text("1", "Go"))))
        val router = router(stub)
        compose.setContent { OrcaApp(router) }

        compose.waitUntil(5_000) { count("Go") > 0 }
        compose.onNodeWithText("Go").performClick()
        compose.waitUntil(5_000) { count("about") > 0 }
        assertEquals(listOf("about"), router.stack.map { it.path })

        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        compose.waitUntil(5_000) { count("about") == 0 }
        compose.onNodeWithText("Go").assertIsDisplayed()
        assertEquals(emptyList(), router.stack)
        assertEquals(listOf("home", "about"), stub.requests.map { it.url.path.substringAfterLast("/") })
    }

    /**
     * A page whose load is cut short when it leaves the screen loads again
     * when it is back: the root, still loading when a page is pushed over
     * it, draws once the user goes back (Swift ends such a load in `failed`,
     * with "Try again").
     */
    @Test
    fun r1_onScreen_aRootLeftWhileLoadingLoadsWhenShownAgain() {
        val home = CompletableDeferred<Unit>()
        val stub = PageStub(holds = mapOf("home" to home))
        val router = router(stub)
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { stub.requests.size == 1 }

        compose.runOnIdle { router.navigate("about") }
        compose.waitUntil(5_000) { count("about") > 0 }
        compose.waitForIdle() // the push has settled: the root page left the composition

        compose.runOnIdle { router.goBack() }
        compose.waitUntil(5_000) { count("about") == 0 }
        home.complete(Unit)
        compose.waitUntil(5_000) { count("home") > 0 }
        assertEquals(listOf("home", "about", "home"), stub.requests.map { it.url.path.substringAfterLast("/") })
    }

    /**
     * A page popped while it loads stays out of the router when its fetch
     * lands (the NavHost keeps it on screen while it leaves): the app scope
     * keeps what the pages on the stack left in it, and no page is built.
     */
    @Test
    fun r3_aPageLandingAfterItsRouteWasPoppedJoinsNothing() = runBlocking {
        val about = CompletableDeferred<Unit>()
        val stub = PageStub(
            state = mapOf(
                "home" to listOf(state("cart", StateScope.App, 0)),
                "about" to listOf(state("seen", StateScope.App, 1)),
            ),
            holds = mapOf("about" to about),
        )
        val router = router(stub)
        loaded(router, router.root)
        router.navigate("about")
        val loader = router.loader(router.stack[0])
        val load = launch(start = CoroutineStart.UNDISPATCHED) {
            loader.loadIfNeeded(ApplicationProvider.getApplicationContext<Context>())
        }

        router.goBack()
        about.complete(Unit)
        load.join()
        assertEquals(mapOf("cart" to JsonValue.Int(0)), router.appState)
        assertSame(OrcaPageLoader.Phase.Loading, loader.phase)
    }

    /**
     * S8.3's `OrcaApp` line on screen: a router the host built without
     * system actions gets the device's own while `OrcaApp` shows it (a tap
     * on copyToClipboard reaches the clipboard), and drops them when it
     * leaves, so a router the host keeps does not hold the activity.
     */
    @Test
    fun y2_onScreen_aHostRouterWithoutSystemGetsTheDevicesOwn() {
        val router = router(copyPage())
        var shown by mutableStateOf(true)
        compose.setContent { if (shown) OrcaApp(router) }

        tapCopy()
        assertEquals("ORCA-42", clipboardText())

        compose.runOnIdle { shown = false }
        compose.waitForIdle()
        assertNull(router.system)
    }

    /** A router the host built with its own system actions keeps them: they get the effect, the clipboard does not. */
    @Test
    fun y2_onScreen_aHostPassedSystemIsUsedNotReplaced() {
        val copied = mutableListOf<String>()
        val own = SystemActions(open = {}, copy = { copied += it }, share = { _, _ -> })
        val router = OrcaRouter(copyPage().client, path = "home", system = own)
        var shown by mutableStateOf(true)
        compose.setContent { if (shown) OrcaApp(router) }

        tapCopy()
        assertEquals(listOf("ORCA-42"), copied)
        assertNull(clipboardText())

        compose.runOnIdle { shown = false }
        compose.waitForIdle()
        assertSame(own, router.system)
    }

    /**
     * B9.6-UK: the host writes app state through the router and reads it
     * back; every page the router has loaded holds it, not only the top one,
     * and a widget reading the key resolves to the new value.
     */
    @Test
    fun b9_6_hostReadsAndWritesAppState() = runBlocking {
        val cart = leaf("0", "Text", mapOf("data" to JsonValue.obj("type" to "state", "scope" to "app", "key" to "cart")))
        val stub = PageStub(
            state = mapOf("home" to listOf(state("cart", StateScope.App, 0))),
            nodes = mapOf("home" to listOf(cart), "product" to listOf(cart)),
        )
        val router = router(stub)
        val home = loaded(router, router.root)
        router.navigate("product")
        val product = loaded(router, router.stack[0])
        var homeRedraws = 0
        var productRedraws = 0
        home.store.subscribe(listOf("cart")) { homeRedraws++ }
        product.store.subscribe(listOf("cart")) { productRedraws++ }
        assertEquals(JsonValue.Int(0), product.resolve("0")?.get("data"))

        router.setAppState("cart", JsonValue.Int(7))
        assertEquals(mapOf("cart" to JsonValue.Int(7)), router.appState)
        assertEquals(JsonValue.Int(7), product.store.state.app["cart"])
        assertEquals(JsonValue.Int(7), home.store.state.app["cart"]) // lower in the stack
        assertEquals(JsonValue.Int(7), product.resolve("0")?.get("data"))
        assertEquals(JsonValue.Int(7), home.resolve("0")?.get("data"))
        assertEquals(1 to 1, homeRedraws to productRedraws)

        // The bulk form keeps the other keys; a page's own commit still reaches the router.
        router.setAppState(mapOf("user" to JsonValue.String("amy"), "cart" to JsonValue.Int(8)))
        assertEquals(mapOf("cart" to JsonValue.Int(8), "user" to JsonValue.String("amy")), router.appState)
        assertEquals(router.appState, home.store.state.app)
        assertEquals(router.appState, product.store.state.app)
        product.run(Action.SetState(key = "cart", scope = StateScope.App, value = JsonValue.Int(9)))
        assertEquals(JsonValue.Int(9), router.appState["cart"])

        // A page loaded later starts from the written scope.
        router.navigate("about")
        val about = loaded(router, router.stack[1])
        assertEquals(JsonValue.obj("cart" to 9, "user" to "amy"), stub.appState(2))
        assertEquals(router.appState, about.store.state.app)
    }

    /**
     * B9.6-UK (Swift `test_B9_6_hostWriteDuringAPageLoadIsKept`): a page
     * whose fetch began before the host wrote joins with the host's value,
     * and its own app definitions fill only the keys still unset.
     */
    @Test
    fun b9_6_hostWriteDuringAPageLoadIsKept() = runBlocking {
        val welcome = CompletableDeferred<Unit>()
        val stub = PageStub(
            state = mapOf(
                "welcome" to listOf(
                    StateDefinition("loggedIn", StateScope.App, JsonValue.Bool(false)),
                    state("cart", StateScope.App, 1),
                ),
            ),
            holds = mapOf("welcome" to welcome),
        )
        val router = OrcaRouter(stub.client, navConfig())
        val loader = router.loader(router.root)
        val load = launch(start = CoroutineStart.UNDISPATCHED) {
            loader.loadIfNeeded(ApplicationProvider.getApplicationContext<Context>())
        }
        assertEquals(JsonValue.obj("loggedIn" to false), stub.appState(0)) // fetched with the scope before the write

        router.setAppState("loggedIn", JsonValue.Bool(true))
        welcome.complete(Unit)
        load.join()
        val model = (loader.phase as? OrcaPageLoader.Phase.Loaded)?.model ?: fail("welcome did not load: ${loader.phase}")
        val scope = mapOf("loggedIn" to JsonValue.Bool(true), "cart" to JsonValue.Int(1))
        assertEquals(scope, router.appState)
        assertEquals(scope, model.store.state.app)
    }

    /** A not-found route's path drops the query only, as Swift's does: a `#fragment` stays in it. */
    @Test
    fun c4_aNotFoundRoutesPathDropsOnlyTheQuery() {
        val router = OrcaRouter(PageStub().client, navConfig())
        router.navigate("/missing#top?x=1")
        assertTrue(router.top.isNotFound)
        assertEquals("missing#top", router.top.path)
        assertEquals("/missing#top?x=1", router.top.location)
    }

    /** The table is readable by the host (Swift's `table`): the config's with one, null without. */
    @Test
    fun c8_theTableIsExposed() {
        val config = navConfig()
        assertSame(config, OrcaRouter(PageStub().client, config).table?.config)
        assertNull(router().table)
    }

    /** B9.7-UK: one event per change of the top location: boot, push, replace, pop; none when it stays. */
    @Test
    fun b9_7_onRouteChangedBootPushReplacePop() {
        val events = mutableListOf<RouteChangeEvent>()
        val router = OrcaRouter(PageStub().client, navConfig(), onRouteChanged = { events += it })
        assertEquals(listOf(RouteChangeEvent("/welcome", null, RouteChangeType.Push)), events)

        router.navigate("/home")
        router.navigate("/home/product/3?tab=specs")
        assertEquals(
            listOf(
                RouteChangeEvent("/home", "/welcome", RouteChangeType.Push),
                RouteChangeEvent("/home/product/3?tab=specs", "/home", RouteChangeType.Push),
            ),
            events.drop(1),
        )

        router.goBack()
        assertEquals(RouteChangeEvent("/home", "/home/product/3?tab=specs", RouteChangeType.Pop), events.last())
        router.navigate("/settings", replace = true)
        assertEquals(RouteChangeEvent("/settings", "/home", RouteChangeType.Replace), events.last())
        assertEquals(5, events.size)

        // The top location stays: replaced by itself, pushed over itself, back on an empty stack.
        router.navigate("/settings", replace = true)
        router.goBack()
        assertEquals(5, events.size)
        router.navigate("/settings")
        assertEquals(1, router.stack.size)
        assertEquals(5, events.size)

        // A stack the host sets shorter is a pop.
        router.navigate("/home")
        router.navigate("/login")
        router.stack = router.stack.take(1)
        assertEquals(RouteChangeEvent("/settings", "/login", RouteChangeType.Pop), events.last())
        assertEquals(8, events.size)
    }

    /** B9.7-UK: the event comes after the redirect, with the final location, at boot and on navigate. */
    @Test
    fun b9_7_onRouteChangedCarriesTheFinalLocationAfterARedirect() {
        val events = mutableListOf<RouteChangeEvent>()
        val router = OrcaRouter(PageStub().client, navConfig(initialRoute = "/account"), onRouteChanged = { events += it })
        assertEquals(listOf(RouteChangeEvent("/login", null, RouteChangeType.Push)), events)

        router.navigate("/home")
        router.navigate("/account")
        assertEquals(RouteChangeEvent("/login", "/home", RouteChangeType.Push), events.last())

        router.setAppState("loggedIn", JsonValue.Bool(true))
        assertEquals(3, events.size) // a state change does not navigate
        router.navigate("/account", replace = true)
        assertEquals(RouteChangeEvent("/account", "/login", RouteChangeType.Replace), events.last())
    }

    /** B9.7-UK without a config: no boot event for a callback set later, then the same rules. */
    @Test
    fun b9_7_onRouteChangedWithoutAConfig() {
        val events = mutableListOf<RouteChangeEvent>()
        val router = router()
        router.onRouteChanged = { events += it }
        assertEquals(emptyList(), events)

        router.navigate("/about")
        router.navigate("checkout", replace = true)
        router.navigate("checkout", replace = true)
        router.navigate("product")
        router.goBack()
        router.goBack()
        assertEquals(
            listOf(
                RouteChangeEvent("/about", "/home", RouteChangeType.Push),
                RouteChangeEvent("/checkout", "/about", RouteChangeType.Replace),
                RouteChangeEvent("/product", "/checkout", RouteChangeType.Push),
                RouteChangeEvent("/checkout", "/product", RouteChangeType.Pop),
            ),
            events,
        )
    }

    /** The config's initial route (not `home`) is the first page, and `initialAppState` is seeded before it is requested. */
    @Test
    fun c1_configBootShowsTheInitialRouteWithTheSeededAppState() = runBlocking {
        val stub = PageStub()
        val router = OrcaRouter(stub.client, navConfig())
        assertEquals("welcome", router.root.path)
        assertEquals("/welcome", router.root.location)
        assertEquals(emptyList(), router.stack)
        assertEquals(mapOf("loggedIn" to JsonValue.Bool(false)), router.appState)
        assertEquals(emptyList(), stub.requests) // the router itself fetches nothing

        val welcome = loaded(router, router.root)
        assertEquals(listOf("welcome"), stub.requests.map { it.url.path.substringAfterLast("/page/") })
        assertEquals(JsonValue.obj("loggedIn" to false), stub.appState(0))
        assertEquals(JsonValue.Bool(false), welcome.store.state.app["loggedIn"])
    }

    /** A nested initial route is shown as GoRouter `go` shows it: the parent chain as root + stack. */
    @Test
    fun c2_configBootOnANestedRouteGivesRootAndStack() {
        val router = OrcaRouter(PageStub().client, navConfig(initialRoute = "/home/product/3?tab=specs"))
        assertEquals("home", router.root.path)
        assertEquals("/home", router.root.location)
        assertEquals(listOf("home/product/3"), router.stack.map { it.path })
        assertEquals("/home/product/3?tab=specs", router.top.location)
    }

    /** A redirect on the initial route lands on its target; logged in, on the route itself. */
    @Test
    fun c3_configBootFollowsTheRedirectOfTheInitialRoute() {
        val out = OrcaRouter(PageStub().client, navConfig(initialRoute = "/account"))
        assertEquals("login", out.root.path)
        assertEquals("/login", out.root.location)

        val loggedIn = navConfig(initialRoute = "/account", initialAppState = mapOf("loggedIn" to JsonValue.Bool(true)))
        assertEquals("account", OrcaRouter(PageStub().client, loggedIn).root.path)
    }

    /** An unknown location is a not-found route, at boot, pushed and replaced, and the router requests nothing for it. */
    @Test
    fun c4_anUnknownLocationIsANotFoundRoute() {
        val stub = PageStub()
        val boot = OrcaRouter(stub.client, navConfig(initialRoute = "/nowhere"))
        assertTrue(boot.root.isNotFound)
        assertEquals("/nowhere", boot.root.location)

        val router = OrcaRouter(stub.client, navConfig())
        assertFalse(router.root.isNotFound)
        router.navigate("/missing?x=1")
        assertEquals(listOf(true), router.stack.map { it.isNotFound })
        assertEquals("/missing?x=1", router.top.location)
        router.navigate("/nope", replace = true)
        assertTrue(router.root.isNotFound)
        assertEquals("/nope", router.root.location)
        assertEquals(emptyList(), router.stack)
        assertEquals(emptyList(), stub.requests)
    }

    /**
     * With a config, `navigate` resolves the location: a push adds one page
     * (the top of the chain), `replace` shows the whole chain, the redirect
     * rule reads the app state of the moment, and only the top entry carries
     * the title and the transition.
     */
    @Test
    fun c5_navigateWithAConfigResolvesTheLocation() {
        val router = OrcaRouter(PageStub().client, navConfig())
        router.navigate("home/product/3") // no leading slash, as a page action may send it
        assertEquals(listOf("home/product/3"), router.stack.map { it.path })
        assertEquals("/home/product/3", router.top.location)

        router.navigate("/account")
        assertEquals("login", router.top.path)
        router.setAppState("loggedIn", JsonValue.Bool(true))
        router.navigate("/account")
        assertEquals("account", router.top.path)

        router.navigate("/home/product/4", replace = true)
        assertEquals("home", router.root.path)
        assertEquals(listOf("home/product/4"), router.stack.map { it.path })

        router.navigate("/settings")
        assertEquals(RouteTransitionDef("fade"), router.top.transition)
        assertNull(router.root.transition)
        assertNull(router.top.scaffoldTitle) // no tabs: no title bar
    }

    /** In a config with tabs, a route outside every tab carries its fallback title; a tab route carries none. */
    @Test
    fun c6_scaffoldTitleIsCarriedForANonTabRoute() {
        val tabs = listOf(TabDef("home", "Home", "home", "/home"))
        val router = OrcaRouter(PageStub().client, navConfig(initialRoute = "/home", tabs = tabs))
        assertNull(router.root.scaffoldTitle)

        router.navigate("/settings")
        assertEquals("Settings", router.top.scaffoldTitle)
        router.navigate("/home/product/3")
        assertNull(router.top.scaffoldTitle)
        router.navigate("/settings", replace = true)
        assertEquals("Settings", router.root.scaffoldTitle)
    }

    /** A route made from a path alone, as before: its location is the path with a leading slash. */
    @Test
    fun c7_aPlainRouteHasItsPathAsLocation() {
        val route = OrcaRoute("/about")
        assertEquals("about", route.path)
        assertEquals("/about", route.location)
        assertNull(route.scaffoldTitle)
        assertNull(route.transition)
        assertFalse(route.isNotFound)
    }

    /** Three tabs (`/home` with the child `home/product/:id`, `/search`, `/more`) and `settings` outside them. */
    private fun tabConfig(
        initialRoute: String = "/home",
        initialAppState: Map<String, JsonValue> = emptyMap(),
        drawerItems: List<DrawerItemDef> = emptyList(),
    ) = NavConfig(
        initialRoute = initialRoute,
        tabs = listOf(
            TabDef("home", "Home", "home", "/home"),
            TabDef("search", "Search", "search", "/search"),
            TabDef("more", "More", "menu", "/more"),
        ),
        drawerItems = drawerItems,
        initialAppState = initialAppState,
        flows = listOf(
            NavFlow(
                name = "main",
                routes = listOf(
                    NavRoute("home", children = listOf(NavRoute("home/product/:id"))),
                    NavRoute("search"),
                    NavRoute("more"),
                    NavRoute("settings"),
                ),
            ),
        ),
    )

    private fun pages(stub: PageStub): List<String> = stub.requests.map { it.url.path.substringAfterLast("/page/") }

    private fun tabIndex(router: OrcaRouter): JsonValue? = router.appState["_tabIndex"]

    /**
     * B10.2-K: a page pushed in tab 0 is still there after a visit to tab 1,
     * as the same route with the same page model, and nothing is fetched
     * again; a tab's page is fetched on its first visit only.
     */
    @Test
    fun b10_2_aTabKeepsItsStackAndItsPagesAcrossASwitch() = runBlocking {
        val stub = PageStub()
        val router = OrcaRouter(stub.client, tabConfig())
        assertTrue(router.hasShell)
        assertEquals(listOf("home", "search", "more"), router.tabs.map { it.id })
        assertEquals(0, router.currentTab)

        val homeRoute = router.root
        val home = loaded(router, homeRoute)
        router.navigate("/home/product/3")
        val productRoute = router.stack.single()
        val product = loaded(router, productRoute)
        assertEquals(listOf(listOf("home", "home/product/3"), emptyList(), emptyList()), router.tabStacks.map { s -> s.map { it.path } })

        router.selectTab(1)
        assertEquals(1, router.currentTab)
        assertEquals("search", router.root.path)
        assertEquals(emptyList(), router.stack)
        assertEquals(listOf("home", "home/product/3"), router.tabStacks[0].map { it.path })
        loaded(router, router.root)
        assertEquals(listOf("home", "home/product/3", "search"), pages(stub)) // the first visit fetches, once

        router.selectTab(0)
        assertEquals(0, router.currentTab)
        assertSame(homeRoute, router.root)
        assertEquals(listOf(productRoute), router.stack)
        assertEquals("/home/product/3", router.top.location)
        assertSame(home, loaded(router, router.root))
        assertSame(product, loaded(router, router.stack[0]))

        router.selectTab(1)
        loaded(router, router.root)
        router.selectTab(0)
        assertEquals(listOf("home", "home/product/3", "search"), pages(stub)) // no repeat
        assertEquals(emptyList(), router.overRoutes)
    }

    /** B10.2-K: a tap on the current tab pops it to its root; the popped page is closed, the root is kept. */
    @Test
    fun b10_2_reselectPopsTheTabToItsRoot() = runBlocking {
        val stub = PageStub()
        val router = OrcaRouter(stub.client, tabConfig())
        val home = loaded(router, router.root)
        router.navigate("/home/product/3")
        router.navigate("/home/product/4")
        val product = router.stack[0]
        val productLoader = router.loader(product)

        router.selectTab(0)
        assertEquals(emptyList(), router.stack)
        assertEquals(0, router.currentTab)
        assertSame(home, loaded(router, router.root))
        assertNotSame(productLoader, router.loader(product)) // dropped: its loader was closed and forgotten
        assertEquals(listOf("home"), pages(stub))

        router.selectTab(7) // no such tab
        assertEquals(0, router.currentTab)
    }

    /** B10.2-K: `navigate(replace)` into the tab on screen keeps the pages its chain starts with; the kept top follows the new location. */
    @Test
    fun b10_2_goIntoATabKeepsItsPagesAndTheirRoutes() = runBlocking {
        val stub = PageStub()
        val router = OrcaRouter(stub.client, tabConfig())
        val homeRoute = router.root
        val home = loaded(router, homeRoute)

        router.navigate("/home?sort=new", replace = true)
        assertSame(homeRoute, router.root)
        assertEquals("/home?sort=new", router.root.location)
        assertSame(home, loaded(router, router.root))

        router.navigate("/home/product/3", replace = true)
        assertSame(homeRoute, router.root)
        assertEquals("/home", router.root.location)
        assertEquals(listOf("home/product/3"), router.stack.map { it.path })
        assertEquals(listOf("home"), pages(stub))
    }

    /**
     * B10.2-K: a route `navigate(replace)` kept follows its entry with every
     * field, not only the location: the tab root gains its transition when it
     * becomes the top and loses it under its child, as a route built anew for
     * that entry would have it, and stays the same route with the same loader.
     * A route outside the tabs (the one with a title bar) is never kept: it
     * is built anew each time.
     */
    @Test
    fun b10_2_aKeptRouteTakesTheEntrysNewFields() {
        val fade = RouteTransitionDef("fade")
        val slide = RouteTransitionDef("slide")
        fun config(initialRoute: String) = NavConfig(
            initialRoute = initialRoute,
            tabs = listOf(TabDef("home", "Home", "home", "/home"), TabDef("search", "Search", "search", "/search")),
            flows = listOf(
                NavFlow(
                    name = "main",
                    routes = listOf(
                        NavRoute("home", transition = fade, children = listOf(NavRoute("home/product/:id", transition = slide))),
                        NavRoute("search"),
                        NavRoute("settings", transition = fade),
                    ),
                ),
            ),
        )

        fun fields(router: OrcaRouter) = (listOf(router.root) + router.stack).map {
            listOf(it.path, it.location, it.scaffoldTitle, it.isNotFound, it.transition)
        }

        /** What a router booted at [location] shows: every route built anew for its entry. */
        fun fresh(location: String) = fields(OrcaRouter(PageStub().client, config(location)))

        val router = OrcaRouter(PageStub().client, config("/home"))
        val home = router.root
        val loader = router.loader(home)
        assertEquals(fade, home.transition) // the top at boot

        val steps = listOf("/home/product/3", "/home", "/home/product/3?tab=specs", "/home?sort=new", "/home/product/4")
        for (location in steps) {
            router.navigate(location, replace = true)
            assertSame(home, router.root, location)
            assertSame(loader, router.loader(home), location)
            assertEquals(fresh(location), fields(router), location)
        }

        // Spelled out for the first three: a parent has no transition, the top has its own.
        router.navigate("/home/product/3", replace = true)
        assertNull(router.root.transition)
        assertEquals(slide, router.top.transition)
        router.navigate("/home", replace = true)
        assertEquals(fade, router.root.transition)
        assertEquals("/home", router.root.location)
        router.navigate("/home/product/3", replace = true)
        assertNull(router.root.transition)
        assertNull(router.root.scaffoldTitle)
        assertFalse(router.root.isNotFound)
        assertSame(home, router.root)
        assertSame(loader, router.loader(home))

        // Outside the tabs nothing is kept: the titled route is a new one each time, with the fields of its entry.
        router.navigate("/settings", replace = true)
        val settings = router.root
        assertEquals(fresh("/settings"), fields(router))
        assertEquals("Settings", settings.scaffoldTitle)
        router.navigate("/settings?x=1", replace = true)
        assertNotSame(settings, router.root)
        assertEquals(fresh("/settings?x=1"), fields(router))
    }

    /** B10.2-K: a route outside the tabs pushed over the shell keeps the tab under it, and a tab tap drops it. */
    @Test
    fun b10_2_aNonTabRouteOverTheShellKeepsTheTabAndIsDroppedBySelectTab() {
        val router = OrcaRouter(PageStub().client, tabConfig())
        val homeRoute = router.root
        router.navigate("/settings")
        val settings = router.top
        assertEquals("Settings", settings.scaffoldTitle)
        assertEquals(0, router.currentTab)
        assertEquals(listOf(settings), router.overRoutes)
        assertEquals(listOf(settings), router.stack)
        assertEquals(listOf("home"), router.tabStacks[0].map { it.path })
        val loader = router.loader(settings)

        router.selectTab(1)
        assertEquals(1, router.currentTab)
        assertEquals(emptyList(), router.overRoutes)
        assertEquals("search", router.top.path)
        assertNotSame(loader, router.loader(settings))

        router.selectTab(0)
        assertSame(homeRoute, router.root)
        assertEquals(emptyList(), router.stack)

        // Replaced by a route outside the tabs, the shell is gone.
        router.navigate("/settings", replace = true)
        assertFalse(router.hasShell)
        assertNull(router.currentTab)
        assertEquals(listOf(emptyList(), emptyList(), emptyList()), router.tabStacks)
        assertEquals(listOf("settings"), router.overRoutes.map { it.path })
        assertEquals("settings", router.root.path)
    }

    /** B10.2-K: `canGoBack` is what `goBack` would do: false at a tab root, true one level in or under a pushed route. */
    @Test
    fun b10_2_canGoBackIsFalseAtATabRootAndTrueOneLevelIn() {
        val router = OrcaRouter(PageStub().client, tabConfig())
        assertFalse(router.canGoBack)
        router.navigate("/home/product/3")
        assertTrue(router.canGoBack)
        router.goBack()
        assertFalse(router.canGoBack)
        router.goBack() // at the tab root: nothing
        assertEquals("home", router.top.path)

        router.selectTab(1)
        assertFalse(router.canGoBack) // no hop back to the first tab
        router.navigate("/settings")
        assertTrue(router.canGoBack)
        router.goBack()
        assertEquals(1, router.currentTab)
        assertFalse(router.canGoBack)

        val plain = router()
        assertFalse(plain.canGoBack)
        plain.navigate("about")
        assertTrue(plain.canGoBack)
    }

    /**
     * B10.3-K: `_tabIndex` is written at boot, over a seeded value and before
     * the first page request, and follows a tab tap, `switchTab` and
     * `navigate(replace)`; every loaded page holds it. Each is a `Replace`.
     */
    @Test
    fun b10_3_tabIndexIsInTheFirstPageRequestAndFollowsEveryTabChange() = runBlocking {
        val stub = PageStub()
        val events = mutableListOf<RouteChangeEvent>()
        val config = tabConfig(initialRoute = "/search", initialAppState = mapOf("_tabIndex" to JsonValue.Int(7)))
        val router = OrcaRouter(stub.client, config, onRouteChanged = { events += it })
        assertEquals(1, router.currentTab)
        assertEquals(JsonValue.Int(1), tabIndex(router))
        val search = loaded(router, router.root)
        assertEquals(JsonValue.obj("_tabIndex" to 1), stub.appState(0))

        router.selectTab(2)
        assertEquals(JsonValue.Int(2), tabIndex(router))
        assertEquals(JsonValue.Int(2), search.store.state.app["_tabIndex"]) // a page of another tab
        val more = loaded(router, router.root)
        assertEquals(JsonValue.obj("_tabIndex" to 2), stub.appState(1))

        router.switchTab("home")
        assertEquals(0, router.currentTab)
        assertEquals(JsonValue.Int(0), tabIndex(router))
        assertEquals(JsonValue.Int(0), more.store.state.app["_tabIndex"])

        router.navigate("/search", replace = true)
        assertEquals(1, router.currentTab)
        assertEquals(JsonValue.Int(1), tabIndex(router))
        assertSame(search, loaded(router, router.root))

        router.navigate("/settings", replace = true) // the shell is gone; the key keeps its last value
        assertEquals(JsonValue.Int(1), tabIndex(router))

        assertEquals(
            listOf(
                RouteChangeEvent("/search", null, RouteChangeType.Push),
                RouteChangeEvent("/more", "/search", RouteChangeType.Replace),
                RouteChangeEvent("/home", "/more", RouteChangeType.Replace),
                RouteChangeEvent("/search", "/home", RouteChangeType.Replace),
                RouteChangeEvent("/settings", "/search", RouteChangeType.Replace),
            ),
            events,
        )
    }

    /**
     * B10.3-K: a page (or the host) writing app state `_tabIndex` switches
     * the tab and restores its stack; a value that is no tab's index changes
     * nothing and stays in app state as written.
     */
    @Test
    fun b10_3_aPageSettingTabIndexSwitchesTheTab() = runBlocking {
        val stub = PageStub()
        val router = OrcaRouter(stub.client, tabConfig())
        val home = loaded(router, router.root)
        router.navigate("/home/product/3")
        val product = router.top

        home.run(Action.SetState(key = "_tabIndex", scope = StateScope.App, value = JsonValue.Int(2)))
        assertEquals(2, router.currentTab)
        assertEquals("more", router.top.path)
        assertEquals(JsonValue.Int(2), tabIndex(router))
        val more = loaded(router, router.root)

        more.run(Action.SetState(key = "_tabIndex", scope = StateScope.App, value = JsonValue.String("first")))
        assertEquals(2, router.currentTab)
        assertEquals(JsonValue.String("first"), tabIndex(router))
        more.run(Action.SetState(key = "_tabIndex", scope = StateScope.App, value = JsonValue.Int(9)))
        assertEquals(2, router.currentTab)
        assertEquals(JsonValue.Int(9), tabIndex(router))
        assertEquals("more", router.top.path)

        more.run(Action.SetState(key = "_tabIndex", scope = StateScope.App, value = JsonValue.Int(0)))
        assertEquals(0, router.currentTab)
        assertSame(product, router.top) // restored, not reset
        assertEquals(JsonValue.Int(0), home.store.state.app["_tabIndex"])

        router.setAppState("_tabIndex", JsonValue.Int(1)) // the host's write switches too
        assertEquals(1, router.currentTab)
        assertEquals("search", router.top.path)
        assertEquals(listOf("home", "more"), pages(stub))
    }

    /** B10.3-K: the `switchTab` action a page runs changes the tab and lands on its root; an unknown id does nothing. */
    @Test
    fun b10_3_theSwitchTabActionSwitchesAndLandsOnTheRoot() = runBlocking {
        val stub = PageStub()
        val router = OrcaRouter(stub.client, tabConfig())
        val homeRoute = router.root
        loaded(router, homeRoute)
        router.navigate("/home/product/3")
        router.selectTab(1)
        val search = loaded(router, router.root)

        search.run(Action.SwitchTab("home"))
        assertEquals(0, router.currentTab)
        assertSame(homeRoute, router.root)
        assertEquals(emptyList(), router.stack) // the root, not the page it was left on
        assertEquals(JsonValue.Int(0), tabIndex(router))

        search.run(Action.SwitchTab("nowhere"))
        assertEquals(0, router.currentTab)
        search.run(Action.SwitchTab("more"))
        assertEquals(2, router.currentTab)
        assertEquals("more", router.top.path)
        assertEquals(listOf("home", "search"), pages(stub))

        // Without a config there are no tabs: nothing happens.
        val plain = router()
        loaded(plain, plain.root).run(Action.SwitchTab("home"))
        assertEquals("home", plain.top.path)
        assertFalse(plain.hasShell)
        assertEquals(emptyList(), plain.tabs)
        assertNull(plain.currentTab)
    }

    /**
     * B10.3-K (brief D1): `openDrawer` opens the shell drawer from a tab page
     * of a config with a drawer; anywhere else it asks the page on top for
     * its own. A navigation that changes the visible location closes the
     * shell drawer.
     */
    @Test
    fun b10_3_openDrawerOpensTheShellDrawerOnATabPageElseAsksThePage() = runBlocking {
        val drawer = listOf(DrawerItemDef("settings", "Settings", route = "/settings"))
        val router = OrcaRouter(PageStub().client, tabConfig(drawerItems = drawer))
        assertTrue(router.hasDrawer)
        assertFalse(router.isDrawerOpen)
        val home = loaded(router, router.root)

        home.run(Action.OpenDrawer)
        assertTrue(router.isDrawerOpen)
        assertNull(router.pageDrawerRequest)
        router.closeDrawer()
        assertFalse(router.isDrawerOpen)

        router.openDrawer()
        router.selectTab(1) // the visible location changes
        assertFalse(router.isDrawerOpen)

        router.navigate("/settings") // over the shell: no shell drawer there
        router.openDrawer()
        assertFalse(router.isDrawerOpen)
        assertEquals(router.top.id, router.pageDrawerRequest)
        router.pageDrawerRequest = null // a consumer clears it
        assertNull(router.pageDrawerRequest)

        // No drawer in the config: a tab page is asked for its own.
        val bare = OrcaRouter(PageStub().client, tabConfig())
        assertFalse(bare.hasDrawer)
        loaded(bare, bare.root).run(Action.OpenDrawer)
        assertFalse(bare.isDrawerOpen)
        assertEquals(bare.root.id, bare.pageDrawerRequest)

        // Drawer items without tabs are no shell drawer.
        assertFalse(OrcaRouter(PageStub().client, navConfig().copy(drawerItems = drawer)).hasDrawer)
        assertFalse(router().hasDrawer)
    }

    /** A home page whose one button copies `ORCA-42`. */
    private fun copyPage(): PageStub {
        val copy = Action.CopyToClipboard(text = JsonValue.String("ORCA-42"))
        return PageStub(nodes = mapOf("home" to listOf(button("0", "TextButton", "1", mapOf("onTap" to copy)), text("1", "Copy"))))
    }

    private fun tapCopy() {
        compose.waitUntil(5_000) { count("Copy") > 0 }
        compose.onNodeWithText("Copy").performClick()
        compose.waitForIdle()
    }

    private fun clipboardText(): String? =
        compose.activity.getSystemService(ClipboardManager::class.java).primaryClip?.getItemAt(0)?.text?.toString()

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size
}
