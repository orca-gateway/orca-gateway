#if canImport(SwiftUI)
import SwiftUI

/// The system material that stands in for Flutter's backdrop blur. Flutter
/// blurs by a Gaussian sigma (`ImageFilter.blur`, 10 by default); iOS 16 has
/// no backdrop blur by sigma, only materials of fixed strength, so the larger
/// of `blurX` and `blurY` picks one of five: ≤ 3 ultraThin, ≤ 8 thin, ≤ 16
/// regular, ≤ 24 thick, else ultraThick (default 10, regular).
enum BackdropStrength: Equatable {
    case ultraThin, thin, regular, thick, ultraThick

    init(blurX: CGFloat?, blurY: CGFloat?) {
        switch max(blurX ?? 10, blurY ?? 10) {
        case ...3: self = .ultraThin
        case ...8: self = .thin
        case ...16: self = .regular
        case ...24: self = .thick
        default: self = .ultraThick
        }
    }

    init(_ node: ResolvedNode) {
        self.init(blurX: Props.number(node["blurX"]), blurY: Props.number(node["blurY"]))
    }

    var material: Material {
        switch self {
        case .ultraThin: return .ultraThinMaterial
        case .thin: return .thinMaterial
        case .regular: return .regularMaterial
        case .thick: return .thickMaterial
        case .ultraThick: return .ultraThickMaterial
        }
    }
}

/// Flutter `BackdropFilter` (layout_builders.dart:345-352): a proxy box, its
/// child's size, the child drawn sharp on top of what is behind it blurred.
/// Here the blur is a material (`BackdropStrength`) behind the child, cut to
/// the child's box: Flutter's blur reaches the nearest ancestor clip or the
/// whole screen (basic.dart:495-501), a documented difference (D9). The
/// material takes no taps: RenderBackdropFilter has no hitTestSelf, so where
/// the child takes none the tap goes on to what is behind. With no child it
/// is nothing (Flutter's `SizedBox.shrink`).
@MainActor
struct BackdropFilterView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        if !node.childIds.isEmpty {
            ChildView(node: node, model: model)
                .background { Rectangle().fill(BackdropStrength(node).material).allowsHitTesting(false) }
        }
    }
}

/// The Flutter SDK's `BlurView` (layout_builders.dart:354-370):
/// `ClipRRect(circular(borderRadius ?? 0))` > `BackdropFilter` >
/// `Container(color: overlayColor ?? transparent)` > child. Inside the
/// rounded clip, bottom to top: the material, the overlay colour at the
/// child's size, the child; all of it is its child's size and is cut to the
/// radius for drawing. It takes every tap in its whole box, the overlay
/// transparent or not and the corners outside the radius included: a
/// Container with a colour is a ColoredBox, opaque to hits (basic.dart
/// :8392-8394), and RenderClipRRect cuts hits only with a custom clipper
/// (proxy_box.dart:1736-1746), which the SDK does not pass. The material, a
/// UIKit view as big as the box, takes no taps; they are taken by a
/// rectangle filled with an invisible colour, outside the clip (a clear
/// fill, like a content shape alone, lets UIKit views behind take them).
/// With no child it is nothing.
@MainActor
struct BlurView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        if !node.childIds.isEmpty {
            let shape = RoundedRectangle(cornerRadius: max(Props.number(node["borderRadius"]) ?? 0, 0),
                                         style: .circular)
            ChildView(node: node, model: model)
                .background { Props.color(node["overlayColor"]) ?? .clear }
                .background { Rectangle().fill(BackdropStrength(node).material).allowsHitTesting(false) }
                .clipShape(shape)
                .background { Rectangle().fill(Color.black.opacity(0.001)) } // invisible, but takes hits (see above)
        }
    }
}
#endif
