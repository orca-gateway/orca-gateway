import Foundation

/// A pipeline step: (its definition, the value so far, the resolver for
/// nested Values) to the next value. Mirrors Dart's `PipeTransform`.
public typealias PipeTransform = (
    _ definition: [String: JSONValue], _ current: JSONValue, _ resolver: ValueResolver
) -> JSONValue

/// Transform kinds by name. `defaults` holds the engine's 31 kinds plus the
/// Dart SDK's `toggle`; plugins may register more. Unknown kinds are skipped by
/// the resolver, as in Dart.
public struct TransformRegistry {
    private var table: [String: PipeTransform]

    public init(_ table: [String: PipeTransform] = [:]) { self.table = table }

    public subscript(type: String) -> PipeTransform? { table[type] }

    public mutating func register(_ type: String, _ transform: @escaping PipeTransform) {
        table[type] = transform
    }

    public var kinds: [String] { table.keys.sorted() }

    public static let defaults: TransformRegistry = {
        var r = TransformRegistry()
        Transforms.registerDefaults(&r)
        return r
    }()
}

/// The built-in transforms, each a port of the Dart closure of the same name
/// in `PipeTransformRegistry.registerDefaults`.
enum Transforms {
    static func registerDefaults(_ r: inout TransformRegistry) {
        // Numbers: `(current ?? 0) as num <op> (by as num)`.
        r.register("add") { def, current, resolver in
            DartNum.binary(current, resolver.resolve(def["by"] ?? .null), .add)
        }
        r.register("subtract") { def, current, resolver in
            DartNum.binary(current, resolver.resolve(def["by"] ?? .null), .subtract)
        }
        r.register("multiply") { def, current, resolver in
            DartNum.binary(current, resolver.resolve(def["by"] ?? .null), .multiply)
        }
        r.register("divide") { def, current, resolver in
            DartNum.binary(current, resolver.resolve(def["by"] ?? .null), .divide)
        }
        r.register("modulo") { def, current, resolver in
            DartNum.binary(current, resolver.resolve(def["by"] ?? .null), .modulo)
        }
        r.register("round") { _, current, _ in DartNum.toInt(current, .toNearestOrAwayFromZero) }
        r.register("floor") { _, current, _ in DartNum.toInt(current, .down) }
        r.register("ceil") { _, current, _ in DartNum.toInt(current, .up) }
        r.register("abs") { _, current, _ in
            switch current {
            case .int(let i): return .int(i == Int.min ? i : Swift.abs(i))
            case .double(let d): return .double(Swift.abs(d))
            default: return .null
            }
        }
        r.register("toFixed") { def, current, _ in
            let decimals = def["decimals"]?.dartInt ?? 2
            guard current.isNumber, let s = DartFormat.fixed(current, decimals) else { return .null }
            return .string(s)
        }

        // Strings: `'$current'` first, so null reads "null" as in Dart.
        r.register("toString") { _, current, _ in .string(DartFormat.string(current)) }
        r.register("toUpperCase") { _, current, _ in .string(DartFormat.string(current).uppercased()) }
        r.register("toLowerCase") { _, current, _ in .string(DartFormat.string(current).lowercased()) }
        r.register("trim") { _, current, _ in
            .string(DartFormat.string(current).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        r.register("template") { def, current, resolver in
            let template = def["template"]?.stringValue ?? ""
            return .string(Placeholders.expand(template, current, def["params"]?.objectValue, resolver))
        }
        r.register("regex") { def, current, resolver in
            regexTransform(def, current, resolver)
        }
        r.register("substring") { def, current, _ in
            let units = Array(DartFormat.string(current).utf16)
            let start = def["start"]?.dartInt ?? 0
            // Dart throws a RangeError outside 0 <= start <= end <= length.
            guard start >= 0, start <= units.count else { return .null }
            var end = units.count
            if let length = def["length"]?.dartInt {
                guard length >= 0, length <= units.count - start else { return .null }
                end = start + length
            }
            return .string(String(decoding: units[start..<end], as: UTF16.self))
        }
        r.register("split") { def, current, _ in
            let separator = def["separator"]?.stringValue ?? ""
            return .array(DartString.split(DartFormat.string(current), separator).map { .string($0) })
        }
        r.register("join") { def, current, _ in
            let separator = def["separator"]?.stringValue ?? ""
            if case .array(let items) = current {
                return .string(items.map(DartFormat.string).joined(separator: separator))
            }
            return .string(DartFormat.string(current))
        }

        // Booleans
        r.register("not") { _, current, _ in .bool(!(current == .bool(true))) }
        r.register("toBool") { _, current, _ in
            switch current {
            case .null, .bool(false), .int(0), .string(""): return .bool(false)
            case .double(let d) where d == 0: return .bool(false)
            default: return .bool(true)
            }
        }
        r.register("toggle") { _, current, _ in
            switch current {
            case .null: return .bool(true)
            case .bool(let b): return .bool(!b)
            default: return .null
            }
        }

        // Collections
        r.register("length") { _, current, _ in
            switch current {
            case .array(let a): return .int(a.count)
            case .string(let s): return .int(s.utf16.count)
            default: return .int(0)
            }
        }
        r.register("at") { def, current, _ in
            let index = def["index"]?.dartInt ?? 0
            guard case .array(let a) = current, index < a.count else { return .null }
            return index >= 0 ? a[index] : .null
        }
        r.register("first") { _, current, _ in current.arrayValue?.first ?? .null }
        r.register("last") { _, current, _ in current.arrayValue?.last ?? .null }
        r.register("map") { def, current, resolver in
            guard case .array(let items) = current,
                case .object(let step)? = def["transform"],
                let type = step["type"]?.stringValue,
                let op = resolver.transforms[type]
            else { return current }
            return .array(items.map { op(step, $0, resolver) })
        }
        r.register("filter") { def, current, resolver in
            // Dart evaluates the expression once per item without binding the
            // item, so the result is all items or none. Kept for parity.
            guard case .array(let items) = current, case .object(let expr)? = def["expr"] else {
                return current
            }
            return .array(items.filter { _ in resolver.evaluate(expr) })
        }
        r.register("contains") { def, current, resolver in
            let value = resolver.resolve(def["value"] ?? .null)
            switch current {
            case .array(let a): return .bool(a.contains(value))
            case .string(let s): return .bool(DartString.contains(s, DartFormat.string(value)))
            default: return .bool(false)
            }
        }

        // Formatting
        r.register("formatCurrency") { def, current, _ in
            let currency = def["currency"]?.stringValue ?? "USD"
            let decimals = def["decimals"]?.dartInt ?? 2
            let value: JSONValue = current.isNull ? .int(0) : current
            guard value.isNumber, let s = DartFormat.fixed(value, decimals) else { return .null }
            return .string(currencySymbol(currency) + s)
        }
        r.register("formatNumber") { def, current, _ in
            let value: JSONValue = current.isNull ? .int(0) : current
            guard value.isNumber else { return .null }
            if let decimals = def["decimals"]?.dartInt {
                return DartFormat.fixed(value, decimals).map { .string($0) } ?? .null
            }
            return .string(DartFormat.string(value))
        }
        r.register("formatDate") { def, current, _ in
            formatDate(def["format"]?.stringValue ?? "", current)
        }
    }

    static func currencySymbol(_ currency: String) -> String {
        switch currency.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return currency + " "
        }
    }

    /// `regex`: match-only returns match 0 or null; with `replacement`,
    /// `$1`-`$9` backrefs then `{{value}}` (the match) and named params expand,
    /// first match only unless the flags hold `g`. Invalid patterns give null.
    static func regexTransform(
        _ def: [String: JSONValue], _ current: JSONValue, _ resolver: ValueResolver
    ) -> JSONValue {
        let pattern = def["pattern"]?.stringValue ?? ""
        guard pattern.utf16.count <= Regex.maxPatternLength else { return .null }
        let flags = def["flags"]?.stringValue
        guard let re = Regex.compile(pattern, flags: flags) else { return .null }
        let input = Regex.clip(current.isNull ? "" : DartFormat.string(current))

        guard let replacement = def["replacement"]?.stringValue else {
            guard let m = Regex.firstMatch(re, in: input) else { return .null }
            return .string(m.group(0) ?? "")
        }
        let params = def["params"]?.objectValue
        let global = flags?.contains("g") ?? false
        let matches = global ? Regex.allMatches(re, in: input) : Regex.firstMatch(re, in: input).map { [$0] } ?? []

        let source = input as NSString
        var out = ""
        var cursor = 0
        for m in matches {
            out += source.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            let matched = m.group(0) ?? ""
            let backreffed = Regex.expandBackrefs(replacement, m)
            out += Placeholders.expand(backreffed, .string(matched), params, resolver)
            cursor = m.range.location + m.range.length
        }
        out += source.substring(from: cursor)
        return .string(out)
    }

    /// `formatDate` exists in the engine but not in the Dart SDK (which skips
    /// it). This follows the Dart engine: an ISO-8601 string keeps the fields
    /// as written (UTC when it carries an offset), a number is epoch
    /// milliseconds in UTC; `yyyy MM dd HH mm ss` are replaced. An unparseable
    /// input is returned unchanged rather than rendering "now".
    static func formatDate(_ format: String, _ current: JSONValue) -> JSONValue {
        guard let parts = DateParts(current) else { return current }
        func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : String(n) }
        let out = format
            .replacingOccurrences(of: "yyyy", with: String(parts.year))
            .replacingOccurrences(of: "MM", with: pad(parts.month))
            .replacingOccurrences(of: "dd", with: pad(parts.day))
            .replacingOccurrences(of: "HH", with: pad(parts.hour))
            .replacingOccurrences(of: "mm", with: pad(parts.minute))
            .replacingOccurrences(of: "ss", with: pad(parts.second))
        return .string(out)
    }
}

