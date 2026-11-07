package com.orcagateway.sdk

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
 * The root of an Orca-driven app: a [NavHost] of server pages, each with its
 * loading and error states. `navigate` pushes a page, `goBack` and the
 * system back gesture pop one, and app state is shared by every page on the
 * stack (see [OrcaRouter]).
 *
 *     OrcaApp(OrcaClient(URI("https://api.example.com"), appId = "counter", transport = OkHttpTransport()))
 *
 * Snackbars and toasts are handled by the page; `openUrl`, the clipboard and
 * share go to [system], by default the device's own ([SystemActions.android]).
 * The router is made once, like Swift's `StateObject`, and closed with this
 * composition: a new activity starts again at [path].
 */
@Composable
public fun OrcaApp(
    client: OrcaClient,
    modifier: Modifier = Modifier,
    path: String = "home",
    system: SystemActions? = null,
) {
    val router = remember { OrcaRouter(client, path, system) }
    DisposableEffect(router) { onDispose { router.close() } }
    OrcaApp(router, modifier)
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
            key(root.id) { RoutePage(router.loader(root)) }
        }
        composable(PAGE_ROUTE) { entry ->
            val id = entry.arguments?.getString(ROUTE_ID)
            // Kept while a popped page leaves the screen, after the router dropped it.
            val loader = remember(id) { router.stack.firstOrNull { it.id.toString() == id }?.let(router::loader) }
            if (loader != null) RoutePage(loader)
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

/** One route's page: a spinner, the page, or the error with a retry. */
@Composable
private fun RoutePage(loader: OrcaPageLoader) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    LaunchedEffect(loader) { loader.loadIfNeeded(context) }

    when (val phase = loader.phase) {
        OrcaPageLoader.Phase.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        is OrcaPageLoader.Phase.Loaded -> OrcaPageView(phase.model)
        is OrcaPageLoader.Phase.Failed -> Column(
            Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("Could not load this page", style = MaterialTheme.typography.titleMedium)
            Text(
                phase.message,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            TextButton(onClick = { scope.launch { loader.reload(context) } }) { Text("Try again") }
        }
    }
}

private const val ROOT_ROUTE = "orca/root"
private const val ROUTE_ID = "id"
private const val PAGE_ROUTE = "orca/page/{$ROUTE_ID}"
