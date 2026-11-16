package com.orcagateway.sdk.widgets

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LocalPinnableContainer
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.ItemSpan
import com.orcagateway.core.render.ReorderDrop
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.ScrollEvent
import com.orcagateway.core.render.ScrollMetrics
import com.orcagateway.core.render.ScrollObserver
import com.orcagateway.sdk.LocalOrcaFrozenNodes
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Insets
import com.orcagateway.sdk.style.Props
import kotlinx.coroutines.flow.collectLatest
import kotlin.math.sign

/** How far a list scrolls per frame while a dragged row is held past its edge. */
private val AutoScrollStep = 8.dp

/** The lift of the row under the finger. */
private val DraggedElevation = 6.dp

/** How long the other rows take to make room. */
private const val MakeRoomMillis = 150

/**
 * Flutter `ReorderableListView` (layout_builders.dart:686-716): the children
 * in a scrolling list, a column, or a row with `scrollDirection:
 * "horizontal"`, `padding` inside the scrolled content. It fills the space
 * it is given and its rows span the cross axis, as a Flutter list.
 *
 * A long press picks a row up: it follows the finger, lifted, the rows it
 * passes make room, and a row held past an edge scrolls the list. Letting
 * go fires the node's `onReorder` with `{oldIndex, newIndex}`
 * ([ReorderDrop]: Flutter's raw newIndex), or nothing when the row is where
 * it was. The order is never changed here: after the drop every row is back
 * where the page has it, and the action (state, a component mutation)
 * changes the page. A row the page then moves glides to its place.
 *
 * The scroll triggers fire as on a SingleChildScrollView
 * ([ListScrollTriggers]). In a layer drawn from a snapshot
 * ([LocalOrcaFrozenNodes]) the list is still: no drag, no trigger. With
 * reduced motion the rows make room at once. On an axis with no limit (a
 * list inside a Column) Flutter fails to lay out and a lazy list would
 * throw; here the rows are drawn one after the other, with no scroll and no
 * drag.
 */
@Composable
internal fun ReorderableListWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val horizontal = node["scrollDirection"]?.stringValue == "horizontal"
    val padding = (Props.insets(node["padding"]) ?: Insets.Zero).paddingValues()
    val frozen = LocalOrcaFrozenNodes.current != null
    val still = frozen || orcaReduceMotion()
    BoxWithConstraints(modifier, propagateMinConstraints = true) {
        val bounded = if (horizontal) constraints.hasBoundedWidth else constraints.hasBoundedHeight
        if (!bounded) {
            if (horizontal) {
                Row(Modifier.padding(padding)) { for (id in node.childIds) NodeView(id, model) }
            } else {
                Column(Modifier.padding(padding)) { for (id in node.childIds) NodeView(id, model) }
            }
            return@BoxWithConstraints
        }
        val fillsWidth = constraints.hasBoundedWidth
        val fillsHeight = constraints.hasBoundedHeight
        val state = rememberLazyListState()
        val drag = remember(state) { ReorderDrag(state) }
        val current = rememberUpdatedState(node)
        if (!frozen) {
            if (node.actions.keys.any { it in ScrollEvent.TRIGGERS }) ListScrollTriggers(node, model, state)
            AutoScroll(drag, state)
        }
        val ids = node.childIds
        // Rows keep their state by node id as the page moves them; ids are
        // unique in a page, and a list naming one twice falls back to the index.
        val keyed = remember(ids) { ids.toSet().size == ids.size }
        val fill = Modifier
            .then(if (fillsWidth) Modifier.fillMaxWidth() else Modifier)
            .then(if (fillsHeight) Modifier.fillMaxHeight() else Modifier)
        val rowFill = when {
            horizontal -> if (fillsHeight) Modifier.fillMaxHeight() else Modifier
            else -> if (fillsWidth) Modifier.fillMaxWidth() else Modifier
        }
        val content: LazyListScope.() -> Unit = {
            itemsIndexed(ids, key = if (keyed) { _, id -> id } else null) { index, id ->
                val placement = if (still) Modifier else Modifier.animateItem(fadeInSpec = null, fadeOutSpec = null)
                ReorderableRow(
                    index = index,
                    drag = drag,
                    horizontal = horizontal,
                    still = still,
                    draggable = !frozen,
                    modifier = placement.then(rowFill),
                    onDrop = { event -> model.fire("onReorder", current.value, event) },
                    count = { current.value.childIds.size },
                ) { NodeView(id, model) }
            }
        }
        if (horizontal) {
            LazyRow(fill, state, contentPadding = padding, content = content)
        } else {
            LazyColumn(fill, state, contentPadding = padding, content = content)
        }
    }
}

