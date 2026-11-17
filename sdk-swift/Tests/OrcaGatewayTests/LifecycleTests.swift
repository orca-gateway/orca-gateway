#if canImport(SwiftUI)
import Foundation
import OSLog
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@testable import OrcaGateway

/// Plan step 2 on Swift: the lifecycle triggers any node may carry (Flutter
/// component_renderer.dart:230-255, lifecycle_wrapper.dart), the widget
/// source a tap hands the executor, and the host's debugLog line. The node
/// is drawn in a real host window (onAppear needs one); the scene phase is
/// driven through the environment by the host view, so the app events run
/// the same path as a scene's own phase.
@MainActor
final class LifecycleTests: XCTestCase {
    // MARK: A2.1 / A2.2 once per mount

    /// A2.1: onInit runs once when the node is first built, not again when a
    /// state change it watches redraws it.
    func testA2_1OnInitRunsOnceWhenTheNodeIsFirstBuiltNotOnARedraw() throws {
        try assertRunsOnceOnAppear("onInit")
    }

    /// A2.2 (corrected, as Flutter): onVisible runs once when the node is
    /// first built, not again when it redraws.
    func testA2_2OnVisibleRunsOnceWhenTheNodeIsFirstBuiltNotOnARedraw() throws {
        try assertRunsOnceOnAppear("onVisible")
    }

    #if os(macOS)
    /// A2.1: a node hidden and shown again while it stays mounted (another
    /// tab here; a page popped back over it is the same case, Flutter keeps
    /// a covered route mounted) does not run its onInit or onVisible again,
    /// though SwiftUI calls its onAppear again. macOS only: the iOS test
    /// runner has no window scene, and there UIKit sends the covered tab
    /// no disappearance (nor does a NavigationStack its root), so the case
    /// cannot be staged.
    func testA2_1ANodeShownAgainWhileMountedDoesNotRunItsOnInitAgain() throws {
        let model = try page(["onInit", "onVisible"])
        let tabs = TabBox()
        let hosted = HostedNode(TabHost(tabs: tabs, model: model), model: model)
        defer { hosted.close() }
        hosted.pump(0.5)
        XCTAssertEqual(model.store.value("onInit"), 1, "onInit not run on the first build")
        XCTAssertEqual(model.store.value("onVisible"), 1, "onVisible not run on the first build")

        tabs.selection = 1
        hosted.pump(1)
        tabs.selection = 0
        hosted.pump(1)
        XCTAssertEqual(tabs.appeared, 2, "the node was not shown again")
        XCTAssertEqual(model.store.value("onInit"), 1, "onInit ran again when the node came back")
        XCTAssertEqual(model.store.value("onVisible"), 1, "onVisible ran again when the node came back")
    }
    #endif

    // MARK: A2.3 app events

    /// A2.3: going to the background runs onBackground, coming back runs
    /// onForeground. No onForeground on the first build, `.inactive` alone
    /// runs nothing, and `.active` without a `.background` before it runs
    /// nothing.
    func testA2_3BackgroundThenForegroundRunOnBackgroundThenOnForeground() throws {
        let model = try page(["onBackground", "onForeground"])
        let hosted = HostedNode(model: model)
        defer { hosted.close() }
        hosted.pump()
        XCTAssertEqual(model.store.value("onForeground"), 0, "onForeground on the first build")

        hosted.set(.inactive)
        hosted.set(.active)
        XCTAssertEqual(model.store.value("onBackground"), 0, "inactive is not the background")
        XCTAssertEqual(model.store.value("onForeground"), 0, "active after inactive alone is not a return")

        hosted.set(.inactive)
        hosted.set(.background)
        XCTAssertEqual(model.store.value("onBackground"), 1, "onBackground not run")
        XCTAssertEqual(model.store.value("onForeground"), 0)
        XCTAssertEqual(model.store.value("order"), 1)

        hosted.set(.inactive)
        hosted.set(.active)
        XCTAssertEqual(model.store.value("onBackground"), 1)
        XCTAssertEqual(model.store.value("onForeground"), 1, "onForeground not run")
        XCTAssertEqual(model.store.value("order"), 12, "background then foreground")
    }

