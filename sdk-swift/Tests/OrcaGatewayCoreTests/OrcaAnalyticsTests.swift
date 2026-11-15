import Foundation
import XCTest

@testable import OrcaGatewayCore

/// Opens once; `wait()` returns as soon as it is open.
private final class Latch: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        lock.lock()
        isOpen = true
        let resumed = waiters
        waiters = []
        lock.unlock()
        resumed.forEach { $0.resume() }
    }

    func wait() async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isOpen {
                lock.unlock()
                c.resume()
            } else {
                waiters.append(c)
                lock.unlock()
            }
        }
    }
}

/// An event sender that records each batch and answers with the next queued
/// result (true once they run out). With a gate it holds every send until
/// the gate opens; `entered` opens when the first send starts.
private final class RecordingSender: @unchecked Sendable {
    private let lock = NSLock()
    private var _batches: [[[String: JSONValue]]] = []
    private var results: [Bool]
    let gate: Latch?
    let entered = Latch()

    init(results: [Bool] = [], gate: Latch? = nil) {
        self.results = results
        self.gate = gate
    }

    var batches: [[[String: JSONValue]]] {
        lock.lock()
        defer { lock.unlock() }
        return _batches
    }

    var types: [[String]] {
        batches.map { $0.map { $0["type"]?.stringValue ?? "?" } }
    }

    func send(_ events: [[String: JSONValue]]) async -> Bool {
        let result = record(events)
        entered.open()
        if let gate { await gate.wait() }
        return result
    }

    /// Synchronous, as NSLock is unavailable from async contexts.
    private func record(_ events: [[String: JSONValue]]) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _batches.append(events)
        return results.isEmpty ? true : results.removeFirst()
    }
}

/// A scheduler fired by hand: it records each timer and runs the armed ones
/// when told to.
private final class ManualScheduler: @unchecked Sendable {
    private struct Timer {
        var delay: TimeInterval
        var action: @Sendable () -> Void
        var done = false
    }

    private let lock = NSLock()
    private var timers: [Timer] = []

    var scheduler: OrcaScheduler {
        { [self] delay, action in
            lock.lock()
            timers.append(Timer(delay: delay, action: action))
            let id = timers.count - 1
            lock.unlock()
            return { [self] in
                lock.lock()
                timers[id].done = true
                lock.unlock()
            }
        }
    }

    /// Every timer ever armed, fired or not.
    var delays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return timers.map(\.delay)
    }

    /// Timers armed and neither fired nor cancelled.
    var armed: Int {
        lock.lock()
        defer { lock.unlock() }
        return timers.filter { !$0.done }.count
    }

    /// Run every armed timer's action.
    func fire() {
        lock.lock()
        var actions: [@Sendable () -> Void] = []
        for i in timers.indices where !timers[i].done {
            timers[i].done = true
            actions.append(timers[i].action)
        }
        lock.unlock()
        actions.forEach { $0() }
    }
}

/// C15.4: track() batches by size and interval, re-queues a failed send, and
/// drops the oldest past the buffer limit; OrcaClient.sendEvents posts the
/// batch. Ports the five cases of sdk/test/orca_analytics_test.dart, then the
/// timer, in-flight, re-queue order, timestamp and sendEvents cases.
final class OrcaAnalyticsTests: XCTestCase {
    let base = URL(string: "http://localhost:8080")!

    private func analytics(
        _ sender: RecordingSender, _ timers: ManualScheduler = ManualScheduler(),
        batchSize: Int = 20, flushInterval: TimeInterval = 10, maxBuffer: Int = 500,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) -> OrcaAnalytics {
        OrcaAnalytics(
            sender: { await sender.send($0) }, batchSize: batchSize, flushInterval: flushInterval,
            maxBuffer: maxBuffer, clock: clock, scheduler: timers.scheduler)
    }

    // MARK: the five Dart cases

    func testC15_4_flushesOnceBatchSizeIsReached() async throws {
        let sender = RecordingSender()
        let a = analytics(sender, batchSize: 3)
        a.track("a")
        a.track("b")
        XCTAssertNil(a.backgroundFlush, "no flush before batchSize")
        a.track("c")
        let flush = try XCTUnwrap(a.backgroundFlush)
        let ok = await flush.value
        XCTAssertTrue(ok)
        XCTAssertEqual(sender.types, [["a", "b", "c"]])
        XCTAssertEqual(a.bufferedCount, 0)
    }

