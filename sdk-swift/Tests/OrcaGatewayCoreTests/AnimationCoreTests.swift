import XCTest

@testable import OrcaGatewayCore

/// The pure animation core: curves, controller, registry and implicit
/// animation, with a number for "now" (milliseconds).
final class AnimationCoreTests: XCTestCase {
    // MARK: Curves

    /// Flutter's own `Curves.<name>.transform(t)` at t = 0, 0.25, 0.5, 0.75, 1,
    /// printed by a throwaway `flutter test` over
    /// `packages/flutter/lib/src/animation/curves.dart` (the names are the
    /// cases of `_parseCurve`, `sdk/lib/src/builders/layout_builders.dart:822-875`).
    private static let oracle: [(String, [Double])] = [
        ("linear", [0.0, 0.25, 0.5, 0.75, 1.0]),
        ("easeIn", [0.0, 0.09407757222652435, 0.31640625, 0.6219428777694702, 1.0]),
        ("easeOut", [0.0, 0.3780571222305298, 0.68359375, 0.9059224277734756, 1.0]),
        ("easeInOut", [0.0, 0.12868531048297882, 0.5, 0.8713146895170212, 1.0]),
        ("decelerate", [0.0, 0.4375, 0.75, 0.9375, 1.0]),
        ("bounceIn", [0.0, 0.02734375, 0.234375, 0.52734375, 1.0]),
        ("bounceOut", [0.0, 0.47265625, 0.765625, 0.97265625, 1.0]),
        ("bounceInOut", [0.0, 0.1171875, 0.5, 0.8828125, 1.0]),
        ("elasticIn", [0.0, 0.0039062499999999952, 1.1481063742006436e-17, -0.12500000000000003, 1.0]),
        ("elasticOut", [0.0, 1.125, 1.0, 0.99609375, 1.0]),
        ("elasticInOut", [0.0, 5.740531871003218e-18, 0.5, 1.0, 1.0]),
        ("fastOutSlowIn", [0.0, 0.23698604106903076, 0.7755804806947708, 0.9595602750778198, 1.0]),
        ("ease", [0.0, 0.4094947278499603, 0.8019922554492951, 0.9605494872666895, 1.0]),
        ("easeInSine", [0.0, 0.07055574744939805, 0.29112104445695874, 0.641778564453125, 1.0]),
        ("easeOutSine", [0.0, 0.38462089877575634, 0.7361679568886756, 0.9438758566975594, 1.0]),
        ("easeInOutSine", [0.0, 0.13703918457031247, 0.502783190459013, 0.8669293820858001, 1.0]),
        ("easeInQuad", [0.0, 0.0740315055847168, 0.2556095013022423, 0.5967816352844239, 1.0]),
        ("easeOutQuad", [0.0, 0.45368375778198244, 0.7711302757263183, 0.9363017678260803, 1.0]),
        ("easeInOutQuad", [0.0, 0.12958908081054688, 0.5141134391352534, 0.8785284233093262, 1.0]),
        ("easeInCubic", [0.0, 0.0384702491760254, 0.14525883290916683, 0.4469313845038414, 1.0]),
        ("easeOutCubic", [0.0, 0.5991595584154129, 0.8751163475867361, 0.9760727959871291, 1.0]),
        ("easeInOutCubic", [0.0, 0.0873946738243103, 0.516875, 0.931120035648346, 1.0]),
        ("easeInQuart", [0.0, 0.015537386899814008, 0.062475943565368654, 0.2749938040971756, 1.0]),
        ("easeOutQuart", [0.0, 0.6995202612876892, 0.9149362006783486, 0.9851705887913704, 1.0]),
        ("easeInOutQuart", [0.0, 0.052356377243995667, 0.59326171875, 0.9563882369548082, 1.0]),
        ("easeInQuint", [0.0, 0.01844727270305157, 0.05488859303295613, 0.18798087537288666, 1.0]),
        ("easeOutQuint", [0.0, 0.7758848145604134, 0.9659188389778137, 0.9973333552479744, 1.0]),
        ("easeInOutQuint", [0.0, 0.04233002848923206, 0.6725625991821289, 0.9661552030593157, 1.0]),
        ("easeInExpo", [0.0, 0.013900599689222873, 0.037226962172426284, 0.12758299738168716, 1.0]),
        ("easeOutExpo", [0.0, 0.8433547019958496, 0.977752685546875, 0.998266932554543, 1.0]),
        ("easeInOutExpo", [0.0, 0.029928013682365417, 0.5, 0.9700719863176346, 1.0]),
        ("easeInCirc", [0.0, 0.03435471374541521, 0.11819791048765184, 0.29891128923743965, 1.0]),
        ("easeOutCirc", [0.0, 0.8417613618075848, 0.9583633197844028, 0.992806018460542, 1.0]),
        ("easeInOutCirc", [0.0, 0.08545319288969042, 0.603654799759388, 0.9247162434039637, 1.0]),
        ("easeInBack", [0.0, -0.0868431091308594, -0.06346484366804361, 0.24055313784629107, 1.0]),
        ("easeOutBack", [0.0, 0.8481117981672287, 1.0674425686150788, 1.0759368389844894, 1.0]),
        ("easeInOutBack", [0.0, -0.08304632082581521, 0.6084384918212892, 1.0890036918222905, 1.0]),
        ("fastLinearToSlowEaseIn", [0.0, 0.9139966368675232, 0.988370418548584, 0.999082577531226, 1.0]),
        ("slowMiddle", [0.0, 0.42831611633300776, 0.5, 0.5716838836669922, 1.0]),
        ("fastEaseInToSlowEaseOut", [0.0, 0.6668229198455811, 0.9423460066318512, 0.9915634170807899, 1.0]),
        ("linearToEaseOut", [0.0, 0.62372185587883, 0.9198041975498199, 0.982636445760727, 1.0]),
        ("easeInToLinear", [0.0, 0.01736355423927307, 0.08019580245018006, 0.37627814412117006, 1.0]),
    ]

