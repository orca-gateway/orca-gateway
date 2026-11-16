#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// The implicitly animated widgets (AnimatedContainer, AnimatedOpacity,
/// AnimatedAlign), AnimatedSwitcher and Hero. Their clocks are the core's;
/// the tests move the page's frame clock and read the props the views hand
/// to the Container, opacity and Align drawing code at that time.
@MainActor
final class AnimatedWidgetTests: XCTestCase {
    static let orange = "#FF6F00"
    static let blue = "#1565C0"

    private func box(curve: String?) throws -> Stage {
        var props: [String: JSONValue] = [
            "duration": 300, "width": Stage.state("w"), "color": Stage.state("c"), "height": 40,
        ]
        if let curve { props["curve"] = .string(curve) }
        return try Stage("AnimatedContainer", props, state: ["w": 100, "c": .string(Self.blue)])
    }

    // MARK: B12.2 AnimatedContainer

    /// The first build shows the target as it is: no run, no frames asked for.
    func test_B12_2_theFirstBuildHasNoAnimation() throws {
        let stage = try box(curve: "linear")
        let driver = ImplicitDriver(.container)
        XCTAssertFalse(try stage.show(driver), "the first build asked for frames")
        for at in [0.0, 150, 300] {
            XCTAssertEqual(driver.node(at: at).props, try stage.node().props)
        }
        XCTAssertEqual(driver.node(at: 0)["width"], 100)
        XCTAssertEqual(driver.node(at: 0).childIds, ["kid"])
    }

    /// Width and colour at 150 of 300 ms are the core's mix, for a linear
    /// curve and for the default (easeInOut); the end state is the resolved
    /// props exactly, and the view stops asking for frames.
    func test_B12_2_widthAndColourAtTheMidpointAreTheCoresMix() throws {
        for curve in ["linear", "easeInOut", nil] {
            let stage = try box(curve: curve)
            let driver = ImplicitDriver(.container)
            try stage.show(driver)

            stage.now = 1000
            stage.model.store.dispatch(["w": 200, "c": .string(Self.orange)])
            XCTAssertTrue(try stage.show(driver), "a new width did not start a run")

            for elapsed in [75.0, 150, 225] {
                let t = Curves.apply(curve ?? "easeInOut", elapsed / 300)
                let node = driver.node(at: 1000 + elapsed)
                XCTAssertEqual(try XCTUnwrap(node["width"]?.doubleValue), AnimationMix.number(100, 200, t),
                               accuracy: 1e-9)
                XCTAssertEqual(node["color"]?.stringValue, AnimationMix.color(Self.blue, Self.orange, t))
                XCTAssertEqual(node["height"], 40, "an unchanged prop moved")
            }
            if curve == "linear" {
                XCTAssertEqual(try XCTUnwrap(driver.node(at: 1150)["width"]?.doubleValue), 150, accuracy: 1e-9)
            }
            XCTAssertTrue(driver.needsTick)

            XCTAssertEqual(driver.node(at: 1300).props, try stage.node().props)
            XCTAssertEqual(driver.node(at: 1300)["width"], 200)
            XCTAssertEqual(driver.node(at: 1300)["color"]?.stringValue, Self.orange)
            driver.settle(at: 1300)
            XCTAssertFalse(driver.needsTick, "the run ended and frames are still asked for")
        }
    }

    /// A new target mid-run starts from what is on screen, over the full
    /// duration.
    func test_B12_2_aRetargetMidRunStartsFromTheOnScreenValue() throws {
        let stage = try box(curve: "linear")
        let driver = ImplicitDriver(.container)
        try stage.show(driver)

        stage.now = 0
        stage.model.store.dispatch(["w": 200])
        try stage.show(driver)
        stage.now = 150
        stage.model.store.dispatch(["w": 300])
        XCTAssertTrue(try stage.show(driver))

        XCTAssertEqual(try XCTUnwrap(driver.node(at: 150)["width"]?.doubleValue), 150, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(driver.node(at: 300)["width"]?.doubleValue), 225, accuracy: 1e-9)
        XCTAssertEqual(driver.node(at: 450)["width"], 300)
    }

    /// A redraw with the same props (the frame tick, a parent's redraw) does
    /// not restart the run.
    func test_B12_2_aRedrawWithTheSamePropsKeepsTheRun() throws {
        let stage = try box(curve: "linear")
        let driver = ImplicitDriver(.container)
        try stage.show(driver)
        stage.model.store.dispatch(["w": 200])
        try stage.show(driver)
        stage.now = 150
        XCTAssertTrue(try stage.show(driver), "the live run was dropped")
        XCTAssertEqual(try XCTUnwrap(driver.node(at: 150)["width"]?.doubleValue), 150, accuracy: 1e-9)
    }

