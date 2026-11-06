package com.orcagateway.sdk

import android.content.Context
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.ElmStore
import com.orcagateway.sdk.client.current
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * Loads one page through [OrcaClient] and keeps the result (Swift
 * `OrcaPageLoader`). The first load fills the client's device headers from
 * this device when the client was built with the default [DeviceInfo].
 * Use it from the main thread; [phase] is Compose state.
 */
public class OrcaPageLoader(
    public val client: OrcaClient,
    public val path: String,
) : AutoCloseable {
    /** Where the load stands. */
    public sealed interface Phase {
        public data object Loading : Phase

        public class Loaded(public val model: OrcaPageModel) : Phase

        public data class Failed(public val message: String) : Phase
    }

    public var phase: Phase by mutableStateOf(Phase.Loading)
        private set

    /** Handed to every loaded page's model (see [OrcaPageModel.effectHandler]). */
    public var effectHandler: ((ActionEffect) -> Unit)? = null

    private var started = false

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
        phase = try {
            val page = client.fetchPage(path)
            // DevTools reporting arrives with the adapters slice (S8).
            val model = OrcaPageModel(page, store = ElmStore(), client = client)
            model.effectHandler = effectHandler
            Phase.Loaded(model)
        } catch (e: CancellationException) {
            throw e
        } catch (e: OrcaClientException.Http) {
            Phase.Failed("HTTP ${e.status}: ${e.body.take(200)}")
        } catch (e: Exception) {
            Phase.Failed(e.message ?: e.toString())
        }
    }

    /** Cancel the loaded page's running actions. */
    override fun close() {
        (phase as? Phase.Loaded)?.model?.close()
    }
}

/**
 * The root of an Orca-driven app: a [NavHost] whose start destination is the
 * server page at [path], drawn with its loading and error states.
 *
 *     OrcaApp(OrcaClient(URI("https://api.example.com"), appId = "counter", transport = OkHttpTransport()))
 *
 * Snackbars and toasts are handled by the page. Navigation, URL, clipboard,
 * share and the other effects go to [effectHandler]; the SDK's own adapters
 * for them arrive with the adapters slice (S8). Without a handler they do
 * nothing, and a FallbackPrompt's link opens through Compose's `UriHandler`.
 */
@Composable
public fun OrcaApp(
    client: OrcaClient,
    modifier: Modifier = Modifier,
    path: String = "home",
    effectHandler: ((ActionEffect) -> Unit)? = null,
) {
    val navController = rememberNavController()
    NavHost(navController, startDestination = ROOT_ROUTE, modifier = modifier) {
        composable(ROOT_ROUTE) { RoutePage(client, path, effectHandler) }
    }
}

/** One route's page: a spinner, the page, or the error with a retry. */
@Composable
private fun RoutePage(client: OrcaClient, path: String, effectHandler: ((ActionEffect) -> Unit)?) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val loader = remember(client, path) { OrcaPageLoader(client, path) }
    loader.effectHandler = effectHandler
    DisposableEffect(loader) { onDispose { loader.close() } }
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
