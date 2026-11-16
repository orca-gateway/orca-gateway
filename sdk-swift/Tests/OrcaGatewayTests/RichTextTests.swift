#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A7.1: RichText draws its span tree as Flutter's builder does
/// (primitive_builders.dart:325-348): one paragraph of runs, each span's
/// style merged onto its parent's (TextStyles), on the engine's defaults
/// for what the root leaves unset (14 points, white, regular; never the
/// ambient style), no text scaling, start, softWrap, clip unless sent,
/// maxLines. ImageRenderer pixels at scale 1 (macOS and iOS); the redraw
/// on SetState in a hosted window (iOS). RichText is advertised only in
/// group 7, so the page's registry is widened by it.
@MainActor
final class RichTextTests: XCTestCase {
    static let black: JSONValue = "#000000"

    /// A7.1: an unstyled root draws white at 14 points: on its own it is
    /// as big as "Hello" in the 14 point system font, and on a black box
    /// its ink is white, no other colour.
    func testA7_1AnUnstyledRootDrawsWhiteFourteenPointText() throws {
        let alone = try draw([rich(["text": "Hello"])])
        let font = PlatformFont.systemFont(ofSize: 14)
        let line = NSAttributedString(string: "Hello", attributes: [.font: font]).size()
        XCTAssertEqual(CGFloat(alone.height), ceil(font.ascender - font.descender + font.leading), accuracy: 1,
                       "not one 14 point line: \(alone.width) x \(alone.height)")
        XCTAssertEqual(CGFloat(alone.width), line.width, accuracy: 1.5,
                       "not 'Hello' at 14 points: \(alone.width) vs \(line.width)")

        let dark = try draw([
            node("box", "Container", ["color": Self.black, "width": 200, "height": 40, "alignment": "topLeft"], ["t"]),
            rich(["text": "Hello"]),
        ], width: 200, height: 40)
        let white = try XCTUnwrap(dark.bounds(of: Self.isWhite), "no white ink on the black box")
        XCTAssertLessThanOrEqual(white.maxY, 18, "white ink below one 14 point line: \(white)")
        XCTAssertNil(dark.bounds(of: Self.isColoured), "ink in a colour other than white")
    }

