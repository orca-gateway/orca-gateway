package com.orcagateway.sdk

import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.PluginParts
import com.orcagateway.core.plugins.TriggerDefinition

/**
 * Custom widgets, custom actions and trigger declarations that belong
 * together (Dart `OrcaPlugin`, sdk/lib/src/plugins/orca_plugin.dart), so
 * both halves are registered at once. A plugin's widget and action names
 * are advertised in the client's capabilities; two plugins, or a plugin and
 * the SDK, the host or the standalone custom actions, claiming the same
 * name is a conflict (see `PluginMerger`).
 *
 * A widget builder draws its children with the public [NodeView] (one per
 * child id in `node.childIds` or `node.slots`) and fires one of its
 * [triggers] with `model.fire(trigger, on = node, eventData = ...)`, as
 * Flutter's `ctx.fireAction(name, eventData:)`: the node's action of that
 * name runs, and reads the event data through `V.event`.
 */
public interface OrcaPlugin {
    /** Names the plugin in conflict messages and debugging. */
    public val name: String

    /** The plugin's widget builders by wire type (`"MapView"`, ...). */
    public val widgets: Map<String, WidgetBuilder> get() = emptyMap()

    /**
     * The plugin's action handlers by action type. A node's action reaches
     * one as `{"type":"<name>"}` or `{"type":"custom:<name>"}`. A name
     * like a built-in action's replaces the built-in.
     */
    public val actions: Map<String, OrcaActionHandler> get() = emptyMap()

    /** The triggers each widget type fires, for tooling; nothing reads them at runtime. */
    public val triggers: Map<String, List<TriggerDefinition>> get() = emptyMap()
}

/** What `PluginMerger` merges: this plugin with its builders reduced to their type names. */
public fun OrcaPlugin.toParts(): PluginParts =
    PluginParts(name = name, widgetTypes = widgets.keys.toSet(), actions = actions, triggers = triggers)
