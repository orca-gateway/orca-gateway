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
@MainActor
struct ScrollNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

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
        let axis: Axis.Set = horizontal ? .horizontal : .vertical
        let end: UnitPoint = horizontal ? .trailing : .bottom
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
