#if canImport(SwiftUI)
import Combine
import SwiftUI
import XCTest

@testable import OrcaGateway

/// AnimatedBuilder's clock (Flutter `forward` / `repeat(reverse:)`), its
/// curves, and the builder driven by `animateForward` / `animateReverse`
/// through the page's registry. The clock is a number the test moves: the
/// driver takes "now" in milliseconds wherever the view passes a frame date.
@MainActor
final class MotionTests: XCTestCase {
    /// The clock is the core's `AnimationController`: `start` is Flutter's
    /// `forward()` or, on a repeating builder, `repeat(reverse:)`.
    func testOneShotClampsAtTheEnd() {
        var controller = AnimationController(durationMs: 1000, repeats: false, reverses: false)
        controller.start(at: 0)
        XCTAssertEqual(controller.value(at: 500), 0.5)
        XCTAssertEqual(controller.value(at: 3000), 1)
    }

    func testRepeatWrapsAndReverseBouncesBack() {
        var wrapping = AnimationController(durationMs: 1000, repeats: true, reverses: false)
        wrapping.start(at: 0)
        XCTAssertEqual(wrapping.value(at: 1250), 0.25, accuracy: 1e-9)
        var bouncing = AnimationController(durationMs: 1000, repeats: true, reverses: true)
        bouncing.start(at: 0)
        XCTAssertEqual(bouncing.value(at: 1250), 0.75, accuracy: 1e-9)
    }

    func testNoAutoStartHoldsAtZero() {
        let controller = AnimationController(durationMs: 1000, repeats: true, reverses: false)
        XCTAssertEqual(controller.value(at: 5000), 0)
    }

    /// The curves are the core's now (the UI's own table is gone).
    func testCurvesKeepTheirEndsAndShape() {
        for name in ["linear", "easeIn", "easeOut", "easeInOut", "fastOutSlowIn"] {
            XCTAssertEqual(Curves.apply(name, 0), 0)
            XCTAssertEqual(Curves.apply(name, 1), 1)
        }
        XCTAssertLessThan(Curves.apply("easeIn", 0.5), 0.5)
        XCTAssertGreaterThan(Curves.apply("easeOut", 0.5), 0.5)
        XCTAssertEqual(Curves.apply("easeInOut", 0.5), 0.5, accuracy: 1e-3)
    }

    // MARK: B12.1 the controlled builder

