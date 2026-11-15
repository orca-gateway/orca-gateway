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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.currentCompositeKeyHashCode
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
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
import com.orcagateway.sdk.navigation.LocalOrcaNavigation
import com.orcagateway.sdk.navigation.OrcaNavigation
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
 * [OrcaRouter.onRouteChanged]); the current one is used, set on the router
 * only while shown, so a router kept through a rotation holds no old activity's.
 *
 * Snackbars and toasts are handled by the page; `openUrl`, the clipboard and
 * share go to [system], by default the device's own ([SystemActions.android]).
 *
 * With a [path], the router is made once, like Swift's `StateObject`, and
 * kept in the activity's `ViewModelStore` (one per call site): an activity
 * recreated by a rotation shows the same pages, with their state, and the
 * router is closed when the activity finishes. It never holds the activity:
 * [system] and [onRouteChanged] are the router's only while this composition
 * shows it. The boot of `path = null` is closed with this composition: a new
 * activity boots again. A [client] without a device id gets the one saved in
 * SharedPreferences (`DeviceIdentity`, [SharedPreferencesKeyValueStore]),
 * made on first run, as Flutter does whether or not sessions are tracked;
 * `/config` is asked with it too.
 *
 * @param enableOffline runs the version check at boot, before anything else
 * is asked: a forceUpdate answer shows the force-update screen and neither
 * the config nor a page is fetched. The static-flow cache, saved config and
 * `preload()` arrive with plan step 14.
 * @param enableSessionTracking posts a session start when the app comes to
 * the foreground and an end when it leaves, queued offline when unsent.
 */
@Composable
public fun OrcaApp(
    client: OrcaClient,
    modifier: Modifier = Modifier,
    path: String? = "home",
    system: SystemActions? = null,
    onRouteChanged: ((RouteChangeEvent) -> Unit)? = null,
    enableOffline: Boolean = false,
    enableSessionTracking: Boolean = false,
) {
    val context = LocalContext.current
    val identified = remember { client.identified(SharedPreferencesKeyValueStore(context)) }
    // Keyed by the call site: two OrcaApps in one activity keep a router each.
    val site = currentCompositeKeyHashCode.toString(36)
    if (path != null) {
        val retained = viewModel(key = "com.orcagateway.sdk.OrcaApp:$site") { RetainedRouter(OrcaRouter(identified, path)) }
        val router = retained.router
        AttachHost(router, system, onRouteChanged)
        OrcaApp(router, modifier, enableOffline, enableSessionTracking)
        return
    }
    // The version check comes first: the config is asked only once the app may run.
    OrcaBootView(identified, enableOffline, enableSessionTracking, modifier) {
        val scope = rememberCoroutineScope()
        val boot = remember { OrcaAppBoot(identified, system, onRouteChanged) }
        DisposableEffect(boot) { onDispose { boot.close() } }
        LaunchedEffect(boot) { boot.loadIfNeeded(context) }
        when (val phase = boot.phase) {
            OrcaAppBoot.Phase.Loading -> LoadingView(modifier)
            is OrcaAppBoot.Phase.Ready -> OrcaNavHost(phase.router, modifier)
            is OrcaAppBoot.Phase.Failed -> ErrorView("Could not load this app", phase.message, modifier) {
                scope.launch { boot.reload(context) }
            }
        }
    }
}

/**
 * While shown, the host's latest [system] and [onRouteChanged] are the
 * router's (OrcaApp(client) keeps the router, not the activity they belong to).
 */
@Composable
private fun AttachHost(router: OrcaRouter, system: SystemActions?, onRouteChanged: ((RouteChangeEvent) -> Unit)?) {
    DisposableEffect(router, system) {
        if (system != null) router.system = system
        onDispose { if (system != null && router.system === system) router.system = null }
    }
    DisposableEffect(router, onRouteChanged) {
        router.onRouteChanged = onRouteChanged
        onDispose { if (router.onRouteChanged === onRouteChanged) router.onRouteChanged = null }
    }
}

