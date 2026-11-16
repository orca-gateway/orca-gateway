package com.orcagateway.core.state

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/**
 * C16.2: custom action handlers on [ActionExecutor], as Dart's
 * `registerHandler` and `execute` (sdk/lib/src/state/action_executor.dart):
 * exact type first, then the type without `custom:`, the raw action object,
 * built-ins replaceable, unhandled kinds a silent no-op, and `resolve` for
 * the handler's own values.
 */
class ActionHandlerTest {
    /** The handler name and the raw action of every handler call, in order. */
    private class Calls {
        val list = ArrayList<Pair<String, JsonValue>>()

        fun handler(name: String) = OrcaActionHandler { action, _ -> list.add(name to JsonValue.fromJsonElement(action)) }
    }

    private fun executor(state: StoreState = StoreState()): Triple<ActionExecutor, ElmStore, ArrayList<ActionEffect>> {
        val store = ElmStore(state)
        val executor = ActionExecutor(store)
        val effects = ArrayList<ActionEffect>()
        executor.onEffect = { effects.add(it) }
        return Triple(executor, store, effects)
    }

    private fun decode(json: JsonValue): Action = json.decode(Action.serializer())

    @Test
    fun c16_2_anExactMatchWinsOverTheBareType(): Unit = runSuspend {
        val (executor, _, _) = executor()
        val calls = Calls()
        executor.registerHandler("ping", calls.handler("ping"))
        executor.registerHandler("custom:ping", calls.handler("custom:ping"))
        executor.execute(decode(obj("type" to "custom:ping", "id" to 1)))
        assertEquals(listOf("custom:ping" to obj("type" to "custom:ping", "id" to 1)), calls.list)
    }

    @Test
    fun c16_2_aPrefixedTypeReachesTheHandlerOfItsBareName(): Unit = runSuspend {
        val (executor, _, effects) = executor()
        val calls = Calls()
        executor.registerHandler("x", calls.handler("x"))
        executor.execute(decode(obj("type" to "custom:x")))
        assertEquals(listOf("x" to obj("type" to "custom:x")), calls.list)
        assertEquals(emptyList(), effects)
    }

    @Test
    fun c16_2_aBareTypeReachesItsHandler(): Unit = runSuspend {
        val (executor, _, _) = executor()
        val calls = Calls()
        executor.registerHandler("x", calls.handler("x"))
        executor.execute(decode(obj("type" to "x", "n" to 2)))
        assertEquals(listOf("x" to obj("type" to "x", "n" to 2)), calls.list)
    }

    @Test
    fun c16_2_theHandlerGetsTheRawObjectWithItsParamsUnresolved(): Unit = runSuspend {
        val (executor, _, _) = executor(StoreState(page = props("n" to 7)))
        val calls = Calls()
        executor.registerHandler("hapticFeedback", calls.handler("hapticFeedback"))
        val sent = obj(
            "type" to "custom:hapticFeedback",
            "intensity" to "heavy",
            "count" to obj("type" to "state", "scope" to "page", "key" to "n"),
            "pattern" to arr(1, 2.5),
        )
        executor.execute(decode(sent))
        assertEquals(1, calls.list.size)
        assertJsonEqual(calls.list[0].second, sent, "raw action")
    }

    @Test
    fun c16_2_reRegisteringATypeReplacesItsHandler(): Unit = runSuspend {
        val (executor, _, _) = executor()
        val calls = Calls()
        executor.registerHandler("x", calls.handler("first"))
        executor.registerHandler("x", calls.handler("second"))
        executor.execute(decode(obj("type" to "custom:x")))
        assertEquals(listOf("second"), calls.list.map { it.first })
    }

    @Test
    fun c16_2_aHandlerUnderABuiltInNameReplacesTheBuiltIn(): Unit = runSuspend {
        val (executor, _, effects) = executor()
        val calls = Calls()
        executor.registerHandler("navigate", calls.handler("navigate"))
        val sent = obj("type" to "navigate", "route" to "/next", "replace" to true)
        executor.execute(decode(sent))
        assertEquals(emptyList(), effects, "no built-in navigation")
        assertEquals(1, calls.list.size)
        assertJsonEqual(calls.list[0].second, sent, "the typed built-in re-encoded as sent")
    }

    @Test
    fun c16_2_anUnhandledCustomActionDoesNothingAndItsGroupGoesOn(): Unit = runSuspend {
        val (executor, store, effects) = executor(StoreState(page = props("count" to 0)))
        executor.registerHandler("other", Calls().handler("other"))
        executor.execute(
            decode(
                obj(
                    "type" to "actionGroup",
                    "mode" to "sequential",
                    "actions" to arr(
                        obj("type" to "custom:rateApp", "stars" to 5),
                        obj("type" to "setState", "key" to "count", "value" to obj("type" to "static", "value" to 1)),
                    ),
                ),
            ),
        )
        assertEquals(j(1), store.state.page["count"])
        assertEquals(emptyList(), effects)
    }

    @Test
    fun c16_2_resolveReadsEventDataAndPageStateInsideAHandler(): Unit = runSuspend {
        val (executor, _, _) = executor(StoreState(page = props("n" to 7), app = props("user" to "amr")))
        val seen = ArrayList<JsonValue>()
        executor.registerHandler(
            "read",
            OrcaActionHandler { action, exec ->
                val raw = JsonValue.fromJsonElement(action)
                for (key in listOf("text", "count", "user", "plain")) {
                    seen.add(JsonValue.fromJsonElement(exec.resolve(raw[key].toJsonElement())))
                }
            },
        )
        executor.execute(
            decode(
                obj(
                    "type" to "custom:read",
                    "text" to obj("type" to "event", "key" to "text"),
                    "count" to obj("type" to "state", "scope" to "page", "key" to "n"),
                    "user" to obj("type" to "state", "scope" to "app", "key" to "user"),
                    "plain" to "as is",
                ),
            ),
            eventData = props("text" to "hi"),
        )
        assertEquals(listOf(j("hi"), j(7), j("amr"), j("as is")), seen)
    }

    @Test
    fun c16_2_aHandlerErrorPropagatesAsAnyActionError(): Unit = runSuspend {
        val (executor, _, _) = executor()
        executor.registerHandler("boom", OrcaActionHandler { _, _ -> throw IllegalStateException("boom") })
        val error = assertFailsWith<IllegalStateException> { executor.execute(decode(obj("type" to "custom:boom"))) }
        assertEquals("boom", error.message)
    }

    @Test
    fun c16_2_kindsStayTheBuiltInList(): Unit = runSuspend {
        val before = ActionExecutor.kinds
        val (executor, _, _) = executor()
        executor.registerHandler("custom:x", Calls().handler("x"))
        executor.registerHandler("navigate", Calls().handler("navigate"))
        assertEquals(before, ActionExecutor.kinds)
        assertEquals(
            setOf(
                "setState", "actionGroup", "showSnackbar", "showToast", "conditionalAction",
                "lifecycle", "navigate", "goBack", "switchTab", "openDrawer", "openUrl", "copyToClipboard", "share",
                "serverAction", "addComponent", "updateComponent", "deleteComponent", "replaceComponent",
                "once", "always", "debugLog", "animateForward", "animateReverse", "updateSubPage",
            ),
            ActionExecutor.kinds,
        )
    }
}
