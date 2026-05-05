import 'package:flutter/widgets.dart';
import 'component_context.dart';
import '../builders/layout_builders.dart';
import '../builders/primitive_builders.dart';
import '../builders/input_builders.dart';
import '../builders/button_builders.dart';
import '../builders/structure_builders.dart';

/// Signature for a component builder function.
typedef ComponentBuilder = Widget Function(OrcaComponentContext context);

/// Metadata attached to a registered widget type for platform and UX concerns.
///
/// Lives alongside the builder in [ComponentRegistry] so the renderer can
/// decide at render time whether to run the real builder, substitute a
/// registered web stub, or fall through to the [UnsupportedWidgetPlaceholder]
/// card. Epic 38 task 38.1 / 38.2. Fields are intentionally cosmetic or
/// boolean — nothing in here is part of the wire format.
class WidgetWebMetadata {
  /// `false` when the widget cannot render in the Flutter Web preview editor
  /// (plugin widgets backed by platform views or native-only APIs). Defaults
  /// to `true` — the vast majority of core widgets render on web unchanged.
  final bool isSupportedOnWeb;

  /// Human-readable name shown in the placeholder card and the dashboard
  /// missing-widgets screen (Slice C). Falls back to the wire type when null.
  final String? displayName;

  /// Optional Material icon name shown inside the placeholder.
  final String? iconName;

  /// Optional docs URL surfaced from the placeholder card's "Learn more" link.
  final String? docsUrl;

  const WidgetWebMetadata({
    this.isSupportedOnWeb = true,
    this.displayName,
    this.iconName,
    this.docsUrl,
  });
}

/// Registry mapping component type strings to Flutter widget builders.
///
/// Holds three parallel maps:
///
///   * `_builders` — the primary `type → builder` mapping used at render time.
///   * `_metadata` — optional web-support metadata attached at registration.
///     Missing entries are treated as "supported on web with no extra data",
///     matching the default for core widgets.
///   * `_webStubs` — web-only substitute builders registered via
///     [registerWebStub]. These take effect only when the renderer is running
///     on web AND the widget's metadata marks it unsupported. When a stub is
///     present, the renderer uses it in place of the real builder — which is
///     the plugin-author escape hatch added in Epic 38 task 38.3 (e.g. a map
///     plugin ships a static image stub that runs in the preview iframe).
class ComponentRegistry {
  final Map<String, ComponentBuilder> _builders = {};
  final Map<String, WidgetWebMetadata> _metadata = {};
  final Map<String, ComponentBuilder> _webStubs = {};

  /// Register a builder for a component type, optionally attaching metadata
  /// that the renderer consults on web platforms.
  void register(
    String type,
    ComponentBuilder builder, {
    WidgetWebMetadata? metadata,
  }) {
    _builders[type] = builder;
    if (metadata != null) {
      _metadata[type] = metadata;
    }
  }

  /// Register a web-only substitute for [type] (Epic 38 task 38.3).
  ///
  /// The renderer uses this builder in place of the real one when:
  ///
  ///   1. The current platform is web (`kIsWeb`), and
  ///   2. The widget's [WidgetWebMetadata.isSupportedOnWeb] is `false`.
  ///
  /// On non-web platforms this map is never consulted — the real builder
  /// always wins. This is the intended escape hatch for plugin authors who
  /// want their widget to "work" in preview without maintaining a full Flutter
  /// Web implementation: register a static image, a stub card, or a simplified
  /// interaction that communicates the widget's shape honestly.
  void registerWebStub(String type, ComponentBuilder stubBuilder) {
    _webStubs[type] = stubBuilder;
  }

  /// Attach or update metadata for an already-registered [type].
  ///
  /// Useful when plugins register their builders through a shared helper that
  /// cannot pass metadata at registration time. Overwrites any previous
  /// metadata for the same type.
  void setMetadata(String type, WidgetWebMetadata metadata) {
    _metadata[type] = metadata;
  }

  /// Look up a builder by type. Returns null if not registered.
  ComponentBuilder? get(String type) => _builders[type];

  /// Look up the web-only substitute builder, if any.
  ComponentBuilder? getWebStub(String type) => _webStubs[type];

  /// Look up metadata for a type, or null when none was registered.
  WidgetWebMetadata? getMetadata(String type) => _metadata[type];

  /// Returns `true` when this [type] is marked unsupported on web.
  ///
  /// Absent metadata is treated as "supported on web" because every core
  /// widget that has been registered through [registerDefaults] is web-safe
  /// unless a later slice explicitly marks it otherwise. This keeps the check
  /// permissive — only widgets whose authors deliberately opt out trip it.
  bool isUnsupportedOnWeb(String type) {
    final meta = _metadata[type];
    if (meta == null) return false;
    return !meta.isSupportedOnWeb;
  }

  /// Check if a builder is registered for a type.
  bool has(String type) => _builders.containsKey(type);

  /// Register all default component builders.
  void registerDefaults() {
    registerLayoutBuilders(this);
    registerPrimitiveBuilders(this);
    registerInputBuilders(this);
    registerButtonBuilders(this);
    registerStructureBuilders(this);
  }

  /// Register multiple builders from a map. Does not attach metadata or web
  /// stubs — use [register] or [setMetadata] for those paths.
  void registerAll(Map<String, ComponentBuilder> builders) {
    _builders.addAll(builders);
  }
}