// MARK: - Dart number semantics

enum DartNum {
    enum Op { case add, subtract, multiply, divide, modulo }

    /// `((current ?? 0) as num) <op> (by as num)`: int with int stays int
    /// (wrapping like the Dart VM), `/` always gives a double, `%` is
    /// Euclidean. A non-number operand, or int `% 0`, is where Dart throws.
    static func binary(_ current: JSONValue, _ by: JSONValue, _ op: Op) -> JSONValue {
        let left: JSONValue = current.isNull ? .int(0) : current
        switch (left, by) {
        case (.int(let a), .int(let b)):
            switch op {
            case .add: return .int(a &+ b)
            case .subtract: return .int(a &- b)
            case .multiply: return .int(a &* b)
            case .divide: return .double(Double(a) / Double(b))
            case .modulo:
                guard b != 0 else { return .null }
                if b == -1 { return .int(0) }  // Int.min % -1 would trap
                let r = a % b
                // r + |b| without computing |Int.min|.
                return .int(r < 0 ? (b < 0 ? r &- b : r &+ b) : r)
            }
        default:
            guard let a = left.doubleValue, let b = by.doubleValue else { return .null }
            switch op {
            case .add: return .double(a + b)
            case .subtract: return .double(a - b)
            case .multiply: return .double(a * b)
            case .divide: return .double(a / b)
            case .modulo:
                let r = fmod(a, b)
                return .double(r < 0 ? r + Swift.abs(b) : r)
            }
        }
    }

