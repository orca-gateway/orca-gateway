import Foundation

/// Resolves wire Values against state, a port of the Flutter SDK's
/// `sdk/lib/src/state/value_resolver.dart`, which is the reference client.
///
/// It works on raw `JSONValue` exactly as the Dart one works on
/// `Map<String, dynamic>`: literals pass through, a map whose `type` is a
/// client-side Value kind resolves, anything else is returned unchanged
/// (including `info` and `request`, which the engine resolves before sending).
///
/// One deliberate difference: where Dart throws a TypeError or RangeError (an
/// `add` on a string, `substring` past the end, `round` on null) the widget
/// build fails in Flutter; here the step yields `.null` instead, because a
/// Swift crash would take the whole app down. Everything else, including the
/// null semantics of the BoolExpr ops, follows Dart line by line.
public struct ValueResolver {
    /// Merged state, app first and page on top, as the Dart SDK builds it.
    public var state: [String: JSONValue]
    /// Event payload of the trigger that fired the current action, if any.
    public var eventData: [String: JSONValue]?
    /// Progress (0...1) of the enclosing animation; nil outside one.
    public var animationProgress: Double?
    /// Progress of a targeted animation by id (Dart's AnimationRegistry).
    public var animationProgressFor: ((String) -> Double?)?
    public var transforms: TransformRegistry

    public init(
        state: [String: JSONValue],
        eventData: [String: JSONValue]? = nil,
        animationProgress: Double? = nil,
        animationProgressFor: ((String) -> Double?)? = nil,
        transforms: TransformRegistry = .defaults
    ) {
        self.state = state
        self.eventData = eventData
        self.animationProgress = animationProgress
        self.animationProgressFor = animationProgressFor
        self.transforms = transforms
    }

    /// Merge app and page scopes the way every Dart call site does: page wins.
    public init(page: [String: JSONValue], app: [String: JSONValue],
                eventData: [String: JSONValue]? = nil) {
        self.init(state: app.merging(page) { _, pageValue in pageValue }, eventData: eventData)
    }

    /// The nine Value kinds; a map with one of these `type`s is a Value.
    public static let valueTypes: Set<String> = Set(Value.kinds)

    // MARK: resolve

    /// Resolve one value expression (Dart `resolve`). Does not descend into
    /// plain maps or lists; use `resolveDeep` for props.
    public func resolve(_ value: JSONValue) -> JSONValue {
        guard case .object(let map) = value else { return value }
        switch map["type"]?.stringValue {
        case "static": return map["value"] ?? .null
        case "state": return resolveState(map)
        case "event": return resolveEvent(map)
        case "transform": return resolveTransform(map)
        case "conditional": return resolveConditional(map)
        case "tween": return resolveTween(map)
        case "tweenSequence": return resolveTweenSequence(map)
        default: return value
        }
    }

    public func resolve(_ value: Value) -> JSONValue {
        resolve(value.json)
    }

    /// Resolve and render as text: null becomes "", everything else Dart's
    /// `'$value'`.
    public func resolveToString(_ value: JSONValue) -> String {
        let resolved = resolve(value)
        return resolved.isNull ? "" : DartFormat.string(resolved)
    }

    /// Resolve every Value nested in plain maps and lists (Dart `resolveDeep`).
    public func resolveDeep(_ value: JSONValue) -> JSONValue {
        switch value {
        case .array(let items):
            return .array(items.map(resolveDeep))
        case .object(let map):
            if let type = map["type"]?.stringValue, Self.valueTypes.contains(type) {
                return resolve(value)
            }
            return .object(map.mapValues(resolveDeep))
        default:
            return value
        }
    }

    // MARK: kinds

    private func resolveState(_ map: [String: JSONValue]) -> JSONValue {
        guard let key = map["key"]?.stringValue else { return .null }
        return StatePath.lookup(state, key)
    }

