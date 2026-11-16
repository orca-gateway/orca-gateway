#if canImport(SwiftUI)
import SwiftUI

/// Column and Row (Flutter `Flex`): no implicit spacing, `gap` between
/// children only, main-axis alignment with spacers, `mainAxisSize: max` (the
/// default) fills the main axis. As in the Flutter SDK, a gap is a box that
/// `spaceAround` and `spaceEvenly` space like a child; `spaceAround` puts
/// half a space at each end. A Column's cross-axis `baseline` is `start`.
///
/// A Row or Column with an Expanded or Spacer child is drawn by FlexLayout,
/// which shares the space by `flex`; every other one keeps the stack below,
/// so pages that drew before draw exactly as before.
///
/// `textDirection` and `verticalDirection` (Flutter LB:119-158) order the
/// flex's own layout only: rtl starts a Row at the right and swaps a
/// Column's cross start and end; up lays a Column out bottom-to-top and
/// swaps a Row's cross start and end. The children keep the ambient
/// direction, as Flutter's Flex does not change their Directionality.
/// Without `textDirection` no direction is set on the flex or its children.
@MainActor
struct FlexView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    let axis: Axis
    @Environment(\.layoutDirection) private var ambient

    var body: some View {
        let laid = content
            .environment(\.orcaTight, stretched ? TightAxes(axis == .vertical ? .horizontal : .vertical) : [])
        if let direction {
            laid.environment(\.layoutDirection, direction)
        } else {
            laid
        }
    }

    /// `textDirection`; nil when it is not sent (the ambient one stands).
    private var direction: LayoutDirection? {
        switch node["textDirection"]?.stringValue {
        case "rtl": return .rightToLeft
        case "ltr": return .leftToRight
        default: return nil
        }
    }

    private var up: Bool { node["verticalDirection"]?.stringValue == "up" }

    private var stretched: Bool { Props.crossAxis(node["crossAxisAlignment"]) == .stretch }

    @ViewBuilder
    private var content: some View {
        let flexes = node.childIds.map(flex(of:))
        if flexes.contains(where: { $0 > 0 }) {
            FlexLayout(axis: axis, cross: Props.crossAxis(node["crossAxisAlignment"]),
                       fill: Props.fillsMainAxis(node["mainAxisSize"]),
                       gap: Props.number(node["gap"]) ?? 0, up: up) {
                ForEach(Array(zip(node.childIds, flexes)), id: \.0) { id, flex in
                    child(id).layoutValue(key: FlexFactor.self, value: flex)
                }
            }
            .environment(\.orcaFlexAxis, axis)
        } else {
            stacked
        }
    }

    /// Flutter `propOr<int>('flex', 1)` for Expanded and Spacer; 0 otherwise.
    private func flex(of id: String) -> Int {
        guard let type = model.renderer.node(id)?.type, type == "Expanded" || type == "Spacer" else { return 0 }
        return max(model.resolve(id)?["flex"]?.intValue ?? 1, 0)
    }

    /// A Column going up is the stack of its children in reverse, its
    /// `start` and `end` swapped.
    @ViewBuilder
    private var stacked: some View {
        let reversed = up && axis == .vertical
        let alignment = Props.mainAxis(node["mainAxisAlignment"])
        let main: Props.MainAxis = !reversed ? alignment
            : alignment == .start ? .end : alignment == .end ? .start : alignment
        let fill = Props.fillsMainAxis(node["mainAxisSize"])
        let ids = reversed ? Array(node.childIds.reversed()) : node.childIds
        let lead = fill && [.end, .center, .spaceAround, .spaceEvenly].contains(main)
        let trail = fill && [.start, .center, .spaceAround, .spaceEvenly].contains(main)
        let between = fill && [.spaceBetween, .spaceAround, .spaceEvenly].contains(main)
        // spaceAround spaces each item on both sides, so two spacers meet
        // between items.
        let around = fill && main == .spaceAround
        let gap = Props.number(node["gap"])
        // The Flutter SDK's gap box (`_addGaps`, any gap, even 0) is an item
        // spaceAround and spaceEvenly space like a child.
        let boxed = gap != nil && fill && [.spaceAround, .spaceEvenly].contains(main)

        stack {
            if lead { Spacer(minLength: 0) }
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                if index > 0 {
                    if boxed {
                        Spacer(minLength: 0)
                        if around { Spacer(minLength: 0) }
                    }
                    if let gap, gap > 0 || boxed { gapView(gap) }
                    if between { Spacer(minLength: 0) }
                    if around { Spacer(minLength: 0) }
                }
                child(id)
            }
            if trail { Spacer(minLength: 0) }
        }
        .environment(\.orcaFlexAxis, axis)
    }

    @ViewBuilder
    private func stack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let cross = Props.crossAxis(node["crossAxisAlignment"])
        if axis == .vertical {
            // Flutter has no baselines across a Column: `baseline` is `start`.
            let alignment: HorizontalAlignment =
                cross == .start || cross == .baseline ? .leading : cross == .end ? .trailing : .center
            VStack(alignment: alignment, spacing: 0, content: content)
        } else {
            let alignment: VerticalAlignment =
                cross == .start ? (up ? .bottom : .top) : cross == .end ? (up ? .top : .bottom)
                : cross == .baseline ? .firstTextBaseline : .center
            HStack(alignment: alignment, spacing: 0, content: content)
        }
    }

    /// Under `stretch` a child spans the cross axis; one that does not fill
    /// it (a Text) sits at its start, as Flutter paints it in the tight box.
    /// Under `textDirection` each child is back in the ambient direction.
    @ViewBuilder
    private func child(_ id: String) -> some View {
        if direction != nil {
            stretchedChild(id).environment(\.layoutDirection, ambient)
        } else {
            stretchedChild(id)
        }
    }

    @ViewBuilder
    private func stretchedChild(_ id: String) -> some View {
        if Props.crossAxis(node["crossAxisAlignment"]) == .stretch {
            if axis == .vertical {
                NodeView(id: id, model: model).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                NodeView(id: id, model: model).frame(maxHeight: .infinity, alignment: .top)
            }
        } else {
            NodeView(id: id, model: model)
        }
    }

    private func gapView(_ gap: CGFloat) -> some View {
        Color.clear.frame(width: axis == .horizontal ? gap : 0, height: axis == .vertical ? gap : 0)
    }
}

