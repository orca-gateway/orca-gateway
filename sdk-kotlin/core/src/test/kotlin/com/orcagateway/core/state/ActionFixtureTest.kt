package com.orcagateway.core.state

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.support.ActionStub
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.arr
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
 * the Dart executor. Each run seeds the state, runs the steps, and compares
 * the state and the effects as JSON. A fixture with `serverResponses` talks
 * to a stub of the `/action` route, as the Dart runner's stub client does.
 * A fixture with `handlers` registers, for each name, a handler that records
 * `{"kind": "handler", "name": <name>, "action": <the raw action>}` among
 * the effects (fixtures 45-47, custom action handlers), before any step runs.
 *
 * `steps` run in order, each with the widget and trigger that fired it
 * (`source`, so once can dedupe) and its own `event` in place of the
 * fixture's; `actions` run as steps with the fixture's event and no source.
 */
class ActionFixtureTest {
    private class Step(val action: Action, val source: ActionSource?, val event: Map<String, JsonValue>?)

    private fun steps(fx: JsonValue): List<Step> {
        val fixtureEvent = fx["event"].objectValue
        val steps = fx["steps"].arrayValue
            ?: return fx["actions"].arrayValue.orEmpty().map { Step(it.decode(Action.serializer()), null, fixtureEvent) }
        return steps.map { step ->
            val source = step["source"].objectValue?.let {
                ActionSource(widgetId = it.getValue("widgetId").stringValue!!, trigger = it.getValue("trigger").stringValue!!)
            }
            Step(step["action"].decode(Action.serializer()), source, step["event"].objectValue ?: fixtureEvent)
        }
    }

    private suspend fun runFixture(name: String, fx: JsonValue) {
        val handlers = fx["handlers"].arrayValue.orEmpty().map { it.stringValue ?: error("$name: a handler name is a string") }
        val steps = steps(fx)
        assertTrue(steps.all { runs(it.action, handlers) }, "$name: every kind implemented")

        val store = ElmStore(fx["state"].decode(StoreState.serializer()))
        val client = fx["serverResponses"].objectValue?.let { ActionStub.client(ActionStub(it)) }
        val executor = ActionExecutor(store, client)
        val effects = ArrayList<JsonValue>()
        executor.onEffect = { effects.add(it.json) }
        for (handler in handlers) {
            executor.registerHandler(
                handler,
                OrcaActionHandler { action, _ ->
                    effects.add(JsonValue.obj("kind" to "handler", "name" to handler, "action" to JsonValue.fromJsonElement(action)))
                },
            )
        }

        for (step in steps) executor.execute(step.action, eventData = step.event, source = step.source)
        assertJsonEqual(jsonOf(store.state), fx["expected"]["state"], "$name: state")
        assertJsonEqual(JsonValue.Array(effects), fx["expected"]["effects"], "$name: effects")
    }

    /**
     * A built-in the executor implements, an action a fixture handler takes,
     * or a `custom:` action (run by its handler, else the silent no-op
     * fixture 46 pins); groups and once/always are checked member by member.
     */
    private fun runs(action: Action, handlers: List<String>): Boolean = when {
        action is Action.Custom || action.kind in handlers -> true
        action is Action.ActionGroup -> action.actions.all { runs(it, handlers) }
        action is Action.Once -> runs(action.action, handlers)
        action is Action.Always -> runs(action.action, handlers)
        else -> ActionExecutor.implements(action)
    }

    private suspend fun runFixture(file: String) = runFixture(file, Fixtures.json("schema/fixtures/actions/$file"))

    @Test
    fun allTwentySixActionFixturesPass() = runSuspend {
        val files = Fixtures.files("actions")
        assertEquals(26, files.size)
        for ((name, fx) in files) runFixture(name, fx)
    }

    @Test
    fun a2_5_onceRunsOncePerWidgetAndTrigger() = runSuspend { runFixture("16_once_per_widget_trigger.json") }

    @Test
    fun a2_6_alwaysRunsEveryTimeAndDebugLogEmitsItsMessage() = runSuspend { runFixture("17_always_and_debugLog.json") }

    @Test
    fun a2_1_onInitWrappedInOnceRunsOneTime() = runSuspend { runFixture("18_onInit_once.json") }

    @Test
    fun a2_4_scrollTriggersReadOffsetAndExtentThroughTheEvent() = runSuspend { runFixture("19_scroll_event_values.json") }

    // MARK: source and once

    private fun increment(key: String): Action = Action.SetState(
        key,
        value = obj(
            "type" to "transform",
            "input" to obj("type" to "state", "scope" to "page", "key" to key),
            "by" to arr(obj("type" to "add", "by" to obj("type" to "static", "value" to 1))),
        ),
    )

