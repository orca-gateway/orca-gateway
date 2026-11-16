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

// MARK: - IconButton and FloatingActionButton

/// The gestures of Flutter's GestureDetector around a button, each attached
/// only when given: a tap and a long press. With both, a touch is one or the
/// other, never both: SwiftUI lets one of the two gestures on a view win,
/// the long press once held `longPressDuration`, else the tap on release.
/// With neither nothing is attached.
struct PressGestures: ViewModifier {
    /// A gesture's action: it fires the node's trigger and returns the run
    /// (`OrcaPageModel.fire`), nil when the node has no action for it.
    typealias Fire = @MainActor () -> Task<Void, Never>?

    /// Flutter's kLongPressTimeout, 500 ms (gestures/constants.dart:29).
    /// SwiftUI's LongPressGesture waits the same 0.5 s by default (its
    /// `minimumDuration`, iOS and macOS SDK 27.2); it is set here so it
    /// stays Flutter's.
    static let longPressDuration: Double = 0.5

    /// A gesture firing `trigger` on `node` when the button `takes` it;
    /// nil, no gesture, otherwise.
    static func fire(_ trigger: String, on node: ResolvedNode, in model: OrcaPageModel, when takes: Bool) -> Fire? {
        guard takes else { return nil }
        return { model.fire(trigger, on: node) }
    }

    let tap: Fire?
    let longPress: Fire?

    func body(content: Content) -> some View {
        switch (tap, longPress) {
        case let (tap?, longPress?):
            content
                .onTapGesture { _ = tap() }
                .onLongPressGesture(minimumDuration: Self.longPressDuration) { _ = longPress() }
        case let (tap?, nil):
            content.onTapGesture { _ = tap() }
        case let (nil, longPress?):
            content.onLongPressGesture(minimumDuration: Self.longPressDuration) { _ = longPress() }
        case (nil, nil):
            content
        }
    }
}

/// `tooltip`, unless empty, as the accessibility label: iOS has no tooltip
/// to show (Flutter adds no Tooltip for an empty one).
private struct TooltipLabel: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text, !text.isEmpty {
            content.accessibilityElement(children: .combine).accessibilityLabel(Text(text))
        } else {
            content
        }
    }
}

