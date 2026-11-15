#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// The engine for the app-shell tests: `/version` answers a fresh check, or
/// a forceUpdate one; `/config` opens `initialRoute`, or answers 500; both
/// take a moment, so a screen shown meanwhile is drawn. A page is `plain`
/// (one EnvProbe), `scaffold` (a Scaffold whose body is an EnvProbe), and a
/// 404 for any other name. Every request is kept.
final class ShellStub: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private let forceUpdate: Bool
    private let configFails: Bool
    private let initialRoute: String

    init(forceUpdate: Bool = false, configFails: Bool = false, initialRoute: String = "/plain") {
        self.forceUpdate = forceUpdate
        self.configFails = configFails
        self.initialRoute = initialRoute
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    var pageRequests: [HTTPRequest] { requests.filter { $0.url.path.contains("/page/") } }

    private func record(_ request: HTTPRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }

    static func probe(_ id: String) -> JSONValue {
        ["id": .string(id), "type": "EnvProbe", "kind": "primitive", "childMode": "none",
         "props": [:], "children": [], "watches": []]
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        record(request)
        let path = request.url.path
        if path.hasSuffix("/version") {
            try await Task.sleep(nanoseconds: 150_000_000)
            let answer: JSONValue = ["flows": [:], "forceUpdate": .bool(forceUpdate)]
            return HTTPResponse(status: 200, body: try answer.encoded())
        }
        if path.hasSuffix("/config") {
            try await Task.sleep(nanoseconds: 150_000_000)
            if configFails { return HTTPResponse(status: 500, body: Data("config is down".utf8)) }
            let config: JSONValue = [
                "initialRoute": .string(initialRoute),
                "flows": [["name": "main", "routes": [["path": "plain"], ["path": "scaffold"]]]],
            ]
            return HTTPResponse(status: 200, body: try config.encoded())
        }
        let name = path.components(separatedBy: "/page/").last ?? ""
        let components: [JSONValue]
        switch name {
        case "plain":
            components = [Self.probe("plain")]
        case "scaffold":
            components = [
                ["id": "s", "type": "Scaffold", "kind": "structure", "childMode": "none",
                 "props": ["body": "inScaffold"], "children": ["inScaffold"], "watches": []],
                Self.probe("inScaffold"),
            ]
        default:
            return HTTPResponse(status: 404, body: Data("no page here".utf8))
        }
        let page: JSONValue = [
            "pageId": .string(name), "title": .string(name), "state": [], "components": .array(components),
        ]
        return HTTPResponse(status: 200, body: try page.encoded())
    }

    /// A client over this stub. With `DeviceInfo()` the app sends this
    /// device's headers, as a host client does.
    func client(device: DeviceInfo = DeviceInfo(osVersion: "test")) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   device: device, transport: self)
    }
}

/// What the host's views and the pages' probes saw: each one's name as it
/// appeared, with the colour scheme and locale it read, and every error the
/// host's error view was given.
@MainActor
final class Seen {
    struct Sight {
        let name: String
        let scheme: ColorScheme
        let locale: String
    }

    var sights: [Sight] = []
    var errors: [Error] = []

    var names: [String] { sights.map(\.name) }

    func first(_ name: String) -> Sight? { sights.first { $0.name == name } }

    func saw(_ name: String, _ scheme: ColorScheme, _ locale: Locale) {
        sights.append(Sight(name: name, scheme: scheme, locale: locale.identifier))
    }
}

/// A host view, or a page's EnvProbe: its name, drawn; on appearing it
/// tells `seen` the colour scheme and locale it reads.
struct HostScreen: View {
    let name: String
    let seen: Seen
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: name).onAppear { seen.saw(name, scheme, locale) }
    }
}

/// C18.1 and C18.3: OrcaApp's host boot views (Flutter `OrcaApp.loadingWidget`,
/// `splashWidget`, `errorBuilder`, `forceUpdateBuilder`, used by
/// `_buildSplash`, `_buildError` and `_buildForceUpdate` in
/// sdk/lib/src/widgets/orca_app.dart, at boot only), and its colour scheme and
/// locale (Flutter `OrcaMaterialAppConfig.themeMode` and `locale`), which
/// reach everything the app draws but a Scaffold, kept light as Flutter's
/// builders wrap it in `Theme(data: ThemeData())`. No header changes.
@MainActor
final class AppShellTests: XCTestCase {
    let spinner = ProgressView<EmptyView, EmptyView>.self
    let conflict = #"Widget type "ColoredBadge" from plugin "b" conflicts with plugin "a"."#

    func screen(_ name: String, _ seen: Seen) -> () -> AnyView {
        { AnyView(HostScreen(name: name, seen: seen)) }
    }

