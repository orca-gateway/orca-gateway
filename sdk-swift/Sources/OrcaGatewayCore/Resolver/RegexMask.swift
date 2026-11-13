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
/// half's stand-in, as its parts outside the surrogate block without the
/// halves' stand-ins, plus the stand-ins of the halves it covers (`range`).
/// A run with `u`, or with no half anywhere, is not masked for halves.
///
/// Under `i` a backreference compares the text its group took with the input,
/// both folded: Dart without `u` canonicalizes by upper case and never maps a
/// non-ASCII letter to ASCII, with `u` it folds simply, and ICU compares by full
/// case folding (ß with "ss"), only by the case pairs its own Unicode has. So
/// where `i` is in force anywhere and the reader writes a backreference
/// (`foldsReference`), each letter of the input whose folding there ICU does
/// not share with Dart (`foldsApart`, or a letter of a class the ICU lags on,
/// `Regex.laggingLetters`, above U+FFFF only with `u`) becomes the stand-in of
/// its Dart fold class (`Regex.dartSet`, the flags' `u`): one per class, taken
/// from the same pool after the halves', in code point order. A letter above
/// U+FFFF takes a stand-in of two units (`Pool.takeWide`), and no class mixes
/// such letters with others, so the copy keeps the input's length. A stand-in
/// matches only itself, as the class's letters match each other in Dart, and
/// in the pattern such a letter is its stand-in too (`standIn(forLetter:)`);
/// a class or property Dart matches it with takes the stand-in (the reader).
/// Where `i` is off, the letters of one class (with `u`: ß and ẞ) share their
/// stand-in, a known limit. A run whose input holds so many private-use
/// characters that too few units are left runs unmasked.
struct RegexMask {
    /// The masked surrogate units, each to its stand-in.
    private let standIns: [UInt16: UInt16]
    /// Each half's stand-in to the unit it stands for.
    private let units: [UInt16: UInt16]
    /// The halves' stand-ins, ascending.
    private let sortedStandIns: [UInt16]
    /// Each letter masked for a backreference under `i`, to its class's stand-in,
    /// by code point.
    private let letterStandIns: [UInt32: UInt32]
    /// Those letters, every member of each class with a stand-in, ascending.
    let letters: [Unicode.Scalar]
    /// Their stand-ins, ascending.
    let lettersStandIns: [Unicode.Scalar]

    /// The private-use characters free for stand-ins, lowest first: those
    /// neither the input nor the pattern holds. One per call, which every
    /// stand-in comes from: units (U+E000-F8FF), and for a letter above
    /// U+FFFF characters of two units (U+F0000-FFFFD, then U+100000-10FFFD).
    struct Pool {
        private var next: UInt32 = 0xE000
        private var nextWide: UInt32 = 0xF0000
        private let held: Set<UInt16>
        private let heldWide: Set<UInt32>

        init(held: Set<UInt16>, heldWide: Set<UInt32> = []) {
            self.held = held
            self.heldWide = heldWide
        }

        mutating func take() -> UInt16? {
            while next <= 0xF8FF {
                let unit = UInt16(next)
                next += 1
                if !held.contains(unit) { return unit }
            }
            return nil
        }

        /// A free character of two units, nil when none is left.
        mutating func takeWide() -> UInt32? {
            while nextWide <= 0x10FFFD {
                let value = nextWide
                nextWide = value == 0xFFFFD ? 0x100000 : value + 1
                if !heldWide.contains(value) { return value }
            }
            return nil
        }
    }

