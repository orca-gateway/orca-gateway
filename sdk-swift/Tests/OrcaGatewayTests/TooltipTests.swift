#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A8.3 (design D7, q2 a): Flutter's Tooltip as MUI draws it under the light
/// ThemeData() (layout_builders.dart:583-586; material tooltip.dart;
/// widgets/raw_tooltip.dart). A 500 ms long press shows a bubble placed by
/// `TooltipPlacement` around the child's centre in the overlay less the
/// keyboard: grey[700] at 0.9, corners 4, white 14, padded 16 x 4, at least
/// 32 tall. It fades in over 150 ms and out over 75 through fastOutSlowIn,
/// stays while held, and goes 1.5 s after release or at once at any other
/// touch. It takes no touch. An empty message draws the child alone.
/// VoiceOver reads the child's label, then the message. IconButton's and the
/// FAB's `tooltip` show the same bubble (button_builders.dart:158-159;
/// floating_action_button.dart:623).
///
/// Swift cannot inject a long press or a touch. The tests run what the
/// gestures and the window's touch watch run (`OrcaTooltips.press`,
/// `touchDown`, `touchUp`) on the test's clock, and read the bubble's pixels
/// in a hosted window (iOS). The look and the timing run on macOS too. The
/// registry is widened by Tooltip (advertised in group 7).
@MainActor
final class TooltipTests: XCTestCase {
    static let accuracy: CGFloat = 1
    private var now: Double = 1_000_000

    private func manual(_ tooltips: OrcaTooltips) {
        tooltips.clock = { [unowned self] in self.now }
        tooltips.sleep = nil
    }

    private func pass(_ ms: Double, _ tooltips: OrcaTooltips) {
        now += ms
        tooltips.tick()
    }

    private func opacity(_ tooltips: OrcaTooltips) -> Double? {
        tooltips.bubbles.first.map { $0.fade.opacity(at: now) }
    }

    private let key = OrcaTooltips.Key(model: ObjectIdentifier(TooltipTests.self), node: "t")
    private let child = CGRect(x: 100, y: 100, width: 40, height: 40)
    private let inside = CGPoint(x: 120, y: 120)
    private let outside = CGPoint(x: 10, y: 10)

    /// `tooltips` with `key`'s child at `child` and a bubble pressed on it.
    private func pressed(_ tooltips: OrcaTooltips, touching: Bool) {
        tooltips.place(key, at: child, by: UUID())
        if touching { tooltips.touchDown(at: inside) }
        tooltips.press(key, message: "Hi", direction: .leftToRight)
    }

    // MARK: - Timing (macOS and iOS)

    /// A8.3: held, the bubble fades in over 150 ms through fastOutSlowIn
    /// (raw_tooltip.dart:27-31; curves.dart:1865) and stays as long as the
    /// finger is down. Once it lifts the bubble stays 1.5 s (tooltip.dart:416,
    /// raw_tooltip.dart:762-767), then fades out over 75 ms through the same
    /// curve and is gone.
    func testA8_3_HeldTheBubbleStaysAndGoes1500msAfterReleaseFadingIn150AndOut75() throws {
        let tooltips = OrcaTooltips()
        manual(tooltips)
        pressed(tooltips, touching: true)
        XCTAssertEqual(opacity(tooltips), 0, "in at once")
        pass(75, tooltips)
        XCTAssertEqual(try XCTUnwrap(opacity(tooltips)), Curves.apply("fastOutSlowIn", 0.5), accuracy: 1e-9)
        pass(75, tooltips)
        XCTAssertEqual(opacity(tooltips), 1, "150 ms in")
        pass(10_000, tooltips)
        XCTAssertEqual(opacity(tooltips), 1, "gone while held")

        tooltips.touchUp()
        pass(1499, tooltips)
        XCTAssertEqual(opacity(tooltips), 1, "gone before 1.5 s")
        pass(1, tooltips)
        pass(37.5, tooltips)
        XCTAssertEqual(try XCTUnwrap(opacity(tooltips), "gone at once"), Curves.apply("fastOutSlowIn", 0.5),
                       accuracy: 1e-9, "37.5 ms out")
        pass(37.5, tooltips)
        XCTAssertTrue(tooltips.bubbles.isEmpty, "kept once faded out")
    }

    /// A8.3: where no touch is seen (macOS, no window watch) the 1.5 s run
    /// from the long press.
    func testA8_3_WithNoTouchSeenTheBubbleGoes1500msAfterItShows() {
        let tooltips = OrcaTooltips()
        manual(tooltips)
        pressed(tooltips, touching: false)
        pass(1499, tooltips)
        XCTAssertEqual(opacity(tooltips), 1)
        pass(1, tooltips)
        pass(75, tooltips)
        XCTAssertTrue(tooltips.bubbles.isEmpty)
    }

    /// A8.3: any other touch going down starts the fade out at once
    /// (RawTooltip's global pointer route, raw_tooltip.dart:706-733). A touch
    /// on the bubble's own child is its recognizer's: lifted before a long
    /// press it hides the bubble then (onLongPressCancel); a new long press
    /// keeps it, held again.
    func testA8_3_AnyOtherTouchHidesItAtOnceATapOnItsChildAsItLifts() throws {
        let tooltips = OrcaTooltips()
        manual(tooltips)
        pressed(tooltips, touching: true)
        tooltips.touchUp()
        pass(150, tooltips)
        tooltips.touchDown(at: outside)
        pass(37.5, tooltips)
        XCTAssertEqual(try XCTUnwrap(opacity(tooltips), "gone at once"), Curves.apply("fastOutSlowIn", 0.5),
                       accuracy: 1e-9, "another touch: not fading out")
        pass(37.5, tooltips)
        XCTAssertTrue(tooltips.bubbles.isEmpty, "another touch: kept")
        tooltips.touchUp()

        pressed(tooltips, touching: true)
        tooltips.touchUp()
        pass(150, tooltips)
        tooltips.touchDown(at: inside)
        pass(100, tooltips)
        XCTAssertEqual(opacity(tooltips), 1, "a touch on its child hid it as it went down")
        tooltips.touchUp()
        pass(75, tooltips)
        XCTAssertTrue(tooltips.bubbles.isEmpty, "a tap on its child kept it")

        pressed(tooltips, touching: true)
        tooltips.touchUp()
        pass(150, tooltips)
        tooltips.touchDown(at: inside)
        pass(500, tooltips)
        tooltips.press(key, message: "Hi", direction: .leftToRight)
        pass(3000, tooltips)
        XCTAssertEqual(opacity(tooltips), 1, "a new long press on its child did not hold it")
        tooltips.touchUp()
        pass(1499, tooltips)
        XCTAssertEqual(opacity(tooltips), 1)
        pass(76, tooltips)
        XCTAssertTrue(tooltips.bubbles.isEmpty)
    }

