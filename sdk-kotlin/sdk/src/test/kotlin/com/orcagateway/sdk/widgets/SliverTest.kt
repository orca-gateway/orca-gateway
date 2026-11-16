package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.GridCells
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * B13.1-K, B13.2-K, C-fallback-K and C-fix on Android: CustomScrollView and
 * the four slivers against Flutter's builders (structure_builders.dart
 * `_buildCustomScrollView` to `_buildSliverAppBar`) and the bar's extents
 * Flutter measures (sdk/test/sliver_widgets_test.dart `barCases`), at 1 dp
 * per pixel in a view 300 x 400 (Flutter's is 800 x 600: the bar's numbers
 * do not depend on it). CustomScrollViews, SizedBoxes and Columns are tagged
 * with their ids; a drawn bar by [sliverAppBarTag].
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class SliverTest {
    @get:Rule
    val compose = createComposeRule()

    /** Set by a test that tears the page down and restores it: the page is then drawn through it. */
    private var restoration: StateRestorationTester? = null

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

    private val counters = listOf(
        StateDefinition("built", StateScope.Page, JsonValue.Int(0)),
        StateDefinition("inits", StateScope.Page, JsonValue.Int(0)),
    )

    /** A page drawn from its root, with the standard builders, inside a loose box of the given size. */
    private fun sliverPage(
        width: Dp,
        height: Dp,
        vararg nodes: ComponentNode,
        state: List<StateDefinition> = emptyList(),
        app: Lifecycle? = null,
    ): OrcaPageModel {
        val model = OrcaPageModel(page(*nodes, state = state)).apply {
            val standard = WidgetBuilders.standard()
            builders = WidgetBuilders.standard().apply {
                val scroll = requireNotNull(standard["CustomScrollView"]) { "CustomScrollView is not registered" }
                register("CustomScrollView") { node, model, modifier -> scroll(node, model, modifier.testTag(node.id)) }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
                register("Column") { node, model, modifier ->
                    FlexWidget(node, model, modifier.testTag(node.id), vertical = true)
                }
            }
        }
        val content: @Composable () -> Unit = {
            // The app's lifecycle is the test's when it gives one, standing in for ProcessLifecycleOwner's.
            CompositionLocalProvider(*listOfNotNull(app?.let { LocalOrcaAppLifecycle provides it }).toTypedArray()) {
                Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
            }
        }
        restoration?.setContent(content) ?: compose.setContent(content)
        compose.waitForIdle()
        return model
    }

    private fun layout(type: String, id: String, children: List<String>, props: Map<String, Any?>, actions: Map<String, Action>? = null) =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout,
            if (type == "SliverToBoxAdapter") ComponentNode.ChildMode.Single else ComponentNode.ChildMode.Multi,
            props.mapValues { JsonValue.of(it.value) }, children, actions = actions,
        )

    private fun scroll(id: String, children: List<String>, props: Map<String, Any?> = emptyMap(), actions: Map<String, Action>? = null) =
        layout("CustomScrollView", id, children, props, actions)

    private fun sliverList(id: String, children: List<String>) = layout("SliverList", id, children, emptyMap())

    private fun sliverGrid(id: String, children: List<String>, props: Map<String, Any?> = emptyMap()) =
        layout("SliverGrid", id, children, props)

    private fun adapter(id: String, child: String? = null) = layout("SliverToBoxAdapter", id, listOfNotNull(child), emptyMap())

    private fun bar(
        id: String,
        props: Map<String, Any?> = emptyMap(),
        slots: Map<String, String> = emptyMap(),
        actions: Map<String, Action>? = null,
    ) = ComponentNode(
        id, "SliverAppBar", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
        (props + slots).mapValues { JsonValue.of(it.value) }, slots.values.toList(), actions = actions,
    )

    /** A SizedBox [id] that counts itself into `built` when it is built. */
    private fun counted(id: String, height: Int): ComponentNode =
        sizedBox(id, height = height).copy(actions = mapOf("onInit" to count("built")))

    private fun ids(prefix: String, count: Int): List<String> = (0 until count).map { "$prefix$it" }

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun assertRect(left: Int, top: Int, right: Int, bottom: Int, tag: String) {
        assertEquals(DpRect(left.dp, top.dp, right.dp, bottom.dp), bounds(tag), tag)
    }

    private fun OrcaPageModel.value(key: String): JsonValue? = store.state.page[key]

    private fun OrcaPageModel.int(key: String): Int = value(key)?.doubleValue?.toInt() ?: -1

    /** Scroll the only scroll view by [by] dp along its axis (the semantics action, which Compose runs as a user's drag). */
    private fun scrollBy(by: Float) {
        compose.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, by) }
        compose.waitForIdle()
    }

    /** Put a finger on scroll view `s` and spend the touch slop toward the end ([forward]) or back toward the start. */
    private fun fingerDown(forward: Boolean) {
        compose.onNodeWithTag("s").performTouchInput {
            down(Offset(150f, 300f))
            moveBy(Offset(0f, if (forward) -viewConfiguration.touchSlop else viewConfiguration.touchSlop))
        }
        compose.waitForIdle()
    }

    /** Drag the finger so the scroll offset grows by [by] dp (negative: back toward the start). */
    private fun drag(by: Float) {
        compose.onNodeWithTag("s").performTouchInput { moveBy(Offset(0f, -by)) }
        compose.waitForIdle()
    }

    /** Hold the finger still, so nothing is flung, and lift it; the view settles. */
    private fun lift() {
        compose.onNodeWithTag("s").performTouchInput {
            advanceEventTime(500)
            move()
            up()
        }
        compose.waitForIdle()
    }

    // ── The bar, as Flutter's table reads it ────────────────────────────────

    /** CustomScrollView `s` > [SliverAppBar `bar`, SliverToBoxAdapter(`first`, 50 high), SliverList of 40 rows 50 high]. */
    private fun barPage(vararg props: Pair<String, Any?>): OrcaPageModel {
        val rows = ids("r", 40)
        return sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar", "ad", "l")),
            bar("bar", props.toMap(), mapOf("title" to "title", "flexibleSpace" to "space")),
            text("title", "Title"),
            // Taller than any bar: it fills the box, whose height is the most a flexibleSpace gets.
            sizedBox("space", height = 1000),
            adapter("ad", "first"),
            sizedBox("first", height = 50),
            sliverList("l", rows),
            *rows.map { sizedBox(it, height = 50) }.toTypedArray(),
        )
    }

    /**
     * One row of Flutter's table: the drawn bar is [paint] high from the top
     * of the view, its box (the flexibleSpace fills it) [box] high with its
     * bottom edge at [paint], the toolbar at [opacity], and the content
     * starts at [layout] while the first of it is on screen.
     */
    private fun assertBar(paint: Int, layout: Int, box: Int, opacity: Double, at: String) {
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, paint.dp), bounds(sliverAppBarTag("bar")), "the drawn bar, $at")
        assertEquals(DpRect(0.dp, (paint - box).dp, 300.dp, paint.dp), bounds("space"), "the bar's box, $at")
        val alpha = compose.onNodeWithTag(sliverToolbarTag("bar")).fetchSemanticsNode().config[SliverToolbarAlpha]
        assertEquals(opacity, alpha.toDouble(), 0.0001, "toolbar opacity, $at")
        if (compose.onAllNodes(hasTestTag("first")).fetchSemanticsNodes().isNotEmpty()) {
            val top = bounds("first").top
            if (top >= 0.dp) assertEquals(layout.dp, top, "content top, $at")
        }
    }

    /** B13.2-K: Flutter's `pinned, expanded 200`: the bar shrinks to the toolbar and stays, over the content. */
    @Test
    fun b13_2_k_aPinnedBarCollapsesToTheToolbarAndStays() {
        barPage("pinned" to true, "expandedHeight" to 200)
        assertBar(200, 200, 200, 1.0, "0")
        scrollBy(100f)
        assertBar(100, 100, 100, 1.0, "100")
        scrollBy(500f)
        assertBar(56, 0, 56, 1.0, "600")
        scrollBy(-20f)
        assertBar(56, 0, 56, 1.0, "580")
        scrollBy(-580f)
        assertBar(200, 200, 200, 1.0, "back at 0")
    }

    /** B13.2-K: Flutter's `neither, expanded 200`: the bar scrolls away with the content and only comes back at the top. */
    @Test
    fun b13_2_k_aBarThatIsNeitherScrollsAway() {
        barPage("expandedHeight" to 200)
        assertBar(200, 200, 200, 1.0, "0")
        scrollBy(100f)
        assertBar(100, 100, 100, 1.0, "100")
        scrollBy(500f)
        assertBar(0, 0, 56, 0.0, "600")

        fingerDown(forward = false)
        drag(-20f)
        assertBar(0, 0, 56, 0.0, "580")
        lift()
    }

    /** B13.2-K: Flutter's `neither, no expanded`: with no expandedHeight the bar is the toolbar, 56 high, fading as it leaves. */
    @Test
    fun b13_2_k_withNoExpandedHeightTheBarIsTheToolbar() {
        barPage()
        assertBar(56, 56, 56, 1.0, "0")
        scrollBy(30f)
        assertBar(26, 26, 56, 0.4643, "30")
        scrollBy(570f)
        assertBar(0, 0, 56, 0.0, "600")
    }

    /**
     * B13.2-K: Flutter's `floating, expanded 200`: gone when scrolled away,
     * back in by as much as the finger drags back, out again as it goes on;
     * lifting the finger leaves it (no snap).
     */
    @Test
    fun b13_2_k_aFloatingBarReEntersOnAReverseScroll() {
        barPage("floating" to true, "expandedHeight" to 200)
        assertBar(200, 200, 200, 1.0, "0")
        scrollBy(100f)
        assertBar(100, 100, 100, 1.0, "100")
        scrollBy(500f)
        assertBar(0, 0, 56, 0.0, "600")

        fingerDown(forward = false)
        drag(-20f)
        assertBar(20, 0, 56, 0.3571, "580")
        drag(-80f)
        assertBar(100, 0, 100, 1.0, "500")
        drag(20f)
        assertBar(80, 0, 80, 1.0, "520")
        lift()
        assertBar(80, 0, 80, 1.0, "520, released")
    }

    /**
     * B13.2-K: a programmatic scroll (a jump to an item, which passes no
     * scroll delta) does not float the bar back in, as Flutter's, which
     * reveals a floating bar on a user drag only; the bar is back when the
     * view is back at its start. The semantics scroll action counts as the
     * user's: Compose runs it as a drag.
     */
    @Test
    fun b13_2_k_aProgrammaticScrollDoesNotFloatTheBarBackIn() {
        barPage("floating" to true, "expandedHeight" to 200)
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(20)
        compose.waitForIdle()
        assertBar(0, 0, 56, 0.0, "at item 20")
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(10)
        compose.waitForIdle()
        assertBar(0, 0, 56, 0.0, "back at item 10")
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(0)
        compose.waitForIdle()
        assertBar(200, 200, 200, 1.0, "at the start")

        scrollBy(600f)
        scrollBy(-100f)
        assertBar(100, 0, 100, 1.0, "500 by the semantics action")
    }

    /**
     * B13.2-K: a floating bar comes back on a drag back after a jump to an
     * item: Flutter's `floating, E200` at 580 after a drag back of 20.
     */
    @Test
    fun b13_2_k_aFloatingBarReEntersOnADragBackAfterAJump() {
        barPage("floating" to true, "expandedHeight" to 200)
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(20)
        compose.waitForIdle()
        assertBar(0, 0, 56, 0.0, "at item 20")

        fingerDown(forward = false)
        drag(-20f)
        assertBar(20, 0, 56, 0.3571, "20 back from item 20")
        drag(-80f)
        assertBar(100, 0, 100, 1.0, "100 back from item 20")
        lift()
    }

    /**
     * B13.2-K: a floating bar comes back on a drag back after a scrolled
     * position was restored with the list's state (a rotation, a process
     * brought back): Flutter's `floating, E200` at 580 after a drag back of
     * 20 from 600.
     */
    @Test
    fun b13_2_k_aFloatingBarReEntersOnADragBackAfterARestore() {
        val tester = StateRestorationTester(compose)
        restoration = tester
        barPage("floating" to true, "expandedHeight" to 200)
        scrollBy(600f)
        assertBar(0, 0, 56, 0.0, "600")
        val row = bounds("r8")

        tester.emulateSavedInstanceStateRestore()
        compose.waitForIdle()
        assertEquals(row, bounds("r8"), "the list is restored where it was")
        assertBar(0, 0, 56, 0.0, "600, restored")

        fingerDown(forward = false)
        drag(-20f)
        assertBar(20, 0, 56, 0.3571, "580")
        drag(-80f)
        assertBar(100, 0, 100, 1.0, "500")
        lift()
    }

    /**
     * B13.2-K: a jump that stops just past the bar (item 2 under a bar of
     * 200: offset 250, the bar's place gone by 50) still lets a floating bar
     * in by as much as the finger drags back, before its place shows again.
     */
    @Test
    fun b13_2_k_aFloatingBarReEntersOnADragBackAfterAShallowJump() {
        barPage("floating" to true, "expandedHeight" to 200)
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(2)
        compose.waitForIdle()
        assertRect(0, 0, 300, 50, "r0")
        assertBar(0, 0, 56, 0.0, "at item 2")

        fingerDown(forward = false)
        drag(-20f)
        assertRect(0, 20, 300, 70, "r0")
        assertBar(20, 0, 56, 0.3571, "20 back from item 2")
        lift()
    }

    /**
     * B13.2-K: the flexibleSpace is as wide as the bar and at most as high
     * as its box, at the top (Flutter lays it out loose in height, in a
     * passthrough Stack: its Text there measures 800 x 20): a slot 20 high
     * keeps its height.
     */
    @Test
    fun b13_2_k_aFlexibleSpaceThatDoesNotExpandKeepsItsHeightAtTheTop() {
        val rows = ids("r", 40)
        sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar", "l")),
            bar("bar", mapOf("pinned" to true, "expandedHeight" to 200), mapOf("flexibleSpace" to "space")),
            sizedBox("space", height = 20),
            sliverList("l", rows),
            *rows.map { sizedBox(it, height = 50) }.toTypedArray(),
        )
        assertRect(0, 0, 300, 20, "space")

        scrollBy(600f)

        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 56.dp), bounds(sliverAppBarTag("bar")))
        assertRect(0, 0, 300, 20, "space")
    }

    /** B13.2-K: a snap bar does not jump: half way through the 300 ms it is part open. */
    @Test
    fun b13_2_k_aSnapBarSettlesOverTime() {
        barPage("floating" to true, "snap" to true, "expandedHeight" to 200)
        scrollBy(600f)
        fingerDown(forward = false)
        drag(-20f)
        compose.mainClock.autoAdvance = false
        compose.onNodeWithTag("s").performTouchInput {
            advanceEventTime(500)
            move()
            up()
        }
        compose.mainClock.advanceTimeBy(150)
        val part = bounds(sliverAppBarTag("bar")).height
        assertTrue(part > 30.dp && part < 190.dp, "half way: $part")
        compose.mainClock.autoAdvance = true
        compose.waitForIdle()
        assertBar(200, 0, 200, 1.0, "580, released")
    }

    /** B13.2-K: Flutter's `floating + pinned, expanded 200`: never below the toolbar, and it grows back on a reverse scroll. */
    @Test
    fun b13_2_k_aFloatingPinnedBarGrowsBackFromTheToolbar() {
        barPage("floating" to true, "pinned" to true, "expandedHeight" to 200)
        scrollBy(600f)
        assertBar(56, 0, 56, 1.0, "600")

        fingerDown(forward = false)
        drag(-20f)
        assertBar(56, 0, 56, 1.0, "580")
        drag(-80f)
        assertBar(100, 0, 100, 1.0, "500")
        drag(20f)
        assertBar(80, 0, 80, 1.0, "520")
        lift()
    }

    /**
     * B13.2-K: Flutter's `floating + snap, expanded 200`: when the finger
     * lifts the bar opens whole after a drag back, and closes whole after a
     * drag on; the scroll offset does not move.
     */
    @Test
    fun b13_2_k_aSnapBarSettlesWhenTheFingerLifts() {
        barPage("floating" to true, "snap" to true, "expandedHeight" to 200)
        assertBar(200, 200, 200, 1.0, "0")
        scrollBy(600f)
        assertBar(0, 0, 56, 0.0, "600")

        fingerDown(forward = false)
        drag(-20f)
        assertBar(20, 0, 56, 0.3571, "580")
        val row = bounds("r8")
        lift()
        assertBar(200, 0, 200, 1.0, "580, released")
        assertEquals(row, bounds("r8"), "the content did not move")

        fingerDown(forward = true)
        drag(20f)
        assertBar(180, 0, 180, 1.0, "600")
        lift()
        assertBar(0, 0, 56, 0.0, "600, released")
    }

    /** B13.2-K: Flutter's `pinned, expanded 200, collapsed 80`: the pinned bar stops at collapsedHeight. */
    @Test
    fun b13_2_k_collapsedHeightIsWhereAPinnedBarStops() {
        barPage("pinned" to true, "expandedHeight" to 200, "collapsedHeight" to 80)
        assertBar(200, 200, 200, 1.0, "0")
        scrollBy(100f)
        assertBar(100, 100, 100, 1.0, "100")
        scrollBy(50f)
        assertBar(80, 50, 80, 1.0, "150")
        scrollBy(450f)
        assertBar(80, 0, 80, 1.0, "600")
    }

    /** B13.2-K: Flutter's `neither, expanded 200, collapsed 80`: the box stops at 80 and slides out, the toolbar fading. */
    @Test
    fun b13_2_k_collapsedHeightIsTheSmallestBoxOfABarThatScrollsAway() {
        barPage("expandedHeight" to 200, "collapsedHeight" to 80)
        scrollBy(100f)
        assertBar(100, 100, 100, 1.0, "100")
        scrollBy(50f)
        assertBar(50, 50, 80, 0.4643, "150")
        scrollBy(450f)
        assertBar(0, 0, 80, 0.0, "600")
    }

    /**
     * B13.2-K: the slots are drawn as Flutter's toolbar lays them out: the
     * leading box 56 square at the start, the title 16 past it, the actions
     * in order at the end, the flexibleSpace behind them filling the bar;
     * the bar's own onInit runs once.
     */
    @Test
    fun b13_2_k_theBarDrawsItsSlots() {
        val rows = ids("r", 40)
        val model = sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar", "l")),
            bar(
                "bar", mapOf("pinned" to true, "expandedHeight" to 200),
                mapOf("title" to "title", "leading" to "lead", "flexibleSpace" to "space", "action_0" to "a0", "action_1" to "a1", "action_3" to "a3"),
                actions = mapOf("onInit" to count("inits")),
            ),
            text("title", "Title"),
            sizedBox("lead", 24, 24),
            sizedBox("space", height = 1000),
            sizedBox("a0", 30, 30),
            sizedBox("a1", 40, 30),
            sizedBox("a3", 40, 30),
            sliverList("l", rows),
            *rows.map { sizedBox(it, height = 50) }.toTypedArray(),
            state = counters,
        )
        assertRect(0, 0, 300, 200, "space")
        assertRect(0, 0, 56, 56, "lead")
        assertEquals(72.dp, compose.onNodeWithText("Title").getUnclippedBoundsInRoot().left)
        assertRect(230, 13, 260, 43, "a0")
        assertRect(260, 13, 300, 43, "a1")
        // action_2 is missing: the slots stop at the first gap, as Flutter's.
        compose.onNodeWithTag("a3").assertDoesNotExist()
        assertEquals(1, model.int("inits"))

        scrollBy(600f)

        assertRect(0, 0, 300, 56, "space")
        assertRect(0, 0, 56, 56, "lead")
        compose.onNodeWithText("Title").assertIsDisplayed()
        assertEquals(1, model.int("inits"))
    }

    /** B13.2-K: `centerTitle` centres the title in the toolbar; with no leading a title that is not centred starts at 16. */
    @Test
    fun b13_2_k_centerTitleCentresTheTitle() {
        sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar")),
            bar("bar", mapOf("centerTitle" to true), mapOf("title" to "title")),
            sizedBox("title", 100, 20),
        )
        assertRect(100, 18, 200, 38, "title")
    }

    @Test
    fun b13_2_k_aTitleWithNoLeadingStartsAt16() {
        sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar")),
            bar("bar", slots = mapOf("title" to "title")),
            sizedBox("title", 100, 20),
        )
        assertRect(16, 18, 116, 38, "title")
    }

    // ── One scroll view ─────────────────────────────────────────────────────

    /**
     * B13.1-K: a bar, an adapter, a grid, a list of 200 and a closing adapter
     * are one scroll view. Grid cells have the size and place the core's
     * GridCells gives (3 across 300 with crossAxisSpacing 6 and ratio 1.5:
     * 96 x 64, mainAxisSpacing 8 between the lines and none after the last);
     * only the rows near the screen are built; the end shows the last adapter.
     */
    @Test
    fun b13_1_k_aBarAGridAListOf200AndAdaptersAreOneLazyScrollView() {
        val rows = ids("r", 200)
        val cells = ids("c", 5)
        val grid = mapOf("crossAxisCount" to 3, "mainAxisSpacing" to 8, "crossAxisSpacing" to 6, "childAspectRatio" to 1.5)
        val model = sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar", "ad", "g", "l", "end")),
            bar("bar", mapOf("pinned" to true, "expandedHeight" to 100), mapOf("title" to "title")),
            text("title", "Title"),
            adapter("ad", "first"),
            sizedBox("first", 20, 50),
            sliverGrid("g", cells, grid),
            *cells.map { sizedBox(it) }.toTypedArray(),
            sliverList("l", rows),
            *rows.map { counted(it, height = 40) }.toTypedArray(),
            adapter("end", "last"),
            sizedBox("last", height = 50),
            state = counters,
        )
        compose.onAllNodes(hasScrollAction()).assertCountEquals(1)
        assertRect(0, 0, 300, 400, "s")
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 100.dp), bounds(sliverAppBarTag("bar")))
        // The adapter's child right under the bar, at the cross extent.
        assertRect(0, 100, 300, 150, "first")

        val core = GridCells(crossAxisCount = 3, mainAxisSpacing = 8.0, crossAxisSpacing = 6.0, childAspectRatio = 1.5)
        for (index in cells.indices) {
            val frame = core.frame(index, 300.0, 400.0)
            val expected = DpRect(frame.x.dp, (150 + frame.y).dp, (frame.x + frame.width).dp, (150 + frame.y + frame.height).dp)
            assertEquals(expected, bounds("c$index"), "c$index")
        }
        assertRect(0, 150, 96, 214, "c0")
        assertRect(204, 150, 300, 214, "c2")
        assertRect(102, 222, 198, 286, "c4")
        // The list starts right after the second line: no spacing after the last.
        assertRect(0, 286, 300, 326, "r0")

        val first = model.int("built")
        assertTrue(first in 3..8, "built $first")
        compose.onNodeWithTag("r199").assertDoesNotExist()
        compose.onNodeWithTag("last").assertDoesNotExist()

        scrollBy(100_000f)

        assertRect(0, 350, 300, 400, "last")
        assertRect(0, 310, 300, 350, "r199")
        compose.onNodeWithTag("r0").assertDoesNotExist()
        compose.onNodeWithTag("c0").assertDoesNotExist()
        val after = model.int("built")
        assertTrue(after < 60, "built $after of 200")
        // Pinned: the toolbar is still there, over the rows.
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 56.dp), bounds(sliverAppBarTag("bar")))
    }

    /** B13.1-K: SliverGrid's defaults are GridView's: 2 across, no spacing, square cells. */
    @Test
    fun b13_1_k_aSliverGridDefaultsToTwoSquareCellsAcross() {
        sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("g")),
            sliverGrid("g", listOf("c0", "c1", "c2")),
            sizedBox("c0"), sizedBox("c1"), sizedBox("c2"),
        )
        assertRect(0, 0, 150, 150, "c0")
        assertRect(150, 0, 300, 150, "c1")
        assertRect(0, 150, 150, 300, "c2")
    }

    /** B13.1-K: the view runs its node's scroll triggers with ListView's metrics: 100 rows of 40 in a view of 400 scroll 3,600. */
    @Test
    fun b13_1_k_scrollingRunsTheScrollTriggers() {
        val rows = ids("r", 100)
        val model = sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("l"), actions = triggers),
            sliverList("l", rows),
            *rows.map { sizedBox(it, height = 40) }.toTypedArray(),
        )

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

    /** B13.1-K: with a bar and mixed slivers the triggers still fire, begin and end once a scroll, at the end `atEnd`. */
    @Test
    fun b13_1_k_theTriggersFireUnderABar() {
        val rows = ids("r", 60)
        val model = sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar", "l"), actions = triggers),
            bar("bar", mapOf("pinned" to true, "expandedHeight" to 200)),
            sliverList("l", rows),
            *rows.map { sizedBox(it, height = 40) }.toTypedArray(),
        )

        scrollBy(100_000f)

        assertEquals(JsonValue.Int(1), model.value("begins"))
        assertEquals(JsonValue.Int(1), model.value("ends"))
        assertEquals(JsonValue.Bool(true), model.value("endAtEnd"))
        assertEquals(JsonValue.Double(400.0), model.value("viewport"))
    }

    /** B13.1-K: a horizontal view runs across, each box as tall as the view, a grid line a column of cells. */
    @Test
    fun b13_1_k_aHorizontalViewRunsAcross() {
        sliverPage(
            300.dp, 100.dp,
            scroll("s", listOf("l", "g"), mapOf("scrollDirection" to "horizontal")),
            sliverList("l", listOf("a", "b")),
            sizedBox("a", width = 50), sizedBox("b", width = 60),
            sliverGrid("g", listOf("c0", "c1", "c2"), mapOf("mainAxisSpacing" to 10)),
            sizedBox("c0"), sizedBox("c1"), sizedBox("c2"),
        )
        assertRect(0, 0, 300, 100, "s")
        assertRect(0, 0, 50, 100, "a")
        assertRect(50, 0, 110, 100, "b")
        // 2 down 100: cells 50 x 50, the second line 10 past the first.
        assertRect(110, 0, 160, 50, "c0")
        assertRect(110, 50, 160, 100, "c1")
        assertRect(170, 0, 220, 50, "c2")
    }

    /** B13.1-K: reverse puts the first sliver at the far end, offset 0 there. */
    @Test
    fun b13_1_k_reverseStartsAtTheFarEnd() {
        sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("l", "g"), mapOf("reverse" to true)),
            sliverList("l", listOf("a", "b")),
            sizedBox("a", height = 40), sizedBox("b", height = 40),
            sliverGrid("g", listOf("c0", "c1", "c2"), mapOf("mainAxisSpacing" to 10, "childAspectRatio" to 3)),
            sizedBox("c0"), sizedBox("c1"), sizedBox("c2"),
        )
        assertRect(0, 360, 300, 400, "a")
        assertRect(0, 320, 300, 360, "b")
        // Cells 150 x 50; the second line is above the first, 10 apart.
        assertRect(0, 270, 150, 320, "c0")
        assertRect(150, 270, 300, 320, "c1")
        assertRect(0, 210, 150, 260, "c2")
    }

    /** B13.1-K: a reversed horizontal view starts at the right. */
    @Test
    fun b13_1_k_aReversedHorizontalViewStartsAtTheRight() {
        sliverPage(
            300.dp, 100.dp,
            scroll("s", listOf("l"), mapOf("scrollDirection" to "horizontal", "reverse" to true)),
            sliverList("l", listOf("a", "b")),
            sizedBox("a", width = 50), sizedBox("b", width = 60),
        )
        assertRect(250, 0, 300, 100, "a")
        assertRect(190, 0, 250, 100, "b")
    }

    /** B13.1-K: shrinkWrap sizes the view to its content on the scroll axis, the bar's spacer included. */
    @Test
    fun b13_1_k_shrinkWrapHugsItsContent() {
        sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar", "l"), mapOf("shrinkWrap" to true)),
            bar("bar"),
            sliverList("l", listOf("a", "b", "c")),
            sizedBox("a", height = 40), sizedBox("b", height = 40), sizedBox("c", height = 40),
        )
        assertRect(0, 0, 300, 176, "s")
        assertRect(0, 136, 300, 176, "c")
    }

    /** B13.1-K: in a Column (no height limit) the view lays out every item and does not scroll, as ListView. */
    @Test
    fun b13_1_k_aViewWithNoLimitLaysOutEveryItem() {
        val rows = ids("r", 30)
        sliverPage(
            300.dp, 400.dp,
            column("root", "s", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            scroll("s", listOf("bar", "l")),
            bar("bar"),
            sliverList("l", rows),
            *rows.map { sizedBox(it, height = 40) }.toTypedArray(),
        )
        assertRect(0, 0, 300, 1256, "s")
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 56.dp), bounds(sliverAppBarTag("bar")))
        assertRect(0, 56, 300, 96, "r0")
        assertRect(0, 1216, 300, 1256, "r29")
        compose.onAllNodes(hasScrollAction()).assertCountEquals(0)
    }

    // ── Fallbacks ───────────────────────────────────────────────────────────

    /**
     * C-fallback-K: outside a CustomScrollView (Flutter throws) a SliverList
     * draws its children one below the other, a SliverGrid its cells, a
     * SliverToBoxAdapter its child, a SliverAppBar a box of its full extent.
     */
    @Test
    fun c_fallback_k_eachSliverDrawsOutsideACustomScrollView() {
        sliverPage(
            300.dp, 400.dp,
            column("root", "l", "g", "ad", "bar", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            sliverList("l", listOf("a", "b")),
            sizedBox("a", height = 40), sizedBox("b", height = 40),
            sliverGrid("g", listOf("c0", "c1", "c2"), mapOf("childAspectRatio" to 3, "mainAxisSpacing" to 10)),
            sizedBox("c0"), sizedBox("c1"), sizedBox("c2"),
            adapter("ad", "only"),
            sizedBox("only", height = 30),
            bar("bar", mapOf("expandedHeight" to 120), mapOf("title" to "title")),
            text("title", "Title"),
        )
        assertRect(0, 0, 300, 40, "a")
        assertRect(0, 40, 300, 80, "b")
        assertRect(0, 80, 150, 130, "c0")
        assertRect(150, 80, 300, 130, "c1")
        assertRect(0, 140, 150, 190, "c2")
        assertRect(0, 190, 300, 220, "only")
        assertEquals(DpRect(0.dp, 220.dp, 300.dp, 340.dp), bounds(sliverAppBarTag("bar")))
        compose.onNodeWithText("Title").assertIsDisplayed()
    }

    /**
     * C-fallback-K: a widget that is no sliver draws as a box item (Flutter
     * throws), an adapter with no child draws nothing, and a bar that is not
     * the first sliver is a box of its full extent that scrolls with the rest.
     */
    @Test
    fun c_fallback_k_aStrayChildAndABarThatIsNotFirstAreBoxes() {
        val rows = ids("r", 40)
        sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("stray", "empty", "bar", "l")),
            sizedBox("stray", 20, 30),
            adapter("empty"),
            bar("bar", mapOf("pinned" to true, "expandedHeight" to 100), mapOf("title" to "title")),
            text("title", "Title"),
            sliverList("l", rows),
            *rows.map { sizedBox(it, height = 50) }.toTypedArray(),
        )
        assertRect(0, 0, 300, 30, "stray")
        assertEquals(DpRect(0.dp, 30.dp, 300.dp, 130.dp), bounds(sliverAppBarTag("bar")))
        assertRect(0, 130, 300, 180, "r0")

        scrollBy(60f)

        assertEquals(DpRect(0.dp, (-30).dp, 300.dp, 70.dp), bounds(sliverAppBarTag("bar")))
        assertEquals(100.dp, bounds(sliverAppBarTag("bar")).height)
        assertRect(0, 70, 300, 120, "r0")

        scrollBy(600f)

        compose.onNodeWithTag(sliverAppBarTag("bar")).assertDoesNotExist()
    }

    /**
     * C-fallback-K: a stray child is resolved once, by the view, and gets
     * one set of lifecycle triggers: when the app goes to the background its
     * onAppBackground runs once, as a row's and an adapter child's.
     */
    @Test
    fun c_fallback_k_aStrayChildRunsItsLifecycleTriggersOnce() {
        val app = object : LifecycleOwner {
            val registry = LifecycleRegistry(this)
            override val lifecycle: Lifecycle get() = registry
        }
        compose.runOnUiThread { app.registry.currentState = Lifecycle.State.RESUMED }
        val model = sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("stray", "l", "ad")),
            sizedBox("stray", 20, 30).copy(actions = mapOf("onInit" to count("inits"), "onAppBackground" to count("stops"))),
            sliverList("l", listOf("row")),
            sizedBox("row", height = 40).copy(actions = mapOf("onAppBackground" to count("rowStops"))),
            adapter("ad", "only"),
            sizedBox("only", height = 40).copy(actions = mapOf("onAppBackground" to count("rowStops"))),
            state = counters + listOf("stops", "rowStops").map { StateDefinition(it, StateScope.Page, JsonValue.Int(0)) },
            app = app.lifecycle,
        )
        assertRect(0, 0, 300, 30, "stray")
        assertRect(0, 30, 300, 70, "row")
        assertRect(0, 70, 300, 110, "only")
        assertEquals(1, model.int("inits"), "the stray child's onInit")

        compose.runOnUiThread { app.registry.handleLifecycleEvent(Lifecycle.Event.ON_STOP) }
        compose.waitForIdle()

        assertEquals(1, model.int("stops"), "the stray child's onAppBackground")
        assertEquals(2, model.int("rowStops"), "the row's and the adapter child's onAppBackground")
    }

    /** C-fallback-K: the first bar of a reversed view does not collapse: a box at the far end, scrolling with the rest. */
    @Test
    fun c_fallback_k_theBarOfAReversedViewIsABox() {
        val rows = ids("r", 40)
        sliverPage(
            300.dp, 400.dp,
            scroll("s", listOf("bar", "l"), mapOf("reverse" to true)),
            bar("bar", mapOf("pinned" to true, "expandedHeight" to 100)),
            sliverList("l", rows),
            *rows.map { sizedBox(it, height = 50) }.toTypedArray(),
        )
        assertEquals(DpRect(0.dp, 300.dp, 300.dp, 400.dp), bounds(sliverAppBarTag("bar")))
        assertRect(0, 250, 300, 300, "r0")
    }

    // ── The fixture ─────────────────────────────────────────────────────────

    /**
     * C-fix: render fixture 69 holds the five widgets with every wire prop.
     * Its `expected` nodes, with its page state, draw here whole: the bar
     * (pinned by state, title from state) over the vertical view, the
     * adapter's heading, and the horizontal strip.
     */
    @Test
    fun c_fix_fixture69DrawsWhole() {
        val file = generateSequence(File("").absoluteFile) { it.parentFile }
            .map { File(it, "schema/fixtures/render/69_custom_scroll_view_slivers.json") }
            .first { it.isFile }
        val fixture = Json.parseToJsonElement(file.readText()).jsonObject
        val nodes = fixture["expected"]!!.jsonArray.map { Json.decodeFromJsonElement(ComponentNode.serializer(), it) }
        assertEquals(
            setOf("CustomScrollView", "SliverAppBar", "SliverGrid", "SliverList", "SliverToBoxAdapter"),
            nodes.map { it.type }.filter { it.startsWith("Sliver") || it == "CustomScrollView" }.toSet(),
        )
        val state = JsonValue.parse(file.readText())["context"]["pageState"].objectValue!!
            .map { (key, value) -> StateDefinition(key, StateScope.Page, value) }
        val model = OrcaPageModel(PageResponse(pageId = "p", title = "P", state = state, components = nodes))
        model.builders = WidgetBuilders.standard()
        compose.setContent { Box(Modifier.size(300.dp, 400.dp)) { NodeView("page", model) } }
        compose.waitForIdle()

        compose.onAllNodes(hasScrollAction()).assertCountEquals(2)
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 200.dp), bounds(sliverAppBarTag("bar")))
        compose.onNodeWithText("Catalogue").assertIsDisplayed()
        compose.onNodeWithText("Featured").assertIsDisplayed()
        // The bar's own onInit ran.
        assertEquals(JsonValue.Bool(true), model.value("barReady"))
    }
}
