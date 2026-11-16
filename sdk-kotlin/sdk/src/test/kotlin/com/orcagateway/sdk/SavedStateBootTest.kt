package com.orcagateway.sdk

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableIntState
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.FileKeyValueStore
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.StaticFlowManager
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.models.TabDef
import com.orcagateway.core.state.SavedState
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.net.ConnectException
import java.net.URI
import java.util.Collections
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNotSame
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * C14.6 on Android, as Flutter's OrcaApp does it (sdk/lib/src/widgets/orca_app.dart
 * `loadSaved` and `restoreApp`, sdk/lib/src/state/state_manager.dart `initPage`):
 * a page's persistState saves into the app's SavedState, and a new OrcaApp over
 * the same store (a relaunch) restores it; a session save outlives leaving the
 * page, not a new process; clearState empties the live key and both saved
 * copies; the saved app entry is laid over `initialAppState` before the first
 * route is resolved; a page from the static cache saves and restores as one
 * from the network; a page seeded again from a fresh response gets its saved
 * entry over that seed; a server tab bar saves app keys as a page does
 * (Flutter's shell executor has the app's StateManager, orca_shell.dart). Every store is a file store in a temporary directory,
 * the session storage is reset around each test (a new process). Swift twin:
 * SavedStateBootTests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class SavedStateBootTest {
    @get:Rule
    val compose = createComposeRule()

    @get:Rule
    val folder = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Before
    fun newProcess() {
        SavedState.resetSession()
    }

    @After
    fun reset() {
        SavedState.resetSession()
        File(context.filesDir, "orca_gateway").deleteRecursively()
    }

    /**
     * The saved-state demo (examples/server/saved-state.ts), small: `home`
     * (page `count`, app `visits`, the save and forget buttons), `other` and
     * `login`, and [config] at `/config`, the static flow's version at
     * `/version`. Off [online], every request fails as an unreachable server does.
     */
    private class SavedEngine(private val config: String = CONFIG) : HttpTransport {
        var online: Boolean = true

        /** What `home` declares for `count`. */
        var initialCount: Long = 0

        val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())

        override suspend fun send(request: HttpRequest): HttpResponse {
            requests += request
            if (!online) throw ConnectException("unreachable")
            val path = request.url.path
            return when {
                path.endsWith("/version") -> HttpResponse(200, JSON, """{"flows":{"main":1}}""".toByteArray())
                path.endsWith("/config") -> HttpResponse(200, JSON, config.toByteArray())
                else -> {
                    val page = when (path.substringAfterLast("/page/")) {
                        "home" -> home(initialCount)
                        "login" -> LOGIN
                        else -> OTHER
                    }
                    HttpResponse(200, JSON, encode(page).toByteArray())
                }
            }
        }

        private val pageRequests: List<HttpRequest> get() = requests.toList().filter { "/page/" in it.url.path }

        /** The pages asked of the network, in order. */
        val pages: List<String> get() = pageRequests.map { it.url.path.substringAfterLast("/page/") }

        /** The app state each page request carried (a POST's body; a GET carries none). */
        val pageAppStates: List<Map<String, JsonValue>>
            get() = pageRequests.map { request ->
                request.body?.let { JsonValue.parse(it.decodeToString()).objectValue?.get("appState")?.objectValue }.orEmpty()
            }

        val client: OrcaClient get() = OrcaClient(URI("http://engine.invalid"), appId = "saved-state", transport = this)
    }

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    private fun waitForText(text: String) {
        compose.waitUntil(5_000) { count(text) > 0 }
    }

    private fun tap(label: String) {
        compose.onNodeWithText(label).performClick()
        compose.waitForIdle()
    }

    /** [content] under a key: [relaunch] composes it anew, a new OrcaApp with new remembered stores. */
    private fun launch(content: @Composable () -> Unit): MutableIntState {
        val run = mutableIntStateOf(0)
        compose.setContent { key(run.intValue) { content() } }
        return run
    }

    /** A new process: the session storage is gone, and a new OrcaApp boots over the same files. */
    private fun relaunch(run: MutableIntState, engine: SavedEngine) {
        SavedState.resetSession()
        engine.requests.clear()
        compose.runOnIdle { run.intValue += 1 }
    }

    /** The saved entry [name] of the temporary directory's files, as a map; null when there is none. */
    private fun savedEntry(name: String, store: FileKeyValueStore = FileKeyValueStore(folder.root)): Map<String, JsonValue>? =
        store.getString(name)?.let { JsonValue.parse(it).objectValue }

    @Test
    fun c14_6_aPageAndAppLocalSaveSurviveANewOrcaAppOverTheSameStore() {
        val engine = SavedEngine()
        val run = launch { OrcaApp(engine.client, path = "home", savedState = remember { SavedState(FileKeyValueStore(folder.root)) }) }

        waitForText("Count: 0")
        tap("Set 5")
        tap("Save on device")
        tap("Visit and save")
        waitForText("Visits: 3")
        assertEquals(mapOf("count" to JsonValue.Int(5)), savedEntry("orca_saved_page_home"))
        assertEquals(mapOf("visits" to JsonValue.Int(3)), savedEntry("orca_saved_app"))

        relaunch(run, engine)
        waitForText("Count: 5")
        waitForText("Visits: 3")
        // With a path there is no config: the app entry is restored at boot, before the first page request.
        assertEquals(listOf("home"), engine.pages)
        assertEquals(listOf(mapOf("visits" to JsonValue.Int(3))), engine.pageAppStates)
    }

    @Test
    fun c14_6_aSessionSaveSurvivesLeavingAndReopeningThePageButNotANewProcess() {
        val engine = SavedEngine()
        val run = launch { OrcaApp(engine.client, path = "home", savedState = remember { SavedState(FileKeyValueStore(folder.root)) }) }

        waitForText("Count: 0")
        tap("Set 5")
        tap("Save for this session")
        assertEquals(mapOf("orca_saved_page_home" to mapOf("count" to JsonValue.Int(5))), SavedState.sessionEntries)
        assertNull(savedEntry("orca_saved_page_home"))

        // Leave the page (it is closed) and open it again: a new page, set up from its saved entry.
        tap("Leave")
        waitForText("Back home")
        tap("Back home")
        waitForText("Count: 5")
        assertEquals(listOf("home", "other", "home"), engine.pages)

        relaunch(run, engine)
        waitForText("Count: 0")
    }

    @Test
    fun c14_6_clearStateEmptiesTheLiveKeyAndBothSavedCopies() {
        val engine = SavedEngine()
        val run = launch { OrcaApp(engine.client, path = "home", savedState = remember { SavedState(FileKeyValueStore(folder.root)) }) }

        waitForText("Count: 0")
        tap("Set 5")
        tap("Save on device")
        assertNotNull(savedEntry("orca_saved_page_home"))
        tap("Forget")
        compose.waitUntil(5_000) { count("Count: 5") == 0 }
        assertNull(savedEntry("orca_saved_page_home"))

        tap("Set 5")
        tap("Save for this session")
        assertEquals(setOf("orca_saved_page_home"), SavedState.sessionEntries.keys)
        tap("Forget")
        compose.waitUntil(5_000) { count("Count: 5") == 0 }
        assertEquals(emptyMap(), SavedState.sessionEntries)

        tap("Leave")
        waitForText("Back home")
        tap("Back home")
        waitForText("Count: 0")

        relaunch(run, engine)
        waitForText("Count: 0")
        assertNull(savedEntry("orca_saved_page_home"))
    }

    @Test
    fun c14_6_theSavedAppEntryIsLaidOverInitialAppStateBeforeTheFirstRoute() {
        val engine = SavedEngine(CONFIG)
        val run = launch { OrcaApp(engine.client, savedState = remember { SavedState(FileKeyValueStore(folder.root)) }) }

        // initialAppState says signedIn false: /home redirects to /login.
        waitForText("Please sign in")
        assertEquals(listOf("login"), engine.pages)
        tap("Sign in")
        waitForText("Count: 0")
        assertEquals(mapOf("signedIn" to JsonValue.Bool(true)), savedEntry("orca_saved_app"))

        relaunch(run, engine)
        waitForText("Count: 0")
        // The redirect of the initial route read the restored value, and the first request carries it.
        assertEquals(listOf("home"), engine.pages)
        assertEquals(JsonValue.Bool(true), engine.pageAppStates.single()["signedIn"])
    }

    @Test
    fun c14_6_aPageFromTheStaticCacheSavesAndRestoresAsOneFromTheNetwork() {
        val engine = SavedEngine(STATIC_CONFIG)
        // The cache and the saved entries share one directory: their names do not collide.
        val run = launch {
            OrcaApp(
                engine.client,
                enableOffline = true,
                staticFlowManager = remember { StaticFlowManager(FileKeyValueStore(folder.root)) },
                savedState = remember { SavedState(FileKeyValueStore(folder.root)) },
            )
        }

        waitForText("Count: 0")
        tap("Set 5")
        tap("Save on device")
        assertEquals(mapOf("count" to JsonValue.Int(5)), savedEntry("orca_saved_page_home"))

        engine.online = false
        relaunch(run, engine)
        waitForText("Count: 5")
        assertEquals(emptyList(), engine.pages)
        assertNotNull(FileKeyValueStore(folder.root).getString("orca_nav_config"))
    }

    @Test
    fun c14_6_aPageSeededAgainFromAFreshResponseGetsItsSavedEntryOverThatSeed(): Unit = runBlocking {
        val engine = SavedEngine()
        val saved = SavedState(FileKeyValueStore(folder.root))
        val router = OrcaRouter(engine.client, "home", savedState = saved)
        val loader = router.loader(router.root)
        loader.loadIfNeeded(context)
        val first = assertIs<OrcaPageLoader.Phase.Loaded>(loader.phase).model
        assertSame(saved, first.executor.savedState)
        first.run(Action.SetState("count", value = JsonValue.Int(5)))
        first.run(Action.PersistState("count"))
        // A snapshot: the saved copy stays 5.
        first.run(Action.SetState("count", value = JsonValue.Int(6)))

        // The server now declares another initial; the reload seeds the page from its answer.
        engine.initialCount = 1
        loader.reload(context)
        val second = assertIs<OrcaPageLoader.Phase.Loaded>(loader.phase).model
        assertNotSame(first, second)
        assertEquals(JsonValue.Int(5), second.store.state.page["count"])
        assertSame(saved, second.executor.savedState)
    }

    /**
     * A page refetched in place (refetchPage, Flutter's `OrcaPage.onRefetchPage`, which calls `initPage`) is
     * seeded from the fresh response with its saved entry over that seed: the saved key keeps its saved value.
     */
    @Test
    fun c14_6_aRefetchLaysTheSavedEntryOverTheFreshSeed(): Unit = runBlocking {
        val engine = SavedEngine()
        val router = OrcaRouter(engine.client, "home", savedState = SavedState(FileKeyValueStore(folder.root)))
        val loader = router.loader(router.root)
        loader.loadIfNeeded(context)
        val model = assertIs<OrcaPageLoader.Phase.Loaded>(loader.phase).model
        model.run(Action.SetState("count", value = JsonValue.Int(5)))
        model.run(Action.PersistState("count"))
        model.run(Action.SetState("count", value = JsonValue.Int(6)))

        // The server now declares another initial; the refetch seeds the page from its answer.
        engine.initialCount = 1
        model.executor.execute(Action.RefetchPage)

        assertEquals(listOf("home", "home"), engine.pages)
        assertSame(model, assertIs<OrcaPageLoader.Phase.Loaded>(loader.phase).model)
        assertEquals(mapOf("count" to JsonValue.Int(5)), model.store.state.page)
    }

    /**
     * Flutter's order on a refetch: the fresh page's initials, the saved entry over them, then the keys of the
     * pages mounted in SubPages over both. A key with no saved value takes the fresh page's initial.
     */
    @Test
    fun c14_6_aRefetchKeepsASubPagesCarriedKeyOverTheSavedEntry() {
        FileKeyValueStore(folder.root).putString("orca_saved_page_host", """{"count":4,"detail:count":9}""")
        fun host(count: Long, name: String) = PageResponse(
            pageId = "host",
            title = "Host",
            state = listOf(
                StateDefinition("count", StateScope.Page, JsonValue.Int(count)),
                StateDefinition("name", StateScope.Page, JsonValue.String(name)),
            ),
            components = listOf(
                column("root", "detail"),
                ComponentNode("detail", "SubPage", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single),
            ),
        )
        val detail = PageResponse(
            pageId = "detail/a",
            title = "",
            state = listOf(StateDefinition("count", StateScope.Page, JsonValue.Int(5))),
            components = listOf(text("0", "Page a")),
        )
        val model = OrcaPageModel(host(100, "none"), savedState = SavedState(FileKeyValueStore(folder.root)))
        assertEquals(
            mapOf("count" to JsonValue.Int(4), "name" to JsonValue.String("none"), "detail:count" to JsonValue.Int(9)),
            model.store.state.page,
        )
        model.subPages.register("detail")
        model.subPages.mount("detail", "replace", detail)
        model.store.dispatch(mapOf("detail:count" to JsonValue.Int(6), "name" to JsonValue.String("kim")))

        model.replacePage(host(200, "fresh"))

        assertEquals(
            mapOf("count" to JsonValue.Int(4), "name" to JsonValue.String("fresh"), "detail:count" to JsonValue.Int(6)),
            model.store.state.page,
        )
        model.close()
    }

    @Test
    fun c14_6_aServerTabBarsPersistStateSavesTheAppEntryAndANewOrcaAppStartsWithIt() {
        val engine = SavedEngine()
        val run = launch {
            OrcaApp(engine.client, preloadedConfig = TAB_CONFIG, savedState = remember { SavedState(FileKeyValueStore(folder.root)) })
        }

        waitForText("Bar visits: 0")
        tap("Visit from the bar")
        waitForText("Bar visits: 7")
        assertEquals(mapOf("visits" to JsonValue.Int(7)), savedEntry("orca_saved_app"))
        // The shell is no page: it has no entry of its own.
        assertNull(savedEntry("orca_saved_page___shell__"))

        relaunch(run, engine)
        waitForText("Bar visits: 7")
        waitForText("Visits: 7")
        assertEquals(listOf("home"), engine.pages)
        assertEquals(JsonValue.Int(7), engine.pageAppStates.single()["visits"])
    }

    @Test
    fun c14_6_withoutASavedStateOrcaAppSavesUnderFilesDirOrcaGateway() {
        val engine = SavedEngine()
        compose.setContent { OrcaApp(engine.client, path = "home") }

        waitForText("Count: 0")
        tap("Set 5")
        // A page that sends neither action saves nothing.
        assertNull(savedEntry("orca_saved_page_home", offlineStore(context)))
        tap("Save on device")
        assertEquals(mapOf("count" to JsonValue.Int(5)), savedEntry("orca_saved_page_home", offlineStore(context)))
        assertTrue(File(context.filesDir, "orca_gateway").isDirectory)
    }

    private companion object {
        val JSON = mapOf("content-type" to "application/json")

        fun encode(page: PageResponse): String = Json.encodeToString(PageResponse.serializer(), page)

        fun onTap(action: Action): Map<String, Action> = mapOf("onTap" to action)

        fun navigate(route: String, replace: Boolean = false): Action =
            Action.Navigate(route = JsonValue.String(route), replace = replace.takeIf { it })

        fun sequential(vararg actions: Action): Action = Action.ActionGroup("sequential", actions.toList())

        /** A Text drawing `<label>: <value>` of state [key] in [scope], redrawn when it changes. */
        fun shown(id: String, label: String, key: String, scope: String): ComponentNode {
            val state = JsonValue.Object(mapOf("type" to JsonValue.String("state"), "key" to JsonValue.String(key), "scope" to JsonValue.String(scope)))
            val template = JsonValue.Object(mapOf("type" to JsonValue.String("template"), "template" to JsonValue.String("$label: {{value}}")))
            val data = JsonValue.Object(
                mapOf("type" to JsonValue.String("transform"), "input" to state, "by" to JsonValue.Array(listOf(template))),
            )
            return ComponentNode(
                id, "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, mapOf("data" to data), watches = listOf(key),
            )
        }

        /**
         * Home: `Count: <count>` (page, declared [initialCount]) with Set 5, Save on device,
         * Save for this session and Forget; `Visits: <visits>` (app, 0) with Visit and save;
         * Leave, a `go` to /other (the page is closed).
         */
        fun home(initialCount: Long = 0): PageResponse = PageResponse(
            pageId = "home",
            title = "Home",
            state = listOf(
                StateDefinition("count", StateScope.Page, JsonValue.Int(initialCount)),
                StateDefinition("visits", StateScope.App, JsonValue.Int(0)),
            ),
            components = listOf(
                column("0", "1", "2", "4", "6", "8", "10", "11", "13"),
                shown("1", "Count", "count", "page"),
                button("2", "TextButton", "3", onTap(Action.SetState("count", value = JsonValue.Int(5)))),
                text("3", "Set 5"),
                button("4", "TextButton", "5", onTap(Action.PersistState("count"))),
                text("5", "Save on device"),
                button("6", "TextButton", "7", onTap(Action.PersistState("count", StateScope.Page, "session"))),
                text("7", "Save for this session"),
                button("8", "TextButton", "9", onTap(Action.ClearState("count"))),
                text("9", "Forget"),
                shown("10", "Visits", "visits", "app"),
                button(
                    "11", "TextButton", "12",
                    onTap(sequential(Action.SetState("visits", StateScope.App, JsonValue.Int(3)), Action.PersistState("visits", StateScope.App))),
                ),
                text("12", "Visit and save"),
                button("13", "TextButton", "14", onTap(navigate("/other", replace = true))),
                text("14", "Leave"),
            ),
        )

        /** Other: Back home, a `go` to /home. */
        val OTHER = PageResponse(
            pageId = "other",
            title = "Other",
            components = listOf(
                column("0", "1", "2"),
                text("1", "Other page"),
                button("2", "TextButton", "3", onTap(navigate("/home", replace = true))),
                text("3", "Back home"),
            ),
        )

        /** Login: Sign in sets app `signedIn`, saves it on the device and goes home. */
        val LOGIN = PageResponse(
            pageId = "login",
            title = "Login",
            components = listOf(
                column("0", "1", "2"),
                text("1", "Please sign in"),
                button(
                    "2", "TextButton", "3",
                    onTap(
                        sequential(
                            Action.SetState("signedIn", StateScope.App, JsonValue.Bool(true)),
                            Action.PersistState("signedIn", StateScope.App),
                            navigate("/home", replace = true),
                        ),
                    ),
                ),
                text("3", "Sign in"),
            ),
        )

        /** Two tabs, `home` and `other`, under a server tab bar: `Bar visits: <visits>` and Visit from the bar, which saves app `visits`. */
        val TAB_CONFIG = NavConfig(
            initialRoute = "/home",
            tabs = listOf(TabDef("home", "Home", "home", "/home"), TabDef("other", "Other", "menu", "/other")),
            tabBarComponents = listOf(
                row("bar", "bar-visits", "bar-visit"),
                shown("bar-visits", "Bar visits", "visits", "app"),
                button(
                    "bar-visit", "TextButton", "bar-visit-label",
                    onTap(sequential(Action.SetState("visits", StateScope.App, JsonValue.Int(7)), Action.PersistState("visits", StateScope.App))),
                ),
                text("bar-visit-label", "Visit from the bar"),
            ),
            flows = listOf(NavFlow(name = "main", routes = listOf(NavRoute("home"), NavRoute("other")))),
        )

        /** From the network: /home, sent to /login while app `signedIn` is false (initialAppState). */
        const val CONFIG: String =
            """{"appId":"saved-state","appName":"Saved state","initialRoute":"/home",""" +
                """"initialAppState":{"signedIn":false},"flows":[{"name":"main","routes":[""" +
                """{"path":"home","redirect":{"when":"signedIn","equals":false,"to":"/login"}},""" +
                """{"path":"login"},{"path":"other"}]}]}"""

        /** Static flow `main` at version 1, with `home` and `other` pre-rendered. */
        val STATIC_CONFIG: String =
            """{"appId":"saved-state","appName":"Saved state","initialRoute":"/home","flows":[""" +
                """{"name":"main","version":1,"isStatic":true,"routes":[{"path":"home"},{"path":"other"}],""" +
                """"pages":{"home":${encode(home())},"other":${encode(OTHER)}}}]}"""
    }
}
