#if canImport(SwiftUI)
import SwiftUI

/// What OrcaApp makes of its `plugins`, `customActions` and `widgets`, the
/// plugin part of `_OrcaAppState` in sdk/lib/src/widgets/orca_app.dart.
/// `PluginMerger.merge` runs once, the first time anything here is read.
/// On success the router's client advertises the plugins' widget and action
/// names (not the standalone actions or the host widgets, as in Flutter),
/// and every page the app loads gets the per-app registry and builders and
/// the merged handlers. On a conflict `failure` holds Flutter's message:
/// OrcaApp shows it and fetches nothing. Internal: only OrcaApp drives it.
@MainActor
final class OrcaPluginHost {
    private struct Merged {
        var failure: String?
        /// The SDK's own types, the host's and the plugins'.
        var registry = WidgetRegistry.shared
        /// The host's builders, then the plugins'.
        var builders = WidgetBuilders()
        /// The standalone custom actions and the plugins' actions.
        var handlers: [String: OrcaActionHandler] = [:]
        var pluginWidgets: [String] = []
        var pluginActions: [String] = []
    }

    private let plugins: [OrcaPlugin]
    private let customActions: [String: OrcaActionHandler]
    private let widgets: WidgetBuilders
    private lazy var merged = merge()

    init(plugins: [OrcaPlugin], customActions: [String: OrcaActionHandler], widgets: WidgetBuilders) {
        self.plugins = plugins
        self.customActions = customActions
        self.widgets = widgets
    }

    /// The conflict message when the merge failed, else nil.
    var failure: String? { merged.failure }

    /// Advertise the plugins' names on `client` (shared by its copies).
    func advertise(on client: OrcaClient) {
        client.registerCapabilityExtensions(widgets: merged.pluginWidgets, actions: merged.pluginActions)
    }

    /// Advertise the plugins' names on `router`'s client (shared by its
    /// copies) and give the router this host for its pages.
    func attach(_ router: OrcaRouter) -> OrcaRouter {
        advertise(on: router.client)
        router.plugins = self
        return router
    }

    /// A page model with the app's registry, builders and handlers.
    func page(_ page: PageResponse, store: ElmStore, client: OrcaClient) -> OrcaPageModel {
        let model = OrcaPageModel(
            page: page, store: store, registry: merged.registry, client: client, widgets: merged.builders)
        for (type, handler) in merged.handlers {
            model.executor.registerHandler(type, handler)
        }
        return model
    }

    private func merge() -> Merged {
        let builtIns = WidgetRegistry.shared.types
        let result: PluginMergeResult
        do {
            result = try PluginMerger.merge(
                builtInWidgets: builtIns, hostWidgets: widgets.types,
                customActions: customActions, plugins: plugins.map(\.parts))
        } catch {
            return Merged(failure: "\(error)")
        }
        let builders = WidgetBuilders()
        for type in widgets.types {
            if let builder = widgets.builder(for: type) { builders.register(type, builder) }
        }
        for plugin in plugins {
            for (type, builder) in plugin.widgets { builders.register(type, builder) }
        }
        return Merged(
            registry: builders.types.isEmpty ? .shared : WidgetRegistry(types: builtIns.union(builders.types)),
            builders: builders, handlers: result.actions,
            pluginWidgets: result.pluginWidgetTypes.sorted(), pluginActions: result.pluginActionTypes.sorted())
    }
}
#endif
