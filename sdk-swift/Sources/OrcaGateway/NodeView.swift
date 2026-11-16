#if canImport(SwiftUI)
import SwiftUI

/// Draws one node of a page by id, and everything below it. Each node
/// observes only its own watched keys; the model itself is not observed here,
/// so a toast appearing does not redraw the page's nodes.
@MainActor
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

@MainActor
private struct WatchedNode: View {
    let id: String
    let model: OrcaPageModel
    @StateObject private var observer: NodeObserver
    /// Set by an enclosing AnimatedBuilder; redraws this node every frame.
    @Environment(\.orcaAnimationProgress) private var animationProgress
    /// Set by an enclosing AnimatedSwitcher: where this node is recorded
    /// each time it is drawn.
    @Environment(\.orcaNodeRecorder) private var recorder

    init(id: String, model: OrcaPageModel) {
        self.id = id
        self.model = model
        _observer = StateObject(wrappedValue: NodeObserver(model: model, id: id))
    }

    var body: some View {
        // Reading the revision ties this body to the node's watches.
        let _ = observer.revision
        if let node = model.resolve(id, animationProgress: animationProgress) {
            // What is on screen from now on. A frozen copy is a record
            // already.
            let _ = recorder?.record(node, drawnFrom: model)
            // Only a node with a lifecycle trigger is wrapped (Flutter
            // component_renderer.dart:230-255); the others keep their tree.
            if let triggers = LifecycleTriggers(node.actions) {
                WidgetView(node: node, model: model)
                    .modifier(Lifecycle(node: node, model: model, triggers: triggers))
            } else {
                WidgetView(node: node, model: model)
            }
        }
    }
}

extension NodeRecorder {
    /// `node` was resolved for drawing from `model`: recorded with the node
    /// as the page holds it. Nothing from a frozen copy, a record already.
    /// For the view that draws a node: NodeView, and a CustomScrollView for
    /// the slivers it flattens, which have no NodeView there.
    func record(_ node: ResolvedNode, drawnFrom model: OrcaPageModel) {
        guard !model.isInert, let source = model.renderer.node(node.id) else { return }
        record(node, source: source)
    }
}

/// Where the nodes drawn below this point are recorded as they are resolved
/// (`NodeRecorder`); nil, the default: nowhere.
private struct OrcaNodeRecorderKey: EnvironmentKey {
    static let defaultValue: NodeRecorder? = nil
}

extension EnvironmentValues {
    var orcaNodeRecorder: NodeRecorder? {
        get { self[OrcaNodeRecorderKey.self] }
        set { self[OrcaNodeRecorderKey.self] = newValue }
    }
}

