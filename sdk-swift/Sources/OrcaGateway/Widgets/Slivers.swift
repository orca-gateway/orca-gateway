#if canImport(SwiftUI)
import Combine
import SwiftUI

/// Flutter `CustomScrollView` (structure_builders.dart
/// `_buildCustomScrollView`): ONE lazy scroll view, a ScrollView of a
/// `LazyVStack` (`LazyHStack` when `scrollDirection` is "horizontal"),
/// holding what the core's SliverItems makes of its slivers, in order:
/// a SliverList's children and a SliverToBoxAdapter's child as rows forced
/// to the cross extent (ListView's rows), a SliverGrid as one row per line
/// of cells at GridCells' size (GridView's numbers: `crossAxisSpacing`
/// between cells, `mainAxisSpacing` after each line but the last), a
/// SliverAppBar, and any other widget as a row of its own (Flutter throws).
/// Only the items in view are built, with no 250 px cache, as ListView.
/// `reverse`, `shrinkWrap`, the stack that does not scroll when the scroll
/// axis has no limit, and onScrollBegin, onScrolling and onScrollEnd are
/// ListView's, through the same LazyScroll and ScrollTriggers; the scroll
/// metrics are exact with rows of one length, an estimate otherwise.
///
/// A SliverAppBar that is the first sliver of a vertical view that is not
/// reversed collapses: its row is a clear spacer as tall as the bar fully
/// open, and the bar is drawn in the scroll view's content over the rows
/// (a ZStack around the lazy stack, not a lazy row, which would be unloaded
/// once scrolled past), moved down by the scroll offset so it stays at the
/// top of the view, at the extent the core's SliverAppBarGeometry gives for
/// each scroll offset (the samples ScrollTriggers reads: the scroll
/// geometry on iOS 18 / macOS 15, the content's frame before). So the
/// content starts max(0, maxExtent - offset) down, as Flutter's, a pinned
/// or floated-in bar lies over it, and a touch on the bar is the scroll
/// view's: a drag that starts there scrolls, as on Flutter's bar, a sliver
/// of the one Scrollable.
/// With `snap` the bar settles when a scroll ends (where onScrollEnd
/// fires), animated over 300 ms. Where the view reaches under the status
/// bar (a top safe-area inset no bar above took) it runs up to the screen's
/// top and the bar is taller by the inset, its toolbar below it
/// (Flutter's MediaQuery top padding); not with `shrinkWrap`. Any other
/// SliverAppBar is a plain box that scrolls with the content
/// (SliverAppBarView).
///
/// The slivers flattened here (a list, a grid, an adapter) have no NodeView:
/// this view does a NodeView's work for them. It resolves them as their own
/// build (with an enclosing AnimatedBuilder's progress), redraws when a key
/// one of them watches changes, records them for an enclosing
/// AnimatedSwitcher (so its fading-out copy keeps their children) and fires
/// their lifecycle triggers; their other triggers have nothing to fire them.
///
/// Known difference: a floating bar also comes back when the view is
/// scrolled toward its start by code (Flutter: by a drag only).
@MainActor
struct CustomScrollNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaUnbounded) private var unbounded
    @Environment(\.orcaSafeAreaTaken) private var taken
    /// Set by an enclosing AnimatedBuilder, as NodeView reads it.
    @Environment(\.orcaAnimationProgress) private var animationProgress
    /// Set by an enclosing AnimatedSwitcher, as NodeView reads it.
    @Environment(\.orcaNodeRecorder) private var recorder
    /// Redraws this view when a sliver's watched state changes.
    @StateObject private var watched = SliverObservers()
    /// The collapsing bar's extents; a reference, so a scroll sample redraws
    /// the bar only.
    @State private var bar = SliverBarModel()

    var body: some View {
        let slivers = node.childIds.compactMap(sliver)
        // A stray widget has its own NodeView and nothing this view reads.
        let _ = watched.watch(slivers.filter { $0.type == SliverItems.barType || Self.flattened.contains($0.type) }
            .map(\.id), in: model)
        let layout = SliverItems(slivers)
        let horizontal = node["scrollDirection"]?.stringValue == "horizontal"
        let axis: Axis = horizontal ? .horizontal : .vertical
        // The bar that collapses, with the view vertical and not reversed.
        let collapsing = horizontal || reverse ? nil : slivers.first { $0.id == layout.collapsingBarId }
        Group {
            if unbounded.contains(TightAxes(axis)) {
                stack(layout.items, slivers, horizontal: horizontal, lazy: false, spacer: nil)
            } else if Props.bool(node["shrinkWrap"]) == true {
                HugLayout(axis: axis) { scroll(layout.items, slivers, horizontal, collapsing, top: 0) }
            } else if collapsing != nil, !taken.contains(.top) {
                GeometryReader { geometry in
                    let top = geometry.safeAreaInsets.top
                    scroll(layout.items, slivers, horizontal, collapsing, top: top)
                        .ignoresSafeArea(.container, edges: top > 0 ? .top : [])
                }
            } else {
                scroll(layout.items, slivers, horizontal, collapsing, top: 0)
            }
        }
        .background { lifecycles(slivers) }
    }

    private var reverse: Bool { Props.bool(node["reverse"]) == true }

    /// The types this view flattens into its items: drawn by no NodeView.
    private static let flattened = [SliverItems.listType, SliverItems.gridType, SliverItems.adapterType]

    /// The child `id` resolved. A flattened sliver as NodeView resolves a
    /// node it draws: its own build, with the animation progress, recorded.
    /// A bar or a stray widget is read only; its NodeView does the rest.
    private func sliver(_ id: String) -> ResolvedNode? {
        guard let read = model.resolve(id) else { return nil }
        guard Self.flattened.contains(read.type) else { return read }
        let own = model.resolve(id, animationProgress: animationProgress) ?? read
        recorder?.record(own, drawnFrom: model)
        return own
    }

    /// The scroll view; with a bar that collapses, the bar in its content
    /// over the rows, `top` of it under the status bar.
    @ViewBuilder
    private func scroll(_ items: [SliverItem], _ slivers: [ResolvedNode], _ horizontal: Bool,
                        _ collapsing: ResolvedNode?, top: CGFloat) -> some View {
        if let collapsing {
            let extent = CGFloat(SliverAppBarView.geometry(collapsing, topPadding: top).maxExtent)
            LazyScroll(node: node, model: model, horizontal: false, reverse: false, watch: bar.watch) {
                ZStack(alignment: .top) {
                    stack(items, slivers, horizontal: false, lazy: true, spacer: (id: collapsing.id, extent: extent))
                    NodeView(id: collapsing.id, model: model)
                        .environment(\.orcaSliverBar, SliverBarPlace(id: collapsing.id, bar: bar, topPadding: top))
                        .zIndex(1)
                }
            }
        } else {
            LazyScroll(node: node, model: model, horizontal: horizontal, reverse: reverse) {
                stack(items, slivers, horizontal: horizontal, lazy: true, spacer: nil)
            }
        }
    }

    /// The items in a stack along the axis, reversed under `reverse`.
    /// `spacer` is the collapsing bar's id and how much room its row keeps.
    private func stack(_ items: [SliverItem], _ slivers: [ResolvedNode], horizontal: Bool, lazy: Bool,
                       spacer: (id: String, extent: CGFloat)?) -> some View {
        let grids = Dictionary(slivers.filter { $0.type == SliverItems.gridType }
            .map { ($0.id, GridCells($0, horizontal: horizontal)) }) { first, _ in first }
        return AxisStack(horizontal: horizontal, lazy: lazy) {
            ForEach(reverse ? Array(items.reversed()) : items) { item in
                switch item {
                case .box(let id):
                    ListNodeView.row(id, model: model, horizontal: horizontal, extent: nil)
                case .bar(let id):
                    if let spacer, spacer.id == id {
                        Color.clear.frame(height: spacer.extent)
                    } else {
                        ListNodeView.row(id, model: model, horizontal: horizontal, extent: nil)
                    }
                case .gridLine(let grid, _, let cells, let isLast):
                    line(cells, grids[grid] ?? GridCells(horizontal: horizontal), isLast: isLast)
                }
            }
        }
    }

    /// One line of a SliverGrid: its cells where GridCells puts a grid's
    /// first line, as wide as the view, and `mainAxisSpacing` before the
    /// next line.
    private func line(_ ids: [String], _ cells: GridCells, isLast: Bool) -> some View {
        let next: Edge.Set = cells.horizontal ? (reverse ? .leading : .trailing) : (reverse ? .top : .bottom)
        return EagerGrid(ids: ids, cells: cells, model: model)
            .padding(next, isLast ? CGFloat(0) : CGFloat(max(cells.mainAxisSpacing, 0)))
    }

    /// The lifecycle triggers of the slivers this view flattens (a list, a
    /// grid, an adapter): they are not drawn as nodes, so nothing else
    /// would fire them. A bar and a stray widget are drawn by a NodeView.
    private func lifecycles(_ slivers: [ResolvedNode]) -> some View {
        ForEach(slivers.filter { Self.flattened.contains($0.type) }, id: \.id) { flat in
            if let triggers = LifecycleTriggers(flat.actions) {
                Color.clear.frame(width: 0, height: 0)
                    .modifier(Lifecycle(node: flat, model: model, triggers: triggers))
            }
        }
    }
}

