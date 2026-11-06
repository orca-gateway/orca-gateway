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

    static func textAlignment(_ value: JSONValue?) -> TextAlignment? {
        switch value?.stringValue {
        case "left", "start", "justify": return .leading
        case "right", "end": return .trailing
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

}

/// Flutter `TextStyleData` applied to a SwiftUI `Text`.
struct TextStyleProps {
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

    init(_ value: JSONValue?) {
        guard case .object(let s)? = value else { return }
        size = Props.number(s["fontSize"])
        weight = Props.fontWeight(s["fontWeight"])
        family = s["fontFamily"]?.stringValue
        italic = s["fontStyle"]?.stringValue == "italic"
        color = Props.color(s["color"])
        background = Props.color(s["backgroundColor"])
        letterSpacing = Props.number(s["letterSpacing"])
        underline = s["decoration"]?.stringValue == "underline"
        strikethrough = s["decoration"]?.stringValue == "lineThrough"
        decorationColor = Props.color(s["decorationColor"])
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

    func apply(_ text: Text) -> Text {
        var t = text
        if let font { t = t.font(font) }
        if italic { t = t.italic() }
        if let color { t = t.foregroundColor(color) }
        if let letterSpacing { t = t.kerning(letterSpacing) }
        if underline { t = t.underline(true, color: decorationColor) }
        if strikethrough { t = t.strikethrough(true, color: decorationColor) }
        return t
    }
}
#endif
