package com.orcagateway.core.plugins

import com.orcagateway.core.state.ActionExecutor
import kotlinx.serialization.json.JsonObject

/**
 * An event a plugin widget can fire, declared for tooling (Dart
 * `TriggerDefinition`, sdk/lib/src/plugins/orca_plugin.dart). Nothing reads
 * it at runtime: a builder fires a trigger by running the node's action of
 * that name.
 */
public data class TriggerDefinition(
    public val name: String,
    /** The type of the event data the trigger carries, when it carries any. */
    public val dataType: String? = null,
    public val description: String? = null,
)

/**
 * Runs a custom or plugin action (Dart `ActionHandler`,
 * sdk/lib/src/state/action_executor.dart). It gets the raw action object as
 * sent (`type` and its params as sibling keys, values unresolved) and the
 * executor running it.
 */
public fun interface OrcaActionHandler {
    public suspend fun handle(action: JsonObject, executor: ActionExecutor)
}

/**
 * What [PluginMerger] needs of one plugin: the members of Dart's
 * `OrcaPlugin` (sdk/lib/src/plugins/orca_plugin.dart) with the widget
 * builders reduced to their type names, so the core can merge without the
 * UI layer.
 */
public class PluginParts(
    public val name: String,
    public val widgetTypes: Set<String> = emptySet(),
    public val actions: Map<String, OrcaActionHandler> = emptyMap(),
    public val triggers: Map<String, List<TriggerDefinition>> = emptyMap(),
)

/** What [PluginMerger.merge] built (Dart `PluginMergeResult`). */
public class PluginMergeResult(
    /** The plugins' widget types (built-in and host widgets are not in it). */
    public val widgetTypes: Set<String>,
    /** The standalone custom actions, then every plugin's actions. */
    public val actions: Map<String, OrcaActionHandler>,
    /** Every plugin's triggers, concatenated per widget type in plugin order. */
    public val triggers: Map<String, List<TriggerDefinition>>,
    /** The plugin that registered each plugin widget type. */
    public val widgetOwners: Map<String, String>,
    /** The plugins' widget type names, the ones a client advertises. */
    public val pluginWidgetTypes: Set<String>,
    /** The plugins' action names (no standalone ones), the ones a client advertises. */
    public val pluginActionTypes: Set<String>,
)

/**
 * Dart `mergePlugins` (sdk/lib/src/plugins/plugin_merger.dart): the
 * standalone custom actions first, then each plugin in list order, its
 * widgets, then its actions, then its triggers.
 */
public object PluginMerger {
    /**
     * Merges [plugins] over the [builtInWidgets], the [hostWidgets] and the
     * standalone [customActions]. Throws [IllegalArgumentException] (Dart's
     * `ArgumentError`) with Dart's message on the first conflict: a widget
     * type another plugin or the SDK and host already register, or an action
     * type another plugin or the standalone actions already register.
     *
     * Within one plugin the keys are visited sorted, not in insertion order
     * as Dart does, so the Swift and Kotlin SDKs report the same first
     * conflict. A plugin action named like a built-in action (`navigate`,
     * `setState`, ...) is no conflict: it overrides the built-in. Triggers
     * are not checked.
     */
    public fun merge(
        builtInWidgets: Set<String>,
        hostWidgets: Set<String> = emptySet(),
        customActions: Map<String, OrcaActionHandler> = emptyMap(),
        plugins: List<PluginParts>,
    ): PluginMergeResult {
        val actions = LinkedHashMap<String, OrcaActionHandler>()
        for (key in customActions.keys.sorted()) actions[key] = customActions.getValue(key)
        val triggers = LinkedHashMap<String, List<TriggerDefinition>>()
        val widgetOwners = LinkedHashMap<String, String>()
        val actionOwners = LinkedHashMap<String, String>()

        for (plugin in plugins) {
            for (type in plugin.widgetTypes.sorted()) {
                widgetOwners[type]?.let { owner ->
                    throw IllegalArgumentException(
                        "Widget type \"$type\" from plugin \"${plugin.name}\" conflicts with plugin \"$owner\".",
                    )
                }
                if (type in builtInWidgets || type in hostWidgets) {
                    throw IllegalArgumentException(
                        "Widget type \"$type\" from plugin \"${plugin.name}\" conflicts with an already registered widget.",
                    )
                }
                widgetOwners[type] = plugin.name
            }
            for (type in plugin.actions.keys.sorted()) {
                actionOwners[type]?.let { owner ->
                    throw IllegalArgumentException(
                        "Action type \"$type\" from plugin \"${plugin.name}\" conflicts with plugin \"$owner\".",
                    )
                }
                if (type in actions) {
                    throw IllegalArgumentException(
                        "Action type \"$type\" from plugin \"${plugin.name}\" conflicts with an already registered action.",
                    )
                }
                actions[type] = plugin.actions.getValue(type)
                actionOwners[type] = plugin.name
            }
            for (type in plugin.triggers.keys.sorted()) {
                triggers[type] = triggers[type].orEmpty() + plugin.triggers.getValue(type)
            }
        }

        val pluginWidgets = LinkedHashSet(widgetOwners.keys)
        return PluginMergeResult(
            widgetTypes = pluginWidgets,
            actions = actions,
            triggers = triggers,
            widgetOwners = widgetOwners,
            pluginWidgetTypes = pluginWidgets,
            pluginActionTypes = LinkedHashSet(actionOwners.keys),
        )
    }
}
