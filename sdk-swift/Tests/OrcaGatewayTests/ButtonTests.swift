#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// native-parity S-button: ElevatedButton, OutlinedButton and TextButton keep
/// the platform's look (native-sdk gate 03: iOS idioms) and take the props
/// the server sends on top of it (BB:29-91, 165-245). A plain button is
/// pinned by the counter-home golden. The buttons are drawn through the real
/// views with ImageRenderer at scale 1 and read back from the pixels (the
/// AppBarCardTests helpers); no metric of the system style is assumed, only
/// how a prop moves the drawing. Autofocus needs a window: SwiftUI makes the
/// hosting view the first responder while one of its views holds the focus
/// (iOS only).
@MainActor
final class ButtonTests: XCTestCase {
    let cards = AppBarCardTests()

    // MARK: A1.5 padding

    /// A1.5 and D11: `padding` is the content padding: the button's fill
    /// reaches at least 20 beyond the label on every side (the system's own
    /// insets come on top), and it starts at the button's top left corner,
    /// so the padding is no margin outside it.
    func testA1_5PaddingIsInsideTheButton() throws {
        let pixels = try draw("ElevatedButton", ["backgroundColor": "#0000FF",
                                                 "padding": Self.insets(top: 20, right: 20, bottom: 20, left: 20)])
        let fill = try XCTUnwrap(pixels.bounds(of: AppBarCardTests.isBlue), "button not drawn")
        let label = try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "label not drawn")
        for (side, gap) in [("left", label.minX - fill.minX), ("top", label.minY - fill.minY),
                            ("right", fill.maxX - label.maxX), ("bottom", fill.maxY - label.maxY)] {
            XCTAssertGreaterThanOrEqual(gap, 20 - AppBarCardTests.accuracy, "\(side): \(fill) around \(label)")
        }
        XCTAssertEqual(fill.minX, 0, accuracy: AppBarCardTests.accuracy, "a margin before the button: \(fill)")
        XCTAssertEqual(fill.minY, 0, accuracy: AppBarCardTests.accuracy, "a margin above the button: \(fill)")
    }

    /// A1.5 and D4: the padding is absolute: a left padding of 30 and a right
    /// one of 10 leave 20 more fill left of the label than right of it (the
    /// system's insets are the same on both sides), in either direction.
    func testA1_5PaddingLeftStaysLeftInRightToLeft() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let pixels = try draw("ElevatedButton", ["backgroundColor": "#0000FF",
                                                     "padding": Self.insets(top: 0, right: 10, bottom: 0, left: 30)],
                                  direction: direction)
            let fill = try XCTUnwrap(pixels.bounds(of: AppBarCardTests.isBlue), "button not drawn")
            let label = try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "label not drawn")
            XCTAssertEqual((label.minX - fill.minX) - (fill.maxX - label.maxX), 20,
                           accuracy: AppBarCardTests.accuracy, "\(direction): \(fill) around \(label)")
        }
    }

    // MARK: A1.5 elevation

    /// A1.5 and D11: an ElevatedButton that sends `elevation` 6 draws a dark
    /// shadow just below its fill; without `elevation` (Flutter's default 1
    /// is a Material look, not iOS's), with 0, or disabled (Flutter M3:
    /// elevation 0), there is none.
    func testA1_5ElevationDrawsAShadowBelowTheButton() throws {
        let raised = try draw("ElevatedButton", ["backgroundColor": "#0000FF", "elevation": 6])
        let fill = try XCTUnwrap(raised.bounds(of: AppBarCardTests.isBlue), "button not drawn")
        let (x, y) = (Int(fill.midX), Int(fill.maxY) + 2)
        let below = raised.pixel(x, y)
        XCTAssertGreaterThan(below.a, 10, "no shadow below \(fill): \(below)")
        XCTAssertTrue(below.r < 60 && below.g < 60 && below.b < 60, "shadow not dark: \(below)")

        for props: [String: JSONValue] in [["backgroundColor": "#0000FF"],
                                           ["backgroundColor": "#0000FF", "elevation": 0],
                                           ["backgroundColor": "#0000FF", "elevation": 6, "enabled": false]] {
            let flat = try draw("ElevatedButton", props)
            XCTAssertEqual(flat.pixel(x, y).a, 0, "a shadow with \(props)")
        }
    }

    // MARK: D11 splash and highlight

    /// D11: an enabled button that sends splashColor or highlightColor is
    /// drawn by `OverlayFace`, a copy of its native look: idle, it covers
    /// what the system style covers (the Elevated fill, the Outlined border,
    /// the Text label). The Elevated and Outlined faces also keep the
    /// system's shape: the face and the native button agree on the pixel 2
    /// points in from the top and left edges (filled under a small rounded
    /// corner, empty under a capsule's) and on the one at the middle of the
    /// left edge. Idle, a Text face has no shape of its own, only the label.
    /// A button that sends neither, or a disabled one (Flutter draws no
    /// overlay on it), keeps the system style. On macOS ImageRenderer draws
    /// the AppKit-backed native TextButton as a yellow placeholder
    /// (255, 204, 0) in its frame, so there the face's label is compared with
    /// the native control's frame.
    func testD11AnOverlayFaceKeepsTheNativeLook() throws {
        let cases: [(String, [String: JSONValue], (Pixel) -> Bool, shaped: Bool)] = [
            ("ElevatedButton", ["backgroundColor": "#0000FF"], AppBarCardTests.isBlue, true),
            ("OutlinedButton", ["borderColor": "#0000FF"], AppBarCardTests.isBlue, true),
            ("TextButton", [:], Pixels.isRed, false),
        ]
        for (type, props, matches, shaped) in cases {
            let splashed = props.merging(["splashColor": "#00FF00"]) { $1 }
            XCTAssertNil(OverlayFace(try node(type, props)), "\(type) without an overlay")
            XCTAssertNil(OverlayFace(try node(type, splashed.merging(["enabled": false]) { $1 })), "\(type) disabled")
            XCTAssertNotNil(OverlayFace(try node(type, ["highlightColor": "#00FF00"])), "\(type) with a highlight")
            let (nativePixels, facePixels) = (try draw(type, props), try draw(type, splashed))
            #if os(macOS)
            let drawn: (Pixel) -> Bool = type == "TextButton" ? { $0 == (255, 204, 0, 255) } : matches
            #else
            let drawn = matches
            #endif
            let native = try XCTUnwrap(nativePixels.bounds(of: drawn), "\(type) not drawn")
            let face = try XCTUnwrap(facePixels.bounds(of: matches), "\(type) face not drawn")
            cards.assertRect(face, native)
            guard shaped else { continue }
            for (place, x, y) in [("inside the top left corner", Int(native.minX) + 2, Int(native.minY) + 2),
                                  ("at the middle of the left edge", Int(native.minX), Int(native.midY))] {
                let (n, f) = (nativePixels.pixel(x, y), facePixels.pixel(x, y))
                let apart = [(n.r, f.r), (n.g, f.g), (n.b, f.b), (n.a, f.a)].map { abs(Int($0) - Int($1)) }.max() ?? 0
                XCTAssertLessThanOrEqual(apart, 24, "\(type) \(place) (\(x), \(y)): face \(f), native \(n)")
            }
        }
    }

    /// D11 (Flutter `_applyOverlay`): pressed lays the splash colour over the
    /// button's fill and under its label, hovered the highlight colour, each
    /// standing in for the other when alone; idle, neither.
    func testD11SplashIsThePressedOverlayAndHighlightTheHovered() throws {
        let both = try face(["splashColor": "#00FF00", "highlightColor": "#FFFF00"])
        XCTAssertTrue(AppBarCardTests.isBlue(try both(false, false).pixel(5, 17)), "idle is not the fill")
        let pressed = try both(true, false)
        XCTAssertTrue(AppBarCardTests.isGreen(pressed.pixel(5, 17)), "pressed is not the splash colour")
        XCTAssertTrue(Pixels.isRed(pressed.pixel(32, 15)), "the splash covers the label")
        XCTAssertTrue(AppBarCardTests.isYellow(try both(false, true).pixel(5, 17)), "hovered is not the highlight")

        let splash = try face(["splashColor": "#00FF00"])
        XCTAssertTrue(AppBarCardTests.isGreen(try splash(false, true).pixel(5, 17)), "hovered without a highlight")
    }

    // MARK: A1.11 autofocus

    #if canImport(UIKit)
    /// A1.11: a button with autofocus takes the focus when it appears
    /// (SwiftUI then makes its hosting view the first responder); without
    /// autofocus, or disabled, it does not. Focusable buttons need iOS 17.
    func testA1_11ButtonsWithAutofocusTakeTheFocus() throws {
        guard #available(iOS 17, *) else { throw XCTSkip("SwiftUI buttons are focusable from iOS 17") }
        for type in ["ElevatedButton", "OutlinedButton", "TextButton"] {
            XCTAssertTrue(try focused(type, ["autofocus": true]), "\(type) with autofocus")
            XCTAssertFalse(try focused(type, [:]), "\(type) without autofocus")
        }
        XCTAssertFalse(try focused("ElevatedButton", ["autofocus": true, "enabled": false]), "disabled")
    }

    /// Whether any view in a window holding the button is the first responder.
    func focused(_ type: String, _ props: [String: JSONValue]) throws -> Bool {
        let model = try cards.model([
            AppBarCardTests.node("b", type, kind: "button", props: props, children: ["label"]),
            AppBarCardTests.node("label", "Container", props: ["color": "#FF0000", "width": 40, "height": 20]),
        ])
        let host = UIHostingController(rootView: NodeView(id: "b", model: model))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        func responder(_ view: UIView) -> Bool { view.isFirstResponder || view.subviews.contains(where: responder) }
        defer { window.isHidden = true }
        return responder(window)
    }
    #endif

    // MARK: helpers

    typealias Pixel = (r: UInt8, g: UInt8, b: UInt8, a: UInt8)

    /// A button node of `type` with `props`.
    func node(_ type: String, _ props: [String: JSONValue]) throws -> ResolvedNode {
        try XCTUnwrap(cards.model([AppBarCardTests.node("b", type, kind: "button", props: props)]).resolve("b"))
    }

    /// An ElevatedButton's `OverlayFace` with `props`, filled blue, around a
    /// red 40x20 label, drawn pressed and hovered as asked.
    func face(_ props: [String: JSONValue]) throws -> (Bool, Bool) throws -> Pixels {
        let style = try XCTUnwrap(OverlayFace(try node("ElevatedButton", props)))
        return { [cards] pressed, hovered in
            try cards.render(style.face(Color.red.frame(width: 40, height: 20), pressed: pressed, hovered: hovered)
                .tint(Color(.sRGB, red: 0, green: 0, blue: 1)),
                             width: 100, height: 50, direction: .leftToRight)
        }
    }

    static func insets(top: Double, right: Double, bottom: Double, left: Double) -> JSONValue {
        ["top": .double(top), "right": .double(right), "bottom": .double(bottom), "left": .double(left)]
    }

    /// A button of `type` with `props` whose child is a red 40x20 Container,
    /// at the top left of a 200x100 canvas.
    func draw(_ type: String, _ props: [String: JSONValue],
              direction: LayoutDirection = .leftToRight) throws -> Pixels {
        let model = try cards.model([
            AppBarCardTests.node("b", type, kind: "button", props: props, children: ["label"]),
            AppBarCardTests.node("label", "Container", props: ["color": "#FF0000", "width": 40, "height": 20]),
        ])
        return try cards.render(NodeView(id: "b", model: model), width: 200, height: 100, direction: direction)
    }
}
#endif
