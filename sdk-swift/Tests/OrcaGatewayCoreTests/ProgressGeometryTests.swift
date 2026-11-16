import XCTest

@testable import OrcaGatewayCore

/// A7.3, the core half of CircularProgressIndicator and
/// LinearProgressIndicator: the geometry and colours Flutter's builders
/// paint with (sdk/lib/src/builders/primitive_builders.dart: Circular
/// :302-323 and its painter :465-513, Linear :364-384 and its painter
/// :435-463), not Material's indicators. Angles in radians, clockwise from
/// 3 o'clock; colours ARGB as Flutter's `Color`. The same cases and numbers
/// as Kotlin's ProgressGeometryTest.
final class ProgressGeometryTests: XCTestCase {
    private func assertArc(_ arc: ProgressGeometry.Arc, start: Double, sweep: Double, track: Bool, draws: Bool,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(arc.startRad, start, accuracy: 1e-12, "startRad", file: file, line: line)
        XCTAssertEqual(arc.sweepRad, sweep, accuracy: 1e-12, "sweepRad", file: file, line: line)
        XCTAssertEqual(arc.track, track, "track", file: file, line: line)
        XCTAssertEqual(arc.drawsArc, draws, "drawsArc", file: file, line: line)
    }

    // MARK: A7.3 Circular

    /// A7.3: the stroke is strokeWidth, 3 when absent or not above 0 (NaN
    /// too).
    func testA7_3CircularStrokeDefaultsTo3AndNonPositiveIs3() {
        XCTAssertEqual(ProgressGeometry.circularStroke(nil), 3)
        XCTAssertEqual(ProgressGeometry.circularStroke(0), 3)
        XCTAssertEqual(ProgressGeometry.circularStroke(-2), 3)
        XCTAssertEqual(ProgressGeometry.circularStroke(.nan), 3)
        XCTAssertEqual(ProgressGeometry.circularStroke(6), 6)
        XCTAssertEqual(ProgressGeometry.circularStroke(0.5), 0.5)
    }

    /// A7.3: the indicator is 36 square; it draws in its box inset by half
    /// the stroke on every side (a forced box that is not square draws an
    /// ellipse, a box narrower than the stroke an empty rect).
    func testA7_3TheCircularIs36SquareAndInsetByHalfTheStroke() {
        XCTAssertEqual(ProgressGeometry.circularSize, 36)
        XCTAssertEqual(ProgressGeometry.circularRect(width: 36, height: 36, strokeWidth: 3),
                       ProgressGeometry.Rect(x: 1.5, y: 1.5, width: 33, height: 33))
        XCTAssertEqual(ProgressGeometry.circularRect(width: 36, height: 36, strokeWidth: 6),
                       ProgressGeometry.Rect(x: 3, y: 3, width: 30, height: 30))
        XCTAssertEqual(ProgressGeometry.circularRect(width: 80, height: 36, strokeWidth: 4),
                       ProgressGeometry.Rect(x: 2, y: 2, width: 76, height: 32))
        XCTAssertEqual(ProgressGeometry.circularRect(width: 2, height: 2, strokeWidth: 4),
                       ProgressGeometry.Rect(x: 2, y: 2, width: 0, height: 0))
        XCTAssertEqual(ProgressGeometry.circularRect(width: 50, height: 36, strokeWidth: 10),
                       ProgressGeometry.Rect(x: 5, y: 5, width: 40, height: 26))
        XCTAssertEqual(ProgressGeometry.circularRect(width: 36, height: 36, strokeWidth: 40),
                       ProgressGeometry.Rect(x: 20, y: 20, width: 0, height: 0))
    }

    /// A7.3: with no value, or NaN, the indicator is one static arc from
    /// -0.5 rad sweeping 4.5 rad, with no track.
    func testA7_3AnIndeterminateCircularIsOneStaticArc() {
        assertArc(ProgressGeometry.circularArc(nil), start: -0.5, sweep: 4.5, track: false, draws: true)
        assertArc(ProgressGeometry.circularArc(.nan), start: -0.5, sweep: 4.5, track: false, draws: true)
    }

    /// A7.3: at 0.4 the arc starts at 12 o'clock and sweeps 0.8π (144°) over
    /// the track.
    func testA7_3ADeterminateCircularSweepsFromTwelveOClock() {
        let arc = ProgressGeometry.circularArc(0.4)
        assertArc(arc, start: -Double.pi / 2, sweep: 0.8 * Double.pi, track: true, draws: true)
        XCTAssertEqual(arc.sweepRad * 180 / Double.pi, 144, accuracy: 1e-9)
    }

