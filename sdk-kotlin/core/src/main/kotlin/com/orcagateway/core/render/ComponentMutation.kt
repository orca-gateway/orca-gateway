package com.orcagateway.core.render

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.SwiftText
import com.orcagateway.core.models.ComponentNode

/**
 * A structural change to a page's node tree, sent by a server action
 * (engine/src/core/server-action.ts). The engine flattens a response widget
 * into `components` (root first, ids namespaced by `keyPrefix`) before it
 * reaches the client.
 */
public sealed class ComponentMutation {
    /** Shallow-merge props into one node. */
    public data class Update(public val id: String, public val props: Map<String, JsonValue>) : ComponentMutation()

    /** Remove a node and everything under it. */
    public data class Delete(public val id: String) : ComponentMutation()

    /** Insert a subtree under a parent, at [position] or at the end. */
    public data class Add(
        public val parentId: String,
        public val components: List<ComponentNode>,
        public val position: Long? = null,
    ) : ComponentMutation()

    /** Swap a node (and its subtree) for a new subtree, in the same place. */
    public data class Replace(public val targetId: String, public val components: List<ComponentNode>) : ComponentMutation()
}

/**
 * Apply one mutation the way the Flutter `ComponentStore` does
 * (sdk/lib/src/state/component_store.dart), including its edge cases: an
 * unknown id or an empty subtree changes nothing, a position past the end
 * appends, and replacing the root leaves the page without one. The node map
 * is replaced, never changed in place, so a map read before stays as it was.
 */
internal fun PageRenderer.applyMutation(mutation: ComponentMutation) {
    val map = LinkedHashMap(nodes)
    when (mutation) {
        is ComponentMutation.Update -> {
            val node = map[mutation.id] ?: return
            map[mutation.id] = node.copy(props = node.props + mutation.props)
        }

        is ComponentMutation.Delete -> {
            parentOf(map, mutation.id)?.let { parent ->
                map[parent]?.let { map[parent] = it.copy(children = it.children.filter { c -> c != mutation.id }) }
            }
            removeSubtree(map, mutation.id)
        }

        is ComponentMutation.Add -> {
            val root = mutation.components.firstOrNull() ?: return
            val parent = map[mutation.parentId] ?: return
            for (node in mutation.components) map[node.id] = node
            map[mutation.parentId] = parent.copy(children = inserting(root.id, parent.children, mutation.position))
        }

        is ComponentMutation.Replace -> {
            val root = mutation.components.firstOrNull() ?: return
            val parentId = parentOf(map, mutation.targetId)
            val position = parentId?.let { map[it]?.children?.indexOf(mutation.targetId)?.takeIf { i -> i >= 0 }?.toLong() }
            removeSubtree(map, mutation.targetId)
            if (mutation.targetId == rootId) rootId = null
            val parent = parentId?.let { map[it] }
            if (parentId == null || parent == null) {
                nodes = map
                return
            }
            for (node in mutation.components) map[node.id] = node
            val children = parent.children.filter { it != mutation.targetId }
            map[parentId] = parent.copy(children = inserting(root.id, children, position))
        }
    }
    nodes = map
}

/**
 * The first node that lists [id] as a child, searching from the root so the
 * answer does not depend on map order.
 */
private fun PageRenderer.parentOf(map: Map<String, ComponentNode>, id: String): String? {
    val seen = HashSet<String>()
    val queue = ArrayDeque<String>()
    rootId?.let { queue.addLast(it) }
    while (queue.isNotEmpty()) {
        val current = queue.removeFirst()
        if (!seen.add(current)) continue
        val node = map[current] ?: continue
        if (id in node.children) return current
        queue.addAll(node.children)
    }
    // Not reachable from the root: fall back to any node, in id order.
    return map.keys.sortedWith(SwiftText.stringOrder).firstOrNull { map[it]?.children?.contains(id) == true }
}

private fun removeSubtree(map: MutableMap<String, ComponentNode>, id: String) {
    val node = map.remove(id) ?: return
    for (child in node.children) removeSubtree(map, child)
}

private fun inserting(id: String, children: List<String>, position: Long?): List<String> {
    val out = children.toMutableList()
    if (position != null && position >= 0 && position <= out.size) out.add(position.toInt(), id) else out.add(id)
    return out
}
