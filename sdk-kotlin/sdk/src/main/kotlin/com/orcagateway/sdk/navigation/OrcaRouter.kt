package com.orcagateway.sdk.navigation

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.RouteTransitionDef
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.core.navigation.RouteChangeType
import com.orcagateway.core.navigation.RouteResolution
import com.orcagateway.core.navigation.RouteResolutionKind
import com.orcagateway.core.navigation.RouteTable
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPluginHost
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
    /** Fallback title when the page is drawn under a title bar (a top-level route beside tabs), else null. */
    public val scaffoldTitle: String? = null,
    /** The location matched no route: the "page not found" screen, and nothing is requested. */
    public val isNotFound: Boolean = false,
    /** The matched route's transition, when it declares one. */
    public val transition: RouteTransitionDef? = null,
) {
    public val id: UUID = UUID.randomUUID()

    // Routes arrive as "about" or "/about"; the page URL wants no slash.
    /** The page request path, without a leading slash. */
    public val path: String = path.trimStart('/')

    /** The full location, with its leading slash and its query: what `onRouteChanged` reports. */
    public val location: String = location ?: "/${this.path}"

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
 * the config's `initialAppState`, and every location goes through a
 * [RouteTable]: the route's redirect rule is applied (once), a nested
 * location shown with `replace` comes with its parent pages under it, and a
 * location no route matches is a route with [OrcaRoute.isNotFound]. Built
 * from a path, there is no table: every path is a page.
 *
 * [OrcaApp][com.orcagateway.sdk.OrcaApp] draws it on a `NavHost` that
 * follows [root] and [stack] (Compose state). Use it from the main thread.
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
     * `replace` a `Replace`, [goBack] and a [stack] set shorter a `Pop`.
     * Nothing is reported while the top location stays the same.
     */
    public var onRouteChanged: ((RouteChangeEvent) -> Unit)?,
) : AutoCloseable {
    /** A router without a config, starting at [path]: every path is a page. */
    public constructor(client: OrcaClient, path: String = "home", system: SystemActions? = null) :
        this(client, system, null, path, null)

    /**
     * A router for the server's [config] (`OrcaClient.fetchConfig`): app
     * state starts as `initialAppState`, and `initialRoute` is resolved
     * against it and shown. [onRouteChanged] passed here gets the first
     * event, with no previous location and type `Push`.
     */
    public constructor(
        client: OrcaClient,
        config: NavConfig,
        system: SystemActions? = null,
        onRouteChanged: ((RouteChangeEvent) -> Unit)? = null,
    ) : this(client, system, RouteTable(config), config.initialRoute, onRouteChanged)

    /** The shared app scope, as the latest page or [setAppState] left it. */
    public var appState: Map<String, JsonValue> = table?.config?.initialAppState.orEmpty()
        private set

    /** The page under every pushed route. */
    public var root: OrcaRoute by mutableStateOf(OrcaRoute(start))
        private set

    private var routes by mutableStateOf(emptyList<OrcaRoute>())

    /** Pushed routes, bottom to top: the pages the `NavHost` shows over [root]. */
    public var stack: List<OrcaRoute>
        get() = routes
        set(value) {
            val type = if (value.size < routes.size) RouteChangeType.Pop else RouteChangeType.Push
            routes = value
            routesChanged(type)
        }

    /** Called with every effect a page reports, for DevTools and logging. */
    public var onEffect: ((ActionEffect) -> Unit)? = null

    /** What OrcaApp's plugins give each page loaded from here; OrcaApp sets it before the first request. */
    internal var plugins: OrcaPluginHost? = null

    private val loaders = HashMap<UUID, OrcaPageLoader>()

    // The top location last reported (or the first one, when nobody listened yet).
    private var shownLocation: String

    init {
        if (table != null) {
            val chain = chain(table.resolve(slashed(start), appState))
            root = chain.first()
            routes = chain.drop(1)
        }
        shownLocation = top.location
        if (table != null) onRouteChanged?.invoke(RouteChangeEvent(shownLocation, null, RouteChangeType.Push))
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
        val chain = if (table != null) chain(table.resolve(slashed(path), appState)) else listOf(OrcaRoute(path))
        if (replace) {
            root = chain.first()
            routes = chain.drop(1)
            routesChanged(RouteChangeType.Replace)
        } else {
            routes = routes + chain.last()
            routesChanged(RouteChangeType.Push)
        }
    }

    /** Pop the page on top; nothing happens on the root page. */
    public fun goBack() {
        if (stack.isEmpty()) return
        stack = stack.dropLast(1)
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
     */
    public fun setAppState(values: Map<String, JsonValue>) {
        val next = appState + values
        appState = next
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
     * its navigation and system effects come here, its effects are reported.
     */
    internal fun attach(model: OrcaPageModel) {
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
        model.store.onCommit = { state -> appState = state.app }
        model.onEffect = { effect -> onEffect?.invoke(effect) }
        model.effectHandler = { effect -> if (!perform(effect)) system?.perform(effect) }
    }

    /**
     * The routes a resolution shows, bottom to top: its page chain, of which
     * only the top entry carries the location, the title and the transition;
     * or the one not-found route.
     */
    private fun chain(resolution: RouteResolution): List<OrcaRoute> {
        if (resolution.kind == RouteResolutionKind.Error) {
            val path = resolution.location.substringBefore('?')
            return listOf(OrcaRoute(path, location = resolution.location, isNotFound = true))
        }
        val parents = resolution.stack.dropLast(1).map { OrcaRoute(it) }
        val page = resolution.pagePath ?: resolution.stack.last()
        return parents + OrcaRoute(page, resolution.location, resolution.scaffoldTitle, transition = resolution.transition)
    }

    private fun slashed(location: String): String = if (location.startsWith("/")) location else "/$location"

    /**
     * Drop (and close) loaders of routes that left the stack, hand the page
     * now on top the latest app scope, and report a top location that
     * changed as a [type] event.
     */
    private fun routesChanged(type: RouteChangeType) {
        val live = stack.mapTo(HashSet()) { it.id } + root.id
        for (id in loaders.keys - live) loaders.remove(id)?.close()
        val model = (loaders[top.id]?.phase as? OrcaPageLoader.Phase.Loaded)?.model
        if (model != null && model.store.state.app != appState) model.store.commit(model.store.state.copy(app = appState))

        val location = top.location
        if (location == shownLocation) return
        val previous = shownLocation
        shownLocation = location
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
            else -> return false
        }
        return true
    }
}

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
