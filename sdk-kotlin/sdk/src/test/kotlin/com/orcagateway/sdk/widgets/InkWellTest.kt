package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material.ripple.RippleAlpha
import androidx.compose.material3.RippleConfiguration
import androidx.compose.material3.RippleDefaults
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.click
import androidx.compose.ui.test.doubleClick
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.draw
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.page
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
 * A6.6 and A6.7 for InkWell, as Flutter's `_buildInkWell`
 * (layout_builders.dart) builds it: Material's InkWell with onTap,
 * onLongPress and onDoubleTap always set, so a single tap waits out the
 * double-tap timeout, a long press takes Flutter's 500 ms, and it is live
 * with no actions and no `enabled`; its ink drawn under the child, clipped
 * to `borderRadius`. Each trigger counts its fires in a page state key;
 * nodes are tagged with their ids. At 1 dp per pixel, drawn in software
 * for the colours.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class InkWellTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View

    private val triggers = listOf("onTap", "onDoubleTap", "onLongPress")

    /** The counters every test may read: the InkWell's triggers and a GestureDetector around it. */
    private val keys = triggers + "outer"

    /** `setState(key, key + 1)`, as the counter page's increment. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    /** An InkWell around [child], each trigger in [on] (all three by default) counting itself. */
    private fun inkWell(id: String, child: String, vararg props: Pair<String, Any?>, on: List<String> = triggers) =
        ComponentNode(
            id, "InkWell", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props(*props), listOf(child),
            actions = on.associateWith { count(it) },
        )

    /** A GestureDetector around [child] counting its taps in `outer`. */
    private fun outer(id: String, child: String) = ComponentNode(
        id, "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        children = listOf(child), actions = mapOf("onTap" to count("outer")),
    )

    private fun container(id: String, color: String, width: Int, height: Int) = ComponentNode(
        id, "Container", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        props("color" to color, "width" to width, "height" to height),
    )

    private fun start(id: String, vararg children: String) =
        column(id, *children, props = mapOf("crossAxisAlignment" to JsonValue.String("start")))

    /**
     * The page from [nodes], its root in a 300 x 400 box; InkWell,
     * GestureDetector and Container known to the core and drawn here, they
     * and SizedBoxes tagged with their ids. With [longPressTimeout] the
     * page's surroundings take that long-press timeout instead of the
     * runner's.
     */
    private fun show(vararg nodes: ComponentNode, longPressTimeout: Long? = null): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("InkWell", "GestureDetector", "Container"))
        val state = keys.map { StateDefinition(it, StateScope.Page, JsonValue.Int(0)) }
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("InkWell") { node, model, modifier -> InkWellWidget(node, model, modifier.testTag(node.id)) }
                register("GestureDetector") { node, model, modifier ->
                    GestureDetectorWidget(node, model, modifier.testTag(node.id))
                }
                register("Container") { node, model, modifier -> ContainerWidget(node, model, modifier.testTag(node.id)) }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            val runner = LocalViewConfiguration.current
            val timing = longPressTimeout?.let { timeout ->
                object : ViewConfiguration by runner {
                    override val longPressTimeoutMillis: Long get() = timeout
                }
            } ?: runner
            CompositionLocalProvider(LocalViewConfiguration provides timing) {
                Box(Modifier.size(300.dp, 400.dp)) { NodeView(nodes.first().id, model) }
            }
        }
        compose.waitForIdle()
        return model
    }

    /** How many times each counter has fired, read as it stands. */
    private fun counted(model: OrcaPageModel): Map<String, Int> =
        keys.associateWith { model.store.value(it).doubleValue?.toInt() ?: -1 }

    /** How many times each counter fired, once every wait (the double-tap one too) has run out. */
    private fun fired(model: OrcaPageModel): Map<String, Int> {
        compose.mainClock.advanceTimeBy(1_000)
        compose.waitForIdle()
        return counted(model)
    }

    private fun counts(tap: Int = 0, doubleTap: Int = 0, longPress: Int = 0, outer: Int = 0): Map<String, Int> =
        mapOf("onTap" to tap, "onDoubleTap" to doubleTap, "onLongPress" to longPress, "outer" to outer)

    private val click = SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick)
    private val longClickAction = SemanticsMatcher.keyIsDefined(SemanticsActions.OnLongClick)

    private fun picture(): Bitmap {
        compose.waitForIdle()
        return draw(view)
    }

    /** The pixel [dx], [dy] into the node tagged [tag], in [picture]. */
    private fun assertPixel(expected: Color, picture: Bitmap, tag: String, dx: Int, dy: Int) {
        val box = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()
        val actual = picture.getPixel(box.left.value.toInt() + dx, box.top.value.toInt() + dy)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.05f },
            "$tag ($dx, $dy) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }

    private val red = Props.hex("#E53935")
    private val blue = Props.hex("#1E88E5")

    // A6.6.

    /**
     * A6.6: onDoubleTap is always set (Flutter's builder sets all three), so
     * a single tap fires onTap only once the 300 ms double-tap timeout has
     * passed with no second tap, never before.
     */
    @Test
    fun a6_6_kt_aTapFiresOnTapOnlyOnceTheDoubleTapTimeoutHasPassed() {
        val model = show(start("root", "w"), inkWell("w", "c"), sizedBox("c", 100, 50))
        compose.mainClock.autoAdvance = false

        compose.onNodeWithTag("w").performTouchInput { click() }
        compose.mainClock.advanceTimeBy(250)
        assertEquals(counts(), counted(model), "250 ms after the tap")
        compose.mainClock.advanceTimeBy(100)
        assertEquals(counts(tap = 1), counted(model), "350 ms after the tap")
    }

    /** A6.6: a double tap fires onDoubleTap once, and onTap not at all. */
    @Test
    fun a6_6_kt_aDoubleTapFiresOnDoubleTapOnly() {
        val model = show(start("root", "w"), inkWell("w", "c"), sizedBox("c", 100, 50))

        compose.onNodeWithTag("w").performTouchInput { doubleClick() }

        assertEquals(counts(doubleTap = 1), fired(model))
    }

    /**
     * A6.6: a long press fires onLongPress and no tap, after Flutter's
     * kLongPressTimeout, 500 ms, not the platform's: around the page,
     * Android 12 and later's 400 (the runner's Robolectric reports 500), and
     * still a 450 ms hold is a tap, a 510 ms one a long press. Both are
     * offered to accessibility.
     */
    @Test
    fun a6_6_kt_aLongPressFiresOnLongPressAfterFlutters500ms() {
        val model = show(start("root", "w"), inkWell("w", "c"), sizedBox("c", 100, 50), longPressTimeout = 400)
        fun hold(millis: Long) = compose.onNodeWithTag("w").performTouchInput {
            down(center)
            advanceEventTime(millis)
            up()
        }
        compose.onNodeWithTag("w").assert(click).assert(longClickAction)

        compose.onNodeWithTag("w").performTouchInput { longClick() }
        assertEquals(counts(longPress = 1), fired(model))
        hold(450)
        assertEquals(counts(tap = 1, longPress = 1), fired(model))
        hold(510)
        assertEquals(counts(tap = 1, longPress = 2), fired(model))
    }

    /**
     * A6.6: while pressed the highlight fills the InkWell in
     * `highlightColor`, clipped to `borderRadius` (20: (3, 3) lies outside
     * it, (8, 8) inside), and under the child, as Flutter paints its ink on
     * the Material below it: an opaque child hides it. Released, it is gone.
     * The splash is transparent here; Robolectric does not draw Android's
     * press ripple.
     */
    @Test
    fun a6_6_kt_aPressDrawsTheHighlightUnderTheChildClippedToTheBorderRadius() {
        show(
            start("root", "w"),
            inkWell("w", "r", "borderRadius" to 20, "highlightColor" to "#1E88E5", "splashColor" to "#00000000"),
            row("r", "clear", "opaque", props = mapOf("mainAxisSize" to JsonValue.String("min"))),
            sizedBox("clear", 50, 60),
            container("opaque", "#E53935", 50, 60),
        )
        val rest = picture()
        assertPixel(Color.White, rest, "w", 25, 30)

        compose.onNodeWithTag("w").performTouchInput { down(Offset(25f, 30f)) }
        val pressed = picture()
        assertPixel(blue, pressed, "w", 25, 30)
        assertPixel(blue, pressed, "w", 8, 8)
        assertPixel(Color.White, pressed, "w", 3, 3)
        assertPixel(blue, pressed, "w", 8, 52)
        assertPixel(Color.White, pressed, "w", 3, 57)
        assertPixel(red, pressed, "opaque", 25, 30)
        assertPixel(red, pressed, "opaque", 47, 3)

        compose.onNodeWithTag("w").performTouchInput { up() }
        compose.mainClock.advanceTimeBy(1_000)
        assertPixel(Color.White, picture(), "w", 25, 30)
    }

    /**
     * A6.6: the press ripple is drawn in `splashColor` at that colour's own
     * alpha (Flutter draws its splash as given; Compose's ripple would take
     * 0.1), dragged too; without one in ThemeData()'s splash colour,
     * #C8C8C866. Hover and focus keep Material 3's alphas. Robolectric does
     * not draw Android's press ripple, so its configuration is checked.
     */
    @Test
    fun a6_6_kt_theRippleIsTheSplashColorAtItsOwnAlpha() {
        val splash = Props.hex("#E5393580")
        val m3 = RippleDefaults.RippleAlpha
        fun at(alpha: Float) = RippleAlpha(
            draggedAlpha = alpha,
            focusedAlpha = m3.focusedAlpha,
            hoveredAlpha = m3.hoveredAlpha,
            pressedAlpha = alpha,
        )

        assertEquals(RippleConfiguration(splash, at(splash.alpha)), inkRipple(splash))
        val flutter = Props.hex("#C8C8C866")
        assertEquals(RippleConfiguration(flutter, at(flutter.alpha)), inkRipple(null))
    }

    // A6.7.

    /**
     * A6.7: an InkWell with no actions is still live, as Flutter's builder
     * sets all three handlers: it offers a click and a long click, takes
     * the touches, so a GestureDetector around it gets none, and fires
     * nothing.
     */
    @Test
    fun a6_7_kt_anInkWellWithNoActionsIsLiveAndFiresNothing() {
        val model = show(start("root", "g"), outer("g", "w"), inkWell("w", "c", on = emptyList()), sizedBox("c", 100, 50))
        compose.onNodeWithTag("w").assert(click).assert(longClickAction)

        compose.onNodeWithTag("w").performClick()
        compose.onNodeWithTag("w").performTouchInput { doubleClick() }
        compose.onNodeWithTag("w").performTouchInput { longClick() }

        assertEquals(counts(), fired(model))
    }

    /** A6.7: InkWell has no `enabled`: given `enabled: false` it still fires. */
    @Test
    fun a6_7_kt_anInkWellHasNoEnabled() {
        val model = show(start("root", "w"), inkWell("w", "c", "enabled" to false), sizedBox("c", 100, 50))

        compose.onNodeWithTag("w").performClick()

        assertEquals(counts(tap = 1), fired(model))
    }
}
