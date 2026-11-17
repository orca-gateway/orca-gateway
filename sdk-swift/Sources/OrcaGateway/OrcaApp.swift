#if canImport(SwiftUI)
import SwiftUI

/// One page with the toast overlay (the head of its queue, the router's
/// under OrcaApp, when it is a toast; a snackbar is drawn by the root
/// Scaffold on screen, `SnackbarSlot`), and the debug overlay while DevTools
/// runs with `showOverlay` on. Put it inside a NavigationStack (OrcaApp does)
/// so a Scaffold's AppBar becomes the navigation bar.
///
/// The sheets openDialog opens are drawn over the NavigationStack under
/// OrcaApp (`RouteDialogLayer`); a page shown on its own draws them over
/// itself. A page leaving the screen for good (its route no longer on any
/// stack, or shown on its own) closes them, so no openDialog waits forever.
/// The tooltip bubbles are OrcaApp's, over everything; a page shown on its
/// own draws its own over itself and its sheets (`TooltipHostLayer`).
@MainActor
public struct OrcaPageView: View {
    @ObservedObject var model: OrcaPageModel
    @Environment(\.orcaDialogsDrawn) private var dialogsDrawn
    @Environment(\.orcaPage) private var page
    @Environment(\.orcaTooltips) private var appTooltips
    /// The bubbles of a page shown on its own; unused under OrcaApp.
    @State private var ownTooltips = OrcaTooltips()
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
        .overlay(alignment: .bottom) { ToastView(snackbars: model.snackbars) }
        .overlay {
            if !dialogsDrawn { DialogLayer(model: model).ignoresSafeArea() }
        }
        .overlay {
            if appTooltips == nil { TooltipHostLayer(tooltips: ownTooltips).ignoresSafeArea() }
        }
        .environment(\.orcaTooltips, appTooltips ?? ownTooltips)
        .onDisappear {
            // Covered by a push or another tab: its sheets wait for it.
            if let page, page.router.holds(page.route.id) { return }
            model.dialogs.closeAll()
        }
    }
}

/// The head of the queue at the bottom while it is in (entering or
/// showing) and a toast, as the pill it was before the queue (a known
/// difference: Flutter's toast is a floating SnackBar). It slides and fades
/// in, and out as the head starts to leave; the queue times it. A snackbar
/// head is not drawn here.
@MainActor
private struct ToastView: View {
    @ObservedObject var snackbars: OrcaSnackbars

    var body: some View {
        let toast = snackbars.shown.flatMap { $0.style == .toast ? $0 : nil }
        ZStack {
            if let toast {
                Text(toast.message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.18)))
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("orca.toast")
                    // Each item slides in and out on its own, also when
                    // the head goes from one straight to the next.
                    .id(toast.id)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast?.id)
    }
}

/// The app's one queue of snackbars and toasts, D4's `SnackbarQueue` kept
/// live: Flutter's root ScaffoldMessenger as showSnackbar and showToast use
/// it (sdk/lib/src/state/action_executor.dart:393-423; material app.dart
/// :990, scaffold.dart:371-392, :438-449, :661-674). OrcaRouter holds the
/// app's, so a bar outlives the page that showed it, across navigate, back
/// and a tab switch; a page with no router holds its own. Pages hand it
/// their snackbars and toasts in arrival order; views draw its head.
///
/// Time is `clock`'s. Each change first brings the queue up to it, and the
/// queue wakes itself (`sleep`) when its next phase is due, whatever is on
/// screen: a bar's time runs once it is in, as the messenger's timer does
/// with no Scaffold drawn. Tests set `clock`, set `sleep` to nil and pass
/// time in with `tick()`.
@MainActor
final class OrcaSnackbars: ObservableObject {
    @Published private(set) var queue = SnackbarQueue()
    /// Now, in ms, on the scale of `OrcaPageModel.milliseconds(_:)`.
    var clock: () -> Double = { OrcaPageModel.milliseconds(Date()) }
    /// Waits the given ms, until the queue's next phase is due; nil: nothing
    /// wakes the queue but `tick()`.
    var sleep: ((Double) async -> Void)? = { ms in
        try? await Task.sleep(nanoseconds: UInt64(max(ms, 1) * 1_000_000))
    }
    /// The clock's reading the queue was last brought up to.
    private var last: Double?
    private var wake: Task<Void, Never>?
    /// Each queued item as an OrcaToast, made once so its id stays, by item
    /// id.
    private var toasts: [Int: OrcaToast] = [:]

