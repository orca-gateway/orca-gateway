#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Flutter `Icon` as the Flutter builder (`_buildIcon`) makes it: a Material
/// name drawn as the nearest SF Symbol (`IconNames`), in a `size` by `size`
/// box (default 24), in `color` or the surrounding foreground colour.
///
/// A `src` takes precedence, as Flutter's `ImageIcon` (the builder's
/// ImageIcon node draws here too; FW widgets/image_icon.dart:91-119): the
/// image at one point per image pixel (a network image at scale 1), fitted
/// `scaleDown` into the square (shrunk to fit keeping its aspect, never
/// enlarged), centred, and always tinted srcIn (a template image) with
/// `color` or else the surrounding foreground. The square is empty while it
/// loads, after a failed load and for a `src` that is not a URL, as
/// Flutter's `Image` with no image yet: never the name glyph.
@MainActor
struct IconNodeView: View {
    let node: ResolvedNode
    /// A picture already in hand, drawn in place of loading `src` (tests).
    var image: Image?

    var body: some View {
        let size = Props.number(node["size"]) ?? 24
        Group {
            if let src = node["src"], !src.isNull {
                source(Props.text(src), size: size)
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

    @ViewBuilder
    private func source(_ src: String, size: CGFloat) -> some View {
        if let image {
            fitted(image, size: size)
        } else if let url = URL(string: src) {
            AsyncImage(url: url, scale: 1) { phase in
                if let image = phase.image {
                    fitted(image, size: size)
                } else {
                    Color.clear
                }
            }
        } else {
            Color.clear
        }
    }

    /// Flutter's paintImage with BoxFit.scaleDown and Alignment.center.
    private func fitted(_ image: Image, size: CGFloat) -> some View {
        ImageBox(width: size, height: size, tight: [], fit: .scaleDown, alignment: .center) {
            image.renderingMode(.template).resizable()
        }
    }
}

/// Flutter `Image.network`: `src` loaded from the network (or, for a name
/// without a scheme, from the app's asset catalog), sized and drawn as
/// Flutter's RenderImage (ImageBox): `fit` (Flutter's default here is
/// `cover`), `alignment`, and `repeat` tiling the picture from its fitted
/// place. `color` tints it, as Flutter's default `srcIn` blend does; `alt` is
/// its accessibility label. A failed load draws "!" in the box, as the
/// Flutter error builder.
@MainActor
struct ImageNodeView: View {
    let node: ResolvedNode
    /// A picture already in hand, drawn in place of loading `src` (tests).
    var image: Image?
    @Environment(\.orcaTight) private var tight
    @Environment(\.layoutDirection) private var direction

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
        if let image {
            fitted(image)
        } else if let url = URL(string: src), ["http", "https"].contains(url.scheme?.lowercased()) {
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
        let fit = ImageFit(rawValue: node["fit"]?.stringValue ?? "") ?? .cover
        let alignment = Props.unitPoint(node["alignment"])
        let tiles = ImageTiles(node["repeat"])
        // SwiftUI mirrors a layout's placements in right-to-left; the
        // alignment is absolute, so it is mirrored first.
        let placed = direction == .rightToLeft ? UnitPoint(x: 1 - alignment.x, y: alignment.y) : alignment
        ImageBox(width: Props.number(node["width"]), height: Props.number(node["height"]), tight: tight,
                 fit: fit, alignment: placed) {
            tinted.resizable().opacity(tiles == nil ? 1 : 0)
        }
        .overlay {
            if let tiles {
                Canvas { context, size in
                    let picture = context.resolve(tinted)
                    let place = fit.rect(for: picture.size, in: size, alignment: alignment)
                    context.clip(to: Path(CGRect(origin: .zero, size: size)))
                    for tile in tiles.rects(from: place, in: size) {
                        context.draw(picture, in: tile)
                    }
                }
            }
        }
    }
}

/// Flutter `BoxFit`: how a picture of one size is drawn in a box of another.
enum ImageFit: String {
    case fill, contain, cover, fitWidth, fitHeight, none, scaleDown

    /// Where the whole picture (`natural`, in points) is drawn in `box`:
    /// scaled as the fit says and placed by `alignment` (each axis 0 at the
    /// start, 1 at the end), as Flutter's `paintImage`. Whatever falls outside
    /// the box is cut.
    func rect(for natural: CGSize, in box: CGSize, alignment: UnitPoint) -> CGRect {
        guard natural.width > 0, natural.height > 0 else { return .zero }
        let across = box.width / natural.width, down = box.height / natural.height
        let size: CGSize
        switch self {
        case .fill: size = box
        case .contain: size = natural.scaled(min(across, down))
        case .cover: size = natural.scaled(max(across, down))
        case .fitWidth: size = natural.scaled(across)
        case .fitHeight: size = natural.scaled(down)
        case .none: size = natural
        case .scaleDown: size = natural.scaled(min(1, across, down))
        }
        return CGRect(x: (box.width - size.width) * alignment.x,
                      y: (box.height - size.height) * alignment.y,
                      width: size.width, height: size.height)
    }
}

/// Flutter `ImageRepeat` other than `noRepeat`: the axes the picture is
/// tiled on.
struct ImageTiles: Equatable {
    let across: Bool
    let down: Bool

    init?(_ value: JSONValue?) {
        switch value?.stringValue {
        case "repeat": (across, down) = (true, true)
        case "repeatX": (across, down) = (true, false)
        case "repeatY": (across, down) = (false, true)
        default: return nil
        }
    }

    /// Flutter `_generateImageTileRects`: `place` and its copies a whole
    /// stride apart on the tiled axes, as many as reach into `box`.
    func rects(from place: CGRect, in box: CGSize) -> [CGRect] {
        guard place.width > 0, place.height > 0 else { return [] }
        func steps(_ tiled: Bool, from start: CGFloat, to end: CGFloat, stride length: CGFloat) -> [Int] {
            guard tiled else { return [0] }
            let first = Int((-start / length).rounded(.down))
            let last = Int(((end - start - length) / length).rounded(.up))
            return Array(Swift.stride(from: first, through: last, by: 1))
        }
        let columns = steps(across, from: place.minX, to: box.width, stride: place.width)
        let rows = steps(down, from: place.minY, to: box.height, stride: place.height)
        return rows.flatMap { row in
            columns.map { column in
                place.offsetBy(dx: CGFloat(column) * place.width, dy: CGFloat(row) * place.height)
            }
        }
    }
}

/// Flutter `RenderImage`: the box is `width` by `height` where they are
/// set; otherwise the picture's own size (its pixels at scale 1), kept
/// within what the parent offers and stretched to what it forces
/// (TightAxes), its aspect kept (`constrainSizeAndAttemptToPreserveAspectRatio`).
/// The one subview, the resizable picture, is placed where its fit puts it.
struct ImageBox: Layout {
    let width: CGFloat?
    let height: CGFloat?
    let tight: TightAxes
    let fit: ImageFit
    let alignment: UnitPoint

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let natural = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        func limits(_ set: CGFloat?, _ offered: CGFloat?, forced: Bool) -> (min: CGFloat, max: CGFloat) {
            if let set { return (set, set) }
            let most = offered ?? .infinity
            return (forced && most.isFinite ? most : 0, most)
        }
        let w = limits(width, proposal.width, forced: tight.contains(.horizontal))
        let h = limits(height, proposal.height, forced: tight.contains(.vertical))
        guard natural.width > 0, natural.height > 0, w.min < w.max || h.min < h.max else {
            return CGSize(width: w.min, height: h.min)
        }
        let aspect = natural.width / natural.height
        var size = natural
        if size.width > w.max { size = CGSize(width: w.max, height: w.max / aspect) }
        if size.height > h.max { size = CGSize(width: h.max * aspect, height: h.max) }
        if size.width < w.min { size = CGSize(width: w.min, height: w.min / aspect) }
        if size.height < h.min { size = CGSize(width: h.min * aspect, height: h.min) }
        return CGSize(width: min(max(size.width, w.min), w.max), height: min(max(size.height, h.min), h.max))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let picture = subviews.first else { return }
        let place = fit.rect(for: picture.sizeThatFits(.unspecified), in: bounds.size, alignment: alignment)
        picture.place(at: CGPoint(x: bounds.minX + place.minX, y: bounds.minY + place.minY), anchor: .topLeading,
                      proposal: ProposedViewSize(place.size))
    }
}

private extension CGSize {
    func scaled(_ factor: CGFloat) -> CGSize {
        CGSize(width: width * factor, height: height * factor)
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
