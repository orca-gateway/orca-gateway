package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.sp
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
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.runBlocking
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
 * A7.1: Flutter's raw `RichText` (primitive_builders.dart:325-348) at 1 dp
 * per pixel with real font metrics. The span tree draws as runs on one
 * line, each in its merged style; what the root leaves unset is the
 * engine's paragraph default (14, white, regular), never the ambient style;
 * no text scaling; start, clip unless `overflow` is sent, `maxLines`; a span
 * bound to page state redraws when the state changes. RichText is not
 * registered until K-caps (G7): the test registers [RichTextWidget] for it,
 * as standard() will. Each RichText and Text is tagged with its node id;
 * the view is drawn in software on white unless a test asks for black.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class RichTextTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /** A page of [nodes] (the first the root) whose core knows RichText and whose RichTexts and Texts are tagged. */
    private fun model(vararg nodes: ComponentNode, state: List<StateDefinition> = emptyList()): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "RichText")
        return OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("RichText") { node, _, modifier -> RichTextWidget(node, modifier.testTag(node.id)) }
                register("Text") { node, _, modifier -> TextWidget(node, modifier.testTag(node.id)) }
            }
        }
    }

    /** [content] at the top left of a 320 x 240 window, on [background] (none: the white the picture starts from). */
    private fun show(background: Color = Color.Unspecified, content: @Composable () -> Unit) {
        compose.setContent {
            view = LocalView.current
            val fill = if (background == Color.Unspecified) Modifier else Modifier.background(background)
            Box(Modifier.size(320.dp, 240.dp).then(fill), contentAlignment = AbsoluteAlignment.TopLeft) { content() }
        }
    }

    /** The root of [nodes] drawn in a loose box of [width] x 200. */
    private fun richPage(
        vararg nodes: ComponentNode,
        width: Dp = 300.dp,
        state: List<StateDefinition> = emptyList(),
        background: Color = Color.Unspecified,
    ): OrcaPageModel {
        val model = model(*nodes, state = state)
        show(background) { Box(Modifier.size(width, 200.dp)) { NodeView(nodes.first().id, model) } }
        return model
    }

    private fun rich(id: String, text: JsonValue, vararg props: Pair<String, Any?>, watches: List<String> = emptyList()) =
        ComponentNode(
            id, "RichText", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
            props.associate { (key, value) -> key to JsonValue.of(value) } + ("text" to text),
            watches = watches,
        )

    /** A TextSpan: [text], its [style] when one is given, its [children] when there are some. */
    private fun span(text: Any?, style: JsonValue? = null, vararg children: Any?): JsonValue = JsonValue.Object(
        buildMap {
            put("text", JsonValue.of(text))
            style?.let { put("style", it) }
            if (children.isNotEmpty()) put("children", JsonValue.arr(*children))
        },
    )

    private fun style(vararg style: Pair<String, Any?>): JsonValue = JsonValue.obj(*style)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun layout(tag: String): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag(tag).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single()
    }

    /** A7.1: the runs read as one text, in order, the page-state span resolved (fixture 46's tree). */
    @Test
    fun a7_1_kt_theRunsReadAsOneTextInOrder() {
        val name = JsonValue.obj("type" to "state", "key" to "name", "scope" to "page")
        richPage(
            rich(
                "t",
                span(
                    "Hello ", style("fontWeight" to "bold", "color" to "#1E88E5"),
                    span(
                        "world", style("fontStyle" to "italic", "color" to "#43A047"),
                        span(name, style("color" to "#E53935", "decoration" to "underline")),
                    ),
                    span(JsonValue.obj("type" to "static", "value" to "!")),
                ),
                "textAlign" to "center", "maxLines" to 1, "overflow" to "ellipsis",
                watches = listOf("name"),
            ),
            state = listOf(StateDefinition("name", StateScope.Page, JsonValue.String("Ada"))),
        )
        compose.onNodeWithTag("t").assertTextEquals("Hello worldAda!")
    }

    /**
     * A7.1: what an unstyled root leaves unset is the engine's paragraph
     * default, white 14 regular, not the ambient style (here red 30): it
     * lays out as a Text of fontSize 14 does and draws white ink on black;
     * start, soft wrap, clip, no line limit.
     */
    @Test
    fun a7_1_kt_anUnstyledRootDrawsWhite14() {
        val model = model(
            column("0", "r", "x"),
            rich("r", span("Hello")),
            text("x", "Hello", mapOf("style" to style("fontSize" to 14))),
        )
        show(Color.Black) {
            CompositionLocalProvider(LocalTextStyle provides TextStyle(fontSize = 30.sp, color = Color.Red)) {
                Column {
                    NodeView("r", model)
                    NodeView("x", model)
                }
            }
        }
        val box = bounds("r")
        assertEquals(bounds("x").width.value, box.width.value, 0.5f)
        assertEquals(bounds("x").height.value, box.height.value, 0.5f)
        val input = layout("r").layoutInput
        assertEquals(14.sp, input.style.fontSize)
        assertEquals(TextAlign.Start, input.style.textAlign)
        assertTrue(input.softWrap, "no soft wrap")
        assertEquals(TextOverflow.Clip, input.overflow)
        assertEquals(Int.MAX_VALUE, input.maxLines)
        val picture = picture()
        val ink = pixels(box).map { picture.getPixel(it.first, it.second) }.filter { luminance(it) > 0.1f }
        assertTrue(ink.isNotEmpty(), "nothing drawn on the black")
        assertTrue(ink.any { isColour(it, WHITE) && luminance(it) > 0.9f }, "no white ink")
        assertTrue(ink.all { isGrey(it) }, "coloured ink in a white text")
    }

    /** A7.1: three spans in three colours on one line, each run in its own colour, in order. */
    @Test
    fun a7_1_kt_eachRunDrawsInItsOwnColourOnOneLine() {
        richPage(
            rich(
                "t",
                span(
                    "HH", style("fontSize" to 30, "fontWeight" to "bold", "color" to "#FF0000"),
                    span("HH", style("color" to "#00FF00")),
                    span("HH", style("color" to "#0000FF")),
                ),
            ),
        )
        assertEquals(1, layout("t").lineCount)
        val picture = picture()
        val box = bounds("t")
        val red = inkColumns(picture, box, RED)
        val green = inkColumns(picture, box, GREEN)
        val blue = inkColumns(picture, box, BLUE)
        assertTrue(red.isNotEmpty() && green.isNotEmpty() && blue.isNotEmpty(), "red ${red.size}, green ${green.size}, blue ${blue.size}")
        assertTrue(red.max() < green.min(), "red ${red.min()}..${red.max()} not before green ${green.min()}")
        assertTrue(green.max() < blue.min(), "green ${green.min()}..${green.max()} not before blue ${blue.min()}")
    }

    /**
     * A7.1: a child with a style of its own is upright under an italic
     * parent (Flutter's `parseTextStyle` always sets fontStyle): the red
     * italic root leans, its blue child's stems stand straight.
     */
    @Test
    fun a7_1_kt_aStyledChildIsUprightUnderAnItalicParent() {
        richPage(
            rich(
                "t",
                span(
                    "HH", style("fontSize" to 60, "fontStyle" to "italic", "color" to "#FF0000"),
                    span("HH", style("color" to "#0000FF")),
                ),
            ),
        )
        val picture = picture()
        val box = bounds("t")
        val lean = lean(picture, box, RED)
        val upright = lean(picture, box, BLUE)
        assertTrue(lean > 3f, "the italic root does not lean: $lean")
        assertTrue(abs(upright) <= 1.5f, "the styled child leans: $upright")
    }

    /**
     * A7.1: decoration `none` on a child clears the parent's line: the red
     * root is underlined, its blue child has nothing under it.
     */
    @Test
    fun a7_1_kt_decorationNoneClearsTheParentsLine() {
        richPage(
            rich(
                "t",
                span(
                    "HHHH", style("fontSize" to 30, "color" to "#FF0000", "decoration" to "underline"),
                    span("HHHH", style("color" to "#0000FF", "decoration" to "none")),
                ),
            ),
        )
        val picture = picture()
        val box = bounds("t")
        val baseline = (box.top.value + layout("t").getLineBaseline(0)).roundToInt()
        val red = inkColumns(picture, box, RED).let { it.min() + 2..it.max() - 2 }
        val blue = inkColumns(picture, box, BLUE).let { it.min() + 2..it.max() - 2 }
        val under = (baseline + 1..baseline + 8)
        assertTrue(
            under.any { y -> red.count { isColour(picture.getPixel(it, y), RED) } >= red.count() * 4 / 5 },
            "no underline under the red root",
        )
        val marked = under.filter { y -> blue.any { luminance(picture.getPixel(it, y)) < 0.8f } }
        assertTrue(marked.isEmpty(), "a line under the blue child at rows $marked")
    }

    /**
     * A7.1: maxLines 1 keeps one line; `ellipsis` ends it with an ellipsis,
     * no `overflow` clips it (the RichText default).
     */
    @Test
    fun a7_1_kt_maxLinesKeepsOneLineEllipsizedOnlyWhenSent() {
        val words = span("HHHH HHHH HHHH HHHH HHHH", style("fontSize" to 20, "color" to "#000000"))
        richPage(
            column("0", "1", "2"),
            rich("1", words, "maxLines" to 1, "overflow" to "ellipsis"),
            rich("2", words, "maxLines" to 1),
            width = 100.dp,
        )
        val ellipsized = layout("1")
        val clipped = layout("2")
        assertEquals(1, ellipsized.lineCount)
        assertEquals(1, clipped.lineCount)
        assertTrue(ellipsized.isLineEllipsized(0), "no ellipsis")
        assertFalse(clipped.isLineEllipsized(0), "an ellipsis without overflow")
        assertEquals(bounds("1").height.value, bounds("2").height.value, 0.5f)
    }

    /** A7.1: `fade` on a line cut by maxLines fades its bottom, as a Text's (Flutter's vertical overflow shader). */
    @Test
    fun a7_1_kt_fadeFadesTheBottomOfALineCutByMaxLines() {
        richPage(
            rich(
                "t",
                span("HHHH HHHH HHHH HHHH HHHH", style("fontSize" to 20, "color" to "#000000", "backgroundColor" to "#000000")),
                "maxLines" to 1, "overflow" to "fade",
            ),
            width = 100.dp,
        )
        val picture = picture()
        val box = bounds("t")
        val x = box.left.value.roundToInt() + 3
        val top = luminance(picture.getPixel(x, box.top.value.roundToInt() + 2))
        val bottom = luminance(picture.getPixel(x, box.bottom.value.roundToInt() - 1))
        assertTrue(top < 0.1f, "faded at the top: $top")
        assertTrue(bottom > 0.8f, "not faded at the bottom: $bottom")
    }

    /**
     * A7.1: a span's `wordSpacing` widens each space of its own run: " a b"
     * with wordSpacing 10 is 2 x 10 wider than without, while the runs
     * before and after it, spaces and all, keep their width.
     */
    @Test
    fun a7_1_kt_wordSpacingWidensOnlyItsRunsSpaces() {
        fun words(spacing: Int?) = span(
            "H H", style("fontSize" to 20, "color" to "#000000"),
            span(" a b", spacing?.let { style("wordSpacing" to it) }),
            span(" H H"),
        )
        richPage(column("0", "1", "2"), rich("1", words(10)), rich("2", words(null)))
        val spaced = layout("1")
        val plain = layout("2")
        fun width(layout: TextLayoutResult, from: Int, to: Int): Float =
            layout.getBoundingBox(to - 1).right - layout.getBoundingBox(from).left
        assertEquals(20f, width(spaced, 0, 11) - width(plain, 0, 11), 2f, "the spaced run did not widen by 2 x 10")
        assertEquals(width(plain, 0, 3), width(spaced, 0, 3), 0.5f, "the run before widened")
        assertEquals(width(plain, 7, 11), width(spaced, 7, 11), 0.5f, "the run after widened")
    }

    /** A7.1: a RichText does not scale with the font scale (a Text beside it does). */
    @Test
    fun a7_1_kt_fontScaleTwoChangesNothing() {
        val words = span("Hello", style("fontSize" to 20))
        val model = model(
            column("0", "a", "b", "c", "d"),
            rich("a", words),
            rich("b", words),
            text("c", "Hello", mapOf("style" to style("fontSize" to 20))),
            text("d", "Hello", mapOf("style" to style("fontSize" to 20))),
        )
        show {
            val density = LocalDensity.current.density
            Column {
                for ((id, scale) in listOf("a" to 1f, "b" to 2f, "c" to 1f, "d" to 2f)) {
                    CompositionLocalProvider(LocalDensity provides Density(density, scale)) { NodeView(id, model) }
                }
            }
        }
        assertEquals(bounds("a").width.value, bounds("b").width.value, 0.5f)
        assertEquals(bounds("a").height.value, bounds("b").height.value, 0.5f)
        assertTrue(bounds("d").height > bounds("c").height * 1.5f, "the Text did not scale: the check is dead")
    }

    /** A7.1: SetState("name") redraws the span bound to it. */
    @Test
    fun a7_1_kt_aStateSpanRedrawsAfterSetState() {
        val name = JsonValue.obj("type" to "state", "key" to "name", "scope" to "page")
        val model = richPage(
            rich("t", span("Hi ", null, span(name, style("color" to "#E53935"))), watches = listOf("name")),
            state = listOf(StateDefinition("name", StateScope.Page, JsonValue.String("Ada"))),
        )
        compose.onNodeWithTag("t").assertTextEquals("Hi Ada")
        runBlocking { model.run(Action.SetState("name", value = JsonValue.String("Kim"))) }
        compose.waitForIdle()
        compose.onNodeWithTag("t").assertTextEquals("Hi Kim")
    }

    /** Every pixel of [box]. */
    private fun pixels(box: DpRect): List<Pair<Int, Int>> {
        val xs = box.left.value.roundToInt() until box.right.value.roundToInt()
        val ys = box.top.value.roundToInt() until box.bottom.value.roundToInt()
        return ys.flatMap { y -> xs.map { it to y } }
    }

    /** The columns of [box] holding a pixel of [rgb]. */
    private fun inkColumns(picture: Bitmap, box: DpRect, rgb: Triple<Int, Int, Int>): List<Int> =
        pixels(box).filter { (x, y) -> isColour(picture.getPixel(x, y), rgb) }.map { it.first }.distinct().sorted()

    /**
     * How far the leftmost [rgb] ink of the upper quarter of its rows sits
     * right of that of the lower quarter, on average: a capital H's left
     * stem, 0 upright, positive leaning right (italic).
     */
    private fun lean(picture: Bitmap, box: DpRect, rgb: Triple<Int, Int, Int>): Float {
        val xs = box.left.value.roundToInt() until box.right.value.roundToInt()
        val lefts = (box.top.value.roundToInt() until box.bottom.value.roundToInt()).mapNotNull { y ->
            xs.firstOrNull { isColour(picture.getPixel(it, y), rgb) }?.let { y to it }
        }
        assertTrue(lefts.size >= 8, "no $rgb ink")
        val quarter = lefts.size / 4
        val upper = lefts.drop(1).take(quarter).map { it.second }.average()
        val lower = lefts.dropLast(1).takeLast(quarter).map { it.second }.average()
        return (upper - lower).toFloat()
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

    /** Red, green and blue within 24 of each other: white or black text antialiased on black. */
    private fun isGrey(pixel: Int): Boolean {
        val channels = listOf(android.graphics.Color.red(pixel), android.graphics.Color.green(pixel), android.graphics.Color.blue(pixel))
        return channels.max() - channels.min() <= 24
    }

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
        val GREEN = Triple(0, 255, 0)
        val BLUE = Triple(0, 0, 255)
        val WHITE = Triple(255, 255, 255)
    }
}
