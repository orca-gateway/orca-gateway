import Foundation

/// A typed wire `Value` (schema/value.schema.json, engine/src/types/value.ts).
///
/// Props on a `ComponentNode` stay `JSONValue`, because a prop may be a plain
/// literal, a nested map, or a Value anywhere inside it; the resolver works on
/// that JSON directly, as the Dart SDK does. This typed form is for code that
/// knows a field holds a Value and for round-trip tests.
public indirect enum Value: Equatable, Sendable {
    case `static`(JSONValue)
    case state(key: String, scope: StateScope)
    case info(key: String)
    case request(key: String)
    case event(key: String)
    case transform(input: Value, by: [Transform])
    case conditional(branches: [ConditionalBranch], else: Value?)
    case tween(begin: JSONValue, end: JSONValue, animationId: String?)
    case tweenSequence(items: [TweenSequenceItem], animationId: String?)

    /// The nine `type` discriminators, in schema order.
    public static let kinds = [
        "static", "state", "info", "request", "event",
        "transform", "conditional", "tween", "tweenSequence",
    ]

    public var kind: String {
        switch self {
        case .static: return "static"
        case .state: return "state"
        case .info: return "info"
        case .request: return "request"
        case .event: return "event"
        case .transform: return "transform"
        case .conditional: return "conditional"
        case .tween: return "tween"
        case .tweenSequence: return "tweenSequence"
        }
    }
}

public enum StateScope: String, Codable, Sendable, CaseIterable {
    case page
    case app
}

public struct ConditionalBranch: Codable, Equatable, Sendable {
    public var when: BoolExpr
    public var then: Value

    public init(when: BoolExpr, then: Value) {
        self.when = when
        self.then = then
    }
}

public struct TweenSequenceItem: Codable, Equatable, Sendable {
    public var value: JSONValue
    public var duration: Double

    public init(value: JSONValue, duration: Double) {
        self.value = value
        self.duration = duration
    }
}

extension Value: Codable {
    private enum Keys: String, CodingKey {
        case type, value, key, scope, input, by, branches, `else`
        case begin, end, animationId, items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "static":
            self = .static(try c.decodeIfPresent(JSONValue.self, forKey: .value) ?? .null)
        case "state":
            self = .state(
                key: try c.decode(String.self, forKey: .key),
                scope: try c.decodeIfPresent(StateScope.self, forKey: .scope) ?? .page)
        case "info":
            self = .info(key: try c.decode(String.self, forKey: .key))
        case "request":
            self = .request(key: try c.decode(String.self, forKey: .key))
        case "event":
            self = .event(key: try c.decode(String.self, forKey: .key))
        case "transform":
            self = .transform(
                input: try c.decode(Value.self, forKey: .input),
                by: try c.decode([Transform].self, forKey: .by))
        case "conditional":
            self = .conditional(
                branches: try c.decode([ConditionalBranch].self, forKey: .branches),
                else: try c.decodeIfPresent(Value.self, forKey: .else))
        case "tween":
            self = .tween(
                begin: try c.decodeIfPresent(JSONValue.self, forKey: .begin) ?? .null,
                end: try c.decodeIfPresent(JSONValue.self, forKey: .end) ?? .null,
                animationId: try c.decodeIfPresent(String.self, forKey: .animationId))
        case "tweenSequence":
            self = .tweenSequence(
                items: try c.decode([TweenSequenceItem].self, forKey: .items),
                animationId: try c.decodeIfPresent(String.self, forKey: .animationId))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c, debugDescription: "Unknown Value type '\(type)'")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(kind, forKey: .type)
        switch self {
        case .static(let v):
            try c.encode(v, forKey: .value)
        case .state(let key, let scope):
            try c.encode(key, forKey: .key)
            try c.encode(scope, forKey: .scope)
        case .info(let key), .request(let key), .event(let key):
            try c.encode(key, forKey: .key)
        case .transform(let input, let by):
            try c.encode(input, forKey: .input)
            try c.encode(by, forKey: .by)
        case .conditional(let branches, let elseValue):
            try c.encode(branches, forKey: .branches)
            try c.encodeIfPresent(elseValue, forKey: .else)
        case .tween(let begin, let end, let animationId):
            try c.encode(begin, forKey: .begin)
            try c.encode(end, forKey: .end)
            try c.encodeIfPresent(animationId, forKey: .animationId)
        case .tweenSequence(let items, let animationId):
            try c.encode(items, forKey: .items)
            try c.encodeIfPresent(animationId, forKey: .animationId)
        }
    }
}

