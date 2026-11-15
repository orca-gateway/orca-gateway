#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@testable import OrcaGateway

/// C18.4, the look: UnsupportedWidgetPlaceholder drawn as Flutter's
/// `_buildUnsupportedWidgetPlaceholder` (sdk/lib/src/builders/
/// primitive_builders.dart), the grey "known widget that cannot run here"
/// card. The view is driven directly with fixture 17's node (schema/fixtures/
/// render/17_unsupported_widget_placeholder.json) and variants of it; the
/// page's registry knows the type, which the SDK does not advertise yet.
@MainActor
final class UnsupportedWidgetPlaceholderTests: XCTestCase {
    typealias RGB = (r: Int, g: Int, b: Int)

    static let defaultReason = "This widget runs in the compiled mobile app and cannot preview here."
    static let fixtureReason = "Maps render in the compiled mobile app. Open on device to preview."
    static let docsUrl = "https://docs.orcagateway.com/plugins/orca_google_map"

    /// Flutter's colours over a white page: the fill is #6B7280 at 6%, the
    /// border #6B7280 at 35% over that fill; the title is #374151, the reason
    /// #6B7280 like the icon, the link #2563EB.
    static let fill: RGB = (246, 247, 247)
    static let border: RGB = (197, 200, 206)
    static let accent: RGB = (107, 114, 128)
    static let title: RGB = (55, 65, 81)
    static let link: RGB = (37, 99, 235)
    static let white: RGB = (255, 255, 255)

    /// Fixture 17's node as the engine emits it (`expected[0]`).
    func fixtureNode() throws -> [String: JSONValue] {
        let url = swiftRoot.deletingLastPathComponent()
            .appendingPathComponent("schema/fixtures/render/17_unsupported_widget_placeholder.json")
        let fixture = try JSONValue.decode(Data(contentsOf: url))
        return try XCTUnwrap(fixture["expected"].arrayValue?.first?.objectValue)
    }