/// Flutter `Center` (LB:257-263): fills what it is offered, the child in
/// the middle. With `widthFactor` or `heightFactor` that axis is the
/// child's size times the factor (CenterFactorLayout).
@MainActor
struct CenterView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let widthFactor = Props.number(node["widthFactor"])
        let heightFactor = Props.number(node["heightFactor"])
        if widthFactor == nil && heightFactor == nil {
            ChildView(node: node, model: model)
                .environment(\.orcaTight, [])
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            CenterFactorLayout(widthFactor: widthFactor, heightFactor: heightFactor) {
                ChildView(node: node, model: model).environment(\.orcaTight, [])
            }
        }
    }
}

/// Flutter `RenderPositionedBox` with a factor: on an axis with a factor
/// the box is the child's size times it, on one without it fills what is
/// offered (the child's size when unbounded), never more than offered.
/// The child, offered what the box is offered, sits in the middle.
struct CenterFactorLayout: Layout {
    var widthFactor: CGFloat?
    var heightFactor: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let child = subviews.first?.sizeThatFits(proposal) ?? .zero
        return CGSize(width: side(child.width, widthFactor, proposal.width),
                      height: side(child.height, heightFactor, proposal.height))
    }

    private func side(_ child: CGFloat, _ factor: CGFloat?, _ offered: CGFloat?) -> CGFloat {
        let bound = offered.flatMap { $0.isFinite ? $0 : nil }
        guard let factor else { return bound ?? child }
        return min(child * factor, bound ?? .infinity)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        child.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                    proposal: ProposedViewSize(child.sizeThatFits(proposal)))
    }
}

