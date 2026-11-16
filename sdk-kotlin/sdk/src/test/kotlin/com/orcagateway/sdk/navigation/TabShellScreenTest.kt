package com.orcagateway.sdk.navigation

import android.view.View
import androidx.activity.ComponentActivity
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasAnyDescendant
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.compose.ui.test.swipeUp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.DrawerItemDef
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.core.models.TabDef
import com.orcagateway.core.navigation.PageMotion
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPlugin
import com.orcagateway.sdk.WidgetBuilder
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import com.orcagateway.sdk.widgets.LocalOrcaReduceMotion
import com.orcagateway.sdk.widgets.SafeAreaWidget
import com.orcagateway.sdk.widgets.SizedBoxWidget
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * The pages of the tab shell tests: page `name` shows "name page". `home`
 * also has the buttons "Go" (pushes `/home/product/3`, inside the tab) and
 * "Settings" (pushes `/settings`, outside the tabs) and "Open drawer" (the
 * `openDrawer` action); `search` has a TextField bound to no state key;
 * `more` is forty rows in a scroll view.
 * Every request is kept. With [appBars] every page is a Scaffold whose
 * AppBar is titled "bar of name", over that body.
 */
private class ShellPages(private val appBars: Boolean = false) : HttpTransport {
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

    private fun nodes(name: String): List<ComponentNode> {
        val body = body(name)
        if (!appBars) return body
        return listOf(
            structure("sc", "Scaffold", mapOf("appBar" to "ab", "body" to body.first().id)),
            structure("ab", "AppBar", mapOf("title" to "abt")),
            text("abt", "bar of $name"),
        ) + body
    }

    private fun structure(id: String, type: String, slots: Map<String, String>) = ComponentNode(
        id, type, ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
        slots.mapValues { JsonValue.String(it.value) }, slots.values.toList(),
    )