/// Flutter `SliverAppBar` (structure_builders.dart `_buildSliverAppBar`),
/// drawn by the SDK: a box with `backgroundColor` (else the platform's
/// background, the surface a Scaffold's bar has), `flexibleSpace` behind
/// the toolbar as wide as the bar, up to its height, from the top (Flutter
/// lays the bar out with a tight width and a height of 0 to the box's,
/// sliver_persistent_header.dart:248-251, and its AppBar stacks the space
/// with those, app_bar.dart:1199-1200; no FlexibleSpaceBar), and at the
/// top, under the top padding, the 56-high toolbar row of AppBarView:
/// `leading`, `title` (centred unless `centerTitle` is false), `action_0`
/// ... (to the first gap), always 56 high with a 56 leading box: a
/// SliverAppBar carries no `toolbarHeight` or `leadingWidth`, and its
/// geometry counts 56. `elevation` is AppBarShadow's: drawn with a
/// `shadowColor`, which a SliverAppBar never carries, so nothing, as Flutter's M3 bar (its
/// shadowColor is transparent).
///
/// As the first sliver of a vertical CustomScrollView that is not reversed
/// the bar collapses (CustomScrollNodeView puts it at the top of the scroll
/// view's content, over the rows, and names it in `orcaSliverBar`): the box
/// is `frame.box` high, moved down by the scroll offset so its bottom edge
/// is `frame.paint` below the view's top, what is above the top cut off,
/// the toolbar at `frame.toolbarOpacity`. Anywhere else (not first, a
/// horizontal or reversed view, outside a CustomScrollView) it is a box as
/// tall as the bar fully open (`expandedHeight`, else 56) that scrolls
/// with the content, whatever `pinned`, `floating` and `snap` say.
@MainActor
struct SliverAppBarView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaSliverBar) private var place

    var body: some View {
        if let place, place.id == node.id {
            CollapsingSliverBar(node: node, model: model, bar: place.bar, topPadding: place.topPadding)
        } else {
            let extent = Self.geometry(node, topPadding: 0).maxExtent
            SliverBarBox(node: node, model: model, topPadding: 0,
                         frame: SliverAppBarFrame(paint: extent, layout: extent, box: extent, toolbarOpacity: 1))
        }
    }

    /// The bar's extents from its props, not yet scrolled.
    static func geometry(_ node: ResolvedNode, topPadding: CGFloat) -> SliverAppBarGeometry {
        SliverAppBarGeometry(
            pinned: Props.bool(node["pinned"]) == true, floating: Props.bool(node["floating"]) == true,
            snap: Props.bool(node["snap"]) == true,
            expandedHeight: Props.number(node["expandedHeight"]).map { Double($0) },
            collapsedHeight: Props.number(node["collapsedHeight"]).map { Double($0) },
            topPadding: Double(topPadding))
    }
}

