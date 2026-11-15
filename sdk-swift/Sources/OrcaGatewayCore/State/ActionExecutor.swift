import Foundation

/// Where an action chain started: the widget and the trigger that fired it,
/// so `once` can run at most once per (widget, trigger). A port of the Dart
/// `ActionSource` (sdk/lib/src/state/action_executor.dart); nested runs of
/// the chain inherit it.
public struct ActionSource: Equatable, Hashable, Sendable {
    public var widgetId: String
    public var trigger: String

    public init(widgetId: String, trigger: String) {
        self.widgetId = widgetId
        self.trigger = trigger
    }

    /// `widgetId::trigger`, the key `once` records.
    public var dedupeKey: String { "\(widgetId)::\(trigger)" }
}

/// Runs a page's actions: state changes through the store, structural changes
/// through `onMutation`, everything else as effects. A port of
/// `sdk/lib/src/state/action_executor.dart` for the kinds the Swift caps
/// vector advertises (sdk-swift/capabilities.json).
///
/// Every platform effect is first reported to `onEffect` as data (what the
/// cross-SDK fixtures in schema/fixtures/actions compare), then handed to
/// `perform` (the host's navigation, system and toast adapters). A
/// `serverAction` is the one effect the executor carries out itself: it emits
/// the request, POSTs it through `client` and runs the actions that come
/// back. Without `perform` or `client` the executor is pure, which is how the
/// fixtures run on Linux.
///
/// It lives on the main actor because the store and the node tree it changes
/// are what SwiftUI draws.
@MainActor
public final class ActionExecutor {
    /// The kinds this executor runs. Anything else does nothing, as an
    /// unregistered handler does in Dart. `replaceComponent` is a server
    /// response kind outside action.ts, so it is handled but never advertised.
    nonisolated public static let kinds: Set<String> = [
        "setState", "actionGroup", "showSnackbar", "showToast", "conditionalAction",
        "lifecycle", "navigate", "goBack", "switchTab", "openDrawer", "openUrl", "copyToClipboard", "share",
        "serverAction", "addComponent", "updateComponent", "deleteComponent", "replaceComponent",
        "once", "always", "debugLog",
    ]

    public let store: ElmStore
    public let client: OrcaClient?
    /// Every effect, as data, before it is performed.
    public var onEffect: ((ActionEffect) -> Void)?
    /// Performs an effect on the platform (navigation, URL, clipboard, share,
    /// snackbar and toast). Not called for `serverAction`.
    public var perform: ((ActionEffect) async -> Void)?
    /// A structural change from a server action, for the page's node tree.
    public var onMutation: ((ComponentMutation) -> Void)?

    private let reducer = ActionReducer()
    private var eventData: [String: JSONValue]?
    /// Custom handlers by the type they were registered under, apart from
    /// `kinds` (which stays what the caps vector advertises).
    private var handlers: [String: OrcaActionHandler] = [:]
    /// The source of the chain being run; nested runs inherit it.
    private var source: ActionSource?
    /// The `once` keys (`widgetId::trigger`) that have fired, for as long as
    /// this executor (its page model) lives. Flutter's known limit is kept:
    /// the key has no id for the wrapper, so two `once` fired by one widget
    /// and trigger share it, and in Sequential(Once(A), Once(B)) B never runs.
    private var firedOnceKeys: Set<String> = []

    public init(store: ElmStore, client: OrcaClient? = nil) {
        self.store = store
        self.client = client
    }

    /// Register a handler for an action type, or override a built-in one; a
    /// second registration of the same type replaces the first. Dart
    /// `registerHandler` (sdk/lib/src/state/action_executor.dart).
    ///
    /// An action runs the handler registered under its type as sent, else the
    /// one under that type without a leading `custom:`, so a plugin registers
    /// `moveCamera` and receives `custom:moveCamera`.
    public func registerHandler(_ type: String, _ handler: @escaping OrcaActionHandler) {
        handlers[type] = handler
    }

    /// Resolve a Value against the page and app state and the event data of
    /// the action being run, for handlers that read their raw params. Dart
    /// `resolveValue` (sdk/lib/src/state/action_executor.dart).
    public func resolve(_ value: JSONValue) -> JSONValue {
        resolver.resolve(value)
    }

