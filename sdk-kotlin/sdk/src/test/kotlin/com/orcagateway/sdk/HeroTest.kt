package com.orcagateway.sdk

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.core.models.TabDef
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import com.orcagateway.sdk.widgets.LocalOrcaReduceMotion
import com.orcagateway.sdk.widgets.OrcaHeroTag
import com.orcagateway.sdk.widgets.OrcaSharedHero
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

private fun hero(id: String, child: String, tag: String): ComponentNode =
    ComponentNode(
        id, "Hero", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        mapOf("tag" to JsonValue.String(tag)), listOf(child),
    )

/**
 * `list` (and `home`): the Hero `h` ("List hero") at the top. `detail` and
 * `fade`: the Hero `h` ("Detail hero") 300 dp lower. `empty`: a Hero with an
 * empty tag. `twins`: two Heroes `h` on one page. Each ends with "name page".
 */
private class HeroPages : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse {
        // `home/detail`, a tab's child, is the detail page.
        val name = request.url.path.substringAfterLast("/")
        val label = text("label", "$name page")
        val nodes = when (name) {
            "detail", "fade" -> listOf(
                column("c", "gap", "hero", "label"),
                sizedBox("gap", height = 300),
                hero("hero", "t", "h"),
                text("t", "Detail hero"),
                label,
            )
            "empty" -> listOf(column("c", "hero", "label"), hero("hero", "t", ""), text("t", "Empty hero"), label)
            "twins" -> listOf(
                column("c", "one", "two", "label"),
                hero("one", "t1", "h"),
                text("t1", "Twin one"),
                hero("two", "t2", "h"),
                text("t2", "Twin two"),
                label,
            )
            else -> listOf(column("c", "hero", "label"), hero("hero", "t", "h"), text("t", "List hero"), label)
        }
        val page = PageResponse(pageId = name, title = name, state = emptyList(), components = nodes)
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    val client: OrcaClient
        get() = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", device = DeviceInfo(osVersion = "test"), transport = this)
}

private val heroRoutes = listOf(
    NavRoute("list"),
    NavRoute("detail"),
    NavRoute("fade", transition = RouteTransitionDef("fade", 1_000, "linear")),
    NavRoute("empty"),
    NavRoute("twins"),
)

/** One stack, starting at `list`. */
private val stackConfig = NavConfig(initialRoute = "/list", flows = listOf(NavFlow(name = "main", routes = heroRoutes)))

/** A tab shell: `home` (the list page) with `home/detail` pushed inside the tab. */
private val shellConfig = NavConfig(
    initialRoute = "/home",
    tabs = listOf(TabDef("home", "Home", "home", "/home"), TabDef("more", "More", "menu", "/more")),
    flows = listOf(
        NavFlow(
            name = "main",
            routes = listOf(NavRoute("home", children = listOf(NavRoute("home/detail"))), NavRoute("more")),
        ),
    ),
)

