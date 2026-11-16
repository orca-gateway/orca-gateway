package com.orcagateway.sdk

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.res.Configuration
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.util.Consumer
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.orcagateway.core.animation.Curves
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.client.OrcaErrorInfo
import com.orcagateway.core.client.PreloadResult
import com.orcagateway.core.client.StaticFlowManager
import com.orcagateway.core.client.preload
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.navigation.DeeplinkEvent
import com.orcagateway.core.navigation.RouteChangeEvent
import com.orcagateway.core.navigation.TransitionKind
import com.orcagateway.core.navigation.TransitionSpec
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.SavedState
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
import com.orcagateway.sdk.widgets.LocalOrcaHeroStage
import com.orcagateway.sdk.widgets.LocalOrcaPageDrawerHost
import com.orcagateway.sdk.widgets.OrcaHeroStage
import com.orcagateway.sdk.widgets.PageDrawerHost
import com.orcagateway.sdk.widgets.SnackbarLayer
import com.orcagateway.sdk.widgets.orcaReduceMotion
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

/**
 * Loads one page through [OrcaClient] and keeps the result (Swift
 * `OrcaPageLoader`). The first load fills the client's device headers from
 * this device when the client was built with the default [DeviceInfo].
 * Under a [router] the fetch carries the shared app state, and the page
 * joins the router, with the plugins, custom actions and host widgets its
 * OrcaApp was given. Use it from the main thread; [phase] is Compose state.
 * With DevTools on, a loaded page sends its `timing` once, on its first frame.
 * A page's `refetchPage` action fetches it again into the same model, in place.
 *
 * Under a router with an offline cache (OrcaApp's `staticFlowManager`, or
 * `enableOffline`) the page is asked of the cache first, off the main
 * thread, as Flutter's `OrcaPage` does: a static page saved at boot is
 * used with no request and sends no `timing`; any other goes to the
 * network, and what the network answers is never saved.
 *
 * Under a router with a [OrcaRouter.savedState] the page, cached or not, is
 * set up under its saved entry and saves into it ([OrcaPageModel]).
 *
 * A load cancelled mid-fetch (its page left the screen) leaves [phase] at
 * `Loading` and runs again on the next [loadIfNeeded]. After [close] it
 * builds no page: a fetch that lands then is dropped. A failed load keeps
 * what was thrown in [Phase.Failed.error]; [OrcaErrorView] draws it.
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

        /** The load threw [error]: [message] says it as text ("HTTP 404: <body>" for a status). */
        public data class Failed(public val message: String, public val error: Throwable? = null) : Phase
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
        val cache = router?.staticFlowManager
        val flows = router?.flows.orEmpty()
        phase = try {
            // The cache first (Flutter's `OrcaPage._fetchPage`); a hit has no timing to send.
            val cached = cache?.let { withContext(Dispatchers.IO) { it.getCachedPage(path, flows) } }
            val (page, timing) = if (cached != null) cached to null else client.fetchPageTimed(path, app)
            if (closed) return
            val renderStart = timing?.elapsed()
            val plugins = router?.plugins
            val registry = plugins?.registry ?: WidgetRegistry.shared
            val model = OrcaPageModel(
                page, store = ElmStore(StoreState(app = app)), registry = registry, client = client, savedState = router?.savedState,
            )
            // Before the plugins: a custom `refetchPage` overrides it, as in Flutter.
            model.executor.registerHandler("refetchPage") { _, _ -> refetch(model, client) }
            plugins?.install(model)
            router?.attach(model)
            // A cache hit has no timing: no DevTools `timing` event and no load time on the
            // overlay, as Flutter's OrcaPage (its collector is null for a cached page).
            val renderComplete = timing?.elapsed()
            if (timing != null && renderStart != null && renderComplete != null) {
                // The DevTools `timing` event waits for the first frame; logTimings also
                // writes Flutter's line (orca_debug.dart reportTiming).
                model.onFirstAppear = {
                    if (OrcaDebug.isEnabled) {
                        OrcaDebug.report { timing.event(page.pageId, path, renderStart, renderComplete, firstFrameMs = timing.elapsed()) }
                        if (OrcaDebug.options.logTimings) Log.i(WidgetBuilders.LOG_TAG, "[OrcaDebug] Timing: ${page.pageId} - $path")
                    }
                }
            }
            Phase.Loaded(model).also { it.renderCompleteMs = renderComplete }
        } catch (e: CancellationException) {
            started = false
            throw e
        } catch (e: OrcaClientException.Http) {
            Phase.Failed("HTTP ${e.status}: ${e.body.take(200)}", e)
        } catch (e: Exception) {
            Phase.Failed(e.message ?: e.toString(), e)
        }
    }

    /**
     * The `refetchPage` action (Flutter's `onRefetchPage`, orca_page.dart:276-297):
     * fetch [path] again with the app state and show it in place in [model]
     * ([OrcaPageModel.replacePage]). No loading phase and no effect; the
     * action ends once the new tree is in, and a failed fetch throws out of
     * it, the page staying as it was. Not through [reload], whose close
     * would cancel the action awaiting this.
     */
    private suspend fun refetch(model: OrcaPageModel, client: OrcaClient) {
        val page = client.fetchPage(path, router?.appState ?: model.store.state.app)
        model.replacePage(page)
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
 * lands then is dropped. A failed fetch keeps what was thrown in
 * [Phase.Failed.error]; [OrcaErrorView] draws it.
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

        /** The fetch threw [error]: [message] says it as text ("HTTP 500: <body>" for a status). */
        public data class Failed(public val message: String, public val error: Throwable? = null) : Phase
    }

    public var phase: Phase by mutableStateOf(Phase.Loading)
        private set

    /**
     * [preload] said the server demands an update: OrcaApp shows the
     * force-update screen, no router is made and nothing else is fetched.
     * Compose state. Swift twin `updateRequired`.
     */
    internal var updateRequired: Boolean by mutableStateOf(false)
        private set

    /** What OrcaApp's plugins give each router made here; OrcaApp sets it before the config is fetched. */
    internal var plugins: OrcaPluginHost? = null

    /**
     * The offline cache (Dart `OrcaApp.staticFlowManager`); OrcaApp sets it
     * before the boot starts. A router made here asks it for each page
     * first, never for a dynamic route. Null: every page from the network.
     */
    internal var staticFlowManager: StaticFlowManager? = null

    /**
     * With a [staticFlowManager], the boot is Flutter's offline one: [preload]
     * instead of `GET /config`, its file work off the main thread. A
     * forceUpdate answer leaves [phase] at `Loading` and sets
     * [updateRequired]; offline with no saved config, the boot fails with
     * "No network and no cached config available"; a failed `/config` fails
     * it as without. OrcaApp sets it before the boot starts.
     */
    internal var enableOffline: Boolean = false

    /**
     * Where the pages of a router made here save, and what it restores
     * ([OrcaRouter.savedState]); OrcaApp sets it before the boot starts.
     * The offline boot reads its app entry off the main thread, with [preload].
     */
    internal var savedState: SavedState? = null

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

    /**
     * Start from a config the host already has (OrcaApp's `preloadedConfig`):
     * the router at once, with no request. Nothing once the boot started.
     */
    internal fun start(config: NavConfig) {
        if (started) return
        started = true
        phase = Phase.Ready(router(client, config))
    }

    /** Fetch the config (or [preload] it) and start again from it, with a new router. */
    public suspend fun reload(context: Context) {
        started = true
        (phase as? Phase.Ready)?.router?.close()
        phase = Phase.Loading
        val client = if (client.device == DeviceInfo()) client.copy(device = DeviceInfo.current(context)) else client
        val cache = staticFlowManager
        val saved = savedState
        phase = try {
            val result = if (enableOffline && cache != null) {
                withContext(Dispatchers.IO) {
                    // Into a throwaway store: the app entry is then in the mirror the router restores from.
                    saved?.restore(ElmStore())
                    preload(client, cache)
                }
            } else {
                PreloadResult.Success(client.fetchConfig())
            }
            if (closed) return
            when (result) {
                PreloadResult.ForceUpdate -> {
                    // [phase] stays at Loading: the public phases are the ones of before.
                    updateRequired = true
                    return
                }
                is PreloadResult.Success -> Phase.Ready(router(client, result.config))
            }
        } catch (e: CancellationException) {
            started = false
            throw e
        } catch (e: OrcaClientException.Http) {
            Phase.Failed("HTTP ${e.status}: ${e.body.take(200)}", e)
        } catch (e: Exception) {
            Phase.Failed(e.message ?: e.toString(), e)
        }
    }

    /** A router for [config] (Dart `_initRouter`), at the held link if any, with the plugins and the cache. */
    private fun router(client: OrcaClient, config: NavConfig): OrcaRouter {
        val link = pendingLink
        pendingLink = null
        staticFlowManager?.initDynamicPaths(config.flows)
        return OrcaRouter(client, config, system, onRouteChanged, link, savedState).also {
            it.plugins = plugins
            it.staticFlowManager = staticFlowManager
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
 * a failed fetch shows Flutter's error screen for it ([OrcaErrorView]) with a
 * retry, as a page that failed to load does. A config with tabs is drawn as
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
 * @param enableOffline boots offline-first, as Flutter's OrcaApp: a
 * [StaticFlowManager] over [offlineStore], files in
 * `context.filesDir/orca_gateway` (unless [staticFlowManager] is given), and
 * [preload] at boot under the spinner:
 * the version check against the saved flow versions, before anything else
 * is asked. A forceUpdate answer shows the force-update screen and fetches
 * nothing more; offline (any `/version` failure) the saved config is used,
 * and with none saved the boot fails: the error view shows Flutter's screen
 * for it, "Something Went Wrong" and "An unexpected error occurred. Please
 * try again.", with a retry, while the error's message (what [error] gets,
 * and what a host's own [preload] throws) is "No network and no cached
 * config available"; fresh versions use the saved config with no `/config`
 * request; stale ones fetch `/config` and save it with the static flows'
 * pre-rendered pages. Those pages then open from the cache, offline too.
 * With a [path] there is no config: only the version check runs, and
 * nothing is cached.
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
 * @param loading drawn while `/config` is fetched (Dart
 * `OrcaApp.loadingWidget`) and, without a [splash], while the version check
 * runs. Boot only, as the views below: pages keep the SDK's spinner.
 * @param splash drawn while the version check runs and while `/config` is
 * fetched (Dart `OrcaApp.splashWidget`, which falls back to `loadingWidget`).
 * @param error drawn, alone, with what failed the boot: the `/config` fetch's
 * error or the plugin conflict (Dart `OrcaApp.errorBuilder`). Without it the
 * SDK's [OrcaErrorView] shows; a page that fails to load always shows that.
 * @param forceUpdate drawn when the version check demands an update (Dart
 * `OrcaApp.forceUpdateBuilder`), in place of the SDK's one line.
 * @param colorScheme the Material 3 colours of everything OrcaApp draws, its
 * boot screens and its pages (Flutter's MaterialApp `theme`, `darkTheme` and
 * `themeMode`, through `OrcaApp.materialApp`), with the host's typography and
 * shapes; null keeps the host's [MaterialTheme]. A Scaffold page stays light,
 * as Flutter's builders wrap it in a light `ThemeData()`.
 * @param locale the locale OrcaApp's screens and pages see in
 * [LocalConfiguration] (Flutter's MaterialApp `locale`), the layout direction
 * kept: Flutter's default localizations are left to right. Nothing is sent:
 * `x-orca-locale` stays the device's, as in Flutter.
 * @param preloadedConfig pre-loaded NavConfig (Dart `OrcaApp.preloadedConfig`).
 * When provided, skips the config fetch entirely: the app is on screen from
 * the first frame, and no version check runs. Use [preload] to obtain this
 * before calling OrcaApp; its forceUpdate answer is yours to show. Not used
 * with a [path].
 * @param staticFlowManager pre-initialized [StaticFlowManager] (Dart
 * `OrcaApp.staticFlowManager`). Pass the same instance as to [preload]:
 * each page is asked of it before the network. Not used with a [path].
 * @param savedState where the pages' `persistState` saves and `clearState`
 * drops saved copies of state keys (Flutter's StateManager `SavedState`):
 * `local` ones in its store, kept after a restart, `session` ones for the
 * life of the process. What is saved is restored when its scope is set up:
 * the app entry over `initialAppState` (with a [path], over the empty app
 * state) before the first route is resolved, so redirects and the first page
 * request see it, and each page's entry over the page's declared initials,
 * from the network or the cache alike. Null: one over [offlineStore], its
 * entries `orca_saved_*` in `context.filesDir/orca_gateway` beside the
 * offline cache's. Taken once, with the kept router or boot (one per
 * OrcaApp, through a rotation).
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
    loading: (@Composable () -> Unit)? = null,
    splash: (@Composable () -> Unit)? = null,
    error: (@Composable (Throwable) -> Unit)? = null,
    forceUpdate: (@Composable () -> Unit)? = null,
    colorScheme: ColorScheme? = null,
    locale: Locale? = null,
    preloadedConfig: NavConfig? = null,
    staticFlowManager: StaticFlowManager? = null,
    savedState: SavedState? = null,
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
            val saved = savedState ?: SavedState(offlineStore(context))
            Retained(OrcaRouter(identified, path, system = null, coldLink = launch, savedState = saved))
        }
        val router = retained.value
        AttachHost(router, system, onRouteChanged, onDeeplink)
        NewIntentLinks { router.handleDeeplink(it) }
        RouterApp(
            router, modifier, enableOffline, enableSessionTracking, plugins, customActions, widgets,
            loading, splash, error, forceUpdate, colorScheme, locale,
        )
        return
    }
    // A boot made now holds the link through the version check and the config fetch. Once per kept
    // boot, as for the path above: an OrcaApp that left the composition and came back reads the
    // launch Intent again, and that is not a new link.
    val retained = viewModel(key = "com.orcagateway.sdk.OrcaAppBoot:$site") {
        // Dart `staticFlowManager ?? (enableOffline ? StaticFlowManager() : null)`, over files.
        val cache = staticFlowManager ?: if (enableOffline) StaticFlowManager(offlineStore(context)) else null
        Retained(
            OrcaAppBoot(identified).also { boot ->
                boot.staticFlowManager = cache
                boot.enableOffline = enableOffline
                boot.savedState = savedState ?: SavedState(offlineStore(context))
                launch?.let(boot::handleDeeplink)
            },
        )
    }
    val boot = retained.value
    NewIntentLinks { boot.handleDeeplink(it) }
    // The plugins are merged first, so the config is asked with their names; once per kept boot.
    // A preloaded config then gives the router at once, while composing: the first frame is the app.
    val prepare = {
        if (boot.plugins == null) boot.plugins = OrcaPluginHost.merge(boot.client, plugins, customActions, widgets)
        if (preloadedConfig != null) boot.start(preloadedConfig)
    }
    val bootSplash = splash ?: loading
    WithSchemeAndLocale(colorScheme, locale) {
        // No version check in the gate: the boot's preload runs it, and a preloaded config has none.
        OrcaBootView(identified, enableOffline = false, enableSessionTracking, modifier, prepare, bootSplash, error, forceUpdate) {
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
            // The boot's preload said forceUpdate (Swift twin `updateRequired`); its phase stays Loading.
            if (boot.updateRequired) {
                if (forceUpdate != null) HostView(modifier, forceUpdate) else ForceUpdateScreen(modifier)
            } else {
                when (val phase = boot.phase) {
                    OrcaAppBoot.Phase.Loading -> if (bootSplash != null) HostView(modifier, bootSplash) else LoadingView(modifier)
                    is OrcaAppBoot.Phase.Ready -> {
                        AttachHost(phase.router, system, onRouteChanged, onDeeplink)
                        OrcaNavHost(phase.router, modifier)
                    }
                    is OrcaAppBoot.Phase.Failed -> {
                        val thrown = phase.error ?: RuntimeException(phase.message)
                        if (error != null) {
                            HostView(modifier) { error(thrown) }
                        } else {
                            OrcaErrorView(thrown, modifier) { scope.launch { boot.reload(context) } }
                        }
                    }
                }
            }
        }
    }
}

