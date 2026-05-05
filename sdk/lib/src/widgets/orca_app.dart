import 'dart:convert' show jsonEncode;

import 'package:flutter/material.dart' show
    CircularProgressIndicator,
    MaterialApp,
    ThemeData,
    ThemeMode,
    kThemeAnimationDuration;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';

import '../client/orca_client.dart';
import '../client/offline_session_store.dart';
import '../client/static_flow_manager.dart';
import '../client/version_checker.dart';
import '../debug/orca_debug.dart';
import '../models/page_response.dart';
import '../navigation/deeplink_event.dart';
import '../navigation/navigation_handler.dart';
import '../plugins/orca_plugin.dart';
import '../plugins/plugin_merger.dart';
import '../rendering/component_registry.dart';
import '../state/action_executor.dart' show ActionHandler;
import '../state/state_manager.dart';
import 'orca_error.dart';
import 'orca_material_app_config.dart';
import 'orca_nav_config.dart';

/// Result of [OrcaApp.preload] — either a loaded config or a reason it couldn't load.
sealed class PreloadResult {}

/// Config loaded successfully.
class PreloadSuccess extends PreloadResult {
  final NavConfig config;
  PreloadSuccess(this.config);
}

/// Server requires a forced app update.
class PreloadForceUpdate extends PreloadResult {}

/// Boot state for the app initialization sequence.
enum _BootState { splash, ready, forceUpdate, error }

/// Top-level widget that fetches navigation config from the server
/// and builds a full GoRouter-based app with tabs, drawer, and deeplinks.
class OrcaApp extends StatefulWidget {
  /// The OrcaClient used to fetch config and pages.
  final OrcaClient client;

  /// The app ID to fetch config for.
  final String appId;

  /// Shared StateManager — if null, one is created.
  final StateManager? stateManager;

  /// The component registry to use for rendering pages.
  final ComponentRegistry? registry;

  /// Optional custom action handlers to register on every ActionExecutor.
  /// Keys are action type strings, values are handler functions.
  final Map<String, ActionHandler>? customActions;

  /// Optional plugins that bundle related custom widgets and actions.
  /// Plugins are merged with [registry] and [customActions] at init time.
  /// Throws [ArgumentError] if two plugins register the same type.
  final List<OrcaPlugin>? plugins;

  /// Widget to show while loading config.
  final Widget? loadingWidget;

  /// Widget builder to show on config fetch error.
  final Widget Function(Object error)? errorBuilder;

  /// Optional theme data for the MaterialApp.
  ///
  /// Prefer [materialApp] ([OrcaMaterialAppConfig.theme]) going forward —
  /// this flat field is retained for backwards compatibility and is ignored
  /// when [materialApp] is provided.
  @Deprecated('Use materialApp.theme instead')
  final ThemeData? theme;

  /// Optional title for the MaterialApp.
  ///
  /// Prefer [materialApp] ([OrcaMaterialAppConfig.title]) going forward.
  /// Retained for backwards compatibility; ignored when [materialApp] is set.
  @Deprecated('Use materialApp.title instead')
  final String title;

  /// Full developer-facing MaterialApp passthrough configuration.
  ///
  /// When provided, all supplied fields are forwarded to BOTH the boot-time
  /// `MaterialApp` (which hosts splash/force-update/error) and the ready-state
  /// `MaterialApp.router`, keeping theming and localization consistent across
  /// the boot swap.
  ///
  /// The SDK deliberately does not expose routing-related fields — OrcaApp
  /// owns the GoRouter and its configuration.
  final OrcaMaterialAppConfig? materialApp;

  /// Fires on every GoRouter location change, including in-app navigation.
  ///
  /// Use this for analytics breadcrumbs or general navigation logging.
  /// For externally-initiated deeplinks specifically, prefer [onDeeplink].
  final void Function(OrcaRouteChangeEvent event)? onRouteChanged;

  /// Fires after the SDK has resolved an externally-initiated deeplink
  /// (cold-start launch URL or warm-resume via intent / universal link).
  ///
  /// Runs AFTER any server-defined `RedirectRule` or auth gate has executed,
  /// so the event carries the FINAL route — developer code never has to
  /// reimplement SDK-owned redirect logic.
  final void Function(OrcaDeeplinkEvent event)? onDeeplink;

  /// Whether to enable offline support via static flow caching.
  final bool enableOffline;

  /// Widget to show during splash/version check. Falls back to [loadingWidget].
  final Widget? splashWidget;

  /// Widget builder for the force-update screen.
  final Widget Function()? forceUpdateBuilder;