    /// A8.3: Flutter's long-press feedback (Feedback.forLongPress: on iOS the
    /// click sound and a heavy impact, feedback.dart:136-146) comes as a
    /// bubble appears, not again while it shows (raw_tooltip.dart:752-759).
    /// Another tooltip's long press sends the first away and feels again.
    func testA8_3_TheLongPressFeedbackComesAsABubbleAppears() {
        var felt = 0
        let saved = OrcaTooltips.feedback
        OrcaTooltips.feedback = { felt += 1 }
        defer { OrcaTooltips.feedback = saved }
        let tooltips = OrcaTooltips()
        manual(tooltips)
        pressed(tooltips, touching: true)
        XCTAssertEqual(felt, 1)
        pass(150, tooltips)
        tooltips.press(key, message: "Hi", direction: .leftToRight)
        XCTAssertEqual(felt, 1, "felt again while it shows")

        let other = OrcaTooltips.Key(model: key.model, node: "u")
        tooltips.place(other, at: CGRect(x: 0, y: 300, width: 40, height: 40), by: UUID())
        tooltips.press(other, message: "There", direction: .leftToRight)
        XCTAssertEqual(felt, 2)
        pass(75, tooltips)
        XCTAssertEqual(tooltips.bubbles.map(\.key), [other], "the first bubble stayed")
    }

    // MARK: - The look (macOS and iOS)

    /// A8.3: the bubble as MUI draws it on a phone under the light
    /// ThemeData() (tooltip.dart:450-465, :503-534, _TooltipBox :595-627):
    /// grey[700] at 0.9 (over black, 0x61 x 0.9 = 87), corners 4, the message
    /// white 14 from 16 in to 16 before the end, at least 32 tall, bodyMedium's
    /// line height 1.43 (20.02 a line: two lines are 48 tall with the
    /// padding). The text has every Text's line box (TextNodeView's
    /// `height`), whose SwiftUI line runs up to about a point over Flutter's:
    /// two lines land within 2 of 48 (as SnackbarBarTests' two lines of 68).
    func testA8_3_TheBubbleIsGrey700At09Radius4White14Padded16By4AtLeast32Tall() throws {
        let pixels = try drawBubble("Hello")
        let bubble = try XCTUnwrap(pixels.bounds(of: Self.isBubbleOnBlack), "no bubble drawn")
        XCTAssertEqual(bubble.minX, 10, accuracy: Self.accuracy)
        XCTAssertEqual(bubble.minY, 10, accuracy: Self.accuracy)
        XCTAssertEqual(bubble.height, 32, accuracy: Self.accuracy, "one line: the minimum height")
        assertColour(pixels.pixel(Int(bubble.minX) + 6, Int(bubble.midY)), (87, 87, 87), "the fill")
        XCTAssertFalse(Self.isBubbleOnBlack(pixels.pixel(10, 10)), "a square corner")
        XCTAssertTrue(Self.isBubbleOnBlack(pixels.pixel(14, 10)), "the top edge 4 in")

        let ink = try XCTUnwrap(pixels.rows(Int(bubble.minY)...Int(bubble.maxY) - 1).bounds(of: Self.isWhiteInk),
                                "no white message")
        XCTAssertEqual(ink.minX, bubble.minX + 16, accuracy: 2, "the message starts 16 in")
        XCTAssertEqual(bubble.maxX - ink.maxX, 16, accuracy: 2, "the bubble ends 16 after the message")
        XCTAssertTrue((9...12).contains(ink.height), "not 14 pt: \(ink.height) tall")
        XCTAssertGreaterThanOrEqual(ink.minY, 4, "inside the top padding")
        XCTAssertLessThanOrEqual(ink.maxY, bubble.height - 4, "inside the bottom padding")

        let two = try XCTUnwrap(try drawBubble("Hello\nthere").bounds(of: Self.isBubbleOnBlack))
        XCTAssertEqual(two.height, 48, accuracy: 2, "two lines of 20 and the padding")
    }

    // MARK: - The widget and the buttons (macOS and iOS)

    /// A8.3: the switch draws a Tooltip; an empty or missing message draws
    /// the child alone, adding nothing (MUI tooltip.dart:499-501).
    func testA8_3_AnEmptyMessageDrawsTheChildAlone() throws {
        let model = try page([
            tooltip("said", "Hi", "a"), box("a", "#E53935"),
            tooltip("empty", "", "b"), box("b", "#E53935"),
            tooltip("missing", nil, "c"), box("c", "#E53935"),
        ])
        let drawn = BottomSheetTests.branch(WidgetView(node: try XCTUnwrap(model.resolve("said")), model: model).body)
        XCTAssertTrue(drawn is TooltipNodeView, "the switch draws a Tooltip with \(type(of: drawn))")
        XCTAssertTrue(try view(model, "said").trigger.shows)
        for id in ["empty", "missing"] {
            XCTAssertFalse(try view(model, id).trigger.shows, "\(id): a bubble to show")
            XCTAssertEqual(try BottomSheetTests().draw(model, id, width: 60, height: 60).bytes,
                           try BottomSheetTests().draw(model, "a", width: 60, height: 60).bytes, "\(id): not the child")
        }
        XCTAssertNil(try view(model, "said").trigger.pressGestures(bubble: { nil }),
                     "the widget's long press takes a button's place")
    }

