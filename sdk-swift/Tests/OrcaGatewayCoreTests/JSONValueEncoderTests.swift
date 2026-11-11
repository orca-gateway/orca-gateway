import Foundation
import XCTest

@testable import OrcaGatewayCore

/// S13 (23b.35): `JSONValue(encoding:)` builds the tree straight from the
/// model, so a typed 4.0 stays `.double` in `Value.json`, `Action.json`, the
/// DevTools action payload and its text, as the Flutter SDK's double does.
/// Numbers are checked by kind, never by `==` alone, which equates 4 and 4.0.
final class JSONValueEncoderTests: XCTestCase {
    /// What `init(encoding:)` gave before S13: JSONEncoder's text read back.
    func oldPath<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONValue.decode(JSONEncoder().encode(value))
    }

    /// `new` is `old` with some ints that were integral doubles kept doubles:
    /// the count of those, nil when anything else differs.
    func widenings(_ old: JSONValue, _ new: JSONValue) -> Int? {
        switch (old, new) {
        case (.int(let x), .int(let y)): return x == y ? 0 : nil
        case (.double(let x), .double(let y)): return x == y ? 0 : nil
        case (.int(let x), .double(let y)): return Double(x) == y ? 1 : nil
        case (.array(let x), .array(let y)):
            guard x.count == y.count else { return nil }
            var n = 0
            for (a, b) in zip(x, y) {
                guard let k = widenings(a, b) else { return nil }
                n += k
            }
            return n
        case (.object(let x), .object(let y)):
            guard Set(x.keys) == Set(y.keys) else { return nil }
            var n = 0
            for (key, a) in x {
                guard let b = y[key], let k = widenings(a, b) else { return nil }
                n += k
            }
            return n
        case (.int, _), (.double, _), (.array, _), (.object, _): return nil
        default: return old == new ? 0 : nil
        }
    }

    // MARK: W2 the models

    func testW2_AValueKeepsATyped4_0AndIntsStayInts() throws {
        assertDouble(Value.static(4.0).json["value"], 4.0)
        assertInt(Value.static(4).json["value"], 4)
        let tween = Value.tween(begin: 4.0, end: [4.0, 4, ["k": -0.0]], animationId: nil).json
        assertDouble(tween["begin"], 4.0)
        XCTAssertTrue(sameKinds(tween["end"], [4.0, 4, ["k": -0.0]]), "\(tween)")
        XCTAssertNil(tween.objectValue?["animationId"], "an absent optional is left out")
        // A field typed Double is a double, 300 included, as Dart's double field (F5).
        let sequence = Value.tweenSequence(items: [.init(value: 4, duration: 300)], animationId: "a").json
        assertDouble(sequence["items"][0]["duration"], 300.0)
        assertInt(sequence["items"][0]["value"], 4)
        let nested = Value.transform(input: .static(100.0), by: [.multiply(by: 4.0), .substring(start: 4, length: 2)]).json
        assertDouble(nested["input"]["value"], 100.0)
        assertDouble(nested["by"][0]["by"], 4.0)
        assertInt(nested["by"][1]["start"], 4)
        assertInt(nested["by"][1]["length"], 2)
    }

    func testW2_ABoolExprAndATransformKeep4_0() throws {
        let expr = BoolExpr.and([.eq(left: 4.0, right: 4), .startsWith(str: ["type": "static", "value": 4.0], prefix: "4.0")]).json
        assertDouble(expr["exprs"][0]["left"], 4.0)
        assertInt(expr["exprs"][0]["right"], 4)
        assertDouble(expr["exprs"][1]["str"]["value"], 4.0)
        assertDouble(Transform.add(by: 4.0).json["by"], 4.0)
        assertDouble(Transform.contains(value: [4.0]).json["value"][0], 4.0)
        assertInt(Transform.toFixed(decimals: 2).json["decimals"], 2)
        // `evaluate(_: BoolExpr)` reads `expr.json`: Dart's "4.0".startsWith("4.0").
        XCTAssertTrue(ValueResolver(state: [:]).evaluate(BoolExpr.startsWith(str: 4.0, prefix: "4.0")))
    }

    /// `Action.encode` writes the payload, then asks for a keyed container
    /// again to add `type`: both halves land in one object (F4).
    func testW2_AnActionKeeps4_0AndItsTypeInOneObject() throws {
        let set = Action.setState(.init(key: "d", value: 4.0)).json
        XCTAssertEqual(set.objectValue.map { Set($0.keys) }, ["key", "type", "value"])
        XCTAssertEqual(set["type"], "setState")
        assertDouble(set["value"], 4.0)
        XCTAssertEqual(Action.goBack.json, ["type": "goBack"])
        let dialog = Action.openDialog(.init(dialogId: "sheet", heightFactor: 1.0)).json
        assertDouble(dialog["heightFactor"], 1.0)
        XCTAssertEqual(dialog["type"], "openDialog")
        let toast = Action.showToast(.init(message: "hi", duration: 3000)).json
        assertInt(toast["duration"], 3000)
        let group = Action.actionGroup(.init(actions: [
            .once(.init(action: .setState(.init(key: "n", scope: .app, value: [4.0])))),
            .custom(["type": "custom:beep", "level": 4.0]),
            .unknown(["type": "sparkle", "at": 4]),
        ])).json
        XCTAssertEqual(group["type"], "actionGroup")
        XCTAssertEqual(group["actions"][0]["type"], "once")
        assertDouble(group["actions"][0]["action"]["value"][0], 4.0)
        XCTAssertEqual(group["actions"][0]["action"]["scope"], "app")
        XCTAssertTrue(sameKinds(group["actions"][1], ["type": "custom:beep", "level": 4.0]), "\(group)")
        XCTAssertTrue(sameKinds(group["actions"][2], ["type": "sparkle", "at": 4]), "\(group)")
    }

    func testW2_TheCapsVectorShapeIsUnchanged() throws {
        let tree = try JSONValue(encoding: CapabilityVector.current)
        assertJSONEqual(tree, try oldPath(CapabilityVector.current))
        XCTAssertEqual(
            tree.objectValue.map { Set($0.keys) },
            ["protocolVersion", "sdkSemver", "widgets", "valueKinds", "actionKinds", "transformKinds", "boolExprOps"])
        XCTAssertEqual(try tree.decode(CapabilityVector.self), CapabilityVector.current)
    }

    func testW2_TheDevToolsActionPayloadKeeps4_0() throws {
        let event = DevToolsEvent.action(.setState(.init(key: "d", value: 4.0)), pageId: "home", durationMs: 0.75)
        assertDouble(event.payload["data"]?["value"], 4.0)
        XCTAssertEqual(event.payload["data"]?["type"], "setState")
    }

    func testW2_ResolvingATypedValueWithToStringGives4_0() throws {
        let resolver = ValueResolver(state: [:])
        XCTAssertEqual(resolver.resolve(Value.transform(input: .static(4.0), by: [.toString])), "4.0")
        XCTAssertEqual(resolver.resolve(Value.transform(input: .static(4), by: [.toString])), "4")
        XCTAssertEqual(resolver.resolve(Value.static([4.0])), [4.0])
        assertDouble(resolver.resolve(Value.static([4.0]))[0], 4.0)
    }

    /// JSONEncoder threw on these, so `.json` is `.null` and so is DevTools' `data` (F6).
    func testW2_NaNAndInfinityStillThrowAndGiveNull() throws {
        XCTAssertEqual(Value.static(.double(.nan)).json, .null)
        XCTAssertEqual(Value.static([["k": .double(.infinity)]]).json, .null)
        XCTAssertEqual(Action.openDialog(.init(dialogId: "x", heightFactor: -.infinity)).json, .null)
        XCTAssertEqual(Value.tweenSequence(items: [.init(value: 1, duration: .nan)], animationId: nil).json, .null)
        let event = DevToolsEvent.action(.setState(.init(key: "d", value: .double(.nan))), pageId: "home", durationMs: 1)
        XCTAssertEqual(event.payload["data"], .null)
        XCTAssertThrowsError(try JSONValue(encoding: Value.static(.double(.nan)))) { error in
            guard case EncodingError.invalidValue = error else { return XCTFail("\(error)") }
        }
    }

    /// Every container kind, a second `container(keyedBy:)` on one encoder,
    /// super encoders and coding paths, as JSONEncoder writes them.
    func testW2_TheEncoderNestsMergesAndNamesPathsAsJSONEncoder() throws {
        let mine = Probe(), theirs = Probe()
        let tree = try JSONValue(encoding: mine)
        let old = try oldPath(theirs)
        assertJSONEqual(tree, old)
        // A nested container's super encoder: JSONEncoder names it from the
        // owning encoder's path (`Index 5`); this one keeps the whole path,
        // as JSONValueDecoder's `superDecoder()` does. Every other path is JSONEncoder's.
        var expected = theirs.log.paths
        guard expected.count == 6 else { return XCTFail("\(expected)") }
        expected[2] = ["list", "Index 5"]
        XCTAssertEqual(mine.log.paths, expected)
        assertDouble(tree["d"], 4.0)
        assertInt(tree["i"], 4)
        XCTAssertEqual(tree["type"], "probe", "the second keyed container adds to the first")
        XCTAssertEqual(tree.objectValue?["n"], .null)
        XCTAssertNil(tree.objectValue?["absent"])
        guard case .double(let z) = tree["nested"]["z"], z == 0, z.sign == .minus else {
            return XCTFail("\(tree["nested"]["z"]) is not -0.0")
        }
        assertDouble(tree["list"][0], 1.5)
        XCTAssertEqual(tree["list"][1], .null)
        assertDouble(tree["list"][2], Double(UInt64.max))
        assertDouble(tree["list"][3]["f"], 0.1)
        assertDouble(tree["list"][4][0], 4.0)
        assertDouble(tree["list"][5], 4.0)
        assertDouble(tree["leaf"], 4.0)
        assertDouble(tree["super"], 100.0)
        XCTAssertEqual(tree["sup"], "s")
    }

    /// Over generated models: the tree is the old one as data, ints the same,
    /// each number that differs a double the old path wrote as an integer,
    /// and every JSONValue a model holds comes back with its kinds (F4).
    func testW2_OverGeneratedModelsTheTreeIsTheOldOneWithDoublesKept() throws {
        var widened = 0
        func check<T: Encodable & Decodable & Equatable>(_ model: T, _ label: String) throws {
            let tree = try JSONValue(encoding: model)
            let old = try oldPath(model)
            assertJSONEqual(tree, old, label)
            guard let n = widenings(old, tree) else { return XCTFail("\(label): kinds differ beyond widening") }
            widened += n
            XCTAssertEqual(try tree.decode(T.self), model, label)
        }
        for seed: UInt64 in [3, 41, 2026, 0xBEEF] {
            var gen = Gen(seed: seed)
            for i in 0..<100 {
                let label = "seed \(seed) #\(i)"
                try check(gen.value(depth: 3), label + " value")
                try check(gen.action(depth: 3), label + " action")
                let node = gen.node()
                try check(node, label + " node")
                XCTAssertTrue(sameKinds(try JSONValue(encoding: node)["props"], .object(node.props)), label)
                let json = gen.json(depth: 3)
                XCTAssertTrue(sameKinds(Value.static(json).json["value"], json), label)
                XCTAssertTrue(sameKinds(Action.setState(.init(key: "k", value: json)).json["value"], json), label)
            }
        }
        XCTAssertGreaterThan(widened, 0, "the generators make integral doubles the old path wrote as ints")
    }

    // MARK: W3 the text DevToolsClient sends

    func testW3_TheDevToolsActionEnvelopeShows4_0() throws {
        let event = DevToolsEvent.action(.setState(.init(key: "d", value: 4.0)), pageId: "home", durationMs: 0.75)
        XCTAssertEqual(
            try wireText(event.envelope(deviceId: "dev", timestamp: 1)),
            #"{"deviceId":"dev","payload":{"actionType":"setState","#
                + #""data":{"key":"d","type":"setState","value":4.0},"#
                + #""durationMs":0.75,"family":"state","pageId":"home"},"timestamp":1,"type":"action"}"#)
    }
}

