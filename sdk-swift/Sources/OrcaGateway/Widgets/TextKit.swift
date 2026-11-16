#if canImport(SwiftUI)
import CoreText
import SwiftUI
#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
#endif

/// What TextNodeView needs beyond SwiftUI's `Text` modifiers to draw a
/// Flutter `TextStyle` (BH:96-170): the line box, word spacing, the
/// decoration lines SwiftUI cannot draw, `overflow` and `TextAlign.justify`.
extension TextStyleProps {
    /// The platform font SwiftUI draws `font` with, for its metrics. No size:
    /// the body size (SwiftUI's default), 17 with a family, as `font`.
    var platformFont: PlatformFont {
        let pointSize = size ?? (family != nil ? 17 : PlatformFont.preferredFont(forTextStyle: .body).pointSize)
        if let family, let font = PlatformFont(name: family, size: pointSize) { return font }
        let weights: [Font.Weight: PlatformFont.Weight] = [
            .ultraLight: .ultraLight, .thin: .thin, .light: .light, .medium: .medium,
            .semibold: .semibold, .bold: .bold, .heavy: .heavy, .black: .black,
        ]
        return PlatformFont.systemFont(ofSize: pointSize, weight: weight.flatMap { weights[$0] } ?? .regular)
    }

    /// Flutter `height`: each line box is height x fontSize. SwiftUI lays a
    /// line at the font's own height, so the caller puts the difference
    /// between lines (`lineSpacing`) and half of it above the first and
    /// below the last line (padding). 0 without `height`. A box smaller
    /// than the font's own line (negative) only shrinks the outer padding:
    /// SwiftUI cannot overlap lines, so wrapped lines keep the font's pitch.
    var extraLeading: CGFloat {
        guard let height else { return 0 }
        let font = platformFont
        return height * font.pointSize - (font.ascender - font.descender + font.leading)
    }

    /// The text with Flutter's `wordSpacing` added to each space, as the
    /// space's kerning (which replaces `letterSpacing` there, so both add).
    /// Without `wordSpacing` the plain `Text(string)`: no attributed string.
    func text(_ string: String) -> Text {
        guard let wordSpacing else { return Text(string) }
        var text = AttributedString(string)
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.characters.index(after: index)
            if text.characters[index] == " " { text[index..<next].kern = (letterSpacing ?? 0) + wordSpacing }
            index = next
        }
        return Text(text)
    }

    /// Lines SwiftUI's `Text` cannot draw (an overline; a double or wavy
    /// underline or line-through), drawn by `DecorationRenderer` on iOS 18 /
    /// macOS 15 (where `textRenderer` exists). Before that an overline is not
    /// drawn and double or wavy lines are solid.
    var rendersLines: Bool {
        guard #available(iOS 18, macOS 15, *) else { return false }
        return overline || ((underline || strikethrough) && (decorationStyle == .double || decorationStyle == .wavy))
    }

    /// The width of an ellipsis in this style: Flutter's `fade` fades the
    /// last this much of the box.
    var ellipsisWidth: CGFloat {
        NSAttributedString(string: "\u{2026}", attributes: [.font: platformFont]).size().width
    }

    @available(iOS 18, macOS 15, *)
    var lineRenderer: DecorationRenderer? {
        guard rendersLines else { return nil }
        return decorationLine(color: decorationColor ?? color)
    }

    /// The style's line (an overline, underline or line-through) as
    /// DecorationRenderer draws it: placed and as thick as `platformFont`
    /// says (no `decorationThickness`), in `color` (nil: the foreground).
    /// Nil when the style has no line.
    @available(iOS 18, macOS 15, *)
    func decorationLine(color: Color?) -> DecorationRenderer? {
        guard overline || underline || strikethrough else { return nil }
        let font = platformFont as CTFont
        let size = CTFontGetSize(font)
        let thickness = CTFontGetUnderlineThickness(font)
        let shading: GraphicsContext.Shading = color.map { .color($0) } ?? .foreground
        return DecorationRenderer(
            baselineOffset: overline ? nil : underline ? -CTFontGetUnderlinePosition(font) : -CTFontGetXHeight(font) / 2,
            thickness: thickness > 0 ? thickness : size / 14, unit: size / 14, style: decorationStyle,
            shading: shading)
    }
}