    func testCurveTableHoldsExactlyFluttersNames() {
        XCTAssertEqual(Curves.names, Self.oracle.map(\.0))
        XCTAssertEqual(Set(Curves.names).count, Curves.names.count)
    }

    func testEveryCurveMatchesFlutterAtFivePoints() {
        let points = [0.0, 0.25, 0.5, 0.75, 1.0]
        for (name, expected) in Self.oracle {
            for (t, want) in zip(points, expected) {
                XCTAssertEqual(Curves.apply(name, t), want, accuracy: 1e-9, "\(name) at \(t)")
            }
        }
        // Off the five points: a cubic, the three-point cubic, an elastic.
        XCTAssertEqual(Curves.apply("easeInOut", 0.1), 0.01997537910938263, accuracy: 1e-9)
        XCTAssertEqual(Curves.apply("fastEaseInToSlowEaseOut", 0.1), 0.23856930012628438, accuracy: 1e-9)
        XCTAssertEqual(Curves.apply("elasticOut", 0.1), 1.0, accuracy: 1e-9)
    }

    func testMissingOrUnknownCurveIsEaseInOut() {
        for t in [0.1, 0.25, 0.6, 0.9] {
            XCTAssertEqual(Curves.apply(nil, t), Curves.apply("easeInOut", t))
            XCTAssertEqual(Curves.apply("wobble", t), Curves.apply("easeInOut", t))
        }
    }

    func testCurveInputIsClamped() {
        for name in Curves.names {
            XCTAssertEqual(Curves.apply(name, -0.5), 0, name)
            XCTAssertEqual(Curves.apply(name, 1.5), 1, name)
        }
    }

    // MARK: Duration

    func testDurationParsing() {
        XCTAssertEqual(AnimationDuration.milliseconds(nil, default: 300), 300)
        XCTAssertEqual(AnimationDuration.milliseconds(.null, default: 300), 300)
        XCTAssertEqual(AnimationDuration.milliseconds(500, default: 300), 500)
        XCTAssertEqual(AnimationDuration.milliseconds(.double(250), default: 300), 250)
        XCTAssertEqual(AnimationDuration.milliseconds("fast", default: 300), 300)
        XCTAssertEqual(AnimationDuration.milliseconds(0, default: 300), 0)
        XCTAssertEqual(AnimationDuration.milliseconds(-40, default: 300), 0)
    }

    // MARK: Controller

    private func controller(_ duration: Double = 300, curve: String? = "linear", repeats: Bool = false,
                            reverses: Bool = false, reduceMotion: Bool = false) -> AnimationController {
        AnimationController(durationMs: duration, curve: curve, repeats: repeats, reverses: reverses,
                            reduceMotion: reduceMotion)
    }

