package com.orcagateway.sdk

import android.os.Looper
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ProcessLifecycleOwner
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.MemoryKeyValueStore
import com.orcagateway.core.client.OfflineSessionStore
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import java.net.URI
import java.util.Collections
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotSame
import kotlin.test.assertSame
import kotlin.test.assertTrue

/** Records every request and answers 200, like an engine that takes every session event. */
private class RecordingTransport : HttpTransport {
    val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests.add(request)
        return HttpResponse(200)
    }

    /** The `type` of each request's body, in order. */
    val types: List<String?>
        get() = requests.toList().map { JsonValue.parse(it.body ?: ByteArray(0))["type"].stringValue }
}

/**
 * C15.2 on the Android hook (T8's SessionLifecycle.kt): the process
 * lifecycle, not an activity's, drives the session, so ON_START posts the
 * start and ON_STOP the end, through one tracker per base URL, appId and
 * device id that a recreated activity gets back, and the end still goes out
 * after the SessionTracking composable has left the composition.
 * [ProcessSessions] lives as long as the process (the test sandbox here), so
 * each test uses its own appId, and the process lifecycle is put back to
 * CREATED (stopped) before and after each test.
 */
@RunWith(RobolectricTestRunner::class)
class SessionLifecycleTest {
    @get:Rule
    val compose = createComposeRule()

    private val process = ProcessLifecycleOwner.get().lifecycle as LifecycleRegistry

    private fun client(appId: String, transport: HttpTransport, base: String = "http://engine.invalid") =
        OrcaClient(URI(base), appId = appId, transport = transport)

    private fun offline() = OfflineSessionStore(MemoryKeyValueStore())

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun processEvent(event: Lifecycle.Event) {
        process.handleLifecycleEvent(event)
        idle()
    }

    @Before
    @After
    fun stopTheProcess() {
        process.currentState = Lifecycle.State.CREATED
        idle()
    }

    @Test
    fun c15_2_theSameClientKeyGetsTheSameTrackerAndAnotherKeyAnother() {
        val transport = RecordingTransport()
        val first = ProcessSessions.tracker(client("t13-key", transport), "device-1", offline())

        // A recreated activity builds a new client and store over the same settings.
        assertSame(first, ProcessSessions.tracker(client("t13-key", RecordingTransport()), "device-1", offline()))
        assertNotSame(first, ProcessSessions.tracker(client("t13-key-other", transport), "device-1", offline()))
        assertNotSame(first, ProcessSessions.tracker(client("t13-key", transport), "device-2", offline()))
        assertNotSame(first, ProcessSessions.tracker(client("t13-key", transport), null, offline()))
        assertNotSame(
            first,
            ProcessSessions.tracker(client("t13-key", transport, base = "http://other.invalid"), "device-1", offline()),
        )
    }

    @Test
    fun c15_2_processOnStartPostsTheStartAndOnStopTheEnd() {
        val transport = RecordingTransport()
        val tracker = ProcessSessions.tracker(client("t13-hook", transport), "device-1", offline())
        idle()
        assertEquals(emptyList(), transport.types)

        processEvent(Lifecycle.Event.ON_START)
        assertEquals(listOf<String?>("start"), transport.types)
        assertTrue(tracker.isOpen)

        processEvent(Lifecycle.Event.ON_STOP)
        assertEquals(listOf<String?>("start", "end"), transport.types)
        assertFalse(tracker.isOpen)
        for (request in transport.requests) {
            assertEquals("POST", request.method)
            assertEquals("http://engine.invalid/api/v1/app/t13-hook/session", request.url.toString())
            assertEquals("device-1", JsonValue.parse(request.body ?: ByteArray(0))["deviceId"].stringValue)
        }
    }

    @Test
    fun c15_2_attachingWhileTheProcessIsStartedSendsTheFirstStart() {
        processEvent(Lifecycle.Event.ON_START)
        val transport = RecordingTransport()

        val tracker = ProcessSessions.tracker(client("t13-replay", transport), "device-1", offline())
        idle()

        assertEquals(listOf<String?>("start"), transport.types)
        assertTrue(tracker.isOpen)
    }

    @Test
    fun c15_2_onStopStillPostsTheEndAfterSessionTrackingLeftTheComposition() {
        val transport = RecordingTransport()
        val client = client("t13-compose", transport)
        var shown by mutableStateOf(true)
        var left = false
        compose.setContent {
            if (shown) {
                SessionTracking(client, "device-1", offline())
                DisposableEffect(Unit) { onDispose { left = true } }
            }
        }
        compose.waitForIdle()
        processEvent(Lifecycle.Event.ON_START)
        assertEquals(listOf<String?>("start"), transport.types)

        compose.runOnIdle { shown = false }
        compose.waitForIdle()
        assertTrue(left)

        processEvent(Lifecycle.Event.ON_STOP)
        assertEquals(listOf<String?>("start", "end"), transport.types)
        assertFalse(ProcessSessions.tracker(client, "device-1", offline()).isOpen)
    }
}
