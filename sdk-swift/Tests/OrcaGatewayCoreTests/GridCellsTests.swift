import XCTest

@testable import OrcaGatewayCore

/// A5.3, the core half of GridView: its cells against Flutter's
/// `GridView.count` builder (structure_builders.dart:204-227:
/// crossAxisCount 2, spacings 0, childAspectRatio 1 by default),
/// `SliverGridDelegateWithFixedCrossAxisCount` and
/// `SliverGridRegularTileLayout` (rendering/sliver_grid.dart:171-262,
/// 390-405): cross = (usable cross extent - crossSpacing x (n - 1)) / n,
/// main = cross / ratio, the padding (a SliverPadding) taken off first.
/// Frames are (x, y, width, height) in the grid's scrolled content. The
/// same cases and numbers as Kotlin's GridCellsTest.
final class GridCellsTests: XCTestCase {
    private func assertFrame(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ actual: GridFrame,
                             _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.x, x, accuracy: 1e-9, "\(label) x", file: file, line: line)
        XCTAssertEqual(actual.y, y, accuracy: 1e-9, "\(label) y", file: file, line: line)
        XCTAssertEqual(actual.width, width, accuracy: 1e-9, "\(label) width", file: file, line: line)
        XCTAssertEqual(actual.height, height, accuracy: 1e-9, "\(label) height", file: file, line: line)
    }

    /// A5.3: two columns share the width less one spacing; a row is the
    /// cell's width over the ratio, then mainAxisSpacing.
    func testA5_3TwoColumnsWithSpacingAndAspectRatio() {
        let cells = GridCells(crossAxisCount: 2, mainAxisSpacing: 4, crossAxisSpacing: 10, childAspectRatio: 1.5)
        assertFrame(0, 0, 150, 100, cells.frame(0, width: 310, height: 500), "cell 0")
        assertFrame(160, 0, 150, 100, cells.frame(1, width: 310, height: 500), "cell 1")
        assertFrame(0, 104, 150, 100, cells.frame(2, width: 310, height: 500), "cell 2")
        assertFrame(160, 104, 150, 100, cells.frame(3, width: 310, height: 500), "cell 3")
    }

    /// A5.3: with nothing set, two square columns and no spacing.
    func testA5_3DefaultsAreTwoSquareColumnsWithoutSpacing() {
        let cells = GridCells()
        assertFrame(0, 0, 150, 150, cells.frame(0, width: 300, height: 900), "cell 0")
        assertFrame(150, 150, 150, 150, cells.frame(3, width: 300, height: 900), "cell 3")
    }

    /// A5.3: three columns take a third each and a fourth cell opens the next row.
    func testA5_3TheCountSetsTheColumns() {
        let cells = GridCells(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6)
        assertFrame(0, 0, 96, 96, cells.frame(0, width: 300, height: 900), "cell 0")
        assertFrame(204, 0, 96, 96, cells.frame(2, width: 300, height: 900), "cell 2")
        assertFrame(0, 102, 96, 96, cells.frame(3, width: 300, height: 900), "cell 3")
    }

    /// A5.3: a horizontal grid splits its height into rows and reads the
    /// ratio as height / width (the cell's cross over its main extent);
    /// cells go down a column, then to the next column.
    func testA5_3AHorizontalGridReadsTheRatioAsHeightOverWidth() {
        let cells = GridCells(crossAxisCount: 2, mainAxisSpacing: 5, crossAxisSpacing: 10, childAspectRatio: 2,
                              horizontal: true)
        assertFrame(0, 0, 50, 100, cells.frame(0, width: 900, height: 210), "cell 0")
        assertFrame(0, 110, 50, 100, cells.frame(1, width: 900, height: 210), "cell 1")
        assertFrame(55, 0, 50, 100, cells.frame(2, width: 900, height: 210), "cell 2")
        assertFrame(55, 110, 50, 100, cells.frame(3, width: 900, height: 210), "cell 3")
    }

    /// A5.3: the padding comes off the cross extent first and moves every
    /// cell by its leading sides.
    func testA5_3ThePaddingIsTakenOffFirst() {
        let padding = GridPadding(top: 5, left: 20, bottom: 7, right: 10)
        let vertical = GridCells(crossAxisSpacing: 10, padding: padding)
        assertFrame(20, 5, 145, 145, vertical.frame(0, width: 330, height: 900), "vertical cell 0")
        assertFrame(175, 150, 145, 145, vertical.frame(3, width: 330, height: 900), "vertical cell 3")

        let horizontal = GridCells(crossAxisSpacing: 10, horizontal: true, padding: padding)
        assertFrame(20, 5, 94, 94, horizontal.frame(0, width: 900, height: 210), "horizontal cell 0")
        assertFrame(114, 109, 94, 94, horizontal.frame(3, width: 900, height: 210), "horizontal cell 3")
    }

    /// A5.3: the content's main extent is Flutter's
    /// `computeMaxScrollOffset` (whole rows, spacing between them) plus the
    /// padding on the main axis: 5 cells in 2 columns are 3 rows.
    func testA5_3TheContentExtentCountsWholeRowsAndThePadding() {
        let padding = GridPadding(top: 5, left: 0, bottom: 7, right: 0)
        let cells = GridCells(mainAxisSpacing: 4, crossAxisSpacing: 10, childAspectRatio: 1.5, padding: padding)
        XCTAssertEqual(cells.contentExtent(5, width: 310, height: 500), 320, accuracy: 1e-9)
        XCTAssertEqual(cells.contentExtent(4, width: 310, height: 500), 216, accuracy: 1e-9)
        XCTAssertEqual(cells.contentExtent(0, width: 310, height: 500), 12, accuracy: 1e-9)

        let horizontal = GridCells(crossAxisSpacing: 10, childAspectRatio: 2, horizontal: true)
        XCTAssertEqual(horizontal.contentExtent(4, width: 900, height: 210), 100, accuracy: 1e-9)
    }

    /// A5.3: spacing wider than the grid leaves no room, so the cells are
    /// empty (Flutter's `max(0, ...)`).
    func testA5_3SpacingWiderThanTheGridLeavesEmptyCells() {
        let cells = GridCells(crossAxisSpacing: 400)
        assertFrame(0, 0, 0, 0, cells.frame(0, width: 300, height: 900), "cell 0")
        assertFrame(400, 0, 0, 0, cells.frame(1, width: 300, height: 900), "cell 1")
    }

    /// A5.3: values Flutter only asserts on (a count below 1, a ratio that
    /// is not above 0, a negative spacing) draw as one column, a square
    /// cell and no spacing instead of dividing by zero.
    func testA5_3ValuesFlutterAssertsOnFallBack() {
        let cells = GridCells(crossAxisCount: 0, mainAxisSpacing: -3, crossAxisSpacing: -3, childAspectRatio: 0)
        assertFrame(0, 0, 300, 300, cells.frame(0, width: 300, height: 900), "cell 0")
        assertFrame(0, 300, 300, 300, cells.frame(1, width: 300, height: 900), "cell 1")
        XCTAssertEqual(cells.crossCount, 1)
    }
}
