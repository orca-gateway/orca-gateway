#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A8.5: Flutter's SnackBar builder (structure_builders.dart:429-465) is a
/// static Container: `backgroundColor` ?? #323232, radius 4, padding 16 x
/// 12, holding a Row of the content (white 14) in an Expanded and, when
/// `actionLabel` is not empty, an 8 gap and the label (#BB86FC 14 w600)
/// whose tap fires onAction. `duration` is never read: no timer, no
/// animation. ImageRenderer pixels at scale 1 (macOS and iOS); Swift cannot
/// inject a tap (TouchTests), so the label's tap runs the view's own action
/// for it, and what takes a touch is found by hit tests over text fields
/// behind, in a hosted window (iOS). The registry is widened by the type
/// (advertised in group 7).
@MainActor
final class SnackBarWidgetTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    /// A8.5: the bar fills the width it is given (its content is
    /// Expanded), on #323232 with corners of 4; the content is drawn white
    /// inside the 16 x 12 padding; no label, no purple.
    func testA8_5TheSnackBarDrawsItsContentWhiteOnDarkGreyPadded16By12() throws {
        let model = try page([snackBar("s", ["content": "Hello there"])])
        for width in [300, 200] as [CGFloat] {
            let pixels = try draw(model, "s", width: width, height: 80)
            let bar = try XCTUnwrap(pixels.bounds(of: Self.isDark), "\(width): no bar")
            XCTAssertEqual(bar.minX, 0, accuracy: Self.accuracy, "\(width): \(bar)")
            XCTAssertEqual(bar.minY, 0, accuracy: Self.accuracy, "\(width): \(bar)")
            XCTAssertEqual(bar.width, width, accuracy: Self.accuracy, "\(width): the bar is not as wide as given")
            XCTAssertTrue((24 + 14...24 + 20).contains(bar.height), "\(width): height \(bar.height)")
            assertColour(pixels.pixel(Int(width) / 2, 3), Self.dark, "\(width): the fill")
            XCTAssertFalse(Self.isDark(pixels.pixel(0, 0)), "\(width): a square corner")

            let ink = try XCTUnwrap(pixels.bounds(of: Self.isWhiteInk), "\(width): no content drawn")
            XCTAssertTrue((16...18).contains(ink.minX), "\(width): the content starts at \(ink.minX)")
            XCTAssertGreaterThanOrEqual(ink.minY, 12, "\(width): inside the top padding")
            XCTAssertLessThanOrEqual(ink.maxY, bar.maxY - 12, "\(width): inside the bottom padding")
            XCTAssertNil(pixels.bounds(of: Self.isPurple), "\(width): a label was drawn")
        }
    }

    /// A8.5: an actionLabel is drawn #BB86FC at the end, inside the 16
    /// padding, 8 past the content's Expanded, which ends before it.
    func testA8_5TheActionLabelIsDrawnPurpleAtTheEndAfterAnEightGap() throws {
        let model = try page([snackBar("s", ["content": "Hi", "actionLabel": "UNDO"])])
        let pixels = try draw(model, "s", width: 300, height: 80)

        let label = try XCTUnwrap(pixels.bounds(of: Self.isPurple), "no label drawn")
        XCTAssertTrue((280...284).contains(label.maxX), "the label ends at \(label.maxX), not at the padding")
        let content = try XCTUnwrap(pixels.bounds(of: Self.isWhiteInk), "no content drawn")
        XCTAssertLessThan(content.maxX, label.minX - 8, "the content runs into the label")
        let bar = try XCTUnwrap(pixels.bounds(of: Self.isDark))
        XCTAssertEqual(label.midY, bar.midY, accuracy: 2, "the label is centred in the row")
    }

    /// A8.5: the label is laid out at its own width (Flutter's Row gives a
    /// non-flex child unbounded room), so a label wider than half the row
    /// stays on one line, whole, and the content's Expanded shrinks to end
    /// 8 before it.
    func testA8_5ALongActionLabelStaysOnOneLineAndTheContentShrinks() throws {
        let model = try page([snackBar("s", ["content": "Your message was archived",
                                             "actionLabel": "RESTORE EVERY MESSAGE"])])
        let pixels = try draw(model, "s", width: 300, height: 120)

        let label = try XCTUnwrap(pixels.bounds(of: Self.isPurple), "no label drawn")
        XCTAssertLessThan(label.height, 20, "the label wrapped: \(label)")
        XCTAssertGreaterThan(label.width, 150, "the label was cut to half the row: \(label)")
        XCTAssertTrue((280...284).contains(label.maxX), "the label ends at \(label.maxX), not at the padding")
        let content = try XCTUnwrap(pixels.bounds(of: Self.isWhiteInk), "no content drawn")
        XCTAssertLessThan(content.maxX, label.minX - 8, "the content runs into the label")
    }

    /// A8.5: Flutter's Text merges its own style over the enclosing
    /// DefaultTextStyle and takes maxLines and overflow from it
    /// (widgets/text.dart:723-728, :789-796); the SnackBar's own TextStyles
    /// set only colour and size (and the label's weight), so a DTS's letter
    /// spacing and its one ellipsised line reach both texts while its colour
    /// (red) and size (30) do not.
    func testA8_5AnEnclosingDefaultTextStyleLayersUnderTheSnackBarsTexts() throws {
        let content = "This message is long enough to take two lines in the bar here"
        let model = try page([
            node("dts", "DefaultTextStyle", ["style": ["letterSpacing": 4, "color": "#FF0000", "fontSize": 30],
                                             "maxLines": 1, "overflow": "ellipsis"], ["s"]),
            snackBar("s", ["content": .string(content), "actionLabel": "UNDO"]),
            snackBar("plain", ["content": .string(content), "actionLabel": "UNDO"]),
        ])
        let layered = try draw(model, "dts", width: 300, height: 120)
        let plain = try draw(model, "plain", width: 300, height: 120)

        let plainContent = try XCTUnwrap(plain.bounds(of: Self.isWhiteInk), "plain: no content")
        XCTAssertGreaterThan(plainContent.height, 24, "plain: the content does not wrap: \(plainContent)")
        let layeredContent = try XCTUnwrap(layered.bounds(of: Self.isWhiteInk), "layered: no white content")
        XCTAssertLessThan(layeredContent.height, 20, "the DTS's maxLines 1 or its size 30 is lost: \(layeredContent)")
        XCTAssertNil(layered.bounds(of: Pixels.isRed), "the DTS's red reached a text")

        let plainLabel = try XCTUnwrap(plain.bounds(of: Self.isPurple), "plain: no label")
        let layeredLabel = try XCTUnwrap(layered.bounds(of: Self.isPurple), "layered: no label")
        XCTAssertGreaterThan(layeredLabel.width, plainLabel.width + 9, "the DTS's letter spacing is lost on the label")
        XCTAssertLessThan(layeredLabel.height, 20, "the DTS's size 30 reached the label")
    }

    /// A8.5: an empty or missing actionLabel draws no label and attaches no
    /// tap; a label does.
    func testA8_5AnEmptyOrMissingActionLabelDrawsNoLabelAndTakesNoTap() throws {
        let model = try page([
            snackBar("none", ["content": "Hi"], onAction: true),
            snackBar("empty", ["content": "Hi", "actionLabel": ""], onAction: true),
            snackBar("label", ["content": "Hi", "actionLabel": "UNDO"], onAction: true),
        ])
        for id in ["none", "empty"] {
            XCTAssertNil(try draw(model, id, width: 300, height: 80).bounds(of: Self.isPurple), "\(id): a label")
            XCTAssertNil(try view(model, id).labelTap, "\(id): a tap is attached")
        }
        XCTAssertNotNil(try view(model, "label").labelTap, "the label takes no tap")
    }

    /// A8.5: a tap on the label fires onAction, once per tap; a label with
    /// no onAction takes the tap and fires nothing.
    func testA8_5TheLabelsTapFiresOnAction() async throws {
        let model = try page([
            snackBar("s", ["content": "Hi", "actionLabel": "UNDO"], onAction: true),
            snackBar("bare", ["content": "Hi", "actionLabel": "UNDO"]),
        ])
        let tap = try XCTUnwrap(try view(model, "s").labelTap, "no tap on the label")
        await tap()?.value
        XCTAssertEqual(fired(model), 1)
        await tap()?.value
        XCTAssertEqual(fired(model), 2)

        let bare = try XCTUnwrap(try view(model, "bare").labelTap, "no tap on the label")
        XCTAssertNil(bare(), "fired with no onAction")
        XCTAssertEqual(fired(model), 2)
    }

    /// A8.5: `duration` changes nothing: the bar with a duration of 1 ms
    /// is drawn exactly as one without, also once that time has passed.
    func testA8_5DurationChangesNothing() throws {
        let model = try page([
            snackBar("timed", ["content": "Hi", "actionLabel": "UNDO", "duration": 1]),
            snackBar("plain", ["content": "Hi", "actionLabel": "UNDO"]),
        ])
        let plain = try draw(model, "plain", width: 300, height: 80)
        XCTAssertNotNil(plain.bounds(of: Self.isDark), "not drawn")
        XCTAssertEqual(try draw(model, "timed", width: 300, height: 80).bytes, plain.bytes, "at once")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(try draw(model, "timed", width: 300, height: 80).bytes, plain.bytes, "after its duration")
    }

    /// A8.5: `backgroundColor` replaces the grey; the content stays white.
    func testA8_5BackgroundColorIsTheBarsOwn() throws {
        let model = try page([snackBar("s", ["content": "Hello", "backgroundColor": "#00FF00"])])
        let pixels = try draw(model, "s", width: 300, height: 80)
        XCTAssertNil(pixels.bounds(of: Self.isDark), "the grey is still drawn")
        assertColour(pixels.pixel(150, 3), (0, 255, 0), "the fill")
        XCTAssertNotNil(pixels.bounds(of: Self.isWhiteInk), "the content is not white")
    }

    #if canImport(UIKit)
    /// A8.5: the label takes a touch (its GestureDetector), and so does the
    /// rest of the bar (the Container's decoration, BoxDecoration.hitTest);
    /// below the bar the field behind takes it. The label is a button to
    /// VoiceOver (GestureDetector's semantics tap), and activating it runs
    /// the label's own action, the one a tap runs: onAction fires once. A
    /// label with no action of its own is activated by a synthesised touch,
    /// which no test can deliver, so this fails without it.
    func testA8_5TheLabelAndTheBarTakeTouches() throws {
        let host = try Host(try page(CheckboxRadioTests().behind(
            snackBar("s", ["content": "Hi", "actionLabel": "UNDO"], onAction: true))))
        defer { host.close() }
        let pixels = try host.pixels()
        let label = try XCTUnwrap(pixels.bounds(of: Self.isPurple), "no label drawn")
        host.assertTaken(CGPoint(x: label.midX, y: label.midY))
        host.assertTaken(CGPoint(x: 40, y: label.midY))
        host.assertPassed(CGPoint(x: 150, y: 100))

        let restore = Self.automation(true)
        defer { _ = Self.automation(restore) }
        host.pump()
        let element = try XCTUnwrap(Self.element(labelled: "UNDO", in: host.window),
                                    "no accessibility element for the label")
        XCTAssertTrue(element.accessibilityTraits.contains(.button), "the label is not a button")
        _ = element.accessibilityActivate()
        host.pump()
        XCTAssertEqual(fired(host.model), 1, "activating the label did not fire onAction once")
    }

    /// Sets the accessibility automation flag (libAccessibility's
    /// `_AXSSetAutomationEnabled`, as KIF turns it on in unit tests): SwiftUI
    /// builds its accessibility elements only for an assistive client.
    /// Returns the value it had.
    static func automation(_ on: Bool) -> Bool {
        guard let handle = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let get = dlsym(handle, "_AXSAutomationEnabled"),
              let set = dlsym(handle, "_AXSSetAutomationEnabled") else { return false }
        let was = unsafeBitCast(get, to: (@convention(c) () -> Int32).self)() != 0
        unsafeBitCast(set, to: (@convention(c) (Int32) -> Void).self)(on ? 1 : 0)
        return was
    }

    /// The first accessibility element labelled `label` under `root`: its
    /// accessibility elements (SwiftUI's), then its subviews, depth first.
    static func element(labelled label: String, in root: NSObject, depth: Int = 0) -> NSObject? {
        guard depth < 60 else { return nil }
        if root.isAccessibilityElement, root.accessibilityLabel == label { return root }
        var children: [NSObject] = (root.accessibilityElements as? [NSObject]) ?? []
        if children.isEmpty {
            let count = root.accessibilityElementCount()
            if count != NSNotFound, count > 0 {
                children = (0..<count).compactMap { root.accessibilityElement(at: $0) as? NSObject }
            }
        }
        if let view = root as? UIView { children += view.subviews }
        for child in children {
            if let found = element(labelled: label, in: child, depth: depth + 1) { return found }
        }
        return nil
    }
    #endif

    // MARK: pages

    /// A page of `nodes` (the first is the root) whose registry draws
    /// BottomSheet, SnackBar and Dialog; page state `onAction`, 0.
    func page(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        try BottomSheetTests().page(nodes)
    }

    /// A SnackBar with `props`; with `onAction`, its onAction counts itself
    /// in the page state `onAction`.
    func snackBar(_ id: String, _ props: [String: JSONValue], onAction: Bool = false) -> JSONValue {
        var node: [String: JSONValue] = [
            "id": .string(id), "type": "SnackBar", "kind": "primitive", "childMode": "none",
            "props": .object(props), "children": [], "watches": [],
        ]
        if onAction {
            node["actions"] = ["onAction": ["type": "setState", "scope": "page", "key": "onAction", "value": [
                "type": "transform", "input": ["type": "state", "key": "onAction", "scope": "page"],
                "by": [["type": "add", "by": ["type": "static", "value": 1]]],
            ]]]
        }
        return .object(node)
    }

    func node(_ id: String, _ type: String, _ props: [String: JSONValue], _ children: [String]) -> JSONValue {
        BottomSheetTests().node(id, type, props, children)
    }

    /// How many times onAction fired.
    func fired(_ model: OrcaPageModel) -> Int {
        model.store.value("onAction").doubleValue.map { Int($0) } ?? -1
    }

    func view(_ model: OrcaPageModel, _ id: String) throws -> SnackBarNodeView {
        SnackBarNodeView(node: try XCTUnwrap(model.resolve(id), "no node \(id)"), model: model)
    }

    // MARK: pixels

    static let dark: (Int, Int, Int) = (0x32, 0x32, 0x32)

    static func isDark(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && (44...56).contains(p.r) && (44...56).contains(p.g) && (44...56).contains(p.b)
    }

    static func isWhiteInk(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.r > 180 && p.g > 180 && p.b > 180
    }

    /// #BB86FC and its anti-aliased edges on the grey.
    static func isPurple(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && Int(p.b) > Int(p.g) + 50 && Int(p.r) > Int(p.g) + 25 && p.b > 140
    }

    /// Node `id` drawn at the top left of a light `width` x `height` blue
    /// picture at scale 1.
    func draw(_ model: OrcaPageModel, _ id: String, width: CGFloat, height: CGFloat) throws -> Pixels {
        try BottomSheetTests().draw(model, id, width: width, height: height)
    }

    func assertColour(_ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (Int, Int, Int),
                      _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        BottomSheetTests().assertColour(actual, expected, message, file: file, line: line)
    }

    #if canImport(UIKit)
    typealias Host = CheckboxRadioTests.Host
    #endif
}
#endif
