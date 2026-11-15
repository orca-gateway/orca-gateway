#if canImport(SwiftUI)
import XCTest

@testable import OrcaGateway

/// AnimatedBuilder's clock (Flutter `forward` / `repeat(reverse:)`) and curves.
@MainActor
final class MotionTests: XCTestCase {
    func testOneShotClampsAtTheEnd() {
        XCTAssertEqual(AnimatedBuilderView.clock(elapsed: 0.5, duration: 1, repeats: false, reverse: false, autoStart: true), 0.5)
        XCTAssertEqual(AnimatedBuilderView.clock(elapsed: 3, duration: 1, repeats: false, reverse: false, autoStart: true), 1)
    }

    func testRepeatWrapsAndReverseBouncesBack() {
        XCTAssertEqual(AnimatedBuilderView.clock(elapsed: 1.25, duration: 1, repeats: true, reverse: false, autoStart: true), 0.25, accuracy: 1e-9)
        XCTAssertEqual(AnimatedBuilderView.clock(elapsed: 1.25, duration: 1, repeats: true, reverse: true, autoStart: true), 0.75, accuracy: 1e-9)
    }

    func testNoAutoStartHoldsAtZero() {
        XCTAssertEqual(AnimatedBuilderView.clock(elapsed: 5, duration: 1, repeats: true, reverse: false, autoStart: false), 0)
    }

    func testCurvesKeepTheirEndsAndShape() {
        for name in ["linear", "easeIn", "easeOut", "easeInOut", "fastOutSlowIn"] {
            XCTAssertEqual(OrcaCurve.apply(name, 0), 0)
            XCTAssertEqual(OrcaCurve.apply(name, 1), 1)
        }
        XCTAssertLessThan(OrcaCurve.apply("easeIn", 0.5), 0.5)
        XCTAssertGreaterThan(OrcaCurve.apply("easeOut", 0.5), 0.5)
        XCTAssertEqual(OrcaCurve.apply("easeInOut", 0.5), 0.5, accuracy: 1e-3)
    }
}
#endif
