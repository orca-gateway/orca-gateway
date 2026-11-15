package com.orcagateway.sdk

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.client.current
import com.orcagateway.sdk.navigation.OrcaRoute
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.system.SystemActions
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * Loads one page through [OrcaClient] and keeps the result (Swift
 * `OrcaPageLoader`). The first load fills the client's device headers from
 * this device when the client was built with the default [DeviceInfo].
 * Under a [router] the fetch carries the shared app state, and the page
 * joins the router. Use it from the main thread; [phase] is Compose state.
 * With DevTools on, a loaded page sends its `timing` once, on its first frame.
 *
 * A load cancelled mid-fetch (its page left the screen) leaves [phase] at
 * `Loading` and runs again on the next [loadIfNeeded]. After [close] it
 * builds no page: a fetch that lands then is dropped.
 */
public class OrcaPageLoader(
    public val client: OrcaClient,
    public val path: String,
    private val router: OrcaRouter? = null,
) : AutoCloseable {
    /** Where the load stands. */
    public sealed interface Phase {
        public data object Loading : Phase

        public class Loaded(public val model: OrcaPageModel) : Phase

        public data class Failed(public val message: String) : Phase
    }

    public var phase: Phase by mutableStateOf(Phase.Loading)
        private set

    private var started = false
    private var closed = false

    /** Fetch once; [reload] fetches again. */
    public suspend fun loadIfNeeded(context: Context) {
        if (started) return
        reload(context)
    }

    public suspend fun reload(context: Context) {
        started = true
        (phase as? Phase.Loaded)?.model?.close()
        phase = Phase.Loading
        val client = if (client.device == DeviceInfo()) client.copy(device = DeviceInfo.current(context)) else client
        val app = router?.appState ?: emptyMap()
        phase = try {
            val (page, timing) = client.fetchPageTimed(path, app)
            if (closed) return
            val renderStart = timing.elapsed()
            val model = OrcaPageModel(page, store = ElmStore(StoreState(app = app)), client = client)
            router?.attach(model)
            val renderComplete = timing.elapsed()
            // The DevTools `timing` event waits for the first frame.
            model.onFirstAppear = {
                OrcaDebug.report { timing.event(page.pageId, path, renderStart, renderComplete, firstFrameMs = timing.elapsed()) }
            }
            Phase.Loaded(model)
        } catch (e: CancellationException) {
            started = false
            throw e
        } catch (e: OrcaClientException.Http) {
            Phase.Failed("HTTP ${e.status}: ${e.body.take(200)}")
        } catch (e: Exception) {
            Phase.Failed(e.message ?: e.toString())
        }
    }

    /** Cancel the loaded page's running actions, and drop a fetch still running. */
    override fun close() {
        closed = true
        (phase as? Phase.Loaded)?.model?.close()
    }
}

/**
 * Boots an app from the server's navigation config (Flutter `OrcaApp`'s
 * online start): `GET /config` once, then an [OrcaRouter] for it, which
 * seeds `initialAppState` and shows `initialRoute`. The fetch fills the
 * client's device headers from this device when the client was built with
 * the default [DeviceInfo], as [OrcaPageLoader] does. Use it from the main
 * thread; [phase] is Compose state.
 *
 * A boot cancelled mid-fetch leaves [phase] at `Loading` and runs again on
 * the next [loadIfNeeded]. After [close] it builds no router: a config that
 * lands then is dropped.
 */
