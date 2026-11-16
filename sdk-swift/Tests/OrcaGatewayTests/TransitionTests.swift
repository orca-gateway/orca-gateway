#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// Step 12: a pushed route whose transition is `fade` or `slideUp` is pushed
/// with the system animation off and its page animates its own content in;
/// every other kind, and reduced motion, keeps the system push. The decision
/// and the clock are the router's, which is what these tests read; how it
/// looks on a device is a hand check.
@MainActor
final class TransitionTests: XCTestCase {
    /// No tabs: `/start` first, one route per kind, `home` with a `fade`
    /// child, `bare` with no transition.
    private var plain: JSONValue {
        [
            "initialRoute": "/start",
            "flows": [["name": "main", "routes": [
                ["path": "start"],
                ["path": "fade", "transition": ["type": "fade", "duration": 200, "curve": "linear"]],
                ["path": "rise", "transition": ["type": "slideUp", "duration": 400, "curve": "linear"]],
                ["path": "eased", "transition": ["type": "fade"]],
                ["path": "zoom", "transition": ["type": "scale"]],
                ["path": "right", "transition": ["type": "slideRight"]],
                ["path": "left", "transition": ["type": "slide"]],
                ["path": "odd", "transition": ["type": "wobble"]],
                ["path": "none", "transition": ["type": "none"]],
                ["path": "bare"],
                ["path": "home", "children": [
                    ["path": "home/detail", "transition": ["type": "fade", "duration": 200, "curve": "linear"]],
                ]],
            ]]],
        ]
    }

    /// Tabs `/feed` (its child fades in) and `/search`; `/settings` outside
    /// them rises over the shell.
    private var tabbed: JSONValue {
        [
            "initialRoute": "/feed",
            "tabs": [
                ["id": "feed", "label": "Feed", "icon": "home", "initialRoute": "/feed"],
                ["id": "search", "label": "Search", "icon": "search", "initialRoute": "/search"],
            ],
            "flows": [["name": "main", "routes": [
                ["path": "feed", "children": [
                    ["path": "feed/item/:id", "transition": ["type": "fade", "duration": 200, "curve": "linear"]],
                    ["path": "feed/about", "transition": ["type": "scale"]],
                ]],
                ["path": "search"],
                ["path": "settings", "transition": ["type": "slideUp", "duration": 400, "curve": "linear"]],
            ]]],
        ]
    }

    private var stub = PageStub()

    /// A router on `config` whose clock reads `now`.
    private func router(_ config: JSONValue) throws -> OrcaRouter {
        let nav = try JSONDecoder().decode(NavConfig.self, from: config.encoded())
        let router = OrcaRouter(client: PageStub.client(stub), config: nav, system: SystemRecorder().actions())
        router.frameClock = { [unowned self] in self.now }
        return router
    }

    private var now: Double = 1000

    private typealias Look = (opacity: Double, offsetXFraction: Double, offsetYFraction: Double, scale: Double)

    private func assertLook(_ look: Look, _ opacity: Double, _ y: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(look.opacity, opacity, accuracy: 1e-9, "opacity", file: file, line: line)
        XCTAssertEqual(look.offsetYFraction, y, accuracy: 1e-9, "y", file: file, line: line)
        XCTAssertEqual(look.offsetXFraction, 0, accuracy: 1e-9, "x", file: file, line: line)
        XCTAssertEqual(look.scale, 1, accuracy: 1e-9, "scale", file: file, line: line)
    }

    /// Wait for `condition`, looked at every 10 ms, for 5 s at most; what
    /// follows asserts it, so a timeout fails there.
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: - B12.6-S: fade and slide-up

    func test_B12_6_pushingAFadeRouteTurnsTheSystemPushOffAndThePageFadesIn() throws {
        let router = try router(plain)
        XCTAssertNil(router.entrance(of: router.top.id), "the boot is no push")
        router.navigate(to: "/fade")
        XCTAssertEqual(router.top.path, "fade")
        XCTAssertNotNil(router.entrance(of: router.top.id))
        XCTAssertEqual(router.entrance(of: router.top.id)?.spec.kind, .fade)

        assertLook(router.entering(router.top, at: 1000), 0, 0)
        assertLook(router.entering(router.top, at: 1050), 0.25, 0)
        assertLook(router.entering(router.top, at: 1100), 0.5, 0)
        assertLook(router.entering(router.top, at: 1200), 1, 0)
        assertLook(router.entering(router.top, at: 9000), 1, 0)
        // The page under it never moves.
        assertLook(router.entering(router.root, at: 1000), 1, 0)
    }

