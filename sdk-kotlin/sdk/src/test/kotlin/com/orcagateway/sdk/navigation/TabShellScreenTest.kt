package com.orcagateway.sdk.navigation

import androidx.activity.ComponentActivity
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.click
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
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.compose.ui.test.swipeUp
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
import com.orcagateway.core.models.TabDef
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageLoader
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
 * the shell drawer (B10.5-K), the system back gesture (B10.7-K), and pages
 * kept across tab switches and drawer cycles (B10.8-K).
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
}

/** The tag of the top bar's title, as OrcaApp sets it. */
private const val TITLE_TAG = "orca-route-title"

/** What TalkBack reads on the scrim of an open Material 3 drawer. */
private const val CLOSE_DRAWER = "Close navigation menu"
