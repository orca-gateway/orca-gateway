import Foundation
import XCTest

@testable import OrcaGatewayCore

/// Collects what the SDK reports to DevTools.
final class EventRecorder: DevToolsReporter, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [DevToolsEvent] = []

    var events: [DevToolsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    func of(_ type: String) -> [DevToolsEvent] { events.filter { $0.type == type } }

    func report(_ event: DevToolsEvent) {
        lock.lock()
        _events.append(event)
        lock.unlock()
    }
}

/// A transport that never reaches a server.
struct DownTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        throw URLError(.cannotConnectToHost)
    }
}

/// T3.6: the Swift SDK builds every event in schema/fixtures/devtools exactly
/// as the Flutter SDK does (sdk/test/conformance/devtools_events_test.dart),
/// and each part of the SDK reports its events.
final class DevToolsEventTests: XCTestCase {
    let recorder = EventRecorder()

    override func tearDown() {
        OrcaDebug.reporter = nil
        super.tearDown()
    }

    // MARK: The fixtures

    func testSwiftBuildsEveryFixture() throws {
        let action = try Fixtures.json("schema/fixtures/devtools/action.json")["payload"]["data"].decode(Action.self)
        let built: [String: DevToolsEvent] = [
            "device_info": .deviceInfo(platform: "iOS", deviceModel: "iPhone17,1", appName: "Orca Counter"),
            "timing": .timing(
                pageId: "home", path: "home",
                server: [
                    "path": "/api/v1/app/counter/page/home", "method": "GET",
                    "stages": ["getInfo": 0.12, "getState": 0.05, "render": 0.41, "flatten": 0.2],
                    "componentCount": 16, "responseSizeBytes": 2048, "cacheStatus": "miss",
                    "totalMs": 1.5, "timestamp": 1_793_980_799_990,
                ],
                client: .init(responseReceivedMs: 12.5, parseCompleteMs: 13.25, renderStartMs: 13.5,
                              renderCompleteMs: 20.75, firstFrameMs: 21.5)),
            "state_change": .stateChange(scope: .page, pageId: "home", key: "count", oldValue: 0, newValue: 1),
            "action": .action(action, pageId: "home", durationMs: 0.75),
            "network": .network(
                method: "GET", url: "http://localhost:8080/api/v1/app/counter/page/home",
                statusCode: 200, durationMs: 12.5, responseSizeBytes: 2048,
                requestHeaders: DevToolsEvent.sanitize(["accept": "application/json", "x-api-key": "demo-key"]),
                responseHeaders: ["content-type": "application/json"], phases: [.init("wait", 12.5)]),
            "widget_rebuild": .widgetRebuild(
                widgetId: "5", widgetType: "Text", watches: ["count"],
                propTraces: ["data": [["op": "toString", "in": "1", "out": "1"]]]),
            "error": .error(
                message: "HTTP 500 /api/v1/app/counter/page/home", stackTrace: #"{"error":"boom"}"#,
                context: "GET http://localhost:8080/api/v1/app/counter/page/home"),
            "error-fallback-prompt": .fallbackPrompt("Checkbox"),
        ]
        let files = try Fixtures.files("devtools").map {
            (name: String($0.name.dropLast(".json".count)), json: $0.json)
        }
        XCTAssertEqual(Set(files.map(\.name)), Set(built.keys))
        for (name, fixture) in files {
            let event = try XCTUnwrap(built[name], name)
            // Through JSON text, as the WebSocket sends it.
            let sent = try JSONValue.decode(
                event.envelope(deviceId: "fixture-device", timestamp: 1_793_980_800_000).encoded())
            assertJSONEqual(sent, fixture, name)
        }
    }

    func testActionFamiliesFollowDart() {
        let expected: [String: String] = [
            "setState": "state", "navigate": "navigation", "goBack": "navigation",
            "showSnackbar": "ui-feedback", "share": "ui-feedback", "serverAction": "data",
            "actionGroup": "lifecycle", "conditionalAction": "data", "lifecycle": "lifecycle",
            "addComponent": "state", "replaceComponent": "state", "NAVIGATE_HOME": "navigation",
            "SET_THEME": "state", "SHOW_MODAL": "ui-feedback", "FETCH_CART": "data",
            "somethingElse": "custom",
        ]
        for (type, family) in expected {
            XCTAssertEqual(DevToolsEvent.family(of: type), family, type)
        }
    }

