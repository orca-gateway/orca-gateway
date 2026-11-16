import Foundation

/// Receives the SDK's DevTools events. The OrcaGateway target's
/// `DevToolsClient` sends them over a WebSocket; tests record them.
/// `report` is called from any thread.
public protocol DevToolsReporter: AnyObject, Sendable {
    func report(_ event: DevToolsEvent)
}

/// What the core captures while a reporter is set: the four fields of
/// Flutter's `OrcaDebugConfig` the core reads (sdk/lib/src/debug/orca_debug.dart),
/// with Flutter's defaults. `OrcaDebugOptions()` is the defaults.
public struct OrcaDebugOptions: Equatable, Sendable {
    /// Off: the store sends no `state_change`.
    public var captureStateChanges: Bool
    /// Off: the client sends no `network` event; a failed request's `error`
    /// event still goes, as Flutter's.
    public var captureNetworkRequests: Bool
    /// On: `network` events carry `requestBody` and `responseBody` (a page
    /// fetch shows the app state it sent, as Flutter). Off by default, since
    /// bodies can hold personal data.
    public var includeBodies: Bool
    /// On: the `timing` event also goes to the platform log. Read by the UI
    /// layer, which sends that event.
    public var logTimings: Bool

    public init(
        captureStateChanges: Bool = true, captureNetworkRequests: Bool = true,
        includeBodies: Bool = false, logTimings: Bool = false
    ) {
        self.captureStateChanges = captureStateChanges
        self.captureNetworkRequests = captureNetworkRequests
        self.includeBodies = includeBodies
        self.logTimings = logTimings
    }
}

/// Where DevTools events go, the Flutter `OrcaDebug.instance`: nowhere until
/// a reporter is set, and then the client, the store, the executor, the
/// registry and the views send their events to it. Building an event costs
/// nothing while no reporter is set.
public enum OrcaDebug {
    private static let lock = NSLock()
    private static var current: DevToolsReporter?
    private static var currentOptions = OrcaDebugOptions()

    public static var reporter: DevToolsReporter? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return current
        }
        set {
            lock.lock()
            current = newValue
            lock.unlock()
        }
    }

    /// The host's capture switches, read and written whole under the lock:
    /// starting DevTools sets them from its config
    /// (`OrcaDebug.options = OrcaDebugOptions(includeBodies: true)`), and
    /// stopping it sets `OrcaDebugOptions()` back.
    public static var options: OrcaDebugOptions {
        get {
            lock.lock()
            defer { lock.unlock() }
            return currentOptions
        }
        set {
            lock.lock()
            currentOptions = newValue
            lock.unlock()
        }
    }

    public static var isEnabled: Bool { reporter != nil }

    public static func report(_ event: @autoclosure () -> DevToolsEvent) {
        guard let reporter else { return }
        reporter.report(event())
    }

    /// Milliseconds on a monotonic clock, for durations.
    public static func now() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000
    }
}