@MainActor
struct PaddingView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .orcaPadding(node["padding"])
    }
}

/// A fixed size on the axes it names; with no child, an empty box of that
/// size (0 on an axis it leaves out).
@MainActor
struct SizedBoxView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let width = Props.number(node["width"])
        let height = Props.number(node["height"])
        if node.childIds.isEmpty {
            Color.clear.frame(width: width ?? 0, height: height ?? 0)
        } else {
            ChildView(node: node, model: model)
                .modifier(AddTight(axes: [width != nil ? .horizontal : [], height != nil ? .vertical : []]))
                .frame(width: width, height: height)
        }
    }
}

/// Flutter `SingleChildScrollView` (LB:203-228). `reverse` puts offset 0
/// at the far end: the view starts there and short content sits there
/// (iOS 17 / macOS 14 `defaultScrollAnchor`; before, a scroll to the end on
/// appear, short content staying at the start). `shrinkWrap` (Flutter's
/// IntrinsicHeight, IntrinsicWidth when horizontal) hugs the content on the
/// scroll axis. `primary` only feeds iOS's status-bar tap in Flutter;
/// SwiftUI has no switch for it, so it is not read (a known difference).
/// A node with onScrollBegin, onScrolling or onScrollEnd gets
/// ScrollTriggers; the others keep their tree.
@MainActor
struct ScrollNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    /// Whether iOS 18 / macOS 15 read the scroll phase; tests turn it off
    /// to run the iOS 16-17 path on a newer simulator.
    static var usesScrollPhase = true

    var body: some View {
        let horizontal = node["scrollDirection"]?.stringValue == "horizontal"
        if node["shrinkWrap"]?.boolValue == true {
            HugLayout(axis: horizontal ? .horizontal : .vertical) { scroll(horizontal) }
        } else {
            scroll(horizontal)
        }
    }

    @ViewBuilder
    private func scroll(_ horizontal: Bool) -> some View {
        if node.actions.keys.contains(where: ScrollEvent.triggers.contains) {
            let triggers = ScrollTriggers(node: node, model: model, horizontal: horizontal,
                                          reverse: node["reverse"]?.boolValue == true, phased: Self.phased)
            if triggers.phased {
                scrollView(horizontal) { content }.modifier(triggers)
            } else {
                scrollView(horizontal) { ScrollTriggers.probe(content) }.modifier(triggers)
            }
        } else {
            scrollView(horizontal) { content }
        }
    }

    @ViewBuilder
    private func scrollView<Content: View>(_ horizontal: Bool, @ViewBuilder content: () -> Content) -> some View {
        let axis: Axis.Set = horizontal ? .horizontal : .vertical
        let end: UnitPoint = horizontal ? .trailing : .bottom
        let content = content()
        if node["reverse"]?.boolValue != true {
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

    private var content: some View {
        ChildView(node: node, model: model)
            .orcaPadding(node["padding"])
    }

    /// The scroll phase is there (iOS 18, macOS 15) and in use.
    static var phased: Bool {
        guard usesScrollPhase else { return false }
        if #available(iOS 18, macOS 15, *) { return true }
        return false
    }
}

/// onScrollBegin, onScrolling and onScrollEnd of a scroll view's node,
/// Flutter `wrapScrollNotifier` (builder_helpers.dart:46-71): each sample
/// of the offset along the view's axis, the content's length and the
/// view's goes through a ScrollObserver with whether a scroll is in
/// progress, and the triggers it yields fire with their payload, in points
/// (Flutter's logical pixels). Draws nothing.
///
/// - iOS 18 / macOS 15 (`phased`): the ScrollGeometry (offset and content
///   counted from the content insets' start) and the ScrollPhase: a scroll
///   is in progress while the phase is scrolling (a drag, its fling, an
///   animation).
/// - iOS 16-17: the content's frame in the view's coordinate space
///   (`probe`, a GeometryReader inside the scroll view) and the view's size.
///   A scroll is in progress while a simultaneous DragGesture is active
///   (begin as the finger starts dragging) and until the offset has held
///   still for ScrollTracker.settleDelay (the end of a fling, or of any
///   other move).
struct ScrollTriggers: ViewModifier {
    static let space = "orca-scroll"

    let node: ResolvedNode
    let model: OrcaPageModel
    let horizontal: Bool
    let reverse: Bool
    let phased: Bool
    @State private var tracker = ScrollTracker()
    @GestureState private var dragging = false

    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, *), phased {
            content
                .onScrollGeometryChange(for: ScrollMetrics.self) { [horizontal, reverse] geometry in
                    Self.metrics(geometry, horizontal: horizontal, reverse: reverse)
                } action: { old, new in
                    fire(tracker.see(new, after: old))
                }
                .onScrollPhaseChange { _, phase in
                    fire(tracker.phase(scrolling: phase.isScrolling))
                }
        } else {
            content
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: ScrollProbe.self, value: ScrollProbe(viewport: geometry.size))
                })
                .coordinateSpace(name: Self.space)
                .onPreferenceChange(ScrollProbe.self) { probe in
                    guard let frame = probe.content, let viewport = probe.viewport else { return }
                    let metrics = ScrollMetrics(offset: horizontal ? -frame.minX : -frame.minY,
                                                contentExtent: horizontal ? frame.width : frame.height,
                                                viewportExtent: horizontal ? viewport.width : viewport.height,
                                                reverse: reverse)
                    fire(tracker.probe(metrics, then: fire))
                }
                // An outer watched scroll view reads its own content, not this one's.
                .transformPreference(ScrollProbe.self) { $0 = ScrollProbe() }
                .simultaneousGesture(DragGesture().updating($dragging) { _, state, _ in state = true })
                .onChange(of: dragging) { active in
                    fire(tracker.drag(active, then: fire))
                }
                // A view that is gone fires no end (a disposed Flutter ScrollPosition sends no ScrollEnd).
                .onAppear { tracker.start() }
                .onDisappear { tracker.stop() }
        }
    }

    /// iOS 16-17: `content` reporting its frame in the scroll view's space.
    static func probe<V: View>(_ content: V) -> some View {
        content.background(GeometryReader { geometry in
            Color.clear.preference(key: ScrollProbe.self,
                                   value: ScrollProbe(content: geometry.frame(in: .named(space))))
        })
    }

    @available(iOS 18, macOS 15, *)
    private static func metrics(_ geometry: ScrollGeometry, horizontal: Bool, reverse: Bool) -> ScrollMetrics {
        let insets = geometry.contentInsets
        return horizontal
            ? ScrollMetrics(offset: geometry.contentOffset.x + insets.leading,
                            contentExtent: geometry.contentSize.width + insets.leading + insets.trailing,
                            viewportExtent: geometry.containerSize.width, reverse: reverse)
            : ScrollMetrics(offset: geometry.contentOffset.y + insets.top,
                            contentExtent: geometry.contentSize.height + insets.top + insets.bottom,
                            viewportExtent: geometry.containerSize.height, reverse: reverse)
    }

    private func fire(_ events: [ScrollEvent]) {
        for event in events { model.fire(event.trigger, on: node, eventData: event.eventData) }
    }
}

