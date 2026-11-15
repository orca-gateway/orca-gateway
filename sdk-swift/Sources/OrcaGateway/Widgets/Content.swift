#if canImport(SwiftUI)
import SwiftUI

/// Flutter `Text` (PB:30-48). Where the parent forces the width (TightAxes:
/// a stretched Column, a Container that fills), the text spans it and
/// `textAlign` places the lines, as Flutter lays a Text out in a tight box.
/// `overflow` (else `style.overflow`, else clip) as Flutter: on one line
/// (`softWrap` false) clip cuts at the box edge, fade fades the last
/// ellipsis-width, ellipsis truncates, visible paints past the box; with
/// `maxLines` clip, fade and visible stop after that many lines with no
/// ellipsis. TextKit.swift holds the parts SwiftUI's Text lacks.
@MainActor
struct TextNodeView: View {
    let node: ResolvedNode
    @Environment(\.orcaTight) private var tight
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let style = TextStyleProps(node["style"])
        let alignment = Props.textAlignment(node["textAlign"], direction: direction)
        lineBox(style)
            .multilineTextAlignment(alignment ?? .leading)
            .background(style.background)
            .frame(maxWidth: tight.contains(.horizontal) ? .infinity : nil,
                   alignment: Props.frameAlignment(alignment))
            .accessibilityLabel(node["semanticsLabel"]?.stringValue.map { Text($0) } ?? Text(Props.text(node["data"])))
    }

    /// Flutter `height` (TextKit `extraLeading`): the room between lines,
    /// and half of it above the first and below the last. Without `height`
    /// the lines alone, no modifier added.
    @ViewBuilder
    private func lineBox(_ style: TextStyleProps) -> some View {
        if style.height != nil {
            let extra = style.extraLeading
            lines(style, lineSpacing: max(extra, 0))
                .lineSpacing(max(extra, 0))
                .padding(.vertical, extra / 2)
        } else {
            lines(style, lineSpacing: 0)
        }
    }

    @ViewBuilder
    private func lines(_ style: TextStyleProps, lineSpacing: CGFloat) -> some View {
        let data = Props.text(node["data"])
        let maxLines = node["maxLines"]?.intValue.flatMap { $0 > 0 ? $0 : nil }
        let oneLine = node["softWrap"]?.boolValue == false
        #if canImport(UIKit)
        if node["textAlign"]?.stringValue == "justify" {
            JustifiedText(style: style, data: data, lines: oneLine ? 1 : maxLines ?? 0,
                          ellipsis: overflow(style) == "ellipsis", lineSpacing: lineSpacing)
        } else {
            wrapped(style.styledText(data), style: style, maxLines: maxLines, oneLine: oneLine)
        }
        #else
        wrapped(style.styledText(data), style: style, maxLines: maxLines, oneLine: oneLine)
        #endif
    }

    /// `overflow`, else `style.overflow`, else Flutter's default clip.
    private func overflow(_ style: TextStyleProps) -> String {
        node["overflow"]?.stringValue ?? style.overflow ?? "clip"
    }

    @ViewBuilder
    private func wrapped(_ text: some View, style: TextStyleProps, maxLines: Int?, oneLine: Bool) -> some View {
        if oneLine {
            switch overflow(style) {
            case "ellipsis":
                text.lineLimit(1)
            case "visible":
                OneLineLayout { text }
            case "fade":
                ViewThatFits(in: .horizontal) {
                    text
                    OneLineLayout { text }.clipped().mask { FadeMask(width: style.ellipsisWidth) }
                }
            default:
                OneLineLayout { text }.clipped()
            }
        } else if let maxLines {
            if overflow(style) == "ellipsis" {
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

/// UnsupportedWidgetPlaceholder, as the Flutter builder draws it: the grey
/// "known widget that cannot run here" card, kept apart from FallbackPrompt's
/// "unknown widget". `iconName` (the Icon widget's names, `IconNames`) and
/// the title (`displayName`, else `widgetType`) on one line, `reason` (else
/// Flutter's default) under it, and "Learn more" when `docsUrl` is set, which
/// opens it through the URL policy as FallbackPrompt's link does. As wide as
/// its content, or the width a parent forces (TightAxes), as a Container.
@MainActor
struct UnsupportedWidgetPlaceholderView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.openURL) private var openURL

    static let defaultReason = "This widget runs in the compiled mobile app and cannot preview here."

    var body: some View {
        let accent = Props.color(hex: "#6B7280")
        let displayName = node["displayName"]?.stringValue ?? ""
        let docsUrl = node["docsUrl"]?.stringValue ?? ""
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let iconName = node["iconName"]?.stringValue {
                    // A Material glyph fills about 20 of its 24 points, as IconNodeView.
                    Image(systemName: IconNames.symbol(for: iconName))
                        .font(.system(size: 20 * 0.83))
                        .rotationEffect(.degrees(IconNames.isRotated(iconName) ? 90 : 0))
                        .frame(width: 20, height: 20)
                        .foregroundColor(accent)
                }
                Text(displayName.isEmpty ? Props.text(node["widgetType"]) : displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Props.color(hex: "#374151"))
                    .lineLimit(1)
            }
            Text(node["reason"]?.stringValue ?? Self.defaultReason)
                .font(.system(size: 13))
                .foregroundColor(accent)
                .padding(.top, 6)
            if !docsUrl.isEmpty {
                Button {
                    model.openLink(docsUrl) { openURL($0) }
                } label: {
                    Text("Learn more")
                        .font(.system(size: 13, weight: .semibold))
                        .underline()
                        .foregroundColor(Props.color(hex: "#2563EB"))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .modifier(FillsForcedWidth())
        // The 16-point padding plus the border's 1-point width: Flutter's
        // Container adds the border's width to its padding, as ContainerView's
        // borderInset.
        .padding(16 + 1)
        .background(accent.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(accent.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Spans the width when the parent forces it (TightAxes), else as wide as
/// the content.
private struct FillsForcedWidth: ViewModifier {
    @Environment(\.orcaTight) private var tight

    func body(content: Content) -> some View {
        content.frame(maxWidth: tight.contains(.horizontal) ? .infinity : nil, alignment: .leading)
    }
}
#endif