    private fun body(name: String): List<ComponentNode> = when (name) {
        "home" -> listOf(
            column("c", "t", "go", "set", "od"),
            text("t", "home page"),
            button("go", "TextButton", "gol", mapOf("onTap" to Action.Navigate(route = JsonValue.String("/home/product/3")))),
            text("gol", "Go"),
            button("set", "TextButton", "setl", mapOf("onTap" to Action.Navigate(route = JsonValue.String("/settings")))),
            text("setl", "Settings"),
            button("od", "TextButton", "odl", mapOf("onTap" to Action.OpenDrawer)),
            text("odl", "Open drawer"),
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

/**
 * Pages whose root is a SafeArea `s-name` around the SizedBox `box-name`,
 * as large as it is let be: the box fills what the SafeArea leaves.
 */
private class SafeAreaPages : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse {
        val name = request.url.path.substringAfterLast("/page/")
        val nodes = listOf(
            ComponentNode("s-$name", "SafeArea", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, emptyMap(), listOf("box-$name")),
            sizedBox("box-$name", width = 10_000, height = 10_000),
        )
        val page = PageResponse(pageId = name, title = "Title of $name", state = emptyList(), components = nodes)
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    val client: OrcaClient
        get() = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", device = DeviceInfo(osVersion = "test"), transport = this)
}

/**
 * Three tabs (`/home` with the child `home/product/:id`, `/search`, `/more`)
 * and `settings` outside them; a drawer when [drawerItems] or
 * [drawerComponents] has any.
 */
private fun tabConfig(
    tabBarComponents: List<ComponentNode> = emptyList(),
    drawerItems: List<DrawerItemDef> = emptyList(),
    drawerComponents: List<ComponentNode> = emptyList(),
) = NavConfig(
    initialRoute = "/home",
    tabs = listOf(
        TabDef("home", "Home", "home", "/home"),
        TabDef("search", "Search", "search", "/search"),
        TabDef("more", "More", "menu", "/more"),
    ),
    drawerItems = drawerItems,
    tabBarComponents = tabBarComponents,
    drawerComponents = drawerComponents,
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

/** The default drawer's entries: a route outside the tabs, and one inside the first tab. */
private val drawerItems = listOf(
    DrawerItemDef("settings", "App settings", "settings", "/settings"),
    DrawerItemDef("product", "Product 3", null, "/home/product/3"),
)

/**
 * The tab shell on screen (Swift's `TabShellViewTests`): the default bar
 * and the lazy first visit of a tab (B10.1-K), the server tab bar (B10.4-K),
 * the shell drawer (B10.5-K), the system back gesture (B10.7-K), pages
 * kept across tab switches and drawer cycles (B10.8-K), and the bottom
 * inset a tab page leaves to the tab bar (A3.6-K).
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

    /** The node tagged [tag] is composed and inside the screen: a closed drawer's sheet is composed beside it. */
    private fun onScreen(tag: String): Boolean = runCatching { compose.onNodeWithTag(tag).assertIsDisplayed() }.isSuccess

    /** The default drawer is open on screen: its header and every item. */
    private fun defaultDrawerShown(): Boolean {
        compose.waitForIdle()
        val header = runCatching { compose.onNodeWithText("Menu").assertIsDisplayed() }.isSuccess
        val items = drawerItems.map { onScreen(drawerItemTag(it.id)) }
        assertEquals(List(items.size) { header }, items, "the header and the items are not shown together")
        return header
    }

    private fun onUi(block: () -> Unit) {
        compose.runOnUiThread(block)
        compose.waitForIdle()
    }

    /** Tap the part of the open drawer's scrim that its sheet leaves free: the trailing edge. */
    private fun tapScrim() {
        compose.onNodeWithContentDescription(CLOSE_DRAWER).performTouchInput { click(Offset(width - 4f, height / 2f)) }
        compose.waitForIdle()
    }

    /** The back arrows on screen: a kept page under the one on top is composed, and not shown. */
    private fun backArrows(): Int {
        compose.waitForIdle()
        return compose.onAllNodes(hasContentDescription("Back")).fetchSemanticsNodes().count { it.layoutInfo.isPlaced }
    }

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
     * The AppBar of a page pushed inside a tab shows the implied back arrow,
     * and it pops inside the tab; the AppBar of a tab's root shows none.
     */
    @Test
    fun seam_anAppBarInsideATabShowsABackArrowOnAPushedPageOnlyAndItPopsInsideTheTab() {
        val pages = ShellPages(appBars = true)
        val router = show(pages)
        awaitShown("bar of home")
        assertEquals(0, backArrows())

        compose.onNodeWithText("Go").performClick()
        awaitShown("bar of home/product/3")
        assertEquals(1, backArrows())
        compose.onNodeWithTag(tabTag(0)).assertIsDisplayed()

        compose.onNodeWithContentDescription("Back").performClick()
        awaitShown("bar of home")
        assertEquals(emptyList(), router.stack)
        assertEquals(0, router.currentTab)
        assertEquals(0, backArrows())

        // The root of another tab has none either.
        tapTab(1)
        awaitShown("bar of search")
        assertEquals(0, backArrows())
    }

    /**
     * The AppBar of a route over the shell shows the implied back arrow,
     * under the one of the route's title bar, and it pops the route.
     */
    @Test
    fun seam_anAppBarOnARouteOverTheShellShowsABackArrowThatPopsTheRoute() {
        val pages = ShellPages(appBars = true)
        val router = show(pages)

        compose.onNodeWithText("Settings").performClick()
        awaitShown("bar of settings")
        // The title bar's and the AppBar's.
        assertEquals(2, backArrows())

        compose.onAllNodes(hasContentDescription("Back"))[1].performClick()
        awaitShown("bar of home")
        assertEquals(emptyList(), router.overRoutes)
        assertEquals(0, backArrows())
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

        onUi { router.selectTab(1) }
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
        onUi { router.goBack() }
        awaitShown("more page")
        compose.onNodeWithText("To more").assertIsDisplayed()
    }

    /**
     * Seam of C16.1 with B10.4-K: the shell's server trees get OrcaApp's
     * plugins as its pages do. A plugin widget in `tabBarComponents` is kept
     * and drawn with the plugin's builder, and a custom action tapped there
     * runs its handler; the tab page beside it draws the plugin widget too.
     */
    @Test
    fun seam_aServerTabBarDrawsPluginWidgetsAndRunsCustomActionsAsATabPageDoes() {
        val bar = listOf(
            row("bar", "badge", "rate"),
            leaf("badge", "ShellBadge"),
            button("rate", "TextButton", "rate-label", mapOf("onTap" to Action.Custom(JsonValue.obj("type" to "custom:rateApp")))),
            text("rate-label", "Rate"),
        )
        val badge: WidgetBuilder = { node, _, modifier -> BasicText("badge of ${node.id}", modifier.testTag("shell-badge-${node.id}")) }
        val plugin = object : OrcaPlugin {
            override val name: String = "badge"
            override val widgets: Map<String, WidgetBuilder> = mapOf("ShellBadge" to badge)
        }
        val rated = mutableListOf<JsonObject>()
        // The first tab's page is one plugin widget.
        val pages = object : HttpTransport {
            override suspend fun send(request: HttpRequest): HttpResponse {
                val name = request.url.path.substringAfterLast("/page/")
                val page = PageResponse(pageId = name, title = name, state = emptyList(), components = listOf(leaf("page", "ShellBadge")))
                return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
            }
        }
        val client = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", device = DeviceInfo(osVersion = "test"), transport = pages)
        val router = OrcaRouter(client, tabConfig(tabBarComponents = bar))
        compose.setContent {
            OrcaApp(
                router,
                plugins = listOf(plugin),
                customActions = mapOf("rateApp" to OrcaActionHandler { action, _ -> rated += action }),
            )
        }

        // The tab page, loaded through the router's loader.
        compose.waitUntil(5_000) { tagCount("shell-badge-page") == 1 }
        // The server tab bar.
        compose.onNodeWithTag("shell-badge-badge").assertIsDisplayed()
        compose.onNodeWithText("Rate").performClick()
        compose.waitForIdle()
        assertEquals(1, rated.size)
        assertEquals("\"custom:rateApp\"", rated.single()["type"].toString())
    }

    /**
     * B10.5-K: with a drawer in the config every tab page, at any depth, is
     * under the shell's top bar: the current tab's label and the menu
     * button. A route over the shell has its own title bar instead.
     */
    @Test
    fun b10_5_withADrawerEveryTabPageIsUnderATopBarWithTheTabLabelAndTheMenuButton() {
        val pages = ShellPages()
        show(pages, tabConfig(drawerItems = drawerItems))

        compose.onNodeWithTag(SHELL_TITLE_TAG).assertIsDisplayed().assertTextEquals("Home")
        compose.onNodeWithTag(DRAWER_MENU_TAG).assertIsDisplayed()
        compose.onNodeWithContentDescription("Menu").assertIsDisplayed()
        assertFalse(defaultDrawerShown())

        tapTab(1)
        awaitShown("search page")
        compose.onNodeWithTag(SHELL_TITLE_TAG).assertTextEquals("Search")
        compose.onNodeWithTag(DRAWER_MENU_TAG).assertIsDisplayed()

        tapTab(0)
        awaitShown("home page")
        compose.onNodeWithText("Go").performClick()
        awaitShown("home/product/3 page")
        compose.onNodeWithTag(SHELL_TITLE_TAG).assertIsDisplayed().assertTextEquals("Home")
        compose.onNodeWithTag(DRAWER_MENU_TAG).assertIsDisplayed()

        compose.onNodeWithTag(tabTag(0)).performClick()
        awaitShown("home page")
        compose.onNodeWithText("Settings").performClick()
        awaitShown("settings page")
        assertEquals(0, tagCount(SHELL_TITLE_TAG))
        assertEquals(0, tagCount(DRAWER_MENU_TAG))
        compose.onNodeWithTag(TITLE_TAG).assertTextEquals("Title of settings")
    }

    /**
     * B10.5-K: the menu button, `router.openDrawer()` and a page's
     * `openDrawer` action each open the default drawer (the "Menu" header
     * and one row per `drawerItems` entry); `router.closeDrawer()`, a tap on
     * the scrim and a swipe each close it, and the router follows.
     */
    @Test
    fun b10_5_theMenuButtonTheRouterAndAPageActionOpenTheDefaultDrawerAndItClosesThreeWays() {
        val pages = ShellPages()
        val router = show(pages, tabConfig(drawerItems = drawerItems))
        assertFalse(defaultDrawerShown())

        compose.onNodeWithTag(DRAWER_MENU_TAG).performClick()
        assertTrue(defaultDrawerShown())
        assertTrue(router.isDrawerOpen)
        compose.onNodeWithText("Product 3").assertIsDisplayed()
        onUi { router.closeDrawer() }
        assertFalse(defaultDrawerShown())

        onUi { router.openDrawer() }
        assertTrue(defaultDrawerShown())
        tapScrim()
        assertFalse(router.isDrawerOpen)
        assertFalse(defaultDrawerShown())

        compose.onNodeWithText("Open drawer").performClick()
        assertTrue(defaultDrawerShown())
        assertTrue(router.isDrawerOpen)
        // Across a row, towards the leading edge: far enough to take the sheet with it.
        compose.onNodeWithTag(drawerItemTag("product")).performTouchInput { swipeLeft() }
        compose.waitForIdle()
        assertFalse(router.isDrawerOpen)
        assertEquals(emptyList(), router.stack)
        assertFalse(defaultDrawerShown())

        // Closed by the user, it opens again.
        compose.onNodeWithTag(DRAWER_MENU_TAG).performClick()
        assertTrue(defaultDrawerShown())
        assertEquals(listOf("home"), pages.pages)
    }

    /**
     * B10.5-K: the router closes the drawer while the user drags its sheet,
     * and the user lets go on the open side: the sheet still ends closed, as
     * the router says, and the back gesture has no drawer left to close.
     */
    @Test
    fun b10_5_aRouterCloseDuringADragThatIsReleasedOnTheOpenSideStillClosesTheSheet() {
        val pages = ShellPages()
        val router = show(pages, tabConfig(drawerItems = drawerItems))
        compose.onNodeWithTag(DRAWER_MENU_TAG).performClick()
        assertTrue(defaultDrawerShown())

        // Slowly, and not half of the sheet: let go here and it settles open.
        val row = compose.onNodeWithTag(drawerItemTag("product"))
        row.performTouchInput {
            down(center)
            repeat(3) { moveBy(Offset(-40f, 0f), delayMillis = 200) }
        }
        compose.runOnUiThread { router.closeDrawer() }
        row.performTouchInput {
            moveBy(Offset(-10f, 0f), delayMillis = 200)
            up()
        }
        compose.waitForIdle()

        assertFalse(router.isDrawerOpen)
        assertFalse(defaultDrawerShown())
        assertFalse(backIsHandled())
        assertEquals(emptyList(), router.stack)

        // In step again: it opens and closes as before.
        compose.onNodeWithTag(DRAWER_MENU_TAG).performClick()
        assertTrue(defaultDrawerShown())
        onUi { router.closeDrawer() }
        assertFalse(defaultDrawerShown())
    }

    /** B10.5-K: a tap on a drawer item closes the drawer, then pushes the item's route: over the shell, with its title bar. */
    @Test
    fun b10_5_aDrawerItemClosesTheDrawerAndPushesItsRoute() {
        val pages = ShellPages()
        val router = show(pages, tabConfig(drawerItems = drawerItems))

        compose.onNodeWithTag(DRAWER_MENU_TAG).performClick()
        assertTrue(defaultDrawerShown())
        compose.onNodeWithTag(drawerItemTag("settings")).performClick()
        awaitShown("settings page")
        assertFalse(router.isDrawerOpen)
        assertFalse(defaultDrawerShown())
        compose.onNodeWithTag(TITLE_TAG).assertTextEquals("Title of settings")
        assertEquals(listOf("/settings"), router.overRoutes.map { it.location })
        for (index in 0..2) assertEquals(0, tagCount(tabTag(index)))

        // Back is a pop: the tab page again, the drawer closed.
        compose.onNodeWithContentDescription("Back").performClick()
        awaitShown("home page")
        assertFalse(defaultDrawerShown())

        // An item of a route inside the tab pushes it on the tab's stack.
        compose.onNodeWithTag(DRAWER_MENU_TAG).performClick()
        compose.onNodeWithTag(drawerItemTag("product")).performClick()
        awaitShown("home/product/3 page")
        assertFalse(router.isDrawerOpen)
        assertEquals(listOf("/home/product/3"), router.stack.map { it.location })
        assertEquals(listOf("home", "settings", "home/product/3"), pages.pages)
    }

    /**
     * B10.5-K: the server's `drawerComponents` are drawn in place of the
     * default drawer, and the tree's `SwitchTab` row switches the tab, which
     * closes the drawer.
     */
    @Test
    fun b10_5_theServerDrawerReplacesTheDefaultOneAndItsSwitchTabClosesIt() {
        val drawer = listOf(
            ComponentNode("drawer", "Drawer", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, emptyMap(), listOf("rows")),
            column("rows", "head", "to-more"),
            text("head", "Server menu"),
            button("to-more", "TextButton", "to-more-label", mapOf("onTap" to Action.SwitchTab("more"))),
            text("to-more-label", "To more"),
        )
        val pages = ShellPages()
        val router = show(pages, tabConfig(drawerItems = drawerItems, drawerComponents = drawer))
        fun serverDrawerShown(): Boolean {
            compose.waitForIdle()
            return runCatching { compose.onNodeWithText("Server menu").assertIsDisplayed() }.isSuccess
        }

        compose.onNodeWithTag(SHELL_TITLE_TAG).assertTextEquals("Home")
        assertFalse(serverDrawerShown())
        compose.onNodeWithTag(DRAWER_MENU_TAG).performClick()
        assertTrue(serverDrawerShown())
        assertEquals(0, compose.onAllNodes(hasText("Menu")).fetchSemanticsNodes().size)
        for (item in drawerItems) assertEquals(0, tagCount(drawerItemTag(item.id)))

        compose.onNodeWithText("To more").performClick()
        awaitShown("more page")
        assertEquals(2, router.currentTab)
        assertFalse(router.isDrawerOpen)
        assertFalse(serverDrawerShown())
        compose.onNodeWithTag(SHELL_TITLE_TAG).assertTextEquals("More")
        assertEquals(listOf("home", "more"), pages.pages)
    }

    /** B10.5-K: a config without `drawerItems` and `drawerComponents` has no drawer, no top bar and no menu button. */
    @Test
    fun b10_5_noDrawerAndNoTopBarWhenTheConfigHasNone() {
        val pages = ShellPages()
        val router = show(pages)

        assertEquals(0, tagCount(SHELL_TITLE_TAG))
        assertEquals(0, tagCount(DRAWER_MENU_TAG))
        compose.onNodeWithText("Open drawer").performClick()
        onUi { router.openDrawer() }
        assertFalse(router.isDrawerOpen)
        assertEquals(0, compose.onAllNodes(hasText("Menu")).fetchSemanticsNodes().size)
        compose.onNodeWithText("home page").assertIsDisplayed()
    }

    /**
     * B10.8-K: a round of tab switches with the drawer opened and closed on
     * every tab asks the server for nothing, and leaves every page as it
     * was: the same loader, the same page model, the typed text, the scroll
     * offset.
     */
    @Test
    fun b10_8_tabSwitchesAndDrawerCyclesRequestNothingAndKeepEveryPage() {
        val pages = ShellPages()
        val router = show(pages, tabConfig(drawerItems = drawerItems))
        fun typed(): String = compose.onNode(hasSetTextAction()).fetchSemanticsNode().config[SemanticsProperties.EditableText].text
        // The drawer's rows scroll too.
        val list = hasScrollAction() and hasAnyDescendant(hasText("more page"))
        fun offset(): Float = compose.onNode(list).fetchSemanticsNode().config[SemanticsProperties.VerticalScrollAxisRange].value()

        tapTab(1)
        awaitShown("search page")
        compose.onNode(hasSetTextAction()).performTextInput("pizza")
        tapTab(2)
        awaitShown("more page")
        compose.onNode(list).performTouchInput { swipeUp() }
        compose.waitForIdle()
        val scrolled = offset()
        assertTrue(scrolled > 0f, "the list did not scroll")
        tapTab(0)
        awaitShown("home page")

        val routes = router.tabStacks.flatten()
        assertEquals(listOf("/home", "/search", "/more"), routes.map { it.location })
        val loaders = routes.map { router.loader(it) }
        val models = loaders.map { (it.phase as OrcaPageLoader.Phase.Loaded).model }
        val requests = pages.requests.size
        assertEquals(listOf("home", "search", "more"), pages.pages)

        repeat(2) { round ->
            for (tab in listOf(1, 2, 0)) {
                tapTab(tab)
                awaitShown("${listOf("home", "search", "more")[tab]} page")
                compose.onNodeWithTag(DRAWER_MENU_TAG).performClick()
                assertTrue(defaultDrawerShown())
                if (round == 0) tapScrim() else onUi { router.closeDrawer() }
                assertFalse(defaultDrawerShown())
            }
        }

        assertEquals(requests, pages.requests.size)
        assertEquals(listOf("home", "search", "more"), pages.pages)
        assertEquals(routes, router.tabStacks.flatten())
        routes.forEachIndexed { i, route ->
            assertSame(loaders[i], router.loader(route))
            assertSame(models[i], (router.loader(route).phase as OrcaPageLoader.Phase.Loaded).model)
        }
        assertEquals("pizza", typed())
        assertEquals(scrolled, offset())
    }

    // MARK: Route transitions inside the shell (B12.6-K, B12.7-K)

    /** The shell of [movingConfig] on its home page, the clock then in the test's hands. */
    private fun showMoving(pages: ShellPages, reduceMotion: Boolean = false): OrcaRouter {
        val router = OrcaRouter(pages.client, movingConfig)
        compose.setContent { CompositionLocalProvider(LocalOrcaReduceMotion provides reduceMotion) { OrcaApp(router) } }
        awaitShown("home page")
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        return router
    }

    /** The page that is moving, as the shell draws it this frame; null when no transition runs. */
    private fun motion(): PageMotion? {
        val moving = compose.onAllNodes(SemanticsMatcher.keyIsDefined(PageMotionKey)).fetchSemanticsNodes()
        assertTrue(moving.size <= 1, "one page moves at a time")
        return moving.singleOrNull()?.config?.get(PageMotionKey)
    }

    private fun OrcaRouter.go(path: String) = onUi { navigate(path) }

    /** Where [text] is drawn, in pixels from the top of the screen. */
    private fun top(text: String): Float = compose.onNode(hasText(text)).fetchSemanticsNode().positionInRoot.y

    private val still = PageMotion.Identity

    /** A fade route pushed inside a tab fades in over the previous top, which stays placed until the run ends. */
    @Test
    fun b12_6_k_aFadePushInsideATabFadesInOverThePreviousTop() {
        val router = showMoving(ShellPages())

        router.go("/home/fade")
        compose.mainClock.advanceTimeBy(500)
        val mid = assertNotNull(motion(), "a run is live at half time")
        assertEquals(0.5, mid.opacity, 0.1)
        assertEquals(still, mid.copy(opacity = 1.0), "a fade only fades")
        assertTrue(shown("home page"), "the previous top is still placed mid-run")
        assertTrue(shown("home/fade page"))

        compose.mainClock.advanceTimeBy(1_000)
        assertNull(motion(), "the run is over")
        assertTrue(shown("home/fade page"))
        assertFalse(shown("home page"), "the new page is alone at the end")
    }

    /** A slideUp route rises from the bottom of the page area: the offset is drawn, not only computed. */
    @Test
    fun b12_6_k_aSlideUpPushInsideATabRisesFromTheBottom() {
        val router = showMoving(ShellPages())
        val home = top("home page")

        router.go("/home/up")
        compose.mainClock.advanceTimeBy(500)
        val mid = assertNotNull(motion())
        assertEquals(0.5, mid.offsetYFraction, 0.1)
        assertEquals(still, mid.copy(offsetYFraction = 0.0))
        assertEquals(home, top("home page"), "the page under stands still")
        val drawn = top("home/up page") - home
        assertTrue(drawn > 300f, "the entering page is drawn lower mid-run, by $drawn px")

        compose.mainClock.advanceTimeBy(1_000)
        assertNull(motion())
        assertEquals(home, top("home/up page"))
        assertFalse(shown("home page"))
    }

    /** A pop plays the popped route's transition backwards over the page under it, and asks the server for nothing. */
    @Test
    fun b12_6_k_aPopInsideATabPlaysTheTransitionBackwards() {
        val pages = ShellPages()
        val router = showMoving(pages)
        router.go("/home/up")
        compose.mainClock.advanceTimeBy(1_500)
        assertNull(motion())
        assertEquals(listOf("home", "home/up"), pages.pages)

        onUi { router.goBack() }
        compose.mainClock.advanceTimeBy(250)
        assertEquals(0.25, assertNotNull(motion()).offsetYFraction, 0.1)
        assertTrue(shown("home page"), "the page under is there at once")
        assertTrue(shown("home/up page"), "the popped page is still drawn while it leaves")
        compose.mainClock.advanceTimeBy(500)
        assertEquals(0.75, assertNotNull(motion()).offsetYFraction, 0.1)

        compose.mainClock.advanceTimeBy(500)
        assertNull(motion())
        assertEquals(0, compose.onAllNodes(hasText("home/up page")).fetchSemanticsNodes().size, "the popped page left")
        assertTrue(shown("home page"))
        assertEquals(listOf("home", "home/up"), pages.pages, "the leaving page is not requested again")
    }

    /** A scale route grows about the centre of the page area, and a pop shrinks it back: the scale is drawn. */
    @Test
    fun b12_6_k_aScalePushInsideATabGrowsFromItsCentreAndAPopShrinksItBack() {
        val router = showMoving(ShellPages())
        fun width(): Float = compose.onNode(hasText("home/scale page")).fetchSemanticsNode().boundsInRoot.width

        router.go("/home/scale")
        compose.mainClock.advanceTimeBy(500)
        val mid = assertNotNull(motion(), "a run is live at half time")
        assertEquals(0.5, mid.scale, 0.1)
        assertEquals(still, mid.copy(scale = 1.0), "a scale only scales")
        assertTrue(shown("home page"), "the previous top is still placed mid-run")
        val midWidth = width()

        compose.mainClock.advanceTimeBy(1_000)
        assertNull(motion())
        assertFalse(shown("home page"))
        val full = width()
        assertEquals(0.5f, midWidth / full, 0.1f, "the entering page is drawn at half its size mid-run")

        onUi { router.goBack() }
        compose.mainClock.advanceTimeBy(250)
        assertEquals(0.75, assertNotNull(motion()).scale, 0.1)
        assertEquals(0.75f, width() / full, 0.1f)
        assertTrue(shown("home page"))
        compose.mainClock.advanceTimeBy(1_000)
        assertNull(motion())
        assertEquals(0, compose.onAllNodes(hasText("home/scale page")).fetchSemanticsNodes().size)
    }

    /** A type the SDK does not know is `slide` (Dart's `'slide' || _`): the page comes in from the left. */
    @Test
    fun b12_6_k_anUnknownTypeInsideATabSlidesInFromTheLeft() {
        val router = showMoving(ShellPages())

        router.go("/home/odd")
        compose.mainClock.advanceTimeBy(500)
        val mid = assertNotNull(motion())
        assertEquals(-0.5, mid.offsetXFraction, 0.1)
        assertEquals(still, mid.copy(offsetXFraction = 0.0))
        val left = compose.onNode(hasText("home/odd page")).fetchSemanticsNode().positionInRoot.x

        compose.mainClock.advanceTimeBy(1_000)
        assertNull(motion())
        val rest = compose.onNode(hasText("home/odd page")).fetchSemanticsNode().positionInRoot.x
        assertTrue(rest - left > 100f, "the entering page is drawn to the left mid-run, by ${rest - left} px")
    }

    /**
     * A pop while the push is still running goes back from where the page
     * is (Flutter's controller reversed), in the time the push had run: no
     * jump to the page in place, no whole run backwards.
     */
    @Test
    fun b12_6_k_aPopDuringAPushInsideATabGoesBackFromWhereThePageIs() {
        val pages = ShellPages()
        val router = showMoving(pages)

        router.go("/home/fade")
        compose.mainClock.advanceTimeBy(300)
        val pushed = assertNotNull(motion()).opacity
        assertEquals(0.3, pushed, 0.05)

        onUi { router.goBack() }
        compose.mainClock.advanceTimeByFrame()
        assertEquals(pushed, assertNotNull(motion(), "the page leaves from where it is").opacity, 0.05, "no jump at the pop")
        assertTrue(shown("home page"))

        compose.mainClock.advanceTimeBy(150)
        assertEquals(pushed - 0.15, assertNotNull(motion()).opacity, 0.05)

        // 300 ms of push are 300 ms of pop, not the route's 1000.
        compose.mainClock.advanceTimeBy(200)
        assertNull(motion(), "the run back is over after the time the push had run")
        assertEquals(0, compose.onAllNodes(hasText("home/fade page")).fetchSemanticsNodes().size, "the popped page left")
        assertTrue(shown("home page"))

        // The same for a slide, and a push after it plays whole again.
        router.go("/home/up")
        compose.mainClock.advanceTimeBy(300)
        val risen = assertNotNull(motion()).offsetYFraction
        assertEquals(0.7, risen, 0.05)
        onUi { router.goBack() }
        compose.mainClock.advanceTimeByFrame()
        assertEquals(risen, assertNotNull(motion()).offsetYFraction, 0.05, "no jump at the pop")
        compose.mainClock.advanceTimeBy(350)
        assertNull(motion())
        router.go("/home/up")
        compose.mainClock.advanceTimeBy(500)
        assertEquals(0.5, assertNotNull(motion()).offsetYFraction, 0.1)
    }

    /** `none` and no transition: the shell swaps the pages at once, as before. */
    @Test
    fun b12_6_k_noneAndAbsentSwapAtOnceInsideATab() {
        val router = showMoving(ShellPages())
        for (path in listOf("none", "plain")) {
            router.go("/home/$path")
            compose.mainClock.advanceTimeBy(100)
            assertNull(motion(), path)
            assertFalse(shown("home page"), path)
            assertTrue(shown("home/$path page"), path)

            onUi { router.goBack() }
            compose.mainClock.advanceTimeBy(100)
            assertNull(motion(), path)
            assertTrue(shown("home page"), path)
        }
    }

    /** Reduced motion: the pushed page is in place at once and the popped one gone at once. */
    @Test
    fun b12_6_k_reducedMotionLandsAtOnceInsideATab() {
        val router = showMoving(ShellPages(), reduceMotion = true)

        router.go("/home/fade")
        compose.mainClock.advanceTimeBy(100)
        assertNull(motion())
        assertFalse(shown("home page"))
        assertTrue(shown("home/fade page"))

        onUi { router.goBack() }
        compose.mainClock.advanceTimeBy(100)
        assertNull(motion())
        assertTrue(shown("home page"))
        assertEquals(0, compose.onAllNodes(hasText("home/fade page")).fetchSemanticsNodes().size)
    }

    /** A change of tab is not a push: nothing moves, also into a tab whose root route has a transition. */
    @Test
    fun b12_7_k_aTabSwitchPlaysNoTransitionAndARouteOverTheShellPlaysIts() {
        val router = showMoving(ShellPages())

        onUi { router.selectTab(1) }
        compose.mainClock.advanceTimeBy(100)
        assertNull(motion(), "the first visit of a tab")
        assertTrue(shown("search page"))
        assertFalse(shown("home page"))
        onUi { router.selectTab(0) }
        compose.mainClock.advanceTimeBy(100)
        assertNull(motion(), "back to a visited tab")
        assertTrue(shown("home page"))

        // `settings` is outside the tabs: it covers the shell, with its own transition.
        router.go("/settings")
        compose.mainClock.advanceTimeBy(500)
        assertEquals(0.5, assertNotNull(motion()).opacity, 0.1)
        assertTrue(shown("home page"))
        compose.mainClock.advanceTimeBy(1_000)
        assertNull(motion())
        assertTrue(shown("settings page"))
        assertFalse(shown("home page"))
    }

    /**
     * A3.6-K (never twice): the tab bar already pads for the bottom system
     * bar, so a SafeArea that is a tab page's root adds nothing at the
     * bottom: its box ends where the bar begins, as under Flutter's
     * Scaffold, whose body loses the bottom padding to its
     * bottomNavigationBar. The top inset, which nothing above took, is
     * padded once. A route over the shell has no bar: its SafeArea pads for
     * the bottom inset itself.
     */
    @Test
    fun a3_6_aSafeAreaInATabPageDoesNotPadTheBottomInsetTheTabBarTook() {
        val router = OrcaRouter(SafeAreaPages().client, tabConfig())
        // SafeArea is advertised in group 5: the app gets it as a host widget. Both tagged with their ids.
        val widgets = WidgetBuilders.standard().apply {
            register("SafeArea") { node, model, modifier -> SafeAreaWidget(node, model, modifier.testTag(node.id)) }
            register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
        }
        lateinit var host: View
        compose.setContent {
            host = LocalView.current
            OrcaApp(router, widgets = widgets)
        }
        compose.waitUntil(5_000) { placed("box-home") }
        // In pixels, 2 per dp at xhdpi: 24 dp at the top, 48 dp at the bottom.
        systemBars(host, top = 48, bottom = 96)
        val screen = compose.onRoot().getUnclippedBoundsInRoot()

        val box = bounds("box-home")
        assertEquals(24.dp, box.top)
        assertEquals(bounds(tabTag(0)).top, box.bottom)

        compose.runOnUiThread { router.navigate("/settings") }
        compose.waitUntil(5_000) { placed("box-settings") }
        assertEquals(screen.bottom - 48.dp, bounds("box-settings").bottom)
    }

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    /** The node tagged [tag] is composed and placed. */
    private fun placed(tag: String): Boolean =
        compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().any { it.layoutInfo.isPlaced }

    /** The device's system bars, in pixels, delivered to [host] as the platform does (FlowTest's harness). */
    private fun systemBars(host: View, top: Int, bottom: Int) {
        val insets = WindowInsetsCompat.Builder()
            .setInsets(WindowInsetsCompat.Type.systemBars(), Insets.of(0, top, 0, bottom))
            .build()
        compose.runOnIdle { ViewCompat.dispatchApplyWindowInsets(host, insets) }
        compose.waitForIdle()
    }
}

/** One second, linear: half time is half way. */
private fun moving(type: String, duration: Int = 1_000) = RouteTransitionDef(type, duration, "linear")

/**
 * The tabs of [tabConfig] with a route per transition under `home`
 * (`home/fade`, `home/up`, `home/scale`, `home/odd` with a type no SDK
 * knows, `home/none` with the type `none`, `home/plain` with none), a fade on the root of the `search` tab and on `settings`.
 */
private val movingConfig = NavConfig(
    initialRoute = "/home",
    tabs = listOf(
        TabDef("home", "Home", "home", "/home"),
        TabDef("search", "Search", "search", "/search"),
        TabDef("more", "More", "menu", "/more"),
    ),
    flows = listOf(
        NavFlow(
            name = "main",
            routes = listOf(
                NavRoute(
                    "home",
                    children = listOf(
                        NavRoute("home/fade", transition = moving("fade")),
                        NavRoute("home/up", transition = moving("slideUp")),
                        NavRoute("home/scale", transition = moving("scale")),
                        NavRoute("home/odd", transition = moving("zoomAndSpin")),
                        NavRoute("home/none", transition = moving("none", duration = 5_000)),
                        NavRoute("home/plain"),
                    ),
                ),
                NavRoute("search", transition = moving("fade")),
                NavRoute("more"),
                NavRoute("settings", transition = moving("fade")),
            ),
        ),
    ),
)

/** The tag of the top bar's title, as OrcaApp sets it. */
private const val TITLE_TAG = "orca-route-title"

/** What TalkBack reads on the scrim of an open Material 3 drawer. */
private const val CLOSE_DRAWER = "Close navigation menu"
