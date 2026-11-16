package com.orcagateway.core.render

import kotlin.math.max

/** One lazy item of a CustomScrollView's single scroll view. */
public sealed class SliverItem {
    /** Stable across renders and unique in the scroll view: a node id, or a grid's id and line index. */
    public abstract val key: String

    /** Node [id] drawn at the cross extent: a SliverList row, a SliverToBoxAdapter's child, or a stray widget. */
    public data class Box(public val id: String) : SliverItem() {
        override val key: String get() = id
    }

    /**
     * Line [line] of SliverGrid [gridId]: [cellIds] in order, as many as
     * the grid has across but for a shorter last line. `mainAxisSpacing`
     * follows every line except the last ([isLast]).
     */
    public data class GridLine(
        public val gridId: String,
        public val line: Int,
        public val cellIds: List<String>,
        public val isLast: Boolean,
    ) : SliverItem() {
        override val key: String get() = "$gridId#$line"
    }

    /** SliverAppBar [id]. */
    public data class Bar(public val id: String) : SliverItem() {
        override val key: String get() = id
    }
}

/**
 * A CustomScrollView's direct children flattened into the ordered lazy
 * [items] of ONE scroll view, so the view holds no arithmetic. Flutter
 * nests them as slivers (structure_builders.dart `_buildCustomScrollView`,
 * `_buildSliverList`, `_buildSliverGrid`, `_buildSliverToBoxAdapter`,
 * `_buildSliverAppBar`):
 *
 * - SliverList: a [SliverItem.Box] per child.
 * - SliverGrid: a [SliverItem.GridLine] per line of `crossAxisCount` cells
 *   (2 when absent; below 1 is 1, as [GridCells]); 5 cells at 2 across are
 *   3 lines, the last with 1 cell.
 * - SliverToBoxAdapter: a [SliverItem.Box] of its first child; no child,
 *   no item.
 * - SliverAppBar: a [SliverItem.Bar].
 * - anything else: a [SliverItem.Box] of the widget itself (Flutter
 *   throws; it is drawn).
 *
 * The Swift twin (`SliverItems.swift`) pins the same cases.
 */
public data class SliverItems(
    public val items: List<SliverItem>,
    /**
     * The id of the bar that collapses over the content: a SliverAppBar that is the
     * FIRST direct child, else null (a bar anywhere else scrolls as a box).
     * The view also needs a vertical, non-reversed scroll for it.
     */
    public val collapsingBarId: String?,
) {
    public companion object {
        /** The items of the direct [children], in order. */
        public fun of(children: List<ResolvedNode>): SliverItems {
            val items = buildList {
                for (child in children) {
                    when (child.type) {
                        "SliverList" -> child.childIds.forEach { add(SliverItem.Box(it)) }
                        "SliverGrid" -> addAll(gridLines(child))
                        "SliverToBoxAdapter" -> child.childIds.firstOrNull()?.let { add(SliverItem.Box(it)) }
                        "SliverAppBar" -> add(SliverItem.Bar(child.id))
                        else -> add(SliverItem.Box(child.id))
                    }
                }
            }
            val first = children.firstOrNull()?.takeIf { it.type == "SliverAppBar" }
            return SliverItems(items, first?.id)
        }

        private fun gridLines(grid: ResolvedNode): List<SliverItem.GridLine> {
            val across = max(grid["crossAxisCount"]?.doubleValue?.toInt() ?: 2, 1)
            val lines = grid.childIds.chunked(across)
            return lines.mapIndexed { line, cells -> SliverItem.GridLine(grid.id, line, cells, isLast = line == lines.lastIndex) }
        }
    }
}
