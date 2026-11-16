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

/// A5.5: Flutter's `PullToRefresh` (layout_builders.dart:372-393) is a
/// RefreshIndicator over the scroll view directly inside it (depth-0
/// notifications, refresh_indicator.dart:461-475): a pull at its top runs
/// onRefresh and the spinner turns until that action ends (:634-639); a
/// horizontal scroll view never starts it, nor does one nested inside the
/// first. Here the vertical scroll kinds directly inside a PullToRefresh
/// get iOS's refresh control (SwiftUI `refreshable`), read from the
/// UIScrollView each is hosted with; the pull itself is the hand check,
/// the control's valueChanged actions stand in for it.
@MainActor
final class RefreshTests: XCTestCase {
    /// The four kinds drawn with a scroll view (PageView not snapping).
    static let kinds = ["SingleChildScrollView", "ListView", "GridView", "PageView"]

    #if canImport(UIKit)
    /// A5.5: each kind directly inside a PullToRefresh has a refresh
    /// control; without one, none.
    func testA5_5PullToRefreshGivesTheVerticalScrollViewInsideARefreshControl() throws {
        for type in Self.kinds {
            for wrapped in [true, false] {
                let nodes = scrolling(type, "s", horizontal: false)
                let hosted = try HostedPull(wrapped ? [pull(["s"])] + nodes : nodes)
                defer { hosted.close() }
                let views = hosted.scrollViews
                XCTAssertEqual(views.count, 1, "\(type) wrapped \(wrapped)")
                let scroll = try XCTUnwrap(views.first, "no UIScrollView: \(type) wrapped \(wrapped)")
                XCTAssertEqual(scroll.refreshControl != nil, wrapped, "\(type) wrapped \(wrapped)")
            }
        }
    }

    /// A5.5: widgets that do not scroll between the PullToRefresh and the
    /// scroll view leave it the one refreshed (still Flutter's depth 0).
    func testA5_5PullToRefreshReachesItsScrollViewThroughWidgetsThatDoNotScroll() throws {
        let hosted = try HostedPull([
            pull(["pad"]),
            node("pad", "Padding", ["padding": ["top": 4, "right": 4, "bottom": 4, "left": 4]], ["center"]),
            node("center", "Center", [:], ["s"]),
        ] + scrolling("ListView", "s", horizontal: false))
        defer { hosted.close() }
        let scroll = try XCTUnwrap(hosted.scrollViews.first, "no UIScrollView")
        XCTAssertNotNil(scroll.refreshControl)
    }

    /// A5.5: the control's pull runs onRefresh, on each kind, and the
    /// spinner stops once it has run.
    func testA5_5ThePullRunsOnRefresh() throws {
        for type in Self.kinds {
            let hosted = try HostedPull([pull(["s"], onRefresh: count("pulls"))]
                + scrolling(type, "s", horizontal: false), keys: ["pulls"])
            defer { hosted.close() }
            let control = try XCTUnwrap(hosted.scrollViews.first?.refreshControl, "no refresh control: \(type)")
            HostedPull.pulled(control)
            hosted.pump(0.5)
            XCTAssertEqual(hosted.value("pulls"), 1, type)
            XCTAssertFalse(control.isRefreshing, "\(type): onRefresh has ended")
        }
    }

    /// A5.5: the spinner turns for as long as onRefresh runs (Flutter awaits
    /// the action): a refetchPage held by its handler keeps it refreshing,
    /// and it ends when the handler returns.
    func testA5_5TheSpinnerTurnsUntilOnRefreshEnds() throws {
        let hosted = try HostedPull([pull(["s"], onRefresh: ["type": "refetchPage"])]
            + scrolling("ListView", "s", horizontal: false))
        defer { hosted.close() }
        let gate = Gate()
        hosted.model.onRefetchPage = { await gate.wait() }
        let control = try XCTUnwrap(hosted.scrollViews.first?.refreshControl, "no refresh control")
        HostedPull.pulled(control)
        hosted.pump(0.5)
        XCTAssertEqual(gate.waits, 1, "onRefresh has started")
        XCTAssertTrue(control.isRefreshing, "onRefresh still runs")
        hosted.pump(1)
        XCTAssertTrue(control.isRefreshing, "onRefresh still runs")

        gate.open()
        hosted.pump(0.5)
        XCTAssertFalse(control.isRefreshing, "onRefresh has ended")
    }

