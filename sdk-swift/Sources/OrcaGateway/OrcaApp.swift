#if canImport(SwiftUI)
import SwiftUI

/// One page with its snackbar and toast overlay. Put it inside a
/// NavigationStack (OrcaApp does) so a Scaffold's AppBar becomes the
/// navigation bar.
@MainActor
public struct OrcaPageView: View {
    @ObservedObject var model: OrcaPageModel

    public init(model: OrcaPageModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if let root = model.renderer.rootId {
                NodeView(id: root, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { model.appeared() }
        .overlay(alignment: .bottom) { ToastView(model: model) }
        .animation(.easeInOut(duration: 0.2), value: model.toast)
    }
}

/// The snackbar or toast at the bottom; it leaves after its duration.
@MainActor
private struct ToastView: View {
    @ObservedObject var model: OrcaPageModel

    var body: some View {
        if let toast = model.toast {
            let snackbar = toast.style == .snackbar
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: snackbar ? .infinity : nil, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: snackbar ? 6 : 22)
                        .fill(Color(white: 0.18)))
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("orca.toast")
                .task(id: toast.id) {
                    try? await Task.sleep(nanoseconds: UInt64(max(0, toast.duration) * 1_000_000_000))
                    if model.toast?.id == toast.id { model.toast = nil }
                }
        }
    }
}

/// Loads a page through OrcaClient and keeps the result. Under a router the
/// fetch carries the shared app state, and the page joins the router.
@MainActor
public final class OrcaPageLoader: ObservableObject {
    public enum Phase {
        case loading
        case loaded(OrcaPageModel)
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .loading
    public let client: OrcaClient
    public let path: String
    private weak var router: OrcaRouter?
    private var started = false

    public init(client: OrcaClient, path: String, router: OrcaRouter? = nil) {
        self.client = client
        self.path = path
        self.router = router
    }

    /// Fetch once; `reload()` fetches again.
    public func loadIfNeeded() async {
        guard !started else { return }
        await reload()
    }

