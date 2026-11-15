#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// native-parity S-box: a Container lays out and clips as Flutter's
/// `Container.build` does (LB:160-185): the border's widths are added to
/// `padding` (BoxDecoration.padding), `clipBehavior` clips the padded child
/// but not the decoration behind it, and `padding` and `margin` are absolute
/// EdgeInsets (D4). Each test draws a Container holding a red Container
/// through the real ContainerView with ImageRenderer at scale 1 and reads the
/// frames back from the pixels (the LayoutTests `draw` style).
@MainActor
final class BoxTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    /// A1.4: a 4 point border insets the child by 4 on every side; the border
    /// is drawn around it. A border with style none is not drawn but still
    /// insets (Flutter's Border.dimensions ignore the style); no border, no inset.
    func testA1_4AFourPointBorderInsetsTheChildByFour() throws {
        let bordered = try draw(["width": 100, "height": 60,
                                 "decoration": ["border": ["width": 4, "color": "#0000FF"]]],
                                child: ["color": "#FF0000"], width: 100, height: 60)
        assertRect(try XCTUnwrap(bordered.bounds(of: Pixels.isRed), "child not drawn"),
                   CGRect(x: 4, y: 4, width: 92, height: 52))
        assertRect(try XCTUnwrap(bordered.bounds(of: Self.isBlue), "border not drawn"),
                   CGRect(x: 0, y: 0, width: 100, height: 60))

        let hidden = try draw(["width": 100, "height": 60,
                               "decoration": ["border": ["width": 4, "color": "#0000FF", "style": "none"]]],
                              child: ["color": "#FF0000"], width: 100, height: 60)
        assertRect(try XCTUnwrap(hidden.bounds(of: Pixels.isRed)), CGRect(x: 4, y: 4, width: 92, height: 52))
        XCTAssertNil(hidden.bounds(of: Self.isBlue), "a border with style none is not drawn")

        let plain = try draw(["width": 100, "height": 60, "decoration": ["color": "#0000FF"]],
                             child: ["color": "#FF0000"], width: 100, height: 60)
        assertRect(try XCTUnwrap(plain.bounds(of: Pixels.isRed)), CGRect(x: 0, y: 0, width: 100, height: 60))
    }

    /// A1.4: the border adds to `padding`: border 4 and padding 10 inset the
    /// child by 14.
    func testA1_4ABorderAndPaddingTenInsetTheChildByFourteen() throws {
        let pixels = try draw(["width": 100, "height": 60,
                               "padding": ["top": 10, "right": 10, "bottom": 10, "left": 10],
                               "decoration": ["border": ["width": 4, "color": "#0000FF"]]],
                              child: ["color": "#FF0000"], width: 100, height: 60)
        assertRect(try XCTUnwrap(pixels.bounds(of: Pixels.isRed)), CGRect(x: 14, y: 14, width: 72, height: 32))
    }

    /// A1.4: clipBehavior clips the child to the box, not the decoration: a
    /// shadow offset by (20, 20) stays visible outside the box while a
    /// 300-point child is cut at the box's 100-point edges.
    func testA1_4ClipCutsTheChildButNotTheShadow() throws {
        let pixels = try draw(["width": 100, "height": 100, "clipBehavior": "antiAlias",
                               "margin": ["top": 40, "right": 40, "bottom": 40, "left": 40],
                               "decoration": ["boxShadow": [["color": "#00FF00", "blurRadius": 0,
                                                             "offset": ["dx": 20, "dy": 20]]]]],
                              child: ["color": "#FF0000", "width": 300, "height": 300], width: 200, height: 200)
        assertRect(try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "child not drawn"),
                   CGRect(x: 40, y: 40, width: 100, height: 100))
        assertRect(try XCTUnwrap(pixels.bounds(of: Self.isGreen), "shadow clipped away"),
                   CGRect(x: 60, y: 60, width: 100, height: 100))
    }

    /// A1.4 and D4: `padding` and `margin` are absolute EdgeInsets, so a left
    /// margin of 20 and a left padding of 10 stay on the left in right-to-left.
    func testA1_4D4PaddingAndMarginLeftStayLeftInRightToLeft() throws {
        let pixels = try draw(["width": 100, "height": 40, "color": "#0000FF",
                               "margin": ["top": 0, "right": 0, "bottom": 0, "left": 20],
                               "padding": ["top": 0, "right": 0, "bottom": 0, "left": 10]],
                              child: ["color": "#FF0000"], width: 120, height: 40, direction: .rightToLeft)
        // The blue box shows only in its padding, left of the red child.
        assertRect(try XCTUnwrap(pixels.bounds(of: Self.isBlue), "padding not drawn"),
                   CGRect(x: 20, y: 0, width: 10, height: 40))
        assertRect(try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "child not drawn"),
                   CGRect(x: 30, y: 0, width: 90, height: 40))
    }

    // MARK: helpers

    static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.g > 200 && p.r < 60 && p.b < 60
    }

    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.b > 200 && p.r < 60 && p.g < 60
    }

    func assertRect(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.maxX, expected.maxX), (actual.maxY, expected.maxY)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// Draws a Container with `props` holding a Container with `child`
    /// props, in a `width` by `height` canvas, drawn with ImageRenderer at
    /// scale 1.
    func draw(_ props: [String: JSONValue], child: [String: JSONValue], width: CGFloat, height: CGFloat,
              direction: LayoutDirection = .leftToRight) throws -> Pixels {
        let components: [JSONValue] = [
            ["id": "box", "type": "Container", "kind": "layout", "childMode": "single",
             "props": .object(props), "children": ["child"], "watches": []],
            ["id": "child", "type": "Container", "kind": "layout", "childMode": "single",
             "props": .object(child), "children": [], "watches": []],
        ]
        let model = OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(components),
        ]).decode(PageResponse.self))

        let renderer = ImageRenderer(content: NodeView(id: "box", model: model)
            .frame(width: width, height: height, alignment: .topLeading)
            .environment(\.layoutDirection, direction))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}
#endif
