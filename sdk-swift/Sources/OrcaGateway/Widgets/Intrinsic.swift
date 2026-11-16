#if canImport(SwiftUI)
import SwiftUI

// IntrinsicHeight, IntrinsicWidth and Baseline of the Flutter SDK's
// layout_builders.dart (LB:434-446, :469-479), each a Layout porting its
// Flutter render object. A child's max intrinsic size on an axis is its
// size when SwiftUI proposes nothing on that axis (its ideal size), at the
// other axis's maximum. Limits are read as BoxLimits (Sizing.swift); a
// missing child is Flutter's `SizedBox.shrink()`.

extension BoxLimits {
    /// Flutter `BoxConstraints.tighten`, which is `tightFor(width:height:)
    /// .enforce(this)`: a given width or height, kept within these limits,
    /// becomes both their min and max.
    func tightened(width: CGFloat?, height: CGFloat?) -> BoxLimits {
        BoxLimits(minWidth: width ?? 0, maxWidth: width ?? .infinity,
                  minHeight: height ?? 0, maxHeight: height ?? .infinity).enforced(in: self)
    }
}

private struct IntrinsicHeightKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Inside IntrinsicHeight (or IntrinsicWidth with `stepHeight`), whose
    /// own layout forces the height: an unbounded height there is the max
    /// intrinsic height measure, which SwiftUI cannot tell from a layout.
    /// Baseline then answers with its child's height, as Flutter's
    /// RenderShiftedBox intrinsics do.
    var orcaIntrinsicHeight: Bool {
        get { self[IntrinsicHeightKey.self] }
        set { self[IntrinsicHeightKey.self] = newValue }
    }
}

/// The child laid out within `inner` and the box its size, from the top
/// leading corner (RenderProxyBox).
private func proxy(_ inner: BoxLimits, _ subviews: LayoutSubviews) -> CGSize {
    inner.constrain(subviews.first?.sizeThatFits(inner.proposal) ?? .zero)
}

// MARK: - IntrinsicHeight

/// Flutter `IntrinsicHeight` (LB:434-436), RenderIntrinsicHeight: unless
/// the parent forces the height, the child is forced to its max intrinsic
/// height at the width offered, kept within the parent's limits; the box is
/// the child's size. Around a Row with `stretch` every child is then as
/// tall as the tallest.
@MainActor
struct IntrinsicHeightView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        IntrinsicHeightLayout(tight: tight) {
            ChildView(node: node, model: model).modifier(AddTight(axes: .vertical))
                .environment(\.orcaIntrinsicHeight, true)
        }
    }
}

/// RenderIntrinsicHeight `_childConstraints`.
struct IntrinsicHeightLayout: Layout {
    var tight: TightAxes

    private func inner(_ proposal: ProposedViewSize, _ subviews: Subviews) -> BoxLimits {
        let limits = BoxLimits(proposal, tight: tight)
        guard let child = subviews.first, !limits.tightAxes.contains(.vertical) else { return limits }
        return limits.tightened(width: nil, height: child.sizeThatFits(
            ProposedViewSize(width: limits.proposal.width, height: nil)).height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proxy(inner(proposal, subviews), subviews)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

// MARK: - IntrinsicWidth

/// Flutter `IntrinsicWidth` (LB:438-446), RenderIntrinsicWidth: unless the
/// parent forces the width, the child is forced to its max intrinsic width
/// at the height offered, rounded up to a multiple of `stepWidth`; with
/// `stepHeight` the height is forced too, to the max intrinsic height at
/// the width offered rounded up to a multiple of it. Both are kept within
/// the parent's limits; the box is the child's size. Around a Column with
/// `stretch` every child is then as wide as the widest.
@MainActor
struct IntrinsicWidthView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        let stepHeight = Props.number(node["stepHeight"])
        IntrinsicWidthLayout(stepWidth: Props.number(node["stepWidth"]), stepHeight: stepHeight, tight: tight) {
            ChildView(node: node, model: model)
                .modifier(AddTight(axes: [.horizontal, stepHeight != nil ? .vertical : []]))
                .modifier(IntrinsicHeightIf(on: stepHeight != nil))
        }
    }
}

/// RenderIntrinsicWidth `_childConstraints`.
struct IntrinsicWidthLayout: Layout {
    var stepWidth: CGFloat?
    var stepHeight: CGFloat?
    var tight: TightAxes

