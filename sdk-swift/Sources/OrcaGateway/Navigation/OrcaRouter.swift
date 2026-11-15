#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// One page on the navigation stack: a server path such as `home` or
/// `product/42`. Each push is a new route, so the same path twice is two pages.
public struct OrcaRoute: Hashable, Identifiable, Sendable {
    public let id: UUID
    /// The page request path: no leading slash, no query.
    public let path: String
    /// The full location, with its leading slash and its query.
    public let location: String
    /// Fallback title of a route drawn with a title bar (a route outside the
    /// tabs of a config with tabs); nil when the page is not wrapped.
    public let scaffoldTitle: String?
    /// No route matches the location: show "Page not found", fetch nothing.
    public let isNotFound: Bool
    /// The matched route's transition, as the config carries it.
    public let transition: RouteTransitionDef?

    /// `location` defaults to the path with a leading slash.
    public init(_ path: String, location: String? = nil, scaffoldTitle: String? = nil,
                isNotFound: Bool = false, transition: RouteTransitionDef? = nil) {
        id = UUID()
        // Routes arrive as "about" or "/about"; the page URL wants no slash.
        var trimmed = Substring(path)
        while trimmed.hasPrefix("/") { trimmed = trimmed.dropFirst() }
        self.path = String(trimmed)
        self.location = location ?? "/" + trimmed
        self.scaffoldTitle = scaffoldTitle
        self.isNotFound = isNotFound
        self.transition = transition
    }

