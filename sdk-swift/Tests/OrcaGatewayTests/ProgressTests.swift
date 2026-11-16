#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A7.3: CircularProgressIndicator and LinearProgressIndicator as Flutter's
/// builders paint them (primitive_builders.dart:302-323, 364-384, painters
/// :435-513), from the ProgressGeometry core. A Circular is 36 points square
/// unless its parent forces a size, its arc inset half the stroke (3 by
/// default) in #2196F3: without a value one static arc from -0.5 rad over
/// 4.5 rad (3 o'clock, clockwise), with one a full track at alpha 0x33 and
/// the arc from 12 o'clock. A Linear is minHeight (4) high across its
/// parent, a #E0E0E0 track and a #2196F3 bar from the left, clipped to round
/// ends. The same cases as Kotlin's ProgressTest.
///
/// Pages are drawn by ImageRenderer at scale 1 in a box from the top left,
/// on white. Points on a ring are given in degrees clockwise from 12 o'clock
/// and sampled mid-stroke, well away from the round caps. The two are
/// advertised only in group 7, so the page's registry is widened by them.
@MainActor
final class ProgressTests: XCTestCase {
    static let flutterBlue = (r: 0x21, g: 0x96, b: 0xF3)
    static let track = (r: 0xE0, g: 0xE0, b: 0xE0)
    static let white = (r: 255, g: 255, b: 255)

