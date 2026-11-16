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
    /// change to apply to the host page. A replace takes the old pages out
    /// whole (`SubPageChange.removedPrefixes`): a SubPage that was in one of
    /// them is forgotten here.
    public mutating func mount(
        _ key: String, mode: String, response: JSONValue, pageStateKeys: some Sequence<String>
    ) -> SubPageChange {
        var pages = mounts[key] ?? SubPageMounts(subPageKey: key)
        let change = pages.apply(mode: mode, response: response, pageStateKeys: pageStateKeys)
        forget(under: change.removedPrefixes)
        mounts[key] = pages
        return change
    }

    /// The SubPage `key` left the page: forgets its pages, and the SubPages
    /// that were in them, and gives the prefixes of all those pages, to take
    /// out of the node store (`PageRenderer.removePages`). Its state keys stay.
    public mutating func unmount(_ key: String) -> [String] {
        guard let own = mounts.removeValue(forKey: key)?.prefixes else { return [] }
        return own + forget(under: own)
    }

    /// Forgets every SubPage whose node is in a page mounted under one of
    /// `prefixes`; gives the prefixes of the pages they had.
    @discardableResult
    private mutating func forget(under prefixes: [String]) -> [String] {
        var gone: [String] = []
        for key in mounts.keys.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) })
        where prefixes.contains(where: { SubPage.starts(key, with: $0) }) {
            gone += mounts.removeValue(forKey: key)?.prefixes ?? []
        }
        return gone
    }
}

extension PageRenderer {
    /// Applies a sub-page change to the node map: the pages that leave go
    /// whole, the new nodes come in. They hang under no parent; the SubPage
    /// draws them from their root. Throws, changing nothing, when a node does
    /// not decode.
    public mutating func apply(_ change: SubPageChange) throws {
        let added = try change.nodes.map { try $0.decode(ComponentNode.self) }
        removePages(under: change.removedPrefixes)
        for node in added { nodes[node.id] = node }
    }

    /// Takes the pages mounted under `prefixes` out of the node map: every
    /// node whose id starts with one of them, so the nodes added to a page
    /// since its mount (addComponent) and the pages of a SubPage inside it
    /// go too.
    public mutating func removePages(under prefixes: [String]) {
        guard !prefixes.isEmpty else { return }
        nodes = nodes.filter { id, _ in !prefixes.contains { SubPage.starts(id, with: $0) } }
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