    /// The view for fixture 17's node with `changes` to its props (nil
    /// removes a prop), and the page model it draws with.
    func placeholder(_ changes: [String: JSONValue?] = [:]) throws
        -> (view: UnsupportedWidgetPlaceholderView, model: OrcaPageModel) {
        var node = try fixtureNode()
        var props = node["props"]?.objectValue ?? [:]
        for (key, value) in changes { props[key] = value }
        node["props"] = .object(props)
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": [.object(node)],
        ]).decode(PageResponse.self)
        let registry = WidgetRegistry(types: Set(GeneratedCapabilities.widgets).union(["UnsupportedWidgetPlaceholder"]))
        let model = OrcaPageModel(page: page, registry: registry)
        let resolved = try XCTUnwrap(model.resolve("root"))
        XCTAssertEqual(resolved.type, "UnsupportedWidgetPlaceholder", "not degraded")
        return (UnsupportedWidgetPlaceholderView(node: resolved, model: model), model)
    }

    /// The action of the view's one button, as SwiftUI's Button holds it.
    func buttonAction(_ view: UnsupportedWidgetPlaceholderView) -> (@MainActor () -> Void)? {
        ViewTree.first((@MainActor () -> Void).self, in: view)
    }

    /// Taps "Learn more": runs the action of the view's one button.
    func tapLearnMore(_ view: UnsupportedWidgetPlaceholderView) throws {
        try XCTUnwrap(buttonAction(view), "no button to tap")()
    }

    /// `view` on a white page at `scale` pixels per point.
    func draw<V: View>(_ view: V, scale: CGFloat = 2) throws -> Pixels {
        let renderer = ImageRenderer(content: view.background(Color.white))
        renderer.scale = scale
        return try Pixels(XCTUnwrap(renderer.cgImage, "draws nothing"))
    }

    func near(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ c: RGB, _ tolerance: Int = 2) -> Bool {
        abs(Int(p.r) - c.r) <= tolerance && abs(Int(p.g) - c.g) <= tolerance && abs(Int(p.b) - c.b) <= tolerance
    }

    func assertNear(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ c: RGB, _ what: String,
                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(near(p, c), "\(what): \(p) is not \(c)", file: file, line: line)
    }

    /// The first of `points` whose pixel is not `colour`, described; nil
    /// when all are.
    func firstOff(_ pixels: Pixels, _ points: [(Int, Int)], _ colour: RGB) -> String? {
        for (x, y) in points where !near(pixels.pixel(x, y), colour) {
            return "\(x), \(y) is \(pixels.pixel(x, y)), not \(colour)"
        }
        return nil
    }

    // MARK: what it draws

    func testC18_4_Fixture17DrawsTheMapIconTheDisplayNameTheReasonAndLearnMore() throws {
        let symbol = IconNames.symbol(for: "map")
        XCTAssertNotEqual(symbol, IconNames.fallback, "\"map\" resolves as the Icon widget resolves it")
        #if canImport(UIKit)
        XCTAssertNotNil(UIImage(systemName: symbol), "no SF Symbol \(symbol)")
        #elseif canImport(AppKit)
        XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), "no SF Symbol \(symbol)")
        #endif

        let (view, _) = try placeholder()
        let drawn = ViewTree.strings(in: view)
        for shown in [symbol, "Google Maps", Self.fixtureReason, "Learn more"] {
            XCTAssertTrue(drawn.contains(shown), "missing \(shown): \(drawn)")
        }
        for hidden in ["OrcaGoogleMap", Self.defaultReason, Self.docsUrl] {
            XCTAssertFalse(drawn.contains(hidden), "draws \(hidden): \(drawn)")
        }
    }

    func testC18_4_WithoutADisplayNameTheTitleIsTheWidgetType() throws {
        for changes: [String: JSONValue?] in [["displayName": nil], ["displayName": ""]] {
            let drawn = ViewTree.strings(in: try placeholder(changes).view)
            XCTAssertTrue(drawn.contains("OrcaGoogleMap"), "\(changes): \(drawn)")
            XCTAssertFalse(drawn.contains("Google Maps"), "\(changes): \(drawn)")
        }
    }

    func testC18_4_WithoutAnIconNameNoIconIsDrawnAndAnUnknownOneIsACircle() throws {
        let (none, _) = try placeholder(["iconName": nil])
        XCTAssertNil(ViewTree.first(Image.self, in: none), "an icon without iconName")
        XCTAssertTrue(ViewTree.strings(in: none).contains("Google Maps"))

        // Flutter's resolveIconData draws Icons.circle for a name it does not know.
        let drawn = ViewTree.strings(in: try placeholder(["iconName": "no_such_icon"]).view)
        XCTAssertTrue(drawn.contains(IconNames.fallback), "\(drawn)")
    }

    func testC18_4_WithoutAReasonTheDefaultTextIsDrawn() throws {
        let drawn = ViewTree.strings(in: try placeholder(["reason": nil]).view)
        XCTAssertTrue(drawn.contains(Self.defaultReason), "\(drawn)")
        XCTAssertFalse(drawn.contains(Self.fixtureReason))
    }

    func testC18_4_WithoutADocsUrlNoLinkIsDrawn() throws {
        for changes: [String: JSONValue?] in [["docsUrl": nil], ["docsUrl": ""]] {
            let (view, _) = try placeholder(changes)
            XCTAssertFalse(ViewTree.strings(in: view).contains("Learn more"), "\(changes)")
            XCTAssertNil(buttonAction(view), "\(changes): a button without a link")
        }
    }

    // MARK: the link

    func testC18_4_AnAllowedDocsUrlOpensOnTap() throws {
        let (view, model) = try placeholder()
        var effects: [ActionEffect] = []
        model.effectHandler = { effects.append($0) }

        try tapLearnMore(view)

        XCTAssertEqual(effects, [ActionEffect("openUrl", ["url": .string(Self.docsUrl)])])
    }

    func testC18_4_ADisallowedDocsUrlDoesNothingOnTap() throws {
        for raw in ["javascript:alert(1)", "file:///etc/hosts", "tel:123"] {
            let (view, model) = try placeholder(["docsUrl": .string(raw)])
            XCTAssertTrue(ViewTree.strings(in: view).contains("Learn more"), "Flutter draws the link for \(raw)")
            var effects: [ActionEffect] = []
            model.effectHandler = { effects.append($0) }

            try tapLearnMore(view)

            XCTAssertEqual(effects, [], raw)
        }
    }

    // MARK: the look

    func testC18_4_TheCardIsFluttersTintedBorderedBoxWithItsColours() throws {
        let pixels = try draw(try placeholder().view)
        let (w, h) = (pixels.width, pixels.height)
        let midY = h / 2

        assertNear(pixels.pixel(0, 0), Self.white, "the rounded corner")
        assertNear(pixels.pixel(0, midY), Self.border, "the left border")
        assertNear(pixels.pixel(w - 1, midY), Self.border, "the right border")
        assertNear(pixels.pixel(w / 2, 0), Self.border, "the top border")
        assertNear(pixels.pixel(w / 2, h - 1), Self.border, "the bottom border")
        // The 16-point padding holds only the fill: a line 8 points in on
        // each side (from 2 points in along it: the border's edge is smoothed).
        let padding = (4..<w - 4).flatMap { [($0, 2 * 8), ($0, h - 2 * 8)] }
            + (2 * 8..<h - 2 * 8).flatMap { [(2 * 8, $0), (w - 2 * 8, $0)] }
        XCTAssertNil(firstOff(pixels, padding, Self.fill), "the padding")

        // The first row: the grey icon in its 20-point box at 16, an
        // 8-point gap, then the title.
        let row = pixels.rows(2 * 16...2 * 36)
        let iconBox = (2 * 16..<2 * 36)
        XCTAssertTrue(iconBox.contains { x in (0..<row.height).contains { near(row.pixel(x, $0), Self.accent, 12) } },
                      "no grey icon")
        let gap = (2 * 36..<2 * 44).flatMap { x in (0..<row.height).map { (x, $0) } }
        XCTAssertNil(firstOff(row, gap, Self.fill), "the gap")
        let title = try XCTUnwrap(row.bounds { near($0, Self.title, 12) }, "no #374151 title")
        XCTAssertGreaterThanOrEqual(title.minX, 2 * 44)
        XCTAssertLessThanOrEqual(title.minX, 2 * 46)

        // Below it the grey reason, then the blue link, both from the padding's edge.
        let below = pixels.rows(2 * 40...h - 1)
        let reason = try XCTUnwrap(below.bounds { near($0, Self.accent, 12) }, "no grey reason")
        let link = try XCTUnwrap(below.bounds { near($0, Self.link, 16) }, "no blue link")
        XCTAssertLessThan(reason.maxY, link.minY, "the link is under the reason")
        for left in [reason.minX, link.minX] {
            XCTAssertGreaterThanOrEqual(left, 2 * 16)
            XCTAssertLessThanOrEqual(left, 2 * 19)
        }
        // Underlined: one blue row runs the width of the words.
        let underline = (Int(link.minY)..<Int(link.maxY)).map { y in
            (Int(link.minX)..<Int(link.maxX)).filter { near(below.pixel($0, y), Self.link, 40) }.count
        }.max() ?? 0
        XCTAssertGreaterThanOrEqual(Double(underline), Double(link.width) * 0.9, "Learn more is not underlined")
    }

    func testC18_4_WithoutAnIconTheTitleStartsAtThePadding() throws {
        let pixels = try draw(try placeholder(["iconName": nil]).view)
        let row = pixels.rows(2 * 16...2 * 36)
        let title = try XCTUnwrap(row.bounds { near($0, Self.title, 12) }, "no #374151 title")
        XCTAssertGreaterThanOrEqual(title.minX, 2 * 16)
        XCTAssertLessThanOrEqual(title.minX, 2 * 18)
    }

    func testC18_4_TheCardHugsItsContentAndFillsAWidthItsParentForces() throws {
        let (view, _) = try placeholder()
        let loose = try draw(view.frame(width: 600, alignment: .topLeading), scale: 1)
        let looseRight = try XCTUnwrap(loose.bounds { near($0, Self.border) }).maxX
        XCTAssertLessThan(looseRight, 560, "a loose parent: the card is as wide as its content")

        let tight = try draw(view.environment(\.orcaTight, [.horizontal]).frame(width: 600, alignment: .topLeading),
                             scale: 1)
        let tightRight = try XCTUnwrap(tight.bounds { near($0, Self.border) }).maxX
        XCTAssertEqual(tightRight, 600, "a stretched Column or a list: the card spans the width")
    }
}
#endif
