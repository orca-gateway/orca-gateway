import XCTest

@testable import OrcaGatewayCore

/// T1.3: every transform kind, table-tested against the Dart closures in
/// sdk/lib/src/state/value_resolver.dart (Dart's output in the comments where
/// it is not obvious). Where Dart throws, Swift yields null.
final class TransformTests: XCTestCase {
    private struct Row {
        let step: JSONValue
        let input: JSONValue
        let expected: JSONValue
        let line: UInt
        init(_ step: JSONValue, _ input: JSONValue, _ expected: JSONValue, line: UInt = #line) {
            self.step = step
            self.input = input
            self.expected = expected
            self.line = line
        }
        var kind: String { step["type"].stringValue ?? "" }
    }

    private static let state: [String: JSONValue] = ["n": 3, "name": "Amr", "suffix": "!", "flag": true]
    private static func s(_ v: JSONValue) -> JSONValue { ["type": "static", "value": v] }

    private let rows: [Row] = [
        // Numbers: int op int stays int, `/` is always double, `%` Euclidean.
        Row(["type": "add", "by": s(3)], 5, 8),
        Row(["type": "add", "by": s(0.5)], 5, 5.5),
        Row(["type": "add", "by": s(2)], nil, 2),  // (current ?? 0)
        Row(["type": "add", "by": ["type": "state", "key": "n"]], 1, 4),
        Row(["type": "add", "by": s("x")], 1, nil),  // Dart: TypeError
        Row(["type": "add", "by": s(1)], "1", nil),  // Dart: TypeError
        Row(["type": "subtract", "by": s(4)], 10, 6),
        Row(["type": "subtract", "by": s(1.5)], 1, -0.5),
        Row(["type": "multiply", "by": s(2)], 5, 10),
        Row(["type": "multiply", "by": s(2)], 49.99, 99.98),
        Row(["type": "divide", "by": s(2)], 6, .double(3)),
        Row(["type": "divide", "by": s(0)], 1, .double(.infinity)),
        Row(["type": "modulo", "by": s(3)], 7, 1),
        Row(["type": "modulo", "by": s(3)], -7, 2),  // Euclidean
        Row(["type": "modulo", "by": s(-3)], -7, 2),
        Row(["type": "modulo", "by": s(2)], -7.5, 0.5),
        Row(["type": "modulo", "by": s(0)], 7, nil),  // Dart: IntegerDivisionByZero
        Row(["type": "round"], 2.5, 3),
        Row(["type": "round"], -2.5, -3),
        Row(["type": "round"], 7, 7),
        Row(["type": "round"], nil, nil),  // Dart: TypeError
        Row(["type": "floor"], -1.5, -2),
        Row(["type": "ceil"], 1.2, 2),
        Row(["type": "abs"], -4, 4),
        Row(["type": "abs"], -4.5, 4.5),
        Row(["type": "toFixed", "decimals": 2], 99.98, "99.98"),
        Row(["type": "toFixed", "decimals": 2], 5, "5.00"),
        Row(["type": "toFixed"], 1.005, "1.00"),  // binary 1.00499…
        Row(["type": "toFixed", "decimals": 2], 0.125, "0.13"),  // exact tie, away from zero
        Row(["type": "toFixed", "decimals": 0], 2.5, "3"),
        Row(["type": "toFixed", "decimals": 1], -0.25, "-0.3"),
        Row(["type": "toFixed", "decimals": 2], 9.999, "10.00"),
        Row(["type": "toFixed", "decimals": 21], 1, nil),  // Dart: RangeError

        // Strings: '$current' first, so null reads "null".
        Row(["type": "toString"], 42, "42"),
        Row(["type": "toString"], 4.0, "4.0"),
        Row(["type": "toString"], 1e21, "1e+21"),
        Row(["type": "toString"], 0.0000015, "0.0000015"),
        Row(["type": "toString"], 1.5e-7, "1.5e-7"),
        Row(["type": "toString"], nil, "null"),
        Row(["type": "toString"], [1, "a", true], "[1, a, true]"),
        Row(["type": "toUpperCase"], "straße", "STRASSE"),
        Row(["type": "toUpperCase"], nil, "NULL"),
        Row(["type": "toLowerCase"], "HeLLo", "hello"),
        Row(["type": "trim"], "  padded \n", "padded"),
        Row(["type": "template", "template": "Total: ${{value}}"], "99.98", "Total: $99.98"),
        Row(["type": "template", "template": "[{{value}}|{{missing}}]"], "x", "[x|]"),
        Row(["type": "template", "template": "{{ value }}"], nil, ""),
        Row(
            ["type": "template", "template": "{{greeting}}: {{value}}, {{name}}",
             "params": ["greeting": s("Welcome"), "name": ["type": "state", "key": "name"]]],
            "Hi", "Welcome: Hi, Amr"),
        Row(["type": "template", "template": "{{a.b}} {{1x}}"], "v", "{{a.b}} {{1x}}"),  // not identifiers
        Row(["type": "regex", "pattern": "\\d+"], "abc123def", "123"),
        Row(["type": "regex", "pattern": "\\d+"], "abc", nil),
        Row(
            ["type": "regex", "pattern": "(\\w+) (\\w+)", "replacement": "$2 $1 ({{value}}){{suffix}}",
             "params": ["suffix": ["type": "state", "key": "suffix"]]],
            "hello world", "world hello (hello world)!"),
        Row(["type": "regex", "pattern": "a", "flags": "g", "replacement": "b"], "a a a", "b b b"),
        Row(["type": "regex", "pattern": "a", "replacement": "b"], "a a a", "b a a"),
        Row(["type": "regex", "pattern": "A", "flags": "gi", "replacement": "_"], "aAa", "___"),
        Row(["type": "regex", "pattern": "(a)", "replacement": "$2$1"], "xa", "xa"),  // $2 past groups
        Row(["type": "regex", "pattern": "("], "x", nil),  // invalid pattern
        Row(["type": "regex", "pattern": .string(String(repeating: "a", count: 201))], "a", nil),
        Row(["type": "substring", "start": 1, "length": 3], "abcdef", "bcd"),
        Row(["type": "substring", "start": 2], "abcdef", "cdef"),
        Row(["type": "substring", "start": 4, "length": 5], "abcdef", nil),  // Dart: RangeError
        Row(["type": "split", "separator": ","], "a,b,,c", ["a", "b", "", "c"]),
        Row(["type": "split", "separator": ""], "abc", ["a", "b", "c"]),
        Row(["type": "split", "separator": ","], "", [""]),
        Row(["type": "join", "separator": "-"], ["a", 1, nil], "a-1-null"),
        Row(["type": "join", "separator": "-"], "solo", "solo"),

        // Booleans
        Row(["type": "not"], true, false),
        Row(["type": "not"], "true", true),  // only bool true is true
        Row(["type": "not"], nil, true),
        Row(["type": "toBool"], 0, false),
        Row(["type": "toBool"], 0.0, false),
        Row(["type": "toBool"], "", false),
        Row(["type": "toBool"], nil, false),
        Row(["type": "toBool"], "0", true),
        Row(["type": "toBool"], [], true),
        Row(["type": "toggle"], true, false),
        Row(["type": "toggle"], nil, true),
        Row(["type": "toggle"], 1, nil),  // Dart: TypeError

        // Collections
        Row(["type": "length"], [1, 2, 3], 3),
        Row(["type": "length"], "héllo", 5),
        Row(["type": "length"], "🙂", 2),  // UTF-16 units, as Dart
        Row(["type": "length"], 42, 0),
        Row(["type": "at", "index": 1], ["a", "b"], "b"),
        Row(["type": "at", "index": 5], ["a", "b"], nil),
        Row(["type": "at", "index": -1], ["a", "b"], nil),
        Row(["type": "first"], [7, 8], 7),
        Row(["type": "first"], [], nil),
        Row(["type": "last"], [7, 8], 8),
        Row(["type": "last"], "ab", nil),
        Row(["type": "map", "transform": ["type": "add", "by": s(1)]], [1, 2], [2, 3]),
        Row(["type": "map", "transform": ["type": "toUpperCase"]], ["a", "b"], ["A", "B"]),
        Row(["type": "map", "transform": ["type": "nope"]], [1], [1]),
        Row(["type": "map", "transform": ["type": "add", "by": s(1)]], "x", "x"),
        // filter: Dart evaluates the expression without binding the item.
        Row(["type": "filter", "expr": ["op": "eq", "left": s(1), "right": s(1)]], [1, 2], [1, 2]),
        Row(["type": "filter", "expr": ["op": "eq", "left": s(1), "right": s(2)]], [1, 2], []),
        Row(["type": "contains", "value": s(2)], [1, 2, 3], true),
        Row(["type": "contains", "value": s("ell")], "hello", true),
        Row(["type": "contains", "value": s(1)], 10, false),

        // Formatting (Flutter SDK: symbol + toStringAsFixed, no grouping)
        Row(["type": "formatCurrency", "currency": "USD"], 1234.5, "$1234.50"),
        Row(["type": "formatCurrency", "currency": "eur", "decimals": 0], 3, "€3"),
        Row(["type": "formatCurrency", "currency": "SEK"], nil, "SEK 0.00"),
        Row(["type": "formatCurrency"], 2, "$2.00"),
        Row(["type": "formatNumber", "decimals": 1], 3.14159, "3.1"),
        Row(["type": "formatNumber"], 3.5, "3.5"),
        Row(["type": "formatNumber"], 7, "7"),
        Row(["type": "formatNumber"], "x", nil),
        Row(["type": "formatDate", "format": "yyyy-MM-dd HH:mm:ss"], "2024-03-05T07:08:09", "2024-03-05 07:08:09"),
        Row(["type": "formatDate", "format": "dd/MM/yyyy"], "2024-03-05T23:30:00Z", "05/03/2024"),
        Row(["type": "formatDate", "format": "HH:mm"], "2024-03-05T23:30:00+02:00", "21:30"),
        Row(["type": "formatDate", "format": "yyyy-MM-dd"], 0, "1970-01-01"),
        Row(["type": "formatDate", "format": "yyyy"], "not a date", "not a date"),
    ]

