package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.test.assertTrue

/**
 * A5.7 on Android: Flutter's Scrollbar there (material_ui scrollbar.dart)
 * is a square thumb, 4 dp thick by default, the colour of the light
 * theme's highlightColor made opaque (#BCBCBC), at least 48 long, along the
 * far edge of the Scrollbar of the scroll view directly inside it. It
 * shows while that view scrolls and fades 600 ms after the scroll ends,
 * over 300 ms; thumbVisibility keeps it. Without a Scrollbar there is no
 * thumb (Flutter on mobile), nor for a scroll view nested in the one the
 * Scrollbar follows. A view of 100 x 100 over content 300 long has a
 * thumb 48 long that travels 52 as the offset goes 0 to 200; a drag of 60
 * (less the touch slop) puts it between y 10 and 64, so (98, 50) is on it
 * and (98, 2) and (90, 50) are not. Pixels at 1 dp per pixel on white,
 * the clock moved by hand.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScrollbarTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View
    private val thumb = Props.hex("#BCBCBC")

    /** A page drawn from its root in a 100 x 100 box that forces its size, Scrollbar and the scroll views tagged with their ids. */
    private fun show(vararg nodes: ComponentNode, direction: LayoutDirection = LayoutDirection.Ltr) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "Scrollbar")
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Scrollbar") { node, model, modifier -> ScrollbarWidget(node, model, modifier.testTag(node.id)) }
                register("SingleChildScrollView") { node, model, modifier ->
                    ScrollWidget(node, model, modifier.testTag(node.id))
                }
            }
        }
        compose.mainClock.autoAdvance = false
        compose.setContent {
            view = LocalView.current
            CompositionLocalProvider(LocalLayoutDirection provides direction) {
                Box(Modifier.size(100.dp, 100.dp), propagateMinConstraints = true) { NodeView(nodes.first().id, model) }
            }
        }
        compose.mainClock.advanceTimeBy(1_000)
    }

    private fun scrollbar(id: String, child: String, vararg props: Pair<String, Any?>) = ComponentNode(
        id, "Scrollbar", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        props.associate { (key, value) -> key to JsonValue.of(value) }, listOf(child),
    )

    private fun scrollView(id: String, child: String, horizontal: Boolean = false) = ComponentNode(
        id, "SingleChildScrollView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        if (horizontal) mapOf("scrollDirection" to JsonValue.String("horizontal")) else emptyMap(), listOf(child),
    )

    /** A finger put down on [tag] at ([x], [y]) that moves by ([dx], [dy]) and stays down. */
    private fun drag(tag: String, x: Float, y: Float, dx: Float, dy: Float) {
        compose.onNodeWithTag(tag).performTouchInput {
            down(Offset(x, y))
            repeat(6) { moveBy(Offset(dx / 6, dy / 6)) }
        }
    }

    private fun lift(tag: String) {
        compose.onNodeWithTag(tag).performTouchInput { up() }
    }

    /** A5.7 (kt ui): dragging the view inside a Scrollbar shows the thumb, 4 wide, on the far edge, where the offset puts it. */
    @Test
    fun a5_7_kt_aThumbShowsWhileScrolling() {
        show(scrollbar("bar", "s"), scrollView("s", "b"), sizedBox("b", 40, 300))
        assertPixel(Color.White, 98, 50, "no thumb before a scroll")

        drag("s", 50f, 80f, 0f, -60f)
        compose.mainClock.advanceTimeBy(400)

        val picture = draw()
        assertPixel(thumb, 98, 50, "on the thumb", picture)
        assertPixel(thumb, 96, 50, "the thumb's first column", picture)
        assertPixel(Color.White, 95, 50, "left of the 4-wide thumb", picture)
        assertPixel(Color.White, 98, 2, "above the thumb, which has moved down", picture)
    }

    /** A5.7 (kt ui): the thumb stays 600 ms after the scroll ends, then fades out over 300 ms. */
    @Test
    fun a5_7_kt_theThumbIsGoneAfterTheFade() {
        show(scrollbar("bar", "s"), scrollView("s", "b"), sizedBox("b", 40, 300))
        drag("s", 50f, 80f, 0f, -60f)
        compose.mainClock.advanceTimeBy(400)
        lift("s")

        compose.mainClock.advanceTimeBy(450)
        assertPixel(thumb, 98, 50, "kept 450 ms after the scroll ended")
        compose.mainClock.advanceTimeBy(600)
        assertPixel(Color.White, 98, 50, "gone 1,050 ms after it")
    }

    /** A5.7 (kt ui): with thumbVisibility the thumb shows before any scroll and stays long after one. */
    @Test
    fun a5_7_kt_thumbVisibilityKeepsTheThumb() {
        show(scrollbar("bar", "s", "thumbVisibility" to true), scrollView("s", "b"), sizedBox("b", 40, 300))
        assertPixel(thumb, 98, 24, "shown at offset 0 with no scroll")
        assertPixel(Color.White, 98, 60, "below the 48-long thumb")

        drag("s", 50f, 80f, 0f, -60f)
        compose.mainClock.advanceTimeBy(400)
        lift("s")
        compose.mainClock.advanceTimeBy(5_000)
        assertPixel(thumb, 98, 50, "still shown 5 s after the scroll ended")
    }

    /** A5.7 (kt ui): the thickness prop sets the thumb's width. */
    @Test
    fun a5_7_kt_thicknessSetsTheThumbsWidth() {
        show(scrollbar("bar", "s", "thumbVisibility" to true, "thickness" to 10), scrollView("s", "b"), sizedBox("b", 40, 300))
        val picture = draw()
        assertPixel(thumb, 90, 24, "the thumb's first column", picture)
        assertPixel(Color.White, 89, 24, "left of the 10-wide thumb", picture)
    }

    /** A5.7 (kt ui): right to left, a vertical view's thumb is on the left edge. */
    @Test
    fun a5_7_kt_rightToLeftAVerticalThumbIsOnTheLeft() {
        show(
            scrollbar("bar", "s", "thumbVisibility" to true), scrollView("s", "b"), sizedBox("b", 40, 300),
            direction = LayoutDirection.Rtl,
        )
        val picture = draw()
        assertPixel(thumb, 1, 24, "on the left edge", picture)
        assertPixel(Color.White, 98, 24, "nothing on the right edge", picture)
    }

    /** A5.7 (kt ui): a horizontal view's thumb runs along the bottom, from the left at offset 0. */
    @Test
    fun a5_7_kt_aHorizontalThumbRunsAlongTheBottom() {
        show(scrollbar("bar", "s", "thumbVisibility" to true), scrollView("s", "b", horizontal = true), sizedBox("b", 300, 40))
        val picture = draw()
        assertPixel(thumb, 24, 98, "on the bottom edge", picture)
        assertPixel(thumb, 24, 96, "the thumb's top row", picture)
        assertPixel(Color.White, 24, 95, "above the 4-thick thumb", picture)
        assertPixel(Color.White, 75, 98, "right of the 48-long thumb", picture)
    }

    /** A5.7 (kt ui): right to left, a horizontal view starts at the right (Flutter's axis left), and so does its thumb. */
    @Test
    fun a5_7_kt_rightToLeftAHorizontalThumbStartsAtTheRight() {
        show(
            scrollbar("bar", "s", "thumbVisibility" to true), scrollView("s", "b", horizontal = true), sizedBox("b", 300, 40),
            direction = LayoutDirection.Rtl,
        )
        val picture = draw()
        assertPixel(thumb, 75, 98, "at the right end of the bottom edge", picture)
        assertPixel(Color.White, 24, 98, "nothing at the left end", picture)
    }

    /** A5.7 (kt ui): a scroll view with no Scrollbar around it draws no thumb, as Flutter on mobile. */
    @Test
    fun a5_7_kt_noThumbWithoutAScrollbar() {
        show(scrollView("s", "b"), sizedBox("b", 40, 300))
        drag("s", 50f, 80f, 0f, -60f)
        compose.mainClock.advanceTimeBy(400)

        val picture = draw()
        assertPixel(Color.White, 98, 50, "no thumb on the right edge", picture)
        assertPixel(Color.White, 98, 20, "nor higher up", picture)
    }

    /**
     * A5.7 (kt ui): only the scroll view directly inside the Scrollbar has a
     * thumb: scrolling a horizontal view nested in it draws none along the
     * bottom, then scrolling the outer view draws the outer's.
     */
    @Test
    fun a5_7_kt_aNestedScrollViewHasNoThumb() {
        show(
            scrollbar("bar", "outer"),
            scrollView("outer", "col"),
            column("col", "frame", "tall"),
            ComponentNode(
                "frame", "SizedBox", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                mapOf("height" to JsonValue.Int(50)), listOf("inner"),
            ),
            scrollView("inner", "wide", horizontal = true),
            sizedBox("wide", 300, 50),
            sizedBox("tall", 40, 250),
        )

        drag("inner", 80f, 25f, -60f, 0f)
        compose.mainClock.advanceTimeBy(400)
        var picture = draw()
        assertPixel(Color.White, 50, 98, "no thumb along the bottom for the nested view", picture)
        assertPixel(Color.White, 98, 50, "nor on the right edge", picture)
        lift("inner")
        compose.mainClock.advanceTimeBy(2_000)

        drag("outer", 50f, 80f, 0f, -60f)
        compose.mainClock.advanceTimeBy(400)
        picture = draw()
        assertPixel(thumb, 98, 50, "the outer view's thumb on the right edge", picture)
    }

    /** The view drawn in software on white, as GoldenTest draws it. */
    private fun draw(): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun assertPixel(expected: Color, x: Int, y: Int, label: String, picture: Bitmap = draw()) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.05f },
            "$label: ($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }
}
