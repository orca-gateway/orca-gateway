#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Scaffold: `body` fills the screen; an `appBar` slot holding an AppBar
/// becomes the navigation bar of the enclosing NavigationStack (see
/// AppBarChrome: title, leading item, `action_N` items on the trailing side);
/// `floatingActionButton` floats bottom-trailing; `bottomNavigationBar` and
/// `persistentFooterButton_N` sit above the bottom safe area. The `drawer`
/// slot is a panel at the leading edge and `endDrawer` one at the trailing
/// edge, shown by the app's drawer host over everything (`ScaffoldDrawers`):
/// a drag from the screen edge opens one (the leading edge only on the first
/// page of a stack, where no back swipe takes it), the `openDrawer` action
/// the leading one, and an AppBar with no leading widget (no actions) gets a
/// menu button for it, as Flutter's AppBar does. The bars take their insets
/// from the body (Flutter removes them from its MediaQuery padding,
/// scaffold.dart :3027-3031): a SafeArea in it neither adds them nor lets its
/// content under the bars. Bottom sheets are not drawn yet.
@MainActor
struct ScaffoldView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaDrawerHost) private var drawerHost
    @Environment(\.orcaPage) private var page
    @Environment(\.orcaSafeAreaTaken) private var taken

    var body: some View {
        // The appBar slot has no NodeView: this is its build.
        let appBar = node.slots["appBar"].flatMap { model.resolve($0, animationProgress: nil) }
        let drawers = ScaffoldDrawers(node: node, model: model, host: drawerHost,
                                      router: page?.router, route: page?.route.id)
        ZStack(alignment: .bottomTrailing) {
            if let background = Props.color(node["backgroundColor"]) {
                background.ignoresSafeArea()
            }
            Group {
                if let body = node.slots["body"] {
                    NodeView(id: body, model: model)
                }
            }
            .environment(\.orcaSafeAreaTaken, taken.union(barEdges(appBar: appBar != nil)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let fab = node.slots["floatingActionButton"] {
                NodeView(id: fab, model: model).padding(16)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBars }
        .overlay(alignment: .leading) {
            if drawers.hosts(.leading), page?.isStackRoot ?? true {
                DrawerEdgeGrip(edge: .leading) { drawers.open(.leading) }
            }
        }
        .overlay(alignment: .trailing) {
            if drawers.hosts(.trailing) {
                DrawerEdgeGrip(edge: .trailing) { drawers.open(.trailing) }
            }
        }
        .background {
            if let router = page?.router {
                PageDrawerRequests(router: router, drawers: drawers)
            }
        }
        .onDisappear {
            drawers.close(.leading)
            drawers.close(.trailing)
        }
        .preference(key: PageChromeKey.self, value: PageChrome(
            hasBar: appBar?.type == "AppBar",
            hasLeadingItem: appBar?.type == "AppBar"
                && (appBar?.slots["leading"] != nil || drawers.showsMenu(.leading)),
            hasLeadingDrawer: drawers.hosts(.leading)))
        .modifier(AppBarChrome(appBar: appBar, model: model, drawers: drawers))
        // Flutter's Scaffold lays out its slots with fresh, loose
        // constraints, so an axis forced on the Scaffold (the warn banner's
        // stretched Column) reaches neither the AppBar title nor the body.
        .environment(\.orcaTight, [])
    }

    /// The top edge under an appBar, the bottom one above bottom bars.
    private func barEdges(appBar: Bool) -> Edge.Set {
        var edges: Edge.Set = []
        if appBar { edges.insert(.top) }
        if hasBottomBars { edges.insert(.bottom) }
        return edges
    }

    private var hasBottomBars: Bool {
        !indexedSlots(node, "persistentFooterButton").isEmpty || node.slots["bottomNavigationBar"] != nil
    }

    @ViewBuilder
    private var bottomBars: some View {
        let footer = indexedSlots(node, "persistentFooterButton")
        if hasBottomBars {
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
            .bottomBarBacking(Props.color(node["backgroundColor"]) ?? systemBackground)
        }
    }
}

/// A Scaffold's `drawer` and `endDrawer` slots without their drawing: which
/// it has, the panel each presents on the app's drawer host, and what opens
/// and closes them, so a test can run them without a touch.
@MainActor
struct ScaffoldDrawers {
    let node: ResolvedNode
    let model: OrcaPageModel
    /// The app's drawer host; nil for a page drawn outside `OrcaApp`, where
    /// no drawer opens.
    let host: DrawerHost?
    let router: OrcaRouter?
    /// The route this page is drawn for: the id `pageDrawerRequest` names.
    let route: OrcaRoute.ID?

    /// The node in the `drawer` slot (leading) or the `endDrawer` slot.
    func slot(_ edge: DrawerEdge) -> String? {
        node.slots[edge == .leading ? "drawer" : "endDrawer"]
    }

    /// The Scaffold has a drawer at that edge and a host to show it.
    func hosts(_ edge: DrawerEdge) -> Bool {
        host != nil && slot(edge) != nil
    }

    /// The id of that drawer's panel on the host.
    func panelId(_ edge: DrawerEdge) -> String {
        "\(ObjectIdentifier(model).hashValue)/\(node.id)/\(edge == .leading ? "drawer" : "endDrawer")"
    }

    func isOpen(_ edge: DrawerEdge) -> Bool {
        host?.open?.id == panelId(edge)
    }

    /// Show that drawer: the slot's node, normally a `Drawer`, which gives
    /// the panel its width and colour.
    func open(_ edge: DrawerEdge) {
        guard let host, let id = slot(edge) else { return }
        let model = self.model
        host.present(id: panelId(edge), edge: edge) { AnyView(NodeView(id: id, model: model)) }
    }

    func close(_ edge: DrawerEdge) {
        host?.remove(panelId(edge))
    }

    /// `openDrawer` asked this page for its drawer (`pageDrawerRequest`
    /// names its route): clear the request and open the leading drawer. A
    /// Scaffold with none clears the request and opens nothing.
    func answerRequest() {
        guard let router, let route, router.pageDrawerRequest == route else { return }
        router.pageDrawerRequest = nil
        open(.leading)
    }

    /// The AppBar gets a menu button for that drawer: it is the navigation
    /// bar and has no leading widget (for the end drawer: no actions).
    func showsMenu(_ edge: DrawerEdge) -> Bool {
        guard hosts(edge), let appBar = node.slots["appBar"].flatMap(model.resolve),
              appBar.type == "AppBar" else { return false }
        return edge == .leading ? appBar.slots["leading"] == nil : indexedSlots(appBar, "action").isEmpty
    }
}

/// Opens a Scaffold's drawer when the router asks its page for one. Only
/// this view follows the router, so a route change redraws no Scaffold.
@MainActor
private struct PageDrawerRequests: View {
    @ObservedObject var router: OrcaRouter
    let drawers: ScaffoldDrawers

    var body: some View {
        Color.clear
            .onAppear { drawers.answerRequest() }
            .onChange(of: router.pageDrawerRequest) { _ in drawers.answerRequest() }
    }
}

/// `name_0`, `name_1`, ... slot ids in order, stopping at the first gap (the
/// Flutter builders read indexed slots this way).
func indexedSlots(_ node: ResolvedNode, _ name: String) -> [String] {
    var ids: [String] = []
    while let id = node.slots["\(name)_\(ids.count)"] { ids.append(id) }
    return ids
}

/// Puts a Scaffold's AppBar into the navigation bar (Flutter `_buildAppBar`,
/// SB:85-120, M3). The title is centred, or with `centerTitle` false a
/// leading item (after the back button) with a blank principal item, so the
/// plain `navigationTitle` (kept for the next page's back button and
/// VoiceOver) is not centred as well. A `leading` slot replaces the back
/// button, `leadingWidth` sizes it (UIKit's bar margin stands in for
/// Flutter's default 56 box), and `automaticallyImplyLeading` false hides
/// the back button (SwiftUI then also turns off the swipe back, which
/// Flutter keeps). `elevation` with a
/// `shadowColor` draws `AppBarShadow` at the top of the content, under the
/// bar: SwiftUI has no navigation-bar shadow, and a global
/// UINavigationBarAppearance would leak to other screens. Where the AppBar
/// left the place free (no leading widget; for the end drawer no actions) a
/// drawer gets a menu button, before a title that is not centred. A slot
/// that is not an AppBar is drawn above the body instead.
@MainActor
private struct AppBarChrome: ViewModifier {
    let appBar: ResolvedNode?
    let model: OrcaPageModel
    let drawers: ScaffoldDrawers

    func body(content: Content) -> some View {
        if let appBar, appBar.type == "AppBar" {
            let actions = indexedSlots(appBar, "action")
            let background = Props.color(appBar["backgroundColor"])
            content
                .overlay(alignment: .top) { AppBarShadow(appBar: appBar) }
                .navigationTitle(plainTitle(appBar))
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        if centresTitle(appBar) {
                            title(appBar)
                        } else {
                            // An empty item is dropped and the plain title centred instead.
                            Color.clear.frame(width: 0, height: 0)
                        }
                    }
                    #if os(iOS)
                    if appBar.slots["leading"] != nil || !centresTitle(appBar) {
                        ToolbarItem(placement: .navigationBarLeading) {
                            HStack(spacing: 16) {
                                if let leading = appBar.slots["leading"] {
                                    NodeView(id: leading, model: model)
                                        .frame(width: Props.number(appBar["leadingWidth"]))
                                } else if drawers.showsMenu(.leading) {
                                    DrawerMenuButton { drawers.open(.leading) }
                                }
                                if !centresTitle(appBar) { title(appBar) }
                            }
                        }
                    } else if drawers.showsMenu(.leading) {
                        ToolbarItem(placement: .navigationBarLeading) {
                            DrawerMenuButton { drawers.open(.leading) }
                        }
                    }
                    if !actions.isEmpty {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            ForEach(actions, id: \.self) { NodeView(id: $0, model: model) }
                        }
                    } else if drawers.showsMenu(.trailing) {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            DrawerMenuButton { drawers.open(.trailing) }
                        }
                    }
                    #endif
                }
                #if os(iOS)
                .navigationBarBackButtonHidden(
                    appBar.slots["leading"] != nil || Props.bool(appBar["automaticallyImplyLeading"]) == false)
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

    /// Centred unless `centerTitle` is false (Flutter on iOS centres with
    /// fewer than two actions). The leading placement is iOS-only, so macOS
    /// always centres.
    private func centresTitle(_ appBar: ResolvedNode) -> Bool {
        #if os(iOS)
        return Props.bool(appBar["centerTitle"]) != false
        #else
        return true
        #endif
    }

    @ViewBuilder
    private func title(_ appBar: ResolvedNode) -> some View {
        if let title = appBar.slots["title"] {
            // A title without its own style gets the bar's font.
            NodeView(id: title, model: model).font(.headline)
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

/// An AppBar outside a Scaffold's appBar slot, laid out as Flutter's
/// NavigationToolbar: `toolbarHeight` high (default 56); the leading slot a
/// box `leadingWidth` wide (default 56) at the leading edge, as high as the
/// bar, its size forced as Flutter's tight constraints force it; the title
/// centred, or with `centerTitle` false 16 after the leading box (16 in
/// without one); actions at the trailing edge. `elevation` with a
/// `shadowColor` draws `AppBarShadow` under the bar.
@MainActor
struct AppBarView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let centred = Props.bool(node["centerTitle"]) != false
        ZStack {
            if centred, let title = node.slots["title"] {
                NodeView(id: title, model: model).font(.headline).padding(.horizontal, 16)
            }
            HStack(spacing: 0) {
                if let leading = node.slots["leading"] {
                    NodeView(id: leading, model: model)
                        .environment(\.orcaTight, [.horizontal, .vertical])
                        .frame(width: Props.number(node["leadingWidth"]) ?? 56)
                }
                if !centred, let title = node.slots["title"] {
                    NodeView(id: title, model: model).font(.headline).padding(.leading, 16)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    ForEach(indexedSlots(node, "action"), id: \.self) { NodeView(id: $0, model: model) }
                }
                .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Props.number(node["toolbarHeight"]) ?? 56)
        .background(Props.color(node["backgroundColor"]))
        .overlay(alignment: .bottom) {
            AppBarShadow(appBar: node).alignmentGuide(.bottom) { $0[.top] }
        }
    }
}

/// An AppBar's elevation shadow, drawn below the edge it is aligned to: a
/// strip `elevation` points tall fading from `shadowColor` at 25% (Skia's
/// spot-shadow alpha, which Flutter's Material shadow uses) to clear.
/// Flutter's M3 AppBar has elevation 0 and a transparent shadowColor by
/// default, so nothing is drawn unless both are sent. It never takes taps.
private struct AppBarShadow: View {
    let appBar: ResolvedNode

    var body: some View {
        let elevation = Props.number(appBar["elevation"]) ?? 0
        if elevation > 0, let color = Props.color(appBar["shadowColor"]) {
            LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: elevation)
                .allowsHitTesting(false)
        }
    }
}

/// Card (Flutter `_buildCard`, SB:122-160, M3): rounded surface (radius
/// default 12) with a shadow from `elevation` (default 1), inner `padding`,
/// outer `margin` (default 4), both absolute (D4). `surfaceTintColor` is laid
/// over the colour (default white) with the M3 opacity for the elevation
/// (`surfaceTintOpacity`); `clipBehavior`, when sent, clips the child to the
/// card's shape, not the shadow.
@MainActor
struct CardView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let elevation = Props.number(node["elevation"]) ?? 1
        let radius = Props.number(node["borderRadius"]) ?? 12
        let shape = CornersShape(radii: CornerRadii(all: radius))
        ChildView(node: node, model: model)
            .orcaPadding(node["padding"])
            .modifier(ClipIf(shape: Props.clips(node["clipBehavior"]) ? shape : nil))
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Props.color(node["color"]) ?? Color.white)
                    .shadow(
                        color: Props.color(node["shadowColor"]) ?? Color.black.opacity(0.18),
                        radius: elevation, x: 0, y: elevation / 2)
                    // After the shadow, which would otherwise shade the tint too.
                    .overlay {
                        if let tint = Self.tint(node["surfaceTintColor"]) {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(tint.opacity(Self.surfaceTintOpacity(elevation)))
                        }
                    })
            .orcaPadding(node["margin"], fallback: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }

    /// The tint as Flutter's `withOpacity` uses it: the colour's own alpha is
    /// replaced, so it is read opaque. Transparent (`#00000000`) is no tint.
    static func tint(_ value: JSONValue?) -> Color? {
        guard let hex = value?.stringValue, Props.color(value) != nil, hex.uppercased() != "#00000000" else {
            return nil
        }
        return Props.color(.string(String(hex.prefix(7))))
    }

    /// Flutter `ElevationOverlay.applySurfaceTint`'s opacity: the M3 table,
    /// linear between its entries, clamped at both ends.
    static func surfaceTintOpacity(_ elevation: CGFloat) -> Double {
        let table: [(elevation: CGFloat, opacity: Double)] = [
            (0, 0), (1, 0.05), (3, 0.08), (6, 0.11), (8, 0.12), (12, 0.14),
        ]
        guard elevation > 0 else { return 0 }
        for (lower, upper) in zip(table, table.dropFirst()) where elevation <= upper.elevation {
            let t = Double((elevation - lower.elevation) / (upper.elevation - lower.elevation))
            return lower.opacity + t * (upper.opacity - lower.opacity)
        }
        return 0.14
    }
}
/// Flutter `BottomNavigationBar` (`_buildBottomNavigationBar`) without its
/// drawing: the items, the selected index and what a tap does, so a test can
/// run a tap without a touch.
@MainActor
struct BottomNavBar {
    /// One `BottomNavItem` node. Its props are read raw, not resolved, as
    /// the Flutter builder reads `itemNode.props`.
    struct Item: Equatable, Identifiable {
        let id: String
        let icon: String?
        let activeIcon: String?
        let label: String

