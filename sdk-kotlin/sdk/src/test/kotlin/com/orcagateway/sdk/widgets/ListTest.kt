package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performSemanticsAction
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
import com.orcagateway.sdk.support.column
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
 * A5.1, A5.2 and A5.3 on Android: ListView and GridView against Flutter's
 * builders (structure_builders.dart:161-227), `SliverList` (children
 * forced to the cross extent), `SliverFixedExtentList` (itemExtent),
 * `SliverPadding`, a reversed axis and `SliverGridRegularTileLayout`, at
 * 1 dp per pixel. Rows count themselves into page key `built` on init, as
 * Flutter's OrcaLifecycleWrapper does when a row's element is built.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class ListTest {
    @get:Rule
    val compose = createComposeRule()

    /** `setState(key, key + 1)`. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    /** `setState(key, event[field])`, one per pair. */
    private fun write(vararg keys: Pair<String, String>): Action = Action.ActionGroup(
        mode = "sequential",
        actions = keys.map { (key, field) ->
            Action.SetState(key = key, value = JsonValue.parse("""{"type":"event","key":"$field"}"""))
        },
    )

    private val triggers: Map<String, Action> = mapOf(
        "onScrollBegin" to count("begins"),
        "onScrolling" to write("offset" to "offset", "maxExtent" to "maxExtent"),
        "onScrollEnd" to Action.ActionGroup(
            mode = "sequential",
            actions = listOf(
                count("ends"),
                write("endOffset" to "offset", "endAtEnd" to "atEnd", "viewport" to "viewportDimension"),
            ),
        ),
    )

    private val built = listOf(StateDefinition("built", StateScope.Page, JsonValue.Int(0)))

    /**
     * A page drawn from its root inside a loose box of the given size, with
     * ListView and GridView known to the core (they are advertised in a
     * later group) and drawn here; they, SizedBoxes and Columns are tagged
     * with their ids.
     */
    private fun listPage(width: Dp, height: Dp, vararg nodes: ComponentNode, state: List<StateDefinition> = emptyList()): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("ListView", "GridView"))
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("ListView") { node, model, modifier -> ListViewWidget(node, model, modifier.testTag(node.id)) }
                register("GridView") { node, model, modifier -> GridViewWidget(node, model, modifier.testTag(node.id)) }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
                register("Column") { node, model, modifier ->
                    FlexWidget(node, model, modifier.testTag(node.id), vertical = true)
                }
            }
        }
        compose.setContent {
            Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
        }
        compose.waitForIdle()
        return model
    }

    private fun scrollView(
        type: String,
        id: String,
        children: List<String>,
        props: Map<String, Any?>,
        actions: Map<String, Action>?,
    ) = ComponentNode(
        id, type, ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi,
        props.mapValues { JsonValue.of(it.value) }, children, actions = actions,
    )

    private fun list(id: String, children: List<String>, props: Map<String, Any?> = emptyMap(), actions: Map<String, Action>? = null) =
        scrollView("ListView", id, children, props, actions)

    private fun grid(id: String, children: List<String>, props: Map<String, Any?> = emptyMap(), actions: Map<String, Action>? = null) =
        scrollView("GridView", id, children, props, actions)

    /** A SizedBox [id] that counts itself into `built` when it is built. */
    private fun counted(id: String, width: Int? = null, height: Int? = null): ComponentNode =
        sizedBox(id, width, height).copy(actions = mapOf("onInit" to count("built")))

    private fun ids(prefix: String, count: Int): List<String> = (0 until count).map { "$prefix$it" }

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun assertRect(left: Int, top: Int, right: Int, bottom: Int, tag: String) {
        assertEquals(DpRect(left.dp, top.dp, right.dp, bottom.dp), bounds(tag), tag)
    }

    private fun OrcaPageModel.value(key: String): JsonValue? = store.state.page[key]

    private fun OrcaPageModel.builtCount(): Int = value("built")?.doubleValue?.toInt() ?: -1

    /** Scroll the only scroll view down by [by] dp (the semantics action, animated like a user's). */
    private fun scrollBy(by: Float) {
        compose.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, by) }
        compose.waitForIdle()
    }

    /**
     * A5.1 (kt ui): of 1,000 rows 40 high in a view 400 high only those on
     * screen and the next few are built (Flutter: the viewport and its
     * 250 px cache, 17 rows); after a jump to row 500 the rows there are
     * built and the first ones are gone.
     */
    @Test
    fun a5_1_kt_aListOf1000RowsBuildsOnlyTheRowsNearTheViewport() {
        val rows = ids("r", 1000)
        val model = listPage(
            300.dp, 400.dp,
            list("l", rows),
            *rows.map { counted(it, height = 40) }.toTypedArray(),
            state = built,
        )
        val first = model.builtCount()
        assertTrue(first in 10..17, "built $first")
        compose.onNodeWithTag("r9").assertIsDisplayed()
        compose.onNodeWithTag("r999").assertDoesNotExist()

        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(500)
        compose.waitForIdle()

        compose.onNodeWithTag("r500").assertIsDisplayed()
        compose.onNodeWithTag("r0").assertDoesNotExist()
        val after = model.builtCount()
        assertTrue(after in first + 10..first + 20, "built $after after $first")
    }

    /**
     * A5.1 (kt ui): the list runs onScrollBegin, onScrolling and onScrollEnd
     * with Flutter's metrics: 100 rows of 40 in a view of 400 scroll 3,600.
     */
    @Test
    fun a5_1_kt_scrollingTheListRunsTheScrollTriggers() {
        val rows = ids("r", 100)
        val model = listPage(300.dp, 400.dp, list("l", rows, actions = triggers), *rows.map { sizedBox(it, height = 40) }.toTypedArray())

        scrollBy(1000f)

        assertEquals(JsonValue.Int(1), model.value("begins"))
        assertEquals(JsonValue.Int(1), model.value("ends"))
        assertEquals(JsonValue.Double(1000.0), model.value("endOffset"))
        assertEquals(JsonValue.Double(3600.0), model.value("maxExtent"))
        assertEquals(JsonValue.Double(400.0), model.value("viewport"))
        assertEquals(JsonValue.Bool(false), model.value("endAtEnd"))

        scrollBy(10_000f)

        assertEquals(JsonValue.Int(2), model.value("ends"))
        assertEquals(JsonValue.Double(3600.0), model.value("endOffset"))
        assertEquals(JsonValue.Bool(true), model.value("endAtEnd"))
    }

    /** A5.1 (kt ui): a list fills its parent, as Flutter's viewport does, and its rows fill its width. */
    @Test
    fun a5_1_kt_aListFillsItsParentAndItsRowsItsWidth() {
        listPage(300.dp, 400.dp, list("l", listOf("a", "b")), sizedBox("a", 40, 40), sizedBox("b", height = 40))
        assertRect(0, 0, 300, 400, "l")
        assertRect(0, 0, 300, 40, "a")
        assertRect(0, 40, 300, 80, "b")
    }

    /** A5.2 (kt ui): a horizontal list runs across, each child as tall as the list. */
    @Test
    fun a5_2_kt_aHorizontalListRunsAcrossAndFillsItsHeight() {
        listPage(
            300.dp, 100.dp,
            list("l", listOf("a", "b", "c"), mapOf("scrollDirection" to "horizontal")),
            sizedBox("a", width = 50), sizedBox("b", width = 60), sizedBox("c", width = 70),
        )
        assertRect(0, 0, 300, 100, "l")
        assertRect(0, 0, 50, 100, "a")
        assertRect(50, 0, 110, 100, "b")
        assertRect(110, 0, 180, 100, "c")
    }

    /** A5.2 (kt ui): padding is inside the scroll extent: around the first row at the start, after the last at the end. */
    @Test
    fun a5_2_kt_paddingIsInsideTheScrollExtent() {
        val rows = ids("r", 20)
        listPage(
            300.dp, 400.dp,
            list("l", rows, mapOf("padding" to mapOf("top" to 10, "left" to 20, "bottom" to 30, "right" to 5))),
            *rows.map { sizedBox(it, height = 40) }.toTypedArray(),
        )
        assertRect(20, 10, 295, 50, "r0")
        assertRect(20, 50, 295, 90, "r1")

        scrollBy(10_000f)

        assertRect(20, 330, 295, 370, "r19")
    }

    /** A5.2 (kt ui): reverse puts the first child at the far end, offset 0 there; the padding stays on its side. */
    @Test
    fun a5_2_kt_reverseStartsAtTheFarEnd() {
        listPage(
            300.dp, 400.dp,
            list("l", listOf("a", "b", "c"), mapOf("reverse" to true, "padding" to mapOf("bottom" to 10))),
            sizedBox("a", height = 40), sizedBox("b", height = 40), sizedBox("c", height = 40),
        )
        assertRect(0, 350, 300, 390, "a")
        assertRect(0, 310, 300, 350, "b")
        assertRect(0, 270, 300, 310, "c")
    }

    /** A5.2 (kt ui): a reversed horizontal list starts at the right. */
    @Test
    fun a5_2_kt_aReversedHorizontalListStartsAtTheRight() {
        listPage(
            300.dp, 100.dp,
            list("l", listOf("a", "b"), mapOf("scrollDirection" to "horizontal", "reverse" to true)),
            sizedBox("a", width = 50), sizedBox("b", width = 60),
        )
        assertRect(250, 0, 300, 100, "a")
        assertRect(190, 0, 250, 100, "b")
    }

    /** A5.2 (kt ui): itemExtent forces every child's main extent, whatever it asks for. */
    @Test
    fun a5_2_kt_itemExtentForcesEachChildsLength() {
        listPage(
            300.dp, 400.dp,
            list("l", listOf("a", "b"), mapOf("itemExtent" to 30)),
            sizedBox("a", height = 50), sizedBox("b", height = 10),
        )
        assertRect(0, 0, 300, 30, "a")
        assertRect(0, 30, 300, 60, "b")
    }

    /** A5.2 (kt ui): shrinkWrap sizes the list to its content on the scroll axis, as Flutter's ShrinkWrappingViewport. */
    @Test
    fun a5_2_kt_shrinkWrapHugsItsContent() {
        listPage(
            300.dp, 400.dp,
            list("l", listOf("a", "b", "c"), mapOf("shrinkWrap" to true)),
            sizedBox("a", height = 40), sizedBox("b", height = 40), sizedBox("c", height = 40),
        )
        assertRect(0, 0, 300, 120, "l")
        assertRect(0, 80, 300, 120, "c")
    }

    /** A5.2 (kt ui): in a Column (no height limit) the list lays out every child instead of throwing as Flutter's does. */
    @Test
    fun a5_2_kt_aListWithNoLimitLaysOutEveryChild() {
        val rows = ids("r", 30)
        listPage(
            300.dp, 400.dp,
            column("root", "l", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            list("l", rows, mapOf("padding" to mapOf("top" to 10))),
            *rows.map { sizedBox(it, height = 40) }.toTypedArray(),
        )
        assertRect(0, 0, 300, 1210, "l")
        assertRect(0, 10, 300, 50, "r0")
        assertRect(0, 1170, 300, 1210, "r29")
    }

    /**
     * A5.3 (kt ui): two columns 310 wide with crossAxisSpacing 10,
     * mainAxisSpacing 4 and childAspectRatio 1.5 are cells 150 x 100, each
     * child forced to its cell.
     */
    @Test
    fun a5_3_kt_aGridOfTwoColumnsWithSpacingAndRatio() {
        listPage(
            310.dp, 400.dp,
            grid(
                "g", ids("c", 4),
                mapOf("crossAxisCount" to 2, "mainAxisSpacing" to 4, "crossAxisSpacing" to 10, "childAspectRatio" to 1.5),
            ),
            sizedBox("c0", 10, 10), sizedBox("c1"), sizedBox("c2"), sizedBox("c3"),
        )
        assertRect(0, 0, 310, 400, "g")
        assertRect(0, 0, 150, 100, "c0")
        assertRect(160, 0, 310, 100, "c1")
        assertRect(0, 104, 150, 204, "c2")
        assertRect(160, 104, 310, 204, "c3")
    }

    /** A5.3 (kt ui): with no count, ratio or spacing, two square columns; the padding is taken off first. */
    @Test
    fun a5_3_kt_defaultsAndPadding() {
        listPage(
            310.dp, 400.dp,
            grid("g", ids("c", 3), mapOf("padding" to mapOf("top" to 5, "left" to 20, "right" to 10))),
            sizedBox("c0"), sizedBox("c1"), sizedBox("c2"),
        )
        assertRect(20, 5, 160, 145, "c0")
        assertRect(160, 5, 300, 145, "c1")
        assertRect(20, 145, 160, 285, "c2")
    }

    /** A5.3 (kt ui): a horizontal grid splits its height and reads the ratio as height / width. */
    @Test
    fun a5_3_kt_aHorizontalGrid() {
        listPage(
            300.dp, 210.dp,
            grid(
                "g", ids("c", 3),
                mapOf(
                    "scrollDirection" to "horizontal", "mainAxisSpacing" to 5, "crossAxisSpacing" to 10,
                    "childAspectRatio" to 2,
                ),
            ),
            sizedBox("c0"), sizedBox("c1"), sizedBox("c2"),
        )
        assertRect(0, 0, 50, 100, "c0")
        assertRect(0, 110, 50, 210, "c1")
        assertRect(55, 0, 105, 100, "c2")
    }

    /** A5.3 (kt ui): of 200 cells only the rows near the view are built. */
    @Test
    fun a5_3_kt_aGridBuildsOnlyTheCellsNearTheViewport() {
        val cells = ids("c", 200)
        val model = listPage(
            300.dp, 400.dp,
            grid("g", cells),
            *cells.map { counted(it) }.toTypedArray(),
            state = built,
        )
        val count = model.builtCount()
        assertTrue(count in 6..12, "built $count")
        compose.onNodeWithTag("c199").assertDoesNotExist()
    }

    /** A5.3 (kt ui): the grid runs the scroll triggers: 10 rows of 150 with spacing 10 in a view of 400 scroll 1,190. */
    @Test
    fun a5_3_kt_scrollingTheGridRunsTheScrollTriggers() {
        val cells = ids("c", 20)
        val model = listPage(
            300.dp, 400.dp,
            grid("g", cells, mapOf("mainAxisSpacing" to 10), actions = triggers),
            *cells.map { sizedBox(it) }.toTypedArray(),
        )

        scrollBy(10_000f)

        assertEquals(JsonValue.Int(1), model.value("begins"))
        assertEquals(JsonValue.Double(1190.0), model.value("maxExtent"))
        assertEquals(JsonValue.Double(1190.0), model.value("endOffset"))
        assertEquals(JsonValue.Bool(true), model.value("endAtEnd"))
        assertEquals(JsonValue.Double(400.0), model.value("viewport"))
    }

    /** A5.3 (kt ui): in a Column (no height limit) the grid lays out every cell, as tall as its rows. */
    @Test
    fun a5_3_kt_aGridWithNoLimitLaysOutEveryCell() {
        val cells = ids("c", 5)
        listPage(
            300.dp, 400.dp,
            column("root", "g", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            grid("g", cells, mapOf("mainAxisSpacing" to 10)),
            *cells.map { sizedBox(it) }.toTypedArray(),
        )
        assertRect(0, 0, 300, 470, "g")
        assertRect(150, 160, 300, 310, "c3")
        assertRect(0, 320, 150, 470, "c4")
    }
}
