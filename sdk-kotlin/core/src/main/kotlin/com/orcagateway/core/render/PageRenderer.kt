package com.orcagateway.core.render

import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.SwiftText
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.state.StoreState

/**
 * Which widget types this build draws, and what happens to the rest.
 *
 * Mirrors the Flutter `ComponentRenderer`: an unknown type never throws. It
 * is reported once per type per registry and drawn as a `FallbackPrompt`
 * with the Flutter wording and the `warn` severity
 * (sdk/lib/src/rendering/component_renderer.dart:149-190). If the build
 * cannot draw a FallbackPrompt either, the node draws nothing. Thread-safe.
 */
public class WidgetRegistry(
    public val types: Set<String> = GeneratedCapabilities.widgets.toSet(),
    /** Called once per unknown type (Flutter's `unknown_widget_type` event). */
    @Volatile public var onUnknownType: ((String) -> Unit)? = null,
) {
    private val lock = Any()
    private val reported = LinkedHashSet<String>()

    public fun supports(type: String): Boolean = type in types

    /** Report an unknown type; true the first time it is seen. */
    public fun reportUnknown(type: String): Boolean {
        val first = synchronized(lock) { reported.add(type) }
        if (first) onUnknownType?.invoke(type)
        return first
    }

    /** Unknown types seen so far. */
    public val reportedTypes: Set<String> get() = synchronized(lock) { reported.toSet() }

    /** Forget what was reported (tests, or a new session). */
    public fun resetReported() {
        synchronized(lock) { reported.clear() }
    }

    /** What the renderer draws instead of a node of an unknown type. */
    internal fun degraded(node: ComponentNode): ComponentNode {
        reportUnknown(node.type)
        if (!supports("FallbackPrompt")) {
            return ComponentNode(node.id, emptyType, ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None)
        }
        // DevTools reporting arrives with the adapters slice (S8).
        val body = "This screen includes a \"${node.type}\" component that this app version " +
            "cannot display. Please update to the latest version for the full experience."
        return ComponentNode(
            id = node.id, type = "FallbackPrompt", kind = ComponentNode.Kind.Primitive,
            childMode = ComponentNode.ChildMode.None,
            props = mapOf(
                "title" to JsonValue.String("Unsupported content"),
                "body" to JsonValue.String(body),
                "severity" to JsonValue.String("warn"),
            ),
            actions = node.actions,
        )
    }

    public companion object {
        /** The registry the SDK draws with: the widgets the caps vector advertises. */
        public val shared: WidgetRegistry = WidgetRegistry()

        /** Type of a node that draws nothing (an unknown type with no fallback). */
        public const val emptyType: String = "_Empty"
    }
}

/**
 * A node ready to draw against one state: props resolved, children and
 * slots as ids. The UI layer asks for one of these per node, so only nodes
 * whose watched keys changed are resolved again.
 */
public data class ResolvedNode(
    public val id: String,
    public val type: String,
    public val kind: ComponentNode.Kind,
    public val props: Map<String, JsonValue>,
    /** Children of a single or multi child node, in order. */
    public val childIds: List<String>,
    /**
     * Named slots of a structure node (`appBar`, `body`, `title`,
     * `action_0`, ...), as node ids.
     */
    public val slots: Map<String, String>,
    public val actions: Map<String, Action>,
    public val watches: List<String>,
    /** The wire type when the node was degraded to a FallbackPrompt. */
    public val degradedFrom: String? = null,
) {
    /** A resolved prop, or null when absent or JSON null. */
    public operator fun get(prop: String): JsonValue? = props[prop]?.takeUnless { it.isNull }
}

/** A node with everything below it resolved: what tests walk instead of the UI. */
public data class RenderNode(
    public val node: ResolvedNode,
    public val children: List<RenderNode>,
    public val slots: Map<String, RenderNode>,
) {
    public val id: String get() = node.id
    public val type: String get() = node.type
    public val props: Map<String, JsonValue> get() = node.props

    /**
     * This node and every node below it, children before slots, slots in
     * name order.
     */
    public val all: List<RenderNode>
        get() = listOf(this) + children.flatMap { it.all } +
            slots.keys.sortedWith(SwiftText.stringOrder).mapNotNull { slots[it] }.flatMap { it.all }

    /** The first node below (or at) this one that matches. */
    public fun first(match: (RenderNode) -> Boolean): RenderNode? = all.firstOrNull(match)
}

/**
 * Turns a page's flat node list into resolved nodes, the Kotlin side of the
 * Flutter `ComponentRenderer`: the first node is the root, `children` are
 * ids, a structure node's slots are props holding node ids, and props are
 * resolved deep against the merged state.
 *
 * Server-action mutations change [nodes] in place (`apply`); [page] keeps
 * what the server sent. Not thread-safe.
 */
public class PageRenderer(
    /** The page as the server sent it; mutations change [nodes], not this. */
    public val page: PageResponse,
    public val registry: WidgetRegistry = WidgetRegistry.shared,
) {
    /** The current node map, as the Flutter `ComponentStore` holds it (a snapshot). */
    public var nodes: Map<String, ComponentNode> = page.nodesById
        internal set

    public var rootId: String? = page.components.firstOrNull()?.id
        internal set

    /**
     * Apply one server-action mutation the way the Flutter `ComponentStore`
     * does (see [ComponentMutation]).
     */
    public fun apply(mutation: ComponentMutation) {
        applyMutation(mutation)
    }

    /**
     * The node to draw for an id: degraded when its type is unknown, null
     * when the page has no such node.
     */
    public fun node(id: String): ComponentNode? {
        val node = nodes[id] ?: return null
        return if (registry.supports(node.type)) node else registry.degraded(node)
    }

    public fun resolve(id: String, state: StoreState, eventData: Map<String, JsonValue>? = null): ResolvedNode? {
        val source = nodes[id] ?: return null
        val node = node(id) ?: return null
        val resolver = state.resolver(eventData)
        val props = node.props.mapValues { resolver.resolveDeep(it.value) }

        var childIds: List<String> = emptyList()
        val slots = LinkedHashMap<String, String>()
        if (node.childMode == ComponentNode.ChildMode.None) {
            // The encoder lists every slot widget in `children` and names it
            // with a prop holding its id; that pairing is what marks a slot.
            val ids = node.children.toSet()
            for ((key, value) in node.props) {
                if (value is JsonValue.String && value.value in ids) slots[key] = value.value
            }
        } else {
            childIds = node.children.filter { it in nodes }
        }
        return ResolvedNode(
            id = node.id, type = node.type, kind = node.kind, props = props, childIds = childIds,
            slots = slots, actions = node.actions ?: emptyMap(), watches = node.watches,
            degradedFrom = if (node.type == source.type) null else source.type,
        )
    }

    /**
     * The whole tree under the root (or under [from]), resolved against one
     * state. A missing child id, or one already on the path (a cycle), is
     * skipped.
     */
    public fun tree(state: StoreState, from: String? = null): RenderNode? {
        val start = from ?: rootId ?: return null
        val visiting = HashSet<String>()
        fun build(id: String): RenderNode? {
            if (id in visiting) return null
            val resolved = resolve(id, state) ?: return null
            visiting.add(id)
            try {
                val slots = LinkedHashMap<String, RenderNode>()
                for ((name, ref) in resolved.slots) build(ref)?.let { slots[name] = it }
                return RenderNode(resolved, resolved.childIds.mapNotNull(::build), slots)
            } finally {
                visiting.remove(id)
            }
        }
        return build(start)
    }
}