    /// A7.3: a Circular in a loose parent is 36 x 36 whatever its stroke; a
    /// Linear takes the parent's width and is minHeight (4 when unset) high.
    func testA7_3ACircularIs36SquareAndALinearIsMinHeightHighAcrossItsParent() throws {
        let pixels = try draw([
            column("root", ["c", "thick", "l", "tall"]),
            circular("c", ["value": 1, "color": "#FF0000"]),
            circular("thick", ["value": 1, "color": "#00FF00", "strokeWidth": 8]),
            linear("l", ["value": 0.4, "color": "#0000FF", "backgroundColor": "#0000FF"]),
            linear("tall", ["minHeight": 10, "backgroundColor": "#FFFF00"]),
        ], width: 120, height: 200)

        let c = try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "no Circular")
        XCTAssertEqual(c.width, 36, accuracy: 1, "\(c)")
        XCTAssertEqual(c.height, 36, accuracy: 1, "\(c)")
        let thick = try XCTUnwrap(pixels.bounds(of: RichTextTests.isGreen), "no thick Circular")
        XCTAssertEqual(thick.width, 36, accuracy: 1, "\(thick)")
        XCTAssertEqual(thick.height, 36, accuracy: 1, "\(thick)")
        XCTAssertEqual(thick.minY, c.maxY, accuracy: 1, "the Circulars are not stacked 36 apart: \(c), \(thick)")
        let bar = try XCTUnwrap(pixels.bounds(of: RichTextTests.isBlue), "no Linear")
        XCTAssertEqual(bar.width, 120, accuracy: 0.5, "\(bar)")
        XCTAssertEqual(bar.height, 4, accuracy: 0.5, "\(bar)")
        let tall = try XCTUnwrap(pixels.bounds(of: AppBarCardTests.isYellow), "no tall Linear")
        XCTAssertEqual(tall.width, 120, accuracy: 0.5, "\(tall)")
        XCTAssertEqual(tall.height, 10, accuracy: 0.5, "\(tall)")
        XCTAssertEqual(tall.minY, bar.maxY, accuracy: 0.5, "the Linears are not stacked: \(bar), \(tall)")
    }

    /// A7.3: determinate at 0.4, the full ring in #2196F3 at alpha 0x33,
    /// then the arc from 12 o'clock over 144 degrees, clockwise, in #2196F3;
    /// the middle and the ring's inside stay white.
    func testA7_3ADeterminateCircularDrawsTheFaintTrackThenTheArcFromTwelve() throws {
        let pixels = try draw([circular("c", ["value": 0.4])], width: 100, height: 100)
        let box = CGRect(x: 0, y: 0, width: 36, height: 36)
        let faint = Self.onWhite(Self.flutterBlue, alpha: 0x33)
        for degrees in [30.0, 70, 100, 120] {
            assertColour(Self.flutterBlue, pixels.ring(box, degrees), "arc at \(degrees)")
        }
        for degrees in [170.0, 200, 270, 330] {
            assertColour(faint, pixels.ring(box, degrees), "track at \(degrees)")
        }
        assertColour(Self.white, pixels.at(box, 18, 18), "centre")
        assertColour(Self.white, pixels.ring(box, 100, radius: 12), "inside the ring")
        assertColour(Self.white, pixels.at(box, 50, 18), "right of the box")
    }

    /// A7.3: without a value, one arc from -0.5 rad over 4.5 rad, about 2
    /// o'clock round to half past 10 clockwise, over no track: the top is
    /// blank.
    func testA7_3AnIndeterminateCircularIsOneStaticArcOverNoTrack() throws {
        let pixels = try draw([circular("c", [:])], width: 100, height: 100)
        let box = CGRect(x: 0, y: 0, width: 36, height: 36)
        for degrees in [90.0, 180, 270] {
            assertColour(Self.flutterBlue, pixels.ring(box, degrees), "arc at \(degrees)")
        }
        for degrees in [0.0, 340, 20] {
            assertColour(Self.white, pixels.ring(box, degrees), "gap at \(degrees)")
        }
    }

    /// A7.3: a parent forcing 80 x 36 (a SizedBox) makes the arc an ellipse
    /// inset half the stroke: it reaches the box's right and left ends and
    /// its bottom middle.
    func testA7_3AForcedNonSquareBoxDrawsAnEllipse() throws {
        let pixels = try draw([
            ["id": "s", "type": "SizedBox", "kind": "layout", "childMode": "single",
             "props": ["width": 80, "height": 36], "children": ["c"], "watches": []],
            circular("c", [:]),
        ], width: 100, height: 100)
        let box = CGRect(x: 0, y: 0, width: 80, height: 36)
        assertColour(Self.flutterBlue, pixels.at(box, 78.5, 18.5), "right end")
        assertColour(Self.flutterBlue, pixels.at(box, 40.5, 34.5), "bottom middle")
        assertColour(Self.flutterBlue, pixels.at(box, 1.5, 18.5), "left end")
        assertColour(Self.white, pixels.at(box, 40.5, 18.5), "middle")
        let ink = try XCTUnwrap(pixels.bounds(of: Self.isInked), "nothing drawn")
        XCTAssertEqual(ink.width, 80, accuracy: 1, "not the forced 80 points wide: \(ink)")
    }

    /// A7.3: a Linear at 0.4 across 200 points, the #2196F3 bar over 0 to 80
    /// from the left, the #E0E0E0 track after it.
    func testA7_3ALinearDrawsA40PercentBarOverTheTrack() throws {
        let pixels = try draw([linear("l", ["value": 0.4])], width: 200, height: 50)
        let box = CGRect(x: 0, y: 0, width: 200, height: 4)
        for x in [10.5, 40.5, 76.5] { assertColour(Self.flutterBlue, pixels.at(box, x, 2), "bar at \(x)") }
        for x in [84.5, 150.5, 190.5] { assertColour(Self.track, pixels.at(box, x, 2), "track at \(x)") }
        assertColour(Self.white, pixels.at(box, 100, 6), "below the Linear")
    }

    /// A7.3: a Linear without a value is the bare track, no bar.
    func testA7_3ALinearWithoutAValueIsTheBareTrack() throws {
        let pixels = try draw([linear("l", [:])], width: 200, height: 50)
        let box = CGRect(x: 0, y: 0, width: 200, height: 4)
        for x in [5.5, 50.5, 100.5, 194.5] { assertColour(Self.track, pixels.at(box, x, 2), "track at \(x)") }
    }

    /// A7.3: `color` and `strokeWidth` on a Circular (8 wide, so the ring is
    /// inked 10 to 18 from the middle); `color`, `backgroundColor` and
    /// `minHeight` on a Linear, its ends cut round at half its height.
    func testA7_3ColoursAndSizesComeFromTheProps() throws {
        let pixels = try draw([
            column("root", ["c", "l"], ["crossAxisAlignment": "start"]),
            circular("c", ["value": 0.4, "color": "#FF0000", "strokeWidth": 8]),
            linear("l", ["value": 0.4, "color": "#00FF00", "backgroundColor": "#0000FF", "minHeight": 20]),
        ], width: 100, height: 100)

        let circle = CGRect(x: 0, y: 0, width: 36, height: 36)
        let red = (r: 255, g: 0, b: 0)
        assertColour(red, pixels.ring(circle, 100, radius: 14), "arc at 100, mid-stroke")
        assertColour(red, pixels.ring(circle, 100, radius: 12), "arc at 100, inner half")
        assertColour(Self.onWhite(red, alpha: 0x33), pixels.ring(circle, 200, radius: 14), "track at 200")
        assertColour(Self.white, pixels.ring(circle, 200, radius: 8), "inside the ring")

        let bar = CGRect(x: 0, y: 36, width: 100, height: 20)
        let drawn = try XCTUnwrap(pixels.bounds(of: { RichTextTests.isBlue($0) || RichTextTests.isGreen($0) }))
        XCTAssertEqual(drawn.minY, bar.minY, accuracy: 0.5, "\(drawn)")
        XCTAssertEqual(drawn.width, 100, accuracy: 0.5, "\(drawn)")
        XCTAssertEqual(drawn.height, 20, accuracy: 0.5, "\(drawn)")
        assertColour((0, 255, 0), pixels.at(bar, 20.5, 10.5), "bar")
        assertColour((0, 0, 255), pixels.at(bar, 70.5, 10.5), "track")
        assertColour(Self.white, pixels.at(bar, 1.5, 1.5), "top left corner, cut")
        assertColour(Self.white, pixels.at(bar, 98.5, 18.5), "bottom right corner, cut")
        assertColour((0, 255, 0), pixels.at(bar, 1.5, 10.5), "left end, middle")
    }

    /// A7.3: right to left the bar still runs from the left, as Flutter's
    /// painter draws it; an indeterminate Circular's arc is not mirrored
    /// either (it ends at 319 degrees, past 2 o'clock is the gap).
    func testA7_3RightToLeftALinearStillFillsFromTheLeft() throws {
        let pixels = try draw([linear("l", ["value": 0.4])], width: 100, height: 50, direction: .rightToLeft)
        let box = CGRect(x: 0, y: 0, width: 100, height: 4)
        assertColour(Self.flutterBlue, pixels.at(box, 20.5, 2), "left")
        assertColour(Self.track, pixels.at(box, 80.5, 2), "right")

        let circle = try draw([circular("c", [:])], width: 36, height: 36, direction: .rightToLeft)
        let square = CGRect(x: 0, y: 0, width: 36, height: 36)
        assertColour(Self.flutterBlue, circle.ring(square, 310), "arc at 310, right to left")
        assertColour(Self.white, circle.ring(square, 50), "gap at 50, right to left")
    }

    #if canImport(UIKit)
    /// A7.3: nothing animates. In a window, an indeterminate Circular and
    /// Linear look the same half a second apart. A guard against a SwiftUI
    /// redraw only: `layer.render(in:)` draws the layers' model values, so a
    /// running Core Animation (a ProgressView's spin) would not show here.
    func testA7_3AnIndeterminateIndicatorStandsStillInAWindow() async throws {
        let model = try Self.model([
            column("root", ["c", "l"]), circular("c", [:]), linear("l", [:]),
        ])
        let host = RichTextTests.Hosted(model: model, root: "root")
        defer { host.window.isHidden = true }
        let before = try host.pixels()
        XCTAssertNotNil(before.bounds(of: Self.isBlueInk), "the Circular is not drawn")
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(before.bytes == (try host.pixels()).bytes, "the indicators moved")
    }
    #endif

    // MARK: helpers

    func circular(_ id: String, _ props: [String: JSONValue]) -> JSONValue {
        leaf(id, "CircularProgressIndicator", props)
    }

    func linear(_ id: String, _ props: [String: JSONValue]) -> JSONValue {
        leaf(id, "LinearProgressIndicator", props)
    }

    func leaf(_ id: String, _ type: String, _ props: [String: JSONValue]) -> JSONValue {
        ["id": .string(id), "type": .string(type), "kind": "primitive", "childMode": "none",
         "props": .object(props), "children": [], "watches": []]
    }

    func column(_ id: String, _ children: [String], _ props: [String: JSONValue] = [:]) -> JSONValue {
        ["id": .string(id), "type": "Column", "kind": "layout", "childMode": "multi",
         "props": .object(props), "children": .array(children.map { .string($0) }), "watches": []]
    }

    /// The page of `nodes` (the first is the root), its registry widened by
    /// the two indicators.
    static func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["CircularProgressIndicator", "LinearProgressIndicator"])))
    }

    /// The page drawn by ImageRenderer at scale 1 in a `width` by `height`
    /// box from the top leading corner, on white.
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat,
              direction: LayoutDirection = .leftToRight) throws -> Pixels {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as Pixels?, "no root node")
        }
        let renderer = ImageRenderer(content: NodeView(id: root, model: try Self.model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Color.white)
            .environment(\.layoutDirection, direction))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
    }

    /// `colour` at `alpha` laid over white, as the picture shows it.
    static func onWhite(_ colour: (r: Int, g: Int, b: Int), alpha: Int) -> (r: Int, g: Int, b: Int) {
        func channel(_ c: Int) -> Int { Int((255 + Double(c - 255) * Double(alpha) / 255).rounded()) }
        return (channel(colour.r), channel(colour.g), channel(colour.b))
    }

    /// Anything not white.
    static func isInked(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.r < 240 || p.g < 240 || p.b < 240
    }

    static func isBlueInk(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.b > 200 && p.r < 80 && p.g > 110 && p.g < 190
    }

    func assertColour(_ expected: (r: Int, g: Int, b: Int), _ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
                      _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let close = abs(Int(actual.r) - expected.r) <= 8 && abs(Int(actual.g) - expected.g) <= 8
            && abs(Int(actual.b) - expected.b) <= 8
        XCTAssertTrue(close, "\(message) is \(actual), expected \(expected)", file: file, line: line)
    }
}

private extension Pixels {
    /// The pixel `x`, `y` points from the top left of `box`.
    func at(_ box: CGRect, _ x: Double, _ y: Double) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        pixel(Int((box.minX + x).rounded(.down)), Int((box.minY + y).rounded(.down)))
    }

    /// The pixel on the ring of `radius` about `box`'s centre, `degrees`
    /// clockwise from 12 o'clock; 16.5, the default stroke's middle in 36.
    func ring(_ box: CGRect, _ degrees: Double, radius: Double = 16.5) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let rad = degrees * .pi / 180
        return at(box, box.width / 2 + radius * sin(rad), box.height / 2 - radius * cos(rad))
    }
}
#endif
