import Foundation

/// A trigger a plugin widget can fire, such as `onPan` or `onZoom`: declarative
/// metadata for devtools and documentation, read by nothing at run time. A port
/// of Dart `TriggerDefinition` (sdk/lib/src/plugins/orca_plugin.dart).
public struct TriggerDefinition: Equatable, Sendable {
    /// The trigger name, e.g. "onPan".
    public var name: String
    /// The type of the event data it fires with ("String", "double", ...), or
    /// nil when it fires without data.
    public var dataType: String?
    /// When the trigger fires.
    public var description: String?

    public init(name: String, dataType: String? = nil, description: String? = nil) {
        self.name = name
        self.dataType = dataType
        self.description = description
    }
}

/// A custom action handler: the raw action object as the server sent it (type
/// as sent, params as sibling keys, values unresolved) and the executor running
/// it. A port of Dart `ActionHandler` (sdk/lib/src/state/action_executor.dart).
public typealias OrcaActionHandler = @Sendable (_ action: JSONValue, _ executor: ActionExecutor) async throws -> Void

/// What a plugin contributes to a merge: its name, the widget types it draws,
/// its action handlers and its trigger declarations. The core half of Dart
/// `OrcaPlugin` (sdk/lib/src/plugins/orca_plugin.dart); the widget builders
/// stay in the UI layer, only their type names come here.
public struct PluginParts: Sendable {
    /// Used in conflict messages.
    public var name: String
    public var widgetTypes: Set<String>
    public var actions: [String: OrcaActionHandler]
    /// Trigger declarations per widget type.
    public var triggers: [String: [TriggerDefinition]]

    public init(
        name: String, widgetTypes: Set<String> = [], actions: [String: OrcaActionHandler] = [:],
        triggers: [String: [TriggerDefinition]] = [:]
    ) {
        self.name = name
        self.widgetTypes = widgetTypes
        self.actions = actions
        self.triggers = triggers
    }
}

/// What `PluginMerger.merge` produced (Dart `PluginMergeResult`).
public struct PluginMergeResult: Sendable {
    /// The standalone custom actions, then every plugin's actions.
    public let actions: [String: OrcaActionHandler]
    /// Each widget type's triggers, concatenated in plugin order.
    public let triggers: [String: [TriggerDefinition]]
    /// The plugin that registered each plugin widget type.
    public let widgetOwners: [String: String]
    /// The action types plugins registered, without the standalone ones: what
    /// the client advertises.
    public let pluginActionTypes: Set<String>

    /// The widget types plugins registered, without built-in or host widgets:
    /// what the client advertises.
    public var pluginWidgetTypes: Set<String> { Set(widgetOwners.keys) }
    /// The plugin widget types (the same set as `pluginWidgetTypes`).
    public var widgetTypes: Set<String> { pluginWidgetTypes }
}

/// Two plugins, or a plugin and a registered widget or standalone action,
/// claiming the same name (Dart's `ArgumentError` from `mergePlugins`). The
/// message is Flutter's, verbatim.
public struct OrcaPluginConflict: Error, Equatable, CustomStringConvertible {
    public let message: String

    public init(message: String) { self.message = message }

    public var description: String { message }
}

/// Merges plugins with the built-in and host widgets and the standalone custom
/// actions, as Dart `mergePlugins` (sdk/lib/src/plugins/plugin_merger.dart).
public enum PluginMerger {
    /// Standalone `customActions` first, then each plugin in list order: its
    /// widgets, then its actions, then its triggers (concatenated per widget
    /// type, unchecked). Throws `OrcaPluginConflict` on the first conflict.
    ///
    /// Within a plugin the keys are visited in sorted (UTF-16) order, where
    /// Dart uses its maps' insertion order, so both native SDKs report the
    /// same first conflict. Built-in action kinds are not in the merged map,
    /// so a plugin action named like one (`navigate`) merges and overrides it,
    /// as in Dart.
    public static func merge(
        builtInWidgets: Set<String>, hostWidgets: Set<String> = [],
        customActions: [String: OrcaActionHandler] = [:], plugins: [PluginParts]
    ) throws -> PluginMergeResult {
        let registered = builtInWidgets.union(hostWidgets)
        var actions = customActions
        var triggers: [String: [TriggerDefinition]] = [:]
        var widgetOwners: [String: String] = [:]
        var actionOwners: [String: String] = [:]

        for plugin in plugins {
            for type in plugin.widgetTypes.sorted(by: utf16Order) {
                if let owner = widgetOwners[type] {
                    throw OrcaPluginConflict(
                        message: "Widget type \"\(type)\" from plugin \"\(plugin.name)\" conflicts with plugin \"\(owner)\".")
                }
                if registered.contains(type) {
                    throw OrcaPluginConflict(
                        message: "Widget type \"\(type)\" from plugin \"\(plugin.name)\" "
                            + "conflicts with an already registered widget.")
                }
                widgetOwners[type] = plugin.name
            }
            for (type, handler) in plugin.actions.sorted(by: { utf16Order($0.key, $1.key) }) {
                if let owner = actionOwners[type] {
                    throw OrcaPluginConflict(
                        message: "Action type \"\(type)\" from plugin \"\(plugin.name)\" conflicts with plugin \"\(owner)\".")
                }
                if actions[type] != nil {
                    throw OrcaPluginConflict(
                        message: "Action type \"\(type)\" from plugin \"\(plugin.name)\" "
                            + "conflicts with an already registered action.")
                }
                actions[type] = handler
                actionOwners[type] = plugin.name
            }
            for (type, list) in plugin.triggers.sorted(by: { utf16Order($0.key, $1.key) }) {
                triggers[type, default: []] += list
            }
        }

        return PluginMergeResult(
            actions: actions, triggers: triggers, widgetOwners: widgetOwners,
            pluginActionTypes: Set(actionOwners.keys))
    }

    /// UTF-16 code unit order, as Kotlin's `sorted()` and CapabilityVector's
    /// canonical JSON compare strings.
    private static func utf16Order(_ a: String, _ b: String) -> Bool {
        a.utf16.lexicographicallyPrecedes(b.utf16)
    }
}
