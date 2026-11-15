#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// native-parity S-text: a Text draws its style, overflow and alignment as
/// Flutter's `Text` does (PB:30-48, BH:96-170, PB:400-410). Each test draws
/// a page through the real TextNodeView with ImageRenderer at scale 1 and
/// reads the result back from the pixels: black text, decorations in red.
@MainActor
final class TextStyleTests: XCTestCase {
    static let black: JSONValue = "#000000"
    static let red: JSONValue = "#FF0000"
    static let wide = "MMMMMMMMMMMMMMMMMMMM"

    /// A1.1: line height 1.5, word spacing 4, an overline and a dashed
    /// decoration are all drawn.
    func testA1_1LineHeightWordSpacingOverlineAndDashedAreDrawn() throws {
        // The line box is height x fontSize: 1.5 x 16 = 24.
        let plain = try draw(text: "Ag", style: ["fontSize": 16])
        let tall = try draw(text: "Ag", style: ["fontSize": 16, "height": 1.5])
        XCTAssertEqual(CGFloat(tall.height), 24, accuracy: 1, "line box \(tall.height), plain \(plain.height)")

        // Each space is 4 points wider.
        let narrow = try draw(text: "a b", style: ["fontSize": 16])
        let spaced = try draw(text: "a b", style: ["fontSize": 16, "wordSpacing": 4])
        XCTAssertEqual(CGFloat(spaced.width - narrow.width), 4, accuracy: 1,
                       "\(narrow.width) -> \(spaced.width)")
        // Without wordSpacing a Text stays the plain Text(String) it was:
        // no AttributedString is built on every body.
        XCTAssertEqual(TextStyleProps(["fontSize": 16]).text("a b"), Text(verbatim: "a b"),
                       "a Text without wordSpacing is built from an AttributedString")
        XCTAssertNotEqual(TextStyleProps(["wordSpacing": 4]).text("a b"), Text(verbatim: "a b"))

        // The fixture's style: a dashed overline in decorationColor at the
        // top of the 24 point line, above the glyphs.
        let over = try draw(text: "MMMMMMMM", style: [
            "fontSize": 16, "height": 1.5, "color": Self.black,
            "decoration": "overline", "decorationStyle": "dashed", "decorationColor": Self.red,
        ])
        let line = try XCTUnwrap(over.bounds(of: Pixels.isRed), "no overline drawn")
        let glyphs = try XCTUnwrap(over.bounds(of: Pixels.isInk))
        XCTAssertLessThan(line.maxY, glyphs.minY, "overline \(line) not above the glyphs \(glyphs)")
        XCTAssertLessThanOrEqual(line.minY, 5, "overline \(line) not at the top of the line")
        XCTAssertGreaterThanOrEqual(over.gaps(in: line), 2, "overline \(line) is not dashed")

        // A dashed underline, below the glyphs, has gaps too.
        let under = try draw(text: "MMMMMMMM", style: [
            "fontSize": 16, "color": Self.black,
            "decoration": "underline", "decorationStyle": "dashed", "decorationColor": Self.red,
        ])
        let underline = try XCTUnwrap(under.bounds(of: Pixels.isRed), "no underline drawn")
        XCTAssertGreaterThan(underline.minY, try XCTUnwrap(under.bounds(of: Pixels.isInk)).minY)
        XCTAssertGreaterThanOrEqual(under.gaps(in: underline), 2, "underline \(underline) is not dashed")
    }