    func test_B12_1_forwardReachesTheMidpointAndCompletesOnce() {
        var c = controller()
        XCTAssertEqual(c.value(at: 0), 0)
        XCTAssertEqual(c.status(at: 0), .dismissed)
        XCTAssertFalse(c.isRunning(at: 0))

        c.forward(at: 1000)
        XCTAssertEqual(c.value(at: 1150), 0.5, accuracy: 1e-12)
        XCTAssertEqual(c.status(at: 1150), .forward)
        XCTAssertTrue(c.isRunning(at: 1150))
        XCTAssertFalse(c.takeCompletion(at: 1150))

        XCTAssertEqual(c.value(at: 1300), 1)
        XCTAssertEqual(c.status(at: 1300), .completed)
        XCTAssertFalse(c.isRunning(at: 1300))
        XCTAssertTrue(c.takeCompletion(at: 1300))
        XCTAssertFalse(c.takeCompletion(at: 1300))
        XCTAssertFalse(c.takeCompletion(at: 9000))
        XCTAssertEqual(c.value(at: 9000), 1)
    }

    func test_B12_1_forwardAlwaysRestartsFromZero() {
        var c = controller()
        c.forward(at: 0)
        c.forward(at: 200)
        XCTAssertEqual(c.value(at: 200), 0)
        XCTAssertEqual(c.value(at: 350), 0.5, accuracy: 1e-12)
        XCTAssertFalse(c.takeCompletion(at: 350))
        XCTAssertTrue(c.takeCompletion(at: 500))
        // Again from the completed end: a second run, a second completion.
        c.forward(at: 600)
        XCTAssertEqual(c.value(at: 600), 0)
        XCTAssertTrue(c.takeCompletion(at: 900))
        XCTAssertFalse(c.takeCompletion(at: 900))
    }

    func test_B12_1_reverseFromTheMiddleTakesValueTimesDurationAndCompletesAtZero() {
        var c = controller()
        c.forward(at: 0)
        c.reverse(at: 150)
        XCTAssertEqual(c.value(at: 150), 0.5, accuracy: 1e-12)
        XCTAssertEqual(c.value(at: 225), 0.25, accuracy: 1e-12)
        XCTAssertEqual(c.status(at: 225), .reverse)
        XCTAssertFalse(c.takeCompletion(at: 225))
        XCTAssertEqual(c.value(at: 300), 0)
        XCTAssertEqual(c.status(at: 300), .dismissed)
        XCTAssertTrue(c.takeCompletion(at: 300))
        XCTAssertFalse(c.takeCompletion(at: 300))
    }

    func test_B12_1_reverseFromTheEndTakesTheFullDuration() {
        var c = controller()
        c.forward(at: 0)
        XCTAssertTrue(c.takeCompletion(at: 300))
        c.reverse(at: 1000)
        XCTAssertEqual(c.value(at: 1150), 0.5, accuracy: 1e-12)
        XCTAssertTrue(c.takeCompletion(at: 1300))
    }

    func test_B12_1_reverseAtZeroDoesNothing() {
        var c = controller()
        c.reverse(at: 100)
        XCTAssertFalse(c.isRunning(at: 100))
        XCTAssertEqual(c.status(at: 100), .dismissed)
        XCTAssertFalse(c.takeCompletion(at: 100))
        XCTAssertFalse(c.takeCompletion(at: 5000))
    }

    func test_B12_1_aRepeatNeverCompletes() {
        var c = controller(repeats: true)
        c.start(at: 0)
        XCTAssertEqual(c.value(at: 150), 0.5, accuracy: 1e-12)
        XCTAssertEqual(c.value(at: 450), 0.5, accuracy: 1e-12)
        XCTAssertEqual(c.status(at: 450), .forward)
        XCTAssertTrue(c.isRunning(at: 100_000))
        XCTAssertFalse(c.takeCompletion(at: 300))
        XCTAssertFalse(c.takeCompletion(at: 100_000))

        var pingPong = controller(repeats: true, reverses: true)
        pingPong.start(at: 0)
        XCTAssertEqual(pingPong.value(at: 75), 0.25, accuracy: 1e-12)
        XCTAssertEqual(pingPong.value(at: 375), 0.75, accuracy: 1e-12)
        XCTAssertEqual(pingPong.status(at: 375), .reverse)
        XCTAssertEqual(pingPong.value(at: 675), 0.25, accuracy: 1e-12)
        XCTAssertFalse(pingPong.takeCompletion(at: 100_000))
    }

