import Foundation
import XCTest

@testable import OrcaGatewayCore

/// T3.1: schema/fixtures/actions through the Swift executor, as the Flutter
/// runner (sdk/test/conformance/action_fixtures_test.dart) runs them through
/// the Dart executor. Each run seeds the state, runs the actions, and compares
/// the state and the effects as JSON. A fixture with `serverResponses` talks
/// to a stub of the `/action` route, as the Dart runner's stub client does.
///
/// Optional `handlers: [String]` (native parity step 16): before the actions
/// run, a recording handler is registered under each name; it appends
/// `{"kind": "handler", "name": <the name it was registered under>, "action":
/// <the raw action it received>}` to the effects, in order with the others.
final class ActionFixtureTests: XCTestCase {
    /// The effects of one run as JSON, SDK effects and handler records alike.
    @MainActor final class Effects {
        var list: [JSONValue] = []
        func append(_ effect: JSONValue) { list.append(effect) }
    }

    @MainActor func testAllActionFixturesPass() async throws {
        let files = try Fixtures.files("actions")
        XCTAssertEqual(files.count, 18)
        for (name, fx) in files {
            let actions = try (fx["actions"].arrayValue ?? []).map { try $0.decode(Action.self) }
            let handlers = (fx["handlers"].arrayValue ?? []).compactMap(\.stringValue)
            XCTAssertTrue(actions.allSatisfy { runs($0, Set(handlers)) }, "\(name): every kind implemented")

            let store = ElmStore(try fx["state"].decode(StoreState.self))
            var client: OrcaClient?
            if case .object(let responses) = fx["serverResponses"] {
                client = ActionStub.client(ActionStub(responses))
            }
            let executor = ActionExecutor(store: store, client: client)
            let effects = Effects()
            executor.onEffect = { effects.append($0.json) }
            for handler in handlers {
                executor.registerHandler(handler) { action, _ in
                    await effects.append(["kind": "handler", "name": .string(handler), "action": action])
                }
            }

            for action in actions {
                try await executor.execute(action, eventData: fx["event"].objectValue)
            }
            assertJSONEqual(try jsonOf(store.state), fx["expected"]["state"], "\(name): state")
            assertJSONEqual(.array(effects.list), fx["expected"]["effects"], "\(name): effects")
        }
    }

    /// `ActionExecutor.implements`, counting a kind the fixture registers a
    /// handler for, and a `custom:` kind (a silent no-op without one, fixture
    /// 46), as run.
    private func runs(_ action: Action, _ handlers: Set<String>) -> Bool {
        if action.kind.hasPrefix("custom:") || handlers.contains(action.kind) { return true }
        switch action {
        case .actionGroup(let group): return group.actions.allSatisfy { runs($0, handlers) }
        case .lifecycle(let l): return runs(l.action, handlers)
        case .conditionalAction(let c):
            return c.branches.allSatisfy { runs($0.then, handlers) } && (c.else.map { runs($0, handlers) } ?? true)
        default: return ActionExecutor.implements(action)
        }
    }

    @MainActor func testUnimplementedKindsChangeNothing() async throws {
        let state = StoreState(page: ["count": 1])
        let (next, effects) = ActionReducer().reduce(state, .openDrawer)
        XCTAssertEqual(next, state)
        XCTAssertEqual(effects, [])

        let store = ElmStore(state)
        let executor = ActionExecutor(store: store)
        var seen: [ActionEffect] = []
        executor.onEffect = { seen.append($0) }
        try await executor.execute(.openDrawer)
        try await executor.execute(.closeDialog)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(seen, [])
        XCTAssertFalse(ActionExecutor.implements(.actionGroup(.init(actions: [.goBack, .openDrawer]))))
        XCTAssertTrue(ActionExecutor.implements(.actionGroup(.init(actions: [.goBack, .setState(.init(key: "a", value: 1))]))))
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
