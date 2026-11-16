import Foundation

/// The pure core of the SubPage widget and the updateSubPage action.
///
/// No SwiftUI, no I/O: JSON values in, JSON values out. The contract (S1 to
/// S8) and the normative table of rewritten fields are in
/// `schema/fixtures/subpage/README.md`; every function here is pinned by the
/// fixtures of that folder, and it is the twin, call for call, of the Dart
/// core (`sdk/lib/src/state/sub_page_core.dart`) and of the Kotlin one.
///
/// A page mounted in a SubPage lives in the host page's node store and page
/// state. What keeps the two apart is a prefix, put by `merge` in front of
/// every id and every page-state key of the mounted page.
///
/// Nodes, actions and responses are `JSONValue` trees, not the typed models:
/// merge copies every field it has no rule for, known to the models or not.
/// Text is compared by its UTF-8 bytes, never by Swift's `==` or `hasPrefix`,
/// which call canonically equivalent strings the same.
public enum SubPage {
    /// The prefix of a page mounted in the SubPage whose node id is `key`:
    /// `K:` for page 0, `K#j:` for the `join`-th joined page (from 1).
    public static func prefix(key: String, join: Int = 0) -> String {
        join == 0 ? "\(key):" : "\(key)#\(join):"
    }

    /// Rewrites a page `response` (`components` and `state`) for mounting
    /// under `prefix`: ids, children, slot props, page-state references and
    /// keys, watches and node-addressing ids get the prefix; each page-scoped
    /// state definition gives one seed.
    public static func merge(prefix: String, response: JSONValue) -> SubPageMerge {
        let nodes = (response["components"].arrayValue ?? []).map { node(prefix, $0) }
        var state: [String: JSONValue] = [:]
        for def in response["state"].arrayValue ?? [] {
            guard isPage(def["scope"]), let key = def["key"].stringValue else { continue }
            state[prefix + key] = def["initial"]
        }
        return SubPageMerge(nodes: nodes, state: state)
    }

    /// Rewrites a bare action list (what a server returns to a serverAction
    /// fired inside the page mounted under `prefix`) by the rules `merge`
    /// applies to a node's actions.
    public static func rewriteActions(prefix: String, actions: [JSONValue]) -> [JSONValue] {
        actions.map { walk(prefix, $0, actions: true) }
    }

    /// The fetch of `pageId` with the resolved `params`. The path is the page
    /// id without its leading slashes, each segment between slashes
    /// percent-encoded (so a `?` or a `#` in it stays in the path). The query:
    /// keys sorted by code point, keys and values percent-encoded, null
    /// params left out.
    public static func request(pageId: String, params: [String: JSONValue]? = nil) -> SubPageRequest {
        let sent = (params ?? [:]).filter { !$0.value.isNull }
        let query = sent.keys.sorted(by: byCodePoint)
            .map { "\(percent($0.utf8))=\(percent(text(sent[$0] ?? .null).utf8))" }
            .joined(separator: "&")
        let path = pageId.utf8.drop { $0 == slash }
            .split(separator: slash, omittingEmptySubsequences: false)
            .map { percent($0) }
            .joined(separator: "/")
        return SubPageRequest(path: path, query: query)
    }

    /// The mounted page a node belongs to: the longest of `prefixes` that
    /// `sourceId` starts with (an id equal to a prefix starts with it), or nil
    /// (a host node, an empty id, or no source).
    public static func prefixOf(prefixes: some Sequence<String>, sourceId: String?) -> String? {
        guard let sourceId else { return nil }
        var best: String?
        for prefix in prefixes where starts(sourceId, with: prefix) {
            if best.map({ prefix.utf8.count > $0.utf8.count }) ?? true { best = prefix }
        }
        return best
    }

    /// The page state a serverAction posts when its source belongs to
    /// `prefix` (see `prefixOf`): the keys under the prefix, with the prefix
    /// removed. A nil prefix posts the whole `pageState`.
    public static func postedState(prefix: String?, pageState: [String: JSONValue]) -> [String: JSONValue] {
        guard let prefix else { return pageState }
        var posted: [String: JSONValue] = [:]
        for (key, value) in pageState where starts(key, with: prefix) {
            posted[String(decoding: key.utf8.dropFirst(prefix.utf8.count), as: UTF8.self)] = value
        }
        return posted
    }
}

