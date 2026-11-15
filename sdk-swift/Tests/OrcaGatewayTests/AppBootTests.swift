#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// `/config` and pages by path, for boot tests: the config is the JSON given,
/// the first `configFailures` asks for it answer 500, and a page is
/// `{pageId, title, state, components}` with one Text node. A path's title
/// is `titles[path]`, else the path. Every request is kept.
final class BootStub: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private var failuresLeft: Int
    private let config: JSONValue
    private let titles: [String: String]

    init(config: JSONValue, configFailures: Int = 0, titles: [String: String] = [:]) {
        self.config = config
        self.failuresLeft = configFailures
        self.titles = titles
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    var configRequests: [HTTPRequest] { requests.filter { $0.url.path.hasSuffix("/config") } }
    var pageRequests: [HTTPRequest] { requests.filter { $0.url.path.contains("/page/") } }

    /// Records the request; true when this ask for the config must fail.
    private func record(_ request: HTTPRequest, isConfig: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _requests.append(request)
        guard isConfig, failuresLeft > 0 else { return false }
        failuresLeft -= 1
        return true
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let path = request.url.path
        let isConfig = path.hasSuffix("/config")
        let fails = record(request, isConfig: isConfig)
        if isConfig {
            if fails { return HTTPResponse(status: 500, body: Data("config is down".utf8)) }
            return HTTPResponse(status: 200, body: try config.encoded())
        }
        let name = path.components(separatedBy: "/page/").last ?? ""
        let page: JSONValue = [
            "pageId": .string(name), "title": .string(titles[name] ?? name),
            "state": [],
            "components": [["id": "0", "type": "Text", "kind": "primitive", "childMode": "none",
                            "props": ["data": .string(name)], "children": [], "watches": []]],
        ]
        return HTTPResponse(status: 200, body: try page.encoded())
    }

    static func client(_ stub: BootStub) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   device: DeviceInfo(osVersion: "test"), transport: stub)
    }
}

/// Step 9: `OrcaApp` boots from the server config, and a route outside the
/// tabs is drawn with a title bar.
@MainActor
final class AppBootTests: XCTestCase {
    /// The config as the server sends it: `/welcome` first, `loggedIn` seeded,
    /// tabs `/home` and `/cart` when asked, `settings` outside them.
    private func config(tabs: Bool = false, initialRoute: String = "/welcome") -> JSONValue {
        let tabDefs: [JSONValue] = tabs ? [
            ["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"],
            ["id": "cart", "label": "Cart", "icon": "cart", "initialRoute": "/cart"],
        ] : []
        return [
            "initialRoute": .string(initialRoute),
            "tabs": .array(tabDefs),
            "initialAppState": ["loggedIn": false, "plan": "free"],
            "flows": [["name": "main", "routes": [
                ["path": "welcome"], ["path": "home"], ["path": "cart"], ["path": "settings"],
            ]]],
        ]
    }

    /// `path` nil is the config boot; a host says so, it is not the default.
    private func boot(_ stub: BootStub, path: String?,
                      onRouteChanged: ((RouteChangeEvent) -> Void)? = nil) -> OrcaAppBoot
    {
        OrcaAppBoot(client: BootStub.client(stub), path: path, system: SystemRecorder().actions(),
                    onRouteChanged: onRouteChanged)
    }

    private func ready(_ boot: OrcaAppBoot) throws -> OrcaRouter {
        guard case .ready(let router) = boot.phase else {
            throw NSError(domain: "AppBootTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "the boot is not ready: \(boot.phase)"])
        }
        return router
    }

    private func loaded(_ router: OrcaRouter, _ route: OrcaRoute) async throws -> OrcaPageModel {
        let loader = router.loader(for: route)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "AppBootTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
        }
        return model
    }

