package com.orcagateway.core.models

import com.orcagateway.core.json.JsonValue
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException

/**
 * One node of the flat component array the engine's encoder emits
 * (schema/component-node.schema.json). The root comes first; [children] are
 * ids of other nodes; [watches] lists the state keys whose change must
 * re-render this node.
 */
@Serializable(with = ComponentNodeSerializer::class)
public data class ComponentNode(
    public val id: String,
    public val type: String,
    public val kind: Kind,
    public val childMode: ChildMode,
    /** Plain JSON with Values anywhere inside; resolve with `ValueResolver`. */
    public val props: Map<String, JsonValue> = emptyMap(),
    public val children: List<String> = emptyList(),
    public val watches: List<String> = emptyList(),
    /** Trigger name (`onTap`, `onChange`, ...) to action. */
    public val actions: Map<String, Action>? = null,
) {
    public enum class Kind(public val wire: String) {
        Layout("layout"),
        Primitive("primitive"),
        Input("input"),
        Button("button"),
        Structure("structure"),
        ;

        public companion object {
            public fun fromWire(wire: String): Kind? = entries.firstOrNull { it.wire == wire }
        }
    }

    public enum class ChildMode(public val wire: String) {
        Single("single"),
        Multi("multi"),
        None("none"),
        ;

        public companion object {
            public fun fromWire(wire: String): ChildMode? = entries.firstOrNull { it.wire == wire }
        }
    }
}

/** An initial state declaration from `Page.getState()`. */
@Serializable(with = StateDefinitionSerializer::class)
public data class StateDefinition(
    public val key: String,
    public val scope: StateScope,
    /** Required by the schema, but may be JSON null. */
    public val initial: JsonValue,
)

/**
 * Body of `GET /api/v1/app/:appId/page/:path` (schema/page-response.schema.json).
 * Members beyond the four required ones (capability banners, sub-page data,
 * `_debug` and friends) are kept in [extra] and written back on encode.
 */
@Serializable(with = PageResponseSerializer::class)
public data class PageResponse(
    public val pageId: String,
    public val title: String,
    public val state: List<StateDefinition> = emptyList(),
    public val components: List<ComponentNode> = emptyList(),
    public val extra: Map<String, JsonValue> = emptyMap(),
) {
    /** Nodes keyed by id (the first node wins a duplicate id), for child lookups. */
    public val nodesById: Map<String, ComponentNode>
        get() {
            val out = LinkedHashMap<String, ComponentNode>()
            for (node in components) out.putIfAbsent(node.id, node)
            return out
        }
}

// MARK: - Serializers

internal object ComponentNodeSerializer : JsonTreeSerializer<ComponentNode>("com.orcagateway.core.models.ComponentNode") {
    override fun fromTree(tree: JsonValue): ComponentNode {
        val f = Fields.of(tree, "ComponentNode")
        val kind = f.string("kind")
        val childMode = f.string("childMode")
        return ComponentNode(
            id = f.string("id"),
            type = f.string("type"),
            kind = ComponentNode.Kind.fromWire(kind)
                ?: throw SerializationException("Cannot initialize Kind from invalid value $kind"),
            childMode = ComponentNode.ChildMode.fromWire(childMode)
                ?: throw SerializationException("Cannot initialize ChildMode from invalid value $childMode"),
            props = f.obj("props"),
            children = f.strings("children"),
            watches = f.strings("watches"),
            actions = f.mapOrNull("actions", ActionSerializer::fromTree),
        )
    }

    override fun toTree(value: ComponentNode): JsonValue = tree {
        put("id", value.id)
        put("type", value.type)
        put("kind", value.kind.wire)
        put("childMode", value.childMode.wire)
        put("props", JsonValue.Object(value.props))
        put("children", JsonValue.Array(value.children.map { JsonValue.String(it) }))
        put("watches", JsonValue.Array(value.watches.map { JsonValue.String(it) }))
        value.actions?.let { actions -> put("actions", JsonValue.Object(actions.mapValues { ActionSerializer.toTree(it.value) })) }
    }
}

internal object StateDefinitionSerializer : JsonTreeSerializer<StateDefinition>("com.orcagateway.core.models.StateDefinition") {
    override fun fromTree(tree: JsonValue): StateDefinition {
        val f = Fields.of(tree, "StateDefinition")
        return StateDefinition(f.string("key"), f.decode("scope", ::scopeFromTree), f.jsonOrNull("initial") ?: JsonValue.Null)
    }

    override fun toTree(value: StateDefinition): JsonValue = tree {
        put("key", value.key)
        put("scope", value.scope.wire)
        put("initial", value.initial)
    }
}

internal object PageResponseSerializer : JsonTreeSerializer<PageResponse>("com.orcagateway.core.models.PageResponse") {
    private val known = setOf("pageId", "title", "state", "components")

    override fun fromTree(tree: JsonValue): PageResponse {
        val f = Fields.of(tree, "PageResponse")
        return PageResponse(
            pageId = f.string("pageId"),
            title = f.string("title"),
            state = f.list("state", StateDefinitionSerializer::fromTree),
            components = f.list("components", ComponentNodeSerializer::fromTree),
            extra = tree.objectValue.orEmpty().filterKeys { it !in known },
        )
    }

    override fun toTree(value: PageResponse): JsonValue = tree {
        for ((key, extra) in value.extra) if (key !in known) put(key, extra)
        put("pageId", value.pageId)
        put("title", value.title)
        put("state", JsonValue.Array(value.state.map(StateDefinitionSerializer::toTree)))
        put("components", JsonValue.Array(value.components.map(ComponentNodeSerializer::toTree)))
    }
}
