package com.orcagateway.sdk.widgets

import android.app.Application
import android.content.ClipboardManager
import android.widget.Magnifier
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.assertIsNotFocused
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.test.swipeUp
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
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * A7.2: SelectableText as Flutter's builder makes it (primitive_builders
 * .dart:350-362): Material's SelectableText, a read-only EditableText
 * (selectable_text.dart:705-799). A long press selects a word, with handles
 * and a toolbar; its style is the DefaultTextStyle's merged with its own
 * (:753-758), textAlign own ?? DTS ?? start (:779), maxLines own ?? DTS
 * (:785), and past maxLines the text scrolls in a box of that many lines
 * (rendering/editable.dart:1916-1953, :2409-2416), never ellipsized; the
 * width is the text's plus the 3 px caret margin (:1272, :2407). The same
 * cases as Swift's SelectableTextTests. SelectableText and DefaultTextStyle
 * are registered only in K-caps (G7): the test registers their builders, as
 * standard() will, and widens the core's registry by them. The ambient style
 * around the page is red 30 italic, so anything of it that shows through is
 * seen.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SelectableTextTest {
    @get:Rule
    val compose = createComposeRule()

    /** The root of [nodes] under the ambient style, in a loose 300 x 200 box at the top left. */
    private fun show(vararg nodes: ComponentNode) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "DefaultTextStyle" + "SelectableText")
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("DefaultTextStyle") { node, model, modifier -> DefaultTextStyleWidget(node, model, modifier) }
                register("SelectableText") { node, _, modifier -> SelectableTextWidget(node, modifier.testTag(node.id)) }
                register("Text") { node, _, modifier -> TextWidget(node, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            CompositionLocalProvider(LocalTextStyle provides AMBIENT) {
                Box(Modifier.size(300.dp, 200.dp), contentAlignment = AbsoluteAlignment.TopLeft) {
                    NodeView(nodes.first().id, model)
                }
            }
        }
    }

    private fun selectable(id: String, data: String, vararg props: Pair<String, Any?>) =
        leaf(id, "SelectableText", props(*props) + ("data" to JsonValue.String(data)))

    private fun dts(id: String, child: String, vararg props: Pair<String, Any?>) = ComponentNode(
        id, "DefaultTextStyle", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props(*props), listOf(child),
    )

    private fun box(id: String, width: Int, child: String) = ComponentNode(
        id, "Container", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        mapOf("width" to JsonValue.Int(width.toLong())), listOf(child),
    )

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    private fun style(vararg style: Pair<String, Any?>): JsonValue = JsonValue.obj(*style)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    /** The text the SelectableText [tag] draws (the node under its selection container). */
    private fun inner(tag: String, data: String): SemanticsNodeInteraction =
        compose.onNode(hasText(data) and hasAnyAncestor(hasTestTag(tag)), useUnmergedTree = true)

    private fun layout(node: SemanticsNodeInteraction): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        node.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single()
    }

    /**
     * A7.2: a SelectableText is a selection container around its text: a
     * focusable node (it takes focus when a selection starts, as Flutter's
     * EditableText does) holding the text, where a Text has none; as tall as
     * the Text of the same data and style, and 3 wider (the caret margin).
     */
    @Test
    fun a7_2_kt_selectableTextIsAFocusableSelectionContainerAroundItsText() {
        val own = style("fontSize" to 16, "color" to "#000000")
        show(
            column("0", "s", "t"),
            selectable("s", "Hello world", "style" to own),
            text("t", "Hello world", props("style" to own)),
        )
        compose.onNodeWithTag("s")
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Focused))
            .assertIsNotFocused()
        inner("s", "Hello world").assert(SemanticsMatcher.keyIsDefined(SemanticsActions.GetTextLayoutResult))
        compose.onNodeWithTag("t").assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.Focused))
        assertEquals(bounds("t").height.value, bounds("s").height.value, 0.5f)
        assertEquals(bounds("t").width.value + 3f, bounds("s").width.value, 0.5f, "no 3 px caret margin")
    }

    /**
     * A7.2: a long press on a word selects that word: the container takes
     * focus, the two selection handles show, and Copy puts exactly the word
     * on the clipboard. The toolbar itself (the system's floating menu),
     * the handles' look and the magnifier (here a no-op, [NoMagnifier]) are
     * seen only by hand.
     */
    @Test
    @Config(shadows = [NoMagnifier::class])
    fun a7_2_kt_aLongPressOnSelectableTextSelectsAWord() {
        val data = "Hello brave world"
        show(selectable("s", data, "style" to style("fontSize" to 20, "color" to "#000000")))
        val node = inner("s", data)
        val result = layout(node)
        val start = data.indexOf("brave")
        val word = result.getBoundingBox(start).left..result.getBoundingBox(start + 4).right
        val middle = Offset((word.start + word.endInclusive) / 2, (result.getLineTop(0) + result.getLineBottom(0)) / 2)
        node.performTouchInput { longClick(middle) }
        compose.waitForIdle()
        compose.onNodeWithTag("s").assertIsFocused()
        val handle = SemanticsMatcher("a selection handle") { candidate ->
            candidate.config.any { (key, _) -> key.name == "SelectionHandleInfo" }
        }
        compose.onAllNodes(handle, useUnmergedTree = true).assertCountEquals(2)
        compose.onNodeWithTag("s").performKeyInput { pressKey(Key.Copy) }
        compose.waitForIdle()
        val clipboard = ApplicationProvider.getApplicationContext<Application>().getSystemService(ClipboardManager::class.java)
        assertEquals("brave", clipboard.primaryClip?.getItemAt(0)?.text?.toString())
    }

    /**
     * A7.2: under a DTS {fontWeight: bold} an unstyled SelectableText draws
     * white, 14, bold and upright (the DTS's style on the engine's
     * defaults, the ambient red 30 italic dropped), start aligned, no line
     * limit; outside any DTS it draws on the ambient style, as Flutter's
     * reads DefaultTextStyle.of(context), the Material's, with its own
     * fields over it.
     */
    @Test
    fun a7_2_kt_selectableTextUnderADtsDrawsWhite14Bold() {
        show(
            column("0", "d", "s2"),
            dts("d", "s1", "style" to style("fontWeight" to "bold")),
            selectable("s1", "Under"),
            selectable("s2", "Outside", "style" to style("fontWeight" to "bold")),
        )
        val under = layout(inner("s1", "Under")).layoutInput
        assertEquals(Color.White, under.style.color)
        assertEquals(14.sp, under.style.fontSize)
        assertEquals(FontWeight.Bold, under.style.fontWeight)
        assertEquals(FontStyle.Normal, under.style.fontStyle)
        assertEquals(TextAlign.Start, under.style.textAlign)
        assertEquals(Int.MAX_VALUE, under.maxLines)
        val outside = layout(inner("s2", "Outside")).layoutInput
        assertEquals(Color.Red, outside.style.color)
        assertEquals(30.sp, outside.style.fontSize)
        assertEquals(FontWeight.Bold, outside.style.fontWeight)
    }

    /**
     * A7.2: the SelectableText's own fontSize, color, textAlign and maxLines
     * win over the DTS's; the DTS's fontWeight, which it leaves unset,
     * still applies; its maxLines 2 makes a box two lines tall (a Text of
     * the same style cut at two lines), not the DTS's one.
     */
    @Test
    fun a7_2_kt_selectableTextsOwnFieldsWinOverTheDts() {
        val own = style("fontSize" to 16, "color" to "#000000")
        show(
            column("0", "d", "b2"),
            dts(
                "d", "b1",
                "style" to style("fontSize" to 30, "color" to "#FF0000", "fontWeight" to "bold"),
                "textAlign" to "center", "maxLines" to 1,
            ),
            box("b1", 100, "s"),
            selectable("s", WORDS, "style" to own, "textAlign" to "right", "maxLines" to 2),
            box("b2", 100, "t"),
            text("t", WORDS, props("style" to style("fontSize" to 16, "fontWeight" to "bold"), "maxLines" to 2)),
        )
        val input = layout(inner("s", WORDS)).layoutInput
        assertEquals(16.sp, input.style.fontSize)
        assertEquals(Color.Black, input.style.color)
        assertEquals(FontWeight.Bold, input.style.fontWeight)
        assertEquals(TextAlign.Right, input.style.textAlign)
        assertEquals(bounds("t").height.value, bounds("s").height.value, 0.5f, "not two lines tall")
    }

    /**
     * A7.2: maxLines 2 on a long text is a box two lines tall (a Text cut
     * at two lines), the text below it laid out whole, nothing ellipsized,
     * and a swipe up scrolls the rest into the box.
     */
    @Test
    fun a7_2_kt_selectableTextMaxLinesTwoIsATwoLineBoxThatScrolls() {
        val own = style("fontSize" to 16, "color" to "#000000")
        show(
            column("0", "b1", "b2"),
            box("b1", 100, "s"),
            selectable("s", WORDS, "style" to own, "maxLines" to 2),
            box("b2", 100, "t"),
            text("t", WORDS, props("style" to own, "maxLines" to 2)),
        )
        assertEquals(bounds("t").height.value, bounds("s").height.value, 0.5f, "not two lines tall")
        val node = inner("s", WORDS)
        val result = layout(node)
        assertTrue(result.lineCount > 2, "the text is cut at two lines: ${result.lineCount}")
        assertEquals(Int.MAX_VALUE, result.layoutInput.maxLines)
        assertFalse((0 until result.lineCount).any { result.isLineEllipsized(it) }, "a line is ellipsized")
        assertTrue(result.size.height > bounds("s").height.value + 1, "nothing below the box")
        val range = SemanticsProperties.VerticalScrollAxisRange
        val scrolled = compose.onNode(hasAnyAncestor(hasTestTag("s")) and SemanticsMatcher.keyIsDefined(range), useUnmergedTree = true)
        assertEquals(0f, scrolled.fetchSemanticsNode().config[range].value())
        assertTrue(scrolled.fetchSemanticsNode().config[range].maxValue() > 0f, "nothing to scroll")
        compose.onNodeWithTag("s").performTouchInput { swipeUp() }
        compose.waitForIdle()
        assertTrue(scrolled.fetchSemanticsNode().config[range].value() > 0f, "a swipe up does not scroll")
    }

    /**
     * A7.2: maxLines 1 is one line that does not wrap (Flutter lays it out
     * on an unbounded width, editable.dart:2276-2279) and scrolls sideways
     * in the box, never ellipsized.
     */
    @Test
    fun a7_2_kt_selectableTextMaxLinesOneIsOneLineThatScrollsSideways() {
        val own = style("fontSize" to 16, "color" to "#000000")
        show(
            column("0", "b1", "b2"),
            box("b1", 100, "s"),
            selectable("s", WORDS, "style" to own, "maxLines" to 1),
            box("b2", 100, "t"),
            text("t", "MMMM", props("style" to own)),
        )
        val result = layout(inner("s", WORDS))
        assertEquals(1, result.lineCount)
        assertFalse(result.isLineEllipsized(0), "the line is ellipsized")
        assertTrue(result.size.width > 100, "the line wraps or is cut: ${result.size.width}")
        assertEquals(100f, bounds("s").width.value, 0.5f)
        assertEquals(bounds("t").height.value, bounds("s").height.value, 0.5f, "not one line tall")
        val range = SemanticsProperties.HorizontalScrollAxisRange
        val scrolled = compose.onNode(hasAnyAncestor(hasTestTag("s")) and SemanticsMatcher.keyIsDefined(range), useUnmergedTree = true)
        assertTrue(scrolled.fetchSemanticsNode().config[range].maxValue() > 0f, "nothing to scroll")
        assertEquals(TextOverflow.Clip, result.layoutInput.overflow)
    }

    /**
     * The platform magnifier a touch selection shows while the finger is
     * down: Robolectric gives its window no surface, so dismissing it
     * throws. Here it shows nothing.
     */
    @Implements(Magnifier::class)
    class NoMagnifier {
        @Implementation
        fun show(sourceCenterX: Float, sourceCenterY: Float) = Unit

        @Implementation
        fun show(sourceCenterX: Float, sourceCenterY: Float, magnifierCenterX: Float, magnifierCenterY: Float) = Unit

        @Implementation
        fun update() = Unit

        @Implementation
        fun dismiss() = Unit
    }

    private companion object {
        const val WORDS = "MMMM MMMM MMMM MMMM MMMM MMMM MMMM MMMM"

        /** The ambient style around the page: what a DTS must drop. */
        val AMBIENT = TextStyle(color = Color.Red, fontSize = 30.sp, fontStyle = FontStyle.Italic)
    }
}
