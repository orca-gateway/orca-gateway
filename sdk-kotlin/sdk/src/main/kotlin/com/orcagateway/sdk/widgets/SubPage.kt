package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.Layout
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.subpage.SubPage
import com.orcagateway.sdk.LocalOrcaFrozenNodes
import com.orcagateway.sdk.LocalOrcaNodeRecorder
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props

/**
 * SubPage: another page fetched and drawn in place, Flutter's `OrcaSubPageWidget`
 * (sdk/lib/src/builders/sub_page_widget.dart). The contract (S1 to S8) is in
 * `schema/fixtures/subpage/README.md` and its rules in the core (`SubPage`, `SubPageHost`); this builder only
 * asks for the fetch and draws. Each rule:
 *
 * - Fetch (S4): the resolved `pageId` and `params` as one location (`SubPage.request`), when the node is first
 *   drawn and again, as a replace, when that location changes. A redraw with the same location fetches nothing,
 *   so what `updateSubPage` mounted stays. The fetch belongs to the page model ([OrcaPageModel.loadSubPage]).
 * - Draw (S5): while nothing is mounted and nothing failed, the child, else a centred progress indicator;
 *   after a failed fetch of its own, the text `SubPage error: <message>`; else the root of each mounted page,
 *   oldest first, one below the other. One mounted page is drawn exactly as its root.
 * - The mounted nodes are the host page's own, so they are drawn with [NodeView] like any node.
 * - Unmount (S8) is the model's: it follows the SubPage node, not this composition, so a page under a pushed
 *   one (which leaves the composition) keeps its sub-pages.
 * - A layer drawn from a snapshot ([LocalOrcaFrozenNodes]) fetches and registers nothing: it draws what the
 *   snapshot holds of what was last drawn here.
 */
@Composable
internal fun SubPageWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    if (LocalOrcaFrozenNodes.current != null) {
        Pages(node.childIds, model, modifier)
        return
    }
    // A mount changes the node tree; reading the revision here draws the new pages.
    model.structureRevision
    val slot = model.subPage(node.id)
    val location = SubPage.request(Props.string(node["pageId"]) ?: "", node["params"]?.objectValue).location
    LaunchedEffect(slot, location) { model.loadSubPage(slot, location) }

    val error = slot.error
    val drawn = when {
        error != null -> emptyList()
        slot.mounts.pages.isEmpty() -> node.childIds.take(1)
        else -> slot.mounts.roots
    }
    // What a snapshot of this node draws: the SubPage with the pages on screen as its children.
    LocalOrcaNodeRecorder.current?.record(node.copy(childIds = drawn))
    when {
        error != null -> Centred(modifier) { Text("SubPage error: $error", color = Color.Red) }
        slot.mounts.pages.isEmpty() && drawn.isEmpty() -> Centred(modifier) { CircularProgressIndicator() }
        else -> Pages(drawn, model, modifier)
    }
}

/** The nodes [ids] one below the other; a single one exactly as itself, none as nothing. */
@Composable
private fun Pages(ids: List<String>, model: OrcaPageModel, modifier: Modifier) {
    when (ids.size) {
        0 -> Unit
        1 -> key(ids[0]) { NodeView(ids[0], model, modifier) }
        else -> Column(modifier) {
            for (id in ids) key(id) { NodeView(id, model) }
        }
    }
}

/** Flutter's `Center`: as big as the parent allows, the content in the middle. */
@Composable
private fun Centred(modifier: Modifier, content: @Composable () -> Unit) {
    Layout(content = content, modifier = modifier, measurePolicy = CenterMeasurePolicy(null, null))
}
