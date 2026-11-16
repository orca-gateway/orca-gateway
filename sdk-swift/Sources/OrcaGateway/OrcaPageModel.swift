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

/// A node and everything below it, frozen as it was last drawn: what an
/// AnimatedSwitcher draws its outgoing child from once a replace or a delete
/// has taken that child off the page.
struct NodeSnapshot: Equatable {
    let rootId: String
    /// The subtree's nodes as they were drawn, by id.
    let nodes: [String: ResolvedNode]
    /// The same nodes as the page held them (what layout reads types from).
    let components: [ComponentNode]
    let state: StoreState
    /// The roots a SubPage of the subtree was drawing, by the SubPage's id.
    var subPageRoots: [String: [String]] = [:]
}

/// The resolved nodes last drawn below one point of a page, by id: what an
/// AnimatedSwitcher keeps of its child so it can still draw it, fading out,
/// once a server action has removed it from the page (Kotlin's
/// `OrcaNodeSnapshot`).
///
/// The view that draws a watched node hands it here each time it resolves
/// it (`orcaNodeRecorder`): a dictionary entry for a node already resolved
/// for drawing. Each recorder also tells its `parent`, so an outer
/// switcher's record includes what an inner one draws.
@MainActor
final class NodeRecorder {
    /// The recorder around the widget that owns this one, if any.
    weak var parent: NodeRecorder?
    private var nodes: [String: ResolvedNode] = [:]
    private var components: [String: ComponentNode] = [:]

    /// `node` was drawn; `source` is the same node as the page holds it.
    func record(_ node: ResolvedNode, source: ComponentNode) {
        nodes[node.id] = node
        components[node.id] = source
        parent?.record(node, source: source)
    }

    /// Forget everything: the widget that owns this one has a new child.
    func reset() {
        nodes.removeAll()
        components.removeAll()
    }

    /// The subtree under `root` as last drawn: the nodes reachable from it
    /// through children and slots, with `state` the page's at this moment.
    /// Nil when `root` was never drawn. A SubPage's mounted pages hang under
    /// no node: `subPages` (the page's) names their roots.
    func snapshot(of root: String, state: StoreState, subPages: SubPageRegistry = SubPageRegistry())
        -> NodeSnapshot? {
        var found: [String: ResolvedNode] = [:]
        var sources: [ComponentNode] = []
        var roots: [String: [String]] = [:]
        var pending = [root]
        while let id = pending.popLast() {
            guard found[id] == nil, let node = nodes[id], let source = components[id] else { continue }
            found[id] = node
            sources.append(source)
            pending += node.childIds
            pending += node.slots.values
            if let mounted = subPages[id]?.roots {
                roots[id] = mounted
                pending += mounted
            }
        }
        guard found[root] != nil else { return nil }
        return NodeSnapshot(rootId: root, nodes: found, components: sources, state: state, subPageRoots: roots)
    }
}

