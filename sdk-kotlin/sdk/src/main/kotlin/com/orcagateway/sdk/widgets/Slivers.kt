package com.orcagateway.sdk.widgets

import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.exclude
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.onConsumedWindowInsetsChanged
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.SliverAppBarFrame
import com.orcagateway.core.render.SliverAppBarGeometry
import com.orcagateway.core.render.SliverItem
import com.orcagateway.core.render.SliverItems
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetView
import com.orcagateway.sdk.indexedSlots
import com.orcagateway.sdk.liveNode
import com.orcagateway.sdk.navigation.LocalOrcaNavigation
import com.orcagateway.sdk.style.Props
import kotlinx.coroutines.flow.collectLatest
import kotlin.math.max

/** The test tag of the drawn part of SliverAppBar [id]: as high as the bar shows, from the top of its view. */
internal fun sliverAppBarTag(id: String): String = "orca-sliver-app-bar-$id"

/** The test tag of the toolbar row of SliverAppBar [id]. */
internal fun sliverToolbarTag(id: String): String = "orca-sliver-toolbar-$id"

/** The opacity the toolbar row of a SliverAppBar is drawn at (Flutter's `AppBar.toolbarOpacity`), for tests. */
internal val SliverToolbarAlpha = SemanticsPropertyKey<Float>("OrcaSliverToolbarAlpha")

/** How long a `snap` bar takes to settle once the scroll has ended. */
private const val SNAP_MILLIS = 300

/**
 * Flutter `CustomScrollView` (structure_builders.dart
 * `_buildCustomScrollView`): ONE `LazyColumn` (`LazyRow` when
 * `scrollDirection` is `horizontal`) whose items are its slivers flattened
 * by the core's [SliverItems], each keyed by its item's key, so only what
 * is near the screen is composed:
 *
 * - a SliverList row, a SliverToBoxAdapter's child and any widget that is
 *   no sliver (Flutter throws) are box items, forced to the cross extent
 *   as ListView's rows;
 * - a SliverGrid gives one item per line of cells ([GridLineView]);
 * - a SliverAppBar that is the first sliver of a vertical view that is not
 *   reversed collapses over the content ([CollapsingBarScroll]); any other
 *   is a box of its full extent that scrolls with the rest
 *   ([SliverAppBarWidget]).
 *
 * `reverse`, `shrinkWrap`, the scroll axis with no limit (every item laid
 * out, nothing scrolls), the Scrollbar reports and the scroll triggers are
 * ListView's ([ListViewWidget], [LazyScrollReports]); the metrics are its
 * estimate from the items on screen, exact when all are one length. The
 * direct children are resolved here, each observing its own watches and
 * running its own lifecycle triggers ([liveNode]); one that is no sliver
 * is then drawn from that node, not resolved a second time.
 */
@Composable
internal fun CustomScrollViewWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val horizontal = node["scrollDirection"]?.stringValue == "horizontal"
    val reverse = Props.bool(node["reverse"]) ?: false
    val shrinkWrap = Props.bool(node["shrinkWrap"]) ?: false
    val slivers = ArrayList<ResolvedNode>(node.childIds.size)
    for (id in node.childIds) key(id) { liveNode(id, model)?.let(slivers::add) }
    val flat = SliverItems.of(slivers)
    val byId = slivers.associateBy { it.id }
    BoxWithConstraints(modifier, propagateMinConstraints = true) {
        val bounded = if (horizontal) constraints.hasBoundedWidth else constraints.hasBoundedHeight
        val across = if (horizontal) constraints.hasBoundedHeight else constraints.hasBoundedWidth
        val view = SliverView(
            model, byId, horizontal, reverse,
            collapsingId = flat.collapsingBarId?.takeIf { bounded && !horizontal && !reverse },
            cross = if (!across) 0.dp else if (horizontal) maxHeight else maxWidth,
            // A bar that does not collapse in a horizontal view is as wide as the view.
            barWidth = if (horizontal && bounded) maxWidth else null,
        )
        if (!bounded) {
            val items = if (reverse) flat.items.asReversed() else flat.items
            // Not scrolling, but still the scroll view a Scrollbar around it follows: nothing inside reports.
            CompositionLocalProvider(LocalScrollbarHost provides null) {
                if (horizontal) {
                    Row(Modifier.fillMaxHeight()) { for (item in items) key(item.key) { view.Item(item, spacer = null) } }
                } else {
                    Column(Modifier.fillMaxWidth()) { for (item in items) key(item.key) { view.Item(item, spacer = null) } }
                }
            }
        } else {
            val state = rememberLazyListState()
            val fill = viewSize(horizontal, shrinkWrap)
            val bar = view.collapsingId?.let(byId::get)
            LazyScrollReports(node, model, state, horizontal, reverse, { density -> state.metrics(density) }) {
                when {
                    bar != null -> CollapsingBarScroll(bar, model, state, fill) { spacer -> sliverItems(flat.items, view, spacer) }
                    horizontal -> LazyRow(fill, state, reverseLayout = reverse) { sliverItems(flat.items, view, null) }
                    else -> LazyColumn(fill, state, reverseLayout = reverse) { sliverItems(flat.items, view, null) }
                }
            }
        }
    }
}

