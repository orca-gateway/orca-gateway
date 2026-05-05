import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../builders/builder_helpers.dart' show resolveIconData;
import '../client/orca_client.dart';
import '../client/static_flow_manager.dart';
import '../models/page_response.dart';
import '../rendering/component_registry.dart';
import '../state/action_executor.dart' show ActionHandler;
import '../state/state_manager.dart';
import '../widgets/orca_page.dart';
import '../widgets/orca_shell.dart';
import 'deeplink_event.dart';

/// Builds a [GoRouter] from server-provided [NavConfig].
class NavigationHandler {
  NavigationHandler._();

  /// Build a [GoRouter] from the server navigation config.
  ///
  /// [onLocationChanged] fires after every GoRouter location change, after
  /// any SDK-owned `redirect` has resolved. It is the single choke point the
  /// SDK uses to dispatch both route-change and deeplink callbacks — OrcaApp
  /// layers `onRouteChanged` and `onDeeplink` semantics on top of it.
  ///
  /// [extraObservers] are developer-supplied [NavigatorObserver]s forwarded
  /// into the GoRouter's observers list. The SDK prepends its own
  /// type-tracking observer so route-change type detection stays internal.
  static GoRouter buildRouter({
    required NavConfig config,
    required OrcaClient client,
    required String appId,
    required StateManager stateManager,
    ComponentRegistry? registry,
    Map<String, ActionHandler>? customActions,
    GlobalKey<NavigatorState>? navigatorKey,
    StaticFlowManager? staticFlowManager,
    void Function(String location, String? previous, OrcaRouteChangeType type)?
        onLocationChanged,
    List<NavigatorObserver>? extraObservers,
  }) {
    final routes = <RouteBase>[];

    // Collect all routes from all flows into a flat list of NavRoute
    final allRoutes = <NavRoute>[];
    for (final flow in config.flows) {
      allRoutes.addAll(flow.routes);
    }

    if (config.tabs.isNotEmpty) {
      // Build tabbed navigation with StatefulShellRoute
      final branches = <StatefulShellBranch>[];

      for (final tab in config.tabs) {
        // Find routes that belong to this tab (start with tab's initialRoute)
        final tabRoutes = _findTabRoutes(tab, allRoutes);
        branches.add(
          StatefulShellBranch(
            routes: tabRoutes.isNotEmpty
                ? tabRoutes
                    .map((r) => _buildGoRoute(
                          r,
                          client: client,
                          appId: appId,
                          stateManager: stateManager,
                          registry: registry,
                          customActions: customActions,
                          staticFlowManager: staticFlowManager,
                          flows: config.flows,
                        ))
                    .toList()
                : [
                    GoRoute(
                      path: tab.initialRoute,
                      builder: (context, state) => _buildOrcaPage(
                        client: client,
                        appId: appId,
                        stateManager: stateManager,
                        registry: registry,
                        customActions: customActions,
                        goRouterState: state,
                        staticFlowManager: staticFlowManager,
                        flows: config.flows,
                      ),
                    ),
                  ],
          ),
        );
      }

      routes.add(
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return OrcaShell(
              navigationShell: navigationShell,
              tabs: config.tabs,
              drawerItems: config.drawerItems,
              tabBarComponents: config.tabBarComponents,
              drawerComponents: config.drawerComponents,
              stateManager: stateManager,
              registry: registry,
              customActions: customActions,
              client: client,
              appId: appId,
            );
          },
          branches: branches,
        ),
      );

