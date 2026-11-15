package com.orcagateway.core.telemetry

import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.cancellation.CancellationException
import kotlin.coroutines.startCoroutine

/**
 * Runs an action once after a delay, for [OrcaAnalytics]' flush timer (Dart
 * uses a `Timer`; Swift twin: the scheduler closure of `OrcaAnalytics`).
 * Tests pass one they fire by hand.
 */
public fun interface OrcaScheduler {
    /**
     * Runs [action] once, on any thread, after [delayMillis]. Returns a
     * function that cancels the action if it has not run yet.
     */
    public fun schedule(delayMillis: Long, action: () -> Unit): () -> Unit
}

/** The default [OrcaScheduler]: one shared daemon thread. */
private object ExecutorScheduler : OrcaScheduler {
    private val executor: ScheduledExecutorService by lazy {
        Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "orca-analytics").apply { isDaemon = true }
        }
    }

    override fun schedule(delayMillis: Long, action: () -> Unit): () -> Unit {
        val future = executor.schedule(action, delayMillis, TimeUnit.MILLISECONDS)
        return { future.cancel(false) }
    }
}

/**
 * Buffered, batched analytics emitter (Epic 47.4). Ports Dart `OrcaAnalytics`
 * (sdk/lib/src/telemetry/orca_analytics.dart); Swift twin `OrcaAnalytics`.
 *
 * [track] appends to an in-memory buffer, which flushes through [sender]
 * when it holds [batchSize] events or [flushIntervalMillis] after the first
 * pending one, whichever comes first. A failed send puts the batch back in
 * front, and past [maxBuffer] the oldest events are dropped, so a down
 * endpoint cannot grow memory without limit.
 *
 * Build one at app start with [forClient], call [track] from the UI and
 * [dispose] on teardown; the SDK does not wire it in, as in Flutter.
 * Thread-safe: track and flush may be called from any thread.
 */
public class OrcaAnalytics(
    /** Sends one batch; true when it went through. [OrcaClient.sendEvents] is one. */
    private val sender: suspend (List<Map<String, JsonValue>>) -> Boolean,
    /** Flush once this many events are buffered. */
    public val batchSize: Int = 20,
    /** Flush at least this often while events are pending. */
    public val flushIntervalMillis: Long = 10_000,
    /** Hard cap on buffered events; the oldest are dropped beyond it. */
    public val maxBuffer: Int = 500,
    /** Milliseconds since the epoch, stamped on each event. */
    private val clock: () -> Long = System::currentTimeMillis,
    /** Arms the flush timer. */
    private val scheduler: OrcaScheduler = ExecutorScheduler,
) {
    private val lock = Any()
    private val buffer = ArrayList<Map<String, JsonValue>>()
    private var cancelTimer: (() -> Unit)? = null
    private var flushing = false

    /** How many events wait to be sent. For tests. */
    public val bufferedCount: Int get() = synchronized(lock) { buffer.size }

    /**
     * Queues an event: [type] is its name (e.g. `screen_view`), [payload]
     * any JSON context, and the clock's time goes in `ts` as UTC ISO 8601
     * with milliseconds. Starts a flush, without waiting for it, once
     * [batchSize] events are buffered.
     */
    public fun track(type: String, payload: Map<String, JsonValue>? = null) {
        val event = LinkedHashMap<String, JsonValue>()
        event["type"] = JsonValue.String(type)
        event["ts"] = JsonValue.String(timestamp(clock()))
        payload?.let { event["payload"] = JsonValue.Object(it) }
        val full = synchronized(lock) {
            buffer.add(event)
            trim()
            if (cancelTimer == null) cancelTimer = scheduler.schedule(flushIntervalMillis) { startFlush() }
            buffer.size >= batchSize
        }
        if (full) startFlush()
    }

    /**
     * Sends the buffered events now. A flush already in flight makes this a
     * no-op. True when nothing needed sending or the send went through;
     * false when it failed and the batch went back in front of the buffer.
     */
    public suspend fun flush(): Boolean {
        val batch = synchronized(lock) {
            cancelTimer?.invoke()
            cancelTimer = null
            if (flushing || buffer.isEmpty()) return true
            flushing = true
            val taken = ArrayList(buffer)
            buffer.clear()
            taken
        }
        try {
            val ok = sender(batch)
            if (!ok) {
                synchronized(lock) {
                    buffer.addAll(0, batch)
                    trim()
                }
            }
            return ok
        } finally {
            synchronized(lock) { flushing = false }
        }
    }

    /** Flushes and stops the timer. Call from the host's teardown. */
    public suspend fun dispose() {
        flush()
        synchronized(lock) {
            cancelTimer?.invoke()
            cancelTimer = null
        }
    }

    /** Starts [flush] without waiting for it; its result, or a throw of the sender, is dropped. */
    private fun startFlush() {
        val block: suspend () -> Boolean = { flush() }
        block.startCoroutine(Continuation(EmptyCoroutineContext) {})
    }

    /** Drops the oldest events past [maxBuffer]. Called with the lock held. */
    private fun trim() {
        if (buffer.size > maxBuffer) buffer.subList(0, buffer.size - maxBuffer).clear()
    }

    public companion object {
        /**
         * `2026-11-15T10:00:00.123Z`, as Dart's `toUtc().toIso8601String()`
         * prints it. A fresh calendar per call, no `java.time`: core ships in
         * the Android SDK at minSdk 24 (dates as in resolver/Transforms.kt).
         */
        private fun timestamp(epochMillis: Long): String {
            val c = GregorianCalendar(TimeZone.getTimeZone("UTC"))
            c.timeInMillis = epochMillis
            return String.format(
                Locale.ROOT,
                "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
                c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
                c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE), c.get(Calendar.SECOND), c.get(Calendar.MILLISECOND),
            )
        }

        /** An emitter that sends through [client]'s [sendEvents] (Dart `OrcaAnalytics.forClient`). */
        public fun forClient(
            client: OrcaClient,
            batchSize: Int = 20,
            flushIntervalMillis: Long = 10_000,
            maxBuffer: Int = 500,
        ): OrcaAnalytics = OrcaAnalytics(
            sender = { client.sendEvents(it) },
            batchSize = batchSize,
            flushIntervalMillis = flushIntervalMillis,
            maxBuffer = maxBuffer,
        )
    }
}

/**
 * `POST /api/v1/app/{appId}/events` with `{"events": [...]}` and the
 * client's headers (Dart `OrcaClient.sendEvents`, Epic 47.4; Swift twin
 * `OrcaClient.sendEvents`). Best effort: true on a 2xx, false on any other
 * status or when the request fails, so the caller can re-queue; an empty
 * list is true without a request. Cancellation still goes up.
 */
public suspend fun OrcaClient.sendEvents(events: List<Map<String, JsonValue>>): Boolean {
    if (events.isEmpty()) return true
    return try {
        val headers = LinkedHashMap(this.headers)
        headers["Content-Type"] = "application/json"
        val body = JsonValue.Object(mapOf("events" to JsonValue.Array(events.map { JsonValue.Object(it) })))
        val response = send(HttpRequest("POST", endpointUrl("events"), headers, body.encoded().encodeToByteArray()))
        response.status in 200..299
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        false
    }
}