    func testTransformTable() {
        let resolver = ValueResolver(state: Self.state)
        for row in rows {
            let value: JSONValue = ["type": "transform", "input": Self.s(row.input), "by": [row.step]]
            let got = resolver.resolve(value)
            if got != row.expected || got.isNumber != row.expected.isNumber {
                XCTFail(
                    "\(row.kind) on \(DartFormat.string(row.input)): got \(DartFormat.string(got)), "
                        + "expected \(DartFormat.string(row.expected))", line: row.line)
            }
        }
    }

    func testIntAndDoubleTypesFollowDart() {
        let r = ValueResolver(state: [:])
        func run(_ input: JSONValue, _ step: JSONValue) -> JSONValue {
            r.resolve(["type": "transform", "input": Self.s(input), "by": [step]])
        }
        XCTAssertNotNil(run(5, ["type": "add", "by": Self.s(3)]).intValue)
        if case .double = run(6, ["type": "divide", "by": Self.s(2)]) {} else { XCTFail("6/2 is a double in Dart") }
        XCTAssertNotNil(run(2.5, ["type": "round"]).intValue)
        XCTAssertEqual(DartFormat.string(run(6, ["type": "divide", "by": Self.s(2)])), "3.0")
    }

    func testEveryAdvertisedTransformHasRows() {
        let covered = Set(rows.map(\.kind))
        let advertised = Set(GeneratedCapabilities.transformKinds)
        XCTAssertEqual(advertised.count, 31)
        XCTAssertEqual(advertised.subtracting(covered), [], "transforms without a table row")
        for kind in advertised {
            XCTAssertNotNil(TransformRegistry.defaults[kind], "\(kind) not registered")
        }
        XCTAssertNotNil(TransformRegistry.defaults["toggle"], "Dart SDK extra")
    }

    func testPipelineSkipsUnknownStepsAndChains() {
        let r = ValueResolver(state: ["price": 49.99, "quantity": 2])
        let value: JSONValue = [
            "type": "transform",
            "input": ["type": "state", "key": "price", "scope": "page"],
            "by": [
                ["type": "multiply", "by": ["type": "state", "key": "quantity", "scope": "page"]],
                ["type": "sparkle"],
                "not a step",
                ["type": "toFixed", "decimals": 2],
                ["type": "template", "template": "Total: ${{value}}"],
            ],
        ]
        XCTAssertEqual(r.resolve(value), "Total: $99.98")
        // No `by` at all: the input comes back.
        XCTAssertEqual(r.resolve(["type": "transform", "input": Self.s(1)]), 1)
    }

    func testHostileInputsYieldNullInsteadOfTrapping() {
        // Each of these makes Dart throw; a trap here would kill the app.
        let r = ValueResolver(state: [:])
        func run(_ input: JSONValue, _ step: JSONValue) -> JSONValue {
            r.resolve(["type": "transform", "input": Self.s(input), "by": [step]])
        }
        XCTAssertEqual(run(.int(Int.min), ["type": "modulo", "by": Self.s(-1)]), 0)
        XCTAssertEqual(run(.int(Int.min), ["type": "modulo", "by": Self.s(.int(Int.min))]), 0)
        XCTAssertEqual(run(-1, ["type": "modulo", "by": Self.s(.int(Int.min))]), .int(Int.max))
        XCTAssertEqual(run(.int(Int.min), ["type": "abs"]), .int(Int.min))  // wraps, as the Dart VM
        XCTAssertEqual(run(.int(Int.max), ["type": "add", "by": Self.s(1)]), .int(Int.min))
        XCTAssertEqual(run(["a"], ["type": "at", "index": 1e300]), .null)
        XCTAssertEqual(run(["a"], ["type": "at", "index": -1e300]), .null)
        XCTAssertEqual(run("abc", ["type": "substring", "start": 1e300]), .null)
        XCTAssertEqual(run("abc", ["type": "substring", "start": 1, "length": .int(Int.max)]), .null)
        XCTAssertEqual(run("abc", ["type": "substring", "start": -1]), .null)
        XCTAssertEqual(run(1, ["type": "toFixed", "decimals": 1e300]), .null)
        XCTAssertEqual(run(1, ["type": "formatNumber", "decimals": -1e300]), .null)
        XCTAssertEqual(run(1e300, ["type": "round"]), .int(Int.max))
        XCTAssertEqual(run(.double(.nan), ["type": "floor"]), .null)
        XCTAssertEqual(run(1e300, ["type": "formatDate", "format": "yyyy"]), 1e300)
        XCTAssertEqual(
            ValueResolver(state: [:], animationProgress: .nan)
                .resolve(["type": "tween", "begin": "#000000", "end": "#FFFFFF"]),
            "#00000000")
    }

    // MARK: S11 Dart's corners (render fixtures 25-29)

    private func run(_ input: JSONValue, _ step: JSONValue) -> JSONValue {
        ValueResolver(state: [:]).resolve(["type": "transform", "input": Self.s(input), "by": [step]])
    }

    private func holds(_ expr: JSONValue) -> Bool {
        ValueResolver(state: [:]).evaluate(expr.objectValue ?? [:])
    }

    /// UTF-16 units of every string in a value, so a check cannot pass by
    /// canonical equivalence ("\u{e9}" against "e\u{301}").
    private func units(_ v: JSONValue) -> [[UInt16]] {
        switch v {
        case .string(let s): return [Array(s.utf16)]
        case .array(let items): return items.flatMap(units)
        default: return []
        }
    }

    private func assertSame(_ got: JSONValue, _ expected: JSONValue, line: UInt = #line) {
        XCTAssertEqual(got, expected, line: line)
        XCTAssertEqual(units(got), units(expected), line: line)
    }

    func testP1_containsWithAnEmptyNeedleIsTrue() {
        // Dart: 'abc'.contains('') and ''.contains('') are true.
        XCTAssertEqual(run("abc", ["type": "contains", "value": Self.s("")]), true)
        XCTAssertEqual(run("", ["type": "contains", "value": Self.s("")]), true)
        XCTAssertTrue(holds(["op": "contains", "haystack": Self.s("abc"), "needle": Self.s("")]))
        XCTAssertTrue(holds(["op": "contains", "haystack": Self.s(""), "needle": Self.s("")]))
    }

