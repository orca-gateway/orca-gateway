#if canImport(SwiftUI)
import SwiftUI

// MARK: - Opacity

/// Flutter `Opacity` (layout_builders.dart:288-293, `opacity` default 1):
/// the child drawn at that alpha as one layer (`compositingGroup`, so
/// overlapping children do not show through each other). RenderOpacity has
/// no hitTest override, so the child takes taps at any opacity, 0 included
/// (`HitTestableOpacity`).
@MainActor
struct OpacityView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .modifier(HitTestableOpacity(opacity: Props.number(node["opacity"]) ?? 1))
    }
}

/// The content drawn at `opacity` as one layer, still taking taps however
/// faint it is, as a Flutter child under an Opacity does. Below an alpha of
/// 0.01 SwiftUI takes no hits on a view and UIKit's `hitTest` skips it (a
/// text field included), so an opacity under `floor` is drawn at `floor`
/// with every pixel multiplied by clear: nothing shows (for a UIKit view
/// too, which SwiftUI multiplies with a layer filter) and the hits stay.
/// Such a faint opacity draws nothing rather than at most 5/255. The
/// modifiers are the same at every opacity, so the content keeps its
/// identity and state as the opacity changes.
struct HitTestableOpacity: ViewModifier {
    static let floor = 0.02
    let opacity: Double

    func body(content: Content) -> some View {
        let opacity = min(max(opacity, 0), 1)
        content
            .compositingGroup()
            .colorMultiply(opacity < Self.floor ? .clear : .white)
            .opacity(max(opacity, Self.floor))
    }
}

// MARK: - RotatedBox

/// Flutter `RotatedBox` (layout_builders.dart:523-528, `quarterTurns`
/// default 0): RenderRotatedBox (rendering/rotated_box.dart) lays the child
/// out with the axes swapped on odd turns, takes the child's size swapped
/// on odd turns, and draws it (and hit-tests it) turned clockwise by
/// `quarterTurns % 4` quarter turns about the centre; with no child it is
/// the smallest size the parent allows. The forced and the unbounded axes
/// (`orcaTight`, `orcaUnbounded`) swap with the proposal, so the child is
/// kept within Flutter's flipped constraints.
@MainActor
struct RotatedBoxView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight
    @Environment(\.orcaUnbounded) private var unbounded

    var body: some View {
        // Dart's `%` is never negative: -1 is 3 quarter turns.
        let turns = ((node["quarterTurns"]?.intValue ?? 0) % 4 + 4) % 4
        let odd = turns % 2 == 1
        RotatedLayout(odd: odd, tight: tight) {
            if let first = node.childIds.first {
                NodeView(id: first, model: model)
                    .environment(\.orcaTight, odd ? tight.swapped : tight)
                    .environment(\.orcaUnbounded, odd ? unbounded.swapped : unbounded)
                    .rotationEffect(.degrees(Double(turns) * 90))
            }
        }
    }
}

/// RenderRotatedBox `performLayout`: the child measured with the proposal
/// swapped on odd turns and its size swapped back; it is placed centred in
/// the box at its own size, so a rotation about its centre fills the box.
struct RotatedLayout: Layout {
    var odd: Bool
    var tight: TightAxes

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return BoxLimits(proposal, tight: tight).constrain(.zero) }
        let size = child.sizeThatFits(flip(proposal))
        return odd ? CGSize(width: size.height, height: size.width) : size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: flip(proposal))
    }

    private func flip(_ proposal: ProposedViewSize) -> ProposedViewSize {
        odd ? ProposedViewSize(width: proposal.height, height: proposal.width) : proposal
    }
}

extension TightAxes {
    /// The same axes with width and height swapped.
    var swapped: TightAxes {
        [contains(.horizontal) ? .vertical : [], contains(.vertical) ? .horizontal : []]
    }
}

// MARK: - ClipRect and ClipOval

/// Flutter `ClipRect` (layout_builders.dart:426-428): the child cut to the
/// box (Clip.hardEdge). A Flutter box is never hit outside its own size,
/// so the child's overflow takes no taps; the content shape makes that so
/// here, where a clip alone cuts only the drawing.
@MainActor
struct ClipRectView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .clipShape(Rectangle())
            .contentShape(Rectangle())
    }
}

/// Flutter `ClipOval` (layout_builders.dart:430-432): the child cut to the
/// ellipse inscribed in its box (Clip.antiAlias), which is also the only
/// place it takes taps (RenderClipOval `hitTest`, proxy_box.dart:1924-1938).
@MainActor
struct ClipOvalView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .clipShape(Ellipse())
            .contentShape(Ellipse())
    }
}

// MARK: - DecoratedBox

