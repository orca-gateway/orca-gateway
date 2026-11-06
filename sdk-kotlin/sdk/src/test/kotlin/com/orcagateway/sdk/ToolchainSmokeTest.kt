package com.orcagateway.sdk

import androidx.compose.material3.Text
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.assertIsDisplayed
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class ToolchainSmokeTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun composeDrawsUnderRobolectric() {
        compose.setContent { Text(OrcaSdk.MODULE) }
        compose.onNodeWithText("OrcaGateway").assertIsDisplayed()
    }
}
