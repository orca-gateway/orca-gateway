package com.orcagateway.sdk

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.PluginMerger
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ElmStore
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonObject
import orca.plugins.GoogleMapProps
import orca.plugins.MoveCameraParams
import orca.plugins.OrcaGoogleMapPlugin
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * C16.6 on Android: the stub `orca plugin generate --lang kotlin` writes for
 * plugins/orca_google_map/orca_plugin.yaml (committed unchanged as
 * orca/plugins/OrcaGoogleMapPlugin.kt, kept in sync by
 * cli/test/kotlin_generator_test.dart) compiles under the build's rules,
 * merges through `toParts()`, draws its placeholder through `NodeView`, and
 * its action handler runs on an executor with no effect.
 */
@RunWith(RobolectricTestRunner::class)
class GeneratedPluginTest {
    @get:Rule
    val compose = createComposeRule()

    private val triggers = listOf("onTap", "onLongPress", "onCameraMove", "onMarkerTap")

    @Test
    fun c16_6_theGeneratedPluginMergesWithItsNameWidgetActionAndTriggers() {
        val parts = OrcaGoogleMapPlugin().toParts()
        assertEquals("orca_google_map", parts.name)
        assertEquals(setOf("GoogleMap"), parts.widgetTypes)
        assertEquals(setOf("moveCamera"), parts.actions.keys)
        assertEquals(mapOf("GoogleMap" to triggers.map { TriggerDefinition(it) }), parts.triggers)

        val merged = PluginMerger.merge(builtInWidgets = WidgetBuilders.standard().types, plugins = listOf(parts))
        assertEquals(setOf("GoogleMap"), merged.pluginWidgetTypes)
        assertEquals(setOf("moveCamera"), merged.pluginActionTypes)
        assertEquals(parts.triggers, merged.triggers)
    }

    @Test
    fun c16_6_nodeViewDrawsTheGeneratedPlaceholderAndItsPropsReadTheNode() {
        val map = ComponentNode(
            "1", "GoogleMap", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
            props = mapOf("latitude" to JsonValue.Double(30.0), "mapType" to JsonValue.String("hybrid")),
        )
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "GoogleMap")
        val model = OrcaPageModel(page(column("0", "1"), map), registry = registry)
        model.builders = WidgetBuilders.standard().apply {
            for ((type, builder) in OrcaGoogleMapPlugin().widgets) register(type, builder)
        }

        val node = assertNotNull(model.resolve("1"))
        val props = GoogleMapProps(node)
        assertEquals(30.0, props.latitude)
        assertEquals("hybrid", props.mapType)
        assertEquals(null, props.zoom)

        compose.setContent { NodeView("1", model) }
        compose.onNodeWithText("GoogleMap").assertIsDisplayed()
        assertTrue(model.builders.reportedMissing.isEmpty())
    }

    @Test
    fun c16_6_theGeneratedActionHandlerRunsWithNoEffect() = runBlocking {
        val generated = assertNotNull(OrcaGoogleMapPlugin().actions["moveCamera"])
        val ran = ArrayList<JsonObject>()
        val store = ElmStore(page = mapOf("count" to JsonValue.Double(1.0)))
        val before = store.state
        val executor = ActionExecutor(store)
        val effects = ArrayList<ActionEffect>()
        var mutations = 0
        executor.onEffect = { effects.add(it) }
        executor.onMutation = { mutations += 1 }
        executor.registerHandler(
            "moveCamera",
            OrcaActionHandler { action, e ->
                generated.handle(action, e)
                ran.add(action)
            },
        )

        val raw = JsonValue.obj("type" to "custom:moveCamera", "targetId" to "map", "latitude" to 1.5, "zoom" to null)
        executor.execute(Action.Custom(raw))

        assertEquals(listOf(raw.toJsonElement() as JsonObject), ran, "the generated handler ran and returned")
        assertEquals(emptyList(), effects)
        assertEquals(0, mutations)
        assertEquals(before, store.state)
        val params = MoveCameraParams(raw.toJsonElement() as JsonObject)
        assertEquals("map", params.targetId)
        assertEquals(1.5, params.latitude)
        assertEquals(null, params.zoom)
    }
}
