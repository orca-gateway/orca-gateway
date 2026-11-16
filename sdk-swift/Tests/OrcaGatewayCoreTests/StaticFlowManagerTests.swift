import Foundation
import XCTest

@testable import OrcaGatewayCore

/// A page as the engine pre-renders it into /config, small.
private func page(_ id: String) -> PageResponse {
    PageResponse(pageId: id, title: id.capitalized, components: [
        ComponentNode(id: "0", type: "Text", kind: .primitive, childMode: .none, props: ["data": .string(id)])
    ])
}

/// A flow of a /config body, its pages by path.
private func flow(_ name: String, version: Int? = nil, isStatic: Bool = true, routes: [NavRoute] = [],
                  pages: [String]? = nil) -> NavFlow {
    NavFlow(name: name, version: version, isStatic: isStatic, routes: routes,
            pages: pages.map { Dictionary(uniqueKeysWithValues: $0.map { ($0, page($0)) }) })
}

/// The paths saved under `orca_pages_<name>`, or nil when the key is absent.
private func savedPaths(_ store: MemoryKeyValueStore, _ name: String) throws -> Set<String>? {
    guard let text = store.values["orca_pages_\(name)"] else { return nil }
    return Set(try XCTUnwrap(JSONValue.decode(Data(text.utf8)).objectValue).keys)
}

/// C14.3, C14.4 (core part): Flutter's StaticFlowManager
/// (sdk/lib/src/client/static_flow_manager.dart) over a KeyValueStore, with
/// Flutter's keys: `orca_nav_config`, `orca_flow_versions`, `orca_pages_<flow>`.
/// The boot decisions themselves run in OfflineFixtureTests.
final class StaticFlowManagerTests: XCTestCase {
    func testC14_3_cacheStaticFlowsSavesStaticPagesAndTheVersionsOfVersionedFlowsOnly() throws {
        let store = MemoryKeyValueStore()
        let cache = StaticFlowManager(store: store)
        cache.cacheStaticFlows(NavConfig(flows: [
            flow("main", version: 4, pages: ["home", "about"]),
            flow("extra", pages: ["legacy"]),
            flow("plain", version: 2, isStatic: false, pages: ["feed"]),
        ]))

        XCTAssertEqual(Set(store.values.keys), ["orca_flow_versions", "orca_pages_main", "orca_pages_extra"])
        XCTAssertEqual(try savedPaths(store, "main"), ["home", "about"])
        XCTAssertEqual(try savedPaths(store, "extra"), ["legacy"], "an unversioned static flow saves its pages")
        assertJSONEqual(try JSONValue.decode(Data(try XCTUnwrap(store.values["orca_flow_versions"]).utf8)),
                        ["main": 4, "plain": 2])
        XCTAssertEqual(try cache.getLocalVersions(), ["main": 4, "plain": 2])
    }

    func testC14_3_aNewManagerOverTheSameStoreServesTheSavedPagesAsTheyWere() throws {
        let store = MemoryKeyValueStore()
        let flows = [flow("main", version: 4, pages: ["home", "about"])]
        StaticFlowManager(store: store).cacheStaticFlows(NavConfig(flows: flows))

        let restarted = StaticFlowManager(store: MemoryKeyValueStore(store.values))
        XCTAssertEqual(try restarted.getLocalVersions(), ["main": 4])
        XCTAssertEqual(try restarted.getCachedPage("home", flows: flows), page("home"))
        XCTAssertEqual(try restarted.getCachedPage("about", flows: flows), page("about"))
        XCTAssertNil(try restarted.getCachedPage("settings", flows: flows))
    }

    func testC14_3_getCachedPageReadsMemoryFirstThenTheStore() throws {
        let store = MemoryKeyValueStore()
        let flows = [flow("main", version: 4, pages: ["home"])]
        let cache = StaticFlowManager(store: store)
        cache.cacheStaticFlows(NavConfig(flows: flows))
        let saved = store.values

        store.set(nil, forKey: "orca_pages_main")
        XCTAssertEqual(try cache.getCachedPage("home", flows: flows)?.pageId, "home", "from memory")
        XCTAssertNil(try StaticFlowManager(store: store).getCachedPage("home", flows: flows), "nothing saved")

        let cold = StaticFlowManager(store: MemoryKeyValueStore(saved))
        XCTAssertEqual(try cold.getCachedPage("home", flows: flows)?.pageId, "home", "from the store")
        let broken = MemoryKeyValueStore(["orca_pages_main": "not json"])
        XCTAssertThrowsError(try StaticFlowManager(store: broken).getCachedPage("home", flows: flows),
                             "a saved text that does not decode fails, as Dart's jsonDecode does")
    }

