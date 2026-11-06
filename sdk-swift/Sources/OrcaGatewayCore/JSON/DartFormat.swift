import Foundation

/// String conversions that reproduce Dart's `'$value'` and `toStringAsFixed`,
/// because the Flutter SDK is the reference client: a `toString`, `template`
/// or `formatNumber` transform must render the same text on every SDK.
public enum DartFormat {
    /// Dart's `'$value'` for a JSON value: `null`, `true`, `42`, `4.0`,
    /// `1e+21`, `[1, a]`, `{k: v}`.
    public static func string(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return double(d)
        case .string(let s): return s
        case .array(let a): return "[" + a.map(string).joined(separator: ", ") + "]"
        case .object(let o):
            let body = o.keys.sorted().map { "\($0): \(string(o[$0]!))" }
            return "{" + body.joined(separator: ", ") + "}"
        }
    }

    /// Dart's `double.toString()`: the shortest digits that round-trip, in
    /// fixed notation for 1e-6 <= |x| < 1e21 (with a trailing `.0` when
    /// integral) and exponential notation (`1e+21`, `1.5e-7`) otherwise.
    public static func double(_ d: Double) -> String {
        if d.isNaN { return "NaN" }
        if d.isInfinite { return d < 0 ? "-Infinity" : "Infinity" }
        if d == 0 { return d.sign == .minus ? "-0.0" : "0.0" }

        let (negative, digits, pointPos) = shortestDigits(d)
        let sign = negative ? "-" : ""
        let k = digits.count
        let n = pointPos  // value = 0.d1d2...dk × 10^n

        if k <= n && n <= 21 {
            return sign + digits + String(repeating: "0", count: n - k) + ".0"
        }
        if 0 < n && n <= 21 {
            let i = digits.index(digits.startIndex, offsetBy: n)
            return sign + digits[..<i] + "." + digits[i...]
        }
        if -6 < n && n <= 0 {
            return sign + "0." + String(repeating: "0", count: -n) + digits
        }
        let e = n - 1
        let expPart = "e" + (e >= 0 ? "+" : "-") + String(abs(e))
        if k == 1 { return sign + digits + expPart }
        let first = digits.prefix(1)
        return sign + first + "." + digits.dropFirst() + expPart
    }

    /// Splits Swift's shortest round-trip rendering into sign, significant
    /// digits and the decimal point position (value = 0.digits × 10^pointPos).
    private static func shortestDigits(_ d: Double) -> (Bool, String, Int) {
        var text = "\(d.magnitude)"  // e.g. "1.5e-07", "123.45", "1e+16"
        var exponent = 0
        if let e = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            exponent = Int(text[text.index(after: e)...]) ?? 0
            text = String(text[..<e])
        }
        var intPart = text
        var fracPart = ""
        if let dot = text.firstIndex(of: ".") {
            intPart = String(text[..<dot])
            fracPart = String(text[text.index(after: dot)...])
        }
        var digits = intPart + fracPart
        var pointPos = intPart.count + exponent
        // Strip leading zeros (moving the point) and trailing zeros.
        while digits.count > 1 && digits.hasPrefix("0") {
            digits.removeFirst()
            pointPos -= 1
        }
        while digits.count > 1 && digits.hasSuffix("0") {
            digits.removeLast()
        }
        return (d.sign == .minus, digits, pointPos)
    }

    /// Dart's `num.toStringAsFixed(fractionDigits)`: rounds half away from
    /// zero on the exact binary value (`0.125` gives `0.13`, `2.5` gives `3`),
    /// falls back to `toString()` for |x| >= 1e21. Returns nil where Dart
    /// throws (fractionDigits outside 0...20).
    public static func fixed(_ value: Double, _ fractionDigits: Int) -> String? {
        guard (0...20).contains(fractionDigits) else { return nil }
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
        if value.magnitude >= 1e21 { return double(value) }

        // Print well past the cut; the extra digits show which side of the
        // half the exact binary value lies on.
        let long = String(format: "%.\(fractionDigits + 25)f", value.magnitude)
        let parts = long.split(separator: ".", omittingEmptySubsequences: false)
        var intDigits = Array(parts[0])
        let frac = parts.count > 1 ? Array(parts[1]) : []
        var kept = Array(frac.prefix(fractionDigits))
        let roundUp = frac.count > fractionDigits && frac[fractionDigits] >= "5"

        if roundUp {
            var all = intDigits + kept
            var i = all.count - 1
            var carry = true
            while carry && i >= 0 {
                if all[i] == "9" {
                    all[i] = "0"
                    i -= 1
                } else {
                    all[i] = Character(String(all[i].wholeNumberValue! + 1))
                    carry = false
                }
            }
            if carry { all.insert("1", at: 0) }
            intDigits = Array(all.prefix(all.count - kept.count))
            kept = Array(all.suffix(kept.count))
        }

        let sign = value.sign == .minus ? "-" : ""
        let body = String(intDigits) + (fractionDigits > 0 ? "." + String(kept) : "")
        return sign + body
    }

    /// `toStringAsFixed` for a JSON number (Dart converts an int to double).
    public static func fixed(_ value: JSONValue, _ fractionDigits: Int) -> String? {
        guard let d = value.doubleValue else { return nil }
        return fixed(d, fractionDigits)
    }
}
