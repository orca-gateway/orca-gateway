package com.orcagateway.sdk.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.DrawerItemDef
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.navigation.PageMotion
import com.orcagateway.core.navigation.TransitionSpec
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.RoutePage
import com.orcagateway.sdk.style.IconNames
import com.orcagateway.sdk.widgets.orcaReduceMotion
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch
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
 * A config with a drawer ([OrcaRouter.hasDrawer]) puts the shell inside a
 * [ShellDrawer], and every tab page, at any depth of its tab, under a top
 * bar: the current tab's label and a menu button that opens the drawer.
 *
 * The system back gesture closes an open drawer, else pops the router while
 * it has a page to pop ([OrcaRouter.canGoBack]). At a tab's root nothing
 * handles it, so the system leaves the app; there is no hop to the first
 * tab.
 */
@Composable
internal fun TabShellScreen(router: OrcaRouter, modifier: Modifier = Modifier) {
    // Fixed for a router: the pages never move between the two branches.
    if (router.hasDrawer) {
        ShellDrawer(router, modifier) { ShellScaffold(router, Modifier, drawer = true) }
    } else {
        ShellScaffold(router, modifier, drawer = false)
    }
    BackHandler(enabled = router.canGoBack) { router.goBack() }
    // After the other one, so it is asked first.
    BackHandler(enabled = router.isDrawerOpen) { router.closeDrawer() }
}

/** The shell without its drawer: the tab bar, the kept pages, and with a [drawer] the top bar over tab pages. */
@Composable
private fun ShellScaffold(router: OrcaRouter, modifier: Modifier, drawer: Boolean) {
    val covered = router.overRoutes.isNotEmpty()
    val serverBar = router.table?.config?.tabBarComponents.orEmpty()
    Scaffold(
        modifier = modifier,
        topBar = { if (drawer && !covered) ShellTopBar(router) },
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
        // The top bar took the status bar and the tab bar the navigation bar: a page must
        // not pad for them again (Flutter's Scaffold removes them from its body's padding).
        // Over the shell there is no tab bar, so the page pads for the bottom inset itself.
        Box(Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding)) { KeptPages(router) }
    }
}

/** The bar over the tab pages of a shell with a drawer (Flutter's `OrcaShell` AppBar): the tab's label, the menu button. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ShellTopBar(router: OrcaRouter) {
    val label = router.currentTab?.let { router.tabs.getOrNull(it) }?.label ?: ""
    TopAppBar(
        title = { Text(label, Modifier.testTag(SHELL_TITLE_TAG)) },
        navigationIcon = {
            IconButton(onClick = { router.openDrawer() }, modifier = Modifier.testTag(DRAWER_MENU_TAG)) {
                Icon(Icons.Filled.Menu, contentDescription = "Menu")
            }
        },
    )
}

/**
 * The shell's drawer, a Material 3 `ModalNavigationDrawer` around [content]:
 * the config's `drawerComponents` when it has any (a [ShellTree]; its root
 * `Drawer` draws the sheet), else the [DefaultDrawer] of its `drawerItems`.
 *
 * [OrcaRouter.isDrawerOpen] is the truth: the sheet animates to it. Where
 * the user leaves the sheet (a swipe, a tap on the scrim) is told to the
 * router once the sheet rests there; a rest the router asked for changes
 * nothing, so neither side answers the other twice. A drag that takes the
 * sheet from the router's animation and lets it go where it was is not the
 * user's word: the sheet then goes where the router asked. Swipes and the scrim
 * work on tab pages only: a route over the shell has no drawer.
 */