    /// Put a view in a window and let it run for a moment. On macOS the
    /// navigation title on top is the window's title, given back; nil on
    /// iOS, where the test does not read the bar.
    private func host<V: View>(_ view: V) async throws -> String? {
        let size = CGRect(x: 0, y: 0, width: 390, height: 700)
        #if canImport(UIKit)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: size)
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = size
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 500_000_000)
        return nil
        #elseif canImport(AppKit)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.setFrame(size, display: true)
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 500_000_000)
        let title = window.title
        window.orderOut(nil)
        return title
        #endif
    }

    func test_B9_1_bootFetchesTheConfigOnceAndOpensItsInitialRoute() async throws {
        let stub = BootStub(config: config())
        var events: [RouteChangeEvent] = []
        let boot = boot(stub, path: nil) { events.append($0) }
        guard case .loading = boot.phase else { return XCTFail("a config boot starts loading") }
        XCTAssertEqual(stub.requests.count, 0)

        await boot.startIfNeeded()
        let router = try ready(boot)
        XCTAssertEqual(stub.configRequests.count, 1)
        XCTAssertTrue(stub.requests[0].url.path.hasSuffix("/api/v1/app/fixture-app/config"))
        XCTAssertEqual(stub.requests[0].method, "GET")
        XCTAssertEqual(stub.pageRequests.count, 0, "the boot fetches no page")
        XCTAssertNotNil(router.table)
        XCTAssertEqual(router.root.location, "/welcome")
        XCTAssertEqual(events, [RouteChangeEvent(location: "/welcome", previousLocation: nil, type: .push)])

        _ = try await loaded(router, router.root)
        XCTAssertEqual(stub.pageRequests.count, 1)
        XCTAssertTrue(stub.pageRequests[0].url.path.hasSuffix("/page/welcome"),
                      "the first page is the config's initial route, not home")

        // Asked again (the view appears again): the same router, no new fetch.
        await boot.startIfNeeded()
        XCTAssertTrue(try ready(boot) === router)
        XCTAssertEqual(stub.configRequests.count, 1)
    }

    func test_B9_1_aHostPathSkipsTheConfig() async throws {
        let stub = BootStub(config: config())
        var events: [RouteChangeEvent] = []
        let boot = boot(stub, path: "shop") { events.append($0) }
        let router = try ready(boot)  // ready at once: nothing to wait for
        await boot.startIfNeeded()
        XCTAssertTrue(try ready(boot) === router)
        XCTAssertNil(router.table)
        XCTAssertEqual(router.root.path, "shop")

        _ = try await loaded(router, router.root)
        XCTAssertEqual(stub.configRequests.count, 0)
        XCTAssertEqual(stub.requests.count, 1)
        XCTAssertTrue(stub.requests[0].url.path.hasSuffix("/page/shop"))

        router.navigate(to: "about")
        XCTAssertEqual(events, [RouteChangeEvent(location: "/about", previousLocation: "/shop", type: .push)])

        // No path argument at all: `home`, as before the config boot existed.
        let plainStub = BootStub(config: config())
        let plain = OrcaAppBoot(client: BootStub.client(plainStub))
        let home = try ready(plain)  // ready at once here too
        await plain.startIfNeeded()
        XCTAssertTrue(try ready(plain) === home)
        XCTAssertNil(home.table)
        XCTAssertEqual(home.root.path, "home")
        _ = try await loaded(home, home.root)
        XCTAssertEqual(plainStub.configRequests.count, 0, "the default asks for no config")
        XCTAssertEqual(plainStub.requests.count, 1)
        XCTAssertTrue(plainStub.requests[0].url.path.hasSuffix("/page/home"))
    }

    func test_B9_1_aFailedConfigFetchCanBeRetried() async throws {
        let stub = BootStub(config: config(), configFailures: 1)
        let boot = boot(stub, path: nil)
        await boot.startIfNeeded()
        guard case .failed(let message) = boot.phase else {
            return XCTFail("a failed config fetch is the failed phase, got \(boot.phase)")
        }
        XCTAssertEqual(message, "HTTP 500: config is down")
        XCTAssertEqual(stub.pageRequests.count, 0)

        await boot.startIfNeeded()  // started already: only a retry fetches again
        XCTAssertEqual(stub.configRequests.count, 1)

        await boot.retry()
        let router = try ready(boot)
        XCTAssertEqual(stub.configRequests.count, 2)
        XCTAssertEqual(router.root.path, "welcome")
    }

    func test_B9_5_initialAppStateIsSeededBeforeTheFirstPageAndSentWithIt() async throws {
        let stub = BootStub(config: config())
        let boot = boot(stub, path: nil)
        await boot.startIfNeeded()
        let router = try ready(boot)
        XCTAssertEqual(router.appState, ["loggedIn": false, "plan": "free"])
        XCTAssertEqual(stub.pageRequests.count, 0, "seeded before any page request")

        let welcome = try await loaded(router, router.root)
        XCTAssertEqual(stub.pageRequests[0].method, "POST")
        XCTAssertEqual(PageStub.appState(stub.pageRequests[0]), ["loggedIn": false, "plan": "free"])
        XCTAssertEqual(welcome.store.state.app, ["loggedIn": false, "plan": "free"])
    }

    func test_B9_8_aNonTabRouteHasATitleBarWithTheFallbackThenThePageTitle() async throws {
        let stub = BootStub(config: config(tabs: true, initialRoute: "/home"),
                            titles: ["settings": "Your settings"])
        let boot = boot(stub, path: nil)
        await boot.startIfNeeded()
        let router = try ready(boot)
        let home = router.root
        XCTAssertNil(home.barTitle(router.loader(for: home).phase), "a tab route has no title bar")

        router.navigate(to: "/settings")
        let settings = router.top
        XCTAssertEqual(router.stack.count, 1, "pushed, so the bar has a back button")
        let loader = router.loader(for: settings)
        XCTAssertEqual(settings.barTitle(loader.phase), "Settings", "the fallback before the page loads")
        XCTAssertEqual(settings.barTitle(.failed("down")), "Settings")

        _ = try await loaded(router, settings)
        XCTAssertEqual(settings.barTitle(loader.phase), "Your settings", "the page's title once loaded")
        _ = try await loaded(router, home)
        XCTAssertNil(home.barTitle(router.loader(for: home).phase))

        // Hosted, on a router whose pages the views load themselves: the
        // pushed page's navigation title ends as the page's title.
        let second = self.boot(stub, path: nil)
        await second.startIfNeeded()
        let fresh = try ready(second)
        fresh.navigate(to: "/settings")
        if let shown = try await host(OrcaApp(router: fresh)) {
            XCTAssertEqual(shown, "Your settings")
        }
        XCTAssertTrue(stub.pageRequests.last?.url.path.hasSuffix("/page/settings") ?? false,
                      "the hosted app loaded the pushed page")
    }

    func test_B10_1_bootingIntoATabShowsTheShell() async throws {
        let stub = BootStub(config: config(tabs: true, initialRoute: "/cart"))
        let boot = boot(stub, path: nil)
        await boot.startIfNeeded()
        let router = try ready(boot)
        XCTAssertTrue(router.hasShell)
        XCTAssertEqual(router.currentTab, 1, "the initial route's tab is the selected one")
        let shell = TabShellModel(router: router)
        XCTAssertEqual(shell.items.map(\.label), ["Home", "Cart"])
        XCTAssertEqual(shell.items.map(\.symbol), ["house.fill", "cart.fill"])
        XCTAssertEqual(shell.selection, 1)
        XCTAssertFalse(shell.usesServerBar)
        XCTAssertNil(shell.root(of: 0), "the other tab is not visited yet")

        _ = try await host(OrcaApp(router: router))
        XCTAssertEqual(stub.pageRequests.map { $0.url.path.components(separatedBy: "/page/").last },
                       ["cart"], "only the selected tab's page is fetched")
        XCTAssertEqual(stub.configRequests.count, 1)

        // A config without tabs has no shell: the single stack of step 9.
        let plain = self.boot(BootStub(config: config()), path: nil)
        await plain.startIfNeeded()
        XCTAssertFalse(try ready(plain).hasShell)
    }

    func test_aNotFoundRouteRequestsNoPage() async throws {
        let stub = BootStub(config: config(initialRoute: "/nowhere"))
        let boot = boot(stub, path: nil)
        await boot.startIfNeeded()
        let router = try ready(boot)
        XCTAssertTrue(router.root.isNotFound)
        router.navigate(to: "/missing/page?x=1")
        XCTAssertTrue(router.top.isNotFound)

        _ = try await host(OrcaApp(router: router))
        XCTAssertEqual(stub.pageRequests.count, 0, "an unknown location fetches nothing")
        XCTAssertEqual(stub.configRequests.count, 1)
    }
}
#endif
