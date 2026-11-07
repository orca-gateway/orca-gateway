package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * I2: the Image widget as Flutter's `_buildImage` draws a network image,
 * loaded through the shared [ImageLoader] from a MockWebServer on
 * 127.0.0.1. The PNG is made here: 40x20 pixels in four 10-pixel columns,
 * green, red, blue, green. Native graphics decode and draw it, at 1 dp per
 * pixel. Each test has its own server port, so the shared loader's cache
 * never answers one test with another's image.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "mdpi")
class ImageTest {
    @get:Rule
    val compose = createComposeRule()

    /** Lets `/slow.png` answer. */
    private val release = CountDownLatch(1)

    private val png: ByteArray by lazy {
        val columns = intArrayOf(Color.GREEN, Color.RED, Color.BLUE, Color.GREEN)
        val pixels = IntArray(40 * 20) { columns[it % 40 / 10] }
        val bitmap = Bitmap.createBitmap(pixels, 40, 20, Bitmap.Config.ARGB_8888)
        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }

    /** `/stripes.png` is the PNG, `/slow.png` the PNG once [release]d, anything else a 404. */
    private val server = MockWebServer().apply {
        dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse = when (request.path) {
                "/stripes.png" -> MockResponse().setBody(Buffer().write(png))
                "/slow.png" -> {
                    release.await(5, TimeUnit.SECONDS)
                    MockResponse().setBody(Buffer().write(png))
                }
                else -> MockResponse().setResponseCode(404)
            }
        }
        start(InetAddress.getByName("127.0.0.1"), 0)
    }

    @After
    fun stop() {
        release.countDown()
        server.shutdown()
    }

    private var view: View? = null

    private fun url(path: String) = server.url(path).toString()

    private fun image(id: String, vararg props: Pair<String, Any?>): ComponentNode =
        leaf(id, "Image", props.associate { (key, value) -> key to JsonValue.of(value) })

    /** The page on screen, with Image known to the core and drawn by [ImageWidget]. */
    private fun show(vararg nodes: ComponentNode) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "Image")
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Image") { node, model, modifier -> ImageWidget(node, model, modifier) }
            }
        }
        compose.setContent {
            view = LocalView.current
            OrcaPageView(model)
        }
    }

    /** The node whose content description is [alt], in dp (pixels here). */
    private fun box(alt: String): DpRect = compose.onNodeWithContentDescription(alt).getUnclippedBoundsInRoot()

    /** The view drawn on white in software, as GoldenTest draws it. */
    private fun draw(): Bitmap {
        val view = requireNotNull(view)
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    /** The pixel [x], [y] from the top left of [box] (which may lie outside it). */
    private fun Bitmap.at(box: DpRect, x: Int, y: Int): Int =
        getPixel(box.left.value.roundToInt() + x, box.top.value.roundToInt() + y)

    private fun assertColor(expected: Int, actual: Int, where: String) {
        val close = intArrayOf(24, 16, 8, 0).all { abs((expected ushr it and 0xFF) - (actual ushr it and 0xFF)) <= 8 }
        assertTrue(close, "$where is #${Integer.toHexString(actual)}, expected #${Integer.toHexString(expected)}")
    }

    /**
     * Cover by default: the 40x20 image scaled by 2 to 80x40 and cropped to
     * the box's middle, its red and blue columns, nothing drawn outside the
     * box. `alt` describes the box, sized by `width` and `height`.
     */
    @Test
    fun i2_aNetworkImageCoversItsBoxWithAltAsItsDescription() {
        show(image("0", "src" to url("/stripes.png"), "alt" to "Stripes", "width" to 40, "height" to 40))

        val box = box("Stripes")
        assertEquals(40.dp to 40.dp, box.width to box.height)
        compose.waitUntil(5_000) { draw().at(box, 5, 20) != Color.WHITE }
        val picture = draw()
        assertColor(Color.RED, picture.at(box, 5, 20), "left half")
        assertColor(Color.RED, picture.at(box, 15, 2), "left half, top")
        assertColor(Color.BLUE, picture.at(box, 35, 20), "right half")
        assertColor(Color.BLUE, picture.at(box, 25, 37), "right half, bottom")
        assertColor(Color.WHITE, picture.at(box, -5, 20), "left of the box")
        assertColor(Color.WHITE, picture.at(box, 45, 20), "right of the box")
    }

    /**
     * `fit` is Flutter's BoxFit by name (cover when unknown); `contain` with
     * `alignment: topLeft` puts the 40x20 image in the top half of a 40x40
     * box; `color` tints it as Flutter's default `srcIn` blend does.
     */
    @Test
    fun i2_fitAlignmentAndColorAreFlutters() {
        val fits = mapOf(
            "fill" to ContentScale.FillBounds,
            "contain" to ContentScale.Fit,
            "cover" to ContentScale.Crop,
            "fitWidth" to ContentScale.FillWidth,
            "fitHeight" to ContentScale.FillHeight,
            "none" to ContentScale.None,
            "scaleDown" to ContentScale.Inside,
        )
        assertEquals(fits, fits.mapValues { (name, _) -> imageFit(JsonValue.String(name)) })
        assertEquals(ContentScale.Crop, imageFit(null))
        assertEquals(ContentScale.Crop, imageFit(JsonValue.String("tile")))

        show(
            image(
                "0", "src" to url("/stripes.png"), "alt" to "Tinted", "width" to 40, "height" to 40,
                "fit" to "contain", "alignment" to "topLeft", "color" to "#FF00FF",
            ),
        )
        val box = box("Tinted")
        assertEquals(40.dp to 40.dp, box.width to box.height)
        compose.waitUntil(5_000) { draw().at(box, 5, 5) != Color.WHITE }
        val picture = draw()
        assertColor(Color.MAGENTA, picture.at(box, 5, 5), "top left")
        assertColor(Color.MAGENTA, picture.at(box, 35, 15), "top right")
        assertColor(Color.WHITE, picture.at(box, 5, 25), "bottom left")
        assertColor(Color.WHITE, picture.at(box, 35, 35), "bottom right")
    }

    /**
     * A load still running, a 404 and a name that is not an http URL (no
     * assets in S9) each leave an empty box of the given size, described
     * by `alt`, drawn as nothing.
     */
    @Test
    fun i2_whileLoadingAfterAFailedLoadOrWithNoNetworkSrcItIsAnEmptyBoxOfItsSize() {
        val alts = listOf("Loading", "Missing", "Asset")
        show(
            column("0", "1", "2", "3"),
            image("1", "src" to url("/slow.png"), "alt" to "Loading", "width" to 30, "height" to 20),
            image("2", "src" to url("/missing.png"), "alt" to "Missing", "width" to 30, "height" to 20),
            image("3", "src" to "logo.png", "alt" to "Asset", "width" to 30, "height" to 20),
        )

        for (alt in alts) {
            val box = box(alt)
            assertEquals(30.dp to 20.dp, box.width to box.height, alt)
        }
        compose.waitUntil(5_000) { server.requestCount >= 2 }
        // A load of the missing URL joins the widget's, or fails the same way after it.
        runBlocking { assertNull(ImageLoader.shared.load(url("/missing.png"))) }
        compose.waitForIdle()

        val picture = draw()
        for (alt in alts) {
            val box = box(alt)
            assertEquals(30.dp to 20.dp, box.width to box.height, alt)
            for (x in 0 until 30) {
                for (y in 0 until 20) assertColor(Color.WHITE, picture.at(box, x, y), "$alt ($x, $y)")
            }
        }
    }
}