    /// A5.5: with no onRefresh the control is there and its spinner stops
    /// at once (Flutter's onRefresh completes at once).
    func testA5_5WithoutOnRefreshTheSpinnerStopsAtOnce() throws {
        let hosted = try HostedPull([pull(["s"])] + scrolling("ListView", "s", horizontal: false))
        defer { hosted.close() }
        let control = try XCTUnwrap(hosted.scrollViews.first?.refreshControl, "no refresh control")
        HostedPull.pulled(control)
        hosted.pump(0.5)
        XCTAssertFalse(control.isRefreshing)
    }

    /// A5.5: a horizontal scroll view directly inside a PullToRefresh gets
    /// no refresh control, nor does a vertical one inside it (Flutter's
    /// depth 1).
    func testA5_5AHorizontalScrollViewGetsNoRefreshControlNorDoesOneInsideIt() throws {
        for type in Self.kinds {
            let hosted = try HostedPull([pull(["s"])]
                + scrolling(type, "s", horizontal: true, holding: scrolling(type, "n", horizontal: false)))
            defer { hosted.close() }
            let views = hosted.scrollViews
            XCTAssertEqual(views.count, 2, "\(type): the outer and the nested scroll view")
            for (index, scroll) in views.enumerated() {
                XCTAssertNil(scroll.refreshControl, "\(type) scroll view \(index)")
            }
        }
    }

    /// A5.5: a scroll view nested inside the one refreshed does not start
    /// the refresh (Flutter's depth 1), across or along the same axis.
    func testA5_5AScrollViewNestedInsideTheRefreshedOneGetsNoRefreshControl() throws {
        for type in Self.kinds {
            for across in [true, false] {
                let hosted = try HostedPull([pull(["s"])]
                    + scrolling(type, "s", horizontal: false, holding: scrolling(type, "n", horizontal: across)))
                defer { hosted.close() }
                let views = hosted.scrollViews
                XCTAssertEqual(views.count, 2, "\(type): the outer and the nested scroll view")
                guard views.count == 2 else { continue }
                XCTAssertNotNil(views[0].refreshControl, "\(type): the refreshed one")
                XCTAssertNil(views[1].refreshControl, "\(type) nested, horizontal \(across)")
            }
        }
    }

    /// A5.5: a snapping PageView has no UIScrollView, so it cannot be
    /// pulled (a known difference: Flutter refreshes a vertical one at its
    /// first page), and a list in one of its pages is nested, so it gets
    /// no control either.
    func testA5_5ASnappingPageViewIsNoScrollViewAndItsPagesListsGetNoRefreshControl() throws {
        let hosted = try HostedPull([
            pull(["pv"]),
            node("pv", "PageView", ["scrollDirection": "vertical"], ["s", "p1"]),
            node("p1", "SizedBox", ["width": 100, "height": 100]),
        ] + scrolling("ListView", "s", horizontal: false))
        defer { hosted.close() }
        let views = hosted.scrollViews
        XCTAssertEqual(views.count, 1, "only the page's list")
        XCTAssertNil(try XCTUnwrap(views.first, "no UIScrollView").refreshControl)
    }

    /// A5.5: a ListView or GridView with no limit on its scroll axis (a
    /// shrinkWrap one in a Column) is drawn without a scroll view, so it is
    /// not pulled, and a list inside it, set in a sized box, is nested, so
    /// it gets no control either (Flutter's depth 1).
    func testA5_5AListInAColumnIsNoScrollViewAndAListInsideItGetsNoRefreshControl() throws {
        for type in ["ListView", "GridView"] {
            let hosted = try HostedPull([pull(["col"]), node("col", "Column", [:], ["s"])]
                + scrolling(type, "s", horizontal: false, extra: ["shrinkWrap": true],
                            holding: scrolling("ListView", "n", horizontal: false)))
            defer { hosted.close() }
            let views = hosted.scrollViews
            XCTAssertEqual(views.count, 1, "\(type): only the list inside")
            XCTAssertNil(try XCTUnwrap(views.first, "no UIScrollView: \(type)").refreshControl, type)
        }
    }

