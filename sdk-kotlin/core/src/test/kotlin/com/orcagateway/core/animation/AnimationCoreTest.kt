package com.orcagateway.core.animation

import com.orcagateway.core.json.JsonValue
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * The pure animation core of step 12: the curve table, the controller and
 * its registry, and the implicit animation with its mixes. Time is always a
 * number of milliseconds handed in, so every midpoint is exact.
 */
class AnimationCoreTest {
    // MARK: Curves

    /**
     * Flutter's own numbers: `Curves.<name>.transform(t)` at t = 0, 0.25,
     * 0.5, 0.75, 1, printed by a `flutter test` run on Flutter 3.50.0
     * (packages/flutter/lib/src/animation/curves.dart), in the order of the
     * SDK's `_parseCurve` (sdk/lib/src/builders/layout_builders.dart:822-875).
     */
    private val flutter: List<Pair<String, DoubleArray>> = listOf(
        "linear" to doubleArrayOf(0.0, 0.25, 0.5, 0.75, 1.0),
        "easeIn" to doubleArrayOf(0.0, 0.09407757222652435, 0.31640625, 0.6219428777694702, 1.0),
        "easeOut" to doubleArrayOf(0.0, 0.3780571222305298, 0.68359375, 0.9059224277734756, 1.0),
        "easeInOut" to doubleArrayOf(0.0, 0.12868531048297882, 0.5, 0.8713146895170212, 1.0),
        "decelerate" to doubleArrayOf(0.0, 0.4375, 0.75, 0.9375, 1.0),
        "bounceIn" to doubleArrayOf(0.0, 0.02734375, 0.234375, 0.52734375, 1.0),
        "bounceOut" to doubleArrayOf(0.0, 0.47265625, 0.765625, 0.97265625, 1.0),
        "bounceInOut" to doubleArrayOf(0.0, 0.1171875, 0.5, 0.8828125, 1.0),
        "elasticIn" to doubleArrayOf(0.0, 0.0039062499999999952, 1.1481063742006436e-17, -0.12500000000000003, 1.0),
        "elasticOut" to doubleArrayOf(0.0, 1.125, 1.0, 0.99609375, 1.0),
        "elasticInOut" to doubleArrayOf(0.0, 5.740531871003218e-18, 0.5, 1.0, 1.0),
        "fastOutSlowIn" to doubleArrayOf(0.0, 0.23698604106903076, 0.7755804806947708, 0.9595602750778198, 1.0),
        "ease" to doubleArrayOf(0.0, 0.4094947278499603, 0.8019922554492951, 0.9605494872666895, 1.0),
        "easeInSine" to doubleArrayOf(0.0, 0.07055574744939805, 0.29112104445695874, 0.641778564453125, 1.0),
        "easeOutSine" to doubleArrayOf(0.0, 0.38462089877575634, 0.7361679568886756, 0.9438758566975594, 1.0),
        "easeInOutSine" to doubleArrayOf(0.0, 0.13703918457031247, 0.502783190459013, 0.8669293820858001, 1.0),
        "easeInQuad" to doubleArrayOf(0.0, 0.0740315055847168, 0.2556095013022423, 0.5967816352844239, 1.0),
        "easeOutQuad" to doubleArrayOf(0.0, 0.45368375778198244, 0.7711302757263183, 0.9363017678260803, 1.0),
        "easeInOutQuad" to doubleArrayOf(0.0, 0.12958908081054688, 0.5141134391352534, 0.8785284233093262, 1.0),
        "easeInCubic" to doubleArrayOf(0.0, 0.0384702491760254, 0.14525883290916683, 0.4469313845038414, 1.0),
        "easeOutCubic" to doubleArrayOf(0.0, 0.5991595584154129, 0.8751163475867361, 0.9760727959871291, 1.0),
        "easeInOutCubic" to doubleArrayOf(0.0, 0.0873946738243103, 0.516875, 0.931120035648346, 1.0),
        "easeInQuart" to doubleArrayOf(0.0, 0.015537386899814008, 0.062475943565368654, 0.2749938040971756, 1.0),
        "easeOutQuart" to doubleArrayOf(0.0, 0.6995202612876892, 0.9149362006783486, 0.9851705887913704, 1.0),
        "easeInOutQuart" to doubleArrayOf(0.0, 0.052356377243995667, 0.59326171875, 0.9563882369548082, 1.0),
        "easeInQuint" to doubleArrayOf(0.0, 0.01844727270305157, 0.05488859303295613, 0.18798087537288666, 1.0),
        "easeOutQuint" to doubleArrayOf(0.0, 0.7758848145604134, 0.9659188389778137, 0.9973333552479744, 1.0),
        "easeInOutQuint" to doubleArrayOf(0.0, 0.04233002848923206, 0.6725625991821289, 0.9661552030593157, 1.0),
        "easeInExpo" to doubleArrayOf(0.0, 0.013900599689222873, 0.037226962172426284, 0.12758299738168716, 1.0),
        "easeOutExpo" to doubleArrayOf(0.0, 0.8433547019958496, 0.977752685546875, 0.998266932554543, 1.0),
        "easeInOutExpo" to doubleArrayOf(0.0, 0.029928013682365417, 0.5, 0.9700719863176346, 1.0),
        "easeInCirc" to doubleArrayOf(0.0, 0.03435471374541521, 0.11819791048765184, 0.29891128923743965, 1.0),
        "easeOutCirc" to doubleArrayOf(0.0, 0.8417613618075848, 0.9583633197844028, 0.992806018460542, 1.0),
        "easeInOutCirc" to doubleArrayOf(0.0, 0.08545319288969042, 0.603654799759388, 0.9247162434039637, 1.0),
        "easeInBack" to doubleArrayOf(0.0, -0.0868431091308594, -0.06346484366804361, 0.24055313784629107, 1.0),
        "easeOutBack" to doubleArrayOf(0.0, 0.8481117981672287, 1.0674425686150788, 1.0759368389844894, 1.0),
        "easeInOutBack" to doubleArrayOf(0.0, -0.08304632082581521, 0.6084384918212892, 1.0890036918222905, 1.0),
        "fastLinearToSlowEaseIn" to doubleArrayOf(0.0, 0.9139966368675232, 0.988370418548584, 0.999082577531226, 1.0),
        "slowMiddle" to doubleArrayOf(0.0, 0.42831611633300776, 0.5, 0.5716838836669922, 1.0),
        "fastEaseInToSlowEaseOut" to doubleArrayOf(0.0, 0.6668229198455811, 0.9423460066318512, 0.9915634170807899, 1.0),
        "linearToEaseOut" to doubleArrayOf(0.0, 0.62372185587883, 0.9198041975498199, 0.982636445760727, 1.0),
        "easeInToLinear" to doubleArrayOf(0.0, 0.01736355423927307, 0.08019580245018006, 0.37627814412117006, 1.0),
    )

