#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A7.4: ImageIcon, and an Icon with `src`, as Flutter's `ImageIcon`
/// (widgets/image_icon.dart:91-119): the image in a `size` square (24 by
/// default) at one point per image pixel (a network image at scale 1),
/// fitted scaleDown (shrunk to fit keeping its aspect, never enlarged) and
/// centred, always tinted srcIn with `color` or else the surrounding
/// foreground; while it loads and after a failed load, the empty square, no
/// name glyph. The same cases as Kotlin's ImageIconTest.
///
/// The pictures are made in memory and handed to IconNodeView in place of
/// the load (`image:`), drawn by ImageRenderer at scale 1 on white: `half`
/// is 10x10 pixels, its left half opaque blue and its right half
/// transparent; `wide` is 40x20 opaque blue. A real load (from a file) is
/// checked in a window on iOS. ImageIcon is advertised only in group 7, so
/// the page's registry is widened by it.
@MainActor
final class ImageIconTests: XCTestCase {
    static let magenta: JSONValue = "#FF00FF"

    /// A7.4: the 10x10 image in a 40 point square keeps its 10 points,
    /// centred: its opaque half fills 15 to 20 across and 15 to 25 down,
    /// and around it the square is white. Scaled to the square, its opaque
    /// half would cover 0 to 20 across.
    func testA7_4ASmallImageKeepsItsSizeCentredInTheSquare() throws {
        let pixels = try draw(["size": 40, "color": Self.magenta], picture: Self.half())
        XCTAssertEqual(pixels.width, 40, "not a 40 point square")
        XCTAssertEqual(pixels.height, 40, "not a 40 point square")
        assertRect(try XCTUnwrap(pixels.bounds(of: Self.isMagenta), "nothing drawn"),
                   CGRect(x: 15, y: 15, width: 5, height: 10))
        XCTAssertNil(pixels.bounds(of: Self.isNeither), "ink other than the tint")
    }

    /// A7.4: the 40x20 image in a 20 point square is shrunk to 20x10,
    /// keeping its 2:1, and centred: blank 5 points above and below.
    func testA7_4ABigImageIsShrunkToFitKeepingItsAspectRatio() throws {
        let pixels = try draw(["size": 20, "color": Self.magenta], picture: Self.wide())
        XCTAssertEqual(pixels.width, 20, "not a 20 point square")
        XCTAssertEqual(pixels.height, 20, "not a 20 point square")
        assertRect(try XCTUnwrap(pixels.bounds(of: Self.isMagenta), "nothing drawn"),
                   CGRect(x: 0, y: 5, width: 20, height: 10))
    }

    /// A7.4: `color` replaces the image's own colour where it is opaque
    /// (srcIn); its transparent half stays clear.
    func testA7_4TheTintColoursTheOpaquePixelsOnly() throws {
        let pixels = try draw(["size": 10, "color": "#00FF00"], picture: Self.half())
        for y in [1, 5, 8] {
            XCTAssertTrue(AppBarCardTests.isGreen(pixels.pixel(2, y)), "opaque half, y \(y): \(pixels.pixel(2, y))")
            XCTAssertTrue(Self.isWhite(pixels.pixel(7, y)), "transparent half, y \(y): \(pixels.pixel(7, y))")
        }
    }

    /// A7.4: without `color` the image is tinted with the surrounding
    /// foreground colour, as an Icon is (Flutter's IconTheme colour).
    func testA7_4NoColorTintsWithTheSurroundingForeground() throws {
        let teal = Color(.sRGB, red: 0, green: 128.0 / 255, blue: 128.0 / 255)
        let pixels = try draw(["size": 10], picture: Self.half()) { AnyView($0.foregroundColor(teal)) }
        let p = pixels.pixel(2, 5)
        XCTAssertTrue(p.r < 20 && abs(Int(p.g) - 128) < 12 && abs(Int(p.b) - 128) < 12, "opaque half: \(p)")
        XCTAssertTrue(Self.isWhite(pixels.pixel(7, 5)), "transparent half: \(pixels.pixel(7, 5))")
    }