/** The lazy items of [items], each keyed by its key; [spacer] is how long the collapsing bar's place is. */
private fun LazyListScope.sliverItems(items: List<SliverItem>, view: SliverView, spacer: Dp?) {
    items(items, key = { it.key }, contentType = { it::class }) { view.Item(it, spacer) }
}

/** What draws one item of a CustomScrollView: the view's axis, direction and cross extent, and its direct children by id. */
private class SliverView(
    val model: OrcaPageModel,
    val slivers: Map<String, ResolvedNode>,
    val horizontal: Boolean,
    val reverse: Boolean,
    /** The bar that collapses over the view, when it has one. */
    val collapsingId: String?,
    val cross: Dp,
    val barWidth: Dp?,
) {
    /**
     * [item] as the view draws it. The bar that collapses is only its
     * place here, a [spacer] as long as the bar's full extent; the bar
     * itself is drawn over the view. A box that is a direct child of the
     * view (no sliver) is drawn from the node the view resolved; a row or an
     * adapter's child is found here.
     */
    @Composable
    fun Item(item: SliverItem, spacer: Dp?) {
        val box = if (horizontal) Modifier.fillMaxHeight() else Modifier.fillMaxWidth()
        when (item) {
            is SliverItem.Box -> {
                val direct = slivers[item.id]
                if (direct != null) WidgetView(direct, model, box) else NodeView(item.id, model, box)
            }
            is SliverItem.GridLine -> slivers[item.gridId]?.let { GridLineView(item, it, this) }
            is SliverItem.Bar -> when {
                spacer != null && item.id == collapsingId -> Spacer(Modifier.height(spacer))
                else -> slivers[item.id]?.let {
                    SliverAppBarWidget(it, model, barWidth?.let(Modifier::width) ?: Modifier.fillMaxWidth())
                }
            }
        }
    }
}

/**
 * One line of a SliverGrid in its CustomScrollView: up to `crossAxisCount`
 * cells, each forced to the size and placed at the cross offset the core's
 * GridCells gives in a grid as wide as the view (the numbers of GridView,
 * [gridCells]), with `mainAxisSpacing` after the line unless it is the
 * grid's last: toward the far end, so before it in a reversed view.
 */
@Composable
private fun GridLineView(line: SliverItem.GridLine, grid: ResolvedNode, view: SliverView) {
    val cells = gridCells(grid, view.horizontal)
    val cross = view.cross.value.toDouble()
    val gap = if (line.isLast) 0.0 else cells.mainAxisSpacing
    Layout(content = { for (id in line.cellIds) key(id) { NodeView(id, view.model) } }) { measurables, _ ->
        val frames = measurables.indices.map { cells.frame(it, cross, cross) }
        val placeables = measurables.mapIndexed { index, measurable ->
            measurable.measure(Constraints.fixed(frames[index].width.dp.roundToPx(), frames[index].height.dp.roundToPx()))
        }
        val cell = cells.frame(0, cross, cross)
        val gapPx = gap.dp.roundToPx()
        val before = if (view.reverse) gapPx else 0
        val crossPx = view.cross.roundToPx()
        val width = if (view.horizontal) cell.width.dp.roundToPx() + gapPx else crossPx
        val height = if (view.horizontal) crossPx else cell.height.dp.roundToPx() + gapPx
        layout(width, height) {
            placeables.forEachIndexed { index, placeable ->
                val x = frames[index].x.dp.roundToPx() + if (view.horizontal) before else 0
                val y = frames[index].y.dp.roundToPx() + if (view.horizontal) 0 else before
                placeable.placeRelative(x, y)
            }
        }
    }
}

