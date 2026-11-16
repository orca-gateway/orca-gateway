package com.orcagateway.sdk.widgets

import androidx.compose.animation.core.AnimationState
import androidx.compose.animation.core.animateTo
import androidx.compose.animation.core.spring
import androidx.compose.foundation.gestures.ScrollScope
import androidx.compose.foundation.gestures.TargetedFlingBehavior
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import com.orcagateway.core.render.PageSnap
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.ScrollMetrics
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.abs

/**
 * Flutter `PageView` as `_buildPageView` makes it (layout_builders.dart:
 * 668-684): horizontal unless `scrollDirection` is `vertical`, `reverse`
 * (page 0 at the far end) and `pageSnapping`, both false and true by
 * default; no controller, so it starts on page 0 and each page is the
 * viewport's size (viewportFraction 1), the page forced to it as Flutter's
 * SliverFillViewport does. Only the visible pages are laid out (cache 0,
 * page_view.dart:723: `beyondViewportPageCount` 0); while it scrolls,
 * Compose's prefetch also composes the next page ahead, not placed, which
 * Flutter does not.
 *
 * Snapping, a Compose pager whose release settles on the core's
 * [PageSnap] target (Flutter's PageScrollPhysics: at most one page per
 * fling, and a fling only past both of Flutter's gates, 50 dp a second and
 * 18 dp of travel in the last 100 ms, not Compose's 400 dp a second) with
 * Flutter's settling spring. Not snapping, a lazy row (column) of viewport-sized
 * items with the platform's free fling. Both report their scrolling
 * through [LazyScrollReports]: a node with a scroll trigger gets
 * onScrollBegin, onScrolling and onScrollEnd (`wrapScrollNotifier`) with
 * offset = (page + fraction) x page extent and the viewport, in dp, and a
 * Scrollbar the PageView sits directly in draws its thumb.
 *
 * On a main axis with no limit (in a Row, Column or scroll view along it)
 * Flutter's viewport asserts and draws nothing useful, and Compose's lazy
 * layouts throw: here the pages are laid out one after another at their
 * own size instead, in order, as a SingleChildScrollView there takes its
 * child's size. Nothing pages or scrolls, so no scroll trigger fires.
 */
@Composable
internal fun PageViewWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val vertical = node["scrollDirection"]?.stringValue == "vertical"
    val reverse = Props.bool(node["reverse"]) ?: false
    val pages = node.childIds
    BoxWithConstraints(modifier, propagateMinConstraints = true) {
        val bounded = if (vertical) constraints.hasBoundedHeight else constraints.hasBoundedWidth
        when {
            // As ListView's: nothing inside reports to a Scrollbar around it.
            !bounded -> CompositionLocalProvider(LocalScrollbarHost provides null) { EagerPages(pages, model, vertical) }
            Props.bool(node["pageSnapping"]) ?: true -> SnappingPages(node, model, pages, vertical, reverse)
            else -> FreePages(node, model, pages, vertical, reverse)
        }
    }
}

/** Every page at its own size, in a Row (a Column when vertical): a PageView with no limit along its axis. */
@Composable
private fun EagerPages(pages: List<String>, model: OrcaPageModel, vertical: Boolean) {
    if (vertical) {
        Column { pages.forEach { NodeView(it, model) } }
    } else {
        Row { pages.forEach { NodeView(it, model) } }
    }
}

@Composable
private fun SnappingPages(
    node: ResolvedNode,
    model: OrcaPageModel,
    pages: List<String>,
    vertical: Boolean,
    reverse: Boolean,
) {
    val state = rememberPagerState { pages.size }
    val density = LocalDensity.current.density
    val travel = remember { ReleaseTravel() }
    val fling = remember(state, density, travel) { PageSnapFling(state, density, travel) }
    // Watches the touches on their way down, taking none.
    val sampling = Modifier.pointerInput(travel, vertical) {
        awaitPointerEventScope {
            while (true) {
                val change = awaitPointerEvent(PointerEventPass.Initial).changes.firstOrNull() ?: continue
                // Flutter samples downs and moves, not the lift.
                if (!change.pressed) continue
                if (!change.previousPressed) travel.clear()
                travel.add(change.uptimeMillis, if (vertical) change.position.y else change.position.x)
            }
        }
    }
    val content: @Composable (Int) -> Unit = { index -> pages.getOrNull(index)?.let { Page(it, model, Modifier.fillMaxSize()) } }
    LazyScrollReports(node, model, state, !vertical, reverse, { state.metrics(it, vertical) }) {
        if (vertical) {
            VerticalPager(
                state, sampling, beyondViewportPageCount = 0, flingBehavior = fling, reverseLayout = reverse,
            ) { content(it) }
        } else {
            HorizontalPager(
                state, sampling, beyondViewportPageCount = 0, flingBehavior = fling, reverseLayout = reverse,
            ) { content(it) }
        }
    }
}

