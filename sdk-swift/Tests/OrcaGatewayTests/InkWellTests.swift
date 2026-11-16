#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A6.6 and A6.7 for InkWell, as Flutter's `_buildInkWell`
/// (layout_builders.dart:615-634) builds it: Material's InkWell with onTap,
/// onLongPress and onDoubleTap always set, so it is live with no actions and
/// has no `enabled`, a single tap waits out the double-tap timeout and a long
/// press takes Flutter's 500 ms; its highlight drawn under the child, clipped
/// to `borderRadius`, and no ripple on iOS. Each trigger counts its fires in
/// a page state key. Swift cannot inject a tap (TouchTests): a gesture runs
/// the view's own action for it, and what takes touches is found by hit
/// tests over text fields behind, in a hosted window (iOS). The double-tap
/// window is `DoubleTapResolver`'s and `InkTaps`', tested here; that SwiftUI
/// delivers each lift, the hold and a swipe is checked by hand. The look,
/// pressed and at rest, is ImageRenderer pixels at scale 1
/// (macOS and iOS). The registry is widened by InkWell (advertised only in
/// group 8).
@MainActor
final class InkWellTests: XCTestCase {
    // MARK: A6.6

    /// A6.6: onDoubleTap is always set (Flutter's builder sets all three), so
    /// a node with only onTap still has its double tap and long press
    /// attached, firing nothing, and a tap is held as Flutter's
    /// DoubleTapGestureRecognizer holds it (`DoubleTapResolver`): it fires
    /// onTap, once, only when kDoubleTapTimeout, 300 ms
    /// (gestures/constants.dart:35), has passed since its lift with no
    /// second tap; not at 250 ms.
    func testA6_6ATapFiresOnTapOnlyOnceTheDoubleTapTimeoutHasPassed() async throws {
        let model = try page([inkWell("w", "c", on: ["onTap"]), sizedBox("c", 100, 50)])
        let well = try view(model, "w")
        let doubleTap = try XCTUnwrap(well.doubleTap, "no double tap attached: a single tap would not wait")
        let longPress = try XCTUnwrap(well.longPress, "no long press attached")

        await well.tap?()?.value
        XCTAssertEqual(fired(model), counts(tap: 1))
        XCTAssertNil(doubleTap(), "a double tap with no onDoubleTap fired something")
        XCTAssertNil(longPress(), "a long press with no onLongPress fired something")
        XCTAssertEqual(fired(model), counts(tap: 1))

        var taps = DoubleTapResolver()
        XCTAssertEqual(taps.tapEnded(at: 0), [], "a tap fired at its lift")
        XCTAssertEqual(taps.advance(to: 0.25), [], "250 ms after the tap")
        XCTAssertEqual(taps.advance(to: 0.299), [], "299 ms after the tap")
        XCTAssertEqual(taps.advance(to: 0.3), [.tap], "300 ms after the tap")
        XCTAssertEqual(taps.advance(to: 1), [], "the tap fired twice")
    }

    /// A6.6: a double tap fires onDoubleTap once, and onTap not at all: a
    /// second tap lifting 250 ms after the first makes the two a double tap
    /// at that lift, and no tap fires after it.
    func testA6_6ADoubleTapFiresOnDoubleTapOnly() async throws {
        let model = try page([inkWell("w", "c"), sizedBox("c", 100, 50)])

        await (try view(model, "w")).doubleTap?()?.value

        XCTAssertEqual(fired(model), counts(doubleTap: 1))
        var taps = DoubleTapResolver()
        XCTAssertEqual(taps.tapEnded(at: 0), [])
        XCTAssertEqual(taps.tapEnded(at: 0.25), [.doubleTap], "a second tap 250 ms after the first")
        XCTAssertNil(taps.deadline, "a tap still held after the double tap")
        XCTAssertEqual(taps.advance(to: 1), [], "the double tap also fired a tap")
    }

