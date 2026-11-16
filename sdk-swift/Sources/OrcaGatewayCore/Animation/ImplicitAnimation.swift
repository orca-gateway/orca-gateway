import Foundation

/// The clock of one implicitly animated widget (AnimatedContainer,
/// AnimatedOpacity, AnimatedAlign): it is handed the widget's resolved props
/// each time they change and answers "the props to draw at time t".
///
/// The first props are shown as they are. Different props later start a run
/// from what is on screen at that moment to the new props, over the full
/// duration, also when a run was live (Flutter's ImplicitlyAnimatedWidget).
/// With `reduceMotion`, or a duration of 0 or less, the new props show at once.
///
/// Time is a parameter, in milliseconds. `durationMs`, `curve` and
/// `reduceMotion` may be set before `retarget`; a live run keeps the ones it
/// began with.
public struct ImplicitAnimation: Equatable, Sendable {
    public var durationMs: Double
    public var curve: String?
    public var reduceMotion: Bool

    /// The props the live or last run began from.
    public private(set) var from: [String: JSONValue] = [:]
    /// The props last handed in; nil before the first.
    public private(set) var to: [String: JSONValue]?
    /// When the live or last run began.
    public private(set) var startMs: Double = 0

    private var runDurationMs: Double = 0
    private var runCurve: String?

    public init(durationMs: Double = 300, curve: String? = nil, reduceMotion: Bool = false) {
        self.durationMs = durationMs
        self.curve = curve
        self.reduceMotion = reduceMotion
    }

    /// Hands in the widget's props at `now`. True when a run began: not for
    /// the first props, not for props equal to the current target, not when
    /// the change jumps.
    @discardableResult
    public mutating func retarget(to props: [String: JSONValue], at now: Double) -> Bool {
        guard let current = to else {
            from = props
            to = props
            return false
        }
        if current == props { return false }
        from = value(at: now)
        to = props
        startMs = now
        runDurationMs = reduceMotion ? 0 : Swift.max(0, durationMs)
        runCurve = curve
        return runDurationMs > 0
    }

    /// The props to draw at `now`: the mix while a run is live (see
    /// `AnimationMix.prop`), else the target exactly as it was handed in.
    public func value(at now: Double) -> [String: JSONValue] {
        guard let target = to else { return [:] }
        guard isRunning(at: now) else { return target }
        let t = Curves.apply(runCurve, (now - startMs) / runDurationMs)
        var mixed: [String: JSONValue] = [:]
        for (key, end) in target {
            guard let begin = from[key] else {
                mixed[key] = end
                continue
            }
            mixed[key] = AnimationMix.prop(key, from: begin, to: end, t)
        }
        return mixed
    }

    public func isRunning(at now: Double) -> Bool {
        to != nil && runDurationMs > 0 && now < startMs + runDurationMs
    }
}

/// How the props of an implicitly animated widget are mixed between two
/// states. `t` is the curved progress and may leave 0...1 (elastic, back).
public enum AnimationMix {
    /// One prop by its name: `alignment`, `padding` / `margin`, `decoration`
    /// and `color` by their own mixes, any other pair of numbers as numbers.
    /// Everything else, a null side included, is `to` from the start.
    public static func prop(_ key: String, from: JSONValue, to: JSONValue, _ t: Double) -> JSONValue {
        if from == to || from.isNull || to.isNull { return to }
        switch key {
        case "alignment":
            return alignment(from, to, t) ?? to
        case "padding", "margin":
            return edgeInsets(from, to, t) ?? to
        case "decoration":
            return decoration(from, to, t) ?? to
        case "color":
            guard case .string(let a) = from, case .string(let b) = to else { return to }
            return color(a, b, t).map(JSONValue.string) ?? to
        default:
            guard let a = from.doubleValue, let b = to.doubleValue else { return to }
            return .double(number(a, b, t))
        }
    }

