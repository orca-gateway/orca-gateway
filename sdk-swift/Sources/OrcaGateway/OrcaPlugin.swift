#if canImport(SwiftUI)
import SwiftUI

/// Draws a node of a type the SDK's own views do not draw (a plugin or host
/// widget), the Swift `ComponentBuilder` (sdk/lib/src/rendering/component_registry.dart).
///
/// It gets the resolved node and the page model. It draws a child with the
/// public `NodeView(id: node.childIds[i], model: model)` (or a slot's id from
/// `node.slots`), and fires one of its triggers with
/// `model.fire("onTap", on: node, eventData: [...])`, which runs the node's
/// action for that trigger with the event data, as Flutter's
/// `ctx.fireAction` (sdk/lib/src/rendering/component_context.dart).
public typealias OrcaWidgetBuilder = @MainActor (_ node: ResolvedNode, _ model: OrcaPageModel) -> AnyView

/// A plugin bundles widgets, custom actions and trigger declarations that go
/// together, so a host registers them in one place. A port of Dart
/// `OrcaPlugin` (sdk/lib/src/plugins/orca_plugin.dart), without its web-only
/// members (`widgetMetadata`, `webStubs`).
///
/// `name` appears in conflict messages. Widget and action keys are wire type
/// names (`MapView`, `centerMap`); an action is reached by its name and by
/// `custom:<name>`. Triggers are metadata: nothing reads them at run time.
public protocol OrcaPlugin {
    /// Human-readable name used in error messages and debugging.
    var name: String { get }
    /// Widget builders by component type.
    var widgets: [String: OrcaWidgetBuilder] { get }
    /// Action handlers by action type.
    var actions: [String: OrcaActionHandler] { get }
    /// The triggers each widget type can fire.
    var triggers: [String: [TriggerDefinition]] { get }
}

extension OrcaPlugin {
    public var widgets: [String: OrcaWidgetBuilder] { [:] }
    public var actions: [String: OrcaActionHandler] { [:] }
    public var triggers: [String: [TriggerDefinition]] { [:] }

    /// What `PluginMerger.merge` needs: the name, the widget type names, the
    /// actions and the triggers.
    public var parts: PluginParts {
        PluginParts(name: name, widgetTypes: Set(widgets.keys), actions: actions, triggers: triggers)
    }
}

/// Builders for the widget types the SDK's own views do not draw: plugin and
/// host-registered widgets, the extra entries of Dart's `ComponentRegistry`
/// (sdk/lib/src/rendering/component_registry.dart). A page model carries one;
/// a node whose type has no builder here and no SDK view draws nothing.
///
/// The renderer's `WidgetRegistry` must list these types too, or it degrades
/// their nodes to a FallbackPrompt before they are drawn.
@MainActor
public final class WidgetBuilders {
    private var builders: [String: OrcaWidgetBuilder] = [:]

    /// Empty. Nonisolated, so it can be a default argument.
    nonisolated public init() {}

    /// Register the builder for `type`, replacing any registered before.
    public func register(_ type: String, _ builder: @escaping OrcaWidgetBuilder) {
        builders[type] = builder
    }

    /// The builder registered for `type`, or nil.
    public func builder(for type: String) -> OrcaWidgetBuilder? {
        builders[type]
    }

    /// The types with a builder.
    public var types: Set<String> { Set(builders.keys) }
}
#endif
