#if canImport(SwiftUI)
import SwiftUI

/// One page with its snackbar and toast overlay, and the debug overlay
/// while DevTools runs with `showOverlay` on. Put it inside a
/// NavigationStack (OrcaApp does) so a Scaffold's AppBar becomes the
/// navigation bar.
@MainActor
public struct OrcaPageView: View {
    @ObservedObject var model: OrcaPageModel
    /// The page's load, request start to render complete in ms, from the
    /// loader that fetched it; nil for a page drawn without one.
    let loadTimeMs: Double?

    public init(model: OrcaPageModel) {
        self.init(model: model, loadTimeMs: nil)
    }

    init(model: OrcaPageModel, loadTimeMs: Double?) {
        self.model = model
        self.loadTimeMs = loadTimeMs
    }

    /// The debug overlay this page draws, nil while it is off (Flutter
    /// orca_page.dart:396-403).
    var debugOverlay: DebugOverlay? {
        guard DebugOverlay.isShown else { return nil }
        return DebugOverlay(loadMs: loadTimeMs, components: model.renderer.nodes.count)
    }

    public var body: some View {
        Group {
            if let root = model.renderer.rootId {
                NodeView(id: root, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { model.appeared() }
        .overlay(alignment: .bottomTrailing) { debugOverlay }
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
    /// The loaded page's request start to render complete, in ms (its
    /// timing event's `renderCompleteMs`), for the debug overlay.
    private(set) var loadTimeMs: Double?
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
        loadTimeMs = nil
        var client = self.client
        if client.device == DeviceInfo() { client.device = .current() }
        let app = router?.appState ?? [:]
        do {
            let (page, timing) = try await client.fetchPageTimed(path, appState: app)
            let renderStart = timing.elapsed()
            let model = router?.plugins?.page(page, store: ElmStore(app: app), client: client)
                ?? OrcaPageModel(page: page, store: ElmStore(app: app), client: client)
            router?.attach(model)
            let renderComplete = timing.elapsed()
            let path = self.path
            model.onFirstAppear = {
                OrcaDebug.report(timing.event(
                    pageId: page.pageId, path: path, renderStartMs: renderStart,
                    renderCompleteMs: renderComplete, firstFrameMs: timing.elapsed()))
                if OrcaDebug.isEnabled && OrcaDebug.options.logTimings {
                    OrcaDebug.logTiming(pageId: page.pageId, path: path)
                }
            }
            loadTimeMs = renderComplete
            phase = .loaded(model)
        } catch OrcaClientError.http(let status, let body) {
            phase = .failed("HTTP \(status): \(body.prefix(200))")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// How an `OrcaApp` starts. With a path the router is ready at once and
/// nothing is fetched here. With no path (the default, `path: nil`) the
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
    private let onDeeplink: ((DeeplinkEvent) -> Void)?
    /// OrcaApp's plugins: every router made here is attached to them.
    private let plugins: OrcaPluginHost?
    private var started = false
    /// A deep link that came while there was no router yet (the version
    /// check, the config fetch, a failed boot): the router boots at it.
    private var pendingLink: URL?
    /// No route has appeared and no link was applied yet: the next link the
    /// view receives is the one that opened the app.
    private var awaitsFirstRoute = true
    /// The router is the one made here from the host's `path`.
    private var madeAtPath = false

    /// `path` defaults to nil, the boot from the config: call
    /// `startIfNeeded()`. A path opens that page and fetches no config.
    /// `onDeeplink` is told of every deep link (`handleDeeplink(_:)`).
    public convenience init(client: OrcaClient, path: String? = nil, system: SystemActions? = nil,
                            onRouteChanged: ((RouteChangeEvent) -> Void)? = nil,
                            onDeeplink: ((DeeplinkEvent) -> Void)? = nil) {
        self.init(client: client, path: path, system: system, onRouteChanged: onRouteChanged,
                  onDeeplink: onDeeplink, plugins: nil)
    }

    /// With OrcaApp's plugins: their names are advertised on `client` before
    /// the config is asked for, and the router is attached to them.
    init(client: OrcaClient, path: String?, system: SystemActions?,
         onRouteChanged: ((RouteChangeEvent) -> Void)?, onDeeplink: ((DeeplinkEvent) -> Void)? = nil,
         plugins: OrcaPluginHost?) {
        self.client = client
        self.system = system
        self.onRouteChanged = onRouteChanged
        self.onDeeplink = onDeeplink
        self.plugins = plugins
        plugins?.advertise(on: client)
        if let path {
            let router = OrcaRouter(client: client, path: path, system: system)
            router.onRouteChanged = onRouteChanged
            router.onDeeplink = onDeeplink
            madeAtPath = true
            started = true
            phase = .ready(plugins?.attach(router) ?? router)
        }
    }

    /// A router the host made: ready at once. Its `onDeeplink` is the
    /// host's to set.
    public init(router: OrcaRouter) {
        client = router.client
        system = nil
        onRouteChanged = nil
        onDeeplink = nil
        plugins = nil
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

    /// A deep link reached the app. With a router it goes there, as a link
    /// to a running app (`OrcaRouter.handleDeeplink`, `isColdStart` false);
    /// without one yet it is held, the last one winning, and the router
    /// boots at it instead of the config's `initialRoute`, `isColdStart`
    /// set.
    public func handleDeeplink(_ url: URL) {
        guard case .ready(let router) = phase else {
            pendingLink = url
            return
        }
        awaitsFirstRoute = false
        router.handleDeeplink(url)
    }

    /// A link from `OrcaApp`'s own `.onOpenURL` or
    /// `.onContinueUserActivity`. As `handleDeeplink(_:)`, but iOS may hand
    /// over the launch URL when the router already exists and nothing
    /// showed yet: that one link is the cold start. The router made from the
    /// host's `path` then starts at it (no route event, the path never
    /// requested); a config's or the host's router goes to it.
    func receive(_ url: URL) {
        guard case .ready(let router) = phase, awaitsFirstRoute else { return handleDeeplink(url) }
        awaitsFirstRoute = false
        if madeAtPath { router.start(at: url) } else { router.handleDeeplink(url, isColdStart: true) }
    }

    /// The router's first route is on screen: a link from now on is warm.
    func firstRouteAppeared() {
        awaitsFirstRoute = false
    }

    private func fetch() async {
        var client = self.client
        if client.device == DeviceInfo() { client.device = .current() }
        do {
            let config = try await client.fetchConfig()
            // A link held until now is what the app opens at.
            let link = pendingLink
            pendingLink = nil
            if link != nil { awaitsFirstRoute = false }
            let router = OrcaRouter(client: self.client, config: config, system: system,
                                    onRouteChanged: onRouteChanged, onDeeplink: onDeeplink, link: link)
            // The held link was the system's delivery: no repeat will come.
            router.bootLink = nil
            phase = .ready(plugins?.attach(router) ?? router)
        } catch OrcaClientError.http(let status, let body) {
            phase = .failed("HTTP \(status): \(body.prefix(200))")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// The root view of an Orca-driven app: a NavigationStack of server pages,
/// each with loading and error states. `navigate` pushes a page, `goBack`
/// pops one, and app state is shared by every page on the stack. A config
/// with tabs is drawn as a tab bar with one NavigationStack per tab
/// (`TabShellView`).
///
/// With no `path` (the default, as in the Flutter SDK) the app gets the
/// server's navigation (routes, redirects, initial app state): it fetches
/// the navigation config first, its `initialRoute` is the first page and its
/// `initialAppState` is seeded before that page is asked for.
///
/// With a `path` no config is fetched and every path is a page: the app
/// opens that one page.
///
///     OrcaApp(client: OrcaClient(baseURL: url, appId: "navigation", apiKey: "demo-key"))
///     OrcaApp(client: OrcaClient(baseURL: url, appId: "counter", apiKey: "demo-key"), path: "home")
///     OrcaApp(client: OrcaClient(baseURL: url, appId: "server-actions", apiKey: "demo-key"), path: "shop")
@MainActor
public struct OrcaApp: View {
    @StateObject private var boot: OrcaAppBoot
    @StateObject private var gate: OrcaBootModel

    /// A client without a device id gets the one saved in UserDefaults
    /// (`DeviceIdentity`, made on first run).
    /// - Parameters:
    ///   - path: the first page; nil, the default, boots from the server's
    ///     navigation config (see above).
    ///   - enableOffline: run the version check at boot, before the config
    ///     or any page is asked for; a forceUpdate answer shows the
    ///     force-update screen and loads neither. The static-flow cache, the
    ///     saved config and `preload()` arrive with plan step 14.
    ///   - enableSessionTracking: send a session start when the app comes to
    ///     the foreground and an end when it goes to the background.
    ///   - onRouteChanged: told of every route change, the first route included.
    ///   - onDeeplink: told once per deep link, after the navigation and
    ///     after `onRouteChanged` (Dart `OrcaApp.onDeeplink`). The view
    ///     receives URL scheme and universal links itself (`.onOpenURL`,
    ///     `.onContinueUserActivity`) and goes to the link's path and query,
    ///     with or without this callback. A link that opens the app is where
    ///     the app starts, in place of the config's initial route. With a
    ///     `path` and no version check the first page shows at once: a launch
    ///     URL iOS delivers after that is a link to a running app
    ///     (`isColdStart` false, the `path` page already requested). To have
    ///     it exact, make the router with `link:` and use `init(router:)`.
    ///   - plugins: widgets, actions and triggers bundled per plugin, merged
    ///     once with `customActions` and `widgets` before the first request
    ///     (Dart `OrcaApp.plugins`, sdk/lib/src/widgets/orca_app.dart). Their
    ///     widget and action names are added to the client's capabilities. A
    ///     conflict shows the error view with Flutter's message and loads no page.
    ///   - customActions: handlers by action type, run by every page and not
    ///     advertised (Dart `OrcaApp.customActions`). A plugin action of the
    ///     same name is a conflict.
    ///   - widgets: builders for host widget types the SDK does not draw, not
    ///     advertised (Dart `OrcaApp.registry`). A plugin widget of the same
    ///     type is a conflict.
    public init(client: OrcaClient, path: String? = nil, system: SystemActions? = nil,
                enableOffline: Bool = false, enableSessionTracking: Bool = false,
                onRouteChanged: ((RouteChangeEvent) -> Void)? = nil,
                onDeeplink: ((DeeplinkEvent) -> Void)? = nil,
                plugins: [OrcaPlugin] = [], customActions: [String: OrcaActionHandler] = [:],
                widgets: WidgetBuilders = WidgetBuilders()) {
        let host = OrcaPluginHost(plugins: plugins, customActions: customActions, widgets: widgets)
        _boot = StateObject(wrappedValue: OrcaAppBoot(
            client: client.identified(by: UserDefaultsKeyValueStore()), path: path, system: system,
            onRouteChanged: onRouteChanged, onDeeplink: onDeeplink, plugins: host))
        _gate = StateObject(wrappedValue: OrcaBootModel(
            enableOffline: enableOffline, enableSessionTracking: enableSessionTracking, failure: host.failure))
    }

    /// The router's client is used as the host built it: to send a device
    /// id, set `client.deviceId = DeviceIdentity.resolve(UserDefaultsKeyValueStore())`.
    /// The options are those of `init(client:)`, `plugins`, `customActions`
    /// and `widgets` included (Dart `OrcaApp`, sdk/lib/src/widgets/orca_app.dart):
    /// a conflict shows the error view. Deep links go to the router as for
    /// `init(client:)`; set `router.onDeeplink` to be told of them. The
    /// router shows its first page at once, so a launch URL iOS delivers
    /// after that is a link to a running app (`isColdStart` false, the first
    /// page already requested); a router made with `link:` starts at the
    /// link, and drops the system's repeat of it.
    public init(router: @autoclosure @escaping () -> OrcaRouter,
                enableOffline: Bool = false, enableSessionTracking: Bool = false,
                plugins: [OrcaPlugin] = [], customActions: [String: OrcaActionHandler] = [:],
                widgets: WidgetBuilders = WidgetBuilders()) {
        let host = OrcaPluginHost(plugins: plugins, customActions: customActions, widgets: widgets)
        _boot = StateObject(wrappedValue: OrcaAppBoot(router: host.attach(router())))
        _gate = StateObject(wrappedValue: OrcaBootModel(
            enableOffline: enableOffline, enableSessionTracking: enableSessionTracking, failure: host.failure))
    }

    public var body: some View {
        // The gate first: its content, and so the config fetch and every
        // page, exists only once the version check lets the app through.
        OrcaBootView(boot: gate, client: boot.client) {
            switch boot.phase {
            case .loading:
                ProgressView().task { await boot.startIfNeeded() }
            case .ready(let router):
                RouterRoot(router: router).onAppear { boot.firstRouteAppeared() }
            case .failed(let message):
                LoadError(title: "Could not start the app", message: message) {
                    Task { await boot.retry() }
                }
            }
        }
        // Deep links: a URL scheme link, and a universal link. Held by the
        // boot while there is no router (also under the version check),
        // else a navigation of the router.
        .onOpenURL { boot.receive($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { boot.receive(url) }
        }
    }
}

/// A router on screen: the tab shell while it has one (a config with tabs,
/// showing a tab), else one stack (no tabs, a host path, or after a `go` to
/// a route outside the tabs). Over it lies the drawer layer: the one place a
/// drawer is drawn (the shell's and each page Scaffold's), so a panel covers
/// the navigation and tab bars too. The host is not observed here: a drawer
/// opening redraws the layer, not the pages.
@MainActor
private struct RouterRoot: View {
    @ObservedObject var router: OrcaRouter
    @State private var drawers = DrawerHost()

    var body: some View {
        ZStack {
            Group {
                if router.hasShell {
                    TabShellView(router: router, drawers: drawers)
                } else {
                    RouteStack(router: router)
                }
            }
            .environment(\.orcaDrawerHost, drawers)
            DrawerHostLayer(host: drawers)
        }
    }
}

/// The router's pages as a NavigationStack.
@MainActor
private struct RouteStack: View {
    @ObservedObject var router: OrcaRouter

    var body: some View {
        NavigationStack(path: $router.stack) {
            RoutePage(router: router, route: router.root, isStackRoot: true)
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
/// (no loader is made for it, so nothing is fetched), with Flutter's "Go to
/// home page" button, a `go` to `/`. `isStackRoot`: the first
/// page of its NavigationStack, where no back swipe takes the leading edge.
/// Where the route shows a navigation bar on iOS (pushed: the back button;
/// or a title bar) that bar takes the top inset from the page, as Flutter's
/// Scaffold takes it under an appBar (scaffold.dart :3027-3031): a SafeArea
/// in the page neither adds it nor lets its content under the bar.
@MainActor
struct RoutePage: View {
    let router: OrcaRouter
    let route: OrcaRoute
    var isStackRoot = false
    @Environment(\.orcaSafeAreaTaken) private var taken

    /// The top edge where the route shows a navigation bar on iOS; macOS
    /// draws its toolbar outside the content.
    private var barEdges: Edge.Set {
        #if os(iOS)
        return !isStackRoot || route.scaffoldTitle != nil ? .top : []
        #else
        return []
        #endif
    }

    static let homeButtonTitle = "Go to home page"

    /// The not-found page's button (go_router's default error screen does
    /// `go('/')`).
    func goHome() {
        router.navigate(to: "/", replace: true)
    }

    var body: some View {
        if route.isNotFound {
            VStack(spacing: 12) {
                Text("Page not found").font(.headline)
                Text(route.location).font(.footnote).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button(Self.homeButtonTitle, action: goHome)
                    .accessibilityIdentifier("orca.notFound.home")
            }
            .padding(24)
            .accessibilityIdentifier("orca.notFound")
        } else {
            LoadedRoutePage(route: route, loader: router.loader(for: route))
                .environment(\.orcaPage, OrcaPageContext(router: router, route: route, isStackRoot: isStackRoot))
                .environment(\.orcaSafeAreaTaken, taken.union(barEdges))
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
                OrcaPageView(model: model, loadTimeMs: loader.loadTimeMs)
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
struct TitleBar: ViewModifier {
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

/// The SDK's error view (a failed fetch, an app that cannot start): the
/// reason, and "Try again" when there is a `retry`.
struct LoadError: View {
    let title: String
    let message: String
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.headline)
            Text(message).font(.footnote).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Try again", action: retry)
            }
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
