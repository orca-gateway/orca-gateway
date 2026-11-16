#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A6.5 and A6.7 for IconButton and FloatingActionButton, as Flutter's
/// `_buildIconButton` and `_buildFAB` (button_builders.dart:93-163, :193-223)
/// draw them: IconButton in Flutter's own (size + 16) box, firing only when
/// enabled and given a handler; the FAB in Flutter's Material 3 shape, live
/// whenever enabled, with a long press through its wrapper, and placed by
/// the Scaffold at its bottom end. Each trigger counts its fires in a page
/// state key. Swift cannot inject a tap (TouchTests): a tap or a long press
/// runs the view's own gesture action, and what takes touches is found by
/// hit tests over text fields behind, in a hosted window (iOS). The boxes
/// and the looks are ImageRenderer pixels at scale 1 (macOS and iOS). The
/// registry is widened by the two types (advertised only in group 8).
@MainActor
final class IconButtonFabTests: XCTestCase {
    static let accuracy: CGFloat = 1

    // MARK: A6.5 IconButton

    /// A6.5: a tap fires onTap; a long press fires onLongPress and not
    /// onTap. Each fires once per gesture.
    func testA6_5AnIconButtonFiresOnTapAndOnLongPress() async throws {
        let model = try page([iconButton("b", "i", on: ["onTap", "onLongPress"]), icon("i")])
        let button = try iconButtonView(model, "b")

        await button.tap?()?.value
        XCTAssertEqual(fired(model), counts(tap: 1))
        await button.longPress?()?.value
        XCTAssertEqual(fired(model), counts(tap: 1, longPress: 1))
    }

