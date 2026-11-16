import Foundation

/// One lazy item of a CustomScrollView's single scroll view.
public enum SliverItem: Equatable, Sendable, Identifiable {
    /// The node with this id, drawn at the cross extent: a SliverList's
    /// child, a SliverToBoxAdapter's child, or a stray widget itself.
    case box(String)
    /// Line `line` (from 0) of the SliverGrid `grid`: up to crossAxisCount
    /// cell ids, laid across at `GridCells`' size. `isLast` is the grid's
    /// last line, which has no mainAxisSpacing after it.
    case gridLine(grid: String, line: Int, cells: [String], isLast: Bool)
    /// The SliverAppBar with this id.
    case bar(String)

    /// The item's stable key: the node's id, or for a grid line the grid's
    /// id, `#` and the line.
    public var key: String {
        switch self {
        case .box(let id), .bar(let id): return id
        case .gridLine(let grid, let line, _, _): return "\(grid)#\(line)"
        }
    }

    /// `key`, for SwiftUI's `ForEach`.
    public var id: String { key }
}

/// A CustomScrollView's direct children flattened into the ordered lazy
/// items of ONE scroll view (design brief native-parity-s13-slivers, V1),
/// what Flutter's sliver builders lay out one after the other
/// (structure_builders.dart `_buildSliverList`, `_buildSliverGrid`,
/// `_buildSliverToBoxAdapter`, `_buildSliverAppBar`):
/// - SliverList: one box per child.
/// - SliverGrid: one item per line of up to `crossAxisCount` cells (2 when
///   absent, 1 below 1, as `GridCells`); no cells, no line.
/// - SliverToBoxAdapter: its (first) child as a box; no child, nothing.
/// - SliverAppBar: one bar item.
/// - Any other widget: a box of its own (Flutter throws; we draw it).
/// The same as Kotlin's SliverItems.
public struct SliverItems: Equatable, Sendable {
    public static let listType = "SliverList"
    public static let gridType = "SliverGrid"
    public static let adapterType = "SliverToBoxAdapter"
    public static let barType = "SliverAppBar"

    /// The items, in scroll order.
    public var items: [SliverItem]
    /// The id of the bar that may collapse over the content: a SliverAppBar
    /// that is the FIRST direct child (then `items[0]` is its `.bar`), else
    /// nil. The UI also wants the view vertical and not reversed; any other
    /// bar is a plain box that scrolls away.
    public var collapsingBarId: String?

    /// The items of a CustomScrollView's direct children, as resolved nodes
    /// and in order; a grid's `crossAxisCount` is read as Dart's `toInt()`.
    public init(_ children: [ResolvedNode]) {
        var items: [SliverItem] = []
        for child in children {
            switch child.type {
            case Self.listType:
                items.append(contentsOf: child.childIds.map(SliverItem.box))
            case Self.gridType:
                let across = max(child["crossAxisCount"]?.dartInt ?? 2, 1)
                let cells = child.childIds
                let lines = cells.isEmpty ? 0 : (cells.count - 1) / across + 1
                for line in 0..<lines {
                    let start = line * across
                    items.append(.gridLine(grid: child.id, line: line,
                                           cells: Array(cells[start..<min(start + across, cells.count)]),
                                           isLast: line == lines - 1))
                }
            case Self.adapterType:
                if let first = child.childIds.first { items.append(.box(first)) }
            case Self.barType:
                items.append(.bar(child.id))
            default:
                items.append(.box(child.id))
            }
        }
        self.items = items
        self.collapsingBarId = children.first.flatMap { $0.type == Self.barType ? $0.id : nil }
    }
}
