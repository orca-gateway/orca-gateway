#if canImport(SwiftUI)
import SwiftUI

/// Flutter `_buildBottomSheet` (structure_builders.dart:235-249): a
/// Container, padding 16 on each side, `backgroundColor` (default white),
/// its top corners rounded `borderRadius` (default 16), holding its child or
/// nothing (then it is the padding alone, 32x32). No Material, elevation or
/// drag, and `dismissible` is not read: it draws inline wherever it stands.
/// In a Scaffold's `bottomSheet` slot the Scaffold lays it on the sheet
/// surface (`ScaffoldBottomSheet`). A forced axis fills, as a Container's.
@MainActor
struct BottomSheetNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        let radius = Props.number(node["borderRadius"]) ?? 16
        Group {
            if node.childIds.isEmpty {
                Color.clear.frame(width: 0, height: 0)
            } else {
                ChildView(node: node, model: model)
            }
        }
        .padding(16)
        .frame(maxWidth: tight.contains(.horizontal) ? .infinity : nil,
               maxHeight: tight.contains(.vertical) ? .infinity : nil, alignment: .topLeading)
        .background(CornersShape(radii: CornerRadii(topLeft: radius, topRight: radius))
            .fill(Props.color(node["backgroundColor"]) ?? Color.white))
    }
}

/// Flutter `_buildSnackBar` (structure_builders.dart:429-465): a static
/// Container, `backgroundColor` (default #323232), corners of 4, padding 16
/// x 12, holding a Row: the `content` in an Expanded and, when
/// `actionLabel` is not empty, an 8 gap and the label, laid out at its own
/// width (a Row's non-flex child), so the content shrinks for it. Both are
/// Flutter Texts: drawn by `TextNodeView`, so an enclosing DefaultTextStyle
/// is layered under them as under any Text (`TextStyles.layer`: its style,
/// maxLines, overflow and textAlign), with the SnackBar's own TextStyles on
/// top: white 14, the label #BB86FC 14 w600. Those set no fontStyle, so a
/// DTS's italic stays (Flutter's TextStyle.merge keeps a null field's
/// parent value). The label's GestureDetector is a Button here, with no
/// pressed look: a tap and VoiceOver's activation both fire `onAction`.
/// `duration` is never read: no timer, no animation. As Flutter's Expanded
/// it takes all the width it is offered.
@MainActor
struct SnackBarNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaDefaultTextStyle) private var defaultStyle

    /// The label's text, nil when absent or empty (Flutter reads it as a String).
    private var actionLabel: String? {
        guard let label = node["actionLabel"]?.stringValue, !label.isEmpty else { return nil }
        return label
    }

    /// What a tap on the label runs (its GestureDetector is there whenever
    /// the label is, with or without an `onAction`); nil with no label.
    var labelTap: (() -> Task<Void, Never>?)? {
        guard actionLabel != nil else { return nil }
        let node = node, model = model
        return { model.fire("onAction", on: node) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            TextNodeView(node: text(Props.text(node["content"]), ["color": "#FFFFFF", "fontSize": 14]))
                // Expanded: a forced width.
                .environment(\.orcaTight, [.horizontal])
            if let actionLabel, let labelTap {
                Color.clear.frame(width: 8, height: 0)
                Button {
                    _ = labelTap()
                } label: {
                    TextNodeView(node: text(actionLabel, ["color": "#BB86FC", "fontSize": 14, "fontWeight": "w600"]))
                        .environment(\.orcaTight, [])
                        .fixedSize(horizontal: true, vertical: false)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NoPressedLook())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 4).fill(Props.color(node["backgroundColor"]) ?? Props.color(hex: "#323232")))
    }

    /// A Text node of `data` in the SnackBar's own `style`, plus the DTS's
    /// italic, which a style with no fontStyle keeps.
    private func text(_ data: String, _ style: [String: JSONValue]) -> ResolvedNode {
        var style = style
        if defaultStyle?.style?["fontStyle"] == "italic" { style["fontStyle"] = "italic" }
        var text = node
        text.props = ["data": .string(data), "style": .object(style)]
        return text
    }
}

/// A button drawn as its label alone, pressed or not (Flutter's
/// GestureDetector shows nothing).
private struct NoPressedLook: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// Flutter `_buildDialog` (structure_builders.dart:229-233): a Dialog draws
/// nothing where it stands (SizedBox.shrink); its children are shown only by
/// the `openDialog` action. A view of its own, not EmptyView, so the
/// registry's switch is seen to draw the type.
@MainActor
struct DialogNodeView: View {
    var body: some View {
        Color.clear.frame(width: 0, height: 0).accessibilityHidden(true)
    }
}
#endif