    private val points = doubleArrayOf(0.0, 0.25, 0.5, 0.75, 1.0)

    private fun assertNear(expected: Double, actual: Double, what: String = "", tolerance: Double = 1e-9) {
        assertTrue(abs(expected - actual) <= tolerance, "$what: expected $expected, got $actual")
    }

    @Test
    fun curveTableHasExactlyFluttersNames() {
        // The SDK's `_parseCurve` and the engine's `Curves` enum both hold 42 names.
        assertEquals(42, Curves.names.size)
        assertEquals(flutter.map { it.first }, Curves.names)
        assertEquals(Curves.names.size, Curves.names.toSet().size)
    }

    @Test
    fun everyCurveMatchesFlutterAtTheFivePoints() {
        for ((name, expected) in flutter) {
            for (i in points.indices) {
                assertNear(expected[i], Curves.apply(name, points[i]), "$name(${points[i]})", 1e-12)
            }
        }
    }

    @Test
    fun aMissingOrUnknownCurveIsEaseInOut() {
        for (t in doubleArrayOf(0.1, 0.25, 0.5, 0.9)) {
            assertEquals(Curves.apply("easeInOut", t), Curves.apply(null, t))
            assertEquals(Curves.apply("easeInOut", t), Curves.apply("wobble", t))
            assertEquals(Curves.apply("easeInOut", t), Curves.apply("", t))
        }
        assertNear(0.12868531048297882, Curves.apply(null, 0.25))
    }

    @Test
    fun curveTimeIsClampedButElasticAndBackOvershootInValue() {
        for (name in Curves.names) {
            assertEquals(0.0, Curves.apply(name, -0.5), name)
            assertEquals(1.0, Curves.apply(name, 1.5), name)
            assertEquals(0.0, Curves.apply(name, Double.NaN), name)
        }
        assertTrue(Curves.apply("elasticOut", 0.25) > 1.0)
        assertTrue(Curves.apply("easeInBack", 0.25) < 0.0)
        assertTrue(Curves.apply("easeOutBack", 0.75) > 1.0)
    }

    @Test
    fun durationIsANumberOfMillisecondsDefault300AndNeverNegative() {
        assertEquals(300.0, AnimationDuration.milliseconds(null))
        assertEquals(300.0, AnimationDuration.milliseconds(JsonValue.Null))
        assertEquals(300.0, AnimationDuration.milliseconds(JsonValue.String("500")))
        assertEquals(500.0, AnimationDuration.milliseconds(JsonValue.Int(500)))
        // Dart reads the prop as an int: a fraction is cut off.
        assertEquals(120.0, AnimationDuration.milliseconds(JsonValue.Double(120.5)))
        assertEquals(0.0, AnimationDuration.milliseconds(JsonValue.Int(0)))
        assertEquals(0.0, AnimationDuration.milliseconds(JsonValue.Int(-40)))
        assertEquals(300.0, AnimationDuration.milliseconds(JsonValue.Double(Double.NaN)))
        assertEquals(200.0, AnimationDuration.milliseconds(null, 200.0))
    }

