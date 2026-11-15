import Foundation
import XCTest

@testable import OrcaGatewayCore

/// A clock that reads the given times in order, then stays on the last one.
private final class SteppingClock: @unchecked Sendable {
    private let lock = NSLock()
    private var times: [Date]

    init(_ times: [Date]) { self.times = times }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return times.count > 1 ? times.removeFirst() : times[0]
    }
}

/// C15.2: a session starts on foreground and ends on background (Flutter
/// posts `{type, deviceId}` to /session and no duration). C15.3: sessions
/// recorded offline are queued in OfflineSessionStore and sent to
/// /session/offline on the next foreground with the network back. Ports
/// sendSessionStart, sendSessionEnd and flushOfflineSessions of
/// sdk/lib/src/client/orca_client.dart and sdk/lib/src/client/offline_session_store.dart.
final class SessionTrackerTests: XCTestCase {
    let base = URL(string: "http://localhost:8080")!
    let t0 = Date(timeIntervalSince1970: 1_763_200_000)
    let t1 = Date(timeIntervalSince1970: 1_763_200_060.5)
    let t0ms: Int64 = 1_763_200_000_000
    let t1ms: Int64 = 1_763_200_060_500

    func client(_ transport: HTTPTransport, deviceId: String? = "dev-1") -> OrcaClient {
        OrcaClient(baseURL: base, appId: "counter", deviceId: deviceId, transport: transport)
    }

    /// An engine that answers every request with `status`.
    func engine(_ status: Int = 200) -> StubEngine {
        let stub = StubEngine(page: Data())
        stub.forced = HTTPResponse(status: status)
        return stub
    }

    func body(_ request: HTTPRequest) throws -> JSONValue {
        try JSONValue.decode(request.body ?? Data())
    }

    func jsonHeaders(_ c: OrcaClient) -> [String: String] {
        var h = c.headers
        h["Content-Type"] = "application/json"
        return h
    }

    // MARK: C15.2 one session per foreground period

