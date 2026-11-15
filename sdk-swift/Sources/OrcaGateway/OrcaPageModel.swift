#if canImport(SwiftUI)
import Combine
import os
import SwiftUI

/// A snackbar or toast on screen. Both are drawn as a floating message at the
/// bottom; a snackbar spans the width.
public struct OrcaToast: Identifiable, Equatable, Sendable {
    public enum Style: Sendable { case snackbar, toast }
    public let id = UUID()
    public var message: String
    public var duration: TimeInterval
    public var style: Style
}

/// One rendered page: its nodes, its store, and the executor that runs its
/// actions. Views resolve nodes through it and fire triggers into it.
///
/// Snackbars and toasts are drawn by the page itself. Navigation and system
/// effects go to `effectHandler` (OrcaApp's router sets it), and a server
/// action's structural changes edit the node tree here.
@MainActor
public final class OrcaPageModel: ObservableObject {
    public private(set) var renderer: PageRenderer
    public let store: ElmStore
    public let executor: ActionExecutor
    /// The snackbar or toast showing now.
    @Published public var toast: OrcaToast?
    /// Bumped after every change to the node tree (a server action adding,
    /// updating, replacing or deleting components).
    @Published public private(set) var structureRevision = 0
    /// Every effect as data, before it is performed (DevTools, logging).
    public var onEffect: ((ActionEffect) -> Void)?
    /// Performs what the page does not: navigation, URL, clipboard, share.
    public var effectHandler: ((ActionEffect) -> Void)?
    /// An action that threw and had no lifecycle `onError` to catch it. Dart
    /// leaves such a future unhandled; Swift reports it here and moves on.
    public var onError: ((Error) -> Void)?
    /// Builders for the plugin and host widget types this page draws beyond
    /// the SDK's own views.
    public let widgets: WidgetBuilders

    public init(page: PageResponse, store: ElmStore = ElmStore(),
                registry: WidgetRegistry = .shared, client: OrcaClient? = nil,
                widgets: WidgetBuilders = WidgetBuilders()) {
        self.renderer = PageRenderer(page: page, registry: registry)
        self.store = store
        self.widgets = widgets
        self.executor = ActionExecutor(store: store, client: client)
        store.pageId = page.pageId
        store.seed(page.state)
        executor.onEffect = { [weak self] effect in self?.onEffect?(effect) }
        executor.perform = { [weak self] effect in self?.perform(effect) }
        executor.onMutation = { [weak self] mutation in self?.apply(mutation) }
    }

    public var page: PageResponse { renderer.page }

    public func resolve(_ id: String) -> ResolvedNode? {
        renderer.resolve(id, state: store.state)
    }

    /// Resolve under an AnimatedBuilder: `tween` props take `animationProgress`.
    public func resolve(_ id: String, animationProgress: Double?) -> ResolvedNode? {
        renderer.resolve(id, state: store.state, animationProgress: animationProgress)
    }

    public func watches(of id: String) -> [String] {
        renderer.node(id)?.watches ?? []
    }

    /// Run the node's action for a trigger (`onTap`, `onLongPress`, ...), the
    /// Flutter `fireAction`: nothing happens when the node has none. The
    /// node and trigger are the run's source (what `once` is keyed by). The
    /// run is asynchronous (a server action waits on the network); the
    /// returned task finishes when the action does, which tests await.
    @discardableResult
    public func fire(_ trigger: String, on node: ResolvedNode,
                     eventData: [String: JSONValue]? = nil) -> Task<Void, Never>? {
        guard let action = node.actions[trigger] else { return nil }
        let source = ActionSource(widgetId: node.id, trigger: trigger)
        return Task { await run(action, eventData: eventData, source: source) }
    }

    /// Run one action to the end; `source` is the widget and trigger that
    /// fired it, when there is one.
    public func run(_ action: Action, eventData: [String: JSONValue]? = nil,
                    source: ActionSource? = nil) async {
        do {
            try await executor.execute(action, eventData: eventData, source: source)
        } catch {
            OrcaDebug.report(.error(message: "\(error)", context: "action \(action.kind) on \(page.pageId)"))
            onError?(error)
        }
    }

    /// Runs once, the first time the page is on screen (the loader's
    /// DevTools `timing` event, which needs the first frame).
    var onFirstAppear: (() -> Void)?

    func appeared() {
        let first = onFirstAppear
        onFirstAppear = nil
        first?()
    }

    /// The last text edit's run; each edit waits for the one before.
    private var textEdits: Task<Void, Never>?