    /// A2.3: onAppBackground and onAppForeground win over onBackground and
    /// onForeground when both are set; alone, either spelling runs.
    func testA2_3TheOnAppSpellingWinsOverTheShortName() throws {
        let both = try page(["onAppBackground", "onBackground", "onAppForeground", "onForeground"])
        let hosted = HostedNode(model: both)
        defer { hosted.close() }
        hosted.pump()
        hosted.set(.background)
        hosted.set(.active)
        XCTAssertEqual(both.store.value("onAppBackground"), 1)
        XCTAssertEqual(both.store.value("onBackground"), 0, "the short name ran beside onAppBackground")
        XCTAssertEqual(both.store.value("onAppForeground"), 1)
        XCTAssertEqual(both.store.value("onForeground"), 0, "the short name ran beside onAppForeground")

        let app = try page(["onAppBackground", "onAppForeground"])
        let alone = HostedNode(model: app)
        defer { alone.close() }
        alone.pump()
        alone.set(.background)
        alone.set(.active)
        XCTAssertEqual(app.store.value("onAppBackground"), 1)
        XCTAssertEqual(app.store.value("onAppForeground"), 1)
    }

    /// A2.3: a page under a pushed one hears the app go to the background
    /// and come back, once each, as Flutter's covered route (the Navigator
    /// keeps it mounted) does; the pushed page hears them too. Popped back
    /// on top it hears each once more, not twice.
    func testA2_3APageUnderAPushedOneHearsTheAppEvents() throws {
        let router = OrcaRouter(client: AppEventPages.client, path: "home", system: SystemRecorder().actions())
        let hosted = HostedNode(OrcaApp(router: router))
        defer { hosted.close() }
        let home = try hosted.loaded(router, router.root)

        router.navigate(to: "about")
        let about = try hosted.loaded(router, router.top)
        hosted.pump(1)
        cycle(hosted)
        XCTAssertEqual(Self.appEvents(home), [1, 1], "the covered page")
        XCTAssertEqual(Self.appEvents(about), [1, 1], "the pushed page")

        router.goBack()
        hosted.pump(1)
        cycle(hosted)
        XCTAssertEqual(Self.appEvents(home), [2, 2], "back on top")
    }

    /// The app goes to the background and comes back, through `.inactive` each way.
    private func cycle(_ hosted: HostedNode) {
        for phase in [ScenePhase.inactive, .background, .inactive, .active] { hosted.set(phase) }
    }

    /// How many times the page's onAppBackground and onAppForeground ran.
    static func appEvents(_ model: OrcaPageModel) -> [JSONValue] {
        [model.store.value("onAppBackground"), model.store.value("onAppForeground")]
    }

    // MARK: A2.5 once per widget and trigger

