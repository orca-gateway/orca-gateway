package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.findRootCoordinates
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
 * Align, AspectRatio, ConstrainedBox, FittedBox, FractionallySizedBox and
 * LimitedBox against Flutter's render objects (`RenderPositionedBox`,
 * `RenderAspectRatio`, `RenderConstrainedBox`, `RenderFittedBox`,
 * `RenderFractionallySizedOverflowBox`, `RenderLimitedBox`), at 1 dp per
 * pixel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class SizingTest {
    @get:Rule
    val compose = createComposeRule()

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    /**
     * Where the node is drawn: its box through every layer's transform (the
     * unclipped bounds above scale its position, not its size), for a child
     * a FittedBox scales.
     */
    private fun drawnBounds(tag: String): DpRect {
        val coordinates = compose.onNodeWithTag(tag).fetchSemanticsNode().layoutInfo.coordinates
        val rect = coordinates.findRootCoordinates().localBoundingBoxOf(coordinates, clipBounds = false)
        return with(compose.density) { DpRect(rect.left.toDp(), rect.top.toDp(), rect.right.toDp(), rect.bottom.toDp()) }
    }

    /**
     * A page drawn from its root inside a box of the given size, loose or
     * (with [tight]) forcing that size on the root. The six types are
     * advertised, so the core's standard registry lets them through; they
     * and the SizedBoxes are tagged with their ids.
     */
    private fun sizingPage(width: Dp, height: Dp, vararg nodes: ComponentNode, tight: Boolean = false) {
        val model = OrcaPageModel(page(*nodes)).apply {
            builders = WidgetBuilders.standard().apply {
                register("Align") { node, model, modifier -> AlignWidget(node, model, modifier.testTag(node.id)) }
                register("AspectRatio") { node, model, modifier ->
                    AspectRatioWidget(node, model, modifier.testTag(node.id))
                }
                register("ConstrainedBox") { node, model, modifier ->
                    ConstrainedBoxWidget(node, model, modifier.testTag(node.id))
                }
                register("FittedBox") { node, model, modifier ->
                    FittedBoxWidget(node, model, modifier.testTag(node.id))
                }
                register("FractionallySizedBox") { node, model, modifier ->
                    FractionallySizedBoxWidget(node, model, modifier.testTag(node.id))
                }
                register("LimitedBox") { node, model, modifier ->
                    LimitedBoxWidget(node, model, modifier.testTag(node.id))
                }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            Box(Modifier.size(width, height), propagateMinConstraints = tight) { NodeView(nodes.first().id, model) }
        }
    }

    private fun single(id: String, type: String, child: String?, vararg props: Pair<String, Any?>) =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            props.associate { (key, value) -> key to JsonValue.of(value) }, listOfNotNull(child),
        )

    private fun assertRect(left: Int, top: Int, right: Int, bottom: Int, actual: DpRect) {
        assertEquals(DpRect(left.dp, top.dp, right.dp, bottom.dp), actual)
    }

    // A3.2 AspectRatio

    /** A3.2: AspectRatio 16:9 in a 320-wide parent is 180 tall, its child forced to that size. */
    @Test
    fun a3_2_aspectRatioSixteenByNineIn320WideIs180Tall() {
        sizingPage(320.dp, 400.dp, single("ar", "AspectRatio", "b", "aspectRatio" to 16.0 / 9.0), sizedBox("b"))
        assertEquals(320.dp, bounds("ar").width)
        assertEquals(180.dp, bounds("ar").height)
        assertRect(0, 0, 320, 180, bounds("b"))
    }

    /** A3.2: with no width limit (a horizontal scroll view) the height leads; the ratio defaults to 1. */
    @Test
    fun a3_2_aspectRatioDefaultsToOneAndFollowsTheHeightWhenTheWidthIsUnbounded() {
        sizingPage(
            300.dp, 120.dp,
            single("s", "SingleChildScrollView", "ar", "scrollDirection" to "horizontal"),
            single("ar", "AspectRatio", "b"),
            sizedBox("b"),
        )
        assertEquals(120.dp, bounds("ar").width)
        assertEquals(120.dp, bounds("ar").height)
    }

    /** A3.2: a tight parent wins over the ratio. */
    @Test
    fun a3_2_aspectRatioTakesATightParentsSize() {
        sizingPage(
            200.dp, 100.dp,
            single("ar", "AspectRatio", "b", "aspectRatio" to 16.0 / 9.0),
            sizedBox("b"),
            tight = true,
        )
        assertRect(0, 0, 200, 100, bounds("b"))
    }

    // A3.2 FractionallySizedBox

    /** A3.2: FractionallySizedBox 0.5 takes half of what its parent offers, and is its child's size. */
    @Test
    fun a3_2_fractionallySizedBoxHalfTakesHalf() {
        sizingPage(
            320.dp, 400.dp,
            single("f", "FractionallySizedBox", "b", "widthFactor" to 0.5, "heightFactor" to 0.5),
            sizedBox("b"),
        )
        assertRect(0, 0, 160, 200, bounds("f"))
        assertRect(0, 0, 160, 200, bounds("b"))
    }

    /** A3.2: an axis without a factor keeps the parent's constraints on it. */
    @Test
    fun a3_2_fractionallySizedBoxLeavesAnAxisWithoutAFactorToTheChild() {
        sizingPage(
            320.dp, 400.dp,
            single("f", "FractionallySizedBox", "b", "widthFactor" to 0.5),
            sizedBox("b", height = 50),
        )
        assertRect(0, 0, 160, 50, bounds("b"))
        assertRect(0, 0, 160, 50, bounds("f"))
    }

    /** A3.2: under a tight parent it is the parent's size and places the child by `alignment`. */
    @Test
    fun a3_2_fractionallySizedBoxPlacesItsChildByAlignment() {
        sizingPage(
            320.dp, 400.dp,
            single(
                "f", "FractionallySizedBox", "b",
                "widthFactor" to 0.5, "heightFactor" to 0.25, "alignment" to "bottomRight",
            ),
            sizedBox("b"),
            tight = true,
        )
        assertRect(0, 0, 320, 400, bounds("f"))
        assertRect(160, 300, 320, 400, bounds("b"))
    }

    /** A3.2: the alignment defaults to center. */
    @Test
    fun a3_2_fractionallySizedBoxCentresByDefault() {
        sizingPage(
            320.dp, 400.dp,
            single("f", "FractionallySizedBox", "b", "widthFactor" to 0.5, "heightFactor" to 0.5),
            sizedBox("b"),
            tight = true,
        )
        assertRect(80, 100, 240, 300, bounds("b"))
    }

    // A3.2 ConstrainedBox

    private val bounded = mapOf("minWidth" to 100, "maxWidth" to 200, "minHeight" to 50, "maxHeight" to 80)

    /** A3.2: a child smaller than the minimum is raised to it. */
    @Test
    fun a3_2_constrainedBoxRaisesASmallChildToItsMinimum() {
        sizingPage(
            300.dp, 300.dp,
            single("cb", "ConstrainedBox", "b", "constraints" to bounded),
            sizedBox("b", 20, 20),
        )
        assertRect(0, 0, 100, 50, bounds("b"))
        assertRect(0, 0, 100, 50, bounds("cb"))
    }

    /** A3.2: a child larger than the maximum is held to it. */
    @Test
    fun a3_2_constrainedBoxHoldsALargeChildToItsMaximum() {
        sizingPage(
            300.dp, 300.dp,
            single("cb", "ConstrainedBox", "b", "constraints" to bounded),
            sizedBox("b", 250, 100),
        )
        assertRect(0, 0, 200, 80, bounds("b"))
    }

    /** A3.2: the constraints apply within the parent's: a tight parent wins. */
    @Test
    fun a3_2_constrainedBoxStaysWithinATightParent() {
        sizingPage(
            300.dp, 300.dp,
            single("cb", "ConstrainedBox", "b", "constraints" to bounded),
            sizedBox("b", 20, 20),
            tight = true,
        )
        assertRect(0, 0, 300, 300, bounds("b"))
    }

    /** A3.2: a missing maximum is no limit (the parent's stays). */
    @Test
    fun a3_2_constrainedBoxWithoutAMaximumLeavesTheParentsLimit() {
        sizingPage(
            300.dp, 300.dp,
            single("cb", "ConstrainedBox", "b", "constraints" to mapOf("minWidth" to 100)),
            sizedBox("b", 250, 20),
        )
        assertRect(0, 0, 250, 20, bounds("b"))
    }

    /** A3.2: without a child it is the smallest size its constraints allow (Flutter's SizedBox.shrink child). */
    @Test
    fun a3_2_constrainedBoxWithoutAChildIsItsMinimum() {
        sizingPage(300.dp, 300.dp, single("cb", "ConstrainedBox", null, "constraints" to bounded))
        assertRect(0, 0, 100, 50, bounds("cb"))
    }

    // A3.2 LimitedBox

    /** A3.2: in a vertical scroll view the height is unbounded and capped; the bounded width is not. */
    @Test
    fun a3_2_limitedBoxCapsOnlyTheAxisItsParentLeavesUnbounded() {
        sizingPage(
            200.dp, 400.dp,
            single("s", "SingleChildScrollView", "lb"),
            single("lb", "LimitedBox", "b", "maxWidth" to 50, "maxHeight" to 100),
            sizedBox("b", 150, 500),
        )
        assertRect(0, 0, 150, 100, bounds("b"))
        assertRect(0, 0, 150, 100, bounds("lb"))
    }

    /** A3.2: under a bounded parent it changes nothing. */
    @Test
    fun a3_2_limitedBoxDoesNothingUnderABoundedParent() {
        sizingPage(
            200.dp, 400.dp,
            single("lb", "LimitedBox", "b", "maxWidth" to 50, "maxHeight" to 100),
            sizedBox("b", 150, 300),
        )
        assertRect(0, 0, 150, 300, bounds("b"))
    }

    // A3.4 Align

    /** A3.4: with no factors Align fills a bounded parent and places its child by `alignment`. */
    @Test
    fun a3_4_alignPlacesItsChildByAlignment() {
        sizingPage(200.dp, 200.dp, single("a", "Align", "b", "alignment" to "bottomRight"), sizedBox("b", 40, 20))
        assertRect(0, 0, 200, 200, bounds("a"))
        assertRect(160, 180, 200, 200, bounds("b"))
    }

    /** A3.4: the alignment defaults to center. */
    @Test
    fun a3_4_alignCentresByDefault() {
        sizingPage(200.dp, 200.dp, single("a", "Align", "b"), sizedBox("b", 40, 20))
        assertRect(80, 90, 120, 110, bounds("b"))
    }

    /** A3.4: a factor makes that axis the child's size times it, the child still placed by `alignment`. */
    @Test
    fun a3_4_alignFactorsSizeItByTheChild() {
        sizingPage(
            200.dp, 200.dp,
            single("a", "Align", "b", "alignment" to "bottomRight", "widthFactor" to 2, "heightFactor" to 1.5),
            sizedBox("b", 40, 20),
        )
        assertRect(0, 0, 80, 30, bounds("a"))
        assertRect(40, 10, 80, 30, bounds("b"))
    }

    /** A3.4: an unbounded axis (in a vertical scroll view) takes the child's size. */
    @Test
    fun a3_4_alignShrinkWrapsAnUnboundedAxis() {
        sizingPage(
            200.dp, 400.dp,
            single("s", "SingleChildScrollView", "a"),
            single("a", "Align", "b", "alignment" to "topRight"),
            sizedBox("b", 40, 20),
        )
        assertRect(0, 0, 200, 20, bounds("a"))
        assertRect(160, 0, 200, 20, bounds("b"))
    }

    // A3.7 FittedBox

    /** A3.7: contain scales the child up until one side fits, centred. */
    @Test
    fun a3_7_fittedBoxContainFitsTheChildCentred() {
        sizingPage(
            200.dp, 200.dp,
            single("fb", "FittedBox", "b", "fit" to "contain"),
            sizedBox("b", 100, 50),
            tight = true,
        )
        assertRect(0, 0, 200, 200, bounds("fb"))
        assertRect(0, 50, 200, 150, drawnBounds("b"))
    }

    /** A3.7: cover scales the child until both sides fill, centred, overflowing the box. */
    @Test
    fun a3_7_fittedBoxCoverFillsTheBoxCentred() {
        sizingPage(
            200.dp, 200.dp,
            single("fb", "FittedBox", "b", "fit" to "cover"),
            sizedBox("b", 100, 50),
            tight = true,
        )
        assertRect(-100, 0, 300, 200, drawnBounds("b"))
    }

    /** A3.7: scaleDown leaves a child that fits at its size, centred. */
    @Test
    fun a3_7_fittedBoxScaleDownDoesNotEnlarge() {
        sizingPage(
            200.dp, 200.dp,
            single("fb", "FittedBox", "b", "fit" to "scaleDown"),
            sizedBox("b", 100, 50),
            tight = true,
        )
        assertRect(50, 75, 150, 125, drawnBounds("b"))
    }

    /** A3.7: scaleDown shrinks a child that does not fit as contain does. */
    @Test
    fun a3_7_fittedBoxScaleDownShrinksALargeChild() {
        sizingPage(
            200.dp, 200.dp,
            single("fb", "FittedBox", "b", "fit" to "scaleDown"),
            sizedBox("b", 400, 100),
            tight = true,
        )
        assertRect(0, 75, 200, 125, drawnBounds("b"))
    }

    /** A3.7: the fit defaults to contain and `alignment` is not read: always centred. */
    @Test
    fun a3_7_fittedBoxDefaultsToContainAndIgnoresAlignment() {
        sizingPage(
            200.dp, 200.dp,
            single("fb", "FittedBox", "b", "alignment" to "topLeft"),
            sizedBox("b", 100, 50),
            tight = true,
        )
        assertRect(0, 50, 200, 150, drawnBounds("b"))
    }

    /** A3.7: in a loose parent the box keeps the child's aspect ratio within the parent's limits. */
    @Test
    fun a3_7_fittedBoxInALooseParentKeepsTheChildsAspectRatio() {
        sizingPage(200.dp, 200.dp, single("fb", "FittedBox", "b"), sizedBox("b", 400, 100))
        assertRect(0, 0, 200, 50, bounds("fb"))
        assertRect(0, 0, 200, 50, drawnBounds("b"))
    }
}
