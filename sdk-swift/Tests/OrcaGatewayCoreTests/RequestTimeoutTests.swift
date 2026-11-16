import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@testable import OrcaGatewayCore

/// A transport that answers after `delay` seconds, recording what it was sent
/// and whether its wait was cancelled before it answered.
final class DelayedTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [HTTPRequest] = []
    private var _cancelled = false
    let delay: TimeInterval
    let response: HTTPResponse

    init(delay: TimeInterval,
         response: HTTPResponse = HTTPResponse(status: 200, body: Data(#"{"flows":{},"actions":[]}"#.utf8))) {
        self.delay = delay
        self.response = response
    }

    /// NSLock.withLock is missing from older Linux Foundation releases.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var requests: [HTTPRequest] { locked { _requests } }
    var cancelled: Bool { locked { _cancelled } }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        locked { _requests.append(request) }
        do {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch {
            locked { _cancelled = true }
            throw error
        }
        return response
    }
}

/// C18.5: the client takes Flutter's `timeout` option (30 s by default,
/// sdk/lib/src/client/orca_client.dart) and enforces it on every request: an
/// answer later than the timeout fails with URLError(.timedOut), which
/// OrcaErrorInfo maps to Connection Failed.
final class RequestTimeoutTests: XCTestCase {
    let base = URL(string: "http://localhost:8080")!

    override func tearDown() {
        OrcaDebug.reporter = nil
        super.tearDown()
    }

    private func timedClient(_ transport: HTTPTransport, timeout: TimeInterval) -> OrcaClient {
        OrcaClient(baseURL: base, appId: "counter", transport: transport, timeout: timeout)
    }

    /// Runs `body`, which must throw URLError(.timedOut) well before the
    /// stub's 2 s answer; returns the error.
    @discardableResult
    private func assertTimesOut(
        _ name: String, file: StaticString = #filePath, line: UInt = #line,
        _ body: () async throws -> Void
    ) async -> Error? {
        let start = Date()
        do {
            try await body()
            XCTFail("\(name) answered instead of timing out", file: file, line: line)
            return nil
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut, "\(name): \(error)", file: file, line: line)
            XCTAssertLessThan(Date().timeIntervalSince(start), 1.5, "\(name) waited for the answer",
                              file: file, line: line)
            return error
        }
    }

    func testC18_5_theDefaultTimeoutIsThirtySeconds() {
        XCTAssertEqual(OrcaClient(baseURL: base, appId: "counter").timeout, 30)
        XCTAssertEqual(OrcaClient(baseURL: base, appId: "counter", transport: DelayedTransport(delay: 0)).timeout, 30)
    }

    func testC18_5_anAnswerLaterThanTheTimeoutFailsAsConnectionFailed() async throws {
        let slow = DelayedTransport(delay: 2)
        let error = await assertTimesOut("fetchVersion") {
            _ = try await self.timedClient(slow, timeout: 0.1).fetchVersion()
        }
        let info = OrcaErrorInfo(try XCTUnwrap(error))
        XCTAssertEqual(info.kind, .connection)
        XCTAssertEqual(info.title, "Connection Failed")
        XCTAssertTrue(slow.cancelled, "the transport's request is cancelled on timeout")
    }

    func testC18_5_everyRequestOfTheClientIsTimed() async throws {
        let slow = DelayedTransport(delay: 2)
        let client = timedClient(slow, timeout: 0.1)
        await assertTimesOut("fetchPage") { _ = try await client.fetchPage("home") }
        await assertTimesOut("fetchConfig") { _ = try await client.fetchConfig() }
        await assertTimesOut("executeAction") { _ = try await client.executeAction("save") }
        await assertTimesOut("fetchVersion") { _ = try await client.fetchVersion() }
        await assertTimesOut("sendSession") { try await client.sendSession("start", deviceId: "d") }

        let start = Date()
        let sent = await client.sendEvents([["name": "tap"]])
        XCTAssertFalse(sent, "a timed-out analytics batch is not sent")
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5)
        let offline = await client.sendOfflineSessions(deviceId: "d", sessions: [])
        XCTAssertFalse(offline)
        XCTAssertEqual(slow.requests.count, 7)
    }

    func testC18_5_anAnswerWithinTheTimeoutSucceeds() async throws {
        let quick = DelayedTransport(delay: 0.05)
        let client = timedClient(quick, timeout: 2)
        let actions = try await client.executeAction("save")
        XCTAssertEqual(actions, [])
        let version = try await client.fetchVersion()
        XCTAssertEqual(version, VersionResponse(flows: [:]))
        XCTAssertFalse(quick.cancelled)
    }

    func testC18_5_copiesOfTheClientKeepTheTimeout() async throws {
        let slow = DelayedTransport(delay: 2)
        var copy = timedClient(slow, timeout: 0.1)
        copy.deviceId = "device-1"
        copy.apiKey = "key"
        XCTAssertEqual(copy.timeout, 0.1)
        await assertTimesOut("a copy's fetchVersion") { _ = try await copy.fetchVersion() }
    }

    func testC18_5_everyRequestCarriesTheTimeoutToTheTransport() async throws {
        let quick = DelayedTransport(delay: 0)
        let client = timedClient(quick, timeout: 12)
        _ = try await client.executeAction("save")
        _ = try await client.fetchVersion()
        XCTAssertEqual(quick.requests.map(\.timeout), [12, 12])
        XCTAssertNil(HTTPRequest(method: "GET", url: base).timeout, "a request built by hand has none")
    }

    func testC18_5_urlSessionTransportPutsTheTimeoutOnTheURLRequest() {
        let transport = URLSessionTransport()
        let timed = transport.urlRequest(HTTPRequest(method: "GET", url: base, timeout: 12))
        XCTAssertEqual(timed.timeoutInterval, 12)
        let plain = transport.urlRequest(HTTPRequest(method: "GET", url: base))
        XCTAssertEqual(plain.timeoutInterval, URLRequest(url: base).timeoutInterval,
                       "no timeout keeps URLSession's own")
    }

    func testC18_5_aTimedOutRequestIsReportedToDevTools() async throws {
        let recorder = EventRecorder()
        OrcaDebug.reporter = recorder
        let slow = DelayedTransport(delay: 2)
        await assertTimesOut("fetchVersion with DevTools on") {
            _ = try await self.timedClient(slow, timeout: 0.1).fetchVersion()
        }
        XCTAssertTrue(slow.cancelled)
        XCTAssertEqual(recorder.of("network").last?.payload["statusCode"], 0)
        XCTAssertEqual(recorder.of("error").last?.payload["context"],
                       "GET http://localhost:8080/api/v1/app/counter/version")
    }
}
