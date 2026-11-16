package com.orcagateway.sdk.widgets

import android.app.Activity
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.toSize
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.sizedBox
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.math.floor
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * A4.3 (blur half): BackdropFilter and BlurView, at 1 dp per pixel. Compose
 * has no backdrop API, so the page root records what it draws (every
 * backdrop leaving itself out) and each backdrop draws its part of that
 * copy, blurred, in its own box (the natives clip the blur to the box,
 * design D9; Flutter's reaches the nearest ancestor clip).
 *
 * Pages are drawn by [OrcaPageView], which provides the recorder, or, to
 * force an Android level, by [BackdropRecording] around [NodeView] as
 * OrcaPageView puts it there. Two ways of drawing: the view drawn in
 * software on white (as GoldenTest), where a RenderEffect is not applied, so
 * the copy shows unblurred and lines up exactly; and a window `PixelCopy`,
 * which Robolectric draws with Android's hardware renderer (its RenderNodes
 * and RenderEffects), where the blur itself shows.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class BackdropTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /** The recorder the backdrops register with, as their builders find it. */
    private var recorder: BackdropRecorder? = null

    private val red = Props.hex("#FF0000")
    private val blue = Props.hex("#0000FF")
    private val green = Props.hex("#00FF00")

    /**
     * The page from its first node inside a [width] x [height] box: drawn by
     * OrcaPageView, or with [apiLevel] by a recorder for that Android level
     * around NodeView, or with [bare] by NodeView alone (no recorder).
     * BackdropFilter, BlurView and Container are tagged with their ids; a
     * `Shown` node (test only) draws its child while its `shown` is true.
     */
    private fun show(
        width: Int,
        height: Int,
        vararg nodes: ComponentNode,
        state: List<StateDefinition> = emptyList(),
        apiLevel: Int? = null,
        bare: Boolean = false,
    ): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("BackdropFilter", "BlurView", "Shown"))
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("BackdropFilter") { node, model, modifier ->
                    recorder = LocalBackdropRecorder.current
                    BackdropFilterWidget(node, model, modifier.testTag(node.id))
                }
                register("BlurView") { node, model, modifier ->
                    recorder = LocalBackdropRecorder.current
                    BlurViewWidget(node, model, modifier.testTag(node.id))
                }
                register("Container") { node, model, modifier -> ContainerWidget(node, model, modifier.testTag(node.id)) }
                // Test only: its child while its `shown` prop is true, none otherwise.
                register("Shown") { node, model, modifier ->
                    if (node["shown"]?.boolValue == true) ChildView(node, model, modifier)
                }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(width.dp, height.dp)) {
                when {
                    bare -> NodeView(nodes.first().id, model)
                    apiLevel == null -> OrcaPageView(model)
                    else -> BackdropRecording(apiLevel) { root -> NodeView(nodes.first().id, model, root) }
                }
            }
        }
        compose.waitForIdle()
        return model
    }

    private fun node(id: String, type: String, vararg children: String, props: Map<String, Any?> = emptyMap()) =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout,
            if (type == "Stack") ComponentNode.ChildMode.Multi else ComponentNode.ChildMode.Single,
            props.mapValues { JsonValue.of(it.value) }, children.toList(),
        )

    private fun container(id: String, vararg children: String, props: Map<String, Any?> = emptyMap()) =
        node(id, "Container", *children, props = props)

    private fun sized(width: Int, height: Int, color: String? = null): Map<String, Any?> =
        mapOf("width" to width, "height" to height, "color" to color)

    /** `setState(key, key + 1)`. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    private fun gesture(id: String, child: String, key: String) = ComponentNode(
        id, "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        children = listOf(child), actions = mapOf("onTap" to count(key)),
    )

    private fun counter(key: String) = StateDefinition(key, StateScope.Page, JsonValue.Int(0))

    /**
     * A 200 x 200 Stack: behind, a GestureDetector `probe` (counting in
     * `probe`) over all of it; on top, centred, [backdrop] (`b`, 80 x 80 at
     * (60, 60)).
     */
    private fun overProbe(backdrop: ComponentNode, vararg rest: ComponentNode): Array<ComponentNode> = arrayOf(
        node("page", "Stack", "probe", "b", props = mapOf("alignment" to "center")),
        gesture("probe", "behind", "probe"),
        sizedBox("behind", 200, 200),
        backdrop,
        *rest,
    )

    /**
     * A 120 x 80 page, red on the left half and blue on the right, with
     * [backdrop] (a BackdropFilter or BlurView `b` around a 60 x 40 child
     * `c`) centred on it: the backdrop's box is (30, 20)-(90, 60), the
     * colours meet at x = 60.
     */
    private fun stripes(backdrop: ComponentNode, vararg rest: ComponentNode): Array<ComponentNode> = arrayOf(
        node("stack", "Stack", "halves", "b", props = mapOf("alignment" to "center")),
        row("halves", "left", "right"),
        container("left", props = sized(60, 80, "#FF0000")),
        container("right", props = sized(60, 80, "#0000FF")),
        backdrop,
        *rest,
    )

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    /** The view drawn in software on white, as GoldenTest draws it. */
    private fun draw(): Bitmap {
        val view = requireNotNull(view)
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    /**
     * The window copied as Android composes it: Robolectric draws a
     * `PixelCopy` with the hardware renderer (RenderNodes, RenderEffects).
     * Cut to the Compose view.
     */
    private fun pixelCopy(): Bitmap {
        val view = requireNotNull(view)
        val window = generateSequence(view.context) { (it as? ContextWrapper)?.baseContext }
            .filterIsInstance<Activity>().first().window
        val whole = Bitmap.createBitmap(window.decorView.width, window.decorView.height, Bitmap.Config.ARGB_8888)
        var result = -1
        PixelCopy.request(window, whole, { result = it }, Handler(Looper.getMainLooper()))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(PixelCopy.SUCCESS, result, "PixelCopy")
        val at = IntArray(2).also { view.getLocationInWindow(it) }
        return Bitmap.createBitmap(whole, at[0], at[1], view.width, view.height)
    }

    /** What backdrop [index] draws behind itself (the recorded copy, unblurred), alone, on transparent. */
    private fun copyOf(index: Int = 0): Bitmap {
        val backdrop = requireNotNull(recorder).backdrops[index]
        val size = backdrop.layer.size
        val bitmap = Bitmap.createBitmap(size.width, size.height, Bitmap.Config.ARGB_8888)
        CanvasDrawScope().draw(
            Density(1f), LayoutDirection.Ltr, androidx.compose.ui.graphics.Canvas(Canvas(bitmap)), size.toSize(),
        ) { drawLayer(backdrop.layer) }
        return bitmap
    }

    private fun channels(argb: Int) = Triple(
        android.graphics.Color.red(argb) / 255f,
        android.graphics.Color.green(argb) / 255f,
        android.graphics.Color.blue(argb) / 255f,
    )

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int) {
        val actual = picture.getPixel(x, y)
        val (r, g, b) = channels(actual)
        assertTrue(
            abs(expected.red - r) < 0.05f && abs(expected.green - g) < 0.05f && abs(expected.blue - b) < 0.05f,
            "($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }

    // (1) The API split.

    /** A4.3 (q7): Android blurs from 12 (API 31, RenderEffect); below, a white scrim stands in. */
    @Test
    fun a4_3_theBlurNeedsAndroid12AndAScrimStandsInBelow() {
        assertFalse(backdropBlurs(24))
        assertFalse(backdropBlurs(30))
        assertTrue(backdropBlurs(31))
        assertTrue(backdropBlurs(34))
    }

    // (2) Sigma to radius.

    /**
     * A4.3: Flutter's blur is a Gaussian sigma in logical pixels; Android's
     * takes a radius in pixels, with sigma = 0.57735 r + 0.5 (as Swift's
     * shadows convert). A sigma of 0.5 or less is no blur.
     */
    @Test
    fun a4_3_theSigmaBecomesAndroidsBlurRadiusInPixels() {
        assertEquals(16.454, blurRadius(10.0, 1f).toDouble(), 0.001)
        assertEquals(33.775, blurRadius(10.0, 2f).toDouble(), 0.001)
        for ((sigma, density) in listOf(4.0 to 1f, 6.0 to 2.75f, 8.0 to 3f)) {
            assertEquals(sigma * density, 0.57735 * blurRadius(sigma, density) + 0.5, 0.001)
        }
        assertEquals(0f, blurRadius(0.5, 1f))
        assertEquals(0f, blurRadius(0.0, 3f))
        assertEquals(0f, blurRadius(-2.0, 1f))
    }

    // (3) Size.

    /**
     * A4.3: a BackdropFilter and a BlurView are their child's size (a
     * Container with a set width and height); without a child, nothing.
     */
    @Test
    fun a4_3_aBackdropIsItsChildsSizeAndNothingWithoutOne() {
        show(
            200, 300,
            column("root", "bf", "bfEmpty", "bv", "bvEmpty", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            node("bf", "BackdropFilter", "c1"),
            node("bfEmpty", "BackdropFilter"),
            node("bv", "BlurView", "c2", props = mapOf("borderRadius" to 12, "overlayColor" to "#FFFFFF80")),
            node("bvEmpty", "BlurView", props = mapOf("overlayColor" to "#FF0000")),
            container("c1", props = sized(60, 40)),
            container("c2", props = sized(60, 40)),
        )
        assertEquals(60.dp to 40.dp, bounds("bf").width to bounds("bf").height)
        assertEquals(bounds("c1"), bounds("bf"))
        assertEquals(0.dp, bounds("bfEmpty").width)
        assertEquals(0.dp, bounds("bfEmpty").height)
        assertEquals(60.dp to 40.dp, bounds("bv").width to bounds("bv").height)
        assertEquals(bounds("bf").bottom, bounds("bv").top)
        assertEquals(bounds("c2"), bounds("bv"))
        assertEquals(0.dp, bounds("bvEmpty").width)
        assertEquals(0.dp, bounds("bvEmpty").height)
    }

    // (4) The scrim, forced.

    /**
     * A4.3 (q7): below Android 12 (forced here: level 30) a backdrop draws a
     * white scrim at 60% instead of the blur, inside its box only: over a
     * red page, #FF9999 inside, red outside.
     */
    @Test
    fun a4_3_belowAndroid12AWhiteScrimIsDrawnInsideTheBoxOnly() {
        show(
            100, 100,
            container("page", "b", props = sized(100, 100, "#FF0000") + ("alignment" to "center")),
            node("b", "BackdropFilter", "c"),
            container("c", props = sized(60, 40)),
            apiLevel = 30,
        )
        assertEquals(DpRect(20.dp, 30.dp, 80.dp, 70.dp), bounds("b"))
        val picture = draw()
        val scrim = Color(1f, 0.6f, 0.6f)
        for ((x, y) in listOf(50 to 50, 21 to 31, 78 to 68, 21 to 68, 78 to 31)) assertPixel(scrim, picture, x, y)
        for ((x, y) in listOf(18 to 50, 50 to 28, 82 to 50, 50 to 72, 5 to 5)) assertPixel(red, picture, x, y)
        compose.runOnIdle {
            assertEquals(1, requireNotNull(recorder).backdrops.size)
            assertFalse(requireNotNull(recorder).records(), "nothing is recorded below Android 12")
        }
    }

    /**
     * A4.3: a backdrop with no recorder above it (a NodeView hosted on its
     * own) has no copy to draw: it draws the scrim, and its child, and does
     * not fail.
     */
    @Test
    fun a4_3_withoutARecorderABackdropDrawsTheScrim() {
        show(
            100, 100,
            container("page", "b", props = sized(100, 100, "#FF0000") + ("alignment" to "center")),
            node("b", "BlurView", "c", props = mapOf("borderRadius" to 4)),
            container("c", "dot", props = sized(60, 40) + ("alignment" to "center")),
            container("dot", props = sized(20, 20, "#00FF00")),
            bare = true,
        )
        assertEquals(null, recorder)
        val picture = draw()
        assertPixel(Color(1f, 0.6f, 0.6f), picture, 30, 40)
        assertPixel(green, picture, 50, 50)
        assertPixel(red, picture, 10, 10)
    }

    /**
     * A4.3 (q6): the page root records only while a backdrop is on the page:
     * once page state removes the last one, it has left the recorder and
     * nothing is recorded.
     */
    @Test
    fun a4_3_removingTheLastBackdropStopsTheRecording() {
        val model = show(
            100, 100,
            container("page", "only", props = sized(100, 100, "#FF0000") + ("alignment" to "center")),
            ComponentNode(
                "only", "Shown", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                mapOf("shown" to JsonValue.obj("type" to "state", "key" to "shown")), listOf("b"),
                watches = listOf("shown"),
            ),
            node("b", "BlurView", "c", props = mapOf("overlayColor" to "#FFFFFF80")),
            container("c", props = sized(60, 40)),
            state = listOf(StateDefinition("shown", StateScope.Page, JsonValue.Bool(true))),
        )
        val recorder = requireNotNull(recorder)
        compose.runOnIdle {
            assertEquals(1, recorder.backdrops.size)
            assertTrue(recorder.records())
        }

        compose.runOnIdle { model.store.dispatch(mapOf("shown" to JsonValue.Bool(false))) }
        compose.waitForIdle()
        compose.onNodeWithTag("b").assertDoesNotExist()
        compose.runOnIdle {
            assertTrue(recorder.backdrops.isEmpty())
            assertFalse(recorder.records())
        }
        assertPixel(red, draw(), 50, 50)
    }

    // (5) BlurView's layers.

    /**
     * A4.3: BlurView is ClipRRect > blur > overlay colour > child. Outside
     * its rounded corners the page shows (no copy, overlay or child there);
     * inside, the overlay (blue at 50%) over the copy of the red page covers
     * the whole box, and the child (a green square) is drawn on top of it.
     */
    @Test
    fun a4_3_aBlurViewCutsItsCornersAndDrawsTheOverlayUnderItsChild() {
        show(
            100, 100,
            container("page", "b", props = sized(100, 100, "#FF0000") + ("alignment" to "center")),
            node("b", "BlurView", "c", props = mapOf("borderRadius" to 20, "overlayColor" to "#0000FF80")),
            container("c", "dot", props = sized(60, 40) + ("alignment" to "center")),
            container("dot", props = sized(20, 20, "#00FF00")),
        )
        assertEquals(DpRect(20.dp, 30.dp, 80.dp, 70.dp), bounds("b"))
        val picture = draw()
        val tinted = Color(0.5f, 0f, 0.5f)
        for ((x, y) in listOf(21 to 31, 78 to 31, 21 to 68, 78 to 68)) assertPixel(red, picture, x, y)
        for ((x, y) in listOf(22 to 50, 78 to 50, 50 to 32, 50 to 68, 35 to 40)) assertPixel(tinted, picture, x, y)
        assertPixel(green, picture, 50, 50)
        assertPixel(red, picture, 10, 50)
    }

    // (6) The copy holds no backdrop.

    /**
     * A4.3: the copy a backdrop draws holds only what is behind it, as
     * Flutter blurs what was painted before it: with a 50% red overlay over
     * a white page the box reads #FF8080 (the overlay once), not #FF4040
     * (an overlay already in the copy); the copy itself is all white.
     */
    @Test
    fun a4_3_theCopyHoldsNoBackdropSoTheOverlayIsDrawnOnce() {
        show(
            100, 100,
            container("page", "b", props = sized(100, 100, "#FFFFFF") + ("alignment" to "center")),
            node("b", "BlurView", "c", props = mapOf("overlayColor" to "#FF000080")),
            container("c", props = sized(60, 40)),
        )
        val picture = draw()
        for ((x, y) in listOf(50 to 50, 22 to 32, 78 to 68)) assertPixel(Color(1f, 0.5f, 0.5f), picture, x, y)
        assertPixel(Color.White, picture, 10, 10)

        val copy = copyOf()
        assertEquals(60 to 40, copy.width to copy.height)
        for ((x, y) in listOf(1 to 1, 30 to 20, 58 to 38)) assertPixel(Color.White, copy, x, y)
    }

    /**
     * A4.3: the copy is the part of the page behind the backdrop, lined up
     * with it: a backdrop at (30, 20) over red and blue halves meeting at
     * x = 60 copies red up to its x = 30 and blue from there, and holds
     * neither its child (a green square) nor anything of its own.
     */
    @Test
    fun a4_3_theCopyIsThePartOfThePageBehindTheBackdrop() {
        show(
            120, 80,
            *stripes(
                node("b", "BackdropFilter", "c"),
                container("c", "dot", props = sized(60, 40) + ("alignment" to "center")),
                container("dot", props = sized(20, 20, "#00FF00")),
            ),
        )
        assertEquals(DpRect(30.dp, 20.dp, 90.dp, 60.dp), bounds("b"))
        draw()
        val copy = copyOf()
        assertEquals(60 to 40, copy.width to copy.height)
        for ((x, y) in listOf(0 to 0, 29 to 20, 29 to 39, 15 to 30)) assertPixel(red, copy, x, y)
        for ((x, y) in listOf(30 to 0, 30 to 20, 59 to 39, 45 to 10)) assertPixel(blue, copy, x, y)
    }

    // (7) Taps.

    /** A4.3: a tap on a backdrop reaches its child (a GestureDetector), for both widgets. */
    @Test
    fun a4_3_tapsReachTheChild() {
        val model = show(
            100, 200,
            column("root", "bf", "bv", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            node("bf", "BackdropFilter", "g1"),
            node("bv", "BlurView", "g2", props = mapOf("borderRadius" to 8, "overlayColor" to "#FFFFFF80")),
            gesture("g1", "c1", "a"),
            gesture("g2", "c2", "b"),
            container("c1", props = sized(60, 40)),
            container("c2", props = sized(60, 40)),
            state = listOf(counter("a"), counter("b")),
        )
        compose.onNodeWithTag("bf").performTouchInput { click() }
        compose.runOnIdle { assertEquals(JsonValue.Int(1), model.store.value("a")) }
        compose.onNodeWithTag("bv").performTouchInput { click() }
        compose.runOnIdle {
            assertEquals(JsonValue.Int(1), model.store.value("a"))
            assertEquals(JsonValue.Int(1), model.store.value("b"))
        }
    }

    // What a backdrop clips and which taps it takes, as Flutter.

    /**
     * A4.3: Flutter's BackdropFilter is a proxy box with no clip: only the
     * blur is cut to its box (D9), its child draws where it lies, here a
     * green square placed 30 to the right in a 40 x 40 Stack.
     */
    @Test
    fun a4_3_aBackdropFilterDoesNotClipItsChild() {
        show(
            100, 100,
            container("page", "b", props = sized(100, 100, "#FFFFFF") + ("alignment" to "topLeft")),
            node("b", "BackdropFilter", "s"),
            node("s", "Stack", "base", "p"),
            sizedBox("base", 40, 40),
            node("p", "Positioned", "dot", props = mapOf("left" to 30, "top" to 0)),
            container("dot", props = sized(40, 40, "#00FF00")),
        )
        assertEquals(DpRect(0.dp, 0.dp, 40.dp, 40.dp), bounds("b"))
        val picture = draw()
        for ((x, y) in listOf(35 to 20, 45 to 20, 65 to 35)) assertPixel(green, picture, x, y)
        assertPixel(Color.White, picture, 20, 20)
        assertPixel(Color.White, picture, 80, 20)
    }

    /**
     * A4.3: a BackdropFilter takes no tap itself: where its child takes none
     * (a SizedBox), the tap reaches what is behind it.
     */
    @Test
    fun a4_3_aTapOnABackdropFilterReachesWhatIsBehind() {
        val model = show(
            200, 200,
            *overProbe(node("b", "BackdropFilter", "c"), sizedBox("c", 80, 80)),
            state = listOf(counter("probe")),
        )
        assertEquals(DpRect(60.dp, 60.dp, 140.dp, 140.dp), bounds("b"))
        compose.onNodeWithTag("b").performTouchInput { click() }
        compose.runOnIdle { assertEquals(JsonValue.Int(1), model.store.value("probe")) }
    }

    /**
     * A4.3: a BlurView takes every tap over its whole rectangle, corners
     * outside its radius included (its overlay is a Flutter ColoredBox, and
     * a ClipRRect cuts hits only with a custom clipper), so nothing behind
     * it gets one.
     */
    @Test
    fun a4_3_aBlurViewTakesEveryTapOverItsRectangle() {
        val model = show(
            200, 200,
            *overProbe(node("b", "BlurView", "c", props = mapOf("borderRadius" to 30)), sizedBox("c", 80, 80)),
            state = listOf(counter("probe")),
        )
        assertEquals(DpRect(60.dp, 60.dp, 140.dp, 140.dp), bounds("b"))
        compose.onNodeWithTag("b").performTouchInput { click() }
        compose.onNodeWithTag("b").performTouchInput { click(Offset(2f, 2f)) }
        compose.runOnIdle { assertEquals(JsonValue.Int(0), model.store.value("probe")) }
        compose.onRoot().performTouchInput { click(Offset(20f, 20f)) }
        compose.runOnIdle { assertEquals(JsonValue.Int(1), model.store.value("probe")) }
    }

    /**
     * A4.3: a BlurView's corners cut what its child draws, not where it is
     * touched: a GestureDetector filling a BlurView of radius 30 counts a
     * tap in a corner outside the radius, and the probe behind gets none.
     */
    @Test
    fun a4_3_aChildFillingABlurViewTakesATapInItsCorner() {
        val model = show(
            200, 200,
            *overProbe(
                node("b", "BlurView", "g", props = mapOf("borderRadius" to 30)),
                gesture("g", "c", "child"),
                sizedBox("c", 80, 80),
            ),
            state = listOf(counter("probe"), counter("child")),
        )
        compose.onNodeWithTag("b").performTouchInput { click(Offset(2f, 2f)) }
        compose.runOnIdle {
            assertEquals(JsonValue.Int(1), model.store.value("child"))
            assertEquals(JsonValue.Int(0), model.store.value("probe"))
        }
    }

    // The copy follows scrolling.

    /**
     * A4.3: a BlurView fixed over a scrolling list (the frosted bar) draws
     * the stripes behind it now, not those behind it before the scroll.
     * Drawn by Android's renderer, where a scroll view redraws its own layer
     * only; the blur is 0 so the copy reads exactly.
     */
    @Test
    fun a4_3_aFixedBlurViewFollowsTheListScrollingBehindIt() {
        val colours = listOf(
            "#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#00FFFF",
            "#FF00FF", "#800000", "#008000", "#000080", "#808000",
        )
        val stripes = colours.indices.map { "s$it" }
        show(
            200, 200,
            node("page", "Stack", "list", "bar"),
            node("list", "SingleChildScrollView", "column"),
            column("column", *stripes.toTypedArray()),
            *colours.mapIndexed { i, colour -> container("s$i", props = sized(200, 40, colour)) }.toTypedArray(),
            node("bar", "Positioned", "b", props = mapOf("left" to 0, "top" to 0)),
            node("b", "BlurView", "c", props = mapOf("blurX" to 0, "blurY" to 0)),
            container("c", props = sized(200, 40)),
        )
        pixelCopy()
        assertPixel(red, copyOf(), 100, 20)

        compose.onRoot().performTouchInput { swipe(Offset(100f, 190f), Offset(100f, 70f), durationMillis = 500) }
        compose.waitForIdle()
        val scrolled = -bounds("s0").top.value
        assertTrue(scrolled >= 40f, "the list scrolled by $scrolled")

        val screen = pixelCopy()
        val copy = copyOf()
        var checked = 0
        for (y in 2..38) {
            val inPage = y + scrolled
            val into = inPage - floor(inPage / 40f) * 40f
            if (into < 2f || into > 38f) continue
            val colour = Props.hex(colours[floor(inPage / 40f).toInt()])
            assertPixel(colour, copy, 100, y)
            assertPixel(colour, screen, 100, y)
            checked++
        }
        assertTrue(checked > 20, "checked $checked rows")
    }

    // The blur itself, under Android's renderer.

    /**
     * A4.3: drawn by Android's renderer, a BackdropFilter blurs what is
     * behind it inside its box only: where red meets blue inside the box the
     * two run into each other, while the same edge just above and below the
     * box stays sharp, and away from the edge each side keeps its colour.
     */
    @Test
    fun a4_3_androidsRendererBlursWhatIsBehindInsideTheBoxOnly() {
        show(
            120, 80,
            *stripes(
                node("b", "BackdropFilter", "c", props = mapOf("blurX" to 4, "blurY" to 4)),
                container("c", props = sized(60, 40)),
            ),
        )
        assertBlurredInsideOnly(pixelCopy())
    }

    /**
     * A4.3: a backdrop inside a layer of its own (here a scroll view, which
     * clips) still draws the blurred page behind it: the copy is recorded
     * flat, so it never holds a layer the backdrop itself draws into.
     */
    @Test
    fun a4_3_insideAScrollViewTheBackdropStillBlursWhatIsBehind() {
        show(
            120, 80,
            node("scroll", "SingleChildScrollView", "stack"),
            *stripes(
                node("b", "BlurView", "c", props = mapOf("blurX" to 4, "blurY" to 4, "borderRadius" to 4)),
                container("c", props = sized(60, 40)),
            ),
        )
        assertEquals(DpRect(30.dp, 20.dp, 90.dp, 60.dp), bounds("b"))
        assertBlurredInsideOnly(pixelCopy())
    }

    /** The red-blue edge at x = 60 is soft inside the box (30, 20)-(90, 60) and sharp outside it. */
    private fun assertBlurredInsideOnly(picture: Bitmap) {
        fun at(x: Int, y: Int) = channels(picture.getPixel(x, y))
        fun hex(x: Int, y: Int) = Integer.toHexString(picture.getPixel(x, y))
        for (y in listOf(10, 70)) {
            assertPixel(red, picture, 59, y)
            assertPixel(blue, picture, 60, y)
        }
        for (x in listOf(58, 59, 60, 61)) {
            val (r, _, b) = at(x, 40)
            assertTrue(r in 0.15f..0.85f && b in 0.15f..0.85f, "($x, 40) is #${hex(x, 40)}: the edge should be blurred")
        }
        assertPixel(red, picture, 36, 40)
        assertPixel(blue, picture, 84, 40)
    }
}