@Composable
private fun ShellDrawer(router: OrcaRouter, modifier: Modifier, content: @Composable () -> Unit) {
    val state = rememberDrawerState(if (router.isDrawerOpen) DrawerValue.Open else DrawerValue.Closed)
    val open = router.isDrawerOpen
    LaunchedEffect(state, open) { if (open) state.open() else state.close() }
    // Where the sheet came to rest. After the router moved it, that is the router's own value.
    val current by rememberUpdatedState(router)
    LaunchedEffect(state) {
        var last = state.currentValue
        snapshotFlow { state.currentValue to state.isAnimationRunning }.drop(1).collect { (rested, moving) ->
            val restedOpen = rested == DrawerValue.Open
            val asked = current.isDrawerOpen
            if (rested != last) {
                last = rested
                if (restedOpen != asked) {
                    if (restedOpen) current.openDrawer() else current.closeDrawer()
                    // The router has no drawer to open here: the sheet goes back.
                    if (restedOpen != current.isDrawerOpen) state.close()
                }
            } else if (!moving && restedOpen != asked) {
                // Back where it was, and the router moved meanwhile: a drag took the sheet
                // from the router's animation. On its own: another drag may take it again.
                launch { if (asked) state.open() else state.close() }
            }
        }
    }

    val config = router.table?.config
    val server = config?.drawerComponents.orEmpty()
    ModalNavigationDrawer(
        drawerContent = {
            if (server.isEmpty()) DefaultDrawer(router, config?.drawerItems.orEmpty()) else ShellTreeView(router, server)
        },
        modifier = modifier,
        drawerState = state,
        gesturesEnabled = router.overRoutes.isEmpty(),
        content = content,
    )
}

/**
 * The drawer of `drawerItems` (Flutter's `_buildDefaultDrawer`): a blue
 * header "Menu", then one row per item, its Material icon and its label. A
 * tap closes the drawer, then pushes the item's route. The row of item `id`
 * carries the test tag `orca-drawer-item-id`.
 */
