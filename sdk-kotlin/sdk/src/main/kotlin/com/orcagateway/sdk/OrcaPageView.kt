package com.orcagateway.sdk

import android.widget.Toast
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.orcagateway.core.state.SnackbarQueue
import com.orcagateway.sdk.widgets.BackdropRecording

/**
 * Where a page's snackbars go: the page's host, handed to the Scaffold that
 * is the page root (so the snackbar sits above its bottom bar and FAB, as in
 * Material 3). Null below that Scaffold, so a nested one draws no second host.
 */
internal val LocalOrcaSnackbars = compositionLocalOf<SnackbarHostState?> { null }

/**
 * One page, with the head of its snackbar queue. Draws the page root at the
 * top of the space it is given; a Scaffold root fills it.
 *
 * The queue is the app's under a router (Flutter's root ScaffoldMessenger),
 * else the page's own, and it runs on this view's frames. A snackbar shows
 * in the root Scaffold's Material 3 `SnackbarHost` from when it comes in to
 * when it starts to go; with no Scaffold on screen it is queued and timed
 * but drawn nowhere, as Flutter in release (scaffold.dart:229-262, :360-365).
 * A toast is an Android `Toast`, shown when it reaches the head (Swift draws
 * it as a floating message).
 *
 * Text without a style of its own is Material 3 `bodyMedium`, as Flutter's
 * default text style; the host's `MaterialTheme`, if any, applies.
 *
 * The page root records what it draws for the page's BackdropFilters and
 * BlurViews, only while there is one ([BackdropRecording]).
 */
@Composable
public fun OrcaPageView(model: OrcaPageModel, modifier: Modifier = Modifier) {
    val snackbars = remember { SnackbarHostState() }
    val context = LocalContext.current
    val queue = model.snackbars
    val head = queue.head

    LaunchedEffect(model) { model.appeared() }
    // Time passes for the queue on frames, and only while it holds something.
    LaunchedEffect(queue) {
        while (true) {
            queue.awaitWork()
            withFrameMillis(queue::tick)
        }
    }
    LaunchedEffect(head) {
        if (head == null || head.style != OrcaToast.Style.Toast || !queue.take(head)) return@LaunchedEffect
        val length = if (head.durationMillis > TOAST_SHORT_MILLIS) Toast.LENGTH_LONG else Toast.LENGTH_SHORT
        Toast.makeText(context, head.message, length).show()
    }
    val bar = head?.takeIf { it.style == OrcaToast.Style.Snackbar && queue.phase != SnackbarQueue.Phase.Leaving }
    LaunchedEffect(bar) {
        // Shown until this effect is cancelled: when the bar starts to go.
        if (bar != null) snackbars.showSnackbar(bar.message, duration = SnackbarDuration.Indefinite)
    }

    // The root can change with the tree (a server action replacing it).
    val revision = model.structureRevision
    val root = remember(model, revision) { model.renderer.rootId }
    val rootIsScaffold = remember(model, revision) { root?.let { model.renderer.node(it)?.type } == "Scaffold" }

    ProvideTextStyle(MaterialTheme.typography.bodyMedium) {
        CompositionLocalProvider(LocalOrcaSnackbars provides if (rootIsScaffold) snackbars else null) {
            Box(modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
                if (root != null) BackdropRecording { rootModifier -> NodeView(root, model, rootModifier) }
            }
        }
    }
}

/** Android's short toast; anything longer is shown as a long one. */
private const val TOAST_SHORT_MILLIS = 2000L