    /// A6.6: a second tap 350 ms after the first is a tap of its own: the
    /// first fires onTap at 300 ms, the second 300 ms after its own lift.
    /// Should the wait run late, the second lift fires the first tap before
    /// it holds itself.
    func testA6_6ASecondTapAfterTheTimeoutIsATapOfItsOwn() {
        var taps = DoubleTapResolver()
        XCTAssertEqual(taps.tapEnded(at: 0), [])
        XCTAssertEqual(taps.advance(to: 0.3), [.tap], "the first tap")
        XCTAssertEqual(taps.tapEnded(at: 0.35), [], "the second tap fired at its lift")
        XCTAssertEqual(taps.advance(to: 0.6), [], "the second tap fired before its 300 ms")
        XCTAssertEqual(taps.advance(to: 0.65), [.tap], "the second tap")

        var late = DoubleTapResolver()
        XCTAssertEqual(late.tapEnded(at: 0), [])
        XCTAssertEqual(late.tapEnded(at: 0.35), [.tap], "the first tap, its window over")
        XCTAssertEqual(late.advance(to: 0.65), [.tap], "the second tap")
    }

    /// A6.6: the view's taps (`InkTaps`) wait out the window on the clock: a
    /// tap fires nothing at its lift and onTap once 300 ms have passed; two
    /// taps 250 ms apart fire the double tap at the second lift and leave no
    /// wait behind.
    func testA6_6TheTapsWaitOutTheWindowInRealTime() async throws {
        let taps = InkTaps()
        let seen = Seen()
        let start = Date()

        taps.tapEnded(at: 0) { seen.events.append($0) }
        XCTAssertEqual(seen.events, [], "a tap fired at its lift")
        let wait = try XCTUnwrap(taps.wait, "no wait for the double-tap window")
        await wait.value
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.29, "the tap fired before 300 ms")
        XCTAssertEqual(seen.events, [.tap])

