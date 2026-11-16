package com.orcagateway.core.state

import com.orcagateway.core.client.FileKeyValueStore
import com.orcagateway.core.client.KeyValueStore
import com.orcagateway.core.client.MemoryKeyValueStore
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import java.nio.file.Files
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Every entry of a local store, its JSON text decoded. */
private fun entries(store: MemoryKeyValueStore): Map<String, JsonValue> = store.snapshot().mapValues { JsonValue.parse(it.value) }

/** A KeyValueStore that counts its reads and can hold any text. */
private class CountingStore(initial: Map<String, String> = emptyMap()) : KeyValueStore {
    val values = HashMap(initial)
    val reads = ArrayList<String>()

    override fun getString(key: String): String? {
        reads.add(key)
        return values[key]
    }

    override fun putString(key: String, value: String?) {
        if (value == null) values.remove(key) else values[key] = value
    }
}

/** A KeyValueStore whose every read and write throws, as a broken disk would. */
private class FailingStore : KeyValueStore {
    override fun getString(key: String): String? = throw IllegalStateException("read failed")

    override fun putString(key: String, value: String?): Unit = throw IllegalStateException("write failed")
}

/**
 * C14.6 (Kotlin core): persistState and clearState through SavedState, by
 * the saved-state contract S1-S8 the three SDKs share: entries
 * `orca_saved_app` and `orca_saved_page_<pageId>`, each a JSON object;
 * `local` in the KeyValueStore, `session` in a process-wide map. Swift twin:
 * SavedStateTests.
 */
class SavedStateTest {
    @BeforeTest
    fun resetBefore() {
        SavedState.resetSession()
    }

    @AfterTest
    fun resetAfter() {
        SavedState.resetSession()
    }

    /** A page store for `home`, and an executor over it that saves through [saved]. */
    private fun page(
        page: Map<String, JsonValue> = emptyMap(),
        app: Map<String, JsonValue> = emptyMap(),
        saved: SavedState?,
    ): Pair<ElmStore, ActionExecutor> {
        val store = ElmStore(StoreState(page, app))
        store.pageId = "home"
        val executor = ActionExecutor(store)
        executor.savedState = saved
        return store to executor
    }

    private fun persist(key: String, scope: StateScope? = null, storage: String? = null): Action =
        Action.PersistState(key, scope, storage)

    private fun clear(key: String, scope: StateScope? = null): Action = Action.ClearState(key, scope)

    private fun entry(vararg members: Pair<String, Any?>): Map<String, JsonValue> = props(*members)

    // MARK: S1, S3: persistState

    @Test
    fun c14_6_s1_s3_persistWritesTheKeyIntoItsScopesEntryInLocal() = runSuspend {
        val local = MemoryKeyValueStore()
        val (_, executor) = page(props("count" to 3, "name" to "Ada"), props("visits" to 2), SavedState(local))

        executor.execute(persist("count", StateScope.Page, "local"))
        executor.execute(persist("name"))
        executor.execute(persist("visits", StateScope.App, "local"))

        assertEquals(
            mapOf("orca_saved_page_home" to obj("count" to 3, "name" to "Ada"), "orca_saved_app" to obj("visits" to 2)),
            entries(local),
        )
        assertEquals(emptyMap(), SavedState.sessionEntries)
    }

    @Test
    fun c14_6_s3_persistSessionKeepsOneSavedCopyPerKey() = runSuspend {
        val local = MemoryKeyValueStore()
        val (store, executor) = page(props("count" to 3, "other" to true), saved = SavedState(local))

        executor.execute(persist("count", StateScope.Page, "local"))
        executor.execute(persist("other", StateScope.Page, "local"))
        executor.execute(persist("count", StateScope.Page, "session"))
        assertEquals(mapOf("orca_saved_page_home" to obj("other" to true)), entries(local))
        assertEquals(mapOf("orca_saved_page_home" to entry("count" to 3)), SavedState.sessionEntries)

        store.dispatch(props("count" to 4))
        executor.execute(persist("count", StateScope.Page, "local"))
        assertEquals(mapOf("orca_saved_page_home" to obj("other" to true, "count" to 4)), entries(local))
        assertEquals(emptyMap(), SavedState.sessionEntries, "an entry left with no key is deleted")
    }

