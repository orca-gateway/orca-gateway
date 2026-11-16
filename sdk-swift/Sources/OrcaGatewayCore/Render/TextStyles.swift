import Foundation

/// How wire text styles (engine `TextStyleData`, the JSON object a style
/// prop carries) combine, as Flutter combines the `TextStyle`s its builders
/// parse them into (sdk/lib/src/builders/builder_helpers.dart:96-120
/// `parseTextStyle`). Pure: RichText flattens its span tree here, and a
/// Text or SelectableText under a DefaultTextStyle layers its own fields
/// over the DTS's here; the UI layers parse the result as they parse any
/// style (design D4). The same as Kotlin's TextStyles.
public enum TextStyles {
    /// One RichText run: its text and the style it draws in, already merged
    /// onto every style above it (nil when none was).
    public struct Run: Equatable, Sendable {
        public var text: String
        public var style: JSONValue?

        public init(text: String, style: JSONValue?) {
            self.text = text
            self.style = style
        }
    }

    /// What a DefaultTextStyle hands down and what a Text sends of its own:
    /// the wire `style` object, `textAlign`, `maxLines` and `overflow`.
    public struct Layer: Equatable, Sendable {
        public var style: JSONValue?
        public var textAlign: String?
        public var maxLines: Int?
        public var overflow: String?

        public init(style: JSONValue? = nil, textAlign: String? = nil, maxLines: Int? = nil, overflow: String? = nil) {
            self.style = style
            self.textAlign = textAlign
            self.maxLines = maxLines
            self.overflow = overflow
        }
    }

    /// `child` laid over `parent`: Flutter `TextStyle.merge` (painting/
    /// text_style.dart:1078-1122) of the two parsed styles, which for spans
    /// is the engine's PushStyle on its parent's (lib/ui/text/
    /// paragraph_builder.cc:396). A child that is not an object is no style
    /// (parseTextStyle returns null): the parent as it is. Else the child's
    /// non-null fields win field by field, decoration "none" too (a set
    /// value, builder_helpers.dart:141, so it clears the parent's line), and
    /// fontStyle is always the child's, "italic" or else "normal", as
    /// parseTextStyle always sets it (:103-105). Field values go through as
    /// sent; the UI parses them.
    public static func merge(_ parent: JSONValue?, _ child: JSONValue?) -> JSONValue? {
        guard case .object(let fields)? = child else { return parent }
        var merged = parent?.objectValue ?? [:]
        for (key, value) in fields where !value.isNull {
            merged[key] = value
        }
        merged["fontStyle"] = fields["fontStyle"] == "italic" ? "italic" : "normal"
        return .object(merged)
    }

    /// RichText's span tree as runs, depth-first: a span's own text, then
    /// its children (Flutter `_buildTextSpan`, primitive_builders.dart:
    /// 339-348). Each span's style is merged onto its parent's, the root's
    /// onto `base`. A span's text is resolveStringValue's (builder_helpers
    /// .dart:436-447): '' when absent or null, so a span without text is an
    /// empty run (:340); a child that is not an object is a run of Dart's
    /// `'$c'` in its parent's style (:344). No root is Flutter's
    /// `const TextSpan()` (:332): one empty run in `base`.
    public static func spans(_ root: JSONValue?, base: JSONValue?) -> [Run] {
        var runs: [Run] = []
        walk(root?.objectValue ?? [:], parent: base, into: &runs)
        return runs
    }

    private static func walk(_ span: [String: JSONValue], parent: JSONValue?, into runs: inout [Run]) {
        let style = merge(parent, span["style"])
        let text = span["text"].map { $0.isNull ? "" : DartFormat.string($0) } ?? ""
        runs.append(Run(text: text, style: style))
        for child in span["children"]?.arrayValue ?? [] {
            if case .object(let object) = child {
                walk(object, parent: style, into: &runs)
            } else {
                runs.append(Run(text: DartFormat.string(child), style: style))
            }
        }
    }

    /// A Text's own fields over its DefaultTextStyle's (`dts`, nil when
    /// none): Flutter `Text.build` (widgets/text.dart:723-728, :789-796).
    /// The style is the DTS's merged with the Text's own; textAlign own ??
    /// DTS ?? "start"; maxLines own ?? DTS; overflow own ?? the merged
    /// style's ?? DTS ?? "clip" (the DTS builder's default,
    /// layout_builders.dart:598, and DefaultTextStyle.fallback's). The
    /// merged style's overflow is Flutter's `effectiveTextStyle?.overflow`,
    /// so a DTS style's overflow beats the DTS's own.
    public static func layer(dts: Layer?, own: Layer) -> Layer {
        let style = merge(dts?.style, own.style)
        return Layer(
            style: style,
            textAlign: own.textAlign ?? dts?.textAlign ?? "start",
            maxLines: own.maxLines ?? dts?.maxLines,
            overflow: own.overflow ?? style?["overflow"].stringValue ?? dts?.overflow ?? "clip")
    }
}