    @Test
    fun durationIsReadAsDartsInt() {
        assertEquals(300.0, AnimationDuration.milliseconds(JsonValue.Double(300.5)))
        assertEquals(0.0, AnimationDuration.milliseconds(JsonValue.Double(0.5)))
        assertEquals(0.0, AnimationDuration.milliseconds(JsonValue.Double(-0.5)))
        assertEquals(0.0, AnimationDuration.milliseconds(JsonValue.Double(-40.9)))
        assertEquals(250.0, AnimationDuration.milliseconds(JsonValue.Double(250.0)))
        assertEquals(200.0, AnimationDuration.milliseconds(JsonValue.Double(Double.POSITIVE_INFINITY), 200.0))
        assertEquals(200.0, AnimationDuration.milliseconds(JsonValue.Bool(true), 200.0))
    }

    // MARK: Controller (B12.1, core half)

    private fun controller(
        durationMs: Double = 300.0,
        curve: String? = "linear",
        repeats: Boolean = false,
        reverses: Boolean = false,
        reduceMotion: Boolean = false,
    ) = AnimationController(durationMs, curve, repeats, reverses, reduceMotion)

    @Test
    fun b12_1_aNewControllerRestsAtZero() {
        val c = controller()
        assertEquals(0.0, c.value(0.0))
        assertEquals(0.0, c.progress(1000.0))
        assertEquals(AnimationStatus.Dismissed, c.status(0.0))
        assertFalse(c.isRunning(0.0))
        assertFalse(c.takeCompletion(1000.0))
    }

    @Test
    fun b12_1_forwardReachesTheMidpointAt150Of300AndCompletesOnceAtOne() {
        val c = controller()
        c.forward(1000.0)
        assertEquals(0.0, c.value(1000.0))
        assertEquals(0.5, c.value(1150.0))
        assertEquals(AnimationStatus.Forward, c.status(1150.0))
        assertTrue(c.isRunning(1150.0))
        assertFalse(c.takeCompletion(1150.0))
        assertEquals(1.0, c.value(1300.0))
        assertEquals(AnimationStatus.Completed, c.status(1300.0))
        assertFalse(c.isRunning(1300.0))
        assertTrue(c.takeCompletion(1300.0))
        assertFalse(c.takeCompletion(1300.0))
        assertFalse(c.takeCompletion(9000.0))
        assertEquals(1.0, c.value(9000.0))
    }

    @Test
    fun b12_1_progressIsTheValueAfterTheCurve() {
        val eased = controller(curve = "easeIn")
        eased.forward(0.0)
        assertEquals(0.5, eased.value(150.0))
        assertNear(0.31640625, eased.progress(150.0))
        val default = controller(curve = null)
        default.forward(0.0)
        assertNear(0.12868531048297882, default.progress(75.0))
    }

    @Test
    fun b12_1_forwardRestartsFromZero() {
        val c = controller()
        c.forward(0.0)
        c.forward(200.0)
        assertEquals(0.0, c.value(200.0))
        assertEquals(0.5, c.value(350.0))
        assertFalse(c.takeCompletion(300.0))
        assertTrue(c.takeCompletion(500.0))
        // Again from the end: back to 0, one more completion.
        c.forward(600.0)
        assertEquals(0.5, c.value(750.0))
        assertTrue(c.takeCompletion(900.0))
        assertFalse(c.takeCompletion(900.0))
    }

    @Test
    fun b12_1_reverseFromTheMiddleTakesValueTimesDurationAndCompletesAtZero() {
        val c = controller()
        c.forward(0.0)
        c.reverse(150.0)
        assertEquals(0.5, c.value(150.0))
        assertEquals(AnimationStatus.Reverse, c.status(151.0))
        assertTrue(c.isRunning(151.0))
        assertEquals(0.25, c.value(225.0))
        assertFalse(c.takeCompletion(225.0))
        assertEquals(0.0, c.value(300.0))
        assertEquals(AnimationStatus.Dismissed, c.status(300.0))
        assertFalse(c.isRunning(300.0))
        assertTrue(c.takeCompletion(300.0))
        assertFalse(c.takeCompletion(300.0))
    }

    @Test
    fun b12_1_reverseFromTheEndTakesTheWholeDuration() {
        val c = controller()
        c.forward(0.0)
        assertTrue(c.takeCompletion(300.0))
        c.reverse(1000.0)
        assertEquals(0.5, c.value(1150.0))
        assertEquals(0.0, c.value(1300.0))
        assertTrue(c.takeCompletion(1300.0))
    }

    @Test
    fun b12_1_reverseAtZeroDoesNothing() {
        val c = controller()
        c.reverse(100.0)
        assertFalse(c.isRunning(100.0))
        assertEquals(AnimationStatus.Dismissed, c.status(100.0))
        assertEquals(0.0, c.value(200.0))
        assertFalse(c.takeCompletion(500.0))
    }

