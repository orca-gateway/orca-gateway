package com.orcagateway.sdk

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.UriHandler
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.system.SystemActions
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.net.URI
import kotlin.test.assertEquals

/**
 * The basic FallbackPrompt card: its call to action goes to the host as an
 * `openUrl` effect, through the URL policy. Mirrors Swift's
 * `FallbackPromptTests`: without a router the link opens through the
 * platform's `UriHandler`, under one the router's system actions open it.
 */
@RunWith(RobolectricTestRunner::class)
class FallbackPromptTest {
    @get:Rule
    val compose = createComposeRule()

    private fun prompt(url: String) = page(
        leaf(
            "0", "FallbackPrompt",
            mapOf(
                "title" to JsonValue.String("Update needed"),
                "body" to JsonValue.String("Get the latest version."),
                "severity" to JsonValue.String("blocking"),
                "ctaLabel" to JsonValue.String("Update"),
                "ctaUrl" to JsonValue.String(url),
            ),
        ),
    )

    @Test
    fun theCallToActionIsAnOpenUrlEffect() {
        val model = OrcaPageModel(prompt("https://example.com/app"))
        val handled = ArrayList<ActionEffect>()
        model.effectHandler = { handled.add(it) }
        compose.setContent { OrcaPageView(model) }

        compose.onNodeWithText("Update needed").assertIsDisplayed()
        compose.onNodeWithText("Get the latest version.").assertIsDisplayed()
        compose.onNodeWithText("Update").performClick()
        assertEquals(listOf(ActionEffect("openUrl", mapOf("url" to JsonValue.String("https://example.com/app")))), handled)
    }

    @Test
    fun aUrlThePolicyRefusesDoesNothing() {
        val model = OrcaPageModel(prompt("javascript:alert(1)"))
        val handled = ArrayList<ActionEffect>()
        model.effectHandler = { handled.add(it) }
        compose.setContent { OrcaPageView(model) }

        compose.onNodeWithText("Update").performClick()
        assertEquals(emptyList(), handled)
    }

    /** Swift `testWithoutARouterTheLinkOpensDirectly`: no host for effects, so the platform URI handler opens it. */
    @Test
    fun withoutARouterTheLinkOpensDirectly() {
        val model = OrcaPageModel(prompt("mailto:help@example.com"))
        val opened = ArrayList<String>()
        compose.setContent {
            CompositionLocalProvider(LocalUriHandler provides recordingUriHandler(opened)) { OrcaPageView(model) }
        }

        compose.onNodeWithText("Update").performClick()
        assertEquals(listOf("mailto:help@example.com"), opened)
    }

    /** Swift `testUnderTheRouterTheSystemOpensIt`: the router's system actions open it, the URI handler is not used. */
    @Test
    fun underTheRouterTheSystemOpensIt() {
        val systemOpened = ArrayList<URI>()
        val system = SystemActions(open = { systemOpened.add(it) }, copy = {}, share = { _, _ -> })
        val router = OrcaRouter(OrcaClient(URI("http://stub.invalid"), appId = "a", transport = NoRequests), system = system)
        val model = OrcaPageModel(prompt("https://example.com/whats-new"))
        router.attach(model)
        val uriOpened = ArrayList<String>()
        compose.setContent {
            CompositionLocalProvider(LocalUriHandler provides recordingUriHandler(uriOpened)) { OrcaPageView(model) }
        }

        compose.onNodeWithText("Update").performClick()
        assertEquals(listOf(URI("https://example.com/whats-new")), systemOpened)
        assertEquals(emptyList(), uriOpened, "the router opens it")
    }

    private fun recordingUriHandler(opened: MutableList<String>) = object : UriHandler {
        override fun openUri(uri: String) {
            opened.add(uri)
        }
    }

    /** The router's client: these tests never fetch a page. */
    private object NoRequests : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse = error("no request expected: ${request.url}")
    }
}
