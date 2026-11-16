package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.LayoutDirection
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
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A7.3: CircularProgressIndicator and LinearProgressIndicator as Flutter's
 * builders paint them (primitive_builders.dart:302-323, 364-384, painters
 * :435-513), at 1 dp per pixel on white. A Circular is 36 dp square unless
 * its parent forces a size, its arc inset half the stroke (3 by default) in
 * #2196F3: without a value one static arc from -0.5 rad over 4.5 rad (3
 * o'clock, clockwise), with one a full track at alpha 0x33 and the arc from
 * 12 o'clock. A Linear is minHeight (4) high across its parent, a #E0E0E0
 * track and a #2196F3 bar from the left, clipped to round ends.
 *
 * Points on a ring are given in degrees clockwise from 12 o'clock and are
 * sampled mid-stroke, well away from the round caps; the two are not
 * registered until K-caps (G7): the test registers them, as standard() will.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "mdpi")
class ProgressTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    private fun node(id: String, type: String, vararg props: Pair<String, Any?>): ComponentNode =
        leaf(id, type, props.associate { (key, value) -> key to JsonValue.of(value) })

    private fun circular(id: String, vararg props: Pair<String, Any?>) = node(id, CIRCULAR, *props)

    private fun linear(id: String, vararg props: Pair<String, Any?>) = node(id, LINEAR, *props)

    /**
     * The page drawn from its root in a [width] x [height] box, the two
     * indicators known to the core and drawn by their builders, tagged with
     * their ids; the box forces its size on the root when [forced].
     */
    private fun show(
        width: Dp,
        height: Dp,
        vararg nodes: ComponentNode,
        forced: Boolean = false,
        direction: LayoutDirection = LayoutDirection.Ltr,
    ) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf(CIRCULAR, LINEAR))
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register(CIRCULAR) { node, model, modifier ->
                    CircularProgressIndicatorWidget(node, model, modifier.testTag(node.id))
                }
                register(LINEAR) { node, model, modifier ->
                    LinearProgressIndicatorWidget(node, model, modifier.testTag(node.id))
                }
            }
        }
        compose.setContent {
            view = LocalView.current
            CompositionLocalProvider(LocalLayoutDirection provides direction) {
                Box(Modifier.size(width, height), propagateMinConstraints = forced) { NodeView(nodes.first().id, model) }
            }
        }
    }

    private fun box(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    /** The view drawn on white in software, as GoldenTest draws it. */
    private fun draw(): Bitmap {
        compose.waitForIdle()
        val view = requireNotNull(view)
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    /** The pixel [x], [y] dp from the top left of [box] (1 dp per pixel). */
    private fun Bitmap.at(box: DpRect, x: Double, y: Double): Int =
        getPixel(floor(box.left.value + x).toInt(), floor(box.top.value + y).toInt())

    /**
     * The pixel on the ring of [radius] about [box]'s centre, [degrees]
     * clockwise from 12 o'clock; 16.5, the default stroke's middle in 36 dp.
     */
    private fun Bitmap.ring(box: DpRect, degrees: Double, radius: Double = 16.5): Int {
        val rad = Math.toRadians(degrees)
        return at(box, box.width.value / 2 + radius * sin(rad), box.height.value / 2 - radius * cos(rad))
    }

    /** [argb] laid over white, as the picture shows it. */
    private fun onWhite(argb: Int): Int {
        val alpha = (argb ushr 24) / 255.0
        fun channel(shift: Int) = (255 + ((argb ushr shift and 0xFF) - 255) * alpha).roundToInt()
        return Color.rgb(channel(16), channel(8), channel(0))
    }

    private fun assertColor(expected: Int, actual: Int, where: String) {
        val close = intArrayOf(16, 8, 0).all { abs((expected ushr it and 0xFF) - (actual ushr it and 0xFF)) <= 8 }
        assertTrue(close, "$where is #${Integer.toHexString(actual)}, expected #${Integer.toHexString(expected)}")
    }

    /**
     * A Circular in a loose parent is 36 x 36 whatever its stroke; a Linear
     * takes the parent's width and is minHeight (4 when unset) high.
     */
    @Test
    fun a7_3_kt_aCircularIs36SquareAndALinearIsMinHeightHighAcrossItsParent() {
        show(
            120.dp, 200.dp,
            column("root", "c", "thick", "l", "tall"),
            circular("c"),
            circular("thick", "strokeWidth" to 8, "value" to 0.5),
            linear("l", "value" to 0.4),
            linear("tall", "minHeight" to 10),
        )

        for (tag in listOf("c", "thick")) {
            val circle = box(tag)
            assertEquals(36.dp to 36.dp, circle.width to circle.height, tag)
        }
        val bar = box("l")
        assertEquals(120.dp to 4.dp, bar.width to bar.height)
        val tall = box("tall")
        assertEquals(120.dp to 10.dp, tall.width to tall.height)
    }

    /**
     * Determinate at 0.4: the full ring in #2196F3 at alpha 0x33, then the
     * arc from 12 o'clock over 144 degrees in #2196F3; the middle and the
     * ring's inside stay white.
     */
    @Test
    fun a7_3_kt_aDeterminateCircularDrawsTheFaintTrackThenTheArcFromTwelve() {
        show(100.dp, 100.dp, circular("c", "value" to 0.4))

        val box = box("c")
        assertEquals(36.dp to 36.dp, box.width to box.height)
        val picture = draw()
        val track = onWhite(0x332196F3)
        for (degrees in listOf(30.0, 70.0, 100.0, 120.0)) assertColor(FLUTTER_BLUE, picture.ring(box, degrees), "arc at $degrees")
        for (degrees in listOf(170.0, 200.0, 270.0, 330.0)) assertColor(track, picture.ring(box, degrees), "track at $degrees")
        assertColor(Color.WHITE, picture.at(box, 18.0, 18.0), "centre")
        assertColor(Color.WHITE, picture.ring(box, 100.0, radius = 12.0), "inside the ring")
    }

    /**
     * Without a value one arc from -0.5 rad over 4.5 rad, about 2 o'clock
     * round to half past 10 clockwise, over no track: the top is blank. It
     * does not move.
     */
    @Test
    fun a7_3_kt_anIndeterminateCircularIsOneStaticArcOverNoTrack() {
        compose.mainClock.autoAdvance = false
        show(100.dp, 100.dp, circular("c"))

        val box = box("c")
        assertEquals(36.dp to 36.dp, box.width to box.height)
        val picture = draw()
        for (degrees in listOf(90.0, 180.0, 270.0)) assertColor(FLUTTER_BLUE, picture.ring(box, degrees), "arc at $degrees")
        for (degrees in listOf(0.0, 340.0, 20.0)) assertColor(Color.WHITE, picture.ring(box, degrees), "gap at $degrees")
        compose.mainClock.advanceTimeBy(1_000)
        assertTrue(picture.sameAs(draw()), "the arc moved")
    }

    /**
     * A parent forcing 80 x 36 makes the arc an ellipse inset half the
     * stroke: it reaches the box's right end and its bottom middle.
     */
    @Test
    fun a7_3_kt_aForcedNonSquareBoxDrawsAnEllipse() {
        show(80.dp, 36.dp, circular("c"), forced = true)

        val box = box("c")
        assertEquals(80.dp to 36.dp, box.width to box.height)
        val picture = draw()
        assertColor(FLUTTER_BLUE, picture.at(box, 78.5, 18.5), "right end")
        assertColor(FLUTTER_BLUE, picture.at(box, 40.5, 34.5), "bottom middle")
        assertColor(FLUTTER_BLUE, picture.at(box, 1.5, 18.5), "left end")
        assertColor(Color.WHITE, picture.at(box, 40.5, 18.5), "middle")
    }

    /** A Linear at 0.4 in 200 dp: the #2196F3 bar over 0..80 from the left, the #E0E0E0 track after it. */
    @Test
    fun a7_3_kt_aLinearDrawsA40PercentBarOverTheTrack() {
        show(200.dp, 50.dp, linear("l", "value" to 0.4))

        val box = box("l")
        val picture = draw()
        for (x in listOf(10.5, 40.5, 76.5)) assertColor(FLUTTER_BLUE, picture.at(box, x, 2.0), "bar at $x")
        for (x in listOf(84.5, 150.5, 190.5)) assertColor(TRACK, picture.at(box, x, 2.0), "track at $x")
    }

    /** A Linear without a value is the bare track, no bar. */
    @Test
    fun a7_3_kt_aLinearWithoutAValueIsTheBareTrack() {
        show(200.dp, 50.dp, linear("l"))

        val box = box("l")
        val picture = draw()
        for (x in listOf(5.5, 50.5, 100.5, 194.5)) assertColor(TRACK, picture.at(box, x, 2.0), "track at $x")
    }

    /**
     * `color` and `strokeWidth` on a Circular (8 wide, so the ring is
     * inked 10 to 18 from the middle); `color`, `backgroundColor`
     * and `minHeight` on a Linear, its ends cut round at half its height.
     */
    @Test
    fun a7_3_kt_coloursAndSizesComeFromTheProps() {
        show(
            100.dp, 100.dp,
            column("root", "c", "l", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            circular("c", "value" to 0.4, "color" to "#FF0000", "strokeWidth" to 8),
            linear("l", "value" to 0.4, "color" to "#00FF00", "backgroundColor" to "#0000FF", "minHeight" to 20),
        )

        val circle = box("c")
        val red = Color.RED
        val faintRed = onWhite(0x33FF0000)
        val picture = draw()
        assertColor(red, picture.ring(circle, 100.0, radius = 14.0), "arc at 100, mid-stroke")
        assertColor(red, picture.ring(circle, 100.0, radius = 12.0), "arc at 100, inner half")
        assertColor(faintRed, picture.ring(circle, 200.0, radius = 14.0), "track at 200")
        assertColor(Color.WHITE, picture.ring(circle, 200.0, radius = 8.0), "inside the ring")

        val bar = box("l")
        assertEquals(100.dp to 20.dp, bar.width to bar.height)
        assertColor(Color.GREEN, picture.at(bar, 20.5, 10.5), "bar")
        assertColor(Color.BLUE, picture.at(bar, 70.5, 10.5), "track")
        assertColor(Color.WHITE, picture.at(bar, 1.5, 1.5), "top left corner, cut")
        assertColor(Color.WHITE, picture.at(bar, 98.5, 18.5), "bottom right corner, cut")
        assertColor(Color.GREEN, picture.at(bar, 1.5, 10.5), "left end, middle")
    }

    /** Right to left the bar still runs from the left, as Flutter's painter draws it. */
    @Test
    fun a7_3_kt_rightToLeftALinearStillFillsFromTheLeft() {
        show(100.dp, 50.dp, linear("l", "value" to 0.4), direction = LayoutDirection.Rtl)

        val box = box("l")
        assertEquals(100.dp, box.width)
        val picture = draw()
        assertColor(FLUTTER_BLUE, picture.at(box, 20.5, 2.0), "left")
        assertColor(TRACK, picture.at(box, 80.5, 2.0), "right")
    }

    private companion object {
        const val CIRCULAR = "CircularProgressIndicator"
        const val LINEAR = "LinearProgressIndicator"
        const val FLUTTER_BLUE: Int = 0xFF2196F3.toInt()
        const val TRACK: Int = 0xFFE0E0E0.toInt()
    }
}
