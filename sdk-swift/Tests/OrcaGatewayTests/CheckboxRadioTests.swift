#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A6.1, A6.2 and A6.7 for Checkbox and Radio: Flutter's builders
/// (input_builders.dart:139-244) bound as they bind (design D4). What is drawn
/// comes from the store at `stateKey` or from the `value` prop, never from
/// state of the view's own, and a node redraws only through its watches; a
/// change goes through `valueChanged` (page-scope write, then onChange). The
/// registry is widened by the two types (advertised only in group 8). Swift
/// cannot inject a tap (TouchTests): a tap runs the view's own action, and
/// what takes touches is found by hit tests over text fields behind, in a
/// hosted window (iOS). The footprints and the cycles run on macOS too.
@MainActor
final class CheckboxRadioTests: XCTestCase {
    static let accuracy: CGFloat = 1.5

    // MARK: A6.1 Checkbox

    /// A6.1: a bare Checkbox is Flutter's padded tap target, 48 x 48
    /// (checkbox.dart:551-556); a labelled one is CheckboxListTile's
    /// one-line row, the whole width and 56 high (list_tile.dart:1505).
    func testA6_1TheCheckboxTakesFlutterFootprint() throws {
        for (props, size) in [([:], CGSize(width: 48, height: 48)),
                              (["label": "Agree"], CGSize(width: 300, height: 56))] as [([String: JSONValue], CGSize)] {
            let model = try page([checkbox("c", props)])
            let frames = NativeWidgetTests().layout(width: 300, height: 200) {
                NodeView(id: "c", model: model).record("c")
            }
            let frame = try XCTUnwrap(frames["c"], "\(props): not laid out")
            XCTAssertEqual(frame.width, size.width, accuracy: 0.5, "\(props): \(frame)")
            XCTAssertEqual(frame.height, size.height, accuracy: 0.5, "\(props): \(frame)")
        }
    }

    /// A6.1: a tristate Checkbox cycles false → true → null → false
    /// (toggleable.dart:247-252); each value is written to the stateKey and
    /// sent as onChange's (null too), and drawn as an empty square, a ticked
    /// one and a dashed one.
    func testA6_1ATristateCheckboxCyclesThroughNull() async throws {
        let model = try page([checkbox("c", ["stateKey": "done", "tristate": true, "value": state("done")],
                                       watches: ["done"], onChange: echo)], state: ["done": false])
        XCTAssertEqual(try view(model, "c").symbol, "square")
        for (next, symbol) in [(JSONValue.bool(true), "checkmark.square.fill"), (.null, "minus.square.fill"),
                               (.bool(false), "square")] {
            let tap = try view(model, "c").tap()
            XCTAssertNotNil(tap, "\(next): the tap did nothing")
            await tap?.value
            XCTAssertEqual(model.store.state.page["done"], next, "the stateKey")
            XCTAssertEqual(model.store.value("echo"), next, "onChange's value")
            XCTAssertEqual(try view(model, "c").symbol, symbol, "drawn after \(next)")
        }
    }

    /// A6.1: a two-state Checkbox draws a missing value as false
    /// (input_builders.dart:224), so its first tap ticks it; a state that is
    /// not a bool (Flutter throws) draws the `value` prop instead (D4).
    func testA6_1ATwoStateCheckboxDrawsAMissingValueAsFalse() async throws {
        let model = try page([
            checkbox("unset", ["stateKey": "none"], onChange: echo),
            checkbox("word", ["stateKey": "word", "value": true]),
        ], state: ["word": "yes"])
        XCTAssertEqual(try view(model, "unset").symbol, "square")
        try await view(model, "unset").tap()?.value
        XCTAssertEqual(model.store.state.page["none"], true)
        XCTAssertEqual(model.store.value("echo"), true)

        XCTAssertEqual(try view(model, "word").shown, true, "a string state: the prop is drawn")
        XCTAssertEqual(try view(model, "word").symbol, "checkmark.square.fill")
    }

