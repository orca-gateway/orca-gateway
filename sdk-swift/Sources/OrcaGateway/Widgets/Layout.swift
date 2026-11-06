#if canImport(SwiftUI)
import SwiftUI

/// Column and Row (Flutter `Flex`): no implicit spacing, `gap` between
/// children only, main-axis alignment with spacers, `mainAxisSize: max` (the
/// default) fills the main axis. `spaceAround` is drawn like `spaceEvenly`.
///
/// A Row or Column with an Expanded or Spacer child is drawn by FlexLayout,
/// which shares the space by `flex`; every other one keeps the stack below,
/// so pages that drew before draw exactly as before.
@MainActor
struct FlexView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    let axis: Axis

    var body: some View {
        content.environment(\.orcaTight, stretched ? TightAxes(axis == .vertical ? .horizontal : .vertical) : [])
    }

    private var stretched: Bool { Props.crossAxis(node["crossAxisAlignment"]) == .stretch }

    @ViewBuilder
    private var content: some View {
        let flexes = node.childIds.map(flex(of:))
        if flexes.contains(where: { $0 > 0 }) {
            FlexLayout(axis: axis, cross: Props.crossAxis(node["crossAxisAlignment"]),
                       fill: Props.fillsMainAxis(node["mainAxisSize"]),
                       gap: Props.number(node["gap"]) ?? 0) {
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

    @ViewBuilder
    private var stacked: some View {
        let main = Props.mainAxis(node["mainAxisAlignment"])
        let fill = Props.fillsMainAxis(node["mainAxisSize"])
        let ids = node.childIds
        let lead = fill && [.end, .center, .spaceAround, .spaceEvenly].contains(main)
        let trail = fill && [.start, .center, .spaceAround, .spaceEvenly].contains(main)
        let between = fill && [.spaceBetween, .spaceAround, .spaceEvenly].contains(main)
        let gap = Props.number(node["gap"]) ?? 0

        stack {
            if lead { Spacer(minLength: 0) }
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                if index > 0 {
                    if gap > 0 { gapView(gap) }
                    if between { Spacer(minLength: 0) }
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
            let alignment: HorizontalAlignment = cross == .start ? .leading : cross == .end ? .trailing : .center
            VStack(alignment: alignment, spacing: 0, content: content)
        } else {
            let alignment: VerticalAlignment =
                cross == .start ? .top : cross == .end ? .bottom
                : cross == .baseline ? .firstTextBaseline : .center
            HStack(alignment: alignment, spacing: 0, content: content)
        }
    }

    /// Under `stretch` a child spans the cross axis; one that does not fill
    /// it (a Text) sits at its start, as Flutter paints it in the tight box.
    @ViewBuilder
    private func child(_ id: String) -> some View {
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

@MainActor
struct CenterView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .environment(\.orcaTight, [])
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

@MainActor
struct PaddingView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .padding(Props.insets(node["padding"]) ?? EdgeInsets())
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

@MainActor
struct ScrollNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let horizontal = node["scrollDirection"]?.stringValue == "horizontal"
        ScrollView(horizontal ? .horizontal : .vertical) {
            ChildView(node: node, model: model)
                .padding(Props.insets(node["padding"]) ?? EdgeInsets())
        }
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
