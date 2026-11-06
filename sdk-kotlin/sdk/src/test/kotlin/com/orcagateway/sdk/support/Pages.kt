package com.orcagateway.sdk.support

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import kotlinx.serialization.json.Json
import java.io.File

/** sdk-kotlin/ in the monorepo (the test task sets `orca.repoRoot`). */
val kotlinRoot: File
    get() = File(requireNotNull(System.getProperty("orca.repoRoot")) { "orca.repoRoot is not set" }, "sdk-kotlin")

/** A page recorded from the engine, from `src/test/resources/pages/<name>.json`. */
fun recordedPage(name: String): PageResponse {
    val text = requireNotNull(object {}.javaClass.getResource("/pages/$name.json")) { "no page $name" }.readText()
    return Json.decodeFromString(PageResponse.serializer(), text)
}

/** A page from nodes, the first one the root. */
fun page(vararg nodes: ComponentNode, state: List<StateDefinition> = emptyList()): PageResponse =
    PageResponse(pageId = "p", title = "P", state = state, components = nodes.toList())

fun column(id: String, vararg children: String, props: Map<String, JsonValue> = emptyMap()): ComponentNode =
    ComponentNode(id, "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, props, children.toList())

fun row(id: String, vararg children: String, props: Map<String, JsonValue> = emptyMap()): ComponentNode =
    ComponentNode(id, "Row", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, props, children.toList())

fun text(id: String, data: String, props: Map<String, JsonValue> = emptyMap()): ComponentNode =
    ComponentNode(
        id, "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
        props + ("data" to JsonValue.String(data)),
    )

fun leaf(id: String, type: String, props: Map<String, JsonValue> = emptyMap()): ComponentNode =
    ComponentNode(id, type, ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, props)

fun sizedBox(id: String, width: Int? = null, height: Int? = null): ComponentNode {
    val props = LinkedHashMap<String, JsonValue>()
    width?.let { props["width"] = JsonValue.Int(it.toLong()) }
    height?.let { props["height"] = JsonValue.Int(it.toLong()) }
    return ComponentNode(id, "SizedBox", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props)
}

fun button(
    id: String,
    type: String,
    child: String,
    actions: Map<String, Action>,
    props: Map<String, JsonValue> = emptyMap(),
): ComponentNode =
    ComponentNode(
        id, type, ComponentNode.Kind.Button, ComponentNode.ChildMode.Single, props, listOf(child),
        actions = actions,
    )
