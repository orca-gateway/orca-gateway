package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * A7.1 lines by range (OQ7 a): a RichText span's own line (an overline; a
 * double, wavy, dotted or dashed line; a decorationColor) is drawn under,
 * or for an overline over, that span's run alone, as Flutter's paragraph
 * (SkParagraph Decorations.cpp) paints a decoration per style run. The
 * pages put a blue run with a red line between two black runs: the red
 * stays within the blue run's columns and the black runs' columns hold
 * none. The same cases as Swift's SpanLinesTests. RichText is registered
 * by the test until K-caps (G7). Each RichText sits at the top left of a
 * slot of its own, the slots one under another, drawn in software on white
 * at 1 dp per pixel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SpanLinesTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /**
     * A7.1 lines: an overline in decorationColor is centred on its run's
     * top edge, half of it above (SkParagraph centres it there), above the
     * glyphs, and spans that run alone. The RichText sits 10 dp down so the
     * half above its top is in the picture.
     */
    @Test
    fun a7_1_kt_linesAnOverlineStraddlesItsOwnRunsTopOnly() {
        val top = 10
        val (picture) = draw(between(style("decoration" to "overline", "decorationColor" to RED), fontSize = 28), height = 60, top = top)
        val (run, line) = runAndLine(picture)
        assertTrue(line.top < top, "the overline $line has no half above the RichText's top $top")
        assertTrue(line.bottom > top, "the overline $line has no half below the RichText's top $top")
        assertTrue(line.bottom < run.top, "the overline $line is not above the run's glyphs $run")
        assertOnItsRunOnly(picture, run, line, fontSize = 28)
    }

    /** A7.1 lines: a double underline is two lines of red rows below its run's glyphs, under that run alone. */
    @Test
    fun a7_1_kt_linesADoubleUnderlineDrawsTwoRowsUnderItsOwnRunOnly() {
        val (picture) = draw(between(style("decoration" to "underline", "decorationStyle" to "double", "decorationColor" to RED)))
        val (run, line) = runAndLine(picture)
        assertTrue(line.top > run.midY, "the double line $line is not under the run's glyphs $run")
        assertEquals(2, redRowGroups(picture, run.left + 3 until run.right - 3), "not two lines of red under the run: $line")
        assertOnItsRunOnly(picture, run, line, fontSize = 16)
    }

    /** A7.1 lines: a wavy underline is drawn in decorationColor under its run alone, and waves: its red is taller than a straight line's. */
    @Test
    fun a7_1_kt_linesAWavyLineInDecorationColorUnderItsOwnRunOnly() {
        val (wavy, straight) = draw(
            between(style("decoration" to "underline", "decorationStyle" to "wavy", "decorationColor" to RED), text = "MM", fontSize = 40),
            between(style("decoration" to "underline", "decorationColor" to RED), text = "MM", fontSize = 40, id = "s"),
            width = 320,
            height = 70,
        )
        val (run, line) = runAndLine(wavy)
        val solid = assertNotNull(straight.bounds(::isRed), "a solid underline in decorationColor is not drawn")
        assertTrue(line.height >= solid.height + 1, "the wavy line $line is no taller than a straight one $solid")
        assertTrue(line.top > run.midY, "the wavy line $line is not under the run's glyphs $run")
        assertOnItsRunOnly(wavy, run, line, fontSize = 40)
    }

    /**
     * A7.1 lines: decoration "none" on a child clears the line its parent
     * draws for that child's run alone; the parent's run and a later
     * sibling (which inherits the parent's style) keep it.
     */
    @Test
    fun a7_1_kt_linesNoneOnAChildClearsItsParentsLineForItsRunOnly() {
        val (cleared, plain) = draw(
            rich(
                "t",
                span(
                    "MMM",
                    style("color" to BLACK, "fontSize" to 16, "decoration" to "underline", "decorationStyle" to "wavy", "decorationColor" to RED),
                    span("MMM", style("color" to BLUE, "decoration" to "none")),
                    span("MMM"),
                ),
            ),
            rich("p", span("MMM", style("color" to BLACK, "fontSize" to 16), span("MMM", style("color" to BLUE)), span("MMM"))),
        )
        val blue = assertNotNull(cleared.bounds(::isBlue), "no blue run")
        assertEquals(plain.bounds(::isBlue), blue, "the cleared run has a line of its own colour")
        val red = assertNotNull(cleared.bounds(::isRed), "the parent's line is not drawn")
        assertTrue(red.left < blue.left - 5, "the parent's run lost its line: $red")
        assertTrue(red.right > blue.right + 5, "the later sibling lost the inherited line: $red")
        val under = blue.left + 2 until blue.right - 2
        val crossing = (0 until cleared.height).any { y -> under.any { isRed(cleared.pixel(it, y)) } }
        assertFalse(crossing, "the parent's line runs under the child with decoration none")
    }

    // helpers

    /** A black run, a blue run with [own] over it, a black run: the root span and its two children, [text] each at [fontSize]. */
    private fun between(own: JsonValue, text: String = "MMM", fontSize: Int = 16, id: String = "t"): ComponentNode {
        val blue = JsonValue.Object(own.objectValue.orEmpty() + ("color" to JsonValue.String(BLUE)))
        return rich(id, span(text, style("color" to BLACK, "fontSize" to fontSize), span(text, blue), span(text)))
    }

    private fun rich(id: String, text: JsonValue): ComponentNode =
        ComponentNode(id, "RichText", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, mapOf("text" to text))

    /** A TextSpan: [text], its [style] when one is given, its [children] when there are some. */
    private fun span(text: String, style: JsonValue? = null, vararg children: JsonValue): JsonValue = JsonValue.Object(
        buildMap {
            put("text", JsonValue.String(text))
            style?.let { put("style", it) }
            if (children.isNotEmpty()) put("children", JsonValue.arr(*children))
        },
    )

    private fun style(vararg style: Pair<String, Any?>): JsonValue = JsonValue.obj(*style)

    /**
     * Each of [nodes] (RichTexts) at the top left of a [width] x [height]
     * slot, [top] dp down, the slots one under another on white; the
     * picture of each slot, in order.
     */
    private fun draw(vararg nodes: ComponentNode, width: Int = 240, height: Int = 40, top: Int = 0): List<Pixels> {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "RichText")
        val root = column("0", *nodes.map { it.id }.toTypedArray())
        val model = OrcaPageModel(page(root, *nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("RichText") { node, _, modifier -> RichTextWidget(node, modifier) }
            }
        }
        compose.setContent {
            view = LocalView.current
            Column {
                for (node in nodes) {
                    Box(Modifier.size(width.dp, height.dp).padding(top = top.dp)) { NodeView(node.id, model) }
                }
            }
        }
        compose.waitForIdle()
        val view = requireNotNull(view)
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return nodes.indices.map { Pixels(bitmap, it * height, width, height) }
    }

    /** The blue run's glyphs and the red line's bounds. */
    private fun runAndLine(pixels: Pixels): Pair<Area, Area> {
        val run = assertNotNull(pixels.bounds(::isBlue), "no blue run")
        val line = assertNotNull(pixels.bounds(::isRed), "no line drawn in decorationColor")
        return run to line
    }

    /**
     * The red line spans the blue run and stops at its edges (a glyph's
     * side bearing either way, about a tenth of the [fontSize], and the
     * slanted butt end of a wave); the black runs on both sides are drawn.
     */
    private fun assertOnItsRunOnly(pixels: Pixels, run: Area, line: Area, fontSize: Int) {
        val slack = maxOf(3, fontSize * 3 / 20)
        assertTrue(line.left >= run.left - slack, "the line reaches the run before: $line vs $run")
        assertTrue(line.right <= run.right + slack, "the line reaches the run after: $line vs $run")
        assertTrue(line.width > run.width - 2 * slack, "the line does not span its run: $line vs $run")
        val ink = pixels.bounds(::isInk)
        assertTrue(ink != null && ink.left < run.left - 5 && ink.right > run.right + 5, "the black runs beside it are not drawn: $ink")
    }

    /** How many runs of consecutive rows hold red within [columns]. */
    private fun redRowGroups(pixels: Pixels, columns: IntRange): Int {
        val rows = (0 until pixels.height).filter { y -> columns.any { isRed(pixels.pixel(it, y)) } }
        return rows.filterIndexed { i, y -> i == 0 || rows[i - 1] != y - 1 }.size
    }

    /** Pixel bounds, right and bottom exclusive. */
    private data class Area(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val width: Int get() = right - left
        val height: Int get() = bottom - top
        val midY: Float get() = (top + bottom) / 2f
    }

    /** The [width] x [height] rows of [bitmap] from row [top]. */
    private class Pixels(bitmap: Bitmap, top: Int, val width: Int, val height: Int) {
        private val argb = IntArray(width * height).also { bitmap.getPixels(it, 0, width, 0, top, width, height) }

        fun pixel(x: Int, y: Int): Int = argb[y * width + x]

        /** The bounds of the pixels [matches] accepts, null when none. */
        fun bounds(matches: (Int) -> Boolean): Area? {
            var area: Area? = null
            for (y in 0 until height) {
                for (x in 0 until width) {
                    if (!matches(pixel(x, y))) continue
                    area = area?.let { Area(minOf(it.left, x), minOf(it.top, y), maxOf(it.right, x + 1), maxOf(it.bottom, y + 1)) }
                        ?: Area(x, y, x + 1, y + 1)
                }
            }
            return area
        }
    }

    private companion object {
        const val BLACK = "#000000"
        const val BLUE = "#0000FF"
        const val RED = "#FF0000"

        fun red(pixel: Int) = android.graphics.Color.red(pixel)
        fun green(pixel: Int) = android.graphics.Color.green(pixel)
        fun blue(pixel: Int) = android.graphics.Color.blue(pixel)

        /** Red over white, antialiased edges too (Swift's Pixels.isRed). */
        fun isRed(pixel: Int): Boolean = red(pixel) > 60 && red(pixel) > green(pixel) + 50 && red(pixel) > blue(pixel) + 50

        fun isBlue(pixel: Int): Boolean = blue(pixel) > 175 && red(pixel) < 80 && green(pixel) < 80

        /** Black ink. */
        fun isInk(pixel: Int): Boolean = red(pixel) < 90 && green(pixel) < 90 && blue(pixel) < 90
    }
}