    private func resolveEvent(_ map: [String: JSONValue]) -> JSONValue {
        guard let key = map["key"]?.stringValue, let eventData else { return .null }
        return eventData[key] ?? .null
    }

    private func resolveConditional(_ map: [String: JSONValue]) -> JSONValue {
        if case .array(let branches)? = map["branches"] {
            for branch in branches {
                guard case .object(let b) = branch else { continue }
                if case .object(let when)? = b["when"], evaluate(when) {
                    return resolve(b["then"] ?? .null)
                }
            }
        }
        let elseValue = map["else"] ?? .null
        return elseValue.isNull ? .null : resolve(elseValue)
    }

    private func resolveTransform(_ map: [String: JSONValue]) -> JSONValue {
        var current = resolve(map["input"] ?? .null)
        guard case .array(let pipeline)? = map["by"] else { return current }
        for step in pipeline {
            guard case .object(let def) = step, let type = def["type"]?.stringValue,
                let op = transforms[type]
            else { continue }
            current = op(def, current, self)
        }
        return current
    }

    // MARK: tweens

    private func progress(_ map: [String: JSONValue]) -> Double {
        if let id = map["animationId"]?.stringValue, let lookup = animationProgressFor {
            return lookup(id) ?? 0
        }
        return animationProgress ?? 0
    }

    private func resolveTween(_ map: [String: JSONValue]) -> JSONValue {
        let t = progress(map)
        let begin = map["begin"] ?? .null
        let end = map["end"] ?? .null
        return Self.lerp(begin, end, t)
    }

    private func resolveTweenSequence(_ map: [String: JSONValue]) -> JSONValue {
        let t = progress(map)
        guard case .array(let items)? = map["items"], !items.isEmpty else { return .null }

        var total = 0.0
        for item in items {
            if case .object = item { total += item["duration"].doubleValue ?? 0 }
        }
        if total <= 0 { return items[0]["value"] }

        let currentTime = t * total
        var elapsed = 0.0
        for (i, item) in items.enumerated() {
            let duration = item["duration"].doubleValue ?? 0
            let value = item["value"]
            if duration <= 0 { continue }
            if currentTime <= elapsed + duration {
                let segment = (currentTime - elapsed) / duration
                let previous = i > 0 ? items[i - 1]["value"] : value
                return Self.lerp(previous, value, segment)
            }
            elapsed += duration
        }
        return items[items.count - 1]["value"]
    }

    /// Numbers interpolate (always to a double, as Dart's `num + num * double`),
    /// `#hex` colours interpolate per channel, anything else snaps at 0.5.
    static func lerp(_ a: JSONValue, _ b: JSONValue, _ t: Double) -> JSONValue {
        if let x = a.doubleValue, let y = b.doubleValue {
            return .double(x + (y - x) * t)
        }
        if case .string(let x) = a, case .string(let y) = b, x.hasPrefix("#"), y.hasPrefix("#") {
            guard let color = lerpColor(x, y, t) else { return .null }
            return .string(color)
        }
        return t < 0.5 ? a : b
    }

    static func lerpColor(_ hexA: String, _ hexB: String, _ t: Double) -> String? {
        func parse(_ hex: String) -> UInt32? {
            let h = String(hex.dropFirst())
            if h.count == 6 { return UInt32("FF" + h, radix: 16) }
            if h.count == 8 { return UInt32(h, radix: 16) }
            return 0xFF00_0000
        }
        guard let a = parse(hexA), let b = parse(hexB) else { return nil }
        func channel(_ shift: UInt32) -> UInt32 {
            let ca = Double((a >> shift) & 0xFF)
            let cb = Double((b >> shift) & 0xFF)
            let v = (ca + (cb - ca) * t).rounded(.toNearestOrAwayFromZero)
            guard v.isFinite else { return 0 }
            return UInt32(Swift.min(Swift.max(v, 0), 255))
        }
        let value = (channel(24) << 24) | (channel(16) << 16) | (channel(8) << 8) | channel(0)
        let hex = String(value, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: Swift.max(0, 8 - hex.count)) + hex
    }

