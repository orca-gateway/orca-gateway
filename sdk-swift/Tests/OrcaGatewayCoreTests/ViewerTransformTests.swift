import XCTest

@testable import OrcaGatewayCore

/// A4.5, the core half of InteractiveViewer: Flutter's
/// `_InteractiveViewerState` (widgets/interactive_viewer.dart) as the
/// Flutter builder makes it (layout_builders.dart:636-644: minScale 0.8,
/// maxScale 2.5, pan and scale on; the framework's boundaryMargin zero, so
/// the bound is the child's rect). The scale is clamped after a floor of
/// viewport / child (`_matrixScale` :646-660), a translation is kept inside
/// the bound (`_matrixTranslate` :547-640), and one scale gesture pans or
/// pinches about its focal point (`_onScaleStart`, `_onScaleUpdate`
/// :700-805). The same cases as Kotlin's ViewerTransformTest.
final class ViewerTransformTests: XCTestCase {
    /// A 200x200 child filling a 200x200 viewer, Flutter's defaults.
    static let square = ViewerLimits(viewport: ViewerSize(width: 200, height: 200),
                                     child: ViewerSize(width: 200, height: 200))
    static let centre = ViewerPoint(x: 100, y: 100)
    /// Zoomed in to 2 about the centre.
    static let zoomed = ViewerTransform(scale: 2, x: -100, y: -100)

    /// A4.5: at rest the transform is the identity, whose scene point is
    /// the point itself; a transform draws scene point p at scale·p + (x, y).
    func testA4_5AtRestTheTransformIsTheIdentity() {
        XCTAssertEqual(ViewerTransform.identity, ViewerTransform(scale: 1, x: 0, y: 0))
        XCTAssertEqual(ViewerTransform.identity.toScene(ViewerPoint(x: 30, y: 70)), ViewerPoint(x: 30, y: 70))
        XCTAssertEqual(ViewerTransform(scale: 2, x: -100, y: -50).toScene(ViewerPoint(x: 100, y: 100)),
                       ViewerPoint(x: 100, y: 75))
    }

    /// A4.5: the limits default to the Flutter builder's: 0.8 and 2.5, pan
    /// and scale on.
    func testA4_5LimitsDefaultToTheFlutterBuilders() {
        let limits = Self.square
        XCTAssertEqual(limits.minScale, 0.8)
        XCTAssertEqual(limits.maxScale, 2.5)
        XCTAssertTrue(limits.panEnabled)
        XCTAssertTrue(limits.scaleEnabled)
    }

    /// A4.5: a pinch x2 about the centre zooms to 2 and keeps the centre
    /// where it was: translation (-100, -100).
    func testA4_5APinchTimesTwoAboutTheCentreZoomsAboutIt() {
        assertTransform(pinch([2], at: Self.centre), Self.zoomed)
    }

    /// A4.5: a pinch x10 stops at maxScale 2.5, still about the centre.
    func testA4_5APinchStopsAtMaxScale() {
        assertTransform(pinch([10], at: Self.centre), ViewerTransform(scale: 2.5, x: -150, y: -150))
    }

    /// A4.5: a pinch x0.5 at rest stays at 1: the child would no longer
    /// cover the viewer, whatever minScale (0.8 by default) allows.
    func testA4_5APinchOutAtRestStaysAtOneWhateverMinScale() {
        assertTransform(pinch([0.5], at: Self.centre), .identity)
        var low = Self.square
        low.minScale = 0.1
        assertTransform(pinch([0.5], at: Self.centre, limits: low), .identity)
    }

    /// A4.5: with minScale 1.5 a pinch x1.01 jumps to 1.5 (Flutter clamps
    /// the total), about the centre.
    func testA4_5AMinScaleAboveOneIsReachedByAnyPinch() {
        var limits = Self.square
        limits.minScale = 1.5
        assertTransform(pinch([1.01], at: Self.centre, limits: limits), ViewerTransform(scale: 1.5, x: -50, y: -50))
    }