/**
 * A vertical lazy list under the SliverAppBar [bar] that collapses over
 * it. The list's first item is a spacer as long as the bar's full extent
 * ([content] is given that length), so the content below is pushed by
 * max(0, maxExtent - offset) as Flutter's for every variant, and the bar is
 * drawn over the top of the list at the frame the core's
 * [SliverAppBarGeometry] gives ([BarScroll]).
 *
 * The top padding is the status bar's inset where no ancestor has taken it
 * (a Scaffold pads its body below the status bar and consumes it), Flutter's
 * `MediaQuery.padding.top`; else 0.
 */
@Composable
private fun CollapsingBarScroll(
    bar: ResolvedNode,
    model: OrcaPageModel,
    state: LazyListState,
    fill: Modifier,
    content: LazyListScope.(spacer: Dp) -> Unit,
) {
    val density = LocalDensity.current
    var consumed by remember { mutableStateOf(WindowInsets(0, 0, 0, 0)) }
    val top = with(density) { WindowInsets.statusBars.exclude(consumed).getTop(this).toDp() }
    val shape = BarShape.of(bar, top.value.toDouble())
    val scroll = remember(shape, state, density.density) {
        BarScroll(shape.geometry(), state, density.density).also { Snapshot.withoutReadObservation(it::sync) }
    }
    LaunchedEffect(scroll) {
        // Every move of the list, a finger's or not; a finger's has already been taken in onPostScroll.
        snapshotFlow { state.firstVisibleItemIndex to state.firstVisibleItemScrollOffset }.collect { scroll.sync() }
    }
    LaunchedEffect(scroll) {
        snapshotFlow { state.isScrollInProgress }.collectLatest { moving -> if (!moving) scroll.settle() }
    }
    Box(Modifier.onConsumedWindowInsetsChanged { consumed = it }.nestedScroll(scroll)) {
        LazyColumn(fill, state) { content(scroll.geometry.maxExtent.dp) }
        SliverBar(bar, model, scroll.frame, top, Modifier)
    }
}

/** The props of a SliverAppBar that shape its geometry, and the top padding it reaches under. */
private data class BarShape(
    val pinned: Boolean,
    val floating: Boolean,
    val snap: Boolean,
    val expandedHeight: Double?,
    val collapsedHeight: Double?,
    val topPadding: Double,
) {
    fun geometry(): SliverAppBarGeometry = SliverAppBarGeometry(pinned, floating, snap, expandedHeight, collapsedHeight, topPadding)

    companion object {
        fun of(bar: ResolvedNode, topPadding: Double): BarShape = BarShape(
            pinned = Props.bool(bar["pinned"]) ?: false,
            floating = Props.bool(bar["floating"]) ?: false,
            snap = Props.bool(bar["snap"]) ?: false,
            expandedHeight = Props.number(bar["expandedHeight"]),
            collapsedHeight = Props.number(bar["collapsedHeight"]),
            topPadding = topPadding,
        )
    }
}

/**
 * Feeds the scroll of [state] to [geometry] and holds the [frame] to draw.
 *
 * While the bar's spacer (item 0) is the first item on screen the scroll
 * offset is exact: how far the spacer has scrolled. Once it is gone a lazy
 * list no longer knows its offset, so a running one is kept from what each
 * drag and fling consumed ([onPostScroll]), never below the bar's full
 * extent: that is what lets a floating bar come back by exactly as much as
 * the finger drags back (the semantics scroll action is a drag to
 * Compose, and counts).
 *
 * A move with no delta there (`scrollToItem`, a scrolled position restored
 * with the list's state) moves the bar while the spacer is on screen; past
 * it, the running offset is raised to an estimate of the list's ([past])
 * when that is larger, and never lowered. So the bar the list has left
 * behind closes, a drag back after a jump or a restore brings a floating
 * bar in by as much as the finger moves, and a jump back does not float it
 * in, as Flutter's. After a jump back the running offset is ahead of the
 * list's, so when the spacer next comes on screen a floating bar may open
 * further than Flutter's would.
 *
 * The estimate must not undo what a drag's delta gave, so the position a
 * drag left ([seen]) is no move when the list reports it afterwards. Only a
 * drag records it: the first [sync] of a restored list runs before the list
 * is laid out, when nothing can be estimated, and the report that follows
 * the layout, at that same position, is the one that raises the offset.
 */