    /// Run one action. `eventData` feeds `V.event(...)` for this action and
    /// everything it runs, as Dart's `execute(action, eventData:, source:)`
    /// does; `source` (the widget and trigger that fired it) keys `once`.
    /// Both are inherited by everything the action runs and restored after.
    public func execute(
        _ action: Action, eventData: [String: JSONValue]? = nil, source: ActionSource? = nil
    ) async throws {
        let previous = (self.eventData, self.source)
        if let eventData { self.eventData = eventData }
        if let source { self.source = source }
        defer { (self.eventData, self.source) = previous }
        try await run(action)
    }

    /// Run actions one after another (Dart `executeAll`).
    public func executeAll(
        _ actions: [Action], eventData: [String: JSONValue]? = nil, source: ActionSource? = nil
    ) async throws {
        for action in actions { try await execute(action, eventData: eventData, source: source) }
    }

    /// True when the action and everything nested in it is implemented.
    nonisolated public static func implements(_ action: Action) -> Bool {
        switch action {
        case .actionGroup(let group): return group.actions.allSatisfy(implements)
        case .lifecycle(let l): return implements(l.action)
        case .once(let w), .always(let w): return implements(w.action)
        case .conditionalAction(let c):
            return c.branches.allSatisfy { implements($0.then) } && (c.else.map(implements) ?? true)
        default: return kinds.contains(action.kind)
        }
    }

    // MARK: Handlers

    private var resolver: ValueResolver { store.state.resolver(eventData: eventData) }

    /// The handler for an action, as Dart `execute` picks it: exact type first,
    /// then the type without `custom:`.
    private func handler(for kind: String) -> OrcaActionHandler? {
        let bare = kind.hasPrefix("custom:") ? String(kind.dropFirst("custom:".count)) : kind
        return handlers[kind] ?? handlers[bare]
    }

    private func run(_ action: Action) async throws {
        let handler = self.handler(for: action.kind)
        guard handler != nil || Self.kinds.contains(action.kind) else { return }
        // Every action run, nested ones too, is a DevTools `action` event.
        let start = OrcaDebug.isEnabled ? OrcaDebug.now() : nil
        defer {
            if let start {
                OrcaDebug.report(.action(action, pageId: store.pageId ?? "", durationMs: OrcaDebug.now() - start))
            }
        }

        if let handler {
            // The raw object as sent; a built-in kind is encoded back to it.
            switch action {
            case .custom(let raw), .unknown(let raw): try await handler(raw, self)
            default: try await handler(action.json, self)
            }
            return
        }

        switch action {
        case .setState, .showSnackbar, .showToast:
            let (next, effects) = reducer.reduce(store.state, action, eventData: eventData)
            store.commit(next)
            for effect in effects { await emit(effect) }

        case .actionGroup(let group):
            if group.mode == "parallel" {
                try await runParallel(group.actions)
            } else {
                for inner in group.actions { try await run(inner) }
            }

        case .conditionalAction(let c):
            let resolver = self.resolver
            for branch in c.branches where resolver.evaluate(branch.when) {
                try await run(branch.then)
                return
            }
            if let otherwise = c.else { try await run(otherwise) }

        case .lifecycle(let l):
            try await runLifecycle(l)

        // At most once per (widget, trigger) (see `firedOnceKeys`); without
        // a source, every time.
        case .once(let w):
            if let source, !firedOnceKeys.insert(source.dedupeKey).inserted { return }
            try await run(w.action)

        case .always(let w):
            try await run(w.action)

        case .debugLog(let d):
            await emit(debugLogEffect(d))

        case .navigate(let n):
            let resolver = self.resolver
            let route = resolver.resolveToString(n.route ?? n.path ?? .null)
            guard !route.isEmpty else { return }
            var payload: [String: JSONValue] = ["route": .string(route), "replace": .bool(n.replace == true)]
            if let params = n.params { payload["params"] = .object(params.mapValues { resolver.resolve($0) }) }
            await emit(ActionEffect("navigate", payload))

        case .goBack:
            await emit(ActionEffect("goBack"))

        case .switchTab(let t):
            await emit(ActionEffect("switchTab", ["tabId": .string(t.tabId)]))

        case .openDrawer:
            await emit(ActionEffect("openDrawer"))

        case .openUrl(let o):
            await emit(ActionEffect("openUrl", ["url": .string(resolver.resolveToString(o.url ?? .null))]))

        case .copyToClipboard(let c):
            await emit(ActionEffect("copyToClipboard", ["text": .string(resolver.resolveToString(c.text ?? .null))]))

        case .share(let s):
            let resolver = self.resolver
            let text = resolver.resolveToString(s.text ?? s.message ?? .null)
            let subject = resolver.resolveToString(s.subject ?? s.title ?? .null)
            var payload: [String: JSONValue] = ["text": .string(text)]
            if !subject.isEmpty { payload["subject"] = .string(subject) }
            await emit(ActionEffect("share", payload))

        case .serverAction(let s):
            try await runServerAction(s)

        case .updateComponent(let u):
            onMutation?(.update(id: u.id, props: u.props ?? [:]))

        case .deleteComponent(let d):
            onMutation?(.delete(id: d.id))

        case .addComponent(let a):
            let nodes = try (a.components?.arrayValue ?? []).map { try $0.decode(ComponentNode.self) }
            onMutation?(.add(parentId: a.parentId, components: nodes, position: a.position))

        case .unknown(let raw) where action.kind == "replaceComponent":
            guard let target = raw["targetId"].stringValue else { return }
            let nodes = try (raw["components"].arrayValue ?? []).map { try $0.decode(ComponentNode.self) }
            onMutation?(.replace(targetId: target, components: nodes))

        default:
            return
        }
    }

