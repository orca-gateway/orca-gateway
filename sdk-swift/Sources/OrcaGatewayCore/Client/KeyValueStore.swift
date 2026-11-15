import Foundation

/// A small persistent string store, the part of Flutter's SharedPreferences
/// the SDK uses (sdk/lib/src/widgets/orca_app.dart and
/// sdk/lib/src/client/offline_session_store.dart read and write strings
/// through it). The core holds only this contract so it stays testable on
/// Linux; the SwiftUI layer adapts UserDefaults.
public protocol KeyValueStore: AnyObject, Sendable {
    /// The saved string for `key`, or nil when none is saved.
    func string(forKey key: String) -> String?
    /// Saves `value` under `key`; nil removes the key.
    func set(_ value: String?, forKey key: String)
}

/// A KeyValueStore held in memory, for tests and for hosts that do not want
/// anything kept on disk. Thread-safe.
public final class MemoryKeyValueStore: KeyValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [String: String]

    /// A store that starts with `values`, e.g. another store's `values` to
    /// stand for an app restart over the same saved contents.
    public init(_ values: [String: String] = [:]) {
        _values = values
    }

    /// A snapshot of every saved key and value.
    public var values: [String: String] { locked { _values } }

    /// The saved string for `key`, or nil.
    public func string(forKey key: String) -> String? {
        locked { _values[key] }
    }

    /// Saves `value` under `key`; nil removes the key.
    public func set(_ value: String?, forKey key: String) {
        locked { _values[key] = value }
    }

    /// NSLock.withLock is missing from older Linux Foundation releases.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
