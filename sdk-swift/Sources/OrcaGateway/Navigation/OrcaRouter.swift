#if canImport(SwiftUI)
import Combine
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

    /// The route of a stack entry that lives on: the same id (so the same
    /// page), the entry's fields as they are now.
    init(id: UUID, _ path: String, location: String, scaffoldTitle: String?, isNotFound: Bool,
         transition: RouteTransitionDef?) {
        self.id = id
        self.path = path
        self.location = location
        self.scaffoldTitle = scaffoldTitle
        self.isNotFound = isNotFound
        self.transition = transition
    }

    public static func == (a: OrcaRoute, b: OrcaRoute) -> Bool { a.id == b.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A pushed page animating its own content in: the route's transition and
/// the time of its push, on the scale of `OrcaRouter.frameClock`.
struct RouteEntrance: Equatable {
    let spec: TransitionSpec
    let startMs: Double

    /// The page at `ms`: `TransitionSpec.entering`.
    func look(at ms: Double, reduceMotion: Bool = false)
        -> (opacity: Double, offsetXFraction: Double, offsetYFraction: Double, scale: Double)
    {
        spec.entering(at: ms - startMs, reduceMotion: reduceMotion)
    }

    func isOver(at ms: Double, reduceMotion: Bool = false) -> Bool {
        spec.isOver(at: ms - startMs, reduceMotion: reduceMotion)
    }

    /// Points for an offset given as a fraction of the page's height.
    static func offset(fraction: Double, height: CGFloat) -> CGFloat {
        CGFloat(fraction) * height
    }
}

/// The Hero a push flies from: the tag of the Hero around the widget whose
/// action navigated, and the route that widget's page is. Also the id that
/// Hero marks itself with as a zoom source, so the same tag on the pushed
/// page is another source.
struct HeroSource: Hashable, Sendable {
    let route: OrcaRoute.ID
    let tag: String
}

/// How a pushed route comes in.
enum RoutePush: Equatable {
    /// The system's zoom out of the Hero with this tag (iOS 18 and up).
    case zoom(String)
    /// The system animation off, the page animating its own content in
    /// (`RouteEntrance`).
    case entrance
    /// The system push.
    case system

    /// The zoom transition exists: iOS 18 and up, never macOS.
    static func zoomAvailable(isIOS: Bool, osMajor: Int) -> Bool {
        isIOS && osMajor >= 18
    }

    /// The zoom transition exists where this runs.
    static var zoomAvailable: Bool {
        #if os(iOS)
        zoomAvailable(isIOS: true, osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        #else
        false
        #endif
    }

    /// The push of a route. `heroTag`: the Hero the navigation came from,
    /// nil or empty for none. `entranceHonoured`: the route's transition is
    /// one the page plays itself (`fade`, `slideUp`). Where the zoom exists
    /// a Hero wins over the route's transition, and reduced motion is the
    /// system's to honour inside its zoom; without one, reduced motion
    /// leaves the system push.
    static func decide(heroTag: String?, entranceHonoured: Bool, reduceMotion: Bool,
                       zoomAvailable: Bool) -> RoutePush {
        if zoomAvailable, let heroTag, !heroTag.isEmpty { return .zoom(heroTag) }
        return entranceHonoured && !reduceMotion ? .entrance : .system
    }
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
///
/// A config with tabs gives a tab shell (`TabShell`, the Swift side of
/// Flutter's `OrcaShell`): each tab keeps its own stack and its pages while
/// another tab is shown, `root` and `stack` are the stack on screen (the
/// current tab's, then the routes over the shell), and app state `_tabIndex`
/// follows the current tab and switches it when written.
///
/// Route transitions (a config route's `transition`): `fade` and `slideUp`
/// are played by the pushed page itself. When `navigate`, a deep link or a
/// tab change leaves a route new to the stacks on top of another page, and
/// its transition is one of the two, the stacks are written with the system
/// push animation off (a `Transaction` with `disablesAnimations`) and the
/// page fades or rises in over the route's duration with its curve. Every
/// other kind, a route without one, and reduced motion keep the system push;
/// going back is always the system pop. Known limits: the page under is gone
/// at once, so the new page fades or rises over the page background, not
/// over the old page; the navigation bar and its back button appear at once;
/// iOS 16 may not obey the transaction and play its push as well; a route
/// the host or the system writes into `stack` itself is not animated here;
/// the first page of a stack never is.
///
/// Hero: a `navigate` that pushes, fired by a widget inside a Hero with a
/// tag, records that Hero on the pushed route (`heroSource(of:)`) for as
/// long as the route is on the stacks. On iOS 18 and up that push is the
/// system's zoom out of the Hero, also for a `fade` or `slideUp` route,
/// whose own entrance is skipped for that push (`RoutePush.decide`). Below
/// iOS 18 and on macOS the record changes nothing. A `go`, a deep link, the
/// boot, a tab change and a push the host makes record none. Known limits:
/// the whole page zooms, which is not Flutter's flight of the one widget,
/// and it zooms whether or not the pushed page has a Hero of that tag (the
/// page is not loaded when the push begins).
@MainActor
public final class OrcaRouter: ObservableObject {
    /// The page under every pushed route: with tabs, the current tab's root.
    @Published public private(set) var root: OrcaRoute
    /// Pushed routes, bottom to top: the `NavigationStack` path. With tabs,
    /// the current tab's pages above its root, then `overRoutes`. Written
    /// by a back swipe or by the host; with a config the write goes through
    /// the table like `goBack` and `navigate`: routes taken off the top are
    /// popped, and each route added is pushed by its location and stays the
    /// route given.
    @Published public var stack: [OrcaRoute] = [] {
        didSet {
            guard !isSyncing else { return }
            if shell != nil { pathWritten(from: oldValue) } else { routesChanged(from: oldValue.count) }
        }
    }

    /// The tabs of the config; empty without a config or without tabs.
    public let tabs: [TabDef]
    /// A tab shell is on screen: the config has tabs and the last `go`
    /// (boot, `navigate` with `replace`, a tab switch) landed in one.
    public var hasShell: Bool { currentTab != nil }
    /// The tab on screen, also under a route pushed over the shell; nil
    /// without a shell.
    @Published public private(set) var currentTab: Int?
    /// One stack per tab, bottom to top; empty: not visited yet. Empty
    /// array without tabs.
    @Published public private(set) var tabStacks: [[OrcaRoute]] = []
    /// Routes above the shell, bottom to top. With a config and no shell on
    /// screen: the whole stack, `root` first. Empty without a config.
    @Published public private(set) var overRoutes: [OrcaRoute] = []
    /// The config has a shell drawer: tabs, and `drawerItems` or
    /// `drawerComponents`.
    public let hasDrawer: Bool
    /// The shell drawer is open.
    @Published public private(set) var isDrawerOpen = false
    /// `openDrawer()` was asked where no shell drawer can open: the route
    /// whose page should open its own `Scaffold` drawer. The page that does
    /// sets it back to nil; with no drawer on that page nothing happens.
    @Published public var pageDrawerRequest: OrcaRoute.ID?

    public let client: OrcaClient
    public var system: SystemActions
    /// The shared app scope, as the latest page or the host left it.
    public private(set) var appState: [String: JSONValue] = [:] {
        didSet { if appState != oldValue { appStateChanges.send(appState) } }
    }
    /// The app scope after each change, whoever wrote it (a page, the host,
    /// a tab change): what the shell's server trees (tab bar, drawer) are
    /// drawn against.
    let appStateChanges = PassthroughSubject<[String: JSONValue], Never>()
    /// Called with every effect a page reports, for DevTools and logging.
    public var onEffect: ((ActionEffect) -> Void)?
    /// Called once per change of the location on top, after any redirect
    /// (Flutter `OrcaApp.onRouteChanged`): `push` for `navigate`, `replace`
    /// for `navigate` with `replace`, `pop` for `goBack` and a back swipe.
    /// The same location again gives no event. The boot event (no previous
    /// location, `push`) goes to the callback given to `init`.
    public var onRouteChanged: ((RouteChangeEvent) -> Void)?
    /// Called once per deep link (`handleDeeplink`, or the link the router
    /// booted at), after the navigation and after `onRouteChanged` fired for
    /// it (Flutter `OrcaApp.onDeeplink`); also for a link to the location
    /// already on screen, which navigates nothing. Links navigate with or
    /// without it.
    public var onDeeplink: ((DeeplinkEvent) -> Void)?
    /// The routes of the config the router was made with; nil without one.
    public let table: RouteTable?
    /// OrcaApp's plugins: every page this router loads is built by it.
    var plugins: OrcaPluginHost?

    /// "Now" for route entrances, in milliseconds, on the scale of
    /// `OrcaPageModel.milliseconds(_:)`: the time a push is stamped with.
    /// Tests set it.
    var frameClock: () -> Double = { OrcaPageModel.milliseconds(Date()) }
    /// Reduced motion (`@OrcaReduceMotion`, set by the view that draws the
    /// router): every push is the system's.
    var reduceMotion = false
    /// The entrance of every route on the stacks that was pushed with the
    /// system animation off, by route id; it stays while the route does.
    private var entrances: [UUID: RouteEntrance] = [:]
    /// The zoom transition exists on this system (`RoutePush.zoomAvailable`).
    /// Tests set it.
    var zoomAvailable = RoutePush.zoomAvailable
    /// The Hero each route on the stacks was pushed from, by route id; it
    /// stays while the route does.
    private var heroSources: [UUID: HeroSource] = [:]
    /// The Hero tag of the `navigate` that is pushing right now.
    private var pushingHeroTag: String?

    private var loaders: [UUID: OrcaPageLoader] = [:]
    /// The stacks of a router made with a config; nil in path mode.
    private var shell: TabShell?
    /// The route of every entry of `shell`, by entry id, with the entry as
    /// it was when the route was made or given (a `stack` write): the route
    /// stays while its entry is the same.
    private var bound: [Int: (route: OrcaRoute, entry: TabShellEntry)] = [:]
    /// `root` and `stack` are being set from `shell`: not a back swipe.
    private var isSyncing = false
    /// The location last reported, and how the change under way began.
    private var lastLocation: String
    private var pendingType: RouteChangeType?
    /// The `link` the router was made with, until another link comes or the
    /// location on top changes: the system may deliver that same URL once
    /// more (`OrcaApp(router:)`'s `.onOpenURL`), and that repeat is dropped.
    var bootLink: URL?

    /// Every path is a page, starting at `path`.
    /// `system` defaults to the device's own handlers (`SystemActions.live`).
    ///
    /// With a `link` (the deep link that opened the app) the router starts at
    /// the link's location instead of `path`, which is never requested, and
    /// `onDeeplink` is told with `isColdStart` set. No route event: without
    /// a config there is none for the boot.
    public init(client: OrcaClient, path: String = "home", system: SystemActions? = nil,
                onDeeplink: ((DeeplinkEvent) -> Void)? = nil, link: URL? = nil) {
        self.client = client
        self.system = system ?? .live
        self.table = nil
        self.tabs = []
        self.hasDrawer = false
        let root = OrcaRoute(path)
        self.root = root
        self.lastLocation = root.location
        self.onDeeplink = onDeeplink
        if let link {
            bootLink = link
            start(at: link)
        }
    }

    /// Boot from the server's config (`OrcaClient.fetchConfig`), as Flutter's
    /// `OrcaApp._initRouter`: seed `initialAppState`, then show
    /// `initialRoute` resolved against it, the page chain as root + stack.
    ///
    /// With a `link` (the deep link that opened the app) the router boots at
    /// the link's location instead of `initialRoute`: the same seeding, the
    /// link's redirect rule applied, and `onDeeplink` told with
    /// `isColdStart` set, after the boot's route event.
    public init(client: OrcaClient, config: NavConfig, system: SystemActions? = nil,
                onRouteChanged: ((RouteChangeEvent) -> Void)? = nil,
                onDeeplink: ((DeeplinkEvent) -> Void)? = nil, link: URL? = nil) {
        self.client = client
        self.system = system ?? .live
        let table = RouteTable(config)
        self.table = table
        self.tabs = config.tabs
        self.hasDrawer = !config.tabs.isEmpty
            && !(config.drawerItems.isEmpty && config.drawerComponents.isEmpty)
        self.appState = config.initialAppState
        self.onRouteChanged = onRouteChanged
        self.onDeeplink = onDeeplink
        var shell = TabShell(table: table)
        // On a fresh shell a link is the boot: a `go` to its location.
        let opened = link.map { shell.open(link: DeepLink.location(of: $0), appState: config.initialAppState) }
        let change = opened?.change ?? shell.go(config.initialRoute, appState: config.initialAppState)
        // `go` always leaves a page on screen, if only "not found".
        let first = Self.route(shell.visible[0], id: nil)
        self.root = first
        self.lastLocation = shell.location
        self.bound = [shell.visible[0].id: (first, shell.visible[0])]
        self.shell = shell
        self.bootLink = link
        // `_tabIndex` is in app state before the first page is requested.
        if let index = change.tabIndexWrite { appState["_tabIndex"] = .int(index) }
        // The boot is no push: whatever is on top is simply there.
        publishStacks(isBoot: true)
        onRouteChanged?(RouteChangeEvent(location: lastLocation, previousLocation: nil, type: .push))
        if let link, let opened {
            onDeeplink?(DeepLink.event(link: link, resolution: opened.resolution, coldStart: true))
        }
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

    // MARK: - Route entrances

    /// The entrance of a route pushed with the system animation off; nil for
    /// every other route.
    func entrance(of id: OrcaRoute.ID) -> RouteEntrance? {
        entrances[id]
    }

    /// A route's page content at `ms`: at rest unless the route has an
    /// entrance still playing.
    func entering(_ route: OrcaRoute, at ms: Double)
        -> (opacity: Double, offsetXFraction: Double, offsetYFraction: Double, scale: Double)
    {
        entrances[route.id]?.look(at: ms, reduceMotion: reduceMotion) ?? (1, 0, 0, 1)
    }

    /// The tag of the Hero a route was pushed from; nil for a route no Hero
    /// pushed.
    func heroTag(of id: OrcaRoute.ID) -> String? {
        heroSources[id]?.tag
    }

    /// The Hero a route was pushed from, with the route it is on.
    func heroSource(of id: OrcaRoute.ID) -> HeroSource? {
        heroSources[id]
    }

    /// The Hero a route zooms out of and back into: its `heroSource` where
    /// the zoom exists, else nil.
    func zoomSource(of id: OrcaRoute.ID) -> HeroSource? {
        zoomAvailable ? heroSources[id] : nil
    }

    /// Where a push is decided (`RoutePush.decide`). `body` writes the
    /// stacks; `pushed` is the route it leaves on top when that route is new
    /// to the stacks and lies over another page, else nil. The Hero of the
    /// `navigate` under way is recorded on it. A `fade` or `slideUp` route
    /// (what iOS honours of `TransitionSpec`) is stamped with an entrance
    /// and written with the system animation off; a zoom, anything else, and
    /// reduced motion, is written as before.
    private func writeStacks(pushed: OrcaRoute?, _ body: () -> Void) {
        let tag = pushingHeroTag
        pushingHeroTag = nil
        guard let pushed else { return body() }
        if let tag, !tag.isEmpty { heroSources[pushed.id] = HeroSource(route: top.id, tag: tag) }
        let spec = TransitionSpec.spec(for: pushed.transition)
        let push = RoutePush.decide(heroTag: tag, entranceHonoured: spec.honoured(on: .iOS),
                                    reduceMotion: reduceMotion, zoomAvailable: zoomAvailable)
        guard push == .entrance else { return body() }
        entrances[pushed.id] = RouteEntrance(spec: spec, startMs: frameClock())
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }

    public func navigate(to path: String, replace: Bool = false) {
        navigate(to: path, replace: replace, heroTag: nil)
    }

    /// `navigate` from a page's action: `heroTag` is the tag of the Hero
    /// around the widget that fired it, recorded on the route a push adds.
    func navigate(to path: String, replace: Bool, heroTag: String?) {
        guard !path.isEmpty else { return }
        if shell != nil {
            // A push adds one page, the one asked for; `go` shows its chain.
            if replace {
                shellChanged(shell?.go(path, appState: appState), .replace)
            } else {
                pushingHeroTag = heroTag
                shellChanged(shell?.push(path, appState: appState), .push)
                pushingHeroTag = nil
            }
            return
        }
        let routes = [OrcaRoute(path)]
        if replace {
            pendingType = .replace
            root = routes[0]
            stack = Array(routes.dropFirst())
        } else {
            pendingType = .push
            if let heroTag, !heroTag.isEmpty {
                heroSources[routes[0].id] = HeroSource(route: top.id, tag: heroTag)
            }
            // Without a config no route has a transition: the system push,
            // or the zoom out of the Hero.
            stack.append(routes[0])
        }
    }

    /// Open a deep link (a URL scheme or universal link the platform handed
    /// to the app): go to its location, `DeepLink.location(of:)`, the URL's
    /// path and query. A `go` (`navigate` with `replace`), so the stack and
    /// the tab come from the config and the route's redirect rule applies;
    /// a link that ends on the location already on screen navigates and
    /// requests nothing. Then `onDeeplink` is told, once, after
    /// `onRouteChanged`. `OrcaApp` calls this for the links it receives;
    /// call it for links the host receives elsewhere. `isColdStart`: the
    /// link is what opened the app. A router made with a `link` drops one
    /// repeat of that exact URL while it is still where it booted: the
    /// system delivering the launch URL again is not a second link.
    public func handleDeeplink(_ url: URL, isColdStart: Bool = false) {
        let booted = bootLink
        bootLink = nil
        if url == booted { return }
        let location = DeepLink.location(of: url)
        let resolution: RouteResolution
        if let opened = shell?.open(link: location, appState: appState) {
            resolution = opened.resolution
            shellChanged(opened.change, .replace)
        } else {
            // No config: every path is a page, and the event's fields are
            // those of a location no rule can redirect.
            resolution = Self.pathResolution(location, appState)
            if location != top.location {
                pendingType = .replace
                root = OrcaRoute(String(location.unicodeScalars.prefix { $0 != "?" }), location: location)
                stack = []
            }
        }
        onDeeplink?(DeepLink.event(link: url, resolution: resolution, coldStart: isColdStart))
    }

    /// A link's resolution without a config: its own location, no rule.
    private static func pathResolution(_ location: String, _ appState: [String: JSONValue]) -> RouteResolution {
        RouteTable(NavConfig(initialRoute: "/")).resolve(location, appState: appState)
    }

    /// Without a config, before any page showed: stand on the link that
    /// opened the app as if made there. The location is not a change, so no
    /// route event, and the path the router was made with is never
    /// requested; then `onDeeplink` is told, `isColdStart` set.
    func start(at link: URL) {
        guard shell == nil else { return handleDeeplink(link, isColdStart: true) }
        let location = DeepLink.location(of: link)
        if location != top.location {
            lastLocation = location
            root = OrcaRoute(String(location.unicodeScalars.prefix { $0 != "?" }), location: location)
            if !stack.isEmpty { stack = [] }
        }
        onDeeplink?(DeepLink.event(link: link, resolution: Self.pathResolution(location, appState),
                                   coldStart: true))
    }

    public func goBack() {
        if shell != nil {
            shellChanged(shell?.pop(), .pop)
            return
        }
        guard !stack.isEmpty else { return }
        pendingType = .pop
        stack.removeLast()
    }

    /// A tap on the tab bar: another tab shows its stack as it was left (its
    /// first page on its first visit), the tab on screen pops to its root.
    /// What lies over the shell is dropped. Nothing without a shell or for
    /// an index out of range.
    public func selectTab(_ index: Int) {
        guard shell != nil else { return }
        shellChanged(shell?.selectTab(index, appState: appState), .replace)
    }

    /// The `switchTab` action: go to the tab's first page. Nothing for an
    /// unknown id.
    public func switchTab(_ tabId: String) {
        guard shell != nil else { return }
        shellChanged(shell?.switchTab(tabId, appState: appState), .replace)
    }

    /// The path of tab `index`'s own `NavigationStack`, as SwiftUI writes it
    /// after a back swipe. The path is the tab's pages above its root
    /// (`tabStacks[index].dropFirst()`), then `overRoutes` for the tab on
    /// screen. A shorter path pops; anything else, and any write for a tab
    /// that is not on screen, changes nothing.
    public func setTabPath(_ index: Int, _ routes: [OrcaRoute]) {
        guard shell != nil, index == currentTab else { return }
        let current = stack
        if routes.count < current.count, Array(current.prefix(routes.count)) == routes {
            for _ in routes.count..<current.count { _ = shell?.pop() }
        }
        shellChanged(nil, .pop)
    }

    /// Open the nearest drawer: the shell drawer when a tab's page is on
    /// screen and the config has one; else ask the page on top to open its
    /// own (`pageDrawerRequest`).
    public func openDrawer() {
        if hasDrawer, hasShell, overRoutes.isEmpty {
            isDrawerOpen = true
        } else {
            pageDrawerRequest = top.id
        }
    }

    /// Close the shell drawer.
    public func closeDrawer() {
        if isDrawerOpen { isDrawerOpen = false }
    }

    /// Write one app state key from the host. See `setAppState(_:)`.
    public func setAppState(_ key: String, _ value: JSONValue) {
        setAppState([key: value])
    }

    /// Write app state from the host: the shared scope takes the values, and
    /// so does the store of every page loaded so far, so widgets watching a
    /// key redraw. A page loaded later starts from the new scope.
    public func setAppState(_ values: [String: JSONValue]) {
        let tabIndex = appState["_tabIndex"]
        appState.merge(values) { _, new in new }
        shareAppState()
        tabIndexWritten(was: tabIndex)
    }

    /// Give every loaded page the shared scope.
    private func shareAppState() {
        let scope = appState
        for loader in loaders.values {
            guard case .loaded(let model) = loader.phase, model.store.state.app != scope else { continue }
            var state = model.store.state
            state.app = scope
            model.store.commit(state)
        }
    }

    // MARK: - The shell's stacks as routes

    /// The route of a shell entry: only the top of a page chain carries the
    /// location's query, title and transition; an entry of no route is "not
    /// found", its path the location without the query. `id` is the route
    /// the entry already has, nil for a new one.
    private static func route(_ entry: TabShellEntry, id: UUID?) -> OrcaRoute {
        let isNotFound = entry.resolution.kind != .page
        var path = Substring(entry.pagePath)
        if isNotFound {
            path = entry.resolution.location.prefix { $0 != "?" }
            while path.hasPrefix("/") { path = path.dropFirst() }
        }
        return OrcaRoute(id: id ?? UUID(), String(path), location: entry.location,
                         scaffoldTitle: entry.isTop ? entry.resolution.scaffoldTitle : nil,
                         isNotFound: isNotFound,
                         transition: entry.isTop ? entry.resolution.transition : nil)
    }

    /// The same routes showing the same locations.
    private static func same(_ a: [OrcaRoute], _ b: [OrcaRoute]) -> Bool {
        a == b && a.map(\.location) == b.map(\.location)
    }

    /// Set the published stacks from `shell`: one route per entry, the same
    /// route (its id, so its loader) for as long as the entry lives. Loaders
    /// of entries that left every stack go, and a page drawer request with
    /// its route.
    private func publishStacks(isBoot: Bool = false) {
        guard let shell else { return }
        var next: [Int: (route: OrcaRoute, entry: TabShellEntry)] = [:]
        let known = bound
        func route(_ entry: TabShellEntry) -> OrcaRoute {
            let was = known[entry.id]
            // A route stays as it is while its entry is the same.
            let route = was?.entry == entry ? was!.route : Self.route(entry, id: was?.route.id)
            next[entry.id] = (route, entry)
            return route
        }
        let tabs = shell.tabStacks.map { $0.map(route) }
        let over = shell.over.map(route)
        bound = next
        let live = Set(next.values.map(\.route.id))
        loaders = loaders.filter { live.contains($0.key) }
        if let asked = pageDrawerRequest, !live.contains(asked) { pageDrawerRequest = nil }
        entrances = entrances.filter { live.contains($0.key) }
        heroSources = heroSources.filter { live.contains($0.key) }

        let visible = (shell.currentTab.map { tabs[$0] } ?? []) + over
        let sync = {
            self.isSyncing = true
            defer { self.isSyncing = false }
            if self.currentTab != shell.currentTab { self.currentTab = shell.currentTab }
            if self.tabStacks.count != tabs.count || !zip(self.tabStacks, tabs).allSatisfy(Self.same) {
                self.tabStacks = tabs
            }
            if !Self.same(self.overRoutes, over) { self.overRoutes = over }
            guard let bottom = visible.first else { return }
            if !Self.same([self.root], [bottom]) { self.root = bottom }
            let above = Array(visible.dropFirst())
            if !Self.same(self.stack, above) { self.stack = above }
        }
        // The boot's stacks are simply there, with no word on animation.
        if isBoot { return sync() }
        // A push: the route on top was on no stack before and lies over
        // another page. A route the path binding brought (`pathWritten`) is
        // bound already, so it is not one.
        let was = Set(known.values.map(\.route.id))
        let pushed = visible.count > 1 ? visible.last.flatMap { was.contains($0.id) ? nil : $0 } : nil
        writeStacks(pushed: pushed, sync)
    }

    /// `shell` did an operation: publish its stacks, write the `_tabIndex`
    /// it asks for (every loaded page sees it; coming back through
    /// `tabIndexWritten` it is the current index, so it stops there), hand
    /// the page now on top the latest app scope, and report the location on
    /// top when it changed (which also closes the shell drawer).
    private func shellChanged(_ change: TabShellChange?, _ type: RouteChangeType) {
        publishStacks()
        if let index = change?.tabIndexWrite { setAppState("_tabIndex", .int(index)) }
        handTopTheAppState()
        report(type)
    }

    /// App state `_tabIndex` may have been written, by a page or the host:
    /// another tab's index shows that tab. Our own write comes back with the
    /// current index, which changes nothing.
    private func tabIndexWritten(was previous: JSONValue?) {
        let value = appState["_tabIndex"]
        guard shell != nil, value != previous else { return }
        guard case .int(let index)? = value, index != currentTab else { return }
        shellChanged(shell?.tabIndexChanged(value, appState: appState), .replace)
    }

    /// The visible path was written from outside (a `NavigationStack`
    /// binding after a back swipe, or the host): pop down to the routes the
    /// old and the new path share, then push each route added by its
    /// location; its entry's route is the route given. A `pop` event when
    /// the path got shorter, else a `push`.
    private func pathWritten(from old: [OrcaRoute]) {
        let written = stack
        var kept = 0
        while kept < written.count, kept < old.count, written[kept] == old[kept] { kept += 1 }
        for _ in kept..<old.count { _ = shell?.pop() }
        for route in written.dropFirst(kept) {
            let before = shell?.visible.count
            _ = shell?.push(route.location, appState: appState)
            guard let entry = shell?.visible.last, shell?.visible.count != before else { continue }
            bound[entry.id] = (route, entry)
        }
        shellChanged(nil, written.count < old.count ? .pop : .push)
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
        model.store.onCommit = { [weak self] state in
            guard let self else { return }
            let tabIndex = self.appState["_tabIndex"]
            self.appState = state.app
            self.tabIndexWritten(was: tabIndex)
        }
        model.onEffect = { [weak self] effect in self?.onEffect?(effect) }
        model.effectHandler = { [weak self] effect in
            guard let self, !self.perform(effect) else { return }
            self.system.perform(effect)
        }
    }

    /// Drop loaders of routes that left the stack (a back swipe changes the
    /// path directly) and a page drawer request with its route, hand the
    /// page now on top the latest app scope, and report the location on top
    /// when it changed.
    private func routesChanged(from oldCount: Int) {
        let live = Set(stack.map(\.id) + [root.id])
        loaders = loaders.filter { live.contains($0.key) }
        if let asked = pageDrawerRequest, !live.contains(asked) { pageDrawerRequest = nil }
        entrances = entrances.filter { live.contains($0.key) }
        heroSources = heroSources.filter { live.contains($0.key) }
        handTopTheAppState()
        // A change that `navigate` and `goBack` did not start came through
        // the `NavigationStack` path: a back swipe when the stack shrank.
        let type = pendingType ?? (stack.count < oldCount ? .pop : .push)
        pendingType = nil
        report(type)
    }

    private func handTopTheAppState() {
        if case .loaded(let model)? = loaders[top.id]?.phase, model.store.state.app != appState {
            var state = model.store.state
            state.app = appState
            model.store.commit(state)
        }
    }

    /// Report the location on top when it is another; the shell drawer
    /// closes with it.
    private func report(_ type: RouteChangeType) {
        let location = top.location
        guard location != lastLocation else { return }
        let previous = lastLocation
        lastLocation = location
        bootLink = nil
        closeDrawer()
        onRouteChanged?(RouteChangeEvent(location: location, previousLocation: previous, type: type))
    }

    /// Perform a navigation effect; false for any other effect.
    @discardableResult
    func perform(_ effect: ActionEffect) -> Bool {
        switch effect.type {
        case "navigate":
            // Fired by a widget inside a Hero, the push flies from it.
            navigate(to: effect.payload["route"]?.stringValue ?? "",
                     replace: effect.payload["replace"]?.boolValue ?? false,
                     heroTag: OrcaPageModel.firingHeroTag)
        case "goBack":
            goBack()
        case "switchTab":
            switchTab(effect.payload["tabId"]?.stringValue ?? "")
        case "openDrawer":
            openDrawer()
        default:
            return false
        }
        return true
    }
}
#endif