    /// A8.3, risk 11: Flutter wraps the IconButton's GestureDetector in the
    /// Tooltip (button_builders.dart:136-159). Both long-press recognizers
    /// join the arena, the button's first, so with its own onLongPress the
    /// button's timer ends first and wins: onLongPress fires and no bubble
    /// shows. With only onTap, or disabled, the Tooltip's long press wins:
    /// the bubble shows and the tap fires nothing. A tap stays the button's.
    func testA8_3_AnIconButtonsHoldShowsTheBubbleAndFiresNothingUnlessItHasOnLongPress() async throws {
        let buttons = IconButtonFabTests()
        let model = try buttons.page([
            buttons.column("col", ["tap", "hold", "off", "empty"]),
            buttons.iconButton("tap", "i1", ["tooltip": "Tip"], on: ["onTap"]), buttons.icon("i1"),
            buttons.iconButton("hold", "i2", ["tooltip": "Tip"], on: ["onTap", "onLongPress"]), buttons.icon("i2"),
            buttons.iconButton("off", "i3", ["tooltip": "Tip", "enabled": false], on: ["onTap"]), buttons.icon("i3"),
            buttons.iconButton("empty", "i4", ["tooltip": ""], on: ["onTap"]), buttons.icon("i4"),
        ])
        var shown = 0
        let bubble: PressGestures.Fire = { shown += 1; return nil }

        let tap = try XCTUnwrap(try buttons.iconButtonView(model, "tap").tooltip.pressGestures(bubble: bubble))
        await tap.tap?()?.value
        XCTAssertEqual(buttons.fired(model), buttons.counts(tap: 1), "the tap is not the button's")
        _ = try XCTUnwrap(tap.longPress, "the hold takes nothing")()
        XCTAssertEqual(shown, 1, "the hold shows no bubble")
        XCTAssertEqual(buttons.fired(model), buttons.counts(tap: 1), "the hold fired the button")

        let hold = try XCTUnwrap(try buttons.iconButtonView(model, "hold").tooltip.pressGestures(bubble: bubble))
        await hold.longPress?()?.value
        XCTAssertEqual(buttons.fired(model), buttons.counts(tap: 1, longPress: 1), "its own long press lost")
        XCTAssertEqual(shown, 1, "a bubble over the button's own long press")

        let off = try XCTUnwrap(try buttons.iconButtonView(model, "off").tooltip.pressGestures(bubble: bubble))
        XCTAssertNil(off.tap, "a disabled button takes a tap")
        _ = try XCTUnwrap(off.longPress, "a disabled button's tooltip takes no hold")()
        XCTAssertEqual(shown, 2)

        let empty = try XCTUnwrap(try buttons.iconButtonView(model, "empty").tooltip.pressGestures(bubble: bubble))
        XCTAssertNotNil(empty.tap)
        XCTAssertNil(empty.longPress, "an empty tooltip takes the hold")
    }

    /// A8.3, risk 11: the FAB's Tooltip is inside the GestureDetector that
    /// carries its onLongPress (button_builders.dart:216-219;
    /// floating_action_button.dart:623), so the Tooltip's recognizer joins
    /// the arena first and wins: a hold shows the bubble and onLongPress never
    /// fires; disabled, the hold still shows it. Without a tooltip the FAB
    /// keeps its own long press.
    func testA8_3_AFabsHoldShowsTheBubbleOverItsOwnLongPress() async throws {
        let buttons = IconButtonFabTests()
        let model = try buttons.page([
            buttons.column("col", ["tip", "off", "plain"]),
            buttons.fab("tip", "i1", ["tooltip": "Add"], on: ["onTap", "onLongPress"]), buttons.icon("i1"),
            buttons.fab("off", "i2", ["tooltip": "Add", "enabled": false], on: ["onLongPress"]), buttons.icon("i2"),
            buttons.fab("plain", "i3", [:], on: ["onLongPress"]), buttons.icon("i3"),
        ])
        var shown = 0
        let bubble: PressGestures.Fire = { shown += 1; return nil }

        let tip = try XCTUnwrap(try buttons.fabView(model, "tip").tooltip.pressGestures(bubble: bubble))
        _ = try XCTUnwrap(tip.longPress)()
        XCTAssertEqual(shown, 1, "the hold shows no bubble")
        XCTAssertEqual(buttons.fired(model), buttons.counts(), "the hold fired onLongPress")
        await tip.tap?()?.value
        XCTAssertEqual(buttons.fired(model), buttons.counts(tap: 1))

        let off = try XCTUnwrap(try buttons.fabView(model, "off").tooltip.pressGestures(bubble: bubble))
        XCTAssertNil(off.tap)
        _ = try XCTUnwrap(off.longPress, "a disabled FAB's tooltip takes no hold")()
        XCTAssertEqual(shown, 2)

        let plain = try XCTUnwrap(try buttons.fabView(model, "plain").tooltip.pressGestures(bubble: bubble))
        await plain.longPress?()?.value
        XCTAssertEqual(buttons.fired(model), buttons.counts(tap: 1, longPress: 1), "without a tooltip")
        XCTAssertEqual(shown, 2)
    }

    #if canImport(UIKit)
    // MARK: - On screen (iOS)

