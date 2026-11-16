package com.orcagateway.core.render

import kotlin.math.max

/** A GridView cell's box in the grid's scrolled content (padding included), in logical pixels. */
public data class GridFrame(public val x: Double, public val y: Double, public val width: Double, public val height: Double)

/** A GridView's `padding`: space inside its scroll extent around the cells, Flutter's SliverPadding. */
public data class GridPadding(
    public val top: Double = 0.0,
    public val left: Double = 0.0,
    public val bottom: Double = 0.0,
    public val right: Double = 0.0,
)

/**
 * Where a GridView's cells go, Flutter `GridView.count` as the builder
 * makes it (structure_builders.dart:204-227) with
 * `SliverGridDelegateWithFixedCrossAxisCount` and
 * `SliverGridRegularTileLayout` (rendering/sliver_grid.dart:171-262,
 * 390-405). The main axis is the scroll axis (down, or across when
 * [horizontal]). With the padding taken off the cross extent, each cell's
 * cross extent is (that extent - [crossAxisSpacing] x (n - 1)) / n, never
 * below 0, and its main extent that over [childAspectRatio], so a
 * horizontal grid reads the ratio as height / width. Cells fill a row
 * across, then the next one [mainAxisSpacing] further; every cell is
 * forced to that size (Flutter's tight constraints). A layout direction is
 * the caller's (Compose mirrors). A count below 1, a ratio not above 0 and
 * a negative spacing, which Flutter only asserts on, are 1, 1 and 0.
 */
public data class GridCells(
    public val crossAxisCount: Int = 2,
    public val mainAxisSpacing: Double = 0.0,
    public val crossAxisSpacing: Double = 0.0,
    public val childAspectRatio: Double = 1.0,
    public val horizontal: Boolean = false,
    public val padding: GridPadding = GridPadding(),
) {
    /** The cells across the grid (columns, or rows when [horizontal]). */
    public val crossCount: Int get() = max(crossAxisCount, 1)

    private val mainSpacing: Double get() = max(mainAxisSpacing, 0.0)
    private val crossSpacing: Double get() = max(crossAxisSpacing, 0.0)
    private val ratio: Double get() = if (childAspectRatio > 0.0 && childAspectRatio.isFinite()) childAspectRatio else 1.0

    /** Cell [index]'s box in a grid [width] by [height] (its viewport, padding included). */
    public fun frame(index: Int, width: Double, height: Double): GridFrame {
        val cross = cellCross(width, height)
        val main = cross / ratio
        val mainOffset = (index / crossCount) * (main + mainSpacing)
        val crossOffset = (index % crossCount) * (cross + crossSpacing)
        return if (horizontal) {
            GridFrame(padding.left + mainOffset, padding.top + crossOffset, main, cross)
        } else {
            GridFrame(padding.left + crossOffset, padding.top + mainOffset, cross, main)
        }
    }

    /**
     * The main-axis length of a grid of [count] cells, padding included:
     * Flutter `computeMaxScrollOffset` (whole rows, spacing between them)
     * plus the padding on the main axis.
     */
    public fun contentExtent(count: Int, width: Double, height: Double): Double {
        val paddings = if (horizontal) padding.left + padding.right else padding.top + padding.bottom
        if (count <= 0) return paddings
        val main = cellCross(width, height) / ratio
        val rows = (count - 1) / crossCount + 1
        return paddings + rows * (main + mainSpacing) - mainSpacing
    }

    /** Each cell's cross extent: Flutter's `usableCrossAxisExtent / crossAxisCount`. */
    private fun cellCross(width: Double, height: Double): Double {
        val extent = if (horizontal) height - padding.top - padding.bottom else width - padding.left - padding.right
        return max(0.0, extent - crossSpacing * (crossCount - 1)) / crossCount
    }
}
