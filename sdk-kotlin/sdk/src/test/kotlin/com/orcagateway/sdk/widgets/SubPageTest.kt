package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasProgressBarRangeInfo
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ActionList
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.LocalOrcaFrozenNodes
import com.orcagateway.sdk.LocalOrcaNodeRecorder
import com.orcagateway.sdk.OrcaNodeSnapshot
import com.orcagateway.sdk.NodeObserver
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.CompletableDeferred
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun state(key: String, scope: String = "page"): JsonValue = JsonValue.obj("type" to "state", "key" to key, "scope" to scope)

/** A Text showing page-state [key]. */
private fun watching(id: String, key: String): ComponentNode =
    ComponentNode(id, "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, mapOf("data" to state(key)), watches = listOf(key))

/** `setState(key, key + 1)`. */
private fun increment(key: String): Action = Action.SetState(
    key = key,
    value = JsonValue.parse(
        """{"type":"transform","input":{"type":"state","key":"$key","scope":"page"},"by":[{"type":"add","by":{"type":"static","value":1}}]}""",
    ),
)

private fun structure(id: String, type: String, slots: Map<String, String>): ComponentNode = ComponentNode(
    id, type, ComponentNode.Kind.Structure, ComponentNode.ChildMode.None, slots.mapValues { JsonValue.String(it.value) }, slots.values.toList(),
)

/** A SubPage node with [pageId] (a string or a Value), [params] and maybe a loading [child]. */
private fun subPage(id: String, pageId: Any, params: JsonValue? = null, child: String? = null, watches: List<String> = emptyList()): ComponentNode {
    val props = LinkedHashMap<String, JsonValue>()
    props["pageId"] = pageId as? JsonValue ?: JsonValue.String(pageId as String)
    params?.let { props["params"] = it }
    return ComponentNode(id, "SubPage", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, props, listOfNotNull(child), watches)
}

private fun pageOf(id: String, vararg nodes: ComponentNode, state: Map<String, Any?> = emptyMap()): PageResponse = PageResponse(
    pageId = id, title = id, components = nodes.toList(),
    state = state.map { (key, initial) -> StateDefinition(key, StateScope.Page, JsonValue.of(initial)) },
)

/**
 * A counter page named [name]: the label "Page [name]", the page-state `count` (from [count]) and a button
 * "Add [name]" that adds one to it. Every page uses the same ids and the same key, as two real pages may.
 */
private fun counter(name: String, count: Int): PageResponse = pageOf(
    name,
    column("r", "label", "value", "add"),
    text("label", "Page $name"),
    watching("value", "count"),
    button("add", "TextButton", "addLabel", mapOf("onTap" to increment("count"))),
    text("addLabel", "Add $name"),
    state = mapOf("count" to count),
)

/** The engine behind a host page: pages by id, `/action` answering [actions], every request kept. */
private class Engine(vararg pages: PageResponse) : HttpTransport {
    val pages = pages.associateByTo(HashMap()) { it.pageId }
    val requests = ArrayList<HttpRequest>()

    /** Page ids answered 500 with this text. */
    val broken = HashMap<String, String>()

    /** Page ids whose answer waits until the gate is completed. */
    val gates = HashMap<String, CompletableDeferred<Unit>>()

    /** The `actions` of every `/action` answer. */
    var actions: JsonValue = JsonValue.arr()

    /** What came after `/page/` in each page request, in order. */
    val locations: List<String>
        get() = requests.map { it.url.toString() }.filter { "/page/" in it }.map { it.substringAfter("/page/") }

    override suspend fun send(request: HttpRequest): HttpResponse {
        requests.add(request)
        if (request.url.path.endsWith("/action")) {
            return HttpResponse(200, body = JsonValue.obj("actions" to actions).encoded().encodeToByteArray())
        }
        val id = request.url.path.substringAfter("/page/")
        gates[id]?.await()
        broken[id]?.let { return HttpResponse(500, body = it.encodeToByteArray()) }
        val page = pages[id] ?: return HttpResponse(404, body = "no page $id".encodeToByteArray())
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    val client: OrcaClient get() = OrcaClient(URI("http://stub.invalid"), "app", transport = this)
}

/**
 * B13.4-K and B13.5-K, the UI part: the SubPage widget fetches, mounts through the core (`SubPageHost`) and
 * draws (contract S4, S5, S8), `updateSubPage` replaces or joins (S7), and a server action fired inside sees the
 * sub-page only (S6). The rewrite itself is pinned by the shared fixtures (core `SubPageFixtureTest`).
 *
 * The host page: a column with its own `count` (7), then the SubPage `sp`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class SubPageTest {
    @get:Rule
    val compose = createComposeRule()

    private val spinner: SemanticsMatcher = hasProgressBarRangeInfo(ProgressBarRangeInfo.Indeterminate)

    private fun host(subPage: ComponentNode, vararg more: ComponentNode, state: Map<String, Any?> = emptyMap()): PageResponse = pageOf(
        "host",
        column("root", "hostValue", subPage.id, *more.filter { it.id.startsWith("top") }.map { it.id }.toTypedArray()),
        watching("hostValue", "count"),
        subPage,
        *more,
        state = mapOf("count" to 7) + state,
    )

    private fun show(engine: Engine, page: PageResponse, app: Map<String, JsonValue> = emptyMap()): OrcaPageModel {
        val model = OrcaPageModel(page, store = ElmStore(StoreState(app = app)), client = engine.client)
        compose.setContent {
            Box(Modifier.size(300.dp, 600.dp)) { NodeView("root", model) }
        }
        compose.waitForIdle()
        return model
    }

    private fun shown(text: String) = compose.onNodeWithText(text).assertIsDisplayed()

    private fun gone(text: String) = compose.onNodeWithText(text).assertDoesNotExist()

    private fun top(text: String) = compose.onNodeWithText(text).getUnclippedBoundsInRoot().top

    private fun run(model: OrcaPageModel, action: Action) {
        compose.runOnIdle { model.fire("onTap", ResolvedNode("root", "Column", ComponentNode.Kind.Layout, emptyMap(), emptyList(), emptyMap(), mapOf("onTap" to action), emptyList())) }
        compose.waitForIdle()
    }

    private fun update(pageId: String, mode: String? = null, id: String = "sp", params: Map<String, JsonValue>? = null): Action =
        Action.UpdateSubPage(JsonValue.String(id), JsonValue.String(pageId), params, mode?.let { JsonValue.String(it) })

    // MARK: B13.4-K, the widget

    /** S4: the page id is the path, the resolved params the query, keys sorted; app state is posted. */
    @Test
    fun b13_4_theParamsReachTheRequestPathAndAppStateIsPosted() {
        val engine = Engine(counter("a", 1))
        val params = JsonValue.obj("z" to "last one", "first" to state("count"))
        val model = show(engine, host(subPage("sp", "a", params)), app = mapOf("user" to JsonValue.String("amr")))

        assertEquals(listOf("a?first=7&z=last%20one"), engine.locations)
        val request = engine.requests.single()
        assertEquals("POST", request.method)
        assertEquals(JsonValue.obj("appState" to JsonValue.obj("user" to "amr")), JsonValue.parse(request.body!!))
        shown("Page a")
        assertTrue("sp:r" in model.renderer.nodes)
    }

    /** S2 b: a structure node's slots are rewritten, so a Scaffold with an AppBar draws inside a sub-page. */
    @Test
    fun b13_4_aScaffoldWithAnAppBarInsideDraws() {
        val inner = pageOf(
            "a",
            structure("page", "Scaffold", mapOf("appBar" to "bar", "body" to "body")),
            structure("bar", "AppBar", mapOf("title" to "title")),
            text("title", "Inbox"),
            text("body", "Messages"),
        )
        show(Engine(inner), host(subPage("sp", "a")))
        shown("Inbox")
        shown("Messages")
        assertTrue(top("Inbox") < top("Messages"))
    }

    /** S2, S3: the sub-page's `count` is `sp:count`; the host's `count` is another key. */
    @Test
    fun b13_4_theSubPagesStateIsItsOwnAndDoesNotClashWithTheHost() {
        val model = show(Engine(counter("a", 1)), host(subPage("sp", "a")))
        assertEquals(mapOf("count" to JsonValue.Int(7), "sp:count" to JsonValue.Int(1)), model.store.state.page)
        shown("7")
        shown("1")
        assertTrue(top("7") < top("Page a"))
    }

    /** A setState inside writes the prefixed key, and only the node of the sub-page that shows it is drawn again. */
    @Test
    fun b13_4_aSetStateInsideWritesThePrefixedKeyAndOnlyTheSubPageRedraws() {
        val model = show(Engine(counter("a", 1)), host(subPage("sp", "a")))
        val hostValue = NodeObserver(model, "hostValue")
        val value = NodeObserver(model, "sp:value")

        compose.onNodeWithText("Add a").performClick()
        compose.waitForIdle()

        assertEquals(mapOf("count" to JsonValue.Int(7), "sp:count" to JsonValue.Int(2)), model.store.state.page)
        shown("2")
        shown("7")
        assertEquals(1, value.revision)
        assertEquals(0, hostValue.revision)
    }

    /** S5: while the first fetch runs the child is drawn, and the page takes its place. */
    @Test
    fun b13_4_whileTheFirstFetchRunsItDrawsTheChild() {
        val engine = Engine(counter("a", 1))
        val gate = CompletableDeferred<Unit>().also { engine.gates["a"] = it }
        show(engine, host(subPage("sp", "a", child = "wait"), text("wait", "Loading feed")))
        shown("Loading feed")
        compose.onNode(spinner).assertDoesNotExist()

        compose.runOnIdle { gate.complete(Unit) }
        compose.waitForIdle()
        gone("Loading feed")
        shown("Page a")
    }

    /** S5: with no child, a progress indicator. */
    @Test
    fun b13_4_whileTheFirstFetchRunsWithNoChildItDrawsASpinner() {
        val engine = Engine(counter("a", 1))
        val gate = CompletableDeferred<Unit>().also { engine.gates["a"] = it }
        show(engine, host(subPage("sp", "a")))
        compose.onNode(spinner).assertExists()

        compose.runOnIdle { gate.complete(Unit) }
        compose.waitForIdle()
        compose.onNode(spinner).assertDoesNotExist()
        shown("Page a")
    }

    /** S5: a failed fetch draws `SubPage error: <message>`. */
    @Test
    fun b13_4_aFailedFetchDrawsTheErrorText() {
        val engine = Engine().also { it.broken["a"] = "boom" }
        val model = show(engine, host(subPage("sp", "a", child = "wait"), text("wait", "Loading feed")))
        shown("SubPage error: Failed to fetch page: 500")
        gone("Loading feed")
        assertEquals(setOf("root", "hostValue", "sp", "wait"), model.renderer.nodes.keys)
    }

    /** S4: a new resolved pageId, or new resolved params, fetches again and replaces; a redraw alone does not. */
    @Test
    fun b13_4_aPageIdOrParamsChangeRefetchesAsAReplace() {
        val engine = Engine(counter("a", 1), counter("b", 20))
        val node = subPage("sp", state("which"), JsonValue.obj("q" to state("q")), watches = listOf("which", "q"))
        val model = show(engine, host(node, state = mapOf("which" to "a", "q" to 1)))
        shown("Page a")

        compose.runOnIdle { model.store.dispatch(mapOf("count" to JsonValue.Int(8))) }
        compose.waitForIdle()
        assertEquals(listOf("a?q=1"), engine.locations, "a change the SubPage does not read fetches nothing")

        compose.runOnIdle { model.store.dispatch(mapOf("which" to JsonValue.String("b"))) }
        compose.waitForIdle()
        shown("Page b")
        gone("Page a")
        assertEquals(JsonValue.Int(20), model.store.value("sp:count"))

        compose.runOnIdle { model.store.dispatch(mapOf("q" to JsonValue.Int(2))) }
        compose.waitForIdle()
        assertEquals(listOf("a?q=1", "b?q=1", "b?q=2"), engine.locations)
        assertEquals(listOf("sp:"), model.subPages.prefixes)
    }

    /** A fetch a newer one overtook is dropped when it answers. */
    @Test
    fun b13_4_anAnswerOvertakenByANewerFetchIsIgnored() {
        val engine = Engine(counter("a", 1), counter("b", 20))
        val gate = CompletableDeferred<Unit>().also { engine.gates["a"] = it }
        val model = show(engine, host(subPage("sp", state("which"), watches = listOf("which")), state = mapOf("which" to "a")))

        compose.runOnIdle { model.store.dispatch(mapOf("which" to JsonValue.String("b"))) }
        compose.waitForIdle()
        shown("Page b")

        compose.runOnIdle { gate.complete(Unit) }
        compose.waitForIdle()
        shown("Page b")
        gone("Page a")
        assertEquals(JsonValue.Int(20), model.store.value("sp:count"))
    }

    /** S8: when the SubPage node goes, its nodes go and its state keys stay; an answer still out is dropped. */
    @Test
    fun b13_4_removingTheSubPageNodeRemovesItsNodesAndLeavesItsState() {
        val engine = Engine(counter("a", 1), counter("b", 20))
        val model = show(engine, host(subPage("sp", "a")))
        assertTrue("sp:value" in model.renderer.nodes)

        compose.runOnIdle { model.apply(ComponentMutation.Delete("sp")) }
        compose.waitForIdle()
        gone("Page a")
        assertEquals(setOf("root", "hostValue"), model.renderer.nodes.keys)
        assertEquals(mapOf("count" to JsonValue.Int(7), "sp:count" to JsonValue.Int(1)), model.store.state.page)
        assertEquals(emptyList(), model.subPages.prefixes)

        // The widget left: an updateSubPage for it is an unknown id.
        run(model, update("b"))
        assertEquals(listOf("a"), engine.locations)
    }

    /** S8: a SubPage that leaves while its fetch is out mounts nothing when the answer comes. */
    @Test
    fun b13_4_anAnswerForASubPageThatLeftIsIgnored() {
        val engine = Engine(counter("a", 1))
        val gate = CompletableDeferred<Unit>().also { engine.gates["a"] = it }
        val model = show(engine, host(subPage("sp", "a")))

        compose.runOnIdle { model.apply(ComponentMutation.Delete("sp")) }
        compose.waitForIdle()
        compose.runOnIdle { gate.complete(Unit) }
        compose.waitForIdle()
        assertEquals(setOf("root", "hostValue"), model.renderer.nodes.keys)
        assertEquals(mapOf("count" to JsonValue.Int(7)), model.store.state.page)
    }

    /** S1: a SubPage inside a sub-page mounts under `outer:inner:`. */
    @Test
    fun b13_4_aNestedSubPageMountsUnderBothPrefixes() {
        val outer = pageOf("outer", column("r", "label", "inner"), text("label", "Page outer"), subPage("inner", "a"))
        val model = show(Engine(outer, counter("a", 1)), host(subPage("sp", "outer")))
        shown("Page outer")
        shown("Page a")
        assertEquals(JsonValue.Int(1), model.store.value("sp:inner:count"))
        assertEquals(listOf("sp:", "sp:inner:"), model.subPages.prefixes)

        compose.onNodeWithText("Add a").performClick()
        compose.waitForIdle()
        assertEquals(JsonValue.Int(2), model.store.value("sp:inner:count"))
        shown("2")
    }

    /** A layer drawn from a snapshot fetches nothing and registers nothing. */
    @Test
    fun b13_4_aFrozenLayerFetchesNothing() {
        val engine = Engine(counter("a", 1))
        val model = OrcaPageModel(host(subPage("sp", "a", child = "wait"), text("wait", "Loading feed")), client = engine.client)
        val frozen: Map<String, ResolvedNode> = model.page.components.associate { it.id to assertNotNull(model.resolve(it.id)) }
        compose.setContent {
            CompositionLocalProvider(LocalOrcaFrozenNodes provides frozen) {
                Box(Modifier.size(300.dp, 600.dp)) { NodeView("root", model) }
            }
        }
        compose.waitForIdle()
        assertEquals(emptyList(), engine.requests)
        assertNull(model.subPages.mounts("sp"))
        shown("Loading feed")
    }

    /** A snapshot of the page (an AnimatedSwitcher's outgoing child) holds the mounted pages under their SubPage. */
    @Test
    fun b13_4_aSnapshotHoldsTheMountedPages() {
        val model = OrcaPageModel(host(subPage("sp", "a")), client = Engine(counter("a", 1)).client)
        val snapshot = OrcaNodeSnapshot()
        compose.setContent {
            CompositionLocalProvider(LocalOrcaNodeRecorder provides snapshot) {
                Box(Modifier.size(300.dp, 600.dp)) { NodeView("root", model) }
            }
        }
        compose.waitForIdle()
        val frozen = snapshot.frozen("root")
        assertEquals(listOf("sp:r"), frozen["sp"]?.childIds)
        assertTrue(frozen.keys.containsAll(setOf("sp:r", "sp:label", "sp:value", "sp:add", "sp:addLabel")), "${frozen.keys}")
        assertEquals(OrcaPageModel.INERT_ACTION, frozen["sp:add"]?.actions?.get("onTap"))
    }

    // MARK: B13.5-K, updateSubPage and server actions

    /** S7: replace swaps the page, removes the old nodes and state, and no later redraw puts the first page back. */
    @Test
    fun b13_5_replaceSticksAfterRecompositionAndRemovesTheOldNodesAndState() {
        val other = pageOf("b", column("r", "label"), text("label", "Page b"), state = mapOf("other" to 5))
        val engine = Engine(counter("a", 1), other)
        val model = OrcaPageModel(host(subPage("sp", "a")), client = engine.client)
        var redraws by mutableIntStateOf(0)
        compose.setContent {
            // Reading it here composes the whole host again when it changes.
            Box(Modifier.size(300.dp, (600 + redraws).dp)) { NodeView("root", model) }
        }
        compose.waitForIdle()
        shown("Page a")

        run(model, update("b", params = mapOf("n" to state("count"))))
        shown("Page b")
        gone("Page a")
        assertEquals(setOf("root", "hostValue", "sp", "sp:r", "sp:label"), model.renderer.nodes.keys)
        assertEquals(mapOf("count" to JsonValue.Int(7), "sp:other" to JsonValue.Int(5)), model.store.state.page)

        compose.runOnIdle {
            redraws += 1
            model.store.dispatch(mapOf("count" to JsonValue.Int(8)))
            model.apply(ComponentMutation.Update("hostValue", emptyMap()))
        }
        compose.waitForIdle()
        shown("Page b")
        gone("Page a")
        assertEquals(listOf("a", "b?n=7"), engine.locations)
    }

    /** S7: join mounts the new page after the first, each with its own state; S5: one below the other. */
    @Test
    fun b13_5_joinDrawsBothTreesInOrderWithSeparateState() {
        val engine = Engine(counter("a", 1), counter("c", 30))
        val model = show(engine, host(subPage("sp", "a")))

        run(model, update("c", "join"))
        shown("Page a")
        shown("Page c")
        assertTrue(top("Page a") < top("Page c"))
        assertEquals(listOf("sp:", "sp#1:"), model.subPages.prefixes)
        assertEquals(
            mapOf("count" to JsonValue.Int(7), "sp:count" to JsonValue.Int(1), "sp#1:count" to JsonValue.Int(30)),
            model.store.state.page,
        )

        compose.onNodeWithText("Add c").performClick()
        compose.waitForIdle()
        assertEquals(JsonValue.Int(31), model.store.value("sp#1:count"))
        assertEquals(JsonValue.Int(1), model.store.value("sp:count"))
        shown("31")
        shown("1")
    }

    /** S7: the old content stays on screen while the new page is fetched. */
    @Test
    fun b13_5_theOldContentStaysWhileTheUpdateFetches() {
        val engine = Engine(counter("a", 1), counter("b", 20))
        val model = show(engine, host(subPage("sp", "a")))
        val gate = CompletableDeferred<Unit>().also { engine.gates["b"] = it }

        run(model, update("b"))
        shown("Page a")
        compose.onNode(spinner).assertDoesNotExist()

        compose.runOnIdle { gate.complete(Unit) }
        compose.waitForIdle()
        shown("Page b")
        gone("Page a")
    }

    /** S7: an id no SubPage has does nothing: no fetch, no effect, no error. */
    @Test
    fun b13_5_anUnknownSubPageIdDoesNothing() {
        val engine = Engine(counter("a", 1), counter("b", 20))
        val model = show(engine, host(subPage("sp", "a")))
        val effects = ArrayList<String>()
        val errors = ArrayList<Throwable>()
        model.onEffect = { effects.add(it.type) }
        model.onError = { errors.add(it) }

        run(model, update("b", id = "nope"))
        shown("Page a")
        assertEquals(listOf("a"), engine.locations)
        assertEquals(emptyList(), effects)
        assertEquals(emptyList(), errors)
    }

    /** S7: a failed fetch leaves the content and is the action's failure: a lifecycle's onError runs, or the page's. */
    @Test
    fun b13_5_aFailedUpdateLeavesTheContentAndFailsLikeAnyAction() {
        val engine = Engine(counter("a", 1)).also { it.broken["b"] = "boom" }
        val model = show(engine, host(subPage("sp", "a")))
        val errors = ArrayList<Throwable>()
        model.onError = { errors.add(it) }

        run(model, Action.Lifecycle(update("b"), onError = ActionList.Single(Action.SetState(key = "failed", value = JsonValue.Bool(true)))))
        shown("Page a")
        assertEquals(JsonValue.Bool(true), model.store.value("failed"))
        assertEquals(emptyList(), errors)
        assertEquals(JsonValue.Int(1), model.store.value("sp:count"))

        run(model, update("b"))
        shown("Page a")
        assertEquals(1, errors.size)
    }

    /**
     * S6: a server action fired inside posts the sub-page's keys only, without the prefix; the setState and the
     * component mutation it answers with land on the sub-page.
     */
    @Test
    fun b13_5_aServerActionInsidePostsOnlyTheSubPageKeysAndItsAnswerLandsUnderThePrefix() {
        val inner = pageOf(
            "a",
            column("r", "label", "value", "save"),
            text("label", "Page a"),
            watching("value", "count"),
            button("save", "TextButton", "saveLabel", mapOf("onTap" to Action.ServerAction("save"))),
            text("saveLabel", "Save"),
            state = mapOf("count" to 1),
        )
        val engine = Engine(inner)
        engine.actions = JsonValue.parse(
            """[{"type":"setState","key":"count","value":42},{"type":"updateComponent","id":"label","props":{"data":"Saved a"}}]""",
        )
        val model = show(engine, host(subPage("sp", "a")))

        compose.onNodeWithText("Save").performClick()
        compose.waitForIdle()

        val body = JsonValue.parse(engine.requests.last().body!!)
        assertEquals(JsonValue.obj("count" to 1), body["pageState"])
        assertEquals(mapOf("count" to JsonValue.Int(7), "sp:count" to JsonValue.Int(42)), model.store.state.page)
        shown("42")
        shown("7")
        shown("Saved a")
        gone("Page a")
    }

    /** S6: a server action of the host posts the whole page state and its answer is not rewritten. */
    @Test
    fun b13_5_aServerActionOfTheHostIsUnchanged() {
        val engine = Engine(counter("a", 1))
        engine.actions = JsonValue.parse("""[{"type":"setState","key":"count","value":42}]""")
        val model = show(engine, host(subPage("sp", "a")))

        run(model, Action.ServerAction("save"))
        val body = JsonValue.parse(engine.requests.last().body!!)
        assertEquals(JsonValue.obj("count" to 7, "sp:count" to 1), body["pageState"])
        assertEquals(mapOf("count" to JsonValue.Int(42), "sp:count" to JsonValue.Int(1)), model.store.state.page)
    }
}
