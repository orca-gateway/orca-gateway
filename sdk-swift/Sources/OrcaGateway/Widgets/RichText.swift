#if canImport(SwiftUI)
import SwiftUI

/// Flutter `RichText` as the builder makes it (PB:325-348): the raw widget,
/// not `Text.rich`, so no DefaultTextStyle, no ambient style and no text
/// scaling; start, softWrap, clip (FW widgets/basic.dart RichText). The
/// span tree becomes runs through `TextStyles.spans` (each span's style
/// merged onto its parent's: a styled child is upright unless italic,
/// decoration "none" clears the parent's line), drawn as one Text of an
/// AttributedString whose runs sit on the engine's defaults
/// (`TextStyleProps.engineRun`: 14 points, white). `textAlign` and the
/// width as a Text's; `maxLines` with overflow ellipsis truncates the last
/// line, any other overflow cuts the lines past it (LineCutLayout, as a
/// Text with maxLines). softWrap is never sent, so a RichText always wraps.
@MainActor
struct RichTextView: View {
    let node: ResolvedNode
    @Environment(\.orcaTight) private var tight
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let alignment = Props.textAlignment(node["textAlign"], direction: direction) ?? .leading
        lines(Text(Self.paragraph(node["text"])))
            .multilineTextAlignment(alignment)
            .frame(maxWidth: tight.contains(.horizontal) ? .infinity : nil,
                   alignment: Props.frameAlignment(alignment))
    }

    /// The runs of the span tree `root`, one after another.
    static func paragraph(_ root: JSONValue?) -> AttributedString {
        TextStyles.spans(root, base: nil).reduce(into: AttributedString()) { text, run in
            text += TextStyleProps(run.style).engineRun(run.text)
        }
    }

    @ViewBuilder
    private func lines(_ text: Text) -> some View {
        if let maxLines = node["maxLines"]?.intValue.flatMap({ $0 > 0 ? $0 : nil }) {
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
#endif