    /// A1.2: one line (softWrap false) of M's in a 100 point box drawn in a
    /// 300 point canvas, so pixels past the box show.
    func testA1_2OverflowModesDrawAsFlutter() throws {
        func oneLine(_ overflow: JSONValue?, style: [String: JSONValue] = [:]) throws -> Pixels {
            var props: [String: JSONValue] = ["softWrap": false]
            props["overflow"] = overflow
            return try draw(text: Self.wide, style: ["fontSize": 16, "color": Self.black].merging(style) { $1 },
                            props: props, box: 100, canvas: CGSize(width: 300, height: 30))
        }

        // clip: cut at the box edge mid-glyph, no ellipsis.
        let clip = try oneLine("clip")
        let clipInk = try XCTUnwrap(clip.bounds(of: Pixels.isInk))
        XCTAssertLessThanOrEqual(clipInk.maxX, 100, "clip painted past the box")
        XCTAssertGreaterThanOrEqual(clipInk.maxX, 97, "clip did not reach the box edge")
        XCTAssertGreaterThanOrEqual(clip.inkHeight(columns: Int(clipInk.maxX) - 4..<Int(clipInk.maxX)), 8,
                                    "clip ends with an ellipsis")

        // Absent: style.overflow, then clip (Flutter's default).
        let absent = try oneLine(nil)
        XCTAssertEqual(absent.bounds(of: Pixels.isInk), clipInk, "overflow absent is not clip")
        let fromStyle = try oneLine(nil, style: ["overflow": "visible"])
        XCTAssertGreaterThan(try XCTUnwrap(fromStyle.bounds(of: Pixels.isInk)).maxX, 110,
                             "style.overflow visible ignored")

        // fade: clipped, the last ellipsis-width fades out.
        let fade = try oneLine("fade")
        XCTAssertLessThanOrEqual(try XCTUnwrap(fade.bounds(of: Pixels.isInk)).maxX, 100, "fade painted past the box")
        XCTAssertGreaterThanOrEqual(fade.maxAlpha(columns: 40..<80), 230, "fade dimmed the middle")
        let edge = fade.maxAlpha(columns: 96..<100)
        XCTAssertTrue((1...160).contains(edge), "fade edge alpha \(edge)")

        // ellipsis: whole glyphs, then the dots on the baseline.
        let ellipsis = try oneLine("ellipsis")
        let dotsInk = try XCTUnwrap(ellipsis.bounds(of: Pixels.isInk))
        XCTAssertLessThanOrEqual(dotsInk.maxX, 100)
        XCTAssertLessThanOrEqual(ellipsis.inkHeight(columns: Int(dotsInk.maxX) - 3..<Int(dotsInk.maxX)), 4,
                                 "ellipsis does not end with dots")

        // visible: the text runs past the box.
        let visible = try oneLine("visible")
        XCTAssertGreaterThan(try XCTUnwrap(visible.bounds(of: Pixels.isInk)).maxX, 110, "visible was cut")

        // maxLines 2, clip: two whole lines, the second ends in glyphs.
        let lines = try draw(text: "MMMM MMMM MMMM MMMM MMMM", style: ["fontSize": 16, "color": Self.black],
                             props: ["maxLines": 2, "overflow": "clip"], box: 100,
                             canvas: CGSize(width: 100, height: 100))
        let linesInk = try XCTUnwrap(lines.bounds(of: Pixels.isInk))
        XCTAssertLessThan(linesInk.maxY, 40, "more than two lines drawn: \(linesInk)")
        let second = lines.rows(Int(linesInk.maxY) - 12...Int(linesInk.maxY))
        let secondInk = try XCTUnwrap(second.bounds(of: Pixels.isInk))
        XCTAssertGreaterThanOrEqual(second.inkHeight(columns: Int(secondInk.maxX) - 3..<Int(secondInk.maxX)), 8,
                                    "maxLines clip ends with an ellipsis")
    }

    /// A1.3: left and right are absolute (they stay put in right-to-left),
    /// start and end follow the direction; justify stretches every line but
    /// the last (iOS: a UIKit label; macOS has no justified SwiftUI Text).
    func testA1_3TextAlignLeftRightAbsoluteAndJustify() throws {
        func ink(_ align: JSONValue, _ direction: LayoutDirection) throws -> CGRect {
            try XCTUnwrap(draw(text: "Hi", style: ["fontSize": 16, "color": Self.black], props: ["textAlign": align],
                               box: 200, canvas: CGSize(width: 200, height: 30), direction: direction)
                .bounds(of: Pixels.isInk))
        }
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            XCTAssertLessThanOrEqual(try ink("left", direction).minX, 3, "left in \(direction)")
            XCTAssertGreaterThanOrEqual(try ink("right", direction).maxX, 197, "right in \(direction)")
        }
        XCTAssertGreaterThanOrEqual(try ink("start", .rightToLeft).maxX, 197, "start in right-to-left")
        XCTAssertLessThanOrEqual(try ink("end", .rightToLeft).minX, 3, "end in right-to-left")

