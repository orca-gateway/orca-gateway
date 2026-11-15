import Foundation
import XCTest

@testable import OrcaGatewayCore

/// A stand-in for the engine's page route with its capability-vector cache,
/// following engine/test/caps-412-protocol.test.ts: a known hash answers 200;
/// an unknown hash answers 412 caps_vector_unknown unless the body carries a
/// vector that hashes to it, which is then cached.
final class StubEngine: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: CapabilityVector] = [:]
    private var _requests: [HTTPRequest] = []
    /// When false the stub behaves like an engine without negotiation.
    var negotiates = true
    /// Refuse every vector (the engine's case E: hash and vector disagree).
    var refuseVectors = false
    /// Answer every request with this instead (a non-caps 412, a 500).
    var forced: HTTPResponse?
    let page: Data

    init(page: Data) { self.page = page }

    /// NSLock.withLock is missing from older Linux Foundation releases.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var requests: [HTTPRequest] { locked { _requests } }
    func cached(_ hash: String) -> CapabilityVector? { locked { cache[hash] } }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        locked {
            _requests.append(request)
            if let forced { return forced }
            guard negotiates, let hash = request.headers["x-orca-caps-hash"] else {
                return HTTPResponse(status: 200, body: page)
            }
            if cache[hash] != nil { return HTTPResponse(status: 200, body: page) }
            if let body = request.body, let json = try? JSONValue.decode(body),
                case .object = json["_orcaCapsVector"],
                let vector = try? json["_orcaCapsVector"].decode(CapabilityVector.self),
                !refuseVectors, vector.hash == hash
            {
                cache[hash] = vector
                return HTTPResponse(status: 200, body: page)
            }
            return HTTPResponse(
                status: 412,
                body: Data(#"{"error":"caps_vector_unknown","hash":"\#(hash)"}"#.utf8))
        }
    }
}

/// A JSON value is this double, not an int that equals it (C1: a live 4.0).
func assertDouble(_ v: JSONValue?, _ expected: Double, file: StaticString = #filePath, line: UInt = #line) {
    guard case .double(let d)? = v, d == expected else {
        return XCTFail("\(String(describing: v)) is not .double(\(expected))", file: file, line: line)
    }
}

/// A JSON value is this int, not a double that equals it.
func assertInt(_ v: JSONValue?, _ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
    guard case .int(let i)? = v, i == expected else {
        return XCTFail("\(String(describing: v)) is not .int(\(expected))", file: file, line: line)
    }
}

final class OrcaClientTests: XCTestCase {
    let base = URL(string: "http://localhost:8080")!

    func counterPage() throws -> Data {
        try Fixtures.data("sdk-swift/Tests/Pages/counter-home.json")
    }

    func client(_ stub: StubEngine, device: DeviceInfo = DeviceInfo()) -> OrcaClient {
        OrcaClient(baseURL: base, appId: "counter", device: device, transport: stub)
    }

    // MARK: T2.1 the handshake, cases A to E of caps-412-protocol

    func testA_ServerWithoutNegotiationAnswersTheFirstGet() async throws {
        let stub = StubEngine(page: try counterPage())
        stub.negotiates = false
        let page = try await client(stub).fetchPage("home")
        XCTAssertEqual(page.pageId, "home")
        XCTAssertEqual(stub.requests.map(\.method), ["GET"])
    }

    func testB_C_UnknownHashThenOneRetryWithTheVector() async throws {
        let stub = StubEngine(page: try counterPage())
        let c = client(stub)
        let page = try await c.fetchPage("home")
        XCTAssertEqual(page.components.count, 16)

        let requests = stub.requests
        XCTAssertEqual(requests.map(\.method), ["GET", "POST"])
        XCTAssertEqual(requests[0].url.absoluteString, "http://localhost:8080/api/v1/app/counter/page/home")
        XCTAssertNil(requests[0].body)
        XCTAssertEqual(requests[1].url, requests[0].url)
        XCTAssertEqual(requests[1].headers["x-orca-caps-hash"], c.capsHash)
        XCTAssertEqual(requests[1].headers["Content-Type"], "application/json")
        let body = try JSONValue.decode(requests[1].body ?? Data())
        assertJSONEqual(body["_orcaCapsVector"], try JSONValue(encoding: CapabilityVector.current))
        XCTAssertTrue(body["appState"].isNull)
        XCTAssertEqual(stub.cached(c.capsHash), .current)
    }

