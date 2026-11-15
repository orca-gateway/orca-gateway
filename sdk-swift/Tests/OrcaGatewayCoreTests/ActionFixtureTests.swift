import Foundation
import XCTest

@testable import OrcaGatewayCore

/// T3.1: schema/fixtures/actions through the Swift executor, as the Flutter
/// runner (sdk/test/conformance/action_fixtures_test.dart) runs them through
/// the Dart executor. Each run seeds the state, runs the actions, and compares
/// the state and the effects as JSON. A fixture with `serverResponses` talks
/// to a stub of the `/action` route, as the Dart runner's stub client does.
final class ActionFixtureTests: XCTestCase {
    @MainActor func testAllSeventeenActionFixturesPass() async throws {
        let files = try Fixtures.files("actions")
        XCTAssertEqual(files.count, 17)
        for (name, fx) in files {
            let actions = try (fx["actions"].arrayValue ?? []).map { try $0.decode(Action.self) }
            XCTAssertTrue(actions.allSatisfy(ActionExecutor.implements), "\(name): every kind implemented")

            let store = ElmStore(try fx["state"].decode(StoreState.self))
            var client: OrcaClient?
            if case .object(let responses) = fx["serverResponses"] {
                client = ActionStub.client(ActionStub(responses))
            }
            let executor = ActionExecutor(store: store, client: client)
            var effects: [ActionEffect] = []
            executor.onEffect = { effects.append($0) }

            for action in actions {
                try await executor.execute(action, eventData: fx["event"].objectValue)
            }
            assertJSONEqual(try jsonOf(store.state), fx["expected"]["state"], "\(name): state")
            assertJSONEqual(.array(effects.map(\.json)), fx["expected"]["effects"], "\(name): effects")
        }
    }

    @MainActor func testUnimplementedKindsChangeNothing() async throws {
        let state = StoreState(page: ["count": 1])
        let (next, effects) = ActionReducer().reduce(state, .animateForward(.init(animationId: "a")))
        XCTAssertEqual(next, state)
        XCTAssertEqual(effects, [])

        let store = ElmStore(state)
        let executor = ActionExecutor(store: store)
        var seen: [ActionEffect] = []
        executor.onEffect = { seen.append($0) }
        try await executor.execute(.animateForward(.init(animationId: "a")))
        try await executor.execute(.closeDialog)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(seen, [])
        XCTAssertFalse(ActionExecutor.implements(.actionGroup(.init(actions: [.goBack, .animateForward(.init(animationId: "a"))]))))
        XCTAssertTrue(ActionExecutor.implements(.actionGroup(.init(actions: [.goBack, .setState(.init(key: "a", value: 1))]))))
    }

    /// B10.3-A, B10.5-A: the two shell effects go out as data, then to the
    /// platform, and leave the state alone.
    @MainActor func testSwitchTabAndOpenDrawerEmitThenPerform() async throws {
        let state = StoreState(page: ["count": 1])
        let store = ElmStore(state)
        let executor = ActionExecutor(store: store)
        var order: [String] = []
        executor.onEffect = { order.append("effect:\($0.type)") }
        executor.perform = { order.append("perform:\($0.type)") }
        var seen: [ActionEffect] = []
        let report = executor.onEffect
        executor.onEffect = { seen.append($0); report?($0) }

        try await executor.execute(.switchTab(.init(tabId: "search")))
        try await executor.execute(.openDrawer)
        XCTAssertEqual(seen, [ActionEffect("switchTab", ["tabId": "search"]), ActionEffect("openDrawer")])
        XCTAssertEqual(order, ["effect:switchTab", "perform:switchTab", "effect:openDrawer", "perform:openDrawer"])
        XCTAssertEqual(store.state, state)
        XCTAssertTrue(ActionExecutor.implements(.actionGroup(.init(actions: [.switchTab(.init(tabId: "a")), .openDrawer]))))
    }

    func testSetStateWritesTheAppScopeAndReadsEventData() {
        let action = Action.setState(.init(
            key: "query", scope: .app, value: ["type": "event", "key": "text"]))
        let (next, _) = ActionReducer().reduce(StoreState(), action, eventData: ["text": "hi"])
        XCTAssertEqual(next.app["query"], "hi")
        XCTAssertEqual(next.page, [:])
    }

    func testToastDefaultsFollowDart() {
        let (_, effects) = ActionReducer().reduce(StoreState(), .actionGroup(.init(
            mode: "parallel", actions: [.showToast(.init(message: 5)), .showSnackbar(.init())])))
        XCTAssertEqual(effects, [
            ActionEffect("showToast", ["message": "5", "duration": 2000]),
            ActionEffect("showSnackbar", ["message": "", "duration": 4000]),
        ])
    }
}
