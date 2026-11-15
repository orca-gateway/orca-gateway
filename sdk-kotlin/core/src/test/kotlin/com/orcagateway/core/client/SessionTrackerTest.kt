package com.orcagateway.core.client

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.runSuspend
import java.net.ConnectException
import java.net.URI
import java.util.Collections
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.cancellation.CancellationException
import kotlin.coroutines.resume
import kotlin.coroutines.startCoroutine
import kotlin.coroutines.suspendCoroutine
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A transport that records every request, answers [status], and throws a
 * connection error while [offline] is set (the network is down).
 */
private class SwitchableTransport : HttpTransport {
    val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())

    @Volatile var offline = false

    @Volatile var status = 200

    override suspend fun send(request: HttpRequest): HttpResponse {
        if (offline) throw ConnectException("Connection refused")
        requests.add(request)
        return HttpResponse(status)
    }
}

/**
 * A transport whose first request stays unanswered until [release]; later
 * requests are answered 200 at once. Records every request.
 */
private class GatedTransport : HttpTransport {
    val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())
    private var held: Continuation<HttpResponse>? = null
    private var first = true

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests.add(request)
        if (!first) return HttpResponse(200)
        first = false
        return suspendCoroutine { held = it }
    }

    fun release(status: Int = 200) {
        held!!.resume(HttpResponse(status))
    }
}

/** A transport that throws [error] instead of answering. */
private class ThrowingTransport(val error: Exception) : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse = throw error
}

/**
 * C15.2 and C15.3 on the Kotlin core. C15.2: a session starts on foreground
 * and ends on background (`{type, deviceId}`, no duration, as Flutter sends
 * it). C15.3: sessions recorded offline are queued with their timestamps and
 * sent on the next online foreground. Ports Dart
 * sdk/lib/src/client/offline_session_store.dart and the session methods of
 * sdk/lib/src/client/orca_client.dart, with `_OrcaAppState`'s lifecycle
 * (sdk/lib/src/widgets/orca_app.dart) as [SessionTracker].
 */
class SessionTrackerTest {
    private val base = URI("http://localhost:8080")
    private val transport = SwitchableTransport()
    private val kv = MemoryKeyValueStore()
    private var now = 1_000L
    private val offline = OfflineSessionStore(kv) { now }

    private fun client(t: HttpTransport = transport): OrcaClient =
        OrcaClient(base, "counter", apiKey = "k", environment = "staging", deviceId = "dev-1", transport = t)

    private fun tracker(deviceId: String? = "dev-1"): SessionTracker = SessionTracker(client(), deviceId, offline)

    private fun body(request: HttpRequest): JsonValue = JsonValue.parse(request.body ?: ByteArray(0))

    // MARK: C15.2 sessions

    @Test
    fun c15_2_foregroundPostsStartAndBackgroundPostsEndWithTheDeviceId(): Unit = runSuspend {
        val t = tracker()

        t.foreground()
        assertTrue(t.isOpen)
        t.background()
        assertFalse(t.isOpen)

        val (start, end) = transport.requests.toList().also { assertEquals(2, it.size) }
        for (request in listOf(start, end)) {
            assertEquals("POST", request.method)
            assertEquals("http://localhost:8080/api/v1/app/counter/session", request.url.toString())
            assertEquals(client().headers + ("Content-Type" to "application/json"), request.headers)
        }
        assertJsonEqual(body(start), obj("type" to "start", "deviceId" to "dev-1"))
        assertJsonEqual(body(end), obj("type" to "end", "deviceId" to "dev-1"))
    }

    @Test
    fun c15_2_aSecondForegroundWithoutABackgroundOpensNoSecondSession(): Unit = runSuspend {
        val t = tracker()

        t.foreground()
        t.foreground()

        assertEquals(1, transport.requests.size)
        t.background()
        t.foreground()
        assertEquals(
            listOf("start", "end", "start"),
            transport.requests.map { body(it)["type"].stringValue },
        )
    }

    @Test
    fun c15_2_backgroundWithoutAnOpenSessionSendsNothing(): Unit = runSuspend {
        val t = tracker()

        t.background()
        t.foreground()
        t.background()
        t.background()

        assertEquals(listOf("start", "end"), transport.requests.map { body(it)["type"].stringValue })
        assertFalse(offline.hasPending)
    }