    /// The sampled props reach the Container drawing code: a mid-run
    /// alignment is an `{x, y}` object and the Container places its child by
    /// it; at rest the AnimatedContainer draws as the Container would.
    func test_B12_2_theContainerDrawsAMidRunAlignmentAndTheRestState() throws {
        let kid = CGRect(x: 0, y: 0, width: 20, height: 20)
        let midRun = try Stage("Container", ["width": 100, "height": 100, "alignment": ["x": 0.5, "y": -1]])
        let placed = try XCTUnwrap(try midRun.draw(width: 100, height: 100).bounds(of: Pixels.isRed))
        assertRect(placed, kid.offsetBy(dx: 60, dy: 0))

        let rest = try Stage("AnimatedContainer",
                             ["width": 100, "height": 100, "alignment": "bottomRight", "duration": 300])
        let drawn = try XCTUnwrap(try rest.draw(width: 100, height: 100).bounds(of: Pixels.isRed))
        assertRect(drawn, kid.offsetBy(dx: 80, dy: 80))
    }

    // MARK: B12.3 AnimatedOpacity and AnimatedAlign

    func test_B12_3_opacityAtTheMidpointOnAStateChange() throws {
        let stage = try Stage("AnimatedOpacity",
                              ["opacity": Stage.state("o"), "duration": 400, "curve": "bounceOut"],
                              state: ["o": 1])
        let driver = ImplicitDriver(.opacity)
        XCTAssertFalse(try stage.show(driver))
        XCTAssertEqual(driver.node(at: 0)["opacity"], 1)

        stage.now = 500
        stage.model.store.dispatch(["o": 0.25])
        XCTAssertTrue(try stage.show(driver))
        let t = Curves.apply("bounceOut", 0.5)
        XCTAssertEqual(try XCTUnwrap(driver.node(at: 700)["opacity"]?.doubleValue),
                       AnimationMix.number(1, 0.25, t), accuracy: 1e-9)
        XCTAssertEqual(driver.node(at: 900)["opacity"], 0.25)
    }

    /// No `opacity` is 1 (Dart's default), so adding one later animates.
    func test_B12_3_aMissingOpacityAnimatesFromOne() throws {
        let stage = try Stage("AnimatedOpacity", ["duration": 200, "curve": "linear"])
        let driver = ImplicitDriver(.opacity)
        try stage.show(driver)
        XCTAssertEqual(driver.node(at: 0)["opacity"], 1)
        stage.model.apply(.update(id: "w", props: ["opacity": 0]))
        XCTAssertTrue(try stage.show(driver))
        XCTAssertEqual(try XCTUnwrap(driver.node(at: 100)["opacity"]?.doubleValue), 0.5, accuracy: 1e-9)
    }

    /// An alignment by name is an `{x, y}` object mid-run and the name again
    /// at the end.
    func test_B12_3_alignmentAtTheMidpointOnAStateChange() throws {
        let stage = try Stage("AnimatedAlign",
                              ["alignment": Stage.state("corner"), "duration": 300, "curve": "linear",
                               "widthFactor": 2],
                              state: ["corner": "topLeft"])
        let driver = ImplicitDriver(.align)
        XCTAssertFalse(try stage.show(driver))
        XCTAssertEqual(driver.node(at: 0)["alignment"], "topLeft")

        stage.now = 100
        stage.model.store.dispatch(["corner": "bottomRight"])
        XCTAssertTrue(try stage.show(driver))
        let mid = driver.node(at: 250)
        XCTAssertEqual(mid["alignment"], AnimationMix.alignment("topLeft", "bottomRight", 0.5))
        XCTAssertEqual(mid["alignment"], ["x": 0.0, "y": 0.0])
        XCTAssertEqual(mid["widthFactor"], 2)
        let quarter = try XCTUnwrap(driver.node(at: 175)["alignment"])
        XCTAssertEqual(try XCTUnwrap(quarter["x"].doubleValue), -0.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(quarter["y"].doubleValue), -0.5, accuracy: 1e-9)
        XCTAssertEqual(driver.node(at: 400)["alignment"], "bottomRight")
    }

    /// No `alignment` is the centre (Flutter's default), so naming one later
    /// animates from the centre.
    func test_B12_3_aMissingAlignmentAnimatesFromTheCentre() throws {
        let stage = try Stage("AnimatedAlign", ["duration": 200, "curve": "linear"])
        let driver = ImplicitDriver(.align)
        try stage.show(driver)
        XCTAssertEqual(driver.node(at: 0)["alignment"], "center")
        stage.model.apply(.update(id: "w", props: ["alignment": "bottomRight"]))
        XCTAssertTrue(try stage.show(driver))
        XCTAssertEqual(driver.node(at: 100)["alignment"], ["x": 0.5, "y": 0.5])
    }

