package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasParent
import androidx.compose.ui.test.hasText
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
 *
 * I1: an Image that cannot be had draws "!" centred in its box, as
 * Flutter's error builder.
 *
 * I3: the Image sized as Flutter's RenderImage, on an xhdpi screen (2
 * pixels per dp), where the 40x20-pixel image at one dp per image pixel,
 * as Flutter lays it out, is 40x20 dp, and at one device pixel per image
 * pixel, as Compose would, 20x10.
 *
 * A1.7: `fit` and `repeat` drawn as Flutter's `paintImage`, with a second
 * PNG, 10x10 pixels, its left half red and its right half blue.
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

    private val halves: ByteArray by lazy {
        val pixels = IntArray(10 * 10) { if (it % 10 < 5) Color.RED else Color.BLUE }
        val bitmap = Bitmap.createBitmap(pixels, 10, 10, Bitmap.Config.ARGB_8888)
        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }

    /**
     * `/stripes.png` is the PNG, `/halves.png` the 10x10 one, `/slow.png`
     * the PNG once [release]d, anything else a 404.
     */
    private val server = MockWebServer().apply {
        dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse = when (request.path) {
                "/stripes.png" -> MockResponse().setBody(Buffer().write(png))
                "/halves.png" -> MockResponse().setBody(Buffer().write(halves))
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

    /** A SizedBox [width] dp wide around the node [child]. */
    private fun sizedBox(id: String, width: Int, child: String): ComponentNode = ComponentNode(
        id, "SizedBox", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        mapOf("width" to JsonValue.of(width)), listOf(child),
    )

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

    /**
     * The device pixel at [x], [y] dp from the top left of [box] (which may
     * lie outside it): the same number at mdpi, twice it at xhdpi.
     */
    private fun Bitmap.at(box: DpRect, x: Int, y: Int): Int {
        val density = compose.density.density
        return getPixel(((box.left.value + x) * density).roundToInt(), ((box.top.value + y) * density).roundToInt())
    }

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
     * A load still running leaves an empty box of the given size, described
     * by `alt`, drawn as nothing.
     */
    @Test
    fun i2_whileLoadingItIsAnEmptyBoxOfItsSize() {
        val alt = "Loading"
        show(image("0", "src" to url("/slow.png"), "alt" to alt, "width" to 30, "height" to 20))

        val before = box(alt)
        assertEquals(30.dp to 20.dp, before.width to before.height, alt)
        compose.waitUntil(5_000) { server.requestCount >= 1 }
        compose.waitForIdle()

        val picture = draw()
        val box = box(alt)
        assertEquals(30.dp to 20.dp, box.width to box.height, alt)
        for (x in 0 until 30) {
            for (y in 0 until 20) assertColor(Color.WHITE, picture.at(box, x, y), "$alt ($x, $y)")
        }
    }

    /**
     * I1: a 404, an empty `src` and a name that is not an http URL (no
     * assets in S9) each draw "!" centred in a box of the given size,
     * described by `alt`, as Flutter's error builder:
     * `SizedBox(width, height, child: Center(child: Text('!')))`.
     * A1: the box is read as `alt` with the image role, as while loading and
     * once loaded; the "!" is drawn but no semantics node carries it.
     */
    @Test
    fun i1_aFailedLoadAnEmptySrcOrANonHttpSrcDrawsAnExclamationMarkCentredInItsBox() {
        val alts = listOf("Missing", "Empty", "Asset")
        show(
            column("0", "1", "2", "3"),
            image("1", "src" to url("/missing.png"), "alt" to "Missing", "width" to 30, "height" to 20),
            image("2", "src" to "", "alt" to "Empty", "width" to 30, "height" to 20),
            image("3", "src" to "logo.png", "alt" to "Asset", "width" to 30, "height" to 20),
        )

        for (alt in alts) {
            val box = box(alt)
            assertEquals(30.dp to 20.dp, box.width to box.height, alt)
        }
        compose.waitUntil(5_000) { server.requestCount >= 1 }
        // A load of the missing URL joins the widget's, or fails the same way after it.
        runBlocking { assertNull(ImageLoader.shared.load(url("/missing.png"))) }
        compose.waitForIdle()

        // A1: read as its alt with the image role, as loading and loaded; "!" is never exposed.
        compose.onAllNodes(hasText("!")).assertCountEquals(0)
        compose.onAllNodes(hasText("!"), useUnmergedTree = true).assertCountEquals(0)
        val picture = draw()
        for (alt in alts) {
            compose.onNode(hasContentDescription(alt) and SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Image))
                .assertExists()
            val box = box(alt)
            assertEquals(30.dp to 20.dp, box.width to box.height, alt)
            val mark = compose.onNode(hasParent(hasContentDescription(alt)), useUnmergedTree = true).getUnclippedBoundsInRoot()
            // Centred to the pixel: an odd space left over puts it half a pixel off.
            val (x, y) = (box.left + box.width / 2).value to (box.top + box.height / 2).value
            assertEquals(x, (mark.left + mark.width / 2).value, 1f, "$alt: \"!\" centre x")
            assertEquals(y, (mark.top + mark.height / 2).value, 1f, "$alt: \"!\" centre y")
            val inked = (0 until 30).any { px -> (0 until 20).any { py -> picture.at(box, px, py) != Color.WHITE } }
            assertTrue(inked, "$alt: \"!\" is drawn")
        }
    }

    /**
     * With neither `width` nor `height` the loaded image is its size in
     * logical pixels, one dp per image pixel as a network image at scale 1:
     * 40x20 dp, 80x40 device pixels here.
     */
    @Test
    @Config(qualifiers = "xhdpi")
    fun i3_withNoSizeTheImageIsItsPixelSizeInDp() {
        show(image("0", "src" to url("/stripes.png"), "alt" to "Natural"))

        compose.waitUntil(5_000) { box("Natural").width > 0.dp }
        val box = box("Natural")
        assertEquals(40.dp to 20.dp, box.width to box.height)
    }

    /**
     * With only a `height` the width follows the image's 2:1, and with only
     * a `width` the height does, whatever the `fit`: 5 dp high is 10 wide
     * (cover), 60 dp wide is 30 high (contain).
     */
    @Test
    @Config(qualifiers = "xhdpi")
    fun i3_withOnlyAHeightOrOnlyAWidthTheOtherSideKeepsTheAspectRatio() {
        show(
            column("0", "1", "2"),
            image("1", "src" to url("/stripes.png"), "alt" to "Height", "height" to 5),
            image("2", "src" to url("/stripes.png"), "alt" to "Width", "width" to 60, "fit" to "contain"),
        )

        compose.waitUntil(5_000) { box("Height").width > 0.dp && box("Width").height > 0.dp }
        val height = box("Height")
        assertEquals(10.dp to 5.dp, height.width to height.height, "only a height")
        val width = box("Width")
        assertEquals(60.dp to 30.dp, width.width to width.height, "only a width")
    }

    /**
     * A parent narrower than the image's 40 dp scales it down to its width
     * keeping 2:1, as `constrainSizeAndAttemptToPreserveAspectRatio`: 16x8
     * in a 16 dp SizedBox (cover), 30x15 in a 30 dp one (contain).
     */
    @Test
    @Config(qualifiers = "xhdpi")
    fun i3_inANarrowerParentItIsScaledDownKeepingTheAspectRatio() {
        show(
            column("0", "1", "2"),
            sizedBox("1", width = 16, child = "3"),
            sizedBox("2", width = 30, child = "4"),
            image("3", "src" to url("/stripes.png"), "alt" to "Narrow"),
            image("4", "src" to url("/stripes.png"), "alt" to "Contained", "fit" to "contain"),
        )

        compose.waitUntil(5_000) { box("Narrow").height > 0.dp && box("Contained").height > 0.dp }
        val narrow = box("Narrow")
        assertEquals(16.dp to 8.dp, narrow.width to narrow.height, "cover in 16 dp")
        val contained = box("Contained")
        assertEquals(30.dp to 15.dp, contained.width to contained.height, "contain in 30 dp")
    }

    /**
     * A1.7: in an 80x80 box the 40x20 image is, as Flutter's BoxFit:
     * fitWidth 80 wide and 40 high, centred (white above and below);
     * fitHeight 160 wide and 80 high, centred and cut to the box (its red
     * and blue columns fill it); scaleDown its own 40x20, centred, never
     * enlarged. In a 20x40 box scaleDown shrinks it to 20x10 as contain.
     */
    @Test
    fun a1_7_fitWidthFitHeightAndScaleDownAreFlutters() {
        fun fitted(id: String, alt: String, fit: String, width: Int, height: Int) =
            image(id, "src" to url("/stripes.png"), "alt" to alt, "width" to width, "height" to height, "fit" to fit)
        show(
            column("0", "1", "2", "3", "4"),
            fitted("1", "Width", "fitWidth", 80, 80),
            fitted("2", "Height", "fitHeight", 80, 80),
            fitted("3", "Down", "scaleDown", 80, 80),
            fitted("4", "Shrunk", "scaleDown", 20, 40),
        )
        compose.waitUntil(5_000) { draw().at(box("Shrunk"), 7, 20) != Color.WHITE }
        val picture = draw()

        val width = box("Width")
        assertColor(Color.WHITE, picture.at(width, 40, 10), "fitWidth, above")
        for ((x, color) in listOf(10 to Color.GREEN, 30 to Color.RED, 50 to Color.BLUE, 70 to Color.GREEN)) {
            assertColor(color, picture.at(width, x, 40), "fitWidth, x $x")
        }
        assertColor(Color.WHITE, picture.at(width, 40, 70), "fitWidth, below")

        val height = box("Height")
        for (y in listOf(3, 40, 77)) {
            assertColor(Color.RED, picture.at(height, 20, y), "fitHeight, left, y $y")
            assertColor(Color.BLUE, picture.at(height, 60, y), "fitHeight, right, y $y")
        }

        val down = box("Down")
        val row = listOf(15 to Color.WHITE, 25 to Color.GREEN, 35 to Color.RED, 45 to Color.BLUE, 55 to Color.GREEN, 65 to Color.WHITE)
        for ((x, color) in row) {
            assertColor(color, picture.at(down, x, 40), "scaleDown, x $x")
        }
        assertColor(Color.WHITE, picture.at(down, 40, 25), "scaleDown, above")
        assertColor(Color.WHITE, picture.at(down, 40, 55), "scaleDown, below")

        val shrunk = box("Shrunk")
        for ((x, color) in listOf(2 to Color.GREEN, 7 to Color.RED, 12 to Color.BLUE, 17 to Color.GREEN)) {
            assertColor(color, picture.at(shrunk, x, 20), "scaleDown shrunk, x $x")
        }
        assertColor(Color.WHITE, picture.at(shrunk, 10, 10), "scaleDown shrunk, above")
        assertColor(Color.WHITE, picture.at(shrunk, 10, 30), "scaleDown shrunk, below")
    }

    /**
     * A1.7: `repeat` draws the image at its fitted size and position (fit
     * none, centred: x 15 to 25, y 5 to 15 of a 40x20 box), then tiles it
     * from there over the box, as Flutter's `ImageRepeat`: x 5 and x 15
     * both start a tile (red), x 2 ends one (blue). repeatX tiles across
     * only, repeatY down only; noRepeat draws the one image.
     */
    @Test
    fun a1_7_repeatTilesTheImageFromItsAlignedPosition() {
        fun tiled(id: String, alt: String, repeat: String) = image(
            id, "src" to url("/halves.png"), "alt" to alt, "width" to 40, "height" to 20, "fit" to "none", "repeat" to repeat,
        )
        show(
            column("0", "1", "2", "3", "4"),
            tiled("1", "Repeat", "repeat"),
            tiled("2", "RepeatX", "repeatX"),
            tiled("3", "RepeatY", "repeatY"),
            tiled("4", "Once", "noRepeat"),
        )
        compose.waitUntil(5_000) { draw().at(box("Once"), 17, 10) != Color.WHITE }
        val picture = draw()

        val repeat = box("Repeat")
        assertColor(picture.at(repeat, 15, 10), picture.at(repeat, 5, 10), "repeat: x 5 as x 15")
        assertColor(Color.RED, picture.at(repeat, 5, 10), "repeat (5, 10)")
        assertColor(Color.BLUE, picture.at(repeat, 12, 10), "repeat (12, 10)")
        assertColor(Color.BLUE, picture.at(repeat, 2, 2), "repeat (2, 2)")
        assertColor(Color.RED, picture.at(repeat, 35, 18), "repeat (35, 18)")

        val across = box("RepeatX")
        assertColor(Color.RED, picture.at(across, 5, 10), "repeatX (5, 10)")
        assertColor(Color.BLUE, picture.at(across, 32, 10), "repeatX (32, 10)")
        assertColor(Color.WHITE, picture.at(across, 17, 2), "repeatX (17, 2)")
        assertColor(Color.WHITE, picture.at(across, 17, 18), "repeatX (17, 18)")

        val down = box("RepeatY")
        assertColor(Color.RED, picture.at(down, 17, 2), "repeatY (17, 2)")
        assertColor(Color.BLUE, picture.at(down, 22, 18), "repeatY (22, 18)")
        assertColor(Color.WHITE, picture.at(down, 5, 10), "repeatY (5, 10)")
        assertColor(Color.WHITE, picture.at(down, 32, 10), "repeatY (32, 10)")

        val once = box("Once")
        assertColor(Color.RED, picture.at(once, 17, 10), "noRepeat (17, 10)")
        assertColor(Color.BLUE, picture.at(once, 22, 10), "noRepeat (22, 10)")
        for ((x, y) in listOf(5 to 10, 32 to 10, 17 to 2, 17 to 18)) {
            assertColor(Color.WHITE, picture.at(once, x, y), "noRepeat ($x, $y)")
        }
    }

    /**
     * A1.7 on an xhdpi screen (2 pixels per dp): the 10x10-pixel image is
     * 10x10 dp, as Flutter paints a network image at scale 1, whether drawn
     * once or tiled. In a 40x20 box `fit: none` and `scaleDown` both centre
     * it at x 15 to 25, y 5 to 15 (red to 20, blue after), the same as the
     * first tile of `repeat`; at one device pixel per image pixel it would
     * be 5x5 dp. With no size the box is 10x10 dp and the image fills it.
     */
    @Test
    @Config(qualifiers = "xhdpi")
    fun a1_7_atXhdpiEveryFitDrawsTheImageAtOneDpPerImagePixel() {
        fun halves(id: String, alt: String, vararg props: Pair<String, Any?>) =
            image(id, "src" to url("/halves.png"), "alt" to alt, *props)
        show(
            column("0", "1", "2", "3", "4"),
            halves("1", "None", "width" to 40, "height" to 20, "fit" to "none", "repeat" to "noRepeat"),
            halves("2", "Down", "width" to 40, "height" to 20, "fit" to "scaleDown"),
            halves("3", "Tiled", "width" to 40, "height" to 20, "fit" to "none", "repeat" to "repeatY"),
            halves("4", "Natural"),
        )
        compose.waitUntil(5_000) { draw().at(box("Down"), 20, 10) != Color.WHITE && box("Natural").width > 0.dp }
        val picture = draw()

        for (alt in listOf("None", "Down", "Tiled")) {
            val box = box(alt)
            assertEquals(40.dp to 20.dp, box.width to box.height, alt)
            assertColor(Color.RED, picture.at(box, 16, 10), "$alt (16, 10)")
            assertColor(Color.BLUE, picture.at(box, 24, 10), "$alt (24, 10)")
            assertColor(Color.WHITE, picture.at(box, 13, 10), "$alt (13, 10)")
            assertColor(Color.WHITE, picture.at(box, 27, 10), "$alt (27, 10)")
        }
        for (alt in listOf("None", "Down")) {
            val box = box(alt)
            assertColor(Color.RED, picture.at(box, 16, 6), "$alt (16, 6)")
            assertColor(Color.BLUE, picture.at(box, 24, 14), "$alt (24, 14)")
            assertColor(Color.WHITE, picture.at(box, 20, 3), "$alt (20, 3)")
            assertColor(Color.WHITE, picture.at(box, 20, 17), "$alt (20, 17)")
        }

        val natural = box("Natural")
        assertEquals(10.dp to 10.dp, natural.width to natural.height, "no size")
        for (y in listOf(1, 5, 9)) {
            assertColor(Color.RED, picture.at(natural, 1, y), "no size (1, $y)")
            assertColor(Color.BLUE, picture.at(natural, 9, y), "no size (9, $y)")
        }
    }
}
