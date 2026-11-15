import Foundation

/// Where a location ends up: a page to request, or the error screen.
public enum RouteResolutionKind: String, Sendable {
    case page, error
}

/// The outcome of `RouteTable.resolve`, with the fields of a navigation
/// fixture's `expected` (schema/fixtures/navigation/README.md). For kind
/// `error` only `kind`, `location`, `redirected` and `queryParameters` say
/// anything: no page is requested.
public struct RouteResolution: Equatable, Sendable {
    public var kind: RouteResolutionKind
    /// The final location. Not redirected: the asked one, query included.
    /// Redirected: the rule's target as written.
    public var location: String
    /// The final path differs from the asked path.
    public var redirected: Bool
    /// Page request path of the top page: the matched location without its
    /// leading slash and without the query.
    public var pagePath: String?
    /// The full matched pattern (`/product/:id`): a slash, then the segments
    /// of the matched chain joined by slashes.
    public var routePath: String?
    /// Path params of every matched level, percent-decoded.
    public var params: [String: String]
    /// Page request paths bottom to top: the parent chain, then the page.
    public var stack: [String]
    /// Index into `config.tabs` when the route sits in a tab.
    public var tabIndex: Int?
    /// Fallback title of a route drawn over the tabs with a title bar; nil
    /// when the page is not wrapped.
    public var scaffoldTitle: String?
    /// The matched route's transition, as the config carries it.
    public var transition: RouteTransitionDef?
    /// Query parameters of the final location, decoded; a repeated key keeps
    /// its last value.
    public var queryParameters: [String: String]

    public init(kind: RouteResolutionKind, location: String, redirected: Bool = false, pagePath: String? = nil,
                routePath: String? = nil, params: [String: String] = [:], stack: [String] = [],
                tabIndex: Int? = nil, scaffoldTitle: String? = nil, transition: RouteTransitionDef? = nil,
                queryParameters: [String: String] = [:]) {
        self.kind = kind
        self.location = location
        self.redirected = redirected
        self.pagePath = pagePath
        self.routePath = routePath
        self.params = params
        self.stack = stack
        self.tabIndex = tabIndex
        self.scaffoldTitle = scaffoldTitle
        self.transition = transition
        self.queryParameters = queryParameters
    }
}

/// The routes of a `NavConfig`, laid out as Flutter's
/// `NavigationHandler.buildRouter` (sdk/lib/src/navigation/navigation_handler.dart)
/// hands them to GoRouter, and resolved by GoRouter's rules. Pure: no page is
/// fetched and no state is written. The navigation fixtures
/// (schema/fixtures/navigation) are the spec.
///
/// - Routes of all flows are flattened in flow order; the first match wins.
/// - With tabs, each tab's branch comes first (the routes whose path equals
///   the tab's `initialRoute` or lies under it plus `/`; a tab with none gets
///   one at its `initialRoute`), then the routes whose path starts with no
///   tab's `initialRoute` as a plain string. `homework` beside tab `/home` is
///   in neither list: unreachable.
/// - A child is matched under its parent, and the parent chain is the stack.
/// - The redirect rule is looked up as `_findRouteByPath` does and applied
///   once: the target's own rule is not evaluated.
public struct RouteTable: Sendable {
    public let config: NavConfig

    /// One GoRoute: `segments` are relative to the parent.
    private struct Node: Sendable {
        var segments: [String]
        var transition: RouteTransitionDef?
        var children: [Node]
    }

    /// A top-level GoRoute, in match order.
    private struct Entry: Sendable {
        var node: Node
        var tabIndex: Int?
        var scaffoldTitle: String?
    }

    /// One line of the `_findRouteByPath` walk: a node before its children.
    private struct Rule: Sendable {
        var segments: [String]
        var redirect: RedirectRule?
    }

    private let entries: [Entry]
    private let rules: [Rule]

    public init(_ config: NavConfig) {
        self.config = config
        let all = config.flows.flatMap(\.routes)
        var entries: [Entry] = []

        if config.tabs.isEmpty {
            entries = all.map { Entry(node: Self.node($0, parent: ""), tabIndex: nil, scaffoldTitle: nil) }
        } else {
            for (index, tab) in config.tabs.enumerated() {
                // `_findTabRoutes`.
                let tabPath = Self.slashed(tab.initialRoute)
                let own = all.filter {
                    let path = Self.slashed($0.path)
                    return path == tabPath || path.hasPrefix(tabPath + "/")
                }
                if own.isEmpty {
                    let node = Node(segments: Self.segments(tabPath), transition: nil, children: [])
                    entries.append(Entry(node: node, tabIndex: index, scaffoldTitle: nil))
                } else {
                    entries += own.map { Entry(node: Self.node($0, parent: ""), tabIndex: index, scaffoldTitle: nil) }
                }
            }
            // The routes outside every tab, drawn over the shell with a title
            // bar. The prefix test has no slash boundary, as in Dart.
            var drawerLabels: [String: String] = [:]
            for item in config.drawerItems { drawerLabels[item.route] = item.label }
            for route in all {
                let path = Self.slashed(route.path)
                if config.tabs.contains(where: { path.hasPrefix($0.initialRoute) }) { continue }
                let title = drawerLabels[path] ?? Self.fallbackTitle(path)
                entries.append(Entry(node: Self.node(route, parent: ""), tabIndex: nil, scaffoldTitle: title))
            }
        }
        self.entries = entries

        var rules: [Rule] = []
        func walk(_ routes: [NavRoute]) {
            for route in routes {
                rules.append(Rule(segments: Self.segments(route.path), redirect: route.redirect))
                walk(route.children)
            }
        }
        walk(all)
        self.rules = rules
    }

