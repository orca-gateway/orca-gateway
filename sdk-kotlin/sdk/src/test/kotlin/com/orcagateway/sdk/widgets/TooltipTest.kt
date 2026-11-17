package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
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
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.models.TabDef
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.draw
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.navigation.tabTag
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.net.URI
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A8.3: Flutter's Material Tooltip with its defaults (MUI tooltip.dart
 * :413-420, :450-538; widgets/raw_tooltip.dart), the bubble the SDK draws
 * itself (q2 a): a press held for 500 ms shows the message with a long-press
 * haptic, it stays while held and goes 1.5 s after the release or at any
 * other touch, fading in over 150 ms and out over 75; grey[700] at 0.9,
 * radius 4, white 14 on 20, padding 16 x 4, at least 32 high; centred on
 * the child 24 below its centre, above it when it does not fit, 10 from the
 * edges (TooltipPlacement); in a window of its own that takes no touches.
 * The page is 300 x 400 at 1 dp per pixel, on the test clock; tooltips and
 * sized boxes are tagged with their ids.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w300dp-h400dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TooltipTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private lateinit var view: View

    /** The haptics the page asked for, in order. */
    private val haptics = mutableListOf<HapticFeedbackType>()

    private val recorder = object : HapticFeedback {
        override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) {
            haptics += hapticFeedbackType
        }
    }

    /**
     * A8.3: a press shorter than 500 ms shows nothing; held 500 ms (Flutter's
     * kLongPressTimeout, the Tooltip's long-press trigger, tooltip.dart:420)
     * the bubble shows the message, with one long-press haptic
     * (Feedback.forLongPress: HapticFeedbackConstants.LONG_PRESS on Android).
     */
    @Test
    fun a8_3_aPressHeld500msShowsTheMessageWithOneLongPressHaptic() {
        show(*at(100, 50))
        compose.onNodeWithTag("tip").performTouchInput { click() }
        compose.mainClock.advanceTimeBy(2000)
        assertEquals(0, bubbles(), "a tap")

        hold("tip", 450)
        assertEquals(0, bubbles(), "450 ms")
        assertEquals(emptyList(), haptics)
        compose.mainClock.advanceTimeBy(100)

        assertEquals(1, bubbles(), "550 ms")
        assertEquals(1, compose.onAllNodes(bubbleText("Hello")).fetchSemanticsNodes().size)
        assertEquals(listOf(HapticFeedbackType.LongPress), haptics)
    }

    /**
     * A8.3: the bubble stays as long as the press is held, and goes 1.5 s
     * after the release (the Tooltip's showDuration, tooltip.dart:416,
     * raw_tooltip.dart:762-767), fading out over 75 ms.
     */
    @Test
    fun a8_3_theBubbleStaysWhileHeldAndGoes1500msAfterTheRelease() {
        show(*at(100, 50))
        hold("tip", 600)
        compose.mainClock.advanceTimeBy(3000)
        assertEquals(1, bubbles(), "held 3.6 s")

        release("tip")
        compose.mainClock.advanceTimeBy(1450)
        assertEquals(1, bubbles(), "1450 ms after the release")
        compose.mainClock.advanceTimeBy(200)
        assertEquals(0, bubbles(), "1650 ms after the release")
    }

    /**
     * A8.3: the bubble's top is 24 below the child's centre, the bubble
     * centred on it (positionDependentBox, geometry.dart:42-68, about the
     * child's centre, raw_tooltip.dart:881-884), one line at its least
     * height of 32 (tooltip.dart:450-456).
     */
    @Test
    fun a8_3_theBubbleIsCentredOnTheChild24BelowItsCentre() {
        show(*at(100, 50))
        hold("tip", 600)

        assertEquals(DpRect(100.dp, 50.dp, 140.dp, 90.dp), bounds("box"))
        val bubble = bubble()
        assertEquals(94.dp, bubble.top)
        assertEquals(32.dp, bubble.bottom - bubble.top)
        assertTrue(abs((bubble.left + bubble.right).value / 2 - 120f) <= 0.5f, "centred on 120: $bubble")
    }

    /** A8.3: near the bottom, where it does not fit below, it goes above: its bottom 24 above the centre. */
    @Test
    fun a8_3_nearTheBottomTheBubbleGoesAboveTheChild() {
        show(*at(100, 350))
        hold("tip", 600)

        val bubble = bubble()
        assertEquals(314.dp, bubble.top)
        assertEquals(346.dp, bubble.bottom)
    }

    /** A8.3: by a side the bubble is held 10 from the edge (geometry.dart:62-66). */
    @Test
    fun a8_3_byASideTheBubbleIsHeld10FromTheEdge() {
        show(
            column("root", "line"),
            row("line", "left", "gap", "right"),
            tooltip("left", "Hello", "a"),
            sizedBox("a", 40, 40),
            sizedBox("gap", width = 220),
            tooltip("right", "Hello", "b"),
            sizedBox("b", 40, 40),
        )
        hold("left", 600)
        assertEquals(10.dp, bubble().left)
        release("left")
        compose.mainClock.advanceTimeBy(1700)
        assertEquals(0, bubbles())

        hold("right", 600)
        assertEquals(DpRect(260.dp, 0.dp, 300.dp, 40.dp), bounds("b"))
        assertEquals(290.dp, bubble().right)
    }

    /**
     * A8.3: the overlay the bubble is placed in ends at the keyboard's top
     * (raw_tooltip.dart:896-897): a bubble that fits below a child at 300
     * on the bare page goes above it with a keyboard of 100 up.
     */
    @Test
    fun a8_3_withTheKeyboardUpTheOverlayEndsAtItsTop() {
        show(*at(100, 280))
        hold("tip", 600)
        assertEquals(324.dp, bubble().top, "below: 300 + 24")

        keyboard(100)
        assertEquals(244.dp, bubble().top, "above: 300 - 24 - 32")
    }

    /**
     * A8.3: under tabs the bubble is placed in the tab's Navigator, Flutter's
     * nearest Overlay (raw_tooltip.dart:965-969, overlay.dart:1941-1945;
     * navigation_handler.dart:92), which ends at the tab bar: a FAB just
     * above the tab bar, whose bubble would fit below it on the screen, gets
     * it above, its bottom 24 over the FAB's centre, never over the tab bar.
     */
    @Test
    fun a8_3_underTabsAFabsBubbleStaysInTheTabsAreaAboveIt() {
        showApp(TabPages(sheet = false), "f")
        hold("f", 600)

        val tabTop = bounds(tabTag(0)).top
        val fab = bounds("f")
        val bubble = bubble()
        assertTrue(abs((fab.top + fab.bottom).value / 2 - 24f - bubble.bottom.value) <= 1f, "above the FAB: $bubble, FAB $fab")
        assertTrue(bubble.bottom <= tabTop, "above the tab bar at $tabTop: $bubble")
    }

    /**
     * A8.3: a Tooltip in an open sheet under tabs is in the sheet's route,
     * on the same tab Navigator (orca_page.dart:346-349), so its bubble too
     * stays in the tab's area: one near the sheet's bottom, whose bubble
     * would fit below it on the screen, gets it above, never over the tab
     * bar.
     */
    @Test
    fun a8_3_underTabsATooltipInASheetKeepsItsBubbleInTheTabsArea() {
        showApp(TabPages(sheet = true), "open")
        compose.onNodeWithTag("open").performClick()
        compose.mainClock.advanceTimeBy(400)
        hold("tip", 600)

        val tabTop = bounds(tabTag(0)).top
        val tip = bounds("tip")
        assertTrue(tip.bottom <= tabTop && tip.bottom > tabTop - 20.dp, "near the sheet's bottom: $tip, tab bar at $tabTop")
        val bubble = bubble()
        assertTrue(abs((tip.top + tip.bottom).value / 2 - 24f - bubble.bottom.value) <= 1f, "above the child: $bubble, child $tip")
        assertTrue(bubble.bottom <= tabTop, "above the tab bar at $tabTop: $bubble")
    }

    /**
     * A8.3: the layer gives its route's area to the tooltips in it whether
     * its page has loaded or not, so a page coming in (a route's frame from
     * loading to loaded, a reload) keeps what the content remembered.
     */
    @Test
    fun a8_3_thePagesLayerKeepsItsContentAsThePageComesIn() {
        var model by mutableStateOf<OrcaPageModel?>(null)
        var made = 0
        compose.setContent {
            DialogLayer(model) {
                remember { made++ }
                BasicText("content")
            }
        }
        compose.runOnIdle { model = OrcaPageModel(page(text("t", "x"))) }
        compose.waitForIdle()

        assertEquals(1, made)
    }

    /**
     * A8.3: Flutter's light tooltip (tooltip.dart:524-538): grey[700] at 0.9
     * (0xE6616161), corners cut round at 4, the message in bodyMedium in
     * white at 14 on a 20 line with 0.25 tracking (typography_defaults_m3
     * .g.dart:142-151), 16 in from each side and centred in the 32.
     */
    @Test
    fun a8_3_theBubbleIsGrey700At09Radius4WithTheMessageWhite14Padded16() {
        show(*at(100, 50))
        hold("tip", 800)

        val bubble = bubble()
        val width = (bubble.right - bubble.left).value.toInt()
        val message = compose.onNode(bubbleText("Hello")).getUnclippedBoundsInRoot()
        assertEquals(DpRect(16.dp, 6.dp, (width - 16).dp, 26.dp), message)
        val style = style("Hello")
        assertEquals(Color.White, style.color)
        assertEquals(14.sp, style.fontSize)
        assertEquals(20.sp, style.lineHeight)
        assertEquals(0.25.sp, style.letterSpacing)

        val picture = picture()
        assertEquals(width to 32, picture.width to picture.height)
        assertPixel(Color.White, picture, 0, 0)
        for ((x, y) in listOf(2 to 2, 8 to 16, width - 8 to 16, width / 2 to 2, width / 2 to 30)) assertPixel(fill, picture, x, y)
        assertTrue((0 until 32).any { y -> (16 until width - 16).any { x -> bright(picture.getPixel(x, y)) } }, "white ink in the message")
        assertTrue((4 until 28).none { y -> (4 until 15).any { x -> bright(picture.getPixel(x, y)) } }, "no ink in the padding")
    }

    /**
     * A8.3: it fades in over 150 ms and out over 75 (raw_tooltip.dart:27-31):
     * part way 64 ms in, whole by 202; part way 64 ms into the leave, gone
     * by 136 (a 150 ms leave would still show). Each picture takes a frame.
     */
    @Test
    fun a8_3_theBubbleFadesIn150AndOut75() {
        show(*at(100, 50))
        hold("tip", 548)
        assertTrue(partial(picture().getPixel(8, 16)), "64 ms in")
        compose.mainClock.advanceTimeBy(122)
        assertPixel(fill, picture(), 8, 16)

        release("tip")
        compose.mainClock.advanceTimeBy(1548)
        assertTrue(partial(picture().getPixel(8, 16)), "64 ms out")
        compose.mainClock.advanceTimeBy(72)
        assertEquals(0, bubbles(), "136 ms out")
    }

    /** A8.3: an empty message draws the child alone (tooltip.dart:503-505): no label, no bubble on a hold. */
    @Test
    fun a8_3_anEmptyMessageDrawsTheChildAloneAndNoBubble() {
        show(*at(100, 50, message = ""))

        // The child is the Tooltip's node: one node carries both tags.
        val child = compose.onNode(hasTestTag("tip") or hasTestTag("box"))
        assertEquals(DpRect(100.dp, 50.dp, 140.dp, 90.dp), child.getUnclippedBoundsInRoot())
        assertEquals(0, compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.ContentDescription)).fetchSemanticsNodes().size)
        child.performTouchInput { down(center) }
        compose.mainClock.advanceTimeBy(600)
        assertEquals(0, bubbles())
        assertEquals(emptyList(), haptics)
    }

    /**
     * A8.3: the bubble takes no touches (Material's Tooltip ignores the
     * pointer over its message, tooltip.dart:579-580): its window is neither
     * touchable nor focusable, so a touch on it reaches what is under it, and
     * it offers no action. A touch anywhere else hides it at once (RawTooltip's
     * global pointer route, raw_tooltip.dart:706-734): the platform tells the
     * window it was touched outside.
     */
    @Test
    fun a8_3_theBubbleTakesNoTouchesAndAnyOtherTouchHidesIt() {
        show(*at(100, 50))
        hold("tip", 600)
        release("tip")
        val window = bubbleWindow()
        val flags = (window.layoutParams as WindowManager.LayoutParams).flags
        assertTrue(flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE != 0, "not touchable")
        assertTrue(flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE != 0, "not focusable")
        assertTrue(flags and WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH != 0, "watches touches outside")
        compose.onNode(hasTestTag(TOOLTIP_BUBBLE_TAG)).assert(SemanticsMatcher.keyNotDefined(SemanticsActions.OnClick))

        touchOutside()
        compose.mainClock.advanceTimeBy(120)
        assertEquals(0, bubbles())
    }

    /**
     * A8.3: a new press on the child itself is the Tooltip's own long press,
     * not another touch (raw_tooltip.dart:706-724): the bubble stays while
     * it is held; let go short of 500 ms it hides at once (the long press
     * cancelled, :687, :728-734). Held 500 ms it stays with no second
     * haptic (the bubble was not gone, :753-757), and goes 1.5 s after that
     * release.
     */
    @Test
    fun a8_3_aNewPressOnTheChildIsTheTooltipsOwn() {
        show(*at(100, 50))
        hold("tip", 600)
        release("tip")
        compose.mainClock.advanceTimeBy(500)

        press("tip")
        touchOutside()
        compose.mainClock.advanceTimeBy(100)
        assertEquals(1, bubbles(), "held 100 ms")
        release("tip")
        compose.mainClock.advanceTimeBy(100)
        assertEquals(0, bubbles(), "let go short")

        hold("tip", 600)
        release("tip")
        compose.mainClock.advanceTimeBy(1000)
        press("tip")
        touchOutside()
        compose.mainClock.advanceTimeBy(600)
        assertEquals(1, bubbles(), "held again")
        assertEquals(2, haptics.size, "one haptic per bubble shown from nothing")
        release("tip")
        compose.mainClock.advanceTimeBy(1400)
        assertEquals(1, bubbles(), "1400 ms after the last release")
        compose.mainClock.advanceTimeBy(250)
        assertEquals(0, bubbles())
    }

    /**
     * A8.3: a hold on a child that only taps is the Tooltip's: the bubble
     * shows and the tap does not fire (the Tooltip's long press wins the
     * gesture arena from the child's tap); a short tap still fires.
     */
    @Test
    fun a8_3_aHoldOnATappableChildShowsTheBubbleAndFiresNoTap() {
        val model = show(
            column("root", "tip"),
            tooltip("tip", "Hello", "g"),
            ComponentNode(
                "g", "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                children = listOf("box"), actions = mapOf("onTap" to Action.SetState(key = "taps", value = JsonValue.Int(1))),
            ),
            sizedBox("box", 40, 40),
            state = listOf(StateDefinition("taps", StateScope.Page, JsonValue.Int(0))),
        )
        hold("tip", 600)
        release("tip")
        compose.mainClock.advanceTimeBy(100)
        assertEquals(1, bubbles())
        assertEquals(0, taps(model))

        compose.onNodeWithTag("tip").performTouchInput { click() }
        compose.mainClock.advanceTimeBy(400)
        assertEquals(1, taps(model))
    }

    /**
     * A8.3: the message is the Tooltip's accessibility label: Flutter's
     * Semantics(tooltip:) (raw_tooltip.dart:949-952), which its Android
     * bridge gives TalkBack as the node's content description where it has
     * no label of its own (and its tooltip text, which Compose has no
     * property for: BaseRoleConfigurator.java:360-378). The child keeps its
     * own semantics.
     */
    @Test
    fun a8_3_theMessageIsTheTooltipsAccessibilityLabel() {
        show(column("root", "tip"), tooltip("tip", "Hello", "t"), text("t", "Hi"))

        compose.onNodeWithTag("tip").assert(SemanticsMatcher.expectValue(SemanticsProperties.ContentDescription, listOf("Hello")))
        assertEquals(1, compose.onAllNodes(hasText("Hi")).fetchSemanticsNodes().size)
    }

    // The page.

    private fun tooltip(id: String, message: String, child: String) = ComponentNode(
        id, "Tooltip", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        mapOf("message" to JsonValue.String(message)), listOf(child),
    )

    /** A Tooltip `tip` over a 40 x 40 box `box` at ([x], [y]) on the page. */
    private fun at(x: Int, y: Int, message: String = "Hello"): Array<ComponentNode> = arrayOf(
        column("root", "gap", "line", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
        sizedBox("gap", height = y),
        row("line", "lead", "tip"),
        sizedBox("lead", width = x),
        tooltip("tip", message, "box"),
        sizedBox("box", 40, 40),
    )

    /** The page from [nodes] in the 300 x 400 window, Tooltip known to the core and drawn; then the clock moves only when told. */
    private fun show(vararg nodes: ComponentNode, state: List<StateDefinition> = emptyList()): OrcaPageModel {
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry)
        model.builders = WidgetBuilders.standard().apply {
            register("Tooltip") { node, page, modifier -> TooltipWidget(node, page, modifier.testTag(node.id)) }
            register("SizedBox") { node, page, modifier -> SizedBoxWidget(node, page, modifier.testTag(node.id)) }
        }
        compose.setContent {
            view = LocalView.current
            CompositionLocalProvider(LocalHapticFeedback provides recorder) {
                Box(Modifier.size(300.dp, 400.dp)) { NodeView(nodes.first().id, model) }
            }
        }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        return model
    }

    private fun press(tag: String) = compose.onNodeWithTag(tag).performTouchInput { down(center) }

    /** [pages] under OrcaApp with tabs, Tooltip and Dialog known to them and these tagged, until [tag] is on screen. */
    private fun showApp(pages: TabPages, tag: String) {
        val router = OrcaRouter(pages.client, tabs)
        compose.setContent {
            view = LocalView.current
            OrcaApp(
                router,
                widgets = WidgetBuilders.standard().apply {
                    register("FloatingActionButton") { node, page, modifier ->
                        FloatingActionButtonWidget(node, page, modifier.testTag(node.id))
                    }
                    register("ElevatedButton") { node, page, modifier -> ButtonWidget(node, page, modifier.testTag(node.id)) }
                    register("Tooltip") { node, page, modifier -> TooltipWidget(node, page, modifier.testTag(node.id)) }
                    register("Dialog") { node, _, modifier -> DialogWidget(modifier.testTag(node.id)) }
                    register("SizedBox") { node, page, modifier -> SizedBoxWidget(node, page, modifier.testTag(node.id)) }
                },
            )
        }
        compose.waitUntil(5_000) { compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().isNotEmpty() }
        compose.mainClock.autoAdvance = false
    }

    /** A finger down on [tag]'s centre, held [millis]. */
    private fun hold(tag: String, millis: Long) {
        press(tag)
        compose.mainClock.advanceTimeBy(millis)
    }

    private fun release(tag: String) = compose.onNodeWithTag(tag).performTouchInput { up() }

    /** A touch elsewhere, as the platform reports it to the bubble's window (FLAG_WATCH_OUTSIDE_TOUCH). */
    private fun touchOutside() {
        val window = bubbleWindow()
        compose.runOnUiThread {
            val event = MotionEvent.obtain(0L, 0L, MotionEvent.ACTION_OUTSIDE, 0f, 0f, 0)
            window.dispatchTouchEvent(event)
            event.recycle()
        }
    }

    /** The keyboard up, [height] pixels (dp at mdpi), delivered as the platform does (DialogTest's harness). */
    private fun keyboard(height: Int) {
        val insets = WindowInsetsCompat.Builder()
            .setInsets(WindowInsetsCompat.Type.ime(), Insets.of(0, 0, 0, height))
            .setVisible(WindowInsetsCompat.Type.ime(), true)
            .build()
        compose.runOnUiThread { ViewCompat.dispatchApplyWindowInsets(view, insets) }
        compose.mainClock.advanceTimeBy(32)
    }

    private fun taps(model: OrcaPageModel): Int? = model.store.value("taps").doubleValue?.toInt()

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    /** The bubbles on screen. */
    private fun bubbles(): Int = compose.onAllNodes(hasTestTag(TOOLTIP_BUBBLE_TAG)).fetchSemanticsNodes().size

    private fun bubbleText(message: String) = hasText(message) and hasAnyAncestor(hasTestTag(TOOLTIP_BUBBLE_TAG))

    /** The bubble's window: Compose's PopupLayout, as the window manager holds it. */
    private fun bubbleWindow(): View {
        val global = Class.forName("android.view.WindowManagerGlobal")
        val instance = global.getMethod("getInstance").invoke(null)
        val views = global.getDeclaredField("mViews").apply { isAccessible = true }.get(instance) as List<*>
        return views.filterIsInstance<View>().single { it.javaClass.simpleName == "PopupLayout" }
    }

    /** The bubble in the page's coordinates: its window's place less the page's place in the window, and its size. */
    private fun bubble(): DpRect {
        val params = bubbleWindow().layoutParams as WindowManager.LayoutParams
        val page = IntArray(2).also { view.getLocationInWindow(it) }
        val size = compose.onNode(hasTestTag(TOOLTIP_BUBBLE_TAG)).getUnclippedBoundsInRoot()
        val left = (params.x - page[0]).dp
        val top = (params.y - page[1]).dp
        return DpRect(left, top, left + (size.right - size.left), top + (size.bottom - size.top))
    }

    /**
     * The bubble's window drawn over white, a frame after it is laid out:
     * Compose's Popup draws nothing until it knows where it goes.
     */
    private fun picture(): Bitmap {
        compose.waitForIdle()
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        return draw(bubbleWindow())
    }

    private fun style(message: String): TextStyle {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNode(bubbleText(message)).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single().layoutInput.style
    }

    /** grey[700] at 0.9 over the white the capture starts from. */
    private val fill = Color(0xE6616161).let { c ->
        Color(red = c.red * c.alpha + 1f - c.alpha, green = c.green * c.alpha + 1f - c.alpha, blue = c.blue * c.alpha + 1f - c.alpha)
    }

    /** Lighter than the bubble by far: the white message. */
    private fun bright(pixel: Int): Boolean = android.graphics.Color.red(pixel) > 200

    /** Between nothing and the whole bubble: part way through a fade. */
    private fun partial(pixel: Int): Boolean = android.graphics.Color.red(pixel) in (fill.red * 255).toInt() + 12..243

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(channels.all { (want, got) -> abs(want - got) < 0.03f }, "($x, $y) is #${Integer.toHexString(actual)}, expected $expected")
    }

    private companion object {
        /** The core knows Tooltip (standard() takes it in K-caps). */
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("Tooltip"))

        /** Tabs `/home` and `/other`. */
        val tabs = NavConfig(
            initialRoute = "/home",
            tabs = listOf(TabDef("home", "Home", "home", "/home"), TabDef("other", "Other", "search", "/other")),
            flows = listOf(NavFlow(name = "main", routes = listOf(NavRoute("home"), NavRoute("other")))),
        )
    }

    /**
     * Each page a Scaffold whose FAB `f` has the tooltip "Compose"; with
     * [sheet], a button `open` opening the Dialog `d` instead, whose child
     * puts a Tooltip `tip` over a 40 x 40 box 110 down.
     */
    private class TabPages(private val sheet: Boolean) : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse {
            val name = request.url.path.substringAfterLast("/page/")
            val nodes = if (sheet) {
                listOf(
                    column("c", "open", "d"),
                    ComponentNode(
                        "open", "ElevatedButton", ComponentNode.Kind.Button, ComponentNode.ChildMode.Single,
                        children = listOf("ot"), actions = mapOf("onTap" to Action.OpenDialog("d")),
                    ),
                    text("ot", "Open"),
                    ComponentNode("d", "Dialog", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, children = listOf("dc")),
                    column("dc", "gap", "tip", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
                    sizedBox("gap", height = 110),
                    ComponentNode(
                        "tip", "Tooltip", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                        mapOf("message" to JsonValue.String("Hello")), listOf("box"),
                    ),
                    sizedBox("box", 40, 40),
                )
            } else {
                listOf(
                ComponentNode(
                    "s", "Scaffold", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
                    mapOf("body" to JsonValue.String("t"), "floatingActionButton" to JsonValue.String("f")), listOf("t", "f"),
                ),
                text("t", "$name page"),
                ComponentNode(
                    "f", "FloatingActionButton", ComponentNode.Kind.Button, ComponentNode.ChildMode.Single,
                    mapOf("tooltip" to JsonValue.String("Compose")), listOf("i"),
                ),
                ComponentNode("i", "Icon", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None),
                )
            }
            val page = PageResponse(pageId = name, title = name, components = nodes)
            return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
        }

        val client: OrcaClient
            get() = OrcaClient(URI("http://stub.invalid"), appId = "app", device = DeviceInfo(osVersion = "test"), transport = this)
    }
}
