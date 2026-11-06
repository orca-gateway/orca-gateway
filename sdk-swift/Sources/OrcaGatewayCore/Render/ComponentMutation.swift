import Foundation

/// A structural change to a page's node tree, sent by a server action
/// (engine/src/core/server-action.ts). The engine flattens a response widget
/// into `components` (root first, ids namespaced by `keyPrefix`) before it
/// reaches the client.
public enum ComponentMutation: Equatable, Sendable {
    /// Shallow-merge props into one node.
    case update(id: String, props: [String: JSONValue])
    /// Remove a node and everything under it.
    case delete(id: String)
    /// Insert a subtree under a parent, at `position` or at the end.
    case add(parentId: String, components: [ComponentNode], position: Int?)
    /// Swap a node (and its subtree) for a new subtree, in the same place.
    case replace(targetId: String, components: [ComponentNode])
}

extension PageRenderer {
    /// Apply one mutation the way the Flutter `ComponentStore` does
    /// (sdk/lib/src/state/component_store.dart), including its edge cases:
    /// an unknown id or an empty subtree changes nothing, a position past the
    /// end appends, and replacing the root leaves the page without one.
    public mutating func apply(_ mutation: ComponentMutation) {
        switch mutation {
        case .update(let id, let props):
            guard var node = nodes[id] else { return }
            node.props.merge(props) { _, new in new }
            nodes[id] = node

        case .delete(let id):
            if let parent = parentOf(id) {
                nodes[parent]?.children.removeAll { $0 == id }
            }
            removeSubtree(id)

        case .add(let parentId, let components, let position):
            guard let root = components.first, var parent = nodes[parentId] else { return }
            for node in components { nodes[node.id] = node }
            insert(root.id, into: &parent.children, at: position)
            nodes[parentId] = parent

        case .replace(let targetId, let components):
            guard let root = components.first else { return }
            let parentId = parentOf(targetId)
            let position = parentId.flatMap { nodes[$0]?.children.firstIndex(of: targetId) }
            removeSubtree(targetId)
            if targetId == rootId { rootId = nil }
            guard let parentId, var parent = nodes[parentId] else { return }
            for node in components { nodes[node.id] = node }
            parent.children.removeAll { $0 == targetId }
            insert(root.id, into: &parent.children, at: position)
            nodes[parentId] = parent
        }
    }

    /// The first node that lists `id` as a child, searching from the root so
    /// the answer does not depend on dictionary order.
    private func parentOf(_ id: String) -> String? {
        var seen: Set<String> = []
        var queue = rootId.map { [$0] } ?? []
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard seen.insert(current).inserted, let node = nodes[current] else { continue }
            if node.children.contains(id) { return current }
            queue += node.children
        }
        // Not reachable from the root: fall back to any node, in id order.
        return nodes.keys.sorted().first { nodes[$0]?.children.contains(id) == true }
    }

    private mutating func removeSubtree(_ id: String) {
        guard let node = nodes.removeValue(forKey: id) else { return }
        for child in node.children { removeSubtree(child) }
    }

    private func insert(_ id: String, into children: inout [String], at position: Int?) {
        if let position, position >= 0, position <= children.count {
            children.insert(id, at: position)
        } else {
            children.append(id)
        }
    }
}