    /// A4.5: with maxScale 0.9 (below 1, above the default minScale) the
    /// clamp wins over the floor of 1: any pinch goes to 0.9, and since the
    /// child then covers neither axis of the viewer no translation is kept
    /// (Flutter's result).
    func testA4_5AMaxScaleBelowOneIsWhatTheClampGives() {
        var limits = Self.square
        limits.maxScale = 0.9
        for scale in [2, 0.5] {
            assertTransform(pinch([scale], at: Self.centre, limits: limits), ViewerTransform(scale: 0.9, x: 0, y: 0))
        }
    }

    /// A4.5: at scale 1 a drag moves nothing (the child is exactly the
    /// viewport, so the bound leaves no room).
    func testA4_5ADragAtScaleOneMovesNothing() {
        for by in [ViewerPoint(x: 50, y: 30), ViewerPoint(x: -80, y: 0), ViewerPoint(x: 0, y: -500)] {
            assertTransform(drag(by, from: .identity), .identity)
        }
    }

    /// A4.5: zoomed in to 2 at (-100, -100), a drag by (-50, -30) pans to
    /// (-150, -130); by (+500, 0) x stops at 0; by (-500, 0) x stops at
    /// -200 (the child's right edge on the viewer's); within one drag the
    /// edge keeps no overshoot: +500 then back 50 is at once at -50.
    func testA4_5ZoomedInADragPansWithinTheChild() {
        assertTransform(drag(ViewerPoint(x: -50, y: -30), from: Self.zoomed),
                        ViewerTransform(scale: 2, x: -150, y: -130))
        assertTransform(drag(ViewerPoint(x: 500, y: 0), from: Self.zoomed), ViewerTransform(scale: 2, x: 0, y: -100))
        assertTransform(drag(ViewerPoint(x: -500, y: 0), from: Self.zoomed),
                        ViewerTransform(scale: 2, x: -200, y: -100))
        assertTransform(drag([ViewerPoint(x: 500, y: 0), ViewerPoint(x: 450, y: 0)], from: Self.zoomed),
                        ViewerTransform(scale: 2, x: -50, y: -100))
    }

    /// A4.5: a 200x100 child zoomed to 2 in a 200x100 viewport pans within
    /// [-200, 0] x [-100, 0].
    func testA4_5AWideChildPansWithinItsOwnBounds() {
        let limits = ViewerLimits(viewport: ViewerSize(width: 200, height: 100),
                                  child: ViewerSize(width: 200, height: 100))
        let from = ViewerTransform(scale: 2, x: -100, y: -50)
        assertTransform(drag(ViewerPoint(x: 900, y: 900), from: from, limits: limits), ViewerTransform(scale: 2, x: 0, y: 0))
        assertTransform(drag(ViewerPoint(x: -900, y: -900), from: from, limits: limits),
                        ViewerTransform(scale: 2, x: -200, y: -100))
        assertTransform(drag(ViewerPoint(x: -60, y: 30), from: from, limits: limits),
                        ViewerTransform(scale: 2, x: -160, y: -20))
    }

    /// A4.5: a pinch x2 about the top-left corner keeps the corner there:
    /// translation (0, 0).
    func testA4_5APinchAboutTheTopLeftCornerKeepsItThere() {
        assertTransform(pinch([2], at: ViewerPoint(x: 0, y: 0)), ViewerTransform(scale: 2, x: 0, y: 0))
    }