    @Test
    fun b12_1_startPlaysOnceWithoutRepeat() {
        val c = controller()
        c.start(0.0)
        assertEquals(0.5, c.value(150.0))
        assertTrue(c.takeCompletion(300.0))
    }

    @Test
    fun b12_1_aRepeatNeverCompletes() {
        val c = controller(repeats = true)
        c.start(0.0)
        assertEquals(0.5, c.value(150.0))
        assertEquals(0.5, c.value(450.0))
        assertEquals(0.25, c.value(3075.0))
        assertTrue(c.isRunning(1_000_000.0))
        assertEquals(AnimationStatus.Forward, c.status(450.0))
        for (now in listOf(300.0, 600.0, 601.0, 1_000_000.0)) assertFalse(c.takeCompletion(now))
    }

    @Test
    fun b12_1_aRepeatThatReversesGoesBackAndForth() {
        val c = controller(repeats = true, reverses = true)
        c.start(0.0)
        assertEquals(0.5, c.value(150.0))
        assertEquals(AnimationStatus.Forward, c.status(150.0))
        assertEquals(0.75, c.value(375.0))
        assertEquals(AnimationStatus.Reverse, c.status(375.0))
        assertEquals(0.25, c.value(675.0))
        assertFalse(c.takeCompletion(1200.0))
    }

    @Test
    fun b12_1_forwardOnARepeatingBuilderPlaysOnce() {
        val c = controller(repeats = true, reverses = true)
        c.start(0.0)
        c.forward(1000.0)
        assertEquals(0.0, c.value(1000.0))
        assertEquals(0.5, c.value(1150.0))
        assertEquals(1.0, c.value(1300.0))
        assertEquals(1.0, c.value(5000.0))
        assertFalse(c.isRunning(5000.0))
        assertEquals(AnimationStatus.Completed, c.status(5000.0))
        assertTrue(c.takeCompletion(5000.0))
        assertFalse(c.takeCompletion(6000.0))
    }

    @Test
    fun b12_1_reverseOnARepeatRunsFromTheCurrentValueToZero() {
        val c = controller(repeats = true)
        c.start(0.0)
        c.reverse(450.0)
        assertEquals(0.5, c.value(450.0))
        assertEquals(0.0, c.value(600.0))
        assertEquals(0.0, c.value(5000.0))
        assertTrue(c.takeCompletion(600.0))
    }

    @Test
    fun b12_1_aDurationOfZeroJumps() {
        val c = controller(durationMs = 0.0)
        c.forward(10.0)
        assertEquals(1.0, c.value(10.0))
        assertFalse(c.isRunning(10.0))
        assertTrue(c.takeCompletion(10.0))
        assertFalse(c.takeCompletion(10.0))
    }

    @Test
    fun b12_1_aJumpingRunHasEndedAlsoWhenReadBeforeItsStartTime() {
        for (c in listOf(controller(durationMs = 0.0), controller(durationMs = -5.0), controller(reduceMotion = true))) {
            c.forward(100.0)
            assertEquals(1.0, c.value(50.0))
            assertEquals(1.0, c.progress(50.0))
            assertEquals(AnimationStatus.Completed, c.status(50.0))
            assertFalse(c.isRunning(50.0))
            assertTrue(c.takeCompletion(50.0))
            assertFalse(c.takeCompletion(50.0))

            c.reverse(200.0)
            assertEquals(0.0, c.value(150.0))
            assertEquals(AnimationStatus.Dismissed, c.status(150.0))
            assertTrue(c.takeCompletion(150.0))
            assertFalse(c.takeCompletion(150.0))
        }
    }

    // MARK: Reduced motion (B12.7-K)

    @Test
    fun b12_7_K_reduceMotionEndsAControllerRunAtOnceAndCompletesOnce() {
        val c = controller(reduceMotion = true)
        c.start(0.0)
        assertEquals(1.0, c.value(0.0))
        assertEquals(1.0, c.progress(0.0))
        assertEquals(AnimationStatus.Completed, c.status(0.0))
        assertFalse(c.isRunning(0.0))
        assertTrue(c.takeCompletion(0.0))
        assertFalse(c.takeCompletion(16.0))

        c.reverse(100.0)
        assertEquals(0.0, c.value(100.0))
        assertEquals(AnimationStatus.Dismissed, c.status(100.0))
        assertTrue(c.takeCompletion(100.0))
        assertFalse(c.takeCompletion(100.0))

        c.forward(200.0)
        assertEquals(1.0, c.value(200.0))
        assertTrue(c.takeCompletion(200.0))
    }

    @Test
    fun b12_7_K_reduceMotionKeepsBothCompletionsOfAForwardAndAReverseInOneFrame() {
        val c = controller(reduceMotion = true)
        c.forward(0.0)
        c.reverse(0.0)
        assertEquals(0.0, c.value(0.0))
        assertTrue(c.takeCompletion(0.0))
        assertTrue(c.takeCompletion(0.0))
        assertFalse(c.takeCompletion(0.0))
    }

