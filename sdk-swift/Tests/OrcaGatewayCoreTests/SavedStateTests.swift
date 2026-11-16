import Foundation
import XCTest

@testable import OrcaGatewayCore

/// Every entry of a local store, its JSON text decoded.
private func entries(_ store: MemoryKeyValueStore) throws -> [String: JSONValue] {
    try store.values.mapValues { try JSONValue.decode(Data($0.utf8)) }
}

/// A KeyValueStore that counts its reads and can hold any text.
private final class CountingStore: KeyValueStore, @unchecked Sendable {
    var values: [String: String]
    var reads: [String] = []
    init(_ values: [String: String] = [:]) { self.values = values }
    func string(forKey key: String) -> String? {
        reads.append(key)
        return values[key]
    }
    func set(_ value: String?, forKey key: String) { values[key] = value }
}

/// C14.6 (Swift core): persistState and clearState through SavedState, by
/// the saved-state contract S1-S8 the three SDKs share: entries
/// `orca_saved_app` and `orca_saved_page_<pageId>`, each a JSON object;
/// `local` in the KeyValueStore, `session` in a process-wide map.
final class SavedStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SavedState.resetSession()
    }

    override func tearDown() {
        SavedState.resetSession()
        super.tearDown()
    }

    /// A page store for `home`, and an executor over it that saves through `saved`.
    @MainActor private func page(
        _ page: [String: JSONValue] = [:], app: [String: JSONValue] = [:], saved: SavedState?
    ) -> (ElmStore, ActionExecutor) {
        let store = ElmStore(StoreState(page: page, app: app))
        store.pageId = "home"
        let executor = ActionExecutor(store: store)
        executor.savedState = saved
        return (store, executor)
    }

    private static func persist(_ key: String, _ scope: StateScope? = nil, _ storage: String? = nil) -> Action {
        .persistState(.init(key: key, scope: scope, storage: storage))
    }

    private static func clear(_ key: String, _ scope: StateScope? = nil) -> Action {
        .clearState(.init(key: key, scope: scope))
    }

    // MARK: S1, S3: persistState

    @MainActor func testC14_6_S1_S3_PersistWritesTheKeyIntoItsScopesEntryInLocal() async throws {
        let local = MemoryKeyValueStore()
        let (_, executor) = page(["count": 3, "name": "Ada"], app: ["visits": 2], saved: SavedState(local: local))

        try await executor.execute(Self.persist("count", .page, "local"))
        try await executor.execute(Self.persist("name"))
        try await executor.execute(Self.persist("visits", .app, "local"))

        XCTAssertEqual(try entries(local), [
            "orca_saved_page_home": ["count": 3, "name": "Ada"],
            "orca_saved_app": ["visits": 2],
        ])
        XCTAssertEqual(SavedState.sessionEntries, [:])
    }

    @MainActor func testC14_6_S3_PersistSessionKeepsOneSavedCopyPerKey() async throws {
        let local = MemoryKeyValueStore()
        let (store, executor) = page(["count": 3, "other": true], saved: SavedState(local: local))

        try await executor.execute(Self.persist("count", .page, "local"))
        try await executor.execute(Self.persist("other", .page, "local"))
        try await executor.execute(Self.persist("count", .page, "session"))
        XCTAssertEqual(try entries(local), ["orca_saved_page_home": ["other": true]])
        XCTAssertEqual(SavedState.sessionEntries, ["orca_saved_page_home": ["count": 3]])

        store.dispatch(["count": 4])
        try await executor.execute(Self.persist("count", .page, "local"))
        XCTAssertEqual(try entries(local), ["orca_saved_page_home": ["other": true, "count": 4]])
        XCTAssertEqual(SavedState.sessionEntries, [:], "an entry left with no key is deleted")
    }

    @MainActor func testC14_6_S3_PersistIsASnapshotSavesNullAndIgnoresAnAbsentKey() async throws {
        let local = MemoryKeyValueStore()
        let (store, executor) = page(["count": 3, "empty": .null], saved: SavedState(local: local))

        try await executor.execute(Self.persist("count"))
        store.dispatch(["count": 9])
        XCTAssertEqual(try entries(local), ["orca_saved_page_home": ["count": 3]], "a later setState saves nothing")

        try await executor.execute(Self.persist("empty"))
        try await executor.execute(Self.persist("missing"))
        try await executor.execute(Self.persist("count", .app))
        XCTAssertEqual(try entries(local), ["orca_saved_page_home": ["count": 3, "empty": .null]])
        XCTAssertEqual(store.state, StoreState(page: ["count": 9, "empty": .null]))
    }

    // MARK: S4: clearState

    @MainActor func testC14_6_S4_ClearNullsTheLiveKeyAndRemovesEverySavedCopy() async throws {
        let local = MemoryKeyValueStore([
            "orca_saved_page_home": #"{"count":3,"keep":1}"#, "orca_saved_app": #"{"token":"t"}"#,
        ])
        SavedState.resetSession(["orca_saved_page_home": ["count": 5], "orca_saved_app": ["token": "s", "theme": "dark"]])
        let (store, executor) = page(["count": 5, "keep": 1], app: ["token": "t", "theme": "dark"],
                                     saved: SavedState(local: local))

        try await executor.execute(Self.clear("count"))
        try await executor.execute(Self.clear("token", .app))

        XCTAssertEqual(store.state, StoreState(page: ["count": .null, "keep": 1], app: ["token": .null, "theme": "dark"]))
        XCTAssertEqual(try entries(local), ["orca_saved_page_home": ["keep": 1]], "the emptied app entry is deleted")
        XCTAssertEqual(SavedState.sessionEntries, ["orca_saved_app": ["theme": "dark"]])
    }

    @MainActor func testC14_6_S4_WithoutSavedStateClearOnlyNullsAndPersistSavesNothing() async throws {
        let (store, executor) = page(["count": 5], saved: nil)
        try await executor.execute(Self.persist("count", .page, "session"))
        try await executor.execute(Self.clear("count"))
        try await executor.execute(Self.clear("absent", .app))
        XCTAssertEqual(store.state, StoreState(page: ["count": .null], app: ["absent": .null]))
        XCTAssertEqual(SavedState.sessionEntries, [:])
    }

    // MARK: S5: restore

    func testC14_6_S5_RestorePageReplacesTheInitialsAndAddsUndeclaredKeys() {
        let local = MemoryKeyValueStore(["orca_saved_page_home": #"{"count":7}"#])
        SavedState.resetSession(["orca_saved_page_home": ["draft": "hi"], "orca_saved_page_other": ["x": 1]])
        let store = ElmStore()
        store.seed([StateDefinition(key: "count", scope: .page, initial: 0),
                    StateDefinition(key: "name", scope: .page, initial: "")])

        SavedState(local: local).restorePage(into: store, pageId: "home")
        XCTAssertEqual(store.state.page, ["count": 7, "name": "", "draft": "hi"])
        XCTAssertEqual(store.state.app, [:])
    }

    func testC14_6_S5_RestoreSetsTheAppEntryOverTheAppState() {
        let local = MemoryKeyValueStore(["orca_saved_app": #"{"visits":4,"user":{"id":1}}"#])
        SavedState.resetSession(["orca_saved_app": ["lang": "fr"]])
        let store = ElmStore(StoreState(page: ["visits": "page"], app: ["visits": 0, "theme": "light"]))

        SavedState(local: local).restore(into: store)
        XCTAssertEqual(store.state, StoreState(
            page: ["visits": "page"], app: ["visits": 4, "theme": "light", "user": ["id": 1], "lang": "fr"]))
    }

    // MARK: S2, S6: storages

    @MainActor func testC14_6_S2_ARestartOverTheSameFilesRestoresLocalAndNotSession() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("orca-saved-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let (_, executor) = page(["count": 3], app: ["visits": 1, "seen": true],
                                 saved: SavedState(local: FileKeyValueStore(directory: dir)))
        try await executor.execute(Self.persist("count"))
        try await executor.execute(Self.persist("visits", .app))
        try await executor.execute(Self.persist("seen", .app, "session"))

        // Another SavedState in this process sees the same session.
        let again = ElmStore()
        SavedState(local: nil).restore(into: again)
        XCTAssertEqual(again.state.app, ["seen": true])

        // A restart: the process ends (the session goes), the files stay.
        SavedState.resetSession()
        let restarted = SavedState(local: FileKeyValueStore(directory: dir))
        let store = ElmStore()
        restarted.restore(into: store)
        store.seed([StateDefinition(key: "count", scope: .page, initial: 0)])
        restarted.restorePage(into: store, pageId: "home")
        XCTAssertEqual(store.state, StoreState(page: ["count": 3], app: ["visits": 1]))
    }

    func testC14_6_S6_LocalIsReadOnceAndAFailedReadRestoresNothing() throws {
        let local = CountingStore(["orca_saved_page_home": "not json", "orca_saved_app": "[1]"])
        let saved = SavedState(local: local)
        let store = ElmStore(StoreState(page: ["count": 1]))
        saved.restorePage(into: store, pageId: "home")
        saved.restore(into: store)
        saved.restorePage(into: store, pageId: "home")
        XCTAssertEqual(store.state, StoreState(page: ["count": 1]))
        XCTAssertEqual(local.reads.sorted(), ["orca_saved_app", "orca_saved_page_home"], "the mirror reads each entry once")

        // A persist writes over the unreadable entry.
        store.pageId = "home"
        saved.persist("count", scope: .page, pageId: "home", storage: .local, from: store)
        XCTAssertEqual(local.values["orca_saved_page_home"], #"{"count":1}"#)
    }

    // MARK: S7, S8

    @MainActor func testC14_6_S7_NeitherActionEmitsAnEffectAndBothAreImplemented() async throws {
        let (_, executor) = page(["count": 1], saved: SavedState(local: MemoryKeyValueStore()))
        var effects: [ActionEffect] = []
        executor.onEffect = { effects.append($0) }
        try await executor.execute(.actionGroup(.init(actions: [Self.persist("count"), Self.clear("count")])))
        XCTAssertEqual(effects, [])
        XCTAssertTrue(ActionExecutor.implements(Self.persist("count")))
        XCTAssertTrue(ActionExecutor.implements(Self.clear("count")))
    }
}
