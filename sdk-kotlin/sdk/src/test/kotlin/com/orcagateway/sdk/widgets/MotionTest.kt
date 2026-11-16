package com.orcagateway.sdk.widgets

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.orcagateway.core.animation.AnimationController
import com.orcagateway.core.animation.Curves
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * AnimatedBuilder: the clock and curves it takes from the core (Flutter
 * `forward` / `repeat(reverse:)`, as Swift's MotionTests), then the builder
 * itself on the test frame clock: `animationId` and the page's registry,
 * `autoStart`, `onComplete`, targeted tweens and reduced motion.
 */
@RunWith(RobolectricTestRunner::class)
class MotionTest {
    @get:Rule
    val compose = createComposeRule()

    // MARK: the clock and the curves (the core's, which the builder now drives)

    @Test
    fun oneShotClampsAtTheEnd() {
        val clock = AnimationController(durationMs = 1000.0, curve = "linear").apply { start(0.0) }
        assertEquals(0.5, clock.value(500.0))
        assertEquals(1.0, clock.value(3000.0))
    }

    @Test
    fun repeatWrapsAndReverseBouncesBack() {
        val wrap = AnimationController(durationMs = 1000.0, repeats = true).apply { start(0.0) }
        val bounce = AnimationController(durationMs = 1000.0, repeats = true, reverses = true).apply { start(0.0) }
        assertEquals(0.25, wrap.value(1250.0), 1e-9)
        assertEquals(0.75, bounce.value(1250.0), 1e-9)
    }

    @Test
    fun noAutoStartHoldsAtZero() {
        // `autoStart: false` never calls start: the controller rests at 0.
        assertEquals(0.0, AnimationController(durationMs = 1000.0, repeats = true).value(5000.0))
    }

    @Test
    fun curvesKeepTheirEndsAndShape() {
        for (name in listOf("linear", "easeIn", "easeOut", "easeInOut", "fastOutSlowIn")) {
            assertEquals(0.0, Curves.apply(name, 0.0))
            assertEquals(1.0, Curves.apply(name, 1.0))
        }
        assertTrue(Curves.apply("easeIn", 0.5) < 0.5)
        assertTrue(Curves.apply("easeOut", 0.5) > 0.5)
        assertEquals(0.5, Curves.apply("easeInOut", 0.5), 1e-3)
    }

    // MARK: the builder

    /** What each probe node (a SizedBox whose `width` is a tween) was last drawn with. */
    private val drawn = HashMap<String, Double?>()

    /** How many times each builder's `onComplete` ran, by the tag of its action. */
    private val completed = HashMap<String, Int>()

    private fun builder(
        id: String,
        child: String,
        animationId: String? = "pulse",
        props: Map<String, JsonValue> = emptyMap(),
    ): ComponentNode = ComponentNode(
        id, "AnimatedBuilder", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi,
        props + listOfNotNull(animationId?.let { "animationId" to JsonValue.String(it) }),
        listOf(child),
        actions = mapOf("onComplete" to Action.DebugLog(tag = id)),
    )

    /** A node whose `width` goes 0.25 to 1 with the animation [animationId] names, or the enclosing one. */
    private fun probe(id: String, animationId: String? = "pulse"): ComponentNode = leaf(
        id, "SizedBox",
        mapOf(
            "width" to JsonValue.Object(
                mapOf(
                    "type" to JsonValue.String("tween"),
                    "begin" to JsonValue.Double(BEGIN),
                    "end" to JsonValue.Double(END),
                ) + listOfNotNull(animationId?.let { "animationId" to JsonValue.String(it) }),
            ),
        ),
    )

    private fun model(vararg nodes: ComponentNode): OrcaPageModel = OrcaPageModel(page(*nodes)).also { model ->
        model.builders = WidgetBuilders.standard().apply {
            register("SizedBox") { node, _, _ -> drawn[node.id] = node["width"]?.doubleValue }
        }
        model.onEffect = { effect ->
            if (effect.type == "debugLog") {
                val tag = effect.payload["tag"]?.stringValue ?: ""
                completed[tag] = (completed[tag] ?: 0) + 1
            }
        }
    }

    private fun controlled(vararg props: Pair<String, JsonValue>): OrcaPageModel = model(
        builder("b", "p", props = mapOf("duration" to JsonValue.Int(400), "autoStart" to JsonValue.Bool(false)) + props),
        probe("p"),
    )

    private fun effect(type: String, id: String) = ActionEffect(type, mapOf("animationId" to JsonValue.String(id)))

    private fun OrcaPageModel.send(type: String, id: String = "pulse") {
        compose.runOnIdle { perform(effect(type, id)) }
    }

    /** The registered controller's linear value at the frame the page last drew. */
    private fun OrcaPageModel.raw(id: String = "pulse"): Double =
        assertNotNull(animations.controller(id)).value(animationFrameMs)

    private fun at(progress: Double): Double = BEGIN + (END - BEGIN) * progress

    private fun show(model: OrcaPageModel, root: String = "b") {
        compose.mainClock.autoAdvance = false
        compose.setContent { NodeView(root, model) }
        compose.mainClock.advanceTimeByFrame()
    }

    @Test
    fun b12_1_k_autoStartFalseRestsAtBeginUntilForwarded() {
        val model = controlled()
        show(model)
        compose.mainClock.advanceTimeBy(1000)

        assertEquals(BEGIN, drawn["p"])
        assertEquals(0.0, model.raw())
        assertNull(completed["b"])
        assertEquals(0.0, model.animationFrameMs, "a builder at rest takes no frames")
    }

    @Test
    fun b12_1_k_aForwardEffectRunsItThroughTheCurveAndCompletesOnce() {
        val model = controlled("curve" to JsonValue.String("easeOut"))
        show(model)

        model.send("animateForward")
        compose.mainClock.advanceTimeBy(200)
        val raw = model.raw()
        assertEquals(0.5, raw, 0.1, "about half way by the test clock")
        assertEquals(at(Curves.apply("easeOut", raw)), assertNotNull(drawn["p"]), 1e-9)
        assertNull(completed["b"], "not complete mid-run")

        compose.mainClock.advanceTimeBy(400)
        assertEquals(END, drawn["p"])
        assertEquals(1, completed["b"])
        val rested = model.animationFrameMs
        compose.mainClock.advanceTimeBy(1000)
        assertEquals(1, completed["b"], "once")
        assertEquals(rested, model.animationFrameMs, "no frames once the run is over")
    }

    @Test
    fun b12_1_k_aReverseEffectReturnsToBeginAndCompletesAgain() {
        val model = controlled()
        show(model)
        model.send("animateForward")
        compose.mainClock.advanceTimeBy(600)
        assertEquals(END, drawn["p"])

        model.send("animateReverse")
        compose.mainClock.advanceTimeBy(200)
        val raw = model.raw()
        assertEquals(0.5, raw, 0.1)
        assertEquals(at(Curves.apply("easeInOut", raw)), assertNotNull(drawn["p"]), 1e-9)
        compose.mainClock.advanceTimeBy(400)
        assertEquals(BEGIN, drawn["p"])
        assertEquals(2, completed["b"])

        // At 0 a reverse has nothing to do, and nothing completes.
        model.send("animateReverse")
        compose.mainClock.advanceTimeBy(600)
        assertEquals(BEGIN, drawn["p"])
        assertEquals(2, completed["b"])
    }

    @Test
    fun b12_1_k_aForwardRestartsFromZeroAlsoMidRun() {
        val model = controlled()
        show(model)
        model.send("animateForward")
        compose.mainClock.advanceTimeBy(300)
        assertTrue(model.raw() > 0.6)

        model.send("animateForward")
        compose.mainClock.advanceTimeBy(100)
        assertEquals(0.25, model.raw(), 0.1)
        compose.mainClock.advanceTimeBy(500)
        assertEquals(1, completed["b"], "the run that was cut short never completed")
    }

    @Test
    fun b12_1_k_anUnknownIdDoesNothing() {
        val model = controlled()
        show(model)

        model.send("animateForward", "ghost")
        model.send("animateReverse", "ghost")
        compose.runOnIdle { model.perform(ActionEffect("animateForward")) }
        compose.mainClock.advanceTimeBy(600)

        assertEquals(BEGIN, drawn["p"])
        assertEquals(0.0, model.raw())
        assertNull(completed["b"])
        assertNull(model.animations.controller("ghost"))
    }

    @Test
    fun b12_1_k_theEffectsAreThePagesOwnAndDoNotReachTheHost() {
        val model = controlled()
        val passedOn = ArrayList<String>()
        model.effectHandler = { passedOn.add(it.type) }
        show(model)

        model.send("animateForward")
        model.send("animateReverse", "ghost")
        compose.mainClock.advanceTimeBy(600)

        assertEquals(END, drawn["p"])
        assertFalse("animateForward" in passedOn || "animateReverse" in passedOn, "$passedOn")
    }

    @Test
    fun b12_1_k_theLastBuilderOwnsASharedIdAndTheFirstLeavingKeepsIt() {
        val model = model(
            column("0", "a", "b"),
            builder("a", "pa", props = mapOf("autoStart" to JsonValue.Bool(false))),
            probe("pa"),
            builder("b", "pb", props = mapOf("autoStart" to JsonValue.Bool(false), "duration" to JsonValue.Int(400))),
            probe("pb"),
        )
        var first by mutableStateOf(true)
        compose.mainClock.autoAdvance = false
        compose.setContent {
            if (first) NodeView("a", model)
            NodeView("b", model)
        }
        compose.mainClock.advanceTimeByFrame()
        // The entry is the second builder's: its duration, 400 and not 300.
        assertEquals(400.0, assertNotNull(model.animations.controller("pulse")).durationMs)

        compose.mainClock.autoAdvance = true
        compose.runOnIdle { first = false }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        assertEquals(400.0, assertNotNull(model.animations.controller("pulse")).durationMs, "still registered")

        model.send("animateForward")
        compose.mainClock.advanceTimeBy(600)
        assertEquals(END, drawn["pb"])
        assertEquals(1, completed["b"])
        assertNull(completed["a"])
    }

    @Test
    fun b12_1_k_aBuilderLeavingRemovesItsOwnId() {
        val model = controlled()
        var shown by mutableStateOf(true)
        compose.mainClock.autoAdvance = false
        compose.setContent { if (shown) NodeView("b", model) }
        compose.mainClock.advanceTimeByFrame()
        assertNotNull(model.animations.controller("pulse"))

        compose.mainClock.autoAdvance = true
        compose.runOnIdle { shown = false }
        compose.waitForIdle()
        assertNull(model.animations.controller("pulse"))
    }

    /** D6: a tween naming an id reads that controller, not the builder it sits under; an unknown id is 0. */
    @Test
    fun b12_1_k_aTargetedTweenReadsTheRegistryAndAnUnknownIdReadsZero() {
        val model = model(
            column("0", "run", "b", "out"),
            // A running builder with no id: its unnamed tween moves, the ones naming an id do not follow it.
            builder("run", "col", animationId = null, props = mapOf("duration" to JsonValue.Int(400), "curve" to JsonValue.String("linear"))),
            column("col", "plain", "ghost", "named"),
            probe("plain", animationId = null),
            probe("ghost", animationId = "ghost"),
            probe("named", animationId = "pulse"),
            builder("b", "p", props = mapOf("autoStart" to JsonValue.Bool(false))),
            probe("p"),
            // Outside every builder: the registry's value when it is drawn (at rest, begin).
            probe("out"),
        )
        show(model, root = "0")
        compose.mainClock.advanceTimeBy(200)

        val plain = assertNotNull(drawn["plain"])
        assertTrue(plain > at(0.3) && plain < at(0.7), "the enclosing builder's progress: $plain")
        assertEquals(BEGIN, drawn["ghost"])
        assertEquals(BEGIN, drawn["named"], "the named controller rests at 0")
        assertEquals(BEGIN, drawn["p"])
        assertEquals(BEGIN, drawn["out"])
    }

    /** Props an update sends to a builder that already has its controller: all four it was built with. */
    private val newTiming = mapOf(
        "duration" to JsonValue.Int(900),
        "curve" to JsonValue.String("linear"),
        "repeat" to JsonValue.Bool(true),
        "reverse" to JsonValue.Bool(true),
    )

    /** Runs [change] and has the composition see it at the next frame, the clock staying manual. */
    private fun redraw(change: () -> Unit) {
        compose.runOnIdle {
            change()
            Snapshot.sendApplyNotifications()
        }
    }

    /** The controller is built once, as Flutter's in `initState`: an update keeps the value and the old props. */
    @Test
    fun b12_1_k_anUpdateOfItsPropsKeepsTheControllerAndItsValue() {
        val model = controlled()
        show(model)
        model.send("animateForward")
        compose.mainClock.advanceTimeBy(600)
        assertEquals(END, drawn["p"])
        assertEquals(1, completed["b"])
        val before = assertNotNull(model.animations.controller("pulse"))

        redraw { model.apply(ComponentMutation.Update("b", newTiming)) }
        compose.mainClock.advanceTimeBy(1200)

        assertTrue(before === model.animations.controller("pulse"), "the same controller stays registered")
        assertEquals(400.0, before.durationMs, "built once, with the props it appeared with")
        assertEquals(1.0, model.raw())
        assertEquals(END, drawn["p"])
        assertEquals(1, completed["b"], "no new onComplete")
    }

    @Test
    fun b12_1_k_anUpdateOfItsPropsDoesNotReplayAnAutoStartBuilder() {
        val model = model(builder("b", "p", props = mapOf("duration" to JsonValue.Int(400))), probe("p"))
        show(model)
        compose.mainClock.advanceTimeBy(600)
        assertEquals(END, drawn["p"])
        assertEquals(1, completed["b"])

        redraw { model.apply(ComponentMutation.Update("b", newTiming)) }
        compose.mainClock.advanceTimeBy(100)
        assertEquals(END, drawn["p"], "no replay from 0")
        assertEquals(1.0, model.raw())
        compose.mainClock.advanceTimeBy(1100)

        assertEquals(END, drawn["p"])
        assertEquals(1, completed["b"], "no new onComplete")
    }

    /** `autoStart` is read when the builder appears (Flutter `initState`): turned on later it starts nothing. */
    @Test
    fun b12_1_k_autoStartTurnedOnByAnUpdateStartsNothing() {
        val model = controlled()
        show(model)

        redraw { model.apply(ComponentMutation.Update("b", mapOf("autoStart" to JsonValue.Bool(true)))) }
        compose.mainClock.advanceTimeBy(600)

        assertEquals(BEGIN, drawn["p"])
        assertEquals(0.0, model.raw())
        assertNull(completed["b"])
    }

    @Test
    fun b12_7_k_reducedMotionTogglingKeepsTheControllerAndItsValue() {
        val model = model(builder("b", "p", props = mapOf("duration" to JsonValue.Int(400))), probe("p"))
        var reduce by mutableStateOf(false)
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalOrcaReduceMotion provides reduce) { NodeView("b", model) }
        }
        compose.mainClock.advanceTimeBy(600)
        assertEquals(END, drawn["p"])
        assertEquals(1, completed["b"])
        val before = assertNotNull(model.animations.controller("pulse"))

        redraw { reduce = true }
        compose.mainClock.advanceTimeBy(600)

        assertTrue(before === model.animations.controller("pulse"), "the same controller stays registered")
        assertEquals(END, drawn["p"])
        assertEquals(1, completed["b"], "no replay, no new onComplete")
    }

    @Test
    fun b12_7_k_reducedMotionJumpsToTheEndAndCompletesOnce() {
        val model = model(builder("b", "p", props = mapOf("duration" to JsonValue.Int(400))), probe("p"))
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalOrcaReduceMotion provides true) { NodeView("b", model) }
        }
        compose.mainClock.advanceTimeBy(48)

        assertEquals(END, drawn["p"])
        assertEquals(1, completed["b"])

        // Driven by actions it still jumps: back to begin at once, one more completion.
        model.send("animateReverse")
        compose.mainClock.advanceTimeBy(48)
        assertEquals(BEGIN, drawn["p"])
        assertEquals(2, completed["b"])
        compose.mainClock.advanceTimeBy(1000)
        assertEquals(2, completed["b"])
    }

    @Test
    fun b12_7_k_reducedMotionRestsARepeatingBuilderAtTheEndWithNoCompletion() {
        val model = model(
            builder("b", "p", props = mapOf("duration" to JsonValue.Int(400), "repeat" to JsonValue.Bool(true), "reverse" to JsonValue.Bool(true))),
            probe("p"),
        )
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalOrcaReduceMotion provides true) { NodeView("b", model) }
        }
        compose.mainClock.advanceTimeBy(1000)

        assertEquals(END, drawn["p"])
        assertNull(completed["b"])
    }

    @Test
    fun b12_7_k_withoutReducedMotionARepeatKeepsRunningAndNeverCompletes() {
        val model = model(
            builder("b", "p", props = mapOf("duration" to JsonValue.Int(400), "repeat" to JsonValue.Bool(true))),
            probe("p"),
        )
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalOrcaReduceMotion provides false) { NodeView("b", model) }
        }
        compose.mainClock.advanceTimeBy(1000)
        val first = assertNotNull(drawn["p"])
        compose.mainClock.advanceTimeBy(100)

        assertNotEquals(first, drawn["p"], "still moving after two and a half cycles")
        assertNull(completed["b"])
    }

    @Test
    fun c_curves_k_aCurveOutsideTheOldNineIsHonoured() {
        val model = model(
            builder("b", "p", props = mapOf("duration" to JsonValue.Int(400), "curve" to JsonValue.String("bounceOut"))),
            probe("p"),
        )
        show(model)
        compose.mainClock.advanceTimeBy(100)

        val raw = model.raw()
        assertTrue(raw > 0.1 && raw < 0.5, "$raw")
        assertNotEquals(raw, Curves.apply("bounceOut", raw), "bounceOut is not linear here")
        assertEquals(at(Curves.apply("bounceOut", raw)), assertNotNull(drawn["p"]), 1e-9)
    }

    @Test
    fun c_curves_k_aMissingCurveIsEaseInOut() = easesInAndOut(curve = null)

    @Test
    fun c_curves_k_anUnknownCurveIsEaseInOut() = easesInAndOut(curve = "noSuchCurve")

    private fun easesInAndOut(curve: String?) {
        val model = model(
            builder("b", "p", props = mapOf("duration" to JsonValue.Int(400)) + listOfNotNull(curve?.let { "curve" to JsonValue.String(it) })),
            probe("p"),
        )
        show(model)
        compose.mainClock.advanceTimeBy(100)

        val raw = model.raw()
        assertTrue(raw > 0.1 && raw < 0.5, "$raw")
        val eased = Curves.apply("easeInOut", raw)
        assertTrue(eased < raw - 0.01, "easeInOut lags linear in the first half: $eased vs $raw")
        assertEquals(at(eased), assertNotNull(drawn["p"]), 1e-9)
    }

    private companion object {
        const val BEGIN = 0.25
        const val END = 1.0
    }
}
