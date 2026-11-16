package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.PageSnap
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.sizedBox
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A5.4 on Android: Flutter's PageView as `_buildPageView` makes it
 * (layout_builders.dart:668-684): horizontal unless `scrollDirection` is
 * vertical, `pageSnapping` true, `reverse` false, each page the viewport's
 * size, only the visible pages built (cache 0, page_view.dart:723), and
 * onScrollBegin / onScrolling / onScrollEnd with the offset and
 * viewportDimension (wrapScrollNotifier, builder_helpers.dart:46-71). A
 * snapping release settles where the core's [PageSnap] says, a free one
 * where its momentum stops. A 200 x 200 view at 1 dp per pixel; the touch
 * slop (16 here) is not scrolled, so a drag of d moves the pages d - 16.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class PagerTest {
    @get:Rule
    val compose = createComposeRule()

    /** The page from [nodes], its root drawn in a 200 x 200 box; PageView known to the core and drawn here. */
    private fun show(vararg nodes: ComponentNode): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("PageView"))
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("PageView") { node, model, modifier -> PageViewWidget(node, model, modifier.testTag(node.id)) }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
                register("SingleChildScrollView") { node, model, modifier -> ScrollWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            Box(Modifier.size(200.dp, 200.dp), propagateMinConstraints = true) { NodeView(nodes.first().id, model) }
        }
        compose.waitForIdle()
        return model
    }

    private fun pageView(
        id: String,
        vararg pages: String,
        props: Map<String, Any?> = emptyMap(),
        actions: Map<String, Action> = emptyMap(),
    ) = ComponentNode(
        id, "PageView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi,
        props.mapValues { JsonValue.of(it.value) }, pages.toList(), actions = actions,
    )

    /** Pages p0 ... p<count - 1>, each a SizedBox of 50 x 50 the page forces to its size. */
    private fun pages(count: Int): Array<ComponentNode> = Array(count) { sizedBox("p$it", 50, 50) }

    private fun ids(count: Int): Array<String> = Array(count) { "p$it" }

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
        "onScrollBegin" to Action.ActionGroup(mode = "sequential", actions = listOf(count("begins"), write("beginOffset" to "offset"))),
        "onScrolling" to write("offset" to "offset"),
        "onScrollEnd" to Action.ActionGroup(
            mode = "sequential",
            actions = listOf(count("ends"), write("endOffset" to "offset", "viewport" to "viewportDimension", "maxExtent" to "maxExtent")),
        ),
    )

    private fun OrcaPageModel.value(key: String): JsonValue? = store.state.page[key]

    private fun OrcaPageModel.number(key: String): Double = requireNotNull(value(key)?.doubleValue) { "$key is ${value(key)}" }

    /** A drag from [from] to [to] at a steady speed over [millis], let go there. */
    private fun swipe(from: Offset, to: Offset, millis: Long) {
        compose.onRoot().performTouchInput { swipe(start = from, end = to, durationMillis = millis) }
        compose.waitForIdle()
    }

    /** A drag [by] pixels to the left (negative: to the right) across the middle. */
    private fun swipeLeft(by: Float, millis: Long) =
        swipe(Offset(if (by > 0) 196f else 4f, 100f), Offset(if (by > 0) 196f - by else 4f - by, 100f), millis)

    private fun swipeUp(by: Float, millis: Long) = swipe(Offset(100f, 196f), Offset(100f, 196f - by), millis)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun assertRect(left: Int, top: Int, right: Int, bottom: Int, tag: String) {
        assertEquals(DpRect(left.dp, top.dp, right.dp, bottom.dp), bounds(tag), tag)
    }

    /** A5.4 (kt ui): page 0 fills the view, whatever its child asks, and the next page is not built. */
    @Test
    fun a5_4_kt_eachPageIsTheViewportsSizeAndOnlyTheVisibleOneIsBuilt() {
        show(pageView("pv", *ids(3)), *pages(3))
        assertRect(0, 0, 200, 200, "pv")
        assertRect(0, 0, 200, 200, "p0")
        compose.onNodeWithTag("p1").assertDoesNotExist()
        compose.onNodeWithTag("p2").assertDoesNotExist()
    }

    /**
     * A5.4 (kt ui): a slow swipe (about 40 a second, no fling) settles on
     * the nearest page: 64 of 200 goes back to page 0, 114 on to page 1.
     */
    @Test
    fun a5_4_kt_aSlowSwipeSettlesOnTheNearestPage() {
        show(pageView("pv", *ids(3)), *pages(3))
        swipeLeft(80f, millis = 2000)
        assertRect(0, 0, 200, 200, "p0")

        swipeLeft(130f, millis = 3000)
        assertRect(0, 0, 200, 200, "p1")
        compose.onNodeWithTag("p0").assertDoesNotExist()
    }

    /**
     * A5.4 (kt ui): a fast fling of almost a whole page moves one page, not
     * two (page 2 is not on screen; Compose's prefetch may have composed
     * it), and a short quick one moves one page too.
     */
    @Test
    fun a5_4_kt_aFastFlingMovesOnePage() {
        show(pageView("pv", *ids(3)), *pages(3))
        swipeLeft(190f, millis = 40)
        assertRect(0, 0, 200, 200, "p1")
        compose.onNodeWithTag("p2").assertIsNotDisplayed()

        swipeLeft(40f, millis = 60)
        assertRect(0, 0, 200, 200, "p2")
    }

    /**
     * A5.4 (kt ui): a release at 240 a second after 44 of 200 is a fling
     * for Flutter (past 50 a second) and for the core, so it goes on to
     * page 1; Compose's own pager (PagerDefaults.flingBehavior) goes back
     * to page 0 (its fling threshold is 400 dp a second, its positional
     * one 56 dp).
     */
    @Test
    fun a5_4_kt_aMediumReleaseSettlesWherePageSnapSays() {
        show(pageView("pv", *ids(3)), *pages(3))
        val expected = PageSnap.target(offset = 44.0, viewportExtent = 200.0, velocity = 240.0, travel = 24.0, pageCount = 3)
        assertEquals(1, expected)

        swipeLeft(60f, millis = 250)

        assertRect(0, 0, 200, 200, "p$expected")
    }

    /**
     * A5.4 (kt ui): a steady release at 120 a second, past the minimum
     * velocity but only 12 of travel in its last 100 ms (under kTouchSlop,
     * 18), is no fling for Flutter: 44 of 200 settles on the nearest page,
     * page 0.
     */
    @Test
    fun a5_4_kt_aSteadyReleaseWithLittleTravelSettlesOnTheNearestPage() {
        show(pageView("pv", *ids(3)), *pages(3))
        assertEquals(0, PageSnap.target(offset = 44.0, viewportExtent = 200.0, velocity = 120.0, travel = 12.0, pageCount = 3))

        swipeLeft(60f, millis = 500)

        assertRect(0, 0, 200, 200, "p0")
    }

    /**
     * A5.4 (kt ui): with pageSnapping false a slow drag stays where it is
     * let go (44 of 200), and a fast fling runs on past the next page.
     */
    @Test
    fun a5_4_kt_withPageSnappingOffAFlingGoesFurther() {
        val model = show(pageView("pv", *ids(5), props = mapOf("pageSnapping" to false), actions = triggers), *pages(5))
        assertRect(0, 0, 200, 200, "p0")

        swipeLeft(60f, millis = 2000)
        val stopped = model.number("endOffset")
        assertTrue(stopped > 40.0 && stopped < 60.0, "a slow free drag stops where let go: $stopped")
        assertEquals(800.0, model.number("maxExtent"))

        swipeLeft(150f, millis = 30)
        val flung = model.number("endOffset")
        assertTrue(flung > stopped + 200.0, "a free fling runs past the next page: $flung")
    }

    /** A5.4 (kt ui): a vertical PageView pages upward, each page the view's size. */
    @Test
    fun a5_4_kt_aVerticalPageViewPagesUpward() {
        show(pageView("pv", *ids(3), props = mapOf("scrollDirection" to "vertical")), *pages(3))
        assertRect(0, 0, 200, 200, "p0")

        swipeLeft(190f, millis = 40)
        assertRect(0, 0, 200, 200, "p0")

        swipeUp(190f, millis = 40)
        assertRect(0, 0, 200, 200, "p1")
    }

    /**
     * A5.4 (kt ui): reversed, page 1 lies to the left of page 0: a swipe to
     * the left does nothing, one to the right brings page 1.
     */
    @Test
    fun a5_4_kt_aReversedPageViewHasTheNextPageOnTheOtherSide() {
        show(pageView("pv", *ids(3), props = mapOf("reverse" to true)), *pages(3))
        swipeLeft(190f, millis = 40)
        assertRect(0, 0, 200, 200, "p0")

        swipeLeft(-190f, millis = 40)
        assertRect(0, 0, 200, 200, "p1")
    }

    /**
     * A5.4 (kt ui): onScrollBegin reports where the scroll started, and
     * onScrollEnd the page times the viewport's extent, with the viewport
     * and the last page's offset as maxExtent.
     */
    @Test
    fun a5_4_kt_onScrollEndReportsThePageTimesTheViewport() {
        val model = show(pageView("pv", *ids(3), actions = triggers), *pages(3))
        assertEquals(null, model.value("begins"))

        swipeLeft(190f, millis = 40)
        assertEquals(JsonValue.Int(1), model.value("begins"))
        assertEquals(JsonValue.Double(0.0), model.value("beginOffset"))
        assertEquals(JsonValue.Int(1), model.value("ends"))
        assertEquals(JsonValue.Double(200.0), model.value("endOffset"))
        assertEquals(JsonValue.Double(200.0), model.value("viewport"))
        assertEquals(JsonValue.Double(400.0), model.value("maxExtent"))

        swipeLeft(190f, millis = 40)
        assertEquals(JsonValue.Int(2), model.value("ends"))
        assertEquals(JsonValue.Double(400.0), model.value("endOffset"))
    }

    /**
     * A5.4 (kt ui): a horizontal PageView with no width limit (in a Row in
     * a horizontal scroll view) does not crash: it lays every page out at
     * its own size, one after another, and does not page. Flutter asserts
     * there.
     */
    @Test
    fun a5_4_kt_aPageViewWithNoLimitLaysOutEveryPage() {
        show(
            ComponentNode(
                "scroll", "SingleChildScrollView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                mapOf("scrollDirection" to JsonValue.String("horizontal")), listOf("row"),
            ),
            row("row", "pv"),
            pageView("pv", *ids(3)),
            *pages(3),
        )
        val top = bounds("p0").top
        for (index in 0..2) {
            val page = bounds("p$index")
            assertEquals(DpRect((50 * index).dp, top, (50 * index + 50).dp, top + 50.dp), page, "p$index")
        }
    }

    /**
     * A5.4 (kt ui): a vertical scroll view on a horizontal page still
     * scrolls up and down, the pages staying put, and a horizontal drag on
     * it still turns the page.
     */
    @Test
    fun a5_4_kt_aVerticalListInAHorizontalPageStillScrolls() {
        show(
            pageView("pv", "list", "p1"),
            ComponentNode(
                "list", "SingleChildScrollView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                emptyMap(), listOf("tall"),
            ),
            sizedBox("tall", 200, 600),
            sizedBox("p1", 50, 50),
        )
        swipeUp(150f, millis = 300)
        val top = bounds("tall").top
        assertTrue(top < (-100).dp, "the list scrolled up: its content's top is at $top")
        assertRect(0, 0, 200, 200, "list")

        swipeLeft(190f, millis = 40)
        compose.onNodeWithTag("p1").assertIsDisplayed()
        assertRect(0, 0, 200, 200, "p1")
    }
}
