#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import XCTest

@testable import OrcaGateway

/// Pages by name for the SafeArea shell tests: `components[name]` as the
/// page's nodes, nothing for any other name.
struct SafeAreaShellPages: HTTPTransport {
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

/// A3.6 (never twice): a bar that took an inset takes it from the SafeArea
/// below it too. Flutter's Scaffold removes the top padding from its body's
/// MediaQuery when it has an appBar and the bottom padding when it has a
/// bottomNavigationBar or persistent footer (scaffold.dart :3027-3031), and
/// the tab shell is such a Scaffold: a SafeArea in the body sees no inset on
/// those edges, so flagged false it still keeps its content between the
/// bars. Each page is drawn by OrcaApp in a UIKit window with safe-area
/// insets (iOS only); its content is a Column as tall as it is let be, a
/// green box at its top and a blue one at its bottom, found in the pixels,
/// the bars found as UIKit views or by their colour.
@MainActor
final class SafeAreaShellTests: XCTestCase {
    static let accuracy: CGFloat = 0.5
    /// The window's safe-area insets: top 30 and bottom 20 of a 300 by 500
    /// window.
    static let insets = UIEdgeInsets(top: 30, left: 0, bottom: 20, right: 0)

    /// A3.6: in a Scaffold with an AppBar (the navigation bar), a SafeArea
    /// whose top is false keeps its content below the bar, not under it.
    func testA3_6ASafeAreaWithTopFalseUnderAScaffoldsAppBarStaysBelowTheBar() async throws {
        let router = OrcaRouter(client: SafeAreaShellPages(components: ["page": [
            node("s", "Scaffold", ["appBar": "bar", "body": "safe"], ["bar", "safe"], kind: "structure"),
            node("bar", "AppBar", [:], [], kind: "structure"),
        ] + safeArea(["top": false])]).client, path: "page", system: SystemRecorder().actions())
        let window = try await show(router)
        defer { window.isHidden = true }

        let bar = try XCTUnwrap(AppBarCardTests.navigationBar(in: window), "no navigation bar")
        let barBottom = bar.convert(bar.bounds, to: window).maxY
        XCTAssertGreaterThan(barBottom, Self.insets.top, "the bar sits below the top inset")
        let top = try XCTUnwrap(try snapshot(window).bounds(of: FlowTests.isGreen), "the content's top is hidden")
        XCTAssertEqual(top.minY, barBottom, accuracy: Self.accuracy, "the content starts at the bar's bottom")
    }

    /// A3.6: in a Scaffold with a bottomNavigationBar, a SafeArea whose
    /// bottom is false ends its content on the bar's top, not under it.
    func testA3_6ASafeAreaWithBottomFalseAboveAScaffoldsBottomBarEndsOnTheBar() async throws {
        let router = OrcaRouter(client: SafeAreaShellPages(components: ["page": [
            node("s", "Scaffold", ["body": "safe", "bottomNavigationBar": "nav"], ["safe", "nav"],
                 kind: "structure"),
            box("nav", "#FF00FF", 40, 40),
        ] + safeArea(["bottom": false])]).client, path: "page", system: SystemRecorder().actions())
        let window = try await show(router)
        defer { window.isHidden = true }

        let pixels = try snapshot(window)
        let bar = try XCTUnwrap(pixels.bounds(of: FlowTests.isMagenta), "no bottom bar")
        let bottom = try XCTUnwrap(pixels.bounds(of: FlowTests.isBlue), "the content's bottom is hidden")
        XCTAssertEqual(bottom.maxY, bar.minY, accuracy: Self.accuracy, "the content ends on the bar's top")
    }

    /// A3.6: the tab bar took the bottom inset, so a tab page whose root is
    /// a SafeArea with bottom false ends its content on the tab bar's top.
    func testA3_6ATabPageWithBottomFalseEndsOnTheTabBar() async throws {
        let router = try tabRouter(safeArea(["bottom": false]))
        let window = try await show(router)
        defer { window.isHidden = true }

        let tabs = try XCTUnwrap(Self.tabBar(in: window), "no tab bar")
        let tabsTop = tabs.convert(tabs.bounds, to: window).minY
        XCTAssertLessThan(tabsTop, window.bounds.height - Self.insets.bottom, "the tab bar sits above the bottom inset")
        let bottom = try XCTUnwrap(try snapshot(window).bounds(of: FlowTests.isBlue), "the content's bottom is hidden")
        XCTAssertEqual(bottom.maxY, tabsTop, accuracy: Self.accuracy, "the content ends on the tab bar's top")
    }

