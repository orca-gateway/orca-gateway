package com.orcagateway.core.render

import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.StubEngine
import com.orcagateway.core.support.j
import com.orcagateway.core.support.runSuspend
import kotlinx.serialization.json.Json
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * S9.2: the three fallback policies and the 426 gate, on pages a real engine
 * produced for the Kotlin caps vector (`examples/server/record-page.ts
 * --sdk kotlin`, the capability-demo `degrade` page with an
 * UnregisteredPluginWidget, a plugin widget no app registers, so no SDK
 * advertises it). Mirrors Swift's DegradeTests; the engine shapes are pinned by
 * engine/test/caps-policy-e2e.test.ts, these tests pin what the Kotlin
 * renderer makes of them. The registry is the build's own
 * ([WidgetRegistry]'s default, the caps vector's widgets), as Swift's is.
 */
class DegradeTest {
    private val base = URI("http://localhost:8080")

    private fun recorded(name: String): String = Fixtures.text("sdk-kotlin/sdk/src/test/resources/pages/$name.json")

    private fun tree(name: String): RenderNode {
        val page = Json.decodeFromString(PageResponse.serializer(), recorded(name))
        val renderer = PageRenderer(page, WidgetRegistry())
        val store = ElmStore()
        store.seed(page.state)
        return assertNotNull(renderer.tree(store.state))
    }

    private fun texts(tree: RenderNode): List<String> =
        tree.all.filter { it.type == "Text" }.mapNotNull { it.props["data"]?.stringValue }

    @Test
    fun d1_gracefulStripsTheNodeAndKeepsItsSiblings() {
        val tree = tree("degrade-graceful")
        assertEquals("Scaffold", tree.type)
        assertNull(tree.first { it.type == "UnregisteredPluginWidget" || it.type == "FallbackPrompt" })
        val column = assertNotNull(tree.first { it.type == "Column" })
        assertEquals(
            listOf("Above the plugin widget.", "Below the plugin widget."),
            column.children.map { it.props["data"]?.stringValue },
        )
    }

    @Test
    fun d2_warnPrependsABannerAndKeepsThePage() {
        val tree = tree("degrade-warn")
        assertEquals("__caps_warn_root__", tree.id)
        assertEquals("Column", tree.type)
        assertEquals(listOf("__caps_warn_banner__", "0"), tree.children.map { it.id })
        val banner = tree.children[0]
        assertEquals("FallbackPrompt", banner.type)
        assertEquals(j("warn"), banner.props["severity"])
        assertEquals(j("Some content needs an update"), banner.props["title"])
        // The banner names the one feature the engine found missing.
        assertEquals(
            "Parts of this screen use features that your current app version can't fully render " +
                "(widget.UnregisteredPluginWidget). Please update when convenient for the full experience.",
            banner.props["body"]?.stringValue,
        )
        assertEquals("Scaffold", tree.children[1].type)
        // warn keeps the authored tree, the plugin widget included; the client
        // then draws it as its own "Unsupported content" prompt, as Flutter does.
        val plugin = assertNotNull(tree.first { it.node.degradedFrom == "UnregisteredPluginWidget" })
        assertEquals("FallbackPrompt", plugin.type)
        assertEquals(j("Unsupported content"), plugin.props["title"])
        assertEquals(
            listOf("Above the plugin widget.", "Below the plugin widget."),
            texts(tree).filter { it.endsWith("plugin widget.") },
        )
    }

    @Test
    fun d3_requireReplacesThePageWithOneBlockingPrompt() {
        val tree = tree("degrade-require")
        assertEquals(1, tree.all.size)
        assertEquals("__caps_block_root__", tree.id)
        assertEquals("FallbackPrompt", tree.type)
        assertEquals(j("blocking"), tree.props["severity"])
        assertEquals(j("Update required"), tree.props["title"])
        // The prompt names the one feature the engine found missing.
        assertEquals(
            "This screen needs features that this app version can't render " +
                "(widget.UnregisteredPluginWidget). Please update from your app store to continue.",
            tree.props["body"]?.stringValue,
        )
    }

    @Test
    fun d4_a426DrawsTheUpgradePageItCarries() = runSuspend {
        val engine = StubEngine(ByteArray(0))
        engine.forced = HttpResponse(426, body = recorded("degrade-426").encodeToByteArray())
        val client = OrcaClient(base, "capability-demo", transport = engine)

        val page = client.fetchPage("degrade")

        assertEquals("Update required", page.title)
        assertEquals(listOf("__min_sdk_block_root__"), page.components.map { it.id })
        val root = assertNotNull(page.components.firstOrNull())
        assertEquals("FallbackPrompt", root.type)
        assertEquals(j("blocking"), root.props["severity"])
        assertEquals(
            "This app needs version 99.0.0 or later to continue. Please update from your app store.",
            root.props["body"]?.stringValue,
        )
    }

    @Test
    fun d5_a426WithoutAPageStaysAnError() = runSuspend {
        val engine = StubEngine(ByteArray(0))
        val body = """{"error":"sdk_version_too_old"}"""
        engine.forced = HttpResponse(426, body = body.encodeToByteArray())
        val client = OrcaClient(base, "a", transport = engine)
        val error = assertFailsWith<OrcaClientException.Http>("expected an error") { client.fetchPage("home") }
        assertEquals(OrcaClientException.Http(426, body), error)
    }

    @Test
    fun d6_anotherStatusWithAPageStaysAnError() = runSuspend {
        val engine = StubEngine(ByteArray(0))
        engine.forced = HttpResponse(500, body = recorded("degrade-426").encodeToByteArray())
        val client = OrcaClient(base, "a", transport = engine)
        val error = assertFailsWith<OrcaClientException.Http>("expected an error") { client.fetchPage("home") }
        assertEquals(500, error.status)
    }
}
