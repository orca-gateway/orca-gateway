package com.orcagateway.core.state

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.j
import com.orcagateway.core.support.jsonOf
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * T1.5: page and app scopes, nested keys, and a change notifies only the
 * subscribers of that key (the per-node `watches` of the Flutter WatchBuilder).
 */
class ElmStoreTest {
    /** Records every notification per label. */
    private class Probe {
        val hits = HashMap<String, Int>()
        val subs = ArrayList<ElmStore.Subscription>()

        fun watch(store: ElmStore, label: String, keys: List<String>) {
            subs.add(store.subscribe(keys) { hits[label] = (hits[label] ?: 0) + 1 })
        }

        fun count(label: String): Int = hits[label] ?: 0
    }

    @Test
    fun changeNotifiesOnlyWatchersOfThatKey() {
        val store = ElmStore(page = props("count" to 0, "name" to "a"))
        val probe = Probe()
        probe.watch(store, "count", listOf("count"))
        probe.watch(store, "name", listOf("name"))
        probe.watch(store, "both", listOf("count", "name"))
        probe.watch(store, "none", emptyList())

        store.dispatch(props("count" to 1))
        assertEquals(1, probe.count("count"))
        assertEquals(0, probe.count("name"))
        assertEquals(1, probe.count("both"))
        assertEquals(0, probe.count("none"))
        assertEquals(j(1), store.value("count"))

        // Writing the same value again is not a change.
        store.dispatch(props("count" to 1))
        assertEquals(1, probe.count("count"))

        // An unrelated key notifies nobody watching count or name.
        store.dispatch(props("other" to true))
        assertEquals(1, probe.count("count") + probe.count("name"))
    }

    @Test
    fun nestedKeys() {
        val store = ElmStore(page = props("theme" to obj("color" to "red", "size" to 12)))
        val probe = Probe()
        probe.watch(store, "color", listOf("theme.color"))
        probe.watch(store, "size", listOf("theme.size"))
        probe.watch(store, "theme", listOf("theme"))

        store.dispatch(props("theme" to obj("color" to "blue", "size" to 12)))
        assertEquals(1, probe.count("color"))
        assertEquals(0, probe.count("size"), "size did not change")
        assertEquals(1, probe.count("theme"), "the parent changed")
        assertEquals(j("blue"), store.value("theme.color"))

        // A flat dotted key (what setState("theme.color") writes) shadows the
        // nested path, as lookupStatePath reads the flat key first.
        store.dispatch(props("theme.color" to "green"))
        assertEquals(2, probe.count("color"))
        assertEquals(1, probe.count("theme"), "the nested map is untouched")
        assertEquals(j("green"), store.value("theme.color"))

        // Array paths.
        store.dispatch(props("items" to arr(obj("name" to "x"))))
        probe.watch(store, "item0", listOf("items.0.name"))
        store.dispatch(props("items" to arr(obj("name" to "y"), obj("name" to "z"))))
        assertEquals(1, probe.count("item0"))
        store.dispatch(props("items" to arr(obj("name" to "y"))))
        assertEquals(1, probe.count("item0"))
    }

    @Test
    fun pageAndAppScopes() {
        val store = ElmStore(page = props("count" to 1), app = props("user" to "amr", "count" to 100))
        val probe = Probe()
        probe.watch(store, "user", listOf("user"))
        probe.watch(store, "count", listOf("count"))

        // Page wins on a key held by both scopes.
        assertEquals(j(1), store.value("count"))
        store.dispatch(props("count" to 200), StateScope.App)
        assertEquals(0, probe.count("count"), "the merged value did not change")
        assertEquals(j(200), store.state.app["count"])

        store.dispatch(props("user" to "sam"), StateScope.App)
        assertEquals(1, probe.count("user"))
        assertNull(store.state.page["user"], "app writes stay in the app scope")

        store.dispatch(props("count" to 2), StateScope.Page)
        assertEquals(1, probe.count("count"))
        assertEquals(j(2), store.state.merged["count"])
    }

    @Test
    fun seedFollowsStateManagerInitPage() {
        val store = ElmStore(page = props("stale" to true), app = props("user" to "amr"))
        store.seed(
            listOf(
                StateDefinition("count", StateScope.Page, j(0)),
                StateDefinition("user", StateScope.App, j("default")),
                StateDefinition("theme", StateScope.App, j("dark")),
            ),
        )
        assertEquals(props("count" to 0), store.state.page, "page scope replaced")
        assertEquals(j("amr"), store.state.app["user"], "set app keys survive navigation")
        assertEquals(j("dark"), store.state.app["theme"], "unset app keys take their initial")
    }