    func test_B12_6_pushingASlideUpRouteTurnsTheSystemPushOffAndThePageRises() throws {
        let router = try router(plain)
        now = 5000
        router.navigate(to: "/rise")
        XCTAssertNotNil(router.entrance(of: router.top.id))
        XCTAssertEqual(router.entrance(of: router.top.id)?.spec.kind, .slideUp)

        assertLook(router.entering(router.top, at: 5000), 1, 1)
        assertLook(router.entering(router.top, at: 5100), 1, 0.75)
        assertLook(router.entering(router.top, at: 5200), 1, 0.5)
        assertLook(router.entering(router.top, at: 5400), 1, 0)
        assertLook(router.entering(router.top, at: 5401), 1, 0)
    }

    func test_B12_6_theDefaultsAre300MillisecondsEasedInAndOut() throws {
        let router = try router(plain)
        router.navigate(to: "/eased")
        XCTAssertNotNil(router.entrance(of: router.top.id))
        assertLook(router.entering(router.top, at: 1075), 0.12868531048297882, 0)
        assertLook(router.entering(router.top, at: 1150), 0.5, 0)
        assertLook(router.entering(router.top, at: 1300), 1, 0)
    }

    func test_B12_6_theOffsetIsTheFractionOfThePagesHeight() {
        XCTAssertEqual(RouteEntrance.offset(fraction: 1, height: 700), 700)
        XCTAssertEqual(RouteEntrance.offset(fraction: 0.25, height: 700), 175)
        XCTAssertEqual(RouteEntrance.offset(fraction: 0, height: 700), 0)
    }

    // MARK: - B12.7-S: everything else keeps the system push

    func test_B12_7_everyOtherKindKeepsTheSystemPushAndThePageInPlace() throws {
        for path in ["zoom", "right", "left", "odd", "none", "bare"] {
            let router = try router(plain)
            router.navigate(to: "/" + path)
            XCTAssertEqual(router.top.path, path)
            XCTAssertNil(router.entrance(of: router.top.id), path)
            assertLook(router.entering(router.top, at: 1000), 1, 0)
        }
    }

    func test_B12_7_reducedMotionKeepsTheSystemPushForFadeAndSlideUp() throws {
        for path in ["fade", "rise"] {
            let router = try router(plain)
            router.reduceMotion = true
            router.navigate(to: "/" + path)
            XCTAssertNil(router.entrance(of: router.top.id), path)
            assertLook(router.entering(router.top, at: 1000), 1, 0)
        }
    }

    func test_B12_7_poppingIsTheSystemPopAndThePageUnderItIsInPlace() throws {
        let router = try router(plain)
        router.navigate(to: "/fade")
        let pushed = router.top.id
        XCTAssertNotNil(router.entrance(of: router.top.id))

        now = 1050
        router.goBack()
        XCTAssertEqual(router.top.path, "start")
        XCTAssertNil(router.entrance(of: router.top.id), "the pop is the system's")
        XCTAssertNil(router.entrance(of: pushed), "the route that left takes its entrance along")
        assertLook(router.entering(router.top, at: 1050), 1, 0)

        // A back swipe writes the path itself: nothing of ours runs.
        router.navigate(to: "/rise")
        let swiped = router.top.id
        XCTAssertNotNil(router.entrance(of: swiped))
        now = 3000
        router.stack = []
        XCTAssertEqual(router.top.path, "start")
        XCTAssertNil(router.entrance(of: router.top.id))
        XCTAssertNil(router.entrance(of: swiped), "swiped away, its entrance with it")

        // The same route again enters again, from the new time.
        now = 4000
        router.navigate(to: "/fade")
        XCTAssertNotNil(router.entrance(of: router.top.id))
        assertLook(router.entering(router.top, at: 4000), 0, 0)
        assertLook(router.entering(router.top, at: 4200), 1, 0)
    }

    func test_B12_7_aPageUnderAPushKeepsItsFinishedEntrance() throws {
        let router = try router(plain)
        router.navigate(to: "/fade")
        let fade = router.top
        now = 2000
        router.navigate(to: "/bare")
        let bare = router.top.id
        XCTAssertNil(router.entrance(of: bare))
        // Still on the stack: the same entrance, long over.
        XCTAssertEqual(router.entrance(of: fade.id)?.startMs, 1000)
        assertLook(router.entering(fade, at: 2000), 1, 0)
        router.goBack()
        XCTAssertEqual(router.top, fade)
        // The pop is the system's: no entrance begins, the old one stands.
        XCTAssertNil(router.entrance(of: bare))
        XCTAssertEqual(router.entrance(of: fade.id)?.startMs, 1000)
        assertLook(router.entering(fade, at: 2000), 1, 0)
    }