    /// A6.1: a tap starts from the value the box was built with, not from
    /// the store at tap time (Toggleable sends the next of its built value,
    /// input_builders.dart:224, :236). Bound by stateKey with nothing
    /// watching the key, the box is not rebuilt, so every tap on it writes
    /// and sends true again.
    func testA6_1ATapStartsFromTheValueTheBoxWasBuiltWith() async throws {
        let model = try page([checkbox("c", ["stateKey": "done"], onChange: echo)], state: ["done": false])
        let built = try view(model, "c")
        for tap in 1...2 {
            model.store.dispatch(["echo": "unset"])
            let change = built.tap()
            XCTAssertNotNil(change, "tap \(tap) did nothing")
            await change?.value
            XCTAssertEqual(model.store.state.page["done"], true, "tap \(tap): the stateKey")
            XCTAssertEqual(model.store.value("echo"), true, "tap \(tap): onChange's value")
        }
    }

    // MARK: A6.2 Radio

    /// A6.2: a Radio's tap is decided by the selection it was built with
    /// (its onTap exists only when built enabled and unselected,
    /// input_builders.dart:153). Not watching its key, one built unselected
    /// fires on every tap; one built selected does nothing, even once the
    /// store has moved the group elsewhere.
    func testA6_2ATapIsDecidedByTheSelectionTheRadioWasBuiltWith() async throws {
        let model = try page([radio("a", ["stateKey": "pick", "value": "a"], onChange: echo),
                              radio("b", ["stateKey": "pick", "value": "b"], onChange: echo)], state: ["pick": "a"])
        let a = try radioView(model, "a"), b = try radioView(model, "b")
        for tap in 1...2 {
            model.store.dispatch(["echo": "unset"])
            let change = b.tap()
            XCTAssertNotNil(change, "tap \(tap) on b, built unselected, did nothing")
            await change?.value
            XCTAssertEqual(model.store.state.page["pick"], "b", "tap \(tap): the stateKey")
            XCTAssertEqual(model.store.value("echo"), "b", "tap \(tap): onChange's value")
        }

        model.store.dispatch(["pick": "c", "echo": "unset"])
        XCTAssertNil(a.tap(), "a, built selected, took a tap")
        XCTAssertEqual(model.store.state.page["pick"], "c")
        XCTAssertEqual(model.store.value("echo"), "unset")
    }

    /// A6.2: three Radios on one group, bound as the demo binds them
    /// (groupValue V.pageState, onChange SetState of the key): exactly the
    /// one whose value is the group's is selected (input_builders.dart:148);
    /// a tap on another selects it alone and sends its value; a tap on the
    /// selected one does nothing (:153).
    func testA6_2ExactlyOneRadioOfAGroupIsSelected() async throws {
        let model = try page(radios(), state: ["pick": "b"])
        XCTAssertEqual(try selected(model), ["b"])

        let tap = try radioView(model, "c").tap()
        XCTAssertNotNil(tap, "an unselected radio took no tap")
        await tap?.value
        XCTAssertEqual(model.store.value("pick"), "c")
        XCTAssertEqual(model.store.value("echo"), "c", "onChange's value is the radio's string")
        XCTAssertEqual(try selected(model), ["c"])

        XCTAssertNil(try radioView(model, "c").tap(), "the selected radio took a tap")
        XCTAssertEqual(model.store.value("echo"), "c")
    }

    /// A6.2: bound by stateKey, the group is the state at the key as a string
    /// (input_builders.dart:143-145): a tap writes the radio's value there in
    /// page scope.
    func testA6_2ARadioBoundByStateKeyWritesItsValue() async throws {
        let model = try page([radio("a", ["stateKey": "pick", "value": "a"]),
                              radio("b", ["stateKey": "pick", "value": "b"])], state: ["pick": "a"])
        XCTAssertEqual(try selected(model, ["a", "b"]), ["a"])
        try await radioView(model, "b").tap()?.value
        XCTAssertEqual(model.store.state.page["pick"], "b")
        XCTAssertEqual(try selected(model, ["a", "b"]), ["b"])
    }

    // MARK: A6.7 enabled false, no onChange

