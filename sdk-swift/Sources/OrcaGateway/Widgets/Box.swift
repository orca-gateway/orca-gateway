#if canImport(SwiftUI)
import SwiftUI

/// The four corner radii of a box, Flutter `BorderRadius`.
struct CornerRadii: Equatable {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0

    init(topLeft: CGFloat = 0, topRight: CGFloat = 0, bottomLeft: CGFloat = 0, bottomRight: CGFloat = 0) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    init(all radius: CGFloat) {
        self.init(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
    }

    static let zero = CornerRadii()
}

/// A rectangle with its own radius per corner. `UnevenRoundedRectangle` is
/// iOS 17; the package supports iOS 16. Radii are capped at half the shorter
/// side, as Flutter's RRect does.
struct CornersShape: InsettableShape {
    var radii: CornerRadii
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> CornersShape {
        var shape = self
        shape.inset += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        guard r.width > 0, r.height > 0 else { return Path() }
        let cap = min(r.width, r.height) / 2
        func c(_ value: CGFloat) -> CGFloat { min(max(value - inset, 0), cap) }
        let tl = c(radii.topLeft), tr = c(radii.topRight)
        let br = c(radii.bottomRight), bl = c(radii.bottomLeft)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + tl, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - tr, y: r.minY + tr), radius: tr,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        p.addArc(center: CGPoint(x: r.maxX - br, y: r.maxY - br), radius: br,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + bl, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + bl, y: r.maxY - bl), radius: bl,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
        p.addArc(center: CGPoint(x: r.minX + tl, y: r.minY + tl), radius: tl,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Flutter `BoxDecoration` (`parseBoxDecoration`): color, borderRadius,
/// border, boxShadow, gradient.
struct BoxDecorationProps {
    struct Border {
        var color: Color
        var width: CGFloat
    }

    struct Shadow {
        var color: Color
        var blurRadius: CGFloat
        var spreadRadius: CGFloat
        var offset: CGSize
    }

    struct GradientProps {
        var radial: Bool
        var gradient: Gradient
        var begin: UnitPoint
        var end: UnitPoint
    }

    var color: Color?
    var radii: CornerRadii?
    var border: Border?
    var shadows: [Shadow] = []
    var gradient: GradientProps?

    init?(_ value: JSONValue?) {
        guard case .object(let d)? = value else { return nil }
        color = Props.color(d["color"])
        radii = Props.radii(d["borderRadius"])
        if case .object(let b)? = d["border"], b["style"]?.stringValue != "none" {
            border = Border(color: Props.color(b["color"]) ?? .black,
                            width: Props.number(b["width"]) ?? 1)
        }
        if case .array(let list)? = d["boxShadow"] {
            shadows = list.compactMap { item in
                guard case .object(let s) = item else { return nil }
                let offset = s["offset"]
                return Shadow(
                    color: Props.color(s["color"]) ?? Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.2),
                    blurRadius: Props.number(s["blurRadius"]) ?? 0,
                    spreadRadius: Props.number(s["spreadRadius"]) ?? 0,
                    offset: CGSize(width: Props.number(offset?["dx"]) ?? 0,
                                   height: Props.number(offset?["dy"]) ?? 0))
            }
        }
        if case .object(let g)? = d["gradient"], case .array(let rawColors)? = g["colors"] {
            let colors = rawColors.map { Props.color($0) ?? .clear }
            let stops = g["stops"]?.arrayValue?.compactMap { $0.doubleValue }
            let built: Gradient
            if let stops, stops.count == colors.count {
                built = Gradient(stops: zip(colors, stops).map { Gradient.Stop(color: $0, location: CGFloat($1)) })
            } else {
                built = Gradient(colors: colors)
            }
            // As the Flutter SDK: `begin` defaults to center, and an `end` of
            // center (or none) becomes centerRight.
            let end = Props.unitPoint(g["end"])
            gradient = GradientProps(
                radial: g["type"]?.stringValue == "radial", gradient: built,
                begin: Props.unitPoint(g["begin"]), end: end == .center ? .trailing : end)
        }
    }

    var shape: CornersShape { CornersShape(radii: radii ?? .zero) }
}

/// What a BoxDecoration paints behind a box: shadows, the fill (colour or
/// gradient), then the border inside the edge, as Flutter paints them.
struct DecorationBackground: View {
    let decoration: BoxDecorationProps

