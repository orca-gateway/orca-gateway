package com.orcagateway.sdk.widgets

import android.util.Log
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
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
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowLog
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** `setState(key, key + 1)`, as the counter page's increment. */
private fun count(key: String): Action = Action.SetState(
    key = key,
    value = JsonValue.parse(
        """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
            """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
    ),
)

/** Page keys starting at 0, for [count] to increment. */
private fun counters(vararg keys: String): List<StateDefinition> =
    keys.map { StateDefinition(it, StateScope.Page, JsonValue.Int(0)) }

/**
 * A2.1, A2.2, A2.3 and A2.5 on Android, against Flutter's
 * OrcaLifecycleWrapper (sdk/lib/src/widgets/lifecycle_wrapper.dart) and
 * component_renderer.dart:230-255: onInit and onVisible once per mount, the
 * app triggers from a test lifecycle, `once` per widget and trigger on a
 * tap, and a debugLog effect printed and handed on. Each trigger counts its
 * fires in a page state key.
 */
@RunWith(RobolectricTestRunner::class)
class LifecycleTest {
    @get:Rule
    val compose = createComposeRule()

    /** A lifecycle the test moves, standing in for ProcessLifecycleOwner's. */
    private class TestApp : LifecycleOwner {
        val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle get() = registry
    }

    /** How many times each Text node was drawn, by id. */
    private val draws = HashMap<String, Int>()

    /** A Text showing page key [shows] (so it redraws when it changes), with [actions]. */
    private fun watcher(id: String, shows: String, actions: Map<String, Action>): ComponentNode = ComponentNode(
        id, "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
        props = mapOf("data" to JsonValue.parse("""{"type":"state","key":"$shows","scope":"page"}""")),
        watches = listOf(shows),
        actions = actions,
    )

    private fun OrcaPageModel.value(key: String): Long? = store.state.page[key]?.dartInt

    /** The page's model with its Texts counting their draws in [draws]. */
    private fun model(vararg nodes: ComponentNode, state: List<StateDefinition>): OrcaPageModel =
        OrcaPageModel(page(*nodes, state = state)).apply {
            builders = WidgetBuilders.standard().apply {
                val plain = checkNotNull(this["Text"])
                register("Text") { node, model, modifier ->
                    draws[node.id] = (draws[node.id] ?: 0) + 1
                    plain(node, model, modifier)
                }
            }
        }

    private fun show(model: OrcaPageModel, app: TestApp? = null) {
        compose.setContent {
            if (app == null) {
                NodeView(model.page.components.first().id, model)
            } else {
                CompositionLocalProvider(LocalOrcaAppLifecycle provides app.lifecycle) {
                    NodeView(model.page.components.first().id, model)
                }
            }
        }
        compose.waitForIdle()
    }

    /** A2.1 (kt): onInit runs once after the node is first composed, and not again when its state change redraws it. */
    @Test
    fun a2_1_kt_onInitRunsOnceAndNotOnARedraw() {
        val model = model(watcher("t", shows = "inits", actions = mapOf("onInit" to count("inits"))), state = counters("inits", "other"))
        show(model)

        assertEquals(1, model.value("inits"))
        // The onInit's own change redrew the node; a second change redraws it again.
        compose.runOnIdle { model.store.dispatch(mapOf("inits" to JsonValue.Int(5))) }
        compose.waitForIdle()
        assertTrue(draws.getValue("t") >= 3, "the node redrew (${draws["t"]} draws)")
        assertEquals(5, model.value("inits"))
    }

    /** A2.2 (kt, corrected): onVisible runs once when the node is first built, as Flutter's, and not again on a redraw. */
    @Test
    fun a2_2_kt_onVisibleRunsOnceAndNotOnARedraw() {
        val model = model(watcher("t", shows = "seen", actions = mapOf("onVisible" to count("seen"))), state = counters("seen"))
        show(model)

        assertEquals(1, model.value("seen"))
        compose.runOnIdle { model.store.dispatch(mapOf("seen" to JsonValue.Int(5))) }
        compose.waitForIdle()
        assertTrue(draws.getValue("t") >= 3, "the node redrew (${draws["t"]} draws)")
        assertEquals(5, model.value("seen"))
    }

    /** `home`: a Text with onInit and onVisible and a Go button to `/about`; any other page is one Text of its name. */
    private class Pages : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse {
            val name = request.url.path.substringAfterLast("/page/")
            val page = if (name == "home") {
                PageResponse(
                    pageId = name, title = name,
                    state = counters("inits", "seen"),
                    components = listOf(
                        column("c", "t", "b"),
                        ComponentNode(
                            "t", "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
                            props = mapOf("data" to JsonValue.String("home")),
                            actions = mapOf("onInit" to count("inits"), "onVisible" to count("seen")),
                        ),
                        button("b", "TextButton", "l", mapOf("onTap" to Action.Navigate(route = JsonValue.String("/about")))),
                        text("l", "Go"),
                    ),
                )
            } else {
                PageResponse(pageId = name, title = name, components = listOf(text("0", name)))
            }
            return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
        }

