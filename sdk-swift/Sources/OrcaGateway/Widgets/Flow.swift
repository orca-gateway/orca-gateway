#if canImport(SwiftUI)
import SwiftUI

// Wrap, Offstage and SafeArea of the Flutter SDK's layout_builders.dart
// (LB:188-201, :448-453, :295-303). Wrap and Offstage are Layouts porting
// their Flutter render objects, their limits read as BoxLimits (Sizing.swift);
// SafeArea maps its edges onto SwiftUI's safe area.

// MARK: - Wrap

/// Flutter `Wrap` (LB:188-201), RenderWrap: each child is laid out loosely
/// (main axis up to the Wrap's maximum, cross axis unbounded), then
/// WrapRuns breaks them into runs and places them. `spacing` and
/// `runSpacing` default to 0, `alignment` (six values) and
/// `crossAxisAlignment` (start, end, center; anything else start) to start,
/// `direction` "vertical" is vertical (the engine cannot send it). It takes
/// the ambient direction: SwiftUI mirrors the placements in right-to-left,
/// as Flutter mirrors a Wrap there. Measured for IntrinsicHeight
/// (`orcaIntrinsicHeight`, an unbounded height) a vertical Wrap is its
/// children's heights summed with no spacing
/// (RenderWrap.computeMaxIntrinsicHeight); a horizontal one is the height of
/// its runs at the width offered, as in Flutter.
@MainActor
struct WrapView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight
    @Environment(\.orcaIntrinsicHeight) private var intrinsicHeight

    var body: some View {
        WrapRunsLayout(axis: node["direction"]?.stringValue == "vertical" ? .vertical : .horizontal,
                       spacing: Props.number(node["spacing"]) ?? 0,
                       runSpacing: Props.number(node["runSpacing"]) ?? 0,
                       alignment: WrapAlignment.of(node["alignment"]?.stringValue),
                       crossAlignment: WrapCrossAlignment.of(node["crossAxisAlignment"]?.stringValue),
                       tight: tight, intrinsicHeight: intrinsicHeight) {
            ForEach(node.childIds, id: \.self) { NodeView(id: $0, model: model) }
        }
        .environment(\.orcaTight, [])
    }
}

/// RenderWrap `performLayout` over WrapRuns.
struct WrapRunsLayout: Layout {
    var axis: Axis
    var spacing: CGFloat
    var runSpacing: CGFloat
    var alignment: WrapAlignment
    var crossAlignment: WrapCrossAlignment
    var tight: TightAxes
    var intrinsicHeight: Bool

    private func layout(_ proposal: ProposedViewSize, _ subviews: Subviews)
        -> (limits: BoxLimits, child: ProposedViewSize, sizes: [WrapSize], runs: WrapLayout) {
        let limits = BoxLimits(proposal, tight: tight)
        let horizontal = axis == .horizontal
        let child = horizontal ? ProposedViewSize(width: limits.proposal.width, height: nil)
            : ProposedViewSize(width: nil, height: limits.proposal.height)
        let sizes = subviews.map { subview -> WrapSize in
            let size = subview.sizeThatFits(child)
            return horizontal ? WrapSize(main: size.width, cross: size.height)
                : WrapSize(main: size.height, cross: size.width)
        }
        let runs = WrapRuns.layout(sizes,
                                   minMain: horizontal ? limits.minWidth : limits.minHeight,
                                   maxMain: horizontal ? limits.maxWidth : limits.maxHeight,
                                   minCross: horizontal ? limits.minHeight : limits.minWidth,
                                   maxCross: horizontal ? limits.maxHeight : limits.maxWidth,
                                   spacing: spacing, runSpacing: runSpacing,
                                   alignment: alignment, crossAlignment: crossAlignment)
        return (limits, child, sizes, runs)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let (limits, _, sizes, runs) = layout(proposal, subviews)
        if intrinsicHeight, axis == .vertical, !limits.maxHeight.isFinite {
            // The children were measured unconstrained (`.unspecified`): their max intrinsic heights.
            return CGSize(width: runs.size.cross, height: sizes.reduce(0) { $0 + $1.main })
        }
        return axis == .horizontal ? CGSize(width: runs.size.main, height: runs.size.cross)
            : CGSize(width: runs.size.cross, height: runs.size.main)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (_, child, _, runs) = layout(proposal, subviews)
        for (subview, offset) in zip(subviews, runs.offsets) {
            let x = axis == .horizontal ? offset.main : offset.cross
            let y = axis == .horizontal ? offset.cross : offset.main
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: child)
        }
    }
}

