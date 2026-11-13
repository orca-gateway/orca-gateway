import Foundation
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
        // Without `u` Dart reads `\p` as the letter p (Annex B), and `{IsLatin}` as text; Dart 3.12.2 printed each.
        let input = "aL p{IsLatin} P{CWKCF} p{Han} p{javaLowerCase}"
        let rows: [(String, String, String, UInt)] = [
            (#"\p{IsLatin}"#, "g", "aL # P{CWKCF} p{Han} p{javaLowerCase}", #line),
            (#"\p{IsLatin}"#, "gi", "aL # P{CWKCF} p{Han} p{javaLowerCase}", #line),
            (#"[\p{Han}]"#, "g", "#L ##IsL#ti## P#CWKCF# ###### ##j#v#LowerC#se#", #line),
            (#"[\p{Han}]"#, "gi", "#L ##IsL#ti## ##CWKCF# ###### ##j#v#LowerC#se#", #line),
            (#"\P{CWKCF}"#, "g", "aL p{IsLatin} # p{Han} p{javaLowerCase}", #line),
            (#"\P{CWKCF}"#, "gi", "aL p{IsLatin} # p{Han} p{javaLowerCase}", #line),
            (#"\p{javaLowerCase}"#, "g", "aL p{IsLatin} P{CWKCF} p{Han} #", #line),
            (#"\p{javaLowerCase}"#, "gi", "aL p{IsLatin} P{CWKCF} p{Han} #", #line),
        ]
        for (pattern, flags, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
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

    // MARK: S15 — quantifiers (row 23b.37)

    // Dart 3.12.2 printed every value; a quantifier is `*`, `+`, `?`, `{n}`, `{n,}` or `{n,m}`.

    func testA3_dartRefusesAQuantifierOnAQuantifierAnAssertionOrNothing() {
        // On a quantifier (but for the lazy `?`), on `^ $ \b \B` or a lookbehind, at the start, after `(` or `|`.
        let refused = [
            "a++", "a*+", "a?+", "a{1,2}+", "a{1,}+", "a{1}{2}", "a**", "a+?+", "a???", "{3}",
            "^*", "$+", "\\b*", "\\B+", "(?i:\\b+)", "(?<=a)*", "(?<!a)+",
            "*a", "+a", "?a", "a|*b", "(*a)", "(?:+a)", "(?<n>{2}a)", "a{2,1}",
        ]
        for flags in ["g", "gu"] {
            for pattern in refused { assertRegex(pattern, flags, "aaa", nil) }
        }
        assertRegex("^*a", "gm", "aaa", nil)
    }

    func testA3_aLazyQuestionMarkAndAnEmptyGroupStayValid() {
        let rows: [(String, String, String, String, UInt)] = [
            ("a+?", "g", "aaa", "###", #line),
            ("a+?", "gu", "aaa", "###", #line),
            ("a??", "g", "aaa", "#a#a#a#", #line),
            ("a??", "gu", "aaa", "#a#a#a#", #line),
            ("a{1,2}?", "g", "aaa", "###", #line),
            ("a{1,2}?", "gu", "aaa", "###", #line),
            ("a{1}?", "g", "aaa", "###", #line),
            ("a{2,}?", "g", "aaa", "#a", #line),
            ("(?:)*", "g", "aaa", "#a#a#a#", #line),
            ("(?:)*", "gu", "aaa", "#a#a#a#", #line),
            ("()+", "g", "aaa", "#a#a#a#", #line),
            ("()+", "gu", "aaa", "#a#a#a#", #line),
            ("(?i:)+", "g", "aaa", "#a#a#a#", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testA3_guard_quantifiersAndAssertionsKeepTheirMatches() {
        let rows: [(String, String, String, String, UInt)] = [
            ("a{1,2}", "g", "aaa", "##", #line),
            ("(a)+", "g", "aaa", "#", #line),
            ("(?<n>a)+", "g", "aaa", "#", #line),
            ("(?:ab)*", "g", "abab", "##", #line),
            ("(?-i:a)+", "gi", "aAa", "#A#", #line),
            ("[a]*", "g", "aaa", "##", #line),
            ("\\d+", "g", "a12", "a#", #line),
            ("\\s?a", "g", "aaa", "###", #line),
            ("\\x61{2}", "g", "aaa", "#a", #line),
            ("\\b", "g", "a b", "#a# #b#", #line),
            ("\\B", "g", "ab", "a#b", #line),
            ("^a", "g", "aaa", "#aa", #line),
            ("a$", "g", "aaa", "aa#", #line),
            ("(?=a)a", "g", "aaa", "###", #line),
            ("a|(?=a)a", "g", "aaa", "###", #line),
            ("(?<=a)a", "g", "aaa", "a##", #line),
            ("(?<!a)a", "g", "aaa", "#aa", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    // MARK: S15 — Annex B without u (row 23b.37)

    // Without `u` Dart reads ECMAScript's Annex B grammar; Dart 3.12.2 printed every value (nil: refused).

    func testA1_withoutUAnEscapeWithNoMeaningIsTheCharacter() {
        // A letter ECMAScript gives no meaning, `\p`, `\P`, `\k` without a named group, `\c` without a letter
        // (a backslash, then c), `\x` and `\u` without their digits; each then goes the character's way.
        let rows: [(String, String, String, String?, UInt)] = [
            (#"\A"#, "g", "aA", "a#", #line),
            (#"\Qa\E"#, "g", "QaE a", "# a", #line),
            (#"\z"#, "g", "z", "#", #line),
            (#"\h"#, "g", "h", "#", #line),
            (#"\K"#, "g", "kK\u{212A}", "k#\u{212A}", #line),
            (#"\K"#, "gi", "kK\u{212A}", "##\u{212A}", #line),
            (#"\p{L}"#, "g", "p{L} a", "# a", #line),
            (#"\P{L}"#, "g", "P{L} a", "# a", #line),
            (#"\p{L}"#, "gi", "p{L} P{l}", "# #", #line),
            (#"\k"#, "g", "k", "#", #line),
            (#"\k<a>"#, "g", "k<a>", "#", #line),
            (#"\ka"#, "g", "ka", "#", #line),
            (#"\c1"#, "g", #"\c1"#, "#", #line),
            (#"\c"#, "g", #"\c"#, "#", #line),
            (#"\c!"#, "g", #"\c!"#, "#", #line),
            (#"\u61"#, "g", "u61 a", "# a", #line),
            (#"\u{3}"#, "g", "uuu u", "# u", #line),
            (#"\u{61}"#, "g", "u{61} a", "u{61} a", #line),
            (#"\x6"#, "g", "x6", "#", #line),
            (#"\x{2}"#, "g", "xx x", "# x", #line),
            (#"\xG1"#, "g", "xG1", "#", #line),
            (#"\e"#, "g", "e", "#", #line),
            (#"\a"#, "g", "a", "#", #line),
            (#"\c*"#, "g", #"\ccc \"#, "# #", #line),
            (#"\c_"#, "g", #"\c_"#, "#", #line),
            (#"\k"#, "gi", "kK\u{212A}", "##\u{212A}", #line),
            (#"\u"#, "g", "u", "#", #line),
            (#"\x"#, "g", "x", "#", #line),
            (#"\p"#, "g", "p", "#", #line),
            (#"\P"#, "gi", "pP", "##", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testA1_aDecimalEscapeIsNULABackreferenceOrALegacyOctal() {
        // `\0` before no digit is NUL with `u` too; otherwise, without `u`, the digits are a group when there is
        // one by that number, else at most three octal digits up to \377, and `\8`, `\9` are the digits.
        let rows: [(String, String, String, String?, UInt)] = [
            (#"\0"#, "g", "a\u{0}", "a#", #line),
            (#"\0"#, "gu", "a\u{0}", "a#", #line),
            (#"[\0]"#, "gu", "a\u{0}", "a#", #line),
            (#"\01"#, "g", "\u{1} 1", "# 1", #line),
            (#"\377"#, "g", "\u{FF}", "#", #line),
            (#"\400"#, "g", " 0", "#", #line),
            (#"\8"#, "g", "8", "#", #line),
            (#"\18"#, "g", "\u{1}8", "#", #line),
            (#"\08"#, "g", "\u{0}8", "#", #line),
            (#"[\1]"#, "g", "\u{1} 1", "# 1", #line),
            (#"[\8]"#, "g", "8", "#", #line),
            (#"(a)\8"#, "g", "a8", "#", #line),
            (#"(a)\2"#, "g", "a\u{2}", "#", #line),
            (#"(a)\10"#, "g", "a\u{8}", "#", #line),
            (#"(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\10"#, "g", "abcdefghijj abcdefghija\u{8}", "# abcdefghija\u{8}", #line),
            (#"\9"#, "g", "9", "#", #line),
            (#"\81"#, "g", "81", "#", #line),
            (#"\19"#, "g", "\u{1}9", "#", #line),
            (#"\012"#, "g", "\n", "#", #line),
            (#"\0123"#, "g", "\n3", "#", #line),
            (#"[\18]"#, "g", "\u{1} 8 a", "# # a", #line),
            (#"[\400]"#, "g", " 0 a", "###a", #line),
            (#"[\08]"#, "g", "\u{0} 8 a", "# # a", #line),
            (#"[\0]"#, "g", "a\u{0}", "a#", #line),
            (#"[\1-\3]"#, "g", "\u{1}\u{2}\u{3}\u{4}", "###\u{4}", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testA1_withoutUABraceThatStartsNoQuantifierAndALoneBracketAreText() {
        let rows: [(String, String, String, String?, UInt)] = [
            ("{", "g", "{x}", "#x}", #line),
            ("}", "g", "{x}", "{x#", #line),
            ("x{,3}", "g", "x{,3} x", "# x", #line),
            ("a{1", "g", "a{1 a", "# a", #line),
            ("a{1,", "g", "a{1, a", "# a", #line),
            ("]", "g", "a]", "a#", #line),
            ("p{L}", "g", "p{L}", "#", #line),
            ("x{,}", "g", "x{,} x", "# x", #line),
            ("a{", "g", "a{ a", "# a", #line),
            ("}", "gi", "}", "#", #line),
            ("a]", "g", "a] a", "# a", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testA1_aClassIsReadAsECMAScriptReadsIt() {
        // `[]` and `[^]`; a `]` first ends the class; `[`, `&`, `~`, `-` are members; a range out of order is
        // refused, with `u` too; without `u` a range with a class escape is a union and `\B`, `\k`, `\a`, `\p`,
        // `\x` and `\u` without digits are letters, `\c` with a digit or `_` a control character, else `\` and c.
        let rows: [(String, String, String, String?, UInt)] = [
            ("[]", "g", "ab", "ab", #line),
            ("[^]", "g", "a\nb", "###", #line),
            ("[]a]", "g", "a]", "a]", #line),
            ("[^]a]", "g", "a]", "a]", #line),
            ("[[:alpha:]]", "g", "a:] a", "a# a", #line),
            ("[a&&b]", "g", "a&b", "###", #line),
            ("[a--b]", "g", "a-b", nil, #line),
            ("[a~~b]", "g", "~", "#", #line),
            (#"[a-\d]"#, "g", "a-1b", "###b", #line),
            (#"[\d-z]"#, "g", "1-z y", "### y", #line),
            (#"[\B]"#, "g", "Bb", "#b", #line),
            (#"[\k]"#, "g", "k", "#", #line),
            (#"[\a]"#, "g", "a", "#", #line),
            (#"[\c1]"#, "g", "\u{11} c 1", "# c 1", #line),
            (#"[\c]"#, "g", #"\c"#, "##", #line),
            (#"[\K]"#, "gi", "kK\u{212A}", "##\u{212A}", #line),
            (#"[\w-\d]"#, "g", "a-1 %", "### %", #line),
            (#"[\c-z]"#, "g", #"\cdz-a"#, "####-a", #line),
            (#"[\c_]"#, "g", "\u{1F}_c", "#_c", #line),
            ("[a-z-0]", "g", "b-0 A", "### A", #line),
            ("[-a]", "g", "-a b", "## b", #line),
            ("[a-]", "g", "-a b", "## b", #line),
            (#"[\-]"#, "g", "-a", "#a", #line),
            ("[z-a]", "g", "a", nil, #line),
            ("[z-a]", "gu", "a", nil, #line),
            ("[a--b]", "gu", "a", nil, #line),
            (#"[\x6]"#, "g", "x6 a", "## a", #line),
            (#"[\u61]"#, "g", "u61 a", "### a", #line),
            (#"[\p{L}]"#, "g", "p{L} a", "#### a", #line),
            (#"[\cA-\cC]"#, "g", "\u{1}\u{2}\u{3}\u{4}", "###\u{4}", #line),
            (#"[a-\s]"#, "g", "a- b", "###b", #line),
            (#"[\s-a]"#, "g", "a- b", "###b", #line),
            ("[[]", "g", "[a", "#a", #line),
            ("[^[]", "g", "[a", "[#", #line),
            ("[&&]", "g", "&a", "#a", #line),
            ("[a-z&&[aeiou]]", "g", "a&[]e x", "a&#e x", #line),
            (#"[\w&&\d]"#, "g", "a&1", "###", #line),
            (#"[\k]"#, "gi", "kK\u{212A}", "##\u{212A}", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testA1_withoutUALookaheadMayBeQuantified() {
        let rows: [(String, String, String, String?, UInt)] = [
            ("(?=a)*", "g", "ab", "#a#b#", #line),
            ("(?!a)+", "g", "ab", "a#b#", #line),
            ("(?=a){2}", "g", "ab", "#ab", #line),
            ("(?=a)?", "g", "ab", "#a#b#", #line),
            ("(?=a)+", "g", "ab", "#ab", #line),
        ]
        for (pattern, flags, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    // MARK: S15 — strict u (row 23b.37)

    // With `u` Dart reads ECMAScript's strict grammar; Dart 3.12.2 printed every value (nil: refused).

    func testA2_withUDartRefusesAnEscapeTheStrictGrammarLacks() {
        // An identity escape of anything but `^ $ \ . * + ? ( ) [ ] { } | /` (and `-` in a class), `\0` before a
        // digit, `\N` beyond the group count, a decimal escape in a class but `\0`, `\c` without an ASCII letter,
        // `\x` without two hex digits, `\u` without four or a valid `{…}`, `\p` without `{`, and `\k` without the
        // `<name>` of a group.
        let refused = [
            #"\A"#, #"\z"#, #"\-"#, #"\%"#, #"\_"#, #"\a"#, #"\00"#, #"\01"#, #"\8"#, #"\c1"#, #"\c"#, #"[\c_]"#,
            #"\x6"#, #"\u61"#, #"\u{}"#, #"\k"#, #"\k<a>"#, #"[\k]"#, #"[\B]"#, #"[\a]"#, #"[\_]"#, #"\p"#, #"\pL"#,
            #"[\8]"#, #"[\1]"#, #"[\00]"#, #"(a)\k<a>"#, #"\k<a"#, #"\1"#, #"\10"#, #"\é"#,
            #"\N{LATIN SMALL LETTER A}"#, #"\o{141}"#, #"\x{73}"#, #"\u{110000}"#, #"[\c]"#, #"\c\"#, #"[\c1]"#,
            #"\Qa.\E"#, #"\ "#, "\\#", #"[\%]"#, #"[\ ]"#, #"\V"#, #"\h"#, #"\H"#, #"\R"#, #"\e"#, #"\K"#, #"[\K]"#,
            #"[\p]"#, #"[\pL]"#, #"\p{L"#, #"\x"#, #"\u"#, #"\u006"#,
            #"(a)\2"#, #"(a)\8"#, #"(a)\10"#, #"(a)\01"#, #"[\01]"#, #"\07"#, #"\c_"#, #"\c!"#, #"\x6g"#, #"[\x6]"#,
        ]
        for pattern in refused { assertRegex(pattern, "gu", "a-%_{}]", nil) }
        assertRegex(#"[\c_]"#, "gu", "\u{1F}", nil)
    }

    func testA2_withUDartRefusesALoneBracketARangeOnASetAndAQuantifiedLookahead() {
        // A lone `{`, `}` or `]` and a brace that finishes no quantifier; a class range with a class escape or a
        // property on either side; a lookahead with a quantifier (a lookbehind is refused in both modes).
        let refused = [
            "{", "}", "]", "a{1", "x{,3}", #"[a-\d]"#, #"[\d-z]"#, #"[\p{L}-z]"#, #"[a-\p{L}]"#, #"[\w-a]"#,
            "(?=a)*", "(?!a)?", #"(?<a>x)\k<b>"#, #"(?<a>x)\k"#, #"[\d-\d]"#, #"[\s-a]"#, #"[a-\s]"#, #"[\w-\d]"#,
            #"[\D-z]"#, #"[\P{L}-z]"#, #"[\S-a]"#, #"[a-\W]"#, "(?=a)+", "(?!a)*", "(?=a){2}", "(?<=a)*", "a{,3}",
            "x{,}", "[]a]", "[[:alpha:]]", "a]",
        ]
        for pattern in refused { assertRegex(pattern, "gu", "a-%_{}]", nil) }
    }

    func testA2_guard_withUTheStrictGrammarsEscapesStayValid() {
        let rows: [(String, String, String, UInt)] = [
            (#"\/"#, "a/", "a#", #line),
            (#"\^"#, "^", "#", #line),
            (#"[\-]"#, "-a", "#a", #line),
            (#"\$"#, "$", "#", #line),
            (#"[\^]"#, "^", "#", #line),
            (#"[\/]"#, "/", "#", #line),
            (#"\0"#, "a\u{0}", "a#", #line),
            (#"[\0]"#, "a\u{0}", "a#", #line),
            (#"[\b]"#, "\u{8}b", "#b", #line),
            (#"\cA"#, "\u{1}", "#", #line),
            (#"(?<a>x)\k<a>"#, "xx x", "# x", #line),
            (#"[\d-]"#, "a1-", "a##", #line),
            (#"[-\d]"#, "a1-", "a##", #line),
            (#"[a\-z]"#, "a-zb", "###b", #line),
            (#"😀"#, "a\u{1F600}", "a#", #line),
            ("(?:(?=a))*", "ab", "#a#b#", #line),
            (#"\]"#, "a]", "a#", #line),
            (#"\}"#, "a}", "a#", #line),
            (#"\{"#, "a{", "a#", #line),
            (#"\|"#, "a|", "a#", #line),
            (#"(a)\1"#, "aa a", "# a", #line),
            (#"(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\10"#, "abcdefghijj", "#", #line),
            (#"\0a"#, "a\u{0}a", "a#", #line),
            (#"\cz"#, "\u{1A}", "#", #line),
            (#"[\cz]"#, "\u{1A}", "#", #line),
            (#"[\cA-\cC]"#, "\u{1}\u{2}\u{3}\u{4}", "###\u{4}", #line),
            ("x{1,2}", "xxx", "##", #line),
            (#"\f\n\r\t"#, "\u{C}\n\r\t", "#", #line),
            (#"\p{L}"#, "a1", "#1", #line),
            (#"[\p{L}-]"#, "a-1", "##1", #line),
            (#"[\b-\n]"#, "\u{8}\t\n\u{B}", "###\u{B}", #line),
            (#"\."#, "a.", "a#", #line),
            (#"[\.]"#, "a.", "a#", #line),
            (#"\x41"#, "A", "#", #line),
            (#"\u{61}"#, "a", "#", #line),
            (#"[\]]"#, "a]", "a#", #line),
            (#"[\-a]"#, "-ab", "##b", #line),
            (#"\\"#, "a\\", "a#", #line),
            (#"[\w-]"#, "a-%", "##%", #line),
            (#"\b\B"#, "ab", "ab", #line),
        ]
        for (pattern, input, expected, line) in rows { assertRegex(pattern, "gu", input, expected, line: line) }
    }

    func testA2_vIsU000BAndSIsECMAScriptsWhiteSpaceUnderEveryFlag() {
        // `\v` is U+000B alone and `\s` U+0009-000D, U+0020, U+00A0, U+1680, U+2000-200A, U+2028, U+2029,
        // U+202F, U+205F, U+3000 and U+FEFF (not U+0085, U+180E, U+200B), in and out of classes.
        let v = "a\u{B}\n\u{C}\r\t\u{85}\u{2028}\u{2029} b"
        let w = "a\u{FEFF}b\u{180E}\u{200B}c\u{A0}d\u{1680}\u{2000}\u{200A}\u{202F}\u{205F}\u{3000}\u{85}"
        let everyFlag: [(String, String, String, UInt)] = [
            (#"\v"#, v, "a#\n\u{C}\r\t\u{85}\u{2028}\u{2029} b", #line),
            (#"[\v]"#, v, "a#\n\u{C}\r\t\u{85}\u{2028}\u{2029} b", #line),
            (#"[^\v]"#, v, "#\u{B}#########", #line),
            (#"\s"#, v, "a#####\u{85}###b", #line),
            (#"[\s]"#, v, "a#####\u{85}###b", #line),
            (#"[^\s]"#, v, "#\u{B}\n\u{C}\r\t#\u{2028}\u{2029} #", #line),
            (#"\S"#, v, "#\u{B}\n\u{C}\r\t#\u{2028}\u{2029} #", #line),
            (#"[\S]"#, v, "#\u{B}\n\u{C}\r\t#\u{2028}\u{2029} #", #line),
            (#"[^\S]"#, v, "a#####\u{85}###b", #line),
            (#"[\s\d]"#, v, "a#####\u{85}###b", #line),
            (#"[^\s\d]"#, v, "#\u{B}\n\u{C}\r\t#\u{2028}\u{2029} #", #line),
            (#"[\v-\r]"#, v, "a#\n##\t\u{85}\u{2028}\u{2029} b", #line),
            (#"\s"#, w, "a#b\u{180E}\u{200B}c#d######\u{85}", #line),
            (#"\S"#, w, "#\u{FEFF}####\u{A0}#\u{1680}\u{2000}\u{200A}\u{202F}\u{205F}\u{3000}#", #line),
            (#"[\s]"#, w, "a#b\u{180E}\u{200B}c#d######\u{85}", #line),
            (#"[\S]"#, w, "#\u{FEFF}####\u{A0}#\u{1680}\u{2000}\u{200A}\u{202F}\u{205F}\u{3000}#", #line),
            (#"[^\s]"#, w, "#\u{FEFF}####\u{A0}#\u{1680}\u{2000}\u{200A}\u{202F}\u{205F}\u{3000}#", #line),
            (#"[^\S]"#, w, "a#b\u{180E}\u{200B}c#d######\u{85}", #line),
            (#"\s+"#, w, "a#b\u{180E}\u{200B}c#d#\u{85}", #line),
            (#"[\sa]"#, w, "##b\u{180E}\u{200B}c#d######\u{85}", #line),
        ]
        for flags in ["g", "gu", "gi", "giu"] {
            for (pattern, input, expected, line) in everyFlag { assertRegex(pattern, flags, input, expected, line: line) }
        }
        let gAndGu: [(String, String, String, UInt)] = [
            (#"\f"#, v, "a\u{B}\n#\r\t\u{85}\u{2028}\u{2029} b", #line),
            (#"\n"#, v, "a\u{B}#\u{C}\r\t\u{85}\u{2028}\u{2029} b", #line),
            (#"\r"#, v, "a\u{B}\n\u{C}#\t\u{85}\u{2028}\u{2029} b", #line),
            (#"\t"#, v, "a\u{B}\n\u{C}\r#\u{85}\u{2028}\u{2029} b", #line),
            (#"[\f]"#, v, "a\u{B}\n#\r\t\u{85}\u{2028}\u{2029} b", #line),
            (#"\s"#, "a\u{FEFF}b\u{180E}\u{200B}c\u{A0}d", "a#b\u{180E}\u{200B}c#d", #line),
            (#"[\S]"#, "a\u{FEFF}\u{85}", "#\u{FEFF}#", #line),
            (#"\S"#, "\u{FEFF}\u{85}", "\u{FEFF}#", #line),
        ]
        for flags in ["g", "gu"] {
            for (pattern, input, expected, line) in gAndGu { assertRegex(pattern, flags, input, expected, line: line) }
        }
        // `\V`, `\h`, `\H` and `\R` are the letters without `u` and refused with it.
        for pattern in [#"\V"#, #"\h"#, #"\H"#, #"\R"#] {
            for flags in ["g", "gi"] { assertRegex(pattern, flags, v, v) }
            for flags in ["gu", "giu"] { assertRegex(pattern, flags, v, nil) }
        }
    }

    func testA2_anEmptyClassTakesAQuantifierUnderEveryFlag() {
        let rows: [(String, String, String, UInt)] = [
            ("[]*", "ab", "#a#b#", #line),
            ("[]+", "ab", "ab", #line),
            ("[]?", "ab", "#a#b#", #line),
            ("a[]?b", "ab", "#", #line),
            ("[]{2}", "ab", "ab", #line),
            ("[]{0}", "ab", "#a#b#", #line),
            ("(?:[])*", "ab", "#a#b#", #line),
            ("[]*?", "ab", "#a#b#", #line),
            ("[^]*", "ab", "##", #line),
            ("a[]*b", "ab", "#", #line),
            ("[]|a", "ab", "#b", #line),
            ("[^]?", "ab", "###", #line),
        ]
        for flags in ["g", "gu", "gi", "giu"] {
            for (pattern, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
        }
        assertRegex("(?=a)*", "g", "ab", "#a#b#")
        assertRegex("(?=a)*", "gu", "ab", nil)
    }

    func testA2_guard_aDecimalEscapePastIntIsNoBackreference() {
        // Digits past Int.max name no group: with `u` refused, without it `\9` and the digits, or an octal escape.
        let rows: [(String, String, String, UInt)] = [
            (#"\99999999999999999999"#, "99999999999999999999 9", "# 9", #line),
            (#"(a)\12345678901234567890"#, "aaS45678901234567890 a", "a# a", #line),
            (#"\12345678901234567890"#, "S45678901234567890", "#", #line),
            (#"[\12345678901234567890]"#, "S4x", "##x", #line),
            (#"(a)\9223372036854775808"#, "a9223372036854775808", "#", #line),
        ]
        for (pattern, input, expected, line) in rows {
            assertRegex(pattern, "g", input, expected, line: line)
            assertRegex(pattern, "gu", input, nil, line: line)
        }
    }

    // MARK: S15 — group names, unset references (row 23b.37)

    // Group names are dropped (`(?<a>x)` is `(x)`, `\k<a>` the group's number) and a reference that can only see
    // its group unset matches empty; Dart 3.12.2 printed every value (nil: refused), the same under g and gu.

    func testG3_aGroupNameIsDroppedSoEveryNameDartAcceptsWorks() {
        // ECMAScript's identifier: ID_Start, `$` or `_`, then ID_Continue, `$`, ZWNJ or ZWJ, `\u` escapes read.
        let n = "x xx ab k"
        let rows: [(String, String, String?, UInt)] = [
            ("(?<$a>x)", "x", "#", #line),
            ("(?<\u{E9}>x)", "x", "#", #line),
            ("(?<a>x)", n, "# ## ab k", #line),
            ("(?<$>x)", n, "# ## ab k", #line),
            ("(?<_>x)", n, "# ## ab k", #line),
            ("(?<a1>x)", n, "# ## ab k", #line),
            ("(?<a$_\u{200C}\u{200D}>x)", n, "# ## ab k", #line),
            ("(?<\u{1D49C}>x)", n, "# ## ab k", #line),
            ("(?<a\u{300}>x)", n, "# ## ab k", #line),
            ("(?<a\u{B7}>x)", n, "# ## ab k", #line),
            ("(?<a\\u{62}>x)", n, "# ## ab k", #line),
            ("(?<a\\u{0062}>x)", n, "# ## ab k", #line),
            ("(?<\\u{1D49C}>x)", n, "# ## ab k", #line),
            ("(?<a\\u0024>x)", n, "# ## ab k", #line),
            ("(?<a\\u0062>x)\\k<ab>", n, "x # ab k", #line),
            ("(?<ab>x)\\k<a\\u{62}>", n, "x # ab k", #line),
            ("(?<a\\u{62}>x)\\k<ab>", "x xx", "x #", #line),
            ("(?<A>x)\\k<A>", n, "x # ab k", #line),
            ("(?<1a>x)", n, nil, #line),
            ("(?<a-b>x)", n, nil, #line),
            ("(?<>x)", n, nil, #line),
            ("(?<\u{1F600}>x)", n, nil, #line),
            ("(?<a\u{1F600}>x)", n, nil, #line),
            ("(?<\u{300}>x)", n, nil, #line),
            ("(?<\\u0031>x)", n, nil, #line),
            ("(?<a\\u002D>x)", n, nil, #line),
            ("(?<a\\x62>x)", n, nil, #line),
            ("(?<a\\>x)", n, nil, #line),
            ("(?<a\\u{>x)", n, nil, #line),
            ("(?<a\\u{}>x)", n, nil, #line),
            ("(?<a\\u{110000}>x)", n, nil, #line),
            ("(?<a\\u006>x)", n, nil, #line),
            ("(?<a\\uD835>x)", n, nil, #line),
            ("(?<a\\u{D835}\\u{DC9C}>x)", n, nil, #line),
            ("(?<a", n, nil, #line),
        ]
        for flags in ["g", "gu"] {
            for (pattern, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testG3_aNameTwoAlternativesHoldIsTheGroupThatTookPart() {
        // Two groups may share a name only in two alternatives of a disjunction; `\k<a>` is then each of them.
        let rows: [(String, String, String?, UInt)] = [
            ("(?<a>x)|(?<a>y)", "xy", "##", #line),
            (#"(?:(?<a>x)|(?<a>y))\k<a>"#, "xx yy xy", "# # xy", #line),
            ("(?<a>x)|(?<a>y)|(?<a>z)", "xyz w", "### w", #line),
            (#"(?<a>x)|(?:(?<a>y)|(?<a>z))\k<a>"#, "x yy zz yz zy", "# # # yz zy", #line),
            (#"(?:(?<a>x)|(?<a>y))\k<a>\k<a>"#, "xxx yyy xyy", "# # xyy", #line),
            ("(?<a>x)(?<a>y)", "xy", nil, #line),
            ("(?:(?<a>x)|(?<a>y))(?<a>z)", "xyz", nil, #line),
            ("(?<a>x(?<a>y))", "xy", nil, #line),
            ("(?<ab>x)(?<a\\u0062>y)", "xy", nil, #line),
            ("(?<ab>x)(?<a\\u{62}>y)", "xy", nil, #line),
        ]
        for flags in ["g", "gu"] {
            for (pattern, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testG3_withANamedGroupKIsTheReferenceToOne() {
        // `\k` without the `<name>` of a group, in a class too, is refused once some group has a name.
        let rows: [(String, String, String?, UInt)] = [
            (#"(?<a>x)\1"#, "xx", "#", #line),
            (#"(?<a>x)(?<b>y)\k<b>\k<a>"#, "xyyx", "#", #line),
            (#"(?<a>.)\k<a>(?<b>.)\2"#, "aabb", "#", #line),
            (#"(?<a>x)\k<a>1"#, "xx1 x1 xx", "# x1 xx", #line),
            (#"(?<a>x)\k<a>*"#, "x xx xxx", "# # #", #line),
            (#"(?<a>x)\k<a>\k<a>"#, "xxx x", "# x", #line),
            (#"(?<a>x)\k<\u{61}>"#, "x xx", "x #", #line),
            (#"(?<a>x)(?:\k<a>|(?<b>y)\k<b>)"#, "xx xyy xy", "# # xy", #line),
            (#"(?<a>x)\k<b>"#, "xx", nil, #line),
            (#"(?<a>x)\k"#, "xk", nil, #line),
            (#"(?<a>x)\k<a"#, "xx", nil, #line),
            (#"(?<a>x)\ka"#, "x xka", nil, #line),
            (#"(?<a>x)\k<A>"#, "xx", nil, #line),
            (#"(?<a>x)\k<1a>"#, "x", nil, #line),
            ("(?<a>x)\\k<a\\u0062>", "xx", nil, #line),
            (#"(?<a>x)[\k]"#, "xk", nil, #line),
            (#"(?<a>x)[\k<a>]"#, "xk", nil, #line),
        ]
        for flags in ["g", "gu"] {
            for (pattern, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testG3_aReferenceThatCanOnlySeeItsGroupUnsetMatchesEmpty() {
        // It stands before its group closes, or in another alternative of a disjunction that holds the group
        // (a quantifier resets the groups inside it at each pass, so a pass before cannot set them).
        let f = "a ab aab b ba aba abab xx"
        let u = "b ab aa ba bb abb aab xy y x"
        let rows: [(String, String, String, UInt)] = [
            (#"\1(a)"#, "aa", "##", #line),
            (#"(a\1)"#, "aa", "##", #line),
            (#"(a)|\1b"#, "ab b", "## #", #line),
            (#"(a)|b\1"#, "ab b", "## #", #line),
            (#"\2(a)(b)"#, "ab", "#", #line),
            (#"(?:\1b|(a))+"#, "ab", "#", #line),
            (#"(a)(?:\2(b))"#, "ab", "#", #line),
            (#"\k<a>(?<a>x)"#, "xx", "##", #line),
            (#"(\1a)"#, f, "# #b ##b b b# #b# #b#b xx", #line),
            (#"(?:\1b|(a))+"#, f, "# # # # # # # xx", #line),
            (#"(a)|\1b"#, f, "# ## ### # ## ### #### xx", #line),
            (#"\k<a>(?<a>x)"#, f, "a ab aab b ba aba abab ##", #line),
            (#"((a)|\2b)"#, "b ab", "# ##", #line),
            (#"(?:(a)|\1b)+"#, u, "# # # # # # # xy y x", #line),
            (#"(?:(?:(a))|\1)"#, u, "#b# ##b# ### #b## #b#b# ##b#b# ###b# #x#y# #y# #x#", #line),
            (#"(a)\1|\1b"#, u, "# a# # #a ## a## ## xy y x", #line),
            (#"(?=(a)|\1b)"#, "ab b", "#a#b #b", #line),
            (#"(?<a>x)|\k<a>y"#, u, "b ab aa ba bb abb aab ## # #", #line),
            (#"(?:(?<a>x)|(?<a>y))|\k<a>z"#, u, "b ab aa ba bb abb aab ## # #", #line),
            (#"(?:(?<a>x)|(?<a>y)|\k<a>z)"#, u, "b ab aa ba bb abb aab ## # #", #line),
            (#"(?<a>x)(?<b>y)|\k<a>\k<b>"#, "xy y x", "## #y# #x#", #line),
            (#"(?<a>x)(?:(?<b>y)|\k<b>)"#, u, "b ab aa ba bb abb aab # y #", #line),
        ]
        for flags in ["g", "gu"] {
            for (pattern, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testG3_guard_aReferenceToAGroupBehindItKeepsItsMatch() {
        let u = "b ab aa ba bb abb aab xy y x"
        let rows: [(String, String, String, UInt)] = [
            (#"((a)\2)"#, u, "b ab # ba bb abb #b xy y x", #line),
            (#"\1*(a)"#, u, "b #b ## b# bb #bb ##b xy y x", #line),
            (#"(a)(?:|\1)b"#, u, "b # aa ba bb #b # xy y x", #line),
            (#"(?=(a))\1"#, u, "b #b ## b# bb #bb ##b xy y x", #line),
            (#"(?<=(a))\1"#, u, "b ab a# ba bb abb a#b xy y x", #line),
            (#"(a)(?=\1)"#, u, "b ab #a ba bb abb #ab xy y x", #line),
            (#"(?<a>a)\k<a>"#, u, "b ab # ba bb abb #b xy y x", #line),
            (#"(?i:(?<a>x)|\k<a>X)"#, u, "b ab aa ba bb abb aab #y y #", #line),
            (#"(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)\10"#, "abcdefghijj", "#", #line),
        ]
        for flags in ["g", "gu"] {
            for (pattern, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
        }
        // Past the group count a decimal escape is octal or a digit without `u`, and refused with it.
        for (pattern, input) in [(#"(a)\2"#, "a\u{2}"), (#"(a)\10"#, "a\u{8}"), (#"(a)\8"#, "a8")] {
            assertRegex(pattern, "g", input, "#")
            assertRegex(pattern, "gu", input, nil)
        }
    }

    func testG3_aReferenceIsWrittenAsTheNumbersOfTheGroupsItCanSee() {
        // `(?:\N)`, so that a digit after it stays a digit; in a lookbehind, which Dart reads right to left, all.
        let rows: [(String, String, UInt)] = [
            (#"(?<a>x)\k<a>"#, #"(x)(?:\1)"#, #line),
            (#"(?<a>x)\k<a>1"#, #"(x)(?:\1)1"#, #line),
            (#"(a)\1"#, #"(a)(?:\1)"#, #line),
            (#"(?:(?<a>x)|(?<a>y))\k<a>"#, #"(?:(x)|(y))(?:\1|\2)"#, #line),
            (#"(?<a>x)|(?:(?<a>y)|(?<a>z))\k<a>"#, #"(x)|(?:(y)|(z))(?:\2|\3)"#, #line),
            (#"\1(a)"#, "(?:)(a)", #line),
            (#"(a)|b\1"#, "(a)|b(?:)", #line),
            (#"\k<a>(?<a>x)"#, "(?:)(x)", #line),
            (#"(?<=\1(a))b"#, #"(?<=(?:\1)(a))b"#, #line),
            (#"(a)|(?<=\1)b"#, #"(a)|(?<=(?:\1))b"#, #line),
        ]
        for (pattern, written, line) in rows {
            for unicode in [false, true] {
                XCTAssertEqual(Regex.asciiClasses(pattern, ignoreCase: false, unicode: unicode), written, line: line)
            }
        }
    }

    func testG3_aReferenceToAGroupInANegativeLookaroundMatchesEmpty() {
        // A negative lookaround succeeds only when its body fails, so after it every group inside is unset.
        let u = "b ab aa ba bb abb aab xy y x"
        let rows: [(String, String, String, UInt)] = [
            (#"(?!(a))\1"#, u, "#b# a#b# aa# #ba# #b#b# a#b#b# aa#b# #x#y# #y# #x#", #line),
            (#"(?!(a))\1b"#, u, "# a# aa #a ## a## aa# xy y x", #line),
            (#"(?!(?=(a)))\1"#, u, "#b# a#b# aa# #ba# #b#b# a#b#b# aa#b# #x#y# #y# #x#", #line),
            (#"(?!(a)|(b))\1\2c"#, "c ac bc cc", "# a# b# ##", #line),
            (#"(?!(?<n>a))\k<n>b"#, u, "# a# aa #a ## a## aa# xy y x", #line),
            (#"(a)(?!(b))\1\2"#, "aa ab aab aba", "# ab #b aba", #line),
            (#"(?<!(a))\1b"#, u, "# ab aa #a ## ab# aab xy y x", #line),
            (#"(?:(?!(a))\1b)+"#, u, "# a# aa #a # a# aa# xy y x", #line),
            (#"(?!(?!(a)))\1"#, u, "b #ab #a#a b#a bb #abb #a#ab xy y x", #line),
            (#"(?!(?!(a))\1)b"#, u, u, #line),
            (#"(?!(a))(?:\1b)"#, u, "# a# aa #a ## a## aa# xy y x", #line),
            (#"(?:(?!(a)))\1b"#, u, "# a# aa #a ## a## aa# xy y x", #line),
            (#"((?!(a)))\2b"#, u, "# a# aa #a ## a## aa# xy y x", #line),
        ]
        for flags in ["g", "gu"] {
            for (pattern, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testG3_guard_aNegativeLookaroundsGroupStaysForWhatIsInsideItAndForItsName() {
        // Inside the lookaround a reference sees the group closed before it; a name stays taken after it.
        let u = "b ab aa ba bb abb aab xy y x"
        let rows: [(String, String, String?, UInt)] = [
            (#"(?!(a)\1)b"#, u, "# a# aa #a ## a## aa# xy y x", #line),
            (#"(?!(a)\1)"#, "aa ab", "a#a# #a#b#", #line),
            (#"(a)(?!\1)"#, u, "b #b a# b# bb #bb a#b xy y x", #line),
            ("(?<a>x)|(?!(?<a>y))", "xy y x", "#y# y# ##", #line),
            ("(?!(?<a>x))(?<a>y)", "xy y x", nil, #line),
            ("(?<!(?<a>x))(?<a>y)", "xy y", nil, #line),
            ("(?:(?!(?<a>x))|(?<a>y))(?<a>z)", "xyz", nil, #line),
            ("(?=(?<a>x))(?<a>x)", "xy", nil, #line),
        ]
        for flags in ["g", "gu"] {
            for (pattern, input, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testG3_aReferenceToAGroupInANegativeLookaroundIsWrittenWithoutIt() {
        // `(?:)` when all its groups are, the others when some are (the one set at run time is left to fail).
        let rows: [(String, String, UInt)] = [
            (#"(?!(a))\1b"#, "(?!(a))(?:)b", #line),
            (#"(?<!(a))\1b"#, "(?<!(a))(?:)b", #line),
            (#"(?!(?!(a))\1)b"#, "(?!(?!(a))(?:))b", #line),
            (#"(?!(a)\1)b"#, #"(?!(a)(?:\1))b"#, #line),
            (#"(?<!(a)\1)b"#, #"(?<!(a)(?:\1))b"#, #line),
            (#"(?:(?!(?<a>x))|(?<a>y))\k<a>"#, #"(?:(?!(x))|(y))(?:\2)"#, #line),
            (#"(?:(?!(a))|(a))\2"#, #"(?:(?!(a))|(a))(?:\2)"#, #line),
        ]
        for (pattern, written, line) in rows {
            for unicode in [false, true] {
                XCTAssertEqual(Regex.asciiClasses(pattern, ignoreCase: false, unicode: unicode), written, line: line)
            }
        }
    }

    // MARK: S15 — iu properties, script values (row 23b.37)

    // Under `i` with `u` Dart builds a class holding `\p{…}` or `\P{…}` first and folds after: a character
    // matches when a letter of its simple-fold class is in the class, and a negated class when none is (`\P{Ll}`
    // matches s, as S is no Ll). An escape outside a class is the one-member class. With `u` a script value is one of
    // ECMA-262's, case-sensitive. Dart 3.12.2 printed every value (nil: refused).

    /// s S ſ k K K _ ! é É ǅ Ǆ ǆ ß ẞ: cased letters with partners in other categories, and two with none.
    private static let cased = "sS\u{17F}kK\u{212A}_!\u{E9}\u{C9}\u{1C5}\u{1C4}\u{1C6}\u{DF}\u{1E9E}"
    /// s S k K _ ! é É 1 ǅ Ǆ ǆ ſ K Σ σ ς ẞ ß: the same with a digit and the three sigmas.
    private static let sigmas =
        "sSkK_!\u{E9}\u{C9}1\u{1C5}\u{1C4}\u{1C6}\u{17F}\u{212A}\u{3A3}\u{3C3}\u{3C2}\u{1E9E}\u{DF}"

    func testG4_underIUAPropertyClassIsBuiltFirstAndFoldedAfter() {
        // A class or escape holding a property, negated or not, with other members or not.
        let rows: [(String, String?, UInt)] = [
            (#"\P{Ll}"#, "###############", #line),
            (#"\P{Lu}"#, "###############", #line),
            (#"\P{Lt}"#, "###############", #line),
            (#"[\P{Ll}]"#, "###############", #line),
            (#"[^\P{Ll}]"#, Self.cased, #line),
            (#"[\P{Ll}\d]"#, "###############", #line),
            (#"\P{Lowercase}"#, "###############", #line),
            (#"\P{Script=Latin}"#, "sS\u{17F}kK\u{212A}##\u{E9}\u{C9}\u{1C5}\u{1C4}\u{1C6}\u{DF}\u{1E9E}", #line),
            (#"\p{Lt}"#, "sS\u{17F}kK\u{212A}_!\u{E9}\u{C9}###\u{DF}\u{1E9E}", #line),
            (#"\p{ASCII}"#, "########\u{E9}\u{C9}\u{1C5}\u{1C4}\u{1C6}\u{DF}\u{1E9E}", #line),
            (#"\P{ASCII}"#, "######_!#######", #line),
            (#"\p{Lu}"#, "######_!#######", #line),
            (#"[^\p{Ll}]"#, "sS\u{17F}kK\u{212A}##\u{E9}\u{C9}\u{1C5}\u{1C4}\u{1C6}\u{DF}\u{1E9E}", #line),
            (#"\p{Lowercase_Letter}"#, "######_!#######", #line),
            (#"\p{LC}"#, "######_!#######", #line),
            (#"[\p{Lt}x]"#, "sS\u{17F}kK\u{212A}_!\u{E9}\u{C9}###\u{DF}\u{1E9E}", #line),
        ]
        for (pattern, expected, line) in rows { assertRegex(pattern, "giu", Self.cased, expected, line: line) }
    }

    func testG4_underIUAPropertyClassMatchesByWholeFoldClasses() {
        // `[^\P{Lu}]` matches a letter only when its whole fold class is Lu, none is here: Σ comes with σ and ς.
        let rows: [(String, String?, UInt)] = [
            (#"\P{Ll}"#, "###################", #line),
            (#"\P{Lu}"#, "###################", #line),
            (
                #"[^\p{Ll}]"#,
                "sSkK##\u{E9}\u{C9}#\u{1C5}\u{1C4}\u{1C6}\u{17F}\u{212A}\u{3A3}\u{3C3}\u{3C2}\u{1E9E}\u{DF}", #line
            ),
            (#"[\P{Ll}]"#, "###################", #line),
            (#"[^\P{Ll}]"#, Self.sigmas, #line),
            (#"\P{Lt}"#, "###################", #line),
            (#"\P{Lowercase}"#, "###################", #line),
            (#"\P{Uppercase}"#, "###################", #line),
            (#"\P{Script=Latin}"#, "sSkK##\u{E9}\u{C9}#\u{1C5}\u{1C4}\u{1C6}\u{17F}\u{212A}###\u{1E9E}\u{DF}", #line),
            (
                #"[^\p{Lu}a]"#,
                "sSkK##\u{E9}\u{C9}#\u{1C5}\u{1C4}\u{1C6}\u{17F}\u{212A}\u{3A3}\u{3C3}\u{3C2}\u{1E9E}\u{DF}", #line
            ),
            (#"\p{Ll}"#, "####_!##1##########", #line),
            (#"\p{Lu}"#, "####_!##1##########", #line),
            (#"\p{Lt}"#, "sSkK_!\u{E9}\u{C9}1###\u{17F}\u{212A}\u{3A3}\u{3C3}\u{3C2}\u{1E9E}\u{DF}", #line),
            (#"[^a-z]"#, "sSkK########\u{17F}\u{212A}#####", #line),
            (
                #"[^\p{L}]"#,
                "sSkK##\u{E9}\u{C9}#\u{1C5}\u{1C4}\u{1C6}\u{17F}\u{212A}\u{3A3}\u{3C3}\u{3C2}\u{1E9E}\u{DF}", #line
            ),
            (
                #"\P{L}"#,
                "sSkK##\u{E9}\u{C9}#\u{1C5}\u{1C4}\u{1C6}\u{17F}\u{212A}\u{3A3}\u{3C3}\u{3C2}\u{1E9E}\u{DF}", #line
            ),
            (
                #"\P{Cased}"#,
                "sSkK##\u{E9}\u{C9}#\u{1C5}\u{1C4}\u{1C6}\u{17F}\u{212A}\u{3A3}\u{3C3}\u{3C2}\u{1E9E}\u{DF}", #line
            ),
            (#"[^\P{Lu}]"#, Self.sigmas, #line),
            (#"[\P{Ll}\d]"#, "###################", #line),
            (#"[^\P{Ll}\d]"#, Self.sigmas, #line),
        ]
        for (pattern, expected, line) in rows { assertRegex(pattern, "giu", Self.sigmas, expected, line: line) }
    }

    func testG4_aPropertyClassFoldsTheSameBesideOtherMembersAndInsideGroups() {
        // With letters, sets and binary properties beside it; quantified, in a group, a lookbehind, a modifier group.
        let rows: [(String, String?, UInt)] = [
            (#"\P{Ll}+"#, "#", #line),
            (#"(?:\P{Ll})"#, "###############", #line),
            (#"(?-i:\P{Ll})"#, "s#\u{17F}k####\u{E9}###\u{1C6}\u{DF}#", #line),
            (#"(?i:\P{Ll})"#, "###############", #line),
            (#"[\P{Ll}]{2}"#, "#######\u{1E9E}", #line),
            (#"(?<=\P{Ll})s"#, "s##kK\u{212A}_!\u{E9}\u{C9}\u{1C5}\u{1C4}\u{1C6}\u{DF}\u{1E9E}", #line),
            (#"[\p{Ll}--]"#, nil, #line),
            (#"\p{Ll}\P{Ll}"#, "###_!###\u{1E9E}", #line),
            (#"[s\p{Lu}]"#, "######_!#######", #line),
            (#"[^s\p{Lu}]"#, "sS\u{17F}kK\u{212A}##\u{E9}\u{C9}\u{1C5}\u{1C4}\u{1C6}\u{DF}\u{1E9E}", #line),
            (#"[^\p{Lt}]"#, "##########\u{1C5}\u{1C4}\u{1C6}##", #line),
            (#"\P{Lt}"#, "###############", #line),
            (#"[\p{L}&&\p{Ll}]"#, "######_!#######", #line),
            (#"[\w\P{Ll}]"#, "###############", #line),
            (#"[^\w\p{Lu}]"#, "sS\u{17F}kK\u{212A}_#\u{E9}\u{C9}\u{1C5}\u{1C4}\u{1C6}\u{DF}\u{1E9E}", #line),
            (#"[\p{ASCII}]"#, "########\u{E9}\u{C9}\u{1C5}\u{1C4}\u{1C6}\u{DF}\u{1E9E}", #line),
            (#"[^\p{ASCII}]"#, "sS\u{17F}kK\u{212A}_!#######", #line),
            (#"\p{Lowercase}"#, "######_!#######", #line),
            (#"\p{Uppercase}"#, "######_!#######", #line),
            (#"[^\P{Lowercase}]"#, Self.cased, #line),
            (#"\p{Changes_When_Casefolded}"#, "######_!#######", #line),
            (#"\P{Changes_When_Casefolded}"#, "#############\u{DF}\u{1E9E}", #line),
            (#"\p{CWU}"#, "######_!#######", #line),
            (#"\P{CWU}"#, "###############", #line),
        ]
        for (pattern, expected, line) in rows { assertRegex(pattern, "giu", Self.cased, expected, line: line) }
    }

    func testG4_aPropertyClassFoldsLettersAboveFFFFToo() {
        // Deseret 𐐀 𐐨, Osage 𐒰 𐓘, Adlam 𞤀 𞤢 (each a partner pair), 𝐚 (Ll, no partner), 𐌰 (Lo), 😀, x.
        let input = "\u{10400}\u{10428}\u{104B0}\u{104D8}\u{1E900}\u{1E922}\u{1D41A}\u{10330}\u{1F600}x"
        let rows: [(String, String, String?, UInt)] = [
            (#"\P{Ll}"#, "giu", "######\u{1D41A}###", #line),
            (#"\P{Ll}"#, "gu", "#\u{10428}#\u{104D8}#\u{1E922}\u{1D41A}##x", #line),
            (#"[^\P{Ll}]"#, "giu", "\u{10400}\u{10428}\u{104B0}\u{104D8}\u{1E900}\u{1E922}#\u{10330}\u{1F600}x", #line),
            (#"[^\P{Ll}]"#, "gu", "\u{10400}#\u{104B0}#\u{1E900}##\u{10330}\u{1F600}#", #line),
            (#"\p{Lu}"#, "giu", "######\u{1D41A}\u{10330}\u{1F600}#", #line),
            (#"\p{Lu}"#, "gu", "#\u{10428}#\u{104D8}#\u{1E922}\u{1D41A}\u{10330}\u{1F600}x", #line),
            (#"\p{Ll}"#, "giu", "#######\u{10330}\u{1F600}#", #line),
            (#"\p{Ll}"#, "gu", "\u{10400}#\u{104B0}#\u{1E900}##\u{10330}\u{1F600}#", #line),
            (#"[^\p{Lu}]"#, "giu", "\u{10400}\u{10428}\u{104B0}\u{104D8}\u{1E900}\u{1E922}###x", #line),
            (#"[^\p{Lu}]"#, "gu", "\u{10400}#\u{104B0}#\u{1E900}#####", #line),
            (#"\P{Lu}"#, "giu", "##########", #line),
            (#"\P{Lu}"#, "gu", "\u{10400}#\u{104B0}#\u{1E900}#####", #line),
            (#"[\P{Lu}a]"#, "giu", "##########", #line),
            (#"[\P{Lu}a]"#, "gu", "\u{10400}#\u{104B0}#\u{1E900}#####", #line),
            (
                #"\p{Script=Deseret}"#, "giu",
                "##\u{104B0}\u{104D8}\u{1E900}\u{1E922}\u{1D41A}\u{10330}\u{1F600}x", #line
            ),
            (#"\p{Script=Deseret}"#, "gu", "##\u{104B0}\u{104D8}\u{1E900}\u{1E922}\u{1D41A}\u{10330}\u{1F600}x", #line),
            (#"\P{Script=Deseret}"#, "giu", "\u{10400}\u{10428}########", #line),
            (#"\P{Script=Deseret}"#, "gu", "\u{10400}\u{10428}########", #line),
            (#"[^\p{Script=Osage}]"#, "giu", "##\u{104B0}\u{104D8}######", #line),
            (#"[^\p{Script=Osage}]"#, "gu", "##\u{104B0}\u{104D8}######", #line),
            (#"\P{Cased}"#, "giu", "\u{10400}\u{10428}\u{104B0}\u{104D8}\u{1E900}\u{1E922}\u{1D41A}##x", #line),
            (#"\P{Cased}"#, "gu", "\u{10400}\u{10428}\u{104B0}\u{104D8}\u{1E900}\u{1E922}\u{1D41A}##x", #line),
            (#"\p{Lt}"#, "giu", input, #line),
            (#"\p{Lt}"#, "gu", input, #line),
            (#"[\p{Lt}\u{10400}]"#, "giu", "##\u{104B0}\u{104D8}\u{1E900}\u{1E922}\u{1D41A}\u{10330}\u{1F600}x", #line),
            (
                #"[\p{Lt}\u{10400}]"#, "gu",
                "#\u{10428}\u{104B0}\u{104D8}\u{1E900}\u{1E922}\u{1D41A}\u{10330}\u{1F600}x", #line
            ),
            (#"\p{Any}"#, "giu", "##########", #line),
            (#"\p{Any}"#, "gu", "##########", #line),
            (#"[^\p{Any}]"#, "giu", input, #line),
            (#"[^\p{Any}]"#, "gu", input, #line),
            (#"\P{Any}"#, "giu", input, #line),
            (#"\P{Any}"#, "gu", input, #line),
        ]
        for (pattern, flags, expected, line) in rows { assertRegex(pattern, flags, input, expected, line: line) }
    }

    func testG4_withUAScriptValueIsOneOfECMAScriptsExactly() {
        // Unicode's long names and four-letter codes, case-sensitive, no space, plus Qaai and Qaac; none newer
        // than Dart's Unicode (Sidetic, Tai_Yo), no alias (Hrkt, Katakana_Or_Hiragana, Jpan, Zsym), the same under scx.
        let input = "a\u{3B1}\u{300}\u{2C81}\u{309B}\u{951}"  // a, α, U+0300 (Zinh), ⲁ (Copt), ゛ (Zyyy), U+0951 (Zinh)
        // An ICU older than a script's Unicode refuses it, so the pattern is null: Linux's Foundation (in CI, before
        // Unicode 14 with Swift 5.10, before 16 with 6.2), the known difference, pinned. Apple's ICU has Unicode 16.
        let garay = Self.icuKnows(#"\p{sc=Gara}"#)  // Unicode 16
        let cpmn = Self.icuKnows(#"\p{sc=Cpmn}"#)  // Unicode 14
        #if canImport(Darwin)
            XCTAssert(garay && cpmn, "Apple's ICU has Unicode 16, so every row is checked")
        #endif
        // With Unicode 16 only, which gave U+0300 its own Script_Extensions: an older ICU's depend on its version.
        let unchecked: Set<String> =
            garay ? [] : [#"\p{scx=Qaai}"#, #"\p{scx=Inherited}"#, #"\p{scx=Qaac}"#, #"\p{scx=Copt}"#]
        let rows: [(String, String?, UInt)] = [
            (#"\p{Script=latin}"#, nil, #line),
            (#"\p{sc=latn}"#, nil, #line),
            (#"\p{Script=Latn}"#, "#\u{3B1}\u{300}\u{2C81}\u{309B}\u{951}", #line),
            (#"\p{Script=Hrkt}"#, nil, #line),
            (#"\p{Script=Katakana_Or_Hiragana}"#, nil, #line),
            (#"\p{Script= Latin}"#, nil, #line),
            (#"\p{Script=Latin }"#, nil, #line),
            (#"\p{Script=OldItalic}"#, nil, #line),
            (#"\p{Script=Old_Italic}"#, input, #line),
            (#"\p{Script=Qaai}"#, "a\u{3B1}#\u{2C81}\u{309B}#", #line),
            (#"\p{Script=Qaac}"#, "a\u{3B1}\u{300}#\u{309B}\u{951}", #line),
            (#"\p{Script=Zinh}"#, "a\u{3B1}#\u{2C81}\u{309B}#", #line),
            (#"\p{sc=Copt}"#, "a\u{3B1}\u{300}#\u{309B}\u{951}", #line),
            (#"\p{scx=Qaai}"#, input, #line),
            (#"\p{scx=latin}"#, nil, #line),
            (#"\p{Script=}"#, nil, #line),
            (#"\p{Script=Zzzz}"#, input, #line),
            (#"\p{Script=Unknown}"#, input, #line),
            (#"\P{sc=Latn}"#, "a#####", #line),
            (#"[\p{sc=Grek}a]"#, "##\u{300}\u{2C81}\u{309B}\u{951}", #line),
        ]
        for (pattern, expected, line) in rows where !unchecked.contains(pattern) {
            assertRegex(pattern, "gu", input, expected, line: line)
        }
        let both: [(String, String?, UInt)] = [
            (#"\p{Script=LATIN}"#, nil, #line),
            (#"\p{Script=Latin}"#, "#\u{3B1}\u{300}\u{2C81}\u{309B}\u{951}", #line),
            (#"\p{scx=Hrkt}"#, nil, #line),
            (#"\p{Script_Extensions=Katakana_Or_Hiragana}"#, nil, #line),
            (#"[\p{Script=Hrkt}]"#, nil, #line),
            (#"[^\p{sc=latn}]"#, nil, #line),
            (#"\p{Script=Sidetic}"#, nil, #line),
            (#"\p{Script=Tai_Yo}"#, nil, #line),
            (#"\p{Script=Garay}"#, garay ? input : nil, #line),
            (#"\p{sc=Gara}"#, garay ? input : nil, #line),
            (#"\p{scx=Garay}"#, garay ? input : nil, #line),
            (#"\p{Script=Qaac}"#, "a\u{3B1}\u{300}#\u{309B}\u{951}", #line),
            (#"\p{scx=Qaac}"#, "a\u{3B1}##\u{309B}\u{951}", #line),
            (#"\p{scx=Copt}"#, "a\u{3B1}##\u{309B}\u{951}", #line),
            (#"\p{Script_Extensions=Zyyy}"#, input, #line),
            (#"\p{sc=Zyyy}"#, "a\u{3B1}\u{300}\u{2C81}#\u{951}", #line),
            (#"\p{Script=Zzzz}"#, input, #line),
            (#"\p{scx=Zzzz}"#, input, #line),
            (#"\p{scx=Unknown}"#, input, #line),
            (#"\p{Script=Unknown }"#, nil, #line),
            (#"\p{Script=_Latin}"#, nil, #line),
            (#"\p{Script=Latin_}"#, nil, #line),
            (#"\p{Script=Old Italic}"#, nil, #line),
            (#"\p{Script=Old-Italic}"#, nil, #line),
            (#"\p{Script=oldItalic}"#, nil, #line),
            (#"\p{sc=Brai}"#, input, #line),
            (#"\p{sc=Braille}"#, input, #line),
            (#"\p{scx=Inherited}"#, input, #line),
            (#"\p{Script=Zinh}"#, "a\u{3B1}#\u{2C81}\u{309B}#", #line),
            (#"\p{sc=Qaai}"#, "a\u{3B1}#\u{2C81}\u{309B}#", #line),
            (#"\p{sc=Hira}"#, input, #line),
            (#"\p{sc=Kana}"#, input, #line),
            (#"\p{sc=Hani}"#, input, #line),
            (#"\p{sc=Han}"#, input, #line),
            (#"\p{sc=Jpan}"#, nil, #line),
            (#"\p{sc=Zsym}"#, nil, #line),
            (#"\p{sc=Zmth}"#, nil, #line),
            (#"\p{sc=Zsye}"#, nil, #line),
            (#"\p{sc=Latf}"#, nil, #line),
            (#"\p{sc=Aran}"#, nil, #line),
            (#"\p{sc=Syrc}"#, input, #line),
            (#"\p{sc=Syre}"#, nil, #line),
            (#"\p{sc=Geok}"#, nil, #line),
            (#"\p{sc=Hans}"#, nil, #line),
            (#"\p{sc=Qabx}"#, nil, #line),
            (#"\p{sc=Cpmn}"#, cpmn ? input : nil, #line),
            (#"\p{sc=Copt}"#, "a\u{3B1}\u{300}#\u{309B}\u{951}", #line),
        ]
        for flags in ["gu", "giu"] {
            for (pattern, expected, line) in both where !unchecked.contains(pattern) {
                assertRegex(pattern, flags, input, expected, line: line)
            }
        }
    }

    /// The script values Dart 3.12.2 accepts after `Script=`, `sc=`, `Script_Extensions=` and `scx=` with `u`.
    private static let dartScripts = """
        Adlam Adlm Aghb Ahom Anatolian_Hieroglyphs Arab Arabic Armenian Armi Armn Avestan Avst Bali Balinese \
        Bamu Bamum Bass Bassa_Vah Batak Batk Beng Bengali Bhaiksuki Bhks Bopo Bopomofo Brah Brahmi Brai Braille \
        Bugi Buginese Buhd Buhid Cakm Canadian_Aboriginal Cans Cari Carian Caucasian_Albanian Chakma Cham Cher \
        Cherokee Chorasmian Chrs Common Copt Coptic Cpmn Cprt Cuneiform Cypriot Cypro_Minoan Cyrillic Cyrl \
        Deseret Deva Devanagari Diak Dives_Akuru Dogr Dogra Dsrt Dupl Duployan Egyp Egyptian_Hieroglyphs Elba \
        Elbasan Elym Elymaic Ethi Ethiopic Gara Garay Geor Georgian Glag Glagolitic Gong Gonm Goth Gothic Gran \
        Grantha Greek Grek Gujarati Gujr Gukh Gunjala_Gondi Gurmukhi Guru Gurung_Khema Han Hang Hangul Hani \
        Hanifi_Rohingya Hano Hanunoo Hatr Hatran Hebr Hebrew Hira Hiragana Hluw Hmng Hmnp Hung Imperial_Aramaic \
        Inherited Inscriptional_Pahlavi Inscriptional_Parthian Ital Java Javanese Kaithi Kali Kana Kannada \
        Katakana Kawi Kayah_Li Khar Kharoshthi Khitan_Small_Script Khmer Khmr Khoj Khojki Khudawadi Kirat_Rai \
        Kits Knda Krai Kthi Lana Lao Laoo Latin Latn Lepc Lepcha Limb Limbu Lina Linb Linear_A Linear_B Lisu \
        Lyci Lycian Lydi Lydian Mahajani Mahj Maka Makasar Malayalam Mand Mandaic Mani Manichaean Marc Marchen \
        Masaram_Gondi Medefaidrin Medf Meetei_Mayek Mend Mende_Kikakui Merc Mero Meroitic_Cursive \
        Meroitic_Hieroglyphs Miao Mlym Modi Mong Mongolian Mro Mroo Mtei Mult Multani Myanmar Mymr Nabataean \
        Nag_Mundari Nagm Nand Nandinagari Narb Nbat New_Tai_Lue Newa Nko Nkoo Nshu Nushu Nyiakeng_Puachue_Hmong \
        Ogam Ogham Ol_Chiki Ol_Onal Olck Old_Hungarian Old_Italic Old_North_Arabian Old_Permic Old_Persian \
        Old_Sogdian Old_South_Arabian Old_Turkic Old_Uyghur Onao Oriya Orkh Orya Osage Osge Osma Osmanya Ougr \
        Pahawh_Hmong Palm Palmyrene Pau_Cin_Hau Pauc Perm Phag Phags_Pa Phli Phlp Phnx Phoenician Plrd Prti \
        Psalter_Pahlavi Qaac Qaai Rejang Rjng Rohg Runic Runr Samaritan Samr Sarb Saur Saurashtra Sgnw Sharada \
        Shavian Shaw Shrd Sidd Siddham SignWriting Sind Sinh Sinhala Sogd Sogdian Sogo Sora Sora_Sompeng Soyo \
        Soyombo Sund Sundanese Sunu Sunuwar Sylo Syloti_Nagri Syrc Syriac Tagalog Tagb Tagbanwa Tai_Le Tai_Tham \
        Tai_Viet Takr Takri Tale Talu Tamil Taml Tang Tangsa Tangut Tavt Telu Telugu Tfng Tglg Thaa Thaana Thai \
        Tibetan Tibt Tifinagh Tirh Tirhuta Tnsa Todhri Todr Toto Tulu_Tigalari Tutg Ugar Ugaritic Unknown Vai \
        Vaii Vith Vithkuqi Wancho Wara Warang_Citi Wcho Xpeo Xsux Yezi Yezidi Yi Yiii Zanabazar_Square Zanb Zinh \
        Zyyy Zzzz
        """.split(separator: " ").map(String.init)

    /// Whether the platform's ICU compiles `pattern` as written, the SDK's rewriter bypassed.
    private static func icuKnows(_ pattern: String) -> Bool { (try? NSRegularExpression(pattern: pattern)) != nil }

    func testG4_guard_everyScriptValueTheICUKnowsStaysValid() {
        // Under each of the four keys, every value the platform's ICU knows: all 1 344 on Apple's; a script newer
        // than its Unicode is refused as written (Linux's Foundation), so the SDK's null there is the known difference.
        XCTAssertEqual(Self.dartScripts.count, 336)
        XCTAssertEqual(Regex.scriptValues, Set(Self.dartScripts))
        var refused: [String] = []
        var skipped = 0
        for key in ["Script", "sc", "Script_Extensions", "scx"] {
            for value in Self.dartScripts {
                let pattern = "\\p{\(key)=\(value)}"
                guard Self.icuKnows(pattern) else {
                    skipped += 1
                    continue
                }
                let step: JSONValue = ["type": "regex", "pattern": .string(pattern), "flags": "gu", "replacement": "#"]
                if run(.string("a"), step) == .null { refused.append(pattern) }
            }
        }
        XCTAssert(refused.isEmpty, "\(refused.count) refused: " + refused.prefix(8).joined(separator: "; "))
        #if canImport(Darwin)
            XCTAssertEqual(skipped, 0, "Apple's ICU has Unicode 16, so all 1 344 are checked")
        #endif
    }

    func testG4_theFoldClassesHoldTheFoldTablesSetsWithU() {
        // The data, as printed: 1 454 classes of 2 to 4 letters, 2 938 letters, 564 of them above U+FFFF. A table
        // letter's set with `u` is its class, or the letter alone where it has no partner (ﬀ, ŉ, ǰ, …).
        let letters = Regex.foldClassLetters
        XCTAssertEqual(letters.count, 2938)
        XCTAssertEqual(letters.filter { $0.value > 0xFFFF }.count, 564)
        XCTAssertEqual(Set(letters.compactMap { Regex.foldClasses[$0]?.map(\.value) }).count, 1454)
        for c in letters {
            let members = Regex.foldClasses[c] ?? []
            XCTAssert((2...4).contains(members.count) && members.contains(c), "\(c.value)")
            XCTAssert(members.allSatisfy { Regex.foldClasses[$0] == members }, "\(c.value)")
        }
        for c in Regex.foldLetters {
            XCTAssertEqual(Set(Regex.dartFold(c, unicode: true) ?? []), Set(Regex.foldClasses[c] ?? [c]), "\(c.value)")
        }
    }

    // MARK: S16 — UTF-16 units without u (row 23b.38)

    // Without `u` Dart reads a pattern and its input as UTF-16 code units: each half of a surrogate pair is one
    // character to `.`, a class or a quantifier, an empty match falls between the halves, and a letter above U+FFFF
    // never folds. Dart 3.14.0 printed every value (nil: refused). Where Dart's result splits a pair, Swift writes
    // U+FFFD (`h` below) for each lone half, a known difference (row 23b.38): Dart's "#", D83D, "#", DE00, "#" is
    // "#\u{FFFD}#\u{FFFD}#" here.

    /// 😀 (D83D DE00) and 𐐨 (Deseret, D801 DC28): a pair alone, between letters, twice, after a line break.
    private static let pairs = ["\u{1F600}", "a\u{1F600}b", "\u{1F600}\u{1F600}", "\u{10428}", "a\n\u{1F600}"]

    func testU1_withoutUEachHalfOfAPairIsOneUnit() {
        // `.`, a negated class or escape takes one half, `.{2}` a pair, `^.$` none; an empty match falls between the
        // halves; `[😀]` has two members, `😀+` repeats the low half; `\uD83D`, a class member, a range end is a half.
        // One value per input of `pairs`, the same under g, gi, gm and gs but on "a\n😀".
        let (e, small, h) = ("\u{1F600}", "\u{10428}", "\u{FFFD}")
        let rows: [(String, [String?], UInt)] = [
            (".", ["##", "####", "####", "##", "#\n##"], #line),
            ("[^a]", ["##", "a###", "####", "##", "a###"], #line),
            (#"\S"#, ["##", "####", "####", "##", "#\n##"], #line),
            (#"\W"#, ["##", "a##b", "####", "##", "a###"], #line),
            (#"\D"#, ["##", "####", "####", "##", "####"], #line),
            ("[^]", ["##", "####", "####", "##", "####"], #line),
            (".{2}", ["#", "##", "##", "#", "a\n#"], #line),
            ("^.$", [e, "a\(e)b", "\(e)\(e)", small, "a\n\(e)"], #line),
            ("^..$", ["#", "a\(e)b", "\(e)\(e)", "#", "a\n\(e)"], #line),
            ("(.)", ["##", "####", "####", "##", "#\n##"], #line),
            (".?", ["###", "#####", "#####", "###", "##\n###"], #line),
            (
                "a??", ["#\(h)#\(h)#", "#a#\(h)#\(h)#b#", "#\(h)#\(h)#\(h)#\(h)#", "#\(h)#\(h)#", "#a#\n#\(h)#\(h)#"],
                #line
            ),
            ("", ["#\(h)#\(h)#", "#a#\(h)#\(h)#b#", "#\(h)#\(h)#\(h)#\(h)#", "#\(h)#\(h)#", "#a#\n#\(h)#\(h)#"], #line),
            (
                "(?:)", ["#\(h)#\(h)#", "#a#\(h)#\(h)#b#", "#\(h)#\(h)#\(h)#\(h)#", "#\(h)#\(h)#", "#a#\n#\(h)#\(h)#"],
                #line
            ),
            (
                "x*", ["#\(h)#\(h)#", "#a#\(h)#\(h)#b#", "#\(h)#\(h)#\(h)#\(h)#", "#\(h)#\(h)#", "#a#\n#\(h)#\(h)#"],
                #line
            ),
            (#"\B"#, ["#\(h)#\(h)#", "a\(h)#\(h)b", "#\(h)#\(h)#\(h)#\(h)#", "#\(h)#\(h)#", "a\n#\(h)#\(h)#"], #line),
            ("[\(e)]", ["##", "a##b", "####", small, "a\n##"], #line),
            ("[^\(e)]", [e, "#\(e)#", "\(e)\(e)", "##", "##\(e)"], #line),
            ("\(e)+", ["#", "a#b", "##", small, "a\n#"], #line),
            (#"[\uD83D]"#, ["#\(h)", "a#\(h)b", "#\(h)#\(h)", small, "a\n#\(h)"], #line),
            (#"\uD83D"#, ["#\(h)", "a#\(h)b", "#\(h)#\(h)", small, "a\n#\(h)"], #line),
            (#"\uDE00"#, ["\(h)#", "a\(h)#b", "\(h)#\(h)#", small, "a\n\(h)#"], #line),
            (#"[\uD800-\uDBFF]"#, ["#\(h)", "a#\(h)b", "#\(h)#\(h)", "#\(h)", "a\n#\(h)"], #line),
            (#"[\uDC00-\uDFFF]"#, ["\(h)#", "a\(h)#b", "\(h)#\(h)#", "\(h)#", "a\n\(h)#"], #line),
            (#"[\uD83D\uDE00]"#, ["##", "a##b", "####", small, "a\n##"], #line),
            (".(?=.)", ["#\(h)", "###b", "###\(h)", "#\(h)", "a\n#\(h)"], #line),
            ("(?<=.).", ["\(h)#", "a###", "\(h)###", "\(h)#", "a\n\(h)#"], #line),
            (".$", ["\(h)#", "a\(e)#", "\(e)\(h)#", "\(h)#", "a\n\(h)#"], #line),
            ("[\(small)]", [e, "a\(e)b", "\(e)\(e)", "##", "a\n\(e)"], #line),
        ]
        // On "a\n😀", where `m` or `s` reads the line break another way.
        let lines: [String: [String: String]] = [
            ".": ["gs": "####"],
            ".{2}": ["gs": "##"],
            "^.$": ["gm": "#\n\(e)"],
            "^..$": ["gm": "a\n#"],
            "(.)": ["gs": "####"],
            ".?": ["gs": "#####"],
            ".(?=.)": ["gs": "###\(h)"],
            "(?<=.).": ["gs": "a###"],
            ".$": ["gm": "#\n\(h)#"],
        ]
        for flags in ["g", "gi", "gm", "gs"] {
            for (pattern, values, line) in rows {
                for (input, value) in zip(Self.pairs, values) {
                    let expected = input == "a\n\u{1F600}" ? lines[pattern]?[flags] ?? value : value
                    assertRegex(pattern, flags, input, expected, line: line)
                }
            }
        }
    }

    func testU1_guard_withoutUAPairWrittenWholeStillMatchesWhole() {
        // 😀, `(?:😀)+`, the two escapes of a pair, 𐐨: as many units in the pattern as in the input; `\b`, `^`, `$`.
        let (e, small) = ("\u{1F600}", "\u{10428}")
        let rows: [(String, [String?], UInt)] = [
            (#"\b"#, [e, "#a#\(e)#b#", "\(e)\(e)", small, "#a#\n\(e)"], #line),
            ("$", ["\(e)#", "a\(e)b#", "\(e)\(e)#", "\(small)#", "a\n\(e)#"], #line),
            ("^", ["#\(e)", "#a\(e)b", "#\(e)\(e)", "#\(small)", "#a\n\(e)"], #line),
            (e, ["#", "a#b", "##", small, "a\n#"], #line),
            ("(?:\(e))+", ["#", "a#b", "#", small, "a\n#"], #line),
            (#"\uD83D\uDE00"#, ["#", "a#b", "##", small, "a\n#"], #line),
            (small, [e, "a\(e)b", "\(e)\(e)", "#", "a\n\(e)"], #line),
        ]
        // On "a\n😀", where `m` or `s` reads the line break another way.
        let lines: [String: [String: String]] = [
            "$": ["gm": "a#\n\(e)#"],
            "^": ["gm": "#a\n#\(e)"],
        ]
        for flags in ["g", "gi", "gm", "gs"] {
            for (pattern, values, line) in rows {
                for (input, value) in zip(Self.pairs, values) {
                    let expected = input == "a\n\u{1F600}" ? lines[pattern]?[flags] ?? value : value
                    assertRegex(pattern, flags, input, expected, line: line)
                }
            }
        }
    }

    func testU1_theMatchesOpReadsUnitsToo() {
        // `matches` takes no flags, so a pair is two units there too.
        let e = "\u{1F600}"
        func matches(_ regex: String) -> Bool {
            holds(["op": "matches", "str": Self.s(.string(e)), "regex": .string(regex)])
        }
        let rows: [(String, Bool, UInt)] = [
            ("^.$", false, #line),
            ("^..$", true, #line),
            (#"\uD83D"#, true, #line),
            (#"^\uDE00"#, false, #line),
            (#"[\uD800-\uDBFF]"#, true, #line),
            (e, true, #line),
            ("^\(e)$", true, #line),
            ("^[\(e)]$", false, #line),
            ("^[\(e)]{2}$", true, #line),
        ]
        for (regex, expected, line) in rows { XCTAssertEqual(matches(regex), expected, regex, line: line) }
    }

    func testU1_theResultAndEveryGroupAreReadFromTheInput() {
        // The engine searches a copy with a stand-in per half; the text between matches, match 0, `$n` and `{{value}}`
        // come from the input, so an empty match between the halves leaves the pair whole (`x*` with "": 😀).
        let (e, h) = ("\u{1F600}", "\u{FFFD}")
        let rows: [(String, String?, String, String?, String?, UInt)] = [
            ("x*", "g", e, "", e, #line),
            ("a??", "g", e, "", e, #line),
            ("", "g", "a\(e)", "", "a\(e)", #line),
            ("x*", "gu", e, "", e, #line),
            ("a??", "gu", e, "", e, #line),
            ("", "gu", "a\(e)", "", "a\(e)", #line),
            ("(.)", "g", e, "[$1]", "[\(h)][\(h)]", #line),
            ("(.)", "g", "a\(e)", "[$1]", "[a][\(h)][\(h)]", #line),
            (".", "g", e, "<{{value}}>", "<\(h)><\(h)>", #line),
            ("(.)(.)", "g", e, "$2$1", "\(h)\(h)", #line),
            (".{2}", "g", e, "[$&]", "[$&]", #line),
            (".", nil, e, nil, h, #line),
            (".", "g", e, nil, h, #line),
            (".{2}", nil, e, nil, e, #line),
            (#"\uDE00"#, nil, e, nil, h, #line),
            (#".\uDE00"#, nil, e, nil, e, #line),
            ("(?<=.).", nil, e, nil, h, #line),
            ("b.", nil, "b\(e)", nil, "b\(h)", #line),
        ]
        for (pattern, flags, input, replacement, expected, line) in rows {
            var step: [String: JSONValue] = ["type": "regex", "pattern": .string(pattern)]
            if let flags { step["flags"] = .string(flags) }
            if let replacement { step["replacement"] = .string(replacement) }
            assertSame(run(.string(input), .object(step)), expected.map(JSONValue.string) ?? .null, line: line)
        }
        // A pair cut by two groups and joined again in the replacement: Dart's is the pair, Swift's two U+FFFD, as
        // each `$n` is a string (the known difference, row 23b.38), pinned.
        let joined: JSONValue = ["type": "regex", "pattern": "(.)(.)", "flags": "g", "replacement": "$1$2"]
        assertSame(run(.string(e), joined), .string(h + h))  // Dart: the pair, 😀
    }

    func testU1_standInsAreNoPrivateUseCharacterOfTheInputOrThePattern() {
        // A stand-in is a private-use unit (U+E000-F8FF) neither holds; a class part that reaches into the block leaves
        // the stand-ins out, and a range over surrogates takes the stand-ins of the halves it covers.
        let e = "\u{1F600}"
        let rows: [(String, [String], String, String?, UInt)] = [
            (#"[\uE000-\uF8FF]"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "#\(e)#", #line),
            (#"\uE000"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "#\(e)\u{F8FF}", #line),
            (#"[\uE000]"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "#\(e)\u{F8FF}", #line),
            (".", ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "####", #line),
            (#"[^\uE000]"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "\u{E000}###", #line),
            (#"[\uE000-\uFFFF]"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "#\(e)#", #line),
            (#"[\u0000-\uFFFF]"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "####", #line),
            (#"[\uD800-\uDFFF]"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "\u{E000}##\u{F8FF}", #line),
            (#"[^\uD800-\uDFFF]"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "#\(e)#", #line),
            ("\u{E000}", ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "#\(e)\u{F8FF}", #line),
            ("[\u{E000}-\u{F8FF}]", ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "#\(e)#", #line),
            ("[^\u{E000}-\u{F8FF}]", ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "\u{E000}##\u{F8FF}", #line),
            (#"[\uE001]"#, ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "\u{E000}\(e)\u{F8FF}", #line),
            ("[\u{E001}-\u{F8FF}]", ["g", "gi"], "\u{E000}\(e)\u{F8FF}", "\u{E000}\(e)#", #line),
            (#"[\uE000-\uE002]"#, ["g"], "\u{E001}\(e)\u{E003}", "#\(e)\u{E003}", #line),
            (#"[\uD83D-\uDE00]"#, ["g"], "\u{E001}\(e)\u{E003}", "\u{E001}##\u{E003}", #line),
        ]
        for (pattern, flags, input, expected, line) in rows {
            for flags in flags { assertRegex(pattern, flags, input, expected, line: line) }
        }
        // A stand-in per half: with one unit left (the input holds 6 399 of the 6 400 private-use characters) the run
        // is not masked, so `.` takes 😀 whole, the known difference (row 23b.38), pinned; with two left it is Dart's.
        let block = (UInt32(0xE000)...0xF8FF).compactMap(Unicode.Scalar.init)
        let pins: [(Int, Int, UInt)] = [(0, 6401, #line), (1, 6400, #line), (2, 6400, #line)]  // Dart: 6402, 6401, 6400
        for (dropped, count, line) in pins {
            let input = String(String.UnicodeScalarView(block.dropFirst(dropped))) + e
            assertRegex(".", "g", input, String(repeating: "#", count: count), line: line)
        }
    }

    func testU1_aClassRangeIsReadOnDartsUnits() {
        // Without `u` a class holds a pair as two members, so `[😀-🙁]` is D83D, then DE00-D83D, out of order: refused.
        // A range over the surrogate block covers halves; without `u` `[\d-\uD83D]` is the union of both and `-`.
        let (e, h) = ("\u{1F600}", "\u{FFFD}")
        let rows: [(String, [String], String, String?, UInt)] = [
            (#"[\uDE00-\uD83D]"#, ["g"], "a\(e)b-", nil, #line),
            (#"[\uDE00-\uD83D]"#, ["g"], "\(e)\u{1F601}", nil, #line),
            ("[\\uE000-\(e)]", ["g"], "a\(e)b-", nil, #line),
            ("[\\uE000-\(e)]", ["g"], "\(e)\u{1F601}", nil, #line),
            ("[\\uD83D-\(e)]", ["g"], "a\(e)b-", "a##b-", #line),
            ("[\\uD83D-\(e)]", ["g"], "\(e)\u{1F601}", "###\(h)", #line),
            ("[\(e)-\\uDE01]", ["g"], "a\(e)b-", "a##b-", #line),
            ("[\(e)-\\uDE01]", ["g"], "\(e)\u{1F601}", "####", #line),
            ("[a-\(e)]", ["g"], "a\(e)b-", "####-", #line),
            ("[a-\(e)]", ["g"], "\(e)\u{1F601}", "###\(h)", #line),
            ("[\(e)-a]", ["g"], "a\(e)b-", nil, #line),
            ("[\(e)-a]", ["g"], "\(e)\u{1F601}", nil, #line),
            (#"[\u0000-\uFFFF]"#, ["g"], "a\(e)b-", "#####", #line),
            (#"[\u0000-\uFFFF]"#, ["g"], "\(e)\u{1F601}", "####", #line),
            (#"[\uD800-\uDFFF]"#, ["g"], "a\(e)b-", "a##b-", #line),
            (#"[\uD800-\uDFFF]"#, ["g"], "\(e)\u{1F601}", "####", #line),
            (#"[-\uD83D]"#, ["g"], "a\(e)b-", "a#\(h)b#", #line),
            (#"[-\uD83D]"#, ["g"], "\(e)\u{1F601}", "#\(h)#\(h)", #line),
            (#"[\uD83D-]"#, ["g"], "a\(e)b-", "a#\(h)b#", #line),
            (#"[\uD83D-]"#, ["g"], "\(e)\u{1F601}", "#\(h)#\(h)", #line),
            ("[\(e)-\u{1F601}]", ["g"], "a\(e)b-", nil, #line),
            ("[\(e)-\u{1F601}]", ["g"], "\(e)\u{1F601}", nil, #line),
            (#"[\uDBFF-\uDC00]"#, ["g"], "a\(e)b-", "a\(e)b-", #line),
            (#"[\uDBFF-\uDC00]"#, ["g"], "\(e)\u{1F601}", "\(e)\u{1F601}", #line),
            (#"[\uD7FF-\uE000]"#, ["g"], "a\(e)b-", "a##b-", #line),
            (#"[\uD7FF-\uE000]"#, ["g"], "\(e)\u{1F601}", "####", #line),
            (#"[^\uD7FF-\uE000]"#, ["g"], "a\(e)b-", "#\(e)##", #line),
            (#"[^\uD7FF-\uE000]"#, ["g"], "\(e)\u{1F601}", "\(e)\u{1F601}", #line),
            (#"[\d-\uD83D]"#, ["g"], "a\(e)b-", "a#\(h)b#", #line),
            (#"[\d-\uD83D]"#, ["g"], "\(e)\u{1F601}", "#\(h)#\(h)", #line),
            (#"[\uD83D-\d]"#, ["g"], "a\(e)b-", "a#\(h)b#", #line),
            (#"[\uD83D-\d]"#, ["g"], "\(e)\u{1F601}", "#\(h)#\(h)", #line),
            (#"[\s\uD83D]"#, ["g"], "a\(e)b-", "a#\(h)b-", #line),
            (#"[\s\uD83D]"#, ["g"], "\(e)\u{1F601}", "#\(h)#\(h)", #line),
            (#"[\S]"#, ["g"], "a\(e)b-", "#####", #line),
            (#"[\S]"#, ["g"], "\(e)\u{1F601}", "####", #line),
            (#"[^\S]"#, ["g"], "a\(e)b-", "a\(e)b-", #line),
            (#"[^\S]"#, ["g"], "\(e)\u{1F601}", "\(e)\u{1F601}", #line),
            (#"[\W]"#, ["g"], "a\(e)b-", "a##b#", #line),
            (#"[\W]"#, ["g"], "\(e)\u{1F601}", "####", #line),
            (#"[\uDE00-\uDFFF]"#, ["g"], "a\(e)b-", "a\(h)#b-", #line),
            (#"[\uDE00-\uDFFF]"#, ["g"], "\(e)\u{1F601}", "\(h)#\(h)#", #line),
        ]
        for (pattern, flags, input, expected, line) in rows {
            for flags in flags { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testU1_escapesGroupNamesAndLookaroundsReadUnitsToo() {
        // `\😀` is the escaped high half, then the low half; a quantifier takes the low half; a group name is read by
        // code point (`(?<𝒜>.)`); a backreference, a lookaround and `\b` see halves.
        let (e, h) = ("\u{1F600}", "\u{FFFD}")
        let rows: [(String, [String], String, String?, UInt)] = [
            ("\\\(e)", ["g", "gi"], "\(e)\(e)", "##", #line),
            ("\\\(e)", ["g", "gi"], "a\(e)s\u{1D49C}S", "a#s\u{1D49C}S", #line),
            ("\\\(e)", ["g", "gi"], "\(e)a\(e)a", "#a#a", #line),
            ("[\\\(e)]", ["g", "gi"], "\(e)\(e)", "####", #line),
            ("[\\\(e)]", ["g", "gi"], "a\(e)s\u{1D49C}S", "a##s\u{1D49C}S", #line),
            ("[\\\(e)]", ["g", "gi"], "\(e)a\(e)a", "##a##a", #line),
            ("(?<=\(e))a", ["g", "gi"], "\(e)\(e)", "\(e)\(e)", #line),
            ("(?<=\(e))a", ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            ("(?<=\(e))a", ["g", "gi"], "\(e)a\(e)a", "\(e)#\(e)#", #line),
            ("\(e){2}", ["g", "gi"], "\(e)\(e)", "\(e)\(e)", #line),
            ("\(e){2}", ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            ("\(e){2}", ["g", "gi"], "\(e)a\(e)a", "\(e)a\(e)a", #line),
            ("(?:\(e)){2}", ["g", "gi"], "\(e)\(e)", "#", #line),
            ("(?:\(e)){2}", ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            ("(?:\(e)){2}", ["g", "gi"], "\(e)a\(e)a", "\(e)a\(e)a", #line),
            ("\(e)?", ["g", "gi"], "\(e)\(e)", "##", #line),
            ("\(e)?", ["g", "gi"], "a\(e)s\u{1D49C}S", "a#s\u{1D49C}S", #line),
            ("\(e)?", ["g", "gi"], "\(e)a\(e)a", "#a#a", #line),
            ("[\(e)]{2}", ["g", "gi"], "\(e)\(e)", "##", #line),
            ("[\(e)]{2}", ["g", "gi"], "a\(e)s\u{1D49C}S", "a#s\u{1D49C}S", #line),
            ("[\(e)]{2}", ["g", "gi"], "\(e)a\(e)a", "#a#a", #line),
            ("(\(e))\\1", ["g", "gi"], "\(e)\(e)", "#", #line),
            ("(\(e))\\1", ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            ("(\(e))\\1", ["g", "gi"], "\(e)a\(e)a", "\(e)a\(e)a", #line),
            (#"(\uD83D)\1"#, ["g", "gi"], "\(e)\(e)", "\(e)\(e)", #line),
            (#"(\uD83D)\1"#, ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            (#"(\uD83D)\1"#, ["g", "gi"], "\(e)a\(e)a", "\(e)a\(e)a", #line),
            (#"\uD83D\uDE00"#, ["g", "gi"], "\(e)\(e)", "##", #line),
            (#"\uD83D\uDE00"#, ["g", "gi"], "a\(e)s\u{1D49C}S", "a#s\u{1D49C}S", #line),
            (#"\uD83D\uDE00"#, ["g", "gi"], "\(e)a\(e)a", "#a#a", #line),
            (#"\ud83d\ude00"#, ["g", "gi"], "\(e)\(e)", "##", #line),
            (#"\ud83d\ude00"#, ["g", "gi"], "a\(e)s\u{1D49C}S", "a#s\u{1D49C}S", #line),
            (#"\ud83d\ude00"#, ["g", "gi"], "\(e)a\(e)a", "#a#a", #line),
            ("(?<\u{1D49C}>.)", ["g", "gi"], "\(e)\(e)", "####", #line),
            ("(?<\u{1D49C}>.)", ["g", "gi"], "a\(e)s\u{1D49C}S", "#######", #line),
            ("(?<\u{1D49C}>.)", ["g", "gi"], "\(e)a\(e)a", "######", #line),
            ("(?<\u{1D49C}>.)\\k<\u{1D49C}>", ["g", "gi"], "\(e)\(e)", "\(e)\(e)", #line),
            ("(?<\u{1D49C}>.)\\k<\u{1D49C}>", ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            ("(?<\u{1D49C}>.)\\k<\u{1D49C}>", ["g", "gi"], "\(e)a\(e)a", "\(e)a\(e)a", #line),
            ("(?<a>\(e))\\k<a>", ["g", "gi"], "\(e)\(e)", "#", #line),
            ("(?<a>\(e))\\k<a>", ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            ("(?<a>\(e))\\k<a>", ["g", "gi"], "\(e)a\(e)a", "\(e)a\(e)a", #line),
            ("\\k<\(e)>", ["g", "gi"], "\(e)\(e)", "\(e)\(e)", #line),
            ("\\k<\(e)>", ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            ("\\k<\(e)>", ["g", "gi"], "\(e)a\(e)a", "\(e)a\(e)a", #line),
            ("[\\k\(e)]", ["g", "gi"], "\(e)\(e)", "####", #line),
            ("[\\k\(e)]", ["g", "gi"], "a\(e)s\u{1D49C}S", "a##s\u{1D49C}S", #line),
            ("[\\k\(e)]", ["g", "gi"], "\(e)a\(e)a", "##a##a", #line),
            ("(?i:\(e))", ["g", "gi"], "\(e)\(e)", "##", #line),
            ("(?i:\(e))", ["g", "gi"], "a\(e)s\u{1D49C}S", "a#s\u{1D49C}S", #line),
            ("(?i:\(e))", ["g", "gi"], "\(e)a\(e)a", "#a#a", #line),
            (#"(?-i:\uD83D)"#, ["g", "gi"], "\(e)\(e)", "#\(h)#\(h)", #line),
            (#"(?-i:\uD83D)"#, ["g", "gi"], "a\(e)s\u{1D49C}S", "a#\(h)s\u{1D49C}S", #line),
            (#"(?-i:\uD83D)"#, ["g", "gi"], "\(e)a\(e)a", "#\(h)a#\(h)a", #line),
            ("[s\(e)]", ["g", "gi"], "\(e)\(e)", "####", #line),
            ("[s\(e)]", ["g"], "a\(e)s\u{1D49C}S", "a###\u{1D49C}S", #line),
            ("[s\(e)]", ["g", "gi"], "\(e)a\(e)a", "##a##a", #line),
            ("[s\(e)]", ["gi"], "a\(e)s\u{1D49C}S", "a###\u{1D49C}#", #line),
            ("[\(e)s]", ["g", "gi"], "\(e)\(e)", "####", #line),
            ("[\(e)s]", ["g"], "a\(e)s\u{1D49C}S", "a###\u{1D49C}S", #line),
            ("[\(e)s]", ["g", "gi"], "\(e)a\(e)a", "##a##a", #line),
            ("[\(e)s]", ["gi"], "a\(e)s\u{1D49C}S", "a###\u{1D49C}#", #line),
            ("[^s\(e)]", ["g", "gi"], "\(e)\(e)", "\(e)\(e)", #line),
            ("[^s\(e)]", ["g"], "a\(e)s\u{1D49C}S", "#\(e)s###", #line),
            ("[^s\(e)]", ["g", "gi"], "\(e)a\(e)a", "\(e)#\(e)#", #line),
            ("[^s\(e)]", ["gi"], "a\(e)s\u{1D49C}S", "#\(e)s##S", #line),
            ("\\uD83D|\(e)", ["g", "gi"], "\(e)\(e)", "#\(h)#\(h)", #line),
            ("\\uD83D|\(e)", ["g", "gi"], "a\(e)s\u{1D49C}S", "a#\(h)s\u{1D49C}S", #line),
            ("\\uD83D|\(e)", ["g", "gi"], "\(e)a\(e)a", "#\(h)a#\(h)a", #line),
            (#"(?=\uD83D)"#, ["g", "gi"], "\(e)\(e)", "#\(e)#\(e)", #line),
            (#"(?=\uD83D)"#, ["g", "gi"], "a\(e)s\u{1D49C}S", "a#\(e)s\u{1D49C}S", #line),
            (#"(?=\uD83D)"#, ["g", "gi"], "\(e)a\(e)a", "#\(e)a#\(e)a", #line),
            (#"(?!\uDE00)."#, ["g", "gi"], "\(e)\(e)", "#\(h)#\(h)", #line),
            (#"(?!\uDE00)."#, ["g", "gi"], "a\(e)s\u{1D49C}S", "##\(h)####", #line),
            (#"(?!\uDE00)."#, ["g", "gi"], "\(e)a\(e)a", "#\(h)##\(h)#", #line),
            (#"\b\uD83D"#, ["g", "gi"], "\(e)\(e)", "\(e)\(e)", #line),
            (#"\b\uD83D"#, ["g", "gi"], "a\(e)s\u{1D49C}S", "a#\(h)s\u{1D49C}S", #line),
            (#"\b\uD83D"#, ["g", "gi"], "\(e)a\(e)a", "\(e)a#\(h)a", #line),
            (#"(?<!\uD83D)\uDE00"#, ["g", "gi"], "\(e)\(e)", "\(e)\(e)", #line),
            (#"(?<!\uD83D)\uDE00"#, ["g", "gi"], "a\(e)s\u{1D49C}S", "a\(e)s\u{1D49C}S", #line),
            (#"(?<!\uD83D)\uDE00"#, ["g", "gi"], "\(e)a\(e)a", "\(e)a\(e)a", #line),
        ]
        for (pattern, flags, input, expected, line) in rows {
            for flags in flags { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testU2_withoutULettersAboveFFFFNeverFold() {
        // Without `u` Dart folds code units, so under `i` a letter above U+FFFF matches only itself, and `[𐐀]` takes
        // the high half 𐐀 and 𐐨 share; with `u` each folds to its partner. Every pair of a fold class above U+FFFF,
        // the pattern's letter a, the input's b (all 282 classes share a high half).
        let (big, small, h) = ("\u{10400}", "\u{10428}", "\u{FFFD}")
        let letters = Regex.foldClassLetters.filter { $0.value > 0xFFFF }
        XCTAssertEqual(letters.count, 564)
        var differ: [String] = []
        for a in letters {
            for b in Regex.foldClasses[a] ?? [] where b != a {
                let (x, y) = (String(a), String(b))
                let rows: [(String, String, String, String)] = [
                    (x, "gi", y, y), ("[\(x)]", "gi", y, "#\(h)"), ("(\(x))\\1", "gi", x + y, x + y),
                    ("(.)\\1", "gi", x + y, x + y), (x, "giu", y, "#"), ("[\(x)]", "giu", y, "#"),
                    ("(\(x))\\1", "giu", x + y, "#"), ("(.)\\1", "giu", x + y, "#"),
                ]
                for (pattern, flags, input, expected) in rows {
                    let step: JSONValue = [
                        "type": "regex", "pattern": .string(pattern), "flags": .string(flags), "replacement": "#",
                    ]
                    let got = run(.string(input), step)
                    if got != .string(expected) || units(got) != [Array(expected.utf16)] {
                        differ.append("\(pattern.debugDescription) /\(flags) on \(input.debugDescription): \(got)")
                    }
                }
            }
        }
        XCTAssert(differ.isEmpty, "\(differ.count) differ: " + differ.prefix(8).joined(separator: "; "))
        // Deseret 𐐀 (U+10400) and 𐐨 under each flag set; `[𐐀-𐐧]` is D801, then DC00-D801, out of order.
        let rows: [(String, [String], String, String?, UInt)] = [
            (big, ["gi", "g", "gu", "gim", "gis"], small, small, #line),
            (big, ["giu"], small, "#", #line),
            ("[\(big)]", ["gi", "g", "gim", "gis"], small, "#\(h)", #line),
            ("[\(big)]", ["giu"], small, "#", #line),
            ("[\(big)]", ["gu"], small, small, #line),
            ("(\(big))\\1", ["gi", "g", "gu", "gim", "gis"], "\(big)\(small)", "\(big)\(small)", #line),
            ("(\(big))\\1", ["giu"], "\(big)\(small)", "#", #line),
            (#"(.)\1"#, ["gi", "g", "gu", "gim", "gis"], "\(big)\(small)", "\(big)\(small)", #line),
            (#"(.)\1"#, ["giu"], "\(big)\(small)", "#", #line),
            ("[\(big)-\u{10427}]", ["gi", "g", "gim", "gis"], small, nil, #line),
            ("[\(big)-\u{10427}]", ["giu"], small, "#", #line),
            ("[\(big)-\u{10427}]", ["gu"], small, small, #line),
            ("[^\(big)]", ["gi", "g", "gim", "gis"], small, "\(h)#", #line),
            ("[^\(big)]", ["giu"], small, small, #line),
            ("[^\(big)]", ["gu"], small, "#", #line),
        ]
        for (pattern, flags, input, expected, line) in rows {
            for flags in flags { assertRegex(pattern, flags, input, expected, line: line) }
        }
    }

    func testK1_guard_withUAPairIsOneCharacter() {
        // With `u` nothing is masked: ICU and Dart read code points, and an empty match never falls inside a pair
        // (`a??`, ``, `(?:)`, `x*` on 😀 are "#😀#"). One value per input of `pairs`, the same under gu and giu.
        let (e, small) = ("\u{1F600}", "\u{10428}")
        let rows: [(String, [String?], UInt)] = [
            (".", ["#", "###", "##", "#", "#\n#"], #line),
            ("[^a]", ["#", "a##", "##", "#", "a##"], #line),
            (#"\S"#, ["#", "###", "##", "#", "#\n#"], #line),
            (#"\W"#, ["#", "a#b", "##", "#", "a##"], #line),
            (#"\D"#, ["#", "###", "##", "#", "###"], #line),
            ("[^]", ["#", "###", "##", "#", "###"], #line),
            (".{2}", [e, "#b", "#", small, "a\n\(e)"], #line),
            ("^.$", ["#", "a\(e)b", "\(e)\(e)", "#", "a\n\(e)"], #line),
            ("^..$", [e, "a\(e)b", "#", small, "a\n\(e)"], #line),
            ("(.)", ["#", "###", "##", "#", "#\n#"], #line),
            (".?", ["##", "####", "###", "##", "##\n##"], #line),
            ("a??", ["#\(e)#", "#a#\(e)#b#", "#\(e)#\(e)#", "#\(small)#", "#a#\n#\(e)#"], #line),
            ("", ["#\(e)#", "#a#\(e)#b#", "#\(e)#\(e)#", "#\(small)#", "#a#\n#\(e)#"], #line),
            ("(?:)", ["#\(e)#", "#a#\(e)#b#", "#\(e)#\(e)#", "#\(small)#", "#a#\n#\(e)#"], #line),
            ("x*", ["#\(e)#", "#a#\(e)#b#", "#\(e)#\(e)#", "#\(small)#", "#a#\n#\(e)#"], #line),
            (#"\b"#, [e, "#a#\(e)#b#", "\(e)\(e)", small, "#a#\n\(e)"], #line),
            // On "a😀b" Dart's search, which tries every unit with `u` too, finds the empty match inside the
            // pair ("a", D83D, "#", DE00, "b"); ICU never starts inside a pair: the known difference
            // (row 23b.38), pinned.
            (#"\B"#, ["#\(e)#", "a\(e)b", "#\(e)#\(e)#", "#\(small)#", "a\n#\(e)#"], #line),
            ("$", ["\(e)#", "a\(e)b#", "\(e)\(e)#", "\(small)#", "a\n\(e)#"], #line),
            ("^", ["#\(e)", "#a\(e)b", "#\(e)\(e)", "#\(small)", "#a\n\(e)"], #line),
            ("[\(e)]", ["#", "a#b", "##", small, "a\n#"], #line),
            ("[^\(e)]", [e, "#\(e)#", "\(e)\(e)", "#", "##\(e)"], #line),
            (e, ["#", "a#b", "##", small, "a\n#"], #line),
            ("\(e)+", ["#", "a#b", "#", small, "a\n#"], #line),
            ("(?:\(e))+", ["#", "a#b", "#", small, "a\n#"], #line),
            (#"[\uD83D]"#, [e, "a\(e)b", "\(e)\(e)", small, "a\n\(e)"], #line),
            (#"\uD83D"#, [e, "a\(e)b", "\(e)\(e)", small, "a\n\(e)"], #line),
            (#"\uDE00"#, [e, "a\(e)b", "\(e)\(e)", small, "a\n\(e)"], #line),
            (#"[\uD800-\uDBFF]"#, [e, "a\(e)b", "\(e)\(e)", small, "a\n\(e)"], #line),
            (#"[\uDC00-\uDFFF]"#, [e, "a\(e)b", "\(e)\(e)", small, "a\n\(e)"], #line),
            (#"\uD83D\uDE00"#, ["#", "a#b", "##", small, "a\n#"], #line),
            (#"[\uD83D\uDE00]"#, ["#", "a#b", "##", small, "a\n#"], #line),
            (".(?=.)", [e, "##b", "#\(e)", small, "a\n\(e)"], #line),
            ("(?<=.).", [e, "a##", "\(e)#", small, "a\n\(e)"], #line),
            (".$", ["#", "a\(e)#", "\(e)#", "#", "a\n#"], #line),
            ("[\(small)]", [e, "a\(e)b", "\(e)\(e)", "#", "a\n\(e)"], #line),
            (small, [e, "a\(e)b", "\(e)\(e)", "#", "a\n\(e)"], #line),
        ]
        for flags in ["gu", "giu"] {
            for (pattern, values, line) in rows {
                for (input, value) in zip(Self.pairs, values) {
                    assertRegex(pattern, flags, input, value, line: line)
                }
            }
        }
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