/**
 * While shown, the host's latest [system], [onRouteChanged] and [onDeeplink]
 * are the router's (OrcaApp(client) keeps the router, not the activity they
 * belong to). The link that opened the app is reported here, once, after
 * the first location of a router made before anyone listened.
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
        router.deliverFirstRoute()
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
 * by the first OrcaApp that shows it. Here [enableOffline] runs the version
 * check only: nothing is cached, and pages come from the network.
 *
 * Saved state is the router's own [OrcaRouter.savedState], as the host
 * built it (`savedState = SavedState(offlineStore(context))` saves where
 * OrcaApp(client) does); a router built without one saves nothing.
 *
 * Deep links are handled as by OrcaApp(client), and reported to the
 * router's own [OrcaRouter.onDeeplink]: the launch Intent's link once, as a
 * cold start, before the first page is drawn (so the page the router stood
 * on is not requested), and every new Intent's link. The router remembers
 * that it took the launch link, so hiding and showing this in the same
 * activity does not handle it again.
 *
 * [loading], [splash], [error], [forceUpdate], [colorScheme] and [locale]
 * are those of OrcaApp(client) (Dart `OrcaApp.loadingWidget`,
 * `splashWidget`, `errorBuilder`, `forceUpdateBuilder`, and
 * `OrcaApp.materialApp`'s theme and locale): here no config is fetched, so
 * [splash] (else [loading]) shows while the version check runs, and
 * [error] gets the plugin conflict.
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
    loading: (@Composable () -> Unit)? = null,
    splash: (@Composable () -> Unit)? = null,
    error: (@Composable (Throwable) -> Unit)? = null,
    forceUpdate: (@Composable () -> Unit)? = null,
    colorScheme: ColorScheme? = null,
    locale: Locale? = null,
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
    RouterApp(
        router, modifier, enableOffline, enableSessionTracking, plugins, customActions, widgets,
        loading, splash, error, forceUpdate, colorScheme, locale,
    )
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
    loading: (@Composable () -> Unit)?,
    splash: (@Composable () -> Unit)?,
    error: (@Composable (Throwable) -> Unit)?,
    forceUpdate: (@Composable () -> Unit)?,
    colorScheme: ColorScheme?,
    locale: Locale?,
) {
    // Once per router: one kept through a rotation keeps what it was given.
    val prepare = {
        if (router.plugins == null) router.plugins = OrcaPluginHost.merge(router.client, plugins, customActions, widgets)
    }
    WithSchemeAndLocale(colorScheme, locale) {
        OrcaBootView(router.client, enableOffline, enableSessionTracking, modifier, prepare, splash ?: loading, error, forceUpdate) {
            OrcaNavHost(router, modifier)
        }
    }
}

/**
 * [content] under the host's [colorScheme] and [locale], each when given
 * (Flutter's boot and ready MaterialApps take `OrcaApp.materialApp`'s theme
 * and locale). The tree is the same either way, so a scheme or a locale
 * changed while the app runs keeps the boot and the pages: with no scheme,
 * the host's own is set again.
 */