/// What `SubPage.merge` gives: the rewritten nodes, in the response's order
/// (the root first), and the state seeds (prefixed key to initial value).
public struct SubPageMerge: Sendable, Equatable {
    public let nodes: [JSONValue]
    public let state: [String: JSONValue]
}

/// Where a sub-page is fetched: `path` on the normal page route and `query`,
/// without its question mark, empty when no param is sent.
public struct SubPageRequest: Sendable, Equatable {
    public let path: String
    public let query: String

    /// The path with its query: what is handed to the page fetch.
    public var location: String { query.isEmpty ? path : "\(path)?\(query)" }
}

/// One page mounted in a SubPage.
public struct SubPageMounted: Sendable, Equatable {
    public let prefix: String
    /// The merged nodes, the root first.
    public let nodes: [JSONValue]

    /// Id of the node to draw, nil for a page without components.
    public var rootId: String? { nodes.first?["id"].stringValue }
}

/// What one `SubPageMounts.apply` asks of the host page, in this order: take
/// `removedNodeIds` out of the node store and `removedStateKeys` out of the
/// page state, then put `nodes` in the store and write `seeds`.
public struct SubPageChange: Sendable, Equatable {
    /// Prefix of the page this step mounted.
    public let prefix: String
    public let nodes: [JSONValue]
    public let seeds: [String: JSONValue]
    public let removedNodeIds: [String]
    public let removedStateKeys: [String]
}

/// The pages mounted in one SubPage, oldest first.
public struct SubPageMounts: Sendable, Equatable {
    /// Id of the SubPage node in the host page's node store.
    public let subPageKey: String
    public private(set) var pages: [SubPageMounted] = []
    private var joins = 0

    public init(subPageKey: String) {
        self.subPageKey = subPageKey
    }

    /// Prefix of each mounted page, oldest first.
    public var prefixes: [String] { pages.map(\.prefix) }

    /// Root id of each mounted page that has one: the drawing order.
    public var roots: [String] { pages.compactMap(\.rootId) }

    /// Id of every node this SubPage has in the host's node store.
    public var nodeIds: [String] { pages.flatMap { $0.nodes.compactMap { $0["id"].stringValue } } }

    /// Mounts a fetched `response`. Mode `join`, with a page already mounted,
    /// adds it after the others under the next `K#j:` prefix and removes
    /// nothing. Any other mode (the first load is a `replace`) removes every
    /// mounted page and every key of `pageStateKeys` under `K:` or
    /// `K#<digits>:`, and mounts the response as page 0.
    public mutating func apply(mode: String, response: JSONValue, pageStateKeys: some Sequence<String>)
        -> SubPageChange {
        let join = SubPage.same(mode, "join") && !pages.isEmpty
        let removedNodeIds = join ? [] : nodeIds
        let removedStateKeys = join ? [] : pageStateKeys.filter(owns)
        if join {
            joins += 1
        } else {
            pages.removeAll()
            joins = 0
        }
        let prefix = SubPage.prefix(key: subPageKey, join: joins)
        let merged = SubPage.merge(prefix: prefix, response: response)
        pages.append(SubPageMounted(prefix: prefix, nodes: merged.nodes))
        return SubPageChange(
            prefix: prefix, nodes: merged.nodes, seeds: merged.state,
            removedNodeIds: removedNodeIds, removedStateKeys: removedStateKeys)
    }

    /// Whether a page-state key is under `K:` or `K#<digits>:`.
    private func owns(_ key: String) -> Bool {
        guard SubPage.starts(key, with: subPageKey) else { return false }
        var rest = key.utf8.dropFirst(subPageKey.utf8.count)
        guard let first = rest.first else { return false }
        if first == UInt8(ascii: ":") { return true }
        guard first == UInt8(ascii: "#") else { return false }
        rest = rest.dropFirst()
        let afterDigits = rest.drop { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
        return afterDigits.count < rest.count && afterDigits.first == UInt8(ascii: ":")
    }
}

// MARK: - The rewrite

extension SubPage {
    /// The same text, unit for unit (no Unicode normalization).
    static func same(_ a: String, _ b: String) -> Bool {
        a.utf8.elementsEqual(b.utf8)
    }

