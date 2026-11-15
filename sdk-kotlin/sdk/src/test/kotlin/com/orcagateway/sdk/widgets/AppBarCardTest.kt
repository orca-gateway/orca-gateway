package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.InspectableValue
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.navigation.LocalOrcaNavigation
import com.orcagateway.sdk.navigation.OrcaNavigation
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.net.URI
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A1.9 and the Card half of A1.11 against Flutter's Material 3 AppBar and
 * Card (structure_builders.dart `_buildAppBar`, `_buildCard`), at 1 dp per
 * pixel. AppBars and SizedBoxes are tagged with their node ids.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class AppBarCardTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /** A page drawn from its root inside a loose box, on a page that [navigation] says can pop or not. */
    private fun structurePage(
        width: Dp,
        height: Dp,
        vararg nodes: ComponentNode,
        navigation: OrcaNavigation = OrcaNavigation(router = null, canPop = false),
    ) {
        val model = OrcaPageModel(page(*nodes)).apply {
            builders = WidgetBuilders.standard().apply {
                register("AppBar") { node, model, modifier -> AppBarWidget(node, model, modifier.testTag(node.id)) }
                register("SizedBox") { node, model, modifier -> SizedBoxWidget(node, model, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            CompositionLocalProvider(LocalOrcaNavigation provides navigation) {
                Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
            }
        }
    }

    private fun appBar(id: String, slots: Map<String, String>, props: Map<String, Any?> = emptyMap()) =
        ComponentNode(
            id, "AppBar", ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
            (props + slots).mapValues { JsonValue.of(it.value) }, slots.values.toList(),
        )

    private fun node(id: String, type: String, vararg children: String, props: Map<String, Any?> = emptyMap()) =
        ComponentNode(
            id, type, ComponentNode.Kind.Layout,
            if (type == "Stack") ComponentNode.ChildMode.Multi else ComponentNode.ChildMode.Single,
            props.mapValues { JsonValue.of(it.value) }, children.toList(),
        )

    private val noMargin = mapOf("top" to 0, "right" to 0, "bottom" to 0, "left" to 0)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    private fun boundsOfText(data: String): DpRect = compose.onNodeWithText(data).getUnclippedBoundsInRoot()

    /** A router with one pushed page; it never fetches one. */
    private fun pushedRouter(): OrcaRouter =
        OrcaRouter(OrcaClient(URI("http://stub.invalid"), appId = "a", transport = NoRequests)).apply { navigate("detail") }

    /** Flutter's AppBar is 56 high (kToolbarHeight) unless toolbarHeight is sent. */
    @Test
    fun a1_9_theBarIs56HighUnlessToolbarHeightIsSent() {
        structurePage(
            400.dp, 300.dp,
            column("root", "plain", "tall"),
            appBar("plain", mapOf("title" to "t1")),
            appBar("tall", mapOf("title" to "t2"), mapOf("toolbarHeight" to 70)),
            text("t1", "Plain"),
            text("t2", "Tall"),
        )
        assertEquals(56.dp, bounds("plain").height)
        assertEquals(70.dp, bounds("tall").height)
    }

    /**
     * Flutter's leading box is `leadingWidth` wide (56 when absent) and as
     * high as the bar, at the start; a title that is not centred starts 16
     * past it, or 16 from the start with no leading.
     */
    @Test
    fun a1_9_leadingWidthSizesTheLeadingBoxAndTheTitleStartsAfterIt() {
        structurePage(
            400.dp, 300.dp,
            column("root", "wide", "default", "bare", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            appBar("wide", mapOf("leading" to "lead1", "title" to "t1"), mapOf("leadingWidth" to 72, "centerTitle" to false)),
            appBar("default", mapOf("leading" to "lead2", "title" to "t2"), mapOf("centerTitle" to false)),
            appBar("bare", mapOf("title" to "t3")),
            sizedBox("lead1", 24, 24),
            sizedBox("lead2", 24, 24),
            text("t1", "Wide"),
            text("t2", "Default"),
            text("t3", "Bare"),
        )
        val wide = bounds("wide")
        val lead1 = bounds("lead1")
        assertEquals(wide.left, lead1.left)
        assertEquals(72.dp, lead1.width)
        assertEquals(56.dp, lead1.height)
        assertEquals(lead1.right + 16.dp, boundsOfText("Wide").left)

        val lead2 = bounds("lead2")
        assertEquals(56.dp, lead2.width)
        assertEquals(lead2.right + 16.dp, boundsOfText("Default").left)

        assertEquals(bounds("bare").left + 16.dp, boundsOfText("Bare").left)
    }

    /**
     * Flutter's M3 AppBar has no shadow at elevation 0 (its default); an
     * elevation casts one in shadowColor.
     */
    @Test
    fun a1_9_elevationAndShadowColorCastTheBarsShadow() {
        structurePage(
            400.dp, 300.dp,
            column("root", "raised", "flat"),
            appBar("raised", mapOf("title" to "t1"), mapOf("elevation" to 4, "shadowColor" to "#FF0000")),
            appBar("flat", mapOf("title" to "t2")),
            text("t1", "Raised"),
            text("t2", "Flat"),
        )
        val shadow = assertNotNull(shadowOf("raised"), "the raised bar's shadow")
        val red = Props.hex("#FF0000")
        assertEquals(4.dp, shadow["elevation"])
        assertEquals(red, shadow["spotColor"])
        assertEquals(red, shadow["ambientColor"])
        assertNull(shadowOf("flat"))
    }

    /**
     * Flutter's M3 AppBar's default shadowColor is transparent
     * (`_AppBarDefaultsM3.shadowColor`): an elevation without a shadowColor
     * casts no shadow.
     */
    @Test
    fun a1_9_anElevationWithoutShadowColorCastsNoShadow() {
        structurePage(
            400.dp, 300.dp,
            appBar("raised", mapOf("title" to "t"), mapOf("elevation" to 4)),
            text("t", "Raised"),
        )
        assertNull(shadowOf("raised"))
    }

    /**
     * A pushed page's AppBar shows a back arrow that goes back, unless
     * automaticallyImplyLeading is false or a leading slot takes its place;
     * with the arrow the title starts 16 past its 56 box.
     */
    @Test
    fun a1_9_aPushedPageShowsABackArrowThatGoesBack() {
        val router = pushedRouter()
        structurePage(
            400.dp, 300.dp,
            column("root", "implied", "off", "own"),
            appBar("implied", mapOf("title" to "t1")),
            appBar("off", mapOf("title" to "t2"), mapOf("automaticallyImplyLeading" to false)),
            appBar("own", mapOf("leading" to "lead", "title" to "t3")),
            sizedBox("lead", 24, 24),
            text("t1", "Implied"),
            text("t2", "Off"),
            text("t3", "Own"),
            navigation = OrcaNavigation(router, canPop = true),
        )
        compose.onAllNodesWithContentDescription("Back").assertCountEquals(1)
        assertEquals(bounds("implied").left + 72.dp, boundsOfText("Implied").left)
        assertEquals(bounds("off").left + 16.dp, boundsOfText("Off").left)
        assertEquals(56.dp, bounds("lead").width)

        compose.onNode(hasContentDescription("Back") and hasAnyAncestor(hasTestTag("implied"))).performClick()
        compose.waitForIdle()
        assertEquals(emptyList(), router.stack)
    }

    /** The root page (it cannot pop) shows no back arrow. */
    @Test
    fun a1_9_theRootPageShowsNoBackArrow() {
        structurePage(
            400.dp, 300.dp,
            appBar("bar", mapOf("title" to "t")),
            text("t", "Root"),
            navigation = OrcaNavigation(pushedRouter(), canPop = false),
        )
        compose.onAllNodesWithContentDescription("Back").assertCountEquals(0)
        assertEquals(bounds("bar").left + 16.dp, boundsOfText("Root").left)
    }

    /**
     * Flutter's M3 Card lays surfaceTintColor over its colour with the
     * opacity of its elevation (ElevationOverlay.applySurfaceTint: .05 at
     * 1, .08 at 3, linear between, .14 from 12 up).
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a1_11_surfaceTintIsLaidOverTheCardColourByItsElevation() {
        val white = "#FFFFFF"
        val tinted = { elevation: Int ->
            mapOf("color" to white, "surfaceTintColor" to "#FF0000", "elevation" to elevation, "margin" to noMargin)
        }
        structurePage(
            100.dp, 260.dp,
            column("root", "e3", "e2", "e20", "plain", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            // y 0..60, 60..120, 120..180, 180..240.
            node("e3", "Card", "s1", props = tinted(3)),
            node("e2", "Card", "s2", props = tinted(2)),
            node("e20", "Card", "s3", props = tinted(20)),
            node("plain", "Card", "s4", props = mapOf("color" to white, "elevation" to 3, "margin" to noMargin)),
            sizedBox("s1", 60, 60),
            sizedBox("s2", 60, 60),
            sizedBox("s3", 60, 60),
            sizedBox("s4", 60, 60),
        )
        compose.waitForIdle()
        val picture = draw(requireNotNull(view))

        assertPixel(Color(1f, 0.92f, 0.92f), picture, 30, 30)
        assertPixel(Color(1f, 0.935f, 0.935f), picture, 30, 90)
        assertPixel(Color(1f, 0.86f, 0.86f), picture, 30, 150)
        assertPixel(Color.White, picture, 30, 210)
    }

    /**
     * A Card clips its child to its shape only when clipBehavior is sent
     * (Flutter's Card: Clip.none by default). Each Card holds a 60x60 Stack
     * whose red Positioned square hangs 40 past its right and bottom.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a1_11_aCardClipsItsChildOnlyWhenClipBehaviorIsSent() {
        val blue = Props.hex("#0000FF")
        val red = Props.hex("#FF0000")
        val card = mapOf("color" to "#0000FF", "elevation" to 0, "margin" to noMargin)
        val overhang = mapOf("left" to 40, "top" to 40, "width" to 60, "height" to 60)
        structurePage(
            200.dp, 240.dp,
            column("root", "clipped", "gap", "open", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            // y 0..60, gap 60..100, 100..160 (its square to 200).
            node("clipped", "Card", "stack1", props = card + ("clipBehavior" to "antiAlias")),
            sizedBox("gap", 10, 40),
            node("open", "Card", "stack2", props = card),
            node("stack1", "Stack", "box1", "pos1"),
            node("stack2", "Stack", "box2", "pos2"),
            sizedBox("box1", 60, 60),
            sizedBox("box2", 60, 60),
            node("pos1", "Positioned", "red1", props = overhang),
            node("pos2", "Positioned", "red2", props = overhang),
            node("red1", "Container", props = mapOf("color" to "#FF0000")),
            node("red2", "Container", props = mapOf("color" to "#FF0000")),
        )
        compose.waitForIdle()
        val picture = draw(requireNotNull(view))

        assertPixel(blue, picture, 20, 20)
        assertPixel(red, picture, 50, 50)
        assertPixel(Color.White, picture, 80, 80)
        assertPixel(Color.White, picture, 50, 80)

        assertPixel(blue, picture, 20, 120)
        assertPixel(red, picture, 50, 150)
        assertPixel(red, picture, 80, 180)
    }

    /** The bar's `Modifier.shadow`, as its inspector reports it, or null when it casts none. */
    private fun shadowOf(tag: String): Map<String, Any?>? =
        compose.onNodeWithTag(tag).fetchSemanticsNode().layoutInfo.getModifierInfo()
            .map { it.modifier }
            .filterIsInstance<InspectableValue>()
            .firstOrNull { it.nameFallback == "shadow" }
            ?.inspectableElements?.associate { it.name to it.value }

    /** The view drawn in software on white, as GoldenTest draws it (no elevation shadows). */
    private fun draw(view: View): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    /** Each channel within 1% of the expected one (the tints differ by 1.5% and more). */
    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.01f },
            "($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }

    /** The router's client: these tests never fetch a page. */
    private object NoRequests : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse = error("no request expected: ${request.url}")
    }
}