    /// A7.3: the value is held within 0 ... 1: below 0 and at 0 the track
    /// alone (a sweep of 0, no arc), above 1 the full circle.
    func testA7_3TheCircularValueIsClampedAndZeroDrawsNoArc() {
        assertArc(ProgressGeometry.circularArc(-1), start: -Double.pi / 2, sweep: 0, track: true, draws: false)
        assertArc(ProgressGeometry.circularArc(0), start: -Double.pi / 2, sweep: 0, track: true, draws: false)
        assertArc(ProgressGeometry.circularArc(2), start: -Double.pi / 2, sweep: 2 * Double.pi, track: true, draws: true)
    }

    /// A7.3: the track is the colour with its alpha replaced by 0x33, not
    /// multiplied; the colour defaults to #2196F3.
    func testA7_3TheTrackIsTheColourAtAlpha0x33() {
        XCTAssertEqual(ProgressGeometry.trackColor(0x80FF_0000), 0x33FF_0000)
        XCTAssertEqual(ProgressGeometry.trackColor(0x0012_3456), 0x3312_3456)
        XCTAssertEqual(ProgressGeometry.trackColor(0xFFFF_0000), 0x33FF_0000)
        XCTAssertEqual(ProgressGeometry.trackColor(0x00FF_0000), 0x33FF_0000)
        XCTAssertEqual(ProgressGeometry.defaultColor, 0xFF21_96F3)
        XCTAssertEqual(ProgressGeometry.trackColor(ProgressGeometry.defaultColor), 0x3321_96F3)
    }

    // MARK: A7.3 Linear

    /// A7.3: the bar is minHeight high, 4 when absent (0 is 0: Flutter has
    /// no rule for it), its corners rounded by half of that. A negative
    /// height, which Flutter asserts on, and NaN are 0; the track is #E0E0E0.
    func testA7_3LinearHeightDefaultsTo4WithRadiusHalfOfIt() {
        XCTAssertEqual(ProgressGeometry.linearHeight(nil), 4)
        XCTAssertEqual(ProgressGeometry.linearRadius(ProgressGeometry.linearHeight(nil)), 2)
        XCTAssertEqual(ProgressGeometry.linearHeight(10), 10)
        XCTAssertEqual(ProgressGeometry.linearRadius(10), 5)
        XCTAssertEqual(ProgressGeometry.linearHeight(0), 0)
        XCTAssertEqual(ProgressGeometry.linearRadius(0), 0)
        XCTAssertEqual(ProgressGeometry.linearHeight(-2), 0)
        XCTAssertEqual(ProgressGeometry.linearHeight(-3), 0)
        XCTAssertEqual(ProgressGeometry.linearHeight(.nan), 0)
        XCTAssertEqual(ProgressGeometry.linearTrackColor, 0xFFE0_E0E0)
    }

    /// A7.3: with no value the Linear is its track alone, #E0E0E0 by default.
    func testA7_3AnIndeterminateLinearHasNoBar() {
        XCTAssertNil(ProgressGeometry.linearBar(width: 200, value: nil))
        XCTAssertEqual(ProgressGeometry.linearTrackColor, 0xFFE0_E0E0)
    }

    /// A7.3: the bar is the width times the value held within 0 ... 1,
    /// drawn from the left edge (x 0, in right-to-left too) in #2196F3 by
    /// default. NaN is a full bar: Dart's `clamp` puts NaN above the upper
    /// limit (vm/lib/double.dart:229, `compareTo`).
    func testA7_3ADeterminateLinearBarIsTheClampedFractionOfTheWidthFromTheLeft() {
        XCTAssertEqual(ProgressGeometry.linearBar(width: 200, value: 0.4) ?? -1, 80, accuracy: 1e-9)
        XCTAssertEqual(ProgressGeometry.linearBar(width: 200, value: 0), 0)
        XCTAssertEqual(ProgressGeometry.linearBar(width: 200, value: -0.5), 0)
        XCTAssertEqual(ProgressGeometry.linearBar(width: 200, value: 1.5), 200)
        XCTAssertEqual(ProgressGeometry.linearBar(width: 200, value: .nan), 200)
        XCTAssertEqual(ProgressGeometry.defaultColor, 0xFF21_96F3)
    }
}