    /// Dart's `startsWith`: by code units, where `hasPrefix` normalizes.
    static func starts(_ text: String, with prefix: String) -> Bool {
        text.utf8.starts(with: prefix.utf8)
    }

    private static func isPage(_ scope: JSONValue) -> Bool {
        scope.isNull || scope.stringValue.map { same($0, "page") } ?? false
    }

    /// Props that name a page-state key or a node of the page as a plain string.
    private static let nodeProps: Set<String> = ["animationId", "stateKey"]

    /// Actions whose `key` is a state key in `scope`.
    private static let stateActions: Set<String> = ["setState", "clearState", "persistState"]

    /// Per action kind, the field that holds the id of a node of the page.
    private static let idFields: [String: String] = [
        "openDialog": "dialogId",
        "animateForward": "animationId",
        "animateReverse": "animationId",
        "updateComponent": "id",
        "deleteComponent": "id",
        "addComponent": "parentId",
        "replaceComponent": "targetId",
        "updateSubPage": "subPageId",
    ]

    /// One node. A value that is not an object is left as it is.
    private static func node(_ prefix: String, _ node: JSONValue) -> JSONValue {
        guard case .object(var out) = node else { return node }
        let children = (out["children"]?.arrayValue ?? []).compactMap(\.stringValue)
        if let id = out["id"]?.stringValue { out["id"] = .string(prefix + id) }
        if let entries = out["children"]?.arrayValue {
            out["children"] = .array(entries.map { $0.stringValue.map { .string(prefix + $0) } ?? $0 })
        }
        let nodeProps = out["props"]?.objectValue
        if let nodeProps { out["props"] = .object(props(prefix, nodeProps, children: children)) }

        if let watches = out["watches"]?.arrayValue {
            var pageKeys = Set<[UInt8]>()
            var appKeys = Set<[UInt8]>()
            if let nodeProps { refs(.object(nodeProps), &pageKeys, &appKeys) }
            var rewritten: [JSONValue] = []
            for watch in watches {
                guard let key = watch.stringValue, pageKeys.contains(Array(key.utf8)) else {
                    rewritten.append(watch)
                    continue
                }
                rewritten.append(.string(prefix + key))
                if appKeys.contains(Array(key.utf8)) { rewritten.append(watch) }
            }
            out["watches"] = .array(rewritten)
        }
        if let actions = out["actions"] { out["actions"] = walk(prefix, actions, actions: true) }
        return .object(out)
    }

    /// A props map: a string that is one of the node's `children` is a slot,
    /// the strings of `nodeProps` name a key or a node; everything else is
    /// walked.
    private static func props(_ prefix: String, _ props: [String: JSONValue], children: [String])
        -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for (key, value) in props {
            if case .string(let s) = value, nodeProps.contains(key) || children.contains(where: { same($0, s) }) {
                out[key] = .string(prefix + s)
            } else {
                out[key] = walk(prefix, value, actions: false)
            }
        }
        return out
    }

    /// A static Value is data, whatever it holds and with or without a `value`.
    private static func isStatic(_ map: [String: JSONValue]) -> Bool {
        map["type"]?.stringValue.map { same($0, "static") } ?? false
    }