/// Flutter's decoration lines (Skia `Decorations`) on each line of the text:
/// an overline centred on the font's ascent above the baseline (the top of
/// the glyphs, below the half-leading `height` adds), an underline at the
/// font's underline position below the baseline, a line-through half the
/// x-height above it; the font's underline thickness; dashed 4 on 2 off and
/// dotted 1 on 1.5 off in units of fontSize / 14; double a second line 3
/// points below; wavy quarter waves one thickness high.
@available(iOS 18, macOS 15, *)
struct DecorationRenderer: TextRenderer {
    /// Below the baseline (negative: above it); nil for an overline.
    let baselineOffset: CGFloat?
    let thickness: CGFloat
    let unit: CGFloat
    let style: TextStyleProps.DecorationStyle
    let shading: GraphicsContext.Shading

    /// Room for the half of an overline above the text, a wave's crest and
    /// a double line's second line below the descent.
    var displayPadding: EdgeInsets {
        EdgeInsets(top: thickness * 2, leading: 0, bottom: 3 + thickness * 2, trailing: 0)
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            ctx.draw(line)
            stroke(line.typographicBounds, in: &ctx)
        }
    }

    /// The line across `bounds` (a text line's, or a run's for
    /// `RunLinesRenderer`): from its baseline (`origin.y`) and ascent, over
    /// its whole width.
    func stroke(_ bounds: Text.Layout.TypographicBounds, in ctx: inout GraphicsContext) {
        let y = baselineOffset.map { bounds.origin.y + $0 } ?? bounds.origin.y - bounds.ascent
        let start = bounds.rect.minX, end = bounds.rect.maxX
        var path = Path()
        path.move(to: CGPoint(x: start, y: y))
        if style == .wavy {
            var x = start, up = true
            while x + thickness * 2 <= end {
                path.addQuadCurve(to: CGPoint(x: x + thickness * 2, y: y),
                                  control: CGPoint(x: x + thickness, y: up ? y - thickness : y + thickness))
                x += thickness * 2
                up.toggle()
            }
        } else {
            path.addLine(to: CGPoint(x: end, y: y))
            if style == .double {
                path.move(to: CGPoint(x: start, y: y + 3))
                path.addLine(to: CGPoint(x: end, y: y + 3))
            }
        }
        let dash: [CGFloat] = style == .dashed ? [4 * unit, 2 * unit] : style == .dotted ? [unit, 1.5 * unit] : []
        ctx.stroke(path, with: shading, style: StrokeStyle(lineWidth: thickness, dash: dash))
    }
}

/// DecorationRenderer's range form, for a RichText: a run of the text
/// tagged `Tag(index)` gets `lines[index]` under (an overline: over) its
/// own glyphs alone, from that run's baseline and ascent, on each line it
/// wraps onto, as Flutter's paragraph paints a decoration per style run.
/// An overline is centred on the run's top edge, half of it above, for
/// every style (SkParagraph Decorations.cpp: calculatePosition's
/// `-ascent`, 0 without a height or a baseline shift, from the clip's
/// top). Layout runs of one tag side by side on a line share one stroke,
/// so a wave or a dash runs on across them. Untagged runs get no line.
@available(iOS 18, macOS 15, *)
struct RunLinesRenderer: TextRenderer {
    /// Which of `lines` a run draws.
    struct Tag: TextAttribute {
        let index: Int
    }

    let lines: [DecorationRenderer]

