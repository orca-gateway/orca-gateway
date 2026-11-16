#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@testable import OrcaGateway

/// B13.4-S and B13.5-S, the UI part: what the fixtures of
/// schema/fixtures/subpage cannot pin. The SubPage widget fetches, mounts
/// through the core and draws; updateSubPage replaces or joins; a server
/// action fired inside sees its own page. The host page is drawn in a real
/// window (the fetch starts when the SubPage appears) against a stub client.
@MainActor
final class SubPageTests: XCTestCase {
    // MARK: B13.4 fetch

    func test_B13_4_theResolvedParamsReachTheRequestPathAndAppStateIsPosted() throws {
        let stub = SubPagePages()
        let stage = try Stage(
            stub, subPage: ["pageId": "a", "params": ["userId": Self.page("uid"), "b": 2, "none": .null]],
            state: ["uid": "u 42"], app: ["theme": "dark"])
        defer { stage.close() }
        stage.wait("the sub-page") { stage.model.renderer.nodes["detail:0"] != nil }

        XCTAssertEqual(stub.pagePaths, ["a?b=2&userId=u%2042"])
        XCTAssertEqual(PageStub.appState(try XCTUnwrap(stub.requests.first)), ["theme": "dark"])
    }

    func test_B13_4_aPageIdOrParamsChangeFetchesAgainAsAReplace() throws {
        let stub = SubPagePages()
        let stage = try Stage(
            stub, subPage: ["pageId": Self.page("which"), "params": ["id": Self.page("uid")]],
            watches: ["which", "uid"], state: ["which": "a", "uid": 1])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }

        stage.model.store.dispatch(["which": "b"])
        stage.wait("page b") { stage.model.renderer.nodes["detail:7"] == nil }
        XCTAssertEqual(stage.model.renderer.nodes["detail:1"]?.props["data"], "B")
        XCTAssertEqual(stage.model.store.state.page["detail:name"], "b")
        XCTAssertNil(stage.model.store.state.page["detail:count"], "the replaced page's state stayed")

        stage.model.store.dispatch(["uid": 2])
        stage.wait("the params' fetch") { stub.pagePaths.count == 3 }
        XCTAssertEqual(stub.pagePaths, ["a?id=1", "b?id=1", "b?id=2"])