    /// The user edited a TextField (Flutter `_buildTextField`'s onChanged):
    /// `setState` on the node's `stateKey` when it has one, then its
    /// `onChange` with `eventData: {value}`. Edits run one after another in
    /// typing order: Flutter runs each one synchronously, and two runs that
    /// overlapped could leave the page with an older value. The returned
    /// task finishes when this edit has run.
    @discardableResult
    func textChanged(_ value: String, on node: ResolvedNode) -> Task<Void, Never>? {
        let stateKey = node["stateKey"]?.stringValue
        let onChange = node.actions["onChange"]
        guard stateKey != nil || onChange != nil else { return nil }
        let previous = textEdits
        let edit = Task {
            await previous?.value
            if let stateKey {
                await run(.setState(Action.SetState(key: stateKey, value: .string(value))))
            }
            if let onChange {
                await run(onChange, eventData: ["value": .string(value)],
                          source: ActionSource(widgetId: node.id, trigger: "onChange"))
            }
        }
        textEdits = edit
        return edit
    }

    /// A link the page itself draws, such as a FallbackPrompt's call to
    /// action (Flutter: `OrcaUrlPolicy.isAllowed`, then `launchUrl`). A URL
    /// the policy refuses does nothing. Under OrcaApp it goes out as an
    /// `openUrl` effect, like the action; a page shown on its own opens it
    /// with `fallback` (SwiftUI's `openURL`).
    func openLink(_ raw: String, fallback: (URL) -> Void) {
        guard let url = OrcaURLPolicy.standard.url(raw) else { return }
        if let effectHandler {
            effectHandler(ActionEffect("openUrl", ["url": .string(url.absoluteString)]))
        } else {
            fallback(url)
        }
    }

    func perform(_ effect: ActionEffect) {
        switch effect.type {
        case "showSnackbar", "showToast":
            toast = OrcaToast(
                message: effect.payload["message"]?.stringValue ?? "",
                duration: Double(effect.payload["duration"]?.intValue ?? 4000) / 1000,
                style: effect.type == "showSnackbar" ? .snackbar : .toast)
        case "debugLog":
            Self.log(effect)
            effectHandler?(effect)
        default:
            effectHandler?(effect)
        }
    }

    /// A debugLog effect as a system log line, as Flutter writes
    /// `developer.log` and `debugPrint`: subsystem com.orcagateway, the tag
    /// as category, the message then the data as JSON. debug and info keep
    /// their level, warn is `.default`, error `.error`. Public, as Flutter's
    /// `debugPrint` prints it whole.
    static func log(_ effect: ActionEffect) {
        let payload = effect.payload
        let logger = Logger(subsystem: "com.orcagateway", category: payload["tag"]?.stringValue ?? "orca")
        var parts: [String] = []
        if let message = payload["message"]?.stringValue { parts.append(message) }
        if let data = payload["data"], let text = try? data.encoded() {
            parts.append(String(decoding: text, as: UTF8.self))
        }
        let level: OSLogType = switch payload["level"]?.stringValue {
        case "info": .info
        case "warn": .default
        case "error": .error
        default: .debug
        }
        logger.log(level: level, "\(parts.joined(separator: " "), privacy: .public)")
    }

    func apply(_ mutation: ComponentMutation) {
        renderer.apply(mutation)
        structureRevision += 1
    }
}

/// Re-renders one node when a key it watches changes, the Flutter
/// `WatchBuilder`: other nodes of the page are left alone. A change to the
/// node tree redraws every node, and picks up watches an update changed.
@MainActor
final class NodeObserver: ObservableObject {
    @Published private(set) var revision = 0
    private weak var model: OrcaPageModel?
    private let id: String
    private var watches: [String] = []
    private var subscription: ElmStore.Subscription?
    private var structure: AnyCancellable?

    init(model: OrcaPageModel, id: String) {
        self.model = model
        self.id = id
        subscribe()
        // `apply` edits the tree before it bumps the revision, so the tree is
        // already new when this runs.
        structure = model.$structureRevision.dropFirst().sink { [weak self] _ in
            self?.structureChanged()
        }
    }

    private func subscribe() {
        guard let model else { return }
        let next = model.watches(of: id)
        guard next != watches || subscription == nil else { return }
        watches = next
        subscription = next.isEmpty ? nil : model.store.subscribe(next) { [weak self] _ in
            self?.watchedChanged()
        }
    }

    /// A watched key changed: redraw, and tell DevTools.
    private func watchedChanged() {
        revision += 1
        guard OrcaDebug.isEnabled, let node = model?.renderer.node(id) else { return }
        OrcaDebug.report(.widgetRebuild(widgetId: id, widgetType: node.type, watches: watches))
    }

    private func structureChanged() {
        subscribe()
        revision += 1
    }
}
#endif
