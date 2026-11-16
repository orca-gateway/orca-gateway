#if canImport(SwiftUI)
import Combine
import SwiftUI

/// A server tree of the shell (`tabBarComponents`, `drawerComponents`) as a
/// page the normal renderer draws, the Swift side of Flutter's
/// `OrcaShell._renderServerTabBar`: page id `__shell__`, no page state, the
/// router's app state. It follows every change of the app scope, so a node
/// watching `_tabIndex` redraws when the tab changes; what it writes to app
/// state goes to the router and every loaded page; its navigation and system
/// effects are performed and reported as a page's are; the app's plugin
/// widgets and custom action handlers are a page's too. A widget this SDK
/// cannot draw degrades as on a page.
@MainActor
final class ShellTree {
    static let pageId = "__shell__"

    let page: OrcaPageModel
    private var changes: AnyCancellable?

    init(components: [ComponentNode], router: OrcaRouter) {
        // Built as the loader builds a page: by the app's plugins when the
        // router has them, so plugin widgets draw and custom actions run.
        let response = PageResponse(pageId: Self.pageId, title: "", components: components)
        let store = ElmStore(app: router.appState)
        let page = router.plugins?.page(response, store: store, client: router.client)
            ?? OrcaPageModel(page: response, store: store, client: router.client)
        self.page = page
        page.store.onCommit = { [weak router] state in router?.setAppState(state.app) }
        page.onEffect = { [weak router] effect in router?.onEffect?(effect) }
        page.effectHandler = { [weak router] effect in
            guard let router, !router.perform(effect) else { return }
            router.system.perform(effect)
        }
        changes = router.appStateChanges.sink { [weak page] scope in
            guard let page, page.store.state.app != scope else { return }
            var state = page.store.state
            state.app = scope
            page.store.commit(state)
        }
    }

    /// The whole tree resolved against the state as it is now.
    var tree: RenderNode? {
        page.renderer.tree(state: page.store.state)
    }
}

/// What the tab shell shows, read from the router: the tab items, the
/// selected tab, each tab's `NavigationStack` path, whether the bar is the
/// server's and where it is hidden, and the shell drawer (its rows or its
/// server tree, which pages get the menu button, and the panel it presents
/// on the app's drawer host while the router has it open). `TabShellView`
/// only draws this.
@MainActor
final class TabShellModel: ObservableObject {
    /// One item of the default tab bar.
    struct Item: Identifiable, Equatable {
        let index: Int
        /// The tab's id in the config.
        let id: String
        let label: String
        /// The SF Symbol of the tab's Material icon name (`IconNames`).
        let symbol: String
    }

    /// One row of the default drawer (`drawerItems`).
    struct DrawerRow: Identifiable, Equatable {
        /// The item's id in the config.
        let id: String
        let label: String
        /// The SF Symbol of the item's Material icon name (`IconNames`).
        let symbol: String
        /// The location a tap pushes.
        let route: String
    }

    let router: OrcaRouter
    let items: [Item]
    /// The server tab bar (`tabBarComponents`); nil for the default bar.
    let bar: ShellTree?
    /// The server drawer (`drawerComponents`); nil for the default list or
    /// no drawer.
    let drawer: ShellTree?
    /// The default drawer's rows; empty without `drawerItems`.
    let drawerRows: [DrawerRow]
    /// The default drawer's header (Flutter `OrcaShell._buildDefaultDrawer`).
    let drawerHeader = "Menu"
    private var drawerOpen: AnyCancellable?

    /// `drawers`: where the shell drawer is shown while the router has it
    /// open; nil shows none.
    init(router: OrcaRouter, drawers: DrawerHost? = nil) {
        self.router = router
        items = router.tabs.enumerated().map { index, tab in
            Item(index: index, id: tab.id, label: tab.label, symbol: IconNames.symbol(for: tab.icon))
        }
        let config = router.table?.config
        let components = config?.tabBarComponents ?? []
        bar = components.isEmpty ? nil : ShellTree(components: components, router: router)
        let tree = router.hasDrawer ? config?.drawerComponents ?? [] : []
        drawer = tree.isEmpty ? nil : ShellTree(components: tree, router: router)
        drawerRows = router.hasDrawer ? (config?.drawerItems ?? []).map {
            DrawerRow(id: $0.id, label: $0.label, symbol: IconNames.symbol(for: $0.icon), route: $0.route)
        } : []
        guard router.hasDrawer, let drawers else { return }
        // The router says when the shell drawer is open; the host shows it.
        drawerOpen = router.$isDrawerOpen.removeDuplicates().sink { [weak self, weak router, weak drawers] open in
            guard open else {
                drawers?.remove(DrawerHost.shellPanel)
                return
            }
            drawers?.present(id: DrawerHost.shellPanel, edge: .leading,
                             onClose: { router?.closeDrawer() }) {
                AnyView(Group { if let self { ShellDrawerView(model: self) } })
            }
        }
    }