    /// The Align drawing code places the child by a name and by a mid-run
    /// `{x, y}`, and a factor sizes the box from the child.
    func test_B12_3_theAlignDrawsNamesAndMidRunPoints() throws {
        let kid = CGRect(x: 0, y: 0, width: 20, height: 20)
        let named = try Stage("AnimatedAlign", ["alignment": "bottomRight"])
        assertRect(try XCTUnwrap(try named.draw(width: 100, height: 100).bounds(of: Pixels.isRed)),
                   kid.offsetBy(dx: 80, dy: 80))

        let node = try Stage("AnimatedAlign", [:]).node()
        func draw(_ props: [String: JSONValue], in stage: Stage) throws -> CGRect {
            var sampled = node
            sampled.props = props
            let renderer = ImageRenderer(content: AlignedView(node: sampled, model: stage.model)
                .frame(width: 100, height: 100, alignment: .topLeading))
            renderer.scale = 1
            return try XCTUnwrap(try Pixels(XCTUnwrap(renderer.cgImage)).bounds(of: Pixels.isRed))
        }
        let stage = try Stage("AnimatedAlign", [:])
        assertRect(try draw(["alignment": ["x": 0.5, "y": -0.5]], in: stage), kid.offsetBy(dx: 60, dy: 20))
        // widthFactor 2: the box is 40 wide, the child at its right edge.
        assertRect(try draw(["alignment": "centerRight", "widthFactor": 2, "heightFactor": 1], in: stage),
                   kid.offsetBy(dx: 20, dy: 0))
    }

    // MARK: B12.4 AnimatedSwitcher

    private func switcher() throws -> Stage {
        try Stage("AnimatedSwitcher", ["duration": 200], kid: "a")
    }

    private static func kid(_ id: String) throws -> ComponentNode {
        try JSONValue.object(Stage.kid(id)).decode(ComponentNode.self)
    }

    /// The child's id changed: both children are there mid-fade, the old one
    /// below, with complementary opacities; after `duration` only the new one.
    func test_B12_4_aNewChildIdCrossFades() throws {
        let stage = try switcher()
        let driver = SwitcherDriver()
        XCTAssertFalse(try stage.show(driver), "the first child faded in")
        XCTAssertEqual(driver.layers(at: 0), [SwitcherDriver.Layer(id: "a", opacity: 1)])

        stage.now = 1000
        stage.model.apply(.replace(targetId: "a", components: [try Self.kid("c")]))
        XCTAssertEqual(try stage.node().childIds, ["c"])
        XCTAssertTrue(try stage.show(driver), "a new child id did not start a fade")

        XCTAssertEqual(driver.layers(at: 1000), [.init(id: "a", opacity: 1), .init(id: "c", opacity: 0)])
        let quarter = driver.layers(at: 1050)
        XCTAssertEqual(quarter.map(\.id), ["a", "c"])
        XCTAssertEqual(quarter[0].opacity, 0.75, accuracy: 1e-9)
        XCTAssertEqual(quarter[1].opacity, 0.25, accuracy: 1e-9)
        let mid = driver.layers(at: 1100)
        XCTAssertEqual(mid[0].opacity + mid[1].opacity, 1, accuracy: 1e-9)
        XCTAssertEqual(mid[1].opacity, 0.5, accuracy: 1e-9)
        XCTAssertTrue(driver.needsTick)

        XCTAssertEqual(driver.layers(at: 1200), [.init(id: "c", opacity: 1)])
        driver.settle(at: 1200)
        XCTAssertFalse(driver.needsTick)
        XCTAssertEqual(driver.layers(at: 5000), [.init(id: "c", opacity: 1)])
    }

    /// The same id with new props is a prop change, not a new child.
    func test_B12_4_theSameIdWithNewPropsDoesNotFade() throws {
        let stage = try switcher()
        let driver = SwitcherDriver()
        try stage.show(driver)
        stage.now = 300
        stage.model.apply(.update(id: "a", props: ["color": "#00FF00"]))
        XCTAssertFalse(try stage.show(driver))
        XCTAssertEqual(driver.layers(at: 300), [.init(id: "a", opacity: 1)])
        XCTAssertFalse(driver.needsTick)
    }