    @Test
    fun b12_7_K_reduceMotionRestsARepeatingBuilderAtOne() {
        val c = controller(repeats = true, reverses = true, reduceMotion = true)
        c.start(0.0)
        for (now in listOf(0.0, 150.0, 375.0, 10_000.0)) {
            assertEquals(1.0, c.value(now))
            assertFalse(c.isRunning(now))
        }
        assertEquals(AnimationStatus.Completed, c.status(150.0))
        // A repeat never completes, at rest or not.
        assertFalse(c.takeCompletion(10_000.0))
    }

    // MARK: Registry (B12.1, design D4)

    @Test
    fun b12_1_registryDrivesTheControllerOfAnId() {
        val registry = AnimationRegistry()
        val owner = Any()
        val c = controller(curve = "easeIn")
        registry.register("spin", owner, c)
        assertSame(c, registry.controller("spin"))
        assertTrue(registry.owns("spin", owner))
        assertTrue(registry.forward("spin", 0.0))
        assertEquals(0.5, c.value(150.0))
        assertNear(0.31640625, registry.progress("spin", 150.0))
        assertTrue(registry.reverse("spin", 150.0))
        assertEquals(0.25, c.value(225.0))
    }

    @Test
    fun b12_1_registryIgnoresAnUnknownId() {
        val registry = AnimationRegistry()
        assertFalse(registry.forward("nobody", 0.0))
        assertFalse(registry.reverse("nobody", 0.0))
        assertEquals(0.0, registry.progress("nobody", 100.0))
        assertNull(registry.controller("nobody"))
        assertFalse(registry.owns("nobody", Any()))
        registry.unregister("nobody", Any())
    }

    @Test
    fun b12_1_theLastBuilderToRegisterAnIdOwnsItAndALeavingOneRemovesOnlyItsOwn() {
        val registry = AnimationRegistry()
        val first = Any()
        val second = Any()
        val a = controller()
        val b = controller()
        registry.register("spin", first, a)
        registry.register("spin", second, b)
        assertSame(b, registry.controller("spin"))
        assertFalse(registry.owns("spin", first))
        assertTrue(registry.owns("spin", second))

        // The older builder leaves: the newer entry stays (Flutter would delete it).
        registry.unregister("spin", first)
        assertSame(b, registry.controller("spin"))
        assertTrue(registry.forward("spin", 0.0))
        assertEquals(0.5, b.value(150.0))
        assertEquals(0.0, a.value(150.0))

        registry.unregister("spin", second)
        assertNull(registry.controller("spin"))
        assertFalse(registry.forward("spin", 0.0))
    }

    // MARK: Implicit animation (B12.2, B12.3 core halves)

    private fun props(vararg members: Pair<String, JsonValue>): Map<String, JsonValue> = mapOf(*members)

    private fun n(value: Double): JsonValue = JsonValue.Double(value)

    private fun s(value: String): JsonValue = JsonValue.String(value)

    private fun o(vararg members: Pair<String, JsonValue>): JsonValue = JsonValue.Object(mapOf(*members))

    private fun implicit(curve: String? = "linear", durationMs: Double = 300.0, reduceMotion: Boolean = false) =
        ImplicitAnimation(durationMs, curve, reduceMotion, AnimationMix::props)

    private fun number(value: JsonValue?): Double = requireNotNull(value?.doubleValue) { "not a number: $value" }

    @Test
    fun b12_2_theFirstTargetIsShownWithNoAnimation() {
        val a = implicit()
        assertNull(a.value(0.0))
        assertFalse(a.isRunning(0.0))
        val first = props("width" to n(100.0), "color" to s("#000000"))
        a.retarget(first, 0.0)
        assertFalse(a.isRunning(0.0))
        assertEquals(first, a.value(0.0))
        assertEquals(first, a.value(150.0))
    }

    @Test
    fun b12_2_widthAndColourAreHalfWayAt150Of300Linear() {
        val a = implicit()
        a.retarget(props("width" to n(100.0), "height" to n(40.0), "color" to s("#000000")), 0.0)
        val target = props("width" to n(200.0), "height" to n(80.0), "color" to s("#FFFFFF"))
        a.retarget(target, 1000.0)
        assertTrue(a.isRunning(1000.0))
        assertEquals(100.0, number(a.value(1000.0)!!["width"]))
        val mid = a.value(1150.0)!!
        assertEquals(150.0, number(mid["width"]))
        assertEquals(60.0, number(mid["height"]))
        // 127.5 per channel rounds away from zero; widget colours are #RRGGBBAA.
        assertEquals(s("#808080FF"), mid["color"])
        assertTrue(a.isRunning(1299.0))
        assertFalse(a.isRunning(1300.0))
        assertEquals(target, a.value(1300.0))
        assertEquals(target, a.value(9000.0))
    }