    public static func number(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    /// Two wire colours (`#RRGGBB`, or `#RRGGBBAA` with alpha last, as Dart's
    /// `parseColor` reads them) mixed per channel and written as `#RRGGBBAA`.
    /// Nil when either is not a colour.
    ///
    /// Not the resolver's `lerpColor`: that one writes `#AARRGGBB`, the order
    /// the tween path uses, which a widget's colour prop would misread.
    public static func color(_ a: String, _ b: String, _ t: Double) -> String? {
        guard let x = rgba(a), let y = rgba(b) else { return nil }
        var out = "#"
        for i in 0..<4 {
            let v = number(x[i], y[i], t).rounded(.toNearestOrAwayFromZero)
            let byte = v.isFinite ? Int(Swift.min(Swift.max(v, 0), 255)) : 0
            let hex = String(byte, radix: 16, uppercase: true)
            out += hex.count == 1 ? "0" + hex : hex
        }
        return out
    }

    /// An alignment as x and y in -1...1 (Flutter's `Alignment`): one of the
    /// nine names (any other string is the centre, as Dart's `parseAlignment`)
    /// or an `{x, y}` object, the form a mix is written in. Nil otherwise.
    public static func alignmentPoint(_ value: JSONValue) -> (x: Double, y: Double)? {
        switch value {
        case .string(let name):
            switch name {
            case "topLeft": return (-1, -1)
            case "topCenter": return (0, -1)
            case "topRight": return (1, -1)
            case "centerLeft": return (-1, 0)
            case "centerRight": return (1, 0)
            case "bottomLeft": return (-1, 1)
            case "bottomCenter": return (0, 1)
            case "bottomRight": return (1, 1)
            default: return (0, 0)
            }
        case .object(let o):
            guard let x = o["x"]?.doubleValue, let y = o["y"]?.doubleValue else { return nil }
            return (x, y)
        default:
            return nil
        }
    }

    /// Two alignments mixed, as an `{x, y}` object. Nil when either is not one.
    public static func alignment(_ a: JSONValue, _ b: JSONValue, _ t: Double) -> JSONValue? {
        guard let p = alignmentPoint(a), let q = alignmentPoint(b) else { return nil }
        return .object(["x": .double(number(p.x, q.x, t)), "y": .double(number(p.y, q.y, t))])
    }

    /// Two edge insets (`{top, right, bottom, left}`, a missing side is 0, as
    /// Dart's `parseEdgeInsets`) mixed side by side. Nil when either is not an
    /// object.
    public static func edgeInsets(_ a: JSONValue, _ b: JSONValue, _ t: Double) -> JSONValue? {
        guard case .object(let x) = a, case .object(let y) = b else { return nil }
        return .object(sides(["top", "right", "bottom", "left"], x, y, t))
    }

    /// Two box decorations: the colour, the corner radius and the border's
    /// width and colour are mixed; every other part (gradient, shadows, border
    /// style) and any part with a null side is the target's. Nil when either
    /// is not an object.
    public static func decoration(_ a: JSONValue, _ b: JSONValue, _ t: Double) -> JSONValue? {
        guard case .object(let x) = a, case .object(let y) = b else { return nil }
        var out = y
        if case .string(let c)? = x["color"], case .string(let d)? = y["color"], let mixed = color(c, d, t) {
            out["color"] = .string(mixed)
        }
        if let r = x["borderRadius"], let s = y["borderRadius"] {
            if let p = r.doubleValue, let q = s.doubleValue {
                out["borderRadius"] = .double(number(p, q, t))
            } else if let p = corners(r), let q = corners(s) {
                out["borderRadius"] = .object(sides(cornerNames, p, q, t))
            }
        }
        if case .object(let p)? = x["border"], case .object(let q)? = y["border"] {
            var border = q
            // Dart `_parseBorder`: width 1 and black when missing.
            border["width"] = .double(number(p["width"]?.doubleValue ?? 1, q["width"]?.doubleValue ?? 1, t))
            let c = p["color"]?.stringValue ?? "#000000"
            let d = q["color"]?.stringValue ?? "#000000"
            if let mixed = color(c, d, t) { border["color"] = .string(mixed) }
            out["border"] = .object(border)
        }
        return .object(out)
    }

    // MARK: Private

    private static let cornerNames = ["topLeft", "topRight", "bottomLeft", "bottomRight"]

    private static func sides(_ names: [String], _ a: [String: JSONValue], _ b: [String: JSONValue],
                              _ t: Double) -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for name in names {
            out[name] = .double(number(a[name]?.doubleValue ?? 0, b[name]?.doubleValue ?? 0, t))
        }
        return out
    }

    /// Dart `_parseBorderRadius`: a number is every corner, an object each
    /// corner (missing ones 0).
    private static func corners(_ value: JSONValue) -> [String: JSONValue]? {
        if let all = value.doubleValue {
            return Dictionary(cornerNames.map { ($0, JSONValue.double(all)) }, uniquingKeysWith: { first, _ in first })
        }
        if case .object(let o) = value { return o }
        return nil
    }

    /// Red, green, blue, alpha as 0...255.
    private static func rgba(_ text: String) -> [Double]? {
        guard text.hasPrefix("#") else { return nil }
        let hex = text.dropFirst()
        guard hex.utf8.count == 6 || hex.utf8.count == 8,
              hex.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 70) || ($0 >= 97 && $0 <= 102) }),
              let raw = UInt32(hex, radix: 16) else { return nil }
        let value = hex.utf8.count == 6 ? (raw << 8) | 0xFF : raw
        return [24, 16, 8, 0].map { Double((value >> UInt32($0)) & 0xFF) }
    }
}
