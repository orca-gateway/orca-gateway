import Foundation

/// What Flutter's builders paint for CircularProgressIndicator and
/// LinearProgressIndicator (sdk/lib/src/builders/primitive_builders.dart:
/// Circular :302-323 with `_CircularProgressPainter` :465-513, Linear
/// :364-384 with `_LinearProgressPainter` :435-463): their own static
/// painters, not Material's animated indicators. Pure: the UI layers draw
/// these numbers on a canvas (design D9). Angles are radians, clockwise
/// from 3 o'clock (Flutter's `drawArc`); colours are ARGB, as Flutter's
/// `Color` value. The same as Kotlin's ProgressGeometry.
public enum ProgressGeometry {
    /// A box in points: where the circular stroke is centred.
    public struct Rect: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    /// The circular arc: `startRad` and `sweepRad` in radians, round caps,
    /// drawn only when `drawsArc`. `track`: a full ring in `trackColor`, butt
    /// caps, goes under it first (:500-504).
    public struct Arc: Equatable, Sendable {
        public var startRad: Double
        public var sweepRad: Double
        public var track: Bool

        public init(startRad: Double, sweepRad: Double, track: Bool) {
            self.startRad = startRad
            self.sweepRad = sweepRad
            self.track = track
        }

        /// Whether the arc is stroked: only when it sweeps, as Flutter draws
        /// it only when the value is above 0 (:505); a round cap on a sweep
        /// of 0 would leave a dot.
        public var drawsArc: Bool { sweepRad > 0 }
    }

    /// The arc and the Linear bar's colour when `color` is not sent, #2196F3
    /// (:317, :378).
    public static let defaultColor: UInt32 = 0xFF21_96F3

    /// The Linear track's colour when `backgroundColor` is not sent, #E0E0E0
    /// (:379).
    public static let linearTrackColor: UInt32 = 0xFFE0_E0E0

    /// The Circular's width and height unless its parent forces a box
    /// (:303; `size` is not an engine prop, so always 36).
    public static let circularSize: Double = 36

    /// The Circular's stroke: `strokeWidth`, 3 when absent or not above 0
    /// (:305, :318).
    public static func circularStroke(_ strokeWidth: Double?) -> Double {
        guard let strokeWidth, strokeWidth > 0 else { return 3 }
        return strokeWidth
    }

    /// The rect the Circular strokes in a `width` x `height` box: inset by
    /// half the stroke on every side, never below 0 wide or high (:480-486).
    /// A box that is not square gives an ellipse, as Flutter's.
    public static func circularRect(width: Double, height: Double, strokeWidth: Double) -> Rect {
        Rect(x: strokeWidth / 2, y: strokeWidth / 2,
             width: max(0, width - strokeWidth), height: max(0, height - strokeWidth))
    }

    /// The Circular's arc for `value`: none or NaN is indeterminate, one
    /// static arc from -0.5 sweeping 4.5 with no track (:310, :494-497;
    /// nothing animates); else the value held within 0 ... 1 (:310), a track,
    /// and an arc from 12 o'clock (-π/2) sweeping 2π x value (:505-507).
    public static func circularArc(_ value: Double?) -> Arc {
        guard let value, !value.isNaN else { return Arc(startRad: -0.5, sweepRad: 4.5, track: false) }
        return Arc(startRad: -Double.pi / 2, sweepRad: 2 * Double.pi * min(max(value, 0), 1), track: true)
    }

    /// The determinate Circular's track colour: `argb` with its alpha
    /// replaced by 0x33, Flutter `Color.withAlpha(0x33)` (:501), not
    /// multiplied.
    public static func trackColor(_ argb: UInt32) -> UInt32 {
        (argb & 0x00FF_FFFF) | 0x3300_0000
    }

    /// The Linear's height: `minHeight`, 4 when absent (:368, :371). One not
    /// above 0 (NaN too, which a divide transform can make) is 0: Flutter
    /// asserts on a negative one in debug and enforces it into a loose
    /// parent's constraints in release.
    public static func linearHeight(_ minHeight: Double?) -> Double {
        let height = minHeight ?? 4
        return height > 0 ? height : 0
    }

    /// The Linear's corner radius for its `height`: half of it, the
    /// ClipRRect around track and bar (:373).
    public static func linearRadius(_ height: Double) -> Double {
        height / 2
    }

    /// The width of the Linear's bar across a track `width` wide: none when
    /// `value` is nil (indeterminate is the bare track, :451, nothing
    /// animates), else width x the value held within 0 ... 1 (:454), NaN
    /// being 1 as Dart's `clamp` has it (NaN compares above every number,
    /// vm/lib/double.dart:229). The bar starts at the left edge, in
    /// right-to-left too (the painter takes no direction).
    public static func linearBar(width: Double, value: Double?) -> Double? {
        value.map { width * ($0.isNaN ? 1 : min(max($0, 0), 1)) }
    }
}