/** Flutter's metrics of a snapping pager in dp: offset (page + fraction) x page extent, [pageCount] - 1 pages to scroll. */
private fun PagerState.metrics(density: Double, vertical: Boolean): ScrollMetrics {
    val page = layoutInfo.pageSize / density
    return ScrollMetrics(
        offset = (currentPage + currentPageOffsetFraction) * page,
        maxExtent = (pageCount - 1).coerceAtLeast(0) * page,
        viewportDimension = layoutInfo.viewportSize.let { if (vertical) it.height else it.width } / density,
    )
}

@Composable
private fun FreePages(
    node: ResolvedNode,
    model: OrcaPageModel,
    pages: List<String>,
    vertical: Boolean,
    reverse: Boolean,
) {
    val state = rememberLazyListState()
    val item: @Composable LazyItemScope.(Int) -> Unit = { index -> Page(pages[index], model, Modifier.fillParentMaxSize()) }
    // Every item is the viewport's size, so a list's metrics are exact.
    LazyScrollReports(node, model, state, !vertical, reverse, { state.metrics(it) }) {
        if (vertical) {
            LazyColumn(state = state, reverseLayout = reverse) { items(pages.size) { item(it) } }
        } else {
            LazyRow(state = state, reverseLayout = reverse) { items(pages.size) { item(it) } }
        }
    }
}

/** One page, its node forced to the page's size. */
@Composable
private fun Page(id: String, model: OrcaPageModel, modifier: Modifier) {
    Box(modifier, propagateMinConstraints = true) { NodeView(id, model) }
}

/**
 * The finger's travel along the pager's axis in Flutter's velocity window
 * (`VelocityTracker.getVelocityEstimate`, velocity_tracker.dart:195-255):
 * the newest sample minus the oldest one at most 100 ms older, with no gap
 * over 40 ms between samples, among the last 20 of the touch, in pixels.
 */
private class ReleaseTravel {
    private val times = ArrayList<Long>()
    private val positions = ArrayList<Float>()

    fun clear() {
        times.clear()
        positions.clear()
    }

    fun add(time: Long, position: Float) {
        if (times.size == 20) {
            times.removeAt(0)
            positions.removeAt(0)
        }
        times.add(time)
        positions.add(position)
    }

    val travel: Float
        get() {
            val newest = times.lastOrNull() ?: return 0f
            var oldest = positions.last()
            var previous = newest
            for (index in times.indices.reversed()) {
                val time = times[index]
                if (newest - time > 100 || previous - time > 40) break
                previous = time
                oldest = positions[index]
            }
            return positions.last() - oldest
        }
}

/**
 * Flutter `PageScrollPhysics.createBallisticSimulation`: from where the
 * finger let go, to the page the core's [PageSnap] picks for the release
 * velocity (in dp a second, the fling direction toward later pages
 * positive, whatever `reverse`) and the finger's [ReleaseTravel], along
 * Flutter's default scroll spring (mass 0.5, stiffness 100, damping ratio
 * 1.1: Compose's mass is 1, so stiffness 200).
 */
private class PageSnapFling(
    private val state: PagerState,
    private val density: Float,
    private val travel: ReleaseTravel,
) : TargetedFlingBehavior {
    override suspend fun ScrollScope.performFling(initialVelocity: Float, onRemainingDistanceUpdated: (Float) -> Unit): Float {
        val size = (state.layoutInfo.pageSize + state.layoutInfo.pageSpacing).toFloat()
        val position = state.currentPage + state.currentPageOffsetFraction
        val target = PageSnap.target(
            offset = position * size / density.toDouble(),
            viewportExtent = size / density.toDouble(),
            velocity = initialVelocity / density.toDouble(),
            travel = travel.travel / density.toDouble(),
            pageCount = state.pageCount,
        ) ?: return initialVelocity
        val distance = (target - position) * size
        // Flutter starts no simulation when already there.
        if (distance == 0f) return 0f
        var scrolled = 0f
        val animation = AnimationState(initialValue = 0f, initialVelocity = initialVelocity)
        onRemainingDistanceUpdated(distance)
        animation.animateTo(distance, spring(dampingRatio = 1.1f, stiffness = 200f)) {
            val delta = value - scrolled
            val consumed = scrollBy(delta)
            scrolled += consumed
            onRemainingDistanceUpdated(distance - scrolled)
            // An edge stopped it.
            if (abs(delta - consumed) > 0.5f) cancelAnimation()
        }
        return if (abs(distance - scrolled) > 0.5f) animation.velocity else 0f
    }
}
