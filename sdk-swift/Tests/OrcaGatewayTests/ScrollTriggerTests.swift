#if canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import XCTest

@testable import OrcaGateway

/// A2.4 on iOS: a SingleChildScrollView runs onScrollBegin, onScrolling and
/// onScrollEnd, Flutter's `wrapScrollNotifier` (builder_helpers.dart:46-71),
/// and each reads its payload through `V.event` into page state. A view of
/// 100 over content 300 long scrolls 200 (maxExtent), in points, Flutter's
/// logical pixels. The view is hosted in a UIKit window and moved through
/// its UIScrollView: `setContentOffset` (a jump), offsets set one run-loop
/// turn apart, and the scroll view delegate's drag and deceleration calls,
/// which UIKit makes for a finger and SwiftUI turns into its scroll phase.
/// A real finger (the iOS 16-17 DragGesture) is the hand check.
@MainActor
final class ScrollTriggerTests: XCTestCase {
    override func tearDown() {
        ScrollNodeView.usesScrollPhase = true
        super.tearDown()
    }

    // MARK: iOS 18 and later (the scroll phase)

    /// A2.4: a jump to the end (no scroll in progress, as Flutter's
    /// `jumpTo`) runs begin, scrolling and end once each, all at the new
    /// offset, with Flutter's values.
    func testA2_4AJumpToTheEndRunsTheThreeTriggersWithFlutterValues() throws {
        let hosted = try Hosted(triggers)
        defer { hosted.close() }
        XCTAssertEqual(hosted.value("begins"), 0, "a trigger ran on the first build")

        hosted.scroll(to: 200)

        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("beginOffset"), 200)
        XCTAssertEqual(hosted.value("scrolls"), 1)
        XCTAssertEqual(hosted.value("offset"), 200)
        XCTAssertEqual(hosted.value("maxExtent"), 200)
        XCTAssertEqual(hosted.value("atEnd"), true)
        XCTAssertEqual(hosted.value("delta"), 200)
        XCTAssertEqual(hosted.value("ends"), 1)
        XCTAssertEqual(hosted.value("endOffset"), 200)
        XCTAssertEqual(hosted.value("endAtEnd"), true)
        XCTAssertEqual(hosted.value("viewport"), 100)
    }

    /// A2.4: a drag runs onScrollBegin as it starts, before the view moves,
    /// onScrolling per offset with its delta, and onScrollEnd where the
    /// finger lifts.
    func testA2_4ADragRunsBeginThenScrollingThenEnd() throws {
        let hosted = try Hosted(triggers)
        defer { hosted.close() }

        hosted.beginDrag()
        XCTAssertEqual(hosted.value("begins"), 1, "no begin as the drag started")
        XCTAssertEqual(hosted.value("scrolls"), 0)
        XCTAssertEqual(hosted.value("beginOffset"), 0)
        XCTAssertEqual(hosted.value("beginAtStart"), true)

        hosted.move(through: [50, 100, 150, 200])
        XCTAssertEqual(hosted.value("scrolls"), 4)
        XCTAssertEqual(hosted.value("offset"), 200)
        XCTAssertEqual(hosted.value("delta"), 50)
        XCTAssertEqual(hosted.value("atEnd"), true)
        XCTAssertEqual(hosted.value("ends"), 0, "an end before the finger lifted")

        hosted.endDrag(decelerating: false)
        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("ends"), 1)
        XCTAssertEqual(hosted.value("endOffset"), 200)
        XCTAssertEqual(hosted.value("endAtEnd"), true)
        XCTAssertEqual(hosted.value("viewport"), 100)
    }

    /// A2.4: a fling ends where its deceleration stops, not where the
    /// finger lifted.
    func testA2_4AFlingEndsWhereItStops() throws {
        let hosted = try Hosted(triggers)
        defer { hosted.close() }

        hosted.beginDrag()
        hosted.move(through: [40, 80])
        hosted.endDrag(decelerating: true)
        XCTAssertEqual(hosted.value("ends"), 0, "an end as the finger lifted")
        hosted.move(through: [130, 170, 190])
        hosted.endDeceleration()

        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("scrolls"), 5)
        XCTAssertEqual(hosted.value("ends"), 1)
        XCTAssertEqual(hosted.value("endOffset"), 190)
        XCTAssertEqual(hosted.value("endAtEnd"), false)
    }

    /// A2.4: scrolling back runs onScrolling with a negative delta, ending
    /// at the start.
    func testA2_4ScrollingBackHasANegativeDelta() throws {
        let hosted = try Hosted(triggers)
        defer { hosted.close() }
        hosted.scroll(to: 150)
        XCTAssertEqual(hosted.value("endOffset"), 150)
        XCTAssertEqual(hosted.value("endAtEnd"), false)

        hosted.scroll(to: 0)

        XCTAssertEqual(hosted.value("begins"), 2)
        XCTAssertEqual(hosted.value("offset"), 0)
        XCTAssertEqual(hosted.value("delta"), -150)
        XCTAssertEqual(hosted.value("atEnd"), false)
        XCTAssertEqual(hosted.value("ends"), 2)
        XCTAssertEqual(hosted.value("endOffset"), 0)
    }

    /// A2.4: a horizontal view runs the same triggers along the x axis.
    func testA2_4AHorizontalViewUsesTheXAxis() throws {
        let hosted = try Hosted(triggers, props: ["scrollDirection": "horizontal"])
        defer { hosted.close() }

        hosted.scroll(to: 200)

        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("offset"), 200)
        XCTAssertEqual(hosted.value("maxExtent"), 200)
        XCTAssertEqual(hosted.value("endAtEnd"), true)
        XCTAssertEqual(hosted.value("viewport"), 100)
    }

    /// A2.4: a reversed view counts from the bottom, where it starts, as
    /// Flutter's: shown, it runs nothing; at the top it is at offset 200,
    /// its end.
    func testA2_4AReversedViewCountsFromTheBottom() throws {
        let hosted = try Hosted(triggers, props: ["reverse": true])
        defer { hosted.close() }
        XCTAssertEqual(hosted.value("begins"), 0, "a trigger ran on the first build")

        hosted.scroll(to: 0)

        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("offset"), 200)
        XCTAssertEqual(hosted.value("delta"), 200)
        XCTAssertEqual(hosted.value("endAtEnd"), true)
    }

    /// A2.4: a scroll view with no scroll trigger fires nothing (its onTap
    /// is not a scroll trigger).
    func testA2_4AViewWithoutTriggersFiresNothing() throws {
        let hosted = try Hosted(["onTap": Self.count("begins")])
        defer { hosted.close() }

        hosted.scroll(to: 200)
        hosted.beginDrag()
        hosted.move(through: [150, 100])
        hosted.endDrag(decelerating: false)

        XCTAssertEqual(hosted.value("begins"), 0)
    }

    // MARK: iOS 16 and 17 (offset probe, drag and settle)

    /// A2.4 on the iOS 16-17 path: an offset change is a scroll in progress
    /// until the view has not moved for a moment, so a jump runs begin where
    /// it started, onScrolling, and end once it settles.
    func testA2_4OnIOS16AJumpRunsBeginScrollingThenEndOnceSettled() throws {
        ScrollNodeView.usesScrollPhase = false
        let hosted = try Hosted(triggers)
        defer { hosted.close() }

        hosted.scroll(to: 200)

        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("beginOffset"), 0)
        XCTAssertEqual(hosted.value("beginAtStart"), true)
        XCTAssertEqual(hosted.value("offset"), 200)
        XCTAssertEqual(hosted.value("maxExtent"), 200)
        XCTAssertEqual(hosted.value("delta"), 200)
        XCTAssertEqual(hosted.value("ends"), 1)
        XCTAssertEqual(hosted.value("endOffset"), 200)
        XCTAssertEqual(hosted.value("endAtEnd"), true)
        XCTAssertEqual(hosted.value("viewport"), 100)
    }

    /// A2.4 on the iOS 16-17 path: offsets a frame apart (a fling) run one
    /// begin, onScrolling each and one end where the view stops; horizontal
    /// and reversed views read their axis and far end there too.
    func testA2_4OnIOS16MovesAFrameApartRunOneBeginAndOneEnd() throws {
        ScrollNodeView.usesScrollPhase = false
        let hosted = try Hosted(triggers)
        defer { hosted.close() }

        hosted.move(through: [50, 100, 150, 200])
        hosted.pump(0.5)

        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("beginOffset"), 0)
        XCTAssertEqual(hosted.value("scrolls"), 4)
        XCTAssertEqual(hosted.value("delta"), 50)
        XCTAssertEqual(hosted.value("ends"), 1)
        XCTAssertEqual(hosted.value("endOffset"), 200)

        let row = try Hosted(triggers, props: ["scrollDirection": "horizontal", "reverse": true])
        defer { row.close() }
        XCTAssertEqual(row.value("begins"), 0, "a trigger ran on the first build")
        row.scroll(to: 0)
        XCTAssertEqual(row.value("endOffset"), 200)
        XCTAssertEqual(row.value("maxExtent"), 200)
        XCTAssertEqual(row.value("endAtEnd"), true)
    }

    /// A2.4 on the iOS 16-17 path: a view removed before its scroll settles
    /// runs no onScrollEnd afterwards, as a disposed Flutter ScrollPosition
    /// sends no ScrollEnd.
    func testA2_4OnIOS16AViewRemovedBeforeItSettlesRunsNoEnd() throws {
        ScrollNodeView.usesScrollPhase = false
        let hosted = try Hosted(triggers)
        defer { hosted.close() }

        hosted.move(through: [50, 100])
        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("ends"), 0, "the scroll settled before the view was removed")

        hosted.remove()

        XCTAssertEqual(hosted.value("ends"), 0, "onScrollEnd ran after the view was gone")
    }

    /// A2.4 on the iOS 16-17 path: a view that disappeared mid-scroll and
    /// came back drops that scroll, firing nothing, so its next scroll runs
    /// onScrollBegin first, from where the view stood (a new Flutter scroll
    /// has a new ScrollStart).
    func testA2_4OnIOS16AViewBackAfterLeavingMidScrollBeginsItsNextScroll() {
        let tracker = ScrollTracker()
        var later: [ScrollEvent] = []
        let fire: ([ScrollEvent]) -> Void = { later += $0 }
        func at(_ offset: Double) -> ScrollMetrics {
            ScrollMetrics(offset: offset, maxExtent: 200, viewportDimension: 100)
        }
        tracker.start()
        XCTAssertEqual(tracker.probe(at(0), then: fire), [])
        XCTAssertEqual(tracker.probe(at(50), then: fire).map(\.trigger), ["onScrollBegin", "onScrolling"])

        tracker.stop()
        tracker.start()
        let next = tracker.probe(at(100), then: fire)

        XCTAssertEqual(next.map(\.trigger), ["onScrollBegin", "onScrolling"])
        XCTAssertEqual(next.first?.eventData["offset"], 50)
        XCTAssertEqual(next.last?.eventData["delta"], 50)
        XCTAssertEqual(later, [], "the dropped scroll fired an end")
    }

    // MARK: helpers

    /// begin counts and writes where it started; onScrolling counts and
    /// writes offset, maxExtent, atEnd and delta; end counts and writes where
    /// it settled and the viewport.
    var triggers: [String: JSONValue] {
        [
            "onScrollBegin": Self.sequence([Self.count("begins"),
                                            Self.write("beginOffset", "offset"), Self.write("beginAtStart", "atStart")]),
            "onScrolling": Self.sequence([Self.count("scrolls"), Self.write("offset", "offset"),
                                          Self.write("maxExtent", "maxExtent"), Self.write("atEnd", "atEnd"),
                                          Self.write("delta", "delta")]),
            "onScrollEnd": Self.sequence([Self.count("ends"), Self.write("endOffset", "offset"),
                                          Self.write("endAtEnd", "atEnd"), Self.write("viewport", "viewportDimension")]),
        ]
    }

    static func sequence(_ actions: [JSONValue]) -> JSONValue {
        ["type": "actionGroup", "mode": "sequential", "actions": .array(actions)]
    }

    /// setState `key` to the event's `field`.
    static func write(_ key: String, _ field: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": ["type": "event", "key": .string(field)]]
    }

    /// setState `key` to itself plus 1.
    static func count(_ key: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": [
            "type": "transform", "input": ["type": "state", "key": .string(key), "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]
    }
}

