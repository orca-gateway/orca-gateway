#if canImport(SwiftUI) && canImport(Network)
import Foundation
import Network
import XCTest

@testable import OrcaGateway

/// A local stand-in for Orca DevTools' WebSocket server, on 127.0.0.1: it
/// keeps every text message it receives, parsed.
final class DevToolsStub: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "devtools-stub")
    private let lock = NSLock()
    private var _messages: [JSONValue] = []
    private var connections: [NWConnection] = []

    init(port: UInt16 = 0) throws {
        let parameters = NWParameters.tcp
        let websocket = NWProtocolWebSocket.Options()
        websocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port) ?? .any)
        listener = try NWListener(using: parameters)
    }

    var port: UInt16 { listener.port?.rawValue ?? 0 }
    var url: URL { URL(string: "ws://127.0.0.1:\(port)")! }

    var messages: [JSONValue] {
        lock.lock()
        defer { lock.unlock() }
        return _messages
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
            let once = Once()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { done.resume() }
                case .failed(let error): once.run { done.resume(throwing: error) }
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.start(queue: queue)
        }
    }

    func stop() {
        queue.sync {
            connections.forEach { $0.cancel() }
            connections = []
        }
        listener.cancel()
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        receive(connection)
    }

    private func receive(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, let json = try? JSONValue.decode(data) {
                self.lock.lock()
                self._messages.append(json)
                self.lock.unlock()
            }
            if error == nil { self.receive(connection) }
        }
    }

    private final class Once: @unchecked Sendable {
        private var done = false
        private let lock = NSLock()
        func run(_ body: () -> Void) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            body()
        }
    }
}

/// Waits up to `timeout` seconds for `condition`.
func eventually(_ timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return condition()
}

/// T3.6: the WebSocket client against a local DevTools stub.
final class DevToolsClientTests: XCTestCase {
    let handshake = DevToolsEvent.deviceInfo(platform: "iOS", deviceModel: "test", appName: "Tests")

    func client(_ url: URL, backoff: @escaping (Int) -> TimeInterval? = { $0 < 10 ? 0.05 : nil })
        -> DevToolsClient
    {
        DevToolsClient(url: url, handshake: handshake, deviceId: "test-device", backoff: backoff)
    }

    func testDeviceInfoComesFirstThenEvents() async throws {
        let stub = try DevToolsStub()
        try await stub.start()
        defer { stub.stop() }
        let client = client(stub.url)
        defer { client.disconnect() }

        client.report(.error(message: "before connect"))  // dropped, as in Flutter
        client.connect()
        let connected = await eventually { client.isConnected && !stub.messages.isEmpty }
        XCTAssertTrue(connected)
        client.report(.error(message: "after connect"))
        let delivered = await eventually { stub.messages.count >= 2 }
        XCTAssertTrue(delivered)

        let first = try XCTUnwrap(stub.messages.first)
        XCTAssertEqual(first["type"], "device_info")
        XCTAssertEqual(first["deviceId"], "test-device")
        XCTAssertEqual(first["payload"], .object(handshake.payload))
        XCTAssertNotNil(first["timestamp"].intValue)
        XCTAssertEqual(stub.messages.map { $0["payload"]["message"].stringValue }, [nil, "after connect"])
    }

    func testReconnectsAfterDevToolsRestarts() async throws {
        let stub = try DevToolsStub()
        try await stub.start()
        let port = stub.port
        let client = client(stub.url)
        defer { client.disconnect() }
        client.connect()
        let first = await eventually { stub.messages.count == 1 }
        XCTAssertTrue(first)

        stub.stop()
        let dropped = await eventually { !client.isConnected }
        XCTAssertTrue(dropped)

        let again = try DevToolsStub(port: port)
        try await again.start()
        defer { again.stop() }
        let reconnected = await eventually { again.messages.first?["type"] == "device_info" }
        XCTAssertTrue(reconnected, "device_info again on the new connection")
    }

    func testARefusedClientGivesUpAfterTenTries() async throws {
        // A port with nothing behind it: start a stub, note its port, stop it.
        let stub = try DevToolsStub()
        try await stub.start()
        let url = stub.url
        stub.stop()

        let asked = Recorded()
        let client = client(url) { attempt in
            asked.add(attempt)
            return DevToolsClient.reconnectDelay(attempt: attempt).map { _ in 0.01 }
        }
        defer { client.disconnect() }
        client.connect()
        let gaveUp = await eventually(10) { asked.values.last == 10 }
        XCTAssertTrue(gaveUp)
        XCTAssertEqual(asked.values, Array(0...10))
        XCTAssertFalse(client.isConnected)
    }

