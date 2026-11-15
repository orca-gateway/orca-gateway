#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// Step 10: `OrcaApp` draws a config with tabs as a tab shell, and a server
/// tab bar (`tabBarComponents`) in place of the default one. The view's logic
/// is in `TabShellModel` and `ShellTree`, which is what these tests read.
@MainActor
final class TabShellTests: XCTestCase {
    /// A server tab bar: a Row with a Text showing app state `_tabIndex`, a
    /// button that switches to the tab `profile`, a button that writes app
    /// state `badge`, and a widget no SDK draws.
    private var serverBar: JSONValue {
        func node(_ id: String, _ type: String, _ kind: String, _ childMode: String,
                  props: JSONValue = [:], children: [JSONValue] = [], watches: [JSONValue] = [],
                  actions: JSONValue? = nil) -> JSONValue {
            var o: [String: JSONValue] = [
                "id": .string(id), "type": .string(type), "kind": .string(kind),
                "childMode": .string(childMode), "props": props, "children": .array(children),
                "watches": .array(watches),
            ]
            if let actions { o["actions"] = actions }
            return .object(o)
        }
        return [
            node("bar", "Row", "layout", "multi", children: ["index", "toProfile", "badge", "holo"]),
            node("index", "Text", "primitive", "none",
                 props: ["data": ["type": "state", "scope": "app", "key": "_tabIndex"]],
                 watches: ["_tabIndex"]),
            node("toProfile", "TextButton", "button", "single", children: ["toProfileLabel"],
                 actions: ["onTap": ["type": "switchTab", "tabId": "profile"]]),
            node("toProfileLabel", "Text", "primitive", "none", props: ["data": "Profile"]),
            node("badge", "TextButton", "button", "single", children: ["badgeLabel"],
                 actions: ["onTap": ["type": "setState", "key": "badge", "value": 3, "scope": "app"]]),
            node("badgeLabel", "Text", "primitive", "none", props: ["data": "Badge"]),
            node("holo", "Hologram", "primitive", "none"),
        ]
    }

    /// A server drawer: a `Drawer` 280 wide holding a Column with a button
    /// that switches to the tab `search` and a Text.
    private var serverDrawer: JSONValue {
        [
            ["id": "drawer", "type": "Drawer", "kind": "layout", "childMode": "single",
             "props": ["width": 280, "backgroundColor": "#FAFAFA"], "children": ["menu"], "watches": []],
            ["id": "menu", "type": "Column", "kind": "layout", "childMode": "multi",
             "props": [:], "children": ["toSearch", "about"], "watches": []],
            ["id": "toSearch", "type": "TextButton", "kind": "button", "childMode": "single",
             "props": [:], "children": ["toSearchLabel"], "watches": [],
             "actions": ["onTap": ["type": "switchTab", "tabId": "search"]]],
            ["id": "toSearchLabel", "type": "Text", "kind": "primitive", "childMode": "none",
             "props": ["data": "Search"], "children": [], "watches": []],
            ["id": "about", "type": "Text", "kind": "primitive", "childMode": "none",
             "props": ["data": "About"], "children": [], "watches": []],
        ]
    }

    /// Tabs `/feed` (with a child), `/search`, `/profile`; `/settings` and
    /// `/help` outside them; the server tab bar, the default drawer's items
    /// and the server drawer when asked.
    private func config(serverBar: Bool = false, drawerItems: Bool = false,
                        serverDrawer: Bool = false) -> JSONValue {
        [
            "initialRoute": "/feed",
            "drawerItems": drawerItems ? [
                ["id": "settings", "label": "Settings", "icon": "settings", "route": "/settings"],
                ["id": "help", "label": "Help", "route": "/help"],
            ] : [],
            "drawerComponents": serverDrawer ? self.serverDrawer : [],
            "tabs": [
                ["id": "feed", "label": "Feed", "icon": "home", "initialRoute": "/feed"],
                ["id": "search", "label": "Search", "icon": "search", "initialRoute": "/search"],
                ["id": "profile", "label": "Profile", "icon": "person", "initialRoute": "/profile"],
            ],
            "tabBarComponents": serverBar ? self.serverBar : [],
            "flows": [["name": "main", "routes": [
                ["path": "feed", "children": [["path": "feed/item/:id"]]],
                ["path": "search"], ["path": "profile"], ["path": "settings"], ["path": "help"],
            ]]],
        ]
    }

