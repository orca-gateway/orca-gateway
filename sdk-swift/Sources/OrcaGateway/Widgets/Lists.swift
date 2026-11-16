#if canImport(SwiftUI)
import SwiftUI

/// Flutter `ListView` (structure_builders.dart:161-202): a ScrollView of a
/// `LazyVStack`, or a `LazyHStack` when `scrollDirection` is "horizontal",
/// so only the rows in view are built: Flutter also builds 250 px past
/// each end (rendering/viewport.dart:289), SwiftUI none (a known
/// difference; the tests count 10 rows where Flutter builds 17).
/// Each child is forced to the list's cross extent, and to `itemExtent` on
/// the main axis when set (SliverFixedExtentList). `padding` is inside the
/// scroll extent; `reverse` puts the first child and offset 0 at the far
/// end, as SingleChildScrollView's (the children in reverse order, the
/// view anchored at its end; before iOS 17 a scroll to the end on appear).
/// The list fills its parent as Flutter's viewport does; `shrinkWrap` hugs
/// its content on the scroll axis, never longer than offered, and stays
/// lazy as Flutter's ShrinkWrappingViewport. With no limit on the scroll
/// axis (a list in a Row or Column) every child is laid out in a stack
/// that does not scroll, what ShrinkWrappingViewport does there; without
/// `shrinkWrap` Flutter throws. A null padding adds no safe-area inset here
/// (Flutter's BoxScrollView adds the MediaQuery padding on the scroll axis,
/// widgets/scroll_view.dart:911-944); SwiftUI's ScrollView keeps its own
/// safe-area handling at a screen edge, padding or not. `primary` has no
/// iOS counterpart and `separator` arrives as a raw widget Flutter cannot
/// read: both ignored. onScrollBegin, onScrolling and onScrollEnd as
/// SingleChildScrollView's (ScrollTriggers); SwiftUI estimates a lazy
/// stack's length from the rows it built, so the extents are exact with
/// rows of one length or `itemExtent`, an estimate otherwise.
@MainActor
struct ListNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaUnbounded) private var unbounded

    var body: some View {
        let horizontal = node["scrollDirection"]?.stringValue == "horizontal"
        let axis: Axis = horizontal ? .horizontal : .vertical
        if unbounded.contains(TightAxes(axis)) {
            rows(horizontal, lazy: false)
        } else if Props.bool(node["shrinkWrap"]) == true {
            HugLayout(axis: axis) { scroll(horizontal) }
        } else {
            scroll(horizontal)
        }
    }

    private var reverse: Bool { Props.bool(node["reverse"]) == true }

    private func scroll(_ horizontal: Bool) -> some View {
        LazyScroll(node: node, model: model, horizontal: horizontal, reverse: reverse) {
            rows(horizontal, lazy: true)
        }
    }

    /// The children in a stack along the axis, reversed under `reverse`, padded.
    @ViewBuilder
    private func rows(_ horizontal: Bool, lazy: Bool) -> some View {
        let ids = reverse ? Array(node.childIds.reversed()) : node.childIds
        let extent = Props.number(node["itemExtent"])
        let items = ForEach(ids, id: \.self) { id in row(id, horizontal: horizontal, extent: extent) }
        Group {
            switch (horizontal, lazy) {
            case (false, true): LazyVStack(alignment: .leading, spacing: 0) { items }
            case (true, true): LazyHStack(alignment: .top, spacing: 0) { items }
            case (false, false): VStack(alignment: .leading, spacing: 0) { items }
            case (true, false): HStack(alignment: .top, spacing: 0) { items }
            }
        }
        .orcaPadding(node["padding"])
    }

    /// A child forced to the cross extent (SliverList's cross-axis tight
    /// constraints) and, with `extent`, to it on the main axis.
    private func row(_ id: String, horizontal: Bool, extent: CGFloat?) -> some View {
        let cross = TightAxes(horizontal ? .vertical : .horizontal)
        return NodeView(id: id, model: model)
            .modifier(AddTight(axes: extent == nil ? cross : [.horizontal, .vertical]))
            .frame(width: horizontal ? extent : nil, height: horizontal ? nil : extent, alignment: .topLeading)
            .frame(maxWidth: horizontal ? nil : .infinity, maxHeight: horizontal ? .infinity : nil,
                   alignment: .topLeading)
    }
}

