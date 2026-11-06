#if canImport(SwiftUI)
import SwiftUI

/// A child's `flex`: 0 for an ordinary child, the factor for Expanded and
/// Spacer.
struct FlexFactor: LayoutValueKey {
    static let defaultValue = 0
}

private struct FlexAxisKey: EnvironmentKey {
    static let defaultValue: Axis? = nil
}

extension EnvironmentValues {
    /// The main axis of the Row or Column a node sits in, for Expanded.
    var orcaFlexAxis: Axis? {
        get { self[FlexAxisKey.self] }
        set { self[FlexAxisKey.self] = newValue }
    }
}

/// Flutter's `RenderFlex` for a Row or Column with Expanded or Spacer
/// children. HStack and VStack cannot split space by weight, so this layout
/// does what Flutter does:
///
/// 1. Each ordinary child is measured with no limit on the main axis and the
///    row's limit on the cross axis.
/// 2. The main-axis space left after them (and the gaps) is shared by the
///    flex children in proportion to `flex`; each gets exactly its share.
/// 3. The layout is as long as it is offered when `mainAxisSize` is `max`,
///    and as wide as its widest child on the cross axis (all of it under
///    `stretch`). Children are placed in order, aligned on the cross axis.
///
/// With flex children there is no space left over, so `mainAxisAlignment`
/// changes nothing, as in Flutter. When the main axis is unbounded (a Column
/// in a scroll view, where Flutter throws), flex children take their own
/// size.
struct FlexLayout: Layout {
    var axis: Axis
    var cross: Props.CrossAxis
    var fill: Bool
    var gap: CGFloat

    struct Measured {
        var mains: [CGFloat]
        var crosses: [CGFloat]
        var total: CGFloat
    }

    private func main(_ size: CGSize) -> CGFloat { axis == .horizontal ? size.width : size.height }
    private func crossOf(_ size: CGSize) -> CGFloat { axis == .horizontal ? size.height : size.width }
    private func proposal(main: CGFloat?, cross: CGFloat?) -> ProposedViewSize {
        axis == .horizontal ? ProposedViewSize(width: main, height: cross)
            : ProposedViewSize(width: cross, height: main)
    }

    private func finite(_ value: CGFloat?) -> CGFloat? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    func measure(_ offered: ProposedViewSize, _ subviews: Subviews) -> Measured {
        let availableMain = finite(axis == .horizontal ? offered.width : offered.height)
        let availableCross = finite(axis == .horizontal ? offered.height : offered.width)
        var mains = [CGFloat](repeating: 0, count: subviews.count)
        var crosses = mains
        var used = gap * CGFloat(max(subviews.count - 1, 0))
        var totalFlex = 0
        for (i, child) in subviews.enumerated() {
            let flex = child[FlexFactor.self]
            if flex > 0 {
                totalFlex += flex
                continue
            }
            let size = child.sizeThatFits(proposal(main: nil, cross: availableCross))
            mains[i] = main(size)
            crosses[i] = crossOf(size)
            used += mains[i]
        }
        let free = availableMain.map { max(0, $0 - used) }
        for (i, child) in subviews.enumerated() where child[FlexFactor.self] > 0 {
            let share = free.map { $0 * CGFloat(child[FlexFactor.self]) / CGFloat(totalFlex) }
            let size = child.sizeThatFits(proposal(main: share, cross: availableCross))
            mains[i] = share ?? main(size)
            crosses[i] = crossOf(size)
        }
        return Measured(mains: mains, crosses: crosses,
                        total: mains.reduce(0, +) + gap * CGFloat(max(subviews.count - 1, 0)))
    }

    func sizeThatFits(proposal offered: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let measured = measure(offered, subviews)
        let availableMain = finite(axis == .horizontal ? offered.width : offered.height)
        let availableCross = finite(axis == .horizontal ? offered.height : offered.width)
        let mainSize = fill ? (availableMain ?? measured.total) : measured.total
        let widest = measured.crosses.max() ?? 0
        let crossSize = cross == .stretch ? (availableCross ?? widest) : widest
        return axis == .horizontal ? CGSize(width: mainSize, height: crossSize)
            : CGSize(width: crossSize, height: mainSize)
    }

    func placeSubviews(in bounds: CGRect, proposal offered: ProposedViewSize, subviews: Subviews,
                       cache: inout ()) {
        let measured = measure(offered, subviews)
        let boundsCross = axis == .horizontal ? bounds.height : bounds.width
        var position = axis == .horizontal ? bounds.minX : bounds.minY
        for (i, child) in subviews.enumerated() {
            let childCross = cross == .stretch ? boundsCross : min(measured.crosses[i], boundsCross)
            let offset: CGFloat
            switch cross {
            case .end: offset = boundsCross - childCross
            case .center: offset = (boundsCross - childCross) / 2
            default: offset = 0
            }
            let point = axis == .horizontal
                ? CGPoint(x: position, y: bounds.minY + offset)
                : CGPoint(x: bounds.minX + offset, y: position)
            child.place(at: point, anchor: .topLeading,
                        proposal: proposal(main: measured.mains[i], cross: childCross))
            position += measured.mains[i] + gap
        }
    }
}

/// Flutter `Expanded`: its child fills the share of the main axis the flex
/// layout gives it, starting at the leading or top edge.
@MainActor
struct ExpandedView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaFlexAxis) private var axis

    var body: some View {
        ChildView(node: node, model: model)
            .frame(maxWidth: axis == .horizontal ? .infinity : nil,
                   maxHeight: axis == .vertical ? .infinity : nil,
                   alignment: .topLeading)
    }
}

/// Flutter `Spacer`: empty, and as long as the share the flex layout gives
/// it. It has no size of its own, so it never widens a Row's cross axis.
struct SpacerNodeView: View {
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
    }
}
#endif
