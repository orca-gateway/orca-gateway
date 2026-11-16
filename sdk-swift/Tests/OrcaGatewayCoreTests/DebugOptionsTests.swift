import Foundation
import XCTest

@testable import OrcaGatewayCore

/// Answers every request with the same response.
private struct Canned: HTTPTransport {
    let response: HTTPResponse

    func send(_ request: HTTPRequest) async throws -> HTTPResponse { response }
}

/// C19.3 and C19.4: the debug options the core reads, Flutter's
/// `OrcaDebugConfig` (sdk/lib/src/debug/orca_debug.dart): the two capture
/// gates (ElmStore's state_change, OrcaClient's network) and the network
/// bodies (sdk/lib/src/client/orca_client.dart `includeBodies`).
final class DebugOptionsTests: XCTestCase {
    let recorder = EventRecorder()
    let base = URL(string: "http://localhost:8080")!

    override func setUp() {
        super.setUp()
        OrcaDebug.reporter = recorder
    }

    override func tearDown() {
        OrcaDebug.reporter = nil
        OrcaDebug.options = OrcaDebugOptions()
        super.tearDown()
    }

    func page() throws -> Data {
        try Fixtures.data("sdk-swift/Tests/Pages/counter-home.json")
    }

    func client(_ transport: HTTPTransport, apiKey: String? = nil) -> OrcaClient {
        OrcaClient(baseURL: base, appId: "counter", apiKey: apiKey, transport: transport)
    }

    // MARK: C19.4 the options and the two gates

    func testC19_4_TheOptionsHaveFluttersDefaultsAndAreSetAsOneValue() {
        let defaults = OrcaDebugOptions()
        XCTAssertTrue(defaults.captureStateChanges)
        XCTAssertTrue(defaults.captureNetworkRequests)
        XCTAssertFalse(defaults.includeBodies)
        XCTAssertFalse(defaults.logTimings)
        XCTAssertEqual(OrcaDebug.options, defaults)

        let all = OrcaDebugOptions(
            captureStateChanges: false, captureNetworkRequests: false, includeBodies: true, logTimings: true)
        OrcaDebug.options = all
        XCTAssertEqual(OrcaDebug.options, all)
        OrcaDebug.options = OrcaDebugOptions()
        XCTAssertEqual(OrcaDebug.options, defaults, "a stop resets them")
    }

    @MainActor func testC19_4_StateChangesOffStopsOnlyStateChanges() async throws {
        OrcaDebug.options = OrcaDebugOptions(captureStateChanges: false)
        let store = ElmStore(page: ["n": 0])
        store.pageId = "home"
        try await ActionExecutor(store: store).execute(.setState(.init(key: "n", value: 1)))
        store.dispatch(["cart": 2], scope: .app)
        let stub = StubEngine(page: try page())
        stub.negotiates = false
        _ = try await client(stub).fetchPage("home")

        XCTAssertEqual(store.state.page["n"], 1, "the state still changes")
        XCTAssertEqual(recorder.of("state_change"), [])
        XCTAssertEqual(recorder.of("action").map { $0.payload["actionType"] }, ["setState"])
        XCTAssertEqual(recorder.of("network").count, 1)

        OrcaDebug.options = OrcaDebugOptions()
        store.dispatch(["n": 2])
        XCTAssertEqual(recorder.of("state_change"), [
            .stateChange(scope: .page, pageId: "home", key: "n", oldValue: 1, newValue: 2),
        ])
    }

