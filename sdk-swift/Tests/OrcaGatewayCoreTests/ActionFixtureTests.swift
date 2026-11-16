import Foundation
import XCTest

@testable import OrcaGatewayCore

/// T3.1: schema/fixtures/actions through the Swift executor, as the Flutter
/// runner (sdk/test/conformance/action_fixtures_test.dart) runs them through
/// the Dart executor. Each run seeds the state, runs the steps, and compares
/// the state and the effects as JSON. A fixture with `serverResponses` talks
/// to a stub of the `/action` route, as the Dart runner's stub client does.
///
/// Optional `handlers: [String]` (native parity step 16): before the actions
/// run, a recording handler is registered under each name; it appends
/// `{"kind": "handler", "name": <the name it was registered under>, "action":
/// <the raw action it received>}` to the effects, in order with the others.
///
/// Optional `saved`, `load` and `expected.saved` (native parity step 14,
/// C14.6): `saved` seeds the executor's SavedState, local in its store and
/// session in the process-wide map; `load` sets state up as a boot and a page
/// load do, so saved entries are restored; `expected.saved` is compared exactly.
final class ActionFixtureTests: XCTestCase {
    /// The effects of one run as JSON, SDK effects and handler records alike.
    @MainActor final class Effects {
        var list: [JSONValue] = []
        func append(_ effect: JSONValue) { list.append(effect) }
    }

    @MainActor func testAllThirtyTwoActionFixturesPass() async throws {
        let files = try Fixtures.files("actions")
        XCTAssertEqual(files.count, 32)
        for (name, fx) in files { try await run(name, fx) }
    }

    /// `ActionExecutor.implements`, counting a kind the fixture registers a
    /// handler for, and a `custom:` kind (a silent no-op without one, fixture
    /// 46), as run.
    private func runs(_ action: Action, _ handlers: Set<String>) -> Bool {
        if action.kind.hasPrefix("custom:") || handlers.contains(action.kind) { return true }
        switch action {
        case .actionGroup(let group): return group.actions.allSatisfy { runs($0, handlers) }
        case .lifecycle(let l): return runs(l.action, handlers)
        case .once(let w), .always(let w): return runs(w.action, handlers)
        case .conditionalAction(let c):
            return c.branches.allSatisfy { runs($0.then, handlers) } && (c.else.map { runs($0, handlers) } ?? true)
        default: return ActionExecutor.implements(action)
        }
    }

    @MainActor func testA2_5_OnceRunsOncePerWidgetAndTrigger_fixture16() async throws {
        try await run(fixture: "16_once_per_widget_trigger.json")
    }

    @MainActor func testA2_6_AlwaysRunsEveryTimeAndDebugLogEmitsItsEffect_fixture17() async throws {
        try await run(fixture: "17_always_and_debugLog.json")
    }

    @MainActor func testA2_1_OnInitWrappedInOnceRunsOneTime_fixture18() async throws {
        try await run(fixture: "18_onInit_once.json")
    }

    @MainActor func testA2_4_ScrollTriggersReadTheirEventValues_fixture19() async throws {
        try await run(fixture: "19_scroll_event_values.json")
    }

    /// A5.6: with no reload wired, refetchPage leaves the state alone and
    /// emits no effect, as Flutter's executor awaits a null onRefetchPage.
    @MainActor func testA5_6_RefetchPageEmitsNothing_fixture48() async throws {
        try await run(fixture: "48_refetchPage.json")
    }

    @MainActor func testC14_6_PersistStateSavesASnapshotAndMovesAKeyBetweenStorages_fixture48() async throws {
        try await run(fixture: "48_persist_state.json")
    }

    @MainActor func testC14_6_ClearStateNullsTheKeyAndRemovesItFromBothStorages_fixture49() async throws {
        try await run(fixture: "49_clear_state.json")
    }

    @MainActor func testC14_6_SavedEntriesAreRestoredWhenStateIsSetUp_fixture50() async throws {
        try await run(fixture: "50_restore_saved_state.json")
    }

    // MARK: the source (D1) and once (D2) beyond the fixtures

    @MainActor func testTheSourceIsRestoredAfterANestedRun() async throws {
        let store = ElmStore(StoreState(page: ["a": 0, "b": 0, "c": 0]))
        let executor = ActionExecutor(store: store)
        // The host runs another widget's once while the outer chain waits on
        // its toast; the outer chain must go on under its own source.
        executor.perform = { [weak executor] effect in
            guard effect.type == "showToast" else { return }
            try? await executor?.execute(.once(.init(action: Self.inc("b"))), source: Self.other)
        }
        let outer = Action.actionGroup(.init(actions: [
            .showToast(.init(message: "hi")), .once(.init(action: Self.inc("a"))),
        ]))
        try await executor.execute(outer, source: Self.buy)
        try await executor.execute(outer, source: Self.buy)
        XCTAssertEqual(store.state.page["a"], 1, "the outer once keyed by buy::onTap, not the nested source")
        XCTAssertEqual(store.state.page["b"], 1)

        // After the chain the executor has no source again.
        try await executor.execute(.once(.init(action: Self.inc("c"))))
        try await executor.execute(.once(.init(action: Self.inc("c"))))
        XCTAssertEqual(store.state.page["c"], 2)
    }

