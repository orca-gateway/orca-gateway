package com.orcagateway.core.render

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.state.StoreState
import com.orcagateway.core.support.TestWidgets
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * The four structural changes on a page's node map, against the Flutter
 * `ComponentStore` behaviour they port.
 */
class ComponentMutationTest {
    private fun node(
        id: String,
        type: String = "Text",
        children: List<String> = emptyList(),
        props: Map<String, JsonValue> = emptyMap(),
    ): ComponentNode = ComponentNode(
        id, type,
        kind = if (children.isEmpty()) ComponentNode.Kind.Primitive else ComponentNode.Kind.Layout,
        childMode = if (children.isEmpty()) ComponentNode.ChildMode.None else ComponentNode.ChildMode.Multi,
        props = props, children = children,
    )

    /** root (Column) → list (Column) → [a, b] */
    private fun renderer(): PageRenderer = PageRenderer(
        PageResponse(
            "shop", "Shop",
            components = listOf(
                node("root", "Column", children = listOf("list")),
                node("list", "Column", children = listOf("a", "b")),
                node("a", props = props("data" to "A")),
                node("b", props = props("data" to "B")),
            ),
        ),
        TestWidgets.registry(),
    )

    private fun texts(r: PageRenderer, under: String = "list"): List<String> =
        r.tree(StoreState(), from = under)?.children?.mapNotNull { it.props["data"]?.stringValue } ?: emptyList()

    @Test
    fun updateMergesProps() {
        val r = renderer()
        r.apply(ComponentMutation.Update("a", props("data" to "A2", "style" to obj("fontSize" to 12))))
        assertEquals(props("data" to "A2", "style" to obj("fontSize" to 12)), r.nodes["a"]?.props)
        r.apply(ComponentMutation.Update("nope", props("x" to 1)))
        assertNull(r.nodes["nope"])
    }

    @Test
    fun deleteRemovesTheSubtreeAndTheParentLink() {
        val r = renderer()
        r.apply(ComponentMutation.Delete("list"))
        assertEquals(emptyList(), r.nodes["root"]?.children)
        assertNull(r.nodes["list"])
        assertNull(r.nodes["a"])
        assertNull(r.nodes["b"])
    }

    @Test
    fun addInsertsAtAPositionOrAppends() {
        val r = renderer()
        r.apply(ComponentMutation.Add("list", listOf(node("c", props = props("data" to "C"))), position = 0))
        r.apply(ComponentMutation.Add("list", listOf(node("d", props = props("data" to "D"))), position = 99))
        r.apply(ComponentMutation.Add("list", listOf(node("e", props = props("data" to "E"))), position = null))
        assertEquals(listOf("C", "A", "B", "D", "E"), texts(r))
    }

    @Test
    fun addWithASubtreeKeepsItsChildren() {
        val r = renderer()
        r.apply(
            ComponentMutation.Add(
                "list",
                listOf(node("row", "Row", children = listOf("row-t")), node("row-t", props = props("data" to "inner"))),
                position = null,
            ),
        )
        val row = r.tree(StoreState(), from = "row")
        assertEquals(j("inner"), row?.children?.firstOrNull()?.props?.get("data"))
    }

    @Test
    fun addToAMissingParentOrWithNothingChangesNothing() {
        val r = renderer()
        val before = r.nodes
        r.apply(ComponentMutation.Add("ghost", listOf(node("c")), position = null))
        r.apply(ComponentMutation.Add("list", emptyList(), position = null))
        assertEquals(before, r.nodes)
    }

    @Test
    fun replaceSwapsInPlace() {
        val r = renderer()
        r.apply(ComponentMutation.Replace("a", listOf(node("z", props = props("data" to "Z")))))
        assertEquals(listOf("Z", "B"), texts(r))
        assertNull(r.nodes["a"])
    }

    @Test
    fun replaceASubtreeDropsTheOldChildren() {
        val r = renderer()
        r.apply(
            ComponentMutation.Replace(
                "list",
                listOf(node("list2", "Column", children = listOf("q")), node("q", props = props("data" to "Q"))),
            ),
        )
        assertEquals(listOf("list2"), r.nodes["root"]?.children)
        assertNull(r.nodes["a"])
        assertEquals(listOf("Q"), texts(r, under = "list2"))
    }

    @Test
    fun replacingTheRootLeavesNothingToDraw() {
        val r = renderer()
        r.apply(ComponentMutation.Replace("root", listOf(node("x"))))
        assertNull(r.tree(StoreState()))
    }
}
