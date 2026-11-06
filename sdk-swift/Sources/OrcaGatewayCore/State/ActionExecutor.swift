import Foundation

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
        "lifecycle", "navigate", "goBack", "openUrl", "copyToClipboard", "share",
        "serverAction", "addComponent", "updateComponent", "deleteComponent", "replaceComponent",
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

    public init(store: ElmStore, client: OrcaClient? = nil) {
        self.store = store
        self.client = client
    }

    /// Run one action. `eventData` feeds `V.event(...)` for this action and
    /// everything it runs, as Dart's `execute(action, eventData:)` does.
    public func execute(_ action: Action, eventData: [String: JSONValue]? = nil) async throws {
        let previous = self.eventData
        if let eventData { self.eventData = eventData }
        defer { self.eventData = previous }
        try await run(action)
    }

    /// Run actions one after another (Dart `executeAll`).
    public func executeAll(_ actions: [Action], eventData: [String: JSONValue]? = nil) async throws {
        for action in actions { try await execute(action, eventData: eventData) }
    }

    /// True when the action and everything nested in it is implemented.
    nonisolated public static func implements(_ action: Action) -> Bool {
        switch action {
        case .actionGroup(let group): return group.actions.allSatisfy(implements)
        case .lifecycle(let l): return implements(l.action)
        case .conditionalAction(let c):
            return c.branches.allSatisfy { implements($0.then) } && (c.else.map(implements) ?? true)
        default: return kinds.contains(action.kind)
        }
    }

    // MARK: Handlers

    private var resolver: ValueResolver { store.state.resolver(eventData: eventData) }

    private func run(_ action: Action) async throws {
        guard Self.kinds.contains(action.kind) else { return }
        // Every action run, nested ones too, is a DevTools `action` event.
        let start = OrcaDebug.isEnabled ? OrcaDebug.now() : nil
        defer {
            if let start {
                OrcaDebug.report(.action(action, pageId: store.pageId ?? "", durationMs: OrcaDebug.now() - start))
            }
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

        case .navigate(let n):
            let resolver = self.resolver
            let route = resolver.resolveToString(n.route ?? n.path ?? .null)
            guard !route.isEmpty else { return }
            var payload: [String: JSONValue] = ["route": .string(route), "replace": .bool(n.replace == true)]
            if let params = n.params { payload["params"] = .object(params.mapValues { resolver.resolve($0) }) }
            await emit(ActionEffect("navigate", payload))

        case .goBack:
            await emit(ActionEffect("goBack"))

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
