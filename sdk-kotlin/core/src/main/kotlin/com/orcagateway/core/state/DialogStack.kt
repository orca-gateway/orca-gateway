package com.orcagateway.core.state

import com.orcagateway.core.models.ComponentNode

/**
 * One open sheet. Two opens of the same Dialog are two sheets (identity, as
 * Swift's `Sheet.id`).
 */
public class DialogSheet internal constructor(
    public val dialogId: String,
    /** The sheet's height as a fraction of the height available. */
    public val heightFactor: Double,
    /**
     * The Dialog's children and everything below them, depth first in
     * order, as the page held them when the sheet opened: Flutter's
     * `subtree` list (orca_page.dart:332-343). Never empty.
     */
    public val nodes: List<ComponentNode>,
) {
    /** The node the sheet draws: the first of [nodes], the Dialog's first child on the page. */
    public val rootId: String get() = nodes.first().id

    override fun toString(): String = "DialogSheet($dialogId, $heightFactor, ${nodes.map { it.id }})"
}

/**
 * The sheets openDialog has opened on one page, the Kotlin side of Flutter's
 * openDialog and closeDialog handlers (sdk/lib/src/widgets/orca_page.dart
 * :323-374, sdk/lib/src/state/action_executor.dart:894-919). Pure: the UI
 * draws [sheets] bottom to top and reports what closes them.
 *
 * A sheet holds the Dialog's children subtree, depth first; Flutter's
 * ComponentRenderer draws such a list from its first node
 * (component_renderer.dart:44-54), the Dialog's first child, so a second
 * child is in the list but nothing draws it. The Dialog's own props
 * (title, dismissible, backgroundColor, borderRadius) are never read, and
 * its type is not checked: any keyed node with children opens. The same
 * cases as Swift's DialogStack.
 */
public class DialogStack {
    private val open = ArrayList<DialogSheet>()

    /** Open sheets, the bottom one first. */
    public val sheets: List<DialogSheet> get() = open.toList()

    /** The sheet on top, the one a close or a dismiss takes away. */
    public val top: DialogSheet? get() = open.lastOrNull()

    /**
     * openDialog: a sheet of the Dialog [dialogId] of [nodes] (the page's
     * node map) on top of the stack, and that sheet. An id the page lacks,
     * or a Dialog none of whose children is on the page, opens nothing and
     * gives null (orca_page.dart:329, :344). A child the page lacks is
     * skipped, as Flutter's `collect`; a node met twice is listed once (a
     * cycle, which would never end in Flutter, ends).
     */
    public fun open(dialogId: String, heightFactor: Double?, nodes: Map<String, ComponentNode>): DialogSheet? {
        val dialog = nodes[dialogId] ?: return null
        val subtree = ArrayList<ComponentNode>()
        val seen = HashSet<String>()
        fun collect(id: String) {
            val node = nodes[id] ?: return
            if (!seen.add(id)) return
            subtree.add(node)
            node.children.forEach(::collect)
        }
        dialog.children.forEach(::collect)
        if (subtree.isEmpty()) return null
        return DialogSheet(dialogId, heightFactor(heightFactor), subtree).also { open.add(it) }
    }

    /**
     * closeDialog: takes the top sheet away and gives it; with none open it
     * does nothing and gives null, never closing a page (action_executor
     * .dart:903-912).
     */
    public fun close(): DialogSheet? = open.removeLastOrNull()

    /**
     * A barrier tap, a drag down or Back: takes the top sheet away, whatever
     * the Dialog's `dismissible` says, and gives it; null with none open.
     */
    public fun dismiss(): DialogSheet? = close()

    public companion object {
        /** The height of a sheet whose openDialog names none (orca_page.dart:326). */
        public const val DEFAULT_HEIGHT_FACTOR: Double = 0.5

        /** A sheet's height factor: openDialog's `heightFactor`, 0.5 when absent, NaN or negative. */
        public fun heightFactor(raw: Double?): Double = if (raw != null && raw >= 0) raw else DEFAULT_HEIGHT_FACTOR
    }
}
