import XCTest

@testable import OrcaGatewayCore

/// T1.4: the 13 BoolExpr ops, with the cases of the Dart groups "11.9:
/// BoolExpr evaluation" and "11.7: ConditionalValue resolution" in
/// sdk/test/orca_gateway_test.dart, plus the null semantics Dart's code has.
final class BoolExprTests: XCTestCase {
    private func s(_ v: JSONValue) -> JSONValue { ["type": "static", "value": v] }
    private func st(_ key: String) -> JSONValue { ["type": "state", "key": .string(key), "scope": "page"] }
    private func cmp(_ op: String, _ l: JSONValue, _ r: JSONValue) -> JSONValue {
        ["op": .string(op), "left": l, "right": r]
    }

    private func eval(_ expr: JSONValue, _ state: [String: JSONValue] = [:]) -> Bool {
        ValueResolver(state: state).evaluate(expr.objectValue ?? [:])
    }

    // MARK: lifted from the Dart group 11.9

    func testDartCases() {
        XCTAssertTrue(eval(cmp("eq", s(5), s(5))))
        XCTAssertFalse(eval(cmp("eq", s(5), s(3))))
        XCTAssertTrue(eval(cmp("neq", s(5), s(3))))
        XCTAssertFalse(eval(cmp("neq", s(5), s(5))))
        XCTAssertTrue(eval(cmp("gt", s(10), s(5))))
        XCTAssertFalse(eval(cmp("gt", s(5), s(5))))
        XCTAssertTrue(eval(cmp("gte", s(5), s(5))))
        XCTAssertTrue(eval(cmp("lt", s(3), s(5))))
        XCTAssertTrue(eval(cmp("lte", s(5), s(5))))
        XCTAssertTrue(eval(["op": "and", "exprs": [cmp("eq", s(1), s(1)), cmp("gt", s(5), s(3))]]))
        XCTAssertFalse(eval(["op": "and", "exprs": [cmp("eq", s(1), s(1)), cmp("gt", s(3), s(5))]]))
        XCTAssertTrue(eval(["op": "or", "exprs": [cmp("eq", s(1), s(2)), cmp("gt", s(5), s(3))]]))
        XCTAssertTrue(eval(["op": "not", "expr": cmp("eq", s(1), s(2))]))
        XCTAssertTrue(eval(["op": "isNull", "value": s(nil)]))
        XCTAssertFalse(eval(["op": "isNull", "value": s(42)]))
        XCTAssertTrue(eval(["op": "isNull", "value": st("missing")]))
        XCTAssertTrue(eval(["op": "contains", "haystack": s("hello world"), "needle": s("world")]))
        XCTAssertTrue(eval(["op": "contains", "haystack": s([1, 2, 3]), "needle": s(2)]))
        XCTAssertTrue(eval(["op": "startsWith", "str": s("hello"), "prefix": s("hel")]))
        XCTAssertTrue(eval(["op": "matches", "str": s("abc123"), "regex": "\\d+"]))
        XCTAssertFalse(eval(["op": "matches", "str": s("abc"), "regex": "\\d+"]))
        XCTAssertTrue(eval(cmp("gt", st("count"), s(3)), ["count": 5]))
    }

    // MARK: null and type semantics of the Dart code

    func testComparisonsWithNonNumbersCompareAsEqual() {
        // `_compareNum` returns 0 unless both sides are numbers.
        XCTAssertFalse(eval(cmp("gt", st("missing"), s(1))))
        XCTAssertFalse(eval(cmp("lt", st("missing"), s(1))))
        XCTAssertTrue(eval(cmp("gte", st("missing"), s(1))))
        XCTAssertTrue(eval(cmp("lte", s("b"), s("a"))))
        XCTAssertTrue(eval(cmp("gte", s(1), s(1.0))))
        XCTAssertTrue(eval(cmp("lt", s(1), s(1.5))))
    }

    func testEqualityFollowsDartNumbersAndNull() {
        XCTAssertTrue(eval(cmp("eq", s(1), s(1.0))))
        XCTAssertTrue(eval(cmp("eq", st("missing"), s(nil))))
        XCTAssertFalse(eval(cmp("eq", s(1), s("1"))))
        XCTAssertFalse(eval(cmp("eq", s(true), s(1))))
        XCTAssertTrue(eval(cmp("neq", st("missing"), s(0))))
        // Operands may be literals, not only Values.
        XCTAssertTrue(eval(cmp("eq", 2, s(2))))
    }