    func testD_KnownHashTakesTheFastPath() async throws {
        let stub = StubEngine(page: try counterPage())
        let c = client(stub)
        _ = try await c.fetchPage("home")
        _ = try await c.fetchPage("home")
        XCTAssertEqual(stub.requests.map(\.method), ["GET", "POST", "GET"])
    }

    func testE_ASecond412IsNeverRetried() async throws {
        let stub = StubEngine(page: try counterPage())
        stub.refuseVectors = true
        do {
            _ = try await client(stub).fetchPage("home")
            XCTFail("a refused vector must surface as an error")
        } catch OrcaClientError.http(let status, let body) {
            XCTAssertEqual(status, 412)
            XCTAssertTrue(body.contains("caps_vector_unknown"))
        }
        XCTAssertEqual(stub.requests.count, 2)
    }

    func testOther412sPassThroughWithoutARetry() async throws {
        let stub = StubEngine(page: try counterPage())
        stub.forced = HTTPResponse(status: 412, body: Data(#"{"error":"precondition_failed"}"#.utf8))
        do {
            _ = try await client(stub).fetchPage("home")
            XCTFail("expected an error")
        } catch OrcaClientError.http(let status, _) {
            XCTAssertEqual(status, 412)
        }
        XCTAssertEqual(stub.requests.count, 1)
    }

    func testAppStateGoesInThePostBodyOfBothAttempts() async throws {
        let stub = StubEngine(page: try counterPage())
        _ = try await client(stub).fetchPage("home", appState: ["user": "amr"])
        let requests = stub.requests
        XCTAssertEqual(requests.map(\.method), ["POST", "POST"])
        assertJSONEqual(try JSONValue.decode(requests[0].body ?? Data()), ["appState": ["user": "amr"]])
        let retry = try JSONValue.decode(requests[1].body ?? Data())
        assertJSONEqual(retry["appState"], ["user": "amr"])
        XCTAssertFalse(retry["_orcaCapsVector"].isNull)
    }

    func testServerErrorsCarryStatusAndBody() async throws {
        let stub = StubEngine(page: Data())
        stub.forced = HTTPResponse(status: 500, body: Data("boom".utf8))
        do {
            _ = try await client(stub).fetchPage("home")
            XCTFail("expected an error")
        } catch let error as OrcaClientError {
            XCTAssertEqual(error, .http(status: 500, body: "boom"))
        }
    }

    func testPageURLJoinsBaseAndPathWithOneSlash() throws {
        let c = OrcaClient(
            baseURL: URL(string: "http://h:1/")!, appId: "a", transport: StubEngine(page: Data()))
        XCTAssertEqual(try c.pageURL("/shop/cart").absoluteString, "http://h:1/api/v1/app/a/page/shop/cart")
    }

    // MARK: B9.1-CS /config is requested with the device headers and decoded

    /// A `/config` body as `App.getNavConfig` serves it: unknown members
    /// (`appId`, `appName`, `requiredAppState`), route paths without a leading
    /// slash, a child with its full path, a static flow with its pages.
    static let configBody = #"""
        {"appId": "shop", "appName": "Shop", "initialRoute": "/home",
         "tabs": [{"id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"},
                  {"id": "cart", "label": "Cart", "icon": "cart", "initialRoute": "/cart"}],
         "drawerItems": [{"id": "settings", "label": "Settings", "icon": "gear", "route": "/settings"},
                         {"id": "about", "label": "About", "route": "/about"}],
         "initialAppState": {"loggedIn": false, "ratio": 4.0, "user": {"name": "amr"}},
         "tabBarComponents": [{"id": "bar", "type": "Text", "kind": "primitive", "childMode": "none",
                               "props": {"data": "bar"}, "children": [], "watches": []}],
         "drawerComponents": [{"id": "drw", "type": "Text", "kind": "primitive", "childMode": "none",
                               "props": {"data": "drawer"}, "children": [], "watches": []}],
         "flows": [
           {"name": "main", "routes": [
              {"path": "home", "requiredAppState": [], "children": [
                 {"path": "home/product/:id", "requiredAppState": [], "isDynamic": true,
                  "transition": {"type": "slide", "duration": 150, "curve": "linear"}}]},
              {"path": "cart", "requiredAppState": ["loggedIn"],
               "redirect": {"when": "loggedIn", "equals": false, "to": "/login"},
               "transition": {"type": "fade"}},
              {"path": "login", "requiredAppState": []}]},
           {"name": "onboarding", "version": 3, "isStatic": true,
            "routes": [{"path": "welcome", "requiredAppState": []}],
            "pages": {"welcome": {"pageId": "welcome", "title": "Welcome", "state": [], "components": [
              {"id": "t", "type": "Text", "kind": "primitive", "childMode": "none",
               "props": {"data": "Hi"}, "children": [], "watches": []}]}}}]}
        """#

    func testB9_1_CS_FetchConfigRequestsConfigWithTheDeviceHeadersAndDecodesIt() async throws {
        // The stub's page route would answer an unknown hash with 412: the
        // config route has no handshake, so it is one plain GET.
        let stub = StubEngine(page: Data(Self.configBody.utf8))
        stub.negotiates = false
        var c = client(stub, device: DeviceInfo(screenWidth: 393, locale: "en_US"))
        c.apiKey = "demo-key"
        c.deviceId = "device-1"
        let config = try await c.fetchConfig()

        let requests = stub.requests
        XCTAssertEqual(requests.map(\.method), ["GET"])
        XCTAssertEqual(requests[0].url.absoluteString, "http://localhost:8080/api/v1/app/counter/config")
        XCTAssertNil(requests[0].body)
        XCTAssertEqual(requests[0].headers, c.headers)
        XCTAssertEqual(requests[0].headers["x-orca-platform"], "iOS")
        XCTAssertEqual(requests[0].headers["x-orca-screen-width"], "393")
        XCTAssertEqual(requests[0].headers["x-orca-locale"], "en_US")
        XCTAssertEqual(requests[0].headers["x-orca-device-id"], "device-1")
        XCTAssertEqual(requests[0].headers["Authorization"], "Bearer demo-key")
        XCTAssertEqual(requests[0].headers["x-orca-caps-hash"], c.capsHash)

        XCTAssertEqual(config.initialRoute, "/home")
        XCTAssertEqual(config.tabs, [
            TabDef(id: "home", label: "Home", icon: "home", initialRoute: "/home"),
            TabDef(id: "cart", label: "Cart", icon: "cart", initialRoute: "/cart"),
        ])
        XCTAssertEqual(config.drawerItems, [
            DrawerItemDef(id: "settings", label: "Settings", icon: "gear", route: "/settings"),
            DrawerItemDef(id: "about", label: "About", icon: nil, route: "/about"),
        ])
        XCTAssertEqual(config.initialAppState["loggedIn"], .bool(false))
        assertDouble(config.initialAppState["ratio"], 4.0)
        XCTAssertEqual(config.initialAppState["user"]?["name"], "amr")
        XCTAssertEqual(config.tabBarComponents.map(\.id), ["bar"])
        XCTAssertEqual(config.drawerComponents.map(\.id), ["drw"])

        XCTAssertEqual(config.flows.map(\.name), ["main", "onboarding"])
        let main = config.flows[0]
        XCTAssertNil(main.version)
        XCTAssertFalse(main.isStatic)
        XCTAssertNil(main.pages)
        XCTAssertEqual(main.routes.map(\.path), ["home", "cart", "login"])
        XCTAssertEqual(main.routes[0].children, [
            NavRoute(path: "home/product/:id",
                     transition: RouteTransitionDef(type: "slide", duration: 150, curve: "linear"),
                     isDynamic: true)
        ])
        XCTAssertNil(main.routes[0].redirect)
        XCTAssertNil(main.routes[0].transition)
        XCTAssertFalse(main.routes[0].isDynamic)
        XCTAssertEqual(main.routes[1].redirect, RedirectRule(when: "loggedIn", equals: .bool(false), to: "/login"))
        XCTAssertEqual(main.routes[1].transition, RouteTransitionDef(type: "fade", duration: 300, curve: "easeInOut"))

        let onboarding = config.flows[1]
        XCTAssertEqual(onboarding.version, 3)
        XCTAssertTrue(onboarding.isStatic)
        XCTAssertEqual(onboarding.routes.map(\.path), ["welcome"])
        XCTAssertEqual(onboarding.pages?.keys.sorted(), ["welcome"])
        XCTAssertEqual(onboarding.pages?["welcome"]?.title, "Welcome")
        XCTAssertEqual(onboarding.pages?["welcome"]?.components.map(\.id), ["t"])

        XCTAssertEqual(config.rawBody, Self.configBody)
        XCTAssertEqual(config.raw["appName"], "Shop")
        assertJSONEqual(config.raw, try JSONValue.decode(Data(Self.configBody.utf8)))
    }

    func testB9_1_CS_FetchConfigThrowsOnA404AndA500LikeFetchPage() async throws {
        for (status, text) in [(404, #"{"error":"App not found"}"#), (500, "boom")] {
            let stub = StubEngine(page: Data())
            stub.forced = HTTPResponse(status: status, body: Data(text.utf8))
            do {
                _ = try await client(stub).fetchConfig()
                XCTFail("expected an error for \(status)")
            } catch let error as OrcaClientError {
                XCTAssertEqual(error, .http(status: status, body: text))
            }
            XCTAssertEqual(stub.requests.count, 1)
        }
    }

    // MARK: T2.2 headers

    func testHeadersMatchTheFlutterClient() throws {
        let device = DeviceInfo(
            osVersion: "Version 18.5 (Build 22F77)",
            screenWidth: 393, screenHeight: 852, pixelDensity: 3,
            safeTop: 59, safeBottom: 34, safeLeft: 0, safeRight: 0,
            locale: "en_US", timezone: "GMT+2")
        var c = client(StubEngine(page: Data()), device: device)
        c.apiKey = "demo-key"
        c.environment = "staging"
        c.deviceId = "device-1"
        XCTAssertEqual(c.headers, [
            "x-orca-platform": "iOS",
            "x-orca-os-version": "Version 18.5 (Build 22F77)",
            "x-orca-screen-width": "393",
            "x-orca-screen-height": "852",
            "x-orca-pixel-density": "3.0",
            "x-orca-safe-top": "59",
            "x-orca-safe-bottom": "34",
            "x-orca-safe-left": "0",
            "x-orca-safe-right": "0",
            "x-orca-locale": "en_US",
            "x-orca-timezone": "GMT+2",
            "x-orca-device-id": "device-1",
            "Authorization": "Bearer demo-key",
            "X-Orca-Env": "staging",
            "x-orca-sdk-version": GeneratedCapabilities.sdkSemver,
            "x-orca-caps-hash": GeneratedCapabilities.capsHash,
        ])
    }

    func testFractionalSizesRoundLikeDart() {
        let h = DeviceInfo(screenWidth: 390.5, pixelDensity: 2.625, safeTop: 47.33).headers
        XCTAssertEqual(h["x-orca-screen-width"], "391")
        XCTAssertEqual(h["x-orca-pixel-density"], "2.6")
        XCTAssertEqual(h["x-orca-safe-top"], "47")
        XCTAssertNil(h["x-orca-screen-height"])
        XCTAssertEqual(h["x-orca-platform"], "iOS")
    }

    func testEmptyDeviceIdIsNotSent() {
        var c = client(StubEngine(page: Data()))
        c.deviceId = ""
        XCTAssertNil(c.headers["x-orca-device-id"])
        XCTAssertNil(c.headers["Authorization"])
    }

    // MARK: C1 a live 4.0 stays a double, as Dart's jsonDecode keeps it

    /// Served as raw text, so `4.0` reaches the client as the engine wrote it
    /// (`encoded()` would write `4`).
    static let doublePage = #"""
        {"pageId": "p", "title": "T",
         "state": [{"key": "d", "scope": "page", "initial": 4.0}, {"key": "i", "scope": "page", "initial": 4}],
         "components": [{"id": "t", "type": "Text", "kind": "primitive", "childMode": "none",
           "props": {"data": {"type": "transform", "input": {"type": "state", "key": "d"}, "by": [{"type": "toString"}]},
                     "size": 4.0, "count": 4, "style": {"fontSize": 4.0}},
           "children": [], "watches": ["d"]}]}
        """#

    static func toString(_ key: String) -> JSONValue {
        ["type": "transform", "input": ["type": "state", "key": .string(key)], "by": [["type": "toString"]]]
    }

    func initialState(_ page: PageResponse) -> [String: JSONValue] {
        Dictionary(page.state.map { ($0.key, $0.initial) }, uniquingKeysWith: { _, last in last })
    }

    func testC1_AFetchedPageKeepsADoubleInitialValue() async throws {
        let page = try await client(StubEngine(page: Data(Self.doublePage.utf8))).fetchPage("p")
        XCTAssertEqual(page.state.map(\.key), ["d", "i"])
        assertDouble(page.state.first?.initial, 4.0)
        assertInt(page.state.last?.initial, 4)
        let r = ValueResolver(state: initialState(page))
        XCTAssertEqual(r.resolve(Self.toString("d")).stringValue, "4.0")
        XCTAssertEqual(r.resolve(Self.toString("i")).stringValue, "4")
    }

    func testC1_AFetchedPageKeepsADoubleProp() async throws {
        let page = try await client(StubEngine(page: Data(Self.doublePage.utf8))).fetchPage("p")
        let props = try XCTUnwrap(page.components.first?.props)
        assertDouble(props["size"], 4.0)
        assertDouble(props["style"]?["fontSize"], 4.0)
        assertInt(props["count"], 4)
        XCTAssertEqual(ValueResolver(state: initialState(page)).resolveToString(props["data"] ?? .null), "4.0")
    }

    func testC1_The426PageKeepsADouble() async throws {
        let stub = StubEngine(page: Data())
        stub.forced = HTTPResponse(status: 426, body: Data(#"""
            {"error": "sdk_version_too_old", "minSdkVersion": "99.0.0", "clientSdkVersion": "0.1.0",
             "page": \#(Self.doublePage)}
            """#.utf8))
        let page = try await client(stub).fetchPage("p")
        assertDouble(page.state.first?.initial, 4.0)
        assertInt(page.state.last?.initial, 4)
        assertDouble(page.components.first?.props["size"], 4.0)
        XCTAssertEqual(ValueResolver(state: initialState(page)).resolve(Self.toString("d")).stringValue, "4.0")
    }

    func testC1_AServerActionResponseKeepsADoubleSetStateValue() async throws {
        let body = #"""
            {"actions": [{"type": "setState", "key": "d", "value": 4.0},
                         {"type": "setState", "key": "i", "value": 4},
                         {"type": "updateComponent", "id": "t", "props": {"size": 4.0}}]}
            """#
        let stub = ActionStub([:], raw: ["save": HTTPResponse(status: 200, body: Data(body.utf8))])
        let actions = try await ActionStub.client(stub).executeAction("save")
        guard actions.count == 3, case .setState(let d) = actions[0], case .setState(let i) = actions[1],
            case .updateComponent(let u) = actions[2]
        else { return XCTFail("setState, setState, updateComponent expected, got \(actions)") }
        assertDouble(d.value, 4.0)
        assertInt(i.value, 4)
        assertDouble(u.props?["size"], 4.0)
        let r = ValueResolver(state: ["d": d.value, "i": i.value])
        XCTAssertEqual(r.resolve(Self.toString("d")).stringValue, "4.0")
        XCTAssertEqual(r.resolve(Self.toString("i")).stringValue, "4")
    }
}