    func test_B12_1_forwardOnARepeatingBuilderPlaysOnce() {
        var c = controller(repeats: true, reverses: true)
        c.start(at: 0)
        c.forward(at: 1000)
        XCTAssertEqual(c.value(at: 1000), 0)
        XCTAssertEqual(c.value(at: 1150), 0.5, accuracy: 1e-12)
        XCTAssertEqual(c.value(at: 1300), 1)
        XCTAssertEqual(c.value(at: 2050), 1)
        XCTAssertFalse(c.isRunning(at: 2050))
        XCTAssertTrue(c.takeCompletion(at: 1300))
        XCTAssertFalse(c.takeCompletion(at: 2050))
    }

    func test_B12_1_startOnAOneShotIsForward() {
        var c = controller()
        c.start(at: 10)
        XCTAssertEqual(c.value(at: 160), 0.5, accuracy: 1e-12)
        XCTAssertTrue(c.takeCompletion(at: 310))
    }

    func test_B12_1_progressIsTheValueAfterTheCurve() {
        var eased = controller(curve: "easeInOut")
        eased.forward(at: 0)
        XCTAssertEqual(eased.value(at: 75), 0.25, accuracy: 1e-12)
        XCTAssertEqual(eased.progress(at: 75), 0.12868531048297882, accuracy: 1e-9)
        XCTAssertEqual(eased.progress(at: 150), 0.5, accuracy: 1e-9)

        var byDefault = controller(curve: nil)
        byDefault.forward(at: 0)
        XCTAssertEqual(byDefault.progress(at: 75), eased.progress(at: 75))
    }

    func test_B12_7_S_reducedMotionControllerJumpsAndCompletesOnce() {
        var c = controller(reduceMotion: true)
        c.start(at: 0)
        XCTAssertEqual(c.value(at: 0), 1)
        XCTAssertEqual(c.progress(at: 0), 1)
        XCTAssertEqual(c.status(at: 0), .completed)
        XCTAssertFalse(c.isRunning(at: 0))
        XCTAssertTrue(c.takeCompletion(at: 0))
        XCTAssertFalse(c.takeCompletion(at: 0))

        c.reverse(at: 5)
        XCTAssertEqual(c.value(at: 5), 0)
        XCTAssertEqual(c.status(at: 5), .dismissed)
        XCTAssertTrue(c.takeCompletion(at: 5))
        XCTAssertFalse(c.takeCompletion(at: 5))
    }

    func test_B12_7_S_reducedMotionRepeatingBuilderRestsAtOne() {
        var c = controller(repeats: true, reverses: true, reduceMotion: true)
        c.start(at: 0)
        XCTAssertEqual(c.value(at: 0), 1)
        XCTAssertEqual(c.value(at: 450), 1)
        XCTAssertFalse(c.isRunning(at: 450))
        XCTAssertFalse(c.takeCompletion(at: 450))
    }

    func test_B12_7_S_aZeroDurationJumpsLikeReducedMotion() {
        var c = controller(0)
        c.forward(at: 7)
        XCTAssertEqual(c.value(at: 7), 1)
        XCTAssertTrue(c.takeCompletion(at: 7))
        var looping = controller(0, repeats: true)
        looping.start(at: 0)
        XCTAssertEqual(looping.value(at: 50), 1)
        XCTAssertFalse(looping.isRunning(at: 50))
    }

    // MARK: Registry

    func test_B12_1_registryForwardAndReverseDriveTheNamedController() {
        let registry = AnimationRegistry()
        let owner = registry.makeOwner()
        registry.register(id: "pulse", owner: owner, controller: controller(curve: "easeInOut"))

        XCTAssertTrue(registry.forward(id: "pulse", at: 0))
        XCTAssertEqual(registry.progress(id: "pulse", at: 75), 0.12868531048297882, accuracy: 1e-9)
        XCTAssertEqual(registry.controller(id: "pulse", owner: owner)?.value(at: 150) ?? -1, 0.5, accuracy: 1e-12)
        XCTAssertTrue(registry.reverse(id: "pulse", at: 150))
        XCTAssertEqual(registry.controller(id: "pulse", owner: owner)?.value(at: 225) ?? -1, 0.25, accuracy: 1e-12)

        // The owner drains the completion through the registry.
        XCTAssertEqual(registry.update(id: "pulse", owner: owner) { $0.takeCompletion(at: 300) }, true)
        XCTAssertEqual(registry.update(id: "pulse", owner: owner) { $0.takeCompletion(at: 300) }, false)
    }