    /// A6.7: enabled false makes both inert (Flutter's onChanged and onTap
    /// are null, input_builders.dart:153, :229, :240): no tap writes or
    /// fires anything, selected or not.
    func testA6_7DisabledCheckboxAndRadioAreInert() throws {
        let model = try page([
            checkbox("c", ["stateKey": "done", "enabled": false], onChange: echo),
            checkbox("l", ["stateKey": "done", "label": "Locked", "enabled": false], onChange: echo),
            radio("a", ["stateKey": "pick", "value": "a", "enabled": false]),
            radio("b", ["stateKey": "pick", "value": "b", "enabled": false]),
        ], state: ["pick": "a", "done": false])
        XCTAssertNil(try view(model, "c").tap())
        XCTAssertNil(try view(model, "l").tap())
        XCTAssertNil(try radioView(model, "a").tap())
        XCTAssertNil(try radioView(model, "b").tap())
        XCTAssertEqual(model.store.value("done"), false)
        XCTAssertEqual(model.store.value("pick"), "a")
        XCTAssertEqual(model.store.value("echo"), "unset")
    }

    /// A6.7: without an onChange both still take a tap: the stateKey write
    /// happens and nothing fires (input_builders.dart:208-218, :155-162).
    func testA6_7WithoutOnChangeATapStillWritesTheStateKey() async throws {
        let model = try page([checkbox("c", ["stateKey": "done"]), radio("b", ["stateKey": "pick", "value": "b"])],
                             state: ["pick": "a", "done": false])
        try await view(model, "c").tap()?.value
        try await radioView(model, "b").tap()?.value
        XCTAssertEqual(model.store.state.page["done"], true)
        XCTAssertEqual(model.store.state.page["pick"], "b")
        XCTAssertEqual(model.store.value("echo"), "unset")
    }

    #if canImport(UIKit)
    // MARK: drawn (a hosted window)

    /// A6.1: a tap ticks the box: the next value is written in page scope,
    /// then onChange runs (it reads the key back) with {value: true}, and the
    /// box redraws filled in activeColor, 18 pt in the middle of its 48 pt
    /// target, because the node watches the key. Both bindings: stateKey
    /// with value V.pageState, and the demo's value V.pageState with
    /// onChange SetState.
    func testA6_1ATapTicksTheBoxWhenTheNodeWatchesTheKey() async throws {
        for byStateKey in [true, false] {
            var props: [String: JSONValue] = ["value": state("done"), "activeColor": "#FF0000"]
            if byStateKey { props["stateKey"] = "done" }
            let hosted = try Host(try page([checkbox("c", props, watches: ["done"],
                                                       onChange: byStateKey ? echo : write("done") + echo)],
                                             state: ["done": false]))
            defer { hosted.close() }
            XCTAssertNil(try hosted.pixels().bounds(of: Pixels.isRed), "stateKey \(byStateKey): ticked before the tap")

            try await view(hosted.model, "c").tap()?.value
            hosted.pump()

            assertFrame(try hosted.pixels().bounds(of: Pixels.isRed), CGRect(x: 15, y: 15, width: 18, height: 18),
                        "stateKey \(byStateKey): the tick")
            XCTAssertEqual(hosted.model.store.state.page["done"], true)
            XCTAssertNil(hosted.model.store.state.app["done"], "the write left page scope")
            XCTAssertEqual(hosted.model.store.value("seen"), true, "onChange ran before the write")
            XCTAssertEqual(hosted.model.store.value("echo"), true, "onChange's value")
        }
    }

    /// A6.1 (D4): bound by stateKey alone, with nothing watching the key,
    /// the write lands but the box is not redrawn, as in Flutter (no
    /// WatchBuilder, component_renderer.dart:63-79): no state of the view's
    /// own flips it.
    func testA6_1ABoxNotWatchingItsKeyIsNotRedrawn() async throws {
        let hosted = try Host(try page([checkbox("c", ["stateKey": "done", "activeColor": "#FF0000"])],
                                         state: ["done": false]))
        defer { hosted.close() }
        try await view(hosted.model, "c").tap()?.value
        hosted.pump()
        XCTAssertEqual(hosted.model.store.value("done"), true)
        XCTAssertNil(try hosted.pixels().bounds(of: Pixels.isRed), "redrawn without a watch")
    }