    func testHeadersAreRedacted() {
        XCTAssertEqual(DevToolsEvent.sanitize([
            "Authorization": "Bearer k", "Cookie": "a", "set-cookie": "b", "X-Api-Key": "k",
            "Proxy-Authorization": "p", "x-orca-caps-hash": "h",
        ]), [
            "Authorization": "<redacted>", "Cookie": "<redacted>", "set-cookie": "<redacted>",
            "X-Api-Key": "<redacted>", "Proxy-Authorization": "<redacted>", "x-orca-caps-hash": "h",
        ])
    }

    func testStateChangesDiffBothScopes() {
        let old = StoreState(page: ["a": 1, "b": 2], app: ["cart": 0])
        let new = StoreState(page: ["a": 1, "b": 3, "c": true], app: [:])
        XCTAssertEqual(DevToolsEvent.stateChanges(from: old, to: new, pageId: "p"), [
            .stateChange(scope: .page, pageId: "p", key: "b", oldValue: 2, newValue: 3),
            .stateChange(scope: .page, pageId: "p", key: "c", oldValue: .null, newValue: true),
            .stateChange(scope: .app, pageId: "p", key: "cart", oldValue: 0, newValue: .null),
        ])
    }

    // MARK: Who reports what

    func testNothingIsBuiltWithoutAReporter() {
        var built = false
        OrcaDebug.report({ built = true; return .error(message: "x") }())
        XCTAssertFalse(built)
        XCTAssertFalse(OrcaDebug.isEnabled)
    }

    func testTheStoreReportsChangedKeysOfItsPage() {
        OrcaDebug.reporter = recorder
        let anonymous = ElmStore(page: ["n": 0])
        anonymous.dispatch(["n": 1])
        XCTAssertEqual(recorder.events, [], "a store without a page reports nothing")

        let store = ElmStore(page: ["n": 0])
        store.pageId = "home"
        store.dispatch(["n": 1, "same": .null])
        store.dispatch(["cart": 2], scope: .app)
        XCTAssertEqual(recorder.events, [
            .stateChange(scope: .page, pageId: "home", key: "n", oldValue: 0, newValue: 1),
            .stateChange(scope: .app, pageId: "home", key: "cart", oldValue: .null, newValue: 2),
        ])
    }

    @MainActor func testTheExecutorReportsEveryActionRun() async throws {
        OrcaDebug.reporter = recorder
        let store = ElmStore(page: ["n": 0])
        store.pageId = "home"
        let executor = ActionExecutor(store: store)
        try await executor.execute(.actionGroup(.init(actions: [
            .setState(.init(key: "n", value: 1)), .showToast(.init(message: "hi")),
        ])))
        let actions = recorder.of("action")
        XCTAssertEqual(actions.map { $0.payload["actionType"] }, ["setState", "showToast", "actionGroup"],
                       "children finish first, as in Dart")
        XCTAssertEqual(actions.map { $0.payload["pageId"] }, ["home", "home", "home"])
        XCTAssertEqual(actions[0].payload["data"], ["type": "setState", "key": "n", "value": 1])
        XCTAssertNotNil(actions[2].payload["durationMs"]?.doubleValue)
        XCTAssertEqual(recorder.of("state_change").count, 1)
    }