        /// The Material icon name to draw: `activeIcon` on the selected item
        /// when it has one.
        func iconName(selected: Bool) -> String? {
            selected ? activeIcon ?? icon : icon
        }
    }

    let node: ResolvedNode
    let model: OrcaPageModel

    /// The nodes named by `item_0` ... `item_9`, in order, stopping at the
    /// first slot that is absent or names no node (Flutter breaks there too).
    var items: [Item] {
        var items: [Item] = []
        for id in indexedSlots(node, "item").prefix(10) {
            guard let props = model.renderer.nodes[id]?.props else { break }
            items.append(Item(id: id, icon: props["icon"]?.stringValue,
                              activeIcon: props["activeIcon"]?.stringValue,
                              label: props["label"]?.stringValue ?? ""))
        }
        return items
    }

    /// The resolved `currentIndex` (default 0), kept inside the items.
    var currentIndex: Int {
        min(max(node["currentIndex"]?.dartInt ?? 0, 0), max(items.count - 1, 0))
    }

    /// A tap on item `index`, in Flutter's order: when the raw `currentIndex`
    /// prop is a state Value, write the index into that key (app scope into
    /// app state, anything else into page state); then fire `onChange` with
    /// `eventData: {value: index}`. The returned task is the `onChange` run,
    /// nil when the node has none.
    @discardableResult
    func select(_ index: Int) -> Task<Void, Never>? {
        if case .object(let raw)? = model.renderer.nodes[node.id]?.props["currentIndex"],
           raw["type"]?.stringValue == "state", let key = raw["key"]?.stringValue {
            model.store.dispatch([key: .int(index)],
                                 scope: raw["scope"]?.stringValue == "app" ? .app : .page)
        }
        return model.fire("onChange", on: node, eventData: ["value": .int(index)])
    }
}

