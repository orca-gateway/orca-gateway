package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.LocalOverscrollFactory
import androidx.compose.foundation.OverscrollEffect
import androidx.compose.foundation.OverscrollFactory
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasProgressBarRangeInfo
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import kotlinx.coroutines.CompletableDeferred
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
 * A5.5 on Android: Flutter's PullToRefresh (layout_builders.dart:372-393),
 * a RefreshIndicator that runs onRefresh when a drag begun at the top of
 * the vertical scroll view inside it pulls far enough, and keeps its
 * spinner until the action ends (refresh_indicator.dart:461-475, :634-639).
 * onRefresh is RefetchPage, run by a handler that counts the runs and
 * waits for [hold]. A 200 x 300 box at 1 dp per pixel; the touch slop (16)
 * is not scrolled, and Compose's indicator travels half the finger's
 * distance, so a drag of d past the top pulls (d - 16) / 2 against
 * Compose's threshold of 80.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class RefreshTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View
    private var refreshes = 0
    private val hold = CompletableDeferred<Unit>()

    private val spinner = hasProgressBarRangeInfo(ProgressBarRangeInfo.Indeterminate)

    /**
     * The page from [nodes], its root in a 200 x 300 box; PullToRefresh and
     * ListView known to the core and drawn here, they and SizedBoxes tagged
     * with their ids; the scroll views' overscroll from [overscroll] when
     * given.
     */
    private fun show(vararg nodes: ComponentNode, overscroll: OverscrollFactory? = null): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("PullToRefresh", "ListView"))
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("PullToRefresh") { node, model, modifier -> PullToRefreshWidget(node, model, modifier.testTag(node.id)) }
                register("ListView") { node, model, modifier -> ListViewWidget(node, model, modifier.testTag(node.id)) }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
            }
            executor.registerHandler(
                "refetchPage",
                OrcaActionHandler { _, _ ->
                    refreshes += 1
                    hold.await()
                },
            )
        }
        compose.setContent {
            view = LocalView.current
            CompositionLocalProvider(LocalOverscrollFactory provides (overscroll ?: LocalOverscrollFactory.current)) {
                Box(Modifier.size(200.dp, 300.dp), propagateMinConstraints = true) { NodeView(nodes.first().id, model) }
            }
        }
        compose.waitForIdle()
        return model
    }

    private fun refresh(id: String, child: String, vararg props: Pair<String, Any?>) = ComponentNode(
        id, "PullToRefresh", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        props.associate { (key, value) -> key to JsonValue.of(value) }, listOf(child),
        actions = mapOf("onRefresh" to Action.RefetchPage),
    )

    private fun list(id: String, children: List<String>, vararg props: Pair<String, Any?>) = ComponentNode(
        id, "ListView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi,
        props.associate { (key, value) -> key to JsonValue.of(value) }, children,
    )

    private fun ids(prefix: String, count: Int = 10) = List(count) { "$prefix$it" }

    /** Rows [prefix]0 ... [prefix]<count - 1>, each [width] x [height] (null: the list forces it). */
    private fun rows(prefix: String, count: Int = 10, width: Int? = null, height: Int? = null) =
        Array(count) { sizedBox("$prefix$it", width, height) }

    /** A drag on [tag] from [from] to [to] over 300 ms, let go there. */
    private fun swipe(tag: String, from: Offset, to: Offset) {
        compose.onNodeWithTag(tag).performTouchInput { swipe(start = from, end = to, durationMillis = 300) }
        compose.waitForIdle()
    }

    /** A drag down the whole height of [tag] (290: a pull of 137). */
    private fun pullDown(tag: String) = swipe(tag, Offset(100f, 5f), Offset(100f, 295f))

    /** Scroll the only scroll view down by [by] (the semantics action, animated like a user's). */
    private fun scrollBy(by: Float) {
        compose.onNode(hasScrollAction()).performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, by) }
        compose.waitForIdle()
    }

    /** An overscroll effect that draws nothing and keeps the y of what each drag's scroll left over for it. */
    private class LeftOver : OverscrollEffect {
        val left = ArrayList<Float>()

        override fun applyToScroll(delta: Offset, source: NestedScrollSource, performScroll: (Offset) -> Offset): Offset {
            val consumed = performScroll(delta)
            if (source == NestedScrollSource.UserInput) left += delta.y - consumed.y
            return consumed
        }

        override suspend fun applyToFling(velocity: Velocity, performFling: suspend (Velocity) -> Velocity) {
            performFling(velocity)
        }

        override val isInProgress: Boolean get() = false
    }

    private data class Overscrolls(val effect: LeftOver) : OverscrollFactory {
        override fun createOverscrollEffect(): OverscrollEffect = effect
    }

    /**
     * A5.5 (kt ui): a pull from the top of the list runs onRefresh once, and
     * the spinner shows until the action has ended.
     */
    @Test
    fun a5_5_kt_aPullAtTheTopRunsOnRefreshAndTheSpinnerWaitsForTheAction() {
        show(refresh("ptr", "l"), list("l", ids("r")), *rows("r", height = 50))

        pullDown("l")

        assertEquals(1, refreshes, "onRefresh ran")
        compose.onNode(spinner).assertExists("spinning while the action runs")
        compose.mainClock.advanceTimeBy(5_000)
        compose.onNode(spinner).assertExists("still spinning 5 s later, the action not done")

        hold.complete(Unit)
        compose.waitForIdle()

        compose.onNode(spinner).assertDoesNotExist()
        assertEquals(1, refreshes, "run once")
    }

    /**
     * A5.5 (kt ui): a drag that begins below the top runs nothing, even when
     * it scrolls the list back to the top and on far past the threshold
     * (Flutter's onEdge: only a drag that starts at the edge).
     */
    @Test
    fun a5_5_kt_aPullBegunAwayFromTheTopDoesNothing() {
        show(refresh("ptr", "l"), list("l", ids("r")), *rows("r", height = 50))
        scrollBy(40f)
        assertEquals(-40f, compose.onNodeWithTag("r0").getUnclippedBoundsInRoot().top.value, "scrolled 40 down")

        pullDown("l")

        assertEquals(0f, compose.onNodeWithTag("r0").getUnclippedBoundsInRoot().top.value, "back at the top")
        assertEquals(0, refreshes, "onRefresh did not run")
        compose.onNode(spinner).assertDoesNotExist()
    }

    /**
     * A5.5 (kt ui): after a refresh, a drag begun below the top still runs
     * nothing: what the last drag decided is gone when a finger goes down.
     */
    @Test
    fun a5_5_kt_afterARefreshAPullBegunAwayFromTheTopDoesNothing() {
        show(refresh("ptr", "l"), list("l", ids("r")), *rows("r", height = 50))
        pullDown("l")
        assertEquals(1, refreshes, "the first pull refreshed")
        hold.complete(Unit)
        compose.waitForIdle()
        compose.onNode(spinner).assertDoesNotExist()

        scrollBy(40f)
        pullDown("l")

        assertEquals(0f, compose.onNodeWithTag("r0").getUnclippedBoundsInRoot().top.value, "back at the top")
        assertEquals(1, refreshes, "no second refresh")
    }

    /**
     * A5.5 (kt ui): a drag begun at the top that first scrolls the list up,
     * then comes back down past the top, refreshes: it began at the edge
     * (Flutter's drag offset counts the trip up and back).
     */
    @Test
    fun a5_5_kt_aPullBegunAtTheTopThatGoesUpFirstStillRefreshes() {
        show(refresh("ptr", "l"), list("l", ids("r")), *rows("r", height = 50))

        compose.onNodeWithTag("l").performTouchInput {
            down(Offset(100f, 100f))
            repeat(4) { moveBy(Offset(0f, -10f)) }
            repeat(12) { moveBy(Offset(0f, 236f / 12)) }
            up()
        }
        compose.waitForIdle()

        assertEquals(1, refreshes, "onRefresh ran")
    }

    /**
     * A5.5 (kt ui): a drag up at the bottom of the list still leaves its
     * excess to the list's overscroll (Android's stretch): only a pull
     * down is kept from a drag begun below the top.
     */
    @Test
    fun a5_5_kt_theListStillOverscrollsAtItsBottom() {
        val overscroll = LeftOver()
        show(refresh("ptr", "l"), list("l", ids("r")), *rows("r", height = 50), overscroll = Overscrolls(overscroll))
        scrollBy(1_000f)
        assertEquals(250f, compose.onNodeWithTag("r9").getUnclippedBoundsInRoot().top.value, "at the bottom")

        swipe("l", Offset(100f, 250f), Offset(100f, 50f))

        assertTrue(overscroll.left.sum() < -100f, "left over for the list's overscroll: ${overscroll.left.sum()}")
        assertEquals(0, refreshes)
    }

    /** A5.5 (kt ui): a horizontal list never starts it, neither by a pull down nor by a drag across and down. */
    @Test
    fun a5_5_kt_aHorizontalListDoesNotRefresh() {
        show(refresh("ptr", "l"), list("l", ids("c"), "scrollDirection" to "horizontal"), *rows("c", width = 50))

        pullDown("l")
        swipe("l", Offset(190f, 5f), Offset(10f, 295f))

        assertTrue(compose.onNodeWithTag("c4").getUnclippedBoundsInRoot().left.value < 100f, "the drag across scrolled the list (c4 was at 200)")
        assertEquals(0, refreshes, "onRefresh did not run")
        compose.onNode(spinner).assertDoesNotExist()
    }

    /**
     * A5.5 (kt ui), q9: a vertical list nested in the one PullToRefresh
     * wraps also starts it when both are at their top: Compose hands what
     * the inner list leaves to the outer one and then to the indicator,
     * where Flutter's RefreshIndicator hears only depth 0. Documented.
     */
    @Test
    fun a5_5_kt_q9_aVerticalListNestedInTheWrappedOneAlsoStartsIt() {
        show(
            refresh("ptr", "outer"),
            list("outer", listOf("frame", "tall")),
            ComponentNode(
                "frame", "SizedBox", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                mapOf("height" to JsonValue.Int(150)), listOf("inner"),
            ),
            list("inner", ids("r")),
            *rows("r", height = 50),
            sizedBox("tall", height = 400),
        )

        pullDown("inner")

        assertEquals(1, refreshes, "the nested list started the refresh")
    }

    /**
     * A5.5 (kt ui): while refreshing, the indicator's circle rests 4 below
     * `displacement` (Flutter's RefreshProgressIndicator margin), centred,
     * in `backgroundColor`, its arc in `color`.
     */
    @Test
    fun a5_5_kt_theSpinnerRestsAtDisplacementInThePropsColours() {
        show(
            refresh("ptr", "l", "displacement" to 60, "color" to "#FF0000", "backgroundColor" to "#0000FF"),
            list("l", ids("r")),
            *rows("r", height = 50),
        )

        pullDown("l")

        val bounds = compose.onNode(spinner).getUnclippedBoundsInRoot()
        assertEquals(100f, (bounds.left.value + bounds.right.value) / 2, 0.5f, "centred across")
        assertEquals(84f, (bounds.top.value + bounds.bottom.value) / 2, 0.5f, "circle 60 + 4 to 60 + 44")
        val picture = draw()
        assertPixel(Props.hex("#0000FF"), 100, 68, "the circle's background, above the arc", picture)
        val arc = (bounds.left.value.toInt()..bounds.right.value.toInt()).any { x ->
            (bounds.top.value.toInt()..bounds.bottom.value.toInt()).any { y -> close(Props.hex("#FF0000"), picture.getPixel(x, y)) }
        }
        assertTrue(arc, "a pixel of the arc in color")
        hold.complete(Unit)
    }

    /** The view drawn in software on white, as GoldenTest draws it. */
    private fun draw(): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun close(expected: Color, actual: Int): Boolean = listOf(
        expected.red to android.graphics.Color.red(actual) / 255f,
        expected.green to android.graphics.Color.green(actual) / 255f,
        expected.blue to android.graphics.Color.blue(actual) / 255f,
    ).all { (want, got) -> abs(want - got) < 0.05f }

    private fun assertPixel(expected: Color, x: Int, y: Int, label: String, picture: Bitmap) {
        val actual = picture.getPixel(x, y)
        assertTrue(close(expected, actual), "$label: ($x, $y) is #${Integer.toHexString(actual)}, expected $expected")
    }
}