    @Test
    fun c14_6_s3_persistIsASnapshotSavesNullAndIgnoresAnAbsentKey() = runSuspend {
        val local = MemoryKeyValueStore()
        val (store, executor) = page(mapOf("count" to j(3), "empty" to JsonValue.Null), saved = SavedState(local))

        executor.execute(persist("count"))
        store.dispatch(props("count" to 9))
        assertEquals(mapOf("orca_saved_page_home" to obj("count" to 3)), entries(local), "a later setState saves nothing")

        executor.execute(persist("empty"))
        executor.execute(persist("missing"))
        executor.execute(persist("count", StateScope.App))
        assertEquals(mapOf("orca_saved_page_home" to obj("count" to 3, "empty" to null)), entries(local))
        assertEquals(StoreState(page = mapOf("count" to j(9), "empty" to JsonValue.Null)), store.state)
    }

    // MARK: S4: clearState

    @Test
    fun c14_6_s4_clearNullsTheLiveKeyAndRemovesEverySavedCopy() = runSuspend {
        val local = MemoryKeyValueStore(
            mapOf("orca_saved_page_home" to """{"count":3,"keep":1}""", "orca_saved_app" to """{"token":"t"}"""),
        )
        SavedState.resetSession(
            mapOf("orca_saved_page_home" to entry("count" to 5), "orca_saved_app" to entry("token" to "s", "theme" to "dark")),
        )
        val (store, executor) = page(props("count" to 5, "keep" to 1), props("token" to "t", "theme" to "dark"), SavedState(local))

        executor.execute(clear("count"))
        executor.execute(clear("token", StateScope.App))

        assertEquals(
            StoreState(
                page = mapOf("count" to JsonValue.Null, "keep" to j(1)),
                app = mapOf("token" to JsonValue.Null, "theme" to j("dark")),
            ),
            store.state,
        )
        assertEquals(mapOf("orca_saved_page_home" to obj("keep" to 1)), entries(local), "the emptied app entry is deleted")
        assertEquals(mapOf("orca_saved_app" to entry("theme" to "dark")), SavedState.sessionEntries)
    }

    @Test
    fun c14_6_s4_withoutSavedStateClearOnlyNullsAndPersistSavesNothing() = runSuspend {
        val (store, executor) = page(props("count" to 5), saved = null)
        executor.execute(persist("count", StateScope.Page, "session"))
        executor.execute(clear("count"))
        executor.execute(clear("absent", StateScope.App))
        assertEquals(StoreState(page = mapOf("count" to JsonValue.Null), app = mapOf("absent" to JsonValue.Null)), store.state)
        assertEquals(emptyMap(), SavedState.sessionEntries)
    }

    // MARK: S5: restore

    @Test
    fun c14_6_s5_restorePageReplacesTheInitialsAndAddsUndeclaredKeys() {
        val local = MemoryKeyValueStore(mapOf("orca_saved_page_home" to """{"count":7}"""))
        SavedState.resetSession(
            mapOf("orca_saved_page_home" to entry("draft" to "hi"), "orca_saved_page_other" to entry("x" to 1)),
        )
        val store = ElmStore()
        store.seed(listOf(StateDefinition("count", StateScope.Page, j(0)), StateDefinition("name", StateScope.Page, j(""))))

        SavedState(local).restorePage(into = store, pageId = "home")
        assertEquals(props("count" to 7, "name" to "", "draft" to "hi"), store.state.page)
        assertEquals(emptyMap(), store.state.app)
    }

    @Test
    fun c14_6_s5_restoreSetsTheAppEntryOverTheAppState() {
        val local = MemoryKeyValueStore(mapOf("orca_saved_app" to """{"visits":4,"user":{"id":1}}"""))
        SavedState.resetSession(mapOf("orca_saved_app" to entry("lang" to "fr")))
        val store = ElmStore(StoreState(page = props("visits" to "page"), app = props("visits" to 0, "theme" to "light")))

        SavedState(local).restore(into = store)
        assertEquals(
            StoreState(
                page = props("visits" to "page"),
                app = mapOf("visits" to j(4), "theme" to j("light"), "user" to obj("id" to 1), "lang" to j("fr")),
            ),
            store.state,
        )
    }

