#if canImport(SwiftUI)
import SwiftUI

/// Draws one node of a page by id, and everything below it. Each node
/// observes only its own watched keys; the model itself is not observed here,
/// so a toast appearing does not redraw the page's nodes.
public struct NodeView: View {
    let id: String
    let model: OrcaPageModel

    public init(id: String, model: OrcaPageModel) {
        self.id = id
        self.model = model
    }

    public var body: some View {
        WatchedNode(id: id, model: model)
    }
}

private struct WatchedNode: View {
    let id: String
    let model: OrcaPageModel
    @StateObject private var observer: NodeObserver

    init(id: String, model: OrcaPageModel) {
        self.id = id
        self.model = model
        _observer = StateObject(wrappedValue: NodeObserver(model: model, id: id))
    }

    var body: some View {
        // Reading the revision ties this body to the node's watches.
        let _ = observer.revision
        if let node = model.resolve(id) {
            WidgetView(node: node, model: model)
        }
    }
}

/// The registry's builders: wire type to SwiftUI view. The 15 types listed in
/// sdk-swift/capabilities.json; anything else has already been degraded by
/// the renderer.
struct WidgetView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        switch node.type {
        case "Scaffold": ScaffoldView(node: node, model: model)
        case "AppBar": AppBarView(node: node, model: model)
        case "Column": FlexView(node: node, model: model, axis: .vertical)
        case "Row": FlexView(node: node, model: model, axis: .horizontal)
        case "Center": CenterView(node: node, model: model)
        case "Padding": PaddingView(node: node, model: model)
        case "SizedBox": SizedBoxView(node: node, model: model)
        case "SingleChildScrollView": ScrollNodeView(node: node, model: model)
        case "Card": CardView(node: node, model: model)
        case "Text": TextNodeView(node: node)
        case "Divider": DividerView(node: node)
        case "ElevatedButton", "OutlinedButton", "TextButton": ButtonNodeView(node: node, model: model)
        case "FallbackPrompt": FallbackPromptView(node: node)
        default: EmptyView()
        }
    }
}

/// The first child, or nothing (Flutter `renderChild`).
struct ChildView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        if let first = node.childIds.first {
            NodeView(id: first, model: model)
        }
    }
}
#endif
