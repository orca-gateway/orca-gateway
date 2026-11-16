#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A6.3 and A6.7 for Switch and Slider: Flutter's builders
/// (input_builders.dart:246-348) bound as they bind (design D4), drawn with
/// SwiftUI's Toggle and Slider (D6). What is drawn comes from the store at
/// `stateKey` or from the `value` prop, read when the view is built; a node
/// redraws only through its watches; a change goes through `valueChanged`
/// (page-scope write, then onChange). On iOS the Toggle is a UISwitch and the
/// Slider a UISlider, which SwiftUI runs over 0-1 (the fraction of the
/// track): a test moves the control as a finger would, then performs its
/// target actions, since `sendActions` sends nothing in package tests
/// (RefreshTests). The registry is widened by the two types (advertised
/// only in group 8). The footprints run on macOS too.
@MainActor
final class SwitchSliderTests: XCTestCase {
    static let accuracy: CGFloat = 1.5

    // MARK: A6.3 footprints

    /// A6.3: a Switch takes the room of Flutter's padded M3 Switch, 60 x 48
    /// (52 wide and 40 + 8 high, with 4 of padding left and right,
    /// switch.dart:583-585, switch_defaults_m3.g.dart:140, :195-201, :228);
    /// a Slider the width it is given and Flutter's 48 (slider.dart:1796-1804).
    func testA6_3TheSwitchAndTheSliderTakeFlutterFootprints() throws {
        let model = try page([control("s", "Switch", [:]), control("l", "Slider", [:])])
        let frames = NativeWidgetTests().layout(width: 300, height: 200) {
            VStack(alignment: .leading, spacing: 0) {
                NodeView(id: "s", model: model).record("s")
                NodeView(id: "l", model: model).record("l")
            }
        }
        assertFrame(frames["s"], CGRect(x: 0, y: 0, width: 60, height: 48), "the switch")
        assertFrame(frames["l"], CGRect(x: 0, y: 48, width: 300, height: 48), "the slider")
    }

    #if canImport(UIKit)
    // MARK: A6.3 Switch (a hosted window)

    /// A6.3: the Toggle is a UISwitch, iOS's 51 x 31, in the middle of its
    /// 60 x 48; on, its track (the on tint) is activeColor at alpha 0x80,
    /// Flutter's checked track (switch.dart:950-957).
    func testA6_3TheSwitchIsAUISwitchOnActiveColorAtHalfAlpha() throws {
        let hosted = try host([control("s", "Switch", ["value": true, "activeColor": "#FF0000"])])
        defer { hosted.close() }
        let toggle = try uiSwitch(hosted)
        XCTAssertTrue(toggle.isOn)
        let track = CGRect(x: 4.5, y: 8.5, width: 51, height: 31)
        assertFrame(toggle.convert(toggle.bounds, to: hosted.window), track, "the UISwitch")
        assertFrame(try hosted.pixels().bounds(of: Pixels.isRed), track, "the red track")

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let tint = try XCTUnwrap(toggle.onTintColor, "no on tint")
        XCTAssertTrue(tint.getRed(&red, green: &green, blue: &blue, alpha: &alpha), "\(tint)")
        for (actual, expected, name) in [(red, 1, "red"), (green, 0, "green"), (blue, 0, "blue"),
                                         (alpha, 0x80 / 255, "alpha")] as [(CGFloat, CGFloat, String)] {
            XCTAssertEqual(actual, expected, accuracy: 0.01, "the on tint's \(name): \(tint)")
        }
    }