    @Test
    fun c15_2_theDeviceIdKeyIsAbsentWhenThereIsNone(): Unit = runSuspend {
        client().sendSession("start", null)

        val request = transport.requests.single()
        assertEquals("""{"type":"start"}""", request.body?.decodeToString())
        assertJsonEqual(body(request), obj("type" to "start"))
    }

    @Test
    fun c15_2_sendSessionReturnsOnAnyStatusAndThrowsOnATransportFailure(): Unit = runSuspend {
        for (status in listOf(200, 204, 404, 500)) {
            transport.status = status
            client().sendSession("end", "dev-1")
        }
        assertEquals(4, transport.requests.size)

        assertFailsWith<ConnectException> {
            client(ThrowingTransport(ConnectException("Connection refused"))).sendSession("start", "dev-1")
        }
        assertFailsWith<CancellationException> {
            client(ThrowingTransport(CancellationException("gone"))).sendSession("start", "dev-1")
        }
    }

    // MARK: C15.3 offline queue

    @Test
    fun c15_3_aThrowingTransportSavesStartAndEndWithTheirTimestamps(): Unit = runSuspend {
        val t = tracker()
        transport.offline = true

        now = 1_000L
        t.foreground()
        assertTrue(t.isOpen)
        now = 2_000L
        t.background()
        assertFalse(t.isOpen)

        assertEquals(
            listOf(OfflineSessionRecord("start", 1_000L), OfflineSessionRecord("end", 2_000L)),
            offline.load(),
        )
        assertTrue(offline.hasPending)
        assertJsonEqual(
            JsonValue.parse(kv.getString("orca_offline_sessions") ?: ""),
            arr(obj("type" to "start", "timestamp" to 1_000), obj("type" to "end", "timestamp" to 2_000)),
        )
        assertEquals(emptyList(), transport.requests)
    }

    @Test
    fun c15_3_theNextOnlineForegroundPostsTheQueueAndClearsIt(): Unit = runSuspend {
        val t = tracker()
        transport.offline = true
        now = 1_000L
        t.foreground()
        now = 2_000L
        t.background()

        transport.offline = false
        now = 3_000L
        t.foreground()

        val (start, flush) = transport.requests.toList().also { assertEquals(2, it.size) }
        assertJsonEqual(body(start), obj("type" to "start", "deviceId" to "dev-1"))
        assertEquals("POST", flush.method)
        assertEquals("http://localhost:8080/api/v1/app/counter/session/offline", flush.url.toString())
        assertEquals(client().headers + ("Content-Type" to "application/json"), flush.headers)
        assertJsonEqual(
            body(flush),
            obj(
                "deviceId" to "dev-1",
                "sessions" to arr(
                    obj("type" to "start", "timestamp" to 1_000),
                    obj("type" to "end", "timestamp" to 2_000),
                ),
            ),
        )
        assertEquals(emptyList(), offline.load())
        assertFalse(offline.hasPending)
        assertEquals("[]", kv.getString("orca_offline_sessions"))
    }

    @Test
    fun c15_3_aSecondForegroundFlushesAQueueThatGrewMeanwhile(): Unit = runSuspend {
        val t = tracker()
        t.foreground()
        assertEquals(1, transport.requests.size)

        now = 5_000L
        offline.save("end")
        t.foreground()

        val (start, flush) = transport.requests.toList().also { assertEquals(2, it.size) }
        assertJsonEqual(body(start), obj("type" to "start", "deviceId" to "dev-1"))
        assertEquals("http://localhost:8080/api/v1/app/counter/session/offline", flush.url.toString())
        assertJsonEqual(
            body(flush),
            obj("deviceId" to "dev-1", "sessions" to arr(obj("type" to "end", "timestamp" to 5_000))),
        )
        assertTrue(t.isOpen)
        assertFalse(offline.hasPending)
    }

