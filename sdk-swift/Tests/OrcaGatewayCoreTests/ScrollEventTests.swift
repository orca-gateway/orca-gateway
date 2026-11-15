import XCTest

@testable import OrcaGatewayCore

/// A2.4: the scroll triggers' payload and order, against Flutter's
/// `_scrollEventData` and `wrapScrollNotifier` (sdk/lib/src/builders/
/// builder_helpers.dart:32-71) and fixture 19_scroll_event_values: a view of
/// 400 over content 1000 long, so maxExtent 600.
final class ScrollEventTests: XCTestCase {
    private func at(_ offset: Double, maxExtent: Double = 600) -> ScrollMetrics {
        ScrollMetrics(offset: offset, maxExtent: maxExtent, viewportDimension: 400)
    }

    private func payload(_ offset: Double, atStart: Bool, atEnd: Bool, delta: Double? = nil) -> [String: JSONValue] {
        var data: [String: JSONValue] = [
            "offset": .double(offset), "maxExtent": .double(600), "minExtent": .double(0),
            "viewportDimension": .double(400), "atStart": .bool(atStart), "atEnd": .bool(atEnd),
        ]
        if let delta { data["delta"] = .double(delta) }
        return data
    }

    private func feed(_ observer: ScrollObserver, _ samples: [(Double, Bool)]) -> [ScrollEvent] {
        samples.flatMap { offset, inProgress in observer.observe(at(offset), inProgress: inProgress) }
    }

    // MARK: payload

    /// A2.4: at offset 0 the view is at its start, as Flutter's `atEdge && pixels <= min`.
    func testA2_4PayloadAtTheStart() {
        XCTAssertEqual(at(0).eventData, payload(0, atStart: true, atEnd: false))
    }

    /// A2.4: between the edges it is at neither.
    func testA2_4PayloadInTheMiddle() {
        XCTAssertEqual(at(250.5).eventData, payload(250.5, atStart: false, atEnd: false))
    }

    /// A2.4: at maxExtent it is at its end.
    func testA2_4PayloadAtTheEnd() {
        XCTAssertEqual(at(600).eventData, payload(600, atStart: false, atEnd: true))
    }

    /// A2.4: content shorter than the view (maxExtent 0) is at both edges, as in Flutter.
    func testA2_4ContentThatFitsIsAtBothEdges() {
        let data = at(0, maxExtent: 0).eventData
        XCTAssertEqual(data["atStart"], .bool(true))
        XCTAssertEqual(data["atEnd"], .bool(true))
    }

    /// A2.4: a sample is an offset along the axis and the content's and
    /// viewport's lengths: maxExtent is content minus viewport, never below
    /// 0, minExtent 0 (a SingleChildScrollView's).
    func testA2_4ASampleMakesFlutterExtents() {
        XCTAssertEqual(ScrollMetrics(offset: 250.5, contentExtent: 1000, viewportExtent: 400), at(250.5))
        XCTAssertEqual(ScrollMetrics(offset: 0, contentExtent: 300, viewportExtent: 400), at(0, maxExtent: 0))
    }

    /// A2.4: a reversed view counts its offset from the far end, as
    /// Flutter's: the view resting at the bottom is at offset 0.
    func testA2_4AReversedSampleCountsFromTheFarEnd() {
        XCTAssertEqual(ScrollMetrics(offset: 600, contentExtent: 1000, viewportExtent: 400, reverse: true), at(0))
        XCTAssertEqual(ScrollMetrics(offset: 150, contentExtent: 1000, viewportExtent: 400, reverse: true), at(450))
    }

