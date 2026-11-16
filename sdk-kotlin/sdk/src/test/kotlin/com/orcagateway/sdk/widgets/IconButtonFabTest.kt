package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material.ripple.RippleAlpha
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.RippleConfiguration
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
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
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
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
 * A6.5 and A6.7 for IconButton and FloatingActionButton, as Flutter's
 * `_buildIconButton` and `_buildFAB` (button_builders.dart) draw them:
 * IconButton in Flutter's own (size + 16) box, firing only when enabled and
 * given a handler; the FAB Material 3's, live whenever enabled, with a long
 * press through its wrapper, and placed by the Scaffold at its bottom end.
 * Each trigger counts its fires in a page state key; nodes are tagged with
 * their ids. At 1 dp per pixel, drawn in software for the colours.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class IconButtonFabTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View

    /** The ripple configuration each SizedBox (here a FAB's child) last saw, by node id. */
    private val ripples = mutableMapOf<String, RippleConfiguration?>()

    /** The counters every test may read. */
    private val keys = listOf("onTap", "onLongPress", "outer")

    /** `setState(key, key + 1)`, as the counter page's increment. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    /** A button of [type] around [child], each trigger in [on] counting itself. */
    private fun tapButton(type: String, id: String, child: String?, vararg props: Pair<String, Any?>, on: List<String>) =
        ComponentNode(
            id, type, ComponentNode.Kind.Button, ComponentNode.ChildMode.Single, props(*props), listOfNotNull(child),
            actions = on.associateWith { count(it) },
        )

    private fun iconButton(id: String, child: String?, vararg props: Pair<String, Any?>, on: List<String> = emptyList()) =
        tapButton("IconButton", id, child, *props, on = on)

    private fun fab(id: String, child: String?, vararg props: Pair<String, Any?>, on: List<String> = emptyList()) =
        tapButton("FloatingActionButton", id, child, *props, on = on)

    /** An Icon with no name: Flutter's filled circle, solid at its centre. */
    private fun icon(id: String, vararg props: Pair<String, Any?>) = leaf(id, "Icon", props(*props))

    /** A GestureDetector around [child] counting its taps in `outer`. */
    private fun outer(id: String, child: String) = ComponentNode(
        id, "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        children = listOf(child), actions = mapOf("onTap" to count("outer")),
    )

    /** A Scaffold, its slots props holding the ids of nodes listed as its children. */
    private fun scaffold(id: String, slots: Map<String, String>) = ComponentNode(
        id, "Scaffold", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
        slots.mapValues { JsonValue.String(it.value) }, slots.values.toList(),
    )

    private fun start(id: String, vararg children: String) =
        column(id, *children, props = mapOf("crossAxisAlignment" to JsonValue.String("start")))

    /**
     * The page from [nodes], its root in a 300 x 400 box; IconButton and
     * FloatingActionButton known to the core and drawn here, they, Icons,
     * GestureDetectors and SizedBoxes tagged with their ids (and each
     * SizedBox's ripple configuration kept in [ripples]). With
     * [longPressTimeout] the page's surroundings take that long-press
     * timeout instead of the runner's.
     */
    private fun show(vararg nodes: ComponentNode, longPressTimeout: Long? = null): OrcaPageModel {
        val types = setOf("IconButton", "FloatingActionButton", "GestureDetector")
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + types)
        val state = keys.map { StateDefinition(it, StateScope.Page, JsonValue.Int(0)) }
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("IconButton") { node, model, modifier -> IconButtonWidget(node, model, modifier.testTag(node.id)) }
                register("FloatingActionButton") { node, model, modifier ->
                    FloatingActionButtonWidget(node, model, modifier.testTag(node.id))
                }
                register("Icon") { node, model, modifier -> IconWidget(node, model, modifier.testTag(node.id)) }
                register("GestureDetector") { node, model, modifier ->
                    GestureDetectorWidget(node, model, modifier.testTag(node.id))
                }
                register("SizedBox") { node, model, modifier ->
                    ripples[node.id] = LocalRippleConfiguration.current
                    SizedBoxWidget(node, model, modifier.testTag(node.id))
                }
            }
        }
        compose.setContent {
            view = LocalView.current
            val runner = LocalViewConfiguration.current
            val timing = longPressTimeout?.let { timeout ->
                object : ViewConfiguration by runner {
                    override val longPressTimeoutMillis: Long get() = timeout
                }
            } ?: runner
            CompositionLocalProvider(LocalViewConfiguration provides timing) {
                Box(Modifier.size(300.dp, 400.dp)) { NodeView(nodes.first().id, model) }
            }
        }
        compose.waitForIdle()
        return model
    }

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    /** Where [inner] sits in [outer], and its size: (left, top, width, height). */
    private fun placed(inner: String, outer: String): List<Int> {
        val box = bounds(outer)
        val child = bounds(inner)
        return listOf(child.left - box.left, child.top - box.top, child.right - child.left, child.bottom - child.top)
            .map { it.value.toInt() }
    }

    private fun size(tag: String): Pair<Int, Int> = bounds(tag).let {
        (it.right - it.left).value.toInt() to (it.bottom - it.top).value.toInt()
    }

    /** How many times each counter fired. */
    private fun fired(model: OrcaPageModel): Map<String, Int> {
        compose.waitForIdle()
        return keys.associateWith { model.store.value(it).doubleValue?.toInt() ?: -1 }
    }

    private fun counts(tap: Int = 0, longPress: Int = 0, outer: Int = 0): Map<String, Int> =
        mapOf("onTap" to tap, "onLongPress" to longPress, "outer" to outer)

    private val click = SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick)
    private val noClick = SemanticsMatcher.keyNotDefined(SemanticsActions.OnClick)
    private val noLongClick = SemanticsMatcher.keyNotDefined(SemanticsActions.OnLongClick)

    private fun picture(): Bitmap {
        compose.waitForIdle()
        return draw(view)
    }

    /** The pixels of the [side] square at [left], [top] in [picture], row by row. */
    private fun region(picture: Bitmap, left: Int, top: Int, side: Int): List<Int> =
        IntArray(side * side).also { picture.getPixels(it, 0, side, left, top, side, side) }.toList()

    /** The pixel [dx], [dy] into the node tagged [tag], in [picture]. */
    private fun assertPixel(expected: Color, picture: Bitmap, tag: String, dx: Int, dy: Int) {
        val box = bounds(tag)
        val actual = picture.getPixel(box.left.value.toInt() + dx, box.top.value.toInt() + dy)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.05f },
            "$tag ($dx, $dy) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }

    private val red = Props.hex("#E53935")
    private val blue = Props.hex("#1E88E5")

    /** Material 3's light primaryContainer and onPrimaryContainer, ThemeData()'s FAB colours. */
    private val fabFill = Props.hex("#EADDFF")
    private val fabContent = Props.hex("#4F378B")

    // A6.5 IconButton.

    /**
     * A6.5: a tap fires onTap; a long press fires onLongPress and not onTap.
     * Both are offered to accessibility.
     */
    @Test
    fun a6_5_kt_anIconButtonFiresOnTapAndOnLongPress() {
        val model = show(
            start("root", "b"),
            iconButton("b", "i", on = listOf("onTap", "onLongPress")),
            icon("i"),
        )
        compose.onNodeWithTag("b").assert(click)
        compose.onNodeWithTag("b").assert(SemanticsMatcher.keyIsDefined(SemanticsActions.OnLongClick))

        compose.onNodeWithTag("b").performClick()
        assertEquals(counts(tap = 1), fired(model))

        compose.onNodeWithTag("b").performTouchInput { longClick() }
        assertEquals(counts(tap = 1, longPress = 1), fired(model))
    }

    /**
     * A6.5: the box is (size + 16) square, `size` 24 by default, the child
     * centred; an Icon child keeps its own size, so `size` grows only the
     * box. With `padding` the child is aligned by `alignment` inside it;
     * `constraints` are outside the box, and its minimum wins over it.
     */
    @Test
    fun a6_5_kt_anIconButtonIsASizePlus16BoxWithItsChildCentred() {
        show(
            start("root", "plain", "big", "padded", "constrained", "empty"),
            iconButton("plain", "i1", on = listOf("onTap")),
            iconButton("big", "i2", "size" to 32, on = listOf("onTap")),
            iconButton(
                "padded", "i3", "padding" to mapOf("top" to 2, "right" to 0, "bottom" to 0, "left" to 3),
                "alignment" to "topLeft", on = listOf("onTap"),
            ),
            iconButton("constrained", "i4", "constraints" to mapOf("minWidth" to 56, "minHeight" to 56), on = listOf("onTap")),
            iconButton("empty", null, "size" to 10),
            icon("i1"),
            icon("i2"),
            icon("i3"),
            icon("i4"),
        )

        assertEquals(40 to 40, size("plain"))
        assertEquals(listOf(8, 8, 24, 24), placed("i1", "plain"))
        assertEquals(48 to 48, size("big"))
        assertEquals(listOf(12, 12, 24, 24), placed("i2", "big"))
        assertEquals(40 to 40, size("padded"))
        assertEquals(listOf(3, 2, 24, 24), placed("i3", "padded"))
        assertEquals(56 to 56, size("constrained"))
        assertEquals(listOf(16, 16, 24, 24), placed("i4", "constrained"))
        assertEquals(26 to 26, size("empty"))
    }

    /**
     * A6.5: `color` tints the child's icon (Flutter's IconTheme) only when
     * set; an Icon's own colour wins over it, and without it the child is
     * drawn as it is anywhere else.
     */
    @Test
    fun a6_5_kt_colorTintsTheChildOnlyWhenSet() {
        show(
            start("root", "tinted", "own", "untinted", "bare"),
            iconButton("tinted", "i1", "color" to "#E53935", on = listOf("onTap")),
            iconButton("own", "i2", "color" to "#E53935", on = listOf("onTap")),
            iconButton("untinted", "i3", on = listOf("onTap")),
            icon("i1"),
            icon("i2", "color" to "#1E88E5"),
            icon("i3"),
            icon("bare"),
        )
        val picture = picture()
        val bare = picture.getPixel(bounds("bare").left.value.toInt() + 12, bounds("bare").top.value.toInt() + 12)

        assertPixel(red, picture, "i1", 12, 12)
        assertPixel(blue, picture, "i2", 12, 12)
        assertPixel(Color(bare), picture, "i3", 12, 12)
        assertPixel(Color.White, picture, "tinted", 2, 2)
    }

    /**
     * A6.5: `tooltip` is the button's accessibility label (the repo draws no
     * tooltip yet, step 8); an empty one is none, as Flutter adds no Tooltip
     * for it.
     */
    @Test
    fun a6_5_kt_theTooltipIsTheAccessibilityLabel() {
        show(
            start("root", "b", "silent", "f"),
            iconButton("b", "i1", "tooltip" to "Add", on = listOf("onTap")),
            iconButton("silent", "i2", "tooltip" to "", on = listOf("onTap")),
            fab("f", "i3", "tooltip" to "Compose"),
            icon("i1"),
            icon("i2"),
            icon("i3"),
        )

        compose.onNodeWithTag("b").assert(SemanticsMatcher.expectValue(SemanticsProperties.ContentDescription, listOf("Add")))
        compose.onNodeWithTag("silent").assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.ContentDescription))
        compose.onNodeWithTag("f").assert(SemanticsMatcher.expectValue(SemanticsProperties.ContentDescription, listOf("Compose")))
    }

    // A6.5 FloatingActionButton.

    /**
     * A6.5: a tap fires onTap and a long press onLongPress (Flutter's
     * GestureDetector around the FAB). The wrapper takes every long press
     * while enabled, so a long press on a FAB without onLongPress fires
     * nothing, not onTap.
     */
    @Test
    fun a6_5_kt_aFabFiresOnTapAndOnLongPress() {
        val model = show(
            start("root", "both", "tapOnly"),
            fab("both", "i1", on = listOf("onTap", "onLongPress")),
            fab("tapOnly", "i2", on = listOf("onTap")),
            icon("i1"),
            icon("i2"),
        )
        compose.onNodeWithTag("both").assert(SemanticsMatcher.keyIsDefined(SemanticsActions.OnLongClick))

        compose.onNodeWithTag("both").performClick()
        assertEquals(counts(tap = 1), fired(model))
        compose.onNodeWithTag("both").performTouchInput { longClick() }
        assertEquals(counts(tap = 1, longPress = 1), fired(model))

        compose.onNodeWithTag("tapOnly").performTouchInput { longClick() }
        assertEquals(counts(tap = 1, longPress = 1), fired(model))
    }

    /**
     * A6.5: Flutter's Material 3 FAB under ThemeData(): 56 square in
     * primaryContainer with its icon in onPrimaryContainer; `mini` is 40
     * drawn in the middle of a 48 tap target (the FAB's bounds are the 40);
     * `backgroundColor` is the fill.
     */
    @Test
    fun a6_5_kt_aFabIsMaterial3sRegularOrSmall() {
        show(
            start("root", "regular", "mini", "after"),
            fab("regular", "i1"),
            fab("mini", "i2", "mini" to true, "backgroundColor" to "#E53935"),
            sizedBox("after", 10, 10),
            icon("i1"),
            icon("i2"),
        )
        val picture = picture()

        assertEquals(DpRect(0.dp, 0.dp, 56.dp, 56.dp), bounds("regular"))
        assertEquals(listOf(16, 16, 24, 24), placed("i1", "regular"))
        assertPixel(fabFill, picture, "regular", 4, 28)
        assertPixel(fabContent, picture, "i1", 12, 12)
        // The corner radius 16: (3, 3) lies outside it, (5, 5) inside (12 or less would fill the first, 19 or more not the second).
        assertPixel(Color.White, picture, "regular", 3, 3)
        assertPixel(fabFill, picture, "regular", 5, 5)
        assertEquals(DpRect(4.dp, 60.dp, 44.dp, 100.dp), bounds("mini"))
        assertEquals(104.dp, bounds("after").top)
        assertEquals(listOf(8, 8, 24, 24), placed("i2", "mini"))
        assertPixel(Color.White, picture, "mini", -2, 20)
        assertPixel(red, picture, "mini", 3, 20)
        assertPixel(fabContent, picture, "i2", 12, 12)
        // The mini's radius 12: (2, 2) outside it, (4, 4) inside (8 or less would fill the first, 16 or more not the second).
        assertPixel(Color.White, picture, "mini", 2, 2)
        assertPixel(red, picture, "mini", 4, 4)
    }

    /**
     * A6.5: the FAB's `splashColor` is its press ripple, `hoverColor` its
     * hover layer and `focusColor` its focus layer, each at its own alpha
     * (Flutter's FAB hands all three to its InkWell). One left unset keeps
     * Material 3's, the content colour at 0.1 pressed and focused and 0.08
     * hovered (Flutter's M3 FAB defaults too); with none the theme's ripple
     * is kept. Robolectric does not draw Android's press ripple, so the
     * configuration is read where the FAB's child reads it, as ButtonTest's
     * D11 does.
     */
    @Test
    fun a6_5_kt_aFabsSplashColorIsItsPressRipple() {
        show(
            start("root", "f", "focusOnly", "plain"),
            fab("f", "l1", "splashColor" to "#E5393580", "hoverColor" to "#1E88E533", on = listOf("onTap")),
            fab("focusOnly", "l2", "focusColor" to "#43A04740", on = listOf("onTap")),
            fab("plain", "l3", on = listOf("onTap")),
            sizedBox("l1", 24, 24),
            sizedBox("l2", 24, 24),
            sizedBox("l3", 24, 24),
        )
        val splash = Props.hex("#E5393580")
        val hover = Props.hex("#1E88E533")
        val focus = Props.hex("#43A04740")
        val overlays = RippleAlpha(draggedAlpha = splash.alpha, focusedAlpha = 0.1f, hoveredAlpha = hover.alpha, pressedAlpha = splash.alpha)

        assertEquals(RippleConfiguration(hover, overlays), ripples["l1"], "at rest")
        assertEquals(
            RippleConfiguration(fabContent, RippleAlpha(draggedAlpha = 0.16f, focusedAlpha = focus.alpha, hoveredAlpha = 0.08f, pressedAlpha = 0.1f)),
            ripples["l2"],
            "focus only",
        )
        assertEquals(RippleConfiguration(), ripples["l3"], "no overlay colours")

        compose.onNodeWithTag("f").performTouchInput { down(center) }
        compose.waitForIdle()
        assertEquals(RippleConfiguration(splash, overlays), ripples["l1"], "pressed")
        compose.onNodeWithTag("f").performTouchInput { up() }
    }

    /**
     * A6.5: a long press takes Flutter's kLongPressTimeout, 500 ms, not the
     * platform's: around the page, Android 12 and later's 400 (the runner's
     * Robolectric reports 500), and still a 450 ms hold on a FAB or an
     * IconButton with both handlers is a tap, a 510 ms one a long press.
     */
    @Test
    fun a6_5_kt_aLongPressTakesFlutters500ms() {
        val both = listOf("onTap", "onLongPress")
        val model = show(
            start("root", "f", "b"),
            fab("f", "i1", on = both),
            iconButton("b", "i2", on = both),
            icon("i1"),
            icon("i2"),
            longPressTimeout = 400,
        )
        fun hold(tag: String, millis: Long) = compose.onNodeWithTag(tag).performTouchInput {
            down(center)
            advanceEventTime(millis)
            up()
        }

        hold("f", 450)
        assertEquals(counts(tap = 1), fired(model))
        hold("f", 510)
        assertEquals(counts(tap = 1, longPress = 1), fired(model))
        hold("b", 450)
        assertEquals(counts(tap = 2, longPress = 1), fired(model))
        hold("b", 510)
        assertEquals(counts(tap = 2, longPress = 2), fired(model))
    }

    /**
     * A6.5: in the Scaffold's floatingActionButton slot the FAB sits at the
     * bottom end, 16 in from both edges (Flutter's endFloat), and fires.
     */
    @Test
    fun a6_5_kt_aFabInTheScaffoldSitsBottomEnd16In() {
        val model = show(
            scaffold("page", mapOf("body" to "body", "floatingActionButton" to "f")),
            sizedBox("body", 10, 10),
            fab("f", "i", on = listOf("onTap")),
            icon("i"),
        )

        assertEquals(DpRect(228.dp, 328.dp, 284.dp, 384.dp), bounds("f"))
        compose.onNodeWithTag("f").performClick()
        assertEquals(counts(tap = 1), fired(model))
    }

    // A6.7.

    /**
     * A6.7: an IconButton takes touches only when enabled and given onTap or
     * onLongPress. Without a handler, or disabled, it takes none and offers
     * no click, so a GestureDetector around it gets the tap; with one, it
     * takes the tap itself.
     */
    @Test
    fun a6_7_kt_anIconButtonWithoutAHandlerOrDisabledTakesNoTouches() {
        val model = show(
            start("root", "g1", "g2", "g3"),
            outer("g1", "plain"),
            outer("g2", "off"),
            outer("g3", "live"),
            iconButton("plain", "i1"),
            iconButton("off", "i2", "enabled" to false, on = listOf("onTap", "onLongPress")),
            iconButton("live", "i3", on = listOf("onTap")),
            icon("i1"),
            icon("i2"),
            icon("i3"),
        )
        compose.onNodeWithTag("plain").assert(noClick)
        compose.onNodeWithTag("off").assert(noClick).assert(noLongClick)

        compose.onNodeWithTag("plain").performClick()
        assertEquals(counts(outer = 1), fired(model))
        compose.onNodeWithTag("off").performClick()
        assertEquals(counts(outer = 2), fired(model))
        // A held press is a tap to the GestureDetector, which has no long press.
        compose.onNodeWithTag("off").performTouchInput { longClick() }
        assertEquals(counts(outer = 3), fired(model))
        compose.onNodeWithTag("live").performClick()
        assertEquals(counts(tap = 1, outer = 3), fired(model))
    }

    /** A6.7: a disabled IconButton is drawn at opacity 0.38, an enabled one without a handler at 1. */
    @Test
    fun a6_7_kt_aDisabledIconButtonIsDrawnAt038() {
        show(
            start("root", "off", "unbound"),
            iconButton("off", "i1", "color" to "#E53935", "enabled" to false, on = listOf("onTap")),
            iconButton("unbound", "i2", "color" to "#E53935"),
            icon("i1"),
            icon("i2"),
        )
        val faded = Color(
            red = 0.38f * red.red + 0.62f,
            green = 0.38f * red.green + 0.62f,
            blue = 0.38f * red.blue + 0.62f,
        )
        val picture = picture()

        assertPixel(faded, picture, "i1", 12, 12)
        assertPixel(red, picture, "i2", 12, 12)
    }

    /**
     * A6.7: a FAB without a handler is live, as Flutter passes onPressed
     * whenever enabled: it offers a click and takes the tap, so a
     * GestureDetector around it gets none, and nothing fires.
     */
    @Test
    fun a6_7_kt_aFabWithoutAHandlerIsLiveAndFiresNothing() {
        val model = show(
            start("root", "g"),
            outer("g", "f"),
            fab("f", "i"),
            icon("i"),
        )
        compose.onNodeWithTag("f").assertIsEnabled().assert(click)

        compose.onNodeWithTag("f").performClick()
        compose.onNodeWithTag("f").performTouchInput { longClick() }

        assertEquals(counts(), fired(model))
    }

    /**
     * A6.7: a disabled FAB, regular or mini, is drawn as an enabled one (the
     * same pixels in the same layout: 56, a mini 48) and is inert: no click,
     * no long press, disabled to accessibility; a tap goes on to a
     * GestureDetector around it, as in Flutter, where its InkWell has no tap.
     */
    @Test
    fun a6_7_kt_aDisabledFabIsDrawnUnchangedAndInert() {
        val both = listOf("onTap", "onLongPress")
        val model = show(
            // y 0, 56, 112, 160, 208.
            start("root", "g", "on", "offMini", "onMini", "after"),
            outer("g", "off"),
            fab("off", "i1", "enabled" to false, on = both),
            fab("on", "i2", on = both),
            fab("offMini", "i3", "mini" to true, "enabled" to false, on = both),
            fab("onMini", "i4", "mini" to true, on = both),
            sizedBox("after", 10, 10),
            icon("i1"),
            icon("i2"),
            icon("i3"),
            icon("i4"),
        )
        val picture = picture()

        assertEquals(region(picture, 0, 56, 56), region(picture, 0, 0, 56), "regular")
        assertEquals(region(picture, 0, 160, 48), region(picture, 0, 112, 48), "mini")
        assertEquals(208.dp, bounds("after").top)
        assertPixel(fabFill, picture, "off", 4, 28)
        assertPixel(fabContent, picture, "i1", 12, 12)
        for (tag in listOf("off", "offMini")) compose.onNodeWithTag(tag).assertIsNotEnabled().assert(noClick).assert(noLongClick)

        compose.onNodeWithTag("offMini").performClick()
        compose.onNodeWithTag("offMini").performTouchInput { longClick() }
        assertEquals(counts(), fired(model))
        compose.onNodeWithTag("off").performClick()
        assertEquals(counts(outer = 1), fired(model))
        // A held press is a tap to the GestureDetector, which has no long press.
        compose.onNodeWithTag("off").performTouchInput { longClick() }
        assertEquals(counts(outer = 2), fired(model))
    }
}
