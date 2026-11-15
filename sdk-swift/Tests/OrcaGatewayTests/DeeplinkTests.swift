#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// A `BootStub` whose `/config` answer waits until `release()`: the config
/// fetch of a boot test stays under way for as long as the test needs.
final class HeldConfigStub: HTTPTransport, @unchecked Sendable {
    let stub: BootStub
    private let lock = NSLock()
    private var released = false

    init(_ stub: BootStub) {
        self.stub = stub
    }

    func release() {
        lock.lock()
        released = true
        lock.unlock()
    }

    private var isReleased: Bool {
        lock.lock()
        defer { lock.unlock() }
        return released
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let response = try await stub.send(request)
        if request.url.path.hasSuffix("/config") {
            while !isReleased { try await Task.sleep(nanoseconds: 2_000_000) }
        }
        return response
    }
}

/// Step 11: deep links through `OrcaRouter.handleDeeplink` (what `OrcaApp`'s
/// `.onOpenURL` and `.onContinueUserActivity` call once the app runs) and
/// through `OrcaAppBoot.receive` (what they call, whatever the boot's
/// phase; the public `handleDeeplink` is the host's door to the same). The modifiers themselves need a real app: hand-check.
/// schema/fixtures/navigation/15_deep_links.json pins the pure part.
@MainActor
final class DeeplinkTests: XCTestCase {
    /// What the two callbacks said, in the order they said it.
    private final class Log {
        var lines: [String] = []
        var routes: [RouteChangeEvent] = []
        var links: [DeeplinkEvent] = []

        func route(_ event: RouteChangeEvent) {
            routes.append(event)
            lines.append("route \(event.location)")
        }

        func link(_ event: DeeplinkEvent) {
            links.append(event)
            lines.append("link \(event.resolvedLocation)")
        }
    }

    private func url(_ text: String) throws -> URL {
        try XCTUnwrap(URL(string: text), text)
    }

