package com.orcagateway.sdk.widgets

import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.MeasurePolicy
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.subpage.SubPage
import com.orcagateway.sdk.LocalOrcaFrozenNodes
import com.orcagateway.sdk.LocalOrcaNodeRecorder
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.SubPageSlot
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
 *   oldest first, one below the other, each at the full width the host gives (Flutter's stretched Column).
 *   One mounted page is drawn exactly as its root.
 * - A page that replaces another is composed anew, even when its ids are the same: each drawn page is keyed by
 *   the count of replaces ([SubPageSlot.generation]) and its prefix. The new page's composables may register
 *   (an `animationId`) before the old ones are disposed; a registration is given up only by its owner
 *   (`AnimationRegistry.unregister`), and a nested SubPage follows its node, not its composition.
 * - The mounted nodes are the host page's own, so they are drawn with [NodeView] like any node.
 * - Unmount (S8) is the model's: it follows the SubPage node, not this composition, so a page under a pushed
 *   one (which leaves the composition) keeps its sub-pages.
 * - A layer drawn from a snapshot ([LocalOrcaFrozenNodes]) fetches and registers nothing: it draws what the
 *   snapshot holds of what was last drawn here.
 */
@Composable
internal fun SubPageWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    if (LocalOrcaFrozenNodes.current != null) {
        Pages(node.childIds, node.childIds, model, modifier)
        return
    }
    // A mount changes the node tree; reading the revision here draws the new pages.
    model.structureRevision
    val slot = model.subPage(node.id)
    val location = SubPage.request(Props.string(node["pageId"]) ?: "", node["params"]?.objectValue).location
    LaunchedEffect(slot, location) { model.loadSubPage(slot, location) }

    val error = slot.error
    val mounted = slot.mounts.pages.filter { it.rootId != null }
    val drawn = when {
        error != null -> emptyList()
        slot.mounts.pages.isEmpty() -> node.childIds.take(1)
        else -> mounted.mapNotNull { it.rootId }
    }
    val keys = if (slot.mounts.pages.isEmpty()) drawn else mounted.map { "${slot.generation}/${it.prefix}" }
    // What a snapshot of this node draws: the SubPage with the pages on screen as its children.
    LocalOrcaNodeRecorder.current?.record(node.copy(childIds = drawn))
    when {
        error != null -> Centred(modifier) { Text("SubPage error: $error", color = Color.Red) }
        slot.mounts.pages.isEmpty() && drawn.isEmpty() -> Centred(modifier) { CircularProgressIndicator() }
        else -> Pages(drawn, keys, model, modifier)
    }
}

/**
 * The nodes [ids] one below the other, each as wide as the parent allows; a single one with the limits and the
 * size of its own, none as nothing. Each is composed under its entry of [keys]: a new key is a new composition,
 * and a kept key keeps its composition when a page joins (one layout for one page and for several).
 */
@Composable
private fun Pages(ids: List<String>, keys: List<String>, model: OrcaPageModel, modifier: Modifier) {
    if (ids.isEmpty()) return
    Layout(
        content = { for (i in ids.indices) key(keys[i]) { NodeView(ids[i], model) } },
        modifier = modifier,
        measurePolicy = PagesMeasurePolicy,
    )
}

/**
 * One child: the parent's limits, the child's size. Several: Flutter's `Column(mainAxisSize: min,
 * crossAxisAlignment: stretch)`, each child held to the width the parent allows (its own when that has no
 * limit) at its own height, the column as tall as they are.
 */
private val PagesMeasurePolicy = MeasurePolicy { measurables, constraints ->
    if (measurables.size == 1) {
        val only = measurables[0].measure(constraints)
        return@MeasurePolicy layout(only.width, only.height) { only.place(0, 0) }
    }
    val bounded = constraints.maxWidth != Constraints.Infinity
    val child = Constraints(minWidth = if (bounded) constraints.maxWidth else 0, maxWidth = constraints.maxWidth)
    val placeables = measurables.map { it.measure(child) }
    val width = constraints.constrainWidth(placeables.maxOfOrNull { it.width } ?: 0)
    layout(width, constraints.constrainHeight(placeables.sumOf { it.height })) {
        var y = 0
        for (placeable in placeables) {
            placeable.place(0, y)
            y += placeable.height
        }
    }
}

/** Flutter's `Center`: as big as the parent allows, the content in the middle. */
@Composable
private fun Centred(modifier: Modifier, content: @Composable () -> Unit) {
    Layout(content = content, modifier = modifier, measurePolicy = CenterMeasurePolicy(null, null))
}
