package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.client.ImageLoader
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import okio.Buffer
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.ByteArrayOutputStream
import java.net.InetAddress
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import androidx.compose.ui.graphics.Color as ComposeColor

/**
 * A7.4: ImageIcon, and an Icon with `src`, as Flutter's `ImageIcon`
 * (widgets/image_icon.dart): an `Image` in a `size` square (24 by default),
 * fitted `scaleDown` (shrunk to fit, never enlarged) and centred, tinted
 * `srcIn` with `color` or else the Icon's default colour; while it loads and
 * after a failed load, the empty square.
 *
 * The PNGs are made here and served from a MockWebServer on 127.0.0.1, as
 * ImageTest: `/half.png` is 10x10 pixels, its left half opaque blue and its
 * right half transparent; `/wide.png` is 40x20 opaque blue. ImageIcon is not
 * registered until K-caps (G7): the test registers [IconWidget] for it, as
 * standard() will. The view is drawn on white, so an untouched pixel is white.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "mdpi")
class ImageIconTest {
    @get:Rule
    val compose = createComposeRule()

    private fun png(width: Int, height: Int, color: (Int) -> Int): ByteArray {
        val pixels = IntArray(width * height) { color(it % width) }
        val bitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
        return ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }

    private val half: ByteArray by lazy { png(10, 10) { x -> if (x < 5) Color.BLUE else Color.TRANSPARENT } }
    private val wide: ByteArray by lazy { png(40, 20) { Color.BLUE } }

    /** `/half.png`, `/wide.png`, anything else a 404. */
    private val server = MockWebServer().apply {
        dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse = when (request.path) {
                "/half.png" -> MockResponse().setBody(Buffer().write(half))
                "/wide.png" -> MockResponse().setBody(Buffer().write(wide))
                else -> MockResponse().setResponseCode(404)
            }
        }
        start(InetAddress.getByName("127.0.0.1"), 0)
    }

    @After
    fun stop() {
        server.shutdown()
    }

    private var view: View? = null

    private fun url(path: String) = server.url(path).toString()

    private fun node(id: String, type: String, vararg props: Pair<String, Any?>): ComponentNode =
        leaf(id, type, props.associate { (key, value) -> key to JsonValue.of(value) })

    private fun imageIcon(id: String, vararg props: Pair<String, Any?>) = node(id, "ImageIcon", *props)

    /**
     * The page on screen, ImageIcon known to the core and drawn by
     * [IconWidget], Icons drawn by it too, both tagged with their ids; the
     * content colour [content] when given.
     */
    private fun show(vararg nodes: ComponentNode, content: ComposeColor? = null) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "ImageIcon")
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("ImageIcon") { node, model, modifier -> IconWidget(node, model, modifier.testTag(node.id)) }
                register("Icon") { node, model, modifier -> IconWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            if (content == null) {
                OrcaPageView(model)
            } else {
                CompositionLocalProvider(LocalContentColor provides content) { OrcaPageView(model) }
            }
        }
    }

    private fun box(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    /** The view drawn on white in software, as GoldenTest draws it. */
    private fun draw(): Bitmap {
        val view = requireNotNull(view)
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    /** The device pixel at [x], [y] dp from the top left of [box]. */
    private fun Bitmap.at(box: DpRect, x: Int, y: Int): Int {
        val density = compose.density.density
        return getPixel(((box.left.value + x) * density).roundToInt(), ((box.top.value + y) * density).roundToInt())
    }

    private fun assertColor(expected: Int, actual: Int, where: String) {
        val close = intArrayOf(24, 16, 8, 0).all { abs((expected ushr it and 0xFF) - (actual ushr it and 0xFF)) <= 8 }
        assertTrue(close, "$where is #${Integer.toHexString(actual)}, expected #${Integer.toHexString(expected)}")
    }

    /** Waits until the pixel [x], [y] dp into [tag] is no longer white. */
    private fun awaitInk(tag: String, x: Int, y: Int) {
        compose.waitUntil(5_000) { draw().at(box(tag), x, y) != Color.WHITE }
        compose.waitForIdle()
    }

    /**
     * The 10x10 image in a 40 dp square keeps its 10 dp, one dp per image
     * pixel on this xhdpi screen as a network image at scale 1, centred: its
     * opaque half fills 15 to 20 dp across, and around it the square is
     * white. Scaled to the square, its opaque half would cover 0 to 20 dp.
     */
    @Test
    @Config(qualifiers = "xhdpi")
    fun a7_4_kt_aSmallImageKeepsItsSizeCentredInTheSquare() {
        show(imageIcon("0", "src" to url("/half.png"), "size" to 40, "color" to "#FF00FF"))

        val box = box("0")
        assertEquals(40.dp to 40.dp, box.width to box.height)
        awaitInk("0", 17, 20)
        val picture = draw()
        assertColor(Color.MAGENTA, picture.at(box, 17, 20), "opaque half")
        assertColor(Color.MAGENTA, picture.at(box, 16, 16), "opaque half, top")
        assertColor(Color.MAGENTA, picture.at(box, 19, 24), "opaque half, bottom")
        for ((x, y) in listOf(12 to 20, 5 to 5, 17 to 12, 17 to 28, 35 to 35, 23 to 20)) {
            assertColor(Color.WHITE, picture.at(box, x, y), "($x, $y)")
        }
    }

    /**
     * The 40x20 image in a 20 dp square is shrunk to 20x10, keeping its 2:1,
     * and centred: blank 5 dp above and below, the full width inked between.
     */
    @Test
    fun a7_4_kt_aBigImageIsShrunkToFitKeepingItsAspectRatio() {
        show(imageIcon("0", "src" to url("/wide.png"), "size" to 20, "color" to "#FF00FF"))

        val box = box("0")
        assertEquals(20.dp to 20.dp, box.width to box.height)
        awaitInk("0", 10, 10)
        val picture = draw()
        for (x in listOf(1, 10, 18)) assertColor(Color.MAGENTA, picture.at(box, x, 10), "middle row, x $x")
        assertColor(Color.MAGENTA, picture.at(box, 10, 6), "just inside the top")
        assertColor(Color.MAGENTA, picture.at(box, 10, 13), "just inside the bottom")
        assertColor(Color.WHITE, picture.at(box, 10, 2), "above")
        assertColor(Color.WHITE, picture.at(box, 10, 17), "below")
    }

    /** `color` replaces the image's own colour where it is opaque (srcIn); its transparent half stays clear. */
    @Test
    fun a7_4_kt_theTintColoursTheOpaquePixelsOnly() {
        show(imageIcon("0", "src" to url("/half.png"), "size" to 10, "color" to "#00FF00"))

        awaitInk("0", 2, 5)
        val picture = draw()
        val box = box("0")
        for (y in listOf(1, 5, 8)) {
            assertColor(Color.GREEN, picture.at(box, 2, y), "opaque half, y $y")
            assertColor(Color.WHITE, picture.at(box, 7, y), "transparent half, y $y")
        }
    }

    /** No `color`: tinted with the Icon's default, the content colour, as Flutter's IconTheme colour. */
    @Test
    fun a7_4_kt_noColorTintsWithTheIconDefault() {
        val content = ComposeColor(0xFF008080)
        show(imageIcon("0", "src" to url("/half.png"), "size" to 10), content = content)

        awaitInk("0", 2, 5)
        val picture = draw()
        val box = box("0")
        assertColor(content.toArgb(), picture.at(box, 2, 5), "opaque half")
        assertColor(Color.WHITE, picture.at(box, 7, 5), "transparent half")
    }

    /** No `size`: a 24 dp square, the 10x10 image centred in it at its own size. */
    @Test
    fun a7_4_kt_theSizeDefaultsToTwentyFour() {
        show(imageIcon("0", "src" to url("/half.png"), "color" to "#FF00FF"))

        val box = box("0")
        assertEquals(24.dp to 24.dp, box.width to box.height)
        awaitInk("0", 9, 12)
        val picture = draw()
        assertColor(Color.MAGENTA, picture.at(box, 9, 12), "opaque half")
        assertColor(Color.WHITE, picture.at(box, 4, 12), "left of the image")
        assertColor(Color.WHITE, picture.at(box, 14, 12), "transparent half")
    }

    /**
     * A 404 and a `src` that is not an http URL leave the empty square of
     * the size: nothing drawn, no error mark, no name glyph.
     */
    @Test
    fun a7_4_kt_aFailedSrcLeavesTheEmptySquare() {
        show(
            column("r", "0", "1"),
            imageIcon("0", "src" to url("/missing.png"), "size" to 30, "color" to "#FF00FF"),
            node("1", "Icon", "src" to "logo.png", "name" to "home", "size" to 30, "color" to "#FF00FF"),
        )

        compose.waitUntil(5_000) { server.requestCount >= 1 }
        // A load of the missing URL joins the widget's, or fails the same way after it.
        runBlocking { assertNull(ImageLoader.shared.load(url("/missing.png"))) }
        compose.waitForIdle()
        val picture = draw()
        for (tag in listOf("0", "1")) {
            val box = box(tag)
            assertEquals(30.dp to 30.dp, box.width to box.height, tag)
            for (x in 0 until 30) {
                for (y in 0 until 30) assertColor(Color.WHITE, picture.at(box, x, y), "$tag ($x, $y)")
            }
        }
    }

    /** An Icon with `src` is the same path: the small image kept at its size, centred, tinted. */
    @Test
    fun a7_4_kt_anIconWithSrcDrawsAsImageIcon() {
        show(
            column("r", "0", "1"),
            imageIcon("0", "src" to url("/half.png"), "size" to 40, "color" to "#FF00FF"),
            node("1", "Icon", "src" to url("/half.png"), "name" to "home", "size" to 40, "color" to "#FF00FF"),
        )

        awaitInk("0", 17, 20)
        awaitInk("1", 17, 20)
        val picture = draw()
        val image = box("0")
        val icon = box("1")
        assertEquals(image.width to image.height, icon.width to icon.height)
        for (x in 0 until 40) {
            for (y in 0 until 40) {
                assertEquals(picture.at(image, x, y), picture.at(icon, x, y), "($x, $y)")
            }
        }
        assertColor(Color.MAGENTA, picture.at(icon, 17, 20), "Icon, opaque half")
        assertColor(Color.WHITE, picture.at(icon, 12, 20), "Icon, left of the image")
    }
}
