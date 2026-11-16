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
        // The message Kotlin draws (Flutter prints its exception: the same
        // text after `OrcaClientException(404): `).
        XCTAssertEqual(text, "SubPage error: Failed to fetch page: 404")
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

    func test_B13_5_anUpdateDuringTheFirstFetchWinsAndTheLateFirstAnswerIsDropped() throws {
        let stub = SubPagePages()
        stub.hold("a")
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("the first fetch") { stub.pagePaths == ["a"] }

        try stage.tap("replace")
        stage.wait("page b") { stage.model.renderer.nodes["detail:1"]?.props["data"] == "B" }
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))

        stub.release()
        stage.wait("the late answer") { stub.answered == ["b", "a"] }
        stage.pump(0.3)
        XCTAssertEqual(stage.model.renderer.nodes["detail:1"]?.props["data"], "B", "the late first answer was mounted")
        XCTAssertNil(stage.model.renderer.nodes["detail:7"])
        XCTAssertEqual(stage.model.store.state.page, ["count": 1, "detail:name": "b"])
        XCTAssertEqual(stub.pagePaths, ["a", "b?from=host"])
    }

    /// A page that replaces another gets fresh UI state, even with the same
    /// node ids: the AnimatedBuilder of the new page has a controller of its
    /// own under the id, and the old one leaving does not take that
    /// registration away. A join keeps what is drawn.
    func test_B13_5_aReplacedPageGetsFreshUIStateAndAJoinKeepsIt() throws {
        let stub = SubPagePages()
        let stage = try Stage(stub, subPage: ["pageId": "anim"])
        defer { stage.close() }
        let animations = stage.model.animations
        func now() -> Double { stage.model.frameClock() }
        func progress(_ id: String = "detail:spin") -> Double { animations.progress(id: id, at: now()) }

        stage.wait("the builder") { animations.forward(id: "detail:spin", at: now()) }
        XCTAssertFalse(animations.forward(id: "spin", at: now()), "the id was registered without the prefix")
        stage.wait("the run") { progress() == 1 }

        // The same page again: every id is the same.
        try stage.run(Self.update("detail", "anim"))
        stage.wait("the second fetch") { stub.answered == ["anim", "anim"] }
        stage.wait("a controller of its own") { progress() == 0 }
        // Time for the old page's views to be torn down.
        stage.pump(0.3)
        XCTAssertTrue(animations.forward(id: "detail:spin", at: now()), "the old builder took the new one's id with it")
        stage.wait("the new run") { progress() == 1 }

        try stage.run(Self.update("detail", "anim", mode: "join"))
        stage.wait("the joined builder") { animations.forward(id: "detail#1:spin", at: now()) }
        stage.pump(0.3)
        XCTAssertEqual(progress(), 1, "a join rebuilt the first page")
        XCTAssertEqual(stub.pagePaths, ["anim", "anim", "anim"])
    }

    /// S5: joined pages are one below the other, each as wide as the SubPage;
    /// a single page is drawn exactly as its root.
    func test_B13_5_joinedPagesAreDrawnOneBelowTheOtherAtFullWidth() throws {
        let frames = ProbeFrames()
        let widgets = WidgetBuilders()
        widgets.register("Probe") { node, _ in
            AnyView(Probe(id: node.id, width: CGFloat(node["width"]?.intValue ?? 0), frames: frames))
        }
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "probe"], widgets: widgets)
        defer { stage.close() }
        stage.wait("the page") { frames["detail:0"] != nil }
        stage.pump(0.2)
        XCTAssertEqual(frames["detail:0"]?.width, 40, "a single page was not drawn as its root")

        try stage.run(Self.update("detail", "wide", mode: "join"))
        stage.wait("the joined page") { frames["detail#1:0"] != nil }
        stage.pump(0.2)
        let first = try XCTUnwrap(frames["detail:0"])
        let second = try XCTUnwrap(frames["detail#1:0"])
        XCTAssertEqual(stage.drawing, .pages(["detail:0", "detail#1:0"]))
        // The SubPage is offered the window's width, whatever its pages'
        // own widths (40 and 120) are.
        let width = stage.width
        XCTAssertEqual([first.minX, second.minX], [0, 0])
        XCTAssertEqual([first.width, second.width], [width, width], "a joined page is not as wide as the SubPage")
        XCTAssertEqual(second.minY, first.maxY, "the joined page is not right below the first")
    }

    /// A node added to a sub-page after its mount (addComponent) leaves with
    /// the page: on a replace and when the SubPage node goes.
    func test_B13_5_aNodeAddedInsideLeavesWithItsPage() throws {
        let add: [JSONValue] = [["type": "addComponent", "parentId": "3", "components": [Self.text("note", "Note")]]]
        func mounted(_ stage: Stage) -> [String] {
            stage.model.renderer.nodes.keys.filter { $0.hasPrefix("detail:") }.sorted()
        }

        let stage = try Stage(SubPagePages(actions: add), subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }
        try stage.tap("detail:6")
        stage.wait("the note") { stage.model.renderer.nodes["detail:note"] != nil }
        XCTAssertEqual(stage.model.renderer.nodes["detail:3"]?.children.last, "detail:note")
        try stage.tap("replace")
        stage.wait("page b") { stage.model.renderer.nodes["detail:1"]?.props["data"] == "B" }
        XCTAssertEqual(mounted(stage), ["detail:0", "detail:1", "detail:2"])

        let other = try Stage(SubPagePages(actions: add), subPage: ["pageId": "a"])
        defer { other.close() }
        other.wait("page a") { other.model.renderer.nodes["detail:7"] != nil }
        try other.tap("detail:6")
        other.wait("the note") { other.model.renderer.nodes["detail:note"] != nil }
        try other.tap("remove")
        other.wait("the unmount") { other.model.subPages.prefixes.isEmpty }
        XCTAssertEqual(other.model.renderer.nodes.keys.filter { $0.hasPrefix("detail") }, [])
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

    /// A page replaced by one with the same nested SubPage: the nested one
    /// is mounted anew, once, with the state its page starts with.
    func test_B13_5_aNestedSubPageOfAReplacedPageIsMountedAnew() throws {
        let stub = SubPagePages(actions: [["type": "setState", "key": "name", "scope": "page", "value": "x"]])
        let stage = try Stage(stub, subPage: ["pageId": "nest"], key: "outer")
        defer { stage.close() }
        stage.wait("the inner page") { stage.drawn.contains("outer:inner:1") }
        try stage.tap("outer:inner:2")
        stage.wait("the answer") { stage.model.store.state.page["outer:inner:name"] == "x" }

        try stage.run(Self.update("outer", "nest"))
        stage.wait("the inner page, again") { stub.answered == ["nest", "b", "nest", "b"] }
        stage.wait("its state") { stage.model.store.state.page["outer:inner:name"] == "b" }
        stage.pump(0.3)
        XCTAssertEqual(stub.pagePaths, ["nest", "b", "nest", "b"])
        XCTAssertEqual(stage.model.subPages.prefixes, ["outer:", "outer:inner:"])
        XCTAssertEqual(stage.model.store.state.page, ["count": 1, "outer:inner:name": "b"])
        XCTAssertEqual(
            stage.model.renderer.nodes.keys.filter { $0.hasPrefix("outer:") }.sorted(),
            ["outer:0", "outer:inner", "outer:inner:0", "outer:inner:1", "outer:inner:2"])
        XCTAssertNotNil(stage.model.subPageView("outer:inner"))

        // The new inner page answers to its own server action.
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

    // MARK: the SubPage follows its node, not its view

    /// S7, S8: the pages belong to the SubPage node. A view of it that is
    /// taken down and built again (the host page covered by a push and shown
    /// again) fetches nothing, even a fetch that would now fail, and draws
    /// what an earlier updateSubPage mounted.
    func test_B13_5_hidingAndShowingTheHostAgainFetchesNothingAndKeepsTheMounts() throws {
        let stub = SubPagePages()
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }
        try stage.tap("replace")
        stage.wait("page b") { stage.model.renderer.nodes["detail:1"]?.props["data"] == "B" }
        stage.model.store.dispatch(["detail:name": "mine"])
        let mounted = stage.model.subPages

        stage.hide()
        stage.pump(0.3)
        XCTAssertEqual(stage.model.subPages, mounted, "hiding the host unmounted the sub-page")
        XCTAssertEqual(stage.model.renderer.nodes["detail:1"]?.props["data"], "B")

        // Any fetch from here on fails: a view that fetched again would draw the error.
        stub.breakPages()
        stage.show()
        stage.pump(0.5)
        XCTAssertEqual(stub.pagePaths, ["a", "b?from=host"], "the view built again fetched")
        XCTAssertEqual(stage.model.subPages, mounted)
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))
        XCTAssertEqual(stage.model.renderer.nodes["detail:1"]?.props["data"], "B", "the first page came back")
        XCTAssertEqual(stage.model.store.state.page, ["count": 1, "detail:name": "mine"])
    }

    /// S8 follows the node: with no view showing the SubPage, its pages stay
    /// until its node is deleted, and go then.
    func test_B13_4_aSubPageWhoseNodeIsDeletedWhileNoViewShowsItIsUnmounted() throws {
        let stage = try Stage(SubPagePages(), subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.model.renderer.nodes["detail:7"] != nil }

        stage.hide()
        stage.pump(0.3)
        XCTAssertEqual(stage.model.subPages.prefixes, ["detail:"], "the view leaving unmounted the sub-page")
        XCTAssertNotNil(stage.model.renderer.nodes["detail:7"])

        try stage.tap("remove")
        stage.wait("the unmount") { stage.model.subPages.prefixes.isEmpty }
        XCTAssertEqual(stage.model.renderer.nodes.keys.filter { $0.hasPrefix("detail") }, [])
        XCTAssertEqual(stage.model.store.state.page["detail:count"], 5)
        XCTAssertNil(stage.model.subPageView("detail"))
    }

    #if canImport(UIKit)
    /// A ReorderableListView gives its rows a new identity on every drop, so
    /// the SubPage in a row gets a new view: its pages, their state and an
    /// earlier updateSubPage are kept, and nothing is fetched.
    func test_B13_5_aSubPageInAReorderableRowKeepsItsPagesItsStateAndAnUpdateAcrossADrop() throws {
        func box(_ id: String, _ height: JSONValue) -> JSONValue {
            ["id": .string(id), "type": "SizedBox", "kind": "layout", "childMode": "single",
             "props": ["width": 20, "height": height], "children": [], "watches": []]
        }
        let page: JSONValue = [
            "pageId": "host", "title": "Host", "state": [Self.count(0, key: "moves")],
            "components": [
                ["id": "list", "type": "ReorderableListView", "kind": "layout", "childMode": "multi", "props": [:],
                 "children": ["detail", "x", "y"], "watches": [],
                 "actions": ["onReorder": ["type": "setState", "key": "moves", "scope": "page", "value": 1]]],
                ["id": "detail", "type": "SubPage", "kind": "layout", "childMode": "single",
                 "props": ["pageId": "b"], "children": [], "watches": []],
                box("x", 100), box("y", 110),
            ],
        ]
        let stub = SubPagePages()
        let stage = try Stage(stub, page: page, root: "list")
        defer { stage.close() }
        stage.wait("page b") { stage.model.renderer.nodes["detail:1"] != nil }
        try stage.run(Self.update("detail", "c"))
        stage.wait("page c") { stage.model.store.state.page["detail:count"] == 3 }
        stage.model.store.dispatch(["detail:count": 9])
        stage.pump(0.3)
        let mounted = stage.model.subPages

        let list = try XCTUnwrap(stage.collectionView)
        XCTAssertTrue(list.beginInteractiveMovementForItem(at: IndexPath(item: 0, section: 0)))
        stage.pump(0.1)
        list.updateInteractiveMovementTargetPosition(CGPoint(x: 100, y: list.contentSize.height - 10))
        stage.pump(0.3)
        list.endInteractiveMovement()
        stage.wait("the drop") { stage.model.store.state.page["moves"] == 1 }
        stage.pump(0.8)

        XCTAssertEqual(stub.pagePaths, ["b", "c"], "the row built again fetched")
        XCTAssertEqual(stage.model.subPages, mounted)
        XCTAssertEqual(stage.model.store.state.page, ["moves": 1, "detail:count": 9])
        XCTAssertEqual(stage.model.resolve("detail:1")?["data"], 9)
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))
    }
    #endif

    // MARK: fetches that are overtaken

    func test_B13_4_anAnswerForASubPageWhoseNodeLeftIsDropped() throws {
        let stub = SubPagePages()
        stub.hold()
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("the fetch") { stub.pagePaths == ["a"] }

        try stage.tap("remove")
        stage.wait("the delete") { stage.model.renderer.nodes["detail"] == nil }
        stub.release()
        stage.pump(0.5)
        XCTAssertEqual(stage.model.subPages.prefixes, [], "the answer was mounted after its SubPage left")
        XCTAssertEqual(stage.model.renderer.nodes.keys.filter { $0.hasPrefix("detail") }, [])
        XCTAssertEqual(stage.model.store.state.page, ["count": 1])
        XCTAssertNil(stage.model.subPageView("detail"))
    }

    func test_B13_4_aNewerOwnFetchOvertakesAnOlderOne() throws {
        let stub = SubPagePages()
        stub.hold("a")
        let stage = try Stage(
            stub, subPage: ["pageId": Self.page("which")], watches: ["which"], state: ["which": "a"])
        defer { stage.close() }
        stage.wait("the first fetch") { stub.pagePaths == ["a"] }

        stage.model.store.dispatch(["which": "b"])
        stage.wait("page b") { stage.model.renderer.nodes["detail:1"]?.props["data"] == "B" }
        stub.release()
        stage.pump(0.5)
        XCTAssertEqual(stage.model.renderer.nodes["detail:1"]?.props["data"], "B", "the older answer was mounted")
        XCTAssertNil(stage.model.renderer.nodes["detail:7"])
        XCTAssertEqual(stage.model.store.state.page, ["count": 1, "which": "b", "detail:name": "b"])
        XCTAssertEqual(stub.pagePaths, ["a", "b"])
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))
    }

    func test_B13_5_theOldContentStaysWhileAnUpdateFetches() throws {
        let stub = SubPagePages()
        let stage = try Stage(stub, subPage: ["pageId": "a"])
        defer { stage.close() }
        stage.wait("page a") { stage.drawn.contains("detail:7") }

        stub.hold("b")
        try stage.tap("replace")
        stage.wait("the update's fetch") { stub.pagePaths == ["a", "b?from=host"] }
        stage.pump(0.2)
        XCTAssertEqual(stage.drawing, .pages(["detail:0"]))
        XCTAssertEqual(stage.model.renderer.nodes["detail:7"]?.props["data"], "A")
        XCTAssertEqual(stage.model.store.state.page, ["count": 1, "detail:count": 5])

        stub.release()
        stage.wait("page b") { stage.model.renderer.nodes["detail:1"]?.props["data"] == "B" }
        XCTAssertNil(stage.model.renderer.nodes["detail:7"])
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

    /// An updateSubPage action.
    nonisolated static func update(_ subPageId: String, _ pageId: String, mode: String? = nil) -> JSONValue {
        var action: [String: JSONValue] = [
            "type": "updateSubPage", "subPageId": .string(subPageId), "pageId": .string(pageId),
        ]
        if let mode { action["mode"] = .string(mode) }
        return .object(action)
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
        // Column[label, AnimatedBuilder(spin, held at 0)[text]]
        "anim": [
            "pageId": "anim", "title": "Anim", "state": [],
            "components": [
                column("0", ["1", "2"]),
                text("1", "Anim"),
                ["id": "2", "type": "AnimatedBuilder", "kind": "layout", "childMode": "single",
                 "props": ["animationId": "spin", "autoStart": false, "duration": 100], "children": ["3"],
                 "watches": []],
                text("3", "Animated"),
            ],
        ],
        "probe": [
            "pageId": "probe", "title": "Probe", "state": [],
            "components": [
                ["id": "0", "type": "Probe", "kind": "primitive", "childMode": "none", "props": ["width": 40],
                 "children": [], "watches": []],
            ],
        ],
        "wide": [
            "pageId": "wide", "title": "Wide", "state": [],
            "components": [
                ["id": "0", "type": "Probe", "kind": "primitive", "childMode": "none", "props": ["width": 120],
                 "children": [], "watches": []],
            ],
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
    private let root: String
    private(set) var errors = 0
    private var window: HostWindow?

    convenience init(_ stub: SubPagePages, subPage props: JSONValue, key: String = "detail", watches: [JSONValue] = [],
                     state: [String: JSONValue] = [:], app: [String: JSONValue] = [:], loadingChild: Bool = false,
                     widgets: WidgetBuilders = WidgetBuilders()) throws {
        try self.init(
            stub,
            page: SubPageTests.host(
                key: key, subPage: props, watches: watches, state: state, loadingChild: loadingChild),
            key: key, app: app, widgets: widgets)
    }

    /// `page` drawn from its node `root`; `key` is its SubPage.
    init(_ stub: SubPagePages, page: JSONValue, root: String = "root", key: String = "detail",
         app: [String: JSONValue] = [:], widgets: WidgetBuilders = WidgetBuilders()) throws {
        self.key = key
        self.root = root
        model = OrcaPageModel(
            page: try page.decode(PageResponse.self), store: ElmStore(app: app),
            registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets).union(widgets.types)),
            client: OrcaClient(
                baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                device: DeviceInfo(osVersion: "test"), transport: stub),
            widgets: widgets)
        model.onError = { [weak self] _ in self?.errors += 1 }
        show()
    }

    /// Put the page on screen, with views of its own.
    func show() {
        window = HostWindow(NodeView(id: root, model: model).environment(\.orcaNodeRecorder, recorder))
    }

    /// Take the page's views down, as when another page covers it for good;
    /// the page itself stays.
    func hide() {
        close()
    }

    #if canImport(UIKit)
    /// The UICollectionView SwiftUI draws a List with.
    var collectionView: UICollectionView? { window?.collectionView }
    #endif

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

    /// Run an action of the host page, as a host node's trigger does.
    func run(_ action: JSONValue) throws {
        let action = try action.decode(Action.self)
        Task { await model.run(action) }
    }

    /// Width of the window's content.
    var width: CGFloat { window?.width ?? 0 }

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

/// Where each Probe was last laid out, in the window, by node id.
@MainActor
private final class ProbeFrames {
    private var frames: [String: CGRect] = [:]
    subscript(id: String) -> CGRect? { frames[id] }
    func set(_ id: String, _ frame: CGRect) { frames[id] = frame }
}

/// A host widget 20 high that is `width` wide, or as wide as its parent
/// forces (`orcaTight`), as a Container is.
private struct Probe: View {
    let id: String
    let width: CGFloat
    let frames: ProbeFrames
    @Environment(\.orcaTight) private var tight

    var body: some View {
        Color.red
            .frame(width: tight.contains(.horizontal) ? nil : width, height: 20)
            .background(GeometryReader { geometry in
                let _ = frames.set(id, geometry.frame(in: .global))
                Color.clear
            })
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

    #if canImport(UIKit)
    var collectionView: UICollectionView? {
        func find(in view: UIView) -> UICollectionView? {
            (view as? UICollectionView) ?? view.subviews.lazy.compactMap { find(in: $0) }.first
        }
        return find(in: window)
    }
    #endif

    var width: CGFloat {
        #if canImport(UIKit)
        window.bounds.width
        #elseif canImport(AppKit)
        window.contentView?.bounds.width ?? 0
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
    private var broken = false
    private var heldPages: Set<String> = []
    private var _answered: [String] = []
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

    /// The page ids answered so far, in the order of the answers.
    var answered: [String] { locked { _answered } }

    /// Page fetches wait from now on: all of them, or those of one page.
    func hold(_ page: String? = nil) {
        locked {
            if let page { heldPages.insert(page) } else { held = true }
        }
    }

    /// Every page fetch fails from now on, with a 500.
    func breakPages() { locked { broken = true } }

    func release() {
        locked {
            held = false
            heldPages = []
        }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        locked { _requests.append(request) }
        if request.url.path.hasSuffix("/action") {
            let id = (try JSONValue.decode(request.body ?? Data()))["action"].stringValue
            // The host's `save` writes the host's count.
            let answer: [JSONValue] = id == "save"
                ? [["type": "setState", "key": "count", "scope": "page", "value": 6]] : actions
            return HTTPResponse(status: 200, body: try JSONValue.object(["actions": .array(answer)]).encoded())
        }
        let name = request.url.path.components(separatedBy: "/page/").last ?? ""
        while locked({ held || heldPages.contains(name) }) { try await Task.sleep(nanoseconds: 10_000_000) }
        locked { _answered.append(name) }
        if locked({ broken }) { return HTTPResponse(status: 500, body: Data("{}".utf8)) }
        guard let page = SubPageTests.pages[name] else { return HTTPResponse(status: 404, body: Data("{}".utf8)) }
        return HTTPResponse(status: 200, body: try page.encoded())
    }
}
#endif
