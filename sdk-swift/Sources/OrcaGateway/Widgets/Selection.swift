#if canImport(SwiftUI)
import os
import SwiftUI

/// Flutter `_buildCheckbox` (input_builders.dart:196-244), drawn as an iOS
/// tick box (design D6). The value drawn is the store's at `stateKey` when
/// the node has one, else the `value` prop, read when the view is built
/// (Flutter's build), with no state of the view's own: the box changes when
/// the node redraws, through its watches (D4), and a tap starts from what
/// is drawn, not from the store at tap time (Toggleable sends the next of
/// its built value, input_builders.dart:224, :236). A
/// two-state box draws a missing value as false; a tristate one draws it
/// dashed. A state that is not a bool, where Flutter throws, draws the prop
/// and is logged once. A tap writes `FormControls.checkboxNext` through
/// `valueChanged` (the stateKey in page scope, then onChange {value}); a
/// disabled box takes the touch and does nothing with it.
///
/// Without a label it is Flutter's padded Checkbox: an 18 pt box in the
/// middle of a 48 pt target, all of which takes touches, so UIKit views
/// behind get none (`Shape.hitFill`; checkbox.dart:438, :551-556). With one
/// it is CheckboxListTile with the box leading (input_builders.dart:233-243):
/// a row the whole width and at least 56 high that takes touches anywhere,
/// 16 before the box's 40 pt target, 16 from it to the title, 24 after
/// (list_tile.dart:1505, the M3 tile defaults); the title 16 pt in
/// #1D1B20 (M3 bodyLarge, onSurface), black at 0.38 when disabled. The box
/// is SF Symbols square, checkmark.square.fill or minus.square.fill: filled
/// in activeColor, else the accent, with a white mark (with no activeColor
/// the iOS accent, where Flutter's tile takes ThemeData()'s primary #6750A4:
/// the iOS look, D6); empty in Flutter's
/// #49454F (onSurfaceVariant); disabled all in #1D1B20 at 0.38 with a
/// #FEF7FF mark, activeColor ignored as Flutter ignores it (checkbox.dart:
/// 483-493). focusColor and hoverColor have no touch-screen state; Flutter
/// reads no inactiveColor.
@MainActor
struct CheckboxNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    /// What the box shows (Flutter: `tristate ? value : (value ?? false)`),
    /// read when the view is built.
    let shown: Bool?

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        shown = Self.drawn(node, model)
    }

    var body: some View {
        let label = Props.text(node["label"])
        if label.isEmpty {
            box
                .frame(width: 48, height: 48)
                .background { Rectangle().hitFill() }
                .contentShape(Rectangle())
                .onTapGesture { tap() }
                .accessibilityAddTraits(traits)
        } else {
            HStack(spacing: 16) {
                box.frame(width: 40, height: 40)
                Text(label)
                    .font(.system(size: 16))
                    .tracking(0.5)
                    .foregroundColor(enabled ? Props.color(hex: "#1D1B20") : Color.black.opacity(0.38))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 16)
            .padding(.trailing, 24)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background { Rectangle().hitFill() }
            .contentShape(Rectangle())
            .onTapGesture { tap() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(traits)
        }
    }

    /// A button, selected while ticked or dashed.
    private var traits: AccessibilityTraits {
        shown == false ? .isButton : [.isButton, .isSelected]
    }

    /// The box, 18 pt.
    private var box: some View {
        let value = shown
        let fill = enabled ? Props.color(node["activeColor"]) ?? .accentColor : Self.disabled
        return Group {
            if value == false {
                Image(systemName: Self.symbol(for: value))
                    .resizable()
                    .foregroundColor(enabled ? Props.color(hex: "#49454F") : Self.disabled)
            } else {
                Image(systemName: Self.symbol(for: value))
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(enabled ? Color.white : Props.color(hex: "#FEF7FF"), fill)
            }
        }
        .frame(width: 18, height: 18)
    }

    private var enabled: Bool { node["enabled"]?.boolValue ?? true }
    private var tristate: Bool { node["tristate"]?.boolValue ?? false }

    /// The value a box built now shows: the store's at `stateKey`, else the
    /// prop; a missing one false unless tristate.
    private static func drawn(_ node: ResolvedNode, _ model: OrcaPageModel) -> Bool? {
        var value = node["value"]?.boolValue
        if let key = node["stateKey"]?.stringValue {
            switch model.store.value(key) {
            case .bool(let stored): value = stored
            case .null: value = nil
            case let other: notABool(other, at: key, on: node, in: model)
            }
        }
        return node["tristate"]?.boolValue == true ? value : (value ?? false)
    }

    /// The SF Symbol the box is drawn with.
    var symbol: String { Self.symbol(for: shown) }

    static func symbol(for value: Bool?) -> String {
        switch value {
        case true?: return "checkmark.square.fill"
        case false?: return "square"
        case nil: return "minus.square.fill"
        }
    }

    /// A tap on the box or the row: the next of the value drawn, written and
    /// sent; nil when disabled or when the node has neither a stateKey nor
    /// onChange.
    @discardableResult
    func tap() -> Task<Void, Never>? {
        guard enabled else { return nil }
        let next = FormControls.checkboxNext(value: shown, tristate: tristate)
        return model.valueChanged(next.map(JSONValue.bool) ?? .null, on: node)
    }

    private static let disabled = Props.color(hex: "#1D1B20").opacity(0.38)
    private static let logger = Logger(subsystem: "com.orcagateway", category: "Checkbox")
    /// The Checkboxes already logged for a state that is not a bool, by
    /// page and node.
    private static var logged: Set<String> = []

    private static func notABool(_ value: JSONValue, at key: String, on node: ResolvedNode, in model: OrcaPageModel) {
        guard logged.insert("\(model.page.pageId)/\(node.id)").inserted else { return }
        logger.warning("""
            Checkbox \(node.id, privacy: .public): state \(key, privacy: .public) is \
            \(String(describing: value), privacy: .public), not a bool (Flutter throws); its value prop is drawn
            """)
    }
}