@Composable
private fun DefaultDrawer(router: OrcaRouter, items: List<DrawerItemDef>) {
    // The header is blue up to the top of the screen, its text under the status bar.
    ModalDrawerSheet(windowInsets = WindowInsets(0, 0, 0, 0)) {
        Box(
            Modifier
                .fillMaxWidth()
                .background(DRAWER_HEADER_COLOR)
                .windowInsetsPadding(WindowInsets.statusBars)
                .height(160.dp)
                .padding(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 8.dp),
        ) {
            Text("Menu", color = Color.White, fontSize = 24.sp)
        }
        Column(Modifier.verticalScroll(rememberScrollState()).padding(vertical = 8.dp)) {
            for (item in items) {
                NavigationDrawerItem(
                    label = { Text(item.label) },
                    selected = false,
                    onClick = {
                        router.closeDrawer()
                        router.navigate(item.route)
                    },
                    modifier = Modifier.testTag(drawerItemTag(item.id)).padding(NavigationDrawerItemDefaults.ItemPadding),
                    icon = { Icon(IconNames.vector(item.icon), contentDescription = null) },
                )
            }
        }
    }
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
 * placed. A route that left the stacks leaves the composition. Each page is
 * told whether it can pop, for its AppBar's back arrow ([LocalOrcaNavigation]):
 * a tab's root cannot, a page pushed on it and a route over the shell can,
 * and the arrow pops the router as the system back does.
 *
 * A route's transition is played here too ([ShellMotion]): the page pushed
 * on a tab, or over the shell, comes in over the previous top, which stays
 * placed until the run ends, and a popped page stays drawn while the same
 * run plays backwards over the page under it. A pop while the page is
 * still coming in takes it back from where it is, in the time it had run.
 * The moving page is drawn as
 * the core's [TransitionSpec] samples it on each frame. A change of tab
 * moves nothing, and neither does a route with no transition or `none`.
 * With reduced motion ([orcaReduceMotion]) nothing is played.
 */
@Composable
private fun KeptPages(router: OrcaRouter) {
    val top = router.top
    val routes = router.tabStacks.flatten() + router.overRoutes
    val live = routes.mapTo(HashSet()) { it.id }
    // Not Compose state: it changes only with the router's stacks, which are.
    val shown = remember(router) { HashSet<UUID>() }
    shown.retainAll(live)
    shown.add(top.id)
    // The loaders of the pages drawn: the router drops a popped route's before its page has left the screen.
    val loaders = remember(router) { HashMap<UUID, OrcaPageLoader?>() }
    val motion = remember(router) { ShellMotion() }
    // The page the top lies over: the one before it on its stack; under the first route over the shell, the tab's top.
    val over = router.overRoutes
    val under = when (val at = over.indexOf(top)) {
        -1 -> router.tabStacks.firstNotNullOfOrNull { stack -> stack.indexOf(top).takeIf { it > 0 }?.let { stack[it - 1] } }
        0 -> router.currentTab?.let { router.tabStacks.getOrNull(it)?.lastOrNull() }
        else -> over[at - 1]
    }
    motion.follow(top, under?.id, live, orcaReduceMotion())
    val run = motion.run
    LaunchedEffect(run) {
        if (run == null) return@LaunchedEffect
        var start = -1L
        do {
            val over = withFrameNanos { nanos ->
                if (start < 0) start = nanos
                motion.elapsedMs = run.fromMs + (nanos - start) / NANOS_PER_MILLI
                run.spec.isOver(motion.elapsedMs, reduceMotion = false)
            }
        } while (!over)
        motion.end(run)
    }
    val leaving = run?.route?.takeIf { run.leaving }
    loaders.keys.retainAll(if (leaving == null) live else live + leaving.id)
    // As on the single stack: a tab's root cannot pop, a page pushed on it and a route over the shell can.
    val tabRoots = router.tabStacks.mapNotNullTo(HashSet()) { it.firstOrNull()?.id }
    val atRoot = remember(router) { OrcaNavigation(router, canPop = false) }
    val pushed = remember(router) { OrcaNavigation(router, canPop = true) }

    // A field of a page that is no longer on top must not keep the keyboard.
    val focus = LocalFocusManager.current
    LaunchedEffect(top.id) { focus.clearFocus() }

    // A page that leaves is no longer on a stack: it is drawn after the others, under the key it had.
    for (route in routes + listOfNotNull(leaving)) {
        if (route.id !in shown && route !== leaving) continue
        key(route.id) {
            val moves = run != null && route === run.route
            val placed = route === top || moves || (run != null && route.id == run.under)
            var kept = Modifier.fillMaxSize().layout { measurable, constraints ->
                val placeable = measurable.measure(constraints)
                layout(placeable.width, placeable.height) { if (placed) placeable.place(0, 0) }
            }
            if (run != null && moves) {
                kept = kept
                    .zIndex(1f)
                    .graphicsLayer {
                        val at = run.at(motion.elapsedMs)
                        alpha = at.opacity.toFloat()
                        translationX = (at.offsetXFraction * size.width).toFloat()
                        translationY = (at.offsetYFraction * size.height).toFloat()
                        scaleX = at.scale.toFloat()
                        scaleY = at.scale.toFloat()
                    }
                    .semantics { this[PageMotionKey] = run.at(motion.elapsedMs) }
            }
            // A not-found route has no loader: nothing is requested for it.
            val loader = if (route.id in live) {
                (if (route.isNotFound) null else router.loader(route)).also { loaders[route.id] = it }
            } else {
                loaders[route.id]
            }
            Box(kept) {
                CompositionLocalProvider(LocalOrcaNavigation provides if (route.id in tabRoots) atRoot else pushed) {
                    RoutePage(router, route, loader)
                }
            }
        }
    }
}

/**
 * The route transition the shell is playing, if any: which page moves and
 * which stays under it. [follow] is told the top route on every
 * composition and starts a run when it changed by a push or a pop.
 */
private class ShellMotion {
    /**
     * One run: [route] moves (in on a push, out when [leaving]) over the
     * page of the route [under]. Its first frame is [fromMs] into the
     * transition: more than 0 for a pop of a page that was still coming in.
     */
    class Run(val route: OrcaRoute, val under: UUID, val leaving: Boolean, val spec: TransitionSpec, val fromMs: Double = 0.0) {
        /** The moving page [elapsedMs] into the run. */
        fun at(elapsedMs: Double): PageMotion =
            if (leaving) spec.leaving(elapsedMs, reduceMotion = false) else spec.entering(elapsedMs, reduceMotion = false)
    }

    /** The run on screen, or null. */
    var run: Run? by mutableStateOf(null)
        private set

    /** How far into its transition the run is: [Run.fromMs] and the time since its first frame. */
    var elapsedMs: Double by mutableDoubleStateOf(0.0)

    private var lastTop: OrcaRoute? = null
    private var lastLive: Set<UUID> = emptySet()

    /**
     * The top is now [top], lying over the page of [under] (null for the
     * root of a stack), and the routes on the stacks are [live]. A push (the
     * route on top was on no stack before and lies over another page) plays
     * the new route's transition; a pop (the old top gone, the new one
     * known) plays the old top's backwards, from where that page is when
     * it was still coming in (Flutter's controller reversed: as long back
     * as it came); anything else (the first page, a change of tab, the root
     * of a stack) ends a run and starts none.
     * Nothing is played for a transition that has no run
     * ([TransitionSpec.runMs]).
     */
    fun follow(top: OrcaRoute, under: UUID?, live: Set<UUID>, reduceMotion: Boolean) {
        val last = lastTop
        if (last != null && last !== top) {
            val pushed = top.id !in lastLive && under != null
            val popped = last.id !in live && top.id in lastLive
            val next = when {
                pushed -> Run(top, checkNotNull(under), leaving = false, TransitionSpec.of(top.transition))
                popped -> {
                    val spec = TransitionSpec.of(last.transition)
                    val entering = run?.takeIf { !it.leaving && it.route === last }
                    // What is left of the way in is already behind on the way out.
                    val from = if (entering == null) 0.0 else (spec.runMs(reduceMotion) - elapsedMs).coerceAtLeast(0.0)
                    Run(last, top.id, leaving = true, spec, from)
                }
                else -> null
            }
            elapsedMs = next?.fromMs ?: 0.0
            run = next?.takeIf { it.spec.runMs(reduceMotion) > 0.0 }
        }
        lastTop = top
        lastLive = live
    }

    /** [ended] reached its last frame. */
    fun end(ended: Run) {
        if (run === ended) run = null
    }
}

/** What the shell draws the moving page with on this frame, on that page's node while a route transition runs. */
internal val PageMotionKey: SemanticsPropertyKey<PageMotion> = SemanticsPropertyKey("OrcaPageMotion")

private const val NANOS_PER_MILLI = 1_000_000.0

/**
 * A server tree of the tab shell (`tabBarComponents`, `drawerComponents`)
 * as a page model: no page state, the router's app state, page id
 * `__shell__` (Flutter's `OrcaShell` renders them so). It gets the plugins,
 * custom actions and host widgets of the router's OrcaApp, as a page does
 * ([OrcaPageLoader]). Unknown widgets degrade as on a page.
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
        registry = router.plugins?.registry ?: WidgetRegistry.shared,
        client = router.client,
    ).also { router.plugins?.install(it) }

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

/** The default drawer's header colour (Flutter's `OrcaShell`: 0xFF1976D2). */
private val DRAWER_HEADER_COLOR = Color(0xFF1976D2)

/** The test tag of the title in the top bar a shell with a drawer draws over its tab pages. */
internal const val SHELL_TITLE_TAG: String = "orca-shell-title"

/** The test tag of that bar's menu button. */
internal const val DRAWER_MENU_TAG: String = "orca-drawer-menu"

/** The test tag of the default drawer's row for the `drawerItems` entry [id]. */
internal fun drawerItemTag(id: String): String = "orca-drawer-item-$id"
