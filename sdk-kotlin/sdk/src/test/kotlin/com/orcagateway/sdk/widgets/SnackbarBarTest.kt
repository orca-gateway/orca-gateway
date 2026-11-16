package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.sp
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.TabDef
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.SnackbarQueue
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.OrcaSnackbarQueue
import com.orcagateway.sdk.OrcaToast
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.draw
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.navigation.tabTag
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowToast
import java.net.URI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A8.4, the bar: the head of the app's snackbar queue drawn as Flutter's
 * Material 3 fixed SnackBar (MUI snack_bar.dart) where its root
 * ScaffoldMessenger shows it: in the top page's root Scaffold, at the
 * content bottom above the bottom bar and footer, over the bottomSheet
 * slot, the floating button lifted over it (scaffold.dart `_ScaffoldLayout`
 * :1236-1352; floating_action_button_location.dart `FabFloatOffsetY`
 * :576-581); with tabs in the shell's, above the tab bar (orca_shell.dart).
 * Then the two entry points of the queue the bar drives: its reveal and
 * the swipe. At 1 dp per pixel, drawn in software for the colours, on the
 * test clock (a bar is in 250 ms after the first frame that sees it).
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w300dp-h400dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SnackbarBarTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View

    private val blue = Props.hex("#0000FF")
    private val red = Props.hex("#FF0000")

    /** Flutter's light inverseSurface, the M3 bar (color_scheme_defaults.g.dart, snackbar_defaults_m3.g.dart:18). */
    private val barColour = Props.hex("#322F35")

    /** The queue's one entry, a snackbar of [message] with the default 4000 ms. */
    private fun OrcaSnackbarQueue.snackbar(message: String) = show(OrcaToast.Style.Snackbar, message, null)

    // The queue's two entry points the bar drives.

    /**
     * A8.4: the queue's reveal (how far the head is in, linear in the time)
     * is Compose state, and a swipe takes the head away at once, whatever
     * its phase, and the next starts entering from nothing.
     */
    @Test
    fun a8_4_theQueuesRevealIsStateAndASwipeRemovesTheHeadAtOnce() {
        val queue = OrcaSnackbarQueue()
        queue.snackbar("First")
        queue.snackbar("Second")
        assertEquals(0.0, queue.reveal)

        queue.tick(1_000)
        queue.tick(1_125)
        assertEquals(0.5, queue.reveal)
        val reads = mutableListOf<Any>()
        Snapshot.observe(readObserver = { reads += it }) { queue.reveal }
        assertTrue(reads.isNotEmpty(), "reveal is read from a state object")

        queue.swipe()
        assertEquals("Second", queue.head?.message)
        assertEquals(SnackbarQueue.Phase.Entering, queue.phase)
        assertEquals(0.0, queue.reveal)
        queue.tick(1_225)
        assertEquals(0.4, queue.reveal)
    }

    /**
     * A8.4: a swipe that empties the queue stops its clock: the next show
     * starts entering on the first frame after it, not as far in as the
     * time the queue stood idle.
     */
    @Test
    fun a8_4_aSwipeThatEmptiesTheQueueDoesNotCountTheIdleTimeAsTheNextEntry() {
        val queue = OrcaSnackbarQueue()
        queue.snackbar("Only")
        queue.tick(1_000)
        queue.tick(1_100)
        queue.swipe()
        assertNull(queue.head)
        assertNull(queue.phase)
        assertEquals(0.0, queue.reveal)

        queue.snackbar("Next")
        queue.tick(1_300)
        assertEquals("Next", queue.head?.message)
        assertEquals(0.0, queue.reveal, "the clock starts again here")
        queue.tick(1_400)
        assertEquals(0.4, queue.reveal)
    }

    // The bar on a page.

    /**
     * A8.4: the bar is M3's fixed SnackBar: the whole width of the Scaffold,
     * square, on #322F35, at its bottom; the message in bodyMedium (14, line
     * 20) #F5EFF7, 24 in from the start, 14 above and below a short one's
     * one line (snack_bar.dart:29, :707-713, :793, :817-818). Its Material's
     * elevation 6 casts no shadow past it: Flutter clips the bar to its box
     * (:901, clipBehavior hardEdge :315). It is a live region whose dismiss
     * removes it, as Flutter's Semantics (:852-858).
     */
    @Test
    fun a8_4_theBarIsM3sFixedBarFullWidthSquareOnInverseSurfaceItsTextInBodyMedium() {
        val model = show(scaffold("page", mapOf("body" to "fill")), fill())
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(DpRect(0.dp, 352.dp, 300.dp, 400.dp), bounds(SNACKBAR_BAR_TAG))
        val text = compose.onNodeWithText("Hello").getUnclippedBoundsInRoot()
        assertEquals(24.dp, text.left)
        assertEquals(366.dp, text.top)
        assertEquals(386.dp, text.bottom)
        val style = style("Hello")
        assertEquals(Color(0xFFF5EFF7), style.color)
        assertEquals(14.sp, style.fontSize)
        assertEquals(20.sp, style.lineHeight)

        val picture = picture()
        for ((x, y) in listOf(0 to 352, 299 to 352, 0 to 399, 299 to 399, 12 to 376, 290 to 376)) {
            assertPixel(barColour, picture, x, y)
        }
        for ((x, y) in listOf(150 to 351, 150 to 348, 2 to 351)) assertPixel(blue, picture, x, y)

        val node = compose.onNodeWithTag(SNACKBAR_BAR_TAG).fetchSemanticsNode()
        assertEquals(LiveRegionMode.Polite, node.config[SemanticsProperties.LiveRegion])
        compose.onNodeWithTag(SNACKBAR_BAR_TAG).performSemanticsAction(SemanticsActions.Dismiss)
        assertNull(model.toast, "dismissed at once")
    }

    /**
     * A8.4: without a bottom bar or footer the bottom safe area is inside
     * the bar, under its text (snack_bar.dart:812): the bar reaches the
     * Scaffold's bottom edge and grows by the inset.
     */
    @Test
    fun a8_4_withoutABottomBarTheBottomSafeAreaIsInsideTheBar() {
        val model = show(scaffold("page", mapOf("body" to "fill")), fill())
        systemBars(bottom = 20)
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(DpRect(0.dp, 332.dp, 300.dp, 400.dp), bounds(SNACKBAR_BAR_TAG))
        assertEquals(346.dp, compose.onNodeWithText("Hello").getUnclippedBoundsInRoot().top)
        assertPixel(barColour, picture(), 150, 395)
    }

    /**
     * A8.4 over A8.2: with a bottom bar the bar stands on it, as high as its
     * line (the bar takes the safe area: scaffold.dart:3273-3283), and it
     * paints over the bottomSheet slot, which keeps its place
     * (scaffold.dart:3257, :3276, :3343).
     */
    @Test
    fun a8_4_theBarStandsOnTheBottomBarAndPaintsOverTheSheetSlot() {
        val model = show(
            scaffold("page", mapOf("body" to "fill", "bottomNavigationBar" to "bar", "bottomSheet" to "sheet")),
            fill(),
            container("bar", props("height" to 50, "color" to "#FF0000")),
            bottomSheet("sheet", "content"),
            sizedBox("content", 100, 100),
        )
        systemBars(bottom = 20)
        assertEquals(DpRect(84.dp, 218.dp, 216.dp, 350.dp), bounds("sheet"))
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(DpRect(0.dp, 302.dp, 300.dp, 350.dp), bounds(SNACKBAR_BAR_TAG))
        assertEquals(DpRect(84.dp, 218.dp, 216.dp, 350.dp), bounds("sheet"))
        val picture = picture()
        for ((x, y) in listOf(150 to 303, 150 to 349, 90 to 330, 2 to 330)) assertPixel(barColour, picture, x, y)
        assertPixel(Color.White, picture, 150, 290)
        assertPixel(red, picture, 150, 375)
    }

    /**
     * A8.4: the floating button rises until its bottom is 16 over the bar
     * (FabFloatOffsetY, floating_action_button_location.dart:576-581), and
     * comes back down when the bar has gone.
     */
    @Test
    fun a8_4_theFabRisesUntilItsBottomIs16OverTheBar() {
        val model = show(
            scaffold("page", mapOf("body" to "fill", "bottomNavigationBar" to "bar", "floatingActionButton" to "f")),
            fill(),
            container("bar", props("height" to 50, "color" to "#FF0000")),
            fab("f", "icon"),
            sizedBox("icon", 24, 24),
        )
        assertEquals(DpRect(228.dp, 278.dp, 284.dp, 334.dp), bounds("f"))
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(DpRect(0.dp, 302.dp, 300.dp, 350.dp), bounds(SNACKBAR_BAR_TAG))
        assertEquals(DpRect(228.dp, 230.dp, 284.dp, 286.dp), bounds("f"))

        compose.mainClock.advanceTimeBy(4_500)
        assertEquals(0, bars())
        assertEquals(DpRect(228.dp, 278.dp, 284.dp, 334.dp), bounds("f"))
    }

    /**
     * A8.4 with A8.2: the floating button takes the higher of the two lifts:
     * over a tall sheet its centre stays on the sheet's top edge, above
     * where the bar alone would put it (FabFloatOffsetY, the min of both).
     */
    @Test
    fun a8_4_overATallSheetTheFabTakesTheHigherOfTheTwoLifts() {
        val model = show(
            scaffold("page", mapOf("body" to "fill", "floatingActionButton" to "f", "bottomSheet" to "sheet")),
            fill(),
            fab("f", "icon"),
            sizedBox("icon", 24, 24),
            bottomSheet("sheet", "content"),
            sizedBox("content", 100, 100),
        )
        assertEquals(DpRect(228.dp, 240.dp, 284.dp, 296.dp), bounds("f"))
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(DpRect(0.dp, 352.dp, 300.dp, 400.dp), bounds(SNACKBAR_BAR_TAG))
        assertEquals(DpRect(228.dp, 240.dp, 284.dp, 296.dp), bounds("f"))
    }

    /**
     * A8.4: on its way in the bar is revealed by height, never faded: its
     * box is its height times fastOutSlowIn of the queue's reveal, from the
     * Scaffold's bottom up, the bar's top part shown and the rest cut off
     * below (snack_bar.dart:32, :596, :888-893, a top-start Align in a
     * ClipRect :901).
     */
    @Test
    fun a8_4_onItsWayInTheBarIsRevealedByHeightNotFaded() {
        val model = show(scaffold("page", mapOf("body" to "fill")), fill())
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(150)

        val reveal = model.snackbars.reveal
        assertTrue(reveal > 0.2 && reveal < 0.8, "halfway in: $reveal")
        assertEquals(SnackbarQueue.Phase.Entering, model.snackbars.phase)
        val bar = bounds(SNACKBAR_BAR_TAG)
        assertEquals(400.dp, bar.bottom)
        val expected = 48f * FastOutSlowInEasing.transform(reveal.toFloat())
        assertTrue(abs(bar.height.value - expected) <= 1f, "height ${bar.height} for $expected")
        assertEquals(bar.top + 14.dp, compose.onNodeWithText("Hello").getUnclippedBoundsInRoot().top)
        assertPixel(barColour, picture(), 150, ceil(bar.top.value).toInt() + 1)
    }

    /**
     * A8.4: a swipe down moves the bar's content with the finger inside the
     * bar, which stays where it is; let go short of 0.4 of its height it
     * comes back. Past that it slides off, the queue drops it at once with
     * no leave of its own, and the next comes in (Flutter's Dismissible,
     * dismissible.dart:19-22, :500-530; snack_bar.dart:859-871).
     */
    @Test
    fun a8_4_aSwipeDownSlidesTheBarThenTakesItAwayAndTheNextEnters() {
        val model = show(scaffold("page", mapOf("body" to "fill")), fill())
        snackbar(model, "First")
        snackbar(model, "Second")
        compose.mainClock.advanceTimeBy(400)
        assertEquals(366.dp, textTop("First"))

        compose.onNodeWithTag(SNACKBAR_BAR_TAG).performTouchInput {
            down(center)
            repeat(6) { moveBy(Offset(0f, 4f), delayMillis = 50) }
        }
        compose.mainClock.advanceTimeBy(32)
        val dragged = textTop("First")
        assertTrue(dragged > 366.dp && dragged < 386.dp, "moved with the finger: $dragged")
        assertEquals(DpRect(0.dp, 352.dp, 300.dp, 400.dp), bounds(SNACKBAR_BAR_TAG))
        compose.onNodeWithTag(SNACKBAR_BAR_TAG).performTouchInput { up() }
        compose.mainClock.advanceTimeBy(300)
        assertEquals(366.dp, textTop("First"))
        assertEquals("First", model.toast?.message)

        compose.onNodeWithTag(SNACKBAR_BAR_TAG).performTouchInput {
            swipeDown(startY = top + 2f, endY = bottom - 1f, durationMillis = 300)
        }
        compose.mainClock.advanceTimeBy(250)
        assertEquals(0, count("First"))
        assertEquals("Second", model.toast?.message)

        compose.mainClock.advanceTimeBy(400)
        assertEquals(DpRect(0.dp, 352.dp, 300.dp, 400.dp), bounds(SNACKBAR_BAR_TAG))
        assertEquals(366.dp, textTop("Second"))
    }

    /**
     * A8.4: a message too long for one line wraps, as Flutter's
     * `Text(message)` with no line limit (action_executor.dart:393-406), and
     * the bar grows with it, 14 above and below its lines.
     */
    @Test
    fun a8_4_aLongMessageWrapsAndTheBarGrowsWithIt() {
        val model = show(scaffold("page", mapOf("body" to "fill")), fill())
        snackbar(model, LONG)
        compose.mainClock.advanceTimeBy(400)

        val text = compose.onNodeWithText(LONG).getUnclippedBoundsInRoot()
        val bar = bounds(SNACKBAR_BAR_TAG)
        assertTrue(text.height >= 40.dp, "two lines or more: ${text.height}")
        assertEquals(0f, text.height.value % 20f, "whole lines of 20")
        assertTrue(text.right <= 276.dp, "inside the 24 at the end: ${text.right}")
        assertEquals(DpRect(0.dp, 400.dp - text.height - 28.dp, 300.dp, 400.dp), bar)
        assertEquals(bar.top + 14.dp, text.top)
    }

    /**
     * A8.4: a fling down of 700 dp/s or more takes the bar away even short
     * of 0.4 of its height (dismissible.dart:19, :482-490, :514-521); the
     * same distance dragged slowly brings it back (the swipe case).
     */
    @Test
    fun a8_4_aFlingDownTakesTheBarAwayShortOfTheThreshold() {
        val model = show(scaffold("page", mapOf("body" to "fill")), fill())
        snackbar(model, "First")
        snackbar(model, "Second")
        compose.mainClock.advanceTimeBy(400)

        // Past the touch slop (16 here) by 1, then 15 more in 15 ms: 16 dragged (a third of 48) at 1000 dp/s.
        compose.onNodeWithTag(SNACKBAR_BAR_TAG).performTouchInput {
            down(center)
            moveBy(Offset(0f, 17f))
            repeat(3) { moveBy(Offset(0f, 5f), delayMillis = 5) }
            up()
        }
        compose.mainClock.advanceTimeBy(250)
        assertEquals(0, count("First"))
        assertEquals("Second", model.toast?.message)
    }

    /**
     * A8.4: a toast at the head of the queue draws no bar: it is an Android
     * Toast on its turn (a known difference: Flutter's is a floating bar).
     */
    @Test
    fun a8_4_aToastAtTheHeadDrawsNoBar() {
        val model = show(scaffold("page", mapOf("body" to "fill")), fill())
        compose.mainClock.autoAdvance = false
        compose.runOnUiThread { model.snackbars.show(OrcaToast.Style.Toast, "Saved", null) }
        compose.mainClock.advanceTimeBy(400)

        assertEquals(OrcaToast.Style.Toast, model.toast?.style)
        assertEquals(0, bars())
        assertEquals("Saved", ShadowToast.getTextOfLatestToast())
    }

    /**
     * A8.4: a persistent footer row is a bottom bar too: the bar stands on
     * it (scaffold.dart:1173-1176, its bottomWidgetsHeight).
     */
    @Test
    fun a8_4_theBarStandsOnThePersistentFooter() {
        val model = show(
            scaffold("page", mapOf("body" to "fill", "persistentFooterButton_0" to "button")),
            fill(),
            sizedBox("button", 40, 40),
        )
        // The row: 8 around the 40 of its button.
        assertEquals(352.dp, bounds("button").top)
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(DpRect(0.dp, 296.dp, 300.dp, 344.dp), bounds(SNACKBAR_BAR_TAG))
    }

    /**
     * A8.4: a Scaffold in another Scaffold draws no second bar: the
     * messenger draws in root Scaffolds only (scaffold.dart:258-263).
     */
    @Test
    fun a8_4_aNestedScaffoldDrawsNoSecondBar() {
        val model = show(
            scaffold("page", mapOf("body" to "inner")),
            scaffold("inner", mapOf("body" to "fill")),
            fill(),
        )
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(1, bars())
        assertEquals(DpRect(0.dp, 352.dp, 300.dp, 400.dp), bounds(SNACKBAR_BAR_TAG))
    }

    /**
     * A8.4: a Scaffold that is not the page root, with none above it, is a
     * root Scaffold to Flutter's messenger and draws the bar
     * (scaffold.dart:258-263).
     */
    @Test
    fun a8_4_aScaffoldUnderAColumnRootDrawsTheBar() {
        val model = show(column("col", "page"), scaffold("page", mapOf("body" to "fill")), fill())
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(1, bars())
        assertEquals(DpRect(0.dp, 352.dp, 300.dp, 400.dp), bounds(SNACKBAR_BAR_TAG))
    }

    /**
     * A8.4: with the keyboard up the bar stands on it, Flutter's
     * contentBottom (scaffold.dart:1173-1176), and the safe area the
     * keyboard covers is not in the bar.
     */
    @Test
    fun a8_4_withTheKeyboardUpTheBarStandsOnIt() {
        val model = show(scaffold("page", mapOf("body" to "fill")), fill())
        systemBars(bottom = 20, keyboard = 200)
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(400)

        assertEquals(DpRect(0.dp, 152.dp, 300.dp, 200.dp), bounds(SNACKBAR_BAR_TAG))
    }

    /**
     * A8.4: with no Scaffold on screen no bar is drawn, and the snackbar is
     * timed all the same (Flutter in release, scaffold.dart:360-365).
     */
    @Test
    fun a8_4_withNoScaffoldNoBarIsDrawnButItIsTimed() {
        val model = show(column("col", "t"), text("t", "Plain"))
        snackbar(model, "Hello")
        compose.mainClock.advanceTimeBy(500)
        assertEquals(0, bars())
        assertEquals(0, count("Hello"))
        assertEquals("Hello", model.toast?.message)

        compose.mainClock.advanceTimeBy(4_500)
        assertNull(model.toast)
    }

    // The bar in a router.

    /**
     * A8.4: a pushed page's root Scaffold shows the same bar, its time still
     * running from the tap (Flutter: the pushed Scaffold registers with the
     * one messenger, snack_bar.dart:898), and it goes when it would have
     * gone on the first page.
     */
    @Test
    fun a8_4_aPushedPageShowsTheSameBarItsTimeStillRunning() {
        val router = OrcaRouter(Pages().client, path = "first")
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { count("Go") == 1 }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        val screen = compose.onRoot().getUnclippedBoundsInRoot()
        val bar = DpRect(0.dp, screen.bottom - 48.dp, screen.right, screen.bottom)

        compose.onNodeWithText("Go").performClick()
        compose.mainClock.advanceTimeBy(2_000)
        assertEquals(bar, bounds(SNACKBAR_BAR_TAG))

        compose.runOnUiThread { router.navigate("second") }
        compose.waitForIdle()
        compose.mainClock.advanceTimeBy(1_500)
        assertEquals("second", router.top.path)
        assertEquals(0, count("Go"), "the first page has left")
        compose.onNodeWithText("second page").assertIsDisplayed()
        assertEquals(bar, bounds(SNACKBAR_BAR_TAG))
        compose.onNodeWithText("Saved").assertIsDisplayed()

        // Counted from the tap: in by t + 266, out by t + 4516.
        compose.mainClock.advanceTimeBy(1_100)
        assertEquals(0, bars())
    }

    /**
     * A8.4: with tabs the shell draws the bar above its tab bar and a tab
     * page's Scaffold draws none (Flutter's page Scaffold is nested in
     * OrcaShell's, and the messenger draws in the root one only,
     * scaffold.dart:258-263; orca_shell.dart:114-117): one bar, on a page
     * with a Scaffold and on one without.
     */
    @Test
    fun a8_4_withTabsTheShellDrawsTheBarAboveTheTabBar() {
        val router = OrcaRouter(Pages().client, tabs)
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { count("Go") == 1 }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false

        compose.onNodeWithText("Go").performClick()
        compose.mainClock.advanceTimeBy(400)
        assertEquals(1, compose.onAllNodes(hasTestTag(SNACKBAR_BAR_TAG)).fetchSemanticsNodes().size)
        val bar = bounds(SNACKBAR_BAR_TAG)
        assertEquals(bounds(tabTag(0)).top, bar.bottom)
        assertEquals(48.dp, bar.height)
        assertEquals(0.dp, bar.left)

        compose.onNodeWithTag(tabTag(1)).performClick()
        compose.mainClock.advanceTimeBy(500)
        compose.waitUntil(5_000) { count("plain page") == 1 }
        compose.mainClock.advanceTimeBy(100)
        assertEquals(1, compose.onAllNodes(hasTestTag(SNACKBAR_BAR_TAG)).fetchSemanticsNodes().size)
        assertEquals(bar, bounds(SNACKBAR_BAR_TAG))
    }

    /**
     * A8.4: a route over the tab shell with a title is wrapped in Flutter's
     * title-bar Scaffold (navigation_handler.dart:111-147, :372): the bar
     * is at its bottom edge even when the page has no Scaffold, and it is
     * the only one (the shell is covered).
     */
    @Test
    fun a8_4_aTitledRouteOverTheShellShowsTheBarAtItsBottomEdge() {
        val router = OrcaRouter(Pages().client, tabs)
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { count("Go") == 1 }
        compose.runOnUiThread { router.navigate("/settings") }
        compose.waitUntil(5_000) { count("Go now") == 1 }
        compose.waitForIdle()
        assertEquals("Settings", router.top.scaffoldTitle)
        compose.mainClock.autoAdvance = false
        val screen = compose.onRoot().getUnclippedBoundsInRoot()

        compose.onNodeWithText("Go now").performClick()
        compose.mainClock.advanceTimeBy(400)
        assertEquals(1, bars())
        assertEquals(DpRect(0.dp, screen.bottom - 48.dp, screen.right, screen.bottom), bounds(SNACKBAR_BAR_TAG))
    }

    /**
     * A8.4: a titled route the app starts on (a tabbed config's
     * `initialRoute` outside every tab) is drawn on the single stack, the
     * shell not mounted, and Flutter wraps it in its title-bar Scaffold all
     * the same (navigation_handler.dart:111-147, :372): the bar is at the
     * bottom edge with the inset inside, though its page is a Column.
     */
    @Test
    fun a8_4_aTitledRouteTheAppStartsOnShowsTheBarAtTheEdge() {
        val router = OrcaRouter(Pages().client, tabs.copy(initialRoute = "/settings"))
        compose.setContent {
            view = LocalView.current
            OrcaApp(router)
        }
        compose.waitUntil(5_000) { count("Go now") == 1 }
        assertEquals("Settings", router.root.scaffoldTitle)
        assertEquals(0, compose.onAllNodes(hasTestTag(tabTag(0))).fetchSemanticsNodes().size, "no tab bar")
        systemBars(bottom = 20)
        compose.mainClock.autoAdvance = false
        val screen = compose.onRoot().getUnclippedBoundsInRoot()

        compose.onNodeWithText("Go now").performClick()
        compose.mainClock.advanceTimeBy(400)
        assertEquals(1, bars())
        assertEquals(DpRect(0.dp, screen.bottom - 68.dp, screen.right, screen.bottom), bounds(SNACKBAR_BAR_TAG))
        assertEquals(screen.bottom - 54.dp, textTop("Saved"))
    }

    // Helpers.

    /** The page from [nodes] under OrcaPageView in a 300 x 400 box; the BottomSheet known, nodes tagged with their ids. */
    private fun show(vararg nodes: ComponentNode): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("BottomSheet"))
        val standard = WidgetBuilders.standard()
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("BottomSheet") { node, model, modifier -> BottomSheetWidget(node, model, modifier.testTag(node.id)) }
                for (type in listOf("Container", "SizedBox", "FloatingActionButton")) {
                    val drawn = requireNotNull(standard[type])
                    register(type) { node, model, modifier -> drawn(node, model, modifier.testTag(node.id)) }
                }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(300.dp, 400.dp)) { OrcaPageView(model) }
        }
        compose.waitForIdle()
        return model
    }

    /** A snackbar of [message] joins the page's queue; from here the test clock moves only when told. */
    private fun snackbar(model: OrcaPageModel, message: String) {
        compose.mainClock.autoAdvance = false
        compose.runOnUiThread { model.snackbars.snackbar(message) }
    }

    /** The device's system bars and keyboard, in pixels (dp at mdpi), delivered as the platform does (FlowTest's harness). */
    private fun systemBars(bottom: Int, keyboard: Int = 0) {
        val insets = WindowInsetsCompat.Builder()
            .setInsets(WindowInsetsCompat.Type.systemBars(), Insets.of(0, 0, 0, bottom))
            .setInsets(WindowInsetsCompat.Type.ime(), Insets.of(0, 0, 0, keyboard))
            .setVisible(WindowInsetsCompat.Type.ime(), keyboard > 0)
            .build()
        compose.runOnIdle { ViewCompat.dispatchApplyWindowInsets(view, insets) }
        compose.waitForIdle()
    }

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    private fun container(id: String, props: Map<String, JsonValue> = emptyMap()) =
        ComponentNode(id, "Container", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props)

    /** The body: a blue Container filling it. */
    private fun fill() = container("fill", props("color" to "#0000FF"))

    private fun bottomSheet(id: String, child: String) =
        ComponentNode(id, "BottomSheet", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, children = listOf(child))

    private fun fab(id: String, child: String) =
        ComponentNode(id, "FloatingActionButton", ComponentNode.Kind.Button, ComponentNode.ChildMode.Single, children = listOf(child))

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    private fun textTop(text: String): Dp = compose.onNodeWithText(text).getUnclippedBoundsInRoot().top

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    private fun bars(): Int = compose.onAllNodes(hasTestTag(SNACKBAR_BAR_TAG)).fetchSemanticsNodes().size

    private fun style(text: String): TextStyle {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithText(text).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single().layoutInput.style
    }

    private fun picture(): Bitmap {
        compose.waitForIdle()
        return draw(view)
    }

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int, tolerance: Float = 0.03f) {
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

    private companion object {
        /** A Scaffold, its slot props holding the ids of nodes listed as its children. */
        fun scaffold(id: String, slots: Map<String, String>) = ComponentNode(
            id, "Scaffold", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
            slots.mapValues { JsonValue.String(it.value) }, slots.values.toList(),
        )

        /** A message longer than a line of the 300 wide bar. */
        const val LONG = "Your changes were saved, and the copy on the server is up to date again"

        /** Two tabs, `/home` (a Scaffold firing the snackbar) and `/plain` (no Scaffold), and `/settings` beside them. */
        val tabs = NavConfig(
            initialRoute = "/home",
            tabs = listOf(TabDef("home", "Home", "home", "/home"), TabDef("plain", "Plain", "search", "/plain")),
            flows = listOf(
                NavFlow(name = "main", routes = listOf(NavRoute("home"), NavRoute("plain"), NavRoute("settings"))),
            ),
        )
    }

    /**
     * Pages `first` and `home`: a Scaffold whose button "Go" shows the
     * snackbar "Saved"; `second`: a Scaffold with "second page"; `plain`: a
     * Column with "plain page", no Scaffold; `settings`: a Column whose
     * button "Go now" shows "Saved", no Scaffold.
     */
    private class Pages : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse {
            val name = request.url.path.substringAfterLast("/page/")
            val nodes = when (name) {
                "first", "home" -> listOf(
                    scaffold("s", mapOf("body" to "b")),
                    button("b", "ElevatedButton", "g", mapOf("onTap" to Action.ShowSnackbar(message = JsonValue.String("Saved")))),
                    text("g", "Go"),
                )
                "plain" -> listOf(column("c", "t"), text("t", "plain page"))
                "settings" -> listOf(
                    column("c", "b"),
                    button("b", "ElevatedButton", "g", mapOf("onTap" to Action.ShowSnackbar(message = JsonValue.String("Saved")))),
                    text("g", "Go now"),
                )
                else -> listOf(scaffold("s", mapOf("body" to "t")), text("t", "$name page"))
            }
            val page = PageResponse(pageId = name, title = name, components = nodes)
            return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
        }

        val client: OrcaClient
            get() = OrcaClient(URI("http://stub.invalid"), appId = "app", device = DeviceInfo(osVersion = "test"), transport = this)
    }
}
