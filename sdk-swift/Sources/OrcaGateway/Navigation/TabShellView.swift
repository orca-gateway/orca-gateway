#if canImport(SwiftUI)
import Combine
import SwiftUI

/// A server tree of the shell (`tabBarComponents`, `drawerComponents`) as a
/// page the normal renderer draws, the Swift side of Flutter's
/// `OrcaShell._renderServerTabBar`: page id `__shell__`, no page state, the
/// router's app state. It follows every change of the app scope, so a node
/// watching `_tabIndex` redraws when the tab changes; what it writes to app
/// state goes to the router and every loaded page; its navigation and system
/// effects are performed and reported as a page's are. A widget this SDK
/// cannot draw degrades as on a page.
@MainActor
final class ShellTree {
    static let pageId = "__shell__"

    let page: OrcaPageModel
    private var changes: AnyCancellable?

    init(components: [ComponentNode], router: OrcaRouter) {
        let page = OrcaPageModel(
            page: PageResponse(pageId: Self.pageId, title: "", components: components),
            store: ElmStore(app: router.appState), client: router.client)
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
/// server's and where it is hidden. `TabShellView` only draws this.
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

    let router: OrcaRouter
    let items: [Item]
    /// The server tab bar (`tabBarComponents`); nil for the default bar.
    let bar: ShellTree?

    init(router: OrcaRouter) {
        self.router = router
        items = router.tabs.enumerated().map { index, tab in
            Item(index: index, id: tab.id, label: tab.label, symbol: IconNames.symbol(for: tab.icon))
        }
        let components = router.table?.config.tabBarComponents ?? []
        bar = components.isEmpty ? nil : ShellTree(components: components, router: router)
    }

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

    init(router: OrcaRouter) {
        self.router = router
        _model = StateObject(wrappedValue: TabShellModel(router: router))
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
@MainActor
private struct TabStack: View {
    @ObservedObject var router: OrcaRouter
    let model: TabShellModel
    let index: Int

    var body: some View {
        if let root = model.root(of: index) {
            NavigationStack(path: Binding(get: { model.path(of: index) },
                                          set: { model.setPath(index, $0) })) {
                RoutePage(router: router, route: root)
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

/// The tab bar as one page of a tab's stack sees it: the system bar, hidden
/// over the shell and under a server bar; the server bar below a tab's page.
@MainActor
private struct ShellBar: ViewModifier {
    let model: TabShellModel
    let route: OrcaRoute

    func body(content: Content) -> some View {
        let server = model.showsServerBar(for: route)
        content
            #if os(iOS)
            .toolbar(server || model.hidesBar(for: route) ? .hidden : .automatic, for: .tabBar)
            #endif
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if server, let bar = model.bar {
                    ShellTreeView(tree: bar)
                }
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