    /// The mask for `pattern` over `input`, or nil where the run needs none:
    /// with no half to mask (with `u`, or with no surrogate unit in the input
    /// or named by the pattern) and no letter, or with too few private-use
    /// units left for stand-ins.
    init?(pattern: String, flags: String?, input: String) {
        let flags = flags ?? ""
        let unicode = flags.contains("u")
        var halves: Set<UInt16> = []
        var held: Set<UInt16> = []
        var heldWide: Set<UInt32> = []
        func note(_ value: UInt32) {
            if (0xD800...0xDFFF).contains(value) {
                if !unicode { halves.insert(UInt16(value)) }  // with `u` Dart reads code points, as ICU does
            } else if (0xE000...0xF8FF).contains(value) {
                held.insert(UInt16(value))
            } else if value >= 0xF0000 {
                heldWide.insert(value)
            }
        }
        // A character, and above U+FFFF its halves.
        func note(character c: Unicode.Scalar) {
            if c.value > 0xFFFF {
                note(UInt32(UTF16.leadSurrogate(c)))
                note(UInt32(UTF16.trailSurrogate(c)))
            }
            note(c.value)
        }
        for c in input.unicodeScalars { note(character: c) }
        let p = Array(pattern.unicodeScalars)
        var k = 0
        // Read conservatively: a character, or the value a `\uHHHH` or `\u{H…}` escape spells, and a high half's
        // escape then a low half's as the one character ICU reads them as.
        while k < p.count {
            if p[k] == "\\", k + 1 < p.count, p[k + 1] == "u", let (value, length) = Self.escape(p, at: k) {
                note(value)
                k += length
                if (0xD800...0xDBFF).contains(value), k + 1 < p.count, p[k] == "\\", p[k + 1] == "u",
                    let (low, _) = Self.escape(p, at: k), (0xDC00...0xDFFF).contains(low)
                {
                    note(0x10000 + ((value - 0xD800) << 10) + (low - 0xDC00))
                }
                continue
            }
            note(character: p[k])
            k += 1
        }
        var folding: Set<Unicode.Scalar> = []
        if Self.foldsReference(p, ignoreCase: flags.contains("i"), unicode: unicode) {
            let lagging = Regex.laggingLetters
            folding = Set(input.unicodeScalars.filter { c in
                c.value > 0xFFFF
                    ? unicode && lagging.contains(c)
                    : Self.foldsApart(UInt16(c.value), unicode: unicode) || lagging.contains(c)
            })
        }
        guard !halves.isEmpty || !folding.isEmpty else { return nil }
        var pool = Pool(held: held, heldWide: heldWide)
        var standIns: [UInt16: UInt16] = [:]
        var units: [UInt16: UInt16] = [:]
        var sorted: [UInt16] = []
        for half in halves.sorted() {
            guard let standIn = pool.take() else { return nil }
            standIns[half] = standIn
            units[standIn] = half
            sorted.append(standIn)
        }
        var letterStandIns: [UInt32: UInt32] = [:]
        for letter in folding.sorted(by: { $0.value < $1.value }) where letterStandIns[letter.value] == nil {
            guard let standIn = letter.value > 0xFFFF ? pool.takeWide() : pool.take().map(UInt32.init) else {
                return nil
            }
            let members = Regex.dartSet(letter, unicode: unicode) ?? []
            for member in members + [letter] { letterStandIns[member.value] = standIn }
        }
        self.standIns = standIns
        self.units = units
        sortedStandIns = sorted
        self.letterStandIns = letterStandIns
        letters = letterStandIns.keys.sorted().compactMap(Unicode.Scalar.init)
        lettersStandIns = Set(letterStandIns.values).sorted().compactMap(Unicode.Scalar.init)
    }

    /// The letters whose full case folding is two or more letters (Unicode's
    /// CaseFolding.txt, status F), which ICU compares a backreference under `i`
    /// by: ß and ẞ with "ss", ﬀ with "ff", İ with i and a combining dot above,
    /// ᾀ with ἀι.
    private static let fullFolding: Set<UInt16> = Set(
        ([
            0xDF...0xDF, 0x130...0x130, 0x149...0x149, 0x1F0...0x1F0, 0x390...0x390, 0x3B0...0x3B0, 0x587...0x587,
            0x1E96...0x1E9A, 0x1E9E...0x1E9E, 0x1F50...0x1F50, 0x1F52...0x1F52, 0x1F54...0x1F54, 0x1F56...0x1F56,
            0x1F80...0x1FAF, 0x1FB2...0x1FB4, 0x1FB6...0x1FB7, 0x1FBC...0x1FBC, 0x1FC2...0x1FC4, 0x1FC6...0x1FC7,
            0x1FCC...0x1FCC, 0x1FD2...0x1FD3, 0x1FD6...0x1FD7, 0x1FE2...0x1FE4, 0x1FE6...0x1FE7, 0x1FF2...0x1FF4,
            0x1FF6...0x1FF7, 0x1FFC...0x1FFC, 0xFB00...0xFB06, 0xFB13...0xFB17,
        ] as [ClosedRange<UInt16>]).joined()
    )

    /// Whether a backreference under `i` folds `unit` in ICU as it does not in
    /// Dart: a letter of `fullFolding` and, without `u`, ſ, ϴ, the ohm sign,
    /// the Kelvin sign and the angstrom sign, which ICU folds simply into
    /// letters Dart keeps apart (s, θ, ω, k, å). With `u` Dart folds those as
    /// ICU does.
    private static func foldsApart(_ unit: UInt16, unicode: Bool) -> Bool {
        fullFolding.contains(unit) || !unicode && [0x17F, 0x3F4, 0x2126, 0x212A, 0x212B].contains(unit)
    }

