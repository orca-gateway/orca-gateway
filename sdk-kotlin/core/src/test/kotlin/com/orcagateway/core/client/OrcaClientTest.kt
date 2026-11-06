package com.orcagateway.core.client

import com.orcagateway.core.capabilities.CapabilityVector
import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.encoding
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.StubEngine
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** T2.1 (the capability handshake) and T2.2 (headers) on the Kotlin client. */
class OrcaClientTest {
    private val base = URI("http://localhost:8080")

    private fun counterPage(): ByteArray = Fixtures.text("sdk-swift/Tests/Pages/counter-home.json").encodeToByteArray()

    private fun client(stub: StubEngine, device: DeviceInfo = DeviceInfo()): OrcaClient =
        OrcaClient(base, "counter", device = device, transport = stub)

    private fun json(body: ByteArray?): JsonValue = JsonValue.parse(body ?: ByteArray(0))

    // MARK: T2.1 the handshake, cases A to E of caps-412-protocol

    @Test
    fun a_serverWithoutNegotiationAnswersTheFirstGet() = runSuspend {
        val stub = StubEngine(counterPage())
        stub.negotiates = false
        val page = client(stub).fetchPage("home")
        assertEquals("home", page.pageId)
        assertEquals(listOf("GET"), stub.requests.map { it.method })
    }

    @Test
    fun b_c_unknownHashThenOneRetryWithTheVector() = runSuspend {
        val stub = StubEngine(counterPage())
        val c = client(stub)
        val page = c.fetchPage("home")
        assertEquals(16, page.components.size)

        val requests = stub.requests
        assertEquals(listOf("GET", "POST"), requests.map { it.method })
        assertEquals("http://localhost:8080/api/v1/app/counter/page/home", requests[0].url.toString())
        assertNull(requests[0].body)
        assertEquals(requests[0].url, requests[1].url)
        assertEquals(c.capsHash, requests[1].headers["x-orca-caps-hash"])
        assertEquals("application/json", requests[1].headers["Content-Type"])
        val body = json(requests[1].body)
        assertJsonEqual(body["_orcaCapsVector"], JsonValue.encoding(CapabilityVector.current))
        assertTrue(body["appState"].isNull)
        assertEquals(CapabilityVector.current, stub.cached(c.capsHash))
    }

    @Test
    fun d_knownHashTakesTheFastPath() = runSuspend {
        val stub = StubEngine(counterPage())
        val c = client(stub)
        c.fetchPage("home")
        c.fetchPage("home")
        assertEquals(listOf("GET", "POST", "GET"), stub.requests.map { it.method })
    }

    @Test
    fun e_aSecond412IsNeverRetried() = runSuspend {
        val stub = StubEngine(counterPage())
        stub.refuseVectors = true
        val error = assertFailsWith<OrcaClientException.Http>("a refused vector must surface as an error") {
            client(stub).fetchPage("home")
        }
        assertEquals(412, error.status)
        assertTrue(error.body.contains("caps_vector_unknown"))
        assertEquals(2, stub.requests.size)
    }

    @Test
    fun other412sPassThroughWithoutARetry() = runSuspend {
        val stub = StubEngine(counterPage())
        stub.forced = HttpResponse(412, body = """{"error":"precondition_failed"}""".encodeToByteArray())
        val error = assertFailsWith<OrcaClientException.Http>("expected an error") { client(stub).fetchPage("home") }
        assertEquals(412, error.status)
        assertEquals(1, stub.requests.size)
    }

    @Test
    fun appStateGoesInThePostBodyOfBothAttempts() = runSuspend {
        val stub = StubEngine(counterPage())
        client(stub).fetchPage("home", appState = props("user" to "amr"))
        val requests = stub.requests
        assertEquals(listOf("POST", "POST"), requests.map { it.method })
        assertJsonEqual(json(requests[0].body), obj("appState" to obj("user" to "amr")))
        val retry = json(requests[1].body)
        assertJsonEqual(retry["appState"], obj("user" to "amr"))
        assertFalse(retry["_orcaCapsVector"].isNull)
    }

    @Test
    fun serverErrorsCarryStatusAndBody() = runSuspend {
        val stub = StubEngine(ByteArray(0))
        stub.forced = HttpResponse(500, body = "boom".encodeToByteArray())
        val error = assertFailsWith<OrcaClientException>("expected an error") { client(stub).fetchPage("home") }
        assertEquals(OrcaClientException.Http(500, "boom"), error)
    }

    @Test
    fun pageUrlJoinsBaseAndPathWithOneSlash() {
        val c = OrcaClient(URI("http://h:1/"), "a", transport = StubEngine(ByteArray(0)))
        assertEquals("http://h:1/api/v1/app/a/page/shop/cart", c.pageUrl("/shop/cart").toString())
    }

    // MARK: T2.2 headers

    /**
     * The platform is `Android`, and the OS version an Android-style string
     * (Swift pins iOS's "Version 18.5 (Build 22F77)"); both go out as given.
     */
    @Test
    fun headersMatchTheFlutterClient() {
        val device = DeviceInfo(
            osVersion = "Android 15 (API 35)",
            screenWidth = 393.0, screenHeight = 852.0, pixelDensity = 3.0,
            safeTop = 59.0, safeBottom = 34.0, safeLeft = 0.0, safeRight = 0.0,
            locale = "en_US", timezone = "GMT+2",
        )
        val c = client(StubEngine(ByteArray(0)), device)
            .copy(apiKey = "demo-key", environment = "staging", deviceId = "device-1")
        assertEquals(
            mapOf(
                "x-orca-platform" to "Android",
                "x-orca-os-version" to "Android 15 (API 35)",
                "x-orca-screen-width" to "393",
                "x-orca-screen-height" to "852",
                "x-orca-pixel-density" to "3.0",
                "x-orca-safe-top" to "59",
                "x-orca-safe-bottom" to "34",
                "x-orca-safe-left" to "0",
                "x-orca-safe-right" to "0",
                "x-orca-locale" to "en_US",
                "x-orca-timezone" to "GMT+2",
                "x-orca-device-id" to "device-1",
                "Authorization" to "Bearer demo-key",
                "X-Orca-Env" to "staging",
                "x-orca-sdk-version" to GeneratedCapabilities.sdkSemver,
                "x-orca-caps-hash" to GeneratedCapabilities.capsHash,
            ),
            c.headers,
        )
    }

    @Test
    fun fractionalSizesRoundLikeDart() {
        val h = DeviceInfo(screenWidth = 390.5, pixelDensity = 2.625, safeTop = 47.33).headers
        assertEquals("391", h["x-orca-screen-width"])
        assertEquals("2.6", h["x-orca-pixel-density"])
        assertEquals("47", h["x-orca-safe-top"])
        assertNull(h["x-orca-screen-height"])
        assertEquals("Android", h["x-orca-platform"])
    }

    @Test
    fun emptyDeviceIdIsNotSent() {
        val c = client(StubEngine(ByteArray(0))).copy(deviceId = "")
        assertNull(c.headers["x-orca-device-id"])
        assertNull(c.headers["Authorization"])
    }
}
