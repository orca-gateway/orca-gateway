#if canImport(SwiftUI)
import SwiftUI

/// The lifecycle triggers a node carries, which any widget may (Flutter
/// component_renderer.dart:230-255). Nil for a node with none, which is
/// drawn without the wrapper, so its view tree stays as it was.
struct LifecycleTriggers: Equatable {
    var onInit: Bool
    var onVisible: Bool
    /// onAppBackground wins over onBackground when both are set; the name set is the trigger fired.
    var background: String?
    /// onAppForeground wins over onForeground when both are set; the name set is the trigger fired.
    var foreground: String?

    init?(_ actions: [String: Action]) {
        onInit = actions["onInit"] != nil
        onVisible = actions["onVisible"] != nil
        background = ["onAppBackground", "onBackground"].first { actions[$0] != nil }
        foreground = ["onAppForeground", "onForeground"].first { actions[$0] != nil }
        guard onInit || onVisible || background != nil || foreground != nil else { return nil }
    }
}

/// Fires a node's lifecycle triggers, the Flutter `OrcaLifecycleWrapper`
/// (sdk/lib/src/widgets/lifecycle_wrapper.dart).
struct Lifecycle: ViewModifier {
    let node: ResolvedNode
    let model: OrcaPageModel
    let triggers: LifecycleTriggers
    @Environment(\.scenePhase) private var scenePhase
    /// Set on the first appearance; kept while the node stays mounted.
    @State private var appeared = false
    /// Set by a `.background`, cleared by the `.active` that follows it.
    @State private var backgrounded = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                // onInit, then onVisible, once per mount: a redraw or a page popped back over the node does not fire them again.
                // onVisible is Flutter's: once on mount, not viewport visibility (action.ts "CURRENT BEHAVIOR").
                // Each runs in the model's task, after this appearance, as Flutter's post-frame callback.
                guard !appeared else { return }
                appeared = true
                if triggers.onInit { model.fire("onInit", on: node) }
                if triggers.onVisible { model.fire("onVisible", on: node) }
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                // .background fires the background trigger (Flutter `paused`).
                case .background:
                    backgrounded = true
                    if let trigger = triggers.background { model.fire(trigger, on: node) }
                // .active fires the foreground trigger only after a .background: none on the first appearance.
                case .active where backgrounded:
                    backgrounded = false
                    if let trigger = triggers.foreground { model.fire(trigger, on: node) }
                // .inactive (and .active without a .background before it) fires nothing.
                default:
                    break
                }
            }
    }
}
#endif
