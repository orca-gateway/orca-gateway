#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// A7.2: where a DefaultTextStyle stops. Every Material puts its child under
/// the theme's text style (MUI material.dart:470-474), so a DTS above a
/// Card (card.dart:279), an ElevatedButton, OutlinedButton or TextButton
/// (button_style_button.dart:628), a FloatingActionButton (its
/// RawMaterialButton), an InkWell (the builder's transparent Material,
/// layout_builders.dart:620), a Scaffold (scaffold.dart:3415) or an AppBar
/// (app_bar.dart:1162, :1233) never reaches a Text inside: that Text draws
/// the same pixels as with no DTS (`apart`: within 2 levels a channel, as
/// the FAB's shadowed fill rounds apart by 1 from one render to the next;
/// the red 30-point Text would be far off). A Text beside the host, outside
/// any Material, takes the DTS (red, 30): the control. Flutter's IconButton
/// builder draws no Material (button_builders.dart:93-163), so the DTS
/// reaches a Text in it. ImageRenderer pixels at scale 1 (macOS and iOS);
/// on macOS ImageRenderer draws the AppKit-backed TextButton as a
/// placeholder (yellow, with a red sign), so the TextButton is checked on
/// the iOS scheme only. The registry is widened by the types the page uses.
@MainActor
final class TextStyleResetTests: XCTestCase {
    /// The DTS over every host: red, 30 points.
    static let dtsProps: [String: JSONValue] = ["style": ["color": "#FF0000", "fontSize": 30]]

    /// A7.2: a Card resets the DTS.
    func testA7_2ACardResetsTheDts() throws {
        try assertResets("card", [node("card", "Card", children: ["t"]), text("t", "Hi")])
    }

    /// A7.2: ElevatedButton, OutlinedButton and TextButton reset the DTS
    /// for their label (TextButton on iOS only, see above).
    func testA7_2TheButtonsResetTheDts() throws {
        #if os(macOS)
        let types = ["ElevatedButton", "OutlinedButton"]
        #else
        let types = ["ElevatedButton", "OutlinedButton", "TextButton"]
        #endif
        for type in types {
            try assertResets("b", [node("b", type, kind: "button", children: ["t"]), text("t", "Hi")])
        }
    }

    /// A7.2: a FloatingActionButton resets the DTS.
    func testA7_2AFloatingActionButtonResetsTheDts() throws {
        try assertResets("fab", [node("fab", "FloatingActionButton", kind: "button", children: ["t"]),
                                 text("t", "Hi")])
    }

    /// A7.2: an InkWell resets the DTS (the builder wraps it in a
    /// transparent Material, which still resets it).
    func testA7_2AnInkWellResetsTheDts() throws {
        try assertResets("ink", [node("ink", "InkWell", children: ["t"]), text("t", "Hi")])
    }

    /// A7.2: an AppBar resets the DTS for its title and its actions (its
    /// Material holds the whole toolbar; the title draws in the bar's own
    /// style, as before).
    func testA7_2AnAppBarResetsTheDtsForItsTitleAndActions() throws {
        try assertResets("bar", [
            node("bar", "AppBar", kind: "structure", childMode: "none", props: ["title": "t", "action_0": "a"],
                 children: ["t", "a"]),
            text("t", "Hi"), text("a", "Go"),
        ])
    }

    /// A7.2: a Scaffold resets the DTS for its body. The Scaffold fills the
    /// box, so the control is the same body with the DTS and no Scaffold.
    func testA7_2TheScaffoldBodyResetsTheDts() throws {
        let body = [column("col", ["t"]), text("t", "Hi")]
        let scaffold = [node("s", "Scaffold", kind: "structure", childMode: "none", props: ["body": "col"],
                             children: ["col"])] + body
        let alone = try draw(scaffold)
        let under = try draw([dts(child: "s")] + scaffold)
        XCTAssertLessThanOrEqual(Self.apart(under, alone), 2, "the DTS reached the Text in the Scaffold's body")
        let bare = try draw([dts(child: "col")] + body)
        XCTAssertNotNil(bare.bounds(of: Self.isRed), "the body without a Scaffold did not take the DTS")
    }