/// One rendered page: its nodes, its store, and the executor that runs its
/// actions. Views resolve nodes through it and fire triggers into it.
///
/// Snackbars and toasts are drawn by the page itself, and `animateForward` /
/// `animateReverse` run on its animation registry. Navigation and system
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
    /// The page's animation controllers by `animationId` (Flutter's
    /// AnimationRegistry): what `animateForward` / `animateReverse` reach and
    /// what a `tween` naming an id reads. An AnimatedBuilder registers here
    /// while it is on screen.
    let animations = AnimationRegistry()
    /// "Now" for the page's animations, in milliseconds: the time an effect
    /// starts a run at and a targeted tween is read at. Views pass their
    /// frame's date through `milliseconds(_:)`, the same scale; tests set it.
    var frameClock: () -> Double = { OrcaPageModel.milliseconds(Date()) }
    /// The id an effect has just started a run on. The registry has no change
    /// signal, so this is what wakes that id's paused builder.
    let animationChanged = PassthroughSubject<String, Never>()

    /// A frame date on the scale of `frameClock`.
    nonisolated static func milliseconds(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate * 1000
    }

    /// The pages mounted in this page's SubPages (their nodes are in
    /// `renderer`, their state in `store`, both under the pages' prefixes).
    public private(set) var subPages = SubPageRegistry()
    /// What each SubPage node drawn so far holds besides its pages, by node
    /// id, for as long as the node is in the page: what `updateSubPage`
    /// reaches, and what a view built again for the node takes up.
    private var subPageControllers: [String: SubPageController] = [:]
    /// On a frozen copy, the roots each SubPage was drawing.
    let frozenSubPageRoots: [String: [String]]

    /// The resolved nodes of a frozen copy (`init(snapshot:of:)`), nil on a
    /// live page.
    private let frozen: [String: ResolvedNode]?
    /// A frozen copy draws and nothing else: no action runs, no effect is
    /// performed, nothing reaches the server or the live page.
    var isInert: Bool { frozen != nil }

    public init(page: PageResponse, store: ElmStore = ElmStore(),
                registry: WidgetRegistry = .shared, client: OrcaClient? = nil,
                widgets: WidgetBuilders = WidgetBuilders()) {
        self.renderer = PageRenderer(page: page, registry: registry)
        self.store = store
        self.widgets = widgets
        self.frozen = nil
        self.frozenSubPageRoots = [:]
        self.executor = ActionExecutor(store: store, client: client)
        store.pageId = page.pageId
        store.seed(page.state)
        executor.onEffect = { [weak self] effect in self?.onEffect?(effect) }
        executor.perform = { [weak self] effect in self?.perform(effect) }
        executor.onMutation = { [weak self] mutation in self?.apply(mutation) }
        executor.subPagePrefixes = { [weak self] in self?.subPages.prefixes ?? [] }
        executor.onUpdateSubPage = { [weak self] subPageId, pageId, params, mode in
            try await self?.updateSubPage(subPageId, pageId: pageId, params: params, mode: mode)
        }
    }

    /// An inert page of `snapshot` alone, drawn by the same views as the
    /// live one: `resolve` answers from the snapshot, the store is a private
    /// copy of the state at that moment, and the executor is wired to
    /// nothing.
    init(snapshot: NodeSnapshot, of live: OrcaPageModel) {
        let page = PageResponse(pageId: live.page.pageId, title: live.page.title,
                                components: snapshot.components, extra: live.page.extra)
        self.renderer = PageRenderer(page: page, registry: live.renderer.registry)
        self.store = ElmStore(snapshot.state)
        self.widgets = live.widgets
        self.frozen = snapshot.nodes
        self.frozenSubPageRoots = snapshot.subPageRoots
        self.executor = ActionExecutor(store: store, client: nil)
        self.frameClock = live.frameClock
    }

    public var page: PageResponse { renderer.page }

    public func resolve(_ id: String) -> ResolvedNode? {
        resolve(id, animationProgress: nil)
    }

    /// Resolve under an AnimatedBuilder: `tween` props take `animationProgress`.
    /// A tween naming an `animationId` takes that controller's curved
    /// progress from the page's registry instead, 0 for an unknown id.
    public func resolve(_ id: String, animationProgress: Double?) -> ResolvedNode? {
        if let frozen { return frozen[id] }
        guard var node = renderer.resolve(id, state: store.state, animationProgress: animationProgress)
        else { return nil }
        // The renderer builds its resolver without the id lookup, so the
        // props holding a targeted tween are resolved again with it.
        let targeted = (renderer.node(id)?.props ?? [:]).filter { Self.namesAnimation($0.value) }
        guard !targeted.isEmpty else { return node }
        var resolver = store.state.resolver()
        resolver.animationProgress = animationProgress
        let now = frameClock()
        resolver.animationProgressFor = { [animations] in animations.progress(id: $0, at: now) }
        for (key, value) in targeted { node.props[key] = resolver.resolveDeep(value) }
        return node
    }

    /// Whether a prop holds a `tween` or `tweenSequence` naming an id.
    private static func namesAnimation(_ value: JSONValue) -> Bool {
        switch value {
        case .object(let map):
            if let type = map["type"]?.stringValue, type == "tween" || type == "tweenSequence",
               map["animationId"]?.stringValue != nil {
                return true
            }
            return map.values.contains(where: namesAnimation)
        case .array(let items):
            return items.contains(where: namesAnimation)
        default:
            return false
        }
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
        guard !isInert, let action = node.actions[trigger] else { return nil }
        let source = ActionSource(widgetId: node.id, trigger: trigger)
        // The Hero around the node, as it is now: what the first `navigate`
        // of this run flies from (`OrcaRouter.perform`).
        let hero = heroTag(enclosing: node.id).map { FiringHero(tag: $0, page: self) }
        return Task {
            await Self.$firingHero.withValue(hero) {
                await run(action, eventData: eventData, source: source)
            }
        }
    }

    /// The Hero around the widget whose trigger the current task runs
    /// (`fire`); nil outside such a run and outside a Hero with a tag.
    @TaskLocal static var firingHero: FiringHero?

    /// The tag of the nearest Hero above node `id`: nil when there is none,
    /// and when the nearest one has no tag or an empty one.
    func heroTag(enclosing id: String) -> String? {
        var seen: Set<String> = [id]
        var current = id
        while let parent = renderer.parentOf(current), seen.insert(parent).inserted {
            if renderer.node(parent)?.type == "Hero" { return resolve(parent).flatMap(HeroView.tag(of:)) }
            current = parent
        }
        return nil
    }

    /// Run one action to the end; `source` is the widget and trigger that
    /// fired it, when there is one.
    public func run(_ action: Action, eventData: [String: JSONValue]? = nil,
                    source: ActionSource? = nil) async {
        guard !isInert else { return }
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
        guard !isInert, stateKey != nil || onChange != nil else { return nil }
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
        guard !isInert, let url = OrcaURLPolicy.standard.url(raw) else { return }
        if let effectHandler {
            effectHandler(ActionEffect("openUrl", ["url": .string(url.absoluteString)]))
        } else {
            fallback(url)
        }
    }

    func perform(_ effect: ActionEffect) {
        guard !isInert else { return }
        switch effect.type {
        case "showSnackbar", "showToast":
            toast = OrcaToast(
                message: effect.payload["message"]?.stringValue ?? "",
                duration: Double(effect.payload["duration"]?.intValue ?? 4000) / 1000,
                style: effect.type == "showSnackbar" ? .snackbar : .toast)
        case "animateForward", "animateReverse":
            // Flutter: a missing or unknown id does nothing, no error.
            guard let id = effect.payload["animationId"]?.stringValue else { return }
            let now = frameClock()
            let known = effect.type == "animateForward"
                ? animations.forward(id: id, at: now) : animations.reverse(id: id, at: now)
            if known { animationChanged.send(id) }
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
        guard !isInert else { return }
        renderer.apply(mutation)
        // S8: a SubPage node the mutation took out takes its pages with it.
        sweepSubPages()
        structureRevision += 1
    }
}

