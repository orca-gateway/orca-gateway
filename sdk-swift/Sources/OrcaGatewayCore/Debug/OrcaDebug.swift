import Foundation

/// Receives the SDK's DevTools events. The OrcaGateway target's
/// `DevToolsClient` sends them over a WebSocket; tests record them.
/// `report` is called from any thread.
public protocol DevToolsReporter: AnyObject, Sendable {
    func report(_ event: DevToolsEvent)
}

/// Where DevTools events go, the Flutter `OrcaDebug.instance`: nowhere until
/// a reporter is set, and then the client, the store, the executor, the
/// registry and the views send their events to it. Building an event costs
/// nothing while no reporter is set.
public enum OrcaDebug {
    private static let lock = NSLock()
    private static var current: DevToolsReporter?

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
