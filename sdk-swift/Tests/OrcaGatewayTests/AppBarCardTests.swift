#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// native-parity S-bar: AppBar and Card as Flutter's `_buildAppBar` and
/// `_buildCard` draw them (SB:85-160, Material 3 under `Theme(ThemeData())`).
/// The standalone AppBar and the Card are drawn through the real views with
/// ImageRenderer at scale 1 and read back from the pixels (the BoxTests
/// style). The Scaffold's AppBar is the navigation bar, which ImageRenderer
/// cannot draw: those tests push the page onto a NavigationStack in a UIKit
/// window and read the window's pixels (iOS only).
@MainActor
final class AppBarCardTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: A1.9 standalone AppBar

    /// A1.9 and D7: a standalone AppBar is 56 high (Flutter kToolbarHeight);
    /// toolbarHeight still wins.
    func testA1_9AStandaloneAppBarIs56High() throws {
        let plain = try drawBar(["backgroundColor": "#0000FF"])
        assertRect(try XCTUnwrap(plain.bounds(of: Self.isBlue), "bar not drawn"),
                   CGRect(x: 0, y: 0, width: 300, height: 56))
        let tall = try drawBar(["backgroundColor": "#0000FF", "toolbarHeight": 70])
        assertRect(try XCTUnwrap(tall.bounds(of: Self.isBlue), "bar not drawn"),
                   CGRect(x: 0, y: 0, width: 300, height: 70))
    }

    /// A1.9: centerTitle false puts the title at the leading edge, 16 in
    /// (NavigationToolbar.kMiddleSpacing), vertically centred; on the right
    /// in right-to-left. Absent, the title stays centred (Flutter on iOS with
    /// fewer than two actions).
    func testA1_9CenterTitleFalsePutsTheTitleAtTheLeadingEdge() throws {
        let start = try drawBar(["centerTitle": false], title: true)
        assertRect(try XCTUnwrap(start.bounds(of: Pixels.isRed), "title not drawn"),
                   CGRect(x: 16, y: 18, width: 40, height: 20))
        let rtl = try drawBar(["centerTitle": false], title: true, direction: .rightToLeft)
        assertRect(try XCTUnwrap(rtl.bounds(of: Pixels.isRed), "title not drawn"),
                   CGRect(x: 300 - 16 - 40, y: 18, width: 40, height: 20))
        let centred = try drawBar([:], title: true)
        assertRect(try XCTUnwrap(centred.bounds(of: Pixels.isRed), "title not drawn"),
                   CGRect(x: 130, y: 18, width: 40, height: 20))
    }

    /// A1.9: the leading slot is a box `leadingWidth` wide (Flutter default
    /// 56) at the bar's leading edge, as high as the bar, and a start-aligned
    /// title follows 16 after it. The leading Container has no size, so it
    /// fills the box as Flutter's tight constraints make it.
    func testA1_9LeadingWidthSizesTheLeadingSlot() throws {
        let wide = try drawBar(["leadingWidth": 100, "centerTitle": false], title: true, leading: true)
        assertRect(try XCTUnwrap(wide.bounds(of: Self.isGreen), "leading not drawn"),
                   CGRect(x: 0, y: 0, width: 100, height: 56))
        XCTAssertEqual(try XCTUnwrap(wide.bounds(of: Pixels.isRed)).minX, 116, accuracy: Self.accuracy)

        let plain = try drawBar(["centerTitle": false], title: true, leading: true)
        assertRect(try XCTUnwrap(plain.bounds(of: Self.isGreen), "leading not drawn"),
                   CGRect(x: 0, y: 0, width: 56, height: 56))
        XCTAssertEqual(try XCTUnwrap(plain.bounds(of: Pixels.isRed)).minX, 72, accuracy: Self.accuracy)
    }

    /// A1.9: elevation draws a shadow in shadowColor just under the bar,
    /// fading out within `elevation` points. Flutter's M3 AppBar has a
    /// transparent default shadowColor, so elevation alone draws none, and
    /// elevation 0 (the default) draws none.
    func testA1_9ElevationDrawsAShadowInShadowColorUnderTheBar() throws {
        let shadowed = try drawBar(["backgroundColor": "#0000FF", "elevation": 4, "shadowColor": "#FF0000"])
        let edge = shadowed.pixel(150, 56)
        XCTAssertGreaterThan(edge.a, 30, "no shadow under the bar: \(edge)")
        // Premultiplied: a quarter-alpha red is (64, 0, 0, 64).
        XCTAssertTrue(edge.r > 40 && edge.g < 10 && edge.b < 10, "shadow not in shadowColor: \(edge)")
        XCTAssertEqual(shadowed.pixel(150, 62).a, 0, "shadow reaches past elevation")

        let noColour = try drawBar(["backgroundColor": "#0000FF", "elevation": 4])
        XCTAssertEqual(noColour.pixel(150, 56).a, 0, "M3 AppBar shadowColor defaults to transparent")
        let flat = try drawBar(["backgroundColor": "#0000FF", "shadowColor": "#FF0000"])
        XCTAssertEqual(flat.pixel(150, 56).a, 0, "elevation defaults to 0")
    }

    // MARK: A1.11 Card

    /// A1.11 and D8: surfaceTintColor is laid over the card colour with the
    /// M3 opacity for the elevation (ElevationOverlay.applySurfaceTint: .08
    /// at 3, .065 between 1 and 3, .14 above 12); no tint without one.
    func testA1_11CardSurfaceTintIsLaidOverByElevation() throws {
        for (elevation, opacity) in [(3.0, 0.08), (2.0, 0.065), (20.0, 0.14), (0.0, 0.0)] {
            let pixels = try drawCard(["color": "#FFFFFF", "surfaceTintColor": "#0000FF",
                                       "elevation": .double(elevation)],
                                      child: ["width": 100, "height": 60], width: 108, height: 68)
            assertColour(pixels.pixel(54, 34), (255 * (1 - opacity), 255 * (1 - opacity), 255),
                         "elevation \(elevation)")
        }
        let untinted = try drawCard(["color": "#FFFFFF", "elevation": 3],
                                    child: ["width": 100, "height": 60], width: 108, height: 68)
        assertColour(untinted.pixel(54, 34), (255, 255, 255), "no surfaceTintColor")
    }

    /// A1.11: clipBehavior, when sent, clips the child to the card's shape;
    /// absent, a child larger than the card is not clipped. The card is 100
    /// square (its child Container), the red grandchild 300 square.
    func testA1_11CardClipBehaviorClipsTheChildOnlyWhenSent() throws {
        let oversized: [String: JSONValue] = ["width": 100, "height": 100]
        let clipped = try drawCard(["clipBehavior": "antiAlias", "borderRadius": 0], child: oversized,
                                   grandchild: ["color": "#FF0000", "width": 300, "height": 300],
                                   width: 200, height: 200)
        assertRect(try XCTUnwrap(clipped.bounds(of: Pixels.isRed), "child not drawn"),
                   CGRect(x: 4, y: 4, width: 100, height: 100))

        let open = try drawCard(["borderRadius": 0], child: oversized,
                                grandchild: ["color": "#FF0000", "width": 300, "height": 300],
                                width: 200, height: 200)
        assertRect(try XCTUnwrap(open.bounds(of: Pixels.isRed), "child not drawn"),
                   CGRect(x: 4, y: 4, width: 196, height: 196))
    }

    /// A1.11 and D4: a Card's `padding` and `margin` are absolute EdgeInsets:
    /// a left margin of 20 and a left padding of 10 stay on the left in
    /// right-to-left.
    func testA1_11D4CardPaddingAndMarginLeftStayLeftInRightToLeft() throws {
        let pixels = try drawCard(["color": "#0000FF", "elevation": 0, "borderRadius": 0,
                                   "margin": ["top": 0, "right": 0, "bottom": 0, "left": 20],
                                   "padding": ["top": 0, "right": 0, "bottom": 0, "left": 10]],
                                  child: ["color": "#FF0000", "width": 80, "height": 40],
                                  width: 110, height: 40, direction: .rightToLeft)
        assertRect(try XCTUnwrap(pixels.bounds(of: Self.isBlue), "padding not drawn"),
                   CGRect(x: 20, y: 0, width: 10, height: 40))
        assertRect(try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "child not drawn"),
                   CGRect(x: 30, y: 0, width: 80, height: 40))
    }

    // MARK: A1.9 the Scaffold's AppBar in the navigation bar (iOS)

    #if canImport(UIKit)
    /// A1.9: a pushed page shows the back button; automaticallyImplyLeading
    /// false hides it.
    func testA1_9AutomaticallyImplyLeadingFalseHidesTheBackButton() throws {
        let pushed = try hostedScaffold([:])
        XCTAssertNotNil(pushed.bar.bounds(of: Self.isTint), "a pushed page shows a back button")
        let hidden = try hostedScaffold(["automaticallyImplyLeading": false])
        XCTAssertNil(hidden.bar.bounds(of: Self.isTint), "back button still shown")
    }

    /// A1.9: a leading slot replaces the back button instead of sitting next
    /// to it.
    func testA1_9ALeadingSlotReplacesTheBackButton() throws {
        let pixels = try hostedScaffold([:], leading: true)
        XCTAssertNotNil(pixels.bar.bounds(of: Self.isGreen), "leading not drawn")
        XCTAssertNil(pixels.bar.bounds(of: Self.isTint), "back button shown next to the leading slot")
    }

    /// A1.9: in the navigation bar centerTitle false puts the title at the
    /// leading edge (after the back button when there is one); absent, the
    /// title is centred.
    func testA1_9ScaffoldCenterTitleFalsePutsTheTitleAtTheLeadingEdge() throws {
        let centred = try hostedScaffold(["automaticallyImplyLeading": false])
        let middle = try XCTUnwrap(centred.bar.bounds(of: Pixels.isRed), "title not drawn")
        XCTAssertEqual(middle.midX, Self.window.width / 2, accuracy: 1)

        let start = try hostedScaffold(["automaticallyImplyLeading": false, "centerTitle": false])
        let leading = try XCTUnwrap(start.bar.bounds(of: Pixels.isRed), "title not drawn")
        XCTAssertLessThanOrEqual(leading.minX, 24, "title not at the leading edge: \(leading)")

        let afterBack = try hostedScaffold(["centerTitle": false])
        let back = try XCTUnwrap(afterBack.bar.bounds(of: Self.isTint), "no back button")
        let title = try XCTUnwrap(afterBack.bar.bounds(of: Pixels.isRed), "title not drawn")
        XCTAssertGreaterThan(title.minX, back.maxX, "title not after the back button")
        XCTAssertLessThan(title.midX, Self.window.width / 2, "title still centred")
    }

    /// A1.9: in the navigation bar leadingWidth makes the leading slot that
    /// wide: the 20-wide leading is centred in a 100-wide box and a
    /// start-aligned title follows 16 after the box (40 + 20 + 40 + 16).
    func testA1_9ScaffoldLeadingWidthSizesTheLeadingSlot() throws {
        let pixels = try hostedScaffold(["leadingWidth": 100, "centerTitle": false], leading: true)
        let leading = try XCTUnwrap(pixels.bar.bounds(of: Self.isGreen), "leading not drawn")
        let title = try XCTUnwrap(pixels.bar.bounds(of: Pixels.isRed), "title not drawn")
        XCTAssertEqual(title.minX - leading.minX, 116 - 40, accuracy: 1, "\(leading) then \(title)")
    }

    /// A1.9: elevation with a shadowColor draws the shadow strip under the
    /// navigation bar, over the top of the body.
    func testA1_9ScaffoldElevationDrawsAShadowUnderTheBar() throws {
        let shadowed = try hostedScaffold(["elevation": 4, "shadowColor": "#FF0000"])
        let below = shadowed.pixels.pixel(Int(Self.window.width / 2), Int(shadowed.barRect.maxY))
        XCTAssertGreaterThan(Int(below.r), Int(below.g) + 30, "no shadow under the bar: \(below)")

        let flat = try hostedScaffold([:])
        let plain = flat.pixels.pixel(Int(Self.window.width / 2), Int(flat.barRect.maxY))
        XCTAssertLessThan(abs(Int(plain.r) - Int(plain.g)), 10, "shadow without elevation: \(plain)")
    }
    #endif

    // MARK: helpers

    static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.g > 200 && p.r < 60 && p.b < 60
    }

    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.b > 200 && p.r < 60 && p.g < 60
    }

    static func isYellow(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.r > 230 && p.g > 230 && p.b < 40
    }

    /// The system tint the back button is drawn in (iOS blue, #007AFF).
    static func isTint(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.b > 180 && p.r < 100 && p.g > 60 && p.g < 180
    }

    func assertRect(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.maxX, expected.maxX), (actual.maxY, expected.maxY)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    func assertColour(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (Double, Double, Double),
                      _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(p.r, expected.0), (p.g, expected.1), (p.b, expected.2)] {
            XCTAssertEqual(Double(a), e, accuracy: 2, "\(message): \(p)", file: file, line: line)
        }
    }

    static func node(_ id: String, _ type: String, kind: String = "layout", childMode: String = "single",
                     props: [String: JSONValue], children: [JSONValue] = []) -> JSONValue {
        ["id": .string(id), "type": .string(type), "kind": .string(kind), "childMode": .string(childMode),
         "props": .object(props), "children": .array(children), "watches": []]
    }

    func model(_ components: [JSONValue]) throws -> OrcaPageModel {
        OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(components),
        ]).decode(PageResponse.self))
    }

    /// A standalone AppBar with `props`, a red 40x20 Container as its title
    /// and a green Container with no size as its leading slot, drawn at the
    /// top of a `width` by `height` canvas.
    func drawBar(_ props: [String: JSONValue], title: Bool = false, leading: Bool = false,
                 width: CGFloat = 300, height: CGFloat = 100,
                 direction: LayoutDirection = .leftToRight) throws -> Pixels {
        var barProps = props
        var slots: [JSONValue] = []
        var components: [JSONValue] = []
        if title {
            barProps["title"] = "title"
            slots.append("title")
            components.append(Self.node("title", "Container", props: ["color": "#FF0000", "width": 40, "height": 20]))
        }
        if leading {
            barProps["leading"] = "lead"
            slots.append("lead")
            components.append(Self.node("lead", "Container", props: ["color": "#00FF00"]))
        }
        components.insert(Self.node("bar", "AppBar", kind: "structure", childMode: "none", props: barProps,
                                    children: slots), at: 0)
        return try render(NodeView(id: "bar", model: model(components)), width: width, height: height,
                          direction: direction)
    }

    /// A Card with `props` holding a Container with `child` props (and that
    /// one a Container with `grandchild` props), in a `width` by `height`
    /// canvas.
    func drawCard(_ props: [String: JSONValue], child: [String: JSONValue],
                  grandchild: [String: JSONValue]? = nil, width: CGFloat, height: CGFloat,
                  direction: LayoutDirection = .leftToRight) throws -> Pixels {
        var components = [
            Self.node("card", "Card", props: props, children: ["child"]),
            Self.node("child", "Container", props: child, children: grandchild == nil ? [] : ["grandchild"]),
        ]
        if let grandchild {
            components.append(Self.node("grandchild", "Container", props: grandchild))
        }
        return try render(NodeView(id: "card", model: model(components)), width: width, height: height,
                          direction: direction)
    }

    func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, direction: LayoutDirection) throws -> Pixels {
        let renderer = ImageRenderer(content: view
            .frame(width: width, height: height, alignment: .topLeading)
            .environment(\.layoutDirection, direction))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }

    #if canImport(UIKit)
    static let window = CGSize(width: 390, height: 300)

    struct Hosted {
        let pixels: Pixels
        /// The navigation bar: the rows of its yellow background.
        let barRect: CGRect
        var bar: Pixels { pixels.rows(Int(barRect.minY)...Int(barRect.maxY) - 1) }
    }

    /// A Scaffold whose AppBar (`props`, a yellow background, a red 40x20
    /// title and with `leading` a green 20x20 leading slot) is the bar of a
    /// page pushed onto a NavigationStack, in a UIKit window at scale 1.
    func hostedScaffold(_ props: [String: JSONValue], leading: Bool = false) throws -> Hosted {
        var barProps = props
        barProps["backgroundColor"] = "#FFFF00"
        barProps["title"] = "title"
        var slots: [JSONValue] = ["title"]
        if leading {
            barProps["leading"] = "lead"
            slots.append("lead")
        }
        let model = try model([
            Self.node("s", "Scaffold", kind: "structure", childMode: "none",
                      props: ["appBar": "bar", "body": "body", "backgroundColor": "#FFFFFF"],
                      children: ["bar", "body"]),
            Self.node("bar", "AppBar", kind: "structure", childMode: "none", props: barProps, children: slots),
            Self.node("title", "Container", props: ["color": "#FF0000", "width": 40, "height": 20]),
            Self.node("lead", "Container", props: ["color": "#00FF00", "width": 20, "height": 20]),
            Self.node("body", "Container", props: ["color": "#FFFFFF"]),
        ])
        let root = NavigationStack(path: .constant([1])) {
            Color.white.navigationDestination(for: Int.self) { _ in NodeView(id: "s", model: model) }
        }
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.window))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: Self.window, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        let pixels = try Pixels(XCTUnwrap(image.cgImage))
        let bar = try XCTUnwrap(pixels.bounds(of: Self.isYellow), "navigation bar not drawn")
        return Hosted(pixels: pixels, barRect: bar)
    }
    #endif
}
#endif
