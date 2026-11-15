import Foundation

/// What the deep link callback receives, once per link, after the navigation
/// settled. The fields of Dart `OrcaDeeplinkEvent`
/// (sdk/lib/src/navigation/deeplink_event.dart) with the native contract of
/// schema/fixtures/navigation/README.md, "Links": the fixture's `expected`,
/// not Flutter's quirks.
public struct DeeplinkEvent: Equatable, Sendable {
    /// The link as the platform delivered it.
    public var incoming: URL
    /// The final location, path and query: the link's location, or the
    /// redirect rule's target.
    public var resolvedLocation: String
    /// Path params of the matched route, percent-decoded; empty on the
    /// not-found screen.
    public var pathParameters: [String: String]
    /// Query parameters of the final location, decoded.
    public var queryParameters: [String: String]
    /// A redirect rule sent the link to another path. A trailing slash or an
    /// empty path in the link is not a redirect.
    public var wasRedirected: Bool
    /// The link is what opened the app.
    public var isColdStart: Bool

    public init(incoming: URL, resolvedLocation: String, pathParameters: [String: String] = [:],
                queryParameters: [String: String] = [:], wasRedirected: Bool = false, isColdStart: Bool = false) {
        self.incoming = incoming
        self.resolvedLocation = resolvedLocation
        self.pathParameters = pathParameters
        self.queryParameters = queryParameters
        self.wasRedirected = wasRedirected
        self.isColdStart = isColdStart
    }
}

/// What `TabShell.open(link:appState:)` did.
public struct DeepLinkNavigation: Equatable, Sendable {
    /// What the link's location resolved to, also when nothing changed.
    public var resolution: RouteResolution
    /// What the shell changed; nothing when the location was on screen.
    public var change: TabShellChange

    public init(resolution: RouteResolution, change: TabShellChange) {
        self.resolution = resolution
        self.change = change
    }
}

/// Deep links, the pure part: a URL the platform hands to the app becomes a
/// location, the app goes there, and the callback gets a `DeeplinkEvent`.
/// schema/fixtures/navigation/15_deep_links.json is the spec.
public enum DeepLink {
    /// The location of a link: its path and its query, nothing else. Scheme,
    /// host (with user info and port) and fragment are dropped; an empty
    /// path is `/`; trailing slashes are dropped; the query is kept as
    /// given, an empty one is dropped. Nothing is decoded or encoded.
    ///
    /// The text is split as RFC 3986 splits a URI reference, by hand, so
    /// every scheme reads alike: `orcashop://settings` has host `settings`
    /// and location `/`; `orcashop://open/settings`, `orcashop:settings`,
    /// `/settings` and `settings` are all `/settings`. A location is its own
    /// location.
    public static func location(of link: String) -> String {
        var rest = Substring(link)
        if let hash = rest.firstIndex(of: "#") { rest = rest[..<hash] }
        var query: Substring = ""
        if let mark = rest.firstIndex(of: "?") {
            query = rest[rest.index(after: mark)...]
            rest = rest[..<mark]
        }
        if let colon = rest.firstIndex(of: ":"), isScheme(rest[..<colon]) {
            rest = rest[rest.index(after: colon)...]
        }
        if rest.hasPrefix("//") {
            rest = rest.dropFirst(2)
            rest = rest.firstIndex(of: "/").map { rest[$0...] } ?? ""
        }
        while rest.hasSuffix("/") { rest = rest.dropLast() }
        let path = rest.hasPrefix("/") ? String(rest) : "/" + rest
        return query.isEmpty ? path : path + "?" + query
    }

    /// The location of a link the platform delivered as a `URL`: that of its
    /// `absoluteString`.
    public static func location(of link: URL) -> String {
        location(of: link.absoluteString)
    }

    /// The event of a link, from what its location resolved to:
    /// `table.resolve(DeepLink.location(of: link), appState:)`, or the
    /// `resolution` of `TabShell.open(link:appState:)`.
    public static func event(link: URL, resolution: RouteResolution, coldStart: Bool) -> DeeplinkEvent {
        DeeplinkEvent(incoming: link, resolvedLocation: resolution.location, pathParameters: resolution.params,
                      queryParameters: resolution.queryParameters, wasRedirected: resolution.redirected,
                      isColdStart: coldStart)
    }

    /// RFC 3986 `scheme`: a letter, then letters, digits, `+`, `-` or `.`.
    private static func isScheme(_ text: Substring) -> Bool {
        guard let first = text.unicodeScalars.first, isLetter(first) else { return false }
        return text.unicodeScalars.allSatisfy { isLetter($0) || ("0"..."9").contains($0) || "+-.".unicodeScalars.contains($0) }
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }
}

extension TabShell {
    /// Open a link's location (`DeepLink.location(of:)`): a `go`, so the
    /// stack and the tab come from the config and the asked route's redirect
    /// rule is applied once. On a fresh shell this is the boot of a cold
    /// link: the app starts at the link, not at the initial route. When the
    /// link ends on the location already on screen, itself or by its
    /// redirect, nothing changes and nothing is requested; the resolution is
    /// returned all the same, for the event.
    public mutating func open(link location: String, appState: [String: JSONValue]) -> DeepLinkNavigation {
        let resolution = table.resolve(location.hasPrefix("/") ? location : "/" + location, appState: appState)
        if !visible.isEmpty, resolution.location == self.location {
            return DeepLinkNavigation(resolution: resolution,
                                      change: TabShellChange(requested: [], dropped: [], tabIndexWrite: nil))
        }
        return DeepLinkNavigation(resolution: resolution, change: go(location, appState: appState))
    }
}
