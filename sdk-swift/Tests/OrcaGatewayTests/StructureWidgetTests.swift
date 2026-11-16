#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@testable import OrcaGateway

/// S10: BottomNavigationBar, BottomNavItem and Drawer. The nodes are shaped
/// like schema/fixtures/render/60_bottom_navigation_bar.json and
/// 61_scaffold_drawers.json; the tap runs on the model, layout in a real
/// SwiftUI host.
@MainActor
final class StructureWidgetTests: XCTestCase {
    // MARK: B10.6-S

    func test_B10_6_S_barShowsItsItemsAndTheSelectedIndexFromPageState() throws {
        let model = try navModel()
        let bar = try self.bar(model)

        XCTAssertEqual(bar.items.map(\.label), ["Home", "Search", "Profile"])
        XCTAssertEqual(bar.items.map(\.icon), ["home", "search", "person"])
        XCTAssertEqual(bar.items.map(\.activeIcon), ["home_filled", nil, nil])
        XCTAssertEqual(bar.currentIndex, 1)
        // The selected item shows its activeIcon when it has one.
        XCTAssertEqual(bar.items[0].iconName(selected: true), "home_filled")
        XCTAssertEqual(bar.items[0].iconName(selected: false), "home")
        XCTAssertEqual(bar.items[1].iconName(selected: true), "search")

        // In the Scaffold's bottomNavigationBar slot it is drawn at the bottom.
        XCTAssertEqual(model.resolve("page")?.slots["bottomNavigationBar"], "nav")
        let frames = host(width: 390, height: 600) {
            NodeView(id: "nav", model: model).record("bar")
        }
        let frame = try XCTUnwrap(frames["bar"])
        XCTAssertEqual(frame.width, 390)
        XCTAssertGreaterThan(frame.height, 40)
    }

