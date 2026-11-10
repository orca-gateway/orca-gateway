package com.orcagateway.core.client

import com.orcagateway.core.capabilities.CapabilityVector
import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.encoding
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.resolver.ValueResolver
import com.orcagateway.core.support.ActionStub
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.StubEngine
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** T2.1 (the capability handshake), T2.2 (headers) and C1 (a live 4.0) on the Kotlin client. */
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

    // MARK: C1 a live 4.0 stays a double, as Dart's jsonDecode keeps it

    /**
     * A page as the engine sends it, written as raw text so `4.0` reaches the
     * client as typed: a double and an int state, a double and an int prop,
     * a static Value holding 4.0, and a Text whose `data` prints the double.
     */
    private val numbersPage = """
        {"pageId":"numbers","title":"Numbers",
         "state":[{"key":"ratio","scope":"page","initial":4.0},{"key":"count","scope":"page","initial":4}],
         "components":[{"id":"t","type":"Text","kind":"primitive","childMode":"none",
           "props":{"data":{"type":"transform","input":{"type":"state","key":"ratio"},"by":[{"type":"toString"}]},
                    "fontSize":4.0,"maxLines":4,"opacity":{"type":"static","value":4.0}},
           "children":[],"watches":["ratio"]}]}
    """.trimIndent()

    /** [value] through a `toString` transform, as a Text's `data` would print it. */
    private fun printed(value: JsonValue): String? = ValueResolver(state = mapOf("v" to value)).resolve(
        obj(
            "type" to "transform",
            "input" to obj("type" to "state", "key" to "v"),
            "by" to arr(obj("type" to "toString")),
        ),
    ).stringValue

    /** [value] is the double 4.0: printed "4.0" by `toString` and written "4.0" by `encoded()`. */
    private fun assertLiveDouble(value: JsonValue?, what: String) {
        assertEquals(4.0, assertIs<JsonValue.Double>(value, "$what stays a double").value)
        assertEquals("4.0", printed(value), "$what through toString")
        assertEquals("4.0", value.encoded(), "$what encoded")
    }

    /** [value] is the int 4: printed "4" and written "4". */
    private fun assertLiveInt(value: JsonValue?, what: String) {
        assertEquals(4L, assertIs<JsonValue.Int>(value, "$what stays an int").value)
        assertEquals("4", printed(value), "$what through toString")
        assertEquals("4", value.encoded(), "$what encoded")
    }

    /** The doubles and ints of [numbersPage], wherever the page came from. */
    private fun assertNumbersKept(page: PageResponse) {
        val initial = page.state.associate { it.key to it.initial }
        assertLiveDouble(initial["ratio"], "state initial 4.0")
        assertLiveInt(initial["count"], "state initial 4")
        val props = page.components.single().props
        assertLiveDouble(props["fontSize"], "prop 4.0")
        assertLiveInt(props["maxLines"], "prop 4")
        val resolver = ValueResolver(state = initial)
        assertLiveDouble(resolver.resolve(props.getValue("opacity")), "static Value 4.0")
        assertEquals(JsonValue.String("4.0"), resolver.resolveDeep(props.getValue("data")), "Text data of state 4.0")
        assertTrue(JsonValue.encoding(page).encoded().contains("\"initial\":4.0"), "page written back keeps 4.0")
    }

    @Test
    fun c1_aFetchedPageKeepsALive4_0ADouble() = runSuspend {
        val page = client(StubEngine(numbersPage.encodeToByteArray())).fetchPage("numbers")
        assertNumbersKept(page)
    }

    @Test
    fun c1_theUpgradePageOfA426KeepsALive4_0ADouble() = runSuspend {
        val stub = StubEngine(ByteArray(0))
        val body = """
            {"error":"sdk_version_too_old","minSdkVersion":"99.0.0","clientSdkVersion":"0.1.0",
             "page":$numbersPage}
        """.trimIndent()
        stub.forced = HttpResponse(426, body = body.encodeToByteArray())
        val page = client(stub).fetchPage("numbers")
        assertNumbersKept(page)
    }

    @Test
    fun c1_aServerActionResponseKeepsALive4_0ADouble() = runSuspend {
        val body = """
            {"actions":[
              {"type":"setState","key":"ratio","value":4.0},
              {"type":"setState","key":"count","value":4},
              {"type":"updateComponent","id":"t","props":{"fontSize":4.0}},
              {"type":"addComponent","parentId":"root","components":[{"id":"n","type":"Text","kind":"primitive",
                "childMode":"none","props":{"fontSize":4.0,"maxLines":4},"children":[],"watches":[]}]}
            ]}
        """.trimIndent()
        val stub = ActionStub(emptyMap(), raw = mapOf("bump" to HttpResponse(200, body = body.encodeToByteArray())))
        val actions = ActionStub.client(stub).executeAction("bump")

        assertLiveDouble(assertIs<Action.SetState>(actions[0]).value, "setState value 4.0")
        assertLiveInt(assertIs<Action.SetState>(actions[1]).value, "setState value 4")
        val updated = assertIs<Action.UpdateComponent>(actions[2]).props
        assertLiveDouble(updated?.get("fontSize"), "updateComponent prop 4.0")
        val added = assertIs<Action.AddComponent>(actions[3]).components?.arrayValue.orEmpty()
            .map { it.decode(ComponentNode.serializer()) }
        assertLiveDouble(added.single().props["fontSize"], "added component prop 4.0")
        assertLiveInt(added.single().props["maxLines"], "added component prop 4")
    }
}
