import Foundation

/// A KeyValueStore kept on disk, one file per key under `directory`, so what
/// it holds survives a restart (the offline cache's config, flow versions and
/// pages; Flutter keeps them in SharedPreferences). The SwiftUI layer's
/// `FileKeyValueStore.applicationSupport()` uses Application Support/<bundle
/// id>/OrcaGateway. Foundation only, so it runs on Linux too.
///
/// A key becomes its file name with every byte outside `[a-z0-9_-]` written
/// as `%XX` (capitals too, so two keys stay apart on a case-insensitive disk),
/// and the empty key is `%`. The directory is created by the first write; each
/// write goes to a temporary file that then replaces the old one. A write that
/// fails is dropped, as UserDefaults drops one. Thread-safe.
public final class FileKeyValueStore: KeyValueStore, @unchecked Sendable {
    /// The directory the files live in.
    public let directory: URL
    private let lock = NSLock()

    /// A store over `directory`, which need not exist yet.
    public init(directory: URL) {
        self.directory = directory
    }

    /// The text saved for `key`, or nil when none is saved.
    public func string(forKey key: String) -> String? {
        locked {
            guard let data = try? Data(contentsOf: file(key)) else { return nil }
            return String(decoding: data, as: UTF8.self)
        }
    }

    /// Saves `value` under `key`; nil removes the key's file.
    public func set(_ value: String?, forKey key: String) {
        locked {
            let url = file(key)
            guard let value else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? Data(value.utf8).write(to: url, options: .atomic)
        }
    }

    private func file(_ key: String) -> URL {
        directory.appendingPathComponent(Self.fileName(key), isDirectory: false)
    }

    /// The file name of `key`: `[a-z0-9_-]` kept, every other UTF-8 byte
    /// `%XX`, the empty key `%`.
    static func fileName(_ key: String) -> String {
        if key.isEmpty { return "%" }
        var name = ""
        for byte in key.utf8 {
            switch byte {
            case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "_"), UInt8(ascii: "-"):
                name.append(Character(Unicode.Scalar(byte)))
            default:
                name += (byte < 0x10 ? "%0" : "%") + String(byte, radix: 16, uppercase: true)
            }
        }
        return name
    }

    /// NSLock.withLock is missing from older Linux Foundation releases.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
