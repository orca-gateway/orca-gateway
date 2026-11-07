package com.orcagateway.sdk.debug

import com.orcagateway.core.debug.DevToolsEvent
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Test
import java.net.InetAddress
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * A local stand-in for Orca DevTools' WebSocket server, on 127.0.0.1: every
 * connection is upgraded, and every text message it receives is kept,
 * parsed. [port] 0 lets the OS pick one; a given port is reused, so a stub
 * can come back where a stopped one was.
 */
private class DevToolsStub(port: Int = 0) {
    private val received = mutableListOf<JsonValue>()
    private val server = MockWebServer()

    private val listener = object : WebSocketListener() {
        override fun onMessage(webSocket: WebSocket, text: String) {
            synchronized(received) { received += JsonValue.parse(text) }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(1000, null)
        }
    }

    init {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse =
                MockResponse().withWebSocketUpgrade(listener)
        }
        server.start(InetAddress.getByName("127.0.0.1"), port)
    }

    val port: Int get() = server.port
    val url: String get() = "ws://127.0.0.1:$port"
    val messages: List<JsonValue> get() = synchronized(received) { received.toList() }

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
     * Swift `testReconnectsAfterDevToolsRestarts`. The client here never
     * gives up, so the restart does not race the ten tries.
     */
    @Test
    fun c2_reconnectsAfterDevToolsRestarts() {
        val stub = DevToolsStub()
        val port = stub.port
        val client = client(stub.url) { 50.milliseconds }
        var again: DevToolsStub? = null
        try {
            client.connect()
            assertTrue(eventually { stub.messages.size == 1 })

            stub.stop()
            assertTrue(eventually { !client.isConnected })

            again = DevToolsStub(port)
            val restarted = again
            assertTrue(
                eventually { restarted.messages.firstOrNull()?.get("type")?.stringValue == "device_info" },
                "device_info again on the new connection",
            )
        } finally {
            client.disconnect()
            stub.stop()
            again?.stop()
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