    func testC14_3_theCacheNeverServesPagesInsideTheConfigNorThePagesOfANonStaticFlow() throws {
        let inConfig = [flow("main", version: 4, pages: ["home"])]
        XCTAssertNil(try StaticFlowManager(store: MemoryKeyValueStore()).getCachedPage("home", flows: inConfig))

        let store = MemoryKeyValueStore()
        StaticFlowManager(store: store).cacheStaticFlows(NavConfig(flows: [flow("plain", pages: ["home"])]))
        let notStatic = [flow("plain", isStatic: false)]
        XCTAssertNil(try StaticFlowManager(store: store).getCachedPage("home", flows: notStatic))
    }

    func testC14_3_loadConfigDecodesTheSavedTextAndKeepsItAsTheRawBody() throws {
        let store = MemoryKeyValueStore()
        let cache = StaticFlowManager(store: store)
        XCTAssertNil(try cache.loadConfig(), "nothing saved")

        let text = #"{"appId":"static-flows","initialRoute":"/home","flows":[{"name":"main","version":4,"isStatic":true,"routes":[{"path":"home","requiredAppState":[]}]}]}"#
        cache.saveConfigRaw(text)
        XCTAssertEqual(store.values, ["orca_nav_config": text], "the text as given")
        let config = try XCTUnwrap(cache.loadConfig())
        XCTAssertEqual(config.initialRoute, "/home")
        XCTAssertEqual(config.flows.map(\.name), ["main"])
        XCTAssertEqual(config.flows.first?.version, 4)
        XCTAssertEqual(config.rawBody, text)
        XCTAssertEqual(config.raw["appId"], "static-flows")

        cache.saveConfigRaw("not json")
        XCTAssertThrowsError(try cache.loadConfig())
    }