/// Whether the hosted node is in the view tree.
private final class Shown: ObservableObject {
    @Published var value = true
}

/// The node `s` while `shown`, nothing once removed.
private struct Removable: View {
    @ObservedObject var shown: Shown
    let model: OrcaPageModel

    var body: some View {
        if shown.value { NodeView(id: "s", model: model) }
    }
}

/// A SingleChildScrollView `s` of 100 by 100 over a SizedBox 300 long on its
/// axis, with `actions`, in a UIKit window, kept on screen until `close`
/// (the node until `remove`).
@MainActor
private final class Hosted {
    let model: OrcaPageModel
    let horizontal: Bool
    private let shown = Shown()
    private let window: UIWindow

    init(_ actions: [String: JSONValue], props: [String: JSONValue] = [:]) throws {
        horizontal = props["scrollDirection"]?.stringValue == "horizontal"
        let size: [String: JSONValue] = horizontal ? ["width": 300, "height": 40] : ["width": 40, "height": 300]
        model = try OrcaPageModel(page: JSONValue.object([
            "pageId": "p", "title": "T",
            "state": .array(["begins", "scrolls", "ends"].map { ["key": .string($0), "scope": "page", "initial": 0] }),
            "components": [
                ["id": "s", "type": "SingleChildScrollView", "kind": "layout", "childMode": "single",
                 "props": .object(props), "children": ["b"], "watches": [], "actions": .object(actions)],
                ["id": "b", "type": "SizedBox", "kind": "layout", "childMode": "single",
                 "props": .object(size), "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self))
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let host = UIHostingController(rootView: Removable(shown: shown, model: model)
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

    /// The UIScrollView SwiftUI draws the node with.
    private var scrollView: UIScrollView {
        func find(_ view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            return view.subviews.lazy.compactMap(find).first
        }
        guard let scroll = find(window) else { fatalError("no UIScrollView") }
        return scroll
    }

    private func point(_ offset: CGFloat) -> CGPoint {
        horizontal ? CGPoint(x: offset, y: 0) : CGPoint(x: 0, y: offset)
    }

    /// `setContentOffset` on the view's axis, with no scroll in progress.
    func scroll(to offset: CGFloat) {
        scrollView.setContentOffset(point(offset), animated: false)
        pump(0.5)
    }

    /// Each offset one short run-loop turn after the other, as a drag or a
    /// fling moves the view every frame.
    func move(through offsets: [CGFloat]) {
        for offset in offsets {
            scrollView.contentOffset = point(offset)
            pump(0.03)
        }
        pump(0.05)
    }

    /// The delegate call UIKit makes when a finger starts dragging the view.
    func beginDrag() {
        scrollView.delegate?.scrollViewWillBeginDragging?(scrollView)
        pump(0.1)
    }

    /// The delegate calls UIKit makes when the finger lifts, with or without
    /// a fling to follow.
    func endDrag(decelerating: Bool) {
        var target = scrollView.contentOffset
        scrollView.delegate?.scrollViewWillEndDragging?(scrollView, withVelocity: .zero, targetContentOffset: &target)
        scrollView.delegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerating)
        pump(0.3)
    }

    /// The delegate call UIKit makes when a fling stops.
    func endDeceleration() {
        scrollView.delegate?.scrollViewDidEndDecelerating?(scrollView)
        pump(0.3)
    }

    func pump(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Take the node out of the view tree, as a page going away does.
    func remove() {
        shown.value = false
        pump(0.5)
    }

    func close() {
        window.isHidden = true
    }
}
#endif
