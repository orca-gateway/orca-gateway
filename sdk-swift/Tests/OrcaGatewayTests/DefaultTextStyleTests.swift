#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A7.2: DefaultTextStyle as Flutter's builder makes it (layout_builders
/// .dart:588-601): the replacing constructor (widgets/text.dart:63), so the
/// ambient style is dropped and what its style leaves unset is the engine's
/// (14 points, white, regular); a Text merges its own style over the DTS's
/// field by field, its own textAlign, maxLines and overflow winning
/// (text.dart:723-772); a nested DTS replaces the outer one; RichText
/// ignores it. ImageRenderer pixels at scale 1 (macOS and iOS); the
/// justified Text (a UIKit label) in a hosted window (iOS). DefaultTextStyle
/// and RichText are advertised only in group 7, so the page's registry is
/// widened by them.
@MainActor
final class DefaultTextStyleTests: XCTestCase {
    static let black: JSONValue = "#000000"
    static let words = "MMMM MMMM MMMM MMMM MMMM"

    /// A7.2: an unstyled Text under a DTS {fontWeight: bold} draws white,
    /// 14 points, bold, whatever the ambient font and colour.
    func testA7_2AnUnstyledTextUnderADtsDrawsWhiteFourteenBold() throws {
        let nodes = [dts("d", ["style": ["fontWeight": "bold"]], child: "t"), text("t", "MMMMMMMMMM")]
        let ambient: (AnyView) -> AnyView = { AnyView($0.font(.largeTitle).foregroundColor(.red)) }
        let alone = try draw(nodes, wrap: ambient)
        func line(_ weight: PlatformFont.Weight) -> CGSize {
            NSAttributedString(string: "MMMMMMMMMM",
                               attributes: [.font: PlatformFont.systemFont(ofSize: 14, weight: weight)]).size()
        }
        let bold = PlatformFont.systemFont(ofSize: 14, weight: .bold)
        XCTAssertGreaterThan(line(.bold).width, line(.regular).width + 3, "bold is not wider than regular here")
        XCTAssertEqual(CGFloat(alone.width), line(.bold).width, accuracy: 1.5,
                       "not 14 point bold: \(alone.width) vs \(line(.bold).width)")
        XCTAssertEqual(CGFloat(alone.height), ceil(bold.ascender - bold.descender + bold.leading), accuracy: 1,
                       "not one 14 point line: \(alone.height)")

        let dark = try draw(nodes, width: 200, height: 40, background: .black, wrap: ambient)
        let white = try XCTUnwrap(dark.bounds(of: Self.isWhite), "no white ink on the black box")
        XCTAssertLessThanOrEqual(white.maxY, 18, "white ink below one 14 point line: \(white)")
        XCTAssertNil(dark.bounds(of: Self.isColoured), "ink in a colour other than white (the ambient red)")
    }

    /// A7.2: the Text's own fontSize, color, textAlign and maxLines win over
    /// the DTS's; the DTS's fontWeight and overflow, which the Text leaves
    /// unset, still apply: the same pixels as that Text with those fields
    /// of its own and no DTS.
    func testA7_2ATextsOwnSizeColourAlignAndMaxLinesWin() throws {
        let own: [String: JSONValue] = ["style": ["fontSize": 16, "color": Self.black], "textAlign": "right",
                                        "maxLines": 2]
        let under = try draw([
            dts("d", ["style": ["fontSize": 30, "color": "#FF0000", "fontWeight": "bold"], "textAlign": "center",
                      "maxLines": 1, "overflow": "ellipsis"], child: "box"),
            box("box", width: 100, child: "t"),
            text("t", Self.words, own),
        ], width: 100, height: 100)
        let ink = try XCTUnwrap(under.bounds(of: Pixels.isInk), "no black ink")
        XCTAssertNil(under.bounds(of: Pixels.isRed), "the DTS colour beat the Text's own")
        XCTAssertGreaterThan(ink.height, 24, "one line: the DTS maxLines beat the Text's own 2: \(ink)")
        XCTAssertLessThan(ink.maxY, 45, "more than two 16 point lines: \(ink)")
        XCTAssertGreaterThanOrEqual(ink.maxX, 96, "not right aligned: \(ink)")

        let alone = try draw([
            box("box", width: 100, child: "t"),
            text("t", Self.words, ["style": ["fontSize": 16, "color": Self.black, "fontWeight": "bold"],
                                   "textAlign": "right", "maxLines": 2, "overflow": "ellipsis"]),
        ], width: 100, height: 100)
        XCTAssertTrue(under.bytes == alone.bytes,
                      "not the Text with its own fields over the DTS's fontWeight bold and overflow ellipsis")
    }