    func test_B12_6_aGoThatLandsOnAFadeRouteOverItsParentEntersToo() throws {
        let router = try router(plain)
        router.navigate(to: "/home/detail", replace: true)
        XCTAssertEqual(router.root.path, "home")
        XCTAssertEqual(router.top.path, "home/detail")
        XCTAssertNotNil(router.entrance(of: router.top.id))
        assertLook(router.entering(router.top, at: 1000), 0, 0)
        assertLook(router.entering(router.root, at: 1000), 1, 0)

        // A go that leaves the route alone at the bottom is no push: the
        // root of a stack has no entrance.
        let other = try self.router(plain)
        other.navigate(to: "/fade", replace: true)
        XCTAssertEqual(other.root.path, "fade")
        XCTAssertTrue(other.stack.isEmpty)
        XCTAssertNil(other.entrance(of: other.root.id))
    }

    func test_B12_7_withoutAConfigNoRouteHasATransition() {
        let router = OrcaRouter(client: PageStub.client(stub), path: "home", system: SystemRecorder().actions())
        router.navigate(to: "about")
        XCTAssertEqual(router.top.path, "about")
        XCTAssertNil(router.entrance(of: router.top.id))
        router.goBack()
        XCTAssertEqual(router.top.path, "home")
        XCTAssertNil(router.entrance(of: router.top.id))
    }

    // MARK: - Inside a tab

    func test_B12_6_aFadeRoutePushedInsideATabEntersTheSameWay() throws {
        let router = try router(tabbed)
        XCTAssertTrue(router.hasShell)
        router.navigate(to: "/feed/item/7")
        XCTAssertEqual(router.tabStacks[0].map(\.path), ["feed", "feed/item/7"])
        XCTAssertNotNil(router.entrance(of: router.top.id))
        let item = router.top
        assertLook(router.entering(item, at: 1000), 0, 0)
        assertLook(router.entering(item, at: 1100), 0.5, 0)
        assertLook(router.entering(item, at: 1200), 1, 0)

        // Another tab and back: no push, and the page is as it was left.
        now = 6000
        router.selectTab(1)
        XCTAssertNil(router.entrance(of: router.top.id))
        router.navigate(to: "/feed/item/7", replace: true)
        XCTAssertEqual(router.currentTab, 0)
        let left = router.entrance(of: router.top.id)?.startMs
        now = 7000
        router.selectTab(1)
        router.selectTab(0)
        // Coming back to a tab is no push: no entrance begins.
        XCTAssertEqual(router.entrance(of: router.top.id)?.startMs, left)

        // The tab's other child keeps the system push.
        router.navigate(to: "/feed/about")
        XCTAssertEqual(router.top.path, "feed/about")
        XCTAssertNil(router.entrance(of: router.top.id))
    }

    func test_B12_6_aSlideUpRouteOverTheShellRises() throws {
        let router = try router(tabbed)
        router.navigate(to: "/settings")
        XCTAssertEqual(router.overRoutes.map(\.path), ["settings"])
        XCTAssertNotNil(router.entrance(of: router.top.id))
        assertLook(router.entering(router.top, at: 1000), 1, 1)
        assertLook(router.entering(router.top, at: 1200), 1, 0.5)
        assertLook(router.entering(router.top, at: 1400), 1, 0)

        now = 1500
        router.goBack()
        XCTAssertEqual(router.top.path, "feed")
        XCTAssertNil(router.entrance(of: router.top.id))
    }

    func test_B12_7_reducedMotionInsideATabKeepsTheSystemPush() throws {
        let router = try router(tabbed)
        router.reduceMotion = true
        router.navigate(to: "/feed/item/7")
        XCTAssertNil(router.entrance(of: router.top.id))
    }

    func test_B12_6_theHostedShellDrawsAPageThatFadesIn() async throws {
        let router = try router(tabbed)
        router.frameClock = { OrcaPageModel.milliseconds(Date()) }
        #if canImport(UIKit)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        window.rootViewController = UIHostingController(rootView: TabShellView(router: router))
        window.isHidden = false
        defer { window.isHidden = true }
        #elseif canImport(AppKit)
        let window = NSWindow(contentViewController: NSHostingController(rootView: TabShellView(router: router)))
        window.setFrame(CGRect(x: 0, y: 0, width: 390, height: 700), display: true)
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        #endif
        let pages = { self.stub.requests.map { $0.url.path.components(separatedBy: "/page/").last ?? "" } }
        try await waitUntil { pages() == ["feed"] }
        router.navigate(to: "/feed/item/7")
        XCTAssertNotNil(router.entrance(of: router.top.id))
        // The pushed page was drawn (so fetched), and its entrance is over.
        try await waitUntil {
            pages().count == 2 && router.entering(router.top, at: router.frameClock()).opacity == 1
        }
        XCTAssertEqual(pages(), ["feed", "feed/item/7"])
        let look = router.entering(router.top, at: router.frameClock())
        XCTAssertEqual(look.opacity, 1)
    }
}
#endif
