package com.orcagateway.sdk

import android.content.Context
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.client.OrcaClientException
import com.orcagateway.core.client.OrcaErrorInfo
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.SerializationException
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.ConnectException
import java.net.URI
import java.util.Collections
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * C18.2 on Android, the screen half: through the real OrcaApp, a page that
 * failed to load and a failed config boot show Flutter's error screen
 * (`buildOrcaError`, sdk/lib/src/widgets/orca_error.dart) for their status,
 * or for a server never reached, with the native "Try again" that loads them
 * again; a plugin conflict shows Flutter's "Something Went Wrong" with the
 * conflict's own message, no retry, and nothing fetched. The failed phases
 * carry the error. Then [OrcaErrorView] alone: each kind's title, message and
 * icon, Flutter's sizes, the theme's colours. Swift twin: ErrorScreenTests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class ErrorScreenTest {
    @get:Rule
    val compose = createComposeRule()

    /**
     * Answers like the engine: 412 to a page GET, the counter page to the POST
     * retry, a one-route config to `/config`. With [status] every request is
     * answered with it; with [unreachable] the transport throws the
     * connection error OkHttp throws for a refused connection.
     */
    private class StubEngine(var status: Int? = null, var unreachable: Boolean = false) : HttpTransport {
        val requests: MutableList<HttpRequest> = Collections.synchronizedList(ArrayList())
        private val page = requireNotNull(javaClass.getResource("/pages/counter-home.json")).readBytes()

        override suspend fun send(request: HttpRequest): HttpResponse {
            requests += request
            if (unreachable) throw ConnectException("Connection refused")
            status?.let { return HttpResponse(it, body = BODY.toByteArray()) }
            if (request.url.path.endsWith("/config")) return HttpResponse(200, JSON, CONFIG.toByteArray())
            if (request.method == "GET") return HttpResponse(412, body = """{"error":"caps_vector_unknown"}""".toByteArray())
            return HttpResponse(200, JSON, page)
        }

        val paths: List<String> get() = requests.toList().map { it.url.path }
    }

    /** A plugin with one widget, `X`, for the conflict. */
    private class WidgetsPlugin(override val name: String) : OrcaPlugin {
        override val widgets: Map<String, WidgetBuilder> = mapOf("X" to nothing)
    }

    private fun client(engine: StubEngine) =
        OrcaClient(URI("http://engine.invalid"), appId = "counter", apiKey = "demo-key", transport = engine)

    private fun count(text: String): Int = compose.onAllNodes(hasText(text)).fetchSemanticsNodes().size

    private fun waitForText(text: String) {
        compose.waitUntil(5_000) { count(text) > 0 }
    }

    private fun style(text: String): TextStyle {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithText(text).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single().layoutInput.style
    }

    @Test
    fun c18_2_aPageAnswering404ShowsNotFoundWithItsMessageAndTryAgain() {
        val engine = StubEngine(status = 404)
        compose.setContent { OrcaApp(client(engine), path = "home") }

        waitForText("Not Found")
        compose.onNodeWithText("The requested page could not be found.").assertIsDisplayed()
        compose.onNodeWithText("Try again").assertIsDisplayed()
        compose.onNodeWithTag("orca.error").assertIsDisplayed()
        compose.onNodeWithTag("orca.error.icon").assertIsDisplayed()
        // The raw answer is not on the screen any more.
        assertEquals(0, count("HTTP 404: $BODY"))
    }

    @Test
    fun c18_2_401_403_429And503EachShowTheirOwnTitleAndMessage() {
        val engine = StubEngine(status = 401)
        compose.setContent { OrcaApp(client(engine), path = "home") }
        val screens = listOf(
            Triple(401, "Unauthorized", "Invalid or missing API key. Please check your configuration."),
            Triple(403, "Forbidden", "You do not have permission to access this resource."),
            Triple(429, "Too Many Requests", "Please slow down and try again in a moment."),
            Triple(503, "Server Error", "Something went wrong on the server. Please try again later."),
        )

        for ((status, title, message) in screens) {
            if (status != 401) {
                engine.status = status
                compose.onNodeWithText("Try again").performClick()
            }
            waitForText(title)
            compose.onNodeWithText(message).assertIsDisplayed()
            compose.onNodeWithText("Try again").assertIsDisplayed()
        }
        // One page request per load: the first, then one per retry.
        assertEquals(4, engine.requests.size)
    }

    @Test
    fun c18_2_anUnreachableServerShowsConnectionFailedWithItsMessage() {
        val engine = StubEngine(unreachable = true)
        compose.setContent { OrcaApp(client(engine), path = "home") }

        waitForText("Connection Failed")
        compose.onNodeWithText("Unable to reach the server. Please check your network and server status.").assertIsDisplayed()
        compose.onNodeWithText("Try again").assertIsDisplayed()
    }

    @Test
    fun c18_2_aConfigBootFailingWith500ShowsServerErrorAndItsRetryLoadsTheApp() {
        val engine = StubEngine(status = 500)
        compose.setContent { OrcaApp(client(engine), path = null) }

        waitForText("Server Error")
        compose.onNodeWithText("Something went wrong on the server. Please try again later.").assertIsDisplayed()
        assertEquals(listOf("/api/v1/app/counter/config"), engine.paths)

        engine.status = null
        compose.onNodeWithText("Try again").performClick()
        waitForText("Counter Example")
        assertEquals(0, count("Server Error"))
    }

    @Test
    fun c18_2_aPluginConflictShowsSomethingWentWrongWithTheConflictMessageNoRetryAndFetchesNothing() {
        val engine = StubEngine()
        compose.setContent {
            OrcaApp(client(engine), enableOffline = true, plugins = listOf(WidgetsPlugin("a"), WidgetsPlugin("b")))
        }

        waitForText("Something Went Wrong")
        compose.onNodeWithText("Widget type \"X\" from plugin \"b\" conflicts with plugin \"a\".").assertIsDisplayed()
        compose.onNodeWithTag("orca.error.icon").assertIsDisplayed()
        compose.waitForIdle()
        // The conflict's message replaces Flutter's, and nothing can be tried again.
        assertEquals(0, count("An unexpected error occurred. Please try again."))
        assertEquals(0, count("Try again"))
        assertTrue(engine.requests.isEmpty())
    }

    @Test
    fun c18_2_aRetryAfterAFailedPageLoadsThePage() {
        val engine = StubEngine(status = 404)
        compose.setContent { OrcaApp(client(engine), path = "home") }
        waitForText("Not Found")

        engine.status = null
        compose.onNodeWithText("Try again").performClick()
        waitForText("Counter Example")
        compose.onNodeWithText("0").assertIsDisplayed()
        assertEquals(0, count("Not Found"))
    }

    /** The failed phases keep today's message and carry the error, for a host's own view. */
    @Test
    fun c18_2_theFailedPhasesCarryTheErrorAndKeepTheirMessage(): Unit = runBlocking {
        val context: Context = ApplicationProvider.getApplicationContext()

        val page = OrcaPageLoader(client(StubEngine(status = 404)), "home")
        page.reload(context)
        val notFound = assertIs<OrcaPageLoader.Phase.Failed>(page.phase)
        assertEquals("HTTP 404: $BODY", notFound.message)
        assertEquals(OrcaClientException.Http(404, BODY), notFound.error)

        val unreachable = OrcaPageLoader(client(StubEngine(unreachable = true)), "home")
        unreachable.reload(context)
        val down = assertIs<OrcaPageLoader.Phase.Failed>(unreachable.phase)
        assertEquals("Connection refused", down.message)
        assertIs<ConnectException>(down.error)

        val boot = OrcaAppBoot(client(StubEngine(status = 500)))
        boot.reload(context)
        val server = assertIs<OrcaAppBoot.Phase.Failed>(boot.phase)
        assertEquals("HTTP 500: $BODY", server.message)
        assertEquals(OrcaClientException.Http(500, BODY), server.error)

        // A failed phase made as before still compiles, without an error.
        assertNull(OrcaPageLoader.Phase.Failed("x").error)
        assertNull(OrcaAppBoot.Phase.Failed("x").error)
    }

    /** Each kind of [OrcaErrorInfo]: Flutter's title and message, and the Material icon Flutter draws. */
    @Test
    fun c18_2_theErrorViewDrawsEachKindsTitleMessageAndIcon() {
        class Screen(val error: Throwable, val title: String, val message: String, val icon: String)
        val screens = listOf(
            Screen(
                OrcaClientException.Http(401, ""), "Unauthorized",
                "Invalid or missing API key. Please check your configuration.", "Outlined.Lock",
            ),
            Screen(
                OrcaClientException.Http(403, ""), "Forbidden",
                "You do not have permission to access this resource.", "Filled.Block",
            ),
            Screen(OrcaClientException.Http(404, ""), "Not Found", "The requested page could not be found.", "Filled.SearchOff"),
            Screen(
                OrcaClientException.Http(429, ""), "Too Many Requests",
                "Please slow down and try again in a moment.", "Filled.Speed",
            ),
            Screen(
                OrcaClientException.Http(502, ""), "Server Error",
                "Something went wrong on the server. Please try again later.", "Filled.CloudOff",
            ),
            Screen(OrcaClientException.Http(418, ""), "Error", "Failed to fetch page: 418", "Filled.ErrorOutline"),
            Screen(
                SerializationException("not a page"), "Configuration Error",
                "Invalid value in configuration. Please check your setup.", "Filled.Settings",
            ),
            Screen(
                ConnectException("Connection refused"), "Connection Failed",
                "Unable to reach the server. Please check your network and server status.", "Filled.WifiOff",
            ),
            Screen(
                IllegalStateException("boom"), "Something Went Wrong",
                "An unexpected error occurred. Please try again.", "Filled.ErrorOutline",
            ),
        )
        var shown: Throwable by mutableStateOf(screens.first().error)
        compose.setContent { OrcaErrorView(shown) }

        for (screen in screens) {
            compose.runOnIdle { shown = screen.error }
            compose.onNodeWithText(screen.title).assertIsDisplayed()
            compose.onNodeWithText(screen.message).assertIsDisplayed()
            compose.onNodeWithTag("orca.error.icon").assertIsDisplayed()
            assertEquals(screen.icon, errorIcon(OrcaErrorInfo.from(screen.error).kind).name, screen.title)
        }
        // No onRetry, no button.
        assertEquals(0, count("Try again"))
    }

    /** Flutter's sizes (icon 48, gaps 16 and 8, title 18 semibold, message 14, centred), the theme's colours, and Try again. */
    @Test
    fun c18_2_theErrorViewHasFlutterSizesTheThemeColoursAndTryAgainWhenItCanRetry() {
        val dark = darkColorScheme()
        var retried = 0
        compose.setContent {
            MaterialTheme(colorScheme = dark) {
                OrcaErrorView(OrcaClientException.Http(404, ""), onRetry = { retried++ })
            }
        }

        val icon = compose.onNodeWithTag("orca.error.icon").getUnclippedBoundsInRoot()
        val title = compose.onNodeWithText("Not Found").getUnclippedBoundsInRoot()
        val message = compose.onNodeWithText("The requested page could not be found.").getUnclippedBoundsInRoot()
        assertEquals(48.dp, icon.right - icon.left)
        assertEquals(48.dp, icon.bottom - icon.top)
        assertEquals(16.dp, title.top - icon.bottom)
        assertEquals(8.dp, message.top - title.bottom)

        val titleStyle = style("Not Found")
        assertEquals(18.sp, titleStyle.fontSize)
        assertEquals(FontWeight.SemiBold, titleStyle.fontWeight)
        assertEquals(TextAlign.Center, titleStyle.textAlign)
        assertEquals(dark.onSurface, titleStyle.color)
        val messageStyle = style("The requested page could not be found.")
        assertEquals(14.sp, messageStyle.fontSize)
        assertEquals(TextAlign.Center, messageStyle.textAlign)
        assertEquals(dark.onSurfaceVariant, messageStyle.color)

        compose.onNodeWithText("Try again").performClick()
        compose.runOnIdle { assertEquals(1, retried) }
    }

    /**
     * Flutter's sizes go onto the host's text style, as Flutter's inheriting
     * TextStyle does: the host theme's font family and letter spacing reach
     * the title and the message.
     */
    @Test
    fun c18_2_theErrorViewKeepsTheHostFontFamilyAndLetterSpacingUnderFlutterSizes() {
        val host = TextStyle(fontFamily = FontFamily.Serif, letterSpacing = 2.sp)
        compose.setContent {
            MaterialTheme(typography = Typography(bodyLarge = host)) {
                OrcaErrorView(OrcaClientException.Http(404, ""))
            }
        }

        val titleStyle = style("Not Found")
        assertEquals(FontFamily.Serif, titleStyle.fontFamily)
        assertEquals(2.sp, titleStyle.letterSpacing)
        assertEquals(18.sp, titleStyle.fontSize)
        assertEquals(FontWeight.SemiBold, titleStyle.fontWeight)
        val messageStyle = style("The requested page could not be found.")
        assertEquals(FontFamily.Serif, messageStyle.fontFamily)
        assertEquals(2.sp, messageStyle.letterSpacing)
        assertEquals(14.sp, messageStyle.fontSize)
    }

    private companion object {
        const val BODY = """{"error":"boom"}"""
        val JSON = mapOf("content-type" to "application/json")
        const val CONFIG = """{"initialRoute":"/home","flows":[{"name":"main","routes":[{"path":"home"}]}]}"""

        val nothing: WidgetBuilder = { _, _, _ -> }
    }
}