public class OrcaAppBoot(
    public val client: OrcaClient,
    private val system: SystemActions? = null,
    private val onRouteChanged: ((RouteChangeEvent) -> Unit)? = null,
) : AutoCloseable {
    /** Where the boot stands. */
    public sealed interface Phase {
        public data object Loading : Phase

        public class Ready(public val router: OrcaRouter) : Phase

        public data class Failed(public val message: String) : Phase
    }

    public var phase: Phase by mutableStateOf(Phase.Loading)
        private set

    private var started = false
    private var closed = false

    /** Fetch the config once; [reload] fetches it again. */
    public suspend fun loadIfNeeded(context: Context) {
        if (started) return
        reload(context)
    }

    /** Fetch the config and start again from it, with a new router. */
    public suspend fun reload(context: Context) {
        started = true
        (phase as? Phase.Ready)?.router?.close()
        phase = Phase.Loading
        val client = if (client.device == DeviceInfo()) client.copy(device = DeviceInfo.current(context)) else client
        phase = try {
            val config = client.fetchConfig()
            if (closed) return
            Phase.Ready(OrcaRouter(client, config, system, onRouteChanged))
        } catch (e: CancellationException) {
            started = false
            throw e
        } catch (e: OrcaClientException.Http) {
            Phase.Failed("HTTP ${e.status}: ${e.body.take(200)}")
        } catch (e: Exception) {
            Phase.Failed(e.message ?: e.toString())
        }
    }

    /** Close the router this boot made, and drop a fetch still running. */
    override fun close() {
        closed = true
        (phase as? Phase.Ready)?.router?.close()
    }
}

/**
 * The root of an Orca-driven app: a [NavHost] of server pages, each with its
 * loading and error states. `navigate` pushes a page, `goBack` and the
 * system back gesture pop one, and app state is shared by every page on the
 * stack (see [OrcaRouter]).
 *
 *     OrcaApp(OrcaClient(URI("https://api.example.com"), appId = "counter", transport = OkHttpTransport()))
 *
 * By default the app starts at the page `home`, and so does any [path] the
 * host gives: no config is fetched and every path is a page.
 *
 * `path = null` is the way to get the server's navigation (routes,
 * redirects, initial app state): the app boots from the server's navigation
 * config ([OrcaAppBoot]):
 *
 *     OrcaApp(client, path = null)
 *
 * a spinner while `/config` is fetched (once), then the config's
 * `initialRoute` with its `initialAppState`, every location going through
 * the config's routes; a failed fetch shows an error with a retry. Tabs and
 * the drawer of a config are not drawn yet: the app runs as one stack.
 *
 * [onRouteChanged] is called once per change of the location on top (see
 * [OrcaRouter.onRouteChanged]); the one given at the first composition is
 * kept.
 *
 * Snackbars and toasts are handled by the page; `openUrl`, the clipboard and
 * share go to [system], by default the device's own ([SystemActions.android]).
 * The router is made once, like Swift's `StateObject`, and closed with this
 * composition: a new activity starts again at [path], or boots again.
 */
@Composable
public fun OrcaApp(
    client: OrcaClient,
    modifier: Modifier = Modifier,
    path: String? = "home",
    system: SystemActions? = null,
    onRouteChanged: ((RouteChangeEvent) -> Unit)? = null,
) {
    if (path != null) {
        val router = remember { OrcaRouter(client, path, system).also { it.onRouteChanged = onRouteChanged } }
        DisposableEffect(router) { onDispose { router.close() } }
        OrcaApp(router, modifier)
        return
    }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val boot = remember { OrcaAppBoot(client, system, onRouteChanged) }
    DisposableEffect(boot) { onDispose { boot.close() } }
    LaunchedEffect(boot) { boot.loadIfNeeded(context) }
    when (val phase = boot.phase) {
        OrcaAppBoot.Phase.Loading -> LoadingView(modifier)
        is OrcaAppBoot.Phase.Ready -> OrcaApp(phase.router, modifier)
        is OrcaAppBoot.Phase.Failed -> ErrorView("Could not load this app", phase.message, modifier) {
            scope.launch { boot.reload(context) }
        }
    }
}

/**
 * [OrcaApp] over a router the host made and keeps (Swift
 * `OrcaApp(router:)`), to read or drive the stack itself. It is not closed
 * here. A router built with its own [OrcaRouter.system] keeps it; one built
 * without gets the device's own ([SystemActions.android]) while it is shown
 * here, and loses them again when this leaves, so it never holds on to the
 * activity.
 *
 * The router is the one source of truth: the system back gesture pops the
 * router, and the [NavHost] follows the router's stack.
 */
