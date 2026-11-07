package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getAlignmentLinePosition
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
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
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The Column and Row layout against Flutter's `RenderFlex` numbers, on
 * plain boxes at 1 dp per pixel.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class FlexLayoutTest {
    @get:Rule
    val compose = createComposeRule()

    private fun policy(
        vertical: Boolean,
        main: Props.MainAxis = Props.MainAxis.Start,
        cross: Props.CrossAxis = Props.CrossAxis.Center,
        fill: Boolean = true,
        gap: Dp? = null,
    ) = FlexMeasurePolicy(vertical, main, cross, fill, gap)

    /** A flex of boxes `c0`, `c1`, ... inside a loose box of the given size. */
    private fun flex(
        policy: FlexMeasurePolicy,
        boxes: List<Modifier>,
        width: Dp = 100.dp,
        height: Dp = 100.dp,
        direction: LayoutDirection = LayoutDirection.Ltr,
    ) {
        compose.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides direction) {
                Box(Modifier.size(width, height)) {
                    Layout(
                        content = { boxes.forEachIndexed { i, m -> Box(m.testTag("c$i")) } },
                        modifier = Modifier.testTag("flex"),
                        measurePolicy = policy,
                    )
                }
            }
        }
    }

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private val tens = List(3) { Modifier.size(10.dp) }

    @Test
    fun spaceBetweenWithAGapSpacesTheGapBoxesToo() {
        flex(policy(vertical = false, main = Props.MainAxis.SpaceBetween, gap = 5.dp), tens)
        assertEquals(listOf(0.dp, 45.dp, 90.dp), (0..2).map { bounds("c$it").left })
    }

    @Test
    fun spaceAroundIsHalfSizedAtTheEnds() {
        flex(policy(vertical = false, main = Props.MainAxis.SpaceAround), tens)
        // Free 70 over 3: 23.33 between, 11.67 at each end.
        assertEquals(listOf(12.dp, 45.dp, 78.dp), (0..2).map { bounds("c$it").left })
    }

    @Test
    fun spaceEvenlyCountsTheGapBoxesAsItems() {
        flex(policy(vertical = false, main = Props.MainAxis.SpaceEvenly, gap = 5.dp), tens)
        // Five items (three boxes, two gaps), 60 free over six spaces.
        assertEquals(listOf(10.dp, 45.dp, 80.dp), (0..2).map { bounds("c$it").left })
    }

    @Test
    fun aMaxColumnFillsAndCentres() {
        flex(policy(vertical = true, main = Props.MainAxis.Center), tens.take(2))
        assertEquals(100.dp, bounds("flex").height)
        assertEquals(10.dp, bounds("flex").width)
        assertEquals(listOf(40.dp, 50.dp), (0..1).map { bounds("c$it").top })
    }

    @Test
    fun aMinColumnIsAsLongAsItsChildrenAndGaps() {
        flex(policy(vertical = true, main = Props.MainAxis.End, fill = false, gap = 4.dp), tens)
        assertEquals(38.dp, bounds("flex").height)
        assertEquals(listOf(0.dp, 14.dp, 28.dp), (0..2).map { bounds("c$it").top })
    }

    @Test
    fun crossAxisPlacesNarrowChildrenInTheWidest() {
        flex(policy(vertical = true, cross = Props.CrossAxis.End), listOf(Modifier.size(10.dp), Modifier.size(30.dp)))
        assertEquals(30.dp, bounds("flex").width)
        assertEquals(20.dp, bounds("c0").left)
    }

    @Test
    fun stretchForcesTheCrossAxisAndStartsThere() {
        flex(policy(vertical = true, cross = Props.CrossAxis.Stretch), tens.take(2))
        assertEquals(100.dp, bounds("flex").width)
        assertEquals(100.dp, bounds("c0").width)
        assertEquals(0.dp, bounds("c1").left)
    }

    @Test
    fun childrenHaveNoLimitOnTheMainAxis() {
        // Flutter gives a Column's children unbounded height, so a child
        // that fills it takes its own (here none); Compose's Column would
        // give it the space left.
        flex(policy(vertical = true), listOf(Modifier.width(10.dp).fillMaxHeight(), Modifier.size(10.dp)))
        assertEquals(0.dp, bounds("c0").height)
        assertEquals(0.dp, bounds("c1").top)
    }

    @Test
    fun aRowStartsOnTheRightInRightToLeft() {
        flex(policy(vertical = false), tens.take(2), direction = LayoutDirection.Rtl)
        assertEquals(90.dp, bounds("c0").left)
        assertEquals(80.dp, bounds("c1").left)
    }

    /** Real font metrics: the legacy graphics mode gives every text the same height. */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun baselineAlignsTheFirstBaselines() {
        compose.setContent {
            Box(Modifier.size(300.dp, 200.dp)) {
                Layout(
                    content = {
                        Text("small", Modifier.testTag("c0"), fontSize = 12.sp)
                        Text("big", Modifier.testTag("c1"), fontSize = 30.sp)
                    },
                    measurePolicy = policy(vertical = false, cross = Props.CrossAxis.Baseline),
                )
            }
        }
        val small = bounds("c0").top + compose.onNodeWithTag("c0").getAlignmentLinePosition(FirstBaseline)
        val big = bounds("c1").top + compose.onNodeWithTag("c1").getAlignmentLinePosition(FirstBaseline)
        assertTrue(abs((small - big).value) <= 1f, "baselines $small and $big")
        assertTrue(bounds("c0").top > bounds("c1").top)
    }

    /**
     * A page drawn from its root inside a loose box, with Expanded and
     * Spacer known to the core and drawn by their composables.
     */
    private fun flexPage(width: Dp, height: Dp, vararg nodes: ComponentNode) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("Expanded", "Spacer"))
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Expanded") { node, model, modifier -> ExpandedWidget(node, model, modifier) }
                register("Spacer") { node, model, modifier -> SpacerWidget(node, model, modifier) }
            }
        }
        compose.setContent {
            Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
        }
    }

    /** A SizedBox around a Text, so the box is found by its text. */
    private fun sizedText(id: String, child: String, width: Int? = null, height: Int? = null) =
        sizedBox(id, width, height).copy(children = listOf(child))

    private fun boundsOfText(data: String): DpRect = compose.onNodeWithText(data).getUnclippedBoundsInRoot()

    @Test
    fun w1_flexSharesTheSpaceLeftByFlex() {
        flex(
            policy(vertical = false),
            listOf(Modifier.size(50.dp, 10.dp), Modifier.flex(1), Modifier.flex(2)),
            width = 200.dp,
        )
        // 150 left after the fixed child, shared 1:2.
        assertEquals(listOf(50.dp, 50.dp, 100.dp), (0..2).map { bounds("c$it").width })
        assertEquals(listOf(0.dp, 50.dp, 100.dp), (0..2).map { bounds("c$it").left })
        assertEquals(200.dp, bounds("flex").width)
        // Centred on the cross axis: an empty flex child in a 10 high row.
        assertEquals(10.dp, bounds("flex").height)
        assertEquals(5.dp, bounds("c1").top)
    }

    @Test
    fun w2_gapsAreTakenBeforeTheShareAndASpacerPushesToTheEnd() {
        flexPage(
            300.dp, 100.dp,
            row(
                "0", "1", "2", "3",
                props = mapOf("gap" to JsonValue.Int(10L), "crossAxisAlignment" to JsonValue.String("start")),
            ),
            sizedText("1", "4", width = 40, height = 10),
            leaf("2", "Spacer"),
            sizedText("3", "5", width = 40, height = 10),
            text("4", "a"),
            text("5", "b"),
        )
        assertEquals(0.dp, boundsOfText("a").left)
        // 300 less the two boxes and the two gaps leaves the Spacer 200.
        assertEquals(260.dp, boundsOfText("b").left)
        assertEquals(300.dp, boundsOfText("b").right)
        assertEquals(0.dp, boundsOfText("b").top)
    }

    @Test
    fun w3_aColumnSharesHeightAndStretchesAcross() {
        flexPage(
            200.dp, 400.dp,
            column("0", "1", "2", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            sizedText("1", "3", height = 100),
            ComponentNode("2", "Expanded", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, children = listOf("4")),
            text("3", "top"),
            text("4", "rest"),
        )
        assertEquals(100.dp, boundsOfText("top").height)
        assertEquals(200.dp, boundsOfText("top").width)
        assertEquals(100.dp, boundsOfText("rest").top)
        assertEquals(300.dp, boundsOfText("rest").height)
        assertEquals(200.dp, boundsOfText("rest").width)
    }
}