    /// `round`, `floor`, `ceil` return an int; Dart throws on null, NaN and
    /// infinity.
    static func toInt(_ value: JSONValue, _ rule: FloatingPointRoundingRule) -> JSONValue {
        switch value {
        case .int: return value
        case .double(let d):
            guard d.isFinite else { return .null }
            let r = d.rounded(rule)
            if r >= 9.223372036854775807e18 { return .int(Int.max) }
            if r <= -9.223372036854775808e18 { return .int(Int.min) }
            return .int(Int(r))
        default:
            return .null
        }
    }
}

// MARK: - Dart string semantics

/// Dart compares strings by UTF-16 code units, with no Unicode normalization;
/// Swift's `contains`, `hasPrefix` and `components(separatedBy:)` compare
/// Characters with canonical equivalence ("e\u{301}" would match "\u{e9}").
/// A String always holds whole scalars, so a code-unit match always starts and
/// ends on a scalar boundary.
enum DartString {
    /// `haystack.contains(needle)`; true for an empty needle.
    static func contains(_ haystack: String, _ needle: String) -> Bool {
        firstIndex(Array(haystack.utf16), of: Array(needle.utf16), from: 0) != nil
    }

    /// `s.startsWith(prefix)`.
    static func hasPrefix(_ s: String, _ prefix: String) -> Bool {
        s.utf16.starts(with: prefix.utf16)
    }

