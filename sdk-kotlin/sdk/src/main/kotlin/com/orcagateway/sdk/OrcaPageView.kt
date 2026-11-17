package com.orcagateway.sdk

import android.widget.Toast
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.orcagateway.sdk.widgets.BackdropRecording
import com.orcagateway.sdk.widgets.DialogLayer

/**
 * The queue whose head a Scaffold with no Scaffold above it draws, as
 * Flutter's ScaffoldMessenger draws its bar in root Scaffolds only
 * (scaffold.dart:229-262). Null below a Scaffold, so a nested one draws no
 * second bar.
 */
internal val LocalOrcaSnackbars = compositionLocalOf<OrcaSnackbarQueue?> { null }

/**
 * True for a page that a Scaffold of the app's own frame holds, which draws
 * the bar itself, so the page's Scaffolds draw none (scaffold.dart
 * :258-263): a tab page (Flutter's OrcaShell Scaffold) and a titled route's
 * page (Flutter wraps it in a title-bar Scaffold of its own,
 * navigation_handler.dart:111-147, :372).
 */
internal val LocalOrcaShellSnackbars = compositionLocalOf { false }

/**
 * True for a page that a titled route's frame holds: the frame draws the
 * page's sheets over its title bar ([DialogLayer]), as Flutter's sheet route
 * is above the route's title-bar Scaffold, so the page draws none itself.
 */
internal val LocalOrcaFrameDialogs = compositionLocalOf { false }

/**
 * One page, with the head of its snackbar queue. Draws the page root at the
 * top of the space it is given; a Scaffold root fills it.
 *
 * The queue is the app's under a router (Flutter's root ScaffoldMessenger),
 * else the page's own, and it runs on this view's frames. A snackbar is
 * drawn as Material 3's fixed bar ([com.orcagateway.sdk.widgets.SnackbarBar])
 * by each of the page's Scaffolds with no Scaffold above it, by the tab
 * shell under tabs; with no Scaffold on screen it is queued and timed but drawn nowhere, as
 * Flutter in release (scaffold.dart:229-262, :360-365). A toast is an
 * Android `Toast`, shown when it reaches the head (Swift draws it as a
 * floating message).
 *
 * The sheets the page's openDialog opens are drawn over it, its Scaffold's
 * bars included, and under a tab bar around it ([DialogLayer]); under a
 * titled route's frame, over that frame instead.
 *
 * Text without a style of its own is Material 3 `bodyMedium`, as Flutter's
 * default text style; the host's `MaterialTheme`, if any, applies.
 *
 * The page root records what it draws for the page's BackdropFilters and
 * BlurViews, only while there is one ([BackdropRecording]).
 */
@Composable
public fun OrcaPageView(model: OrcaPageModel, modifier: Modifier = Modifier) {
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

    // The root can change with the tree (a server action replacing it).
    val revision = model.structureRevision
    val root = remember(model, revision) { model.renderer.rootId }
    val drawsBar = !LocalOrcaShellSnackbars.current

    ProvideTextStyle(MaterialTheme.typography.bodyMedium) {
        CompositionLocalProvider(LocalOrcaSnackbars provides if (drawsBar) queue else null) {
            Box(modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
                DialogLayer(if (LocalOrcaFrameDialogs.current) null else model) {
                    if (root != null) BackdropRecording { rootModifier -> NodeView(root, model, rootModifier) }
                }
            }
        }
    }
}

/** Android's short toast; anything longer is shown as a long one. */
private const val TOAST_SHORT_MILLIS = 2000L