    /// A6.3: a tap writes the other bool to the key in page scope, then
    /// fires onChange with it (onChange reads the key back), and a Text
    /// watching the key redraws, the switch too. Both bindings: stateKey,
    /// and the demo's value V.pageState with onChange SetState.
    func testA6_3ATapOnTheSwitchWritesThenFiresAndAWatchingTextRedraws() throws {
        for byStateKey in [true, false] {
            var props: [String: JSONValue] = ["value": state("on")]
            if byStateKey { props["stateKey"] = "on" }
            let hosted = try host([
                column(["s", "t"]),
                control("s", "Switch", props, watches: ["on"],
                        onChange: byStateKey ? echo("on") : write("on") + echo("on")),
                text("t", state("on"), watches: ["on"]),
            ], state: ["on": false])
            defer { hosted.close() }
            let label = "stateKey \(byStateKey)"
            XCTAssertEqual(try textWidth(hosted), try inkWidth("false"), accuracy: 1, "\(label): the Text before")

            Self.tap(try uiSwitch(hosted))
            Self.settle(hosted) { hosted.model.store.value("fired") == 1 }

            XCTAssertEqual(hosted.model.store.state.page["on"], true, "\(label): the key")
            XCTAssertNil(hosted.model.store.state.app["on"], "\(label): the write left page scope")
            XCTAssertEqual(hosted.model.store.value("seen"), true, "\(label): onChange ran before the write")
            XCTAssertEqual(hosted.model.store.value("echo"), true, "\(label): onChange's value")
            XCTAssertEqual(try textWidth(hosted), try inkWidth("true"), accuracy: 1, "\(label): the Text not redrawn")
            XCTAssertTrue(try uiSwitch(hosted).isOn, "\(label): the switch not redrawn")
        }
    }

    /// A6.3 (D4): bound by stateKey alone, with nothing watching the key,
    /// the write lands and nothing redraws, as in Flutter: the UISwitch the
    /// finger moved is put back at the value drawn, and the next tap sends
    /// the other of that value, true, again (Flutter's `!value`).
    func testA6_3ASwitchNotWatchingItsKeyIsPutBackAtTheValueDrawn() throws {
        let hosted = try host([control("s", "Switch", ["stateKey": "on"], onChange: echo("on"))], state: ["on": false])
        defer { hosted.close() }
        for tap in 1...2 {
            Self.tap(try uiSwitch(hosted))
            Self.settle(hosted) { hosted.model.store.value("fired") == .int(tap) }
            XCTAssertEqual(hosted.model.store.value("on"), true, "tap \(tap): the key")
            XCTAssertEqual(hosted.model.store.value("echo"), true, "tap \(tap): onChange's value")
            XCTAssertFalse(try uiSwitch(hosted).isOn, "tap \(tap): the switch stayed where the finger put it")
        }
    }

    // MARK: A6.3 Slider (a hosted window)

    /// A6.3: a drag on a Slider of 0-100 in 4 divisions sends the stop
    /// nearest the finger (Flutter's `_lerp`, FormControls.sliderValue), 50
    /// for 60 % of the track, as a double: the key is written in page scope,
    /// then onChange fires with it, and a Text watching the key redraws, the
    /// thumb too. Both bindings.
    func testA6_3ADragOnTheSliderSnapsWritesThenFiresAndAWatchingTextRedraws() throws {
        for byStateKey in [true, false] {
            var props: [String: JSONValue] = ["value": state("level"), "min": 0, "max": 100, "divisions": 4]
            if byStateKey { props["stateKey"] = "level" }
            let hosted = try host([
                column(["l", "t"]),
                control("l", "Slider", props, watches: ["level"],
                        onChange: byStateKey ? echo("level") : write("level") + echo("level")),
                text("t", state("level"), watches: ["level"]),
            ], state: ["level": 0])
            defer { hosted.close() }
            let label = "stateKey \(byStateKey)"
            XCTAssertEqual(try uiSlider(hosted).value, 0, "\(label): the thumb before")

            Self.drag(try uiSlider(hosted), to: 0.6)
            Self.settle(hosted) { hosted.model.store.value("fired") == 1 }

            XCTAssertEqual(hosted.model.store.state.page["level"], 50, "\(label): the key")
            XCTAssertNil(hosted.model.store.state.app["level"], "\(label): the write left page scope")
            XCTAssertEqual(hosted.model.store.value("seen"), 50, "\(label): onChange ran before the write")
            guard case .double(50) = hosted.model.store.value("echo") else {
                return XCTFail("\(label): onChange's value is \(hosted.model.store.value("echo")), not the double 50")
            }
            XCTAssertEqual(try textWidth(hosted), try inkWidth("50.0"), accuracy: 1, "\(label): the Text not redrawn")
            XCTAssertEqual(try uiSlider(hosted).value, 0.5, "\(label): the thumb not redrawn")
        }
    }