    var body: some View {
        let shape = decoration.shape
        ZStack {
            ForEach(Array(decoration.shadows.enumerated()), id: \.offset) { _, shadow in
                shape.inset(by: -shadow.spreadRadius)
                    .fill(shadow.color)
                    .offset(shadow.offset)
                    // Flutter's convertRadiusToSigma.
                    .blur(radius: shadow.blurRadius > 0 ? shadow.blurRadius * 0.57735 + 0.5 : 0)
            }
            fill(shape)
            if let border = decoration.border {
                shape.strokeBorder(border.color, lineWidth: border.width)
            }
        }
    }

    @ViewBuilder
    private func fill(_ shape: CornersShape) -> some View {
        if let gradient = decoration.gradient {
            if gradient.radial {
                GeometryReader { geometry in
                    shape.fill(RadialGradient(
                        gradient: gradient.gradient, center: .center, startRadius: 0,
                        endRadius: min(geometry.size.width, geometry.size.height) / 2))
                }
            } else {
                shape.fill(LinearGradient(gradient: gradient.gradient,
                                          startPoint: gradient.begin, endPoint: gradient.end))
            }
        } else {
            shape.fill(decoration.color ?? .clear)
        }
    }
}

/// Flutter `Container`: margin, then the decoration (or `color` when there
/// is no decoration) behind the padding, a fixed `width` and `height` that
/// include the padding, and `alignment`, which makes the box fill its parent
/// and places the child in it. With no child the box takes the space it is
/// offered. `clipBehavior` other than `none` clips to the decoration's shape.
///
/// Where the parent forces its size (TightAxes: a stretched Column, an
/// Expanded), the box fills that axis, decoration included, as Flutter's
/// tight constraints make it.
@MainActor
struct ContainerView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        let decoration = BoxDecorationProps(node["decoration"])
        let width = Props.number(node["width"])
        let height = Props.number(node["height"])
        let shape = decoration?.shape ?? CornersShape(radii: .zero)
        let fillsWidth = width == nil && tight.contains(.horizontal)
        let fillsHeight = height == nil && tight.contains(.vertical)

        aligned
            .padding(Props.insets(node["padding"]) ?? EdgeInsets())
            .frame(maxWidth: fillsWidth ? .infinity : nil, maxHeight: fillsHeight ? .infinity : nil,
                   alignment: .topLeading)
            .frame(width: width, height: height, alignment: .topLeading)
            .background {
                if let decoration {
                    DecorationBackground(decoration: decoration)
                } else if let color = Props.color(node["color"]) {
                    color
                }
            }
            .modifier(ClipIf(shape: Props.clips(node["clipBehavior"]) ? shape : nil))
            .padding(Props.insets(node["margin"]) ?? EdgeInsets())
    }

    @ViewBuilder
    private var aligned: some View {
        if node.childIds.isEmpty {
            Color.clear
        } else if node["alignment"] != nil {
            ChildView(node: node, model: model)
                .environment(\.orcaTight, [])
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Props.alignment(node["alignment"]))
        } else {
            ChildView(node: node, model: model)
                .modifier(AddTight(axes: [Props.number(node["width"]) != nil ? .horizontal : [],
                                          Props.number(node["height"]) != nil ? .vertical : []]))
        }
    }
}
/// Clips to the shape when there is one.
struct ClipIf: ViewModifier {
    let shape: CornersShape?

    func body(content: Content) -> some View {
        if let shape {
            content.clipShape(shape)
        } else {
            content
        }
    }
}
#endif