    /// A8.3: the child's frame the Tooltip measures is where it is drawn; the
    /// bubble is centred on it, its top 24 below its centre, placed by
    /// TooltipPlacement in the whole window (tooltip.dart:413-414;
    /// geometry.dart:42-68), and drawn over the page. Released, it is still
    /// drawn after 1499 ms and gone 75 ms after 1500.
    func testA8_3_TheBubbleIsCentred24BelowTheChildsCentre() async throws {
        let shown = try await show([stack("root", ["p", "probe"]), positioned("p", ["left": 100, "top": 100], "tip"),
                                    tooltip("tip", "Hello", "box"), box("box", "#E53935"), probe])
        defer { shown.window.isHidden = true }
        let drawn = try XCTUnwrap(try snapshot(shown.window).bounds(of: Pixels.isRed), "no child")
        let measured = try XCTUnwrap(shown.tooltips.frames[shown.key("tip")], "the Tooltip measured no frame")
        assertFrame(measured, drawn, "the measured child")

        shown.tooltips.press(shown.key("tip"), message: "Hello", direction: .leftToRight)
        pass(150, shown.tooltips)
        let bubble = try XCTUnwrap(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "no bubble")
        assertPlaced(bubble, around: drawn, overlay: CGSize(width: 300, height: 500))
        XCTAssertEqual(bubble.minY, drawn.midY + 24, accuracy: Self.accuracy, "not 24 below the centre")
        XCTAssertEqual(bubble.midX, drawn.midX, accuracy: Self.accuracy, "not centred on the child")
        XCTAssertEqual(bubble.height, 32, accuracy: Self.accuracy)

        // No touch was seen: the 1.5 s run from the press.
        pass(1349, shown.tooltips)
        XCTAssertNotNil(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "gone before 1.5 s")
        pass(76, shown.tooltips)
        XCTAssertNil(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "still drawn after its fade out")
    }

    /// A8.3: near the bottom the bubble goes above, its bottom 24 over the
    /// child's centre; near a side it is held 10 from it (geometry.dart
    /// :50-67).
    func testA8_3_NearTheBottomTheBubbleGoesAboveNearASideItIsHeld10In() async throws {
        let shown = try await show([
            stack("root", ["ps", "pl", "probe"]),
            positioned("ps", ["left": 0, "top": 100], "side"), tooltip("side", "Hello", "a"), box("a", "#E53935"),
            positioned("pl", ["left": 130, "bottom": 0], "low"), tooltip("low", "Hello", "b"), box("b", "#0000FF"),
            probe,
        ])
        defer { shown.window.isHidden = true }
        let pixels = try snapshot(shown.window)
        let side = try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "no side child")
        let low = try XCTUnwrap(pixels.bounds(of: FlowTests.isBlue), "no low child")

        shown.tooltips.press(shown.key("side"), message: "Hello", direction: .leftToRight)
        pass(150, shown.tooltips)
        var bubble = try XCTUnwrap(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "no side bubble")
        XCTAssertEqual(bubble.minX, 10, accuracy: Self.accuracy, "not held 10 from the side")
        assertPlaced(bubble, around: side, overlay: CGSize(width: 300, height: 500))

