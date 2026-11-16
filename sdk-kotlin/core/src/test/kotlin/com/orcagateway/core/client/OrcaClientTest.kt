package com.orcagateway.core.client

import com.orcagateway.core.capabilities.CapabilityVector
import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.encoding
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.DrawerItemDef
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.RedirectRule
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.core.models.TabDef
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
import kotlinx.serialization.SerializationException

/**
 * T2.1 (the capability handshake), T2.2 (headers), C16.3 (capability
 * extensions) and C1 (a live 4.0) on the Kotlin client.
 */
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

    // MARK: C16.3 capability extensions (Dart registerCapabilityExtensions)

    private val vector = CapabilityVector(
        protocolVersion = "2.0.0", sdkSemver = "1.0.0", widgets = listOf("Text", "Column"),
        valueKinds = listOf("static"), actionKinds = listOf("setState"), transformKinds = listOf("toString"),
        boolExprOps = listOf("eq"),
    )

    @Test
    fun c16_3_addingUnionsSortsAndDoublesBareActions() {
        val added = vector.adding(widgets = listOf("Map", "Text"), actions = listOf("moveCamera", "custom:rateApp", "setState"))
        assertEquals(listOf("Column", "Map", "Text"), added.widgets)
        assertEquals(
            listOf("custom:moveCamera", "custom:rateApp", "custom:setState", "moveCamera", "setState"),
            added.actionKinds,
        )
        assertEquals(vector.copy(widgets = added.widgets, actionKinds = added.actionKinds), added)
    }

    @Test
    fun c16_3_extensionsAddWidgetsVerbatimAndActionsBareAndPrefixed() {
        val c = client(StubEngine(ByteArray(0)))
        c.registerCapabilityExtensions(widgets = listOf("Map"), actions = listOf("moveCamera", "custom:rateApp"))
        val base = CapabilityVector.current
        assertEquals((base.widgets + "Map").sorted(), c.capabilities.widgets)
        assertEquals((base.actionKinds + listOf("moveCamera", "custom:moveCamera", "custom:rateApp")).sorted(), c.capabilities.actionKinds)
        assertFalse("custom:custom:rateApp" in c.capabilities.actionKinds)
        assertFalse("rateApp" in c.capabilities.actionKinds)
        assertEquals(base.valueKinds, c.capabilities.valueKinds)
    }

    @Test
    fun c16_3_extensionsChangeTheHashOnceAndAreIdempotent() {
        val c = client(StubEngine(ByteArray(0)))
        assertEquals(GeneratedCapabilities.capsHash, c.capsHash)
        assertEquals(CapabilityVector.current, c.capabilities)
        c.registerCapabilityExtensions()
        assertEquals(GeneratedCapabilities.capsHash, c.capsHash)

        c.registerCapabilityExtensions(widgets = listOf("Map"), actions = listOf("moveCamera"))
        val grown = c.capsHash
        assertTrue(grown != GeneratedCapabilities.capsHash)
        assertEquals(c.capabilities.hash, grown)
        assertEquals(grown, c.headers["x-orca-caps-hash"])

        c.registerCapabilityExtensions(widgets = listOf("Map"), actions = listOf("moveCamera", "custom:moveCamera"))
        assertEquals(grown, c.capsHash)
    }

    @Test
    fun c16_3_copiesShareTheExtensionsBothWays() {
        val c = client(StubEngine(ByteArray(0)))
        val early = c.copy(appId = "router")
        c.registerCapabilityExtensions(widgets = listOf("Map"))
        assertEquals(c.capsHash, early.capsHash)
        assertTrue("Map" in early.capabilities.widgets)

        early.registerCapabilityExtensions(actions = listOf("moveCamera"))
        assertTrue("custom:moveCamera" in c.capabilities.actionKinds)
        assertEquals(c.capsHash, early.capsHash)
    }

    /** `copy(capabilities = ...)` replaces the base; the shared extensions stay on top of it. */
    @Test
    fun c16_3_aCopyWithAnotherBaseKeepsTheExtensions() {
        val c = client(StubEngine(ByteArray(0)))
        c.registerCapabilityExtensions(widgets = listOf("Map"), actions = listOf("moveCamera"))
        val other = c.copy(capabilities = vector)
        assertEquals(vector.adding(listOf("Map"), listOf("moveCamera")), other.capabilities)
        assertEquals(other.capabilities.hash, other.capsHash)
        assertTrue("Map" in c.capabilities.widgets)
        assertTrue("AppBar" in c.capabilities.widgets)
    }

    @Test
    fun c16_3_aPageRequestAndItsRetryCarryTheExtendedVector(): Unit = runSuspend {
        val stub = StubEngine(counterPage())
        val c = client(stub)
        c.registerCapabilityExtensions(widgets = listOf("ColoredBadge"), actions = listOf("hapticFeedback"))
        c.fetchPage("home")

        val requests = stub.requests
        assertEquals(listOf("GET", "POST"), requests.map { it.method })
        assertTrue(c.capsHash != GeneratedCapabilities.capsHash)
        assertEquals(c.capsHash, requests[0].headers["x-orca-caps-hash"])
        assertEquals(c.capsHash, requests[1].headers["x-orca-caps-hash"])
        assertJsonEqual(json(requests[1].body)["_orcaCapsVector"], JsonValue.encoding(c.capabilities))
        assertEquals(c.capabilities, stub.cached(c.capsHash))
        assertTrue("custom:hapticFeedback" in c.capabilities.actionKinds)
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

    // MARK: B9.1-CK the navigation config

    /**
     * A /config body as the engine's `getNavConfig` serves it: keys the
     * client does not read (`appId`, `appName`, `requiredAppState`), a nested
     * route, a redirect, a transition, shell components and a static flow.
     */
    private val configBody = """
        {"appId":"shop","appName":"Shop","initialRoute":"/home",
         "tabs":[{"id":"home","label":"Home","icon":"home","initialRoute":"/home"},
                 {"id":"cart","label":"Cart","icon":"shopping_cart","initialRoute":"/cart"}],
         "drawerItems":[{"id":"settings","label":"Settings","icon":"settings","route":"/settings"},
                        {"id":"about","label":"About","route":"/about"}],
         "initialAppState":{"loggedIn":false,"ratio":4.0,"count":4},
         "tabBarComponents":[{"id":"bar","type":"Row","kind":"layout","childMode":"multi",
           "props":{},"children":[],"watches":[]}],
         "drawerComponents":[{"id":"drawer","type":"Column","kind":"layout","childMode":"multi",
           "props":{},"children":[],"watches":[]}],
         "flows":[
           {"name":"main","version":3,"routes":[
             {"path":"home","requiredAppState":[],"children":[
               {"path":"home/product/:id","requiredAppState":[],"isDynamic":true,
                "transition":{"type":"slide","duration":150,"curve":"linear"}}]},
             {"path":"cart","requiredAppState":["loggedIn"],
              "redirect":{"when":"loggedIn","equals":false,"to":"/login"},
              "transition":{"type":"fade"}}]},
           {"name":"onboarding","isStatic":true,"routes":[{"path":"welcome","requiredAppState":[]}],
            "pages":{"welcome":{"pageId":"welcome","title":"Welcome","state":[],"components":[
              {"id":"t","type":"Text","kind":"primitive","childMode":"none",
               "props":{"data":"Hi"},"children":[],"watches":[]}]}}}
         ]}
    """.trimIndent()

    private fun configStub(body: String = configBody): StubEngine =
        StubEngine(body.encodeToByteArray()).also { it.negotiates = false }

    @Test
    fun b9_1_ck_fetchConfigGetsTheConfigRouteWithTheDeviceHeaders() = runSuspend {
        val stub = configStub()
        val c = client(stub, DeviceInfo(osVersion = "Android 15 (API 35)", locale = "en_US"))
            .copy(apiKey = "demo-key", environment = "staging", deviceId = "device-1")
        c.fetchConfig()

        val request = stub.requests.single()
        assertEquals("GET", request.method)
        assertEquals("http://localhost:8080/api/v1/app/counter/config", request.url.toString())
        assertNull(request.body)
        assertEquals(c.headers, request.headers)
        assertEquals("Android", request.headers["x-orca-platform"])
        assertEquals("en_US", request.headers["x-orca-locale"])
        assertEquals("device-1", request.headers["x-orca-device-id"])
        assertEquals("Bearer demo-key", request.headers["Authorization"])
        assertEquals(c.capsHash, request.headers["x-orca-caps-hash"])
    }

    @Test
    fun b9_1_ck_fetchConfigDecodesTheBodyAndKeepsItRaw() = runSuspend {
        val config = client(configStub()).fetchConfig()

        assertEquals("/home", config.initialRoute)
        assertEquals(
            listOf(TabDef("home", "Home", "home", "/home"), TabDef("cart", "Cart", "shopping_cart", "/cart")),
            config.tabs,
        )
        assertEquals(
            listOf(
                DrawerItemDef("settings", "Settings", "settings", "/settings"),
                DrawerItemDef("about", "About", null, "/about"),
            ),
            config.drawerItems,
        )
        assertEquals(setOf("loggedIn", "ratio", "count"), config.initialAppState.keys)
        assertEquals(JsonValue.Bool(false), config.initialAppState["loggedIn"])
        assertIs<JsonValue.Double>(config.initialAppState["ratio"], "a 4.0 seed stays a double")
        assertIs<JsonValue.Int>(config.initialAppState["count"], "a 4 seed stays an int")
        assertEquals(listOf("bar"), config.tabBarComponents.map { it.id })
        assertEquals(listOf("drawer"), config.drawerComponents.map { it.id })

        assertEquals(listOf("main", "onboarding"), config.flows.map { it.name })
        val main = config.flows[0]
        assertEquals(3, main.version)
        assertFalse(main.isStatic)
        assertNull(main.pages)
        assertEquals(listOf("home", "cart"), main.routes.map { it.path })

        val home = main.routes[0]
        assertNull(home.redirect)
        assertNull(home.transition)
        assertFalse(home.isDynamic)
        val product = home.children.single()
        assertEquals("home/product/:id", product.path)
        assertTrue(product.isDynamic)
        assertTrue(product.children.isEmpty())
        assertEquals(RouteTransitionDef("slide", 150, "linear"), product.transition)

        val cart = main.routes[1]
        assertEquals(RedirectRule("loggedIn", JsonValue.Bool(false), "/login"), cart.redirect)
        assertEquals("loggedIn", cart.redirect?.`when`)
        assertEquals(RouteTransitionDef("fade", duration = 300, curve = "easeInOut"), cart.transition)
        assertEquals(RouteTransitionDef("fade"), cart.transition)

        val onboarding = config.flows[1]
        assertNull(onboarding.version)
        assertTrue(onboarding.isStatic)
        val welcome = onboarding.pages?.get("welcome")
        assertEquals("Welcome", welcome?.title)
        assertEquals(JsonValue.String("Hi"), welcome?.components?.single()?.props?.get("data"))

        assertEquals(configBody, config.rawBody)
        assertEquals(JsonValue.parse(configBody), config.raw)
        assertEquals(JsonValue.String("shop"), config.raw["appId"])
    }

    @Test
    fun b9_1_ck_aBareConfigTakesTheFlutterDefaults() = runSuspend {
        val config = client(configStub("""{"flows":[{"name":"main"}]}""")).fetchConfig()
        assertEquals("/", config.initialRoute)
        assertTrue(config.tabs.isEmpty())
        assertTrue(config.drawerItems.isEmpty())
        assertTrue(config.initialAppState.isEmpty())
        assertTrue(config.tabBarComponents.isEmpty())
        assertTrue(config.drawerComponents.isEmpty())
        assertTrue(config.flows.single().routes.isEmpty())
        assertTrue(NavConfig.fromJson(JsonValue.parse("{}")).flows.isEmpty())
        assertNull(NavConfig.fromJson(JsonValue.parse("{}")).rawBody)
    }

    @Test
    fun b9_1_ck_aMissingRequiredKeyIsADecodeError() = runSuspend {
        val body = """{"flows":[{"name":"main","routes":[{"requiredAppState":[]}]}]}"""
        val error = assertFailsWith<SerializationException> { client(configStub(body)).fetchConfig() }
        assertTrue(error.message.orEmpty().contains("path"), error.message)
        assertFailsWith<SerializationException> {
            NavConfig.fromJson(JsonValue.parse("""{"tabs":[{"id":"home","label":"Home","icon":"home"}]}"""))
        }
    }

    @Test
    fun b9_1_ck_fetchConfigThrowsOnA404AndA500LikeFetchPage() = runSuspend {
        for ((status, text) in listOf(404 to """{"error":"App not found"}""", 500 to "boom")) {
            val stub = configStub()
            stub.forced = HttpResponse(status, body = text.encodeToByteArray())
            val error = assertFailsWith<OrcaClientException>("expected an error") { client(stub).fetchConfig() }
            assertEquals(OrcaClientException.Http(status, text), error)
            assertEquals(1, stub.requests.size)
        }
    }

    @Test
    fun b9_1_ck_fetchConfigNeverStartsTheCapabilityHandshake() = runSuspend {
        val stub = StubEngine(configBody.encodeToByteArray())
        val error = assertFailsWith<OrcaClientException.Http> { client(stub).fetchConfig() }
        assertEquals(412, error.status)
        assertEquals(listOf("GET"), stub.requests.map { it.method })
    }

    // MARK: C18.5 the request timeout (Flutter's `timeout`, 30 s by default)

    private fun answer(body: String) = HttpResponse(200, body = body.encodeToByteArray())

    /** The page and its handshake retry, config, a server action, version and session all carry it. */
    @Test
    fun c18_5_everyRequestTheClientBuildsCarriesItsTimeout() = runSuspend {
        val stub = StubEngine(counterPage())
        val c = OrcaClient(base, "counter", transport = stub, timeoutMillis = 1_500)
        assertEquals(1_500L, c.timeoutMillis)
        c.fetchPage("home")
        stub.forced = answer("""{"flows":[]}""")
        c.fetchConfig()
        stub.forced = answer("""{"actions":[]}""")
        c.executeAction("bump")
        stub.forced = answer("""{"flows":{}}""")
        c.fetchVersion()
        c.sendSession("start", "d1")

        val requests = stub.requests
        assertEquals(
            listOf("page/home", "page/home", "config", "action", "version", "session"),
            requests.map { it.url.path.removePrefix("/api/v1/app/counter/") },
        )
        assertEquals(List(requests.size) { 1_500L }, requests.map { it.timeoutMillis })
    }

    @Test
    fun c18_5_theDefaultIsThirtySecondsAsInFlutter() = runSuspend {
        val stub = StubEngine(counterPage())
        val c = client(stub)
        assertEquals(30_000L, c.timeoutMillis)
        c.fetchPage("home")
        assertEquals(listOf(30_000L, 30_000L), stub.requests.map { it.timeoutMillis })
    }

    /** `identified` is a `copy(deviceId = ...)`: the copy keeps the timeout, and `copy` can change it. */
    @Test
    fun c18_5_copiesKeepTheTimeout() = runSuspend {
        val stub = StubEngine(counterPage())
        val c = OrcaClient(base, "counter", transport = stub, timeoutMillis = 1_500)
        val identified = c.copy(deviceId = "d1")
        assertEquals(1_500L, identified.timeoutMillis)
        assertEquals(1_500L, c.copy(appId = "router").copy(apiKey = "k").timeoutMillis)
        assertEquals(200L, c.copy(timeoutMillis = 200).timeoutMillis)
        assertEquals(1_500L, c.timeoutMillis)

        identified.fetchPage("home")
        assertEquals(listOf(1_500L, 1_500L), stub.requests.map { it.timeoutMillis })
    }

    /** The request keeps its timeout in equality and in its text. */
    @Test
    fun c18_5_aRequestComparesAndPrintsItsTimeout() {
        val url = URI("http://h/a")
        assertEquals(HttpRequest("GET", url, timeoutMillis = 100), HttpRequest("GET", url, timeoutMillis = 100))
        assertEquals(
            HttpRequest("GET", url, timeoutMillis = 100).hashCode(),
            HttpRequest("GET", url, timeoutMillis = 100).hashCode(),
        )
        assertFalse(HttpRequest("GET", url, timeoutMillis = 100) == HttpRequest("GET", url))
        assertNull(HttpRequest("GET", url).timeoutMillis)
        assertTrue("timeoutMillis=100" in HttpRequest("GET", url, timeoutMillis = 100).toString())
    }
}
