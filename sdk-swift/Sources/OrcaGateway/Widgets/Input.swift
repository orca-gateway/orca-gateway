#if canImport(SwiftUI)
import SwiftUI

/// Flutter `TextField` (`_buildTextField`). The text lives in the field.
/// Each edit runs `setState` on `stateKey` when the node has one, then fires
/// `onChange` with `eventData: {value}`. When the page's value changes from
/// elsewhere (a reset, a server action), the field takes it without firing;
/// the value coming back from the field's own edits is ignored, since it
/// arrives after newer typing. A `readOnly` field takes focus and lets its
/// text be selected, but an edit is put back at once and sends nothing
/// (Flutter `readOnly`); SwiftUI has no switch for that, so the keyboard
/// still opens on iOS.
///
/// Without `decoration` the field is bare, as Flutter's EditableText path
/// (16 point text, grey placeholder). With one it draws the label above,
/// prefix and suffix, the border (`outline`, `underline`, the default, or
/// `none`), the fill, helper or error text below, and the `n/max` counter
/// when `maxLength` is set. `hintStyle`, `labelStyle`, `helperStyle`,
/// `errorStyle` and `isDense` apply only when sent; otherwise the field keeps
/// its native look (native-sdk gate 03). `enableSuggestions` has no SwiftUI
/// switch.
@MainActor
struct TextFieldNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @State private var text = ""
    @State private var loaded = false
    /// Set while the field takes the page's value, so that change is not
    /// sent back as an edit.
    @State private var pageText: String?
    /// Edits sent to the page whose echo has not come back yet. The page's
    /// value follows the typing a render later, so an echo is not a change
    /// from elsewhere and must not overwrite newer text.
    @State private var echoes: [String] = []
    @FocusState private var focused: Bool

    var body: some View {
        let value = pageValue
        decorated
            .onAppear {
                if !loaded {
                    loaded = true
                    if value != text { pageText = value; text = value }
                }
                if node["autofocus"]?.boolValue == true { focused = true }
            }
            .onChange(of: value) { new in
                if let index = echoes.firstIndex(of: new) {
                    echoes.removeFirst(index + 1)
                    return
                }
                guard new != text else { return }
                pageText = new
                text = new
            }
            .onChange(of: text) { new in
                if let page = pageText {
                    pageText = nil
                    if page == new { return }
                }
                if readOnly {
                    let page = pageValue
                    if new != page { pageText = page; text = page }
                    return
                }
                if let max = node["maxLength"]?.intValue, new.count > max {
                    text = String(new.prefix(max))
                    return
                }
                if model.textChanged(new, on: node) != nil {
                    echoes.append(new)
                    if echoes.count > 64 { echoes.removeFirst(echoes.count - 64) }
                }
            }
    }

    /// The page's value: the store at `stateKey`, else the resolved `value`.
    private var pageValue: String {
        if let key = node["stateKey"]?.stringValue {
            let stored = model.store.value(key)
            return stored.isNull ? "" : Props.text(stored)
        }
        return Props.text(node["value"])
    }

    // MARK: drawing

    private var decoration: [String: JSONValue]? {
        if case .object(let d)? = node["decoration"] { return d }
        return nil
    }

    private var placeholder: String {
        decoration?["hintText"]?.stringValue ?? node["placeholder"]?.stringValue ?? ""
    }

    private var readOnly: Bool {
        node["readOnly"]?.boolValue ?? false
    }

    /// The placeholder in grey (#9E9E9E) at the field's size, or in the
    /// decoration's `hintStyle` over that (a weight or family alone keeps the
    /// field's size).
    private var prompt: Text {
        var style = TextStyleProps(decoration?["hintStyle"])
        if style.color == nil { style.color = Props.color(hex: "#9E9E9E") }
        if style.size == nil, style.font != nil { style.size = TextStyleProps(node["style"]).size ?? 16 }
        return style.apply(Text(placeholder))
    }

    @ViewBuilder
    private var decorated: some View {
        if let decoration {
            DecoratedField(decoration: decoration, focused: focused, count: text.count,
                           maxLength: node["maxLength"]?.intValue) {
                field
            }
        } else {
            field
        }
    }

    private var field: some View {
        let style = TextStyleProps(node["style"])
        let enabled = node["enabled"]?.boolValue ?? true
        let maxLines = max(node["maxLines"]?.intValue ?? 1, 1)
        return Group {
            if node["obscureText"]?.boolValue == true {
                SecureField(text: $text, prompt: prompt) { Text(placeholder) }
            } else if maxLines > 1 {
                TextField(text: $text, prompt: prompt, axis: .vertical) { Text(placeholder) }
                    .lineLimit(maxLines, reservesSpace: true)
            } else {
                TextField(text: $text, prompt: prompt) { Text(placeholder) }
            }
        }
        .font(style.font ?? .system(size: 16))
        .foregroundColor(style.color ?? Props.color(hex: "#000000"))
        .focused($focused)
        .disabled(!enabled)
        .autocorrectionDisabled(node["autocorrect"]?.boolValue == false)
        .submitLabel(Self.submitLabel(node["textInputAction"]?.stringValue))
        #if os(iOS)
        .keyboardType(Self.keyboard(node["inputType"]?.stringValue))
        #endif
    }

    static func submitLabel(_ action: String?) -> SubmitLabel {
        switch action {
        case "done": return .done
        case "go": return .go
        case "next": return .next
        case "search": return .search
        case "send": return .send
        case "join": return .join
        case "route": return .route
        case "continueAction": return .continue
        default: return .return
        }
    }

    #if os(iOS)
    static func keyboard(_ type: String?) -> UIKeyboardType {
        switch type {
        case "number": return .numberPad
        case "email": return .emailAddress
        case "phone": return .phonePad
        case "url": return .URL
        default: return .default
        }
    }
    #endif
}

