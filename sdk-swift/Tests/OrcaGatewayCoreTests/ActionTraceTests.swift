import Foundation
import XCTest

@testable import OrcaGatewayCore

/// C19.2 and C19.6: what a run action tells DevTools. A setState whose value
/// is a transform carries that value's trace, and the page's nodes watching
/// its key, as Flutter's setState handler does under OrcaDebug
/// (sdk/lib/src/state/action_executor.dart:165-207, 255-298); only the
/// setState's own event carries them. A debugLog reaches DevTools as its
/// generic action event and nothing else.
final class ActionTraceTests: XCTestCase {
    let recorder = EventRecorder()

    override func tearDown() {
        OrcaDebug.reporter = nil
        super.tearDown()
    }

    private static func node(_ id: String, _ type: String, watches: [String]) -> ComponentNode {
        ComponentNode(id: id, type: type, kind: .primitive, childMode: .none, watches: watches)
    }

    /// The fixture's page: Text 5 and Container 8 watch `count`; Text 3 and
    /// Text 9 watch other keys (a dotted path and a longer name are not
    /// `count`).
    private static let page: [ComponentNode] = [
        node("3", "Text", watches: ["theme"]),
        node("5", "Text", watches: ["count"]),
        node("8", "Container", watches: ["count", "theme"]),
        node("9", "Text", watches: ["count.total", "counter"]),
    ]

    private static func fixture() throws -> JSONValue {
        try Fixtures.json("schema/fixtures/devtools/action-traced.json")["payload"]
    }

    /// An executor on page `home` with `count` at 0 and the fixture's nodes.
    @MainActor
    private func executor(nodes: [ComponentNode]? = page) -> ActionExecutor {
        let store = ElmStore(page: ["count": 0])
        store.pageId = "home"
        let executor = ActionExecutor(store: store)
        if let nodes { executor.pageNodes = { nodes } }
        return executor
    }

    private func payloads(_ actionType: String) -> [[String: JSONValue]] {
        recorder.of("action").map(\.payload).filter { $0["actionType"] == .string(actionType) }
    }

    // MARK: C19.2

    /// The fixture's own action run at count 0 reports the fixture's payload,
    /// field for field (the duration aside, which is measured).
    @MainActor func testC19_2_theFixturesSetStateReportsItsTraceAndWatchers() async throws {
        let fixture = try Self.fixture()
        OrcaDebug.reporter = recorder
        let executor = executor()
        try await executor.execute(fixture["data"].decode(Action.self))

        XCTAssertEqual(executor.store.value("count"), 1)
        let events = recorder.of("action")
        XCTAssertEqual(events.count, 1)
        var payload = try XCTUnwrap(events.first?.payload)
        XCTAssertNotNil(payload["durationMs"]?.doubleValue)
        payload["durationMs"] = fixture["durationMs"]
        assertJSONEqual(.object(payload), fixture)
    }

    /// The trace reads the same state and event data the plain resolution
    /// does: an event input and the merged app state.
    @MainActor func testC19_2_theTraceReadsTheEventDataAndAppStateOfTheRun() async throws {
        OrcaDebug.reporter = recorder
        let executor = executor()
        executor.store.dispatch(["step": 10], scope: .app)
        let value: JSONValue = [
            "type": "transform", "input": ["type": "event", "key": "value"],
            "by": [["type": "add", "by": ["type": "state", "key": "step", "scope": "app"]]],
        ]
        try await executor.execute(.setState(.init(key: "count", value: value)), eventData: ["value": 4])

        XCTAssertEqual(executor.store.value("count"), 14)
        XCTAssertEqual(payloads("setState").first?["transformTrace"], [
            ["op": "event", "in": "value", "out": "4"], ["op": "input", "out": "4"],
            ["op": "state", "in": "step", "out": "10"], ["op": "add", "in": "4", "out": "14"],
        ])
    }

    /// A value that is not a transform (a state ref, a literal) has no
    /// trace; its watchers are still listed.
    @MainActor func testC19_2_aValueThatIsNotATransformListsTheWatchersOnly() async throws {
        OrcaDebug.reporter = recorder
        let executor = executor()
        executor.store.dispatch(["start": 7])
        try await executor.execute(.setState(.init(key: "count", value: ["type": "state", "key": "start"])))
        try await executor.execute(.setState(.init(key: "count", value: 3)))

        let watchers: JSONValue = [
            ["id": "5", "type": "Text", "watches": ["count"]],
            ["id": "8", "type": "Container", "watches": ["count", "theme"]],
        ]
        let sets = payloads("setState")
        XCTAssertEqual(sets.count, 2)
        for payload in sets {
            XCTAssertNil(payload["transformTrace"])
            XCTAssertEqual(payload["affectedWidgets"], watchers)
        }
        XCTAssertEqual(executor.store.value("count"), 3)
    }