    func testReconnectDelaysFollowFlutter() {
        XCTAssertEqual((0...10).map(DevToolsClient.reconnectDelay),
                       [1, 2, 4, 8, 16, 30, 30, 30, 30, 30, nil])
    }

    @MainActor func testDevToolsIsOptIn() async {
        let config = OrcaDebugConfig()
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.url, URL(string: "ws://localhost:6363"))
        XCTAssertNil(OrcaDebug.start(config))
        XCTAssertFalse(OrcaDebug.isEnabled)
        XCTAssertEqual(OrcaDebugConfig(enabled: true, host: "10.0.0.5", port: 7000).url,
                       URL(string: "ws://10.0.0.5:7000"))
    }

    final class Recorded: @unchecked Sendable {
        private let lock = NSLock()
        private var _values: [Int] = []
        var values: [Int] {
            lock.lock()
            defer { lock.unlock() }
            return _values
        }
        func add(_ value: Int) {
            lock.lock()
            _values.append(value)
            lock.unlock()
        }
    }
}

/// What a page reports to DevTools: rebuilds, its timing, a thrown action.
@MainActor
final class DevToolsHookTests: XCTestCase {
    final class Recorder: DevToolsReporter, @unchecked Sendable {
        private let lock = NSLock()
        private var _events: [DevToolsEvent] = []
        var events: [DevToolsEvent] {
            lock.lock()
            defer { lock.unlock() }
            return _events
        }
        func of(_ type: String) -> [DevToolsEvent] { events.filter { $0.type == type } }
        func report(_ event: DevToolsEvent) {
            lock.lock()
            _events.append(event)
            lock.unlock()
        }
    }

    let recorder = Recorder()

    override func tearDown() async throws {
        OrcaDebug.reporter = nil
        try await super.tearDown()
    }

    func testAWatchingNodeReportsItsRebuild() async throws {
        let model = OrcaPageModel(page: try recordedPage("counter-home"))
        let count = NodeObserver(model: model, id: "5")
        OrcaDebug.reporter = recorder
        await model.fire("onTap", on: try XCTUnwrap(model.resolve("11")))?.value
        XCTAssertEqual(count.revision, 1)
        XCTAssertEqual(recorder.of("widget_rebuild"), [
            .widgetRebuild(widgetId: "5", widgetType: "Text", watches: ["count"]),
        ])
        XCTAssertEqual(recorder.of("state_change"), [
            .stateChange(scope: .page, pageId: "home", key: "count", oldValue: 0, newValue: 1),
        ])
        XCTAssertEqual(recorder.of("action").first?.payload["pageId"], "home")
    }

    func testALoadedPageReportsItsTimingOnce() async throws {
        OrcaDebug.reporter = recorder
        let router = OrcaRouter(client: PageStub.client(PageStub()), path: "home",
                                system: SystemRecorder().actions())
        let loader = router.loader(for: router.root)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else { return XCTFail("not loaded") }
        XCTAssertEqual(recorder.of("timing"), [], "sent on the first frame")
        model.appeared()
        model.appeared()
        let timing = recorder.of("timing")
        XCTAssertEqual(timing.count, 1)
        XCTAssertEqual(timing.first?.payload["pageId"], "home")
        XCTAssertEqual(timing.first?.payload["path"], "home")
        let client = try XCTUnwrap(timing.first?.payload["client"])
        let marks = ["responseReceivedMs", "parseCompleteMs", "renderStartMs", "renderCompleteMs", "firstFrameMs"]
            .compactMap { client[$0].doubleValue }
        XCTAssertEqual(marks.count, 5)
        XCTAssertEqual(marks, marks.sorted(), "marks only move forward")
        XCTAssertEqual(recorder.of("network").count, 1)
    }

    func testAThrownActionIsReportedAsAnError() async {
        OrcaDebug.reporter = recorder
        let model = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"),
                                  client: PageStub.client(PageStub(actionBody: "not json")))
        await model.run(.serverAction(.init(id: "boom")))
        XCTAssertEqual(recorder.of("error").last?.payload["context"], "action serverAction on p")
    }
}
#endif
