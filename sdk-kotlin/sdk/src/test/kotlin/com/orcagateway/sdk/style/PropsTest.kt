package com.orcagateway.sdk.style

import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.BiasAbsoluteAlignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.json.JsonValue
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The prop parsers, on the cases Swift's `Props` handles. Plain JUnit, no Android. */
class PropsTest {
    private fun s(text: String) = JsonValue.String(text)

    @Test
    fun sixDigitColoursAreOpaque() {
        assertEquals(Color(0xFF, 0x00, 0x00, 0xFF), Props.color(s("#FF0000")))
        assertEquals(Color(0x12, 0x34, 0x56, 0xFF), Props.color(s("#123456")))
        assertEquals(Color(0xAB, 0xCD, 0xEF, 0xFF), Props.color(s("#abcdef")))
    }

    @Test
    fun eightDigitColoursCarryAlphaLast() {
        assertEquals(Color(0x00, 0xFF, 0x00, 0x80), Props.color(s("#00FF0080")))
        assertEquals(Color(0x11, 0x22, 0x33, 0x00), Props.color(s("#11223300")))
        assertEquals(0x80 / 255f, Props.color(s("#00FF0080"))!!.alpha, 0.001f)
    }

    @Test
    fun anythingElseIsNoColour() {
        for (bad in listOf("FF0000", "#FFF", "#FFFF", "#1234567", "#123456789", "#GG0000", "#+FFFFF", "# FFFFF", "", "#", "red")) {
            assertNull(Props.color(s(bad)), bad)
        }
        assertNull(Props.color(JsonValue.Int(0xFF0000)))
        assertNull(Props.color(JsonValue.Null))
        assertNull(Props.color(null))
    }

    @Test
    fun insetsReadFourSidesMissingOnesZero() {
        val all = JsonValue.obj("top" to 1, "right" to 2, "bottom" to 3, "left" to 4)
        assertEquals(Insets(top = 1.0, left = 4.0, bottom = 3.0, right = 2.0), Props.insets(all))
        assertEquals(Insets(top = 5.0, left = 0.0, bottom = 0.0, right = 0.0), Props.insets(JsonValue.obj("top" to 5)))
        assertEquals(Insets(0.0, 1.5, 0.0, 0.0), Props.insets(JsonValue.obj("left" to 1.5)))
        assertEquals(Insets.Zero, Props.insets(JsonValue.obj()))
        assertNull(Props.insets(JsonValue.Int(8)))
        assertNull(Props.insets(s("8")))
        assertNull(Props.insets(null))
    }

    @Test
    fun insetsAreAbsoluteAndNeverNegative() {
        val padding = Insets(top = 1.0, left = 4.0, bottom = -3.0, right = 2.0).paddingValues()
        assertEquals(1.dp, padding.calculateTopPadding())
        assertEquals(0.dp, padding.calculateBottomPadding())
        assertEquals(4.dp, padding.calculateLeftPadding(LayoutDirection.Ltr))
        assertEquals(4.dp, padding.calculateLeftPadding(LayoutDirection.Rtl))
        assertEquals(2.dp, padding.calculateRightPadding(LayoutDirection.Rtl))
    }

    @Test
    fun lengthsAreClampedToWhatComposeCanDraw() {
        assertEquals(16.dp, Props.length(JsonValue.Int(16)))
        assertEquals(2.5.dp, Props.length(JsonValue.Double(2.5)))
        assertEquals(0.dp, Props.length(JsonValue.Int(-4)))
        assertEquals(Props.MAX_LENGTH.dp, Props.length(JsonValue.Double(1e12)))
        assertNull(Props.length(s("16")))
        assertNull(Props.length(null))
    }

    @Test
    fun mainAxisAlignmentNamesAndDefault() {
        val names = mapOf(
            "start" to Props.MainAxis.Start, "end" to Props.MainAxis.End, "center" to Props.MainAxis.Center,
            "spaceBetween" to Props.MainAxis.SpaceBetween, "spaceAround" to Props.MainAxis.SpaceAround,
            "spaceEvenly" to Props.MainAxis.SpaceEvenly,
        )
        for ((name, axis) in names) assertEquals(axis, Props.mainAxis(s(name)), name)
        assertEquals(Props.MainAxis.Start, Props.mainAxis(s("middle")))
        assertEquals(Props.MainAxis.Start, Props.mainAxis(null))
    }

