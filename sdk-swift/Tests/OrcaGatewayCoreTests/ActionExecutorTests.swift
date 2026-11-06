import Foundation
import XCTest

@testable import OrcaGatewayCore

/// T3.3 and the executor's own rules beyond the fixtures: the server action
/// request, how its failures surface, lifecycle order, and parallel groups.
final class ActionExecutorTests: XCTestCase {
    @MainActor private func executor(
        _ state: StoreState = StoreState(), stub: ActionStub? = nil
    ) -> (ActionExecutor, ElmStore, Box) {
        let store = ElmStore(state)
        let executor = ActionExecutor(store: store, client: stub.map(ActionStub.client))
        let box = Box()
        executor.onEffect = { box.effects.append($0) }
        executor.onMutation = { box.mutations.append($0) }
        return (executor, store, box)
    }

    final class Box {
        var effects: [ActionEffect] = []
        var mutations: [ComponentMutation] = []
        var types: [String] { effects.map(\.type) }
    }

    // MARK: T3.3 server actions

    @MainActor func testServerActionPostsTheDartBody() async throws {
        let stub = ActionStub(["save": ["actions": []]])
        let (executor, _, _) = executor(StoreState(page: ["n": 1], app: ["user": "amr"]), stub: stub)
        try await executor.execute(.serverAction(.init(
            id: "save", params: ["n": ["type": "state", "scope": "page", "key": "n"]])))

        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(stub.requests.count, 1, "no caps retry on actions")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "http://stub.invalid/api/v1/app/fixture-app/action")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertNotNil(request.headers["x-orca-caps-hash"])
        XCTAssertEqual(request.headers["x-orca-platform"], "iOS")
        assertJSONEqual(try JSONValue.decode(request.body ?? Data()), [
            "action": "save", "params": ["n": 1], "pageState": ["n": 1], "appState": ["user": "amr"],
        ])
    }

    @MainActor func testResponseActionsRunAndSetStateDefaultsToPageScope() async throws {
        let stub = ActionStub(["add": ["actions": [
            ["type": "setState", "key": "cart", "value": 2],
            ["type": "setState", "key": "user", "scope": "app", "value": "x"],
            ["type": "showToast", "message": "Added"],
        ]]])
        let (executor, store, box) = executor(stub: stub)
        try await executor.execute(.serverAction(.init(id: "add")))
        XCTAssertEqual(store.state.page["cart"], 2)
        XCTAssertEqual(store.state.app["user"], "x")
        XCTAssertEqual(box.types, ["serverAction", "showToast"])
    }

    @MainActor func testRefusedCallsShowTheServerMessageInASnackbar() async throws {
        let stub = ActionStub([:], raw: [
            "forbidden": ActionStub.json(403, ["error": "Forbidden"]),
            "missing": ActionStub.json(404, ["error": "Unknown action: missing"]),
            // A thrown handler: the engine adds a snackbar Flutter ignores.
            "boom": ActionStub.json(500, [
                "error": "Server action failed",
                "actions": [["type": "showSnackbar", "message": "TypeError: x"]],
            ]),
            "silent": ActionStub.json(400, [:]),
        ])
        let (executor, _, box) = executor(stub: stub)
        for id in ["forbidden", "missing", "boom", "silent"] {
            try await executor.execute(.serverAction(.init(id: id)))
        }
        let messages = box.effects.filter { $0.type == "showSnackbar" }
            .map { $0.payload["message"]?.stringValue ?? "" }
        XCTAssertEqual(messages, [
            "Forbidden", "Unknown action: missing", "Server action failed", "Server action failed",
        ])
    }

    @MainActor func testABodyThatIsNotJSONThrowsToTheLifecycle() async throws {
        let stub = ActionStub([:], raw: ["html": HTTPResponse(status: 502, body: Data("<html>".utf8))])
        let (executor, store, box) = executor(stub: stub)
        try await executor.execute(.lifecycle(.init(
            action: .serverAction(.init(id: "html")),
            onLoading: .single(.setState(.init(key: "loading", value: true))),
            onError: .single(.showToast(.init(message: "failed"))),
            onComplete: .single(.setState(.init(key: "loading", value: false))))))
        XCTAssertEqual(store.state.page["loading"], false)
        XCTAssertEqual(box.types, ["serverAction", "showToast"])
    }

    @MainActor func testWithoutAClientOnlyTheRequestIsEmitted() async throws {
        let (executor, _, box) = executor()
        try await executor.execute(.serverAction(.init(id: "x", params: ["a": 1])))
        XCTAssertEqual(box.effects, [ActionEffect("serverAction", ["id": "x", "params": ["a": 1]])])
    }

    // MARK: lifecycle and groups

    @MainActor func testLifecycleOrderOnSuccess() async throws {
        let (executor, _, box) = executor()
        try await executor.execute(.lifecycle(.init(
            action: .showToast(.init(message: "action")),
            onLoading: .single(.showToast(.init(message: "loading"))),
            onSuccess: .many([.showToast(.init(message: "success"))]),
            onError: .single(.showToast(.init(message: "error"))),
            onComplete: .single(.showToast(.init(message: "complete"))))))
        XCTAssertEqual(box.effects.map { $0.payload["message"]?.stringValue }, [
            "loading", "action", "success", "complete",
        ])
    }

    @MainActor func testLifecycleWithoutOnErrorRethrowsAfterOnComplete() async throws {
        let stub = ActionStub([:], raw: ["bad": HTTPResponse(status: 500, body: Data("oops".utf8))])
        let (executor, _, box) = executor(stub: stub)
        do {
            try await executor.execute(.lifecycle(.init(
                action: .serverAction(.init(id: "bad")),
                onComplete: .single(.showToast(.init(message: "complete"))))))
            XCTFail("expected the decoding error to go on up")
        } catch {}
        XCTAssertEqual(box.types, ["serverAction", "showToast"])
    }

    @MainActor func testParallelGroupRunsEveryAction() async throws {
        let (executor, store, box) = executor()
        try await executor.execute(.actionGroup(.init(mode: "parallel", actions: [
            .setState(.init(key: "a", value: 1)),
            .setState(.init(key: "b", value: 2)),
            .showToast(.init(message: "t")),
        ])))
        XCTAssertEqual(store.state.page, ["a": 1, "b": 2])
        XCTAssertEqual(box.types, ["showToast"])
    }

    @MainActor func testNavigateWithAnEmptyRouteDoesNothing() async throws {
        let (executor, _, box) = executor()
        try await executor.execute(.navigate(.init(route: "")))
        try await executor.execute(.navigate(.init(path: "about")))
        XCTAssertEqual(box.effects, [ActionEffect("navigate", ["route": "about", "replace": false])])
    }

    @MainActor func testEffectsReachThePerformerAfterTheSink() async throws {
        let (executor, _, box) = executor()
        var performed: [String] = []
        executor.perform = { performed.append($0.type) }
        try await executor.execute(.actionGroup(.init(actions: [
            .goBack, .openUrl(.init(url: "https://orcagateway.com")),
            .copyToClipboard(.init(text: "hi")), .share(.init(title: "", message: "m")),
            .serverAction(.init(id: "x")),
        ])))
        XCTAssertEqual(box.types, ["goBack", "openUrl", "copyToClipboard", "share", "serverAction"])
        XCTAssertEqual(performed, ["goBack", "openUrl", "copyToClipboard", "share"], "serverAction is not performed")
    }

    // MARK: component mutations

    @MainActor func testComponentKindsBecomeMutations() async throws {
        let node: JSONValue = [
            "id": "c-1", "type": "Text", "kind": "primitive", "childMode": "none",
            "props": ["data": "x"], "children": [], "watches": [],
        ]
        let (executor, _, box) = executor()
        try await executor.execute(.updateComponent(.init(id: "t", props: ["data": "y"])))
        try await executor.execute(.deleteComponent(.init(id: "t")))
        try await executor.execute(.addComponent(.init(parentId: "list", components: [node], position: 0)))
        try await executor.execute(.unknown([
            "type": "replaceComponent", "targetId": "list", "components": [node],
        ]))
        XCTAssertEqual(box.mutations.count, 4)
        XCTAssertEqual(box.mutations[0], .update(id: "t", props: ["data": "y"]))
        XCTAssertEqual(box.mutations[1], .delete(id: "t"))
        guard case .add(let parent, let nodes, let position) = box.mutations[2],
            case .replace(let target, let replacement) = box.mutations[3]
        else { return XCTFail("add and replace expected") }
        XCTAssertEqual(parent, "list")
        XCTAssertEqual(position, 0)
        XCTAssertEqual(nodes.map(\.id), ["c-1"])
        XCTAssertEqual(target, "list")
        XCTAssertEqual(replacement.map(\.type), ["Text"])
        XCTAssertEqual(box.effects, [], "mutations emit no effects, as in Dart")
    }
}
