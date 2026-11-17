package com.orcagateway.core.state

import com.orcagateway.core.models.ComponentNode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/**
 * A8.1, the core half of openDialog and closeDialog (design D4). Flutter's
 * page handler (sdk/lib/src/widgets/orca_page.dart:323-374) looks the
 * Dialog up in the node map (absent: nothing), collects each child's
 * subtree depth first in order (a missing id skipped; none: nothing) and
 * draws it with `ComponentRenderer.render`, whose root is the list's first
 * node (component_renderer.dart:44-54): the Dialog's first child. A second
 * child's subtree is in the list but nothing under the root points at it,
 * so it is never drawn. The height is `heightFactor ?? 0.5`. closeDialog
 * and a barrier tap, a drag down or Back pop the top sheet only, nothing
 * when none is open (action_executor.dart:894-919). The same cases as
 * Swift's DialogStackTests.
 */
class DialogStackTest {
    private fun node(id: String, vararg children: String, type: String = "Text"): ComponentNode =
        ComponentNode(
            id = id,
            type = type,
            kind = ComponentNode.Kind.Layout,
            childMode = if (children.isEmpty()) ComponentNode.ChildMode.None else ComponentNode.ChildMode.Multi,
            children = children.toList(),
        )

    private fun map(vararg nodes: ComponentNode): Map<String, ComponentNode> = nodes.associateBy { it.id }

    /** A page with the keyed Dialog `d` (child `body`) and the keyed Dialog `e` (child `other`). */
    private val page = map(
        node("root", "d", "e", type = "Column"),
        node("d", "body", type = "Dialog"),
        node("body", "t", type = "Column"),
        node("t"),
        node("e", "other", type = "Dialog"),
        node("other"),
    )

    /**
     * A8.1: the sheet's root is the Dialog's first child, its subtree
     * depth first in order; a second child's subtree follows (collected,
     * never drawn: not under the root); a missing id is skipped, and an id
     * already on the path (a cycle) is not followed again.
     */
    @Test
    fun a8_1_openResolvesTheDialogsFirstChildAsTheSheetRootWithItsSubtreeDepthFirst() {
        val nodes = map(
            node("d", "a", "b", type = "Dialog"),
            node("a", "a1", "gone", "a2", type = "Column"),
            node("a1", "a1x", type = "Row"),
            node("a1x"),
            node("a2", "a", type = "Column"),
            node("b", "b1", type = "Column"),
            node("b1"),
        )
        val stack = DialogStack()
        val sheet = assertNotNull(stack.open("d", 0.4, nodes))
        assertEquals("d", sheet.dialogId)
        assertEquals("a", sheet.rootId)
        assertEquals(listOf("a", "a1", "a1x", "a2", "b", "b1"), sheet.nodes.map { it.id })
        assertSame(sheet, stack.top)
        assertEquals(listOf(sheet), stack.sheets)

        val one = assertNotNull(stack.open("d", null, page))
        assertEquals("body", one.rootId)
        assertEquals(listOf("body", "t"), one.nodes.map { it.id })
    }

    /** A8.1: an id not in the map, a Dialog with no children, or only missing ones, opens nothing. */
    @Test
    fun a8_1_anUnknownIdOrNoChildrenOpensNothing() {
        val stack = DialogStack()
        assertNull(stack.open("nope", 0.5, page))
        assertNull(stack.open("t", 0.5, page))
        assertNull(stack.open("d", 0.5, map(node("d", type = "Dialog"))))
        assertNull(stack.open("d", 0.5, map(node("d", "x", "y", type = "Dialog"))))
        assertNull(stack.open("d", 0.5, emptyMap()))
        assertTrue(stack.sheets.isEmpty())
        assertNull(stack.top)

        // None of them left a sheet behind: the next real one is the only one.
        val sheet = assertNotNull(stack.open("d", 0.5, page))
        assertEquals(listOf(sheet), stack.sheets)
    }

    /** A8.1: `heightFactor ?? 0.5`; NaN or a negative one is 0.5; 0 and others are kept. */
    @Test
    fun a8_1_heightFactorDefaultsToHalfAndNaNOrNegativeIsHalf() {
        assertEquals(0.5, DialogStack.DEFAULT_HEIGHT_FACTOR)
        val cases = listOf(null to 0.5, Double.NaN to 0.5, -0.2 to 0.5, 0.0 to 0.0, 0.3 to 0.3, 1.0 to 1.0)
        for ((raw, expected) in cases) {
            assertEquals(expected, DialogStack.heightFactor(raw), "heightFactor($raw)")
            assertEquals(expected, assertNotNull(DialogStack().open("d", raw, page)).heightFactor, "open(d, $raw)")
        }
    }

    /** A8.1: closeDialog pops the top sheet and returns it; with none open it does nothing (never a page). */
    @Test
    fun a8_1_closePopsTheTopSheetAndNoneOpenIsANoOp() {
        val stack = DialogStack()
        assertNull(stack.close())
        assertTrue(stack.sheets.isEmpty())

        val sheet = assertNotNull(stack.open("d", null, page))
        assertSame(sheet, stack.close())
        assertTrue(stack.sheets.isEmpty())
        assertNull(stack.top)
        assertNull(stack.close())
        assertTrue(stack.sheets.isEmpty())
    }

    /** A8.1: a barrier tap, a drag down or Back pops the top sheet only, whatever `dismissible` says. */
    @Test
    fun a8_1_aDismissPopsTheTopSheet() {
        val stack = DialogStack()
        assertNull(stack.dismiss())
        val first = assertNotNull(stack.open("d", null, page))
        val second = assertNotNull(stack.open("e", 0.3, page))
        assertSame(second, stack.dismiss())
        assertEquals(listOf(first), stack.sheets)
        assertSame(first, stack.top)
        assertSame(first, stack.dismiss())
        assertTrue(stack.sheets.isEmpty())
        assertNull(stack.dismiss())
    }

    /** A8.1: sheets stack in opening order (the same Dialog twice too) and close one per call, top first. */
    @Test
    fun a8_1_stackedSheetsCloseOnePerCall() {
        val stack = DialogStack()
        val a = assertNotNull(stack.open("d", 0.5, page))
        val b = assertNotNull(stack.open("e", 0.3, page))
        val c = assertNotNull(stack.open("d", 0.4, page))
        assertEquals(listOf(a, b, c), stack.sheets)
        assertSame(c, stack.close())
        assertEquals(listOf(a, b), stack.sheets)
        assertSame(b, stack.close())
        assertEquals(listOf(a), stack.sheets)
        assertSame(a, stack.close())
        assertTrue(stack.sheets.isEmpty())
        assertNull(stack.close())
    }
}