    /// `s.split(separator)`. An empty separator cuts every code unit, but a
    /// surrogate pair stays whole: Dart's lone surrogates cannot live in a
    /// Swift String (gate 08), and this keeps split/join a round trip.
    static func split(_ s: String, _ separator: String) -> [String] {
        if separator.isEmpty { return s.unicodeScalars.map { String($0) } }
        let units = Array(s.utf16)
        let sep = Array(separator.utf16)
        var parts: [String] = []
        var start = 0
        while let found = firstIndex(units, of: sep, from: start) {
            parts.append(String(decoding: units[start..<found], as: UTF16.self))
            start = found + sep.count
        }
        parts.append(String(decoding: units[start...], as: UTF16.self))
        return parts
    }

    private static func firstIndex(_ units: [UInt16], of needle: [UInt16], from start: Int) -> Int? {
        guard needle.count <= units.count - start else { return nil }
        for i in start...(units.count - needle.count) where units[i..<(i + needle.count)].elementsEqual(needle) {
            return i
        }
        return nil
    }
}

// MARK: - Placeholders

enum Placeholders {
    /// `{{name}}`, identifier-only, byte for byte with the TS, engine-dart and
    /// Flutter implementations.
    static let pattern = try! NSRegularExpression(
        pattern: "\\{\\{\\s*([A-Za-z_$][A-Za-z0-9_$]*)\\s*\\}\\}")

    /// `{{value}}` is the previous pipeline output, other names come from
    /// `params` (resolved); unknown names render as "".
    static func expand(
        _ template: String, _ current: JSONValue, _ params: [String: JSONValue]?,
        _ resolver: ValueResolver
    ) -> String {
        let ns = template as NSString
        var out = ""
        var cursor = 0
        for m in pattern.matches(in: template, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            let name = ns.substring(with: m.range(at: 1))
            if name == "value" {
                out += current.isNull ? "" : DartFormat.string(current)
            } else if let raw = params?[name] {
                let resolved = resolver.resolve(raw)
                out += resolved.isNull ? "" : DartFormat.string(resolved)
            }
            cursor = m.range.location + m.range.length
        }
        out += ns.substring(from: cursor)
        return out
    }
}

// MARK: - Regex

/// NSRegularExpression (ICU) standing in for Dart's ECMAScript `RegExp`, with
/// the same guard rails: patterns over 200 UTF-16 units are refused and the
/// input is clipped to 10 000 units.
enum Regex {
    static let maxPatternLength = 200
    static let maxInputLength = 10_000

    struct Match {
        let result: NSTextCheckingResult
        let source: NSString
        var range: NSRange { result.range }
        var groupCount: Int { result.numberOfRanges - 1 }

        func group(_ i: Int) -> String? {
            guard i < result.numberOfRanges else { return nil }
            let r = result.range(at: i)
            return r.location == NSNotFound ? nil : source.substring(with: r)
        }
    }

    static func compile(_ pattern: String, flags: String?) -> NSRegularExpression? {
        let flags = flags ?? ""
        var options: NSRegularExpression.Options = []
        if flags.contains("i") { options.insert(.caseInsensitive) }
        if flags.contains("m") { options.insert(.anchorsMatchLines) }
        if flags.contains("s") { options.insert(.dotMatchesLineSeparators) }
        // ICU refuses "", which Dart accepts (it matches "" everywhere).
        guard let source = pattern.isEmpty
            ? "(?:)" : asciiClasses(pattern, ignoreCase: flags.contains("i"), unicode: flags.contains("u"))
        else { return nil }
        return try? NSRegularExpression(pattern: source, options: options)
    }