    @Test
    fun theSourceIsInheritedByNestedRunsAndRestoredAfter() = runSuspend {
        val store = ElmStore(StoreState(page = props("a" to 0, "b" to 0, "inner" to 0)))
        val executor = ActionExecutor(store)
        // The host runs another chain from another widget while performing a
        // toast of the first; the first chain's source comes back after it.
        executor.perform = { effect ->
            if (effect.type == "showToast") executor.execute(Action.Once(increment("inner")), source = ActionSource("other", "onTap"))
        }
        val tap = ActionSource("buy", "onTap")
        repeat(2) {
            executor.execute(
                Action.ActionGroup(actions = listOf(Action.ShowToast(j("hi")), Action.Once(increment("a")))),
                source = tap,
            )
        }
        // Back at the top no source is left: once runs every time.
        repeat(2) { executor.execute(Action.Once(increment("b"))) }
        assertEquals(j(1), store.state.page["inner"])
        assertEquals(j(1), store.state.page["a"])
        assertEquals(j(2), store.state.page["b"])
    }

    @Test
    fun onceWithoutASourceRunsEveryTime() = runSuspend {
        val store = ElmStore(StoreState(page = props("n" to 0)))
        val executor = ActionExecutor(store)
        repeat(3) { executor.execute(Action.Once(increment("n"))) }
        executor.executeAll(listOf(Action.Once(increment("n")), Action.Once(increment("n"))))
        assertEquals(j(5), store.state.page["n"])
    }

    /**
     * Flutter's known limit, kept: the key is the widget and the trigger, not
     * the wrapper, so a second once under the same tap never runs.
     */
    @Test
    fun twoOnceUnderOneWidgetAndTriggerShareTheirKey() = runSuspend {
        val store = ElmStore(StoreState(page = props("a" to 0, "b" to 0)))
        val executor = ActionExecutor(store)
        executor.execute(
            Action.ActionGroup("sequential", listOf(Action.Once(increment("a")), Action.Once(increment("b")))),
            source = ActionSource("buy", "onTap"),
        )
        assertEquals(j(1), store.state.page["a"])
        assertEquals(j(0), store.state.page["b"])
    }

    @Test
    fun implementsLooksInsideOnceAndAlways() {
        assertTrue(ActionExecutor.implements(Action.Once(Action.GoBack)))
        assertTrue(ActionExecutor.implements(Action.Always(Action.DebugLog())))
        assertFalse(ActionExecutor.implements(Action.Once(Action.RefetchPage)))
        assertFalse(ActionExecutor.implements(Action.Always(Action.ActionGroup(actions = listOf(Action.RefetchPage)))))
    }

    @Test
    fun unimplementedKindsChangeNothing() = runSuspend {
        val state = StoreState(page = props("count" to 1))
        val (next, effects) = ActionReducer().reduce(state, Action.RefetchPage)
        assertEquals(state, next)
        assertEquals(emptyList(), effects)

        val store = ElmStore(state)
        val executor = ActionExecutor(store)
        val seen = ArrayList<ActionEffect>()
        executor.onEffect = { seen.add(it) }
        executor.execute(Action.RefetchPage)
        executor.execute(Action.CloseDialog)
        assertEquals(state, store.state)
        assertEquals(emptyList(), seen)
        assertFalse(ActionExecutor.implements(Action.ActionGroup(actions = listOf(Action.GoBack, Action.RefetchPage))))
        assertTrue(
            ActionExecutor.implements(Action.ActionGroup(actions = listOf(Action.GoBack, Action.SetState("a", value = j(1))))),
        )
    }

    /** B12.1-K: both kinds emit the animation id, in their place in a sequential group; state stays. */
    @Test
    fun b12_1_K_animateForwardAndReverseEmitTheAnimationId() = runSuspend { runFixture("32_animate_forward_reverse.json") }

    /** B12.1-K: an id no builder registered still goes out, and the group runs on. */
    @Test
    fun b12_1_K_anUnknownAnimationIdStillEmitsAndTheGroupGoesOn() = runSuspend { runFixture("33_animate_unknown_id.json") }

    /** B12.1-K: one effect each, reported then performed; an empty id emits nothing (Dart returns on a missing id). */
    @Test
    fun b12_1_K_animateEffectsArePerformedAndAnEmptyIdEmitsNothing() = runSuspend {
        val state = StoreState(page = props("count" to 1))
        val store = ElmStore(state)
        val executor = ActionExecutor(store)
        val seen = ArrayList<ActionEffect>()
        val performed = ArrayList<ActionEffect>()
        executor.onEffect = { seen.add(it) }
        executor.perform = { performed.add(it) }
        executor.execute(Action.AnimateForward("pulse"))
        executor.execute(Action.AnimateReverse("pulse"))
        executor.execute(Action.ActionGroup(actions = listOf(Action.AnimateForward(""), Action.AnimateReverse(""), Action.GoBack)))
        assertEquals(
            listOf(
                ActionEffect("animateForward", props("animationId" to "pulse")),
                ActionEffect("animateReverse", props("animationId" to "pulse")),
                ActionEffect("goBack"),
            ),
            seen,
        )
        assertEquals(seen, performed)
        assertEquals(state, store.state)
        assertTrue(ActionExecutor.implements(Action.AnimateForward("pulse")))
        assertTrue(ActionExecutor.implements(Action.AnimateReverse("pulse")))
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