    /// `autoStart: false`: the builder rests at 0, needs no frame, and its
    /// child's tween naming the id shows `begin` (render fixture 67).
    func test_B12_1_autoStartFalseStaysAtBegin() throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "easeOut", "autoStart": false])
        let driver = try stage.builder()
        for at in [1000.0, 1200, 5000] {
            XCTAssertEqual(driver.progress(at: at), 0)
            XCTAssertFalse(driver.needsTick(at: at))
            stage.now = at
            XCTAssertEqual(stage.width(under: driver), 0.25)
        }
        XCTAssertNil(driver.settle(at: 5000))
        XCTAssertEqual(stage.completions, 0)
    }

    /// A forward effect starts it; the midpoint is the core's curved value;
    /// `onComplete` fires once at the end and the builder stops ticking.
    func test_B12_1_forwardEffectRunsToTheEndAndCompletesOnce() async throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "easeOut", "autoStart": false])
        let driver = try stage.builder()
        var wakes = 0
        let woken = driver.objectWillChange.sink { wakes += 1 }
        defer { woken.cancel() }

        stage.now = 2000
        stage.model.perform(ActionEffect("animateForward", ["animationId": "pulse"]))
        XCTAssertEqual(wakes, 1, "the paused builder was not woken")
        XCTAssertTrue(driver.needsTick(at: 2000))

        stage.now = 2200
        let mid = Curves.apply("easeOut", 0.5)
        XCTAssertEqual(driver.progress(at: 2200), mid, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(stage.width(under: driver)), 0.25 + 0.75 * mid, accuracy: 1e-9)
        XCTAssertNil(driver.settle(at: 2200), "completed before the end")

        stage.now = 2400
        XCTAssertEqual(driver.progress(at: 2400), 1)
        XCTAssertTrue(driver.needsTick(at: 2400), "the frame that reports the end is still needed")
        await driver.settle(at: 2400)?.value
        XCTAssertEqual(stage.completions, 1)
        XCTAssertNil(driver.settle(at: 2500))
        XCTAssertFalse(driver.needsTick(at: 2500))
        XCTAssertEqual(stage.completions, 1)
    }

    /// Reverse runs back to `begin` and fires `onComplete` again; a reverse
    /// at 0 does nothing.
    func test_B12_1_reverseReturnsToBeginAndCompletesAgain() async throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "easeOut", "autoStart": false])
        let driver = try stage.builder()
        stage.now = 0
        stage.model.perform(ActionEffect("animateForward", ["animationId": "pulse"]))
        await driver.settle(at: 400)?.value
        XCTAssertEqual(stage.completions, 1)

        stage.now = 1000
        stage.model.perform(ActionEffect("animateReverse", ["animationId": "pulse"]))
        XCTAssertTrue(driver.needsTick(at: 1000))
        XCTAssertEqual(driver.progress(at: 1200), Curves.apply("easeOut", 0.5), accuracy: 1e-12)
        XCTAssertEqual(driver.progress(at: 1400), 0)
        stage.now = 1400
        XCTAssertEqual(stage.width(under: driver), 0.25)
        await driver.settle(at: 1400)?.value
        XCTAssertEqual(stage.completions, 2)

        stage.now = 2000
        stage.model.perform(ActionEffect("animateReverse", ["animationId": "pulse"]))
        XCTAssertFalse(driver.needsTick(at: 2000))
        XCTAssertNil(driver.settle(at: 2600))
        XCTAssertEqual(stage.completions, 2)
    }

    /// An id no builder has, or no id at all: nothing moves, nobody is woken
    /// and the effect is not passed on to the host.
    func test_B12_1_unknownIdDoesNothing() throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "autoStart": false])
        let driver = try stage.builder()
        var wakes = 0
        let woken = driver.objectWillChange.sink { wakes += 1 }
        defer { woken.cancel() }
        var passedOn: [String] = []
        stage.model.effectHandler = { passedOn.append($0.type) }

        stage.model.perform(ActionEffect("animateForward", ["animationId": "ghost"]))
        stage.model.perform(ActionEffect("animateReverse", ["animationId": "ghost"]))
        stage.model.perform(ActionEffect("animateForward"))
        XCTAssertEqual(wakes, 0)
        XCTAssertEqual(passedOn, [])
        XCTAssertFalse(driver.needsTick(at: 100))
        XCTAssertEqual(driver.progress(at: 100), 0)
    }

    /// Two builders with one id: the last one owns it, and the first leaving
    /// does not remove it (Flutter removes whatever sits under the id).
    func test_B12_1_twoBuildersOneIdTheLastOwnsIt() throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "linear", "autoStart": false])
        let first = try stage.builder()
        let second = try stage.builder()

        stage.model.perform(ActionEffect("animateForward", ["animationId": "pulse"]))
        XCTAssertEqual(second.progress(at: 200), 0.5, accuracy: 1e-12)
        XCTAssertEqual(first.progress(at: 200), 0, "the first builder no longer owns the id")

        first.disappear()
        stage.now = 1000
        stage.model.perform(ActionEffect("animateForward", ["animationId": "pulse"]))
        XCTAssertEqual(second.progress(at: 1100), 0.25, accuracy: 1e-12)
        XCTAssertEqual(stage.model.animations.progress(id: "pulse", at: 1100), 0.25, accuracy: 1e-12)

        second.disappear()
        XCTAssertFalse(stage.model.animations.forward(id: "pulse", at: 2000), "the owner leaving removes the id")
    }

    /// A builder whose id a later builder takes keeps its own controller as
    /// it was: forwarded to 1 it stays at 1, and the completion it reported
    /// is not reported again.
    func test_B12_1_aDisplacedBuilderKeepsItsValueAndItsCompletions() async throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "linear", "autoStart": false])
        let first = try stage.builder()
        stage.now = 0
        stage.model.perform(ActionEffect("animateForward", ["animationId": "pulse"]))
        await first.settle(at: 400)?.value
        XCTAssertEqual(stage.completions, 1)

        _ = try stage.builder(at: 500)
        XCTAssertEqual(first.progress(at: 600), 1, "the displaced builder snapped back")
        XCTAssertFalse(first.needsTick(at: 600))
        XCTAssertNil(first.settle(at: 600))
        XCTAssertEqual(stage.completions, 1)
    }

    /// `autoStart`, the run already reported, then displaced: `onComplete`
    /// does not fire a second time.
    func test_B12_1_aDisplacedAutoStartBuilderDoesNotCompleteTwice() async throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "linear"])
        let first = try stage.builder(at: 0)
        await first.settle(at: 400)?.value
        XCTAssertEqual(stage.completions, 1)

        _ = try stage.builder(at: 500)
        XCTAssertEqual(first.progress(at: 600), 1)
        XCTAssertFalse(first.needsTick(at: 600))
        XCTAssertNil(first.settle(at: 600))
        XCTAssertEqual(stage.completions, 1)
    }

    /// Displaced in the middle of a run an effect started: the builder
    /// finishes that run on its own controller and completes once.
    func test_B12_1_aBuilderDisplacedMidRunFinishesAndCompletesOnce() async throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "linear", "autoStart": false])
        let first = try stage.builder()
        stage.now = 0
        stage.model.perform(ActionEffect("animateForward", ["animationId": "pulse"]))

        _ = try stage.builder(at: 100)
        XCTAssertEqual(first.progress(at: 200), 0.5, accuracy: 1e-12)
        XCTAssertTrue(first.needsTick(at: 200))
        XCTAssertNil(first.settle(at: 200))
        XCTAssertEqual(first.progress(at: 400), 1)
        await first.settle(at: 400)?.value
        XCTAssertEqual(stage.completions, 1)
        XCTAssertNil(first.settle(at: 500))
        XCTAssertFalse(first.needsTick(at: 500))
        XCTAssertEqual(stage.completions, 1)
    }

    /// The builder's `onComplete` was replaced while it was on screen (an
    /// updateComponent): the run that ends fires the node's current action,
    /// not the one it appeared with.
    func test_B12_1_onCompleteIsTheNodesCurrentAction() async throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "linear", "autoStart": false])
        let driver = try stage.builder()
        var updated = try XCTUnwrap(stage.model.resolve("b"))
        updated.actions["onComplete"] = try JSONValue.object([
            "type": "setState", "scope": "page", "key": "done", "value": ["type": "static", "value": 10],
        ]).decode(Action.self)

        stage.now = 0
        stage.model.perform(ActionEffect("animateForward", ["animationId": "pulse"]))
        await driver.settle(at: 400, node: updated)?.value
        XCTAssertEqual(stage.completions, 10, "the action the builder appeared with was fired")

        // A node that lost its `onComplete` fires nothing.
        updated.actions["onComplete"] = nil
        stage.now = 1000
        stage.model.perform(ActionEffect("animateReverse", ["animationId": "pulse"]))
        XCTAssertNil(driver.settle(at: 1400, node: updated))
        XCTAssertEqual(stage.completions, 10)
    }

    /// A builder with `autoStart` runs once on its own and completes once; a
    /// repeating one never completes.
    func test_B12_1_autoStartRunsOnceAndARepeatNeverCompletes() async throws {
        let once = try Stage(["duration": 200, "curve": "linear"])
        let driver = try once.builder(at: 0)
        XCTAssertEqual(driver.progress(at: 100), 0.5, accuracy: 1e-12)
        await driver.settle(at: 200)?.value
        XCTAssertEqual(once.completions, 1)

        let looping = try Stage(["duration": 200, "curve": "linear", "repeat": true, "reverse": true])
        let loop = try looping.builder(at: 0)
        XCTAssertEqual(loop.progress(at: 250), 0.75, accuracy: 1e-12)
        for at in [200.0, 400, 450, 1000] { XCTAssertNil(loop.settle(at: at)) }
        XCTAssertTrue(loop.needsTick(at: 1000))
        XCTAssertEqual(looping.completions, 0)
    }

    /// A tween naming an id reads that controller and not the builder it sits
    /// under; an id nobody registered is 0.
    func test_B12_1_aTweenNamingAnIdReadsTheRegistry() throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400, "curve": "linear", "autoStart": false],
                              tweenId: "ghost")
        _ = try stage.builder()
        XCTAssertEqual(stage.model.resolve("fade", animationProgress: 0.9)?["width"], 0.25)
        XCTAssertEqual(stage.model.resolve("fade")?["width"], 0.25)
    }

    // MARK: C-curves

    /// A curve outside the UI's old nine is honoured.
    func test_C_curves_S_bounceOutIsHonoured() throws {
        let stage = try Stage(["duration": 400, "curve": "bounceOut"])
        let driver = try stage.builder(at: 0)
        XCTAssertEqual(driver.progress(at: 200), Curves.apply("bounceOut", 0.5), accuracy: 1e-12)
        XCTAssertNotEqual(driver.progress(at: 200), 0.5, accuracy: 1e-3)
    }

    /// No curve, or a name nobody knows, is easeInOut (it was linear).
    func test_C_curves_S_aMissingCurveIsEaseInOut() throws {
        for props: [String: JSONValue] in [["duration": 400], ["duration": 400, "curve": "wobble"]] {
            let driver = try Stage(props).builder(at: 0)
            XCTAssertEqual(driver.progress(at: 100), Curves.apply("easeInOut", 0.25), accuracy: 1e-12)
            XCTAssertLessThan(driver.progress(at: 100), 0.2, "linear would be 0.25")
        }
    }

    /// Every one of the core's 42 names reaches the builder.
    func test_C_curves_S_everyNameReachesTheBuilder() throws {
        XCTAssertEqual(Curves.names.count, 42)
        for name in Curves.names {
            let driver = try Stage(["duration": 400, "curve": .string(name)]).builder(at: 0)
            XCTAssertEqual(driver.progress(at: 120), Curves.apply(name, 0.3), accuracy: 1e-12, name)
        }
    }

    // MARK: B12.7 reduced motion

    /// Reduced motion: the end state at once and one completion.
    func test_B12_7_reducedMotionJumpsToTheEndAndCompletesOnce() async throws {
        let stage = try Stage(["animationId": "pulse", "duration": 400])
        let driver = try stage.builder(at: 0, reduceMotion: true)
        XCTAssertEqual(driver.progress(at: 0), 1)
        XCTAssertEqual(stage.width(under: driver), 1)
        XCTAssertTrue(driver.needsTick(at: 0), "one frame reports the end")
        await driver.settle(at: 0)?.value
        XCTAssertEqual(stage.completions, 1)
        XCTAssertNil(driver.settle(at: 10))
        XCTAssertFalse(driver.needsTick(at: 10))

        stage.now = 50
        stage.model.perform(ActionEffect("animateReverse", ["animationId": "pulse"]))
        XCTAssertEqual(driver.progress(at: 50), 0)
        await driver.settle(at: 50)?.value
        XCTAssertEqual(stage.completions, 2)
    }

    /// Reduced motion on a repeating builder: it rests at 1, no completion.
    func test_B12_7_reducedMotionARepeatingBuilderRestsAtOne() throws {
        let stage = try Stage(["duration": 400, "repeat": true, "reverse": true])
        let driver = try stage.builder(at: 0, reduceMotion: true)
        for at in [0.0, 100, 400, 900] {
            XCTAssertEqual(driver.progress(at: at), 1)
            XCTAssertFalse(driver.needsTick(at: at))
            XCTAssertNil(driver.settle(at: at))
        }
        XCTAssertEqual(stage.completions, 0)
    }

    /// The SDK's key: nil follows the system, a value wins over it.
    func test_B12_7_theReduceMotionKeyOverridesTheSystem() {
        XCTAssertNil(EnvironmentValues().orcaReduceMotion)
        var values = EnvironmentValues()
        values.orcaReduceMotion = true
        XCTAssertEqual(values.orcaReduceMotion, true)
        XCTAssertTrue(OrcaReduceMotion.resolve(override: nil, system: true))
        XCTAssertFalse(OrcaReduceMotion.resolve(override: nil, system: false))
        XCTAssertTrue(OrcaReduceMotion.resolve(override: true, system: false))
        XCTAssertFalse(OrcaReduceMotion.resolve(override: false, system: true))
    }
}