    /// The most room any of the lines needs.
    var displayPadding: EdgeInsets {
        lines.reduce(into: EdgeInsets()) { room, line in
            room.top = max(room.top, line.displayPadding.top)
            room.bottom = max(room.bottom, line.displayPadding.bottom)
        }
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            ctx.draw(line)
            var tag: Tag?
            var span = Text.Layout.TypographicBounds()
            for run in line {
                let bounds = run.typographicBounds
                if let current = tag, run[Tag.self] == current {
                    let start = min(span.rect.minX, bounds.rect.minX), end = max(span.rect.maxX, bounds.rect.maxX)
                    span.origin.x = start
                    span.width = end - start
                    span.ascent = max(span.ascent, bounds.ascent)
                } else {
                    if let tag { lines[tag.index].stroke(span, in: &ctx) }
                    tag = run[Tag.self]
                    span = bounds
                }
            }
            if let tag { lines[tag.index].stroke(span, in: &ctx) }
        }
    }
}

extension TextStyleProps {
    /// The style's `Text`, with `DecorationRenderer` where it draws the
    /// lines. Otherwise the bare styled `Text`, as a Text drew before: no
    /// view around it (the availability branch, an `AnyView`, is only taken
    /// with a renderer).
    @MainActor @ViewBuilder
    func styledText(_ data: String) -> some View {
        let text = apply(self.text(data))
        if #available(iOS 18, macOS 15, *), let renderer = lineRenderer {
            text.textRenderer(renderer)
        } else {
            text
        }
    }
}

/// Flutter `softWrap: false`: the text on one line at its own width. The
/// box is as wide as the text or as the width offered, whichever is less,
/// and the line runs on past it (the caller clips or fades it).
struct OneLineLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let size = text.sizeThatFits(.unspecified)
        return CGSize(width: min(proposal.width ?? size.width, size.width), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: .unspecified)
    }
}

/// Flutter `maxLines` with `overflow` clip, fade or visible: the text wraps
/// as usual and the box stops after `maxLines` lines, with no ellipsis
/// (SwiftUI's `lineLimit` always adds one). Subviews: the whole text, then
/// the same text with `lineLimit(maxLines)`, hidden, whose height is where
/// the box stops. Flutter's vertical fade over the last line is not drawn.
struct LineCutLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = ProposedViewSize(width: proposal.width, height: nil)
        let whole = subviews[0].sizeThatFits(width)
        return CGSize(width: whole.width, height: min(whole.height, subviews[1].sizeThatFits(width).height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for text in subviews {
            text.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }
}

/// Flutter's `fade` on one line (RenderParagraph's overflow shader):
/// opaque, then clear over the last `width` points at the trailing edge.
struct FadeMask: View {
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .flipsForRightToLeftLayoutDirection(true)
                .frame(width: width)
        }
    }
}

#if canImport(UIKit)
/// Flutter `TextAlign.justify` on iOS: SwiftUI's `Text` cannot justify, so
/// a UILabel draws the text with `NSTextAlignment.justified` (every line
/// but the last stretched, as Flutter). It draws the font, colour, letter
/// and word spacing, line spacing, and an underline or line-through (dotted,
/// dashed, double; wavy is solid); no overline (UIKit has none). `lines` 0
/// is unlimited; past it the text is cut, with an ellipsis for `ellipsis`
/// (fade and visible cut as clip). A Text's string in its one style, or a
/// RichText's runs (`init(runs:lines:ellipsis:)`). macOS draws a `start`
/// aligned Text.
struct JustifiedText: UIViewRepresentable {
    let style: TextStyleProps
    let data: String
    let lines: Int
    let ellipsis: Bool
    let lineSpacing: CGFloat
    /// A RichText's runs, drawn in place of `data` in `style` (see
    /// `init(runs:lines:ellipsis:)`); nil for a Text.
    var runs: [TextStyles.Run]?

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = attributedText
        label.numberOfLines = lines
        label.lineBreakMode = ellipsis ? .byTruncatingTail : .byWordWrapping
    }

    /// One line at its own width when it fits; else the width offered and
    /// as many lines as it takes (Flutter's paragraph spans its box).
    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: UILabel, context: Context) -> CGSize? {
        let free = CGFloat.greatestFiniteMagnitude
        let line = label.sizeThatFits(CGSize(width: free, height: free))
        guard let width = proposal.width, width < line.width else {
            return CGSize(width: ceil(line.width), height: ceil(line.height))
        }
        return CGSize(width: width, height: ceil(label.sizeThatFits(CGSize(width: width, height: free)).height))
    }

    var attributedText: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.lineSpacing = lineSpacing
        guard let runs else { return style.attributed(data, paragraph: paragraph) }
        return runs.reduce(into: NSMutableAttributedString()) { text, run in
            let style = TextStyleProps(run.style).onEngineBase
            let piece = style.attributed(run.text, paragraph: paragraph)
            if let background = style.background {
                piece.addAttribute(.backgroundColor, value: UIColor(background),
                                   range: NSRange(location: 0, length: piece.length))
            }
            text.append(piece)
        }
    }
}