    /// The `debugLog` effect: level ("debug") and tag ("orca"), the message
    /// as text, the data resolved (entry by entry for a record, as Dart does
    /// for any map). Never throws: the resolver yields null where Dart's
    /// throws, so Dart's "<unresolvable>" has no case here. No timestamp and
    /// nothing from the include* flags, which only feed the host's log line.
    private func debugLogEffect(_ d: Action.DebugLog) -> ActionEffect {
        let resolver = self.resolver
        var payload: [String: JSONValue] = [
            "level": .string(d.level ?? "debug"), "tag": .string(d.tag ?? "orca"),
        ]
        if let message = d.message, !message.isNull {
            payload["message"] = .string(resolver.resolveToString(message))
        }
        switch d.data {
        case .object(let entries)?:
            payload["data"] = .object(entries.mapValues { resolver.resolve($0) })
        case let raw?:
            let data = resolver.resolve(raw)
            if !data.isNull { payload["data"] = data }
        case nil:
            break
        }
        return ActionEffect("debugLog", payload)
    }

    /// Report an effect, then hand it to the platform.
    private func emit(_ effect: ActionEffect) async {
        onEffect?(effect)
        await perform?(effect)
    }

    /// Dart `Future.wait`: start every action, wait for all of them, then
    /// throw the first error, if any.
    private func runParallel(_ actions: [Action]) async throws {
        var firstError: Error?
        await withTaskGroup(of: Error?.self) { group in
            for action in actions {
                group.addTask { @MainActor in
                    do {
                        try await self.run(action)
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            for await error in group where firstError == nil {
                firstError = error
            }
        }
        if let firstError { throw firstError }
    }

    /// onLoading, then the action and onSuccess; onError on a throw (or the
    /// error goes on up when there is none); onComplete always, last.
    private func runLifecycle(_ l: Action.Lifecycle) async throws {
        try await runList(l.onLoading)
        var failure: Error?
        do {
            try await run(l.action)
            try await runList(l.onSuccess)
        } catch {
            if let onError = l.onError {
                do { try await runList(onError) } catch let next { failure = next }
            } else {
                failure = error
            }
        }
        try await runList(l.onComplete)
        if let failure { throw failure }
    }

    private func runList(_ list: ActionList?) async throws {
        for action in list?.actions ?? [] { try await run(action) }
    }

    /// Emit the request, POST it, run what comes back. A refused call (a
    /// status other than 200) shows its message in a snackbar and does not
    /// throw, as in Dart; a transport failure throws.
    private func runServerAction(_ s: Action.ServerAction) async throws {
        let resolver = self.resolver
        let params = s.params?.mapValues { resolver.resolve($0) }
        var payload: [String: JSONValue] = ["id": .string(s.id)]
        if let params { payload["params"] = .object(params) }
        onEffect?(ActionEffect("serverAction", payload))

        guard let client else { return }
        do {
            let state = store.state
            let actions = try await client.executeAction(
                s.id, params: params, pageState: state.page, appState: state.app)
            for action in actions { try await run(action) }
        } catch OrcaClientError.action(_, let message) {
            try await run(.showSnackbar(.init(message: .string(message))))
        }
    }
}