    /// A6.1: CheckboxListTile's row takes touches across its whole width and
    /// height (list_tile.dart's InkWell): the box sits leading, 16 in plus
    /// half of its 40 pt target, and the title right of it; below the row a
    /// field behind takes the touch. A bare Checkbox takes them on its 48 pt
    /// target, not only on its box.
    func testA6_1TheLabelledRowTakesTapsAnywhere() throws {
        let labelled = try Host(try page(behind(checkbox("c", ["label": "WWWW", "activeColor": "#FF0000",
                                                                 "value": true]))))
        defer { labelled.close() }
        for x in [4, 36, 100, 296] as [CGFloat] {
            for y in [4, 28, 52] as [CGFloat] {
                labelled.assertTaken(CGPoint(x: x, y: y))
            }
        }
        labelled.assertPassed(CGPoint(x: 150, y: 70))
        assertFrame(try labelled.pixels().bounds(of: Pixels.isRed), CGRect(x: 27, y: 19, width: 18, height: 18),
                    "the leading box")
        XCTAssertNotNil(try labelled.pixels().bounds(of: Pixels.isInk), "no title")

        let bare = try Host(try page(behind(checkbox("c", [:]))))
        defer { bare.close() }
        bare.assertTaken(CGPoint(x: 3, y: 3))
        bare.assertTaken(CGPoint(x: 45, y: 45))
        bare.assertPassed(CGPoint(x: 60, y: 24))
    }

    /// A6.2: Flutter's own Radio (input_builders.dart:165-190): a 20 pt
    /// circle with a 2 pt ring, the selected one ringed and dotted (10 pt) in
    /// activeColor ?? #2196F3, the others ringed in inactiveColor ?? #757575;
    /// after a tap the dot moves. Only the circle takes touches.
    func testA6_2TheSelectedRadioIsDottedAndTheOthersRinged() async throws {
        let hosted = try Host(try page(radios(), state: ["pick": "b"]))
        defer { hosted.close() }
        try assertRadios(hosted, rings: [Self.grey, Self.blue, Self.grey], dots: [false, true, false])

        try await radioView(hosted.model, "a").tap()?.value
        hosted.pump()
        try assertRadios(hosted, rings: [Self.blue, Self.grey, Self.grey], dots: [true, false, false])
    }

    /// A6.7: drawn disabled as Flutter does: a Checkbox greyed (onSurface at
    /// 0.38, activeColor ignored: checkbox.dart:483-493, checkbox defaults),
    /// its title too (black at 0.38); an unselected Radio ringed #BDBDBD, a
    /// selected one unchanged.
    func testA6_7DisabledControlsAreDrawnAsFlutterDrawsThem() async throws {
        for label in ["", "WWWW"] {
            let hosted = try Host(try page([checkbox("c", ["value": true, "label": .string(label),
                                                             "activeColor": "#FF0000", "enabled": false])]))
            defer { hosted.close() }
            let pixels = try hosted.pixels()
            XCTAssertNil(pixels.bounds(of: Pixels.isRed), "\(label): drawn in activeColor while disabled")
            let box = label.isEmpty ? CGRect(x: 15, y: 15, width: 18, height: 18)
                : CGRect(x: 27, y: 19, width: 18, height: 18)
            assertFrame(Self.bounds(of: Self.isGreyed, in: pixels, left: 60), box, "\(label): the greyed box")
            XCTAssertNil(pixels.bounds(of: Pixels.isInk), "\(label): a title in full ink")
        }

        let radios = try Host(try page([
            row("r", ["a", "b", "c"]),
            radio("a", ["value": "a", "groupValue": "a", "enabled": false]),
            radio("b", ["value": "b", "groupValue": "a", "enabled": false]),
            radio("c", ["value": "c", "groupValue": "a"]),
        ]))
        defer { radios.close() }
        try assertRadios(radios, rings: [Self.blue, (189, 189, 189), Self.grey], dots: [true, false, false])
    }

    /// A6.7: without an onChange, and with no binding at all, both still
    /// take touches (Flutter's Checkbox keeps its handler, a Radio's
    /// GestureDetector its tap); disabled they still hold the touch, doing
    /// nothing with it.
    func testA6_7ControlsWithoutOnChangeStillTakeTouches() throws {
        for props in [["stateKey": "done"], [:], ["enabled": false]] as [[String: JSONValue]] {
            let box = try Host(try page(behind(checkbox("c", props))))
            defer { box.close() }
            box.assertTaken(CGPoint(x: 24, y: 24))
            var radioProps = props
            radioProps["value"] = "b"
            let dot = try Host(try page(behind(radio("r", radioProps))))
            defer { dot.close() }
            dot.assertTaken(CGPoint(x: 10, y: 10))
            dot.assertPassed(CGPoint(x: 30, y: 10))
        }
    }
    #endif

