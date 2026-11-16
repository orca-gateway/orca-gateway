package com.orcagateway.core.subpage

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.decode
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.render.PageRenderer
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ActionSource
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.support.ActionStub
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertSame

/**
 * B13.4-K and B13.5-K, the part between the pure functions (SubPageFixtureTest) and Compose: the mounted pages
 * of a host page ([SubPageHost]) and what the executor does for a node inside one (S6) and for updateSubPage (S7).
 */
class SubPageHostTest {
    private fun text(id: String, key: String? = null): JsonValue = obj(
        "id" to id, "type" to "Text", "kind" to "primitive", "childMode" to "none",
        "props" to obj("data" to if (key == null) id else obj("type" to "state", "scope" to "page", "key" to key)),
        "children" to arr(), "watches" to if (key == null) arr() else arr(key),
    )

    private fun subPage(id: String): JsonValue =
        obj("id" to id, "type" to "SubPage", "kind" to "layout", "childMode" to "single", "props" to obj("pageId" to "a"), "children" to arr(), "watches" to arr())

    private fun column(id: String, vararg children: String): JsonValue =
        obj("id" to id, "type" to "Column", "kind" to "layout", "childMode" to "multi", "props" to obj(), "children" to arr(*children), "watches" to arr())

    private fun page(id: String, vararg nodes: JsonValue, state: Map<String, Any?> = emptyMap()): PageResponse = obj(
        "pageId" to id, "title" to id, "components" to arr(*nodes),
        "state" to arr(*state.map { (k, v) -> obj("key" to k, "scope" to "page", "initial" to v) }.toTypedArray()),
    ).decode()

    private class Host(page: PageResponse) {
        val renderer = PageRenderer(page)
        val store = ElmStore().also { it.seed(page.state) }
        val subPages = SubPageHost(renderer, store)
        val ids: Set<String> get() = renderer.nodes.keys
    }

    private val hostPage: PageResponse
        get() = page("host", column("root", "feed", "other"), subPage("feed"), subPage("other"), state = mapOf("count" to 7))

    @Test
    fun b13_4_aMountedPageLivesInTheHostStoreAndStateUnderItsPrefix() {
        val host = Host(hostPage)
        val mounts = host.subPages.register("feed")
        assertSame(mounts, host.subPages.register("feed"), "one SubPageMounts per key")
        assertEquals(emptyList(), host.subPages.prefixes)

        val change = host.subPages.mount("feed", "replace", page("a", column("r", "t"), text("t", "count"), state = mapOf("count" to 1)))
        assertEquals("feed:", change?.prefix)
        assertEquals(setOf("root", "feed", "other", "feed:r", "feed:t"), host.ids)
        assertEquals(props("count" to 7, "feed:count" to 1), host.store.state.page)
        assertEquals(listOf("feed:"), host.subPages.prefixes)
        assertEquals(listOf("feed:r"), mounts.roots)
        // The merged node reads its own key, not the host's.
        assertEquals(JsonValue.Int(1), host.renderer.resolve("feed:t", host.store.state)?.get("data"))
        assertEquals(listOf("feed:count"), host.renderer.nodes["feed:t"]?.watches)
    }

    @Test
    fun b13_5_replaceRemovesTheOldNodesAndKeysAndJoinAddsAfter() {
        val host = Host(hostPage)
        host.subPages.register("feed")
        host.subPages.mount("feed", "replace", page("a", text("t", "n"), state = mapOf("n" to 1)))
        host.subPages.mount("feed", "join", page("c", text("t", "n"), state = mapOf("n" to 3)))
        assertEquals(setOf("root", "feed", "other", "feed:t", "feed#1:t"), host.ids)
        assertEquals(props("count" to 7, "feed:n" to 1, "feed#1:n" to 3), host.store.state.page)
        assertEquals(listOf("feed:", "feed#1:"), host.subPages.prefixes)
        assertEquals("feed#1:", SubPage.prefixOf(host.subPages.prefixes, "feed#1:t"))
        assertNull(SubPage.prefixOf(host.subPages.prefixes, "root"))

        host.subPages.mount("feed", "replace", page("b", text("u", "m"), state = mapOf("m" to 2)))
        assertEquals(setOf("root", "feed", "other", "feed:u"), host.ids)
        assertEquals(props("count" to 7, "feed:m" to 2), host.store.state.page)
        assertEquals(listOf("feed:"), host.subPages.prefixes)
    }

