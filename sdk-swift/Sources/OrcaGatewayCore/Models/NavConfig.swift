import Foundation

/// Body of `GET /api/v1/app/:appId/config` (engine `App.getNavConfig`): the
/// app's routes, tabs, drawer and the app state to seed before the first page.
/// A port of Dart `NavConfig` (sdk/lib/src/models/page_response.dart) with its
/// defaults. Members the SDK does not read (`appId`, `appName`, a route's
/// `requiredAppState`) are ignored here and stay in `raw`.
public struct NavConfig: Decodable, Equatable, Sendable {
    public var initialRoute: String
    public var tabs: [TabDef]
    public var drawerItems: [DrawerItemDef]
    /// Seeded into app state before the router is built.
    public var initialAppState: [String: JSONValue]
    public var tabBarComponents: [ComponentNode]
    public var drawerComponents: [ComponentNode]
    public var flows: [NavFlow]
    /// The whole body as decoded, for the offline cache.
    public var raw: JSONValue
    /// The body's text as the server sent it; nil when not decoded from a
    /// response.
    public var rawBody: String?

    public init(initialRoute: String = "/", tabs: [TabDef] = [], drawerItems: [DrawerItemDef] = [],
                initialAppState: [String: JSONValue] = [:], tabBarComponents: [ComponentNode] = [],
                drawerComponents: [ComponentNode] = [], flows: [NavFlow] = [],
                raw: JSONValue = .object([:]), rawBody: String? = nil) {
        self.initialRoute = initialRoute
        self.tabs = tabs
        self.drawerItems = drawerItems
        self.initialAppState = initialAppState
        self.tabBarComponents = tabBarComponents
        self.drawerComponents = drawerComponents
        self.flows = flows
        self.raw = raw
        self.rawBody = rawBody
    }

    private enum CodingKeys: String, CodingKey {
        case initialRoute, tabs, drawerItems, initialAppState, tabBarComponents, drawerComponents, flows
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        initialRoute = try c.decodeIfPresent(String.self, forKey: .initialRoute) ?? "/"
        tabs = try c.decodeIfPresent([TabDef].self, forKey: .tabs) ?? []
        drawerItems = try c.decodeIfPresent([DrawerItemDef].self, forKey: .drawerItems) ?? []
        initialAppState = try c.decodeIfPresent([String: JSONValue].self, forKey: .initialAppState) ?? [:]
        tabBarComponents = try c.decodeIfPresent([ComponentNode].self, forKey: .tabBarComponents) ?? []
        drawerComponents = try c.decodeIfPresent([ComponentNode].self, forKey: .drawerComponents) ?? []
        flows = try c.decodeIfPresent([NavFlow].self, forKey: .flows) ?? []
        raw = try JSONValue(from: decoder)
        rawBody = nil
    }
}

/// One tab of the tab bar; `initialRoute` has its leading slash (`/home`).
public struct TabDef: Decodable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var icon: String
    public var initialRoute: String

    public init(id: String, label: String, icon: String, initialRoute: String) {
        self.id = id
        self.label = label
        self.icon = icon
        self.initialRoute = initialRoute
    }
}

/// One drawer entry.
public struct DrawerItemDef: Decodable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var icon: String?
    public var route: String

    public init(id: String, label: String, icon: String? = nil, route: String) {
        self.id = id
        self.label = label
        self.icon = icon
        self.route = route
    }
}

/// A flow's routes. A static flow also carries its pre-rendered pages, keyed
/// by page path, for offline use.
public struct NavFlow: Decodable, Equatable, Sendable {
    public var name: String
    public var version: Int?
    public var isStatic: Bool
    public var routes: [NavRoute]
    public var pages: [String: PageResponse]?

    public init(name: String, version: Int? = nil, isStatic: Bool = false, routes: [NavRoute] = [],
                pages: [String: PageResponse]? = nil) {
        self.name = name
        self.version = version
        self.isStatic = isStatic
        self.routes = routes
        self.pages = pages
    }

    private enum CodingKeys: String, CodingKey { case name, version, isStatic, routes, pages }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        version = try c.decodeIfPresent(Int.self, forKey: .version)
        isStatic = try c.decodeIfPresent(Bool.self, forKey: .isStatic) ?? false
        routes = try c.decodeIfPresent([NavRoute].self, forKey: .routes) ?? []
        pages = try c.decodeIfPresent([String: PageResponse].self, forKey: .pages)
    }
}

/// One route. `path` has no leading slash (`home`), and a child carries its
/// full path (`home/product/:id`).
public struct NavRoute: Decodable, Equatable, Sendable {
    public var path: String
    public var children: [NavRoute]
    public var redirect: RedirectRule?
    public var transition: RouteTransitionDef?
    public var isDynamic: Bool

    public init(path: String, children: [NavRoute] = [], redirect: RedirectRule? = nil,
                transition: RouteTransitionDef? = nil, isDynamic: Bool = false) {
        self.path = path
        self.children = children
        self.redirect = redirect
        self.transition = transition
        self.isDynamic = isDynamic
    }

    private enum CodingKeys: String, CodingKey { case path, children, redirect, transition, isDynamic }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decode(String.self, forKey: .path)
        children = try c.decodeIfPresent([NavRoute].self, forKey: .children) ?? []
        redirect = try c.decodeIfPresent(RedirectRule.self, forKey: .redirect)
        transition = try c.decodeIfPresent(RouteTransitionDef.self, forKey: .transition)
        isDynamic = try c.decodeIfPresent(Bool.self, forKey: .isDynamic) ?? false
    }
}

/// Go to `to` when app state `when` equals `equals`.
public struct RedirectRule: Decodable, Equatable, Sendable {
    public var when: String
    public var equals: JSONValue
    public var to: String

    public init(when: String, equals: JSONValue, to: String) {
        self.when = when
        self.equals = equals
        self.to = to
    }

    private enum CodingKeys: String, CodingKey { case when, equals, to }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        when = try c.decode(String.self, forKey: .when)
        // Dart reads `json['equals']` as is: absent or null compares to null.
        equals = try c.decodeIfPresent(JSONValue.self, forKey: .equals) ?? .null
        to = try c.decode(String.self, forKey: .to)
    }
}

/// A route's page transition; `duration` is in milliseconds.
public struct RouteTransitionDef: Decodable, Equatable, Sendable {
    public var type: String
    public var duration: Int
    public var curve: String

    public init(type: String, duration: Int = 300, curve: String = "easeInOut") {
        self.type = type
        self.duration = duration
        self.curve = curve
    }

    private enum CodingKeys: String, CodingKey { case type, duration, curve }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration) ?? 300
        curve = try c.decodeIfPresent(String.self, forKey: .curve) ?? "easeInOut"
    }
}
