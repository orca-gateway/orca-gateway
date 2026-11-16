#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A8.4 (design D8): the app queue's head, when it is a snackbar, is drawn
/// as Flutter's M3 fixed SnackBar in the root Scaffold on screen
/// (material scaffold.dart:229-262, :1236-1237, :1340-1352, snack_bar.dart
/// :690-905): full width, square, inverseSurface #322F35, bodyMedium
/// #F5EFF7 14/20 with padding 24 each side and 14 above and below, the
/// bottom safe area inside it when no bottom bar is under it, at the content
/// bottom above the bottom bars, over the bottomSheet slot, the FAB lifted
/// 16 above it; revealed by height through fastOutSlowIn, never faded; a
/// swipe down slides it and takes it off at once. With tabs the shell's
/// Scaffold draws it above the tab bar (orca_shell.dart:114-117); a nested
/// Scaffold draws none; with no Scaffold nothing is drawn while the queue
/// still times it. Time is passed in: each queue runs on `now`.
@MainActor
final class SnackbarBarTests: XCTestCase {
    static let accuracy: CGFloat = 1
    private var now: Double = 1_000_000

    /// `snackbars` on the test's clock, with no wake of its own.
    private func manual(_ snackbars: OrcaSnackbars) {
        snackbars.clock = { [unowned self] in self.now }
        snackbars.sleep = nil
    }

    private func pass(_ ms: Double, _ snackbars: OrcaSnackbars) {
        now += ms
        snackbars.tick()
    }

    private func snackbar(_ message: String) -> Action {
        .showSnackbar(.init(message: .string(message)))
    }

    // MARK: - The look

    /// A8.4: fully in, the bar is 300 wide (the Scaffold's width), 48 tall
    /// (14 + one 20 line + 14) at the bottom, square, #322F35, with no shadow
    /// above it (snack_bar.dart:901 clips the elevation-6 Material to the
    /// bar); its text starts 24 in and lies inside the 14 padding.
    func testA8_4_TheBarIsM3sFixedBarFullWidthSquareOnInverseSurface() async throws {
        let model = try page([scaffold("page", ["body": "body"]), fill("body", "#00FF00")])
        await model.run(snackbar("Saved"))
        pass(250, model.snackbars)

        let pixels = try draw(model, width: 300, height: 400)
        let bar = try XCTUnwrap(pixels.bounds(of: Self.isBar), "no bar")
        assertFrame(bar, CGRect(x: 0, y: 352, width: 300, height: 48), "the bar")
        for (x, y) in [(0, 352), (299, 352), (0, 399), (299, 399)] {
            XCTAssertTrue(Self.isBar(pixels.pixel(x, y)), "corner (\(x), \(y)) is not square")
        }
        XCTAssertTrue(FlowTests.isGreen(pixels.pixel(150, 350)), "a shadow above the bar")
        let text = try XCTUnwrap(pixels.rows(352...399).bounds(of: Self.isLight), "no text")
            .offsetBy(dx: 0, dy: 352)
        XCTAssertEqual(text.minX, 24, accuracy: 1.5, "the text's start padding")
        XCTAssertGreaterThanOrEqual(text.minY, 366, "the text above the 14 padding")
        XCTAssertLessThanOrEqual(text.maxY, 386, "the text below the 14 padding")

        // At scale 3 the stems are wide enough to show the text's own colour.
        let sharp = try draw(model, width: 300, height: 400, scale: 3)
        let rows = sharp.rows((352 * 3)...(400 * 3 - 1))
        var found = false
        for y in 0..<rows.height {
            for x in 0..<rows.width where Self.near(rows.pixel(x, y), (0xF5, 0xEF, 0xF7), 4) { found = true }
        }
        XCTAssertTrue(found, "no pixel of #F5EFF7 in the bar")
        XCTAssertNil(rows.bounds(of: { $0.r > 250 && $0.g > 250 && $0.b > 250 }), "white text")
    }

    /// A8.4: the message is Flutter's `Text(message)`, which wraps (the 14
    /// is the single-line padding, snack_bar.dart:29, :793): a long one
    /// takes two 20 lines, 68 in all. The bar's text has every Text's line
    /// box (TextNodeView's `height`), whose SwiftUI line runs up to about a
    /// point over Flutter's 20.02 a line: two lines land within 2 of 68,
    /// one line or three far outside it.
    func testA8_4_ALongMessageWrapsAsFlutterTextDoes() async throws {
        let model = try page([scaffold("page", ["body": "body"]), fill("body", "#00FF00")])
        await model.run(snackbar("A message long enough to need a second line in a bar of three hundred"))
        pass(250, model.snackbars)

        let bar = try XCTUnwrap(try draw(model, width: 300, height: 400).bounds(of: Self.isBar))
        XCTAssertEqual(bar.width, 300, accuracy: Self.accuracy)
        XCTAssertEqual(bar.maxY, 400, accuracy: Self.accuracy)
        XCTAssertEqual(bar.height, 68, accuracy: 2, "not two lines: \(bar)")
    }

