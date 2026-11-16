#if canImport(SwiftUI)
import SwiftUI

/// Flutter `_buildSwitch` (input_builders.dart:246-294), drawn as SwiftUI's
/// Toggle (design D6), on iOS a UISwitch. On when the store at `stateKey`
/// is true, when the node has one, else when the `value` prop is (anything
/// else, or none, is off), read when the view is built (Flutter's build),
/// with no state of the view's own: it changes when the node redraws,
/// through its watches (D4). A tap sends the other of the value drawn
/// (Toggleable's `!value`) through `valueChanged`: the stateKey in page
/// scope, then onChange {value}. UISwitch moves under the finger; when no
/// redraw follows (the node does not watch the key), SwiftUI puts it back
/// at the value drawn, where Flutter's never moved. `enabled` false
/// disables it (greyed by the system) and it sends nothing; without
/// onChange it still writes the stateKey.
///
/// It takes the room of Flutter's padded M3 Switch, 60 x 48 (52 wide and
/// 40 + 8 high, with 4 of padding left and right, switch.dart:583-585,
/// switch_defaults_m3.g.dart:140, :195-201, :228), so rows lay out as
/// Flutter's do, with iOS's 51 x 31 switch in the middle taking the
/// touches. With activeColor the on track (SwiftUI's tint) is activeColor
/// at alpha 0x80, Flutter's checked track (switch.dart:950-957); Flutter
/// paints its thumb in activeColor too, and the iOS thumb stays white
/// (SwiftUI has no thumb colour). Without activeColor the track is the iOS
/// green, where Flutter's is the theme's primary, ThemeData()'s #6750A4
/// (the iOS look, D6). inactiveColor, Flutter's off track, has no SwiftUI
/// setting. focusColor and hoverColor have no touch-screen state. The
/// engine's Switch sends no `label`, so Flutter's SwitchListTile is not
/// drawn.
@MainActor
struct SwitchNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    /// Whether the switch is drawn on, read when the view is built.
    let isOn: Bool

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        if let key = node["stateKey"]?.stringValue {
            isOn = model.store.value(key).boolValue ?? false
        } else {
            isOn = node["value"]?.boolValue ?? false
        }
    }

    var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { _ in toggled() }))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(Props.color(node["activeColor"]).map { $0.opacity(Double(0x80) / 255) })
            .disabled(!enabled)
            .frame(width: 60, height: 48)
    }

    private var enabled: Bool { node["enabled"]?.boolValue ?? true }

    /// A tap: the other of the value drawn, written and sent; nil when
    /// disabled or when the node has neither a stateKey nor onChange.
    @discardableResult
    func toggled() -> Task<Void, Never>? {
        guard enabled else { return nil }
        return model.valueChanged(.bool(!isOn), on: node)
    }
}

/// Flutter `_buildSlider` (input_builders.dart:296-348), drawn as SwiftUI's
/// Slider (design D6), on iOS a UISlider, over `min` (0) to `max` (1), in
/// steps of (max − min) / `divisions` when divisions is above 0. The value
/// is the number in the store at `stateKey`, when the node has one, else
/// the `value` prop, else 0, read when the view is built; it is drawn
/// clamped to the range and the state is not corrected (:312), the thumb on
/// the nearest stop when discrete (Flutter's `_convert`). A reversed range
/// is drawn at min (Flutter's builder throws in `clamp`). Each drag update
/// sends the value under the finger snapped as Flutter's `_lerp`
/// (`FormControls.sliderValue`), a double, through `valueChanged` (the
/// stateKey in page scope, then onChange {value}), and only when it is
/// neither the one last sent in this drag nor the one drawn (Flutter's
/// `_handleChanged`, material slider.dart:752-760); what was sent outlives
/// redraws until the finger lifts, as `_currentChangedValue` lives in
/// Flutter's State. UISlider moves only when its thumb is dragged, so a
/// tap on the track sends nothing, where Flutter's sends the value under
/// the finger as it goes down and its thumb jumps there (slider.dart:
/// 1653-1678, :1747-1748, :1768-1771). The thumb follows the finger; when
/// no redraw follows, SwiftUI puts it back at the value drawn. `enabled`
/// false disables it (greyed by the system) and it sends nothing; without
/// onChange it still writes the stateKey.
///
/// It is the width it is given and 48 high, as Flutter's (slider.dart:
/// 1796-1804). activeColor is the track left of the thumb (SwiftUI's
/// tint); without it the iOS accent, where Flutter's is ThemeData()'s
/// primary #6750A4 (the iOS look, D6). Flutter also paints the thumb in
/// activeColor when thumbColor is unset, with an overlay of it at 0.12
/// while pressed (slider.dart:917, :956); the iOS thumb stays white.
/// SwiftUI's Slider has no setting for inactiveColor (the track right of
/// the thumb), thumbColor, trackHeight, the tick marks of a discrete
/// Flutter Slider (slider.dart:948-950), nor the value indicator that
/// shows `label` above its thumb.
@MainActor
struct SliderNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    let min: Double
    let max: Double
    /// Above 0, or nil: continuous.
    let divisions: Int?
    /// The value drawn, clamped, read when the view is built.
    let drawn: Double
    /// The value last sent in the drag under way. It outlives redraws, as
    /// Flutter's `_currentChangedValue` lives in the slider's State; a box,
    /// so a change to it redraws nothing.
    @State private var sent = Sent()

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        let min = node["min"]?.doubleValue ?? 0
        let max = Swift.max(node["max"]?.doubleValue ?? 1, min)
        let value: Double?
        if let key = node["stateKey"]?.stringValue {
            value = model.store.value(key).doubleValue
        } else {
            value = node["value"]?.doubleValue
        }
        self.min = min
        self.max = max
        divisions = node["divisions"]?.intValue.flatMap { $0 > 0 ? $0 : nil }
        drawn = Swift.min(Swift.max(value ?? 0, min), max)
    }

    var body: some View {
        let value = Binding(get: { thumb }, set: { moved(to: $0) })
        Group {
            if let divisions, max > min {
                Slider(value: value, in: min...max, step: (max - min) / Double(divisions)) { edited($0) }
            } else {
                Slider(value: value, in: min...max) { edited($0) }
            }
        }
        .tint(Props.color(node["activeColor"]))
        .disabled(!enabled)
        .frame(height: 48)
    }

    private var enabled: Bool { node["enabled"]?.boolValue ?? true }

    /// Where the thumb is drawn: the value, on the nearest stop when
    /// discrete.
    var thumb: Double { snapped(drawn) }

    /// A drag update with the finger at `value`: snapped, written and sent
    /// when it is new to this drag and not the value drawn; nil otherwise,
    /// when disabled, or when the node has neither a stateKey nor onChange.
    @discardableResult
    func moved(to value: Double) -> Task<Void, Never>? {
        guard enabled else { return nil }
        let next = snapped(value)
        guard next != sent.value else { return nil }
        sent.value = next
        guard next != drawn else { return nil }
        return model.valueChanged(.double(next), on: node)
    }

    /// The finger lifted: the next drag sends afresh (Flutter's
    /// `_handleDragEnd`).
    func edited(_ editing: Bool) {
        if !editing { sent.value = nil }
    }

    private func snapped(_ value: Double) -> Double {
        FormControls.sliderValue(fraction: FormControls.sliderFraction(value: value, min: min, max: max),
                                 min: min, max: max, divisions: divisions)
    }

    private final class Sent {
        var value: Double?
    }
}
#endif