    /// A7.4: without `size`, a 24 point square, the 10x10 image centred in
    /// it at its own size.
    func testA7_4TheSizeDefaultsToTwentyFour() throws {
        let pixels = try draw(["color": Self.magenta], picture: Self.half())
        XCTAssertEqual(pixels.width, 24, "not a 24 point square")
        XCTAssertEqual(pixels.height, 24, "not a 24 point square")
        assertRect(try XCTUnwrap(pixels.bounds(of: Self.isMagenta), "nothing drawn"),
                   CGRect(x: 7, y: 7, width: 5, height: 10))
    }

    /// A7.4: an ImageIcon whose image is still loading, and an Icon whose
    /// `src` is not a URL at all (""), are each the empty square of their
    /// size: nothing drawn, no name glyph. The red marker below them sits
    /// 60 points down, under two 30 point squares. Without a `src` the same
    /// Icon draws its glyph.
    func testA7_4ALoadingSrcOrOneThatIsNotAURLLeavesTheEmptySquare() throws {
        let marker = Self.node("m", "Container", ["color": "#FF0000", "width": 10, "height": 10])
        let pixels = try drawPage([
            Self.column("r", ["a", "b", "m"]),
            Self.node("a", "ImageIcon", ["src": "https://orca.test/icon.png", "size": 30, "color": Self.magenta]),
            Self.node("b", "Icon", ["src": "", "name": "home", "size": 30, "color": Self.magenta]),
            marker,
        ])
        XCTAssertNil(pixels.bounds(of: Self.isMagenta), "an image or a glyph is drawn")
        assertRect(try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "no marker"),
                   CGRect(x: 10, y: 60, width: 10, height: 10))