    @Test
    fun c15_3_twoOverlappingFlushesSendOneRequest() {
        now = 1_000L
        offline.save("start")
        val gate = GatedTransport()
        val t = SessionTracker(client(gate), "dev-1", offline)

        var first: Result<Boolean>? = null
        suspend { t.flush() }.startCoroutine(Continuation(EmptyCoroutineContext) { first = it })
        assertEquals(1, gate.requests.size)
        assertNull(first, "the first flush waits for its answer")

        assertTrue(runSuspend { t.flush() }, "a flush that finds one running returns true")
        assertEquals(1, gate.requests.size, "and sends no request")
        assertTrue(offline.hasPending)

        gate.release()
        assertEquals(true, first?.getOrThrow())
        assertFalse(offline.hasPending)

        offline.save("end")
        assertTrue(runSuspend { t.flush() }, "the guard lifts once the first flush ends")
        assertEquals(2, gate.requests.size)
        assertFalse(offline.hasPending)
    }

    @Test
    fun c15_3_aFlushAnsweredWithAnythingBut200KeepsTheQueue(): Unit = runSuspend {
        now = 1_000L
        offline.save("start")
        val t = tracker()

        for (status in listOf(201, 204, 500)) {
            transport.status = status
            assertFalse(t.flush(), "status $status")
            assertEquals(listOf(OfflineSessionRecord("start", 1_000L)), offline.load())
        }
        transport.status = 200
        assertTrue(t.flush())
        assertEquals(emptyList(), offline.load())
    }

    @Test
    fun c15_3_aFlushThatThrowsKeepsTheQueue(): Unit = runSuspend {
        offline.save("end")
        transport.offline = true

        assertFalse(tracker().flush())
        assertTrue(offline.hasPending)
    }

    @Test
    fun c15_3_withoutADeviceIdTheFlushIsANoOpReturningTrue(): Unit = runSuspend {
        offline.save("start")

        assertTrue(tracker(deviceId = null).flush())

        assertEquals(emptyList(), transport.requests)
        assertTrue(offline.hasPending)
    }

    @Test
    fun c15_3_withNothingPendingTheFlushSendsNoRequest(): Unit = runSuspend {
        assertTrue(tracker().flush())
        kv.putString("orca_offline_sessions", "[]")
        assertTrue(tracker().flush())

        assertEquals(emptyList(), transport.requests)
    }

    @Test
    fun c15_3_aNon2xxAnswerToSessionIsNotQueued(): Unit = runSuspend {
        transport.status = 500
        val t = tracker()

        t.foreground()
        t.background()

        assertFalse(offline.hasPending)
        assertEquals(listOf("start", "end"), transport.requests.map { body(it)["type"].stringValue })
    }

    @Test
    fun c15_3_theQueueSurvivesARestart(): Unit = runSuspend {
        transport.offline = true
        now = 1_000L
        tracker().foreground()

        val restarted = OfflineSessionStore(MemoryKeyValueStore(kv.snapshot())) { 9_000L }

        assertEquals(listOf(OfflineSessionRecord("start", 1_000L)), restarted.load())
        transport.offline = false
        assertTrue(SessionTracker(client(), "dev-1", restarted).flush())
        assertEquals(emptyList(), restarted.load())
    }

    @Test
    fun c15_3_loadIsEmptyForMissingEmptyOrCorruptText() {
        assertEquals(emptyList(), offline.load())
        for (text in listOf("", "not json", """{"type":"start"}""", """[{"type":1,"timestamp":2}]""", "[1]")) {
            kv.putString("orca_offline_sessions", text)
            assertEquals(emptyList(), offline.load(), text)
            assertFalse(offline.hasPending, text)
        }
        offline.save("start")
        assertEquals(listOf(OfflineSessionRecord("start", 1_000L)), offline.load())
        offline.clear()
        assertEquals("[]", kv.getString("orca_offline_sessions"))
    }

    @Test
    fun c15_3_sendOfflineSessionsIsTrueOnlyOn200AndFalseOnAThrow(): Unit = runSuspend {
        val records = listOf(OfflineSessionRecord("start", 5L))
        for ((status, ok) in listOf(200 to true, 201 to false, 404 to false, 500 to false)) {
            transport.status = status
            assertEquals(ok, client().sendOfflineSessions("dev-1", records), "status $status")
        }
        assertFalse(client(ThrowingTransport(ConnectException("down"))).sendOfflineSessions("dev-1", records))
        assertFailsWith<CancellationException> {
            client(ThrowingTransport(CancellationException("gone"))).sendOfflineSessions("dev-1", records)
        }
    }
}
