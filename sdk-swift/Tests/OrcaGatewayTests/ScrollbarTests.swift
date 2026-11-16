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

/// A5.7: Flutter's `Scrollbar` (layout_builders.dart:603-611) is a
/// CupertinoScrollbar on iOS, drawn for the scroll view directly inside it
/// (depth-0 notifications) and fading when the scroll stops; with no
/// Scrollbar Flutter on a phone draws no indicator at all, on a desktop
/// one on every scroll view (scroll_configuration.dart:160-172). Here the
/// scroll kinds show the system indicator under a Scrollbar and hide it
/// otherwise on iOS, read from the UIScrollView each is hosted with:
/// SingleChildScrollView, ListView, GridView and a PageView with
/// `pageSnapping` false (a snapping one is drawn without one); macOS
/// keeps its scroller. How the thumb looks and fades is the hand check.
@MainActor
final class ScrollbarTests: XCTestCase {
    /// The four kinds drawn with a scroll view.
    static let kinds = ["SingleChildScrollView", "ListView", "GridView", "PageView"]

    #if canImport(UIKit)
    /// A5.7: each kind directly inside a Scrollbar shows the indicator on
    /// its axis, vertical and horizontal.
    func testA5_7AScrollbarShowsTheIndicatorOfTheScrollViewInside() throws {
        for type in Self.kinds {
            for horizontal in [false, true] {
                let hosted = try HostedBar([node("bar", "Scrollbar", [:], ["s"])]
                    + scrolling(type, "s", horizontal: horizontal))
                defer { hosted.close() }
                let views = hosted.scrollViews
                XCTAssertEqual(views.count, 1, "\(type) horizontal \(horizontal)")
                let scroll = try XCTUnwrap(views.first, "no UIScrollView: \(type) horizontal \(horizontal)")
                XCTAssertTrue(horizontal ? scroll.showsHorizontalScrollIndicator : scroll.showsVerticalScrollIndicator,
                              "\(type) horizontal \(horizontal)")
            }
        }
    }

    /// A5.7: with no Scrollbar no kind shows an indicator, as Flutter on a
    /// phone (iOS's default would show one while scrolling).
    func testA5_7WithoutAScrollbarNoScrollViewShowsAnIndicator() throws {
        for type in Self.kinds {
            for horizontal in [false, true] {
                let hosted = try HostedBar(scrolling(type, "s", horizontal: horizontal))
                defer { hosted.close() }
                let scroll = try XCTUnwrap(hosted.scrollViews.first,
                                           "no UIScrollView: \(type) horizontal \(horizontal)")
                XCTAssertFalse(scroll.showsVerticalScrollIndicator, "\(type) horizontal \(horizontal)")
                XCTAssertFalse(scroll.showsHorizontalScrollIndicator, "\(type) horizontal \(horizontal)")
            }
        }
    }

    /// A5.7: a scroll view inside the one a Scrollbar follows is not
    /// followed (Flutter's depth 1): each kind holding a horizontal one of
    /// its kind in its first item shows its indicator, the inner one none.
    func testA5_7AScrollViewNestedInsideTheFollowedOneShowsNoIndicator() throws {
        for type in Self.kinds {
            let inner = scrolling(type, "n", horizontal: true)
            let hosted = try HostedBar([node("bar", "Scrollbar", [:], ["s"])]
                + scrolling(type, "s", horizontal: false, holding: inner))
            defer { hosted.close() }
            let views = hosted.scrollViews
            XCTAssertEqual(views.count, 2, "\(type): the outer and the nested scroll view")
            guard views.count == 2 else { continue }
            XCTAssertTrue(views[0].showsVerticalScrollIndicator, "\(type): the followed one")
            XCTAssertFalse(views[1].showsVerticalScrollIndicator, "\(type): the nested one")
            XCTAssertFalse(views[1].showsHorizontalScrollIndicator, "\(type): the nested one")
        }
    }