    /// A second swap mid-fade: the child that was still fading out from the
    /// first swap is dropped (one outgoing layer at most, as the Kotlin
    /// twin); the one just replaced fades out from where it is, the newest
    /// fades in.
    func test_B12_4_aSecondSwapMidFadeDropsTheEarlierOutgoingChild() throws {
        let driver = SwitcherDriver()
        driver.update(childId: "a", durationMs: 200, reduceMotion: false, at: 0)
        driver.update(childId: "b", durationMs: 200, reduceMotion: false, at: 0)
        XCTAssertEqual(driver.layers(at: 50).map(\.id), ["a", "b"])
        driver.update(childId: "c", durationMs: 200, reduceMotion: false, at: 100)
        let layers = driver.layers(at: 150)
        XCTAssertEqual(layers.map(\.id), ["b", "c"], "the earlier outgoing child is still drawn")
        XCTAssertEqual(layers[0].opacity, 0.25, accuracy: 1e-9)
        XCTAssertEqual(layers[1].opacity, 0.25, accuracy: 1e-9)
        XCTAssertEqual(driver.layers(at: 300), [.init(id: "c", opacity: 1)])

        // A child that comes back mid-fade rises again from where it is, and
        // the one it replaces is the only one going out.
        driver.update(childId: "d", durationMs: 200, reduceMotion: false, at: 1000)
        driver.update(childId: "c", durationMs: 200, reduceMotion: false, at: 1050)
        let back = driver.layers(at: 1050)
        XCTAssertEqual(back.map(\.id), ["c", "d"])
        XCTAssertEqual(back[0].opacity, 0.75, accuracy: 1e-9)
        XCTAssertEqual(back[1].opacity, 0.25, accuracy: 1e-9)
    }

    /// The switcher draws its child, centred in the biggest one.
    func test_B12_4_theSwitcherDrawsItsChild() throws {
        let pixels = try switcher().draw(width: 100, height: 100)
        assertRect(try XCTUnwrap(pixels.bounds(of: Pixels.isRed)), CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    // MARK: B12.4 the outgoing child is drawn from its snapshot

    /// A switcher `w` over `a`: a GestureDetector (onTap sets `n`) over a
    /// red 20 by 20 Container over a Text. The clock reads `now.value`.
    private func liveSwitcher(_ now: Clock) throws -> OrcaPageModel {
        let model = OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "n", "scope": "page", "initial": 0]],
            "components": [
                ["id": "w", "type": "AnimatedSwitcher", "kind": "layout", "childMode": "single",
                 "props": ["duration": 200], "children": ["a"], "watches": []],
                ["id": "a", "type": "GestureDetector", "kind": "layout", "childMode": "single",
                 "props": [:], "children": ["a-box"], "watches": [],
                 "actions": ["onTap": ["type": "setState", "scope": "page", "key": "n",
                                       "value": ["type": "static", "value": 1]]]],
                ["id": "a-box", "type": "Container", "kind": "layout", "childMode": "single",
                 "props": ["width": 20, "height": 20, "color": "#FF0000"], "children": ["a-text"], "watches": []],
                ["id": "a-text", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "old"], "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self))
        model.frameClock = { now.value }
        return model
    }

    /// What the views do on a redraw of the switcher: the driver is told,
    /// then the current child and everything below it is drawn, which
    /// records each node (`draw`).
    @discardableResult
    private func show(_ driver: SwitcherDriver, _ model: OrcaPageModel, reduceMotion: Bool = false) throws -> Bool {
        let node = try XCTUnwrap(model.resolve("w"))
        let live = driver.update(node: node, in: model, reduceMotion: reduceMotion, at: model.frameClock())
        if let child = node.childIds.first { draw(child, of: model, into: driver.recorder) }
        return live
    }

    /// What NodeView does when it draws node `id`, and with `below` the
    /// nodes under it: each is resolved and recorded.
    private func draw(_ id: String, of model: OrcaPageModel, into recorder: NodeRecorder, below: Bool = true) {
        guard let node = model.resolve(id), let source = model.renderer.node(id) else { return }
        recorder.record(node, source: source)
        guard below else { return }
        for child in node.childIds { draw(child, of: model, into: recorder) }
    }

    /// The outgoing layer of `a` has the old child to draw: its node, its
    /// descendants down to the Text, and red pixels through NodeView.
    private func assertOutgoingHasTheOldChild(_ driver: SwitcherDriver, file: StaticString = #filePath,
                                              line: UInt = #line) throws -> OrcaPageModel {
        let frozen = try XCTUnwrap(driver.outgoing("a"), "the outgoing layer has nothing to draw",
                                   file: file, line: line)
        XCTAssertEqual(frozen.resolve("a")?.type, "GestureDetector", file: file, line: line)
        XCTAssertEqual(frozen.resolve("a")?.childIds, ["a-box"], file: file, line: line)
        XCTAssertEqual(frozen.resolve("a-box")?["color"], "#FF0000", file: file, line: line)
        XCTAssertEqual(frozen.resolve("a-text")?["data"], "old", file: file, line: line)
        let renderer = ImageRenderer(content: NodeView(id: "a", model: frozen)
            .frame(width: 100, height: 100, alignment: .topLeading))
        renderer.scale = 1
        let pixels = try Pixels(XCTUnwrap(renderer.cgImage))
        assertRect(try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "the old child drew nothing", file: file, line: line),
                   CGRect(x: 0, y: 0, width: 20, height: 20), file: file, line: line)
        return frozen
    }

