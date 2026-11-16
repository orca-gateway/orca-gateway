#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// A8.4 (design D8, D4's queue): one SnackbarQueue for the app, the
/// router's, as Flutter's root ScaffoldMessenger (sdk/lib/src/state/
/// action_executor.dart:393-423; material app.dart:990, scaffold.dart
/// :371-392, :438-449, :661-674). Every page's showSnackbar and showToast
/// join it in arrival order, nothing dropped or replaced; it outlives the
/// page that showed a bar, across navigate, back and a tab switch, the bar's
/// time still running. A page with no router keeps a queue of its own.
/// Time is passed in: each queue runs on `now`, and only `pass` moves it.
@MainActor
final class SnackbarQueueHostTests: XCTestCase {
    /// Now, in ms, for every queue under test.
    private var now: Double = 1_000_000

    /// `snackbars` on the test's clock, with no wake of its own: nothing but
    /// `pass` moves it.
    private func manual(_ snackbars: OrcaSnackbars) {
        snackbars.clock = { [unowned self] in self.now }
        snackbars.sleep = nil
    }

    /// `ms` of time pass for `snackbars`.
    private func pass(_ ms: Double, _ snackbars: OrcaSnackbars) {
        now += ms
        snackbars.tick()
    }

    private func router(_ stub: PageStub = PageStub()) -> OrcaRouter {
        let router = OrcaRouter(client: PageStub.client(stub), path: "home", system: SystemRecorder().actions())
        manual(router.snackbars)
        return router
    }

