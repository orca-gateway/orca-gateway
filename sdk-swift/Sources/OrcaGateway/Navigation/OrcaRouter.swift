#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// One page on the navigation stack: a server path such as `home` or
/// `product`. Each push is a new route, so the same path twice is two pages.
public struct OrcaRoute: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let path: String

    public init(_ path: String) {
        id = UUID()
        // Routes arrive as "about" or "/about"; the page URL wants no slash.
        var trimmed = Substring(path)
        while trimmed.hasPrefix("/") { trimmed = trimmed.dropFirst() }
        self.path = String(trimmed)
    }
}

/// The navigation stack of an Orca app, the Swift side of Flutter's GoRouter
/// wiring (sdk/lib/src/navigation/navigation_handler.dart):
/// - every route is its own page fetch with its own page state;
/// - app state is one shared scope, sent with each page request;
/// - `navigate` pushes, `navigate` with `replace` goes to the route as the
///   only page (GoRouter `go`), and `goBack` pops.
@MainActor
public final class OrcaRouter: ObservableObject {
    /// The page under every pushed route.
    @Published public private(set) var root: OrcaRoute
    /// Pushed routes, bottom to top: the `NavigationStack` path.
    @Published public var stack: [OrcaRoute] = [] {
        didSet { routesChanged() }
    }

    public let client: OrcaClient
    public var system: SystemActions
    /// The shared app scope, as the latest page left it.
    public private(set) var appState: [String: JSONValue] = [:]
    /// Called with every effect a page reports, for DevTools and logging.
    public var onEffect: ((ActionEffect) -> Void)?

    private var loaders: [UUID: OrcaPageLoader] = [:]

    /// `system` defaults to the device's own handlers (`SystemActions.live`).
    public init(client: OrcaClient, path: String = "home", system: SystemActions? = nil) {
        self.client = client
        self.system = system ?? .live
        self.root = OrcaRoute(path)
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
        if replace {
            root = OrcaRoute(path)
            stack = []
        } else {
            stack.append(OrcaRoute(path))
        }
    }

    public func goBack() {
        guard !stack.isEmpty else { return }
        stack.removeLast()
    }

    /// Wire a page that just loaded: its commits keep the shared app scope,
    /// its navigation and system effects come here, its effects are reported.
    func attach(_ model: OrcaPageModel) {
        // The page seeded its own app definitions; they are shared from now.
        appState = model.store.state.app
        model.store.onCommit = { [weak self] state in self?.appState = state.app }
        model.onEffect = { [weak self] effect in self?.onEffect?(effect) }
        model.effectHandler = { [weak self] effect in
            guard let self, !self.perform(effect) else { return }
            self.system.perform(effect)
        }
    }

    /// Drop loaders of routes that left the stack (a back swipe changes the
    /// path directly), and hand the page now on top the latest app scope.
    private func routesChanged() {
        let live = Set(stack.map(\.id) + [root.id])
        loaders = loaders.filter { live.contains($0.key) }
        if case .loaded(let model)? = loaders[top.id]?.phase, model.store.state.app != appState {
            var state = model.store.state
            state.app = appState
            model.store.commit(state)
        }
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
