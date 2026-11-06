import Foundation

/// Both state scopes as one value: what a reducer reads and returns, and the
/// shape of `state` and `expected.state` in schema/fixtures/actions.
public struct StoreState: Codable, Equatable, Sendable {
    public var page: [String: JSONValue]
    public var app: [String: JSONValue]

    public init(page: [String: JSONValue] = [:], app: [String: JSONValue] = [:]) {
        self.page = page
        self.app = app
    }

    /// App first, page on top: the view every Dart call site resolves against.
    public var merged: [String: JSONValue] {
        app.merging(page) { _, pageValue in pageValue }
    }

    /// Read a key (flat, or a dotted path) from the merged view.
    public func value(_ key: String) -> JSONValue {
        StatePath.lookup(merged, key)
    }

    public subscript(scope: StateScope) -> [String: JSONValue] {
        get { scope == .app ? app : page }
        set { if scope == .app { app = newValue } else { page = newValue } }
    }

    /// Pure write of one flat key, as the Dart `setState` handler does
    /// (`theme.color` is stored as that flat key, which `lookup` finds first).
    public func setting(_ key: String, _ value: JSONValue, in scope: StateScope) -> StoreState {
        var next = self
        next[scope][key] = value
        return next
    }

    /// Pure merge of several keys into one scope (Dart `ElmStore.dispatch`).
    public func merging(_ update: [String: JSONValue], into scope: StateScope) -> StoreState {
        var next = self
        next[scope].merge(update) { _, new in new }
        return next
    }

    /// A resolver over the merged view.
    public func resolver(eventData: [String: JSONValue]? = nil) -> ValueResolver {
        ValueResolver(state: merged, eventData: eventData)
    }
}

/// A side effect an action asks the host to perform, as data: navigation,
/// snackbar and toast, URL launch, clipboard, share, server call. Mirrors the
/// Dart `ActionEffect` (`{type, ...payload}`), so fixtures compare effects as
/// plain JSON and every SDK must emit the same list for the same actions.
public struct ActionEffect: Equatable, Sendable, Codable {
    public var type: String
    public var payload: [String: JSONValue]

    public init(_ type: String, _ payload: [String: JSONValue] = [:]) {
        self.type = type
        self.payload = payload
    }

    /// `{"type": type, ...payload}`, the wire shape in the fixtures.
    public var json: JSONValue {
        var o = payload
        o["type"] = .string(type)
        return .object(o)
    }

    public init(json: JSONValue) throws {
        guard case .object(var o) = json, case .string(let type)? = o["type"] else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "An effect is an object with a string type"))
        }
        o["type"] = nil
        self.init(type, o)
    }

    public init(from decoder: Decoder) throws {
        try self.init(json: try JSONValue(from: decoder))
    }

    public func encode(to encoder: Encoder) throws {
        try json.encode(to: encoder)
    }
}

/// A reducer: the current state and one action in, the next state and the
/// effects to run out. The executor (S3) is one of these; keeping it pure is
/// what lets the action fixtures run without a UI.
public typealias Reducer = (StoreState, Action) -> (StoreState, [ActionEffect])

/// The observable state holder behind a page: page and app scopes, change
/// notifications scoped to the keys a view watches.
///
/// A subscriber names the state keys it depends on (a node's `watches`;
/// dotted paths allowed). After every commit the store compares each
/// subscriber's watched values before and after against the merged view and
/// notifies only the subscribers whose values changed, which is what the
/// Flutter `WatchBuilder` does per node. Not thread-safe: use it from one
/// actor (the main actor in the UI layer).
public final class ElmStore {
    public private(set) var state: StoreState

    private var subscribers: [Int: Subscriber] = [:]
    private var nextId = 0

    private struct Subscriber {
        var watches: [String]
        var snapshot: [JSONValue]
        var onChange: (StoreState) -> Void
    }

    /// Called after every commit with the new state, before subscribers are
    /// notified: how a navigator keeps the app scope shared between pages.
    public var onCommit: ((StoreState) -> Void)?

    /// The page this store belongs to. When set and DevTools is on, every
    /// changed key is reported as a `state_change` (Dart `ElmStore.pageId`).
    public var pageId: String?

    public init(_ state: StoreState = StoreState()) {
        self.state = state
    }

    public convenience init(page: [String: JSONValue] = [:], app: [String: JSONValue] = [:]) {
        self.init(StoreState(page: page, app: app))
    }

    /// Read a key from the merged view (flat key first, then dotted path).
    public func value(_ key: String) -> JSONValue { state.value(key) }

    /// Seed a page from its `PageResponse.state` (Dart `StateManager.initPage`):
    /// page definitions replace the page scope; an app definition is applied
    /// only when that app key is still unset, so app state survives navigation.
    public func seed(_ definitions: [StateDefinition]) {
        var next = state
        next.page = [:]
        for def in definitions {
            switch def.scope {
            case .page:
                next.page[def.key] = def.initial
            case .app:
                if (next.app[def.key] ?? .null).isNull { next.app[def.key] = def.initial }
            }
        }
        commit(next)
    }

    /// Merge keys into one scope and notify (Dart `ElmStore.dispatch`).
    public func dispatch(_ update: [String: JSONValue], scope: StateScope = .page) {
        commit(state.merging(update, into: scope))
    }

    /// Run a pure reducer, commit its state, and hand back its effects for the
    /// platform adapters to perform.
    @discardableResult
    public func apply(_ action: Action, with reducer: Reducer) -> [ActionEffect] {
        let (next, effects) = reducer(state, action)
        commit(next)
        return effects
    }

    /// Replace the state and notify the subscribers whose watched values
    /// changed. Subscribers are notified in subscription order.
    public func commit(_ next: StoreState) {
        let previous = state
        state = next
        if let pageId, OrcaDebug.isEnabled {
            for event in DevToolsEvent.stateChanges(from: previous, to: next, pageId: pageId) {
                OrcaDebug.report(event)
            }
        }
        onCommit?(next)
        let merged = next.merged
        for id in subscribers.keys.sorted() {
            guard var sub = subscribers[id] else { continue }
            let snapshot = sub.watches.map { StatePath.lookup(merged, $0) }
            guard snapshot != sub.snapshot else { continue }
            sub.snapshot = snapshot
            subscribers[id] = sub
            sub.onChange(next)
        }
    }

    /// Watch some keys. The handler runs after any commit that changes one of
    /// their values; keep the returned subscription alive for as long as the
    /// view is, or cancel it.
    public func subscribe(
        _ watches: [String], onChange: @escaping (StoreState) -> Void
    ) -> Subscription {
        let id = nextId
        nextId += 1
        let merged = state.merged
        subscribers[id] = Subscriber(
            watches: watches,
            snapshot: watches.map { StatePath.lookup(merged, $0) },
            onChange: onChange)
        return Subscription { [weak self] in self?.subscribers[id] = nil }
    }

    public var subscriberCount: Int { subscribers.count }

    /// Cancels its watch when cancelled or released.
    public final class Subscription {
        private var cancelAction: (() -> Void)?

        init(_ cancel: @escaping () -> Void) { cancelAction = cancel }

        public func cancel() {
            cancelAction?()
            cancelAction = nil
        }

        deinit { cancel() }
    }
}