    @Test
    fun b12_2_widthAndColourFollowEaseInOut() {
        val a = implicit(curve = "easeInOut")
        a.retarget(props("width" to n(100.0), "color" to s("#000000FF")), 0.0)
        a.retarget(props("width" to n(200.0), "color" to s("#FF000080")), 0.0)
        // easeInOut(0.5) = 0.5 and easeInOut(0.25) = 0.12868531048297882 (Flutter).
        assertNear(150.0, number(a.value(150.0)!!["width"]))
        assertEquals(s("#800000C0"), a.value(150.0)!!["color"])
        assertNear(112.868531048297882, number(a.value(75.0)!!["width"]))
        // 255 * 0.1287 = 32.8 -> 0x21; alpha 255 - 127 * 0.1287 = 238.7 -> 0xEF.
        assertEquals(s("#210000EF"), a.value(75.0)!!["color"])
    }

    @Test
    fun b12_2_aMissingCurveIsEaseInOut() {
        val a = implicit(curve = null)
        a.retarget(props("width" to n(0.0)), 0.0)
        a.retarget(props("width" to n(1.0)), 0.0)
        assertNear(0.12868531048297882, number(a.value(75.0)!!["width"]))
    }

    @Test
    fun b12_3_opacityAndAlignmentAreHalfWayAt150Of300() {
        val a = implicit()
        a.retarget(props("opacity" to n(0.0), "alignment" to s("topLeft")), 0.0)
        a.retarget(props("opacity" to n(1.0), "alignment" to s("bottomRight")), 0.0)
        val mid = a.value(150.0)!!
        assertEquals(0.5, number(mid["opacity"]))
        assertEquals(AlignmentBias(0.0, 0.0), AlignmentBias.of(mid["alignment"]))
        val quarter = a.value(75.0)!!
        assertEquals(AlignmentBias(-0.5, -0.5), AlignmentBias.of(quarter["alignment"]))
        assertEquals(s("bottomRight"), a.value(300.0)!!["alignment"])
    }

    @Test
    fun b12_3_opacityAndAlignmentFollowEaseInOut() {
        val a = implicit(curve = "easeInOut")
        a.retarget(props("opacity" to n(1.0), "alignment" to s("centerLeft"), "widthFactor" to n(1.0)), 0.0)
        a.retarget(props("opacity" to n(0.0), "alignment" to s("topRight"), "widthFactor" to n(2.0)), 0.0)
        val mid = a.value(150.0)!!
        assertNear(0.5, number(mid["opacity"]))
        assertNear(1.5, number(mid["widthFactor"]))
        val bias = AlignmentBias.of(mid["alignment"])
        assertNear(0.0, bias.x)
        assertNear(-0.5, bias.y)
        assertNear(1 - 0.12868531048297882, number(a.value(75.0)!!["opacity"]))
    }

    @Test
    fun b12_3_anAlignmentOnlyOneSideHasSnaps() {
        // Design D7: a null side snaps. Nothing to topLeft: topLeft at once.
        val appears = AnimationMix.props(props(), props("alignment" to s("topLeft")), 0.5)
        assertEquals(props("alignment" to s("topLeft")), appears)
        // topLeft to nothing: no key at all.
        val leaves = AnimationMix.props(props("alignment" to s("topLeft")), props(), 0.5)
        assertEquals(props(), leaves)
        assertEquals(s("topRight"), AnimationMix.props(props("alignment" to JsonValue.Null), props("alignment" to s("topRight")), 0.5)["alignment"])
        assertEquals(JsonValue.Null, AnimationMix.props(props("alignment" to s("topRight")), props("alignment" to JsonValue.Null), 0.5)["alignment"])

        val a = implicit()
        a.retarget(props("opacity" to n(1.0)), 0.0)
        a.retarget(props("opacity" to n(1.0), "alignment" to s("topRight")), 0.0)
        assertEquals(s("topRight"), a.value(150.0)!!["alignment"])
    }

    @Test
    fun b12_3_anAlignmentThatIsNotANameOrACompletePointSnaps() {
        val half = o("x" to n(1.0))
        assertEquals(half, AnimationMix.props(props("alignment" to s("topLeft")), props("alignment" to half), 0.5)["alignment"])
        assertEquals(s("topLeft"), AnimationMix.props(props("alignment" to half), props("alignment" to s("topLeft")), 0.5)["alignment"])
        val text = o("x" to s("1"), "y" to n(1.0))
        assertEquals(s("topLeft"), AnimationMix.props(props("alignment" to text), props("alignment" to s("topLeft")), 0.5)["alignment"])
        assertEquals(s("topLeft"), AnimationMix.props(props("alignment" to n(1.0)), props("alignment" to s("topLeft")), 0.5)["alignment"])
        // A complete point and a name mix; a name outside the nine is the centre.
        val point = o("x" to n(1.0), "y" to n(1.0))
        assertEquals(AlignmentBias(0.0, 0.0).json, AnimationMix.props(props("alignment" to point), props("alignment" to s("topLeft")), 0.5)["alignment"])
        assertEquals(AlignmentBias(-0.5, -0.5).json, AnimationMix.props(props("alignment" to s("topLeft")), props("alignment" to s("sideways")), 0.5)["alignment"])
        // The same value on both sides stays as it was handed in.
        assertEquals(s("topLeft"), AnimationMix.props(props("alignment" to s("topLeft")), props("alignment" to s("topLeft")), 0.5)["alignment"])
    }

