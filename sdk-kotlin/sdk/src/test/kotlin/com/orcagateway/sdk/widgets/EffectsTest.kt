package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
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
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
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
 * A4.1, A4.2 and the ColorFiltered half of A4.3 against Flutter's builders
 * (layout_builders.dart `_buildOpacity`, `_buildRotatedBox`,
 * `_buildClipRect`, `_buildClipOval`, `_buildDecoratedBox`,
 * `_buildColorFiltered`) and render objects (RenderOpacity,
 * RenderRotatedBox, RenderClipRect, RenderClipOval, RenderDecoratedBox), at
 * 1 dp per pixel. Every size case has sized children (Containers with a set
 * width and height). The six are not advertised yet, so the registry is
 * widened by them and their builders registered here, tagged with their
 * node ids, as Containers and GestureDetectors are.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class EffectsTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    private val red = Props.hex("#FF0000")
    private val blue = Props.hex("#0000FF")
    private val black = Props.hex("#000000")

    /** The page from its first node inside a [width] x [height] box. */
    private fun show(
        width: Int,
        height: Int,
        vararg nodes: ComponentNode,
        state: List<StateDefinition> = emptyList(),
    ): OrcaPageModel {
        val effects = setOf("Opacity", "RotatedBox", "ClipRect", "ClipOval", "DecoratedBox", "ColorFiltered")
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + effects)
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Opacity") { node, model, modifier -> OpacityWidget(node, model, modifier.testTag(node.id)) }
                register("RotatedBox") { node, model, modifier -> RotatedBoxWidget(node, model, modifier.testTag(node.id)) }
                register("ClipRect") { node, model, modifier -> ClipRectWidget(node, model, modifier.testTag(node.id)) }
                register("ClipOval") { node, model, modifier -> ClipOvalWidget(node, model, modifier.testTag(node.id)) }
                register("DecoratedBox") { node, model, modifier ->
                    DecoratedBoxWidget(node, model, modifier.testTag(node.id))
                }
                register("ColorFiltered") { node, model, modifier ->
                    ColorFilteredWidget(node, model, modifier.testTag(node.id))
                }
                register("Container") { node, model, modifier -> ContainerWidget(node, model, modifier.testTag(node.id)) }
                register("Row") { node, model, modifier -> FlexWidget(node, model, modifier.testTag(node.id), vertical = false) }
                register("IntrinsicHeight") { node, model, modifier ->
                    IntrinsicHeightWidget(node, model, modifier.testTag(node.id))
                }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
                register("GestureDetector") { node, model, modifier ->
                    GestureDetectorWidget(node, model, modifier.testTag(node.id))
                }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(width.dp, height.dp)) { NodeView(nodes.first().id, model) }
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

    private fun start(id: String, vararg children: String) =
        column(id, *children, props = mapOf("crossAxisAlignment" to JsonValue.String("start")))

    /** A Row as wide as its children (Flutter's Row takes all the width it may by default). */
    private fun tightRow(id: String, vararg children: String) =
        row(id, *children, props = mapOf("mainAxisSize" to JsonValue.String("min")))

    /**
     * A Stack of a GestureDetector `probe` (counting in `probe`) over a
     * [width] x [height] SizedBox, behind [front] at the top left. A tap
     * nothing in front takes reaches it, as in Flutter. (Compose counts a
     * tap near a target smaller than 48 dp as that target's when nothing
     * else is hit, so a miss is shown by the probe taking the tap.)
     */
    private fun overProbe(width: Int, height: Int, front: String): Array<ComponentNode> = arrayOf(
        node("page", "Stack", "probe", front, props = mapOf("alignment" to "topLeft")),
        gesture("probe", "behind", "probe"),
        sizedBox("behind", width, height),
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

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    /** A tap at ([x], [y]) in the page. */
    private fun tap(x: Int, y: Int) {
        compose.onRoot().performTouchInput { click(Offset(x.toFloat(), y.toFloat())) }
        compose.waitForIdle()
    }

    private fun assertCount(expected: Int, model: OrcaPageModel, key: String, message: String) {
        compose.runOnIdle { assertEquals(JsonValue.Int(expected.toLong()), model.store.value(key), message) }
    }

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int, what: String = "") {
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

    // A4.1 Opacity.

    /**
     * A4.1: Opacity 0.5 draws its child at half alpha (red over white reads
     * #FF8080); without `opacity` it is 1 (red); at 0 nothing shows. It is
     * its child's size.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_1_opacityHalfDrawsTheChildHalfTransparentAndDefaultsToOne() {
        show(
            100, 200,
            // y 0..40, 40..80, 80..120.
            start("root", "half", "plain", "none"),
            node("half", "Opacity", "c1", props = mapOf("opacity" to 0.5)),
            node("plain", "Opacity", "c2"),
            node("none", "Opacity", "c3", props = mapOf("opacity" to 0)),
            container("c1", props = sized(40, 40, "#FF0000")),
            container("c2", props = sized(40, 40, "#FF0000")),
            container("c3", props = sized(40, 40, "#FF0000")),
        )
        assertEquals(DpRect(0.dp, 0.dp, 40.dp, 40.dp), bounds("half"))
        assertEquals(bounds("c2"), bounds("plain"))
        val picture = draw(requireNotNull(view))
        assertPixel(Color(1f, 0.5f, 0.5f), picture, 20, 20, "half")
        assertPixel(red, picture, 20, 60, "default")
        assertPixel(Color.White, picture, 20, 100, "zero")
    }

    /**
     * A4.1: Flutter's RenderOpacity has no hit test of its own, so a child
     * at opacity 0 still takes taps.
     */
    @Test
    fun a4_1_atOpacityZeroTheChildStillTakesTaps() {
        val model = show(
            100, 100,
            node("o", "Opacity", "g", props = mapOf("opacity" to 0)),
            gesture("g", "c", "taps"),
            container("c", props = sized(40, 40, "#FF0000")),
            state = listOf(counter("taps")),
        )
        compose.onNodeWithTag("o").performTouchInput { click() }
        assertCount(1, model, "taps", "a tap on the invisible child")
    }

    // A4.1 RotatedBox.

    /**
     * A4.1: a RotatedBox lays its child out with the constraints flipped and
     * takes the child's size swapped on odd turns: one turn around a 60 x 20
     * Container is 20 x 60 (the sibling below starts at 60), two turns keep
     * 60 x 20, three (and -1, Dart's -1 % 4) are 20 x 60; with no child it
     * is the smallest size.
     */
    @Test
    fun a4_1_aQuarterTurnSwapsTheLayoutWidthAndHeight() {
        show(
            200, 400,
            start("root", "one", "after", "two", "three", "minus", "empty"),
            node("one", "RotatedBox", "c1", props = mapOf("quarterTurns" to 1)),
            sizedBox("after", 10, 10),
            node("two", "RotatedBox", "c2", props = mapOf("quarterTurns" to 2)),
            node("three", "RotatedBox", "c3", props = mapOf("quarterTurns" to 3)),
            node("minus", "RotatedBox", "c4", props = mapOf("quarterTurns" to -1)),
            node("empty", "RotatedBox", props = mapOf("quarterTurns" to 1)),
            container("c1", props = sized(60, 20, "#FF0000")),
            container("c2", props = sized(60, 20, "#FF0000")),
            container("c3", props = sized(60, 20, "#FF0000")),
            container("c4", props = sized(60, 20, "#FF0000")),
        )
        assertEquals(DpRect(0.dp, 0.dp, 20.dp, 60.dp), bounds("one"))
        assertEquals(60.dp, bounds("after").top)
        assertEquals(60.dp to 20.dp, bounds("two").width to bounds("two").height)
        assertEquals(20.dp to 60.dp, bounds("three").width to bounds("three").height)
        assertEquals(20.dp to 60.dp, bounds("minus").width to bounds("minus").height)
        assertEquals(0.dp to 0.dp, bounds("empty").width to bounds("empty").height)
        assertEquals(bounds("minus").bottom, bounds("empty").top)
    }

    /**
     * A4.1: a RotatedBox's intrinsic sizes are its child's, swapped on odd
     * turns (Flutter's RenderRotatedBox answers its min and max intrinsic
     * width with the child's height and the other way round): an
     * IntrinsicHeight around a stretched Row holding a RotatedBox turned
     * once around a 60 x 20 Container and a 10 wide Container makes the Row
     * 60 tall, and the sibling stretches to 60.
     */
    @Test
    fun a4_1_aTurnedBoxSwapsItsIntrinsicSizes() {
        show(
            200, 300,
            node("ih", "IntrinsicHeight", "row"),
            row("row", "rb", "fill", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            node("rb", "RotatedBox", "c", props = mapOf("quarterTurns" to 1)),
            container("c", props = sized(60, 20, "#FF0000")),
            container("fill", props = mapOf("width" to 10, "color" to "#0000FF")),
        )
        assertEquals(60.dp, bounds("row").height)
        assertEquals(DpRect(0.dp, 0.dp, 20.dp, 60.dp), bounds("rb"))
        assertEquals(DpRect(20.dp, 0.dp, 30.dp, 60.dp), bounds("fill"))
    }

    /**
     * A4.1: the child is turned clockwise about the box's centre: a 60 x 20
     * child red on its left half and blue on its right shows red on top
     * after one turn, red on the right after two, red at the bottom after
     * three.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_1_aRotatedBoxTurnsItsChildClockwiseAboutItsCentre() {
        show(
            200, 200,
            // x 0..20, 20..80 (y 0..20), 80..100.
            row("root", "one", "two", "three", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            node("one", "RotatedBox", "r1", props = mapOf("quarterTurns" to 1)),
            node("two", "RotatedBox", "r2", props = mapOf("quarterTurns" to 2)),
            node("three", "RotatedBox", "r3", props = mapOf("quarterTurns" to 3)),
            *(1..3).flatMap { i ->
                listOf(
                    tightRow("r$i", "a$i", "b$i"),
                    container("a$i", props = sized(30, 20, "#FF0000")),
                    container("b$i", props = sized(30, 20, "#0000FF")),
                )
            }.toTypedArray(),
        )
        assertEquals(DpRect(20.dp, 0.dp, 80.dp, 20.dp), bounds("two"))
        val picture = draw(requireNotNull(view))
        assertPixel(red, picture, 10, 15, "one turn, top")
        assertPixel(blue, picture, 10, 45, "one turn, bottom")
        assertPixel(blue, picture, 35, 10, "two turns, left")
        assertPixel(red, picture, 65, 10, "two turns, right")
        assertPixel(blue, picture, 90, 15, "three turns, top")
        assertPixel(red, picture, 90, 45, "three turns, bottom")
    }

    /**
     * A4.1: taps go through the turn, as Flutter's RenderRotatedBox hit
     * tests through its transform: a GestureDetector around a 60 x 20
     * Container turned once takes a tap where it is drawn, low in its
     * 20 x 60 box; where it would lie unturned the tap reaches the probe
     * behind.
     */
    @Test
    fun a4_1_tapsReachARotatedChildWhereItIsDrawn() {
        val model = show(
            200, 200,
            *overProbe(200, 200, "rb"),
            node("rb", "RotatedBox", "g", props = mapOf("quarterTurns" to 1)),
            gesture("g", "c", "taps"),
            container("c", props = sized(60, 20, "#FF0000")),
            state = listOf(counter("taps"), counter("probe")),
        )
        assertEquals(DpRect(0.dp, 0.dp, 20.dp, 60.dp), bounds("rb"))
        tap(30, 30)
        assertCount(0, model, "taps", "where the child would lie unturned")
        assertCount(1, model, "probe", "where the child would lie unturned")
        tap(10, 50)
        assertCount(1, model, "taps", "low in the turned child")
        assertCount(1, model, "probe", "low in the turned child")
    }

    // A4.2 ClipRect and ClipOval.

    /**
     * Each clip around a 40 x 40 Stack whose 80 x 80 red Container hangs 40
     * past its right and bottom (a Stack does not clip, as Flutter's
     * builder sends Clip.none): ClipRect at y 0..40, a gap to 80, ClipOval
     * at y 80..120. With [taps] the Containers sit in GestureDetectors that
     * count in `rect` and `oval`, and the column is over a probe.
     */
    private fun clips(taps: Boolean): Array<ComponentNode> = arrayOf(
        *(if (taps) overProbe(100, 200, "root") else emptyArray()),
        start("root", "rect", "gap", "oval"),
        node("rect", "ClipRect", "s1"),
        sizedBox("gap", 40, 40),
        node("oval", "ClipOval", "s2"),
        *listOf(1 to "rect", 2 to "oval").flatMap { (i, key) ->
            val square = container("red$i", props = sized(80, 80, "#FF0000"))
            listOfNotNull(
                node("s$i", "Stack", "base$i", "p$i"),
                sizedBox("base$i", 40, 40),
                node(
                    "p$i", "Positioned", if (taps) "g$i" else "red$i",
                    props = mapOf("left" to 0, "top" to 0, "width" to 80, "height" to 80),
                ),
                if (taps) gesture("g$i", "red$i", key) else null,
                square,
            )
        }.toTypedArray(),
    )

    /**
     * A4.2: ClipRect cuts the overflow at its box; ClipOval cuts it to the
     * ellipse inscribed in its box, so the box's corners show the page.
     * Both are their child's size.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_2_clipRectAndClipOvalCutTheOverflow() {
        show(100, 200, *clips(taps = false))
        assertEquals(DpRect(0.dp, 0.dp, 40.dp, 40.dp), bounds("rect"))
        assertEquals(DpRect(0.dp, 80.dp, 40.dp, 120.dp), bounds("oval"))
        val picture = draw(requireNotNull(view))

        for ((x, y) in listOf(20 to 20, 1 to 1, 38 to 38)) assertPixel(red, picture, x, y, "rect inside")
        for ((x, y) in listOf(60 to 20, 20 to 60, 60 to 60, 42 to 38)) assertPixel(Color.White, picture, x, y, "rect outside")

        for ((x, y) in listOf(20 to 100, 20 to 82, 2 to 100, 37 to 100, 20 to 117)) {
            assertPixel(red, picture, x, y, "oval inside")
        }
        for ((x, y) in listOf(2 to 82, 37 to 82, 2 to 117, 37 to 117)) assertPixel(Color.White, picture, x, y, "oval corner")
        for ((x, y) in listOf(60 to 100, 20 to 140, 60 to 140)) assertPixel(Color.White, picture, x, y, "oval outside")
    }

    /**
     * A4.2: a clip cuts hits too. Flutter's RenderClipOval hit tests inside
     * its ellipse only, and no render box is hit outside its size: a tap in
     * the oval's corner or on the overflow misses its child and reaches the
     * probe behind, one at its centre hits; a tap on ClipRect's overflow
     * reaches the probe, one in its corner hits.
     */
    @Test
    fun a4_2_tapsOutsideTheClipMissAndInsideHit() {
        val model = show(
            100, 200, *clips(taps = true),
            state = listOf(counter("rect"), counter("oval"), counter("probe")),
        )

        tap(60, 20)
        tap(20, 60)
        assertCount(0, model, "rect", "the rect's overflow")
        assertCount(2, model, "probe", "the rect's overflow")
        tap(2, 2)
        assertCount(1, model, "rect", "the rect's corner")

        tap(2, 82)
        tap(37, 117)
        tap(60, 100)
        assertCount(0, model, "oval", "the oval's corners and overflow")
        assertCount(5, model, "probe", "the oval's corners and overflow")
        tap(20, 100)
        assertCount(1, model, "oval", "the oval's centre")
        assertCount(5, model, "probe", "the oval's centre")
    }

    // A4.2 DecoratedBox.

    /**
     * A4.2: a DecoratedBox is its child's size and adds no padding for its
     * border (unlike a Container): with a 4 wide border around a 60 x 40
     * Container it is 60 x 40 and the child is not inset, in the
     * background or the foreground; without a child it is the smallest
     * size.
     */
    @Test
    fun a4_2_aDecoratedBoxIsItsChildsSizeWithNoBorderInset() {
        val decoration = mapOf("color" to "#0000FF", "border" to mapOf("width" to 4, "color" to "#000000"))
        show(
            200, 300,
            start("root", "back", "front", "empty"),
            node("back", "DecoratedBox", "c1", props = mapOf("decoration" to decoration)),
            node("front", "DecoratedBox", "c2", props = mapOf("decoration" to decoration, "position" to "foreground")),
            node("empty", "DecoratedBox", props = mapOf("decoration" to decoration)),
            container("c1", props = sized(60, 40)),
            container("c2", props = sized(60, 40)),
        )
        assertEquals(DpRect(0.dp, 0.dp, 60.dp, 40.dp), bounds("back"))
        assertEquals(bounds("back"), bounds("c1"))
        assertEquals(DpRect(0.dp, 40.dp, 60.dp, 80.dp), bounds("front"))
        assertEquals(bounds("front"), bounds("c2"))
        assertEquals(0.dp to 0.dp, bounds("empty").width to bounds("empty").height)
    }

    /**
     * A4.2: the decoration is drawn behind the child, or over it with
     * `position: foreground`. Behind: the border and the blue fill show
     * around a 20 x 20 red square in the middle of a 60 x 40 child, which
     * is drawn over the fill. In front, over a 60 x 40 red child: the
     * border covers the child's edge and the 50% blue fill tints it; a
     * shadow (black, 10 down and right, no blur) is drawn over the child
     * too, beneath the fill, as Flutter paints a foreground decoration
     * whole after its child, and outside the box.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_2_aDecoratedBoxPaintsBehindItsChildOrOverIt() {
        val border = mapOf("width" to 4, "color" to "#000000")
        val shadow = mapOf("color" to "#000000", "offset" to mapOf("dx" to 10, "dy" to 10))
        show(
            200, 300,
            // y 0..40; 60..100 (its shadow to 110).
            start("root", "back", "gap", "front"),
            node("back", "DecoratedBox", "c1", props = mapOf("decoration" to mapOf("color" to "#0000FF", "border" to border))),
            sizedBox("gap", 10, 20),
            node(
                "front", "DecoratedBox", "c2",
                props = mapOf(
                    "decoration" to mapOf("color" to "#0000FF80", "border" to border, "boxShadow" to listOf(shadow)),
                    "position" to "foreground",
                ),
            ),
            container("c1", "dot", props = sized(60, 40) + ("alignment" to "center")),
            container("dot", props = sized(20, 20, "#FF0000")),
            container("c2", props = sized(60, 40, "#FF0000")),
        )
        val picture = draw(requireNotNull(view))

        assertPixel(black, picture, 1, 1, "back border")
        assertPixel(blue, picture, 8, 20, "back fill")
        assertPixel(red, picture, 30, 20, "the child over the fill")

        assertPixel(black, picture, 1, 61, "front border over the child")
        assertPixel(Color(0.5f, 0f, 0.5f), picture, 8, 66, "front fill over the child, no shadow there")
        assertPixel(Color(0f, 0f, 0.5f), picture, 30, 80, "front fill over the shadow over the child")
        assertPixel(black, picture, 65, 105, "front shadow outside the box")
    }

    /**
     * A4.2: Flutter's RenderDecoratedBox is hit wherever its decoration is
     * (BoxDecoration.hitTest: the whole box, or its rounded rect with a
     * borderRadius), filled or not, so the probe behind gets no tap there:
     * a border only, a borderRadius 20 (whose corner outside the radius
     * lets the tap through), and no decoration at all, each around a
     * 60 x 40 SizedBox. Its child still takes its own taps.
     */
    @Test
    fun a4_2_aDecoratedBoxTakesTheTapsOverItsBox() {
        val border = mapOf("border" to mapOf("width" to 4, "color" to "#000000"))
        fun at(id: String, top: Int, child: String) =
            node(id, "Positioned", child, props = mapOf("left" to 10, "top" to top))
        val model = show(
            200, 300,
            node("page", "Stack", "probe", "p1", "p2", "p3", "p4"),
            gesture("probe", "behind", "probe"),
            sizedBox("behind", 200, 300),
            // y 10..50, 70..110, 130..170, 190..230.
            at("p1", 10, "bordered"),
            at("p2", 70, "rounded"),
            at("p3", 130, "bare"),
            at("p4", 190, "parent"),
            node("bordered", "DecoratedBox", "s1", props = mapOf("decoration" to border)),
            node("rounded", "DecoratedBox", "s2", props = mapOf("decoration" to border + ("borderRadius" to 20))),
            node("bare", "DecoratedBox", "s3"),
            node("parent", "DecoratedBox", "g", props = mapOf("decoration" to mapOf("borderRadius" to 20))),
            sizedBox("s1", 60, 40),
            sizedBox("s2", 60, 40),
            sizedBox("s3", 60, 40),
            gesture("g", "s4", "child"),
            sizedBox("s4", 60, 40),
            state = listOf(counter("probe"), counter("child")),
        )
        assertEquals(DpRect(10.dp, 70.dp, 70.dp, 110.dp), bounds("rounded"))

        tap(40, 30)
        assertCount(0, model, "probe", "the centre of a border-only box")
        tap(40, 90)
        assertCount(0, model, "probe", "the centre of a rounded box")
        tap(12, 72)
        assertCount(1, model, "probe", "a rounded box's corner, outside the radius")
        tap(40, 150)
        assertCount(1, model, "probe", "the centre of a box with no decoration")
        tap(150, 150)
        assertCount(2, model, "probe", "beside the boxes")

        tap(40, 210)
        tap(12, 192)
        assertCount(2, model, "child", "the child's own taps, its corner included")
        assertCount(2, model, "probe", "nothing through the child")
    }

    // A4.3 ColorFiltered.

    /**
     * A4.3: ColorFiltered blends its colour (the source) with every pixel of
     * its child (the destination) by Flutter's BlendMode formulas. The colour
     * is green at 50%; the child is opaque red on the left (D1) and blue at
     * 50% on the right (D2); read over white, inside the child:
     *
     * | mode     | D1            | D2               |
     * | multiply | (.5, 0, 0)    | (.25, .5, .5)    |
     * | srcIn    | (.5, 1, .5)   | (.75, 1, .75)    |
     * | dstIn    | (1, .5, .5)   | (.75, .75, 1)    |
     * | dstATop  | (1, .5, .5)   | (.5, .75, .75)   |
     * | srcATop  | (.5, .5, 0)   | (.5, .75, .75)   |
     *
     * With no colour and no mode (transparent, srcATop) the child is
     * unchanged: red, and blue at 50% over white (.5, .5, 1).
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a4_3_colorFilteredBlendsItsColourWithTheChildByTheMode() {
        val modes = listOf("multiply", "srcIn", "dstIn", "dstATop", "srcATop", null)
        show(
            100, 200,
            // Each 40 x 20, one under the other: D1 x 0..20, D2 x 20..40.
            start("root", *modes.indices.map { "f$it" }.toTypedArray()),
            *modes.flatMapIndexed { i, mode ->
                val props = if (mode == null) emptyMap() else mapOf("color" to "#00FF0080", "blendMode" to mode)
                listOf(
                    node("f$i", "ColorFiltered", "r$i", props = props),
                    tightRow("r$i", "d1_$i", "d2_$i"),
                    container("d1_$i", props = sized(20, 20, "#FF0000")),
                    container("d2_$i", props = sized(20, 20, "#0000FF80")),
                )
            }.toTypedArray(),
        )
        assertEquals(DpRect(0.dp, 20.dp, 40.dp, 40.dp), bounds("f1"))
        val expected = listOf(
            Color(0.5f, 0f, 0f) to Color(0.25f, 0.5f, 0.5f),
            Color(0.5f, 1f, 0.5f) to Color(0.75f, 1f, 0.75f),
            Color(1f, 0.5f, 0.5f) to Color(0.75f, 0.75f, 1f),
            Color(1f, 0.5f, 0.5f) to Color(0.5f, 0.75f, 0.75f),
            Color(0.5f, 0.5f, 0f) to Color(0.5f, 0.75f, 0.75f),
            red to Color(0.5f, 0.5f, 1f),
        )
        val picture = draw(requireNotNull(view))
        for ((i, pair) in expected.withIndex()) {
            val y = i * 20 + 10
            val name = modes[i] ?: "default"
            for (x in listOf(2, 10, 17)) assertPixel(pair.first, picture, x, y, "$name D1")
            for (x in listOf(22, 30, 37)) assertPixel(pair.second, picture, x, y, "$name D2")
        }
    }
}
