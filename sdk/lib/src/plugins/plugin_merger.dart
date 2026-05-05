import '../rendering/component_registry.dart';
import '../state/action_executor.dart' show ActionHandler;
import 'orca_plugin.dart';

/// Result of merging plugins with standalone registry/customActions.
class PluginMergeResult {
  final ComponentRegistry registry;
  final Map<String, ActionHandler> customActions;
  final Map<String, List<TriggerDefinition>> triggers;

  PluginMergeResult({
    required this.registry,
    required this.customActions,
    required this.triggers,
  });
}

/// Merges [plugins] with standalone [registry] and [customActions].
///
/// Plugins are applied in order after standalone values. Throws
/// [ArgumentError] if two plugins register the same widget type or
/// action type.
PluginMergeResult mergePlugins({
  ComponentRegistry? registry,
  Map<String, ActionHandler>? customActions,
  List<OrcaPlugin>? plugins,
}) {
  final mergedRegistry = registry ?? (ComponentRegistry()..registerDefaults());
  final mergedActions = <String, ActionHandler>{};
  final mergedTriggers = <String, List<TriggerDefinition>>{};

  // Apply standalone customActions first
  if (customActions != null) {
    mergedActions.addAll(customActions);
  }

  if (plugins != null) {
    // Track which plugin registered each type for clear error messages
    final widgetOwners = <String, String>{};
    final actionOwners = <String, String>{};

    for (final plugin in plugins) {
      // Register widgets
      for (final entry in plugin.widgets.entries) {
        final existingOwner = widgetOwners[entry.key];
        if (existingOwner != null) {
          throw ArgumentError(
            'Widget type "${entry.key}" from plugin "${plugin.name}" '
            'conflicts with plugin "$existingOwner".',
          );
        }
        if (mergedRegistry.has(entry.key)) {
          throw ArgumentError(
            'Widget type "${entry.key}" from plugin "${plugin.name}" '
            'conflicts with an already registered widget.',
          );
        }
        mergedRegistry.register(
          entry.key,
          entry.value,
          metadata: plugin.widgetMetadata[entry.key],
        );
        widgetOwners[entry.key] = plugin.name;
      }

      // Epic 38 task 38.3: forward any web-only substitute builders into the
      // registry's parallel stub map. These are safe to register unconditionally
      // — they only take effect on web and only for widgets whose metadata
      // marks them unsupported, so registering a stub on mobile is a no-op.
      for (final stub in plugin.webStubs.entries) {
        mergedRegistry.registerWebStub(stub.key, stub.value);
      }

      // Register actions
      for (final entry in plugin.actions.entries) {
        final existingOwner = actionOwners[entry.key];
        if (existingOwner != null) {
          throw ArgumentError(
            'Action type "${entry.key}" from plugin "${plugin.name}" '
            'conflicts with plugin "$existingOwner".',
          );
        }
        if (mergedActions.containsKey(entry.key)) {
          throw ArgumentError(
            'Action type "${entry.key}" from plugin "${plugin.name}" '
            'conflicts with an already registered action.',
          );
        }
        mergedActions[entry.key] = entry.value;
        actionOwners[entry.key] = plugin.name;
      }

      // Merge trigger declarations
      for (final entry in plugin.triggers.entries) {
        mergedTriggers[entry.key] = [
          ...?mergedTriggers[entry.key],
          ...entry.value,
        ];
      }
    }
  }

  return PluginMergeResult(
    registry: mergedRegistry,
    customActions: mergedActions,
    triggers: mergedTriggers,
  );
}
