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
}
#endif
