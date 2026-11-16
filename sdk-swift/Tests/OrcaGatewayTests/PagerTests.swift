#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A5.4, the UI half of PageView (layout_builders.dart:668-684; widgets/
/// page_view.dart): horizontal unless "vertical", page 0 first, each page
/// the viewport's size, the axis run backwards by `reverse` (and by
/// right-to-left when horizontal), only the pages in sight built (cache 0
/// viewports), a release settling on PageScrollPhysics' page (the core's
/// PageSnap), onScrollBegin / onScrolling / onScrollEnd with the offset and
/// viewportDimension, and pageSnapping false a free scroll view. Swift
/// cannot inject a finger, so the drag goes through the pager's feed (the
/// entry point its DragGesture calls): on its own, then in a hosted window
/// where the view draws, builds pages and settles (iOS). Frames by
/// ImageRenderer (macOS and iOS). Real swipes and their feel are the hand
/// check.
@MainActor
final class PagerTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: frames (ImageRenderer)

    /// A5.4: at rest page 0 fills the box, nothing of the next page shows,
    /// horizontal or vertical, forward or reversed, in either direction.
    func testA5_4AtRestPageZeroFillsTheBox() throws {
        let cases: [([String: JSONValue], LayoutDirection)] = [
            ([:], .leftToRight), (["scrollDirection": "vertical"], .leftToRight), (["reverse": true], .leftToRight),
            (["scrollDirection": "vertical", "reverse": true], .leftToRight), ([:], .rightToLeft),
        ]
        for (props, direction) in cases {
            let model = try model([node("box", "SizedBox", ["width": 200, "height": 100], ["pv"])] + pages(3, props))
            let pixels = try draw(NodeView(id: "box", model: model).environment(\.layoutDirection, direction))
            assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 200, height: 100),
                        "\(props) \(direction)")
            XCTAssertNil(pixels.bounds(of: Self.green), "\(props) \(direction)")
            assertFrame(pixels.bounds { !Self.grey($0) }, CGRect(x: 0, y: 0, width: 200, height: 100),
                        "\(props) \(direction)")
        }
    }

    /// A5.4: half way to page 1 the pages lie along the axis in order: page
    /// 0 on the left half and page 1 on the right, or page 0 on top and 1
    /// below when vertical.
    func testA5_4HalfWayThePagesLieAlongTheAxisInOrder() throws {
        let horizontal = try draw(pager(pages(3), at: 0.5))
        assertFrame(horizontal.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 100, height: 100))
        assertFrame(horizontal.bounds(of: Self.green), CGRect(x: 100, y: 0, width: 100, height: 100))
        XCTAssertNil(horizontal.bounds(of: Self.blue))

        let vertical = try draw(pager(pages(3, ["scrollDirection": "vertical"]), at: 0.5))
        assertFrame(vertical.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 200, height: 50))
        assertFrame(vertical.bounds(of: Self.green), CGRect(x: 0, y: 50, width: 200, height: 50))
        XCTAssertNil(vertical.bounds(of: Self.blue))
    }

    /// A5.4: reverse runs the axis backwards (Flutter's flipped axis
    /// direction): half way, page 1 is on the left (on top when vertical)
    /// and page 0 on the right (below). Right-to-left runs a horizontal
    /// pager backwards too, and reverse then runs it forwards again.
    func testA5_4ReverseRunsTheAxisBackwards() throws {
        let cases: [([String: JSONValue], LayoutDirection, CGRect, CGRect)] = [
            (["reverse": true], .leftToRight,
             CGRect(x: 100, y: 0, width: 100, height: 100), CGRect(x: 0, y: 0, width: 100, height: 100)),
            (["reverse": true, "scrollDirection": "vertical"], .leftToRight,
             CGRect(x: 0, y: 50, width: 200, height: 50), CGRect(x: 0, y: 0, width: 200, height: 50)),
            ([:], .rightToLeft,
             CGRect(x: 100, y: 0, width: 100, height: 100), CGRect(x: 0, y: 0, width: 100, height: 100)),
            (["reverse": true], .rightToLeft,
             CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 100, y: 0, width: 100, height: 100)),
        ]
        for (props, direction, red, green) in cases {
            let pixels = try draw(pager(pages(3, props), at: 0.5).environment(\.layoutDirection, direction))
            assertFrame(pixels.bounds(of: Self.red), red, "\(props) \(direction)")
            assertFrame(pixels.bounds(of: Self.green), green, "\(props) \(direction)")
        }
    }

    // MARK: the feed (the drag the pager's DragGesture hands it)

    /// A5.4: a drag follows the finger from where it passes the slop
    /// (Flutter's DragStartBehavior.start: the slop moves nothing), begins
    /// the scroll there, and each move scrolls with Flutter's payload; it
    /// stays within the pages (no overscroll, a known difference).
    func testA5_4ADragFollowsTheFingerFromWhereItPassesTheSlop() {
        let (feed, events) = feed()
        let t = Date()
        feed.changed(.zero, at: t)
        feed.changed(CGSize(width: -10, height: 2), at: t + 0.01)
        XCTAssertEqual(feed.page, 0)
        XCTAssertEqual(events.list, [], "a move within the slop scrolled")

        feed.changed(CGSize(width: -20, height: 2), at: t + 0.02)
        XCTAssertEqual(feed.page, 0, "the slop moved the page")
        XCTAssertEqual(events.list.map(\.trigger), ["onScrollBegin"])
        XCTAssertEqual(events.list.last?.eventData["offset"], 0)

        feed.changed(CGSize(width: -70, height: 5), at: t + 0.03)
        XCTAssertEqual(feed.page, 0.25, accuracy: 1e-9)
        XCTAssertEqual(events.list.map(\.trigger), ["onScrollBegin", "onScrolling"])
        let scrolled = events.list.last?.eventData ?? [:]
        XCTAssertEqual(scrolled["offset"], 50)
        XCTAssertEqual(scrolled["delta"], 50)
        XCTAssertEqual(scrolled["viewportDimension"], 200)
        XCTAssertEqual(scrolled["maxExtent"], 800)

        feed.changed(CGSize(width: 100, height: 5), at: t + 0.04)
        XCTAssertEqual(feed.page, 0, "dragged past the first page")
    }

    /// A5.4: a reversed pager moves forward with the finger going right (or
    /// down when vertical); a vertical one reads the drag's height.
    func testA5_4APagerReadsItsOwnAxisAndDirection() {
        let t = Date()
        let (backwards, _) = feed(backwards: true)
        for (step, x) in [0.0, 20, 70].enumerated() {
            backwards.changed(CGSize(width: x, height: 0), at: t + Double(step) * 0.01)
        }
        XCTAssertEqual(backwards.page, 0.25, accuracy: 1e-9)

        let (vertical, _) = feed(extent: 100, vertical: true)
        for (step, y) in [0.0, -20, -45].enumerated() {
            vertical.changed(CGSize(width: 0, height: y), at: t + Double(step) * 0.01)
        }
        XCTAssertEqual(vertical.page, 0.25, accuracy: 1e-9)
    }

    /// A5.4: a drag that passes the slop across the axis first is left
    /// alone to its end, for a scroll view inside the page (Flutter's
    /// gesture arena gives it to the vertical scrollable); the next drag
    /// along the axis pages again.
    func testA5_4ADragAcrossTheAxisIsLeftToTheScrollViewInside() {
        let (feed, events) = feed()
        let t = Date()
        feed.changed(.zero, at: t)
        feed.changed(CGSize(width: -5, height: -30), at: t + 0.01)
        feed.changed(CGSize(width: -150, height: -40), at: t + 0.02)
        feed.ended(at: t + 0.03)
        XCTAssertEqual(feed.page, 0)
        XCTAssertEqual(events.list, [])

        feed.changed(.zero, at: t + 1)
        feed.changed(CGSize(width: -20, height: 0), at: t + 1.01)
        feed.changed(CGSize(width: -70, height: 0), at: t + 1.02)
        XCTAssertEqual(feed.page, 0.25, accuracy: 1e-9)
    }

    /// A5.4: a release is a fling only while the finger was still moving
    /// (Flutter's iOS tracker takes no sample for 40 ms as a still finger):
    /// let go at once a fifth of the way on, the pager settles on page 1;
    /// held still first, it settles back on page 0.
    func testA5_4AReleaseIsAFlingOnlyWhileTheFingerStillMoves() {
        let (moving, _) = feed()
        Self.swipe(moving, to: -70, hold: 0)
        wait(until: { moving.page == 1 }, "a moving release did not settle on page 1: \(moving.page)")

        let (held, _) = feed()
        Self.swipe(held, to: -70, hold: 0.1)
        wait(until: { held.page == 0 }, "a held release did not settle back on page 0: \(held.page)")
    }

    /// A5.4: a quick 35-point swipe in 40 ms pages: the iOS tracker counts
    /// the finger from touch-down (Flutter's recognizer feeds it from the
    /// pointer down), so its travel is 35, past the 18 of the gate, though
    /// the pager took the drag only past the slop.
    func testA5_4AQuick35PointSwipePages() {
        let (feed, _) = feed()
        Self.swipe(feed, to: -35, over: 0.04, hold: 0.005)
        wait(until: { feed.page == 1 }, "a quick 35-point swipe did not page: \(feed.page)")
    }

    /// A5.4: the travel counts from touch-down, so a drag back near where
    /// the finger touched down is no fling, however fast: from page 1, left
    /// to -60 and quickly back right (about 1800 points a second) to 10
    /// points short of the touch, it settles on page 1 from 0.9; back to 20
    /// points past it, it flings back to page 0 from 0.75.
    func testA5_4ADragBackNearWhereItTouchedDownIsNoFling() {
        for (back, page) in [(-10.0, 1.0), (20, 0)] {
            let (feed, _) = feed(page: 1)
            let t = Date()
            for (step, x) in [0, -30, -60, -40, -25, back].enumerated() {
                feed.changed(CGSize(width: x, height: 0), at: t + Double(step) * 0.01)
            }
            feed.ended(at: t + 0.055)
            wait(until: { feed.page == page }, "back to \(back) did not settle on page \(page): \(feed.page)")
        }
    }

    /// A5.4: the iOS tracker has no window and no cut at a pause: a fast 40
    /// points, a 60 ms pause, then 5 more weighs to about -2483 points a
    /// second over 75 of travel, a fling, so the pager settles on page 1
    /// from 0.275.
    func testA5_4AReleaseAfterAPauseStillCountsTheWholeDrag() {
        let (feed, _) = feed()
        let t = Date()
        feed.changed(.zero, at: t)
        feed.changed(CGSize(width: -20, height: 0), at: t + 0.01)
        feed.changed(CGSize(width: -60, height: 0), at: t + 0.02)
        feed.changed(CGSize(width: -70, height: 0), at: t + 0.08)
        feed.changed(CGSize(width: -75, height: 0), at: t + 0.09)
        XCTAssertEqual(feed.page, 0.275, accuracy: 1e-9)
        feed.ended(at: t + 0.1)
        wait(until: { feed.page == 1 }, "a release after a pause did not fling: \(feed.page)")
    }

    /// A5.4: fewer pages (a new tree, the pager kept) bring a pager past the
    /// last one back to it, silently, as Flutter keeps the offset within the
    /// new extent; a settle aimed past the end stops on the last page and
    /// ends the scroll there.
    func testA5_4FewerPagesBringThePagerBackWithinThem() {
        let (feed, events) = feed(page: 4)
        feed.keepWithinPages(count: 2)
        XCTAssertEqual(feed.page, 1)
        XCTAssertEqual(events.list, [], "the correction scrolled")

        let (settling, settled) = self.feed(page: 3)
        Self.swipe(settling, to: -70)
        pump(0.05)
        XCTAssertGreaterThan(settling.page, 3.2, "no settle under way")
        settling.keepWithinPages(count: 2)
        XCTAssertEqual(settling.page, 1)
        XCTAssertEqual(settled.list.last?.trigger, "onScrollEnd")
        XCTAssertEqual(settled.list.last?.eventData["offset"], 200)
        let count = settled.list.count
        pump(0.5)
        XCTAssertEqual(settled.list.count, count, "the stopped settle went on")
        XCTAssertEqual(settling.page, 1)
    }

    /// A5.4: a new extent, or none, during a settle ends it on its page at
    /// once, onScrollEnd at page × the new extent, and leaves no settle
    /// behind (a touch then ends nothing).
    func testA5_4ANewExtentEndsASettleOnItsPage() {
        for extent in [300.0, 0] {
            let (feed, events) = feed()
            Self.swipe(feed, to: -70)
            pump(0.05)
            XCTAssertTrue(feed.page > 0.2 && feed.page < 1, "no settle under way: \(feed.page)")
            feed.update(extent: extent, count: 5, vertical: false, backwards: false) { events.list += $0 }
            wait(until: { events.list.last?.trigger == "onScrollEnd" }, "no onScrollEnd at extent \(extent)")
            XCTAssertEqual(feed.page, 1)
            XCTAssertEqual(events.list.last?.eventData["offset"], .double(extent))
            XCTAssertEqual(events.list.last?.eventData["viewportDimension"], .double(extent))
            let count = events.list.count
            feed.changed(.zero, at: Date())
            XCTAssertEqual(events.list.count, count, "a settle was left behind at extent \(extent)")
        }
    }

    #if canImport(UIKit)
    // MARK: hosted (a UIKit window: the view draws, builds pages and settles)

    /// A5.4: a swipe settles on the next page with an animation: onScrollBegin
    /// once, onScrolling on the way, and onScrollEnd at offset = page × width
    /// (200) with viewportDimension 200; page 1 then fills the box.
    func testA5_4ASettleEndsOnAPageAndOnScrollEndReportsPageTimesWidth() throws {
        let hosted = try HostedPager(pages(5, actions: triggers))
        defer { hosted.close() }

        hosted.swipe(to: -70)
        hosted.wait(until: { hosted.value("ends") == 1 }, "no onScrollEnd")

        XCTAssertEqual(hosted.feed.page, 1)
        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertGreaterThan(hosted.value("scrolls").doubleValue ?? 0, 2, "no onScrolling while it settled")
        XCTAssertEqual(hosted.value("endOffset"), 200)
        XCTAssertEqual(hosted.value("viewport"), 200)
        XCTAssertEqual(hosted.value("maxExtent"), 800)
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 0, width: 200, height: 100))
        XCTAssertNil(pixels.bounds(of: Self.red))
    }

    /// A5.4: each settle moves at most one page from where the finger let
    /// go, however fast: from page 0 (let go at 0.375) to 1, from 1 (let go
    /// at 1.475) to 2, and a drag of more than a page from 2 (let go at 3.2)
    /// to 4, each ending at page × 200.
    func testA5_4EachSettleMovesAtMostOnePageFromWhereTheFingerLetGo() throws {
        let hosted = try HostedPager(pages(5, actions: triggers))
        defer { hosted.close() }

        for (finger, over, page, ends) in [(-150.0, 0.02, 1.0, 1), (-190, 0.02, 2, 2), (-300, 0.05, 4, 3)] {
            hosted.swipe(to: finger, over: over)
            hosted.wait(until: { hosted.value("ends") == .int(ends) }, "no onScrollEnd \(ends)")
            XCTAssertEqual(hosted.feed.page, page)
            XCTAssertEqual(hosted.value("endOffset").doubleValue, page * 200)
        }
    }

    /// A5.4: only the pages in sight are built (Flutter's cache of 0
    /// viewports): at rest page 0 alone; a quarter of the way on, pages 0
    /// and 1, not 2; at rest on page 1 page 0 is dropped, so dragging back
    /// towards it builds it again, while page 2 is not built again.
    func testA5_4AtMostTwoPagesAreBuiltWhileBetweenPages() throws {
        let hosted = try HostedPager(pages(5))
        defer { hosted.close() }
        XCTAssertEqual(hosted.inits, [1, 0, 0, 0, 0])

        // 1,000 points a second: the spring settles on page 1 without
        // overshooting it (a faster fling overshoots, building page 2, as
        // Flutter's does).
        let t = Date()
        hosted.feed.changed(.zero, at: t)
        hosted.feed.changed(CGSize(width: -20, height: 0), at: t + 0.01)
        hosted.feed.changed(CGSize(width: -45, height: 0), at: t + 0.035)
        hosted.feed.changed(CGSize(width: -70, height: 0), at: t + 0.06)
        hosted.pump(0.3)
        XCTAssertEqual(hosted.inits, [1, 1, 0, 0, 0])
        hosted.feed.ended(at: t + 0.07)
        hosted.wait(until: { hosted.feed.page == 1 }, "did not settle on page 1")
        hosted.pump(0.3)

        let u = Date()
        hosted.feed.changed(.zero, at: u)
        hosted.feed.changed(CGSize(width: -20, height: 0), at: u + 0.01)
        hosted.feed.changed(CGSize(width: -70, height: 0), at: u + 0.02)
        hosted.pump(0.3)
        XCTAssertEqual(hosted.inits, [1, 1, 1, 0, 0])
        hosted.feed.changed(CGSize(width: 30, height: 0), at: u + 0.03)
        hosted.pump(0.3)
        XCTAssertEqual(hosted.feed.page, 0.75, accuracy: 1e-9)
        XCTAssertEqual(hosted.inits, [2, 1, 1, 0, 0])
        hosted.feed.ended(at: u + 0.5)
        hosted.wait(until: { hosted.feed.page == 1 }, "did not settle back on page 1")
    }

    /// A5.4: a pager on page 4 whose node comes back with two pages (a new
    /// tree, the pager kept) shows page 1, the last, not an empty box.
    func testA5_4APagerOnAPageThatIsGoneShowsTheLastPage() throws {
        let hosted = try HostedPager(pages(5) + [node("pv2", "PageView", [:], ["page0", "page1"])], page: 4)
        defer { hosted.close() }
        assertFrame(try hosted.pixels().bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 200, height: 100))

        try hosted.show("pv2")
        XCTAssertEqual(hosted.feed.page, 1)
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 0, width: 200, height: 100))
        XCTAssertNil(pixels.bounds(of: Self.magenta))
    }

    /// A5.4: with pageSnapping false the pages scroll freely: a scroll view
    /// moved to 300 stays there (half of page 1, half of page 2) and its
    /// onScrollEnd reports 300 of a maxExtent of 400. Reversed, page 0 sits
    /// at the far end, where the view starts.
    func testA5_4WithoutSnappingThePagesScrollFreely() throws {
        let hosted = try HostedPager(pages(3, ["pageSnapping": false], actions: triggers))
        defer { hosted.close() }
        assertFrame(try hosted.pixels().bounds(of: Self.red), CGRect(x: 0, y: 0, width: 200, height: 100))

        let scroll = try XCTUnwrap(hosted.scrollViews.first, "no scroll view")
        scroll.setContentOffset(CGPoint(x: 300, y: 0), animated: false)
        hosted.wait(until: { hosted.value("ends") == 1 }, "no onScrollEnd")
        hosted.pump(0.5)

        XCTAssertEqual(scroll.contentOffset.x, 300, accuracy: Self.accuracy, "the free view snapped")
        XCTAssertEqual(hosted.value("endOffset"), 300)
        XCTAssertEqual(hosted.value("maxExtent"), 400)
        XCTAssertEqual(hosted.value("viewport"), 200)
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 0, width: 100, height: 100))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 100, y: 0, width: 100, height: 100))

        let reversed = try HostedPager(pages(3, ["pageSnapping": false, "reverse": true]))
        defer { reversed.close() }
        let start = try reversed.pixels()
        assertFrame(start.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 200, height: 100))
        XCTAssertNil(start.bounds(of: Self.green))
    }

    /// A5.4: a vertical scroll view in a horizontal page still scrolls
    /// vertically, the pager standing still, and a vertical drag stays with
    /// it; a horizontal drag still pages, the scroll view left where it was.
    func testA5_4AVerticalScrollViewInAPageScrollsAndTheDragAlongStillPages() throws {
        let nodes = [
            node("pv", "PageView", [:], ["inner", "green"], actions: triggers),
            node("inner", "SingleChildScrollView", [:], ["tall"], actions: [
                "onScrollEnd": Self.sequence([Self.count("innerEnds"), Self.write("innerOffset", "offset")]),
            ]),
            box("tall", "#FF0000", 200, 600),
            box("green", "#00FF00"),
        ]
        let hosted = try HostedPager(nodes, height: 200)
        defer { hosted.close() }
        XCTAssertEqual(hosted.scrollViews.count, 1, "the snapping pager is not the only scroll view's parent")
        let inner = try XCTUnwrap(hosted.scrollViews.first)
        XCTAssertEqual(inner.bounds.size, CGSize(width: 200, height: 200))

        inner.setContentOffset(CGPoint(x: 0, y: 150), animated: false)
        hosted.wait(until: { hosted.value("innerEnds") == 1 }, "the scroll view inside did not scroll")
        XCTAssertEqual(hosted.value("innerOffset"), 150)
        XCTAssertEqual(hosted.value("begins"), 0, "the pager scrolled with the scroll view inside")

        let t = Date()
        hosted.feed.changed(.zero, at: t)
        hosted.feed.changed(CGSize(width: 3, height: -40), at: t + 0.01)
        hosted.feed.changed(CGSize(width: 5, height: -120), at: t + 0.02)
        hosted.feed.ended(at: t + 0.03)
        hosted.pump(0.3)
        XCTAssertEqual(hosted.feed.page, 0, "a vertical drag paged")
        XCTAssertEqual(hosted.value("begins"), 0)

        hosted.swipe(to: -70)
        hosted.wait(until: { hosted.value("ends") == 1 }, "the pager did not page")
        XCTAssertEqual(hosted.value("endOffset"), 200)
        XCTAssertEqual(hosted.value("innerEnds"), 1)
        XCTAssertEqual(inner.contentOffset.y, 150, accuracy: Self.accuracy)
    }

    /// A5.4: a drag along a pager inside a scroll view is the pager's alone
    /// (Flutter's arena gives it to the deepest drag recognizer; a real swipe
    /// up on a vertical pager in a vertical page on the iOS 18.5 simulator
    /// also scrolled the page). The pager puts a hold on the scroll view
    /// around it, which the scroll view's pan waits on and which keeps every
    /// touch going; it lets go of a drag across the axis (a vertical drag on
    /// a horizontal pager still scrolls the page, the slop rule the feed's
    /// tests pin). The hold goes when the pager leaves the window.
    func testA5_4ADragAlongAPagerIsNotAlsoTheScrollViewsAroundIt() throws {
        for direction in ["vertical", "horizontal"] {
            let hosted = try HostedPage([
                node("outer", "SingleChildScrollView", [:], ["pbox"]),
                node("pbox", "SizedBox", ["width": 200, "height": 400], ["pv"]),
            ] + pages(3, ["scrollDirection": .string(direction)]), root: "outer")
            defer { hosted.close() }
            XCTAssertEqual(hosted.scrollViews.count, 1, "\(direction): only the page's scroll view")
            let outer = try XCTUnwrap(hosted.scrollViews.first, "no scroll view")
            let holds = (outer.gestureRecognizers ?? []).filter { hold in
                hold.delegate?.gestureRecognizer?(hold, shouldBeRequiredToFailBy: outer.panGestureRecognizer) == true
            }
            XCTAssertEqual(holds.count, 1, "\(direction): no hold the page's pan waits on")
            for hold in holds {
                XCTAssertFalse(hold.cancelsTouchesInView, direction)
                XCTAssertFalse(hold.delaysTouchesBegan, direction)
                XCTAssertEqual(hold.delegate?.gestureRecognizer?(hold, shouldRecognizeSimultaneouslyWith:
                    outer.panGestureRecognizer), true, direction)
            }

            hosted.remove()
            XCTAssertTrue((outer.gestureRecognizers ?? []).allSatisfy { recognizer in
                !holds.contains { $0 === recognizer }
            }, "\(direction): the hold stayed on the scroll view")
        }
    }
    #endif

    // MARK: pages

    static let colours = ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF"]

    /// A PageView "pv" with `props` and `actions` over `count` pages, page i
    /// a Container of colours[i] whose onInit counts "init<i>".
    func pages(_ count: Int, _ props: [String: JSONValue] = [:],
               actions: [String: JSONValue] = [:]) -> [JSONValue] {
        [node("pv", "PageView", props, (0..<count).map { "page\($0)" }, actions: actions)]
            + (0..<count).map { index in
                node("page\(index)", "Container", ["color": .string(Self.colours[index])], [],
                     actions: ["onInit": Self.count("init\(index)")])
            }
    }

    /// begin counts; onScrolling counts and writes maxExtent; end counts and
    /// writes where it settled and the viewport.
    var triggers: [String: JSONValue] {
        [
            "onScrollBegin": Self.count("begins"),
            "onScrolling": Self.sequence([Self.count("scrolls"), Self.write("maxExtent", "maxExtent")]),
            "onScrollEnd": Self.sequence([Self.count("ends"), Self.write("endOffset", "offset"),
                                          Self.write("viewport", "viewportDimension")]),
        ]
    }

    static let keys = ["begins", "scrolls", "ends", "endOffset", "viewport", "maxExtent", "innerEnds", "innerOffset"]
        + (0..<5).map { "init\($0)" }

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

    /// A wire node: a PageView holds many children, the rest at most one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:], _ children: [String] = [],
              actions: [String: JSONValue] = [:]) -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": "layout",
            "childMode": type == "PageView" ? "multi" : children.isEmpty ? "none" : "single",
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
            "actions": .object(actions),
        ]
    }

    /// A Container of `hex`, `width` by `height` when set.
    func box(_ id: String, _ hex: String, _ width: Double? = nil, _ height: Double? = nil) -> JSONValue {
        var props: [String: JSONValue] = ["color": .string(hex)]
        if let width { props["width"] = .double(width) }
        if let height { props["height"] = .double(height) }
        return node(id, "Container", props)
    }

    /// The page, its registry widened by PageView (advertised only in group
    /// 8; the renderer degrades any type it lacks), its counters at 0.
    func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": .array(Self.keys.map { ["key": .string($0), "scope": "page", "initial": 0] }),
            "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["PageView"])))
    }

    /// The pager "pv" of `nodes`, 200 by 100, standing at `page`.
    func pager(_ nodes: [JSONValue], at page: Double) throws -> some View {
        let model = try model(nodes)
        return PagerView(node: try XCTUnwrap(model.resolve("pv"), "no pager"), model: model,
                         feed: PagerFeed(page: page))
            .frame(width: 200, height: 100)
    }

    /// A feed at `page` laid out as a pager of five pages `extent` long,
    /// and the events it fires.
    func feed(page: Double = 0, extent: Double = 200, vertical: Bool = false,
              backwards: Bool = false) -> (PagerFeed, Events) {
        let feed = PagerFeed(page: page)
        let events = Events()
        feed.update(extent: extent, count: 5, vertical: vertical, backwards: backwards) { events.list += $0 }
        return (feed, events)
    }

    /// A horizontal swipe from touch-down: the finger moves evenly to
    /// `finger` over `over` seconds, a sample every 10 ms (as a finger's
    /// moves come), and lifts after `hold`; the pager takes it where it
    /// passes the slop.
    static func swipe(_ feed: PagerFeed, to finger: Double, over: Double = 0.05, hold: Double = 0.01) {
        let t = Date()
        feed.changed(.zero, at: t)
        let steps = max(Int((over / 0.01).rounded()), 1)
        for step in 1...steps {
            let part = Double(step) / Double(steps)
            feed.changed(CGSize(width: finger * part, height: 0), at: t + over * part)
        }
        feed.ended(at: t + over + hold)
    }

    func pump(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func wait(until done: () -> Bool, _ message: @autoclosure () -> String, timeout: Double = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        while !done() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        XCTAssertTrue(done(), message())
    }

    // MARK: helpers

    typealias Pixel = (r: UInt8, g: UInt8, b: UInt8, a: UInt8)

    static func colour(_ r: Int, _ g: Int, _ b: Int) -> (Pixel) -> Bool {
        { p in p.a > 250 && abs(Int(p.r) - r) < 12 && abs(Int(p.g) - g) < 12 && abs(Int(p.b) - b) < 12 }
    }

    static let red = colour(255, 0, 0)
    static let green = colour(0, 255, 0)
    static let blue = colour(0, 0, 255)
    static let magenta = colour(255, 0, 255)
    static let grey = colour(128, 128, 128)
    static let background = Color(.sRGB, red: 128 / 255, green: 128 / 255, blue: 128 / 255)

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, _ message: String = "",
                     file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected) \(message)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected) \(message)", file: file, line: line)
        }
    }

    /// `content` drawn by ImageRenderer at scale 1 in a 300x300 box from the
    /// top leading corner, over a grey page.
    func draw<V: View>(_ content: V) throws -> Pixels {
        let renderer = ImageRenderer(content: content
            .frame(width: 300, height: 300, alignment: .topLeading)
            .background(Self.background))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}