  /// Pre-loaded NavConfig. When provided, skips the config fetch entirely.
  /// Use [OrcaApp.preload] to obtain this before constructing OrcaApp.
  final NavConfig? preloadedConfig;

  /// Pre-initialized StaticFlowManager. Pass the same instance from [preload].
  final StaticFlowManager? staticFlowManager;

  /// Whether to send session start/end events to the engine when the app
  /// enters the foreground or background. Default: false.
  final bool enableSessionTracking;

  /// Optional debug configuration. When [OrcaDebugConfig.enabled] is true,
  /// debug instrumentation (timing, state changes, actions, network) is active.
  final OrcaDebugConfig? debugConfig;

  const OrcaApp({
    super.key,
    required this.client,
    required this.appId,
    this.stateManager,
    this.registry,
    this.customActions,
    this.plugins,
    this.loadingWidget,
    this.errorBuilder,
    @Deprecated('Use materialApp.theme instead') this.theme,
    @Deprecated('Use materialApp.title instead') this.title = '',
    this.materialApp,
    this.onRouteChanged,
    this.onDeeplink,
    this.enableOffline = false,
    this.splashWidget,
    this.forceUpdateBuilder,
    this.preloadedConfig,
    this.staticFlowManager,
    this.enableSessionTracking = false,
    this.debugConfig,
  });

  /// Pre-load config and cache static flows before constructing OrcaApp.
  /// Call this during your own splash screen, then pass the result to OrcaApp.
  ///
  /// Returns [PreloadForceUpdate] if the server demands an app update.
  /// Returns [PreloadSuccess] with the config on success.
  /// Throws if offline and no cached config exists.
  ///
  /// Example:
  /// ```dart
  /// final flowManager = StaticFlowManager();
  /// final result = await OrcaApp.preload(
  ///   client: client,
  ///   appId: 'myapp',
  ///   flowManager: flowManager,
  /// );
  /// switch (result) {
  ///   case PreloadForceUpdate():
  ///     // show force update screen
  ///     break;
  ///   case PreloadSuccess(:final config):
  ///     runApp(OrcaApp(
  ///       client: client,
  ///       appId: 'myapp',
  ///       preloadedConfig: config,
  ///       staticFlowManager: flowManager,
  ///     ));
  /// }
  /// ```
  static Future<PreloadResult> preload({
    required OrcaClient client,
    required String appId,
    required StaticFlowManager flowManager,
  }) async {
    final checker = VersionChecker(
      client: client,
      appId: appId,
      flowManager: flowManager,
    );
    final outcome = await checker.check();

    switch (outcome.result) {
      case VersionCheckResult.forceUpdate:
        return PreloadForceUpdate();

      case VersionCheckResult.offline:
        final cached = await flowManager.loadConfig();
        if (cached != null) return PreloadSuccess(cached);
        throw Exception('No network and no cached config available');

      case VersionCheckResult.fresh:
        // Versions match — use cached config (saves bandwidth)
        final cached = await flowManager.loadConfig();
        if (cached != null) return PreloadSuccess(cached);
        // Cache missing (first boot?) — fetch then cache in background
        final freshConfig = await client.fetchConfig(appId);
        // Fire-and-forget: don't block on cache writes
        flowManager.saveConfigRaw(freshConfig.rawBody ?? jsonEncode(freshConfig.raw));
        flowManager.cacheStaticFlows(freshConfig);
        return PreloadSuccess(freshConfig);

      case VersionCheckResult.stale:
        final config = await client.fetchConfig(appId);
        // Fire-and-forget: don't block on cache writes
        flowManager.saveConfigRaw(config.rawBody ?? jsonEncode(config.raw));
        flowManager.cacheStaticFlows(config);
        return PreloadSuccess(config);
    }
  }

  @override
  State<OrcaApp> createState() => _OrcaAppState();
}

class _OrcaAppState extends State<OrcaApp> with WidgetsBindingObserver {
  late StateManager _stateManager;
  GoRouter? _router;
  NavConfig? _config;
  StaticFlowManager? _flowManager;

  _BootState _bootState = _BootState.splash;
  Object? _error;
  String? _deviceId;

  // --- Deeplink tracking ---
  // The raw incoming URI that should be reported via [OrcaApp.onDeeplink]
  // once the router finishes resolving it (redirects, auth gates, etc.).
  // When null, the next route change is treated as ordinary in-app navigation.
  Uri? _pendingDeeplink;
  bool _pendingDeeplinkIsColdStart = false;

  // Whether we've already consumed the cold-start deeplink from the platform.
  // Prevents re-firing onDeeplink on hot reload or state rebuilds.
  bool _coldStartDeeplinkConsumed = false;