// MARK: - Offstage

/// Flutter `Offstage` (LB:448-453, `offstage` default true), RenderOffstage
/// (proxy_box.dart:3842-3880): offstage, the child stays in the tree with
/// the same identity (its state survives toggling) but the box is as small
/// as the parent allows (zero, or the size the parent forces), and the
/// child is not drawn, takes no hits and is out of accessibility. With
/// `offstage` false it is its child.
@MainActor
struct OffstageView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        let offstage = Props.bool(node["offstage"]) ?? true
        OffstageLayout(offstage: offstage, tight: tight) {
            ChildView(node: node, model: model)
                .opacity(offstage ? 0 : 1)
                .allowsHitTesting(!offstage)
                .accessibilityHidden(offstage)
        }
    }
}

/// RenderOffstage `computeDryLayout`: `constraints.smallest` when offstage,
/// else the child's size. The child is laid out at its origin either way.
struct OffstageLayout: Layout {
    var offstage: Bool
    var tight: TightAxes

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let smallest = BoxLimits(proposal, tight: tight).constrain(.zero)
        guard !offstage, let child = subviews.first else { return smallest }
        return child.sizeThatFits(proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: proposal)
    }
}

// MARK: - SafeArea

private struct SafeAreaTakenKey: EnvironmentKey {
    static let defaultValue: Edge.Set = []
}

extension EnvironmentValues {
    /// The edges whose inset a SafeArea above already took: Flutter removes
    /// them from the MediaQuery padding below it, so a nested SafeArea
    /// neither adds them again nor lets its content back into them.
    var orcaSafeAreaTaken: Edge.Set {
        get { self[SafeAreaTakenKey.self] }
        set { self[SafeAreaTakenKey.self] = newValue }
    }
}

/// Flutter `SafeArea` (LB:295-303; widgets/safe_area.dart:112-135): `top`,
/// `bottom`, `left` and `right`, each true by default. SwiftUI already lays
/// a page out inside the safe area (OrcaPageView, the Scaffold's body under
/// its AppBar and bottom bars), so an edge flagged true keeps its content
/// clear of that inset by adding nothing, and nothing is ever added twice;
/// an edge flagged false lets the content into the inset
/// (`ignoresSafeArea(.container)`; the keyboard still pushes it up), unless
/// a SafeArea above took that edge. `left` and `right` are the screen's, in
/// right-to-left too.
@MainActor
struct SafeAreaView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaSafeAreaTaken) private var taken
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let kept = keptEdges
        ChildView(node: node, model: model)
            .environment(\.orcaSafeAreaTaken, taken.union(kept))
            .ignoresSafeArea(.container, edges: Edge.Set.all.subtracting(kept).subtracting(taken))
    }

    /// The edges flagged true, `left` and `right` as leading and trailing.
    private var keptEdges: Edge.Set {
        let rightToLeft = direction == .rightToLeft
        var edges: Edge.Set = []
        if Props.bool(node["top"]) != false { edges.insert(.top) }
        if Props.bool(node["bottom"]) != false { edges.insert(.bottom) }
        if Props.bool(node["left"]) != false { edges.insert(rightToLeft ? .trailing : .leading) }
        if Props.bool(node["right"]) != false { edges.insert(rightToLeft ? .leading : .trailing) }
        return edges
    }
}
#endif