        taps.tapEnded(at: 10) { seen.events.append($0) }
        taps.tapEnded(at: 10.25) { seen.events.append($0) }
        XCTAssertEqual(seen.events, [.tap, .doubleTap])
        XCTAssertNil(taps.wait, "a double tap left a tap waiting")
    }

    /// A6.6: a long press fires onLongPress and no tap. The InkWell's long
    /// press (the first of `InkWellNodeView.gestures`, the gesture it
    /// attaches) waits Flutter's kLongPressTimeout, 500 ms
    /// (gestures/constants.dart:29), and allows Flutter's kTouchSlop, 18
    /// (:65), not SwiftUI's default 10. That SwiftUI then delivers a hold as
    /// the long press alone, and gives it up past 18 pt, needs a touch,
    /// which a package test cannot inject: a hand check.
    func testA6_6ALongPressFiresOnLongPressAfterFlutters500ms() async throws {
        let model = try page([inkWell("w", "c"), sizedBox("c", 100, 50)])

        await (try view(model, "w")).longPress?()?.value

        XCTAssertEqual(fired(model), counts(longPress: 1))
        let press = InkWellNodeView.gestures.first
        XCTAssertEqual(press.minimumDuration, 0.5, "Flutter's kLongPressTimeout")
        XCTAssertEqual(press.maximumDistance, 18, "Flutter's kTouchSlop")
        XCTAssertEqual(LongPressGesture().maximumDistance, 10, "SwiftUI's default slop")
    }

    /// A6.6: the long press and the tap are one gesture, exactly the FAB's
    /// (`PressGestures.exclusive`, the shape the iPhone hand check proves),
    /// as Flutter's gesture arena decides between its recognizers: the long
    /// press first (500 ms, 18 pt), so the tap can succeed only once it has
    /// failed, the press lifted sooner, and once it succeeds the tap cannot
    /// (a hold is never a tap); then one tap, whose lifts `InkTaps` sorts
    /// into taps and double taps. Nothing else is in it: a count-2 tap in it
    /// lost the single taps on the iPhone (hand check 2), and the
    /// highlight's `.updating` on its long press lost every tap (hand check
    /// 3). Read from the gesture the
    /// view attaches (`InkWellNodeView.gestures`).
    func testA6_6TheLongPressAndTheTapAreOneGestureTheLongPressFirst() {
        let gestures: ExclusiveGesture<LongPressGesture, TapGesture> = InkWellNodeView.gestures

        XCTAssertEqual(gestures.first.minimumDuration, 0.5, "first, the long press: Flutter's kLongPressTimeout")
        XCTAssertEqual(gestures.first.maximumDistance, 18, "first, the long press: Flutter's kTouchSlop")
        XCTAssertEqual(gestures.second.count, 1, "then one tap")
    }

    /// A6.6: the pressed highlight is read by a gesture of its own, beside the
    /// InkWell's (simultaneous, so it cannot take a touch from it): a long
    /// press that never succeeds, pressing from the touch, given up past
    /// Flutter's 18 pt kTouchSlop (Flutter cancels the tap there), and, as a
    /// @GestureState, reset on the lift and when a ScrollView takes the
    /// touch. What a package test cannot reach, as it cannot inject a touch:
    /// that SwiftUI delivers a 0.7 s hold as the long press alone and a quick
    /// press as the tap, shows and clears the highlight so, and lets a swipe
    /// that starts on the InkWell scroll a ScrollView around it (hand
    /// checks).
    func testA6_6TheHighlightIsReadByAGestureOfItsOwn() {
        let highlight = InkWellNodeView.highlightGesture(pressing: GestureState(initialValue: false))

        XCTAssertEqual(highlight.base.minimumDuration, .infinity, "the highlight's long press can succeed")
        XCTAssertEqual(highlight.base.maximumDistance, 18, "Flutter's kTouchSlop")
        var pressed = false
        var transaction = Transaction()
        highlight.body(true, &pressed, &transaction)
        XCTAssertTrue(pressed, "the press does not drive the highlight")
        highlight.body(false, &pressed, &transaction)
        XCTAssertFalse(pressed, "the highlight outlives the press")
    }

    /// A6.6: while pressed the highlight fills the InkWell in
    /// `highlightColor`, clipped to `borderRadius` (20: (3, 3) lies outside
    /// it, (8, 8) inside), and under the child, as Flutter paints its ink on
    /// the Material below it: an opaque child hides it, and is not clipped.
    /// At rest (through NodeView) there is none. Without `highlightColor`
    /// it is ThemeData()'s #BCBCBC66 (theme_data.dart:595), 228 over white.
    /// It fades in and out over Flutter's 200 ms (ink_well.dart:1036).
    func testA6_6APressDrawsTheHighlightUnderTheChildClippedToTheBorderRadius() throws {
        let model = try page([
            inkWell("w", "r", ["borderRadius": 20, "highlightColor": "#1E88E5"]),
            row("r", ["clear", "opaque"]),
            sizedBox("clear", 50, 60),
            container("opaque", "#E53935", 50, 60),
            inkWell("plain", "c"),
            sizedBox("c", 40, 40),
        ])
        let rest = try draw(NodeView(id: "w", model: model))
        Self.assertColour(rest.pixel(25, 30), Self.white, "at rest")
        Self.assertColour(rest.pixel(75, 30), Self.red, "the child at rest")

        let pressed = try draw(try view(model, "w").face(pressed: true))
        Self.assertColour(pressed.pixel(25, 30), Self.blue, "pressed")
        Self.assertColour(pressed.pixel(8, 8), Self.blue, "inside the top left corner")
        Self.assertColour(pressed.pixel(3, 3), Self.white, "outside the top left corner")
        Self.assertColour(pressed.pixel(8, 52), Self.blue, "inside the bottom left corner")
        Self.assertColour(pressed.pixel(3, 57), Self.white, "outside the bottom left corner")
        Self.assertColour(pressed.pixel(75, 30), Self.red, "the opaque child over the highlight")
        Self.assertColour(pressed.pixel(97, 3), Self.red, "the child, not clipped")
        Self.assertColour(pressed.pixel(110, 30), Self.white, "beside the InkWell")

        let plain = try draw(try view(model, "plain").face(pressed: true))
        Self.assertColour(plain.pixel(20, 20), (228, 228, 228), "ThemeData()'s highlight")
        Self.assertColour(try draw(NodeView(id: "plain", model: model)).pixel(20, 20), Self.white, "plain at rest")
        XCTAssertEqual(InkWellNodeView.highlightFade, 0.2, "Flutter's pressed highlight fade")
    }

    /// A6.6: iOS draws no ripple (D6): `splashColor` is not read, so a
    /// pressed InkWell with one is drawn exactly as one without, the
    /// highlight alone.
    func testA6_6TheSplashColorDrawsNoRippleOnIOS() throws {
        let model = try page([
            inkWell("splash", "c1", ["splashColor": "#E53935"]), sizedBox("c1", 40, 40),
            inkWell("none", "c2"), sizedBox("c2", 40, 40),
        ])
        let splash = try draw(try view(model, "splash").face(pressed: true))
        let none = try draw(try view(model, "none").face(pressed: true))

        Self.assertColour(splash.pixel(20, 20), (228, 228, 228), "the highlight")
        XCTAssertEqual(splash.bytes, none.bytes, "a splashColor changed the pressed look")
    }

    // MARK: A6.7

    /// A6.7: an InkWell with no actions is still live, as Flutter's builder
    /// sets all three handlers: its tap, double tap and long press are all
    /// attached, and fire nothing.
    func testA6_7AnInkWellWithNoActionsIsLiveAndFiresNothing() throws {
        let model = try page([inkWell("w", "c", on: []), sizedBox("c", 100, 50)])
        let well = try view(model, "w")

        for (name, gesture) in [("tap", well.tap), ("double tap", well.doubleTap), ("long press", well.longPress)] {
            let fire = try XCTUnwrap(gesture, "no \(name) attached")
            XCTAssertNil(fire(), "the \(name) fired something")
        }
        XCTAssertEqual(fired(model), counts())
    }

    /// A6.7: InkWell has no `enabled`: given `enabled: false` it still fires,
    /// and still draws its highlight when pressed.
    func testA6_7AnInkWellHasNoEnabled() async throws {
        let model = try page([inkWell("w", "c", ["enabled": false]), sizedBox("c", 40, 40)])
        let well = try view(model, "w")

        await well.tap?()?.value

        XCTAssertEqual(fired(model), counts(tap: 1))
        Self.assertColour(try draw(well.face(pressed: true)).pixel(20, 20), (228, 228, 228), "pressed")
    }

    #if canImport(UIKit)
    /// A6.7: an InkWell takes touches over its whole box (Flutter's
    /// HitTestBehavior.opaque), with no actions and around a child that
    /// draws nothing, so the field behind gets none there; beside the box
    /// the field behind takes them.
    func testA6_7AnInkWellWithNoActionsTakesTouchesOverItsWholeBox() throws {
        let hosted = try Host(try page(behind(inkWell("w", "c", on: [])) + [sizedBox("c", 100, 50)]))
        defer { hosted.close() }
        for point in [CGPoint(x: 2, y: 2), CGPoint(x: 50, y: 25), CGPoint(x: 97, y: 47)] {
            hosted.assertTaken(point)
        }
        hosted.assertPassed(CGPoint(x: 150, y: 20))
    }
    #endif

    // MARK: pages

    /// What a tap sequence fired, in order.
    @MainActor
    final class Seen {
        var events: [DoubleTapResolver.Event] = []
    }

    nonisolated static let triggers = ["onTap", "onDoubleTap", "onLongPress"]

    /// A page of `nodes` (the first is the root) whose registry draws
    /// InkWell; page state `onTap`, `onDoubleTap` and `onLongPress`, 0.
    func page(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let state: [JSONValue] = Self.triggers.map { ["key": .string($0), "scope": "page", "initial": 0] }
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(state), "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: response, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["InkWell"])))
    }

    /// `setState(key, key + 1)` in page scope, as the counter page's increment.
    func count(_ key: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": [
            "type": "transform", "input": ["type": "state", "key": .string(key), "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]
    }

    /// An InkWell around `child`, each trigger in `on` (all three by default)
    /// counting itself.
    func inkWell(_ id: String, _ child: String, _ props: [String: JSONValue] = [:],
                 on: [String] = InkWellTests.triggers) -> JSONValue {
        var node: [String: JSONValue] = [
            "id": .string(id), "type": "InkWell", "kind": "layout", "childMode": "single",
            "props": .object(props), "children": [.string(child)], "watches": [],
        ]
        if !on.isEmpty {
            node["actions"] = .object(Dictionary(uniqueKeysWithValues: on.map { ($0, count($0)) }))
        }
        return .object(node)
    }

    func sizedBox(_ id: String, _ width: Double, _ height: Double) -> JSONValue {
        ["id": .string(id), "type": "SizedBox", "kind": "layout", "childMode": "single",
         "props": ["width": .double(width), "height": .double(height)], "children": [], "watches": []]
    }

    /// A solid `hex` Container, `width` x `height`.
    func container(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        ["id": .string(id), "type": "Container", "kind": "layout", "childMode": "single",
         "props": ["color": .string(hex), "width": .double(width), "height": .double(height)], "children": [],
         "watches": []]
    }

    /// A Row as wide as its children.
    func row(_ id: String, _ children: [String]) -> JSONValue {
        ["id": .string(id), "type": "Row", "kind": "layout", "childMode": "multi",
         "props": ["mainAxisSize": "min"], "children": .array(children.map(JSONValue.string)), "watches": []]
    }

    /// A Stack: text fields behind (the probes), `front` over them at the
    /// top left (CheckboxRadioTests).
    func behind(_ front: JSONValue) -> [JSONValue] {
        CheckboxRadioTests().behind(front)
    }

    func view(_ model: OrcaPageModel, _ id: String) throws -> InkWellNodeView {
        InkWellNodeView(node: try XCTUnwrap(model.resolve(id), "no node \(id)"), model: model)
    }

    /// How many times each counter fired.
    func fired(_ model: OrcaPageModel) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: Self.triggers.map {
            ($0, model.store.value($0).doubleValue.map { Int($0) } ?? -1)
        })
    }

    func counts(tap: Int = 0, doubleTap: Int = 0, longPress: Int = 0) -> [String: Int] {
        ["onTap": tap, "onDoubleTap": doubleTap, "onLongPress": longPress]
    }

    // MARK: pixels

    static let white: (Int, Int, Int) = (255, 255, 255)
    static let red: (Int, Int, Int) = (0xE5, 0x39, 0x35)
    static let blue: (Int, Int, Int) = (0x1E, 0x88, 0xE5)

    /// `content` drawn at the top left of a light 120 x 80 white picture at
    /// scale 1.
    func draw<Content: View>(_ content: Content) throws -> Pixels {
        let renderer = ImageRenderer(content: content
            .frame(width: 120, height: 80, alignment: .topLeading)
            .background(Color.white)
            .environment(\.colorScheme, .light))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "not drawn"))
    }

    static func assertColour(_ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (Int, Int, Int),
                             _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let pairs = [(Int(actual.r), expected.0), (Int(actual.g), expected.1), (Int(actual.b), expected.2)]
        if pairs.contains(where: { abs($0.0 - $0.1) > 8 }) {
            XCTFail("\(message): \(actual) vs \(expected)", file: file, line: line)
        }
    }

    #if canImport(UIKit)
    typealias Host = CheckboxRadioTests.Host
    #endif
}

#endif