        val client: OrcaClient
            get() = OrcaClient(URI("http://stub.invalid"), appId = "lifecycle", device = DeviceInfo(osVersion = "test"), transport = this)
    }

    private fun shown(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    /**
     * A2.1 and A2.2 (kt): a page covered by a pushed one leaves the
     * composition (NavHost), and coming back on top is not a new mount: its
     * onInit and onVisible do not run again.
     */
    @Test
    fun a2_1_a2_2_kt_aCoveredPagePoppingBackDoesNotRunThemAgain() {
        val router = OrcaRouter(Pages().client)
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { shown("Go") > 0 }
        val home = (router.loader(router.root).phase as OrcaPageLoader.Phase.Loaded).model
        compose.waitForIdle()
        assertEquals(1, home.value("inits"))
        assertEquals(1, home.value("seen"))

        compose.onNodeWithText("Go").performClick()
        compose.waitUntil(5_000) { shown("about") > 0 && shown("home") == 0 }
        compose.runOnIdle { router.goBack() }
        compose.waitUntil(5_000) { shown("home") > 0 && shown("about") == 0 }
        compose.waitForIdle()

        assertEquals(1, home.value("inits"))
        assertEquals(1, home.value("seen"))
    }

    /**
     * A2.3 (kt): the app lifecycle going STARTED → CREATED → STARTED runs
     * onBackground then onForeground; its first start runs nothing (Flutter
     * adds its observer after the app resumed).
     */
    @Test
    fun a2_3_kt_appEventsRunBackgroundThenForegroundAndNothingOnTheFirstStart() {
        val app = TestApp()
        compose.runOnIdle { app.registry.currentState = Lifecycle.State.CREATED }
        val model = model(
            text("t", "app").copy(actions = mapOf("onBackground" to count("bg"), "onForeground" to count("fg"))),
            state = counters("bg", "fg"),
        )
        show(model, app)

        compose.runOnIdle { app.registry.currentState = Lifecycle.State.STARTED }
        compose.waitForIdle()
        assertEquals(0L to 0L, model.value("bg") to model.value("fg"), "first start")

        compose.runOnIdle { app.registry.currentState = Lifecycle.State.CREATED }
        compose.waitForIdle()
        assertEquals(1L to 0L, model.value("bg") to model.value("fg"), "background")

        compose.runOnIdle { app.registry.currentState = Lifecycle.State.STARTED }
        compose.waitForIdle()
        assertEquals(1L to 1L, model.value("bg") to model.value("fg"), "foreground")
    }

    /** A2.3 (kt): with both names set, onAppBackground and onAppForeground run and the short aliases do not. */
    @Test
    fun a2_3_kt_theOnAppNamesWinOverTheShortOnes() {
        val app = TestApp()
        compose.runOnIdle { app.registry.currentState = Lifecycle.State.STARTED }
        val model = model(
            text("t", "app").copy(
                actions = mapOf(
                    "onAppBackground" to count("appBg"), "onBackground" to count("bg"),
                    "onAppForeground" to count("appFg"), "onForeground" to count("fg"),
                ),
            ),
            state = counters("appBg", "bg", "appFg", "fg"),
        )
        show(model, app)

        compose.runOnIdle { app.registry.currentState = Lifecycle.State.CREATED }
        compose.runOnIdle { app.registry.currentState = Lifecycle.State.STARTED }
        compose.waitForIdle()

        assertEquals(listOf(1L, 1L), listOf(model.value("appBg"), model.value("appFg")), "onApp*")
        assertEquals(listOf(0L, 0L), listOf(model.value("bg"), model.value("fg")), "short names")
    }

    /** A2.5 (kt): a tap wrapped in once changes state one time; a second tap does nothing, and another widget's once still runs. */
    @Test
    fun a2_5_kt_aOnceTapRunsOneTimePerWidgetAndTrigger() {
        val model = model(
            column("0", "a", "b"),
            button("a", "ElevatedButton", "la", mapOf("onTap" to Action.Once(count("taps")))),
            text("la", "A"),
            button("b", "ElevatedButton", "lb", mapOf("onTap" to Action.Once(count("taps")))),
            text("lb", "B"),
            state = counters("taps"),
        )
        show(model)

        compose.onNodeWithText("A").performClick()
        compose.onNodeWithText("A").performClick()
        compose.waitForIdle()
        assertEquals(1, model.value("taps"), "second tap on A")

        compose.onNodeWithText("B").performClick()
        compose.onNodeWithText("B").performClick()
        compose.waitForIdle()
        assertEquals(2, model.value("taps"), "B's once")
    }

    /**
     * D3 (kt): a debugLog effect is printed through android.util.Log, at its
     * level under its tag with its message and data, and still reaches the
     * host's effect handler.
     */
    @Test
    fun d3_kt_aDebugLogIsPrintedAndStillReachesTheEffectHandler() {
        ShadowLog.clear()
        val handled = ArrayList<ActionEffect>()
        val model = OrcaPageModel(page(text("t", "x"))).apply { effectHandler = { handled += it } }
        val log = Action.DebugLog(level = "warn", message = JsonValue.String("hello"), tag = "lifecycle-test", data = JsonValue.obj("n" to 3))

        compose.runOnIdle { model.fire("onTap", model.resolve("t")!!.copy(actions = mapOf("onTap" to log))) }
        compose.waitForIdle()

        assertEquals(listOf("debugLog"), handled.map { it.type })
        assertEquals("hello", handled.single().payload["message"]?.stringValue)
        val line = ShadowLog.getLogsForTag("lifecycle-test").single()
        assertEquals(Log.WARN, line.type)
        assertTrue("hello" in line.msg && "\"n\":3" in line.msg, line.msg)
    }
}