    // MARK: - Where it is drawn

    /// A8.4: above the bottomNavigationBar and the persistent footer
    /// (contentBottom, scaffold.dart:1171-1176, :1340-1352), which stay as
    /// they are.
    func testA8_4_TheBarSitsAboveTheBottomBarAndTheFooter() async throws {
        let model = try page([
            scaffold("page", ["body": "body", "bottomNavigationBar": "nav"]), fill("body", "#00FF00"),
            box("nav", "#FF00FF", 300, 50),
            scaffold("footed", ["body": "body2", "bottomNavigationBar": "nav2", "persistentFooterButton_0": "foot"]),
            fill("body2", "#00FF00"), box("nav2", "#FF00FF", 300, 50), box("foot", "#0000FF", 40, 20),
        ])
        await model.run(snackbar("Saved"))
        pass(250, model.snackbars)

        let plain = try draw(model, width: 300, height: 400)
        assertFrame(plain.bounds(of: Self.isBar), CGRect(x: 0, y: 302, width: 300, height: 48), "over the bar")
        assertFrame(plain.bounds(of: FlowTests.isMagenta), CGRect(x: 0, y: 350, width: 300, height: 50), "the bar")

        // The footer: 8 + 20 + 8 above the 50 bar.
        let footed = try draw(model, "footed", width: 300, height: 400)
        assertFrame(footed.bounds(of: Self.isBar), CGRect(x: 0, y: 266, width: 300, height: 48), "over the footer")
        assertFrame(footed.bounds(of: Self.isBlue), CGRect(x: 252, y: 322, width: 40, height: 20), "the footer")
    }