/// Flutter `InputDecoration` around a field (`parseInputDecoration`).
/// `isDense` takes 4 off the top and the bottom of the default content
/// padding, as Flutter's InputDecorator does for every border (here 12 to 8
/// for an outlined or filled field, 8 to 4 for an underlined one); a
/// `contentPadding` sent wins over both. Its sides are absolute (D4).
private struct DecoratedField<Field: View>: View {
    let decoration: [String: JSONValue]
    let focused: Bool
    let count: Int
    let maxLength: Int?
    @ViewBuilder let field: () -> Field

    var body: some View {
        let error = decoration["errorText"]?.stringValue
        let helper = decoration["helperText"]?.stringValue
        let border = decoration["border"]?.stringValue ?? "underline"
        let accent = error != nil ? Props.color(hex: "#D32F2F") : focused ? Color.accentColor
            : Props.color(hex: "#9E9E9E")
        let grey = Props.color(hex: "#666666")
        VStack(alignment: .leading, spacing: 4) {
            if let label = decoration["labelText"]?.stringValue {
                let style = TextStyleProps(decoration["labelStyle"])
                Text(label)
                    .font(style.font ?? .system(size: 12))
                    .foregroundColor(style.color ?? (error != nil ? accent : grey))
            }
            HStack(spacing: 4) {
                if let prefix = decoration["prefixText"]?.stringValue { Text(prefix).foregroundColor(grey) }
                field()
                if let suffix = decoration["suffixText"]?.stringValue { Text(suffix).foregroundColor(grey) }
            }
            .orcaPadding(decoration["contentPadding"], fallback: defaultPadding(border: border))
            .background {
                if decoration["filled"]?.boolValue == true {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Props.color(decoration["fillColor"]) ?? Props.color(hex: "#F5F5F5"))
                }
            }
            .overlay {
                switch border {
                case "outline":
                    RoundedRectangle(cornerRadius: 4).strokeBorder(accent, lineWidth: focused ? 2 : 1)
                case "none":
                    EmptyView()
                default:
                    VStack {
                        Spacer(minLength: 0)
                        Rectangle().fill(accent).frame(height: focused ? 2 : 1)
                    }
                }
            }
            if error != nil || helper != nil || maxLength != nil {
                HStack {
                    if let error {
                        supporting(error, style: "errorStyle", color: accent)
                    } else if let helper {
                        supporting(helper, style: "helperStyle", color: grey)
                    }
                    Spacer(minLength: 0)
                    if let maxLength {
                        Text("\(count)/\(maxLength)").foregroundColor(grey)
                    }
                }
                .font(.system(size: 12))
            }
        }
    }

    private func defaultPadding(border: String) -> EdgeInsets {
        let boxed = border == "outline" || decoration["filled"]?.boolValue == true
        let vertical: CGFloat = (boxed ? 12 : 8) - (decoration["isDense"]?.boolValue == true ? 4 : 0)
        return EdgeInsets(top: vertical, leading: boxed ? 12 : 0, bottom: vertical, trailing: boxed ? 12 : 0)
    }

    /// Helper or error text: 12 point in `color`, or the decoration's
    /// `style` over that (a weight or family alone keeps the 12 points).
    private func supporting(_ text: String, style key: String, color: Color) -> Text {
        var style = TextStyleProps(decoration[key])
        if style.color == nil { style.color = color }
        if style.size == nil, style.font != nil { style.size = 12 }
        return style.apply(Text(text))
    }
}
#endif