/// What a feed fired, in order.
@MainActor
final class Events {
    var list: [ScrollEvent] = []
}

#if canImport(UIKit)
/// `root` in a UIKit window `width` by `height` (light), kept on screen
/// until `close`.
@MainActor
private class HostedWindow {
    let window: UIWindow

    init<Root: View>(_ root: Root, width: CGFloat, height: CGFloat) {
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        let host = UIHostingController(rootView: root
            .frame(width: width, height: height, alignment: .topLeading)
            .ignoresSafeArea())
        window = UIWindow(frame: frame)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = frame
        host.view.layoutIfNeeded()
        pump(0.3)
    }

    /// Every UIScrollView in the window.
    var scrollViews: [UIScrollView] {
        func find(_ view: UIView) -> [UIScrollView] {
            ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap(find)
        }
        return find(window)
    }

    func pump(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func close() {
        window.isHidden = true
    }
}

/// The pager "pv" of `nodes` in a hosted window `width` by `height` (scale
/// 1 pixels), driven through its feed.
@MainActor
private final class HostedPager: HostedWindow {
    let model: OrcaPageModel
    let feed: PagerFeed
    private let holder: NodeHolder

    init(_ nodes: [JSONValue], width: CGFloat = 200, height: CGFloat = 100, page: Double = 0) throws {
        let model = try PagerTests().model(nodes)
        let feed = PagerFeed(page: page)
        let holder = NodeHolder(try XCTUnwrap(model.resolve("pv"), "no pager"))
        self.model = model
        self.feed = feed
        self.holder = holder
        super.init(HeldPager(holder: holder, model: model, feed: feed), width: width, height: height)
    }

