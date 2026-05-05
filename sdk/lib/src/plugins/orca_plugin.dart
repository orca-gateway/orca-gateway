import '../rendering/component_registry.dart'
    show ComponentBuilder, WidgetWebMetadata;
import '../state/action_executor.dart' show ActionHandler;

/// Describes an action trigger that a custom widget can fire.
///
/// Used by plugins to declare what events their widgets support,
/// enabling validation, devtools discovery, and documentation.
class TriggerDefinition {
  /// The trigger name (e.g., "onPan", "onZoom", "onTap").
  final String name;

  /// The type of data this trigger provides via `eventData`,
  /// or null if the trigger fires with no data.
  /// Examples: "String", "double", "Offset", `Map<String, dynamic>`.
  final String? dataType;

  /// Optional description of when this trigger fires.
  final String? description;

  const TriggerDefinition({
    required this.name,
    this.dataType,
    this.description,
  });
}

/// A plugin that bundles related custom widgets, custom actions,
/// and trigger declarations.
///
/// Use plugins to co-locate widgets and actions that depend on each other,
/// ensuring both are registered together. Register plugins via
/// `OrcaApp(plugins: [...])` or `OrcaPage(plugins: [...])`.
///
/// Example:
/// ```dart
/// class MapPlugin extends OrcaPlugin {
///   MapPlugin() : super(
///     name: 'MapPlugin',
///     widgets: {
///       'MapView': (ctx) => GoogleMapView(...),
///     },
///     actions: {
///       'centerMap': (action, executor) async { ... },
///     },
///     triggers: {
///       'MapView': [
///         TriggerDefinition(name: 'onPan', dataType: 'Offset'),
///         TriggerDefinition(name: 'onZoom', dataType: 'double'),
///       ],
///     },
///     // Epic 38 task 38.1 / 38.2: declare which widgets do not run in the
///     // Flutter Web preview, and optionally supply human-readable card
///     // metadata for the UnsupportedWidgetPlaceholder that substitutes in.
///     widgetMetadata: {
///       'MapView': WidgetWebMetadata(
///         isSupportedOnWeb: false,
///         displayName: 'Google Maps',
///         iconName: 'map',
///         docsUrl: 'https://docs.example.com/map-plugin',
///       ),
///     },
///     // Epic 38 task 38.3: optional web-only substitute builder that runs
///     // inside the preview. When present the renderer uses this instead of
///     // the real builder on web.
///     webStubs: {
///       'MapView': (ctx) => const _MapPreviewStub(),
///     },
///   );
/// }
/// ```
class OrcaPlugin {
  /// Human-readable name used in error messages and debugging.
  final String name;

  /// Custom widget builders provided by this plugin.
  /// Keys are component type strings (e.g., "MapView").
  final Map<String, ComponentBuilder> widgets;

  /// Custom action handlers provided by this plugin.
  /// Keys are action type strings (e.g., "centerMap").
  final Map<String, ActionHandler> actions;

  /// Trigger declarations per widget type.
  /// Keys are component type strings matching [widgets] keys.
  /// Values list the triggers that widget can fire.
  final Map<String, List<TriggerDefinition>> triggers;

  /// Per-widget web-support metadata (Epic 38 task 38.1 / 38.2).
  ///
  /// Declaring `isSupportedOnWeb: false` here is what causes the renderer to
  /// substitute either a registered web stub or the
  /// UnsupportedWidgetPlaceholder card when the SDK runs in the Flutter Web
  /// preview. Widgets without an entry are treated as web-supported, matching
  /// the default for core widgets.
  final Map<String, WidgetWebMetadata> widgetMetadata;

  /// Per-widget web-only substitute builders (Epic 38 task 38.3).
  ///
  /// Builders listed here take priority over [widgets] entries when the SDK
  /// runs on web AND the widget is marked unsupported in [widgetMetadata].
  /// On non-web platforms this map is ignored — the real builder in [widgets]
  /// always runs. The hook gives plugin authors a low-effort path to ship
  /// something visually honest in preview (a static map image, a "will run on
  /// device" card with a CTA) without maintaining a full Flutter Web port.
  final Map<String, ComponentBuilder> webStubs;

  const OrcaPlugin({
    required this.name,
    this.widgets = const {},
    this.actions = const {},
    this.triggers = const {},
    this.widgetMetadata = const {},
    this.webStubs = const {},
  });
}