    /// A6.3: the value is drawn clamped to min-max and the state is left as
    /// it is (input_builders.dart:312); with divisions the thumb sits on the
    /// nearest stop (Flutter's `_convert`); without min and max the track
    /// runs 0-1, the thumb at 0 without a value; a reversed range draws min.
    /// The thumb as the fraction of the track.
    func testA6_3TheSliderDrawsItsValueClamped() throws {
        let cases: [([String: JSONValue], JSONValue, Float)] = [
            (["stateKey": "level", "min": 0, "max": 100], 150, 1),
            (["stateKey": "level", "min": 0, "max": 100], -5, 0),
            (["stateKey": "level", "min": 0, "max": 100], 40, 0.4),
            (["stateKey": "level", "max": 100, "divisions": 4], 30, 0.25),
            ([:], 7, 0),
            (["value": 0.5], 7, 0.5),
            (["min": 10, "max": 0, "value": 5], 7, 0),
        ]
        for (props, level, drawn) in cases {
            let hosted = try host([control("l", "Slider", props)], state: ["level": level])
            defer { hosted.close() }
            XCTAssertEqual(try uiSlider(hosted).value, drawn, accuracy: 0.001, "\(props) at \(level): the thumb")
            XCTAssertEqual(hosted.model.store.value("level"), level, "\(props): the state was corrected")
        }
    }

    /// A6.3: a value is sent once in a drag (Flutter's `_handleChanged`,
    /// slider.dart:752-760). Bound by stateKey with nothing watching it, the
    /// slider stays built at 0: 60 % of the track sends 50, 55 % nothing (50
    /// again), 70 % sends 75; once the finger lifts, 70 % sends 75 again; a
    /// drag onto the value drawn (5 %, the stop 0) sends nothing. With no
    /// redraw the UISlider is put back at 0 each time.
    func testA6_3ASliderSendsAValueOnceADrag() throws {
        let hosted = try host([control("l", "Slider", ["stateKey": "level", "max": 100, "divisions": 4],
                                       onChange: echo("level"))], state: ["level": 0])
        defer { hosted.close() }
        let slider = try uiSlider(hosted)
        for (to, fired, sent) in [(0.6, 1, 50), (0.55, 1, 50), (0.7, 2, 75), (nil, 2, 75), (0.7, 3, 75), (nil, 3, 75),
                                  (0.05, 3, 75)] as [(Float?, Int, Int)] {
            if let to {
                Self.drag(slider, to: to)
            } else {
                Self.release(slider)
            }
            Self.settle(hosted) { hosted.model.store.value("fired") == .int(fired) }
            hosted.pump(0.3)
            let step = to.map { "after \($0)" } ?? "after lifting"
            XCTAssertEqual(hosted.model.store.value("fired"), .int(fired), step)
            XCTAssertEqual(hosted.model.store.value("echo"), .int(sent), step)
            XCTAssertEqual(slider.value, 0, "\(step): the thumb stayed where the finger put it")
        }
    }

    /// A6.3: what was sent in a drag outlives a redraw, as Flutter's
    /// `_currentChangedValue` lives in the slider's State
    /// (slider.dart:752-760). The node watches its key but onChange writes
    /// elsewhere: 60 % of the track sends 50; the key then moves to 25 from
    /// elsewhere and the slider redraws there; 55 % (50 again) sends nothing;
    /// 70 % sends 75.
    func testA6_3ASliderKeepsWhatItSentThroughARedrawMidDrag() throws {
        let hosted = try host([control("l", "Slider", ["value": state("level"), "max": 100, "divisions": 4],
                                       watches: ["level"], onChange: echo("level"))], state: ["level": 0])
        defer { hosted.close() }
        Self.drag(try uiSlider(hosted), to: 0.6)
        Self.settle(hosted) { hosted.model.store.value("fired") == 1 }
        XCTAssertEqual(hosted.model.store.value("echo"), 50)

        hosted.model.store.dispatch(["level": 25])
        Self.settle(hosted) { Self.find(UISlider.self, in: hosted.window)?.value == 0.25 }
        XCTAssertEqual(try uiSlider(hosted).value, 0.25, "not redrawn at 25")

        Self.drag(try uiSlider(hosted), to: 0.55)
        hosted.pump(0.6)
        XCTAssertEqual(hosted.model.store.value("fired"), 1, "50, sent before the redraw, was sent again")

        Self.drag(try uiSlider(hosted), to: 0.7)
        Self.settle(hosted) { hosted.model.store.value("fired") == 2 }
        XCTAssertEqual(hosted.model.store.value("fired"), 2)
        XCTAssertEqual(hosted.model.store.value("echo"), 75)
    }

