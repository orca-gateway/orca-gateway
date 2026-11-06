import Foundation

/// Which widget types this build draws, and what happens to the rest.
///
/// Mirrors the Flutter `ComponentRenderer`: an unknown type never throws. It
/// is reported once per type per process and drawn as a `FallbackPrompt` with
/// the Flutter wording and the `warn` severity
/// (sdk/lib/src/rendering/component_renderer.dart:149-190). If the build
/// cannot draw a FallbackPrompt either, the node draws nothing.
public final class WidgetRegistry: @unchecked Sendable {
    public let types: Set<String>
    private let lock = NSLock()
    private var reported: Set<String> = []
    /// Called once per unknown type (Flutter's `unknown_widget_type` event).
    public var onUnknownType: ((String) -> Void)?

    public init(types: Set<String> = Set(GeneratedCapabilities.widgets),
                onUnknownType: ((String) -> Void)? = nil) {
        self.types = types
        self.onUnknownType = onUnknownType
    }

    /// The registry the SDK draws with: the widgets the caps vector advertises.
    public static let shared = WidgetRegistry()

    public func supports(_ type: String) -> Bool { types.contains(type) }

    /// Report an unknown type; true the first time it is seen.
    @discardableResult
    public func reportUnknown(_ type: String) -> Bool {
        lock.lock()
        let first = reported.insert(type).inserted
        lock.unlock()
        if first { onUnknownType?(type) }
        return first
    }

    /// Unknown types seen so far.
    public var reportedTypes: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return reported
    }

    /// Forget what was reported (tests, or a new session).
    public func resetReported() {
        lock.lock()
        reported = []
        lock.unlock()
    }

    /// What the renderer draws instead of a node of an unknown type.
    func degraded(_ node: ComponentNode) -> ComponentNode {
        reportUnknown(node.type)
        guard supports("FallbackPrompt") else {
            return ComponentNode(id: node.id, type: Self.emptyType, kind: .primitive, childMode: .none)
        }
        let body = "This screen includes a \"\(node.type)\" component that this app version "
            + "cannot display. Please update to the latest version for the full experience."
        return ComponentNode(
            id: node.id, type: "FallbackPrompt", kind: .primitive, childMode: .none,
            props: ["title": "Unsupported content", "body": .string(body), "severity": "warn"],
            actions: node.actions)
    }

    /// Type of a node that draws nothing (an unknown type with no fallback).
    public static let emptyType = "_Empty"
}

/// A node ready to draw against one state: props resolved, children and
/// slots as ids. The SwiftUI layer asks for one of these per node, so only
/// nodes whose watched keys changed are resolved again.
public struct ResolvedNode: Equatable, Sendable {
    public var id: String
    public var type: String
    public var kind: ComponentNode.Kind
    public var props: [String: JSONValue]
    /// Children of a single or multi child node, in order.
    public var childIds: [String]
    /// Named slots of a structure node (`appBar`, `body`, `title`,
    /// `action_0`, ...), as node ids.
    public var slots: [String: String]
    public var actions: [String: Action]
    public var watches: [String]
    /// The wire type when the node was degraded to a FallbackPrompt.
    public var degradedFrom: String?

    /// A resolved prop, or nil when absent or null.
    public subscript(prop: String) -> JSONValue? {
        guard let value = props[prop], !value.isNull else { return nil }
        return value
    }
}

/// A node with everything below it resolved: what tests walk instead of
/// tapping through SwiftUI.
public struct RenderNode: Equatable, Sendable {
    public var node: ResolvedNode
    public var children: [RenderNode]
    public var slots: [String: RenderNode]

    public var id: String { node.id }
    public var type: String { node.type }
    public var props: [String: JSONValue] { node.props }

    /// This node and every node below it, children before slots, slots in
    /// name order.
    public var all: [RenderNode] {
        [self] + children.flatMap(\.all)
            + slots.keys.sorted().compactMap { slots[$0] }.flatMap(\.all)
    }

    /// The first node below (or at) this one that matches.
    public func first(where match: (RenderNode) -> Bool) -> RenderNode? {
        all.first(where: match)
    }
}

/// Turns a page's flat node list into resolved nodes, the Swift side of the
/// Flutter `ComponentRenderer`: the first node is the root, `children` are ids,
/// a structure node's slots are props holding node ids, and props are
/// resolved deep against the merged state.
public struct PageRenderer: Sendable {
    public let page: PageResponse
    public let registry: WidgetRegistry
    private let nodes: [String: ComponentNode]

    public init(page: PageResponse, registry: WidgetRegistry = .shared) {
        self.page = page
        self.registry = registry
        self.nodes = page.nodesById
    }

    public var rootId: String? { page.components.first?.id }

    /// The node to draw for an id: degraded when its type is unknown, nil
    /// when the page has no such node.
    public func node(_ id: String) -> ComponentNode? {
        guard let node = nodes[id] else { return nil }
        return registry.supports(node.type) ? node : registry.degraded(node)
    }

    public func resolve(_ id: String, state: StoreState,
                        eventData: [String: JSONValue]? = nil) -> ResolvedNode? {
        guard let source = nodes[id], let node = node(id) else { return nil }
        let resolver = state.resolver(eventData: eventData)
        var props: [String: JSONValue] = [:]
        for (key, value) in node.props { props[key] = resolver.resolveDeep(value) }

        var childIds: [String] = []
        var slots: [String: String] = [:]
        if node.childMode == .none {
            // The encoder lists every slot widget in `children` and names it
            // with a prop holding its id; that pairing is what marks a slot.
            let ids = Set(node.children)
            for (key, value) in node.props {
                if case .string(let ref) = value, ids.contains(ref) { slots[key] = ref }
            }
        } else {
            childIds = node.children.filter { nodes[$0] != nil }
        }
        return ResolvedNode(
            id: node.id, type: node.type, kind: node.kind, props: props, childIds: childIds,
            slots: slots, actions: node.actions ?? [:], watches: node.watches,
            degradedFrom: node.type == source.type ? nil : source.type)
    }

    /// The whole tree under the root (or under `id`), resolved against one
    /// state. A missing child id is skipped.
    public func tree(state: StoreState, from id: String? = nil) -> RenderNode? {
        guard let start = id ?? rootId else { return nil }
        var visiting: Set<String> = []
        func build(_ id: String) -> RenderNode? {
            guard !visiting.contains(id), let resolved = resolve(id, state: state) else { return nil }
            visiting.insert(id)
            defer { visiting.remove(id) }
            var slots: [String: RenderNode] = [:]
            for (name, ref) in resolved.slots { slots[name] = build(ref) }
            return RenderNode(node: resolved, children: resolved.childIds.compactMap(build), slots: slots)
        }
        return build(start)
    }
}
