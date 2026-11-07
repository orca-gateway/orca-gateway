package com.orcagateway.sdk.navigation

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.system.SystemActions
import java.util.UUID

/**
 * One page on the navigation stack: a server path such as `home` or
 * `product`. Each push is a new route, so the same path twice is two pages.
 */
public class OrcaRoute(path: String) {
    public val id: UUID = UUID.randomUUID()

    // Routes arrive as "about" or "/about"; the page URL wants no slash.
    public val path: String = path.trimStart('/')

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
 * [OrcaApp][com.orcagateway.sdk.OrcaApp] draws it on a `NavHost` that
 * follows [root] and [stack] (Compose state). Use it from the main thread.
 *
 * [system] performs `openUrl`, `copyToClipboard` and `share`; without one
 * they are only reported to [onEffect]. While `OrcaApp` shows a router that
 * has none, it sets the device's own ([SystemActions.android]) and takes
 * them away again when it leaves.
 */
public class OrcaRouter(
    public val client: OrcaClient,
    path: String = "home",
    public var system: SystemActions? = null,
) : AutoCloseable {
    /** The page under every pushed route. */
    public var root: OrcaRoute by mutableStateOf(OrcaRoute(path))
        private set

    private var routes by mutableStateOf(emptyList<OrcaRoute>())

    /** Pushed routes, bottom to top: the pages the `NavHost` shows over [root]. */
    public var stack: List<OrcaRoute>
        get() = routes
        set(value) {
            routes = value
            routesChanged()
        }

    /** The shared app scope, as the latest page left it. */
    public var appState: Map<String, JsonValue> = emptyMap()
        private set

    /** Called with every effect a page reports, for DevTools and logging. */
    public var onEffect: ((ActionEffect) -> Unit)? = null

    private val loaders = HashMap<UUID, OrcaPageLoader>()

    /** The loader of a route, made the first time it is asked for. */
    public fun loader(route: OrcaRoute): OrcaPageLoader =
        loaders.getOrPut(route.id) { OrcaPageLoader(client, route.path, router = this) }

    /** The route on top: the one a user is looking at. */
    public val top: OrcaRoute get() = stack.lastOrNull() ?: root

    public fun navigate(path: String, replace: Boolean = false) {
        if (path.isEmpty()) return
        if (replace) {
            root = OrcaRoute(path)
            stack = emptyList()
        } else {
            stack = stack + OrcaRoute(path)
        }
    }

    public fun goBack() {
        if (stack.isEmpty()) return
        stack = stack.dropLast(1)
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
        appState = model.store.state.app
        model.store.onCommit = { state -> appState = state.app }
        model.onEffect = { effect -> onEffect?.invoke(effect) }
        model.effectHandler = { effect -> if (!perform(effect)) system?.perform(effect) }
    }

    /**
     * Drop (and close) loaders of routes that left the stack, and hand the
     * page now on top the latest app scope.
     */
    private fun routesChanged() {
        val live = stack.mapTo(HashSet()) { it.id } + root.id
        for (id in loaders.keys - live) loaders.remove(id)?.close()
        val model = (loaders[top.id]?.phase as? OrcaPageLoader.Phase.Loaded)?.model ?: return
        if (model.store.state.app != appState) model.store.commit(model.store.state.copy(app = appState))
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
