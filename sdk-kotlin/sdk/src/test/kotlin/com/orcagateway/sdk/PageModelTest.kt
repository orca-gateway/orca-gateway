package com.orcagateway.sdk

import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.support.recordedPage
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * What the views do with a tap, without tapping through Compose: the model
 * runs the node's action, commits the state and shows the toast. Swift's
 * `PageModelTests`, all six (none needs the router or DevTools).
 */
@RunWith(RobolectricTestRunner::class)
class PageModelTest {
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
}