    /// A7.1: nested spans in three colours draw side by side on one line,
    /// in span order.
    func testA7_1NestedSpansDrawThreeColoursOnOneLine() throws {
        let pixels = try draw([rich([
            "text": "MMM", "style": ["color": "#FF0000"],
            "children": [[
                "text": "MMM", "style": ["color": "#00FF00"],
                "children": [["text": "MMM", "style": ["color": "#0000FF"]]],
            ]],
        ])], width: 300, height: 40)
        let red = try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "no red run")
        let green = try XCTUnwrap(pixels.bounds(of: Self.isGreen), "no green run")
        let blue = try XCTUnwrap(pixels.bounds(of: Self.isBlue), "no blue run")
        XCTAssertLessThan(red.maxX, green.minX + 1, "red \(red) is not before green \(green)")
        XCTAssertLessThan(green.maxX, blue.minX + 1, "green \(green) is not before blue \(blue)")
        XCTAssertEqual(red.midY, green.midY, accuracy: 1, "red \(red) and green \(green) on two lines")
        XCTAssertEqual(green.midY, blue.midY, accuracy: 1, "green \(green) and blue \(blue) on two lines")
    }

    /// A7.1: a span's letterSpacing and wordSpacing widen its own run only:
    /// 4 points after each of its glyphs, 4 more at its space; its
    /// backgroundColor fills behind its own run only.
    func testA7_1ARunKeepsItsSpacingAndBackground() throws {
        func width(_ child: [String: JSONValue]) throws -> CGFloat {
            var style: [String: JSONValue] = ["color": Self.black, "fontSize": 16]
            style.merge(child) { $1 }
            return try XCTUnwrap(draw([rich([
                "text": "MM", "style": ["color": Self.black, "fontSize": 16],
                "children": [["text": "M M", "style": .object(style)]],
            ])], width: 300, height: 40).bounds(of: Pixels.isInk), "nothing drawn").width
        }
        let plain = try width([:])
        XCTAssertEqual(try width(["letterSpacing": 4]) - plain, 8, accuracy: 1.5,
                       "letterSpacing did not widen the run's glyphs by 4 each")
        XCTAssertEqual(try width(["wordSpacing": 4]) - plain, 4, accuracy: 1.5,
                       "wordSpacing did not widen the run's space by 4")

        let filled = try draw([rich([
            "text": "MMMM", "style": ["color": Self.black],
            "children": [["text": "MMMM", "style": ["color": Self.black, "backgroundColor": "#0000FF"]]],
        ])], width: 300, height: 40)
        let background = try XCTUnwrap(filled.bounds(of: Self.isBlue), "no background behind the child's run")
        let ink = try XCTUnwrap(filled.bounds(of: Pixels.isInk))
        XCTAssertGreaterThan(background.minX, ink.minX + 20, "the background reaches the parent's run: \(background)")
        XCTAssertGreaterThanOrEqual(background.maxX, ink.maxX, "the background stops short of the run: \(background)")
    }

    /// A7.1: a child with a style of its own under an italic parent draws
    /// upright (parseTextStyle always sets fontStyle, BH:103-105); a child
    /// without one inherits the italic.
    func testA7_1AStyledChildUnderAnItalicParentIsUpright() throws {
        func child(parent: JSONValue?, style: JSONValue?) throws -> Pixels {
            var span: [String: JSONValue] = ["text": "IIII"]
            span["style"] = style
            var root: [String: JSONValue] = ["text": "", "children": [.object(span)]]
            root["style"] = parent
            return try draw([rich(.object(root))], width: 200, height: 30)
        }
        let italic: JSONValue = ["fontStyle": "italic", "color": Self.black]
        let styled = try child(parent: italic, style: ["color": Self.black])
        XCTAssertNotNil(styled.bounds(of: Pixels.isInk), "the child is not drawn")
        let upright = try child(parent: nil, style: ["color": Self.black])
        XCTAssertTrue(styled.bytes == upright.bytes, "a styled child under an italic parent is not upright")
        let inherited = try child(parent: italic, style: nil)
        XCTAssertTrue(styled.bytes != inherited.bytes, "a child without a style did not inherit the italic")
    }

    /// A7.1: decoration "none" on a child clears the underline it would
    /// inherit (BH:141); the parent's own run keeps its line. A child's
    /// lineThrough replaces the underline with a line through its glyphs.
    func testA7_1DecorationNoneClearsTheParentsUnderline() throws {
        func underlined(child: JSONValue) throws -> Pixels {
            try draw([rich([
                "text": "MMMM", "style": ["color": "#FF0000", "decoration": "underline"],
                "children": [["text": "MMMM", "style": child]],
            ])], width: 300, height: 40)
        }
        let inherited = try underlined(child: ["color": "#0000FF"])
        let inheritedBlue = try XCTUnwrap(inherited.bounds(of: Self.isBlue), "no blue run")
        let cleared = try underlined(child: ["color": "#0000FF", "decoration": "none"])
        let clearedBlue = try XCTUnwrap(cleared.bounds(of: Self.isBlue), "no blue run")
        let red = try XCTUnwrap(cleared.bounds(of: Pixels.isRed), "no red run")
        XCTAssertGreaterThan(inheritedBlue.maxY, clearedBlue.maxY + 1,
                             "without 'none' the child has no underline: \(inheritedBlue) vs \(clearedBlue)")
        XCTAssertGreaterThan(red.maxY, clearedBlue.maxY + 1, "the parent's run lost its underline: \(red)")

        let struck = try underlined(child: ["color": "#0000FF", "decoration": "lineThrough"])
        let middle = Int(clearedBlue.midY) - 3...Int(clearedBlue.midY) + 1
        func across(_ pixels: Pixels) -> Int {
            middle.map { y in (0..<pixels.width).filter { Self.isBlue(pixels.pixel($0, y)) }.count }.max() ?? 0
        }
        XCTAssertGreaterThan(across(struck), across(cleared) + 10, "the child's lineThrough is not drawn")
        XCTAssertEqual(try XCTUnwrap(struck.bounds(of: Self.isBlue)).maxY, clearedBlue.maxY, accuracy: 1,
                       "the child's lineThrough kept the parent's underline")
    }

    /// A7.1: start aligned (left in left-to-right, right in right-to-left),
    /// wrapping (softWrap true) unless maxLines stops it: maxLines 1 with
    /// ellipsis ends in the dots, without `overflow` it is clipped (whole
    /// glyphs to the end, no dots).
    func testA7_1StartWrapsAndMaxLinesClipsOrEllipsizes() throws {
        func boxed(_ text: String, _ props: [String: JSONValue] = [:], width: CGFloat = 100,
                   direction: LayoutDirection = .leftToRight) throws -> Pixels {
            try draw([
                node("box", "Container", ["width": .double(Double(width))], ["t"]),
                rich(["text": .string(text), "style": ["color": Self.black, "fontSize": 16]], props),
            ], width: width, height: 120, direction: direction)
        }
        XCTAssertLessThanOrEqual(try XCTUnwrap(boxed("Hi", width: 200).bounds(of: Pixels.isInk)).minX, 3,
                                 "not start aligned in left-to-right")
        XCTAssertGreaterThanOrEqual(
            try XCTUnwrap(boxed("Hi", width: 200, direction: .rightToLeft).bounds(of: Pixels.isInk)).maxX, 197,
            "not start aligned in right-to-left")

        let words = "MMMM MMMM MMMM MMMM MMMM"
        let wrapped = try XCTUnwrap(boxed(words).bounds(of: Pixels.isInk))
        XCTAssertGreaterThan(wrapped.height, 40, "the text did not wrap: \(wrapped)")

        let ellipsis = try boxed(words, ["maxLines": 1, "overflow": "ellipsis"])
        let dots = try XCTUnwrap(ellipsis.bounds(of: Pixels.isInk))
        XCTAssertLessThan(dots.height, 20, "more than one line: \(dots)")
        XCTAssertLessThanOrEqual(Self.inkRows(ellipsis, columns: Int(dots.maxX) - 3..<Int(dots.maxX)), 4,
                                 "maxLines 1 with ellipsis does not end in dots")

        let clip = try boxed(words, ["maxLines": 1])
        let cut = try XCTUnwrap(clip.bounds(of: Pixels.isInk))
        XCTAssertLessThan(cut.height, 20, "more than one line: \(cut)")
        XCTAssertGreaterThanOrEqual(Self.inkRows(clip, columns: Int(cut.maxX) - 3..<Int(cut.maxX)), 8,
                                    "maxLines 1 without overflow ends in an ellipsis")
    }

    /// A7.1: no text scaling and no ambient style: a larger Dynamic Type
    /// size, an ambient font and colour draw the same pixels.
    func testA7_1DynamicTypeAndTheAmbientStyleChangeNothing() throws {
        let nodes = [rich(["text": "Hello", "children": [["text": " world", "style": ["fontSize": 18]]]])]
        let plain = try draw(nodes, width: 200, height: 40, background: .black)
        XCTAssertNotNil(plain.bounds(of: Self.isWhite), "nothing drawn")
        let ambient = try draw(nodes, width: 200, height: 40, background: .black) { view in
            AnyView(view.font(.largeTitle).foregroundColor(.red).environment(\.dynamicTypeSize, .accessibility3))
        }
        XCTAssertTrue(plain.bytes == ambient.bytes, "Dynamic Type or the ambient style changed the RichText")
    }

    #if canImport(UIKit)
    /// A7.1: a span bound to the page state `name` redraws when a SetState
    /// changes it: the red run grows from "Ada" to "Margaret Hamilton" where
    /// it was, after the black run, which stays put.
    func testA7_1APageStateSpanRedrawsOnSetState() async throws {
        let model = try Self.model([rich([
            "text": "Hi ", "style": ["color": Self.black],
            "children": [["text": ["type": "state", "key": "name", "scope": "page"], "style": ["color": "#FF0000"]]],
        ], watches: ["name"])], state: [["key": "name", "scope": "page", "initial": "Ada"]])
        let host = Hosted(model: model, root: "t")
        defer { host.window.isHidden = true }
        let before = try host.pixels()
        let ada = try XCTUnwrap(before.bounds(of: Pixels.isRed), "no red run")
        let hi = try XCTUnwrap(before.bounds(of: Pixels.isInk), "no black run")

        let action: JSONValue = ["type": "setState", "scope": "page", "key": "name",
                                 "value": ["type": "static", "value": "Margaret Hamilton"]]
        await model.run(try action.decode(Action.self))
        try await Task.sleep(nanoseconds: 300_000_000)
        let after = try host.pixels()
        let margaret = try XCTUnwrap(after.bounds(of: Pixels.isRed), "no red run after SetState")
        XCTAssertGreaterThan(margaret.width, ada.width + 40, "the state span was not redrawn: \(ada) -> \(margaret)")
        XCTAssertEqual(margaret.minX, ada.minX, accuracy: 1, "the state span moved: \(ada) -> \(margaret)")
        XCTAssertEqual(try XCTUnwrap(after.bounds(of: Pixels.isInk)).minX, hi.minX, accuracy: 1, "the black run moved")
    }

    /// The page in a light 300x60 UIKit window, white behind it, read back
    /// at scale 1.
    @MainActor
    struct Hosted {
        let window: UIWindow

        init(model: OrcaPageModel, root: String) {
            let host = UIHostingController(rootView: NodeView(id: root, model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)
                .ignoresSafeArea())
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
            window.overrideUserInterfaceStyle = .light
            window.rootViewController = host
            window.isHidden = false
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        }

        func pixels() throws -> Pixels {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
                window.layer.render(in: context.cgContext)
            }
            return try Pixels(XCTUnwrap(image.cgImage))
        }
    }
    #endif

    // MARK: pages

    /// A RichText `id` whose root span is `text`, with `props` beside it.
    func rich(_ text: JSONValue, _ props: [String: JSONValue] = [:], id: String = "t",
              watches: [String] = []) -> JSONValue {
        var all = props
        all["text"] = text
        return [
            "id": .string(id), "type": "RichText", "kind": "primitive", "childMode": "none",
            "props": .object(all), "children": [], "watches": .array(watches.map { .string($0) }),
        ]
    }

    func node(_ id: String, _ type: String, _ props: [String: JSONValue], _ children: [String]) -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": "layout", "childMode": "single",
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
        ]
    }

    /// The page of `nodes` (the first is the root), its registry widened by
    /// RichText.
    static func model(_ nodes: [JSONValue], state: [JSONValue] = []) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(state), "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["RichText"])))
    }

    /// The first node drawn by ImageRenderer at scale 1: at its own size, or
    /// in a `width` by `height` box from the top leading corner over
    /// `background` (a render that draws nothing can come back holding the
    /// previous render's pixels). `wrap` puts the ambient around it.
    func draw(_ nodes: [JSONValue], width: CGFloat? = nil, height: CGFloat? = nil,
              background: Color = .white, direction: LayoutDirection = .leftToRight,
              wrap: (AnyView) -> AnyView = { $0 }) throws -> Pixels {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as Pixels?, "no root node")
        }
        var view = AnyView(NodeView(id: root, model: try Self.model(nodes)))
        if let width, let height {
            view = AnyView(view.frame(width: width, height: height, alignment: .topLeading).background(background))
        }
        let renderer = ImageRenderer(content: wrap(view).environment(\.layoutDirection, direction))
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

    static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.g > 60 && Int(p.g) > Int(p.r) + 50 && Int(p.g) > Int(p.b) + 50
    }

    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.b > 60 && Int(p.b) > Int(p.r) + 50 && Int(p.b) > Int(p.g) + 50
    }
}
#endif