    // MARK: The shell drawer

    /// The title of the top bar a tab's page gets under a shell drawer: its
    /// tab's label, beside the menu button. Nil without a drawer and for a
    /// route over the shell: no bar, no menu.
    func menuTitle(for route: OrcaRoute) -> String? {
        guard router.hasDrawer, let index = router.tabStacks.firstIndex(where: { $0.contains(route) }),
              items.indices.contains(index) else { return nil }
        return items[index].label
    }

    /// A drag from the leading screen edge opens the shell drawer: at a
    /// tab's first page, where no back swipe takes that edge.
    func opensDrawerByEdge(for route: OrcaRoute) -> Bool {
        router.hasDrawer && router.tabStacks.contains { $0.first == route }
    }

    /// The menu button, and the edge drag.
    func openDrawer() {
        router.openDrawer()
    }

    /// A tap on a row of the default drawer: close the drawer, then push the
    /// item's route (Flutter pops the drawer, then `GoRouter.push`).
    func tap(_ row: DrawerRow) {
        router.closeDrawer()
        router.navigate(to: row.route)
    }

    // MARK: The tabs

    /// The server's tree is drawn in place of the system tab bar.
    var usesServerBar: Bool { bar != nil }

    /// A route over the shell is on screen: no tab bar, default or server.
    var barHidden: Bool { !router.overRoutes.isEmpty }

    var selection: Int { router.currentTab ?? 0 }

    /// A tap on a tab item: another tab shows its stack as it was left, the
    /// selected tab pops to its root.
    func select(_ index: Int) {
        router.selectTab(index)
    }

    /// The first page of a tab; nil until the tab is first visited, so its
    /// page is not fetched before.
    func root(of index: Int) -> OrcaRoute? {
        router.tabStacks.indices.contains(index) ? router.tabStacks[index].first : nil
    }

    /// The path of a tab's `NavigationStack`: its pages above its root, then
    /// the routes over the shell for the tab on screen.
    func path(of index: Int) -> [OrcaRoute] {
        guard router.tabStacks.indices.contains(index) else { return [] }
        return Array(router.tabStacks[index].dropFirst()) + (index == router.currentTab ? router.overRoutes : [])
    }

    /// The system wrote a tab's path: the back button or a back swipe.
    func setPath(_ index: Int, _ routes: [OrcaRoute]) {
        router.setTabPath(index, routes)
    }

    /// The route lies over the shell: it covers the tab bar.
    func hidesBar(for route: OrcaRoute) -> Bool {
        router.overRoutes.contains(route)
    }

    /// The route is a tab's page under a server tab bar.
    func showsServerBar(for route: OrcaRoute) -> Bool {
        usesServerBar && !hidesBar(for: route)
    }
}

/// A config with tabs on screen (Flutter `OrcaShell`): a tab bar, one
/// `NavigationStack` per tab. A tab's page is fetched when the tab is first
/// selected, and a visited tab stays as it was left. A route outside the tabs
/// is pushed on the current tab's stack and covers the bar. With
/// `tabBarComponents` the system bar is hidden and the server's tree is drawn
/// at the bottom of every tab page instead.
@MainActor
struct TabShellView: View {
    @ObservedObject var router: OrcaRouter
    @StateObject private var model: TabShellModel

    init(router: OrcaRouter, drawers: DrawerHost? = nil) {
        self.router = router
        _model = StateObject(wrappedValue: TabShellModel(router: router, drawers: drawers))
    }

    var body: some View {
        #if os(iOS)
        // The setter also runs for the selected tab: a reselect pops to root.
        TabView(selection: Binding(get: { model.selection }, set: { model.select($0) })) {
            ForEach(model.items) { item in
                TabStack(router: router, model: model, index: item.index)
                    .tabItem { Label(item.label, systemImage: item.symbol) }
                    .tag(item.index)
            }
        }
        #else
        PlainTabs(router: router, model: model)
        #endif
    }
}

#if !os(iOS)
/// The shell where there is no iOS tab bar (macOS, where the package's tests
/// run): every tab's stack kept in place with only the selected one shown,
/// and the items as a row of buttons under it.
@MainActor
private struct PlainTabs: View {
    @ObservedObject var router: OrcaRouter
    let model: TabShellModel

