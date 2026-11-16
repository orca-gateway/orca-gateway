package com.orcagateway.core.debug

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull

/** Keeps every event it is given, in order, from any thread. */
private class TraceRecorder : DevToolsReporter {
    private val recorded = ArrayList<DevToolsEvent>()

    val events: List<DevToolsEvent> get() = synchronized(recorded) { recorded.toList() }

    fun of(type: String): List<DevToolsEvent> = events.filter { it.type == type }

    override fun report(event: DevToolsEvent) {
        synchronized(recorded) { recorded.add(event) }
    }
}

/**
 * C19.2 and C19.6 on Kotlin, against Flutter's executor
 * (sdk/lib/src/state/action_executor.dart:165-207, 255-298): a setState's
 * own `action` event carries its transform value's trace and the page's
 * nodes watching its key, in the page's order; a debugLog reaches DevTools
 * as its generic `action` event and nothing more.
 */
class ActionTraceTest {
    private val recorder = TraceRecorder()

    /** schema/fixtures/devtools/action-traced.json's payload: Flutter's setState `count` = count + 1 at count 0. */
    private val fixture: JsonValue = Fixtures.json("schema/fixtures/devtools/action-traced.json")["payload"]

    /** The fixture's own action. */
    private val traced: Action = fixture["data"].decode(Action.serializer())

    @AfterTest
    fun resetReporter() {
        OrcaDebug.reporter = null
    }

    private fun node(id: String, type: String, vararg watches: String): ComponentNode =
        ComponentNode(id, type, ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, watches = watches.toList())

    /**
     * The fixture's page: 5 and 8 watch `count`; 1 watches nothing, 7 a
     * dotted path and a longer key of it, 9 another key (no match for any).
     */
    private val page = listOf(
        node("1", "Column"),
        node("5", "Text", "count"),
        node("7", "Text", "count.total", "counter"),
        node("8", "Container", "count", "theme"),
        node("9", "Text", "theme"),
    )

    /** A `home` page store at count 0 and theme "dark", and its executor with [nodes] as the page hook. */
    private fun executor(nodes: List<ComponentNode>? = page): ActionExecutor {
        val store = ElmStore(props("count" to 0, "theme" to "dark"))
        store.pageId = "home"
        return ActionExecutor(store).apply { if (nodes != null) pageNodes = { nodes } }
    }

    /** The one `action` event for [kind]. */
    private fun event(kind: String): DevToolsEvent = recorder.of("action").single { it.payload["actionType"] == j(kind) }

    /**
     * C19.2/K: the fixture's own setState, run at count 0 with a page of
     * nodes 5, 8 and non-watchers, reports the fixture's payload exactly
     * (all but the measured duration), and the hook is read after the state
     * is written, as Flutter does.
     */
    @Test
    fun c19_2_k_aTransformSetStateCarriesTheFixturesTraceAndAffectedWidgets() = runSuspend {
        OrcaDebug.reporter = recorder
        val executor = executor(nodes = null)
        val countWhenAsked = ArrayList<JsonValue?>()
        executor.pageNodes = {
            countWhenAsked += executor.store.state.page["count"]
            page
        }
        executor.execute(traced)

        val payload = event("setState").payload
        assertJsonEqual(assertNotNull(payload["transformTrace"]), fixture["transformTrace"], "transformTrace")
        assertJsonEqual(assertNotNull(payload["affectedWidgets"]), fixture["affectedWidgets"], "affectedWidgets")
        assertJsonEqual(
            JsonValue.Object(payload - "durationMs"),
            JsonValue.Object(assertNotNull(fixture.objectValue) - "durationMs"),
            "the whole payload but the duration",
        )
        assertEquals(j(1), executor.store.state.page["count"])
        assertEquals(listOf<JsonValue?>(j(1)), countWhenAsked, "asked once, after the write")
    }

    /** C19.2/K: a value that is no transform (a state ref, a literal) carries no trace; its watchers are still listed. */
    @Test
    fun c19_2_k_aValueThatIsNoTransformCarriesAffectedWidgetsOnly() = runSuspend {
        OrcaDebug.reporter = recorder
        val executor = executor()
        executor.execute(Action.SetState(key = "count", value = obj("type" to "state", "key" to "theme", "scope" to "page")))
        executor.execute(Action.SetState(key = "count", value = j(7)))

        val events = recorder.of("action")
        assertEquals(2, events.size)
        for (event in events) {
            assertFalse("transformTrace" in event.payload, "no trace: ${event.payload}")
            assertJsonEqual(assertNotNull(event.payload["affectedWidgets"]), fixture["affectedWidgets"], "the watchers of count")
        }
        assertEquals(j(7), executor.store.state.page["count"])
    }