        // A redraw with the same page and params fetches nothing.
        stage.model.store.dispatch(["count": 2])
        stage.pump(0.3)
        XCTAssertEqual(stub.pagePaths.count, 3)
        XCTAssertEqual(stage.model.subPages.prefixes, ["detail:"])
    }

    // MARK: B13.4 drawing

    func test_B13_4_aScaffoldAndAnAppBarInsideASubPageDrawThroughTheirSlots() throws {
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("the body") { stage.drawn.contains("detail:7") }

        XCTAssertEqual(stage.model.resolve("detail:0")?.slots, ["appBar": "detail:1", "body": "detail:3"])
        XCTAssertEqual(stage.model.resolve("detail:1")?.slots, ["title": "detail:2"])
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))
        // The Scaffold draws its body as nodes and its bar as the navigation
        // bar, which it reads through the slots: the title is found.
        XCTAssertEqual(stage.model.resolve("detail:2")?["data"], "Title")
        XCTAssertEqual(
            stage.drawn.filter { $0.hasPrefix("detail:") }.sorted(),
            ["detail:0", "detail:3", "detail:4", "detail:5", "detail:6", "detail:7"])
    }

    func test_B13_4_whileTheFirstFetchRunsTheChildIsDrawnElseASpinner() throws {
        let stub = SubPagePages()
        stub.hold()
        let stage = try Stage(stub, subPage: ["pageId": "a"], loadingChild: true)
        defer { stage.close() }
        stage.wait("the fetch") { stub.pagePaths == ["a"] }
        XCTAssertEqual(stage.drawing, .child("loading"))
        XCTAssertTrue(stage.drawn.contains("loading"))

        stub.release()
        stage.wait("the page") { stage.drawn.contains("detail:7") }
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))

        let held = SubPagePages()
        held.hold()
        let bare = try Stage(held, subPage: ["pageId": "a"])
        defer { bare.close() }
        bare.wait("the fetch") { held.pagePaths == ["a"] }
        XCTAssertEqual(bare.drawing, .spinner)
        held.release()
    }

    func test_B13_4_aFetchThatFailsDrawsTheSubPageErrorText() throws {
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "missing"])
        defer { stage.close() }
        stage.wait("the error") { stage.drawing != .spinner }

        guard case .error(let text)? = stage.drawing else { return XCTFail("drew \(String(describing: stage.drawing))") }
        let failure = OrcaClientError.http(status: 404, body: "{}")
        XCTAssertEqual(text, "SubPage error: \(failure.localizedDescription)")
        XCTAssertEqual(stage.model.subPages.prefixes, [])
    }

    // MARK: B13.4 state

    func test_B13_4_theSubPagesInitialStateIsSeenByItsOwnNodesAndDoesNotClashWithTheHosts() throws {
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("the sub-page") { stage.model.renderer.nodes["detail:0"] != nil }

        XCTAssertEqual(stage.model.store.state.page, ["count": 1, "detail:count": 5])
        XCTAssertEqual(stage.model.resolve("detail:4")?["data"], 5)
        XCTAssertEqual(stage.model.resolve("h")?["data"], 1)
        XCTAssertEqual(stage.model.watches(of: "detail:4"), ["detail:count"])
    }

    func test_B13_4_aSetStateInsideWritesThePrefixedKey() throws {
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("the sub-page") { stage.model.renderer.nodes["detail:0"] != nil }

        try stage.tap("detail:5")
        stage.wait("the write") { stage.model.store.state.page["detail:count"] == 7 }
        XCTAssertEqual(stage.model.store.state.page["count"], 1)
        XCTAssertEqual(stage.model.resolve("detail:4")?["data"], 7)
    }

    // MARK: B13.4 server actions

    func test_B13_4_aServerActionFiredInsidePostsOnlyTheSubPagesKeysAndItsSetStateLandsUnderThePrefix() throws {
        let stub = SubPagePages(actions: [
            ["type": "setState", "key": "count", "scope": "page", "value": 6],
        ])
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("the sub-page") { stage.model.renderer.nodes["detail:0"] != nil }

        try stage.tap("detail:6")
        stage.wait("the answer") { stage.model.store.state.page["detail:count"] == 6 }
        XCTAssertEqual(stub.actionBodies.last?["pageState"], ["count": 5])
        XCTAssertEqual(stage.model.store.state.page["count"], 1, "the host's key was written")

        // A host node's server action posts the whole page state.
        try stage.tap("save")
        stage.wait("the host's answer") { stage.model.store.state.page["count"] == 6 }
        XCTAssertEqual(stub.actionBodies.last?["pageState"], ["count": 1, "detail:count": 6])
    }

    func test_B13_4_aComponentMutationReturnedForASubPageNodeChangesIt() throws {
        let stub = SubPagePages(actions: [
            ["type": "updateComponent", "id": "7", "props": ["data": "changed"]],
        ])
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("the sub-page") { stage.model.renderer.nodes["detail:0"] != nil }

        try stage.tap("detail:6")
        stage.wait("the mutation") { stage.model.resolve("detail:7")?["data"] == "changed" }
        XCTAssertEqual(stage.model.resolve("h")?["data"], 1)
    }

    // MARK: B13.5 updateSubPage

    func test_B13_5_aReplaceToAnotherPageSticksAfterARedrawAndRemovesTheOldNodesAndState() throws {
        let stub = SubPagePages()
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }

        try stage.tap("replace")
        stage.wait("page b") { stage.model.renderer.nodes["detail:1"]?.props["data"] == "B" }
        XCTAssertEqual(stage.model.renderer.nodes.keys.filter { $0.hasPrefix("detail:") }.sorted(), ["detail:0", "detail:1", "detail:2"])
        XCTAssertEqual(stage.model.store.state.page, ["count": 1, "detail:name": "b"])
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))

        // The host redraws: the first page does not come back.
        stage.model.store.dispatch(["count": 2])
        stage.pump(0.3)
        XCTAssertEqual(stage.model.resolve("h")?["data"], 2)
        XCTAssertEqual(stage.model.renderer.nodes["detail:1"]?.props["data"], "B")
        XCTAssertEqual(stub.pagePaths, ["a", "b?from=host"])
    }

    func test_B13_5_aJoinDrawsBothTreesInOrderEachWithItsOwnState() throws {
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }
        try stage.tap("detail:5")

        try stage.tap("join")
        stage.wait("page c") { stage.drawn.contains("detail#1:1") }
        XCTAssertEqual(stage.drawing, .pages(["detail:0", "detail#1:0"]))
        XCTAssertEqual(stage.model.subPages.prefixes, ["detail:", "detail#1:"])
        XCTAssertEqual(stage.model.store.state.page, ["count": 1, "detail:count": 7, "detail#1:count": 3])
        XCTAssertEqual(stage.model.resolve("detail:4")?["data"], 7)
        XCTAssertEqual(stage.model.resolve("detail#1:1")?["data"], 3)
        XCTAssertNotNil(stage.model.renderer.nodes["detail:7"], "the join removed the first page")
    }

    func test_B13_5_anUnknownSubPageIdDoesNothing() throws {
        let stub = SubPagePages()
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }
        var effects: [ActionEffect] = []
        stage.model.onEffect = { effects.append($0) }
        let before = stage.model.renderer.nodes

        let done = try XCTUnwrap(stage.tap("unknown"))
        stage.wait("the action") { stage.model.store.state.page["after"] == true }
        _ = done
        XCTAssertEqual(stub.pagePaths, ["a"], "an unknown subPageId fetched")
        XCTAssertEqual(stage.model.renderer.nodes, before)
        XCTAssertEqual(effects, [])
        XCTAssertEqual(stage.errors, 0)
    }

    func test_B13_5_anUpdateThatFailsLeavesTheContentAndRunsOnError() throws {
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }

        try stage.tap("broken")
        stage.wait("onError") { stage.model.store.state.page["failed"] == true }
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))
        XCTAssertNotNil(stage.model.renderer.nodes["detail:7"])
        XCTAssertEqual(stage.model.store.state.page["detail:count"], 5)
    }

    // MARK: B13.4 unmount, nesting, frozen layers

    func test_B13_4_whenTheSubPageNodeGoesItsNodesAreRemovedAndItsStateKeysStay() throws {
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }

        try stage.tap("remove")
        stage.wait("the unmount") { !stage.model.renderer.nodes.keys.contains { $0.hasPrefix("detail") } }
        XCTAssertEqual(stage.model.subPages.prefixes, [])
        XCTAssertEqual(stage.model.store.state.page["detail:count"], 5)
        XCTAssertNil(stage.model.subPageView("detail"))
    }

    func test_B13_4_aNestedSubPageMountsUnderTheComposedPrefix() throws {
        let stub = SubPagePages(actions: [["type": "setState", "key": "name", "scope": "page", "value": "x"]])
        let stage = try Stage(stub, subPage: ["pageId": "nest"], key: "outer")
        defer { stage.close() }
        stage.wait("the inner page") { stage.drawn.contains("outer:inner:1") }

        XCTAssertEqual(stage.model.subPages.prefixes, ["outer:", "outer:inner:"])
        XCTAssertEqual(stage.model.renderer.nodes["outer:inner"]?.type, "SubPage")
        XCTAssertEqual(stage.model.store.state.page["outer:inner:name"], "b")
        XCTAssertEqual(stub.pagePaths, ["nest", "b"])

        // The longest prefix is the inner page's.
        try stage.tap("outer:inner:2")
        stage.wait("the answer") { stage.model.store.state.page["outer:inner:name"] == "x" }
        XCTAssertEqual(stub.actionBodies.last?["pageState"], ["name": "b"])
    }

    func test_B13_4_anInertLayerFetchesNothingAndDrawsWhatWasMounted() throws {
        let stub = SubPagePages()
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.drawn.contains("detail:7") }

        let snapshot = try XCTUnwrap(stage.recorder.snapshot(
            of: "root", state: stage.model.store.state, subPages: stage.model.subPages))
        let frozen = OrcaPageModel(snapshot: snapshot, of: stage.model)
        XCTAssertTrue(frozen.isInert)
        let recorder = NodeRecorder()
        let window = HostWindow(NodeView(id: "root", model: frozen).environment(\.orcaNodeRecorder, recorder))
        defer { window.close() }
        stage.pump(0.5)

        XCTAssertEqual(stub.pagePaths, ["a"], "a frozen layer fetched")
        XCTAssertEqual(frozen.subPages.prefixes, [])
        XCTAssertNotNil(frozen.resolve("detail:7"), "the frozen page lost the mounted nodes")
        XCTAssertEqual(SubPageNodeView.frozenRoots(of: "detail", in: frozen), ["detail:0"])
    }

    // MARK: Pages

    /// A page-state reference.
    nonisolated static func page(_ key: String) -> JSONValue { ["type": "state", "scope": "page", "key": .string(key)] }

    nonisolated static func text(_ id: String, _ data: JSONValue, watches: [JSONValue] = [], onTap: JSONValue? = nil)
        -> JSONValue {
        var node: [String: JSONValue] = [
            "id": .string(id), "type": "Text", "kind": "primitive", "childMode": "none",
            "props": ["data": data], "children": [], "watches": .array(watches),
        ]
        if let onTap { node["actions"] = ["onTap": onTap] }
        return .object(node)
    }

    nonisolated static func column(_ id: String, _ children: [JSONValue]) -> JSONValue {
        ["id": .string(id), "type": "Column", "kind": "layout", "childMode": "multi", "props": [:],
         "children": .array(children), "watches": []]
    }

    nonisolated static func count(_ initial: JSONValue, key: String = "count") -> JSONValue {
        ["key": .string(key), "scope": "page", "initial": initial]
    }

    /// The pages the stub serves, by page id.
    nonisolated static let pages: [String: JSONValue] = [
        // Scaffold(appBar: AppBar(title), body: Column[count, set, bump, "A"])
        "a": [
            "pageId": "a", "title": "A", "state": [count(5)],
            "components": [
                ["id": "0", "type": "Scaffold", "kind": "structure", "childMode": "none",
                 "props": ["appBar": "1", "body": "3"], "children": ["1", "3"], "watches": []],
                ["id": "1", "type": "AppBar", "kind": "structure", "childMode": "none",
                 "props": ["title": "2"], "children": ["2"], "watches": []],
                text("2", "Title"),
                column("3", ["4", "5", "6", "7"]),
                text("4", page("count"), watches: ["count"]),
                text("5", "set", onTap: ["type": "setState", "key": "count", "scope": "page", "value": 7]),
                text("6", "bump", onTap: ["type": "serverAction", "id": "bump"]),
                text("7", "A"),
            ],
        ],
        "b": [
            "pageId": "b", "title": "B", "state": [count("b", key: "name")],
            "components": [
                column("0", ["1", "2"]),
                text("1", "B"),
                text("2", "rename", onTap: ["type": "serverAction", "id": "bump"]),
            ],
        ],
        "c": [
            "pageId": "c", "title": "C", "state": [count(3)],
            "components": [column("0", ["1"]), text("1", page("count"), watches: ["count"])],
        ],
        "nest": [
            "pageId": "nest", "title": "Nest", "state": [],
            "components": [
                column("0", ["inner"]),
                ["id": "inner", "type": "SubPage", "kind": "layout", "childMode": "single",
                 "props": ["pageId": "b"], "children": [], "watches": []],
            ],
        ],
    ]

    /// The host page: a count of its own, the SubPage, and the buttons the
    /// tests tap.
    nonisolated static func host(key: String, subPage props: JSONValue, watches: [JSONValue], state: [String: JSONValue],
                     loadingChild: Bool) -> JSONValue {
        func update(_ pageId: String, mode: String? = nil, subPageId: String? = nil) -> JSONValue {
            var action: [String: JSONValue] = [
                "type": "updateSubPage", "subPageId": .string(subPageId ?? key), "pageId": .string(pageId),
                "params": ["from": "host"],
            ]
            if let mode { action["mode"] = .string(mode) }
            return .object(action)
        }
        var definitions = [count(1)]
        for (name, value) in state { definitions.append(count(value, key: name)) }
        var nodes: [JSONValue] = [
            column("root", ["h", .string(key), "replace", "join", "unknown", "broken", "remove", "save"]),
            text("h", page("count"), watches: ["count"]),
            ["id": .string(key), "type": "SubPage", "kind": "layout", "childMode": "single", "props": props,
             "children": loadingChild ? ["loading"] : [], "watches": .array(watches)],
            text("replace", "replace", onTap: update("b")),
            text("join", "join", onTap: ["type": "updateSubPage", "subPageId": .string(key), "pageId": "c",
                                         "mode": "join"]),
            text("unknown", "unknown", onTap: ["type": "actionGroup", "mode": "sequential", "actions": [
                update("b", subPageId: "nope"),
                ["type": "setState", "key": "after", "scope": "page", "value": true],
            ]]),
            text("broken", "broken", onTap: [
                "type": "lifecycle", "action": update("missing"),
                "onError": [["type": "setState", "key": "failed", "scope": "page", "value": true]],
            ]),
            text("remove", "remove", onTap: ["type": "deleteComponent", "id": .string(key)]),
            text("save", "save", onTap: ["type": "serverAction", "id": "save"]),
        ]
        if loadingChild { nodes.append(text("loading", "Loading")) }
        return ["pageId": "host", "title": "Host", "state": .array(definitions), "components": .array(nodes)]
    }
}

