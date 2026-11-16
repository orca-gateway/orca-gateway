package com.orcagateway.core.subpage

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.encoding
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.render.PageRenderer
import com.orcagateway.core.state.ElmStore

/**
 * The sub-pages mounted in one host page (contract S3): which SubPage node holds which pages, and the one place
 * a [SubPageChange] is applied to the host's node store ([PageRenderer.nodes]) and page state ([ElmStore]).
 *
 * A SubPage is registered under its node id for as long as that node is in the store; [sweep] takes out the
 * ones whose node left (S8). No Android, no I/O: the UI layer fetches and draws. Not thread-safe, as the store.
 */
public class SubPageHost(private val renderer: PageRenderer, private val store: ElmStore) {
    private val registry = LinkedHashMap<String, SubPageMounts>()

    /** The mounted pages of the SubPage node [key], made the first time it is asked for. */
    public fun register(key: String): SubPageMounts = registry.getOrPut(key) { SubPageMounts(key) }

    /** The mounted pages of the SubPage node [key], null when none is registered (an unknown id). */
    public fun mounts(key: String): SubPageMounts? = registry[key]

    /** Prefix of every page mounted in the host page, by SubPage in registration order. */
    public val prefixes: List<String> get() = registry.values.flatMap { it.prefixes }

    /**
     * Mounts a fetched [page] in the SubPage [key] ([SubPageMounts.apply]) and applies the change to the host
     * page in the contract's order: nodes out, state keys out, nodes in, seeds written (one commit). A replace
     * takes out every node under the old pages' prefixes, so the ones added since the mount (addComponent) go
     * too, and a SubPage among them is unmounted with its page. Null, and nothing done, for an unknown [key].
     */
    public fun mount(key: String, mode: String, page: PageResponse): SubPageChange? {
        val mounts = registry[key] ?: return null
        val before = mounts.prefixes
        val change = mounts.apply(mode, JsonValue.encoding(PageResponse.serializer(), page), store.state.page.keys)
        val added = change.nodes.map { it.decode(ComponentNode.serializer()) }

        if (before.isNotEmpty() && mode != "join") {
            removePages(before)
            sweep()
        }
        if (added.isNotEmpty()) renderer.nodes = renderer.nodes + added.associateBy { it.id }
        val state = store.state
        store.commit(state.copy(page = state.page - change.removedStateKeys.toSet() + change.seeds))
        return change
    }

    /**
     * Unmounts every SubPage whose node is no longer in the store (S8): every node under its pages' prefixes
     * is removed, its state keys are left. Gives the keys it unmounted, a SubPage nested in one of them included.
     */
    public fun sweep(): List<String> {
        val gone = ArrayList<String>()
        while (true) {
            val key = registry.keys.firstOrNull { it !in renderer.nodes } ?: return gone
            val mounts = registry.remove(key) ?: return gone
            removePages(mounts.prefixes)
            gone += key
        }
    }

    /** Takes every node of the pages mounted under [prefixes] out of the store: each id that starts with one. */
    private fun removePages(prefixes: List<String>) {
        if (prefixes.isEmpty()) return
        renderer.nodes = renderer.nodes.filterKeys { id -> prefixes.none(id::startsWith) }
    }
}