    /// `/welcome` first, a nested child, a protected route, an order with a
    /// param; tabs `/home` and `/cart` when asked, `settings` outside them.
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
                NavRoute(path: "settings"),
                NavRoute(path: "order/:id"),
                NavRoute(path: "account",
                         redirect: RedirectRule(when: "loggedIn", equals: false, to: "/login")),
            ])])
    }

    /// The same config as the server sends it.
    private var configJSON: JSONValue {
        [
            "initialRoute": "/welcome",
            "tabs": [],
            "initialAppState": ["loggedIn": false, "plan": "free"],
            "flows": [["name": "main", "routes": [
                ["path": "welcome"], ["path": "login"], ["path": "settings"], ["path": "order/:id"],
                ["path": "account", "redirect": ["when": "loggedIn", "equals": false, "to": "/login"]],
            ]]],
        ]
    }

    private func router(_ config: NavConfig, _ stub: PageStub = PageStub(), _ log: Log,
                        link: URL? = nil) -> OrcaRouter
    {
        OrcaRouter(client: PageStub.client(stub), config: config, system: SystemRecorder().actions(),
                   onRouteChanged: log.route, onDeeplink: log.link, link: link)
    }

    private func boot(_ client: OrcaClient, path: String?, _ log: Log) -> OrcaAppBoot {
        OrcaAppBoot(client: client, path: path, system: SystemRecorder().actions(),
                    onRouteChanged: log.route, onDeeplink: log.link)
    }

    private func ready(_ boot: OrcaAppBoot) throws -> OrcaRouter {
        guard case .ready(let router) = boot.phase else {
            throw NSError(domain: "DeeplinkTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "the boot is not ready: \(boot.phase)"])
        }
        return router
    }

    private func loaded(_ router: OrcaRouter, _ route: OrcaRoute) async throws -> OrcaPageModel {
        let loader = router.loader(for: route)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "DeeplinkTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
        }
        return model
    }

    private func pages(_ requests: [HTTPRequest]) -> [String] {
        requests.filter { $0.url.path.contains("/page/") }
            .map { $0.url.path.components(separatedBy: "/page/").last ?? "" }
    }

    /// Put a view in a window and let it run for a moment.
    private func host<V: View>(_ view: V) async throws {
        let size = CGRect(x: 0, y: 0, width: 390, height: 700)
        #if canImport(UIKit)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: size)
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = size
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 500_000_000)
        #elseif canImport(AppKit)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.setFrame(size, display: true)
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 500_000_000)
        window.orderOut(nil)
        #endif
    }

    // MARK: - L2 a warm link

    func test_B11_2_aWarmLinkIsAGoAndTheEventFollowsTheRouteEventOnce() async throws {
        let stub = PageStub()
        let log = Log()
        let router = router(config(), stub, log)
        _ = try await loaded(router, router.root)
        router.navigate(to: "/login")  // a push: the link must not keep it
        log.lines = []

        let link = try url("https://shop.example/settings/?tab=2&ref=mail#top")
        router.handleDeeplink(link)
        XCTAssertEqual(router.root.location, "/settings?tab=2&ref=mail")
        XCTAssertEqual(router.root.path, "settings")
        XCTAssertEqual(router.stack, [], "a go: nothing of the old stack is under the link")
        XCTAssertEqual(log.lines, ["route /settings?tab=2&ref=mail", "link /settings?tab=2&ref=mail"],
                       "the link event comes once, after the route event")
        XCTAssertEqual(log.routes.last, RouteChangeEvent(
            location: "/settings?tab=2&ref=mail", previousLocation: "/login", type: .replace))
        XCTAssertEqual(log.links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/settings?tab=2&ref=mail", pathParameters: [:],
            queryParameters: ["tab": "2", "ref": "mail"], wasRedirected: false, isColdStart: false)])

        // A nested route: the stack comes from the config, parent under child.
        let product = try url("orcashop://open/home/product/42")
        router.handleDeeplink(product)
        XCTAssertEqual(router.root.path, "home")
        XCTAssertEqual(router.stack.map(\.path), ["home/product/42"])
        XCTAssertEqual(log.links.count, 2)
        XCTAssertEqual(log.links[1], DeeplinkEvent(
            incoming: product, resolvedLocation: "/home/product/42", pathParameters: ["id": "42"],
            queryParameters: [:], wasRedirected: false, isColdStart: false))
        XCTAssertEqual(Array(log.lines.suffix(2)), ["route /home/product/42", "link /home/product/42"])

        _ = try await loaded(router, router.top)
        XCTAssertEqual(pages(stub.requests), ["welcome", "home/product/42"],
                       "the settings page was never shown, so never asked for")
    }

    func test_B11_2_linksNavigateWithoutACallback() throws {
        let router = OrcaRouter(client: PageStub.client(PageStub()), config: config(),
                                system: SystemRecorder().actions())
        XCTAssertNil(router.onDeeplink)
        router.handleDeeplink(try url("orcashop://open/order/7?gift=1"))
        XCTAssertEqual(router.top.location, "/order/7?gift=1")

        // The callback is a property, as `onRouteChanged`: set later, it sees
        // the links that follow.
        var seen: [DeeplinkEvent] = []
        router.onDeeplink = { seen.append($0) }
        router.handleDeeplink(try url("orcashop://open/settings"))
        XCTAssertEqual(seen.map(\.resolvedLocation), ["/settings"])
    }

    func test_B11_2_aLinkIntoATabSelectsTheTabAndALinkToANonTabRouteLeavesTheShell() async throws {
        let stub = PageStub()
        let log = Log()
        let router = router(config(initialRoute: "/home", tabs: true), stub, log)
        XCTAssertEqual(router.currentTab, 0)
        _ = try await loaded(router, router.root)

        router.handleDeeplink(try url("https://shop.example/cart"))
        XCTAssertTrue(router.hasShell)
        XCTAssertEqual(router.currentTab, 1, "the link's tab is the selected one")
        XCTAssertEqual(router.appState["_tabIndex"], .int(1))
        XCTAssertEqual(router.top.location, "/cart")
        XCTAssertEqual(log.links.map(\.resolvedLocation), ["/cart"])
        _ = try await loaded(router, router.top)
        XCTAssertEqual(pages(stub.requests), ["home", "cart"])
        XCTAssertEqual(PageStub.appState(stub.requests[1])?["_tabIndex"], .int(1),
                       "the tab index is in the linked page's request")

        // A child of a tab's route: over its parent, in the parent's tab.
        router.handleDeeplink(try url("https://shop.example/home/product/42"))
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.root.path, "home")
        XCTAssertEqual(router.stack.map(\.path), ["home/product/42"])

        // A route outside the tabs: a go leaves the shell, one stack.
        router.handleDeeplink(try url("https://shop.example/settings"))
        XCTAssertFalse(router.hasShell, "a link to a non-tab route is shown without the tab bar")
        XCTAssertEqual(router.root.location, "/settings")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(router.root.scaffoldTitle, "Settings")
        XCTAssertEqual(log.links.map(\.resolvedLocation), ["/cart", "/home/product/42", "/settings"])
        XCTAssertEqual(Array(log.lines.suffix(2)), ["route /settings", "link /settings"])
    }

    // MARK: - L6 the location on screen

    func test_B11_2_aLinkToTheLocationOnScreenNavigatesNothingAndStillCallsBack() async throws {
        let stub = PageStub()
        let log = Log()
        let router = router(config(), stub, log)
        let welcome = router.root
        let model = try await loaded(router, welcome)
        log.lines = []

        let link = try url("orcashop://open/welcome/")
        router.handleDeeplink(link)
        XCTAssertEqual(router.root.id, welcome.id, "the same route, not a new one")
        XCTAssertEqual(router.stack, [])
        let again = try await loaded(router, router.root)
        XCTAssertTrue(again === model, "the page is not loaded again")
        XCTAssertEqual(stub.requests.count, 1, "nothing is requested")
        XCTAssertEqual(log.lines, ["link /welcome"], "no route event, and the callback all the same")
        XCTAssertEqual(log.links, [DeeplinkEvent(incoming: link, resolvedLocation: "/welcome")])

        // Redirected onto the location on screen: nothing moves either.
        router.navigate(to: "/login", replace: true)
        let login = router.root
        log.lines = []
        router.handleDeeplink(try url("https://shop.example/account?from=mail"))
        XCTAssertEqual(router.root.id, login.id)
        XCTAssertEqual(log.lines, ["link /login"])
        XCTAssertEqual(log.links.last?.wasRedirected, true)

        // Without a config too.
        let plainStub = PageStub()
        let plain = OrcaRouter(client: PageStub.client(plainStub), path: "home",
                               system: SystemRecorder().actions())
        var routes: [RouteChangeEvent] = []
        var links: [DeeplinkEvent] = []
        plain.onRouteChanged = { routes.append($0) }
        plain.onDeeplink = { links.append($0) }
        let home = plain.root
        _ = try await loaded(plain, home)
        plain.handleDeeplink(try url("https://shop.example/home"))
        XCTAssertEqual(plain.root.id, home.id)
        XCTAssertEqual(plainStub.requests.count, 1)
        XCTAssertEqual(routes, [])
        XCTAssertEqual(links.map(\.resolvedLocation), ["/home"])
    }

    func test_B11_2_withoutAConfigEveryLinkedPathIsAPage() async throws {
        let stub = PageStub()
        let router = OrcaRouter(client: PageStub.client(stub), path: "home", system: SystemRecorder().actions())
        var lines: [String] = []
        var links: [DeeplinkEvent] = []
        router.onRouteChanged = { lines.append("route \($0.location) \($0.type)") }
        router.onDeeplink = {
            links.append($0)
            lines.append("link \($0.resolvedLocation)")
        }
        router.navigate(to: "about")
        lines = []

        let link = try url("orcashop://open/product/42/?gift=1&note=a+b#top")
        router.handleDeeplink(link)
        XCTAssertEqual(router.root.path, "product/42", "the page path has no query")
        XCTAssertEqual(router.root.location, "/product/42?gift=1&note=a+b")
        XCTAssertFalse(router.root.isNotFound)
        XCTAssertEqual(router.stack, [], "a go")
        XCTAssertEqual(lines, ["route /product/42?gift=1&note=a+b replace", "link /product/42?gift=1&note=a+b"])
        XCTAssertEqual(links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/product/42?gift=1&note=a+b", pathParameters: [:],
            queryParameters: ["gift": "1", "note": "a b"], wasRedirected: false, isColdStart: false)])

        _ = try await loaded(router, router.root)
        XCTAssertEqual(stub.requests.count, 1)
        XCTAssertTrue(stub.requests[0].url.path.hasSuffix("/page/product/42"))
    }

    // MARK: - L3 a protected route

    func test_B11_3_aProtectedLinkIsRedirectedWarmAndCold() async throws {
        let link = try url("https://shop.example/account?from=mail")

        // Warm, logged out: the rule's target, the asked query dropped.
        let stub = PageStub()
        let log = Log()
        let router = router(config(), stub, log)
        log.lines = []
        router.handleDeeplink(link)
        XCTAssertEqual(router.root.location, "/login")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(log.lines, ["route /login", "link /login"])
        XCTAssertEqual(log.links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/login", pathParameters: [:], queryParameters: [:],
            wasRedirected: true, isColdStart: false)])
        _ = try await loaded(router, router.root)
        XCTAssertEqual(pages(stub.requests), ["login"], "the protected page is never asked for")

        // Logged in: the link's own location, not redirected.
        router.setAppState("loggedIn", true)
        router.handleDeeplink(link)
        XCTAssertEqual(router.root.location, "/account?from=mail")
        XCTAssertEqual(log.links.last, DeeplinkEvent(
            incoming: link, resolvedLocation: "/account?from=mail", pathParameters: [:],
            queryParameters: ["from": "mail"], wasRedirected: false, isColdStart: false))

        // Cold, logged out: the router boots at the rule's target.
        let coldStub = PageStub()
        let coldLog = Log()
        let cold = self.router(config(), coldStub, coldLog, link: link)
        XCTAssertEqual(cold.root.location, "/login")
        XCTAssertEqual(cold.stack, [])
        XCTAssertEqual(coldLog.lines, ["route /login", "link /login"])
        XCTAssertEqual(coldLog.routes, [RouteChangeEvent(location: "/login", previousLocation: nil, type: .push)])
        XCTAssertEqual(coldLog.links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/login", pathParameters: [:], queryParameters: [:],
            wasRedirected: true, isColdStart: true)])
        _ = try await loaded(cold, cold.root)
        XCTAssertEqual(pages(coldStub.requests), ["login"], "neither the initial route nor the protected one")

        // Cold, logged in by the config's initial app state: let through.
        let inLog = Log()
        let loggedIn = self.router(config(loggedIn: true), PageStub(), inLog, link: link)
        XCTAssertEqual(loggedIn.root.location, "/account?from=mail")
        XCTAssertEqual(inLog.links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/account?from=mail", pathParameters: [:],
            queryParameters: ["from": "mail"], wasRedirected: false, isColdStart: true)])
    }

    // MARK: - L4 an unknown link

    func test_B11_4_anUnknownLinkIsNotFoundRequestsNothingAndTheButtonGoesHome() async throws {
        let stub = PageStub()
        let log = Log()
        let router = router(config(), stub, log)
        log.lines = []

        let link = try url("https://shop.example/nowhere/?x=1")
        router.handleDeeplink(link)
        XCTAssertTrue(router.top.isNotFound)
        XCTAssertEqual(router.top.location, "/nowhere?x=1", "the asked location is kept")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(log.lines, ["route /nowhere?x=1", "link /nowhere?x=1"])
        XCTAssertEqual(log.links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/nowhere?x=1", pathParameters: [:],
            queryParameters: ["x": "1"], wasRedirected: false, isColdStart: false)])

        try await host(OrcaApp(router: router))
        XCTAssertEqual(stub.requests.count, 0, "an unknown link fetches nothing")

        // "Go to home page": a go to "/", as Flutter's default screen.
        let page = RoutePage(router: router, route: router.top)
        XCTAssertEqual(RoutePage.homeButtonTitle, "Go to home page")
        router.navigate(to: "/login")  // something on the stack: a go drops it
        page.goHome()
        XCTAssertEqual(router.root.location, "/")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(log.routes.last, RouteChangeEvent(location: "/", previousLocation: "/login", type: .replace))

        // Cold: the app starts on the not-found page, and asks for nothing.
        let coldStub = PageStub()
        let coldLog = Log()
        let cold = self.router(config(), coldStub, coldLog, link: link)
        XCTAssertTrue(cold.root.isNotFound)
        XCTAssertEqual(cold.root.location, "/nowhere?x=1")
        XCTAssertEqual(coldLog.lines, ["route /nowhere?x=1", "link /nowhere?x=1"])
        XCTAssertEqual(coldLog.links.first?.wasRedirected, false)
        XCTAssertEqual(coldLog.links.first?.isColdStart, true)
        try await host(OrcaApp(router: cold))
        XCTAssertEqual(coldStub.requests.count, 0)
    }

    // MARK: - L5 a cold start

    func test_B11_1_aColdLinkIsHeldDuringTheConfigFetchAndTheAppBootsAtIt() async throws {
        let stub = BootStub(config: configJSON)
        let held = HeldConfigStub(stub)
        let client = OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                                device: DeviceInfo(osVersion: "test"), transport: held)
        let log = Log()
        let boot = boot(client, path: nil, log)

        let start = Task { await boot.startIfNeeded() }
        while stub.configRequests.isEmpty { try await Task.sleep(nanoseconds: 2_000_000) }
        let link = try url("orcashop://open/order/7?gift=1")
        boot.handleDeeplink(link)
        guard case .loading = boot.phase else { return XCTFail("the fetch is still under way") }
        XCTAssertEqual(log.lines, [], "nothing is said while the link is held")

        held.release()
        await start.value
        let router = try ready(boot)
        XCTAssertEqual(router.root.location, "/order/7?gift=1", "the app starts at the link, not at /welcome")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(log.lines, ["route /order/7?gift=1", "link /order/7?gift=1"])
        XCTAssertEqual(log.routes, [RouteChangeEvent(location: "/order/7?gift=1", previousLocation: nil, type: .push)])
        XCTAssertEqual(log.links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/order/7?gift=1", pathParameters: ["id": "7"],
            queryParameters: ["gift": "1"], wasRedirected: false, isColdStart: true)])
        XCTAssertEqual(router.appState, ["loggedIn": false, "plan": "free"], "seeded first")

        // Hosted: the one page asked for is the link's.
        try await host(OrcaApp(router: router))
        XCTAssertEqual(stub.configRequests.count, 1)
        XCTAssertEqual(pages(stub.requests), ["order/7"], "one page request, and not the initial route's")
        XCTAssertEqual(PageStub.appState(stub.pageRequests[0]), ["loggedIn": false, "plan": "free"])

        // The first route is on screen: a link from now on is warm.
        boot.firstRouteAppeared()
        let later = try url("orcashop://open/settings")
        boot.handleDeeplink(later)
        XCTAssertEqual(router.root.location, "/settings")
        XCTAssertEqual(log.links.count, 2)
        XCTAssertEqual(log.links[1], DeeplinkEvent(incoming: later, resolvedLocation: "/settings"))
    }

    func test_B11_1_aLinkBeforeTheBootStartsOrWhileItFailedIsNotLost() async throws {
        // Before the fetch began (the version check is still on screen).
        let early = BootStub(config: configJSON)
        let earlyLog = Log()
        let waiting = boot(BootStub.client(early), path: nil, earlyLog)
        let link = try url("https://shop.example/account")
        waiting.handleDeeplink(link)
        XCTAssertEqual(early.requests.count, 0, "a held link starts nothing")
        await waiting.startIfNeeded()
        XCTAssertEqual(try ready(waiting).root.location, "/login")
        XCTAssertEqual(earlyLog.lines, ["route /login", "link /login"])
        XCTAssertEqual(earlyLog.links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/login", wasRedirected: true, isColdStart: true)])

        // While the boot failed: kept through the retry; the last link wins.
        let stub = BootStub(config: configJSON, configFailures: 2)
        let log = Log()
        let boot = boot(BootStub.client(stub), path: nil, log)
        boot.handleDeeplink(try url("orcashop://open/settings"))
        await boot.startIfNeeded()
        guard case .failed = boot.phase else { return XCTFail("the first fetch fails") }
        let second = try url("orcashop://open/order/9")
        boot.handleDeeplink(second)
        await boot.retry()
        guard case .failed = boot.phase else { return XCTFail("the second fetch fails") }
        XCTAssertEqual(log.lines, [])
        await boot.retry()
        let router = try ready(boot)
        XCTAssertEqual(router.root.location, "/order/9")
        XCTAssertEqual(log.lines, ["route /order/9", "link /order/9"])
        XCTAssertEqual(log.links, [DeeplinkEvent(
            incoming: second, resolvedLocation: "/order/9", pathParameters: ["id": "9"], isColdStart: true)])
        _ = try await loaded(router, router.root)
        XCTAssertEqual(pages(stub.requests), ["order/9"])
    }

    func test_B11_1_withoutALinkTheBootIsAsBeforeAndALaterLinkIsWarm() async throws {
        let stub = BootStub(config: configJSON)
        let log = Log()
        let boot = boot(BootStub.client(stub), path: nil, log)
        await boot.startIfNeeded()
        let router = try ready(boot)
        XCTAssertEqual(router.root.location, "/welcome")
        XCTAssertEqual(log.lines, ["route /welcome"], "no link, no link event")
        boot.firstRouteAppeared()

        let link = try url("orcashop://open/settings")
        boot.handleDeeplink(link)
        XCTAssertEqual(router.root.location, "/settings")
        XCTAssertEqual(log.lines, ["route /welcome", "route /settings", "link /settings"])
        XCTAssertEqual(log.links, [DeeplinkEvent(incoming: link, resolvedLocation: "/settings")])
    }

    func test_B11_1_aColdLinkReplacesTheHostsPath() async throws {
        let stub = BootStub(config: configJSON)
        let log = Log()
        let boot = boot(BootStub.client(stub), path: "shop", log)
        let router = try ready(boot)  // ready at once, nothing shown yet

        let link = try url("orcashop://open/product/42?gift=1")
        boot.receive(link)  // the view's delivery, before the first route showed
        XCTAssertTrue(try ready(boot) === router)
        XCTAssertEqual(router.root.path, "product/42")
        XCTAssertEqual(router.root.location, "/product/42?gift=1")
        XCTAssertEqual(router.stack, [])
        XCTAssertEqual(log.lines, ["link /product/42?gift=1"],
                       "the app boots AT the link: no route event from a host path that never showed")
        XCTAssertEqual(log.links, [DeeplinkEvent(
            incoming: link, resolvedLocation: "/product/42?gift=1", queryParameters: ["gift": "1"],
            isColdStart: true)])

        try await host(OrcaApp(router: router))
        XCTAssertEqual(stub.configRequests.count, 0)
        XCTAssertEqual(pages(stub.requests), ["product/42"], "one page request, and not the host path's")

        // Only the link that opened the app is cold.
        let later = try url("orcashop://open/about")
        boot.receive(later)
        XCTAssertEqual(router.root.location, "/about")
        XCTAssertEqual(log.links.last, DeeplinkEvent(incoming: later, resolvedLocation: "/about"))
        XCTAssertEqual(log.routes, [RouteChangeEvent(
            location: "/about", previousLocation: "/product/42?gift=1", type: .replace)],
                       "the first route event is from the link's location")

        // A link after the first route appeared is warm.
        let warmLog = Log()
        let shown = self.boot(BootStub.client(BootStub(config: configJSON)), path: "shop", warmLog)
        shown.firstRouteAppeared()
        shown.receive(link)
        XCTAssertEqual(try ready(shown).root.location, "/product/42?gift=1")
        XCTAssertEqual(warmLog.links.map(\.isColdStart), [false])
        XCTAssertEqual(warmLog.lines, ["route /product/42?gift=1", "link /product/42?gift=1"])
    }

    func test_B11_1_aHostDrivingTheBootGetsEveryLinkToAReadyRouterWarm() throws {
        // A host with its own view never calls the internal
        // `firstRouteAppeared()`: with a router, its links are warm, however
        // late the first one comes (Kotlin `OrcaAppBoot.handleDeeplink`).
        let log = Log()
        let boot = boot(BootStub.client(BootStub(config: configJSON)), path: "shop", log)
        let link = try url("orcashop://open/product/42")
        boot.handleDeeplink(link)
        XCTAssertEqual(try ready(boot).root.location, "/product/42")
        XCTAssertEqual(log.lines, ["route /product/42", "link /product/42"])
        XCTAssertEqual(log.links.map(\.isColdStart), [false])

        let router = OrcaRouter(client: PageStub.client(PageStub()), config: config(),
                                system: SystemRecorder().actions())
        var seen: [DeeplinkEvent] = []
        router.onDeeplink = { seen.append($0) }
        let hosted = OrcaAppBoot(router: router)
        hosted.handleDeeplink(try url("orcashop://open/settings"))
        XCTAssertEqual(seen.map(\.isColdStart), [false])

        // The view's own delivery before the first route showed is the cold one.
        var viewSeen: [DeeplinkEvent] = []
        let other = OrcaRouter(client: PageStub.client(PageStub()), config: config(),
                               system: SystemRecorder().actions())
        other.onDeeplink = { viewSeen.append($0) }
        let viewBoot = OrcaAppBoot(router: other)
        viewBoot.receive(try url("orcashop://open/settings"))
        viewBoot.receive(try url("orcashop://open/login"))
        XCTAssertEqual(viewSeen.map(\.isColdStart), [true, false])
    }

    // MARK: - A router made with `link:`

    func test_B11_1_aPathRouterMadeWithALinkBootsAtItWithoutARouteEvent() async throws {
        let stub = PageStub()
        var lines: [String] = []
        let link = try url("orcashop://open/product/42?gift=1")
        let router = OrcaRouter(client: PageStub.client(stub), path: "shop", system: SystemRecorder().actions(),
                                onDeeplink: { lines.append("link \($0.resolvedLocation) \($0.isColdStart)") },
                                link: link)
        router.onRouteChanged = { lines.append("route \($0.location) from \($0.previousLocation ?? "nil")") }
        XCTAssertEqual(router.root.location, "/product/42?gift=1")
        XCTAssertEqual(router.root.path, "product/42")
        XCTAssertEqual(lines, ["link /product/42?gift=1 true"])
        _ = try await loaded(router, router.root)
        XCTAssertEqual(pages(stub.requests), ["product/42"], "the host path is never asked for")
        router.navigate(to: "about")
        XCTAssertEqual(lines.last, "route /about from /product/42?gift=1")
    }

    func test_B11_1_aRouterMadeWithALinkIgnoresOneRepeatOfItWhileOnTheBootLocation() throws {
        // `OrcaApp(router:)`: the system may hand the launch URL to
        // `.onOpenURL` too. The repeat navigates nothing and is not reported.
        let link = try url("orcashop://open/order/7?gift=1")
        let log = Log()
        let router = router(config(), PageStub(), log, link: link)
        XCTAssertEqual(log.lines, ["route /order/7?gift=1", "link /order/7?gift=1"])
        let boot = OrcaAppBoot(router: router)
        boot.receive(link)
        XCTAssertEqual(log.lines, ["route /order/7?gift=1", "link /order/7?gift=1"], "the repeat is dropped")
        XCTAssertEqual(router.root.location, "/order/7?gift=1")
        // Only one: the same link again is a link.
        boot.receive(link)
        XCTAssertEqual(log.links.map(\.isColdStart), [true, false])

        // Another URL first: no repeat is waited for any more.
        let otherLog = Log()
        let other = self.router(config(), PageStub(), otherLog, link: link)
        other.handleDeeplink(try url("orcashop://open/order/7?gift=1#top"))
        other.handleDeeplink(link)
        XCTAssertEqual(otherLog.links.count, 3)

        // Away from the boot location: the same URL is a link like any other.
        let movedLog = Log()
        let moved = self.router(config(), PageStub(), movedLog, link: link)
        moved.navigate(to: "/settings", replace: true)
        moved.handleDeeplink(link)
        XCTAssertEqual(moved.root.location, "/order/7?gift=1")
        XCTAssertEqual(movedLog.links.map(\.isColdStart), [true, false])

        // A path router made with a link, the same.
        var seen: [DeeplinkEvent] = []
        let plain = OrcaRouter(client: PageStub.client(PageStub()), path: "shop",
                               system: SystemRecorder().actions(), onDeeplink: { seen.append($0) }, link: link)
        plain.handleDeeplink(link)
        XCTAssertEqual(seen.count, 1)
        plain.handleDeeplink(link)
        XCTAssertEqual(seen.count, 2)
    }

    func test_B11_1_aLinkTheBootHeldIsNotWaitedForAgain() async throws {
        // The held link WAS the system's delivery: the same link tapped
        // again is reported.
        let log = Log()
        let boot = boot(BootStub.client(BootStub(config: configJSON)), path: nil, log)
        let link = try url("orcashop://open/settings")
        boot.receive(link)
        await boot.startIfNeeded()
        boot.receive(link)
        XCTAssertEqual(log.lines, ["route /settings", "link /settings", "link /settings"])
        XCTAssertEqual(log.links.map(\.isColdStart), [true, false])
    }

    func test_B11_1_aHostsRouterGetsTheLinksAndKeepsItsOwnCallback() throws {
        let router = OrcaRouter(client: PageStub.client(PageStub()), config: config(),
                                system: SystemRecorder().actions())
        var seen: [DeeplinkEvent] = []
        router.onDeeplink = { seen.append($0) }
        let boot = OrcaAppBoot(router: router)
        boot.firstRouteAppeared()

        let link = try url("orcashop://open/settings")
        boot.handleDeeplink(link)
        XCTAssertEqual(router.root.location, "/settings")
        XCTAssertEqual(seen, [DeeplinkEvent(incoming: link, resolvedLocation: "/settings")])
    }
}
#endif
