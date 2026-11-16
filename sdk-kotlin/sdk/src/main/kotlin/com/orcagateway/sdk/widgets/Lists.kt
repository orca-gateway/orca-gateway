package com.orcagateway.sdk.widgets

import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.ScrollableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyHorizontalGrid
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.GridPadding
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.ScrollEvent
import com.orcagateway.core.render.ScrollMetrics
import com.orcagateway.core.render.ScrollObserver
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Insets
import com.orcagateway.sdk.style.Props
import kotlin.math.max
import androidx.compose.foundation.lazy.grid.GridCells as ComposeGridCells
import androidx.compose.foundation.lazy.grid.items as gridItems
import com.orcagateway.core.render.GridCells as OrcaGridCells

/**
 * Flutter `ListView` (structure_builders.dart:161-202): a `LazyColumn`, or
 * a `LazyRow` when `scrollDirection` is `horizontal`, so only the children
 * on screen are composed. Flutter also builds 250 px past each end of the
 * view (rendering/viewport.dart:289). Compose's counterpart,
 * `LazyLayoutCacheWindow`, is experimental and built no extra row in the
 * Robolectric tests, so it is not used: past the screen there is only
 * Compose's default prefetch of the next row in the scroll direction.
 * Each child is forced to the list's cross extent, and to `itemExtent` on
 * the main axis when set (SliverFixedExtentList). `padding` is inside the
 * scroll extent; `reverse` puts the first child and offset 0 at the far
 * end (Compose's `reverseLayout`). The list fills its parent as Flutter's
 * viewport does; `shrinkWrap` hugs its content on the scroll axis, up to
 * the limit, and stays lazy as Flutter's ShrinkWrappingViewport. On a
 * scroll axis with no limit (a list in a Column) every child is laid out
 * in a Column (Row) that does not scroll: what Flutter's
 * ShrinkWrappingViewport does with `shrinkWrap` (viewport.dart:2151-2156);
 * without it Flutter throws. A null padding adds no safe-area inset
 * (Flutter's BoxScrollView adds the MediaQuery padding on the scroll axis,
 * widgets/scroll_view.dart:911-944). `primary` has no Android counterpart
 * and `separator` arrives as a raw widget Flutter cannot read: both
 * ignored. A node with a scroll trigger gets [LazyScrollTriggers].
 */
@Composable
internal fun ListViewWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val horizontal = node["scrollDirection"]?.stringValue == "horizontal"
    val reverse = Props.bool(node["reverse"]) ?: false
    val shrinkWrap = Props.bool(node["shrinkWrap"]) ?: false
    val padding = (Props.insets(node["padding"]) ?: Insets.Zero).paddingValues()
    val extent = Props.length(node["itemExtent"])
    val item = when {
        horizontal -> Modifier.fillMaxHeight().then(extent?.let { Modifier.width(it) } ?: Modifier)
        else -> Modifier.fillMaxWidth().then(extent?.let { Modifier.height(it) } ?: Modifier)
    }
    BoxWithConstraints(modifier, propagateMinConstraints = true) {
        val bounded = if (horizontal) constraints.hasBoundedWidth else constraints.hasBoundedHeight
        if (!bounded) {
            val children = if (reverse) node.childIds.asReversed() else node.childIds
            if (horizontal) {
                Row(Modifier.fillMaxHeight().padding(padding)) { for (id in children) NodeView(id, model, item) }
            } else {
                Column(Modifier.fillMaxWidth().padding(padding)) { for (id in children) NodeView(id, model, item) }
            }
        } else {
            val state = rememberLazyListState()
            if (hasScrollTriggers(node)) LazyScrollTriggers(node, model, state) { density -> state.metrics(density) }
            val fill = viewSize(horizontal, shrinkWrap)
            if (horizontal) {
                LazyRow(fill, state, padding, reverseLayout = reverse) { items(node.childIds) { NodeView(it, model, item) } }
            } else {
                LazyColumn(fill, state, padding, reverseLayout = reverse) { items(node.childIds) { NodeView(it, model, item) } }
            }
        }
    }
}