    func value(_ key: String) -> JSONValue { model.store.value(key) }

    /// The same pager drawn from the node `id` from now on, as a new tree's
    /// node in its place.
    func show(_ id: String) throws {
        holder.node = try XCTUnwrap(model.resolve(id), "no node \(id)")
        pump(0.3)
    }

    /// How many times each page's onInit ran.
    var inits: [Double] { (0..<5).map { value("init\($0)").doubleValue ?? -1 } }

    /// A horizontal swipe through the feed (PagerTests.swipe), then a pump.
    func swipe(to finger: Double, over: Double = 0.05) {
        PagerTests.swipe(feed, to: finger, over: over)
        pump(0.05)
    }

    func wait(until done: () -> Bool, _ message: @autoclosure () -> String, timeout: Double = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        while !done() && Date() < deadline { pump(0.05) }
        XCTAssertTrue(done(), message())
        pump(0.1)
    }

    func pixels() throws -> Pixels {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }
}

/// The node `root` of `nodes` in a hosted window `width` by `height`.
@MainActor
private final class HostedPage: HostedWindow {
    init(_ nodes: [JSONValue], root: String, width: CGFloat = 200, height: CGFloat = 200) throws {
        let model = try PagerTests().model(nodes)
        super.init(NodeView(id: root, model: model), width: width, height: height)
    }

    /// Takes the page out of the window.
    func remove() {
        window.rootViewController = nil
        pump(0.3)
    }
}

/// The node a hosted pager is drawn from.
private final class NodeHolder: ObservableObject {
    @Published var node: ResolvedNode

    init(_ node: ResolvedNode) {
        self.node = node
    }
}

/// A pager drawn from the held node, keeping its view (and feed) as the node changes.
private struct HeldPager: View {
    @ObservedObject var holder: NodeHolder
    let model: OrcaPageModel
    let feed: PagerFeed

    var body: some View {
        PagerView(node: holder.node, model: model, feed: feed)
    }
}
#endif
#endif