    /// Rewrites Dart's (ECMAScript) pattern where ICU reads the same text
    /// another way, or nil where Dart refuses it. Every other escape, `\\`
    /// included, is copied as is, as are group names, modifier flags and
    /// what follows `\c`, `\k<` and `\p{`, and the digits of `\xHH` and
    /// `\uHHHH` (but for a letter of the table, below); `\s` stays Unicode,
    /// as Dart's is.
    ///
    /// - After `(?` Dart reads only `:`, `=`, `!`, `<=`, `<!`, a group name
    ///   (`<name>`) and modifiers: flags from `ims`, each at most once, then
    ///   optionally `-` and more, then `:`, not both sides empty (`(?ms-i:`).
    ///   Any other form, `(?i)`, `(?x:`, `(?>`, `(?#` among them, is nil.
    /// - `i` below is the one in force where the text sits: the pattern's,
    ///   or that of the innermost modifier group around it (`(?i:`, `(?-i:`),
    ///   to its `)`. ICU scopes the copied flags the same way, so inside
    ///   `(?-i:` letters stay as written and inside `(?i:` they fold as below.
    /// - `\d \w \D \W` are ASCII in Dart and Unicode in ICU, which has no
    ///   ASCII switch, so they are spelled out as sets. Inside a class
    ///   (`[\w.]`) the set nests, and ICU unions it with the rest.
    /// - `\b` and `\B` are ASCII word edges in Dart, so they become
    ///   lookarounds on the word set. Inside a class `[\b]` is a backspace,
    ///   which ICU would read as the letter b.
    /// - The word set is `[A-Za-z0-9_]`, with ſ (U+017F) and K (U+212A) added
    ///   when `i` and `u` are both on (Unicode folding sends them to s and k).
    ///   Outside a class it sits in `(?-i:…)`: ICU's `i` would add those two.
    /// - Under `i`, ICU folds some letters another way than Dart: ſ and K
    ///   into ASCII, Å (U+212B) into å, `ß` into "ss", "ff" into `ﬀ`. Dart's
    ///   fold table (`foldTable`, its letters `foldLetters`) holds them, the
    ///   letters such foldings start with and their partners, so these never
    ///   go to ICU's folding. Outside a class each is the case-sensitive set
    ///   Dart folds it to (`dartFold`): `s` is `(?-i:[Ss])`, with `u`
    ///   `(?-i:[Ssſ])`. A class C becomes `(?:(?!T)C|(?-i:[M]))`, T the
    ///   table's letters and M those C matches in Dart, found by running C,
    ///   compiled case-sensitively, once over T. Every other letter keeps
    ///   ICU's folding (é with É). An escape that spells a letter of the
    ///   table (`\x73`, `\u017F`, with `u` `\u{17F}`) is that letter: outside
    ///   a class the same set, inside one ICU reads it in C. Left as ICU has
    ///   them: backreferences.
    /// - With `u`, `\u{H…}` (hex digits, at most U+10FFFF) becomes ICU's
    ///   `\x{H…}`, in a class too, without leading zeros: ICU refuses `\u{`
    ///   and reads at most six digits. Any other `\u{…}` Dart refuses, so it
    ///   is nil. Without `u` it is copied as is.
    /// - With `u`, Dart reads the name in `\p{…}` and `\P{…}` by ECMA-262's
    ///   tables (`dartAcceptsProperty`), in a class too: a name it refuses
    ///   (`IsLatin`, `Latin`, `L&`, `script=Latin`), which ICU may read, is
    ///   nil. Without `u` it is copied as is.
    static func asciiClasses(_ pattern: String, ignoreCase: Bool, unicode: Bool) -> String? {
        // The sets and edges under a group whose `i` is `fold`.
        func escapes(_ fold: Bool) -> (sets: [Unicode.Scalar: String], edges: [Unicode.Scalar: String]) {
            let word = fold && unicode ? "A-Za-z0-9_\\u017F\\u212A" : "A-Za-z0-9_"
            let w = "[\(word)]"
            return (
                ["d": "[0-9]", "D": "[^0-9]", "w": w, "W": "[^\(word)]"],
                [
                    "b": "(?-i:(?<=\(w))(?!\(w))|(?<!\(w))(?=\(w)))",
                    "B": "(?-i:(?<=\(w))(?=\(w))|(?<!\(w))(?!\(w)))",
                ]
            )
        }

        let p = Array(pattern.unicodeScalars)
        var i = 0
        var out = ""
        var scope: [Bool] = []  // the `i` of each open group, innermost last
        func next(_ k: Int) -> Unicode.Scalar? { i + k < p.count ? p[i + k] : nil }
        func take(_ n: Int) {
            for _ in 0..<n where i < p.count {
                out.unicodeScalars.append(p[i])
                i += 1
            }
        }
        func take(through close: Unicode.Scalar) {
            while let c = next(0) {
                take(1)
                if c == close { return }
            }
        }
        // At `(?` and no lookaround: the `i` of the modifier group (`(?:`,
        // `(?ms-i:`) inside `fold`, or nil when Dart refuses the form.
        func modifiers(_ fold: Bool) -> Bool? {
            var k = 2
            var seen: Set<Unicode.Scalar> = []
            var off = false
            var inner = fold
            while let f = next(k), f != ":" {
                if f == "-", !off {
                    off = true
                } else if "ims".unicodeScalars.contains(f), seen.insert(f).inserted {
                    if f == "i" { inner = !off }
                } else {
                    return nil
                }
                k += 1
            }
            return next(k) == ":" && (!seen.isEmpty || !off) ? inner : nil
        }
        // At `\`: the code point `\xHH`, `\uHHHH` or, with `u`, `\u{H…}` spells,
        // and the escape's length; nil for any other escape. A `\u{…}` Dart
        // refuses (no digit, one not hex, no `}`, past U+10FFFF) has no value.
        func hexEscape() -> (value: UInt32?, length: Int)? {
            guard next(0) == "\\", let n = next(1), n == "x" || n == "u" else { return nil }
            func digit(_ k: Int) -> UInt32? {
                guard let d = next(k), d.properties.isASCIIHexDigit else { return nil }
                return UInt32(String(d), radix: 16)
            }
            var value: UInt32 = 0
            var k = 2
            if n == "u", unicode, next(2) == "{" {
                k = 3
                while let h = digit(k), value <= 0x10FFFF {
                    value = value * 16 + h
                    k += 1
                }
                return (k > 3 && next(k) == "}" && value <= 0x10FFFF ? value : nil, k + 1)
            }
            for _ in 0..<(n == "x" ? 2 : 4) {
                guard let h = digit(k) else { return nil }
                value = value * 16 + h
                k += 1
            }
            return (value, k)
        }
        // ICU refuses `\u{` and reads at most six digits in `\x{…}`.
        func braced(_ value: UInt32) -> String { "\\x{\(String(value, radix: 16, uppercase: true))}" }
        // At `\p{` or `\P{` with `u`: the escape's length through its `}`, or
        // nil when there is no `}` or Dart refuses the name.
        func propertyEscape() -> Int? {
            guard let close = p[i...].firstIndex(of: "}"),
                dartAcceptsProperty(String(String.UnicodeScalarView(p[(i + 3)..<close])))
            else { return nil }
            return close + 1 - i
        }
        // A class up to its first unescaped `]`, as ECMAScript reads it: its
        // body, whether it is negated, and whether it closes; nil where Dart
        // refuses a `\u{…}` or, with `u`, a property name in it.
        func classSet(_ sets: [Unicode.Scalar: String]) -> (body: String, negated: Bool, closed: Bool)? {
            var body = ""
            i += 1
            let negated = next(0) == "^"
            if negated { i += 1 }
            while let c = next(0) {
                if next(2) == "{", let escape = hexEscape() {  // `\u{…}` with `u`
                    guard let value = escape.value else { return nil }
                    body += braced(value)
                    i += escape.length
                    continue
                }
                if unicode, c == "\\", next(1) == "p" || next(1) == "P", next(2) == "{" {
                    guard let length = propertyEscape() else { return nil }
                    body.unicodeScalars.append(contentsOf: p[i..<(i + length)])
                    i += length
                    continue
                }
                i += 1
                if c == "]" { return (body, negated, true) }
                guard c == "\\", let n = next(0) else {
                    body.unicodeScalars.append(c)
                    continue
                }
                i += 1
                body += n == "b" ? "\\u0008" : sets[n] ?? "\\\(n)"
            }
            return (body, negated, false)
        }

        while let c = next(0) {
            let fold = scope.last ?? ignoreCase
            let (sets, edges) = escapes(fold)
            if c == "[" {
                guard case let (body, negated, closed)? = classSet(sets) else { return nil }
                let set = "[" + (negated ? "^" : "") + body + (closed ? "]" : "")
                out += fold && closed ? dartFolded(set, body: body, negated: negated, unicode: unicode) : set
            } else if c == "\\", let n = next(1) {
                if let set = sets[n] {
                    out += "(?-i:\(set))"
                    i += 2
                } else if let edge = edges[n] {
                    out += edge
                    i += 2
                } else if n == "k", next(2) == "<" {
                    take(through: ">")  // `\k<name>` keeps its letters
                } else if n == "p" || n == "P", next(2) == "{" {
                    guard !unicode || propertyEscape() != nil else { return nil }  // a name Dart refuses
                    take(through: "}")  // and so does `\p{Script=Latin}`
                } else if let escape = hexEscape() {
                    // `\x73`, `\u017F`, `\u{17F}`: a letter of the table is that letter
                    guard let value = escape.value else { return nil }
                    if fold, let set = Unicode.Scalar(value).flatMap({ dartFold($0, unicode: unicode) }) {
                        out += "(?-i:[\(spelled(set))])"
                        i += escape.length
                    } else if next(2) == "{" {
                        out += braced(value)
                        i += escape.length
                    } else {
                        take(escape.length)  // `\x4a`, `\u00ff`: digits that may be letters of the table
                    }
                } else {
                    take(n == "c" ? 3 : 2)  // `\cK`, and `\x`, `\u` without their digits
                }
            } else if c == "(" {
                var inner: Bool? = fold  // a group keeps the `i` around it
                if next(1) != "?" || next(2) == "=" || next(2) == "!"
                    || next(2) == "<" && (next(3) == "=" || next(3) == "!")
                {
                    take(1)  // a group or a lookaround
                } else if next(2) == "<" {
                    take(through: ">")  // a group name
                } else {
                    inner = modifiers(fold)
                    take(through: ":")  // `(?-i:`, whose flags ICU reads as Dart does
                }
                guard let inner else { return nil }
                scope.append(inner)
            } else if c == ")" {
                _ = scope.popLast()  // an unbalanced `)` is ICU's to refuse
                take(1)
            } else if fold, let set = dartFold(c, unicode: unicode) {
                out += "(?-i:[\(spelled(set))])"
                i += 1
            } else {
                take(1)
            }
        }
        return out
    }

