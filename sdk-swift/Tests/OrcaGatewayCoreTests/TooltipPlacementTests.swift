import XCTest

@testable import OrcaGatewayCore

/// A8.3, the core half of Tooltip: where the bubble goes and how long it
/// takes, Flutter's Material Tooltip as `positionDependentBox` places it
/// (painting/geometry.dart:42-68) with MUI tooltip.dart's defaults
/// (:413-416: vertical offset 24, prefer below, 1.5 s after release) and
/// RawTooltip's fade (widgets/raw_tooltip.dart:27-31). The child's rect,
/// the bubble's size and the overlay's size in one coordinate space; the
/// target is the child's centre. A 400 x 800 overlay and a 100 x 32 bubble
/// unless said. The same cases as Kotlin's TooltipPlacementTest.
final class TooltipPlacementTests: XCTestCase {
    private let overlay = TooltipPlacement.Size(width: 400, height: 800)
    private let bubble = TooltipPlacement.Size(width: 100, height: 32)

    private func origin(_ x: Double, _ y: Double, _ width: Double, _ height: Double,
                        bubble: TooltipPlacement.Size? = nil,
                        overlay: TooltipPlacement.Size? = nil) -> TooltipPlacement.Origin {
        TooltipPlacement.origin(child: TooltipPlacement.Rect(x: x, y: y, width: width, height: height),
                                bubble: bubble ?? self.bubble, overlay: overlay ?? self.overlay)
    }

    /// A8.3: the bubble's centre sits on the child's centre across, whatever
    /// the two widths (geometry.dart:66, target.dx − width / 2).
    func testA8_3_TheBubbleIsCentredOnTheChild() {
        XCTAssertEqual(origin(150, 100, 100, 40).x, 150, accuracy: 1e-9)
        XCTAssertEqual(origin(190, 100, 20, 20).x, 150, accuracy: 1e-9, "a child narrower than the bubble")
        XCTAssertEqual(origin(50, 100, 300, 40).x, 150, accuracy: 1e-9, "a child wider than the bubble")
        XCTAssertEqual(origin(50, 100, 200, 40).x, 100, accuracy: 1e-9, "a child wider, centre 150 (Kotlin's `wide`)")
        XCTAssertEqual(origin(60, 300, 80, 40).x, 50, accuracy: 1e-9, "a child left of the middle")
        XCTAssertEqual(origin(150, 100, 100, 40, bubble: .init(width: 60, height: 32)).x, 170, accuracy: 1e-9,
                       "a 60-wide bubble")
    }

    /// A8.3: the bubble's top is 24 below the child's centre, not its
    /// bottom edge (geometry.dart:56; tooltip.dart:413 verticalOffset 24,
    /// :414 preferBelow), so a tall child is overlapped.
    func testA8_3_TheBubbleSits24BelowTheChildsCentre() {
        XCTAssertEqual(origin(150, 100, 100, 40), .init(x: 150, y: 144))
        XCTAssertEqual(origin(180, 100, 40, 60), .init(x: 150, y: 154), "centre 130 (Kotlin's row)")
        XCTAssertEqual(origin(150, 100, 100, 200), .init(x: 150, y: 224), "a tall child: centre 200")
        XCTAssertEqual(origin(150, 0, 100, 20), .init(x: 150, y: 34), "at the top: above cannot fit")
    }