/// BottomNavigationBar drawn as an iOS tab bar: equal-width items, icon over
/// label, the selected one in `selectedItemColor` (default the accent
/// colour), the others in `unselectedItemColor` (default grey), on
/// `backgroundColor` (default the system background). No items draws nothing.
@MainActor
struct BottomNavigationBarView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let bar = BottomNavBar(node: node, model: model)
        let items = bar.items
        if !items.isEmpty {
            let current = bar.currentIndex
            let selectedColor = Props.color(node["selectedItemColor"]) ?? Color.accentColor
            let unselectedColor = Props.color(node["unselectedItemColor"]) ?? Props.color(hex: "#8E8E93")
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let selected = index == current
                    Button {
                        bar.select(index)
                    } label: {
                        VStack(spacing: 2) {
                            NavIcon(name: item.iconName(selected: selected), size: 24)
                            if !item.label.isEmpty {
                                Text(item.label).font(.system(size: 10, weight: .medium)).lineLimit(1)
                            }
                        }
                        .foregroundColor(selected ? selectedColor : unselectedColor)
                        .frame(maxWidth: .infinity, minHeight: 49)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(item.label)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .frame(maxWidth: .infinity)
            .background((Props.color(node["backgroundColor"]) ?? systemBackground)
                .ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) {
                Rectangle().fill(Color.black.opacity(0.12)).frame(height: 0.5)
            }
        }
    }
}

