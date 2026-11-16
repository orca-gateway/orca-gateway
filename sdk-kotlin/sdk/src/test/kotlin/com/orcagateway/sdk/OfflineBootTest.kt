package com.orcagateway.sdk

import android.content.Context
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.test.assertIsDisplayed
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
import com.orcagateway.core.client.PreloadResult
import com.orcagateway.core.client.StaticFlowManager
import com.orcagateway.core.client.preload
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.DevToolsReporter
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.After
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
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * C14.1, C14.2 and C14.5 on Android, as Flutter's OrcaApp does them
 * (sdk/lib/src/widgets/orca_app.dart, orca_page.dart): with `enableOffline`
 * the config boot runs `preload` and saves the config and the static flow's
 * pre-rendered pages; a static page, visited or not, opens from the cache
 * with no request, also offline after a restart; a network page is never
 * saved; an offline cold start boots from the saved config; a preloaded
 * config and the same cache fetch nothing. Every cache is a file store in a
 * temporary directory; a new manager over the same directory is a restart.
 * Swift twin: OfflineBootTests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class OfflineBootTest {
    @get:Rule
    val compose = createComposeRule()

    @get:Rule
    val folder = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()

    @After
    fun reset() {
        OrcaDebug.reporter = null
    }

    /**
     * The static-flows demo (examples/server/static-flows.ts), small: flow
     * `main` at version 4, static, `home` and `about` pre-rendered in
     * `/config`, `profile` dynamic, initialRoute `/home`. `/version` answers
     * [version]; a page asked of the network is "<name> from the network".
     * Off [online], every request fails as an unreachable server does.
     */
    private class StaticFlowsEngine(
        var online: Boolean = true,
        var version: String = """{"flows":{"main":4}}""",
    ) : HttpTransport {
        val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())

        override suspend fun send(request: HttpRequest): HttpResponse {
            requests += request
            if (!online) throw ConnectException("unreachable")
            val path = request.url.path
            return when {
                path.endsWith("/version") -> HttpResponse(200, body = version.toByteArray())
                path.endsWith("/config") -> HttpResponse(200, mapOf("content-type" to "application/json"), CONFIG.toByteArray())
                else -> {
                    val name = path.substringAfterLast("/page/")
                    val page = PageResponse(pageId = name, title = name, components = listOf(text("0", "$name from the network")))
                    HttpResponse(200, body = encode(page).toByteArray())
                }
            }
        }

        /** What was asked, after `/api/v1/app/static-flows/`, in order. */
        val paths: List<String> get() = requests.toList().map { it.url.path.substringAfter("/app/static-flows/") }

        val client: OrcaClient get() = OrcaClient(URI("http://engine.invalid"), appId = "static-flows", transport = this)
    }

    private fun waitForText(text: String) {
        compose.waitUntil(5_000) { compose.onAllNodes(hasText(text)).fetchSemanticsNodes().isNotEmpty() }
    }

    /** A manager over the temporary directory: a new one over the same directory is an app restart. */
    private fun cache() = StaticFlowManager(FileKeyValueStore(folder.root))

    /** One online boot, as a host's own preload would run it: the config and the static pages saved. */
    private fun bootOnceOnline(): NavConfig = runBlocking {
        assertIs<PreloadResult.Success>(preload(StaticFlowsEngine().client, cache())).config
    }

    /** The page paths the saved pages of flow `main` hold. */
    private fun savedPagePaths(directory: File): Set<String> {
        val saved = assertNotNull(FileKeyValueStore(directory).getString("orca_pages_main"))
        return requireNotNull(JsonValue.parse(saved).objectValue).keys
    }

    @Test
    fun c14_1_afterAnOnlineBootEveryStaticPageOpensFromTheCacheAndADynamicOneFromTheNetwork() {
        val engine = StaticFlowsEngine()
        val cache = cache()
        compose.setContent { OrcaApp(engine.client, enableOffline = true, staticFlowManager = cache) }

        waitForText("Home from the cache")
        assertEquals(listOf("version", "config"), engine.paths)

        // Never visited, saved at boot: no request.
        compose.onNodeWithText("About").performClick()
        waitForText("About from the cache")
        compose.onNodeWithText("About from the cache").assertIsDisplayed()
        assertEquals(listOf("version", "config"), engine.paths)

        // Dynamic: the network, and what it answered is not saved.
        compose.onNodeWithText("Profile").performClick()
        waitForText("profile from the network")
        assertEquals(listOf("version", "config", "page/profile"), engine.paths)
        assertEquals(setOf("home", "about"), savedPagePaths(folder.root))
    }

    @Test
    fun c14_1_afterARestartWithTheServerDownStaticPagesStillOpenFromTheCache() {
        bootOnceOnline()
        val engine = StaticFlowsEngine(online = false)
        val cache = cache()
        compose.setContent { OrcaApp(engine.client, enableOffline = true, staticFlowManager = cache) }

        waitForText("Home from the cache")
        compose.onNodeWithText("About").performClick()
        waitForText("About from the cache")
        assertEquals(listOf("version"), engine.paths)

        // Not saved: the page's error view, as today: Flutter's for a server never reached.
        compose.onNodeWithText("Profile").performClick()
        waitForText("Connection Failed")
        compose.onNodeWithText("Unable to reach the server. Please check your network and server status.").assertIsDisplayed()
        assertEquals(listOf("version", "page/profile"), engine.paths)
    }

    @Test
    fun c14_1_aPageFromTheCacheSendsNoTimingEventAndANetworkPageDoes(): Unit = runBlocking {
        val config = bootOnceOnline()
        val recorder = Recorder()
        OrcaDebug.reporter = recorder
        val engine = StaticFlowsEngine()
        val boot = OrcaAppBoot(engine.client).also { it.staticFlowManager = cache() }
        boot.start(config)
        val router = assertIs<OrcaAppBoot.Phase.Ready>(boot.phase).router

        val home = router.loader(router.root)
        home.loadIfNeeded(context)
        assertIs<OrcaPageLoader.Phase.Loaded>(home.phase).model.appeared()
        assertEquals(emptyList(), recorder.of("timing"))
        assertEquals(emptyList(), engine.paths)

        router.navigate("/profile")
        val profile = router.loader(router.top)
        profile.loadIfNeeded(context)
        assertIs<OrcaPageLoader.Phase.Loaded>(profile.phase).model.appeared()
        assertEquals(1, recorder.of("timing").size)
        assertEquals(listOf("page/profile"), engine.paths)
    }

    @Test
    fun c14_2_anOfflineColdStartBootsFromTheSavedConfigAtItsInitialRoute() {
        bootOnceOnline()
        val engine = StaticFlowsEngine(online = false)
        val cache = cache()
        val events = Collections.synchronizedList(ArrayList<RouteChangeEvent>())
        compose.setContent {
            OrcaApp(engine.client, enableOffline = true, staticFlowManager = cache, onRouteChanged = { events += it })
        }

        waitForText("Home from the cache")
        assertEquals(listOf("/home"), events.toList().map { it.location })
        assertEquals(listOf("version"), engine.paths)
    }

    @Test
    fun c14_2_withNothingSavedTheBootShowsFluttersErrorForItAndTryAgainRunsPreloadAgain() {
        val engine = StaticFlowsEngine(online = false)
        val cache = cache()
        compose.setContent { OrcaApp(engine.client, enableOffline = true, staticFlowManager = cache) }

        // Flutter's buildOrcaError for Exception('No network and no cached config available'): its
        // default branch, and no other text. Not "Connection Failed": the boot's own error, not /version's.
        waitForText("Something Went Wrong")
        compose.onNodeWithText("An unexpected error occurred. Please try again.").assertIsDisplayed()
        assertEquals(0, compose.onAllNodes(hasText("No network and no cached config available")).fetchSemanticsNodes().size)
        assertEquals(0, compose.onAllNodes(hasText("Connection Failed")).fetchSemanticsNodes().size)
        assertEquals(listOf("version"), engine.paths)

        engine.online = true
        compose.onNodeWithText("Try again").performClick()
        waitForText("Home from the cache")
        assertEquals(listOf("version", "version", "config"), engine.paths)
    }

    @Test
    fun c14_2_freshVersionsUseTheSavedConfigWithNoConfigRequest() {
        bootOnceOnline()
        val engine = StaticFlowsEngine()
        val cache = cache()
        compose.setContent { OrcaApp(engine.client, enableOffline = true, staticFlowManager = cache) }

        waitForText("Home from the cache")
        assertEquals(listOf("version"), engine.paths)
    }

    @Test
    fun c14_2_withoutAManagerTheCacheIsSavedUnderFilesDirOrcaGateway() {
        val engine = StaticFlowsEngine()
        compose.setContent { OrcaApp(engine.client, enableOffline = true) }

        waitForText("Home from the cache")
        val directory = File(context.filesDir, "orca_gateway")
        assertNotNull(FileKeyValueStore(directory).getString("orca_nav_config"))
        assertEquals(setOf("home", "about"), savedPagePaths(directory))
    }

    @Test
    fun c14_5_aPreloadedConfigAndTheSameCacheFetchNothingAndShowTheAppOnTheFirstFrame() {
        val config = bootOnceOnline()
        val engine = StaticFlowsEngine()
        val cache = cache()
        val events = Collections.synchronizedList(ArrayList<RouteChangeEvent>())
        var atFirstFrame: List<String>? = null
        compose.setContent {
            OrcaApp(
                engine.client,
                enableOffline = true,
                onRouteChanged = { events += it },
                preloadedConfig = config,
                staticFlowManager = cache,
            )
            // Once, after the effects of the first composition above: the router's are among them.
            DisposableEffect(Unit) {
                atFirstFrame = events.toList().map { it.location }
                onDispose {}
            }
        }

        // The first frame is the app, not the spinner: its router already reported where it stands.
        assertEquals(listOf("/home"), atFirstFrame)
        waitForText("Home from the cache")
        compose.onNodeWithText("About").performClick()
        waitForText("About from the cache")
        // No /version (the gate does not run), no /config, no page.
        assertEquals(emptyList(), engine.paths)
    }

    @Test
    fun c14_5_aBootGivenAPreloadedConfigIsReadyAtOnce() {
        val config = bootOnceOnline()
        val engine = StaticFlowsEngine()
        val boot = OrcaAppBoot(engine.client).also {
            it.staticFlowManager = cache()
            it.enableOffline = true
        }
        assertIs<OrcaAppBoot.Phase.Loading>(boot.phase)

        boot.start(config)

        assertEquals("/home", assertIs<OrcaAppBoot.Phase.Ready>(boot.phase).router.top.location)
        assertEquals(emptyList(), engine.paths)
    }

    @Test
    fun c14_2_preloadsForceUpdateSetsUpdateRequiredAndLeavesThePhasesAsTheyWere(): Unit = runBlocking {
        val engine = StaticFlowsEngine(version = """{"flows":{"main":4},"forceUpdate":true}""")
        val boot = OrcaAppBoot(engine.client).also {
            it.staticFlowManager = cache()
            it.enableOffline = true
        }

        boot.reload(context)

        // OrcaApp reads the flag and shows the force-update screen (Swift twin `updateRequired`).
        assertTrue(boot.updateRequired)
        // A host's exhaustive `when` over the phases of before compiles unchanged: no new case.
        val shown = when (boot.phase) {
            OrcaAppBoot.Phase.Loading -> "loading"
            is OrcaAppBoot.Phase.Ready -> "ready"
            is OrcaAppBoot.Phase.Failed -> "failed"
        }
        assertEquals("loading", shown)
        assertEquals(listOf("version"), engine.paths)
    }

    @Test
    fun c14_5_offlineStoreIsTheStoreOrcaAppUsesUnderFilesDirOrcaGateway() {
        assertEquals(File(context.filesDir, "orca_gateway"), offlineStore(context).directory)
    }

    @Test
    fun c14_5_preloadsForceUpdateIsTheHostsToShow(): Unit = runBlocking {
        val engine = StaticFlowsEngine(version = """{"flows":{"main":4},"forceUpdate":true}""")
        val cache = cache()

        // What the host awaits in its own splash; it shows its own update screen, and OrcaApp is never made.
        assertEquals(PreloadResult.ForceUpdate, preload(engine.client, cache))
        assertEquals(listOf("version"), engine.paths)
        assertNull(cache.loadConfig())
    }

    /** Keeps every DevTools event it is given, from any thread. */
    private class Recorder : DevToolsReporter {
        private val events = mutableListOf<DevToolsEvent>()

        override fun report(event: DevToolsEvent) {
            synchronized(events) { events += event }
        }

        fun of(type: String): List<DevToolsEvent> = synchronized(events) { events.filter { it.type == type } }
    }

    private companion object {
        fun encode(page: PageResponse): String = Json.encodeToString(PageResponse.serializer(), page)

        fun navigate(route: String): Map<String, Action> = mapOf("onTap" to Action.Navigate(route = JsonValue.String(route)))

        /** Home: a line and a button to /about. */
        val HOME = PageResponse(
            pageId = "home",
            title = "Home",
            components = listOf(
                column("0", "1", "2"),
                text("1", "Home from the cache"),
                button("2", "TextButton", "3", navigate("/about")),
                text("3", "About"),
            ),
        )

        /** About: a line and a button to /profile. */
        val ABOUT = PageResponse(
            pageId = "about",
            title = "About",
            components = listOf(
                column("0", "1", "2"),
                text("1", "About from the cache"),
                button("2", "TextButton", "3", navigate("/profile")),
                text("3", "Profile"),
            ),
        )

        val CONFIG: String =
            """{"appId":"static-flows","appName":"Static Flows Demo","initialRoute":"/home","flows":[""" +
                """{"name":"main","version":4,"isStatic":true,""" +
                """"routes":[{"path":"home"},{"path":"about"},{"path":"profile","isDynamic":true}],""" +
                """"pages":{"home":${encode(HOME)},"about":${encode(ABOUT)}}}]}"""
    }
}