/// The host page on screen, with the stub behind it.
@MainActor
private final class Stage {
    let model: OrcaPageModel
    let recorder = NodeRecorder()
    let key: String
    private(set) var errors = 0
    private var window: HostWindow?

    init(_ stub: SubPagePages, subPage props: JSONValue, key: String = "detail", watches: [JSONValue] = [],
         state: [String: JSONValue] = [:], app: [String: JSONValue] = [:], loadingChild: Bool = false) throws {
        let page = try SubPageTests.host(
            key: key, subPage: props, watches: watches, state: state, loadingChild: loadingChild)
            .decode(PageResponse.self)
        self.key = key
        model = OrcaPageModel(page: page, store: ElmStore(app: app), client: OrcaClient(
            baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
            device: DeviceInfo(osVersion: "test"), transport: stub))
        model.onError = { [weak self] _ in self?.errors += 1 }
        window = HostWindow(NodeView(id: "root", model: model).environment(\.orcaNodeRecorder, recorder))
    }

    /// What the SubPage draws now; nil when it is not on screen.
    var drawing: SubPageDrawing? {
        guard let node = model.resolve(key) else { return nil }
        return model.subPageView(key)?.drawing(childId: node.childIds.first)
    }

    /// Ids of the nodes drawn so far from the root down, mounted pages included.
    var drawn: Set<String> {
        let snapshot = recorder.snapshot(of: "root", state: model.store.state, subPages: model.subPages)
        return Set((snapshot?.nodes ?? [:]).keys)
    }

