package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.LocalOrcaFrozenNodes
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * B13.3-K: ReorderableListView on Android, Flutter's builder
 * (layout_builders.dart:686-716). The children are drawn in the page's
 * order; a long-press drag fires `onReorder` with {oldIndex, newIndex},
 * newIndex Flutter's raw value; the list never reorders by itself; the
 * scroll triggers fire as on a SingleChildScrollView. The view is 100 x 100
 * and each row 40 long, at 1 px per dp.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class ReorderableListViewTest {
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

    /** Counts the drops and keeps the last event. */
    private val onReorder: Map<String, Action> = mapOf(
        "onReorder" to Action.ActionGroup(
            mode = "sequential",
            actions = listOf(count("drops"), write("from" to "oldIndex", "to" to "newIndex")),
        ),
    )

    /** The nodes of list `l` with [rows] rows `r0`, `r1`, ... each a SizedBox 40 long around the Text "Row i". */
    private fun nodes(
        rows: Int,
        actions: Map<String, Action>,
        horizontal: Boolean = false,
        props: Map<String, JsonValue> = emptyMap(),
    ): Array<ComponentNode> {
        val direction = if (horizontal) mapOf("scrollDirection" to JsonValue.String("horizontal")) else emptyMap()
        val list = ComponentNode(
            "l", "ReorderableListView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi,
            props + direction, (0 until rows).map { "r$it" }, actions = actions,
        )
        val side = mapOf((if (horizontal) "width" else "height") to JsonValue.Int(40))
        val boxes = (0 until rows).map {
            ComponentNode("r$it", "SizedBox", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, side, listOf("t$it"))
        }
        val texts = (0 until rows).map { text("t$it", "Row $it") }
        return (listOf(list) + boxes + texts).toTypedArray()
    }

    private fun show(
        rows: Int = 3,
        actions: Map<String, Action> = onReorder,
        horizontal: Boolean = false,
        props: Map<String, JsonValue> = emptyMap(),
    ): OrcaPageModel {
        val model = OrcaPageModel(page(*nodes(rows, actions, horizontal, props)))
        compose.setContent {
            Box(Modifier.size(100.dp, 100.dp), propagateMinConstraints = true) { NodeView("l", model) }
        }
        compose.waitForIdle()
        return model
    }

    private fun OrcaPageModel.value(key: String): JsonValue? = store.state.page[key]

    private fun top(row: Int): Dp = compose.onNodeWithText("Row $row").getUnclippedBoundsInRoot().top

    private fun left(row: Int): Dp = compose.onNodeWithText("Row $row").getUnclippedBoundsInRoot().left

    /** Press row [row] in its middle and hold it past the long-press time. */
    private fun hold(row: Int) {
        compose.onNodeWithText("Row $row").performTouchInput { down(center) }
        compose.mainClock.advanceTimeBy(1_000)
        compose.waitForIdle()
    }

    /** Move the held finger by [by] dp in total, in steps of at most 10. */
    private fun move(row: Int, by: Offset) {
        val steps = (maxOf(kotlin.math.abs(by.x), kotlin.math.abs(by.y)) / 10f).toInt().coerceAtLeast(1)
        compose.onNodeWithText("Row $row").performTouchInput {
            repeat(steps) { moveBy(by / steps.toFloat()) }
        }
        compose.waitForIdle()
    }

    private fun release(row: Int) {
        compose.onNodeWithText("Row $row").performTouchInput { up() }
        compose.waitForIdle()
    }

    /** Long-press row [row], drag it by [by] dp, let go. */
    private fun drag(row: Int, by: Offset) {
        hold(row)
        move(row, by)
        release(row)
    }

    /** B13.3-K: the children are drawn one below the other, in the page's order. */
    @Test
    fun b13_3_drawsItsChildrenInOrder() {
        show()

        assertEquals(listOf(0.dp, 40.dp, 80.dp), (0..2).map { top(it) })
        assertEquals(listOf(0.dp, 0.dp, 0.dp), (0..2).map { left(it) })
    }

    /** B13.3-K: `padding` is inside the scrolled content, around the rows. */
    @Test
    fun b13_3_paddingInsetsTheRows() {
        show(props = mapOf("padding" to JsonValue.parse("""{"top":8,"right":16,"bottom":8,"left":16}""")))

        assertEquals(listOf(8.dp, 48.dp), (0..1).map { top(it) })
        assertEquals(16.dp, left(0))
    }

    /** B13.3-K: row 0 dragged below row 1 fires onReorder once, with the raw newIndex 2. */
    @Test
    fun b13_3_draggingRow0BelowRow1FiresOnReorderWith0And2() {
        val model = show()

        drag(0, Offset(0f, 60f))

        assertEquals(JsonValue.Int(1), model.value("drops"))
        assertEquals(JsonValue.Int(0), model.value("from"))
        assertEquals(JsonValue.Int(2), model.value("to"))
    }

    /** B13.3-K: row 0 dragged to the end of three gives newIndex 3, not 2. */
    @Test
    fun b13_3_draggingRow0ToTheEndGives0And3() {
        val model = show()

        drag(0, Offset(0f, 90f))

        assertEquals(JsonValue.Int(1), model.value("drops"))
        assertEquals(JsonValue.Int(0), model.value("from"))
        assertEquals(JsonValue.Int(3), model.value("to"))
    }

    /** B13.3-K: the last row dragged to the top gives {2, 0}. */
    @Test
    fun b13_3_draggingTheLastRowToTheTopGives2And0() {
        val model = show()

        drag(2, Offset(0f, -90f))

        assertEquals(JsonValue.Int(1), model.value("drops"))
        assertEquals(JsonValue.Int(2), model.value("from"))
        assertEquals(JsonValue.Int(0), model.value("to"))
    }

    /** B13.3-K: a drag that does not pass a neighbour's middle fires nothing, as Flutter. */
    @Test
    fun b13_3_aTinyDragFiresNothing() {
        val model = show()

        drag(1, Offset(0f, 12f))
        drag(1, Offset(0f, -12f))

        assertNull(model.value("drops"))
        assertNull(model.value("from"))
    }

    /** B13.3-K: a long press with no move fires nothing, and so does a swipe with no long press. */
    @Test
    fun b13_3_aLongPressAloneAndAPlainSwipeFireNothing() {
        val model = show()

        hold(0)
        release(0)
        compose.onNodeWithText("Row 0").performTouchInput {
            down(center)
            repeat(6) { moveBy(Offset(0f, 10f)) }
            up()
        }
        compose.waitForIdle()

        assertNull(model.value("drops"))
    }

    /** B13.3-K: while dragged the row follows the finger and the rows it passes make room. */
    @Test
    fun b13_3_theDraggedRowFollowsTheFingerAndTheOthersMakeRoom() {
        show()

        hold(0)
        move(0, Offset(0f, 60f))

        assertEquals(60.dp, top(0))
        assertEquals(0.dp, top(1))
        assertEquals(80.dp, top(2))
        release(0)
    }

    /** B13.3-K: after the drop the list draws the page's children, in the page's order (R4). */
    @Test
    fun b13_3_theOrderIsNotChangedLocallyAfterTheDrop() {
        val model = show()

        drag(0, Offset(0f, 60f))

        assertEquals(JsonValue.Int(2), model.value("to"))
        assertEquals(listOf(0.dp, 40.dp, 80.dp), (0..2).map { top(it) })
        assertEquals(listOf("r0", "r1", "r2"), model.resolve("l")?.childIds)
    }

    /** B13.3-K: a list with no onReorder still drags, fires nothing and goes back. */
    @Test
    fun b13_3_aListWithoutOnReorderGoesBack() {
        val model = show(actions = emptyMap())

        drag(0, Offset(0f, 60f))

        assertEquals(emptyMap(), model.store.state.page)
        assertEquals(listOf(0.dp, 40.dp, 80.dp), (0..2).map { top(it) })
    }

    /** B13.3-K: `scrollDirection: "horizontal"` draws the rows side by side and drags along x. */
    @Test
    fun b13_3_aHorizontalListDrawsAndDragsAlongX() {
        val model = show(horizontal = true)
        assertEquals(listOf(0.dp, 40.dp, 80.dp), (0..2).map { left(it) })
        assertEquals(listOf(0.dp, 0.dp, 0.dp), (0..2).map { top(it) })

        drag(0, Offset(60f, 0f))

        assertEquals(JsonValue.Int(1), model.value("drops"))
        assertEquals(JsonValue.Int(0), model.value("from"))
        assertEquals(JsonValue.Int(2), model.value("to"))
        assertEquals(listOf(0.dp, 40.dp, 80.dp), (0..2).map { left(it) })
    }

    /** B13.3-K: a drag across a horizontal list (along y) passes no row and fires nothing. */
    @Test
    fun b13_3_aHorizontalListIgnoresTheCrossAxis() {
        val model = show(horizontal = true)

        drag(0, Offset(0f, 60f))

        assertNull(model.value("drops"))
    }

    /** B13.3-K: a row held past the bottom edge scrolls the list, and drops where the list then stands. */
    @Test
    fun b13_3_aRowHeldAtTheEdgeScrollsTheList() {
        val model = show(rows = 5)

        hold(0)
        move(0, Offset(0f, 80f))
        compose.mainClock.advanceTimeBy(2_000)
        compose.waitForIdle()
        // The list is at its end (scrolled by 100): row 4 would lie at 60, and has made room, 40 up.
        assertEquals(20.dp, top(4))
        assertEquals(80.dp, top(0))
        release(0)
        // Let go, the rows are where the page has them, the list still at its end.
        assertEquals(listOf(-20.dp, 20.dp, 60.dp), (2..4).map { top(it) })

        assertEquals(JsonValue.Int(1), model.value("drops"))
        assertEquals(JsonValue.Int(0), model.value("from"))
        assertEquals(JsonValue.Int(5), model.value("to"))
    }

    /** B13.3-K: scrolling runs onScrollBegin, onScrolling and onScrollEnd with the scroll payload, in dp. */
    @Test
    fun b13_3_scrollingFiresTheScrollTriggers() {
        val triggers = mapOf(
            "onScrollBegin" to Action.ActionGroup(
                mode = "sequential",
                actions = listOf(count("begins"), write("beginOffset" to "offset", "beginAtStart" to "atStart")),
            ),
            "onScrolling" to write("offset" to "offset", "maxExtent" to "maxExtent", "delta" to "delta"),
            "onScrollEnd" to Action.ActionGroup(
                mode = "sequential",
                actions = listOf(count("ends"), write("endOffset" to "offset", "endAtEnd" to "atEnd", "viewport" to "viewportDimension")),
            ),
        )
        val model = show(rows = 5, actions = triggers)
        assertNull(model.value("begins"))

        compose.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, 1000f) }
        compose.waitForIdle()

        assertEquals(JsonValue.Int(1), model.value("begins"))
        assertEquals(JsonValue.Double(0.0), model.value("beginOffset"))
        assertEquals(JsonValue.Bool(true), model.value("beginAtStart"))
        assertEquals(JsonValue.Double(100.0), model.value("offset"))
        assertEquals(JsonValue.Double(100.0), model.value("maxExtent"))
        assertEquals(JsonValue.Int(1), model.value("ends"))
        assertEquals(JsonValue.Double(100.0), model.value("endOffset"))
        assertEquals(JsonValue.Bool(true), model.value("endAtEnd"))
        assertEquals(JsonValue.Double(100.0), model.value("viewport"))
    }

    /** B13.3-K: a list with only onReorder fires no scroll trigger when scrolled. */
    @Test
    fun b13_3_aListWithoutScrollTriggersFiresNoneWhenScrolled() {
        val model = show(rows = 5)

        compose.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, 1000f) }
        compose.waitForIdle()

        assertEquals(emptyMap(), model.store.state.page)
        assertEquals(60.dp, top(4))
    }

    /** B13.3-K: in a layer drawn from a snapshot the list is still: no drag, no action. */
    @Test
    fun b13_3_aFrozenListDoesNotDragOrFire() {
        val model = OrcaPageModel(page(*nodes(3, onReorder)))
        val frozen: Map<String, ResolvedNode> = model.page.components.associate { node ->
            val resolved = assertNotNull(model.resolve(node.id))
            node.id to resolved.copy(actions = resolved.actions.mapValues { OrcaPageModel.INERT_ACTION })
        }
        compose.setContent {
            CompositionLocalProvider(LocalOrcaFrozenNodes provides frozen) {
                Box(Modifier.size(100.dp, 100.dp), propagateMinConstraints = true) { NodeView("l", model) }
            }
        }
        compose.waitForIdle()

        hold(0)
        move(0, Offset(0f, 60f))
        assertEquals(listOf(0.dp, 40.dp, 80.dp), (0..2).map { top(it) })
        release(0)

        assertEquals(emptyMap(), model.store.state.page)
    }

    /** B13.3-K: on an axis with no limit (a list inside a Column) it draws its rows and does not throw. */
    @Test
    fun b13_3_aListWithNoHeightLimitDrawsItsRows() {
        val model = OrcaPageModel(page(column("c", "l"), *nodes(3, onReorder)))
        compose.setContent {
            Box(Modifier.size(100.dp, 300.dp), propagateMinConstraints = true) { NodeView("c", model) }
        }
        compose.waitForIdle()

        assertEquals(listOf(0.dp, 40.dp, 80.dp), (0..2).map { top(it) })
    }

    /**
     * B13.3-K: the page puts a row before the held one while it is held. The
     * drag is dropped (letting go fires nothing, no row is drawn as dragged),
     * and the list drags again.
     */
    @Test
    fun b13_3_childrenChangedWhileARowIsHeldEndTheDragAndTheListDragsAgain() {
        val model = show()
        val added = listOf(
            ComponentNode(
                "r9", "SizedBox", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                mapOf("height" to JsonValue.Int(40)), listOf("t9"),
            ),
            text("t9", "Row 9"),
        )

        hold(1)
        move(1, Offset(0f, 20f))
        compose.runOnIdle { model.apply(ComponentMutation.Add("l", added, position = 1)) }
        compose.waitForIdle()
        release(1)

        assertEquals(listOf("r0", "r9", "r1", "r2"), model.resolve("l")?.childIds)
        assertNull(model.value("drops"))
        assertEquals(listOf(0.dp, 40.dp, 80.dp), listOf(0, 9, 1).map { top(it) })

        // The new row took the held row's index: dragged above row 0 it gives {1, 0}.
        drag(9, Offset(0f, -50f))

        assertEquals(JsonValue.Int(1), model.value("drops"))
        assertEquals(JsonValue.Int(1), model.value("from"))
        assertEquals(JsonValue.Int(0), model.value("to"))
    }

    /** B13.3-K: right to left, a horizontal list runs from the right and a drag to the left moves a row on. */
    @Test
    fun b13_3_aHorizontalListRightToLeftRunsFromTheRightAndDragsLeftward() {
        val model = OrcaPageModel(page(*nodes(3, onReorder, horizontal = true)))
        compose.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                Box(Modifier.size(100.dp, 100.dp), propagateMinConstraints = true) { NodeView("l", model) }
            }
        }
        compose.waitForIdle()
        assertEquals(listOf(60.dp, 20.dp, -20.dp), (0..2).map { left(it) })

        hold(0)
        move(0, Offset(-60f, 0f))
        assertEquals(0.dp, left(0))
        assertEquals(60.dp, left(1))
        release(0)

        assertEquals(JsonValue.Int(1), model.value("drops"))
        assertEquals(JsonValue.Int(0), model.value("from"))
        assertEquals(JsonValue.Int(2), model.value("to"))
        assertEquals(listOf(60.dp, 20.dp, -20.dp), (0..2).map { left(it) })
    }
}
