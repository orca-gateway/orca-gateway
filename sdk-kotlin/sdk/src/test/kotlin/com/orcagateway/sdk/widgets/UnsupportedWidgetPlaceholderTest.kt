package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.UriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.sp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.kotlinRoot
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * C18.4 (look): UnsupportedWidgetPlaceholder drawn as Flutter's
 * `_buildUnsupportedWidgetPlaceholder` (sdk/lib/src/builders/
 * primitive_builders.dart), at 1 dp per pixel. The composable is called
 * directly with a resolved node: it is not registered nor advertised yet.
 * The card is tagged `card`; text is laid out with real font metrics.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class UnsupportedWidgetPlaceholderTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null
    private val accent = Props.hex("#6B7280")
    private val opened = ArrayList<String>()

    private fun node(props: Map<String, JsonValue>) = ResolvedNode(
        id = "root",
        type = "UnsupportedWidgetPlaceholder",
        kind = ComponentNode.Kind.Primitive,
        props = props,
        childIds = emptyList(),
        slots = emptyMap(),
        actions = emptyMap(),
        watches = emptyList(),
    )

    private fun props(vararg props: Pair<String, String>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.String(value) }

    /** Fixture 17's resolved props (schema/fixtures/render/17_unsupported_widget_placeholder.json). */
    private fun fixture17(): Map<String, JsonValue> {
        val file = File(kotlinRoot.parentFile, "schema/fixtures/render/17_unsupported_widget_placeholder.json")
        val expected = JsonValue.parse(file.readText())["expected"].arrayValue!!.single()
        return expected["props"].objectValue!!
    }

    /** The placeholder in a 320 x 300 box at the top left, an italic inherited text style, URIs recorded. */
    private fun draw(props: Map<String, JsonValue>, model: OrcaPageModel = OrcaPageModel(page(text("0", "")))) {
        val handler = object : UriHandler {
            override fun openUri(uri: String) {
                opened.add(uri)
            }
        }
        compose.setContent {
            view = LocalView.current
            CompositionLocalProvider(
                LocalUriHandler provides handler,
                LocalTextStyle provides TextStyle(fontStyle = FontStyle.Italic),
            ) {
                Box(Modifier.size(320.dp, 300.dp), contentAlignment = AbsoluteAlignment.TopLeft) {
                    UnsupportedWidgetPlaceholderWidget(node(props), model, Modifier.testTag("card"))
                }
            }
        }
    }

    private fun bounds(text: String): DpRect = compose.onNodeWithText(text).getUnclippedBoundsInRoot()

    private fun card(): DpRect = compose.onNodeWithTag("card").getUnclippedBoundsInRoot()

    private fun layout(text: String): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithText(text).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single()
    }

    /**
     * Fixture 17: the card (fill #6B7280 at 6%, a 1 px border of it at 35%,
     * corners of 8, the border inside a padding of 16, as Flutter's
     * Container adds the border to the padding), a 20 map icon in the accent
     * and 8 after it the display name (15 semibold #374151, one line with an
     * ellipsis) centred on the icon, 6 below the reason (13 #6B7280), 8
     * below "Learn more" (13 semibold #2563EB, underlined); the card as wide
     * as its widest line. Each style merges onto the inherited one.
     */
    @Test
    fun c18_4_fixture17IsDrawnAsFlutterDrawsIt() {
        val props = fixture17()
        draw(props)
        val reasonText = props.getValue("reason").stringValue!!

        compose.onNodeWithText("Google Maps").assertIsDisplayed()
        compose.onNodeWithText(reasonText).assertIsDisplayed()
        compose.onNodeWithText("Learn more").assertIsDisplayed()

        val title = layout("Google Maps").layoutInput
        assertEquals(15.sp, title.style.fontSize)
        assertEquals(FontWeight.SemiBold, title.style.fontWeight)
        assertEquals(Props.hex("#374151"), title.style.color)
        assertEquals(FontStyle.Italic, title.style.fontStyle)
        assertEquals(1, title.maxLines)
        assertEquals(TextOverflow.Ellipsis, title.overflow)
        val reason = layout(reasonText).layoutInput
        assertEquals(13.sp, reason.style.fontSize)
        assertEquals(accent, reason.style.color)
        assertEquals(FontStyle.Italic, reason.style.fontStyle)
        val link = layout("Learn more").layoutInput
        assertEquals(13.sp, link.style.fontSize)
        assertEquals(FontWeight.SemiBold, link.style.fontWeight)
        assertEquals(Props.hex("#2563EB"), link.style.color)
        assertEquals(TextDecoration.Underline, link.style.textDecoration)
        assertEquals(FontStyle.Italic, link.style.fontStyle)

        val card = card()
        val titleBox = bounds("Google Maps")
        val reasonBox = bounds(reasonText)
        val linkBox = bounds("Learn more")
        val rowTop = card.top + 17.dp
        val rowHeight = maxOf(20.dp, titleBox.height)
        near(card.left + 17.dp + 20.dp + 8.dp, titleBox.left, "title left")
        near(rowTop + (rowHeight - titleBox.height) / 2, titleBox.top, "title top", 1f)
        near(card.left + 17.dp, reasonBox.left, "reason left")
        near(rowTop + rowHeight + 6.dp, reasonBox.top, "reason top")
        near(card.left + 17.dp, linkBox.left, "link left")
        near(reasonBox.bottom + 8.dp, linkBox.top, "link top")
        near(linkBox.bottom + 17.dp, card.bottom, "card bottom")
        near(maxOf(titleBox.right, reasonBox.right, linkBox.right) + 17.dp, card.right, "card right")

        compose.waitForIdle()
        val picture = capture()
        val fill = accent.copy(alpha = 0.06f).compositeOver(Color.White)
        val border = accent.copy(alpha = 0.35f).compositeOver(fill)
        val left = card.left.value.roundToInt()
        val top = card.top.value.roundToInt()
        val middle = ((card.top.value + card.bottom.value) / 2).roundToInt()
        assertPixel(fill, picture, left + 8, middle, "fill")
        assertPixel(border, picture, left, middle, "border")
        assertPixel(Color.White, picture, left, top, "rounded corner")
        // Flutter's `map`, not its `circle` fallback: a filled left panel, a hollow middle one.
        val iconLeft = left + 17
        val iconTop = (rowTop + (rowHeight - 20.dp) / 2).value.roundToInt()
        assertPixel(accent.compositeOver(fill), picture, iconLeft + 5, iconTop + 10, "icon's left panel")
        assertPixel(fill, picture, iconLeft + 10, iconTop + 10, "icon's middle panel")
    }

    /**
     * Only `widgetType`: it is the title, no icon (the title 16 + 1 in), the
     * default reason, no "Learn more". An empty displayName and docsUrl are
     * as absent.
     */
    @Test
    fun c18_4_withOnlyAWidgetTypeTheTitleIsItAndTheRestDefaults() {
        draw(props("widgetType" to "CustomWidget", "displayName" to "", "docsUrl" to ""))

        compose.onNodeWithText("CustomWidget").assertIsDisplayed()
        compose.onNodeWithText("This widget runs in the compiled mobile app and cannot preview here.").assertIsDisplayed()
        compose.onNodeWithText("Learn more").assertDoesNotExist()
        near(card().left + 17.dp, bounds("CustomWidget").left, "title left without an icon")
        near(card().top + 17.dp, bounds("CustomWidget").top, "title top without an icon")
    }

    /** A display name wider than the card stays on one line and ends in an ellipsis; the card stays in its box. */
    @Test
    fun c18_4_aLongTitleStaysOnOneLineWithAnEllipsis() {
        val long = "A plugin widget with a display name far too long for one line of this card"
        draw(props("widgetType" to "Long", "displayName" to long, "iconName" to "map", "reason" to "No."))

        val title = layout(long)
        assertEquals(1, title.lineCount)
        assertTrue(title.isLineEllipsized(0), "the title ends in an ellipsis")
        assertTrue(card().right <= 320.dp, "the card stays in its box: ${card().right}")
    }

    /** A docsUrl the URL policy refuses: the link shows, a tap neither reaches the host nor opens anything. */
    @Test
    fun c18_4_aDisallowedDocsUrlDoesNothingOnTap() {
        val model = OrcaPageModel(page(text("0", "")))
        val handled = ArrayList<ActionEffect>()
        model.effectHandler = { handled.add(it) }
        draw(props("widgetType" to "OrcaGoogleMap", "docsUrl" to "javascript:alert(1)"), model)

        compose.onNodeWithText("Learn more").performClick()
        assertEquals(emptyList(), handled)
        assertEquals(emptyList(), opened)
    }

    /** An allowed docsUrl, as FallbackPrompt's call to action: an `openUrl` effect to the host. */
    @Test
    fun c18_4_anAllowedDocsUrlGoesToTheHost() {
        val model = OrcaPageModel(page(text("0", "")))
        val handled = ArrayList<ActionEffect>()
        model.effectHandler = { handled.add(it) }
        draw(fixture17(), model)

        compose.onNodeWithText("Learn more").performClick()
        val url = JsonValue.String("https://docs.orcagateway.com/plugins/orca_google_map")
        assertEquals(listOf(ActionEffect("openUrl", mapOf("url" to url))), handled)
        assertEquals(emptyList(), opened)
    }

    /** An allowed docsUrl with no host for effects: the platform's URI handler opens it. */
    @Test
    fun c18_4_withoutAHostAnAllowedDocsUrlOpensDirectly() {
        draw(fixture17())

        compose.onNodeWithText("Learn more").performClick()
        assertEquals(listOf("https://docs.orcagateway.com/plugins/orca_google_map"), opened)
    }

    private fun near(expected: Dp, actual: Dp, what: String, within: Float = 0.5f) {
        assertTrue(abs(expected.value - actual.value) <= within, "$what: $actual, expected $expected")
    }

    /** The view drawn in software on white, as GoldenTest draws it. */
    private fun capture(): Bitmap {
        val drawn = requireNotNull(view)
        val bitmap = Bitmap.createBitmap(drawn.width, drawn.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        drawn.draw(Canvas(bitmap))
        return bitmap
    }

    /** Each channel within 3 of 255 of [expected]. */
    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int, what: String) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual),
            expected.green to android.graphics.Color.green(actual),
            expected.blue to android.graphics.Color.blue(actual),
        )
        assertTrue(
            channels.all { (want, got) -> abs(want * 255f - got) <= 3f },
            "$what ($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }
}
