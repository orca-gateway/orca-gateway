#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A1.10 and A1.12 (Flutter LB:119-263): a Row or Column's direction props
/// stay with its own layout, Center's factors, SingleChildScrollView's
/// reverse and shrinkWrap, and Padding's absolute sides (D4). Each test
/// draws a page through the real NodeView and finds its solid colours in
/// the pixels: ImageRenderer where it can draw the views, a UIKit window
/// for a scroll view's offset (iOS only).
@MainActor
final class LayoutTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: A1.10 children keep the ambient direction

    /// A1.10: a Column's textDirection does not reach its children: a
    /// stretched Text aligned `start` sits at the ambient start (Flutter's
    /// Text reads Directionality, which the Column does not change).
    func testA1_10ATextChildKeepsTheAmbientDirection() throws {
        let text = node("t", "Text", ["data": "Hi", "textAlign": "start",
                                      "style": ["fontSize": 20, "color": "#FF0000"]])
        for spacer in [false, true] {
            let extra = spacer ? [node("s", "Spacer")] : []
            let ids = ["t"] + (spacer ? ["s"] : [])
            let rtl = try draw([node("col", "Column", ["textDirection": "rtl", "crossAxisAlignment": "stretch"], ids),
                                text] + extra, width: 200, height: 50)
            XCTAssertLessThan(try XCTUnwrap(rtl.bounds(of: Pixels.isRed)).maxX, 100, "spacer \(spacer)")
            let ltr = try draw([node("col", "Column", ["textDirection": "ltr", "crossAxisAlignment": "stretch"], ids),
                                text] + extra, width: 200, height: 50, direction: .rightToLeft)
            XCTAssertGreaterThan(try XCTUnwrap(ltr.bounds(of: Pixels.isRed)).minX, 100, "spacer \(spacer)")
        }
    }

    // MARK: A1.10 Center factors

    /// A1.10: widthFactor 0.5 and heightFactor 2 around a 40x20 child make
    /// a 20x40 Center with the child centred (half of each colour shows).
    func testA1_10CenterWidthFactorHalfHeightFactorTwoIsTwentyByForty() throws {
        let pixels = try draw([
            node("center", "Center", ["widthFactor": 0.5, "heightFactor": 2], ["row"]),
            node("row", "Row", ["mainAxisSize": "min"], ["red", "green"]),
            box("red", "#FF0000", 20, 20), box("green", "#00FF00", 20, 20),
        ])
        XCTAssertEqual(pixels.width, 20)
        XCTAssertEqual(pixels.height, 40)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 10, width: 10, height: 20))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 10, y: 10, width: 10, height: 20))
    }

    /// A1.10: an axis with no factor fills; the given one is child × factor.
    func testA1_10CenterFillsTheAxisWithNoFactor() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["center", "green"]),
            node("center", "Center", ["heightFactor": 2], ["red"]),
            box("red", "#FF0000", 40, 20), box("green", "#00FF00", 10, 10),
        ], width: 200, height: 300)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 80, y: 10, width: 40, height: 20))
        XCTAssertEqual(try XCTUnwrap(pixels.bounds(of: Self.isGreen)).minY, 40, accuracy: Self.accuracy)
    }

    // MARK: D4 Padding

    /// D4: a Padding's left stays on the left in right-to-left.
    func testD4PaddingLeftStaysLeftInRightToLeft() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let pixels = try draw([
                node("pad", "Padding", ["padding": ["top": 0, "right": 5, "bottom": 0, "left": 20]], ["red"]),
                box("red", "#FF0000", 10, 10),
            ], direction: direction)
            XCTAssertEqual(pixels.width, 35)
            XCTAssertEqual(try XCTUnwrap(pixels.bounds(of: Pixels.isRed)).minX, 20, "in \(direction)")
        }
    }

    // MARK: A1.12 SingleChildScrollView

    /// A1.12: shrinkWrap hugs the content on the scroll axis (Flutter's
    /// IntrinsicHeight) instead of taking all the height offered.
    func testA1_12ShrinkWrapScrollHugsItsContentHeight() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["scroll", "green"]),
            node("scroll", "SingleChildScrollView", ["shrinkWrap": true], ["red"]),
            box("red", "#FF0000", 100, 50), box("green", "#00FF00", 100, 20),
        ], width: 100, height: 300)
        XCTAssertEqual(try XCTUnwrap(pixels.bounds(of: Self.isGreen)).minY, 50, accuracy: Self.accuracy)
    }

    #if canImport(UIKit)
    /// A1.12: shrinkWrap never makes the scroll view longer than offered
    /// (Flutter's IntrinsicHeight is constrained by its parent): in a 300
    /// high Center, 500 of content scroll in a 300 high view from the top.
    func testA1_12ShrinkWrapScrollStopsAtTheBounds() throws {
        let pixels = try hosted([
            node("center", "Center", [:], ["scroll"]),
            node("scroll", "SingleChildScrollView", ["shrinkWrap": true], ["col"]),
            node("col", "Column", ["mainAxisSize": "min"], ["red", "green"]),
            box("red", "#FF0000", 100, 250), box("green", "#00FF00", 100, 250),
        ], width: 100, height: 300)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 100, height: 250))
    }

    /// A1.12: reverse starts at the far end: the last of five 100-high
    /// items fills the bottom of a 200-high view, the first is out of sight.
    func testA1_12ReverseScrollShowsTheLastItem() throws {
        let pixels = try hosted([
            node("scroll", "SingleChildScrollView", ["reverse": true], ["col"]),
            node("col", "Column", ["mainAxisSize": "min"], ["red", "g1", "g2", "g3", "blue"]),
            box("red", "#FF0000", 100, 100), box("g1", "#00FF00", 100, 100), box("g2", "#00FF00", 100, 100),
            box("g3", "#00FF00", 100, 100), box("blue", "#0000FF", 100, 100),
        ], width: 100, height: 200)
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 0, y: 100, width: 100, height: 100))
        XCTAssertNil(pixels.bounds(of: Pixels.isRed))

        let row = try hosted([
            node("scroll", "SingleChildScrollView", ["reverse": true, "scrollDirection": "horizontal"], ["row"]),
            node("row", "Row", ["mainAxisSize": "min"], ["red", "g1", "blue"]),
            box("red", "#FF0000", 100, 100), box("g1", "#00FF00", 300, 100), box("blue", "#0000FF", 100, 100),
        ], width: 200, height: 100)
        assertFrame(row.bounds(of: Self.isBlue), CGRect(x: 100, y: 0, width: 100, height: 100))
        XCTAssertNil(row.bounds(of: Pixels.isRed))
    }

    /// A1.12: reverse puts content shorter than the view at the far end.
    func testA1_12ReverseScrollPutsShortContentAtTheFarEnd() throws {
        let pixels = try hosted([
            node("scroll", "SingleChildScrollView", ["reverse": true], ["red"]),
            box("red", "#FF0000", 100, 50),
        ], width: 100, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 150, width: 100, height: 50))
    }

    /// D4: a scroll view's padding keeps left on the left in right-to-left.
    func testD4ScrollPaddingLeftStaysLeftInRightToLeft() throws {
        let pixels = try hosted([
            node("scroll", "SingleChildScrollView", ["padding": ["top": 0, "right": 5, "bottom": 0, "left": 20]],
                 ["red"]),
            box("red", "#FF0000", 75, 50),
        ], width: 100, height: 200, direction: .rightToLeft)
        XCTAssertEqual(try XCTUnwrap(pixels.bounds(of: Pixels.isRed)).minX, 20, accuracy: Self.accuracy)
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

    /// A wire node: Row and Column hold many children, Text and Spacer none.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
              _ children: [String] = []) -> JSONValue {
        let mode = ["Row", "Column"].contains(type) ? "multi" : ["Text", "Spacer"].contains(type) ? "none" : "single"
        return [
            "id": .string(id), "type": .string(type), "kind": type == "Text" ? "primitive" : "layout",
            "childMode": .string(mode), "props": .object(props), "children": .array(children.map { .string($0) }),
            "watches": [],
        ]
    }

    /// A solid Container of `hex`, `width` by `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self))
    }

    func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    /// The first node drawn with ImageRenderer at scale 1: in a `width` by
    /// `height` box from the top leading corner, or at its own size.
    func draw(_ nodes: [JSONValue], width: CGFloat? = nil, height: CGFloat? = nil,
              direction: LayoutDirection = .leftToRight) throws -> Pixels {
        let view = NodeView(id: try rootId(nodes), model: try model(nodes))
        let content: AnyView
        if let width, let height {
            content = AnyView(view.frame(width: width, height: height, alignment: .topLeading)
                .environment(\.layoutDirection, direction))
        } else {
            content = AnyView(view.environment(\.layoutDirection, direction))
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }

    #if canImport(UIKit)
    /// The first node in a UIKit window `width` by `height`, for the views
    /// ImageRenderer cannot draw (a scroll view at its offset). Scale 1.
    func hosted(_ nodes: [JSONValue], width: CGFloat, height: CGFloat,
                direction: LayoutDirection = .leftToRight) throws -> Pixels {
        let size = CGSize(width: width, height: height)
        let host = UIHostingController(rootView: NodeView(id: try rootId(nodes), model: try model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
            .environment(\.layoutDirection, direction)
            .ignoresSafeArea())
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }
    #endif
}
#endif
