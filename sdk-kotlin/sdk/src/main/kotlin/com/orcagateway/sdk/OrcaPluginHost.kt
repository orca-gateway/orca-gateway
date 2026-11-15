package com.orcagateway.sdk

import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.PluginMerger
import com.orcagateway.core.render.WidgetRegistry

/**
 * What OrcaApp's plugins, custom actions and host widgets give every page
 * it loads: Dart's `mergePlugins` result as `_OrcaAppState._initialize` and
 * `_initRouter` use it (sdk/lib/src/widgets/orca_app.dart). Made once per
 * OrcaApp, before its first request, by [merge].
 */
internal class OrcaPluginHost private constructor(
    /** The core registry of the app's pages: built-in, host and plugin widget types. */
    val registry: WidgetRegistry,
    /** The Compose builders of the app's pages: the built-ins, the host's, then the plugins'. */
    val builders: WidgetBuilders,
    /** The standalone custom actions, then the plugins' actions, by type. */
    val actions: Map<String, OrcaActionHandler>,
) {
    /** Give a page just built this app's builders, and its executor the merged handlers. */
    fun install(model: OrcaPageModel) {
        model.builders = builders
        for ((type, handler) in actions) model.executor.registerHandler(type, handler)
    }

    companion object {
        /**
         * Merges [plugins] over the SDK's widgets, the extra types of
         * [widgets] and [customActions] (`PluginMerger`), then advertises
         * the plugins' widget and action names on [client] (Flutter does
         * not advertise standalone custom actions or host widgets). A
         * conflict throws `PluginMerger`'s [IllegalArgumentException] before
         * anything is registered. The builders are a new instance: neither
         * [widgets] nor `WidgetBuilders.shared` is changed.
         */
        fun merge(
            client: OrcaClient,
            plugins: List<OrcaPlugin>,
            customActions: Map<String, OrcaActionHandler>,
            widgets: WidgetBuilders,
        ): OrcaPluginHost {
            val builtIns = WidgetBuilders.shared.types
            val hostWidgets = widgets.types - builtIns
            val merged = PluginMerger.merge(builtIns, hostWidgets, customActions, plugins.map { it.toParts() })
            client.registerCapabilityExtensions(merged.pluginWidgetTypes, merged.pluginActionTypes)
            val builders = WidgetBuilders.standard()
            for (type in widgets.types) widgets[type]?.let { builders.register(type, it) }
            for (plugin in plugins) for ((type, builder) in plugin.widgets) builders.register(type, builder)
            val registry = WidgetRegistry(types = builtIns + hostWidgets + merged.pluginWidgetTypes)
            return OrcaPluginHost(registry, builders, merged.actions)
        }
    }
}
