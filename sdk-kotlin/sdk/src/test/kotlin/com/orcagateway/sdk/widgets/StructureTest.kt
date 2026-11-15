package com.orcagateway.sdk.widgets

import androidx.activity.ComponentActivity
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getBoundsInRoot
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.compose.ui.unit.dp
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.URI
import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** A structure node: its slots are props that hold the id of a node listed in `children`. */
private fun structure(
    id: String,
    type: String,
    slots: Map<String, String>,
    props: Map<String, JsonValue> = emptyMap(),
    actions: Map<String, Action>? = null,
): ComponentNode = ComponentNode(
    id, type, ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
    props + slots.mapValues { JsonValue.String(it.value) }, slots.values.toList(),
    actions = actions,
)

private fun state(key: String, scope: String = "page"): JsonValue = JsonValue.obj("type" to "state", "key" to key, "scope" to scope)

/** `onChange` of the bar: the tapped index, from the event, into page state `lastTab`. */
private val keepLastTab: Action =
    Action.SetState(key = "lastTab", value = JsonValue.obj("type" to "event", "key" to "value"))

/**
 * The page of render fixture `60_bottom_navigation_bar.json`: a Scaffold
 * with the body "Feed" and a BottomNavigationBar in its
 * `bottomNavigationBar` slot, the BottomNavItems named by [slots].
 */
private fun barPage(
    currentIndex: JsonValue? = state("tab"),
    slots: List<Int> = listOf(0, 1, 2),
): List<ComponentNode> {
    val items = listOf(
        leaf("nav_home", "BottomNavItem", mapOf("icon" to JsonValue.String("home"), "activeIcon" to JsonValue.String("home_filled"), "label" to JsonValue.String("Home"))),
        leaf("nav_search", "BottomNavItem", mapOf("icon" to JsonValue.String("search"), "label" to JsonValue.String("Search"))),
        leaf("nav_profile", "BottomNavItem", mapOf("icon" to JsonValue.String("person"), "label" to JsonValue.String("Profile"))),
    )
    val props = LinkedHashMap<String, JsonValue>()
    props["backgroundColor"] = JsonValue.String("#FFFFFF")
    props["selectedItemColor"] = JsonValue.String("#6200EE")
    props["unselectedItemColor"] = JsonValue.String("#9E9E9E")
    currentIndex?.let { props["currentIndex"] = it }
    val nav = structure("nav", "BottomNavigationBar", slots.associate { "item_$it" to items[it].id }, props, mapOf("onChange" to keepLastTab))
        .copy(watches = listOf("tab"))
    return listOf(
        structure("page", "Scaffold", mapOf("body" to "body", "bottomNavigationBar" to "nav")),
        nav,
        text("body", "Feed"),
    ) + slots.map { items[it] }
}

/**
 * The page of render fixture `61_scaffold_drawers.json`: a Scaffold with an
 * AppBar titled "Inbox", the body "Messages", a `drawer` (Inbox, Sent) and
 * an `endDrawer` (Filters). [bar] replaces the AppBar and its slot nodes.
 */
private fun drawerPage(
    bar: List<ComponentNode> = listOf(structure("bar", "AppBar", mapOf("title" to "title")), text("title", "Inbox")),
): List<ComponentNode> = listOf(
    structure("page", "Scaffold", mapOf("appBar" to "bar", "body" to "body", "drawer" to "drawer", "endDrawer" to "end_drawer")),
    ComponentNode(
        "drawer", "Drawer", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        mapOf("backgroundColor" to JsonValue.String("#FAFAFA"), "elevation" to JsonValue.Int(16), "width" to JsonValue.Int(280)),
        listOf("menu"),
    ),
    column("menu", "menu_inbox", "menu_sent"),
    text("menu_inbox", "Inbox"),
    text("menu_sent", "Sent"),
    ComponentNode(
        "end_drawer", "Drawer", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
        mapOf("backgroundColor" to JsonValue.String("#263238"), "elevation" to JsonValue.Int(4), "width" to JsonValue.Int(320)),
        listOf("filters_title"),
    ),
    text("filters_title", "Filters"),
    text("body", "Messages"),
) + bar

/** A server whose every page is [nodes]. */
private class OnePage(private val nodes: List<ComponentNode>) : HttpTransport {
    val requests = mutableListOf<HttpRequest>()

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests += request
        val page = PageResponse(pageId = "home", title = "Home", state = emptyList(), components = nodes)
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    val client: OrcaClient
        get() = OrcaClient(URI("http://stub.invalid"), appId = "fixture-app", device = DeviceInfo(osVersion = "test"), transport = this)
}