    func testP2_stringsCompareByUTF16CodeUnits() {
        let composed: JSONValue = "\u{e9}"
        let decomposed: JSONValue = "e\u{301}"
        XCTAssertNotEqual(composed, decomposed)
        XCTAssertEqual(composed, "\u{e9}")
        XCTAssertFalse(holds(["op": "eq", "left": Self.s(composed), "right": Self.s(decomposed)]))
        XCTAssertTrue(holds(["op": "neq", "left": Self.s(composed), "right": Self.s(decomposed)]))
        XCTAssertFalse(holds(["op": "contains", "haystack": Self.s(composed), "needle": Self.s(decomposed)]))
        XCTAssertFalse(holds(["op": "contains", "haystack": Self.s([composed]), "needle": Self.s(decomposed)]))
        XCTAssertTrue(holds(["op": "contains", "haystack": Self.s(decomposed), "needle": Self.s("e")]))
        XCTAssertFalse(holds(["op": "startsWith", "str": Self.s(composed), "prefix": Self.s(decomposed)]))
        XCTAssertTrue(holds(["op": "startsWith", "str": Self.s(decomposed), "prefix": Self.s("e")]))
        XCTAssertEqual(run(composed, ["type": "contains", "value": Self.s(decomposed)]), false)
        XCTAssertEqual(run(decomposed, ["type": "contains", "value": Self.s("e")]), true)
        XCTAssertEqual(run([composed], ["type": "contains", "value": Self.s(decomposed)]), false)
        // split "" cuts code units, a surrogate pair kept whole (gate 08).
        assertSame(run(decomposed, ["type": "split", "separator": ""]), ["e", "\u{301}"])
        assertSame(run("a🙂b", ["type": "split", "separator": ""]), ["a", "🙂", "b"])
        assertSame(run("", ["type": "split", "separator": ""]), [])
        assertSame(run("e\u{301}x", ["type": "split", "separator": composed]), ["e\u{301}x"])
        assertSame(run("e\u{301}x", ["type": "split", "separator": "e"]), ["", "\u{301}x"])
        assertSame(run("a🙂b🙂", ["type": "split", "separator": "🙂"]), ["a", "b", ""])
    }

    func testP3_anEmptyRegexPatternMatchesEverywhere() {
        assertSame(run("ab", ["type": "regex", "pattern": "", "flags": "g", "replacement": "-"]), "-a-b-")
        assertSame(run("ab", ["type": "regex", "pattern": "", "replacement": "-"]), "-ab")
        assertSame(run("ab", ["type": "regex", "pattern": ""]), "")  // match 0 is ""
        XCTAssertTrue(holds(["op": "matches", "str": Self.s("abc"), "regex": ""]))
        XCTAssertTrue(holds(["op": "matches", "str": Self.s(""), "regex": ""]))
    }

    func testP4_regexDigitAndWordClassesAreASCII() {
        func replace(_ pattern: String, _ input: JSONValue) -> JSONValue {
            run(input, ["type": "regex", "pattern": .string(pattern), "flags": "g", "replacement": "[{{value}}]"])
        }
        let digits: JSONValue = "\u{663} 4"  // ARABIC-INDIC DIGIT THREE
        let word: JSONValue = "caf\u{e9}_1"
        assertSame(replace("\\d+", digits), "\u{663} [4]")
        assertSame(replace("\\D+", digits), "[\u{663} ]4")
        assertSame(replace("\\w+", word), "[caf]\u{e9}[_1]")
        assertSame(replace("\\W+", word), "caf[\u{e9}]_1")
        // Inside a character class, negated or not.
        assertSame(replace("[\\w]+", word), "[caf]\u{e9}[_1]")
        assertSame(replace("[\\W]+", word), "caf[\u{e9}]_1")
        assertSame(replace("[^\\w]+", word), "caf[\u{e9}]_1")
        assertSame(replace("[^\\W]+", word), "[caf]\u{e9}[_1]")
        assertSame(replace("[\\d.]+", "\u{663}.5"), "\u{663}[.5]")
        assertSame(replace("[\\D]+", digits), "[\u{663} ]4")
        // An escaped backslash stays a backslash: `\\d` is "\" then "d".
        assertSame(run("a\\d1", ["type": "regex", "pattern": "\\\\d"]), "\\d")
        // `\s` stays Unicode, as Dart's: NO-BREAK SPACE is whitespace.
        assertSame(run("a\u{a0}b", ["type": "regex", "pattern": "\\s"]), "\u{a0}")
        XCTAssertFalse(holds(["op": "matches", "str": Self.s("\u{663}\u{664}\u{665}"), "regex": "^\\d+$"]))
        XCTAssertTrue(holds(["op": "matches", "str": Self.s("345"), "regex": "^\\d+$"]))
        XCTAssertFalse(holds(["op": "matches", "str": Self.s("\u{e9}"), "regex": "[\\w]"]))
    }

