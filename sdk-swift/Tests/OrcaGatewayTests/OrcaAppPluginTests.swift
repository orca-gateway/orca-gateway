#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// Pages for the plugin tests: every path is a page with one ColoredBadge,
/// a plugin widget type no SDK view draws. Every request is kept.
final class BadgePageStub: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []

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
        let name = request.url.path.components(separatedBy: "/page/").last ?? ""
        let page: JSONValue = [
            "pageId": .string(name), "title": .string(name), "state": [],
            "components": [["id": "badge", "type": "ColoredBadge", "kind": "primitive", "childMode": "none",
                            "props": ["label": "hi"], "children": [], "watches": []]],
        ]
        return HTTPResponse(status: 200, body: try page.encoded())
    }

    var client: OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   device: DeviceInfo(osVersion: "test"), transport: self)
    }
}

/// C16.1 (OrcaApp part) and C16.5: what OrcaApp does with `plugins`,
/// `customActions` and `widgets`, as `_OrcaAppState` in
/// sdk/lib/src/widgets/orca_app.dart: the plugins' widget and action names
/// are advertised before the first request (standalone actions and host
/// widgets are not), every page the app loads keeps plugin nodes, holds the
/// builders and runs the merged handlers (a plugin action named like a
/// built-in replaces it), and a merge conflict fails the boot with Flutter's
/// message and fetches nothing.
@MainActor
final class OrcaAppPluginTests: XCTestCase {
    /// What the plugins' builders drew and their handlers received.
    @MainActor final class Ran {
        var drawn: [String] = []
        var calls: [(name: String, action: JSONValue)] = []
        func record(_ name: String, _ action: JSONValue) { calls.append((name, action)) }
    }

    /// The Flutter example host's `_BadgePlugin` and `_DeviceActionsPlugin`
    /// in one (examples/app/lib/main.dart).
    struct BadgePlugin: OrcaPlugin {
        let ran: Ran
        let name = "badge"
        var widgets: [String: OrcaWidgetBuilder] {
            ["ColoredBadge": { [ran] node, _ in
                ran.drawn.append(node.id)
                return AnyView(EmptyView())
            }]
        }
        var actions: [String: OrcaActionHandler] {
            ["hapticFeedback": { [ran] action, _ in await ran.record("hapticFeedback", action) }]
        }
    }

    /// Takes over the built-in `copyToClipboard`.
    struct ClipboardPlugin: OrcaPlugin {
        let ran: Ran
        let name = "clipboard"
        var actions: [String: OrcaActionHandler] {
            ["copyToClipboard": { [ran] action, _ in await ran.record("copyToClipboard", action) }]
        }
    }

    /// A ColoredBadge under another name, to collide with.
    struct NamedBadgePlugin: OrcaPlugin {
        let name: String
        var widgets: [String: OrcaWidgetBuilder] {
            ["ColoredBadge": { _, _ in AnyView(EmptyView()) }]
        }
    }

    /// OrcaApp's wiring for these inputs: the host, attached to a router over `stub`.
    func app(_ stub: BadgePageStub, plugins: [OrcaPlugin] = [],
             customActions: [String: OrcaActionHandler] = [:], widgets: WidgetBuilders = WidgetBuilders(),
             system: SystemRecorder? = nil) -> (OrcaPluginHost, OrcaRouter) {
        let host = OrcaPluginHost(plugins: plugins, customActions: customActions, widgets: widgets)
        let router = host.attach(OrcaRouter(
            client: stub.client, path: "home", system: (system ?? SystemRecorder()).actions()))
        return (host, router)
    }

