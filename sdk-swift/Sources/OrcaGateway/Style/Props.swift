#if canImport(SwiftUI)
import SwiftUI

/// Prop parsers shared by the widget views, ported from the Flutter SDK's
/// `builders/builder_helpers.dart`. Unknown or malformed values fall back to
/// the Flutter default instead of failing.
enum Props {
    /// `#RRGGBB` (opaque) or `#RRGGBBAA` (alpha last, CSS order); anything
    /// else is nil (Dart `parseColor`).
    static func color(_ value: JSONValue?) -> Color? {
        guard case .string(let text)? = value, text.hasPrefix("#") else { return nil }
        let hex = String(text.dropFirst())
        guard hex.count == 6 || hex.count == 8, let raw = UInt64(hex, radix: 16) else { return nil }
        let rgba = hex.count == 6 ? (raw << 8) | 0xFF : raw
        return Color(
            .sRGB,
            red: Double((rgba >> 24) & 0xFF) / 255,
            green: Double((rgba >> 16) & 0xFF) / 255,
            blue: Double((rgba >> 8) & 0xFF) / 255,
            opacity: Double(rgba & 0xFF) / 255)
    }

    static func color(hex: String) -> Color {
        color(.string(hex)) ?? .primary
    }

    static func number(_ value: JSONValue?) -> CGFloat? {
        value?.doubleValue.map { CGFloat($0) }
    }

    static func bool(_ value: JSONValue?) -> Bool? {
        value?.boolValue
    }

    static func string(_ value: JSONValue?) -> String? {
        value?.stringValue
    }

    /// Dart `resolveStringValue`: null is "", numbers and bools are printed
    /// the Dart way.
    static func text(_ value: JSONValue?) -> String {
        guard let value, !value.isNull else { return "" }
        return DartFormat.string(value)
    }

    /// `{top, right, bottom, left}`, missing sides 0; anything else nil. The
    /// engine always sends all four (engine/src/components/helpers/edge-insets.ts).
    static func insets(_ value: JSONValue?) -> EdgeInsets? {
        guard case .object(let o)? = value else { return nil }
        func side(_ key: String) -> CGFloat { CGFloat(o[key]?.doubleValue ?? 0) }
        return EdgeInsets(top: side("top"), leading: side("left"), bottom: side("bottom"), trailing: side("right"))
    }

    /// Flutter `EdgeInsets` are absolute: `left` is the left side in either
    /// layout direction. The same insets in SwiftUI's leading/trailing terms
    /// for `direction`; `fallback` (in the same absolute terms) when absent.
    static func insets(_ value: JSONValue?, direction: LayoutDirection, fallback: EdgeInsets = EdgeInsets()) -> EdgeInsets {
        var insets = insets(value) ?? fallback
        if direction == .rightToLeft { swap(&insets.leading, &insets.trailing) }
        return insets
    }

    /// `w100`...`w900`, `normal` (w400), `bold` (w700); nil inherits.
    static func fontWeight(_ value: JSONValue?) -> Font.Weight? {
        switch value?.stringValue {
        case "w100": return .ultraLight
        case "w200": return .thin
        case "w300": return .light
        case "w400", "normal": return .regular
        case "w500": return .medium
        case "w600": return .semibold
        case "w700", "bold": return .bold
        case "w800": return .heavy
        case "w900": return .black
        default: return nil
        }
    }

    enum MainAxis: String {
        case start, end, center, spaceBetween, spaceAround, spaceEvenly
    }

    static func mainAxis(_ value: JSONValue?) -> MainAxis {
        value?.stringValue.flatMap(MainAxis.init(rawValue:)) ?? .start
    }

    enum CrossAxis: String {
        case start, end, center, stretch, baseline
    }

    static func crossAxis(_ value: JSONValue?) -> CrossAxis {
        value?.stringValue.flatMap(CrossAxis.init(rawValue:)) ?? .center
    }

    /// `min` or `max` (default).
    static func fillsMainAxis(_ value: JSONValue?) -> Bool {
        value?.stringValue != "min"
    }

