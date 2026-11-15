#if canImport(SwiftUI)
import Foundation
import XCTest

@testable import OrcaGateway

/// Pages by path and the `/action` route, for router tests: a page is
/// `{pageId, title, state, components}` with one Text node, and every request
/// is kept so a test can read the app state a fetch carried.
final class PageStub: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private let state: [String: [JSONValue]]
    private let actionBody: String?
    private let watching: [String: String]

    /// `state` gives each path its state definitions; any other path is a
    /// page with none. `watching` gives a path's Text an app key to show
    /// (`V.appState(key)`) instead of the path's name.
    init(state: [String: [JSONValue]] = [:], actionBody: String? = nil, watching: [String: String] = [:]) {
        self.state = state
        self.actionBody = actionBody
        self.watching = watching
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    private func record(_ request: HTTPRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        record(request)
        let path = request.url.path
        if path.hasSuffix("/action") {
            return HTTPResponse(status: 200, body: Data((actionBody ?? #"{"actions":[]}"#).utf8))
        }
        let name = path.components(separatedBy: "/page/").last ?? ""
        var data = JSONValue.string(name)
        var watches: [JSONValue] = []
        if let key = watching[name] {
            data = ["type": "state", "scope": "app", "key": .string(key)]
            watches = [.string(key)]
        }
        let page: JSONValue = [
            "pageId": .string(name), "title": .string(name),
            "state": .array(state[name] ?? []),
            "components": [["id": "0", "type": "Text", "kind": "primitive", "childMode": "none",
                            "props": ["data": data], "children": [], "watches": .array(watches)]],
        ]
        return HTTPResponse(status: 200, body: try page.encoded())
    }

    /// The app state a request carried (a POST body), or nil for a GET.
    static func appState(_ request: HTTPRequest) -> JSONValue? {
        guard request.method == "POST", let body = request.body else { return nil }
        return (try? JSONValue.decode(body))?["appState"]
    }

    static func client(_ stub: PageStub) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   device: DeviceInfo(osVersion: "test"), transport: stub)
    }
}

/// What a test's system adapters were asked to do.
@MainActor
final class SystemRecorder {
    var opened: [URL] = []
    var copied: [String] = []
    var shared: [[String?]] = []

    func actions(_ policy: OrcaURLPolicy = .standard) -> SystemActions {
        SystemActions(
            open: { self.opened.append($0) }, copy: { self.copied.append($0) },
            share: { self.shared.append([$0, $1]) }, urlPolicy: policy)
    }
}

/// T3.2: navigation through the router, and openUrl, clipboard and share
/// through recording adapters, as the effects a page's actions report.
@MainActor
final class RouterTests: XCTestCase {
    private func router(_ stub: PageStub = PageStub(), _ recorder: SystemRecorder? = nil)
        -> OrcaRouter
    {
        OrcaRouter(client: PageStub.client(stub), path: "home",
                   system: (recorder ?? SystemRecorder()).actions())
    }

    private func loaded(_ router: OrcaRouter, _ route: OrcaRoute) async throws -> OrcaPageModel {
        let loader = router.loader(for: route)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "RouterTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
        }
        return model
    }

    func testNavigatePushesReplaceResetsGoBackPops() {
        let router = router()
        let home = router.root
        XCTAssertEqual(home.path, "home")

        router.navigate(to: "/about")
        router.navigate(to: "product")
        XCTAssertEqual(router.stack.map(\.path), ["about", "product"])
        XCTAssertEqual(router.top.path, "product")

        router.goBack()
        XCTAssertEqual(router.stack.map(\.path), ["about"])

        router.navigate(to: "checkout", replace: true)
        XCTAssertEqual(router.root.path, "checkout")
        XCTAssertNotEqual(router.root.id, home.id)
        XCTAssertEqual(router.stack, [])

        router.goBack()
        router.navigate(to: "")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(router.root.path, "checkout")
    }

    func testTheSamePathTwiceIsTwoPages() {
        let router = router()
        router.navigate(to: "product")
        router.navigate(to: "product")
        XCTAssertEqual(router.stack.count, 2)
        XCTAssertNotEqual(router.stack[0].id, router.stack[1].id)
        XCTAssertFalse(router.loader(for: router.stack[0]) === router.loader(for: router.stack[1]))
        XCTAssertTrue(router.loader(for: router.stack[0]) === router.loader(for: router.stack[0]))
    }

    func testAPoppedRouteLosesItsPage() {
        let router = router()
        router.navigate(to: "about")
        let about = router.stack[0]
        let first = router.loader(for: about)
        router.stack = []  // a back swipe sets the path directly
        XCTAssertFalse(first === router.loader(for: about))
    }

    func testPageActionsDriveTheRouter() async throws {
        let router = router()
        let home = try await loaded(router, router.root)
        await home.run(.navigate(.init(route: "/about")))
        XCTAssertEqual(router.stack.map(\.path), ["about"])

        let about = try await loaded(router, router.stack[0])
        await about.run(.goBack)
        XCTAssertEqual(router.stack, [])

        await home.run(.navigate(.init(path: "checkout", replace: true)))
        XCTAssertEqual(router.root.path, "checkout")
    }

    /// App state is one scope: the next page's fetch carries it, the page
    /// starts from it, and the page revealed by a pop sees later writes.
    func testAppStateIsSharedAcrossPages() async throws {
        let stub = PageStub(state: [
            "home": [["key": "cart", "scope": "app", "initial": 0]],
            "product": [["key": "cart", "scope": "app", "initial": 99],
                        ["key": "qty", "scope": "page", "initial": 1]],
        ])
        let router = router(stub)
        let home = try await loaded(router, router.root)
        XCTAssertNil(PageStub.appState(stub.requests[0]))
        XCTAssertEqual(router.appState, ["cart": 0])

        await home.run(.setState(.init(key: "cart", scope: .app, value: 2)))
        router.navigate(to: "product")
        let product = try await loaded(router, router.stack[0])
        XCTAssertEqual(PageStub.appState(stub.requests[1]), ["cart": 2])
        // The app key was already set, so the page's own initial is ignored.
        XCTAssertEqual(product.store.state.app, ["cart": 2])
        XCTAssertEqual(product.store.state.page, ["qty": 1])

        await product.run(.setState(.init(key: "cart", scope: .app, value: 3)))
        XCTAssertEqual(home.store.value("cart"), 2)
        router.goBack()
        XCTAssertEqual(home.store.value("cart"), 3)
        XCTAssertEqual(home.store.state.page, [:])
    }

    func testOpenUrlFollowsThePolicy() async throws {
        let recorder = SystemRecorder()
        let router = router(PageStub(), recorder)
        let home = try await loaded(router, router.root)
        var reported: [String] = []
        router.onEffect = { reported.append($0.type) }

        for url in ["https://orca.example/docs", "mailto:hi@orca.example", "javascript:alert(1)",
                    "tel:123", "file:///etc/hosts", "not a url"] {
            await home.run(.openUrl(.init(url: .string(url))))
        }
        XCTAssertEqual(recorder.opened.map(\.absoluteString),
                       ["https://orca.example/docs", "mailto:hi@orca.example"])
        XCTAssertEqual(reported.count, 6, "blocked URLs are still reported")

        let tel = SystemRecorder()
        let policy = OrcaURLPolicy(extraSchemes: ["TEL"])
        XCTAssertTrue(tel.actions(policy).perform(ActionEffect("openUrl", ["url": "tel:123"])))
        XCTAssertEqual(tel.opened.map(\.absoluteString), ["tel:123"])
    }

    func testClipboardAndShare() async throws {
        let recorder = SystemRecorder()
        let router = router(PageStub(), recorder)
        let home = try await loaded(router, router.root)
        await home.run(.copyToClipboard(.init(text: "ORCA-42")))
        await home.run(.share(.init(title: "Orca", message: "Look")))
        await home.run(.share(.init(text: "Plain")))
        XCTAssertEqual(recorder.copied, ["ORCA-42"])
        XCTAssertEqual(recorder.shared, [["Look", "Orca"], ["Plain", nil]])
        XCTAssertFalse(recorder.actions().perform(ActionEffect("navigate", ["route": "x"])))
    }

    // MARK: - Step 9: config, app state, onRouteChanged

    /// Tabs `/home` and `/cart`, a nested child, a protected route, and two
    /// routes outside the tabs (drawn with a title bar).
    private func config(initialRoute: String = "/welcome", loggedIn: Bool = false, tabs: Bool = false)
        -> NavConfig
    {
        NavConfig(
            initialRoute: initialRoute,
            tabs: tabs ? [TabDef(id: "home", label: "Home", icon: "home", initialRoute: "/home"),
                          TabDef(id: "cart", label: "Cart", icon: "cart", initialRoute: "/cart")] : [],
            initialAppState: ["loggedIn": .bool(loggedIn)],
            flows: [NavFlow(name: "main", routes: [
                NavRoute(path: "welcome"),
                NavRoute(path: "home", children: [NavRoute(path: "home/product/:id")]),
                NavRoute(path: "cart"),
                NavRoute(path: "login"),
                NavRoute(path: "settings", transition: RouteTransitionDef(type: "fade")),
                NavRoute(path: "account",
                         redirect: RedirectRule(when: "loggedIn", equals: false, to: "/login")),
            ])])
    }

    private func router(_ config: NavConfig, _ stub: PageStub = PageStub(),
                        onRouteChanged: ((RouteChangeEvent) -> Void)? = nil) -> OrcaRouter
    {
        OrcaRouter(client: PageStub.client(stub), config: config, system: SystemRecorder().actions(),
                   onRouteChanged: onRouteChanged)
    }

    func test_B9_6_hostReadsAndWritesAppState() async throws {
        let stub = PageStub(state: ["home": [["key": "cart", "scope": "app", "initial": 0]]],
                            watching: ["home": "cart", "product": "cart"])
        let router = router(stub)
        let home = try await loaded(router, router.root)
        router.navigate(to: "product")
        let product = try await loaded(router, router.stack[0])
        router.navigate(to: "about")  // on the stack, never loaded
        XCTAssertEqual(product.resolve("0")?["data"], 0)

        var redraws = 0
        let watching = home.store.subscribe(["cart"]) { _ in redraws += 1 }
        defer { watching.cancel() }

        router.setAppState("cart", 5)
        XCTAssertEqual(router.appState["cart"], 5)
        XCTAssertEqual(product.store.state.app["cart"], 5)
        XCTAssertEqual(home.store.state.app["cart"], 5, "a page lower in the stack holds it too")
        XCTAssertEqual(product.resolve("0")?["data"], 5)
        XCTAssertEqual(home.resolve("0")?["data"], 5)
        XCTAssertEqual(redraws, 1, "a widget watching the key redraws")

        router.setAppState(["cart": 6, "user": "amr"])
        XCTAssertEqual(router.appState, ["cart": 6, "user": "amr"])
        XCTAssertEqual(home.store.state.app, ["cart": 6, "user": "amr"])
        XCTAssertEqual(product.store.state.app, ["cart": 6, "user": "amr"])
        XCTAssertEqual(home.store.state.page, [:])

        // A page's own write still reaches the host, and a page loaded later
        // starts from the scope the host wrote.
        await product.run(.setState(.init(key: "cart", scope: .app, value: 7)))
        XCTAssertEqual(router.appState["cart"], 7)
        let about = try await loaded(router, router.stack[1])
        XCTAssertEqual(PageStub.appState(stub.requests.last!), ["cart": 7, "user": "amr"])
        XCTAssertEqual(about.store.state.app, ["cart": 7, "user": "amr"])
    }

    func test_B9_6_hostWritesAppStateBeforeAnyPageLoaded() async throws {
        let stub = PageStub()
        let router = router(config(), stub)
        router.setAppState("loggedIn", true)
        XCTAssertEqual(router.appState, ["loggedIn": true])
        _ = try await loaded(router, router.root)
        XCTAssertEqual(PageStub.appState(stub.requests[0]), ["loggedIn": true])
    }

    /// A page whose fetch began before the host wrote: it joins with the
    /// host's value, and its own app definitions fill only unset keys.
    func test_B9_6_hostWriteDuringAPageLoadIsKept() throws {
        let router = router(config())
        let body = #"{"pageId":"welcome","title":"","state":[{"key":"cart","scope":"app","initial":1}],"components":[]}"#
        let page = try JSONDecoder().decode(PageResponse.self, from: Data(body.utf8))
        let fetchedWith = router.appState
        router.setAppState("loggedIn", true)

        let model = OrcaPageModel(page: page, store: ElmStore(app: fetchedWith))
        router.attach(model)
        XCTAssertEqual(router.appState, ["loggedIn": true, "cart": 1])
        XCTAssertEqual(model.store.state.app, ["loggedIn": true, "cart": 1])
    }

    func test_B9_7_onRouteChangedBootPushReplacePop() {
        var events: [RouteChangeEvent] = []
        let router = router(config(loggedIn: true)) { events.append($0) }
        XCTAssertEqual(events, [RouteChangeEvent(location: "/welcome", previousLocation: nil, type: .push)])

        router.navigate(to: "/home")
        router.navigate(to: "/home/product/3?ref=a")
        router.navigate(to: "/cart", replace: true)
        router.navigate(to: "/login")
        router.goBack()
        router.navigate(to: "/settings")
        router.navigate(to: "/account")
        router.stack = []  // a back swipe to the root sets the path directly
        XCTAssertEqual(Array(events.dropFirst()), [
            RouteChangeEvent(location: "/home", previousLocation: "/welcome", type: .push),
            RouteChangeEvent(location: "/home/product/3?ref=a", previousLocation: "/home", type: .push),
            RouteChangeEvent(location: "/cart", previousLocation: "/home/product/3?ref=a", type: .replace),
            RouteChangeEvent(location: "/login", previousLocation: "/cart", type: .push),
            RouteChangeEvent(location: "/cart", previousLocation: "/login", type: .pop),
            RouteChangeEvent(location: "/settings", previousLocation: "/cart", type: .push),
            RouteChangeEvent(location: "/account", previousLocation: "/settings", type: .push),
            RouteChangeEvent(location: "/cart", previousLocation: "/account", type: .pop),
        ])
    }

    func test_B9_7_onRouteChangedNoEventForAnUnchangedLocation() {
        var events: [RouteChangeEvent] = []
        let router = router(config()) { events.append($0) }
        events = []
        router.goBack()  // nothing to pop
        router.navigate(to: "/welcome", replace: true)  // the same location by itself
        router.navigate(to: "")
        XCTAssertEqual(events, [])
        XCTAssertEqual(router.top.location, "/welcome")

        // The same location pushed over itself is a new page, not a new
        // location (Flutter drops the same URI twice).
        router.navigate(to: "/welcome")
        XCTAssertEqual(router.stack.count, 1)
        XCTAssertEqual(events, [])
        router.goBack()
        XCTAssertEqual(events, [])
    }

    func test_B9_7_onRouteChangedCarriesTheFinalLocationOfARedirect() {
        var events: [RouteChangeEvent] = []
        let router = router(config(initialRoute: "/account")) { events.append($0) }
        XCTAssertEqual(events, [RouteChangeEvent(location: "/login", previousLocation: nil, type: .push)])
        XCTAssertEqual(router.root.path, "login")

        router.navigate(to: "/home")
        router.navigate(to: "/account?tab=2")  // logged out: redirected
        XCTAssertEqual(router.top.path, "login")
        XCTAssertEqual(events.last, RouteChangeEvent(location: "/login", previousLocation: "/home", type: .push))

        router.setAppState("loggedIn", true)
        XCTAssertEqual(events.count, 3, "a state change does not re-run the redirect")
        router.navigate(to: "account?tab=2", replace: true)
        XCTAssertEqual(router.root.path, "account")
        XCTAssertEqual(events.last,
                       RouteChangeEvent(location: "/account?tab=2", previousLocation: "/login", type: .replace))
    }

    func test_B9_7_onRouteChangedWithoutAConfig() {
        var events: [RouteChangeEvent] = []
        let router = router()
        router.onRouteChanged = { events.append($0) }  // set after boot: later events only
        router.navigate(to: "about")
        router.navigate(to: "/product")
        router.goBack()
        router.navigate(to: "checkout", replace: true)
        router.goBack()
        XCTAssertEqual(events, [
            RouteChangeEvent(location: "/about", previousLocation: "/home", type: .push),
            RouteChangeEvent(location: "/product", previousLocation: "/about", type: .push),
            RouteChangeEvent(location: "/about", previousLocation: "/product", type: .pop),
            RouteChangeEvent(location: "/checkout", previousLocation: "/about", type: .replace),
        ])
    }

    func testConfigBootShowsTheInitialRouteWithTheSeededAppState() async throws {
        let stub = PageStub()
        let router = router(config(), stub)
        XCTAssertEqual(router.root.path, "welcome")
        XCTAssertEqual(router.root.location, "/welcome")
        XCTAssertEqual(router.stack, [])
        XCTAssertFalse(router.root.isNotFound)
        XCTAssertEqual(router.appState, ["loggedIn": false])
        XCTAssertEqual(stub.requests.count, 0, "the router itself fetches nothing")

        let welcome = try await loaded(router, router.root)
        XCTAssertEqual(stub.requests.count, 1)
        XCTAssertTrue(stub.requests[0].url.path.hasSuffix("/page/welcome"))
        XCTAssertEqual(PageStub.appState(stub.requests[0]), ["loggedIn": false])
        XCTAssertEqual(welcome.store.state.app, ["loggedIn": false])
    }

    func testConfigBootOnANestedRouteGivesRootAndStack() {
        let router = router(config(initialRoute: "/home/product/3?ref=a"))
        XCTAssertEqual(router.root.path, "home")
        XCTAssertEqual(router.root.location, "/home")
        XCTAssertEqual(router.stack.map(\.path), ["home/product/3"])
        XCTAssertEqual(router.top.location, "/home/product/3?ref=a")
    }

    func testConfigBootFollowsARedirectOnTheInitialRoute() {
        XCTAssertEqual(router(config(initialRoute: "/account")).root.path, "login")
        XCTAssertEqual(router(config(initialRoute: "/account", loggedIn: true)).root.path, "account")
    }

    func testAnUnknownLocationIsANotFoundRoute() async {
        let stub = PageStub()
        let boot = router(config(initialRoute: "/nowhere"), stub)
        XCTAssertTrue(boot.root.isNotFound)
        XCTAssertEqual(boot.root.location, "/nowhere")

        var events: [RouteChangeEvent] = []
        let router = router(config(), stub) { events.append($0) }
        router.navigate(to: "/missing/page?x=1")
        XCTAssertEqual(router.stack.count, 1)
        XCTAssertTrue(router.top.isNotFound)
        XCTAssertEqual(router.top.location, "/missing/page?x=1")
        XCTAssertEqual(events.last,
                       RouteChangeEvent(location: "/missing/page?x=1", previousLocation: "/welcome", type: .push))
        router.goBack()
        XCTAssertEqual(router.top.path, "welcome")

        router.navigate(to: "/missing", replace: true)
        XCTAssertTrue(router.root.isNotFound)
        XCTAssertEqual(router.stack, [])
        await Task.yield()
        XCTAssertEqual(stub.requests.count, 0, "nothing is fetched for an unknown location")
    }

    func testNavigateWithAConfigPushesOnePageAndReplaceShowsTheChain() {
        let router = router(config(loggedIn: true))
        router.navigate(to: "/home/product/3")
        XCTAssertEqual(router.root.path, "welcome")
        XCTAssertEqual(router.stack.map(\.path), ["home/product/3"], "a push adds the top page only")

        router.navigate(to: "/login")
        router.navigate(to: "/home/product/4?ref=b", replace: true)
        XCTAssertEqual(router.root.path, "home")
        XCTAssertEqual(router.stack.map(\.path), ["home/product/4"])
        XCTAssertEqual(router.stack.map(\.location), ["/home/product/4?ref=b"])
    }

    func testScaffoldTitleAndTransitionAreCarriedByTheTopRoute() {
        let router = router(config(initialRoute: "/home", tabs: true))
        XCTAssertNil(router.root.scaffoldTitle, "a tab route has no title bar")

        router.navigate(to: "/settings")
        XCTAssertEqual(router.top.scaffoldTitle, "Settings")
        XCTAssertEqual(router.top.transition, RouteTransitionDef(type: "fade"))
        router.navigate(to: "/home/product/3")
        XCTAssertNil(router.top.scaffoldTitle)
        XCTAssertNil(router.top.transition)

        router.navigate(to: "/login", replace: true)
        XCTAssertEqual(router.root.scaffoldTitle, "Login")
        XCTAssertNil(self.router(config(initialRoute: "/settings")).root.scaffoldTitle,
                     "without tabs no route is wrapped")
    }

    func testARouteMadeFromAPathKeepsItsDefaults() {
        let route = OrcaRoute("/about")
        XCTAssertEqual(route.path, "about")
        XCTAssertEqual(route.location, "/about")
        XCTAssertNil(route.scaffoldTitle)
        XCTAssertNil(route.transition)
        XCTAssertFalse(route.isNotFound)
    }

    // MARK: - Step 10: tabs, _tabIndex, drawer state

    /// Tabs `/home` (with a child), `/search`, `/more`, and `/settings`
    /// outside the tabs.
    private func tabConfig(initialRoute: String = "/home", drawer: Bool = false,
                           seed: [String: JSONValue] = [:]) -> NavConfig
    {
        NavConfig(
            initialRoute: initialRoute,
            tabs: [TabDef(id: "home", label: "Home", icon: "home", initialRoute: "/home"),
                   TabDef(id: "search", label: "Search", icon: "search", initialRoute: "/search"),
                   TabDef(id: "more", label: "More", icon: "menu", initialRoute: "/more")],
            drawerItems: drawer ? [DrawerItemDef(id: "settings", label: "Settings", route: "/settings")] : [],
            initialAppState: seed,
            flows: [NavFlow(name: "main", routes: [
                NavRoute(path: "home", children: [NavRoute(path: "home/product/:id")]),
                NavRoute(path: "search"),
                NavRoute(path: "more"),
                NavRoute(path: "settings"),
            ])])
    }

    /// The page paths requested so far, in order.
    private func pages(_ stub: PageStub) -> [String] {
        stub.requests.map { $0.url.path.components(separatedBy: "/page/").last ?? "" }
    }

    /// The route's page is still the model it was: not loaded again.
    private func assertSamePage(_ router: OrcaRouter, _ route: OrcaRoute, _ model: OrcaPageModel,
                                line: UInt = #line) async throws
    {
        let now = try await loaded(router, route)
        XCTAssertTrue(now === model, "the page of \(route.path) is another object", line: line)
    }

    func test_B10_2_aTabKeepsItsStackAndItsPagesAcrossASwitch() async throws {
        let stub = PageStub()
        let router = router(tabConfig(), stub)
        XCTAssertTrue(router.hasShell)
        XCTAssertEqual(router.tabs.map(\.id), ["home", "search", "more"])
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.tabStacks.map { $0.map(\.path) }, [["home"], [], []])

        let home = try await loaded(router, router.root)
        router.navigate(to: "/home/product/7")
        let pushed = router.top
        let product = try await loaded(router, pushed)
        XCTAssertEqual(router.stack, [pushed])

        router.selectTab(1)
        XCTAssertEqual(router.currentTab, 1)
        XCTAssertEqual(router.root.path, "search")
        XCTAssertEqual(router.stack, [])
        let search = try await loaded(router, router.root)
        XCTAssertEqual(pages(stub), ["home", "home/product/7", "search"], "a tab's first visit fetches once")

        router.selectTab(0)
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.root.path, "home")
        XCTAssertEqual(router.stack, [pushed], "tab 0 shows its pushed page")
        XCTAssertEqual(router.top.location, "/home/product/7")
        XCTAssertEqual(router.tabStacks.map { $0.map(\.path) }, [["home", "home/product/7"], ["search"], []])
        try await assertSamePage(router, router.root, home)
        try await assertSamePage(router, router.top, product)

        router.selectTab(1)
        try await assertSamePage(router, router.root, search)
        router.selectTab(0)
        XCTAssertEqual(pages(stub), ["home", "home/product/7", "search"], "nothing is fetched again")

        // The selected tab again: it pops to its root, and the popped page goes.
        let productLoader = router.loader(for: pushed)
        router.selectTab(0)
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(router.tabStacks[0].map(\.path), ["home"])
        try await assertSamePage(router, router.root, home)
        XCTAssertFalse(router.loader(for: pushed) === productLoader, "a dropped entry loses its loader")
        XCTAssertEqual(pages(stub), ["home", "home/product/7", "search"])
    }

    func test_B10_2_aShorterPathPopsInsideTheTabAndEventsFollow() {
        var events: [RouteChangeEvent] = []
        let router = router(tabConfig()) { events.append($0) }
        router.navigate(to: "/home/product/1")
        router.navigate(to: "/home/product/2")
        let first = router.stack[0]
        router.stack = [first]  // a back swipe sets the path directly
        XCTAssertEqual(router.tabStacks[0].map(\.path), ["home", "home/product/1"])
        XCTAssertEqual(router.stack, [first])

        router.selectTab(2)
        router.setTabPath(0, [])  // not the tab on screen: nothing
        XCTAssertEqual(router.tabStacks[0].count, 2)
        router.selectTab(0)
        router.setTabPath(0, [first])  // the path as it is: nothing
        XCTAssertEqual(router.tabStacks[0].count, 2)
        router.setTabPath(0, [])
        XCTAssertEqual(router.tabStacks[0].map(\.path), ["home"])
        XCTAssertEqual(router.stack, [])
        router.goBack()  // a tab root: nothing to pop
        XCTAssertEqual(router.currentTab, 0)

        XCTAssertEqual(events, [
            RouteChangeEvent(location: "/home", previousLocation: nil, type: .push),
            RouteChangeEvent(location: "/home/product/1", previousLocation: "/home", type: .push),
            RouteChangeEvent(location: "/home/product/2", previousLocation: "/home/product/1", type: .push),
            RouteChangeEvent(location: "/home/product/1", previousLocation: "/home/product/2", type: .pop),
            RouteChangeEvent(location: "/more", previousLocation: "/home/product/1", type: .replace),
            RouteChangeEvent(location: "/home/product/1", previousLocation: "/more", type: .replace),
            RouteChangeEvent(location: "/home", previousLocation: "/home/product/1", type: .pop),
        ])
    }

    func test_B10_2_aRouteOverTheShellKeepsTheTabAndIsDroppedBySelectTab() {
        let router = router(tabConfig())
        router.navigate(to: "/home/product/1")
        router.navigate(to: "/settings")
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.overRoutes.map(\.path), ["settings"])
        XCTAssertEqual(router.stack.map(\.path), ["home/product/1", "settings"])
        XCTAssertEqual(router.top.scaffoldTitle, "Settings")
        XCTAssertEqual(router.tabStacks[0].count, 2)

        // What a tab's NavigationStack binds: its own pages, then the routes over the shell.
        let product = router.stack[0]
        router.setTabPath(0, [product])
        XCTAssertEqual(router.overRoutes, [])
        XCTAssertEqual(router.stack, [product])

        router.navigate(to: "/settings")
        router.selectTab(1)
        XCTAssertEqual(router.currentTab, 1)
        XCTAssertEqual(router.overRoutes, [])
        XCTAssertEqual(router.top.path, "search")
        XCTAssertEqual(router.tabStacks[0].count, 2, "tab 0 keeps its stack")

        router.navigate(to: "/settings")
        router.selectTab(1)  // the selected tab: the route over the shell goes too
        XCTAssertEqual(router.overRoutes, [])
        XCTAssertEqual(router.top.path, "search")

        // `go` outside the tabs unmounts the shell; `_tabIndex` keeps its value.
        router.navigate(to: "/settings", replace: true)
        XCTAssertFalse(router.hasShell)
        XCTAssertNil(router.currentTab)
        XCTAssertEqual(router.tabStacks.map(\.count), [0, 0, 0])
        XCTAssertEqual(router.root.path, "settings")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(router.appState["_tabIndex"], 1)
        router.selectTab(0)  // no shell: nothing
        XCTAssertEqual(router.root.path, "settings")
    }

    func test_B10_3_tabIndexIsInTheFirstPageRequestAndFollowsEveryTabChange() async throws {
        let stub = PageStub()
        let router = router(tabConfig(initialRoute: "/search", seed: ["_tabIndex": 9, "user": "amr"]), stub)
        XCTAssertEqual(router.appState, ["_tabIndex": 1, "user": "amr"], "the boot write beats the seeded value")
        XCTAssertEqual(stub.requests.count, 0)
        let search = try await loaded(router, router.root)
        XCTAssertEqual(PageStub.appState(stub.requests[0]), ["_tabIndex": 1, "user": "amr"])

        router.selectTab(2)
        XCTAssertEqual(router.appState["_tabIndex"], 2)
        XCTAssertEqual(search.store.state.app["_tabIndex"], 2, "a loaded page of another tab sees it")
        _ = try await loaded(router, router.root)
        XCTAssertEqual(PageStub.appState(stub.requests[1]), ["_tabIndex": 2, "user": "amr"])

        router.switchTab("home")
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.appState["_tabIndex"], 0)
        router.navigate(to: "/more", replace: true)
        XCTAssertEqual(router.currentTab, 2)
        XCTAssertEqual(router.appState["_tabIndex"], 2)
        router.selectTab(1)
        XCTAssertEqual(router.appState["_tabIndex"], 1)
        XCTAssertEqual(search.store.state.app["_tabIndex"], 1)

        router.switchTab("nowhere")  // an unknown tab: nothing
        router.navigate(to: "/settings")  // over the shell: the index stays
        XCTAssertEqual(router.currentTab, 1)
        XCTAssertEqual(router.appState["_tabIndex"], 1)
    }

    func test_B10_3_aPageWritingTabIndexSwitchesTheTab() async throws {
        var events: [RouteChangeEvent] = []
        let stub = PageStub()
        let router = router(tabConfig(), stub) { events.append($0) }
        let home = try await loaded(router, router.root)
        router.navigate(to: "/home/product/7")
        let pushed = router.top
        events = []

        await home.run(.setState(.init(key: "_tabIndex", scope: .app, value: 2)))
        XCTAssertEqual(router.currentTab, 2)
        XCTAssertEqual(router.root.path, "more")
        XCTAssertEqual(router.appState["_tabIndex"], 2)
        XCTAssertEqual(events, [RouteChangeEvent(location: "/more", previousLocation: "/home/product/7",
                                                 type: .replace)])
        let more = try await loaded(router, router.root)
        XCTAssertEqual(more.store.state.app["_tabIndex"], 2)

        // Back to a visited tab: its stack as it was left, nothing fetched.
        await more.run(.setState(.init(key: "_tabIndex", scope: .app, value: 0)))
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.stack, [pushed])
        XCTAssertEqual(home.store.state.app["_tabIndex"], 0)
        XCTAssertEqual(pages(stub), ["home", "more"])

        // The same index, a non-int and an index out of range move nothing;
        // the value stays as written until the next tab change.
        events = []
        for value: JSONValue in [0, "x", 7, -1, 1.5] {
            await home.run(.setState(.init(key: "_tabIndex", scope: .app, value: value)))
            XCTAssertEqual(router.currentTab, 0)
            XCTAssertEqual(router.stack, [pushed])
            XCTAssertEqual(router.appState["_tabIndex"], value)
        }
        XCTAssertEqual(events, [])
        router.selectTab(1)
        XCTAssertEqual(router.appState["_tabIndex"], 1)
        XCTAssertEqual(home.store.state.app["_tabIndex"], 1)

        // The host writing it switches too.
        router.setAppState("_tabIndex", 2)
        XCTAssertEqual(router.currentTab, 2)
        XCTAssertEqual(router.root.path, "more")
    }

    func test_B10_3_switchTabActionSwitchesAndLandsOnTheRoot() async throws {
        let stub = PageStub()
        let router = router(tabConfig(), stub)
        let home = try await loaded(router, router.root)
        router.navigate(to: "/home/product/7")
        router.navigate(to: "/settings")

        await home.run(.switchTab(.init(tabId: "search")))
        XCTAssertEqual(router.currentTab, 1)
        XCTAssertEqual(router.root.path, "search")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(router.overRoutes, [], "what lay over the shell is dropped")
        XCTAssertEqual(router.appState["_tabIndex"], 1)
        XCTAssertEqual(router.tabStacks[0].map(\.path), ["home", "home/product/7"])
        let search = try await loaded(router, router.root)

        await search.run(.switchTab(.init(tabId: "home")))
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.stack, [], "it lands on the tab's root")
        XCTAssertEqual(router.tabStacks[0].map(\.path), ["home"])
        XCTAssertEqual(router.appState["_tabIndex"], 0)
        try await assertSamePage(router, router.root, home)
        XCTAssertEqual(pages(stub), ["home", "search"])

        await home.run(.switchTab(.init(tabId: "nowhere")))
        XCTAssertEqual(router.currentTab, 0)
    }

    func test_B10_3_openDrawerOpensTheShellDrawerOnATabPageOnly() async throws {
        let router = router(tabConfig(drawer: true))
        XCTAssertTrue(router.hasDrawer)
        XCTAssertFalse(router.isDrawerOpen)
        let home = try await loaded(router, router.root)
        await home.run(.openDrawer)
        XCTAssertTrue(router.isDrawerOpen)
        XCTAssertNil(router.pageDrawerRequest)
        router.closeDrawer()
        XCTAssertFalse(router.isDrawerOpen)

        // A navigation that changes the visible location closes it.
        router.openDrawer()
        router.selectTab(1)
        XCTAssertFalse(router.isDrawerOpen)
        router.openDrawer()
        router.navigate(to: "/settings")
        XCTAssertFalse(router.isDrawerOpen)

        // Over the shell there is no shell drawer: the page is asked.
        let settings = try await loaded(router, router.top)
        await settings.run(.openDrawer)
        XCTAssertFalse(router.isDrawerOpen)
        XCTAssertEqual(router.pageDrawerRequest, router.top.id)
    }

    func test_B10_3_openDrawerWithoutAShellDrawerAsksThePage() async throws {
        let router = router(tabConfig())
        XCTAssertFalse(router.hasDrawer)
        let home = try await loaded(router, router.root)
        await home.run(.openDrawer)
        XCTAssertFalse(router.isDrawerOpen)
        XCTAssertEqual(router.pageDrawerRequest, router.root.id)

        // Drawer items without tabs are no shell drawer.
        var noTabs = config()
        noTabs.drawerItems = [DrawerItemDef(id: "a", label: "A", route: "/login")]
        XCTAssertFalse(self.router(noTabs).hasDrawer)
    }

    func test_B10_3_withoutTabsThereIsNoShell() {
        for router in [router(), router(config())] {
            XCTAssertFalse(router.hasShell)
            XCTAssertEqual(router.tabs, [])
            XCTAssertNil(router.currentTab)
            XCTAssertEqual(router.tabStacks, [])
            XCTAssertFalse(router.hasDrawer)
            let root = router.root
            router.selectTab(0)
            router.switchTab("home")
            router.setTabPath(0, [])
            XCTAssertEqual(router.root, root)
            XCTAssertEqual(router.stack, [])
            XCTAssertNil(router.appState["_tabIndex"])
        }
    }

    // MARK: - Step 10 rework: the Kotlin router's twin behavior

    /// A not-found route's path drops only the query, as Kotlin's does
    /// (`c4_aNotFoundRoutesPathDropsOnlyTheQuery`).
    func test_c4_aNotFoundRoutesPathDropsOnlyTheQuery() {
        let router = router(config())
        router.navigate(to: "/missing#top?x=1")
        XCTAssertTrue(router.top.isNotFound)
        XCTAssertEqual(router.top.path, "missing#top")
        XCTAssertEqual(router.top.location, "/missing#top?x=1")
    }

    /// A stack set by the host with routes added: each is pushed through the
    /// shell by its location and stays the route given, with and without tabs.
    func test_B10_2_aStackWrittenWithAnAddedRouteIsPushedThroughTheShell() {
        var events: [RouteChangeEvent] = []
        let plain = router(config(loggedIn: true)) { events.append($0) }
        let settings = OrcaRoute("/settings")
        plain.stack = [settings]
        XCTAssertEqual(plain.stack, [settings], "the added route is kept, not put back")
        XCTAssertEqual(plain.top.id, settings.id)
        XCTAssertEqual(plain.top.location, "/settings")
        XCTAssertEqual(plain.overRoutes.map(\.path), ["welcome", "settings"])
        XCTAssertEqual(plain.overRoutes.last?.id, settings.id, "the shell's entry is the route given")
        let loader = plain.loader(for: settings)
        plain.navigate(to: "/login")
        XCTAssertTrue(plain.loader(for: plain.stack[0]) === loader, "the given route keeps its page")
        plain.goBack()
        plain.goBack()
        XCTAssertEqual(plain.stack, [], "the shell pops what the host pushed")
        XCTAssertEqual(Array(events.dropFirst()), [
            RouteChangeEvent(location: "/settings", previousLocation: "/welcome", type: .push),
            RouteChangeEvent(location: "/login", previousLocation: "/settings", type: .push),
            RouteChangeEvent(location: "/settings", previousLocation: "/login", type: .pop),
            RouteChangeEvent(location: "/welcome", previousLocation: "/settings", type: .pop),
        ])

        // With tabs: a tab's route goes on the tab's stack, another over the shell.
        events = []
        let tabbed = router(tabConfig()) { events.append($0) }
        let product = OrcaRoute("/home/product/1")
        let over = OrcaRoute("/settings")
        tabbed.stack = [product, over]
        XCTAssertEqual(tabbed.stack, [product, over])
        XCTAssertEqual(tabbed.tabStacks[0].map(\.path), ["home", "home/product/1"])
        XCTAssertEqual(tabbed.tabStacks[0].last?.id, product.id)
        XCTAssertEqual(tabbed.overRoutes, [over])
        XCTAssertEqual(tabbed.currentTab, 0)

        // The top route swapped for another: one pop, one push.
        let other = OrcaRoute("/home/product/2")
        tabbed.stack = [product, other]
        XCTAssertEqual(tabbed.stack, [product, other])
        XCTAssertEqual(tabbed.overRoutes, [])
        XCTAssertEqual(tabbed.tabStacks[0].map(\.path), ["home", "home/product/1", "home/product/2"])
        tabbed.stack = [product]  // shorter: a pop
        XCTAssertEqual(tabbed.tabStacks[0].map(\.path), ["home", "home/product/1"])
        XCTAssertEqual(Array(events.dropFirst()), [
            RouteChangeEvent(location: "/settings", previousLocation: "/home", type: .push),
            RouteChangeEvent(location: "/home/product/2", previousLocation: "/settings", type: .push),
            RouteChangeEvent(location: "/home/product/1", previousLocation: "/home/product/2", type: .pop),
        ])

        // A tab's own path stays pop-only: a longer one changes nothing.
        tabbed.setTabPath(0, [product, OrcaRoute("/settings")])
        XCTAssertEqual(tabbed.stack, [product])
        XCTAssertEqual(tabbed.overRoutes, [])
    }

    /// The page drawer request goes with its route.
    func test_B10_3_thePageDrawerRequestIsClearedWhenItsRouteIsDropped() {
        let tabbed = router(tabConfig())
        tabbed.navigate(to: "/settings")
        tabbed.openDrawer()
        XCTAssertEqual(tabbed.pageDrawerRequest, tabbed.top.id)
        tabbed.navigate(to: "/home/product/1")  // the asked route is still on the stack
        XCTAssertEqual(tabbed.pageDrawerRequest, tabbed.stack[0].id)
        tabbed.goBack()
        tabbed.goBack()
        XCTAssertNil(tabbed.pageDrawerRequest)

        // Without a config too.
        let plain = router()
        plain.navigate(to: "about")
        plain.openDrawer()
        XCTAssertEqual(plain.pageDrawerRequest, plain.top.id)
        plain.goBack()
        XCTAssertNil(plain.pageDrawerRequest)
    }

    /// The shell drawer closes when the visible location changes, not when
    /// another page shows the same location.
    func test_B10_3_theShellDrawerClosesOnlyWhenTheVisibleLocationChanges() {
        let router = router(tabConfig(drawer: true))
        router.openDrawer()
        XCTAssertTrue(router.isDrawerOpen)
        let home = router.top
        router.navigate(to: "/home")  // another page, the same location
        XCTAssertNotEqual(router.top.id, home.id)
        XCTAssertEqual(router.top.location, "/home")
        XCTAssertTrue(router.isDrawerOpen, "the same location keeps the drawer open")
        router.goBack()
        XCTAssertTrue(router.isDrawerOpen)

        router.navigate(to: "/home/product/1")
        XCTAssertFalse(router.isDrawerOpen, "another location closes it")
    }
}
#endif