    // MARK: A6.7 enabled false, no onChange

    /// A6.7: enabled false disables the UISwitch and the UISlider (greyed by
    /// the system, as Flutter's null onChanged greys them) and makes them
    /// inert: their actions, performed anyway, write and fire nothing.
    func testA6_7DisabledSwitchAndSliderAreGreyedAndInert() throws {
        let hosted = try host([
            column(["s", "l"]),
            control("s", "Switch", ["stateKey": "on", "enabled": false], onChange: echo("on")),
            control("l", "Slider", ["stateKey": "level", "max": 100, "enabled": false], onChange: echo("level")),
        ], state: ["on": false, "level": 0])
        defer { hosted.close() }
        let toggle = try uiSwitch(hosted), slider = try uiSlider(hosted)
        XCTAssertFalse(toggle.isEnabled, "the switch is enabled")
        XCTAssertFalse(slider.isEnabled, "the slider is enabled")

        Self.tap(toggle)
        Self.drag(slider, to: 0.6)
        hosted.pump(0.5)
        XCTAssertEqual(hosted.model.store.value("on"), false)
        XCTAssertEqual(hosted.model.store.value("level"), 0)
        XCTAssertEqual(hosted.model.store.value("fired"), 0)
    }

    /// A6.7: without an onChange both still take touches (Flutter's
    /// onChanged is set whenever enabled, input_builders.dart:280, :320):
    /// the stateKey is written and nothing fires.
    func testA6_7WithoutOnChangeSwitchAndSliderStillWriteTheStateKey() throws {
        let hosted = try host([
            column(["s", "l"]),
            control("s", "Switch", ["stateKey": "on"]),
            control("l", "Slider", ["stateKey": "level", "max": 100]),
        ], state: ["on": false, "level": 0])
        defer { hosted.close() }
        let toggle = try uiSwitch(hosted), slider = try uiSlider(hosted)
        XCTAssertTrue(toggle.isEnabled)
        XCTAssertTrue(slider.isEnabled)

        Self.tap(toggle)
        Self.drag(slider, to: 0.6)
        Self.settle(hosted) { hosted.model.store.value("on") == true && hosted.model.store.value("level") != 0 }
        XCTAssertEqual(hosted.model.store.state.page["on"], true)
        XCTAssertEqual(hosted.model.store.state.page["level"]?.doubleValue ?? 0, 60, accuracy: 0.001)
        XCTAssertEqual(hosted.model.store.value("echo"), "unset")
        XCTAssertEqual(hosted.model.store.value("fired"), 0)
    }

    // MARK: hosted controls

    typealias Host = CheckboxRadioTests.Host

    func host(_ nodes: [JSONValue], state: [String: JSONValue] = [:]) throws -> Host {
        try Host(try page(nodes, state: state))
    }

    func uiSwitch(_ hosted: Host) throws -> UISwitch {
        try XCTUnwrap(Self.find(UISwitch.self, in: hosted.window), "no UISwitch")
    }

    func uiSlider(_ hosted: Host) throws -> UISlider {
        try XCTUnwrap(Self.find(UISlider.self, in: hosted.window), "no UISlider")
    }

