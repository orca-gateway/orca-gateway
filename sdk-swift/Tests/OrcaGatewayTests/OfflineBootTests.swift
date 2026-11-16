#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// The static-flows demo server in small (examples/server/static-flows.ts):
/// flow "main" at version 4, static, `home` and `about` pre-rendered in
/// `/config`, `profile` dynamic, initialRoute `/home`. A page from the
/// network has its path as title ("home"), a pre-rendered one is capitalised
/// ("Home"), so a test sees where a page came from. Each route can be down,
/// and a test may change the answers between requests. Every request is kept
/// as "version", "config" or "page <path>".
final class StaticFlowsServer: HTTPTransport, @unchecked Sendable {
    /// What each route answers.
    struct Answers {
        /// `/version`'s body; nil: unreachable.
        var version: String?
        /// `/config`'s status (200 sends `config`); nil: unreachable.
        var configStatus: Int?
        var pagesUp: Bool
    }

    static let fresh = #"{"flows": {"main": 4}}"#
    static let forceUpdate = #"{"flows": {"main": 4}, "forceUpdate": true}"#
    /// Every route answers, `/version` with the saved version.
    static let online = Answers(version: fresh, configStatus: 200, pagesUp: true)
    /// Nothing answers: the device is offline.
    static let offline = Answers(version: nil, configStatus: nil, pagesUp: false)

    private let lock = NSLock()
    private var _requests: [String] = []
    private var _answers: Answers

    init(_ answers: Answers = online) {
        _answers = answers
    }

    var answers: Answers {
        get { locked { _answers } }
        set { locked { _answers = newValue } }
    }

    var requests: [String] { locked { _requests } }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func record(_ name: String) -> Answers {
        locked {
            _requests.append(name)
            return _answers
        }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let path = request.url.path
        if path.hasSuffix("/version") {
            guard let version = record("version").version else { throw URLError(.notConnectedToInternet) }
            return HTTPResponse(status: 200, body: Data(version.utf8))
        }
        if path.hasSuffix("/config") {
            guard let status = record("config").configStatus else { throw URLError(.notConnectedToInternet) }
            guard status == 200 else { return HTTPResponse(status: status, body: Data("config is down".utf8)) }
            return HTTPResponse(status: 200, body: try Self.config.encoded())
        }
        let name = path.components(separatedBy: "/page/").last ?? ""
        guard record("page " + name).pagesUp else { throw URLError(.notConnectedToInternet) }
        return HTTPResponse(status: 200, body: try Self.page(name, title: name).encoded())
    }

    static func page(_ id: String, title: String) -> JSONValue {
        [
            "pageId": .string(id), "title": .string(title), "state": [],
            "components": [["id": "0", "type": "Text", "kind": "primitive", "childMode": "none",
                            "props": ["data": .string(title)], "children": [], "watches": []]],
        ]
    }

    static let config: JSONValue = [
        "appId": "static-flows", "appName": "Static Flows Demo", "initialRoute": "/home",
        "initialAppState": ["visits": 0],
        "flows": [[
            "name": "main", "version": 4, "isStatic": true,
            "routes": [["path": "home"], ["path": "about"], ["path": "profile", "isDynamic": true]],
            "pages": ["home": page("home", title: "Home"), "about": page("about", title: "About")],
        ]],
    ]
}

/// Put `view` in a window for half a second, so its tasks run.
@MainActor
func showForAMoment<V: View>(_ view: V) async throws {
    let frame = CGRect(x: 0, y: 0, width: 390, height: 700)
    #if canImport(UIKit)
    let controller = UIHostingController(rootView: view)
    let window = UIWindow(frame: frame)
    window.rootViewController = controller
    window.isHidden = false
    controller.view.frame = frame
    controller.view.layoutIfNeeded()
    try await Task.sleep(nanoseconds: 500_000_000)
    window.isHidden = true
    #elseif canImport(AppKit)
    let window = NSWindow(contentViewController: NSHostingController(rootView: view))
    window.setFrame(frame, display: true)
    window.makeKeyAndOrderFront(nil)
    try await Task.sleep(nanoseconds: 500_000_000)
    window.orderOut(nil)
    #endif
}

