package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
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
 * S9.9: Flutter's `Container` sizing and `ClipRRect`'s corners, at 1 dp
 * per pixel. Each Container is tagged with its node id, so its box
 * (margin included) is found by id.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class BoxTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /** A page drawn from its root inside a loose box, Container and ClipRRect known to the core and drawn here. */
    private fun boxPage(width: Dp, height: Dp, vararg nodes: ComponentNode) {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("Container", "ClipRRect"))
        val model = OrcaPageModel(page(*nodes), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Container") { node, model, modifier -> ContainerWidget(node, model, modifier.testTag(node.id)) }
                register("ClipRRect") { node, model, modifier -> ClipRRectWidget(node, model, modifier) }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
        }
    }

    private fun container(id: String, vararg children: String, props: Map<String, Any?> = emptyMap()) =
        ComponentNode(
            id, "Container", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            props.mapValues { JsonValue.of(it.value) }, children.toList(),
        )

    private fun clipRRect(id: String, child: String, radius: Any) =
        ComponentNode(
            id, "ClipRRect", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
            mapOf("borderRadius" to JsonValue.of(radius)), listOf(child),
        )

    private fun all(side: Int) = mapOf("top" to side, "right" to side, "bottom" to side, "left" to side)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun boundsOfText(data: String): DpRect = compose.onNodeWithText(data).getUnclippedBoundsInRoot()

    /**
     * W4: a Container with a child takes its child's size plus padding,
     * except on an axis its parent forces (a stretched Column's width),
     * which it fills; the Column's height is not forced, so it does not
     * fill down. With no child it takes all the space it may (none on an
     * unbounded axis); a width and height fix its size; an alignment makes
     * it as big as it may be and places the loose child in it. Margin is
     * outside, a border's width is added to the padding.
     */
    @Test
    fun w4_aContainerFillsOnlyTheAxisItsParentForces() {
        boxPage(
            300.dp, 400.dp,
            column("root", "forced", "empty", "start", props = mapOf("crossAxisAlignment" to JsonValue.String("stretch"))),
            container("forced", "t1", props = mapOf("padding" to all(8))),
            container("empty"),
            column(
                "start", "loose", "sized", "aligned", "filled", "framed",
                props = mapOf("crossAxisAlignment" to JsonValue.String("start")),
            ),
            container("loose", "t2", props = mapOf("padding" to all(8))),
            container("sized", "t3", props = mapOf("width" to 50, "height" to 40)),
            container("aligned", "t4", props = mapOf("height" to 60, "alignment" to "bottomRight")),
            container("filled", props = mapOf("height" to 30, "color" to "#FF0000")),
            container(
                "framed", "t5",
                props = mapOf(
                    "margin" to all(4),
                    "padding" to all(8),
                    "decoration" to mapOf("border" to mapOf("width" to 2)),
                ),
            ),
            text("t1", "forced"),
            text("t2", "loose"),
            text("t3", "sized"),
            text("t4", "aligned"),
            text("t5", "framed"),
        )

        val forced = bounds("forced")
        assertEquals(300.dp, forced.width)
        assertEquals(boundsOfText("forced").height + 16.dp, forced.height)
        assertEquals(284.dp, boundsOfText("forced").width)

        assertEquals(300.dp, bounds("empty").width)
        assertEquals(0.dp, bounds("empty").height)

        val loose = bounds("loose").width
        assertTrue(loose < 100.dp && loose > 16.dp, "loose width $loose")
        assertEquals(boundsOfText("loose").width + 16.dp, loose)

        assertEquals(50.dp, bounds("sized").width)
        assertEquals(40.dp, bounds("sized").height)

        val aligned = bounds("aligned")
        assertEquals(300.dp, aligned.width)
        assertEquals(60.dp, aligned.height)
        assertEquals(aligned.right, boundsOfText("aligned").right)
        assertEquals(aligned.bottom, boundsOfText("aligned").bottom)

        assertEquals(300.dp, bounds("filled").width)
        assertEquals(30.dp, bounds("filled").height)

        val framed = bounds("framed")
        val inner = boundsOfText("framed")
        assertEquals(framed.left + 14.dp, inner.left)
        assertEquals(framed.top + 14.dp, inner.top)
        assertEquals(inner.width + 28.dp, framed.width)
    }

    /**
     * W4 (ClipRRect, and a Container's clipBehavior): the child is cut to
     * the rounded corners, one radius for all four or each its own; a
     * clipping Container cuts its child to its decoration's corners.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun w4_clipRRectAndAClippingContainerCutTheChildAtTheCorners() {
        val red = Props.hex("#FF0000")
        val blue = Props.hex("#0000FF")
        val square = mapOf("width" to 60, "height" to 60, "color" to "#FF0000")
        boxPage(
            100.dp, 200.dp,
            column("root", "all", "one", "clipped", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            // y 0..60, 60..120, 120..180.
            clipRRect("all", "s1", 20),
            clipRRect("one", "s2", mapOf("topLeft" to 20)),
            container(
                "clipped", "fill",
                props = mapOf(
                    "width" to 60, "height" to 60, "clipBehavior" to "hardEdge",
                    "decoration" to mapOf("color" to "#FF0000", "borderRadius" to 20),
                ),
            ),
            container("s1", props = square),
            container("s2", props = square),
            container("fill", props = mapOf("color" to "#0000FF")),
        )
        compose.waitForIdle()
        val picture = draw(requireNotNull(view))

        assertPixel(red, picture, 30, 30)
        for ((x, y) in listOf(1 to 1, 58 to 1, 1 to 58, 58 to 58)) assertPixel(Color.White, picture, x, y)

        assertPixel(Color.White, picture, 1, 61)
        for ((x, y) in listOf(58 to 61, 1 to 118, 58 to 118)) assertPixel(red, picture, x, y)

        assertPixel(blue, picture, 30, 150)
        for ((x, y) in listOf(1 to 121, 58 to 121, 1 to 178, 58 to 178)) assertPixel(Color.White, picture, x, y)
    }

    /** The view drawn in software on white, as GoldenTest draws it. */
    private fun draw(view: View): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.05f },
            "($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }
}