    /// A replace takes the old child off the page; mid-fade it is still
    /// drawn, from its snapshot, under the new one, opacities complementary.
    /// After `duration` only the new child is left and the snapshot is gone.
    func test_B12_4_aReplacedChildFadesOutFromItsSnapshot() async throws {
        let now = Clock()
        let model = try liveSwitcher(now)
        let driver = SwitcherDriver()
        XCTAssertFalse(try show(driver, model))
        XCTAssertNil(driver.outgoing("a"), "the current child is drawn live")

        now.value = 1000
        let mutate = try XCTUnwrap(model.executor.onMutation)
        mutate(.replace(targetId: "a", components: [try Self.kid("c")]))
        XCTAssertNil(model.resolve("a"), "the replace left the old child on the page")
        XCTAssertNil(model.resolve("a-text"))
        XCTAssertTrue(try show(driver, model))

        let mid = driver.layers(at: 1100)
        XCTAssertEqual(mid.map(\.id), ["a", "c"])
        XCTAssertEqual(mid[0].opacity, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid[0].opacity + mid[1].opacity, 1, accuracy: 1e-9)
        let frozen = try assertOutgoingHasTheOldChild(driver)
        XCTAssertNil(driver.outgoing("c"), "the new child is drawn live")
        XCTAssertNotNil(model.resolve("c"))

        // The outgoing layer is inert: its actions do not run, on either store.
        XCTAssertTrue(frozen.isInert)
        let old = try XCTUnwrap(frozen.resolve("a"))
        XCTAssertNil(frozen.fire("onTap", on: old))
        await frozen.run(try XCTUnwrap(old.actions["onTap"]))
        XCTAssertEqual(model.store.value("n"), 0)
        XCTAssertEqual(frozen.store.value("n"), 0)
        XCTAssertNil(frozen.textChanged("x", on: old))
        frozen.apply(.delete(id: "a"))
        XCTAssertNotNil(frozen.resolve("a"))
        XCTAssertFalse(model.isInert)

        // A redraw mid-fade keeps the same frozen child.
        now.value = 1100
        XCTAssertTrue(try show(driver, model))
        XCTAssertTrue(driver.outgoing("a") === frozen)

        XCTAssertEqual(driver.layers(at: 1200), [.init(id: "c", opacity: 1)])
        driver.settle(at: 1200)
        XCTAssertFalse(driver.needsTick)
        XCTAssertNil(driver.outgoing("a"), "the snapshot outlived the fade")
    }

    /// A delete, then an add: the old child fades out alone from its
    /// snapshot, and the new one fades in when it comes.
    func test_B12_4_aDeletedChildFadesOutAndAnAddedOneFadesIn() throws {
        let now = Clock()
        let model = try liveSwitcher(now)
        let driver = SwitcherDriver()
        try show(driver, model)
        let mutate = try XCTUnwrap(model.executor.onMutation)

        now.value = 1000
        mutate(.delete(id: "a"))
        XCTAssertNil(model.resolve("a"))
        XCTAssertTrue(try show(driver, model))
        let alone = driver.layers(at: 1100)
        XCTAssertEqual(alone.map(\.id), ["a"])
        XCTAssertEqual(alone[0].opacity, 0.5, accuracy: 1e-9)
        _ = try assertOutgoingHasTheOldChild(driver)

        now.value = 1100
        mutate(.add(parentId: "w", components: [try Self.kid("c")], position: nil))
        XCTAssertTrue(try show(driver, model))
        let both = driver.layers(at: 1150)
        XCTAssertEqual(both.map(\.id), ["a", "c"])
        XCTAssertEqual(both[0].opacity, 0.25, accuracy: 1e-9)
        XCTAssertEqual(both[1].opacity, 0.25, accuracy: 1e-9)
        _ = try assertOutgoingHasTheOldChild(driver)

        XCTAssertEqual(driver.layers(at: 1300), [.init(id: "c", opacity: 1)])
        driver.settle(at: 1300)
        XCTAssertNil(driver.outgoing("a"))
        XCTAssertFalse(driver.needsTick)
    }