    /// Deep copy of `value` with every page-state reference and every targeted
    /// tween rewritten; with `actions`, the action fields too.
    private static func walk(_ prefix: String, _ value: JSONValue, actions: Bool) -> JSONValue {
        if case .array(let items) = value { return .array(items.map { walk(prefix, $0, actions: actions) }) }
        guard case .object(let map) = value else { return value }
        if isStatic(map) { return value }

        // A type outside ASCII matches none of the names below.
        let type = map["type"]?.stringValue ?? ""
        var out: [String: JSONValue] = [:]
        for (key, v) in map {
            if actions, type == "updateComponent", key == "props", case .object(let newProps) = v {
                out[key] = .object(props(prefix, newProps, children: []))
            } else if actions, type == "addComponent" || type == "replaceComponent", key == "components",
                case .array(let nodes) = v {
                out[key] = .array(nodes.map { node(prefix, $0) })
            } else {
                out[key] = walk(prefix, v, actions: actions)
            }
        }

        func put(_ field: String) {
            if case .string(let s)? = out[field] { out[field] = .string(prefix + s) }
        }

        let pageScoped = isPage(map["scope"] ?? .null)
        if type == "state", pageScoped { put("key") }
        if type == "tween" || type == "tweenSequence" { put("animationId") }
        if actions {
            if stateActions.contains(type), pageScoped { put("key") }
            if let idField = idFields[type] { put(idField) }
        }
        return .object(out)
    }

    /// Collects the keys of the state references under `value`, by scope.
    private static func refs(_ value: JSONValue, _ pageKeys: inout Set<[UInt8]>, _ appKeys: inout Set<[UInt8]>) {
        switch value {
        case .array(let items):
            for item in items { refs(item, &pageKeys, &appKeys) }
        case .object(let map) where !isStatic(map):
            if map["type"]?.stringValue == "state", let key = map["key"]?.stringValue {
                if isPage(map["scope"] ?? .null) {
                    pageKeys.insert(Array(key.utf8))
                } else {
                    appKeys.insert(Array(key.utf8))
                }
            }
            for item in map.values { refs(item, &pageKeys, &appKeys) }
        default:
            break
        }
    }
}

// MARK: - The query string

extension SubPage {
    private static let slash = UInt8(ascii: "/")

    /// Code point order, which is the order of the UTF-8 bytes.
    private static func byCodePoint(_ a: String, _ b: String) -> Bool {
        a.utf8.lexicographicallyPrecedes(b.utf8)
    }

    private static let unreserved = Set(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)
    private static let hex = Array("0123456789ABCDEF".utf8)

    /// RFC 3986 percent-encoding of everything but the unreserved characters.
    private static func percent(_ bytes: some Sequence<UInt8>) -> String {
        var out: [UInt8] = []
        for byte in bytes {
            if unreserved.contains(byte) {
                out.append(byte)
            } else {
                out += [UInt8(ascii: "%"), hex[Int(byte >> 4)], hex[Int(byte & 0x0F)]]
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// A resolved param as text: a string as it is, a list or a map as JSON.
    private static func text(_ value: JSONValue) -> String {
        if case .string(let s) = value { return s }
        return json(value)
    }

    /// 2^53: up to it, either way, every whole number is exact in a double.
    private static let maxWhole = 9007199254740992.0

    /// A whole number up to 2^53 as its digits, however it was spelt (`3.0`,
    /// `1e3`, `-0.0`); any other number as Dart prints it, which is the
    /// shortest plain decimal that reads back the same from 0.0001 up to 2^53.
    /// Outside that the forms differ between platforms and the contract pins
    /// none.
    private static func number(_ d: Double) -> String {
        d == d.rounded(.towardZero) && abs(d) <= maxWhole ? String(Int(d)) : DartFormat.double(d)
    }

    /// Compact JSON with sorted keys, the same on every platform.
    private static func json(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return number(d)
        case .string(let s): return quoted(s)
        case .array(let items): return "[" + items.map(json).joined(separator: ",") + "]"
        case .object(let map):
            let members = map.keys.sorted(by: byCodePoint).map { "\(quoted($0)):\(json(map[$0] ?? .null))" }
            return "{" + members.joined(separator: ",") + "}"
        }
    }

    /// A JSON string: only the quote, the backslash and the control
    /// characters are escaped.
    private static func quoted(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x22: out += "\\\""
            case 0x5C: out += "\\\\"
            case 0x08: out += "\\b"
            case 0x0C: out += "\\f"
            case 0x0A: out += "\\n"
            case 0x0D: out += "\\r"
            case 0x09: out += "\\t"
            case 0..<0x20:
                let digits = String(scalar.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - digits.count) + digits
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }
}