    func testLogicalEdges() {
        XCTAssertTrue(eval(["op": "and", "exprs": []]))
        XCTAssertFalse(eval(["op": "or", "exprs": []]))
        XCTAssertTrue(eval(["op": "and"]))  // missing exprs reads as []
        XCTAssertFalse(eval(["op": "and", "exprs": [cmp("eq", s(1), s(1)), "junk"]]))
        XCTAssertTrue(eval(["op": "not"]))  // no inner expression
        XCTAssertFalse(eval(["op": "xor"]))
        XCTAssertFalse(eval(["left": s(1)]))
    }

    func testStringOpsStringifyLikeDart() {
        XCTAssertTrue(eval(["op": "startsWith", "str": st("missing"), "prefix": s("nu")]))  // "null"
        XCTAssertTrue(eval(["op": "startsWith", "str": s(123), "prefix": s(12)]))
        XCTAssertTrue(eval(["op": "contains", "haystack": s("a null b"), "needle": st("missing")]))
        XCTAssertFalse(eval(["op": "contains", "haystack": s(42), "needle": s(4)]))
        XCTAssertFalse(eval(["op": "contains", "haystack": st("missing"), "needle": s("x")]))
        XCTAssertFalse(eval(["op": "matches", "str": s("x"), "regex": "("]))  // invalid
        XCTAssertFalse(eval(["op": "matches", "str": s("a"), "regex": .string(String(repeating: "a", count: 201))]))
        XCTAssertTrue(eval(["op": "matches", "str": s(42), "regex": "^4"]))
    }

    func testTypedExpressionsEvaluateTheSame() {
        let r = ValueResolver(state: ["count": 5])
        XCTAssertTrue(r.evaluate(.gt(left: ["type": "state", "key": "count", "scope": "page"], right: 3)))
        XCTAssertTrue(r.evaluate(.and([.isNull(nil), .not(.eq(left: 1, right: 2))])))
        XCTAssertFalse(r.evaluate(.unknown(["op": "xor"])))
    }

    func testEveryAdvertisedOpIsHandled() {
        XCTAssertEqual(Set(GeneratedCapabilities.boolExprOps), Set(BoolExpr.ops))
        XCTAssertEqual(BoolExpr.ops.count, 13)
    }

    // MARK: lifted from the Dart group 11.7

    func testConditionalValues() {
        let stock: JSONValue = [
            "type": "conditional",
            "branches": [["when": cmp("gt", st("stock"), s(0)), "then": s("In Stock")]],
            "else": s("Out of Stock"),
        ]
        XCTAssertEqual(ValueResolver(state: ["stock": 5]).resolve(stock), "In Stock")
        XCTAssertEqual(ValueResolver(state: ["stock": 0]).resolve(stock), "Out of Stock")

        let never: JSONValue = [
            "type": "conditional", "branches": [["when": cmp("eq", s(1), s(2)), "then": s("never")]],
        ]
        XCTAssertEqual(ValueResolver(state: [:]).resolve(never), .null)

        let temp: JSONValue = [
            "type": "conditional",
            "branches": [
                ["when": cmp("lt", st("temp"), s(0)), "then": s("Freezing")],
                ["when": cmp("lt", st("temp"), s(20)), "then": s("Cold")],
            ],
            "else": s("Warm"),
        ]
        XCTAssertEqual(ValueResolver(state: ["temp": -5]).resolve(temp), "Freezing")
        XCTAssertEqual(ValueResolver(state: ["temp": 10]).resolve(temp), "Cold")
        XCTAssertEqual(ValueResolver(state: ["temp": 25]).resolve(temp), "Warm")

        let inner: JSONValue = [
            "type": "conditional",
            "branches": [["when": cmp("eq", st("tier"), s("premium")), "then": s("Free Shipping")]],
            "else": s("$9.99 Shipping"),
        ]
        let outer: JSONValue = [
            "type": "conditional",
            "branches": [["when": cmp("gt", st("total"), s(100)), "then": s("Free Shipping")]],
            "else": inner,
        ]
        XCTAssertEqual(ValueResolver(state: ["total": 150, "tier": "basic"]).resolve(outer), "Free Shipping")
        XCTAssertEqual(ValueResolver(state: ["total": 50, "tier": "premium"]).resolve(outer), "Free Shipping")
        XCTAssertEqual(ValueResolver(state: ["total": 50, "tier": "basic"]).resolve(outer), "$9.99 Shipping")
    }

