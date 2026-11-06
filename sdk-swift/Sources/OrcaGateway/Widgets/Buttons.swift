#if canImport(SwiftUI)
import SwiftUI

/// ElevatedButton, OutlinedButton and TextButton. A tap fires `onTap` and a
/// long press `onLongPress`; `enabled: false` disables both, as in Flutter.
/// The look is native: a prominent bordered button, an outlined one, and a
/// borderless one.
@MainActor
struct ButtonNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let enabled = node["enabled"]?.boolValue ?? true
        styled(
            Button {
                model.fire("onTap", on: node)
            } label: {
                label
            }
        )
        .disabled(!enabled)
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
                if enabled { model.fire("onLongPress", on: node) }
            },
            including: node.actions["onLongPress"] == nil ? .subviews : .all)
    }

    @ViewBuilder
    private var label: some View {
        if let first = node.childIds.first {
            NodeView(id: first, model: model)
        } else {
            Text("")
        }
    }

    @ViewBuilder
    private func styled<B: View>(_ button: B) -> some View {
        let radius = Props.number(node["borderRadius"])
        let padding = Props.insets(node["padding"])
        switch node.type {
        case "ElevatedButton":
            button
                .buttonStyle(.borderedProminent)
                .tint(Props.color(node["backgroundColor"]))
                .foregroundColor(Props.color(node["foregroundColor"]))
                .modifier(OptionalShape(radius: radius))
                .modifier(OptionalPadding(insets: padding))
        case "OutlinedButton":
            button.buttonStyle(OutlinedStyle(
                color: Props.color(node["color"]) ?? .accentColor,
                border: Props.color(node["borderColor"])))
        default:
            button
                .buttonStyle(.borderless)
                .foregroundColor(Props.color(node["color"]))
        }
    }
}

private struct OptionalShape: ViewModifier {
    let radius: CGFloat?

    func body(content: Content) -> some View {
        if let radius {
            content.clipShape(RoundedRectangle(cornerRadius: radius))
        } else {
            content
        }
    }
}

private struct OptionalPadding: ViewModifier {
    let insets: EdgeInsets?

    func body(content: Content) -> some View {
        if let insets {
            content.padding(insets)
        } else {
            content
        }
    }
}

/// A capsule outline, the Material outlined button on iOS.
private struct OutlinedStyle: ButtonStyle {
    let color: Color
    let border: Color?
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(color)
            .overlay(Capsule().stroke(border ?? color.opacity(0.5), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.38)
            .contentShape(Capsule())
    }
}
#endif
