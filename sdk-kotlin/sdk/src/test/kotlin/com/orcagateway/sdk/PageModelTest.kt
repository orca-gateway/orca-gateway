package com.orcagateway.sdk

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.recordedPage
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowToast
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * What the views do with a tap, without tapping through Compose: the model
 * runs the node's action, commits the state and shows the toast. Swift's
 * `PageModelTests`, all six (none needs the router or DevTools). Then A8.4,
 * through Compose on the test clock: the one queue of snackbars and toasts.
 */
@RunWith(RobolectricTestRunner::class)
class PageModelTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun tapsCountAndResetShowsTheSnackbar() = runBlocking {
        val model = OrcaPageModel(recordedPage("counter-home"))
        assertEquals(JsonValue.Int(0), model.store.value("count"))

        val plus = assertNotNull(model.resolve("11"))
        assertEquals(JsonValue.String("+"), model.resolve(plus.childIds[0])?.get("data"))
        model.fire("onTap", on = plus)?.join()
        model.fire("onTap", on = plus)?.join()
        assertEquals(JsonValue.Int(2), model.store.value("count"))
        assertEquals(JsonValue.String("2"), model.resolve("5")?.get("data"))
        assertNull(model.toast)

        val reset = assertNotNull(model.resolve("14"))
        model.fire("onTap", on = reset)?.join()
        assertEquals(JsonValue.Int(0), model.store.value("count"))
        assertEquals("Counter reset to 0", model.toast?.message)
        assertEquals(4000L, model.toast?.durationMillis)
        assertEquals(OrcaToast.Style.Snackbar, model.toast?.style)
    }

    @Test
    fun onlyWatchingNodesSubscribe() = runBlocking {
        val model = OrcaPageModel(recordedPage("counter-home"))
        val count = NodeObserver(model, "5")
        val title = NodeObserver(model, "2")
        assertEquals(1, model.store.subscriberCount)

        model.fire("onTap", on = assertNotNull(model.resolve("11")))?.join()
        assertEquals(1, count.revision)
        assertEquals(0, title.revision)
    }

    @Test
    fun missingTriggerDoesNothing() {
        val model = OrcaPageModel(recordedPage("counter-home"))
        assertNull(model.fire("onLongPress", on = assertNotNull(model.resolve("11"))))
        assertEquals(JsonValue.Int(0), model.store.value("count"))
    }

    @Test
    fun navigationAndSystemEffectsGoToTheHandler() = runBlocking {
        val model = OrcaPageModel(PageResponse(pageId = "p", title = "P"))
        val reported = ArrayList<ActionEffect>()
        val handled = ArrayList<ActionEffect>()
        model.onEffect = { reported.add(it) }
        model.effectHandler = { handled.add(it) }
        model.run(
            Action.ActionGroup(
                actions = listOf(
                    Action.Navigate(route = JsonValue.String("/next")),
                    Action.ShowToast(message = JsonValue.String("hi")),
                ),
            ),
        )
        assertEquals(
            listOf(ActionEffect("navigate", mapOf("route" to JsonValue.String("/next"), "replace" to JsonValue.Bool(false)))),
            handled,
        )
        assertEquals(listOf("navigate", "showToast"), reported.map { it.type })
        assertEquals("hi", model.toast?.message)
    }

    @Test
    fun aThrownActionIsReportedNotRaised() = runBlocking {
        val client = OrcaClient(URI("http://stub.invalid"), "app", transport = ActionBody("not json"))
        val model = OrcaPageModel(PageResponse(pageId = "p", title = "P"), client = client)
        val errors = ArrayList<Throwable>()
        model.onError = { errors.add(it) }
        model.run(Action.ServerAction(id = "boom"))
        assertEquals(1, errors.size)
    }

    /**
     * T3.2: a server action's component kinds edit the tree and every node
     * redraws. Watches stay what the server sent, as in Dart's
     * `ComponentStore.updateComponent`.
     */
    @Test
    fun mutationsRedrawTheTree() {
        val model = OrcaPageModel(recordedPage("counter-home"))
        val title = NodeObserver(model, "2")

        model.apply(
            ComponentMutation.Update("2", mapOf("data" to JsonValue.obj("type" to "state", "scope" to "page", "key" to "count"))),
        )
        assertEquals(1, model.structureRevision)
        assertEquals(1, title.revision)
        assertEquals(JsonValue.Int(0), model.resolve("2")?.get("data"))
        assertEquals(0, model.store.subscriberCount)

        model.apply(ComponentMutation.Delete("14"))
        assertNull(model.resolve("14"))
        assertFalse(model.resolve("4")?.childIds?.contains("14") ?: true)
        assertEquals(2, title.revision)
    }

    /** Swift's `PageStub(actionBody:)`: every `/action` call answers 200 with [body]. */
    private class ActionBody(private val body: String) : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse = HttpResponse(200, body = body.encodeToByteArray())
    }

    // A8.4: one queue for the app (Flutter's root ScaffoldMessenger, action_executor.dart:393-423), shared by
    // showSnackbar and showToast. Each item comes in for 250 ms, stays its duration counted once fully in, goes
    // in 250 ms, and only then does the next come in (scaffold.dart:371-392, :438-449, :661-674; snack_bar.dart:30).
    // The clock starts at the first frame after the tap, so a tap at t leaves a 4000 ms bar gone by t + 4516.

    /**
     * A8.4: two showSnackbar in a row show one after the other: the second
     * waits for the first to go, and nothing is replaced.
     */
    @Test
    fun a8_4_twoSnackbarsInARowShowOneAfterTheOther() {
        val model = OrcaPageModel(firing(snackbar("First"), snackbar("Second")))
        compose.setContent { OrcaPageView(model) }
        compose.mainClock.autoAdvance = false

        compose.onNodeWithText("Go").performClick()
        compose.mainClock.advanceTimeBy(500)
        compose.onNodeWithText("First").assertIsDisplayed()
        assertEquals(0, count("Second"), "the second waits")
        assertEquals("First", model.toast?.message)

        compose.mainClock.advanceTimeBy(3_500)
        compose.onNodeWithText("First").assertIsDisplayed()
        assertEquals(0, count("Second"))

        compose.mainClock.advanceTimeBy(1_000)
        assertEquals(0, count("First"), "gone after its 4000 ms and its leave")
        compose.onNodeWithText("Second").assertIsDisplayed()
        assertEquals("Second", model.toast?.message)

        compose.mainClock.advanceTimeBy(4_500)
        assertEquals(0, count("Second"))
        assertNull(model.toast)
    }

    /**
     * A8.4: a toast fired between two snackbars waits its turn in the same
     * queue: the Android Toast shows only once the first snackbar is gone,
     * and the second snackbar only once the toast's 2000 ms are over.
     */
    @Test
    fun a8_4_aToastBetweenTwoSnackbarsWaitsItsTurn() {
        val toast = Action.ShowToast(message = JsonValue.String("Saved"))
        val model = OrcaPageModel(firing(snackbar("First"), toast, snackbar("Second")))
        compose.setContent { OrcaPageView(model) }
        compose.mainClock.autoAdvance = false

        compose.onNodeWithText("Go").performClick()
        compose.mainClock.advanceTimeBy(500)
        compose.onNodeWithText("First").assertIsDisplayed()
        assertEquals(0, ShadowToast.shownToastCount(), "the toast waits for the first snackbar")

        compose.mainClock.advanceTimeBy(4_500)
        assertEquals(0, count("First"))
        assertEquals(1, ShadowToast.shownToastCount(), "its turn")
        assertEquals("Saved", ShadowToast.getTextOfLatestToast())
        assertEquals(OrcaToast.Style.Toast, model.toast?.style)
        assertEquals(0, count("Second"), "the second snackbar waits for the toast")

        // The toast's 250 + 2000 + 250 ms from t + 4516: the second is in by t + 7266.
        compose.mainClock.advanceTimeBy(2_500)
        compose.onNodeWithText("Second").assertIsDisplayed()
        assertEquals(1, ShadowToast.shownToastCount(), "the toast is shown once")
    }

    /**
     * A8.4: a snackbar survives a navigate: the pushed page's Scaffold shows
     * the same bar, its time still running from the tap (Flutter's pushed
     * Scaffold registers with the one messenger, snack_bar.dart:898), so it
     * goes when it would have gone on the first page.
     */
    @Test
    fun a8_4_aBarAcrossANavigateKeepsItsTime() {
        val router = OrcaRouter(TwoPages().client, path = "first")
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { count("Go") == 1 }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false

        compose.onNodeWithText("Go").performClick()
        compose.mainClock.advanceTimeBy(2_000)
        compose.onNodeWithText("Saved").assertIsDisplayed()

        // The page is fetched while the clock stands still (TransitionTest's way).
        compose.runOnUiThread { router.navigate("second") }
        compose.waitForIdle()
        compose.mainClock.advanceTimeBy(1_500)
        assertEquals("second", router.top.path)
        assertEquals(0, count("Go"), "the first page has left")
        compose.onNodeWithText("second page").assertIsDisplayed()
        compose.onNodeWithText("Saved").assertIsDisplayed()

        compose.mainClock.advanceTimeBy(500)
        compose.onNodeWithText("Saved").assertIsDisplayed()

        // Counted from the tap, not from the navigate (that would keep it until t + 6266).
        compose.mainClock.advanceTimeBy(1_000)
        assertEquals(0, count("Saved"))
        val second = assertNotNull(router.loader(router.top).phase as? OrcaPageLoader.Phase.Loaded).model
        assertNull(second.toast)
    }

    /**
     * A8.4: a server action the server refuses shows its message through the
     * same queue (Flutter: `exec.execute({'type': 'showSnackbar', 'message':
     * e.message})`, action_executor.dart:721-724), after the bar before it.
     */
    @Test
    fun a8_4_aRefusedServerActionsMessageJoinsTheQueue() {
        val client = OrcaClient(URI("http://stub.invalid"), "app", transport = Refusing("Not allowed"))
        val model = OrcaPageModel(firing(snackbar("First"), Action.ServerAction(id = "save")), client = client)
        compose.setContent { OrcaPageView(model) }
        compose.mainClock.autoAdvance = false

        compose.onNodeWithText("Go").performClick()
        compose.mainClock.advanceTimeBy(500)
        compose.onNodeWithText("First").assertIsDisplayed()
        assertEquals(0, count("Not allowed"), "the refusal waits for the bar before it")
        assertEquals("First", model.toast?.message)

        compose.mainClock.advanceTimeBy(4_500)
        assertEquals(0, count("First"))
        compose.onNodeWithText("Not allowed").assertIsDisplayed()
        assertEquals("Not allowed", model.toast?.message)
        assertEquals(4000L, model.toast?.durationMillis)
        assertEquals(OrcaToast.Style.Snackbar, model.toast?.style)
    }

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    private fun snackbar(message: String): Action = Action.ShowSnackbar(message = JsonValue.String(message))

    /** Every `/action` call is refused with [message] (403 and an error body). */
    private class Refusing(private val message: String) : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse =
            HttpResponse(403, body = """{"error":"$message"}""".encodeToByteArray())
    }

    /** Page `first` is a Scaffold with a button that fires a snackbar; `second` a Scaffold with "second page". */
    private class TwoPages : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse {
            val page = when (request.url.path.substringAfterLast("/page/")) {
                "first" -> firing(Action.ShowSnackbar(message = JsonValue.String("Saved")))
                else -> scaffold(text("t", "second page"))
            }
            return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
        }

        val client: OrcaClient
            get() = OrcaClient(URI("http://stub.invalid"), appId = "app", device = DeviceInfo(osVersion = "test"), transport = this)
    }

    private companion object {
        /** A page whose root is a Scaffold, [body] (and the nodes after it) in its body slot. */
        fun scaffold(body: ComponentNode, vararg rest: ComponentNode): PageResponse = page(
            ComponentNode(
                "s", "Scaffold", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
                mapOf("body" to JsonValue.String(body.id)), listOf(body.id),
            ),
            body,
            *rest,
        )

        /** A Scaffold page whose one button, "Go", runs [actions] in order. */
        fun firing(vararg actions: Action): PageResponse = scaffold(
            button("b", "ElevatedButton", "g", mapOf("onTap" to Action.ActionGroup(actions = actions.toList()))),
            text("g", "Go"),
        )
    }
}
