package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
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
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
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
 * A8.2 and A8.1 (in place) as Flutter draws them: BottomSheet is the
 * builder's Container (structure_builders.dart `_buildBottomSheet`), the
 * Scaffold's `bottomSheet` slot is Material's persistent sheet (MUI
 * scaffold.dart `_ScaffoldLayout`, bottom_sheet.dart, the FAB placed by
 * floating_action_button_location.dart `FabFloatOffsetY`), and a Dialog
 * draws Flutter's `SizedBox.shrink()` where it stands. BottomSheet and
 * Dialog are known to the core and drawn here (standard() takes them in
 * K-caps); nodes are tagged with their ids. At 1 dp per pixel, drawn in
 * software for the colours.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1000dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class BottomSheetTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View

    private val blue = Props.hex("#0000FF")
    private val red = Props.hex("#FF0000")
    private val black = Props.hex("#000000")

    /** Flutter's `ThemeData()` surfaceContainerLow, the M3 sheet's colour (color_scheme_defaults.g.dart). */
    private val sheetSurface = Props.hex("#F7F2FA")

    /** The page from [nodes], its root in a [width] x [height] box, page state `taps` at 0. */
    private fun show(width: Dp, height: Dp, vararg nodes: ComponentNode): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("BottomSheet", "Dialog"))
        val standard = WidgetBuilders.standard()
        val state = listOf(StateDefinition("taps", StateScope.Page, JsonValue.Int(0)))
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("BottomSheet") { node, model, modifier -> BottomSheetWidget(node, model, modifier.testTag(node.id)) }
                register("Dialog") { node, _, modifier -> DialogWidget(modifier.testTag(node.id)) }
                for (type in listOf("Container", "SizedBox", "FloatingActionButton", "GestureDetector")) {
                    val drawn = requireNotNull(standard[type])
                    register(type) { node, model, modifier -> drawn(node, model, modifier.testTag(node.id)) }
                }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
        }
        compose.waitForIdle()
        return model
    }

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    private fun container(id: String, vararg children: String, props: Map<String, JsonValue> = emptyMap()) =
        ComponentNode(id, "Container", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props, children.toList())

    private fun bottomSheet(id: String, child: String?, props: Map<String, JsonValue> = emptyMap()) =
        ComponentNode(id, "BottomSheet", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props, listOfNotNull(child))

    private fun dialog(id: String, child: String, props: Map<String, JsonValue> = emptyMap()) =
        ComponentNode(id, "Dialog", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props, listOf(child))

    /** A Scaffold, its slots props holding the ids of nodes listed as its children. */
    private fun scaffold(id: String, slots: Map<String, String>) = ComponentNode(
        id, "Scaffold", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
        slots.mapValues { JsonValue.String(it.value) }, slots.values.toList(),
    )

    /** A FloatingActionButton around [child], with no handler. */
    private fun fab(id: String, child: String) =
        ComponentNode(id, "FloatingActionButton", ComponentNode.Kind.Button, ComponentNode.ChildMode.Single, children = listOf(child))

    /** A GestureDetector around [child] counting its taps in page state `taps`. */
    private fun counting(id: String, child: String) = ComponentNode(
        id, "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        children = listOf(child),
        actions = mapOf(
            "onTap" to Action.SetState(
                key = "taps",
                value = JsonValue.parse(
                    """{"type":"transform","input":{"type":"state","key":"taps","scope":"page"},""" +
                        """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
                ),
            ),
        ),
    )

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    private fun taps(model: OrcaPageModel): Int {
        compose.waitForIdle()
        return model.store.value("taps").doubleValue?.toInt() ?: -1
    }

    private fun picture(): Bitmap {
        compose.waitForIdle()
        return draw(view)
    }

    /**
     * A8.2: BottomSheet is Flutter's Container: padding 16 around its child
     * (an empty one without a child), `backgroundColor` (white when absent)
     * behind, its top corners `borderRadius` (16 when absent), its bottom
     * corners square; drawn inline where it stands.
     */
    @Test
    fun a8_2_aBottomSheetIsAContainerPadded16OnWhiteWithTopCornersOf16() {
        show(
            300.dp, 400.dp,
            container("root", "col", props = props("color" to "#000000")),
            column("col", "plain", "red", "empty", props = props("crossAxisAlignment" to "start")),
            bottomSheet("plain", "c1"),
            bottomSheet("red", "c2", props("backgroundColor" to "#FF0000", "borderRadius" to 0)),
            bottomSheet("empty", null),
            sizedBox("c1", 100, 40),
            sizedBox("c2", 100, 40),
        )

        assertEquals(DpRect(0.dp, 0.dp, 132.dp, 72.dp), bounds("plain"))
        assertEquals(DpRect(16.dp, 16.dp, 116.dp, 56.dp), bounds("c1"))
        assertEquals(DpRect(0.dp, 72.dp, 132.dp, 144.dp), bounds("red"))
        assertEquals(DpRect(16.dp, 88.dp, 116.dp, 128.dp), bounds("c2"))
        assertEquals(DpRect(0.dp, 144.dp, 32.dp, 176.dp), bounds("empty"))

        val picture = picture()
        // White, the top corners cut at 16, the bottom ones square.
        for ((x, y) in listOf(66 to 4, 4 to 36, 1 to 70, 130 to 70)) assertPixel(Color.White, picture, x, y)
        for ((x, y) in listOf(1 to 1, 130 to 1)) assertPixel(black, picture, x, y)
        // Its own colour, radius 0: square at the top too.
        for ((x, y) in listOf(1 to 73, 130 to 73, 66 to 140)) assertPixel(red, picture, x, y)
    }

    /**
     * A8.2: the sheet's decoration takes the touches on it (Flutter's
     * DecoratedBox is hit over its box): a tap on its padding does not reach
     * a GestureDetector below it in a Stack, a tap beside it does.
     */
    @Test
    fun a8_2_aTapOnTheSheetDoesNotReachASiblingBelowIt() {
        val model = show(
            300.dp, 400.dp,
            ComponentNode(
                "stack", "Stack", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi,
                props("alignment" to "topLeft"), listOf("below", "sheet"),
            ),
            counting("below", "fill"),
            container("fill", props = props("color" to "#0000FF")),
            bottomSheet("sheet", "content"),
            sizedBox("content", 100, 40),
        )
        assertEquals(DpRect(0.dp, 0.dp, 132.dp, 72.dp), bounds("sheet"))

        compose.onRoot().performTouchInput { click(Offset(66f, 8f)) }
        compose.onRoot().performTouchInput { click(Offset(8f, 36f)) }
        assertEquals(0, taps(model))
        compose.onRoot().performTouchInput { click(Offset(200f, 36f)) }
        assertEquals(1, taps(model))
    }

    /**
     * A8.2: the Scaffold's `bottomSheet` slot lays the sheet at the bottom
     * over the body, centred, as wide as it is; the body keeps the whole
     * height (it is not shrunk), shows around the sheet and through its cut
     * corners, and gets no touch on the sheet (Material takes it) but every
     * touch beside it.
     */
    @Test
    fun a8_2_theSlotLaysTheSheetOverTheBodysBottomAndTheBodyKeepsItsSize() {
        val model = show(
            300.dp, 400.dp,
            scaffold("page", mapOf("body" to "body", "bottomSheet" to "sheet")),
            counting("body", "fill"),
            container("fill", props = props("color" to "#0000FF")),
            bottomSheet("sheet", "content"),
            sizedBox("content", 100, 40),
        )

        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 400.dp), bounds("body"))
        assertEquals(DpRect(84.dp, 328.dp, 216.dp, 400.dp), bounds("sheet"))

        val picture = picture()
        for ((x, y) in listOf(150 to 200, 80 to 390, 220 to 390, 85 to 329, 214 to 329)) assertPixel(blue, picture, x, y)
        for ((x, y) in listOf(150 to 332, 88 to 398)) assertPixel(Color.White, picture, x, y)

        compose.onRoot().performTouchInput { click(Offset(150f, 364f)) }
        assertEquals(0, taps(model))
        compose.onRoot().performTouchInput { click(Offset(150f, 100f)) }
        assertEquals(1, taps(model))
    }

    /**
     * A8.2: the slot's surface is Material 3's sheet, Flutter's
     * surfaceContainerLow with top corners of 28 and no shadow, at most 640
     * wide and centred at the bottom of a wider Scaffold.
     */
    @Test
    fun a8_2_theSlotSurfaceIsTheM3SheetAtMost640WideAndCentred() {
        show(
            900.dp, 400.dp,
            scaffold("page", mapOf("body" to "fill", "bottomSheet" to "slot")),
            container("fill", props = props("color" to "#0000FF")),
            container("slot", props = props("height" to 60)),
        )

        assertEquals(DpRect(130.dp, 340.dp, 770.dp, 400.dp), bounds("slot"))

        val picture = picture()
        for ((x, y) in listOf(450 to 370, 140 to 360, 131 to 398, 768 to 398)) assertPixel(sheetSurface, picture, x, y, 0.01f)
        // The rounded top corners, beside it and just above it: the body.
        for ((x, y) in listOf(131 to 341, 768 to 341, 129 to 370, 771 to 370, 450 to 338)) assertPixel(blue, picture, x, y)
    }

    /**
     * A8.2: with a bottom bar the sheet sits on the bar, the body keeps the
     * height it has without a sheet, and the floating button rises until
     * its centre is on the sheet's top edge (FabFloatOffsetY: the higher of
     * 16 above the bar and half its height over the sheet).
     */
    @Test
    fun a8_2_theSheetSitsOnTheBottomBarAndTheFabRisesToItsTopEdge() {
        show(
            300.dp, 400.dp,
            scaffold(
                "page",
                mapOf("body" to "fill", "bottomNavigationBar" to "bar", "floatingActionButton" to "f", "bottomSheet" to "sheet"),
            ),
            container("fill", props = props("color" to "#0000FF")),
            container("bar", props = props("height" to 50, "color" to "#FF0000")),
            fab("f", "icon"),
            sizedBox("icon", 24, 24),
            bottomSheet("sheet", "content"),
            sizedBox("content", 100, 100),
        )

        assertEquals(DpRect(0.dp, 350.dp, 300.dp, 400.dp), bounds("bar"))
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 350.dp), bounds("fill"))
        assertEquals(DpRect(84.dp, 218.dp, 216.dp, 350.dp), bounds("sheet"))
        assertEquals(DpRect(228.dp, 190.dp, 284.dp, 246.dp), bounds("f"))
    }

    /**
     * A8.2: without bars the sheet reaches the Scaffold's bottom edge, and
     * a sheet too low to reach the floating button leaves it where it was,
     * 16 in from the bottom end.
     */
    @Test
    fun a8_2_aLowSheetLeavesTheFabWhereItWas() {
        show(
            300.dp, 400.dp,
            scaffold("page", mapOf("body" to "fill", "floatingActionButton" to "f", "bottomSheet" to "sheet")),
            container("fill", props = props("color" to "#0000FF")),
            fab("f", "icon"),
            sizedBox("icon", 24, 24),
            bottomSheet("sheet", null),
        )

        assertEquals(DpRect(134.dp, 368.dp, 166.dp, 400.dp), bounds("sheet"))
        assertEquals(DpRect(228.dp, 328.dp, 284.dp, 384.dp), bounds("f"))
    }

    /**
     * A8.1 (in place): a Dialog draws Flutter's `SizedBox.shrink()` where it
     * stands: an empty box that still counts as a child of its Column (it
     * takes its share of spaceEvenly's gaps), and its children are not drawn
     * there, whatever its props say.
     */
    @Test
    fun a8_1_aDialogDrawsAnEmptyBoxInPlaceAndNotItsChildren() {
        show(
            300.dp, 400.dp,
            column("col", "a", "d", "b", props = props("mainAxisAlignment" to "spaceEvenly")),
            sizedBox("a", 40, 40),
            dialog("d", "inside", props("dismissible" to false, "backgroundColor" to "#FFFBFE", "borderRadius" to 28)),
            text("inside", "Hidden"),
            sizedBox("b", 40, 40),
        )

        // 320 free in four gaps of 80: three children, the Dialog one of them,
        // centred across the Column's 40.
        assertEquals(80.dp, bounds("a").top)
        assertEquals(DpRect(20.dp, 200.dp, 20.dp, 200.dp), bounds("d"))
        assertEquals(280.dp, bounds("b").top)
        assertEquals(0, compose.onAllNodes(hasText("Hidden"), useUnmergedTree = true).fetchSemanticsNodes().size)
    }

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int, tolerance: Float = 0.05f) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < tolerance },
            "($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }
}