    /// A5.7: widgets that do not scroll between the Scrollbar and the
    /// scroll view leave it the one followed (still Flutter's depth 0).
    func testA5_7AScrollbarFollowsItsScrollViewThroughWidgetsThatDoNotScroll() throws {
        let hosted = try HostedBar([
            node("bar", "Scrollbar", [:], ["pad"]),
            node("pad", "Padding", ["padding": ["top": 4, "right": 4, "bottom": 4, "left": 4]], ["center"]),
            node("center", "Center", [:], ["s"]),
        ] + scrolling("ListView", "s", horizontal: false))
        defer { hosted.close() }
        let scroll = try XCTUnwrap(hosted.scrollViews.first, "no UIScrollView")
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
    }

    /// A5.7: a snapping PageView has no UIScrollView, so no indicator (a
    /// known difference: Flutter draws the thumb along the pages), and a
    /// list in one of its pages is nested, so it shows none either.
    func testA5_7ASnappingPageViewIsNoScrollViewAndItsPagesListsShowNoIndicator() throws {
        let hosted = try HostedBar([
            node("bar", "Scrollbar", ["thumbVisibility": true], ["pv"]),
            node("pv", "PageView", [:], ["s", "p1"]),
            node("p1", "SizedBox", ["width": 100, "height": 100]),
        ] + scrolling("ListView", "s", horizontal: false))
        defer { hosted.close() }
        let views = hosted.scrollViews
        XCTAssertEqual(views.count, 1, "only the page's list")
        let scroll = try XCTUnwrap(views.first, "no UIScrollView")
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
    }

    /// A5.7: `thumbVisibility` shows the thumb before any scroll: iOS keeps
    /// no indicator shown, so each kind flashes it as it appears (iOS 17),
    /// the system fading it about a second later; without it the
    /// indicator stays hidden until a scroll.
    func testA5_7ThumbVisibilityFlashesTheIndicatorAsTheViewAppears() throws {
        guard #available(iOS 17, *) else { throw XCTSkip("no scroll indicator flash before iOS 17") }
        for type in Self.kinds {
            for keep in [true, false] {
                let hosted = try HostedBar([node("bar", "Scrollbar", ["thumbVisibility": .bool(keep)], ["s"])]
                    + scrolling(type, "s", horizontal: false))
                defer { hosted.close() }
                let scroll = try XCTUnwrap(hosted.scrollViews.first, "no UIScrollView: \(type)")
                XCTAssertEqual(HostedBar.indicatorShown(scroll), keep, "\(type) thumbVisibility \(keep)")
            }
        }
    }

    /// A5.7: with `thumbVisibility` the thumb flashes again as a scroll
    /// ends (iOS 18's scroll phase), where iOS would fade it, and the
    /// scroll view's own onScrollEnd still runs.
    func testA5_7ThumbVisibilityFlashesTheIndicatorAgainAsAScrollEnds() throws {
        guard #available(iOS 18, *) else { throw XCTSkip("no scroll phase before iOS 18") }
        var nodes = [node("bar", "Scrollbar", ["thumbVisibility": true], ["s"])]
            + scrolling("SingleChildScrollView", "s", horizontal: false)
        nodes[1] = node("s", "SingleChildScrollView", [:], ["s-line"], actions: ["onScrollEnd": [
            "type": "setState", "scope": "page", "key": "ends", "value": ["type": "event", "key": "offset"],
        ]])
        let hosted = try HostedBar(nodes, keys: ["ends"])
        defer { hosted.close() }
        let scroll = try XCTUnwrap(hosted.scrollViews.first, "no UIScrollView")
        hosted.pump(2)
        XCTAssertFalse(HostedBar.indicatorShown(scroll), "the first flash has not faded")

        scroll.delegate?.scrollViewWillBeginDragging?(scroll)
        hosted.pump(0.1)
        for offset in [40, 80, 120] as [CGFloat] {
            scroll.contentOffset = CGPoint(x: 0, y: offset)
            hosted.pump(0.03)
        }
        var target = scroll.contentOffset
        scroll.delegate?.scrollViewWillEndDragging?(scroll, withVelocity: .zero, targetContentOffset: &target)
        scroll.delegate?.scrollViewDidEndDragging?(scroll, willDecelerate: false)
        hosted.pump(0.3)

        XCTAssertTrue(HostedBar.indicatorShown(scroll), "no flash as the scroll ended")
        XCTAssertEqual(hosted.value("ends"), 120, "the scroll view's onScrollEnd")
    }

