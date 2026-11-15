package com.orcagateway.sdk.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.RoutePage
import com.orcagateway.sdk.style.IconNames
import java.util.UUID

/**
 * A router with tabs on screen (Flutter's `OrcaShell`; Swift's
 * `TabShellView`): a Material 3 `Scaffold` whose bottom bar is one
 * `NavigationBarItem` per tab (the tab's Material icon and its label), or
 * the config's `tabBarComponents` when it has any ([ShellTree]). A tap on a
 * tab is [OrcaRouter.selectTab]: the tab comes back as it was left, and a
 * tap on the selected one pops it to its root.
 *
 * The content is the page on top of the current tab's stack. Every page
 * that was shown stays composed while its route is on a stack, placed only
 * while it is the one on top: a typed text, a scroll offset and anything
 * else a widget remembers are there again when the user comes back, as
 * under Flutter's `IndexedStack`. A tab not visited yet has no route, so it
 * composes and requests nothing, and a page under the one on top that was
 * never shown is requested when it is first shown.
 *
 * A route over the shell ([OrcaRouter.overRoutes]) takes the whole screen:
 * the bar is gone while one is on top, and the route has its title bar.
 *
 * The system back gesture pops the router while it has a page to pop
 * ([OrcaRouter.canGoBack]). At a tab's root nothing handles it, so the
 * system leaves the app; there is no hop to the first tab.
 */
@Composable
internal fun TabShellScreen(router: OrcaRouter, modifier: Modifier = Modifier) {
    val covered = router.overRoutes.isNotEmpty()
    val serverBar = router.table?.config?.tabBarComponents.orEmpty()
    Scaffold(
        modifier = modifier,
        bottomBar = {
            when {
                covered -> Unit
                serverBar.isEmpty() -> TabBar(router)
                else -> ShellTreeView(router, serverBar)
            }
        },
        // A page handles the system bars itself, as on the single stack.
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) { KeptPages(router) }
    }
    BackHandler(enabled = router.canGoBack) { router.goBack() }
}

/** The default bar: icon and label per tab, the current one selected; item i carries the test tag `orca-tab-i`. */
@Composable
private fun TabBar(router: OrcaRouter) {
    val current = router.currentTab
    NavigationBar {
        router.tabs.forEachIndexed { index, tab ->
            NavigationBarItem(
                selected = index == current,
                // Also for the selected one: a reselect pops the tab to its root.
                onClick = { router.selectTab(index) },
                icon = { Icon(IconNames.vector(tab.icon), contentDescription = null) },
                modifier = Modifier.testTag(tabTag(index)),
                label = { Text(tab.label) },
            )
        }
    }
}

/**
 * The page of every route on a tab's stack or over the shell that was on
 * top at least once, each under its route's id, and only the one on top
 * placed. A route that left the stacks leaves the composition.
 */
@Composable
private fun KeptPages(router: OrcaRouter) {
    val top = router.top
    val routes = router.tabStacks.flatten() + router.overRoutes
    // Not Compose state: it changes only with the router's stacks, which are.
    val shown = remember(router) { HashSet<UUID>() }
    shown.retainAll(routes.mapTo(HashSet()) { it.id })
    shown.add(top.id)

    // A field of a page that is no longer on top must not keep the keyboard.
    val focus = LocalFocusManager.current
    LaunchedEffect(top.id) { focus.clearFocus() }

    for (route in routes) {
        if (route.id !in shown) continue
        key(route.id) {
            val onTop = route === top
            val kept = Modifier.fillMaxSize().layout { measurable, constraints ->
                val placeable = measurable.measure(constraints)
                layout(placeable.width, placeable.height) { if (onTop) placeable.place(0, 0) }
            }
            // A not-found route has no loader: nothing is requested for it.
            Box(kept) { RoutePage(router, route, if (route.isNotFound) null else router.loader(route)) }
        }
    }
}

/**
 * A server tree of the tab shell (`tabBarComponents`, `drawerComponents`)
 * as a page model: no page state, the router's app state, page id
 * `__shell__` (Flutter's `OrcaShell` renders them so). Unknown widgets
 * degrade as on a page.
 *
 * Building one only reads the router: the model starts on the app state of
 * that moment, so a node bound to `_tabIndex` is right on the first frame.
 * [open] joins the router like a page, so its actions (`switchTab`,
 * `navigate`, a `setState` of app scope) reach it, and it takes every write
 * of app state, so that node redraws on a tab change. [close] it when the
 * tree leaves the screen.
 */
internal class ShellTree(private val router: OrcaRouter, nodes: List<ComponentNode>) : AutoCloseable {
    val model: OrcaPageModel = OrcaPageModel(
        PageResponse(pageId = SHELL_PAGE_ID, title = "", components = nodes),
        store = ElmStore(StoreState(app = router.appState)),
        client = router.client,
    )

    private var following: AutoCloseable? = null

    /** Join the router, on the app state it has now, and follow every write of it. Once. */
    fun open() {
        if (following != null) return
        router.attach(model)
        following = router.onAppStateChange { app ->
            val state = model.store.state
            if (state.app != app) model.store.commit(state.copy(app = app))
        }
    }

    /** Stop following app state, and cancel the tree's running actions. */
    override fun close() {
        following?.close()
        following = null
        model.close()
    }
}

/** A shell tree drawn from its root, with a page's default text style. Nothing for an empty tree. */
@Composable
internal fun ShellTreeView(router: OrcaRouter, nodes: List<ComponentNode>, modifier: Modifier = Modifier) {
    val tree = remember(router, nodes) { ShellTree(router, nodes) }
    // Not in `remember`: a composition that is abandoned must leave nothing on the router.
    DisposableEffect(tree) {
        tree.open()
        onDispose { tree.close() }
    }
    val revision = tree.model.structureRevision
    val root = remember(tree, revision) { tree.model.renderer.rootId } ?: return
    ProvideTextStyle(MaterialTheme.typography.bodyMedium) { NodeView(root, tree.model, modifier) }
}

/** The test tag of tab [index] in the default bar. */
internal fun tabTag(index: Int): String = "orca-tab-$index"

/** The page id of the shell's server trees (Flutter's `OrcaShell`). */
internal const val SHELL_PAGE_ID: String = "__shell__"
