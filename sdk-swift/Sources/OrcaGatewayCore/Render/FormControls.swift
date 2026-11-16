import Foundation

/// What a tap or a drag makes of a form control's value, as Flutter's
/// builders (sdk/lib/src/builders/input_builders.dart) and the Material
/// controls they build decide it. Pure: the UI layers read the value from
/// the store or the prop, draw it, feed gestures here, and write the answer
/// back (design D4, D5). The same as Kotlin's FormControls.
public enum FormControls {
    /// The value a tap gives a Checkbox showing `value`: Toggleable's
    /// `_handleTap` (widgets/toggleable.dart:247-252), false → true, true →
    /// null when `tristate` else false, null → false. The builder
    /// (input_builders.dart:208-218) writes it to its stateKey, then fires
    /// onChange with it; a two-state Checkbox never gets null, as it draws
    /// a missing value as false.
    public static func checkboxNext(value: Bool?, tristate: Bool) -> Bool? {
        switch value {
        case false?: return true
        case true?: return tristate ? nil : false
        case nil: return false
        }
    }

    /// Whether a Radio is selected: its `value` and the `group` value are
    /// the same string (input_builders.dart:148). The builder makes both
    /// strings (:142-147): the value prop resolved by `resolveStringValue`
    /// ('' when missing, a number or bool as Dart prints it,
    /// builder_helpers.dart:436-447); the group from the state at stateKey
    /// as Dart's `toString()` ('' when missing) when stateKey is set, else
    /// the groupValue prop, resolved the same way. So a missing value in an
    /// empty group is selected.
    public static func radioSelected(value: String, group: String) -> Bool {
        value == group
    }

    /// A Slider's value at `fraction` of its track (0 at min, 1 at max):
    /// the fraction held within 0 ... 1, then Flutter's `_lerp` (material
    /// slider.dart:811-819), min + t · (max − min), or with `divisions`
    /// above 0 min + round(t · d) · (max − min) / d, the stop nearest t
    /// (`round` half away from zero, as Dart's). Divisions of 0 or below,
    /// which Flutter only asserts on (:223), are continuous, as its render
    /// object takes only more than 0 as discrete (:1317). An empty or
    /// reversed range (max ≤ min; Flutter asserts min ≤ max and the
    /// builder's `value.clamp(min, max)` throws) gives min.
    public static func sliderValue(fraction: Double, min: Double, max: Double, divisions: Int?) -> Double {
        guard max > min else { return min }
        let t = Swift.min(Swift.max(fraction, 0), 1)
        if let d = divisions, d > 0 {
            return min + (t * Double(d)).rounded() * (max - min) / Double(d)
        }
        return t * (max - min) + min
    }

    /// The fraction of its track (0 at min, 1 at max) a Slider showing
    /// `value` draws its thumb at: the value held within min ... max (the
    /// builder's `value.clamp(min, max)`, input_builders.dart:312), then
    /// Flutter's `_unlerp` (material slider.dart:838-842), 0 for an empty
    /// or reversed range. A discrete Slider draws the stop nearest it
    /// (`_convert`, :829-836): this fraction of
    /// `sliderValue(fraction: sliderFraction(…), …, divisions:)`.
    public static func sliderFraction(value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0 }
        return (Swift.min(Swift.max(value, min), max) - min) / (max - min)
    }
}
