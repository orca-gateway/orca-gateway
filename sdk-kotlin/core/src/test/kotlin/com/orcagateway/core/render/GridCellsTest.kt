package com.orcagateway.core.render

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * A5.3: GridView's cells against Flutter's `GridView.count` builder
 * (structure_builders.dart:204-227: crossAxisCount 2, spacings 0,
 * childAspectRatio 1 by default), `SliverGridDelegateWithFixedCrossAxisCount`
 * and `SliverGridRegularTileLayout` (rendering/sliver_grid.dart:171-262,
 * 390-405): cross = (usable cross extent - crossSpacing x (n - 1)) / n,
 * main = cross / ratio, the padding (a SliverPadding) taken off first.
 * Frames are (x, y, width, height) in the grid's scrolled content.
 */
class GridCellsTest {
    private fun assertFrame(x: Number, y: Number, width: Number, height: Number, actual: GridFrame, label: String) {
        assertEquals(x.toDouble(), actual.x, 1e-9, "$label x")
        assertEquals(y.toDouble(), actual.y, 1e-9, "$label y")
        assertEquals(width.toDouble(), actual.width, 1e-9, "$label width")
        assertEquals(height.toDouble(), actual.height, 1e-9, "$label height")
    }

    /** A5.3 (kt core): two columns share the width less one spacing; a row is the cell's width over the ratio, then mainAxisSpacing. */
    @Test
    fun a5_3_kt_twoColumnsWithSpacingAndAspectRatio() {
        val cells = GridCells(crossAxisCount = 2, mainAxisSpacing = 4.0, crossAxisSpacing = 10.0, childAspectRatio = 1.5)
        assertFrame(0, 0, 150, 100, cells.frame(0, width = 310.0, height = 500.0), "cell 0")
        assertFrame(160, 0, 150, 100, cells.frame(1, width = 310.0, height = 500.0), "cell 1")
        assertFrame(0, 104, 150, 100, cells.frame(2, width = 310.0, height = 500.0), "cell 2")
        assertFrame(160, 104, 150, 100, cells.frame(3, width = 310.0, height = 500.0), "cell 3")
    }

    /** A5.3 (kt core): with nothing set, two square columns and no spacing. */
    @Test
    fun a5_3_kt_defaultsAreTwoSquareColumnsWithoutSpacing() {
        val cells = GridCells()
        assertFrame(0, 0, 150, 150, cells.frame(0, width = 300.0, height = 900.0), "cell 0")
        assertFrame(150, 150, 150, 150, cells.frame(3, width = 300.0, height = 900.0), "cell 3")
    }

    /** A5.3 (kt core): three columns take a third each and a fourth cell opens the next row. */
    @Test
    fun a5_3_kt_theCountSetsTheColumns() {
        val cells = GridCells(crossAxisCount = 3, mainAxisSpacing = 6.0, crossAxisSpacing = 6.0)
        assertFrame(0, 0, 96, 96, cells.frame(0, width = 300.0, height = 900.0), "cell 0")
        assertFrame(204, 0, 96, 96, cells.frame(2, width = 300.0, height = 900.0), "cell 2")
        assertFrame(0, 102, 96, 96, cells.frame(3, width = 300.0, height = 900.0), "cell 3")
    }

    /**
     * A5.3 (kt core): a horizontal grid splits its height into rows and
     * reads the ratio as height / width (the cell's cross over its main
     * extent); cells go down a column, then to the next column.
     */
    @Test
    fun a5_3_kt_aHorizontalGridReadsTheRatioAsHeightOverWidth() {
        val cells = GridCells(
            crossAxisCount = 2, mainAxisSpacing = 5.0, crossAxisSpacing = 10.0, childAspectRatio = 2.0, horizontal = true,
        )
        assertFrame(0, 0, 50, 100, cells.frame(0, width = 900.0, height = 210.0), "cell 0")
        assertFrame(0, 110, 50, 100, cells.frame(1, width = 900.0, height = 210.0), "cell 1")
        assertFrame(55, 0, 50, 100, cells.frame(2, width = 900.0, height = 210.0), "cell 2")
        assertFrame(55, 110, 50, 100, cells.frame(3, width = 900.0, height = 210.0), "cell 3")
    }

    /** A5.3 (kt core): the padding comes off the cross extent first and moves every cell by its leading sides. */
    @Test
    fun a5_3_kt_thePaddingIsTakenOffFirst() {
        val padding = GridPadding(top = 5.0, left = 20.0, bottom = 7.0, right = 10.0)
        val vertical = GridCells(crossAxisSpacing = 10.0, padding = padding)
        assertFrame(20, 5, 145, 145, vertical.frame(0, width = 330.0, height = 900.0), "vertical cell 0")
        assertFrame(175, 150, 145, 145, vertical.frame(3, width = 330.0, height = 900.0), "vertical cell 3")

        val horizontal = GridCells(crossAxisSpacing = 10.0, horizontal = true, padding = padding)
        assertFrame(20, 5, 94, 94, horizontal.frame(0, width = 900.0, height = 210.0), "horizontal cell 0")
        assertFrame(114, 109, 94, 94, horizontal.frame(3, width = 900.0, height = 210.0), "horizontal cell 3")
    }

    /**
     * A5.3 (kt core): the content's main extent is Flutter's
     * `computeMaxScrollOffset` (whole rows, spacing between them) plus the
     * padding on the main axis: 5 cells in 2 columns are 3 rows.
     */
    @Test
    fun a5_3_kt_theContentExtentCountsWholeRowsAndThePadding() {
        val padding = GridPadding(top = 5.0, left = 0.0, bottom = 7.0, right = 0.0)
        val cells = GridCells(mainAxisSpacing = 4.0, crossAxisSpacing = 10.0, childAspectRatio = 1.5, padding = padding)
        assertEquals(320.0, cells.contentExtent(5, width = 310.0, height = 500.0), 1e-9)
        assertEquals(216.0, cells.contentExtent(4, width = 310.0, height = 500.0), 1e-9)
        assertEquals(12.0, cells.contentExtent(0, width = 310.0, height = 500.0), 1e-9)

        val horizontal = GridCells(crossAxisSpacing = 10.0, childAspectRatio = 2.0, horizontal = true)
        assertEquals(100.0, horizontal.contentExtent(4, width = 900.0, height = 210.0), 1e-9)
    }

    /** A5.3 (kt core): spacing wider than the grid leaves no room, so the cells are empty (Flutter's `max(0, ...)`). */
    @Test
    fun a5_3_kt_spacingWiderThanTheGridLeavesEmptyCells() {
        val cells = GridCells(crossAxisSpacing = 400.0)
        assertFrame(0, 0, 0, 0, cells.frame(0, width = 300.0, height = 900.0), "cell 0")
        assertFrame(400, 0, 0, 0, cells.frame(1, width = 300.0, height = 900.0), "cell 1")
    }

    /**
     * A5.3 (kt core): values Flutter only asserts on (a count below 1, a
     * ratio that is not above 0, a negative spacing) draw as one column, a
     * square cell and no spacing instead of dividing by zero.
     */
    @Test
    fun a5_3_kt_valuesFlutterAssertsOnFallBack() {
        val cells = GridCells(crossAxisCount = 0, mainAxisSpacing = -3.0, crossAxisSpacing = -3.0, childAspectRatio = 0.0)
        assertFrame(0, 0, 300, 300, cells.frame(0, width = 300.0, height = 900.0), "cell 0")
        assertFrame(0, 300, 300, 300, cells.frame(1, width = 300.0, height = 900.0), "cell 1")
        assertEquals(1, cells.crossCount)
    }
}