    /// A8.4: the bar paints over the bottomSheet slot (painted after it,
    /// scaffold.dart:3254-3285): the sheet's top shows above the bar.
    func testA8_4_TheBarPaintsOverTheBottomSheetSlot() async throws {
        let model = try page([
            scaffold("page", ["body": "body", "bottomSheet": "s"]), fill("body", "#00FF00"),
            box("s", "#FF0000", 120, 100),
        ])
        await model.run(snackbar("Saved"))
        pass(250, model.snackbars)

        let pixels = try draw(model, width: 300, height: 400)
        assertFrame(pixels.bounds(of: Self.isBar), CGRect(x: 0, y: 352, width: 300, height: 48), "the bar")
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 90, y: 300, width: 120, height: 52),
                    "the sheet above the bar")
    }

    /// A8.4: the FAB (endFloat) rises 16 above the bar
    /// (floating_action_button_location.dart:565-586: contentBottom -
    /// snackBarHeight - fabHeight - 16), or above a sheet when that is
    /// higher; it paints over both.
    func testA8_4_TheFabRisesAboveTheBar() async throws {
        let model = try page([
            scaffold("page", ["body": "body", "floatingActionButton": "f"]), fill("body", "#00FF00"),
            scaffold("sheeted", ["body": "body2", "floatingActionButton": "f2", "bottomSheet": "s"]),
            fill("body2", "#00FF00"), fab("f", "i"), fab("f2", "i2"), icon("i"), icon("i2"),
            box("s", "#0000FF", 120, 120),
        ])
        assertFrame(try draw(model, width: 300, height: 400).bounds(of: Pixels.isRed),
                    CGRect(x: 228, y: 328, width: 56, height: 56), "no bar")
        await model.run(snackbar("Saved"))
        pass(250, model.snackbars)

        assertFrame(try draw(model, width: 300, height: 400).bounds(of: Pixels.isRed),
                    CGRect(x: 228, y: 280, width: 56, height: 56), "400 - 48 - 16 - 56")
        assertFrame(try draw(model, "sheeted", width: 300, height: 400).bounds(of: Pixels.isRed),
                    CGRect(x: 228, y: 252, width: 56, height: 56), "the sheet is higher: 400 - 120 - 28")
    }

    /// A8.4: entering, the bar is revealed by height, not faded
    /// (snack_bar.dart:830, :881-891): at 125 of 250 ms the queue's reveal is
    /// 0.5, fastOutSlowIn gives 0.7756, so 37.2 of its 48 show at the bottom,
    /// the top of the bar first, opaque; the FAB rides on it. Leaving, the
    /// same curve backwards.
    func testA8_4_TheBarIsRevealedByHeightWithNoFade() async throws {
        let model = try page([
            scaffold("page", ["body": "body", "floatingActionButton": "f"]), fill("body", "#00FF00"),
            fab("f", "i"), icon("i"),
        ])
        await model.run(snackbar("Saved"))
        let queue = model.snackbars
        XCTAssertEqual(queue.reveal, 0)
        XCTAssertNil(try draw(model, width: 300, height: 400).bounds(of: Self.isBar), "drawn before it moved")

        pass(125, queue)
        XCTAssertEqual(queue.reveal, 0.5, accuracy: 0.0001)
        let shown = 48 * 0.7755613
        let entering = try draw(model, width: 300, height: 400)
        let bar = try XCTUnwrap(entering.bounds(of: Self.isBar), "nothing at mid-entry")
        XCTAssertEqual(bar.minY, 400 - shown, accuracy: Self.accuracy, "not revealed by height")
        XCTAssertEqual(bar.maxY, 400, accuracy: Self.accuracy)
        XCTAssertTrue(Self.isBar(entering.pixel(5, 395)), "faded: \(entering.pixel(5, 395))")
        let text = try XCTUnwrap(entering.rows(Int(bar.minY)...399).bounds(of: Self.isLight), "no text")
        let fab = try XCTUnwrap(entering.bounds(of: Pixels.isRed))
        XCTAssertEqual(fab.minY, 400 - shown - 16 - 56, accuracy: Self.accuracy, "the FAB does not ride on it")

        // The text lies as far below the shown top as below a full bar's top.
        pass(125, queue)
        let full = try draw(model, width: 300, height: 400)
        let fullText = try XCTUnwrap(full.rows(352...399).bounds(of: Self.isLight), "no text fully in")
        XCTAssertEqual(text.minY, fullText.minY, accuracy: Self.accuracy, "the bar's top is not what shows first")

        pass(4000 + 125, queue)
        XCTAssertEqual(queue.queue.phase, .leaving)
        XCTAssertEqual(queue.reveal, 0.5, accuracy: 0.0001)
        let leaving = try XCTUnwrap(try draw(model, width: 300, height: 400).bounds(of: Self.isBar))
        XCTAssertEqual(leaving.minY, 400 - shown, accuracy: Self.accuracy, "leaving")
        pass(125, queue)
        XCTAssertNil(try draw(model, width: 300, height: 400).bounds(of: Self.isBar), "drawn once gone")
    }

    /// A8.4: only the root Scaffold draws it (scaffold.dart:260-263): a
    /// Scaffold in another's body draws none above its own bottom bar; the
    /// outer one's bar covers that bar.
    func testA8_4_ANestedScaffoldDrawsNoBar() async throws {
        let model = try page([
            scaffold("page", ["body": "inner"]),
            scaffold("inner", ["body": "body", "bottomNavigationBar": "nav"]), fill("body", "#00FF00"),
            box("nav", "#FF00FF", 300, 40),
        ])
        await model.run(snackbar("Saved"))
        pass(250, model.snackbars)

        let pixels = try draw(model, width: 300, height: 400)
        assertFrame(pixels.bounds(of: Self.isBar), CGRect(x: 0, y: 352, width: 300, height: 48), "one bar")
        XCTAssertNil(pixels.bounds(of: FlowTests.isMagenta), "the inner bar shows over the outer's")
    }

    /// A8.4: with no Scaffold on screen nothing is drawn, neither the bar
    /// nor the old look, while the queue still times it (Flutter release).
    func testA8_4_WithNoScaffoldNothingIsDrawnAndTheQueueStillTimesIt() async throws {
        let model = try page([node("col", "Column", [:], ["t"]),
                              node("t", "Text", ["data": "plain"], kind: "primitive")])
        await model.run(snackbar("Saved"))
        pass(250, model.snackbars)

        let pixels = try drawPage(model, width: 300, height: 200)
        XCTAssertNil(pixels.bounds(of: Self.isBar), "a bar with no Scaffold")
        XCTAssertNil(pixels.bounds(of: Self.isPill), "the old snackbar look")
        pass(4000, model.snackbars)
        XCTAssertEqual(model.snackbars.queue.phase, .leaving, "not timed")
    }

    /// A8.4: ToastView draws toasts only, in today's pill; a snackbar head
    /// is the Scaffold's to draw.
    func testA8_4_AToastKeepsItsPillAndASnackbarIsNotOne() async throws {
        let model = try page([scaffold("page", ["body": "body"]), fill("body", "#00FF00")])
        await model.run(.actionGroup(.init(actions: [snackbar("s"), .showToast(.init(message: .string("t")))])))
        pass(250, model.snackbars)
        let first = try drawPage(model, width: 300, height: 200)
        XCTAssertNil(first.bounds(of: Self.isPill), "the snackbar is drawn as a pill too")
        XCTAssertNotNil(first.bounds(of: Self.isBar))

        pass(4000 + 250 + 250, model.snackbars)
        XCTAssertEqual(model.toast?.style, .toast)
        let toast = try drawPage(model, width: 300, height: 200)
        let pill = try XCTUnwrap(toast.bounds(of: Self.isPill), "no toast")
        XCTAssertLessThan(pill.width, 268, "the toast spans the width")
        XCTAssertEqual(pill.maxY, 184, accuracy: Self.accuracy)
        // The full-width bar would cover both edges (the pill's anti-aliased
        // text may come near its colour).
        XCTAssertFalse(Self.isBar(toast.pixel(1, 195)) || Self.isBar(toast.pixel(298, 195)),
                       "a toast drawn as the bar")
    }

    /// A8.4: a pushed page shows the same bar, its time still running
    /// (Flutter's pushed Scaffold registers with the messenger, Hero
    /// snack_bar.dart:898): drawn on both pages at the same place.
    func testA8_4_APushedPageShowsTheSameBarItsTimeRunning() async throws {
        let pages = ScaffoldPages(components: [
            "home": [scaffold("h", ["body": "hb"]), fill("hb", "#00FF00")],
            "next": [scaffold("n", ["body": "nb"]), fill("nb", "#00FF00")],
        ])
        let router = OrcaRouter(client: pages.client, path: "home", system: SystemRecorder().actions())
        manual(router.snackbars)
        let home = try await loaded(router, router.root)
        await home.run(snackbar("kept"))
        pass(250 + 1000, router.snackbars)

        router.navigate(to: "next")
        let next = try await loaded(router, router.top)
        XCTAssertEqual(next.toast?.id, home.toast?.id)
        XCTAssertEqual(router.snackbars.queue.untilNextChangeMs, 3000, "the bar's time restarted")
        for model in [home, next] {
            let pixels = try draw(model, model.renderer.rootId ?? "", width: 300, height: 400)
            assertFrame(pixels.bounds(of: Self.isBar), CGRect(x: 0, y: 352, width: 300, height: 48),
                        model.page.pageId)
        }
    }

    // MARK: - The swipe

    /// A8.4: a drag down slides the bar with the finger inside its own
    /// bounds (Dismissible in the ClipRect, snack_bar.dart:859-871, :901),
    /// showing what lies under it.
    func testA8_4_ADragSlidesTheBarDownInsideItsBounds() throws {
        let renderer = ImageRenderer(content: VStack(spacing: 0) {
            Color.clear
            SnackbarBar(message: "Saved", heightFactor: 1, drag: 20)
        }
        .frame(width: 300, height: 100)
        .background(Color(.sRGB, red: 0, green: 1, blue: 0))
        .environment(\.colorScheme, .light))
        renderer.scale = 1
        let pixels = try Pixels(XCTUnwrap(renderer.cgImage))
        assertFrame(pixels.bounds(of: Self.isBar), CGRect(x: 0, y: 72, width: 300, height: 28), "slid by 20")
        XCTAssertTrue(FlowTests.isGreen(pixels.pixel(150, 60)), "the bar's place does not show what is under it")
    }

    /// A8.4: Flutter's Dismissible rules for the release
    /// (widgets/dismissible.dart:19-22, :477-497, :528-536): past 0.4 of the
    /// height it goes; a fling down of 700 or more whose vertical speed beats
    /// the horizontal by 400 goes whatever the distance; a fling up or a
    /// slow release short of 0.4 comes back.
    func testA8_4_TheReleaseDismissesPast40PercentOrOnAFlingDown() {
        XCTAssertFalse(SnackbarSwipe.dismisses(drag: 19, velocity: nil, height: 48), "0.396")
        XCTAssertTrue(SnackbarSwipe.dismisses(drag: 20, velocity: nil, height: 48), "0.417")
        XCTAssertTrue(SnackbarSwipe.dismisses(drag: 5, velocity: CGSize(width: 0, height: 800), height: 48))
        XCTAssertFalse(SnackbarSwipe.dismisses(drag: 5, velocity: CGSize(width: 0, height: 650), height: 48))
        XCTAssertFalse(SnackbarSwipe.dismisses(drag: 5, velocity: CGSize(width: 500, height: 800), height: 48))
        XCTAssertFalse(SnackbarSwipe.dismisses(drag: 30, velocity: CGSize(width: 0, height: -900), height: 48),
                       "a fling back up")
        XCTAssertFalse(SnackbarSwipe.dismisses(drag: 0, velocity: CGSize(width: 0, height: 900), height: 48),
                       "no displacement")
    }

    /// A8.4: the swipe takes the bar off at once, with no leave, and the next
    /// enters from nothing (removeCurrentSnackBar, snack_bar.dart:865); a
    /// swipe of a bar that is no longer the head changes nothing.
    func testA8_4_ASwipeRemovesTheBarAtOnceAndTheNextEnters() async throws {
        let model = try page([scaffold("page", ["body": "body"]), fill("body", "#00FF00")])
        await model.run(.actionGroup(.init(actions: [snackbar("one"), snackbar("two")])))
        let queue = model.snackbars
        pass(250 + 1000, queue)
        let one = try XCTUnwrap(model.toast)

        queue.swipe(one)
        XCTAssertEqual(model.toast?.message, "two")
        XCTAssertEqual(queue.queue.phase, .entering)
        XCTAssertEqual(queue.reveal, 0)
        XCTAssertNil(try draw(model, width: 300, height: 400).bounds(of: Self.isBar), "the swiped bar is drawn")
        pass(250, queue)
        assertFrame(try draw(model, width: 300, height: 400).bounds(of: Self.isBar),
                    CGRect(x: 0, y: 352, width: 300, height: 48), "the next")

        queue.swipe(one)
        XCTAssertEqual(model.toast?.message, "two", "a stale swipe took the next")
        XCTAssertEqual(queue.queue.phase, .showing)
    }

    // MARK: - The shell

    /// A8.4 (group 3 review, finding 2): the shell's own trees, the server
    /// tab bar and the server drawer, show their snackbars on the app's
    /// queue, as Flutter's shell executor reaches the root messenger.
    func testA8_4_TheShellTreesShowTheirSnackbarsOnTheAppsQueue() async throws {
        let text: JSONValue = ["id": "t", "type": "Text", "kind": "primitive", "childMode": "none",
                               "props": ["data": "bar"], "children": [], "watches": []]
        let config: JSONValue = [
            "initialRoute": "/home",
            "tabs": [["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"],
                     ["id": "more", "label": "More", "icon": "menu", "initialRoute": "/more"]],
            "drawerItems": [["id": "more", "label": "More", "route": "/more"]],
            "tabBarComponents": [text], "drawerComponents": [text],
            "flows": [["name": "main", "routes": [["path": "home"], ["path": "more"]]]],
        ]
        let router = OrcaRouter(client: ScaffoldPages(components: [:]).client,
                                config: try config.decode(NavConfig.self), system: SystemRecorder().actions())
        manual(router.snackbars)
        let shell = TabShellModel(router: router)
        let trees = [try XCTUnwrap(shell.bar), try XCTUnwrap(shell.drawer)]
        for (index, tree) in trees.enumerated() {
            XCTAssertTrue(tree.page.snackbars === router.snackbars, "tree \(index) keeps a queue of its own")
            await tree.page.run(snackbar("from \(index)"))
        }
        XCTAssertEqual(router.snackbars.queue.items.map(\.message), ["from 0", "from 1"])
    }

    #if canImport(UIKit)
    /// A8.4: under tabs the shell draws the bar right above the tab bar
    /// (OrcaShell's Scaffold, orca_shell.dart:114-117), over the tab page;
    /// the page's own Scaffold, nested in the shell's, draws none, so its
    /// bottom bar (40) is covered, not raised above.
    func testA8_4_UnderTabsTheShellDrawsTheBarAboveTheTabBar() async throws {
        let config: JSONValue = [
            "initialRoute": "/home",
            "tabs": [["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"],
                     ["id": "more", "label": "More", "icon": "menu", "initialRoute": "/more"]],
            "flows": [["name": "main", "routes": [["path": "home"], ["path": "more"]]]],
        ]
        let pages = SafeAreaShellPages(components: ["home": [
            scaffold("s", ["body": "b", "bottomNavigationBar": "nav"]), fill("b", "#00FF00"),
            box("nav", "#FF00FF", 300, 40),
        ]])
        let router = OrcaRouter(client: pages.client, config: try config.decode(NavConfig.self),
                                system: SystemRecorder().actions())
        manual(router.snackbars)
        let window = try await show(router)
        defer { window.isHidden = true }
        let home = try await loaded(router, router.root)
        await home.run(snackbar("Saved"))
        pass(250, router.snackbars)

        let tabs = try XCTUnwrap(SafeAreaShellTests.tabBar(in: window), "no tab bar")
        let tabsTop = tabs.convert(tabs.bounds, to: window).minY
        let pixels = try snapshot(window)
        let bar = try XCTUnwrap(pixels.bounds(of: Self.isBar), "no bar")
        XCTAssertEqual(bar.maxY, tabsTop, accuracy: Self.accuracy, "not right above the tab bar")
        XCTAssertEqual(bar.height, 48, accuracy: Self.accuracy, "two bars, or one with the inset inside")
        XCTAssertEqual(bar.width, 300, accuracy: Self.accuracy)
        XCTAssertNil(pixels.bounds(of: FlowTests.isMagenta), "the page's bar shows over the shell's")
    }

    /// A8.4: with no bottom bar the bar reaches the bottom edge and holds the
    /// bottom safe area inside it (SafeArea(top: false), snack_bar.dart
    /// :812): 48 + 20 tall, its text above the inset; above a bottom bar the
    /// inset is the bar's (removeBottomPadding, scaffold.dart:3273-3285).
    /// The FAB keeps 16 above the inset before (safeMargin,
    /// floating_action_button_location.dart:571-574) and 16 above the bar
    /// after.
    func testA8_4_TheBottomSafeAreaIsInsideTheBar() async throws {
        for (nav, expected, fabBefore) in [(false, CGRect(x: 0, y: 432, width: 300, height: 68), 408.0),
                                           (true, CGRect(x: 0, y: 392, width: 300, height: 48), 368.0)] {
            var slots = ["body": "b", "floatingActionButton": "f"]
            if nav { slots["bottomNavigationBar"] = "nav" }
            var nodes = [scaffold("s", slots), fill("b", "#00FF00"), fab("f", "i"), icon("i")]
            if nav { nodes.append(box("nav", "#FF00FF", 300, 40)) }
            let router = OrcaRouter(client: SafeAreaShellPages(components: ["page": nodes]).client, path: "page",
                                    system: SystemRecorder().actions())
            manual(router.snackbars)
            let window = try await show(router)
            defer { window.isHidden = true }
            assertFrame(try snapshot(window).bounds(of: Pixels.isRed),
                        CGRect(x: 228, y: fabBefore, width: 56, height: 56), "nav \(nav): the FAB with no bar")
            let page = try await loaded(router, router.root)
            await page.run(snackbar("Saved"))
            pass(250, router.snackbars)

            let pixels = try snapshot(window)
            assertFrame(pixels.bounds(of: Self.isBar), expected, "nav \(nav)")
            let text = try XCTUnwrap(pixels.rows(Int(expected.minY)...Int(expected.maxY) - 1)
                .bounds(of: Self.isLight), "nav \(nav): no text")
            XCTAssertLessThanOrEqual(text.maxY, 48 - 14, "nav \(nav): the text runs into the inset")
            assertFrame(pixels.bounds(of: Pixels.isRed),
                        CGRect(x: 228, y: expected.minY - 16 - 56, width: 56, height: 56), "nav \(nav): the FAB")
        }
    }

    /// A8.4: a titled route (a tabbed config's route outside every tab) is
    /// wrapped by Flutter in a root Scaffold of its own
    /// (navigation_handler.dart:111-147, :372; orca_page.dart:218-247): its
    /// bar shows at the bottom edge with the inset inside even when the page
    /// has no Scaffold, and a Scaffold in the page is nested: it draws none
    /// and its FAB does not rise (the wrapper's bar paints over the FAB's
    /// foot, as the wrapper's snackbar slot paints over its body).
    func testA8_4_ATitledRouteDrawsTheBarAtTheEdgeAndItsPagesScaffoldIsNested() async throws {
        let column = [node("col", "Column", [:], ["t"]), node("t", "Text", ["data": "login"], kind: "primitive")]
        let scaffolded = [scaffold("s", ["body": "b", "floatingActionButton": "f"]), fill("b", "#00FF00"),
                          fab("f", "i"), icon("i")]
        for (name, nodes) in [("column", column), ("scaffold", scaffolded)] {
            let router = try titledRouter(nodes)
            XCTAssertNotNil(router.root.scaffoldTitle, "\(name): not a titled route")
            let window = try await show(router)
            defer { window.isHidden = true }
            if name == "scaffold" {
                assertFrame(try snapshot(window).bounds(of: Pixels.isRed),
                            CGRect(x: 228, y: 408, width: 56, height: 56), "the FAB with no bar")
            }
            let page = try await loaded(router, router.root)
            await page.run(snackbar("Saved"))
            pass(250, router.snackbars)

            let pixels = try snapshot(window)
            assertFrame(Self.bottomBar(in: pixels), CGRect(x: 0, y: 432, width: 300, height: 68), name)
            if name == "scaffold" {
                assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 228, y: 408, width: 56, height: 24),
                            "the nested Scaffold's FAB rose, or painted over the wrapper's bar")
            }
        }
    }

    /// A8.4: in landscape the bar still runs edge to edge, the side insets
    /// inside it with the bottom one (the snackbar slot keeps its left and
    /// right padding, scaffold.dart:3277-3279; SafeArea, snack_bar.dart:812):
    /// in a page's root Scaffold and over a titled route alike.
    func testA8_4_TheBarRunsEdgeToEdgeWithTheSideInsetsInside() async throws {
        let insets = UIEdgeInsets(top: 30, left: 44, bottom: 20, right: 44)
        let scaffolded = [scaffold("s", ["body": "b"]), fill("b", "#00FF00")]
        let column = [node("col", "Column", [:], ["t"]), node("t", "Text", ["data": "login"], kind: "primitive")]
        for (name, router) in [
            ("scaffold", OrcaRouter(client: SafeAreaShellPages(components: ["page": scaffolded]).client, path: "page",
                                    system: SystemRecorder().actions())),
            ("titled", try titledRouter(column)),
        ] {
            manual(router.snackbars)
            let window = try await show(router, insets: insets)
            defer { window.isHidden = true }
            let page = try await loaded(router, router.root)
            await page.run(snackbar("Saved"))
            pass(250, router.snackbars)

            let pixels = try snapshot(window)
            assertFrame(Self.bottomBar(in: pixels), CGRect(x: 0, y: 432, width: 300, height: 68), name)
            let text = try XCTUnwrap(pixels.rows(432...499).bounds(of: Self.isLight), "\(name): no text")
            XCTAssertEqual(text.minX, 44 + 24, accuracy: 1.5, "\(name): the text's start")
            XCTAssertLessThanOrEqual(text.maxY, 48 - 14, "\(name): the text runs into the bottom inset")
        }
    }

    /// A8.4: VoiceOver hears each bar once, as it first appears (Flutter's
    /// live region, snack_bar.dart:849-851): not again on a pushed page
    /// drawing the same bar, then the next bar.
    func testA8_4_VoiceOverHearsEachBarOnceAsItAppears() async throws {
        var heard: [String] = []
        let announcer = OrcaSnackbars.announcer
        OrcaSnackbars.announcer = { heard.append($0) }
        defer { OrcaSnackbars.announcer = announcer }
        let scaffolded = [scaffold("s", ["body": "b"]), fill("b", "#00FF00")]
        let router = OrcaRouter(client: SafeAreaShellPages(components: ["page": scaffolded, "next": scaffolded]).client,
                                path: "page", system: SystemRecorder().actions())
        manual(router.snackbars)
        let window = try await show(router)
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        await page.run(.actionGroup(.init(actions: [snackbar("one"), snackbar("two")])))
        pass(250, router.snackbars)
        _ = try snapshot(window)
        XCTAssertEqual(heard, ["one"])

        router.navigate(to: "next")
        _ = try await loaded(router, router.top)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        assertFrame(Self.bottomBar(in: try snapshot(window)), CGRect(x: 0, y: 432, width: 300, height: 68),
                    "the pushed page's bar")
        XCTAssertEqual(heard, ["one"], "the same bar was read out again")

        pass(4000 + 250 + 250, router.snackbars)
        _ = try snapshot(window)
        XCTAssertEqual(heard, ["one", "two"])
    }

    /// A8.4: VoiceOver's escape gesture on the bar is Flutter's semantics
    /// dismiss (snack_bar.dart:849-853): the bar goes at once and the next
    /// enters. The bar is one element labelled with its message.
    func testA8_4_VoiceOversEscapeDropsTheBar() async throws {
        let scaffolded = [scaffold("s", ["body": "b"]), fill("b", "#00FF00")]
        let router = OrcaRouter(client: SafeAreaShellPages(components: ["page": scaffolded]).client, path: "page",
                                system: SystemRecorder().actions())
        manual(router.snackbars)
        let window = try await show(router)
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        await page.run(.actionGroup(.init(actions: [snackbar("one"), snackbar("two")])))
        pass(250 + 1000, router.snackbars)

        let restore = SnackBarWidgetTests.automation(true)
        defer { _ = SnackBarWidgetTests.automation(restore) }
        _ = try snapshot(window)
        let element = try XCTUnwrap(SnackBarWidgetTests.element(labelled: "one", in: window), "no element for the bar")
        XCTAssertTrue(element.accessibilityPerformEscape(), "escape not taken")
        XCTAssertEqual(page.toast?.message, "two")
        XCTAssertEqual(router.snackbars.queue.phase, .entering)
    }

    /// A8.4: a release is measured against the whole bar (the Dismissible's
    /// child), not the part shown while it enters: half shown, it still
    /// reports its full 48.
    func testA8_4_TheReleaseIsMeasuredAgainstTheWholeBar() async throws {
        var reported: CGFloat = 0
        let host = UIHostingController(rootView: VStack(spacing: 0) {
            Color.clear
            SnackbarBar(message: "Saved", heightFactor: 0.5)
        }
        .onPreferenceChange(SnackbarHeightKey.self) { reported = $0 })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.view.frame = window.bounds
        _ = try snapshot(window)
        XCTAssertEqual(reported, 48, accuracy: 1)
        XCTAssertEqual(try XCTUnwrap(try snapshot(window).bounds(of: Self.isBar)).height, 24, accuracy: 1,
                       "half of it is not what shows")
    }

    /// A router whose first page is `/login`, a route outside the tab
    /// `/home`: one stack, its root a titled route. The page `login` is
    /// `components`; the router is on the test's clock.
    private func titledRouter(_ components: [JSONValue]) throws -> OrcaRouter {
        let config: JSONValue = [
            "initialRoute": "/login",
            "tabs": [["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"]],
            "flows": [["name": "main", "routes": [["path": "home"], ["path": "login"]]]],
        ]
        let router = OrcaRouter(client: SafeAreaShellPages(components: ["login": components]).client,
                                config: try config.decode(NavConfig.self), system: SystemRecorder().actions())
        manual(router.snackbars)
        return router
    }

    /// OrcaApp on `router` in a light 300 x 500 window whose safe area is
    /// `insets` (top 30, bottom 20 by default), once its first page has
    /// loaded and settled.
    private func show(_ router: OrcaRouter, insets: UIEdgeInsets? = nil) async throws -> UIWindow {
        let host = UIHostingController(rootView: OrcaApp(router: router))
        host.additionalSafeAreaInsets = insets ?? SafeAreaShellTests.insets
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 300, height: 500))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        _ = try await loaded(router, router.root, waits: true)
        try await Task.sleep(nanoseconds: 500_000_000)
        return window
    }

    /// The bar's colour in the window's bottom 200 rows, below any title:
    /// black text anti-aliases to greys within the bar colour's tolerance.
    static func bottomBar(in pixels: Pixels) -> CGRect? {
        pixels.rows(300...499).bounds(of: isBar).map { $0.offsetBy(dx: 0, dy: 300) }
    }

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

    // MARK: - Pages

    /// The route's page once loaded; `waits`: it is loading on screen, so
    /// wait for it rather than load it here.
    private func loaded(_ router: OrcaRouter, _ route: OrcaRoute, waits: Bool = false) async throws
        -> OrcaPageModel {
        let loader = router.loader(for: route)
        if waits {
            for _ in 0..<30 {
                if case .loaded = loader.phase { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        } else {
            await loader.loadIfNeeded()
        }
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "SnackbarBarTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
        }
        return model
    }

    /// A page of `nodes` (the first is the root) on the test's clock.
    private func page(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        let model = OrcaPageModel(page: response)
        manual(model.snackbars)
        return model
    }

    private func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
                      _ children: [String] = [], kind: String = "layout") -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": .string(kind),
            "childMode": children.count > 1 || ["Column", "Row"].contains(type) ? "multi"
                : children.isEmpty ? "none" : "single",
            "props": .object(props), "children": .array(children.map(JSONValue.string)), "watches": [],
        ]
    }

    /// A Scaffold, its slot props holding the ids of nodes listed as its children.
    private func scaffold(_ id: String, _ slots: [String: String]) -> JSONValue {
        ["id": .string(id), "type": "Scaffold", "kind": "structure", "childMode": "none",
         "props": .object(slots.mapValues(JSONValue.string)),
         "children": .array(slots.values.sorted().map(JSONValue.string)), "watches": []]
    }

    private func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    private func fill(_ id: String, _ hex: String) -> JSONValue {
        node(id, "Container", ["color": .string(hex)])
    }

    /// A red 56 FAB with no shadow, holding icon `icon`.
    private func fab(_ id: String, _ icon: String) -> JSONValue {
        node(id, "FloatingActionButton", ["backgroundColor": "#E53935", "elevation": 0], [icon], kind: "button")
    }

    private func icon(_ id: String) -> JSONValue {
        node(id, "Icon", [:], kind: "primitive")
    }

    // MARK: - Pixels

    /// Node `id` (default the root, "page") in a light `width` x `height`
    /// picture over blue, at `scale`.
    private func draw(_ model: OrcaPageModel, _ id: String = "page", width: CGFloat, height: CGFloat,
                      scale: CGFloat = 1) throws -> Pixels {
        let renderer = ImageRenderer(content: NodeView(id: id, model: model)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Color(.sRGB, red: 0, green: 0, blue: 1))
            .environment(\.colorScheme, .light))
        renderer.scale = scale
        return try Pixels(XCTUnwrap(renderer.cgImage, "\(id) not drawn"))
    }

    /// The page as OrcaPageView draws it (with its toast layer), over blue.
    private func drawPage(_ model: OrcaPageModel, width: CGFloat, height: CGFloat) throws -> Pixels {
        let renderer = ImageRenderer(content: OrcaPageView(model: model)
            .frame(width: width, height: height)
            .background(Color(.sRGB, red: 0, green: 0, blue: 1))
            .environment(\.colorScheme, .light))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "the page is not drawn"))
    }

    /// M3's light inverseSurface (color_scheme_defaults.g.dart:57).
    static func isBar(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        near(p, (0x32, 0x2F, 0x35), 3)
    }

    /// Today's toast pill (white 0.18).
    static func isPill(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        near(p, (46, 46, 46), 2)
    }

    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 250 && p.r < 5 && p.g < 5 && p.b > 250
    }

    /// Glyph pixels on the bar: much lighter than it.
    static func isLight(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.r > 140 && p.g > 140 && p.b > 140
    }

    static func near(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ c: (Int, Int, Int), _ tolerance: Int) -> Bool {
        p.a > 250 && abs(Int(p.r) - c.0) <= tolerance && abs(Int(p.g) - c.1) <= tolerance
            && abs(Int(p.b) - c.2) <= tolerance
    }

    private func assertFrame(_ actual: CGRect?, _ expected: CGRect, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected): \(message)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected): \(message)",
                           file: file, line: line)
        }
    }
}

/// Pages by name: `components[name]` as the page's nodes, nothing for any
/// other name (also SnackbarQueueHostTests' Scaffold pages).
struct ScaffoldPages: HTTPTransport {
    let components: [String: [JSONValue]]

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let name = request.url.path.components(separatedBy: "/page/").last ?? ""
        let page: JSONValue = [
            "pageId": .string(name), "title": .string(name), "state": [],
            "components": .array(components[name] ?? []),
        ]
        return HTTPResponse(status: 200, body: try page.encoded())
    }

    var client: OrcaClient {
        OrcaClient(baseURL: URL(string: "http://stub.invalid")!, appId: "fixture-app",
                   device: DeviceInfo(osVersion: "test"), transport: self)
    }
}
#endif
