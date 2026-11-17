#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A8.1 (design D5, q1 a): openDialog shows the keyed Dialog's first child as
/// Flutter's modal bottom sheet (orca_page.dart:323-374;
/// showModalBottomSheet, material bottom_sheet.dart): the page's handler
/// waits for the sheet; a barrier black54 (0x8A000000, :1123) over the
/// navigator's area, the panel white with top corners 24, heightFactor ?? 0.5
/// of the whole height from the bottom edge (useSafeArea false), as wide as
/// its content up to 640 and centred (:618-625, :417-421), in 250 / out 200
/// ms through legacyDecelerate (:29-31); a barrier tap, a drag past half or
/// a fling down close the top sheet; closeDialog closes the top sheet only,
/// never a page (action_executor.dart:894-919). The sheet lies over each
/// NavigationStack (its navigation bar too) and under the tab bar. VoiceOver,
/// as Flutter's sheet reads on iOS: the panel (no name) and the "Scrim"
/// above it in one modal container, the
/// escape gesture closes, focus goes in and comes back. Time is passed in:
/// each page's sheets run on `now`.
@MainActor
final class DialogTests: XCTestCase {
    static let accuracy: CGFloat = 1
    private var now: Double = 1_000_000

    /// `dialogs` on the test's clock.
    private func manual(_ dialogs: OrcaDialogs) {
        dialogs.clock = { [unowned self] in self.now }
    }

    private func pass(_ ms: Double, _ dialogs: OrcaDialogs) {
        now += ms
        dialogs.tick()
    }

    private func open(_ id: String = "d", _ heightFactor: Double? = nil) -> Action {
        .openDialog(.init(dialogId: id, heightFactor: heightFactor))
    }

    /// Runs `action` on `page` in a task of its own and lets it start: until
    /// it has opened a sheet, or for 50 turns of the main actor when it
    /// opens none.
    private func start(_ action: Action, on page: OrcaPageModel) async -> Task<Void, Never> {
        let opens = page.dialogs.opens
        let task = Task { await page.run(action) }
        for _ in 0..<50 where page.dialogs.opens == opens { await Task.yield() }
        return task
    }

    /// True once `task` has finished, waiting at most a few turns.
    private func finished(_ task: Task<Void, Never>) async -> Bool {
        let done = Box(false)
        Task { await task.value; done.value = true }
        for _ in 0..<20 { await Task.yield() }
        return done.value
    }

