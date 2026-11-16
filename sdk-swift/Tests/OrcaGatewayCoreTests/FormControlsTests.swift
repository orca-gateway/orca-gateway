import XCTest

@testable import OrcaGatewayCore

/// A6.1-A6.3, the core half of Checkbox, Radio and Slider: what a tap or a
/// drag makes of the control's value, against Flutter's builders
/// (sdk/lib/src/builders/input_builders.dart: Radio :139-194, Checkbox
/// :196-246, Slider :296-348). A Checkbox tap is Toggleable's `_handleTap`
/// (widgets/toggleable.dart:247-252): false → true, true → null when
/// tristate else false, null → false. A Radio is selected iff its value and
/// the group value are the same string, a missing one being ''
/// (builder_helpers.dart:440). A Slider fraction (0 at min, 1 at max) is
/// clamped, then lerped, snapped to `divisions` when there are more than 0
/// (material slider.dart:811-819, :1317); a value's fraction is its clamped
/// distance from min over the range, 0 for an empty range (:838-842). The
/// same cases and numbers as Kotlin's FormControlsTest.
final class FormControlsTests: XCTestCase {
    private func value(_ fraction: Double, _ min: Double, _ max: Double, _ divisions: Int? = nil) -> Double {
        FormControls.sliderValue(fraction: fraction, min: min, max: max, divisions: divisions)
    }

    private func fraction(_ value: Double, _ min: Double, _ max: Double) -> Double {
        FormControls.sliderFraction(value: value, min: min, max: max)
    }

    // MARK: A6.1 Checkbox

    /// A6.1: a two-state Checkbox flips between false and true.
    func testA6_1ACheckboxTogglesBetweenFalseAndTrue() {
        XCTAssertEqual(FormControls.checkboxNext(value: false, tristate: false), true)
        XCTAssertEqual(FormControls.checkboxNext(value: true, tristate: false), false)
    }

    /// A6.1: a tristate Checkbox cycles false → true → null → false.
    func testA6_1ATristateCheckboxCyclesFalseTrueNull() {
        XCTAssertEqual(FormControls.checkboxNext(value: false, tristate: true), true)
        XCTAssertNil(FormControls.checkboxNext(value: true, tristate: true))
        XCTAssertEqual(FormControls.checkboxNext(value: nil, tristate: true), false)
    }

    /// A6.1: null goes to false whether or not the Checkbox is tristate
    /// (Toggleable's null case does not read `tristate`).
    func testA6_1ANullCheckboxGoesToFalse() {
        XCTAssertEqual(FormControls.checkboxNext(value: nil, tristate: false), false)
    }

    // MARK: A6.2 Radio

    /// A6.2: a Radio is selected when its value is the group value, so of a
    /// group sharing one value exactly one is.
    func testA6_2ARadioIsSelectedWhenItsValueEqualsTheGroup() {
        XCTAssertTrue(FormControls.radioSelected(value: "a", group: "a"))
        XCTAssertFalse(FormControls.radioSelected(value: "a", group: "b"))
        let group = ["a", "b", "c"].filter { FormControls.radioSelected(value: $0, group: "b") }
        XCTAssertEqual(group, ["b"])
    }

    /// A6.2: the comparison is exact string equality: no case folding, no
    /// trimming, no reading numbers ("1" is not "1.0").
    func testA6_2ARadioComparesExactStrings() {
        XCTAssertTrue(FormControls.radioSelected(value: "1.0", group: "1.0"))
        XCTAssertFalse(FormControls.radioSelected(value: "A", group: "a"))
        XCTAssertFalse(FormControls.radioSelected(value: " a", group: "a"))
        XCTAssertFalse(FormControls.radioSelected(value: "1", group: "1.0"))
    }

    /// A6.2: a missing value and a missing group are both '', so they
    /// select; '' against a set one does not.
    func testA6_2AMissingValueAndEmptyGroupSelect() {
        XCTAssertTrue(FormControls.radioSelected(value: "", group: ""))
        XCTAssertFalse(FormControls.radioSelected(value: "a", group: ""))
        XCTAssertFalse(FormControls.radioSelected(value: "", group: "a"))
    }

    // MARK: A6.3 Slider

