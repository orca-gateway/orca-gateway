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
    /// axis within the velocity window (the last 100 ms) for a release to be
    /// a fling: ScrollPhysics `minFlingDistance`, kTouchSlop
    /// (scroll_physics.dart:480, gestures/constants.dart:65), the same on
    /// iOS (Bouncing keeps it).
    public static let minFlingDistance: Double = 18

    /// The page to settle on from `offset` with the release `velocity`
    /// (positive toward later pages) after the finger travelled
    /// `travel` along the axis in the velocity window (either sign).
    /// The release is a fling only past both gates of the drag recognizer's
    /// `isFlingGesture` (gestures/monodrag.dart, both `>`): its speed above
    /// `minFlingVelocity` and its travel above `minFlingDistance`; else the
    /// physics gets a velocity of 0. A fling adds half a page in its
    /// direction, then the page is rounded half away from zero (Dart's
    /// `roundToDouble`), so it moves at most one page from where the finger
    /// let go; kept within 0 ... pageCount - 1 (Flutter's parent physics
    /// brings a view let go past an end back to it). Nil with
    /// `pageSnapping` false (the view scrolls freely), no pages or no extent.
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
    /// with: `velocity` when it is a fling (past both gates, see `target`),
    /// else 0, as the drag recognizer's DragEndDetails.
    public static func flingVelocity(_ velocity: Double, travel: Double,
                                     minFlingVelocity: Double = PageSnap.minFlingVelocity,
                                     minFlingDistance: Double = PageSnap.minFlingDistance) -> Double {
        abs(velocity) > minFlingVelocity && abs(travel) > minFlingDistance ? velocity : 0
    }
}
