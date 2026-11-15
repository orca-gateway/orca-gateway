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
        ])
    }
}