// MARK: - Sub-pages

/// A SubPage cannot fetch: the page was built without a client.
struct SubPageWithoutClient: LocalizedError {
    var errorDescription: String? { "SubPage requires a page with a client" }
}

extension OrcaPageModel {
    /// The controller of the SubPage node `key`: nil when the node was never
    /// drawn or is no longer in the page.
    func subPageView(_ key: String) -> SubPageController? {
        renderer.nodes[key] == nil ? nil : subPageControllers[key]
    }

    /// The controller of the SubPage node `key`, made the first time the
    /// node is drawn. It lives as long as the node, not as long as a view:
    /// every view of the node shares it.
    func subPage(_ key: String) -> SubPageController {
        if let known = subPageControllers[key] { return known }
        let made = SubPageController(key: key, model: self)
        subPageControllers[key] = made
        return made
    }

    /// Contract S8: every SubPage whose node is no longer in the store is
    /// forgotten, its fetch cancelled, and the nodes of its pages leave the
    /// store (a SubPage among them goes the same way). Its state keys stay.
    private func sweepSubPages() {
        while let key = subPageControllers.keys.first(where: { renderer.nodes[$0] == nil }) {
            subPageControllers.removeValue(forKey: key)?.cancel()
            renderer.removePages(under: subPages.unmount(key))
        }
    }

    /// The fetch of a sub-page (contract S4): the normal page route, with
    /// the app state posted as on any page fetch.
    func fetchSubPage(_ request: SubPageRequest) async throws -> PageResponse {
        guard let client = executor.client else { throw SubPageWithoutClient() }
        return try await client.fetchPage(request.location, appState: store.state.app)
    }

    /// Mounts a fetched page in the SubPage `key` through the core's
    /// reducer, and applies the change: nodes and state keys out, nodes and
    /// seeds in. Gives the prefix the page was mounted under; nil on a
    /// frozen copy, where nothing is mounted.
    @discardableResult
    func mountSubPage(_ key: String, mode: String, page: PageResponse) throws -> String? {
        guard !isInert else { return nil }
        var next = subPages
        let change = next.mount(
            key, mode: mode, response: try JSONValue(encoding: page), pageStateKeys: store.state.page.keys)
        // A SubPage of a page that leaves goes with it, even when the new
        // page has a node of the same id: that one starts anew.
        var without = renderer
        without.removePages(under: change.removedPrefixes)
        let gone = subPageControllers.keys.filter { without.nodes[$0] == nil }
        try renderer.apply(change)
        subPages = next
        for key in gone { subPageControllers.removeValue(forKey: key)?.cancel() }
        store.commit(store.state.applying(change))
        structureRevision += 1
        return change.prefix
    }

    /// The `updateSubPage` action (contract S7). A `subPageId` that names no
    /// SubPage of the page (or one never drawn) does nothing; a fetch that fails throws to the
    /// action chain.
    func updateSubPage(_ subPageId: String, pageId: String, params: [String: JSONValue]?, mode: String)
        async throws {
        guard !isInert, let view = subPageView(subPageId) else { return }
        try await view.update(SubPage.request(pageId: pageId, params: params), mode: mode)
    }
}

/// The Hero around the widget that fired one run of actions. Its tag is for
/// the run's first `navigate` alone: a later one leaves from a page that
/// does not hold that Hero.
@MainActor
final class FiringHero {
    private let tag: String
    /// The page the widget is on.
    private(set) weak var page: OrcaPageModel?
    private var taken = false

    init(tag: String, page: OrcaPageModel) {
        self.tag = tag
        self.page = page
    }

    /// The tag, the first time it is asked for; nil ever after.
    func take() -> String? {
        guard !taken else { return nil }
        taken = true
        return tag
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
