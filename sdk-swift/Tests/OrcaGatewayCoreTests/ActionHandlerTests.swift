import Foundation
import XCTest

@testable import OrcaGatewayCore

/// C16.2: custom action handlers on `ActionExecutor`, as Dart's
/// `registerHandler` and `execute` (sdk/lib/src/state/action_executor.dart):
/// the exact type first, then the type without `custom:`; the handler gets the
/// raw action and resolves values itself; no handler means a silent no-op.
final class ActionHandlerTests: XCTestCase {
    /// What the handlers saw, in order: the name each was registered under and
    /// the action it received.
    @MainActor final class Recorder {
        var calls: [(name: String, action: JSONValue)] = []
        var names: [String] { calls.map(\.name) }
        func record(_ name: String, _ action: JSONValue) { calls.append((name, action)) }
    }

    @MainActor private func executor(
        _ state: StoreState = StoreState(), handlers: [String]
    ) -> (ActionExecutor, Recorder, () -> [ActionEffect]) {
        let executor = ActionExecutor(store: ElmStore(state))
        let recorder = Recorder()
        for name in handlers {
            executor.registerHandler(name) { action, _ in await recorder.record(name, action) }
        }
        var effects: [ActionEffect] = []
        executor.onEffect = { effects.append($0) }
        return (executor, recorder, { effects })
    }

    private func action(_ json: JSONValue) throws -> Action { try json.decode(Action.self) }

    @MainActor func testC16_2_ExactMatchWinsOverBare() async throws {
        let (executor, recorder, _) = executor(handlers: ["custom:ping", "ping"])
        try await executor.execute(action(["type": "custom:ping"]))
        try await executor.execute(action(["type": "ping"]))
        XCTAssertEqual(recorder.names, ["custom:ping", "ping"])
    }

    @MainActor func testC16_2_PrefixedAndBareTypesReachABareHandler() async throws {
        let (executor, recorder, _) = executor(handlers: ["x"])
        try await executor.execute(action(["type": "custom:x"]))
        try await executor.execute(action(["type": "x"]))
        XCTAssertEqual(recorder.names, ["x", "x"])
        XCTAssertEqual(recorder.calls.map(\.action), [["type": "custom:x"], ["type": "x"]])
    }

    @MainActor func testC16_2_HandlerGetsTheRawActionWithParamsAsSiblingKeys() async throws {
        let raw: JSONValue = [
            "type": "custom:pay", "amount": 12, "note": ["type": "state", "scope": "page", "key": "n"],
        ]
        let (executor, recorder, _) = executor(StoreState(page: ["n": "unused"]), handlers: ["pay"])
        try await executor.execute(action(raw))
        XCTAssertEqual(recorder.calls.map(\.action), [raw], "type as sent, values unresolved")
    }

    @MainActor func testC16_2_HandlerNamedLikeABuiltInReplacesIt() async throws {
        let (executor, recorder, effects) = executor(handlers: ["navigate"])
        try await executor.execute(.navigate(.init(route: "/a")))
        XCTAssertEqual(effects(), [], "no built-in navigation")
        XCTAssertEqual(recorder.calls.map(\.action), [["type": "navigate", "route": "/a"]])
    }

    @MainActor func testC16_2_ReRegisteringATypeReplacesItsHandler() async throws {
        let (executor, recorder, _) = executor(handlers: ["x"])
        executor.registerHandler("x") { action, _ in await recorder.record("second", action) }
        try await executor.execute(action(["type": "custom:x"]))
        XCTAssertEqual(recorder.names, ["second"])
    }

    @MainActor func testC16_2_UnhandledCustomActionIsANoOpAndTheGroupGoesOn() async throws {
        let (executor, recorder, effects) = executor(StoreState(page: ["count": 0]), handlers: ["other"])
        try await executor.execute(action([
            "type": "actionGroup",
            "actions": [
                ["type": "custom:rateApp", "stars": 5],
                ["type": "setState", "key": "count", "value": ["type": "static", "value": 1]],
            ],
        ]))
        XCTAssertEqual(executor.store.state.page["count"], 1)
        XCTAssertEqual(effects(), [])
        XCTAssertEqual(recorder.names, [])
    }

    @MainActor func testC16_2_ResolveReadsEventDataAndStateInsideAHandler() async throws {
        let executor = ActionExecutor(store: ElmStore(StoreState(page: ["count": 3], app: ["user": "amr"])))
        let recorder = Recorder()
        executor.registerHandler("echo") { action, executor in
            let text = await executor.resolve(action["text"])
            let count = await executor.resolve(action["count"])
            let user = await executor.resolve(action["user"])
            await recorder.record("echo", ["text": text, "count": count, "user": user])
        }
        let echo = try action([
            "type": "custom:echo",
            "text": ["type": "event", "key": "text"],
            "count": ["type": "state", "scope": "page", "key": "count"],
            "user": ["type": "state", "scope": "app", "key": "user"],
        ])
        try await executor.execute(.actionGroup(.init(actions: [echo])), eventData: ["text": "hi"])
        XCTAssertEqual(recorder.calls.map(\.action), [["text": "hi", "count": 3, "user": "amr"]])
    }

    struct Boom: Error, Equatable {}

    @MainActor func testC16_2_HandlerErrorsPropagate() async throws {
        let executor = ActionExecutor(store: ElmStore(StoreState()))
        executor.registerHandler("fail") { _, _ in throw Boom() }
        do {
            try await executor.execute(action(["type": "custom:fail"]))
            XCTFail("expected the handler's error")
        } catch let error as Boom {
            XCTAssertEqual(error, Boom())
        }
    }

