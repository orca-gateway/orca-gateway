import Foundation

/// A GridView cell's box in the grid's scrolled content (padding included), in points.
public struct GridFrame: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A GridView's `padding`: space inside its scroll extent around the cells, Flutter's SliverPadding.
public struct GridPadding: Equatable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double = 0, left: Double = 0, bottom: Double = 0, right: Double = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

/// Where a GridView's cells go, Flutter `GridView.count` as the builder
/// makes it (structure_builders.dart:204-227) with
/// `SliverGridDelegateWithFixedCrossAxisCount` and
/// `SliverGridRegularTileLayout` (rendering/sliver_grid.dart:171-262,
/// 390-405). The main axis is the scroll axis (down, or across when
/// `horizontal`). With the padding taken off the cross extent, each cell's
/// cross extent is (that extent - `crossAxisSpacing` x (n - 1)) / n, never
/// below 0, and its main extent that over `childAspectRatio`, so a
/// horizontal grid reads the ratio as height / width. Cells fill a row
/// across, then the next one `mainAxisSpacing` further; every cell is
/// forced to that size (Flutter's tight constraints). A layout direction is
/// the caller's (SwiftUI mirrors). A count below 1, a ratio not above 0 and
/// a negative spacing, which Flutter only asserts on, are 1, 1 and 0. The
/// same as Kotlin's GridCells.
public struct GridCells: Equatable, Sendable {
    public var crossAxisCount: Int
    public var mainAxisSpacing: Double
    public var crossAxisSpacing: Double
    public var childAspectRatio: Double
    public var horizontal: Bool
    public var padding: GridPadding

    public init(crossAxisCount: Int = 2, mainAxisSpacing: Double = 0, crossAxisSpacing: Double = 0,
                childAspectRatio: Double = 1, horizontal: Bool = false, padding: GridPadding = GridPadding()) {
        self.crossAxisCount = crossAxisCount
        self.mainAxisSpacing = mainAxisSpacing
        self.crossAxisSpacing = crossAxisSpacing
        self.childAspectRatio = childAspectRatio
        self.horizontal = horizontal
        self.padding = padding
    }

    /// The cells across the grid (columns, or rows when `horizontal`).
    public var crossCount: Int { max(crossAxisCount, 1) }

    private var mainSpacing: Double { max(mainAxisSpacing, 0) }
    private var crossSpacing: Double { max(crossAxisSpacing, 0) }
    private var ratio: Double { childAspectRatio > 0 && childAspectRatio.isFinite ? childAspectRatio : 1 }

    /// Cell `index`'s box in a grid `width` by `height` (its viewport, padding included).
    public func frame(_ index: Int, width: Double, height: Double) -> GridFrame {
        let cross = cellCross(width: width, height: height)
        let main = cross / ratio
        let mainOffset = Double(index / crossCount) * (main + mainSpacing)
        let crossOffset = Double(index % crossCount) * (cross + crossSpacing)
        return horizontal
            ? GridFrame(x: padding.left + mainOffset, y: padding.top + crossOffset, width: main, height: cross)
            : GridFrame(x: padding.left + crossOffset, y: padding.top + mainOffset, width: cross, height: main)
    }

    /// The main-axis length of a grid of `count` cells, padding included:
    /// Flutter `computeMaxScrollOffset` (whole rows, spacing between them)
    /// plus the padding on the main axis.
    public func contentExtent(_ count: Int, width: Double, height: Double) -> Double {
        let paddings = horizontal ? padding.left + padding.right : padding.top + padding.bottom
        guard count > 0 else { return paddings }
        let main = cellCross(width: width, height: height) / ratio
        let rows = Double((count - 1) / crossCount + 1)
        return paddings + rows * (main + mainSpacing) - mainSpacing
    }

    /// Each cell's cross extent: Flutter's `usableCrossAxisExtent / crossAxisCount`.
    private func cellCross(width: Double, height: Double) -> Double {
        let extent = horizontal ? height - padding.top - padding.bottom : width - padding.left - padding.right
        return max(0, extent - crossSpacing * Double(crossCount - 1)) / Double(crossCount)
    }
}