    /// Flutter `TextAlign` (PB:400-410): `left` and `right` are absolute (they
    /// do not flip in right-to-left), `start` and `end` follow `direction`.
    /// `justify` lines up as `start` here; TextNodeView justifies on iOS.
    static func textAlignment(_ value: JSONValue?, direction: LayoutDirection = .leftToRight) -> TextAlignment? {
        let rightToLeft = direction == .rightToLeft
        switch value?.stringValue {
        case "start", "justify": return .leading
        case "end": return .trailing
        case "left": return rightToLeft ? .trailing : .leading
        case "right": return rightToLeft ? .leading : .trailing
        case "center": return .center
        default: return nil
        }
    }

    static func frameAlignment(_ text: TextAlignment?) -> Alignment {
        switch text {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }

    /// Flutter `parseAlignment`: the nine names; anything else is center.
    static func alignment(_ value: JSONValue?) -> Alignment {
        switch value?.stringValue {
        case "topLeft": return .topLeading
        case "topCenter": return .top
        case "topRight": return .topTrailing
        case "centerLeft": return .leading
        case "centerRight": return .trailing
        case "bottomLeft": return .bottomLeading
        case "bottomCenter": return .bottom
        case "bottomRight": return .bottomTrailing
        default: return .center
        }
    }

    /// The same nine names as a point in a unit square (gradient ends), or
    /// an `{x, y}` object in -1...1, the form the core writes an alignment
    /// in while an implicit animation mixes two (`AnimationMix.alignment`).
    static func unitPoint(_ value: JSONValue?) -> UnitPoint {
        if case .object(let o)? = value, let x = o["x"]?.doubleValue, let y = o["y"]?.doubleValue {
            return UnitPoint(x: (x + 1) / 2, y: (y + 1) / 2)
        }
        switch value?.stringValue {
        case "topLeft": return .topLeading
        case "topCenter": return .top
        case "topRight": return .topTrailing
        case "centerLeft": return .leading
        case "centerRight": return .trailing
        case "bottomLeft": return .bottomLeading
        case "bottomCenter": return .bottom
        case "bottomRight": return .bottomTrailing
        default: return .center
        }
    }

    /// Flutter `_parseBorderRadius`: a number rounds every corner, an object
    /// `{topLeft, topRight, bottomLeft, bottomRight}` each (missing ones 0);
    /// anything else is nil.
    static func radii(_ value: JSONValue?) -> CornerRadii? {
        switch value {
        case .int?, .double?:
            return value?.doubleValue.map { CornerRadii(all: CGFloat($0)) }
        case .object(let o)?:
            func corner(_ key: String) -> CGFloat { CGFloat(o[key]?.doubleValue ?? 0) }
            return CornerRadii(topLeft: corner("topLeft"), topRight: corner("topRight"),
                               bottomLeft: corner("bottomLeft"), bottomRight: corner("bottomRight"))
        default:
            return nil
        }
    }

    /// Flutter `parseClip`: only `none` (the default) leaves the box unclipped.
    static func clips(_ value: JSONValue?) -> Bool {
        ["hardEdge", "antiAlias", "antiAliasWithSaveLayer"].contains(value?.stringValue ?? "none")
    }
}

extension View {
    /// Padding from a Flutter `EdgeInsets` `{top, right, bottom, left}`, its
    /// sides absolute: `left` stays on the left in right-to-left (D4).
    /// `fallback` (absolute too) when the value is absent.
    func orcaPadding(_ value: JSONValue?, fallback: EdgeInsets = EdgeInsets()) -> some View {
        modifier(AbsolutePadding(value: value, fallback: fallback))
    }
}

private struct AbsolutePadding: ViewModifier {
    let value: JSONValue?
    let fallback: EdgeInsets
    @Environment(\.layoutDirection) private var direction

    func body(content: Content) -> some View {
        content.padding(Props.insets(value, direction: direction, fallback: fallback))
    }
}

/// Flutter `TextStyleData` applied to a SwiftUI `Text` (BH:96-170). The
/// line box, word spacing and the lines SwiftUI cannot draw are in TextKit.swift.
struct TextStyleProps {
    enum DecorationStyle: String {
        case solid, double, dotted, dashed, wavy
    }

    var size: CGFloat?
    var weight: Font.Weight?
    var family: String?
    var italic = false
    var color: Color?
    var background: Color?
    var letterSpacing: CGFloat?
    var underline = false
    var strikethrough = false
    var decorationColor: Color?
    /// Flutter `height`: the line box is `height` x fontSize.
    var height: CGFloat?
    var wordSpacing: CGFloat?
    var overline = false
    var decorationStyle = DecorationStyle.solid
    /// `clip`, `fade`, `ellipsis` or `visible`; the Text's own `overflow` wins.
    var overflow: String?

