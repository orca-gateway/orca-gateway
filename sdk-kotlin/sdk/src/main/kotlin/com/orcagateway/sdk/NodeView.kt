package com.orcagateway.sdk

import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.orcagateway.core.render.ResolvedNode

/**
 * Draws one node of a page by id, and everything below it. Each node
 * observes only its own watched keys (and changes to the node tree); the
 * model itself is not observed here, so a toast appearing does not redraw
 * the page's nodes.
 *
 * [modifier] goes on the node's outermost layout: a parent uses it to force
 * a size, as a Flutter parent passes tight constraints.
 */
@Composable
public fun NodeView(id: String, model: OrcaPageModel, modifier: Modifier = Modifier) {
    val observer = remember(model, id) { NodeObserver(model, id) }
    // Reading the revision ties this node to its watches: the node is
    // resolved again only when one of them, or the tree, changed.
    val revision = observer.revision
    val node = remember(observer, revision) { model.resolve(id) } ?: return
    WidgetView(node, model, modifier)
}

/** The registry's builder for the node's type, or nothing (logged once per type). */
@Composable
internal fun WidgetView(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val builder = model.builders[node.type]
    if (builder == null) {
        val type = node.degradedFrom ?: node.type
        SideEffect { model.builders.reportMissing(type) }
        return
    }
    builder(node, model, modifier)
}

/** The first child, or nothing (Flutter `renderChild`). */
@Composable
internal fun ChildView(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier = Modifier) {
    val first = node.childIds.firstOrNull() ?: return
    NodeView(first, model, modifier)
}

/**
 * `name_0`, `name_1`, ... slot ids in order, stopping at the first gap (the
 * Flutter builders read indexed slots this way).
 */
internal fun indexedSlots(node: ResolvedNode, name: String): List<String> {
    val ids = ArrayList<String>()
    while (true) {
        val id = node.slots["${name}_${ids.size}"] ?: return ids
        ids.add(id)
    }
}
