import Foundation

/// The pages mounted in the SubPages of one host page, by the id of each
/// SubPage node (nested ones included: their id carries the prefix of the
/// page they are in). Pure: the UI layer fetches, hands the response to
/// `mount` and applies the change it gets to the node store
/// (`PageRenderer.apply`) and the page state (`StoreState.applying`).
public struct SubPageRegistry: Sendable, Equatable {
    private var mounts: [String: SubPageMounts] = [:]

    public init() {}

    /// The pages mounted in the SubPage `key`; nil when it has none.
    public subscript(key: String) -> SubPageMounts? { mounts[key] }

    /// Prefix of every mounted page, by SubPage id then oldest first: what
    /// `SubPage.prefixOf` is asked with.
    public var prefixes: [String] {
        mounts.keys.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }.flatMap { mounts[$0]?.prefixes ?? [] }
    }

    /// Mounts a fetched `response` in the SubPage `key` (see
    /// `SubPageMounts.apply`; the first load is a `replace`) and gives the
    /// change to apply to the host page.
    public mutating func mount(
        _ key: String, mode: String, response: JSONValue, pageStateKeys: some Sequence<String>
    ) -> SubPageChange {
        var pages = mounts[key] ?? SubPageMounts(subPageKey: key)
        let change = pages.apply(mode: mode, response: response, pageStateKeys: pageStateKeys)
        mounts[key] = pages
        return change
    }

    /// The SubPage `key` left the page: forgets its pages and gives the ids
    /// of their nodes, to take out of the node store. Its state keys stay.
    public mutating func unmount(_ key: String) -> [String] {
        mounts.removeValue(forKey: key)?.nodeIds ?? []
    }
}

extension PageRenderer {
    /// Applies a sub-page change to the node map: the removed nodes go, the
    /// new ones come in. They hang under no parent; the SubPage draws them
    /// from their root. Throws, changing nothing, when a node does not decode.
    public mutating func apply(_ change: SubPageChange) throws {
        let added = try change.nodes.map { try $0.decode(ComponentNode.self) }
        removeNodes(change.removedNodeIds)
        for node in added { nodes[node.id] = node }
    }

    /// Takes the nodes with these ids out of the node map, and only them.
    public mutating func removeNodes(_ ids: some Sequence<String>) {
        for id in ids { nodes[id] = nil }
    }
}

extension StoreState {
    /// The state after a sub-page change: the removed page-state keys gone,
    /// then the seeds written. The app scope is left alone.
    public func applying(_ change: SubPageChange) -> StoreState {
        var next = self
        for key in change.removedStateKeys { next.page[key] = nil }
        next.page.merge(change.seeds) { _, seed in seed }
        return next
    }
}
