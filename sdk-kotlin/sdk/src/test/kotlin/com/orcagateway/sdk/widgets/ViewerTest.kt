package com.orcagateway.sdk.widgets

import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.pinch
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.ViewerLimits
import com.orcagateway.core.render.ViewerPoint
import com.orcagateway.core.render.ViewerSize
import com.orcagateway.core.render.ViewerTransform
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.draw
import com.orcagateway.sdk.style.Props
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
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A4.5 against Flutter's `_buildInteractiveViewer` (layout_builders.dart
 * :636-644: minScale 0.8, maxScale 2.5, pan and scale on) and
 * InteractiveViewer (interactive_viewer.dart: the child laid out with the
 * viewer's constraints, drawn through the transform and clipped to the
 * viewer's box; one scale gesture pans and pinches). The transform itself
 * is the core's ViewerTransform (ViewerTransformTest); here the pinches and
 * swipes are real touch input, at 1 dp per pixel.
 *
 * The child is a 200x200 scene: blue, a 40x40 green square at its top-left
 * corner and a 40x40 red one at its centre (80..120). Compose's touch slop
 * (8 px here) is passed before a gesture starts, and what moved before it
 * is not applied (as Flutter's, which starts at its slop), so a pinch whose
 * fingers spread x2 zooms by less; the pinches meant to reach maxScale
 * spread x19. InteractiveViewer is not advertised yet, so the registry is
 * widened by it and every builder used is registered here, tagged with its
 * node id.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class ViewerTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    private val red = Props.hex("#FF0000")
    private val green = Props.hex("#00FF00")
    private val blue = Props.hex("#0000FF")
    private val yellow = Props.hex("#FFFF00")

    /** The page from its first node inside a [width] x [height] box, set by [restoration] when given. */
    private fun show(
        width: Int,
        height: Int,
        vararg nodes: ComponentNode,
        state: List<StateDefinition> = emptyList(),
        restoration: StateRestorationTester? = null,
    ): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("InteractiveViewer", "IgnorePointer"))
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("InteractiveViewer") { node, model, modifier ->
                    InteractiveViewerWidget(node, model, modifier.testTag(node.id))
                }
                register("IgnorePointer") { node, model, modifier -> IgnorePointerWidget(node, model, modifier.testTag(node.id)) }
                register("GestureDetector") { node, model, modifier ->
                    GestureDetectorWidget(node, model, modifier.testTag(node.id))
                }
                register("SingleChildScrollView") { node, model, modifier -> ScrollWidget(node, model, modifier.testTag(node.id)) }
                register("Stack") { node, model, modifier -> StackWidget(node, model, modifier.testTag(node.id)) }
                register("Positioned") { node, model, modifier -> PositionedWidget(node, model, modifier.testTag(node.id)) }
                register("Container") { node, model, modifier -> ContainerWidget(node, model, modifier.testTag(node.id)) }
                register("Column") { node, model, modifier -> FlexWidget(node, model, modifier.testTag(node.id), vertical = true) }
                register("Row") { node, model, modifier -> FlexWidget(node, model, modifier.testTag(node.id), vertical = false) }
            }
        }
        val content = @androidx.compose.runtime.Composable {
            view = LocalView.current
            Box(Modifier.size(width.dp, height.dp)) { NodeView(nodes.first().id, model) }
        }
        if (restoration != null) restoration.setContent(content) else compose.setContent(content)
        compose.waitForIdle()
        return model
    }

    private fun node(id: String, type: String, vararg children: String, props: Map<String, Any?> = emptyMap()) =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout,
            if (type in setOf("Stack", "Column", "Row")) ComponentNode.ChildMode.Multi else ComponentNode.ChildMode.Single,
            props.mapValues { JsonValue.of(it.value) }, children.toList(),
        )

    private fun container(id: String, width: Int, height: Int, color: String) =
        node(id, "Container", props = mapOf("width" to width, "height" to height, "color" to color))

    private fun start(id: String, type: String, vararg children: String) =
        node(id, type, *children, props = mapOf("crossAxisAlignment" to "start", "mainAxisSize" to "min"))

    /** An InteractiveViewer [id] around [child]. */
    private fun viewer(id: String, child: String, props: Map<String, Any?> = emptyMap()) =
        node(id, "InteractiveViewer", child, props = props)

    /** The 200x200 scene, its ids ending in [s]. */
    private fun scene(s: String = ""): Array<ComponentNode> = arrayOf(
        node("scene$s", "Stack", "base$s", "corner$s", "mid$s", props = mapOf("alignment" to "topLeft")),
        container("base$s", 200, 200, "#0000FF"),
        node("corner$s", "Positioned", "cornerBox$s", props = mapOf("left" to 0, "top" to 0)),
        container("cornerBox$s", 40, 40, "#00FF00"),
        node("mid$s", "Positioned", "midBox$s", props = mapOf("left" to 80, "top" to 80)),
        container("midBox$s", 40, 40, "#FF0000"),
    )

    /** `setState(key, key + 1)`. */
    private fun count(key: String): Action = Action.SetState(
        key = key,
        value = JsonValue.parse(
            """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},""" +
                """"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
        ),
    )

    /** A GestureDetector around [child] that counts its taps in page state [key]. */
    private fun gesture(id: String, child: String, key: String) = ComponentNode(
        id, "GestureDetector", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        children = listOf(child), actions = mapOf("onTap" to count(key)),
    )

    private fun counter(key: String) = StateDefinition(key, StateScope.Page, JsonValue.Int(0))

    private fun assertCount(expected: Int, model: OrcaPageModel, key: String, message: String) {
        compose.runOnIdle { assertEquals(JsonValue.Int(expected.toLong()), model.store.value(key), message) }
    }

    /**
     * [tag]'s box as drawn, in the root, unclipped: through the viewer's
     * layer scale included (the semantics bounds keep the unscaled size).
     */
    private fun bounds(tag: String): Rect {
        val coordinates = compose.onNodeWithTag(tag, useUnmergedTree = true).fetchSemanticsNode().layoutInfo.coordinates
        return coordinates.findRootCoordinates().localBoundingBoxOf(coordinates, clipBounds = false)
    }

    /** [tag]'s bounds are [left], [top], [right], [bottom] within half a pixel. */
    private fun assertBounds(tag: String, left: Int, top: Int, right: Int, bottom: Int) {
        val box = bounds(tag)
        val got = listOf(box.left, box.top, box.right, box.bottom)
        assertTrue(
            got.zip(listOf(left, top, right, bottom)).all { (g, w) -> abs(g - w) < 0.5f },
            "$tag is at $got, expected [$left, $top, $right, $bottom]",
        )
    }

    /** Two fingers level about ([x], [y]), [from] apart, spread (or pinched) to [to] apart. */
    private fun pinch(x: Float, y: Float, from: Float, to: Float) {
        compose.onRoot().performTouchInput {
            pinch(
                start0 = Offset(x - from / 2, y), end0 = Offset(x - to / 2, y),
                start1 = Offset(x + from / 2, y), end1 = Offset(x + to / 2, y),
            )
        }
        compose.waitForIdle()
    }

    /** A pinch about ([x], [y]) spreading x19, past any maxScale here. */
    private fun pinchAll(x: Float = 100f, y: Float = 100f) = pinch(x, y, from = 10f, to = 190f)

    /** One finger from ([fromX], [fromY]) to ([toX], [toY]). */
    private fun swipe(fromX: Float, fromY: Float, toX: Float, toY: Float) {
        compose.onRoot().performTouchInput { swipe(start = Offset(fromX, fromY), end = Offset(toX, toY)) }
        compose.waitForIdle()
    }

    private fun assertPixel(expected: Color, picture: android.graphics.Bitmap, x: Int, y: Int, what: String) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.05f },
            "$what ($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }

    /** A4.5: a 200x200 viewer is its child's size and, at rest, draws it unchanged, nothing outside its box. */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_5_atRestTheViewerIsItsChildsSizeAndDrawsItUnchanged() {
        show(300, 300, viewer("viewer", "scene"), *scene())
        assertBounds("viewer", 0, 0, 200, 200)
        assertBounds("scene", 0, 0, 200, 200)
        assertBounds("midBox", 80, 80, 120, 120)
        val picture = draw(requireNotNull(view))
        assertPixel(green, picture, 20, 20, "the corner square")
        assertPixel(red, picture, 100, 100, "the centre square")
        assertPixel(blue, picture, 60, 60, "the scene")
        assertPixel(blue, picture, 190, 190, "the scene")
        assertPixel(Color.White, picture, 250, 100, "beside the viewer")
    }

    /**
     * A4.5: two fingers spreading x2 about the centre zoom in about it: the
     * centre pixel stays red and the red square grows about it, while the
     * green corner square leaves the box's corner past its top-left edge.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_5_aPinchSpreadingAboutTheCentreZoomsAboutIt() {
        show(300, 300, viewer("viewer", "scene"), *scene())
        pinch(100f, 100f, from = 60f, to = 120f)
        assertBounds("viewer", 0, 0, 200, 200)
        val mid = bounds("midBox")
        assertTrue(mid.width > 1.3f * 40 && mid.width <= 2f * 40 + 0.5f, "the red square is ${mid.width} wide, zoomed in by less than x2")
        assertTrue(abs(mid.center.x - 100) < 0.5f && abs(mid.center.y - 100) < 0.5f, "the red square stays centred: $mid")
        val corner = bounds("cornerBox")
        assertTrue(corner.left < -10 && corner.top < -10, "the corner square moved out: $corner")
        val picture = draw(requireNotNull(view))
        assertPixel(red, picture, 100, 100, "the centre pixel")
        assertPixel(red, picture, 75, 100, "the grown red square")
        assertPixel(blue, picture, 20, 20, "where the corner square was")
    }

    /**
     * A4.5: a pinch spreading x19 stops at maxScale about its focal point:
     * 2.5 by default (the scene 500 wide from -150), 1.5 when set.
     */
    @Test
    fun a4_5_aPinchStopsAtMaxScale() {
        show(
            200, 400,
            node("root", "Column", "a", "b", props = mapOf("crossAxisAlignment" to "start")),
            viewer("a", "sceneA"), *scene("A"),
            viewer("b", "sceneB", props = mapOf("maxScale" to 1.5)), *scene("B"),
        )
        pinchAll(100f, 100f)
        pinchAll(100f, 300f)
        assertBounds("sceneA", -150, -150, 350, 350)
        assertBounds("sceneB", -50, 150, 250, 450)
        assertBounds("b", 0, 200, 200, 400)
    }

    /** A4.5: at scale 1 a swipe moves nothing: the bound (the child's rect) leaves no room. */
    @Test
    fun a4_5_aSwipeAtScaleOneMovesNothing() {
        show(300, 300, viewer("viewer", "scene"), *scene())
        swipe(100f, 100f, 30f, 40f)
        swipe(20f, 20f, 190f, 180f)
        assertBounds("scene", 0, 0, 200, 200)
    }

    /**
     * A4.5: zoomed in to 2.5, a long swipe pans the scene until its edge
     * meets the viewer's and no further: right by 170 to x 0, then up and
     * left by 180, twice, to -300 (500 - 200) on both axes.
     */
    @Test
    fun a4_5_zoomedInALongSwipeStopsAtTheChildsEdge() {
        show(300, 300, viewer("viewer", "scene"), *scene())
        pinchAll()
        assertBounds("scene", -150, -150, 350, 350)
        swipe(20f, 100f, 190f, 100f)
        assertBounds("scene", 0, -150, 500, 350)
        swipe(190f, 190f, 10f, 10f)
        assertBounds("scene", -180, -300, 320, 200)
        swipe(190f, 190f, 10f, 10f)
        assertBounds("scene", -300, -300, 200, 200)
    }

    /** A4.5: with scaleEnabled false a pinch changes nothing. */
    @Test
    fun a4_5_scaleDisabledAPinchDoesNothing() {
        show(300, 300, viewer("viewer", "scene", props = mapOf("scaleEnabled" to false)), *scene())
        pinchAll()
        pinch(100f, 100f, from = 120f, to = 40f)
        assertBounds("scene", 0, 0, 200, 200)
    }

    /** A4.5: with panEnabled false a pinch still zooms about its focal point, and a swipe then does nothing. */
    @Test
    fun a4_5_panDisabledASwipeDoesNothing() {
        show(300, 300, viewer("viewer", "scene", props = mapOf("panEnabled" to false)), *scene())
        pinchAll()
        assertBounds("scene", -150, -150, 350, 350)
        swipe(20f, 100f, 190f, 100f)
        swipe(100f, 190f, 100f, 10f)
        assertBounds("scene", -150, -150, 350, 350)
    }

    /**
     * A4.5: the zoomed child is cut to the viewer's box: siblings drawn
     * before it (yellow, above and to the left) keep their colour and the
     * page beyond its right and bottom edges stays white, while inside it
     * the red square has grown.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_5_nothingDrawsOutsideTheViewer() {
        show(
            300, 300,
            start("root", "Column", "above", "row"),
            container("above", 260, 60, "#FFFF00"),
            start("row", "Row", "left", "viewer"),
            container("left", 60, 200, "#FFFF00"),
            viewer("viewer", "scene"), *scene(),
        )
        assertBounds("viewer", 60, 60, 260, 260)
        pinchAll(160f, 160f)
        assertBounds("scene", -90, -90, 410, 410)
        val picture = draw(requireNotNull(view))
        assertPixel(red, picture, 120, 160, "the grown red square")
        assertPixel(yellow, picture, 30, 160, "the sibling on the left")
        assertPixel(yellow, picture, 160, 30, "the sibling above")
        assertPixel(Color.White, picture, 280, 160, "right of the viewer")
        assertPixel(Color.White, picture, 160, 280, "below the viewer")
    }

    /** A4.5: a tap on a GestureDetector in the viewer still counts, at rest and zoomed in. */
    @Test
    fun a4_5_aTapOnAChildGestureDetectorStillCounts() {
        val model = show(
            300, 300,
            viewer("viewer", "tapper"), gesture("tapper", "scene", "taps"), *scene(),
            state = listOf(counter("taps")),
        )
        compose.onRoot().performTouchInput { click(Offset(100f, 100f)) }
        assertCount(1, model, "taps", "at rest")
        pinchAll()
        assertBounds("scene", -150, -150, 350, 350)
        compose.onRoot().performTouchInput { click(Offset(30f, 170f)) }
        assertCount(2, model, "taps", "zoomed in")
    }

    /**
     * A4.5: inside a vertical scroll view taller than the screen, a vertical
     * swipe on the viewer at rest scrolls the Column (the viewer could not
     * pan, so it takes nothing), and the viewer is not moved in it.
     */
    @Test
    fun a4_5_atRestAVerticalSwipeOnTheViewerScrollsTheColumnAroundIt() {
        show(
            200, 300,
            node("scroll", "SingleChildScrollView", "list"),
            node("list", "Column", "viewer", "below"),
            viewer("viewer", "scene"), *scene(),
            container("below", 200, 600, "#FFFF00"),
        )
        swipe(100f, 150f, 100f, 50f)
        val top = bounds("list").top
        assertTrue(top < -40, "the Column scrolled up by the swipe: its top is at $top")
        val viewer = bounds("viewer")
        assertBounds("scene", viewer.left.toInt(), viewer.top.toInt(), viewer.right.toInt(), viewer.bottom.toInt())
    }

    /**
     * A4.5: under an IgnorePointer the viewer takes no touch: a tap goes on
     * to the probe behind, and a pinch zooms nothing.
     */
    @Test
    fun a4_5_underAnIgnorePointerTheViewerTakesNoTouch() {
        val model = show(
            300, 300,
            node("page", "Stack", "probe", "ignore", props = mapOf("alignment" to "topLeft")),
            gesture("probe", "behind", "probe"), sizedBox("behind", 200, 200),
            node("ignore", "IgnorePointer", "viewer"),
            viewer("viewer", "scene"), *scene(),
            state = listOf(counter("probe")),
        )
        compose.onRoot().performTouchInput { click(Offset(100f, 100f)) }
        assertCount(1, model, "probe", "the probe behind")
        pinchAll()
        assertBounds("scene", 0, 0, 200, 200)
    }

    /**
     * A4.5: a pinch with one finger on each of two GestureDetectors in the
     * viewer still zooms (Flutter's scale recogniser wins that arena), and
     * neither counts a tap: the second detector taking its finger's down
     * does not end the pinch.
     */
    @Test
    fun a4_5_aPinchWithAFingerOnEachOfTwoGestureDetectorsStillZooms() {
        val model = show(
            300, 300,
            viewer("viewer", "pair"),
            node("pair", "Row", "gA", "gB", props = mapOf("mainAxisSize" to "min")),
            gesture("gA", "boxA", "a"), container("boxA", 100, 200, "#0000FF"),
            gesture("gB", "boxB", "b"), container("boxB", 100, 200, "#00FF00"),
            state = listOf(counter("a"), counter("b")),
        )
        pinch(100f, 100f, from = 20f, to = 190f)
        assertBounds("pair", -150, -150, 350, 350)
        assertCount(0, model, "a", "the left detector")
        assertCount(0, model, "b", "the right detector")
    }

    /** A4.5: the transform is kept through a saved and restored state (a rotation), as a scroll view keeps its offset. */
    @Test
    fun a4_5_theTransformOutlivesASavedStateRestore() {
        val restoration = StateRestorationTester(compose)
        show(300, 300, viewer("viewer", "scene"), *scene(), restoration = restoration)
        pinchAll()
        assertBounds("scene", -150, -150, 350, 350)
        restoration.emulateSavedInstanceStateRestore()
        compose.waitForIdle()
        assertBounds("scene", -150, -150, 350, 350)
    }

    /**
     * A4.5: a prop changing in the middle of a pinch does not drop it: with
     * maxScale bound to page state at 2 the pinch stops at 2; raised to 3,
     * the same pinch goes on to 3.
     */
    @Test
    fun a4_5_aPropChangeMidPinchKeepsTheGesture() {
        val model = show(
            300, 300,
            ComponentNode(
                "viewer", "InteractiveViewer", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                mapOf("maxScale" to JsonValue.obj("type" to "state", "key" to "max")), listOf("scene"), watches = listOf("max"),
            ),
            *scene(),
            state = listOf(StateDefinition("max", StateScope.Page, JsonValue.Int(2))),
        )
        compose.onRoot().performTouchInput {
            down(0, Offset(95f, 100f))
            down(1, Offset(105f, 100f))
            for (half in listOf(10f, 20f)) {
                updatePointerTo(0, Offset(100f - half, 100f))
                updatePointerTo(1, Offset(100f + half, 100f))
                move()
            }
        }
        compose.waitForIdle()
        assertBounds("scene", -100, -100, 300, 300)
        compose.runOnIdle { model.store.dispatch(mapOf("max" to JsonValue.Int(3))) }
        compose.waitForIdle()
        compose.onRoot().performTouchInput {
            updatePointerTo(0, Offset(40f, 100f))
            updatePointerTo(1, Offset(160f, 100f))
            move()
            up(0)
            up(1)
        }
        compose.waitForIdle()
        assertBounds("scene", -200, -200, 400, 400)
    }

    // The feed: Compose's pointer values into the core's ViewerGesture.

    private val square = ViewerLimits(viewport = ViewerSize(200.0, 200.0), child = ViewerSize(200.0, 200.0))
    private val zoomed = ViewerTransform(scale = 2.0, x = -100.0, y = -100.0)

    /** One finger moved from ([x0], [y0]) to ([x1], [y1]). */
    private fun finger(x0: Double, y0: Double, x1: Double, y1: Double) =
        ViewerPointers(count = 1, previous = ViewerPoint(x0, y0), current = ViewerPoint(x1, y1), spread = 0.0, zoom = 1.0)

    /**
     * A4.5: a one-finger move is taken only once past the slop and only
     * while it can pan: at rest it is never taken (so a scroll view around
     * gets it); zoomed in it pans by the move, the slop's own travel left
     * out; with panEnabled false it is not taken.
     */
    @Test
    fun a4_5_theFeedTakesAOneFingerMoveOnlyPastTheSlopAndWhileItCanPan() {
        val atRest = ViewerFeed(touchSlop = 8.0, pointers = 1)
        assertNull(atRest.step(finger(100.0, 100.0, 105.0, 100.0), ViewerTransform.identity, square), "within the slop")
        assertNull(atRest.step(finger(105.0, 100.0, 120.0, 100.0), ViewerTransform.identity, square), "at rest")

        val inZoom = ViewerFeed(touchSlop = 8.0, pointers = 1)
        assertNull(inZoom.step(finger(100.0, 100.0, 105.0, 100.0), zoomed, square), "within the slop")
        val panned = assertNotNull(inZoom.step(finger(105.0, 100.0, 120.0, 100.0), zoomed, square), "zoomed in")
        assertTransform(ViewerTransform(scale = 2.0, x = -85.0, y = -100.0), panned)
        assertTransform(ViewerTransform(scale = 2.0, x = -75.0, y = -100.0), inZoom.step(finger(120.0, 100.0, 130.0, 100.0), panned, square))

        val locked = ViewerFeed(touchSlop = 8.0, pointers = 1)
        assertNull(locked.step(finger(100.0, 100.0, 120.0, 100.0), zoomed, square.copy(panEnabled = false)), "pan off")
    }

    /**
     * A4.5: a pinch is taken once past the slop, even at rest, and zooms by
     * the zoom since it started about its focal point; a finger landing or
     * lifting starts the gesture anew from where the fingers then are (as
     * Flutter's ScaleGestureRecognizer), so the centroid's jump moves
     * nothing.
     */
    @Test
    fun a4_5_theFeedTakesAPinchAndRestartsWhenAFingerLandsOrLifts() {
        val feed = ViewerFeed(touchSlop = 8.0, pointers = 1)
        val centre = ViewerPoint(100.0, 100.0)
        assertNull(feed.step(ViewerPointers(2, centre, centre, 0.0, 1.0), ViewerTransform.identity, square), "a finger lands")
        assertNull(feed.step(ViewerPointers(2, centre, centre, 20.0, 1.2), ViewerTransform.identity, square), "within the slop")
        val first = assertNotNull(feed.step(ViewerPointers(2, centre, centre, 24.0, 1.5), ViewerTransform.identity, square))
        assertTransform(ViewerTransform(scale = 1.5, x = -50.0, y = -50.0), first)
        val second = assertNotNull(feed.step(ViewerPointers(2, centre, centre, 36.0, 4.0 / 3), first, square))
        assertTransform(ViewerTransform(scale = 2.0, x = -100.0, y = -100.0), second)
        assertNull(feed.step(ViewerPointers(1, ViewerPoint(60.0, 100.0), ViewerPoint(60.0, 100.0), 0.0, 1.0), second, square), "one lifts")
        assertTransform(ViewerTransform(scale = 2.0, x = -90.0, y = -100.0), feed.step(finger(60.0, 100.0, 70.0, 100.0), second, square))
    }

    /** [actual] is [expected] within 1e-9 (the other finger pans from where it is). */
    private fun assertTransform(expected: ViewerTransform, actual: ViewerTransform?) {
        val got = assertNotNull(actual, "taken")
        for ((want, have) in listOf(expected.scale to got.scale, expected.x to got.x, expected.y to got.y)) {
            assertEquals(want, have, 1e-9, "$got vs $expected")
        }
    }
}