    static func find<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let found = view as? T { return found }
        for child in view.subviews {
            if let found = find(type, in: child) { return found }
        }
        return nil
    }

    /// A finger's tap: the switch flips, then its valueChanged actions run.
    static func tap(_ control: UISwitch) {
        control.setOn(!control.isOn, animated: false)
        perform(.valueChanged, on: control)
    }

    /// A finger dragging the thumb to `fraction` of the track: it moves
    /// there, then the slider's valueChanged actions run.
    static func drag(_ slider: UISlider, to fraction: Float) {
        slider.value = fraction
        perform(.valueChanged, on: slider)
    }

    /// The finger lifting off the slider.
    static func release(_ slider: UISlider) {
        perform(.touchUpInside, on: slider)
    }

    /// `control`'s actions for `event`, performed on their targets
    /// (`sendActions(for:)` sends nothing without a UIApplication).
    static func perform(_ event: UIControl.Event, on control: UIControl) {
        for target in control.allTargets {
            for action in control.actions(forTarget: target, forControlEvent: event) ?? [] {
                _ = (target as AnyObject).perform(NSSelectorFromString(action), with: control)
            }
        }
    }

    /// Runs the main loop until `done` (5 s at most: a change runs on a
    /// task), then a little more for the redraw.
    static func settle(_ hosted: Host, until done: () -> Bool) {
        let end = Date().addingTimeInterval(5)
        while !done(), Date() < end { hosted.pump(0.05) }
        hosted.pump(0.3)
    }

    /// The width of the red ink in the window: the Text.
    func textWidth(_ hosted: Host) throws -> CGFloat {
        try XCTUnwrap(try hosted.pixels().bounds(of: Pixels.isRed), "no Text").width
    }

    /// The width of `data` drawn alone in the Text's style.
    func inkWidth(_ data: String) throws -> CGFloat {
        let hosted = try host([text("t", .string(data))])
        defer { hosted.close() }
        return try textWidth(hosted)
    }
    #endif

    // MARK: pages

    /// A page of `nodes` (the first is the root) whose registry draws Switch
    /// and Slider; page `state` as given, plus `seen` and `echo` "unset" and
    /// `fired` 0.
    func page(_ nodes: [JSONValue], state: [String: JSONValue] = [:]) throws -> OrcaPageModel {
        var definitions: [JSONValue] = [["key": "seen", "scope": "page", "initial": "unset"],
                                        ["key": "echo", "scope": "page", "initial": "unset"],
                                        ["key": "fired", "scope": "page", "initial": 0]]
        for (key, value) in state.sorted(by: { $0.key < $1.key }) {
            definitions.append(["key": .string(key), "scope": "page", "initial": value])
        }
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(definitions), "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: response, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["Switch", "Slider"])))
    }

    func control(_ id: String, _ type: String, _ props: [String: JSONValue], watches: [String] = [],
                 onChange: [JSONValue] = []) -> JSONValue {
        var node: [String: JSONValue] = [
            "id": .string(id), "type": .string(type), "kind": "input", "childMode": "none",
            "props": .object(props), "children": [], "watches": .array(watches.map(JSONValue.string)),
        ]
        if !onChange.isEmpty {
            node["actions"] = ["onChange": ["type": "actionGroup", "mode": "sequential", "actions": .array(onChange)]]
        }
        return .object(node)
    }

    /// A Column with its children at the start.
    func column(_ children: [String]) -> JSONValue {
        ["id": "col", "type": "Column", "kind": "layout", "childMode": "multi",
         "props": ["crossAxisAlignment": "start"], "children": .array(children.map(JSONValue.string)), "watches": []]
    }

    /// A red 20 pt Text showing `data`.
    func text(_ id: String, _ data: JSONValue, watches: [String] = []) -> JSONValue {
        ["id": .string(id), "type": "Text", "kind": "primitive", "childMode": "none",
         "props": ["data": data, "style": ["color": "#FF0000", "fontSize": 20]], "children": [],
         "watches": .array(watches.map(JSONValue.string))]
    }

    /// A page-state Value of `key`.
    func state(_ key: String) -> JSONValue {
        ["type": "state", "key": .string(key), "scope": "page"]
    }

    /// onChange: copy `key` to `seen` (what the key holds when onChange
    /// runs), the event's value to `echo`, and add 1 to `fired`.
    func echo(_ key: String) -> [JSONValue] {
        [["type": "setState", "key": "seen", "value": state(key)],
         ["type": "setState", "key": "echo", "value": ["type": "event", "key": "value"]],
         ["type": "setState", "key": "fired", "value": [
             "type": "transform", "input": state("fired"),
             "by": [["type": "add", "by": ["type": "static", "value": 1]]],
         ]]]
    }

    /// The demo's binding: SetState(key, V.event('value')).
    func write(_ key: String) -> [JSONValue] {
        [["type": "setState", "key": .string(key), "scope": "page", "value": ["type": "event", "key": "value"]]]
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
}
#endif
