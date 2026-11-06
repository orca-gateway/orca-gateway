#if canImport(SwiftUI)
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

/// One rendered page: its nodes, its store, and the effects its actions ask
/// for. Views resolve nodes through it and fire triggers into it.
@MainActor
public final class OrcaPageModel: ObservableObject {
    public let renderer: PageRenderer
    public let store: ElmStore
    public let reducer: ActionReducer
    /// The snackbar or toast showing now.
    @Published public var toast: OrcaToast?
    /// Effects the page does not handle itself (everything but snackbars and
    /// toasts until S3 adds navigation, system and server adapters).
    public var onEffect: ((ActionEffect) -> Void)?

    public init(page: PageResponse, store: ElmStore = ElmStore(),
                registry: WidgetRegistry = .shared, reducer: ActionReducer = ActionReducer()) {
        self.renderer = PageRenderer(page: page, registry: registry)
        self.store = store
        self.reducer = reducer
        store.seed(page.state)
    }

    public var page: PageResponse { renderer.page }

    public func resolve(_ id: String) -> ResolvedNode? {
        renderer.resolve(id, state: store.state)
    }

    public func watches(of id: String) -> [String] {
        renderer.node(id)?.watches ?? []
    }

    /// Run the node's action for a trigger (`onTap`, `onLongPress`, ...), the
    /// Flutter `fireAction`: nothing happens when the node has none.
    public func fire(_ trigger: String, on node: ResolvedNode, eventData: [String: JSONValue]? = nil) {
        guard let action = node.actions[trigger] else { return }
        let (next, effects) = reducer.reduce(store.state, action, eventData: eventData)
        store.commit(next)
        effects.forEach(perform)
    }

    func perform(_ effect: ActionEffect) {
        switch effect.type {
        case "showSnackbar", "showToast":
            toast = OrcaToast(
                message: effect.payload["message"]?.stringValue ?? "",
                duration: Double(effect.payload["duration"]?.intValue ?? 4000) / 1000,
                style: effect.type == "showSnackbar" ? .snackbar : .toast)
        default:
            onEffect?(effect)
        }
    }
}

/// Re-renders one node when a key it watches changes, the Flutter
/// `WatchBuilder`: other nodes of the page are left alone.
@MainActor
final class NodeObserver: ObservableObject {
    @Published private(set) var revision = 0
    private var subscription: ElmStore.Subscription?

    init(model: OrcaPageModel, id: String) {
        let watches = model.watches(of: id)
        guard !watches.isEmpty else { return }
        subscription = model.store.subscribe(watches) { [weak self] _ in
            self?.revision += 1
        }
    }
}
#endif
