import Foundation

/// The values persistState saves and the scopes get back when they are set
/// up again, by the saved-state contract the three SDKs share (Flutter keeps
/// it in sdk/lib/src/state/state_manager.dart).
///
/// One entry per scope, a JSON object `{key: value}`: app state under
/// `orca_saved_app`, a page's state under `orca_saved_page_<pageId>`. `local`
/// entries live in the KeyValueStore (the entry name is the store's key) and
/// survive a restart; `session` entries live in one map for the whole process
/// and go when it ends. A key has at most one saved copy, in one storage.
///
/// Local entries are read from the store when first needed and then kept in
/// memory, so a restore is synchronous; every change is written through. A
/// store that fails is ignored: an unreadable entry restores nothing, a write
/// that fails is dropped. Without a store, local entries live in this
/// object's memory only. Thread-safe.
public final class SavedState: @unchecked Sendable {
    /// Where persistState keeps a value.
    public enum Storage: String, Sendable, CaseIterable {
        /// The KeyValueStore: survives a restart.
        case local
        /// Memory shared by the whole process: gone when it ends.
        case session
    }

    static let appEntry = "orca_saved_app"
    static let pagePrefix = "orca_saved_page_"

    private let local: KeyValueStore?
    private let lock = NSLock()
    /// Local entries read or written so far; an empty one is not saved.
    private var mirror: [String: [String: JSONValue]] = [:]

    /// Saved state over `local` (Swift's FileKeyValueStore on a device), or
    /// with nil, over nothing that outlives this object.
    public init(local: KeyValueStore?) {
        self.local = local
    }

    // MARK: Actions

    /// persistState: when `key` is in the live scope (`store`'s page state
    /// for `.page`, which is page `pageId`), save its current value, null
    /// included, in `storage` and drop any copy in the other storage. A key
    /// absent from the live scope changes nothing; so does a page scope with
    /// no pageId.
    public func persist(
        _ key: String, scope: StateScope, pageId: String?, storage: Storage, from store: ElmStore
    ) {
        guard let name = Self.entryName(scope, pageId), let value = store.state[scope][key] else { return }
        update(name, in: storage) { $0[key] = value }
        update(name, in: storage == .local ? .session : .local) { $0[key] = nil }
    }

    /// clearState's saved part: remove `key` from both storages' entries of
    /// the scope. The live key is the executor's to null.
    public func clear(_ key: String, scope: StateScope, pageId: String?) {
        guard let name = Self.entryName(scope, pageId) else { return }
        for storage in Storage.allCases { update(name, in: storage) { $0[key] = nil } }
    }

    // MARK: Restore

    /// Set every saved app key over `store`'s app state, adding the ones it
    /// lacks. Run right after the app state is set up at boot.
    public func restore(into store: ElmStore) {
        restore(Self.appEntry, scope: .app, into: store)
    }

    /// Set every saved key of page `pageId` over `store`'s page state, adding
    /// the ones it lacks. Run when the page's state is set up, before it is
    /// shown.
    public func restorePage(into store: ElmStore, pageId: String) {
        restore(Self.pagePrefix + pageId, scope: .page, into: store)
    }

    private func restore(_ name: String, scope: StateScope, into store: ElmStore) {
        var saved = locked { localEntry(name) }
        saved.merge(Self.session.entry(name)) { _, session in session }
        guard !saved.isEmpty else { return }
        store.commit(store.state.merging(saved, into: scope))
    }

    // MARK: Session

    /// Every session entry by its name: for reading what the session holds,
    /// as tests do.
    public static var sessionEntries: [String: [String: JSONValue]] { session.all }

    /// Replace the session entries (none by default): for clearing session
    /// state, for example when a user signs out, and for setting it up in
    /// tests.
    public static func resetSession(_ entries: [String: [String: JSONValue]] = [:]) {
        session.reset(entries)
    }

    private static let session = SessionEntries()

    /// The process-wide session map, behind its own lock.
    private final class SessionEntries: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [String: [String: JSONValue]] = [:]

        var all: [String: [String: JSONValue]] { locked { entries } }

        func entry(_ name: String) -> [String: JSONValue] { locked { entries[name] ?? [:] } }

        func reset(_ next: [String: [String: JSONValue]]) { locked { entries = next.filter { !$0.value.isEmpty } } }

        func update(_ name: String, _ change: (inout [String: JSONValue]) -> Void) {
            locked {
                var entry = entries[name] ?? [:]
                change(&entry)
                entries[name] = entry.isEmpty ? nil : entry
            }
        }

        /// NSLock.withLock is missing from older Linux Foundation releases.
        private func locked<T>(_ body: () -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body()
        }
    }

    // MARK: Entries

    /// `orca_saved_app`, or `orca_saved_page_<pageId>`; nil for a page with
    /// no pageId.
    static func entryName(_ scope: StateScope, _ pageId: String?) -> String? {
        switch scope {
        case .app: return appEntry
        case .page: return pageId.map { pagePrefix + $0 }
        }
    }

    /// Change one entry of `storage`; an entry left empty is deleted.
    private func update(_ name: String, in storage: Storage, _ change: (inout [String: JSONValue]) -> Void) {
        guard storage == .local else {
            Self.session.update(name, change)
            return
        }
        locked {
            var entry = localEntry(name)
            let before = entry
            change(&entry)
            guard entry != before else { return }
            mirror[name] = entry
            if entry.isEmpty {
                local?.set(nil, forKey: name)
            } else if let data = try? JSONValue.object(entry).encoded() {
                local?.set(String(decoding: data, as: UTF8.self), forKey: name)
            }
        }
    }

    /// The local entry `name`, read from the store the first time; empty
    /// when none is saved or the saved text is not a JSON object. Call
    /// under the lock.
    private func localEntry(_ name: String) -> [String: JSONValue] {
        if let entry = mirror[name] { return entry }
        let text = local?.string(forKey: name)
        let entry = text.flatMap { try? JSONValue.decode(Data($0.utf8)).objectValue } ?? [:]
        mirror[name] = entry
        return entry
    }

    /// NSLock.withLock is missing from older Linux Foundation releases.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
