package com.orcagateway.sdk.navigation

import androidx.activity.ComponentActivity
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.TabDef
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.text
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * The pages of the tab shell tests: page `name` shows "name page". `home`
 * also has the buttons "Go" (pushes `/home/product/3`, inside the tab) and
 * "Settings" (pushes `/settings`, outside the tabs); `search` has a
 * TextField bound to no state key; `more` is forty rows in a scroll view.
 * Every request is kept.
 */
private class ShellPages : HttpTransport {
    val requests = mutableListOf<HttpRequest>()

    /** The page paths asked for, in order. */
    val pages: List<String> get() = requests.map { it.url.path.substringAfterLast("/page/") }

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests += request
        val path = request.url.path
        if (path.endsWith("/action")) return HttpResponse(200, body = """{"actions":[]}""".encodeToByteArray())
        val name = path.substringAfterLast("/page/")
        val page = PageResponse(pageId = name, title = "Title of $name", state = emptyList(), components = nodes(name))
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    private fun nodes(name: String): List<ComponentNode> = when (name) {
        "home" -> listOf(
            column("c", "t", "go", "set"),
            text("t", "home page"),
            button("go", "TextButton", "gol", mapOf("onTap" to Action.Navigate(route = JsonValue.String("/home/product/3")))),
            text("gol", "Go"),
            button("set", "TextButton", "setl", mapOf("onTap" to Action.Navigate(route = JsonValue.String("/settings")))),
            text("setl", "Settings"),
        )
        "search" -> listOf(column("c", "t", "f"), text("t", "search page"), leaf("f", "TextField"))
        "more" -> {
            val rows = (0 until 40).map { "r$it" }
            listOf(
                ComponentNode("s", "SingleChildScrollView", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, emptyMap(), listOf("c")),
                column("c", "t", *rows.toTypedArray()),
                text("t", "more page"),
            ) + rows.map { text(it, "row $it", mapOf("style" to JsonValue.obj("fontSize" to 40))) }
        }
        else -> listOf(text("0", "$name page"))
    }

    val client: OrcaClient
        get() = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", device = DeviceInfo(osVersion = "test"), transport = this)
}

/** Three tabs (`/home` with the child `home/product/:id`, `/search`, `/more`) and `settings` outside them. */
private fun tabConfig(tabBarComponents: List<ComponentNode> = emptyList()) = NavConfig(
    initialRoute = "/home",
    tabs = listOf(
        TabDef("home", "Home", "home", "/home"),
        TabDef("search", "Search", "search", "/search"),
        TabDef("more", "More", "menu", "/more"),
    ),
    tabBarComponents = tabBarComponents,
    flows = listOf(
        NavFlow(
            name = "main",
            routes = listOf(
                NavRoute("home", children = listOf(NavRoute("home/product/:id"))),
                NavRoute("search"),
                NavRoute("more"),
                NavRoute("settings"),
            ),
        ),
    ),
)

