import Foundation

/// One session event (start or end) kept while the device is offline, the
/// Dart `OfflineSessionRecord` (sdk/lib/src/client/offline_session_store.dart).
/// JSON: `{"type": "start", "timestamp": 1763200000000}`.
public struct OfflineSessionRecord: Equatable, Sendable {
    /// "start" or "end".
    public var type: String
    /// Milliseconds since the epoch.
    public var timestamp: Int64

    public init(type: String, timestamp: Int64) {
        self.type = type
        self.timestamp = timestamp
    }

    var json: JSONValue {
        ["type": .string(type), "timestamp": .int(Int(timestamp))]
    }

    init?(json: JSONValue) {
        guard let type = json["type"].stringValue, case .int(let ms) = json["timestamp"] else { return nil }
        self.init(type: type, timestamp: Int64(ms))
    }
}

/// The session events that could not be sent, kept in a KeyValueStore so
/// they survive a restart, a port of `OfflineSessionStore` in
/// sdk/lib/src/client/offline_session_store.dart. Saved under
/// `orca_offline_sessions` as a JSON array of records. Safe from any thread.
public final class OfflineSessionStore: @unchecked Sendable {
    /// The key the queue is saved under.
    public static let storageKey = "orca_offline_sessions"

    private let store: KeyValueStore
    private let clock: @Sendable () -> Date
    private let lock = NSLock()

    /// A queue over `store`; `clock` stamps each saved event.
    public init(store: KeyValueStore, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.clock = clock
    }

    /// Append an event of `type` with the clock's time.
    public func save(_ type: String) {
        let ms = Int64((clock().timeIntervalSince1970 * 1000).rounded(.down))
        locked {
            write(read() + [OfflineSessionRecord(type: type, timestamp: ms)])
        }
    }

    /// Every queued event, oldest first; none when nothing is saved or the
    /// saved text is empty or not a list of records, as in Dart.
    public func load() -> [OfflineSessionRecord] {
        locked { read() }
    }

    /// Empty the queue after a successful flush (writes "[]", as Dart does).
    public func clear() {
        locked { store.set("[]", forKey: Self.storageKey) }
    }

    /// Whether any event waits to be sent.
    public var hasPending: Bool { !load().isEmpty }

    /// Call with the lock held.
    private func read() -> [OfflineSessionRecord] {
        guard let raw = store.string(forKey: Self.storageKey), !raw.isEmpty,
              let items = (try? JSONValue.decode(Data(raw.utf8)))?.arrayValue
        else { return [] }
        var records: [OfflineSessionRecord] = []
        for item in items {
            guard let record = OfflineSessionRecord(json: item) else { return [] }
            records.append(record)
        }
        return records
    }

    /// Call with the lock held.
    private func write(_ records: [OfflineSessionRecord]) {
        guard let data = try? JSONValue.array(records.map(\.json)).encoded() else { return }
        store.set(String(decoding: data, as: UTF8.self), forKey: Self.storageKey)
    }

    /// NSLock.withLock is missing from older Linux Foundation releases.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// Reports app sessions to the engine: a start when the app comes to the
/// foreground, an end when it goes to the background. A port of
/// `sendSessionStart`, `sendSessionEnd` and `flushOfflineSessions` in
/// sdk/lib/src/client/orca_client.dart, driven as `_OrcaAppState` drives them
/// in sdk/lib/src/widgets/orca_app.dart. An event whose POST fails to reach
/// the server is queued in the OfflineSessionStore, and the queue is sent to
/// `/session/offline` on each foreground.
///
/// Where it differs from Flutter, on purpose: Flutter sends a start on every
/// `resumed`, also after `inactive` (pulling down Control Center), which can
/// open two sessions; the tracker keeps one session per foreground period.
/// Like Flutter it sends no duration: the server times a session from its
/// start and end.
public actor SessionTracker {
    public let client: OrcaClient
    /// Sent in each event and needed to flush the queue.
    public let deviceId: String?
    public let offline: OfflineSessionStore
    /// Whether a session is open (a start was sent or queued, no end yet).
    public private(set) var isOpen = false
    private var flushing = false

    public init(client: OrcaClient, deviceId: String?, offline: OfflineSessionStore) {
        self.client = client
        self.deviceId = deviceId
        self.offline = offline
    }

    /// The app came to the foreground: open a session unless one is open,
    /// then flush the offline queue.
    public func foreground() async {
        if !isOpen {
            isOpen = true
            do {
                try await client.sendSession("start", deviceId: deviceId)
            } catch {
                offline.save("start")
            }
        }
        await flush()
    }

    /// The app went to the background: end the open session, if any.
    public func background() async {
        guard isOpen else { return }
        isOpen = false
        do {
            try await client.sendSession("end", deviceId: deviceId)
        } catch {
            offline.save("end")
        }
    }

    /// Send the offline queue and clear it once the server took it. True
    /// when nothing needed sending (no device id, as Dart skips the flush
    /// without one; an empty queue; a flush already in flight) or the send
    /// succeeded.
    @discardableResult
    public func flush() async -> Bool {
        guard let deviceId, !flushing else { return true }
        let records = offline.load()
        if records.isEmpty { return true }
        flushing = true
        let ok = await client.sendOfflineSessions(deviceId: deviceId, sessions: records)
        flushing = false
        if ok { offline.clear() }
        return ok
    }
}

extension OrcaClient {
    /// `POST /api/v1/app/{appId}/session` with `{"type", "deviceId"}` (no
    /// deviceId key when nil), the Dart `sendSessionStart` / `sendSessionEnd`.
    /// Any answer returns normally; only a request that fails to reach the
    /// server throws, the one case Dart queues offline.
    public func sendSession(_ type: String, deviceId: String?) async throws {
        var body: [String: JSONValue] = ["type": .string(type)]
        if let deviceId { body["deviceId"] = .string(deviceId) }
        _ = try await send(HTTPRequest(
            method: "POST", url: try endpointURL("session"), headers: sessionHeaders,
            body: try JSONValue.object(body).encoded()))
    }

    /// `POST /api/v1/app/{appId}/session/offline` with `{"deviceId",
    /// "sessions": [{"type", "timestamp"}]}`, the request of the Dart
    /// `flushOfflineSessions`. True only on a 200; any other status or a
    /// network error is false, never a throw.
    public func sendOfflineSessions(deviceId: String, sessions: [OfflineSessionRecord]) async -> Bool {
        do {
            let body = try JSONValue.object([
                "deviceId": .string(deviceId), "sessions": .array(sessions.map(\.json)),
            ]).encoded()
            let response = try await send(HTTPRequest(
                method: "POST", url: try endpointURL("session/offline"), headers: sessionHeaders, body: body))
            return response.status == 200
        } catch {
            return false
        }
    }

    private var sessionHeaders: [String: String] {
        var headers = self.headers
        headers["Content-Type"] = "application/json"
        return headers
    }
}
