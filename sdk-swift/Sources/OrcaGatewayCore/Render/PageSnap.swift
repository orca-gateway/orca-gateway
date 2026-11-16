import Foundation

/// Where a PageView with `pageSnapping` settles when the finger lets go,
/// Flutter's `PageScrollPhysics` (widgets/page_view.dart:603-611) for the
/// PageView its builder makes (layout_builders.dart:668-684): no controller,
/// so viewportFraction 1 and page = offset / viewport extent. Offsets and
/// velocities count toward later pages along the scroll axis, whichever way
/// the axis is drawn (reverse, right-to-left), as Flutter's scroll offset
/// does; a UI maps its finger to them.
public enum PageSnap {
    /// The speed, in points per second, a release must pass to be a fling:
    /// iOS's, BouncingScrollPhysics `minFlingVelocity`, kMinFlingVelocity × 2
    /// (widgets/scroll_physics.dart:905).
    public static let minFlingVelocity: Double = 100

    /// How far, in points, the finger must also have travelled along the
    /// axis by the release's estimate (its offset, newest minus oldest
    /// sample) for a release to be a fling: ScrollPhysics
    /// `minFlingDistance`, kTouchSlop (scroll_physics.dart:480,
    /// gestures/constants.dart:65), the same on iOS (Bouncing keeps it). On
    /// iOS the estimate is IOSFlingTracker's, the last 20 samples from
    /// touch-down; Android's (Kotlin) is the windowed VelocityTracker's.
    public static let minFlingDistance: Double = 18

    /// The most a fling's speed can be, kMaxFlingVelocity (gestures/
    /// constants.dart:95), points per second: BouncingScrollPhysics'
    /// normal deceleration keeps it.
    public static let maxFlingVelocity: Double = 8000

    /// The page to settle on from `offset` with the release `velocity`
    /// (positive toward later pages) and `travel`, the finger's travel
    /// along the axis by the release's estimate (either sign; IOSFlingTracker
    /// on iOS). The release is a fling only past both gates of the drag
    /// recognizer's `isFlingGesture` (gestures/monodrag.dart, both `>`): its
    /// speed above `minFlingVelocity` and its travel above
    /// `minFlingDistance`; else the physics gets a velocity of 0. A fling
    /// adds half a page in its direction, then the page is rounded half away
    /// from zero (Dart's `roundToDouble`), so it moves at most one page from
    /// where the finger let go; kept within 0 ... pageCount - 1 (Flutter's
    /// parent physics brings a view let go past an end back to it). Nil
    /// with `pageSnapping` false (the view scrolls freely), no pages or no
    /// extent.
    public static func target(offset: Double, viewportExtent: Double, velocity: Double, travel: Double,
                              pageCount: Int, pageSnapping: Bool = true,
                              minFlingVelocity: Double = PageSnap.minFlingVelocity,
                              minFlingDistance: Double = PageSnap.minFlingDistance) -> Int? {
        guard pageSnapping, pageCount > 0, viewportExtent > 0, offset.isFinite else { return nil }
        let fling = flingVelocity(velocity, travel: travel, minFlingVelocity: minFlingVelocity,
                                  minFlingDistance: minFlingDistance)
        var page = offset / viewportExtent
        if fling != 0 { page += fling > 0 ? 0.5 : -0.5 }
        return min(max(Int(page.rounded()), 0), pageCount - 1)
    }

    /// The velocity the physics gets for a release, which a settle starts
    /// with: `velocity` held within ±maxFlingVelocity when it is a fling
    /// (past both gates, see `target`), else 0, as the drag recognizer's
    /// `considerFling` and DragEndDetails make it.
    public static func flingVelocity(_ velocity: Double, travel: Double,
                                     minFlingVelocity: Double = PageSnap.minFlingVelocity,
                                     minFlingDistance: Double = PageSnap.minFlingDistance) -> Double {
        guard abs(velocity) > minFlingVelocity && abs(travel) > minFlingDistance else { return 0 }
        return min(max(velocity, -maxFlingVelocity), maxFlingVelocity)
    }

    /// Flutter's IOSScrollViewFlingVelocityTracker (gestures/velocity_tracker
    /// .dart:295-397), the tracker Flutter's scrollables give each pointer
    /// on iOS (widgets/scroll_configuration.dart:213-224), along one axis:
    /// the last `sampleSize` positions of a touch from touch-down, times in
    /// seconds. No 100 ms window and no cut at a pause, unlike Android's
    /// VelocityTracker.
    public struct IOSFlingTracker: Sendable {
        /// `_sampleSize`.
        public static let sampleSize = 20
        /// `_assumePointerMoveStoppedMilliseconds`, in seconds: no sample
        /// for longer is a still finger.
        public static let stoppedAfter: Double = 0.04

        private var samples: [Sample] = []

        private struct Sample: Sendable {
            var time: Double
            var position: Double
        }

        public init() {}

        /// The touch at `position` at `time` (not before the last); the
        /// oldest of more than `sampleSize` goes.
        public mutating func add(time: Double, position: Double) {
            samples.append(Sample(time: time, position: position))
            if samples.count > Self.sampleSize { samples.removeFirst() }
        }

        /// The estimate at the release, `now`: the velocity 0.6 · v(-2) +
        /// 0.35 · v(-1) + 0.05 · v(0) over the last three pairs of adjacent
        /// samples (v(0) the newest pair; a pair missing or with no time
        /// between counts 0), and the travel, newest minus oldest sample (the
        /// estimate's offset, which `isFlingGesture` checks). Both 0 with
        /// no sample or none for more than `stoppedAfter` before `now`.
        public func estimate(now: Double) -> (velocity: Double, travel: Double) {
            guard let newest = samples.last, now - newest.time <= Self.stoppedAfter else { return (0, 0) }
            func pair(_ index: Int) -> Double {
                let end = samples.count - 1 + index
                guard end >= 1 else { return 0 }
                let time = samples[end].time - samples[end - 1].time
                return time > 0 ? (samples[end].position - samples[end - 1].position) / time : 0
            }
            return (0.6 * pair(-2) + 0.35 * pair(-1) + 0.05 * pair(0), newest.position - samples[0].position)
        }
    }
}
