import 'component_node.dart';

/// State definition from the server.
class StateDefinition {
  final String key;
  final String scope;
  final dynamic initial;

  const StateDefinition({
    required this.key,
    required this.scope,
    required this.initial,
  });

  factory StateDefinition.fromJson(Map<String, dynamic> json) {
    return StateDefinition(
      key: json['key'] as String,
      scope: json['scope'] as String,
      initial: json['initial'],
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'scope': scope,
    'initial': initial,
  };
}

/// Response shape for GET /api/v1/app/:appId/page/:path.
class PageResponse {
  final String pageId;
  final String title;
  final List<StateDefinition> state;
  final List<ComponentNode> components;
  final Map<String, dynamic> extra;

  const PageResponse({
    required this.pageId,
    required this.title,
    required this.state,
    required this.components,
    this.extra = const {},
  });

  factory PageResponse.fromJson(Map<String, dynamic> json) {
    try {
      final knownKeys = {'pageId', 'title', 'state', 'components'};
      final extra = Map<String, dynamic>.fromEntries(
        json.entries.where((e) => !knownKeys.contains(e.key)),
      );

      return PageResponse(
        pageId: json['pageId'] as String,
        title: json['title'] as String,
        state: (json['state'] as List)
            .map((e) => StateDefinition.fromJson(e as Map<String, dynamic>))
            .toList(),
        components: (json['components'] as List)
            .map((e) => ComponentNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        extra: extra,
      );
    } catch (e) {
      if (e is OrcaParseException) rethrow;
      throw OrcaParseException(
        'Failed to parse PageResponse: $e',
        json,
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'pageId': pageId,
    'title': title,
    'state': state.map((s) => s.toJson()).toList(),
    'components': components.map((c) => c.toJson()).toList(),
    ...extra,
  };
}

/// Response from POST /api/v1/app/:appId/action.
class ActionResponse {
  final List<Map<String, dynamic>> actions;

  const ActionResponse({required this.actions});

  factory ActionResponse.fromJson(Map<String, dynamic> json) {
    return ActionResponse(
      actions: (json['actions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

/// Navigation configuration response.
class NavConfig {
  final String initialRoute;
  final List<TabDef> tabs;
  final List<DrawerItemDef> drawerItems;
  final Map<String, dynamic> initialAppState;
  final List<ComponentNode> tabBarComponents;
  final List<ComponentNode> drawerComponents;
  final List<NavFlow> flows;
  final Map<String, dynamic> raw;
  /// The original JSON string from the HTTP response, for zero-copy cache storage.
  final String? rawBody;

  const NavConfig({
    required this.initialRoute,
    this.tabs = const [],
    this.drawerItems = const [],
    this.initialAppState = const {},
    this.tabBarComponents = const [],
    this.drawerComponents = const [],
    required this.flows,
    required this.raw,
    this.rawBody,
  });

  factory NavConfig.fromJson(Map<String, dynamic> json, {String? rawBody}) {
    final flows = (json['flows'] as List?)
            ?.map((e) => NavFlow.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final tabs = (json['tabs'] as List?)
            ?.map((e) => TabDef.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final drawerItems = (json['drawerItems'] as List?)
            ?.map((e) => DrawerItemDef.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final initialAppState = json['initialAppState'] != null
        ? Map<String, dynamic>.from(json['initialAppState'] as Map)
        : <String, dynamic>{};
    final tabBarComponents = (json['tabBarComponents'] as List?)
            ?.map((e) => ComponentNode.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final drawerComponents = (json['drawerComponents'] as List?)
            ?.map((e) => ComponentNode.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return NavConfig(
      initialRoute: json['initialRoute'] as String? ?? '/',
      tabs: tabs,
      drawerItems: drawerItems,
      initialAppState: initialAppState,
      tabBarComponents: tabBarComponents,
      drawerComponents: drawerComponents,
      flows: flows,
      raw: json,
      rawBody: rawBody,
    );
  }
}

/// Tab definition from server navigation config.
class TabDef {
  final String id;
  final String label;
  final String icon;
  final String initialRoute;

  const TabDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.initialRoute,
  });

  factory TabDef.fromJson(Map<String, dynamic> json) {
    return TabDef(
      id: json['id'] as String,
      label: json['label'] as String,
      icon: json['icon'] as String,
      initialRoute: json['initialRoute'] as String,
    );
  }
}

/// Drawer item definition from server navigation config.
class DrawerItemDef {
  final String id;
  final String label;
  final String? icon;
  final String route;

  const DrawerItemDef({
    required this.id,
    required this.label,
    this.icon,
    required this.route,
  });

  factory DrawerItemDef.fromJson(Map<String, dynamic> json) {
    return DrawerItemDef(
      id: json['id'] as String,
      label: json['label'] as String,
      icon: json['icon'] as String?,
      route: json['route'] as String,
    );
  }
}

/// Redirect rule for conditional routing.
class RedirectRule {
  final String when;
  final dynamic equals;
  final String to;

  const RedirectRule({
    required this.when,
    required this.equals,
    required this.to,
  });

  factory RedirectRule.fromJson(Map<String, dynamic> json) {
    return RedirectRule(
      when: json['when'] as String,
      equals: json['equals'],
      to: json['to'] as String,
    );
  }
}

class NavFlow {
  final String name;
  final List<NavRoute> routes;
  final int? version;
  final bool isStatic;
  final Map<String, PageResponse>? pages;

  const NavFlow({
    required this.name,
    required this.routes,
    this.version,
    this.isStatic = false,
    this.pages,
  });

  factory NavFlow.fromJson(Map<String, dynamic> json) {
    Map<String, PageResponse>? pages;
    if (json['pages'] != null) {
      pages = (json['pages'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, PageResponse.fromJson(v as Map<String, dynamic>)),
      );
    }
    return NavFlow(
      name: json['name'] as String,
      version: json['version'] as int?,
      isStatic: json['isStatic'] as bool? ?? false,
      routes: (json['routes'] as List?)
              ?.map((e) => NavRoute.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pages: pages,
    );
  }
}

/// Page transition configuration.
class RouteTransitionDef {
  final String type;
  final int duration;
  final String curve;

  const RouteTransitionDef({
    required this.type,
    this.duration = 300,
    this.curve = 'easeInOut',
  });

  factory RouteTransitionDef.fromJson(Map<String, dynamic> json) {
    return RouteTransitionDef(
      type: json['type'] as String,
      duration: json['duration'] as int? ?? 300,
      curve: json['curve'] as String? ?? 'easeInOut',
    );
  }
}

class NavRoute {
  final String path;
  final List<NavRoute> children;
  final RedirectRule? redirect;
  final RouteTransitionDef? transition;
  final bool isDynamic;

  const NavRoute({
    required this.path,
    this.children = const [],
    this.redirect,
    this.transition,
    this.isDynamic = false,
  });

  factory NavRoute.fromJson(Map<String, dynamic> json) {
    return NavRoute(
      path: json['path'] as String,
      isDynamic: json['isDynamic'] as bool? ?? false,
      children: (json['children'] as List?)
              ?.map((e) => NavRoute.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      redirect: json['redirect'] != null
          ? RedirectRule.fromJson(json['redirect'] as Map<String, dynamic>)
          : null,
      transition: json['transition'] != null
          ? RouteTransitionDef.fromJson(json['transition'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Version info response from GET /api/v1/app/:appId/version.
class VersionResponse {
  final Map<String, int> flows;
  final bool forceUpdate;

  const VersionResponse({required this.flows, this.forceUpdate = false});

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      flows: (json['flows'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }
}