    @MainActor func testOnceWithoutASourceRunsEveryTime() async throws {
        let store = ElmStore(StoreState(page: ["n": 0]))
        let executor = ActionExecutor(store: store)
        let once = Action.once(.init(action: Self.inc("n")))
        try await executor.execute(once)
        try await executor.execute(once, eventData: ["x": 1])
        try await executor.executeAll([once, once])
        XCTAssertEqual(store.state.page["n"], 4)
    }

    @MainActor func testTwoOnceUnderOneWidgetAndTriggerShareTheirKeyAsInFlutter() async throws {
        // Flutter's known limit (action_executor.dart once): the key is
        // widgetId::trigger, with no id for the wrapper, so the second once
        // of the chain is taken as already fired.
        let store = ElmStore(StoreState(page: ["a": 0, "b": 0]))
        let executor = ActionExecutor(store: store)
        try await executor.execute(.actionGroup(.init(actions: [
            .once(.init(action: Self.inc("a"))), .once(.init(action: Self.inc("b"))),
        ])), source: Self.buy)
        XCTAssertEqual(store.state.page["a"], 1)
        XCTAssertEqual(store.state.page["b"], 0)
    }

    func testImplementsLooksInsideOnceAndAlways() {
        XCTAssertTrue(ActionExecutor.implements(.once(.init(action: .goBack))))
        XCTAssertTrue(ActionExecutor.implements(.always(.init(action: .debugLog(.init())))))
        XCTAssertFalse(ActionExecutor.implements(.once(.init(action: .closeDialog))))
        // Was refetchPage until native parity step 5 made it a known kind;
        // closeDialog, as Kotlin's twin (ActionFixtureTest.kt).
        XCTAssertFalse(ActionExecutor.implements(.always(.init(action: .once(.init(action: .closeDialog))))))
    }

    // MARK: baseline rules