    /// The letters of Dart's fold table (`foldTable`), in code point order.
    static let foldLetters = foldTable.keys.sorted { $0.value < $1.value }

    /// The letters Dart's `i` matches `c` to, without `u` or with it, or nil
    /// for a letter outside `foldTable`.
    static func dartFold(_ c: Unicode.Scalar, unicode: Bool) -> [Unicode.Scalar]? {
        foldTable[c].map { unicode ? $0.unicode : $0.plain }
    }

    /// Keeps a class's ICU folding off `foldLetters`; and those letters in
    /// one string, to run a class over each of them once.
    private static let notFoldLetter = "(?!(?-i:[\(spelled(foldLetters))]))"
    private static let foldLetterText = String(String.UnicodeScalarView(foldLetters))

    /// The class `set` (`[body]`, or `[^body]` when `negated`) under `i`, with
    /// `foldLetters` matching as in Dart. An empty class, or one ICU refuses,
    /// stays as it is.
    private static func dartFolded(_ set: String, body: String, negated: Bool, unicode: Bool) -> String {
        // C case-sensitively; `[^^a]` has the body `^a`, which ICU would read as negated.
        // The first scalar, not Character: `[^^\u{301}a]` has the body "^\u{301}a".
        guard !body.isEmpty,
            let held = try? NSRegularExpression(
                pattern: "[" + (body.unicodeScalars.first == "^" ? "\\" : "") + body + "]")
        else { return set }
        let members = Set(allMatches(held, in: foldLetterText).compactMap { $0.group(0)?.unicodeScalars.first })
        let matched = foldLetters.filter { c in
            (dartFold(c, unicode: unicode) ?? []).contains(where: members.contains) != negated
        }
        let exact = matched.isEmpty ? "" : "|(?-i:[\(spelled(matched))])"
        return "(?:\(notFoldLetter)\(set)\(exact))"
    }

