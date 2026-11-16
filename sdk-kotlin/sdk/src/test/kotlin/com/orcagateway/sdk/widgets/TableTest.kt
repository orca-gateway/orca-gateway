package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
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
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A7.4 (as corrected): Table as the Flutter SDK's builder makes it
 * (layout_builders.dart:646-666), at 1 dp per pixel on white. Each child is
 * a one-cell row of Flutter's single FlexColumnWidth(1) column: the
 * table's width (the parent's maximum), its own height, rows stacked from
 * the top. `border` sent is TableBorder.all(color ?? black, width ?? 1),
 * painted over the cells: the outer lines inside the table's rect, the
 * lines between rows centred on the row boundaries. columnWidths and
 * defaultColumnWidth are never read. Table is not registered until K-caps
 * (G7): the test registers it, as standard() will.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class TableTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /** The page drawn from its root in a loose [width] x [height] box; Table, SizedBox and Container tagged with their ids. */
    private fun show(width: Dp, height: Dp, vararg nodes: ComponentNode) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + TABLE)
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register(TABLE) { node, model, modifier -> TableWidget(node, model, modifier.testTag(node.id)) }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
                register("Container") { node, model, modifier -> ContainerWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
        }
    }

    private fun table(id: String, vararg rows: String, props: Map<String, Any?> = emptyMap()) =
        ComponentNode(
            id, TABLE, ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi,
            props.mapValues { JsonValue.of(it.value) }, rows.toList(),
        )

    /** A row of [height] filled with [color]: a Container with no child. */
    private fun cell(id: String, height: Int, color: String) =
        ComponentNode(
            id, "Container", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            mapOf("height" to JsonValue.of(height), "color" to JsonValue.of(color)),
        )

    private fun horizontalScroll(id: String, child: String) =
        ComponentNode(
            id, "SingleChildScrollView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            mapOf("scrollDirection" to JsonValue.of("horizontal")), listOf(child),
        )

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    /** The view drawn on white in software, as GoldenTest draws it. */
    private fun draw(): Bitmap {
        compose.waitForIdle()
        val view = requireNotNull(view)
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun assertColor(expected: Int, picture: Bitmap, x: Int, y: Int) {
        val actual = picture.getPixel(x, y)
        val close = intArrayOf(16, 8, 0).all { abs((expected ushr it and 0xFF) - (actual ushr it and 0xFF)) <= 8 }
        assertTrue(close, "($x, $y) is #${Integer.toHexString(actual)}, expected #${Integer.toHexString(expected)}")
    }

    /** A pixel half covered by a black line on white: grey, neither white nor black. */
    private fun assertHalfBlack(picture: Bitmap, x: Int, y: Int) {
        val actual = picture.getPixel(x, y)
        val grey = intArrayOf(16, 8, 0).all { (actual ushr it and 0xFF) in 0x40..0xC0 }
        assertTrue(grey, "($x, $y) is #${Integer.toHexString(actual)}, expected a half-covered grey")
    }

    /**
     * Three children of 30, 20 and 50 dp, whatever their own widths, are
     * rows at y 0, 30 and 50, each the table's width: the loose parent's
     * maximum, 300. The table is as high as its rows.
     */
    @Test
    fun a7_4_kt_tableStacksEachChildAsAFullWidthRowAtItsOwnHeight() {
        show(
            300.dp, 400.dp,
            table("t", "a", "b", "c"),
            sizedBox("a", width = 40, height = 30),
            sizedBox("b", width = 80, height = 20),
            sizedBox("c", width = 10, height = 50),
        )

        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 100.dp), bounds("t"))
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 30.dp), bounds("a"))
        assertEquals(DpRect(0.dp, 30.dp, 300.dp, 50.dp), bounds("b"))
        assertEquals(DpRect(0.dp, 50.dp, 300.dp, 100.dp), bounds("c"))
    }

    /**
     * A 4 dp #FF00FF border over red, green and blue rows of 40, 30 and 50:
     * the outer lines fill 4 dp inside the 200 x 120 rect (nothing outside
     * it), the lines between rows 2 dp either side of y 40 and 70, over the
     * cells; the cells show between the lines.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a7_4_kt_tableBorderDrawsTheOuterLinesInsideAndTheRowLinesCentredOverTheCells() {
        show(
            200.dp, 200.dp,
            table("t", "a", "b", "c", props = mapOf("border" to mapOf("color" to "#FF00FF", "width" to 4))),
            cell("a", 40, "#FF0000"),
            cell("b", 30, "#00FF00"),
            cell("c", 50, "#0000FF"),
        )

        assertEquals(DpRect(0.dp, 0.dp, 200.dp, 120.dp), bounds("t"))
        val picture = draw()
        // The outer lines, inside the rect.
        for ((x, y) in listOf(100 to 0, 100 to 3, 0 to 20, 3 to 20, 196 to 20, 199 to 20, 100 to 116, 100 to 119)) {
            assertColor(MAGENTA, picture, x, y)
        }
        assertColor(RED, picture, 100, 4)
        assertColor(RED, picture, 4, 20)
        assertColor(RED, picture, 195, 20)
        assertColor(BLUE, picture, 100, 115)
        assertColor(Color.WHITE, picture, 100, 121)
        // The row lines, centred on y 40 and 70, across the whole width.
        for ((x, y) in listOf(100 to 38, 100 to 41, 10 to 39, 190 to 40, 100 to 68, 100 to 71)) {
            assertColor(MAGENTA, picture, x, y)
        }
        assertColor(RED, picture, 100, 37)
        assertColor(GREEN, picture, 100, 42)
        assertColor(GREEN, picture, 100, 67)
        assertColor(BLUE, picture, 100, 72)
    }

    /**
     * `border: {}` is black and 1 dp wide: the outer pixel ring of the 200
     * x 70 rect is black, the line between the rows at y 40 half covers the
     * pixels above and below it.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a7_4_kt_tableEmptyBorderIsBlackAndOneWide() {
        show(
            200.dp, 200.dp,
            table("t", "a", "b", props = mapOf("border" to emptyMap<String, Any?>())),
            sizedBox("a", height = 40),
            sizedBox("b", height = 30),
        )

        assertEquals(DpRect(0.dp, 0.dp, 200.dp, 70.dp), bounds("t"))
        val picture = draw()
        for ((x, y) in listOf(100 to 0, 0 to 20, 199 to 20, 100 to 69, 0 to 55, 199 to 55)) {
            assertColor(Color.BLACK, picture, x, y)
        }
        for ((x, y) in listOf(100 to 1, 1 to 20, 198 to 20, 100 to 68, 100 to 70, 100 to 38, 100 to 41)) {
            assertColor(Color.WHITE, picture, x, y)
        }
        assertHalfBlack(picture, 100, 39)
        assertHalfBlack(picture, 100, 40)
    }

    /** No border, no lines: the cells' own colours at the edges and on both sides of each boundary. */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a7_4_kt_tableWithoutBorderDrawsNoLines() {
        show(
            200.dp, 200.dp,
            table("t", "a", "b", "c"),
            cell("a", 40, "#FF0000"),
            cell("b", 30, "#00FF00"),
            cell("c", 50, "#0000FF"),
        )

        val picture = draw()
        for ((x, y) in listOf(100 to 0, 0 to 20, 199 to 20, 100 to 39)) assertColor(RED, picture, x, y)
        for ((x, y) in listOf(100 to 40, 0 to 55, 199 to 55, 100 to 69)) assertColor(GREEN, picture, x, y)
        for ((x, y) in listOf(100 to 70, 100 to 119)) assertColor(BLUE, picture, x, y)
        assertColor(Color.WHITE, picture, 100, 120)
    }

    /**
     * columnWidths and defaultColumnWidth sent change nothing: the second
     * table's rows have the first one's bounds, one table lower.
     */
    @Test
    fun a7_4_kt_tableColumnWidthsAndDefaultColumnWidthChangeNothing() {
        show(
            300.dp, 400.dp,
            column("root", "plain", "sent"),
            table("plain", "a1", "b1"),
            table("sent", "a2", "b2", props = mapOf("columnWidths" to mapOf("0" to 50), "defaultColumnWidth" to 80)),
            sizedBox("a1", width = 40, height = 30),
            sizedBox("b1", width = 120, height = 20),
            sizedBox("a2", width = 40, height = 30),
            sizedBox("b2", width = 120, height = 20),
        )

        val plain = bounds("plain")
        assertEquals(300.dp to 50.dp, plain.width to plain.height)
        for ((one, two) in listOf("plain" to "sent", "a1" to "a2", "b1" to "b2")) {
            val first = bounds(one)
            assertEquals(DpRect(first.left, first.top + 50.dp, first.right, first.bottom + 50.dp), bounds(two), two)
        }
    }

    /**
     * Unbounded width (a horizontal scroll, minimum 0): Flutter's flex
     * column has no intrinsic width (FlexColumnWidth.maxIntrinsicWidth is
     * 0, rendering/table.dart:212-214) and grows only to the minimum, so the
     * table and its rows are 0 wide, the rows their own heights.
     */
    @Test
    fun a7_4_kt_tableUnderUnboundedWidthIsItsMinimumWidthZeroWide() {
        show(
            300.dp, 200.dp,
            horizontalScroll("s", "t"),
            table("t", "a", "b"),
            sizedBox("a", width = 50, height = 30),
            sizedBox("b", width = 120, height = 20),
        )

        val table = bounds("t")
        assertEquals(0.dp to 50.dp, table.width to table.height)
        val a = bounds("a")
        assertEquals(0.dp to 30.dp, a.width to a.height)
        val b = bounds("b")
        assertEquals(DpRect(table.left, table.top + 30.dp, table.left, table.top + 50.dp), b)
    }

    private companion object {
        const val TABLE = "Table"
        val RED = Color.rgb(0xFF, 0, 0)
        val GREEN = Color.rgb(0, 0xFF, 0)
        val BLUE = Color.rgb(0, 0, 0xFF)
        val MAGENTA = Color.rgb(0xFF, 0, 0xFF)
    }
}
