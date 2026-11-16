#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A7.1 lines by range (OQ7 a): a RichText span's own line (an overline; a
/// double, wavy, dotted or dashed line; a decorationColor) is drawn under,
/// or for an overline over, that span's run alone, as Flutter's paragraph
/// paints a decoration per style run. The pages put a blue run with a red
/// line between two black runs: the red stays within the blue run's
/// columns and the black runs' columns hold none. iOS 18 / macOS 15 draw
/// these lines (Text.Layout runs); below them a run keeps SwiftUI's solid
/// underline or line-through in its own colour, which the tests assert
/// there instead. ImageRenderer at scale 1 (macOS and iOS); justify in a
/// UIKit window (iOS).
@MainActor
final class SpanLinesTests: XCTestCase {
    static let black: JSONValue = "#000000"
    static let blue: JSONValue = "#0000FF"
    static let red: JSONValue = "#FF0000"

    /// A7.1 lines: an overline in decorationColor is centred on its run's
    /// top edge, half of it above (SkParagraph centres it there), above the
    /// glyphs, and spans that run alone. The RichText sits 10 points down
    /// so the half above its top is in the picture.
    func testA7_1LinesAnOverlineStraddlesItsOwnRunsTopOnly() throws {
        let top: CGFloat = 10
        let pixels = try draw(between(["decoration": "overline", "decorationColor": Self.red], fontSize: 28),
                              height: 60, top: top)
        guard #available(iOS 18, macOS 15, *) else {
            throw XCTSkip("an overline needs iOS 18 / macOS 15 (Text.Layout runs); below them it is not drawn")
        }
        let (run, line) = try runAndLine(pixels)
        XCTAssertLessThan(line.minY, top, "the overline \(line) has no half above the RichText's top \(top)")
        XCTAssertGreaterThan(line.maxY, top, "the overline \(line) has no half below the RichText's top \(top)")
        XCTAssertLessThan(line.maxY, run.minY, "the overline \(line) is not above the run's glyphs \(run)")
        assertOnItsRunOnly(pixels, run: run, drawn: line)
    }

    /// A7.1 lines: a double underline is two lines of red rows below its
    /// run's glyphs, under that run alone.
    func testA7_1LinesADoubleUnderlineDrawsTwoRowsUnderItsOwnRunOnly() throws {
        let style: [String: JSONValue] = ["decoration": "underline", "decorationStyle": "double",
                                          "decorationColor": Self.red]
        let pixels = try draw(between(style))
        guard #available(iOS 18, macOS 15, *) else {
            return try assertSolidFallback(pixels, plain: draw(between([:])))
        }
        let (run, line) = try runAndLine(pixels)
        XCTAssertGreaterThan(line.minY, run.midY, "the double line \(line) is not under the run's glyphs \(run)")
        let groups = Self.redRowGroups(pixels, columns: Int(run.minX) + 3..<Int(run.maxX) - 3)
        XCTAssertEqual(groups, 2, "not two lines of red under the run: \(line)")
        assertOnItsRunOnly(pixels, run: run, drawn: line)
    }

    /// A7.1 lines: a wavy underline is drawn in decorationColor under its
    /// run alone, and waves: its red is taller than a straight line's.
    func testA7_1LinesAWavyLineInDecorationColorUnderItsOwnRunOnly() throws {
        let wavy: [String: JSONValue] = ["decoration": "underline", "decorationStyle": "wavy",
                                         "decorationColor": Self.red]
        let pixels = try draw(between(wavy, text: "MM", fontSize: 40), width: 320, height: 70)
        guard #available(iOS 18, macOS 15, *) else {
            return try assertSolidFallback(pixels, plain: draw(between([:], text: "MM", fontSize: 40), width: 320,
                                                                height: 70))
        }
        let (run, line) = try runAndLine(pixels)
        let straight = try XCTUnwrap(
            draw(between(["decoration": "underline", "decorationColor": Self.red], text: "MM", fontSize: 40),
                 width: 320, height: 70).bounds(of: Pixels.isRed),
            "a solid underline in decorationColor is not drawn")
        XCTAssertGreaterThanOrEqual(line.height, straight.height + 1,
                                    "the wavy line \(line) is no taller than a straight one \(straight)")
        XCTAssertGreaterThan(line.minY, run.midY, "the wavy line \(line) is not under the run's glyphs \(run)")
        assertOnItsRunOnly(pixels, run: run, drawn: line)
    }

    /// A7.1 lines: decoration "none" on a child clears the line its parent
    /// draws for that child's run alone; the parent's run and a later
    /// sibling (which inherits the parent's style) keep it.
    func testA7_1LinesNoneOnAChildClearsItsParentsLineForItsRunOnly() throws {
        func page(_ child: [String: JSONValue]) -> JSONValue {
            rich([
                "text": "MMM",
                "style": ["color": Self.black, "fontSize": 16, "decoration": "underline",
                          "decorationStyle": "wavy", "decorationColor": Self.red],
                "children": [["text": "MMM", "style": .object(child)], ["text": "MMM"]],
            ])
        }
        let cleared = try draw(page(["color": Self.blue, "decoration": "none"]))
        let blue = try XCTUnwrap(cleared.bounds(of: RichTextTests.isBlue), "no blue run")
        let plain = try draw(rich([
            "text": "MMM", "style": ["color": Self.black, "fontSize": 16],
            "children": [["text": "MMM", "style": ["color": Self.blue]], ["text": "MMM"]],
        ]))
        XCTAssertEqual(blue, plain.bounds(of: RichTextTests.isBlue), "the cleared run has a line of its own colour")
        guard #available(iOS 18, macOS 15, *) else { return }
        let red = try XCTUnwrap(cleared.bounds(of: Pixels.isRed), "the parent's line is not drawn")
        XCTAssertLessThan(red.minX, blue.minX - 5, "the parent's run lost its line: \(red)")
        XCTAssertGreaterThan(red.maxX, blue.maxX + 5, "the later sibling lost the inherited line: \(red)")
        let under = Int(blue.minX) + 2..<Int(blue.maxX) - 2
        let crossing = (0..<cleared.height).contains { y in under.contains { Pixels.isRed(cleared.pixel($0, y)) } }
        XCTAssertFalse(crossing, "the parent's line runs under the child with decoration none")
    }

    #if canImport(UIKit)
    /// A7.1 justify (iOS): a justified RichText of runs fills the width with
    /// every line but the last; the last stays as a start-aligned one ends.
    func testA7_1LinesJustifyFillsEveryLineButTheLast() throws {
        let root: JSONValue = [
            "text": "MM MMM M MMMM ", "style": ["color": Self.black, "fontSize": 16],
            "children": [["text": "MMM MM MMMM M MM MMM", "style": ["fontWeight": "bold"]], ["text": " MM M"]],
        ]
        let justified = try Self.lines(hosted(rich(root, ["textAlign": "justify"])))
        let start = try Self.lines(hosted(rich(root, ["textAlign": "start"])))
        XCTAssertGreaterThanOrEqual(justified.count, 3, "fewer than three lines: \(justified)")
        XCTAssertEqual(justified.count, start.count, "justify wrapped differently: \(justified) vs \(start)")
        for line in justified.dropLast() {
            XCTAssertLessThanOrEqual(line.minX, 2, "a justified line does not start at the edge: \(line)")
            XCTAssertGreaterThanOrEqual(line.maxX, 197, "a justified line does not fill the width: \(line)")
        }
        XCTAssertTrue(start.dropLast().contains { $0.maxX < 190 }, "the words already filled every line: \(start)")
        let last = try XCTUnwrap(justified.last), startLast = try XCTUnwrap(start.last)
        XCTAssertLessThan(last.maxX, 190, "the last line is justified: \(last)")
        XCTAssertEqual(last.maxX, startLast.maxX, accuracy: 1, "the last line is not as a start-aligned one: \(last)")
    }

    /// The RichText in a 200 point Container (so it spans it), in a light
    /// 200x160 UIKit window, white behind it, read back at scale 1: the
    /// justified path is a UIKit label, which ImageRenderer cannot draw.
    func hosted(_ text: JSONValue) throws -> Pixels {
        let model = try RichTextTests.model([
            ["id": "box", "type": "Container", "kind": "layout", "childMode": "single",
             "props": ["width": 200], "children": ["t"], "watches": []],
            text,
        ])
        let host = UIHostingController(rootView: NodeView(id: "box", model: model)
            .frame(width: 200, height: 160, alignment: .topLeading)
            .background(Color.white)
            .ignoresSafeArea())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 160))
        defer { window.isHidden = true }
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }

    /// The ink of each line: the runs of rows holding ink (M's have no
    /// descender, so lines are apart), each as the bounds of its ink.
    static func lines(_ pixels: Pixels) -> [CGRect] {
        var lines: [CGRect] = [], top: Int?
        for y in 0...pixels.height {
            let inked = y < pixels.height && (0..<pixels.width).contains { Pixels.isInk(pixels.pixel($0, y)) }
            if inked, top == nil { top = y }
            if !inked, let first = top {
                if let ink = pixels.rows(first...y - 1).bounds(of: Pixels.isInk) {
                    lines.append(ink.offsetBy(dx: 0, dy: CGFloat(first)))
                }
                top = nil
            }
        }
        return lines
    }
    #endif

    // MARK: helpers

    /// A black run, a blue run with `style` over it, a black run: the root
    /// span and its two children, `text` each at `fontSize`.
    func between(_ style: [String: JSONValue], text: String = "MMM", fontSize: Double = 16) -> JSONValue {
        var own = style
        own["color"] = Self.blue
        return rich([
            "text": .string(text), "style": ["color": Self.black, "fontSize": .double(fontSize)],
            "children": [["text": .string(text), "style": .object(own)], ["text": .string(text)]],
        ])
    }

    /// A RichText `t` whose root span is `text`, with `props` beside it.
    func rich(_ text: JSONValue, _ props: [String: JSONValue] = [:]) -> JSONValue {
        var all = props
        all["text"] = text
        return [
            "id": "t", "type": "RichText", "kind": "primitive", "childMode": "none",
            "props": .object(all), "children": [], "watches": [],
        ]
    }

    /// The RichText drawn by ImageRenderer at scale 1 in a `width` by
    /// `height` box from the top leading corner, `top` points down, white
    /// behind it.
    func draw(_ node: JSONValue, width: CGFloat = 240, height: CGFloat = 40, top: CGFloat = 0) throws -> Pixels {
        let view = NodeView(id: "t", model: try RichTextTests.model([node]))
            .padding(.top, top)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
    }

    /// The blue run's glyphs and the red line's bounds.
    func runAndLine(_ pixels: Pixels) throws -> (run: CGRect, line: CGRect) {
        let run = try XCTUnwrap(pixels.bounds(of: RichTextTests.isBlue), "no blue run")
        let line = try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "no line drawn in decorationColor")
        return (run, line)
    }

    /// The red line spans the blue run and stops at its edges (a glyph's
    /// side bearing either way); the black runs on both sides are drawn.
    func assertOnItsRunOnly(_ pixels: Pixels, run: CGRect, drawn: CGRect, file: StaticString = #filePath,
                            line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(drawn.minX, run.minX - 3, "the line reaches the run before: \(drawn) vs \(run)",
                                    file: file, line: line)
        XCTAssertLessThanOrEqual(drawn.maxX, run.maxX + 3, "the line reaches the run after: \(drawn) vs \(run)",
                                 file: file, line: line)
        XCTAssertGreaterThan(drawn.width, run.width - 6, "the line does not span its run: \(drawn) vs \(run)",
                             file: file, line: line)
        let ink = pixels.bounds(of: Pixels.isInk) ?? .zero
        XCTAssertTrue(ink.minX < run.minX - 5 && ink.maxX > run.maxX + 5,
                      "the black runs beside it are not drawn: \(ink)", file: file, line: line)
    }

    /// Below iOS 18 / macOS 15: the blue run keeps SwiftUI's solid line in
    /// its own colour (blue below its glyphs, which `plain`, the same page
    /// without the line, lacks) and nothing is red.
    func assertSolidFallback(_ pixels: Pixels, plain: Pixels) throws {
        let bare = try XCTUnwrap(plain.bounds(of: RichTextTests.isBlue), "no blue run")
        let lined = try XCTUnwrap(pixels.bounds(of: RichTextTests.isBlue), "no blue run")
        XCTAssertGreaterThan(lined.maxY, bare.maxY, "no solid line in the run's colour below its glyphs")
        XCTAssertNil(pixels.bounds(of: Pixels.isRed), "a line in decorationColor below iOS 18 / macOS 15")
    }

    /// How many runs of consecutive rows hold red within `columns`.
    static func redRowGroups(_ pixels: Pixels, columns: Range<Int>) -> Int {
        let rows = (0..<pixels.height).filter { y in columns.contains { Pixels.isRed(pixels.pixel($0, y)) } }
        return zip(rows, [Int.min] + rows).filter { $0 != $1 + 1 }.count
    }
}
#endif