    func errorScreen(_ seen: Seen) -> (Error) -> AnyView {
        { error in
            seen.errors.append(error)
            return AnyView(HostScreen(name: "error", seen: seen))
        }
    }

    /// The host widgets of these tests: an EnvProbe draws a HostScreen named
    /// by its node id.
    func probes(_ seen: Seen) -> WidgetBuilders {
        let widgets = WidgetBuilders()
        widgets.register("EnvProbe") { node, _ in AnyView(HostScreen(name: node.id, seen: seen)) }
        return widgets
    }

    func configBoot(_ stub: ShellStub) -> OrcaAppBoot {
        OrcaAppBoot(client: stub.client(), path: nil, system: SystemRecorder().actions(), onRouteChanged: nil)
    }

    func gate(offline: Bool, failure: String? = nil) -> OrcaBootModel {
        OrcaBootModel(enableOffline: offline, store: MemoryKeyValueStore(), failure: failure)
    }

    /// Puts `view` in a 390x700 window until `done` holds (two seconds at
    /// most) and `settle` seconds more, then takes it away.
    func host<V: View>(_ view: V, settle: Double = 0, until done: () -> Bool) async throws {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        #if canImport(UIKit)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: frame)
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = frame
        controller.view.layoutIfNeeded()
        defer { window.isHidden = true }
        #elseif canImport(AppKit)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        #endif
        var waited = 0
        while !done(), waited < 200 {
            waited += 1
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let finished = done()
        XCTAssertTrue(finished, "timed out")
        try await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
    }

    // MARK: C18.1

    func testC18_1_AHostSplashViewShowsWhileTheVersionCheckRunsAndWhileTheConfigLoads() async throws {
        let seen = Seen()
        let views = BootViews(loading: screen("loading", seen), splash: screen("splash", seen))
        let checking = gate(offline: true)
        XCTAssertEqual(checking.phase, .checking)
        let stub = ShellStub()
        let gateView = OrcaBootView(boot: checking, client: stub.client(), views: views) { Text("page") }
        XCTAssertEqual(ViewTree.first(HostScreen.self, in: gateView)?.name, "splash")
        XCTAssertNil(ViewTree.first(spinner, in: gateView))

        let loading = AppBootContent(boot: configBoot(stub), views: views)
        XCTAssertEqual(ViewTree.first(HostScreen.self, in: loading)?.name, "splash")
        XCTAssertNil(ViewTree.first(spinner, in: loading))

        // Without host views: the SDK's spinner in both places, as before.
        let plainGate = OrcaBootView(boot: gate(offline: true), client: stub.client()) { Text("page") }
        XCTAssertNotNil(ViewTree.first(spinner, in: plainGate))
        XCTAssertNotNil(ViewTree.first(spinner, in: AppBootContent(boot: configBoot(stub))))

        // Through OrcaApp: the version check, then /config, then the page.
        let app = OrcaApp(client: stub.client(), path: nil, enableOffline: true, widgets: probes(seen),
                          loadingView: screen("loading", seen), splashView: screen("splash", seen))
        try await host(app) { seen.names.contains("plain") }
        XCTAssertEqual(seen.names, ["splash", "splash", "plain"])
        XCTAssertEqual(stub.requests.map { $0.url.lastPathComponent }, ["version", "config", "plain"])
    }

    func testC18_1_WithOnlyALoadingViewThatViewShowsInBothPlaces() async throws {
        let seen = Seen()
        let views = BootViews(loading: screen("loading", seen))
        let stub = ShellStub()
        let gateView = OrcaBootView(boot: gate(offline: true), client: stub.client(), views: views) { Text("page") }
        XCTAssertEqual(ViewTree.first(HostScreen.self, in: gateView)?.name, "loading")
        let loading = AppBootContent(boot: configBoot(stub), views: views)
        XCTAssertEqual(ViewTree.first(HostScreen.self, in: loading)?.name, "loading")
        XCTAssertNil(ViewTree.first(spinner, in: loading))

        // The router init: the version check, then the page.
        let router = OrcaRouter(client: stub.client(), path: "plain", system: SystemRecorder().actions())
        let app = OrcaApp(router: router, enableOffline: true, widgets: probes(seen),
                          loadingView: screen("loading", seen))
        try await host(app) { seen.names.contains("plain") }
        XCTAssertEqual(seen.names, ["loading", "plain"])
    }

    func testC18_1_AHostErrorViewGetsTheConfigBootsErrorAndThePluginConflict() async throws {
        let seen = Seen()
        let views = BootViews(error: errorScreen(seen))
        let stub = ShellStub(configFails: true)
        let boot = configBoot(stub)
        await boot.startIfNeeded()
        guard case .failed("HTTP 500: config is down") = boot.phase else { return XCTFail("not failed: \(boot.phase)") }

        let failed = AppBootContent(boot: boot, views: views)
        XCTAssertEqual(ViewTree.first(HostScreen.self, in: failed)?.name, "error")
        XCTAssertNil(ViewTree.first(OrcaErrorView.self, in: failed), "only the host's view, no retry")
        let error = try XCTUnwrap(seen.errors.first)
        XCTAssertEqual(error as? OrcaClientError, .http(status: 500, body: "config is down"))
        XCTAssertEqual(OrcaErrorInfo(error).title, "Server Error")

        seen.errors = []
        let conflicted = OrcaBootView(boot: gate(offline: false, failure: conflict), client: stub.client(),
                                      views: views) { Text("page") }
        XCTAssertEqual(ViewTree.first(HostScreen.self, in: conflicted)?.name, "error")
        XCTAssertNil(ViewTree.first(OrcaErrorView.self, in: conflicted))
        XCTAssertEqual(seen.errors.first as? OrcaPluginConflict, OrcaPluginConflict(message: conflict))

        // Without a host error view: OrcaErrorView, with a retry for the config.
        let plain = try XCTUnwrap(ViewTree.first(OrcaErrorView.self, in: AppBootContent(boot: boot)))
        XCTAssertEqual(plain.info.title, "Server Error")
        XCTAssertNotNil(plain.retry)

        // Through both of OrcaApp's inits.
        seen.errors = []
        let configStub = ShellStub(configFails: true)
        try await host(OrcaApp(client: configStub.client(), path: nil, errorView: errorScreen(seen))) {
            seen.names.contains("error")
        }
        XCTAssertEqual(seen.errors.first as? OrcaClientError, .http(status: 500, body: "config is down"))
        XCTAssertEqual(seen.names.first, "error")

        seen.errors = []
        let routerStub = ShellStub()
        let router = OrcaRouter(client: routerStub.client(), path: "plain", system: SystemRecorder().actions())
        let plugins: [OrcaPlugin] = [OrcaAppPluginTests.NamedBadgePlugin(name: "a"),
                                     OrcaAppPluginTests.NamedBadgePlugin(name: "b")]
        try await host(OrcaApp(router: router, plugins: plugins, errorView: errorScreen(seen))) {
            !seen.errors.isEmpty
        }
        XCTAssertEqual(seen.errors.first as? OrcaPluginConflict, OrcaPluginConflict(message: conflict))
        XCTAssertEqual(routerStub.requests, [], "nothing is fetched")
    }

    func testC18_1_AHostForceUpdateViewReplacesTheDefault() async throws {
        let seen = Seen()
        let stub = ShellStub(forceUpdate: true)
        let blocked = gate(offline: true)
        await blocked.start(client: stub.client())
        XCTAssertEqual(blocked.phase, .forceUpdate)

        let hostView = OrcaBootView(boot: blocked, client: stub.client(),
                                    views: BootViews(forceUpdate: screen("forceUpdate", seen))) { Text("page") }
        XCTAssertEqual(ViewTree.first(HostScreen.self, in: hostView)?.name, "forceUpdate")
        XCTAssertNil(ViewTree.first(ForceUpdateView.self, in: hostView))
        let plain = OrcaBootView(boot: blocked, client: stub.client()) { Text("page") }
        XCTAssertNotNil(ViewTree.first(ForceUpdateView.self, in: plain), "the default without one")

        let appStub = ShellStub(forceUpdate: true)
        let app = OrcaApp(client: appStub.client(), path: "plain", enableOffline: true, widgets: probes(seen),
                          splashView: screen("splash", seen), forceUpdateView: screen("forceUpdate", seen))
        try await host(app, settle: 0.2) { seen.names.contains("forceUpdate") }
        XCTAssertEqual(seen.names, ["splash", "forceUpdate"])
        XCTAssertEqual(appStub.pageRequests, [], "no page is fetched")
    }

    func testC18_1_PagesUnderOrcaAppKeepTheSDKSpinnerAndErrorView() async throws {
        let seen = Seen()
        let views = BootViews(loading: screen("loading", seen), splash: screen("splash", seen),
                              error: errorScreen(seen), forceUpdate: screen("forceUpdate", seen))
        let stub = ShellStub()
        let router = OrcaRouter(client: stub.client(), path: "missing", system: SystemRecorder().actions())
        let ready = OrcaAppBoot(router: router)
        let stack = AppBootContent(boot: ready, views: views)
        XCTAssertNotNil(ViewTree.first(spinner, in: stack), "a page loading shows the SDK's spinner")
        XCTAssertNil(ViewTree.first(HostScreen.self, in: stack))

        await router.loader(for: router.root).loadIfNeeded()
        let screen404 = try XCTUnwrap(ViewTree.first(OrcaErrorView.self, in: AppBootContent(boot: ready, views: views)))
        XCTAssertEqual(screen404.info.title, "Not Found")
        XCTAssertNotNil(screen404.retry, "a page keeps its retry")
        XCTAssertTrue(seen.errors.isEmpty, "a page 404 does not reach the host's error view")

        // Through OrcaApp.
        let appStub = ShellStub()
        let app = OrcaApp(client: appStub.client(), path: "missing", loadingView: screen("loading", seen),
                          splashView: screen("splash", seen), errorView: errorScreen(seen),
                          forceUpdateView: screen("forceUpdate", seen))
        try await host(app, settle: 0.3) { appStub.pageRequests.count == 1 }
        XCTAssertTrue(seen.errors.isEmpty, "a page 404 does not reach the host's error view")
        XCTAssertEqual(seen.names, [], "no host boot view is drawn for a page")
    }

    // MARK: C18.3

    func testC18_3_WithColorSchemeDarkTheAppReadsDarkAndAScaffoldPageReadsLight() async throws {
        let seen = Seen()
        let app = OrcaApp(client: ShellStub().client(), path: nil, enableOffline: true, widgets: probes(seen),
                          splashView: screen("splash", seen), colorScheme: .dark)
        try await host(app.environment(\.colorScheme, .light)) { seen.names.contains("plain") }
        XCTAssertEqual(seen.names, ["splash", "splash", "plain"])
        XCTAssertEqual(seen.sights.map(\.scheme), [.dark, .dark, .dark], "the boot screens and the page read dark")

        let scaffold = Seen()
        let router = OrcaRouter(client: ShellStub().client(), path: "scaffold", system: SystemRecorder().actions())
        let scaffoldApp = OrcaApp(router: router, widgets: probes(scaffold), colorScheme: .dark)
        try await host(scaffoldApp) { scaffold.names.contains("inScaffold") }
        XCTAssertEqual(scaffold.first("inScaffold")?.scheme, .light, "a Scaffold stays light, as in Flutter")

        // nil follows the host; a scheme given wins over it.
        let follows = Seen()
        let plain = OrcaApp(client: ShellStub().client(), path: "plain", widgets: probes(follows))
        try await host(plain.environment(\.colorScheme, .dark)) { follows.names.contains("plain") }
        XCTAssertEqual(follows.first("plain")?.scheme, .dark)

        let light = Seen()
        let lightApp = OrcaApp(client: ShellStub().client(), path: "plain", widgets: probes(light),
                               colorScheme: .light)
        try await host(lightApp.environment(\.colorScheme, .dark)) { light.names.contains("plain") }
        XCTAssertEqual(light.first("plain")?.scheme, .light)
    }

    func testC18_3_WithALocaleAPageSeesItAndTheHeaderStaysTheDevices() async throws {
        let chosen = Locale.current.identifier.hasPrefix("fr") ? "ja_JP" : "fr_FR"
        let device = try XCTUnwrap(DeviceInfo.current().locale)
        XCTAssertNotEqual(device, chosen)

        let seen = Seen()
        let stub = ShellStub()
        let app = OrcaApp(client: stub.client(device: DeviceInfo()), path: nil, enableOffline: true,
                          widgets: probes(seen), splashView: screen("splash", seen),
                          locale: Locale(identifier: chosen))
        try await host(app) { seen.names.contains("plain") }
        XCTAssertEqual(seen.sights.map(\.locale), [chosen, chosen, chosen], "the boot screens and the page")
        XCTAssertEqual(stub.pageRequests.count, 1)
        XCTAssertEqual(stub.pageRequests.first?.headers["x-orca-locale"], device, "the page asks with the device's")
        XCTAssertFalse(stub.requests.contains { $0.headers["x-orca-locale"] == chosen }, "no request sends it")

        let routed = Seen()
        let routerStub = ShellStub()
        let router = OrcaRouter(client: routerStub.client(device: DeviceInfo()), path: "plain",
                                system: SystemRecorder().actions())
        try await host(OrcaApp(router: router, widgets: probes(routed), locale: Locale(identifier: chosen))) {
            routed.names.contains("plain")
        }
        XCTAssertEqual(routed.first("plain")?.locale, chosen)
        XCTAssertEqual(routerStub.pageRequests.first?.headers["x-orca-locale"], device)
    }
}
#endif
