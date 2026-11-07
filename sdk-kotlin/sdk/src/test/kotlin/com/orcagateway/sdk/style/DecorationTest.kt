package com.orcagateway.sdk.style

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.toRect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.sdk.style.BoxDecorationProps.Border
import com.orcagateway.sdk.style.BoxDecorationProps.BoxShadow
import com.orcagateway.sdk.style.BoxDecorationProps.Gradient
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * S9.3: Flutter's `BoxDecoration` as the Flutter SDK reads it, and the
 * rounded box it is drawn in. Robolectric because an outline with uneven
 * corners is an `android.graphics.Path`, and one case draws.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w100dp-h100dp-mdpi")
class DecorationTest {
    @get:Rule
    val compose = createComposeRule()

    private fun decoration(vararg members: Pair<String, Any?>) = BoxDecorationProps.of(JsonValue.obj(*members))

    /** W8: color, borderRadius, border, boxShadow and gradient, with Flutter's defaults for what is left out. */
    @Test
    fun w8_boxDecorationReadsEveryFlutterField() {
        val full = assertNotNull(
            decoration(
                "color" to "#FFFFFF",
                "borderRadius" to 16,
                "border" to mapOf("color" to "#E0E0E0", "width" to 2),
                "boxShadow" to listOf(
                    mapOf("color" to "#33000000", "blurRadius" to 8, "spreadRadius" to 1, "offset" to mapOf("dx" to 0, "dy" to 4)),
                ),
                "gradient" to mapOf(
                    "colors" to listOf("#FF5722", "#FFC107"), "stops" to listOf(0, 1), "begin" to "topLeft", "end" to "bottomRight",
                ),
            ),
        )
        val orange = Props.hex("#FF5722")
        val amber = Props.hex("#FFC107")
        assertEquals(Props.hex("#FFFFFF"), full.color)
        assertEquals(CornerRadii.all(16.0), full.radii)
        assertEquals(CornersShape(CornerRadii.all(16.0)), full.shape)
        assertEquals(Border(Props.hex("#E0E0E0"), 2.0), full.border)
        val shadowColour = assertNotNull(Props.color(JsonValue.String("#33000000")))
        assertEquals(listOf(BoxShadow(shadowColour, blurRadius = 8.0, spreadRadius = 1.0, dx = 0.0, dy = 4.0)), full.shadows)
        val gradient = assertNotNull(full.gradient)
        assertEquals(Gradient(false, listOf(orange, amber), listOf(0f, 1f), begin = Offset(0f, 0f), end = Offset(1f, 1f)), gradient)
        // begin and end sit within the box, as Flutter's Alignment.withinRect.
        assertEquals(
            Brush.linearGradient(0f to orange, 1f to amber, start = Offset(0f, 0f), end = Offset(40f, 20f)),
            gradient.brush(Size(40f, 20f)),
        )

        // Left out: a black border 1 wide, a shadow #33000000 (ARGB) with no blur,
        // spread or offset, a gradient from center to centerRight; stops that do
        // not match the colours are dropped, a colour that does not parse is clear.
        val plain = assertNotNull(
            decoration(
                "border" to emptyMap<String, Any>(),
                "boxShadow" to listOf("not a shadow", emptyMap<String, Any>()),
                "gradient" to mapOf("colors" to listOf("#000000", "red"), "stops" to listOf(0.5)),
            ),
        )
        assertNull(plain.color)
        assertNull(plain.radii)
        assertEquals(CornersShape(CornerRadii.Zero), plain.shape)
        assertEquals(Border(Color.Black, 1.0), plain.border)
        assertEquals(listOf(BoxShadow(Color(0, 0, 0, 0x33), 0.0, 0.0, 0.0, 0.0)), plain.shadows)
        assertEquals(
            Gradient(false, listOf(Color.Black, Color.Transparent), null, begin = Offset(0.5f, 0.5f), end = Offset(1f, 0.5f)),
            plain.gradient,
        )
        assertEquals(
            Brush.linearGradient(listOf(Color.Black, Color.Transparent), start = Offset(20f, 10f), end = Offset(40f, 10f)),
            plain.gradient?.brush(Size(40f, 20f)),
        )

        // A radial gradient is centred, its radius half the shorter side.
        val radial = assertNotNull(decoration("gradient" to mapOf("type" to "radial", "colors" to listOf("#000000", "#FFFFFF")))?.gradient)
        assertTrue(radial.radial)
        assertEquals(
            Brush.radialGradient(listOf(Color.Black, Color.White), center = Offset(20f, 10f), radius = 10f),
            radial.brush(Size(40f, 20f)),
        )
        assertNull(radial.brush(Size(40f, 0f)))

        assertNull(decoration("border" to mapOf("style" to "none", "width" to 3))?.border)
        assertNull(decoration("gradient" to mapOf("begin" to "topLeft"))?.gradient)
        assertEquals(BoxDecorationProps(), decoration())
        assertNull(BoxDecorationProps.of(JsonValue.String("#FFFFFF")))
        assertNull(BoxDecorationProps.of(null))
    }

