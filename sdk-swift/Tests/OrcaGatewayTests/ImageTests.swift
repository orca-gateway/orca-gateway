#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// A1.7 and D10: an Image's fit, its size without width and height, and
/// `repeat`, as Flutter's RenderImage and paintImage (PB:50-97, 422-433).
/// The picture is made in memory and handed to the view in place of the
/// network load; the view is drawn with ImageRenderer at scale 1 into the
/// top left corner of a canvas and read back from the pixels. The pictures
/// are drawn at their own size or smaller, so a red/blue edge blends over at
/// most one pixel.
@MainActor
final class ImageTests: XCTestCase {
    let cards = AppBarCardTests()
    static let edge: CGFloat = 1

    // MARK: A1.7 fits

    /// fitWidth: the picture is as wide as the box and its height follows;
    /// a tall one is cut at the top and the bottom (centred), a wide one
    /// leaves bands above and below.
    func testA1_7FitWidthScalesToTheBoxWidth() throws {
        let tall = try draw(["fit": "fitWidth", "width": 100, "height": 100],
                            picture: Self.picture(width: 200, height: 400, split: .vertical))
        assertRect(try XCTUnwrap(tall.bounds(of: Pixels.isRed), "top half not drawn"),
                   CGRect(x: 0, y: 0, width: 100, height: 50))
        assertRect(try XCTUnwrap(tall.bounds(of: AppBarCardTests.isBlue), "bottom half not drawn"),
                   CGRect(x: 0, y: 50, width: 100, height: 50))

        let wide = try draw(["fit": "fitWidth", "width": 100, "height": 100],
                            picture: Self.picture(width: 400, height: 200, split: .horizontal))
        assertRect(try XCTUnwrap(wide.bounds(of: Pixels.isRed), "left half not drawn"),
                   CGRect(x: 0, y: 25, width: 50, height: 50))
    }

