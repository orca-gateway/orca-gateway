package com.orcagateway.sdk.widgets

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.PullToRefreshDefaults
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlinx.coroutines.launch
import kotlin.math.abs

/**
 * Flutter `PullToRefresh` (layout_builders.dart:372-393), a
 * RefreshIndicator, as material3's `PullToRefreshBox`: a drag down begun
 * at the top of the vertical scroll view inside it pulls the indicator,
 * and a release past the threshold fires `onRefresh`; the spinner turns
 * until the fired action's job ends (Flutter awaits the action,
 * refresh_indicator.dart:634-639). With no onRefresh nothing runs and the
 * indicator goes back. A drag begun lower down never refreshes, even when
 * it scrolls back to the top and on ([EdgeStart], Flutter's default
 * `RefreshIndicatorTriggerMode.onEdge`); such a drag also loses Android's
 * overscroll stretch at the top, which Flutter shows there (its stretch
 * at the bottom stays). A horizontal scroll view never refreshes. A drag
 * begun at the top that first scrolls up and then comes back down past
 * it does, as Flutter's. Unlike Flutter's, which hears only the scroll
 * view at depth 0, a vertical scroll view nested in that one also starts
 * it when both are at their top: Compose hands what the inner one leaves
 * to the outer one, then here, and says nothing of where it came from.
 *
 * The spinner is `color` (the theme's primary) on `backgroundColor` (the
 * theme's surface, Flutter's Material 3 canvasColor), and its circle rests
 * 4 below `displacement` (40), where Flutter's RefreshProgressIndicator
 * (4 margin) puts it. The pull needed is Compose's own, 160 dp of finger
 * travel (its 80 dp threshold at half speed); Flutter's is a sixth of the
 * view's height.
 */
@Composable
internal fun PullToRefreshWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val color = Props.color(node["color"]) ?: MaterialTheme.colorScheme.primary
    val background = Props.color(node["backgroundColor"]) ?: MaterialTheme.colorScheme.surface
    val displacement = Props.length(node["displacement"]) ?: 40.dp
    val current = rememberUpdatedState(node)
    val scope = rememberCoroutineScope()
    var refreshing by remember { mutableStateOf(false) }
    val state = rememberPullToRefreshState()
    val edge = remember { EdgeStart() }
    PullToRefreshBox(
        isRefreshing = refreshing,
        onRefresh = {
            val job = model.fire("onRefresh", current.value)
            if (job != null && !job.isCompleted) {
                refreshing = true
                scope.launch {
                    job.join()
                    refreshing = false
                }
            }
        },
        modifier = modifier,
        state = state,
        indicator = {
            PullToRefreshDefaults.Indicator(
                state, refreshing, Modifier.align(Alignment.TopCenter),
                containerColor = background, color = color, maxDistance = displacement + 44.dp,
            )
        },
    ) {
        // Watches each finger going down, taking nothing.
        val touches = Modifier.pointerInput(edge) {
            awaitEachGesture {
                awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                edge.touched()
            }
        }
        Box(touches.nestedScroll(edge), propagateMinConstraints = true) { ChildView(node, model) }
    }
}

/**
 * Flutter's `onEdge` trigger between the scroll views and the indicator: a
 * drag pulls only if it began with the scroll view at its top (Flutter's
 * extentBefore 0 at the drag's start, refresh_indicator.dart:461-475).
 * Compose tells no position up the chain, only what each move scrolled,
 * so the start is read where it matters: when a move leaves some over
 * going down, the view is at its top, and the drag began as far below it
 * as it has scrolled the view toward the top since the finger went down
 * ([touched]), within a pixel. A drag begun lower down leaves its excess
 * going down here; its excess going up passes on, to the list's
 * overscroll.
 */
private class EdgeStart : NestedScrollConnection {
    /** How far, in pixels, the drag under way has scrolled the views inside toward their top. */
    private var back = 0f

    fun touched() {
        back = 0f
    }

    override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
        if (source != NestedScrollSource.UserInput) return Offset.Zero
        back += consumed.y
        return if (available.y > 0f && abs(back) >= 1f) Offset(0f, available.y) else Offset.Zero
    }
}