    @Test
    fun cancelAndReleaseStopNotifications() {
        val store = ElmStore(page = props("count" to 0))
        var hits = 0
        val sub = store.subscribe(listOf("count")) { hits += 1 }
        store.dispatch(props("count" to 1))
        sub.cancel()
        store.dispatch(props("count" to 2))
        assertEquals(1, hits)

        // Swift releases a subscription at the end of its scope (deinit);
        // Kotlin closes it at the end of `use`.
        store.subscribe(listOf("count")) { hits += 1 }.use { }
        assertEquals(0, store.subscriberCount)
        store.dispatch(props("count" to 3))
        assertEquals(1, hits)
    }

    @Test
    fun reducerAppliesStateAndReturnsEffects() {
        // The executor is a pure Reducer; the store commits its state and
        // hands the effects to the adapters.
        val reducer: Reducer = { state, action ->
            if (action !is Action.SetState) {
                state to emptyList()
            } else {
                val value = state.resolver().resolve(action.value)
                state.setting(action.key, value, action.scope ?: StateScope.Page) to
                    listOf(ActionEffect("showToast", props("message" to "saved", "duration" to 2000)))
            }
        }
        val store = ElmStore(page = props("count" to 1))
        val seen = ArrayList<JsonValue>()
        val sub = store.subscribe(listOf("count")) { seen.add(it.value("count")) }
        val effects = store.apply(
            Action.SetState(
                "count",
                value = obj(
                    "type" to "transform", "input" to obj("type" to "state", "key" to "count", "scope" to "page"),
                    "by" to arr(obj("type" to "add", "by" to obj("type" to "static", "value" to 1))),
                ),
            ),
            reducer,
        )
        assertEquals(listOf(j(2)), seen)
        assertEquals(listOf(obj("type" to "showToast", "message" to "saved", "duration" to 2000)), effects.map { it.json })
        sub.cancel()
    }

    @Test
    fun storeStateIsAValue() {
        val a = StoreState(page = props("x" to 1))
        val b = a.setting("x", j(2), StateScope.Page).merging(props("y" to true), StateScope.App)
        assertEquals(j(1), a.page["x"], "pure: the original is untouched")
        assertEquals(StoreState(page = props("x" to 2), app = props("y" to true)), b)
        assertEquals(obj("page" to obj("x" to 2), "app" to obj("y" to true)), jsonOf(b))
    }

    /**
     * A navigator shares the app scope through `onCommit`: it sees every
     * commit, before the watchers do, whether or not a watched key changed.
     */
    @Test
    fun onCommitSeesEveryCommitBeforeWatchers() {
        val store = ElmStore(page = props("n" to 0))
        val order = ArrayList<String>()
        store.onCommit = { order.add("commit ${it.app["cart"]?.intValue ?: -1}") }
        val sub = store.subscribe(listOf("cart")) { order.add("watcher") }
        store.dispatch(props("cart" to 2), StateScope.App)
        store.dispatch(props("n" to 1))
        assertEquals(listOf("commit 2", "watcher", "commit 2"), order)
        sub.cancel()
    }

    /**
     * openUrl's scheme policy (Flutter `OrcaUrlPolicy`): http, https and
     * mailto by default, more only when the host opts in.
     */
    @Test
    fun urlPolicy() {
        val policy = OrcaUrlPolicy.standard
        for (allowed in listOf("https://orca.example", "HTTP://orca.example/a?b=1", "mailto:hi@orca.example")) {
            assertNotNull(policy.url(allowed), allowed)
        }
        for (
            blocked in listOf(
                "javascript:alert(1)", "tel:123", "sms:123", "file:///etc/hosts",
                "data:text/html,hi", "orca.example", "", "not a url",
            )
        ) {
            assertNull(policy.url(blocked), blocked)
        }
        assertNotNull(OrcaUrlPolicy(extraSchemes = setOf("Tel")).url("tel:123"))
        assertEquals(setOf("http", "https", "mailto", "tel"), OrcaUrlPolicy(extraSchemes = setOf("tel")).allowedSchemes)
    }
}