    /// No node watching the key, or no hook at all: no `affectedWidgets` key.
    @MainActor func testC19_2_noWatcherOrNoHookLeavesAffectedWidgetsOut() async throws {
        let fixture = try Self.fixture()
        OrcaDebug.reporter = recorder
        let action = try fixture["data"].decode(Action.self)
        let unwatched = Action.setState(.init(key: "theme2", value: fixture["data"]["value"]))
        try await executor().execute(unwatched)
        try await executor(nodes: nil).execute(action)

        let sets = payloads("setState")
        XCTAssertEqual(sets.count, 2)
        for payload in sets {
            XCTAssertNil(payload["affectedWidgets"])
            XCTAssertEqual(payload["transformTrace"], fixture["transformTrace"])
        }
    }

    /// The watchers come in the page's order, as Flutter walks its node map
    /// in wire order: 8 sent before 5 is listed first.
    @MainActor func testC19_2_theWatchersKeepThePagesOrder() async throws {
        OrcaDebug.reporter = recorder
        let executor = executor(nodes: Self.page.reversed())
        try await executor.execute(.setState(.init(key: "count", value: 2)))
        XCTAssertEqual(payloads("setState").first?["affectedWidgets"], [
            ["id": "8", "type": "Container", "watches": ["count", "theme"]],
            ["id": "5", "type": "Text", "watches": ["count"]],
        ])
    }

    /// An enclosing action reports its own event without either field;
    /// only the setState's event carries them (Flutter clears both around
    /// every handler).
    @MainActor func testC19_2_onlyTheSetStatesOwnEventCarriesThem() async throws {
        let fixture = try Self.fixture()
        OrcaDebug.reporter = recorder
        let set = try fixture["data"].decode(Action.self)
        try await executor().execute(.actionGroup(.init(actions: [
            .conditionalAction(.init(branches: [], else: set)), .showToast(.init(message: "hi")),
        ])))

        let events = recorder.of("action").map(\.payload)
        XCTAssertEqual(events.map { $0["actionType"] }, ["setState", "conditionalAction", "showToast", "actionGroup"])
        XCTAssertEqual(events[0]["transformTrace"], fixture["transformTrace"])
        XCTAssertEqual(events[0]["affectedWidgets"], fixture["affectedWidgets"])
        for payload in events.dropFirst() {
            XCTAssertNil(payload["transformTrace"], "\(payload["actionType"] ?? .null)")
            XCTAssertNil(payload["affectedWidgets"], "\(payload["actionType"] ?? .null)")
        }
    }

    /// DevTools off: the hook is never asked and the value resolves as it
    /// always did.
    @MainActor func testC19_2_withDevToolsOffTheHookIsNeverAsked() async throws {
        let fixture = try Self.fixture()
        let executor = executor(nodes: nil)
        var asked = 0
        executor.pageNodes = {
            asked += 1
            return Self.page
        }
        try await executor.execute(fixture["data"].decode(Action.self))
        try await executor.execute(fixture["data"].decode(Action.self))
        XCTAssertEqual(executor.store.value("count"), 2)
        XCTAssertEqual(asked, 0)
        XCTAssertEqual(recorder.events, [])

        OrcaDebug.reporter = recorder
        try await executor.execute(fixture["data"].decode(Action.self))
        XCTAssertEqual(asked, 1, "asked once per setState while DevTools is on")
    }

    // MARK: C19.6

    /// A debugLog reaches DevTools as its generic `action` event (family
    /// custom, data the action as sent) and nothing else; its effect still
    /// goes to the page, which writes the platform log line.
    @MainActor func testC19_6_aDebugLogReachesDevToolsAsItsActionEventOnly() async throws {
        OrcaDebug.reporter = recorder
        let executor = executor()
        var effects: [ActionEffect] = []
        executor.onEffect = { effects.append($0) }
        let log = Action.debugLog(.init(level: "warn", message: ["type": "state", "key": "count"], tag: "cart"))
        try await executor.execute(log)

        XCTAssertEqual(recorder.events.map(\.type), ["action"])
        var payload = try XCTUnwrap(recorder.events.first?.payload)
        XCTAssertNotNil(payload.removeValue(forKey: "durationMs")?.doubleValue)
        XCTAssertEqual(payload, [
            "actionType": "debugLog", "family": "custom", "pageId": "home",
            "data": ["type": "debugLog", "level": "warn", "tag": "cart",
                     "message": ["type": "state", "key": "count"]],
        ])
        XCTAssertEqual(effects, [ActionEffect("debugLog", ["level": "warn", "tag": "cart", "message": "0"])])
    }
}
