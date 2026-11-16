import Foundation

/// Flutter's named curves, the ones the engine can send (`Curves` in
/// `engine/src/components/helpers/curves.ts`, parsed by `_parseCurve` in the
/// Flutter SDK's `builders/layout_builders.dart`). The formulas are ports of
/// Flutter's `animation/curves.dart`, the cubic solver included, so a value
/// here is the value Flutter draws.
public enum Curves {
    /// Every known name, in the order of Flutter's `_parseCurve`.
    public static let names: [String] = table.map(\.name)

    /// The curve's value at `t`. A missing or unknown name is `easeInOut`.
    /// `t` is clamped to 0...1 and the two ends map to themselves; in between
    /// the elastic and back curves may leave 0...1.
    public static func apply(_ name: String?, _ t: Double) -> Double {
        if !(t > 0) { return 0 }  // also NaN
        if t >= 1 { return 1 }
        let shape = name.flatMap { byName[$0] } ?? easeInOut
        return shape.transform(t)
    }

    // MARK: Table

    private enum Shape {
        case linear
        case decelerate
        case cubic(Double, Double, Double, Double)
        /// a1, b1, midpoint, a2, b2 as (x, y) pairs (Flutter's ThreePointCubic).
        case threePoint([Double])
        case bounceIn, bounceOut, bounceInOut
        case elasticIn, elasticOut, elasticInOut

        func transform(_ t: Double) -> Double {
            switch self {
            case .linear: return t
            case .decelerate:
                let u = 1 - t
                return 1 - u * u
            case .cubic(let a, let b, let c, let d): return Curves.cubic(a, b, c, d, t)
            case .threePoint(let p): return Curves.threePointCubic(p, t)
            case .bounceIn: return 1 - Curves.bounce(1 - t)
            case .bounceOut: return Curves.bounce(t)
            case .bounceInOut:
                return t < 0.5 ? (1 - Curves.bounce(1 - t * 2)) * 0.5 : Curves.bounce(t * 2 - 1) * 0.5 + 0.5
            case .elasticIn:
                let u = t - 1
                return -pow(2, 10 * u) * sin((u - elasticPeriod / 4) * (Double.pi * 2) / elasticPeriod)
            case .elasticOut:
                return pow(2, -10 * t) * sin((t - elasticPeriod / 4) * (Double.pi * 2) / elasticPeriod) + 1
            case .elasticInOut:
                let u = 2 * t - 1
                let wave = sin((u - elasticPeriod / 4) * (Double.pi * 2) / elasticPeriod)
                return u < 0 ? -0.5 * pow(2, 10 * u) * wave : pow(2, -10 * u) * wave * 0.5 + 1
            }
        }
    }

    private static let elasticPeriod = 0.4
    private static let easeInOut = Shape.cubic(0.42, 0.0, 0.58, 1.0)