/**
 * The page structure widgets on screen: a BottomNavigationBar in a
 * Scaffold's `bottomNavigationBar` slot (B10.6-K), and a page Scaffold's
 * `drawer` and `endDrawer` (B10.5-K).
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class StructureTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    /** The page on screen; page state `tab` and `lastTab`, app state [app]. */
    private fun show(
        nodes: List<ComponentNode>,
        tab: Int = 1,
        app: Map<String, JsonValue> = emptyMap(),
    ): OrcaPageModel {
        val state = listOf(
            StateDefinition("tab", StateScope.Page, JsonValue.Int(tab.toLong())),
            StateDefinition("lastTab", StateScope.Page, JsonValue.Int(0)),
        )
        val model = OrcaPageModel(page(*nodes.toTypedArray(), state = state), store = ElmStore(StoreState(app = app)))
        compose.setContent { OrcaPageView(model) }
        compose.waitForIdle()
        return model
    }

    private fun tagCount(tag: String): Int = compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().size

    /** A node with [text] is composed and inside the screen: a closed drawer's sheet is composed beside it. */
    private fun onScreen(text: String): Boolean {
        compose.waitForIdle()
        return runCatching { compose.onNodeWithText(text).assertIsDisplayed() }.isSuccess
    }

    private fun selected(): List<Boolean> = (0 until 3).filter { tagCount(bottomNavItemTag(it)) == 1 }.map {
        runCatching { compose.onNodeWithTag(bottomNavItemTag(it)).assertIsSelected() }.isSuccess
    }

    /** Every (tab, lastTab) of page state, one per commit that changed either. */
    private fun commits(model: OrcaPageModel): List<Pair<JsonValue?, JsonValue?>> {
        val log = ArrayList<Pair<JsonValue?, JsonValue?>>()
        model.store.subscribe(listOf("tab", "lastTab")) { log.add(it.page["tab"] to it.page["lastTab"]) }
        return log
    }

    private fun int(value: Int): JsonValue = JsonValue.Int(value.toLong())

    /** B10.6-K: the bar in the Scaffold slot draws its items, and the one page state names is selected. */
    @Test
    fun b10_6_theBarShowsItsItemsAndTheSelectedIndexFromPageState() {
        val model = show(barPage())

        for (index in 0..2) compose.onNodeWithTag(bottomNavItemTag(index)).assertIsDisplayed()
        for (label in listOf("Home", "Search", "Profile")) compose.onNodeWithText(label).assertIsDisplayed()
        compose.onNodeWithText("Feed").assertIsDisplayed()
        compose.onNodeWithTag(bottomNavItemTag(1)).assertIsSelected()
        compose.onNodeWithTag(bottomNavItemTag(0)).assertIsNotSelected()
        compose.onNodeWithTag(bottomNavItemTag(2)).assertIsNotSelected()

        // The bar follows the key it watches.
        compose.runOnUiThread { model.store.dispatch(mapOf("tab" to int(0))) }
        compose.waitForIdle()
        assertEquals(listOf(true, false, false), selected())
    }

    /** B10.6-K: a tap writes the index into the bound page state key first, then fires `onChange` with `value` the index. */
    @Test
    fun b10_6_aTapWritesTheBoundPageStateKeyThenFiresOnChangeWithTheIndex() {
        val model = show(barPage())
        val commits = commits(model)

        compose.onNodeWithTag(bottomNavItemTag(2)).performClick()
        compose.waitForIdle()

        assertEquals(listOf<Pair<JsonValue?, JsonValue?>>(int(2) to int(0), int(2) to int(2)), commits)
        assertEquals(int(2), model.store.state.page["tab"])
        assertEquals(int(2), model.store.state.page["lastTab"])
        assertEquals(emptyMap(), model.store.state.app)
        assertEquals(listOf(false, false, true), selected())
    }

    /** B10.6-K: a `currentIndex` bound to app state is written into app state. */
    @Test
    fun b10_6_anAppScopeBindingWritesAppState() {
        val model = show(barPage(currentIndex = state("section", scope = "app")), app = mapOf("section" to int(1)))
        assertEquals(listOf(false, true, false), selected())

        compose.onNodeWithTag(bottomNavItemTag(2)).performClick()
        compose.waitForIdle()

        assertEquals(int(2), model.store.state.app["section"])
        assertNull(model.store.state.page["section"])
        assertEquals(int(1), model.store.state.page["tab"])
        assertEquals(int(2), model.store.state.page["lastTab"])
    }

    /** B10.6-K: a static `currentIndex` (and none at all) has no key to write: the tap only fires `onChange`. */
    @Test
    fun b10_6_aStaticCurrentIndexWritesNothingAndStillFiresOnChange() {
        val model = show(barPage(currentIndex = int(1)))
        val commits = commits(model)
        assertEquals(listOf(false, true, false), selected())

        compose.onNodeWithTag(bottomNavItemTag(2)).performClick()
        compose.waitForIdle()

        assertEquals(listOf<Pair<JsonValue?, JsonValue?>>(int(1) to int(2)), commits)
        assertEquals(mapOf("tab" to int(1), "lastTab" to int(2)), model.store.state.page)
        assertEquals(listOf(false, true, false), selected())
    }

    /** B10.6-K: no `currentIndex` selects the first item. */
    @Test
    fun b10_6_noCurrentIndexSelectsTheFirstItem() {
        show(barPage(currentIndex = null))
        assertEquals(listOf(true, false, false), selected())
    }

    /** B10.6-K: a `currentIndex` past the items selects the last one, a negative one the first. */
    @Test
    fun b10_6_aCurrentIndexOutOfRangeIsClamped() {
        val model = show(barPage(), tab = 7)
        assertEquals(listOf(false, false, true), selected())

        compose.runOnUiThread { model.store.dispatch(mapOf("tab" to int(-3))) }
        compose.waitForIdle()
        assertEquals(listOf(true, false, false), selected())
    }

    /** B10.6-K: the items are `item_0`, `item_1`, ... up to the first slot that is missing. */
    @Test
    fun b10_6_theItemsStopAtTheFirstMissingSlot() {
        show(barPage(slots = listOf(0, 2)), tab = 0)

        compose.onNodeWithTag(bottomNavItemTag(0)).assertIsDisplayed()
        compose.onNodeWithText("Home").assertIsDisplayed()
        assertEquals(0, tagCount(bottomNavItemTag(1)))
        assertEquals(0, tagCount(bottomNavItemTag(2)))
        assertEquals(0, compose.onAllNodes(hasText("Profile")).fetchSemanticsNodes().size)
    }

    /** B10.6-K: a bar without items draws nothing; the rest of the Scaffold is there. */
    @Test
    fun b10_6_aBarWithoutItemsDrawsNothing() {
        show(barPage(slots = emptyList()))

        for (index in 0..2) assertEquals(0, tagCount(bottomNavItemTag(index)))
        compose.onNodeWithText("Feed").assertIsDisplayed()
    }

    /**
     * B10.5-K: a page Scaffold with a `drawer` and an `endDrawer` shows
     * neither until it is opened. The AppBar, with no `leading` and no
     * actions of its own, has a menu button for each; a tap on the scrim and
     * a swipe close them. The end drawer is on the trailing edge.
     */
    @Test
    fun b10_5_aPageScaffoldsDrawerAndEndDrawerOpenAndClose() {
        show(drawerPage())
        compose.onNodeWithText("Messages").assertIsDisplayed()
        assertFalse(onScreen("Sent"))
        assertFalse(onScreen("Filters"))

        compose.onNodeWithTag(SCAFFOLD_DRAWER_MENU_TAG).performClick()
        assertTrue(onScreen("Sent"))
        assertFalse(onScreen("Filters"))
        assertEquals(0.dp, compose.onNodeWithTag(scaffoldDrawerTag(end = false)).getBoundsInRoot().left)
        compose.onNodeWithContentDescription(CLOSE_DRAWER).performTouchInput { click(Offset(width - 4f, height / 2f)) }
        assertFalse(onScreen("Sent"))

        compose.onNodeWithTag(SCAFFOLD_END_DRAWER_MENU_TAG).performClick()
        assertTrue(onScreen("Filters"))
        assertFalse(onScreen("Sent"))
        assertEquals(393.dp, compose.onNodeWithTag(scaffoldDrawerTag(end = true)).getBoundsInRoot().right)
        compose.onNodeWithContentDescription(CLOSE_DRAWER).performTouchInput { click(Offset(4f, height / 2f)) }
        assertFalse(onScreen("Filters"))

        // A swipe towards its edge closes the leading one.
        compose.onNodeWithTag(SCAFFOLD_DRAWER_MENU_TAG).performClick()
        assertTrue(onScreen("Sent"))
        compose.onNodeWithTag(scaffoldDrawerTag(end = false)).performTouchInput { swipeLeft() }
        assertFalse(onScreen("Sent"))
        compose.onNodeWithText("Messages").assertIsDisplayed()
    }

    /** B10.5-K: the AppBar's menu buttons stand in only for what it leaves empty: none on a side that has a `leading` or an action. */
    @Test
    fun b10_5_theAppBarShowsAMenuButtonOnlyOnASideItLeavesEmpty() {
        val own = listOf(
            structure("bar", "AppBar", mapOf("title" to "title", "leading" to "lead", "action_0" to "act")),
            text("title", "Inbox"),
            text("lead", "Lead"),
            text("act", "Act"),
        )
        show(drawerPage(bar = own))
        compose.onNodeWithText("Lead").assertIsDisplayed()
        compose.onNodeWithText("Act").assertIsDisplayed()
        assertEquals(0, tagCount(SCAFFOLD_DRAWER_MENU_TAG))
        assertEquals(0, tagCount(SCAFFOLD_END_DRAWER_MENU_TAG))
    }

    /** B10.5-K: `automaticallyImplyLeading: false` keeps the leading side empty (Flutter's AppBar). */
    @Test
    fun b10_5_noLeadingMenuButtonWhenTheAppBarDeclinesIt() {
        val declined = listOf(
            structure("bar", "AppBar", mapOf("title" to "title"), mapOf("automaticallyImplyLeading" to JsonValue.Bool(false))),
            text("title", "Inbox"),
        )
        show(drawerPage(bar = declined))
        assertEquals(0, tagCount(SCAFFOLD_DRAWER_MENU_TAG))
        assertEquals(1, tagCount(SCAFFOLD_END_DRAWER_MENU_TAG))
    }

    /** B10.5-K: a Scaffold without drawers draws no drawer and no menu button. */
    @Test
    fun b10_5_aScaffoldWithoutDrawersHasNoMenuButtons() {
        show(
            listOf(
                structure("page", "Scaffold", mapOf("appBar" to "bar", "body" to "body")),
                structure("bar", "AppBar", mapOf("title" to "title")),
                text("title", "Inbox"),
                text("body", "Messages"),
            ),
        )
        compose.onNodeWithText("Messages").assertIsDisplayed()
        assertEquals(0, tagCount(SCAFFOLD_DRAWER_MENU_TAG))
        assertEquals(0, tagCount(SCAFFOLD_END_DRAWER_MENU_TAG))
        assertEquals(0, tagCount(scaffoldDrawerTag(end = false)))
        assertEquals(0, tagCount(scaffoldDrawerTag(end = true)))
    }

    /**
     * B10.5-K (brief D1): `openDrawer` on a page that is under no shell
     * drawer asks the page ([OrcaRouter.pageDrawerRequest]); the page's
     * Scaffold opens its leading drawer and clears the request. A request
     * for another route is left alone.
     */
    @Test
    fun b10_5_aPageDrawerRequestForItsRouteOpensTheLeadingDrawerAndIsCleared() {
        val open = listOf(button("open", "TextButton", "open_label", mapOf("onTap" to Action.OpenDrawer)), text("open_label", "Open"))
        val nodes = drawerPage().map { if (it.id == "body") column("body", "open") else it } + open
        val server = OnePage(nodes)
        val router = OrcaRouter(server.client, "home")
        compose.setContent { OrcaApp(router) }
        compose.waitUntil(5_000) { compose.onAllNodes(hasText("Open")).fetchSemanticsNodes().isNotEmpty() }
        assertFalse(onScreen("Sent"))

        val other = UUID.randomUUID()
        compose.runOnUiThread { router.pageDrawerRequest = other }
        assertFalse(onScreen("Sent"))
        assertEquals(other, router.pageDrawerRequest)

        compose.runOnUiThread { router.openDrawer() }
        assertTrue(onScreen("Sent"))
        assertFalse(onScreen("Filters"))
        assertNull(router.pageDrawerRequest)
        assertFalse(router.isDrawerOpen)

        compose.onNodeWithContentDescription(CLOSE_DRAWER).performTouchInput { click(Offset(width - 4f, height / 2f)) }
        assertFalse(onScreen("Sent"))

        // The page's own `openDrawer` action goes the same way.
        compose.onNodeWithText("Open").performClick()
        assertTrue(onScreen("Sent"))
        assertNull(router.pageDrawerRequest)
        assertEquals(1, server.requests.size)
    }
}

/** What TalkBack reads on the scrim of an open Material 3 drawer. */
private const val CLOSE_DRAWER = "Close navigation menu"