/// Step 14 in the SwiftUI layer (Flutter sdk/lib/src/widgets/orca_app.dart,
/// orca_page.dart): OrcaApp's config boot with `enableOffline` runs the
/// core's `preload` with a file cache, a host's preloaded config boots with
/// no request, and every page asks the cache first. Each test's cache lives
/// in its own temporary directory; a new cache over it is a restart.
@MainActor
final class OfflineBootTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orca-offline-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        OrcaDebug.reporter = nil
        try? FileManager.default.removeItem(at: directory)
    }

    private func cache() -> StaticFlowManager {
        StaticFlowManager(store: FileKeyValueStore(directory: directory))
    }

    private func client(_ server: StaticFlowsServer) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "static-flows", deviceId: "test-device",
                   device: DeviceInfo(osVersion: "test"), transport: server)
    }

    /// OrcaApp's config boot over `server`.
    private func boot(_ server: StaticFlowsServer, cache: StaticFlowManager?, enableOffline: Bool = true,
                      preloadedConfig: NavConfig? = nil) -> OrcaAppBoot {
        OrcaAppBoot(client: client(server), path: nil, system: SystemRecorder().actions(), onRouteChanged: nil,
                    plugins: nil, enableOffline: enableOffline, preloadedConfig: preloadedConfig,
                    staticFlowManager: cache)
    }

    private func ready(_ boot: OrcaAppBoot) throws -> OrcaRouter {
        guard case .ready(let router) = boot.phase else {
            throw NSError(domain: "OfflineBootTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "the boot is not ready: \(boot.phase)"])
        }
        return router
    }

    /// One online boot over a new cache: the config and its static pages saved.
    @discardableResult
    private func bootOnline() async throws -> OrcaRouter {
        let boot = boot(StaticFlowsServer(), cache: cache())
        await boot.startIfNeeded()
        return try ready(boot)
    }

    /// The page on top after a push of `location` (nil: the root), loaded.
    private func open(_ location: String?, in router: OrcaRouter) async -> OrcaPageLoader.Phase {
        if let location { router.navigate(to: location) }
        let loader = router.loader(for: router.top)
        await loader.loadIfNeeded()
        return loader.phase
    }

    /// The title of a loaded page, else what the loader shows.
    private func title(_ phase: OrcaPageLoader.Phase) -> String {
        switch phase {
        case .loaded(let model): return model.page.title
        case .failed(let message): return "failed: \(message)"
        case .loading: return "loading"
        }
    }

    /// Every file the cache wrote, by name, with its text.
    private func savedFiles() throws -> [String: String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var files: [String: String] = [:]
        for name in names {
            files[name] = try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
        }
        return files
    }

    // MARK: C14.1

    func testC14_1_afterAnOnlineBootStaticPagesNeverVisitedOpenFromTheCacheAndTheDynamicOneFromTheNetwork()
        async throws
    {
        let server = StaticFlowsServer()
        let boot = boot(server, cache: cache())
        await boot.startIfNeeded()
        let router = try ready(boot)
        XCTAssertEqual(server.requests, ["version", "config"])

        let home = title(await open(nil, in: router))
        let about = title(await open("/about", in: router))
        XCTAssertEqual([home, about], ["Home", "About"])
        XCTAssertEqual(server.requests, ["version", "config"], "no page request")

        let profile = title(await open("/profile", in: router))
        XCTAssertEqual(profile, "profile", "the dynamic route goes to the network")
        XCTAssertEqual(server.requests, ["version", "config", "page profile"])
    }

    func testC14_1_afterARestartWithTheServerDownStaticPagesStillOpenFromTheCache() async throws {
        try await bootOnline()
        let server = StaticFlowsServer(StaticFlowsServer.offline)
        let boot = boot(server, cache: cache())
        await boot.startIfNeeded()
        let router = try ready(boot)

        let home = title(await open(nil, in: router))
        let about = title(await open("/about", in: router))
        XCTAssertEqual([home, about], ["Home", "About"])
        XCTAssertEqual(server.requests, ["version"], "no /config, no page request")
    }

    func testC14_1_aPageFromTheNetworkIsNeverWrittenToTheCache() async throws {
        let router = try await bootOnline()
        let saved = try savedFiles()
        XCTAssertFalse(saved.isEmpty)

        let profile = title(await open("/profile", in: router))
        XCTAssertEqual(profile, "profile")
        XCTAssertEqual(try savedFiles(), saved, "the store is as the boot left it")
        let restarted = cache()
        XCTAssertNil(try restarted.getCachedPage("profile", flows: router.flows))
    }

    func testC14_1_aCachedPageReportsNoTimingEventAndANetworkPageDoes() async throws {
        let router = try await bootOnline()
        let recorder = DevToolsHookTests.Recorder()
        OrcaDebug.reporter = recorder

        guard case .loaded(let home) = await open(nil, in: router) else { return XCTFail("home did not load") }
        home.appeared()
        XCTAssertEqual(recorder.of("timing"), [])
        XCTAssertEqual(recorder.of("network"), [])

        guard case .loaded(let profile) = await open("/profile", in: router) else {
            return XCTFail("profile did not load")
        }
        profile.appeared()
        XCTAssertEqual(recorder.of("timing").count, 1)
        XCTAssertEqual(recorder.of("timing").first?.payload["path"], "profile")
    }

    func testC14_1_withoutEnableOfflineAHostsCacheStillServesTheStaticPages() async throws {
        let filled = cache()
        _ = try await preload(client: client(StaticFlowsServer()), cache: filled)
        let server = StaticFlowsServer()
        let boot = boot(server, cache: filled, enableOffline: false)
        await boot.startIfNeeded()
        let router = try ready(boot)

        let home = title(await open(nil, in: router))
        XCTAssertEqual(home, "Home")
        XCTAssertEqual(server.requests, ["config"], "the online-only boot: no version check, no page request")
    }

    func testC14_1_orcaAppBootsOnlineWithOneVersionCheckAndOpensItsFirstPageFromTheCache() async throws {
        let server = StaticFlowsServer()
        try await showForAMoment(OrcaApp(client: client(server), enableOffline: true, staticFlowManager: cache()))
        XCTAssertEqual(server.requests, ["version", "config"], "preload's check only, and home from the cache")
    }

    // MARK: C14.2

    func testC14_2_aColdBootWhoseVersionFailsStartsFromTheSavedConfigAndOtherPagesFailAsToday() async throws {
        try await bootOnline()
        let server = StaticFlowsServer(StaticFlowsServer.offline)
        let boot = boot(server, cache: cache())
        await boot.startIfNeeded()
        let router = try ready(boot)
        XCTAssertEqual(router.root.location, "/home", "the saved config's initialRoute")
        XCTAssertEqual(router.appState["visits"], 0, "its initialAppState")

        let home = title(await open(nil, in: router))
        XCTAssertEqual(home, "Home")
        guard case .failed = await open("/profile", in: router) else {
            return XCTFail("a page the cache does not hold fails")
        }
        XCTAssertEqual(server.requests, ["version", "page profile"])
    }

    func testC14_2_withNothingSavedTheBootErrorSaysSoAndRetryRunsPreloadAgain() async throws {
        let server = StaticFlowsServer(StaticFlowsServer.offline)
        let boot = boot(server, cache: cache())
        await boot.startIfNeeded()
        guard case .failed(let message) = boot.phase else { return XCTFail("not failed: \(boot.phase)") }
        XCTAssertEqual(message, "No network and no cached config available")
        XCTAssertEqual(server.requests, ["version"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "nothing saved")

        server.answers = StaticFlowsServer.online
        await boot.retry()
        let router = try ready(boot)
        XCTAssertEqual(server.requests, ["version", "version", "config"])
        let home = title(await open(nil, in: router))
        XCTAssertEqual(home, "Home")
    }

    func testC14_2_freshVersionsUseTheSavedConfigWithNoConfigRequest() async throws {
        try await bootOnline()
        let server = StaticFlowsServer()
        let boot = boot(server, cache: cache())
        await boot.startIfNeeded()
        let router = try ready(boot)
        let home = title(await open(nil, in: router))
        XCTAssertEqual(home, "Home")
        XCTAssertEqual(server.requests, ["version"])
    }

    func testC14_2_aConfigFailureShowsTheBootErrorAsTheOnlineBootShowsIt() async throws {
        var answers = StaticFlowsServer.online
        answers.configStatus = 500
        let offline = boot(StaticFlowsServer(answers), cache: cache())
        await offline.startIfNeeded()
        let online = boot(StaticFlowsServer(answers), cache: nil, enableOffline: false)
        await online.startIfNeeded()
        guard case .failed(let message) = offline.phase, case .failed(let expected) = online.phase else {
            return XCTFail("not failed: \(offline.phase), \(online.phase)")
        }
        XCTAssertEqual(message, expected)
        XCTAssertEqual(message, "HTTP 500: config is down")
    }

    func testC14_2_aForceUpdateAnswerShowsTheForceUpdateScreenAndMakesNoRouter() async throws {
        let server = StaticFlowsServer(.init(version: StaticFlowsServer.forceUpdate, configStatus: 200, pagesUp: true))
        let boot = boot(server, cache: cache())
        XCTAssertFalse(boot.updateRequired)
        await boot.startIfNeeded()
        XCTAssertTrue(boot.updateRequired)
        guard case .loading = boot.phase else { return XCTFail("no router: \(boot.phase)") }
        XCTAssertEqual(server.requests, ["version"])
    }

    func testC14_2_aLinkHeldDuringTheOfflineBootIsWhereTheAppStarts() async throws {
        try await bootOnline()
        let server = StaticFlowsServer(StaticFlowsServer.offline)
        let boot = boot(server, cache: cache())
        boot.handleDeeplink(try XCTUnwrap(URL(string: "orcademo://open/about")))
        await boot.startIfNeeded()
        let router = try ready(boot)
        XCTAssertEqual(router.root.location, "/about")
        let about = title(await open(nil, in: router))
        XCTAssertEqual(about, "About")
        XCTAssertEqual(server.requests, ["version"])
    }

    /// The helper a host builds its preload's store with is the one OrcaApp
    /// uses with `enableOffline`; only its path is read, nothing is written.
    func testC14_2_orcaAppKeepsItsOwnCacheInApplicationSupportUnderTheBundleId() throws {
        let support = try XCTUnwrap(
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
        let expected = [Bundle.main.bundleIdentifier, "OrcaGateway"].compactMap { $0 }
            .reduce(support) { $0.appendingPathComponent($1, isDirectory: true) }
        XCTAssertEqual(FileKeyValueStore.applicationSupport().directory.standardizedFileURL,
                       expected.standardizedFileURL)
    }

    func testC14_2_theCacheDirectoryIsTheBundleIdsWhenThereIsOneAndMadeOnlyByAWrite() throws {
        let app = FileKeyValueStore.applicationSupport(in: directory, bundleIdentifier: "com.example.shop")
        let bare = FileKeyValueStore.applicationSupport(in: directory, bundleIdentifier: nil)
        XCTAssertEqual(app.directory.standardizedFileURL, directory
            .appendingPathComponent("com.example.shop/OrcaGateway", isDirectory: true).standardizedFileURL)
        XCTAssertEqual(bare.directory.standardizedFileURL,
                       directory.appendingPathComponent("OrcaGateway", isDirectory: true).standardizedFileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "nothing made before a write")
        app.set("4", forKey: "orca_flow_versions")
        XCTAssertEqual(FileKeyValueStore(directory: app.directory).string(forKey: "orca_flow_versions"), "4")
    }

    // MARK: C14.5

    func testC14_5_aPreloadedConfigWithItsCacheIsReadyAtOnceAndFetchesNothing() async throws {
        let filled = cache()
        guard case .success(let config) = try await preload(client: client(StaticFlowsServer()), cache: filled) else {
            return XCTFail("preload did not give the config")
        }
        for enableOffline in [true, false] {
            let server = StaticFlowsServer()
            let boot = boot(server, cache: filled, enableOffline: enableOffline, preloadedConfig: config)
            let router = try ready(boot)
            XCTAssertEqual(router.root.location, "/home")
            await boot.startIfNeeded()
            let home = title(await open(nil, in: router))
            let about = title(await open("/about", in: router))
            XCTAssertEqual([home, about], ["Home", "About"])
            XCTAssertEqual(server.requests, [], "no /version, no /config, no page")
        }
    }

    func testC14_5_orcaAppGivenItsConfigAndCacheFetchesNothing() async throws {
        let filled = cache()
        guard case .success(let config) = try await preload(client: client(StaticFlowsServer()), cache: filled) else {
            return XCTFail("preload did not give the config")
        }
        let server = StaticFlowsServer()
        try await showForAMoment(OrcaApp(client: client(server), enableOffline: true,
                                         preloadedConfig: config, staticFlowManager: filled))
        XCTAssertEqual(server.requests, [], "no version check, no /config, home from the cache")
    }

    func testC14_5_preloadsForceUpdateIsTheHostsToShow() async throws {
        let server = StaticFlowsServer(.init(version: StaticFlowsServer.forceUpdate, configStatus: 200, pagesUp: true))
        let result = try await preload(client: client(server), cache: cache())
        XCTAssertEqual(result, .forceUpdate)
        XCTAssertEqual(server.requests, ["version"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "nothing saved")
    }
}
#endif