    // MARK: other Value kinds and the resolver's pass-through rules

    func testValueKinds() {
        let r = ValueResolver(
            state: ["count": 10, "theme": ["color": "red"], "items": [["name": "a"]], "a.b": "flat"],
            eventData: ["value": "typed"])
        XCTAssertEqual(r.resolve(s(42)), 42)
        XCTAssertEqual(r.resolve(["type": "static"]), .null)
        XCTAssertEqual(r.resolve(st("count")), 10)
        XCTAssertEqual(r.resolve(st("theme.color")), "red")
        XCTAssertEqual(r.resolve(st("items.0.name")), "a")
        XCTAssertEqual(r.resolve(st("items.3.name")), .null)
        XCTAssertEqual(r.resolve(st("a.b")), "flat")  // flat key wins
        XCTAssertEqual(r.resolve(["type": "state"]), .null)
        XCTAssertEqual(r.resolve(["type": "event", "key": "value"]), "typed")
        XCTAssertEqual(ValueResolver(state: [:]).resolve(["type": "event", "key": "value"]), .null)
        // info and request are resolved by the engine; the client leaves them.
        let info: JSONValue = ["type": "info", "key": "user.name"]
        XCTAssertEqual(r.resolve(info), info)
        XCTAssertEqual(r.resolve(["type": "request", "key": "q"]), ["type": "request", "key": "q"])
        // Literals and plain maps pass through `resolve`.
        XCTAssertEqual(r.resolve("hello"), "hello")
        XCTAssertEqual(r.resolve(nil), .null)
        XCTAssertEqual(r.resolve(["padding": 8]), ["padding": 8])
        XCTAssertEqual(r.resolveToString(st("missing")), "")
        XCTAssertEqual(r.resolveToString(st("count")), "10")
        // resolveDeep descends into plain maps and lists.
        XCTAssertEqual(
            r.resolveDeep(["style": ["color": st("theme.color"), "sizes": [s(1), 2]]]),
            ["style": ["color": "red", "sizes": [1, 2]]])
    }

    func testTweens() {
        let tween: JSONValue = ["type": "tween", "begin": 0, "end": 10]
        XCTAssertEqual(ValueResolver(state: [:]).resolve(tween), .double(0))
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0.25).resolve(tween), 2.5)
        let color: JSONValue = ["type": "tween", "begin": "#000000", "end": "#FFFFFF"]
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0.5).resolve(color), "#FF808080")
        let alpha: JSONValue = ["type": "tween", "begin": "#00000000", "end": "#FF000000"]
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 1).resolve(alpha), "#FF000000")
        let snap: JSONValue = ["type": "tween", "begin": "left", "end": "right"]
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0.49).resolve(snap), "left")
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0.5).resolve(snap), "right")
        let targeted: JSONValue = ["type": "tween", "begin": 0, "end": 100, "animationId": "fade"]
        let r = ValueResolver(state: [:], animationProgress: 0.9, animationProgressFor: { $0 == "fade" ? 0.1 : nil })
        XCTAssertEqual(r.resolve(targeted), 10)

        let seq: JSONValue = [
            "type": "tweenSequence",
            "items": [["value": 0, "duration": 100], ["value": 10, "duration": 100], ["value": 0, "duration": 200]],
        ]
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0.25).resolve(seq), 0)
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0.375).resolve(seq), 5)
        XCTAssertEqual(ValueResolver(state: [:], animationProgress: 0.75).resolve(seq), 5)
        XCTAssertEqual(ValueResolver(state: [:]).resolve(["type": "tweenSequence", "items": []]), .null)
        XCTAssertEqual(
            ValueResolver(state: [:]).resolve(["type": "tweenSequence", "items": [["value": 7, "duration": 0]]]), 7)
    }
}
