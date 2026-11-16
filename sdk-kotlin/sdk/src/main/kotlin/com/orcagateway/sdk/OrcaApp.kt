package com.orcagateway.sdk

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.util.Log
import androidx.activity.ComponentActivity
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
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.util.Consumer
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
import com.orcagateway.core.navigation.DeeplinkEvent
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.client.current
import com.orcagateway.sdk.debug.PageDebugOverlay
import com.orcagateway.sdk.navigation.LocalOrcaNavigation
import com.orcagateway.sdk.navigation.OrcaNavigation
import com.orcagateway.sdk.navigation.OrcaRoute
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.navigation.TabShellScreen
import com.orcagateway.sdk.navigation.deeplink
import com.orcagateway.sdk.system.SystemActions
import com.orcagateway.sdk.widgets.LocalOrcaPageDrawerHost
import com.orcagateway.sdk.widgets.PageDrawerHost
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * Loads one page through [OrcaClient] and keeps the result (Swift
 * `OrcaPageLoader`). The first load fills the client's device headers from
 * this device when the client was built with the default [DeviceInfo].
 * Under a [router] the fetch carries the shared app state, and the page
 * joins the router, with the plugins, custom actions and host widgets its
 * OrcaApp was given. Use it from the main thread; [phase] is Compose state.
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

        public class Loaded(public val model: OrcaPageModel) : Phase {
            /** Request start to render complete, in ms (the `timing` event's), for the debug overlay. */
            internal var renderCompleteMs: Double? = null
        }

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
            val plugins = router?.plugins
            val registry = plugins?.registry ?: WidgetRegistry.shared
            val model = OrcaPageModel(page, store = ElmStore(StoreState(app = app)), registry = registry, client = client)
            plugins?.install(model)
            router?.attach(model)
            val renderComplete = timing.elapsed()
            // The DevTools `timing` event waits for the first frame; logTimings also
            // writes Flutter's line (orca_debug.dart reportTiming).
            model.onFirstAppear = {
                if (OrcaDebug.isEnabled) {
                    OrcaDebug.report { timing.event(page.pageId, path, renderStart, renderComplete, firstFrameMs = timing.elapsed()) }
                    if (OrcaDebug.options.logTimings) Log.i(WidgetBuilders.LOG_TAG, "[OrcaDebug] Timing: ${page.pageId} - $path")
                }
            }
            Phase.Loaded(model).also { it.renderCompleteMs = renderComplete }
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
 *
 * [system] and [onRouteChanged] go to the router a load makes. OrcaApp keeps
 * a boot through a rotation and sets them to the shown activity's own.
 *
 * A deep link given before the router exists ([handleDeeplink]) is what
 * opens the app: the router starts at the link instead of `initialRoute`.
 */
