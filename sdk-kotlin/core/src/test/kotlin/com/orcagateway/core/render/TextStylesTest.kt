package com.orcagateway.core.render

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * A7.1 and A7.2, the core half of RichText, SelectableText and
 * DefaultTextStyle: how wire text styles layer, against Flutter's builders
 * (sdk/lib/src/builders). A style is read by `parseTextStyle`
 * (builder_helpers.dart:96-121), which always sets fontStyle (normal unless
 * "italic", :103-105) and reads decoration "none" as a set value (:141),
 * then laid over its parent by `TextStyle.merge` (painting/text_style.dart:
 * 1078-1122), the child's set fields winning. RichText's spans
 * (primitive_builders.dart:325-348) flatten depth first, a non-object child
 * a run of its own text (:344), a span without `text` an empty run (:340).
 * A Text under a DefaultTextStyle (layout_builders.dart:588-601) takes
 * Flutter `Text.build` (widgets/text.dart:722-797). The same cases and
 * numbers as Swift's TextStylesTests.
 */
class TextStylesTest {
    private val base = obj("fontSize" to 14, "color" to "#FFFFFF")

    private fun merge(parent: JsonValue?, child: JsonValue?): JsonValue? = TextStyles.merge(parent, child)

    private fun assertStyle(expected: JsonValue, actual: JsonValue?) {
        assertJsonEqual(actual ?: JsonValue.Null, expected)
    }

    // A7.1 merge

    /** A7.1: the child's set fields replace the parent's, the rest are the parent's. */
    @Test
    fun a7_1_aChildsSetFieldsWinOverItsParent() {
        val parent = obj("fontSize" to 20, "fontWeight" to "bold", "color" to "#1E88E5", "letterSpacing" to 2)
        val child = obj("fontSize" to 12, "color" to "#43A047", "letterSpacing" to null)
        assertStyle(
            obj(
                "fontSize" to 12, "fontWeight" to "bold", "color" to "#43A047", "letterSpacing" to 2,
                "fontStyle" to "normal",
            ),
            merge(parent, child),
        )
        assertStyle(obj("color" to "#43A047", "fontStyle" to "normal"), merge(null, obj("color" to "#43A047")))
        val swiftParent = obj("fontSize" to 20, "fontWeight" to "bold", "color" to "#1E88E5", "letterSpacing" to 1)
        val swiftChild = obj("color" to "#E53935", "fontSize" to 12, "decoration" to "underline", "letterSpacing" to null)
        assertStyle(
            obj(
                "fontSize" to 12, "fontWeight" to "bold", "color" to "#E53935", "letterSpacing" to 1,
                "decoration" to "underline", "fontStyle" to "normal",
            ),
            merge(swiftParent, swiftChild),
        )
        assertStyle(swiftParent, merge(swiftParent, null))
        assertNull(merge(null, null))
    }

    /**
     * A7.1: a child with a style is upright under an italic parent unless it
     * says italic itself; any other fontStyle reads as normal.
     */
    @Test
    fun a7_1_aChildWithAStyleIsUprightUnlessItalic() {
        val italic = obj("fontStyle" to "italic", "color" to "#1E88E5")
        assertStyle(obj("fontStyle" to "normal", "color" to "#E53935"), merge(italic, obj("color" to "#E53935")))
        assertStyle(obj("fontStyle" to "normal", "color" to "#1E88E5"), merge(italic, obj()))
        assertStyle(obj("fontStyle" to "normal", "color" to "#1E88E5"), merge(italic, obj("fontStyle" to "oblique")))
        assertStyle(obj("fontStyle" to "italic", "color" to "#1E88E5"), merge(obj("color" to "#1E88E5"), obj("fontStyle" to "italic")))
        val green = obj("fontStyle" to "italic", "color" to "#43A047")
        assertStyle(obj("fontStyle" to "normal", "color" to "#E53935"), merge(green, obj("color" to "#E53935")))
        assertStyle(obj("fontStyle" to "normal", "color" to "#43A047"), merge(green, obj()))
        assertEquals(JsonValue.String("normal"), merge(green, obj("fontStyle" to "oblique"))?.get("fontStyle"))
        assertStyle(obj("fontStyle" to "italic"), merge(null, obj("fontStyle" to "italic")))
    }

    /** A7.1: a child without a style (absent, null or not an object) is its parent's style. */
    @Test
    fun a7_1_aChildWithoutAStyleKeepsItsParentsItalic() {
        val italic = obj("fontStyle" to "italic", "fontSize" to 18)
        assertStyle(italic, merge(italic, null))
        assertStyle(italic, merge(italic, JsonValue.Null))
        assertStyle(italic, merge(italic, JsonValue.String("bold")))
        assertNull(merge(null, null))
        val green = obj("fontStyle" to "italic", "color" to "#43A047")
        assertStyle(green, merge(green, null))
        assertStyle(green, merge(green, JsonValue.Null))
        assertStyle(green, merge(green, JsonValue.String("bold")))
        val runs = TextStyles.spans(obj("text" to "a", "style" to green, "children" to arr(obj("text" to "b"))), null)
        assertEquals(listOf(TextRun("a", green), TextRun("b", green)), runs)
    }

