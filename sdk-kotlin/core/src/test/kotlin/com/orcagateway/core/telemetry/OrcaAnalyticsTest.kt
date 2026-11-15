package com.orcagateway.core.telemetry

import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.support.StubEngine
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
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
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** A scheduler the test fires by hand: no thread, no wall clock. */
private class ManualScheduler : OrcaScheduler {
    class Timer(val delayMillis: Long, val action: () -> Unit) {
        var cancelled = false
        var fired = false
    }

    val timers = ArrayList<Timer>()

    val armed: List<Timer> get() = timers.filter { !it.cancelled && !it.fired }

    override fun schedule(delayMillis: Long, action: () -> Unit): () -> Unit {
        val timer = Timer(delayMillis, action)
        timers.add(timer)
        return { timer.cancelled = true }
    }

    /** Run every armed timer, as if its delay had passed. */
    fun fire() {
        for (timer in armed) {
            timer.fired = true
            timer.action()
        }
    }
}

/** A transport that throws instead of answering. */
private class ThrowingTransport(val error: Exception) : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse = throw error
}

/**
 * C15.4 on the Kotlin core: track() batches by size and by interval,
 * re-queues a failed send, and drops the oldest past the buffer limit. Ports
 * the five cases of sdk/test/orca_analytics_test.dart (Dart
 * sdk/lib/src/telemetry/orca_analytics.dart) and adds the timer, the
 * in-flight flush, the re-queue order, the timestamp format and
 * `OrcaClient.sendEvents` (Dart `OrcaClient.sendEvents`).
 */
class OrcaAnalyticsTest {
    private val sent: MutableList<List<Map<String, JsonValue>>> = Collections.synchronizedList(ArrayList())
    private val scheduler = ManualScheduler()

    /** A sender that records each batch and finishes without suspending. */
    private fun recording(ok: () -> Boolean = { true }): suspend (List<Map<String, JsonValue>>) -> Boolean = {
        sent.add(it)
        ok()
    }

    private fun analytics(
        sender: suspend (List<Map<String, JsonValue>>) -> Boolean = recording(),
        batchSize: Int = 20,
        maxBuffer: Int = 500,
        clock: () -> Long = { 1_794_736_800_123L },
    ): OrcaAnalytics = OrcaAnalytics(
        sender = sender,
        batchSize = batchSize,
        flushIntervalMillis = 10_000,
        maxBuffer = maxBuffer,
        clock = clock,
        scheduler = scheduler,
    )

    private fun types(batch: List<Map<String, JsonValue>>): List<String?> = batch.map { it["type"]?.stringValue }

    @AfterTest
    fun resetReporter() {
        OrcaDebug.reporter = null
    }

    // MARK: the five Dart cases

    @Test
    fun c15_4_flushesOnceBatchSizeIsReached() {
        val a = analytics(batchSize = 3)

        a.track("a")
        a.track("b")
        assertEquals(emptyList(), sent.toList(), "no flush before batchSize")
        a.track("c")

        assertEquals(1, sent.size)
        assertEquals(listOf("a", "b", "c"), types(sent[0]))
        assertEquals(0, a.bufferedCount)
    }

    @Test
    fun c15_4_aManualFlushSendsTypeTsAndPayload(): Unit = runSuspend {
        val a = analytics()

        a.track("screen_view", props("screen" to "home"))
        assertTrue(a.flush())

        assertEquals(1, sent.size)
        val event = sent[0].single()
        assertEquals(JsonValue.String("screen_view"), event["type"])
        assertJsonEqual(JsonValue.Object(assertNotNull(event["payload"]?.objectValue)), obj("screen" to "home"))
        assertIs<JsonValue.String>(event["ts"])
    }

    @Test
    fun c15_4_aFailedSendIsRequeuedAndALaterFlushSucceeds() = runSuspend {
        var ok = false
        val a = analytics(sender = recording { ok })

        a.track("x")
        assertFalse(a.flush())
        assertEquals(1, a.bufferedCount, "a failed send must not lose the event")

        ok = true
        assertTrue(a.flush())
        assertEquals(0, a.bufferedCount)
        assertEquals(listOf(listOf("x"), listOf("x")), sent.map(::types))
    }

    @Test
    fun c15_4_maxBufferDropsTheOldest() = runSuspend {
        val a = analytics(batchSize = 10_000, maxBuffer = 5)
        for (i in 0 until 20) a.track("e$i")

        assertEquals(5, a.bufferedCount)
        a.flush()
        assertEquals(listOf("e15", "e16", "e17", "e18", "e19"), types(sent.single()))
    }

