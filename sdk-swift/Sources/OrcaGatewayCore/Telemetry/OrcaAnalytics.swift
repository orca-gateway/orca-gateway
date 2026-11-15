import Foundation

/// Sends one batch of events and says whether it arrived, the Dart
/// `EventSender` (sdk/lib/src/telemetry/orca_analytics.dart).
/// `OrcaClient.sendEvents` is one.
public typealias OrcaEventSender = @Sendable ([[String: JSONValue]]) async -> Bool

/// Runs the action once the delay (in seconds) has passed, unless the
/// returned closure cancels it first; the timer behind the Dart `Timer` of
/// orca_analytics.dart. The action must run later, never before the
/// scheduler returns.
public typealias OrcaScheduler =
    @Sendable (TimeInterval, @escaping @Sendable () -> Void) -> (@Sendable () -> Void)

/// A buffered, batched analytics emitter, a port of `OrcaAnalytics` in
/// sdk/lib/src/telemetry/orca_analytics.dart (Epic 47.4).
///
/// `track` adds an event to a buffer in memory. The buffer is sent when it
/// holds `batchSize` events or `flushInterval` after the first pending event,
/// whichever comes first. A failed send puts the batch back in front, and
/// past `maxBuffer` the oldest events are dropped. Not wired into OrcaApp, as
/// in Flutter: build one with `forClient`, call `track`, and `dispose` on
/// teardown. Safe from any thread.
public final class OrcaAnalytics: @unchecked Sendable {
    /// Send once this many events are buffered.
    public let batchSize: Int
    /// Send at least this often, in seconds, while events are pending.
    public let flushInterval: TimeInterval
    /// The most events kept; the oldest are dropped beyond it.
    public let maxBuffer: Int

    private let sender: OrcaEventSender
    private let clock: @Sendable () -> Date
    private let scheduler: OrcaScheduler

    private let lock = NSLock()
    private var buffer: [[String: JSONValue]] = []
    private var cancelTimer: (@Sendable () -> Void)?
    private var flushing = false
    private var lastFlush: Task<Bool, Never>?

    /// The Dart constructor, plus a scheduler for the flush timer.
    public init(
        sender: @escaping OrcaEventSender, batchSize: Int = 20, flushInterval: TimeInterval = 10,
        maxBuffer: Int = 500, clock: @escaping @Sendable () -> Date = { Date() },
        scheduler: @escaping OrcaScheduler = OrcaAnalytics.defaultScheduler
    ) {
        self.sender = sender
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.maxBuffer = maxBuffer
        self.clock = clock
        self.scheduler = scheduler
    }

    /// An emitter that sends through the client's `sendEvents`, the Dart
    /// `OrcaAnalytics.forClient` (the client knows its app id).
    public static func forClient(
        _ client: OrcaClient, batchSize: Int = 20, flushInterval: TimeInterval = 10,
        maxBuffer: Int = 500
    ) -> OrcaAnalytics {
        OrcaAnalytics(
            sender: { await client.sendEvents($0) }, batchSize: batchSize,
            flushInterval: flushInterval, maxBuffer: maxBuffer)
    }

    /// The default timer: a Task that sleeps the delay, then runs the action
    /// unless it was cancelled.
    public static let defaultScheduler: OrcaScheduler = { delay, action in
        let task = Task {
            try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            if !Task.isCancelled { action() }
        }
        return { task.cancel() }
    }

    /// Queue an event, the Dart `track`: `type` is its name (e.g.
    /// "screen_view"), `payload` any JSON context, and the clock's time goes
    /// in `ts`. Arms the flush timer when none is armed, and starts a flush
    /// once `batchSize` events are buffered.
    public func track(_ type: String, payload: [String: JSONValue]? = nil) {
        var event: [String: JSONValue] = ["type": .string(type), "ts": .string(Self.timestamp(clock()))]
        if let payload { event["payload"] = .object(payload) }
        lock.lock()
        buffer.append(event)
        trim()
        if cancelTimer == nil {
            cancelTimer = scheduler(flushInterval) { [weak self] in self?.startFlush() }
        }
        let full = buffer.count >= batchSize
        lock.unlock()
        if full { startFlush() }
    }

