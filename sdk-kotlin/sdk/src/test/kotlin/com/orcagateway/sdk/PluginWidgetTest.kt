package com.orcagateway.sdk

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.text.BasicText
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.PluginMerger
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

private const val BADGE_TAG = "coloredBadge"

/** Draws the badge's label; a tap fires the node's `onTap` with the label as event data. */
private val coloredBadge: WidgetBuilder = { node, model, modifier ->
    val label = node["label"]?.stringValue ?: ""
    Box(
        modifier
            .testTag(BADGE_TAG)
            .clickable { model.fire("onTap", on = node, eventData = mapOf("label" to JsonValue.String(label))) },
    ) {
        BasicText(label)
    }
}

/** Flutter's example `_BadgePlugin` (examples/app/lib/main.dart), reduced to what C16.4 needs. */
private class BadgePlugin : OrcaPlugin {
    override val name: String = "badge"
    override val widgets: Map<String, WidgetBuilder> = mapOf("ColoredBadge" to coloredBadge)
    override val actions: Map<String, OrcaActionHandler> = mapOf("hapticFeedback" to OrcaActionHandler { _, _ -> })
    override val triggers: Map<String, List<TriggerDefinition>> =
        mapOf("ColoredBadge" to listOf(TriggerDefinition("onTap", dataType = "String")))
}

/**
 * C16.4: a plugin's widget is drawn by `NodeView` and fires its declared
 * trigger through `model.fire` (Flutter's `ctx.fireAction`), which runs the
 * node's action with the event data; the plugin's names and triggers reach
 * the merger through `toParts()`.
 */
@RunWith(RobolectricTestRunner::class)
class PluginWidgetTest {
    @get:Rule
    val compose = createComposeRule()

    /** A page whose node "1" is a ColoredBadge whose `onTap` sets `picked` to `V.event("label")`. */
    private fun badgeModel(): OrcaPageModel {
        val badge = ComponentNode(
            "1", "ColoredBadge", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
            props = mapOf("label" to JsonValue.String("gold")),
            actions = mapOf(
                "onTap" to Action.SetState(key = "picked", value = JsonValue.obj("type" to "event", "key" to "label")),
            ),
        )
        // The core degrades a type it does not know to FallbackPrompt: told
        // about the plugin's type, it lets the node through to Compose.
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "ColoredBadge")
        return OrcaPageModel(
            page(column("0", "1"), badge, state = listOf(StateDefinition("picked", StateScope.Page, JsonValue.Null))),
            registry = registry,
        )
    }

    @Test
    fun c16_4_toPartsCarriesTheWidgetNamesActionsAndTriggers() {
        val parts = BadgePlugin().toParts()
        assertEquals("badge", parts.name)
        assertEquals(setOf("ColoredBadge"), parts.widgetTypes)
        assertEquals(setOf("hapticFeedback"), parts.actions.keys)
        assertEquals(mapOf("ColoredBadge" to listOf(TriggerDefinition("onTap", dataType = "String"))), parts.triggers)

        // The declared triggers reach the merged result.
        val merged = PluginMerger.merge(builtInWidgets = WidgetBuilders.standard().types, plugins = listOf(parts))
        assertEquals(parts.triggers, merged.triggers)
        assertEquals(setOf("ColoredBadge"), merged.pluginWidgetTypes)

        // A plugin with only a name: no widgets, actions or triggers.
        val bare = object : OrcaPlugin {
            override val name: String = "bare"
        }.toParts()
        assertEquals("bare", bare.name)
        assertTrue(bare.widgetTypes.isEmpty() && bare.actions.isEmpty() && bare.triggers.isEmpty())
    }

    @Test
    fun c16_4_aTriggerFiredThroughModelFireRunsTheNodeActionWithEventData() = runBlocking {
        val model = badgeModel()
        val node = assertNotNull(model.resolve("1"))
        assertEquals("ColoredBadge", node.type, "the plugin node is not degraded")

        model.fire("onTap", on = node, eventData = mapOf("label" to JsonValue.String("silver")))?.join()
        assertEquals(JsonValue.String("silver"), model.store.value("picked"))
    }

    @Test
    fun c16_4_nodeViewDrawsThePluginBuilderAndItsTapFiresTheTrigger() {
        val model = badgeModel()
        model.builders = WidgetBuilders.standard().apply {
            for ((type, builder) in BadgePlugin().widgets) register(type, builder)
        }
        compose.setContent { NodeView("1", model) }

        compose.onNodeWithTag(BADGE_TAG).assertIsDisplayed().performClick()
        compose.waitForIdle()
        assertEquals(JsonValue.String("gold"), model.store.value("picked"))
        assertTrue(model.builders.reportedMissing.isEmpty())
    }

    @Test
    fun c16_4_nodeViewDrawsNothingForAnUnregisteredType() {
        val model = badgeModel()
        model.builders = WidgetBuilders.standard()
        compose.setContent { NodeView("1", model, Modifier) }

        compose.onNodeWithTag(BADGE_TAG).assertDoesNotExist()
        assertEquals(setOf("ColoredBadge"), model.builders.reportedMissing)
    }

    @Test
    fun c16_4_aRegistrationGrowsAStandardInstanceButNotShared() {
        val shared = WidgetBuilders.shared.types
        val builders = WidgetBuilders.standard()
        builders.register("ColoredBadge", coloredBadge)

        assertEquals(WidgetBuilders.standard().types + "ColoredBadge", builders.types)
        assertEquals(shared, WidgetBuilders.shared.types)
        assertFalse("ColoredBadge" in WidgetBuilders.shared.types)
        assertNotNull(builders["ColoredBadge"])
    }
}