private class BarScroll(val geometry: SliverAppBarGeometry, val state: LazyListState, val density: Float) : NestedScrollConnection {
    var frame: SliverAppBarFrame by mutableStateOf(geometry.frame)
        private set

    private var running = 0.0

    /** The list's first item and its offset when a drag or fling last moved it: that position reported again is no move. */
    private var seen: Pair<Int, Int>? = null

    /** Take the list's position, [consumedPx] further along when a drag or fling has just moved it. */
    fun sync(consumedPx: Float = 0f) {
        val at = state.firstVisibleItemIndex to state.firstVisibleItemScrollOffset
        running = when {
            at.first == 0 -> at.second / density.toDouble()
            consumedPx != 0f -> max(running + consumedPx / density, geometry.maxExtent)
            // The move a drag made has been taken with its delta; the estimate must not undo it.
            at == seen -> running
            else -> max(running, past(at))
        }
        if (consumedPx != 0f) seen = at
        frame = geometry.scrollTo(running)
    }

    /**
     * The scroll offset with the spacer gone and [at] first on screen: the
     * spacer's own length, the items between it and that one at the average
     * length of those on screen, and how far that one has scrolled. Exact
     * when the items are one length, whatever the bar's; the bar's full
     * extent before the list is laid out.
     */
    private fun past(at: Pair<Int, Int>): Double {
        val rows = state.layoutInfo.visibleItemsInfo.filter { it.index != 0 }
        if (rows.isEmpty()) return geometry.maxExtent
        val stride = rows.sumOf { it.size }.toDouble() / rows.size
        return geometry.maxExtent + ((at.first - 1) * stride + at.second) / density
    }

    override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
        if (consumed.y != 0f) sync(-consumed.y)
        return Offset.Zero
    }

    /**
     * The scroll has ended: a `snap` bar goes to where the core settles it
     * ([SliverAppBarGeometry.released]), the drawn frame moving there over
     * [SNAP_MILLIS]; any other bar stays. A new scroll cuts it short.
     */
    suspend fun settle() {
        val from = frame
        val to = geometry.released()
        if (to == from) return
        try {
            animate(0f, 1f, animationSpec = tween(SNAP_MILLIS)) { t, _ ->
                fun mix(a: Double, b: Double): Double = a + (b - a) * t
                frame = SliverAppBarFrame(mix(from.paint, to.paint), to.layout, mix(from.box, to.box), mix(from.toolbarOpacity, to.toolbarOpacity))
            }
        } finally {
            if (frame != geometry.frame) frame = geometry.frame
        }
    }
}

/**
 * Flutter `SliverAppBar` (structure_builders.dart `_buildSliverAppBar`)
 * where it does not collapse: not the first sliver, in a horizontal or
 * reversed view, in a view with no limit, or outside a CustomScrollView
 * (Flutter throws). A box of the bar's full extent (`expandedHeight`, else
 * the toolbar's 56, never below `collapsedHeight`) with the bar's content,
 * no top padding.
 */
@Composable
internal fun SliverAppBarWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val shape = BarShape.of(node, topPadding = 0.0)
    SliverBar(node, model, remember(shape) { shape.geometry().frame }, 0.dp, modifier.fillMaxWidth())
}

