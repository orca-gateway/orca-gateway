package com.orcagateway.sdk.navigation

import android.content.Intent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.StaticFlowManager
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.core.models.TabDef
import com.orcagateway.core.navigation.DeepLink
import com.orcagateway.core.navigation.DeeplinkEvent
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.core.navigation.RouteChangeType
import com.orcagateway.core.navigation.RouteResolution
import com.orcagateway.core.navigation.RouteResolutionKind
import com.orcagateway.core.navigation.RouteTable
import com.orcagateway.core.navigation.TabShell
import com.orcagateway.core.navigation.TabShellChange
import com.orcagateway.core.navigation.TabShellEntry
import com.orcagateway.core.navigation.open
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.SavedState
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPluginHost
import com.orcagateway.sdk.OrcaSnackbarQueue
import com.orcagateway.sdk.system.SystemActions
import java.util.UUID

/**
 * One page on the navigation stack: a server path such as `home` or
 * `product`. Each push is a new route, so the same path twice is two pages.
 *
 * A router built from a config fills the rest from the route it resolved;
 * a route made from a path alone has that path as its [location].
 */
public class OrcaRoute(
    path: String,
    location: String? = null,
    scaffoldTitle: String? = null,
    isNotFound: Boolean = false,
    transition: RouteTransitionDef? = null,
) {
    public val id: UUID = UUID.randomUUID()

    // Routes arrive as "about" or "/about"; the page URL wants no slash.
    /** The page request path, without a leading slash. */
    public val path: String = path.trimStart('/')

    /**
     * The full location, with its leading slash and its query: what
     * `onRouteChanged` reports. Compose state: a replace navigation that
     * keeps this page (the same page, another query) moves it.
     */
    public var location: String by mutableStateOf(location ?: "/${this.path}")
        internal set

    // The three below are Compose state for the same reason: a kept page that
    // becomes the top of the chain, or a parent under it, takes them anew.

    /** Fallback title when the page is drawn under a title bar (a top-level route beside tabs), else null. */
    public var scaffoldTitle: String? by mutableStateOf(scaffoldTitle)
        internal set

    /** The location matched no route: the "page not found" screen, and nothing is requested. */
    public var isNotFound: Boolean by mutableStateOf(isNotFound)
        internal set

    /** The matched route's transition, when it declares one. */
    public var transition: RouteTransitionDef? by mutableStateOf(transition)
        internal set

    override fun toString(): String = "OrcaRoute($path)"
}

/**
 * The navigation stack of an Orca app, the Kotlin side of Flutter's GoRouter
 * wiring (sdk/lib/src/navigation/navigation_handler.dart):
 * - every route is its own page fetch with its own page state;
 * - app state is one shared scope, sent with each page request;
 * - [navigate] pushes, [navigate] with `replace` goes to the route as the
 *   only page (GoRouter `go`), and [goBack] pops.
 *
 * Built from a [NavConfig], it starts at the config's `initialRoute` with
 * the config's `initialAppState` (with a [savedState], the saved app entry
 * laid over it first), and every location goes through a
 * [RouteTable]: the route's redirect rule is applied (once), a nested
 * location shown with `replace` comes with its parent pages under it, and a
 * location no route matches is a route with [OrcaRoute.isNotFound]. Built
 * from a path, there is no table: every path is a page.
 *
 * A deep link ([handleDeeplink], [handleIntent]) is a `replace` navigation
 * to the link's location, reported to [onDeeplink].
 *
 * A config with [tabs] gives every tab its own stack (a
 * [TabShell][com.orcagateway.core.navigation.TabShell]): [root] and [stack]
 * are the stack on screen, the current tab's pages and then the routes over
 * the tab shell ([overRoutes]). A page lives as long as its route is on any
 * tab's stack, so switching tabs ([selectTab], [switchTab], an app state
 * write of `_tabIndex`) closes and requests nothing. The router keeps app
 * state `_tabIndex` at the current tab's index.
 *
 * [OrcaApp][com.orcagateway.sdk.OrcaApp] draws it (the stacks are Compose
 * state): a single stack on a `NavHost` that follows [root] and [stack], a
 * config with tabs on the tab shell. Use it from the main thread.
 *
 * [system] performs `openUrl`, `copyToClipboard` and `share`; without one
 * they are only reported to [onEffect]. While `OrcaApp` shows a router that
 * has none, it sets the device's own ([SystemActions.android]) and takes
 * them away again when it leaves.
 */