    func testC15_4_manualFlushSendsTypeTsAndPayload() async throws {
        let sender = RecordingSender()
        let a = analytics(sender)
        a.track("screen_view", payload: ["screen": "home"])
        a.track("plain")
        let ok = await a.flush()
        XCTAssertTrue(ok)
        XCTAssertEqual(sender.batches.count, 1)
        let events = try XCTUnwrap(sender.batches.first)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0]["type"], "screen_view")
        XCTAssertEqual(events[0]["payload"], ["screen": "home"])
        XCTAssertNotNil(events[0]["ts"]?.stringValue)
        XCTAssertEqual(events[1].keys.sorted(), ["ts", "type"], "no payload key without a payload")
    }

    func testC15_4_failedSendIsRequeuedAndALaterFlushSucceeds() async {
        let sender = RecordingSender(results: [false, true])
        let a = analytics(sender)
        a.track("x")
        let first = await a.flush()
        XCTAssertFalse(first)
        XCTAssertEqual(a.bufferedCount, 1, "a failed send must not lose the event")
        let second = await a.flush()
        XCTAssertTrue(second)
        XCTAssertEqual(a.bufferedCount, 0)
        XCTAssertEqual(sender.types, [["x"], ["x"]])
    }

    func testC15_4_maxBufferDropsTheOldest() async {
        let sender = RecordingSender()
        let a = analytics(sender, batchSize: 10000, maxBuffer: 5)
        for i in 0..<20 { a.track("e\(i)") }
        XCTAssertEqual(a.bufferedCount, 5)
        _ = await a.flush()
        XCTAssertEqual(sender.types, [["e15", "e16", "e17", "e18", "e19"]])
    }

    func testC15_4_disposeFlushesTheRest() async {
        let sender = RecordingSender()
        let timers = ManualScheduler()
        let a = analytics(sender, timers)
        a.track("one")
        a.track("two")
        await a.dispose()
        XCTAssertEqual(sender.types, [["one", "two"]])
        XCTAssertEqual(a.bufferedCount, 0)
        XCTAssertEqual(timers.armed, 0, "dispose leaves no timer armed")
    }

    // MARK: timer, in-flight flush, re-queue order

    func testC15_4_intervalFlushFiresThroughTheScheduler() async throws {
        let sender = RecordingSender()
        let timers = ManualScheduler()
        let a = analytics(sender, timers, flushInterval: 7)
        a.track("a")
        a.track("b")
        XCTAssertEqual(timers.delays, [7], "a second track while a timer is armed arms no other")
        XCTAssertTrue(sender.batches.isEmpty)
        timers.fire()
        let flush = try XCTUnwrap(a.backgroundFlush)
        _ = await flush.value
        XCTAssertEqual(sender.types, [["a", "b"]])
        a.track("c")
        XCTAssertEqual(timers.delays, [7, 7], "the next track after a flush arms a new timer")
    }

    func testC15_4_inFlightFlushMakesASecondFlushANoOp() async {
        let gate = Latch()
        let sender = RecordingSender(gate: gate)
        let a = analytics(sender)
        a.track("a")
        let first = Task { await a.flush() }
        await sender.entered.wait()
        a.track("b")
        let second = await a.flush()
        XCTAssertTrue(second)
        XCTAssertEqual(sender.batches.count, 1, "the second flush sends nothing")
        gate.open()
        let firstResult = await first.value
        XCTAssertTrue(firstResult)
        XCTAssertEqual(a.bufferedCount, 1)
    }

    func testC15_4_requeueKeepsOrderInFrontOfEventsTrackedMeanwhile() async {
        let gate = Latch()
        let sender = RecordingSender(results: [false, true], gate: gate)
        let a = analytics(sender, maxBuffer: 3)
        a.track("a")
        a.track("b")
        let first = Task { await a.flush() }
        await sender.entered.wait()
        a.track("c")
        a.track("d")
        gate.open()
        let firstResult = await first.value
        XCTAssertFalse(firstResult)
        XCTAssertEqual(a.bufferedCount, 3, "re-queued in front, then trimmed to maxBuffer")
        _ = await a.flush()
        XCTAssertEqual(sender.types.last, ["b", "c", "d"])
    }

    // MARK: timestamp

    func testC15_4_tsIsUTCISO8601WithMillisecondsFromTheClock() async {
        let sender = RecordingSender()
        let times: [TimeInterval] = [1_794_736_800.123, 1_794_736_859.999, 0]
        let index = Counter()
        let a = analytics(sender, clock: { Date(timeIntervalSince1970: times[index.next()]) })
        a.track("a")
        a.track("b")
        a.track("c")
        _ = await a.flush()
        XCTAssertEqual(
            sender.batches.first?.map { $0["ts"]?.stringValue ?? "" },
            ["2026-11-15T10:00:00.123Z", "2026-11-15T10:00:59.999Z", "1970-01-01T00:00:00.000Z"])
    }

    // MARK: sendEvents

    func testC15_4_sendEventsPostsTheBatchWithTheClientHeaders() async throws {
        let stub = StubEngine(page: Data())
        stub.forced = HTTPResponse(status: 202)
        let client = OrcaClient(
            baseURL: base, appId: "counter", apiKey: "k", environment: "staging", deviceId: "dev-1",
            transport: stub)
        let events: [[String: JSONValue]] = [
            ["type": "screen_view", "ts": "2026-11-15T10:00:00.123Z", "payload": ["screen": "home"]],
            ["type": "tap", "ts": "2026-11-15T10:00:01.000Z"],
        ]
        let ok = await client.sendEvents(events)
        XCTAssertTrue(ok)
        let requests = stub.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "http://localhost:8080/api/v1/app/counter/events")
        var expected = client.headers
        expected["Content-Type"] = "application/json"
        XCTAssertEqual(request.headers, expected)
        let body = try JSONValue.decode(request.body ?? Data())
        XCTAssertEqual(body, ["events": .array(events.map { .object($0) })])
    }

    func testC15_4_sendEventsIsTrueOnlyOn2xx() async {
        let stub = StubEngine(page: Data())
        let client = OrcaClient(baseURL: base, appId: "counter", transport: stub)
        for (status, expected) in [(200, true), (204, true), (299, true), (300, false), (404, false), (500, false)] {
            stub.forced = HTTPResponse(status: status)
            let ok = await client.sendEvents([["type": "a"]])
            XCTAssertEqual(ok, expected, "status \(status)")
        }
    }

    func testC15_4_sendEventsIsFalseOnATransportThrow() async {
        let client = OrcaClient(baseURL: base, appId: "counter", transport: DownTransport())
        let ok = await client.sendEvents([["type": "a"]])
        XCTAssertFalse(ok)
    }

    func testC15_4_sendEventsWithNoEventsMakesNoRequest() async {
        let stub = StubEngine(page: Data())
        let client = OrcaClient(baseURL: base, appId: "counter", transport: stub)
        let ok = await client.sendEvents([])
        XCTAssertTrue(ok)
        XCTAssertTrue(stub.requests.isEmpty)
    }

    func testC15_4_forClientSendsThroughSendEvents() async throws {
        let stub = StubEngine(page: Data())
        stub.forced = HTTPResponse(status: 200)
        let client = OrcaClient(baseURL: base, appId: "counter", transport: stub)
        let a = OrcaAnalytics.forClient(client, batchSize: 50, flushInterval: 3600, maxBuffer: 10)
        a.track("a")
        let ok = await a.flush()
        XCTAssertTrue(ok)
        XCTAssertEqual(a.bufferedCount, 0)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.url.path, "/api/v1/app/counter/events")
        let body = try JSONValue.decode(request.body ?? Data())
        XCTAssertEqual(body["events"].arrayValue?.map { $0["type"] }, ["a"])
    }

    // MARK: the default scheduler

    func testC15_4_defaultSchedulerRunsTheActionUnlessCancelled() async {
        let ran = Latch()
        let cancelledRan = Counter()
        let cancel = OrcaAnalytics.defaultScheduler(0.001) { _ = cancelledRan.next() }
        cancel()
        _ = OrcaAnalytics.defaultScheduler(0.005) { ran.open() }
        await ran.wait()
        XCTAssertEqual(cancelledRan.value, 0, "a cancelled timer never runs")
    }
}

/// A thread-safe counter: `next()` returns the current value, then adds one.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return n
    }

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        n += 1
        return n - 1
    }
}
