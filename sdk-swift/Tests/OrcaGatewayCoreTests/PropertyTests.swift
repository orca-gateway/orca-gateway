import XCTest

@testable import OrcaGatewayCore

/// Properties over seeded random inputs (learning/property-based-testing.md).
/// Seeds are fixed so CI is deterministic; bump `iterations` locally to hunt.
final class PropertyTests: XCTestCase {
    private let seeds: [UInt64] = [1, 23, 2026, 0xC0FFEE]
    private let iterations = 150

    private func forAll(_ body: (inout Gen, String) throws -> Void) rethrows {
        for seed in seeds {
            var gen = Gen(seed: seed)
            for i in 0..<iterations {
                try body(&gen, "seed \(seed) #\(i)")
            }
        }
    }

    // T1.1 property: decode(encode(n)) == n

    func testComponentNodeRoundTrip() throws {
        try forAll { gen, label in
            let node = gen.node()
            let back = try decodeModel(ComponentNode.self, from: try jsonOf(node))
            XCTAssertEqual(back, node, label)
        }
    }

    func testPageResponseRoundTrip() throws {
        try forAll { gen, label in
            let page = PageResponse(
                pageId: gen.key(), title: gen.string(),
                state: (0..<gen.int(0...3)).map { _ in
                    StateDefinition(key: gen.key(), scope: gen.pick(StateScope.allCases), initial: gen.json(depth: 2))
                },
                components: (0..<gen.int(0...3)).map { _ in gen.node() },
                extra: gen.bool() ? ["_debug": gen.json(depth: 2)] : [:])
            XCTAssertEqual(try decodeModel(PageResponse.self, from: try jsonOf(page)), page, label)
        }
    }

    func testValueRoundTrip() throws {
        try forAll { gen, label in
            let value = gen.value(depth: 3)
            XCTAssertEqual(try decodeModel(Value.self, from: value.json), value, label)
        }
    }

    func testActionRoundTrip() throws {
        try forAll { gen, label in
            let action = gen.action(depth: 3)
            XCTAssertEqual(try decodeModel(Action.self, from: action.json), action, label)
        }
    }

    func testJSONValueRoundTripThroughData() throws {
        try forAll { gen, label in
            let json = gen.json(depth: 4)
            XCTAssertEqual(try JSONValue.decode(try json.encoded()), json, label)
        }
    }

    // T1.3 properties

    func testAddThenSubtractIsIdentityOnInts() {
        forAll { gen, label in
            let x = gen.int(-1_000_000...1_000_000)
            let k = gen.int(-1_000_000...1_000_000)
            let r = ValueResolver(state: ["x": .int(x)])
            let out = r.resolve([
                "type": "transform", "input": ["type": "state", "key": "x"],
                "by": [["type": "add", "by": ["type": "static", "value": .int(k)]],
                       ["type": "subtract", "by": ["type": "static", "value": .int(k)]]],
            ])
            XCTAssertEqual(out, .int(x), label)
            XCTAssertNotNil(out.intValue, "int stays int: \(label)")
        }
    }

    func testSplitThenJoinRoundTrips() {
        forAll { gen, label in
            let s = gen.string(maxLength: 12)
            let sep = gen.pick([",", " ", "", "ab"])
            let r = ValueResolver(state: [:])
            let out = r.resolve([
                "type": "transform", "input": ["type": "static", "value": .string(s)],
                "by": [["type": "split", "separator": .string(sep)], ["type": "join", "separator": .string(sep)]],
            ])
            XCTAssertEqual(out, .string(s), label)
        }
    }

    func testTrimIsIdempotent() {
        forAll { gen, label in
            let s = String(repeating: " ", count: gen.int(0...2)) + gen.string() + "\n"
            let r = ValueResolver(state: [:])
            let once = r.resolve(["type": "transform", "input": ["type": "static", "value": .string(s)], "by": [["type": "trim"]]])
            let twice = r.resolve(["type": "transform", "input": ["type": "static", "value": once], "by": [["type": "trim"]]])
            XCTAssertEqual(once, twice, label)
        }
    }

    func testResolverNeverTrapsOnRandomValues() {
        // Where Dart throws, Swift yields null; nothing may crash the app.
        forAll { gen, _ in
            let state = ["a": gen.json(depth: 2), "b": gen.json(depth: 1)]
            let r = ValueResolver(state: state, animationProgress: Double(gen.int(0...10)) / 10)
            _ = r.resolveDeep(.object(gen.props()))
            _ = r.evaluate(gen.boolExpr(depth: 2))
        }
    }

    func testDoubleFormattingRoundTrips() {
        forAll { gen, label in
            let d = gen.double()
            let text = DartFormat.double(d)
            XCTAssertEqual(Double(text), d, "\(label): \(text)")
        }
    }
}