    // MARK: pages

    /// A page of `nodes` (the first is the root) whose registry draws
    /// Checkbox and Radio; page `state` as given, plus `seen` and `echo`
    /// "unset".
    func page(_ nodes: [JSONValue], state: [String: JSONValue] = [:]) throws -> OrcaPageModel {
        var definitions: [JSONValue] = [["key": "seen", "scope": "page", "initial": "unset"],
                                        ["key": "echo", "scope": "page", "initial": "unset"]]
        for (key, value) in state.sorted(by: { $0.key < $1.key }) {
            definitions.append(["key": .string(key), "scope": "page", "initial": value])
        }
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(definitions), "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: response, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["Checkbox", "Radio"])))
    }

    func checkbox(_ id: String, _ props: [String: JSONValue], watches: [String] = [],
                  onChange: [JSONValue] = []) -> JSONValue {
        control(id, "Checkbox", props, watches: watches, onChange: onChange)
    }

    func radio(_ id: String, _ props: [String: JSONValue], watches: [String] = [],
               onChange: [JSONValue] = []) -> JSONValue {
        control(id, "Radio", props, watches: watches, onChange: onChange)
    }

    func control(_ id: String, _ type: String, _ props: [String: JSONValue], watches: [String],
                 onChange: [JSONValue]) -> JSONValue {
        var node: [String: JSONValue] = [
            "id": .string(id), "type": .string(type), "kind": "input", "childMode": "none",
            "props": .object(props), "children": [], "watches": .array(watches.map(JSONValue.string)),
        ]
        if !onChange.isEmpty {
            node["actions"] = ["onChange": ["type": "actionGroup", "mode": "sequential", "actions": .array(onChange)]]
        }
        return .object(node)
    }

    /// A Row `r` of Radios a, b and c on the group `pick`, bound as the demo
    /// binds them.
    func radios() -> [JSONValue] {
        [row("r", ["a", "b", "c"])] + ["a", "b", "c"].map { value in
            radio(value, ["value": .string(value), "groupValue": state("pick")], watches: ["pick"],
                  onChange: write("pick") + echo)
        }
    }

    func row(_ id: String, _ children: [String]) -> JSONValue {
        ["id": .string(id), "type": "Row", "kind": "layout", "childMode": "multi", "props": [:],
         "children": .array(children.map(JSONValue.string)), "watches": []]
    }

    /// A Stack: five text fields in a Column behind (the probes), `front`
    /// over them at the top left.
    func behind(_ front: JSONValue) -> [JSONValue] {
        let probes = (0..<5).map { "p\($0)" }
        return [
            ["id": "stack", "type": "Stack", "kind": "layout", "childMode": "multi",
             "props": ["alignment": "topLeft"], "children": ["probes", front.objectValue?["id"] ?? .null],
             "watches": []],
            ["id": "probes", "type": "Column", "kind": "layout", "childMode": "multi",
             "props": ["crossAxisAlignment": "stretch"], "children": .array(probes.map(JSONValue.string)),
             "watches": []],
        ] + probes.map { id -> JSONValue in
            ["id": .string(id), "type": "TextField", "kind": "input", "childMode": "none",
             "props": ["placeholder": .string(id)], "children": [], "watches": []]
        } + [front]
    }

    /// A page-state Value of `key`.
    func state(_ key: String) -> JSONValue {
        ["type": "state", "key": .string(key), "scope": "page"]
    }

    /// onChange: copy the key `done` to `seen` (what the key holds when
    /// onChange runs), then the event's value to `echo`.
    var echo: [JSONValue] {
        [["type": "setState", "key": "seen", "value": state("done")],
         ["type": "setState", "key": "echo", "value": ["type": "event", "key": "value"]]]
    }

    /// The demo's binding: SetState(key, V.event('value')).
    func write(_ key: String) -> [JSONValue] {
        [["type": "setState", "key": .string(key), "scope": "page", "value": ["type": "event", "key": "value"]]]
    }

    func view(_ model: OrcaPageModel, _ id: String) throws -> CheckboxNodeView {
        CheckboxNodeView(node: try XCTUnwrap(model.resolve(id), "no node \(id)"), model: model)
    }

    func radioView(_ model: OrcaPageModel, _ id: String) throws -> RadioNodeView {
        RadioNodeView(node: try XCTUnwrap(model.resolve(id), "no node \(id)"), model: model)
    }

