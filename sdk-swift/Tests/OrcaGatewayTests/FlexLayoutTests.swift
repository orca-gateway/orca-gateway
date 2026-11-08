#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// S11 T3: a Row or Column spaces its children as Flutter's RenderFlex does
/// (the Flutter SDK is the oracle; Kotlin's Flex matches it). Each test
/// draws a page through the real FlexView, its children Containers of one
/// colour each, and reads every child's frame back from the pixels.
@MainActor
final class FlexLayoutTests: XCTestCase {
    /// Positions are whole points at scale 1; this allows SwiftUI's rounding.
    static let accuracy: CGFloat = 0.5

    /// L1: three 20-wide children in a 300-wide Row leave F = 240.
    /// spaceAround gives F/(2n) = 40 at each end and F/n = 80 between.
    func testL1SpaceAroundPutsHalfASpaceAtEachEnd() throws {
        let frames = try draw("Row", ["mainAxisAlignment": "spaceAround"],
                              children: Array(repeating: CGSize(width: 20, height: 10), count: 3),
                              width: 300, height: 20)
        assertStarts(frames.map(\.minX), [40, 140, 240])
        XCTAssertEqual(frames[2].maxX, 300 - 40, accuracy: Self.accuracy)
    }

    /// L2: the Flutter SDK's `_addGaps` puts a SizedBox(gap) between two
    /// children, so three children and a gap of 10 make m = 5 items. In 320
    /// points the free space is F = 320 - 60 - 20 = 240.
    /// spaceEvenly: m + 1 = 6 slots of 40.
    /// spaceAround: F/m = 48 around each item, 24 at each end.
    func testL2AGapIsAnItemSpaceEvenlyAndSpaceAroundSpace() throws {
        let evenly = try draw("Row", ["mainAxisAlignment": "spaceEvenly", "gap": 10],
                              children: Array(repeating: CGSize(width: 20, height: 10), count: 3),
                              width: 320, height: 20)
        // 40 | a | 40 gap 40 | b | 40 gap 40 | c | 40
        assertStarts(evenly.map(\.minX), [40, 150, 260])

        let around = try draw("Column", ["mainAxisAlignment": "spaceAround", "gap": 10],
                              children: Array(repeating: CGSize(width: 10, height: 20), count: 3),
                              width: 20, height: 320)
        // 24 | a | 48 gap 48 | b | 48 gap 48 | c | 24
        assertStarts(around.map(\.minY), [24, 150, 276])
        XCTAssertEqual(around[2].maxY, 320 - 24, accuracy: Self.accuracy)
    }

    /// L2, a gap of 0: Flutter still inserts the (empty) boxes, so they are
    /// still items. Three 20-wide children in 300 points, F = 240, m = 5.
    func testL2AZeroGapStillAddsItsItems() throws {
        let around = try draw("Row", ["mainAxisAlignment": "spaceAround", "gap": 0],
                              children: Array(repeating: CGSize(width: 20, height: 10), count: 3),
                              width: 300, height: 20)
        // 24 | a | 48 . 48 | b | 48 . 48 | c | 24
        assertStarts(around.map(\.minX), [24, 140, 256])

        let evenly = try draw("Row", ["mainAxisAlignment": "spaceEvenly", "gap": 0],
                              children: Array(repeating: CGSize(width: 20, height: 10), count: 3),
                              width: 300, height: 20)
        // 6 slots of 40: 40 | a | 40 . 40 | b | 40 . 40 | c | 40
        assertStarts(evenly.map(\.minX), [40, 140, 240])
    }

    /// L3: a Column's cross-axis `baseline` is `start` (Flutter has no
    /// baselines across a Column): children at the leading edge, at the
    /// trailing one in right-to-left, exactly where `start` puts them.
    func testL3AColumnsBaselineIsStart() throws {
        let children = [CGSize(width: 40, height: 10), CGSize(width: 80, height: 10)]
        let baseline = try draw("Column", ["crossAxisAlignment": "baseline"], children: children,
                                width: 200, height: 100)
        let start = try draw("Column", ["crossAxisAlignment": "start"], children: children,
                             width: 200, height: 100)
        assertStarts(baseline.map(\.minX), [0, 0])
        assertStarts(baseline.map(\.minX), start.map(\.minX))

        let rtlBaseline = try draw("Column", ["crossAxisAlignment": "baseline"], children: children,
                                   width: 200, height: 100, direction: .rightToLeft)
        let rtlStart = try draw("Column", ["crossAxisAlignment": "start"], children: children,
                                width: 200, height: 100, direction: .rightToLeft)
        assertStarts(rtlBaseline.map(\.maxX), [200, 200])
        assertStarts(rtlBaseline.map(\.minX), rtlStart.map(\.minX))
    }

    // MARK: helpers

    static let colours: [(hex: String, rgb: (UInt8, UInt8, UInt8))] = [
        ("#FF0000", (255, 0, 0)), ("#00FF00", (0, 255, 0)), ("#0000FF", (0, 0, 255)),
    ]

    func assertStarts(_ actual: [CGFloat], _ expected: [CGFloat], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "\(actual) vs \(expected)", file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// Draws a `type` node (Row or Column) with `props`, holding one sized
    /// Container per entry of `children`, in a box of `width` by `height`,
    /// and returns each child's frame in that box.
    func draw(_ type: String, _ props: [String: JSONValue], children: [CGSize],
              width: CGFloat, height: CGFloat, direction: LayoutDirection = .leftToRight) throws -> [CGRect] {
        var components: [JSONValue] = [[
            "id": "flex", "type": .string(type), "kind": "layout", "childMode": "multi",
            "props": .object(props), "children": .array(children.indices.map { .string("c\($0)") }), "watches": [],
        ]]
        for (index, size) in children.enumerated() {
            components.append([
                "id": .string("c\(index)"), "type": "Container", "kind": "layout", "childMode": "single",
                "props": ["color": .string(Self.colours[index].hex),
                          "width": .double(Double(size.width)), "height": .double(Double(size.height))],
                "children": [], "watches": [],
            ])
        }
        let model = OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(components),
        ]).decode(PageResponse.self))

        let renderer = ImageRenderer(content: NodeView(id: "flex", model: model)
            .frame(width: width, height: height, alignment: .topLeading)
            .environment(\.layoutDirection, direction))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let pixels = try rgba(image)
        return try children.indices.map { index in
            try XCTUnwrap(bounds(of: Self.colours[index].rgb, in: pixels, width: image.width, height: image.height),
                          "child \(index) not drawn")
        }
    }

    /// The image's pixels, top row first, as sRGB RGBA bytes.
    func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
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
        return pixels
    }

    /// The smallest rectangle holding every opaque pixel of `rgb`.
    func bounds(of rgb: (UInt8, UInt8, UInt8), in pixels: [UInt8], width: Int, height: Int) -> CGRect? {
        func near(_ a: UInt8, _ b: UInt8) -> Bool { abs(Int(a) - Int(b)) < 60 }
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                guard pixels[i + 3] > 200, near(pixels[i], rgb.0), near(pixels[i + 1], rgb.1),
                      near(pixels[i + 2], rgb.2) else { continue }
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
#endif