    var body: some View {
        ZStack {
            ForEach(model.items) { item in
                TabStack(router: router, model: model, index: item.index)
                    .opacity(item.index == model.selection ? 1 : 0)
                    .allowsHitTesting(item.index == model.selection)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.usesServerBar, !model.barHidden {
                HStack(spacing: 0) {
                    ForEach(model.items) { item in
                        Button { model.select(item.index) } label: {
                            Label(item.label, systemImage: item.symbol).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(item.index == model.selection ? .accentColor : .secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}
#endif

/// One tab: its pages as a NavigationStack, or nothing before its first visit.
/// Route transitions work here as in the single stack: the path comes from
/// the router's `tabStacks` and `overRoutes`, which it writes with the system
/// animation off for a pushed `fade` or `slideUp` route, and `RoutePage`
/// animates that page's content in (the shell's bars around the page are
/// not part of it and appear at once). Any other push, a tab switch and
/// going back are the system's.
@MainActor
private struct TabStack: View {
    @ObservedObject var router: OrcaRouter
    let model: TabShellModel
    let index: Int

    var body: some View {
        if let root = model.root(of: index) {
            NavigationStack(path: Binding(get: { model.path(of: index) },
                                          set: { model.setPath(index, $0) })) {
                RoutePage(router: router, route: root, isStackRoot: true)
                    .id(root.id)
                    .modifier(ShellBar(model: model, route: root))
                    .navigationDestination(for: OrcaRoute.self) { route in
                        RoutePage(router: router, route: route)
                            .modifier(ShellBar(model: model, route: route))
                    }
            }
        } else {
            Color.clear
        }
    }
}

/// The shell's bars as one page of a tab's stack sees them. The tab bar: the
/// system bar, hidden over the shell and under a server bar; the server bar
/// below a tab's page. Under a shell drawer, the top bar of a tab's page: its
/// tab's label and a leading menu button. A page whose own AppBar is the
/// navigation bar keeps its title, and gets the menu button only when it set
/// no leading item (`PageChrome`). At a tab's first page a drag from the
/// leading edge opens the drawer too, unless the page has a drawer there.
/// The bars take their insets from the page, as Flutter's shell Scaffold
/// takes them from its body: the tab bar the bottom one, the top bar under
/// a drawer the top one, so a SafeArea in the page adds neither and keeps
/// its content between the bars.
@MainActor
private struct ShellBar: ViewModifier {
    let model: TabShellModel
    let route: OrcaRoute
    /// What the page drawn here says about its own bar and drawer.
    @State private var page = PageChrome()

    func body(content: Content) -> some View {
        let server = model.showsServerBar(for: route)
        let menu = model.menuTitle(for: route)
        let page = $page
        let bottom: Edge.Set = model.hidesBar(for: route) ? [] : .bottom
        let taken = bottom.union(menu == nil ? [] : .top)
        content
            .environment(\.orcaSafeAreaTaken, taken)
            .overlay(alignment: .leading) {
                if model.opensDrawerByEdge(for: route), !self.page.hasLeadingDrawer {
                    DrawerEdgeGrip(edge: .leading) { model.openDrawer() }
                }
            }
            .onPreferenceChange(PageChromeKey.self) { page.wrappedValue = $0 }
            .modifier(ShellMenuBar(title: self.page.hasBar ? nil : menu,
                                   showsMenu: menu != nil && !self.page.hasLeadingItem,
                                   open: { model.openDrawer() }))
            #if os(iOS)
            .toolbar(server || model.hidesBar(for: route) ? .hidden : .automatic, for: .tabBar)
            #endif
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if server, let bar = model.bar {
                    ShellTreeView(tree: bar).bottomBarBacking()
                }
            }
    }
}

/// The top bar the shell gives a tab's page under a drawer: an inline title
/// and the menu button as the leading item.
private struct ShellMenuBar: ViewModifier {
    let title: String?
    let showsMenu: Bool
    let open: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(TitleBar(title: title))
            #if os(iOS)
            .toolbar {
                if showsMenu {
                    ToolbarItem(placement: .navigationBarLeading) { DrawerMenuButton(open: open) }
                }
            }
            #endif
    }
}

/// The shell drawer's content: the server tree (its root `Drawer` gives the
/// panel its width and colour), else the default list, the Swift side of
/// Flutter's `OrcaShell._buildDefaultDrawer`: a blue "Menu" header, then one
/// row per item, icon and label.
@MainActor
struct ShellDrawerView: View {
    let model: TabShellModel

    var body: some View {
        if let tree = model.drawer {
            ShellTreeView(tree: tree)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.drawerHeader)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                    .background(Props.color(hex: "#1976D2").ignoresSafeArea(edges: [.top, .horizontal]))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 8)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.drawerRows) { row in
                            Button { model.tap(row) } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: row.symbol)
                                        .font(.system(size: 20))
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.secondary)
                                        .accessibilityHidden(true)
                                    Text(row.label).font(.system(size: 16)).foregroundColor(.primary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 56)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: drawerDefaultWidth, maxHeight: .infinity, alignment: .top)
            .background(systemBackground.ignoresSafeArea())
        }
    }
}

/// A shell tree drawn by the page renderer.
@MainActor
struct ShellTreeView: View {
    let tree: ShellTree

    var body: some View {
        if let root = tree.page.renderer.rootId {
            NodeView(id: root, model: tree.page)
        }
    }
}
#endif