/// The bar that collapses: redrawn at each scroll sample of its
/// SliverBarModel, down from the content's top by the scroll offset, so at
/// the top of the view (also past the start, in a bounce).
@MainActor
private struct CollapsingSliverBar: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @ObservedObject var bar: SliverBarModel
    let topPadding: CGFloat

    var body: some View {
        SliverBarBox(node: node, model: model, topPadding: topPadding,
                     frame: bar.frame(for: SliverAppBarView.geometry(node, topPadding: topPadding)))
            .offset(y: bar.offset)
    }
}

/// A SliverAppBar's box at one moment (see SliverAppBarView).
@MainActor
private struct SliverBarBox: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    let topPadding: CGFloat
    let frame: SliverAppBarFrame

    var body: some View {
        ZStack(alignment: .top) {
            Props.color(node["backgroundColor"]) ?? systemBackground
            if let space = node.slots["flexibleSpace"] {
                // Loose on the height: bounded by the box, not forced to it.
                NodeView(id: space, model: model)
                    .modifier(AddTight(axes: .horizontal))
                    .modifier(Bound(axes: .vertical))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            AppBarToolbar(node: node, model: model)
                .padding(.top, topPadding)
                .opacity(frame.toolbarOpacity)
        }
        .frame(height: CGFloat(frame.box))
        .frame(height: CGFloat(frame.paint), alignment: .bottom)
        .clipped()
        // Clipping does not stop touches: none above the view's top, none on a bar scrolled away.
        // The painted box takes its taps (none reaches a row under a pinned bar); a drag is the scroll view's.
        .contentShape(Rectangle())
        .allowsHitTesting(frame.paint > 0)
        .overlay(alignment: .bottom) {
            AppBarShadow(appBar: node).alignmentGuide(.bottom) { $0[.top] }
        }
    }
}