@Composable
public fun OrcaApp(router: OrcaRouter, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    DisposableEffect(router, context) {
        val filled = if (router.system == null) SystemActions.android(context) else null
        if (filled != null) router.system = filled
        // Only the ones set here: a host may have set its own since.
        onDispose { if (filled != null && router.system === filled) router.system = null }
    }
    val navController = rememberNavController()
    NavHost(navController, startDestination = ROOT_ROUTE, modifier = modifier) {
        composable(ROOT_ROUTE) {
            val root = router.root
            key(root.id) { RoutePage(router, root, if (root.isNotFound) null else router.loader(root)) }
        }
        composable(PAGE_ROUTE) { entry ->
            val id = entry.arguments?.getString(ROUTE_ID)
            // Kept while a popped page leaves the screen, after the router dropped it.
            // A not-found route has no loader: nothing is requested for it.
            val shown = remember(id) {
                router.stack.firstOrNull { it.id.toString() == id }
                    ?.let { route -> route to if (route.isNotFound) null else router.loader(route) }
            }
            if (shown != null) RoutePage(router, shown.first, shown.second)
        }
    }
    // After the NavHost, so it is asked before the NavHost's own back handling.
    BackHandler(enabled = router.stack.isNotEmpty()) { router.goBack() }
    LaunchedEffect(router, navController) {
        // Pages a restored NavHost still shows belong to no route here.
        navController.popBackStack(ROOT_ROUTE, inclusive = false)
        var shown = emptyList<OrcaRoute>()
        snapshotFlow { router.stack }.collect { stack ->
            navController.follow(shown, stack)
            shown = stack
        }
    }
}

/** Pop the pages [shown] has beyond what it shares with [stack], then push the rest of [stack]. */
private fun NavHostController.follow(shown: List<OrcaRoute>, stack: List<OrcaRoute>) {
    var same = 0
    while (same < shown.size && same < stack.size && shown[same] === stack[same]) same++
    repeat(shown.size - same) { popBackStack() }
    for (route in stack.drop(same)) navigate("orca/page/${route.id}")
}

/**
 * One route's page: the "page not found" screen for a route without a
 * [loader], else a spinner, the page, or the error with a retry. A route
 * with a fallback title is drawn under a top bar: the page's own title once
 * it loaded, and a back arrow while the router has a page to pop. A page
 * whose root is a Scaffold with an AppBar draws that one below, as Flutter
 * shows both.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RoutePage(router: OrcaRouter, route: OrcaRoute, loader: OrcaPageLoader?) {
    val fallback = route.scaffoldTitle
    if (fallback == null) {
        RouteBody(route, loader)
        return
    }
    val title = (loader?.phase as? OrcaPageLoader.Phase.Loaded)?.model?.page?.title ?: fallback
    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(title, Modifier.testTag(ORCA_ROUTE_TITLE_TAG)) },
            navigationIcon = {
                if (router.stack.isNotEmpty()) {
                    IconButton(onClick = { router.goBack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            },
        )
        Box(Modifier.weight(1f)) { RouteBody(route, loader) }
    }
}

/** What a route shows under its bar, if it has one. */
@Composable
private fun RouteBody(route: OrcaRoute, loader: OrcaPageLoader?) {
    if (loader == null) {
        NotFoundView(route.location)
        return
    }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    LaunchedEffect(loader) { loader.loadIfNeeded(context) }

    when (val phase = loader.phase) {
        OrcaPageLoader.Phase.Loading -> LoadingView()
        is OrcaPageLoader.Phase.Loaded -> OrcaPageView(phase.model)
        is OrcaPageLoader.Phase.Failed -> ErrorView("Could not load this page", phase.message) {
            scope.launch { loader.reload(context) }
        }
    }
}

@Composable
private fun LoadingView(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

/** What went wrong, and a "Try again". */
@Composable
private fun ErrorView(title: String, message: String, modifier: Modifier = Modifier, onRetry: () -> Unit) {
    Column(
        modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        TextButton(onClick = onRetry) { Text("Try again") }
    }
}

/** The page of a location no route matches. */
@Composable
private fun NotFoundView(location: String) {
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Page not found", style = MaterialTheme.typography.titleMedium)
        Text(
            location,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

/** The test tag of the title in a route's top bar. */
internal const val ORCA_ROUTE_TITLE_TAG: String = "orca-route-title"

private const val ROOT_ROUTE = "orca/root"
private const val ROUTE_ID = "id"
private const val PAGE_ROUTE = "orca/page/{$ROUTE_ID}"