      // Add non-tab routes as top-level routes (e.g. drawer-only destinations).
      // These get push()'d on top of the shell, so wrap them in a Scaffold
      // with an AppBar + back button.
      final tabPrefixes = config.tabs.map((t) => t.initialRoute).toSet();
      final drawerLabels = <String, String>{
        for (final item in config.drawerItems) item.route: item.label,
      };
      for (final route in allRoutes) {
        final path = route.path.startsWith('/') ? route.path : '/${route.path}';
        final isTabRoute = tabPrefixes.any((prefix) => path.startsWith(prefix));
        if (!isTabRoute) {
          // Drawer label → parent-segment (for ":id" dynamic tails) →
          // capitalized last path segment.
          final segments =
              path.split('/').where((s) => s.isNotEmpty).toList();
          String pickSegment() {
            final last = segments.last;
            if (last.startsWith(':') && segments.length >= 2) {
              return segments[segments.length - 2];
            }
            return last;
          }
          final seg = pickSegment();
          final label =
              drawerLabels[path] ?? (seg[0].toUpperCase() + seg.substring(1));
          routes.add(_buildGoRoute(
            route,
            client: client,
            appId: appId,
            stateManager: stateManager,
            registry: registry,
            customActions: customActions,
            scaffoldTitle: label,
            staticFlowManager: staticFlowManager,
            flows: config.flows,
          ));
        }
      }
    } else {
      // No tabs — all routes are top-level stack routes
      for (final route in allRoutes) {
        routes.add(_buildGoRoute(
          route,
          client: client,
          appId: appId,
          stateManager: stateManager,
          registry: registry,
          customActions: customActions,
          staticFlowManager: staticFlowManager,
          flows: config.flows,
        ));
      }
    }

    // Track the most recent navigation type (push/replace/pop) via a private
    // NavigatorObserver. The routerDelegate listener below correlates this
    // with the post-redirect location URI to deliver a single callback per
    // navigation — avoiding the NavigatorObserver's own inability to see the
    // final resolved location (observer fires before the redirect completes).
    var lastType = OrcaRouteChangeType.push;
    final typeTracker = _OrcaTypeTrackingObserver(
      (type) => lastType = type,
    );

    final observers = <NavigatorObserver>[
      typeTracker,
      ...?extraObservers,
    ];

    final router = GoRouter(
      initialLocation: config.initialRoute,
      navigatorKey: navigatorKey,
      routes: routes,
      observers: observers,
      redirect: (context, state) {
        // Check redirect rules for the matched route
        final matchedRoute = _findRouteByPath(allRoutes, state.matchedLocation);
        if (matchedRoute?.redirect != null) {
          final rule = matchedRoute!.redirect!;
          final appState = stateManager.appStore.state;
          final value = appState[rule.when];
          if (value == rule.equals) {
            return rule.to;
          }
        }
        return null;
      },
    );

    if (onLocationChanged != null) {
      String? previous;
      router.routerDelegate.addListener(() {
        final uri =
            router.routerDelegate.currentConfiguration.uri.toString();
        if (uri == previous) return;
        final prev = previous;
        previous = uri;
        onLocationChanged(uri, prev, lastType);
      });
    }

    return router;
  }

  /// Find routes belonging to a specific tab.
  static List<NavRoute> _findTabRoutes(TabDef tab, List<NavRoute> allRoutes) {
    final tabPath = tab.initialRoute.startsWith('/')
        ? tab.initialRoute
        : '/${tab.initialRoute}';
    return allRoutes.where((r) {
      final routePath = r.path.startsWith('/') ? r.path : '/${r.path}';
      return routePath == tabPath || routePath.startsWith('$tabPath/');
    }).toList();
  }

  /// Build a GoRoute from a NavRoute.
  /// [parentPath] is used to make child routes relative (GoRouter requirement).
  /// [scaffoldTitle] when set, wraps the page in a Scaffold with AppBar + back button.
  static GoRoute _buildGoRoute(
    NavRoute route, {
    required OrcaClient client,
    required String appId,
    required StateManager stateManager,
    ComponentRegistry? registry,
    Map<String, ActionHandler>? customActions,
    String parentPath = '',
    String? scaffoldTitle,
    StaticFlowManager? staticFlowManager,
    List<NavFlow>? flows,
  }) {
    final fullPath = route.path.startsWith('/') ? route.path : '/${route.path}';

    // GoRouter child routes must be relative to their parent.
    // If parentPath is "/home" and fullPath is "/home/product/:id",
    // the GoRoute path should be "product/:id".
    String goRoutePath;
    if (parentPath.isNotEmpty && fullPath.startsWith('$parentPath/')) {
      goRoutePath = fullPath.substring(parentPath.length + 1);
    } else {
      goRoutePath = fullPath;
    }

    final transition = route.transition;
    final childRoutes = route.children
        .map((child) => _buildGoRoute(
              child,
              client: client,
              appId: appId,
              stateManager: stateManager,
              registry: registry,
              customActions: customActions,
              parentPath: fullPath,
              staticFlowManager: staticFlowManager,
              flows: flows,
            ))
        .toList();

    Widget buildPage(GoRouterState state) => _buildOrcaPage(
          client: client,
          appId: appId,
          stateManager: stateManager,
          registry: registry,
          customActions: customActions,
          goRouterState: state,
          scaffoldTitle: scaffoldTitle,
          staticFlowManager: staticFlowManager,
          flows: flows,
        );

    if (transition != null && transition.type != 'none') {
      return GoRoute(
        path: goRoutePath,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: buildPage(state),
          transitionDuration: Duration(milliseconds: transition.duration),
          reverseTransitionDuration: Duration(milliseconds: transition.duration),
          transitionsBuilder: _transitionsBuilder(transition.type, transition.curve),
        ),
        routes: childRoutes,
      );
    }

    return GoRoute(
      path: goRoutePath,
      builder: (context, state) => buildPage(state),
      routes: childRoutes,
    );
  }

  /// Build a transitionsBuilder function for the given transition type.
  static Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)
      _transitionsBuilder(String type, String curve) {
    return (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: _parseCurve(curve),
      );
      return switch (type) {
        'fade' => FadeTransition(opacity: curvedAnimation, child: child),
        'scale' => ScaleTransition(scale: curvedAnimation, child: child),
        'slideUp' => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(curvedAnimation),
            child: child),
        'slideRight' => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(curvedAnimation),
            child: child),
        'slide' || _ => SlideTransition(
            position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
                .animate(curvedAnimation),
            child: child),
      };
    };
  }

  static Curve _parseCurve(String value) {
    return switch (value) {
      'linear' => Curves.linear,
      'easeIn' => Curves.easeIn,
      'easeOut' => Curves.easeOut,
      'decelerate' => Curves.decelerate,
      'bounceIn' => Curves.bounceIn,
      'bounceOut' => Curves.bounceOut,
      'bounceInOut' => Curves.bounceInOut,
      'elasticIn' => Curves.elasticIn,
      'elasticOut' => Curves.elasticOut,
      'elasticInOut' => Curves.elasticInOut,
      'fastOutSlowIn' => Curves.fastOutSlowIn,
      _ => Curves.easeInOut,
    };
  }

  /// Build an OrcaPage using the full matched location from GoRouter.
  /// When [scaffoldTitle] is set, wraps the page in a Scaffold with
  /// an AppBar that has a back button (used for pushed drawer routes).
  static Widget _buildOrcaPage({
    required OrcaClient client,
    required String appId,
    required StateManager stateManager,
    ComponentRegistry? registry,
    Map<String, ActionHandler>? customActions,
    required GoRouterState goRouterState,
    String? scaffoldTitle,
    StaticFlowManager? staticFlowManager,
    List<NavFlow>? flows,
  }) {
    // Use the fully resolved matched location (e.g. "/home/product/3")
    // and strip the leading slash for the page fetch path.
    final resolvedPath = _extractPagePath(goRouterState.matchedLocation);

    final page = OrcaPage(
      client: client,
      appId: appId,
      path: resolvedPath,
      stateManager: stateManager,
      registry: registry,
      customActions: customActions,
      staticFlowManager: staticFlowManager,
      flows: flows,
      wrapInScaffold: scaffoldTitle != null,
      scaffoldTitleFallback: scaffoldTitle,
    );

    return page;
  }

  /// Strip leading slash for the page fetch path.
  static String _extractPagePath(String path) {
    return path.startsWith('/') ? path.substring(1) : path;
  }

  /// Find a NavRoute matching a given location path.
  static NavRoute? _findRouteByPath(List<NavRoute> routes, String location) {
    for (final route in routes) {
      final routePath = route.path.startsWith('/') ? route.path : '/${route.path}';
      if (_pathMatches(routePath, location)) return route;
      if (route.children.isNotEmpty) {
        final child = _findRouteByPath(route.children, location);
        if (child != null) return child;
      }
    }
    return null;
  }

  /// Simple path matching supporting :param segments.
  static bool _pathMatches(String pattern, String location) {
    final patternParts = pattern.split('/').where((s) => s.isNotEmpty).toList();
    final locationParts = location.split('/').where((s) => s.isNotEmpty).toList();
    if (patternParts.length != locationParts.length) return false;
    for (var i = 0; i < patternParts.length; i++) {
      if (patternParts[i].startsWith(':')) continue;
      if (patternParts[i] != locationParts[i]) return false;
    }
    return true;
  }

  /// Resolve a Material icon name to an IconData.
  /// Delegates to the shared [resolveIconData] from builder_helpers.
  static IconData resolveIcon(String? name) => resolveIconData(name);
}

/// Private NavigatorObserver whose only job is to record the most recent
/// navigation kind (push/replace/pop) so the routerDelegate listener in
/// [NavigationHandler.buildRouter] can correlate it with the final
/// post-redirect URI.
///
/// We don't report the change from here directly because a NavigatorObserver
/// fires during the navigator transaction — BEFORE GoRouter's redirect chain
/// resolves — so the observed route may not be the final one.
class _OrcaTypeTrackingObserver extends NavigatorObserver {
  _OrcaTypeTrackingObserver(this._onType);
  final void Function(OrcaRouteChangeType type) _onType;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onType(OrcaRouteChangeType.push);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _onType(OrcaRouteChangeType.replace);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onType(OrcaRouteChangeType.pop);
  }
}
