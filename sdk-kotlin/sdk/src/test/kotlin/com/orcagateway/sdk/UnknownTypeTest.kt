package com.orcagateway.sdk

import android.util.Log
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowLog
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** T6.3.5: a node no builder draws never throws, takes no space and is logged once per type. */
@RunWith(RobolectricTestRunner::class)
class UnknownTypeTest {
    @get:Rule
    val compose = createComposeRule()

    private val holoPage = page(
        column("0", "1", "2", "3", "4", "5"),
        text("1", "before"),
        leaf("2", "HoloDeck"),
        leaf("3", "HoloDeck"),
        leaf("4", "Warp"),
        text("5", "after"),
    )

    private fun warnings(): List<String> =
        ShadowLog.getLogsForTag(WidgetBuilders.LOG_TAG).filter { it.type == Log.WARN }.map { it.msg }

    /**
     * Types the core lets through (as it will a plugin's) but no Compose
     * builder draws: nothing between "before" and "after", one warning each.
     */
    @Test
    fun aTypeWithNoBuilderDrawsNothingAndWarnsOncePerType() {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("HoloDeck", "Warp"))
        val model = OrcaPageModel(holoPage, registry = registry).apply { builders = WidgetBuilders.standard() }
        compose.setContent { OrcaPageView(model) }

        val before = compose.onNodeWithText("before").getUnclippedBoundsInRoot()
        val after = compose.onNodeWithText("after").getUnclippedBoundsInRoot()
        assertEquals(before.bottom, after.top)
        assertEquals(setOf("HoloDeck", "Warp"), model.builders.reportedMissing)
        val logged = warnings()
        assertEquals(1, logged.count { "\"HoloDeck\"" in it }, "$logged")
        assertEquals(1, logged.count { "\"Warp\"" in it }, "$logged")
        assertEquals(2, logged.size, "$logged")
    }

    /** A core without FallbackPrompt degrades to `_Empty`: drawn as nothing, logged by its wire type. */
    @Test
    fun anEmptyNodeIsLoggedByItsWireType() {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types - "FallbackPrompt")
        val model = OrcaPageModel(holoPage, registry = registry).apply { builders = WidgetBuilders.standard() }
        compose.setContent { OrcaPageView(model) }

        val before = compose.onNodeWithText("before").getUnclippedBoundsInRoot()
        val after = compose.onNodeWithText("after").getUnclippedBoundsInRoot()
        assertEquals(before.bottom, after.top)
        assertEquals(setOf("HoloDeck", "Warp"), model.builders.reportedMissing)
        assertEquals(2, warnings().size)
    }

    /**
     * With the default core registry an unknown type never reaches Compose:
     * the core draws it as Flutter's warn FallbackPrompt (Swift's T2.5), so
     * nothing is missing here.
     */
    @Test
    fun byDefaultAnUnknownTypeIsTheFallbackPrompt() {
        val model = OrcaPageModel(holoPage, registry = WidgetRegistry()).apply { builders = WidgetBuilders.standard() }
        compose.setContent { OrcaPageView(model) }

        compose.onNodeWithText("before").assertIsDisplayed()
        compose.onNodeWithText("after").assertIsDisplayed()
        val prompts = compose.onAllNodesWithText("Unsupported content")
        assertEquals(3, prompts.fetchSemanticsNodes().size)
        assertTrue(model.builders.reportedMissing.isEmpty())
        assertTrue(warnings().isEmpty())
    }
}