@Composable
private fun WithSchemeAndLocale(colorScheme: ColorScheme?, locale: Locale?, content: @Composable () -> Unit) {
    val configuration = LocalConfiguration.current
    val localized = remember(configuration, locale) { locale?.let { configuration.withLocale(it) } }
    CompositionLocalProvider(*listOfNotNull(localized?.let { LocalConfiguration provides it }).toTypedArray()) {
        WithColorScheme(colorScheme ?: MaterialTheme.colorScheme, content)
    }
}

/**
 * A copy of this configuration in [locale], with this one's layout direction:
 * Flutter's MaterialApp turns right to left only with the host's own
 * localizations (its default ones are left to right).
 */
private fun Configuration.withLocale(locale: Locale): Configuration = Configuration(this).also {
    it.setLocale(locale)
    val direction = Configuration.SCREENLAYOUT_LAYOUTDIR_MASK
    it.screenLayout = (it.screenLayout and direction.inv()) or (screenLayout and direction)
}

/**
 * [content] under a [MaterialTheme] of [colorScheme] with the current
 * typography, shapes and text style (MaterialTheme alone would set its
 * bodyLarge as the text style).
 */
@Composable
internal fun WithColorScheme(colorScheme: ColorScheme, content: @Composable () -> Unit) {
    val textStyle = LocalTextStyle.current
    MaterialTheme(colorScheme = colorScheme, shapes = MaterialTheme.shapes, typography = MaterialTheme.typography) {
        CompositionLocalProvider(LocalTextStyle provides textStyle, content = content)
    }
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

/**
 * The router as one stack, on a [NavHost]: a config without tabs, a host path, a route shown outside the tabs.
 *
 * A pushed route with a transition ([TransitionSpec]) comes in with it:
 * only the entering page moves, the page under it stays still and visible,
 * and a pop plays the same run backwards, with the same duration and curve.
 * A route with none, or with `none`, keeps the NavHost's own animation.
 * Only a push plays a route's transition: a `go` or a replace that leaves
 * the route alone at the bottom of the stack shows it at once, where
 * Flutter animates it in (the Swift SDK does as here).
 * With reduced motion ([orcaReduceMotion]) a route's transition is not
 * played: the page is there at once.
 *
 * The NavHost is a shared-transition scope, and each page gets an
 * [OrcaHeroStage]: a Hero whose tag is on both pages as one replaces the
 * other flies between its two places (on a pop, and on a push whose page
 * is loaded before the push ends), while the route's transition plays as
 * above. Otherwise only the route's transition plays.
 */
@Composable
private fun StackScreen(router: OrcaRouter, modifier: Modifier) {
    val navController = rememberNavController()
    // The transition of every pushed page the NavHost shows, by route id: a popped
    // route has left the router's stack by the time its page leaves the screen.
    val specs = remember(router) { HashMap<String, TransitionSpec>() }
    val reduceMotion by rememberUpdatedState(orcaReduceMotion())
    // The route's own transition of the page that moves, or null: the NavHost's default.
    fun moving(entry: NavBackStackEntry): TransitionSpec? =
        specs[entry.arguments?.getString(ROUTE_ID)]?.takeIf { it.kind != TransitionKind.None }
    val enter: AnimatedContentTransitionScope<NavBackStackEntry>.() -> EnterTransition? = {
        moving(targetState)?.let { if (reduceMotion) EnterTransition.None else it.enter() }
    }
    // The page under a page that comes in: still, and drawn until the run ends.
    val exit: AnimatedContentTransitionScope<NavBackStackEntry>.() -> ExitTransition? = {
        moving(targetState)?.let { if (reduceMotion) ExitTransition.None else ExitTransition.KeepUntilTransitionsFinished }
    }
    // The page under a page that leaves: there at once, still.
    val popEnter: AnimatedContentTransitionScope<NavBackStackEntry>.() -> EnterTransition? = {
        moving(initialState)?.let { EnterTransition.None }
    }
    val popExit: AnimatedContentTransitionScope<NavBackStackEntry>.() -> ExitTransition? = {
        moving(initialState)?.let { if (reduceMotion) ExitTransition.None else it.popExit() }
    }
    // The route ids of the pages pushed on the NavController, saved with it:
    // its own back stack is not public API.
    val shown = rememberSaveable { mutableStateOf(emptyList<String>()) }
    val atRoot = remember(router) { OrcaNavigation(router, canPop = false) }
    val pushed = remember(router) { OrcaNavigation(router, canPop = true) }
    // No layout of its own: the scope's modifier (the flight's overlay) goes on the NavHost.
    SharedTransitionScope { overlay ->
        val flights = this
        NavHost(navController, startDestination = ROOT_ROUTE, modifier = modifier.then(overlay)) {
            composable(ROOT_ROUTE, exitTransition = exit, popEnterTransition = popEnter) {
                val root = router.root
                val stage = remember(flights, this) { OrcaHeroStage(flights, this) }
                CompositionLocalProvider(LocalOrcaNavigation provides atRoot, LocalOrcaHeroStage provides stage) {
                    key(root.id) { RoutePage(router, root, if (root.isNotFound) null else router.loader(root)) }
                }
            }
            composable(
                PAGE_ROUTE,
                enterTransition = enter,
                exitTransition = exit,
                popEnterTransition = popEnter,
                popExitTransition = popExit,
            ) { entry ->
                val id = entry.arguments?.getString(ROUTE_ID)
                // Kept while a popped page leaves the screen, after the router dropped it.
                // A not-found route has no loader: nothing is requested for it.
                val page = remember(id) {
                    router.stack.firstOrNull { it.id.toString() == id }
                        ?.let { route -> route to if (route.isNotFound) null else router.loader(route) }
                }
                if (page != null) {
                    val stage = remember(flights, this) { OrcaHeroStage(flights, this) }
                    CompositionLocalProvider(LocalOrcaNavigation provides pushed, LocalOrcaHeroStage provides stage) {
                        RoutePage(router, page.first, page.second)
                    }
                }
            }
        }
    }
    // After the NavHost, so it is asked before the NavHost's own back handling.
    BackHandler(enabled = router.stack.isNotEmpty()) { router.goBack() }
    LaunchedEffect(router, navController) {
        snapshotFlow { router.stack }.collect { stack ->
            // Before the NavController moves: it asks for the transitions as it does.
            val ids = stack.mapTo(HashSet()) { it.id.toString() }
            specs.keys.retainAll(ids + shown.value)
            for (route in stack) specs[route.id.toString()] = TransitionSpec.of(route.transition)
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

/** The route's curve for a Compose animation spec: every name of the core's [Curves] table. */
private fun TransitionSpec.easing(): Easing = Easing { Curves.apply(curve, it.toDouble()).toFloat() }

/** The same curve for the run played backwards: the value at `1 - t`, counted from the other end. */
private fun TransitionSpec.reversedEasing(): Easing = Easing { 1f - Curves.apply(curve, 1.0 - it).toFloat() }

private fun <T> TransitionSpec.tweenOf(easing: Easing): FiniteAnimationSpec<T> = tween(durationMs.toInt(), easing = easing)

/** How the route's page comes in (design D11): only this page moves. */
private fun TransitionSpec.enter(): EnterTransition = when (kind) {
    TransitionKind.Fade -> fadeIn(tweenOf(easing()))
    TransitionKind.SlideUp -> slideInVertically(tweenOf(easing())) { it }
    TransitionKind.Scale -> scaleIn(tweenOf(easing()), initialScale = 0f)
    TransitionKind.SlideRight -> slideInHorizontally(tweenOf(easing())) { it }
    TransitionKind.Slide -> slideInHorizontally(tweenOf(easing())) { -it }
    TransitionKind.None -> EnterTransition.None
}

/** How the route's page leaves on a pop: [enter] played backwards. */
private fun TransitionSpec.popExit(): ExitTransition = when (kind) {
    TransitionKind.Fade -> fadeOut(tweenOf(reversedEasing()))
    TransitionKind.SlideUp -> slideOutVertically(tweenOf(reversedEasing())) { it }
    TransitionKind.Scale -> scaleOut(tweenOf(reversedEasing()), targetScale = 0f)
    TransitionKind.SlideRight -> slideOutHorizontally(tweenOf(reversedEasing())) { it }
    TransitionKind.Slide -> slideOutHorizontally(tweenOf(reversedEasing())) { -it }
    TransitionKind.None -> ExitTransition.None
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

/**
 * A route's page, under the title bar of a route that has a fallback title.
 * Flutter wraps such a route in a root Scaffold of its own
 * (navigation_handler.dart:111-147, :372; orca_page.dart:218-247), on the
 * single stack and over the tab shell alike: the app's snackbar shows at
 * its bottom edge, over the page, even when the page has no Scaffold, and
 * the page's Scaffolds are nested in it and draw none.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RouteFrame(router: OrcaRouter, route: OrcaRoute, loader: OrcaPageLoader?) {
    val fallback = route.scaffoldTitle
    if (fallback == null) {
        RouteBody(router, route, loader)
        return
    }
    val title = (loader?.phase as? OrcaPageLoader.Phase.Loaded)?.model?.page?.title ?: fallback
    Box(Modifier.fillMaxSize()) {
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
            Box(Modifier.weight(1f)) {
                CompositionLocalProvider(LocalOrcaShellSnackbars provides true) { RouteBody(router, route, loader) }
            }
        }
        SnackbarLayer(router.snackbars, NO_BARS, onBars = false)
    }
}

/** No bars under a titled route's snackbar. */
private val NO_BARS = PaddingValues()

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
        is OrcaPageLoader.Phase.Failed -> OrcaErrorView(phase.error ?: RuntimeException(phase.message)) {
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

/**
 * The SDK's error screen, the native twin of Flutter's `buildOrcaError`
 * (sdk/lib/src/widgets/orca_error.dart): for [error], the icon, title and
 * message [OrcaErrorInfo.from] gives ("Not Found" and "The requested page
 * could not be found." for a 404, "Connection Failed" for a server never
 * reached, ...), laid out as Flutter's: centred, padding 32, the icon 48,
 * then 16 down the title (18, semibold), then 8 down the message (14). The
 * icons are Flutter's Material ones (`lock_outline`, `block`, `search_off`,
 * `speed`, `cloud_off`, `error_outline`, `settings`, `wifi_off`).
 *
 * The colours are the theme's, so dark mode reads: [MaterialTheme]'s
 * onSurface for the title, onSurfaceVariant for the icon and message, where
 * Flutter's are fixed black at 87% and 60%.
 *
 * With [onRetry], a "Try again" button under the message, a native extra
 * Flutter's screen does not have. OrcaApp shows this view, with a retry, for
 * a page that failed to load and a failed config boot; a host can show it for
 * its own errors. Test tag `orca.error`.
 */
@Composable
public fun OrcaErrorView(error: Throwable, modifier: Modifier = Modifier, onRetry: (() -> Unit)? = null) {
    OrcaErrorView(OrcaErrorInfo.from(error), modifier, onRetry)
}

/** [OrcaErrorView] for an [info] already made: the boot's plugin conflict keeps its own message. */
@Composable
internal fun OrcaErrorView(info: OrcaErrorInfo, modifier: Modifier = Modifier, onRetry: (() -> Unit)? = null) {
    val colors = MaterialTheme.colorScheme
    val base = LocalTextStyle.current
    Box(modifier.fillMaxSize().testTag("orca.error"), contentAlignment = Alignment.Center) {
        Column(Modifier.padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                errorIcon(info.kind),
                contentDescription = null,
                modifier = Modifier.size(48.dp).testTag("orca.error.icon"),
                tint = colors.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))
            Text(
                info.title,
                color = colors.onSurface,
                textAlign = TextAlign.Center,
                style = base.merge(TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold)),
            )
            Spacer(Modifier.height(8.dp))
            Text(
                info.message,
                color = colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
                style = base.merge(TextStyle(fontSize = 14.sp)),
            )
            if (onRetry != null) {
                Spacer(Modifier.height(16.dp))
                TextButton(onClick = onRetry) { Text("Try again") }
            }
        }
    }
}

/** The Material icon Flutter's `buildOrcaError` draws for [kind]. */
internal fun errorIcon(kind: OrcaErrorInfo.Kind): ImageVector = when (kind) {
    OrcaErrorInfo.Kind.Unauthorized -> Icons.Outlined.Lock
    OrcaErrorInfo.Kind.Forbidden -> Icons.Filled.Block
    OrcaErrorInfo.Kind.NotFound -> Icons.Filled.SearchOff
    OrcaErrorInfo.Kind.TooManyRequests -> Icons.Filled.Speed
    OrcaErrorInfo.Kind.Server -> Icons.Filled.CloudOff
    OrcaErrorInfo.Kind.Configuration -> Icons.Filled.Settings
    OrcaErrorInfo.Kind.Connection -> Icons.Filled.WifiOff
    OrcaErrorInfo.Kind.Status, OrcaErrorInfo.Kind.Unknown -> Icons.Filled.ErrorOutline
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