/// The registry's builders: wire type to SwiftUI view. The types listed in
/// sdk-swift/capabilities.json, then the page model's `WidgetBuilders`;
/// anything else has already been degraded by the renderer.
@MainActor
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
        case "Align": AlignView(node: node, model: model)
        case "AspectRatio": AspectRatioView(node: node, model: model)
        case "Baseline": BaselineView(node: node, model: model)
        case "ConstrainedBox": ConstrainedBoxView(node: node, model: model)
        case "FittedBox": FittedBoxView(node: node, model: model)
        case "FractionallySizedBox": FractionallySizedBoxView(node: node, model: model)
        case "IntrinsicHeight": IntrinsicHeightView(node: node, model: model)
        case "IntrinsicWidth": IntrinsicWidthView(node: node, model: model)
        case "LimitedBox": LimitedBoxView(node: node, model: model)
        case "Offstage": OffstageView(node: node, model: model)
        case "SafeArea": SafeAreaView(node: node, model: model)
        case "Wrap": WrapView(node: node, model: model)
        case "Padding": PaddingView(node: node, model: model)
        case "SizedBox": SizedBoxView(node: node, model: model)
        case "SingleChildScrollView": scrolling(ScrollNodeView(node: node, model: model))
        case "ReorderableListView": ReorderableListNodeView(node: node, model: model)
        case "SubPage": SubPageNodeView(node: node, model: model)
        case "PageView": scrolling(PagerView(node: node, model: model))
        case "ListView": scrolling(ListNodeView(node: node, model: model))
        case "GridView": scrolling(GridNodeView(node: node, model: model))
        case "CustomScrollView": scrolling(CustomScrollNodeView(node: node, model: model))
        case "SliverAppBar": SliverAppBarView(node: node, model: model)
        case "SliverList": SliverListView(node: node, model: model)
        case "SliverGrid": SliverGridView(node: node, model: model)
        case "SliverToBoxAdapter": ChildView(node: node, model: model)
        case "Scrollbar": ScrollbarView(node: node, model: model)
        case "PullToRefresh": PullToRefreshView(node: node, model: model)
        case "Card": CardView(node: node, model: model)
        case "Text": TextNodeView(node: node)
        case "Divider": DividerView(node: node)
        case "ElevatedButton", "OutlinedButton", "TextButton": ButtonNodeView(node: node, model: model)
        case "FallbackPrompt": FallbackPromptView(node: node, model: model)
        case "UnsupportedWidgetPlaceholder": UnsupportedWidgetPlaceholderView(node: node, model: model)
        case "Icon": IconNodeView(node: node)
        case "Image": ImageNodeView(node: node)
        case "Container": ContainerView(node: node, model: model)
        case "Expanded": ExpandedView(node: node, model: model)
        case "Flexible": FlexibleView(node: node, model: model)
        case "Spacer": SpacerNodeView()
        case "TextField": TextFieldNodeView(node: node, model: model)
        case "Stack": StackNodeView(node: node, model: model)
        case "Positioned": PositionedView(node: node, model: model)
        case "ClipRRect": ClipRRectView(node: node, model: model)
        case "GestureDetector": GestureNodeView(node: node, model: model)
        case "AnimatedBuilder":
            // In a frozen copy (an AnimatedSwitcher's outgoing child) the
            // builder is its child as it last resolved: no controller, no
            // `animationId` registered, no frames.
            if model.isInert {
                ChildView(node: node, model: model)
            } else {
                AnimatedBuilderView(node: node, model: model)
            }
        case "Transform": TransformView(node: node, model: model)
        case "AnimatedContainer": AnimatedContainerView(node: node, model: model)
        case "AnimatedOpacity": AnimatedOpacityView(node: node, model: model)
        case "AnimatedAlign": AnimatedAlignView(node: node, model: model)
        case "AnimatedSwitcher": AnimatedSwitcherView(node: node, model: model)
        case "Hero": HeroView(node: node, model: model)
        case "Video": VideoNodeView(node: node)
        case "BottomNavigationBar": BottomNavigationBarView(node: node, model: model)
        case "BottomNavItem": BottomNavItemView(node: node)
        case "Drawer": DrawerView(node: node, model: model)
        case "BackdropFilter": BackdropFilterView(node: node, model: model)
        case "BlurView": BlurView(node: node, model: model)
        case "Opacity": OpacityView(node: node, model: model)
        case "RotatedBox": RotatedBoxView(node: node, model: model)
        case "ClipRect": ClipRectView(node: node, model: model)
        case "ClipOval": ClipOvalView(node: node, model: model)
        case "DecoratedBox": DecoratedBoxView(node: node, model: model)
        case "ColorFiltered": ColorFilteredView(node: node, model: model)
        case "AbsorbPointer": AbsorbPointerView(node: node, model: model)
        case "IgnorePointer": IgnorePointerView(node: node, model: model)
        case "InteractiveViewer": InteractiveViewerView(node: node, model: model)
        default:
            // A plugin or host widget; any other type draws nothing.
            if let build = model.widgets.builder(for: node.type) { build(node, model) } else { EmptyView() }
        }
    }

    /// A scroll kind with what it takes from a Scrollbar and a
    /// PullToRefresh it is directly inside.
    private func scrolling<V: View>(_ view: V) -> some View {
        view.modifier(ScrollIndicators()).modifier(RefreshOnPull(node: node))
    }
}

/// The first child, or nothing (Flutter `renderChild`).
@MainActor
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
