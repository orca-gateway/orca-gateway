package com.orcagateway.sdk.debug

import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Test
import java.net.InetAddress
import java.util.concurrent.TimeUnit
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * A local stand-in for Orca DevTools' WebSocket server, on 127.0.0.1 at a
 * port the OS picks: every connection is upgraded, and every text message
 * it receives is kept, parsed, per connection. [goAway] and [comeBack] play
 * a DevTools restart on the same address without binding the port twice.
 * With [likeDart] it answers a compression offer the way DevTools (dart:io)
 * does: `permessage-deflate; client_max_window_bits=15`.
 */
private class DevToolsStub(likeDart: Boolean = false) {
    private val lock = Any()
    private val opened = mutableListOf<List<JsonValue>>()
    private val sockets = mutableListOf<WebSocket>()

    @Volatile
    private var away = false
    private val server = MockWebServer()

    init {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                if (away) return MockResponse().setResponseCode(503)
                val response = MockResponse().withWebSocketUpgrade(connection())
                val offer = request.getHeader("Sec-WebSocket-Extensions")
                if (likeDart && offer?.contains("permessage-deflate", ignoreCase = true) == true) {
                    response.setHeader("Sec-WebSocket-Extensions", "permessage-deflate; client_max_window_bits=15")
                }
                return response
            }
        }
        server.start(InetAddress.getByName("127.0.0.1"), 0)
    }

    /** The server side of one upgraded connection. */
    private fun connection() = object : WebSocketListener() {
        private val received = mutableListOf<JsonValue>()

        override fun onOpen(webSocket: WebSocket, response: Response) {
            synchronized(lock) {
                opened.add(received)
                sockets.add(webSocket)
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            synchronized(lock) { received += JsonValue.parse(text) }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(1000, null)
        }
    }

    val url: String get() = "ws://127.0.0.1:${server.port}"

    /** Every message received, connection after connection. */
    val messages: List<JsonValue> get() = synchronized(lock) { opened.flatten() }

    /** The messages of each upgraded connection, in the order they opened. */
    val connections: List<List<JsonValue>> get() = synchronized(lock) { opened.map { it.toList() } }

    /** The next request the server read (the upgrade), or null after 5 s. */
    fun takeRequest(): RecordedRequest? = server.takeRequest(5, TimeUnit.SECONDS)

    /**
     * DevTools quits: every open connection is closed from this side, going
     * away (1001), and upgrades are turned down (503) until [comeBack].
     */
    fun goAway() {
        away = true
        synchronized(lock) { sockets.toList() }.forEach { it.close(1001, "DevTools quit") }
    }

    /** DevTools is back on the same address. */
    fun comeBack() {
        away = false
    }

    /** Closes the port and every open connection. */
    fun stop() = server.shutdown()
}

/** Waits up to [timeoutMs] for [condition], checking every 20 ms. */
private fun eventually(timeoutMs: Long = 5_000, condition: () -> Boolean): Boolean {
    val deadline = System.nanoTime() + timeoutMs * 1_000_000
    while (System.nanoTime() < deadline) {
        if (condition()) return true
        Thread.sleep(20)
    }
    return condition()
}

/** The WebSocket client against a local DevTools stub (Swift `DevToolsClientTests`). */
class DevToolsClientTest {
    private val handshake = DevToolsEvent.deviceInfo(platform = "Android", deviceModel = "test", appName = "Tests")

    private fun client(url: String, backoff: (Int) -> Duration? = { if (it < 10) 50.milliseconds else null }) =
        DevToolsClient(url, handshake, deviceId = "test-device", backoff = backoff)

    @After
    fun reset() {
        OrcaDebug.reporter = null
    }

    /** Swift `testDeviceInfoComesFirstThenEvents`. */
    @Test
    fun c1_deviceInfoComesFirstThenEvents() {
        val stub = DevToolsStub()
        val client = client(stub.url)
        try {
            client.report(DevToolsEvent.error(message = "before connect")) // dropped, as in Flutter
            client.connect()
            assertTrue(eventually { client.isConnected && stub.messages.isNotEmpty() })
            client.report(DevToolsEvent.error(message = "after connect"))
            assertTrue(eventually { stub.messages.size >= 2 })

            val first = stub.messages.first()
            assertEquals("device_info", first["type"].stringValue)
            assertEquals("test-device", first["deviceId"].stringValue)
            assertEquals(JsonValue.Object(handshake.payload), first["payload"])
            assertNotNull(first["timestamp"].intValue)
            assertEquals(listOf(null, "after connect"), stub.messages.map { it["payload"]["message"].stringValue })
        } finally {
            client.disconnect()
            stub.stop()
        }
    }

