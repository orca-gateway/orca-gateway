package com.orcagateway.core.state

import com.orcagateway.core.debug.DevToolsReporter
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.resume
import kotlin.coroutines.startCoroutine
import kotlin.coroutines.suspendCoroutine
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

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
        // A5.6: refetchPage is a built-in that does nothing on its own; the
        // page loader's handler reloads (Flutter's onRefetchPage). A8.1: so
        // are openDialog and closeDialog; the page's handlers show and close
        // the sheet (Flutter's OrcaPage).
        assertEquals(
            setOf(
                "setState", "actionGroup", "showSnackbar", "showToast", "conditionalAction",
                "lifecycle", "navigate", "goBack", "switchTab", "openDrawer", "openUrl", "copyToClipboard", "share",
                "serverAction", "addComponent", "updateComponent", "deleteComponent", "replaceComponent",
                "once", "always", "debugLog", "animateForward", "animateReverse", "updateSubPage", "refetchPage",
                "persistState", "clearState", "openDialog", "closeDialog",
            ),
            ActionExecutor.kinds,
        )
    }

    // A8.1 openDialog and closeDialog

    /**
     * A8.1: both are known kinds, as Flutter's executor has a built-in
     * handler for each (sdk/lib/src/state/action_executor.dart:862-871,
     * :894-919), so a chain holding them counts as implemented.
     */
    @Test
    fun a8_1_openDialogAndCloseDialogAreKnownKinds() {
        assertTrue(ActionExecutor.kinds.containsAll(setOf("openDialog", "closeDialog")), "not executor kinds")
        assertTrue(ActionExecutor.implements(Action.OpenDialog("d", heightFactor = 0.4)), "openDialog not implemented")
        assertTrue(ActionExecutor.implements(Action.CloseDialog), "closeDialog not implemented")
        assertTrue(
            ActionExecutor.implements(
                Action.ActionGroup(actions = listOf(Action.OpenDialog("d"), Action.Always(Action.Once(Action.CloseDialog)))),
            ),
            "a chain holding both not implemented",
        )
    }

    /**
     * A8.1: with no page handler each runs nothing: no state change and no
     * effect (Flutter's openDialog awaits a null onOpenDialog, its
     * closeDialog has no context), the chain goes on, and DevTools hears
     * each as a run action, as Flutter reports every action a handler took.
     */
    @Test
    fun a8_1_withNoHandlerBothChangeNoStateAndEmitNoEffect(): Unit = runSuspend {
        val reported = ArrayList<JsonValue?>()
        OrcaDebug.reporter = DevToolsReporter { if (it.type == "action") reported.add(it.payload["actionType"]) }
        try {
            val state = StoreState(page = props("count" to 0, "flag" to true), app = props("user" to "amr"))
            val (executor, store, effects) = executor(state)
            executor.execute(
                decode(
                    obj(
                        "type" to "actionGroup",
                        "mode" to "sequential",
                        "actions" to arr(
                            obj("type" to "openDialog", "dialogId" to "d", "heightFactor" to 0.4),
                            obj("type" to "closeDialog"),
                            obj("type" to "setState", "key" to "count", "value" to obj("type" to "static", "value" to 1)),
                        ),
                    ),
                ),
            )
            assertEquals(state.copy(page = props("count" to 1, "flag" to true)), store.state, "only the setState after them changed state")
            assertEquals(emptyList(), effects)
            assertEquals<List<JsonValue?>>(listOf(j("openDialog"), j("closeDialog"), j("setState"), j("actionGroup")), reported)
        } finally {
            OrcaDebug.reporter = null
        }
    }

    /**
     * A8.1: a page registers openDialog and closeDialog as it registers
     * refetchPage: each handler gets the action as sent (dialogId and
     * heightFactor), and nothing goes out as an effect.
     */
    @Test
    fun a8_1_aRegisteredHandlerRunsWithTheAction(): Unit = runSuspend {
        val (executor, _, effects) = executor()
        val calls = Calls()
        executor.registerHandler("openDialog", calls.handler("openDialog"))
        executor.registerHandler("closeDialog", calls.handler("closeDialog"))
        executor.execute(Action.OpenDialog("confirm", heightFactor = 0.4))
        executor.execute(Action.OpenDialog("plain"))
        executor.execute(Action.CloseDialog)
        assertEquals(listOf("openDialog", "openDialog", "closeDialog"), calls.list.map { it.first })
        assertEquals(
            listOf(
                obj("type" to "openDialog", "dialogId" to "confirm", "heightFactor" to 0.4),
                obj("type" to "openDialog", "dialogId" to "plain"),
                obj("type" to "closeDialog"),
            ),
            calls.list.map { it.second },
        )
        assertEquals(emptyList(), effects)
    }

    /**
     * A8.1: the action after openDialog in a sequential group runs only once
     * the page's handler returns, that is once its sheet has closed
     * (Flutter awaits showModalBottomSheet, orca_page.dart:346).
     */
    @Test
    fun a8_1_theNextActionWaitsForTheOpenDialogHandler() {
        val (executor, store, _) = executor(StoreState(page = props("after" to 0)))
        var sheet: Continuation<Unit>? = null
        executor.registerHandler("openDialog", OrcaActionHandler { _, _ -> suspendCoroutine<Unit> { sheet = it } })
        var result: Result<Unit>? = null
        val chain: suspend () -> Unit = {
            executor.execute(
                Action.ActionGroup(
                    "sequential",
                    listOf(Action.OpenDialog("d", heightFactor = 0.4), Action.SetState("after", value = j(1))),
                ),
            )
        }
        chain.startCoroutine(Continuation(EmptyCoroutineContext) { result = it })
        assertNotNull(sheet, "the handler never started")
        assertEquals(j(0), store.state.page["after"], "ran before the sheet closed")
        assertNull(result, "the chain ended before the sheet closed")
        sheet.resume(Unit)
        assertEquals(Result.success(Unit), result)
        assertEquals(j(1), store.state.page["after"])
    }
}