/// A style as UIKit text attributes, for the UIKit views that draw text
/// (JustifiedText's label, SelectableText's text view).
extension TextStyleProps {
    /// `string` in this style: its font (`font`, else `platformFont`;
    /// italic through the descriptor), colour, letter and word spacing,
    /// its underline or line-through, and `paragraph`.
    func attributed(_ string: String, paragraph: NSParagraphStyle,
                    font: UIFont? = nil) -> NSMutableAttributedString {
        var font = font ?? platformFont
        if italic, let slanted = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            font = UIFont(descriptor: slanted, size: 0)
        }
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraph]
        if let color { attributes[.foregroundColor] = UIColor(color) }
        if let letterSpacing { attributes[.kern] = letterSpacing }
        let pattern: NSUnderlineStyle = switch decorationStyle {
        case .double: .double
        case .dotted: [.single, .patternDot]
        case .dashed: [.single, .patternDash]
        default: .single
        }
        let lineColor = decorationColor.map { UIColor($0) }
        if underline {
            attributes[.underlineStyle] = pattern.rawValue
            attributes[.underlineColor] = lineColor
        }
        if strikethrough {
            attributes[.strikethroughStyle] = pattern.rawValue
            attributes[.strikethroughColor] = lineColor
        }
        let text = NSMutableAttributedString(string: string, attributes: attributes)
        if let wordSpacing {
            for (offset, unit) in string.utf16.enumerated() where unit == 0x20 {
                text.addAttribute(.kern, value: (letterSpacing ?? 0) + wordSpacing,
                                  range: NSRange(location: offset, length: 1))
            }
        }
        return text
    }

    /// `platformFont` at the Dynamic Type size `category`, as SwiftUI sizes
    /// a Text's `font` (or the ambient `.body` when the style has none):
    /// without a size or a family, the body size at `category`; a family
    /// scaled from its size (17 without one) as `Font.custom` scales; a
    /// system font with a size fixed.
    func platformFont(at category: UIContentSizeCategory) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        if family != nil {
            return UIFontMetrics(forTextStyle: .body).scaledFont(for: platformFont, compatibleWith: traits)
        }
        guard size == nil else { return platformFont }
        var body = self
        body.size = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits).pointSize
        return body.platformFont
    }
}

extension JustifiedText {
    /// A RichText's runs, justified: each in its merged style on the
    /// engine base (`TextStyleProps.engineRun`'s: 14 points at a fixed
    /// size, white, regular) with its background, and the lines a justified
    /// Text draws (dotted, dashed, double, decorationColor; wavy solid; no
    /// overline). No line spacing: a span's `height` is not drawn.
    init(runs: [TextStyles.Run], lines: Int, ellipsis: Bool) {
        self.init(style: TextStyleProps(nil), data: "", lines: lines, ellipsis: ellipsis, lineSpacing: 0, runs: runs)
    }
}
#endif
#endif