    /// Letters as ICU set members, the non-ASCII ones as `\uXXXX`.
    private static func spelled(_ letters: [Unicode.Scalar]) -> String {
        letters.map { $0.isASCII ? String(Character($0)) : String(format: "\\u%04X", $0.value) }.joined()
    }

    static func clip(_ s: String) -> String {
        let units = s.utf16
        guard units.count > maxInputLength else { return s }
        let end = units.index(units.startIndex, offsetBy: maxInputLength)
        return String(units[..<end]) ?? String(decoding: Array(units[..<end]), as: UTF16.self)
    }

    private static func wrap(_ r: NSTextCheckingResult, _ input: String) -> Match {
        Match(result: r, source: input as NSString)
    }

    static func firstMatch(_ re: NSRegularExpression, in input: String) -> Match? {
        let range = NSRange(location: 0, length: (input as NSString).length)
        return re.firstMatch(in: input, range: range).map { wrap($0, input) }
    }

    static func allMatches(_ re: NSRegularExpression, in input: String) -> [Match] {
        let range = NSRange(location: 0, length: (input as NSString).length)
        return re.matches(in: input, range: range).map { wrap($0, input) }
    }

    /// Dart: `replacement.replaceAllMapped(RegExp(r'\$([1-9])'), ...)`; a group
    /// past the pattern's count, or one that did not take part, is "".
    static func expandBackrefs(_ replacement: String, _ m: Match) -> String {
        var out = ""
        var chars = replacement.makeIterator()
        var pending: Character? = chars.next()
        while let c = pending {
            pending = chars.next()
            if c == "$", let d = pending, let n = d.wholeNumberValue, (1...9).contains(n),
                d.isASCII
            {
                out += n > m.groupCount ? "" : (m.group(n) ?? "")
                pending = chars.next()
            } else {
                out.append(c)
            }
        }
        return out
    }
}

