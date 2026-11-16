package com.orcagateway.sdk

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasProgressBarRangeInfo
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.LayoutDirection
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.client.OrcaErrorInfo
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import kotlinx.coroutines.CompletableDeferred
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.URI
import java.util.Collections
import java.util.Locale
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * C18.1 and C18.3 on Android. C18.1: OrcaApp's host boot views, Flutter
 * OrcaApp's `splashWidget`, `loadingWidget`, `errorBuilder` and
 * `forceUpdateBuilder` (sdk/lib/src/widgets/orca_app.dart, `_buildSplash`,
 * `_buildError`, `_buildForceUpdate`): the splash (else the loading view)
 * while the version check runs and while `/config` loads, the error view with
 * the config boot's or the plugin conflict's error, the force-update view;
 * pages keep the SDK's spinner and error screen. C18.3: a colour scheme and a
 * locale given to OrcaApp reach its screens and pages, a Scaffold page stays
 * light as Flutter's builders pin a light `ThemeData()`, and `x-orca-locale`
 * stays the device's. Swift twin: AppShellTests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class AppShellTest {
    @get:Rule
    val compose = createComposeRule()

    /**
     * Answers like the engine: [version] to `/version`, a one-route config to
     * `/config` (or [configStatus]), and for a page 412 to the GET and [page]
     * to the POST retry (or [pageStatus] to both). A request whose kind
     * (`version`, `config`, `page`) is in [holds] is answered once its gate
     * is opened.
     */
    private class ShellEngine(
        var configStatus: Int? = null,
        var pageStatus: Int? = null,
        private val version: String = """{"flows":{}}""",
        private val page: ByteArray = counterPage,
        private val holds: Map<String, CompletableDeferred<Unit>> = emptyMap(),
    ) : HttpTransport {
        val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())

        override suspend fun send(request: HttpRequest): HttpResponse {
            requests += request
            val path = request.url.path
            val kind = when {
                path.endsWith("/version") -> "version"
                path.endsWith("/config") -> "config"
                else -> "page"
            }
            holds[kind]?.await()
            return when (kind) {
                "version" -> HttpResponse(200, JSON, version.toByteArray())
                "config" -> configStatus?.let { HttpResponse(it, body = BODY.toByteArray()) }
                    ?: HttpResponse(200, JSON, CONFIG.toByteArray())
                else -> pageStatus?.let { HttpResponse(it, body = BODY.toByteArray()) }
                    ?: if (request.method == "GET") {
                        HttpResponse(412, body = """{"error":"caps_vector_unknown"}""".toByteArray())
                    } else {
                        HttpResponse(200, JSON, page)
                    }
            }
        }

        val paths: List<String> get() = requests.toList().map { it.url.path }
    }

    /** A plugin with one widget, `X`, for the conflict. */
    private class WidgetsPlugin(override val name: String) : OrcaPlugin {
        override val widgets: Map<String, WidgetBuilder> = mapOf("X" to { _, _, _ -> })
    }

    /** What a `Probe` node saw where it was drawn. */
    private class Seen(val colors: ColorScheme, val locale: Locale, val direction: LayoutDirection)

    /** The `Probe` widget: records, by node id, the theme, locale and layout direction it is drawn under. */
    private class ProbePlugin : OrcaPlugin {
        val seen: MutableMap<String, Seen> = Collections.synchronizedMap(HashMap())
        override val name: String = "probe"
        override val widgets: Map<String, WidgetBuilder> = mapOf(
            "Probe" to { node, _, _ ->
                seen[node.id] = Seen(MaterialTheme.colorScheme, LocalConfiguration.current.locales[0], LocalLayoutDirection.current)
            },
        )
    }

    private fun client(engine: ShellEngine) =
        OrcaClient(URI("http://engine.invalid"), appId = "counter", apiKey = "demo-key", transport = engine)

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    private fun tagged(tag: String): Int = compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().size

    private fun spinners(): Int =
        compose.onAllNodes(hasProgressBarRangeInfo(ProgressBarRangeInfo.Indeterminate)).fetchSemanticsNodes().size

    private fun waitForText(text: String) {
        compose.waitUntil(5_000) { count(text) > 0 }
    }

    private fun waitForTag(tag: String) {
        compose.waitUntil(5_000) { tagged(tag) > 0 }
    }

    private fun waitForPath(engine: ShellEngine, suffix: String) {
        compose.waitUntil(5_000) { engine.paths.any { it.endsWith(suffix) } }
    }

    private fun textColor(text: String) = run {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithText(text).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        results.single().layoutInput.style.color
    }

    @Test
    fun c18_1_aHostSplashShowsWhileTheVersionCheckRunsAndWhileTheConfigLoads() {
        val version = CompletableDeferred<Unit>()
        val config = CompletableDeferred<Unit>()
        val engine = ShellEngine(holds = mapOf("version" to version, "config" to config))
        compose.setContent {
            OrcaApp(
                client(engine),
                path = null,
                enableOffline = true,
                loading = { Text("host loading", Modifier.testTag(LOADING)) },
                splash = { Text("host splash", Modifier.testTag(SPLASH)) },
            )
        }

        // The version check runs: the splash, not the loading view nor the SDK spinner. The boot's
        // preload asks /version off the main thread, so the splash is up before the request is.
        waitForTag(SPLASH)
        waitForPath(engine, "/version")
        assertEquals(listOf("/api/v1/app/counter/version"), engine.paths)
        compose.onNodeWithTag(SPLASH).assertIsDisplayed()
        assertEquals(0, tagged(LOADING))
        assertEquals(0, spinners())

        // The config loads: the splash again.
        version.complete(Unit)
        waitForPath(engine, "/config")
        compose.onNodeWithTag(SPLASH).assertIsDisplayed()
        assertEquals(0, tagged(LOADING))
        assertEquals(0, spinners())

        config.complete(Unit)
        waitForText("Counter Example")
        assertEquals(0, tagged(SPLASH))
    }

    @Test
    fun c18_1_withOnlyALoadingViewItShowsWhereTheSplashWould() {
        val version = CompletableDeferred<Unit>()
        val config = CompletableDeferred<Unit>()
        val engine = ShellEngine(holds = mapOf("version" to version, "config" to config))
        compose.setContent {
            OrcaApp(
                client(engine),
                path = null,
                enableOffline = true,
                loading = { Text("host loading", Modifier.testTag(LOADING)) },
            )
        }

        waitForTag(LOADING)
        waitForPath(engine, "/version")
        assertEquals(listOf("/api/v1/app/counter/version"), engine.paths)
        compose.onNodeWithTag(LOADING).assertIsDisplayed()
        assertEquals(0, spinners())

        version.complete(Unit)
        waitForPath(engine, "/config")
        compose.onNodeWithTag(LOADING).assertIsDisplayed()
        assertEquals(0, spinners())

        config.complete(Unit)
        waitForText("Counter Example")
        assertEquals(0, tagged(LOADING))
    }

    @Test
    fun c18_1_aHostErrorViewGetsTheConfigBootsErrorAndIsAllThatIsDrawn() {
        var received: Throwable? = null
        val engine = ShellEngine(configStatus = 500)
        compose.setContent {
            OrcaApp(
                client(engine),
                path = null,
                error = { e ->
                    received = e
                    Text("host error", Modifier.testTag(ERROR))
                },
            )
        }

        waitForTag(ERROR)
        val error = assertNotNull(received)
        assertEquals(OrcaClientException.Http(500, BODY), error)
        assertEquals("Server Error", OrcaErrorInfo.from(error).title)
        // The SDK's screen and its retry are not drawn.
        assertEquals(0, tagged("orca.error"))
        assertEquals(0, count("Try again"))
        assertEquals(listOf("/api/v1/app/counter/config"), engine.paths)
    }

    @Test
    fun c18_1_aHostErrorViewGetsThePluginConflictsErrorAndNothingIsFetched() {
        var received: Throwable? = null
        val engine = ShellEngine()
        val router = OrcaRouter(client(engine), path = "home")
        compose.setContent {
            OrcaApp(
                router,
                enableOffline = true,
                plugins = listOf(WidgetsPlugin("a"), WidgetsPlugin("b")),
                error = { e ->
                    received = e
                    Text("host error", Modifier.testTag(ERROR))
                },
            )
        }

        waitForTag(ERROR)
        val error = assertIs<IllegalArgumentException>(received)
        assertEquals("Widget type \"X\" from plugin \"b\" conflicts with plugin \"a\".", error.message)
        assertEquals(0, tagged("orca.error"))
        compose.waitForIdle()
        assertTrue(engine.requests.isEmpty())
    }

    @Test
    fun c18_1_aHostForceUpdateViewReplacesTheDefaultAfterTheSplash() {
        val version = CompletableDeferred<Unit>()
        val engine = ShellEngine(version = """{"flows":{"home":1},"forceUpdate":true}""", holds = mapOf("version" to version))
        compose.setContent {
            OrcaApp(
                client(engine),
                path = "home",
                enableOffline = true,
                splash = { Text("host splash", Modifier.testTag(SPLASH)) },
                forceUpdate = { Text("host update", Modifier.testTag(FORCE_UPDATE)) },
            )
        }

        waitForTag(SPLASH)
        version.complete(Unit)
        waitForTag(FORCE_UPDATE)
        assertEquals(0, tagged("orca.forceUpdate"))
        assertEquals(0, count("Update required. Please update the app."))
        assertEquals(0, tagged(SPLASH))
        compose.waitForIdle()
        // No page is ever fetched.
        assertEquals(listOf("/api/v1/app/counter/version"), engine.paths)
    }

    @Test
    fun c18_1_pagesUnderOrcaAppKeepTheSdkSpinnerAndErrorScreen() {
        var errors = 0
        val held = CompletableDeferred<Unit>()
        val engine = ShellEngine(pageStatus = 404, holds = mapOf("page" to held))
        compose.setContent {
            OrcaApp(
                client(engine),
                path = "home",
                loading = { Text("host loading", Modifier.testTag(LOADING)) },
                splash = { Text("host splash", Modifier.testTag(SPLASH)) },
                error = {
                    errors++
                    Text("host error", Modifier.testTag(ERROR))
                },
                forceUpdate = { Text("host update", Modifier.testTag(FORCE_UPDATE)) },
            )
        }

        // The page loads: the SDK's spinner.
        waitForPath(engine, "/page/home")
        compose.waitUntil(5_000) { spinners() > 0 }
        assertEquals(0, tagged(LOADING))
        assertEquals(0, tagged(SPLASH))

        // The page answers 404: the SDK's screen with its retry; the host's error view is not called.
        held.complete(Unit)
        waitForText("Not Found")
        compose.onNodeWithTag("orca.error").assertIsDisplayed()
        compose.onNodeWithText("Try again").assertIsDisplayed()
        assertEquals(0, tagged(ERROR))
        assertEquals(0, errors)
    }

    @Test
    fun c18_3_aDarkColorSchemeReachesTheBootAndPageErrorScreens() {
        val dark = darkColorScheme()
        val engine = ShellEngine(configStatus = 500)
        compose.setContent { OrcaApp(client(engine), path = null, colorScheme = dark) }

        waitForText("Server Error")
        assertEquals(dark.onSurface, textColor("Server Error"))

        engine.configStatus = null
        engine.pageStatus = 404
        compose.onNodeWithText("Try again").performClick()
        waitForText("Not Found")
        assertEquals(dark.onSurface, textColor("Not Found"))
        assertEquals(dark.onSurfaceVariant, textColor("The requested page could not be found."))
    }

    @Test
    fun c18_3_aPageReadsTheDarkColorSchemeWhileAScaffoldPageReadsLight() {
        val dark = darkColorScheme()
        val light = lightColorScheme()
        val probe = ProbePlugin()
        val engine = ShellEngine(page = probePage)
        compose.setContent { OrcaApp(client(engine), path = "home", plugins = listOf(probe), colorScheme = dark) }

        compose.waitUntil(5_000) { probe.seen.size == 2 }
        val outside = assertNotNull(probe.seen["out"])
        assertEquals(dark.background, outside.colors.background)
        assertEquals(dark.primary, outside.colors.primary)
        assertEquals(dark.onSurface, outside.colors.onSurface)
        // Flutter's builders wrap a Scaffold in a light ThemeData(): its body reads light.
        val inside = assertNotNull(probe.seen["in"])
        assertEquals(light.background, inside.colors.background)
        assertEquals(light.primary, inside.colors.primary)
        assertEquals(light.onSurface, inside.colors.onSurface)
    }

    @Test
    fun c18_3_aLocaleReachesThePagesItsLayoutDirectionStaysAndXOrcaLocaleStaysTheDevices() {
        val arabic = Locale.forLanguageTag("ar-EG")
        val probe = ProbePlugin()
        val engine = ShellEngine(page = probePage)
        compose.setContent { OrcaApp(client(engine), path = null, plugins = listOf(probe), locale = arabic) }

        compose.waitUntil(5_000) { probe.seen.size == 2 }
        for (id in listOf("out", "in")) {
            val seen = assertNotNull(probe.seen[id])
            assertEquals(arabic, seen.locale, id)
            // Flutter without the host's localizations keeps left to right.
            assertEquals(LayoutDirection.Ltr, seen.direction, id)
        }
        // Nothing is sent: every request, /config and the page, carries the device's locale.
        val sent = engine.requests.toList()
        assertEquals(listOf("/config", "/page/home", "/page/home"), sent.map { "/" + it.url.path.substringAfter("/counter/") })
        for (request in sent) assertEquals("en_US", request.headers["x-orca-locale"], request.url.path)
    }

    private companion object {
        const val BODY = """{"error":"boom"}"""
        val JSON = mapOf("content-type" to "application/json")
        const val CONFIG = """{"initialRoute":"/home","flows":[{"name":"main","routes":[{"path":"home"}]}]}"""

        const val LOADING = "host.loading"
        const val SPLASH = "host.splash"
        const val ERROR = "host.error"
        const val FORCE_UPDATE = "host.forceUpdate"

        val counterPage: ByteArray = requireNotNull(AppShellTest::class.java.getResource("/pages/counter-home.json")).readBytes()

        /** A Probe at the root's top, and one in the body of a Scaffold under it. */
        val probePage: ByteArray = Json.encodeToString(
            PageResponse.serializer(),
            page(
                column("root", "out", "scaffold"),
                leaf("out", "Probe"),
                ComponentNode(
                    "scaffold", "Scaffold", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
                    props = mapOf("body" to JsonValue.String("in")), children = listOf("in"),
                ),
                leaf("in", "Probe"),
            ),
        ).toByteArray()
    }
}