    func testAFallbackPromptIsReportedOncePerType() throws {
        OrcaDebug.reporter = recorder
        let json: JSONValue = [
            "pageId": "p", "title": "P", "state": [],
            "components": [
                ["id": "0", "type": "Column", "kind": "layout", "childMode": "multi",
                 "props": [:], "children": ["1", "2"], "watches": []],
                ["id": "1", "type": "Checkbox", "kind": "input", "childMode": "none",
                 "props": [:], "children": [], "watches": []],
                ["id": "2", "type": "Checkbox", "kind": "input", "childMode": "none",
                 "props": [:], "children": [], "watches": []],
            ],
        ]
        let page = try json.decode(PageResponse.self)
        let renderer = PageRenderer(page: page, registry: WidgetRegistry())
        XCTAssertEqual(renderer.resolve("1", state: StoreState())?.type, "FallbackPrompt")
        XCTAssertEqual(renderer.resolve("2", state: StoreState())?.type, "FallbackPrompt")
        XCTAssertEqual(recorder.events, [.fallbackPrompt("Checkbox")])
    }

    func testTheClientReportsRequestsAndFailures() async throws {
        OrcaDebug.reporter = recorder
        let stub = StubEngine(page: try Fixtures.data("sdk-swift/Tests/Pages/counter-home.json"))
        let client = OrcaClient(baseURL: URL(string: "http://localhost:8080")!, appId: "counter",
                                apiKey: "demo-key", transport: stub)
        _ = try await client.fetchPage("home")
        let network = recorder.of("network")
        XCTAssertEqual(network.map { $0.payload["statusCode"] }, [412, 200], "the handshake, then the page")
        XCTAssertEqual(network[1].payload["requestHeaders"]?["Authorization"], "<redacted>")
        XCTAssertEqual(network[1].payload["phases"]?.arrayValue?.first?["phase"], "wait")
        XCTAssertEqual(recorder.of("error"), [], "the handshake's 412 is expected")

        stub.forced = HTTPResponse(status: 500, body: Data(#"{"error":"boom"}"#.utf8))
        do {
            _ = try await client.fetchPage("home")
            XCTFail("a 500 throws")
        } catch {}
        XCTAssertEqual(recorder.of("error").last, .error(
            message: "HTTP 500 /api/v1/app/counter/page/home", stackTrace: #"{"error":"boom"}"#,
            context: "GET http://localhost:8080/api/v1/app/counter/page/home"))

        let down = OrcaClient(baseURL: URL(string: "http://localhost:9")!, appId: "counter",
                              transport: DownTransport())
        do {
            _ = try await down.fetchPage("home")
            XCTFail("a dead transport throws")
        } catch {}
        XCTAssertEqual(recorder.of("network").last?.payload["statusCode"], 0)
        XCTAssertEqual(recorder.of("error").last?.payload["context"],
                       "GET http://localhost:9/api/v1/app/counter/page/home")
        XCTAssertTrue(recorder.of("error").last?.payload["message"]?.stringValue?
            .hasPrefix("Network request failed: ") ?? false)
    }

    func testATimedFetchReadsTheServerTiming() async throws {
        let header = #"{"path":"/x","method":"GET","stages":{"render":0.5},"componentCount":3,"responseSizeBytes":10,"cacheStatus":"hit","totalMs":1,"timestamp":1}"#
        struct Timed: HTTPTransport {
            let page: Data, header: String
            func send(_ request: HTTPRequest) async throws -> HTTPResponse {
                HTTPResponse(status: 200, headers: ["x-orca-timing": header], body: page)
            }
        }
        let client = OrcaClient(
            baseURL: URL(string: "http://localhost:8080")!, appId: "counter",
            transport: Timed(page: try Fixtures.data("sdk-swift/Tests/Pages/counter-home.json"), header: header))
        let (page, timing) = try await client.fetchPageTimed("home")
        XCTAssertEqual(timing.server?["cacheStatus"], "hit")
        XCTAssertLessThanOrEqual(timing.responseReceivedMs, timing.parseCompleteMs)
        let event = timing.event(pageId: page.pageId, path: "home", renderStartMs: 1, renderCompleteMs: 2,
                                 firstFrameMs: 3)
        XCTAssertEqual(event.payload["server"]?["componentCount"], 3)
        XCTAssertEqual(event.payload["client"]?["firstFrameMs"], 3)
        XCTAssertEqual(event.payload["client"]?["requestStartMs"], 0)
    }
}