/// Flutter `_buildRadio` (input_builders.dart:139-194), Flutter's own look
/// rather than a Material Radio (design D6): a 20 pt circle with a 2 pt
/// ring, and when selected a 10 pt dot in the middle, both in activeColor ??
/// #2196F3; unselected, the ring in inactiveColor ?? #757575, or #BDBDBD
/// when disabled; a selected disabled one looks enabled. These shapes, not
/// SF Symbols' circle and record.circle, whose ring and dot are not
/// Flutter's sizes. Only the circle takes touches, as Flutter's circle
/// decoration hit-tests. Selected iff its value and the group are the same
/// string (`FormControls.radioSelected`): the value prop as Flutter's
/// `resolveStringValue`, the group the store's at `stateKey` as a string
/// when the node has one, else the groupValue prop, read when the view is
/// built. A tap, only when built enabled and unselected (Flutter's onTap
/// exists only then, :153), writes the radio's value through
/// `valueChanged`.
/// focusColor and hoverColor are never read.
@MainActor
struct RadioNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    /// Whether the radio is drawn selected, read when the view is built.
    let isSelected: Bool

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        isSelected = FormControls.radioSelected(value: Props.text(node["value"]), group: Self.group(node, model))
    }

    var body: some View {
        let selected = isSelected
        let active = Props.color(node["activeColor"]) ?? Props.color(hex: "#2196F3")
        let ring = selected ? active
            : enabled ? Props.color(node["inactiveColor"]) ?? Props.color(hex: "#757575") : Props.color(hex: "#BDBDBD")
        Circle()
            .strokeBorder(ring, lineWidth: 2)
            .overlay {
                if selected { Circle().fill(active).frame(width: 10, height: 10) }
            }
            .frame(width: 20, height: 20)
            .background { Circle().hitFill() }
            .contentShape(Circle())
            .onTapGesture { tap() }
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var enabled: Bool { node["enabled"]?.boolValue ?? true }
    private var value: String { Props.text(node["value"]) }

    /// The group's value: the store's at `stateKey` (Dart `toString()`, ""
    /// when unset), else the groupValue prop.
    private static func group(_ node: ResolvedNode, _ model: OrcaPageModel) -> String {
        if let key = node["stateKey"]?.stringValue {
            let stored = model.store.value(key)
            return stored.isNull ? "" : Props.text(stored)
        }
        return Props.text(node["groupValue"])
    }

    /// A tap: the radio's value, written and sent; nil when disabled, when
    /// drawn selected, or when the node has neither a stateKey nor onChange.
    @discardableResult
    func tap() -> Task<Void, Never>? {
        guard enabled, !isSelected else { return nil }
        return model.valueChanged(.string(value), on: node)
    }
}
#endif
