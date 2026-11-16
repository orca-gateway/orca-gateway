import Foundation
import XCTest

@testable import OrcaGatewayCore

/// The engine as an offline fixture case answers it: `/version` to one
/// transport, `/config` to another, every request's name recorded in order.
/// Each answer is the core tests' own stub: a `StubEngine` that answers with
/// the fixture's status and body text, or `DownTransport` for `"fail"` (and
/// for a `/config` the case does not answer), as Flutter's runner throws a
/// `ClientException` there.
final class OfflineRoutes: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [String] = []
    private let version: HTTPTransport
    private let config: HTTPTransport

    init(version: HTTPTransport, config: HTTPTransport) {
        self.version = version
        self.config = config
    }

    /// A fixture answer as a transport: `"fail"` or nothing never reaches a
    /// server; `{status, body}` sends the body's JSON text with that status.
    static func answer(_ json: JSONValue?) throws -> HTTPTransport {
        guard let json, json != "fail" else { return DownTransport() }
        let stub = StubEngine(page: Data())
        stub.forced = HTTPResponse(status: json["status"].intValue ?? 0, body: Data(try wireText(json["body"]).utf8))
        return stub
    }

    static func client(_ transport: HTTPTransport) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "static-flows", transport: transport)
    }

    /// "version", "config", or the path of any other request.
    var requests: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    /// Synchronous, so the lock is never held across a suspension point.
    private func record(_ name: String) {
        lock.lock()
        _requests.append(name)
        lock.unlock()
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let path = request.url.path
        if path.hasSuffix("/version") {
            record("version")
            return try await version.send(request)
        }
        if path.hasSuffix("/config") {
            record("config")
            return try await config.send(request)
        }
        record(path)
        return HTTPResponse(status: 404)
    }
}

/// C14.1-C14.5: schema/fixtures/offline through the Swift core's real
/// `preload` and `StaticFlowManager`, as the Flutter runner
/// (sdk/test/conformance/offline_fixtures_test.dart) runs them through
/// `OrcaApp.preload`. Each case seeds a MemoryKeyValueStore with `saved` (each
/// value as its JSON text), answers /version and /config over `OfflineRoutes`,
/// boots once, then compares the requests, the result, the store after (keys
/// exactly; the config text as served or unchanged, the versions exactly, the
/// pages by their paths) and, for a config, what the cache serves once it knows
/// that config's dynamic paths. Every case of every file runs; a new file needs
/// no edit here.
final class OfflineFixtureTests: XCTestCase {
    static let configKey = "orca_nav_config"
    static let versionsKey = "orca_flow_versions"
    static let pagesPrefix = "orca_pages_"

    /// Case ids (phase-c-tests.md rows) per case name, Flutter's `_rowsOf`.
    static let rowsOf: [String: [String]] = [
        "first online boot": ["C14_1", "C14_2"],
        "fresh: saved versions equal the remote ones": ["C14_3"],
        "fresh with no saved config": ["C14_3"],
        "stale: a flow version moved": ["C14_3"],
        "offline with a saved config": ["C14_1", "C14_2"],
        "offline is any /version failure, an error status too": ["C14_2"],
        "offline with nothing saved": ["C14_2", "C14_5"],
        "force update wins over a stale version": ["C14_5"],
        "cleanup: a versioned flow gone from the refetched config": ["C14_4"],
        "an unversioned flow gone from the config keeps its pages": ["C14_4"],
        "a dynamic route is never served, even with a saved page": ["C14_4"],
        "the cache reads the saved pages, not the pages inside the config": ["C14_1"],
        "quirk: an unversioned flow keeps the boot stale": ["C14_3"],
        "a stale boot whose /config fails does not fall back": ["C14_3", "C14_5"],
    ]

    /// The member names of an object, none for anything else.
    func keysOf(_ json: JSONValue) -> Set<String> {
        Set(json.objectValue.map { Array($0.keys) } ?? [])
    }