    // MARK: BoolExpr

    /// Evaluate a wire BoolExpr (Dart `evaluateBoolExpr`).
    public func evaluate(_ expr: [String: JSONValue]) -> Bool {
        guard let op = expr["op"]?.stringValue else { return false }
        func operand(_ key: String) -> JSONValue { resolve(expr[key] ?? .null) }

        switch op {
        case "eq": return operand("left") == operand("right")
        case "neq": return operand("left") != operand("right")
        case "gt": return compareNum(expr) > 0
        case "gte": return compareNum(expr) >= 0
        case "lt": return compareNum(expr) < 0
        case "lte": return compareNum(expr) <= 0
        case "and":
            let exprs = expr["exprs"]?.arrayValue ?? []
            return exprs.allSatisfy { e in e.objectValue.map(evaluate) ?? false }
        case "or":
            let exprs = expr["exprs"]?.arrayValue ?? []
            return exprs.contains { e in e.objectValue.map(evaluate) ?? false }
        case "not":
            guard let inner = expr["expr"]?.objectValue else { return true }
            return !evaluate(inner)
        case "isNull":
            return operand("value").isNull
        case "contains":
            let haystack = operand("haystack")
            let needle = operand("needle")
            switch haystack {
            case .string(let s): return s.contains(DartFormat.string(needle))
            case .array(let items): return items.contains(needle)
            default: return false
            }
        case "startsWith":
            return DartFormat.string(operand("str")).hasPrefix(DartFormat.string(operand("prefix")))
        case "matches":
            let pattern = expr["regex"]?.stringValue ?? ""
            guard pattern.utf16.count <= Regex.maxPatternLength,
                let re = Regex.compile(pattern, flags: nil)
            else { return false }
            let input = Regex.clip(DartFormat.string(operand("str")))
            return Regex.firstMatch(re, in: input) != nil
        default:
            return false
        }
    }

    public func evaluate(_ expr: BoolExpr) -> Bool {
        guard case .object(let map) = expr.json else { return false }
        return evaluate(map)
    }

    /// Dart `_compareNum`: compares when both sides are numbers, else 0, so
    /// `gte` and `lte` hold for a missing operand while `gt` and `lt` do not.
    private func compareNum(_ expr: [String: JSONValue]) -> Int {
        let l = resolve(expr["left"] ?? .null)
        let r = resolve(expr["right"] ?? .null)
        switch (l, r) {
        case (.int(let a), .int(let b)): return a < b ? -1 : (a > b ? 1 : 0)
        default:
            guard let a = l.doubleValue, let b = r.doubleValue else { return 0 }
            if a < b { return -1 }
            if a > b { return 1 }
            if a == b { return 0 }
            // Dart's compareTo puts NaN above everything, itself included.
            return a.isNaN ? (b.isNaN ? 0 : 1) : -1
        }
    }
}

/// Dotted state paths, shared by the resolver and the store's watch snapshots.
public enum StatePath {
    /// Dart `lookupStatePath`: the flat key wins when present; otherwise walk
    /// `theme.color` or `items.0.name` through nested objects and arrays.
    /// Matches the engine's `getByDotPath`; pinned by render fixture 06.
    public static func lookup(_ state: [String: JSONValue], _ key: String) -> JSONValue {
        if let flat = state[key] { return flat }
        guard key.contains(".") else { return .null }
        var current: JSONValue = .object(state)
        for segment in key.split(separator: ".", omittingEmptySubsequences: false) {
            switch current {
            case .object(let o):
                current = o[String(segment)] ?? .null
            case .array(let a):
                guard let i = Int(segment), i >= 0, i < a.count else { return .null }
                current = a[i]
            default:
                return .null
            }
            if current.isNull { return .null }
        }
        return current
    }
}
