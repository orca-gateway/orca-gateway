#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// A7.4 (as corrected): Table as the Flutter SDK's builder makes it
/// (layout_builders.dart:646-666). Each child is a one-cell row of Flutter's
/// single FlexColumnWidth(1) column: the table's width (the parent's
/// maximum; with none, the minimum, 0), its own height, rows stacked from
/// the top. `border` sent is TableBorder.all(color ?? black, width ?? 1),
/// painted over the cells: the outer lines inside the table's rect, the
/// lines between rows centred on the row boundaries. columnWidths and
/// defaultColumnWidth are never read. The same cases as Kotlin's TableTest.
///
/// Pages are drawn by ImageRenderer at scale 1 in a box from the top left,
/// on white. Table is advertised only in group 7, so the page's registry is
/// widened by it.
@MainActor
final class TableTests: XCTestCase {
    static let red = (r: 0xFF, g: 0, b: 0)
    static let green = (r: 0, g: 0xFF, b: 0)
    static let blue = (r: 0, g: 0, b: 0xFF)
    static let magenta = (r: 0xFF, g: 0, b: 0xFF)
    static let black = (r: 0, g: 0, b: 0)
    static let white = (r: 0xFF, g: 0xFF, b: 0xFF)

    /// A7.4: three children of 30, 20 and 50 points, whatever their own
    /// widths (40, 80, 10), are rows at y 0, 30 and 50, each the table's
    /// width: the loose parent's maximum, 300. The table is as high as its
    /// rows: the yellow box after it in a Column starts at 100.
    func testA7_4TableStacksEachChildAsAFullWidthRowAtItsOwnHeight() throws {
        let pixels = try draw([
            node("root", "Column", [:], ["t", "after"], childMode: "multi"),
            node("t", "Table", [:], ["a", "b", "c"], childMode: "multi"),
            cell("a", "#FF0000", height: 30, width: 40),
            cell("b", "#00FF00", height: 20, width: 80),
            cell("c", "#0000FF", height: 50, width: 10),
            cell("after", "#FFFF00", height: 10, width: 20),
        ], width: 300, height: 400)

        assertRect(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 300, height: 30), "a")
        assertRect(pixels.bounds(of: RichTextTests.isGreen), CGRect(x: 0, y: 30, width: 300, height: 20), "b")
        assertRect(pixels.bounds(of: RichTextTests.isBlue), CGRect(x: 0, y: 50, width: 300, height: 50), "c")
        let after = try XCTUnwrap(pixels.bounds(of: AppBarCardTests.isYellow), "nothing after the table")
        XCTAssertEqual(after.minY, 100, accuracy: 0.5, "the table is not as high as its rows: \(after)")
    }

    /// A7.4: a 4-point #FF00FF border over red, green and blue rows of 40,
    /// 30 and 50: the outer lines fill 4 points inside the 200 x 120 rect
    /// (nothing outside it), the lines between rows 2 points either side of
    /// y 40 and 70, over the cells; the cells show between the lines.
    func testA7_4TableBorderDrawsTheOuterLinesInsideAndTheRowLinesCentredOverTheCells() throws {
        let pixels = try draw([
            node("t", "Table", ["border": ["color": "#FF00FF", "width": 4]], ["a", "b", "c"], childMode: "multi"),
            cell("a", "#FF0000", height: 40),
            cell("b", "#00FF00", height: 30),
            cell("c", "#0000FF", height: 50),
        ], width: 200, height: 200)

        // The outer lines, inside the rect.
        for (x, y) in [(100, 0), (100, 3), (0, 20), (3, 20), (196, 20), (199, 20), (100, 116), (100, 119)] {
            assertColour(Self.magenta, pixels, x, y)
        }
        assertColour(Self.red, pixels, 100, 4)
        assertColour(Self.red, pixels, 4, 20)
        assertColour(Self.red, pixels, 195, 20)
        assertColour(Self.blue, pixels, 100, 115)
        assertColour(Self.white, pixels, 100, 121)
        // The row lines, centred on y 40 and 70, across the whole width.
        for (x, y) in [(100, 38), (100, 41), (10, 39), (190, 40), (100, 68), (100, 71)] {
            assertColour(Self.magenta, pixels, x, y)
        }
        assertColour(Self.red, pixels, 100, 37)
        assertColour(Self.green, pixels, 100, 42)
        assertColour(Self.green, pixels, 100, 67)
        assertColour(Self.blue, pixels, 100, 72)
    }

    /// A7.4: `border: {}` is black and 1 point wide: the outer pixel ring
    /// of the 200 x 70 rect is black, the line between the rows at y 40
    /// half covers the pixels above and below it.
    func testA7_4TableEmptyBorderIsBlackAndOneWide() throws {
        let pixels = try draw([
            node("t", "Table", ["border": [:]], ["a", "b"], childMode: "multi"),
            node("a", "SizedBox", ["height": 40]),
            node("b", "SizedBox", ["height": 30]),
        ], width: 200, height: 200)

        for (x, y) in [(100, 0), (0, 20), (199, 20), (100, 69), (0, 55), (199, 55)] {
            assertColour(Self.black, pixels, x, y)
        }
        for (x, y) in [(100, 1), (1, 20), (198, 20), (100, 68), (100, 70), (100, 38), (100, 41)] {
            assertColour(Self.white, pixels, x, y)
        }
        assertHalfBlack(pixels, 100, 39)
        assertHalfBlack(pixels, 100, 40)
    }

    /// A7.4: no border, no lines: the cells' own colours at the edges and on
    /// both sides of each boundary.
    func testA7_4TableWithoutBorderDrawsNoLines() throws {
        let pixels = try draw([
            node("t", "Table", [:], ["a", "b", "c"], childMode: "multi"),
            cell("a", "#FF0000", height: 40),
            cell("b", "#00FF00", height: 30),
            cell("c", "#0000FF", height: 50),
        ], width: 200, height: 200)

        for (x, y) in [(100, 0), (0, 20), (199, 20), (100, 39)] { assertColour(Self.red, pixels, x, y) }
        for (x, y) in [(100, 40), (0, 55), (199, 55), (100, 69)] { assertColour(Self.green, pixels, x, y) }
        for (x, y) in [(100, 70), (100, 119)] { assertColour(Self.blue, pixels, x, y) }
        assertColour(Self.white, pixels, 100, 120)
    }

    /// A7.4: columnWidths and defaultColumnWidth sent change nothing: the
    /// bordered table draws pixel for pixel what it draws without them, its
    /// rows the full 300 at their own heights.
    func testA7_4TableColumnWidthsAndDefaultColumnWidthChangeNothing() throws {
        func table(_ props: [String: JSONValue]) throws -> Pixels {
            var props = props
            props["border"] = ["color": "#FF00FF", "width": 2]
            return try draw([
                node("t", "Table", props, ["a", "b"], childMode: "multi"),
                cell("a", "#FF0000", height: 30, width: 40),
                cell("b", "#0000FF", height: 20, width: 120),
            ], width: 300, height: 200)
        }

        let plain = try table([:])
        let sent = try table(["columnWidths": ["0": 50, "1": 2], "defaultColumnWidth": 80])

        assertRect(plain.bounds(of: Pixels.isRed), CGRect(x: 2, y: 2, width: 296, height: 27), "a")
        assertRect(plain.bounds(of: RichTextTests.isBlue), CGRect(x: 2, y: 31, width: 296, height: 17), "b")
        XCTAssertEqual(plain.width, sent.width)
        XCTAssertEqual(plain.height, sent.height)
        XCTAssertTrue(plain.bytes == sent.bytes, "columnWidths or defaultColumnWidth changed the picture")
    }

    /// A7.4: unbounded width, a Row's main axis or no width offered at all
    /// (a horizontal scroll): Flutter's flex column has no intrinsic width
    /// (FlexColumnWidth.maxIntrinsicWidth is 0, rendering/table.dart
    /// :212-214) and grows only to the minimum, so the table and its rows
    /// are 0 wide (nothing red or green, the next box at x 0), the rows
    /// their own heights (what follows starts 50 down).
    func testA7_4TableUnderUnboundedWidthIsItsMinimumWidthZeroWide() throws {
        let rows = [
            node("t", "Table", [:], ["a", "b"], childMode: "multi"),
            cell("a", "#FF0000", height: 30, width: 50),
            cell("b", "#00FF00", height: 20, width: 120),
        ]
        let inRow = try draw([
            node("root", "Column", ["crossAxisAlignment": "start"], ["row", "below"], childMode: "multi"),
            node("row", "Row", [:], ["t", "beside"], childMode: "multi"),
        ] + rows + [
            cell("beside", "#FFFF00", height: 10, width: 20),
            cell("below", "#0000FF", height: 10, width: 20),
        ], width: 300, height: 200)

        XCTAssertNil(inRow.bounds(of: Pixels.isRed), "the table in a Row is not 0 wide")
        XCTAssertNil(inRow.bounds(of: RichTextTests.isGreen), "the table in a Row is not 0 wide")
        let beside = try XCTUnwrap(inRow.bounds(of: AppBarCardTests.isYellow), "nothing beside the table")
        XCTAssertEqual(beside.minX, 0, accuracy: 0.5, "the table in a Row is not 0 wide: \(beside)")
        let below = try XCTUnwrap(inRow.bounds(of: RichTextTests.isBlue), "nothing below the Row")
        XCTAssertEqual(below.minY, 50, accuracy: 0.5, "the table in a Row is not 50 high: \(below)")

        let model = try Self.model(rows)
        let unoffered = try picture(VStack(alignment: .leading, spacing: 0) {
            NodeView(id: "t", model: model).fixedSize(horizontal: true, vertical: false)
            Color(red: 0, green: 0, blue: 1).frame(width: 20, height: 10)
        }, width: 300, height: 200)

        XCTAssertNil(unoffered.bounds(of: Pixels.isRed), "the table offered no width is not 0 wide")
        XCTAssertNil(unoffered.bounds(of: RichTextTests.isGreen), "the table offered no width is not 0 wide")
        let after = try XCTUnwrap(unoffered.bounds(of: RichTextTests.isBlue), "nothing below the table")
        XCTAssertEqual(after.minY, 50, accuracy: 0.5, "the table offered no width is not 50 high: \(after)")
    }

    // MARK: helpers

    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:], _ children: [String] = [],
              childMode: String = "single") -> JSONValue {
        ["id": .string(id), "type": .string(type), "kind": "layout", "childMode": .string(childMode),
         "props": .object(props), "children": .array(children.map { .string($0) }), "watches": []]
    }

    /// A row of `height` filled with `colour`: a Container with no child,
    /// `width` wide on its own.
    func cell(_ id: String, _ colour: String, height: Double, width: Double? = nil) -> JSONValue {
        var props: [String: JSONValue] = ["height": .double(height), "color": .string(colour)]
        if let width { props["width"] = .double(width) }
        return node(id, "Container", props)
    }

    /// The page of `nodes` (the first is the root), its registry widened by
    /// Table.
    static func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["Table"])))
    }

    /// The page drawn from its root in a `width` by `height` box.
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat) throws -> Pixels {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as Pixels?, "no root node")
        }
        return try picture(NodeView(id: root, model: Self.model(nodes)), width: width, height: height)
    }

    /// `view` drawn by ImageRenderer at scale 1 in a `width` by `height` box
    /// from the top left, on white.
    func picture<V: View>(_ view: V, width: CGFloat, height: CGFloat) throws -> Pixels {
        let renderer = ImageRenderer(content: view
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Color.white))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
    }

    func assertRect(_ actual: CGRect?, _ expected: CGRect, _ name: String,
                    file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("\(name) not drawn, expected \(expected)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: 0.5, "\(name): \(actual) vs \(expected)", file: file, line: line)
        }
    }

    func assertColour(_ expected: (r: Int, g: Int, b: Int), _ pixels: Pixels, _ x: Int, _ y: Int,
                      file: StaticString = #filePath, line: UInt = #line) {
        let p = pixels.pixel(x, y)
        let close = abs(Int(p.r) - expected.r) <= 8 && abs(Int(p.g) - expected.g) <= 8
            && abs(Int(p.b) - expected.b) <= 8
        XCTAssertTrue(close, "(\(x), \(y)) is \(p), expected \(expected)", file: file, line: line)
    }

    /// A pixel half covered by a black line on white: grey, neither white
    /// nor black.
    func assertHalfBlack(_ pixels: Pixels, _ x: Int, _ y: Int, file: StaticString = #filePath, line: UInt = #line) {
        let p = pixels.pixel(x, y)
        let grey = [p.r, p.g, p.b].allSatisfy { (0x40...0xC0).contains(Int($0)) }
        XCTAssertTrue(grey, "(\(x), \(y)) is \(p), expected a half-covered grey", file: file, line: line)
    }
}
#endif