    func test_B12_1_registryUnknownIdDoesNothing() {
        let registry = AnimationRegistry()
        XCTAssertFalse(registry.forward(id: "nope", at: 0))
        XCTAssertFalse(registry.reverse(id: "nope", at: 0))
        XCTAssertEqual(registry.progress(id: "nope", at: 100), 0)
        XCTAssertNil(registry.controller(id: "nope", owner: registry.makeOwner()))
    }

    func test_B12_1_registryLastRegistrationOwnsTheId() {
        let registry = AnimationRegistry()
        let first = registry.makeOwner()
        let second = registry.makeOwner()
        XCTAssertNotEqual(first, second)
        registry.register(id: "x", owner: first, controller: controller(300))
        registry.register(id: "x", owner: second, controller: controller(100))

        XCTAssertNil(registry.controller(id: "x", owner: first))
        XCTAssertNil(registry.update(id: "x", owner: first) { $0.takeCompletion(at: 0) })
        XCTAssertNotNil(registry.controller(id: "x", owner: second))

        // The first builder leaves: the newer entry stays (not Flutter's q1).
        registry.unregister(id: "x", owner: first)
        XCTAssertTrue(registry.forward(id: "x", at: 0))
        XCTAssertEqual(registry.progress(id: "x", at: 50), 0.5, accuracy: 1e-12)

        registry.unregister(id: "x", owner: second)
        XCTAssertFalse(registry.forward(id: "x", at: 0))
        XCTAssertEqual(registry.progress(id: "x", at: 50), 0)
    }

    // MARK: Implicit animation

