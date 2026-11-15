#if canImport(SwiftUI)
import SwiftUI

/// ElevatedButton, OutlinedButton and TextButton. A tap fires `onTap` and a
/// long press `onLongPress`; `enabled: false` disables both, as in Flutter.
/// The look is native (native-sdk gate 03: platform idioms): a prominent
/// bordered button, an outlined one, and a borderless one, unless the host
/// set a style for the type in `OrcaTheme` and the server sent no style
/// props for this button. The props the server sends apply on top of the
/// native look, each only when sent (BB:29-91, 165-245):
/// - ElevatedButton `padding` is the content padding, around the label
///   inside the button, its sides absolute (D4). The system style's own
///   insets stay around it, so the button is larger than Flutter's by them
///   (a known difference).
/// - ElevatedButton `elevation` draws a shadow (`Elevation`). Without it
///   there is none: Flutter's default elevation 1 is a Material look.
/// - `splashColor` and `highlightColor` draw the button with `OverlayFace`.
/// Flutter's 64x40 minimum size is a Material default too, not applied.
/// `autofocus` asks for the focus once, when the button first appears, and
/// only while it is enabled (a disabled Flutter button cannot take the focus).
@MainActor
struct ButtonNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTheme) private var theme

    var body: some View {
        let enabled = node["enabled"]?.boolValue ?? true
        styled(
            Button {
                model.fire("onTap", on: node)
            } label: {
                label.modifier(ContentPadding(value: node.type == "ElevatedButton" ? node["padding"] : nil))
            }
        )
        .disabled(!enabled)
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
                if enabled { model.fire("onLongPress", on: node) }
            },
            including: node.actions["onLongPress"] == nil ? .subviews : .all)
        .modifier(Autofocus(active: enabled && node["autofocus"]?.boolValue == true))
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
        if let host = theme.buttonStyle(for: node) {
            button.buttonStyle(host)
        } else {
            native(button)
        }
    }

    @ViewBuilder
    private func native<B: View>(_ button: B) -> some View {
        switch (node.type, OverlayFace(node)) {
        case ("ElevatedButton", nil):
            button.buttonStyle(.borderedProminent).modifier(ElevatedProps(node: node))
        case ("ElevatedButton", let face?):
            button.buttonStyle(face).modifier(ElevatedProps(node: node))
        case (_, let face?):
            button.buttonStyle(face)
        case ("OutlinedButton", nil):
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

/// ElevatedButton's props over its style: `backgroundColor` is the tint it
/// is filled with, `foregroundColor` the label's, `borderRadius` clips it,
/// `elevation` casts its shadow.
private struct ElevatedProps: ViewModifier {
    let node: ResolvedNode

    func body(content: Content) -> some View {
        content
            .tint(Props.color(node["backgroundColor"]))
            .foregroundColor(Props.color(node["foregroundColor"]))
            .modifier(OptionalShape(radius: Props.number(node["borderRadius"])))
            .modifier(Elevation(value: Props.number(node["elevation"])))
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

/// ElevatedButton `padding`: around the label, inside the button, its sides
/// absolute (D4); nothing when it is not sent.
private struct ContentPadding: ViewModifier {
    let value: JSONValue?

    func body(content: Content) -> some View {
        if let value {
            content.orcaPadding(value)
        } else {
            content
        }
    }
}

/// ElevatedButton `elevation`: a shadow under the button, as Card's (y
/// offset half the elevation, radius the elevation), none while disabled
/// (Flutter M3: elevation 0). It is cast by the whole button flattened, so
/// the label casts none of its own onto the fill.
private struct Elevation: ViewModifier {
    let value: CGFloat?
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        if let value, value > 0 {
            content
                .compositingGroup()
                .shadow(color: enabled ? Color.black.opacity(0.18) : .clear, radius: value, x: 0, y: value / 2)
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

/// `splashColor` and `highlightColor` (Flutter `_applyOverlay`): a pressed
/// button lays its splash colour over its fill, a hovered one its highlight
/// colour, each standing in for the other. No system button style takes an
/// overlay, so an enabled button that sends either is drawn by this face, a
/// copy of the look it replaces: ElevatedButton `.borderedProminent` (the
/// system's insets around the label and its shape filled with the tint, a
/// white label), OutlinedButton `OutlinedStyle`, TextButton
/// `.borderless` (the bare label in the tint). The overlay lies between the
/// fill and the label, in the button's shape (a TextButton's: a capsule
/// around its label), and takes the place of the system's pressed dimming.
/// Hovering needs a pointer (a Mac, an iPad with a trackpad); touch never
/// hovers. A disabled button draws no overlay, so it keeps the system style.
struct OverlayFace: ButtonStyle {
    let shape: AnyShape
    let insets: EdgeInsets
    let filled: Bool
    let foreground: AnyShapeStyle
    let border: Color?
    let splash: Color?
    let highlight: Color?

    /// `.borderedProminent`'s insets around the label at the regular control
    /// size, as the system draws them.
    #if os(macOS)
    static let prominentInsets = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    #else
    static let prominentInsets = EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
    #endif

    /// `.borderedProminent`'s shape at the regular control size: a rounded
    /// rectangle with 6-point continuous corners. Measured with Xcode 27.2
    /// (ButtonTests `testD11AnOverlayFaceKeepsTheNativeLook`): on the iOS
    /// 18.5 simulator the system draws exactly this, pixel for pixel; on
    /// macOS 27.2 its corner is a little tighter (between 5.5 and 6 points,
    /// the edge pixels' coverage differs), the same shape 2 points in. Other
    /// OS versions are unverified; one that draws the button in another
    /// shape (a capsule, say) fails that test.
    static let prominentShape = RoundedRectangle(cornerRadius: 6, style: .continuous)

    /// The face of an enabled button node that sends splashColor or
    /// highlightColor; nil for any other.
    init?(_ node: ResolvedNode) {
        splash = Props.color(node["splashColor"])
        highlight = Props.color(node["highlightColor"])
        guard splash != nil || highlight != nil, node["enabled"]?.boolValue ?? true else { return nil }
        switch node.type {
        case "ElevatedButton":
            shape = AnyShape(Self.prominentShape)
            insets = Self.prominentInsets
            filled = true
            foreground = AnyShapeStyle(Props.color(node["foregroundColor"]) ?? .white)
            border = nil
        case "OutlinedButton":
            let color = Props.color(node["color"]) ?? .accentColor
            shape = AnyShape(Capsule())
            insets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            filled = false
            foreground = AnyShapeStyle(color)
            border = Props.color(node["borderColor"]) ?? color.opacity(0.5)
        default:
            shape = AnyShape(Capsule())
            insets = EdgeInsets()
            filled = false
            foreground = Props.color(node["color"]).map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint)
            border = nil
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        HoverTracking { hovered in
            face(configuration.label, pressed: configuration.isPressed, hovered: hovered)
        }
    }

    /// The face around `label`, pressed and hovered as given.
    func face<Label: View>(_ label: Label, pressed: Bool, hovered: Bool) -> some View {
        let overlay = pressed ? splash ?? highlight : hovered ? highlight ?? splash : nil
        return label
            .padding(insets)
            .foregroundStyle(foreground)
            .background {
                if filled { shape.fill(.tint) }
                if let overlay { shape.fill(overlay) }
            }
            .overlay {
                if let border { shape.stroke(border, lineWidth: 1) }
            }
            .contentShape(shape)
    }
}

private struct HoverTracking<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content
    @State private var hovered = false

    var body: some View {
        content(hovered).onHover { hovered = $0 }
    }
}

/// Flutter `autofocus`: the focus is asked for once, when the view first
/// appears. A SwiftUI button takes the focus only once it is `focusable`,
/// iOS 17 and macOS 14 and later; before that this does nothing. On a phone
/// without a keyboard nothing shows it, as in Flutter, whose focus highlight
/// is off under touch.
private struct Autofocus: ViewModifier {
    let active: Bool
    @FocusState private var focused: Bool
    @State private var asked = false

    func body(content: Content) -> some View {
        if active, #available(iOS 17, macOS 14, *) {
            content
                .focusable(true, interactions: .activate)
                .focused($focused)
                .onAppear {
                    guard !asked else { return }
                    asked = true
                    focused = true
                }
        } else {
            content
        }
    }
}
#endif