    private static let table: [(name: String, shape: Shape)] = [
        ("linear", .linear),
        ("easeIn", .cubic(0.42, 0.0, 1.0, 1.0)),
        ("easeOut", .cubic(0.0, 0.0, 0.58, 1.0)),
        ("easeInOut", easeInOut),
        ("decelerate", .decelerate),
        ("bounceIn", .bounceIn),
        ("bounceOut", .bounceOut),
        ("bounceInOut", .bounceInOut),
        ("elasticIn", .elasticIn),
        ("elasticOut", .elasticOut),
        ("elasticInOut", .elasticInOut),
        ("fastOutSlowIn", .cubic(0.4, 0.0, 0.2, 1.0)),
        ("ease", .cubic(0.25, 0.1, 0.25, 1.0)),
        ("easeInSine", .cubic(0.47, 0.0, 0.745, 0.715)),
        ("easeOutSine", .cubic(0.39, 0.575, 0.565, 1.0)),
        ("easeInOutSine", .cubic(0.445, 0.05, 0.55, 0.95)),
        ("easeInQuad", .cubic(0.55, 0.085, 0.68, 0.53)),
        ("easeOutQuad", .cubic(0.25, 0.46, 0.45, 0.94)),
        ("easeInOutQuad", .cubic(0.455, 0.03, 0.515, 0.955)),
        ("easeInCubic", .cubic(0.55, 0.055, 0.675, 0.19)),
        ("easeOutCubic", .cubic(0.215, 0.61, 0.355, 1.0)),
        ("easeInOutCubic", .cubic(0.645, 0.045, 0.355, 1.0)),
        ("easeInQuart", .cubic(0.895, 0.03, 0.685, 0.22)),
        ("easeOutQuart", .cubic(0.165, 0.84, 0.44, 1.0)),
        ("easeInOutQuart", .cubic(0.77, 0.0, 0.175, 1.0)),
        ("easeInQuint", .cubic(0.755, 0.05, 0.855, 0.06)),
        ("easeOutQuint", .cubic(0.23, 1.0, 0.32, 1.0)),
        ("easeInOutQuint", .cubic(0.86, 0.0, 0.07, 1.0)),
        ("easeInExpo", .cubic(0.95, 0.05, 0.795, 0.035)),
        ("easeOutExpo", .cubic(0.19, 1.0, 0.22, 1.0)),
        ("easeInOutExpo", .cubic(1.0, 0.0, 0.0, 1.0)),
        ("easeInCirc", .cubic(0.6, 0.04, 0.98, 0.335)),
        ("easeOutCirc", .cubic(0.075, 0.82, 0.165, 1.0)),
        ("easeInOutCirc", .cubic(0.785, 0.135, 0.15, 0.86)),
        ("easeInBack", .cubic(0.6, -0.28, 0.735, 0.045)),
        ("easeOutBack", .cubic(0.175, 0.885, 0.32, 1.275)),
        ("easeInOutBack", .cubic(0.68, -0.55, 0.265, 1.55)),
        ("fastLinearToSlowEaseIn", .cubic(0.18, 1.0, 0.04, 1.0)),
        ("slowMiddle", .cubic(0.15, 0.85, 0.85, 0.15)),
        ("fastEaseInToSlowEaseOut", .threePoint([0.056, 0.024, 0.108, 0.3085, 0.198, 0.541, 0.3655, 1.0, 0.5465, 0.989])),
        ("linearToEaseOut", .cubic(0.35, 0.91, 0.33, 0.97)),
        ("easeInToLinear", .cubic(0.67, 0.03, 0.65, 0.09)),
    ]

    private static let byName: [String: Shape] = Dictionary(
        table.map { ($0.name, $0.shape) }, uniquingKeysWith: { first, _ in first })

    // MARK: Formulas

    /// Flutter's `Cubic.transformInternal`: bisection on the parameter until x
    /// is within 0.001 of `t`, then y there.
    private static func cubic(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ t: Double) -> Double {
        if !(t > 0) { return 0 }
        if t >= 1 { return 1 }
        func evaluate(_ p: Double, _ q: Double, _ m: Double) -> Double {
            3 * p * (1 - m) * (1 - m) * m + 3 * q * (1 - m) * m * m + m * m * m
        }
        var start = 0.0
        var end = 1.0
        var midpoint = 0.5
        // Flutter loops until it converges; the bound only guards a curve
        // whose x is not monotonic.
        for _ in 0..<64 {
            midpoint = (start + end) / 2
            let estimate = evaluate(a, c, midpoint)
            if abs(t - estimate) < 0.001 { break }
            if estimate < t { start = midpoint } else { end = midpoint }
        }
        return evaluate(b, d, midpoint)
    }

    /// Flutter's `ThreePointCubic.transformInternal`: two cubics joined at the
    /// midpoint, each scaled to the unit square.
    private static func threePointCubic(_ p: [Double], _ t: Double) -> Double {
        let (midX, midY) = (p[4], p[5])
        let first = t < midX
        let scaleX = first ? midX : 1 - midX
        let scaleY = first ? midY : 1 - midY
        let scaledT = (t - (first ? 0 : midX)) / scaleX
        if first {
            return cubic(p[0] / scaleX, p[1] / scaleY, p[2] / scaleX, p[3] / scaleY, scaledT) * scaleY
        }
        return cubic((p[6] - midX) / scaleX, (p[7] - midY) / scaleY,
                     (p[8] - midX) / scaleX, (p[9] - midY) / scaleY, scaledT) * scaleY + midY
    }

    /// Flutter's `_bounce`.
    private static func bounce(_ value: Double) -> Double {
        var t = value
        if t < 1.0 / 2.75 { return 7.5625 * t * t }
        if t < 2 / 2.75 {
            t -= 1.5 / 2.75
            return 7.5625 * t * t + 0.75
        }
        if t < 2.5 / 2.75 {
            t -= 2.25 / 2.75
            return 7.5625 * t * t + 0.9375
        }
        t -= 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    }
}
