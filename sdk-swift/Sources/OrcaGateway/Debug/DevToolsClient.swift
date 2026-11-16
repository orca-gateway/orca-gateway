#if canImport(SwiftUI)
import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

/// Whether and where the SDK sends DevTools events, and what it captures
/// (Flutter `OrcaDebugConfig`, sdk/lib/src/debug/orca_debug.dart, with its
/// defaults). Off unless `enabled`; the simulator and the Mac reach DevTools
/// at localhost, a device needs the Mac's address in `host`.
public struct OrcaDebugConfig: Equatable, Sendable {
    public var enabled: Bool
    public var host: String
    public var port: Int
    /// Shown in DevTools' device list.
    public var appName: String?
    /// Draw the load-time chip at the bottom right of each page.
    public var showOverlay: Bool
    /// Also write each page's `timing` event to the system log.
    public var logTimings: Bool
    /// Off: no `state_change` events.
    public var captureStateChanges: Bool
    /// Off: no `network` events.
    public var captureNetworkRequests: Bool
    /// On: `network` events carry the request and response bodies. Off by
    /// default, since bodies can hold tokens and personal data.
    public var includeBodies: Bool

    public init(enabled: Bool = false, host: String = "localhost", port: Int = 6363, appName: String? = nil,
                showOverlay: Bool = false, logTimings: Bool = false, captureStateChanges: Bool = true,
                captureNetworkRequests: Bool = true, includeBodies: Bool = false) {
        self.enabled = enabled
        self.host = host
        self.port = port
        self.appName = appName
        self.showOverlay = showOverlay
        self.logTimings = logTimings
        self.captureStateChanges = captureStateChanges
        self.captureNetworkRequests = captureNetworkRequests
        self.includeBodies = includeBodies
    }

    public var url: URL? { URL(string: "ws://\(host):\(port)") }

    /// The four switches the core reads.
    var options: OrcaDebugOptions {
        OrcaDebugOptions(captureStateChanges: captureStateChanges, captureNetworkRequests: captureNetworkRequests,
                         includeBodies: includeBodies, logTimings: logTimings)
    }
}

extension OrcaDebug {
    /// Connect to DevTools when `config.enabled` (Flutter `OrcaDebug.init`):
    /// any earlier client is disconnected first, and a disabled config just
    /// stops. The config's capture switches become `options` and its
    /// `showOverlay` the pages' overlay switch. Returns the client that now
    /// receives the SDK's events.
    @discardableResult
    public static func start(_ config: OrcaDebugConfig) -> DevToolsClient? {
        stop()
        guard config.enabled, let url = config.url else { return nil }
        options = config.options
        showOverlay = config.showOverlay
        let client = DevToolsClient(url: url, handshake: .deviceInfo(
            platform: DevToolsClient.platform, deviceModel: DevToolsClient.deviceModel,
            appVersion: DevToolsClient.appVersion, appName: config.appName))
        reporter = client
        client.connect()
        return client
    }

    /// Disconnect and stop sending events; the options go back to their
    /// defaults and the overlay off.
    public static func stop() {
        (reporter as? DevToolsClient)?.disconnect()
        reporter = nil
        options = OrcaDebugOptions()
        showOverlay = false
    }

    /// Flutter's `logTimings` line (`debugPrint`, orca_debug.dart:60-62),
    /// to the system log as the SDK's other lines: subsystem
    /// com.orcagateway, category OrcaDebug.
    static func logTiming(pageId: String, path: String) {
        Logger(subsystem: "com.orcagateway", category: "OrcaDebug")
            .log("[OrcaDebug] Timing: \(pageId, privacy: .public) - \(path, privacy: .public)")
    }
}

/// The WebSocket to Orca DevTools, the Swift side of Flutter's
/// sdk/lib/src/debug/dev_tools_client.dart:
/// - `device_info` goes first on every connect;
/// - events are dropped while not connected, as in Flutter;
/// - a lost or refused connection is retried after 1, 2, 4, 8, 16, then
///   30 s, at most 10 times in a row; a connect resets the count.
public final class DevToolsClient: NSObject, DevToolsReporter, URLSessionWebSocketDelegate,
    @unchecked Sendable
{
    public static let maxReconnectAttempts = 10

    /// The wait before reconnect number `attempt` (from 0), or nil when the
    /// client gives up.
    public static func reconnectDelay(attempt: Int) -> TimeInterval? {
        guard attempt < maxReconnectAttempts else { return nil }
        return min(pow(2, Double(attempt)), 30)
    }

    public let url: URL
    public let deviceId: String
    private let handshake: DevToolsEvent
    private let backoff: (Int) -> TimeInterval?
    // Everything below is touched on `queue` only.
    private let queue = DispatchQueue(label: "dev.orcagateway.devtools")
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var connected = false
    private var attempts = 0
    private var running = false
    private var retry: DispatchWorkItem?

    /// `backoff` replaces `reconnectDelay` (tests use short waits).
    public init(url: URL, handshake: DevToolsEvent, deviceId: String = UUID().uuidString,
                backoff: @escaping (Int) -> TimeInterval? = DevToolsClient.reconnectDelay)
    {
        self.url = url
        self.handshake = handshake
        self.deviceId = deviceId
        self.backoff = backoff
        super.init()
    }

    /// Open the socket, and keep it open until `disconnect`.
    public func connect() {
        queue.async {
            guard !self.running else { return }
            if self.session == nil {
                // The session keeps its delegate (this client) until
                // `disconnect` invalidates it.
                let delegateQueue = OperationQueue()
                delegateQueue.underlyingQueue = self.queue
                delegateQueue.maxConcurrentOperationCount = 1
                self.session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: delegateQueue)
            }
            self.running = true
            self.attempts = 0
            self.open()
        }
    }

    public func disconnect() {
        queue.async {
            self.running = false
            self.retry?.cancel()
            self.retry = nil
            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
            self.connected = false
            self.session?.invalidateAndCancel()
            self.session = nil
        }
    }

    public func report(_ event: DevToolsEvent) {
        queue.async {
            guard self.connected else { return }
            self.send(event)
        }
    }

    /// Whether the socket is open now (tests).
    public var isConnected: Bool { queue.sync { connected } }

    // MARK: Connection

    private func open() {
        guard running, let session else { return }
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    private func send(_ event: DevToolsEvent) {
        guard let task else { return }
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        guard let data = try? event.envelope(deviceId: deviceId, timestamp: timestamp).encoded() else { return }
        task.send(.string(String(decoding: data, as: UTF8.self))) { [weak self] error in
            guard error != nil, let self else { return }
            self.queue.async { self.lost(task) }
        }
    }

    /// Drain what DevTools sends; a failed receive means the socket is gone.
    private func receive(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            self.queue.async {
                switch result {
                case .success: self.receive(task)
                case .failure: self.lost(task)
                }
            }
        }
    }

    private func lost(_ lostTask: URLSessionTask) {
        guard lostTask === task else { return }
        task = nil
        connected = false
        guard running, let delay = backoff(attempts) else { return }
        attempts += 1
        let item = DispatchWorkItem { [weak self] in self?.open() }
        retry = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didOpenWithProtocol protocol: String?) {
        guard webSocketTask === task else { return }
        connected = true
        attempts = 0
        send(handshake)
        receive(webSocketTask)
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        lost(webSocketTask)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lost(task)
    }

    // MARK: This device

    static var platform: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "Apple"
        #endif
    }

    /// The model identifier (`iPhone17,1`); a simulator reports the model it
    /// simulates.
    static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return machine.isEmpty ? "unknown" : machine
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
#endif
