package com.orcagateway.sdk

import android.os.Build
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.orcagateway.sdk.support.kotlinRoot
import com.orcagateway.sdk.support.recordedPage
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.fail

/**
 * T6.3.4: one golden of the counter page, 393x852 dp at 2x (xhdpi), light,
 * drawn by Robolectric's native graphics. Swift's T2.4 at the same size.
 *
 * The picture depends on the runtime that draws it (Robolectric's Skia and
 * fonts, per host OS) as well as on the page, so the golden is compared only
 * on the runtime that recorded it: `counter-home.runtime` next to the PNG
 * names that runtime, and the test skips elsewhere. Record with
 * `./gradlew :sdk:testDebugUnitTest --tests '*GoldenTest*' -Porca.recordGoldens=true`;
 * the recording run fails on purpose (as Swift's does), the next one compares.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class GoldenTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun counterPage() {
        val model = OrcaPageModel(recordedPage("counter-home"))
        var view: View? = null
        compose.setContent {
            view = LocalView.current
            OrcaPageView(model)
        }
        compose.waitForIdle()
        assertGolden(draw(requireNotNull(view)), "counter-home")
    }

    /**
     * The Compose view drawn into a bitmap on white, in software (Swift
     * renders the layer tree the same way). `captureToImage` times out here:
     * its forced redraw never sees a frame under Robolectric. A software
     * canvas draws no elevation shadows, so the buttons' shadows are not in
     * the picture.
     */
    private fun draw(view: View): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun assertGolden(image: Bitmap, name: String) {
        assertEquals(SIZE_PX, image.width to image.height, "capture size")
        val goldens = File(kotlinRoot, "sdk/src/test/resources/goldens")
        val png = File(goldens, "$name.png")
        val marker = File(goldens, "$name.runtime")
        val actual = pixels(image)

        if (System.getProperty("orca.recordGoldens") == "true") {
            goldens.mkdirs()
            write(actual, image.width, image.height, png)
            marker.writeText(runtime)
            fail("Recorded ${png.path} on $runtimeLine; run the test again.")
        }

        assumeTrue("$name has no golden; record one with -Porca.recordGoldens=true", png.isFile && marker.isFile)
        val recordedOn = marker.readText()
        assumeTrue(
            "$name was recorded on ${recordedOn.trim().replace('\n', ' ')}, this is $runtimeLine; not compared",
            recordedOn == runtime,
        )

        val golden = ImageIO.read(png)
        val share = if (golden.width != image.width || golden.height != image.height) {
            1.0
        } else {
            differingShare(actual, golden.getRGB(0, 0, golden.width, golden.height, null, 0, golden.width))
        }
        if (share > MAX_DIFFERING_SHARE) {
            val dir = File(kotlinRoot, "sdk/build/goldens").apply { mkdirs() }
            val out = File(dir, "$name.actual.png")
            write(actual, image.width, image.height, out)
            fail(
                "$name: ${"%.3f".format(share * 100)}% of pixels differ (limit ${MAX_DIFFERING_SHARE * 100}%). " +
                    "Actual image: ${out.path}",
            )
        }
    }

    /** ARGB pixels, row by row. */
    private fun pixels(bitmap: Bitmap): IntArray {
        val out = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(out, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        return out
    }

    private fun write(argb: IntArray, width: Int, height: Int, file: File) {
        val image = BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
        image.setRGB(0, 0, width, height, argb, 0, width)
        check(ImageIO.write(image, "png", file)) { "no PNG writer" }
    }

    /** Share of pixels where any ARGB channel differs by more than the tolerance. */
    private fun differingShare(a: IntArray, b: IntArray): Double {
        var differing = 0
        for (i in a.indices) {
            for (shift in intArrayOf(24, 16, 8, 0)) {
                if (abs((a[i] ushr shift and 0xFF) - (b[i] ushr shift and 0xFF)) > CHANNEL_TOLERANCE) {
                    differing++
                    break
                }
            }
        }
        return differing.toDouble() / maxOf(a.size, 1)
    }

    private companion object {
        /** 393x852 dp at 2x. */
        val SIZE_PX = 786 to 1704

        /** A pixel differs when a channel moves by more than this (0...255), as in Swift. */
        const val CHANNEL_TOLERANCE = 48

        /** The test fails when more than this share of pixels differs: 0.01%, as in Swift. */
        const val MAX_DIFFERING_SHARE = 0.0001

        /** What draws the picture: the host OS and the Android SDK Robolectric runs. */
        val runtime: String
            get() = "os=${System.getProperty("os.name")}\nrobolectricSdk=${Build.VERSION.SDK_INT}\n"

        val runtimeLine: String get() = runtime.trim().replace('\n', ' ')
    }
}
