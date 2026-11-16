#if canImport(SwiftUI)
import Foundation
import XCTest

@testable import OrcaGateway

/// The engine's `/version` route answering one response (or unreachable),
/// and a page for any other path. Every request is kept.
final class VersionStub: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    /// The `/version` answer; nil means the server cannot be reached.
    private let version: HTTPResponse?

    init(_ version: HTTPResponse?) {
        self.version = version
    }

    convenience init(_ body: String, status: Int = 200) {
        self.init(HTTPResponse(status: status, body: Data(body.utf8)))
    }

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _requests.map(\.url.path)
    }

    private func record(_ request: HTTPRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        record(request)
        guard request.url.path.hasSuffix("/version") else {
            return try await PageStub().send(request)
        }
        guard let version else { throw URLError(.notConnectedToInternet) }
        return version
    }
}

/// C15.1 (boot part): with enableOffline, a forceUpdate answer to the
/// version check blocks the app before any page is fetched; every other
/// answer boots as before, and without enableOffline no `/version` request
/// is made (Flutter checks versions only in its offline boot,
/// sdk/lib/src/widgets/orca_app.dart `OrcaApp.preload`). Also the device id
/// OrcaApp gives a client that has none, and the one session tracker it
/// holds behind enableSessionTracking.
@MainActor
final class OrcaBootTests: XCTestCase {
    let versionPath = "/api/v1/app/fixture-app/version"

    func client(_ stub: VersionStub, deviceId: String? = nil) -> OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   deviceId: deviceId, device: DeviceInfo(osVersion: "test"), transport: stub)
    }

    func boot(offline: Bool, sessions: Bool = false,
              store: KeyValueStore = MemoryKeyValueStore()) -> OrcaBootModel {
        OrcaBootModel(enableOffline: offline, enableSessionTracking: sessions, store: store)
    }

    func testC15_1_withEnableOfflineAForceUpdateAnswerBlocksTheAppAndFetchesNoPage() async {
        let stub = VersionStub(#"{"flows": {"home": 1}, "forceUpdate": true}"#)
        let model = boot(offline: true)
        XCTAssertEqual(model.phase, .checking)
        await model.start(client: client(stub))
        XCTAssertEqual(model.phase, .forceUpdate)
        XCTAssertEqual(stub.paths, [versionPath], "only /version, no page")
    }

    func testC15_1_withEnableOfflineFreshStaleAndOfflineAnswersBoot() async {
        let answers: [(String, VersionStub)] = [
            ("fresh", VersionStub(#"{"flows": {}}"#)),
            ("stale", VersionStub(#"{"flows": {"home": 2}}"#)),
            ("offline: unreachable", VersionStub(nil)),
            ("offline: 500", VersionStub("boom", status: 500)),
            ("offline: not json", VersionStub("<html>")),
        ]
        for (name, stub) in answers {
            let model = boot(offline: true)
            await model.start(client: client(stub))
            XCTAssertEqual(model.phase, .ready, name)
            XCTAssertEqual(stub.paths, [versionPath], name)
        }
    }

    func testC15_1_withoutEnableOfflineTheAppIsReadyWithNoVersionRequest() async {
        let stub = VersionStub(#"{"flows": {}, "forceUpdate": true}"#)
        let model = boot(offline: false)
        XCTAssertEqual(model.phase, .ready)
        await model.start(client: client(stub))
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(stub.paths, [])
    }

    func testC15_1_theVersionCheckRunsOnce() async {
        let stub = VersionStub(#"{"flows": {}}"#)
        let model = boot(offline: true)
        await model.start(client: client(stub))
        await model.start(client: client(stub))
        XCTAssertEqual(stub.paths, [versionPath])
    }

    /// Step 14: the gate's check is for a host `path` (and a host's router)
    /// only; it caches nothing, a cache given or not. The config boot runs
    /// `preload` instead (OfflineBootTests).
    func testC14_2_withAPathEnableOfflineIsTheVersionCheckAloneAndCachesNothing() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orca-boot-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stub = VersionStub(#"{"flows": {"main": 4}}"#)
        let cache = StaticFlowManager(store: FileKeyValueStore(directory: directory))
        try await showForAMoment(OrcaApp(client: client(stub, deviceId: "test-device"), path: "home",
                                         enableOffline: true, staticFlowManager: cache))
        XCTAssertEqual(stub.paths, [versionPath, "/api/v1/app/fixture-app/page/home"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "nothing saved")
    }

    func testC15_1_aClientWithoutADeviceIdGetsTheStoredOne() {
        let store = MemoryKeyValueStore()
        let id = client(VersionStub(#"{}"#)).identified(by: store).deviceId
        XCTAssertNotNil(id)
        XCTAssertEqual(store.string(forKey: DeviceIdentity.storageKey), id)
        XCTAssertEqual(client(VersionStub(#"{}"#), deviceId: "").identified(by: store).deviceId, id)
    }

    func testC15_1_aClientWithADeviceIdKeepsIt() {
        let store = MemoryKeyValueStore()
        let c = client(VersionStub(#"{}"#), deviceId: "host-id").identified(by: store)
        XCTAssertEqual(c.deviceId, "host-id")
        XCTAssertNil(store.string(forKey: DeviceIdentity.storageKey), "the store is not touched")
    }

    func testC15_1_sessionTrackingHoldsOneTrackerWithTheResolvedDeviceId() async {
        let store = MemoryKeyValueStore(["orca_device_id": "stored-id"])
        let c = client(VersionStub(#"{}"#))
        XCTAssertNil(boot(offline: false, sessions: false, store: store).sessionTracker(client: c))

        let model = boot(offline: false, sessions: true, store: store)
        let tracker = model.sessionTracker(client: c)
        XCTAssertNotNil(tracker)
        XCTAssertTrue(tracker === model.sessionTracker(client: c), "one tracker for the app's lifetime")
        let id = await tracker?.deviceId
        XCTAssertEqual(id, "stored-id")
    }

    func testC15_1_userDefaultsStoreSavesAndRemoves() throws {
        let suite = "orca.boot.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsKeyValueStore(defaults)
        XCTAssertNil(store.string(forKey: "k"))
        store.set("v", forKey: "k")
        XCTAssertEqual(UserDefaultsKeyValueStore(defaults).string(forKey: "k"), "v")
        store.set(nil, forKey: "k")
        XCTAssertNil(store.string(forKey: "k"))
    }
}
#endif
