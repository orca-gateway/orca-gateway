import Foundation

/// Without `u` Dart reads a pattern and its input as UTF-16 code units: each
/// half of a surrogate pair is one character to `.`, a class or a quantifier,
/// an empty match falls between the halves, and a letter above U+FFFF never
/// folds. ICU reads code points and never stops inside a pair, and no pattern
/// rewrite reaches that, so such a run searches a masked copy of the input.
///
/// Every surrogate unit of the input, and each one the pattern names (the
/// halves of a character above U+FFFF, a `\uHHHH` escape, which a class
/// member or a range end may be), becomes a stand-in: a private-use unit
/// (U+E000-F8FF) that neither the input nor the pattern holds, the lowest
/// first, one per distinct unit, in the units' order. The copy has the
/// input's UTF-16 length, so a match range in it is the same range in the
/// input, which the result, match 0 and every `$n` are read from. A stand-in
/// has no case, so under `i` a half matches only itself, as in Dart.
///
/// The reader (`Regex.asciiClasses`) splits a character above U+FFFF into its
/// halves' stand-ins (`scalars`), but in a group name, which Dart reads by code
/// point; writes a `\uHHHH` half as its stand-in; checks a class range on
/// Dart's units; and writes a range over surrogates, or one reaching a
/// stand-in, as its parts outside the surrogate block without the stand-ins,
/// plus the stand-ins of the halves it covers (`range`). A run with `u`, or
/// with no half anywhere, is not masked; one whose input holds so many
/// private-use characters that too few units are left runs unmasked.
struct RegexMask {
    /// The masked units, each to its stand-in.
    private let standIns: [UInt16: UInt16]
    /// Each stand-in to the unit it stands for.
    private let units: [UInt16: UInt16]
    /// The stand-ins, ascending.
    private let sortedStandIns: [UInt16]

    /// The private-use units free for stand-ins, lowest first: those neither
    /// the input nor the pattern holds. One per call, which every stand-in
    /// comes from.
    struct Pool {
        private var next: UInt32 = 0xE000
        private let held: Set<UInt16>

        init(held: Set<UInt16>) { self.held = held }

        mutating func take() -> UInt16? {
            while next <= 0xF8FF {
                let unit = UInt16(next)
                next += 1
                if !held.contains(unit) { return unit }
            }
            return nil
        }
    }

    /// The mask for `pattern` over `input`, or nil where the run needs none:
    /// with `u`, with no surrogate unit in the input or named by the pattern,
    /// or with too few private-use units left for stand-ins.
    init?(pattern: String, flags: String?, input: String) {
        guard !(flags ?? "").contains("u") else { return nil }
        var halves: Set<UInt16> = []
        var held: Set<UInt16> = []
        func note(_ value: UInt32) {
            if (0xD800...0xDFFF).contains(value) {
                halves.insert(UInt16(value))
            } else if (0xE000...0xF8FF).contains(value) {
                held.insert(UInt16(value))
            }
        }
        for unit in input.utf16 { note(UInt32(unit)) }
        let p = Array(pattern.unicodeScalars)
        var k = 0
        // Read conservatively: a character, or the value a `\uHHHH` or `\u{H…}` escape spells.
        while k < p.count {
            if p[k] == "\\", k + 1 < p.count, p[k + 1] == "u", let (value, length) = Self.escape(p, at: k) {
                note(value)
                k += length
                continue
            }
            let c = p[k]
            if c.value > 0xFFFF {
                note(UInt32(UTF16.leadSurrogate(c)))
                note(UInt32(UTF16.trailSurrogate(c)))
            } else {
                note(c.value)
            }
            k += 1
        }
        guard !halves.isEmpty else { return nil }
        var pool = Pool(held: held)
        var standIns: [UInt16: UInt16] = [:]
        var units: [UInt16: UInt16] = [:]
        var sorted: [UInt16] = []
        for half in halves.sorted() {
            guard let standIn = pool.take() else { return nil }
            standIns[half] = standIn
            units[standIn] = half
            sorted.append(standIn)
        }
        self.standIns = standIns
        self.units = units
        sortedStandIns = sorted
    }

    /// At `\u` in `p`: the value of `\uHHHH`, or of `\u{H…}`, and the escape's
    /// length; nil for any other form.
    private static func escape(_ p: [Unicode.Scalar], at k: Int) -> (UInt32, Int)? {
        func hex(_ j: Int) -> UInt32? {
            guard j < p.count, p[j].properties.isASCIIHexDigit else { return nil }
            return UInt32(String(p[j]), radix: 16)
        }
        var value: UInt32 = 0
        if k + 2 < p.count, p[k + 2] == "{" {
            var j = k + 3
            while let h = hex(j), value <= 0x10FFFF {
                value = value * 16 + h
                j += 1
            }
            return j > k + 3 && j < p.count && p[j] == "}" ? (value, j + 1 - k) : nil
        }
        for j in (k + 2)..<(k + 6) {
            guard let h = hex(j) else { return nil }
            value = value * 16 + h
        }
        return (value, 6)
    }