    /** C19.2/K: no node watches the key, or no page hook: no affectedWidgets key at all; the trace still goes. */
    @Test
    fun c19_2_k_noWatcherMeansNoAffectedWidgetsKey() = runSuspend {
        OrcaDebug.reporter = recorder
        val plusOne = obj(
            "type" to "transform",
            "input" to obj("type" to "state", "key" to "nobody", "scope" to "page"),
            "by" to arr(obj("type" to "add", "by" to obj("type" to "static", "value" to 1))),
        )
        executor().execute(Action.SetState(key = "nobody", value = plusOne))
        executor(nodes = null).execute(traced)

        val events = recorder.of("action")
        assertEquals(2, events.size)
        for (event in events) {
            assertFalse("affectedWidgets" in event.payload, "no watcher: ${event.payload}")
            assertNotNull(event.payload["transformTrace"], "the trace still goes")
        }
    }

    /** C19.2/K: the watchers are listed in the page's wire order (Flutter's nodeMap): 8 before 5 when sent so. */
    @Test
    fun c19_2_k_theWireOrderOfThePageIsKept() = runSuspend {
        OrcaDebug.reporter = recorder
        executor(nodes = listOf(node("8", "Container", "count", "theme"), node("1", "Column"), node("5", "Text", "count"))).execute(traced)

        assertJsonEqual(
            assertNotNull(event("setState").payload["affectedWidgets"]),
            arr(
                obj("id" to "8", "type" to "Container", "watches" to arr("count", "theme")),
                obj("id" to "5", "type" to "Text", "watches" to arr("count")),
            ),
        )
    }

    /** C19.2/K: in a sequential group only the setState's own event carries the two fields; its sibling and its group do not. */
    @Test
    fun c19_2_k_onlyTheSetStatesOwnEventCarriesThem() = runSuspend {
        OrcaDebug.reporter = recorder
        executor().execute(Action.ActionGroup(actions = listOf(traced, Action.ShowToast(message = j("done")))))

        val events = recorder.of("action")
        assertEquals(listOf(j("setState"), j("showToast"), j("actionGroup")), events.map { it.payload["actionType"] })
        assertNotNull(events[0].payload["transformTrace"])
        assertNotNull(events[0].payload["affectedWidgets"])
        for (event in events.drop(1)) {
            assertFalse("transformTrace" in event.payload || "affectedWidgets" in event.payload, "${event.payload}")
        }
    }

    /** C19.2/K: with DevTools off the page hook is never asked and the value resolves as before. */
    @Test
    fun c19_2_k_withDevToolsOffTheHookIsNeverAsked() = runSuspend {
        val executor = executor(nodes = null)
        var asked = 0
        executor.pageNodes = {
            asked += 1
            page
        }
        executor.execute(traced)
        executor.execute(traced)

        assertEquals(0, asked)
        assertEquals(j(2), executor.store.state.page["count"])
    }

    /**
     * C19.6/K: a debugLog reaches DevTools as its `action` event (actionType
     * debugLog, family custom, data = the action) and nothing else; its
     * effect still goes out for the platform log.
     */
    @Test
    fun c19_6_k_aDebugLogReachesDevToolsAsItsActionEventOnly() = runSuspend {
        OrcaDebug.reporter = recorder
        val executor = executor()
        val effects = ArrayList<ActionEffect>()
        executor.onEffect = { effects += it }
        val log = Action.DebugLog(level = "warn", message = j("hello"), tag = "trace-test", data = obj("n" to 3))
        executor.execute(log)

        assertEquals(listOf("action"), recorder.events.map { it.type }, "one event, no other type")
        val payload = recorder.events.single().payload
        assertJsonEqual(
            JsonValue.Object(payload - "durationMs"),
            obj("actionType" to "debugLog", "family" to "custom", "pageId" to "home", "data" to log.json),
        )
        assertEquals(listOf("debugLog"), effects.map { it.type })
        assertEquals(j("hello"), effects.single().payload["message"])
    }
}
