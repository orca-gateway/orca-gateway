package com.orcagateway.sdk.widgets

import android.app.Activity
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A4.4 against Flutter's `_buildAbsorbPointer` and `_buildIgnorePointer`
 * (layout_builders.dart) and their render objects: RenderAbsorbPointer is
 * hit over its box and keeps the hit from its child, so a Stack's children
 * behind it get nothing; RenderIgnorePointer is never hit, nor is anything
 * in it, so the hit goes on to what is behind. Both block their subtree's
 * semantics actions (`isBlockingUserActions`) and change nothing drawn.
 *
 * Each overlap case is a Stack of a probe behind (a GestureDetector over a
 * 120x120 Container, counting in `back`) and the wrapper in front at the
 * same origin around an 80x80 probe counting in `front`: a GestureDetector,
 * or an ElevatedButton filling an 80x80 Container. A tap at (40, 40) lands
 * on both; the claim is which counter moves. At 1 dp per pixel; the two
 * wrappers are not advertised yet, so the registry is widened by them and
 * every builder used is registered here, tagged with its node id.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class TouchTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    private fun show(width: Int, height: Int, vararg nodes: ComponentNode, state: List<StateDefinition> = emptyList()): OrcaPageModel {
        val wrappers = setOf("AbsorbPointer", "IgnorePointer", "DecoratedBox", "BlurView")
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + wrappers)
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("AbsorbPointer") { node, model, modifier -> AbsorbPointerWidget(node, model, modifier.testTag(node.id)) }
                register("IgnorePointer") { node, model, modifier -> IgnorePointerWidget(node, model, modifier.testTag(node.id)) }
                register("GestureDetector") { node, model, modifier ->
                    GestureDetectorWidget(node, model, modifier.testTag(node.id))
                }
                register("DecoratedBox") { node, model, modifier -> DecoratedBoxWidget(node, model, modifier.testTag(node.id)) }
                register("BlurView") { node, model, modifier -> BlurViewWidget(node, model, modifier.testTag(node.id)) }
                register("SingleChildScrollView") { node, model, modifier -> ScrollWidget(node, model, modifier.testTag(node.id)) }
                register("Container") { node, model, modifier -> ContainerWidget(node, model, modifier.testTag(node.id)) }
                register("Column") { node, model, modifier -> FlexWidget(node, model, modifier.testTag(node.id), vertical = true) }
                register("Row") { node, model, modifier -> FlexWidget(node, model, modifier.testTag(node.id), vertical = false) }
                for (type in listOf("ElevatedButton", "OutlinedButton", "TextButton")) {
                    register(type) { node, model, modifier -> ButtonWidget(node, model, modifier.testTag(node.id)) }
                }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(width.dp, height.dp)) { NodeView(nodes.first().id, model) }
        }
        compose.waitForIdle()
        return model
    }

    private fun node(id: String, type: String, vararg children: String, props: Map<String, JsonValue> = emptyMap()) =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout,
            if (type == "Stack" || type == "Column") ComponentNode.ChildMode.Multi else ComponentNode.ChildMode.Single,
            props, children.toList(), watches = props.values.flatMap { watched(it) },
        )

    /** The page-state keys a `{type: state}` prop reads. */
    private fun watched(value: JsonValue): List<String> =
        if (value["type"].stringValue == "state") listOfNotNull(value["key"].stringValue) else emptyList()

    private fun container(id: String, width: Int, height: Int, vararg children: String) =
        node(id, "Container", *children, props = mapOf("width" to JsonValue.Int(width.toLong()), "height" to JsonValue.Int(height.toLong())))

    /** `setState(key, key + 1)`. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    /** A GestureDetector around [child] that counts its taps in page state [key]. */
    private fun gesture(id: String, child: String, key: String) = ComponentNode(
        id, "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        children = listOf(child), actions = mapOf("onTap" to count(key)),
    )

    private fun counter(key: String) = StateDefinition(key, StateScope.Page, JsonValue.Int(0))

    /** `{type: state, key}`, the engine's `V.pageState`. */
    private fun pageState(key: String): JsonValue = JsonValue.obj("type" to "state", "key" to key)

    /** The front probe: a GestureDetector over an 80x80 Container. */
    private val gestureProbe: Array<ComponentNode>
        get() = arrayOf(gesture("front", "frontBox", "front"), container("frontBox", 80, 80))

    /** The front probe: an ElevatedButton filling an 80x80 Container. */
    private val buttonProbe: Array<ComponentNode>
        get() = arrayOf(
            container("frontBox", 80, 80, "front"),
            button("front", "ElevatedButton", "label", mapOf("onTap" to count("front"))),
            text("label", "go"),
        )

    /**
     * The Stack: the `back` probe behind, [wrapper] (`type` with `props`) in
     * front around the first of [probe], which the rest of [probe] makes up.
     */
    private fun overlap(
        type: String,
        props: Map<String, JsonValue>,
        probe: Array<ComponentNode>,
        state: List<StateDefinition> = emptyList(),
    ): OrcaPageModel = show(
        200, 200,
        node("page", "Stack", "back", "wrapper", props = mapOf("alignment" to JsonValue.String("topLeft"))),
        gesture("back", "backBox", "back"),
        container("backBox", 120, 120),
        node("wrapper", type, probe.first().id, props = props),
        *probe,
        state = listOf(counter("front"), counter("back")) + state,
    )

    /** A tap at ([x], [y]) in the page. */
    private fun tap(x: Int, y: Int) {
        compose.onRoot().performTouchInput { click(Offset(x.toFloat(), y.toFloat())) }
        compose.waitForIdle()
    }

    /** The two counters after the taps so far. */
    private fun OrcaPageModel.counts(): Pair<JsonValue?, JsonValue?> =
        compose.runOnIdle { store.value("front") to store.value("back") }

    private fun counts(front: Int, back: Int) = JsonValue.Int(front.toLong()) to JsonValue.Int(back.toLong())

    private val clickAction = SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick)
    private val noClickAction = SemanticsMatcher.keyNotDefined(SemanticsActions.OnClick)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    /** The front probe offers [action] to accessibility and, a button, keeps its label (Flutter blocks only actions). */
    private fun assertFront(action: SemanticsMatcher, probe: Array<ComponentNode>) {
        val front = compose.onNodeWithTag("front").assert(action)
        if (probe.any { it.type == "ElevatedButton" }) front.assert(hasText("go"))
    }

    // Absorbing (the default).

    private fun absorbingTakesTheTapFromBoth(probe: Array<ComponentNode>) {
        val model = overlap("AbsorbPointer", emptyMap(), probe)
        tap(40, 40)
        assertEquals(counts(front = 0, back = 0), model.counts(), "a tap on the absorber reaches neither probe")
        tap(100, 100)
        assertEquals(counts(front = 0, back = 1), model.counts(), "a tap beside it still reaches the probe behind")
        assertFront(noClickAction, probe)
    }

    /** A4.4: AbsorbPointer takes a tap over its box: its GestureDetector child and the probe behind get nothing. */
    @Test
    fun a4_4_absorbPointerBlocksItsGestureDetectorAndWhatIsBehind() = absorbingTakesTheTapFromBoth(gestureProbe)

    /** A4.4: AbsorbPointer takes a tap over its box: its ElevatedButton child and the probe behind get nothing. */
    @Test
    fun a4_4_absorbPointerBlocksItsButtonAndWhatIsBehind() = absorbingTakesTheTapFromBoth(buttonProbe)

    // Absorbing false.

    private fun notAbsorbingLeavesTheTapToTheChild(probe: Array<ComponentNode>) {
        val model = overlap("AbsorbPointer", mapOf("absorbing" to JsonValue.Bool(false)), probe)
        tap(40, 40)
        assertEquals(counts(front = 1, back = 0), model.counts(), "the child takes the tap, the probe behind does not")
        assertFront(clickAction, probe)
    }

    /** A4.4: AbsorbPointer with `absorbing: false` is only its GestureDetector child. */
    @Test
    fun a4_4_absorbingFalseLeavesTheTapToItsGestureDetector() = notAbsorbingLeavesTheTapToTheChild(gestureProbe)

    /** A4.4: AbsorbPointer with `absorbing: false` is only its ElevatedButton child. */
    @Test
    fun a4_4_absorbingFalseLeavesTheTapToItsButton() = notAbsorbingLeavesTheTapToTheChild(buttonProbe)

    // Ignoring (the default).

    private fun ignoringPassesTheTapBehind(probe: Array<ComponentNode>) {
        val model = overlap("IgnorePointer", emptyMap(), probe)
        tap(40, 40)
        assertEquals(counts(front = 0, back = 1), model.counts(), "the probe behind takes the tap, the child does not")
        assertFront(noClickAction, probe)
    }

    /** A4.4: IgnorePointer lets a tap through its GestureDetector child to the probe behind. */
    @Test
    fun a4_4_ignorePointerPassesTheTapPastItsGestureDetectorToWhatIsBehind() = ignoringPassesTheTapBehind(gestureProbe)

    /** A4.4: IgnorePointer lets a tap through its ElevatedButton child to the probe behind. */
    @Test
    fun a4_4_ignorePointerPassesTheTapPastItsButtonToWhatIsBehind() = ignoringPassesTheTapBehind(buttonProbe)

    // Ignoring false.

    private fun notIgnoringLeavesTheTapToTheChild(probe: Array<ComponentNode>) {
        val model = overlap("IgnorePointer", mapOf("ignoring" to JsonValue.Bool(false)), probe)
        tap(40, 40)
        assertEquals(counts(front = 1, back = 0), model.counts(), "the child takes the tap, the probe behind does not")
        assertFront(clickAction, probe)
    }

    /** A4.4: IgnorePointer with `ignoring: false` is only its GestureDetector child. */
    @Test
    fun a4_4_ignoringFalseLeavesTheTapToItsGestureDetector() = notIgnoringLeavesTheTapToTheChild(gestureProbe)

    /** A4.4: IgnorePointer with `ignoring: false` is only its ElevatedButton child. */
    @Test
    fun a4_4_ignoringFalseLeavesTheTapToItsButton() = notIgnoringLeavesTheTapToTheChild(buttonProbe)

    // `ignoring` bound to page state (fixture 43 binds it to `ignore`).

    private fun flippingIgnoringHandsTheNextTapToTheChild(probe: Array<ComponentNode>) {
        val model = overlap(
            "IgnorePointer", mapOf("ignoring" to pageState("ignore")), probe,
            state = listOf(StateDefinition("ignore", StateScope.Page, JsonValue.Bool(true))),
        )
        tap(40, 40)
        assertEquals(counts(front = 0, back = 1), model.counts(), "ignoring: the probe behind")
        compose.runOnIdle { model.store.dispatch(mapOf("ignore" to JsonValue.Bool(false))) }
        compose.waitForIdle()
        tap(40, 40)
        assertEquals(counts(front = 1, back = 1), model.counts(), "no longer ignoring: the child")
        assertFront(clickAction, probe)
    }

    /** A4.4: when the bound `ignoring` turns false, the GestureDetector child takes the next tap. */
    @Test
    fun a4_4_ignoringBoundToStateFlipsForAGestureDetector() = flippingIgnoringHandsTheNextTapToTheChild(gestureProbe)

    /** A4.4: when the bound `ignoring` turns false, the ElevatedButton child takes the next tap. */
    @Test
    fun a4_4_ignoringBoundToStateFlipsForAButton() = flippingIgnoringHandsTheNextTapToTheChild(buttonProbe)

    // Around, inside and under other hit takers.

    /**
     * A4.4: an absorbing AbsorbPointer is hit, so, as in Flutter, where a
     * hit adds every ancestor of the box hit, the GestureDetector around it
     * still counts a tap on it; its own child does not.
     */
    @Test
    fun a4_4_aGestureDetectorAroundAnAbsorberStillTakesTheTap() {
        val model = show(
            200, 200,
            gesture("back", "wrapper", "back"),
            node("wrapper", "AbsorbPointer", "front"),
            *gestureProbe,
            state = listOf(counter("front"), counter("back")),
        )
        tap(40, 40)
        assertEquals(counts(front = 0, back = 1), model.counts(), "the GestureDetector around it, not the one in it")
    }

    /** A4.4: a drag that starts on an absorbing AbsorbPointer still scrolls the scroll view around it, as in Flutter. */
    @Test
    fun a4_4_aDragStartingOnAnAbsorberStillScrollsTheViewAroundIt() {
        show(
            200, 200,
            node("scroll", "SingleChildScrollView", "list"),
            node("list", "Column", "wrapper", "below"),
            node("wrapper", "AbsorbPointer", "top"),
            container("top", 100, 300), container("below", 100, 300),
        )
        compose.onRoot().performTouchInput { swipe(start = Offset(50f, 150f), end = Offset(50f, 50f)) }
        compose.waitForIdle()
        val top = bounds("list").top
        assertTrue(top < (-40).dp, "the Column scrolled up by the drag: its top is at $top")
    }

    /** A4.4: an AbsorbPointer inside an ignoring IgnorePointer is ignored with it: the probe behind takes the tap. */
    @Test
    fun a4_4_anAbsorberInsideAnIgnorePointerLetsTheTapThrough() {
        val model = overlap("IgnorePointer", emptyMap(), arrayOf(node("absorb", "AbsorbPointer", "front"), *gestureProbe))
        tap(40, 40)
        assertEquals(counts(front = 0, back = 1), model.counts(), "the probe behind takes the tap")
    }

    /** A4.4: a DecoratedBox, which takes the taps over its box, takes none under an IgnorePointer. */
    @Test
    fun a4_4_ignorePointerPassesTheTapPastADecoratedBox() {
        val decorated = mapOf("decoration" to JsonValue.obj("color" to "#3366CC"))
        val model = overlap(
            "IgnorePointer", emptyMap(),
            arrayOf(node("deco", "DecoratedBox", "frontBox", props = decorated), container("frontBox", 80, 80)),
        )
        tap(40, 40)
        assertEquals(counts(front = 0, back = 1), model.counts(), "the probe behind takes the tap")
    }

    /** A4.4: a BlurView, which takes the taps over its box, takes none under an IgnorePointer. */
    @Test
    fun a4_4_ignorePointerPassesTheTapPastABlurView() {
        val model = overlap(
            "IgnorePointer", emptyMap(),
            arrayOf(node("blur", "BlurView", "frontBox", props = mapOf("overlayColor" to JsonValue.String("#FFFFFF80"))), container("frontBox", 80, 80)),
        )
        tap(40, 40)
        assertEquals(counts(front = 0, back = 1), model.counts(), "the probe behind takes the tap")
    }

    // Layout and paint.

    /** A4.4: each wrapper, either way, is its child's size: 60x40 around a 60x40 Container. */
    @Test
    fun a4_4_eachWrapperIsItsChildsSize() {
        show(
            200, 300,
            column("root", "absorb", "notAbsorb", "ignore", "notIgnore", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            node("absorb", "AbsorbPointer", "c1"),
            node("notAbsorb", "AbsorbPointer", "c2", props = mapOf("absorbing" to JsonValue.Bool(false))),
            node("ignore", "IgnorePointer", "c3"),
            node("notIgnore", "IgnorePointer", "c4", props = mapOf("ignoring" to JsonValue.Bool(false))),
            container("c1", 60, 40), container("c2", 60, 40), container("c3", 60, 40), container("c4", 60, 40),
        )
        for (id in listOf("absorb", "notAbsorb", "ignore", "notIgnore")) {
            val box = bounds(id)
            assertEquals(60.dp to 40.dp, box.width to box.height, id)
        }
    }

    /**
     * A4.4: a button under an ignoring IgnorePointer or an absorbing
     * AbsorbPointer draws as without it, never as disabled. One column of
     * buttons (default, styled, outlined, text, disabled, raised to 6) under
     * an IgnorePointer and an AbsorbPointer bound to page state is drawn by
     * the hardware renderer, shadows included, four times at the same place:
     * plain, ignored, plain again, absorbed. Each blocked picture may differ
     * from the first plain one, per 8-bit channel, by no more than the
     * second plain one does. (Side by side, the same buttons differ with
     * their x: the shadows follow the light's position and some edges
     * anti-alias a few levels apart.)
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_4_aBlockedButtonDrawsAsAnUnblockedOne() {
        val tap = mapOf("onTap" to count("front"))
        val model = show(
            300, 400,
            node("ignored", "IgnorePointer", "absorbed", props = mapOf("ignoring" to pageState("ignore"))),
            node("absorbed", "AbsorbPointer", "pad", props = mapOf("absorbing" to pageState("absorb"))),
            node("pad", "Container", "buttons", props = mapOf("padding" to JsonValue.obj("top" to 16, "right" to 16, "bottom" to 16, "left" to 16))),
            column("buttons", "E", "S", "O", "T", "D", "R"),
            button("E", "ElevatedButton", "e", tap),
            button(
                "S", "ElevatedButton", "s", tap,
                mapOf(
                    "backgroundColor" to JsonValue.String("#3366CC"),
                    "foregroundColor" to JsonValue.String("#FFFFFF"),
                    "borderRadius" to JsonValue.Int(4),
                ),
            ),
            button("O", "OutlinedButton", "o", tap, mapOf("color" to JsonValue.String("#CC3333"), "borderColor" to JsonValue.String("#33CC33"))),
            button("T", "TextButton", "t", tap),
            button("D", "ElevatedButton", "d", tap, mapOf("enabled" to JsonValue.Bool(false))),
            button("R", "ElevatedButton", "r", tap, mapOf("elevation" to JsonValue.Int(6), "backgroundColor" to JsonValue.String("#FFFFFF"))),
            text("e", "Elevated"), text("s", "Styled"), text("o", "Outlined"), text("t", "Text"), text("d", "Disabled"), text("r", "Raised"),
            state = listOf(
                counter("front"),
                StateDefinition("ignore", StateScope.Page, JsonValue.Bool(false)),
                StateDefinition("absorb", StateScope.Page, JsonValue.Bool(false)),
            ),
        )

        fun shot(ignore: Boolean, absorb: Boolean): Bitmap {
            compose.runOnIdle { model.store.dispatch(mapOf("ignore" to JsonValue.Bool(ignore), "absorb" to JsonValue.Bool(absorb))) }
            compose.waitForIdle()
            return capture()
        }

        /** The most any channel of [other] differs from [base], and where. */
        fun apart(base: Bitmap, other: Bitmap): Pair<Int, String> {
            var most = 0 to "nowhere"
            for (y in 0 until base.height) {
                for (x in 0 until base.width) {
                    val want = base.getPixel(x, y)
                    val got = other.getPixel(x, y)
                    val channel = listOf(16, 8, 0).maxOf { abs((want shr it and 0xFF) - (got shr it and 0xFF)) }
                    if (channel > most.first) {
                        most = channel to "($x, $y) #${Integer.toHexString(got)} for #${Integer.toHexString(want)}"
                    }
                }
            }
            return most
        }

        val plain = shot(ignore = false, absorb = false)
        val ignored = shot(ignore = true, absorb = false)
        val plain2 = shot(ignore = false, absorb = false)
        val absorbed = shot(ignore = false, absorb = true)

        // The pictures hold the buttons: the styled fill, and the raised button's shadow below it.
        val styled = bounds("S")
        assertEquals("ff3366cc", Integer.toHexString(plain.getPixel((styled.left + 4.dp).value.toInt(), (styled.top + 4.dp).value.toInt())))
        val raised = bounds("R")
        val shadow = plain.getPixel((raised.left + raised.width / 2).value.toInt(), (raised.bottom + 2.dp).value.toInt())
        assertTrue(0xFF - (shadow and 0xFF) >= 8, "the raised button casts a shadow: #${Integer.toHexString(shadow)} below it")

        val (noise, noiseAt) = apart(plain, plain2)
        for ((name, picture) in listOf("ignored" to ignored, "absorbed" to absorbed)) {
            val (most, at) = apart(plain, picture)
            assertTrue(
                most <= noise,
                "the $name picture differs from the plain one by $most at $at; a second plain one by at most $noise ($noiseAt)",
            )
        }
    }

    /** The window as Robolectric's hardware renderer draws it (elevation shadows included), through PixelCopy, as ButtonTest's. */
    private fun capture(): Bitmap {
        val view = requireNotNull(view)
        val activity = generateSequence(view.context) { (it as? ContextWrapper)?.baseContext }
            .filterIsInstance<Activity>().first()
        val decor = activity.window.decorView
        val bitmap = Bitmap.createBitmap(decor.width, decor.height, Bitmap.Config.ARGB_8888)
        PixelCopy.request(activity.window, bitmap, {}, Handler(Looper.getMainLooper()))
        val at = IntArray(2).also { view.getLocationInWindow(it) }
        return Bitmap.createBitmap(bitmap, at[0], at[1], view.width, view.height)
    }
}
