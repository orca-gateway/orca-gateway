#if canImport(SwiftUI)
import SwiftUI

// The sizing wrappers of the Flutter SDK's layout_builders.dart (LB:265-286,
// :487-521), each laid out as the Flutter render object it builds. SwiftUI
// offers a view a size and lets it pick its own, so each is a Layout that
// reads the offer as Flutter's BoxConstraints (BoxLimits) and sizes the box
// and its child as Flutter does. A missing child is Flutter's
// `SizedBox.shrink()` (BH:19-22), a child of size zero.

/// Flutter `BoxConstraints` as a SwiftUI view is offered them: the proposal
/// is the maximum on each axis (nil or infinite: unbounded), and an axis the
/// parent forces (TightAxes) has its minimum there as well; otherwise the
/// minimum is 0.
struct BoxLimits: Equatable {
    var minWidth: CGFloat = 0
    var maxWidth: CGFloat = .infinity
    var minHeight: CGFloat = 0
    var maxHeight: CGFloat = .infinity

    init(minWidth: CGFloat = 0, maxWidth: CGFloat = .infinity, minHeight: CGFloat = 0,
         maxHeight: CGFloat = .infinity) {
        (self.minWidth, self.maxWidth, self.minHeight, self.maxHeight) = (minWidth, maxWidth, minHeight, maxHeight)
    }

    init(_ proposal: ProposedViewSize, tight: TightAxes) {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let height = proposal.height.flatMap { $0.isFinite ? $0 : nil }
        maxWidth = width ?? .infinity
        maxHeight = height ?? .infinity
        minWidth = tight.contains(.horizontal) ? width ?? 0 : 0
        minHeight = tight.contains(.vertical) ? height ?? 0 : 0
    }

    /// The maximum as a SwiftUI proposal, nil where unbounded.
    var proposal: ProposedViewSize {
        ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: maxHeight.isFinite ? maxHeight : nil)
    }

    /// The axes whose minimum is their maximum: a child there is forced.
    var tightAxes: TightAxes {
        [minWidth >= maxWidth ? .horizontal : [], minHeight >= maxHeight ? .vertical : []]
    }

    var isTight: Bool { tightAxes == [.horizontal, .vertical] }

    var loosened: BoxLimits { BoxLimits(maxWidth: maxWidth, maxHeight: maxHeight) }

    func constrain(_ size: CGSize) -> CGSize {
        CGSize(width: min(max(size.width, minWidth), maxWidth), height: min(max(size.height, minHeight), maxHeight))
    }

    /// Flutter `enforce`: these limits, each kept within `outer`'s.
    func enforced(in outer: BoxLimits) -> BoxLimits {
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat { min(max(value, low), high) }
        return BoxLimits(minWidth: clamp(minWidth, outer.minWidth, outer.maxWidth),
                         maxWidth: clamp(maxWidth, outer.minWidth, outer.maxWidth),
                         minHeight: clamp(minHeight, outer.minHeight, outer.maxHeight),
                         maxHeight: clamp(maxHeight, outer.minHeight, outer.maxHeight))
    }

    /// Flutter `constrainSizeAndAttemptToPreserveAspectRatio`.
    func preservingAspectRatio(_ size: CGSize) -> CGSize {
        if isTight { return constrain(.zero) }
        guard size.width > 0, size.height > 0 else { return constrain(size) }
        let ratio = size.width / size.height
        var width = size.width, height = size.height
        if width > maxWidth { width = maxWidth; height = width / ratio }
        if height > maxHeight { height = maxHeight; width = height * ratio }
        if width < minWidth { width = minWidth; height = width / ratio }
        if height < minHeight { height = minHeight; width = height * ratio }
        return constrain(CGSize(width: width, height: height))
    }
}

/// A ConstrainedBox's min for its own child (`id`): SwiftUI proposes a
/// maximum only, so Flutter's incoming minimum travels here. Only that child
/// reads it; a grandchild (under a Padding, a Center, a Row) never sees it.
struct ChildMinimum: Equatable {
    var id: String
    var size: CGSize
}

private struct ChildMinimumKey: EnvironmentKey {
    static let defaultValue: ChildMinimum? = nil
}

private struct UnboundedAxesKey: EnvironmentKey {
    static let defaultValue: TightAxes = []
}

extension EnvironmentValues {
    /// The min a ConstrainedBox sets for its child (see ChildMinimum).
    var orcaMinimum: ChildMinimum? {
        get { self[ChildMinimumKey.self] }
        set { self[ChildMinimumKey.self] = newValue }
    }

