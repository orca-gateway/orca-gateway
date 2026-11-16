package com.orcagateway.sdk

import android.graphics.Bitmap
import android.view.View
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.text
import com.orcagateway.sdk.widgets.LocalOrcaReduceMotion
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Page `name` shows "name page". */
private class TransitionPages : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse {
        val name = request.url.path.substringAfterLast("/page/")
        val page = PageResponse(pageId = name, title = name, state = emptyList(), components = listOf(text("0", "$name page")))
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    val client: OrcaClient
        get() = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", device = DeviceInfo(osVersion = "test"), transport = this)
}

/** One stack: `home`, a route per transition kind (one second, linear), `plain` with none and `none` with the type `none`. */
private val transitionConfig = NavConfig(
    initialRoute = "/home",
    flows = listOf(
        NavFlow(
            name = "main",
            routes = listOf(
                NavRoute("home"),
                NavRoute("fade", transition = RouteTransitionDef("fade", RUN_MS, "linear")),
                NavRoute("up", transition = RouteTransitionDef("slideUp", RUN_MS, "linear")),
                NavRoute("right", transition = RouteTransitionDef("slideRight", RUN_MS, "linear")),
                NavRoute("left", transition = RouteTransitionDef("slide", RUN_MS, "linear")),
                NavRoute("plain"),
                // Longer than the NavHost's own 700 ms: were it played, the page under would still be there after it.
                NavRoute("none", transition = RouteTransitionDef("none", 5_000, "linear")),
            ),
        ),
    ),
)

private const val RUN_MS = 1_000