    @Test
    fun c15_4_disposeFlushesTheRest() = runSuspend {
        val a = analytics()
        a.track("one")
        a.track("two")

        a.dispose()

        assertEquals(2, sent.sumOf { it.size })
        assertEquals(emptyList(), scheduler.armed, "dispose leaves no timer armed")
    }

    // MARK: the interval timer

    @Test
    fun c15_4_theIntervalFlushFiresThroughTheScheduler() {
        val a = analytics()

        a.track("a")
        assertEquals(listOf(10_000L), scheduler.armed.map { it.delayMillis })
        a.track("b")
        assertEquals(1, scheduler.timers.size, "a second track while a timer is armed arms no other")
        assertEquals(emptyList(), sent.toList())

        scheduler.fire()
        assertEquals(listOf(listOf("a", "b")), sent.map(::types))
        assertEquals(0, a.bufferedCount)

        a.track("c")
        assertEquals(2, scheduler.timers.size, "the next track arms a new timer")
        assertEquals(1, scheduler.armed.size)
    }

    @Test
    fun c15_4_aManualFlushCancelsTheArmedTimer() = runSuspend {
        val a = analytics()
        a.track("a")
        val timer = scheduler.armed.single()

        a.flush()

        assertTrue(timer.cancelled)
        assertEquals(emptyList(), scheduler.armed)
    }

    // MARK: the in-flight flush and the re-queue order

    /** A sender that holds the first batch until [release] answers it; later batches finish at once. */
    private class HeldSender {
        val batches: MutableList<List<Map<String, JsonValue>>> = Collections.synchronizedList(ArrayList())
        private var pending: Continuation<Boolean>? = null

        val send: suspend (List<Map<String, JsonValue>>) -> Boolean = { batch ->
            batches.add(batch)
            if (batches.size == 1) suspendCoroutine { pending = it } else true
        }

        fun release(ok: Boolean) {
            assertNotNull(pending).resume(ok)
            pending = null
        }
    }

    /** Start [a]'s flush without waiting; the result lands in the returned list once it finishes. */
    private fun startFlush(a: OrcaAnalytics): List<Boolean> {
        val results = Collections.synchronizedList(ArrayList<Boolean>())
        val block: suspend () -> Boolean = { a.flush() }
        block.startCoroutine(Continuation(EmptyCoroutineContext) { results.add(it.getOrThrow()) })
        return results
    }

    @Test
    fun c15_4_anInFlightFlushMakesASecondFlushANoOpReturningTrue() {
        val held = HeldSender()
        val a = analytics(sender = held.send, batchSize = 2)
        a.track("a")
        val first = startFlush(a)
        assertEquals(1, held.batches.size)
        assertEquals(emptyList(), first.toList(), "the first flush is still in flight")

        assertTrue(runSuspend { a.flush() })
        a.track("b")
        a.track("c")
        assertEquals(1, held.batches.size, "neither a manual nor a batchSize flush sends while one is in flight")

        held.release(true)
        assertEquals(listOf(true), first.toList())
        assertEquals(2, a.bufferedCount)
    }

    @Test
    fun c15_4_aRequeueKeepsOrderInFrontOfEventsTrackedMeanwhile() = runSuspend {
        val held = HeldSender()
        val a = analytics(sender = held.send)
        a.track("a")
        a.track("b")
        val first = startFlush(a)
        a.track("c")

        held.release(false)
        assertEquals(listOf(false), first.toList())
        assertEquals(3, a.bufferedCount)

        assertTrue(a.flush())
        assertEquals(listOf("a", "b", "c"), types(held.batches[1]))
    }

    @Test
    fun c15_4_aRequeueTrimsTheOldestPastMaxBuffer() = runSuspend {
        val held = HeldSender()
        val a = analytics(sender = held.send, maxBuffer = 3)
        a.track("a")
        a.track("b")
        startFlush(a)
        a.track("c")
        a.track("d")

        held.release(false)

        assertEquals(3, a.bufferedCount)
        a.flush()
        assertEquals(listOf("b", "c", "d"), types(held.batches[1]))
    }

    // MARK: the event shape

    @Test
    fun c15_4_tsIsUtcIso8601WithMillisecondsAndZFromTheClock() = runSuspend {
        var now = 1_794_736_800_123L
        val a = analytics(clock = { now })
        a.track("x")
        now = 1_767_323_045_000L
        a.track("y")
        a.flush()

        val events = sent.single()
        assertEquals(JsonValue.String("2026-11-15T10:00:00.123Z"), events[0]["ts"])
        assertEquals(JsonValue.String("2026-01-02T03:04:05.000Z"), events[1]["ts"], "milliseconds even when zero")
    }