/// Flutter `DecoratedBox` (layout_builders.dart:530-541): the decoration
/// (`parseBoxDecoration`; absent or invalid draws nothing) behind the
/// child, or over it when `position` is "foreground", at the child's size.
/// RenderDecoratedBox is a proxy box: unlike a Container (ContainerView),
/// the border does not inset the child.
///
/// Taps: the child is hit-tested first, then the box itself, whose
/// `hitTestSelf` is BoxDecoration.hitTest (proxy_box.dart:2465,
/// box_decoration.dart:375-392): the whole box, or the rounded box when
/// `borderRadius` is set (the SDK never sets a circle shape), filled or
/// not, empty decoration included, in either position. The drawn
/// decoration takes no taps (its shadows reach outside the box); the
/// shape's `hitFill` behind everything takes them. One chain of modifiers
/// for both positions, so the child keeps its state when `position`
/// changes.
@MainActor
struct DecoratedBoxView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let decoration = BoxDecorationProps(node["decoration"])
        let foreground = node["position"]?.stringValue == "foreground"
        ChildView(node: node, model: model)
            .background {
                if !foreground, let decoration {
                    DecorationBackground(decoration: decoration).allowsHitTesting(false)
                }
            }
            .overlay {
                if foreground, let decoration {
                    DecorationBackground(decoration: decoration).allowsHitTesting(false)
                }
            }
            .background { (decoration?.shape ?? CornersShape(radii: .zero)).hitFill() }
    }
}

extension Shape {
    /// The shape filled so that it takes taps but shows nothing: a colour
    /// at alpha 0.001 (0 in 8 bits). SwiftUI and UIKit test a view's own
    /// opacity, not its pixels: a view whose opacity is under 0.01 takes no
    /// hits (SwiftUI drops it, UIKit's `hitTest` skips it), and a clear
    /// fill or a content shape alone lets UIKit views behind take them,
    /// while a filled shape at full view opacity takes them whatever its
    /// colour's alpha.
    func hitFill() -> some View {
        fill(Color.black.opacity(0.001))
    }
}

// MARK: - ColorFiltered

/// Flutter `ColorFiltered` (layout_builders.dart:543-550):
/// `ColorFilter.mode(color, blendMode)`, the colour (default transparent)
/// blended as the source with each pixel of the child (the destination)
/// by `OrcaBlendMode.of(blendMode)` (default srcATop, which with the
/// transparent default leaves the child as it is). The child and the
/// colour, at the child's size, are composited together on their own
/// (`compositingGroup`), then over the page. SwiftUI's blend modes give
/// srcOver (normal), srcATop (sourceAtop), dstOver (destinationOver) and
/// the 15 separable and non-separable modes as Flutter does; the three it
/// lacks are built so the result is Flutter's formula:
/// - srcIn `S·Da`: the opaque colour over the child by sourceAtop (the
///   colour where the child is, at the child's alpha), at the colour's
///   alpha.
/// - dstIn `D·Sa`: the child at the colour's alpha.
/// - dstATop `D·Sa + S·(1−Da)`: srcATop with the roles swapped, the child
///   by sourceAtop over the colour.
/// The colour takes no taps; the child takes them as in Flutter, where the
/// filter is a proxy box, even where it is filtered out of sight
/// (`HitTestableOpacity`).
@MainActor
struct ColorFilteredView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let color = FilterColor(node["color"])
        let child = ChildView(node: node, model: model)
        switch OrcaBlendMode.of(node["blendMode"]?.stringValue) {
        case .srcIn:
            child
                .overlay { color.opaque.blendMode(.sourceAtop).allowsHitTesting(false) }
                .modifier(HitTestableOpacity(opacity: color.alpha))
        case .dstIn:
            child
                .modifier(HitTestableOpacity(opacity: color.alpha))
        case .dstATop:
            child
                .compositingGroup()
                .blendMode(.sourceAtop)
                .background { color.color.allowsHitTesting(false) }
                .compositingGroup()
        case let mode:
            child
                .overlay { color.color.blendMode(Self.blendMode(mode)).allowsHitTesting(false) }
                .compositingGroup()
        }
    }

    /// SwiftUI's blend mode for a Flutter mode it has (srcIn, dstIn and
    /// dstATop are built in `body`).
    static func blendMode(_ mode: OrcaBlendMode) -> BlendMode {
        switch mode {
        case .srcOver, .srcIn, .dstIn, .dstATop: return .normal
        case .srcATop: return .sourceAtop
        case .dstOver: return .destinationOver
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .hardLight: return .hardLight
        case .softLight: return .softLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }
}

/// A ColorFiltered's colour (`Props.color`; missing or invalid is
/// transparent, Flutter's `Color(0x00000000)`), and the same colour opaque
/// with its alpha apart, for the modes built from opacity.
struct FilterColor {
    var color: Color
    var opaque: Color
    var alpha: Double

    init(_ value: JSONValue?) {
        guard let color = Props.color(value), let text = value?.stringValue else {
            (self.color, opaque, alpha) = (.clear, .black, 0)
            return
        }
        let hex = text.dropFirst()
        self.color = color
        opaque = Props.color(hex: "#" + hex.prefix(6))
        alpha = hex.count == 8 ? Double(UInt8(hex.suffix(2), radix: 16) ?? 255) / 255 : 1
    }
}
#endif
