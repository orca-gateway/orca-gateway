import Foundation

@testable import OrcaGatewayCore

/// A seeded random generator for the property tests. SplitMix64: tiny,
/// deterministic on every platform, so a failing seed reproduces anywhere.
/// No shrinking; a failure prints its seed and iteration instead.
struct Gen: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &self) }
    mutating func bool() -> Bool { Bool.random(using: &self) }
    mutating func pick<T>(_ items: [T]) -> T { items[int(0...(items.count - 1))] }
    mutating func maybe<T>(_ make: (inout Gen) -> T) -> T? { bool() ? make(&self) : nil }

    mutating func string(maxLength: Int = 8) -> String {
        let alphabet = Array("abcXYZ019 _-.,é漢🙂\"\\/\n")
        return String((0..<int(0...maxLength)).map { _ in pick(alphabet) })
    }

    mutating func key() -> String {
        String((0..<int(1...6)).map { _ in pick(Array("abcdefghij")) })
    }

    /// A finite double that survives a JSON round trip.
    mutating func double() -> Double {
        switch int(0...3) {
        case 0: return Double(int(-1000...1000)) / 8
        case 1: return Double(int(-1_000_000...1_000_000)) * 1e-3
        case 2: return Double.random(in: -1e12...1e12, using: &self)
        default: return Double.random(in: -1...1, using: &self)
        }
    }

    // MARK: JSON

    mutating func json(depth: Int = 3) -> JSONValue {
        let leafOnly = depth <= 0
        switch int(0...(leafOnly ? 4 : 6)) {
        case 0: return .null
        case 1: return .bool(bool())
        case 2: return .int(int(Int(Int32.min)...Int(Int32.max)))
        case 3: return .double(double())
        case 4: return .string(string())
        case 5: return .array((0..<int(0...3)).map { _ in json(depth: depth - 1) })
        default:
            var o: [String: JSONValue] = [:]
            for _ in 0..<int(0...3) { o[key()] = json(depth: depth - 1) }
            return .object(o)
        }
    }

    // MARK: Values

    mutating func value(depth: Int = 2) -> Value {
        let n = depth <= 0 ? int(0...4) : int(0...8)
        switch n {
        case 0: return .static(json(depth: 1))
        case 1: return .state(key: key() + (bool() ? ".x" : ""), scope: pick(StateScope.allCases))
        case 2: return .info(key: key())
        case 3: return .request(key: key())
        case 4: return .event(key: key())
        case 5:
            return .transform(input: value(depth: depth - 1), by: (0..<int(0...3)).map { _ in transform(depth: depth - 1) })
        case 6:
            return .conditional(
                branches: (0..<int(1...2)).map { _ in
                    ConditionalBranch(when: boolExpr(depth: depth - 1), then: value(depth: depth - 1))
                },
                else: maybe { $0.value(depth: depth - 1) })
        case 7:
            return .tween(begin: .int(int(0...10)), end: .string("#FF0000"), animationId: maybe { $0.key() })
        default:
            return .tweenSequence(
                items: (0..<int(1...3)).map { _ in TweenSequenceItem(value: .int(int(0...5)), duration: Double(int(0...600))) },
                animationId: maybe { $0.key() })
        }
    }

    mutating func operand(depth: Int) -> JSONValue {
        bool() ? json(depth: 1) : value(depth: depth).json
    }

    /// For optional fields: an explicit JSON null decodes as absent (as a
    /// Dart `action['x']` read does), so optional fields never hold `.null`.
    mutating func someOperand(depth: Int) -> JSONValue {
        let v = operand(depth: depth)
        return v.isNull ? "n" : v
    }

    mutating func someJSON(depth: Int) -> JSONValue {
        let v = json(depth: depth)
        return v.isNull ? 0 : v
    }

    mutating func transform(depth: Int = 1) -> Transform {
        switch int(0...32) {
        case 0: return .toString
        case 1: return .toUpperCase
        case 2: return .toLowerCase
        case 3: return .trim
        case 4: return .template(template: "{{value}} " + string(), params: maybe { g in [g.key(): g.value(depth: 0).json] })
        case 5: return .regex(pattern: "a+", flags: maybe { $0.pick(["g", "gi", "m"]) }, replacement: maybe { $0.string() }, params: nil)
        case 6: return .substring(start: int(0...3), length: maybe { $0.int(0...3) })
        case 7: return .split(separator: pick([",", "", " "]))
        case 8: return .join(separator: pick([",", ""]))
        case 9: return .multiply(by: operand(depth: depth))
        case 10: return .divide(by: operand(depth: depth))
        case 11: return .add(by: operand(depth: depth))
        case 12: return .subtract(by: operand(depth: depth))
        case 13: return .modulo(by: operand(depth: depth))
        case 14: return .round
        case 15: return .floor
        case 16: return .ceil
        case 17: return .abs
        case 18: return .toFixed(decimals: maybe { $0.int(0...4) })
        case 19: return .not
        case 20: return .toBool
        case 21: return .toggle
        case 22: return .length
        case 23: return .at(index: int(0...3))
        case 24: return .first
        case 25: return .last
        case 26: return .map(transform: depth > 0 ? transform(depth: depth - 1) : .toString)
        case 27: return .filter(expr: boolExpr(depth: depth - 1))
        case 28: return .contains(value: operand(depth: depth))
        case 29: return .formatCurrency(currency: maybe { $0.pick(["USD", "EUR", "SEK"]) }, decimals: maybe { $0.int(0...3) })
        case 30: return .formatDate(format: "yyyy-MM-dd")
        case 31: return .formatNumber(decimals: maybe { $0.int(0...3) }, useGrouping: maybe { $0.bool() })
        default: return .unknown(["type": "sparkle", "level": .int(int(0...9))])
        }
    }

    mutating func boolExpr(depth: Int = 1) -> BoolExpr {
        let leaf = depth <= 0
        switch int(0...(leaf ? 10 : 13)) {
        case 0: return .eq(left: operand(depth: 0), right: operand(depth: 0))
        case 1: return .neq(left: operand(depth: 0), right: operand(depth: 0))
        case 2: return .gt(left: operand(depth: 0), right: operand(depth: 0))
        case 3: return .gte(left: operand(depth: 0), right: operand(depth: 0))
        case 4: return .lt(left: operand(depth: 0), right: operand(depth: 0))
        case 5: return .lte(left: operand(depth: 0), right: operand(depth: 0))
        case 6: return .isNull(operand(depth: 0))
        case 7: return .contains(haystack: operand(depth: 0), needle: operand(depth: 0))
        case 8: return .startsWith(str: operand(depth: 0), prefix: operand(depth: 0))
        case 9: return .matches(str: operand(depth: 0), regex: "^[a-z]+$")
        case 10: return .unknown(["op": "xor", "a": 1])
        case 11: return .and((0..<int(0...2)).map { _ in boolExpr(depth: depth - 1) })
        case 12: return .or((0..<int(0...2)).map { _ in boolExpr(depth: depth - 1) })
        default: return .not(boolExpr(depth: depth - 1))
        }
    }

    // MARK: Actions and nodes

    mutating func action(depth: Int = 2) -> Action {
        let leaf = depth <= 0
        switch int(0...(leaf ? 22 : 28)) {
        case 0: return .navigate(.init(route: someOperand(depth: 0), params: maybe { g in [g.key(): g.value(depth: 0).json] }, replace: maybe { $0.bool() }))
        case 1: return .goBack
        case 2: return .switchTab(.init(tabId: key()))
        case 3: return .openDrawer
        case 4: return .openDialog(.init(dialogId: key(), heightFactor: maybe { $0.double() }))
        case 5: return .closeDialog
        case 6: return .setState(.init(key: key(), scope: maybe { $0.pick(StateScope.allCases) }, value: operand(depth: 1)))
        case 7: return .clearState(.init(key: key(), scope: maybe { $0.pick(StateScope.allCases) }))
        case 8: return .persistState(.init(key: key(), scope: .app, storage: maybe { $0.pick(["local", "session"]) }))
        case 9: return .serverAction(.init(id: key(), params: maybe { g in [g.key(): g.operand(depth: 0)] }))
        case 10: return .showSnackbar(.init(message: someOperand(depth: 0), duration: maybe { $0.int(0...9000) }, action: maybe { $0.string() }))
        case 11: return .showToast(.init(message: someOperand(depth: 0), duration: maybe { $0.int(0...9000) }))
        case 12: return .updateComponent(.init(id: key(), props: [key(): json(depth: 1)]))
        case 13: return .deleteComponent(.init(id: key()))
        case 14: return .addComponent(.init(parentId: key(), node: someJSON(depth: 2), position: maybe { $0.int(0...5) }))
        case 15: return .copyToClipboard(.init(text: someOperand(depth: 0)))
        case 16: return .share(.init(title: .string(string()), message: someOperand(depth: 0), url: maybe { $0.someJSON(depth: 0) }))
        case 17: return .openUrl(.init(url: someOperand(depth: 0)))
        case 18: return .animateForward(.init(animationId: key()))
        case 19: return .animateReverse(.init(animationId: key()))
        case 20: return .refetchPage
        case 21: return .updateSubPage(.init(subPageId: .string(key()), pageId: operand(depth: 0), mode: maybe { _ in "join" }))
        case 22: return .debugLog(.init(level: maybe { $0.pick(["debug", "info"]) }, message: maybe { $0.someOperand(depth: 0) }, includeState: maybe { $0.bool() }))
        case 23: return .actionGroup(.init(mode: maybe { $0.pick(["sequential", "parallel"]) }, actions: (0..<int(0...3)).map { _ in action(depth: depth - 1) }))
        case 24:
            return .conditionalAction(.init(
                branches: (0..<int(1...2)).map { _ in .init(when: boolExpr(depth: 1), then: action(depth: depth - 1)) },
                else: maybe { $0.action(depth: depth - 1) }))
        case 25:
            return .lifecycle(.init(
                action: action(depth: depth - 1),
                onLoading: maybe { .single($0.action(depth: depth - 1)) },
                onSuccess: maybe { g in .many((0..<g.int(0...2)).map { _ in g.action(depth: depth - 1) }) },
                onError: nil,
                onComplete: maybe { .single($0.action(depth: depth - 1)) }))
        case 26: return .once(.init(action: action(depth: depth - 1)))
        case 27: return .always(.init(action: action(depth: depth - 1)))
        default: return .custom(["type": .string("custom:" + key()), key(): json(depth: 1)])
        }
    }

    /// Props mix plain JSON and Value objects at any depth, as on the wire.
    mutating func props(depth: Int = 2) -> [String: JSONValue] {
        var o: [String: JSONValue] = [:]
        for _ in 0..<int(0...4) {
            if depth > 0 && int(0...3) == 0 {
                o[key()] = .object(props(depth: depth - 1))
            } else {
                o[key()] = bool() ? json(depth: 1) : value().json
            }
        }
        return o
    }

    mutating func node() -> ComponentNode {
        ComponentNode(
            id: key(), type: pick(["Text", "Column", "Row", "Scaffold", "MiniMap"]),
            kind: pick(ComponentNode.Kind.allCases), childMode: pick(ComponentNode.ChildMode.allCases),
            props: props(), children: (0..<int(0...3)).map { _ in key() },
            watches: (0..<int(0...3)).map { _ in key() },
            actions: maybe { g in ["onTap": g.action(), "onLongPress": g.action(depth: 0)] })
    }
}