    /** A7.1: decoration "none" is a set value: it wins over the parent's line and stays in the merged style. */
    @Test
    fun a7_1_decorationNoneClearsTheParentsLine() {
        val underlined = obj("decoration" to "underline", "decorationColor" to "#E53935")
        assertStyle(
            obj("decoration" to "none", "decorationColor" to "#E53935", "fontStyle" to "normal"),
            merge(underlined, obj("decoration" to "none")),
        )
        assertStyle(
            obj("decoration" to "underline", "decorationColor" to "#E53935", "fontStyle" to "normal"),
            merge(underlined, obj("decoration" to null)),
        )
        assertEquals(JsonValue.String("underline"), merge(underlined, obj("color" to "#000000"))?.get("decoration"))
    }

    // A7.1 spans

    /**
     * A7.1: fixture 46's tree, resolved: runs in depth-first order, each
     * span's style merged onto its parent's, the root's onto the base.
     */
    @Test
    fun a7_1_spansFlattenDepthFirstWithMergedStyles() {
        val root = obj(
            "text" to "Hello ",
            "style" to obj("fontWeight" to "bold", "color" to "#1E88E5"),
            "children" to arr(
                obj(
                    "text" to "world",
                    "style" to obj("fontStyle" to "italic", "color" to "#43A047"),
                    "children" to arr(obj("text" to "Ada", "style" to obj("color" to "#E53935", "decoration" to "underline"))),
                ),
                obj("text" to "!"),
            ),
        )
        val runs = TextStyles.spans(root, base)
        assertEquals(listOf("Hello ", "world", "Ada", "!"), runs.map { it.text })
        val hello = obj("fontSize" to 14, "color" to "#1E88E5", "fontWeight" to "bold", "fontStyle" to "normal")
        assertStyle(hello, runs[0].style)
        assertStyle(obj("fontSize" to 14, "color" to "#43A047", "fontWeight" to "bold", "fontStyle" to "italic"), runs[1].style)
        assertStyle(
            obj("fontSize" to 14, "color" to "#E53935", "fontWeight" to "bold", "fontStyle" to "normal", "decoration" to "underline"),
            runs[2].style,
        )
        assertStyle(hello, runs[3].style)
        assertEquals(listOf(TextRun("x", base)), TextStyles.spans(obj("text" to "x"), base))
        assertEquals(
            TextRun("Hello ", obj("fontWeight" to "bold", "color" to "#1E88E5", "fontStyle" to "normal")),
            TextStyles.spans(root, null).first(),
        )
    }

    /**
     * A7.1: a child that is not an object is a run of its Dart string
     * (`'$c'`) in the parent's style: a number as Dart prints it, a bool,
     * null as "null".
     */
    @Test
    fun a7_1_aNonObjectChildIsItsOwnTextWithTheParentsStyle() {
        val style = obj("color" to "#43A047")
        val root = obj("text" to "n=", "style" to style, "children" to arr("plain", 3, 2.5, 4.0, true, null))
        val runs = TextStyles.spans(root, null)
        assertEquals(listOf("n=", "plain", "3", "2.5", "4.0", "true", "null"), runs.map { it.text })
        val merged = obj("color" to "#43A047", "fontStyle" to "normal")
        runs.forEach { assertStyle(merged, it.style) }
        val blue = obj("color" to "#1E88E5", "fontStyle" to "normal")
        assertEquals(
            listOf("n=", "x", "3", "4.0", "true", "null").map { TextRun(it, blue) },
            TextStyles.spans(obj("text" to "n=", "style" to obj("color" to "#1E88E5"), "children" to arr("x", 3, 4.0, true, null)), null),
        )
    }

