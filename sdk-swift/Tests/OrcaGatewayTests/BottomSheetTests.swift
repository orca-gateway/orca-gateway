#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A8.2: Flutter's BottomSheet builder (structure_builders.dart:235-249) is
/// a Container: padding 16, `backgroundColor` ?? white, top corners
/// `borderRadius` ?? 16, its child or nothing, drawn inline where it stands.
/// A Scaffold's `bottomSheet` slot is MUI's persistent sheet: at the content
/// bottom over the body, which keeps its frame (scaffold.dart:1171-1176,
/// :1240-1258), above the bottom bars, on the M3 sheet surface #F7F2FA with
/// top corners 28, at most 640 wide and centred (bottom_sheet.dart:350-420,
/// bottom_sheet_defaults_m3.g.dart:12-40), elevation 1 with no shadow; the
/// FAB rises until its centre is on the sheet's top edge
/// (floating_action_button_location.dart:565-586). A8.1: the Dialog draws
/// nothing in place (SB:229-233). ImageRenderer pixels at scale 1 (macOS
/// and iOS); what takes a touch, hit tests over text fields behind in a
/// hosted window (iOS). The registry is widened by the three types (they
/// are advertised in group 7).
@MainActor
final class BottomSheetTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: A8.2 the widget

    /// A8.2: a BottomSheet around a red 100x40 box is a white 132x72 box
    /// (padding 16 on each side), its top corners rounded 16, its bottom
    /// ones square; `dismissible` changes nothing.
    func testA8_2ABottomSheetIsAWhiteContainerPadded16WithTopCorners16() throws {
        let model = try page([sheet("s", ["c"]), box("c", "#FF0000", 100, 40),
                              sheet("off", ["c2"], ["dismissible": false]), box("c2", "#FF0000", 100, 40)])
        let pixels = try draw(model, "s", width: 200, height: 120)

        assertFrame(pixels.bounds(of: Self.isWhite), CGRect(x: 0, y: 0, width: 132, height: 72), "the sheet")
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 16, y: 16, width: 100, height: 40), "the child")
        assertColour(pixels.pixel(1, 1), Self.blue, "outside the top left corner")
        assertColour(pixels.pixel(130, 1), Self.blue, "outside the top right corner")
        assertColour(pixels.pixel(1, 70), Self.white, "the bottom left corner is square")
        assertColour(pixels.pixel(130, 70), Self.white, "the bottom right corner is square")
        XCTAssertEqual(try draw(model, "off", width: 200, height: 120).bytes, pixels.bytes,
                       "dismissible false changed the drawing")
    }

    /// A8.2: `backgroundColor` and `borderRadius` are its own: green with
    /// square corners at 0; a radius of 30 cuts deeper than 16.
    func testA8_2BackgroundColorAndBorderRadiusAreTheSheetsOwn() throws {
        let model = try page([
            sheet("square", ["c1"], ["backgroundColor": "#00FF00", "borderRadius": 0]), box("c1", "#FF0000", 100, 40),
            sheet("round", ["c2"], ["borderRadius": 30]), box("c2", "#FF0000", 100, 40),
        ])
        let square = try draw(model, "square", width: 200, height: 120)
        assertFrame(square.bounds(of: FlowTests.isGreen), CGRect(x: 0, y: 0, width: 132, height: 72), "green")
        assertColour(square.pixel(0, 0), (0, 255, 0), "a square top left corner")

        let round = try draw(model, "round", width: 200, height: 120)
        assertColour(round.pixel(6, 6), Self.blue, "radius 30 leaves (6, 6) outside")
        assertColour(round.pixel(20, 6), Self.white, "inside the sheet")
    }

    /// A8.2: with no child the sheet is its padding alone, 32x32 (its top
    /// edge a point, the two 16 corners meeting there).
    func testA8_2WithoutAChildTheSheetIsItsPaddingAlone() throws {
        let model = try page([sheet("s", [])])
        let pixels = try draw(model, "s", width: 100, height: 100)
        assertFrame(pixels.bounds(of: { !Self.isBlue($0) }), CGRect(x: 0, y: 0, width: 32, height: 32),
                    "the empty sheet")
        assertColour(pixels.pixel(16, 31), Self.white, "the sheet")
        assertColour(pixels.pixel(1, 1), Self.blue, "outside the top left corner")
    }

    // MARK: A8.2 the Scaffold slot

    /// A8.2: the slot lies over the body's bottom, centred, as tall as the
    /// sheet; the body keeps its whole frame (green all the way down beside
    /// the sheet), as Flutter lays the body out before the sheet and never
    /// shrinks it.
    func testA8_2TheSlotLiesOverTheBodysBottomAndTheBodyKeepsItsFrame() throws {
        let model = try page([
            scaffold("page", ["body": "body", "bottomSheet": "s"]),
            fill("body", "#00FF00"), sheet("s", ["c"]), box("c", "#FF0000", 100, 40),
        ])
        let pixels = try draw(model, "page", width: 300, height: 400)

        assertFrame(pixels.bounds(of: Self.isWhite), CGRect(x: 84, y: 328, width: 132, height: 72), "the sheet")
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 100, y: 344, width: 100, height: 40), "its child")
        assertFrame(pixels.bounds(of: FlowTests.isGreen), CGRect(x: 0, y: 0, width: 300, height: 400), "the body")
        assertColour(pixels.pixel(5, 398), (0, 255, 0), "the body beside the sheet at the bottom")
    }

    /// A8.2: with a bottomNavigationBar the sheet sits on the bar's top
    /// (contentBottom is above the bottom widgets), not under or over it.
    func testA8_2TheSlotSitsAboveTheBottomNavigationBar() throws {
        let model = try page([
            scaffold("page", ["body": "body", "bottomSheet": "s", "bottomNavigationBar": "nav"]),
            fill("body", "#00FF00"), sheet("s", ["c"]), box("c", "#FF0000", 100, 40),
            box("nav", "#FF00FF", 300, 50),
        ])
        let pixels = try draw(model, "page", width: 300, height: 400)

        assertFrame(pixels.bounds(of: FlowTests.isMagenta), CGRect(x: 0, y: 350, width: 300, height: 50), "the bar")
        assertFrame(pixels.bounds(of: Self.isWhite), CGRect(x: 84, y: 278, width: 132, height: 72), "the sheet")
    }

    /// A8.2: the slot is drawn on the sheet's Material, #F7F2FA
    /// (surfaceContainerLow) with top corners 28, no shadow and no tint:
    /// seen around a slot node that paints nothing itself (a padded
    /// Container). Over the green body: (6, 6) in from its top left corner
    /// lies outside a 28 radius (inside a 16 one), and just above its top
    /// edge the body is untouched.
    func testA8_2TheSlotIsOnTheSheetSurfaceWithTopCorners28AndNoShadow() throws {
        let model = try page([
            scaffold("page", ["body": "body", "bottomSheet": "plain"]),
            fill("body", "#00FF00"),
            node("plain", "Container", ["padding": ["top": 16, "right": 16, "bottom": 16, "left": 16]], ["c"]),
            box("c", "#FF0000", 100, 60),
        ])
        let pixels = try draw(model, "page", width: 300, height: 400)

        // The sheet: 132x92 at (84, 308).
        assertColour(pixels.pixel(86, 398), Self.surface, "the surface at the bottom left")
        assertColour(pixels.pixel(150, 312), Self.surface, "the surface at the top")
        assertColour(pixels.pixel(90, 314), (0, 255, 0), "outside the 28 corner")
        assertColour(pixels.pixel(150, 306), (0, 255, 0), "above the sheet: no shadow")
        assertColour(pixels.pixel(82, 398), (0, 255, 0), "beside the sheet")
    }

    /// A8.2: the sheet is at most 640 wide (M3's constraints), centred: a
    /// BottomSheet around a Row (which takes all the width it is given) is
    /// 640 wide in a 1000 wide Scaffold, and the Scaffold's width in a
    /// narrower one.
    func testA8_2TheSlotIsAtMost640WideAndCentred() throws {
        let model = try page([
            scaffold("page", ["body": "body", "bottomSheet": "s"]),
            fill("body", "#00FF00"), sheet("s", ["r"]), row("r", ["c"]), box("c", "#FF0000", 20, 20),
        ])
        let wide = try draw(model, "page", width: 1000, height: 300)
        assertFrame(wide.bounds(of: Self.isWhite), CGRect(x: 180, y: 248, width: 640, height: 52), "wide")

        let narrow = try draw(model, "page", width: 300, height: 300)
        assertFrame(narrow.bounds(of: Self.isWhite), CGRect(x: 0, y: 248, width: 300, height: 52), "narrow")
    }

    /// A8.2: the FAB (endFloat) rises above the sheet until its centre is on
    /// the sheet's top edge, and paints over the sheet: a 52 tall sheet in a
    /// 400 tall Scaffold puts the 56 FAB at y 400 - 52 - 28 = 320, 16 in
    /// from the end edge (the left in right-to-left). A sheet shorter than
    /// the FAB's margin leaves it 16 above the bottom.
    func testA8_2TheFabRisesUntilItsCentreIsOnTheSheetsTopEdge() throws {
        for (content, direction, expected) in [
            ("r", LayoutDirection.leftToRight, CGRect(x: 228, y: 320, width: 56, height: 56)),
            ("r", .rightToLeft, CGRect(x: 16, y: 320, width: 56, height: 56)),
            (nil, .leftToRight, CGRect(x: 228, y: 328, width: 56, height: 56)),
        ] as [(String?, LayoutDirection, CGRect)] {
            let model = try page([
                scaffold("page", ["body": "body", "bottomSheet": "s", "floatingActionButton": "f"]),
                fill("body", "#00FF00"), sheet("s", content.map { [$0] } ?? []), row("r", ["c"]),
                box("c", "#0000FF", 20, 20),
                node("f", "FloatingActionButton", ["backgroundColor": "#E53935", "elevation": 0], ["i"],
                     kind: "button"),
                node("i", "Icon", [:], [], kind: "primitive"),
            ])
            let pixels = try draw(model, "page", width: 300, height: 400, direction: direction)
            assertFrame(pixels.bounds(of: Pixels.isRed), expected, "content \(content ?? "none"), \(direction)")
        }
    }

    #if canImport(UIKit)
    /// A8.2: beside the sheet the body keeps taking touches (the slot's
    /// layer takes none where nothing is drawn); on the sheet a touch is the
    /// sheet's, as Flutter's Material and the Container's decoration take it.
    func testA8_2BesideTheSlotTheBodyTakesTouchesAndOnItTheSheetDoes() throws {
        let host = try Host(try page([
            scaffold("page", ["body": "probes", "bottomSheet": "s"]),
            node("probes", "Column", ["crossAxisAlignment": "stretch"], (0..<6).map { "p\($0)" }),
            sheet("s", ["c"]), node("c", "SizedBox", ["width": 60, "height": 20]),
        ] + (0..<6).map { field("p\($0)") }))
        defer { host.close() }
        // The sheet: 92x52 at (104, 68) in the 300x120 host, over fields 21 tall.
        host.assertTaken(CGPoint(x: 150, y: 100))
        host.assertTaken(CGPoint(x: 110, y: 115))
        host.assertPassed(CGPoint(x: 20, y: 100))
        host.assertPassed(CGPoint(x: 280, y: 100))
    }
    #endif

    // MARK: A8.1 the Dialog in place

    /// A8.1: a Dialog draws nothing where it stands (Flutter's
    /// SizedBox.shrink): in a Column its sibling follows at once, in a Row
    /// too, and its child (blue) is never drawn. It is still a child: in a
    /// Row with a gap of 10 it takes a gap on each side, as Flutter's zero
    /// box does, so an Expanded after [box 20, Dialog] starts at 20 + 10 +
    /// 0 + 10 = 40 (30 if it were no child at all). The switch has a view
    /// of its own for it, not its default's EmptyView.
    func testA8_1TheDialogDrawsNothingInPlaceAndTakesNoRoom() throws {
        let model = try page([
            node("col", "Column", ["crossAxisAlignment": "start"], ["a", "d", "b"]),
            node("line", "Row", ["mainAxisSize": "min"], ["a2", "d2", "b2"]),
            box("a", "#FF0000", 20, 20), dialog("d", ["inside"]), box("b", "#00FF00", 20, 20),
            box("a2", "#FF0000", 20, 20), dialog("d2", ["inside2"]), box("b2", "#00FF00", 20, 20),
            box("inside", "#0000FF", 50, 50), box("inside2", "#0000FF", 50, 50),
            node("gapped", "Row", ["gap": 10], ["a3", "d3", "e3"]),
            box("a3", "#FF0000", 20, 20), dialog("d3", ["inside3"]), box("inside3", "#0000FF", 50, 50),
            node("e3", "Expanded", [:], ["g3"]), node("g3", "Container", ["color": "#00FF00", "height": 20]),
        ])
        let gapped = try draw(model, "gapped", width: 100, height: 100, background: .white)
        assertFrame(gapped.bounds(of: FlowTests.isGreen), CGRect(x: 40, y: 0, width: 60, height: 20),
                    "gapped: the Expanded after the Dialog")
        XCTAssertNil(gapped.bounds(of: FlowTests.isBlue), "gapped: the Dialog's child was drawn")
        let column = try draw(model, "col", width: 100, height: 100, background: .white)
        assertFrame(column.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 20, height: 20), "column: before")
        assertFrame(column.bounds(of: FlowTests.isGreen), CGRect(x: 0, y: 20, width: 20, height: 20), "column: after")
        XCTAssertNil(column.bounds(of: FlowTests.isBlue), "column: the Dialog's child was drawn")

        let row = try draw(model, "line", width: 100, height: 100, background: .white)
        assertFrame(row.bounds(of: FlowTests.isGreen), CGRect(x: 20, y: 0, width: 20, height: 20), "row: after")
        XCTAssertNil(row.bounds(of: FlowTests.isBlue), "row: the Dialog's child was drawn")

        let drawn = Self.branch(WidgetView(node: try XCTUnwrap(model.resolve("d")), model: model).body)
        XCTAssertTrue(drawn is DialogNodeView, "the switch draws a Dialog with \(type(of: drawn))")
    }

    // MARK: pages

    /// A page of `nodes` (the first is the root) whose registry draws
    /// BottomSheet, SnackBar and Dialog; page state `onAction`, 0.
    func page(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [["key": "onAction", "scope": "page", "initial": 0]],
            "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: response, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(Self.types)))
    }

    nonisolated static let types: Set<String> = ["BottomSheet", "SnackBar", "Dialog"]

    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:], _ children: [String] = [],
              kind: String = "layout") -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": .string(kind),
            "childMode": children.count > 1 || ["Column", "Row"].contains(type) ? "multi"
                : children.isEmpty ? "none" : "single",
            "props": .object(props), "children": .array(children.map(JSONValue.string)), "watches": [],
        ]
    }

    func sheet(_ id: String, _ children: [String], _ props: [String: JSONValue] = [:]) -> JSONValue {
        node(id, "BottomSheet", props, children)
    }

    func dialog(_ id: String, _ children: [String]) -> JSONValue {
        node(id, "Dialog", ["dismissible": false, "backgroundColor": "#FF0000", "borderRadius": 28], children)
    }

    /// A Scaffold, its slot props holding the ids of nodes listed as its children.
    func scaffold(_ id: String, _ slots: [String: String]) -> JSONValue {
        ["id": .string(id), "type": "Scaffold", "kind": "structure", "childMode": "none",
         "props": .object(slots.mapValues(JSONValue.string)),
         "children": .array(slots.values.sorted().map(JSONValue.string)), "watches": []]
    }

    /// A solid `hex` Container, `width` x `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    /// A Container of `hex` with no size and no child: it fills what it is given.
    func fill(_ id: String, _ hex: String) -> JSONValue {
        node(id, "Container", ["color": .string(hex)])
    }

    /// A Row as wide as it is offered.
    func row(_ id: String, _ children: [String]) -> JSONValue {
        node(id, "Row", [:], children)
    }

    func field(_ id: String) -> JSONValue {
        node(id, "TextField", ["placeholder": .string(id)], kind: "input")
    }

    // MARK: pixels

    static let white: (Int, Int, Int) = (255, 255, 255)
    static let blue: (Int, Int, Int) = (0, 0, 255)
    /// M3's light surfaceContainerLow (color_scheme_defaults.g.dart:45).
    static let surface: (Int, Int, Int) = (0xF7, 0xF2, 0xFA)

    static func isWhite(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.r > 250 && p.g > 250 && p.b > 250
    }

    /// The blue drawn behind the node.
    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 250 && p.r < 5 && p.g < 5 && p.b > 250
    }

    /// Node `id` drawn at the top left of a light `width` x `height`
    /// picture at scale 1, over `background` (blue by default).
    func draw(_ model: OrcaPageModel, _ id: String, width: CGFloat, height: CGFloat,
              direction: LayoutDirection = .leftToRight, background: Color = Color(.sRGB, red: 0, green: 0, blue: 1))
        throws -> Pixels {
        let renderer = ImageRenderer(content: NodeView(id: id, model: model)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(background)
            .environment(\.layoutDirection, direction)
            .environment(\.colorScheme, .light))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "\(id) not drawn"))
    }

    func assertColour(_ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (Int, Int, Int),
                      _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let pairs = [(Int(actual.r), expected.0), (Int(actual.g), expected.1), (Int(actual.b), expected.2)]
        if pairs.contains(where: { abs($0.0 - $0.1) > 4 }) {
            XCTFail("\(message): \(actual) vs \(expected)", file: file, line: line)
        }
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, _ message: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected): \(message)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected): \(message)",
                           file: file, line: line)
        }
    }

    /// The view a `@ViewBuilder` switch chose, out of its conditional
    /// wrappers (as StructureWidgetTests reads it).
    static func branch(_ view: Any) -> Any {
        var current = view
        while String(describing: type(of: current)).hasPrefix("_ConditionalContent") {
            guard let storage = Mirror(reflecting: current).children.first?.value,
                  let chosen = Mirror(reflecting: storage).children.first?.value else { break }
            current = chosen
        }
        return current
    }

    #if canImport(UIKit)
    typealias Host = CheckboxRadioTests.Host
    #endif
}
#endif