// MARK: - Transform

/// One step of a `transform` Value's `by` pipeline. The 31 kinds of the engine
/// (value.ts) plus `toggle`, which the Dart SDK also registers. A kind this
/// build does not know decodes to `.unknown` and the resolver skips it, as the
/// Dart registry does.
public indirect enum Transform: Equatable, Sendable {
    // String
    case toString
    case toUpperCase
    case toLowerCase
    case trim
    case template(template: String, params: [String: JSONValue]?)
    case regex(pattern: String, flags: String?, replacement: String?, params: [String: JSONValue]?)
    case substring(start: Int, length: Int?)
    case split(separator: String)
    case join(separator: String)
    // Number
    case multiply(by: JSONValue)
    case divide(by: JSONValue)
    case add(by: JSONValue)
    case subtract(by: JSONValue)
    case modulo(by: JSONValue)
    case round
    case floor
    case ceil
    case abs
    case toFixed(decimals: Int?)
    // Boolean
    case not
    case toBool
    case toggle
    // Collection
    case length
    case at(index: Int)
    case first
    case last
    case map(transform: Transform)
    case filter(expr: BoolExpr)
    case contains(value: JSONValue)
    // Format
    case formatCurrency(currency: String?, decimals: Int?)
    case formatDate(format: String)
    case formatNumber(decimals: Int?, useGrouping: Bool?)
    /// A kind this build does not implement, kept verbatim.
    case unknown(JSONValue)

    public var kind: String {
        switch self {
        case .toString: return "toString"
        case .toUpperCase: return "toUpperCase"
        case .toLowerCase: return "toLowerCase"
        case .trim: return "trim"
        case .template: return "template"
        case .regex: return "regex"
        case .substring: return "substring"
        case .split: return "split"
        case .join: return "join"
        case .multiply: return "multiply"
        case .divide: return "divide"
        case .add: return "add"
        case .subtract: return "subtract"
        case .modulo: return "modulo"
        case .round: return "round"
        case .floor: return "floor"
        case .ceil: return "ceil"
        case .abs: return "abs"
        case .toFixed: return "toFixed"
        case .not: return "not"
        case .toBool: return "toBool"
        case .toggle: return "toggle"
        case .length: return "length"
        case .at: return "at"
        case .first: return "first"
        case .last: return "last"
        case .map: return "map"
        case .filter: return "filter"
        case .contains: return "contains"
        case .formatCurrency: return "formatCurrency"
        case .formatDate: return "formatDate"
        case .formatNumber: return "formatNumber"
        case .unknown(let raw): return raw["type"].stringValue ?? ""
        }
    }
}