    /// The stand-in for the surrogate unit `value`, nil for any other value.
    func standIn(forUnit value: UInt32) -> UInt16? {
        value <= 0xFFFF ? standIns[UInt16(value)] : nil
    }

    /// The code unit Dart reads where the pattern holds `value`: the unit a
    /// stand-in stands for, any other value itself.
    func dartUnit(_ value: UInt32) -> UInt32 {
        value <= 0xFFFF ? units[UInt16(value)].map(UInt32.init) ?? value : value
    }

    /// The input with every surrogate unit as its stand-in: valid Unicode of
    /// the same UTF-16 length.
    func copy(of input: String) -> String {
        String(decoding: input.utf16.map { standIns[$0] ?? $0 }, as: UTF16.self)
    }

    /// The pattern's characters, each above U+FFFF as its halves' two
    /// stand-ins, but in a group name (`(?<name>`, and `\k<name>` outside a
    /// class once a group has a name), which Dart reads by code point.
    func scalars(of pattern: String) -> [Unicode.Scalar] {
        let p = Array(pattern.unicodeScalars)
        // At `(`: whether it opens a group name, `(?<` and no lookbehind.
        func opensName(_ k: Int) -> Bool {
            k + 3 < p.count && p[k + 1] == "?" && p[k + 2] == "<" && p[k + 3] != "=" && p[k + 3] != "!"
        }
        var named = false
        var inClass = false
        var k = 0
        while k < p.count {  // whether a group has a name: then `\k<name>` reads one
            let c = p[k]
            if c == "\\" {
                k += 1
            } else if inClass {
                inClass = c != "]"
            } else if c == "[" {
                inClass = true
            } else if c == "(", opensName(k) {
                named = true
            }
            k += 1
        }
        var out: [Unicode.Scalar] = []
        func append(_ c: Unicode.Scalar) {
            guard c.value > 0xFFFF else { return out.append(c) }
            for half in [UTF16.leadSurrogate(c), UTF16.trailSurrogate(c)] {
                out.append(Unicode.Scalar(standIns[half] ?? half) ?? c)
            }
        }
        // Through the first `>`, as the reader takes a name; to the end without one.
        func name() {
            while k < p.count {
                out.append(p[k])
                k += 1
                if p[k - 1] == ">" { return }
            }
        }
        inClass = false
        k = 0
        while k < p.count {
            let c = p[k]
            if c == "\\", k + 1 < p.count {
                out.append(c)
                k += 1
                if !inClass, named, p[k] == "k", k + 1 < p.count, p[k + 1] == "<" {
                    name()
                } else {
                    append(p[k])
                    k += 1
                }
                continue
            }
            if inClass {
                inClass = c != "]"
            } else if c == "[" {
                inClass = true
            } else if c == "(", opensName(k) {
                name()
                continue
            }
            append(c)
            k += 1
        }
        return out
    }

    /// The class range `a-b` over Dart's units: its parts outside the
    /// surrogate block, without the stand-ins, and the stand-ins of the halves
    /// it covers; nil where it meets no surrogate and holds no stand-in, so it
    /// is written as it stands.
    func range(_ a: UInt32, _ b: UInt32) -> (parts: [ClosedRange<UInt32>], standIns: [UInt16])? {
        let held = sortedStandIns.filter { (a...b).contains(UInt32($0)) }
        guard a <= 0xDFFF && b >= 0xD800 || !held.isEmpty else { return nil }
        var parts: [ClosedRange<UInt32>] = []
        if a < 0xD800 { parts.append(a...min(b, 0xD7FF)) }
        if b > 0xDFFF {
            var low = max(a, 0xE000)
            for s in held.map(UInt32.init) where s >= low {
                if s > low { parts.append(low...(s - 1)) }
                low = s + 1
            }
            if low <= b { parts.append(low...b) }
        }
        let covered = standIns.filter { (a...b).contains(UInt32($0.key)) }.map { $0.value }.sorted()
        return (parts, covered)
    }
}

extension Regex {
    /// A pattern compiled for one input: ICU searches `searched`, the input or
    /// its masked copy (`RegexMask`), of the same UTF-16 length, and every
    /// match is read from `original`, the input.
    struct Run {
        let regex: NSRegularExpression
        let searched: String
        let original: NSString
    }

    /// The run of Dart's `RegExp(pattern)` with `flags` over `input`, masked
    /// where Dart reads code units the engine would not; nil where Dart
    /// refuses the pattern. The `regex` transform and the `matches` op call it.
    static func run(_ pattern: String, flags: String?, input: String) -> Run? {
        let mask = RegexMask(pattern: pattern, flags: flags, input: input)
        guard let regex = compile(pattern, flags: flags, mask: mask) else { return nil }
        return Run(regex: regex, searched: mask?.copy(of: input) ?? input, original: input as NSString)
    }
}
