#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Flutter `Icon`: a Material name drawn as the nearest SF Symbol
/// (`IconNames`), in a `size` by `size` box (default 24), in `color` or the
/// surrounding foreground colour. A `src` draws that image instead, tinted
/// like Flutter's `ImageIcon`.
@MainActor
struct IconNodeView: View {
    let node: ResolvedNode

    var body: some View {
        let size = Props.number(node["size"]) ?? 24
        Group {
            if let src = node["src"]?.stringValue, let url = URL(string: src) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.renderingMode(.template).resizable().scaledToFit()
                    } else {
                        Color.clear
                    }
                }
            } else {
                let name = node["name"]?.stringValue ?? node["icon"]?.stringValue
                // A Material glyph fills about 20 of its 24 points.
                Image(systemName: IconNames.symbol(for: name))
                    .font(.system(size: size * 0.83))
                    .rotationEffect(.degrees(IconNames.isRotated(name) ? 90 : 0))
            }
        }
        .frame(width: size, height: size)
        .modifier(OptionalForeground(color: Props.color(node["color"])))
        .accessibilityHidden(true)
    }
}

/// Flutter `Image.network`: `src` loaded from the network (or, for a name
/// without a scheme, from the app's asset catalog), fitted by `fit`
/// (Flutter's default here is `cover`), in a `width` by `height` box placed
/// by `alignment`. `color` tints it, as Flutter's default `srcIn` blend
/// does; `alt` is its accessibility label. A failed load draws "!" in the
/// box, as the Flutter error builder. `repeat` is not drawn: SwiftUI has no
/// tiled image short of drawing it by hand.
@MainActor
struct ImageNodeView: View {
    let node: ResolvedNode

    var body: some View {
        let src = Props.text(node["src"])
        let width = Props.number(node["width"])
        let height = Props.number(node["height"])
        content(src)
            .frame(width: width, height: height, alignment: Props.alignment(node["alignment"]))
            .clipped()
            .modifier(OptionalForeground(color: Props.color(node["color"])))
            .accessibilityElement()
            .accessibilityLabel(node["alt"]?.stringValue ?? "")
            .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private func content(_ src: String) -> some View {
        if let url = URL(string: src), ["http", "https"].contains(url.scheme?.lowercased()) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): fitted(image)
                case .failure: failed
                default: Color.clear
                }
            }
        } else if let image = Self.asset(src) {
            fitted(image)
        } else {
            failed
        }
    }

    private static func asset(_ name: String) -> Image? {
        guard !name.isEmpty else { return nil }
        #if canImport(UIKit)
        return UIImage(named: name) != nil ? Image(name) : nil
        #else
        return Image(name)
        #endif
    }

    private var failed: some View {
        Text("!").frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func fitted(_ image: Image) -> some View {
        let tinted = Props.color(node["color"]) == nil ? image : image.renderingMode(.template)
        switch node["fit"]?.stringValue ?? "cover" {
        case "fill":
            tinted.resizable()
        case "contain", "fitWidth", "fitHeight", "scaleDown":
            tinted.resizable().aspectRatio(contentMode: .fit)
        case "none":
            tinted
        default:
            tinted.resizable().aspectRatio(contentMode: .fill)
        }
    }
}

/// Sets the foreground colour only when there is one, so the view otherwise
/// inherits it (an icon in a button takes the button's colour).
struct OptionalForeground: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content.foregroundColor(color)
        } else {
            content
        }
    }
}
#endif