/// A collapsing SliverAppBar's SliverAppBarGeometry and scroll offset, fed
/// by its CustomScrollView's scroll samples and read by the bar. It
/// publishes when the offset or what the bar draws changes; the settle of a
/// `snap` bar is published in an animation of Flutter's 300 ms and
/// Curves.ease.
@MainActor
final class SliverBarModel: ObservableObject {
    private var geometry = SliverAppBarGeometry()
    /// The scroll offset last sampled, negative past the start (a bounce):
    /// how far the top of the view is below the top of the content.
    private(set) var offset: CGFloat = 0

    /// What the bar draws now, its props as `props` has them (the scroll
    /// seen so far is kept).
    func frame(for props: SliverAppBarGeometry) -> SliverAppBarFrame {
        geometry.pinned = props.pinned
        geometry.floating = props.floating
        geometry.snap = props.snap
        geometry.expandedHeight = props.expandedHeight
        geometry.collapsedHeight = props.collapsedHeight
        geometry.topPadding = props.topPadding
        return geometry.frame
    }

    /// The scroll view's samples, for LazyScroll.
    var watch: ScrollWatch {
        ScrollWatch(offset: { [weak self] in self?.scrolled(to: $0) }, ended: { [weak self] in self?.released() })
    }

    private func scrolled(to offset: Double) {
        guard offset.isFinite else { return }
        let before = geometry.frame
        let moved = CGFloat(offset) != self.offset
        guard geometry.scrolled(to: offset) != before || moved else { return }
        objectWillChange.send()
        self.offset = CGFloat(offset)
    }

    private func released() {
        let before = geometry.frame
        guard geometry.released() != before else { return }
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.3)) { objectWillChange.send() }
    }
}

/// The collapsing bar of the CustomScrollView around: its id, its extents
/// and how much of it is under the status bar.
struct SliverBarPlace {
    let id: String
    let bar: SliverBarModel
    let topPadding: CGFloat
}

private struct SliverBarPlaceKey: EnvironmentKey {
    static let defaultValue: SliverBarPlace? = nil
}

extension EnvironmentValues {
    /// Set by a CustomScrollView on the bar it draws at its top; nil, the
    /// default, and for any other SliverAppBar (another id): a plain box.
    var orcaSliverBar: SliverBarPlace? {
        get { self[SliverBarPlaceKey.self] }
        set { self[SliverBarPlaceKey.self] = newValue }
    }
}

/// One NodeObserver per sliver of a CustomScrollView whose props the view
/// reads itself (a grid's `crossAxisCount`, a bar's `expandedHeight`): a
/// change of a state key one of them watches redraws the view. Not a stray
/// widget, which only its own NodeView reads.
@MainActor
final class SliverObservers: ObservableObject {
    private var ids: [String] = []
    private var observers: [NodeObserver] = []
    private var changes: [AnyCancellable] = []

    func watch(_ ids: [String], in model: OrcaPageModel) {
        guard ids != self.ids else { return }
        self.ids = ids
        observers = ids.map { NodeObserver(model: model, id: $0) }
        changes = observers.map { observer in
            observer.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }
}

/// A `SliverList` outside a CustomScrollView (Flutter throws): its children
/// one below the other, each as wide as the list.
@MainActor
struct SliverListView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(node.childIds, id: \.self) { id in
                ListNodeView.row(id, model: model, horizontal: false, extent: nil)
            }
        }
    }
}

/// A `SliverGrid` outside a CustomScrollView (Flutter throws): every cell
/// where GridCells puts it, as GridView's with no limit on its scroll axis.
@MainActor
struct SliverGridView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        EagerGrid(ids: node.childIds, cells: GridCells(node, horizontal: false), model: model)
    }
}
#endif