    @Test
    fun b12_2_aLiveRunKeepsTheDurationAndCurveItStartedWith() {
        val a = implicit()
        a.retarget(props("width" to n(100.0)), 0.0)
        a.retarget(props("width" to n(200.0)), 0.0)
        a.durationMs = 600.0
        a.curve = "easeIn"
        assertEquals(150.0, number(a.value(150.0)!!["width"]))
        assertTrue(a.isRunning(299.0))
        assertFalse(a.isRunning(300.0))
        assertEquals(n(200.0), a.value(300.0)!!["width"])
        // The next retarget runs with the new ones: easeIn(0.5) = 0.31640625 over 600 ms.
        a.retarget(props("width" to n(300.0)), 1000.0)
        assertNear(200.0 + 100.0 * 0.31640625, number(a.value(1300.0)!!["width"]))
        assertTrue(a.isRunning(1599.0))
        assertFalse(a.isRunning(1600.0))
        // A duration of 0 set mid-run does not cut the run short either.
        a.retarget(props("width" to n(400.0)), 2000.0)
        a.durationMs = 0.0
        assertTrue(a.isRunning(2300.0))
        a.retarget(props("width" to n(500.0)), 2300.0)
        assertFalse(a.isRunning(2300.0))
        assertEquals(n(500.0), a.value(2300.0)!!["width"])
    }

    @Test
    fun b12_2_aNewTargetMidRunStartsAgainFromTheValueOnScreen() {
        val a = implicit()
        a.retarget(props("width" to n(100.0), "alignment" to s("topLeft")), 0.0)
        a.retarget(props("width" to n(200.0), "alignment" to s("topRight")), 0.0)
        // At 150 the screen shows 150 and (0, -1); the new run takes the full 300 ms from there.
        a.retarget(props("width" to n(50.0), "alignment" to s("bottomRight")), 150.0)
        assertEquals(150.0, number(a.value(150.0)!!["width"]))
        assertEquals(AlignmentBias(0.0, -1.0), AlignmentBias.of(a.value(150.0)!!["alignment"]))
        assertEquals(100.0, number(a.value(300.0)!!["width"]))
        assertEquals(AlignmentBias(0.5, 0.0), AlignmentBias.of(a.value(300.0)!!["alignment"]))
        assertTrue(a.isRunning(449.0))
        assertFalse(a.isRunning(450.0))
        assertEquals(50.0, number(a.value(450.0)!!["width"]))
    }

    @Test
    fun b12_2_theSameTargetAgainDoesNotRestart() {
        val a = implicit()
        a.retarget(props("width" to n(100.0)), 0.0)
        a.retarget(props("width" to n(200.0)), 0.0)
        a.retarget(props("width" to n(200.0)), 150.0)
        assertEquals(175.0, number(a.value(225.0)!!["width"]))
        assertFalse(a.isRunning(300.0))
        a.retarget(props("width" to n(200.0)), 400.0)
        assertFalse(a.isRunning(400.0))
    }

    @Test
    fun b12_2_anythingElseOrANullSideSnapsAtTheStart() {
        val a = implicit()
        a.retarget(props("width" to n(100.0), "child" to s("a"), "duration" to n(300.0), "color" to s("red")), 0.0)
        a.retarget(
            props("height" to n(80.0), "child" to s("b"), "duration" to n(900.0), "color" to s("#FFFFFF")),
            0.0,
        )
        val start = a.value(0.0)!!
        assertEquals(s("b"), start["child"])
        assertEquals(n(900.0), start["duration"])
        assertEquals(n(80.0), start["height"])
        assertEquals(s("#FFFFFF"), start["color"])
        assertNull(start["width"])
        assertTrue(a.isRunning(150.0))
    }

    @Test
    fun b12_2_paddingAndMarginMixSideBySide() {
        val a = implicit()
        val from = o("top" to n(0.0), "right" to n(10.0), "bottom" to n(20.0), "left" to n(30.0))
        val to = o("top" to n(8.0), "right" to n(10.0), "bottom" to n(0.0))
        a.retarget(props("padding" to from, "margin" to from), 0.0)
        a.retarget(props("padding" to to, "margin" to JsonValue.Null), 0.0)
        val mid = a.value(150.0)!!
        assertEquals(o("top" to n(4.0), "right" to n(10.0), "bottom" to n(10.0), "left" to n(15.0)), mid["padding"])
        assertEquals(JsonValue.Null, mid["margin"])
    }

