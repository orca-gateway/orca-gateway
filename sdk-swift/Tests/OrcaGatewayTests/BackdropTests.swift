#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A4.3, the blur half: Flutter's `BackdropFilter` (layout_builders.dart
/// :345-352) and the SDK's `BlurView` composite (:354-370). iOS has no
/// backdrop blur by sigma, so both draw a system Material whose strength
/// follows the larger sigma (q8), clipped to the widget's own box (D9:
/// Flutter's blur reaches the nearest ancestor clip). The material function
/// is checked on its own, the boxes and layers by ImageRenderer pixels, the
/// taps in a hosted window with a text field behind (iOS).
/// The blur of what is behind is left to the hand check: only the window
/// server draws it (a CABackdropLayer), `layer.render` leaves it out, and
/// `drawHierarchy` fails in this host, which has no app scene ("Render
/// server returned error").
@MainActor
final class BackdropTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: the material from the sigma (q8)

    /// A4.3: the five steps, ≤ 3 ultraThin, ≤ 8 thin, ≤ 16 regular, ≤ 24
    /// thick, else ultraThick; a sigma of 0 is the thinnest.
    func testA4_3TheMaterialFollowsTheSigmaInFiveSteps() {
        let steps: [(CGFloat, BackdropStrength)] = [
            (0, .ultraThin), (3, .ultraThin), (3.5, .thin), (8, .thin), (8.5, .regular), (16, .regular),
            (16.5, .thick), (24, .thick), (24.5, .ultraThick), (100, .ultraThick),
        ]
        for (sigma, expected) in steps {
            XCTAssertEqual(BackdropStrength(blurX: sigma, blurY: sigma), expected, "sigma \(sigma)")
        }
    }

    /// A4.3: the larger of blurX and blurY decides, either way round.
    func testA4_3TheLargerSigmaWins() {
        XCTAssertEqual(BackdropStrength(blurX: 2, blurY: 20), .thick)
        XCTAssertEqual(BackdropStrength(blurX: 20, blurY: 2), .thick)
        XCTAssertEqual(BackdropStrength(blurX: 0, blurY: 30), .ultraThick)
    }

    /// A4.3: a missing sigma is Flutter's 10, so the default is regular, and
    /// a missing blurX (10) beats a smaller blurY.
    func testA4_3TheDefaultSigma10IsRegular() {
        XCTAssertEqual(BackdropStrength(blurX: nil, blurY: nil), .regular)
        XCTAssertEqual(BackdropStrength(blurX: nil, blurY: 2), .regular)
        XCTAssertEqual(BackdropStrength(blurX: 0, blurY: 0), .ultraThin)
    }

    // MARK: boxes and layers (ImageRenderer pixels)

    /// A4.3: a BackdropFilter is a proxy box: around a 60x40 Container (a
    /// green 40x20 inside 10 of padding) it is exactly 60x40, the material
    /// fills that box (ImageRenderer draws it as a flat light fill) and
    /// nothing outside it, and the child is drawn on top.
    func testA4_3ABackdropFilterIsItsChildsBoxAndDrawsNothingOutside() throws {
        let nodes = [
            node("bf", "BackdropFilter", ["blurX": 4, "blurY": 6], ["frame"]),
            node("frame", "Container", ["width": 60, "height": 40,
                                        "padding": ["left": 10, "top": 10, "right": 10, "bottom": 10]], ["green"]),
            box("green", "#00FF00", 40, 20),
        ]
        let model = try model(nodes)
        let frames = NativeWidgetTests().layout(width: 200, height: 200) {
            NodeView(id: "bf", model: model).record("bf")
        }
        assertFrame(frames["bf"], CGRect(x: 0, y: 0, width: 60, height: 40))

        let pixels = try draw(nodes, width: 120, height: 100)
        assertFrame(pixels.bounds { $0.a > 0 }, CGRect(x: 0, y: 0, width: 60, height: 40))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 10, y: 10, width: 40, height: 20))
        for (x, y) in [(0, 0), (59, 0), (0, 39), (59, 39), (30, 4), (30, 35)] {
            let p = pixels.pixel(x, y)
            XCTAssertTrue(p.a > 200 && !Self.isGreen(p), "(\(x), \(y)) is \(p), not the material")
        }
    }

    /// A4.3: a BlurView with an overlay colour and a radius of 12 around a
    /// sized child: the overlay covers exactly the child's 80x60 box, the
    /// child (a green 40x20 inside 20 of padding) is on top of it, the
    /// corners outside the radius show the page behind (blue), and nothing
    /// is drawn outside the box.
    func testA4_3ABlurViewIsCutToItsRadiusWithItsOverlayUnderItsChild() throws {
        let nodes = [
            node("blur", "BlurView", ["blurX": 8, "blurY": 8, "overlayColor": "#FF0000", "borderRadius": 12], ["frame"]),
            node("frame", "Container", ["width": 80, "height": 60,
                                        "padding": ["left": 20, "top": 20, "right": 20, "bottom": 20]], ["green"]),
            box("green", "#00FF00", 40, 20),
        ]
        let model = try model(nodes)
        let frames = NativeWidgetTests().layout(width: 200, height: 200) {
            NodeView(id: "blur", model: model).record("blur")
        }
        assertFrame(frames["blur"], CGRect(x: 0, y: 0, width: 80, height: 60))

        let pixels = try draw(nodes, width: 120, height: 100, page: Color(.sRGB, red: 0, green: 0, blue: 1))
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 80, height: 60))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 20, y: 20, width: 40, height: 20))
        assertFrame(pixels.bounds { !Self.isBlue($0) }, CGRect(x: 0, y: 0, width: 80, height: 60))
        for (x, y) in [(0, 0), (1, 1), (79, 0), (78, 1), (0, 59), (1, 58), (79, 59), (78, 58)] {
            XCTAssertTrue(Self.isBlue(pixels.pixel(x, y)), "corner (\(x), \(y)) is \(pixels.pixel(x, y)), not the page")
        }
        for (x, y) in [(6, 6), (73, 6), (6, 53), (73, 53), (40, 2), (40, 57)] {
            XCTAssertTrue(Pixels.isRed(pixels.pixel(x, y)), "(\(x), \(y)) is \(pixels.pixel(x, y)), not the overlay")
        }
    }

    /// A4.3: with no child, neither draws anything and both take no room
    /// (Flutter's `renderChild` is `SizedBox.shrink`, builder_helpers.dart
    /// :19-22).
    func testA4_3WithNoChildNeitherDrawsAndBothAreZeroSize() throws {
        let cases: [(String, [String: JSONValue])] = [
            ("BackdropFilter", ["blurX": 4, "blurY": 6]),
            ("BlurView", ["overlayColor": "#FF0000", "borderRadius": 12]),
        ]
        for (type, props) in cases {
            let nodes = [node("w", type, props)]
            let model = try model(nodes)
            let frames = NativeWidgetTests().layout(width: 200, height: 200) {
                NodeView(id: "w", model: model).record("w")
            }
            // Not laid out at all, or laid out at zero size.
            XCTAssertEqual(frames["w"]?.size ?? .zero, .zero, "\(type) with no child takes room")
            // Over a page colour: a render that draws nothing at all can
            // come back holding the previous render's pixels.
            let pixels = try draw(nodes, width: 60, height: 60, page: Color(.sRGB, red: 0, green: 0, blue: 1))
            XCTAssertNil(pixels.bounds { $0.r != 0 || $0.g != 0 || $0.b != 255 || $0.a != 255 },
                         "\(type) with no child draws")
        }
    }

    // MARK: taps (a hosted window, a UIKit text field as the probe)

    #if canImport(UIKit)
    /// A4.3: a BackdropFilter takes no tap itself (RenderBackdropFilter is a
    /// proxy box with no hitTestSelf): around a SizedBox, which takes none,
    /// over a text field, a tap at its centre finds the field.
    func testA4_3ABackdropFilterLetsTapsThroughWhereItsChildTakesNone() throws {
        let (window, field) = try hostedOverField("BackdropFilter", [:], left: 60, top: 68)
        defer { window.isHidden = true }
        let centre = CGPoint(x: 100, y: 108)
        XCTAssertTrue(field.contains(centre), "the field \(field) is not under the centre")
        XCTAssertTrue(FlowTests.isInField(window.hitTest(centre, with: nil)), "the BackdropFilter took the tap")
    }

    /// A4.3: a BlurView (no overlay colour, so a transparent one) takes every
    /// tap in its whole box, corners outside the radius included, as
    /// Flutter's composite does: its Container with a colour, even
    /// transparent, is a ColoredBox, opaque to hits (basic.dart:8392-8394),
    /// and RenderClipRRect cuts hits only with a custom clipper
    /// (proxy_box.dart:1736-1746), which the SDK does not pass. Around a
    /// SizedBox 80x80 with a radius of 30, over a text field: its centre, a
    /// point on its top edge and a point just inside its top left corner,
    /// outside the radius, all find no field.
    func testA4_3ABlurViewTakesTapsOverItsWholeBox() throws {
        let props: [String: JSONValue] = ["borderRadius": 30]
        let (centred, centredField) = try hostedOverField("BlurView", props, left: 60, top: 68)
        let centre = CGPoint(x: 100, y: 108)
        XCTAssertTrue(centredField.contains(centre), "the field \(centredField) is not under the centre")
        XCTAssertFalse(FlowTests.isInField(centred.hitTest(centre, with: nil)), "a tap at the centre went through")
        centred.isHidden = true

        let (cornered, corneredField) = try hostedOverField("BlurView", props, left: 50, top: 104)
        defer { cornered.isHidden = true }
        // (2, 2) and (40, 2) in the BlurView's own box.
        let corner = CGPoint(x: 52, y: 106), edge = CGPoint(x: 90, y: 106)
        XCTAssertTrue(corneredField.contains(corner) && corneredField.contains(edge),
                      "the field \(corneredField) is not under the corner and the edge")
        XCTAssertFalse(FlowTests.isInField(cornered.hitTest(corner, with: nil)),
                       "a tap in the corner, outside the radius, went through")
        XCTAssertFalse(FlowTests.isInField(cornered.hitTest(edge, with: nil)), "a tap on the top edge went through")
    }

    /// A light 200x200 window (away from the screen's edges) holding a Stack:
    /// a text field across it at y 100, and above it `type` with `props`
    /// around a SizedBox 80x80 at (`left`, `top`). The window and the
    /// field's frame in it.
    func hostedOverField(_ type: String, _ props: [String: JSONValue], left: Double,
                         top: Double) throws -> (UIWindow, CGRect) {
        let nodes = [
            node("page", "Stack", ["alignment": "topLeft"], ["fieldAt", "at"]),
            node("fieldAt", "Positioned", ["left": 0, "right": 0, "top": 100], ["field"]),
            node("field", "TextField", ["placeholder": "Name"]),
            node("at", "Positioned", ["left": .double(left), "top": .double(top)], ["w"]),
            node("w", type, props, ["size"]),
            node("size", "SizedBox", ["width": 80, "height": 80]),
        ]
        let host = UIHostingController(rootView: NodeView(id: "page", model: try model(nodes))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 200, height: 200))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let field = try XCTUnwrap(FlowTests.textField(in: window), "no text field")
        return (window, field.convert(field.bounds, to: window))
    }
    #endif

    // MARK: helpers

    static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.g > 200 && p.r < 60 && p.b < 60
    }

    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.b > 200 && p.r < 60 && p.g < 60
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// A wire node: a Stack holds many children, the rest one or none.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
              _ children: [String] = []) -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": "layout",
            "childMode": type == "Stack" ? "multi" : "single",
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
        ]
    }

    /// A solid Container of `hex`, `width` by `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    /// The page, its registry widened by the two types (they are advertised
    /// only in group 6, and the renderer degrades any type it lacks).
    func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        let registry = WidgetRegistry(types: Set(GeneratedCapabilities.widgets).union(["BackdropFilter", "BlurView"]))
        return OrcaPageModel(page: page, registry: registry)
    }

    func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    /// The first node drawn by ImageRenderer at scale 1, in a `width` by
    /// `height` box from the top leading corner, over `page`.
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat, page: Color = .clear) throws -> Pixels {
        let view = NodeView(id: try rootId(nodes), model: try model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
            .background(page)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}
#endif