    /// The radios among `ids` drawn selected.
    func selected(_ model: OrcaPageModel, _ ids: [String] = ["a", "b", "c"]) throws -> [String] {
        try ids.filter { try radioView(model, $0).isSelected }
    }

    // MARK: pixels

    static let blue: (Int, Int, Int) = (0x21, 0x96, 0xF3)
    static let grey: (Int, Int, Int) = (0x75, 0x75, 0x75)

    /// onSurface #1D1B20 at 0.38 over white.
    static func isGreyed(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        abs(Int(p.r) - 169) <= 10 && abs(Int(p.g) - 168) <= 10 && abs(Int(p.b) - 170) <= 10
    }

    /// `Pixels.bounds(of:)` over the columns left of `left` only.
    static func bounds(of matches: ((r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool, in pixels: Pixels,
                       left: Int) -> CGRect? {
        var found: CGRect?
        for y in 0..<pixels.height {
            for x in 0..<min(left, pixels.width) where matches(pixels.pixel(x, y)) {
                let pixel = CGRect(x: x, y: y, width: 1, height: 1)
                found = found?.union(pixel) ?? pixel
            }
        }
        return found
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
    /// The Row `r` of three 20 pt radios at the top left: each ring's colour
    /// (on its left edge, mid-height) and whether its centre is dotted in
    /// the ring's colour.
    func assertRadios(_ hosted: Host, rings: [(Int, Int, Int)], dots: [Bool],
                      file: StaticString = #filePath, line: UInt = #line) throws {
        let pixels = try hosted.pixels()
        for (index, (ring, dot)) in zip(rings, dots).enumerated() {
            let left = 20 * index
            Self.assertColour(pixels.pixel(left + 1, 10), ring, "radio \(index) ring", file: file, line: line)
            Self.assertColour(pixels.pixel(left + 10, 10), dot ? ring : (255, 255, 255), "radio \(index) centre",
                              file: file, line: line)
        }
    }

    static func assertColour(_ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (Int, Int, Int),
                             _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let pairs = [(Int(actual.r), expected.0), (Int(actual.g), expected.1), (Int(actual.b), expected.2)]
        if pairs.contains(where: { abs($0.0 - $0.1) > 8 }) {
            XCTFail("\(message): \(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// A page's root in a light 300 x 120 UIKit window at the top left, kept on
    /// screen until `close`.
    @MainActor
    final class Host {
        static let size = CGSize(width: 300, height: 120)
        let window: UIWindow
        let model: OrcaPageModel

        init(_ model: OrcaPageModel) throws {
            self.model = model
            let root = try XCTUnwrap(model.renderer.rootId, "no root")
            let host = UIHostingController(rootView: NodeView(id: root, model: model)
                .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
                .ignoresSafeArea())
            window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
            window.overrideUserInterfaceStyle = .light
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            pump()
        }

        func pump(_ seconds: Double = 0.3) {
            RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        }

        func pixels() throws -> Pixels {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: Self.size, format: format).image { context in
                window.layer.render(in: context.cgContext)
            }
            return try Pixels(XCTUnwrap(image.cgImage))
        }

        /// The control in front takes a hit at `point`: no probe behind gets it,
        /// though one lies under the point.
        func assertTaken(_ point: CGPoint, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertTrue(probed(point), "no probe under \(point)", file: file, line: line)
            XCTAssertFalse(FlowTests.isInField(window.hitTest(point, with: nil)), "a probe took \(point)",
                           file: file, line: line)
        }

        /// A hit at `point` goes through to the probe behind.
        func assertPassed(_ point: CGPoint, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertTrue(probed(point), "no probe under \(point)", file: file, line: line)
            XCTAssertTrue(FlowTests.isInField(window.hitTest(point, with: nil)), "the probe took no hit at \(point)",
                          file: file, line: line)
        }

        private func probed(_ point: CGPoint) -> Bool {
            func fields(_ view: UIView) -> [UITextField] {
                ((view as? UITextField).map { [$0] } ?? []) + view.subviews.flatMap(fields)
            }
            return fields(window).contains { $0.convert($0.bounds, to: window).contains(point) }
        }

        func close() {
            window.isHidden = true
        }
    }
    #endif
}

#endif