    func test_B10_6_S_aTapWritesTheBoundKeyThenFiresOnChangeWithTheIndex() async throws {
        let model = try navModel()
        var commits: [[String: JSONValue]] = []
        let subscription = model.store.subscribe(["tab", "lastTab"]) { commits.append($0.page) }

        let fired = try bar(model).select(2)
        // The bound key is written at once, before onChange has run.
        XCTAssertEqual(model.store.value("tab"), 2)
        XCTAssertEqual(model.store.value("lastTab"), 0)
        await fired?.value

        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits.first?["tab"], 2)
        XCTAssertEqual(commits.first?["lastTab"], 0)
        // onChange is `setState lastTab = event.value`.
        XCTAssertEqual(commits.last?["lastTab"], 2)
        XCTAssertEqual(model.store.state.page, ["tab": 2, "lastTab": 2])
        XCTAssertEqual(model.store.state.app, [:])
        XCTAssertEqual(try bar(model).currentIndex, 2)
        subscription.cancel()
    }

    func test_B10_6_S_currentIndexOutOfRangeIsClamped() throws {
        XCTAssertEqual(try bar(navModel(tab: 7)).currentIndex, 2)
        XCTAssertEqual(try bar(navModel(tab: -3)).currentIndex, 0)
        // Absent: 0.
        XCTAssertEqual(try bar(navModel(currentIndex: nil)).currentIndex, 0)
    }

    func test_B10_6_S_anAppScopeBindingWritesAppState() async throws {
        let model = try navModel(currentIndex: ["type": "state", "key": "section", "scope": "app"])
        try await bar(model).select(1)?.value

        XCTAssertEqual(model.store.state.app["section"], 1)
        XCTAssertNil(model.store.state.page["section"])
        XCTAssertEqual(model.store.state.page["lastTab"], 1)
    }

    func test_B10_6_S_aStaticIndexWritesNothingAndStillFiresOnChange() async throws {
        let model = try navModel(currentIndex: 1)
        try await bar(model).select(2)?.value

        XCTAssertEqual(model.store.state.page, ["tab": 1, "lastTab": 2])
        // No action: the tap is a no-op.
        let silent = try navModel(actions: nil)
        XCTAssertNil(try bar(silent).select(0))
        XCTAssertEqual(silent.store.state.page, ["tab": 0, "lastTab": 0])
    }

    func test_B10_6_S_itemsStopAtTheFirstGapAndZeroItemsDrawsNothing() throws {
        // As the Flutter builder: only the items before the first gap.
        let gap = try navModel(items: ["item_0": "nav_home", "item_2": "nav_profile"])
        XCTAssertEqual(try bar(gap).items.map(\.label), ["Home"])
        // A slot that names no node is a gap too.
        let dangling = try navModel(items: ["item_0": "nav_home", "item_1": "nav_gone", "item_2": "nav_profile"])
        XCTAssertEqual(try bar(dangling).items.map(\.label), ["Home"])

        let empty = try navModel(items: [:])
        XCTAssertTrue(try bar(empty).items.isEmpty)
        let frames = host(width: 390, height: 600) {
            NodeView(id: "nav", model: empty).record("bar")
        }
        XCTAssertEqual(frames["bar"]?.height ?? 0, 0)
    }

    func test_B10_6_S_aBottomNavItemOnItsOwnDrawsAnIconAndLabelRow() throws {
        let model = try navModel()
        let frames = host(width: 390, height: 600) {
            NodeView(id: "nav_search", model: model).record("item")
        }
        let frame = try XCTUnwrap(frames["item"])
        // A 24 point icon, a 4 point gap, the label.
        XCTAssertGreaterThan(frame.width, 28)
        XCTAssertLessThan(frame.width, 200)
        XCTAssertGreaterThanOrEqual(frame.height, 24)
    }

    func test_B10_6_S_aDrawerDrawsItsChildInAPanel() throws {
        let model = try drawerModel()
        XCTAssertEqual(model.resolve("drawer")?.childIds, ["menu"])

        var frames = host(width: 390, height: 600) {
            NodeView(id: "drawer", model: model).record("drawer")
        }
        XCTAssertEqual(frames["drawer"]?.width, 280)
        XCTAssertEqual(frames["drawer"]?.height, 600)

        // No width: 304, capped to the width there is. No child: an empty panel.
        frames = host(width: 390, height: 600) {
            NodeView(id: "bare", model: model).record("drawer")
        }
        XCTAssertEqual(frames["drawer"]?.width, 304)
        frames = host(width: 200, height: 600) {
            NodeView(id: "bare", model: model).record("drawer")
        }
        XCTAssertEqual(frames["drawer"]?.width, 200)

        // Hosting the Scaffold's drawer slots is a later task: they are slots,
        // not children, and the Scaffold does not draw them.
        XCTAssertEqual(model.resolve("page")?.slots["drawer"], "drawer")
    }

    // MARK: B10.5-S (the page Scaffold's drawer and endDrawer)

    func test_B10_5_S_aPageDrawerRequestOpensTheLeadingPanelAndIsCleared() throws {
        let model = try scaffoldDrawersModel()
        let router = OrcaRouter(client: BootStub.client(BootStub(config: [:])), path: "inbox")
        let host = DrawerHost()
        let drawers = ScaffoldDrawers(node: try XCTUnwrap(model.resolve("page")), model: model,
                                      host: host, router: router, route: router.root.id)
        XCTAssertEqual(drawers.slot(.leading), "drawer")
        XCTAssertEqual(drawers.slot(.trailing), "end_drawer")

        // No request: nothing opens.
        drawers.answerRequest()
        XCTAssertNil(host.open)

        // `openDrawer` where there is no shell drawer asks the page on top.
        router.openDrawer()
        XCTAssertEqual(router.pageDrawerRequest, router.root.id)
        drawers.answerRequest()
        XCTAssertEqual(host.open?.id, drawers.panelId(.leading))
        XCTAssertEqual(host.open?.edge, .leading)
        XCTAssertNil(router.pageDrawerRequest, "the page that opened its drawer clears the request")
        XCTAssertTrue(drawers.isOpen(.leading))

        // A request for another route is not this page's.
        host.dismiss()
        router.navigate(to: "detail")
        router.openDrawer()
        drawers.answerRequest()
        XCTAssertNil(host.open)
        XCTAssertEqual(router.pageDrawerRequest, router.top.id)

        // A Scaffold with no drawer clears its request and opens nothing.
        let bare = try scaffoldDrawersModel(drawers: false)
        let none = ScaffoldDrawers(node: try XCTUnwrap(bare.resolve("page")), model: bare,
                                   host: host, router: router, route: router.top.id)
        XCTAssertNil(none.slot(.leading))
        none.answerRequest()
        XCTAssertNil(host.open)
        XCTAssertNil(router.pageDrawerRequest)
    }

    func test_B10_5_S_theScaffoldsDrawerAndEndDrawerOpenAndCloseOneAtATime() throws {
        let model = try scaffoldDrawersModel()
        let host = DrawerHost()
        let drawers = ScaffoldDrawers(node: try XCTUnwrap(model.resolve("page")), model: model,
                                      host: host, router: nil, route: nil)
        XCTAssertFalse(drawers.isOpen(.leading))

        drawers.open(.leading)
        XCTAssertEqual(host.open?.edge, .leading)
        XCTAssertTrue(drawers.isOpen(.leading))
        // A tap on the scrim, a swipe, escape.
        host.dismiss()
        XCTAssertNil(host.open)
        XCTAssertFalse(drawers.isOpen(.leading))

        drawers.open(.trailing)
        XCTAssertEqual(host.open?.id, drawers.panelId(.trailing))
        XCTAssertEqual(host.open?.edge, .trailing)
        // The other one takes its place.
        drawers.open(.leading)
        XCTAssertTrue(drawers.isOpen(.leading))
        XCTAssertFalse(drawers.isOpen(.trailing))
        // Closing the one that is not open changes nothing.
        drawers.close(.trailing)
        XCTAssertTrue(drawers.isOpen(.leading))
        drawers.close(.leading)
        XCTAssertNil(host.open)

        // Without a host (a page drawn outside OrcaApp) nothing opens.
        let alone = ScaffoldDrawers(node: try XCTUnwrap(model.resolve("page")), model: model,
                                    host: nil, router: nil, route: nil)
        alone.open(.leading)
        XCTAssertFalse(alone.isOpen(.leading))
        XCTAssertFalse(alone.showsMenu(.leading))
    }

    func test_B10_5_S_anAppBarWithNoLeadingOrActionsGetsTheMenuButtons() throws {
        let drawerHost = DrawerHost()
        func drawers(_ model: OrcaPageModel) throws -> ScaffoldDrawers {
            ScaffoldDrawers(node: try XCTUnwrap(model.resolve("page")), model: model,
                            host: drawerHost, router: nil, route: nil)
        }
        // Fixture 61: an AppBar with a title only.
        let plain = try drawers(scaffoldDrawersModel())
        XCTAssertTrue(plain.showsMenu(.leading))
        XCTAssertTrue(plain.showsMenu(.trailing))
        // The page's own leading widget and actions stay.
        let own = try drawers(scaffoldDrawersModel(appBar: ["title": "title", "leading": "title", "action_0": "title"]))
        XCTAssertFalse(own.showsMenu(.leading))
        XCTAssertFalse(own.showsMenu(.trailing))
        // No drawers: no buttons. No AppBar: none either.
        let none = try drawers(scaffoldDrawersModel(drawers: false))
        XCTAssertFalse(none.showsMenu(.leading))
        XCTAssertFalse(none.showsMenu(.trailing))
        let barless = try drawers(scaffoldDrawersModel(appBar: nil))
        XCTAssertFalse(barless.showsMenu(.leading))
        XCTAssertFalse(barless.showsMenu(.trailing))

        // The hosted panel is the slot's Drawer, at its own width.
        plain.open(.trailing)
        let panel = try XCTUnwrap(drawerHost.open)
        let frames = host(width: 390, height: 600) { panel.content().record("panel") }
        XCTAssertEqual(frames["panel"]?.width, 320)
        XCTAssertEqual(frames["panel"]?.height, 600)
    }

    // MARK: B10.C-S

    /// The pin moved from 31 to 49 when native parity step 3 advertised its 13
    /// layout wrappers (A3.1) and step 12 its 5 animated widgets, then to 60
    /// when step 4 advertised its 11 effect and touch wrappers (A4.x), and to
    /// 61 when S18 added UnsupportedWidgetPlaceholder.
    func test_B10_C_S_sixtyOneWidgetsAreAdvertisedWithTheThreeNewOnes() {
        let widgets = GeneratedCapabilities.widgets
        XCTAssertEqual(widgets.count, 61)
        XCTAssertEqual(Set(widgets).count, 61)
        XCTAssertTrue(Set(widgets).isSuperset(of: ["BottomNavigationBar", "BottomNavItem", "Drawer"]))
        XCTAssertEqual(WidgetRegistry.shared.types, Set(widgets))
    }

    func test_B10_C_S_theWidgetSwitchDrawsEveryAdvertisedWidget() throws {
        let model = try navModel()
        // Any resolved node, retyped: only the switch is under test.
        var node = try XCTUnwrap(model.resolve("body"))
        for type in GeneratedCapabilities.widgets {
            node.type = type
            let drawn = Self.branch(WidgetView(node: node, model: model).body)
            XCTAssertFalse(drawn is EmptyView, "\(type) is advertised and falls to the switch's default")
        }
        // What the check relies on: a type outside the switch is EmptyView.
        node.type = "NoSuchWidget"
        XCTAssertTrue(Self.branch(WidgetView(node: node, model: model).body) is EmptyView)
    }

    // MARK: A3.1

    /// A3.1: the standard registry holds native parity step 3's 13 layout
    /// wrappers, so a page holding one of each, built with it (no widened
    /// registry), keeps every node as sent: none is degraded to a
    /// FallbackPrompt, each keeps its child, and the widget switch draws each
    /// with its own view.
    func testA3_1TheStandardRegistryDrawsTheThirteenLayoutWrappersNotAFallback() throws {
        let wrappers = ["Align", "AspectRatio", "Baseline", "ConstrainedBox", "FittedBox", "Flexible",
                        "FractionallySizedBox", "IntrinsicHeight", "IntrinsicWidth", "LimitedBox", "Offstage",
                        "SafeArea", "Wrap"]
        XCTAssertEqual(Set(wrappers).subtracting(WidgetRegistry.shared.types), [], "not in the standard registry")

        let model = try wrappersModel()
        XCTAssertTrue(model.renderer.registry === WidgetRegistry.shared)
        let tree = try XCTUnwrap(model.renderer.tree(state: model.store.state))
        XCTAssertEqual(tree.children.map(\.type), wrappers)
        for wrapper in tree.children {
            XCTAssertNil(wrapper.node.degradedFrom, "\(wrapper.type) was degraded")
            XCTAssertEqual(wrapper.children.map(\.type), wrapper.type == "Wrap" ? ["Container", "Container"] : ["Container"],
                           "\(wrapper.type) lost its child")
        }
        XCTAssertFalse(tree.all.contains { $0.type == "FallbackPrompt" }, "a FallbackPrompt is drawn")
        XCTAssertTrue(WidgetRegistry.shared.reportedTypes.isDisjoint(with: wrappers),
                      "reported unknown: \(WidgetRegistry.shared.reportedTypes.intersection(wrappers))")

        for wire in wrappers {
            let node = try XCTUnwrap(model.resolve("w_\(wire)"))
            let drawn = Self.branch(WidgetView(node: node, model: model).body)
            XCTAssertEqual(String(describing: type(of: drawn)), "\(wire)View")
        }
    }

    // MARK: helpers

    /// The view the switch chose: the value inside the nested
    /// `_ConditionalContent`s a SwiftUI `switch` builds.
    private static func branch(_ view: Any) -> Any {
        var current = view
        while String(describing: type(of: current)).hasPrefix("_ConditionalContent") {
            guard let storage = Mirror(reflecting: current).children.first?.value,
                  let chosen = Mirror(reflecting: storage).children.first?.value else { break }
            current = chosen
        }
        return current
    }

    private func bar(_ model: OrcaPageModel) throws -> BottomNavBar {
        BottomNavBar(node: try XCTUnwrap(model.resolve("nav")), model: model)
    }

    /// Fixture 60's nodes: a Scaffold whose bottomNavigationBar slot holds a
    /// bar with three BottomNavItem slots, `currentIndex` bound to page
    /// state `tab`, `onChange` writing the event's value into `lastTab`.
    private func navModel(
        tab: JSONValue = 1,
        currentIndex: JSONValue? = ["type": "state", "key": "tab", "scope": "page"],
        items: [String: JSONValue] = ["item_0": "nav_home", "item_1": "nav_search", "item_2": "nav_profile"],
        actions: JSONValue? = ["onChange": ["type": "setState", "scope": "page", "key": "lastTab",
                                            "value": ["type": "event", "key": "value"]]]
    ) throws -> OrcaPageModel {
        var props: [String: JSONValue] = [
            "backgroundColor": "#FFFFFF", "selectedItemColor": "#6200EE", "unselectedItemColor": "#9E9E9E",
        ]
        if let currentIndex { props["currentIndex"] = currentIndex }
        props.merge(items) { $1 }
        var nav: [String: JSONValue] = [
            "id": "nav", "type": "BottomNavigationBar", "kind": "structure", "childMode": "none",
            "props": .object(props),
            "children": .array(items.keys.sorted().compactMap { items[$0] }),
            "watches": ["tab"],
        ]
        if let actions { nav["actions"] = actions }
        return OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "tab", "scope": "page", "initial": tab],
                      ["key": "lastTab", "scope": "page", "initial": 0]],
            "components": [
                ["id": "page", "type": "Scaffold", "kind": "structure", "childMode": "none",
                 "props": ["body": "body", "bottomNavigationBar": "nav"],
                 "children": ["body", "nav"], "watches": []],
                .object(nav),
                ["id": "nav_profile", "type": "BottomNavItem", "kind": "primitive", "childMode": "none",
                 "props": ["icon": "person", "label": "Profile", "tooltip": "Your profile"],
                 "children": [], "watches": []],
                ["id": "nav_search", "type": "BottomNavItem", "kind": "primitive", "childMode": "none",
                 "props": ["icon": "search", "label": "Search"], "children": [], "watches": []],
                ["id": "nav_home", "type": "BottomNavItem", "kind": "primitive", "childMode": "none",
                 "props": ["icon": "home", "activeIcon": "home_filled", "label": "Home"],
                 "children": [], "watches": []],
                ["id": "body", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "Feed"], "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self))
    }

    /// Fixture 61's drawer (a single-child layout node) in the Scaffold's
    /// `drawer` slot, and a bare Drawer with no props and no child.
    private func drawerModel() throws -> OrcaPageModel {
        OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [],
            "components": [
                ["id": "page", "type": "Scaffold", "kind": "structure", "childMode": "none",
                 "props": ["body": "body", "drawer": "drawer"],
                 "children": ["body", "drawer"], "watches": []],
                ["id": "body", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "Messages"], "children": [], "watches": []],
                ["id": "drawer", "type": "Drawer", "kind": "layout", "childMode": "single",
                 "props": ["backgroundColor": "#FAFAFA", "elevation": 16, "width": 280],
                 "children": ["menu"], "watches": []],
                ["id": "menu", "type": "Column", "kind": "layout", "childMode": "multi",
                 "props": [:], "children": ["menu_inbox"], "watches": []],
                ["id": "menu_inbox", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "Inbox"], "children": [], "watches": []],
                ["id": "bare", "type": "Drawer", "kind": "layout", "childMode": "single",
                 "props": [:], "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self))
    }

    /// Fixture 61: a Scaffold with an AppBar, a body, a `drawer` and an
    /// `endDrawer`; `appBar` gives the AppBar's slots, nil for no AppBar.
    private func scaffoldDrawersModel(drawers: Bool = true,
                                      appBar: [String: JSONValue]? = ["title": "title"]) throws -> OrcaPageModel {
        var slots: [String: JSONValue] = ["body": "body"]
        if drawers {
            slots["drawer"] = "drawer"
            slots["endDrawer"] = "end_drawer"
        }
        if appBar != nil { slots["appBar"] = "bar" }
        return OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [],
            "components": [
                ["id": "page", "type": "Scaffold", "kind": "structure", "childMode": "none",
                 "props": .object(slots), "children": ["bar", "body", "drawer", "end_drawer"], "watches": []],
                ["id": "bar", "type": "AppBar", "kind": "structure", "childMode": "none",
                 "props": .object(appBar ?? [:]), "children": ["title"], "watches": []],
                ["id": "title", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "Inbox"], "children": [], "watches": []],
                ["id": "body", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "Messages"], "children": [], "watches": []],
                ["id": "drawer", "type": "Drawer", "kind": "layout", "childMode": "single",
                 "props": ["backgroundColor": "#FAFAFA", "elevation": 16, "width": 280],
                 "children": ["menu"], "watches": []],
                ["id": "menu", "type": "Column", "kind": "layout", "childMode": "multi",
                 "props": [:], "children": ["menu_inbox"], "watches": []],
                ["id": "menu_inbox", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "Inbox"], "children": [], "watches": []],
                ["id": "end_drawer", "type": "Drawer", "kind": "layout", "childMode": "single",
                 "props": ["backgroundColor": "#263238", "elevation": 4, "width": 320],
                 "children": ["filters_title"], "watches": []],
                ["id": "filters_title", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": "Filters"], "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self))
    }

    /// A3.1: a Column holding one of each of the 13 layout wrappers (id
    /// `w_<Type>`, props as the engine sends them), each around a small red
    /// Container, the Wrap around two. The model uses the standard registry.
    private func wrappersModel() throws -> OrcaPageModel {
        let props: [(type: String, props: [String: JSONValue])] = [
            ("Align", ["alignment": "bottomRight"]),
            ("AspectRatio", ["aspectRatio": 2]),
            ("Baseline", ["baseline": 20, "baselineType": "alphabetic"]),
            ("ConstrainedBox", ["constraints": ["minWidth": 10, "maxHeight": 40]]),
            ("FittedBox", ["fit": "contain"]),
            ("Flexible", ["flex": 1, "fit": "loose"]),
            ("FractionallySizedBox", ["widthFactor": 0.5]),
            ("IntrinsicHeight", [:]),
            ("IntrinsicWidth", ["stepWidth": 8]),
            ("LimitedBox", ["maxHeight": 40]),
            ("Offstage", ["offstage": false]),
            ("SafeArea", ["top": true]),
            ("Wrap", ["spacing": 4, "runSpacing": 4]),
        ]
        var nodes: [JSONValue] = [
            ["id": "col", "type": "Column", "kind": "layout", "childMode": "multi", "props": [:],
             "children": .array(props.map { .string("w_\($0.type)") }), "watches": []],
        ]
        for (type, wrapperProps) in props {
            let children = type == "Wrap" ? ["c_Wrap", "c_Wrap_2"] : ["c_\(type)"]
            nodes.append(["id": .string("w_\(type)"), "type": .string(type), "kind": "layout",
                          "childMode": .string(type == "Wrap" ? "multi" : "single"), "props": .object(wrapperProps),
                          "children": .array(children.map { .string($0) }), "watches": []])
            for child in children {
                nodes.append(["id": .string(child), "type": "Container", "kind": "layout", "childMode": "single",
                              "props": ["color": "#FF0000", "width": 20, "height": 10], "children": [], "watches": []])
            }
        }
        return OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self))
    }

    /// Lays `content` out in a `width` by `height` host and returns the
    /// frames its `record(_:)` calls reported (as NativeWidgetTests.layout).
    private func host<V: View>(width: CGFloat, height: CGFloat,
                               @ViewBuilder _ content: () -> V) -> [String: CGRect] {
        let box = FrameBox()
        let root = content()
            .frame(width: width, height: height, alignment: .topLeading)
            .coordinateSpace(name: FrameBox.space)
            .onPreferenceChange(FramesKey.self) { box.frames = $0 }
        let size = CGRect(x: 0, y: 0, width: width, height: height)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: size)
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = size
        host.view.layoutIfNeeded()
        #elseif canImport(AppKit)
        let host = NSHostingView(rootView: root)
        host.frame = size
        host.layoutSubtreeIfNeeded()
        #endif
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        _ = host
        return box.frames
    }
}
#endif