/** OrcaApp(client)'s router through configuration changes; closed when the activity finishes. */
internal class RetainedRouter(val router: OrcaRouter) : ViewModel() {
    override fun onCleared() {
        router.close()
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
 * router, and the [NavHost] follows the router's stack. After the activity is
 * recreated (a rotation) the [NavHost] keeps the entries it restored that are
 * still on the router's stack, so the page on screen stays as it was.
 *
 * Each page is told whether it can pop (it is a pushed page, not the root)
 * and how to go back, for the AppBar's back arrow ([LocalOrcaNavigation]).
 *
 * The router's client is used as the host built it: to send the device id
 * OrcaApp(client) gives, build the client with
 * `deviceId = DeviceIdentity.resolve(SharedPreferencesKeyValueStore(context))`.
 * [enableOffline] and [enableSessionTracking] are those of OrcaApp(client).
 */
@Composable
public fun OrcaApp(
    router: OrcaRouter,
    modifier: Modifier = Modifier,
    enableOffline: Boolean = false,
    enableSessionTracking: Boolean = false,
) {
    OrcaBootView(router.client, enableOffline, enableSessionTracking, modifier) { OrcaNavHost(router, modifier) }
}

/** The router's pages on a [NavHost], once the boot let the app run. */
@Composable
private fun OrcaNavHost(router: OrcaRouter, modifier: Modifier) {
    val context = LocalContext.current
    DisposableEffect(router, context) {
        val filled = if (router.system == null) SystemActions.android(context) else null
        if (filled != null) router.system = filled
        // Only the ones set here: a host may have set its own since.
        onDispose { if (filled != null && router.system === filled) router.system = null }
    }
    val navController = rememberNavController()
    // The route ids of the pages pushed on the NavController, saved with it:
    // its own back stack is not public API.
    val shown = rememberSaveable { mutableStateOf(emptyList<String>()) }
    val atRoot = remember(router) { OrcaNavigation(router, canPop = false) }
    val pushed = remember(router) { OrcaNavigation(router, canPop = true) }
    NavHost(navController, startDestination = ROOT_ROUTE, modifier = modifier) {
        composable(ROOT_ROUTE) {
            val root = router.root
            CompositionLocalProvider(LocalOrcaNavigation provides atRoot) {
                key(root.id) { RoutePage(router, root, if (root.isNotFound) null else router.loader(root)) }
            }
        }
        composable(PAGE_ROUTE) { entry ->
            val id = entry.arguments?.getString(ROUTE_ID)
            // Kept while a popped page leaves the screen, after the router dropped it.
            // A not-found route has no loader: nothing is requested for it.
            val page = remember(id) {
                router.stack.firstOrNull { it.id.toString() == id }
                    ?.let { route -> route to if (route.isNotFound) null else router.loader(route) }
            }
            if (page != null) {
                CompositionLocalProvider(LocalOrcaNavigation provides pushed) { RoutePage(router, page.first, page.second) }
            }
        }
    }
    // After the NavHost, so it is asked before the NavHost's own back handling.
    BackHandler(enabled = router.stack.isNotEmpty()) { router.goBack() }
    LaunchedEffect(router, navController) {
        snapshotFlow { router.stack }.collect { stack ->
            navController.follow(shown.value, stack)
            shown.value = stack.map { it.id.toString() }
        }
    }
}

/**
 * Bring the NavController from the pages it shows ([shown], route ids) to
 * [stack]: keep the ones the two share from the bottom, pop the rest, push
 * what is missing. After a recreation the restored entries that are still on
 * the stack stay, so a rotation pops and pushes nothing.
 */
private fun NavHostController.follow(shown: List<String>, stack: List<OrcaRoute>) {
    var same = 0
    while (same < shown.size && same < stack.size && shown[same] == stack[same].id.toString()) same++
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