    /**
     * DevTools is a Flutter app: dart:io answers an offer of
     * `permessage-deflate` with `client_max_window_bits=15`, which OkHttp
     * refuses by closing with 1010 ("unexpected Sec-WebSocket-Extensions in
     * response header"), so a client that offers compression reconnects over
     * and over and never delivers an event. Offering none, it stays.
     */
    @Test
    fun c1_aDartDevToolsServerKeepsTheClient() {
        val stub = DevToolsStub(likeDart = true)
        val client = client(stub.url)
        try {
            client.connect()
            assertTrue(eventually { client.isConnected && stub.messages.isNotEmpty() }, "device_info arrives")
            client.report(DevToolsEvent.error(message = "after connect"))
            assertTrue(eventually { stub.messages.size >= 2 }, "a later event arrives")

            assertEquals(listOf("device_info", "error"), stub.messages.map { it["type"].stringValue })
            assertEquals(1, stub.connections.size, "one connection, kept")
            assertTrue(client.isConnected)
            val upgrade = assertNotNull(stub.takeRequest())
            assertNull(upgrade.getHeader("Sec-WebSocket-Extensions"), "no compression offered")
        } finally {
            client.disconnect()
            stub.stop()
        }
    }

    /**
     * Swift `testReconnectsAfterDevToolsRestarts`. One stub plays DevTools
     * quitting and coming back on the same address: MockWebServer binds a
     * picked port without SO_REUSEADDR, so on Linux a second server on that
     * port fails ("Address already in use") while the first one's closed
     * connection sits in TIME_WAIT. The client here never gives up, so the
     * restart does not race the ten tries.
     */
    @Test
    fun c2_reconnectsAfterDevToolsRestarts() {
        val stub = DevToolsStub()
        val client = client(stub.url) { 50.milliseconds }
        try {
            client.connect()
            assertTrue(eventually { stub.messages.size == 1 })

            stub.goAway()
            assertTrue(eventually { !client.isConnected })

            stub.comeBack()
            assertTrue(
                eventually { client.isConnected && stub.connections.getOrNull(1)?.isNotEmpty() == true },
                "a new connection",
            )
            client.report(DevToolsEvent.error(message = "after restart"))
            assertTrue(eventually { stub.connections[1].size >= 2 })
            assertEquals(
                listOf("device_info", "error"),
                stub.connections[1].map { it["type"].stringValue },
                "device_info again on the new connection, then events",
            )
        } finally {
            client.disconnect()
            stub.stop()
        }
    }

    /** Swift `testARefusedClientGivesUpAfterTenTries`. */
    @Test
    fun c3_aRefusedClientGivesUpAfterTenTries() {
        // A port with nothing behind it: start a stub, note its URL, stop it.
        val stub = DevToolsStub()
        val url = stub.url
        stub.stop()

        val asked = mutableListOf<Int>()
        fun askedSoFar() = synchronized(asked) { asked.toList() }
        val client = client(url) { attempt ->
            synchronized(asked) { asked += attempt }
            DevToolsClient.reconnectDelay(attempt)?.let { 10.milliseconds }
        }
        try {
            client.connect()
            assertTrue(eventually(10_000) { askedSoFar().lastOrNull() == 10 })
            assertEquals((0..10).toList(), askedSoFar())
            assertFalse(client.isConnected)
        } finally {
            client.disconnect()
        }
    }

    /** Swift `testReconnectDelaysFollowFlutter`. */
    @Test
    fun c4_reconnectDelaysFollowFlutter() {
        assertEquals(
            listOf(1, 2, 4, 8, 16, 30, 30, 30, 30, 30).map { it.seconds } + null,
            (0..10).map { DevToolsClient.reconnectDelay(it) },
        )
    }

    /** Swift `testDevToolsIsOptIn`. */
    @Test
    fun c5_devToolsIsOptIn() {
        val config = OrcaDebugConfig()
        assertFalse(config.enabled)
        assertEquals("ws://localhost:6363", config.url)
        assertNull(OrcaDebug.start(config))
        assertFalse(OrcaDebug.isEnabled)
        assertEquals("ws://10.0.0.5:7000", OrcaDebugConfig(enabled = true, host = "10.0.0.5", port = 7000).url)
    }
}
