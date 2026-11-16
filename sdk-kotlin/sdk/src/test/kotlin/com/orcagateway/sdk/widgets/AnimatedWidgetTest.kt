package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.width
import com.orcagateway.core.animation.AlignmentBias
import com.orcagateway.core.animation.AnimationMix
import com.orcagateway.core.animation.Curves
import com.orcagateway.core.animation.ImplicitAnimation
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * AnimatedContainer, AnimatedOpacity, AnimatedAlign, AnimatedSwitcher and
 * Hero on the test frame clock, at 1 dp per pixel. The three implicit
 * widgets are drawn by the real Container, opacity and Align code; the test
 * builders only record the props that code was handed, frame by frame, and
 * the expected values come from the core's [ImplicitAnimation] fed the same
 * frame times.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class AnimatedWidgetTest {
    @get:Rule
    val compose = createComposeRule()

    /** The props each implicit widget last handed to its drawing code, by node id. */
    private val drawn = HashMap<String, Map<String, JsonValue>>()

    /** How many times each implicit widget was drawn. */
    private val draws = HashMap<String, Int>()

    private val fade = SwitcherFade()

    private fun record(id: String, props: Map<String, JsonValue>) {
        drawn[id] = props
        draws[id] = (draws[id] ?: 0) + 1
    }

    private fun model(vararg nodes: ComponentNode, state: Map<String, Any?> = emptyMap()): OrcaPageModel {
        val definitions = state.map { StateDefinition(it.key, StateScope.Page, JsonValue.of(it.value)) }
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + ANIMATED + "Dot")
        return OrcaPageModel(page(*nodes, state = definitions), registry = registry).also { model ->
            model.builders = WidgetBuilders.standard().apply {
                register("AnimatedContainer") { node, m, modifier ->
                    AnimatedContainerWidget(node, m, modifier) { sampled, sm, smod ->
                        record(sampled.id, sampled.props)
                        ContainerWidget(sampled, sm, smod.testTag(sampled.id))
                    }
                }
                register("AnimatedOpacity") { node, m, modifier ->
                    AnimatedOpacityWidget(node, m, modifier) { sampled, sm, smod ->
                        record(sampled.id, sampled.props)
                        OpacityWidget(sampled, sm, smod)
                    }
                }
                register("AnimatedAlign") { node, m, modifier ->
                    AnimatedAlignWidget(node, m, modifier) { sampled, sm, smod ->
                        record(sampled.id, sampled.props)
                        AlignWidget(sampled, sm, smod)
                    }
                }
                register("AnimatedSwitcher") { node, m, modifier -> AnimatedSwitcherWidget(node, m, modifier, fade) }
                // A 20 x 10 box tagged with its node id.
                register("Dot") { node, _, modifier -> Box(modifier.testTag(node.id).size(20.dp, 10.dp)) }
            }
        }
    }

    /** A single-child node; it watches the page state keys its props read ([state]), as the encoder would say. */
    private fun single(id: String, type: String, child: String?, props: Map<String, Any?>): ComponentNode =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            props.mapValues { JsonValue.of(it.value) }, listOfNotNull(child),
            watches = props.values.mapNotNull { (it as? Map<*, *>)?.get("key") as? String },
        )

    private fun dot(id: String): ComponentNode =
        ComponentNode(id, "Dot", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, emptyMap())

    private fun state(key: String): Map<String, Any?> = mapOf("type" to "state", "key" to key, "scope" to "page")

    private fun show(model: OrcaPageModel, root: String, reduceMotion: Boolean = false) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalOrcaReduceMotion provides reduceMotion) {
                Box(Modifier.size(300.dp, 200.dp)) { NodeView(root, model) }
            }
        }
        compose.mainClock.advanceTimeByFrame()
    }

    /**
     * Runs [change] on the main thread and hands what it wrote to Compose,
     * so the next frame redraws it (the frame clock is stepped by hand here,
     * and nothing else would deliver the write before that frame).
     */
    private fun change(change: () -> Unit) {
        compose.runOnIdle {
            change()
            Snapshot.sendApplyNotifications()
        }
    }

    private fun OrcaPageModel.set(vararg update: Pair<String, Any?>) {
        change { store.dispatch(update.associate { it.first to JsonValue.of(it.second) }) }
    }

    /**
     * Steps frames until the page takes one: a widget at rest takes none,
     * so that frame is the one its run began at. Its time.
     */
    private fun OrcaPageModel.startOfRun(): Double {
        val before = animationFrameMs
        repeat(5) {
            compose.mainClock.advanceTimeByFrame()
            if (animationFrameMs != before) return animationFrameMs
        }
        error("no animation frame was taken")
    }

    /** Steps frames until [elapsed] ms after [start]; the frame's time. */
    private fun OrcaPageModel.runTo(start: Double, elapsed: Double): Double {
        while (animationFrameMs - start < elapsed) {
            val before = animationFrameMs
            compose.mainClock.advanceTimeByFrame()
            check(animationFrameMs != before) { "the run stopped taking frames at ${before - start} ms" }
        }
        return animationFrameMs
    }

    private fun core(durationMs: Double, curve: String?, first: Map<String, JsonValue>) =
        ImplicitAnimation(durationMs, curve, mix = AnimationMix::props).apply { retarget(first, 0.0) }

    // MARK: AnimatedContainer (B12.2)

    private fun container(curve: String?): OrcaPageModel = model(
        single(
            "box", "AnimatedContainer", "label",
            mapOf("duration" to 300, "width" to state("w"), "height" to 40, "color" to state("c")) +
                listOfNotNull(curve?.let { "curve" to it }),
        ),
        text("label", "Details"),
        state = mapOf("w" to 100, "c" to "#1565C0"),
    )

    private fun containerMidRun(curve: String?) {
        val model = container(curve)
        show(model, "box")
        val from = assertNotNull(drawn["box"])
        assertEquals(100.0, from["width"]?.doubleValue)

        model.set("w" to 200, "c" to "#FF6F00")
        val start = model.startOfRun()
        val to = from + mapOf("width" to JsonValue.Int(200), "color" to JsonValue.String("#FF6F00"))
        val twin = core(300.0, curve, from).apply { retarget(to, start) }
        // The run starts at the value on screen: the mix at 0, which writes 100 as 100.0 and the colour with its alpha.
        assertEquals(AnimationMix.props(from, to, 0.0), drawn["box"])
        assertEquals(100.0, drawn["box"]?.get("width")?.doubleValue)
        assertEquals("#1565C0FF", drawn["box"]?.get("color")?.stringValue)

        val now = model.runTo(start, 150.0)
        val t = (now - start) / 300.0
        assertTrue(t >= 0.5 && t < 0.6, "about half way by the test clock: $t")
        val expected = AnimationMix.props(from, to, Curves.apply(curve ?: "easeInOut", t))
        assertEquals(expected, drawn["box"])
        assertEquals(twin.value(now), drawn["box"])
        val width = assertNotNull(drawn["box"]?.get("width")?.doubleValue)
        assertTrue(width > 140 && width < 175, "$width")
        val colour = drawn["box"]?.get("color")?.stringValue
        assertNotEquals("#1565C0", colour)
        assertNotEquals("#FF6F00", colour)
        // The Container on screen is as wide as the sampled prop says.
        assertEquals(width, compose.onNodeWithTag("box").getUnclippedBoundsInRoot().width.value.toDouble(), 0.51)

        compose.mainClock.advanceTimeBy(200)
        assertEquals(to, drawn["box"], "the end state is the target itself")
        assertEquals(200.dp, compose.onNodeWithTag("box").getUnclippedBoundsInRoot().width)
        val rested = model.animationFrameMs
        compose.mainClock.advanceTimeBy(500)
        assertEquals(rested, model.animationFrameMs, "no frames once the run is over")
    }

    @Test
    fun b12_2_k_containerWidthAndColourAt150Of300MsEqualTheCoresMix_linear() = containerMidRun("linear")

    @Test
    fun b12_2_k_containerWidthAndColourAt150Of300MsEqualTheCoresMix_easeInOut() = containerMidRun("easeInOut")

    @Test
    fun b12_2_k_aMissingCurveIsEaseInOut() = containerMidRun(null)

    @Test
    fun b12_2_k_aRetargetMidRunStartsFromTheValueOnScreen() {
        val model = container("linear")
        show(model, "box")
        val first = assertNotNull(drawn["box"])
        model.set("w" to 200)
        val start = model.startOfRun()
        val second = first + ("width" to JsonValue.Int(200))
        val twin = core(300.0, "linear", first).apply { retarget(second, start) }
        model.runTo(start, 150.0)

        model.set("w" to 50)
        // The frame that redraws the widget with its new target still belongs
        // to the first run; the new run begins at the frame after it.
        compose.mainClock.advanceTimeByFrame()
        val before = assertNotNull(drawn["box"]?.get("width")?.doubleValue)
        assertEquals(twin.value(model.animationFrameMs), drawn["box"])
        compose.mainClock.advanceTimeByFrame()
        val restart = model.animationFrameMs
        val third = first + ("width" to JsonValue.Int(50))
        twin.retarget(third, restart)
        val turning = assertNotNull(drawn["box"]?.get("width")?.doubleValue)
        assertTrue(turning >= before && turning < 200, "no jump back to an end: $before then $turning")

        // From there a full 300 ms to the new target, each frame the core's mix.
        var last = turning
        while (model.animationFrameMs - restart < 280) {
            compose.mainClock.advanceTimeByFrame()
            assertEquals(twin.value(model.animationFrameMs), drawn["box"])
            val width = assertNotNull(drawn["box"]?.get("width")?.doubleValue)
            assertTrue(width < last && width > 50, "falling from the turning point: $last then $width")
            last = width
        }
        compose.mainClock.advanceTimeBy(48)
        assertEquals(third, drawn["box"])
    }

    @Test
    fun b12_2_k_theFirstCompositionShowsTheTargetWithNoAnimation() {
        val model = container("linear")
        show(model, "box")
        compose.mainClock.advanceTimeBy(1000)

        assertEquals(model.resolve("box")?.props, drawn["box"])
        assertEquals(1, draws["box"])
        assertEquals(0.0, model.animationFrameMs, "a widget at rest takes no frames")
        assertEquals(100.dp, compose.onNodeWithTag("box").getUnclippedBoundsInRoot().width)
    }

    // MARK: AnimatedOpacity and AnimatedAlign (B12.3)

    @Test
    fun b12_3_k_opacityMidRunEqualsTheCoresMixThroughItsCurve() {
        val model = model(
            single("fade", "AnimatedOpacity", "label", mapOf("opacity" to state("o"), "duration" to 300, "curve" to "bounceOut")),
            text("label", "Draft"),
            state = mapOf("o" to 1),
        )
        show(model, "fade")
        val from = assertNotNull(drawn["fade"])

        model.set("o" to 0.25)
        val start = model.startOfRun()
        val to = from + ("opacity" to JsonValue.Double(0.25))
        val now = model.runTo(start, 150.0)
        val t = (now - start) / 300.0
        val expected = 1.0 + (0.25 - 1.0) * Curves.apply("bounceOut", t)
        assertEquals(expected, assertNotNull(drawn["fade"]?.get("opacity")?.doubleValue), 1e-9)
        assertEquals(AnimationMix.props(from, to, Curves.apply("bounceOut", t)), drawn["fade"])
        compose.onNodeWithText("Draft").assertExists()

        compose.mainClock.advanceTimeBy(200)
        assertEquals(to, drawn["fade"])
    }

    @Test
    fun b12_3_k_aMissingOpacityAnimatesFromFlutters1() {
        val model = model(
            single("fade", "AnimatedOpacity", "label", mapOf("opacity" to state("o"), "duration" to 300, "curve" to "linear")),
            text("label", "Draft"),
            state = mapOf("o" to null),
        )
        show(model, "fade")
        assertEquals(1.0, drawn["fade"]?.get("opacity")?.doubleValue)

        model.set("o" to 0)
        val start = model.startOfRun()
        val now = model.runTo(start, 150.0)
        assertEquals(1.0 - (now - start) / 300.0, assertNotNull(drawn["fade"]?.get("opacity")?.doubleValue), 1e-9)
    }

    private fun align(corner: String?): OrcaPageModel = model(
        single("dock", "AnimatedAlign", "dot", mapOf("alignment" to state("corner"), "duration" to 300, "curve" to "linear")),
        dot("dot"),
        state = mapOf("corner" to corner),
    )

    @Test
    fun b12_3_k_alignMidRunIsThePointBetweenTheTwoAlignments() {
        val model = align("topLeft")
        show(model, "dock")
        val from = assertNotNull(drawn["dock"])
        assertEquals(0.dp, compose.onNodeWithTag("dot").getUnclippedBoundsInRoot().left)

        model.set("corner" to "bottomRight")
        val start = model.startOfRun()
        val to = from + ("alignment" to JsonValue.String("bottomRight"))
        val now = model.runTo(start, 150.0)
        val t = (now - start) / 300.0
        assertEquals(AnimationMix.props(from, to, t), drawn["dock"])
        val bias = AlignmentBias.of(drawn["dock"]?.get("alignment"))
        assertEquals(-1.0 + 2.0 * t, bias.x, 1e-9)
        assertEquals(-1.0 + 2.0 * t, bias.y, 1e-9)
        // On screen: the 20 x 10 dot that far along the 300 x 200 box.
        val bounds = compose.onNodeWithTag("dot").getUnclippedBoundsInRoot()
        assertEquals(280.0 * t, bounds.left.value.toDouble(), 0.51)
        assertEquals(190.0 * t, bounds.top.value.toDouble(), 0.51)

        compose.mainClock.advanceTimeBy(200)
        assertEquals(to, drawn["dock"])
        assertEquals(280.dp, compose.onNodeWithTag("dot").getUnclippedBoundsInRoot().left)
        assertEquals(190.dp, compose.onNodeWithTag("dot").getUnclippedBoundsInRoot().top)
    }

    @Test
    fun b12_3_k_aMissingAlignmentAnimatesFromFluttersCentre() {
        val model = align(null)
        show(model, "dock")
        assertEquals(140.dp, compose.onNodeWithTag("dot").getUnclippedBoundsInRoot().left)

        model.set("corner" to "bottomRight")
        val start = model.startOfRun()
        val now = model.runTo(start, 150.0)
        val t = (now - start) / 300.0
        val bias = AlignmentBias.of(drawn["dock"]?.get("alignment"))
        assertEquals(t, bias.x, 1e-9)
        assertEquals(t, bias.y, 1e-9)
    }

    // MARK: AnimatedSwitcher (B12.4)

    private fun switcher(): OrcaPageModel = model(
        single("sw", "AnimatedSwitcher", "a", mapOf("duration" to 300)),
        text("a", "Old", mapOf("maxLines" to JsonValue.of(state("lines")))).copy(watches = listOf("lines")),
        state = mapOf("lines" to 1),
    )

    @Test
    fun b12_4_k_aNewChildIdFadesTheOldOutAndTheNewInThenOnlyTheNewStays() {
        val model = switcher()
        show(model, "sw")
        compose.onNodeWithText("Old").assertExists()
        assertNull(fade.outgoing)
        assertEquals(1.0, fade.incomingAlpha)

        change { model.apply(ComponentMutation.Add("sw", listOf(text("b", "New")), position = 0)) }
        val start = model.startOfRun()
        val now = model.runTo(start, 150.0)
        val t = (now - start) / 300.0

        compose.onNodeWithText("Old").assertExists()
        compose.onNodeWithText("New").assertExists()
        assertEquals("a", fade.outgoing)
        assertEquals("b", fade.current)
        assertEquals(t, fade.incomingAlpha, 1e-9)
        assertEquals(1.0 - t, fade.outgoingAlpha, 1e-9)
        assertEquals(1.0, fade.incomingAlpha + fade.outgoingAlpha, 1e-9)

        compose.mainClock.advanceTimeBy(200)
        compose.onNodeWithText("New").assertExists()
        compose.onNodeWithText("Old").assertDoesNotExist()
        assertNull(fade.outgoing)
        assertEquals(1.0, fade.incomingAlpha)
        val rested = model.animationFrameMs
        compose.mainClock.advanceTimeBy(500)
        assertEquals(rested, model.animationFrameMs, "no frames once the fade is over")
    }

    @Test
    fun b12_4_k_theSameChildIdWithNewPropsDoesNotFade() {
        val model = switcher()
        show(model, "sw")

        model.set("lines" to 2)
        change { model.apply(ComponentMutation.Update("a", mapOf("data" to JsonValue.String("Edited")))) }
        compose.mainClock.advanceTimeBy(160)

        compose.onNodeWithText("Edited").assertExists()
        compose.onNodeWithText("Old").assertDoesNotExist()
        assertEquals("a", fade.current)
        assertNull(fade.outgoing)
        assertEquals(1.0, fade.incomingAlpha)
        assertEquals(0.0, model.animationFrameMs, "no fade, so no frames")
    }

    @Test
    fun b12_4_k_aReplacedChildIsGoneFromThePageSoOnlyTheNewOneFadesIn() {
        val model = switcher()
        show(model, "sw")

        change { model.apply(ComponentMutation.Replace("a", listOf(text("b", "New")))) }
        val start = model.startOfRun()
        val now = model.runTo(start, 150.0)

        compose.onNodeWithText("New").assertExists()
        compose.onNodeWithText("Old").assertDoesNotExist()
        assertEquals((now - start) / 300.0, fade.incomingAlpha, 1e-9)
        compose.mainClock.advanceTimeBy(200)
        assertEquals(1.0, fade.incomingAlpha)
    }

    // MARK: reduced motion (B12.7)

    @Test
    fun b12_7_k_reducedMotionShowsTheEndStateAtOnceForAllFour() {
        val model = model(
            ComponentNode(
                "col", "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, emptyMap(),
                listOf("box", "fade", "dock", "sw"),
            ),
            single("box", "AnimatedContainer", null, mapOf("duration" to 300, "width" to state("w"), "height" to 20, "color" to state("c"))),
            single("fade", "AnimatedOpacity", "label", mapOf("duration" to 300, "opacity" to state("o"))),
            text("label", "Draft"),
            single("dock", "AnimatedAlign", "dot", mapOf("duration" to 300, "alignment" to state("corner"), "heightFactor" to 1)),
            dot("dot"),
            single("sw", "AnimatedSwitcher", "a", mapOf("duration" to 300)),
            text("a", "Old"),
            state = mapOf("w" to 100, "c" to "#1565C0", "o" to 1, "corner" to "topLeft"),
        )
        show(model, "col", reduceMotion = true)
        val box = assertNotNull(drawn["box"])
        val opacity = assertNotNull(drawn["fade"])
        val dock = assertNotNull(drawn["dock"])

        model.set("w" to 200, "c" to "#FF6F00", "o" to 0.25, "corner" to "bottomRight")
        change { model.apply(ComponentMutation.Add("sw", listOf(text("b", "New")), position = 0)) }
        compose.mainClock.advanceTimeByFrame()

        assertEquals(box + mapOf("width" to JsonValue.Int(200), "color" to JsonValue.String("#FF6F00")), drawn["box"])
        assertEquals(opacity + ("opacity" to JsonValue.Double(0.25)), drawn["fade"])
        assertEquals(dock + ("alignment" to JsonValue.String("bottomRight")), drawn["dock"])
        assertEquals(200.dp, compose.onNodeWithTag("box").getUnclippedBoundsInRoot().width)
        assertEquals(280.dp, compose.onNodeWithTag("dot").getUnclippedBoundsInRoot().left)
        compose.onNodeWithText("New").assertExists()
        compose.onNodeWithText("Old").assertDoesNotExist()
        assertNull(fade.outgoing)
        assertEquals(1.0, fade.incomingAlpha)

        compose.mainClock.advanceTimeBy(500)
        assertEquals(0.0, model.animationFrameMs, "nothing ran, so no frames")
        assertEquals(200.0, drawn["box"]?.get("width")?.doubleValue)
    }

    // MARK: Hero (the plain-push half of B12.5) and the registry

    @Test
    fun b12_5_k_heroDrawsItsChildAndCarriesItsTag() {
        val model = model(
            ComponentNode(
                "col", "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, emptyMap(),
                listOf("tagged", "empty", "bare", "childless"),
            ),
            single("tagged", "Hero", "t1", mapOf("tag" to "product-7")),
            text("t1", "Wireless Headphones"),
            single("empty", "Hero", "t2", mapOf("tag" to "")),
            text("t2", "Empty tag"),
            single("bare", "Hero", "t3", emptyMap()),
            text("t3", "No tag"),
            single("childless", "Hero", null, mapOf("tag" to "nothing")),
        )
        show(model, "col")

        compose.onNodeWithText("Wireless Headphones").assertExists()
        compose.onNodeWithText("Empty tag").assertExists()
        compose.onNodeWithText("No tag").assertExists()
        // The seam of the shared-element flight: a Hero with a tag is findable by it.
        compose.onNode(SemanticsMatcher.expectValue(OrcaHeroTag, "product-7")).assertExists()
        compose.onNode(SemanticsMatcher.expectValue(OrcaHeroTag, "")).assertDoesNotExist()
        compose.onNode(SemanticsMatcher.expectValue(OrcaHeroTag, "nothing")).assertDoesNotExist()
    }

    @Test
    fun b12_k_theFiveWidgetsAreDrawnAndNotDegraded() {
        val standard = WidgetBuilders.standard()
        for (type in ANIMATED) {
            assertNotNull(standard[type], "no builder for $type")
            assertTrue(WidgetRegistry.shared.supports(type), "$type degrades to the fallback")
        }
        // Drawn by the standard builders, through the shared registry.
        val page = page(
            single("box", "AnimatedContainer", "fade", mapOf("width" to 120)),
            single("fade", "AnimatedOpacity", "dock", mapOf("opacity" to 0.5)),
            single("dock", "AnimatedAlign", "sw", mapOf("alignment" to "center")),
            single("sw", "AnimatedSwitcher", "hero", emptyMap()),
            single("hero", "Hero", "label", mapOf("tag" to "t")),
            text("label", "Inside all five"),
        )
        val model = OrcaPageModel(page)
        show(model, "box")

        compose.onNodeWithText("Inside all five").assertExists()
        assertEquals(emptySet(), model.builders.reportedMissing)
        assertNull(model.resolve("box")?.degradedFrom)
    }

    private companion object {
        val ANIMATED = setOf("AnimatedContainer", "AnimatedOpacity", "AnimatedAlign", "AnimatedSwitcher", "Hero")
    }
}