    /// Whether `i` is in force somewhere in the pattern `p`, the flags' or a
    /// modifier group's (`(?i:`, `(?mi-s:`), and the reader writes a
    /// backreference: outside a class `\N` up to the group count, or `\k` once
    /// a group has a name, or with `u`. Read as the reader's pre-pass reads
    /// it, escapes and classes aside; a pattern Dart refuses may be read as
    /// one that needs the mask, which changes nothing.
    private static func foldsReference(_ p: [Unicode.Scalar], ignoreCase: Bool, unicode: Bool) -> Bool {
        func isDigit(_ k: Int) -> Bool { k < p.count && ("0"..."9").contains(p[k]) }
        var fold = ignoreCase
        var groups = 0
        var named = false
        var numbers: [Int] = []  // what each `\N` outside a class spells
        var k = false  // whether a `\k` stands outside a class
        var j = 0
        while j < p.count {
            let c = p[j]
            if c == "\\" {
                if j + 1 < p.count, p[j + 1] == "k" { k = true }
                if isDigit(j + 1), p[j + 1] != "0" {
                    var e = j + 1
                    var number = 0
                    while isDigit(e) {
                        number = min(number * 10 + Int(p[e].value - 48), Int(UInt16.max))
                        e += 1
                    }
                    numbers.append(number)
                }
                j += 2
            } else if c == "[" {
                j += 1
                while j < p.count, p[j] != "]" { j += p[j] == "\\" ? 2 : 1 }
                j += 1
            } else {
                if c == "(", j + 1 < p.count, p[j + 1] == "?" {
                    if j + 3 < p.count, p[j + 2] == "<", p[j + 3] != "=", p[j + 3] != "!" {
                        groups += 1  // `(?<name>`
                        named = true
                    }
                    var e = j + 2
                    while e < p.count, "ims".unicodeScalars.contains(p[e]) {  // the flags a modifier group turns on
                        if p[e] == "i" { fold = true }
                        e += 1
                    }
                } else if c == "(" {
                    groups += 1
                }
                j += 1
            }
        }
        return fold && (numbers.contains { $0 <= groups } || k && (named || unicode))
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

    /// The stand-in for the surrogate unit `value`, nil for any other value
    /// and with `u`, where no half is masked.
    func standIn(forUnit value: UInt32) -> UInt16? {
        value <= 0xFFFF ? standIns[UInt16(value)] : nil
    }

    /// The stand-in of the masked letter `value`'s class, nil for a letter or
    /// value the run does not mask.
    func standIn(forLetter value: UInt32) -> UInt32? { letterStandIns[value] }

    /// The code unit Dart reads where the pattern holds `value`: the unit a
    /// half's stand-in stands for, any other value itself.
    func dartUnit(_ value: UInt32) -> UInt32 {
        value <= 0xFFFF ? units[UInt16(value)].map(UInt32.init) ?? value : value
    }

    /// The input with every surrogate unit without `u`, and every masked
    /// letter, as its stand-in: valid Unicode of the same UTF-16 length.
    func copy(of input: String) -> String {
        var units: [UInt16] = []
        units.reserveCapacity(input.utf16.count)
        for c in input.unicodeScalars {
            let letter = letterStandIns[c.value].flatMap(Unicode.Scalar.init) ?? c
            for unit in letter.utf16 { units.append(standIns[unit] ?? unit) }
        }
        return String(decoding: units, as: UTF16.self)
    }

    /// The pattern's characters, each above U+FFFF as its halves' two
    /// stand-ins, but in a group name (`(?<name>`, and `\k<name>` outside a
    /// class once a group has a name), which Dart reads by code point. With
    /// no half masked (with `u`, or letters only), the characters as they are.
    func scalars(of pattern: String) -> [Unicode.Scalar] {
        let p = Array(pattern.unicodeScalars)
        guard !standIns.isEmpty else { return p }
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
    /// surrogate block, without the halves' stand-ins, and the stand-ins of
    /// the halves it covers; nil where it meets no surrogate and holds no
    /// half's stand-in, or no half is masked, so it is written as it stands. A
    /// letter's stand-in in a range is the reader's to leave out.
    func range(_ a: UInt32, _ b: UInt32) -> (parts: [ClosedRange<UInt32>], standIns: [UInt16])? {
        guard !standIns.isEmpty else { return nil }
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
    /// where Dart reads code units the engine would not, or a backreference
    /// under `i` would fold letters as Dart does not; nil where Dart refuses
    /// the pattern. The `regex` transform and the `matches` op call it.
    static func run(_ pattern: String, flags: String?, input: String) -> Run? {
        let mask = RegexMask(pattern: pattern, flags: flags, input: input)
        guard let regex = compile(pattern, flags: flags, mask: mask) else { return nil }
        return Run(regex: regex, searched: mask?.copy(of: input) ?? input, original: input as NSString)
    }
}