/// Flutter `GridView.count` (structure_builders.dart:204-227): a ScrollView
/// of a `LazyVGrid` (`LazyHGrid` when horizontal) of `crossAxisCount` (2)
/// lines with the spacings between cells (0) and `padding` inside the
/// scroll extent; each child is forced to the cell size the core's
/// GridCells gives (cross extent shared, main extent by
/// `childAspectRatio`, 1). Only the cells in view are built, with no
/// 250 px cache, as ListView. It fills its parent, or hugs its content on
/// the scroll axis with `shrinkWrap` (GridBox), lazy still. With no limit
/// on the scroll axis every cell is laid out where the core puts it and
/// nothing scrolls (EagerGridLayout): what Flutter's
/// ShrinkWrappingViewport does with `shrinkWrap`; without it, or with no
/// limit across, Flutter throws, and here no limit across gives empty
/// cells. The safe-area inset as ListView's; `primary` is ignored;
/// GridView has no `reverse`. The scroll triggers as ListView's (exact:
/// every row is as long).
@MainActor
struct GridNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaUnbounded) private var unbounded

    var body: some View {
        let horizontal = node["scrollDirection"]?.stringValue == "horizontal"
        let insets = Props.insets(node["padding"]) ?? EdgeInsets()
        let cells = GridCells(
            crossAxisCount: node["crossAxisCount"]?.dartInt ?? 2,
            mainAxisSpacing: Double(Props.number(node["mainAxisSpacing"]) ?? 0),
            crossAxisSpacing: Double(Props.number(node["crossAxisSpacing"]) ?? 0),
            childAspectRatio: Double(Props.number(node["childAspectRatio"]) ?? 1),
            horizontal: horizontal,
            padding: GridPadding(top: insets.top, left: insets.leading, bottom: insets.bottom,
                                 right: insets.trailing))
        if unbounded.contains(TightAxes(horizontal ? .horizontal : .vertical)) {
            EagerGridLayout(cells: cells) {
                ForEach(node.childIds, id: \.self) { id in
                    NodeView(id: id, model: model).modifier(AddTight(axes: [.horizontal, .vertical]))
                }
            }
        } else {
            GridBox(cells: cells, count: node.childIds.count, shrinkWrap: Props.bool(node["shrinkWrap"]) == true) {
                GeometryReader { geometry in
                    LazyScroll(node: node, model: model, horizontal: horizontal, reverse: false) {
                        grid(cells, geometry.size)
                    }
                }
            }
        }
    }

    /// The lazy grid of cells sized for a view `size` (padding included).
    @ViewBuilder
    private func grid(_ cells: GridCells, _ size: CGSize) -> some View {
        let cell = cells.frame(0, width: size.width, height: size.height)
        let cross = cells.horizontal ? cell.height : cell.width
        let lines = Array(repeating: GridItem(.fixed(cross), spacing: max(cells.crossAxisSpacing, 0)),
                          count: cells.crossCount)
        let spacing = max(cells.mainAxisSpacing, 0)
        let items = ForEach(node.childIds, id: \.self) { id in
            NodeView(id: id, model: model)
                .modifier(AddTight(axes: [.horizontal, .vertical]))
                .frame(width: cell.width, height: cell.height, alignment: .topLeading)
        }
        Group {
            if cells.horizontal {
                LazyHGrid(rows: lines, alignment: .top, spacing: spacing) { items }
            } else {
                LazyVGrid(columns: lines, alignment: .leading, spacing: spacing) { items }
            }
        }
        .orcaPadding(node["padding"])
    }
}

/// A lazy list's or grid's ScrollView along its axis, reversed as
/// SingleChildScrollView's (anchored at the far end; before iOS 17 /
/// macOS 14 a scroll to the end on appear), with ScrollTriggers when the
/// node sets a scroll trigger.
@MainActor
private struct LazyScroll<Content: View>: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    let horizontal: Bool
    let reverse: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if node.actions.keys.contains(where: ScrollEvent.triggers.contains) {
            let triggers = ScrollTriggers(node: node, model: model, horizontal: horizontal, reverse: reverse,
                                          phased: Self.phased)
            if triggers.phased {
                scrollView(content()).modifier(triggers)
            } else {
                scrollView(ScrollTriggers.probe(content())).modifier(triggers)
            }
        } else {
            scrollView(content())
        }
    }

    @ViewBuilder
    private func scrollView<V: View>(_ content: V) -> some View {
        let axis: Axis.Set = horizontal ? .horizontal : .vertical
        let end: UnitPoint = horizontal ? .trailing : .bottom
        if !reverse {
            ScrollView(axis) { content }
        } else if #available(iOS 17, macOS 14, *) {
            ScrollView(axis) { content }.defaultScrollAnchor(end)
        } else {
            ScrollViewReader { proxy in
                ScrollView(axis) { content.id(node.id) }
                    .onAppear { proxy.scrollTo(node.id, anchor: end) }
            }
        }
    }

    /// The scroll phase is there (iOS 18, macOS 15) and in use, as for
    /// SingleChildScrollView.
    private static var phased: Bool {
        guard ScrollNodeView.usesScrollPhase else { return false }
        if #available(iOS 18, macOS 15, *) { return true }
        return false
    }
}

/// A lazy grid's box: all it is offered on its scroll axis (Flutter's
/// viewport), or with `shrinkWrap`, or with no length offered there, the
/// content's length (GridCells), never longer than offered; across, what
/// it is offered (0 with nothing).
struct GridBox: Layout {
    var cells: GridCells
    var count: Int
    var shrinkWrap: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0, height = proposal.height ?? 0
        let offered = cells.horizontal ? proposal.width : proposal.height
        let main = shrinkWrap || offered == nil
            ? min(cells.contentExtent(count, width: width, height: height), offered ?? .infinity)
            : offered ?? 0
        return cells.horizontal ? CGSize(width: main, height: height) : CGSize(width: width, height: main)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// Every cell of a grid with no limit on its scroll axis, each forced to
/// the box GridCells gives it, as long as its rows; across, what it is
/// offered (0 with nothing). SwiftUI mirrors it in right-to-left, as
/// Flutter's grid runs its cross axis.
struct EagerGridLayout: Layout {
    var cells: GridCells

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = cells.horizontal ? 0 : proposal.width ?? 0
        let height = cells.horizontal ? proposal.height ?? 0 : 0
        let main = cells.contentExtent(subviews.count, width: width, height: height)
        return cells.horizontal ? CGSize(width: main, height: height) : CGSize(width: width, height: main)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() {
            let frame = cells.frame(index, width: bounds.width, height: bounds.height)
            subview.place(at: CGPoint(x: bounds.minX + frame.x, y: bounds.minY + frame.y),
                          proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
}
#endif
