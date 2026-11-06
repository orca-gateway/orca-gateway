#if canImport(SwiftUI)
import SwiftUI

/// Flutter `Text`. Where the parent forces the width (TightAxes: a
/// stretched Column, a Container that fills), the text spans it and
/// `textAlign` places the lines, as Flutter lays a Text out in a tight box.
@MainActor
struct TextNodeView: View {
    let node: ResolvedNode
    @Environment(\.orcaTight) private var tight

    var body: some View {
        let style = TextStyleProps(node["style"])
        let alignment = Props.textAlignment(node["textAlign"])
        let maxLines = node["maxLines"]?.intValue
        // SwiftUI truncates with an ellipsis whatever `overflow` says.
        style.apply(Text(Props.text(node["data"])))
            .multilineTextAlignment(alignment ?? .leading)
            .lineLimit(node["softWrap"]?.boolValue == false ? 1 : maxLines)
            .background(style.background)
            .frame(maxWidth: tight.contains(.horizontal) ? .infinity : nil,
                   alignment: Props.frameAlignment(alignment))
            .accessibilityLabel(node["semanticsLabel"]?.stringValue.map { Text($0) } ?? Text(Props.text(node["data"])))
    }
}

/// A line as thick as `thickness` (default 1, colour #E0E0E0), inset by
/// `indent` and `endIndent`; no extra vertical space, as the Flutter builder.
@MainActor
struct DividerView: View {
    let node: ResolvedNode

    var body: some View {
        Rectangle()
            .fill(Props.color(node["color"]) ?? Props.color(hex: "#E0E0E0"))
            .frame(height: Props.number(node["thickness"]) ?? 1)
            .frame(maxWidth: .infinity)
            .padding(.leading, Props.number(node["indent"]) ?? 0)
            .padding(.trailing, Props.number(node["endIndent"]) ?? 0)
    }
}

/// The frozen v1 FallbackPrompt, as the Flutter builder draws it: an accent
/// per severity (blocking red, warn orange, info blue), tinted background,
/// title, body, and a link-style button that opens `ctaUrl` through the URL
/// policy (http, https, mailto only), as `OrcaPageModel.openLink`.
@MainActor
struct FallbackPromptView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        let accent: Color = {
            switch node["severity"]?.stringValue {
            case "blocking": return Props.color(hex: "#D32F2F")
            case "warn": return Props.color(hex: "#F57C00")
            default: return Props.color(hex: "#1976D2")
            }
        }()
        VStack(alignment: .leading, spacing: 0) {
            Text(Props.text(node["title"]))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(accent)
            Text(Props.text(node["body"]))
                .font(.system(size: 14))
                .foregroundColor(Props.color(hex: "#333333"))
                .padding(.top, 8)
            if let label = node["ctaLabel"]?.stringValue, let rawURL = node["ctaUrl"]?.stringValue {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        model.openLink(rawURL) { openURL($0) }
                    } label: {
                        Text(label)
                            .font(.system(size: 14, weight: .semibold))
                            .underline()
                            .foregroundColor(accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(accent.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
#endif