/**
 * One row of the list. The gesture sits outside the layer that moves the
 * row, so the finger is read where the row was laid out and not where it is
 * drawn. A dragged row is pinned: the list keeps it, and its gesture, when
 * scrolling takes its place out of view.
 */
@Composable
private fun ReorderableRow(
    index: Int,
    drag: ReorderDrag,
    horizontal: Boolean,
    still: Boolean,
    draggable: Boolean,
    modifier: Modifier,
    onDrop: (Map<String, JsonValue>) -> Unit,
    count: () -> Int,
    content: @Composable () -> Unit,
) {
    val at = rememberUpdatedState(index)
    val drop = rememberUpdatedState(onDrop)
    // A horizontal list runs from the right in a right-to-left layout.
    val direction = if (horizontal && LocalLayoutDirection.current == LayoutDirection.Rtl) -1f else 1f
    val dragged = drag.from == index
    if (dragged) {
        val pinnable = LocalPinnableContainer.current
        DisposableEffect(pinnable) {
            val handle = pinnable?.pin()
            onDispose { handle?.release() }
        }
    }
    val room = ReorderDrop.displacement(index, drag.from, drag.slot) * drag.size
    val shift = animateFloatAsState(
        targetValue = room.toFloat(),
        animationSpec = if (still || drag.from < 0) snap() else tween(MakeRoomMillis),
        label = "reorder",
    )
    val elevation = with(LocalDensity.current) { DraggedElevation.toPx() }
    val gesture = if (!draggable) {
        Modifier
    } else {
        Modifier.pointerInput(drag, horizontal, direction) {
            detectDragGesturesAfterLongPress(
                onDragStart = { drag.begin(at.value) },
                onDrag = { _, amount ->
                    if (drag.from == at.value) drag.moveBy((if (horizontal) amount.x else amount.y) * direction)
                },
                onDragEnd = { if (drag.from == at.value) drag.end(count())?.let { drop.value(it) } },
                onDragCancel = { if (drag.from == at.value) drag.cancel() },
            )
        }
    }
    val placed = if (!dragged) {
        Modifier
    } else {
        Modifier.onPlaced { row ->
            val position = row.positionInParent()
            val list = row.parentLayoutCoordinates?.size
            drag.placedAt(
                when {
                    !horizontal -> position.y
                    direction < 0 && list != null -> list.width - position.x - row.size.width
                    else -> position.x
                },
            )
        }
    }
    Box(
        modifier
            .zIndex(if (dragged) 1f else 0f)
            .then(gesture)
            .then(placed)
            .graphicsLayer {
                val along = (if (dragged) drag.translation else shift.value) * direction
                if (horizontal) translationX = along else translationY = along
                shadowElevation = if (dragged) elevation else 0f
            },
        propagateMinConstraints = true,
    ) { content() }
}

/**
 * The row being dragged in one list, in the list's pixels along its axis.
 * It holds what the gesture gives it; [ReorderDrop] does the arithmetic.
 */
private class ReorderDrag(private val state: LazyListState) {
    /** The index of the row under the finger; -1 when none is. */
    var from by mutableIntStateOf(-1)
        private set

    /** That row's length. */
    var size by mutableIntStateOf(0)
        private set

    /** Where the row lay in the view when it was picked up. */
    private var start = 0

    /** How far the finger has moved since. */
    private var finger by mutableFloatStateOf(0f)