    /// `_applyStep`: `value` rounded up to a multiple of `step` (a step of
    /// 0 or less, which Flutter asserts against, is ignored).
    static func step(_ value: CGFloat, _ step: CGFloat?) -> CGFloat {
        guard let step, step > 0 else { return value }
        return (value / step).rounded(.up) * step
    }

    private func inner(_ proposal: ProposedViewSize, _ subviews: Subviews) -> BoxLimits {
        let limits = BoxLimits(proposal, tight: tight)
        guard let child = subviews.first else { return limits }
        let width = limits.tightAxes.contains(.horizontal) ? nil : Self.step(child.sizeThatFits(
            ProposedViewSize(width: nil, height: limits.proposal.height)).width, stepWidth)
        let height = stepHeight == nil ? nil : Self.step(child.sizeThatFits(
            ProposedViewSize(width: limits.proposal.width, height: nil)).height, stepHeight)
        return limits.tightened(width: width, height: height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proxy(inner(proposal, subviews), subviews)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// Sets `orcaIntrinsicHeight` when `on`; keeps the ambient value otherwise.
private struct IntrinsicHeightIf: ViewModifier {
    let on: Bool

    func body(content: Content) -> some View {
        if on {
            content.environment(\.orcaIntrinsicHeight, true)
        } else {
            content
        }
    }
}

// MARK: - Baseline

/// Flutter `Baseline` (LB:469-479), RenderBaseline: the child, laid out
/// loosely, has its first text baseline `baseline` (default 0) below the
/// box's top; a child without text uses its height. `ideographic` is drawn
/// as alphabetic (decision s3-baseline-ideographic: SwiftUI exposes no
/// ideographic baseline). The child sits at the left edge, in right-to-left
/// too; the box is the child's width by the child's bottom, within the
/// parent's limits. It aligns nothing else: two texts in Baselines of the
/// same value line up because each puts its baseline there. Measured for
/// IntrinsicHeight (`orcaIntrinsicHeight`, an unbounded height) it is as
/// tall as its child (RenderShiftedBox intrinsics, shifted_box.dart:38-56).
@MainActor
struct BaselineView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight
    @Environment(\.orcaIntrinsicHeight) private var intrinsic
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        BaselineLayout(baseline: Props.number(node["baseline"]) ?? 0, tight: tight, intrinsic: intrinsic,
                       rightToLeft: direction == .rightToLeft) {
            ChildView(node: node, model: model).environment(\.orcaTight, [])
        }
    }
}

/// RenderBaseline `_computeSizes`.
struct BaselineLayout: Layout {
    var baseline: CGFloat
    var tight: TightAxes
    var intrinsic: Bool
    var rightToLeft: Bool

    private func layout(_ proposal: ProposedViewSize, _ subviews: Subviews)
        -> (size: CGSize, child: CGSize, top: CGFloat) {
        let limits = BoxLimits(proposal, tight: tight)
        guard let child = subviews.first else { return (limits.constrain(.zero), .zero, 0) }
        let dimensions = child.dimensions(in: limits.loosened.proposal)
        let size = CGSize(width: dimensions.width, height: dimensions.height)
        let top = baseline - dimensions[VerticalAlignment.firstTextBaseline]
        let height = intrinsic && !limits.maxHeight.isFinite ? size.height : top + size.height
        return (limits.constrain(CGSize(width: size.width, height: height)), size, top)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (_, child, top) = layout(proposal, subviews)
        // SwiftUI mirrors a layout in right-to-left; Flutter's offset is absolute.
        subviews.first?.place(at: CGPoint(x: rightToLeft ? bounds.maxX - child.width : bounds.minX,
                                          y: bounds.minY + top),
                              proposal: ProposedViewSize(child))
    }
}
#endif