  // Whether we're subscribed to WidgetsBinding for deeplink/lifecycle events.
  // We subscribe if EITHER session tracking OR deeplink callbacks are used.
  bool _observerAttached = false;

  @override
  void initState() {
    super.initState();
    if (widget.debugConfig != null && widget.debugConfig!.enabled) {
      OrcaDebug.init(widget.debugConfig!);
    }
    _stateManager = widget.stateManager ?? StateManager();
    _flowManager = widget.staticFlowManager ??
        (widget.enableOffline ? StaticFlowManager() : null);

    // Subscribe once if any lifecycle-dependent feature needs it.
    if (widget.enableSessionTracking || widget.onDeeplink != null) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }
    if (widget.enableSessionTracking) {
      _initSession();
    }

    // Capture cold-start deeplink — the URI the OS used to launch the app.
    // Flutter exposes this via PlatformDispatcher.defaultRouteName. Any value
    // other than '/' indicates the app was entered via a deeplink.
    if (widget.onDeeplink != null) {
      final defaultRoute =
          WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      if (defaultRoute.isNotEmpty && defaultRoute != '/') {
        _pendingDeeplink = Uri.tryParse(defaultRoute);
        _pendingDeeplinkIsColdStart = true;
      }
    }

    _initialize();
  }

  @override
  void dispose() {
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
    }
    OrcaDebug.instance?.dispose();
    _router?.dispose();
    super.dispose();
  }

  /// Called by Flutter when the OS pushes a new route into the app while it
  /// is already running — i.e. a warm-resume deeplink. We capture the URI as
  /// pending; the router listener will flush it to [OrcaApp.onDeeplink] once
  /// the SDK's redirect chain has produced the final location.
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    if (widget.onDeeplink != null) {
      _pendingDeeplink = routeInformation.uri;
      _pendingDeeplinkIsColdStart = false;
    }
    return super.didPushRouteInformation(routeInformation);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enableSessionTracking) return;
    if (state == AppLifecycleState.resumed) {
      widget.client.sendSessionStart(widget.appId, deviceId: _deviceId);
      _flushOfflineSessions();
    } else if (state == AppLifecycleState.paused) {
      widget.client.sendSessionEnd(widget.appId, deviceId: _deviceId);
    }
  }

  Future<void> _initSession() async {
    final store = OfflineSessionStore();
    widget.client.setOfflineSessionStore(store);

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        _deviceId = ios.identifierForVendor;
      } else if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        _deviceId = android.id;
      }
    } catch (_) {
      // Fall back to null deviceId if platform call fails
    }
    widget.client.sendSessionStart(widget.appId, deviceId: _deviceId);
    _flushOfflineSessions();
  }

  Future<void> _flushOfflineSessions() async {
    if (_deviceId == null) return;
    await widget.client.flushOfflineSessions(widget.appId, deviceId: _deviceId!);
  }

  Future<void> _initialize() async {
    try {
      // Fold plugin-contributed widgets + actions into the client's
      // capability vector BEFORE any /config or /page fetch runs. The
      // server's capability-aware fallback policy otherwise strips any
      // widget / action it can't find in the client's advertised vector,
      // and since the compile-time kSupportedWidgets / kSupportedActionKinds
      // only know about core SDK types, plugin widgets (OpenStreetMap,
      // GoogleMap, etc.) would silently vanish from every rendered tree.
      final pluginWidgets = <String>{};
      final pluginActions = <String>{};
      for (final plugin in widget.plugins ?? const []) {
        pluginWidgets.addAll(plugin.widgets.keys);
        pluginActions.addAll(plugin.actions.keys);
      }
      if (pluginWidgets.isNotEmpty || pluginActions.isNotEmpty) {
        widget.client.registerCapabilityExtensions(
          widgets: pluginWidgets,
          actions: pluginActions,
        );
      }

      // If config was pre-loaded (e.g. from developer's own splash), use it directly
      if (widget.preloadedConfig != null) {
        _initRouter(widget.preloadedConfig!);
        if (mounted) setState(() => _bootState = _BootState.ready);
        return;
      }

      if (widget.enableOffline && _flowManager != null) {
        await _initializeWithOffline();
      } else {
        await _initializeOnlineOnly();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bootState = _BootState.error;
          _error = e;
        });
      }
    }
  }

  Future<void> _initializeOnlineOnly() async {
    final config = await widget.client.fetchConfig(widget.appId);
    _initRouter(config);
    if (mounted) {
      setState(() => _bootState = _BootState.ready);
    }
  }

  Future<void> _initializeWithOffline() async {
    final result = await OrcaApp.preload(
      client: widget.client,
      appId: widget.appId,
      flowManager: _flowManager!,
    );

    switch (result) {
      case PreloadForceUpdate():
        if (mounted) setState(() => _bootState = _BootState.forceUpdate);
      case PreloadSuccess(:final config):
        _initRouter(config);
        if (mounted) setState(() => _bootState = _BootState.ready);
    }
  }

  void _initRouter(NavConfig config) {
    _config = config;

    // Pre-compute dynamic route paths for O(1) lookups
    _flowManager?.initDynamicPaths(config.flows);

    // Initialize app-level state from server config
    for (final entry in config.initialAppState.entries) {
      _stateManager.setAppState(entry.key, entry.value);
    }

    final merged = mergePlugins(
      registry: widget.registry,
      customActions: widget.customActions,
      plugins: widget.plugins,
    );

    _router = NavigationHandler.buildRouter(
      config: config,
      client: widget.client,
      appId: widget.appId,
      stateManager: _stateManager,
      registry: merged.registry,
      customActions: merged.customActions,
      staticFlowManager: _flowManager,
      extraObservers: widget.materialApp?.navigatorObservers,
      onLocationChanged:
          (widget.onRouteChanged != null || widget.onDeeplink != null)
              ? _handleLocationChanged
              : null,
    );
  }

  /// Single choke point that receives post-redirect location changes from
  /// the router. Dispatches to [OrcaApp.onRouteChanged] (always) and to
  /// [OrcaApp.onDeeplink] (only when a deeplink is pending).
  void _handleLocationChanged(
    String location,
    String? previousLocation,
    OrcaRouteChangeType type,
  ) {
    // Always fire the general route-change callback.
    widget.onRouteChanged?.call(OrcaRouteChangeEvent(
      location: location,
      previousLocation: previousLocation,
      type: type,
    ));

    // If a deeplink is pending (cold-start URI or OS-pushed warm resume),
    // flush it now — the location we observe here is the FINAL route after
    // any SDK redirect rule has run, so the contract "fire after SDK logic"
    // is naturally satisfied.
    final pending = _pendingDeeplink;
    if (pending != null && widget.onDeeplink != null) {
      // Guard against double-firing the cold-start deeplink across rebuilds.
      if (_pendingDeeplinkIsColdStart && _coldStartDeeplinkConsumed) {
        _pendingDeeplink = null;
        return;
      }

      // Extract params from the resolved location URI for developer convenience.
      final resolvedUri = Uri.tryParse(location) ?? Uri();
      final wasRedirected = pending.path != resolvedUri.path;

      widget.onDeeplink!.call(OrcaDeeplinkEvent(
        incoming: pending,
        resolvedLocation: location,
        pathParameters: const <String, String>{},
        queryParameters: resolvedUri.queryParameters,
        wasRedirected: wasRedirected,
        isColdStart: _pendingDeeplinkIsColdStart,
      ));

      if (_pendingDeeplinkIsColdStart) {
        _coldStartDeeplinkConsumed = true;
      }
      _pendingDeeplink = null;
      _pendingDeeplinkIsColdStart = false;
    }
  }

  Widget _buildSplash() {
    return widget.splashWidget ??
        widget.loadingWidget ??
        const Center(child: CircularProgressIndicator());
  }

  Widget _buildForceUpdate() {
    if (widget.forceUpdateBuilder != null) {
      return widget.forceUpdateBuilder!();
    }
    return const Center(
      child: Text('Update required. Please update the app.'),
    );
  }

  Widget _buildError() {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(_error!);
    }
    return buildOrcaError(_error!);
  }

  /// Resolves the effective MaterialApp title, preferring the new
  /// [OrcaMaterialAppConfig.title] over the deprecated flat [OrcaApp.title].
  String _effectiveTitle() {
    final cfgTitle = widget.materialApp?.title;
    if (cfgTitle != null) return cfgTitle;
    // ignore: deprecated_member_use_from_same_package
    return widget.title;
  }

  /// Resolves the effective theme, preferring [OrcaMaterialAppConfig.theme]
  /// over the deprecated flat [OrcaApp.theme].
  ThemeData? _effectiveTheme() {
    final cfgTheme = widget.materialApp?.theme;
    if (cfgTheme != null) return cfgTheme;
    // ignore: deprecated_member_use_from_same_package
    return widget.theme;
  }

  /// Build a [MaterialApp] for the boot states (splash / forceUpdate / error).
  /// Uses `home:` since there is no router yet. Forwards the full
  /// [OrcaMaterialAppConfig] so theming/localization match the ready state.
  Widget _buildBootMaterialApp(Widget home) {
    final cfg = widget.materialApp;
    return MaterialApp(
      // Theme
      theme: _effectiveTheme(),
      darkTheme: cfg?.darkTheme,
      highContrastTheme: cfg?.highContrastTheme,
      highContrastDarkTheme: cfg?.highContrastDarkTheme,
      themeMode: cfg?.themeMode ?? ThemeMode.system,
      themeAnimationDuration:
          cfg?.themeAnimationDuration ?? kThemeAnimationDuration,
      themeAnimationCurve: cfg?.themeAnimationCurve ?? Curves.linear,
      // Localization
      locale: cfg?.locale,
      localizationsDelegates: cfg?.localizationsDelegates,
      localeListResolutionCallback: cfg?.localeListResolutionCallback,
      localeResolutionCallback: cfg?.localeResolutionCallback,
      supportedLocales: cfg?.supportedLocales ?? const <Locale>[Locale('en', 'US')],
      // Title / color
      title: _effectiveTitle(),
      onGenerateTitle: cfg?.onGenerateTitle,
      color: cfg?.color,
      // Behavior
      builder: cfg?.builder,
      scrollBehavior: cfg?.scrollBehavior ?? const ScrollBehavior(),
      shortcuts: cfg?.shortcuts,
      actions: cfg?.actions,
      restorationScopeId: cfg?.restorationScopeId,
      navigatorObservers: cfg?.navigatorObservers ?? const <NavigatorObserver>[],
      // Debug
      debugShowCheckedModeBanner: cfg?.debugShowCheckedModeBanner ?? true,
      showPerformanceOverlay: cfg?.showPerformanceOverlay ?? false,
      showSemanticsDebugger: cfg?.showSemanticsDebugger ?? false,
      checkerboardRasterCacheImages:
          cfg?.checkerboardRasterCacheImages ?? false,
      checkerboardOffscreenLayers: cfg?.checkerboardOffscreenLayers ?? false,
      home: home,
    );
  }

  /// Build the ready-state [MaterialApp.router]. Mirrors the field
  /// forwarding from [_buildBootMaterialApp] so theming stays identical
  /// across the boot → ready swap.
  ///
  /// Note: `navigatorObservers` is NOT passed here — `MaterialApp.router`
  /// has no such parameter. Developer observers are threaded into the
  /// GoRouter via `NavigationHandler.buildRouter(extraObservers: ...)`.
  Widget _buildReadyMaterialApp() {
    final cfg = widget.materialApp;
    return OrcaNavConfig(
      config: _config!,
      child: MaterialApp.router(
        // Theme
        theme: _effectiveTheme(),
        darkTheme: cfg?.darkTheme,
        highContrastTheme: cfg?.highContrastTheme,
        highContrastDarkTheme: cfg?.highContrastDarkTheme,
        themeMode: cfg?.themeMode ?? ThemeMode.system,
        themeAnimationDuration:
            cfg?.themeAnimationDuration ?? kThemeAnimationDuration,
        themeAnimationCurve: cfg?.themeAnimationCurve ?? Curves.linear,
        // Localization
        locale: cfg?.locale,
        localizationsDelegates: cfg?.localizationsDelegates,
        localeListResolutionCallback: cfg?.localeListResolutionCallback,
        localeResolutionCallback: cfg?.localeResolutionCallback,
        supportedLocales:
            cfg?.supportedLocales ?? const <Locale>[Locale('en', 'US')],
        // Title / color
        title: _effectiveTitle(),
        onGenerateTitle: cfg?.onGenerateTitle,
        color: cfg?.color,
        // Behavior
        builder: cfg?.builder,
        scrollBehavior: cfg?.scrollBehavior ?? const ScrollBehavior(),
        shortcuts: cfg?.shortcuts,
        actions: cfg?.actions,
        restorationScopeId: cfg?.restorationScopeId,
        // Debug
        debugShowCheckedModeBanner: cfg?.debugShowCheckedModeBanner ?? true,
        showPerformanceOverlay: cfg?.showPerformanceOverlay ?? false,
        showSemanticsDebugger: cfg?.showSemanticsDebugger ?? false,
        checkerboardRasterCacheImages:
            cfg?.checkerboardRasterCacheImages ?? false,
        checkerboardOffscreenLayers:
            cfg?.checkerboardOffscreenLayers ?? false,
        // Router
        routerConfig: _router!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_bootState) {
      case _BootState.splash:
        return _buildBootMaterialApp(_buildSplash());

      case _BootState.forceUpdate:
        return _buildBootMaterialApp(_buildForceUpdate());

      case _BootState.error:
        return _buildBootMaterialApp(_buildError());

      case _BootState.ready:
        return _buildReadyMaterialApp();
    }
  }
}