    /**
     * A7.1: a span without `text` (or with a null one) is an empty run that
     * still carries its style to its children; a number `text` is its Dart
     * string. No root is Flutter's `const TextSpan()`: one empty run in the
     * base.
     */
    @Test
    fun a7_1_aSpanWithoutTextIsAnEmptyRun() {
        val root = obj(
            "style" to obj("fontSize" to 20),
            "children" to arr(obj("text" to null, "children" to arr(obj("text" to 7)))),
        )
        val style = obj("fontSize" to 20, "color" to "#FFFFFF", "fontStyle" to "normal")
        assertEquals(listOf(TextRun("", style), TextRun("", style), TextRun("7", style)), TextStyles.spans(root, base))
        assertEquals(listOf(TextRun("", base)), TextStyles.spans(obj(), base))
        assertEquals(listOf(TextRun("", base)), TextStyles.spans(null, base))
        val blue = obj("color" to "#1E88E5", "fontStyle" to "normal")
        val children = arr(obj("text" to "a"), obj("style" to obj("fontWeight" to "bold")), obj("text" to null), obj("text" to 2.5))
        assertEquals(
            listOf(
                TextRun("", blue), TextRun("a", blue),
                TextRun("", obj("color" to "#1E88E5", "fontWeight" to "bold", "fontStyle" to "normal")),
                TextRun("", blue), TextRun("2.5", blue),
            ),
            TextStyles.spans(obj("style" to obj("color" to "#1E88E5"), "children" to children), null),
        )
        assertEquals(listOf(TextRun("", obj("fontSize" to 14))), TextStyles.spans(null, obj("fontSize" to 14)))
    }

    // A7.2 DefaultTextStyle layering

    /** A7.2: a Text's own style is merged over the DTS style field by field; without one the Text takes the DTS style. */
    @Test
    fun a7_2_aTextsOwnStyleMergesOverTheDtsStyle() {
        val dts = props("style" to obj("fontWeight" to "bold", "fontStyle" to "italic", "color" to "#E53935", "fontSize" to 30))
        assertStyle(
            obj("fontWeight" to "bold", "fontStyle" to "normal", "color" to "#1E88E5", "fontSize" to 30),
            TextStyles.layer(dts, props("style" to obj("color" to "#1E88E5"))).style,
        )
        assertStyle(dts.getValue("style"), TextStyles.layer(dts, props()).style)
        assertStyle(obj("fontSize" to 12, "fontStyle" to "normal"), TextStyles.layer(props(), props("style" to obj("fontSize" to 12))).style)
        assertStyle(obj("color" to "#1E88E5", "fontStyle" to "normal"), TextStyles.layer(props(), props("style" to obj("color" to "#1E88E5"))).style)
    }

    /** A7.2: textAlign is the Text's, else the DTS's, else start. */
    @Test
    fun a7_2_ownTextAlignWinsThenTheDtsThenStart() {
        val dts = props("textAlign" to "center")
        assertEquals("right", TextStyles.layer(dts, props("textAlign" to "right")).textAlign)
        assertEquals("center", TextStyles.layer(dts, props()).textAlign)
        assertEquals("start", TextStyles.layer(props(), props()).textAlign)
        val right = props("textAlign" to "right")
        assertEquals("center", TextStyles.layer(right, props("textAlign" to "center")).textAlign)
        assertEquals("right", TextStyles.layer(right, props()).textAlign)
    }

    /** A7.2: maxLines is the Text's, else the DTS's, else none. */
    @Test
    fun a7_2_ownMaxLinesWinsThenTheDts() {
        val dts = props("maxLines" to 3)
        assertEquals(1L, TextStyles.layer(dts, props("maxLines" to 1)).maxLines)
        assertEquals(3L, TextStyles.layer(dts, props()).maxLines)
        assertNull(TextStyles.layer(props(), props()).maxLines)
    }

    /**
     * A7.2: overflow is the Text's, else the merged style's (the Text's
     * style, then the DTS style's), else the DTS's, else clip
     * (widgets/text.dart:794; the builder gives the DTS clip when unset,
     * layout_builders.dart:598).
     */
    @Test
    fun a7_2_overflowIsOwnThenItsStyleThenTheDtsThenClip() {
        val dts = props("overflow" to "fade", "style" to obj("overflow" to "visible"))
        val styled = props("style" to obj("overflow" to "ellipsis"))
        assertEquals("clip", TextStyles.layer(dts, props("overflow" to "clip", "style" to obj("overflow" to "ellipsis"))).overflow)
        assertEquals("ellipsis", TextStyles.layer(dts, styled).overflow)
        assertEquals("visible", TextStyles.layer(dts, props()).overflow)
        assertEquals("fade", TextStyles.layer(props("overflow" to "fade"), props()).overflow)
        assertEquals("clip", TextStyles.layer(props(), props()).overflow)
        val visible = props("overflow" to "visible")
        assertEquals("ellipsis", TextStyles.layer(visible, props("style" to obj("overflow" to "fade"), "overflow" to "ellipsis")).overflow)
        assertEquals("fade", TextStyles.layer(visible, props("style" to obj("overflow" to "fade"))).overflow)
        val dtsStyled = props("style" to obj("overflow" to "ellipsis"), "overflow" to "visible")
        assertEquals("ellipsis", TextStyles.layer(dtsStyled, props("style" to obj("color" to "#1E88E5"))).overflow)
        assertEquals("visible", TextStyles.layer(visible, props("style" to obj("color" to "#1E88E5"))).overflow)
    }
}
