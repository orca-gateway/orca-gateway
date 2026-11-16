import Foundation
import XCTest

@testable import OrcaGatewayCore

/// What a host page holds of its SubPages (contract S3, S6, S7, S8 of
/// schema/fixtures/subpage/README.md): the registry of mounted pages, a
/// change applied to the node store and the page state, and the executor's
/// two hooks.
final class SubPageHostTests: XCTestCase {
    private func page(_ id: String, text: String, state: [JSONValue] = []) -> JSONValue {
        [
            "pageId": .string(id), "title": .string(id), "state": .array(state),
            "components": [
                ["id": "0", "type": "Column", "kind": "layout", "childMode": "multi", "props": [:],
                 "children": ["1"], "watches": []],
                ["id": "1", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": .string(text)], "children": [], "watches": []],
            ],
        ]
    }

    private func host() -> PageRenderer {
        PageRenderer(page: PageResponse(pageId: "host", title: "Host", components: [
            ComponentNode(id: "root", type: "Column", kind: .layout, childMode: .multi, children: ["detail"]),
            ComponentNode(id: "detail", type: "SubPage", kind: .layout, childMode: .single),
        ]))
    }

    private let count: JSONValue = ["key": "count", "scope": "page", "initial": 5]

    // MARK: B13.4 the registry, the node store and the page state

    func test_B13_4_theRegistryListsThePrefixesOfEveryMountedPage() {
        var registry = SubPageRegistry()
        XCTAssertEqual(registry.prefixes, [])
        XCTAssertNil(registry["detail"])

        _ = registry.mount("detail", mode: "replace", response: page("a", text: "A"), pageStateKeys: [])
        _ = registry.mount("detail", mode: "join", response: page("b", text: "B"), pageStateKeys: [])
        _ = registry.mount("side", mode: "replace", response: page("c", text: "C"), pageStateKeys: [])
        XCTAssertEqual(registry.prefixes, ["detail:", "detail#1:", "side:"])
        XCTAssertEqual(registry["detail"]?.roots, ["detail:0", "detail#1:0"])
    }

    func test_B13_4_aChangePutsTheNodesInTheStoreAndTheSeedsInThePageState() throws {
        var registry = SubPageRegistry()
        var renderer = host()
        var state = StoreState(page: ["count": 1], app: ["user": "u"])

        let change = registry.mount(
            "detail", mode: "replace", response: page("a", text: "A", state: [count]),
            pageStateKeys: state.page.keys)
        try renderer.apply(change)
        state = state.applying(change)

        XCTAssertEqual(renderer.nodes["detail:0"]?.children, ["detail:1"])
        XCTAssertEqual(renderer.nodes["detail:1"]?.props["data"], "A")
        XCTAssertNotNil(renderer.nodes["root"], "a host node left the store")
        XCTAssertEqual(state.page, ["count": 1, "detail:count": 5])
        XCTAssertEqual(state.app, ["user": "u"])
    }

    func test_B13_5_aReplaceTakesTheOldNodesAndStateKeysOutAJoinKeepsThem() throws {
        var registry = SubPageRegistry()
        var renderer = host()
        var state = StoreState(page: ["count": 1])
        func mount(_ mode: String, _ response: JSONValue) throws {
            let change = registry.mount("detail", mode: mode, response: response, pageStateKeys: state.page.keys)
            try renderer.apply(change)
            state = state.applying(change)
        }

        try mount("replace", page("a", text: "A", state: [count]))
        state.page["detail:count"] = 9
        try mount("join", page("b", text: "B", state: [count]))
        XCTAssertEqual(renderer.nodes["detail#1:1"]?.props["data"], "B")
        XCTAssertEqual(renderer.nodes["detail:1"]?.props["data"], "A")
        XCTAssertEqual(state.page, ["count": 1, "detail:count": 9, "detail#1:count": 5])

        try mount("replace", page("c", text: "C"))
        XCTAssertNil(renderer.nodes["detail#1:0"])
        XCTAssertNil(renderer.nodes["detail#1:1"])
        XCTAssertEqual(renderer.nodes["detail:1"]?.props["data"], "C")
        XCTAssertEqual(state.page, ["count": 1])
        XCTAssertEqual(registry.prefixes, ["detail:"])
    }

    func test_B13_4_unmountGivesTheNodeIdsToRemoveAndForgetsTheSubPage() {
        var registry = SubPageRegistry()
        var renderer = host()
        let change = registry.mount("detail", mode: "replace", response: page("a", text: "A"), pageStateKeys: [])
        XCTAssertNoThrow(try renderer.apply(change))

        let ids = registry.unmount("detail")
        XCTAssertEqual(ids.sorted(), ["detail:0", "detail:1"])
        renderer.removeNodes(ids)
        XCTAssertEqual(renderer.nodes.keys.sorted(), ["detail", "root"])
        XCTAssertEqual(registry.prefixes, [])
        XCTAssertEqual(registry.unmount("detail"), [])
    }

    // MARK: B13.5 the executor

    /// The body of the last request the stub was sent.
    private func posted(_ stub: ActionStub) -> JSONValue? {
        stub.requests.last?.body.flatMap { try? JSONValue.decode($0) }
    }

    @MainActor
    func test_B13_5_updateSubPageResolvesItsFieldsAndEmitsNoEffect() async throws {
        let executor = ActionExecutor(store: ElmStore(page: ["target": "detail", "next": "b", "id": 7]))
        var effects: [ActionEffect] = []
        var calls: [[JSONValue]] = []
        executor.onEffect = { effects.append($0) }
        executor.onUpdateSubPage = { subPageId, pageId, params, mode in
            calls.append([.string(subPageId), .string(pageId), params.map(JSONValue.object) ?? .null, .string(mode)])
        }
        func ref(_ key: String) -> JSONValue { ["type": "state", "scope": "page", "key": .string(key)] }

        try await executor.execute(.updateSubPage(.init(
            subPageId: ref("target"), pageId: ref("next"), params: ["id": ref("id")], mode: "join")))
        try await executor.execute(.updateSubPage(.init(subPageId: "detail", pageId: "c")))

        XCTAssertEqual(calls, [["detail", "b", ["id": 7], "join"], ["detail", "c", .null, "replace"]])
        XCTAssertEqual(effects, [])
        XCTAssertTrue(ActionExecutor.implements(.updateSubPage(.init(subPageId: "detail", pageId: "c"))))
    }

    @MainActor
    func test_B13_5_anUpdateSubPageThatFailsRunsTheLifecycleOnError() async throws {
        struct Failed: Error {}
        let store = ElmStore(page: ["failed": false])
        let executor = ActionExecutor(store: store)
        executor.onUpdateSubPage = { _, _, _, _ in throw Failed() }
        let action = try JSONValue.object([
            "type": "lifecycle",
            "action": ["type": "updateSubPage", "subPageId": "detail", "pageId": "b"],
            "onError": [["type": "setState", "key": "failed", "scope": "page", "value": true]],
        ]).decode(Action.self)
        try await executor.execute(action)
        XCTAssertEqual(store.value("failed"), true)
    }

    @MainActor
    func test_B13_4_aServerActionFiredInsideASubPagePostsItsKeysAndRewritesWhatComesBack() async throws {
        let transport = ActionStub(["bump": ["actions": [
            ["type": "setState", "key": "count", "scope": "page", "value": 6],
            ["type": "setState", "key": "user", "scope": "app", "value": "v"],
        ]]])
        let client = OrcaClient(
            baseURL: URL(string: "http://stub.invalid")!, appId: "app", device: DeviceInfo(osVersion: "test"),
            transport: transport)
        let store = ElmStore(page: ["count": 1, "detail:count": 5, "detail#1:count": 8], app: ["user": "u"])
        let executor = ActionExecutor(store: store, client: client)
        executor.subPagePrefixes = { ["detail:", "detail#1:"] }
        let bump = Action.serverAction(.init(id: "bump"))

        try await executor.execute(bump, source: ActionSource(widgetId: "detail:1", trigger: "onTap"))
        XCTAssertEqual(posted(transport)?["pageState"], ["count": 5])
        XCTAssertEqual(store.state.page, ["count": 1, "detail:count": 6, "detail#1:count": 8])
        XCTAssertEqual(store.state.app, ["user": "v"])

        // A host node posts the whole page state and runs the actions as sent.
        try await executor.execute(bump, source: ActionSource(widgetId: "root", trigger: "onTap"))
        XCTAssertEqual(
            posted(transport)?["pageState"], ["count": 1, "detail:count": 6, "detail#1:count": 8])
        XCTAssertEqual(store.state.page["count"], 6)
    }
}