/// A BottomNavItem outside a bar (Flutter `_buildBottomNavItem`): its icon,
/// then its label when it has one.
@MainActor
struct BottomNavItemView: View {
    let node: ResolvedNode

    var body: some View {
        let label = node["label"]?.stringValue ?? ""
        HStack(spacing: 4) {
            NavIcon(name: node["icon"]?.stringValue, size: 24)
            if !label.isEmpty { Text(label) }
        }
    }
}

/// A Material icon name as its SF Symbol in a `size` box, as `IconNodeView`.
private struct NavIcon: View {
    let name: String?
    let size: CGFloat

    var body: some View {
        Image(systemName: IconNames.symbol(for: name))
            .font(.system(size: size * 0.83))
            .rotationEffect(.degrees(IconNames.isRotated(name) ? 90 : 0))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Flutter `Drawer`, the panel only: its child on `backgroundColor` (default
/// the system background), `width` wide (default 304, never wider than the
/// space there is) and as tall as its parent, with `elevation` (default 1,
/// Material 3) as a shadow. No child draws the empty panel. Sliding it in
/// from the side is the drawer host's work (`DrawerPanel`); met as an
/// ordinary child it draws in place.
@MainActor
struct DrawerView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let elevation = Props.number(node["elevation"]) ?? 1
        ZStack(alignment: .topLeading) {
            Color.clear
            ChildView(node: node, model: model)
        }
        .frame(maxWidth: Props.number(node["width"]) ?? drawerDefaultWidth, maxHeight: .infinity, alignment: .topLeading)
        // The Material Drawer forces its own size on its child.
        .environment(\.orcaTight, [.horizontal, .vertical])
        // As a panel at a screen edge its surface runs under the status bar
        // and the home indicator; its child stays inside the safe area.
        .background(
            Rectangle()
                .fill(Props.color(node["backgroundColor"]) ?? systemBackground)
                .shadow(color: Color.black.opacity(elevation > 0 ? 0.18 : 0), radius: elevation, x: 0, y: 0)
                .ignoresSafeArea())
    }
}

/// The platform's background colour, light or dark.
var systemBackground: Color {
    #if canImport(UIKit)
    Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
    Color(NSColor.windowBackgroundColor)
    #else
    Color.white
    #endif
}

extension View {
    /// The backing of a bar set in the bottom safe-area inset (the shell's
    /// server tab bar, a Scaffold's bottom bars): a fill behind the bar that
    /// runs down through the bottom safe area, so no page content scrolling
    /// under the inset shows in the home-indicator strip. Only the fill
    /// leaves the safe area; the bar's content stays where it was.
    func bottomBarBacking(_ color: Color = systemBackground) -> some View {
        background(color.ignoresSafeArea(edges: .bottom))
    }
}
#endif
