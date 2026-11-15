package com.orcagateway.core.client

import com.orcagateway.core.json.JsonValue
import kotlinx.serialization.SerializationException
import kotlin.coroutines.cancellation.CancellationException

/**
 * One session event kept while the device was offline: [type] is `start`
 * or `end`, [timestamp] milliseconds since the epoch. Stored and sent as
 * `{"type", "timestamp"}`. Ports Dart `OfflineSessionRecord`
 * (sdk/lib/src/client/offline_session_store.dart); Swift twin
 * `OfflineSessionRecord`.
 */
public data class OfflineSessionRecord(public val type: String, public val timestamp: Long) {
    internal fun toJson(): JsonValue = JsonValue.Object(
        linkedMapOf("type" to JsonValue.String(type), "timestamp" to JsonValue.Int(timestamp)),
    )
}

/**
 * The queue of session events that could not be sent, kept in [store]
 * under `orca_offline_sessions` as a JSON array so it survives a restart.
 * Ports Dart `OfflineSessionStore`
 * (sdk/lib/src/client/offline_session_store.dart); Swift twin
 * `OfflineSessionStore`. Thread-safe.
 */
public class OfflineSessionStore(
    private val store: KeyValueStore,
    /** Milliseconds since the epoch, stamped on each saved event. */
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val lock = Any()

    /** Appends a [type] event stamped with the clock's time. */
    public fun save(type: String) {
        synchronized(lock) {
            val records = load() + OfflineSessionRecord(type, clock())
            store.putString(KEY, JsonValue.Array(records.map { it.toJson() }).encoded())
        }
    }

    /** Every queued event, oldest first; empty when nothing is saved or the text is not a valid queue. */
    public fun load(): List<OfflineSessionRecord> = synchronized(lock) {
        val raw = store.getString(KEY)
        if (raw.isNullOrEmpty()) return emptyList()
        val items = try {
            JsonValue.parse(raw).arrayValue
        } catch (_: SerializationException) {
            null
        } ?: return emptyList()
        items.map { item ->
            val type = item["type"].stringValue
            val timestamp = item["timestamp"].intValue
            if (type == null || timestamp == null) return emptyList()
            OfflineSessionRecord(type, timestamp)
        }
    }

    /** Empties the queue (writes `[]`), after a flush went through. */
    public fun clear() {
        synchronized(lock) { store.putString(KEY, "[]") }
    }

    /** Whether any event waits to be sent. */
    public val hasPending: Boolean get() = load().isNotEmpty()

    private companion object {
        const val KEY = "orca_offline_sessions"
    }
}

/**
 * Sends a session start when the app comes to the foreground and an end
 * when it goes to the background, as `{type, deviceId}` with no duration:
 * the server times sessions from start and end. A send that fails to reach
 * the server is queued in [offline] and flushed on the next foreground.
 * Ports the session part of Dart `_OrcaAppState`
 * (sdk/lib/src/widgets/orca_app.dart) with `OrcaClient.sendSessionStart`,
 * `sendSessionEnd` and `flushOfflineSessions`
 * (sdk/lib/src/client/orca_client.dart); Swift twin `SessionTracker`.
 *
 * Different from Flutter on purpose: Flutter sends a start on every
 * `resumed` (also after `inactive`), which can open two sessions; the
 * tracker keeps one session per foreground period. Thread-safe.
 */
public class SessionTracker(
    private val client: OrcaClient,
    /** Sent with each event and needed to flush the queue. */
    private val deviceId: String?,
    private val offline: OfflineSessionStore,
) {
    private val lock = Any()
    private var open = false
    private var flushing = false

    /** Whether a session is open (started and not yet ended). */
    public val isOpen: Boolean get() = synchronized(lock) { open }

    /**
     * Opens a session unless one is open, posting `start` (queued offline
     * when the request fails), then [flush]es the queue on every call, as
     * Flutter flushes on every `resumed`.
     */
    public suspend fun foreground() {
        val wasOpen = synchronized(lock) { open.also { open = true } }
        if (!wasOpen) post("start")
        flush()
    }

    /** Ends the open session: posts `end` (queued offline when the request fails). With none open it does nothing. */
    public suspend fun background() {
        val wasOpen = synchronized(lock) { open.also { open = false } }
        if (wasOpen) post("end")
    }

    /**
     * Sends the offline queue. True when it went through (and the queue was
     * cleared) or when nothing needed sending: no device id (Dart skips the
     * flush without one), an empty queue, or a flush already in flight,
     * which sends the queue itself. False keeps the queue.
     */
    public suspend fun flush(): Boolean {
        val id = deviceId ?: return true
        val records = synchronized(lock) {
            if (flushing) return true
            offline.load().also { if (it.isNotEmpty()) flushing = true }
        }
        if (records.isEmpty()) return true
        try {
            val ok = client.sendOfflineSessions(id, records)
            if (ok) offline.clear()
            return ok
        } finally {
            synchronized(lock) { flushing = false }
        }
    }

    /** Dart queues only when the POST throws: any answer, 4xx and 5xx too, counts as sent. */
    private suspend fun post(type: String) {
        try {
            client.sendSession(type, deviceId)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            offline.save(type)
        }
    }
}

/**
 * `POST /api/v1/app/{appId}/session` with `{"type": type, "deviceId": id}`
 * (no `deviceId` key when it is null) and the client's headers. Ports Dart
 * `OrcaClient.sendSessionStart` and `sendSessionEnd`
 * (sdk/lib/src/client/orca_client.dart); Swift twin `OrcaClient.sendSession`.
 * Any status returns normally; a request that gets no answer throws.
 */
public suspend fun OrcaClient.sendSession(type: String, deviceId: String?) {
    val body = linkedMapOf<String, JsonValue>("type" to JsonValue.String(type))
    deviceId?.let { body["deviceId"] = JsonValue.String(it) }
    postJson("session", JsonValue.Object(body))
}

/**
 * `POST /api/v1/app/{appId}/session/offline` with `{"deviceId", "sessions":
 * [{"type", "timestamp"}]}` and the client's headers. Ports the request of
 * Dart `OrcaClient.flushOfflineSessions` (sdk/lib/src/client/orca_client.dart);
 * Swift twin `OrcaClient.sendOfflineSessions`. True only on a 200; false on
 * any other status or a request that gets no answer. Cancellation still goes up.
 */
public suspend fun OrcaClient.sendOfflineSessions(deviceId: String, sessions: List<OfflineSessionRecord>): Boolean =
    try {
        val body = JsonValue.Object(
            linkedMapOf(
                "deviceId" to JsonValue.String(deviceId),
                "sessions" to JsonValue.Array(sessions.map { it.toJson() }),
            ),
        )
        postJson("session/offline", body).status == 200
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        false
    }

/** A JSON POST to `{appId}/[rest]` through [OrcaClient.send], with the client's headers. */
private suspend fun OrcaClient.postJson(rest: String, body: JsonValue): HttpResponse {
    val headers = LinkedHashMap(this.headers)
    headers["Content-Type"] = "application/json"
    return send(HttpRequest("POST", endpointUrl(rest), headers, body.encoded().encodeToByteArray()))
}
