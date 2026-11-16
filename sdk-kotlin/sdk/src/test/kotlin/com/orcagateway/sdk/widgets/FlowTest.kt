package com.orcagateway.sdk.widgets

import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.sizedBox
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals

/**
 * Wrap, Offstage and SafeArea against Flutter's `RenderWrap`,
 * `RenderOffstage` and `SafeArea` (a Padding by the MediaQuery padding that
 * removes the sides it took), at 1 dp per pixel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class FlowTest {
    @get:Rule
    val compose = createComposeRule()

    /** The Compose root view of the page, where the window insets arrive. */
    private lateinit var host: View

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun assertRect(left: Int, top: Int, right: Int, bottom: Int, actual: DpRect) {
        assertEquals(DpRect(left.dp, top.dp, right.dp, bottom.dp), actual)
    }

    /**
     * A page drawn from its root inside a box of the given size, loose or
     * (with [tight]) forcing that size on the root, in [direction]. The
     * three types and group 3's IntrinsicHeight and IntrinsicWidth are not
     * advertised yet, so the core gets a registry that knows them; they, the
     * Rows, Columns, GestureDetectors and SizedBoxes are tagged with their
     * ids.
     */
    private fun flowPage(
        width: Dp,
        height: Dp,
        vararg nodes: ComponentNode,
        tight: Boolean = false,
        state: List<StateDefinition> = emptyList(),
        direction: LayoutDirection = LayoutDirection.Ltr,
    ): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + FLOW)
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Wrap") { node, model, modifier -> WrapWidget(node, model, modifier.testTag(node.id)) }
                register("Offstage") { node, model, modifier -> OffstageWidget(node, model, modifier.testTag(node.id)) }
                register("SafeArea") { node, model, modifier -> SafeAreaWidget(node, model, modifier.testTag(node.id)) }
                register("IntrinsicHeight") { node, model, modifier ->
                    IntrinsicHeightWidget(node, model, modifier.testTag(node.id))
                }
                register("IntrinsicWidth") { node, model, modifier ->
                    IntrinsicWidthWidget(node, model, modifier.testTag(node.id))
                }
                register("Row") { node, model, modifier ->
                    FlexWidget(node, model, modifier.testTag(node.id), vertical = false)
                }
                register("Column") { node, model, modifier ->
                    FlexWidget(node, model, modifier.testTag(node.id), vertical = true)
                }
                register("GestureDetector") { node, model, modifier ->
                    GestureDetectorWidget(node, model, modifier.testTag(node.id))
                }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            host = LocalView.current
            CompositionLocalProvider(LocalLayoutDirection provides direction) {
                Box(Modifier.size(width, height), propagateMinConstraints = tight) { NodeView(nodes.first().id, model) }
            }
        }
        return model
    }

    /** The device's system bars, in pixels (dp at mdpi), delivered to the page as the platform does. */
    private fun systemBars(left: Int, top: Int, right: Int, bottom: Int) {
        val insets = WindowInsetsCompat.Builder()
            .setInsets(WindowInsetsCompat.Type.systemBars(), Insets.of(left, top, right, bottom))
            .build()
        compose.runOnIdle { ViewCompat.dispatchApplyWindowInsets(host, insets) }
        compose.waitForIdle()
    }

    private fun single(id: String, type: String, child: String, vararg props: Pair<String, Any?>) =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            props.associate { (key, value) -> key to JsonValue.of(value) }, listOf(child),
        )

    private fun wrap(id: String, vararg children: String, props: Map<String, Any?> = emptyMap()) =
        ComponentNode(
            id, "Wrap", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi,
            props.mapValues { JsonValue.of(it.value) }, children.toList(),
        )

    /** `{type: state, key}`, the engine's `V.pageState`. */
    private fun pageState(key: String): JsonValue = JsonValue.obj("type" to "state", "key" to key)

    /** An Offstage whose `offstage` is the page state `hidden`. */
    private fun offstageBoundTo(id: String, child: String): ComponentNode =
        ComponentNode(
            id, "Offstage", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            mapOf("offstage" to pageState("hidden")), listOf(child), watches = listOf("hidden"),
        )

    private fun hidden(value: Boolean) = StateDefinition("hidden", StateScope.Page, JsonValue.Bool(value))

    private fun OrcaPageModel.setHidden(value: Boolean) {
        compose.runOnIdle { store.dispatch(mapOf("hidden" to JsonValue.Bool(value))) }
        compose.waitForIdle()
    }

    // A3.3 Wrap

    /** A3.3: Wrap moves a child that does not fit to the next line, with spacing and runSpacing. */
    @Test
    fun a3_3_wrapMovesChildrenToTheNextLineWithSpacingAndRunSpacing() {
        flowPage(
            100.dp, 200.dp,
            wrap("w", "a", "b", "c", props = mapOf("spacing" to 10, "runSpacing" to 5)),
            sizedBox("a", 40, 10), sizedBox("b", 40, 20), sizedBox("c", 40, 10),
        )
        assertRect(0, 0, 90, 35, bounds("w"))
        assertRect(0, 0, 40, 10, bounds("a"))
        assertRect(50, 0, 90, 20, bounds("b"))
        assertRect(0, 25, 40, 35, bounds("c"))
    }

    /**
     * A3.3: in a run shorter than the Wrap, `alignment` shares the free
     * space (spaceEvenly: 12 free, 3 at each gap and end) and
     * `crossAxisAlignment` centres each child in its run's height.
     */
    @Test
    fun a3_3_wrapSharesARunsFreeSpaceByAlignmentAndCentresByCrossAlignment() {
        flowPage(
            100.dp, 200.dp,
            wrap(
                "w", "a", "b", "c", "d",
                props = mapOf("spacing" to 5, "alignment" to "spaceEvenly", "crossAxisAlignment" to "center"),
            ),
            sizedBox("a", 82, 10), sizedBox("b", 20, 10), sizedBox("c", 20, 30), sizedBox("d", 20, 10),
        )
        assertRect(0, 0, 82, 40, bounds("w"))
        assertRect(0, 0, 82, 10, bounds("a"))
        assertRect(3, 20, 23, 30, bounds("b"))
        assertRect(31, 10, 51, 40, bounds("c"))
        assertRect(59, 20, 79, 30, bounds("d"))
    }

    /** A3.3: `direction` vertical fills a column top down, then starts the next one to its right. */
    @Test
    fun a3_3_aVerticalWrapFillsAColumnThenStartsTheNext() {
        flowPage(
            200.dp, 100.dp,
            wrap("w", "a", "b", "c", props = mapOf("direction" to "vertical", "spacing" to 10, "runSpacing" to 5)),
            sizedBox("a", 10, 40), sizedBox("b", 20, 40), sizedBox("c", 10, 40),
        )
        assertRect(0, 0, 35, 90, bounds("w"))
        assertRect(0, 0, 10, 40, bounds("a"))
        assertRect(0, 50, 20, 90, bounds("b"))
        assertRect(25, 0, 35, 40, bounds("c"))
    }

    /** A3.3: a parent forcing its size makes the Wrap that size; `alignment` center centres the run. */
    @Test
    fun a3_3_aParentForcingItsSizeWidensTheWrapAndCentresTheRun() {
        flowPage(
            100.dp, 50.dp,
            wrap("w", "a", props = mapOf("alignment" to "center")),
            sizedBox("a", 40, 10),
            tight = true,
        )
        assertRect(0, 0, 100, 50, bounds("w"))
        assertRect(30, 0, 70, 10, bounds("a"))
    }

    /** A3.3: with no width limit (a horizontal scroll view) the children stay on one line. */
    @Test
    fun a3_3_aWrapWithNoWidthLimitKeepsOneLine() {
        flowPage(
            100.dp, 50.dp,
            single("s", "SingleChildScrollView", "w", "scrollDirection" to "horizontal"),
            wrap("w", "a", "b", props = mapOf("spacing" to 10)),
            sizedBox("a", 80, 10), sizedBox("b", 80, 10),
        )
        assertRect(0, 0, 170, 10, bounds("w"))
        assertRect(90, 0, 170, 10, bounds("b"))
    }

    /**
     * A3.3: right to left (the ambient direction; the builder sets no
     * textDirection) a horizontal Wrap is the mirror image: its runs start
     * at the right edge.
     */
    @Test
    fun a3_3_aRightToLeftWrapStartsItsRunsAtTheRight() {
        flowPage(
            100.dp, 200.dp,
            wrap("w", "a", "b", "c", props = mapOf("spacing" to 10, "runSpacing" to 5)),
            sizedBox("a", 40, 10), sizedBox("b", 40, 20), sizedBox("c", 40, 10),
            tight = true,
            direction = LayoutDirection.Rtl,
        )
        assertRect(0, 0, 100, 200, bounds("w"))
        assertRect(60, 0, 100, 10, bounds("a"))
        assertRect(10, 0, 50, 20, bounds("b"))
        assertRect(60, 25, 100, 35, bounds("c"))
    }

    /** A3.3: right to left a vertical Wrap stacks its runs from the right edge, each child at its run's right. */
    @Test
    fun a3_3_aRightToLeftVerticalWrapStacksItsRunsFromTheRight() {
        flowPage(
            200.dp, 100.dp,
            wrap("w", "a", "b", "c", props = mapOf("direction" to "vertical", "spacing" to 10, "runSpacing" to 5)),
            sizedBox("a", 10, 40), sizedBox("b", 20, 40), sizedBox("c", 10, 40),
            tight = true,
            direction = LayoutDirection.Rtl,
        )
        assertRect(190, 0, 200, 40, bounds("a"))
        assertRect(180, 50, 200, 90, bounds("b"))
        assertRect(165, 0, 175, 40, bounds("c"))
    }

    /**
     * A3.3: a Wrap's intrinsic height at a width is the height of its runs
     * there (RenderWrap's dry layout), so IntrinsicHeight around a stretched
     * Row holding a one-line Wrap of three boxes and a bar makes the bar
     * one box tall, not three.
     */
    @Test
    fun a3_3_intrinsicHeightAroundAOneLineWrapIsOneBoxTall() {
        flowPage(
            200.dp, 200.dp,
            single("ih", "IntrinsicHeight", "r"),
            row("r", "w", "bar", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            wrap("w", "a", "b", "c"),
            sizedBox("a", 20, 10), sizedBox("b", 20, 10), sizedBox("c", 20, 10),
            sizedBox("bar", width = 10),
        )
        assertRect(0, 0, 60, 10, bounds("w"))
        assertEquals(10.dp, bounds("bar").height)
    }

    /**
     * A3.3: a Wrap's max intrinsic width is its children's summed, without
     * the spacing (RenderWrap's), so IntrinsicWidth around three 20 wide
     * boxes spaced 5 gives the Wrap 60, and the third box wraps.
     */
    @Test
    fun a3_3_aWrapsMaxIntrinsicWidthSumsItsChildrenWithoutSpacing() {
        flowPage(
            200.dp, 200.dp,
            single("iw", "IntrinsicWidth", "w"),
            wrap("w", "a", "b", "c", props = mapOf("spacing" to 5)),
            sizedBox("a", 20, 10), sizedBox("b", 20, 10), sizedBox("c", 20, 10),
        )
        assertRect(0, 0, 60, 20, bounds("w"))
        assertRect(25, 0, 45, 10, bounds("b"))
        assertRect(0, 10, 20, 20, bounds("c"))
    }

    // A3.6 Offstage

    /** A3.6: Offstage, offstage by default, takes no space in a Column and its child is not on screen. */
    @Test
    fun a3_6_offstageByDefaultTakesNoSpaceInAColumn() {
        flowPage(
            200.dp, 200.dp,
            column("col", "o", "b"),
            single("o", "Offstage", "a"),
            sizedBox("a", 50, 50),
            sizedBox("b", 10, 10),
        )
        assertEquals(0.dp, bounds("o").width)
        assertEquals(0.dp, bounds("o").height)
        assertEquals(0.dp, bounds("b").top)
        compose.onNodeWithTag("a").assertIsNotDisplayed()
    }

    /** A3.6: `offstage` false is its child, as a plain pass-through. */
    @Test
    fun a3_6_offstageFalseIsItsChild() {
        flowPage(200.dp, 200.dp, single("o", "Offstage", "a", "offstage" to false), sizedBox("a", 40, 30))
        assertRect(0, 0, 40, 30, bounds("o"))
        assertRect(0, 0, 40, 30, bounds("a"))
    }

    /**
     * A3.6: an offstage child takes no tap where it would be; once
     * `offstage` turns false the same tap reaches it.
     */
    @Test
    fun a3_6_anOffstageChildTakesNoTaps() {
        val taps = StateDefinition("taps", StateScope.Page, JsonValue.Int(0))
        val tap = Action.SetState(key = "taps", value = JsonValue.obj("type" to "static", "value" to 1))
        val model = flowPage(
            200.dp, 200.dp,
            offstageBoundTo("o", "g"),
            ComponentNode(
                "g", "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                children = listOf("a"), actions = mapOf("onTap" to tap),
            ),
            sizedBox("a", 100, 100),
            state = listOf(hidden(true), taps),
        )

        compose.onRoot().performTouchInput { click(Offset(50f, 50f)) }
        compose.runOnIdle { assertEquals(JsonValue.Int(0), model.store.value("taps")) }
        compose.onNodeWithTag("g").assertIsNotDisplayed()

        model.setHidden(false)
        compose.onNodeWithTag("g").assertIsDisplayed()
        assertRect(0, 0, 100, 100, bounds("o"))
        compose.onRoot().performTouchInput { click(Offset(50f, 50f)) }
        compose.runOnIdle { assertEquals(JsonValue.Int(1), model.store.value("taps")) }
    }

    /**
     * A3.6: the child stays alive while offstage: text typed into a field
     * (kept by the field, not the page) is still there after the page
     * state hides it and shows it again.
     */
    @Test
    fun a3_6_aChildKeepsItsStateWhileOffstage() {
        val model = flowPage(
            300.dp, 100.dp,
            offstageBoundTo("o", "f"),
            leaf("f", "TextField"),
            state = listOf(hidden(false)),
        )
        compose.onNode(hasSetTextAction()).performTextInput("kept")

        model.setHidden(true)
        assertEquals(0.dp, bounds("o").width)
        assertEquals(0.dp, bounds("o").height)
        compose.onNode(hasSetTextAction()).assertIsNotDisplayed()

        model.setHidden(false)
        compose.onNode(hasSetTextAction()).assertIsDisplayed()
        val shown = compose.onNode(hasSetTextAction()).fetchSemanticsNode().config[SemanticsProperties.EditableText]
        assertEquals("kept", shown.text)
    }

    // A3.6 SafeArea

    /** A3.6: SafeArea pads each edge by the device inset that reaches it (all four by default). */
    @Test
    fun a3_6_safeAreaPadsEveryEdgeByTheDeviceInsets() {
        flowPage(300.dp, 400.dp, single("s", "SafeArea", "c"), sizedBox("c"), tight = true)
        systemBars(left = 10, top = 24, right = 16, bottom = 48)
        assertRect(0, 0, 300, 400, bounds("s"))
        assertRect(10, 24, 284, 352, bounds("c"))
    }

    /** A3.6: an edge flagged false is not padded: the content reaches it. */
    @Test
    fun a3_6_anEdgeFlaggedFalseIsNotPadded() {
        flowPage(
            300.dp, 400.dp,
            single("s", "SafeArea", "c", "top" to false, "right" to false),
            sizedBox("c"),
            tight = true,
        )
        systemBars(left = 10, top = 24, right = 16, bottom = 48)
        assertRect(10, 0, 300, 352, bounds("c"))
    }

    /**
     * A3.6: a SafeArea inside another adds only the edges the outer one
     * left (Flutter's `MediaQuery.removePadding` of the sides it took).
     */
    @Test
    fun a3_6_aNestedSafeAreaAddsOnlyTheEdgesLeftToIt() {
        flowPage(
            300.dp, 400.dp,
            single("outer", "SafeArea", "inner", "top" to false),
            single("inner", "SafeArea", "c"),
            sizedBox("c"),
            tight = true,
        )
        systemBars(left = 10, top = 24, right = 16, bottom = 48)
        assertRect(10, 0, 284, 352, bounds("inner"))
        assertRect(10, 24, 284, 352, bounds("c"))
    }

    /**
     * A3.6: in a Scaffold's body, which already keeps clear of the system
     * bars, SafeArea adds nothing more: a Column stretched in it fills
     * exactly the area inside the bars, as in Flutter (where the body runs
     * under the bars and the SafeArea pads it once).
     */
    @Test
    fun a3_6_aSafeAreaInAScaffoldBodyDoesNotPadTwice() {
        flowPage(
            300.dp, 400.dp,
            ComponentNode(
                "page", "Scaffold", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
                mapOf("body" to JsonValue.String("s")), listOf("s"),
            ),
            single("s", "SafeArea", "col"),
            column("col", "b", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            sizedBox("b", height = 10),
            tight = true,
        )
        systemBars(left = 10, top = 24, right = 16, bottom = 48)
        assertRect(10, 24, 284, 352, bounds("col"))
    }

    private companion object {
        val FLOW = setOf("Wrap", "Offstage", "SafeArea", "IntrinsicHeight", "IntrinsicWidth")
    }
}