    /// A2.4: an offset within the tolerance of an edge (layout's fraction of
    /// a pixel) is at it; past the end by more (a bounce) is at neither, as
    /// Flutter's `atEdge` is false out of range.
    func testA2_4AnEdgeHasASmallTolerance() {
        XCTAssertEqual(at(0.2).eventData["atStart"], .bool(true))
        XCTAssertEqual(at(599.8).eventData["atEnd"], .bool(true))
        XCTAssertEqual(at(600.2).eventData["atEnd"], .bool(true))
        XCTAssertEqual(at(-0.2).eventData["atStart"], .bool(true))
        XCTAssertEqual(at(1).eventData["atStart"], .bool(false))
        XCTAssertEqual(at(599).eventData["atEnd"], .bool(false))
        XCTAssertEqual(at(630).eventData["atEnd"], .bool(false))
        XCTAssertEqual(at(-30).eventData["atStart"], .bool(false))
        XCTAssertEqual(at(630).eventData["offset"], .double(630))
    }

    // MARK: order

    /// A2.4: a scroll in progress (a drag, an animation) runs onScrollBegin
    /// where it starts, onScrolling per offset with the change since the
    /// last, and onScrollEnd where it settles.
    func testA2_4AScrollRunsBeginThenScrollingThenEnd() {
        let events = feed(ScrollObserver(), [(0, false), (0, true), (250.5, true), (600, true), (600, false)])
        XCTAssertEqual(events, [
            ScrollEvent(trigger: "onScrollBegin", eventData: payload(0, atStart: true, atEnd: false)),
            ScrollEvent(trigger: "onScrolling", eventData: payload(250.5, atStart: false, atEnd: false, delta: 250.5)),
            ScrollEvent(trigger: "onScrolling", eventData: payload(600, atStart: false, atEnd: true, delta: 349.5)),
            ScrollEvent(trigger: "onScrollEnd", eventData: payload(600, atStart: false, atEnd: true)),
        ])
    }

    /// A2.4: onScrollBegin carries where the scroll started even when the
    /// first sample in progress has already moved (Flutter's drag start
    /// comes before its first update).
    func testA2_4BeginCarriesWhereTheScrollStarted() {
        XCTAssertEqual(feed(ScrollObserver(), [(0, false), (100, true)]), [
            ScrollEvent(trigger: "onScrollBegin", eventData: payload(0, atStart: true, atEnd: false)),
            ScrollEvent(trigger: "onScrolling", eventData: payload(100, atStart: false, atEnd: false, delta: 100)),
        ])
    }

    /// A2.4: an offset that changes with no scroll in progress is a jump,
    /// which Flutter's `jumpTo` reports as begin, one update and end, all at
    /// the new offset.
    func testA2_4AJumpRunsAllThreeAtTheNewOffset() {
        XCTAssertEqual(feed(ScrollObserver(), [(0, false), (600, false)]), [
            ScrollEvent(trigger: "onScrollBegin", eventData: payload(600, atStart: false, atEnd: true)),
            ScrollEvent(trigger: "onScrolling", eventData: payload(600, atStart: false, atEnd: true, delta: 600)),
            ScrollEvent(trigger: "onScrollEnd", eventData: payload(600, atStart: false, atEnd: true)),
        ])
    }

    /// A2.4: a sample with the same offset runs no onScrolling, a new extent
    /// alone runs nothing, and the first sample runs nothing.
    func testA2_4AnUnchangedOffsetRunsNothing() {
        let observer = ScrollObserver()
        _ = feed(observer, [(0, false), (0, true), (50, true)])
        XCTAssertEqual(feed(observer, [(50, true)]), [])

        let resized = ScrollObserver()
        XCTAssertEqual(resized.observe(at(0), inProgress: false), [])
        XCTAssertEqual(resized.observe(at(0, maxExtent: 900), inProgress: false), [])
    }

    /// A2.4: delta is negative when the offset goes back toward the start.
    func testA2_4DeltaIsNegativeTowardTheStart() {
        let events = feed(ScrollObserver(), [(600, false), (600, true), (450, true)])
        XCTAssertEqual(events.last?.trigger, "onScrolling")
        XCTAssertEqual(events.last?.eventData["delta"], .double(-150))
    }

    /// A2.4: the triggers a node must set for its scroll view to be watched.
    func testA2_4TheThreeTriggers() {
        XCTAssertEqual(ScrollEvent.triggers, ["onScrollBegin", "onScrolling", "onScrollEnd"])
    }
}