    /**
     * W8 on screen, at 1 dp per pixel: the shadow, then the fill, then the
     * border inside the edge, all behind the content.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun w8_theDecorationIsPaintedBehindTheContent() {
        val red = Props.hex("#FF0000")
        val blue = Props.hex("#0000FF")
        val green = Props.hex("#00FF00")
        val box = assertNotNull(
            decoration(
                "color" to "#FF0000",
                "borderRadius" to 8,
                "border" to mapOf("color" to "#0000FF", "width" to 2),
                "boxShadow" to listOf(mapOf("color" to "#00FF00", "offset" to mapOf("dx" to 0, "dy" to 6))),
            ),
        )
        var view: View? = null
        compose.setContent {
            view = LocalView.current
            // The box spans x 10..50 and y 10..30; its shadow y 16..36.
            Box(Modifier.size(100.dp)) {
                Box(Modifier.padding(10.dp).size(40.dp, 20.dp).boxDecoration(box)) {
                    Box(Modifier.align(Alignment.CenterEnd).size(4.dp).background(Color.Yellow))
                }
            }
        }
        compose.waitForIdle()
        val picture = draw(requireNotNull(view))

        assertPixel(red, picture, 30, 20)
        assertPixel(blue, picture, 10, 20)
        assertPixel(blue, picture, 11, 20)
        assertPixel(red, picture, 13, 20)
        assertPixel(blue, picture, 30, 10)
        assertPixel(red, picture, 30, 12)
        assertPixel(Color.White, picture, 10, 10)
        assertPixel(green, picture, 30, 33)
        assertPixel(Color.White, picture, 30, 40)
        assertPixel(Color.Yellow, picture, 49, 20)
    }

    /**
     * W9: radii that do not fit shrink by one factor until every side holds
     * its two corners, as Skia and Impeller paint Flutter's RRect, so one
     * radius on all four corners stops at half the shorter side. Corners are
     * absolute and in pixels at the density; the border's inner edge is the
     * box deflated, each radius less the inset.
     */
    @Test
    fun w9_cornerRadiiAreCappedAtHalfTheShorterSide() {
        val box = Size(40f, 20f)
        val outline = CornersShape(CornerRadii.all(100.0)).createOutline(box, LayoutDirection.Ltr, Density(1f))
        val capped = assertIs<Outline.Rounded>(outline).roundRect
        assertEquals(RoundRect(Rect(0f, 0f, 40f, 20f), CornerRadius(10f)), capped)
        assertTrue(capped.contains(Offset(20f, 10f)))
        assertFalse(capped.contains(Offset(1f, 1f)))

        val uneven = CornerRadii(topLeft = 30.0, topRight = 10.0).roundRect(box.toRect(), Density(1f))
        assertEquals(20f, uneven.topLeftCornerRadius.x, 0.001f)
        assertEquals(20f / 3, uneven.topRightCornerRadius.x, 0.001f)
        assertEquals(CornerRadius.Zero, uneven.bottomLeftCornerRadius)

        val dense = CornerRadii(topLeft = 4.0, bottomRight = -2.0).roundRect(box.toRect(), Density(2f))
        assertEquals(CornerRadius(8f), dense.topLeftCornerRadius)
        assertEquals(CornerRadius.Zero, dense.bottomRightCornerRadius)

        assertEquals(
            RoundRect(Rect(2f, 2f, 38f, 18f), CornerRadius(4f)),
            CornerRadii.all(6.0).roundRect(box.toRect(), Density(1f), deflate = 2f),
        )

        val rtl = CornersShape(CornerRadii(topLeft = 8.0)).createOutline(box, LayoutDirection.Rtl, Density(1f))
        val corners = assertIs<Outline.Rounded>(rtl).roundRect
        assertEquals(CornerRadius(8f), corners.topLeftCornerRadius)
        assertEquals(CornerRadius.Zero, corners.topRightCornerRadius)
    }

    /** The view drawn in software on white, as GoldenTest draws it. */
    private fun draw(view: View): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.05f },
            "($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }
}