    func testC14_3_localVersionsAreEmptyUntilSavedThenKeptInMemory() throws {
        let store = MemoryKeyValueStore()
        let cache = StaticFlowManager(store: store)
        XCTAssertEqual(try cache.getLocalVersions(), [:])
        store.set(#"{"main":1}"#, forKey: "orca_flow_versions")
        XCTAssertEqual(try cache.getLocalVersions(), ["main": 1], "an empty answer is not kept")
        store.set(#"{"main":2}"#, forKey: "orca_flow_versions")
        XCTAssertEqual(try cache.getLocalVersions(), ["main": 1], "once read, memory answers, as in Flutter")
        XCTAssertThrowsError(try StaticFlowManager(store: MemoryKeyValueStore(["orca_flow_versions": "[1]"]))
            .getLocalVersions())
    }

    func testC14_4_dynamicPathsAreTheDynamicRoutesOfStaticFlowsAndAreNeverServed() throws {
        let main = flow("main", version: 4, routes: [
            NavRoute(path: "home", children: [NavRoute(path: "home/product/:id", isDynamic: true)]),
            NavRoute(path: "profile", isDynamic: true),
            NavRoute(path: "/legacy", isDynamic: true),
            NavRoute(path: "feed"),
        ], pages: ["home", "profile", "home/product/:id", "legacy", "feed"])
        let other = flow("other", isStatic: false, routes: [NavRoute(path: "feed", isDynamic: true)])
        let store = MemoryKeyValueStore()
        let cache = StaticFlowManager(store: store)
        cache.cacheStaticFlows(NavConfig(flows: [main, other]))
        let flows = [main, other]

        XCTAssertEqual(try cache.getCachedPage("profile", flows: flows)?.pageId, "profile",
                       "no dynamic set yet: Flutter checks it only once initDynamicPaths ran")
        cache.initDynamicPaths(flows)
        XCTAssertEqual(try cache.getCachedPage("home", flows: flows)?.pageId, "home")
        XCTAssertNil(try cache.getCachedPage("profile", flows: flows), "a saved page, but a dynamic route")
        XCTAssertNil(try cache.getCachedPage("home/product/:id", flows: flows), "a child, by its full path")
        XCTAssertNil(try cache.getCachedPage("legacy", flows: flows), "kept without its leading slash")
        XCTAssertEqual(try cache.getCachedPage("feed", flows: flows)?.pageId, "feed",
                       "a dynamic route of a flow that is not static is not in the set")
        XCTAssertNil(try cache.getCachedPage("home/product/42", flows: flows), "a concrete path has no page")
    }

    func testC14_4_aRefetchDeletesThePagesOfAVersionedFlowGoneFromTheConfig() throws {
        let store = MemoryKeyValueStore()
        let cache = StaticFlowManager(store: store)
        let old = flow("old", version: 2, pages: ["legacy"])
        cache.cacheStaticFlows(NavConfig(flows: [flow("main", version: 4, pages: ["home"]), old]))
        XCTAssertEqual(try cache.getCachedPage("legacy", flows: [old])?.pageId, "legacy")

        cache.cacheStaticFlows(NavConfig(flows: [flow("main", version: 5, pages: ["home", "about"])]))
        XCTAssertEqual(Set(store.values.keys), ["orca_flow_versions", "orca_pages_main"])
        XCTAssertEqual(try savedPaths(store, "main"), ["home", "about"])
        XCTAssertEqual(try cache.getLocalVersions(), ["main": 5])
        XCTAssertNil(try cache.getCachedPage("legacy", flows: [old]), "its memory entry is gone too")
    }

    func testC14_4_anUnversionedFlowGoneFromTheConfigKeepsItsPages() throws {
        let store = MemoryKeyValueStore()
        let cache = StaticFlowManager(store: store)
        cache.cacheStaticFlows(NavConfig(flows: [
            flow("main", version: 4, pages: ["home"]), flow("legacy", pages: ["legacy"]),
        ]))
        cache.cacheStaticFlows(NavConfig(flows: [flow("main", version: 5, pages: ["home"])]))
        XCTAssertEqual(try savedPaths(store, "legacy"), ["legacy"], "only saved versions are cleaned up")
        XCTAssertEqual(try cache.getLocalVersions(), ["main": 5])
    }

    func testC14_3_clearAllRemovesTheConfigTheVersionsAndThePagesOfEveryKnownFlow() throws {
        let store = MemoryKeyValueStore()
        let cache = StaticFlowManager(store: store)
        let flows = [flow("main", version: 4, pages: ["home"]), flow("legacy", pages: ["legacy"])]
        cache.saveConfigRaw(#"{"flows":[{"name":"main","routes":[]},{"name":"legacy","routes":[]}]}"#)
        cache.cacheStaticFlows(NavConfig(flows: flows))
        XCTAssertEqual(store.values.count, 4)

        StaticFlowManager(store: store).clearAll()
        XCTAssertEqual(store.values, [:], "a new manager finds the flows from the store")

        cache.cacheStaticFlows(NavConfig(flows: flows))
        cache.initDynamicPaths([flow("main", routes: [NavRoute(path: "home", isDynamic: true)])])
        cache.clearAll()
        XCTAssertEqual(store.values, [:])
        XCTAssertEqual(try cache.getLocalVersions(), [:])
        XCTAssertNil(try cache.getCachedPage("legacy", flows: flows), "memory is cleared")
        store.set(try wireText(["home": try JSONValue(encoding: page("home"))]), forKey: "orca_pages_main")
        XCTAssertEqual(try cache.getCachedPage("home", flows: flows)?.pageId, "home", "the dynamic set too")
    }

    func testC14_2_aBootOverAFileStoreIsServedAgainAfterARestartWithNoNetwork() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("orca-boot-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let body: JSONValue = [
            "initialRoute": "/home",
            "flows": [[
                "name": "main", "version": 4, "isStatic": true,
                "routes": [["path": "home"], ["path": "profile", "isDynamic": true]],
                "pages": ["home": try JSONValue(encoding: page("home"))],
            ]],
        ]
        let online = OfflineRoutes(
            version: try OfflineRoutes.answer(["status": 200, "body": ["flows": ["main": 4]]]),
            config: try OfflineRoutes.answer(["status": 200, "body": body]))
        let first = try await preload(client: OfflineRoutes.client(online),
                                      cache: StaticFlowManager(store: FileKeyValueStore(directory: dir)))
        XCTAssertEqual(online.requests, ["version", "config"])
        guard case .success(let fetched) = first else { return XCTFail("\(first)") }

        let offline = OfflineRoutes(version: DownTransport(), config: DownTransport())
        let cache = StaticFlowManager(store: FileKeyValueStore(directory: dir))
        let second = try await preload(client: OfflineRoutes.client(offline), cache: cache)
        XCTAssertEqual(offline.requests, ["version"])
        guard case .success(let saved) = second else { return XCTFail("\(second)") }
        XCTAssertEqual(saved.rawBody, fetched.rawBody)
        cache.initDynamicPaths(saved.flows)
        XCTAssertEqual(try cache.getCachedPage("home", flows: saved.flows), page("home"))
        XCTAssertNil(try cache.getCachedPage("profile", flows: saved.flows))
    }

    func testC14_5_theOfflineErrorReadsAsFlutterMessage() async {
        let offline = OfflineRoutes(version: DownTransport(), config: DownTransport())
        do {
            _ = try await preload(client: OfflineRoutes.client(offline),
                                  cache: StaticFlowManager(store: MemoryKeyValueStore()))
            XCTFail("offline with nothing saved throws")
        } catch {
            XCTAssertEqual(error as? OfflineBootError, OfflineBootError())
            XCTAssertEqual("\(error)", "No network and no cached config available")
            XCTAssertEqual(error.localizedDescription, "No network and no cached config available")
        }
    }
}

/// D1: FileKeyValueStore, one file per key under a directory, so saved state
/// survives a restart (a new instance over the same directory).
final class FileKeyValueStoreTests: XCTestCase {
    var dir: URL!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("orca-kv-\(UUID().uuidString)").appendingPathComponent("OrcaGateway")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir.deletingLastPathComponent())
        super.tearDown()
    }