    /// A2.5: a tap wrapped in once changes the state one time; a second tap
    /// on the same widget does nothing, another widget's once still runs. A
    /// text field's onChange is keyed the same way.
    func testA2_5AOnceTapRunsOneTimePerWidgetAndTrigger() async throws {
        let once: JSONValue = ["type": "once", "action": Self.count("taps")]
        let model = try OrcaPageModel(page: JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [Self.zero("taps"), Self.zero("edits")],
            "components": [
                Self.node("buy", actions: ["onTap": once]),
                Self.node("cancel", actions: ["onTap": once]),
                AppBarCardTests.node("f", "TextField", kind: "input", childMode: "none", props: [:])
                    .merging(["actions": ["onChange": ["type": "once", "action": Self.count("edits")]]]),
            ],
        ]).decode(PageResponse.self))

        let buy = try XCTUnwrap(model.resolve("buy"))
        await model.fire("onTap", on: buy)?.value
        await model.fire("onTap", on: buy)?.value
        XCTAssertEqual(model.store.value("taps"), 1, "a second tap on the same widget ran its once again")

        await model.fire("onTap", on: try XCTUnwrap(model.resolve("cancel")))?.value
        XCTAssertEqual(model.store.value("taps"), 2, "another widget's once did not run")

        let field = try XCTUnwrap(model.resolve("f"))
        await model.textChanged("a", on: field)?.value
        await model.textChanged("ab", on: field)?.value
        XCTAssertEqual(model.store.value("edits"), 1, "a second edit ran the field's once again")
    }

    // MARK: A2.6 debugLog on the host

    /// A2.6: the host writes a debugLog effect to the system log (subsystem
    /// com.orcagateway, the tag as category, message then data) and still
    /// hands it on to the effect handler.
    func testA2_6ADebugLogIsLoggedAndStillReachesTheEffectHandler() async throws {
        let model = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"))
        var handled: [ActionEffect] = []
        model.effectHandler = { handled.append($0) }
        let since = Date().addingTimeInterval(-1)
        let tag = "lifecycle-\(UUID().uuidString)"
        await model.run(.debugLog(.init(level: "error", message: "hi", tag: tag, data: ["n": 1])))
        XCTAssertEqual(handled, [ActionEffect("debugLog", [
            "level": "error", "tag": .string(tag), "message": "hi", "data": ["n": 1],
        ])])

        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let entries = try store.getEntries(at: store.position(date: since),
                                           matching: NSPredicate(format: "subsystem == %@", "com.orcagateway"))
        let lines = entries.compactMap { $0 as? OSLogEntryLog }.filter { $0.category == tag }
        XCTAssertEqual(lines.map(\.composedMessage), [#"hi {"n":1}"#], "the debugLog line")
        XCTAssertEqual(lines.first?.level, .error)
    }

    // MARK: C19 DevTools on the page

    /// C19.6: with DevTools on, a debugLog still writes its system log line
    /// and still reaches the effect handler, and DevTools hears its generic
    /// `action` event only (Flutter sends no log event; the schema has none).
    func testC19_6_withDevToolsOnADebugLogIsLoggedAndDevToolsHearsItsActionEventOnly() async throws {
        let recorder = DevToolsHookTests.Recorder()
        OrcaDebug.reporter = recorder
        defer { OrcaDebug.reporter = nil }
        let model = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"))
        var handled: [ActionEffect] = []
        model.effectHandler = { handled.append($0) }
        let since = Date().addingTimeInterval(-1)
        let tag = "devtools-\(UUID().uuidString)"
        let log = Action.debugLog(.init(level: "info", message: "hi", tag: tag))
        await model.run(log)
        XCTAssertEqual(handled, [ActionEffect("debugLog", ["level": "info", "tag": .string(tag), "message": "hi"])])

        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let entries = try store.getEntries(at: store.position(date: since),
                                           matching: NSPredicate(format: "subsystem == %@", "com.orcagateway"))
        let lines = entries.compactMap { $0 as? OSLogEntryLog }.filter { $0.category == tag }
        XCTAssertEqual(lines.map(\.composedMessage), ["hi"], "the debugLog line")
        XCTAssertEqual(lines.first?.level, .info)

        XCTAssertEqual(recorder.events.map(\.type), ["action"])
        var payload = try XCTUnwrap(recorder.events.first?.payload)
        XCTAssertNotNil(payload.removeValue(forKey: "durationMs")?.doubleValue)
        XCTAssertEqual(payload, [
            "actionType": "debugLog", "family": "custom", "pageId": "p", "data": log.json,
        ])
    }

    /// C19.2: a page's setState lists the page's own nodes watching its key,
    /// in the order the page sent them (8 before 5 here), then a node a
    /// server action added; a node watching another key is not listed.
    func testC19_2_aPagesSetStateListsItsNodesWatchingTheKey() async throws {
        let recorder = DevToolsHookTests.Recorder()
        OrcaDebug.reporter = recorder
        defer { OrcaDebug.reporter = nil }
        func node(_ id: String, _ type: String, _ watches: [String], children: [String] = []) -> JSONValue {
            ["id": .string(id), "type": .string(type), "kind": "layout", "childMode": "multi",
             "props": [:], "children": .array(children.map { .string($0) }),
             "watches": .array(watches.map { .string($0) })]
        }
        let model = try OrcaPageModel(page: JSONValue.object([
            "pageId": "home", "title": "Home", "state": [Self.zero("count")],
            "components": [
                node("0", "Column", [], children: ["8", "3", "5"]),
                node("8", "Container", ["count", "theme"]),
                node("3", "Text", ["theme"]),
                node("5", "Text", ["count"]),
            ],
        ]).decode(PageResponse.self))
        let increment = try Self.count("count").decode(Action.self)
        func watchers() -> JSONValue? {
            recorder.of("action").last { $0.payload["actionType"] == "setState" }?.payload["affectedWidgets"]
        }

        await model.run(increment)
        XCTAssertEqual(model.store.value("count"), 1)
        let container: JSONValue = ["id": "8", "type": "Container", "watches": ["count", "theme"]]
        let text: JSONValue = ["id": "5", "type": "Text", "watches": ["count"]]
        XCTAssertEqual(watchers(), [container, text])

        let added = ComponentNode(id: "20", type: "Text", kind: .primitive, childMode: .none, watches: ["count"])
        model.apply(.add(parentId: "0", components: [added], position: 0))
        await model.run(increment)
        XCTAssertEqual(watchers(), [container, text, ["id": "20", "type": "Text", "watches": ["count"]]])
    }

    /// C19.2: after server actions change the tree, the watchers come in
    /// Flutter's node map order (component_store.dart): an added node goes
    /// to the end in the order sent, whatever its id or child position; an
    /// update keeps its place; a replace removes the target's subtree first,
    /// so a replacement reusing the target's id moves to the end; a deleted
    /// node drops out.
    func testC19_2_nodesServerActionsChangedKeepFluttersNodeMapOrder() async throws {
        let recorder = DevToolsHookTests.Recorder()
        OrcaDebug.reporter = recorder
        defer { OrcaDebug.reporter = nil }
        func node(_ id: String, _ type: String = "Text", _ watches: [String] = ["count"],
                  children: [String] = []) -> ComponentNode {
            ComponentNode(id: id, type: type, kind: children.isEmpty ? .primitive : .layout,
                          childMode: children.isEmpty ? .none : .multi, children: children, watches: watches)
        }
        let model = OrcaPageModel(page: PageResponse(
            pageId: "home", title: "Home", state: [StateDefinition(key: "count", scope: .page, initial: 0)],
            components: [
                node("0", "Column", [], children: ["8", "3", "5"]),
                node("8", "Container", ["count", "theme"]), node("3", "Text", ["theme"]), node("5"),
            ]))
        let increment = try Self.count("count").decode(Action.self)
        func watchers() async -> [JSONValue] {
            await model.run(increment)
            let last = recorder.of("action").last { $0.payload["actionType"] == "setState" }
            return last?.payload["affectedWidgets"]?.arrayValue ?? []
        }
        func ids() async -> [String] {
            await watchers().compactMap { $0["id"].stringValue }
        }

        // Two adds whose ids sort opposite to their arrival, the second at
        // child position 0, then one subtree of 11 nodes watching at _2, _10.
        model.apply(.add(parentId: "0", components: [node("item-42_0")], position: nil))
        model.apply(.add(parentId: "0", components: [node("item-17_0")], position: 0))
        let subtree = (1...10).map { "item-9_\($0)" }
        model.apply(.add(parentId: "0", components: [node("item-9_0", "Column", [], children: subtree)]
            + subtree.map { node($0, "Text", $0 == "item-9_2" || $0 == "item-9_10" ? ["count"] : ["theme"]) },
            position: 1))
        let watching = await ids()
        XCTAssertEqual(watching, ["8", "5", "item-42_0", "item-17_0", "item-9_2", "item-9_10"])

        model.apply(.update(id: "item-42_0", props: ["data": "updated"]))
        model.apply(.replace(targetId: "8", components: [node("8")]))
        let replaced = await watchers()
        XCTAssertEqual(replaced.compactMap { $0["id"].stringValue },
                       ["5", "item-42_0", "item-17_0", "item-9_2", "item-9_10", "8"])
        XCTAssertEqual(replaced.last, ["id": "8", "type": "Text", "watches": ["count"]], "the current node 8")

        model.apply(.delete(id: "5"))
        model.apply(.delete(id: "item-9_0"))
        let deleted = await ids()
        XCTAssertEqual(deleted, ["item-42_0", "item-17_0", "8"])
    }

    /// C19.2 with a SubPage (step 13): the nodes of a mounted sub-page are in
    /// the host's store, so a setState on a key they watch lists them, in
    /// Flutter's node map order: at the end, in the order the sub-page sent
    /// them, after the nodes the page already had. A replace takes the old
    /// page's nodes out and puts the new ones at the end; a SubPage node
    /// that leaves takes its pages' nodes out of the list.
    func testC19_2_theNodesOfAMountedSubPageAreListedInNodeMapOrder() async throws {
        let recorder = DevToolsHookTests.Recorder()
        OrcaDebug.reporter = recorder
        defer { OrcaDebug.reporter = nil }
        func node(_ id: String, _ type: String = "Text", _ watches: [String] = ["count"],
                  children: [String] = []) -> ComponentNode {
            ComponentNode(id: id, type: type, kind: children.isEmpty ? .primitive : .layout,
                          childMode: children.isEmpty ? .none : .multi, children: children, watches: watches)
        }
        func subPage(_ ids: [String]) -> PageResponse {
            PageResponse(
                pageId: "detail", title: "Detail", state: [StateDefinition(key: "count", scope: .page, initial: 0)],
                components: [node("0", "Column", [], children: ids)] + ids.map {
                    // The node reads the page's count, so its watch is the sub-page's key.
                    ComponentNode(id: $0, type: "Text", kind: .primitive, childMode: .none,
                                  props: ["data": ["type": "state", "key": "count", "scope": "page"]],
                                  watches: ["count"])
                })
        }
        let model = OrcaPageModel(page: PageResponse(
            pageId: "home", title: "Home", state: [],
            components: [
                node("0", "Column", [], children: ["1", "detail", "9"]),
                node("1", "Text", ["detail:count"]), node("detail", "SubPage", []),
                node("9", "Text", ["detail:count"]),
            ]))
        let increment = try Self.count("detail:count").decode(Action.self)
        func ids() async -> [String] {
            await model.run(increment)
            let last = recorder.of("action").last { $0.payload["actionType"] == "setState" }
            return (last?.payload["affectedWidgets"]?.arrayValue ?? []).compactMap { $0["id"].stringValue }
        }

        try model.mountSubPage("detail", mode: "replace", page: subPage(["7", "2"]))
        let mounted = await ids()
        XCTAssertEqual(mounted, ["1", "9", "detail:7", "detail:2"])

        model.apply(.add(parentId: "0", components: [node("30", "Text", ["detail:count"])], position: nil))
        try model.mountSubPage("detail", mode: "replace", page: subPage(["2", "5"]))
        let replaced = await ids()
        XCTAssertEqual(replaced, ["1", "9", "30", "detail:2", "detail:5"])

        try model.mountSubPage("detail", mode: "join", page: subPage(["4"]))
        let joined = await ids()
        XCTAssertEqual(joined, ["1", "9", "30", "detail:2", "detail:5"], "a joined page has its own count")

        _ = model.subPage("detail")
        model.apply(.delete(id: "detail"))
        let left = await ids()
        XCTAssertEqual(left, ["1", "9", "30"])
        XCTAssertTrue(model.renderer.nodes.keys.allSatisfy { !$0.hasPrefix("detail") })
    }

    // MARK: helpers

    /// The node runs `trigger` once on its first build; its own state change
    /// (the counter it watches) and a second one (a longer label, drawn
    /// wider) redraw it without running the trigger again.
    func assertRunsOnceOnAppear(_ trigger: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let model = try page([trigger])
        let hosted = HostedNode(model: model)
        defer { hosted.close() }
        hosted.pump()
        XCTAssertEqual(model.store.value(trigger), 1, "\(trigger) not run on the first build", file: file, line: line)
        let narrow = try XCTUnwrap(hosted.box.frames["n"], "node not drawn", file: file, line: line)

        Task { await model.run(.setState(.init(key: "label", value: "a much longer label"))) }
        hosted.pump()
        let wide = try XCTUnwrap(hosted.box.frames["n"], file: file, line: line)
        XCTAssertGreaterThan(wide.width, narrow.width, "the node did not redraw", file: file, line: line)
        XCTAssertEqual(model.store.value(trigger), 1, "\(trigger) ran again on a redraw", file: file, line: line)
    }

    /// A page of one Text `n` showing the page state `label`, watching it
    /// and its trigger counts; each trigger adds 1 to the page state of its
    /// name and appends its digit to `order` (background 1, foreground 2: a
    /// background then a foreground make 12).
    func page(_ triggers: [String]) throws -> OrcaPageModel {
        var actions: [String: JSONValue] = [:]
        for trigger in triggers {
            actions[trigger] = ["type": "actionGroup", "mode": "sequential", "actions": [
                Self.count(trigger),
                ["type": "setState", "scope": "page", "key": "order", "value": [
                    "type": "transform", "input": ["type": "state", "key": "order", "scope": "page"],
                    "by": [["type": "multiply", "by": ["type": "static", "value": 10]],
                           ["type": "add", "by": ["type": "static", "value": .int(Self.digit(trigger))]]],
                ]],
            ]]
        }
        return try OrcaPageModel(page: JSONValue.object([
            "pageId": "p", "title": "T",
            "state": .array(triggers.map(Self.zero) + [
                ["key": "label", "scope": "page", "initial": "a"],
                ["key": "order", "scope": "page", "initial": 0],
            ]),
            "components": [Self.node("n", watches: ["label"] + triggers, actions: actions)],
        ]).decode(PageResponse.self))
    }

    /// 1 for a background trigger, 2 for a foreground one, 3 otherwise.
    static func digit(_ trigger: String) -> Int {
        trigger.hasSuffix("Background") ? 1 : trigger.hasSuffix("Foreground") ? 2 : 3
    }

    /// A Text showing the page state `label`, with `watches` and `actions`.
    static func node(_ id: String, watches: [String] = [], actions: [String: JSONValue]) -> JSONValue {
        let data: JSONValue = ["type": "state", "key": "label", "scope": "page"]
        return ["id": .string(id), "type": "Text", "kind": "primitive", "childMode": "none",
                "props": ["data": data], "children": [],
                "watches": .array(watches.map { .string($0) }), "actions": .object(actions)]
    }

    static func zero(_ key: String) -> JSONValue {
        ["key": .string(key), "scope": "page", "initial": 0]
    }

    /// setState `key` to itself plus 1.
    static func count(_ key: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": [
            "type": "transform", "input": ["type": "state", "key": .string(key), "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]
    }
}

#if os(macOS)
/// The selected tab of a TabHost, and how often its first tab appeared.
private final class TabBox: ObservableObject {
    @Published var selection = 0
    var appeared = 0
}

/// The node in a TabView's first tab, a Text in the second.
private struct TabHost: View {
    @ObservedObject var tabs: TabBox
    let model: OrcaPageModel

    var body: some View {
        TabView(selection: $tabs.selection) {
            NodeView(id: "n", model: model).onAppear { tabs.appeared += 1 }
                .tabItem { Text("node") }.tag(0)
            Text("other").tabItem { Text("other") }.tag(1)
        }
    }
}
#endif

/// The scene phase a test drives; the host view puts it in the environment.
private final class PhaseBox: ObservableObject {
    @Published var value: ScenePhase = .active
}

/// `NodeView(id: "n")` 300 by 300 at the top left, its frame recorded, under
/// the test's scene phase.
private struct PhaseHost<Content: View>: View {
    @ObservedObject var phase: PhaseBox
    let box: FrameBox
    let content: Content

    var body: some View {
        content
            .frame(width: 300, height: 300, alignment: .topLeading)
            .coordinateSpace(name: FrameBox.space)
            .onPreferenceChange(FramesKey.self) { box.frames = $0 }
            .environment(\.scenePhase, phase.value)
    }
}

/// A view in a real window (UIKit or AppKit), kept on screen until `close`.
@MainActor
private final class HostedNode {
    let model: OrcaPageModel?
    let phase = PhaseBox()
    let box = FrameBox()
    #if canImport(UIKit)
    private let window: UIWindow
    #elseif canImport(AppKit)
    private let window: NSWindow
    #endif

    convenience init(model: OrcaPageModel) {
        self.init(NodeView(id: "n", model: model).record("n"), model: model)
    }

    init<V: View>(_ content: V, model: OrcaPageModel? = nil) {
        self.model = model
        let root = PhaseHost(phase: phase, box: box, content: content)
        let size = CGRect(x: 0, y: 0, width: 300, height: 300)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: root)
        window = UIWindow(frame: size)
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = size
        host.view.layoutIfNeeded()
        #elseif canImport(AppKit)
        window = NSWindow(contentRect: size, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: root)
        host.frame = size
        window.contentView = host
        window.orderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        #endif
    }

    /// Let SwiftUI draw and the fired actions run.
    func pump(_ seconds: Double = 0.2) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func set(_ phase: ScenePhase) {
        self.phase.value = phase
        pump()
    }

    /// The page of `route` once the view on screen loaded it (five seconds at most).
    func loaded(_ router: OrcaRouter, _ route: OrcaRoute) throws -> OrcaPageModel {
        let loader = router.loader(for: route)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if case .loaded(let model) = loader.phase { return model }
            pump(0.05)
        }
        throw NSError(domain: "LifecycleTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
    }

    func close() {
        #if canImport(UIKit)
        window.isHidden = true
        #elseif canImport(AppKit)
        window.orderOut(nil)
        #endif
    }
}

/// Every page: one Text of its name whose onAppBackground and
/// onAppForeground add 1 to the page state of their name.
private final class AppEventPages: HTTPTransport, @unchecked Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let name = request.url.path.components(separatedBy: "/page/").last ?? ""
        let triggers = ["onAppBackground", "onAppForeground"]
        var actions: [String: JSONValue] = [:]
        for trigger in triggers {
            actions[trigger] = ["type": "setState", "scope": "page", "key": .string(trigger), "value": [
                "type": "transform", "input": ["type": "state", "key": .string(trigger), "scope": "page"],
                "by": [["type": "add", "by": ["type": "static", "value": 1]]],
            ]]
        }
        let page: JSONValue = [
            "pageId": .string(name), "title": .string(name),
            "state": .array(triggers.map { ["key": .string($0), "scope": "page", "initial": 0] }),
            "components": [["id": "n", "type": "Text", "kind": "primitive", "childMode": "none",
                            "props": ["data": .string(name)], "children": [], "watches": [],
                            "actions": .object(actions)]],
        ]
        return HTTPResponse(status: 200, body: try page.encoded())
    }

    static var client: OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "lifecycle",
                   device: DeviceInfo(osVersion: "test"), transport: AppEventPages())
    }
}

private extension JSONValue {
    func merging(_ other: [String: JSONValue]) -> JSONValue {
        guard case .object(var o) = self else { return self }
        o.merge(other) { $1 }
        return .object(o)
    }
}
#endif