    public static func == (a: OrcaRoute, b: OrcaRoute) -> Bool { a.id == b.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The navigation stack of an Orca app, the Swift side of Flutter's GoRouter
/// wiring (sdk/lib/src/navigation/navigation_handler.dart):
/// - every route is its own page fetch with its own page state;
/// - app state is one shared scope, sent with each page request;
/// - `navigate` pushes, `navigate` with `replace` goes to the route (GoRouter
///   `go`), and `goBack` pops.
///
/// Made with a `NavConfig`, locations are resolved through its `RouteTable`:
/// redirect rules apply, a nested route is shown over its parents, and an
/// unknown location is a "not found" route. Made with a path, every path is
/// a page.
@MainActor
public final class OrcaRouter: ObservableObject {
    /// The page under every pushed route.
    @Published public private(set) var root: OrcaRoute
    /// Pushed routes, bottom to top: the `NavigationStack` path.
    @Published public var stack: [OrcaRoute] = [] {
        didSet { routesChanged(from: oldValue.count) }
    }

    public let client: OrcaClient
    public var system: SystemActions
    /// The shared app scope, as the latest page or the host left it.
    public private(set) var appState: [String: JSONValue] = [:]
    /// Called with every effect a page reports, for DevTools and logging.
    public var onEffect: ((ActionEffect) -> Void)?
    /// Called once per change of the location on top, after any redirect
    /// (Flutter `OrcaApp.onRouteChanged`): `push` for `navigate`, `replace`
    /// for `navigate` with `replace`, `pop` for `goBack` and a back swipe.
    /// The same location again gives no event. The boot event (no previous
    /// location, `push`) goes to the callback given to `init`.
    public var onRouteChanged: ((RouteChangeEvent) -> Void)?
    /// The routes of the config the router was made with; nil without one.
    public let table: RouteTable?

    private var loaders: [UUID: OrcaPageLoader] = [:]
    /// The location last reported, and how the change under way began.
    private var lastLocation: String
    private var pendingType: RouteChangeType?

    /// Every path is a page, starting at `path`.
    /// `system` defaults to the device's own handlers (`SystemActions.live`).
    public init(client: OrcaClient, path: String = "home", system: SystemActions? = nil) {
        self.client = client
        self.system = system ?? .live
        self.table = nil
        let root = OrcaRoute(path)
        self.root = root
        self.lastLocation = root.location
    }

    /// Boot from the server's config (`OrcaClient.fetchConfig`), as Flutter's
    /// `OrcaApp._initRouter`: seed `initialAppState`, then show
    /// `initialRoute` resolved against it, the page chain as root + stack.
    public init(client: OrcaClient, config: NavConfig, system: SystemActions? = nil,
                onRouteChanged: ((RouteChangeEvent) -> Void)? = nil) {
        self.client = client
        self.system = system ?? .live
        let table = RouteTable(config)
        self.table = table
        self.appState = config.initialAppState
        self.onRouteChanged = onRouteChanged
        let routes = Self.routes(
            table.resolve(Self.slashed(config.initialRoute), appState: config.initialAppState))
        self.root = routes[0]
        self.stack = Array(routes.dropFirst())
        self.lastLocation = routes[routes.count - 1].location
        onRouteChanged?(RouteChangeEvent(location: lastLocation, previousLocation: nil, type: .push))
    }

    /// The loader of a route, made the first time it is asked for.
    public func loader(for route: OrcaRoute) -> OrcaPageLoader {
        if let existing = loaders[route.id] { return existing }
        let loader = OrcaPageLoader(client: client, path: route.path, router: self)
        loaders[route.id] = loader
        return loader
    }

    /// The route on top: the one a user is looking at.
    public var top: OrcaRoute { stack.last ?? root }

    public func navigate(to path: String, replace: Bool = false) {
        guard !path.isEmpty else { return }
        var routes = [OrcaRoute(path)]
        if let table {
            routes = Self.routes(table.resolve(Self.slashed(path), appState: appState))
            // A push adds one page, the one asked for; `go` shows its chain.
            if !replace { routes = [routes[routes.count - 1]] }
        }
        if replace {
            pendingType = .replace
            root = routes[0]
            stack = Array(routes.dropFirst())
        } else {
            pendingType = .push
            stack.append(routes[0])
        }
    }

    public func goBack() {
        guard !stack.isEmpty else { return }
        pendingType = .pop
        stack.removeLast()
    }

    /// Write one app state key from the host. See `setAppState(_:)`.
    public func setAppState(_ key: String, _ value: JSONValue) {
        setAppState([key: value])
    }

    /// Write app state from the host: the shared scope takes the values, and
    /// so does the store of every page loaded so far, so widgets watching a
    /// key redraw. A page loaded later starts from the new scope.
    public func setAppState(_ values: [String: JSONValue]) {
        appState.merge(values) { _, new in new }
        let scope = appState
        for loader in loaders.values {
            guard case .loaded(let model) = loader.phase, model.store.state.app != scope else { continue }
            var state = model.store.state
            state.app = scope
            model.store.commit(state)
        }
    }

    /// The routes of a resolution, bottom to top: its page chain, of which
    /// only the top carries the location's query, title and transition; or
    /// one "not found" route.
    private static func routes(_ resolution: RouteResolution) -> [OrcaRoute] {
        guard resolution.kind == .page, let top = resolution.stack.last else {
            let path = resolution.location.split(
                separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            return [OrcaRoute(String(path), location: resolution.location, isNotFound: true)]
        }
        return resolution.stack.dropLast().map { OrcaRoute($0) } + [
            OrcaRoute(top, location: resolution.location, scaffoldTitle: resolution.scaffoldTitle,
                      transition: resolution.transition)
        ]
    }

    private static func slashed(_ location: String) -> String {
        location.hasPrefix("/") ? location : "/" + location
    }

    /// Wire a page that just loaded: its commits keep the shared app scope,
    /// its navigation and system effects come here, its effects are reported.
    func attach(_ model: OrcaPageModel) {
        // The page seeded its own app definitions; they are shared from now.
        // The scope may have moved on while the page was fetched (the host
        // or another page wrote): those values stay, and what the page
        // seeded fills only the keys still unset.
        var scope = appState
        for (key, value) in model.store.state.app where (scope[key] ?? .null).isNull {
            scope[key] = value
        }
        appState = scope
        if model.store.state.app != scope {
            var state = model.store.state
            state.app = scope
            model.store.commit(state)
        }
        model.store.onCommit = { [weak self] state in self?.appState = state.app }
        model.onEffect = { [weak self] effect in self?.onEffect?(effect) }
        model.effectHandler = { [weak self] effect in
            guard let self, !self.perform(effect) else { return }
            self.system.perform(effect)
        }
    }

    /// Drop loaders of routes that left the stack (a back swipe changes the
    /// path directly), hand the page now on top the latest app scope, and
    /// report the location on top when it changed.
    private func routesChanged(from oldCount: Int) {
        let live = Set(stack.map(\.id) + [root.id])
        loaders = loaders.filter { live.contains($0.key) }
        if case .loaded(let model)? = loaders[top.id]?.phase, model.store.state.app != appState {
            var state = model.store.state
            state.app = appState
            model.store.commit(state)
        }
        // A change that `navigate` and `goBack` did not start came through
        // the `NavigationStack` path: a back swipe when the stack shrank.
        let type = pendingType ?? (stack.count < oldCount ? .pop : .push)
        pendingType = nil
        let location = top.location
        guard location != lastLocation else { return }
        let previous = lastLocation
        lastLocation = location
        onRouteChanged?(RouteChangeEvent(location: location, previousLocation: previous, type: type))
    }

    /// Perform a navigation effect; false for any other effect.
    @discardableResult
    func perform(_ effect: ActionEffect) -> Bool {
        switch effect.type {
        case "navigate":
            navigate(to: effect.payload["route"]?.stringValue ?? "",
                     replace: effect.payload["replace"]?.boolValue ?? false)
        case "goBack":
            goBack()
        default:
            return false
        }
        return true
    }
}
#endif