/**
 * Flutter `GridView.count` (structure_builders.dart:204-227): a
 * `LazyVerticalGrid` (`LazyHorizontalGrid` when horizontal) of
 * `crossAxisCount` (2) lines with the spacings between cells (0) and
 * `padding` inside the scroll extent; each child is forced to the cell
 * size the core's [OrcaGridCells] gives (cross extent shared, main extent
 * by `childAspectRatio`, 1). Only the cells on screen are composed, with no
 * 250 px cache, as ListView. It fills its parent, or hugs its content on
 * the scroll axis with `shrinkWrap`. With no limit on the scroll axis every
 * cell is laid out where the core puts it and nothing scrolls: what
 * Flutter's ShrinkWrappingViewport does with `shrinkWrap`; without it, or
 * with no limit across, Flutter throws, and here an unbounded cross axis
 * gives empty cells. A null padding adds no safe-area inset (Flutter's
 * BoxScrollView adds the MediaQuery padding on the scroll axis,
 * widgets/scroll_view.dart:911-944). `primary` is ignored; GridView has no
 * `reverse`. A node with a scroll trigger gets [LazyScrollTriggers].
 */
@Composable
internal fun GridViewWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val horizontal = node["scrollDirection"]?.stringValue == "horizontal"
    val shrinkWrap = Props.bool(node["shrinkWrap"]) ?: false
    val insets = Props.insets(node["padding"]) ?: Insets.Zero
    val mainSpacing = max(Props.number(node["mainAxisSpacing"]) ?: 0.0, 0.0)
    val crossSpacing = max(Props.number(node["crossAxisSpacing"]) ?: 0.0, 0.0)
    val cells = OrcaGridCells(
        crossAxisCount = Props.number(node["crossAxisCount"])?.toInt() ?: 2,
        mainAxisSpacing = mainSpacing,
        crossAxisSpacing = crossSpacing,
        childAspectRatio = Props.number(node["childAspectRatio"]) ?: 1.0,
        horizontal = horizontal,
        padding = GridPadding(insets.top, insets.left, insets.bottom, insets.right),
    )
    BoxWithConstraints(modifier, propagateMinConstraints = true) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
            EagerGrid(node, model, cells)
        } else {
            val cell = cells.frame(0, maxWidth.value.toDouble(), maxHeight.value.toDouble())
            val item = Modifier.size(cell.width.dp, cell.height.dp)
            val state = rememberLazyGridState()
            if (hasScrollTriggers(node)) {
                LazyScrollTriggers(node, model, state) { density -> state.metrics(density, cells.crossCount) }
            }
            val fill = viewSize(horizontal, shrinkWrap)
            val lines = ComposeGridCells.Fixed(cells.crossCount)
            val padding = insets.paddingValues()
            if (horizontal) {
                LazyHorizontalGrid(
                    lines, fill, state, padding,
                    horizontalArrangement = Arrangement.spacedBy(mainSpacing.dp),
                    verticalArrangement = Arrangement.spacedBy(crossSpacing.dp),
                ) { gridItems(node.childIds) { NodeView(it, model, item) } }
            } else {
                LazyVerticalGrid(
                    lines, fill, state, padding,
                    verticalArrangement = Arrangement.spacedBy(mainSpacing.dp),
                    horizontalArrangement = Arrangement.spacedBy(crossSpacing.dp),
                ) { gridItems(node.childIds) { NodeView(it, model, item) } }
            }
        }
    }
}

/**
 * Every cell of a grid with no limit on an axis, each forced to the box
 * [cells] gives it: as wide as the limit across (0 with none), as long as
 * its rows. Placed relative, so a right-to-left layout mirrors it as
 * Flutter's reversed cross axis does.
 */
@Composable
private fun EagerGrid(node: ResolvedNode, model: OrcaPageModel, cells: OrcaGridCells) {
    Layout(content = { for (id in node.childIds) NodeView(id, model) }) { measurables, constraints ->
        val width = if (constraints.hasBoundedWidth) constraints.maxWidth.toDp().value.toDouble() else 0.0
        val height = if (constraints.hasBoundedHeight) constraints.maxHeight.toDp().value.toDouble() else 0.0
        val frames = measurables.indices.map { cells.frame(it, width, height) }
        val placeables = measurables.mapIndexed { index, measurable ->
            val frame = frames[index]
            measurable.measure(Constraints.fixed(frame.width.dp.roundToPx(), frame.height.dp.roundToPx()))
        }
        val main = cells.contentExtent(measurables.size, width, height).dp.roundToPx()
        val layoutWidth = if (cells.horizontal) main else width.dp.roundToPx()
        val layoutHeight = if (cells.horizontal) height.dp.roundToPx() else main
        layout(constraints.constrainWidth(layoutWidth), constraints.constrainHeight(layoutHeight)) {
            placeables.forEachIndexed { index, placeable ->
                placeable.placeRelative(frames[index].x.dp.roundToPx(), frames[index].y.dp.roundToPx())
            }
        }
    }
}

