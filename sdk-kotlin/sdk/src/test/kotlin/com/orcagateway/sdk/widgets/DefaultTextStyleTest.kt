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
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
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
import kotlin.math.roundToInt
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * A7.2: DefaultTextStyle as Flutter's builder makes it (layout_builders
 * .dart:588-601): the replacing constructor (widgets/text.dart:63), so the
 * ambient style is dropped and what its style leaves unset is the engine's
 * (14, white, regular); a Text merges its own style over the DTS's field by
 * field, its own textAlign, maxLines and overflow winning (text.dart:
 * 723-772); a nested DTS replaces the outer one; RichText ignores it. The
 * same cases as Swift's DefaultTextStyleTests. DefaultTextStyle and
 * RichText are registered only in K-caps (G7): the test registers their
 * builders, as standard() will, and widens the core's registry by them.
 * Texts and RichTexts are tagged with their node id; the ambient style
 * around the page is red 30 italic, so anything of it that shows through
 * is seen.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class DefaultTextStyleTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    private fun model(vararg nodes: ComponentNode): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "DefaultTextStyle" + "RichText")
        return OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("DefaultTextStyle") { node, model, modifier -> DefaultTextStyleWidget(node, model, modifier) }
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

    /** The root of [nodes] under the ambient style, in a loose 300 x 200 box. */
    private fun dtsPage(vararg nodes: ComponentNode, background: Color = Color.Unspecified) {
        val model = model(*nodes)
        show(background) { Ambient { Box(Modifier.size(300.dp, 200.dp)) { NodeView(nodes.first().id, model) } } }
    }

    @Composable
    private fun Ambient(content: @Composable () -> Unit) {
        CompositionLocalProvider(LocalTextStyle provides AMBIENT, content = content)
    }

    private fun dts(id: String, child: String, vararg props: Pair<String, Any?>) = ComponentNode(
        id, "DefaultTextStyle", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        props.associate { (key, value) -> key to JsonValue.of(value) }, listOf(child),
    )

    private fun box(id: String, width: Int, child: String) = ComponentNode(
        id, "Container", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        mapOf("width" to JsonValue.Int(width.toLong())), listOf(child),
    )

    private fun rich(id: String, text: JsonValue) = ComponentNode(
        id, "RichText", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, mapOf("text" to text),
    )

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    private fun style(vararg style: Pair<String, Any?>): JsonValue = JsonValue.obj(*style)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun layout(tag: String): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag(tag).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single()
    }

    /**
     * A7.2: an unstyled Text under a DTS {fontWeight: bold} draws white,
     * 14, bold and upright, whatever the ambient style (red 30 italic): as
     * wide as a Text of its own 14 bold outside any ambient style, white ink
     * on black and nothing red.
     */
    @Test
    fun a7_2_kt_anUnstyledTextUnderADtsDrawsWhite14Bold() {
        val model = model(
            dts("d", "t", "style" to style("fontWeight" to "bold")),
            text("t", "MMMMMMMMMM"),
            text("x", "MMMMMMMMMM", props("style" to style("fontSize" to 14, "fontWeight" to "bold"))),
        )
        show(Color.Black) {
            Column {
                Ambient { NodeView("d", model) }
                NodeView("x", model)
            }
        }
        val input = layout("t").layoutInput
        assertEquals(Color.White, input.style.color)
        assertEquals(14.sp, input.style.fontSize)
        assertEquals(FontWeight.Bold, input.style.fontWeight)
        assertEquals(FontStyle.Normal, input.style.fontStyle)
        assertEquals(bounds("x").width.value, bounds("t").width.value, 0.5f)
        assertEquals(bounds("x").height.value, bounds("t").height.value, 0.5f)
        val picture = picture()
        val ink = pixels(bounds("t")).map { picture.getPixel(it.first, it.second) }.filter { luminance(it) > 0.1f }
        assertTrue(ink.any { luminance(it) > 0.9f }, "no white ink on the black")
        assertTrue(ink.all { isGrey(it) }, "coloured ink (the ambient red) in a white text")
    }

    /**
     * A7.2: the Text's own fontSize, color, textAlign and maxLines win over
     * the DTS's; the DTS's fontWeight and overflow, which the Text leaves
     * unset, still apply: two lines, the second ellipsized, right aligned.
     */
    @Test
    fun a7_2_kt_aTextsOwnSizeColourAlignAndMaxLinesWin() {
        dtsPage(
            dts(
                "d", "box",
                "style" to style("fontSize" to 30, "color" to "#FF0000", "fontWeight" to "bold"),
                "textAlign" to "center", "maxLines" to 1, "overflow" to "ellipsis",
            ),
            box("box", 100, "t"),
            text(
                "t", WORDS,
                props("style" to style("fontSize" to 16, "color" to "#000000"), "textAlign" to "right", "maxLines" to 2),
            ),
        )
        val result = layout("t")
        val input = result.layoutInput
        assertEquals(16.sp, input.style.fontSize)
        assertEquals(Color.Black, input.style.color)
        assertEquals(FontWeight.Bold, input.style.fontWeight)
        assertEquals(TextAlign.Right, input.style.textAlign)
        assertEquals(2, input.maxLines)
        assertEquals(TextOverflow.Ellipsis, input.overflow)
        assertEquals(2, result.lineCount)
        assertTrue(result.isLineEllipsized(1), "the DTS's ellipsis does not end the second line")
    }

    /** A7.2: a DTS textAlign center centres a Text that sends none (own ?? DTS ?? start); the Text's own left wins. */
    @Test
    fun a7_2_kt_aDtsTextAlignCenterCentresAnUnalignedText() {
        val own = style("fontSize" to 16, "color" to "#000000")
        dtsPage(
            column("0", "d1", "d2"),
            dts("d1", "b1", "style" to JsonValue.obj(), "textAlign" to "center"),
            box("b1", 200, "t1"),
            text("t1", "Hi", props("style" to own)),
            dts("d2", "b2", "style" to JsonValue.obj(), "textAlign" to "center"),
            box("b2", 200, "t2"),
            text("t2", "Hi", props("style" to own, "textAlign" to "left")),
        )
        val centred = layout("t1")
        assertEquals(TextAlign.Center, centred.layoutInput.style.textAlign)
        assertEquals(200f, centred.size.width.toFloat(), 0.5f)
        assertEquals(100f, (centred.getLineLeft(0) + centred.getLineRight(0)) / 2, 1f, "the line is not centred")
        val left = layout("t2")
        assertEquals(TextAlign.Left, left.layoutInput.style.textAlign)
        assertEquals(0f, left.getLineLeft(0), 0.5f, "the Text's own textAlign left lost")
    }

    /**
     * A7.2: DTS maxLines 1 with overflow ellipsis cuts a long Text to one
     * ellipsized line; without `overflow` the DTS's clip cuts it with no
     * ellipsis (layout_builders.dart:598).
     */
    @Test
    fun a7_2_kt_dtsMaxLinesOneWithEllipsisCutsALongText() {
        val own = style("fontSize" to 16, "color" to "#000000")
        dtsPage(
            column("0", "d1", "d2"),
            dts("d1", "b1", "style" to own, "maxLines" to 1, "overflow" to "ellipsis"),
            box("b1", 100, "t1"),
            text("t1", WORDS),
            dts("d2", "b2", "style" to own, "maxLines" to 1),
            box("b2", 100, "t2"),
            text("t2", WORDS),
        )
        val ellipsized = layout("t1")
        assertEquals(1, ellipsized.layoutInput.maxLines)
        assertEquals(TextOverflow.Ellipsis, ellipsized.layoutInput.overflow)
        assertEquals(1, ellipsized.lineCount)
        assertTrue(ellipsized.isLineEllipsized(0), "maxLines 1 with ellipsis does not end in an ellipsis")
        val clipped = layout("t2")
        assertEquals(1, clipped.layoutInput.maxLines)
        assertEquals(TextOverflow.Clip, clipped.layoutInput.overflow)
        assertEquals(1, clipped.lineCount)
        assertFalse(clipped.isLineEllipsized(0), "the DTS's clip ends in an ellipsis")
    }

    /**
     * A7.2: a nested DTS replaces the outer one, never merges with it: the
     * outer red, 30, italic, center, maxLines 1 and ellipsis do not leak;
     * the Text draws as under the inner DTS alone (white, 14, bold, start).
     */
    @Test
    fun a7_2_kt_aNestedDtsReplacesTheOuterOne() {
        dtsPage(
            dts(
                "out", "in",
                "style" to style("color" to "#FF0000", "fontSize" to 30, "fontStyle" to "italic"),
                "textAlign" to "center", "maxLines" to 1, "overflow" to "ellipsis",
            ),
            dts("in", "box", "style" to style("fontWeight" to "bold")),
            box("box", 200, "t"),
            text("t", "MMMM MMMM"),
            background = Color.Black,
        )
        val result = layout("t")
        val input = result.layoutInput
        assertEquals(Color.White, input.style.color)
        assertEquals(14.sp, input.style.fontSize)
        assertEquals(FontWeight.Bold, input.style.fontWeight)
        assertEquals(FontStyle.Normal, input.style.fontStyle)
        assertEquals(TextAlign.Start, input.style.textAlign)
        assertEquals(Int.MAX_VALUE, input.maxLines)
        assertEquals(TextOverflow.Clip, input.overflow)
        assertEquals(0f, result.getLineLeft(0), 0.5f, "the outer DTS's center leaked")
        val picture = picture()
        val ink = pixels(bounds("t")).map { picture.getPixel(it.first, it.second) }.filter { luminance(it) > 0.1f }
        assertTrue(ink.any { luminance(it) > 0.9f }, "no white ink on the black")
        assertTrue(ink.all { isGrey(it) }, "the outer DTS's red leaked")
    }

    /**
     * A7.2: RichText ignores the DTS (raw RichText, primitive_builders.dart
     * :325-348): the same paragraph, line limit, overflow and size with and
     * without a DTS above it.
     */
    @Test
    fun a7_2_kt_aRichTextUnderADtsIsUnchanged() {
        val spans = JsonValue.obj("text" to "Hello ", "children" to JsonValue.arr(JsonValue.obj("text" to "world", "style" to style("fontSize" to 18))))
        dtsPage(
            column("0", "d", "b2"),
            dts(
                "d", "b1",
                "style" to style("color" to "#FF0000", "fontSize" to 30, "fontWeight" to "bold", "fontStyle" to "italic"),
                "textAlign" to "center", "maxLines" to 1, "overflow" to "ellipsis",
            ),
            box("b1", 200, "r1"),
            rich("r1", spans),
            box("b2", 200, "r2"),
            rich("r2", spans),
        )
        val under = layout("r1")
        val alone = layout("r2")
        assertEquals(alone.layoutInput.text, under.layoutInput.text)
        assertEquals(alone.layoutInput.style, under.layoutInput.style)
        assertEquals(alone.layoutInput.maxLines, under.layoutInput.maxLines)
        assertEquals(alone.layoutInput.overflow, under.layoutInput.overflow)
        assertEquals(alone.size, under.size)
    }

    /**
     * A7.2: with no DTS a Text draws as before, on the ambient style: an
     * unstyled Text is red 30 italic here, its own fields merged over it.
     */
    @Test
    fun a7_2_kt_withoutADtsATextIsUnchanged() {
        dtsPage(
            column("0", "t", "u"),
            text("t", "Hello"),
            text("u", "Hello", props("style" to style("fontWeight" to "bold"))),
        )
        val plain = layout("t").layoutInput
        assertEquals(Color.Red, plain.style.color)
        assertEquals(30.sp, plain.style.fontSize)
        assertEquals(FontStyle.Italic, plain.style.fontStyle)
        assertEquals(Int.MAX_VALUE, plain.maxLines)
        assertEquals(TextOverflow.Clip, plain.overflow)
        val bold = layout("u").layoutInput
        assertEquals(Color.Red, bold.style.color)
        assertEquals(30.sp, bold.style.fontSize)
        assertEquals(FontWeight.Bold, bold.style.fontWeight)
    }

    /** Every pixel of [box]. */
    private fun pixels(box: DpRect): List<Pair<Int, Int>> {
        val xs = box.left.value.roundToInt() until box.right.value.roundToInt()
        val ys = box.top.value.roundToInt() until box.bottom.value.roundToInt()
        return ys.flatMap { y -> xs.map { it to y } }
    }

    private fun picture(): Bitmap {
        compose.waitForIdle()
        val view = requireNotNull(view)
        // Drawn in software on white, as GoldenTest draws it.
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun luminance(pixel: Int): Float =
        (android.graphics.Color.red(pixel) + android.graphics.Color.green(pixel) + android.graphics.Color.blue(pixel)) / 765f

    /** Red, green and blue within 24 of each other: white text antialiased on black. */
    private fun isGrey(pixel: Int): Boolean {
        val channels = listOf(android.graphics.Color.red(pixel), android.graphics.Color.green(pixel), android.graphics.Color.blue(pixel))
        return channels.max() - channels.min() <= 24
    }

    private companion object {
        const val WORDS = "MMMM MMMM MMMM MMMM MMMM"

        /** The ambient style around the page: what a DTS must drop. */
        val AMBIENT = TextStyle(color = Color.Red, fontSize = 30.sp, fontStyle = FontStyle.Italic)
    }
}
