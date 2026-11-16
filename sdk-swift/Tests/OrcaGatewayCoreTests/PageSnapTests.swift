import XCTest

@testable import OrcaGatewayCore

/// A5.4, the core half of PageView: where a snapping PageView settles when
/// the finger lets go, Flutter's `PageScrollPhysics._getTargetPixels`
/// (widgets/page_view.dart:603-611) as its builder makes it (layout_builders
/// .dart:668-684: no controller, so page = offset / viewport extent). A
/// release velocity reaches the physics only past the drag recognizer's
/// two gates (`isFlingGesture`, gestures/monodrag.dart, both `>`): its
/// speed passes the minimum fling velocity, on iOS BouncingScrollPhysics'
/// kMinFlingVelocity × 2 = 100 points per second (widgets/scroll_physics
/// .dart:905), and the finger travelled more than the minimum fling
/// distance, kTouchSlop = 18 points (scroll_physics.dart `minFlingDistance`),
/// within the velocity window (the estimate's offset, newest minus oldest
/// sample of the last 100 ms, gestures/velocity_tracker.dart); below either
/// the velocity is 0. A fling adds half a page in its direction, then the
/// page is rounded half away from zero (Dart's `roundToDouble`), and kept
/// within the pages. Offsets and velocities count toward later pages,
/// whichever way the axis is drawn. A 200-point viewport over five pages
/// and 100 points of travel unless said. The same cases as
/// Kotlin's PageSnapTest.
final class PageSnapTests: XCTestCase {
    private func target(_ offset: Double, _ velocity: Double = 0, travel: Double = 100, extent: Double = 200,
                        count: Int = 5, snapping: Bool = true, minFling: Double = PageSnap.minFlingVelocity,
                        minDistance: Double = PageSnap.minFlingDistance) -> Int? {
        PageSnap.target(offset: offset, viewportExtent: extent, velocity: velocity, travel: travel,
                        pageCount: count, pageSnapping: snapping, minFlingVelocity: minFling,
                        minFlingDistance: minDistance)
    }

    /// A5.4: let go at rest on a page, the view stays on it.
    func testA5_4AtRestOnAPageItStaysThere() {
        XCTAssertEqual(target(0), 0)
        XCTAssertEqual(target(400), 2)
        XCTAssertEqual(target(375 * 3, extent: 375), 3)
    }

    /// A5.4: a slow release settles on the nearest page; exactly half way
    /// rounds away from zero, to the later page (Dart's `roundToDouble`).
    func testA5_4ASlowReleaseSettlesOnTheNearestPage() {
        XCTAssertEqual(target(290), 1)
        XCTAssertEqual(target(310), 2)
        XCTAssertEqual(target(300), 2)
        XCTAssertEqual(target(375 * 2.6, extent: 375), 3)
        XCTAssertEqual(target(290, 50), 1)
        XCTAssertEqual(target(310, -50), 2)
    }

    /// A5.4: a fling past the minimum velocity goes half a page further in
    /// its direction, then rounds: from page 1.05 a forward fling settles on
    /// 2 and a backward one on 1; from 1.75 a backward fling settles on 1.
    func testA5_4AFlingGoesHalfAPageFurtherInItsDirectionThenRounds() {
        XCTAssertEqual(target(210, 101), 2)
        XCTAssertEqual(target(210, -101), 1)
        XCTAssertEqual(target(290, -101), 1)
        XCTAssertEqual(target(290, 101), 2)
        XCTAssertEqual(target(350, -101), 1)
    }

    /// A5.4: however fast, a fling moves at most one page from where the
    /// finger let go: from 1.95 forward it settles on 2, backward on 1;
    /// from 0.05 forward on 1.
    func testA5_4AtMostOnePagePerFlingFromWhereTheFingerLetGo() {
        XCTAssertEqual(target(390, 8000), 2)
        XCTAssertEqual(target(390, -8000), 1)
        XCTAssertEqual(target(10, 8000), 1)
    }

    /// A5.4: the velocity must pass the minimum, not reach it: 100 points
    /// per second on iOS is no fling, 100.5 is; a lower minimum lets 60 fling.
    func testA5_4TheVelocityMustPassTheMinimumFlingVelocity() {
        XCTAssertEqual(PageSnap.minFlingVelocity, 100)
        XCTAssertEqual(target(210, 100), 1)
        XCTAssertEqual(target(210, -100), 1)
        XCTAssertEqual(target(210, 100.5), 2)
        XCTAssertEqual(target(210, 60), 1)
        XCTAssertEqual(target(210, 60, minFling: 50), 2)
    }

    /// A5.4: a fling must also travel past the minimum distance (kTouchSlop,
    /// 18 points) in its last 100 ms, not reach it: 150 points a second
    /// (past iOS's 100) with 10 points of travel settles on the nearest
    /// page, 300 with 30 turns it; 18 is no fling, 18.5 is; a backward
    /// travel counts by its length; a smaller minimum lets 10 points fling.
    func testA5_4AFlingMustAlsoTravelPastTheMinimumFlingDistance() {
        XCTAssertEqual(PageSnap.minFlingDistance, 18)
        XCTAssertEqual(target(210, 150, travel: 10), 1)
        XCTAssertEqual(target(210, 300, travel: 30), 2)
        XCTAssertEqual(target(210, 300, travel: 18), 1)
        XCTAssertEqual(target(210, 300, travel: 18.5), 2)
        XCTAssertEqual(target(310, -300, travel: -30), 1)
        XCTAssertEqual(target(310, -300, travel: -10), 2)
        XCTAssertEqual(target(210, 150, travel: 10, minDistance: 5), 2)
    }

    /// A5.4: the velocity the physics gets, which the settle starts with,
    /// is the release's past both gates and 0 below either (the drag
    /// recognizer's DragEndDetails): 300 over 30 is 300, -300 over -30 is
    /// -300; 300 over 10 and 100 over 30 are 0.
    func testA5_4TheFlingVelocityIsTheReleasesPastBothGatesElseZero() {
        XCTAssertEqual(PageSnap.flingVelocity(300, travel: 30), 300)
        XCTAssertEqual(PageSnap.flingVelocity(-300, travel: -30), -300)
        XCTAssertEqual(PageSnap.flingVelocity(300, travel: 10), 0)
        XCTAssertEqual(PageSnap.flingVelocity(100, travel: 30), 0)
        XCTAssertEqual(PageSnap.flingVelocity(60, travel: 30, minFlingVelocity: 50), 60)
    }

    /// A5.4: the target stays within the pages: a fling back from the first
    /// page or on from the last stays there, and a drag let go past either
    /// end comes back to it.
    func testA5_4TheTargetIsKeptWithinThePages() {
        XCTAssertEqual(target(0, -1000), 0)
        XCTAssertEqual(target(800, 1000), 4)
        XCTAssertEqual(target(-30), 0)
        XCTAssertEqual(target(-30, 1000), 0)
        XCTAssertEqual(target(830), 4)
        XCTAssertEqual(target(0, 1000, count: 1), 0)
    }

    /// A5.4: nothing to settle on with pageSnapping false (the view scrolls
    /// freely), with no pages or before the viewport has an extent.
    func testA5_4NoTargetWhenSnappingIsOffOrThereIsNothingToSnapTo() {
        XCTAssertNil(target(210, 101, snapping: false))
        XCTAssertNil(target(0, count: 0))
        XCTAssertNil(target(210, 101, extent: 0))
    }
}
