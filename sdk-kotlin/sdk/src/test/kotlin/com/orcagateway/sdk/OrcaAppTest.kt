package com.orcagateway.sdk

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * OrcaApp end to end against a stub engine: the 412 handshake, the device
 * headers filled from this device, the counter drawn and counting, and the
 * error page with its retry.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class OrcaAppTest {
    @get:Rule
    val compose = createComposeRule()

    /** Answers like the engine: 412 to an unknown caps hash, the page to the POST retry. */
    private class StubEngine(var failWith: Int? = null) : HttpTransport {
        val requests = mutableListOf<HttpRequest>()
        private val page = requireNotNull(javaClass.getResource("/pages/counter-home.json")).readBytes()

        override suspend fun send(request: HttpRequest): HttpResponse {
            requests += request
            failWith?.let { return HttpResponse(it, body = """{"error":"boom"}""".toByteArray()) }
            return if (request.method == "GET") {
                HttpResponse(412, body = """{"error":"caps_vector_unknown"}""".toByteArray())
            } else {
                HttpResponse(200, mapOf("content-type" to "application/json"), page)
            }
        }
    }

    private fun client(engine: StubEngine) =
        OrcaClient(URI("http://engine.invalid"), appId = "counter", apiKey = "demo-key", transport = engine)

    @Test
    fun theCounterLoadsThroughTheHandshakeAndCounts() {
        val engine = StubEngine()
        compose.setContent { OrcaApp(client(engine)) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("Counter Example") > 0 }
        compose.onNodeWithText("Counter Example").assertIsDisplayed()
        compose.onNodeWithText("+").performClick()
        compose.onNodeWithText("1").assertIsDisplayed()

        assertEquals(listOf("GET", "POST"), engine.requests.map { it.method })
        val headers = engine.requests.first().headers
        assertEquals("Android", headers["x-orca-platform"])
        assertEquals("393", headers["x-orca-screen-width"])
        assertEquals("2.0", headers["x-orca-pixel-density"])
        assertTrue(engine.requests.first().url.toString().endsWith("/api/v1/app/counter/page/home"))
    }

    @Test
    fun aFailedLoadShowsTheErrorAndRetries() {
        val engine = StubEngine(failWith = 500)
        compose.setContent { OrcaApp(client(engine)) }

        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("Could not load this page") > 0 }
        compose.onNodeWithText("HTTP 500: {\"error\":\"boom\"}").assertIsDisplayed()

        engine.failWith = null
        compose.onNodeWithText("Try again").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTextCount("Counter Example") > 0 }
        compose.onNodeWithText("0").assertIsDisplayed()
    }
}

private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithTextCount(text: String): Int =
    onAllNodes(androidx.compose.ui.test.hasText(text)).fetchSemanticsNodes().size
