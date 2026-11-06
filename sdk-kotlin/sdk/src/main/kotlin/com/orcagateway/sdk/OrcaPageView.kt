package com.orcagateway.sdk

import android.widget.Toast
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Where a page's snackbars go: the page's host, handed to the Scaffold that
 * is the page root (so the snackbar sits above its bottom bar and FAB, as in
 * Material 3). Null below that Scaffold, so a nested one draws no second host.
 */
internal val LocalOrcaSnackbars = compositionLocalOf<SnackbarHostState?> { null }

/**
 * One page with its snackbar and toast. Draws the page root at the top of
 * the space it is given; a Scaffold root fills it. A snackbar shows in the
 * root Scaffold's Material 3 `SnackbarHost` (or at the bottom of the page
 * when the root is not a Scaffold) for its duration; a toast is an Android
 * `Toast` (Swift draws both as a floating message).
 *
 * Text without a style of its own is Material 3 `bodyMedium`, as Flutter's
 * default text style; the host's `MaterialTheme`, if any, applies.
 */
@Composable
public fun OrcaPageView(model: OrcaPageModel, modifier: Modifier = Modifier) {
    val snackbars = remember { SnackbarHostState() }
    val context = LocalContext.current
    val toast = model.toast

    LaunchedEffect(model) { model.appeared() }
    LaunchedEffect(toast) {
        val shown = toast ?: return@LaunchedEffect
        when (shown.style) {
            OrcaToast.Style.Snackbar -> coroutineScope {
                // Cancelling the call dismisses the snackbar: that is how a
                // duration in milliseconds is honoured.
                val showing = launch { snackbars.showSnackbar(shown.message, duration = SnackbarDuration.Indefinite) }
                delay(shown.durationMillis)
                showing.cancel()
            }
            OrcaToast.Style.Toast -> {
                val length = if (shown.durationMillis > TOAST_SHORT_MILLIS) Toast.LENGTH_LONG else Toast.LENGTH_SHORT
                Toast.makeText(context, shown.message, length).show()
                delay(shown.durationMillis)
            }
        }
        if (model.toast === shown) model.toast = null
    }

    // The root can change with the tree (a server action replacing it).
    val revision = model.structureRevision
    val root = remember(model, revision) { model.renderer.rootId }
    val rootIsScaffold = remember(model, revision) { root?.let { model.renderer.node(it)?.type } == "Scaffold" }

    ProvideTextStyle(MaterialTheme.typography.bodyMedium) {
        CompositionLocalProvider(LocalOrcaSnackbars provides if (rootIsScaffold) snackbars else null) {
            Box(modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
                if (root != null) NodeView(root, model)
                if (!rootIsScaffold) SnackbarHost(snackbars, Modifier.align(Alignment.BottomCenter))
            }
        }
    }
}

/** Android's short toast; anything longer is shown as a long one. */
private const val TOAST_SHORT_MILLIS = 2000L