        #if canImport(UIKit)
        // The long word cannot join the first line, which leaves it short.
        let words = "One two three four incomprehensibilities five six seven eight nine ten"
        func firstLine(_ align: JSONValue) throws -> CGRect {
            let pixels = try hosted(text: words, style: ["fontSize": 16, "color": Self.black],
                                    props: ["textAlign": align], box: 200, canvas: CGSize(width: 200, height: 120))
            let top = try XCTUnwrap(pixels.bounds(of: Pixels.isInk)).minY
            return try XCTUnwrap(pixels.rows(Int(top)...Int(top) + 10).bounds(of: Pixels.isInk))
        }
        let left = try firstLine("left")
        let justified = try firstLine("justify")
        XCTAssertGreaterThanOrEqual(justified.maxX, 197, "justify did not stretch the first line: \(justified)")
        XCTAssertLessThan(left.maxX, justified.maxX - 3, "the words already filled the line: \(left)")
        XCTAssertLessThanOrEqual(justified.minX, 2)
        #endif
    }

    /// A1.11 (Text): decorationColor colours the underline, the line-through
    /// and the overline.
    func testA1_11DecorationColorIsDrawn() throws {
        for decoration: JSONValue in ["underline", "lineThrough", "overline"] {
            let pixels = try draw(text: "MMMM", style: [
                "fontSize": 16, "color": Self.black, "decoration": decoration, "decorationColor": Self.red,
            ])
            XCTAssertNotNil(pixels.bounds(of: Pixels.isRed), "\(decoration) not drawn in decorationColor")
        }
    }

    /// D4: `orcaPadding` reads Flutter's EdgeInsets as absolute sides: a
    /// left inset stays on the left in right-to-left.
    func testD4PaddingLeftStaysLeftInRightToLeft() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let renderer = ImageRenderer(content: Color.red.frame(width: 10, height: 10)
                .orcaPadding(["top": 0, "right": 5, "bottom": 0, "left": 20])
                .environment(\.layoutDirection, direction))
            renderer.scale = 1
            let pixels = try Pixels(XCTUnwrap(renderer.cgImage))
            XCTAssertEqual(pixels.width, 35)
            XCTAssertEqual(pixels.bounds(of: Pixels.isRed)?.minX, 20, "in \(direction)")
        }
    }

    // MARK: helpers

    /// Draws a Text with `style` and `props`. With a `box` the Text sits in
    /// a Container that wide (so it spans it, as in a tight box) and the
    /// picture is `canvas`; without one the picture is the Text's own size.
    func draw(text: String, style: [String: JSONValue], props: [String: JSONValue] = [:], box: CGFloat? = nil,
              canvas: CGSize? = nil, direction: LayoutDirection = .leftToRight) throws -> Pixels {
        let (root, model) = try page(text: text, style: style, props: props, box: box)
        let node = NodeView(id: root, model: model).environment(\.layoutDirection, direction)
        let renderer: ImageRenderer<AnyView>
        if let canvas {
            renderer = ImageRenderer(content: AnyView(node.frame(width: canvas.width, height: canvas.height,
                                                                 alignment: .topLeading)))
        } else {
            renderer = ImageRenderer(content: AnyView(node))
        }
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }

    func page(text: String, style: [String: JSONValue], props: [String: JSONValue],
              box: CGFloat?) throws -> (String, OrcaPageModel) {
        var textProps = props
        textProps["data"] = .string(text)
        textProps["style"] = .object(style)
        var components: [JSONValue] = [[
            "id": "t", "type": "Text", "kind": "primitive", "childMode": "none",
            "props": .object(textProps), "children": [], "watches": [],
        ]]
        if let box {
            components.insert([
                "id": "box", "type": "Container", "kind": "layout", "childMode": "single",
                "props": ["width": .double(Double(box))], "children": ["t"], "watches": [],
            ], at: 0)
        }
        let model = OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(components),
        ]).decode(PageResponse.self))
        return (box == nil ? "t" : "box", model)
    }

    #if canImport(UIKit)
    /// The same page in a UIKit window, for views ImageRenderer cannot draw
    /// (a UIKit label). Scale 1, white background.
    func hosted(text: String, style: [String: JSONValue], props: [String: JSONValue], box: CGFloat,
                canvas: CGSize) throws -> Pixels {
        let (root, model) = try page(text: text, style: style, props: props, box: box)
        let host = UIHostingController(rootView: NodeView(id: root, model: model)
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
            .ignoresSafeArea())
        let window = UIWindow(frame: CGRect(origin: .zero, size: canvas))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }
    #endif
}

/// An image's pixels, top row first, as premultiplied sRGB RGBA bytes.
struct Pixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    static func isInk(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 100 && p.r < 90 && p.g < 90 && p.b < 90
    }

    static func isRed(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.r > 60 && Int(p.r) > Int(p.g) + 50 && Int(p.r) > Int(p.b) + 50
    }

    init(_ image: CGImage) throws {
        width = image.width
        height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(drawn)
        bytes = pixels
    }

    private init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let i = (y * width + x) * 4
        return (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3])
    }

    /// Only the rows in `range` (clamped), as an image of their own.
    func rows(_ range: ClosedRange<Int>) -> Pixels {
        let lower = max(range.lowerBound, 0), upper = min(range.upperBound, height - 1)
        guard lower <= upper else { return Pixels(width: width, height: 0, bytes: []) }
        return Pixels(width: width, height: upper - lower + 1,
                      bytes: Array(bytes[(lower * width * 4)..<((upper + 1) * width * 4)]))
    }

    /// The smallest rectangle holding every pixel that `matches`.
    func bounds(of matches: ((r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where matches(pixel(x, y)) {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// How many rows hold ink within `columns`.
    func inkHeight(columns: Range<Int>) -> Int {
        (0..<height).filter { y in
            columns.contains { x in x >= 0 && x < width && pixel(x, y).a > 60 }
        }.count
    }

    /// The highest alpha within `columns`.
    func maxAlpha(columns: Range<Int>) -> Int {
        var best = 0
        for y in 0..<height {
            for x in columns where x >= 0 && x < width { best = max(best, Int(pixel(x, y).a)) }
        }
        return best
    }

    /// Breaks in a red line: on the row of `line` with the most red, the
    /// runs of non-red pixels between its first and last red pixel.
    func gaps(in line: CGRect) -> Int {
        let ys = Int(line.minY)..<Int(line.maxY)
        guard let row = ys.max(by: { a, b in redCount(a) < redCount(b) }) else { return 0 }
        var gaps = 0, inGap = false
        for x in Int(line.minX)..<Int(line.maxX) {
            let red = Self.isRed(pixel(x, row)) && pixel(x, row).a > 90
            if !red && !inGap { gaps += 1 }
            inGap = !red
        }
        return gaps
    }

    private func redCount(_ y: Int) -> Int {
        (0..<width).filter { Self.isRed(pixel($0, y)) }.count
    }
}
#endif