    /// A6.3: a continuous Slider's value is min plus the fraction of the
    /// range; the builder's defaults are min 0, max 1.
    func testA6_3AContinuousSliderValueIsMinPlusTheFraction() {
        XCTAssertEqual(value(0.25, 0, 100), 25, accuracy: 1e-9)
        XCTAssertEqual(value(0.5, -1, 1), 0, accuracy: 1e-9)
        XCTAssertEqual(value(1, 10, 20), 20, accuracy: 1e-9)
        XCTAssertEqual(value(0, 10, 20), 10, accuracy: 1e-9)
        XCTAssertEqual(value(0.3, 0, 1), 0.3, accuracy: 1e-9)
    }

    /// A6.3: a fraction past either end of the track is held at it.
    func testA6_3ASliderFractionIsClampedToTheTrack() {
        XCTAssertEqual(value(-0.5, 0, 100), 0, accuracy: 1e-9)
        XCTAssertEqual(value(1.5, 0, 100), 100, accuracy: 1e-9)
        XCTAssertEqual(value(1.5, 0, 100, 4), 100, accuracy: 1e-9)
    }

    /// A6.3: with divisions the value snaps to the nearest of divisions + 1
    /// stops, min + round(t · d) · (max − min) / d.
    func testA6_3ADiscreteSliderSnapsToTheNearestDivision() {
        XCTAssertEqual(value(0.3, 0, 100, 4), 25, accuracy: 1e-9)
        XCTAssertEqual(value(0.4, 0, 100, 4), 50, accuracy: 1e-9)
        XCTAssertEqual(value(0.9, 0, 100, 4), 100, accuracy: 1e-9)
        XCTAssertEqual(value(0.33, 10, 20, 3), 10 + 10.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(value(0.1, 0, 1, 1), 0, accuracy: 1e-9)
    }

    /// A6.3: half way between two stops goes to the later one, Dart's
    /// `round` (half away from zero), not half to even.
    func testA6_3AHalfWayBetweenStopsRoundsAwayFromZero() {
        XCTAssertEqual(value(0.125, 0, 100, 4), 25, accuracy: 1e-9)
        XCTAssertEqual(value(0.625, 0, 100, 4), 75, accuracy: 1e-9)
    }

    /// A6.3: divisions 0 or below, which Flutter only asserts on (slider
    /// .dart:223), are a continuous Slider, as its render object takes only
    /// more than 0 as discrete (:1317).
    func testA6_3ADivisionsZeroOrBelowAreContinuous() {
        XCTAssertEqual(value(0.3, 0, 100, 0), 30, accuracy: 1e-9)
        XCTAssertEqual(value(0.3, 0, 100, -2), 30, accuracy: 1e-9)
    }

    /// A6.3: a value's fraction is its distance from min over the range,
    /// the value first held within the range (the builder's
    /// `value.clamp(min, max)`).
    func testA6_3AValueFractionIsClampedOverTheRange() {
        XCTAssertEqual(fraction(25, 0, 100), 0.25, accuracy: 1e-9)
        XCTAssertEqual(fraction(0, -1, 1), 0.5, accuracy: 1e-9)
        XCTAssertEqual(fraction(150, 0, 100), 1, accuracy: 1e-9)
        XCTAssertEqual(fraction(-5, 0, 100), 0, accuracy: 1e-9)
    }

    /// A6.3: an empty range (max == min) is fraction 0 and every fraction
    /// gives min; so is a reversed one (max < min), which Flutter asserts on
    /// and whose `clamp` throws.
    func testA6_3AnEmptyOrReversedRangeIsFractionZeroAndValueMin() {
        XCTAssertEqual(fraction(5, 5, 5), 0)
        XCTAssertEqual(fraction(3, 10, 0), 0)
        XCTAssertEqual(value(0.7, 5, 5), 5)
        XCTAssertEqual(value(0.7, 5, 5, 4), 5)
        XCTAssertEqual(value(0.7, 10, 0), 10)
        XCTAssertEqual(value(0.7, 10, 0, 4), 10)
    }

    /// A6.3: a discrete Slider draws its thumb at the stop nearest its value
    /// (Flutter's `_convert`, slider.dart:829-836): the value's fraction,
    /// snapped through sliderValue, then that value's fraction.
    func testA6_3ADiscreteThumbIsDrawnAtTheNearestStop() {
        let snapped = value(fraction(30, 0, 100), 0, 100, 4)
        XCTAssertEqual(snapped, 25, accuracy: 1e-9)
        XCTAssertEqual(fraction(snapped, 0, 100), 0.25, accuracy: 1e-9)
    }
}
