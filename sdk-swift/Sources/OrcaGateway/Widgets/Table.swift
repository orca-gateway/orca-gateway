#if canImport(SwiftUI)
import SwiftUI

/// Flutter's `Table` as the Flutter SDK's builder makes it
/// (layout_builders.dart:646-666): each child its own one-cell row of a
/// single `FlexColumnWidth(1)` column, top-aligned (TableLayout).
/// `columnWidths` and `defaultColumnWidth` are never read, as Flutter's
/// builder does not. `border` sent is `TableBorder.all(color ?? black,
/// width ?? 1)`, its style unread, painted over the cells from the rows'
/// placed edges (TableBorderCanvas); it changes no layout. The same table
/// as Kotlin's Table.kt.
@MainActor
struct TableView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight
    @Environment(\.orcaUnbounded) private var unbounded
    @Environment(\.orcaMinimum) private var minimum

    var body: some View {
        if let border {
            rows(edges: true)
                .overlayPreferenceValue(TableRowsKey.self) { anchors in
                    GeometryReader { proxy in
                        TableBorderCanvas(border: border, rows: anchors.map { proxy[$0] })
                    }
                    .allowsHitTesting(false)
                }
                // A table inside a cell keeps its rows to itself.
                .transformPreference(TableRowsKey.self) { $0 = [] }
        } else {
            rows(edges: false)
        }
    }

    /// Flutter `ctx.prop<Map>('border')`: colour and width as a
    /// BoxDecoration border parses them.
    private var border: BoxDecorationProps.Border? {
        guard case .object(let b)? = node["border"] else { return nil }
        return BoxDecorationProps.Border(color: Props.color(b["color"]) ?? .black,
                                         width: Props.number(b["width"]) ?? 1)
    }

    /// The rows, each its full width and its own height (Flutter's cell is
    /// `tightFor(width)`: forced across, unbounded down); with `edges`, each
    /// row's placed bounds go up for the border.
    private func rows(edges: Bool) -> some View {
        TableLayout(tight: tight, unbounded: unbounded, minimum: minimum.size(for: node.id)) {
            ForEach(node.childIds, id: \.self) { id in
                if edges {
                    NodeView(id: id, model: model).anchorPreference(key: TableRowsKey.self, value: .bounds) { [$0] }
                } else {
                    NodeView(id: id, model: model)
                }
            }
        }
        .environment(\.orcaTight, .horizontal)
        .environment(\.orcaUnbounded, .vertical)
    }
}

/// Flutter `RenderTable.performLayout` for one flex column: the column is
/// the maximum width, or the minimum where there is no maximum (a
/// horizontal scroll, a Row's main axis: 0 there, FlexColumnWidth having no
/// intrinsic width, rendering/table.dart `_computeColumnWidths`). Each
/// child is offered exactly that width and no height, the rows stacked from
/// the top; the table is as high as they are, kept within its limits. No
/// children is the minimum size. The limits are BoxLimits from the offer,
/// the forced axes, the unbounded ones and a ConstrainedBox's min, as
/// TightForLayout reads them.
struct TableLayout: Layout {
    var tight: TightAxes
    var unbounded: TightAxes
    var minimum: CGSize

    private func limits(_ proposal: ProposedViewSize) -> BoxLimits {
        var outer = BoxLimits(proposal, tight: tight)
        if unbounded.contains(.horizontal), !tight.contains(.horizontal) { outer.maxWidth = .infinity }
        if unbounded.contains(.vertical), !tight.contains(.vertical) { outer.maxHeight = .infinity }
        return BoxLimits(minWidth: minimum.width, minHeight: minimum.height).enforced(in: outer)
    }

    private func width(_ limits: BoxLimits) -> CGFloat {
        limits.maxWidth.isFinite ? limits.maxWidth : limits.minWidth
    }

    private func heights(_ width: CGFloat, _ subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limits = limits(proposal)
        guard !subviews.isEmpty else { return limits.constrain(.zero) }
        let width = width(limits)
        return limits.constrain(CGSize(width: width, height: heights(width, subviews).reduce(0, +)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = width(limits(proposal))
        var top = bounds.minY
        for (subview, height) in zip(subviews, heights(width, subviews)) {
            subview.place(at: CGPoint(x: bounds.minX, y: top), anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: nil))
            top += height
        }
    }
}

/// Each row's placed bounds, in order (TableView).
struct TableRowsKey: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

/// Flutter's `TableBorder.paint` for one column over `rows`: the lines
/// between rows first, stroked the border's width centred on each boundary
/// across the table, then the outer lines filling that width inside the
/// rows' rect (Flutter's `paintBorder`). At width 0 every line is a
/// hairline, one device pixel (Skia's stroke width 0; Quartz draws nothing
/// at 0), the outer ones on the edges. The rect is the table's width and
/// the rows' height.
struct TableBorderCanvas: View {
    let border: BoxDecorationProps.Border
    let rows: [CGRect]
    @Environment(\.displayScale) private var scale

    var body: some View {
        Canvas { context, size in
            guard let last = rows.last else { return }
            let rect = CGRect(x: 0, y: 0, width: size.width, height: last.maxY)
            let shading = GraphicsContext.Shading.color(border.color)
            let stroke = border.width > 0 ? border.width : 1 / max(scale, 1)
            for row in rows.dropFirst() {
                context.stroke(Path { line in
                    line.move(to: CGPoint(x: rect.minX, y: row.minY))
                    line.addLine(to: CGPoint(x: rect.maxX, y: row.minY))
                }, with: shading, lineWidth: stroke)
            }
            guard border.width > 0 else {
                context.stroke(Path(rect), with: shading, lineWidth: stroke)
                return
            }
            var ring = Path(rect)
            let inner = rect.insetBy(dx: border.width, dy: border.width)
            if !inner.isEmpty { ring.addRect(inner) }
            context.fill(ring, with: shading, style: FillStyle(eoFill: true))
        }
    }
}
#endif