    /// A8.3: below fits when its bottom is at most 10 above the overlay's
    /// bottom (geometry.dart:51, `<=`); when it does not and above fits
    /// (its top at least 10 below the overlay's top, :52), the bubble's
    /// bottom is 24 above the child's centre (:58). When neither side
    /// fits it stays below (preferBelow, :53), its top at most 10 above the
    /// overlay's bottom (:56), running past it.
    func testA8_3_TheBubbleGoesAboveWhenBelowDoesNotFit() {
        XCTAssertEqual(origin(150, 724, 100, 20), .init(x: 150, y: 758), "centre 734: bottom exactly at 790")
        XCTAssertEqual(origin(150, 725, 100, 20), .init(x: 150, y: 679), "centre 735: bottom would be at 791")
        XCTAssertEqual(origin(150, 760, 100, 40), .init(x: 150, y: 724), "a child at the bottom")
        let tallest = TooltipPlacement.Size(width: 100, height: 780)
        XCTAssertEqual(origin(180, 380, 40, 40, bubble: tallest), .init(x: 150, y: 424),
                       "neither side fits: below, 24 under centre 400 (Kotlin's `middle`)")
        XCTAssertEqual(origin(180, 760, 40, 40, bubble: tallest), .init(x: 150, y: 790),
                       "neither side fits: top held at 790, not 804 (Kotlin's `low`)")
        let short = TooltipPlacement.Size(width: 400, height: 100)
        let tall = TooltipPlacement.Size(width: 100, height: 80)
        XCTAssertEqual(origin(150, 60, 100, 20, bubble: tall, overlay: short), .init(x: 150, y: 90),
                       "neither side fits: below, its top held at 100 - 10")
    }

    /// A8.3: the bubble keeps 10 from the overlay's left and right edges
    /// (geometry.dart:48 margin 10, :66 the clamp).
    func testA8_3_TheBubbleIsClampedTenFromTheEdges() {
        XCTAssertEqual(origin(0, 100, 40, 40).x, 10, accuracy: 1e-9, "at the left edge")
        XCTAssertEqual(origin(380, 100, 20, 40).x, 290, accuracy: 1e-9, "at the right edge: 400 - 100 - 10")
        XCTAssertEqual(origin(40, 100, 40, 40).x, 10, accuracy: 1e-9, "centre 60: exactly 10")
        XCTAssertEqual(origin(41, 100, 40, 40).x, 11, accuracy: 1e-9, "centre 61: inside the margin")
    }

    /// A8.3: a bubble with 20 or less to spare across (the overlay's width
    /// less twice the margin, `<=`) is centred in the overlay, whatever the
    /// child (geometry.dart:61-66). The rows past the overlay's width are
    /// the formula's arithmetic only: Flutter never lays a bubble out wider
    /// than the overlay (`constraints.loosen()`, raw_tooltip.dart:993).
    func testA8_3_ABubbleWiderThanTheOverlayLessTwentyIsCentredInTheOverlay() {
        func x(_ childX: Double, _ width: Double) -> Double {
            origin(childX, 100, 20, 40, bubble: .init(width: width, height: 32)).x
        }
        XCTAssertEqual(x(0, 380), 10, accuracy: 1e-9, "exactly 20 spare")
        XCTAssertEqual(x(0, 390), 5, accuracy: 1e-9, "10 spare, the child at the left")
        XCTAssertEqual(x(380, 390), 5, accuracy: 1e-9, "10 spare, the child at the right")
        XCTAssertEqual(x(0, 420), -10, accuracy: 1e-9, "20 too wide")
        XCTAssertEqual(x(380, 379), 11, accuracy: 1e-9, "21 spare: clamped, not centred")
    }

    /// A8.3: a long press of 500 ms (gestures/constants.dart:29), gone
    /// 1.5 s after release (tooltip.dart:416, :570; raw_tooltip.dart:766),
    /// a fade in of 150 ms and out of 75 (raw_tooltip.dart:27-31); 24 and
    /// 10 as above.
    func testA8_3_TheTimingsAreFlutters() {
        XCTAssertEqual(TooltipPlacement.longPressMs, 500)
        XCTAssertEqual(TooltipPlacement.showDurationMs, 1500)
        XCTAssertEqual(TooltipPlacement.fadeInMs, 150)
        XCTAssertEqual(TooltipPlacement.fadeOutMs, 75)
        XCTAssertEqual(TooltipPlacement.verticalOffset, 24)
        XCTAssertEqual(TooltipPlacement.margin, 10)
    }
}