    /// The axes on which the offer is a Row's or Column's share of its main
    /// axis (an HStack or VStack), which Flutter leaves unbounded (RenderFlex
    /// lays a non-flex child out with no main-axis max, flex.dart
    /// `_computeSizes`): there the offer is no maximum. A Row or Column adds
    /// its main axis (FlexLayout takes it out: a flex child's share is its
    /// maximum); a set size, a forced axis or a ConstrainedBox max takes the
    /// axis out (AddTight, Bound).
    var orcaUnbounded: TightAxes {
        get { self[UnboundedAxesKey.self] }
        set { self[UnboundedAxesKey.self] = newValue }
    }
}

/// Flutter `ConstrainedBox(BoxConstraints.tightFor(width:height:))`, what a
/// Container (container.dart:284) or SizedBox with a set width or height
/// is, laid out with `enforce` (proxy_box.dart:303-313): a set axis is that
/// size kept within the incoming limits (a forced axis wins, a smaller max
/// caps it, a larger min raises it) and its child is offered it; an unset
/// axis is the child's size, at least the incoming min. The limits are
/// BoxLimits from the offer and the forced axes, with no maximum on an
/// `unbounded` axis and at least `minimum` (a ConstrainedBox's min).
struct TightForLayout: Layout {
    var width: CGFloat?
    var height: CGFloat?
    var tight: TightAxes
    var unbounded: TightAxes
    var minimum: CGSize

    private func limits(_ proposal: ProposedViewSize) -> BoxLimits {
        var outer = BoxLimits(proposal, tight: tight)
        if unbounded.contains(.horizontal), !tight.contains(.horizontal) { outer.maxWidth = .infinity }
        if unbounded.contains(.vertical), !tight.contains(.vertical) { outer.maxHeight = .infinity }
        return BoxLimits(minWidth: minimum.width, minHeight: minimum.height).enforced(in: outer)
    }

    /// The set axes within the limits (`tighten`), the offer on the others.
    private func offer(_ proposal: ProposedViewSize) -> ProposedViewSize {
        let set = limits(proposal).tightened(width: width, height: height)
        return ProposedViewSize(width: width != nil ? set.maxWidth : proposal.width,
                                height: height != nil ? set.maxHeight : proposal.height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limits = limits(proposal)
        let offer = offer(proposal)
        let child = subviews.first?.sizeThatFits(offer) ?? .zero
        return CGSize(width: width != nil ? offer.width ?? 0 : max(child.width, limits.minWidth),
                      height: height != nil ? offer.height ?? 0 : max(child.height, limits.minHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(
            width: width != nil ? bounds.width : proposal.width, height: height != nil ? bounds.height : proposal.height))
    }
}

/// TightForLayout around the content when a size is set or a min applies;
/// otherwise the content as it is.
struct TightFor: ViewModifier {
    var width: CGFloat?
    var height: CGFloat?
    var minimum: CGSize = .zero
    @Environment(\.orcaTight) private var tight
    @Environment(\.orcaUnbounded) private var unbounded

    func body(content: Content) -> some View {
        if width == nil && height == nil && minimum == .zero {
            content
        } else {
            TightForLayout(width: width, height: height, tight: tight, unbounded: unbounded, minimum: minimum) {
                content
            }
        }
    }
}

extension ChildMinimum? {
    /// The min for the node `id`: zero unless its parent set it for it.
    func size(for id: String) -> CGSize {
        self.flatMap { $0.id == id ? $0.size : nil } ?? .zero
    }
}

extension Props {
    /// Flutter `parseAlignment` as an absolute point: SwiftUI mirrors a
    /// layout's placements in right-to-left, so it is mirrored first and
    /// `topLeft` stays on the left (as ImageNodeView does).
    static func absoluteAlignment(_ value: JSONValue?, direction: LayoutDirection) -> UnitPoint {
        let point = unitPoint(value)
        return direction == .rightToLeft ? UnitPoint(x: 1 - point.x, y: point.y) : point
    }
}

// MARK: - Align

/// Flutter `Align` (LB:265-272), RenderPositionedBox: the child, loosened,
/// at `alignment` (the nine names, default center); an axis with a factor
/// shrink-wraps the child times it, one without fills a bounded parent and
/// is the child's size in an unbounded one (CenterFactorLayout).
@MainActor
struct AlignView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        CenterFactorLayout(widthFactor: Props.number(node["widthFactor"]),
                           heightFactor: Props.number(node["heightFactor"]),
                           alignment: Props.absoluteAlignment(node["alignment"], direction: direction),
                           tight: tight) {
            ChildView(node: node, model: model).environment(\.orcaTight, [])
        }
    }
}

// MARK: - AspectRatio

/// Flutter `AspectRatio` (LB:281-286), RenderAspectRatio: `aspectRatio`
/// (width over height, default 1) sizes the box from the width offered, or
/// from the height when the width is unbounded, then within the limits; the
/// child is given that size.
@MainActor
struct AspectRatioView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        AspectRatioLayout(ratio: Props.number(node["aspectRatio"]) ?? 1, tight: tight) {
            ChildView(node: node, model: model).modifier(AddTight(axes: [.horizontal, .vertical]))
        }
    }
}

