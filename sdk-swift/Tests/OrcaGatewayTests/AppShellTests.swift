#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// The engine for the app-shell tests: `/version` answers a fresh check, or
/// a forceUpdate one; `/config` opens `initialRoute`, or answers 500; both
/// take a moment, so a screen shown meanwhile is drawn. A page is `plain`
/// (one EnvProbe), `scaffold` (a Scaffold whose body is an EnvProbe),
/// `drawer` (a Scaffold whose body is an EnvProbe and whose drawer slot is a
/// Drawer holding another), and a 404 for any other name. Every request is
/// kept.
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
        case "drawer":
            components = [
                ["id": "s", "type": "Scaffold", "kind": "structure", "childMode": "none",
                 "props": ["body": "drawerBody", "drawer": "panel"], "children": ["drawerBody", "panel"],
                 "watches": []],
                Self.probe("drawerBody"),
                ["id": "panel", "type": "Drawer", "kind": "layout", "childMode": "single",
                 "props": [:], "children": ["inDrawer"], "watches": []],
                Self.probe("inDrawer"),
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

    /// A page Scaffold's drawer is drawn by the app root's drawer layer, out
    /// of the Scaffold, yet stays light: Flutter's `_buildScaffold` wraps the
    /// whole Scaffold, its drawer slot too, in `Theme(data: ThemeData())`, and
    /// Android pins its light scheme over the Scaffold and its drawers.
    func testC18_3_APageScaffoldDrawerStaysLightUnderADarkScheme() async throws {
        let seen = Seen()
        let router = OrcaRouter(client: ShellStub().client(), path: "drawer", system: SystemRecorder().actions())
        let app = OrcaApp(router: router, widgets: probes(seen), colorScheme: .dark)
        var asked = false
        try await host(app) {
            if !asked, seen.names.contains("drawerBody") {
                asked = true
                router.openDrawer()
            }
            return seen.names.contains("inDrawer")
        }
        XCTAssertEqual(seen.first("drawerBody")?.scheme, .light, "the Scaffold's body")
        XCTAssertEqual(seen.first("inDrawer")?.scheme, .light, "its drawer, as in Flutter and on Android")
    }

    /// A page Scaffold with no backgroundColor paints its own light
    /// background, as Flutter's Scaffold paints its light theme's: under a
    /// dark scheme no dark window shows through behind its light-pinned
    /// text. A pixel away from the body's Text is the light system
    /// background, opaque (white on iOS); the Text is dark.
    func testC18_3_APageScaffoldDrawsAnOpaqueLightBackgroundUnderADarkScheme() throws {
        let dark = try drawScaffold(scheme: .dark)
        let away = dark.pixel(150, 150)
        XCTAssertEqual(away.a, 255, "no background drawn: \(away)")
        XCTAssertTrue(away.r > 220 && away.g > 220 && away.b > 220, "the background is not light: \(away)")
        #if canImport(UIKit)
        XCTAssertTrue(away.r == 255 && away.g == 255 && away.b == 255, "the background is not white: \(away)")
        #endif
        let text = try XCTUnwrap(dark.bounds(of: Pixels.isInk), "the Text is not dark")
        XCTAssertLessThan(text.maxX, 100, "\(text)")
    }

    /// Under a light scheme the page looks as it did: its background is the
    /// light system background a light window already showed behind it, and
    /// the page under a dark scheme is the same, pixel for pixel.
    func testC18_3_UnderALightSchemeAScaffoldPageLooksAsUnderADarkOne() throws {
        let light = try drawScaffold(scheme: .light)
        let renderer = ImageRenderer(content: systemBackground.frame(width: 10, height: 10)
            .environment(\.colorScheme, .light))
        renderer.scale = 1
        let window = try Pixels(XCTUnwrap(renderer.cgImage)).pixel(5, 5)
        let away = light.pixel(150, 150)
        XCTAssertTrue(away == window, "the background is not the light system background: \(away) vs \(window)")
        XCTAssertNotNil(light.bounds(of: Pixels.isInk), "the Text is not dark")
        let dark = try drawScaffold(scheme: .dark)
        XCTAssertTrue(light.bytes == dark.bytes, "the page differs between the light and the dark scheme")
    }

    /// A Scaffold's own backgroundColor is drawn under a dark scheme as under
    /// a light one.
    func testC18_3_AScaffoldBackgroundColorStaysUnderADarkScheme() throws {
        let green = try drawScaffold(["backgroundColor": "#00FF00"], scheme: .dark)
        let away = green.pixel(150, 150)
        XCTAssertTrue(away.a == 255 && away.g > 240 && away.r < 15 && away.b < 15, "not the backgroundColor: \(away)")
    }

    #if canImport(UIKit)
    /// A page Scaffold's AppBar is a light navigation bar under a dark
    /// scheme, the app's (`colorScheme: .dark`) or the device's: the bar is
    /// drawn with the light scheme, over the Scaffold's light background,
    /// its title dark on it. An AppBar backgroundColor still fills the bar.
    func testC18_3_APageAppBarIsALightNavigationBarUnderADarkScheme() throws {
        for (scheme, style) in [(ColorScheme?.some(.dark), UIUserInterfaceStyle.light), (nil, .dark)] {
            let hosted = try hostScaffold(appBar: [:], scheme: scheme, style: style)
            let label = scheme == nil ? "the device dark" : "the app dark"
            XCTAssertEqual(hosted.barStyle, .light, "\(label): the navigation bar is not light")
            let edge = hosted.bar.pixel(4, hosted.bar.height / 2)
            XCTAssertTrue(edge.r > 220 && edge.g > 220 && edge.b > 220, "\(label): the bar is not light: \(edge)")
            let title = try XCTUnwrap(hosted.bar.bounds(of: Pixels.isInk), "\(label): no dark title in the bar")
            XCTAssertLessThan(title.width, 100, "\(label): the bar is dark, not its title: \(title)")
        }
        let yellow = try hostScaffold(appBar: ["backgroundColor": "#FFFF00"], scheme: .dark, style: .light)
        XCTAssertNotNil(yellow.bar.bounds(of: AppBarCardTests.isYellow), "the AppBar backgroundColor is not drawn")
    }
    #endif

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

    // MARK: helpers

    /// A page whose root is a Scaffold with `props` and the Text "Hi" as its
    /// body; with `appBar`, an AppBar with those props titled with the Text
    /// "Bar" in its appBar slot.
    func scaffoldPage(_ props: [String: JSONValue] = [:], appBar: [String: JSONValue]? = nil) throws -> OrcaPageModel {
        var scaffold = props
        scaffold["body"] = "body"
        var children: [JSONValue] = ["body"]
        var components: [JSONValue] = [
            AppBarCardTests.node("body", "Text", kind: "primitive", childMode: "none", props: ["data": "Hi"]),
        ]
        if let appBar {
            scaffold["appBar"] = "bar"
            children.append("bar")
            var bar = appBar
            bar["title"] = "title"
            components += [
                AppBarCardTests.node("bar", "AppBar", kind: "structure", childMode: "none", props: bar,
                                     children: ["title"]),
                AppBarCardTests.node("title", "Text", kind: "primitive", childMode: "none", props: ["data": "Bar"]),
            ]
        }
        components.insert(AppBarCardTests.node("s", "Scaffold", kind: "structure", childMode: "none",
                                               props: scaffold, children: children), at: 0)
        return OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(components),
        ]).decode(PageResponse.self))
    }

    /// `scaffoldPage(props)` drawn 200x200 under `scheme` with ImageRenderer
    /// at scale 1.
    func drawScaffold(_ props: [String: JSONValue] = [:], scheme: ColorScheme) throws -> Pixels {
        let renderer = ImageRenderer(content: NodeView(id: "s", model: try scaffoldPage(props))
            .frame(width: 200, height: 200)
            .environment(\.colorScheme, scheme))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }

    #if canImport(UIKit)
    struct HostedScaffold {
        /// The navigation bar's rows of the window.
        let bar: Pixels
        /// The colour scheme the navigation bar is drawn with.
        let barStyle: UIUserInterfaceStyle
    }

    /// `scaffoldPage(appBar: appBar)` as the root of a NavigationStack under
    /// `scheme` (nil: none given) in a 390x300 UIKit window of `style`, read
    /// at scale 1.
    func hostScaffold(appBar: [String: JSONValue], scheme: ColorScheme?, style: UIUserInterfaceStyle) throws
        -> HostedScaffold {
        let model = try scaffoldPage(appBar: appBar)
        let stack = NavigationStack { NodeView(id: "s", model: model) }
        let host = UIHostingController(rootView: AnyView(scheme.map { AnyView(stack.environment(\.colorScheme, $0)) }
            ?? AnyView(stack)))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        let navigationBar = try XCTUnwrap(AppBarCardTests.navigationBar(in: window), "no navigation bar")
        let frame = navigationBar.convert(navigationBar.bounds, to: window)
        XCTAssertGreaterThan(frame.height, 20, "the navigation bar is not shown: \(frame)")
        let pixels = try Pixels(XCTUnwrap(image.cgImage))
        return HostedScaffold(bar: pixels.rows(Int(frame.minY)...Int(frame.maxY) - 1),
                              barStyle: navigationBar.traitCollection.userInterfaceStyle)
    }
    #endif
}
#endif
