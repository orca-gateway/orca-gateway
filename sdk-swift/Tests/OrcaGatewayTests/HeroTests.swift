#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// B12.5-S: a Hero's flight is the system zoom of iOS 18. The pushed page is
/// not loaded when the push begins, so the router records, on the route it
/// pushes, the tag of the Hero around the widget whose action navigated.
/// These tests read that record and the rule that picks the push; the zoom
/// itself is a hand check on an iOS 18 device.
@MainActor
final class HeroTests: XCTestCase {
    /// No tabs: `/start`, `detail` with no transition, `fade` fading in.
    private var plain: JSONValue {
        [
            "initialRoute": "/start",
            "flows": [["name": "main", "routes": [
                ["path": "start"],
                ["path": "detail"],
                ["path": "fade", "transition": ["type": "fade", "duration": 200, "curve": "linear"]],
            ]]],
        ]
    }

    /// Tabs `/feed` (with a child) and `/search`.
    private var tabbed: JSONValue {
        [
            "initialRoute": "/feed",
            "tabs": [
                ["id": "feed", "label": "Feed", "icon": "home", "initialRoute": "/feed"],
                ["id": "search", "label": "Search", "icon": "search", "initialRoute": "/search"],
            ],
            "flows": [["name": "main", "routes": [
                ["path": "feed", "children": [["path": "feed/item/:id"]]],
                ["path": "search"],
            ]]],
        ]
    }

    private func router(_ config: JSONValue) throws -> OrcaRouter {
        let nav = try JSONDecoder().decode(NavConfig.self, from: config.encoded())
        return OrcaRouter(client: PageStub.client(PageStub()), config: nav, system: SystemRecorder().actions())
    }

    private static func hero(_ id: String, tag: JSONValue?, child: String) -> JSONValue {
        ["id": .string(id), "type": "Hero", "kind": "layout", "childMode": "single",
         "props": tag.map { ["tag": $0] } ?? [:], "children": [.string(child)], "watches": []]
    }

    /// A GestureDetector whose tap navigates to `route`.
    private static func tap(_ id: String, to route: String, replace: Bool = false) -> JSONValue {
        ["id": .string(id), "type": "GestureDetector", "kind": "layout", "childMode": "single",
         "props": [:], "children": [],
         "actions": ["onTap": ["type": "navigate", "route": .string(route), "replace": .bool(replace)]],
         "watches": []]
    }

