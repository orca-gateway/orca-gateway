#if canImport(SwiftUI) && canImport(Network)
import Foundation
import OSLog
import SwiftUI
import XCTest

@testable import OrcaGateway

/// C19.5 (the unit part; the chip on a device is a hand check): the host's
/// debug config with Flutter's switches, `logTimings`, and Flutter's
/// `OrcaDebugOverlay` (sdk/lib/src/debug/debug_overlay.dart) over each page
/// while DevTools runs with `showOverlay` on. The tap is tested without
/// tapping through SwiftUI, as the page model's taps are: the chip's tap is
/// `DebugOverlayModel.tap()`.
@MainActor
final class DebugOverlayTests: XCTestCase {
    let recorder = DevToolsHookTests.Recorder()

    override func tearDown() async throws {
        OrcaDebug.stop()
        OrcaDebug.reporter = nil
        OrcaDebug.options = OrcaDebugOptions()
        OrcaDebug.showOverlay = false
        try await super.tearDown()
    }

    // MARK: The config

    /// C19.5 (D1): the config gains Flutter's five switches with Flutter's
    /// defaults (orca_debug.dart:5-30), after the fields it had.
    func testC19_5_theDebugConfigHasFlutterSwitchesWithFlutterDefaults() {
        let config = OrcaDebugConfig()
        XCTAssertFalse(config.showOverlay)
        XCTAssertFalse(config.logTimings)
        XCTAssertTrue(config.captureStateChanges)
        XCTAssertTrue(config.captureNetworkRequests)
        XCTAssertFalse(config.includeBodies)

        let all = OrcaDebugConfig(enabled: true, host: "10.0.0.5", port: 7000, appName: "App",
                                  showOverlay: true, logTimings: true, captureStateChanges: false,
                                  captureNetworkRequests: false, includeBodies: true)
        XCTAssertEqual([all.showOverlay, all.logTimings, all.captureStateChanges,
                        all.captureNetworkRequests, all.includeBodies], [true, true, false, false, true])
        XCTAssertEqual(all.appName, "App")
        XCTAssertEqual(all.url, URL(string: "ws://10.0.0.5:7000"))
    }

    /// C19.5 (D1): `start` copies the four core switches into
    /// `OrcaDebug.options` and keeps `showOverlay` for the pages; `stop`
    /// puts the defaults back and the overlay off; a disabled config starts
    /// nothing and leaves the defaults.
    func testC19_5_startCopiesTheOptionsAndTheOverlaySwitchStopResetsThem() async throws {
        let stub = try DevToolsStub()
        try await stub.start()
        defer { stub.stop() }
        let client = OrcaDebug.start(OrcaDebugConfig(
            enabled: true, host: "127.0.0.1", port: Int(stub.port), showOverlay: true, logTimings: true,
            captureStateChanges: false, captureNetworkRequests: false, includeBodies: true))
        XCTAssertNotNil(client)
        XCTAssertTrue(OrcaDebug.isEnabled)
        XCTAssertEqual(OrcaDebug.options, OrcaDebugOptions(
            captureStateChanges: false, captureNetworkRequests: false, includeBodies: true, logTimings: true))
        XCTAssertTrue(OrcaDebug.showOverlay)
        XCTAssertTrue(DebugOverlay.isShown)

        OrcaDebug.stop()
        XCTAssertFalse(OrcaDebug.isEnabled)
        XCTAssertEqual(OrcaDebug.options, OrcaDebugOptions())
        XCTAssertFalse(OrcaDebug.showOverlay)
        XCTAssertFalse(DebugOverlay.isShown)

        OrcaDebug.start(OrcaDebugConfig(enabled: true, host: "127.0.0.1", port: Int(stub.port),
                                        showOverlay: true, includeBodies: true))
        XCTAssertNil(OrcaDebug.start(OrcaDebugConfig(
            showOverlay: true, logTimings: true, captureStateChanges: false,
            captureNetworkRequests: false, includeBodies: true)), "disabled")
        XCTAssertFalse(OrcaDebug.isEnabled)
        XCTAssertEqual(OrcaDebug.options, OrcaDebugOptions(), "a disabled config leaves the defaults")
        XCTAssertFalse(OrcaDebug.showOverlay)
    }

    // MARK: logTimings

    /// C19.5 (D1): with `logTimings` on, each timing event also writes
    /// Flutter's line `[OrcaDebug] Timing: <pageId> - <path>` to the system
    /// log (subsystem com.orcagateway), once; off, the event goes and no
    /// line is written.
    func testC19_5_logTimingsWritesTheTimingLineOncePerTimingEventAndNoneWhenOff() async throws {
        OrcaDebug.reporter = recorder
        let since = Date().addingTimeInterval(-1)
        let on = "timed-\(UUID().uuidString)", off = "untimed-\(UUID().uuidString)"

        OrcaDebug.options = OrcaDebugOptions(logTimings: true)
        let first = try await loaded(on).model
        first.appeared()
        first.appeared()
        OrcaDebug.options = OrcaDebugOptions()
        let second = try await loaded(off).model
        second.appeared()

        XCTAssertEqual(recorder.of("timing").map { $0.payload["path"] }, [.string(on), .string(off)],
                       "the event goes with or without the line")
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let entries = try store.getEntries(at: store.position(date: since), matching: NSPredicate(
            format: "subsystem == %@", "com.orcagateway"))
        let lines = entries.compactMap { ($0 as? OSLogEntryLog)?.composedMessage }
        XCTAssertEqual(lines.filter { $0.contains(on) }, ["[OrcaDebug] Timing: \(on) - \(on)"])
        XCTAssertEqual(lines.filter { $0.contains(off) }, [], "logTimings off")
    }

