import Foundation
import XCTest

@testable import OrcaGatewayCore

/// schema/fixtures/actions through the Swift reducer, as the Flutter runner
/// (sdk/test/conformance/action_fixtures_test.dart) runs them through the Dart
/// executor: seed state, run the actions, compare state and effects as JSON.
///
/// S2 runs every fixture whose actions the reducer fully implements; S3 widens
/// the set to all fifteen.
final class ActionFixtureTests: XCTestCase {
    /// The fixtures S2 promised (gate 08): setState, actionGroup, showSnackbar,
    /// showToast and the counter scenario.
    static let promised = [
        "01_setState.json", "02_actionGroup.json", "07_showSnackbar.json",
        "08_showToast.json", "13_scenario_counter.json",
    ]

    func testEveryFixtureTheReducerImplementsPasses() throws {
        var ran: [String] = []
        for (name, fx) in try Fixtures.files("actions") {
            let actions = try (fx["actions"].arrayValue ?? []).map { try $0.decode(Action.self) }
            guard actions.allSatisfy(ActionReducer.implements) else { continue }
            ran.append(name)

            var state = try fx["state"].decode(StoreState.self)
            var effects: [ActionEffect] = []
            let event = fx["event"].objectValue
            for action in actions {
                let (next, more) = ActionReducer().reduce(state, action, eventData: event)
                state = next
                effects += more
            }
            assertJSONEqual(try jsonOf(state), fx["expected"]["state"], "\(name): state")
            assertJSONEqual(.array(effects.map(\.json)), fx["expected"]["effects"], "\(name): effects")
        }
        for name in Self.promised {
            XCTAssertTrue(ran.contains(name), "\(name) should run in S2")
        }
    }

    func testUnimplementedKindsChangeNothing() throws {
        let state = StoreState(page: ["count": 1])
        let (next, effects) = ActionReducer().reduce(state, .goBack)
        XCTAssertEqual(next, state)
        XCTAssertEqual(effects, [])
        XCTAssertFalse(ActionReducer.implements(.actionGroup(.init(actions: [.setState(.init(key: "a", value: 1)), .goBack]))))
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