    @Test
    fun b12_2_aDecorationMixesColourRadiusAndBorderAndSnapsTheRest() {
        val from = o(
            "color" to s("#000000"),
            "borderRadius" to n(0.0),
            "border" to o("color" to s("#000000"), "width" to n(1.0)),
            "gradient" to s("old"),
        )
        val to = o(
            "color" to s("#FFFFFF"),
            "borderRadius" to n(16.0),
            "border" to o("color" to s("#FF0000"), "width" to n(3.0), "style" to s("solid")),
            "boxShadow" to s("new"),
        )
        val mid = AnimationMix.decoration(from, to, 0.5)!!
        assertEquals(s("#808080FF"), mid["color"])
        assertEquals(n(8.0), mid["borderRadius"])
        assertEquals(o("color" to s("#800000FF"), "width" to n(2.0), "style" to s("solid")), mid["border"])
        assertEquals(s("new"), mid["boxShadow"])
        assertEquals(JsonValue.Null, mid["gradient"])

        // A number and four corners mix corner by corner; a missing part snaps.
        val corners = o("borderRadius" to o("topLeft" to n(8.0), "bottomRight" to n(4.0)))
        val cornered = AnimationMix.decoration(o("borderRadius" to n(4.0), "color" to s("#000000")), corners, 0.5)!!
        assertEquals(
            o("topLeft" to n(6.0), "topRight" to n(2.0), "bottomLeft" to n(2.0), "bottomRight" to n(4.0)),
            cornered["borderRadius"],
        )
        assertEquals(JsonValue.Null, cornered["color"])
        assertEquals(to, AnimationMix.decoration(null, to, 0.5))
        assertNull(AnimationMix.decoration(from, null, 0.5))

        val a = implicit()
        a.retarget(props("decoration" to from), 0.0)
        a.retarget(props("decoration" to to), 0.0)
        assertEquals(n(8.0), a.value(150.0)!!["decoration"]!!["borderRadius"])
    }

    @Test
    fun theMixesArePureFunctions() {
        assertEquals(15.0, AnimationMix.number(10.0, 20.0, 0.5))
        assertEquals(25.0, AnimationMix.number(10.0, 20.0, 1.5))
        assertEquals("#808080FF", AnimationMix.color("#000000", "#ffffff", 0.5))
        assertEquals("#11223380", AnimationMix.color("#11223300", "#112233FF", 0.5))
        // An overshooting curve stays inside a channel.
        assertEquals("#FFFFFFFF", AnimationMix.color("#000000", "#FFFFFF", 1.4))
        assertEquals("#000000FF", AnimationMix.color("#000000", "#FFFFFF", -0.4))
        assertNull(AnimationMix.color("red", "#FFFFFF", 0.5))
        assertNull(AnimationMix.color("#FFF", "#FFFFFF", 0.5))
        assertEquals(AlignmentBias(0.0, -1.0), AnimationMix.alignment(AlignmentBias(-1.0, -1.0), AlignmentBias(1.0, -1.0), 0.5))
        assertEquals(AlignmentBias(1.0, 1.0), AlignmentBias.named("bottomRight"))
        assertEquals(AlignmentBias(0.0, -1.0), AlignmentBias.named("topCenter"))
        assertEquals(AlignmentBias(0.0, 0.0), AlignmentBias.named("sideways"))
        assertEquals(AlignmentBias(0.0, 0.0), AlignmentBias.named(null))
        assertEquals(AlignmentBias(-1.0, 0.0), AlignmentBias.of(JsonValue.String("centerLeft")))
        assertEquals(AlignmentBias(0.25, -0.5), AlignmentBias.of(AlignmentBias(0.25, -0.5).json))
    }

    // MARK: Reduced motion, implicit (B12.7-K)

    @Test
    fun b12_7_K_reduceMotionShowsANewTargetAtOnce() {
        val a = implicit(reduceMotion = true)
        a.retarget(props("width" to n(100.0), "opacity" to n(0.0)), 0.0)
        val target = props("width" to n(200.0), "opacity" to n(1.0))
        a.retarget(target, 1000.0)
        assertFalse(a.isRunning(1000.0))
        assertEquals(target, a.value(1000.0))
        assertEquals(target, a.value(1150.0))
    }

    @Test
    fun b12_7_K_aDurationOfZeroShowsANewTargetAtOnce() {
        val a = implicit(durationMs = 0.0)
        a.retarget(props("width" to n(100.0)), 0.0)
        a.retarget(props("width" to n(200.0)), 10.0)
        assertFalse(a.isRunning(10.0))
        assertEquals(n(200.0), a.value(10.0)!!["width"])
    }

    @Test
    fun b12_7_K_reduceMotionTurnedOnMidRunEndsTheRun() {
        val a = implicit()
        a.retarget(props("width" to n(100.0)), 0.0)
        a.retarget(props("width" to n(200.0)), 0.0)
        a.reduceMotion = true
        assertFalse(a.isRunning(150.0))
        assertEquals(n(200.0), a.value(150.0)!!["width"])
    }
}
