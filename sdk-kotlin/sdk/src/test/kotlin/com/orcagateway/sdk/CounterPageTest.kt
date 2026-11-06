package com.orcagateway.sdk

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.recordedPage
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowToast
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** T6.3.3: the counter page end to end through Compose, and the toast and long press. */
@RunWith(RobolectricTestRunner::class)
class CounterPageTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun theCounterCountsAndResetShowsTheSnackbar() {
        val model = OrcaPageModel(recordedPage("counter-home"))
        compose.setContent { OrcaPageView(model) }

        compose.onNodeWithText("Counter Example").assertIsDisplayed()
        compose.onNodeWithText("0").assertIsDisplayed()
        compose.onNodeWithText("+").performClick()
        compose.onNodeWithText("+").performClick()
        compose.onNodeWithText("2").assertIsDisplayed()

        compose.mainClock.autoAdvance = false
        compose.onNodeWithText("Reset").performClick()
        compose.mainClock.advanceTimeBy(500)
        compose.onNodeWithText("0").assertIsDisplayed()
        compose.onNodeWithText("Counter reset to 0").assertIsDisplayed()

        // The Dart default duration, 4000 ms, then the snackbar leaves.
        compose.mainClock.advanceTimeBy(4000)
        compose.waitForIdle()
        compose.onNodeWithText("Counter reset to 0").assertDoesNotExist()
        assertNull(model.toast)
    }

    @Test
    fun aToastIsAnAndroidToast() {
        val model = OrcaPageModel(
            page(
                column("0", "1"),
                button("1", "TextButton", "2", mapOf("onTap" to Action.ShowToast(message = JsonValue.String("Saved")))),
                text("2", "Save"),
            ),
        )
        compose.setContent { OrcaPageView(model) }
        compose.onNodeWithText("Save").performClick()
        compose.waitForIdle()
        assertEquals("Saved", ShadowToast.getTextOfLatestToast())
    }

    @Test
    fun aSnackbarShowsOnAPageWithoutAScaffold() {
        val model = OrcaPageModel(
            page(
                column("0", "1"),
                button("1", "ElevatedButton", "2", mapOf("onTap" to Action.ShowSnackbar(message = JsonValue.String("Hello")))),
                text("2", "Greet"),
            ),
        )
        compose.setContent { OrcaPageView(model) }
        compose.mainClock.autoAdvance = false
        compose.onNodeWithText("Greet").performClick()
        compose.mainClock.advanceTimeBy(500)
        compose.onNodeWithText("Hello").assertIsDisplayed()
    }

    @Test
    fun aLongPressFiresOnLongPressInsteadOfOnTap() {
        fun set(key: String) = Action.SetState(key = key, value = JsonValue.Bool(true))
        val model = OrcaPageModel(
            page(
                column("0", "1"),
                button("1", "OutlinedButton", "2", mapOf("onTap" to set("tapped"), "onLongPress" to set("held"))),
                text("2", "Hold"),
                state = listOf(
                    StateDefinition("tapped", StateScope.Page, JsonValue.Bool(false)),
                    StateDefinition("held", StateScope.Page, JsonValue.Bool(false)),
                ),
            ),
        )
        compose.setContent { OrcaPageView(model) }

        compose.onNodeWithText("Hold").performTouchInput { longClick() }
        compose.waitForIdle()
        assertEquals(JsonValue.Bool(true), model.store.value("held"))
        assertEquals(JsonValue.Bool(false), model.store.value("tapped"))

        compose.onNodeWithText("Hold").performClick()
        compose.waitForIdle()
        assertEquals(JsonValue.Bool(true), model.store.value("tapped"))
    }
}