// MARK: - Dates

struct DateParts {
    var year, month, day, hour, minute, second: Int

    init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    init?(_ value: JSONValue) {
        switch value {
        case .int, .double:
            // JS Dates span ±8.64e15 ms; outside that is an Invalid Date.
            guard let ms = value.doubleValue, ms.isFinite, Swift.abs(ms) <= 8.64e15 else { return nil }
            self.init(epochMillis: ms)
        case .string(let s):
            self.init(iso: s)
        default:
            return nil
        }
    }

    init(epochMillis ms: Double) {
        let date = Date(timeIntervalSince1970: ms / 1000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        self.init(
            year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0,
            hour: c.hour ?? 0, minute: c.minute ?? 0, second: c.second ?? 0)
    }

    /// `YYYY-MM-DD[(T| )HH:MM[:SS[.fff]]][Z|±HH[:]MM]`, as Dart's
    /// `DateTime.tryParse` reads it.
    init?(iso s: String) {
        let pattern = #"^([+-]?\d{4,6})-?(\d\d)-?(\d\d)(?:[T ](\d\d)(?::?(\d\d)(?::?(\d\d)(?:[.,]\d+)?)?)?)?\s*(Z|[+-]\d\d(?::?\d\d)?)?$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let m = re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length))
        else { return nil }
        let ns = s as NSString
        func group(_ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        guard let y = Int(group(1) ?? ""), let mo = Int(group(2) ?? ""), let d = Int(group(3) ?? "")
        else { return nil }
        let h = Int(group(4) ?? "0") ?? 0
        let mi = Int(group(5) ?? "0") ?? 0
        let sec = Int(group(6) ?? "0") ?? 0
        guard (1...12).contains(mo), (1...31).contains(d), h <= 24, mi < 60, sec < 60 else { return nil }

        if let zone = group(7), zone.uppercased() != "Z" {
            let sign = zone.hasPrefix("-") ? -1 : 1
            let digits = zone.dropFirst().filter(\.isNumber)
            let oh = Int(digits.prefix(2)) ?? 0
            let om = Int(digits.dropFirst(2)) ?? 0
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let comps = DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: sec)
            guard let local = calendar.date(from: comps) else { return nil }
            let utc = local.addingTimeInterval(-Double(sign * (oh * 3600 + om * 60)))
            self.init(epochMillis: utc.timeIntervalSince1970 * 1000)
            return
        }
        self.init(year: y, month: mo, day: d, hour: h, minute: mi, second: sec)
    }
}