    @Test
    fun b13_5_anUnknownKeyMountsNothing() {
        val host = Host(hostPage)
        assertNull(host.subPages.mount("nope", "replace", page("a", text("t"))))
        assertEquals(setOf("root", "feed", "other"), host.ids)
    }

    @Test
    fun b13_4_aSubPageWhoseNodeLeftIsUnmountedItsStateKeysStay() {
        val host = Host(hostPage)
        host.subPages.register("feed")
        host.subPages.register("other")
        host.subPages.mount("feed", "replace", page("a", text("t", "n"), state = mapOf("n" to 1)))
        host.subPages.mount("other", "replace", page("b", text("t")))
        assertEquals(emptyList(), host.subPages.sweep(), "both nodes are still there")

        host.renderer.apply(ComponentMutation.Delete("feed"))
        assertEquals(listOf("feed"), host.subPages.sweep())
        assertEquals(setOf("root", "other", "other:t"), host.ids)
        assertEquals(props("count" to 7, "feed:n" to 1), host.store.state.page)
        assertNull(host.subPages.mounts("feed"))
        assertEquals(listOf("other:"), host.subPages.prefixes)
    }

    @Test
    fun b13_4_aNestedSubPageMountsUnderBothPrefixesAndLeavesWithItsOuterPage() {
        val host = Host(hostPage)
        host.subPages.register("feed")
        host.subPages.mount("feed", "replace", page("a", column("r", "inner"), subPage("inner")))
        host.subPages.register("feed:inner")
        host.subPages.mount("feed:inner", "replace", page("b", text("t", "n"), state = mapOf("n" to 5)))
        assertEquals(setOf("root", "feed", "other", "feed:r", "feed:inner", "feed:inner:t"), host.ids)
        assertEquals(JsonValue.Int(5), host.store.value("feed:inner:n"))
        assertEquals("feed:inner:", SubPage.prefixOf(host.subPages.prefixes, "feed:inner:t"), "the longest prefix wins")

        host.subPages.mount("feed", "replace", page("c", text("z")))
        assertEquals(setOf("root", "feed", "other", "feed:z"), host.ids)
        assertNull(host.subPages.mounts("feed:inner"))
        assertEquals(props("count" to 7), host.store.state.page)
    }

    private fun add(parent: String, vararg nodes: JsonValue): ComponentMutation =
        ComponentMutation.Add(parent, nodes.map { it.decode() })

    /** A node added to a mounted page after the mount (addComponent) is under its prefix, and leaves with the page. */
    @Test
    fun b13_5_replaceRemovesTheNodesAddedSinceUnderTheOldPages() {
        val host = Host(hostPage)
        host.subPages.register("feed")
        host.subPages.mount("feed", "replace", page("a", column("r", "t"), text("t")))
        host.subPages.mount("feed", "join", page("c", column("r")))
        host.renderer.apply(add("feed:r", text("feed:new"), subPage("feed:late")))
        host.renderer.apply(add("feed#1:r", text("feed#1:new")))
        host.subPages.register("feed:late")
        host.subPages.mount("feed:late", "replace", page("d", text("t", "n"), state = mapOf("n" to 4)))
        assertEquals(
            setOf("root", "feed", "other", "feed:r", "feed:t", "feed:new", "feed:late", "feed:late:t", "feed#1:r", "feed#1:new"),
            host.ids,
        )

        // A join removes nothing.
        host.subPages.mount("feed", "join", page("e", text("z")))
        assertEquals(true, host.ids.containsAll(setOf("feed:new", "feed:late:t", "feed#1:new", "feed#2:z")))

        host.subPages.mount("feed", "replace", page("b", text("u")))
        assertEquals(setOf("root", "feed", "other", "feed:u"), host.ids)
        assertNull(host.subPages.mounts("feed:late"), "the SubPage added since is unmounted with its page")
        assertEquals(listOf("feed:"), host.subPages.prefixes)
    }