    /// A5.5: a refreshed scroll view inside the page's scroll view keeps a
    /// pull at its top: Flutter's inner Scrollable wins the drag, overscrolls
    /// and refreshes, where UIKit hands a drag past a nested scroll view's
    /// edge to the one around it (`transfersVerticalScrollingToParent`, on by
    /// default; a real pull on the iOS 18.5 simulator moved the outer page
    /// and never refreshed). Turned off for the refreshed one, of each kind;
    /// the page's scroll view and a plain nested list keep UIKit's default.
    func testA5_5ARefreshedScrollViewInsideAnotherKeepsThePullAtItsTop() throws {
        guard #available(iOS 17.4, *) else { throw XCTSkip("transfersVerticalScrollingToParent is iOS 17.4") }
        for type in Self.kinds {
            let hosted = try HostedPull([
                node("outer", "SingleChildScrollView", [:], ["col"]),
                node("col", "Column", [:], ["box", "plain", "rest"]),
                node("box", "SizedBox", ["width": 100, "height": 80], ["pull"]),
                pull(["s"]),
                node("plain", "SizedBox", ["width": 100, "height": 80], ["n"]),
                node("rest", "SizedBox", ["width": 100, "height": 400]),
            ] + scrolling(type, "s", horizontal: false) + scrolling("ListView", "n", horizontal: false))
            defer { hosted.close() }
            let views = hosted.scrollViews
            XCTAssertEqual(views.count, 3, "\(type): the page's, the refreshed and the plain one")
            guard views.count == 3 else { continue }
            XCTAssertNil(views[0].refreshControl, type)
            let refreshed = try XCTUnwrap(views.first { $0.refreshControl != nil }, "no refresh control: \(type)")
            XCTAssertFalse(refreshed.transfersVerticalScrollingToParent, "\(type): the refreshed one")
            for scroll in views where scroll !== refreshed {
                XCTAssertTrue(scroll.transfersVerticalScrollingToParent, "\(type): one not refreshed")
            }
        }
    }

    #elseif canImport(AppKit)
    /// A5.5 on macOS: a PullToRefresh draws the scroll view inside it (the
    /// system has no pull to refresh on a scroll view).
    func testA5_5OnMacOSPullToRefreshDrawsTheScrollViewInside() throws {
        for type in Self.kinds {
            let views = try MacHostedPull.scrollViews([pull(["s"])] + scrolling(type, "s", horizontal: false))
            XCTAssertEqual(views.count, 1, type)
        }
    }
    #endif

    // MARK: pages

    /// A PullToRefresh holding `children` (one), with `onRefresh` when given.
    func pull(_ children: [String], onRefresh: JSONValue? = nil) -> JSONValue {
        node("pull", "PullToRefresh", [:], children, actions: onRefresh.map { ["onRefresh": $0] } ?? [:])
    }

    /// setState `key` to itself plus 1.
    func count(_ key: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": [
            "type": "transform", "input": ["type": "state", "key": .string(key), "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]
    }

    /// Scroll kind `type` as node `id` along `horizontal` (else vertical,
    /// a PageView not snapping), with `extra` props, over six boxes of 100
    /// by 100 named from `id`, longer than the 100-point window; the first
    /// box holds the first node of `inner` when given.
    func scrolling(_ type: String, _ id: String, horizontal: Bool, extra: [String: JSONValue] = [:],
                   holding inner: [JSONValue] = []) -> [JSONValue] {
        var props: [String: JSONValue] = horizontal ? ["scrollDirection": "horizontal"] : [:]
        if type == "PageView" {
            props = ["pageSnapping": false, "scrollDirection": horizontal ? "horizontal" : "vertical"]
        }
        props.merge(extra) { $1 }
        let boxes = (0..<6).map { "\(id)-\($0)" }
        let innerRoot: [String] = inner.first.flatMap { $0.objectValue?["id"]?.stringValue }.map { [$0] } ?? []
        let items = boxes.enumerated().map { index, box in
            node(box, "SizedBox", ["width": 100, "height": 100], index == 0 ? innerRoot : [])
        }
        guard type == "SingleChildScrollView" else { return [node(id, type, props, boxes)] + items + inner }
        let line = "\(id)-line"
        return [node(id, type, props, [line]), node(line, horizontal ? "Row" : "Column", [:], boxes)] + items + inner
    }

    /// A wire node: lists, grids, pages and lines hold many children, the rest at most one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:], _ children: [String] = [],
              actions: [String: JSONValue] = [:]) -> JSONValue {
        let multi = ["ListView", "GridView", "PageView", "Column", "Row"].contains(type)
        return [
            "id": .string(id), "type": .string(type), "kind": "layout",
            "childMode": .string(multi ? "multi" : children.isEmpty ? "none" : "single"),
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
            "actions": .object(actions),
        ]
    }
}

