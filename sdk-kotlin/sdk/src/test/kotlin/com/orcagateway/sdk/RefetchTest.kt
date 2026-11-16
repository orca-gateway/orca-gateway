package com.orcagateway.sdk

import android.content.Context
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.test.hasProgressBarRangeInfo
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * Page `home` as the engine would serve it on fetch [n]: a Text naming the
 * fetch, the app key `visits` and the page key `taps` (both shown), and a
 * Refresh button whose tap is RefetchPage. Each fetch has its own initials.
 */
private fun home(n: Int): PageResponse {
    fun shows(id: String, key: String, scope: String) = ComponentNode(
        id, "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
        props = mapOf("data" to JsonValue.parse("""{"type":"state","key":"$key","scope":"$scope"}""")),
        watches = listOf(key),
    )
    return PageResponse(
        pageId = "home-$n", title = "Home $n",
        state = listOf(
            StateDefinition("visits", StateScope.App, JsonValue.String("app-$n")),
            StateDefinition("taps", StateScope.Page, JsonValue.String("page-$n")),
        ),
        components = listOf(
            column("c", "t", "a", "p", "b"),
            text("t", "fetch $n"),
            shows("a", "visits", "app"),
            shows("p", "taps", "page"),
            button("b", "TextButton", "l", mapOf("onTap" to Action.RefetchPage)),
            text("l", "Refresh"),
        ),
    )
}

/** Serves [home] of the fetch count; from the second fetch on, waits for [hold] and answers [failWith] when set. */
private class Refetches : HttpTransport {
    val requests = mutableListOf<HttpRequest>()
    var hold: CompletableDeferred<Unit>? = null
    var failWith: Int? = null

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests += request
        if (requests.size > 1) {
            hold?.await()
            failWith?.let { return HttpResponse(it, body = """{"error":"boom"}""".toByteArray()) }
        }
        val page = home(requests.size)
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    val client: OrcaClient
        get() = OrcaClient(URI("http://stub.invalid"), appId = "refetch", device = DeviceInfo(osVersion = "test"), transport = this)
}

/**
 * A5.6 (kt): refetchPage reloads the page in place, as Flutter's OrcaPage
 * does (sdk/lib/src/widgets/orca_page.dart:276-297, the executor's
 * action_executor.dart:812-818): the current path fetched again with the app
 * state, the same model drawing the new tree, no loading screen, app state
 * kept and page state reset to the new page's initials, no effect. A failed
 * fetch throws out of the action and leaves the page as it was.
 */
@RunWith(RobolectricTestRunner::class)
class RefetchTest {
    @get:Rule
    val compose = createComposeRule()

    private fun shown(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    private fun spinners(): Int =
        compose.onAllNodes(hasProgressBarRangeInfo(ProgressBarRangeInfo.Indeterminate)).fetchSemanticsNodes().size

    @Test
    fun a5_6_kt_refetchPageSwapsTheTreeInPlaceKeepingAppStateAndResettingPageState() {
        val stub = Refetches()
        val router = OrcaRouter(stub.client, path = "home")
        val effects = mutableListOf<ActionEffect>()
        router.onEffect = { effects += it }
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { shown("fetch 1") > 0 }
        val loader = router.loader(router.root)
        val loaded = assertIs<OrcaPageLoader.Phase.Loaded>(loader.phase)
        val model = loaded.model
        compose.runOnIdle {
            model.store.dispatch(mapOf("visits" to JsonValue.String("app-changed")), StateScope.App)
            model.store.dispatch(mapOf("taps" to JsonValue.String("page-changed")))
        }
        compose.waitUntil(5_000) { shown("app-changed") > 0 && shown("page-changed") > 0 }

        val hold = CompletableDeferred<Unit>().also { stub.hold = it }
        val job = compose.runOnIdle { model.fire("onTap", checkNotNull(model.resolve("b"))) }
        checkNotNull(job)
        compose.waitForIdle()
        // The second fetch is in flight: the action waits on it, and the page stays on screen as it was.
        assertEquals(2, stub.requests.size)
        assertTrue(job.isActive, "the action ended before the fetch landed")
        assertSame(loaded, loader.phase)
        assertEquals(0, spinners())
        assertEquals(1, shown("fetch 1"))
        // The fetch carries the app state, as the loader's does.
        assertEquals(JsonValue.parse("""{"visits":"app-changed"}"""), JsonValue.parse(checkNotNull(stub.requests[1].body))["appState"])

        compose.runOnIdle { hold.complete(Unit) }
        compose.waitUntil(5_000) { shown("fetch 2") > 0 }
        assertTrue(job.isCompleted, "the action did not end when the fetch landed")
        assertSame(loaded, loader.phase)
        assertSame(model, (loader.phase as OrcaPageLoader.Phase.Loaded).model)
        assertEquals(0, shown("fetch 1"))
        assertEquals("home-2", model.store.pageId)
        assertEquals(home(2).components, model.page.components)
        assertEquals(mapOf("visits" to JsonValue.String("app-changed")), model.store.state.app)
        assertEquals(mapOf("taps" to JsonValue.String("page-2")), model.store.state.page)
        assertEquals(1, shown("app-changed"))
        assertEquals(1, shown("page-2"))
        assertEquals(emptyList(), effects)
    }

    @Test
    fun a5_6_kt_aFailedRefetchThrowsOutOfTheActionAndLeavesThePage(): Unit = runBlocking {
        val stub = Refetches()
        val router = OrcaRouter(stub.client, path = "home")
        val loader = router.loader(router.root)
        loader.loadIfNeeded(ApplicationProvider.getApplicationContext<Context>())
        val loaded = assertIs<OrcaPageLoader.Phase.Loaded>(loader.phase)
        val model = loaded.model
        model.store.dispatch(mapOf("taps" to JsonValue.String("page-changed")))
        val errors = mutableListOf<Throwable>()
        model.onError = { errors += it }
        stub.failWith = 500

        val thrown = assertFailsWith<OrcaClientException.Http> { model.executor.execute(Action.RefetchPage) }
        assertEquals(500, thrown.status)
        checkNotNull(model.fire("onTap", checkNotNull(model.resolve("b")))).join()
        assertIs<OrcaClientException.Http>(errors.single())

        assertEquals(3, stub.requests.size)
        assertSame(loaded, loader.phase)
        assertEquals("home-1", model.store.pageId)
        assertEquals(home(1).components, model.page.components)
        assertEquals(mapOf("taps" to JsonValue.String("page-changed")), model.store.state.page)
    }
}
