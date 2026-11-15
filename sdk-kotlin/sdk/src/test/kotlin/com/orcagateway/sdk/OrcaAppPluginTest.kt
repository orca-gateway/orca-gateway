package com.orcagateway.sdk

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
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
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.text
import com.orcagateway.sdk.system.SystemActions
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import java.net.URI
import java.util.Collections
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * C16.1 and C16.5 on Android, at the OrcaApp level (Flutter's
 * `_OrcaAppState._initialize` and `_initRouter`, sdk/lib/src/widgets/orca_app.dart):
 * the plugins' widget and action names grow the client's capabilities
 * before the first request (standalone custom actions do not), the app's
 * pages keep a plugin node and draw it with the plugin's builder, the
 * merged handlers run on every page's executor (a plugin action named like
 * a built-in replaces it), and a conflict fails the boot with Flutter's
 * message on the error view, with no request made. Swift twin:
 * OrcaAppPluginTests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class OrcaAppPluginTest {
    @get:Rule
    val compose = createComposeRule()

    /**
     * Pages like the engine (412 to the GET, the page to the POST retry);
     * every path gets [page]. `/config` answers [config] when there is one.
     */
    private class PluginEngine(private val config: String? = null) : HttpTransport {
        val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())

        override suspend fun send(request: HttpRequest): HttpResponse {
            requests += request
            if (config != null && request.url.path.endsWith("/config")) {
                return HttpResponse(200, mapOf("content-type" to "application/json"), config.toByteArray())
            }
            if (request.method == "GET") return HttpResponse(412, body = """{"error":"caps_vector_unknown"}""".toByteArray())
            val name = request.url.path.substringAfterLast("/page/")
            val body = Json.encodeToString(PageResponse.serializer(), page.copy(pageId = name, title = name))
            return HttpResponse(200, mapOf("content-type" to "application/json"), body.toByteArray())
        }
    }

    /** Flutter's example `_BadgePlugin` (examples/app/lib/main.dart): the ColoredBadge widget and `hapticFeedback`. */
    private class BadgePlugin : OrcaPlugin {
        override val name: String = "badge"
        override val widgets: Map<String, WidgetBuilder> = mapOf("ColoredBadge" to badgeBuilder)
        override val actions: Map<String, OrcaActionHandler> = mapOf("hapticFeedback" to OrcaActionHandler { _, _ -> })
    }

    /** A plugin with only widgets of [types], for the conflicts. */
    private class WidgetsPlugin(override val name: String, vararg types: String) : OrcaPlugin {
        override val widgets: Map<String, WidgetBuilder> = types.associateWith { badgeBuilder }
    }

    /** A plugin whose `copyToClipboard` records the raw action it gets (C16.5). */
    private class ClipboardPlugin(val handled: MutableList<JsonObject>) : OrcaPlugin {
        override val name: String = "clipboard"
        override val actions: Map<String, OrcaActionHandler> =
            mapOf("copyToClipboard" to OrcaActionHandler { action, _ -> handled += action })
    }

    /** [BadgePlugin]'s widget, counting how often a merge reads the plugin's widgets. */
    private class CountingPlugin : OrcaPlugin {
        var reads = 0
        override val name: String = "badge"
        override val widgets: Map<String, WidgetBuilder>
            get() = mapOf("ColoredBadge" to badgeBuilder).also { reads++ }
    }

    private fun client(engine: PluginEngine) =
        OrcaClient(URI("http://engine.invalid"), appId = "custom", deviceId = "test-device", transport = engine)

    /** The loaded page of the route on top, or null while it loads. */
    private fun topModel(router: OrcaRouter): OrcaPageModel? =
        (router.loader(router.top).phase as? OrcaPageLoader.Phase.Loaded)?.model

    /** Waits, idling the main thread between looks, for the page on top to load. */
    private fun waitForTop(router: OrcaRouter): OrcaPageModel {
        compose.waitUntil(5_000) { compose.runOnIdle { topModel(router) } != null }
        return assertNotNull(compose.runOnIdle { topModel(router) })
    }

    @After
    fun forgetTheHost() {
        HostActivity.content = {}
    }

    /** An app's activity, set up and resumed: its onCreate shows [content], made again by a recreation. */
    private fun host(content: @Composable () -> Unit): ActivityController<HostActivity> {
        HostActivity.content = content
        return Robolectric.buildActivity(HostActivity::class.java).setup()
    }

    private fun waitForBadge() {
        compose.waitUntil(5_000) { compose.onAllNodes(hasTestTag(BADGE_TAG)).fetchSemanticsNodes().isNotEmpty() }
    }

    private fun waitForText(text: String) {
        compose.waitUntil(5_000) { compose.onAllNodes(hasText(text)).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun c16_1_pluginNamesAreAdvertisedAndTheFirstPageKeepsAndDrawsThePluginWidget() {
        val engine = PluginEngine()
        val client = client(engine)
        val plainHash = client(PluginEngine()).capsHash
        val shared = WidgetBuilders.shared.types
        val rated = mutableListOf<JsonObject>()
        val router = OrcaRouter(client, path = "home")
        compose.setContent {
            OrcaApp(
                router,
                plugins = listOf(BadgePlugin()),
                customActions = mapOf("rateApp" to OrcaActionHandler { action, _ -> rated += action }),
            )
        }
        val model = waitForTop(router)

        // The plugin's names are advertised, bare and `custom:`; the standalone action is not.
        val caps = client.capabilities
        assertTrue("ColoredBadge" in caps.widgets)
        assertTrue("hapticFeedback" in caps.actionKinds)
        assertTrue("custom:hapticFeedback" in caps.actionKinds)
        assertFalse("rateApp" in caps.actionKinds)
        assertFalse("custom:rateApp" in caps.actionKinds)

        // Every request, the first one too, carries the grown vector's hash.
        val sent = engine.requests.toList().map { it.headers["x-orca-caps-hash"] }
        assertEquals(listOf(client.capsHash, client.capsHash), sent)
        assertNotEquals(plainHash, client.capsHash)

        // The page keeps the plugin node and draws it with the plugin's builder.
        assertEquals("ColoredBadge", model.resolve("1")?.type)
        assertTrue(model.renderer.registry.supports("ColoredBadge"))
        assertSame(badgeBuilder, model.builders["ColoredBadge"])
        compose.onNodeWithTag(BADGE_TAG).assertIsDisplayed()
        assertTrue(model.builders.reportedMissing.isEmpty())

        // The standalone custom action runs on the page's executor.
        compose.onNodeWithText("Rate").performClick()
        compose.waitForIdle()
        assertEquals(listOf(JsonObject(mapOf("type" to JsonPrimitive("custom:rateApp")))), rated)

        // The plugin builder went into the app's own builders, never the shared ones.
        assertEquals(shared, WidgetBuilders.shared.types)
        assertFalse("ColoredBadge" in WidgetBuilders.shared.types)
    }

    @Test
    fun c16_1_anAppBootedFromTheConfigAsksItWithThePluginNamesAndItsPagesDrawThePluginWidget() {
        val engine = PluginEngine(config = """{"initialRoute":"/home","flows":[{"name":"main","routes":[{"path":"home"}]}]}""")
        val client = client(engine)
        val plainHash = client(PluginEngine()).capsHash
        compose.setContent { OrcaApp(client, path = null, plugins = listOf(BadgePlugin())) }

        compose.waitUntil(5_000) { compose.onAllNodes(hasTestTag(BADGE_TAG)).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag(BADGE_TAG).assertIsDisplayed()

        // The plugins were merged before the config was asked for.
        val config = engine.requests.toList().first { it.url.path.endsWith("/config") }
        assertEquals(client.capsHash, config.headers["x-orca-caps-hash"])
        assertNotEquals(plainHash, client.capsHash)
    }

    /**
     * C16.1 with A1.13 (kt): OrcaApp(client) merges its plugins once per
     * router it keeps: the activity recreated by a rotation draws the plugin
     * widget again with no new merge and no new request.
     */
    @Test
    fun c16_1_aKeptRouterKeepsItsMergedPluginsThroughARecreation() {
        val engine = PluginEngine()
        val client = client(engine)
        val plugin = CountingPlugin()
        val activity = host { OrcaApp(client, path = "home", plugins = listOf(plugin)) }
        waitForBadge()
        compose.waitForIdle()
        val merged = plugin.reads
        val requests = engine.requests.size
        assertTrue(merged > 0)

        activity.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag(BADGE_TAG).assertIsDisplayed()
        assertEquals(merged, plugin.reads)
        assertEquals(requests, engine.requests.size)
    }

    /**
     * C16.1 with A1.13 (kt): OrcaApp(client, path = null) merges its plugins
     * once per boot it keeps: after a recreation the config's page draws the
     * plugin widget with no new merge, and nothing is asked again.
     */
    @Test
    fun c16_1_aKeptConfigBootKeepsItsMergedPluginsThroughARecreation() {
        val engine = PluginEngine(config = """{"initialRoute":"/home","flows":[{"name":"main","routes":[{"path":"home"}]}]}""")
        val client = client(engine)
        val plugin = CountingPlugin()
        val activity = host { OrcaApp(client, path = null, plugins = listOf(plugin)) }
        waitForBadge()
        compose.waitForIdle()
        val merged = plugin.reads
        val requests = engine.requests.size
        assertTrue(merged > 0)

        activity.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag(BADGE_TAG).assertIsDisplayed()
        assertEquals(merged, plugin.reads)
        assertEquals(requests, engine.requests.size)
    }

    @Test
    fun c16_5_aPluginActionNamedLikeABuiltInReplacesItOnEveryPageOfTheApp() {
        val engine = PluginEngine()
        val copied = mutableListOf<String>()
        val effects = mutableListOf<ActionEffect>()
        val handled = mutableListOf<JsonObject>()
        val system = SystemActions(open = {}, copy = { copied += it }, share = { _, _ -> })
        val router = OrcaRouter(client(engine), path = "home", system = system)
        router.onEffect = { effects += it }
        compose.setContent { OrcaApp(router, plugins = listOf(ClipboardPlugin(handled))) }
        waitForTop(router)

        // The first page: the handler gets the raw action; the built-in copy never runs.
        compose.onNodeWithText("Copy").performClick()
        compose.waitForIdle()
        val raw = JsonObject(mapOf("type" to JsonPrimitive("copyToClipboard"), "text" to JsonPrimitive("ORCA-42")))
        assertEquals(listOf(raw), handled)

        // A page the router pushes has the handler too.
        compose.runOnIdle { router.navigate("detail") }
        val pushed = waitForTop(router)
        assertEquals("detail", pushed.page.pageId)
        val copy = assertNotNull(pushed.resolve("2"))
        runBlocking { pushed.fire("onTap", on = copy)?.join() }
        assertEquals(listOf(raw, raw), handled)

        assertTrue(copied.isEmpty())
        assertFalse(effects.any { it.type == "copyToClipboard" })
    }

    @Test
    fun c16_1_twoPluginsWithTheSameWidgetFailTheBootOnTheErrorViewAndFetchNothing() {
        val engine = PluginEngine()
        val client = client(engine)
        val shared = WidgetBuilders.shared.types
        compose.setContent {
            OrcaApp(client, enableOffline = true, plugins = listOf(WidgetsPlugin("a", "X"), WidgetsPlugin("b", "X")))
        }

        val message = "Widget type \"X\" from plugin \"b\" conflicts with plugin \"a\"."
        waitForText(message)
        compose.onNodeWithText(message).assertIsDisplayed()
        compose.onNodeWithText("Could not load this page").assertIsDisplayed()
        compose.waitForIdle()

        // Not even the version check: nothing is fetched, nothing advertised.
        assertTrue(engine.requests.isEmpty())
        assertFalse("X" in client.capabilities.widgets)
        assertEquals(shared, WidgetBuilders.shared.types)
    }

    @Test
    fun c16_1_theBootModelFailsWithTheConflictMessageAndNeverChecks(): Unit = runBlocking {
        val engine = PluginEngine()
        val boot = OrcaBoot(client(engine), enableOffline = true) {
            throw IllegalArgumentException("Widget type \"X\" from plugin \"b\" conflicts with plugin \"a\".")
        }
        assertEquals(OrcaBoot.Phase.Failed, boot.phase)
        assertEquals("Widget type \"X\" from plugin \"b\" conflicts with plugin \"a\".", boot.failure)

        boot.start()
        assertEquals(OrcaBoot.Phase.Failed, boot.phase)
        assertTrue(engine.requests.isEmpty())

        // A setup that does not throw boots as before.
        val ready = OrcaBoot(client(engine), enableOffline = false) {}
        assertEquals(OrcaBoot.Phase.Ready, ready.phase)
        assertEquals(null, ready.failure)
    }

    private companion object {
        const val BADGE_TAG = "orcaAppPlugin.coloredBadge"

        /** Draws the badge's label. */
        val badgeBuilder: WidgetBuilder = { node, _, modifier ->
            Box(modifier.testTag(BADGE_TAG)) { BasicText(node["label"]?.stringValue ?: "") }
        }

        /**
         * Node 1 a ColoredBadge, node 2 a "Copy" button (`copyToClipboard`
         * of `ORCA-42`), node 4 a "Rate" button (`custom:rateApp`).
         */
        val page: PageResponse = PageResponse(
            pageId = "home",
            title = "home",
            components = listOf(
                column("0", "1", "2", "4"),
                ComponentNode(
                    "1", "ColoredBadge", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
                    props = mapOf("label" to JsonValue.String("gold")),
                ),
                button("2", "TextButton", "3", mapOf("onTap" to Action.CopyToClipboard(text = JsonValue.String("ORCA-42")))),
                text("3", "Copy"),
                button("4", "TextButton", "5", mapOf("onTap" to Action.Custom(JsonValue.obj("type" to "custom:rateApp")))),
                text("5", "Rate"),
            ),
        )
    }
}