    /// A page attached to `router`: taps outside a Hero, inside one, inside
    /// one with an empty tag and one with none, inside two, and inside a
    /// tagged one whose nearer Hero has no tag. `route` is where they go.
    private func page(on router: OrcaRouter, to route: String = "/detail") throws -> OrcaPageModel {
        let model = try OrcaPageModel(page: JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "tag", "scope": "page", "initial": "from-state"]],
            "components": [
                ["id": "root", "type": "Column", "kind": "layout", "childMode": "multi", "props": [:],
                 "children": ["outside", "h", "empty", "bare", "outer", "outer2", "stated", "goer"], "watches": []],
                Self.tap("outside", to: route),
                Self.hero("h", tag: "product-42", child: "box"),
                ["id": "box", "type": "Container", "kind": "layout", "childMode": "single", "props": [:],
                 "children": ["inside"], "watches": []],
                Self.tap("inside", to: route),
                Self.hero("empty", tag: "", child: "inEmpty"),
                Self.tap("inEmpty", to: route),
                Self.hero("bare", tag: nil, child: "inBare"),
                Self.tap("inBare", to: route),
                Self.hero("outer", tag: "far", child: "inner"),
                Self.hero("inner", tag: "near", child: "deep"),
                Self.tap("deep", to: route),
                Self.hero("outer2", tag: "far", child: "inner2"),
                Self.hero("inner2", tag: "", child: "deep2"),
                Self.tap("deep2", to: route),
                Self.hero("stated", tag: ["type": "state", "key": "tag", "scope": "page"], child: "inStated"),
                Self.tap("inStated", to: route),
                Self.hero("goer", tag: "product-42", child: "go"),
                Self.tap("go", to: route, replace: true),
            ],
        ]).decode(PageResponse.self))
        router.attach(model)
        return model
    }

    /// Tap node `id` and wait for its action.
    private func tap(_ id: String, on model: OrcaPageModel) async throws {
        let task = model.fire("onTap", on: try XCTUnwrap(model.resolve(id)))
        try await XCTUnwrap(task).value
    }

    // MARK: - The tag, from the tap to the pushed route

    func test_B12_5_aTapInsideAHeroRecordsItsTagOnThePushedRoute() async throws {
        let router = try router(plain)
        let start = router.top
        let model = try page(on: router)
        try await tap("inside", on: model)
        XCTAssertEqual(router.top.path, "detail")
        XCTAssertEqual(router.heroTag(of: router.top.id), "product-42")
        XCTAssertEqual(router.heroSource(of: router.top.id), HeroSource(route: start.id, tag: "product-42"),
                       "the source is the Hero of the page that was on top")
        XCTAssertNil(router.heroTag(of: start.id), "the page under it is no flight")
    }

    func test_B12_5_aTapOutsideAnyHeroRecordsNone() async throws {
        let router = try router(plain)
        let model = try page(on: router)
        try await tap("outside", on: model)
        XCTAssertEqual(router.top.path, "detail")
        XCTAssertNil(router.heroTag(of: router.top.id))
        XCTAssertNil(router.heroSource(of: router.top.id))
    }

    func test_B12_5_anEmptyOrAbsentTagRecordsNone() async throws {
        for id in ["inEmpty", "inBare"] {
            let router = try router(plain)
            let model = try page(on: router)
            try await tap(id, on: model)
            XCTAssertEqual(router.top.path, "detail", id)
            XCTAssertNil(router.heroTag(of: router.top.id), id)
        }
    }

    func test_B12_5_nestedHeroesRecordTheNearest() async throws {
        let router = try router(plain)
        let model = try page(on: router)
        try await tap("deep", on: model)
        XCTAssertEqual(router.heroTag(of: router.top.id), "near")

        // The nearest Hero decides, as `orcaHeroTag` does below it: one with
        // no tag is no hero, whatever lies further out.
        let other = try self.router(plain)
        try await tap("deep2", on: try page(on: other))
        XCTAssertEqual(other.top.path, "detail")
        XCTAssertNil(other.heroTag(of: other.top.id))
    }

    func test_B12_5_theTagIsTheHerosResolvedTagAtTheTap() async throws {
        let router = try router(plain)
        let model = try page(on: router)
        XCTAssertEqual(model.heroTag(enclosing: "inStated"), "from-state")
        XCTAssertEqual(model.heroTag(enclosing: "inside"), "product-42")
        XCTAssertNil(model.heroTag(enclosing: "outside"))
        XCTAssertNil(model.heroTag(enclosing: "h"), "a Hero is not inside itself")
        XCTAssertNil(model.heroTag(enclosing: "no-such-node"))
        try await tap("inStated", on: model)
        XCTAssertEqual(router.heroTag(of: router.top.id), "from-state")
    }

    func test_B12_5_aGoADeepLinkAndTheBootRecordNone() async throws {
        let router = try router(plain)
        XCTAssertNil(router.heroTag(of: router.top.id), "the boot")

        // `navigate` with `replace` from inside a Hero is a go, not a push.
        let model = try page(on: router)
        try await tap("go", on: model)
        XCTAssertEqual(router.top.path, "detail")
        XCTAssertNil(router.heroTag(of: router.top.id))

        router.handleDeeplink(try XCTUnwrap(URL(string: "app://host/fade")))
        XCTAssertEqual(router.top.path, "fade")
        XCTAssertNil(router.heroTag(of: router.top.id))

        // The host's own push names no Hero.
        router.navigate(to: "/detail")
        XCTAssertNil(router.heroTag(of: router.top.id))

        let linked = try JSONDecoder().decode(NavConfig.self, from: plain.encoded())
        let booted = OrcaRouter(client: PageStub.client(PageStub()), config: linked,
                                system: SystemRecorder().actions(), link: URL(string: "app://host/detail"))
        XCTAssertEqual(booted.top.path, "detail")
        XCTAssertNil(booted.heroTag(of: booted.top.id))
    }

    func test_B12_5_aTagDoesNotLeakIntoALaterPush() async throws {
        let router = try router(plain)
        let model = try page(on: router)
        try await tap("inside", on: model)
        XCTAssertEqual(router.heroTag(of: router.top.id), "product-42")
        try await tap("outside", on: model)
        XCTAssertEqual(router.stack.count, 2)
        XCTAssertNil(router.heroTag(of: router.top.id))
        XCTAssertEqual(router.heroTag(of: router.stack[0].id), "product-42", "the page under keeps its own")
    }

    func test_B12_5_poppingDropsTheTag() async throws {
        let router = try router(plain)
        let model = try page(on: router)
        try await tap("inside", on: model)
        let pushed = router.top
        XCTAssertNotNil(router.heroTag(of: pushed.id))
        router.goBack()
        XCTAssertEqual(router.top.path, "start")
        XCTAssertNil(router.heroTag(of: pushed.id))
        XCTAssertNil(router.heroSource(of: pushed.id))

        // A back swipe writes the path itself.
        try await tap("inside", on: model)
        let again = router.top
        XCTAssertNotNil(router.heroTag(of: again.id))
        router.stack = []
        XCTAssertNil(router.heroTag(of: again.id))
    }

    func test_B12_5_theSameInsideATabsStack() async throws {
        let router = try router(tabbed)
        XCTAssertTrue(router.hasShell)
        let feed = router.top
        let model = try page(on: router, to: "/feed/item/7")
        try await tap("inside", on: model)
        XCTAssertEqual(router.tabStacks[0].map(\.path), ["feed", "feed/item/7"])
        let item = router.top
        XCTAssertEqual(router.heroSource(of: item.id), HeroSource(route: feed.id, tag: "product-42"))

        // It stays while the page does, another tab shown or not.
        router.selectTab(1)
        router.navigate(to: "/feed/item/7", replace: true)
        XCTAssertEqual(router.currentTab, 0)
        XCTAssertEqual(router.top.id, item.id)
        XCTAssertEqual(router.heroTag(of: item.id), "product-42")
        router.goBack()
        XCTAssertNil(router.heroTag(of: item.id))
    }

    func test_B12_5_withoutAConfigThePushedRouteRecordsTheTagToo() async throws {
        let router = OrcaRouter(client: PageStub.client(PageStub()), path: "home",
                                system: SystemRecorder().actions())
        let home = router.root
        let model = try page(on: router, to: "detail")
        try await tap("inside", on: model)
        XCTAssertEqual(router.top.path, "detail")
        XCTAssertEqual(router.heroSource(of: router.top.id), HeroSource(route: home.id, tag: "product-42"))
        try await tap("go", on: model)
        XCTAssertTrue(router.stack.isEmpty)
        XCTAssertNil(router.heroTag(of: router.top.id), "a go records none")
        try await tap("outside", on: model)
        XCTAssertNil(router.heroTag(of: router.top.id))
        try await tap("inside", on: model)
        let pushed = router.top
        router.goBack()
        XCTAssertNil(router.heroTag(of: pushed.id))
    }

    // MARK: - Zoom, content entrance or the plain push

    func test_B12_5_theZoomExistsOnIOS18AndUpOnly() {
        XCTAssertTrue(RoutePush.zoomAvailable(isIOS: true, osMajor: 18))
        XCTAssertTrue(RoutePush.zoomAvailable(isIOS: true, osMajor: 26))
        XCTAssertFalse(RoutePush.zoomAvailable(isIOS: true, osMajor: 17))
        XCTAssertFalse(RoutePush.zoomAvailable(isIOS: true, osMajor: 16))
        XCTAssertFalse(RoutePush.zoomAvailable(isIOS: false, osMajor: 13))
        XCTAssertFalse(RoutePush.zoomAvailable(isIOS: false, osMajor: 26), "macOS has no zoom")
    }

    func test_B12_5_thePushIsTheZoomTheContentEntranceOrTheSystems() {
        func push(_ tag: String?, entrance: Bool, reduceMotion: Bool = false, zoom: Bool) -> RoutePush {
            RoutePush.decide(heroTag: tag, entranceHonoured: entrance, reduceMotion: reduceMotion,
                             zoomAvailable: zoom)
        }
        // iOS 18 and up: a recorded tag is the zoom, also on a fade or
        // slideUp route, whose content entrance is skipped for that push.
        XCTAssertEqual(push("a", entrance: false, zoom: true), .zoom("a"))
        XCTAssertEqual(push("a", entrance: true, zoom: true), .zoom("a"))
        // Reduced motion is the system's to honour inside its zoom.
        XCTAssertEqual(push("a", entrance: true, reduceMotion: true, zoom: true), .zoom("a"))
        XCTAssertEqual(push(nil, entrance: false, zoom: true), .system)
        XCTAssertEqual(push("", entrance: false, zoom: true), .system)
        XCTAssertEqual(push(nil, entrance: true, zoom: true), .entrance)
        XCTAssertEqual(push("", entrance: true, zoom: true), .entrance)
        XCTAssertEqual(push(nil, entrance: true, reduceMotion: true, zoom: true), .system)
        // iOS 16-17 and macOS: the tag changes nothing.
        XCTAssertEqual(push("a", entrance: false, zoom: false), .system)
        XCTAssertEqual(push("a", entrance: true, zoom: false), .entrance)
        XCTAssertEqual(push("a", entrance: true, reduceMotion: true, zoom: false), .system)
        XCTAssertEqual(push(nil, entrance: true, zoom: false), .entrance)
        XCTAssertEqual(push(nil, entrance: false, zoom: false), .system)
    }

    func test_B12_5_whereTheZoomExistsAHeroPushSkipsTheRoutesContentEntrance() async throws {
        let router = try router(plain)
        router.zoomAvailable = true
        let start = router.top
        let model = try page(on: router, to: "/fade")
        try await tap("inside", on: model)
        XCTAssertEqual(router.top.path, "fade")
        XCTAssertEqual(router.zoomSource(of: router.top.id), HeroSource(route: start.id, tag: "product-42"))
        XCTAssertNil(router.entrance(of: router.top.id), "the zoom, not the fade")

        // No Hero: the route's own fade, as before.
        try await tap("outside", on: model)
        XCTAssertNil(router.zoomSource(of: router.top.id))
        XCTAssertEqual(router.entrance(of: router.top.id)?.spec.kind, .fade)
    }

    func test_B12_5_whereThereIsNoZoomAHeroPushIsTheRoutesOwn() async throws {
        let router = try router(plain)
        router.zoomAvailable = false
        let model = try page(on: router, to: "/fade")
        try await tap("inside", on: model)
        XCTAssertEqual(router.heroTag(of: router.top.id), "product-42", "recorded all the same")
        XCTAssertNil(router.zoomSource(of: router.top.id))
        XCTAssertEqual(router.entrance(of: router.top.id)?.spec.kind, .fade)

        let other = try self.router(plain)
        other.zoomAvailable = false
        try await tap("inside", on: try page(on: other))
        XCTAssertNil(other.zoomSource(of: other.top.id))
        XCTAssertNil(other.entrance(of: other.top.id), "the plain push")
    }

    #if os(macOS)
    func test_B12_5_onMacOSTheRouterHasNoZoom() throws {
        XCTAssertFalse(try router(plain).zoomAvailable)
    }
    #endif

    // MARK: - Drawn

    /// A Hero under a router's page and the app's namespace, as OrcaApp
    /// draws it.
    private struct Hosted: View {
        let model: OrcaPageModel
        let page: OrcaPageContext
        @Namespace private var space

        var body: some View {
            NodeView(id: "w", model: model)
                .environment(\.orcaHeroNamespace, space)
                .environment(\.orcaPage, page)
                .frame(width: 100, height: 100, alignment: .topLeading)
        }
    }

    func test_B12_5_aHeroDrawsItsChildInsideAnAppAsOutside() throws {
        let router = try router(plain)
        for tag: JSONValue? in ["product-42", "", nil] {
            let model = try OrcaPageModel(page: JSONValue.object([
                "pageId": "p", "title": "T", "state": [],
                "components": [
                    Self.hero("w", tag: tag, child: "kid"),
                    ["id": "kid", "type": "Container", "kind": "layout", "childMode": "single",
                     "props": ["width": 20, "height": 20, "color": "#FF0000"], "children": [], "watches": []],
                ],
            ]).decode(PageResponse.self))
            let context = OrcaPageContext(router: router, route: router.top, isStackRoot: true)
            let hosted = ImageRenderer(content: Hosted(model: model, page: context))
            hosted.scale = 1
            let bare = ImageRenderer(content: NodeView(id: "w", model: model)
                .frame(width: 100, height: 100, alignment: .topLeading))
            bare.scale = 1
            for image in [hosted.cgImage, bare.cgImage] {
                let red = try XCTUnwrap(try Pixels(XCTUnwrap(image)).bounds(of: Pixels.isRed))
                XCTAssertEqual(red, CGRect(x: 0, y: 0, width: 20, height: 20), "tag \(String(describing: tag))")
            }
        }
    }
}
#endif
