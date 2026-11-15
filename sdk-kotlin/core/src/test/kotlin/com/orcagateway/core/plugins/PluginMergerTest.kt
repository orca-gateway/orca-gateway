package com.orcagateway.core.plugins

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertSame

/**
 * C16.3: two plugins claiming the same widget or action name fail the way
 * Flutter's `mergePlugins` does (sdk/lib/src/plugins/plugin_merger.dart),
 * with its four messages verbatim and the first conflict reported.
 */
class PluginMergerTest {
    private val builtIns = setOf("Column", "Text")
    private val noop = OrcaActionHandler { _, _ -> }

    private fun handlers(vararg names: String): Map<String, OrcaActionHandler> = names.associateWith { noop }

    private fun conflict(
        plugins: List<PluginParts>,
        hostWidgets: Set<String> = emptySet(),
        customActions: Map<String, OrcaActionHandler> = emptyMap(),
    ): String? = assertFailsWith<IllegalArgumentException> {
        PluginMerger.merge(builtIns, hostWidgets, customActions, plugins)
    }.message

    // MARK: the four messages

    @Test
    fun c16_3_aWidgetOfTwoPluginsNamesTheFirstOwner() {
        val message = conflict(
            listOf(PluginParts("maps", widgetTypes = setOf("Map")), PluginParts("geo", widgetTypes = setOf("Map"))),
        )
        assertEquals("Widget type \"Map\" from plugin \"geo\" conflicts with plugin \"maps\".", message)
    }

    @Test
    fun c16_3_aPluginWidgetNamedLikeABuiltInConflictsWithARegisteredWidget() {
        val message = conflict(listOf(PluginParts("text", widgetTypes = setOf("Text"))))
        assertEquals("Widget type \"Text\" from plugin \"text\" conflicts with an already registered widget.", message)
    }

    @Test
    fun c16_3_aPluginWidgetNamedLikeAHostWidgetConflictsWithARegisteredWidget() {
        val message = conflict(listOf(PluginParts("badges", widgetTypes = setOf("Badge"))), hostWidgets = setOf("Badge"))
        assertEquals("Widget type \"Badge\" from plugin \"badges\" conflicts with an already registered widget.", message)
    }

    @Test
    fun c16_3_anActionOfTwoPluginsNamesTheFirstOwner() {
        val message = conflict(
            listOf(PluginParts("pay", actions = handlers("checkout")), PluginParts("shop", actions = handlers("checkout"))),
        )
        assertEquals("Action type \"checkout\" from plugin \"shop\" conflicts with plugin \"pay\".", message)
    }

    @Test
    fun c16_3_aPluginActionNamedLikeAStandaloneActionConflictsWithARegisteredAction() {
        val message = conflict(listOf(PluginParts("haptics", actions = handlers("vibrate"))), customActions = handlers("vibrate"))
        assertEquals("Action type \"vibrate\" from plugin \"haptics\" conflicts with an already registered action.", message)
    }

    // MARK: the first conflict

    /** Within a plugin the keys are visited sorted ("Map" before "Text"), widgets before actions. */
    @Test
    fun c16_3_theFirstConflictIsTheFirstSortedWidgetOfThePlugin() {
        val message = conflict(
            listOf(
                PluginParts("maps", widgetTypes = setOf("Map"), actions = handlers("pay")),
                PluginParts("geo", widgetTypes = linkedSetOf("Text", "Map"), actions = handlers("pay")),
            ),
        )
        assertEquals("Widget type \"Map\" from plugin \"geo\" conflicts with plugin \"maps\".", message)
    }

    /** Sorted actions ("pay" before "zap"); a later plugin's conflict is never reached. */
    @Test
    fun c16_3_theFirstConflictFollowsPluginOrderThenSortedActions() {
        val message = conflict(
            listOf(
                PluginParts("pay", actions = handlers("pay")),
                PluginParts("shop", actions = linkedMapOf("zap" to noop, "pay" to noop)),
                PluginParts("text", widgetTypes = setOf("Text")),
            ),
            customActions = handlers("zap"),
        )
        assertEquals("Action type \"pay\" from plugin \"shop\" conflicts with plugin \"pay\".", message)
    }

    // MARK: a successful merge

    @Test
    fun c16_3_aPluginActionNamedLikeABuiltInActionMerges() {
        val navigate = OrcaActionHandler { _, _ -> }
        val result = PluginMerger.merge(builtIns, plugins = listOf(PluginParts("router", actions = mapOf("navigate" to navigate))))
        assertSame(navigate, result.actions["navigate"])
        assertEquals(setOf("navigate"), result.pluginActionTypes)
    }

    @Test
    fun c16_3_triggersConcatenatePerWidgetTypeAcrossPlugins() {
        val tap = TriggerDefinition("onTap", dataType = "LatLng", description = "A tap on the map")
        val pin = TriggerDefinition("onMarkerTap")
        val press = TriggerDefinition("onLongPress")
        val result = PluginMerger.merge(
            builtIns,
            plugins = listOf(
                PluginParts("maps", widgetTypes = setOf("Map"), triggers = mapOf("Map" to listOf(tap, pin))),
                PluginParts("extra", triggers = mapOf("Map" to listOf(press), "Text" to listOf(tap))),
            ),
        )
        assertEquals(mapOf("Map" to listOf(tap, pin, press), "Text" to listOf(tap)), result.triggers)
    }

    @Test
    fun c16_3_theResultKeepsStandaloneActionsAndNamesOnlyPluginTypes() {
        val rate = OrcaActionHandler { _, _ -> }
        val pay = OrcaActionHandler { _, _ -> }
        val result = PluginMerger.merge(
            builtIns,
            hostWidgets = setOf("Badge"),
            customActions = mapOf("rateApp" to rate),
            plugins = listOf(
                PluginParts("maps", widgetTypes = setOf("Map", "MapMarker")),
                PluginParts("pay", widgetTypes = setOf("PayButton"), actions = mapOf("processPayment" to pay)),
            ),
        )
        assertEquals(setOf("rateApp", "processPayment"), result.actions.keys)
        assertSame(rate, result.actions["rateApp"])
        assertSame(pay, result.actions["processPayment"])
        assertEquals(setOf("Map", "MapMarker", "PayButton"), result.widgetTypes)
        assertEquals(setOf("Map", "MapMarker", "PayButton"), result.pluginWidgetTypes)
        assertEquals(setOf("processPayment"), result.pluginActionTypes)
        assertEquals(mapOf("Map" to "maps", "MapMarker" to "maps", "PayButton" to "pay"), result.widgetOwners)
    }
}