    // MARK: The overlay

    /// C19.5 (D6): with the defaults nothing is drawn over a page; DevTools
    /// on with `showOverlay` off draws nothing, nor `showOverlay` without
    /// DevTools.
    func testC19_5_byDefaultAPageDrawsNoOverlay() async throws {
        let (router, loader, model) = try await loaded("home")
        func page() throws -> Pixels { try draw(RoutePage(router: router, route: router.root, isStackRoot: true)) }
        XCTAssertFalse(DebugOverlay.isShown)
        XCTAssertNil(OrcaPageView(model: model, loadTimeMs: loader.loadTimeMs).debugOverlay)
        XCTAssertNil(chip(in: try page()), "the defaults")

        OrcaDebug.reporter = recorder
        XCTAssertNil(OrcaPageView(model: model, loadTimeMs: loader.loadTimeMs).debugOverlay)
        XCTAssertNil(chip(in: try page()), "DevTools on, showOverlay off")

        OrcaDebug.reporter = nil
        OrcaDebug.showOverlay = true
        XCTAssertNil(OrcaPageView(model: model, loadTimeMs: loader.loadTimeMs).debugOverlay)
        XCTAssertNil(chip(in: try page()), "showOverlay without DevTools")
    }

    /// C19.5 (D6): DevTools on and `showOverlay` on, a page the loader
    /// fetched shows Flutter's chip 8 points in from the bottom right,
    /// black at 87%, with the page's load in ms (request start to render
    /// complete: the timing event's renderCompleteMs) in the green accent.
    func testC19_5_withDevToolsAndShowOverlayAPageShowsItsLoadInMsAtTheBottomRight() async throws {
        OrcaDebug.reporter = recorder
        OrcaDebug.showOverlay = true
        let (router, loader, model) = try await loaded("home")
        model.appeared()
        let renderComplete = try XCTUnwrap(
            recorder.of("timing").first?.payload["client"]?["renderCompleteMs"].doubleValue)
        XCTAssertEqual(loader.loadTimeMs, renderComplete, "the load is the timing's render complete")

        let drawn = try draw(RoutePage(router: router, route: router.root, isStackRoot: true))
        let box = try XCTUnwrap(chip(in: drawn))
        XCTAssertEqual(box.maxX, 300 - 8, "8 points in from the right")
        XCTAssertEqual(box.maxY, 200 - 8, "8 points up from the bottom")
        let fill = drawn.pixel(Int(box.maxX) - 4, Int(box.maxY) - 2)
        XCTAssertEqual(Int(fill.a), 0xDD, accuracy: 2, "black 87%")
        XCTAssertLessThan(max(fill.r, fill.g, fill.b), 3)
        let green = try XCTUnwrap(drawn.bounds { Int($0.g) - Int($0.r) > 40 && $0.g > 60 }, "the green text")
        XCTAssertTrue(box.contains(green))

        // The text: the same pixels as the chip drawn alone with that load,
        // other than with another load.
        XCTAssertEqual(DebugOverlayModel().lines(loadMs: renderComplete, components: 1),
                       ["\(try XCTUnwrap(DartFormat.fixed(renderComplete, 0)))ms"])
        XCTAssertEqual(drawn.rows(100...199).bytes, try draw(alone(renderComplete, components: 1)).rows(100...199).bytes)
        XCTAssertNotEqual(drawn.rows(100...199).bytes,
                          try draw(alone(renderComplete + 10_000, components: 1)).rows(100...199).bytes)
    }