    /// A7.2: a DTS textAlign center centres a Text that sends none (own ??
    /// DTS ?? start); the Text's own textAlign wins.
    func testA7_2ADtsTextAlignCenterCentresAnUnalignedText() throws {
        func ink(_ own: [String: JSONValue]) throws -> CGRect {
            var props = own
            props["style"] = ["fontSize": 16, "color": Self.black]
            return try XCTUnwrap(draw([
                dts("d", ["style": [:], "textAlign": "center"], child: "box"),
                box("box", width: 200, child: "t"),
                text("t", "Hi", props),
            ], width: 200, height: 30).bounds(of: Pixels.isInk), "no ink")
        }
        XCTAssertEqual(try ink([:]).midX, 100, accuracy: 2, "the DTS textAlign center did not centre the Text")
        XCTAssertLessThanOrEqual(try ink(["textAlign": "left"]).minX, 3, "the Text's own textAlign left lost")
    }

    /// A7.2: DTS maxLines 1 with overflow ellipsis cuts a long Text to one
    /// line ending in dots; without `overflow` the DTS's clip cuts it after
    /// whole glyphs (layout_builders.dart:598).
    func testA7_2DtsMaxLinesOneWithEllipsisCutsALongText() throws {
        func cut(_ props: [String: JSONValue]) throws -> Pixels {
            var all = props
            all["style"] = ["fontSize": 16, "color": Self.black]
            return try draw([
                dts("d", all, child: "box"),
                box("box", width: 100, child: "t"),
                text("t", Self.words),
            ], width: 100, height: 120)
        }
        let ellipsis = try cut(["maxLines": 1, "overflow": "ellipsis"])
        let dots = try XCTUnwrap(ellipsis.bounds(of: Pixels.isInk), "no ink")
        XCTAssertLessThan(dots.height, 20, "more than one line: \(dots)")
        XCTAssertLessThanOrEqual(Self.inkRows(ellipsis, columns: Int(dots.maxX) - 3..<Int(dots.maxX)), 4,
                                 "maxLines 1 with ellipsis does not end in dots")

        let clip = try cut(["maxLines": 1])
        let glyphs = try XCTUnwrap(clip.bounds(of: Pixels.isInk), "no ink")
        XCTAssertLessThan(glyphs.height, 20, "more than one line: \(glyphs)")
        XCTAssertGreaterThanOrEqual(Self.inkRows(clip, columns: Int(glyphs.maxX) - 3..<Int(glyphs.maxX)), 8,
                                    "the DTS's clip ends in an ellipsis")
    }

    /// A7.2: a nested DTS replaces the outer one, never merges with it: the
    /// outer red, 30 points, italic, center and maxLines do not leak; the
    /// Text draws as under the inner DTS alone (white, 14, bold, start).
    func testA7_2ANestedDtsReplacesTheOuterOne() throws {
        let inner = dts("in", ["style": ["fontWeight": "bold"]], child: "box")
        let rest = [inner, box("box", width: 200, child: "t"), text("t", "MMMM MMMM")]
        let nested = try draw([
            dts("out", ["style": ["color": "#FF0000", "fontSize": 30, "fontStyle": "italic"], "textAlign": "center",
                        "maxLines": 1, "overflow": "ellipsis"], child: "in"),
        ] + rest, width: 200, height: 40, background: .black)
        let white = try XCTUnwrap(nested.bounds(of: Self.isWhite), "no white ink")
        XCTAssertNil(nested.bounds(of: Self.isColoured), "the outer DTS's red leaked")
        XCTAssertLessThanOrEqual(white.minX, 3, "the outer DTS's center leaked: \(white)")
        let alone = try draw(rest, width: 200, height: 40, background: .black)
        XCTAssertTrue(nested.bytes == alone.bytes, "the nested DTS is not the inner one alone")
    }

    /// A7.2: RichText ignores the DTS (raw RichText, primitive_builders.dart
    /// :325-348): the same pixels with and without one above it.
    func testA7_2ARichTextUnderADtsIsUnchanged() throws {
        let rest = [box("box", width: 200, child: "r"),
                    rich("r", ["text": "Hello ", "children": [["text": "world", "style": ["fontSize": 18]]]])]
        let under = try draw([
            dts("d", ["style": ["color": "#FF0000", "fontSize": 30, "fontWeight": "bold", "fontStyle": "italic"],
                      "textAlign": "center", "maxLines": 1, "overflow": "ellipsis"], child: "box"),
        ] + rest, width: 200, height: 40, background: .black)
        XCTAssertNotNil(under.bounds(of: Self.isWhite), "the RichText is not drawn")
        let alone = try draw(rest, width: 200, height: 40, background: .black)
        XCTAssertTrue(under.bytes == alone.bytes, "the DTS changed the RichText")
    }

    /// A7.2: with no DTS a Text draws as before: an unstyled Text is the
    /// plain SwiftUI Text, ambient font and colour showing through.
    func testA7_2WithoutADtsATextIsUnchanged() throws {
        let none: (AnyView) -> AnyView = { $0 }
        let ambient: (AnyView) -> AnyView = { AnyView($0.font(.title).foregroundColor(.red)) }
        for wrap in [none, ambient] {
            let node = try draw([text("t", "Hello")], wrap: wrap)
            let renderer = ImageRenderer(content: wrap(AnyView(Text("Hello"))))
            renderer.scale = 1
            let plain = try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
            XCTAssertEqual(node.width, plain.width)
            XCTAssertEqual(node.height, plain.height)
            XCTAssertTrue(node.bytes == plain.bytes, "a Text with no DTS is not the plain Text it was")
        }
    }