    @MainActor func testC19_4_NetworkOffStopsOnlyNetworkEvents() async throws {
        OrcaDebug.options = OrcaDebugOptions(captureNetworkRequests: false)
        let stub = StubEngine(page: try page())
        let engine = client(stub)
        _ = try await engine.fetchPage("home", appState: ["theme": "dark"])
        XCTAssertEqual(stub.requests.count, 2, "the handshake, then the page")
        stub.forced = HTTPResponse(status: 500, body: Data(#"{"error":"boom"}"#.utf8))
        do {
            _ = try await engine.fetchPage("home")
            XCTFail("a 500 throws")
        } catch {}
        do {
            _ = try await client(DownTransport()).fetchPage("home")
            XCTFail("a dead transport throws")
        } catch {}
        let store = ElmStore(page: ["n": 0])
        store.pageId = "home"
        try await ActionExecutor(store: store).execute(.setState(.init(key: "n", value: 1)))

        XCTAssertEqual(recorder.of("network"), [])
        let errors = recorder.of("error")
        XCTAssertEqual(errors.count, 2, "a failed request's error still goes, as Flutter's")
        XCTAssertEqual(errors.first?.payload["message"], "HTTP 500 /api/v1/app/counter/page/home")
        XCTAssertTrue(errors.last?.payload["message"]?.stringValue?.hasPrefix("Network request failed: ") ?? false)
        XCTAssertEqual(recorder.of("state_change").count, 1)
        XCTAssertEqual(recorder.of("action").count, 1)
    }

    // MARK: C19.3 the bodies

    func testC19_3_NoBodiesByDefault() async throws {
        let stub = StubEngine(page: try page())
        _ = try await client(stub).fetchPage("home", appState: ["theme": "dark"])
        stub.forced = HTTPResponse(status: 500, body: Data("boom".utf8))
        _ = try? await client(stub).fetchPage("home", appState: ["theme": "dark"])
        _ = try? await client(DownTransport()).fetchPage("home", appState: ["theme": "dark"])

        let events = recorder.of("network")
        XCTAssertEqual(events.map { $0.payload["statusCode"] }, [412, 200, 500, 0])
        for event in events {
            XCTAssertNil(event.payload["requestBody"])
            XCTAssertNil(event.payload["responseBody"])
        }
    }

    /// Flutter's page fetch of schema/fixtures/devtools/network-bodies.json:
    /// the app state it sent and the page it got back, the credential
    /// headers still redacted.
    func testC19_3_APageFetchCarriesTheFixturesBodies() async throws {
        OrcaDebug.options = OrcaDebugOptions(includeBodies: true)
        let fixture = try Fixtures.json("schema/fixtures/devtools/network-bodies.json")["payload"]
        let appState = try XCTUnwrap(fixture["requestBody"].objectValue)
        let transport = Canned(response: HTTPResponse(
            status: 200, headers: ["content-type": "application/json", "set-cookie": "session=1"],
            body: try fixture["responseBody"].encoded()))
        let page = try await client(transport, apiKey: "demo-key").fetchPage("home", appState: appState)
        XCTAssertEqual(page.pageId, "home")

        let events = recorder.of("network")
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        assertJSONEqual(event.payload["requestBody"] ?? .null, fixture["requestBody"], "requestBody")
        assertJSONEqual(event.payload["responseBody"] ?? .null, fixture["responseBody"], "responseBody")
        XCTAssertEqual(event.payload["method"], fixture["method"])
        XCTAssertEqual(event.payload["url"], fixture["url"])
        XCTAssertEqual(event.payload["statusCode"], fixture["statusCode"])
        XCTAssertEqual(event.payload["responseHeaders"], fixture["responseHeaders"])
        XCTAssertEqual(event.payload["requestHeaders"]?["Authorization"], "<redacted>")
    }

    func testC19_3_TheHandshakeShowsTheAppStateNotTheVector() async throws {
        OrcaDebug.options = OrcaDebugOptions(includeBodies: true)
        let stub = StubEngine(page: try page())
        _ = try await client(stub).fetchPage("home", appState: ["theme": "dark"])
        let events = recorder.of("network")
        XCTAssertEqual(events.map { $0.payload["statusCode"] }, [412, 200])
        XCTAssertEqual(events.map { $0.payload["requestBody"] }, [["theme": "dark"], ["theme": "dark"]])
        XCTAssertEqual(events[0].payload["responseBody"]?["error"], "caps_vector_unknown")
        XCTAssertEqual(events[1].payload["responseBody"], try JSONValue.decode(page()))
        let wire = try JSONValue.decode(try XCTUnwrap(stub.requests[1].body))
        XCTAssertNotNil(wire["_orcaCapsVector"].objectValue, "the wire body carries the vector")

        // No app state: a GET, then the vector alone; Flutter's appState is null.
        _ = try await client(StubEngine(page: try page())).fetchPage("home", appState: [:])
        let plain = Array(recorder.of("network").suffix(2))
        XCTAssertEqual(plain.map { $0.payload["statusCode"] }, [412, 200])
        XCTAssertEqual(plain.map { $0.payload["requestBody"] }, [nil, nil])
        XCTAssertEqual(plain[1].payload["responseBody"], try JSONValue.decode(page()))
    }

    func testC19_3_OtherRequestsShowTheirJSONBody() async throws {
        OrcaDebug.options = OrcaDebugOptions(includeBodies: true)
        let answer: JSONValue = ["actions": []]
        let actions = try await client(Canned(response: HTTPResponse(status: 200, body: try answer.encoded())))
            .executeAction("save", params: ["id": 7], appState: ["theme": "dark"])
        XCTAssertTrue(actions.isEmpty)
        let action = try XCTUnwrap(recorder.of("network").last)
        XCTAssertEqual(action.payload["requestBody"], [
            "action": "save", "params": ["id": 7], "appState": ["theme": "dark"],
        ])
        XCTAssertEqual(action.payload["responseBody"], answer)

        let config = try Fixtures.navigation()[0].json["config"]
        _ = try await client(Canned(response: HTTPResponse(status: 200, body: try config.encoded())))
            .fetchConfig()
        let get = try XCTUnwrap(recorder.of("network").last)
        XCTAssertNil(get.payload["requestBody"], "a GET has no body")
        XCTAssertEqual(get.payload["responseBody"], config)
    }

    func testC19_3_AnErrorResponseIsItsJSONElseItsText() async throws {
        OrcaDebug.options = OrcaDebugOptions(includeBodies: true)
        let stub = StubEngine(page: try page())
        stub.forced = HTTPResponse(status: 502, body: Data("Bad Gateway".utf8))
        do {
            _ = try await client(stub).fetchPage("home", appState: ["theme": "dark"])
            XCTFail("a 502 throws")
        } catch {}
        stub.forced = HTTPResponse(status: 500, body: Data(#"{"error":"boom"}"#.utf8))
        do {
            _ = try await client(stub).fetchPage("home")
            XCTFail("a 500 throws")
        } catch {}

        let events = recorder.of("network")
        XCTAssertEqual(events.map { $0.payload["responseBody"] }, ["Bad Gateway", ["error": "boom"]])
        XCTAssertEqual(events.map { $0.payload["requestBody"] }, [["theme": "dark"], nil])
        XCTAssertEqual(recorder.of("error").count, 2)
    }

    func testC19_3_ATransportFailureCarriesTheRequestBodyOnly() async throws {
        OrcaDebug.options = OrcaDebugOptions(includeBodies: true)
        do {
            _ = try await client(DownTransport()).fetchPage("home", appState: ["theme": "dark"])
            XCTFail("a dead transport throws")
        } catch {}
        let event = try XCTUnwrap(recorder.of("network").first)
        XCTAssertEqual(event.payload["statusCode"], 0)
        XCTAssertEqual(event.payload["requestBody"], ["theme": "dark"])
        XCTAssertNil(event.payload["responseBody"])
        XCTAssertEqual(recorder.of("error").count, 1)
    }
}
