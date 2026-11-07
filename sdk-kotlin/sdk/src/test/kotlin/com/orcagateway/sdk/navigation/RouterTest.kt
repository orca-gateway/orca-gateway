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
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.support.button
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
import kotlin.test.assertNotEquals
import kotlin.test.assertNotSame
import kotlin.test.assertNull
import kotlin.test.assertSame
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