    /**
     * Where the list has the row now. It moves as the list scrolls under
     * the held row, and not by the scroll alone: a pinned row that left the
     * view is kept next to the rows in view, not where it would lie.
     */
    private var placed by mutableFloatStateOf(0f)

    /** How far to draw the row from where the list has it now, so that it stays under the finger. */
    val translation: Float get() = start + finger - placed

    /** The slot the row is over; -1 with no drag. */
    val slot: Int by derivedStateOf {
        if (from < 0) -1 else ReorderDrop.slot(spans(), from, start + size / 2.0 + finger)
    }

    private fun spans(): List<ItemSpan> =
        state.layoutInfo.visibleItemsInfo.map { ItemSpan(it.index, it.offset.toDouble(), it.size.toDouble()) }

    /** Pick row [index] up, unless another one is held. */
    fun begin(index: Int) {
        if (from >= 0) return
        val item = state.layoutInfo.visibleItemsInfo.firstOrNull { it.index == index } ?: return
        start = item.offset
        size = item.size
        finger = 0f
        placed = item.offset.toFloat()
        from = index
    }

    /** The list placed the held row [fromStart] past its own start edge (padding included). */
    fun placedAt(fromStart: Float) {
        placed = fromStart + state.layoutInfo.viewportStartOffset
    }

    fun moveBy(amount: Float) {
        finger += amount
    }

    /** Let go: the `onReorder` payload among [count] rows, or null when the row is where it was. */
    fun end(count: Int): Map<String, JsonValue>? {
        val event = ReorderDrop.event(from, slot, count)
        cancel()
        return event
    }

    fun cancel() {
        from = -1
        finger = 0f
        placed = start.toFloat()
    }

    /** How far to scroll this frame, [step] at most: what of the held row sticks out of the view. */
    fun overshoot(step: Float): Float {
        if (from < 0) return 0f
        val info = state.layoutInfo
        return ReorderDrop.autoScroll(
            start = (start + finger).toDouble(),
            size = size.toDouble(),
            viewportStart = info.viewportStartOffset.toDouble(),
            viewportEnd = info.viewportEndOffset.toDouble(),
            step = step.toDouble(),
        ).toFloat()
    }
}

/**
 * Scrolls the list, a step per frame, while the held row sticks out of the
 * view, until it no longer does or the list is at its end. It draws nothing.
 */
@Composable
private fun AutoScroll(drag: ReorderDrag, state: LazyListState) {
    val step = with(LocalDensity.current) { AutoScrollStep.toPx() }
    LaunchedEffect(drag, state, step) {
        snapshotFlow { drag.overshoot(step).sign }.collectLatest { way ->
            while (way != 0f) {
                withFrameNanos { }
                if (state.scrollBy(drag.overshoot(step)) == 0f) break
            }
        }
    }
}

/**
 * onScrollBegin, onScrolling and onScrollEnd of a list's node, as
 * [ScrollWidget]'s: each change of what [state] has in view, or of
 * `isScrollInProgress`, goes through a [ScrollObserver]. A lazy list knows
 * only the rows in view, so the payload comes from them
 * ([ScrollMetrics.ofItems]), in dp. It draws nothing.
 */
@Composable
private fun ListScrollTriggers(node: ResolvedNode, model: OrcaPageModel, state: LazyListState) {
    val current = rememberUpdatedState(node)
    val density = LocalDensity.current.density.toDouble()
    LaunchedEffect(model, state, density) {
        val observer = ScrollObserver()
        snapshotFlow {
            val info = state.layoutInfo
            ScrollMetrics.ofItems(
                items = info.visibleItemsInfo.map { ItemSpan(it.index, it.offset / density, it.size / density) },
                count = info.totalItemsCount,
                viewportStart = info.viewportStartOffset / density,
                viewportEnd = info.viewportEndOffset / density,
                paddingAfter = info.afterContentPadding / density,
            ) to state.isScrollInProgress
        }.collect { (metrics, inProgress) ->
            for (event in observer.observe(metrics, inProgress)) model.fire(event.trigger, current.value, event.eventData)
        }
    }
}
