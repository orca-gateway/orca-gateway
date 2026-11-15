package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.getAlignmentLinePosition
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * A1.1, A1.2, A1.3 and A1.11 (Text part): Flutter's `Text` at 1 dp per
 * pixel with real font metrics. Line height is a multiple of the font
 * size, word spacing widens each space, the decorations Compose cannot draw
 * (an overline, a dashed line, a decorationColor) are drawn, the four
 * overflow modes behave as Flutter's, and `left`/`right` stay absolute.
 * Each Text is tagged with its node id.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TextTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /** A page drawn from its root inside a loose box at the top left of the window. */
    private fun textPage(
        vararg nodes: ComponentNode,
        width: Dp = 300.dp,
        height: Dp = 200.dp,
        direction: LayoutDirection = LayoutDirection.Ltr,
    ) {
        val model = OrcaPageModel(page(*nodes)).apply {
            builders = WidgetBuilders.standard().apply {
                register("Text") { node, _, modifier -> TextWidget(node, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            // The window wraps its content: a fixed outer box leaves room past the text's box.
            Box(Modifier.size(320.dp, 240.dp), contentAlignment = AbsoluteAlignment.TopLeft) {
                CompositionLocalProvider(LocalLayoutDirection provides direction) {
                    Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
                }
            }
        }
    }

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    private fun style(vararg style: Pair<String, Any?>): Pair<String, JsonValue> = "style" to JsonValue.obj(*style)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun layout(tag: String): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag(tag).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single()
    }

    /** A1.1: the line box is `height` times the font size (Flutter's), 16 x 1.5 = 24. */
    @Test
    fun a1_1_lineHeightIsTheHeightTimesTheFontSize() {
        textPage(text("t", "Hello", props() + style("fontSize" to 16, "height" to 1.5)))
        assertEquals(24f, bounds("t").height.value, 0.5f)
    }

    /** A1.1: `wordSpacing` 4 widens a text with one space by 4. */
    @Test
    fun a1_1_wordSpacingWidensEachSpace() {
        textPage(
            column("0", "1", "2"),
            text("1", "a b", props() + style("fontSize" to 16)),
            text("2", "a b", props() + style("fontSize" to 16, "wordSpacing" to 4)),
        )
        val extra = bounds("2").width - bounds("1").width
        assertTrue(abs(extra.value - 4f) <= 1f, "word spacing added $extra")
    }

    /** A1.1: an overline is drawn at the top of the line, in decorationColor. */
    @Test
    fun a1_1_overlineIsDrawnAtTheLineTopInTheDecorationColor() {
        textPage(
            text(
                "t", "HHHHHH",
                props() + style("fontSize" to 20, "decoration" to "overline", "decorationColor" to "#FF0000"),
            ),
        )
        val picture = picture()
        val box = bounds("t")
        val top = box.top.value.roundToInt()
        for (x in columns(box)) {
            assertTrue((top until top + 3).any { isColour(picture.getPixel(x, it), RED) }, "no overline at x $x")
        }
        val below = (top + 4 until box.bottom.value.roundToInt()).count { y ->
            columns(box).any { isColour(picture.getPixel(it, y), RED) }
        }
        assertEquals(0, below, "red rows under the line top")
    }

    /**
     * A1.1: in a line taller than the font (height 1.5) the overline sits at
     * the font's ascent, as Flutter's paragraph draws it: below the top
     * half-leading, (line height - font height) / 2 under the line top.
     */
    @Test
    fun a1_1_overlineSitsAtTheFontAscentInATallLine() {
        textPage(
            column("0", "1", "2"),
            text(
                "1", "HHHHHH",
                props() + style("fontSize" to 40, "height" to 1.5, "decoration" to "overline", "decorationColor" to "#FF0000"),
            ),
            text("2", "HHHHHH", props() + style("fontSize" to 40)),
        )
        val picture = picture()
        val box = bounds("1")
        val leading = (box.height - bounds("2").height).value / 2
        assertTrue(leading >= 4f, "the line is not taller than the font: half-leading $leading")
        val reds = (box.top.value.roundToInt() until box.bottom.value.roundToInt()).filter { y ->
            columns(box).all { isColour(picture.getPixel(it, y), RED) }
        }
        assertTrue(reds.isNotEmpty(), "no overline")
        val offset = reds.first() - box.top.value
        assertTrue(abs(offset - leading) <= 2f, "overline $offset under the line top, the half-leading is $leading")
    }

    /** A1.1: a dashed underline below the baseline, with gaps between the dashes. */
    @Test
    fun a1_1_dashedUnderlineHasGaps() {
        textPage(
            text(
                "t", "HHHHHHHHHH",
                props() + style(
                    "fontSize" to 28, "decoration" to "underline", "decorationStyle" to "dashed",
                    "decorationColor" to "#FF0000",
                ),
            ),
        )
        val picture = picture()
        val box = bounds("t")
        val xs = columns(box, step = 1)
        val row = (box.top.value.roundToInt() until box.bottom.value.roundToInt())
            .maxBy { y -> xs.count { isColour(picture.getPixel(it, y), RED) } }
        val red = xs.map { isColour(picture.getPixel(it, row), RED) }
        assertTrue(red.count { it } > xs.size / 3, "no underline drawn")
        assertTrue(row > (box.top + baseline("t")).value, "the line at $row is not under the baseline")
        val gaps = red.zipWithNext().count { (a, b) -> a && !b }
        assertTrue(gaps >= 3, "$gaps gaps in a dashed underline")
    }

    /** A1.11: the underline takes decorationColor, not the text colour. */
    @Test
    fun a1_11_decorationColorIsDrawn() {
        textPage(
            text(
                "t", "HHHHHH",
                props() + style("fontSize" to 20, "decoration" to "underline", "decorationColor" to "#0000FF"),
            ),
        )
        val picture = picture()
        val box = bounds("t")
        val baseline = (box.top + baseline("t")).value.roundToInt()
        val xs = columns(box)
        val underline = (baseline until box.bottom.value.roundToInt()).any { y ->
            xs.all { isColour(picture.getPixel(it, y), BLUE) }
        }
        assertTrue(underline, "no blue underline under the baseline")
    }

    /**
     * A1.2: `clip` (and no overflow at all, Flutter's default) cuts the line
     * at the box: the letters run to its edge, no ellipsis, nothing past it.
     */
    @Test
    fun a1_2_clipCutsAtTheBoxWithoutAnEllipsis() {
        textPage(
            column("0", "1", "2"),
            text("1", LONG, props("softWrap" to false, "overflow" to "clip") + PLAIN),
            text("2", LONG, props("softWrap" to false) + PLAIN),
            width = 100.dp,
        )
        val picture = picture()
        for (tag in listOf("1", "2")) {
            assertTrue(capInk(picture, tag, 86..99), "$tag: no letter at the box edge")
            assertFalse(capInk(picture, tag, 101..319) || dotInk(picture, tag, 101..319), "$tag paints past the box")
        }
    }

    /** A1.2: `ellipsis` ends the cut line with an ellipsis: dots on the baseline, no letter. */
    @Test
    fun a1_2_ellipsisEndsTheLineWithAnEllipsis() {
        textPage(text("t", LONG, props("softWrap" to false, "overflow" to "ellipsis") + PLAIN), width = 100.dp)
        assertEllipsized(picture(), "t")
    }

    /** A1.2: with no `overflow` on the Text, its style's `overflow` applies (Flutter). */
    @Test
    fun a1_2_styleOverflowAppliesWhenTheTextHasNone() {
        textPage(
            text("t", LONG, props("softWrap" to false) + style("fontSize" to 20, "color" to "#000000", "overflow" to "ellipsis")),
            width = 100.dp,
        )
        assertEllipsized(picture(), "t")
    }

    /** A1.2: `visible` paints the line past the box. */
    @Test
    fun a1_2_visiblePaintsPastTheBox() {
        textPage(text("t", LONG, props("softWrap" to false, "overflow" to "visible") + BLACK_BAND), width = 100.dp)
        val picture = picture()
        assertTrue(luminance(picture.getPixel(150, middle("t"))) < 0.2f, "nothing drawn past the box")
    }

    /**
     * A1.2: `fade` on a line cut at the width fades the last ellipsis-width
     * of the box to transparent (Flutter's horizontal overflow shader).
     */
    @Test
    fun a1_2_fadeFadesTheLastEllipsisWidth() {
        textPage(text("t", LONG, props("softWrap" to false, "overflow" to "fade") + BLACK_BAND), width = 100.dp)
        val picture = picture()
        val y = middle("t")
        val start = luminance(picture.getPixel(50, y))
        val inside = luminance(picture.getPixel(92, y))
        val end = luminance(picture.getPixel(99, y))
        assertTrue(start < 0.1f, "faded at x 50: $start")
        assertTrue(inside in 0.1f..0.9f, "not fading at x 92: $inside")
        assertTrue(end > 0.8f, "not faded out at x 99: $end")
        assertTrue((102 until 300 step 4).all { luminance(picture.getPixel(it, y)) > 0.9f }, "paints past the box")
    }

    /**
     * A1.2: `fade` on a wrapped line cut by maxLines fades the bottom half
     * ellipsis-height instead (Flutter's vertical overflow shader).
     */
    @Test
    fun a1_2_fadeOnALineCutByMaxLinesFadesItsBottom() {
        textPage(text("t", "HHHH HHHH HHHH HHHH HHHH", props("maxLines" to 1, "overflow" to "fade") + BLACK_BAND), width = 100.dp)
        val picture = picture()
        val box = bounds("t")
        val x = box.left.value.roundToInt() + 3
        val top = luminance(picture.getPixel(x, box.top.value.roundToInt() + 2))
        val bottom = luminance(picture.getPixel(x, box.bottom.value.roundToInt() - 1))
        assertTrue(top < 0.1f, "faded at the top: $top")
        assertTrue(bottom > 0.8f, "not faded at the bottom: $bottom")
    }

    /** A1.3: `justify` stretches every line but the last to the box; `left` does not. */
    @Test
    fun a1_3_justifyStretchesEveryLineButTheLast() {
        val words = "abc abc abc abc abc abc abc"
        textPage(
            column("0", "1", "2", props = props("crossAxisAlignment" to "stretch")),
            text("1", words, props("textAlign" to "justify") + style("fontSize" to 16)),
            text("2", words, props("textAlign" to "left") + style("fontSize" to 16)),
            width = 100.dp,
        )
        val picture = picture()
        val justified = layout("1")
        assertTrue(justified.lineCount >= 2, "one line")
        assertTrue(rightmost(picture, "1", justified, 0) >= 96, "first justified line not stretched")
        assertTrue(rightmost(picture, "1", justified, justified.lineCount - 1) < 60, "last line stretched")
        assertTrue(rightmost(picture, "2", layout("2"), 0) < 94, "left-aligned line stretched")
    }

    /** A1.3: `left` and `right` are absolute: right to left does not flip them (`start` does follow). */
    @Test
    fun a1_3_leftAndRightStayAbsoluteInRtl() {
        textPage(
            column("0", "1", "2", "3", props = props("crossAxisAlignment" to "stretch")),
            text("1", "Hi", props("textAlign" to "left") + style("fontSize" to 16)),
            text("2", "Hi", props("textAlign" to "right") + style("fontSize" to 16)),
            text("3", "Hi", props("textAlign" to "start") + style("fontSize" to 16)),
            width = 200.dp,
            direction = LayoutDirection.Rtl,
        )
        val picture = picture()
        assertTrue(inks(picture, "1").all { it < 40 }, "left text not on the left")
        assertTrue(inks(picture, "2").all { it > 160 }, "right text not on the right")
        assertTrue(inks(picture, "3").all { it > 160 }, "start text not on the right in RTL")
    }

    /** The line ends in dots on the baseline: no letter in its last 8 columns, inside the box. */
    private fun assertEllipsized(picture: Bitmap, tag: String) {
        val end = (0 until picture.width).last { x -> capInk(picture, tag, x..x) || dotInk(picture, tag, x..x) }
        assertTrue(end < 100, "drawn past the box, to $end")
        assertFalse(capInk(picture, tag, end - 8..end), "a letter at the end ($end), no ellipsis")
        assertTrue(dotInk(picture, tag, end - 2..end), "no dot at the end ($end)")
    }

    /** Dark pixels in [xs] at the height of a capital's upper half (not of an ellipsis' dots). */
    private fun capInk(picture: Bitmap, tag: String, xs: IntRange): Boolean {
        val baseline = (bounds(tag).top + baseline(tag)).value.roundToInt()
        return ink(picture, xs, baseline - 12..baseline - 7)
    }

    /** Dark pixels in [xs] just above the baseline, where an ellipsis' dots sit. */
    private fun dotInk(picture: Bitmap, tag: String, xs: IntRange): Boolean {
        val baseline = (bounds(tag).top + baseline(tag)).value.roundToInt()
        return ink(picture, xs, baseline - 3..baseline - 1)
    }

    private fun ink(picture: Bitmap, xs: IntRange, ys: IntRange): Boolean =
        xs.any { x -> x in 0 until picture.width && ys.any { y -> luminance(picture.getPixel(x, y)) < 0.5f } }

    private fun baseline(tag: String): Dp = compose.onNodeWithTag(tag).getAlignmentLinePosition(FirstBaseline)

    private fun middle(tag: String): Int = bounds(tag).let { ((it.top + it.bottom) / 2).value.roundToInt() }

    /** Columns inside the text box, 2 dp in from each side. */
    private fun columns(box: DpRect, step: Int = 3): List<Int> =
        (box.left.value.roundToInt() + 2 until box.right.value.roundToInt() - 2 step step).toList()

    /** The x of every dark pixel of a text. */
    private fun inks(picture: Bitmap, tag: String): List<Int> {
        val box = bounds(tag)
        val xs = (0 until picture.width)
        val ys = (box.top.value.roundToInt() until box.bottom.value.roundToInt())
        return ys.flatMap { y -> xs.filter { luminance(picture.getPixel(it, y)) < 0.5f } }.also {
            assertTrue(it.isNotEmpty(), "text $tag not drawn")
        }
    }

    /** The rightmost dark pixel on a line of a text. */
    private fun rightmost(picture: Bitmap, tag: String, layout: TextLayoutResult, line: Int): Int {
        val top = bounds(tag).top.value.roundToInt()
        val ys = (top + layout.getLineTop(line).roundToInt() until top + layout.getLineBottom(line).roundToInt())
        return ys.maxOf { y -> (0 until picture.width).lastOrNull { luminance(picture.getPixel(it, y)) < 0.5f } ?: -1 }
    }

    private fun picture(): Bitmap {
        compose.waitForIdle()
        return draw(requireNotNull(view))
    }

    /** The view drawn in software on white, as GoldenTest draws it. */
    private fun draw(view: View): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun luminance(pixel: Int): Float =
        (android.graphics.Color.red(pixel) + android.graphics.Color.green(pixel) + android.graphics.Color.blue(pixel)) / 765f

    private fun isColour(pixel: Int, rgb: Triple<Int, Int, Int>): Boolean {
        val channels = listOf(
            rgb.first to android.graphics.Color.red(pixel),
            rgb.second to android.graphics.Color.green(pixel),
            rgb.third to android.graphics.Color.blue(pixel),
        )
        return channels.all { (want, got) -> abs(want - got) < 80 }
    }

    private companion object {
        val RED = Triple(255, 0, 0)
        val BLUE = Triple(0, 0, 255)
        const val LONG = "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHH"

        /** Black text, 20 high: capitals reach 14 above the baseline, an ellipsis' dots 3. */
        val PLAIN: Map<String, JsonValue> = mapOf("style" to JsonValue.obj("fontSize" to 20, "color" to "#000000"))

        /** Black text on a black background: the whole line is a solid band. */
        val BLACK_BAND: Map<String, JsonValue> = mapOf(
            "style" to JsonValue.obj("fontSize" to 20, "color" to "#000000", "backgroundColor" to "#000000"),
        )
    }
}
