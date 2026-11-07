package com.orcagateway.sdk

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals

/** The basic FallbackPrompt card: its call to action goes to the host as an `openUrl` effect. */
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
}