    /// A7.2: Flutter's IconButton builder puts no Material around its child
    /// (a SizedBox, an Opacity and a GestureDetector), so a Text in it takes
    /// the DTS.
    func testA7_2AnIconButtonPassesTheDtsThrough() throws {
        let under = try draw([dts(child: "ib"), node("ib", "IconButton", kind: "button", children: ["t"]),
                              text("t", "Hi")])
        XCTAssertNotNil(under.bounds(of: Self.isRed), "the Text in the IconButton did not take the DTS")
    }

    // MARK: helpers

    /// The host rooted at `root` (the first of `nodes`) draws the same pixels
    /// under the DTS as without it; in a Column under the DTS, the Text 40
    /// points below it (room for a shadow) takes the DTS, and no red ink
    /// reaches up into the host.
    func assertResets(_ root: String, _ nodes: [JSONValue], file: StaticString = #filePath,
                      line: UInt = #line) throws {
        let alone = try draw(nodes)
        let under = try draw([dts(child: root)] + nodes)
        XCTAssertLessThanOrEqual(Self.apart(under, alone), 2, "\(root): the DTS reached the Text inside",
                                 file: file, line: line)

        let host = try XCTUnwrap(alone.bounds(of: Self.isDrawn), "\(root): nothing drawn", file: file, line: line)
        let beside = try draw([dts(child: "beside"), column("beside", [root, "gap", "c"]),
                               node("gap", "SizedBox", props: ["height": 40])] + nodes + [text("c", "Hi")])
        let red = try XCTUnwrap(beside.bounds(of: Self.isRed), "\(root): the Text beside did not take the DTS",
                                file: file, line: line)
        XCTAssertGreaterThanOrEqual(red.minY, host.maxY, "\(root): red ink in the host \(host): \(red)",
                                    file: file, line: line)
    }

    func dts(child: String) -> JSONValue {
        node("d", "DefaultTextStyle", props: Self.dtsProps, children: [.string(child)])
    }

    func column(_ id: String, _ children: [String]) -> JSONValue {
        node(id, "Column", childMode: "multi", props: ["crossAxisAlignment": "start"],
             children: children.map { .string($0) })
    }

    func text(_ id: String, _ data: String) -> JSONValue {
        node(id, "Text", kind: "primitive", childMode: "none", props: ["data": .string(data)])
    }

    func node(_ id: String, _ type: String, kind: String = "layout", childMode: String = "single",
              props: [String: JSONValue] = [:], children: [JSONValue] = []) -> JSONValue {
        ["id": .string(id), "type": .string(type), "kind": .string(kind), "childMode": .string(childMode),
         "props": .object(props), "children": .array(children), "watches": []]
    }

    /// The page of `nodes` (the first is the root) drawn by ImageRenderer
    /// at scale 1 in a 300 by 200 box from the top leading corner, over
    /// white.
    func draw(_ nodes: [JSONValue]) throws -> Pixels {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as Pixels?, "no root node")
        }
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        let model = OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["DefaultTextStyle", "Card", "ElevatedButton", "OutlinedButton", "TextButton", "IconButton",
                    "FloatingActionButton", "InkWell", "AppBar", "Scaffold", "Column", "SizedBox", "Text"])))
        let renderer = ImageRenderer(content: NodeView(id: root, model: model)
            .frame(width: 300, height: 200, alignment: .topLeading)
            .background(Color.white))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
    }

    /// The DTS's red, solid: not a yellow or orange placeholder, not an
    /// antialiased edge.
    static func isRed(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.r > 200 && p.g < 90 && p.b < 90
    }

    /// The largest difference of one channel of one pixel between two
    /// pictures of the same size (255 when the sizes differ).
    static func apart(_ a: Pixels, _ b: Pixels) -> Int {
        guard a.width == b.width, a.height == b.height else { return 255 }
        return zip(a.bytes, b.bytes).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    /// Anything but the white background.
    static func isDrawn(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.r < 250 || p.g < 250 || p.b < 250
    }
}
#endif