/// RenderAspectRatio `_applyAspectRatio`. Unbounded both ways (Flutter
/// throws) it is empty.
struct AspectRatioLayout: Layout {
    var ratio: CGFloat
    var tight: TightAxes

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limits = BoxLimits(proposal, tight: tight)
        if limits.isTight { return limits.constrain(.zero) }
        var width = limits.maxWidth
        var height: CGFloat
        if width.isFinite {
            height = width / ratio
        } else {
            height = limits.maxHeight
            width = height * ratio
        }
        if width > limits.maxWidth { width = limits.maxWidth; height = width / ratio }
        if height > limits.maxHeight { height = limits.maxHeight; width = height * ratio }
        if width < limits.minWidth { width = limits.minWidth; height = width / ratio }
        if height < limits.minHeight { height = limits.minHeight; width = height * ratio }
        let size = limits.constrain(CGSize(width: width, height: height))
        return size.width.isFinite && size.height.isFinite ? size : .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

// MARK: - ConstrainedBox

/// Flutter `ConstrainedBox` (LB:487-503), RenderConstrainedBox: the child
/// is laid out within `constraints` (a missing min 0, max unbounded) kept
/// inside the parent's (`enforce`), and the box is its size. An axis the
/// parent forces, or whose min is its max, forces the child.
///
/// The min reaches the child as `orcaMinimum`: a Container or SizedBox
/// child keeps to it (TightForLayout). Known limit: a child that hugs its
/// content (a Text, a button) is not stretched up to the min unless that
/// axis is forced; Flutter (and the Kotlin SDK) raise it. The child then
/// sits at the box's top leading corner.
@MainActor
struct ConstrainedBoxView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        let constraints = node["constraints"]
        let additional = BoxLimits(minWidth: Props.number(constraints?["minWidth"]) ?? 0,
                                   maxWidth: Props.number(constraints?["maxWidth"]) ?? .infinity,
                                   minHeight: Props.number(constraints?["minHeight"]) ?? 0,
                                   maxHeight: Props.number(constraints?["maxHeight"]) ?? .infinity)
        ConstrainedLayout(additional: additional, tight: tight) {
            ChildView(node: node, model: model).environment(\.orcaTight, tight.union(additional.tightAxes))
                .modifier(Bound(axes: [additional.maxWidth.isFinite ? .horizontal : [],
                                       additional.maxHeight.isFinite ? .vertical : []]))
                .environment(\.orcaMinimum, node.childIds.first.map {
                    ChildMinimum(id: $0, size: CGSize(width: additional.minWidth, height: additional.minHeight))
                })
        }
    }
}

/// The child offered the enforced maximum; the box's size is the child's
/// held to the enforced limits, as a Flutter child keeps to its
/// constraints. Only the box is held: a child smaller than the min keeps
/// its own size inside it (see ConstrainedBoxView).
struct ConstrainedLayout: Layout {
    var additional: BoxLimits
    var tight: TightAxes

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let inner = additional.enforced(in: BoxLimits(proposal, tight: tight))
        return inner.constrain(subviews.first?.sizeThatFits(inner.proposal) ?? .zero)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

// MARK: - LimitedBox

/// Flutter `LimitedBox` (LB:506-512), RenderLimitedBox: `maxWidth` and
/// `maxHeight` (missing: unbounded) cap only an axis the parent leaves
/// unbounded (a scroll view's scroll axis); under a bounded one it passes
/// its constraints through.
@MainActor
struct LimitedBoxView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        LimitedLayout(maxWidth: Props.number(node["maxWidth"]) ?? .infinity,
                      maxHeight: Props.number(node["maxHeight"]) ?? .infinity, tight: tight) {
            ChildView(node: node, model: model)
        }
    }
}

/// RenderLimitedBox `_limitConstraints`, then the child's size within the
/// parent's limits.
struct LimitedLayout: Layout {
    var maxWidth: CGFloat
    var maxHeight: CGFloat
    var tight: TightAxes

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let outer = BoxLimits(proposal, tight: tight)
        var inner = outer
        if !outer.maxWidth.isFinite { inner.maxWidth = max(maxWidth, outer.minWidth) }
        if !outer.maxHeight.isFinite { inner.maxHeight = max(maxHeight, outer.minHeight) }
        return outer.constrain(inner.constrain(subviews.first?.sizeThatFits(inner.proposal) ?? .zero))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

// MARK: - FractionallySizedBox

/// Flutter `FractionallySizedBox` (LB:514-521),
/// RenderFractionallySizedOverflowBox: an axis with a factor forces the
/// child to the parent's maximum times it, one without passes the parent's
/// constraints on; the box is the child's size within the parent's limits,
/// the child at `alignment` (default center), overflowing when bigger.
@MainActor
struct FractionallySizedBoxView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let widthFactor = Props.number(node["widthFactor"])
        let heightFactor = Props.number(node["heightFactor"])
        FractionalLayout(widthFactor: widthFactor, heightFactor: heightFactor,
                         alignment: Props.absoluteAlignment(node["alignment"], direction: direction), tight: tight) {
            ChildView(node: node, model: model)
                .modifier(AddTight(axes: [widthFactor != nil ? .horizontal : [], heightFactor != nil ? .vertical : []]))
        }
    }
}