    public func reload() async {
        started = true
        phase = .loading
        var client = self.client
        if client.device == DeviceInfo() { client.device = .current() }
        let app = router?.appState ?? [:]
        do {
            let (page, timing) = try await client.fetchPageTimed(path, appState: app)
            let renderStart = timing.elapsed()
            let model = OrcaPageModel(page: page, store: ElmStore(app: app), client: client)
            router?.attach(model)
            let renderComplete = timing.elapsed()
            let path = self.path
            model.onFirstAppear = {
                OrcaDebug.report(timing.event(
                    pageId: page.pageId, path: path, renderStartMs: renderStart,
                    renderCompleteMs: renderComplete, firstFrameMs: timing.elapsed()))
            }
            phase = .loaded(model)
        } catch OrcaClientError.http(let status, let body) {
            phase = .failed("HTTP \(status): \(body.prefix(200))")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// How an `OrcaApp` starts. With a path (`home` when none is given) the
/// router is ready at once and nothing is fetched here. With `path: nil` the
/// app boots from the server config, as Flutter's `OrcaApp._initializeOnlineOnly`: `fetchConfig`, then a router
/// seeded with `initialAppState` showing `initialRoute`.
@MainActor
public final class OrcaAppBoot: ObservableObject {
    public enum Phase {
        case loading
        case ready(OrcaRouter)
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .loading
    public let client: OrcaClient
    private let system: SystemActions?
    private let onRouteChanged: ((RouteChangeEvent) -> Void)?
    private var started = false

    /// `path` defaults to `home`. An explicit `path: nil` boots from the
    /// config: call `startIfNeeded()`.
    public init(client: OrcaClient, path: String? = "home", system: SystemActions? = nil,
                onRouteChanged: ((RouteChangeEvent) -> Void)? = nil) {
        self.client = client
        self.system = system
        self.onRouteChanged = onRouteChanged
        if let path {
            let router = OrcaRouter(client: client, path: path, system: system)
            router.onRouteChanged = onRouteChanged
            started = true
            phase = .ready(router)
        }
    }

    /// A router the host made: ready at once.
    public init(router: OrcaRouter) {
        client = router.client
        system = nil
        onRouteChanged = nil
        started = true
        phase = .ready(router)
    }

    /// Fetch the config once; `retry()` fetches again after a failure.
    public func startIfNeeded() async {
        guard !started else { return }
        started = true
        await fetch()
    }

    /// Fetch the config again. Does nothing once the app is ready.
    public func retry() async {
        if case .ready = phase { return }
        started = true
        phase = .loading
        await fetch()
    }

    private func fetch() async {
        var client = self.client
        if client.device == DeviceInfo() { client.device = .current() }
        do {
            let config = try await client.fetchConfig()
            phase = .ready(OrcaRouter(client: self.client, config: config, system: system,
                                      onRouteChanged: onRouteChanged))
        } catch OrcaClientError.http(let status, let body) {
            phase = .failed("HTTP \(status): \(body.prefix(200))")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// The root view of an Orca-driven app: a NavigationStack of server pages,
/// each with loading and error states. `navigate` pushes a page, `goBack`
/// pops one, and app state is shared by every page on the stack.
///
/// With a `path` no config is fetched and every path is a page. The default
/// is `home`: `OrcaApp(client:)` opens the page `home`, as it always has.
///
/// `path: nil` is the way to get the server's navigation (routes, redirects,
/// initial app state): the app fetches the navigation config first, its
/// `initialRoute` is the first page and its `initialAppState` is seeded
/// before that page is asked for.
///
///     OrcaApp(client: OrcaClient(baseURL: url, appId: "counter", apiKey: "demo-key"))
///     OrcaApp(client: OrcaClient(baseURL: url, appId: "server-actions", apiKey: "demo-key"), path: "shop")
///     OrcaApp(client: OrcaClient(baseURL: url, appId: "navigation", apiKey: "demo-key"), path: nil)
@MainActor
public struct OrcaApp: View {
    @StateObject private var boot: OrcaAppBoot
    @StateObject private var gate: OrcaBootModel

    /// A client without a device id gets the one saved in UserDefaults
    /// (`DeviceIdentity`, made on first run).
    /// - Parameters:
    ///   - path: the first page; nil boots from the server's navigation
    ///     config (see above).
    ///   - enableOffline: run the version check at boot, before the config
    ///     or any page is asked for; a forceUpdate answer shows the
    ///     force-update screen and loads neither. The static-flow cache, the
    ///     saved config and `preload()` arrive with plan step 14.
    ///   - enableSessionTracking: send a session start when the app comes to
    ///     the foreground and an end when it goes to the background.
    ///   - onRouteChanged: told of every route change, the first route included.
    public init(client: OrcaClient, path: String? = "home", system: SystemActions? = nil,
                enableOffline: Bool = false, enableSessionTracking: Bool = false,
                onRouteChanged: ((RouteChangeEvent) -> Void)? = nil) {
        _boot = StateObject(wrappedValue: OrcaAppBoot(
            client: client.identified(by: UserDefaultsKeyValueStore()), path: path, system: system,
            onRouteChanged: onRouteChanged))
        _gate = StateObject(wrappedValue: OrcaBootModel(
            enableOffline: enableOffline, enableSessionTracking: enableSessionTracking))
    }

    /// The router's client is used as the host built it: to send a device
    /// id, set `client.deviceId = DeviceIdentity.resolve(UserDefaultsKeyValueStore())`.
    /// The options are those of `init(client:)`.
    public init(router: @autoclosure @escaping () -> OrcaRouter,
                enableOffline: Bool = false, enableSessionTracking: Bool = false) {
        _boot = StateObject(wrappedValue: OrcaAppBoot(router: router()))
        _gate = StateObject(wrappedValue: OrcaBootModel(
            enableOffline: enableOffline, enableSessionTracking: enableSessionTracking))
    }

    public var body: some View {
        // The gate first: its content, and so the config fetch and every
        // page, exists only once the version check lets the app through.
        OrcaBootView(boot: gate, client: boot.client) {
            switch boot.phase {
            case .loading:
                ProgressView().task { await boot.startIfNeeded() }
            case .ready(let router):
                RouteStack(router: router)
            case .failed(let message):
                LoadError(title: "Could not start the app", message: message) {
                    Task { await boot.retry() }
                }
            }
        }
    }
}

/// The router's pages as a NavigationStack.
@MainActor
private struct RouteStack: View {
    @ObservedObject var router: OrcaRouter

    var body: some View {
        NavigationStack(path: $router.stack) {
            RoutePage(router: router, route: router.root)
                .id(router.root.id)
                .navigationDestination(for: OrcaRoute.self) { route in
                    RoutePage(router: router, route: route)
                }
        }
    }
}

extension OrcaRoute {
    /// The title of the bar this route is drawn with, nil when it has none
    /// (Flutter `OrcaPage._maybeWrapScaffold`): the page's own title once it
    /// has loaded, the route's fallback until then and on an error.
    @MainActor
    func barTitle(_ phase: OrcaPageLoader.Phase) -> String? {
        guard let scaffoldTitle else { return nil }
        if case .loaded(let model) = phase { return model.page.title }
        return scaffoldTitle
    }
}

/// One route: its page, or "Page not found" for a location no route matches
/// (no loader is made for it, so nothing is fetched).
@MainActor
struct RoutePage: View {
    let router: OrcaRouter
    let route: OrcaRoute

    var body: some View {
        if route.isNotFound {
            VStack(spacing: 12) {
                Text("Page not found").font(.headline)
                Text(route.location).font(.footnote).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .accessibilityIdentifier("orca.notFound")
        } else {
            LoadedRoutePage(route: route, loader: router.loader(for: route))
        }
    }
}

/// A route's page: a spinner, the page, or the error with a retry; under a
/// title bar when the route has one.
@MainActor
private struct LoadedRoutePage: View {
    let route: OrcaRoute
    @ObservedObject var loader: OrcaPageLoader

    var body: some View {
        Group {
            switch loader.phase {
            case .loading:
                ProgressView()
            case .loaded(let model):
                OrcaPageView(model: model)
            case .failed(let message):
                LoadError(title: "Could not load this page", message: message) {
                    Task { await loader.reload() }
                }
            }
        }
        .modifier(TitleBar(title: route.barTitle(loader.phase)))
        .task { await loader.loadIfNeeded() }
    }
}

/// The navigation bar of a route outside the tabs: an inline title; the
/// NavigationStack adds the back button when the route is pushed.
private struct TitleBar: ViewModifier {
    let title: String?

    func body(content: Content) -> some View {
        if let title {
            content
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        } else {
            content
        }
    }
}

/// What a failed fetch shows: the reason and a retry.
private struct LoadError: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.headline)
            Text(message).font(.footnote).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
        }
        .padding(24)
    }
}

extension DeviceInfo {
    /// This device: screen and safe area in points, OS version, locale and
    /// time zone, for the `x-orca-*` headers.
    @MainActor
    public static func current() -> DeviceInfo {
        var info = DeviceInfo(osVersion: ProcessInfo.processInfo.operatingSystemVersionString)
        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? "en"
        info.locale = "\(language)_\(locale.region?.identifier ?? "")"
        info.timezone = TimeZone.current.abbreviation() ?? TimeZone.current.identifier
        #if canImport(UIKit) && !os(watchOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
            let screen = scene.screen
            info.screenWidth = screen.bounds.width
            info.screenHeight = screen.bounds.height
            info.pixelDensity = screen.scale
            if let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first {
                let insets = window.safeAreaInsets
                info.safeTop = insets.top
                info.safeBottom = insets.bottom
                info.safeLeft = insets.left
                info.safeRight = insets.right
            }
        }
        #endif
        return info
    }
}
#endif