    /// Fire the node's onTap, as a tap does.
    @discardableResult
    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws -> Task<Void, Never>? {
        let node = try XCTUnwrap(model.resolve(id), "no node \(id)", file: file, line: line)
        return model.fire("onTap", on: node)
    }

    func pump(_ seconds: Double = 0.05) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Let SwiftUI draw and the fetches answer until `done`.
    func wait(_ what: String, file: StaticString = #filePath, line: UInt = #line, until done: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !done(), Date() < deadline { pump(0.02) }
        if !done() { XCTFail("timed out waiting for \(what)", file: file, line: line) }
    }

    func close() {
        window?.close()
        window = nil
    }
}

/// A view in a real window (UIKit or AppKit), kept on screen until `close`.
@MainActor
private final class HostWindow {
    #if canImport(UIKit)
    private let window: UIWindow
    #elseif canImport(AppKit)
    private let window: NSWindow
    #endif

    init<V: View>(_ content: V) {
        let size = CGRect(x: 0, y: 0, width: 320, height: 600)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: content)
        window = UIWindow(frame: size)
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = size
        host.view.layoutIfNeeded()
        #elseif canImport(AppKit)
        window = NSWindow(contentRect: size, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: content)
        host.frame = size
        window.contentView = host
        window.orderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        #endif
    }

    func close() {
        #if canImport(UIKit)
        window.isHidden = true
        window.rootViewController = nil
        #elseif canImport(AppKit)
        window.orderOut(nil)
        window.contentView = nil
        #endif
    }
}