    func loaded(_ router: OrcaRouter, _ route: OrcaRoute) async throws -> OrcaPageModel {
        let loader = router.loader(for: route)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "OrcaAppPluginTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
        }
        return model
    }

    /// The first page and a pushed one.
    func pages(_ router: OrcaRouter) async throws -> [OrcaPageModel] {
        let home = try await loaded(router, router.root)
        router.navigate(to: "detail")
        return [home, try await loaded(router, router.stack[0])]
    }

    func action(_ json: JSONValue) throws -> Action { try json.decode(Action.self) }

    // MARK: C16.1

    func testC16_1_ThePluginsWidgetAndActionNamesAreAdvertisedAndTheCapsHashChanges() async throws {
        let plain = BadgePageStub()
        let (_, plainRouter) = app(plain)
        let stub = BadgePageStub()
        let (_, router) = app(stub, plugins: [BadgePlugin(ran: Ran())],
                              customActions: ["rateApp": { _, _ in }])

        let caps = router.client.capabilities
        XCTAssertTrue(caps.widgets.contains("ColoredBadge"))
        XCTAssertTrue(caps.actionKinds.contains("hapticFeedback"))
        XCTAssertTrue(caps.actionKinds.contains("custom:hapticFeedback"))
        XCTAssertFalse(caps.actionKinds.contains("rateApp"), "a standalone custom action is not advertised")
        XCTAssertFalse(caps.actionKinds.contains("custom:rateApp"))
        XCTAssertEqual(plainRouter.client.capabilities, .current, "a plugin-less app advertises the base vector")

        _ = try await loaded(plainRouter, plainRouter.root)
        _ = try await loaded(router, router.root)
        let plainHash = try XCTUnwrap(plain.requests.first?.headers["x-orca-caps-hash"])
        let hash = try XCTUnwrap(stub.requests.first?.headers["x-orca-caps-hash"])
        XCTAssertEqual(plainHash, CapabilityVector.current.hash)
        XCTAssertEqual(hash, caps.hash)
        XCTAssertNotEqual(hash, plainHash)
    }

    func testC16_1_EveryPageKeepsThePluginNodeAndHoldsThePluginAndHostBuilders() async throws {
        let ran = Ran()
        let host = WidgetBuilders()
        host.register("HostCard") { _, _ in AnyView(EmptyView()) }
        let (_, router) = app(BadgePageStub(), plugins: [BadgePlugin(ran: ran)], widgets: host)
        XCTAssertFalse(router.client.capabilities.widgets.contains("HostCard"), "host widgets are not advertised")

        for model in try await pages(router) {
            let node = try XCTUnwrap(model.resolve("badge"))
            XCTAssertEqual(node.type, "ColoredBadge", "not degraded to a FallbackPrompt")
            XCTAssertEqual(model.widgets.types, ["ColoredBadge", "HostCard"])
            _ = try XCTUnwrap(model.widgets.builder(for: "ColoredBadge"))(node, model)
        }
        XCTAssertEqual(ran.drawn, ["badge", "badge"])
        XCTAssertEqual(host.types, ["HostCard"], "the host's own builders are left as given")

        let (_, plainRouter) = app(BadgePageStub())
        let plain = try await loaded(plainRouter, plainRouter.root)
        XCTAssertEqual(plain.resolve("badge")?.type, "FallbackPrompt", "without the plugin the node degrades")
    }

    func testC16_1_EveryPageRunsThePluginAndStandaloneHandlers() async throws {
        let ran = Ran()
        let (_, router) = app(BadgePageStub(), plugins: [BadgePlugin(ran: ran)],
                              customActions: ["rateApp": { [ran] action, _ in await ran.record("rateApp", action) }])

        for model in try await pages(router) {
            await model.run(try action(["type": "custom:hapticFeedback", "intensity": "heavy"]))
            await model.run(try action(["type": "custom:rateApp"]))
        }
        XCTAssertEqual(ran.calls.map(\.name), ["hapticFeedback", "rateApp", "hapticFeedback", "rateApp"])
        XCTAssertEqual(ran.calls.first?.action, ["type": "custom:hapticFeedback", "intensity": "heavy"])
    }

    func testC16_1_TheRoutersOrcaAppBootMakesBuildTheirPagesWithThePlugins() async throws {
        let host = OrcaPluginHost(plugins: [BadgePlugin(ran: Ran())], customActions: [:], widgets: WidgetBuilders())
        let stub = BootStub(config: [
            "initialRoute": "/welcome",
            "flows": [["name": "main", "routes": [["path": "welcome"], ["path": "home"]]]],
        ])
        let configBoot = OrcaAppBoot(client: BootStub.client(stub), path: nil, system: SystemRecorder().actions(),
                                     onRouteChanged: nil, plugins: host)
        await configBoot.startIfNeeded()
        guard case .ready(let router) = configBoot.phase else { return XCTFail("not ready: \(configBoot.phase)") }
        let configHash = try XCTUnwrap(stub.configRequests.first?.headers["x-orca-caps-hash"])
        XCTAssertEqual(configHash, router.client.capabilities.hash, "the names are advertised before /config")
        XCTAssertNotEqual(configHash, CapabilityVector.current.hash)
        let welcome = try await loaded(router, router.root)
        router.navigate(to: "home")
        let home = try await loaded(router, router.stack[0])
        XCTAssertEqual(welcome.widgets.types, ["ColoredBadge"])
        XCTAssertEqual(home.widgets.types, ["ColoredBadge"])

        let pathBoot = OrcaAppBoot(client: BadgePageStub().client, path: "home", system: SystemRecorder().actions(),
                                   onRouteChanged: nil, plugins: host)
        guard case .ready(let pathRouter) = pathBoot.phase else { return XCTFail("not ready: \(pathBoot.phase)") }
        let page = try await loaded(pathRouter, pathRouter.root)
        XCTAssertEqual(page.resolve("badge")?.type, "ColoredBadge", "not degraded to a FallbackPrompt")
    }

    // MARK: C16.5

    func testC16_5_APluginActionNamedLikeABuiltInReplacesItOnEveryPage() async throws {
        let ran = Ran()
        let system = SystemRecorder()
        let (_, router) = app(BadgePageStub(), plugins: [ClipboardPlugin(ran: ran)], system: system)
        var effects: [String] = []
        router.onEffect = { effects.append($0.type) }

        for model in try await pages(router) {
            await model.run(.copyToClipboard(.init(text: "x")))
        }
        XCTAssertEqual(ran.calls.map(\.name), ["copyToClipboard", "copyToClipboard"])
        XCTAssertEqual(ran.calls.first?.action, ["type": "copyToClipboard", "text": "x"])
        XCTAssertEqual(system.copied, [], "the built-in clipboard did not run")
        XCTAssertFalse(effects.contains("copyToClipboard"))
    }

    // MARK: C16.1 (conflict)

    func testC16_1_TwoPluginsWithTheSameWidgetFailTheBootWithFlutterMessageAndFetchNothing() async throws {
        let message = #"Widget type "ColoredBadge" from plugin "b" conflicts with plugin "a"."#
        let stub = BadgePageStub()
        let (host, router) = app(stub, plugins: [NamedBadgePlugin(name: "a"), NamedBadgePlugin(name: "b")])
        XCTAssertEqual(host.failure, message)
        XCTAssertEqual(router.client.capabilities, .current, "nothing is advertised")

        for offline in [true, false] {
            let boot = OrcaBootModel(enableOffline: offline, enableSessionTracking: true,
                                     store: MemoryKeyValueStore(), failure: host.failure)
            XCTAssertEqual(boot.phase, .failed(message))
            await boot.start(client: router.client)
            XCTAssertEqual(boot.phase, .failed(message))
            XCTAssertNil(boot.sessionTracker(client: router.client), "no session request either")

            var built = false
            let view = OrcaBootView(boot: boot, client: router.client) {
                let _ = { built = true }()
                Text("page")
            }
            let renderer = ImageRenderer(content: view.frame(width: 300, height: 200))
            XCTAssertNotNil(renderer.cgImage, "the error view draws")
            XCTAssertFalse(built, "no page is built")
        }
        XCTAssertEqual(stub.requests, [], "no request is made")
    }

    func testC16_1_WithoutAConflictTheBootIsAsBefore() {
        let (host, _) = app(BadgePageStub(), plugins: [BadgePlugin(ran: Ran())])
        XCTAssertNil(host.failure)
        XCTAssertEqual(OrcaBootModel(enableOffline: false, failure: host.failure).phase, .ready)
        XCTAssertEqual(OrcaBootModel(enableOffline: true, failure: host.failure).phase, .checking)
    }
}
#endif