    /// A4.5: from 2 at (0, 0), a pinch x0.75 about the centre would keep
    /// the scene point (50, 50) under it only by moving the child right of
    /// the viewer's edge, so the translation stops at (0, 0) and the point
    /// under the focal point, (66.7, 66.7), becomes the reference: back to
    /// x1, the pinch keeps that point there, (-33.3, -33.3), not (0, 0).
    func testA4_5APinchStoppedByTheBoundMovesItsReference() {
        var gesture = ViewerGesture()
        let from = ViewerTransform(scale: 2, x: 0, y: 0)
        gesture.start(focal: Self.centre, transform: from)
        let out = gesture.update(scale: 0.75, focal: Self.centre, transform: from, limits: Self.square)
        assertTransform(out, ViewerTransform(scale: 1.5, x: 0, y: 0))
        XCTAssertEqual(gesture.reference.x, 200.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(gesture.reference.y, 200.0 / 3, accuracy: 1e-9)
        let back = gesture.update(scale: 1, focal: Self.centre, transform: out, limits: Self.square)
        assertTransform(back, ViewerTransform(scale: 2, x: -100.0 / 3, y: -100.0 / 3))
    }

    /// A4.5: with scaleEnabled false a pinch changes nothing (Flutter
    /// counts it as a pan whose scale is not 1, and drops it).
    func testA4_5ScaleDisabledAPinchChangesNothing() {
        var limits = Self.square
        limits.scaleEnabled = false
        assertTransform(pinch([2, 3], at: Self.centre, limits: limits), .identity)
        assertTransform(pinch([0.5], at: Self.centre, from: Self.zoomed, limits: limits), Self.zoomed)
    }

    /// A4.5: with panEnabled false a drag changes nothing, and a pinch
    /// still zooms about its focal point (the pinch's own translation is
    /// not a pan).
    func testA4_5PanDisabledADragChangesNothingButAPinchScalesAboutItsFocalPoint() {
        var limits = Self.square
        limits.panEnabled = false
        assertTransform(drag(ViewerPoint(x: -50, y: -30), from: Self.zoomed, limits: limits), Self.zoomed)
        assertTransform(pinch([2], at: Self.centre, limits: limits), Self.zoomed)
    }

    /// A4.5: a gesture whose first update has scale 1 is a pan, and a later
    /// one with scale 1.5 makes it a scale, about its focal point.
    func testA4_5AGestureThatStartsAsAPanBecomesAScale() {
        var gesture = ViewerGesture()
        gesture.start(focal: Self.centre, transform: .identity)
        let first = gesture.update(scale: 1, focal: Self.centre, transform: .identity, limits: Self.square)
        XCTAssertEqual(gesture.kind, .pan)
        assertTransform(first, .identity)
        let second = gesture.update(scale: 1.5, focal: Self.centre, transform: first, limits: Self.square)
        XCTAssertEqual(gesture.kind, .scale)
        assertTransform(second, ViewerTransform(scale: 1.5, x: -50, y: -50))
    }

    // MARK: helpers

    /// One gesture from `from`: a pinch whose updates have `scales` about a
    /// focal point that stays at `focal`.
    func pinch(_ scales: [Double], at focal: ViewerPoint, from: ViewerTransform = .identity,
               limits: ViewerLimits = square) -> ViewerTransform {
        var gesture = ViewerGesture()
        gesture.start(focal: focal, transform: from)
        var transform = from
        for scale in scales {
            transform = gesture.update(scale: scale, focal: focal, transform: transform, limits: limits)
        }
        return transform
    }

    /// One gesture from `from`: a finger down at the centre, then moved by
    /// each of `moves` from there in turn (scale 1).
    func drag(_ moves: [ViewerPoint], from: ViewerTransform, limits: ViewerLimits = square) -> ViewerTransform {
        var gesture = ViewerGesture()
        gesture.start(focal: Self.centre, transform: from)
        var transform = from
        for move in moves {
            let focal = ViewerPoint(x: Self.centre.x + move.x, y: Self.centre.y + move.y)
            transform = gesture.update(scale: 1, focal: focal, transform: transform, limits: limits)
        }
        return transform
    }

    func drag(_ move: ViewerPoint, from: ViewerTransform, limits: ViewerLimits = square) -> ViewerTransform {
        drag([move], from: from, limits: limits)
    }

    func assertTransform(_ actual: ViewerTransform, _ expected: ViewerTransform,
                         file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.scale, expected.scale), (actual.x, expected.x), (actual.y, expected.y)] {
            XCTAssertEqual(a, e, accuracy: 1e-9, "\(actual) vs \(expected)", file: file, line: line)
        }
    }
}