    @Test
    fun crossAxisAlignmentNamesAndDefault() {
        val names = mapOf(
            "start" to Props.CrossAxis.Start, "end" to Props.CrossAxis.End, "center" to Props.CrossAxis.Center,
            "stretch" to Props.CrossAxis.Stretch, "baseline" to Props.CrossAxis.Baseline,
        )
        for ((name, axis) in names) assertEquals(axis, Props.crossAxis(s(name)), name)
        assertEquals(Props.CrossAxis.Center, Props.crossAxis(s("top")))
        assertEquals(Props.CrossAxis.Center, Props.crossAxis(null))
    }

    @Test
    fun mainAxisSizeIsMaxUnlessMin() {
        assertFalse(Props.fillsMainAxis(s("min")))
        assertTrue(Props.fillsMainAxis(s("max")))
        assertTrue(Props.fillsMainAxis(s("other")))
        assertTrue(Props.fillsMainAxis(null))
    }

    @Test
    fun textAlignKeepsFlutterSixNames() {
        assertEquals(TextAlign.Left, Props.textAlign(s("left")))
        assertEquals(TextAlign.Right, Props.textAlign(s("right")))
        assertEquals(TextAlign.Center, Props.textAlign(s("center")))
        assertEquals(TextAlign.Justify, Props.textAlign(s("justify")))
        assertEquals(TextAlign.Start, Props.textAlign(s("start")))
        assertEquals(TextAlign.End, Props.textAlign(s("end")))
        assertNull(Props.textAlign(s("middle")))
        assertNull(Props.textAlign(null))
    }

    @Test
    fun overflowClipsByDefault() {
        assertEquals(TextOverflow.Ellipsis, Props.overflow(s("ellipsis")))
        assertEquals(TextOverflow.Visible, Props.overflow(s("visible")))
        assertEquals(TextOverflow.Clip, Props.overflow(s("clip")))
        assertEquals(TextOverflow.Clip, Props.overflow(s("fade")))
        assertEquals(TextOverflow.Clip, Props.overflow(null))
    }

    @Test
    fun fontWeights() {
        val expected = listOf(
            FontWeight.W100, FontWeight.W200, FontWeight.W300, FontWeight.W400, FontWeight.W500,
            FontWeight.W600, FontWeight.W700, FontWeight.W800, FontWeight.W900,
        )
        for ((i, weight) in expected.withIndex()) assertEquals(weight, Props.fontWeight(s("w${(i + 1) * 100}")))
        assertEquals(FontWeight.W400, Props.fontWeight(s("normal")))
        assertEquals(FontWeight.W700, Props.fontWeight(s("bold")))
        assertNull(Props.fontWeight(s("heavy")))
        assertNull(Props.fontWeight(null))
    }

    @Test
    fun textIsPrintedTheDartWay() {
        assertEquals("", Props.text(null))
        assertEquals("", Props.text(JsonValue.Null))
        assertEquals("hi", Props.text(s("hi")))
        assertEquals("3", Props.text(JsonValue.Int(3)))
        assertEquals("2.5", Props.text(JsonValue.Double(2.5)))
        assertEquals("true", Props.text(JsonValue.Bool(true)))
    }

    @Test
    fun textStyleReadsTheFlutterKeys() {
        val style = TextStyleProps(
            JsonValue.obj(
                "fontSize" to 48, "fontWeight" to "bold", "fontStyle" to "italic", "color" to "#FF000080",
                "backgroundColor" to "#00FF00", "letterSpacing" to 1.5, "decoration" to "lineThrough",
            ),
        ).textStyle()
        assertEquals(48.sp, style.fontSize)
        assertEquals(FontWeight.W700, style.fontWeight)
        assertEquals(FontStyle.Italic, style.fontStyle)
        assertEquals(Color(0xFF, 0, 0, 0x80), style.color)
        assertEquals(Color(0, 0xFF, 0, 0xFF), style.background)
        assertEquals(1.5.sp, style.letterSpacing)
        assertEquals(TextDecoration.LineThrough, style.textDecoration)

        val plain = TextStyleProps(null).textStyle()
        assertEquals(Color.Unspecified, plain.color)
        assertNull(plain.fontWeight)
        assertNull(plain.textDecoration)
        assertEquals(TextDecoration.Underline, TextStyleProps(JsonValue.obj("decoration" to "underline")).textStyle().textDecoration)
    }