/// iOS 16-17: the scroll content's frame in its view's space and the
/// view's size, each from a GeometryReader.
struct ScrollProbe: PreferenceKey, Equatable {
    var content: CGRect?
    var viewport: CGSize?

    static let defaultValue = ScrollProbe()

    static func reduce(value: inout ScrollProbe, nextValue: () -> ScrollProbe) {
        let next = nextValue()
        value.content = next.content ?? value.content
        value.viewport = next.viewport ?? value.viewport
    }
}

/// One watched scroll view's ScrollObserver and what it last saw, kept in
/// the view's state across redraws (a reference: a sample redraws
/// nothing). A scroll is in progress while the scroll phase says so
/// (iOS 18), or while a finger drags or the offset moved less than
/// `settleDelay` ago (iOS 16-17).
@MainActor
final class ScrollTracker {
    /// How long the offset holds still before a scroll ends on iOS 16-17:
    /// a fling moves it every frame until it stops.
    static let settleDelay: TimeInterval = 0.15

    private var observer = ScrollObserver()
    private var metrics: ScrollMetrics?
    private var scrollPhase = false
    private var dragging = false
    private var moving = false
    private var settle: Task<Void, Never>?
    /// iOS 16-17: the view has disappeared; no settle wait starts.
    private var stopped = false

