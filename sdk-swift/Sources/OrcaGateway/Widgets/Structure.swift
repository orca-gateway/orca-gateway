#if canImport(SwiftUI)
import SwiftUI

/// Scaffold: `body` fills the screen; an `appBar` slot holding an AppBar
/// becomes the navigation bar of the enclosing NavigationStack (title
/// centred, leading item, `action_N` items on the trailing side);
/// `floatingActionButton` floats bottom-trailing; `bottomNavigationBar` and
/// `persistentFooterButton_N` sit above the bottom safe area. Drawers and
/// bottom sheets are not drawn yet.
@MainActor
struct ScaffoldView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let appBar = node.slots["appBar"].flatMap(model.resolve)
        ZStack(alignment: .bottomTrailing) {
            if let background = Props.color(node["backgroundColor"]) {
                background.ignoresSafeArea()
            }
            Group {
                if let body = node.slots["body"] {
                    NodeView(id: body, model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let fab = node.slots["floatingActionButton"] {
                NodeView(id: fab, model: model).padding(16)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBars }
        .modifier(AppBarChrome(appBar: appBar, model: model))
        // Flutter's Scaffold lays out its slots with fresh, loose
        // constraints, so an axis forced on the Scaffold (the warn banner's
        // stretched Column) reaches neither the AppBar title nor the body.
        .environment(\.orcaTight, [])
    }

    @ViewBuilder
    private var bottomBars: some View {
        let footer = indexedSlots(node, "persistentFooterButton")
        if !footer.isEmpty || node.slots["bottomNavigationBar"] != nil {
            VStack(spacing: 0) {
                if !footer.isEmpty {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        ForEach(footer, id: \.self) { NodeView(id: $0, model: model) }
                    }
                    .padding(8)
                }
                if let bar = node.slots["bottomNavigationBar"] {
                    NodeView(id: bar, model: model)
                }
            }
        }
    }
}

/// `name_0`, `name_1`, ... slot ids in order, stopping at the first gap (the
/// Flutter builders read indexed slots this way).
func indexedSlots(_ node: ResolvedNode, _ name: String) -> [String] {
    var ids: [String] = []
    while let id = node.slots["\(name)_\(ids.count)"] { ids.append(id) }
    return ids
}

/// Puts a Scaffold's AppBar into the navigation bar. A slot that is not an
/// AppBar is drawn above the body instead.
@MainActor
private struct AppBarChrome: ViewModifier {
    let appBar: ResolvedNode?
    let model: OrcaPageModel

    func body(content: Content) -> some View {
        if let appBar, appBar.type == "AppBar" {
            let actions = indexedSlots(appBar, "action")
            let background = Props.color(appBar["backgroundColor"])
            content
                .navigationTitle(plainTitle(appBar))
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        if let title = appBar.slots["title"] {
                            // A title without its own style gets the bar's font.
                            NodeView(id: title, model: model).font(.headline)
                        }
                    }
                    #if os(iOS)
                    if let leading = appBar.slots["leading"] {
                        ToolbarItem(placement: .navigationBarLeading) {
                            NodeView(id: leading, model: model)
                        }
                    }
                    if !actions.isEmpty {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            ForEach(actions, id: \.self) { NodeView(id: $0, model: model) }
                        }
                    }
                    #endif
                }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(background ?? Color.clear, for: .navigationBar)
                .toolbarBackground(background == nil ? .automatic : .visible, for: .navigationBar)
                #endif
        } else if let appBar {
            content.safeAreaInset(edge: .top, spacing: 0) {
                WidgetView(node: appBar, model: model)
            }
        } else {
            content
        }
    }

    /// The title as plain text, for the back button and accessibility.
    private func plainTitle(_ appBar: ResolvedNode) -> String {
        guard let id = appBar.slots["title"], let title = model.resolve(id), title.type == "Text" else {
            return model.page.title
        }
        return Props.text(title["data"])
    }
}

/// An AppBar outside a Scaffold's appBar slot: a bar with the title centred.
@MainActor
struct AppBarView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ZStack {
            if let title = node.slots["title"] {
                NodeView(id: title, model: model).font(.headline)
            }
            HStack(spacing: 8) {
                if let leading = node.slots["leading"] {
                    NodeView(id: leading, model: model)
                }
                Spacer(minLength: 0)
                ForEach(indexedSlots(node, "action"), id: \.self) { NodeView(id: $0, model: model) }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: Props.number(node["toolbarHeight"]) ?? 44)
        .background(Props.color(node["backgroundColor"]))
    }
}

/// Card: rounded surface with a shadow from `elevation` (default 1), inner
/// `padding`, outer `margin` (default 4, the Material default).
@MainActor
struct CardView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let elevation = Props.number(node["elevation"]) ?? 1
        let radius = Props.number(node["borderRadius"]) ?? 12
        ChildView(node: node, model: model)
            .padding(Props.insets(node["padding"]) ?? EdgeInsets())
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Props.color(node["color"]) ?? Color.white)
                    .shadow(
                        color: Props.color(node["shadowColor"]) ?? Color.black.opacity(0.18),
                        radius: elevation, x: 0, y: elevation / 2))
            .padding(Props.insets(node["margin"]) ?? EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }
}
#endif