        let glyph = try drawPage([
            Self.column("r", ["b", "m"]),
            Self.node("b", "Icon", ["name": "home", "size": 30, "color": Self.magenta]),
            marker,
        ])
        XCTAssertNotNil(glyph.bounds(of: Self.isMagenta), "an Icon without src draws no glyph")
    }

    /// A7.4: an Icon with `src` is the same path: the small image kept at its
    /// size, centred, tinted; its `name` is not drawn.
    func testA7_4AnIconWithSrcDrawsAsImageIcon() throws {
        let image = try draw(["size": 40, "color": Self.magenta], picture: Self.half())
        let icon = try draw(["size": 40, "color": Self.magenta, "name": "home"], type: "Icon", picture: Self.half())
        XCTAssertEqual(icon.width, image.width)
        XCTAssertEqual(icon.height, image.height)
        XCTAssertTrue(icon.bytes == image.bytes, "the Icon with src draws otherwise than the ImageIcon")
    }

    #if canImport(UIKit)
    /// A7.4: a `src` really loaded (a PNG file) is drawn at one point per
    /// image pixel, scaled down only and centred, tinted; one that fails to
    /// load (no such file) leaves its square empty, no name glyph, once its
    /// load has failed. The two side by side in a Row, in RichTextTests'
    /// 300x60 window.
    func testA7_4ALoadedSrcIsDrawnAndAFailedOneLeavesTheSquareEmpty() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ImageIconTests-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("half.png")
        try XCTUnwrap(UIImage(cgImage: Self.half()).pngData()).write(to: file)
        let missing = folder.appendingPathComponent("missing.png")

        let model = try Self.model([
            Self.column("r", ["a", "b"], type: "Row"),
            Self.node("a", "ImageIcon", ["src": .string(file.absoluteString), "size": 40, "color": Self.magenta]),
            Self.node("b", "Icon", ["src": .string(missing.absoluteString), "name": "home", "size": 40,
                                    "color": Self.magenta]),
        ])
        let host = RichTextTests.Hosted(model: model, root: "r")
        defer { host.window.isHidden = true }
        var pixels = try host.pixels()
        let deadline = Date().addingTimeInterval(5)
        while pixels.bounds(of: Self.isMagenta) == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
            pixels = try host.pixels()
        }
        // The loaded image at its 10 points, its opaque half 5 wide, centred
        // across the first 40 point square. The window's insets set where
        // the Row sits down it, so only the height is pinned on that axis.
        let image = try XCTUnwrap(pixels.bounds(of: Self.isMagenta), "the loaded image is not drawn")
        assertRect(image, CGRect(x: 15, y: image.minY, width: 5, height: 10))

        // A load of the missing file fails at once; 0.3 s after it the
        // second square, 40 to 80 across, is still empty: no image, no name
        // glyph.
        do {
            _ = try await URLSession.shared.data(from: missing)
            XCTFail("missing.png loaded")
        } catch {}
        try await Task.sleep(nanoseconds: 300_000_000)
        let failed = try host.pixels()
        let drawn = (40..<80).flatMap { x in (0..<failed.height).map { y in (x, y) } }
            .first { !Self.isWhite(failed.pixel($0.0, $0.1)) }
        XCTAssertNil(drawn.map { "\($0): \(failed.pixel($0.0, $0.1))" }, "the failed square is drawn")
        XCTAssertEqual(failed.bounds(of: Self.isMagenta), image, "the loaded image changed")
    }
    #endif

    // MARK: helpers

    /// A `type` node with `props` drawn by IconNodeView holding `picture` (in
    /// place of loading its `src`), at its own size on white; `wrap` puts the
    /// surroundings around it.
    func draw(_ props: [String: JSONValue], type: String = "ImageIcon", picture: CGImage,
              wrap: (AnyView) -> AnyView = { $0 }) throws -> Pixels {
        var props = props
        props["src"] = "https://orca.test/icon.png"
        let model = try Self.model([Self.node("i", type, props)])
        let node = try XCTUnwrap(model.resolve("i"))
        let view = AnyView(IconNodeView(node: node, image: Image(decorative: picture, scale: 1)))
        let renderer = ImageRenderer(content: wrap(view).background(Color.white))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
    }

    /// The page of `nodes` (the first is the root) in a 100x100 box from the
    /// top left, on white, at scale 1.
    func drawPage(_ nodes: [JSONValue]) throws -> Pixels {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as Pixels?, "no root node")
        }
        let renderer = ImageRenderer(content: NodeView(id: root, model: try Self.model(nodes))
            .frame(width: 100, height: 100, alignment: .topLeading)
            .background(Color.white))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
    }

    /// The page of `nodes` (the first is the root), its registry widened by
    /// ImageIcon.
    static func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["ImageIcon"])))
    }

    static func node(_ id: String, _ type: String, _ props: [String: JSONValue]) -> JSONValue {
        ["id": .string(id), "type": .string(type), "kind": "primitive", "childMode": "none",
         "props": .object(props), "children": [], "watches": []]
    }

    /// A Column, or a Row with `type`, of `children`.
    static func column(_ id: String, _ children: [String], type: String = "Column") -> JSONValue {
        ["id": .string(id), "type": .string(type), "kind": "layout", "childMode": "multi",
         "props": [:], "children": .array(children.map { .string($0) }), "watches": []]
    }

    /// A `width` x `height` picture, opaque blue in its first `opaque`
    /// columns from the left, transparent in the others.
    static func picture(width: Int, height: Int, opaque: Int) throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: opaque, height: height))
        return try XCTUnwrap(context.makeImage())
    }

    static func half() throws -> CGImage { try picture(width: 10, height: 10, opaque: 5) }

    static func wide() throws -> CGImage { try picture(width: 40, height: 20, opaque: 40) }

    static func isMagenta(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.r > 200 && p.b > 200 && p.g < 60
    }

    static func isWhite(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 240 && p.r > 240 && p.g > 240 && p.b > 240
    }

    /// Neither white nor the magenta tint (the picture's own blue, a blend).
    static func isNeither(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        !isWhite(p) && !isMagenta(p)
    }

    func assertRect(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.maxX, expected.maxX), (actual.maxY, expected.maxY)] {
            XCTAssertEqual(a, e, accuracy: 0.5, "\(actual) vs \(expected)", file: file, line: line)
        }
    }
}
#endif
