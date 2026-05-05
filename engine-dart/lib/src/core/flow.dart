import '../types/context.dart';
import 'page.dart';

/// Lifecycle hooks for routes.
class RouteHooks {
  final Future<void> Function(PageContext)? onEnter;
  final Future<void> Function(PageContext)? onExit;

  const RouteHooks({this.onEnter, this.onExit});
}

/// Route transition configuration.
class RouteTransition {
  final String type;
  final int duration;
  final String curve;

  const RouteTransition({
    required this.type,
    this.duration = 300,
    this.curve = 'easeInOut',
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'duration': duration,
        'curve': curve,
      };
}

/// Redirect rule for conditional routing.
class RedirectRule {
  final String when;
  final dynamic equals;
  final String to;

  const RedirectRule({required this.when, required this.equals, required this.to});

  Map<String, dynamic> toJson() => {'when': when, 'equals': equals, 'to': to};
}

/// Route definition.
class RouteDefinition {
  final String path;
  final Page? page;
  final List<RouteDefinition> children;
  final RouteHooks? hooks;
  final RedirectRule? redirect;
  final RouteTransition? transition;
  final bool isDynamic;

  const RouteDefinition({
    required this.path,
    this.page,
    this.children = const [],
    this.hooks,
    this.redirect,
    this.transition,
    this.isDynamic = false,
  });
}

/// Result of route matching.
class RouteMatch {
  final Page page;
  final Map<String, String> params;
  final String fullPath;
  final RouteHooks? hooks;
  final CachePolicy? flowCachePolicy;
  final int? flowCacheTtl;
  final String? flowName;

  const RouteMatch({
    required this.page,
    this.params = const {},
    required this.fullPath,
    this.hooks,
    this.flowCachePolicy,
    this.flowCacheTtl,
    this.flowName,
  });
}

/// Route info for the navigation config.
class RouteInfo {
  final String path;
  final List<RouteInfo> children;
  final bool isDynamic;
  final Map<String, dynamic>? redirect;
  final Map<String, dynamic>? transition;

  const RouteInfo({
    required this.path,
    this.children = const [],
    this.isDynamic = false,
    this.redirect,
    this.transition,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
        if (isDynamic) 'isDynamic': true,
        if (redirect != null) 'redirect': redirect,
        if (transition != null) 'transition': transition,
      };
}

/// Flow configuration.
class FlowConfig {
  final String name;
  final List<RouteDefinition> routes;
  final int version;
  final bool isStatic;
  final CachePolicy? cachePolicy;
  final int? cacheTtl;

  const FlowConfig({
    required this.name,
    required this.routes,
    this.version = 0,
    this.isStatic = false,
    this.cachePolicy,
    this.cacheTtl,
  });
}

/// Route tree container.
class Flow {
  final String name;
  final int version;
  final bool isStatic;
  final CachePolicy? cachePolicy;
  final int? cacheTtl;
  final List<RouteDefinition> _routes;

  Flow._(this.name, this.version, this.isStatic, this.cachePolicy,
      this.cacheTtl, this._routes);

  factory Flow.create(FlowConfig config) => Flow._(
        config.name,
        config.version,
        config.isStatic,
        config.cachePolicy,
        config.cacheTtl,
        config.routes,
      );

  /// Resolve a path to a route match.
  RouteMatch? resolve(String path) {
    final segments = _splitPath(path);
    return _matchRoutes(_routes, segments, {}, path);
  }

  RouteMatch? _matchRoutes(
    List<RouteDefinition> routes,
    List<String> segments,
    Map<String, String> params,
    String fullPath,
  ) {
    for (final route in routes) {
      final routeSegments = _splitPath(route.path);
      final matchResult = _matchSegments(routeSegments, segments, params);
      if (matchResult == null) continue;

      final remaining = segments.sublist(routeSegments.length);

      if (remaining.isEmpty) {
        // Exact match
        if (route.page != null) {
          return RouteMatch(
            page: route.page!,
            params: Map.unmodifiable(matchResult),
            fullPath: fullPath,
            hooks: route.hooks,
            flowCachePolicy: cachePolicy,
            flowCacheTtl: cacheTtl,
            flowName: name,
          );
        }
      }

      // Try children
      if (route.children.isNotEmpty) {
        final childMatch = _matchRoutes(route.children, remaining, matchResult, fullPath);
        if (childMatch != null) return childMatch;
      }
    }
    return null;
  }

  /// Get route info for navigation config.
  List<RouteInfo> getRouteInfo() => _buildRouteInfo(_routes);

  /// Collect all leaf pages in this flow (for static pre-rendering).
  /// Dynamic routes are skipped — they always fetch fresh.
  List<({String path, Page page})> getPages() => _collectPages(_routes, '');

  List<({String path, Page page})> _collectPages(
      List<RouteDefinition> routes, String prefix) {
    final result = <({String path, Page page})>[];
    for (final r in routes) {
      final full = prefix.isEmpty ? r.path : '$prefix/${r.path}';
      final isDyn = r.isDynamic || r.path.contains(':');
      if (r.page != null && !isDyn) {
        result.add((path: full, page: r.page!));
      }
      if (r.children.isNotEmpty) {
        result.addAll(_collectPages(r.children, full));
      }
    }
    return result;
  }

  List<RouteInfo> _buildRouteInfo(List<RouteDefinition> routes) {
    return routes.map((r) {
      return RouteInfo(
        path: r.path,
        children: r.children.isNotEmpty ? _buildRouteInfo(r.children) : [],
        isDynamic: r.isDynamic || r.path.contains(':'),
        redirect: r.redirect?.toJson(),
        transition: r.transition?.toJson(),
      );
    }).toList();
  }
}

List<String> _splitPath(String path) {
  return path.split('/').where((s) => s.isNotEmpty).toList();
}

Map<String, String>? _matchSegments(
  List<String> routeSegments,
  List<String> pathSegments,
  Map<String, String> existingParams,
) {
  if (routeSegments.length > pathSegments.length) return null;

  final params = Map<String, String>.from(existingParams);
  for (var i = 0; i < routeSegments.length; i++) {
    final routeSeg = routeSegments[i];
    final pathSeg = pathSegments[i];

    if (routeSeg.startsWith(':')) {
      params[routeSeg.substring(1)] = pathSeg;
    } else if (routeSeg != pathSeg) {
      return null;
    }
  }
  return params;
}