    @Test
    fun c15_4_anEventWithoutPayloadHasNoPayloadKey() = runSuspend {
        val a = analytics()
        a.track("x")
        a.flush()

        val event = sent.single().single()
        assertEquals(setOf("type", "ts"), event.keys)
        assertNull(event["payload"])
    }

    // MARK: OrcaClient.sendEvents

    private val base = URI("http://localhost:8080")

    private fun client(transport: HttpTransport): OrcaClient =
        OrcaClient(base, "counter", apiKey = "k", environment = "staging", deviceId = "dev-1", transport = transport)

    private val twoEvents: List<Map<String, JsonValue>> = listOf(
        props("type" to "a", "ts" to "2026-11-15T10:00:00.123Z", "payload" to mapOf("n" to 1)),
        props("type" to "b", "ts" to "2026-11-15T10:00:00.124Z"),
    )

    @Test
    fun c15_4_sendEventsPostsTheEventsWithTheClientHeaders() = runSuspend {
        val stub = StubEngine(ByteArray(0))
        stub.forced = HttpResponse(200)
        val c = client(stub)

        assertTrue(c.sendEvents(twoEvents))

        val request = stub.requests.single()
        assertEquals("POST", request.method)
        assertEquals("http://localhost:8080/api/v1/app/counter/events", request.url.toString())
        assertEquals(c.headers + ("Content-Type" to "application/json"), request.headers)
        assertJsonEqual(
            JsonValue.parse(assertNotNull(request.body)),
            obj(
                "events" to arr(
                    obj("type" to "a", "ts" to "2026-11-15T10:00:00.123Z", "payload" to obj("n" to 1)),
                    obj("type" to "b", "ts" to "2026-11-15T10:00:00.124Z"),
                ),
            ),
        )
    }

    @Test
    fun c15_4_sendEventsIsTrueOn2xxAndFalseOnAnyOtherStatus() = runSuspend {
        val stub = StubEngine(ByteArray(0))
        val c = client(stub)
        val expected = listOf(
            200 to true, 202 to true, 204 to true, 299 to true,
            300 to false, 404 to false, 500 to false,
        )
        for ((status, ok) in expected) {
            stub.forced = HttpResponse(status)
            assertEquals(ok, c.sendEvents(twoEvents), "status $status")
        }
    }

    @Test
    fun c15_4_sendEventsIsFalseOnATransportThrowAndRethrowsCancellation(): Unit = runSuspend {
        assertFalse(client(ThrowingTransport(ConnectException("Connection refused"))).sendEvents(twoEvents))
        assertFailsWith<CancellationException> {
            client(ThrowingTransport(CancellationException("gone"))).sendEvents(twoEvents)
        }
    }

    @Test
    fun c15_4_sendEventsWithNoEventsIsTrueWithoutARequest() = runSuspend {
        val stub = StubEngine(ByteArray(0))
        stub.forced = HttpResponse(500)

        assertTrue(client(stub).sendEvents(emptyList()))
        assertEquals(emptyList(), stub.requests)
    }

    @Test
    fun c15_4_sendEventsGoesThroughTheClientSoDevToolsSeesIt() = runSuspend {
        val events = Collections.synchronizedList(ArrayList<DevToolsEvent>())
        OrcaDebug.reporter = { events.add(it) }
        val stub = StubEngine(ByteArray(0))
        stub.forced = HttpResponse(202)

        client(stub).sendEvents(twoEvents)

        val network = events.single { it.type == "network" }
        assertEquals(JsonValue.String("POST"), network.payload["method"])
    }

    @Test
    fun c15_4_forClientSendsBatchesThroughTheClient() {
        val stub = StubEngine(ByteArray(0))
        stub.forced = HttpResponse(200)
        val a = OrcaAnalytics.forClient(client(stub), batchSize = 2)

        a.track("a")
        a.track("b", props("n" to 1))

        val request = stub.requests.single()
        assertEquals("http://localhost:8080/api/v1/app/counter/events", request.url.toString())
        val body = JsonValue.parse(assertNotNull(request.body))
        assertEquals(listOf("a", "b"), body["events"].arrayValue?.map { it["type"].stringValue })
        assertEquals(0, a.bufferedCount)
    }
}
