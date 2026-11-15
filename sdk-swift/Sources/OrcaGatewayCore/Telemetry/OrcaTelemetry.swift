import Foundation

/// Where the SDK's telemetry events go, the Flutter `OrcaTelemetry`
/// (sdk/lib/src/telemetry/orca_telemetry.dart): nowhere until the host sets
/// `onEvent`. Each unknown widget type is reported once per process,
/// whatever registry drew it. Safe from any thread.
public enum OrcaTelemetry {
    /// The sink and the seen types, behind one lock.
    private static let lock = NSLock()
    private static var sink: ((String, [String: JSONValue]) -> Void)?
    private static var seen: Set<String> = []

    /// The host's event sink, the Flutter `onEvent`. Nil drops events; the
    /// dedup still runs. Known events: `unknown_widget_type` with
    /// `["type": "<componentType>"]`.
    public static var onEvent: ((String, [String: JSONValue]) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return sink
        }
        set {
            lock.lock()
            sink = newValue
            lock.unlock()
        }
    }

    /// Report an unknown widget type the first time this process sees it, the
    /// Flutter `reportUnknownWidgetOnce`; later calls for that type do nothing.
    public static func reportUnknownWidgetOnce(_ type: String) {
        lock.lock()
        let first = seen.insert(type).inserted
        let current = sink
        lock.unlock()
        if first { current?("unknown_widget_type", ["type": .string(type)]) }
    }

    /// Forget the types seen so far, the Flutter `resetForTesting`. For tests
    /// only: in an app it would report every unknown type again.
    public static func resetForTesting() {
        lock.lock()
        seen = []
        lock.unlock()
    }
}