    /**
     * W5: Flutter's nine `Alignment` names, anything else center. Flutter's
     * `Alignment` is absolute, so right to left does not flip a side.
     */
    @Test
    fun w5_alignmentNamesFollowFlutter() {
        val names = mapOf(
            "topLeft" to AbsoluteAlignment.TopLeft, "topCenter" to BiasAbsoluteAlignment(0f, -1f),
            "topRight" to AbsoluteAlignment.TopRight, "centerLeft" to AbsoluteAlignment.CenterLeft,
            "center" to BiasAbsoluteAlignment(0f, 0f), "centerRight" to AbsoluteAlignment.CenterRight,
            "bottomLeft" to AbsoluteAlignment.BottomLeft, "bottomCenter" to BiasAbsoluteAlignment(0f, 1f),
            "bottomRight" to AbsoluteAlignment.BottomRight,
        )
        for ((name, alignment) in names) assertEquals(alignment, Props.alignment(s(name)), name)
        val center = BiasAbsoluteAlignment(0f, 0f)
        assertEquals(center, Props.alignment(s("nonsense")))
        assertEquals(center, Props.alignment(s("topStart")))
        assertEquals(center, Props.alignment(JsonValue.Int(1)))
        assertEquals(center, Props.alignment(null))

        val child = IntSize(10, 10)
        val box = IntSize(100, 50)
        assertEquals(IntOffset(0, 0), Props.alignment(s("topLeft")).align(child, box, LayoutDirection.Rtl))
        assertEquals(IntOffset(90, 20), Props.alignment(s("centerRight")).align(child, box, LayoutDirection.Rtl))
        assertEquals(IntOffset(45, 40), Props.alignment(s("bottomCenter")).align(child, box, LayoutDirection.Rtl))

        // The same names as points of the unit square, where a gradient starts and ends.
        assertEquals(Offset(0f, 0f), Props.unitPoint(s("topLeft")))
        assertEquals(Offset(1f, 0.5f), Props.unitPoint(s("centerRight")))
        assertEquals(Offset(0.5f, 1f), Props.unitPoint(s("bottomCenter")))
        assertEquals(Offset(1f, 1f), Props.unitPoint(s("bottomRight")))
        assertEquals(Offset(0.5f, 0.5f), Props.unitPoint(s("nonsense")))
        assertEquals(Offset(0.5f, 0.5f), Props.unitPoint(null))
    }

    /** W6: a number rounds every corner, an object names each corner and a missing one is 0. */
    @Test
    fun w6_radiiFromANumberOrCorners() {
        assertEquals(CornerRadii.all(12.0), Props.radii(JsonValue.Int(12)))
        assertEquals(
            CornerRadii(topLeft = 2.5, topRight = 2.5, bottomLeft = 2.5, bottomRight = 2.5),
            Props.radii(JsonValue.Double(2.5)),
        )
        assertEquals(
            CornerRadii(topLeft = 8.0, topRight = 8.0, bottomLeft = 0.0, bottomRight = 0.0),
            Props.radii(JsonValue.obj("topLeft" to 8, "topRight" to 8)),
        )
        assertEquals(
            CornerRadii(topLeft = 1.0, topRight = 2.0, bottomLeft = 3.0, bottomRight = 4.0),
            Props.radii(JsonValue.obj("topLeft" to 1, "topRight" to 2, "bottomLeft" to 3, "bottomRight" to 4)),
        )
        assertEquals(CornerRadii.Zero, Props.radii(JsonValue.obj()))
        assertNull(Props.radii(s("12")))
        assertNull(Props.radii(JsonValue.arr(12)))
        assertNull(Props.radii(JsonValue.Null))
        assertNull(Props.radii(null))
    }

    /** W7: `hardEdge`, `antiAlias` and `antiAliasWithSaveLayer` clip; `none`, no value and anything else do not. */
    @Test
    fun w7_clipBehaviourIsOffUnlessAsked() {
        assertFalse(Props.clips(null))
        assertFalse(Props.clips(s("none")))
        assertFalse(Props.clips(s("nonsense")))
        assertFalse(Props.clips(JsonValue.Bool(true)))
        for (clip in listOf("hardEdge", "antiAlias", "antiAliasWithSaveLayer")) assertTrue(Props.clips(s(clip)), clip)
    }
}