    /// C19.5 (D6): a tap shows `Load: <load to 1 decimal>ms`, `Components:
    /// <n>` and `Cache: -`, right-aligned, Load in the accent and the others
    /// in white 70%; a second tap folds it back to `<load>ms` (Dart's
    /// `toStringAsFixed`, half away from zero).
    func testC19_5_aTapShowsLoadComponentsAndCacheAndASecondTapFoldsIt() throws {
        var overlay = DebugOverlayModel()
        XCTAssertFalse(overlay.expanded)
        XCTAssertEqual(overlay.lines(loadMs: 12.345, components: 7), ["12ms"])
        overlay.tap()
        XCTAssertTrue(overlay.expanded)
        XCTAssertEqual(overlay.lines(loadMs: 12.345, components: 7),
                       ["Load: 12.3ms", "Components: 7", "Cache: -"])
        overlay.tap()
        XCTAssertFalse(overlay.expanded)
        XCTAssertEqual(overlay.lines(loadMs: 12.345, components: 7), ["12ms"])
        XCTAssertEqual(DebugOverlayModel().lines(loadMs: 12.5, components: 0), ["13ms"])

        var tapped = DebugOverlayModel()
        tapped.tap()
        let folded = try XCTUnwrap(chip(in: try draw(alone(12.345, components: 7))))
        let unfolded = try draw(alone(12.345, components: 7, model: tapped))
        let open = try XCTUnwrap(chip(in: unfolded))
        XCTAssertEqual(open.maxX, 300 - 8)
        XCTAssertEqual(open.maxY, 200 - 8)
        XCTAssertGreaterThan(open.height, folded.height + 18, "three lines")
        XCTAssertGreaterThan(open.width, folded.width, "the longer lines")

        // Three bands of text, each ending at the same right edge.
        let inner = open.insetBy(dx: 8, dy: 4)
        let band = inner.height / 3
        func ink(_ line: Int, _ matches: ((r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool) -> CGRect? {
            let top = Int(inner.minY + band * CGFloat(line)), bottom = Int(inner.minY + band * CGFloat(line + 1)) - 1
            return unfolded.rows(top...bottom).bounds { matches($0) }
        }
        let isGreen: ((r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool = { Int($0.g) - Int($0.r) > 40 && $0.g > 60 }
        let isWhite: ((r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool = {
            $0.r > 60 && abs(Int($0.r) - Int($0.g)) < 12 && abs(Int($0.g) - Int($0.b)) < 12
        }
        let load = try XCTUnwrap(ink(0, isGreen), "Load in the accent")
        let components = try XCTUnwrap(ink(1, isWhite), "Components in white")
        let cache = try XCTUnwrap(ink(2, isWhite), "Cache in white")
        XCTAssertNil(ink(1, isGreen))
        XCTAssertNil(ink(2, isGreen))
        XCTAssertEqual(load.maxX, components.maxX, accuracy: 4, "right-aligned")
        XCTAssertEqual(cache.maxX, components.maxX, accuracy: 4, "right-aligned")
    }

    /// C19.5 (D6): Components is the page's node count, and a page drawn
    /// without the loader (no timing) shows `-ms`, `Load: -ms` unfolded.
    func testC19_5_theChipCountsThePagesNodesAndAPageWithoutATimingShowsDashMs() throws {
        OrcaDebug.reporter = recorder
        OrcaDebug.showOverlay = true
        let counter = OrcaPageModel(page: try recordedPage("counter-home"))
        let timed = try XCTUnwrap(OrcaPageView(model: counter, loadTimeMs: 4.2).debugOverlay)
        XCTAssertEqual(timed.components, counter.page.components.count)
        XCTAssertGreaterThan(timed.components, 1)
        XCTAssertEqual(timed.loadMs, 4.2)

        let bare = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"))
        let untimed = try XCTUnwrap(OrcaPageView(model: bare).debugOverlay, "a page the host draws itself")
        XCTAssertNil(untimed.loadMs)
        var overlay = DebugOverlayModel()
        XCTAssertEqual(overlay.lines(loadMs: nil, components: 0), ["-ms"])
        overlay.tap()
        XCTAssertEqual(overlay.lines(loadMs: nil, components: 0), ["Load: -ms", "Components: 0", "Cache: -"])
        let drawn = try draw(OrcaPageView(model: bare))
        XCTAssertNotNil(chip(in: drawn))
        XCTAssertEqual(drawn.rows(100...199).bytes, try draw(alone(nil, components: 0)).rows(100...199).bytes)
    }

    // MARK: helpers

    /// A page loaded through a router's loader from `PageStub` (one Text,
    /// page id and title the path).
    private func loaded(_ path: String) async throws -> (router: OrcaRouter, loader: OrcaPageLoader,
                                                         model: OrcaPageModel) {
        let router = OrcaRouter(client: PageStub.client(PageStub()), path: path, system: SystemRecorder().actions())
        let loader = router.loader(for: router.root)
        await loader.loadIfNeeded()
        guard case .loaded(let model) = loader.phase else {
            throw NSError(domain: "DebugOverlayTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "\(path) did not load: \(loader.phase)"])
        }
        return (router, loader, model)
    }

    /// `view` in a 300 by 200 box, drawn at scale 1.
    private func draw<V: View>(_ view: V) throws -> Pixels {
        let renderer = ImageRenderer(content: view.frame(width: 300, height: 200))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }

    /// The overlay alone over an empty page.
    private func alone(_ loadMs: Double?, components: Int, model: DebugOverlayModel = DebugOverlayModel())
        -> some View
    {
        Color.clear.overlay(alignment: .bottomTrailing) {
            DebugOverlay(loadMs: loadMs, components: components, model: model)
        }
    }

    /// The chip: the pixels of 80% alpha or more in the lower half, where a
    /// stub page draws nothing.
    private func chip(in pixels: Pixels) -> CGRect? {
        pixels.rows(100...199).bounds { $0.a > 200 }.map { $0.offsetBy(dx: 0, dy: 100) }
    }
}
#endif