/**
 * B12.5-K: a Hero with a tag is a shared element of the single-stack
 * NavHost and flies between two pages that hold the tag; an empty tag, the
 * tab shell and reduced motion draw the plain child. How the flight looks on
 * a device is a hand check.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class HeroTest {
    @get:Rule
    val compose = createComposeRule()

    /** The app on its first page, the clock then in the test's hands. */
    private fun show(config: NavConfig = stackConfig, first: String = "list", reduceMotion: Boolean = false): OrcaRouter {
        val router = OrcaRouter(HeroPages().client, config)
        compose.setContent {
            CompositionLocalProvider(LocalOrcaReduceMotion provides reduceMotion) { OrcaApp(router) }
        }
        compose.waitUntil(5_000) { count("$first page") == 1 }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        return router
    }

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    /** How many nodes are a shared element with [tag]: the modifier was really applied. */
    private fun shared(tag: String = "h"): Int =
        compose.onAllNodes(SemanticsMatcher.expectValue(OrcaSharedHero, tag)).fetchSemanticsNodes().size

    /** Whether the node showing [text] is a shared element with the tag `h`. */
    private fun isShared(text: String): Boolean =
        compose.onAllNodes(SemanticsMatcher.expectValue(OrcaSharedHero, "h") and hasText(text)).fetchSemanticsNodes().size == 1

    private fun position(text: String): Offset = compose.onNode(hasText(text)).fetchSemanticsNode().positionInRoot

    private fun onUi(block: () -> Unit) {
        compose.runOnUiThread(block)
        compose.waitForIdle()
    }

    /** Push [path] and let every run end. */
    private fun OrcaRouter.push(path: String, page: String) {
        onUi { navigate(path) }
        settle()
        assertEquals(1, count("$page page"))
    }

    private fun settle() {
        // A page loads off the test clock: step until nothing moves.
        repeat(6) {
            compose.mainClock.advanceTimeBy(500)
            compose.waitForIdle()
        }
    }

    @Test
    fun b12_5_k_aHeroWithATagIsASharedElementOnBothPagesOfTheSingleStack() {
        val router = show()
        assertTrue(isShared("List hero"), "the list page's Hero")
        assertEquals(1, compose.onAllNodes(SemanticsMatcher.expectValue(OrcaHeroTag, "h")).fetchSemanticsNodes().size)

        router.push("/detail", "detail")
        assertEquals(0, count("list page"))
        assertTrue(isShared("Detail hero"), "the detail page's Hero")
    }

    @Test
    fun b12_5_k_aPopFliesTheHeroFromItsDetailPlaceToItsListPlace() {
        val router = show()
        val list = position("List hero")
        router.push("/detail", "detail")
        val detail = position("Detail hero")
        assertTrue(detail.y - list.y > 200f, "the two places differ: $list, $detail")

        onUi { router.goBack() }
        compose.mainClock.advanceTimeBy(100)
        assertEquals(1, count("list page"), "the pop is running")
        assertEquals(1, count("detail page"))
        val mid = position("List hero")
        assertTrue(mid.y > list.y + 10f && mid.y < detail.y - 10f, "in flight between $detail and $list: $mid")

        settle()
        assertEquals(0, count("detail page"))
        assertEquals(list, position("List hero"), "at the list place at the end")
    }

    @Test
    fun b12_5_k_anEmptyTagIsNotASharedElementAndDrawsItsChild() {
        val router = show()
        router.push("/empty", "empty")
        assertEquals(1, count("Empty hero"))
        assertEquals(0, shared(""))
        assertEquals(0, shared())

        onUi { router.goBack() }
        settle()
        assertEquals(1, count("List hero"))
    }

    @Test
    fun b12_5_k_insideTheTabShellAHeroIsItsPlainChild() {
        val router = show(shellConfig, first = "home")
        assertEquals(1, count("List hero"))
        assertEquals(0, shared())

        router.push("/home/detail", "detail")
        assertEquals(1, count("Detail hero"))
        assertEquals(0, shared(), "a push inside a tab is a plain push")

        onUi { router.goBack() }
        settle()
        assertEquals(1, count("List hero"))
        assertEquals(0, count("Detail hero"))
    }

    @Test
    fun b12_5_k_reducedMotionHasNoSharedElement() {
        val router = show(reduceMotion = true)
        assertEquals(1, count("List hero"))
        assertEquals(0, shared())
        val list = position("List hero")

        router.push("/detail", "detail")
        assertEquals(1, count("Detail hero"))
        assertEquals(0, shared())

        // The NavHost's own animation still plays for a route without a transition: the Hero stays put in it.
        onUi { router.goBack() }
        compose.mainClock.advanceTimeBy(100)
        assertEquals(list, position("List hero"), "no flight")
        settle()
        assertEquals(0, count("detail page"))
        assertEquals(list, position("List hero"))
    }

    @Test
    fun b12_5_k_twoHeroesWithOneTagOnAPageDoNotCrashAndTheFirstWins() {
        val router = show()
        val list = position("List hero")
        router.push("/twins", "twins")
        assertEquals(1, count("Twin one"))
        assertEquals(1, count("Twin two"))
        assertTrue(isShared("Twin one"), "the first one is the shared element")
        assertEquals(1, shared(), "the second one is its plain child")

        onUi { router.goBack() }
        settle()
        assertEquals(0, count("twins page"))
        assertEquals(list, position("List hero"))
    }

    @Test
    fun b12_5_k_aFadeRouteWithAHeroStillCompletesBothWays() {
        val router = show()
        val list = position("List hero")

        onUi { router.navigate("/fade") }
        compose.mainClock.advanceTimeBy(500)
        assertEquals(1, count("list page"), "the page under is still there mid-run")
        settle()
        assertEquals(0, count("list page"))
        assertEquals(1, count("fade page"))
        assertTrue(isShared("Detail hero"))
        assertEquals(list.y + 300f * 2, position("Detail hero").y, 1f)

        onUi { router.goBack() }
        compose.mainClock.advanceTimeBy(250)
        assertEquals(1, count("fade page"), "the fade back is running")
        settle()
        assertEquals(0, count("fade page"))
        assertEquals(list, position("List hero"))
    }
}
