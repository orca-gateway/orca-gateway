package com.orcagateway.sdk

import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.widgets.LifecycleTriggers
import com.orcagateway.sdk.widgets.hasLifecycleTriggers

/**
 * Progress (0..1, after its curve) of the nearest enclosing AnimatedBuilder;
 * null outside one. Nodes below one resolve `tween` props by it.
 */
internal val LocalOrcaAnimationProgress = compositionLocalOf<Double?> { null }

/**
 * Set below a layer that is drawn from a snapshot and not from the page (an
 * AnimatedSwitcher's outgoing child, which the page may no longer hold): the
 * resolved nodes to draw, by id ([OrcaNodeSnapshot.frozen]). Null, the
 * default, is the live page.
 */
internal val LocalOrcaFrozenNodes = compositionLocalOf<Map<String, ResolvedNode>?> { null }

/** Where the live nodes drawn below this point are recorded as they are resolved; null: nowhere. */
internal val LocalOrcaNodeRecorder = compositionLocalOf<OrcaNodeSnapshot?> { null }

/**
 * Draws one node of a page by id, and everything below it. Each node
 * observes only its own watched keys (and changes to the node tree); the
 * model itself is not observed here, so a toast appearing does not redraw
 * the page's nodes.
 *
 * [modifier] goes on the node's outermost layout: a parent uses it to force
 * a size, as a Flutter parent passes tight constraints.
 *
 * A node setting onInit, onVisible or an app trigger also gets
 * [LifecycleTriggers] (Flutter's OrcaLifecycleWrapper), which draws nothing;
 * other nodes are composed exactly as before.
 *
 * Under [LocalOrcaFrozenNodes] the node is the snapshot's and inert: it
 * observes nothing, is not resolved again, runs no lifecycle trigger, its
 * actions are [OrcaPageModel.INERT_ACTION]. It is drawn by the same
 * builder at the same place, so a widget keeps its composition state as it
 * turns from live to frozen; a builder that runs something of its own
 * (an animation) asks [LocalOrcaFrozenNodes] and stops it.
 */
@Composable
public fun NodeView(id: String, model: OrcaPageModel, modifier: Modifier = Modifier) {
    val frozen = LocalOrcaFrozenNodes.current
    val node = if (frozen != null) {
        frozen[id] ?: return
    } else {
        val observer = remember(model, id) { NodeObserver(model, id) }
        // Reading the revision ties this node to its watches: the node is
        // resolved again only when one of them, or the tree, changed.
        val revision = observer.revision
        // Under an AnimatedBuilder the progress changes every frame, and the
        // node is resolved again with it so its `tween` props move.
        val progress = LocalOrcaAnimationProgress.current
        val live = remember(observer, revision, progress) { model.resolve(id, progress) } ?: return
        LocalOrcaNodeRecorder.current?.record(live)
        if (hasLifecycleTriggers(live)) LifecycleTriggers(live, model)
        live
    }
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