    private var inProgress: Bool { scrollPhase || dragging || moving }

    /// iOS 16-17: the view is on screen again after `stop`. The scroll that
    /// was in progress is dropped, firing nothing; the view's last sample
    /// stays, so its next scroll begins from there (a new Flutter scroll
    /// has a new ScrollStart).
    func start() {
        guard stopped else { return }
        stopped = false
        moving = false
        dragging = false
        observer = ScrollObserver()
        _ = metrics.map { observer.observe($0, inProgress: false) }
    }

    /// iOS 16-17: the view has gone: the settle wait is cancelled, and none
    /// starts until it appears again (a @GestureState reset that follows
    /// the disappearance included), so no onScrollEnd fires for it.
    func stop() {
        stopped = true
        settle?.cancel()
        settle = nil
    }

    /// iOS 18: a new sample; `old`, where the view stood before it, is the
    /// first sample when there was none (the geometry's first change).
    func see(_ new: ScrollMetrics, after old: ScrollMetrics) -> [ScrollEvent] {
        let first = metrics == nil ? see(old) : []
        return first + see(new)
    }

    /// iOS 18: the scroll phase is scrolling, or no longer.
    func phase(scrolling: Bool) -> [ScrollEvent] {
        scrollPhase = scrolling
        return again()
    }

    /// iOS 16-17: a sample from the probe. A new offset is a scroll in
    /// progress until it settles; `fire` gets the end.
    func probe(_ new: ScrollMetrics, then fire: @escaping ([ScrollEvent]) -> Void) -> [ScrollEvent] {
        if let metrics, metrics.offset != new.offset { moving = true; awaitSettle(fire) }
        return see(new)
    }

    /// iOS 16-17: a finger starts dragging the view (the scroll begins) or
    /// lifts (it ends once the view settles).
    func drag(_ active: Bool, then fire: @escaping ([ScrollEvent]) -> Void) -> [ScrollEvent] {
        dragging = active
        guard !active else { return again() }
        moving = true
        awaitSettle(fire)
        return []
    }

    private func see(_ new: ScrollMetrics) -> [ScrollEvent] {
        metrics = new
        return observer.observe(new, inProgress: inProgress)
    }

    private func again() -> [ScrollEvent] {
        metrics.map(see) ?? []
    }

    private func awaitSettle(_ fire: @escaping ([ScrollEvent]) -> Void) {
        settle?.cancel()
        guard !stopped else { return }
        settle = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.settleDelay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            moving = false
            fire(again())
        }
    }
}

/// Flutter `IntrinsicHeight` (`IntrinsicWidth` on `.horizontal`) around a
/// scroll view: as long as its content on `axis`, never longer than offered.
struct HugLayout: Layout {
    var axis: Axis

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        var ideal = proposal
        if axis == .vertical { ideal.height = nil } else { ideal.width = nil }
        var size = child.sizeThatFits(ideal)
        if axis == .vertical, let offered = proposal.height { size.height = min(size.height, offered) }
        if axis == .horizontal, let offered = proposal.width { size.width = min(size.width, offered) }
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
/// Adds axes to the tight set the children see.
struct AddTight: ViewModifier {
    let axes: TightAxes
    @Environment(\.orcaTight) private var tight

    func body(content: Content) -> some View {
        content.environment(\.orcaTight, tight.union(axes))
    }
}
#endif
