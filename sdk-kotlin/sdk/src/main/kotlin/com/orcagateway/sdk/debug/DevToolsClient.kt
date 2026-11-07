package com.orcagateway.sdk.debug

import android.os.Build
import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.DevToolsReporter
import com.orcagateway.core.debug.OrcaDebug
import kotlinx.serialization.SerializationException
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.UUID
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.ThreadFactory
import java.util.concurrent.TimeUnit
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * Whether and where the SDK sends DevTools events (Flutter
 * `OrcaDebugConfig`). Off unless [enabled]. DevTools runs on the Mac: the
 * emulator reaches it at 10.0.2.2 (or at localhost after
 * `adb reverse tcp:6363 tcp:6363`), a device needs the Mac's address in
 * [host].
 */
public data class OrcaDebugConfig(
    public val enabled: Boolean = false,
    public val host: String = "localhost",
    public val port: Int = 6363,
    /** Shown in DevTools' device list. */
    public val appName: String? = null,
    /** Sent in `device_info`; pass the app's version name. */
    public val appVersion: String = "1.0.0",
) {
    /** `ws://host:port`, or null when that is not a valid address. */
    public val url: String?
        get() = "ws://$host:$port".takeIf { "http://$host:$port".toHttpUrlOrNull() != null }
}

/**
 * Connect to DevTools when [config] is enabled (Flutter `OrcaDebug.init`):
 * any earlier client is disconnected first, and a disabled config just
 * stops. Returns the client that now receives the SDK's events.
 */
public fun OrcaDebug.start(config: OrcaDebugConfig): DevToolsClient? {
    stop()
    val url = config.url
    if (!config.enabled || url == null) return null
    val client = DevToolsClient(
        url,
        DevToolsEvent.deviceInfo(
            platform = DevToolsClient.platform,
            deviceModel = DevToolsClient.deviceModel,
            appVersion = config.appVersion,
            appName = config.appName,
        ),
    )
    reporter = client
    client.connect()
    return client
}

/** Disconnect and stop sending events. */
public fun OrcaDebug.stop() {
    (reporter as? DevToolsClient)?.disconnect()
    reporter = null
}

/**
 * The WebSocket to Orca DevTools, the Android side of Flutter's
 * sdk/lib/src/debug/dev_tools_client.dart, on OkHttp:
 * - `device_info` goes first on every connect;
 * - events are dropped while not connected, as in Flutter;
 * - a lost or refused connection is retried after 1, 2, 4, 8, 16, then
 *   30 s, at most 10 times in a row; a connect resets the count.
 *
 * [backoff] replaces [reconnectDelay] (tests use short waits). [url] must be
 * a `ws://` address OkHttp can parse.
 */
public class DevToolsClient(
    public val url: String,
    private val handshake: DevToolsEvent,
    public val deviceId: String = UUID.randomUUID().toString(),
    private val backoff: (attempt: Int) -> Duration? = { reconnectDelay(it) },
) : DevToolsReporter {
    private val request = Request.Builder().url(url).build()
    private val http = OkHttpClient()

    // One thread runs everything below, like Swift's serial queue; it ends
    // when the client is idle and comes back for the next task.
    private val executor = ScheduledThreadPoolExecutor(1, ThreadFactory { Thread(it, "OrcaDevTools").apply { isDaemon = true } })
        .apply {
            setKeepAliveTime(1, TimeUnit.SECONDS)
            allowCoreThreadTimeOut(true)
        }
    private var socket: WebSocket? = null

    @Volatile
    private var connected = false
    private var attempts = 0
    private var running = false
    private var retry: ScheduledFuture<*>? = null

    /** Whether the socket is open now (tests). */
    public val isConnected: Boolean get() = connected

    /** Open the socket, and keep it open until [disconnect]. */
    public fun connect() {
        on {
            if (running) return@on
            running = true
            attempts = 0
            open()
        }
    }

    public fun disconnect() {
        on {
            running = false
            retry?.cancel(false)
            retry = null
            socket?.close(GOING_AWAY, null)
            socket = null
            connected = false
        }
    }

    override fun report(event: DevToolsEvent) {
        on { if (connected) send(event) }
    }

    // Connection

    private fun on(block: () -> Unit) = executor.execute(block)

    private fun open() {
        if (!running) return
        socket = http.newWebSocket(request, listener)
    }

    private fun send(event: DevToolsEvent) {
        val socket = socket ?: return
        val text = try {
            event.envelope(deviceId, System.currentTimeMillis()).encoded()
        } catch (_: SerializationException) {
            return
        }
        // A failed write comes back as onFailure.
        socket.send(text)
    }

    private fun opened(webSocket: WebSocket) {
        if (webSocket !== socket) return
        connected = true
        attempts = 0
        send(handshake)
    }

    private fun lost(webSocket: WebSocket) {
        if (webSocket !== socket) return
        socket = null
        connected = false
        if (!running) return
        val delay = backoff(attempts) ?: return
        attempts += 1
        retry = executor.schedule(Runnable { open() }, delay.inWholeMilliseconds, TimeUnit.MILLISECONDS)
    }

    // OkHttp calls these on its own threads; each hops onto the executor.
    private val listener = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) = on { opened(webSocket) }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(NORMAL, null)
            on { lost(webSocket) }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) = on { lost(webSocket) }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) = on { lost(webSocket) }
    }

    public companion object {
        public const val maxReconnectAttempts: Int = 10

        /**
         * The wait before reconnect number [attempt] (from 0), or null when
         * the client gives up.
         */
        public fun reconnectDelay(attempt: Int): Duration? =
            if (attempt !in 0 until maxReconnectAttempts) null else minOf(1 shl attempt, 30).seconds

        private const val NORMAL = 1000
        private const val GOING_AWAY = 1001

        internal const val platform: String = "Android"

        /** Maker and model (`Google Pixel 8`); the emulator reports its image. */
        internal val deviceModel: String
            get() = listOfNotNull(Build.MANUFACTURER, Build.MODEL)
                .filter { it.isNotBlank() }
                .joinToString(" ")
                .ifEmpty { "unknown" }
    }
}