/**
 * A SliverAppBar drawn at [frame] (no Material top app bar: none honours
 * `expandedHeight`, `collapsedHeight`, `floating` or a raw
 * `flexibleSpace`). The drawn part is `frame.paint` high and clips the
 * bar's box, `frame.box` high with its bottom edge at the bottom of the
 * drawn part, so a bar that slides out is cut off at the top. In the box:
 * `backgroundColor`, else the surface colour AppBar has; the
 * `flexibleSpace` slot, raw, as wide as the box, at most as high and at
 * its top (Flutter's persistent header gives the bar a height from 0 to
 * the box's and AppBar passes that on in a passthrough Stack: a slot that
 * expands fills the box, any other keeps its height); and under
 * [topPadding] the toolbar row ([SliverToolbar]), 56 high, at
 * `frame.toolbarOpacity`.
 *
 * `elevation` draws nothing: SliverAppBar has no `shadowColor`, and as
 * AppBar's ([AppBarWidget]) a shadow with no colour is Flutter's
 * transparent Material 3 one.
 */
@Composable
private fun SliverBar(node: ResolvedNode, model: OrcaPageModel, frame: SliverAppBarFrame, topPadding: Dp, modifier: Modifier) {
    val background = Props.color(node["backgroundColor"]) ?: MaterialTheme.colorScheme.surface
    val opacity = frame.toolbarOpacity.toFloat()
    Box(modifier.fillMaxWidth().height(frame.paint.dp).clipToBounds().testTag(sliverAppBarTag(node.id))) {
        Box(
            Modifier
                .wrapContentHeight(Alignment.Bottom, unbounded = true)
                .fillMaxWidth()
                .height(frame.box.dp)
                .background(background),
        ) {
            node.slots["flexibleSpace"]?.let { NodeView(it, model, Modifier.fillMaxWidth()) }
            SliverToolbar(
                node, model,
                Modifier
                    .padding(top = topPadding)
                    .fillMaxWidth()
                    .height(SliverAppBarGeometry.TOOLBAR_HEIGHT.dp)
                    .alpha(opacity)
                    .testTag(sliverToolbarTag(node.id))
                    .semantics { set(SliverToolbarAlpha, opacity) },
            )
        }
    }
}

/**
 * The toolbar row of a SliverAppBar, as Flutter's NavigationToolbar lays
 * out AppBar's ([AppBarWidget]): the `leading` slot forced to a box 56
 * square at the start (with none, on a pushed page, a back arrow that goes
 * back); the `title` slot in the bar's title style, 16 past the leading
 * box, or in the middle of the row when `centerTitle` is true (Android's
 * default is the start); the `action_0` … slots in order at the end,
 * stopping at the first gap.
 */
@Composable
private fun SliverToolbar(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val navigation = LocalOrcaNavigation.current
    val leading = node.slots["leading"]
    val centered = node["centerTitle"]?.boolValue == true
    val colors = MaterialTheme.colorScheme
    val title: @Composable () -> Unit = {
        node.slots["title"]?.let { ProvideTextStyle(MaterialTheme.typography.titleLarge) { NodeView(it, model) } }
    }
    CompositionLocalProvider(LocalContentColor provides colors.onSurface) {
        Box(modifier) {
            Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                if (leading != null || navigation.canPop) {
                    Box(Modifier.size(56.dp), contentAlignment = Alignment.Center, propagateMinConstraints = leading != null) {
                        if (leading != null) {
                            NodeView(leading, model)
                        } else {
                            IconButton(onClick = navigation::goBack) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                            }
                        }
                    }
                }
                Box(Modifier.weight(1f).padding(horizontal = 16.dp)) { if (!centered) title() }
                CompositionLocalProvider(LocalContentColor provides colors.onSurfaceVariant) {
                    for (id in indexedSlots(node, "action")) NodeView(id, model)
                }
            }
            if (centered) Box(Modifier.align(Alignment.Center)) { title() }
        }
    }
}

/** Flutter `SliverList` outside a CustomScrollView (Flutter throws): its children one below the other, each at the cross extent. */
@Composable
internal fun SliverListWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    Column(modifier) { for (id in node.childIds) key(id) { NodeView(id, model, Modifier.fillMaxWidth()) } }
}

/** Flutter `SliverGrid` outside a CustomScrollView (Flutter throws): every cell where the core's GridCells puts it, as a GridView with no limit. */
@Composable
internal fun SliverGridWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    EagerGrid(node, model, gridCells(node, horizontal = false), modifier)
}

/** Flutter `SliverToBoxAdapter` outside a CustomScrollView (Flutter throws): its child, or nothing. */
@Composable
internal fun SliverToBoxAdapterWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    ChildView(node, model, modifier)
}