    @MainActor func testC16_2_KindsStayTheBuiltInList() async {
        let executor = ActionExecutor(store: ElmStore(StoreState()))
        executor.registerHandler("hapticFeedback") { _, _ in }
        executor.registerHandler("custom:ping") { _, _ in }
        XCTAssertEqual(ActionExecutor.kinds, [
            "setState", "actionGroup", "showSnackbar", "showToast", "conditionalAction",
            "lifecycle", "navigate", "goBack", "openUrl", "copyToClipboard", "share",
            "serverAction", "addComponent", "updateComponent", "deleteComponent", "replaceComponent",
            "switchTab", "openDrawer", "once", "always", "debugLog", "animateForward", "animateReverse",
            "updateSubPage",
            // Native parity step 5 (A5.6): run by the page model's handler.
            "refetchPage",
            "persistState", "clearState",
            // Native parity step 8 (A8.1): run by the page model's handlers.
            "openDialog", "closeDialog",
        ])
    }

    // MARK: A8.1 openDialog and closeDialog

    /// Holds a handler until the test lets it go, as a sheet holds openDialog
    /// until it closes (Flutter awaits showModalBottomSheet, orca_page.dart).
    @MainActor final class Gate {
        var continuation: CheckedContinuation<Void, Never>?
        func wait() async { await withCheckedContinuation { continuation = $0 } }
        func open() {
            continuation?.resume()
            continuation = nil
        }
    }

    /// Both are known kinds, as Flutter's executor has a built-in handler for
    /// each (sdk/lib/src/state/action_executor.dart, openDialog and
    /// closeDialog), so a chain holding them counts as implemented.
    func testA8_1_OpenDialogAndCloseDialogAreKnownKinds() {
        XCTAssertTrue(ActionExecutor.kinds.isSuperset(of: ["openDialog", "closeDialog"]))
        XCTAssertTrue(ActionExecutor.implements(.openDialog(.init(dialogId: "d", heightFactor: 0.4))))
        XCTAssertTrue(ActionExecutor.implements(.closeDialog))
        XCTAssertTrue(ActionExecutor.implements(.actionGroup(.init(actions: [
            .openDialog(.init(dialogId: "d")), .always(.init(action: .once(.init(action: .closeDialog)))),
        ]))))
    }

    /// With no page handler each runs nothing: no state change and no effect
    /// (Flutter's openDialog awaits a null onOpenDialog, its closeDialog has
    /// no context), the chain goes on, and DevTools hears each as a run
    /// action, as Flutter reports every action a handler took.
    @MainActor func testA8_1_WithNoHandlerBothChangeNoStateAndEmitNoEffect() async throws {
        let debug = EventRecorder()
        OrcaDebug.reporter = debug
        defer { OrcaDebug.reporter = nil }
        let state = StoreState(page: ["count": 0, "flag": true], app: ["user": "amr"])
        let (executor, recorder, effects) = executor(state, handlers: [])
        try await executor.execute(.actionGroup(.init(actions: [
            .openDialog(.init(dialogId: "d", heightFactor: 0.4)),
            .closeDialog,
            .setState(.init(key: "count", value: 1)),
        ])))
        var after = state
        after.page["count"] = 1
        XCTAssertEqual(executor.store.state, after, "only the setState after them changed state")
        XCTAssertEqual(effects(), [])
        XCTAssertEqual(recorder.names, [])
        let reported = debug.of("action").compactMap { $0.payload["actionType"]?.stringValue }
        XCTAssertEqual(reported, ["openDialog", "closeDialog", "setState", "actionGroup"])
    }

    /// A page registers openDialog and closeDialog as it registers
    /// refetchPage: each handler gets the action as sent (dialogId and
    /// heightFactor), and nothing goes out as an effect.
    @MainActor func testA8_1_ARegisteredHandlerRunsWithTheAction() async throws {
        let (executor, recorder, effects) = executor(handlers: ["openDialog", "closeDialog"])
        try await executor.execute(.openDialog(.init(dialogId: "confirm", heightFactor: 0.4)))
        try await executor.execute(.openDialog(.init(dialogId: "plain")))
        try await executor.execute(.closeDialog)
        XCTAssertEqual(recorder.names, ["openDialog", "openDialog", "closeDialog"])
        XCTAssertEqual(recorder.calls.map(\.action), [
            ["type": "openDialog", "dialogId": "confirm", "heightFactor": 0.4],
            ["type": "openDialog", "dialogId": "plain"],
            ["type": "closeDialog"],
        ])
        XCTAssertEqual(effects(), [])
    }

    /// The action after openDialog in a sequential group runs only once the
    /// page's handler returns, that is once its sheet has closed.
    @MainActor func testA8_1_TheNextActionWaitsForTheOpenDialogHandler() async throws {
        let executor = ActionExecutor(store: ElmStore(StoreState(page: ["after": 0])))
        let gate = Gate()
        executor.registerHandler("openDialog") { _, _ in await gate.wait() }
        let chain = Task { @MainActor in
            try await executor.execute(.actionGroup(.init(mode: "sequential", actions: [
                .openDialog(.init(dialogId: "d", heightFactor: 0.4)),
                .setState(.init(key: "after", value: 1)),
            ])))
        }
        for _ in 0..<1000 where gate.continuation == nil { await Task.yield() }
        XCTAssertNotNil(gate.continuation, "the handler never started")
        XCTAssertEqual(executor.store.state.page["after"], 0, "ran before the sheet closed")
        gate.open()
        try await chain.value
        XCTAssertEqual(executor.store.state.page["after"], 1)
    }
}
