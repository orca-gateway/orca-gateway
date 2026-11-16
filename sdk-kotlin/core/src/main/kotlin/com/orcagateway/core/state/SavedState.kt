package com.orcagateway.core.state

import com.orcagateway.core.client.KeyValueStore
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.StateScope

/**
 * The saved copies of state keys that `persistState` writes and
 * `clearState` removes, restored when their scope is set up again (the
 * saved-state contract of native parity step 14; Flutter keeps it in
 * sdk/lib/src/state/state_manager.dart, Swift twin `SavedState`).
 *
 * One entry per scope: app state under `orca_saved_app`, a page's state
 * under `orca_saved_page_<pageId>`, each a JSON object `{key: value}`.
 * `local` is [local] (on a device the core's
 * [com.orcagateway.core.client.FileKeyValueStore]; it survives a restart),
 * the entry's name as its key. `session` is one in-memory map for the whole
 * process: it outlives page changes and OrcaApp rebuilds, not the process.
 * A key is saved in one storage at a time.
 *
 * Reads are synchronous: an entry of [local] is read once, when first
 * needed, into a mirror, and every change is written through. A store that
 * throws, or an entry that is not a JSON object, reads as no entry and the
 * write is dropped: nothing is thrown, as the executor treats other
 * failures. Without [local], local saves live in the mirror, for the life
 * of this object. Thread-safe.
 */
public class SavedState(private val local: KeyValueStore?) {
    /** Where `persistState` saves (its `storage`). */
    public enum class Storage(public val wire: String) {
        /** [SavedState]'s `local` store: survives a restart. */
        Local("local"),

        /** The process-wide map: until the process ends. */
        Session("session"),
        ;

        public companion object {
            /** The storage named [wire]; none, or a name it does not know, is [Local] (the engine's default). */
            public fun of(wire: String?): Storage = entries.firstOrNull { it.wire == wire } ?: Local
        }
    }

    private val lock = Any()

    /** The local entries read so far, by entry name; an absent or unreadable one is empty. */
    private val mirror = HashMap<String, Map<String, JsonValue>>()

    /**
     * Save [key]'s current value in [from]'s [scope] (any JSON, null
     * included) into [storage], and drop it from the other storage. A key
     * the live scope does not hold changes nothing, and so does a page scope
     * without a [pageId]. A snapshot: a later change is saved only when this
     * runs again.
     */
    public fun persist(key: String, scope: StateScope, pageId: String?, storage: Storage, from: ElmStore) {
        val name = entryName(scope, pageId) ?: return
        val live = from.state[scope]
        if (!live.containsKey(key)) return
        val value = live.getValue(key)
        synchronized(lock) {
            when (storage) {
                Storage.Local -> {
                    updateLocal(name) { it + (key to value) }
                    updateSession(name) { it - key }
                }
                Storage.Session -> {
                    updateSession(name) { it + (key to value) }
                    updateLocal(name) { it - key }
                }
            }
        }
    }

    /**
     * Remove [key] from both storages' entries for [scope]; an entry left
     * with no key is deleted. The live key is the executor's to null.
     */
    public fun clear(key: String, scope: StateScope, pageId: String?) {
        val name = entryName(scope, pageId) ?: return
        synchronized(lock) {
            updateLocal(name) { it - key }
            updateSession(name) { it - key }
        }
    }

    /** Set every key of the saved app entry over [into]'s app state, replacing or adding it. */
    public fun restore(into: ElmStore) {
        restore(into, StateScope.App, APP_ENTRY)
    }

    /** Set every key of [pageId]'s saved entry over [into]'s page state, replacing or adding it. */
    public fun restorePage(into: ElmStore, pageId: String) {
        restore(into, StateScope.Page, PAGE_PREFIX + pageId)
    }

    private fun restore(store: ElmStore, scope: StateScope, name: String) {
        val saved = synchronized(lock) { localEntry(name) + sessionEntry(name) }
        if (saved.isNotEmpty()) store.dispatch(saved, scope)
    }

    private fun localEntry(name: String): Map<String, JsonValue> = mirror.getOrPut(name) {
        try {
            local?.getString(name)?.let { JsonValue.parse(it).objectValue } ?: emptyMap()
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun updateLocal(name: String, change: (Map<String, JsonValue>) -> Map<String, JsonValue>) {
        val before = localEntry(name)
        val after = change(before)
        if (after == before) return
        mirror[name] = after
        try {
            local?.putString(name, if (after.isEmpty()) null else JsonValue.Object(after).encoded())
        } catch (_: Exception) {
            // Dropped: the mirror keeps the change for this run.
        }
    }

    public companion object {
        private const val APP_ENTRY = "orca_saved_app"
        private const val PAGE_PREFIX = "orca_saved_page_"

        private val sessionLock = Any()
        private val session = HashMap<String, Map<String, JsonValue>>()

        /** The entry [scope] saves into: `orca_saved_app`, or `orca_saved_page_<pageId>` (none without a page id). */
        private fun entryName(scope: StateScope, pageId: String?): String? = when (scope) {
            StateScope.App -> APP_ENTRY
            StateScope.Page -> pageId?.let { PAGE_PREFIX + it }
        }

        private fun sessionEntry(name: String): Map<String, JsonValue> = synchronized(sessionLock) { session[name] } ?: emptyMap()

        private fun updateSession(name: String, change: (Map<String, JsonValue>) -> Map<String, JsonValue>) {
            synchronized(sessionLock) {
                val after = change(session[name] ?: emptyMap())
                if (after.isEmpty()) session.remove(name) else session[name] = after
            }
        }

        /**
         * The session storage's entries, by entry name: what is saved for this
         * process, for a host to inspect it or a test to check it.
         */
        public val sessionEntries: Map<String, Map<String, JsonValue>>
            get() = synchronized(sessionLock) { session.toMap() }

        /**
         * Replace the session storage with [entries] (by default none), to clear
         * session state when a user signs out, or to start a test or fixture
         * from known entries. The local storage is not touched.
         */
        public fun resetSession(entries: Map<String, Map<String, JsonValue>> = emptyMap()) {
            synchronized(sessionLock) {
                session.clear()
                for ((name, entry) in entries) if (entry.isNotEmpty()) session[name] = entry
            }
        }
    }
}