    private final class Box<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }

    // MARK: - The handlers

    /// A8.1: in a Sequential, openDialog opens the Dialog's first child as a
    /// sheet and the next action waits until that sheet closes (the handler
    /// awaits showModalBottomSheet, orca_page.dart:346; the route's future
    /// completes as it is popped, navigator.dart:459-462, 481-483).
    func testA8_1_ASequentialsSetStateRunsOnlyAfterTheSheetCloses() async throws {
        let page = try model(sheetPage())
        let run = await start(.actionGroup(.init(actions: [
            open(), .setState(Action.SetState(key: "after", value: .double(1))),
        ])), on: page)
        XCTAssertEqual(page.dialogs.stack.sheets.map(\.rootId), ["sheet"], "the Dialog's first child is the sheet")
        XCTAssertEqual(page.dialogs.stack.top?.heightFactor, 0.5, "no heightFactor is half")
        let waited = await finished(run)
        XCTAssertFalse(waited, "the Sequential went on with the sheet open")
        XCTAssertTrue(page.store.value("after").isNull, "SetState ran before the close")

        await page.run(.closeDialog)
        let done = await finished(run)
        XCTAssertTrue(done, "the Sequential is still waiting")
        XCTAssertEqual(page.store.value("after"), .double(1))
        XCTAssertNil(page.dialogs.stack.top)
    }

    /// A8.1: closeDialog with no sheet open does nothing: it pops one popup
    /// route and never a page (action_executor.dart:903-912).
    func testA8_1_CloseDialogWithNoneOpenKeepsThePage() async throws {
        let router = OrcaRouter(client: ScaffoldPages(components: [
            "page": sheetPage(), "next": sheetPage(),
        ]).client, path: "page", system: SystemRecorder().actions())
        _ = try await loaded(router, router.root)
        router.navigate(to: "next")
        let next = try await loaded(router, router.top)
        await next.run(.closeDialog)
        await next.run(.closeDialog)
        XCTAssertEqual(router.stack.map(\.path), ["next"], "closeDialog popped a page")
        XCTAssertNil(next.dialogs.stack.top)
    }

    /// A8.1: stacked sheets close one per closeDialog, the top first, and
    /// each opener's wait ends with its own sheet; a third call does nothing
    /// (progress_and_dialog_fixes_test.dart:76-140).
    func testA8_1_StackedSheetsCloseOnePerCall() async throws {
        let page = try model(sheetPage())
        let first = await start(open("d", 0.5), on: page)
        let second = await start(open("d", 0.3), on: page)
        XCTAssertEqual(page.dialogs.stack.sheets.map(\.heightFactor), [0.5, 0.3])

        await page.run(.closeDialog)
        XCTAssertEqual(page.dialogs.stack.sheets.map(\.heightFactor), [0.5], "not the top one closed")
        let secondDone = await finished(second), firstDone = await finished(first)
        XCTAssertTrue(secondDone, "the top sheet's opener still waits")
        XCTAssertFalse(firstDone, "the lower sheet's opener stopped waiting")

        await page.run(.closeDialog)
        let firstAfter = await finished(first)
        XCTAssertTrue(firstAfter)
        XCTAssertNil(page.dialogs.stack.top)
        await page.run(.closeDialog)
        XCTAssertNil(page.dialogs.stack.top)
    }

    /// A8.1 (risk 5): Flutter registers the page's openDialog after the
    /// host's custom actions, so it beats a host's own (orca_page.dart
    /// :318-323), while closeDialog is the executor's built-in, which a
    /// host's own replaces (action_executor.dart:896; registerHandler).
    func testA8_1_ThePagesOpenDialogBeatsAHostsAndAHostsCloseDialogReplacesTheBuiltIn() async throws {
        let ran = HostRan()
        let host = OrcaPluginHost(plugins: [], customActions: [
            "openDialog": { _, _ in await ran.add("openDialog") },
            "closeDialog": { _, _ in await ran.add("closeDialog") },
        ], widgets: WidgetBuilders())
        let router = host.attach(OrcaRouter(client: ScaffoldPages(components: ["page": sheetPage()]).client,
                                            path: "page", system: SystemRecorder().actions()))
        let page = try await loaded(router, router.root)
        _ = await start(open(), on: page)
        XCTAssertNotNil(page.dialogs.stack.top, "the host's openDialog ran in place of the page's")
        await page.run(.closeDialog)
        let calls = await ran.calls
        XCTAssertEqual(calls, ["closeDialog"])
        XCTAssertNotNil(page.dialogs.stack.top, "the built-in closeDialog ran in place of the host's")
    }

    /// A8.1: the shell's trees (tab bar, drawer) are not a page: Flutter's
    /// shell executor has no onOpenDialog, so openDialog there opens nothing
    /// and does not wait (action_executor.dart:862-871; orca_shell.dart).
    func testA8_1_AShellTreeOpensNoSheetAndDoesNotWait() async throws {
        let config: JSONValue = [
            "initialRoute": "/home",
            "tabs": [["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"]],
            "flows": [["name": "main", "routes": [["path": "home"]]]],
        ]
        let router = OrcaRouter(client: ScaffoldPages(components: [:]).client,
                                config: try config.decode(NavConfig.self), system: SystemRecorder().actions())
        let tree = ShellTree(components: try nodes(sheetPage()), router: router)
        let run = await start(open(), on: tree.page)
        let done = await finished(run)
        XCTAssertTrue(done, "openDialog in a shell tree waits")
        XCTAssertNil(tree.page.dialogs.stack.top)
    }

    /// A8.1 (risk 7): a page covered by a push keeps its sheet and its
    /// opener waits (its view left the screen, its route did not); once the
    /// router drops the page from its stacks the wait ends. With no config
    /// and with one (the router's two ways to drop a loader).
    func testA8_1_APageDroppedWhileCoveredResumesItsWaiter() async throws {
        let pages = ScaffoldPages(components: ["page": sheetPage(), "next": sheetPage(), "other": sheetPage()])
        let config: JSONValue = [
            "initialRoute": "/page",
            "flows": [["name": "main", "routes": [["path": "page"], ["path": "next"], ["path": "other"]]]],
        ]
        for router in [
            OrcaRouter(client: pages.client, path: "page", system: SystemRecorder().actions()),
            OrcaRouter(client: pages.client, config: try config.decode(NavConfig.self),
                       system: SystemRecorder().actions()),
        ] {
            let page = try await loaded(router, router.root)
            let run = await start(open(), on: page)
            router.navigate(to: "next")
            _ = try await loaded(router, router.top)
            let covered = await finished(run)
            XCTAssertFalse(covered, "covered by a push, the page's sheet closed")
            XCTAssertNotNil(page.dialogs.stack.top)
            router.navigate(to: "other", replace: true)
            let dropped = await finished(run)
            XCTAssertTrue(dropped, "dropped from the stack, the page's openDialog still waits")
            XCTAssertNil(page.dialogs.stack.top)
        }
    }

    /// A8.1: a release closes the sheet when it was dragged past half its
    /// height (the route animation below 0.5) or flung down faster than
    /// 700, else it slides back (bottom_sheet.dart:32-33, :305-318).
    func testA8_1_TheReleaseClosesPastHalfOrOnAFlingDown() {
        XCTAssertTrue(SheetRelease.dismisses(controller: 0.49, velocity: 0))
        XCTAssertFalse(SheetRelease.dismisses(controller: 0.51, velocity: 0))
        XCTAssertFalse(SheetRelease.dismisses(controller: 0.5, velocity: nil))
        XCTAssertTrue(SheetRelease.dismisses(controller: 0.95, velocity: 701), "a fling down")
        XCTAssertFalse(SheetRelease.dismisses(controller: 0.95, velocity: 700), "not faster than 700")
        XCTAssertFalse(SheetRelease.dismisses(controller: 0.95, velocity: -900), "a fling up")
        XCTAssertTrue(SheetRelease.dismisses(controller: 0.4, velocity: -900), "up, but past half")
    }

    /// A8.1: the sheet's slide is the route animation through
    /// Easing.legacyDecelerate, Cubic(0, 0, 0.2, 1), both ways
    /// (bottom_sheet.dart:31, :695-699; motion_defaults_m3.g.dart:210), the
    /// barrier through Curves.ease (routes.dart:1869): the values Flutter's
    /// own sheet takes 50 and 125 ms in (0.5, 0.839) and 100 ms out (0.839).
    func testA8_1_TheSlideIsLegacyDecelerateAndTheBarrierEase() {
        let enter = SheetMotion(from: 0, to: 1, start: 0)
        XCTAssertEqual(enter.value(at: 50), 0.5, accuracy: 0.005)
        XCTAssertEqual(enter.value(at: 125), 0.8392, accuracy: 0.005)
        XCTAssertEqual(enter.value(at: 250), 1)
        XCTAssertFalse(enter.isDone(at: 249))
        XCTAssertTrue(enter.isDone(at: 250))
        let leave = SheetMotion(from: 1, to: 0, start: 0)
        XCTAssertEqual(leave.value(at: 100), 0.8392, accuracy: 0.005)
        XCTAssertEqual(leave.value(at: 200), 0)
        XCTAssertTrue(leave.isDone(at: 200))
        // After a drag the rest is Split(released, legacyDecelerate)
        // (bottom_sheet.dart:751-766): linear on the way out ...
        let out = SheetMotion(from: 0.4, to: 0, start: 0, split: 0.4)
        XCTAssertEqual(out.value(at: 40), 0.2, accuracy: 0.001)
        XCTAssertTrue(out.isDone(at: 80))
        // ... and the curve over what is left on the way back.
        let back = SheetMotion(from: 0.6, to: 1, start: 0, split: 0.6)
        XCTAssertEqual(back.value(at: 50), 0.6 + 0.4 * 0.8392, accuracy: 0.005)
        XCTAssertEqual(SheetMotion.barrierOpacity(controller: 0.5), 138.0 / 255 * 0.8024, accuracy: 0.003)
    }

    #if canImport(UIKit)
    // MARK: - On screen

    /// A8.1: the panel is heightFactor of the whole height (the navigator's,
    /// no safe area: useSafeArea false) from the bottom edge: 250 at 0.5 and
    /// 200 at 0.4 in a 500 window whose content stops 20 above it; a content
    /// that fills takes the whole width. Its top corners are cut (24).
    func testA8_1_ThePanelIsHeightFactorOfTheWholeHeightFromTheBottomEdge() async throws {
        for (factor, expected) in [(0.5, CGRect(x: 0, y: 250, width: 300, height: 250)),
                                   (0.4, CGRect(x: 0, y: 300, width: 300, height: 200))] {
            let (window, router) = try await show(sheetPage())
            defer { window.isHidden = true }
            let page = try await loaded(router, router.root)
            manual(page.dialogs)
            _ = await start(open("d", factor), on: page)
            pass(250, page.dialogs)
            let pixels = try snapshot(window)
            assertFrame(pixels.bounds(of: Pixels.isRed), expected, "\(factor)")
            XCTAssertFalse(Pixels.isRed(pixels.pixel(1, Int(expected.minY) + 1)), "\(factor): a square top corner")
            XCTAssertFalse(Pixels.isRed(pixels.pixel(298, Int(expected.minY) + 1)), "\(factor): a square top corner")
        }
    }

    /// A8.1: the barrier is black54 over the page: green under it reads
    /// 0x8A of black over it; the panel is white, as wide as its content
    /// (Flutter's sheet: Align bottomCenter > ConstrainedBox(maxWidth 640) >
    /// FractionallySizedBox(heightFactor) > Container, loose in width,
    /// bottom_sheet.dart:417-421, :618-625; Flutter draws a 28-wide panel for
    /// a Column of "hi"), centred; on a 900 window a filling content is 640
    /// wide, centred (130 ... 770, as Flutter's).
    func testA8_1_TheBarrierIsBlack54AndThePanelWhiteAsWideAsItsContentAtMost640() async throws {
        let narrow = [fill("b", "#00FF00"), dialog("d", ["col"]), node("col", "Column", [:], ["t"]),
                      node("t", "Text", ["data": "hi"], kind: "primitive")]
        let (window, router) = try await show(narrow)
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        _ = await start(open(), on: page)
        pass(250, page.dialogs)
        let pixels = try snapshot(window)
        let barrier = pixels.pixel(150, 100)
        XCTAssertTrue(Self.near(barrier, (0, 117, 0), 3), "the barrier over green: \(barrier)")
        let panel = try XCTUnwrap(pixels.rows(250...499).bounds(of: Self.isWhite), "no white panel")
        XCTAssertEqual(panel.minY + 250, 250, accuracy: Self.accuracy, "the panel's top")
        XCTAssertEqual(panel.maxY + 250, 500, accuracy: Self.accuracy, "the panel's bottom")
        XCTAssertLessThan(panel.width, 60, "the panel is wider than its content")
        XCTAssertEqual(panel.midX, 150, accuracy: 1.5, "the panel is not centred")
        XCTAssertTrue(Self.near(pixels.pixel(10, 400), (0, 117, 0), 3), "beside the panel is barrier")

        let (wide, wideRouter) = try await show(sheetPage(), width: 900)
        defer { wide.isHidden = true }
        let widePage = try await loaded(wideRouter, wideRouter.root)
        manual(widePage.dialogs)
        _ = await start(open(), on: widePage)
        pass(250, widePage.dialogs)
        assertFrame(try snapshot(wide).bounds(of: Pixels.isRed), CGRect(x: 130, y: 250, width: 640, height: 250),
                    "900 wide")
    }

    /// A8.1: in 250 ms, out 200, through legacyDecelerate (Flutter's sheet
    /// stands at 290.2 both 125 ms in and 100 ms out); the barrier fades in
    /// with Curves.ease; once out, nothing is left.
    func testA8_1_TheSheetSlidesIn250AndOut200() async throws {
        let (window, router) = try await show(sheetPage())
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        _ = await start(open(), on: page)
        XCTAssertNil(try snapshot(window).bounds(of: Pixels.isRed), "in at once")
        pass(125, page.dialogs)
        var pixels = try snapshot(window)
        XCTAssertEqual(try XCTUnwrap(pixels.bounds(of: Pixels.isRed)).minY, 290.2, accuracy: Self.accuracy, "125 ms in")
        let fading = 255 * (1 - 138.0 / 255 * 0.8024)
        XCTAssertEqual(Double(pixels.pixel(150, 100).g), fading, accuracy: 3, "the barrier 125 ms in")
        pass(125, page.dialogs)
        XCTAssertEqual(try XCTUnwrap(try snapshot(window).bounds(of: Pixels.isRed)).minY, 250,
                       accuracy: Self.accuracy, "250 ms in")

        await page.run(.closeDialog)
        pass(100, page.dialogs)
        pixels = try snapshot(window)
        XCTAssertEqual(try XCTUnwrap(pixels.bounds(of: Pixels.isRed)).minY, 290.2, accuracy: Self.accuracy, "100 ms out")
        pass(100, page.dialogs)
        pixels = try snapshot(window)
        XCTAssertNil(pixels.bounds(of: Pixels.isRed), "200 ms out")
        XCTAssertTrue(Self.near(pixels.pixel(150, 100), (0, 255, 0), 2), "the barrier stayed")
        XCTAssertTrue(page.dialogs.entries.isEmpty, "a sheet that slid out is still kept")
    }

    /// A8.1 (risk 6): the sheet lies over the NavigationStack, so a pushed
    /// page's navigation bar is under the barrier too (Flutter's AppBar is
    /// in the page route, under the sheet route), but under tabs it ends at
    /// the tab bar, which stays as it is (the branch navigator,
    /// showModalBottomSheet's nearest Navigator).
    func testA8_1_TheSheetCoversTheNavigationBarAndStopsAtTheTabBar() async throws {
        let (window, router) = try await show(sheetPage(), components: ["next": sheetPage()])
        defer { window.isHidden = true }
        router.navigate(to: "next")
        let next = try await loaded(router, router.top)
        try await Task.sleep(nanoseconds: 700_000_000)
        let bar = try XCTUnwrap(Self.navigationBar(in: window), "no navigation bar")
        let barFrame = bar.convert(bar.bounds, to: window)
        let before = try snapshot(window).pixel(150, Int(barFrame.midY))
        manual(next.dialogs)
        _ = await start(open(), on: next)
        pass(250, next.dialogs)
        let dimmed = try snapshot(window).pixel(150, Int(barFrame.midY))
        XCTAssertLessThan(Int(dimmed.g), Int(before.g) - 80, "the navigation bar is not under the barrier: \(dimmed)")

        let config: JSONValue = [
            "initialRoute": "/home",
            "tabs": [["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"],
                     ["id": "more", "label": "More", "icon": "menu", "initialRoute": "/more"]],
            "flows": [["name": "main", "routes": [["path": "home"], ["path": "more"]]]],
        ]
        let tabsRouter = OrcaRouter(client: ScaffoldPages(components: ["home": sheetPage()]).client,
                                    config: try config.decode(NavConfig.self), system: SystemRecorder().actions())
        let tabsWindow = try await show(tabsRouter)
        defer { tabsWindow.isHidden = true }
        let home = try await loaded(tabsRouter, tabsRouter.root)
        let tabs = try XCTUnwrap(SafeAreaShellTests.tabBar(in: tabsWindow), "no tab bar")
        let tabsFrame = tabs.convert(tabs.bounds, to: tabsWindow)
        let tabsBefore = try snapshot(tabsWindow).pixel(150, Int(tabsFrame.maxY) - 4)
        manual(home.dialogs)
        _ = await start(open(), on: home)
        pass(250, home.dialogs)
        let pixels = try snapshot(tabsWindow)
        let panel = try XCTUnwrap(pixels.bounds(of: Pixels.isRed), "no panel")
        XCTAssertEqual(panel.maxY, tabsFrame.minY, accuracy: Self.accuracy, "the panel does not end at the tab bar")
        XCTAssertEqual(panel.height, tabsFrame.minY / 2, accuracy: Self.accuracy, "half of the space above the tab bar")
        XCTAssertTrue(Self.near(pixels.pixel(150, Int(tabsFrame.maxY) - 4), (Int(tabsBefore.r), Int(tabsBefore.g),
                                                                          Int(tabsBefore.b)), 3),
                      "the tab bar is under the barrier")
    }

    /// A8.1: where Flutter paints the app's snackbar against the sheet. A
    /// page's root Scaffold is in the page route, under the sheet route: its
    /// bar is under the barrier. Under tabs the bar is the shell Scaffold's,
    /// whose snackbar slot paints over its body, the branch navigators
    /// holding the sheet (scaffold.dart:3197, :3276 child order;
    /// orca_shell.dart:114-117): that bar is over the sheet.
    func testA8_1_APagesBarIsUnderTheSheetAndTheShellsBarOverIt() async throws {
        let scaffolded = [scaffold("s", ["body": "b"]), fill("b", "#00FF00"), dialog("d", ["sheet"]),
                          fill("sheet", "#E53935")]
        let (window, router) = try await show(scaffolded)
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        router.snackbars.clock = { [unowned self] in self.now }
        router.snackbars.sleep = nil
        await page.run(.showSnackbar(.init(message: .string("Saved"))))
        _ = await start(open("d", 0.8), on: page)
        pass(250, page.dialogs)
        router.snackbars.tick()
        XCTAssertNil(try snapshot(window).bounds(of: SnackbarBarTests.isBar), "the page's bar shows over the sheet")

        let config: JSONValue = [
            "initialRoute": "/home",
            "tabs": [["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"]],
            "flows": [["name": "main", "routes": [["path": "home"]]]],
        ]
        let tabsRouter = OrcaRouter(client: ScaffoldPages(components: ["home": sheetPage()]).client,
                                    config: try config.decode(NavConfig.self), system: SystemRecorder().actions())
        tabsRouter.snackbars.clock = { [unowned self] in self.now }
        tabsRouter.snackbars.sleep = nil
        let tabsWindow = try await show(tabsRouter)
        defer { tabsWindow.isHidden = true }
        let home = try await loaded(tabsRouter, tabsRouter.root)
        manual(home.dialogs)
        _ = await start(open("d", 0.8), on: home)
        pass(250, home.dialogs)
        await home.run(.showSnackbar(.init(message: .string("Saved"))))
        now += 250
        tabsRouter.snackbars.tick()
        let tabs = try XCTUnwrap(SafeAreaShellTests.tabBar(in: tabsWindow), "no tab bar")
        let bar = try XCTUnwrap(try snapshot(tabsWindow).bounds(of: SnackbarBarTests.isBar),
                                "the shell's bar is under the sheet")
        XCTAssertEqual(bar.maxY, tabs.convert(tabs.bounds, to: tabsWindow).minY, accuracy: Self.accuracy)
    }

    /// A8.1: the barrier takes every touch above the panel (Flutter's
    /// ModalBarrier: expand, opaque, modal_barrier.dart:243-245, :437): a
    /// field of the page under it gets none. To VoiceOver it is one element
    /// "Scrim" over the space above the panel, as Flutter's reads on iOS
    /// (bottom_sheet.dart:1356, :734-736; material_localizations.dart:1137;
    /// no button trait or hint: the tap hint is Android's), and its
    /// activation, the tap's own action, closes the top sheet.
    func testA8_1_TheBarrierTakesEveryTouchAndTheScrimClosesTheTopSheet() async throws {
        let (window, router) = try await show(probedPage())
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        let probe = try XCTUnwrap(Self.fields(in: window).first, "no probe")
        let point = probe.convert(CGPoint(x: probe.bounds.midX, y: probe.bounds.midY), to: window)
        XCTAssertTrue(FlowTests.isInField(window.hitTest(point, with: nil)), "the probe takes no touch")
        _ = await start(open(), on: page)
        _ = await start(open("d", 0.3), on: page)
        pass(250, page.dialogs)
        _ = try snapshot(window)
        XCTAssertFalse(FlowTests.isInField(window.hitTest(point, with: nil)), "a touch went through the barrier")

        let restore = SnackBarWidgetTests.automation(true)
        defer { _ = SnackBarWidgetTests.automation(restore) }
        _ = try snapshot(window)
        let scrim = try XCTUnwrap(SnackBarWidgetTests.element(labelled: "Scrim", in: window), "no Scrim element")
        XCTAssertFalse(scrim.accessibilityTraits.contains(.button), "the Scrim is a button")
        XCTAssertTrue(scrim.accessibilityHint?.isEmpty ?? true, "the Scrim has a hint")
        // The top sheet is 0.3 of 500: the Scrim is the 350 above it.
        // Accessibility frames are in the coordinates UIKit gives them: the
        // window's own frame converted the same way is the origin.
        let origin = UIAccessibility.convertToScreenCoordinates(window.bounds, in: window).origin
        let frame = scrim.accessibilityFrame.offsetBy(dx: -origin.x, dy: -origin.y)
        assertFrame(frame, CGRect(x: 0, y: 0, width: 300, height: 350), "the Scrim's area")
        XCTAssertTrue(scrim.accessibilityActivate(), "the Scrim's activation was not taken")
        XCTAssertEqual(page.dialogs.stack.sheets.map(\.heightFactor), [0.5], "not the top sheet closed")
    }

    /// A8.1 (D5): while a sheet is open its panel and the Scrim lie in one
    /// modal container, so the page below is out of VoiceOver's reach
    /// (Flutter's barrier BlockSemantics, modal_barrier.dart:259-264); the
    /// panel comes first, the Scrim after it (routes.dart:2282-2284). The
    /// panel has no name of its own: Flutter's route label is empty on iOS
    /// (bottom_sheet.dart:726-728).
    func testA8_1_TheSheetIsModalAndThePageIsOutOfReach() async throws {
        let (window, router) = try await show(probedPage())
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        _ = await start(open(), on: page)
        pass(250, page.dialogs)
        let restore = SnackBarWidgetTests.automation(true)
        defer { _ = SnackBarWidgetTests.automation(restore) }
        _ = try snapshot(window)
        let modal = try XCTUnwrap(Self.modal(in: window), "no modal container")
        let named = Self.objects(in: modal).filter { $0.accessibilityLabel == "Bottom Sheet" }
        XCTAssertTrue(named.isEmpty, "the panel is named; Flutter's iOS route is not")
        XCTAssertNotNil(SnackBarWidgetTests.element(labelled: "Scrim", in: modal), "the Scrim is not in it")
        XCTAssertNotNil(SnackBarWidgetTests.element(labelled: "inside", in: modal), "the panel's content is not in it")
        XCTAssertNil(SnackBarWidgetTests.element(labelled: "p0", in: modal), "the page is inside the modal container")
        XCTAssertFalse(Self.fields(in: window).contains { Self.objects(in: modal).contains($0) },
                       "the page's field is inside the modal container")
        let order = (modal.accessibilityElements as? [NSObject]) ?? []
        if order.count >= 2 {
            XCTAssertNotEqual(order.first?.accessibilityLabel, "Scrim", "the Scrim comes before the panel")
        }
    }

    /// A8.1 (D5): VoiceOver's escape gesture closes the top sheet (Flutter's
    /// barrier semantics dismiss, modal_barrier.dart:236).
    func testA8_1_VoiceOversEscapeClosesTheTopSheet() async throws {
        let (window, router) = try await show(probedPage())
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        _ = await start(open(), on: page)
        _ = await start(open("d", 0.3), on: page)
        pass(250, page.dialogs)
        let restore = SnackBarWidgetTests.automation(true)
        defer { _ = SnackBarWidgetTests.automation(restore) }
        _ = try snapshot(window)
        let modal = try XCTUnwrap(Self.modal(in: window), "no modal container")
        XCTAssertTrue(modal.accessibilityPerformEscape(), "escape not taken")
        XCTAssertEqual(page.dialogs.stack.sheets.map(\.heightFactor), [0.5])
    }

    /// A8.1 (D5): on open VoiceOver is sent into the sheet (a screen change,
    /// the panel first in the modal container), and on close back to the
    /// element that was focused when it opened (a layout change to it).
    func testA8_1_VoiceOverFocusGoesIntoTheSheetAndBackToTheOpener() async throws {
        var posted: [(UIAccessibility.Notification, NSObject?)] = []
        let opener = NSObject()
        let (focused, post) = (OrcaDialogs.focusedElement, OrcaDialogs.post)
        OrcaDialogs.focusedElement = { opener }
        OrcaDialogs.post = { posted.append(($0, $1 as? NSObject)) }
        defer { (OrcaDialogs.focusedElement, OrcaDialogs.post) = (focused, post) }
        let (window, router) = try await show(sheetPage())
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        _ = await start(open(), on: page)
        pass(250, page.dialogs)
        _ = try snapshot(window)
        XCTAssertEqual(posted.map(\.0), [.screenChanged])
        await page.run(.closeDialog)
        _ = try snapshot(window)
        XCTAssertEqual(posted.map(\.0), [.screenChanged, .layoutChanged])
        XCTAssertTrue(posted.last?.1 === opener, "focus does not go back to the opener")
    }

    /// A8.1: the sheet is drawn with the page's stores: a state change
    /// redraws inside it (Flutter's dialog renderer watches the live stores,
    /// orca_page.dart:350-356).
    func testA8_1_AStateChangeRedrawsInsideTheSheet() async throws {
        let bound = [fill("b", "#00FF00"), dialog("d", ["sheet"]),
                     ["id": "sheet", "type": "Container", "kind": "layout", "childMode": "none",
                      "props": ["color": ["type": "state", "key": "tint", "scope": "page"]],
                      "children": [], "watches": ["tint"]] as JSONValue]
        let (window, router) = try await show(bound)
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        await page.run(.setState(Action.SetState(key: "tint", value: "#E53935")))
        _ = await start(open(), on: page)
        pass(250, page.dialogs)
        XCTAssertNotNil(try snapshot(window).bounds(of: Pixels.isRed), "not drawn red")
        await page.run(.setState(Action.SetState(key: "tint", value: "#0000FF")))
        let pixels = try snapshot(window)
        XCTAssertNil(pixels.bounds(of: Pixels.isRed), "still red")
        XCTAssertTrue(Self.near(pixels.pixel(150, 400), (0, 0, 255), 2), "not redrawn blue: \(pixels.pixel(150, 400))")
    }

    /// A8.1 (risk 8): the page's edge swipe back is off while a sheet is
    /// open: Flutter's barrier takes every pointer over the page route, its
    /// back gesture detector included (modal_barrier.dart:243-245, :437).
    /// A touch at the leading edge no longer reaches the navigation
    /// controller's view, whose pop gesture it would start.
    func testA8_1_TheEdgeSwipeIsOffWhileASheetIsOpen() async throws {
        let (window, router) = try await show(sheetPage(), components: ["next": sheetPage()])
        defer { window.isHidden = true }
        router.navigate(to: "next")
        let next = try await loaded(router, router.top)
        try await Task.sleep(nanoseconds: 700_000_000)
        let navigation = try XCTUnwrap(Self.navigationController(in: window.rootViewController), "no navigation")
        let edge = CGPoint(x: 2, y: 250)
        XCTAssertTrue(window.hitTest(edge, with: nil)?.isDescendant(of: navigation.view) ?? false,
                      "the edge is not the navigation's with no sheet")
        manual(next.dialogs)
        _ = await start(open(), on: next)
        pass(250, next.dialogs)
        _ = try snapshot(window)
        XCTAssertFalse(window.hitTest(edge, with: nil)?.isDescendant(of: navigation.view) ?? true,
                       "the edge still reaches the navigation's pop gesture")
    }

    /// A8.1 (D5, beyond Flutter: the user's call): with the keyboard up the
    /// panel rises by the keyboard's height, its own height kept (Flutter
    /// lets the keyboard cover a modal sheet), and the Scrim's element ends
    /// at the risen panel's top.
    func testA8_1_ThePanelRisesAboveARaisedKeyboard() async throws {
        let (window, router) = try await show(sheetPage())
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        _ = await start(open(), on: page)
        pass(250, page.dialogs)
        assertFrame(try snapshot(window).bounds(of: Pixels.isRed), CGRect(x: 0, y: 250, width: 300, height: 250),
                    "the panel with no keyboard")
        let keyboard = window.convert(CGRect(x: 0, y: 300, width: 300, height: 200),
                                      to: window.screen.coordinateSpace)
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                                        userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboard)])
        assertFrame(try snapshot(window).bounds(of: Pixels.isRed), CGRect(x: 0, y: 50, width: 300, height: 250),
                    "the panel on the keyboard")
        // The Scrim's element stays above the risen panel: 500 - 250 - 200.
        let restore = SnackBarWidgetTests.automation(true)
        defer { _ = SnackBarWidgetTests.automation(restore) }
        _ = try snapshot(window)
        let scrim = try XCTUnwrap(SnackBarWidgetTests.element(labelled: "Scrim", in: window), "no Scrim element")
        let origin = UIAccessibility.convertToScreenCoordinates(window.bounds, in: window).origin
        assertFrame(scrim.accessibilityFrame.offsetBy(dx: -origin.x, dy: -origin.y),
                    CGRect(x: 0, y: 0, width: 300, height: 50), "the Scrim over the risen panel")
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: [:])
        assertFrame(try snapshot(window).bounds(of: Pixels.isRed), CGRect(x: 0, y: 250, width: 300, height: 250),
                    "the panel back down")
    }

    /// A8.1 (D5): opening a sheet takes input focus from the page: a field
    /// being edited gives up the keyboard (the sheet route's FocusScope
    /// takes focus). It is not given back on close (a known difference).
    func testA8_1_OpeningASheetEndsTheEditingOfAPageField() async throws {
        let (window, router) = try await show(probedPage())
        defer { window.isHidden = true }
        let page = try await loaded(router, router.root)
        manual(page.dialogs)
        let field = try XCTUnwrap(Self.fields(in: window).first, "no field")
        XCTAssertTrue(field.becomeFirstResponder(), "the field took no focus")
        defer { field.resignFirstResponder() }
        _ = try snapshot(window)
        XCTAssertTrue(field.isFirstResponder)
        _ = await start(open(), on: page)
        pass(250, page.dialogs)
        _ = try snapshot(window)
        XCTAssertFalse(field.isFirstResponder, "the page's field still edits under the sheet")
    }

    /// A8.1 (risk 7): a page taken off the stack with sheets open lets every
    /// openDialog waiting on them go on, so no Sequential hangs.
    func testA8_1_APageTornDownWithSheetsOpenResumesEveryWaiter() async throws {
        let (window, router) = try await show(sheetPage(), components: ["next": sheetPage()])
        defer { window.isHidden = true }
        router.navigate(to: "next")
        let next = try await loaded(router, router.top)
        try await Task.sleep(nanoseconds: 700_000_000)
        let first = await start(open(), on: next)
        let second = await start(open("d", 0.3), on: next)
        XCTAssertEqual(next.dialogs.stack.sheets.count, 2)
        router.goBack()
        try await Task.sleep(nanoseconds: 900_000_000)
        let firstDone = await finished(first), secondDone = await finished(second)
        XCTAssertTrue(firstDone && secondDone, "a waiter hangs: \(firstDone), \(secondDone)")
        XCTAssertNil(next.dialogs.stack.top)
    }

    // MARK: - Hosting

    /// OrcaApp on a router whose first page, `page`, is `nodes` (and other
    /// pages by name), in a light window `width` x 500 with top 30 and
    /// bottom 20 insets, once that page has loaded.
    private func show(_ nodes: [JSONValue], components: [String: [JSONValue]] = [:],
                      width: CGFloat = 300) async throws -> (UIWindow, OrcaRouter) {
        var pages = components
        pages["page"] = nodes
        let router = OrcaRouter(client: ScaffoldPages(components: pages).client, path: "page",
                                system: SystemRecorder().actions())
        return (try await show(router, width: width), router)
    }

    private func show(_ router: OrcaRouter, width: CGFloat = 300) async throws -> UIWindow {
        let host = UIHostingController(rootView: OrcaApp(router: router))
        host.additionalSafeAreaInsets = SafeAreaShellTests.insets
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: width, height: 500))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        _ = try await loaded(router, router.root, waits: true)
        try await Task.sleep(nanoseconds: 500_000_000)
        return window
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

    static func navigationBar(in view: UIView) -> UINavigationBar? {
        if let bar = view as? UINavigationBar, !bar.isHidden, bar.bounds.height > 0 { return bar }
        return view.subviews.lazy.compactMap(navigationBar(in:)).first
    }

    static func navigationController(in controller: UIViewController?) -> UINavigationController? {
        guard let controller else { return nil }
        if let navigation = controller as? UINavigationController { return navigation }
        return controller.children.lazy.compactMap(navigationController(in:)).first
    }

    static func fields(in view: UIView) -> [UITextField] {
        ((view as? UITextField).map { [$0] } ?? []) + view.subviews.flatMap(fields)
    }

    /// Every accessibility object under `root`: its elements, then its
    /// subviews, depth first.
    static func objects(in root: NSObject, depth: Int = 0) -> [NSObject] {
        guard depth < 60 else { return [] }
        var children: [NSObject] = (root.accessibilityElements as? [NSObject]) ?? []
        if children.isEmpty {
            let count = root.accessibilityElementCount()
            if count != NSNotFound, count > 0 {
                children = (0..<count).compactMap { root.accessibilityElement(at: $0) as? NSObject }
            }
        }
        if let view = root as? UIView { children += view.subviews }
        return [root] + children.flatMap { objects(in: $0, depth: depth + 1) }
    }

    /// The first accessibility object under `root` VoiceOver keeps to alone.
    static func modal(in root: NSObject) -> NSObject? {
        objects(in: root).first { $0.accessibilityViewIsModal }
    }
    #endif

    // MARK: - Pages

    /// The route's page once loaded; `waits`: it is loading on screen.
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
            throw NSError(domain: "DialogTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "page \(route.path) did not load: \(loader.phase)"])
        }
        return model
    }

    /// A green page with the Dialog `d`, whose child `sheet` is a red fill.
    private func sheetPage() -> [JSONValue] {
        [fill("b", "#00FF00"), dialog("d", ["sheet"]), fill("sheet", "#E53935")]
    }

    /// A Column of five text fields (p0 ... p4) and the Dialog `d`, whose
    /// child is a Column holding the Text "inside".
    private func probedPage() -> [JSONValue] {
        let probes = (0..<5).map { "p\($0)" }
        return [node("probes", "Column", ["crossAxisAlignment": "stretch"], probes)]
            + probes.map { node($0, "TextField", ["placeholder": .string($0)], kind: "input") }
            + [dialog("d", ["col"]), node("col", "Column", [:], ["t"]),
               node("t", "Text", ["data": "inside"], kind: "primitive")]
    }

    private func nodes(_ json: [JSONValue]) throws -> [ComponentNode] {
        try json.map { try $0.decode(ComponentNode.self) }
    }

    private func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let response = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        let model = OrcaPageModel(page: response)
        manual(model.dialogs)
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

    private func dialog(_ id: String, _ children: [String]) -> JSONValue {
        node(id, "Dialog", ["dismissible": false], children, kind: "structure")
    }

    private func scaffold(_ id: String, _ slots: [String: String]) -> JSONValue {
        ["id": .string(id), "type": "Scaffold", "kind": "structure", "childMode": "none",
         "props": .object(slots.mapValues(JSONValue.string)),
         "children": .array(slots.values.sorted().map(JSONValue.string)), "watches": []]
    }

    private func fill(_ id: String, _ hex: String) -> JSONValue {
        node(id, "Container", ["color": .string(hex)])
    }

    // MARK: - Pixels

    static func isWhite(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 250 && p.r > 250 && p.g > 250 && p.b > 250
    }

    static func near(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ c: (Int, Int, Int), _ tolerance: Int) -> Bool {
        abs(Int(p.r) - c.0) <= tolerance && abs(Int(p.g) - c.1) <= tolerance && abs(Int(p.b) - c.2) <= tolerance
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

/// What a host's custom handlers ran, in order.
private actor HostRan {
    private(set) var calls: [String] = []
    func add(_ call: String) { calls.append(call) }
}
#endif
