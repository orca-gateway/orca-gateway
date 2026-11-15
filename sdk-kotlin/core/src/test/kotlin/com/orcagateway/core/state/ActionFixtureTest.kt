package com.orcagateway.core.state

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.support.ActionStub
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.jsonOf
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * T3.1: schema/fixtures/actions through the Kotlin executor, as the Flutter
 * runner (sdk/test/conformance/action_fixtures_test.dart) runs them through
 * the Dart executor. Each run seeds the state, runs the actions, and compares
 * the state and the effects as JSON. A fixture with `serverResponses` talks
 * to a stub of the `/action` route, as the Dart runner's stub client does.
 */
class ActionFixtureTest {
    @Test
    fun allSeventeenActionFixturesPass() = runSuspend {
        val files = Fixtures.files("actions")
        assertEquals(17, files.size)
        for ((name, fx) in files) {
            val actions = fx["actions"].arrayValue.orEmpty().map { it.decode(Action.serializer()) }
            assertTrue(actions.all { ActionExecutor.implements(it) }, "$name: every kind implemented")

            val store = ElmStore(fx["state"].decode(StoreState.serializer()))
            val client = fx["serverResponses"].objectValue?.let { ActionStub.client(ActionStub(it)) }
            val executor = ActionExecutor(store, client)
            val effects = ArrayList<ActionEffect>()
            executor.onEffect = { effects.add(it) }

            for (action in actions) executor.execute(action, fx["event"].objectValue)
            assertJsonEqual(jsonOf(store.state), fx["expected"]["state"], "$name: state")
            assertJsonEqual(JsonValue.Array(effects.map { it.json }), fx["expected"]["effects"], "$name: effects")
        }
    }

    @Test
    fun unimplementedKindsChangeNothing() = runSuspend {
        val state = StoreState(page = props("count" to 1))
        val (next, effects) = ActionReducer().reduce(state, Action.AnimateForward("fade"))
        assertEquals(state, next)
        assertEquals(emptyList(), effects)

        val store = ElmStore(state)
        val executor = ActionExecutor(store)
        val seen = ArrayList<ActionEffect>()
        executor.onEffect = { seen.add(it) }
        executor.execute(Action.AnimateForward("fade"))
        executor.execute(Action.CloseDialog)
        assertEquals(state, store.state)
        assertEquals(emptyList(), seen)
        assertFalse(ActionExecutor.implements(Action.ActionGroup(actions = listOf(Action.GoBack, Action.AnimateForward("fade")))))
        assertTrue(
            ActionExecutor.implements(Action.ActionGroup(actions = listOf(Action.GoBack, Action.SetState("a", value = j(1))))),
        )
    }

    /** B10.3-A, Kotlin leg: `switchTab` is one effect carrying the tab id; state stays. */
    @Test
    fun b10_3_A_switchTabEmitsTheTabId() = runSuspend {
        val state = StoreState(page = props("count" to 1))
        val store = ElmStore(state)
        val executor = ActionExecutor(store)
        val seen = ArrayList<ActionEffect>()
        val performed = ArrayList<ActionEffect>()
        executor.onEffect = { seen.add(it) }
        executor.perform = { performed.add(it) }
        executor.execute(Action.SwitchTab("search"))
        assertEquals(listOf(ActionEffect("switchTab", props("tabId" to "search"))), seen)
        assertEquals(seen, performed)
        assertEquals(state, store.state)
        assertTrue(ActionExecutor.implements(Action.SwitchTab("search")))
    }

    /** B10.5-A, Kotlin leg: `openDrawer` is one bare effect; state stays. */
    @Test
    fun b10_5_A_openDrawerEmitsABareEffect() = runSuspend {
        val state = StoreState(page = props("count" to 1))
        val store = ElmStore(state)
        val executor = ActionExecutor(store)
        val seen = ArrayList<ActionEffect>()
        val performed = ArrayList<ActionEffect>()
        executor.onEffect = { seen.add(it) }
        executor.perform = { performed.add(it) }
        executor.execute(Action.OpenDrawer)
        assertEquals(listOf(ActionEffect("openDrawer", emptyMap())), seen)
        assertEquals(seen, performed)
        assertEquals(state, store.state)
        assertTrue(ActionExecutor.implements(Action.OpenDrawer))
    }

    @Test
    fun setStateWritesTheAppScopeAndReadsEventData() {
        val action = Action.SetState("query", StateScope.App, obj("type" to "event", "key" to "text"))
        val (next, _) = ActionReducer().reduce(StoreState(), action, eventData = props("text" to "hi"))
        assertEquals(j("hi"), next.app["query"])
        assertEquals(emptyMap(), next.page)
    }

    @Test
    fun toastDefaultsFollowDart() {
        val (_, effects) = ActionReducer().reduce(
            StoreState(),
            Action.ActionGroup("parallel", listOf(Action.ShowToast(j(5)), Action.ShowSnackbar())),
        )
        assertEquals(
            listOf(
                ActionEffect("showToast", props("message" to "5", "duration" to 2000)),
                ActionEffect("showSnackbar", props("message" to "", "duration" to 4000)),
            ),
            effects,
        )
    }
}