extension Transform: Codable {
    private enum Keys: String, CodingKey {
        case type, template, params, pattern, flags, replacement, start, length
        case separator, by, decimals, index, transform, expr, value, currency
        case format, useGrouping
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let type = try c.decode(String.self, forKey: .type)
        func by() throws -> JSONValue { try c.decodeIfPresent(JSONValue.self, forKey: .by) ?? .null }
        switch type {
        case "toString": self = .toString
        case "toUpperCase": self = .toUpperCase
        case "toLowerCase": self = .toLowerCase
        case "trim": self = .trim
        case "template":
            self = .template(
                template: try c.decodeIfPresent(String.self, forKey: .template) ?? "",
                params: try c.decodeIfPresent([String: JSONValue].self, forKey: .params))
        case "regex":
            self = .regex(
                pattern: try c.decodeIfPresent(String.self, forKey: .pattern) ?? "",
                flags: try c.decodeIfPresent(String.self, forKey: .flags),
                replacement: try c.decodeIfPresent(String.self, forKey: .replacement),
                params: try c.decodeIfPresent([String: JSONValue].self, forKey: .params))
        case "substring":
            self = .substring(
                start: try c.decodeIfPresent(Int.self, forKey: .start) ?? 0,
                length: try c.decodeIfPresent(Int.self, forKey: .length))
        case "split":
            self = .split(separator: try c.decodeIfPresent(String.self, forKey: .separator) ?? "")
        case "join":
            self = .join(separator: try c.decodeIfPresent(String.self, forKey: .separator) ?? "")
        case "multiply": self = .multiply(by: try by())
        case "divide": self = .divide(by: try by())
        case "add": self = .add(by: try by())
        case "subtract": self = .subtract(by: try by())
        case "modulo": self = .modulo(by: try by())
        case "round": self = .round
        case "floor": self = .floor
        case "ceil": self = .ceil
        case "abs": self = .abs
        case "toFixed":
            self = .toFixed(decimals: try c.decodeIfPresent(Int.self, forKey: .decimals))
        case "not": self = .not
        case "toBool": self = .toBool
        case "toggle": self = .toggle
        case "length": self = .length
        case "at": self = .at(index: try c.decodeIfPresent(Int.self, forKey: .index) ?? 0)
        case "first": self = .first
        case "last": self = .last
        case "map": self = .map(transform: try c.decode(Transform.self, forKey: .transform))
        case "filter": self = .filter(expr: try c.decode(BoolExpr.self, forKey: .expr))
        case "contains":
            self = .contains(value: try c.decodeIfPresent(JSONValue.self, forKey: .value) ?? .null)
        case "formatCurrency":
            self = .formatCurrency(
                currency: try c.decodeIfPresent(String.self, forKey: .currency),
                decimals: try c.decodeIfPresent(Int.self, forKey: .decimals))
        case "formatDate":
            self = .formatDate(format: try c.decodeIfPresent(String.self, forKey: .format) ?? "")
        case "formatNumber":
            self = .formatNumber(
                decimals: try c.decodeIfPresent(Int.self, forKey: .decimals),
                useGrouping: try c.decodeIfPresent(Bool.self, forKey: .useGrouping))
        default:
            self = .unknown(try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if case .unknown(let raw) = self {
            try raw.encode(to: encoder)
            return
        }
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(kind, forKey: .type)
        switch self {
        case .template(let template, let params):
            try c.encode(template, forKey: .template)
            try c.encodeIfPresent(params, forKey: .params)
        case .regex(let pattern, let flags, let replacement, let params):
            try c.encode(pattern, forKey: .pattern)
            try c.encodeIfPresent(flags, forKey: .flags)
            try c.encodeIfPresent(replacement, forKey: .replacement)
            try c.encodeIfPresent(params, forKey: .params)
        case .substring(let start, let length):
            try c.encode(start, forKey: .start)
            try c.encodeIfPresent(length, forKey: .length)
        case .split(let separator), .join(let separator):
            try c.encode(separator, forKey: .separator)
        case .multiply(let by), .divide(let by), .add(let by), .subtract(let by), .modulo(let by):
            try c.encode(by, forKey: .by)
        case .toFixed(let decimals):
            try c.encodeIfPresent(decimals, forKey: .decimals)
        case .at(let index):
            try c.encode(index, forKey: .index)
        case .map(let transform):
            try c.encode(transform, forKey: .transform)
        case .filter(let expr):
            try c.encode(expr, forKey: .expr)
        case .contains(let value):
            try c.encode(value, forKey: .value)
        case .formatCurrency(let currency, let decimals):
            try c.encodeIfPresent(currency, forKey: .currency)
            try c.encodeIfPresent(decimals, forKey: .decimals)
        case .formatDate(let format):
            try c.encode(format, forKey: .format)
        case .formatNumber(let decimals, let useGrouping):
            try c.encodeIfPresent(decimals, forKey: .decimals)
            try c.encodeIfPresent(useGrouping, forKey: .useGrouping)
        default:
            break
        }
    }
}

// MARK: - BoolExpr

/// A boolean expression used by `conditional` Values, `filter` transforms and
/// `conditionalAction`. Operands are `JSONValue` because the wire allows a
/// Value or a literal in each slot.
public indirect enum BoolExpr: Equatable, Sendable {
    case eq(left: JSONValue, right: JSONValue)
    case neq(left: JSONValue, right: JSONValue)
    case gt(left: JSONValue, right: JSONValue)
    case gte(left: JSONValue, right: JSONValue)
    case lt(left: JSONValue, right: JSONValue)
    case lte(left: JSONValue, right: JSONValue)
    case and([BoolExpr])
    case or([BoolExpr])
    case not(BoolExpr)
    case isNull(JSONValue)
    case contains(haystack: JSONValue, needle: JSONValue)
    case startsWith(str: JSONValue, prefix: JSONValue)
    case matches(str: JSONValue, regex: String)
    /// An op this build does not know; evaluates to false, as in Dart.
    case unknown(JSONValue)

    /// The 13 `op` discriminators.
    public static let ops = [
        "eq", "neq", "gt", "gte", "lt", "lte", "and", "or", "not",
        "isNull", "contains", "startsWith", "matches",
    ]

    public var op: String {
        switch self {
        case .eq: return "eq"
        case .neq: return "neq"
        case .gt: return "gt"
        case .gte: return "gte"
        case .lt: return "lt"
        case .lte: return "lte"
        case .and: return "and"
        case .or: return "or"
        case .not: return "not"
        case .isNull: return "isNull"
        case .contains: return "contains"
        case .startsWith: return "startsWith"
        case .matches: return "matches"
        case .unknown(let raw): return raw["op"].stringValue ?? ""
        }
    }
}

extension BoolExpr: Codable {
    private enum Keys: String, CodingKey {
        case op, left, right, exprs, expr, value, haystack, needle, str, prefix, regex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let op = try c.decode(String.self, forKey: .op)
        func operand(_ k: Keys) throws -> JSONValue {
            try c.decodeIfPresent(JSONValue.self, forKey: k) ?? .null
        }
        switch op {
        case "eq": self = .eq(left: try operand(.left), right: try operand(.right))
        case "neq": self = .neq(left: try operand(.left), right: try operand(.right))
        case "gt": self = .gt(left: try operand(.left), right: try operand(.right))
        case "gte": self = .gte(left: try operand(.left), right: try operand(.right))
        case "lt": self = .lt(left: try operand(.left), right: try operand(.right))
        case "lte": self = .lte(left: try operand(.left), right: try operand(.right))
        case "and": self = .and(try c.decodeIfPresent([BoolExpr].self, forKey: .exprs) ?? [])
        case "or": self = .or(try c.decodeIfPresent([BoolExpr].self, forKey: .exprs) ?? [])
        case "not": self = .not(try c.decode(BoolExpr.self, forKey: .expr))
        case "isNull": self = .isNull(try operand(.value))
        case "contains":
            self = .contains(haystack: try operand(.haystack), needle: try operand(.needle))
        case "startsWith":
            self = .startsWith(str: try operand(.str), prefix: try operand(.prefix))
        case "matches":
            self = .matches(
                str: try operand(.str),
                regex: try c.decodeIfPresent(String.self, forKey: .regex) ?? "")
        default:
            self = .unknown(try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if case .unknown(let raw) = self {
            try raw.encode(to: encoder)
            return
        }
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(op, forKey: .op)
        switch self {
        case .eq(let l, let r), .neq(let l, let r), .gt(let l, let r),
            .gte(let l, let r), .lt(let l, let r), .lte(let l, let r):
            try c.encode(l, forKey: .left)
            try c.encode(r, forKey: .right)
        case .and(let exprs), .or(let exprs):
            try c.encode(exprs, forKey: .exprs)
        case .not(let expr):
            try c.encode(expr, forKey: .expr)
        case .isNull(let v):
            try c.encode(v, forKey: .value)
        case .contains(let haystack, let needle):
            try c.encode(haystack, forKey: .haystack)
            try c.encode(needle, forKey: .needle)
        case .startsWith(let str, let prefix):
            try c.encode(str, forKey: .str)
            try c.encode(prefix, forKey: .prefix)
        case .matches(let str, let regex):
            try c.encode(str, forKey: .str)
            try c.encode(regex, forKey: .regex)
        case .unknown:
            break
        }
    }
}

// MARK: - JSON bridge

extension Value {
    /// This Value as wire JSON.
    public var json: JSONValue { (try? JSONValue(encoding: self)) ?? .null }
}

extension BoolExpr {
    public var json: JSONValue { (try? JSONValue(encoding: self)) ?? .null }
}

extension Transform {
    public var json: JSONValue { (try? JSONValue(encoding: self)) ?? .null }
}