    @MainActor func testUnimplementedKindsChangeNothing() async throws {
        let state = StoreState(page: ["count": 1])
        let (next, effects) = ActionReducer().reduce(state, .refetchPage)
        XCTAssertEqual(next, state)
        XCTAssertEqual(effects, [])

        let store = ElmStore(state)
        let executor = ActionExecutor(store: store)
        var seen: [ActionEffect] = []
        executor.onEffect = { seen.append($0) }
        try await executor.execute(.refetchPage)
        try await executor.execute(.closeDialog)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(seen, [])
        XCTAssertFalse(ActionExecutor.implements(.actionGroup(.init(actions: [.goBack, .closeDialog]))))
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

    /// B12.1-S: fixture 32, the two animation effects in their place in a
    /// sequential group, state untouched by them.
    @MainActor func testB12_1_S_AnimateForwardAndReverseEmitTheirId_fixture32() async throws {
        try await run(fixture: "32_animate_forward_reverse.json")
    }

    /// B12.1-S: fixture 33, an id no builder registered still goes out and
    /// the group runs on.
    @MainActor func testB12_1_S_AnimateUnknownIdStillEmitsAndTheGroupGoesOn_fixture33() async throws {
        try await run(fixture: "33_animate_unknown_id.json")
    }

    /// B13.5-S: fixture 35, an updateSubPage naming no mounted SubPage does
    /// nothing and the group runs on.
    @MainActor func testB13_5_S_UpdateSubPageUnknownIdDoesNothingAndTheGroupGoesOn_fixture35() async throws {
        try await run(fixture: "35_update_sub_page_unknown_id.json")
    }

    /// B12.1-S: the two animation effects go out as data, then to the
    /// platform (the page model's registry), and leave the state alone; an
    /// empty id emits nothing and the group runs its next action.
    @MainActor func testB12_1_S_AnimateEmitsThenPerformsAndAnEmptyIdEmitsNothing() async throws {
        let state = StoreState(page: ["count": 1])
        let store = ElmStore(state)
        let executor = ActionExecutor(store: store)
        var order: [String] = []
        var seen: [ActionEffect] = []
        executor.onEffect = { seen.append($0); order.append("effect:\($0.type)") }
        executor.perform = { order.append("perform:\($0.type)") }

        try await executor.execute(.animateForward(.init(animationId: "pulse")))
        try await executor.execute(.animateReverse(.init(animationId: "pulse")))
        XCTAssertEqual(seen, [
            ActionEffect("animateForward", ["animationId": "pulse"]),
            ActionEffect("animateReverse", ["animationId": "pulse"]),
        ])
        XCTAssertEqual(order, [
            "effect:animateForward", "perform:animateForward", "effect:animateReverse", "perform:animateReverse",
        ])
        XCTAssertEqual(store.state, state)

        seen = []
        try await executor.execute(.actionGroup(.init(actions: [
            .animateForward(.init(animationId: "")), .animateReverse(.init(animationId: "")), .goBack,
        ])))
        XCTAssertEqual(seen, [ActionEffect("goBack")])
        XCTAssertEqual(store.state, state)
        XCTAssertTrue(ActionExecutor.implements(.actionGroup(.init(actions: [
            .animateForward(.init(animationId: "a")), .animateReverse(.init(animationId: "a")),
        ]))))
        XCTAssertTrue(ActionExecutor.kinds.isSuperset(of: ["animateForward", "animateReverse"]))
        XCTAssertTrue(Set(GeneratedCapabilities.actionKinds).isSuperset(of: ["animateForward", "animateReverse"]))
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

    // MARK: runner

    private static let buy = ActionSource(widgetId: "buy", trigger: "onTap")
    private static let other = ActionSource(widgetId: "cancel", trigger: "onTap")

    /// `page[key] += 1`, as the fixtures write it.
    private static func inc(_ key: String) -> Action {
        .setState(.init(key: key, value: [
            "type": "transform",
            "input": ["type": "state", "scope": "page", "key": .string(key)],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]))
    }

    @MainActor private func run(fixture file: String) async throws {
        try await run(file, try Fixtures.json("schema/fixtures/actions/\(file)"))
    }

    /// One fixture, as the Flutter runner runs it: the `handlers` registered
    /// first, then `steps` in order, each with its `source` and its own
    /// `event` (else the fixture's); `actions` are steps with no source.
    @MainActor private func run(_ name: String, _ fx: JSONValue) async throws {
        let steps = fx["steps"].arrayValue
            ?? (fx["actions"].arrayValue ?? []).map { JSONValue.object(["action": $0]) }
        let actions = try steps.map { try $0["action"].decode(Action.self) }
        let handlers = (fx["handlers"].arrayValue ?? []).compactMap(\.stringValue)
        XCTAssertTrue(actions.allSatisfy { runs($0, Set(handlers)) }, "\(name): every kind implemented")

        // `saved` (native parity step 14) seeds both storages: local in the
        // store the SavedState reads, session through the process-wide map,
        // which every fixture starts from and leaves empty.
        let local = MemoryKeyValueStore(try Self.entries(fx["saved"], "local").mapValues { try wireText(.object($0)) })
        SavedState.resetSession(try Self.entries(fx["saved"], "session"))
        defer { SavedState.resetSession() }
        let saved = SavedState(local: local)

        // Without `load` the state is seeded as is and nothing is restored.
        // With it the runner boots (app state, the saved app entry over it)
        // and sets the page up from `load.state`, its saved entry restored.
        let state = try fx["state"].decode(StoreState.self)
        let store = ElmStore(fx["load"].isNull ? state : StoreState(app: state.app))
        store.pageId = fx["pageId"].stringValue
        if !fx["load"].isNull {
            XCTAssertEqual(state.page, [:], "\(name): with load, state.page is {}")
            saved.restore(into: store)
            store.seed(try fx["load"]["state"].decode([StateDefinition].self))
            saved.restorePage(into: store, pageId: try XCTUnwrap(store.pageId, "\(name): pageId"))
        }
        var client: OrcaClient?
        if case .object(let responses) = fx["serverResponses"] {
            client = ActionStub.client(ActionStub(responses))
        }
        let executor = ActionExecutor(store: store, client: client)
        executor.savedState = saved
        let effects = Effects()
        executor.onEffect = { effects.append($0.json) }
        for handler in handlers {
            executor.registerHandler(handler) { action, _ in
                await effects.append(["kind": "handler", "name": .string(handler), "action": action])
            }
        }

        for (step, action) in zip(steps, actions) {
            let source = step["source"].objectValue.map {
                ActionSource(widgetId: $0["widgetId"]?.stringValue ?? "", trigger: $0["trigger"]?.stringValue ?? "")
            }
            try await executor.execute(
                action, eventData: step["event"].objectValue ?? fx["event"].objectValue, source: source)
        }
        assertJSONEqual(try jsonOf(store.state), fx["expected"]["state"], "\(name): state")
        assertJSONEqual(.array(effects.list), fx["expected"]["effects"], "\(name): effects")

        // `expected.saved`, exactly: an entry it does not list must not exist
        // and an absent storage is empty. Local as the store holds it,
        // session as the process-wide map holds it.
        let want = fx["expected"]["saved"]
        if !want.isNull {
            assertJSONEqual(
                .object(try local.values.mapValues { try JSONValue.decode(Data($0.utf8)) }),
                .object(try Self.entries(want, "local").mapValues { .object($0) }), "\(name): saved local")
            assertJSONEqual(
                .object(SavedState.sessionEntries.mapValues { .object($0) }),
                .object(try Self.entries(want, "session").mapValues { .object($0) }), "\(name): saved session")
        }
    }

    /// One storage (`local` or `session`) of a fixture's `saved` or
    /// `expected.saved`: its entries by name, none when absent.
    private static func entries(_ saved: JSONValue, _ storage: String) throws -> [String: [String: JSONValue]] {
        let json = saved[storage]
        return json.isNull ? [:] : try json.decode([String: [String: JSONValue]].self)
    }
}
