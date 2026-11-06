#if canImport(SwiftUI)
import SwiftUI

/// Where a Positioned child sits in its Stack (Flutter `Positioned`).
struct PositionedSpec: Equatable {
    var top: CGFloat?
    var right: CGFloat?
    var bottom: CGFloat?
    var left: CGFloat?
    var width: CGFloat?
    var height: CGFloat?

    init(top: CGFloat? = nil, right: CGFloat? = nil, bottom: CGFloat? = nil, left: CGFloat? = nil,
         width: CGFloat? = nil, height: CGFloat? = nil) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
        self.width = width
        self.height = height
    }

    init(_ node: ResolvedNode) {
        self.init(top: Props.number(node["top"]), right: Props.number(node["right"]),
                  bottom: Props.number(node["bottom"]), left: Props.number(node["left"]),
                  width: Props.number(node["width"]), height: Props.number(node["height"]))
    }

    /// The width the Stack gives the child: both edges set it, else `width`.
    func width(in bounds: CGFloat) -> CGFloat? {
        if let left, let right { return max(bounds - left - right, 0) }
        return width
    }

    func height(in bounds: CGFloat) -> CGFloat? {
        if let top, let bottom { return max(bounds - top - bottom, 0) }
        return height
    }

    /// The child's leading edge: `left`, else from `right`, else by the
    /// Stack's alignment (Flutter `RenderStack.layoutPositionedChild`).
    func x(width: CGFloat, in bounds: CGFloat, alignment: CGFloat) -> CGFloat {
        if let left { return left }
        if let right { return bounds - right - width }
        return (bounds - width) * alignment
    }

    func y(height: CGFloat, in bounds: CGFloat, alignment: CGFloat) -> CGFloat {
        if let top { return top }
        if let bottom { return bounds - bottom - height }
        return (bounds - height) * alignment
    }
}

struct PositionedKey: LayoutValueKey {
    static let defaultValue: PositionedSpec? = nil
}

/// Flutter `RenderStack`. The Stack is as big as its largest ordinary child
/// (`fit: expand`: all the space offered); ordinary children are placed by
/// `alignment` (center by default, as the Flutter SDK parses it); Positioned
/// children by their edges, sized by both edges or their own width and
/// height. Later children draw on top.
struct StackLayout: Layout {
    var alignment: UnitPoint
    var expand: Bool

    private func finite(_ value: CGFloat?) -> CGFloat? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let offered = (finite(proposal.width), finite(proposal.height))
        if expand, let width = offered.0, let height = offered.1 {
            return CGSize(width: width, height: height)
        }
        var size = CGSize.zero
        var sized = false
        for child in subviews where child[PositionedKey.self] == nil {
            let s = child.sizeThatFits(proposal)
            size.width = max(size.width, s.width)
            size.height = max(size.height, s.height)
            sized = true
        }
        // Only Positioned children: the Stack takes what it is offered.
        return sized ? size : CGSize(width: offered.0 ?? 0, height: offered.1 ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for child in subviews {
            if let spec = child[PositionedKey.self] {
                let fixedWidth = spec.width(in: bounds.width)
                let fixedHeight = spec.height(in: bounds.height)
                let measured = child.sizeThatFits(ProposedViewSize(width: fixedWidth, height: fixedHeight))
                let width = fixedWidth ?? measured.width
                let height = fixedHeight ?? measured.height
                let point = CGPoint(
                    x: bounds.minX + spec.x(width: width, in: bounds.width, alignment: alignment.x),
                    y: bounds.minY + spec.y(height: height, in: bounds.height, alignment: alignment.y))
                child.place(at: point, anchor: .topLeading, proposal: ProposedViewSize(width: width, height: height))
            } else {
                let size = expand ? bounds.size : child.sizeThatFits(ProposedViewSize(bounds.size))
                let point = CGPoint(x: bounds.minX + (bounds.width - size.width) * alignment.x,
                                    y: bounds.minY + (bounds.height - size.height) * alignment.y)
                child.place(at: point, anchor: .topLeading, proposal: ProposedViewSize(size))
            }
        }
    }
}

/// Flutter `Stack`: fit, alignment, clipBehavior (no clip unless asked, as
/// the Flutter SDK parses it). `textDirection` is left to the system.
@MainActor
struct StackNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        StackLayout(alignment: Props.unitPoint(node["alignment"]), expand: node["fit"]?.stringValue == "expand") {
            ForEach(node.childIds, id: \.self) { id in
                NodeView(id: id, model: model).layoutValue(key: PositionedKey.self, value: positioned(id))
            }
        }
        .modifier(ClipIf(shape: Props.clips(node["clipBehavior"]) ? CornersShape(radii: .zero) : nil))
    }

    private func positioned(_ id: String) -> PositionedSpec? {
        guard model.renderer.node(id)?.type == "Positioned", let child = model.resolve(id) else { return nil }
        return PositionedSpec(child)
    }
}

/// Flutter `Positioned`: its child fills the width and height the Stack
/// gives it (both edges, or `width` / `height`), and takes its own size on
/// an axis left open. Outside a Stack it only draws its child.
@MainActor
struct PositionedView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let spec = PositionedSpec(node)
        let fillsWidth = spec.width != nil || (spec.left != nil && spec.right != nil)
        let fillsHeight = spec.height != nil || (spec.top != nil && spec.bottom != nil)
        ChildView(node: node, model: model)
            .frame(maxWidth: fillsWidth ? .infinity : nil, maxHeight: fillsHeight ? .infinity : nil,
                   alignment: .topLeading)
    }
}

/// Flutter `ClipRRect`: the child clipped to rounded corners. `borderRadius`
/// is a number or `{topLeft, topRight, bottomLeft, bottomRight}`; the
/// Flutter SDK reads only the number form.
@MainActor
struct ClipRRectView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .clipShape(CornersShape(radii: Props.radii(node["borderRadius"]) ?? .zero))
    }
}

/// Flutter `GestureDetector` as the SDK builds it: only the gestures the node
/// has actions for are attached (onTap, onDoubleTap, onLongPress), and then
/// the whole box takes touches, not just its drawn pixels
/// (`HitTestBehavior.opaque`). With none, it only draws its child.
@MainActor
struct GestureNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let tap = node.actions["onTap"] != nil
        let doubleTap = node.actions["onDoubleTap"] != nil
        let longPress = node.actions["onLongPress"] != nil
        if tap || doubleTap || longPress {
            ChildView(node: node, model: model)
                .contentShape(Rectangle())
                // A double tap is declared first, so a single tap waits for it.
                .gesture(TapGesture(count: 2).onEnded { model.fire("onDoubleTap", on: node) },
                         including: doubleTap ? .all : .subviews)
                .gesture(TapGesture().onEnded { model.fire("onTap", on: node) },
                         including: tap ? .all : .subviews)
                .simultaneousGesture(LongPressGesture().onEnded { _ in model.fire("onLongPress", on: node) },
                                     including: longPress ? .all : .subviews)
                .accessibilityAddTraits(tap ? .isButton : [])
        } else {
            ChildView(node: node, model: model)
        }
    }
}
#endif