    func test_B12_2_firstTargetIsShownWithNoAnimation() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear")
        XCTAssertEqual(a.value(at: 0), [:])
        XCTAssertFalse(a.retarget(to: ["width": 100, "color": "#FF0000"], at: 0))
        XCTAssertFalse(a.isRunning(at: 0))
        XCTAssertEqual(a.value(at: 0), ["width": 100, "color": "#FF0000"])
        XCTAssertEqual(a.value(at: 150), ["width": 100, "color": "#FF0000"])
    }

    func test_B12_2_widthAndColourAt150Of300Linear() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear")
        a.retarget(to: ["width": 100, "color": "#FF0000"], at: 0)
        XCTAssertTrue(a.retarget(to: ["width": 200, "color": "#0000FF"], at: 1000))
        XCTAssertTrue(a.isRunning(at: 1150))
        let mid = a.value(at: 1150)
        XCTAssertEqual(mid["width"]?.doubleValue ?? -1, 150, accuracy: 1e-9)
        XCTAssertEqual(mid["color"], "#800080FF")
        XCTAssertEqual(a.value(at: 1000)["width"]?.doubleValue ?? -1, 100, accuracy: 1e-9)
        // The end is the target as it was sent.
        XCTAssertFalse(a.isRunning(at: 1300))
        XCTAssertEqual(a.value(at: 1300), ["width": 200, "color": "#0000FF"])
    }

    func test_B12_2_widthAndColourEaseInOut() {
        var a = ImplicitAnimation(durationMs: 300, curve: "easeInOut")
        a.retarget(to: ["width": 100, "color": "#000000"], at: 0)
        a.retarget(to: ["width": 200, "color": "#FFFFFF80"], at: 0)
        // easeInOut(0.5) = 0.5; easeInOut(0.25) = 0.128685 (Flutter).
        XCTAssertEqual(a.value(at: 150)["width"]?.doubleValue ?? -1, 150, accuracy: 1e-6)
        XCTAssertEqual(a.value(at: 150)["color"], "#808080C0")
        XCTAssertEqual(a.value(at: 75)["width"]?.doubleValue ?? -1, 112.868531048297882, accuracy: 1e-6)
        // 255 * 0.128685 = 32.8 -> 0x21; alpha 255 - 127 * 0.128685 = 238.7 -> 0xEF.
        XCTAssertEqual(a.value(at: 75)["color"], "#212121EF")

        var byDefault = ImplicitAnimation(durationMs: 300, curve: nil)
        byDefault.retarget(to: ["width": 100], at: 0)
        byDefault.retarget(to: ["width": 200], at: 0)
        XCTAssertEqual(byDefault.value(at: 75)["width"], a.value(at: 75)["width"])
    }

    func test_B12_2_aNewTargetMidRunStartsFromTheValueOnScreen() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear")
        a.retarget(to: ["width": 100], at: 0)
        a.retarget(to: ["width": 200], at: 1000)
        XCTAssertTrue(a.retarget(to: ["width": 300], at: 1150))
        XCTAssertEqual(a.value(at: 1150)["width"]?.doubleValue ?? -1, 150, accuracy: 1e-9)
        XCTAssertEqual(a.value(at: 1300)["width"]?.doubleValue ?? -1, 225, accuracy: 1e-9)
        XCTAssertTrue(a.isRunning(at: 1449))
        XCTAssertFalse(a.isRunning(at: 1450))
        XCTAssertEqual(a.value(at: 1450), ["width": 300])
    }

    func test_B12_2_theSameTargetAgainDoesNotRestart() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear")
        a.retarget(to: ["width": 100], at: 0)
        a.retarget(to: ["width": 200], at: 0)
        XCTAssertFalse(a.retarget(to: ["width": 200], at: 150))
        XCTAssertEqual(a.value(at: 150)["width"]?.doubleValue ?? -1, 150, accuracy: 1e-9)
    }

    func test_B12_2_paddingAndDecorationMix() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear")
        a.retarget(to: [
            "padding": ["top": 0, "left": 10],
            "decoration": ["color": "#000000", "borderRadius": 4,
                           "border": ["color": "#FF0000", "width": 1], "gradient": "g1"],
        ], at: 0)
        a.retarget(to: [
            "padding": ["top": 20, "right": 8, "bottom": 4, "left": 10],
            "decoration": ["color": "#FFFFFF", "borderRadius": 12,
                           "border": ["color": "#0000FF", "width": 3], "gradient": "g2"],
        ], at: 0)
        let mid = a.value(at: 150)
        XCTAssertEqual(mid["padding"], ["top": 10.0, "right": 4.0, "bottom": 2.0, "left": 10.0])
        XCTAssertEqual(mid["decoration"]?["color"], "#808080FF")
        XCTAssertEqual(mid["decoration"]?["borderRadius"], 8.0)
        XCTAssertEqual(mid["decoration"]?["border"]["width"], 2.0)
        XCTAssertEqual(mid["decoration"]?["border"]["color"], "#800080FF")
        // A part with no mix (gradient) is the target's from the start.
        XCTAssertEqual(mid["decoration"]?["gradient"], "g2")
        XCTAssertEqual(a.value(at: 0)["decoration"]?["gradient"], "g2")
    }

    func test_B12_2_cornerRadiusMixesPerCornerWhenASideIsAnObject() {
        let mixed = AnimationMix.decoration(["borderRadius": 4], ["borderRadius": ["topLeft": 12, "bottomRight": 8]], 0.5)
        XCTAssertEqual(mixed?["borderRadius"],
                       ["topLeft": 8.0, "topRight": 2.0, "bottomLeft": 2.0, "bottomRight": 6.0])
    }

    func test_B12_2_aNullSideOrAnUnmixableValueSnapsAtTheStart() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear")
        a.retarget(to: ["width": 100, "color": .null, "label": "old", "height": 10], at: 0)
        a.retarget(to: ["width": .null, "color": "#FF0000", "label": "new", "margin": ["top": 8]], at: 0)
        let start = a.value(at: 0)
        XCTAssertEqual(start, ["width": .null, "color": "#FF0000", "label": "new", "margin": ["top": 8]])
        XCTAssertNil(start["height"])
        XCTAssertEqual(a.value(at: 150), start)
    }

    func test_B12_3_opacityAt150Of300() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear")
        a.retarget(to: ["opacity": 0], at: 0)
        a.retarget(to: ["opacity": 1], at: 500)
        XCTAssertEqual(a.value(at: 650)["opacity"]?.doubleValue ?? -1, 0.5, accuracy: 1e-9)

        var eased = ImplicitAnimation(durationMs: 300, curve: "easeInOut")
        eased.retarget(to: ["opacity": 0], at: 0)
        eased.retarget(to: ["opacity": 1], at: 500)
        XCTAssertEqual(eased.value(at: 650)["opacity"]?.doubleValue ?? -1, 0.5, accuracy: 1e-6)
        XCTAssertEqual(eased.value(at: 575)["opacity"]?.doubleValue ?? -1, 0.12868531048297882, accuracy: 1e-9)
    }

    func test_B12_3_alignmentAt150Of300() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear")
        a.retarget(to: ["alignment": "topLeft"], at: 0)
        a.retarget(to: ["alignment": "bottomRight"], at: 0)
        XCTAssertEqual(a.value(at: 150)["alignment"], ["x": 0.0, "y": 0.0])
        XCTAssertEqual(a.value(at: 75)["alignment"], ["x": -0.5, "y": -0.5])
        XCTAssertEqual(a.value(at: 300)["alignment"], "bottomRight")

        var eased = ImplicitAnimation(durationMs: 300, curve: "easeInOut")
        eased.retarget(to: ["alignment": "centerLeft"], at: 0)
        eased.retarget(to: ["alignment": "topRight"], at: 0)
        let quarter = eased.value(at: 75)["alignment"]
        XCTAssertEqual(quarter?["x"].doubleValue ?? -9, -1 + 2 * 0.12868531048297882, accuracy: 1e-9)
        XCTAssertEqual(quarter?["y"].doubleValue ?? -9, -0.12868531048297882, accuracy: 1e-9)

        // Mid-run retarget: the x/y pair on screen is a valid start.
        XCTAssertTrue(a.retarget(to: ["alignment": "center"], at: 75))
        XCTAssertEqual(a.value(at: 225)["alignment"], ["x": -0.25, "y": -0.25])
    }

    func testAlignmentNames() {
        let names: [(String, Double, Double)] = [
            ("topLeft", -1, -1), ("topCenter", 0, -1), ("topRight", 1, -1),
            ("centerLeft", -1, 0), ("center", 0, 0), ("centerRight", 1, 0),
            ("bottomLeft", -1, 1), ("bottomCenter", 0, 1), ("bottomRight", 1, 1),
            ("sideways", 0, 0),
        ]
        for (name, x, y) in names {
            let point = AnimationMix.alignmentPoint(.string(name))
            XCTAssertEqual(point?.x, x, name)
            XCTAssertEqual(point?.y, y, name)
        }
        XCTAssertEqual(AnimationMix.alignmentPoint(["x": 0.5, "y": -0.25])?.x, 0.5)
        XCTAssertNil(AnimationMix.alignmentPoint(.null))
        XCTAssertNil(AnimationMix.alignmentPoint(3))
    }

    func testColourMixReadsCssOrderAndWritesEightDigits() {
        XCTAssertEqual(AnimationMix.color("#FF0000", "#0000FF", 0), "#FF0000FF")
        XCTAssertEqual(AnimationMix.color("#FF0000", "#0000FF", 1), "#0000FFFF")
        XCTAssertEqual(AnimationMix.color("#FF000000", "#FF0000FF", 0.5), "#FF000080")
        XCTAssertNil(AnimationMix.color("red", "#0000FF", 0.5))
        XCTAssertNil(AnimationMix.color("#FFF", "#0000FF", 0.5))
        XCTAssertEqual(AnimationMix.number(10, 20, 0.25), 12.5)
    }

    func test_B12_7_S_reducedMotionImplicitShowsTheEndStateAtOnce() {
        var a = ImplicitAnimation(durationMs: 300, curve: "linear", reduceMotion: true)
        a.retarget(to: ["width": 100, "opacity": 0, "alignment": "topLeft"], at: 0)
        let target: [String: JSONValue] = ["width": 200, "opacity": 1, "alignment": "bottomRight"]
        a.retarget(to: target, at: 1000)
        XCTAssertFalse(a.isRunning(at: 1000))
        XCTAssertEqual(a.value(at: 1000), target)
        XCTAssertEqual(a.value(at: 1150), target)
    }

    func test_B12_7_S_aZeroDurationImplicitJumps() {
        var a = ImplicitAnimation(durationMs: 0, curve: "linear")
        a.retarget(to: ["width": 100], at: 0)
        a.retarget(to: ["width": 200], at: 10)
        XCTAssertFalse(a.isRunning(at: 10))
        XCTAssertEqual(a.value(at: 10), ["width": 200])
    }
}
