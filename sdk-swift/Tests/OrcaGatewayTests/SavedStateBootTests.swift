#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// The saved-state demo in small (examples/server/saved-state.ts): pages
/// `home`, `other`, `login` and `account` (redirected to `/login` while app
/// state `loggedIn` is false), and a static flow `offline` whose page
/// `cached` is pre-rendered in `/config`. Every page declares page state
/// `count` (0) and `name` ("none") and shows `count`; a page from the
/// network has its path as title, the pre-rendered one "Cached". The
/// config's initialAppState is `{loggedIn: false, theme: "light"}`. Every
/// request is kept.
final class SavedStateServer: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private let initialRoute: String

    init(initialRoute: String = "/home") {
        self.initialRoute = initialRoute
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    /// The page requests, in order.
    var pageRequests: [HTTPRequest] { requests.filter { $0.url.path.contains("/page/") } }

    /// The path of each page request, in order.
    var pagesAsked: [String] { pageRequests.map { $0.url.path.components(separatedBy: "/page/").last ?? "" } }

    private func record(_ request: HTTPRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        record(request)
        let path = request.url.path
        if path.hasSuffix("/version") {
            return HTTPResponse(status: 200, body: Data(#"{"flows": {"offline": 1}}"#.utf8))
        }
        if path.hasSuffix("/config") {
            return HTTPResponse(status: 200, body: try config.encoded())
        }
        let name = path.components(separatedBy: "/page/").last ?? ""
        return HTTPResponse(status: 200, body: try Self.page(name, title: name).encoded())
    }

    static let initialAppState: [String: JSONValue] = ["loggedIn": false, "theme": "light"]

    static func page(_ id: String, title: String) -> JSONValue {
        [
            "pageId": .string(id), "title": .string(title),
            "state": [["key": "count", "scope": "page", "initial": 0],
                      ["key": "name", "scope": "page", "initial": "none"]],
            "components": [["id": "0", "type": "Text", "kind": "primitive", "childMode": "none",
                            "props": ["data": ["type": "state", "scope": "page", "key": "count"]],
                            "children": [], "watches": ["count"]]],
        ]
    }

    var config: JSONValue {
        [
            "appId": "saved-state", "initialRoute": .string(initialRoute),
            "initialAppState": .object(Self.initialAppState),
            "flows": [
                ["name": "main", "routes": [
                    ["path": "home"], ["path": "other"], ["path": "login"],
                    ["path": "account", "redirect": ["when": "loggedIn", "equals": false, "to": "/login"]],
                ]],
                ["name": "offline", "version": 1, "isStatic": true, "routes": [["path": "cached"]],
                 "pages": ["cached": Self.page("cached", title: "Cached")]],
            ],
        ]
    }
}

/// C14.6 in the SwiftUI layer (Flutter sdk/lib/src/widgets/orca_app.dart
/// `_initRouter`, sdk/lib/src/state/state_manager.dart `initPage`): OrcaApp's
/// SavedState reaches the router and every page. The saved app entry is laid
/// over the app state before the first route; each page lays its saved entry
/// over its seed and saves to the app's SavedState. Each test's files live in
/// their own temporary directory, never in Application Support: a new
/// SavedState over them is the app after a relaunch, and
/// `SavedState.resetSession()` is a new process.
@MainActor
final class SavedStateBootTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orca-saved-\(UUID().uuidString)", isDirectory: true)
        SavedState.resetSession()
    }

    override func tearDown() async throws {
        SavedState.resetSession()
        try? FileManager.default.removeItem(at: directory)
    }

    /// The app's files; a new store over them is the same files after a restart.
    private func files() -> FileKeyValueStore {
        FileKeyValueStore(directory: directory)
    }

    /// The SavedState an app starts with over the files.
    private func saved() -> SavedState {
        SavedState(local: files())
    }

    private func client(_ server: SavedStateServer) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "saved-state", deviceId: "test-device",
                   device: DeviceInfo(osVersion: "test"), transport: server)
    }

    /// OrcaApp's boot over `server` (from its config, or at `path`), saving
    /// through `savedState`, started and ready.
    private func launch(_ server: SavedStateServer, savedState: SavedState?, path: String? = nil,
                        cache: StaticFlowManager? = nil) async throws -> OrcaRouter {
        let boot = OrcaAppBoot(client: client(server), path: path, system: SystemRecorder().actions(),
                               onRouteChanged: nil, plugins: nil, staticFlowManager: cache, savedState: savedState)
        await boot.startIfNeeded()
        guard case .ready(let router) = boot.phase else {
            throw NSError(domain: "SavedStateBootTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "the boot is not ready: \(boot.phase)"])
        }
        return router
    }

    /// The page on top once loaded, after a `go` to `location` (nil: the
    /// page on top now).
    private func page(_ location: String?, in router: OrcaRouter) async throws -> OrcaPageModel {
        if let location { router.navigate(to: location, replace: true) }
        let loader = router.loader(for: router.top)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "SavedStateBootTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "\(router.top.location) did not load: \(loader.phase)"])
        }
        return model
    }

    private static func set(_ key: String, _ value: JSONValue, _ scope: StateScope = .page) -> Action {
        .setState(.init(key: key, scope: scope, value: value))
    }

    private static func persist(_ key: String, _ scope: StateScope, _ storage: String) -> Action {
        .persistState(.init(key: key, scope: scope, storage: storage))
    }

    private static func clear(_ key: String, _ scope: StateScope = .page) -> Action {
        .clearState(.init(key: key, scope: scope))
    }

    // MARK: Local: a relaunch

    func testC14_6_aPagesLocalPersistStateSurvivesANewOrcaAppOverTheSameFiles() async throws {
        let first = try await launch(SavedStateServer(), savedState: saved())
        let home = try await page(nil, in: first)
        await home.run(Self.set("count", 5))
        await home.run(Self.persist("count", .page, "local"))
        await home.run(Self.set("theme", "dark", .app))
        await home.run(Self.persist("theme", .app, "local"))
        await home.run(Self.set("count", 6))  // a snapshot: the saved copy stays 5

        // A relaunch: a new process, a new OrcaApp over the same files.
        SavedState.resetSession()
        let server = SavedStateServer()
        let again = try await launch(server, savedState: saved())
        XCTAssertEqual(again.appState, ["loggedIn": false, "theme": "dark"])
        let reopened = try await page(nil, in: again)
        XCTAssertEqual(reopened.store.state.page, ["count": 5, "name": "none"])
        XCTAssertEqual(reopened.resolve("0")?["data"], 5)
        XCTAssertEqual(PageStub.appState(try XCTUnwrap(server.pageRequests.last))?["theme"], "dark")
    }

    // MARK: Session

    func testC14_6_sessionSurvivesLeavingThePageAndANewOrcaAppButNotANewProcess() async throws {
        let router = try await launch(SavedStateServer(), savedState: SavedState(local: MemoryKeyValueStore()))
        let home = try await page(nil, in: router)
        await home.run(Self.set("count", 7))
        await home.run(Self.persist("count", .page, "session"))
        XCTAssertEqual(SavedState.sessionEntries, ["orca_saved_page_home": ["count": 7]])

        _ = try await page("/other", in: router)
        let back = try await page("/home", in: router)
        XCTAssertFalse(back === home, "home was left: a new page")
        XCTAssertEqual(back.store.value("count"), 7)

        let rebuilt = try await launch(SavedStateServer(), savedState: SavedState(local: MemoryKeyValueStore()))
        let rebuiltHome = try await page(nil, in: rebuilt)
        XCTAssertEqual(rebuiltHome.store.value("count"), 7, "the session outlives an OrcaApp")

        SavedState.resetSession()
        let relaunched = try await launch(SavedStateServer(), savedState: SavedState(local: MemoryKeyValueStore()))
        let relaunchedHome = try await page(nil, in: relaunched)
        XCTAssertEqual(relaunchedHome.store.value("count"), 0, "a new process has no session")
    }

    // MARK: clearState

    func testC14_6_clearStateEmptiesBothStoragesAndTheLiveKeys() async throws {
        let router = try await launch(SavedStateServer(), savedState: saved())
        let home = try await page(nil, in: router)
        await home.run(Self.set("count", 5))
        await home.run(Self.persist("count", .page, "local"))
        await home.run(Self.set("name", "kim"))
        await home.run(Self.persist("name", .page, "session"))
        await home.run(Self.set("theme", "dark", .app))
        await home.run(Self.persist("theme", .app, "local"))
        XCTAssertNotNil(files().string(forKey: "orca_saved_page_home"))
        XCTAssertNotNil(files().string(forKey: "orca_saved_app"))
        XCTAssertEqual(SavedState.sessionEntries, ["orca_saved_page_home": ["name": "kim"]])

        await home.run(Self.clear("count"))
        await home.run(Self.clear("name"))
        await home.run(Self.clear("theme", .app))
        XCTAssertEqual(home.store.value("count"), .null)
        XCTAssertEqual(home.store.value("name"), .null)
        XCTAssertEqual(router.appState["theme"] ?? .null, .null)
        XCTAssertNil(files().string(forKey: "orca_saved_page_home"))
        XCTAssertNil(files().string(forKey: "orca_saved_app"))
        XCTAssertEqual(SavedState.sessionEntries, [:])

        let again = try await launch(SavedStateServer(), savedState: saved())
        XCTAssertEqual(again.appState, SavedStateServer.initialAppState)
        let reopened = try await page(nil, in: again)
        XCTAssertEqual(reopened.store.state.page, ["count": 0, "name": "none"])
    }

    // MARK: App state before the first route

    func testC14_6_theSavedAppEntryIsLaidOverInitialAppStateBeforeTheFirstRoute() async throws {
        let unsaved = try await launch(SavedStateServer(initialRoute: "/account"), savedState: saved())
        XCTAssertEqual(unsaved.root.location, "/login", "logged out: the redirect")

        files().set(#"{"loggedIn": true, "token": "t"}"#, forKey: "orca_saved_app")
        let server = SavedStateServer(initialRoute: "/account")
        let router = try await launch(server, savedState: saved())
        XCTAssertEqual(router.root.location, "/account", "the redirect saw the saved loggedIn")
        XCTAssertEqual(router.appState, ["loggedIn": true, "theme": "light", "token": "t"])
        _ = try await page(nil, in: router)
        XCTAssertEqual(server.pagesAsked, ["account"])
        XCTAssertEqual(PageStub.appState(try XCTUnwrap(server.pageRequests.last)),
                       ["loggedIn": true, "theme": "light", "token": "t"])
    }

    func testC14_6_withAPathTheSavedAppEntryIsTheAppStateOfTheFirstPage() async throws {
        files().set(#"{"token": "t"}"#, forKey: "orca_saved_app")
        files().set(#"{"count": 4}"#, forKey: "orca_saved_page_home")
        let server = SavedStateServer()
        let router = try await launch(server, savedState: saved(), path: "home")
        XCTAssertEqual(router.appState, ["token": "t"])
        let home = try await page(nil, in: router)
        XCTAssertEqual(home.store.value("count"), 4)
        XCTAssertEqual(PageStub.appState(try XCTUnwrap(server.pageRequests.last)), ["token": "t"])
    }

    /// `OrcaApp(router:)`: the router the host makes takes the SavedState.
    func testC14_6_aRouterTheHostMakesRestoresAtCreationAndGivesItsPagesTheSavedState() async throws {
        files().set(#"{"loggedIn": true}"#, forKey: "orca_saved_app")
        files().set(#"{"count": 4}"#, forKey: "orca_saved_page_account")
        let server = SavedStateServer(initialRoute: "/account")
        let config = try JSONDecoder().decode(NavConfig.self, from: server.config.encoded())
        let saved = saved()
        let router = OrcaRouter(client: client(server), config: config, system: SystemRecorder().actions(),
                                savedState: saved)
        XCTAssertTrue(router.savedState === saved)
        XCTAssertEqual(router.root.location, "/account")
        let account = try await page(nil, in: router)
        XCTAssertEqual(account.store.value("count"), 4)
        XCTAssertTrue(account.executor.savedState === saved)
    }

    func testC14_6_orcaAppGivenASavedStateSendsTheSavedAppEntryWithTheFirstPage() async throws {
        files().set(#"{"token": "t"}"#, forKey: "orca_saved_app")
        let server = SavedStateServer()
        try await showForAMoment(OrcaApp(client: client(server), path: "home", savedState: saved()))
        let home = try XCTUnwrap(server.pageRequests.first, "home was asked for")
        XCTAssertEqual(PageStub.appState(home), ["token": "t"])
    }

    // MARK: Every seed

    func testC14_6_aPageFromTheOfflineCacheRestoresAsAPageFromTheNetwork() async throws {
        let filled = StaticFlowManager(store: files())
        _ = try await preload(client: client(SavedStateServer()), cache: filled)
        files().set(#"{"count": 9}"#, forKey: "orca_saved_page_cached")
        let server = SavedStateServer()
        let saved = saved()
        let router = try await launch(server, savedState: saved, cache: StaticFlowManager(store: files()))
        let cached = try await page("/cached", in: router)
        XCTAssertEqual(cached.page.title, "Cached", "the pre-rendered page")
        XCTAssertEqual(server.pagesAsked, [], "no page request")
        XCTAssertEqual(cached.store.state.page, ["count": 9, "name": "none"])
        XCTAssertTrue(cached.executor.savedState === saved)

        await cached.run(Self.set("count", 10))
        await cached.run(Self.persist("count", .page, "local"))
        XCTAssertEqual(files().string(forKey: "orca_saved_page_cached").map { try? JSONValue.decode(Data($0.utf8)) },
                       ["count": 10])
    }

    /// U6: a page seeded again from a fresh response (the loader's reload)
    /// gets its saved entry over that seed too.
    func testC14_6_aReloadSeedsThePageAgainAndTheSavedEntryIsLaidOverThatSeed() async throws {
        let router = try await launch(SavedStateServer(), savedState: saved())
        let home = try await page(nil, in: router)
        await home.run(Self.set("count", 3))
        await home.run(Self.persist("count", .page, "local"))
        await home.run(Self.set("count", 8))

        let loader = router.loader(for: router.top)
        await loader.reload()
        guard case .loaded(let fresh) = loader.phase else { return XCTFail("no page: \(loader.phase)") }
        XCTAssertFalse(fresh === home, "a fresh response")
        XCTAssertEqual(fresh.store.state.page, ["count": 3, "name": "none"])
    }

    // MARK: U5

    func testC14_6_anAppThatNeverSavesIsAsBeforeAndWritesNothing() async throws {
        let server = SavedStateServer()
        let router = try await launch(server, savedState: saved())
        XCTAssertEqual(router.appState, SavedStateServer.initialAppState)
        let home = try await page(nil, in: router)
        await home.run(Self.set("count", 2))
        let other = try await page("/other", in: router)
        XCTAssertEqual(home.store.state.page, ["count": 2, "name": "none"])
        XCTAssertEqual(other.store.state.page, ["count": 0, "name": "none"])
        XCTAssertEqual(server.pagesAsked, ["home", "other"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "nothing written")
        XCTAssertEqual(SavedState.sessionEntries, [:])
    }

    // MARK: The shell

    /// Flutter sdk/lib/src/widgets/orca_shell.dart `_renderServerTabBar` and
    /// `_renderServerDrawer`: the shell's executor is built with the app's
    /// StateManager under page id `__shell__`, and no page entry is restored
    /// for it.
    func testC14_6_aServerTabBarsAndDrawersPersistStateOfAnAppKeySavesTheAppEntryForTheNextOrcaApp() async throws {
        func button(_ id: String, _ label: String, _ key: String, _ value: JSONValue) -> [JSONValue] {
            [
                ["id": .string(id), "type": "TextButton", "kind": "button", "childMode": "single",
                 "props": [:], "children": [.string(id + "Label")], "watches": [],
                 "actions": ["onTap": ["type": "actionGroup", "actions": [
                     ["type": "setState", "key": .string(key), "value": value, "scope": "app"],
                     ["type": "persistState", "key": .string(key), "scope": "app", "storage": "local"],
                 ]]]],
                [
                    "id": .string(id + "Label"), "type": "Text", "kind": "primitive", "childMode": "none",
                    "props": ["data": .string(label)], "children": [], "watches": [],
                ],
            ]
        }
        let config: JSONValue = [
            "initialRoute": "/feed",
            "initialAppState": ["theme": "light"],
            "tabs": [
                ["id": "feed", "label": "Feed", "icon": "home", "initialRoute": "/feed"],
                ["id": "search", "label": "Search", "icon": "search", "initialRoute": "/search"],
            ],
            "tabBarComponents": .array(button("dark", "Dark", "theme", "dark")),
            "drawerComponents": .array(button("pro", "Pro", "plan", "pro")),
            "flows": [["name": "main", "routes": [["path": "feed"], ["path": "search"]]]],
        ]
        func launch() async throws -> OrcaRouter {
            let boot = OrcaAppBoot(client: BootStub.client(BootStub(config: config)), path: nil,
                                   system: SystemRecorder().actions(), onRouteChanged: nil, plugins: nil,
                                   savedState: saved())
            await boot.startIfNeeded()
            guard case .ready(let router) = boot.phase else {
                throw NSError(domain: "SavedStateBootTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "the boot is not ready: \(boot.phase)"])
            }
            return router
        }
        files().set(#"{"count": 1}"#, forKey: "orca_saved_page___shell__")

        let router = try await launch()
        let model = TabShellModel(router: router)
        let bar = try XCTUnwrap(model.bar)
        let drawer = try XCTUnwrap(model.drawer)
        XCTAssertEqual(bar.page.store.state.page, [:], "no page entry is restored for the shell")
        XCTAssertEqual(drawer.page.store.state.page, [:])

        await bar.page.fire("onTap", on: try XCTUnwrap(bar.page.resolve("dark")))?.value
        await drawer.page.fire("onTap", on: try XCTUnwrap(drawer.page.resolve("pro")))?.value
        XCTAssertEqual(router.appState["theme"], "dark")
        XCTAssertEqual(router.appState["plan"], "pro")
        let entry = try XCTUnwrap(files().string(forKey: "orca_saved_app"), "the shell saved the app entry")
        XCTAssertEqual(try JSONValue.decode(Data(entry.utf8)), ["theme": "dark", "plan": "pro"])

        // A relaunch: a new process, a new OrcaApp over the same files.
        SavedState.resetSession()
        let again = try await launch()
        XCTAssertEqual(again.appState["theme"], "dark")
        XCTAssertEqual(again.appState["plan"], "pro")
    }
}
#endif
