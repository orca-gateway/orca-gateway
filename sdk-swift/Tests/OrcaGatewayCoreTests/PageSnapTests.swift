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
/// by the estimate's offset; below either the velocity is 0. On iOS the
/// estimate is IOSScrollViewFlingVelocityTracker's (IOSFlingTracker below:
/// the last 20 samples from touch-down, gestures/velocity_tracker.dart
/// :295-397); Kotlin's Android one is the windowed VelocityTracker. A fling
/// adds half a page in its direction, then the page is rounded half away
/// from zero (Dart's `roundToDouble`), and kept within the pages. Offsets
/// and velocities count toward later pages, whichever way the axis is
/// drawn. A 200-point viewport over five pages and 100 points of travel
/// unless said. The same cases as Kotlin's PageSnapTest, plus the iOS
/// tracker's.
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
    /// 18 points) by its estimate, not reach it: 150 points a second
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
    /// -300; 300 over 10 and 100 over 30 are 0; past kMaxFlingVelocity
    /// (8000) it is held there (the recognizer's `considerFling`).
    func testA5_4TheFlingVelocityIsTheReleasesPastBothGatesElseZero() {
        XCTAssertEqual(PageSnap.flingVelocity(300, travel: 30), 300)
        XCTAssertEqual(PageSnap.flingVelocity(-300, travel: -30), -300)
        XCTAssertEqual(PageSnap.flingVelocity(300, travel: 10), 0)
        XCTAssertEqual(PageSnap.flingVelocity(100, travel: 30), 0)
        XCTAssertEqual(PageSnap.flingVelocity(60, travel: 30, minFlingVelocity: 50), 60)
        XCTAssertEqual(PageSnap.maxFlingVelocity, 8000)
        XCTAssertEqual(PageSnap.flingVelocity(9000, travel: 30), 8000)
        XCTAssertEqual(PageSnap.flingVelocity(-9000, travel: -30), -8000)
    }

    // MARK: IOSFlingTracker (IOSScrollViewFlingVelocityTracker)

    private func tracker(_ samples: [(Double, Double)]) -> PageSnap.IOSFlingTracker {
        var tracker = PageSnap.IOSFlingTracker()
        for (time, position) in samples { tracker.add(time: time, position: position) }
        return tracker
    }

    /// A5.4: the iOS estimate weighs the last three pairs of samples 0.6,
    /// 0.35 and 0.05, the oldest most, with no window and no cut at a
    /// pause, and its travel is newest minus oldest: 0, -20, -60 ten ms
    /// apart, a 60 ms pause, -70, -75 is about -2483 points a second
    /// (0.6 × -4000 + 0.35 × -166.7 + 0.05 × -500) over -75 points.
    func testA5_4TheIOSTrackerWeighsItsLastThreePairsAcrossAPause() {
        let estimate = tracker([(0, 0), (0.01, -20), (0.02, -60), (0.08, -70), (0.09, -75)]).estimate(now: 0.1)
        XCTAssertEqual(estimate.velocity, -2483.333, accuracy: 0.01)
        XCTAssertEqual(estimate.travel, -75, accuracy: 1e-9)
    }

    /// A5.4: no sample for more than 40 ms before the release is a still
    /// finger: no speed and no travel (`_assumePointerMoveStoppedMilliseconds`);
    /// 40 ms after 0, -20, -40 it still moves at 0.35 × -2000 + 0.05 × -2000
    /// (the third pair back is missing).
    func testA5_4TheIOSTrackerIsStillAfter40Ms() {
        let moving = tracker([(0, 0), (0.01, -20), (0.02, -40)])
        XCTAssertEqual(PageSnap.IOSFlingTracker.stoppedAfter, 0.04)
        XCTAssertEqual(moving.estimate(now: 0.06).velocity, -800, accuracy: 1e-6)
        XCTAssertEqual(moving.estimate(now: 0.06).travel, -40, accuracy: 1e-9)
        XCTAssertEqual(moving.estimate(now: 0.061).velocity, 0)
        XCTAssertEqual(moving.estimate(now: 0.061).travel, 0)
    }

    /// A5.4: the iOS tracker keeps the last 20 samples: 25 positions 0 ... 24
    /// ten ms apart travel 24 - 5 = 19 at 100 points a second.
    func testA5_4TheIOSTrackerKeepsTheLast20Samples() {
        XCTAssertEqual(PageSnap.IOSFlingTracker.sampleSize, 20)
        let estimate = tracker((0..<25).map { (Double($0) * 0.01, Double($0)) }).estimate(now: 0.25)
        XCTAssertEqual(estimate.velocity, 100, accuracy: 1e-6)
        XCTAssertEqual(estimate.travel, 19, accuracy: 1e-9)
    }

    /// A5.4: a missing pair, or one with no time between its samples, counts
    /// 0: one sample is no speed and no travel; two 10 ms apart 10 points
    /// are 0.05 × 1000; nothing added is no estimate.
    func testA5_4TheIOSTrackerCountsAMissingPairAsZero() {
        XCTAssertEqual(tracker([(0, 5)]).estimate(now: 0).velocity, 0)
        XCTAssertEqual(tracker([(0, 5)]).estimate(now: 0).travel, 0)
        XCTAssertEqual(tracker([(0, 0), (0.01, 10)]).estimate(now: 0.01).velocity, 50, accuracy: 1e-6)
        XCTAssertEqual(tracker([(0, 0), (0, 10)]).estimate(now: 0).velocity, 0)
        XCTAssertEqual(tracker([]).estimate(now: 0).velocity, 0)
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
