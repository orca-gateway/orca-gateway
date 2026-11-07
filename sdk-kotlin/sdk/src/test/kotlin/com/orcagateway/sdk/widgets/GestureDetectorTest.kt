package com.orcagateway.sdk.widgets

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.click
import androidx.compose.ui.test.doubleClick
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * K6: GestureDetector as Flutter's `_buildGestureDetector` builds it. Each
 * trigger counts its fires in a page state key of the same name.
 */
@RunWith(RobolectricTestRunner::class)
class GestureDetectorTest {
    @get:Rule
    val compose = createComposeRule()

    private val triggers = listOf("onTap", "onDoubleTap", "onLongPress")

    /** `setState(key, key + 1)`, as the counter page's increment. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    private fun gesture(id: String, child: String, vararg on: String): ComponentNode = ComponentNode(
        id, "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        children = listOf(child), actions = on.associateWith { count(it) },
    )

    private fun single(id: String, type: String, child: String, props: Map<String, JsonValue> = emptyMap()) =
        ComponentNode(id, type, ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props, listOf(child))

    /** The page on screen, with GestureDetector known to the core and drawn by [GestureDetectorWidget]. */
    private fun show(vararg nodes: ComponentNode): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "GestureDetector")
        val state = triggers.map { StateDefinition(it, StateScope.Page, JsonValue.Int(0)) }
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("GestureDetector") { node, model, modifier -> GestureDetectorWidget(node, model, modifier) }
            }
        }
        compose.setContent { OrcaPageView(model) }
        return model
    }

    /** How many times each trigger fired. */
    private fun OrcaPageModel.fired(): Map<String, JsonValue> = triggers.associateWith { store.value(it) }

    private fun fired(tap: Int = 0, doubleTap: Int = 0, longPress: Int = 0): Map<String, JsonValue> = mapOf(
        "onTap" to JsonValue.Int(tap.toLong()),
        "onDoubleTap" to JsonValue.Int(doubleTap.toLong()),
        "onLongPress" to JsonValue.Int(longPress.toLong()),
    )

    @Test
    fun k6_withOnlyOnTapASingleTapFiresAtOnceWithNoDoubleTapWait() {
        val model = show(gesture("0", "1", "onTap"), text("1", "Tap"))
        compose.mainClock.autoAdvance = false

        compose.onNodeWithText("Tap").performTouchInput { click() }
        compose.mainClock.advanceTimeByFrame()
        assertEquals(fired(tap = 1), model.fired())
    }

    @Test
    fun k6_withOnDoubleTapTooADoubleTapFiresOnDoubleTapAndNotOnTapTwice() {
        val model = show(gesture("0", "1", "onTap", "onDoubleTap"), text("1", "Both"))
        compose.mainClock.autoAdvance = false

        compose.onNodeWithText("Both").performTouchInput { doubleClick() }
        compose.mainClock.advanceTimeBy(1_000)
        assertEquals(fired(doubleTap = 1), model.fired())

        // A single tap now waits out the double-tap timeout, then fires onTap.
        compose.onNodeWithText("Both").performTouchInput { click() }
        compose.mainClock.advanceTimeByFrame()
        assertEquals(fired(doubleTap = 1), model.fired())
        compose.mainClock.advanceTimeBy(1_000)
        assertEquals(fired(tap = 1, doubleTap = 1), model.fired())
    }

    @Test
    fun k6_aLongPressFiresOnLongPressAndNotOnTap() {
        val model = show(gesture("0", "1", "onTap", "onLongPress"), text("1", "Hold"))

        compose.onNodeWithText("Hold").performTouchInput { longClick() }
        compose.waitForIdle()
        assertEquals(fired(longPress = 1), model.fired())

        compose.onNodeWithText("Hold").performTouchInput { click() }
        compose.waitForIdle()
        assertEquals(fired(tap = 1, longPress = 1), model.fired())
    }

    @Test
    fun k6_aNodeWithNoActionsConsumesNoTouchesSoItsParentGetsThem() {
        val model = show(gesture("0", "1", "onTap"), gesture("1", "2"), text("2", "Inner"))

        compose.onNodeWithText("Inner").performTouchInput { click() }
        compose.waitForIdle()
        assertEquals(fired(tap = 1), model.fired())
    }

    @Test
    fun k6_theWholeBoxTakesTouchesNotOnlyTheChildsPixels() {
        val size = mapOf("width" to JsonValue.Int(200), "height" to JsonValue.Int(200))
        val model = show(
            gesture("0", "1", "onTap"),
            single("1", "SizedBox", "2", size),
            single("2", "Center", "3"),
            text("3", "x"),
        )

        // 10 dp inside the 200 dp box's top-left corner, well away from the
        // glyph centred in it.
        val glyph = compose.onNodeWithText("x")
        val bounds = glyph.getUnclippedBoundsInRoot()
        val dx = bounds.width / 2 - 90.dp
        val dy = bounds.height / 2 - 90.dp
        assertTrue(dx < 0.dp && dy < 0.dp, "the point is outside the glyph")
        glyph.performTouchInput { click(Offset(dx.toPx(), dy.toPx())) }
        compose.waitForIdle()
        assertEquals(fired(tap = 1), model.fired())
    }
}
