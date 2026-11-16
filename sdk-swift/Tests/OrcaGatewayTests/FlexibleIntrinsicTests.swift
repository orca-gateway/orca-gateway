#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// A3.4 (Flexible, Baseline) and A3.5: Flexible, IntrinsicHeight,
/// IntrinsicWidth and Baseline drawn as Flutter's render objects lay them
/// out (layout_builders.dart :234-240, :434-446, :469-479). Each test draws
/// a page through the real NodeView, its boxes solid Containers, and finds
/// each colour's frame in the pixels. The four types are not advertised yet
/// (group 5), so the page model here uses a registry widened with them.
@MainActor
final class FlexibleIntrinsicTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: A3.4 Flexible

    /// A3.4: in a Row of 300 the two flex children get shares of 150. The
    /// Flexible one keeps its child's own width (a Container around a 40
    /// wide box); the Expanded one fills its share, right after it.
    func testA3_4FlexibleIsLooseWhereExpandedIsTightInARow() throws {
        let pixels = try draw([
            node("row", "Row", ["crossAxisAlignment": "start"], ["flexible", "expanded"]),
            node("flexible", "Flexible", [:], ["red"]),
            node("red", "Container", ["color": "#FF0000", "height": 20], ["redInner"]),
            node("redInner", "SizedBox", ["width": 40, "height": 10]),
            node("expanded", "Expanded", [:], ["green"]),
            node("green", "Container", ["color": "#00FF00", "height": 20], ["greenInner"]),
            node("greenInner", "SizedBox", ["width": 40, "height": 10]),
        ], width: 300, height: 100)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 40, height: 20))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 40, y: 0, width: 150, height: 20))
    }

    /// A3.4: the same down a Column of 300.
    func testA3_4FlexibleIsLooseWhereExpandedIsTightInAColumn() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["flexible", "expanded"]),
            node("flexible", "Flexible", [:], ["red"]),
            node("red", "Container", ["color": "#FF0000", "width": 20], ["redInner"]),
            node("redInner", "SizedBox", ["width": 10, "height": 40]),
            node("expanded", "Expanded", [:], ["green"]),
            node("green", "Container", ["color": "#00FF00", "width": 20], ["greenInner"]),
            node("greenInner", "SizedBox", ["width": 10, "height": 40]),
        ], width: 100, height: 300)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 20, height: 40))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 40, width: 20, height: 150))
    }

    /// A3.4: `fit: tight` is Expanded's fit: the child fills the share.
    func testA3_4FlexibleTightFillsItsShare() throws {
        let pixels = try draw([
            node("row", "Row", ["crossAxisAlignment": "start"], ["flexible", "other"]),
            node("flexible", "Flexible", ["fit": "tight"], ["red"]),
            node("red", "Container", ["color": "#FF0000", "height": 20], ["redInner"]),
            node("redInner", "SizedBox", ["width": 40, "height": 10]),
            node("other", "Flexible", [:], ["green"]),
            box("green", "#00FF00", 40, 20),
        ], width: 300, height: 100)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 150, height: 20))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 150, y: 0, width: 40, height: 20))
    }

    /// A3.4: Flexible and Expanded share by `flex` alike (100 and 200 of
    /// 300); what the loose child leaves of its share goes to no one, and
    /// `mainAxisAlignment` places it (center: 30 on each side).
    func testA3_4FlexibleSharesByFlexAndLeavesTheRestToMainAxisAlignment() throws {
        let pixels = try draw([
            node("row", "Row", ["crossAxisAlignment": "start", "mainAxisAlignment": "center"],
                 ["flexible", "expanded"]),
            node("flexible", "Flexible", ["flex": 1], ["red"]),
            box("red", "#FF0000", 40, 20),
            node("expanded", "Expanded", ["flex": 2], ["green"]),
            node("green", "Container", ["color": "#00FF00", "height": 20]),
        ], width: 300, height: 100)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 30, y: 0, width: 40, height: 20))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 70, y: 0, width: 200, height: 20))

        // Two loose children (shares 150, 150) leave 200. end, spaceBetween,
        // and spaceEvenly with a gap: the Flutter SDK's gap box is a third
        // item, so 200 / 4 = 50 around each.
        for (props, red, green) in [
            (["mainAxisAlignment": "end"], 200, 240),
            (["mainAxisAlignment": "spaceBetween"], 0, 240),
            (["mainAxisAlignment": "spaceEvenly", "gap": 0], 50, 190),
        ] as [([String: JSONValue], CGFloat, CGFloat)] {
            var rowProps = props
            rowProps["crossAxisAlignment"] = "start"
            let pixels = try draw([
                node("row", "Row", rowProps, ["a", "b"]),
                node("a", "Flexible", [:], ["red"]), box("red", "#FF0000", 40, 20),
                node("b", "Flexible", [:], ["green"]), box("green", "#00FF00", 60, 20),
            ], width: 300, height: 100)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: red, y: 0, width: 40, height: 20))
            assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: green, y: 0, width: 60, height: 20))
        }
    }

    /// A3.4: outside a Row or Column Flexible just draws its child
    /// (Flutter's release behaviour).
    func testA3_4FlexibleOutsideARowOrColumnDrawsItsChild() throws {
        let pixels = try draw([
            node("flexible", "Flexible", ["flex": 3], ["red"]),
            box("red", "#FF0000", 40, 20),
        ], width: 200, height: 100)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 40, height: 20))
    }

    // MARK: A3.4 Baseline

    /// A3.4: a text's baseline sits `baseline` (40) below the Baseline's
    /// top whatever its size, so two texts in Baselines of the same value
    /// line up; `ideographic` is drawn as alphabetic (decision
    /// s3-baseline-ideographic).
    func testA3_4BaselinesWithTheSameValueLineUpTheirTexts() throws {
        var bottoms: [CGFloat] = []
        for (size, type) in [(12, "alphabetic"), (28, "alphabetic"), (28, "ideographic")] as [(Double, String)] {
            let pixels = try draw([
                node("base", "Baseline", ["baseline": 40, "baselineType": .string(type)], ["text"]),
                node("text", "Text", ["data": "H", "style": ["fontSize": .double(size)]]),
            ], width: 100, height: 100)
            let ink = try XCTUnwrap(pixels.bounds(of: Pixels.isInk), "\(size) \(type) not drawn")
            XCTAssertEqual(ink.maxY, 40, accuracy: 1, "\(size) \(type)")
            bottoms.append(ink.maxY)
        }
        XCTAssertEqual(bottoms[0], bottoms[1], accuracy: 1)
        XCTAssertEqual(bottoms[1], bottoms[2], accuracy: 1)
    }

    /// A3.4: a child with no baseline uses its height: its bottom sits at
    /// `baseline`, and the box is `baseline` tall (the green box below
    /// starts at 30).
    func testA3_4BaselineUsesTheHeightOfAChildWithoutABaseline() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["base", "green"]),
            node("base", "Baseline", ["baseline": 30, "baselineType": "alphabetic"], ["red"]),
            box("red", "#FF0000", 40, 10), box("green", "#00FF00", 10, 10),
        ], width: 200, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 20, width: 40, height: 10))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 30, width: 10, height: 10))
    }

    /// A3.4: under a parent that forces 100 by 100 the box takes that size,
    /// but its child is laid out loosely (a Container around a 40 by 10 box
    /// stays 40 by 10) at the left edge, in right-to-left too.
    func testA3_4BaselineLoosensATightParentForItsChild() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let pixels = try draw([
                node("sized", "SizedBox", ["width": 100, "height": 100], ["base"]),
                node("base", "Baseline", ["baseline": 30, "baselineType": "alphabetic"], ["red"]),
                node("red", "Container", ["color": "#FF0000"], ["inner"]),
                node("inner", "SizedBox", ["width": 40, "height": 10]),
            ], width: 100, height: 100, direction: direction)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 20, width: 40, height: 10))
        }
    }

    /// A3.4: `baseline` defaults to 0: the child's bottom sits at the box's
    /// top (drawn over the blue box above) and the box has no height (the
    /// green box follows the blue one directly).
    func testA3_4BaselineDefaultsToZero() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["blue", "base", "green"]),
            box("blue", "#0000FF", 10, 40),
            node("base", "Baseline", [:], ["red"]),
            box("red", "#FF0000", 40, 10), box("green", "#00FF00", 10, 10),
        ], width: 200, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 30, width: 40, height: 10))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 40, width: 10, height: 10))
    }

    // MARK: A3.5 IntrinsicHeight

    /// A3.5: IntrinsicHeight around a Row with `stretch` makes every child
    /// as tall as the tallest (50), and is 50 tall itself (the marker below
    /// starts at 50), not the page's 200.
    func testA3_5IntrinsicHeightMakesAStretchedRowAsTallAsItsTallestChild() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["intrinsic", "marker"]),
            node("intrinsic", "IntrinsicHeight", [:], ["row"]),
            node("row", "Row", ["crossAxisAlignment": "stretch"], ["red", "green", "blue"]),
            node("red", "Container", ["color": "#FF0000", "width": 30]),
            node("green", "Container", ["color": "#00FF00", "width": 30], ["greenInner"]),
            node("greenInner", "SizedBox", ["width": 30, "height": 50]),
            node("blue", "Container", ["color": "#0000FF", "width": 30], ["blueInner"]),
            node("blueInner", "SizedBox", ["width": 30, "height": 20]),
            box("marker", "#FF00FF", 10, 10),
        ], width: 300, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 30, height: 50))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 30, y: 0, width: 30, height: 50))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 60, y: 0, width: 30, height: 50))
        assertFrame(pixels.bounds(of: Self.isMagenta), CGRect(x: 0, y: 50, width: 10, height: 10))
    }

    /// A3.5: Baseline reports its child's intrinsic height (Flutter's
    /// RenderShiftedBox, shifted_box.dart:38-56), not one from `baseline`:
    /// the Row and the bar beside it are 10 tall; the 40 by 10 child still
    /// sits with its bottom 30 down, past the Row.
    func testA3_5IntrinsicHeightTakesABaselinesChildHeight() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["intrinsic", "marker"]),
            node("intrinsic", "IntrinsicHeight", [:], ["row"]),
            node("row", "Row", ["crossAxisAlignment": "stretch"], ["bar", "base"]),
            node("bar", "Container", ["color": "#FF0000", "width": 20]),
            node("base", "Baseline", ["baseline": 30, "baselineType": "alphabetic"], ["green"]),
            box("green", "#00FF00", 40, 10),
            box("marker", "#0000FF", 10, 10),
        ], width: 300, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 20, height: 10))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 20, y: 20, width: 40, height: 10))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 0, y: 10, width: 10, height: 10))
    }

    // MARK: A3.5 IntrinsicWidth

    /// A3.5: IntrinsicWidth around a Column with `stretch` makes every child
    /// as wide as the widest (80), and is 80 wide itself (the marker beside
    /// it starts at 80), not the page's 300.
    func testA3_5IntrinsicWidthMakesAStretchedColumnAsWideAsItsWidestChild() throws {
        let pixels = try draw([
            node("row", "Row", ["crossAxisAlignment": "start"], ["intrinsic", "marker"]),
            node("intrinsic", "IntrinsicWidth", [:], ["col"]),
            node("col", "Column", ["crossAxisAlignment": "stretch"], ["red", "green"]),
            node("red", "Container", ["color": "#FF0000", "height": 20]),
            node("green", "Container", ["color": "#00FF00", "height": 20], ["greenInner"]),
            node("greenInner", "SizedBox", ["width": 80, "height": 20]),
            box("marker", "#0000FF", 10, 10),
        ], width: 300, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 80, height: 20))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 20, width: 80, height: 20))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 80, y: 0, width: 10, height: 10))
    }

    /// A3.5: `stepWidth` rounds the width up to a multiple of it (80 → 100);
    /// `stepHeight` makes the height the child's max intrinsic height
    /// rounded up to a multiple of it (30 → 50).
    func testA3_5IntrinsicWidthRoundsUpToItsSteps() throws {
        for (props, size) in [(["stepWidth": 50], CGSize(width: 100, height: 30)),
                              (["stepHeight": 25], CGSize(width: 80, height: 50)),
                              (["stepWidth": 30, "stepHeight": 20], CGSize(width: 90, height: 40))]
            as [([String: JSONValue], CGSize)] {
            let pixels = try draw([
                node("intrinsic", "IntrinsicWidth", props, ["red"]),
                node("red", "Container", ["color": "#FF0000"], ["inner"]),
                node("inner", "SizedBox", ["width": 80, "height": 30]),
            ], width: 300, height: 200)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(origin: .zero, size: size))
        }
    }

    // MARK: helpers

    /// The four types on top of what the SDK advertises today.
    static let registry = WidgetRegistry(types: Set(GeneratedCapabilities.widgets).union([
        "Baseline", "Flexible", "IntrinsicHeight", "IntrinsicWidth",
    ]))

    static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.g > 200 && p.r < 60 && p.b < 60
    }

    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.b > 200 && p.r < 60 && p.g < 60
    }

    static func isMagenta(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.r > 200 && p.b > 200 && p.g < 60
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// A wire node: Row and Column hold many children, Text none, every
    /// other type one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
              _ children: [String] = []) -> JSONValue {
        let mode = ["Row", "Column"].contains(type) ? "multi" : type == "Text" ? "none" : "single"
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
        ]).decode(PageResponse.self), registry: Self.registry)
    }

    func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    /// The first node drawn with ImageRenderer at scale 1 in a `width` by
    /// `height` box from the top leading corner.
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat,
              direction: LayoutDirection = .leftToRight) throws -> Pixels {
        let view = NodeView(id: try rootId(nodes), model: try model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
            .environment(\.layoutDirection, direction)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}
#endif