    private func loaded(_ router: OrcaRouter, _ route: OrcaRoute) async throws -> OrcaPageModel {
        let loader = router.loader(for: route)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "SnackbarQueueHostTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
        }
        return model
    }

    private func snackbar(_ message: String) -> Action {
        .showSnackbar(.init(message: .string(message)))
    }

    private func toast(_ message: String) -> Action {
        .showToast(.init(message: .string(message)))
    }

    // MARK: - The queue

    /// A8.4: two showSnackbar in a row show one after the other: the second
    /// waits while the first enters (250), shows (4000) and leaves (250),
    /// and enters only once the first has gone.
    func testA8_4_TwoSnackbarsInARowShowOneAfterTheOther() async throws {
        let router = router()
        let home = try await loaded(router, router.root)
        await home.run(.actionGroup(.init(actions: [snackbar("one"), snackbar("two")])))

        let queue = router.snackbars
        XCTAssertEqual(queue.queue.items.map(\.message), ["one", "two"], "the second replaced the first")
        XCTAssertEqual(home.toast?.message, "one")
        XCTAssertEqual(home.toast?.style, .snackbar)
        XCTAssertEqual(home.toast?.duration, 4)
        XCTAssertEqual(queue.queue.phase, .entering)

        pass(250 + 4000, queue)
        XCTAssertEqual(queue.queue.phase, .leaving)
        XCTAssertEqual(home.toast?.message, "one", "the first is still leaving")
        pass(249, queue)
        XCTAssertEqual(home.toast?.message, "one")

        pass(1, queue)
        XCTAssertEqual(home.toast?.message, "two", "the second enters once the first has left")
        XCTAssertEqual(queue.queue.phase, .entering)
        pass(250 + 4000 + 250, queue)
        XCTAssertNil(home.toast)
        XCTAssertNil(queue.queue.phase)
    }

    /// A8.4: a showToast between two showSnackbar waits its turn (one queue,
    /// as Flutter's floating toast shares the messenger, action_executor.dart
    /// :408-423): 2000 ms once in, then the second snackbar.
    func testA8_4_AToastBetweenTwoSnackbarsWaitsItsTurn() async throws {
        let router = router()
        let home = try await loaded(router, router.root)
        await home.run(.actionGroup(.init(actions: [snackbar("a"), toast("t"), snackbar("b")])))

        let queue = router.snackbars
        XCTAssertEqual(queue.queue.items.map(\.kind), [.snackbar, .toast, .snackbar])
        XCTAssertEqual(home.toast?.message, "a", "the toast jumped the queue")

        pass(250 + 4000 + 250, queue)
        XCTAssertEqual(home.toast?.message, "t")
        XCTAssertEqual(home.toast?.style, .toast)
        XCTAssertEqual(home.toast?.duration, 2)

        pass(250 + 1999, queue)
        XCTAssertEqual(queue.queue.phase, .showing)
        pass(1 + 250, queue)
        XCTAssertEqual(home.toast?.message, "b")
        XCTAssertEqual(home.toast?.style, .snackbar)
    }

    /// A8.4: a bar shown before a navigate is still the head on the pushed
    /// page, the same item, its time still running, not restarted (Flutter's
    /// pushed Scaffold shows the messenger's current bar, snack_bar.dart:898);
    /// and after going back.
    func testA8_4_ABarSurvivesANavigateWithItsTimeRunning() async throws {
        let router = router()
        let home = try await loaded(router, router.root)
        XCTAssertTrue(home.snackbars === router.snackbars, "the page does not use the router's queue")
        await home.run(snackbar("kept"))
        let shown = try XCTUnwrap(home.toast)
        let queue = router.snackbars
        pass(1000, queue)
        XCTAssertEqual(queue.queue.untilNextChangeMs, 3250)

        await home.run(.navigate(.init(route: "next")))
        XCTAssertEqual(router.top.path, "next")
        let next = try await loaded(router, router.top)
        XCTAssertTrue(next.snackbars === queue)
        XCTAssertEqual(next.toast?.id, shown.id, "the pushed page does not show the same bar")
        XCTAssertEqual(queue.queue.phase, .showing)
        XCTAssertEqual(queue.queue.untilNextChangeMs, 3250, "the bar's time restarted")

        pass(1000, queue)
        router.goBack()
        XCTAssertEqual(router.top.path, "home")
        XCTAssertEqual(home.toast?.id, shown.id)
        XCTAssertEqual(queue.queue.untilNextChangeMs, 2250)
        pass(2250 + 250, queue)
        XCTAssertNil(home.toast)
    }

    /// A8.4: the queue is the app's under tabs too: a tab switch keeps the
    /// bar and its time.
    func testA8_4_ABarSurvivesATabSwitchWithItsTimeRunning() async throws {
        let config = NavConfig(
            initialRoute: "/home",
            tabs: [TabDef(id: "home", label: "Home", icon: "home", initialRoute: "/home"),
                   TabDef(id: "cart", label: "Cart", icon: "cart", initialRoute: "/cart")],
            initialAppState: [:],
            flows: [NavFlow(name: "main", routes: [NavRoute(path: "home"), NavRoute(path: "cart")])])
        let router = OrcaRouter(client: PageStub.client(PageStub()), config: config,
                                system: SystemRecorder().actions())
        manual(router.snackbars)
        let home = try await loaded(router, router.top)
        await home.run(snackbar("kept"))
        let shown = try XCTUnwrap(home.toast)
        pass(1000, router.snackbars)

        await home.run(.switchTab(.init(tabId: "cart")))
        XCTAssertEqual(router.top.path, "cart")
        let cart = try await loaded(router, router.top)
        XCTAssertEqual(cart.toast?.id, shown.id)
        XCTAssertEqual(router.snackbars.queue.untilNextChangeMs, 3250, "the bar's time restarted")
    }

    /// A8.4: a server action the server refuses shows its message as a
    /// snackbar (Flutter action_executor.dart:721-724 runs showSnackbar with
    /// it): it joins the queue behind what is there, 4000 ms, replacing
    /// nothing.
    func testA8_4_ARefusedServerActionsMessageJoinsTheQueue() async throws {
        let client = OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                                device: DeviceInfo(osVersion: "test"), transport: RefusingStub())
        let model = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"), client: client)
        manual(model.snackbars)
        await model.run(snackbar("first"))
        await model.run(.serverAction(.init(id: "save")))

        let queue = model.snackbars.queue
        XCTAssertEqual(queue.items.map(\.message), ["first", "Not allowed"])
        XCTAssertEqual(queue.items.map(\.kind), [.snackbar, .snackbar])
        XCTAssertEqual(queue.items.map(\.durationMs), [4000, 4000])
        XCTAssertEqual(model.toast?.message, "first", "the refusal replaced the bar on screen")

        pass(250 + 4000 + 250, model.snackbars)
        XCTAssertEqual(model.toast?.message, "Not allowed")
    }

    /// A8.4, risk 9: a page with no router keeps a queue of its own; what it
    /// shows reaches no other page, and `toast` reads its head.
    func testA8_4_APageWithNoRouterKeepsAQueueOfItsOwn() async {
        let one = OrcaPageModel(page: PageResponse(pageId: "one", title: "One"))
        let two = OrcaPageModel(page: PageResponse(pageId: "two", title: "Two"))
        XCTAssertFalse(one.snackbars === two.snackbars)
        manual(one.snackbars)
        manual(two.snackbars)

        await one.run(.actionGroup(.init(actions: [snackbar("s"), toast("t")])))
        XCTAssertEqual(one.snackbars.queue.items.map(\.message), ["s", "t"])
        XCTAssertEqual(one.toast?.message, "s")
        XCTAssertNil(two.toast)
        XCTAssertTrue(two.snackbars.queue.items.isEmpty)
    }

    /// A8.4: `toast` is observable through the page model, as Kotlin's
    /// Compose state reading only the head: the model tells its views once
    /// per change of the head item (nil → a, a → b, b → nil), never at a
    /// phase change in between. On a page with its own queue, and on one a
    /// router attached to the app's.
    func testA8_4_TheModelTellsItsViewsOncePerHeadChange() async throws {
        let own = OrcaPageModel(page: PageResponse(pageId: "own", title: "Own"))
        manual(own.snackbars)
        let router = router()
        let routed = try await loaded(router, router.root)

        for model in [own, routed] {
            let queue = model.snackbars
            var sends = 0
            let watch = model.objectWillChange.sink { sends += 1 }
            defer { watch.cancel() }

            await model.run(.actionGroup(.init(actions: [snackbar("a"), snackbar("b")])))
            XCTAssertEqual(sends, 1, "\(model.page.pageId): a in")
            pass(250, queue)
            XCTAssertEqual(queue.queue.phase, .showing)
            pass(4000, queue)
            XCTAssertEqual(queue.queue.phase, .leaving)
            XCTAssertEqual(sends, 1, "\(model.page.pageId): a phase change was sent")
            pass(250, queue)
            XCTAssertEqual(model.toast?.message, "b")
            XCTAssertEqual(sends, 2, "\(model.page.pageId): a to b")
            pass(250 + 4000 + 250, queue)
            XCTAssertNil(model.toast)
            XCTAssertEqual(sends, 3, "\(model.page.pageId): b out")
        }
    }

    // MARK: - On screen (until S-bar draws M3's bar in the Scaffold)

    /// A8.4: the page draws the head while it is in, at the bottom in
    /// today's look: a snackbar across the width, a toast as a pill; nothing
    /// while it leaves or when the queue is idle. A page that did not show
    /// the bar draws it too: the queue is the router's.
    func testA8_4_ThePageDrawsTheHeadWhileItIsIn() async throws {
        let router = router()
        let home = try await loaded(router, router.root)
        await home.run(.actionGroup(.init(actions: [snackbar("one"), toast("t")])))
        router.navigate(to: "next")
        let next = try await loaded(router, router.top)
        let queue = router.snackbars

        for page in [home, next] {
            let bar = try XCTUnwrap(Self.bar(in: try draw(page)), "\(page.page.pageId): no bar while entering")
            XCTAssertEqual(bar.minX, 16, accuracy: 1, "\(page.page.pageId)")
            XCTAssertEqual(bar.maxX, 284, accuracy: 1, "\(page.page.pageId): not across the width")
            XCTAssertEqual(bar.maxY, 184, accuracy: 1, "\(page.page.pageId): not 16 above the bottom")
        }
        pass(250 + 2000, queue)
        XCTAssertNotNil(Self.bar(in: try draw(next)), "no bar while showing")
        pass(2000, queue)
        XCTAssertEqual(queue.queue.phase, .leaving)
        XCTAssertNil(Self.bar(in: try draw(next)), "the bar is drawn while it leaves")

        pass(250, queue)
        XCTAssertEqual(next.toast?.style, .toast)
        let pill = try XCTUnwrap(Self.bar(in: try draw(next)), "no toast")
        XCTAssertLessThan(pill.width, 268, "the toast spans the width")
        XCTAssertEqual(pill.maxY, 184, accuracy: 1)

        pass(250 + 2000 + 250, queue)
        XCTAssertNil(queue.queue.phase)
        XCTAssertNil(Self.bar(in: try draw(next)), "a bar with the queue idle")
    }

    #if canImport(UIKit)
    /// A8.4, hosted: the page on screen follows the queue as time passes in:
    /// a pushed page that never showed the bar draws it, drops it once it
    /// starts to leave, and draws the next show. Animations are off: with
    /// them on, this host kept drawing the leaving bar and never drew an
    /// entering one, as if the slide never ran; the 0.2 s slide and fade
    /// are a hand check.
    func testA8_4_AHostedPageFollowsTheRoutersQueue() async throws {
        let router = router()
        let home = try await loaded(router, router.root)
        await home.run(snackbar("kept"))
        router.navigate(to: "next")
        let next = try await loaded(router, router.top)
        let queue = router.snackbars

        let host = UIHostingController(rootView: OrcaPageView(model: next)
            .background(Color(.sRGB, red: 0, green: 0, blue: 1))
            .transaction { $0.disablesAnimations = true })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()

        pass(1000, queue)
        let shown = try XCTUnwrap(Self.bar(in: try snapshot(window)), "the pushed page draws no bar")
        XCTAssertEqual(shown.maxX - shown.minX, 268, accuracy: 1)

        pass(3250, queue)
        XCTAssertEqual(queue.queue.phase, .leaving)
        XCTAssertNil(Self.bar(in: try snapshot(window)), "the bar stayed once leaving")
        pass(250, queue)
        XCTAssertNil(queue.queue.phase)
        XCTAssertNil(Self.bar(in: try snapshot(window)), "a bar with the queue idle")

        await home.run(snackbar("again"))
        XCTAssertNotNil(Self.bar(in: try snapshot(window)), "the next show is not drawn")
    }

    /// The window at scale 1, once the views have caught up.
    private func snapshot(_ window: UIWindow) throws -> Pixels {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }
    #endif

    // MARK: - Pixels

    /// The page as OrcaPageView draws it, 300 x 200 over blue, at scale 1.
    private func draw(_ model: OrcaPageModel) throws -> Pixels {
        let renderer = ImageRenderer(content: OrcaPageView(model: model)
            .frame(width: 300, height: 200)
            .background(Color(.sRGB, red: 0, green: 0, blue: 1))
            .environment(\.colorScheme, .light))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "the page is not drawn"))
    }

    /// The bounds of today's bar fill (white 0.18) in the bottom half: nil
    /// when none is drawn.
    static func bar(in pixels: Pixels) -> CGRect? {
        let top = pixels.height / 2
        return pixels.rows(top...(pixels.height - 1)).bounds { p in
            p.a > 250 && abs(Int(p.r) - 46) <= 6 && abs(Int(p.g) - 46) <= 6 && abs(Int(p.b) - 46) <= 6
        }.map { $0.offsetBy(dx: 0, dy: CGFloat(top)) }
    }
}

/// Every request refused with 403 `{"error": "Not allowed"}`: a server
/// action the server turns down.
private final class RefusingStub: HTTPTransport, @unchecked Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(status: 403, body: Data(#"{"error":"Not allowed"}"#.utf8))
    }
}
#endif