    func cases() throws -> [(label: String, json: JSONValue)] {
        try Fixtures.files("offline").flatMap { name, fx in
            (fx["cases"].arrayValue ?? []).map { ("\(name) · \($0["name"].stringValue ?? "?")", $0) }
        }
    }

    // MARK: Rows

    func testC14_1_staticPagesSavedAtBootOpenFromTheCache() async throws {
        try await runRow("C14_1")
    }

    func testC14_2_anOfflineBootUsesTheSavedConfigOrFails() async throws {
        try await runRow("C14_2")
    }

    func testC14_3_freshUsesTheSavedConfigWithNoConfigRequestAndStaleRefetchesIt() async throws {
        try await runRow("C14_3")
    }

    func testC14_4_dynamicRoutesAreNeverServedAndAGoneVersionedFlowIsCleanedUp() async throws {
        try await runRow("C14_4")
    }

    func testC14_5_preloadGivesTheConfigForceUpdateOrTheBootError() async throws {
        try await runRow("C14_5")
    }

    func testC14_1to5_everyCaseOfEveryOfflineFixtureMatchesFlutter() async throws {
        let all = try cases()
        XCTAssertFalse(all.isEmpty, "schema/fixtures/offline holds no case")
        for (label, c) in all { try await run(label, c) }
    }

    /// Flutter's family check: every file and case well formed, and at least
    /// one case of each result, so an empty or missing folder fails.
    func testC14_1to5_theOfflineFamilyIsWellFormedAndCoversEveryResult() throws {
        let files = try Fixtures.files("offline")
        XCTAssertFalse(files.isEmpty)
        var results: Set<String> = []
        for (name, fx) in files {
            XCTAssertEqual(keysOf(fx), ["name", "description", "cases"], name)
            let list = fx["cases"].arrayValue ?? []
            XCTAssertFalse(list.isEmpty, name)
            for c in list {
                let label = "\(name) · \(c["name"].stringValue ?? "?")"
                wellFormed(label, c)
                let r = c["expected"]["result"]
                results.insert(r.stringValue ?? r.objectValue?.keys.first ?? "?")
            }
        }
        XCTAssertEqual(results, ["config", "forceUpdate", "error"])
    }

    // MARK: Runner

    func runRow(_ row: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        var ran = 0
        for (label, c) in try cases() where Self.rowsOf[c["name"].stringValue ?? ""]?.contains(row) == true {
            try await run(label, c)
            ran += 1
        }
        XCTAssertGreaterThan(ran, 0, "no offline case for \(row)", file: file, line: line)
    }

    func wellFormed(_ label: String, _ c: JSONValue) {
        let keys = keysOf(c)
        XCTAssertTrue(keys.isSubset(of: ["name", "description", "saved", "version", "config", "expected"]), label)
        XCTAssertTrue(keys.isSuperset(of: ["name", "description", "saved", "version", "expected"]), label)
        XCTAssertNotNil(c["description"].stringValue, label)
        for key in (c["saved"].objectValue ?? [:]).keys {
            XCTAssertTrue(key == Self.configKey || key == Self.versionsKey || key.hasPrefix(Self.pagesPrefix),
                          "\(label): saved key \(key)")
        }
        XCTAssertNotNil(c["saved"].objectValue, "\(label): saved")
        XCTAssertTrue(c["version"] == "fail" || c["version"].objectValue != nil, "\(label): version")
        if keys.contains("config") { XCTAssertNotNil(c["config"].objectValue, "\(label): config") }
        let e = c["expected"]
        XCTAssertEqual(keysOf(e), ["requests", "result", "saved", "serves"], label)
        XCTAssertTrue((e["requests"].arrayValue ?? []).allSatisfy { $0 == "version" || $0 == "config" }, label)
        let r = e["result"]
        let one = r.objectValue.map { $0.count == 1 ? $0.keys.first! : "" }
        XCTAssertTrue(r == "forceUpdate" || one == "config" || one == "error", "\(label): result")
        XCTAssertNotNil(e["saved"].objectValue, "\(label): expected saved")
        XCTAssertNotNil(e["serves"].objectValue, "\(label): serves")
        if one != "config" { XCTAssertEqual(e["serves"].objectValue?.count, 0, "\(label): serves needs a config") }
    }