public class OrcaAppBoot(
    public val client: OrcaClient,
    internal var system: SystemActions? = null,
    internal var onRouteChanged: ((RouteChangeEvent) -> Unit)? = null,
) : AutoCloseable {
    /** Where the boot stands. */
    public sealed interface Phase {
        public data object Loading : Phase

        public class Ready(public val router: OrcaRouter) : Phase

        public data class Failed(public val message: String) : Phase
    }

    public var phase: Phase by mutableStateOf(Phase.Loading)
        private set

    /** What OrcaApp's plugins give each router made here; OrcaApp sets it before the config is fetched. */
    internal var plugins: OrcaPluginHost? = null

    private var started = false
    private var closed = false

    // The link that arrived before there was a router; the next router starts at it.
    private var pendingLink: String? = null

    /**
     * Open a deep link ([OrcaRouter.handleDeeplink]). With a router, it goes
     * there. Before (the config is being fetched, or the fetch failed and
     * may be retried) the link is held, the last one given, and the router
     * then starts at it: `initialAppState` seeded, the redirect applied, one
     * page request, and the link's event says `isColdStart`.
     */
    public fun handleDeeplink(link: String) {
        val router = (phase as? Phase.Ready)?.router
        if (router != null) router.handleDeeplink(link) else pendingLink = link
    }

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
            val link = pendingLink
            pendingLink = null
            Phase.Ready(OrcaRouter(client, config, system, onRouteChanged, link).also { it.plugins = plugins })
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
 * By default, with no [path], the app boots from the server's navigation
 * config ([OrcaAppBoot]), as Flutter's `OrcaApp` does, and so gets the
 * server's navigation (routes, redirects, initial app state): a spinner
 * while `/config` is fetched (once), then the config's `initialRoute` with
 * its `initialAppState`, every location going through the config's routes;
 * a failed fetch shows an error with a retry. A config with tabs is drawn as
 * a tab shell ([TabShellScreen]): a bottom bar, and one stack per tab.
 *
 * A [path] the host gives opens that one page instead: no config is fetched
 * and every path is a page.
 *
 *     OrcaApp(client, path = "home")
 *
 * [onRouteChanged] is called once per change of the location on top (see
 * [OrcaRouter.onRouteChanged]); the current one is used, set on the router
 * only while shown, so a router kept through a rotation holds no old activity's.
 *
 * Snackbars and toasts are handled by the page; `openUrl`, the clipboard and
 * share go to [system], by default the device's own ([SystemActions.android]).
 *
 * Deep links need no host code: inside a `ComponentActivity`, the link of
 * the Intent that launched it (the data of an `ACTION_VIEW`) opens the app
 * AT the link (instead of `initialRoute`, or of [path]), and the link of
 * every new Intent (`android:launchMode="singleTop"`) goes there as
 * [OrcaRouter.handleDeeplink] does, also one that arrives while the config is
 * fetched. The launch Intent is read once: not again after a rotation, a
 * restore from saved state, or when OrcaApp leaves the composition and comes
 * back in the same activity. [onDeeplink] is called once per link, after the
 * navigation and after [onRouteChanged], with where the link ended
 * ([DeeplinkEvent]); links navigate without it too. Outside a
 * `ComponentActivity` (a preview) no Intent is read.
 *
 * The router (with `path = null`, the boot and the router it makes) is made
 * once, like Swift's `StateObject`, and kept in the activity's
 * `ViewModelStore` (one per call site): an activity recreated by a rotation
 * shows the same pages, with their state, without asking `/config` again,
 * and it is closed when the activity finishes. It never holds the activity:
 * [system] and [onRouteChanged] are the router's only while this composition
 * shows it. A [client] without a device id gets the one saved in
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
 * @param plugins widgets, actions and triggers that belong together (Dart
 * `OrcaApp.plugins`, sdk/lib/src/widgets/orca_app.dart), merged once
 * (the kept router or boot keeps them through a rotation), before the
 * first request: their widget and action names are advertised in the
 * client's capabilities, their builders draw on every page and their
 * handlers run there. A conflict (two plugins, or a plugin and the
 * SDK, [widgets] or [customActions], with one name) shows the error view
 * with Flutter's message, and nothing is fetched.
 * @param customActions action handlers by type (Dart
 * `OrcaApp.customActions`): an action `{"type":"custom:<name>"}` or
 * `{"type":"<name>"}` runs one; a name like a built-in action's replaces
 * it. Not advertised in the capabilities.
 * @param widgets the builders the pages draw with (Dart `OrcaApp.registry`):
 * by default the SDK's own, else a [WidgetBuilders.standard] with what the
 * host registered on it. Not advertised; the plugins' builders are added
 * to a copy, so this one is not changed.
 */
@Composable
public fun OrcaApp(
    client: OrcaClient,
    modifier: Modifier = Modifier,
    path: String? = null,
    system: SystemActions? = null,
    onRouteChanged: ((RouteChangeEvent) -> Unit)? = null,
    enableOffline: Boolean = false,
    enableSessionTracking: Boolean = false,
    plugins: List<OrcaPlugin> = emptyList(),
    customActions: Map<String, OrcaActionHandler> = emptyMap(),
    widgets: WidgetBuilders = WidgetBuilders.shared,
    onDeeplink: ((DeeplinkEvent) -> Unit)? = null,
) {
    val context = LocalContext.current
    val identified = remember { client.identified(SharedPreferencesKeyValueStore(context)) }
    // Keyed by the call site: two OrcaApps in one activity keep a router (or a boot) each.
    val site = currentCompositeKeyHashCode.toString(36)
    // The link that opened the app, the first time only.
    val launch = launchLink()
    if (path != null) {
        // A router made now starts at the link, so the host's path is never requested.
        val retained = viewModel(key = "com.orcagateway.sdk.OrcaApp:$site") {
            Retained(OrcaRouter(identified, path, system = null, coldLink = launch))
        }
        val router = retained.value
        AttachHost(router, system, onRouteChanged, onDeeplink)
        NewIntentLinks { router.handleDeeplink(it) }
        RouterApp(router, modifier, enableOffline, enableSessionTracking, plugins, customActions, widgets)
        return
    }
    // A boot made now holds the link through the version check and the config fetch. Once per kept
    // boot, as for the path above: an OrcaApp that left the composition and came back reads the
    // launch Intent again, and that is not a new link.
    val retained = viewModel(key = "com.orcagateway.sdk.OrcaAppBoot:$site") {
        Retained(OrcaAppBoot(identified).also { boot -> launch?.let(boot::handleDeeplink) })
    }
    val boot = retained.value
    NewIntentLinks { boot.handleDeeplink(it) }
    // The plugins are merged first, so the config is asked with their names; once per kept boot.
    val prepare = {
        if (boot.plugins == null) boot.plugins = OrcaPluginHost.merge(boot.client, plugins, customActions, widgets)
    }
    // The version check comes first: the config is asked only once the app may run.
    OrcaBootView(identified, enableOffline, enableSessionTracking, modifier, prepare) {
        val scope = rememberCoroutineScope()
        // Before the load starts, so the router it makes gets them.
        DisposableEffect(boot, system, onRouteChanged) {
            boot.system = system
            boot.onRouteChanged = onRouteChanged
            onDispose {
                if (boot.system === system) boot.system = null
                if (boot.onRouteChanged === onRouteChanged) boot.onRouteChanged = null
            }
        }
        LaunchedEffect(boot) { boot.loadIfNeeded(context) }
        when (val phase = boot.phase) {
            OrcaAppBoot.Phase.Loading -> LoadingView(modifier)
            is OrcaAppBoot.Phase.Ready -> {
                AttachHost(phase.router, system, onRouteChanged, onDeeplink)
                OrcaNavHost(phase.router, modifier)
            }
            is OrcaAppBoot.Phase.Failed -> ErrorView("Could not load this app", phase.message, modifier) {
                scope.launch { boot.reload(context) }
            }
        }
    }
}

/**
 * While shown, the host's latest [system], [onRouteChanged] and [onDeeplink]
 * are the router's (OrcaApp(client) keeps the router, not the activity they
 * belong to). The link that opened the app is reported here, once.
 */
@Composable
private fun AttachHost(
    router: OrcaRouter,
    system: SystemActions?,
    onRouteChanged: ((RouteChangeEvent) -> Unit)?,
    onDeeplink: ((DeeplinkEvent) -> Unit)?,
) {
    DisposableEffect(router, system) {
        if (system != null) router.system = system
        onDispose { if (system != null && router.system === system) router.system = null }
    }
    DisposableEffect(router, onRouteChanged) {
        router.onRouteChanged = onRouteChanged
        onDispose { if (router.onRouteChanged === onRouteChanged) router.onRouteChanged = null }
    }
    DisposableEffect(router, onDeeplink) {
        router.onDeeplink = onDeeplink
        router.deliverColdLink()
        onDispose { if (router.onDeeplink === onDeeplink) router.onDeeplink = null }
    }
}

/** The `ComponentActivity` this context is, or wraps; null in a preview. */
private tailrec fun Context.componentActivity(): ComponentActivity? = when (this) {
    is ComponentActivity -> this
    is ContextWrapper -> baseContext.componentActivity()
    else -> null
}

/**
 * The deep link of the Intent that launched the hosting activity, the first
 * time this is composed, else null. That it was read is saved with the
 * activity's state, so neither a recreation (a rotation) nor a restore after
 * the process died reads it again; an activity brought back from the recents
 * list carries its old Intent, which is not a new link either.
 *
 * What is saved lasts only while this stays in the composition: composed
 * again in the same activity, it returns the link again. A caller gives it
 * only to what it makes once per activity (the kept router or boot).
 */
@Composable
private fun launchLink(): String? {
    val activity = LocalContext.current.componentActivity()
    // Not Compose state: it is written while composing, and nothing draws from it.
    val read = rememberSaveable { booleanArrayOf(false) }
    if (activity == null || read[0]) return null
    read[0] = true
    val intent = activity.intent ?: return null
    if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
    return intent.deeplink()
}

/** While shown, the deep link of every new Intent of the hosting activity goes to [onLink]. */
@Composable
private fun NewIntentLinks(onLink: (String) -> Unit) {
    val activity = LocalContext.current.componentActivity() ?: return
    val current by rememberUpdatedState(onLink)
    DisposableEffect(activity) {
        val listener = Consumer<Intent> { intent -> intent.deeplink()?.let { current(it) } }
        activity.addOnNewIntentListener(listener)
        onDispose { activity.removeOnNewIntentListener(listener) }
    }
}

/** OrcaApp(client)'s router or boot through configuration changes; [value] is closed when the activity finishes. */
internal class Retained<T : AutoCloseable>(val value: T) : ViewModel(value)

/**
 * [OrcaApp] over a router the host made and keeps (Swift
 * `OrcaApp(router:)`), to read or drive the stack itself. It is not closed
 * here. A router built with its own [OrcaRouter.system] keeps it; one built
 * without gets the device's own ([SystemActions.android]) while it is shown
 * here, and loses them again when this leaves, so it never holds on to the
 * activity.
 *
 * The router is the one source of truth: the system back gesture pops the
 * router, and the [NavHost] follows the router's stack. While the router
 * has a tab shell ([OrcaRouter.hasShell]) the [TabShellScreen] is drawn
 * instead. After the activity is recreated (a rotation) the [NavHost] keeps
 * the entries it restored that are still on the router's stack, so the page
 * on screen stays as it was.
 *
 * Each page is told whether it can pop (it is a pushed page, not the root)
 * and how to go back, for the AppBar's back arrow ([LocalOrcaNavigation]).
 *
 * The router's client is used as the host built it: to send the device id
 * OrcaApp(client) gives, build the client with
 * `deviceId = DeviceIdentity.resolve(SharedPreferencesKeyValueStore(context))`.
 * [enableOffline], [enableSessionTracking], [plugins], [customActions] and
 * [widgets] are those of OrcaApp(client) (Dart `OrcaApp.plugins`,
 * `customActions` and `registry`, sdk/lib/src/widgets/orca_app.dart): the
 * router's pages get them, and a plugin conflict shows the error view with
 * Flutter's message and fetches nothing. They are merged once per router,
 * by the first OrcaApp that shows it.
 *
 * Deep links are handled as by OrcaApp(client), and reported to the
 * router's own [OrcaRouter.onDeeplink]: the launch Intent's link once, as a
 * cold start, before the first page is drawn (so the page the router stood
 * on is not requested), and every new Intent's link. The router remembers
 * that it took the launch link, so hiding and showing this in the same
 * activity does not handle it again.
 */
@Composable
public fun OrcaApp(
    router: OrcaRouter,
    modifier: Modifier = Modifier,
    enableOffline: Boolean = false,
    enableSessionTracking: Boolean = false,
    plugins: List<OrcaPlugin> = emptyList(),
    customActions: Map<String, OrcaActionHandler> = emptyMap(),
    widgets: WidgetBuilders = WidgetBuilders.shared,
) {
    // launchLink() gives the link again when this is composed again in the same activity; the router knows it took it.
    val first = launchLink().takeUnless { router.launchLinkTaken }
    var launch by remember { mutableStateOf(first) }
    NewIntentLinks { router.handleDeeplink(it) }
    val link = launch
    if (link != null) {
        // In an effect, not while composing: the host's callbacks run. Nothing is drawn before it.
        DisposableEffect(router) {
            router.launchLinkTaken = true
            router.handleDeeplink(link, isColdStart = true)
            launch = null
            onDispose {}
        }
        return
    }
    RouterApp(router, modifier, enableOffline, enableSessionTracking, plugins, customActions, widgets)
}

/** A router's pages behind the boot gate, with the plugins merged: what both OrcaApps draw. */
@Composable
private fun RouterApp(
    router: OrcaRouter,
    modifier: Modifier,
    enableOffline: Boolean,
    enableSessionTracking: Boolean,
    plugins: List<OrcaPlugin>,
    customActions: Map<String, OrcaActionHandler>,
    widgets: WidgetBuilders,
) {
    // Once per router: one kept through a rotation keeps what it was given.
    val prepare = {
        if (router.plugins == null) router.plugins = OrcaPluginHost.merge(router.client, plugins, customActions, widgets)
    }
    OrcaBootView(router.client, enableOffline, enableSessionTracking, modifier, prepare) { OrcaNavHost(router, modifier) }
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
    if (router.hasShell) {
        TabShellScreen(router, modifier)
    } else {
        StackScreen(router, modifier)
    }
}

/** The router as one stack, on a [NavHost]: a config without tabs, a host path, a route shown outside the tabs. */
@Composable
private fun StackScreen(router: OrcaRouter, modifier: Modifier) {
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
 * shows both. The page's Scaffold can reach the router, to open its drawer
 * when the router asks this route to ([OrcaRouter.pageDrawerRequest]).
 */
@Composable
internal fun RoutePage(router: OrcaRouter, route: OrcaRoute, loader: OrcaPageLoader?) {
    val drawers = remember(router, route.id) { PageDrawerHost(router, route.id) }
    CompositionLocalProvider(LocalOrcaPageDrawerHost provides drawers) { RouteFrame(router, route, loader) }
}

/** A route's page, under the title bar of a route that has a fallback title. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RouteFrame(router: OrcaRouter, route: OrcaRoute, loader: OrcaPageLoader?) {
    val fallback = route.scaffoldTitle
    if (fallback == null) {
        RouteBody(router, route, loader)
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
        Box(Modifier.weight(1f)) { RouteBody(router, route, loader) }
    }
}

/** What a route shows under its bar, if it has one. */
@Composable
private fun RouteBody(router: OrcaRouter, route: OrcaRoute, loader: OrcaPageLoader?) {
    if (loader == null) {
        // Flutter's default not-found screen: its button is a `go` to "/".
        NotFoundView(route.location) { router.navigate("/", replace = true) }
        return
    }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    LaunchedEffect(loader) { loader.loadIfNeeded(context) }

    when (val phase = loader.phase) {
        OrcaPageLoader.Phase.Loading -> LoadingView()
        is OrcaPageLoader.Phase.Loaded -> Box {
            OrcaPageView(phase.model)
            PageDebugOverlay(phase.model, phase.renderCompleteMs, Modifier.align(AbsoluteAlignment.BottomRight))
        }
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

/** The SDK's error view: what went wrong, and a "Try again" when there is an [onRetry]. */
@Composable
internal fun ErrorView(title: String, message: String, modifier: Modifier = Modifier, onRetry: (() -> Unit)? = null) {
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
        if (onRetry != null) TextButton(onClick = onRetry) { Text("Try again") }
    }
}

/** The page of a location no route matches, with a way out: [onHome]. */
@Composable
private fun NotFoundView(location: String, onHome: () -> Unit) {
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
        TextButton(onClick = onHome) { Text("Go to home page") }
    }
}

/** The test tag of the title in a route's top bar. */
internal const val ORCA_ROUTE_TITLE_TAG: String = "orca-route-title"

private const val ROOT_ROUTE = "orca/root"
private const val ROUTE_ID = "id"
private const val PAGE_ROUTE = "orca/page/{$ROUTE_ID}"
