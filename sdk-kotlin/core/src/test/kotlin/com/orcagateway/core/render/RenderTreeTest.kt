package com.orcagateway.core.render

import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.ActionReducer
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.TestWidgets
import com.orcagateway.core.support.j
import com.orcagateway.core.support.props
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** T2.3 and T2.5 on the render tree, the layer the UI draws. */
class RenderTreeTest {
    private fun page(relative: String): PageResponse = Json.decodeFromString(PageResponse.serializer(), Fixtures.text(relative))

    private fun counter(): PageResponse = page("sdk-swift/Tests/Pages/counter-home.json")

    /** The text of a node: its own `data` (a Text) or the text under it. */
    private fun text(node: RenderNode): String? = node.first { it.type == "Text" }?.props?.get("data")?.stringValue

    private fun button(label: String, tree: RenderNode): RenderNode? =
        tree.first { it.type == "ElevatedButton" && text(it) == label }

    // MARK: T4.4 native-widgets page

    /**
     * Every node of the S4 demo page is a widget this build draws, so
     * nothing degrades to a FallbackPrompt. (Kotlin draws no widget yet, so
     * the registry is the manifest's widget set; see TestWidgets.)
     */
    @Test
    fun theNativeWidgetsPageDrawsWithoutDegrading() {
        val page = page("sdk-swift/Tests/Pages/native-widgets-home.json")
        val registry = TestWidgets.registry()
        val renderer = PageRenderer(page, registry)
        val store = ElmStore()
        store.seed(page.state)
        val tree = assertNotNull(renderer.tree(store.state))
        assertEquals(page.components.size, tree.all.size)
        assertEquals(emptyList(), tree.all.filter { it.node.degradedFrom != null }.map { it.type })
        assertEquals(emptySet(), registry.reportedTypes)
        val types = tree.all.map { it.type }.toSet()
        for (
            added in listOf(
                "Icon", "Image", "Container", "Expanded", "Spacer", "TextField",
                "Stack", "Positioned", "ClipRRect", "GestureDetector",
            )
        ) {
            assertTrue(added in types, "$added is not on the page")
        }
        // The favourite icon follows its state: bowl starts on, pizza off.
        val icons = tree.all.filter { it.type == "Icon" }.mapNotNull { it.props["name"]?.stringValue }
        assertTrue("favorite" in icons)
        assertTrue("favorite_border" in icons)
    }

    // MARK: T2.3 counter page

    @Test
    fun counterPageCountsAndResetsWithASnackbar() {
        val page = counter()
        val renderer = PageRenderer(page, TestWidgets.registry())
        val store = ElmStore()
        store.seed(page.state)
        val reducer = ActionReducer().reducer

        var tree = assertNotNull(renderer.tree(store.state))
        assertEquals(16, tree.all.size)
        assertEquals("Scaffold", tree.type)
        val appBar = assertNotNull(tree.slots["appBar"])
        assertEquals(j("Counter Example"), appBar.slots["title"]?.props?.get("data"))
        val countText = { t: RenderNode -> t.first { it.node.watches == listOf("count") } }
        assertEquals(j("0"), countText(tree)?.props?.get("data"))

        val plus = assertNotNull(button("+", tree)?.node?.actions?.get("onTap"))
        store.apply(plus, reducer)
        store.apply(plus, reducer)
        tree = assertNotNull(renderer.tree(store.state))
        assertEquals(j("2"), countText(tree)?.props?.get("data"))

        val minus = assertNotNull(button("-", tree)?.node?.actions?.get("onTap"))
        store.apply(minus, reducer)
        assertEquals(j(1), store.value("count"))

        val reset = assertNotNull(button("Reset", tree)?.node?.actions?.get("onTap"))
        val effects = store.apply(reset, reducer)
        tree = assertNotNull(renderer.tree(store.state))
        assertEquals(j("0"), countText(tree)?.props?.get("data"))
        assertEquals(listOf(ActionEffect("showSnackbar", props("message" to "Counter reset to 0", "duration" to 4000))), effects)
    }

    @Test
    fun onlyTheCountTextWatchesCount() {
        val page = counter()
        val watchers = page.components.filter { "count" in it.watches }.map { it.id }
        assertEquals(listOf("5"), watchers)
    }

    @Test
    fun propsResolveDeepAndStructureSlotsAreIds() {
        val renderer = PageRenderer(counter(), TestWidgets.registry())
        val state = StoreState(page = props("count" to 7))
        val scaffold = assertNotNull(renderer.resolve("0", state))
        assertEquals(mapOf("appBar" to "1", "body" to "3"), scaffold.slots)
        assertEquals(emptyList(), scaffold.childIds)
        val text = assertNotNull(renderer.resolve("5", state))
        assertEquals(j("7"), text["data"])
        assertEquals(j(48), text["style"]?.get("fontSize"))
        val column = assertNotNull(renderer.resolve("4", state))
        assertEquals(listOf("5", "6", "7", "13", "14"), column.childIds)
    }

    // MARK: T2.5 unknown widget types degrade safely

    private fun page(components: List<ComponentNode>): PageResponse = PageResponse("p", "P", components = components)

    @Test
    fun unknownTypeBecomesAFallbackPromptAndIsReportedOnce() {
        val events = ArrayList<String>()
        val registry = TestWidgets.registry(onUnknownType = { events.add(it) })
        val renderer = PageRenderer(
            page(
                listOf(
                    ComponentNode("0", "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, children = listOf("1", "2", "3")),
                    ComponentNode("1", "HoloDeck", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, props = props("x" to 1)),
                    ComponentNode("2", "HoloDeck", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None),
                    ComponentNode("3", "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None, props = props("data" to "after")),
                ),
            ),
            registry,
        )

        val tree = assertNotNull(renderer.tree(StoreState()))
        val kinds = tree.children.map { it.type }
        assertEquals(listOf("FallbackPrompt", "FallbackPrompt", "Text"), kinds)
        val prompt = tree.children[0].node
        assertEquals("HoloDeck", prompt.degradedFrom)
        assertEquals(j("Unsupported content"), prompt["title"])
        assertEquals(j("warn"), prompt["severity"])
        assertEquals(true, prompt["body"]?.stringValue?.contains("\"HoloDeck\""))
        assertEquals(listOf("HoloDeck"), events)
        assertEquals(setOf("HoloDeck"), registry.reportedTypes)
    }

    @Test
    fun withoutAFallbackPromptAnUnknownTypeDrawsNothing() {
        val registry = WidgetRegistry(types = setOf("Column"))
        val renderer = PageRenderer(
            page(
                listOf(
                    ComponentNode("0", "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, children = listOf("1")),
                    ComponentNode("1", "HoloDeck", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None),
                ),
            ),
            registry,
        )
        val tree = assertNotNull(renderer.tree(StoreState()))
        assertEquals(listOf(WidgetRegistry.emptyType), tree.children.map { it.type })
    }

    @Test
    fun missingChildIdsAndCyclesAreSkipped() {
        val renderer = PageRenderer(
            page(
                listOf(
                    ComponentNode("0", "Column", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, children = listOf("9", "1")),
                    ComponentNode("1", "Center", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, children = listOf("0")),
                ),
            ),
            TestWidgets.registry(),
        )
        val tree = assertNotNull(renderer.tree(StoreState()))
        assertEquals(listOf("1"), tree.children.map { it.id })
        assertEquals(0, tree.children[0].children.size)
    }

    @Test
    fun emptyPageHasNoTree() {
        assertNull(PageRenderer(page(emptyList<ComponentNode>())).tree(StoreState()))
    }
}