extension JSONValue {
    /// An array element, `.null` past the end or when this is not an array.
    fileprivate subscript(index: Int) -> JSONValue {
        guard case .array(let items) = self, items.indices.contains(index) else { return .null }
        return items[index]
    }
}

/// The coding paths a `Probe` saw, as key strings.
private final class PathLog {
    var paths: [[String]] = []
    func record(_ path: [CodingKey]) { paths.append(path.map(\.stringValue)) }
}

/// Writes 4.0 as one value and records the path it was written at.
private struct Leaf: Encodable {
    let log: PathLog
    func encode(to encoder: Encoder) throws {
        log.record(encoder.codingPath)
        var c = encoder.singleValueContainer()
        try c.encode(4.0)
    }
}

/// Writes through every container kind a Codable model may use.
private final class Probe: Encodable {
    let log = PathLog()

    private enum K: String, CodingKey {
        case d, i, n, absent, nested, z, list, f, leaf, sup, type
    }

    func encode(to encoder: Encoder) throws {
        var a = encoder.container(keyedBy: K.self)
        try a.encode(4.0, forKey: .d)
        try a.encode(4, forKey: .i)
        try a.encodeNil(forKey: .n)
        try a.encodeIfPresent(nil as Double?, forKey: .absent)
        var nested = a.nestedContainer(keyedBy: K.self, forKey: .nested)
        try nested.encode(-0.0, forKey: .z)
        log.record(nested.codingPath)
        var list = a.nestedUnkeyedContainer(forKey: .list)
        try list.encode(1.5)
        try list.encodeNil()
        try list.encode(UInt64.max)
        var inner = list.nestedContainer(keyedBy: K.self)
        try inner.encode(Float(0.1), forKey: .f)
        log.record(inner.codingPath)
        var deeper = list.nestedUnkeyedContainer()
        try deeper.encode(4.0)
        try Leaf(log: log).encode(to: list.superEncoder())
        try a.encode(Leaf(log: log), forKey: .leaf)
        let sup = a.superEncoder()
        log.record(sup.codingPath)
        try 100.0.encode(to: sup)
        try "s".encode(to: a.superEncoder(forKey: .sup))
        var again = encoder.container(keyedBy: K.self)
        try again.encode("probe", forKey: .type)
        log.record(again.codingPath)
    }
}
