import Foundation

/// One node of the flat component array the engine's encoder emits
/// (schema/component-node.schema.json). The root comes first; `children` are
/// ids of other nodes; `watches` lists the state keys whose change must
/// re-render this node.
public struct ComponentNode: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case layout, primitive, input, button, structure
    }

    public enum ChildMode: String, Codable, Sendable, CaseIterable {
        case single, multi, none
    }

    public var id: String
    public var type: String
    public var kind: Kind
    public var childMode: ChildMode
    /// Plain JSON with Values anywhere inside; resolve with `ValueResolver`.
    public var props: [String: JSONValue]
    public var children: [String]
    public var watches: [String]
    /// Trigger name (`onTap`, `onChange`, ...) to action.
    public var actions: [String: Action]?

    public init(id: String, type: String, kind: Kind, childMode: ChildMode,
                props: [String: JSONValue] = [:], children: [String] = [],
                watches: [String] = [], actions: [String: Action]? = nil) {
        self.id = id
        self.type = type
        self.kind = kind
        self.childMode = childMode
        self.props = props
        self.children = children
        self.watches = watches
        self.actions = actions
    }
}

/// An initial state declaration from `Page.getState()`.
public struct StateDefinition: Codable, Equatable, Sendable {
    public var key: String
    public var scope: StateScope
    public var initial: JSONValue

    public init(key: String, scope: StateScope, initial: JSONValue) {
        self.key = key
        self.scope = scope
        self.initial = initial
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        scope = try c.decode(StateScope.self, forKey: .scope)
        // `initial` is required by the schema but may be JSON null.
        initial = try c.decodeIfPresent(JSONValue.self, forKey: .initial) ?? .null
    }
}

/// Body of `GET /api/v1/app/:appId/page/:path` (schema/page-response.schema.json).
/// Members beyond the four required ones (capability banners, sub-page data,
/// `_debug` and friends) are kept in `extra` and written back on encode.
public struct PageResponse: Codable, Equatable, Sendable {
    public var pageId: String
    public var title: String
    public var state: [StateDefinition]
    public var components: [ComponentNode]
    public var extra: [String: JSONValue]

    public init(pageId: String, title: String, state: [StateDefinition] = [],
                components: [ComponentNode] = [], extra: [String: JSONValue] = [:]) {
        self.pageId = pageId
        self.title = title
        self.state = state
        self.components = components
        self.extra = extra
    }

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    private static let known: Set<String> = ["pageId", "title", "state", "components"]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        pageId = try c.decode(String.self, forKey: AnyKey("pageId"))
        title = try c.decode(String.self, forKey: AnyKey("title"))
        state = try c.decode([StateDefinition].self, forKey: AnyKey("state"))
        components = try c.decode([ComponentNode].self, forKey: AnyKey("components"))
        var extra: [String: JSONValue] = [:]
        for key in c.allKeys where !Self.known.contains(key.stringValue) {
            extra[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
        self.extra = extra
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        for (key, value) in extra where !Self.known.contains(key) {
            try c.encode(value, forKey: AnyKey(key))
        }
        try c.encode(pageId, forKey: AnyKey("pageId"))
        try c.encode(title, forKey: AnyKey("title"))
        try c.encode(state, forKey: AnyKey("state"))
        try c.encode(components, forKey: AnyKey("components"))
    }

    /// Nodes keyed by id, for the renderer's child lookups.
    public var nodesById: [String: ComponentNode] {
        Dictionary(components.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