    /// The head, whatever its phase; nil when the queue is idle.
    var head: OrcaToast? { queue.current.flatMap { toasts[$0.id] } }

    /// The head while it is in: entering or showing, not leaving.
    var shown: OrcaToast? { queue.phase == .leaving ? nil : head }

    /// How far the head is in at `clock()`, 0 (out) ... 1 (fully in),
    /// linear: the queue's `reveal` brought up to now without changing the
    /// queue, so a bar sampling it each frame moves between the queue's own
    /// phase changes. 0 when idle, or when the head has gone by now.
    var reveal: Double {
        var now = queue
        if let last { now.advance(by: clock() - last) }
        return now.current?.id == queue.current?.id ? now.reveal : 0
    }

    /// What reads a bar's message out as it appears: VoiceOver's
    /// announcement on iOS, nothing elsewhere. Tests put their own here.
    static var announcer: (String) -> Void = { message in
        #if canImport(UIKit) && !os(watchOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
    /// The bar last read out.
    private var announced: UUID?

    /// A bar for `toast` appeared: read its message out once (Flutter's live
    /// region on the SnackBar, snack_bar.dart:849-851). A pushed page
    /// showing the same bar, or the bar drawn again, says nothing more.
    func announce(_ toast: OrcaToast) {
        guard announced != toast.id else { return }
        announced = toast.id
        Self.announcer(toast.message)
    }

    /// A swipe took `toast` off the screen: if it is still the head it goes
    /// at once, whatever its phase, with no leave, and the next enters
    /// (Flutter's Dismissible, then removeCurrentSnackBar, snack_bar.dart
    /// :859-871, :865). A bar that has gone meanwhile changes nothing.
    func swipe(_ toast: OrcaToast) {
        catchUp()
        if head?.id == toast.id {
            queue.swipe()
            prune()
        }
        schedule()
    }

    /// showSnackbar or showToast: the item joins the back of the queue; no
    /// duration is the kind's (4000 ms, 2000 for a toast).
    func show(_ kind: SnackbarQueue.Kind, message: String, durationMs: Int?) {
        catchUp()
        let item = queue.show(kind, message: message, durationMs: durationMs)
        toasts[item.id] = OrcaToast(message: message, duration: Double(item.durationMs) / 1000,
                                    style: kind == .snackbar ? .snackbar : .toast)
        schedule()
    }

    /// Bring the queue up to `clock()`, then set the next wake.
    func tick() {
        catchUp()
        schedule()
    }

    /// The phases due by `clock()` end in turn; a head that has left gives
    /// way to the next.
    private func catchUp() {
        let now = clock()
        if let last, now > last {
            var next = queue
            next.advance(by: now - last)
            if next != queue {
                queue = next
                prune()
            }
        }
        last = now
    }

    /// Forget the OrcaToast of every item no longer queued.
    private func prune() {
        let live = Set(queue.items.map(\.id))
        toasts = toasts.filter { live.contains($0.key) }
    }

    /// Wake at the queue's next phase change; none when it is idle.
    private func schedule() {
        wake?.cancel()
        wake = nil
        guard let sleep, let due = queue.untilNextChangeMs else { return }
        wake = Task { [weak self] in
            await sleep(due)
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }
}

/// Loads a page through OrcaClient and keeps the result. Under a router the
/// fetch carries the shared app state, and the page joins the router. A
/// router with an offline cache is asked first (Flutter
/// `OrcaPage._fetchPage`): a page it holds opens with no request and reports
/// no timing event; any other goes to the network, and what the network
/// sends is never written to the cache. Every page made here runs
/// refetchPage in place (`refetch`), unless the host registered its own
/// `refetchPage`.
@MainActor
public final class OrcaPageLoader: ObservableObject {
    public enum Phase {
        case loading
        case loaded(OrcaPageModel)
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .loading
    /// What failed, set with `.failed` (whose message reads as it always has)
    /// and cleared by `reload()`: `OrcaErrorView` maps it to its screen.
    public private(set) var error: Error?
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
        error = nil
        phase = .loading
        loadTimeMs = nil
        var client = self.client
        if client.device == DeviceInfo() { client.device = .current() }
        let app = router?.appState ?? [:]
        do {
            if let page = try router?.cachedPage(path) {
                phase = .loaded(build(page, app: app, client: client))
                return
            }
            let (page, timing) = try await client.fetchPageTimed(path, appState: app)
            let renderStart = timing.elapsed()
            let model = build(page, app: app, client: client)
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
        } catch {
            self.error = error
            phase = .failed(failedMessage(error))
        }
    }

    /// refetchPage on a page made here (Flutter `OrcaPage`'s `onRefetchPage`):
    /// fetch the path again with the app state and swap the tree into the
    /// same model. No loading phase and no effect; the action ends once the
    /// new tree is in. A failed fetch throws out of the action and the page
    /// stays as it was.
    func refetch(_ model: OrcaPageModel) async throws {
        var client = self.client
        if client.device == DeviceInfo() { client.device = .current() }
        let page = try await client.fetchPage(path, appState: router?.appState ?? model.store.state.app)
        model.replacePage(page)
    }

    /// The page's model, with the router's plugins and saved state (its
    /// saved entry laid over the seed), joined to the router; it runs
    /// refetchPage through `refetch`.
    private func build(_ page: PageResponse, app: [String: JSONValue], client: OrcaClient) -> OrcaPageModel {
        let model = router?.plugins?.page(page, store: ElmStore(app: app), client: client)
            ?? OrcaPageModel(page: page, store: ElmStore(app: app), client: client)
        // After the host's handlers, as Flutter's page registers it.
        model.registerOpenDialog()
        model.onRefetchPage = { [weak self, weak model] in
            guard let self, let model else { return }
            try await self.refetch(model)
        }
        model.useSavedState(router?.savedState)
        router?.attach(model)
        return model
    }
}

/// The message of a `.failed` phase: "HTTP <status>: <body>" for an HTTP
/// error, else the error's description.
private func failedMessage(_ error: Error) -> String {
    if case OrcaClientError.http(let status, let body) = error {
        return "HTTP \(status): \(body.prefix(200))"
    }
    return error.localizedDescription
}

/// How an `OrcaApp` starts. With a path the router is ready at once and
/// nothing is fetched here. With no path (the default, `path: nil`) the
/// app boots from the server config, as Flutter's `OrcaApp._initializeOnlineOnly`: `fetchConfig`, then a router
/// seeded with `initialAppState` showing `initialRoute`. OrcaApp's offline
/// inputs (Flutter `_initialize`): a preloaded config makes the router at
/// once, with no request; else `enableOffline` with a cache runs `preload`
/// in place of `fetchConfig`. A cache, when there is one, learns the
/// config's dynamic paths and serves the router's pages first.
@MainActor
public final class OrcaAppBoot: ObservableObject {
    public enum Phase {
        case loading
        case ready(OrcaRouter)
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .loading
    /// What failed, set with `.failed` (whose message reads as it always has)
    /// and cleared by `retry()`: `OrcaErrorView` maps it to its screen.
    public private(set) var error: Error?
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
    /// The boot runs `preload` with `staticFlowManager` (Flutter
    /// `_initializeWithOffline`).
    private let enableOffline: Bool
    /// The offline cache (Flutter `_flowManager`); nil with a `path`.
    private let staticFlowManager: StaticFlowManager?
    /// The saved state every router made here takes (OrcaApp's); nil:
    /// nothing is saved or restored.
    private let savedState: SavedState?
    /// `preload` answered forceUpdate: OrcaApp shows the force-update
    /// screen, and no router is made.
    @Published private(set) var updateRequired = false

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
    /// the config is asked for, and the router is attached to them. The
    /// offline inputs are OrcaApp's, used only with no `path`; so is
    /// `savedState`, which the router takes in either mode.
    init(client: OrcaClient, path: String?, system: SystemActions?,
         onRouteChanged: ((RouteChangeEvent) -> Void)?, onDeeplink: ((DeeplinkEvent) -> Void)? = nil,
         plugins: OrcaPluginHost?, enableOffline: Bool = false, preloadedConfig: NavConfig? = nil,
         staticFlowManager: StaticFlowManager? = nil, savedState: SavedState? = nil) {
        self.client = client
        self.system = system
        self.onRouteChanged = onRouteChanged
        self.onDeeplink = onDeeplink
        self.plugins = plugins
        self.enableOffline = enableOffline
        self.staticFlowManager = path == nil ? staticFlowManager : nil
        self.savedState = savedState
        plugins?.advertise(on: client)
        if let path {
            let router = OrcaRouter(client: client, path: path, system: system, savedState: savedState)
            router.onRouteChanged = onRouteChanged
            router.onDeeplink = onDeeplink
            madeAtPath = true
            started = true
            phase = .ready(plugins?.attach(router) ?? router)
        } else if let preloadedConfig {
            started = true
            phase = .ready(makeRouter(preloadedConfig, link: nil))
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
        enableOffline = false
        staticFlowManager = nil
        savedState = router.savedState
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
        error = nil
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
            let config: NavConfig
            if enableOffline, let staticFlowManager {
                switch try await preload(client: client, cache: staticFlowManager) {
                case .forceUpdate:
                    updateRequired = true
                    return
                case .success(let loaded):
                    config = loaded
                }
            } else {
                config = try await client.fetchConfig()
            }
            // A link held until now is what the app opens at.
            let link = pendingLink
            pendingLink = nil
            if link != nil { awaitsFirstRoute = false }
            let router = makeRouter(config, link: link)
            // The held link was the system's delivery: no repeat will come.
            router.bootLink = nil
            phase = .ready(router)
        } catch {
            self.error = error
            phase = .failed(failedMessage(error))
        }
    }

    /// The router of `config` (Flutter `_initRouter`): the cache learns the
    /// config's dynamic paths and serves the router's pages first, and the
    /// router is attached to the plugins.
    private func makeRouter(_ config: NavConfig, link: URL?) -> OrcaRouter {
        staticFlowManager?.initDynamicPaths(config.flows)
        let router = OrcaRouter(client: client, config: config, system: system,
                                onRouteChanged: onRouteChanged, onDeeplink: onDeeplink, link: link,
                                savedState: savedState)
        router.staticFlowManager = staticFlowManager
        return plugins?.attach(router) ?? router
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
///
/// A host can run the offline boot during its own splash (Dart
/// `OrcaApp.preload`), then show the app on its first frame. Over
/// `FileKeyValueStore.applicationSupport()`, the store `enableOffline` uses,
/// the host's preload and OrcaApp share one cache:
///
///     let cache = StaticFlowManager(store: FileKeyValueStore.applicationSupport())
///     let result = try await preload(client: client, cache: cache)
///     // .forceUpdate: the host shows its own force-update screen.
///     if case .success(let config) = result {
///         OrcaApp(client: client, preloadedConfig: config, staticFlowManager: cache)
///     }
@MainActor
public struct OrcaApp: View {
    @StateObject private var boot: OrcaAppBoot
    @StateObject private var gate: OrcaBootModel
    private let views: BootViews
    private let colorScheme: ColorScheme?
    private let locale: Locale?

    /// A client without a device id gets the one saved in UserDefaults
    /// (`DeviceIdentity`, made on first run).
    /// - Parameters:
    ///   - path: the first page; nil, the default, boots from the server's
    ///     navigation config (see above).
    ///   - enableOffline: offline support (Dart `OrcaApp.enableOffline`). The
    ///     config boot runs `preload(client:cache:)` under the loading view,
    ///     with `staticFlowManager` or else a cache of its own over
    ///     `FileKeyValueStore.applicationSupport()` (Application Support/<bundle
    ///     id>/OrcaGateway): the version check against the saved flow
    ///     versions, then the saved config, or `/config` fetched and saved
    ///     with the static flows' pre-rendered pages. A forceUpdate answer
    ///     shows the force-update screen; offline (any `/version` failure)
    ///     the app boots from the saved config, and with none saved the boot
    ///     fails: `OrcaErrorView` shows Flutter's screen for it, "Something
    ///     Went Wrong" / "An unexpected error occurred. Please try again.",
    ///     with a retry that runs `preload` again (the error's own message,
    ///     what an `errorView` and a host's own `preload` see, is "No network
    ///     and no cached config available"). With a `path` (Flutter has no
    ///     such mode) it is the version check alone: a forceUpdate answer
    ///     shows the force-update screen, and nothing is cached.
    ///   - preloadedConfig: a config the host already has, from `preload`
    ///     during its own splash (Dart `OrcaApp.preloadedConfig`). The config
    ///     fetch is skipped entirely: the router is made from it at once, so
    ///     the first frame is the app, with no `/version` or `/config`
    ///     request. Ignored with a `path`.
    ///   - staticFlowManager: the offline cache (Dart
    ///     `OrcaApp.staticFlowManager`); pass the same one `preload` used.
    ///     Every page asks it first and opens a static page it holds with no
    ///     request, also without `enableOffline`. Ignored with a `path`.
    ///   - savedState: where persistState saves and clearState deletes, and
    ///     what comes back at start: its saved app entry is laid over the
    ///     app state before the first route (with a config, over
    ///     `initialAppState`, so redirects see it), and each page's saved
    ///     entry over the page's state before the page is shown, as Flutter
    ///     does. Nil, the default, makes one over
    ///     `FileKeyValueStore.applicationSupport()`, the store the offline
    ///     cache uses (the saved entries, `orca_saved_*`, are apart from the
    ///     cache's). One per OrcaApp, made once, as the boot is.
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
    ///   - loadingView: shown while the config is asked for (Dart
    ///     `OrcaApp.loadingWidget`), and while the version check runs when
    ///     there is no `splashView`.
    ///   - splashView: shown while the version check runs and while the
    ///     config is asked for (Dart `OrcaApp.splashWidget`, which falls back
    ///     to `loadingWidget`). With neither, the SDK's spinner.
    ///   - errorView: given the error when the config cannot be fetched or
    ///     the plugins conflict, and drawn alone, with no retry (Dart
    ///     `OrcaApp.errorBuilder`). Without it, `OrcaErrorView`.
    ///   - forceUpdateView: drawn when the server demands an update (Dart
    ///     `OrcaApp.forceUpdateBuilder`). Without it, one centred line.
    ///
    ///     The four are boot views, as in Flutter: a page keeps the SDK's
    ///     spinner and `OrcaErrorView` with its retry.
    ///   - colorScheme: the colour scheme of everything the app draws (Dart
    ///     `OrcaMaterialAppConfig.themeMode`); nil follows the system. A
    ///     Scaffold stays light, as Flutter's builders keep it.
    ///   - locale: the locale of everything the app draws (Dart
    ///     `OrcaMaterialAppConfig.locale`); nil is the environment's. The
    ///     `x-orca-locale` header stays the device's, as in Flutter.
    public init(client: OrcaClient, path: String? = nil, system: SystemActions? = nil,
                enableOffline: Bool = false, preloadedConfig: NavConfig? = nil,
                staticFlowManager: StaticFlowManager? = nil, savedState: SavedState? = nil,
                enableSessionTracking: Bool = false,
                onRouteChanged: ((RouteChangeEvent) -> Void)? = nil,
                onDeeplink: ((DeeplinkEvent) -> Void)? = nil,
                plugins: [OrcaPlugin] = [], customActions: [String: OrcaActionHandler] = [:],
                widgets: WidgetBuilders = WidgetBuilders(),
                loadingView: (() -> AnyView)? = nil, splashView: (() -> AnyView)? = nil,
                errorView: ((Error) -> AnyView)? = nil, forceUpdateView: (() -> AnyView)? = nil,
                colorScheme: ColorScheme? = nil, locale: Locale? = nil) {
        let host = OrcaPluginHost(plugins: plugins, customActions: customActions, widgets: widgets)
        _boot = StateObject(wrappedValue: OrcaAppBoot(
            client: client.identified(by: UserDefaultsKeyValueStore()), path: path, system: system,
            onRouteChanged: onRouteChanged, onDeeplink: onDeeplink, plugins: host,
            enableOffline: enableOffline, preloadedConfig: preloadedConfig,
            staticFlowManager: path != nil ? nil : staticFlowManager
                ?? (enableOffline ? StaticFlowManager(store: FileKeyValueStore.applicationSupport()) : nil),
            savedState: savedState ?? SavedState(local: FileKeyValueStore.applicationSupport())))
        // The config boot checks versions in `preload`, or not at all with
        // a preloaded config: the gate's check is for a `path` only.
        _gate = StateObject(wrappedValue: OrcaBootModel(
            enableOffline: enableOffline && path != nil, enableSessionTracking: enableSessionTracking,
            failure: host.failure))
        views = BootViews(loading: loadingView, splash: splashView, error: errorView, forceUpdate: forceUpdateView)
        self.colorScheme = colorScheme
        self.locale = locale
    }

    /// The router's client is used as the host built it: to send a device
    /// id, set `client.deviceId = DeviceIdentity.resolve(UserDefaultsKeyValueStore())`.
    /// The options are those of `init(client:)`, `plugins`, `customActions`,
    /// `widgets`, the boot views, `colorScheme` and `locale` included (Dart
    /// `OrcaApp`, sdk/lib/src/widgets/orca_app.dart): a conflict shows the
    /// error view. Deep links go to the router as for `init(client:)`; set
    /// `router.onDeeplink` to be told of them. The router shows its first
    /// page at once, so a launch URL iOS delivers after that is a link to a
    /// running app (`isColdStart` false, the first page already requested); a
    /// router made with `link:` starts at the link, and drops the system's
    /// repeat of it. `enableOffline` here is the version check alone (a
    /// forceUpdate answer shows the force-update screen): nothing is cached,
    /// and the router's pages go to the network. Saved state is the
    /// router's (`OrcaRouter(…, savedState:)`): a router made without one
    /// saves and restores nothing.
    public init(router: @autoclosure @escaping () -> OrcaRouter,
                enableOffline: Bool = false, enableSessionTracking: Bool = false,
                plugins: [OrcaPlugin] = [], customActions: [String: OrcaActionHandler] = [:],
                widgets: WidgetBuilders = WidgetBuilders(),
                loadingView: (() -> AnyView)? = nil, splashView: (() -> AnyView)? = nil,
                errorView: ((Error) -> AnyView)? = nil, forceUpdateView: (() -> AnyView)? = nil,
                colorScheme: ColorScheme? = nil, locale: Locale? = nil) {
        let host = OrcaPluginHost(plugins: plugins, customActions: customActions, widgets: widgets)
        _boot = StateObject(wrappedValue: OrcaAppBoot(router: host.attach(router())))
        _gate = StateObject(wrappedValue: OrcaBootModel(
            enableOffline: enableOffline, enableSessionTracking: enableSessionTracking, failure: host.failure))
        views = BootViews(loading: loadingView, splash: splashView, error: errorView, forceUpdate: forceUpdateView)
        self.colorScheme = colorScheme
        self.locale = locale
    }

    public var body: some View {
        // The gate first: its content, and so the config fetch and every
        // page, exists only once the version check lets the app through.
        OrcaBootView(boot: gate, client: boot.client, views: views) {
            AppBootContent(boot: boot, views: views)
        }
        // Deep links: a URL scheme link, and a universal link. Held by the
        // boot while there is no router (also under the version check),
        // else a navigation of the router.
        .onOpenURL { boot.receive($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { boot.receive(url) }
        }
        .modifier(AppEnvironment(colorScheme: colorScheme, locale: locale))
    }
}

/// OrcaApp's colour scheme and locale, set on everything below it, as
/// Flutter's MaterialApp `themeMode` and `locale` reach the boot screens and
/// the pages; nil leaves the host's. Written into the environment, so it
/// stays inside OrcaApp (`preferredColorScheme` would turn the whole window).
private struct AppEnvironment: ViewModifier {
    let colorScheme: ColorScheme?
    let locale: Locale?

    func body(content: Content) -> some View {
        content
            .transformEnvironment(\.colorScheme) { if let colorScheme { $0 = colorScheme } }
            .transformEnvironment(\.locale) { if let locale { $0 = locale } }
    }
}

/// The app once the gate lets it through: the splash while the config is
/// asked for (or the offline boot runs `preload`), the routes, the
/// force-update screen when that preload answered forceUpdate, or the error
/// screen with a retry (the host's views when given, its error view with no
/// retry).
@MainActor
struct AppBootContent: View {
    @ObservedObject var boot: OrcaAppBoot
    var views = BootViews()

    var body: some View {
        if boot.updateRequired {
            // The config boot's own preload answered forceUpdate.
            views.forceUpdateScreen()
        } else {
            bootPhase
        }
    }

    @ViewBuilder private var bootPhase: some View {
        switch boot.phase {
        case .loading:
            views.splashScreen().task { await boot.startIfNeeded() }
        case .ready(let router):
            RouterRoot(router: router).onAppear { boot.firstRouteAppeared() }
        case .failed:
            if let error = boot.error {
                views.errorScreen(error) {
                    OrcaErrorView(error: error) {
                        Task { await boot.retry() }
                    }
                }
            }
        }
    }
}

/// A router on screen: the tab shell while it has one (a config with tabs,
/// showing a tab), else one stack (no tabs, a host path, or after a `go` to
/// a route outside the tabs). Over it lies the drawer layer: the one place a
/// drawer is drawn (the shell's and each page Scaffold's), so a panel covers
/// the navigation and tab bars too. The host is not observed here: a drawer
/// opening redraws the layer, not the pages. Over all of it lie the app's
/// tooltip bubbles (`TooltipHostLayer`), each placed and clipped in its
/// page's Overlay (`TooltipOverlayArea`): over the stacks, their sheets and
/// snackbar bars and the drawer; under tabs, never over the tab bar.
@MainActor
private struct RouterRoot: View {
    @ObservedObject var router: OrcaRouter
    @State private var drawers = DrawerHost()
    @State private var tooltips = OrcaTooltips()
    @OrcaReduceMotion private var reduceMotion
    /// Where a Hero and the page pushed from it meet for the zoom.
    @Namespace private var heroes

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
            .environment(\.orcaHeroNamespace, heroes)
            DrawerHostLayer(host: drawers)
            TooltipHostLayer(tooltips: tooltips).ignoresSafeArea()
        }
        .environment(\.orcaTooltips, tooltips)
        // The router decides each push; with reduced motion all are the
        // system's.
        .onAppear { router.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { router.reduceMotion = $0 }
    }
}

/// The router's pages as a NavigationStack. The system animates its pushes
/// and pops, but for a `fade` or `slideUp` route: the router writes the path
/// with animations off and `RoutePage` animates its content in.
///
/// Over it, its navigation bar included, lie the sheets of the page on top
/// (Flutter's root Navigator: the modal route over the page route, its
/// AppBar and its Scaffold's snackbar), edge to edge.
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
        .environment(\.orcaDialogsDrawn, true)
        .overlay {
            let top = router.top
            if !top.isNotFound {
                RouteDialogLayer(loader: router.loader(for: top))
                    .id(top.id)
                    .ignoresSafeArea()
            }
        }
    }
}

extension OrcaRouter {
    /// The route is on one of the stacks: the single one, a tab's, or over
    /// the shell.
    func holds(_ id: OrcaRoute.ID) -> Bool {
        root.id == id || stack.contains { $0.id == id } || overRoutes.contains { $0.id == id }
            || tabStacks.contains { $0.contains { $0.id == id } }
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
///
/// A route the router pushed with the system animation off (a `fade` or
/// `slideUp` transition, `OrcaRouter.entrance(of:)`) animates its content in
/// here, in a tab's stack as in the single one; every other route is drawn
/// as it is.
///
/// A route pushed from inside a Hero zooms out of it on iOS 18 and up
/// (`OrcaRouter.zoomSource(of:)`, `HeroZoom`); such a route has no entrance.
///
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
        if let entrance = router.entrance(of: route.id) {
            page.modifier(RouteEntranceEffect(entrance: entrance))
        } else {
            page.modifier(HeroZoom(source: router.zoomSource(of: route.id)))
        }
    }

    @ViewBuilder private var page: some View {
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
                .modifier(TitledRouteSnackbar(snackbars: route.scaffoldTitle == nil ? nil : router.snackbars))
                .environment(\.orcaPage, OrcaPageContext(router: router, route: route, isStackRoot: isStackRoot))
                .environment(\.orcaSafeAreaTaken, taken.union(barEdges))
        }
    }
}

/// A titled route (`scaffoldTitle`: a tabbed config's route outside every
/// tab) is wrapped by Flutter in a root Scaffold of its own, with its page,
/// spinner or error inside (navigation_handler.dart:111-147, :372;
/// orca_page.dart:218-247): that Scaffold draws the app's snackbar at the
/// bottom edge, the inset inside, also over a page with no Scaffold, and a
/// Scaffold in the page is nested (draws none, its FAB stays). `snackbars`
/// nil: not a titled route, nothing changes.
private struct TitledRouteSnackbar: ViewModifier {
    let snackbars: OrcaSnackbars?

    func body(content: Content) -> some View {
        if let snackbars {
            content
                .environment(\.orcaSnackbarDrawn, true)
                .overlay { SnackbarOverlay(snackbars: snackbars, reachesBottomEdge: true) }
        } else {
            content
        }
    }
}

/// The content of a pushed page coming in by itself (the route's `fade` or
/// `slideUp` transition): its opacity from 0 to 1, or its offset from its
/// own height down to 0, over the route's duration with the route's curve.
/// Sampled from the core's `TransitionSpec` on the frame clock, not a
/// SwiftUI animation, so every curve of the core's table plays and there is
/// one clock. Frames are asked for only until the entrance is over.
///
/// Known limits: the system push was turned off, so the page under is gone
/// at once and this page fades or rises over the page background, not over
/// the old page; the navigation bar and its back button are not part of the
/// content and appear at once; iOS 16 may ignore the transaction and play
/// its own push under this; going back is the system pop.
private struct RouteEntranceEffect: ViewModifier {
    let entrance: RouteEntrance
    @OrcaReduceMotion private var reduceMotion
    @State private var isOver = false
    /// The height the page has to itself, 0 until it is measured.
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: isOver || reduceMotion)) { context in
            let now = OrcaPageModel.milliseconds(context.date)
            let look = entrance.look(at: now, reduceMotion: reduceMotion)
            let rises = look.offsetYFraction != 0
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(GeometryReader { area in
                    Color.clear
                        .onAppear { height = area.size.height }
                        .onChange(of: area.size.height) { height = $0 }
                })
                // Until the height is known a rising page has no place yet.
                .opacity(rises && height == 0 ? 0 : look.opacity)
                .offset(y: RouteEntrance.offset(fraction: look.offsetYFraction, height: height))
                .onChange(of: context.date) { date in
                    if entrance.isOver(at: OrcaPageModel.milliseconds(date), reduceMotion: reduceMotion) {
                        isOver = true
                    }
                }
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
            case .failed:
                if let error = loader.error {
                    OrcaErrorView(error: error) {
                        Task { await loader.reload() }
                    }
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

/// The SDK's error screen, the native twin of Flutter's `buildOrcaError`
/// (sdk/lib/src/widgets/orca_error.dart): `OrcaErrorInfo`'s icon, title and
/// message, centred, with Flutter's sizes (padding 32, icon 48, gaps 16 and
/// 8, title 18 semibold, message 14). OrcaApp shows it for a page or a config
/// boot that failed and for a plugin conflict; a host can show it too.
///
/// The colours are the platform's, `.primary` for the title and `.secondary`
/// for the icon and message, so dark mode reads; Flutter's are fixed black at
/// 87% and 60%. With a `retry`, a "Try again" button sits under the message,
/// a native extra Flutter does not have.
@MainActor
public struct OrcaErrorView: View {
    let info: OrcaErrorInfo
    /// The info's message, or the one given in its place.
    let message: String
    let retry: (() -> Void)?

    public init(error: Error, retry: (() -> Void)? = nil) {
        self.init(error: error, message: nil, retry: retry)
    }

    /// `error`'s screen with `message` in place of its own: a plugin conflict
    /// keeps Flutter's default title and says what conflicts.
    init(error: Error, message: String?, retry: (() -> Void)? = nil) {
        let info = OrcaErrorInfo(error)
        self.info = info
        self.message = message ?? info.message
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: 0) {
            Image(systemName: Self.symbol(info.kind))
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundColor(.secondary)
            Text(info.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            if let retry {
                Button("Try again", action: retry)
                    .padding(.top, 16)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("orca.error")
    }

    /// The SF Symbol closest to Flutter's Material icon for `kind`.
    static func symbol(_ kind: OrcaErrorInfo.Kind) -> String {
        switch kind {
        case .unauthorized: return "lock"  // lock_outline
        case .forbidden: return "nosign"  // block
        case .notFound: return "magnifyingglass"  // search_off
        case .tooManyRequests: return "speedometer"  // speed
        case .server: return "icloud.slash"  // cloud_off
        case .status, .unknown: return "exclamationmark.circle"  // error_outline
        case .configuration: return "gearshape"  // settings
        case .connection: return "wifi.slash"  // wifi_off
        }
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