    /// Reduced motion swaps at once with no outgoing layer; the same id with
    /// new props keeps the live child and freezes nothing.
    func test_B12_4_reducedMotionAndAPropChangeHaveNoOutgoingLayer() throws {
        let now = Clock()
        let model = try liveSwitcher(now)
        let driver = SwitcherDriver()
        try show(driver, model, reduceMotion: true)
        now.value = 50
        model.executor.onMutation?(.update(id: "a", props: ["behavior": "opaque"]))
        XCTAssertFalse(try show(driver, model, reduceMotion: true))
        XCTAssertNil(driver.outgoing("a"))

        model.executor.onMutation?(.replace(targetId: "a", components: [try Self.kid("c")]))
        XCTAssertFalse(try show(driver, model, reduceMotion: true))
        XCTAssertEqual(driver.layers(at: 50), [.init(id: "c", opacity: 1)])
        XCTAssertNil(driver.outgoing("a"))
        XCTAssertNil(driver.outgoing("c"))
        XCTAssertFalse(driver.needsTick)
    }

    /// A switcher `w` (it watches nothing) over `a`, a 20 by 20 Container
    /// whose colour is page state `c`, red at first: only `a` watches `c`.
    private func watchingChild(_ now: Clock, duration: Int = 200) throws -> OrcaPageModel {
        let model = OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "c", "scope": "page", "initial": "#FF0000"]],
            "components": [
                ["id": "w", "type": "AnimatedSwitcher", "kind": "layout", "childMode": "single",
                 "props": ["duration": .int(duration)], "children": ["a"], "watches": []],
                ["id": "a", "type": "Container", "kind": "layout", "childMode": "single",
                 "props": ["width": 20, "height": 20, "color": Stage.state("c")], "children": [],
                 "watches": ["c"]],
            ],
        ]).decode(PageResponse.self))
        model.frameClock = { now.value }
        return model
    }

    /// The same on the driver: the child alone redraws (the switcher is not
    /// told), and the frozen page holds the child as it was then drawn.
    func test_B12_4_theFrozenChildIsTheChildAsLastDrawn() throws {
        let now = Clock()
        let model = try watchingChild(now)
        let driver = SwitcherDriver()
        try show(driver, model)

        model.store.dispatch(["c": "#00FF00"])
        draw("a", of: model, into: driver.recorder)

        now.value = 1000
        model.apply(.replace(targetId: "a", components: [try Self.kid("n")]))
        XCTAssertTrue(try show(driver, model))
        let frozen = try XCTUnwrap(driver.outgoing("a"))
        XCTAssertEqual(frozen.resolve("a")?["color"], "#00FF00")
        XCTAssertEqual(frozen.store.value("c"), "#00FF00")
        XCTAssertNil(frozen.resolve("n"), "the new child is not part of the old one's record")

        // The record starts again with the new child: replaced in turn, the
        // frozen page of `n` has nothing of `a`, which is dropped.
        now.value = 1050
        model.apply(.replace(targetId: "n", components: [try Self.kid("m")]))
        XCTAssertTrue(try show(driver, model))
        XCTAssertNil(driver.outgoing("a"), "the earlier outgoing child is still kept")
        XCTAssertEqual(driver.layers(at: 1050).map(\.id), ["n", "m"])
        let second = try XCTUnwrap(driver.outgoing("n"))
        XCTAssertNotNil(second.resolve("n"))
        XCTAssertNil(second.resolve("a"))
    }

    /// A node that was never drawn has no frozen page; a switcher inside
    /// another tells the outer one's recorder what its child draws.
    func test_B12_4_aRecorderTellsTheEnclosingOne() throws {
        let now = Clock()
        let model = try watchingChild(now)
        let outer = NodeRecorder()
        let driver = SwitcherDriver()
        driver.update(node: try XCTUnwrap(model.resolve("w")), in: model, enclosing: outer,
                      reduceMotion: false, at: 0)
        XCTAssertNil(outer.snapshot(of: "a", state: model.store.state), "nothing was drawn yet")
        draw("a", of: model, into: driver.recorder)
        XCTAssertEqual(outer.snapshot(of: "a", state: model.store.state)?.nodes["a"]?["color"], "#FF0000")

        // Drawn through the views: NodeView records into the recorder of
        // its environment, the switcher's child included.
        let seen = NodeRecorder()
        let renderer = ImageRenderer(content: NodeView(id: "w", model: model)
            .environment(\.orcaNodeRecorder, seen)
            .frame(width: 100, height: 100, alignment: .topLeading))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
        let drawn = try XCTUnwrap(seen.snapshot(of: "w", state: model.store.state))
        XCTAssertEqual(Set(drawn.nodes.keys), ["w", "a"])
        XCTAssertEqual(drawn.components.map(\.id).sorted(), ["a", "w"])
    }

    private static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.g > 60 && Int(p.g) > Int(p.r) + 50 && Int(p.g) > Int(p.b) + 50
    }

    /// The child's own state changed after the switcher last redrew (only
    /// the child watches it), then the child is replaced: the outgoing layer
    /// shows what was on screen, the new value. Drawn through the views.
    func test_B12_4_theOutgoingChildIsWhatWasOnScreenNotTheSwitchersLastRedraw() throws {
        let now = Clock()
        now.value = OrcaPageModel.milliseconds(Date())
        // A fade far longer than the test: the outgoing layer stays opaque.
        let model = try watchingChild(now, duration: 3_600_000)
        let renderer = ImageRenderer(content: NodeView(id: "w", model: model)
            .frame(width: 100, height: 100, alignment: .topLeading))
        renderer.scale = 1
        // The renderer keeps its views between images; a turn of the run
        // loop lets them take a change in.
        func drawn() throws -> Pixels {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            return try Pixels(XCTUnwrap(renderer.cgImage))
        }
        let box = CGRect(x: 0, y: 0, width: 20, height: 20)
        assertRect(try XCTUnwrap(try drawn().bounds(of: Pixels.isRed)), box)

        model.store.dispatch(["c": "#00FF00"])
        let recoloured = try drawn()
        assertRect(try XCTUnwrap(recoloured.bounds(of: Self.isGreen), "the child did not redraw"), box)
        XCTAssertNil(recoloured.bounds(of: Pixels.isRed))

        var next = Stage.kid("n")
        next["props"] = ["width": 20, "height": 20, "color": "#0000FF"]
        model.apply(.replace(targetId: "a", components: [try JSONValue.object(next).decode(ComponentNode.self)]))
        XCTAssertNil(model.resolve("a"))
        let fading = try drawn()
        XCTAssertNil(fading.bounds(of: Pixels.isRed), "the outgoing layer shows the value of the switcher's last redraw")
        assertRect(try XCTUnwrap(fading.bounds(of: Self.isGreen), "the outgoing layer is not the child as it was on screen"),
                   box)
    }

    // MARK: B12.7 reduced motion

    /// Reduced motion: the end state at once, no frames, for the three
    /// implicit widgets.
    func test_B12_7_reducedMotionJumpsToTheEndState() throws {
        let container = try box(curve: "linear")
        let opacity = try Stage("AnimatedOpacity", ["opacity": Stage.state("w"), "duration": 300], state: ["w": 1])
        let align = try Stage("AnimatedAlign", ["alignment": Stage.state("w"), "duration": 300],
                              state: ["w": "topLeft"])
        let cases: [(Stage, ImplicitDriver, String, JSONValue)] = [
            (container, ImplicitDriver(.container), "width", 200),
            (opacity, ImplicitDriver(.opacity), "opacity", 0.5),
            (align, ImplicitDriver(.align), "alignment", "bottomRight"),
        ]
        for (stage, driver, prop, next) in cases {
            try stage.show(driver, reduceMotion: true)
            stage.now = 100
            stage.model.store.dispatch(["w": next])
            XCTAssertFalse(try stage.show(driver, reduceMotion: true), "\(prop) asked for frames")
            for at in [100.0, 101, 250, 400] {
                XCTAssertEqual(driver.node(at: at)[prop], next, prop)
            }
            XCTAssertFalse(driver.needsTick)
        }
    }

    /// Reduced motion: the switcher swaps at once.
    func test_B12_7_reducedMotionTheSwitcherSwapsAtOnce() throws {
        let stage = try switcher()
        let driver = SwitcherDriver()
        try stage.show(driver, reduceMotion: true)
        stage.now = 50
        stage.model.apply(.replace(targetId: "a", components: [try Self.kid("c")]))
        XCTAssertFalse(try stage.show(driver, reduceMotion: true))
        XCTAssertEqual(driver.layers(at: 50), [.init(id: "c", opacity: 1)])
        XCTAssertFalse(driver.needsTick)
    }

    /// A duration of 0 jumps as well.
    func test_B12_7_aZeroDurationJumps() throws {
        let stage = try Stage("AnimatedContainer", ["width": Stage.state("w"), "duration": 0], state: ["w": 100])
        let driver = ImplicitDriver(.container)
        try stage.show(driver)
        stage.model.store.dispatch(["w": 200])
        XCTAssertFalse(try stage.show(driver))
        XCTAssertEqual(driver.node(at: 0)["width"], 200)
    }

    // MARK: B12.5 Hero, drawn as its child

    func test_B12_5_heroDrawsItsChildAndCarriesItsTag() throws {
        let tagged = try Stage("Hero", ["tag": "product-42"])
        assertRect(try XCTUnwrap(try tagged.draw(width: 100, height: 100).bounds(of: Pixels.isRed)),
                   CGRect(x: 0, y: 0, width: 20, height: 20))
        XCTAssertEqual(HeroView.tag(of: try tagged.node()), "product-42")

        for props: [String: JSONValue] in [["tag": ""], [:]] {
            let bare = try Stage("Hero", props)
            assertRect(try XCTUnwrap(try bare.draw(width: 100, height: 100).bounds(of: Pixels.isRed)),
                       CGRect(x: 0, y: 0, width: 20, height: 20))
            XCTAssertNil(HeroView.tag(of: try bare.node()), "an empty tag is no hero")
        }
    }

    // MARK: the render fixtures

    /// Fixtures 62 to 66: each root keeps its type (it is advertised, so not
    /// degraded to the fallback prompt) and draws its Text child.
    func test_B12_theFiveFixturesAreDrawnNotDegraded() throws {
        let fixtures = [
            ("62_animated_container", "AnimatedContainer"), ("63_animated_opacity", "AnimatedOpacity"),
            ("64_animated_align", "AnimatedAlign"), ("65_animated_switcher", "AnimatedSwitcher"),
            ("66_hero", "Hero"),
        ]
        for (file, type) in fixtures {
            XCTAssertTrue(GeneratedCapabilities.widgets.contains(type), "\(type) is not advertised")
            let url = swiftRoot.appendingPathComponent("../schema/fixtures/render/\(file).json")
            let fixture = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
            let components = try XCTUnwrap(fixture["expected"].arrayValue)
            let rootId = try XCTUnwrap(components.first?["id"].stringValue)
            var state: [JSONValue] = []
            if case .object(let pageState) = fixture["context"]["pageState"] {
                state = pageState.map { ["key": .string($0.key), "scope": "page", "initial": $0.value] }
            }
            let model = OrcaPageModel(page: try JSONValue.object([
                "pageId": "p", "title": "T", "state": .array(state), "components": .array(components),
            ]).decode(PageResponse.self))

            let root = try XCTUnwrap(model.resolve(rootId))
            XCTAssertEqual(root.type, type)
            XCTAssertNil(root.degradedFrom, "\(type) was degraded")

            let renderer = ImageRenderer(content: NodeView(id: rootId, model: model)
                .frame(width: 300, height: 300, alignment: .topLeading))
            renderer.scale = 1
            let pixels = try Pixels(XCTUnwrap(renderer.cgImage))
            XCTAssertNotNil(pixels.bounds(of: { $0.a > 20 }), "\(type) drew nothing")
        }
    }

    // MARK: helpers

    func assertRect(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.maxX, expected.maxX), (actual.maxY, expected.maxY)] {
            XCTAssertEqual(a, e, accuracy: 0.5, "\(actual) vs \(expected)", file: file, line: line)
        }
    }
}