/// `_getInnerConstraints`; a factor on an unbounded axis (Flutter throws)
/// leaves that axis as the parent's.
struct FractionalLayout: Layout {
    var widthFactor: CGFloat?
    var heightFactor: CGFloat?
    var alignment: UnitPoint
    var tight: TightAxes

    private func child(_ proposal: ProposedViewSize, _ subviews: Subviews) -> (outer: BoxLimits, size: CGSize) {
        let outer = BoxLimits(proposal, tight: tight)
        var inner = outer
        if let widthFactor, outer.maxWidth.isFinite {
            inner.maxWidth = outer.maxWidth * widthFactor
            inner.minWidth = inner.maxWidth
        }
        if let heightFactor, outer.maxHeight.isFinite {
            inner.maxHeight = outer.maxHeight * heightFactor
            inner.minHeight = inner.maxHeight
        }
        return (outer, inner.constrain(subviews.first?.sizeThatFits(inner.proposal) ?? .zero))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let (outer, size) = child(proposal, subviews)
        return outer.constrain(size)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = child(proposal, subviews).size
        subviews.first?.place(at: CGPoint(x: bounds.minX + (bounds.width - size.width) * alignment.x,
                                          y: bounds.minY + (bounds.height - size.height) * alignment.y),
                              proposal: ProposedViewSize(size))
    }
}

// MARK: - FittedBox

/// Flutter `FittedBox` (LB:274-279), RenderFittedBox: the child is laid out
/// unconstrained (its ideal size); the box is that size kept within the
/// parent's limits at the child's aspect ratio (scaleDown: never bigger
/// than the child); the child is scaled into the box per `fit` (default
/// contain, ImageFit's maths) and always centred, since Flutter's builder
/// does not read `alignment`. Nothing is clipped (Flutter's Clip.none), so
/// cover draws past the box.
@MainActor
struct FittedBoxView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        let fit = ImageFit(rawValue: node["fit"]?.stringValue ?? "") ?? .contain
        FittedLayout(fit: fit, tight: tight) {
            FitScaleLayout(fit: fit) {
                ChildView(node: node, model: model).environment(\.orcaTight, []).modifier(UnitScale())
            }
            .modifier(SizeScale())
        }
    }
}

/// RenderFittedBox `performLayout`: the box's size; the child's frame
/// (FitScaleLayout) is centred in it.
struct FittedLayout: Layout {
    var fit: ImageFit
    var tight: TightAxes

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limits = BoxLimits(proposal, tight: tight)
        let natural = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        return fit == .scaleDown ? limits.constrain(limits.loosened.preservingAspectRatio(natural))
            : limits.preservingAspectRatio(natural)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                              proposal: ProposedViewSize(bounds.size))
    }
}

/// The child at its ideal size: measured unconstrained it is that size;
/// offered the box, it is the size the fit draws the child at in it, the
/// child in its middle. UnitScale on the child and SizeScale on this frame
/// then draw the child at this size in one layout pass.
struct FitScaleLayout: Layout {
    var fit: ImageFit

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let natural = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        guard let width = proposal.width, let height = proposal.height else { return natural }
        return fit.rect(for: natural, in: CGSize(width: width, height: height), alignment: .center).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
    }
}

/// Draws a view as a 1 by 1 square about its centre (an empty view as it
/// is; SizeScale then draws it at size zero).
struct UnitScale: GeometryEffect {
    func effectValue(size: CGSize) -> ProjectionTransform {
        guard size.width > 0, size.height > 0 else { return ProjectionTransform() }
        return .scale(1 / size.width, 1 / size.height, about: size)
    }
}

/// Draws a 1 by 1 square at its centre as big as the view.
struct SizeScale: GeometryEffect {
    func effectValue(size: CGSize) -> ProjectionTransform {
        .scale(size.width, size.height, about: size)
    }
}

private extension ProjectionTransform {
    static func scale(_ x: CGFloat, _ y: CGFloat, about size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .scaledBy(x: x, y: y)
            .translatedBy(x: -size.width / 2, y: -size.height / 2))
    }
}
#endif
