package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals

/**
 * Stack and Positioned against Flutter's `RenderStack` numbers (Swift's
 * StackTests), at 1 dp per pixel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class StackTest {
    @get:Rule
    val compose = createComposeRule()

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun boundsOfText(data: String): DpRect = compose.onNodeWithText(data).getUnclippedBoundsInRoot()

    /**
     * A page drawn from its root inside a loose box, with Stack and
     * Positioned known to the core and drawn by their composables.
     */
    private fun stackPage(width: Dp, height: Dp, vararg nodes: ComponentNode) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("Stack", "Positioned"))
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Stack") { node, model, modifier -> StackWidget(node, model, modifier) }
                register("Positioned") { node, model, modifier -> PositionedWidget(node, model, modifier) }
            }
        }
        compose.setContent {
            Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
        }
    }

    private fun stack(id: String, vararg children: String, props: Map<String, JsonValue> = emptyMap()) =
        ComponentNode(id, "Stack", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Multi, props, children.toList())

    private fun positioned(id: String, child: String, vararg edges: Pair<String, Int>) =
        ComponentNode(
            id, "Positioned", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            edges.associate { (k, v) -> k to JsonValue.Int(v.toLong()) }, listOf(child),
        )

    /** A SizedBox around a Text, so the box is found by its text. */
    private fun sizedText(id: String, child: String, width: Int? = null, height: Int? = null) =
        sizedBox(id, width, height).copy(children = listOf(child))

    @Test
    fun k1_theStackIsAsBigAsItsLargestChildAndCentresIt() {
        compose.setContent {
            Box(Modifier.size(400.dp)) {
                Layout(
                    content = {
                        Box(Modifier.size(200.dp, 100.dp).testTag("image"))
                        Box(Modifier.size(50.dp, 20.dp).testTag("label"))
                    },
                    modifier = Modifier.testTag("stack"),
                    measurePolicy = StackMeasurePolicy(Alignment.Center, StackFit.Loose),
                )
            }
        }
        assertEquals(DpRect(0.dp, 0.dp, 200.dp, 100.dp), bounds("stack"))
        assertEquals(DpRect(75.dp, 40.dp, 125.dp, 60.dp), bounds("label"))
    }

    @Test
    fun k2_positionedChildrenSitByTheirEdges() {
        stackPage(
            400.dp, 400.dp,
            stack("0", "1", "2", "3"),
            sizedText("1", "4", width = 300, height = 160),
            positioned("2", "5", "top" to 12, "right" to 12),
            positioned("3", "6", "right" to 0, "bottom" to 0, "left" to 0, "height" to 40),
            text("4", "image"),
            sizedText("5", "7", width = 60, height = 24),
            text("6", "bar"),
            text("7", "badge"),
        )
        // The Stack is the image's size; Positioned children do not grow it.
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 160.dp), boundsOfText("image"))
        assertEquals(DpRect(228.dp, 12.dp, 288.dp, 36.dp), boundsOfText("badge"))
        // Both horizontal edges stretch it across; height 40 from the bottom.
        assertEquals(DpRect(0.dp, 120.dp, 300.dp, 160.dp), boundsOfText("bar"))
    }

    @Test
    fun k3_expandFillsWhatItIsOffered() {
        stackPage(
            320.dp, 200.dp,
            stack("0", "1", "2", props = mapOf("fit" to JsonValue.String("expand"))),
            sizedText("1", "3", width = 10, height = 10),
            positioned("2", "4", "right" to 0, "bottom" to 0),
            text("3", "small"),
            sizedText("4", "5", width = 20, height = 20),
            text("5", "corner"),
        )
        // The ordinary child is held to all the space; the corner shows the Stack's own size.
        assertEquals(DpRect(0.dp, 0.dp, 320.dp, 200.dp), boundsOfText("small"))
        assertEquals(DpRect(300.dp, 180.dp, 320.dp, 200.dp), boundsOfText("corner"))
    }

    @Test
    fun k5_positionedSpecFollowsFlutter() {
        val stack = IntSize(100, 100)
        val px = Density(1f)
        val ltr = LayoutDirection.Ltr

        // Both edges fix the width; the open axis has no limit.
        val both = PositionedSpec(right = 10.dp, left = 10.dp)
        assertEquals(Constraints(minWidth = 80, maxWidth = 80), both.constraints(stack, px))
        assertEquals(Constraints.fixedWidth(60), both.constraints(stack, Density(2f)))
        assertEquals(Constraints.fixedWidth(0), PositionedSpec(right = 60.dp, left = 60.dp).constraints(stack, px))

        // One edge and a width: placed from that edge.
        val fromRight = PositionedSpec(right = 10.dp, width = 30.dp)
        assertEquals(Constraints.fixedWidth(30), fromRight.constraints(stack, px))
        assertEquals(60, fromRight.offset(IntSize(30, 20), stack, Alignment.Center, ltr, px).x)

        // No edge on an axis: the Stack's alignment places it there.
        val open = PositionedSpec(top = 0.dp)
        assertEquals(Constraints(), open.constraints(stack, px))
        assertEquals(IntOffset(40, 0), open.offset(IntSize(20, 20), stack, Alignment.Center, ltr, px))
        assertEquals(IntOffset(0, 0), open.offset(IntSize(20, 20), stack, Alignment.TopStart, ltr, px))

        // A negative edge hangs the child over the Stack's side, as Flutter allows.
        val hanging = PositionedSpec(bottom = (-8).dp, left = (-8).dp)
        assertEquals(IntOffset(-8, 92), hanging.offset(IntSize(16, 16), stack, Alignment.Center, ltr, px))
    }
}
