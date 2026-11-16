package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.sp
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
 * A8.5 as Flutter's `_buildSnackBar` (structure_builders.dart) draws the
 * SnackBar widget: a static Container (`backgroundColor` ?? #323232, corners
 * of 4, padding 16 x 12) around a Row of the content (white, 14) in an
 * Expanded and, when `actionLabel` is not empty, an 8 gap and the label
 * (#BB86FC, 14, w600) whose tap fires `onAction`. `duration` is never read.
 * SnackBar is known to the core and drawn here (standard() takes it in
 * K-caps); nodes are tagged with their ids. At 1 dp per pixel, drawn in
 * software for the colours.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SnackBarWidgetTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View

    /** The page from [nodes], its root in a 300 x 400 box, page state `actions` and `taps` at 0. */
    private fun show(vararg nodes: ComponentNode): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("SnackBar"))
        val state = listOf("actions", "taps").map { StateDefinition(it, StateScope.Page, JsonValue.Int(0)) }
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("SnackBar") { node, model, modifier -> SnackBarWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(300.dp, 400.dp)) { NodeView(nodes.first().id, model) }
        }
        compose.waitForIdle()
        return model
    }

    /** `setState(key, key + 1)`. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    /** A SnackBar with [props], its `onAction` counting itself in page state `actions`. */
    private fun snackBar(id: String, vararg props: Pair<String, Any?>) = ComponentNode(
        id, "SnackBar", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
        props.associate { (key, value) -> key to JsonValue.of(value) },
        actions = mapOf("onAction" to count("actions")),
    )

    /** A GestureDetector around [child] counting its taps in page state `taps`. */
    private fun counting(id: String, child: String) = ComponentNode(
        id, "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        children = listOf(child), actions = mapOf("onTap" to count("taps")),
    )

    private fun node(id: String, type: String, mode: ComponentNode.ChildMode, vararg children: String, props: Map<String, JsonValue> = emptyMap()) =
        ComponentNode(id, type, ComponentNode.Kind.Layout, mode, props, children.toList())

    private fun start(id: String, vararg children: String) =
        column(id, *children, props = mapOf("crossAxisAlignment" to JsonValue.String("start")))

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    private fun textBounds(text: String): DpRect = compose.onNodeWithText(text, useUnmergedTree = true).getUnclippedBoundsInRoot()

    /** How [text] is laid out. */
    private fun layout(text: String): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithText(text, useUnmergedTree = true).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single()
    }

    /** The style [text] is laid out in. */
    private fun style(text: String): TextStyle = layout(text).layoutInput.style

    private fun fired(model: OrcaPageModel, key: String = "actions"): Int {
        compose.waitForIdle()
        return model.store.value(key).doubleValue?.toInt() ?: -1
    }

    /**
     * A8.5: the content in white 14 fills the row 16 in from the start, the
     * label in #BB86FC 14 w600 ends 16 in from the end, 8 after the content;
     * 12 above and below, centred; on #323232 with corners of 4. Its own
     * `backgroundColor` replaces the grey; an empty `actionLabel` draws no
     * label and leaves the content the whole row.
     */
    @Test
    fun a8_5_theSnackBarDrawsItsContentAndLabelOnDarkGreyWithCornersOf4() {
        show(
            start("col", "plain", "teal"),
            snackBar("plain", "content" to "Message archived", "actionLabel" to "Undo"),
            snackBar("teal", "content" to "Saved", "actionLabel" to "", "backgroundColor" to "#00796B"),
        )

        val bar = bounds("plain")
        val content = textBounds("Message archived")
        val label = textBounds("Undo")
        assertEquals(0.dp, bar.left)
        assertEquals(300.dp, bar.right)
        assertEquals(16.dp, content.left)
        assertEquals(284.dp, label.right)
        assertEquals(content.right + 8.dp, label.left)
        assertEquals(maxOf(content.height, label.height) + 24.dp, bar.height)
        assertNear((bar.top + bar.bottom) / 2, (content.top + content.bottom) / 2)
        assertNear((bar.top + bar.bottom) / 2, (label.top + label.bottom) / 2)

        assertEquals(Color.White, style("Message archived").color)
        assertEquals(14.sp, style("Message archived").fontSize)
        assertEquals(Props.hex("#BB86FC"), style("Undo").color)
        assertEquals(14.sp, style("Undo").fontSize)
        assertEquals(FontWeight.W600, style("Undo").fontWeight)

        val teal = bounds("teal")
        val saved = textBounds("Saved")
        assertEquals(DpRect(16.dp, teal.top + 12.dp, 284.dp, teal.bottom - 12.dp), saved)

        val picture = picture()
        val top = bar.top.value.toInt()
        for ((x, y) in listOf(150 to top + 4, 2 to top + 2, 297 to bar.bottom.value.toInt() - 3, 8 to top + 30)) {
            assertPixel(Props.hex("#323232"), picture, x, y)
        }
        for ((x, y) in listOf(0 to top, 299 to top)) assertPixel(Color.White, picture, x, y)
        assertPixel(Props.hex("#00796B"), picture, 150, teal.top.value.toInt() + 4)
    }

    /** A8.5: a tap on the label fires `onAction`, once per tap; a tap on the content fires nothing. */
    @Test
    fun a8_5_aTapOnTheLabelFiresOnActionAndOnTheContentNothing() {
        val model = show(
            start("col", "bar"),
            snackBar("bar", "content" to "Message archived", "actionLabel" to "Undo"),
        )

        compose.onNodeWithText("Undo", useUnmergedTree = true).performTouchInput { click() }
        assertEquals(1, fired(model))
        compose.onNodeWithText("Message archived", useUnmergedTree = true).performTouchInput { click() }
        assertEquals(1, fired(model))
        compose.onNodeWithText("Undo", useUnmergedTree = true).performTouchInput { click() }
        assertEquals(2, fired(model))
    }

    /** A8.5: `duration` changes nothing: the bar with one is the bar without, and both stay long after it. */
    @Test
    fun a8_5_durationChangesNothing() {
        show(
            start("col", "timed", "plain"),
            snackBar("timed", "content" to "One", "actionLabel" to "Undo", "duration" to 100),
            snackBar("plain", "content" to "Two", "actionLabel" to "Redo"),
        )
        val timed = bounds("timed")
        val plain = bounds("plain")
        assertEquals(plain.right - plain.left, timed.right - timed.left)
        assertEquals(plain.height, timed.height)

        compose.mainClock.advanceTimeBy(10_000)
        assertEquals(timed, bounds("timed"))
        assertEquals(plain, bounds("plain"))
        assertEquals(1, compose.onAllNodes(hasText("One"), useUnmergedTree = true).fetchSemanticsNodes().size)
    }

    /**
     * A8.5: a DefaultTextStyle around the SnackBar lies under both its
     * texts, as Flutter's Text merges its own style over
     * `DefaultTextStyle.of(context)` and takes the DTS's maxLines and
     * overflow (widgets/text.dart:723-797): bold, italic and letter spacing
     * reach the content, italic and letter spacing the label (its own w600
     * wins), the colours and the size stay the SnackBar's, and the content
     * keeps to one line, ellipsized.
     */
    @Test
    fun a8_5_anEnclosingDefaultTextStyleLayersUnderTheSnackBarsTexts() {
        val long = "Message archived and moved to the folder named Old Things"
        show(
            start("col", "dts"),
            ComponentNode(
                "dts", "DefaultTextStyle", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                mapOf(
                    "style" to JsonValue.obj("fontWeight" to "bold", "fontStyle" to "italic", "letterSpacing" to 2),
                    "maxLines" to JsonValue.Int(1),
                    "overflow" to JsonValue.String("ellipsis"),
                ),
                listOf("bar"),
            ),
            snackBar("bar", "content" to long, "actionLabel" to "Undo"),
        )

        val content = style(long)
        assertEquals(Color.White, content.color)
        assertEquals(14.sp, content.fontSize)
        assertEquals(FontWeight.Bold, content.fontWeight)
        assertEquals(FontStyle.Italic, content.fontStyle)
        assertEquals(2.sp, content.letterSpacing)
        val label = style("Undo")
        assertEquals(Props.hex("#BB86FC"), label.color)
        assertEquals(14.sp, label.fontSize)
        assertEquals(FontWeight.W600, label.fontWeight)
        assertEquals(FontStyle.Italic, label.fontStyle)
        assertEquals(2.sp, label.letterSpacing)
        assertEquals(1, layout(long).lineCount)
        assertTrue(layout(long).isLineEllipsized(0))
    }

    /**
     * A8.5: the bar's decoration takes the touches on it (Flutter's
     * DecoratedBox is hit over its box): a tap on its padding does not reach
     * a GestureDetector below it in a Stack, a tap beside it does.
     */
    @Test
    fun a8_5_aTapOnTheBarsPaddingDoesNotReachASiblingBelowIt() {
        val model = show(
            node("stack", "Stack", ComponentNode.ChildMode.Multi, "below", "bar", props = mapOf("alignment" to JsonValue.String("topLeft"))),
            counting("below", "fill"),
            node("fill", "Container", ComponentNode.ChildMode.Single, props = mapOf("color" to JsonValue.String("#0000FF"))),
            snackBar("bar", "content" to "Message archived", "actionLabel" to "Undo"),
        )
        val bar = bounds("bar")
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, bar.bottom), bar)

        compose.onRoot().performTouchInput { click(Offset(150f, 4f)) }
        compose.onRoot().performTouchInput { click(Offset(4f, bar.bottom.value / 2)) }
        assertEquals(0, fired(model, "taps"))
        compose.onRoot().performTouchInput { click(Offset(150f, 300f)) }
        assertEquals(1, fired(model, "taps"))
        assertEquals(0, fired(model))
    }

    private fun picture(): Bitmap {
        compose.waitForIdle()
        return draw(view)
    }

    /** Within half a pixel: a Row centres a child a pixel shorter on a whole pixel. */
    private fun assertNear(expected: Dp, actual: Dp) {
        assertTrue(abs(expected.value - actual.value) <= 0.5f, "$actual is not $expected")
    }

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.05f },
            "($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }
}
