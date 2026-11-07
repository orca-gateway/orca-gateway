package com.orcagateway.sdk.style

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.text
import kotlinx.serialization.json.Json
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.net.URI
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * S9.15 (Swift's `OrcaThemeTests`): a host button style draws the buttons
 * the server left plain, a server style prop wins over it, and the theme set
 * once reaches every button below, through OrcaApp's pages. At 1 dp per
 * pixel; a label's inset is how far it sits from its button's left edge,
 * the start padding (Material 3: 24 dp, 12 dp for a TextButton).
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w400dp-h900dp-mdpi")
class OrcaThemeTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    private val red = Color(0xFFFF0000)

    private val theme = OrcaTheme(
        elevatedButton = OrcaButtonStyle(containerColor = red, contentPadding = PaddingValues(40.dp)),
        outlinedButton = OrcaButtonStyle(contentPadding = PaddingValues(40.dp)),
        textButton = OrcaButtonStyle(contentPadding = PaddingValues(40.dp)),
    )

    /** One button of [type] with a Text label, and that label. */
    private fun labelled(id: String, type: String, label: String, props: Map<String, Any?> = emptyMap()) =
        arrayOf(button(id, type, "$id-label", emptyMap(), props.mapValues { JsonValue.of(it.value) }), text("$id-label", label))

    /** Pages one under the other, each in its own box and under its own theme. */
    private fun show(vararg pages: Pair<OrcaTheme, PageResponse>) {
        val models = pages.map { (theme, page) -> theme to OrcaPageModel(page) }
        compose.setContent {
            view = LocalView.current
            Column {
                for ((theme, model) in models) {
                    Box(Modifier.height(450.dp)) {
                        CompositionLocalProvider(LocalOrcaTheme provides theme) { OrcaPageView(model) }
                    }
                }
            }
        }
    }

    /** The button drawn with [label] (the merged node), then the label alone. */
    private fun bounds(label: String): Pair<DpRect, DpRect> =
        compose.onNodeWithText(label).getUnclippedBoundsInRoot() to
            compose.onNodeWithText(label, useUnmergedTree = true).getUnclippedBoundsInRoot()

    private fun inset(label: String): Dp {
        val (button, text) = bounds(label)
        return text.left - button.left
    }

    /**
     * H1: with a style set for each type, a button the server left plain is
     * drawn with it (its padding, the ElevatedButton's colour). Without a
     * theme the same button is drawn as before.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun h1_theHostStylesAButtonTheServerLeftPlain() {
        show(
            theme to page(
                column("0", "e", "o", "t"),
                *labelled("e", "ElevatedButton", "Elevated plain"),
                *labelled("o", "OutlinedButton", "Outlined plain"),
                *labelled("t", "TextButton", "Text plain"),
            ),
            OrcaTheme() to page(column("0", "n"), *labelled("n", "ElevatedButton", "Elevated unthemed")),
        )

        assertEquals(40.dp, inset("Elevated plain"))
        assertEquals(40.dp, inset("Outlined plain"))
        assertEquals(40.dp, inset("Text plain"))
        assertEquals(24.dp, inset("Elevated unthemed"))

        compose.waitForIdle()
        val picture = draw(requireNotNull(view))
        assertPixel(red, picture, inside("Elevated plain"))
        val unthemed = picture.colorAt(inside("Elevated unthemed"))
        assertTrue(!unthemed.near(red), "an unthemed button is not the host's red: $unthemed")
    }

    /**
     * H2: a button carrying one of its type's style props is drawn by the
     * server's props, the host style off; props that do not style the
     * button, and a null style prop, leave the host style on.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun h2_aServerStylePropWins() {
        show(
            theme to page(
                column("0", "bg", "radius", "border", "color", "enabled", "null"),
                *labelled("bg", "ElevatedButton", "Server background", mapOf("backgroundColor" to "#0000FF")),
                *labelled("radius", "ElevatedButton", "Server radius", mapOf("borderRadius" to 24)),
                *labelled("border", "OutlinedButton", "Server border", mapOf("borderColor" to "#000000")),
                *labelled("color", "TextButton", "Server colour", mapOf("color" to "#1976D2")),
                *labelled("enabled", "ElevatedButton", "Only enabled", mapOf("enabled" to true)),
                *labelled("null", "TextButton", "Null colour", mapOf("color" to null)),
            ),
        )

        assertEquals(24.dp, inset("Server background"))
        assertEquals(24.dp, inset("Server radius"))
        assertEquals(24.dp, inset("Server border"))
        assertEquals(12.dp, inset("Server colour"))
        assertEquals(40.dp, inset("Only enabled"))
        assertEquals(40.dp, inset("Null colour"))

        compose.waitForIdle()
        val picture = draw(requireNotNull(view))
        assertPixel(Color(0xFF0000FF), picture, inside("Server background"))
    }

    /**
     * H3: the theme set once above OrcaApp reaches a button nested in a
     * Column and a Row on the root page, and a button on a page pushed over
     * it.
     */
    @Test
    fun h3_theThemeTravelsDownTheTree() {
        val go = Action.Navigate(route = JsonValue.String("/more"))
        val stub = Pages(
            mapOf(
                "home" to listOf(
                    column("0", "1"),
                    row("1", "2"),
                    button("2", "ElevatedButton", "3", mapOf("onTap" to go)),
                    text("3", "Nested go"),
                ),
                "more" to listOf(column("0", "t"), *labelled("t", "TextButton", "Pushed text")),
            ),
        )
        compose.setContent {
            CompositionLocalProvider(LocalOrcaTheme provides theme) { OrcaApp(stub.client) }
        }

        compose.waitUntil(5_000) { count("Nested go") > 0 }
        assertEquals(40.dp, inset("Nested go"))

        compose.onNodeWithText("Nested go").performClick()
        compose.waitUntil(5_000) { count("Pushed text") > 0 }
        assertEquals(40.dp, inset("Pushed text"))
    }

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    /** A point in the button's padding, left of its label, half way down. */
    private fun inside(label: String): Pair<Int, Int> {
        val (button, text) = bounds(label)
        val x = (button.left + (text.left - button.left) / 2).value.toInt()
        val y = ((button.top + button.bottom) / 2).value.toInt()
        return x to y
    }

    /** The view drawn in software on white, as GoldenTest draws it. */
    private fun draw(view: View): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun Bitmap.colorAt(point: Pair<Int, Int>): Color = Color(getPixel(point.first, point.second))

    private fun Color.near(other: Color): Boolean =
        abs(red - other.red) < 0.05f && abs(green - other.green) < 0.05f && abs(blue - other.blue) < 0.05f

    private fun assertPixel(expected: Color, picture: Bitmap, point: Pair<Int, Int>) {
        val actual = picture.colorAt(point)
        assertTrue(actual.near(expected), "$point is $actual, expected $expected")
    }
}

/** Pages by path, as the engine answers them (the `/action` route is never called here). */
private class Pages(private val nodes: Map<String, List<ComponentNode>>) : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse {
        val name = request.url.path.substringAfterLast("/page/")
        val page = PageResponse(pageId = name, title = name, components = nodes.getValue(name))
        return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
    }

    val client: OrcaClient get() = OrcaClient(URI("http://stub.invalid"), appId = "theme-app", transport = this)
}