/// A page of one AnimatedBuilder `b` over a Container `fade` whose width is
/// a tween 0.25 to 1 naming `tweenId`; `onComplete` adds 1 to the page state
/// `done`. The page's frame clock reads `now`.
@MainActor
private final class Stage {
    let model: OrcaPageModel
    var now = 0.0

    init(_ props: [String: JSONValue], tweenId: String = "pulse") throws {
        let onComplete: JSONValue = ["type": "setState", "scope": "page", "key": "done", "value": [
            "type": "transform", "input": ["type": "state", "key": "done", "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]
        var tween: [String: JSONValue] = ["type": "tween", "begin": 0.25, "end": 1]
        if props["animationId"] != nil { tween["animationId"] = .string(tweenId) }
        model = try OrcaPageModel(page: JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "done", "scope": "page", "initial": 0]],
            "components": [
                ["id": "b", "type": "AnimatedBuilder", "kind": "layout", "childMode": "multi",
                 "props": .object(props), "actions": ["onComplete": onComplete],
                 "children": ["fade"], "watches": []],
                ["id": "fade", "type": "Container", "kind": "layout", "childMode": "single",
                 "props": ["width": .object(tween)], "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self))
        model.frameClock = { [unowned self] in self.now }
    }

    /// A builder for node `b`, on screen since `at`.
    func builder(at: Double = 0, reduceMotion: Bool = false) throws -> AnimatedBuilderDriver {
        let driver = AnimatedBuilderDriver(model: model)
        driver.appear(node: try XCTUnwrap(model.resolve("b")), reduceMotion: reduceMotion, at: at)
        return driver
    }

    /// The child's width as the view resolves it under `driver` at `now`.
    func width(under driver: AnimatedBuilderDriver) -> Double? {
        model.resolve("fade", animationProgress: driver.progress(at: now))?["width"]?.doubleValue
    }

    var completions: Int { model.store.value("done").intValue ?? -1 }
}
#endif