/// A handler held until `open`: how often it was entered.
@MainActor
private final class Gate {
    private(set) var waits = 0
    private var opened = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        waits += 1
        if opened { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func open() {
        opened = true
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

/// The page of `nodes`, its registry widened by the step 5 widgets
/// (advertised only in group 8), page `keys` at 0, and its first node's id.
@MainActor
private func pullPage(_ nodes: [JSONValue], keys: [String] = []) throws -> (model: OrcaPageModel, root: String) {
    let page = try JSONValue.object([
        "pageId": "p", "title": "T",
        "state": .array(keys.map { ["key": .string($0), "scope": "page", "initial": 0] }),
        "components": .array(nodes),
    ]).decode(PageResponse.self)
    let model = OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
        .union(["PullToRefresh", "ListView", "GridView", "PageView"])))
    return (model, try XCTUnwrap(nodes.first?.objectValue?["id"]?.stringValue, "no root node"))
}

#if canImport(UIKit)
/// The first node of `nodes` in a UIKit window of 100 by 100 (page `keys`
/// at 0), kept on screen until `close`.
@MainActor
private final class HostedPull {
    private let window: UIWindow
    let model: OrcaPageModel

    init(_ nodes: [JSONValue], keys: [String] = []) throws {
        let (model, root) = try pullPage(nodes, keys: keys)
        self.model = model
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let host = UIHostingController(rootView: NodeView(id: root, model: model)
            .frame(width: 100, height: 100, alignment: .topLeading)
            .ignoresSafeArea())
        window = UIWindow(frame: frame)
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = frame
        host.view.layoutIfNeeded()
        pump(0.3)
    }

    func value(_ key: String) -> JSONValue { model.store.value(key) }

    /// What a pull past the threshold does to `control`: it starts
    /// refreshing and sends its valueChanged actions. `sendActions(for:)`
    /// sends nothing here (package tests run with no UIApplication to
    /// dispatch through), so the actions are performed on their targets.
    static func pulled(_ control: UIRefreshControl) {
        control.beginRefreshing()
        for target in control.allTargets {
            for action in control.actions(forTarget: target, forControlEvent: .valueChanged) ?? [] {
                _ = (target as AnyObject).perform(NSSelectorFromString(action), with: control)
            }
        }
    }

    func pump(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Every UIScrollView in the window, each before those inside it.
    var scrollViews: [UIScrollView] {
        func all(_ view: UIView) -> [UIScrollView] {
            ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap(all)
        }
        return all(window)
    }

    func close() {
        window.isHidden = true
    }
}
#elseif canImport(AppKit)
/// The first node of `nodes` in an AppKit window of 100 by 100.
@MainActor
private enum MacHostedPull {
    /// Every NSScrollView the nodes are drawn with, each before those inside it.
    static func scrollViews(_ nodes: [JSONValue]) throws -> [NSScrollView] {
        let (model, root) = try pullPage(nodes)
        let host = NSHostingView(rootView: NodeView(id: root, model: model).frame(width: 100, height: 100))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        func all(_ view: NSView) -> [NSScrollView] {
            ((view as? NSScrollView).map { [$0] } ?? []) + view.subviews.flatMap(all)
        }
        return all(host)
    }
}
#endif
#endif