    func testP5_aJSONNumberKeepsItsIntOrDoubleText() throws {
        func decode(_ text: String) throws -> JSONValue { try JSONValue.decode(Data(text.utf8)) }
        func isDouble(_ v: JSONValue) -> Bool { if case .double = v { return true } else { return false } }

        // Dart's jsonDecode: a fraction or an exponent makes a double.
        XCTAssertTrue(isDouble(try decode("4.0")))
        XCTAssertEqual(try decode("4").intValue, 4)
        XCTAssertTrue(isDouble(try decode("1e2")))
        XCTAssertEqual(try decode("-1.5E-3"), -0.0015)
        XCTAssertEqual(try decode("-0").intValue, 0)  // Dart: int 0
        XCTAssertTrue(isDouble(try decode("12345678901234567890")))  // past Int
        XCTAssertEqual(try decode("-9223372036854775808").intValue, Int.min)
        XCTAssertEqual(JSONValue.int(4), .double(4.0))  // Dart's num ==

        let state = try decode(#" {"d": 4.0, "i": 4, "a": [1.0, 2], "o": {"x": 2.50}} "#)
        XCTAssertTrue(isDouble(state["d"]))
        XCTAssertEqual(state["i"].intValue, 4)
        XCTAssertTrue(isDouble(state["a"].arrayValue?[0] ?? .null))
        XCTAssertEqual(state["a"].arrayValue?[1].intValue, 2)
        let r = ValueResolver(state: state.objectValue ?? [:])
        func text(_ key: String) -> JSONValue {
            r.resolve(["type": "transform", "input": ["type": "state", "key": .string(key)], "by": [["type": "toString"]]])
        }
        XCTAssertEqual(text("d"), "4.0")
        XCTAssertEqual(text("i"), "4")
        XCTAssertEqual(text("o.x"), "2.5")

        // The rest of the grammar reads as JSONDecoder read it.
        let doc = try decode(
            #"{"s": "a\"b\\c\/\b\f\n\r\t\u00e9\ud83d\ude42", "t": true, "f": false, "n": null, "e": [], "o": {}, "k": 1, "k": 2}"#)
        assertSame(doc["s"], .string("a\"b\\c/\u{8}\u{c}\n\r\t\u{e9}🙂"))
        XCTAssertEqual(doc, ["s": doc["s"], "t": true, "f": false, "n": nil, "e": [], "o": [:], "k": 2])
        assertSame(try decode(#""e\u0301""#), "e\u{301}")  // no normalization
        assertSame(try decode("\"caf\u{e9} 🙂\""), "caf\u{e9} 🙂")
        XCTAssertEqual(try JSONValue.decode(Data([0xEF, 0xBB, 0xBF] + Array("[1]".utf8))), [1])  // BOM
        XCTAssertEqual(try decode(" \t\r\n\"x\" "), "x")
        for bad in [
            "", " ", "nul", "[1,]", "{\"a\" 1}", "{\"a\":1,}", "01", "1.", ".5", "+1", "1e", "-", "[1] x",
            "\"\\ud800\"", "\"\\x\"", "\"a\nb\"", "\"open", "[", "1e400", "{1: 2}",
        ] {
            XCTAssertThrowsError(try decode(bad), "accepted \(bad.debugDescription)")
        }
        XCTAssertThrowsError(try JSONValue.decode(Data([0x22, 0xFF, 0x22])), "invalid UTF-8")
        XCTAssertThrowsError(try decode(String(repeating: "[", count: 100_000)), "nesting")
    }

    // MARK: S12 regex word edges and case folding (render fixtures 31-32)

    // Every expected value below was printed by Dart's RegExp on the Dart VM.

    /// `expected` nil: Dart's RegExp refuses the pattern, so the transform is null.
    private func assertRegex(
        _ pattern: String, _ flags: String, _ input: String, _ expected: String?, by: String = "#",
        line: UInt = #line
    ) {
        let step: JSONValue = [
            "type": "regex", "pattern": .string(pattern), "flags": .string(flags), "replacement": .string(by),
        ]
        let got = run(.string(input), step)
        let label = "\(pattern.debugDescription) /\(flags) on \(input.debugDescription)"
        XCTAssertEqual(got, expected.map(JSONValue.string) ?? .null, label, line: line)
        XCTAssertEqual(units(got), expected.map { [Array($0.utf16)] } ?? [], label, line: line)
    }

    func testR1_wordEdgesAreASCIIUnderEveryFlag() {
        for flags in ["g", "gi", "gu", "gm", "gs", "gims"] {
            assertRegex("\\b", flags, "caf\u{e9} x", "|caf|\u{e9} |x|", by: "|")
            assertRegex("\\B", flags, "caf\u{e9}", "c|a|f\u{e9}|", by: "|")
            assertRegex("\\b", flags, "\u{17F}\u{212A}", "\u{17F}\u{212A}", by: "|")
            assertRegex("\\b", flags, "a_1-b", "|a_1|-|b|", by: "|")
            assertRegex("\\w", flags, "\u{17F}\u{212A}\u{e9}_", "\u{17F}\u{212A}\u{e9}#")
            assertRegex("\\W", flags, "\u{17F}\u{212A}\u{e9}_", "###_")
        }
    }

    func testR1_uWithIMakesLongSAndKelvinWordCharacters() {
        for flags in ["giu", "gimsu"] {
            assertRegex("\\b", flags, "\u{17F}\u{212A}", "|\u{17F}\u{212A}|", by: "|")
            assertRegex("\\B", flags, "\u{17F}\u{212A}", "\u{17F}|\u{212A}", by: "|")
            assertRegex("\\b", flags, "caf\u{e9} x", "|caf|\u{e9} |x|", by: "|")
            assertRegex("\\w", flags, "\u{17F}\u{212A}\u{e9}_", "##\u{e9}#")
            assertRegex("\\W", flags, "\u{17F}\u{212A}\u{e9}_", "\u{17F}\u{212A}#_")
            assertRegex("[\\w]", flags, "\u{17F}\u{212A}\u{e9}", "##\u{e9}")
            assertRegex("[\\W]", flags, "s\u{17F}\u{e9}", "s\u{17F}#")
        }
    }

    func testR1_backspaceInsideAClass() {
        for flags in ["g", "gi", "giu"] {
            assertRegex("[\\b]", flags, "a\u{8}b", "a-b", by: "-")
            assertRegex("[a\\b]", flags, "a\u{8}b", "--b", by: "-")
            assertRegex("[^\\b]", flags, "a\u{8}", "-\u{8}", by: "-")
        }
    }

    func testR1_theMatchesOpHasTheSameASCIIWordEdges() {
        func matches(_ regex: String, _ str: String) -> Bool {
            holds(["op": "matches", "str": Self.s(.string(str)), "regex": .string(regex)])
        }
        XCTAssertTrue(matches("\\bcaf\\b", "caf\u{e9}"))
        XCTAssertFalse(matches("\\bcaf\u{e9}\\b", "caf\u{e9}"))
        XCTAssertFalse(matches("\\B\u{e9}", "caf\u{e9}"))
        XCTAssertTrue(matches("^[\\b]$", "\u{8}"))
    }

    func testR2_theFourLettersThatFoldIntoASCIIFollowDartUnderI() {
        let (longS, kelvin, dotless, dotted) = ("\u{17F}", "\u{212A}", "\u{131}", "\u{130}")
        let four = longS + kelvin + dotless + dotted
        // Without `u` none of the four matches an ASCII letter, and no ASCII letter matches them.
        let gi: [(String, String, String, UInt)] = [
            ("[a-z]", four + "sk", four + "##", #line),
            ("[A-Z]", four + "SK", four + "##", #line),
            ("s", longS + "sS", longS + "##", #line),
            ("S", longS + "sS", longS + "##", #line),
            ("k", kelvin + "kK", kelvin + "##", #line),
            ("K", kelvin + "kK", kelvin + "##", #line),
            ("i", dotless + dotted + "iI", dotless + dotted + "##", #line),
            ("I", dotless + dotted + "iI", dotless + dotted + "##", #line),
            ("\\w", longS + kelvin + "x", longS + kelvin + "#", #line),
            ("\\W", longS + kelvin + "x", "##x", #line),
            ("[\\w]", longS + kelvin + "x", longS + kelvin + "#", #line),
            ("[\\W]", longS + kelvin + "s", "##s", #line),
            ("[^a-z]", four + "a", "####a", #line),
            ("[^\\W]", longS + kelvin + "s", longS + kelvin + "#", #line),
            ("s+", longS + "sS", longS + "#", #line),
            ("(?<=s)x", longS + "xsx", longS + "xs#", #line),
            ("(?<=[a-z])x", longS + "xsx", longS + "xs#", #line),
            ("(?<n>k)\\k<n>", "kK", "#", #line),
            (longS, "sS" + longS, "sS#", #line),
            (kelvin, "kK" + kelvin, "kK#", #line),
            ("[" + longS + "a-z]", longS + kelvin + "s", "#" + kelvin + "#", #line),
            (dotted, "i\u{307}" + dotted, "i\u{307}#", #line),
        ]
        for (pattern, input, expected, line) in gi { assertRegex(pattern, "gi", input, expected, line: line) }
        // With `u` simple case folding applies: long s is s, Kelvin is k; the dotless and dotted i stay apart.
        let giu: [(String, String, String, UInt)] = [
            ("[a-z]", four + "sk", "##" + dotless + dotted + "##", #line),
            ("[A-Z]", four + "SK", "##" + dotless + dotted + "##", #line),
            ("s", longS + "sS", "###", #line),
            ("k", kelvin + "kK", "###", #line),
            ("i", dotless + dotted + "iI", dotless + dotted + "##", #line),
            ("\\w", longS + kelvin + "x", "###", #line),
            ("\\W", longS + kelvin + "x", longS + kelvin + "x", #line),
            ("[^a-z]", four + "a", longS + kelvin + "##a", #line),
            (longS, "sS" + longS, "###", #line),
            ("[\\W]", longS + kelvin + "s", longS + kelvin + "s", #line),
            ("(?<=[a-z])x", longS + "xsx", longS + "#s#", #line),
        ]
        for (pattern, input, expected, line) in giu { assertRegex(pattern, "giu", input, expected, line: line) }
    }

    func testR2_guard_nonASCIILettersStillFoldAmongThemselves() {
        for flags in ["gi", "giu"] {
            assertRegex("\u{e9}", flags, "\u{c9}", "#")
            assertRegex("[\u{e9}]", flags, "\u{c9}", "#")
            assertRegex("\u{c9}", flags, "\u{e9}", "#")
            assertRegex("[^\u{e9}]", flags, "\u{c9}x", "\u{c9}#")
            assertRegex("\u{3c3}", flags, "\u{3a3}\u{3c2}", "##")  // σ: Σ ς
            assertRegex("[\u{430}-\u{44f}]", flags, "\u{416}\u{42f}\u{436}", "###")  // [а-я]: Ж Я ж
            assertRegex("[a-z\u{e9}]", flags, "\u{c9}\u{17F}S", flags == "gi" ? "#\u{17F}#" : "###")
        }
    }

    func testR2_aClassNamingOneOfTheFourFollowsDartUnderI() {
        let (longS, kelvin, dotless, dotted) = ("\u{17F}", "\u{212A}", "\u{131}", "\u{130}")
        let iDot = "i\u{307}"  // what Unicode's full folding turns the dotted I into
        // Without `u` a class naming one of the four holds that letter alone, and its negation all else.
        let gi: [(String, String, String, UInt)] = [
            ("[" + longS + "]", longS + "sS", "#sS", #line),
            ("[^" + longS + "]", longS + "sS", longS + "##", #line),
            ("[" + kelvin + "]", kelvin + "kK", "#kK", #line),
            ("[^" + kelvin + "]", kelvin + "kK", kelvin + "##", #line),
            ("[\\u017F]", longS + "sS", "#sS", #line),
            ("[^\\u017F]", longS + "sS", longS + "##", #line),
            ("[s" + longS + "]", longS + "sS", "###", #line),
            ("[^s" + longS + "]", longS + "sSx", longS + "sS#", #line),
            ("[^s]", longS + "sSx", "#sS#", #line),
            ("[" + longS + kelvin + "]", longS + kelvin + "sSkK", "##sSkK", #line),
            ("[" + longS + "-\u{180}]", longS + "sS", "#sS", #line),
            ("[" + dotless + "]", dotless + "iI", "#iI", #line),
            ("[^" + dotless + "]", dotless + "iI", dotless + "##", #line),
            ("[i]", dotless + dotted + "iI", dotless + dotted + "##", #line),
            ("[^i]", dotless + dotted + "iI", "##iI", #line),
            ("[" + dotted + "]", iDot + dotted, iDot + "#", #line),
            ("[^" + dotted + "]", dotted + "iI", dotted + "##", #line),
            ("[" + dotted + "a]", iDot + dotted + "A", iDot + "##", #line),
        ]
        for (pattern, input, expected, line) in gi { assertRegex(pattern, "gi", input, expected, line: line) }
        // With `u` the class holds the letter's simple case folding: long s with s, Kelvin with k, the i's alone.
        let giu: [(String, String, String, UInt)] = [
            ("[" + longS + "]", longS + "sS", "###", #line),
            ("[^" + longS + "]", longS + "sSx", longS + "sS#", #line),
            ("[" + kelvin + "]", kelvin + "kK", "###", #line),
            ("[^" + kelvin + "]", kelvin + "kKx", kelvin + "kK#", #line),
            ("[\u{100}-" + longS + "]", longS + "sS", "###", #line),
            ("[" + dotless + "]", dotless + "iI", "#iI", #line),
            ("[" + dotted + "]", iDot + dotted + "iI", iDot + "#iI", #line),
            ("[^" + dotted + "]", dotted + "iI", dotted + "##", #line),
            (dotted, iDot + dotted + "iI", iDot + "#iI", #line),
            (dotless, dotless + "iI", "#iI", #line),
            ("i", dotted + dotless + "iI", dotted + dotless + "##", #line),
            ("[i]", dotted + dotless + "iI", dotted + dotless + "##", #line),
            ("[^i]", dotted + dotless + "iI", "##iI", #line),
            ("\\p{Script=Latin}", "a\u{391}B", "#\u{391}#", #line),
            ("\\p{Lowercase_Letter}", "aB1", "##1", #line),
            ("[\\p{Script=Latin}]", "a\u{391}B", "#\u{391}#", #line),
        ]
        for (pattern, input, expected, line) in giu { assertRegex(pattern, "giu", input, expected, line: line) }
        // Guard: the flag letters of a modifier group are not letters to fold.
        assertRegex("(?i:a)", "gi", "aA", "##")
        assertRegex("(?-i:a)", "gi", "aA", "#A")
        assertRegex("(?-i:a)", "giu", "aA", "#A")
        assertRegex("(?s:.)", "giu", "\n", "#")
        assertRegex("(?ms-i:^a.)", "gi", "aA\nA\n", "#\nA\n")
    }

    func testR2_F4_sharpSAndLigaturesDoNotMatchAPatternSpelledWithSOrI() {
        // F4: Dart never folds ß into ss or a ligature into its letters; ICU does, except
        // where s and i stay out of its folding (`Regex.foldLetters`).
        for flags in ["gi", "giu"] {
            assertRegex("ss", flags, "\u{df}", "\u{df}")
            assertRegex("SS", flags, "\u{df}", "\u{df}")
            assertRegex("fi", flags, "\u{fb01}", "\u{fb01}")  // ﬁ
            assertRegex("st", flags, "\u{fb06}", "\u{fb06}")  // ﬆ
        }
    }

    // MARK: S14 — modifier scope and (? forms (row 23b.36)

    func testM1_aModifierGroupFoldsTheLettersInsideItByItsOwnI() {
        let (longS, kelvin, dotless, dotted) = ("\u{17F}", "\u{212A}", "\u{131}", "\u{130}")
        // Dart reads a letter, a class and \w \W \b \B under the `i` of the innermost modifier group
        // around it: `(?-i:` matches as written, `(?i:` folds as a pattern `i` does (with `u`, ſ and K too).
        let rows: [(String, String, String, String, UInt)] = [
            ("(?-i:s)", "gi", "sS", "#S", #line),
            ("(?-i:s)", "giu", "sS", "#S", #line),
            ("(?i:s)", "g", longS + "sS", longS + "##", #line),
            ("(?i:s)", "gu", longS + "sS", "###", #line),
            ("(?i:k)", "g", "kK" + kelvin, "##" + kelvin, #line),
            ("(?-i:k)", "gi", "kK" + kelvin, "#K" + kelvin, #line),
            ("(?i:" + longS + ")", "g", "sS" + longS, "sS#", #line),
            ("(?-i:" + longS + ")", "giu", "sS" + longS, "sS#", #line),
            ("(?-i:S)", "gi", "sS", "s#", #line),
            ("(?i:S)", "g", "sS" + longS, "##" + longS, #line),
            ("(?-i:i)", "gi", "iI" + dotless + dotted, "#I" + dotless + dotted, #line),
            ("(?i:i)", "g", "iI" + dotless + dotted, "##" + dotless + dotted, #line),
            ("(?-i:[^s])", "gi", "sS" + longS + "x", "s###", #line),
            ("(?i:[^s])", "g", "sS" + longS + "x", "sS##", #line),
            ("(?i:\\W)", "gu", "sS" + longS + kelvin + "!", "sS" + longS + kelvin + "#", #line),
            ("(?-i:\\b)", "giu", longS + " a", longS + " #a#", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testM1_groupsNestAndAScopeEndsAtItsParen() {
        let longS = "\u{17F}"
        // The innermost modifier group wins; any `)` ends the group it closes, and the enclosing `i` returns.
        let rows: [(String, String, String, String, UInt)] = [
            ("(?i:(?-i:s))", "gi", "sS", "#S", #line),
            ("(?-i:(?i:s))", "g", "sS" + longS, "##" + longS, #line),
            ("(?i:a(?-i:s)S)", "g", "AsS ASs AsS", "# ASs #", #line),
            ("(?-i:a)s", "gi", "aS AS as", "# AS #", #line),
            ("(?-i:s)(s)", "gi", "sS SS", "# SS", #line),
            ("(?i:a)s", "g", "As AS a" + longS, "# AS a" + longS, #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testM1_guard_otherModifiersAndParensThatCloseNothing() {
        // `m` and `s` modifiers open a scope that keeps `i`; a `)` in a class or escaped closes no group.
        assertRegex("(?m:^a)", "gm", "b\na", "b\n#")
        assertRegex("(?s:a.b)", "g", "a\nb", "#")
        assertRegex("(?-i:[)]s)", "gi", ")s )S", "# )S")
        assertRegex("(?-i:\\)s)", "gi", ")s )S", "# )S")
    }

    func testM2_dartRefusesEveryOtherFormAfterParenQuestion() {
        // Dart's RegExp throws (FormatException) on each: no inline `(?i)`, no flag but i m s, each once.
        let refused = [
            "(?i)a", "(?im)a", "(?i)", "((?i)s)", "(?-:a)", "(?u:a)", "(?x:a)", "(?ii:a)", "(?i-i:a)",
            "(?-i-m:a)", "(?>a)", "(?#c)a", "(?P<n>a)", "(?'n'a)", "(?^:a)",
        ]
        for flags in ["g", "gi"] {
            for pattern in refused { assertRegex(pattern, flags, "a", nil) }
        }
    }

    func testM2_guard_theFormsDartReadsStayValid() {
        for flags in ["g", "gi"] {
            assertRegex("(?:a)", flags, "a", "#")
            assertRegex("(?=a)", flags, "a", "#a")
            assertRegex("(?!a)", flags, "a", "a#")
            assertRegex("(?<=a)b", flags, "ab", "a#")
            assertRegex("(?<!a)b", flags, "ab b", "ab #")
            assertRegex("(?<n>a)\\k<n>", flags, "aa", "#")
        }
        assertRegex("(?ms-i:a)", "gi", "aA", "#A")
        assertRegex("(?i-ms:a)", "g", "aA", "##")
        assertRegex("(?i-:a)", "g", "aA", "##")
    }

    func testM2_guard_theMatchesOpIsFalseForARefusedForm() {
        func matches(_ regex: String, _ str: String) -> Bool {
            holds(["op": "matches", "str": Self.s(.string(str)), "regex": .string(regex)])
        }
        XCTAssertFalse(matches("(?i)a", "a"))  // Dart: an invalid pattern never matches
        XCTAssertTrue(matches("(?i:a)", "A"))
    }

    // MARK: S14 — Dart's fold table (row 23b.36)

    func testF1_lettersICUFoldsAnotherWayMatchOnlyDartsSet() {
        // Without `u` Å (U+212B), Ω (U+2126), ϴ, ẞ and ᾀ match only themselves in Dart; with `u` their simple folding.
        let rows: [(String, String, String, String, UInt)] = [
            ("\u{212B}", "gi", "\u{212B} \u{E5} \u{C5}", "# \u{E5} \u{C5}", #line),
            ("\u{212B}", "giu", "\u{212B} \u{E5} \u{C5}", "# # #", #line),
            ("\u{2126}", "gi", "\u{2126} \u{3C9} \u{3A9}", "# \u{3C9} \u{3A9}", #line),
            ("\u{2126}", "giu", "\u{2126} \u{3C9} \u{3A9}", "# # #", #line),
            ("\u{3F4}", "gi", "\u{3F4} \u{3B8} \u{398} \u{3D1}", "# \u{3B8} \u{398} \u{3D1}", #line),
            ("\u{3F4}", "giu", "\u{3F4} \u{3B8} \u{398} \u{3D1}", "# # # #", #line),
            ("\u{1E9E}", "gi", "\u{1E9E} \u{DF}", "# \u{DF}", #line),
            ("\u{1E9E}", "giu", "\u{1E9E} \u{DF}", "# #", #line),
            ("\u{1F80}", "gi", "\u{1F80} \u{1F88}", "# \u{1F88}", #line),
            ("\u{1F80}", "giu", "\u{1F80} \u{1F88}", "# #", #line),
            ("\u{E5}", "gi", "\u{E5}\u{C5}\u{212B}", "##\u{212B}", #line),
            ("\u{E5}", "giu", "\u{E5}\u{C5}\u{212B}", "###", #line),
            ("[\u{E5}]", "gi", "\u{E5}\u{C5}\u{212B}", "##\u{212B}", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testF1_fullCaseFoldingNeverMatchesTwoLetters() {
        // ICU folds ß to "ss" and ﬀ to "ff", and a run "ff" or "αι" to the ligature; Dart never does.
        let rows: [(String, String, String, String, UInt)] = [
            ("\u{DF}", "gi", "\u{DF} ss SS \u{1E9E}", "# ss SS \u{1E9E}", #line),
            ("\u{DF}", "giu", "\u{DF} ss SS \u{1E9E}", "# ss SS #", #line),
            ("[\u{DF}]", "gi", "\u{DF} ss \u{1E9E}", "# ss \u{1E9E}", #line),
            ("[\u{DF}]", "giu", "\u{DF} ss \u{1E9E}", "# ss #", #line),
            ("\u{FB00}", "gi", "\u{FB00} ff FF", "# ff FF", #line),
            ("ff", "gi", "\u{FB00} ff FF", "\u{FB00} # #", #line),
            ("FF", "gi", "\u{FB00} ff FF", "\u{FB00} # #", #line),
            ("[\u{FB00}]", "gi", "\u{FB00} ff FF", "# ff FF", #line),
            ("\u{FB05}", "gi", "\u{FB05} st \u{FB06}", "# st \u{FB06}", #line),
            ("\u{FB05}", "giu", "\u{FB05} st \u{FB06}", "# st #", #line),
            ("\u{2BC}n", "gi", "\u{149} \u{2BC}n", "\u{149} #", #line),
            ("\u{3B1}\u{3B9}", "gi", "\u{1FB3} \u{3B1}\u{3B9}", "\u{1FB3} #", #line),
            ("[a-z]+", "gi", "\u{FB00} ff \u{17F}", "\u{FB00} # \u{17F}", #line),
            ("[^a-z]", "gi", "\u{FB00}\u{212A}a", "##a", #line),
            // A negated class whose first member is `^`: the letters it names stay out, every other letter is in.
            ("[^^a]", "gi", "^aAfFsS", "^aA####", #line),
            ("[^^a]", "giu", "^aAfFsS", "^aA####", #line),
            // The same with a combining mark after that `^`: the body starts with the scalar `^`, not the Character "^\u{301}".
            ("[^^\u{301}a]", "gi", "^\u{301}aAfFsS\u{17F}", "^\u{301}aA#####", #line),
            ("[^^\u{301}a]", "giu", "^\u{301}aAfFsS\u{17F}", "^\u{301}aA#####", #line),
            ("[^^\u{301}]", "gi", "^\u{301}aAfFsS\u{17F}", "^\u{301}#######", #line),
            ("[^^\u{301}]", "giu", "^\u{301}aAfFsS\u{17F}", "^\u{301}#######", #line),
            ("[^\u{301}a]", "gi", "^\u{301}aAfFsS\u{17F}", "#\u{301}aA#####", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testF1_theTableFollowsTheModifierScope() {
        assertRegex("(?i:\u{DF})", "g", "\u{DF} ss \u{1E9E}", "# ss \u{1E9E}")
        assertRegex("(?-i:\u{DF})", "giu", "\u{DF} ss \u{1E9E}", "# ss \u{1E9E}")
        assertRegex("(?i:ff)", "g", "\u{FB00} ff FF", "\u{FB00} # #")
    }

    func testF1_guard_lettersOutsideTheTableKeepICUsFolding() {
        assertRegex("\u{E9}", "gi", "\u{E9}\u{C9}", "##")
        assertRegex("\u{3C3}", "gi", "\u{3C3}\u{3C2}\u{3A3}", "###")  // σ: ς Σ
    }

    func testF1_guard_hexEscapesKeepTheirDigits() {
        // The table holds a A f F: the digits of `\xHH` and `\uHHHH` are not letters to fold.
        let rows: [(String, String, String, UInt)] = [
            ("\\x0a", "a\nb", "a#b", #line),
            ("\\x7F", "a\u{7F}b", "a#b", #line),
            ("\\u00ff", "\u{FF}\u{178}", "##", #line),
            ("\\x4a", "jJ\u{1F0}", "##\u{1F0}", #line),
            ("\\xAF", "\u{AF}", "#", #line),
            ("[\\x41-\\x46]+", "abcdefg", "#g", #line),
            ("\\uFFFF", "\u{FFFF}", "#", #line),
            ("\\cA", "\u{1}", "#", #line),
        ]
        for (pattern, input, expected, line) in rows { assertRegex(pattern, "gi", input, expected, line: line) }
    }

    func testF1_everyTableLetterMatchesDartsSetAsALetterAndAsAClass() {
        // A mechanism check over the data: `c` and `[c]` match, among the table's letters, exactly the set
        // Dart printed for c (without `u` under gi, with `u` under giu).
        let letters = Regex.foldLetters
        let input = String(String.UnicodeScalarView(letters.flatMap { [$0, " "] }))
        func hex(_ set: Set<Unicode.Scalar>) -> String {
            set.map(\.value).sorted().map { String($0, radix: 16, uppercase: true) }.joined(separator: " ")
        }
        var failures: [String] = []
        for c in letters {
            let letter = String(Character(c))
            for (flags, unicode) in [("gi", false), ("giu", true)] {
                let expected = Set(Regex.dartFold(c, unicode: unicode) ?? [])
                for pattern in [letter, "[" + letter + "]"] {
                    let step: JSONValue = [
                        "type": "regex", "pattern": .string(pattern), "flags": .string(flags), "replacement": "#",
                    ]
                    let tokens = run(.string(input), step).stringValue?.unicodeScalars
                        .split(separator: " ", omittingEmptySubsequences: false) ?? []
                    let matched = Set(zip(letters, tokens).filter { Array($0.1) == ["#"] }.map(\.0))
                    if tokens.count != letters.count + 1 || matched != expected {
                        failures.append("\(pattern.debugDescription) /\(flags): \(hex(matched)) not \(hex(expected))")
                    }
                }
            }
        }
        XCTAssertEqual(letters.count, 217)
        XCTAssert(failures.isEmpty, "\(failures.count) of \(letters.count * 4): " + failures.prefix(8).joined(separator: "; "))
    }

    // MARK: S14 — escaped letters and \u{…} (row 23b.36)

    /// s S ſ k K K ß ẞ: the letters ICU folds another way than Dart, with their partners.
    private static let folds = "s S \u{17F} k K \u{212A} \u{DF} \u{1E9E}"

    func testE1_anEscapeSpellingATableLetterIsThatLetterUnderI() {
        let e = Self.folds
        let rows: [(String, String, String, String, UInt)] = [
            ("\\x73", "gi", e, "# # \u{17F} k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\x53", "gi", e, "# # \u{17F} k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\u0073", "gi", e, "# # \u{17F} k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\u017F", "gi", e, "s S # k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\u017f", "giu", e, "# # # k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\u212A", "gi", e, "s S \u{17F} k K # \u{DF} \u{1E9E}", #line),
            ("\\x6b", "gi", e, "s S \u{17F} # # \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\xdf", "gi", e, "s S \u{17F} k K \u{212A} # \u{1E9E}", #line),
            ("\\xdf", "giu", e, "s S \u{17F} k K \u{212A} # #", #line),
            ("\\u1E9E", "gi", e, "s S \u{17F} k K \u{212A} \u{DF} #", #line),
            ("\\u1E9E", "giu", e, "s S \u{17F} k K \u{212A} # #", #line),
            ("\\uFB00", "gi", "\u{FB00} ff FF", "# ff FF", #line),
            ("\\x66\\x66", "gi", "\u{FB00} ff FF", "\u{FB00} # #", #line),
            ("\\x73\\u017F", "gi", "s\u{17F} S\u{17F} ss", "# # ss", #line),
            ("\\u0130", "gi", "i I \u{130} \u{131}", "i I # \u{131}", #line),
            ("\\u0131", "gi", "i I \u{130} \u{131}", "i I \u{130} #", #line),
            ("\\x41", "gi", "aA", "##", #line),
            ("\\u00C5", "gi", "\u{E5}\u{C5}\u{212B}", "##\u{212B}", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testE1_anEscapeFollowsTheModifierScope() {
        assertRegex("(?-i:\\x73)", "gi", "sS", "#S")
        assertRegex("(?i:\\x73)", "g", "sS\u{17F}", "##\u{17F}")
    }

    func testE1_withUABracedEscapeIsItsCodePoint() {
        let e = Self.folds
        let rows: [(String, String, String, String, UInt)] = [
            ("\\u{73}", "gu", e, "# S \u{17F} k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\u{73}", "giu", e, "# # # k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\u{17F}", "gu", e, "s S # k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\u{17F}", "giu", e, "# # # k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("\\u{0000073}", "giu", e, "# # # k K \u{212A} \u{DF} \u{1E9E}", #line),  // more than six digits
            ("\\u{10FFFF}", "gu", "\u{10FFFF}", "#", #line),
            ("\\u{1F600}", "gu", "x\u{1F600}", "x#", #line),
            ("\\u{1F600}+", "gu", "\u{1F600}\u{1F600}", "#", #line),
            ("\\u{61}", "gu", "aA", "#A", #line),
            ("\\u{61}", "giu", "aA", "##", #line),
            ("\\u{212B}", "giu", "\u{E5}\u{C5}\u{212B}", "###", #line),
            // Inside a class too.
            ("[\\u{1F600}a]", "gu", "a\u{1F600}b", "##b", #line),
            ("[\\u{17F}]", "giu", e, "# # # k K \u{212A} \u{DF} \u{1E9E}", #line),
            ("[\\u{17F}]", "gu", e, "s S # k K \u{212A} \u{DF} \u{1E9E}", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testE1_withUDartRefusesABracedEscapeWithoutACodePoint() {
        for pattern in ["\\u{110000}", "\\u{}", "\\u{g}"] { assertRegex(pattern, "gu", "a", nil) }
    }

    // MARK: S14 — property names (row 23b.36)

    // With `u` Dart reads the name in `\p{…}` and `\P{…}` by ECMA-262's tables; Dart 3.12.2 printed every value.

    func testP1_withUDartRefusesANameOutsideECMAScriptsTables() {
        // ICU's own names, bare scripts, a key or value in another case, a value under the wrong key, spaces,
        // an empty value, and the binary properties ECMAScript's table lacks.
        let refused = [
            "IsLatin", "InGreek", "IsAlphabetic", "Latin", "Greek", "Han", "javaLowerCase", "Javalowercase", "L&",
            "script=latin", "script=Latin", "general_category=Ll", "Gc=Ll", "Lowercase_letter", "ll", "gc=Lowercase",
            "ASCII=Y", "Alphabetic=Yes", "Any=", "Script", "=Ll", "gc=Ll=Lu", "Lu,Ll", "L|Lu", " L", "L ", "XIDS ",
            "Script=", "sc=", "Script_Extensions=", "scx=", "gc=", "General_Category=",
            "Changes_When_NFKC_Casefolded", "CWKCF", "Basic_Emoji", "RGI_Emoji", "Emoji_Keycap_Sequence",
            "IDS_Unary_Operator", "ID_Compat_Math_Start",
        ]
        for flags in ["gu", "giu"] {
            for name in refused {
                assertRegex("\\p{\(name)}", flags, "aL", nil)
                assertRegex("\\P{\(name)}", flags, "aL", nil)
            }
        }
    }

    func testP1_withUANameDartRefusesInAClassOrAGroupIsRefusedToo() {
        let refused = [
            #"[\p{IsLatin}]"#, #"[^\p{Han}]"#, #"[a\P{Latin}]"#, #"[\p{L}\p{Greek}]"#, #"[\p{javaLowerCase}-]"#,
            #"[\P{CWKCF}]"#, #"[\p{L&}]"#, #"[^\p{script=latin}]"#, #"[\p{ L}]"#, #"[\p{Script=}]"#,
            #"[\w\p{IsAlphabetic}]"#, #"(?i:[\p{Han}])"#, #"(?-i:\p{IsLatin})"#, #"(?i:\P{InGreek})"#, #"a|\p{Latin}"#,
        ]
        for flags in ["gu", "giu"] {
            for pattern in refused { assertRegex(pattern, flags, "aL", nil) }
        }
    }

    func testP1_guard_withoutUTheNameIsNotRead() {
        // Without `u` Dart reads `\p` as the letter p (Annex B): each pattern is valid; its matches are row 23b.37's.
        for flags in ["g", "gi"] {
            for pattern in [#"\p{IsLatin}"#, #"[\p{Han}]"#, #"\P{CWKCF}"#, #"\p{javaLowerCase}"#] {
                let step: JSONValue = [
                    "type": "regex", "pattern": .string(pattern), "flags": .string(flags), "replacement": "#",
                ]
                XCTAssertNotEqual(run(.string("aL p{IsLatin}"), step), .null, "\(pattern) /\(flags)")
            }
        }
    }

    func testP1_guard_aNameDartAcceptsKeepsItsMatches() {
        let input = "aB1\u{17F}_ p{L} \u{3B1} \u{416} \u{4E2D} \u{663} ! \u{A0} \u{1C5}"
        let rows: [(String, String, String, UInt)] = [
            (#"\p{Lowercase_Letter}"#, "gu", "#B1#_ #{L} # \u{416} \u{4E2D} \u{663} ! \u{A0} \u{1C5}", #line),
            (#"\p{gc=Ll}"#, "giu", "##1#_ #{#} # # \u{4E2D} \u{663} ! \u{A0} #", #line),
            (
                #"\p{General_Category=Lowercase_Letter}"#, "gu",
                "#B1#_ #{L} # \u{416} \u{4E2D} \u{663} ! \u{A0} \u{1C5}", #line
            ),
            (#"\p{Script=Latin}"#, "gu", "##1#_ #{#} \u{3B1} \u{416} \u{4E2D} \u{663} ! \u{A0} #", #line),
            (#"\P{Script=Latin}"#, "gu", "aB#\u{17F}##p#L##############\u{1C5}", #line),
            (#"\p{sc=Greek}"#, "giu", "aB1\u{17F}_ p{L} # \u{416} \u{4E2D} \u{663} ! \u{A0} \u{1C5}", #line),
            (#"\p{scx=Cyrl}"#, "gu", "aB1\u{17F}_ p{L} \u{3B1} # \u{4E2D} \u{663} ! \u{A0} \u{1C5}", #line),
            (#"\p{Script_Extensions=Latin}"#, "giu", "##1#_ #{#} \u{3B1} \u{416} \u{4E2D} \u{663} ! \u{A0} #", #line),
            (#"\p{ASCII}"#, "gu", "###\u{17F}#######\u{3B1}#\u{416}#\u{4E2D}#\u{663}###\u{A0}#\u{1C5}", #line),
            (#"\p{Any}"#, "giu", "########################", #line),
            (#"\p{digit}"#, "gu", "aB#\u{17F}_ p{L} \u{3B1} \u{416} \u{4E2D} # ! \u{A0} \u{1C5}", #line),
            (#"\p{punct}"#, "gu", "aB1\u{17F}# p#L# \u{3B1} \u{416} \u{4E2D} \u{663} # \u{A0} \u{1C5}", #line),
            (#"[\p{Uppercase_Letter}\d]"#, "gu", "a##\u{17F}_ p{#} \u{3B1} # \u{4E2D} \u{663} ! \u{A0} \u{1C5}", #line),
            (#"[\p{Uppercase_Letter}\d]"#, "giu", "####_ #{#} # # \u{4E2D} \u{663} ! \u{A0} #", #line),
            (#"[^\p{Lowercase_Letter}]"#, "gu", "a##\u{17F}##p####\u{3B1}############", #line),
            (#"[\P{Any}a]"#, "gu", "#B1\u{17F}_ p{L} \u{3B1} \u{416} \u{4E2D} \u{663} ! \u{A0} \u{1C5}", #line),
            (#"[^\P{Any}]"#, "giu", "########################", #line),
            (#"[\p{Script=Greek}\p{Nd}]"#, "gu", "aB#\u{17F}_ p{L} # \u{416} \u{4E2D} # ! \u{A0} \u{1C5}", #line),
            (#"(?-i:\p{Lu})"#, "giu", "a#1\u{17F}_ p{#} \u{3B1} # \u{4E2D} \u{663} ! \u{A0} \u{1C5}", #line),
        ]
        for (pattern, flags, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    /// The General_Category values and binary properties Dart 3.12.2 accepts after `\p{` with `u`.
    private static let dartCategories = """
        C Other Cc Control cntrl Cf Format Cn Unassigned Co Private_Use Cs Surrogate L Letter LC Cased_Letter Ll \
        Lowercase_Letter Lm Modifier_Letter Lo Other_Letter Lt Titlecase_Letter Lu Uppercase_Letter M Mark \
        Combining_Mark Mc Spacing_Mark Me Enclosing_Mark Mn Nonspacing_Mark N Number Nd Decimal_Number digit Nl \
        Letter_Number No Other_Number P Punctuation punct Pc Connector_Punctuation Pd Dash_Punctuation Pe \
        Close_Punctuation Pf Final_Punctuation Pi Initial_Punctuation Po Other_Punctuation Ps Open_Punctuation S \
        Symbol Sc Currency_Symbol Sk Modifier_Symbol Sm Math_Symbol So Other_Symbol Z Separator Zl \
        Line_Separator Zp Paragraph_Separator Zs Space_Separator
        """.split(separator: " ").map(String.init)
    private static let dartBinaryProperties = """
        ASCII ASCII_Hex_Digit AHex Alphabetic Alpha Any Assigned Bidi_Control Bidi_C Bidi_Mirrored Bidi_M \
        Case_Ignorable CI Cased Changes_When_Casefolded CWCF Changes_When_Casemapped CWCM \
        Changes_When_Lowercased CWL Changes_When_Titlecased CWT Changes_When_Uppercased CWU Dash \
        Default_Ignorable_Code_Point DI Deprecated Dep Diacritic Dia Emoji Emoji_Component EComp Emoji_Modifier \
        EMod Emoji_Modifier_Base EBase Emoji_Presentation EPres Extended_Pictographic ExtPict Extender Ext \
        Grapheme_Base Gr_Base Grapheme_Extend Gr_Ext Hex_Digit Hex IDS_Binary_Operator IDSB IDS_Trinary_Operator \
        IDST ID_Continue IDC ID_Start IDS Ideographic Ideo Join_Control Join_C Logical_Order_Exception LOE \
        Lowercase Lower Math Noncharacter_Code_Point NChar Pattern_Syntax Pat_Syn Pattern_White_Space Pat_WS \
        Quotation_Mark QMark Radical Regional_Indicator RI Sentence_Terminal STerm Soft_Dotted SD \
        Terminal_Punctuation Term Unified_Ideograph UIdeo Uppercase Upper Variation_Selector VS White_Space \
        space XID_Continue XIDC XID_Start XIDS
        """.split(separator: " ").map(String.init)

    func testP1_guard_everyFormDartAcceptsStaysValid() {
        // Each category bare and after `General_Category=` and `gc=`, each binary property, and scripts; Dart
        // accepts every form as `\p{…}` and as `[\P{…}]`, under gu and giu.
        let scripts = [
            "Script=Latin", "sc=Latn", "Script=Greek", "sc=Grek", "Script_Extensions=Latin", "scx=Latn",
            "Script=Han", "sc=Cyrl", "scx=Cyrl",
        ]
        let names = Self.dartCategories.flatMap { [$0, "General_Category=" + $0, "gc=" + $0] }
            + Self.dartBinaryProperties + scripts
        XCTAssertEqual(names.count, 345)
        var refused: [String] = []
        for flags in ["gu", "giu"] {
            for pattern in names.flatMap({ ["\\p{\($0)}", "[\\P{\($0)}]"] }) {
                let step: JSONValue = [
                    "type": "regex", "pattern": .string(pattern), "flags": .string(flags), "replacement": "#",
                ]
                if run(.string("a"), step) == .null { refused.append("\(pattern) /\(flags)") }
            }
        }
        XCTAssert(refused.isEmpty, "\(refused.count) refused: " + refused.prefix(8).joined(separator: "; "))
    }

    func testDoubleToStringMatchesDart() {
        let cases: [(Double, String)] = [
            (0, "0.0"), (-0.0, "-0.0"), (1, "1.0"), (-2.5, "-2.5"), (0.1, "0.1"), (100, "100.0"),
            (1.2345678901234568e20, "123456789012345680000.0"), (1e21, "1e+21"), (1.5e300, "1.5e+300"),
            (0.000001, "0.000001"), (0.0000001, "1e-7"), (1.25e-7, "1.25e-7"),
            (.nan, "NaN"), (.infinity, "Infinity"), (-.infinity, "-Infinity"), (5e-324, "5e-324"),
        ]
        for (d, expected) in cases {
            XCTAssertEqual(DartFormat.double(d), expected, "\(d)")
        }
    }
}