    @Test
    fun b13_4_aSubPageWhoseNodeLeftTakesTheNodesAddedSinceWithIt() {
        val host = Host(hostPage)
        host.subPages.register("feed")
        host.subPages.mount("feed", "replace", page("a", column("r", "t"), text("t")))
        host.subPages.mount("feed", "replace", page("b", column("r")))
        host.renderer.apply(add("feed:r", text("feed:new"), subPage("feed:late")))
        host.subPages.register("feed:late")
        host.subPages.mount("feed:late", "replace", page("d", text("t")))
        // Cut from its parent, so nothing but the prefix ties it to the page.
        host.renderer.apply(ComponentMutation.Update("feed:r", emptyMap()))
        host.renderer.nodes = host.renderer.nodes + ("feed:orphan" to host.renderer.nodes.getValue("feed:new").copy(id = "feed:orphan"))

        host.renderer.apply(ComponentMutation.Delete("feed"))
        assertEquals(listOf("feed", "feed:late"), host.subPages.sweep())
        assertEquals(setOf("root", "other"), host.ids)
        assertEquals(emptyList(), host.subPages.prefixes)
    }

    // MARK: The executor

    private fun executor(host: Host, stub: ActionStub): ActionExecutor = ActionExecutor(host.store, ActionStub.client(stub)).also {
        it.subPagePrefixes = { host.subPages.prefixes }
    }

    private val answer = obj(
        "actions" to arr(
            obj("type" to "setState", "key" to "n", "value" to 9),
            obj("type" to "updateComponent", "id" to "t", "props" to obj("data" to "changed")),
        ),
    )

    @Test
    fun b13_5_aServerActionInsidePostsTheSubPageKeysAndItsAnswerLandsUnderThePrefix() = runSuspend {
        val host = Host(hostPage)
        host.subPages.register("feed")
        host.subPages.mount("feed", "replace", page("a", text("t", "n"), state = mapOf("n" to 1)))
        val stub = ActionStub(mapOf("save" to answer))
        val executor = executor(host, stub)
        val mutations = ArrayList<ComponentMutation>()
        executor.onMutation = { mutations.add(it) }

        executor.execute(Action.ServerAction("save"), source = ActionSource("feed:t", "onTap"))

        assertJsonEqual(JsonValue.parse(stub.requests.single().body!!)["pageState"], obj("n" to 1))
        assertEquals(props("count" to 7, "feed:n" to 9), host.store.state.page)
        assertEquals(listOf<ComponentMutation>(ComponentMutation.Update("feed:t", props("data" to "changed"))), mutations)
    }

    @Test
    fun b13_5_aServerActionOfTheHostIsUnchanged() = runSuspend {
        val host = Host(hostPage)
        host.subPages.register("feed")
        host.subPages.mount("feed", "replace", page("a", text("t", "n"), state = mapOf("n" to 1)))
        val stub = ActionStub(mapOf("save" to answer))
        val executor = executor(host, stub)

        executor.execute(Action.ServerAction("save"), source = ActionSource("root", "onTap"))

        assertJsonEqual(JsonValue.parse(stub.requests.single().body!!)["pageState"], obj("count" to 7, "feed:n" to 1))
        assertEquals(props("count" to 7, "feed:n" to 1, "n" to 9), host.store.state.page)
    }

    @Test
    fun b13_5_updateSubPageResolvesItsFieldsAndGoesToTheHook() = runSuspend {
        val executor = ActionExecutor(ElmStore(page = props("target" to "feed", "which" to "b", "q" to 3)))
        val calls = ArrayList<List<Any?>>()
        val effects = ArrayList<String>()
        executor.onEffect = { effects.add(it.type) }
        fun state(key: String) = obj("type" to "state", "scope" to "page", "key" to key)
        val action = Action.UpdateSubPage(state("target"), state("which"), props("q" to state("q"), "s" to "x"), JsonValue.String("join"))

        executor.execute(action)
        assertEquals(emptyList<List<Any?>>(), calls, "no hook, nothing happens")

        executor.onUpdateSubPage = { id, pageId, params, mode -> calls.add(listOf(id, pageId, params, mode)) }
        executor.execute(action)
        executor.execute(Action.UpdateSubPage(JsonValue.String("feed"), JsonValue.String("c")))
        assertEquals(
            listOf(listOf("feed", "b", props("q" to 3, "s" to "x"), "join"), listOf("feed", "c", null, "replace")),
            calls,
        )
        assertEquals(emptyList(), effects, "updateSubPage is no effect")
    }
}
