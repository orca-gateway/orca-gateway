package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A2.4 on Android: a SingleChildScrollView runs onScrollBegin, onScrolling
 * and onScrollEnd, Flutter's `wrapScrollNotifier` (builder_helpers.dart:
 * 46-71), and each reads its payload through `V.event` into page state. A
 * view of 100 over content 300 long scrolls 200 (maxExtent), in dp, which
 * is Flutter's logical pixel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class ScrollTriggerTest {
    @get:Rule
    val compose = createComposeRule()

    /** `setState(key, event[field])`, one per pair. */
    private fun write(vararg keys: Pair<String, String>): Action = Action.ActionGroup(
        mode = "sequential",
        actions = keys.map { (key, field) ->
            Action.SetState(key = key, value = JsonValue.parse("""{"type":"event","key":"$field"}"""))
        },
    )

    /** `setState(key, key + 1)`. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    private val triggers: Map<String, Action> = mapOf(
        "onScrollBegin" to Action.ActionGroup(
            mode = "sequential",
            actions = listOf(count("begins"), write("beginOffset" to "offset", "beginAtStart" to "atStart")),
        ),
        "onScrolling" to write("offset" to "offset", "maxExtent" to "maxExtent", "atEnd" to "atEnd", "delta" to "delta"),
        "onScrollEnd" to Action.ActionGroup(
            mode = "sequential",
            actions = listOf(count("ends"), write("endOffset" to "offset", "endAtEnd" to "atEnd", "viewport" to "viewportDimension")),
        ),
    )

    /** A scroll view [id] of 100 x 100 over a SizedBox 300 long on its axis, with [actions]. */
    private fun show(actions: Map<String, Action>, horizontal: Boolean = false): OrcaPageModel {
        val props = if (horizontal) mapOf("scrollDirection" to JsonValue.String("horizontal")) else emptyMap()
        val scroll = ComponentNode(
            "s", "SingleChildScrollView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            props, listOf("b"), actions = actions,
        )
        val content = if (horizontal) sizedBox("b", 300, 40) else sizedBox("b", 40, 300)
        val model = OrcaPageModel(page(scroll, content))
        compose.setContent {
            Box(Modifier.size(100.dp, 100.dp), propagateMinConstraints = true) { NodeView("s", model) }
        }
        compose.waitForIdle()
        return model
    }

    private fun OrcaPageModel.value(key: String): JsonValue? = store.state.page[key]

    /** Scroll the view by [by] dp (the semantics action, an animated scroll like a user's). */
    private fun scrollBy(by: Float, horizontal: Boolean = false) {
        compose.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) {
            if (horizontal) it(by, 0f) else it(0f, by)
        }
        compose.waitForIdle()
    }

    /** A2.4 (kt ui): scrolling to the end runs begin at the start, onScrolling with the offsets, and end at the end. */
    @Test
    fun a2_4_kt_scrollingToTheEndRunsTheThreeTriggers() {
        val model = show(triggers)
        assertEquals(null, model.value("begins"))

        scrollBy(1000f)

        assertEquals(JsonValue.Int(1), model.value("begins"))
        assertEquals(JsonValue.Double(0.0), model.value("beginOffset"))
        assertEquals(JsonValue.Bool(true), model.value("beginAtStart"))
        assertEquals(JsonValue.Double(200.0), model.value("offset"))
        assertEquals(JsonValue.Double(200.0), model.value("maxExtent"))
        assertEquals(JsonValue.Bool(true), model.value("atEnd"))
        assertEquals(JsonValue.Int(1), model.value("ends"))
        assertEquals(JsonValue.Double(200.0), model.value("endOffset"))
        assertEquals(JsonValue.Bool(true), model.value("endAtEnd"))
        assertEquals(JsonValue.Double(100.0), model.value("viewport"))
    }

    /** A2.4 (kt ui): scrolling back runs onScrolling with a negative delta, ending at the start. */
    @Test
    fun a2_4_kt_scrollingBackHasANegativeDelta() {
        val model = show(triggers)
        scrollBy(150f)
        assertEquals(JsonValue.Double(150.0), model.value("endOffset"))

        scrollBy(-1000f)

        assertEquals(JsonValue.Int(2), model.value("begins"))
        assertEquals(JsonValue.Double(150.0), model.value("beginOffset"))
        assertEquals(JsonValue.Double(0.0), model.value("offset"))
        assertTrue((model.value("delta")?.doubleValue ?: 0.0) < 0.0, "delta ${model.value("delta")}")
        assertEquals(JsonValue.Int(2), model.value("ends"))
        assertEquals(JsonValue.Double(0.0), model.value("endOffset"))
    }

    /** A2.4 (kt ui): a horizontal view runs the same triggers along its axis. */
    @Test
    fun a2_4_kt_aHorizontalViewRunsTheTriggers() {
        val model = show(triggers, horizontal = true)
        scrollBy(1000f, horizontal = true)

        assertEquals(JsonValue.Int(1), model.value("begins"))
        assertEquals(JsonValue.Double(200.0), model.value("maxExtent"))
        assertEquals(JsonValue.Bool(true), model.value("endAtEnd"))
    }

    /** A2.4 (kt ui): a drag runs one begin and one end, with the offset it reached. */
    @Test
    fun a2_4_kt_aDragRunsOneBeginAndOneEnd() {
        val model = show(triggers)
        compose.onNode(hasScrollAction()).performTouchInput { swipeUp() }
        compose.waitForIdle()

        assertEquals(JsonValue.Int(1), model.value("begins"))
        assertEquals(JsonValue.Int(1), model.value("ends"))
        val offset = model.value("endOffset")?.doubleValue ?: 0.0
        assertTrue(offset > 0.0, "endOffset $offset")
        assertEquals(model.value("offset"), model.value("endOffset"))
    }

    /** A2.4 (kt ui): the payload is in dp, Flutter's logical pixels, at any density (2 px per dp here). */
    @Test
    @Config(qualifiers = "xhdpi")
    fun a2_4_kt_offsetsAreInDp() {
        val model = show(triggers)
        scrollBy(1000f)

        assertEquals(JsonValue.Double(200.0), model.value("maxExtent"))
        assertEquals(JsonValue.Double(200.0), model.value("endOffset"))
        assertEquals(JsonValue.Double(100.0), model.value("viewport"))
    }

    /** A2.4 (kt ui): a scroll view with no scroll trigger fires nothing (its onTap is not a scroll trigger). */
    @Test
    fun a2_4_kt_aViewWithoutTriggersFiresNothing() {
        val model = show(mapOf("onTap" to count("begins")))
        scrollBy(1000f)

        assertEquals(null, model.value("begins"))
    }
}