    /// A6.5: the box is (size + 16) square, `size` 24 by default, the child
    /// centred; an Icon child keeps its own size, so `size` grows only the
    /// box. With `padding` the child is aligned by `alignment` inside it;
    /// `constraints` are outside the box, and their minimum wins over it.
    /// With no child the box holds an empty `size` square.
    func testA6_5AnIconButtonIsASizePlus16BoxWithItsChildCentred() throws {
        let model = try page([
            column("root", ["plain", "big", "padded", "constrained", "empty"]),
            iconButton("plain", "c1", on: ["onTap"]),
            iconButton("big", "i2", ["size": 32], on: ["onTap"]),
            iconButton("padded", "c3", ["padding": ["top": 2, "right": 0, "bottom": 0, "left": 3],
                                        "alignment": "topLeft"], on: ["onTap"]),
            iconButton("constrained", "c4", ["constraints": ["minWidth": 56, "minHeight": 56]], on: ["onTap"]),
            iconButton("empty", nil, ["size": 10]),
            box("c1", "#FF0000", 24), icon("i2", ["color": "#FF0000"]), box("c3", "#FF0000", 24),
            box("c4", "#FF0000", 24),
        ])
        let ids = ["plain", "big", "padded", "constrained", "empty"]
        let frames = NativeWidgetTests().layout(width: 300, height: 300) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ids, id: \.self) { NodeView(id: $0, model: model).record($0) }
            }
        }
        for (id, side) in [("plain", 40), ("big", 48), ("padded", 40), ("constrained", 56), ("empty", 26)]
            as [(String, CGFloat)] {
            let frame = try XCTUnwrap(frames[id], "\(id): not laid out")
            XCTAssertEqual(frame.width, side, accuracy: 0.5, "\(id): \(frame)")
            XCTAssertEqual(frame.height, side, accuracy: 0.5, "\(id): \(frame)")
        }

        assertFrame(try draw(model, "plain").bounds(of: Pixels.isRed), CGRect(x: 8, y: 8, width: 24, height: 24),
                    "the child centred")
        assertFrame(try draw(model, "padded").bounds(of: Pixels.isRed), CGRect(x: 3, y: 2, width: 24, height: 24),
                    "the child top left inside the padding")
        assertFrame(try draw(model, "constrained").bounds(of: Pixels.isRed),
                    CGRect(x: 16, y: 16, width: 24, height: 24), "the child centred in the constrained box")
        // The Icon keeps its 24: its glyph (about 20 of them) centred in the
        // 48 box, not grown to 32.
        let glyph = try XCTUnwrap(try draw(model, "big").bounds(of: Pixels.isRed), "no icon")
        XCTAssertEqual(glyph.midX, 24, accuracy: 1, "\(glyph)")
        XCTAssertEqual(glyph.midY, 24, accuracy: 1, "\(glyph)")
        XCTAssertTrue((16...24).contains(glyph.width), "the icon grew with size: \(glyph)")
    }

    /// A6.5: `color` tints the child's icon (Flutter's IconTheme) only when
    /// set; an Icon's own colour wins over it, and without it the icon is
    /// drawn as it is anywhere else. The box itself has no fill.
    func testA6_5ColorTintsTheChildOnlyWhenSet() throws {
        let model = try page([
            iconButton("tinted", "i1", ["color": "#E53935"], on: ["onTap"]),
            iconButton("own", "i2", ["color": "#E53935"], on: ["onTap"]),
            iconButton("untinted", "i3", on: ["onTap"]),
            icon("i1"), icon("i2", ["color": "#1E88E5"]), icon("i3"), icon("bare"),
        ])
        let bare = try draw(model, "bare").pixel(12, 12)

        Self.assertColour(try draw(model, "tinted").pixel(20, 20), Self.red, "tinted")
        Self.assertColour(try draw(model, "own").pixel(20, 20), Self.blue, "its own colour")
        Self.assertColour(try draw(model, "untinted").pixel(20, 20), (Int(bare.r), Int(bare.g), Int(bare.b)),
                          "untinted, as a bare Icon")
        Self.assertColour(try draw(model, "tinted").pixel(2, 2), (255, 255, 255), "the box")
    }

    // MARK: A6.5 FloatingActionButton

    /// A6.5: a tap fires onTap and a long press onLongPress (Flutter's
    /// GestureDetector around the FAB). The wrapper takes every long press
    /// while enabled, so a long press on a FAB without onLongPress fires
    /// nothing, not onTap.
    func testA6_5AFabFiresOnTapAndOnLongPress() async throws {
        let model = try page([fab("both", "i1", on: ["onTap", "onLongPress"]), fab("tapOnly", "i2", on: ["onTap"]),
                              icon("i1"), icon("i2")])
        let both = try fabView(model, "both")
        await both.tap?()?.value
        XCTAssertEqual(fired(model), counts(tap: 1))
        await both.longPress?()?.value
        XCTAssertEqual(fired(model), counts(tap: 1, longPress: 1))

        let tapOnly = try fabView(model, "tapOnly")
        let press = try XCTUnwrap(tapOnly.longPress, "the wrapper took no long press")
        await press()?.value
        XCTAssertEqual(fired(model), counts(tap: 1, longPress: 1))
    }

    /// A6.5: Flutter's Material 3 FAB under ThemeData(): 56 square with
    /// corner radius 16 in primaryContainer #EADDFF, its icon in
    /// onPrimaryContainer #4F378B; `mini` is 40 with radius 12, drawn in the
    /// middle of Flutter's padded 48 tap target; `backgroundColor` is the
    /// fill. `elevation` (6 without one) casts a shadow below it; 0 none.
    func testA6_5AFabIsMaterial3sRegularOrSmall() throws {
        let model = try page([
            column("root", ["regular", "mini", "raised"]),
            fab("regular", "i1", ["elevation": 0]),
            fab("mini", "i2", ["mini": true, "backgroundColor": "#E53935", "elevation": 0]),
            fab("raised", "i3"),
            icon("i1"), icon("i2"), icon("i3"),
        ])
        let frames = NativeWidgetTests().layout(width: 300, height: 300) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(["regular", "mini"], id: \.self) { NodeView(id: $0, model: model).record($0) }
            }
        }
        assertFrame(frames["regular"], CGRect(x: 0, y: 0, width: 56, height: 56), "regular")
        assertFrame(frames["mini"], CGRect(x: 0, y: 56, width: 48, height: 48), "mini, with its tap target")

        let regular = try draw(model, "regular")
        Self.assertColour(regular.pixel(4, 28), Self.fabFill, "the fill")
        Self.assertColour(regular.pixel(28, 28), Self.fabContent, "the icon")
        // The corner radius 16: (3, 3) lies outside it, (5, 5) inside (12 or
        // less would fill the first, 19 or more not the second).
        Self.assertColour(regular.pixel(3, 3), (255, 255, 255), "outside the corner")
        Self.assertColour(regular.pixel(5, 5), Self.fabFill, "inside the corner")
        Self.assertColour(regular.pixel(28, 58), (255, 255, 255), "a shadow at elevation 0")

        let mini = try draw(model, "mini")
        assertFrame(mini.bounds(of: Pixels.isRed), CGRect(x: 4, y: 4, width: 40, height: 40), "the mini's fill")
        Self.assertColour(mini.pixel(24, 24), Self.fabContent, "the mini's icon")
        // The mini's radius 12, from its corner at (4, 4): (2, 2) outside it,
        // (4, 4) inside (8 or less would fill the first, 16 or more not the
        // second).
        Self.assertColour(mini.pixel(6, 6), (255, 255, 255), "outside the mini's corner")
        Self.assertColour(mini.pixel(8, 8), Self.red, "inside the mini's corner")

        let shade = try draw(model, "raised").pixel(28, 58)
        XCTAssertLessThan(Int(shade.g), 250, "no shadow below at the default elevation: \(shade)")
    }

    /// A6.5: a long press takes Flutter's kLongPressTimeout, 500 ms
    /// (gestures/constants.dart:29): the buttons' long press waits 0.5 s,
    /// which is also SwiftUI's default (LongPressGesture's minimumDuration).
    func testA6_5ALongPressTakesFlutters500ms() {
        XCTAssertEqual(PressGestures.longPressDuration, 0.5)
        XCTAssertEqual(LongPressGesture().minimumDuration, PressGestures.longPressDuration, "SwiftUI's default")
    }

    /// A6.5: a button with both handlers decides between them as Flutter's
    /// gesture arena does, in one exclusive gesture, the long press first: a
    /// press held 500 ms is a long press and never also a tap, one lifted
    /// sooner a single tap. The long press allows Flutter's kTouchSlop, 18
    /// (gestures/constants.dart:65), not SwiftUI's default 10. Read from the
    /// gestures the buttons attach (`PressGestures`); that SwiftUI then
    /// delivers a hold as the long press alone needs a touch, which a
    /// package test cannot inject: a hand check.
    func testA6_5ALongPressIsExclusiveOfTheTapWithinFlutters18ptSlop() {
        let long = PressGestures.longPressGesture
        XCTAssertEqual(long.minimumDuration, 0.5, "Flutter's kLongPressTimeout")
        XCTAssertEqual(long.maximumDistance, 18, "Flutter's kTouchSlop")
        XCTAssertEqual(PressGestures.touchSlop, 18)
        XCTAssertEqual(LongPressGesture().maximumDistance, 10, "SwiftUI's default slop")

        let both = PressGestures.exclusive
        XCTAssertEqual(both.first.minimumDuration, 0.5, "the long press first")
        XCTAssertEqual(both.first.maximumDistance, 18, "the long press first")
        XCTAssertEqual(both.second.count, 1, "then a single tap")
    }

    /// A6.5: in the Scaffold's floatingActionButton slot the FAB sits at the
    /// bottom end, 16 in from both edges (Flutter's endFloat,
    /// floating_action_button_location.dart:25, :528-534, :565-586): bottom
    /// right, bottom left in right-to-left; a mini by its 48 tap target, so
    /// its fill is 20 in. It fires from there.
    func testA6_5AFabInTheScaffoldSitsBottomEnd16In() async throws {
        for (mini, direction, expected) in [
            (false, LayoutDirection.leftToRight, CGRect(x: 228, y: 328, width: 56, height: 56)),
            (false, .rightToLeft, CGRect(x: 16, y: 328, width: 56, height: 56)),
            (true, .leftToRight, CGRect(x: 240, y: 340, width: 40, height: 40)),
        ] {
            let model = try page([
                scaffold("page", ["body": "body", "floatingActionButton": "f"]),
                box("body", "#00FF00", 10),
                fab("f", "i", ["backgroundColor": "#E53935", "elevation": 0, "mini": .bool(mini)], on: ["onTap"]),
                icon("i"),
            ])
            let pixels = try draw(model, "page", width: 300, height: 400, direction: direction)
            assertFrame(pixels.bounds(of: Pixels.isRed), expected, "mini \(mini), \(direction)")

            await (try fabView(model, "f")).tap?()?.value
            XCTAssertEqual(fired(model), counts(tap: 1), "mini \(mini), \(direction)")
        }
    }

    // MARK: A6.7

    /// A6.7: an IconButton takes touches only when enabled and given onTap
    /// or onLongPress (Flutter wraps it in a GestureDetector only then,
    /// button_builders.dart:142-152). Without a handler, or disabled, it
    /// attaches no gesture, so a GestureDetector around it gets the tap;
    /// with one, it takes the tap itself, and only the triggers it has.
    func testA6_7AnIconButtonWithoutAHandlerOrDisabledTakesNoTouches() throws {
        let model = try page([
            iconButton("plain", "i1"), iconButton("off", "i2", ["enabled": false], on: ["onTap", "onLongPress"]),
            iconButton("tap", "i3", on: ["onTap"]), iconButton("hold", "i4", on: ["onLongPress"]),
            icon("i1"), icon("i2"), icon("i3"), icon("i4"),
        ])
        for id in ["plain", "off"] {
            XCTAssertNil(try iconButtonView(model, id).tap, "\(id) takes a tap")
            XCTAssertNil(try iconButtonView(model, id).longPress, "\(id) takes a long press")
        }
        XCTAssertNotNil(try iconButtonView(model, "tap").tap)
        XCTAssertNil(try iconButtonView(model, "tap").longPress, "a long press with no onLongPress")
        XCTAssertNil(try iconButtonView(model, "hold").tap, "a tap with no onTap")
        XCTAssertNotNil(try iconButtonView(model, "hold").longPress)
    }

    /// A6.7: a disabled IconButton is drawn at opacity 0.38, an enabled one
    /// without a handler at 1 (button_builders.dart:123-126).
    func testA6_7ADisabledIconButtonIsDrawnAt038() throws {
        let model = try page([
            iconButton("off", "i1", ["color": "#E53935", "enabled": false], on: ["onTap"]),
            iconButton("unbound", "i2", ["color": "#E53935"]),
            icon("i1"), icon("i2"),
        ])
        let faded = (Self.fade(Self.red.0), Self.fade(Self.red.1), Self.fade(Self.red.2))
        Self.assertColour(try draw(model, "off").pixel(20, 20), faded, "disabled")
        Self.assertColour(try draw(model, "unbound").pixel(20, 20), Self.red, "unbound")
    }

    /// A6.7: a FAB without a handler is live, as Flutter passes onPressed
    /// whenever enabled: it takes the tap and the long press, so a
    /// GestureDetector around it gets neither, and nothing fires.
    func testA6_7AFabWithoutAHandlerIsLiveAndFiresNothing() async throws {
        let model = try page([fab("f", "i"), icon("i")])
        let button = try fabView(model, "f")
        let tap = try XCTUnwrap(button.tap, "no tap taken")
        let press = try XCTUnwrap(button.longPress, "no long press taken")

        await tap()?.value
        await press()?.value
        XCTAssertEqual(fired(model), counts())
    }

    /// A6.7: a disabled FAB, regular or mini, is drawn as an enabled one (the
    /// same pixels in the same layout; Flutter's disabled elevation falls
    /// back to `elevation`, floating_action_button.dart:538-542) and is
    /// inert: no tap, no long press, so a GestureDetector around it gets the
    /// tap, as in Flutter, where its InkWell has no tap.
    func testA6_7ADisabledFabIsDrawnUnchangedAndInert() throws {
        let both = ["onTap", "onLongPress"]
        let model = try page([
            fab("off", "i1", ["enabled": false], on: both), fab("on", "i2", on: both),
            fab("offMini", "i3", ["mini": true, "enabled": false], on: both), fab("onMini", "i4", ["mini": true], on: both),
            icon("i1"), icon("i2"), icon("i3"), icon("i4"),
        ])
        XCTAssertEqual(try draw(model, "off").bytes, try draw(model, "on").bytes, "regular")
        XCTAssertEqual(try draw(model, "offMini").bytes, try draw(model, "onMini").bytes, "mini")
        Self.assertColour(try draw(model, "off").pixel(4, 28), Self.fabFill, "the disabled fill")
        for id in ["off", "offMini"] {
            XCTAssertNil(try fabView(model, id).tap, "\(id) takes a tap")
            XCTAssertNil(try fabView(model, id).longPress, "\(id) takes a long press")
        }
        XCTAssertNotNil(try fabView(model, "onMini").tap)
    }

    #if canImport(UIKit)
    // MARK: what takes touches (a hosted window)

    /// A6.5 and A6.7: a live IconButton takes touches over its whole box
    /// (Flutter's opaque GestureDetector), not only on its icon; without a
    /// handler or disabled, its empty corners let the field behind take
    /// them. Beside the box, the field behind takes them either way.
    func testA6_7OnlyALiveIconButtonTakesTouchesOverItsBox() throws {
        for (props, actions, live) in [([:], ["onTap"], true), ([:], ["onLongPress"], true), ([:], [], false),
                                       (["enabled": false], ["onTap"], false)] as [([String: JSONValue], [String], Bool)] {
            let hosted = try Host(try page(behind(iconButton("b", "i", props, on: actions)) + [icon("i")]))
            defer { hosted.close() }
            for point in [CGPoint(x: 2, y: 2), CGPoint(x: 37, y: 37)] {
                if live { hosted.assertTaken(point) } else { hosted.assertPassed(point) }
            }
            hosted.assertPassed(CGPoint(x: 45, y: 20))
        }
    }

    /// A6.5 and A6.7: a FAB takes touches over its fill, enabled or not (its
    /// Material takes the hit; disabled it does nothing with it), a mini over
    /// its whole 48 tap target. Beside it, the field behind takes them.
    func testA6_7AFabTakesTouchesEnabledOrNot() throws {
        for (props, edge) in [([:], CGPoint(x: 2, y: 28)), (["enabled": false], CGPoint(x: 2, y: 28)),
                              (["mini": true], CGPoint(x: 1, y: 1)),
                              (["mini": true, "enabled": false], CGPoint(x: 1, y: 1))]
            as [([String: JSONValue], CGPoint)] {
            let hosted = try Host(try page(behind(fab("f", "i", props)) + [icon("i")]))
            defer { hosted.close() }
            hosted.assertTaken(CGPoint(x: 24, y: 24))
            hosted.assertTaken(edge)
            hosted.assertPassed(CGPoint(x: 62, y: 20))
        }
    }
    #endif

    // MARK: pages

    static let keys = ["onTap", "onLongPress"]

    /// A page of `nodes` (the first is the root) whose registry draws
    /// IconButton and FloatingActionButton; page state `onTap` and
    /// `onLongPress`, 0.
    func page(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let state: [JSONValue] = Self.keys.map { ["key": .string($0), "scope": "page", "initial": 0] }
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(state), "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: response, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["IconButton", "FloatingActionButton"])))
    }

    /// `setState(key, key + 1)` in page scope, as the counter page's increment.
    func count(_ key: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": [
            "type": "transform", "input": ["type": "state", "key": .string(key), "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]
    }

    /// A button of `type` around `child`, each trigger in `on` counting itself.
    func button(_ type: String, _ id: String, _ child: String?, _ props: [String: JSONValue],
                on: [String]) -> JSONValue {
        var node: [String: JSONValue] = [
            "id": .string(id), "type": .string(type), "kind": "button", "childMode": "single",
            "props": .object(props), "children": .array(child.map { [.string($0)] } ?? []), "watches": [],
        ]
        if !on.isEmpty {
            node["actions"] = .object(Dictionary(uniqueKeysWithValues: on.map { ($0, count($0)) }))
        }
        return .object(node)
    }

    func iconButton(_ id: String, _ child: String?, _ props: [String: JSONValue] = [:],
                    on: [String] = []) -> JSONValue {
        button("IconButton", id, child, props, on: on)
    }

    func fab(_ id: String, _ child: String?, _ props: [String: JSONValue] = [:], on: [String] = []) -> JSONValue {
        button("FloatingActionButton", id, child, props, on: on)
    }

    /// An Icon with no name: the fallback filled circle, solid at its centre.
    func icon(_ id: String, _ props: [String: JSONValue] = [:]) -> JSONValue {
        ["id": .string(id), "type": "Icon", "kind": "primitive", "childMode": "none", "props": .object(props),
         "children": [], "watches": []]
    }

    /// A solid `hex` Container, `side` square.
    func box(_ id: String, _ hex: String, _ side: Double) -> JSONValue {
        ["id": .string(id), "type": "Container", "kind": "layout", "childMode": "single",
         "props": ["color": .string(hex), "width": .double(side), "height": .double(side)], "children": [],
         "watches": []]
    }

    /// A Column, its children at the start.
    func column(_ id: String, _ children: [String]) -> JSONValue {
        ["id": .string(id), "type": "Column", "kind": "layout", "childMode": "multi",
         "props": ["crossAxisAlignment": "start"], "children": .array(children.map(JSONValue.string)), "watches": []]
    }

    /// A Scaffold, its slot props holding the ids of nodes listed as its children.
    func scaffold(_ id: String, _ slots: [String: String]) -> JSONValue {
        ["id": .string(id), "type": "Scaffold", "kind": "structure", "childMode": "none",
         "props": .object(slots.mapValues(JSONValue.string)),
         "children": .array(slots.values.sorted().map(JSONValue.string)), "watches": []]
    }

    /// A Stack: text fields behind (the probes), `front` over them at the
    /// top left (CheckboxRadioTests).
    func behind(_ front: JSONValue) -> [JSONValue] {
        CheckboxRadioTests().behind(front)
    }

    func iconButtonView(_ model: OrcaPageModel, _ id: String) throws -> IconButtonNodeView {
        IconButtonNodeView(node: try XCTUnwrap(model.resolve(id), "no node \(id)"), model: model)
    }

    func fabView(_ model: OrcaPageModel, _ id: String) throws -> FloatingActionButtonNodeView {
        FloatingActionButtonNodeView(node: try XCTUnwrap(model.resolve(id), "no node \(id)"), model: model)
    }

    /// How many times each counter fired.
    func fired(_ model: OrcaPageModel) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: Self.keys.map { ($0, model.store.value($0).doubleValue.map { Int($0) } ?? -1) })
    }

    func counts(tap: Int = 0, longPress: Int = 0) -> [String: Int] {
        ["onTap": tap, "onLongPress": longPress]
    }

    // MARK: pixels

    static let red: (Int, Int, Int) = (0xE5, 0x39, 0x35)
    static let blue: (Int, Int, Int) = (0x1E, 0x88, 0xE5)
    /// Material 3's light primaryContainer and onPrimaryContainer, ThemeData()'s FAB colours.
    static let fabFill: (Int, Int, Int) = (0xEA, 0xDD, 0xFF)
    static let fabContent: (Int, Int, Int) = (0x4F, 0x37, 0x8B)

    /// `channel` at opacity 0.38 over white.
    static func fade(_ channel: Int) -> Int {
        Int((0.38 * Double(channel) + 0.62 * 255).rounded())
    }

    /// Node `id` drawn at the top left of a light `width` x `height` white
    /// picture at scale 1.
    func draw(_ model: OrcaPageModel, _ id: String, width: CGFloat = 100, height: CGFloat = 100,
              direction: LayoutDirection = .leftToRight) throws -> Pixels {
        let renderer = ImageRenderer(content: NodeView(id: id, model: model)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Color.white)
            .environment(\.layoutDirection, direction)
            .environment(\.colorScheme, .light))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "\(id) not drawn"))
    }

    static func assertColour(_ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (Int, Int, Int),
                             _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let pairs = [(Int(actual.r), expected.0), (Int(actual.g), expected.1), (Int(actual.b), expected.2)]
        if pairs.contains(where: { abs($0.0 - $0.1) > 8 }) {
            XCTFail("\(message): \(actual) vs \(expected)", file: file, line: line)
        }
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, _ message: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected): \(message)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected): \(message)",
                           file: file, line: line)
        }
    }

    #if canImport(UIKit)
    typealias Host = CheckboxRadioTests.Host
    #endif
}

#endif