    // MARK: S2, S6: storages

    @Test
    fun c14_6_s2_aRestartOverTheSameFilesRestoresLocalAndNotSession() = runSuspend {
        val dir = Files.createTempDirectory("orca-saved").toFile()
        try {
            val (_, executor) = page(
                props("count" to 3),
                props("visits" to 1, "seen" to true),
                SavedState(FileKeyValueStore(dir)),
            )
            executor.execute(persist("count"))
            executor.execute(persist("visits", StateScope.App))
            executor.execute(persist("seen", StateScope.App, "session"))

            // Another SavedState in this process sees the same session.
            val again = ElmStore()
            SavedState(local = null).restore(into = again)
            assertEquals(props("seen" to true), again.state.app)

            // A restart: the process ends (the session goes), the files stay.
            SavedState.resetSession()
            val restarted = SavedState(FileKeyValueStore(dir))
            val store = ElmStore()
            restarted.restore(into = store)
            store.seed(listOf(StateDefinition("count", StateScope.Page, j(0))))
            restarted.restorePage(into = store, pageId = "home")
            assertEquals(StoreState(page = props("count" to 3), app = props("visits" to 1)), store.state)
        } finally {
            dir.deleteRecursively()
        }
    }

    @Test
    fun c14_6_s6_localIsReadOnceAndAFailedReadRestoresNothing() {
        val local = CountingStore(mapOf("orca_saved_page_home" to "not json", "orca_saved_app" to "[1]"))
        val saved = SavedState(local)
        val store = ElmStore(StoreState(page = props("count" to 1)))
        saved.restorePage(into = store, pageId = "home")
        saved.restore(into = store)
        saved.restorePage(into = store, pageId = "home")
        assertEquals(StoreState(page = props("count" to 1)), store.state)
        assertEquals(listOf("orca_saved_app", "orca_saved_page_home"), local.reads.sorted(), "the mirror reads each entry once")

        // A persist writes over the unreadable entry.
        store.pageId = "home"
        saved.persist("count", scope = StateScope.Page, pageId = "home", storage = SavedState.Storage.Local, from = store)
        assertEquals("""{"count":1}""", local.values["orca_saved_page_home"])
    }

    @Test
    fun c14_6_s6_aFailingStoreIsSwallowedAndTheActionsStillComplete() = runSuspend {
        val (store, executor) = page(props("count" to 2), saved = SavedState(FailingStore()))
        executor.execute(persist("count"))
        executor.execute(persist("count", StateScope.Page, "session"))
        executor.execute(clear("count"))
        SavedState(FailingStore()).restorePage(into = store, pageId = "home")
        assertEquals(StoreState(page = mapOf("count" to JsonValue.Null)), store.state)
        assertEquals(emptyMap(), SavedState.sessionEntries)
    }

    @Test
    fun c14_6_s3_aPageScopeWithoutAPageIdSavesNothing() = runSuspend {
        val local = MemoryKeyValueStore()
        val store = ElmStore(StoreState(page = props("count" to 1), app = props("visits" to 1)))
        val executor = ActionExecutor(store)
        executor.savedState = SavedState(local)
        executor.execute(persist("count"))
        executor.execute(persist("visits", StateScope.App))
        assertEquals(mapOf("orca_saved_app" to obj("visits" to 1)), entries(local))
    }

    // MARK: S7, S8

    @Test
    fun c14_6_s7_neitherActionEmitsAnEffectAndBothAreImplemented() = runSuspend {
        val (_, executor) = page(props("count" to 1), saved = SavedState(MemoryKeyValueStore()))
        val effects = ArrayList<ActionEffect>()
        executor.onEffect = { effects.add(it) }
        executor.execute(Action.ActionGroup(actions = listOf(persist("count"), clear("count"))))
        assertEquals(emptyList(), effects)
        assertTrue(ActionExecutor.implements(persist("count")))
        assertTrue(ActionExecutor.implements(clear("count")))
    }
}