/**
 * B12.6-K on the single stack: a pushed route's transition moves the
 * entering page only, over the page under it, by the test clock; a pop
 * plays it backwards; `none` keeps the NavHost's own animation; reduced
 * motion plays nothing. The look on a device is a hand check.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class TransitionTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /** The app on its home page, the clock then in the test's hands. */
    private fun show(reduceMotion: Boolean = false): OrcaRouter {
        val router = OrcaRouter(TransitionPages().client, transitionConfig)
        compose.setContent {
            view = LocalView.current
            CompositionLocalProvider(LocalOrcaReduceMotion provides reduceMotion) { OrcaApp(router) }
        }
        compose.waitUntil(5_000) { count("home page") == 1 }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        return router
    }

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    /** Where the text is drawn, in pixels from the top left of the screen. */
    private fun position(text: String) = compose.onNode(hasText(text)).fetchSemanticsNode().positionInRoot

    /** On the main thread, and seen by the composition; the clock does not move. */
    private fun onUi(block: () -> Unit) {
        compose.runOnUiThread(block)
        compose.waitForIdle()
    }

    private fun OrcaRouter.go(path: String) = onUi { navigate(path) }

    private fun picture(): Bitmap = draw(requireNotNull(view))

    /**
     * How far the picture [mid] is from [from] towards [to], 0...1, over the
     * pixels that are light in one and dark in the other: the opacity of
     * what [to] adds to [from].
     */
    private fun mix(from: Bitmap, mid: Bitmap, to: Bitmap): Double {
        val fractions = ArrayList<Double>()
        for (y in 0 until from.height) {
            for (x in 0 until from.width) {
                val a = from.getPixel(x, y) and 0xFF
                val b = to.getPixel(x, y) and 0xFF
                if (a - b < 150) continue
                fractions += (a - (mid.getPixel(x, y) and 0xFF)).toDouble() / (a - b)
            }
        }
        assertTrue(fractions.size > 50, "the two pictures do not differ enough: ${fractions.size} pixels")
        return fractions.sorted()[fractions.size / 2]
    }

    @Test
    fun b12_6_k_aFadeRouteFadesInOverThePageUnderIt() {
        val router = show()
        val before = picture()

        router.go("/fade")
        compose.mainClock.advanceTimeBy(500)
        assertEquals(1, count("home page"), "the page under is still there mid-run")
        assertEquals(1, count("fade page"))
        val mid = picture()

        compose.mainClock.advanceTimeBy(1_000)
        assertEquals(0, count("home page"))
        assertEquals(1, count("fade page"), "alone at the end")
        val after = picture()

        // The new page's ink is half there at half time (linear), and the old page's still fully.
        assertEquals(0.5, mix(before, mid, after), 0.1)
        assertEquals(1.0, mix(after, mid, before), 0.05, "the page under does not fade")
    }

    @Test
    fun b12_6_k_aSlideUpRouteRisesFromTheBottomAndThePageUnderStaysStill() {
        val router = show()
        val home = position("home page")
        val height = requireNotNull(view).height

        router.go("/up")
        compose.mainClock.advanceTimeBy(500)
        assertEquals(home, position("home page"), "the page under stands still")
        val mid = position("up page")

        compose.mainClock.advanceTimeBy(1_000)
        assertEquals(0, count("home page"))
        val rest = position("up page")
        assertEquals(home.y, rest.y, "in place at the end")
        assertEquals(height * 0.5f, mid.y - rest.y, height * 0.1f)
        assertEquals(rest.x, mid.x)
    }

    /** `slideRight` comes in from the right, `slide` from the left (Flutter's names). */
    @Test
    fun b12_6_k_theHorizontalSlidesComeFromTheirFlutterSides() {
        val router = show()
        val width = requireNotNull(view).width

        router.go("/right")
        compose.mainClock.advanceTimeBy(500)
        val fromRight = position("right page")
        compose.mainClock.advanceTimeBy(1_000)
        val right = position("right page")
        assertEquals(width * 0.5f, fromRight.x - right.x, width * 0.1f)
        assertEquals(right.y, fromRight.y)

        router.go("/left")
        compose.mainClock.advanceTimeBy(500)
        val fromLeft = position("left page")
        assertEquals(right, position("right page"), "the page under stands still")
        compose.mainClock.advanceTimeBy(1_000)
        assertEquals(-width * 0.5f, fromLeft.x - position("left page").x, width * 0.1f)
        assertEquals(0, count("right page"))
    }

    @Test
    fun b12_6_k_aPopPlaysTheTransitionBackwards() {
        val router = show()
        val home = position("home page")
        val height = requireNotNull(view).height
        router.go("/up")
        compose.mainClock.advanceTimeBy(1_500)
        assertEquals(0, count("home page"))
        val rest = position("up page")

        onUi { router.goBack() }
        compose.mainClock.advanceTimeBy(250)
        assertEquals(home, position("home page"), "the page under is there at once, still")
        assertEquals(height * 0.25f, position("up page").y - rest.y, height * 0.1f)
        compose.mainClock.advanceTimeBy(500)
        assertEquals(height * 0.75f, position("up page").y - rest.y, height * 0.1f)

        compose.mainClock.advanceTimeBy(500)
        assertEquals(0, count("up page"))
        assertEquals(home, position("home page"))
    }

    @Test
    fun b12_6_k_aFadeRoutePoppedFadesOutOverThePageUnderIt() {
        val router = show()
        val before = picture()
        router.go("/fade")
        compose.mainClock.advanceTimeBy(1_500)
        val pushed = picture()

        onUi { router.goBack() }
        compose.mainClock.advanceTimeBy(250)
        assertEquals(1, count("home page"))
        assertEquals(1, count("fade page"))
        val mid = picture()
        assertEquals(0.75, mix(before, mid, pushed), 0.1, "a quarter gone at a quarter of the run")

        compose.mainClock.advanceTimeBy(1_000)
        assertEquals(0, count("fade page"))
    }

    /** `none` and no transition are the NavHost's own animation (700 ms), not the route's duration and not a cut. */
    @Test
    fun b12_6_k_noneAndAbsentKeepTheNavHostDefault() {
        val router = show()
        val home = position("home page")
        for (path in listOf("none", "plain")) {
            router.go("/$path")
            compose.mainClock.advanceTimeBy(350)
            assertEquals(1, count("home page"), "$path: the default animation is running")
            assertEquals(home, position("home page"))
            val mid = position("$path page")
            compose.mainClock.advanceTimeBy(650)
            assertEquals(0, count("home page"), "$path: over after the default 700 ms")
            assertEquals(mid, position("$path page"), "$path: no slide")

            onUi { router.goBack() }
            compose.mainClock.advanceTimeBy(350)
            assertEquals(1, count("$path page"), "$path: the default pop is running")
            compose.mainClock.advanceTimeBy(650)
            assertEquals(0, count("$path page"))
        }
    }

    @Test
    fun b12_6_k_reducedMotionLandsAtOnce() {
        val router = show(reduceMotion = true)
        val home = position("home page")

        for (path in listOf("fade", "up")) {
            router.go("/$path")
            compose.mainClock.advanceTimeBy(100)
            assertEquals(0, count("home page"), "$path: no run")
            val landed = position("$path page")
            compose.mainClock.advanceTimeBy(1_500)
            assertEquals(landed, position("$path page"), "$path: in place at once")

            onUi { router.goBack() }
            compose.mainClock.advanceTimeBy(100)
            assertEquals(0, count("$path page"), "$path: no run back")
            assertEquals(home, position("home page"))
        }
    }
}