/**
 * A lazy list's or grid's size: its parent's whole box, as Flutter's
 * viewport, or with [shrinkWrap] only across, hugging its content along
 * the scroll axis.
 */
private fun viewSize(horizontal: Boolean, shrinkWrap: Boolean): Modifier = when {
    !shrinkWrap -> Modifier.fillMaxSize()
    horizontal -> Modifier.fillMaxHeight()
    else -> Modifier.fillMaxWidth()
}

private fun hasScrollTriggers(node: ResolvedNode): Boolean = node.actions.keys.any { it in ScrollEvent.TRIGGERS }

/**
 * onScrollBegin, onScrolling and onScrollEnd of a lazy list or grid,
 * Flutter `wrapScrollNotifier`, as SingleChildScrollView's (Layout.kt):
 * each change of [metrics] (at the screen's density) or of [state]'s
 * `isScrollInProgress` goes through a [ScrollObserver]. It draws nothing.
 */
@Composable
private fun LazyScrollTriggers(
    node: ResolvedNode,
    model: OrcaPageModel,
    state: ScrollableState,
    metrics: (density: Double) -> ScrollMetrics,
) {
    val current = rememberUpdatedState(node)
    val measure = rememberUpdatedState(metrics)
    val density = LocalDensity.current.density.toDouble()
    LaunchedEffect(model, state, density) {
        val observer = ScrollObserver()
        snapshotFlow { measure.value(density) to state.isScrollInProgress }.collect { (sample, inProgress) ->
            for (event in observer.observe(sample, inProgress)) model.fire(event.trigger, current.value, event.eventData)
        }
    }
}

/**
 * Flutter's metrics of a lazy list. Compose knows only the rows on screen,
 * so the rows before them and the content's length take their average
 * length: exact with `itemExtent` or rows of one length, an estimate
 * otherwise.
 */
private fun LazyListState.metrics(density: Double): ScrollMetrics {
    val info = layoutInfo
    val rows = info.visibleItemsInfo
    val stride = if (rows.isEmpty()) 0.0 else rows.sumOf { it.size }.toDouble() / rows.size + info.mainAxisItemSpacing
    val horizontal = info.orientation == Orientation.Horizontal
    return lazyMetrics(
        line = firstVisibleItemIndex, lineOffset = firstVisibleItemScrollOffset, stride = stride,
        lines = info.totalItemsCount, spacing = info.mainAxisItemSpacing,
        padding = info.beforeContentPadding + info.afterContentPadding,
        viewport = if (horizontal) info.viewportSize.width else info.viewportSize.height, density = density,
    )
}

/** Flutter's metrics of a lazy grid of [perLine] cells a row, exact: every row is as long as the first on screen. */
private fun LazyGridState.metrics(density: Double, perLine: Int): ScrollMetrics {
    val info = layoutInfo
    val horizontal = info.orientation == Orientation.Horizontal
    val cell = info.visibleItemsInfo.firstOrNull()?.size?.let { if (horizontal) it.width else it.height } ?: 0
    return lazyMetrics(
        line = firstVisibleItemIndex / perLine, lineOffset = firstVisibleItemScrollOffset,
        stride = (cell + info.mainAxisItemSpacing).toDouble(),
        lines = (info.totalItemsCount + perLine - 1) / perLine, spacing = info.mainAxisItemSpacing,
        padding = info.beforeContentPadding + info.afterContentPadding,
        viewport = if (horizontal) info.viewportSize.width else info.viewportSize.height, density = density,
    )
}

/**
 * Flutter's `ScrollMetrics` in dp from a lazy layout's pixels: the offset
 * is the [line]s before the first on screen plus how far that one has
 * scrolled; the content is the [padding] and [lines] lines of [stride],
 * less the [spacing] after the last.
 */
private fun lazyMetrics(
    line: Int,
    lineOffset: Int,
    stride: Double,
    lines: Int,
    spacing: Int,
    padding: Int,
    viewport: Int,
    density: Double,
): ScrollMetrics {
    val content = padding + if (lines > 0) lines * stride - spacing else 0.0
    return ScrollMetrics(
        offset = (line * stride + lineOffset) / density,
        maxExtent = max(0.0, content - viewport) / density,
        viewportDimension = viewport / density,
    )
}