    init(_ value: JSONValue?) {
        guard case .object(let s)? = value else { return }
        size = Props.number(s["fontSize"])
        weight = Props.fontWeight(s["fontWeight"])
        family = s["fontFamily"]?.stringValue
        italic = s["fontStyle"]?.stringValue == "italic"
        color = Props.color(s["color"])
        background = Props.color(s["backgroundColor"])
        letterSpacing = Props.number(s["letterSpacing"])
        let decoration = s["decoration"]?.stringValue
        underline = decoration == "underline"
        strikethrough = decoration == "lineThrough"
        overline = decoration == "overline"
        decorationColor = Props.color(s["decorationColor"])
        decorationStyle = s["decorationStyle"]?.stringValue.flatMap(DecorationStyle.init(rawValue:)) ?? .solid
        height = Props.number(s["height"])
        wordSpacing = Props.number(s["wordSpacing"])
        overflow = s["overflow"]?.stringValue
    }

    var font: Font? {
        guard size != nil || weight != nil || family != nil else { return nil }
        let base: Font
        if let family {
            base = .custom(family, size: size ?? 17)
        } else if let size {
            base = .system(size: size)
        } else {
            base = .body
        }
        return weight.map { base.weight($0) } ?? base
    }

    /// Font, colour, spacing and the underline or line-through SwiftUI
    /// draws itself: solid, dotted and dashed (`Text.LineStyle`). Overline,
    /// double and wavy are drawn by `DecorationRenderer` where it exists.
    func apply(_ text: Text) -> Text {
        var t = text
        if let font { t = t.font(font) }
        if italic { t = t.italic() }
        if let color { t = t.foregroundColor(color) }
        if let letterSpacing { t = t.kerning(letterSpacing) }
        guard underline || strikethrough, !rendersLines else { return t }
        let pattern: Text.LineStyle.Pattern = decorationStyle == .dotted ? .dot : decorationStyle == .dashed ? .dash : .solid
        if underline { t = t.underline(true, pattern: pattern, color: decorationColor) }
        if strikethrough { t = t.strikethrough(true, pattern: pattern, color: decorationColor) }
        return t
    }
}

extension TextStyleProps {
    /// Flutter's engine defaults for what a style leaves unset: 14 points
    /// (painting/text_painter.dart:42), white (engine txt/src/txt/
    /// text_style.h:26,41), regular, upright, no line. A raw RichText draws
    /// on them, never on the ambient style (design D5).
    static let engineSize: CGFloat = 14
    static let engineColor = Color.white

    /// The font on the engine base at a fixed size (no Dynamic Type: a raw
    /// RichText does not scale its text): size ?? 14, weight ?? regular,
    /// italic only when the style says so.
    var engineFont: Font {
        let size = self.size ?? Self.engineSize
        let font: Font = family.map { .custom($0, fixedSize: size) } ?? .system(size: size)
        let weighted = font.weight(weight ?? .regular)
        return italic ? weighted.italic() : weighted
    }

    /// `string` as one run on the engine base. Its font and colour are
    /// always set, so nothing ambient shows through and a style whose
    /// fontStyle is "normal" or whose decoration is "none" (what
    /// `TextStyles.merge` writes over a parent's) draws upright and without
    /// a line. Then what the style sends: background, letter and word
    /// spacing (as `text(_:)`), a solid underline and line-through in the
    /// text's colour.
    func engineRun(_ string: String) -> AttributedString {
        var run = AttributedString(string)
        run.swiftUI.font = engineFont
        run.swiftUI.foregroundColor = color ?? Self.engineColor
        if let background { run.swiftUI.backgroundColor = background }
        if let letterSpacing { run.swiftUI.kern = letterSpacing }
        if let wordSpacing {
            for space in run.characters.indices where run.characters[space] == " " {
                run[space..<run.characters.index(after: space)].swiftUI.kern = (letterSpacing ?? 0) + wordSpacing
            }
        }
        if underline { run.swiftUI.underlineStyle = .single }
        if strikethrough { run.swiftUI.strikethroughStyle = .single }
        return run
    }
}
#endif