    func run(_ label: String, _ c: JSONValue) async throws {
        let expected = c["expected"]
        var seed: [String: String] = [:]
        for (key, value) in c["saved"].objectValue ?? [:] { seed[key] = try wireText(value) }
        let answersConfig = c.objectValue?["config"] != nil
        let configText = answersConfig ? try wireText(c["config"]["body"]) : nil

        let store = MemoryKeyValueStore(seed)
        let routes = OfflineRoutes(
            version: try OfflineRoutes.answer(c["version"]),
            config: try OfflineRoutes.answer(answersConfig ? c["config"] : nil))
        let cache = StaticFlowManager(store: store)

        var result: PreloadResult?
        var failure: Error?
        do {
            result = try await preload(client: OfflineRoutes.client(routes), cache: cache)
        } catch {
            failure = error
        }

        XCTAssertEqual(routes.requests, (expected["requests"].arrayValue ?? []).compactMap(\.stringValue),
                       "\(label): requests")

        let want = expected["result"]
        if want == "forceUpdate" {
            XCTAssertNil(failure, "\(label): boot error")
            XCTAssertEqual(result, .forceUpdate, "\(label): result")
        } else if let error = want.objectValue?["error"] {
            XCTAssertNil(result, "\(label): result")
            if let message = error.stringValue {
                XCTAssertTrue(failure is OfflineBootError, "\(label): \(String(describing: failure))")
                XCTAssertEqual(failure.map { "\($0)" }, message, "\(label): error text")
            } else if case .http(let status, _)? = failure as? OrcaClientError {
                XCTAssertEqual(status, error["status"].intValue, "\(label): error status")
            } else {
                XCTFail("\(label): \(String(describing: failure)) is not the client's HTTP error")
            }
        } else if case .success(let config)? = result {
            XCTAssertNil(failure, "\(label): boot error")
            let flows = JSONValue.object(Dictionary(
                config.flows.map { ($0.name, $0.version.map(JSONValue.int) ?? .null) },
                uniquingKeysWith: { first, _ in first }))
            assertJSONEqual(flows, want["config"], "\(label): config flows")
        } else {
            XCTFail("\(label): wanted a config, got \(String(describing: result)), \(String(describing: failure))")
        }

        let after = store.values
        let wantSaved = expected["saved"].objectValue ?? [:]
        XCTAssertEqual(Set(after.keys), Set(wantSaved.keys), "\(label): keys")
        for (key, value) in wantSaved {
            guard let stored = after[key] else { continue }
            if key == Self.configKey {
                XCTAssertTrue(value == "config" || value == "saved", "\(label): \(key)")
                XCTAssertEqual(stored, value == "config" ? configText : seed[key], "\(label): \(key) \(value)")
            } else if key == Self.versionsKey {
                assertJSONEqual(try JSONValue.decode(Data(stored.utf8)), value, "\(label): \(key)")
            } else {
                XCTAssertEqual(keysOf(try JSONValue.decode(Data(stored.utf8))),
                               Set((value.arrayValue ?? []).compactMap(\.stringValue)), "\(label): \(key)")
            }
        }

        let serves = expected["serves"].objectValue ?? [:]
        if case .success(let config)? = result {
            cache.initDynamicPaths(config.flows)
            var got: [String: JSONValue] = [:]
            for path in serves.keys {
                got[path] = try cache.getCachedPage(path, flows: config.flows).map { .string($0.pageId) } ?? .null
            }
            assertJSONEqual(.object(got), .object(serves), "\(label): serves")
        }
    }
}