    /// fitHeight: the picture is as tall as the box; a wide one is cut at
    /// the left and the right.
    func testA1_7FitHeightScalesToTheBoxHeight() throws {
        let pixels = try draw(["fit": "fitHeight", "width": 100, "height": 100],
                              picture: Self.picture(width: 400, height: 200, split: .horizontal))
        assertRect(try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "left half not drawn"),
                   CGRect(x: 0, y: 0, width: 50, height: 100))
        assertRect(try XCTUnwrap(pixels.bounds(of: AppBarCardTests.isBlue), "right half not drawn"),
                   CGRect(x: 50, y: 0, width: 50, height: 100))
    }

    /// scaleDown: contain, but never larger than the picture itself.
    func testA1_7ScaleDownNeverEnlarges() throws {
        let small = try draw(["fit": "scaleDown", "width": 100, "height": 100],
                             picture: Self.picture(width: 10, height: 10))
        assertRect(try XCTUnwrap(small.bounds(of: Pixels.isRed), "picture not drawn"),
                   CGRect(x: 45, y: 45, width: 10, height: 10))

        let large = try draw(["fit": "scaleDown", "width": 100, "height": 100],
                             picture: Self.picture(width: 400, height: 200))
        assertRect(try XCTUnwrap(large.bounds(of: Pixels.isRed), "picture not drawn"),
                   CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    /// none: the picture at its own size, placed by `alignment` and cut at
    /// the box. The alignment is absolute, as Flutter's: topLeft stays on
    /// the left of the box in right-to-left (where the box itself sits at
    /// the canvas's right, x 200-300).
    func testA1_7NoneIsThePixelSizeAlignedAndClipped() throws {
        for (direction, box) in [(LayoutDirection.leftToRight, 0), (.rightToLeft, 200)] {
            let small = try draw(["fit": "none", "width": 100, "height": 100, "alignment": "topLeft"],
                                 picture: Self.picture(width: 40, height: 20), direction: direction)
            assertRect(try XCTUnwrap(small.bounds(of: Pixels.isRed), "picture not drawn in \(direction)"),
                       CGRect(x: box, y: 0, width: 40, height: 20))
        }

        let large = try draw(["fit": "none", "width": 100, "height": 100, "alignment": "bottomRight"],
                             picture: Self.picture(width: 200, height: 50))
        assertRect(try XCTUnwrap(large.bounds(of: Pixels.isRed), "picture not drawn"),
                   CGRect(x: 0, y: 50, width: 100, height: 50))
    }

    /// none, a picture twice the box's width (red left half, blue right
    /// half): topLeft shows its red half at the box's top, bottomRight its
    /// blue half at the bottom, in both directions (the box at x 200-300 in
    /// right-to-left).
    func testA1_7NoneOverflowAlignsAbsolutelyInBothDirections() throws {
        let picture = try Self.picture(width: 200, height: 50, split: .horizontal)
        for (direction, box) in [(LayoutDirection.leftToRight, 0), (.rightToLeft, 200)] {
            let topLeft = try draw(["fit": "none", "width": 100, "height": 100, "alignment": "topLeft"],
                                   picture: picture, direction: direction)
            assertRect(try XCTUnwrap(topLeft.bounds(of: Pixels.isRed), "topLeft in \(direction)"),
                       CGRect(x: box, y: 0, width: 100, height: 50))
            XCTAssertNil(topLeft.bounds(of: AppBarCardTests.isBlue), "topLeft in \(direction) shows the blue half")

            let bottomRight = try draw(["fit": "none", "width": 100, "height": 100, "alignment": "bottomRight"],
                                       picture: picture, direction: direction)
            assertRect(try XCTUnwrap(bottomRight.bounds(of: AppBarCardTests.isBlue), "bottomRight in \(direction)"),
                       CGRect(x: box, y: 50, width: 100, height: 50))
            XCTAssertNil(bottomRight.bounds(of: Pixels.isRed), "bottomRight in \(direction) shows the red half")
        }
    }

    // MARK: A1.7 size

    /// With no width and no height the Image is as big as its picture, in
    /// a canvas that would let it grow; a width alone sets the height by the
    /// picture's aspect; a picture wider than the room shrinks to it, aspect
    /// kept (Flutter `constrainSizeAndAttemptToPreserveAspectRatio`).
    func testA1_7WithoutWidthOrHeightTheImageTakesItsPixelSize() throws {
        let natural = try draw([:], picture: Self.picture(width: 30, height: 20))
        assertRect(try XCTUnwrap(natural.bounds(of: Pixels.isRed), "picture not drawn"),
                   CGRect(x: 0, y: 0, width: 30, height: 20))

        let widthOnly = try draw(["width": 60], picture: Self.picture(width: 30, height: 20))
        assertRect(try XCTUnwrap(widthOnly.bounds(of: Pixels.isRed), "picture not drawn"),
                   CGRect(x: 0, y: 0, width: 60, height: 40))

        let tooWide = try draw([:], picture: Self.picture(width: 600, height: 100))
        assertRect(try XCTUnwrap(tooWide.bounds(of: Pixels.isRed), "picture not drawn"),
                   CGRect(x: 0, y: 0, width: 300, height: 50))
    }

    // MARK: A1.7 repeat

    /// repeat: a 10x10 picture (red left half, blue right half) at its own
    /// size, centred in a 40x20 box (x 15-25, y 5-15), then tiled from there
    /// on both axes: x = 5 and x = 15 both start a tile, x = 10 is a tile's
    /// blue half, and the rows above and below the centred tile are filled.
    /// repeatX and repeatY tile one axis only.
    func testA1_7RepeatTilesFromTheAlignedPosition() throws {
        let picture = try Self.picture(width: 10, height: 10, split: .horizontal)
        let both = try draw(["fit": "none", "width": 40, "height": 20, "repeat": "repeat"], picture: picture)
        XCTAssertTrue(Pixels.isRed(both.pixel(5, 10)), "x 5: \(both.pixel(5, 10))")
        XCTAssertTrue(Pixels.isRed(both.pixel(15, 10)), "x 15: \(both.pixel(15, 10))")
        XCTAssertTrue(AppBarCardTests.isBlue(both.pixel(10, 10)), "x 10: \(both.pixel(10, 10))")
        XCTAssertTrue(Pixels.isRed(both.pixel(5, 1)), "above the centred tile: \(both.pixel(5, 1))")
        XCTAssertTrue(AppBarCardTests.isBlue(both.pixel(32, 18)), "below the centred tile: \(both.pixel(32, 18))")

        let across = try draw(["fit": "none", "width": 40, "height": 20, "repeat": "repeatX"], picture: picture)
        XCTAssertTrue(Pixels.isRed(across.pixel(5, 10)), "repeatX x 5: \(across.pixel(5, 10))")
        XCTAssertTrue(AppBarCardTests.isBlue(across.pixel(30, 10)), "repeatX x 30: \(across.pixel(30, 10))")
        XCTAssertEqual(across.pixel(5, 1).a, 0, "repeatX tiles no row above: \(across.pixel(5, 1))")

        let down = try draw(["fit": "none", "width": 40, "height": 20, "repeat": "repeatY"], picture: picture)
        XCTAssertTrue(Pixels.isRed(down.pixel(16, 1)), "repeatY above: \(down.pixel(16, 1))")
        XCTAssertTrue(AppBarCardTests.isBlue(down.pixel(22, 18)), "repeatY below: \(down.pixel(22, 18))")
        XCTAssertEqual(down.pixel(5, 10).a, 0, "repeatY tiles no column beside: \(down.pixel(5, 10))")

        // In right-to-left the box sits at the canvas's right (x 260-300);
        // the tiled column stays on its left.
        let left = try draw(["fit": "none", "width": 40, "height": 20, "repeat": "repeatY", "alignment": "topLeft"],
                            picture: picture, direction: .rightToLeft)
        XCTAssertTrue(Pixels.isRed(left.pixel(262, 18)), "topLeft in right-to-left: \(left.pixel(262, 18))")
        XCTAssertEqual(left.pixel(295, 10).a, 0, "topLeft in right-to-left: \(left.pixel(295, 10))")
    }

    // MARK: helpers

    /// An Image node with `props` holding `picture` (in place of its `src`),
    /// drawn into the top left corner of a 300x200 canvas.
    func draw(_ props: [String: JSONValue], picture: CGImage,
              direction: LayoutDirection = .leftToRight) throws -> Pixels {
        var props = props
        props["src"] = "https://orca.test/picture.png"
        let model = try cards.model([AppBarCardTests.node("img", "Image", kind: "primitive", childMode: "none",
                                                          props: props)])
        let node = try XCTUnwrap(model.resolve("img"))
        return try cards.render(ImageNodeView(node: node, image: Image(decorative: picture, scale: 1)),
                                width: 300, height: 200, direction: direction)
    }

    /// A `width` x `height` picture: all red, or red on its first half and
    /// blue on the other, split across (`horizontal`: left | right) or down
    /// (`vertical`: top over bottom).
    static func picture(width: Int, height: Int, split: Axis? = nil) throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        switch split {
        case .horizontal?:
            context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        case .vertical?:
            // Core Graphics counts up from the bottom row.
            context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        case nil:
            break
        }
        return try XCTUnwrap(context.makeImage())
    }

    func assertRect(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.maxX, expected.maxX), (actual.maxY, expected.maxY)] {
            XCTAssertEqual(a, e, accuracy: Self.edge, "\(actual) vs \(expected)", file: file, line: line)
        }
    }
}
#endif