    /// Resolve `location` (leading slash, query allowed) against the routes,
    /// with `appState` as the state the redirect rules read. To boot an app:
    /// `resolve(config.initialRoute, appState: config.initialAppState)`.
    public func resolve(_ location: String, appState: [String: JSONValue]) -> RouteResolution {
        let asked = Self.split(location)
        var final = location
        var parts = asked

        // GoRouter's top-level redirect: once per navigation, on the asked
        // location whether or not it matches a route, and only when the
        // target is another location string.
        let askedSegments = Self.segments(asked.path)
        if let rule = rules.first(where: { Self.matches($0.segments, askedSegments) })?.redirect,
           Self.dartEquals(appState[rule.when] ?? .null, rule.equals), rule.to != location {
            final = rule.to
            parts = Self.split(final)
        }
        let redirected = parts.path != asked.path
        let query = Self.queryParameters(parts.query)

        let segments = Self.segments(parts.path)
        for entry in entries {
            var params: [String: String] = [:]
            guard let chain = Self.match(entry.node, segments, from: 0, params: &params), let top = chain.last else {
                continue
            }
            let stack = chain.map { segments[0..<$0.end].joined(separator: "/") }
            return RouteResolution(
                kind: .page, location: final, redirected: redirected, pagePath: stack.last,
                routePath: "/" + chain.flatMap(\.node.segments).joined(separator: "/"), params: params, stack: stack, tabIndex: entry.tabIndex,
                // `scaffoldTitle` is not passed down to children.
                scaffoldTitle: chain.count == 1 ? entry.scaffoldTitle : nil,
                transition: top.node.transition, queryParameters: query)
        }
        return RouteResolution(kind: .error, location: final, redirected: redirected, queryParameters: query)
    }

    // MARK: - Building

    /// `_buildGoRoute`: a child under `parent + "/"` is relative to it;
    /// any other path is kept whole.
    private static func node(_ route: NavRoute, parent: String) -> Node {
        let full = slashed(route.path)
        let relative = !parent.isEmpty && full.hasPrefix(parent + "/")
            ? String(full.dropFirst(parent.count + 1)) : full
        return Node(segments: segments(relative), transition: route.transition,
                    children: route.children.map { node($0, parent: full) })
    }

    /// Drawer label aside, the title of a non-tab route: its last segment
    /// with the first letter upper-cased, or the one before a trailing
    /// `:param`. As Dart's `seg[0].toUpperCase() + seg.substring(1)`: the
    /// first UTF-16 unit alone, so a segment that starts with a surrogate
    /// (a non-BMP character) stays as it is, and `ß` becomes `SS`.
    private static func fallbackTitle(_ path: String) -> String {
        let parts = segments(path)
        guard var pick = parts.last else { return "" }
        if pick.hasPrefix(":"), parts.count >= 2 { pick = parts[parts.count - 2] }
        let units = Array(pick.utf16)
        guard let first = units.first, !UTF16.isLeadSurrogate(first), !UTF16.isTrailSurrogate(first) else {
            return pick
        }
        return String(decoding: [first], as: UTF16.self).uppercased()
            + String(decoding: units.dropFirst(), as: UTF16.self)
    }

    private static func slashed(_ path: String) -> String {
        path.hasPrefix("/") ? path : "/" + path
    }

    private static func segments(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    // MARK: - Matching

    /// `_pathMatches`: equal segment counts, a `:name` segment matches any.
    private static func matches(_ pattern: [String], _ location: [String]) -> Bool {
        pattern.count == location.count
            && zip(pattern, location).allSatisfy { $0.hasPrefix(":") || $0 == $1 }
    }

    /// GoRouter's match of one route: its segments against the location from
    /// `from`, then nothing left, or a child for the rest. Returns the chain
    /// parent to leaf with where each level's location ends.
    private static func match(_ node: Node, _ location: [String], from: Int,
                              params: inout [String: String]) -> [(node: Node, end: Int)]? {
        let end = from + node.segments.count
        guard end <= location.count else { return nil }
        var found = params
        for (offset, segment) in node.segments.enumerated() {
            let value = location[from + offset]
            if segment.hasPrefix(":") {
                found[String(segment.dropFirst())] = value.removingPercentEncoding ?? value
            } else if segment != value {
                return nil
            }
        }
        if end == location.count {
            params = found
            return [(node, end)]
        }
        for child in node.children {
            var inner = found
            if let rest = match(child, location, from: end, params: &inner) {
                params = inner
                return [(node, end)] + rest
            }
        }
        return nil
    }

    /// Dart `==` on decoded JSON: scalars by value (`0 == 0.0`), a missing
    /// key as null, and a list or a map equal to nothing but itself.
    private static func dartEquals(_ a: JSONValue, _ b: JSONValue) -> Bool {
        switch a {
        case .array, .object: return false
        default: return a == b
        }
    }

    // MARK: - Locations

    /// Path and query of a location; a `#fragment` belongs to neither.
    private static func split(_ location: String) -> (path: String, query: String) {
        let text = location.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let parts = text.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        return (String(parts.first ?? ""), parts.count > 1 ? String(parts[1]) : "")
    }

    /// Dart `Uri.queryParameters`: `+` is a space, the last of a repeated key
    /// stays, a key without `=` has an empty value.
    private static func queryParameters(_ query: String) -> [String: String] {
        var out: [String: String] = [:]
        func decode(_ part: Substring) -> String {
            let spaced = part.replacingOccurrences(of: "+", with: " ")
            return spaced.removingPercentEncoding ?? spaced
        }
        for pair in query.split(separator: "&", omittingEmptySubsequences: true) {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            out[decode(kv[0])] = kv.count > 1 ? decode(kv[1]) : ""
        }
        return out
    }
}