    func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
    }

    func testC14_3_fileStoreKeepsAValueAcrossANewInstance() {
        let store = FileKeyValueStore(directory: dir)
        XCTAssertEqual(store.directory, dir)
        store.set(#"{"main":4}"#, forKey: "orca_flow_versions")
        store.set("second", forKey: "orca_flow_versions")
        XCTAssertEqual(store.string(forKey: "orca_flow_versions"), "second")
        XCTAssertEqual(FileKeyValueStore(directory: dir).string(forKey: "orca_flow_versions"), "second")
        XCTAssertNil(FileKeyValueStore(directory: dir).string(forKey: "orca_nav_config"))
        store.set("", forKey: "empty")
        XCTAssertEqual(FileKeyValueStore(directory: dir).string(forKey: "empty"), "", "empty is not absent")
    }

    func testC14_3_fileStoreNilRemovesTheValueAndItsFile() throws {
        let store = FileKeyValueStore(directory: dir)
        store.set("x", forKey: "orca_pages_main")
        store.set("y", forKey: "orca_nav_config")
        XCTAssertEqual(try files().count, 2)
        store.set(nil, forKey: "orca_pages_main")
        XCTAssertNil(store.string(forKey: "orca_pages_main"))
        XCTAssertNil(FileKeyValueStore(directory: dir).string(forKey: "orca_pages_main"))
        XCTAssertEqual(try files().count, 1)
        store.set(nil, forKey: "never-saved")
        XCTAssertEqual(store.string(forKey: "orca_nav_config"), "y")
    }

    func testC14_3_fileStoreCreatesItsDirectoryOnFirstWriteAndLeavesNoTempFiles() throws {
        let store = FileKeyValueStore(directory: dir)
        XCTAssertNil(store.string(forKey: "orca_nav_config"))
        store.set(nil, forKey: "orca_nav_config")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path), "reads and removes create nothing")
        for i in 0..<5 { store.set("v\(i)", forKey: "orca_nav_config") }
        XCTAssertEqual(try files(), ["orca_nav_config"], "each write replaces the one file")
        XCTAssertEqual(store.string(forKey: "orca_nav_config"), "v4")
    }

    func testC14_3_fileStoreKeepsOddKeysApartInsideItsDirectory() throws {
        let keys = ["", ".", "..", "a/b", "../escape", "Main", "main", "ü ñ", "orca_pages_x:y", "a%2Fb", "%"]
        let store = FileKeyValueStore(directory: dir)
        for (i, key) in keys.enumerated() { store.set("value \(i)", forKey: key) }
        let restarted = FileKeyValueStore(directory: dir)
        for (i, key) in keys.enumerated() {
            XCTAssertEqual(restarted.string(forKey: key), "value \(i)", "key \"\(key)\"")
        }
        let names = try files()
        XCTAssertEqual(names.count, keys.count, "one file per key: \(names)")
        XCTAssertTrue(names.contains("main"), "a plain key is its own file name: \(names)")
        for name in names {
            var isDir: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: dir.appendingPathComponent(name).path, isDirectory: &isDir))
            XCTAssertFalse(isDir.boolValue, name)
        }
        let parent = try FileManager.default.contentsOfDirectory(atPath: dir.deletingLastPathComponent().path)
        XCTAssertEqual(parent, ["OrcaGateway"], "nothing escapes the directory")
    }

    func testC14_3_fileStoreIsSafeFromManyThreads() {
        let store = FileKeyValueStore(directory: dir)
        DispatchQueue.concurrentPerform(iterations: 200) { i in
            store.set("v\(i)", forKey: "k\(i % 8)")
            _ = store.string(forKey: "k\((i + 3) % 8)")
        }
        for k in 0..<8 {
            let value = FileKeyValueStore(directory: dir).string(forKey: "k\(k)")
            XCTAssertNotNil(value, "k\(k)")
            XCTAssertEqual(value.flatMap { Int($0.dropFirst()) }.map { $0 % 8 }, k)
        }
    }
}