/// Flutter `IconButton` as its builder (`_buildIconButton`,
/// button_builders.dart:93-163) draws it, not a system button: a
/// (`size` + 16) square, `size` 24 by default, holding the child (an empty
/// `size` square without one) centred, or with `padding` (its sides
/// absolute) aligned by `alignment` (center by default; `topLeft` stays
/// left in right-to-left, as Flutter's Alignment) inside it. `color`, only
/// when set, tints the child (Flutter's IconTheme; here the foreground
/// colour, so unlike Flutter it also colours a Text child without its own
/// colour); an Icon child keeps its own size, so `size` grows only the box.
/// Disabled it is drawn at opacity 0.38. It takes touches only when enabled
/// and given `onTap` or `onLongPress`, and then over its whole box
/// (Flutter's opaque GestureDetector, only the triggers it has); otherwise
/// it attaches no gesture, so the views around it get them. A long press
/// waits Flutter's 500 ms (`PressGestures`). `constraints` bound the box
/// from outside (Flutter's ConstrainedBox: the box's side clamped into
/// them). `tooltip` is its accessibility label: iOS has no tooltip. No
/// press feedback, as Flutter draws none (`splashColor` and
/// `highlightColor` are never read).
@MainActor
struct IconButtonNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    /// What a tap on the button fires; nil when it takes no tap.
    let tap: PressGestures.Fire?
    /// What a long press on the button fires; nil when it takes none.
    let longPress: PressGestures.Fire?
    @Environment(\.layoutDirection) private var direction

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        let enabled = node["enabled"]?.boolValue ?? true
        tap = PressGestures.fire("onTap", on: node, in: model, when: enabled && node.actions["onTap"] != nil)
        longPress = PressGestures.fire("onLongPress", on: node, in: model,
                                       when: enabled && node.actions["onLongPress"] != nil)
    }

    var body: some View {
        let size = Props.number(node["size"]) ?? 24
        placed(child(size).modifier(OptionalForeground(color: Props.color(node["color"]))))
            .frame(width: side(size, "minWidth", "maxWidth"), height: side(size, "minHeight", "maxHeight"))
            .opacity(node["enabled"]?.boolValue ?? true ? 1 : 0.38)
            .modifier(WholeBox(active: tap != nil || longPress != nil))
            .modifier(PressGestures(tap: tap, longPress: longPress))
            .accessibilityAddTraits(tap != nil ? .isButton : [])
            .modifier(TooltipLabel(text: node["tooltip"]?.stringValue))
    }

    /// The box's side on one axis: `size` + 16 clamped into `constraints`
    /// (Flutter's BoxConstraints.enforce of the SizedBox inside them).
    private func side(_ size: CGFloat, _ min: String, _ max: String) -> CGFloat {
        let bounds = node["constraints"]?.objectValue
        return Swift.min(Swift.max(size + 16, Props.number(bounds?[min]) ?? 0), Props.number(bounds?[max]) ?? .infinity)
    }

    @ViewBuilder
    private func child(_ size: CGFloat) -> some View {
        if node.childIds.isEmpty {
            Color.clear.frame(width: size, height: size)
        } else {
            ChildView(node: node, model: model)
        }
    }

    /// Centred, or with `padding` at `alignment` inside it.
    @ViewBuilder
    private func placed<V: View>(_ child: V) -> some View {
        if node["padding"] != nil {
            child
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .orcaPadding(node["padding"])
        } else {
            child.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Flutter's `parseAlignment` is absolute: mirrored here in
    /// right-to-left, where SwiftUI mirrors it back.
    private var alignment: Alignment {
        let alignment = Props.alignment(node["alignment"])
        guard direction == .rightToLeft else { return alignment }
        switch alignment.horizontal {
        case .leading: return Alignment(horizontal: .trailing, vertical: alignment.vertical)
        case .trailing: return Alignment(horizontal: .leading, vertical: alignment.vertical)
        default: return alignment
        }
    }
}

/// Flutter `FloatingActionButton` (`_buildFAB`, button_builders.dart:193-223)
/// in Flutter's Material 3 look under `ThemeData()` (decision fab-shape;
/// fab_defaults_m3.g.dart), not a circle: a 56 pt square with 16 pt corners,
/// or with `mini` a 40 pt one with 12 pt corners in the middle of Flutter's
/// padded 48 pt tap target (MaterialTapTargetSize.padded on iOS,
/// theme_data.dart:479-485), filled with `backgroundColor` (#EADDFF,
/// primaryContainer, without one), its child in #4F378B
/// (onPrimaryContainer; a child's own colour wins), with a shadow, as
/// Card's, for `elevation` (6 without one). Enabled it takes a tap, firing
/// `onTap`, even with no onTap (Flutter passes onPressed whenever enabled),
/// and a long press, firing `onLongPress` (Flutter's GestureDetector around
/// it takes every long press, so one is never a tap), after Flutter's
/// 500 ms (`PressGestures`). Disabled it is drawn unchanged (Flutter's
/// disabled elevation falls back to `elevation`,
/// floating_action_button.dart:538-542) and attaches no gesture, so the
/// views around it get the tap; its fill (a mini's whole target) still
/// takes the touch from the views behind, as Flutter's Material does.
/// `tooltip` is its accessibility label (iOS has no tooltip). No ripple and
/// no press feedback on iOS: `splashColor`, `focusColor` and `hoverColor`
/// have no counterpart and are not read; nor are `heroTag` (no Hero) and
/// `isExtended` (no effect on Flutter's default FAB). The Scaffold's
/// `floatingActionButton` slot places it bottom-trailing, 16 in from the
/// safe area or the bars below (ScaffoldView), as Flutter's endFloat.
@MainActor
struct FloatingActionButtonNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    /// What a tap on the button fires; nil when it takes no tap.
    let tap: PressGestures.Fire?
    /// What a long press on the button fires; nil when it takes none.
    let longPress: PressGestures.Fire?

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        let enabled = node["enabled"]?.boolValue ?? true
        tap = PressGestures.fire("onTap", on: node, in: model, when: enabled)
        longPress = PressGestures.fire("onLongPress", on: node, in: model, when: enabled)
    }

    var body: some View {
        let mini = node["mini"]?.boolValue ?? false
        let side: CGFloat = mini ? 40 : 56
        let shape = RoundedRectangle(cornerRadius: mini ? 12 : 16)
        let elevation = Props.number(node["elevation"]) ?? 6
        ChildView(node: node, model: model)
            .foregroundColor(Props.color(hex: "#4F378B"))
            .frame(width: side, height: side)
            .background {
                shape
                    .fill(Props.color(node["backgroundColor"]) ?? Props.color(hex: "#EADDFF"))
                    .shadow(color: Color.black.opacity(elevation > 0 ? 0.18 : 0), radius: elevation, x: 0,
                            y: elevation / 2)
            }
            .modifier(TapTarget(padded: mini))
            .modifier(PressGestures(tap: tap, longPress: longPress))
            .accessibilityAddTraits(.isButton)
            .modifier(TooltipLabel(text: node["tooltip"]?.stringValue))
    }
}

/// A live IconButton's whole box takes touches, its empty corners too, so
/// neither SwiftUI gestures nor UIKit views behind get them (Flutter's
/// HitTestBehavior.opaque); an inert one leaves its box as its child draws it.
private struct WholeBox: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content
                .background { Rectangle().hitFill() }
                .contentShape(Rectangle())
        } else {
            content
        }
    }
}

/// Flutter's padded tap target: a mini FAB's 48 pt square around its 40,
/// all of which takes touches (RawMaterialButton's input padding hands a
/// hit there to the button).
private struct TapTarget: ViewModifier {
    let padded: Bool

    func body(content: Content) -> some View {
        if padded {
            content
                .frame(width: 48, height: 48)
                .background { Rectangle().hitFill() }
                .contentShape(Rectangle())
        } else {
            content
        }
    }
}
#endif
