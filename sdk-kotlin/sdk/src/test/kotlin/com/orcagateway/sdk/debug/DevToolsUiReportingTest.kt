package com.orcagateway.sdk.debug

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.DevToolsReporter
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateScope
import com.orcagateway.sdk.NodeObserver
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.recordedPage
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.fail

/** Keeps every event it is given, in order, from any thread. */
private class Recorder : DevToolsReporter {
    private val events = mutableListOf<DevToolsEvent>()

    override fun report(event: DevToolsEvent) {
        synchronized(events) { events += event }
    }

    fun of(type: String): List<DevToolsEvent> = synchronized(events) { events.filter { it.type == type } }
}

/**
 * Swift's `PageStub` as these tests need it: a page by path, `{pageId,
 * title}` with one Text node, and [actionBody] as the 200 answer to every
 * `/action` call.
 */
private class PageStub(private val actionBody: String = """{"actions":[]}""") : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse {
        val path = request.url.path
        if (path.endsWith("/action")) return HttpResponse(200, body = actionBody.encodeToByteArray())
        val name = path.substringAfterLast("/page/")
        val page = PageResponse(pageId = name, title = name, components = listOf(text("0", name)))
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    val client: OrcaClient get() = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", transport = this)
}

/**
 * What a page reports to DevTools from the views: a watching node's
 * rebuild, the page's load timing, a thrown action (Swift
 * `DevToolsHookTests`).
 */
@RunWith(RobolectricTestRunner::class)
class DevToolsUiReportingTest {
    private val recorder = Recorder()

    @After
    fun reset() {
        OrcaDebug.reporter = null
    }

    /** Swift `testAWatchingNodeReportsItsRebuild`. */
    @Test
    fun c6_aWatchingNodeReportsItsRebuild() = runBlocking {
        val model = OrcaPageModel(recordedPage("counter-home"))
        val count = NodeObserver(model, "5")
        OrcaDebug.reporter = recorder
        model.fire("onTap", on = assertNotNull(model.resolve("11")))?.join()
        assertEquals(1, count.revision)
        assertEquals(
            listOf(DevToolsEvent.widgetRebuild(widgetId = "5", widgetType = "Text", watches = listOf("count"))),
            recorder.of("widget_rebuild"),
        )
        assertEquals(
            listOf(DevToolsEvent.stateChange(StateScope.Page, "home", "count", JsonValue.Int(0), JsonValue.Int(1))),
            recorder.of("state_change"),
        )
        assertEquals(JsonValue.String("home"), recorder.of("action").firstOrNull()?.payload?.get("pageId"))
    }

    /** Swift `testALoadedPageReportsItsTimingOnce`. */
    @Test
    fun c7_aLoadedPageReportsItsTimingOnce() = runBlocking {
        OrcaDebug.reporter = recorder
        val router = OrcaRouter(PageStub().client, path = "home")
        val loader = router.loader(router.root)
        loader.loadIfNeeded(ApplicationProvider.getApplicationContext<Context>())
        val model = (loader.phase as? OrcaPageLoader.Phase.Loaded)?.model ?: fail("not loaded: ${loader.phase}")
        assertEquals(emptyList(), recorder.of("timing"), "sent on the first frame")
        model.appeared()
        model.appeared()
        val timing = recorder.of("timing")
        assertEquals(1, timing.size)
        assertEquals(JsonValue.String("home"), timing[0].payload["pageId"])
        assertEquals(JsonValue.String("home"), timing[0].payload["path"])
        val client = assertNotNull(timing[0].payload["client"])
        val marks = listOf("responseReceivedMs", "parseCompleteMs", "renderStartMs", "renderCompleteMs", "firstFrameMs")
            .mapNotNull { client[it].doubleValue }
        assertEquals(5, marks.size)
        assertEquals(marks.sorted(), marks, "marks only move forward")
        assertEquals(1, recorder.of("network").size)
    }

    /** Swift `testAThrownActionIsReportedAsAnError`. */
    @Test
    fun c8_aThrownActionIsReportedAsAnError() = runBlocking {
        OrcaDebug.reporter = recorder
        val model = OrcaPageModel(
            PageResponse(pageId = "p", title = "P"),
            client = PageStub(actionBody = "not json").client,
        )
        model.run(Action.ServerAction(id = "boom"))
        assertEquals(
            JsonValue.String("action serverAction on p"),
            recorder.of("error").lastOrNull()?.payload?.get("context"),
        )
    }
}