    #if canImport(UIKit)
    /// A7.2: a Text justified by its DTS draws through the UIKit label on
    /// the engine base too: white, its glyphs as tall as a start-aligned
    /// Text's under the same DTS (14 points), the first line stretched.
    func testA7_2AJustifiedTextUnderADtsDrawsOnTheEngineBase() throws {
        let words = "One two three four incomprehensibilities five six seven eight nine ten"
        func firstLine(_ align: JSONValue) throws -> (line: CGRect, pixels: Pixels) {
            let pixels = try hosted([
                dts("d", ["style": [:], "textAlign": align], child: "box"),
                box("box", width: 200, child: "t"),
                text("t", words),
            ], size: CGSize(width: 200, height: 120))
            let top = try XCTUnwrap(pixels.bounds(of: Self.isWhite), "no white ink").minY
            return (try XCTUnwrap(pixels.rows(Int(top)...Int(top) + 12).bounds(of: Self.isWhite)), pixels)
        }
        let start = try firstLine("start")
        let justified = try firstLine("justify")
        XCTAssertNil(justified.pixels.bounds(of: Self.isColoured), "the justified Text is not white")
        XCTAssertGreaterThanOrEqual(justified.line.maxX, 197, "justify did not stretch the first line")
        XCTAssertLessThan(start.line.maxX, justified.line.maxX - 3, "the words already filled the line")
        XCTAssertEqual(justified.line.height, start.line.height, accuracy: 1,
                       "the justified glyphs are not 14 points: \(justified.line) vs \(start.line)")
    }

    /// The page in a 300-point-wide UIKit window over black, read back at
    /// scale 1 (ImageRenderer cannot draw a UIKit label).
    func hosted(_ nodes: [JSONValue], size: CGSize) throws -> Pixels {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as Pixels?, "no root node")
        }
        let host = UIHostingController(rootView: NodeView(id: root, model: try Self.model(nodes))
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(Color.black)
            .ignoresSafeArea())
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        defer { window.isHidden = true }
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

    // MARK: pages

    func dts(_ id: String, _ props: [String: JSONValue], child: String) -> JSONValue {
        [
            "id": .string(id), "type": "DefaultTextStyle", "kind": "layout", "childMode": "single",
            "props": .object(props), "children": [.string(child)], "watches": [],
        ]
    }

    func box(_ id: String, width: Double, child: String) -> JSONValue {
        [
            "id": .string(id), "type": "Container", "kind": "layout", "childMode": "single",
            "props": ["width": .double(width)], "children": [.string(child)], "watches": [],
        ]
    }

    func text(_ id: String, _ data: String, _ props: [String: JSONValue] = [:]) -> JSONValue {
        var all = props
        all["data"] = .string(data)
        return [
            "id": .string(id), "type": "Text", "kind": "primitive", "childMode": "none",
            "props": .object(all), "children": [], "watches": [],
        ]
    }

    func rich(_ id: String, _ root: JSONValue) -> JSONValue {
        [
            "id": .string(id), "type": "RichText", "kind": "primitive", "childMode": "none",
            "props": ["text": root], "children": [], "watches": [],
        ]
    }

    /// The page of `nodes` (the first is the root), its registry widened by
    /// DefaultTextStyle and RichText.
    static func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["DefaultTextStyle", "RichText"])))
    }

    /// The root drawn by ImageRenderer at scale 1: at its own size, or in a
    /// `width` by `height` box from the top leading corner over
    /// `background`. `wrap` puts the ambient around it.
    func draw(_ nodes: [JSONValue], width: CGFloat? = nil, height: CGFloat? = nil,
              background: Color = .white, wrap: (AnyView) -> AnyView = { $0 }) throws -> Pixels {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as Pixels?, "no root node")
        }
        var view = AnyView(NodeView(id: root, model: try Self.model(nodes)))
        if let width, let height {
            view = AnyView(view.frame(width: width, height: height, alignment: .topLeading).background(background))
        }
        let renderer = ImageRenderer(content: wrap(view))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
    }

    /// How many rows hold dark ink within `columns` (`Pixels.inkHeight`
    /// counts any opaque pixel, and these pictures have a background).
    static func inkRows(_ pixels: Pixels, columns: Range<Int>) -> Int {
        (0..<pixels.height).filter { y in
            columns.contains { x in x >= 0 && x < pixels.width && Pixels.isInk(pixels.pixel(x, y)) }
        }.count
    }

    static func isWhite(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.r > 200 && p.g > 200 && p.b > 200
    }

    /// Any pixel whose channels differ: not white, grey or black.
    static func isColoured(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        abs(Int(p.r) - Int(p.g)) > 30 || abs(Int(p.g) - Int(p.b)) > 30 || abs(Int(p.r) - Int(p.b)) > 30
    }
}
#endif
