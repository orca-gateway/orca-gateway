package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals

/**
 * Center and SingleChildScrollView against Flutter's `RenderPositionedBox`
 * and scroll viewport numbers, at 1 dp per pixel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class LayoutTest {
    @get:Rule
    val compose = createComposeRule()

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    /**
     * A page drawn from its root inside a box of the given size, loose or
     * (with [tight]) forcing that size on the root; Centers, scroll views and
     * SizedBoxes are tagged with their ids.
     */
    private fun layoutPage(width: Dp, height: Dp, vararg nodes: ComponentNode, tight: Boolean = false) {
        val model = OrcaPageModel(page(*nodes)).apply {
            builders = WidgetBuilders.standard().apply {
                register("Center") { node, model, modifier -> CenterWidget(node, model, modifier.testTag(node.id)) }
                register("SingleChildScrollView") { node, model, modifier ->
                    ScrollWidget(node, model, modifier.testTag(node.id))
                }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            Box(Modifier.size(width, height), propagateMinConstraints = tight) { NodeView(nodes.first().id, model) }
        }
    }

    private fun single(id: String, type: String, child: String, vararg props: Pair<String, Any?>) =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            props.associate { (key, value) -> key to JsonValue.of(value) }, listOf(child),
        )

    /** A1.10: Center with both factors is the child's size times each, the child in its middle. */
    @Test
    fun a1_10_centerFactorsSizeItByTheChild() {
        layoutPage(
            200.dp, 200.dp,
            single("c", "Center", "b", "widthFactor" to 0.5, "heightFactor" to 2),
            sizedBox("b", 40, 20),
        )
        assertEquals(20.dp, bounds("c").width)
        assertEquals(40.dp, bounds("c").height)
        assertEquals(-10.dp, bounds("b").left)
        assertEquals(10.dp, bounds("b").top)
    }

    /** A1.10: an axis with no factor still fills, as Flutter's Center does. */
    @Test
    fun a1_10_centerFillsTheAxisWithNoFactor() {
        layoutPage(
            200.dp, 200.dp,
            single("c", "Center", "b", "widthFactor" to 0.5),
            sizedBox("b", 40, 20),
        )
        assertEquals(20.dp, bounds("c").width)
        assertEquals(200.dp, bounds("c").height)
        assertEquals(90.dp, bounds("b").top)
    }

    /** A1.12: `reverse` puts scroll offset 0 at the far end, so the view starts at the content's bottom. */
    @Test
    fun a1_12_reverseStartsAtTheFarEnd() {
        layoutPage(
            100.dp, 100.dp,
            single("s", "SingleChildScrollView", "b", "reverse" to true),
            sizedBox("b", 40, 300),
        )
        assertEquals(100.dp, bounds("s").height)
        assertEquals(-200.dp, bounds("b").top)
        assertEquals(100.dp, bounds("b").bottom)
    }

    /** A1.12: content shorter than a view its parent forces keeps its length and sits at the far end. */
    @Test
    fun a1_12_shortReversedContentSitsAtTheFarEnd() {
        layoutPage(
            100.dp, 100.dp,
            single("s", "SingleChildScrollView", "b", "reverse" to true),
            sizedBox("b", 40, 30),
            tight = true,
        )
        assertEquals(100.dp, bounds("s").height)
        assertEquals(30.dp, bounds("b").height)
        assertEquals(70.dp, bounds("b").top)
    }

    /** A1.12: `shrinkWrap` (Flutter's IntrinsicHeight around the view) hugs its content in a loose parent. */
    @Test
    fun a1_12_shrinkWrapHugsItsContent() {
        layoutPage(
            100.dp, 100.dp,
            single("s", "SingleChildScrollView", "b", "shrinkWrap" to true),
            sizedBox("b", 40, 30),
        )
        assertEquals(40.dp, bounds("s").width)
        assertEquals(30.dp, bounds("s").height)
    }
}
