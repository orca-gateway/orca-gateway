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
/// render/17_unsupported_widget_placeholder.json) and variants of it, on a
/// page with the SDK's standard registry (S18 advertises the type). The last
/// case draws the page's node through the widget dispatch.
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

    /// How far, in pixels at scale 2, a drawn left edge may sit from where
    /// it is laid out: the anti-aliased first column.
    static let edge: CGFloat = 1

    /// The title and the reason as the card styles them.
    static let titleText = Text("Google Maps").font(.system(size: 15, weight: .semibold))
        .foregroundColor(Props.color(hex: "#374151"))
    static let reasonText = Text(fixtureReason).font(.system(size: 13)).foregroundColor(Props.color(hex: "#6B7280"))

    /// Fixture 17's node as the engine emits it (`expected[0]`).
    func fixtureNode() throws -> [String: JSONValue] {
        let url = swiftRoot.deletingLastPathComponent()
            .appendingPathComponent("schema/fixtures/render/17_unsupported_widget_placeholder.json")
        let fixture = try JSONValue.decode(Data(contentsOf: url))
        return try XCTUnwrap(fixture["expected"].arrayValue?.first?.objectValue)
    }

    /// A page whose one component is fixture 17's node with `changes` to its
    /// props (nil removes a prop).
    func fixturePage(_ changes: [String: JSONValue?] = [:]) throws -> PageResponse {
        var node = try fixtureNode()
        var props = node["props"]?.objectValue ?? [:]
        for (key, value) in changes { props[key] = value }
        node["props"] = .object(props)
        return try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": [.object(node)],
        ]).decode(PageResponse.self)
    }

    /// The view for fixture 17's node with `changes` to its props, and the
    /// page model it draws with (the standard registry).
    func placeholder(_ changes: [String: JSONValue?] = [:]) throws
        -> (view: UnsupportedWidgetPlaceholderView, model: OrcaPageModel) {
        let model = OrcaPageModel(page: try fixturePage(changes))
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

    /// Where the ink of `text` starts when it is drawn alone at 0 on the
    /// card's fill, in pixels at scale 2: its first glyph's side bearing.
    func bearing(_ text: Text, _ colour: RGB) throws -> CGFloat {
        let pixels = try draw(text.fixedSize().background(Props.color(hex: "#6B7280").opacity(0.06)))
        return try XCTUnwrap(pixels.bounds { near($0, colour, 12) }, "no ink").minX
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
        // The 17-point inset holds only the fill: a line 8 points in on
        // each side (from 2 points in along it: the border's edge is smoothed).
        let rows: [(Int, Int)] = (4..<w - 4).flatMap { (x: Int) -> [(Int, Int)] in [(x, 2 * 8), (x, h - 2 * 8)] }
        let columns: [(Int, Int)] = (2 * 8..<h - 2 * 8).flatMap { (y: Int) -> [(Int, Int)] in
            [(2 * 8, y), (w - 2 * 8, y)]
        }
        let padding: [(Int, Int)] = rows + columns
        XCTAssertNil(firstOff(pixels, padding, Self.fill), "the padding")

        // The first row: the grey icon in its 20-point box at 17 (the
        // 16-point padding plus the 1-point border, which Flutter's Container
        // adds to its padding), an 8-point gap, then the title at 45.
        let row = pixels.rows(2 * 17...2 * 37)
        let iconBox = (2 * 17..<2 * 37)
        XCTAssertTrue(iconBox.contains { x in (0..<row.height).contains { near(row.pixel(x, $0), Self.accent, 12) } },
                      "no grey icon")
        let gap = (2 * 37..<2 * 45).flatMap { x in (0..<row.height).map { (x, $0) } }
        XCTAssertNil(firstOff(row, gap, Self.fill), "the gap")
        let title = try XCTUnwrap(row.bounds { near($0, Self.title, 12) }, "no #374151 title")
        let titleBearing = try bearing(Self.titleText, Self.title)
        XCTAssertEqual(title.minX, 2 * 45 + titleBearing, accuracy: Self.edge, "the title")

        // Below it the grey reason, then the blue link, both at the inset
        // (the link's underline starts where its words are laid out).
        let below = pixels.rows(2 * 40...h - 1)
        let reason = try XCTUnwrap(below.bounds { near($0, Self.accent, 12) }, "no grey reason")
        let link = try XCTUnwrap(below.bounds { near($0, Self.link, 16) }, "no blue link")
        XCTAssertLessThan(reason.maxY, link.minY, "the link is under the reason")
        let reasonBearing = try bearing(Self.reasonText, Self.accent)
        XCTAssertEqual(reason.minX, 2 * 17 + reasonBearing, accuracy: Self.edge, "the reason")
        XCTAssertEqual(link.minX, 2 * 17, accuracy: Self.edge, "the link")
        // Underlined: one blue row runs the width of the words.
        let underline = (Int(link.minY)..<Int(link.maxY)).map { y in
            (Int(link.minX)..<Int(link.maxX)).filter { near(below.pixel($0, y), Self.link, 40) }.count
        }.max() ?? 0
        XCTAssertGreaterThanOrEqual(Double(underline), Double(link.width) * 0.9, "Learn more is not underlined")
    }

    func testC18_4_WithoutAnIconTheTitleStartsAtThePadding() throws {
        let pixels = try draw(try placeholder(["iconName": nil]).view)
        let row = pixels.rows(2 * 17...2 * 37)
        let title = try XCTUnwrap(row.bounds { near($0, Self.title, 12) }, "no #374151 title")
        let titleBearing = try bearing(Self.titleText, Self.title)
        XCTAssertEqual(title.minX, 2 * 17 + titleBearing, accuracy: Self.edge, "the title")
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

    // MARK: on a page

    func testC18_4_APageWithFixture17ResolvesUndegradedAndTheDispatchDrawsThePlaceholder() throws {
        let model = OrcaPageModel(page: try fixturePage())
        XCTAssertTrue(model.renderer.registry === WidgetRegistry.shared, "the standard registry")
        let resolved = try XCTUnwrap(model.resolve("root"))
        XCTAssertEqual(resolved.type, "UnsupportedWidgetPlaceholder", "degraded to FallbackPrompt")

        let dispatched = WidgetView(node: resolved, model: model)
        XCTAssertNotNil(ViewTree.first(UnsupportedWidgetPlaceholderView.self, in: dispatched), "the dispatch skips the card")
        XCTAssertNil(ViewTree.first(FallbackPromptView.self, in: dispatched), "the dispatch draws FallbackPrompt")

        // The page's node draws exactly the card.
        let page = try draw(NodeView(id: "root", model: model))
        let card = try draw(UnsupportedWidgetPlaceholderView(node: resolved, model: model))
        XCTAssertEqual(page.width, card.width)
        XCTAssertEqual(page.height, card.height)
        XCTAssertTrue(page.bytes == card.bytes, "the page's node does not draw the card")
    }
}
#endif