/// The page route and the `/action` route: `SubPageTests.pages` by page id
/// (any other id is a 404), every `/action` answered with `actions`. Page
/// fetches wait while the stub is held.
private final class SubPagePages: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private var held = false
    private let actions: [JSONValue]

    init(actions: [JSONValue] = []) { self.actions = actions }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var requests: [HTTPRequest] { locked { _requests } }

    /// Each page fetch as `path` or `path?query`, in order.
    var pagePaths: [String] {
        requests.compactMap { request in
            let text = request.url.absoluteString
            return text.range(of: "/page/").map { String(text[$0.upperBound...]) }
        }
    }

    /// The body of each `/action` call, in order.
    var actionBodies: [JSONValue] {
        requests.filter { $0.url.path.hasSuffix("/action") }
            .compactMap { $0.body.flatMap { try? JSONValue.decode($0) } }
    }

    func hold() { locked { held = true } }
    func release() { locked { held = false } }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        locked { _requests.append(request) }
        if request.url.path.hasSuffix("/action") {
            let id = (try JSONValue.decode(request.body ?? Data()))["action"].stringValue
            // The host's `save` writes the host's count.
            let answer: [JSONValue] = id == "save"
                ? [["type": "setState", "key": "count", "scope": "page", "value": 6]] : actions
            return HTTPResponse(status: 200, body: try JSONValue.object(["actions": .array(answer)]).encoded())
        }
        while locked({ held }) { try await Task.sleep(nanoseconds: 10_000_000) }
        let name = request.url.path.components(separatedBy: "/page/").last ?? ""
        guard let page = SubPageTests.pages[name] else { return HTTPResponse(status: 404, body: Data("{}".utf8)) }
        return HTTPResponse(status: 200, body: try page.encoded())
    }
}
#endif