/// The time a test's page reads as "now", in milliseconds.
@MainActor
private final class Clock {
    var value = 0.0
}

/// A page of one widget `w` of `type` over a red 20 by 20 Container. The
/// page's frame clock reads `now`.
@MainActor
private final class Stage {
    let model: OrcaPageModel
    var now = 0.0

    static func state(_ key: String) -> JSONValue {
        ["type": "state", "key": .string(key), "scope": "page"]
    }

    static func kid(_ id: String) -> [String: JSONValue] {
        ["id": .string(id), "type": "Container", "kind": "layout", "childMode": "single",
         "props": ["width": 20, "height": 20, "color": "#FF0000"], "children": [], "watches": []]
    }

    init(_ type: String, _ props: [String: JSONValue], state: [String: JSONValue] = [:],
         kid: String = "kid") throws {
        let definitions: [JSONValue] = state.map { ["key": .string($0.key), "scope": "page", "initial": $0.value] }
        model = try OrcaPageModel(page: JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(definitions),
            "components": [
                ["id": "w", "type": .string(type), "kind": "layout", "childMode": "single",
                 "props": .object(props), "children": [.string(kid)], "watches": .array(state.keys.sorted().map(JSONValue.string))],
                .object(Self.kid(kid)),
            ],
        ]).decode(PageResponse.self))
        model.frameClock = { [unowned self] in self.now }
    }

    func node() throws -> ResolvedNode {
        try XCTUnwrap(model.resolve("w"))
    }

    /// What the view does on a redraw: hands the node as resolved now to the
    /// driver, at the frame clock's time. True while frames are needed.
    @discardableResult
    func show(_ driver: ImplicitDriver, reduceMotion: Bool = false) throws -> Bool {
        driver.update(node: try node(), reduceMotion: reduceMotion, at: model.frameClock())
    }

    @discardableResult
    func show(_ driver: SwitcherDriver, reduceMotion: Bool = false) throws -> Bool {
        driver.update(node: try node(), reduceMotion: reduceMotion, at: model.frameClock())
    }

    /// `w` drawn through NodeView at scale 1 (the real clock, at rest).
    func draw(width: CGFloat, height: CGFloat) throws -> Pixels {
        model.frameClock = { OrcaPageModel.milliseconds(Date()) }
        let renderer = ImageRenderer(content: NodeView(id: "w", model: model)
            .frame(width: width, height: height, alignment: .topLeading))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}
#endif