    #elseif canImport(AppKit)
    /// A5.7 on macOS: every kind keeps the system's scroller, with or
    /// without a Scrollbar, nested or not, as Flutter's desktop behaviour
    /// draws one on every scroll view.
    func testA5_7OnMacOSEveryScrollViewKeepsItsScroller() throws {
        for type in Self.kinds {
            let nodes = scrolling(type, "s", horizontal: false, holding: scrolling(type, "n", horizontal: true))
            for page in [nodes, [node("bar", "Scrollbar", [:], ["s"])] + nodes] {
                let views = try MacHostedBar.scrollViews(page)
                XCTAssertEqual(views.count, 2, "\(type): the outer and the nested scroll view")
                XCTAssertEqual(views.first?.hasVerticalScroller, true, "\(type): the outer one")
                XCTAssertEqual(views.last?.hasHorizontalScroller, true, "\(type): the nested one")
            }
        }
    }
    #endif

    // MARK: pages

    /// Scroll kind `type` as node `id` along `horizontal` (else vertical,
    /// a PageView not snapping) over six boxes of 100 by 100 named from
    /// `id`, longer than the 100-point window; the first box holds the
    /// first node of `inner` when given.
    func scrolling(_ type: String, _ id: String, horizontal: Bool, holding inner: [JSONValue] = []) -> [JSONValue] {
        var props: [String: JSONValue] = horizontal ? ["scrollDirection": "horizontal"] : [:]
        if type == "PageView" {
            props = ["pageSnapping": false, "scrollDirection": horizontal ? "horizontal" : "vertical"]
        }
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

/// The page of `nodes`, its registry widened by the step 5 widgets
/// (advertised only in group 8), page `keys` at 0, and its first node's id.
@MainActor
private func barPage(_ nodes: [JSONValue], keys: [String] = []) throws -> (model: OrcaPageModel, root: String) {
    let page = try JSONValue.object([
        "pageId": "p", "title": "T",
        "state": .array(keys.map { ["key": .string($0), "scope": "page", "initial": 0] }),
        "components": .array(nodes),
    ]).decode(PageResponse.self)
    let model = OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
        .union(["Scrollbar", "ListView", "GridView", "PageView"])))
    return (model, try XCTUnwrap(nodes.first?.objectValue?["id"]?.stringValue, "no root node"))
}

#if canImport(UIKit)
/// The first node of `nodes` in a UIKit window of 100 by 100 (page `keys`
/// at 0), kept on screen until `close`.
@MainActor
private final class HostedBar {
    private let window: UIWindow
    private let model: OrcaPageModel

    init(_ nodes: [JSONValue], keys: [String] = []) throws {
        let (model, root) = try barPage(nodes, keys: keys)
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

    /// Whether one of `scroll`'s indicators is shown or showing (UIKit's
    /// own subviews: a flash sets their alpha to 1 until the fade starts).
    static func indicatorShown(_ scroll: UIScrollView) -> Bool {
        scroll.subviews.contains { String(describing: type(of: $0)).contains("ScrollIndicator") && $0.alpha > 0 }
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
private enum MacHostedBar {
    /// Every NSScrollView the nodes are drawn with, each before those inside it.
    static func scrollViews(_ nodes: [JSONValue]) throws -> [NSScrollView] {
        let (model, root) = try barPage(nodes)
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