    /// Send the buffered events now, the Dart `flush`. A flush already in
    /// flight makes this one a no-op. True when nothing needed sending or the
    /// send succeeded; on a failed send the batch goes back in front.
    public func flush() async -> Bool {
        guard let batch = takeBatch() else { return true }
        let ok = await sender(batch)
        finish(batch, ok: ok)
        return ok
    }

    /// Flush and stop the timer, the Dart `dispose`.
    public func dispose() async {
        _ = await flush()
        locked {
            cancelTimer?()
            cancelTimer = nil
        }
    }

    /// How many events wait to be sent (for tests, as in Dart).
    public var bufferedCount: Int { locked { buffer.count } }

    /// The flush last started by `track` or the timer, for tests to await.
    var backgroundFlush: Task<Bool, Never>? { locked { lastFlush } }

    /// `date` in UTC as ISO 8601 with milliseconds and "Z", as Dart's
    /// `toUtc().toIso8601String()` writes it: "2026-11-15T10:00:00.123Z".
    /// Built from whole milliseconds and calendar fields, so the text does
    /// not depend on how a platform's date formatter rounds fractions.
    static func timestamp(_ date: Date) -> String {
        let ms = Int((date.timeIntervalSince1970 * 1000).rounded())
        let seconds = Int((Double(ms) / 1000).rounded(.down))
        let p = DateParts(epochMillis: Double(seconds) * 1000)
        func pad(_ n: Int, _ width: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, width - s.count)) + s
        }
        return "\(pad(p.year, 4))-\(pad(p.month, 2))-\(pad(p.day, 2))T"
            + "\(pad(p.hour, 2)):\(pad(p.minute, 2)):\(pad(p.second, 2)).\(pad(ms - seconds * 1000, 3))Z"
    }

    /// Start a flush and forget it (a size- or timer-triggered flush).
    private func startFlush() {
        let task = Task { await self.flush() }
        locked { lastFlush = task }
    }

    /// Cancel the timer and take the whole buffer, or nil when a flush is in
    /// flight or there is nothing to send.
    private func takeBatch() -> [[String: JSONValue]]? {
        locked {
            cancelTimer?()
            cancelTimer = nil
            if flushing || buffer.isEmpty { return nil }
            flushing = true
            let batch = buffer
            buffer = []
            return batch
        }
    }

    /// End a flush: a failed batch goes back in front, order kept, then the
    /// buffer is trimmed.
    private func finish(_ batch: [[String: JSONValue]], ok: Bool) {
        locked {
            if !ok {
                buffer.insert(contentsOf: batch, at: 0)
                trim()
            }
            flushing = false
        }
    }

    /// Drop the oldest events past `maxBuffer`. Call with the lock held.
    private func trim() {
        if buffer.count > maxBuffer { buffer.removeFirst(buffer.count - maxBuffer) }
    }

    /// NSLock.withLock is missing from older Linux Foundation releases, and
    /// NSLock is unavailable from async contexts.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

extension OrcaClient {
    /// `POST /api/v1/app/{appId}/events` with `{"events": [...]}`, the Dart
    /// `sendEvents` (sdk/lib/src/client/orca_client.dart). True on a 2xx;
    /// false on any other status or a network error, never a throw, so the
    /// analytics decides whether to re-queue. No events, no request.
    public func sendEvents(_ events: [[String: JSONValue]]) async -> Bool {
        if events.isEmpty { return true }
        var headers = self.headers
        headers["Content-Type"] = "application/json"
        do {
            let body = try JSONValue.object(["events": .array(events.map { .object($0) })]).encoded()
            let response = try await send(HTTPRequest(
                method: "POST", url: try endpointURL("events"), headers: headers, body: body))
            return (200..<300).contains(response.status)
        } catch {
            return false
        }
    }
}
