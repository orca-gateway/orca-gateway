#if canImport(SwiftUI)
import SwiftUI

/// Flutter `RichText` as the builder makes it (PB:325-348): the raw widget,
/// not `Text.rich`, so no DefaultTextStyle, no ambient style and no text
/// scaling; start, softWrap, clip (FW widgets/basic.dart RichText). The
/// span tree becomes runs through `TextStyles.spans` (each span's style
/// merged onto its parent's: a styled child is upright unless italic,
/// decoration "none" clears the parent's line), drawn as one Text of an
/// AttributedString whose runs sit on the engine's defaults
/// (`TextStyleProps.engineRun`: 14 points, white). A run's own line is
/// drawn under (an overline: over) that run alone (`text(_:)`).
/// `textAlign` and the width as a Text's: justify on iOS through
/// JustifiedText (every line but the last fills the width), on macOS as
/// start, as a Text's; `maxLines` with overflow ellipsis truncates the last
/// line, any other overflow cuts the lines past it (LineCutLayout, as a
/// Text with maxLines). softWrap is never sent, so a RichText always wraps.
/// A known difference: a span's `height` is not drawn (SwiftUI has no line
/// box per run), so its lines keep their font's own height.
@MainActor
struct RichTextView: View {
    let node: ResolvedNode
    @Environment(\.orcaTight) private var tight
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let alignment = Props.textAlignment(node["textAlign"], direction: direction) ?? .leading
        paragraphView(TextStyles.spans(node["text"], base: nil))
            .multilineTextAlignment(alignment)
            .frame(maxWidth: tight.contains(.horizontal) ? .infinity : nil,
                   alignment: Props.frameAlignment(alignment))
    }

    /// The runs, one after another, each on the engine base.
    static func attributed(_ runs: [TextStyles.Run]) -> AttributedString {
        runs.reduce(into: AttributedString()) { text, run in
            text += TextStyleProps(run.style).engineRun(run.text)
        }
    }

    /// The runs as one Text. On iOS 18 / macOS 15 a run whose line is not
    /// engineRun's solid one in its colour (an overline; a double, wavy,
    /// dotted or dashed line; a decorationColor) drops engineRun's line and
    /// RunLinesRenderer draws it under (an overline: over) that run's glyphs
    /// alone. Below them (the package deploys to iOS 16 / macOS 13, and the
    /// renderer and its Text.Layout runs are iOS 18 / macOS 15) every run
    /// keeps engineRun's solid underline or line-through in its own colour,
    /// and an overline is not drawn.
    @ViewBuilder
    static func text(_ runs: [TextStyles.Run]) -> some View {
        if #available(iOS 18, macOS 15, *), let lined = linedText(runs) {
            lined.text.textRenderer(RunLinesRenderer(lines: lined.lines))
        } else {
            Text(attributed(runs))
        }
    }

    /// The runs as one Text, each run with a line of its own for the
    /// renderer tagged with that line's index in `lines`; nil when no run
    /// has one.
    @available(iOS 18, macOS 15, *)
    static func linedText(_ runs: [TextStyles.Run]) -> (text: Text, lines: [DecorationRenderer])? {
        let styles = runs.map { TextStyleProps($0.style) }
        guard styles.contains(where: \.hasRunLine) else { return nil }
        var text = Text(verbatim: "")
        var lines: [DecorationRenderer] = []
        for (run, style) in zip(runs, styles) {
            var string = style.engineRun(run.text)
            guard let line = style.runLine else {
                text = text + Text(string)
                continue
            }
            string.swiftUI.underlineStyle = nil
            string.swiftUI.strikethroughStyle = nil
            text = text + Text(string).customAttribute(RunLinesRenderer.Tag(index: lines.count))
            lines.append(line)
        }
        return (text, lines)
    }

    /// iOS justify: a UIKit label of the runs (TextKit JustifiedText).
    @ViewBuilder
    private func paragraphView(_ runs: [TextStyles.Run]) -> some View {
        #if canImport(UIKit)
        if node["textAlign"]?.stringValue == "justify" {
            JustifiedText(runs: runs, lines: maxLines ?? 0, ellipsis: node["overflow"]?.stringValue == "ellipsis")
        } else {
            lines(Self.text(runs))
        }
        #else
        lines(Self.text(runs))
        #endif
    }

    private var maxLines: Int? {
        node["maxLines"]?.intValue.flatMap { $0 > 0 ? $0 : nil }
    }

    @ViewBuilder
    private func lines(_ text: some View) -> some View {
        if let maxLines {
            if node["overflow"]?.stringValue == "ellipsis" {
                text.lineLimit(maxLines)
            } else {
                LineCutLayout {
                    text
                    text.lineLimit(maxLines).hidden()
                }
                .clipped()
            }
        } else {
            text
        }
    }
}

private extension TextStyleProps {
    /// A line other than engineRun's solid one in the run's colour: an
    /// overline, a double, wavy, dotted or dashed line, or a decorationColor.
    var hasRunLine: Bool {
        overline || ((underline || strikethrough) && (decorationStyle != .solid || decorationColor != nil))
    }

    /// That line as RunLinesRenderer draws it: placed by the run's font on
    /// the engine base (size ?? 14), in decorationColor ?? the run's colour
    /// (?? white).
    @available(iOS 18, macOS 15, *)
    var runLine: DecorationRenderer? {
        guard hasRunLine else { return nil }
        let run = onEngineBase
        return run.decorationLine(color: decorationColor ?? run.color)
    }
}
#endif