        shown.tooltips.press(shown.key("low"), message: "Hello", direction: .leftToRight)
        pass(150, shown.tooltips)
        bubble = try XCTUnwrap(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "no low bubble")
        XCTAssertEqual(bubble.maxY, low.midY - 24, accuracy: Self.accuracy, "not above, 24 over the centre")
        assertPlaced(bubble, around: low, overlay: CGSize(width: 300, height: 500))
    }

    /// A8.3: with the keyboard up the overlay stops at its top
    /// (raw_tooltip.dart:896-897): a bubble that fits below the child in the
    /// window but not above the keyboard goes above; it comes back below as
    /// the keyboard goes.
    func testA8_3_WithTheKeyboardUpTheOverlayStopsAtItsTop() async throws {
        let shown = try await show([stack("root", ["p", "probe"]), positioned("p", ["left": 100, "top": 210], "tip"),
                                    tooltip("tip", "Hello", "box"), box("box", "#E53935"), probe])
        defer { shown.window.isHidden = true }
        let child = try XCTUnwrap(try snapshot(shown.window).bounds(of: Pixels.isRed), "no child")
        let window = shown.window
        let keyboard = window.convert(CGRect(x: 0, y: 300, width: 300, height: 200), to: window.screen.coordinateSpace)
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                                        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboard)])
        defer {
            NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: [:])
        }
        shown.tooltips.press(shown.key("tip"), message: "Hello", direction: .leftToRight)
        pass(150, shown.tooltips)
        var bubble = try XCTUnwrap(try snapshot(window).bounds(of: Self.isBubbleOnWhite), "no bubble")
        assertPlaced(bubble, around: child, overlay: CGSize(width: 300, height: 300))
        XCTAssertLessThan(bubble.maxY, child.midY, "below, over the keyboard")

        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: [:])
        bubble = try XCTUnwrap(try snapshot(window).bounds(of: Self.isBubbleOnWhite), "no bubble")
        XCTAssertEqual(bubble.minY, child.midY + 24, accuracy: Self.accuracy, "not back below")
    }

    /// A8.3: the bubble takes no touch (MUI passes ignorePointer for a
    /// message, tooltip.dart:571; raw_tooltip.dart:883-890): a field under it
    /// gets the hit.
    func testA8_3_TheBubbleTakesNoTouch() async throws {
        let probes = (0..<8).map { "f\($0)" }
        let shown = try await show(
            [stack("root", ["fields", "p", "probe"]), node("fields", "Column", ["crossAxisAlignment": "stretch"], probes)]
                + probes.map { node($0, "TextField", ["placeholder": .string($0)], kind: "input") }
                + [positioned("p", ["left": 100, "top": 0], "tip"), tooltip("tip", "Hello", "box"),
                   box("box", "#E53935"), probe])
        defer { shown.window.isHidden = true }
        shown.tooltips.press(shown.key("tip"), message: "Hello", direction: .leftToRight)
        pass(150, shown.tooltips)
        let bubble = try XCTUnwrap(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "no bubble")
        let point = CGPoint(x: bubble.midX, y: bubble.midY)
        XCTAssertTrue(DialogTests.fields(in: shown.window).contains {
            $0.convert($0.bounds, to: shown.window).contains(point)
        }, "no field under the bubble")
        XCTAssertTrue(FlowTests.isInField(shown.window.hitTest(point, with: nil)), "the bubble took the touch")
    }

    /// A8.3: the message is the semantics tooltip, which Flutter's iOS
    /// engine reads as the label after the child's, on a new line
    /// (raw_tooltip.dart:949-952; SemanticsObject.mm:583-596): one element
    /// whose label starts with the child's and ends with the message. An
    /// IconButton's icon has no label, so its label is the tooltip. The
    /// bubble's text is an element of its own while it shows: Flutter puts
    /// no ExcludeSemantics around it (raw_tooltip.dart:887-893; MUI
    /// tooltip.dart:595-627).
    func testA8_3_VoiceOverReadsTheChildsLabelThenTheMessage() async throws {
        let buttons = IconButtonFabTests()
        let shown = try await show([
            node("root", "Column", ["crossAxisAlignment": "start"], ["tip", "ib", "probe"]),
            tooltip("tip", "Tip", "t"), node("t", "Text", ["data": "Hello"], kind: "primitive"),
            buttons.iconButton("ib", "i", ["tooltip": "Close"], on: ["onTap"]), buttons.icon("i"), probe,
        ])
        defer { shown.window.isHidden = true }
        let restore = SnackBarWidgetTests.automation(true)
        defer { _ = SnackBarWidgetTests.automation(restore) }
        _ = try snapshot(shown.window)
        let labels = DialogTests.objects(in: shown.window).filter(\.isAccessibilityElement)
            .compactMap(\.accessibilityLabel)
        let tip = try XCTUnwrap(labels.first { $0.contains("Hello") }, "no element for the child: \(labels)")
        XCTAssertTrue(tip.hasPrefix("Hello") && tip.hasSuffix("Tip") && tip.count > 8,
                      "the child's label, then the message: \(tip)")
        XCTAssertFalse(labels.contains("Hello"), "the child is an element of its own: \(labels)")
        XCTAssertTrue(labels.contains("Close"), "the IconButton is not labelled by its tooltip: \(labels)")
        XCTAssertFalse(labels.contains("Tip"), "a bubble is an element before it shows: \(labels)")

        shown.tooltips.press(shown.key("tip"), message: "Tip", direction: .leftToRight)
        pass(150, shown.tooltips)
        _ = try snapshot(shown.window)
        let shownLabels = DialogTests.objects(in: shown.window).filter(\.isAccessibilityElement)
            .compactMap(\.accessibilityLabel)
        XCTAssertTrue(shownLabels.contains("Tip"), "the bubble is not an element: \(shownLabels)")
    }

    /// A8.3: IconButton's and the FAB's `tooltip` show the bubble around the
    /// button's box: under the IconButton's (24 + 16 square), above the FAB's
    /// at the bottom (56 square). An empty tooltip measures nothing.
    func testA8_3_AnIconButtonAndAFabShowTheBubbleAroundTheirBox() async throws {
        let buttons = IconButtonFabTests()
        let shown = try await show([
            stack("root", ["pi", "pf", "pe", "probe"]),
            positioned("pi", ["left": 100, "top": 20], "ib"),
            buttons.iconButton("ib", "i1", ["tooltip": "Close"], on: ["onTap"]), buttons.icon("i1"),
            positioned("pf", ["right": 16, "bottom": 16], "fab"),
            buttons.fab("fab", "i2", ["tooltip": "Add"], on: ["onTap"]), buttons.icon("i2"),
            positioned("pe", ["left": 0, "top": 200], "none"),
            buttons.iconButton("none", "i3", ["tooltip": ""], on: ["onTap"]), buttons.icon("i3"),
            probe,
        ])
        defer { shown.window.isHidden = true }
        XCTAssertNil(shown.tooltips.frames[shown.key("none")], "an empty tooltip measured a frame")
        let box = try XCTUnwrap(shown.tooltips.frames[shown.key("ib")], "the IconButton measured no frame")
        XCTAssertEqual(box.size, CGSize(width: 40, height: 40))
        shown.tooltips.press(shown.key("ib"), message: "Close", direction: .leftToRight)
        pass(150, shown.tooltips)
        var bubble = try XCTUnwrap(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "no IconButton bubble")
        XCTAssertEqual(bubble.minY, box.midY + 24, accuracy: Self.accuracy)
        assertPlaced(bubble, around: box, overlay: CGSize(width: 300, height: 500))

        let pixels = try snapshot(shown.window)
        let fill = try XCTUnwrap(pixels.bounds(of: { DialogTests.near($0, IconButtonFabTests.fabFill, 3) }),
                                 "no FAB")
        let fab = try XCTUnwrap(shown.tooltips.frames[shown.key("fab")], "the FAB measured no frame")
        assertFrame(fab, fill, "the FAB's measured box")
        shown.tooltips.press(shown.key("fab"), message: "Add", direction: .leftToRight)
        pass(150, shown.tooltips)
        bubble = try XCTUnwrap(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "no FAB bubble")
        XCTAssertEqual(bubble.maxY, fab.midY - 24, accuracy: Self.accuracy, "not above the FAB")
        assertPlaced(bubble, around: fab, overlay: CGSize(width: 300, height: 500))
    }

    /// A8.3: Flutter places the bubble in the Overlay nearest the Tooltip
    /// (raw_tooltip.dart:965-969; overlay.dart:1941-1945): under tabs the
    /// branch Navigator's (StatefulShellRoute.indexedStack,
    /// navigation_handler.dart:92), which ends at the tab bar. A FAB right
    /// above the tab bar, with room below it in the window but not in the
    /// tab's area, gets its bubble above it, inside that area; so again
    /// after a switch to another tab and back (the TabView takes the tab's
    /// views off screen and puts them back).
    func testA8_3_UnderTabsAFabsBubbleGoesAboveItInsideTheTabArea() async throws {
        let buttons = IconButtonFabTests()
        let config: JSONValue = [
            "initialRoute": "/home",
            "tabs": [["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"],
                     ["id": "more", "label": "More", "icon": "menu", "initialRoute": "/more"]],
            "flows": [["name": "main", "routes": [["path": "home"], ["path": "more"]]]],
        ]
        let nodes = [stack("root", ["pf", "probe"]), positioned("pf", ["right": 16, "bottom": 16], "fab"),
                     buttons.fab("fab", "i", ["tooltip": "Add"], on: ["onTap"]), buttons.icon("i"), probe]
        let router = OrcaRouter(client: ScaffoldPages(components: ["home": nodes, "more": [box("m", "#00FF00")]])
                                    .client,
                                config: try config.decode(NavConfig.self), system: SystemRecorder().actions())
        let shown = try await show(router)
        defer { shown.window.isHidden = true }
        let tabs = try XCTUnwrap(SafeAreaShellTests.tabBar(in: shown.window), "no tab bar")
        let tabsTop = tabs.convert(tabs.bounds, to: shown.window).minY
        let fab = try XCTUnwrap(shown.tooltips.frames[shown.key("fab")], "the FAB measured no frame")
        let below = fab.midY + 24 + 32
        XCTAssertLessThanOrEqual(below, 500 - 10, "no room below the FAB in the window: \(fab)")
        XCTAssertGreaterThan(below, tabsTop - 10, "room below the FAB in the tab's area: \(fab), \(tabsTop)")

        shown.tooltips.press(shown.key("fab"), message: "Add", direction: .leftToRight)
        pass(150, shown.tooltips)
        let bubble = try XCTUnwrap(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite), "no FAB bubble")
        XCTAssertEqual(bubble.maxY, fab.midY - 24, accuracy: Self.accuracy, "not above the FAB: \(bubble)")
        XCTAssertLessThanOrEqual(bubble.maxY, tabsTop, "over the tab bar")
        assertPlaced(bubble, around: fab, overlay: CGSize(width: 300, height: tabsTop))
        pass(1500, shown.tooltips)
        pass(75, shown.tooltips)
        XCTAssertTrue(shown.tooltips.bubbles.isEmpty, "the bubble stayed")

        router.selectTab(1)
        try await Task.sleep(nanoseconds: 500_000_000)
        _ = try snapshot(shown.window)
        router.selectTab(0)
        try await Task.sleep(nanoseconds: 500_000_000)
        _ = try snapshot(shown.window)
        XCTAssertNotNil(shown.tooltips.areas[ObjectIdentifier(shown.page)], "the tab's Overlay is lost on return")
        let back = try XCTUnwrap(shown.tooltips.frames[shown.key("fab")], "the FAB has no frame on return")
        shown.tooltips.press(shown.key("fab"), message: "Add", direction: .leftToRight)
        pass(150, shown.tooltips)
        let again = try XCTUnwrap(try snapshot(shown.window).bounds(of: Self.isBubbleOnWhite),
                                  "no FAB bubble on return")
        XCTAssertEqual(again.maxY, back.midY - 24, accuracy: Self.accuracy, "not above the FAB on return: \(again)")
        assertPlaced(again, around: back, overlay: CGSize(width: 300, height: tabsTop))
    }

    /// A8.3: a Tooltip in a sheet under tabs keeps its bubble in the tab's
    /// area: the sheet is a route on the branch Navigator (showModalBottomSheet's
    /// nearest), so the bubble goes in that Navigator's Overlay
    /// (raw_tooltip.dart:965-969; overlay.dart:1941-1945), which ends at the
    /// tab bar. Near the panel's bottom, with room below its child in the
    /// window but not in the tab's area, the bubble goes above the child.
    func testA8_3_UnderTabsATooltipInASheetKeepsItsBubbleInTheTabsArea() async throws {
        let config: JSONValue = [
            "initialRoute": "/home",
            "tabs": [["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"],
                     ["id": "more", "label": "More", "icon": "menu", "initialRoute": "/more"]],
            "flows": [["name": "main", "routes": [["path": "home"], ["path": "more"]]]],
        ]
        let nodes = [
            stack("root", ["probe"]), probe,
            node("d", "Dialog", [:], ["sst"], kind: "structure"),
            stack("sst", ["pp"]), positioned("pp", ["left": 100, "bottom": 10], "stip"),
            tooltip("stip", "Hello", "sbox"), box("sbox", "#E53935"),
        ]
        let router = OrcaRouter(client: ScaffoldPages(components: ["home": nodes, "more": [box("m", "#00FF00")]])
                                    .client,
                                config: try config.decode(NavConfig.self), system: SystemRecorder().actions())
        let shown = try await show(router)
        defer { shown.window.isHidden = true }
        let tabs = try XCTUnwrap(SafeAreaShellTests.tabBar(in: shown.window), "no tab bar")
        let tabsTop = tabs.convert(tabs.bounds, to: shown.window).minY
        let dialogs = shown.page.dialogs
        dialogs.clock = { [unowned self] in self.now }
        let page = shown.page
        let opening = Task { await page.run(.openDialog(.init(dialogId: "d", heightFactor: 0.5))) }
        for _ in 0..<50 where dialogs.entries.isEmpty { await Task.yield() }
        now += 250
        dialogs.tick()
        let drawn = try XCTUnwrap(try snapshot(shown.window).bounds(of: Pixels.isRed), "no sheet child")
        XCTAssertGreaterThanOrEqual(drawn.minY, tabsTop / 2, "the child is not in the panel: \(drawn)")
        let child = try XCTUnwrap(shown.tooltips.frames[shown.key("stip")], "the Tooltip measured no frame")
        assertFrame(child, drawn, "the measured child in the sheet")
        let below = child.midY + 24 + 32
        XCTAssertLessThanOrEqual(below, 500 - 10, "no room below the child in the window: \(child)")
        XCTAssertGreaterThan(below, tabsTop - 10, "room below the child in the tab's area: \(child), \(tabsTop)")

        // On the panel, below its cut top corners (24): the barrier above it
        // is near the bubble's grey.
        let panel = Int(tabsTop / 2) + 24
        shown.tooltips.press(shown.key("stip"), message: "Hello", direction: .leftToRight)
        pass(150, shown.tooltips)
        let found = try XCTUnwrap(try snapshot(shown.window).rows(panel...499).bounds(of: Self.isBubbleOnWhite),
                                  "no bubble on the panel")
        let bubble = found.offsetBy(dx: 0, dy: CGFloat(panel))
        XCTAssertEqual(bubble.maxY, child.midY - 24, accuracy: Self.accuracy, "not above the child: \(bubble)")
        XCTAssertLessThanOrEqual(bubble.maxY, tabsTop, "over the tab bar")
        assertPlaced(bubble, around: child, overlay: CGSize(width: 300, height: tabsTop))
        await page.run(.closeDialog)
        now += 200
        dialogs.tick()
        await opening.value
    }

    /// A8.3: every touch of the window is seen and none is taken: a
    /// recognizer on the window that cancels and delays nothing, prevents no
    /// other and is prevented by none. A touch going down outside the
    /// bubble's child sends the bubble away; the last lift of a held press
    /// starts its 1.5 s.
    func testA8_3_TheWindowsTouchesAreSeenAndNoneIsTaken() async throws {
        let shown = try await show([stack("root", ["p", "probe"]), positioned("p", ["left": 100, "top": 100], "tip"),
                                    tooltip("tip", "Hello", "box"), box("box", "#E53935"), probe])
        defer { shown.window.isHidden = true }
        let watches = (shown.window.gestureRecognizers ?? []).compactMap { $0 as? TouchWatch }
        XCTAssertEqual(watches.count, 1, "the window has \(watches.count) touch watches")
        let watch = try XCTUnwrap(watches.first)
        XCTAssertFalse(watch.cancelsTouchesInView)
        XCTAssertFalse(watch.delaysTouchesBegan)
        XCTAssertFalse(watch.delaysTouchesEnded)
        XCTAssertFalse(watch.canPrevent(UITapGestureRecognizer()))
        XCTAssertFalse(watch.canBePrevented(by: UIPanGestureRecognizer()))

        let child = try XCTUnwrap(shown.tooltips.frames[shown.key("tip")])
        watch.down(CGPoint(x: child.midX, y: child.midY))
        shown.tooltips.press(shown.key("tip"), message: "Hello", direction: .leftToRight)
        pass(5000, shown.tooltips)
        XCTAssertEqual(opacity(shown.tooltips), 1, "not held")
        watch.up()
        pass(1500, shown.tooltips)
        pass(75, shown.tooltips)
        XCTAssertTrue(shown.tooltips.bubbles.isEmpty, "the lift did not start the 1.5 s")

        shown.tooltips.press(shown.key("tip"), message: "Hello", direction: .leftToRight)
        pass(150, shown.tooltips)
        watch.down(CGPoint(x: 10, y: 400))
        pass(75, shown.tooltips)
        XCTAssertTrue(shown.tooltips.bubbles.isEmpty, "a touch elsewhere left the bubble")
        watch.up()
    }

    /// A8.3: the bubble lies over the sheet openDialog opened: a Tooltip in
    /// the sheet shows its bubble over the white panel (Flutter's bubble is
    /// painted after the sheet route's entry it lives in, overlay.dart
    /// :1831-1836).
    func testA8_3_TheBubbleLiesOverTheSheet() async throws {
        let shown = try await show([
            stack("root", ["probe"]), probe,
            node("d", "Dialog", [:], ["col"], kind: "structure"),
            // The panel is as wide as its content: this one fills the width.
            node("col", "Column", ["crossAxisAlignment": "stretch"], ["row"]), node("row", "Row", [:], ["stip"]),
            tooltip("stip", "Hello", "sbox"), box("sbox", "#E53935"),
        ])
        defer { shown.window.isHidden = true }
        let dialogs = shown.page.dialogs
        dialogs.clock = { [unowned self] in self.now }
        let page = shown.page
        let opening = Task { await page.run(.openDialog(.init(dialogId: "d", heightFactor: 0.5))) }
        for _ in 0..<50 where dialogs.entries.isEmpty { await Task.yield() }
        now += 250
        dialogs.tick()
        let child = try XCTUnwrap(try snapshot(shown.window).bounds(of: Pixels.isRed), "no sheet child")
        XCTAssertGreaterThanOrEqual(child.minY, 249, "the child is not in the panel")

        // Black54 over white is 117 above the panel and in its cut top
        // corners (24): the bubble is looked for on the panel below them.
        let panel = 280
        shown.tooltips.press(shown.key("stip"), message: "Hello", direction: .leftToRight)
        pass(150, shown.tooltips)
        let found = try XCTUnwrap(try snapshot(shown.window).rows(panel...499).bounds(of: Self.isBubbleOnWhite),
                                  "no bubble on the panel")
        assertPlaced(found.offsetBy(dx: 0, dy: CGFloat(panel)), around: child,
                     overlay: CGSize(width: 300, height: 500))
        await page.run(.closeDialog)
        now += 200
        dialogs.tick()
        await opening.value
    }

    /// A8.3: a page shown on its own (no OrcaApp) draws the bubbles of its
    /// own Tooltips over itself.
    func testA8_3_APageShownOnItsOwnDrawsItsBubbles() throws {
        let found = Found()
        let widgets = WidgetBuilders()
        widgets.register("TooltipsProbe") { _, _ in AnyView(TooltipsProbe(found: found)) }
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [],
            "components": .array([stack("root", ["p", "probe"]), positioned("p", ["left": 100, "top": 100], "tip"),
                                  tooltip("tip", "Hello", "box"), box("box", "#E53935"), probe]),
        ]).decode(PageResponse.self)
        let model = OrcaPageModel(page: response, registry: WidgetRegistry(
            types: Set(GeneratedCapabilities.widgets).union(["Tooltip", "TooltipsProbe"])), widgets: widgets)
        let host = UIHostingController(rootView: OrcaPageView(model: model))
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 300, height: 500))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        defer { window.isHidden = true }
        let child = try XCTUnwrap(try snapshot(window).bounds(of: Pixels.isRed), "no child")
        let tooltips = try XCTUnwrap(found.tooltips, "the page has no tooltips")
        manual(tooltips)
        tooltips.press(OrcaTooltips.Key(model, "tip"), message: "Hello", direction: .leftToRight)
        pass(150, tooltips)
        let bubble = try XCTUnwrap(try snapshot(window).bounds(of: Self.isBubbleOnWhite), "no bubble")
        assertPlaced(bubble, around: child, overlay: CGSize(width: 300, height: 500))
    }


    // MARK: - Hosting

    private struct Shown {
        let window: UIWindow
        let router: OrcaRouter
        let page: OrcaPageModel
        let tooltips: OrcaTooltips

        func key(_ node: String) -> OrcaTooltips.Key { OrcaTooltips.Key(page, node) }
    }

    /// OrcaApp on a router whose page is `nodes`, in a light 300 x 500
    /// window with top 30 and bottom 20 insets, once the page has loaded;
    /// the app's tooltips, found by the page's probe, on the test's clock.
    private func show(_ nodes: [JSONValue]) async throws -> Shown {
        try await show(OrcaRouter(client: ScaffoldPages(components: ["page": nodes]).client, path: "page",
                                  system: SystemRecorder().actions()))
    }

    /// OrcaApp on `router`, as `show(_:)` hosts it, once its first page has
    /// loaded; that page's nodes include the probe.
    private func show(_ router: OrcaRouter) async throws -> Shown {
        let found = Found()
        let widgets = WidgetBuilders()
        // Widens the registry; the SDK's switch draws the Tooltip itself.
        widgets.register("Tooltip") { _, _ in AnyView(EmptyView()) }
        widgets.register("TooltipsProbe") { _, _ in AnyView(TooltipsProbe(found: found)) }
        let host = UIHostingController(rootView: OrcaApp(router: router, widgets: widgets))
        host.additionalSafeAreaInsets = SafeAreaShellTests.insets
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 300, height: 500))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        let loader = router.loader(for: router.root)
        for _ in 0..<30 {
            if case .loaded = loader.phase, found.tooltips != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard case .loaded(let page) = loader.phase else {
            window.isHidden = true
            throw NSError(domain: "TooltipTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "not loaded"])
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let tooltips = found.tooltips else {
            window.isHidden = true
            throw NSError(domain: "TooltipTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "no app tooltips"])
        }
        manual(tooltips)
        return Shown(window: window, router: router, page: page, tooltips: tooltips)
    }

    private func snapshot(_ window: UIWindow) throws -> Pixels {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }

    /// `bubble` where TooltipPlacement puts a bubble of its size for `child`
    /// in `overlay`.
    private func assertPlaced(_ bubble: CGRect, around child: CGRect, overlay: CGSize,
                              file: StaticString = #filePath, line: UInt = #line) {
        let origin = TooltipPlacement.origin(
            child: .init(x: child.minX, y: child.minY, width: child.width, height: child.height),
            bubble: .init(width: bubble.width, height: bubble.height),
            overlay: .init(width: overlay.width, height: overlay.height))
        XCTAssertEqual(bubble.minX, CGFloat(origin.x), accuracy: Self.accuracy, "x: \(bubble) for \(child)", file: file, line: line)
        XCTAssertEqual(bubble.minY, CGFloat(origin.y), accuracy: Self.accuracy, "y: \(bubble) for \(child)", file: file, line: line)
    }

    static func isBubbleOnWhite(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        abs(Int(p.r) - 113) <= 4 && abs(Int(p.g) - 113) <= 4 && abs(Int(p.b) - 113) <= 4
    }
    #endif

    // MARK: - Pages

    private var probe: JSONValue { node("probe", "TooltipsProbe", kind: "primitive") }

    /// A page of `nodes` (the first is the root) whose registry draws Tooltip.
    func page(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: response, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["Tooltip"])))
    }

    func view(_ model: OrcaPageModel, _ id: String) throws -> TooltipNodeView {
        TooltipNodeView(node: try XCTUnwrap(model.resolve(id), "no node \(id)"), model: model)
    }

    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:], _ children: [String] = [],
              kind: String = "layout") -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": .string(kind),
            "childMode": children.count > 1 || ["Column", "Row", "Stack"].contains(type) ? "multi"
                : children.isEmpty ? "none" : "single",
            "props": .object(props), "children": .array(children.map(JSONValue.string)), "watches": [],
        ]
    }

    func tooltip(_ id: String, _ message: JSONValue?, _ child: String) -> JSONValue {
        node(id, "Tooltip", message.map { ["message": $0] } ?? [:], [child])
    }

    func box(_ id: String, _ hex: String) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": 40, "height": 40])
    }

    func stack(_ id: String, _ children: [String]) -> JSONValue {
        node(id, "Stack", ["fit": "expand"], children)
    }

    func positioned(_ id: String, _ edges: [String: JSONValue], _ child: String) -> JSONValue {
        node(id, "Positioned", edges, [child])
    }

    // MARK: - Pixels

    /// The bubble alone, 10 in from the corner of a black picture at scale 1.
    private func drawBubble(_ message: String) throws -> Pixels {
        let renderer = ImageRenderer(content: TooltipBubble(message: message)
            .padding(10)
            .background(Color.black)
            .environment(\.colorScheme, .light))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "not drawn"))
    }

    static func isBubbleOnBlack(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        abs(Int(p.r) - 87) <= 4 && abs(Int(p.g) - 87) <= 4 && abs(Int(p.b) - 87) <= 4
    }

    static func isWhiteInk(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.r > 180 && p.g > 180 && p.b > 180
    }

    func assertColour(_ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (Int, Int, Int),
                      _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        BottomSheetTests().assertColour(actual, expected, message, file: file, line: line)
    }

    private func assertFrame(_ actual: CGRect, _ expected: CGRect, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected): \(message)",
                           file: file, line: line)
        }
    }
}

/// Where a probe puts the tooltips it finds.
@MainActor
private final class Found {
    var tooltips: OrcaTooltips?
}

/// Hands the tooltips of its environment to the test as it appears.
private struct TooltipsProbe: View {
    let found: Found
    @Environment(\.orcaTooltips) private var tooltips

    var body: some View {
        Color.clear.frame(width: 0, height: 0).onAppear { found.tooltips = tooltips }
    }
}
#endif