/**
 * The tab shell on screen (Swift's `TabShellViewTests`): the default bar
 * and the lazy first visit of a tab (B10.1-K), the server tab bar (B10.4-K),
 * and the system back gesture (B10.7-K).
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class TabShellScreenTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private fun show(pages: ShellPages, config: NavConfig = tabConfig()): OrcaRouter {
        val router = OrcaRouter(pages.client, config)
        compose.setContent { OrcaApp(router) }
        awaitShown("home page")
        return router
    }

    /** A node with [text] is on screen: a kept page of another tab is composed, and not shown. */
    private fun shown(text: String): Boolean =
        compose.onAllNodes(hasText(text)).fetchSemanticsNodes().any { it.layoutInfo.isPlaced }

    private fun awaitShown(text: String) = compose.waitUntil(5_000) { shown(text) }

    private fun tagCount(tag: String): Int = compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().size

    private fun tapTab(index: Int) = compose.onNodeWithTag(tabTag(index)).performClick()

    private fun backIsHandled(): Boolean {
        compose.waitForIdle()
        var handled = false
        compose.activityRule.scenario.onActivity { handled = it.onBackPressedDispatcher.hasEnabledCallbacks() }
        return handled
    }

    /** B10.1-K: three tabs are three bar items; a tab's page is requested on its first visit, and only then. */
    @Test
    fun b10_1_threeTabsAreThreeBarItemsAndEachPageIsRequestedOnItsFirstVisit() {
        val pages = ShellPages()
        val router = show(pages)

        for (index in 0..2) compose.onNodeWithTag(tabTag(index)).assertIsDisplayed()
        assertEquals(0, tagCount(tabTag(3)))
        for (label in listOf("Home", "Search", "More")) compose.onNodeWithText(label).assertIsDisplayed()
        compose.onNodeWithText("home page").assertIsDisplayed()
        assertEquals(listOf("home"), pages.pages)

        tapTab(1)
        awaitShown("search page")
        compose.onNodeWithText("home page").assertIsNotDisplayed()
        assertEquals(listOf("home", "search"), pages.pages)

        tapTab(2)
        awaitShown("more page")
        compose.onNodeWithText("search page").assertIsNotDisplayed()
        assertEquals(listOf("home", "search", "more"), pages.pages)

        tapTab(0)
        awaitShown("home page")
        compose.onNodeWithText("more page").assertIsNotDisplayed()
        tapTab(1)
        awaitShown("search page")
        compose.waitForIdle()
        assertEquals(1, router.currentTab)
        assertEquals(listOf("home", "search", "more"), pages.pages)
    }

    /** B10.1-K: a tab comes back on the page it was left on, and a tap on the selected tab pops it to its root. */
    @Test
    fun b10_1_aTabComesBackAsItWasLeftAndAReselectPopsItToItsRoot() {
        val pages = ShellPages()
        val router = show(pages)

        compose.onNodeWithText("Go").performClick()
        awaitShown("home/product/3 page")
        compose.onNodeWithText("home page").assertIsNotDisplayed()
        compose.onNodeWithTag(tabTag(0)).assertIsDisplayed()

        tapTab(1)
        awaitShown("search page")
        tapTab(0)
        awaitShown("home/product/3 page")
        assertEquals(listOf("home/product/3"), router.stack.map { it.path })

        tapTab(0)
        awaitShown("home page")
        assertEquals(emptyList(), router.stack)
        assertEquals(0, compose.onAllNodes(hasText("home/product/3 page")).fetchSemanticsNodes().size)
        assertEquals(listOf("home", "home/product/3", "search"), pages.pages)
    }

    /** B10.1-K: a visited tab keeps what the user did there: the text typed in a field, how far a list is scrolled. */
    @Test
    fun b10_1_aVisitedTabKeepsItsTypedTextAndItsScrollOffset() {
        val pages = ShellPages()
        show(pages)
        fun typed(): String = compose.onNode(hasSetTextAction()).fetchSemanticsNode().config[SemanticsProperties.EditableText].text
        fun offset(): Float =
            compose.onNode(hasScrollAction()).fetchSemanticsNode().config[SemanticsProperties.VerticalScrollAxisRange].value()

        tapTab(1)
        awaitShown("search page")
        compose.onNode(hasSetTextAction()).performTextInput("pizza")
        assertEquals("pizza", typed())

        tapTab(2)
        awaitShown("more page")
        compose.onNode(hasScrollAction()).performTouchInput { swipeUp() }
        compose.waitForIdle()
        val scrolled = offset()
        assertTrue(scrolled > 0f, "the list did not scroll")

        tapTab(0)
        awaitShown("home page")
        tapTab(1)
        awaitShown("search page")
        assertEquals("pizza", typed())
        tapTab(2)
        awaitShown("more page")
        assertEquals(scrolled, offset())
        assertEquals(listOf("home", "search", "more"), pages.pages)
    }

    /** B10.1-K: a route outside the tabs covers the whole shell, bar included, under the title bar with its Back. */
    @Test
    fun b10_1_aNonTabRouteCoversTheBarUnderATitleBar() {
        val pages = ShellPages()
        val router = show(pages)
        assertEquals(0, tagCount(TITLE_TAG))

        compose.onNodeWithText("Settings").performClick()
        awaitShown("settings page")
        compose.onNodeWithTag(TITLE_TAG).assertTextEquals("Title of settings")
        for (index in 0..2) assertEquals(0, tagCount(tabTag(index)))
        compose.onNodeWithText("home page").assertIsNotDisplayed()
        assertEquals(0, router.currentTab)

        compose.onNodeWithContentDescription("Back").performClick()
        awaitShown("home page")
        assertEquals(0, tagCount(TITLE_TAG))
        compose.onNodeWithTag(tabTag(0)).assertIsDisplayed()
        assertEquals(listOf("home", "settings"), pages.pages)
    }

    /**
     * B10.7-K: the system back gesture pops inside the tab; at a tab's root
     * nothing handles it, so the system leaves the app (no hop to tab 0).
     */
    @Test
    fun b10_7_systemBackPopsInsideTheTabAndIsNotHandledAtATabRoot() {
        val pages = ShellPages()
        val router = show(pages)
        assertFalse(router.canGoBack)
        assertFalse(backIsHandled())

        compose.onNodeWithText("Go").performClick()
        awaitShown("home/product/3 page")
        assertTrue(router.canGoBack)
        assertTrue(backIsHandled())

        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        awaitShown("home page")
        assertEquals(emptyList(), router.stack)
        assertFalse(router.canGoBack)
        assertFalse(backIsHandled())

        // The root of another tab: still not handled, and the tab stays.
        tapTab(1)
        awaitShown("search page")
        assertFalse(backIsHandled())
        assertEquals(1, router.currentTab)

        // A route over the shell is popped by it.
        tapTab(0)
        awaitShown("home page")
        compose.onNodeWithText("Settings").performClick()
        awaitShown("settings page")
        assertTrue(backIsHandled())
        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        awaitShown("home page")
        assertFalse(backIsHandled())
    }

    /**
     * B10.4-K: the server's `tabBarComponents` are drawn in place of the
     * default bar, against app state: the text bound to `_tabIndex` follows
     * every tab change, and the tree's `SwitchTab` button switches the tab.
     */
    @Test
    fun b10_4_theServerTabBarReplacesTheDefaultOneFollowsTabIndexAndSwitches() {
        val index = JsonValue.obj("type" to "state", "scope" to "app", "key" to "_tabIndex")
        val bar = listOf(
            row("bar", "index", "to-more", "nope"),
            leaf("index", "Text", mapOf("data" to index)).copy(watches = listOf("_tabIndex")),
            button("to-more", "TextButton", "to-more-label", mapOf("onTap" to Action.SwitchTab("more"))),
            text("to-more-label", "To more"),
            // No builder knows it: it draws nothing, as on a page.
            leaf("nope", "NoSuchWidget"),
        )
        val pages = ShellPages()
        val router = show(pages, tabConfig(tabBarComponents = bar))

        for (tab in 0..2) assertEquals(0, tagCount(tabTag(tab)))
        compose.onNodeWithText("To more").assertIsDisplayed()
        compose.onNodeWithText("0").assertIsDisplayed()
        assertEquals(listOf("home"), pages.pages)

        compose.runOnUiThread { router.selectTab(1) }
        awaitShown("search page")
        compose.onNodeWithText("1").assertIsDisplayed()

        compose.onNodeWithText("To more").performClick()
        awaitShown("more page")
        assertEquals(2, router.currentTab)
        compose.onNodeWithText("2").assertIsDisplayed()
        assertEquals(listOf("home", "search", "more"), pages.pages)

        // A route over the shell covers the server bar too.
        compose.runOnUiThread { router.navigate("/settings") }
        awaitShown("settings page")
        assertEquals(0, compose.onAllNodes(hasText("To more")).fetchSemanticsNodes().size)
        compose.runOnUiThread { router.goBack() }
        awaitShown("more page")
        compose.onNodeWithText("To more").assertIsDisplayed()
    }
}

/** The tag of the top bar's title, as OrcaApp sets it. */
private const val TITLE_TAG = "orca-route-title"