    func testC15_2_foregroundPostsStartAndBackgroundPostsEndWithTheDeviceId() async throws {
        let stub = engine()
        let c = client(stub)
        let tracker = SessionTracker(
            client: c, deviceId: "dev-1", offline: OfflineSessionStore(store: MemoryKeyValueStore()))

        await tracker.foreground()
        let open = await tracker.isOpen
        XCTAssertTrue(open)
        await tracker.background()
        let closed = await tracker.isOpen
        XCTAssertFalse(closed)

        let requests = stub.requests
        XCTAssertEqual(requests.count, 2, "nothing pending offline, so no flush request")
        for request in requests {
            XCTAssertEqual(request.method, "POST")
            XCTAssertEqual(request.url.absoluteString, "http://localhost:8080/api/v1/app/counter/session")
            XCTAssertEqual(request.headers, jsonHeaders(c))
        }
        XCTAssertEqual(try body(requests[0]), ["type": "start", "deviceId": "dev-1"])
        XCTAssertEqual(try body(requests[1]), ["type": "end", "deviceId": "dev-1"])
        XCTAssertEqual(String(decoding: requests[0].body ?? Data(), as: UTF8.self),
                       #"{"deviceId":"dev-1","type":"start"}"#)
    }

    func testC15_2_aSecondForegroundWithoutABackgroundOpensNoSecondSession() async throws {
        let stub = engine()
        let tracker = SessionTracker(
            client: client(stub), deviceId: "dev-1", offline: OfflineSessionStore(store: MemoryKeyValueStore()))

        await tracker.foreground()
        await tracker.foreground()
        XCTAssertEqual(try stub.requests.map { try body($0)["type"] }, ["start"])

        await tracker.background()
        await tracker.background()
        XCTAssertEqual(try stub.requests.map { try body($0)["type"] }, ["start", "end"])

        await tracker.foreground()
        XCTAssertEqual(try stub.requests.map { try body($0)["type"] }, ["start", "end", "start"],
                       "a foreground after a background opens the next session")
    }

    func testC15_2_backgroundWithoutAnOpenSessionSendsNothing() async {
        let stub = engine()
        let tracker = SessionTracker(
            client: client(stub), deviceId: "dev-1", offline: OfflineSessionStore(store: MemoryKeyValueStore()))

        await tracker.background()
        XCTAssertTrue(stub.requests.isEmpty)
    }

    func testC15_2_theDeviceIdKeyIsAbsentWhenNil() async throws {
        let stub = engine()
        let c = client(stub, deviceId: nil)
        try await c.sendSession("start", deviceId: nil)

        let tracker = SessionTracker(
            client: c, deviceId: nil, offline: OfflineSessionStore(store: MemoryKeyValueStore()))
        await tracker.foreground()

        XCTAssertEqual(stub.requests.count, 2)
        for request in stub.requests {
            XCTAssertEqual(try body(request), ["type": "start"])
            XCTAssertEqual(String(decoding: request.body ?? Data(), as: UTF8.self), #"{"type":"start"}"#)
            XCTAssertNil(request.headers["x-orca-device-id"])
        }
    }

    // MARK: C15.3 the offline queue

    func testC15_3_aThrowingTransportQueuesStartAndEndWithTheirTimestamps() async throws {
        let kv = MemoryKeyValueStore()
        let clock = SteppingClock([t0, t1])
        let offline = OfflineSessionStore(store: kv, clock: { clock.now() })
        let tracker = SessionTracker(client: client(DownTransport()), deviceId: "dev-1", offline: offline)

        await tracker.foreground()
        await tracker.background()

        XCTAssertEqual(offline.load(), [
            OfflineSessionRecord(type: "start", timestamp: t0ms),
            OfflineSessionRecord(type: "end", timestamp: t1ms),
        ])
        XCTAssertTrue(offline.hasPending)
        let closed = await tracker.isOpen
        XCTAssertFalse(closed, "the session closes even when its end is queued")
        let raw = try XCTUnwrap(kv.string(forKey: "orca_offline_sessions"))
        XCTAssertEqual(try JSONValue.decode(Data(raw.utf8)), [
            ["type": "start", "timestamp": .int(Int(t0ms))],
            ["type": "end", "timestamp": .int(Int(t1ms))],
        ])
        XCTAssertEqual(OfflineSessionStore.storageKey, "orca_offline_sessions")
    }

    func testC15_3_theNextForegroundWithTheNetworkBackPostsTheQueueAndClearsIt() async throws {
        let kv = MemoryKeyValueStore()
        let clock = SteppingClock([t0, t1])
        let offline = OfflineSessionStore(store: kv, clock: { clock.now() })
        let down = SessionTracker(client: client(DownTransport()), deviceId: "dev-1", offline: offline)
        await down.foreground()
        await down.background()

        let stub = engine()
        let c = client(stub)
        let online = SessionTracker(client: c, deviceId: "dev-1", offline: offline)
        await online.foreground()

        let requests = stub.requests
        XCTAssertEqual(requests.map(\.url.absoluteString), [
            "http://localhost:8080/api/v1/app/counter/session",
            "http://localhost:8080/api/v1/app/counter/session/offline",
        ])
        XCTAssertEqual(try body(requests[0]), ["type": "start", "deviceId": "dev-1"])
        XCTAssertEqual(requests[1].method, "POST")
        XCTAssertEqual(requests[1].headers, jsonHeaders(c))
        XCTAssertEqual(try body(requests[1]), [
            "deviceId": "dev-1",
            "sessions": [
                ["type": "start", "timestamp": .int(Int(t0ms))],
                ["type": "end", "timestamp": .int(Int(t1ms))],
            ],
        ])
        XCTAssertEqual(offline.load(), [])
        XCTAssertFalse(offline.hasPending)
        XCTAssertEqual(kv.string(forKey: "orca_offline_sessions"), "[]")
    }

    func testC15_3_aFailedFlushKeepsTheQueue() async throws {
        let offline = OfflineSessionStore(store: MemoryKeyValueStore(), clock: { self.t0 })
        offline.save("start")
        offline.save("end")
        let queued = offline.load()

        let stub = engine(500)
        let tracker = SessionTracker(client: client(stub), deviceId: "dev-1", offline: offline)
        await tracker.foreground()
        XCTAssertEqual(stub.requests.map(\.url.path), [
            "/api/v1/app/counter/session", "/api/v1/app/counter/session/offline",
        ])
        XCTAssertEqual(offline.load(), queued, "a 500 keeps the queue, and the 500 start is not queued")

        let flushed = await tracker.flush()
        XCTAssertFalse(flushed)
        XCTAssertEqual(offline.load(), queued)

        let downFlush = await SessionTracker(
            client: client(DownTransport()), deviceId: "dev-1", offline: offline).flush()
        XCTAssertFalse(downFlush)
        XCTAssertEqual(offline.load(), queued)
    }

    func testC15_3_sendOfflineSessionsIsTrueOnlyOn200() async {
        let sessions = [OfflineSessionRecord(type: "start", timestamp: t0ms)]
        for (status, expected) in [(200, true), (201, false), (204, false), (500, false)] {
            let ok = await client(engine(status)).sendOfflineSessions(deviceId: "dev-1", sessions: sessions)
            XCTAssertEqual(ok, expected, "status \(status)")
        }
        let down = await client(DownTransport()).sendOfflineSessions(deviceId: "dev-1", sessions: sessions)
        XCTAssertFalse(down)
    }

    func testC15_3_aNonSuccessAnswerToSessionIsNotQueued() async throws {
        let stub = engine(503)
        try await client(stub).sendSession("start", deviceId: "dev-1")

        let offline = OfflineSessionStore(store: MemoryKeyValueStore())
        let tracker = SessionTracker(client: client(stub), deviceId: "dev-1", offline: offline)
        await tracker.foreground()
        await tracker.background()
        XCTAssertEqual(offline.load(), [])
        XCTAssertEqual(stub.requests.count, 3, "two session posts plus the direct one; nothing to flush")
    }

    func testC15_3_aSessionPostThatThrowsThrows() async {
        do {
            try await client(DownTransport()).sendSession("start", deviceId: "dev-1")
            XCTFail("a dead transport throws")
        } catch {}
    }

    func testC15_3_flushWithoutADeviceIdIsANoOpReturningTrue() async {
        let offline = OfflineSessionStore(store: MemoryKeyValueStore(), clock: { self.t0 })
        offline.save("start")
        let stub = engine()
        let tracker = SessionTracker(client: client(stub, deviceId: nil), deviceId: nil, offline: offline)

        let flushed = await tracker.flush()
        XCTAssertTrue(flushed)
        XCTAssertTrue(stub.requests.isEmpty)
        XCTAssertEqual(offline.load(), [OfflineSessionRecord(type: "start", timestamp: t0ms)])
    }

    func testC15_3_nothingPendingSendsNoRequest() async {
        let stub = engine()
        let tracker = SessionTracker(
            client: client(stub), deviceId: "dev-1", offline: OfflineSessionStore(store: MemoryKeyValueStore()))

        let flushed = await tracker.flush()
        XCTAssertTrue(flushed)
        XCTAssertTrue(stub.requests.isEmpty)
    }

    func testC15_3_theQueueSurvivesARestart() {
        let before = MemoryKeyValueStore()
        let clock = SteppingClock([t0, t1])
        let first = OfflineSessionStore(store: before, clock: { clock.now() })
        first.save("start")
        first.save("end")

        let after = OfflineSessionStore(store: MemoryKeyValueStore(before.values))
        XCTAssertEqual(after.load(), [
            OfflineSessionRecord(type: "start", timestamp: t0ms),
            OfflineSessionRecord(type: "end", timestamp: t1ms),
        ])
        XCTAssertTrue(after.hasPending)
    }

    func testC15_3_missingEmptyOrCorruptTextLoadsAsNothingAndClearWritesAnEmptyArray() {
        let kv = MemoryKeyValueStore()
        let offline = OfflineSessionStore(store: kv, clock: { self.t0 })
        XCTAssertEqual(offline.load(), [])
        XCTAssertFalse(offline.hasPending)
        for corrupt in ["", "not json", #"{"type":"start"}"#, #"[{"type":"start"}]"#, #"[{"type":1,"timestamp":2}]"#] {
            kv.set(corrupt, forKey: "orca_offline_sessions")
            XCTAssertEqual(offline.load(), [], corrupt)
        }

        offline.save("start")
        XCTAssertEqual(offline.load(), [OfflineSessionRecord(type: "start", timestamp: t0ms)],
                       "a save over corrupt text starts a new queue")
        offline.clear()
        XCTAssertEqual(kv.string(forKey: "orca_offline_sessions"), "[]")
        XCTAssertEqual(offline.load(), [])
    }
}
