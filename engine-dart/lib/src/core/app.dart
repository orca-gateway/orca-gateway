import '../types/context.dart';
import '../types/widget.dart' as w;
import 'flow.dart';
import 'middleware.dart' show Middleware;
import 'page.dart';
import 'pipeline.dart';
import 'server_action.dart';

/// Tab definition for navigation config.
class TabDefinition {
  final String id;
  final String label;
  final String icon;
  final String initialRoute;

  const TabDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.initialRoute,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'icon': icon,
        'initialRoute': initialRoute,
      };
}

/// Drawer item definition.
class DrawerItemDefinition {
  final String id;
  final String label;
  final String? icon;
  final String route;

  const DrawerItemDefinition({
    required this.id,
    required this.label,
    this.icon,
    required this.route,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (icon != null) 'icon': icon,
        'route': route,
      };
}

/// Shell widget — either a static [Widget] or a builder taking [RequestInfo].
typedef ShellWidgetBuilder = w.Widget Function(RequestInfo requestInfo);

/// Navigation configuration. [tabBar]/[drawer] accept a [Widget] or a
/// [ShellWidgetBuilder]; anything else is rejected at resolve time.
class NavigationConfig {
  final List<TabDefinition> tabs;
  final List<DrawerItemDefinition> drawerItems;
  final String initialRoute;
  final Map<String, dynamic> initialAppState;
  final Object? tabBar;
  final Object? drawer;

  const NavigationConfig({
    this.tabs = const [],
    this.drawerItems = const [],
    this.initialRoute = '/',
    this.initialAppState = const {},
    this.tabBar,
    this.drawer,
  });
}

/// App configuration.
class AppConfig {
  final String id;
  final String name;
  final List<Flow> flows;
  final List<ServerActionDefinition> actions;
  final NavigationConfig navigation;
  final Map<String, dynamic> configuration;
  final bool forceUpdate;

  const AppConfig({
    required this.id,
    required this.name,
    this.flows = const [],
    this.actions = const [],
    this.navigation = const NavigationConfig(),
    this.configuration = const {},
    this.forceUpdate = false,
  });
}

/// App container.
class App {
  final String id;
  final String name;
  final Map<String, dynamic> configuration;
  final bool forceUpdate;
  final NavigationConfig _navigation;
  final List<Flow> _flows;
  final Map<String, ServerActionDefinition> _actions;
  final List<Middleware> _middlewares = [];
  final Map<String, _StaticPageCache> _staticPagesCache = {};
  void Function(Object, dynamic)? globalErrorHandler;

  App._(this.id, this.name, this._flows, this._actions, this._navigation,
      this.configuration, this.forceUpdate);

  factory App.create(AppConfig config) {
    final actionMap = <String, ServerActionDefinition>{};
    for (final a in config.actions) {
      actionMap[a.id] = a;
    }
    return App._(
      config.id,
      config.name,
      List.from(config.flows),
      actionMap,
      config.navigation,
      config.configuration,
      config.forceUpdate,
    );
  }

  void registerMiddleware(Middleware mw) => _middlewares.add(mw);

  List<Middleware> getMiddlewares() => List.unmodifiable(_middlewares);

  ServerActionDefinition? getAction(String id) => _actions[id];

  /// Resolve a path across all flows.
  RouteMatch? resolve(String path) {
    for (final flow in _flows) {
      final match = flow.resolve(path);
      if (match != null) return match;
    }
    return null;
  }

  /// Get version info for all flows.
  Map<String, dynamic> getVersionInfo() {
    final flows = <String, int>{};
    for (final flow in _flows) {
      flows[flow.name] = flow.version;
    }
    return {
      'flows': flows,
      if (forceUpdate) 'forceUpdate': true,
    };
  }

  w.Widget _resolveShell(Object shell, RequestInfo? requestInfo) {
    if (shell is w.Widget) return shell;
    if (shell is ShellWidgetBuilder) {
      return shell(requestInfo ?? const RequestInfo());
    }
    throw ArgumentError(
        'NavigationConfig tabBar/drawer must be a Widget or ShellWidgetBuilder, '
        'got ${shell.runtimeType}');
  }

  Future<Map<String, PageResponse>> _preRenderStaticFlow(Flow flow) async {
    final cached = _staticPagesCache[flow.name];
    if (cached != null && cached.version == flow.version) return cached.pages;

    final entries = flow.getPages();
    final rendered = await Future.wait(entries.map((e) async {
      final ctx = PageContext(
        requestInfo: const RequestInfo(),
        pageId: e.page.id,
        routePath: '/${e.path}',
      );
      return (path: e.path, response: await runPipeline(e.page, ctx));
    }));

    final pages = <String, PageResponse>{
      for (final r in rendered) r.path: r.response,
    };
    _staticPagesCache[flow.name] =
        _StaticPageCache(version: flow.version, pages: pages);
    return pages;
  }

  /// Get full navigation config for the client.
  Future<Map<String, dynamic>> getNavConfig([RequestInfo? requestInfo]) async {
    final flowsData = await Future.wait(_flows.map((f) async {
      final entry = <String, dynamic>{
        'name': f.name,
        'routes': f.getRouteInfo().map((r) => r.toJson()).toList(),
      };
      if (f.version > 0) entry['version'] = f.version;
      if (f.isStatic) {
        entry['isStatic'] = true;
        final pages = await _preRenderStaticFlow(f);
        entry['pages'] = {
          for (final e in pages.entries) e.key: e.value.toJson(),
        };
      }
      return entry;
    }));

    List<Map<String, dynamic>>? tabBarComponents;
    List<Map<String, dynamic>>? drawerComponents;
    if (_navigation.tabBar != null) {
      tabBarComponents = w
          .flatten(_resolveShell(_navigation.tabBar!, requestInfo))
          .map((c) => c.toJson())
          .toList();
    }
    if (_navigation.drawer != null) {
      drawerComponents = w
          .flatten(_resolveShell(_navigation.drawer!, requestInfo))
          .map((c) => c.toJson())
          .toList();
    }

    return {
      'appId': id,
      'appName': name,
      'initialRoute': _navigation.initialRoute,
      if (_navigation.tabs.isNotEmpty)
        'tabs': _navigation.tabs.map((t) => t.toJson()).toList(),
      if (_navigation.drawerItems.isNotEmpty)
        'drawerItems': _navigation.drawerItems.map((d) => d.toJson()).toList(),
      if (_navigation.initialAppState.isNotEmpty)
        'initialAppState': _navigation.initialAppState,
      if (tabBarComponents != null) 'tabBarComponents': tabBarComponents,
      if (drawerComponents != null) 'drawerComponents': drawerComponents,
      'flows': flowsData,
    };
  }
}

class _StaticPageCache {
  final int version;
  final Map<String, PageResponse> pages;
  const _StaticPageCache({required this.version, required this.pages});
}