    private func router(_ stub: BootStub) async throws -> OrcaRouter {
        let boot = OrcaAppBoot(client: BootStub.client(stub), path: nil, system: SystemRecorder().actions())
        await boot.startIfNeeded()
        guard case .ready(let router) = boot.phase else {
            throw NSError(domain: "TabShellTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "the boot is not ready: \(boot.phase)"])
        }
        return router
    }

    /// The page paths requested so far, in order.
    private func pages(_ stub: BootStub) -> [String] {
        stub.pageRequests.map { $0.url.path.components(separatedBy: "/page/").last ?? "" }
    }

    private func settle() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    /// Put a view in a window; `body` runs while it is on screen.
    private func hosting<V: View>(_ view: V, _ body: () async throws -> Void) async throws {
        let size = CGRect(x: 0, y: 0, width: 390, height: 700)
        #if canImport(UIKit)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: size)
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = size
        controller.view.layoutIfNeeded()
        try await settle()
        try await body()
        window.isHidden = true
        #elseif canImport(AppKit)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.setFrame(size, display: true)
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        try await settle()
        try await body()
        #endif
    }

    /// The text the server bar's `index` node shows now.
    private func indexText(_ bar: ShellTree) -> JSONValue? {
        bar.tree?.first { $0.id == "index" }?.props["data"]
    }

    // MARK: - B10.1-S

    func test_B10_1_theShellHasOneItemPerTabWithItsLabelAndSymbol() async throws {
        let router = try await router(BootStub(config: config()))
        let model = TabShellModel(router: router)
        XCTAssertEqual(model.items.map(\.label), ["Feed", "Search", "Profile"])
        XCTAssertEqual(model.items.map(\.symbol), ["house.fill", "magnifyingglass", "person.fill"])
        XCTAssertEqual(model.items.map(\.index), [0, 1, 2])
        XCTAssertEqual(model.items.map(\.id), ["feed", "search", "profile"])
        XCTAssertEqual(model.selection, 0)
        XCTAssertFalse(model.usesServerBar, "no tabBarComponents: the default bar")
        XCTAssertNil(model.bar)
        XCTAssertFalse(model.barHidden)
        // A tab not visited yet has no page to draw.
        XCTAssertEqual(model.root(of: 0)?.path, "feed")
        XCTAssertNil(model.root(of: 1))
        XCTAssertNil(model.root(of: 2))
    }

    func test_B10_1_theHostedShellFetchesATabsPageOnItsFirstVisitOnly() async throws {
        let stub = BootStub(config: config())
        let router = try await router(stub)
        let model = TabShellModel(router: router)
        XCTAssertEqual(pages(stub), [])

        try await hosting(OrcaApp(router: router)) {
            XCTAssertEqual(pages(stub), ["feed"], "only the first tab's page is asked for")
            guard case .loaded(let feed) = router.loader(for: router.root).phase else {
                return XCTFail("the first tab's page is loaded by the shell")
            }

            model.select(1)
            try await settle()
            XCTAssertEqual(model.selection, 1)
            XCTAssertEqual(model.root(of: 1)?.path, "search")
            XCTAssertEqual(pages(stub), ["feed", "search"])

            model.select(2)
            try await settle()
            XCTAssertEqual(model.root(of: 2)?.path, "profile")
            XCTAssertEqual(pages(stub), ["feed", "search", "profile"])

            model.select(0)
            try await settle()
            model.select(1)
            try await settle()
            model.select(0)
            try await settle()
            XCTAssertEqual(pages(stub), ["feed", "search", "profile"], "a visited tab is not fetched again")
            guard case .loaded(let again) = router.loader(for: router.root).phase else {
                return XCTFail("the first tab's page is still loaded")
            }
            XCTAssertTrue(again === feed, "the first tab kept its page model")
        }
    }

    func test_B10_1_aTabsPathIsItsOwnPagesAndAReselectPopsToTheRoot() async throws {
        let router = try await router(BootStub(config: config()))
        let model = TabShellModel(router: router)
        router.navigate(to: "/feed/item/7")
        XCTAssertEqual(model.path(of: 0).map(\.path), ["feed/item/7"])
        XCTAssertEqual(model.path(of: 1), [])

        // Another tab, then back: the pushed page is still there.
        model.select(1)
        XCTAssertEqual(model.path(of: 0).map(\.path), ["feed/item/7"])
        XCTAssertEqual(model.path(of: 1), [])
        model.select(0)
        XCTAssertEqual(model.path(of: 0).map(\.path), ["feed/item/7"])

        // The selected tab again: its root.
        model.select(0)
        XCTAssertEqual(model.path(of: 0), [])
        XCTAssertEqual(router.top.path, "feed")

        // The system back button and the back swipe write a shorter path.
        router.navigate(to: "/feed/item/8")
        router.navigate(to: "/feed/item/9")
        model.setPath(0, Array(model.path(of: 0).prefix(1)))
        XCTAssertEqual(model.path(of: 0).map(\.path), ["feed/item/8"])
        XCTAssertEqual(router.top.path, "feed/item/8")
        // A write for a tab that is not on screen changes nothing.
        model.setPath(1, [])
        XCTAssertEqual(model.path(of: 0).map(\.path), ["feed/item/8"])
    }

    func test_B10_1_aRouteOverTheShellHidesTheBar() async throws {
        let router = try await router(BootStub(config: config()))
        let model = TabShellModel(router: router)
        let feed = router.root
        router.navigate(to: "/feed/item/7")
        let item = router.top
        XCTAssertFalse(model.barHidden, "a tab's own page keeps the bar")
        XCTAssertFalse(model.hidesBar(for: item))

        router.navigate(to: "/settings")
        let settings = router.top
        XCTAssertTrue(model.barHidden)
        XCTAssertTrue(model.hidesBar(for: settings))
        XCTAssertFalse(model.hidesBar(for: feed))
        XCTAssertFalse(model.hidesBar(for: item))
        XCTAssertEqual(model.selection, 0, "the tab under it is still the selected one")
        XCTAssertEqual(model.path(of: 0), [item, settings], "it is pushed on the current tab's stack")
        XCTAssertEqual(model.path(of: 1), [])
        XCTAssertEqual(settings.scaffoldTitle, "Settings", "and keeps its title bar")

        model.setPath(0, [item])  // back
        XCTAssertFalse(model.barHidden)
        XCTAssertEqual(router.top, item)
    }

    // MARK: - B10.4-S

    func test_B10_4_tabBarComponentsReplaceTheDefaultBarAndFollowTabIndex() async throws {
        let stub = BootStub(config: config(serverBar: true))
        let router = try await router(stub)
        let model = TabShellModel(router: router)
        XCTAssertTrue(model.usesServerBar)
        XCTAssertEqual(model.items.count, 3, "the tabs are the same; only the bar is another")
        let bar = try XCTUnwrap(model.bar)
        XCTAssertEqual(bar.page.page.pageId, "__shell__")
        XCTAssertEqual(bar.page.store.state.page, [:], "a shell tree has no page state")
        XCTAssertEqual(bar.tree?.type, "Row")
        XCTAssertEqual(indexText(bar), 0)

        router.selectTab(1)
        XCTAssertEqual(indexText(bar), 1)
        // The node that shows the index is told to redraw.
        var redraws = 0
        let watch = bar.page.store.subscribe(bar.page.watches(of: "index")) { _ in redraws += 1 }
        router.selectTab(2)
        XCTAssertEqual(indexText(bar), 2)
        XCTAssertEqual(redraws, 1)
        router.selectTab(0)
        XCTAssertEqual(indexText(bar), 0)
        XCTAssertEqual(redraws, 2)
        watch.cancel()

        // A widget this SDK cannot draw degrades as on a page.
        let holo = try XCTUnwrap(bar.tree?.first { $0.id == "holo" })
        XCTAssertEqual(holo.type, "FallbackPrompt")
        XCTAssertEqual(holo.node.degradedFrom, "Hologram")

        // Under a route over the shell the server bar is hidden too.
        router.navigate(to: "/settings")
        XCTAssertTrue(model.barHidden)
        XCTAssertTrue(model.hidesBar(for: router.top))
        XCTAssertFalse(model.showsServerBar(for: router.top))
        XCTAssertTrue(model.showsServerBar(for: router.root))
        XCTAssertEqual(pages(stub), [], "the bar itself fetches nothing")
    }

    func test_B10_4_theServerBarsSwitchTabButtonSwitchesTheTab() async throws {
        let stub = BootStub(config: config(serverBar: true))
        let router = try await router(stub)
        var effects: [String] = []
        router.onEffect = { effects.append($0.type) }
        let model = TabShellModel(router: router)
        let bar = try XCTUnwrap(model.bar)
        router.navigate(to: "/feed/item/7")

        let button = try XCTUnwrap(bar.page.resolve("toProfile"))
        await bar.page.fire("onTap", on: button)?.value
        XCTAssertEqual(router.currentTab, 2)
        XCTAssertEqual(model.selection, 2)
        XCTAssertEqual(router.root.path, "profile")
        XCTAssertEqual(router.appState["_tabIndex"], 2)
        XCTAssertEqual(indexText(bar), 2, "and the bar shows the new index")
        XCTAssertEqual(effects, ["switchTab"], "its effects are reported like a page's")
        XCTAssertEqual(model.path(of: 0).map(\.path), ["feed/item/7"], "the tab left keeps its stack")
    }

    func test_B10_4_theServerBarSharesAppStateWithThePages() async throws {
        let stub = BootStub(config: config(serverBar: true))
        let router = try await router(stub)
        let model = TabShellModel(router: router)
        let bar = try XCTUnwrap(model.bar)
        let loader = router.loader(for: router.root)
        await loader.loadIfNeeded()
        guard case .loaded(let feed) = loader.phase else { return XCTFail("feed did not load") }

        // The bar writes app state: the router and the page on screen have it.
        let badge = try XCTUnwrap(bar.page.resolve("badge"))
        await bar.page.fire("onTap", on: badge)?.value
        XCTAssertEqual(router.appState["badge"], 3)
        XCTAssertEqual(feed.store.state.app["badge"], 3)

        // A page writes app state: the bar has it.
        await feed.run(.setState(Action.SetState(key: "plan", scope: .app, value: .string("pro"))))
        XCTAssertEqual(bar.page.store.state.app["plan"], "pro")
        // The host writes app state: the bar has it.
        router.setAppState("theme", "dark")
        XCTAssertEqual(bar.page.store.state.app["theme"], "dark")

        // A page writing `_tabIndex` switches the tab, and the bar follows.
        await feed.run(.setState(Action.SetState(key: "_tabIndex", scope: .app, value: .int(1))))
        XCTAssertEqual(router.currentTab, 1)
        XCTAssertEqual(indexText(bar), 1)
    }

    func test_B10_4_theHostedShellWithAServerBarStillLoadsOnlyTheVisibleTab() async throws {
        let stub = BootStub(config: config(serverBar: true))
        let router = try await router(stub)
        try await hosting(OrcaApp(router: router)) {
            XCTAssertEqual(pages(stub), ["feed"])
            router.selectTab(2)
            try await settle()
            XCTAssertEqual(pages(stub), ["feed", "profile"])
            router.navigate(to: "/settings")
            try await settle()
            XCTAssertEqual(pages(stub), ["feed", "profile", "settings"])
        }
    }

    // MARK: - Seam: the shell's server trees and the plugin system (step 16)

    func test_seam_aServerTabBarDrawsPluginWidgetsAndRunsCustomActionsAsATabPageDoes() async throws {
        @MainActor final class Ran {
            var drawn: [String] = []
            var rated: [JSONValue] = []
            func rate(_ action: JSONValue) { rated.append(action) }
        }
        struct ShellBadgePlugin: OrcaPlugin {
            let ran: Ran
            let name = "badge"
            var widgets: [String: OrcaWidgetBuilder] {
                ["ShellBadge": { [ran] node, _ in
                    ran.drawn.append(node.id)
                    return AnyView(EmptyView())
                }]
            }
        }
        // A server tab bar and a server drawer, each a plugin widget and a
        // button with a custom action.
        func tree(_ prefix: String) -> JSONValue {
            [
                ["id": .string(prefix), "type": "Row", "kind": "layout", "childMode": "multi", "props": [:],
                 "children": [.string("\(prefix)Badge"), .string("\(prefix)Rate")], "watches": []],
                ["id": .string("\(prefix)Badge"), "type": "ShellBadge", "kind": "primitive", "childMode": "none",
                 "props": [:], "children": [], "watches": []],
                ["id": .string("\(prefix)Rate"), "type": "TextButton", "kind": "button", "childMode": "single",
                 "props": [:], "children": [.string("\(prefix)Label")], "watches": [],
                 "actions": ["onTap": ["type": "custom:rateApp"]]],
                ["id": .string("\(prefix)Label"), "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "Rate"], "children": [], "watches": []],
            ]
        }
        guard case .object(var config) = self.config(drawerItems: true) else { return XCTFail("the config") }
        config["tabBarComponents"] = tree("bar")
        config["drawerComponents"] = tree("drawer")

        let ran = Ran()
        let host = OrcaPluginHost(
            plugins: [ShellBadgePlugin(ran: ran)],
            customActions: ["rateApp": { [ran] action, _ in await ran.rate(action) }],
            widgets: WidgetBuilders())
        let boot = OrcaAppBoot(client: BootStub.client(BootStub(config: .object(config))), path: nil,
                               system: SystemRecorder().actions(), onRouteChanged: nil, plugins: host)
        await boot.startIfNeeded()
        guard case .ready(let router) = boot.phase else { return XCTFail("not ready: \(boot.phase)") }

        // The tab page, loaded through the router's loader.
        let loader = router.loader(for: router.root)
        await loader.loadIfNeeded()
        guard case .loaded(let feed) = loader.phase else { return XCTFail("feed did not load") }
        XCTAssertEqual(feed.widgets.types, ["ShellBadge"])
        await feed.run(try JSONValue.object(["type": "custom:rateApp"]).decode(Action.self))
        XCTAssertEqual(ran.rated, [["type": "custom:rateApp"]])

        // The shell's server trees: the same widgets and handlers.
        let model = TabShellModel(router: router)
        var rated = 1
        for (prefix, shell) in [("bar", model.bar), ("drawer", model.drawer)] {
            let shell = try XCTUnwrap(shell, prefix)
            let badge = try XCTUnwrap(shell.page.resolve("\(prefix)Badge"))
            XCTAssertEqual(badge.type, "ShellBadge", "\(prefix): not degraded to a FallbackPrompt")
            XCTAssertEqual(shell.tree?.first { $0.id == "\(prefix)Badge" }?.type, "ShellBadge")
            let builder = try XCTUnwrap(shell.page.widgets.builder(for: "ShellBadge"), "\(prefix): the builder")
            _ = builder(badge, shell.page)
            XCTAssertEqual(ran.drawn.last, "\(prefix)Badge")

            let button = try XCTUnwrap(shell.page.resolve("\(prefix)Rate"))
            await shell.page.fire("onTap", on: button)?.value
            rated += 1
            XCTAssertEqual(ran.rated.count, rated, "\(prefix): the custom action ran")
            XCTAssertEqual(ran.rated.last, ["type": "custom:rateApp"])
        }
        XCTAssertEqual(ran.drawn, ["barBadge", "drawerBadge"])
    }

    // MARK: - B10.5-S

    func test_B10_5_thePanelFollowsTheFingerTowardItsEdgeAndClosesPastHalfOrOnAFling() {
        let panel = DrawerPanelModel(edge: .leading, width: 300)
        // Translations run from the leading to the trailing side.
        XCTAssertEqual(panel.offset(translation: 0), 0)
        XCTAssertEqual(panel.offset(translation: -120), -120, "it follows the finger toward its edge")
        XCTAssertEqual(panel.offset(translation: 80), 0, "and does not leave its edge")
        XCTAssertEqual(panel.offset(translation: -900), -300, "nor travel further than its width")
        XCTAssertEqual(panel.progress(translation: 0), 1)
        XCTAssertEqual(panel.progress(translation: -150), 0.5)
        XCTAssertEqual(panel.progress(translation: -900), 0)
        XCTAssertEqual(panel.closedOffset, -300)

        XCTAssertEqual(panel.dragEnded(translation: -100, velocity: 0), .open, "below the threshold")
        XCTAssertEqual(panel.dragEnded(translation: -151, velocity: 0), .closed, "past half its width")
        XCTAssertEqual(panel.dragEnded(translation: -20, velocity: -400), .closed, "a fling toward the edge")
        XCTAssertEqual(panel.dragEnded(translation: -200, velocity: 400), .open, "a fling back")
        XCTAssertEqual(panel.dragEnded(translation: 120, velocity: 0), .open, "the wrong way")

        // A drag in from the screen edge opens.
        XCTAssertTrue(panel.edgeDragOpens(translation: 60, velocity: 0))
        XCTAssertTrue(panel.edgeDragOpens(translation: 10, velocity: 400))
        XCTAssertFalse(panel.edgeDragOpens(translation: 10, velocity: 0))
        XCTAssertFalse(panel.edgeDragOpens(translation: -60, velocity: -400))
    }

    func test_B10_5_aTrailingPanelMirrorsTheLeadingOne() {
        let panel = DrawerPanelModel(edge: .trailing, width: 300)
        XCTAssertEqual(panel.offset(translation: 120), 120)
        XCTAssertEqual(panel.offset(translation: -80), 0)
        XCTAssertEqual(panel.offset(translation: 900), 300)
        XCTAssertEqual(panel.progress(translation: 150), 0.5)
        XCTAssertEqual(panel.closedOffset, 300)
        XCTAssertEqual(panel.dragEnded(translation: 100, velocity: 0), .open)
        XCTAssertEqual(panel.dragEnded(translation: 151, velocity: 0), .closed)
        XCTAssertEqual(panel.dragEnded(translation: 20, velocity: 400), .closed)
        XCTAssertEqual(panel.dragEnded(translation: 200, velocity: -400), .open)
        XCTAssertEqual(panel.dragEnded(translation: -120, velocity: 0), .open)
        XCTAssertTrue(panel.edgeDragOpens(translation: -60, velocity: 0))
        XCTAssertFalse(panel.edgeDragOpens(translation: 60, velocity: 400))
    }

    func test_B10_5_withADrawerEveryTabPageHasTheMenuAndTheTabsLabelAsTitle() async throws {
        let router = try await router(BootStub(config: config(drawerItems: true)))
        XCTAssertTrue(router.hasDrawer)
        let model = TabShellModel(router: router)
        let feed = router.root
        XCTAssertEqual(model.menuTitle(for: feed), "Feed")
        XCTAssertTrue(model.opensDrawerByEdge(for: feed), "a tab's root has no back swipe")

        // Any depth inside a tab.
        router.navigate(to: "/feed/item/7")
        let item = router.top
        XCTAssertEqual(model.menuTitle(for: item), "Feed")
        XCTAssertFalse(model.opensDrawerByEdge(for: item), "the leading edge is the back swipe's")

        // Not a route over the shell.
        router.navigate(to: "/settings")
        XCTAssertNil(model.menuTitle(for: router.top))
        XCTAssertFalse(model.opensDrawerByEdge(for: router.top))

        router.selectTab(2)
        XCTAssertEqual(model.menuTitle(for: router.root), "Profile")
        XCTAssertEqual(model.menuTitle(for: feed), "Feed", "a tab left behind keeps its own label")

        // No drawer in the config: no bar, no menu.
        let plain = try await self.router(BootStub(config: config()))
        let none = TabShellModel(router: plain)
        XCTAssertNil(none.menuTitle(for: plain.root))
        XCTAssertFalse(none.opensDrawerByEdge(for: plain.root))
        XCTAssertNil(none.drawer)
        XCTAssertEqual(none.drawerRows, [])
    }

    func test_B10_5_theMenuButtonAndTheOpenDrawerActionOpenTheShellDrawer() async throws {
        let router = try await router(BootStub(config: config(drawerItems: true)))
        let host = DrawerHost()
        let model = TabShellModel(router: router, drawers: host)
        XCTAssertNil(host.open)

        // The menu button.
        model.openDrawer()
        XCTAssertTrue(router.isDrawerOpen)
        XCTAssertEqual(host.open?.id, DrawerHost.shellPanel)
        XCTAssertEqual(host.open?.edge, .leading)

        // A tap on the scrim, a swipe, escape: the host dismisses its panel.
        host.dismiss()
        XCTAssertNil(host.open)
        XCTAssertFalse(router.isDrawerOpen)

        // The `openDrawer` action from a tab's page.
        let loader = router.loader(for: router.root)
        await loader.loadIfNeeded()
        guard case .loaded(let feed) = loader.phase else { return XCTFail("feed did not load") }
        await feed.run(.openDrawer)
        XCTAssertTrue(router.isDrawerOpen)
        XCTAssertEqual(host.open?.id, DrawerHost.shellPanel)
        XCTAssertNil(router.pageDrawerRequest)

        // The router closes it: the panel goes.
        router.closeDrawer()
        XCTAssertNil(host.open)
        XCTAssertFalse(router.isDrawerOpen)
    }

    func test_B10_5_theDefaultDrawerListsTheItemsAndARowTapClosesItAndPushes() async throws {
        let stub = BootStub(config: config(drawerItems: true))
        let router = try await router(stub)
        let host = DrawerHost()
        let model = TabShellModel(router: router, drawers: host)
        XCTAssertNil(model.drawer, "no drawerComponents: the default list")
        XCTAssertEqual(model.drawerHeader, "Menu")
        XCTAssertEqual(model.drawerRows.map(\.label), ["Settings", "Help"])
        XCTAssertEqual(model.drawerRows.map(\.route), ["/settings", "/help"])
        XCTAssertEqual(model.drawerRows.map(\.symbol),
                       [IconNames.symbol(for: "settings"), IconNames.symbol(for: nil)])

        var events: [RouteChangeEvent] = []
        router.onRouteChanged = { events.append($0) }
        model.openDrawer()
        model.tap(model.drawerRows[0])
        XCTAssertFalse(router.isDrawerOpen, "the tap closes the drawer")
        XCTAssertNil(host.open)
        XCTAssertEqual(router.top.path, "settings")
        XCTAssertEqual(events.map(\.type), [.push], "then pushes the item's route")
        XCTAssertEqual(router.overRoutes, [router.top], "which lies over the shell")
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertTrue(model.barHidden)

        // Over the shell there is no shell drawer to open.
        model.openDrawer()
        XCTAssertFalse(router.isDrawerOpen)
        XCTAssertNil(host.open)
        XCTAssertEqual(pages(stub), [], "the drawer itself fetches nothing")
    }

    func test_B10_5_drawerComponentsAreTheDrawerAndItsSwitchTabRowSwitchesTheTab() async throws {
        let stub = BootStub(config: config(drawerItems: true, serverDrawer: true))
        let router = try await router(stub)
        var effects: [String] = []
        router.onEffect = { effects.append($0.type) }
        let host = DrawerHost()
        let model = TabShellModel(router: router, drawers: host)
        let drawer = try XCTUnwrap(model.drawer, "drawerComponents win over drawerItems")
        XCTAssertEqual(drawer.page.page.pageId, "__shell__")
        XCTAssertEqual(drawer.tree?.type, "Drawer")
        XCTAssertEqual(drawer.tree?.props["width"], 280)
        XCTAssertEqual(model.menuTitle(for: router.root), "Feed")

        router.openDrawer()
        XCTAssertEqual(host.open?.id, DrawerHost.shellPanel)
        let row = try XCTUnwrap(drawer.page.resolve("toSearch"))
        await drawer.page.fire("onTap", on: row)?.value
        XCTAssertEqual(router.currentTab, 1)
        XCTAssertEqual(router.root.path, "search")
        XCTAssertEqual(effects, ["switchTab"])
        XCTAssertFalse(router.isDrawerOpen, "the change of location closes the drawer")
        XCTAssertNil(host.open)
        XCTAssertEqual(model.menuTitle(for: router.root), "Search")
        XCTAssertEqual(pages(stub), [])
    }

    func test_B10_5_onePanelIsOpenAtATime() async throws {
        let router = try await router(BootStub(config: config(drawerItems: true)))
        let host = DrawerHost()
        var closed = 0
        host.present(id: "page", edge: .trailing, onClose: { closed += 1 }) { AnyView(EmptyView()) }
        XCTAssertEqual(host.open?.id, "page")
        XCTAssertEqual(host.open?.edge, .trailing)

        // The shell drawer takes the page drawer's place.
        let model = TabShellModel(router: router, drawers: host)
        model.openDrawer()
        XCTAssertEqual(host.open?.id, DrawerHost.shellPanel)
        XCTAssertEqual(closed, 1)

        // And a page drawer the shell drawer's: the router is told.
        host.present(id: "page", edge: .leading, onClose: { closed += 1 }) { AnyView(EmptyView()) }
        XCTAssertEqual(host.open?.id, "page")
        XCTAssertFalse(router.isDrawerOpen)

        // Removing a panel that is not the open one changes nothing.
        host.remove("other")
        XCTAssertEqual(host.open?.id, "page")
        host.remove("page")
        XCTAssertNil(host.open)
        XCTAssertEqual(closed, 1, "its owner took it away: no callback")
    }

    // MARK: - B10.8-S

    func test_B10_8_tabSwitchesAndDrawerCyclesRequestNothingAndKeepEachPagesModelAndState() async throws {
        let stub = BootStub(config: config(drawerItems: true))
        let router = try await router(stub)
        let host = DrawerHost()
        let model = TabShellModel(router: router, drawers: host)
        let feedRoute = router.root
        let feedLoader = router.loader(for: feedRoute)
        await feedLoader.loadIfNeeded()
        guard case .loaded(let feed) = feedLoader.phase else { return XCTFail("feed did not load") }
        feed.store.dispatch(["count": 1])

        model.select(1)
        let searchRoute = router.root
        let searchLoader = router.loader(for: searchRoute)
        await searchLoader.loadIfNeeded()
        guard case .loaded(let search) = searchLoader.phase else { return XCTFail("search did not load") }
        search.store.dispatch(["query": "orca"])
        XCTAssertEqual(pages(stub), ["feed", "search"])

        for _ in 0..<3 {
            model.openDrawer()
            XCTAssertEqual(host.open?.id, DrawerHost.shellPanel)
            host.dismiss()
            model.select(0)
            model.openDrawer()
            router.closeDrawer()
            model.openDrawer()
            model.select(1)  // the switch closes it
            XCTAssertNil(host.open)
        }

        XCTAssertEqual(pages(stub), ["feed", "search"], "no page was asked for again")
        XCTAssertTrue(router.loader(for: feedRoute) === feedLoader)
        XCTAssertTrue(router.loader(for: searchRoute) === searchLoader)
        guard case .loaded(let feedAgain) = feedLoader.phase,
              case .loaded(let searchAgain) = searchLoader.phase else {
            return XCTFail("the pages are still loaded")
        }
        XCTAssertTrue(feedAgain === feed)
        XCTAssertTrue(searchAgain === search)
        XCTAssertEqual(feed.store.value("count"), 1)
        XCTAssertEqual(search.store.value("query"), "orca")
    }

    func test_B10_8_theHostedShellWithADrawerKeepsItsPagesAcrossSwitchesAndDrawerCycles() async throws {
        let stub = BootStub(config: config(drawerItems: true))
        let router = try await router(stub)
        try await hosting(OrcaApp(router: router)) {
            let feedRoute = router.root
            let feedLoader = router.loader(for: feedRoute)
            guard case .loaded(let feed) = feedLoader.phase else {
                return XCTFail("the first tab's page is loaded by the shell")
            }
            feed.store.dispatch(["count": 1])
            router.selectTab(1)
            try await settle()
            XCTAssertEqual(pages(stub), ["feed", "search"])

            for _ in 0..<2 {
                router.openDrawer()
                try await settle()
                XCTAssertTrue(router.isDrawerOpen)
                router.closeDrawer()
                try await settle()
                router.selectTab(0)
                try await settle()
                router.openDrawer()
                try await settle()
                router.selectTab(1)
                try await settle()
                XCTAssertFalse(router.isDrawerOpen)
            }

            XCTAssertEqual(pages(stub), ["feed", "search"], "no page was asked for again")
            XCTAssertTrue(router.loader(for: feedRoute) === feedLoader)
            guard case .loaded(let again) = feedLoader.phase else {
                return XCTFail("the first tab's page is still loaded")
            }
            XCTAssertTrue(again === feed)
            XCTAssertEqual(feed.store.value("count"), 1)
        }
    }
}
#endif
