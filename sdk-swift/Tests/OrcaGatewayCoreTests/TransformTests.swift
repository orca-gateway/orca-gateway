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