public class OrcaRouter private constructor(
    public val client: OrcaClient,
    public var system: SystemActions?,
    /** The route table of the config this router was built from; null for a router built from a path. */
    public val table: RouteTable?,
    start: String,
    /**
     * Called once per change of the location on top, after the redirect
     * resolved (Flutter's `onLocationChanged`): [navigate] is a `Push`, with
     * `replace` a `Replace`, [goBack] and a [stack] set shorter a `Pop`,
     * a change of tab a `Replace`.
     * Nothing is reported while the top location stays the same.
     */
    public var onRouteChanged: ((RouteChangeEvent) -> Unit)?,
    // The link that opened the app: the router starts at its location, not at `start`.
    coldLink: String?,
    /**
     * Where the pages loaded here save (`persistState`) and drop
     * (`clearState`) saved copies of their state, and what is restored
     * (Flutter's StateManager `SavedState`): its app entry is laid over the
     * first [appState] before the first route is resolved, so the redirect
     * and the first page request see it, and each page's entry over the
     * page's declared initials. Null: nothing is saved or restored.
     */
    public val savedState: SavedState?,
) : AutoCloseable {
    /** A router without a config, starting at [path]: every path is a page. */
    public constructor(
        client: OrcaClient,
        path: String = "home",
        system: SystemActions? = null,
        savedState: SavedState? = null,
    ) : this(client, system, null, path, null, null, savedState)

    /** A router without a config that [coldLink] opened: it starts at the link's location instead of [path]. */
    internal constructor(client: OrcaClient, path: String, system: SystemActions?, coldLink: String?, savedState: SavedState?) :
        this(client, system, null, path, null, coldLink, savedState)

    /**
     * A router for [config] that [coldLink] opened: it starts at the link's
     * location instead of `initialRoute`, and the link's event waits for
     * [deliverColdLink].
     */
    internal constructor(
        client: OrcaClient,
        config: NavConfig,
        system: SystemActions?,
        onRouteChanged: ((RouteChangeEvent) -> Unit)?,
        coldLink: String?,
        savedState: SavedState?,
    ) : this(client, system, RouteTable(config), config.initialRoute, onRouteChanged, coldLink, savedState)

    /**
     * A router for the server's [config] (`OrcaClient.fetchConfig`): app
     * state starts as `initialAppState`, with [savedState]'s app entry laid
     * over it, and `initialRoute` is resolved against it and shown.
     * [onRouteChanged] passed here gets the first event, with no previous
     * location and type `Push`.
     */
    public constructor(
        client: OrcaClient,
        config: NavConfig,
        system: SystemActions? = null,
        onRouteChanged: ((RouteChangeEvent) -> Unit)? = null,
        savedState: SavedState? = null,
    ) : this(client, system, RouteTable(config), config.initialRoute, onRouteChanged, null, savedState)

    /**
     * Called once per deep link ([handleDeeplink]), after the navigation and
     * after [onRouteChanged] reported it; also for a link that navigated
     * nowhere (its location was on screen) and for one no route matches.
     */
    public var onDeeplink: ((DeeplinkEvent) -> Unit)? = null

    /**
     * OrcaApp(router) gave this router the launch Intent's link. Kept here, not
     * in the composition: an OrcaApp hidden and shown again in the same
     * activity does not handle that link a second time.
     */
    internal var launchLinkTaken: Boolean = false

    // The event of the link that opened the app, until deliverColdLink hands it over.
    private var coldEvent: DeeplinkEvent? = null

    // The first location's event when nobody listened yet, until deliverFirstRoute hands it over or the location moves.
    private var firstEvent: RouteChangeEvent? = null

    /** The shared app scope, as the latest page or [setAppState] left it. */
    public var appState: Map<String, JsonValue> = restored(table?.config?.initialAppState.orEmpty(), savedState)
        // Named apart from the host's `setAppState(Map)`.
        @JvmName("writeAppState")
        private set(value) {
            field = value
            for (listener in appStateListeners.toList()) listener(value)
        }

    private val appStateListeners = ArrayList<(Map<String, JsonValue>) -> Unit>()

    /**
     * Calls [listener] with the app scope after every write of it (a page's
     * commit, the host's, the router's `_tabIndex`), until the returned
     * handle is closed: the tab shell's server trees are drawn against app
     * state, and belong to no page the router commits into.
     */
    internal fun onAppStateChange(listener: (Map<String, JsonValue>) -> Unit): AutoCloseable {
        appStateListeners.add(listener)
        return AutoCloseable { appStateListeners.remove(listener) }
    }

    /** The page under every pushed route. */
    public var root: OrcaRoute by mutableStateOf(coldLink?.let { pathRoute(DeepLink.location(it)) } ?: OrcaRoute(start))
        private set

    private var routes by mutableStateOf(emptyList<OrcaRoute>())

    /**
     * Pushed routes, bottom to top: the pages the `NavHost` shows over [root].
     * With a config, a stack set by the host goes through the table like
     * [goBack] and [navigate]: routes taken off the top are popped, and each
     * route added is pushed by its location and stays the route given.
     */
    public var stack: List<OrcaRoute>
        get() = routes
        set(value) {
            val type = if (value.size < routes.size) RouteChangeType.Pop else RouteChangeType.Push
            val shell = shell
            if (shell == null) {
                routes = value
            } else {
                val current = routes
                var kept = 0
                while (kept < value.size && kept < current.size && value[kept] === current[kept]) kept++
                repeat(current.size - kept) { for (entry in shell.pop().dropped) bound.remove(entry.id) }
                for (route in value.drop(kept)) {
                    shell.push(route.location, appState)
                    val entry = shell.visible.last()
                    bound[entry.id] = Bound(route, entry)
                }
                follow()
            }
            routesChanged(type)
        }

    /** The tabs of the config, in bar order; empty without a config or when it has none. */
    public val tabs: List<TabDef> get() = table?.config?.tabs.orEmpty()

    /** A tab shell is on screen: the config has tabs and the last replace navigation (or the boot) landed in one. */
    public val hasShell: Boolean get() = currentTab != null

    /** The tab on screen, also under a route pushed over the shell; null when [hasShell] is false. Compose state. */
    public var currentTab: Int? by mutableStateOf(null)
        private set

    /** One stack per tab, bottom to top; empty: not visited since the shell came on screen. Compose state. */
    public var tabStacks: List<List<OrcaRoute>> by mutableStateOf(emptyList())
        private set

    /** The routes above the tab shell, bottom to top; with a config and no shell, the whole stack. Compose state. */
    public var overRoutes: List<OrcaRoute> by mutableStateOf(emptyList())
        private set

    /** The config has tabs and a drawer for them (`drawerItems` or `drawerComponents`). */
    public val hasDrawer: Boolean
        get() = table?.config?.let { it.tabs.isNotEmpty() && (it.drawerItems.isNotEmpty() || it.drawerComponents.isNotEmpty()) } ?: false

    /** The tab shell's drawer is open ([openDrawer], [closeDrawer]). Compose state. */
    public var isDrawerOpen: Boolean by mutableStateOf(false)
        private set

    /**
     * The route whose page was asked to open its own drawer ([openDrawer]
     * where the shell drawer does not apply). The page that opens it sets
     * this back to null; with no such page nothing happens. Compose state.
     */
    public var pageDrawerRequest: UUID? by mutableStateOf(null)

    /** [goBack] would pop a page: false at a tab's root and on the root page. */
    public val canGoBack: Boolean get() = routes.isNotEmpty()

    /** Called with every effect a page reports, for DevTools and logging. */
    public var onEffect: ((ActionEffect) -> Unit)? = null

    /**
     * The app's one queue of snackbars and toasts, Flutter's root
     * ScaffoldMessenger (MaterialApp's): every page attached here shows into
     * it, and it is kept across navigate, back and a change of tab, so a bar
     * a page showed stays on the next page with its time still running.
     */
    internal val snackbars: OrcaSnackbarQueue = OrcaSnackbarQueue()

    /** What OrcaApp's plugins give each page loaded from here; OrcaApp sets it before the first request. */
    internal var plugins: OrcaPluginHost? = null

    /**
     * The offline cache each page is asked of first (Flutter hands its
     * `StaticFlowManager` to every OrcaPage); OrcaApp's boot sets it before
     * the first page loads. Null: every page comes from the network.
     */
    internal var staticFlowManager: StaticFlowManager? = null

    /** The flows of the config, where [staticFlowManager] looks a page up; empty without a config. */
    internal val flows: List<NavFlow> get() = table?.config?.flows.orEmpty()

    private val loaders = HashMap<UUID, OrcaPageLoader>()

    // With a config, every navigation goes through the shell; its entries are the routes.
    private val shell: TabShell? = table?.let { TabShell(it) }

    /** The route of a shell entry, and the entry as it was when the route last followed it. */
    private class Bound(val route: OrcaRoute, var entry: TabShellEntry)

    private val bound = HashMap<Int, Bound>()

    // App state `_tabIndex` as last seen: a different value is somebody's write.
    private var seenTabIndex: JsonValue? = appState[TAB_INDEX]

    // The top location last reported (or the first one, when nobody listened yet).
    private var shownLocation: String

    init {
        val begin = coldLink?.let { DeepLink.location(it) } ?: start
        val resolution = if (shell != null) {
            // On a fresh shell a link's `open` is the `go` of its location.
            val opened = shell.open(begin, appState)
            follow()
            // Before the first page request: no page is loaded yet.
            opened.change.tabIndexWrite?.let { writeTabIndex(it) }
            opened.resolution
        } else {
            pathResolution(begin)
        }
        shownLocation = top.location
        if (table != null) {
            val first = RouteChangeEvent(shownLocation, null, RouteChangeType.Push)
            val listener = onRouteChanged
            if (listener != null) listener(first) else firstEvent = first
        }
        if (coldLink != null) coldEvent = DeepLink.event(coldLink, resolution, coldStart = true)
    }

    /**
     * Open a deep link, a URL the platform handed to the app
     * (`https://shop.example/product/3?tab=specs`, `myapp://open/settings`):
     * the router goes to its location, the URL's path and query
     * ([DeepLink.location]; scheme, host and fragment are dropped), as
     * [navigate] with `replace` does, so the stack and the tab come from the
     * config and the route's redirect rule is applied. A link that ends on
     * the location already on screen navigates nowhere and requests nothing.
     * Then [onDeeplink] is called, once, after [onRouteChanged].
     *
     * [OrcaApp][com.orcagateway.sdk.OrcaApp] calls it for the activity's
     * Intents; call it yourself for a link received elsewhere (a push
     * notification). [isColdStart] is only reported in the event: pass true
     * when the link is what opened the app.
     */
    public fun handleDeeplink(link: String, isColdStart: Boolean = false) {
        val location = DeepLink.location(link)
        val shell = shell
        val resolution = if (shell != null) {
            val opened = shell.open(location, appState)
            apply(opened.change, RouteChangeType.Replace)
            opened.resolution
        } else {
            if (location != top.location) {
                root = pathRoute(location)
                routes = emptyList()
                routesChanged(RouteChangeType.Replace)
            }
            pathResolution(location)
        }
        onDeeplink?.invoke(DeepLink.event(link, resolution, isColdStart))
    }

    /**
     * [handleDeeplink] for the link of [intent], the data of an
     * `ACTION_VIEW` Intent, for a host that receives `onNewIntent` itself.
     * False, and nothing happens, when the Intent carries no link.
     */
    public fun handleIntent(intent: Intent): Boolean {
        val link = intent.deeplink() ?: return false
        handleDeeplink(link)
        return true
    }

    /** Hand the event of the link that opened the app to [onDeeplink], once; OrcaApp calls it when it shows the router. */
    internal fun deliverColdLink() {
        val event = coldEvent ?: return
        coldEvent = null
        onDeeplink?.invoke(event)
    }

    /**
     * Hand the first location's event to [onRouteChanged], once, when the
     * router was made before anyone listened (OrcaApp's preloaded boot makes
     * it while composing) and the location has not moved since; OrcaApp calls
     * it when it shows the router.
     */
    internal fun deliverFirstRoute() {
        val event = firstEvent ?: return
        firstEvent = null
        onRouteChanged?.invoke(event)
    }

    /** The loader of a route, made the first time it is asked for. */
    public fun loader(route: OrcaRoute): OrcaPageLoader =
        loaders.getOrPut(route.id) { OrcaPageLoader(client, route.path, router = this) }

    /** The route on top: the one a user is looking at. */
    public val top: OrcaRoute get() = stack.lastOrNull() ?: root

    /**
     * Show [path] (`about`, `/about`, `/product/3?tab=specs`): pushed over
     * the page on top, or with [replace] as the only page, the way GoRouter
     * `go` shows it (a nested route comes with its parent pages under it).
     * With a config the location is resolved first: the redirect rule reads
     * [appState] as it is now, and a push adds one page, the resolved one.
     */
    public fun navigate(path: String, replace: Boolean = false) {
        if (path.isEmpty()) return
        val shell = shell
        if (shell != null) {
            if (replace) {
                apply(shell.go(path, appState), RouteChangeType.Replace)
            } else {
                apply(shell.push(path, appState), RouteChangeType.Push)
            }
        } else if (replace) {
            root = OrcaRoute(path)
            routes = emptyList()
            routesChanged(RouteChangeType.Replace)
        } else {
            routes = routes + OrcaRoute(path)
            routesChanged(RouteChangeType.Push)
        }
    }

    /** Pop the page on top; nothing happens on the root page or at a tab's root. */
    public fun goBack() {
        if (stack.isEmpty()) return
        val shell = shell
        if (shell != null) apply(shell.pop(), RouteChangeType.Pop) else stack = stack.dropLast(1)
    }

    /**
     * A tap on the tab bar: tab [index] comes back as it was left (its page
     * is requested on the first visit only), and a tap on the current tab
     * pops it to its root. Routes over the shell are dropped. Nothing
     * without a shell or for an index that is no tab's.
     */
    public fun selectTab(index: Int) {
        val shell = shell ?: return
        apply(shell.selectTab(index, appState), RouteChangeType.Replace)
    }

    /** The `switchTab` action: show the root of the tab with id [tabId]. Nothing for an unknown id or without tabs. */
    public fun switchTab(tabId: String) {
        val shell = shell ?: return
        apply(shell.switchTab(tabId, appState), RouteChangeType.Replace)
    }

    /**
     * The `openDrawer` action: on a tab page of a config with a drawer
     * ([hasDrawer]) the shell drawer opens; anywhere else the page on top is
     * asked for its own ([pageDrawerRequest]).
     */
    public fun openDrawer() {
        if (hasShell && overRoutes.isEmpty() && hasDrawer) isDrawerOpen = true else pageDrawerRequest = top.id
    }

    /** Close the shell drawer. */
    public fun closeDrawer() {
        isDrawerOpen = false
    }

    /** Write one app state key from the host: see the map form. */
    public fun setAppState(key: String, value: JsonValue) {
        setAppState(mapOf(key to value))
    }

    /**
     * Write app state from the host: [values] are laid over [appState] and
     * committed into every page the router has loaded, so widgets watching
     * a key redraw; a page loaded later starts from them. It does not
     * navigate: a redirect rule reads the new state at the next [navigate].
     * The one key that does is `_tabIndex`: another tab's index shows that tab.
     */
    public fun setAppState(values: Map<String, JsonValue>) {
        appState = appState + values
        tabIndexMayHaveChanged()
        val next = appState
        for (loader in loaders.values.toList()) {
            val store = (loader.phase as? OrcaPageLoader.Phase.Loaded)?.model?.store ?: continue
            if (store.state.app != next) store.commit(store.state.copy(app = next))
        }
    }

    /** Close every page's loader (their running actions stop) and forget them. */
    override fun close() {
        for (loader in loaders.values) loader.close()
        loaders.clear()
    }

    /**
     * Wire a page that just loaded: its commits keep the shared app scope,
     * its navigation and system effects come here, its effects are reported,
     * and its snackbars and toasts join the app's queue ([snackbars]).
     */
    internal fun attach(model: OrcaPageModel) {
        model.snackbars = snackbars
        // The page seeded its own app definitions; they are shared from now.
        // The scope may have moved on while the page was fetched (the host
        // or another page wrote): those values stay, and what the page
        // seeded fills only the keys still unset.
        val scope = appState.toMutableMap()
        for ((key, value) in model.store.state.app) {
            if (scope[key]?.isNull != false) scope[key] = value
        }
        appState = scope
        if (model.store.state.app != scope) model.store.commit(model.store.state.copy(app = scope))
        model.store.onCommit = { state ->
            appState = state.app
            tabIndexMayHaveChanged()
        }
        model.onEffect = { effect -> onEffect?.invoke(effect) }
        model.effectHandler = { effect -> if (!perform(effect)) system?.perform(effect) }
    }

    /** Take what a shell operation changed: the stacks, the `_tabIndex` write, the loaders, the location. */
    private fun apply(change: TabShellChange, type: RouteChangeType) {
        for (entry in change.dropped) bound.remove(entry.id)
        follow()
        change.tabIndexWrite?.let { writeTabIndex(it) }
        routesChanged(type)
    }

    /** Make [root], [stack], [tabStacks], [overRoutes] and [currentTab] those of the shell. */
    private fun follow() {
        val shell = shell ?: return
        tabStacks = shell.tabStacks.map { stack -> stack.map(::route) }
        overRoutes = shell.over.map(::route)
        currentTab = shell.currentTab
        val visible = shell.visible.map(::route)
        root = visible.first()
        routes = visible.drop(1)
    }

    /**
     * The route of a shell entry, one for the entry's life. An entry a
     * replace navigation kept comes back changed (the top of another
     * resolution, or under a new page): its route follows with every field
     * a new route for the entry would have, and keeps its id and its loader.
     */
    private fun route(entry: TabShellEntry): OrcaRoute {
        val known = bound[entry.id] ?: return newRoute(entry).also { bound[entry.id] = Bound(it, entry) }
        if (known.entry != entry) {
            known.entry = entry
            val fresh = newRoute(entry)
            known.route.location = entry.location
            known.route.scaffoldTitle = fresh.scaffoldTitle
            known.route.isNotFound = fresh.isNotFound
            known.route.transition = fresh.transition
        }
        return known.route
    }

    /**
     * A new route for an entry: only the top of a page chain carries the
     * resolved location, the title and the transition; the pages under it
     * are plain; an error is the one not-found route.
     */
    private fun newRoute(entry: TabShellEntry): OrcaRoute {
        val resolution = entry.resolution
        if (resolution.kind == RouteResolutionKind.Error) {
            val path = resolution.location.substringBefore('?')
            return OrcaRoute(path, location = resolution.location, isNotFound = true)
        }
        if (!entry.isTop) return OrcaRoute(entry.pagePath)
        val page = resolution.pagePath ?: entry.pagePath
        return OrcaRoute(page, resolution.location, resolution.scaffoldTitle, transition = resolution.transition)
    }

    /** The shell asked for `_tabIndex`: into app state and every loaded page, as the router's own write. */
    private fun writeTabIndex(index: Int) {
        val value = JsonValue.Int(index.toLong())
        seenTabIndex = value
        setAppState(TAB_INDEX, value)
    }

    /**
     * App state changed: when `_tabIndex` is not what the router last saw, a
     * page or the host wrote it, and another tab's index shows that tab.
     * The router's own write is seen before it lands, so it stops here.
     */
    private fun tabIndexMayHaveChanged() {
        val shell = shell ?: return
        val value = appState[TAB_INDEX]
        if (value == seenTabIndex) return
        seenTabIndex = value
        apply(shell.tabIndexChanged(value, appState), RouteChangeType.Replace)
    }

    /**
     * Drop (and close) loaders of routes that left every stack, hand the
     * page now on top the latest app scope, and report a top location that
     * changed as a [type] event (which also closes the shell drawer).
     */
    private fun routesChanged(type: RouteChangeType) {
        // With a config: every route on any tab's stack or over the shell, shown or not.
        val live = if (shell != null) bound.values.mapTo(HashSet()) { it.route.id } else stack.mapTo(HashSet()) { it.id } + root.id
        for (id in loaders.keys - live) loaders.remove(id)?.close()
        // Without a shell OrcaApp draws one NavHost, which takes every page but the top one out of the
        // composition; a page it covers still hears the app events. The tab shell keeps every page composed.
        for ((id, loader) in loaders) (loader.phase as? OrcaPageLoader.Phase.Loaded)?.model?.isCovered = !hasShell && id != top.id
        if (pageDrawerRequest != null && pageDrawerRequest !in live) pageDrawerRequest = null
        val model = (loaders[top.id]?.phase as? OrcaPageLoader.Phase.Loaded)?.model
        if (model != null && model.store.state.app != appState) model.store.commit(model.store.state.copy(app = appState))

        val location = top.location
        if (location == shownLocation) return
        val previous = shownLocation
        shownLocation = location
        firstEvent = null
        isDrawerOpen = false
        onRouteChanged?.invoke(RouteChangeEvent(location, previous, type))
    }

    /** Perform a navigation effect; false for any other effect. */
    internal fun perform(effect: ActionEffect): Boolean {
        when (effect.type) {
            "navigate" -> navigate(
                effect.payload["route"]?.stringValue ?: "",
                replace = effect.payload["replace"]?.boolValue ?: false,
            )
            "goBack" -> goBack()
            "switchTab" -> switchTab(effect.payload["tabId"]?.stringValue ?: "")
            "openDrawer" -> openDrawer()
            else -> return false
        }
        return true
    }

    private companion object {
        /** The app state key that holds the current tab's index (Flutter's `OrcaShell`). */
        const val TAB_INDEX = "_tabIndex"

        /**
         * [initial] with every key of [saved]'s app entry laid over it, replaced
         * or added: Flutter's `restoreApp`, right after the `initialAppState`
         * loop of `_initRouter`. The entry's first read reads its file.
         */
        fun restored(initial: Map<String, JsonValue>, saved: SavedState?): Map<String, JsonValue> {
            if (saved == null) return initial
            val store = ElmStore(StoreState(app = initial))
            saved.restore(store)
            return store.state.app
        }

        /** Without a config, the route of a link's location: the page is its path, the query stays in the location. */
        fun pathRoute(location: String): OrcaRoute = OrcaRoute(location.substringBefore('?'), location = location)

        // No route: its `resolve` only reads the location, so the query is core's own decoding.
        val noRoutes = RouteTable(NavConfig())

        /** Without a config every path is a page: nothing redirects and there are no path parameters. */
        fun pathResolution(location: String): RouteResolution =
            noRoutes.resolve(location, emptyMap()).copy(kind = RouteResolutionKind.Page)
    }
}

/** The deep link an Intent carries: the data of an `ACTION_VIEW`, else null. */
internal fun Intent.deeplink(): String? = if (action == Intent.ACTION_VIEW) dataString else null

/**
 * What a page knows of the stack it is shown on, provided by
 * [OrcaApp][com.orcagateway.sdk.OrcaApp] around each page: [canPop] when the
 * page is a pushed one (not the root), and [goBack] pops the [router]. The
 * AppBar's implied back arrow is drawn from it (Flutter `ModalRoute.canPop`).
 * A page shown outside `OrcaApp` has no router: it cannot pop, and [goBack]
 * does nothing.
 */
internal class OrcaNavigation(val router: OrcaRouter?, val canPop: Boolean) {
    fun goBack() {
        router?.goBack()
    }
}

internal val LocalOrcaNavigation = staticCompositionLocalOf { OrcaNavigation(router = null, canPop = false) }
