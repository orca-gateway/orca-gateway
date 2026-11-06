import XCTest

@testable import OrcaGatewayCore

/// T1.5: page and app scopes, nested keys, and a change notifies only the
/// subscribers of that key (the per-node `watches` of the Flutter WatchBuilder).
final class ElmStoreTests: XCTestCase {
    /// Records every notification per label.
    private final class Probe {
        var hits: [String: Int] = [:]
        var subs: [ElmStore.Subscription] = []

        func watch(_ store: ElmStore, _ label: String, _ keys: [String]) {
            subs.append(store.subscribe(keys) { [unowned self] _ in self.hits[label, default: 0] += 1 })
        }

        func count(_ label: String) -> Int { hits[label] ?? 0 }
    }

    func testChangeNotifiesOnlyWatchersOfThatKey() {
        let store = ElmStore(page: ["count": 0, "name": "a"])
        let probe = Probe()
        probe.watch(store, "count", ["count"])
        probe.watch(store, "name", ["name"])
        probe.watch(store, "both", ["count", "name"])
        probe.watch(store, "none", [])

        store.dispatch(["count": 1])
        XCTAssertEqual(probe.count("count"), 1)
        XCTAssertEqual(probe.count("name"), 0)
        XCTAssertEqual(probe.count("both"), 1)
        XCTAssertEqual(probe.count("none"), 0)
        XCTAssertEqual(store.value("count"), 1)

        // Writing the same value again is not a change.
        store.dispatch(["count": 1])
        XCTAssertEqual(probe.count("count"), 1)

        // An unrelated key notifies nobody watching count or name.
        store.dispatch(["other": true])
        XCTAssertEqual(probe.count("count") + probe.count("name"), 1)
    }

    func testNestedKeys() {
        let store = ElmStore(page: ["theme": ["color": "red", "size": 12]])
        let probe = Probe()
        probe.watch(store, "color", ["theme.color"])
        probe.watch(store, "size", ["theme.size"])
        probe.watch(store, "theme", ["theme"])

        store.dispatch(["theme": ["color": "blue", "size": 12]])
        XCTAssertEqual(probe.count("color"), 1)
        XCTAssertEqual(probe.count("size"), 0, "size did not change")
        XCTAssertEqual(probe.count("theme"), 1, "the parent changed")
        XCTAssertEqual(store.value("theme.color"), "blue")

        // A flat dotted key (what setState("theme.color") writes) shadows the
        // nested path, as lookupStatePath reads the flat key first.
        store.dispatch(["theme.color": "green"])
        XCTAssertEqual(probe.count("color"), 2)
        XCTAssertEqual(probe.count("theme"), 1, "the nested map is untouched")
        XCTAssertEqual(store.value("theme.color"), "green")

        // Array paths.
        store.dispatch(["items": [["name": "x"]]])
        probe.watch(store, "item0", ["items.0.name"])
        store.dispatch(["items": [["name": "y"], ["name": "z"]]])
        XCTAssertEqual(probe.count("item0"), 1)
        store.dispatch(["items": [["name": "y"]]])
        XCTAssertEqual(probe.count("item0"), 1)
    }

    func testPageAndAppScopes() {
        let store = ElmStore(page: ["count": 1], app: ["user": "amr", "count": 100])
        let probe = Probe()
        probe.watch(store, "user", ["user"])
        probe.watch(store, "count", ["count"])

        // Page wins on a key held by both scopes.
        XCTAssertEqual(store.value("count"), 1)
        store.dispatch(["count": 200], scope: .app)
        XCTAssertEqual(probe.count("count"), 0, "the merged value did not change")
        XCTAssertEqual(store.state.app["count"], 200)

        store.dispatch(["user": "sam"], scope: .app)
        XCTAssertEqual(probe.count("user"), 1)
        XCTAssertEqual(store.state.page["user"], nil, "app writes stay in the app scope")

        store.dispatch(["count": 2], scope: .page)
        XCTAssertEqual(probe.count("count"), 1)
        XCTAssertEqual(store.state.merged["count"], 2)
    }

    func testSeedFollowsStateManagerInitPage() {
        let store = ElmStore(page: ["stale": true], app: ["user": "amr"])
        store.seed([
            StateDefinition(key: "count", scope: .page, initial: 0),
            StateDefinition(key: "user", scope: .app, initial: "default"),
            StateDefinition(key: "theme", scope: .app, initial: "dark"),
        ])
        XCTAssertEqual(store.state.page, ["count": 0], "page scope replaced")
        XCTAssertEqual(store.state.app["user"], "amr", "set app keys survive navigation")
        XCTAssertEqual(store.state.app["theme"], "dark", "unset app keys take their initial")
    }

    func testCancelAndReleaseStopNotifications() {
        let store = ElmStore(page: ["count": 0])
        var hits = 0
        let sub = store.subscribe(["count"]) { _ in hits += 1 }
        store.dispatch(["count": 1])
        sub.cancel()
        store.dispatch(["count": 2])
        XCTAssertEqual(hits, 1)

        do {
            let released = store.subscribe(["count"]) { _ in hits += 1 }
            _ = released
        }
        XCTAssertEqual(store.subscriberCount, 0)
        store.dispatch(["count": 3])
        XCTAssertEqual(hits, 1)
    }

    func testReducerAppliesStateAndReturnsEffects() {
        // The executor (S3) is a pure Reducer; the store commits its state and
        // hands the effects to the adapters.
        let reducer: Reducer = { state, action in
            guard case .setState(let set) = action else { return (state, []) }
            let value = state.resolver().resolve(set.value)
            return (state.setting(set.key, value, in: set.scope ?? .page),
                    [ActionEffect("showToast", ["message": "saved", "duration": 2000])])
        }
        let store = ElmStore(page: ["count": 1])
        var seen: [JSONValue] = []
        let sub = store.subscribe(["count"]) { state in seen.append(state.value("count")) }
        let effects = store.apply(
            .setState(.init(key: "count", value: [
                "type": "transform", "input": ["type": "state", "key": "count", "scope": "page"],
                "by": [["type": "add", "by": ["type": "static", "value": 1]]],
            ])),
            with: reducer)
        XCTAssertEqual(seen, [2])
        XCTAssertEqual(effects.map(\.json), [["type": "showToast", "message": "saved", "duration": 2000]])
        withExtendedLifetime(sub) {}
    }

    func testStoreStateIsAValue() {
        let a = StoreState(page: ["x": 1])
        let b = a.setting("x", 2, in: .page).merging(["y": true], into: .app)
        XCTAssertEqual(a.page["x"], 1, "pure: the original is untouched")
        XCTAssertEqual(b, StoreState(page: ["x": 2], app: ["y": true]))
        XCTAssertEqual(try jsonOf(b), ["page": ["x": 2], "app": ["y": true]])
    }
}