    /// A3.6: under a shell drawer a tab page gets the shell's top bar,
    /// which took the top inset: a SafeArea with top false keeps its
    /// content below that bar.
    func testA3_6ATabPageWithTopFalseUnderTheShellsTopBarStaysBelowIt() async throws {
        let router = try tabRouter(safeArea(["top": false]), drawer: true)
        let window = try await show(router)
        defer { window.isHidden = true }

        let bar = try XCTUnwrap(AppBarCardTests.navigationBar(in: window), "no navigation bar")
        let barBottom = bar.convert(bar.bounds, to: window).maxY
        XCTAssertGreaterThan(barBottom, Self.insets.top, "the bar sits below the top inset")
        let top = try XCTUnwrap(try snapshot(window).bounds(of: FlowTests.isGreen), "the content's top is hidden")
        XCTAssertEqual(top.minY, barBottom, accuracy: Self.accuracy, "the content starts at the bar's bottom")
    }

    // MARK: helpers

    /// A wire node; a structure node names its slots in `props`.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue], _ children: [String],
              kind: String = "layout") -> JSONValue {
        let mode = kind == "structure" ? "none" : type == "Column" ? "multi" : "single"
        return [
            "id": .string(id), "type": .string(type), "kind": .string(kind), "childMode": .string(mode),
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
        ]
    }

    /// A solid Container of `hex`, `width` by `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)], [])
    }

    /// The SafeArea `safe` with `flags` around a Column as tall as it is
    /// let be: a green 40 by 6 box at its top, a blue one at its bottom.
    func safeArea(_ flags: [String: JSONValue]) -> [JSONValue] {
        [
            node("safe", "SafeArea", flags, ["col"]),
            node("col", "Column", ["mainAxisAlignment": "spaceBetween"], ["top", "bottom"]),
            box("top", "#00FF00", 40, 6),
            box("bottom", "#0000FF", 40, 6),
        ]
    }

    /// A router on the tabs `/home` (whose page is `components`) and
    /// `/more`, with a shell drawer when `drawer`.
    func tabRouter(_ components: [JSONValue], drawer: Bool = false) throws -> OrcaRouter {
        let config: JSONValue = [
            "initialRoute": "/home",
            "drawerItems": drawer ? [["id": "more", "label": "More", "icon": "menu", "route": "/more"]] : [],
            "tabs": [
                ["id": "home", "label": "Home", "icon": "home", "initialRoute": "/home"],
                ["id": "more", "label": "More", "icon": "menu", "initialRoute": "/more"],
            ],
            "flows": [["name": "main", "routes": [["path": "home"], ["path": "more"]]]],
        ]
        return OrcaRouter(client: SafeAreaShellPages(components: ["home": components]).client,
                          config: try config.decode(NavConfig.self), system: SystemRecorder().actions())
    }

    /// OrcaApp on `router` in a light 300 by 500 UIKit window whose safe
    /// area is `insets`, once its first page has loaded and settled.
    func show(_ router: OrcaRouter) async throws -> UIWindow {
        let host = UIHostingController(rootView: OrcaApp(router: router))
        host.additionalSafeAreaInsets = Self.insets
        // Away from the screen's edges, so the device's own insets (the
        // status bar, the home indicator) do not reach it.
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 300, height: 500))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        let loader = router.loader(for: router.root)
        for _ in 0..<30 {
            if case .loaded = loader.phase { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard case .loaded = loader.phase else {
            window.isHidden = true
            throw NSError(domain: "SafeAreaShellTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "the page did not load: \(loader.phase)"])
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(host.view.safeAreaInsets, Self.insets, "the window's safe area")
        return window
    }

    func snapshot(_ window: UIWindow) throws -> Pixels {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }

    static func tabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar, !bar.isHidden { return bar }
        return view.subviews.lazy.compactMap(tabBar(in:)).first
    }
}
#endif
