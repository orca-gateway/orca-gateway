package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.getAlignmentLinePosition
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
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
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.ceil
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Flexible, IntrinsicHeight, IntrinsicWidth and Baseline against Flutter's
 * render objects (`RenderFlex` with a loose `FlexFit`,
 * `RenderIntrinsicHeight`, `RenderIntrinsicWidth`, `RenderBaseline`), at
 * 1 dp per pixel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class FlexibleIntrinsicTest {
    @get:Rule
    val compose = createComposeRule()

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    /** Where the node's first text baseline is, from the top of the root. */
    private fun baselineOf(tag: String): Dp =
        bounds(tag).top + compose.onNodeWithTag(tag).getAlignmentLinePosition(FirstBaseline)

    private fun textLayout(tag: String): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag(tag).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single()
    }

    /**
     * A page drawn from its root inside a box of the given size, loose or
     * (with [tight]) forcing that size on the root. The four types are
     * advertised, so the core's standard registry lets them through; every
     * node is tagged with its id.
     */
    private fun flexPage(width: Dp, height: Dp, vararg nodes: ComponentNode, tight: Boolean = false) {
        val model = OrcaPageModel(page(*nodes)).apply {
            builders = WidgetBuilders.standard().apply {
                register("Flexible") { node, model, modifier -> FlexibleWidget(node, model, modifier.testTag(node.id)) }
                register("Expanded") { node, model, modifier -> ExpandedWidget(node, model, modifier.testTag(node.id)) }
                register("IntrinsicHeight") { node, model, modifier ->
                    IntrinsicHeightWidget(node, model, modifier.testTag(node.id))
                }
                register("IntrinsicWidth") { node, model, modifier ->
                    IntrinsicWidthWidget(node, model, modifier.testTag(node.id))
                }
                register("Baseline") { node, model, modifier -> BaselineWidget(node, model, modifier.testTag(node.id)) }
                register("Row") { node, model, modifier ->
                    FlexWidget(node, model, modifier.testTag(node.id), vertical = false)
                }
                register("Column") { node, model, modifier ->
                    FlexWidget(node, model, modifier.testTag(node.id), vertical = true)
                }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
                register("Text") { node, _, modifier -> TextWidget(node, modifier.testTag(node.id)) }
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

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    private fun assertRect(left: Int, top: Int, right: Int, bottom: Int, actual: DpRect) {
        assertEquals(DpRect(left.dp, top.dp, right.dp, bottom.dp), actual)
    }

    // A3.4 Flexible

    /** A3.4: in a Row a Flexible child keeps its own width within its share; an Expanded one fills its share. */
    @Test
    fun a3_4_flexibleIsLooseWhereExpandedIsTightInARow() {
        flexPage(
            300.dp, 100.dp,
            row("r", "f", "e"),
            single("f", "Flexible", "a"),
            single("e", "Expanded", "b"),
            sizedBox("a", 50, 10),
            sizedBox("b", 50, 10),
        )
        assertRect(0, 0, 50, 10, bounds("a"))
        assertRect(50, 0, 200, 10, bounds("b"))
        assertEquals(300.dp, bounds("r").width)
    }

    /** A3.4: the same in a Column, where `stretch` still forces the cross axis on a Flexible child. */
    @Test
    fun a3_4_flexibleIsLooseWhereExpandedIsTightInAColumn() {
        flexPage(
            100.dp, 300.dp,
            column("c", "f", "e", props = props("crossAxisAlignment" to "stretch")),
            single("f", "Flexible", "a"),
            single("e", "Expanded", "b"),
            sizedBox("a", height = 50),
            sizedBox("b", height = 50),
        )
        assertRect(0, 0, 100, 50, bounds("a"))
        assertRect(0, 50, 100, 200, bounds("b"))
    }

    /** A3.4: `fit: tight` is Expanded's fit. */
    @Test
    fun a3_4_flexibleTightFillsItsShare() {
        flexPage(
            300.dp, 100.dp,
            row("r", "f", "e"),
            single("f", "Flexible", "a", "fit" to "tight"),
            single("e", "Expanded", "b"),
            sizedBox("a", 50, 10),
            sizedBox("b", 50, 10),
        )
        assertRect(0, 0, 150, 10, bounds("a"))
        assertRect(150, 0, 300, 10, bounds("b"))
    }

    /** A3.4: Flexible and Expanded share by `flex` alike, and a loose child larger than its share is held to it. */
    @Test
    fun a3_4_flexibleSharesByFlexAndHoldsALargeChildToItsShare() {
        flexPage(
            300.dp, 100.dp,
            row("r", "f", "e"),
            single("f", "Flexible", "a", "flex" to 2),
            single("e", "Expanded", "b"),
            sizedBox("a", 250, 10),
            sizedBox("b", 50, 10),
        )
        assertRect(0, 0, 200, 10, bounds("a"))
        assertRect(200, 0, 300, 10, bounds("b"))
    }

    /** A3.4: what a loose child leaves of its share goes to no one: `mainAxisAlignment` places it. */
    @Test
    fun a3_4_flexibleLeavesTheRestOfItsShareToMainAxisAlignment() {
        flexPage(
            300.dp, 100.dp,
            row("r", "f", "g", props = props("mainAxisAlignment" to "center")),
            single("f", "Flexible", "a"),
            single("g", "Flexible", "b"),
            sizedBox("a", 50, 10),
            sizedBox("b", 50, 10),
        )
        assertRect(100, 0, 150, 10, bounds("a"))
        assertRect(150, 0, 200, 10, bounds("b"))
    }

    /** A3.4: outside a Row or Column Flexible just draws its child (Flutter's release behaviour). */
    @Test
    fun a3_4_flexibleOutsideARowOrColumnDrawsItsChild() {
        flexPage(200.dp, 200.dp, single("f", "Flexible", "a", "fit" to "tight"), sizedBox("a", 40, 20))
        assertRect(0, 0, 40, 20, bounds("f"))
        assertRect(0, 0, 40, 20, bounds("a"))
    }

    // A3.4 Baseline

    /** A3.4: two texts of different sizes in Baselines with the same value have their baselines `baseline` below the top. */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a3_4_baselinesWithTheSameValueLineUpTheirTexts() {
        flexPage(
            300.dp, 200.dp,
            row("r", "s", "l", props = props("crossAxisAlignment" to "start")),
            single("s", "Baseline", "t1", "baseline" to 40, "baselineType" to "alphabetic"),
            single("l", "Baseline", "t2", "baseline" to 40, "baselineType" to "alphabetic"),
            text("t1", "small", props("style" to mapOf("fontSize" to 12))),
            text("t2", "big", props("style" to mapOf("fontSize" to 30))),
        )
        assertEquals(40.dp, baselineOf("t1"))
        assertEquals(40.dp, baselineOf("t2"))
        assertTrue(bounds("t1").top > bounds("t2").top)
        // Its own size: the child's width by its top plus the child's height.
        val text = bounds("t1")
        assertEquals(DpRect(0.dp, 0.dp, text.width, text.bottom), bounds("s"))
    }

    /** A3.4: `ideographic` is drawn as alphabetic (decision s3-baseline-ideographic). */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a3_4_baselineReadsIdeographicAsAlphabetic() {
        flexPage(
            300.dp, 200.dp,
            single("s", "Baseline", "t", "baseline" to 40, "baselineType" to "ideographic"),
            text("t", "small", props("style" to mapOf("fontSize" to 12))),
        )
        assertEquals(40.dp, baselineOf("t"))
    }

    /** A3.4: a child with no baseline uses its height: its bottom sits at `baseline`. */
    @Test
    fun a3_4_baselineUsesTheHeightOfAChildWithoutABaseline() {
        flexPage(200.dp, 200.dp, single("b", "Baseline", "a", "baseline" to 30), sizedBox("a", 40, 10))
        assertRect(0, 20, 40, 30, bounds("a"))
        assertRect(0, 0, 40, 30, bounds("b"))
    }

    /** A3.4: the child is laid out loosely under a tight parent, and the box takes the parent's size. */
    @Test
    fun a3_4_baselineLoosensATightParentForItsChild() {
        flexPage(
            200.dp, 200.dp,
            single("b", "Baseline", "a", "baseline" to 30),
            sizedBox("a", 40, 10),
            tight = true,
        )
        assertRect(0, 0, 200, 200, bounds("b"))
        assertRect(0, 20, 40, 30, bounds("a"))
    }

    /** A3.4: `baseline` defaults to 0, so a child without one sits above the box, which has no height. */
    @Test
    fun a3_4_baselineDefaultsToZero() {
        flexPage(200.dp, 200.dp, single("b", "Baseline", "a"), sizedBox("a", 40, 10))
        assertRect(0, -10, 40, 0, bounds("a"))
        assertRect(0, 0, 40, 0, bounds("b"))
    }

    // A3.5 IntrinsicHeight

    /** A3.5: IntrinsicHeight around a stretched Row makes every child as tall as the tallest. */
    @Test
    fun a3_5_intrinsicHeightMakesAStretchedRowAsTallAsItsTallestChild() {
        flexPage(
            300.dp, 400.dp,
            single("ih", "IntrinsicHeight", "r"),
            row("r", "a", "b", "c", props = props("crossAxisAlignment" to "stretch")),
            sizedBox("a", width = 50),
            sizedBox("b", 50, 80),
            sizedBox("c", width = 30),
        )
        assertRect(0, 0, 300, 80, bounds("ih"))
        assertRect(0, 0, 50, 80, bounds("a"))
        assertRect(50, 0, 100, 80, bounds("b"))
        assertRect(100, 0, 130, 80, bounds("c"))
    }

    /**
     * A3.5: a flex child counts at the width its share gives it (Flutter's
     * `RenderFlex` intrinsics), so a text wrapping in an Expanded sets the
     * height the stretched bar beside it gets.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a3_5_intrinsicHeightMeasuresAnExpandedTextAtItsShare() {
        flexPage(
            200.dp, 400.dp,
            single("ih", "IntrinsicHeight", "r"),
            row("r", "bar", "e", props = props("crossAxisAlignment" to "stretch")),
            sizedBox("bar", width = 20),
            single("e", "Expanded", "t"),
            text("t", "a text long enough to wrap over a few lines at this width"),
        )
        val text = textLayout("t")
        assertTrue(text.lineCount > 1, "${text.lineCount} lines")
        assertEquals(180f, text.size.width.toFloat())
        assertEquals(ceil(text.multiParagraph.height).dp, bounds("bar").height)
        assertEquals(bounds("bar").height, bounds("ih").height)
    }

    /**
     * A3.5: a Baseline answers its child's intrinsic height
     * (`RenderShiftedBox`), not the shift, so the bar beside it is as tall
     * as the box inside it.
     */
    @Test
    fun a3_5_intrinsicHeightTakesABaselinesChildHeight() {
        flexPage(
            300.dp, 400.dp,
            single("ih", "IntrinsicHeight", "r"),
            row("r", "bar", "bl", props = props("crossAxisAlignment" to "stretch")),
            sizedBox("bar", width = 20),
            single("bl", "Baseline", "a", "baseline" to 30),
            sizedBox("a", 40, 10),
        )
        assertRect(0, 0, 300, 10, bounds("ih"))
        assertRect(0, 0, 20, 10, bounds("bar"))
    }

    // A3.5 IntrinsicWidth

    /** A3.5: IntrinsicWidth around a stretched Column makes every child as wide as the widest. */
    @Test
    fun a3_5_intrinsicWidthMakesAStretchedColumnAsWideAsItsWidestChild() {
        flexPage(
            300.dp, 400.dp,
            single("iw", "IntrinsicWidth", "c"),
            column("c", "a", "b", "d", props = props("crossAxisAlignment" to "stretch")),
            sizedBox("a", height = 20),
            sizedBox("b", 120, 20),
            sizedBox("d", height = 30),
        )
        assertRect(0, 0, 120, 400, bounds("iw"))
        assertRect(0, 0, 120, 20, bounds("a"))
        assertRect(0, 20, 120, 40, bounds("b"))
        assertRect(0, 40, 120, 70, bounds("d"))
    }

    /** A3.5: `stepWidth` rounds that width up to a multiple of it. */
    @Test
    fun a3_5_intrinsicWidthRoundsUpToStepWidth() {
        flexPage(
            300.dp, 400.dp,
            single("iw", "IntrinsicWidth", "c", "stepWidth" to 50),
            column("c", "a", "b", props = props("crossAxisAlignment" to "stretch")),
            sizedBox("a", height = 20),
            sizedBox("b", 120, 20),
        )
        assertRect(0, 0, 150, 400, bounds("iw"))
        assertRect(0, 0, 150, 20, bounds("a"))
    }

    /** A3.5: `stepHeight` makes the height the child's max intrinsic height rounded up to a multiple of it. */
    @Test
    fun a3_5_intrinsicWidthStepHeightRoundsTheHeightUp() {
        flexPage(
            300.dp, 400.dp,
            single("iw", "IntrinsicWidth", "c", "stepWidth" to 50, "stepHeight" to 50),
            column("c", "a", "b", "d", props = props("crossAxisAlignment" to "stretch")),
            sizedBox("a", height = 20),
            sizedBox("b", 120, 20),
            sizedBox("d", height = 30),
        )
        assertRect(0, 0, 150, 100, bounds("iw"))
        assertRect(0, 0, 150, 100, bounds("c"))
        assertRect(0, 40, 150, 70, bounds("d"))
    }

    /**
     * A3.5: a Row's flex children count by their largest width per flex
     * (Flutter's `RenderFlex` intrinsics), so each gets what the widest
     * needs.
     */
    @Test
    fun a3_5_intrinsicWidthGivesARowsFlexChildrenTheLargestShare() {
        flexPage(
            300.dp, 100.dp,
            single("iw", "IntrinsicWidth", "r"),
            row("r", "e1", "e2"),
            single("e1", "Expanded", "a"),
            single("e2", "Expanded", "b"),
            sizedBox("a", 30, 10),
            sizedBox("b", 50, 10),
        )
        assertRect(0, 0, 100, 10, bounds("r"))
        assertRect(0, 0, 50, 10, bounds("a"))
        assertRect(50, 0, 100, 10, bounds("b"))
    }
}
