import Foundation
import XCTest

@testable import OrcaGatewayCore

/// Native parity step 11: the pure part of deep links. The location of a
/// link (design D1), the event the callback receives (D3) and a link as a
/// `go` on a `TabShell` (D2, D5). The fixture
/// schema/fixtures/navigation/15_deep_links.json runs in
/// `NavigationFixtureTests`; here are the inputs it does not pin.
final class DeepLinkTests: XCTestCase {
    // MARK: L1 the location of a link

    func test_L1_locationOfALink() {
        let pinned: [(link: String, location: String)] = [
            // https: scheme and host dropped.
            ("https://shop.example/settings", "/settings"),
            // A custom scheme: the first part after `//` is a host.
            ("orcashop://open/settings", "/settings"),
            ("orcashop://settings", "/"),
            // The query is kept as given, the fragment dropped.
            ("https://shop.example/settings?tab=2&ref=mail#top", "/settings?tab=2&ref=mail"),
            ("https://shop.example/account?tab=2#x", "/account?tab=2"),
            ("app://host/account?tab=2", "/account?tab=2"),
            // A trailing slash is dropped; an empty path is "/".
            ("https://shop.example/settings/", "/settings"),
            ("https://shop.example/settings/?tab=2", "/settings?tab=2"),
            ("https://shop.example", "/"),
            ("https://shop.example/", "/"),
            ("https://shop.example?x=1", "/?x=1"),
            // The path keeps its case.
            ("https://shop.example/Settings", "/Settings"),
            ("orcashop://open/order/7?gift=1", "/order/7?gift=1"),
        ]
        for (link, location) in pinned {
            XCTAssertEqual(DeepLink.location(of: link), location, link)
            if let url = URL(string: link) {
                XCTAssertEqual(DeepLink.location(of: url), location, "URL \(link)")
            } else {
                XCTFail("\(link): not a URL")
            }
        }
    }

    func test_L1_oddLinks() {
        let odd: [(link: String, location: String)] = [
            // The scheme is dropped whatever its case; so is the host's.
            ("HTTPS://Shop.Example/Settings", "/Settings"),
            ("OrcaShop://OPEN/settings", "/settings"),
            // Percent-encoding is kept as is, in the path and in the query.
            ("https://shop.example/product/4%202?q=a+b%21", "/product/4%202?q=a+b%21"),
            ("https://shop.example/a%2Fb", "/a%2Fb"),
            // A bare path, with and without its slash.
            ("/settings", "/settings"),
            ("/settings/", "/settings"),
            ("/settings?tab=2#top", "/settings?tab=2"),
            ("settings", "/settings"),
            ("home/product/42", "/home/product/42"),
            ("/", "/"),
            // Nothing at all, and nothing but a query or a fragment.
            ("", "/"),
            ("?tab=2", "/?tab=2"),
            ("#top", "/"),
            ("https://shop.example/#top", "/"),
            // An empty query is no query.
            ("https://shop.example/settings?", "/settings"),
            ("https://shop.example/settings?#top", "/settings"),
            // A `?` or a `/` inside the query stays; a `#` ends it.
            ("https://shop.example/go?next=/a/b?c=1&d=//x#y?z", "/go?next=/a/b?c=1&d=//x"),
            // Port and user info belong to the host.
            ("https://user:pw@shop.example:8443/settings", "/settings"),
            ("orcashop://open:80", "/"),
            // A scheme without `//`: what follows is the path.
            ("orcashop:settings", "/settings"),
            ("orcashop:/settings?tab=2", "/settings?tab=2"),
            ("orcashop:", "/"),
            // No host between the slashes.
            ("orcashop:///settings", "/settings"),
            ("file:///settings/", "/settings"),
            // A colon that is no scheme: after a slash, or after a `?`.
            ("/order/a:b", "/order/a:b"),
            ("order/a:b", "/order/a:b"),
            ("?at=10:30", "/?at=10:30"),
            // Every trailing slash goes.
            ("https://shop.example/settings//", "/settings"),
            ("https://shop.example//", "/"),
        ]
        for (link, location) in odd {
            XCTAssertEqual(DeepLink.location(of: link), location, "'\(link)'")
        }
        // A location is its own location.
        for (_, location) in odd {
            XCTAssertEqual(DeepLink.location(of: location), location, "again '\(location)'")
        }
    }

    // MARK: L3, L4 the event

    private var table: RouteTable {
        RouteTable(NavConfig(
            initialRoute: "/home",
            initialAppState: ["loggedIn": false],
            flows: [NavFlow(name: "main", routes: [
                NavRoute(path: "home"),
                NavRoute(path: "login"),
                NavRoute(path: "account", redirect: RedirectRule(when: "loggedIn", equals: false, to: "/login?why=link")),
                NavRoute(path: "order/:id"),
            ])]))
    }

    private func event(_ link: String, loggedIn: Bool = false, coldStart: Bool = false) throws -> DeeplinkEvent {
        let url = try XCTUnwrap(URL(string: link), link)
        let resolution = table.resolve(DeepLink.location(of: url), appState: ["loggedIn": .bool(loggedIn)])
        return DeepLink.event(link: url, resolution: resolution, coldStart: coldStart)
    }

    func test_L1_eventOfAPlainLink() throws {
        let e = try event("orcashop://open/order/4%202/?gift=1&note=a+b#top")
        XCTAssertEqual(e.incoming.absoluteString, "orcashop://open/order/4%202/?gift=1&note=a+b#top")
        XCTAssertEqual(e.resolvedLocation, "/order/4%202?gift=1&note=a+b")
        XCTAssertEqual(e.pathParameters, ["id": "4 2"])
        XCTAssertEqual(e.queryParameters, ["gift": "1", "note": "a b"])
        // A trailing slash is not a redirect.
        XCTAssertFalse(e.wasRedirected)
        XCTAssertFalse(e.isColdStart)
        XCTAssertEqual(e, DeeplinkEvent(
            incoming: try XCTUnwrap(URL(string: "orcashop://open/order/4%202/?gift=1&note=a+b#top")),
            resolvedLocation: "/order/4%202?gift=1&note=a+b", pathParameters: ["id": "4 2"],
            queryParameters: ["gift": "1", "note": "a b"], wasRedirected: false, isColdStart: false))
    }

    func test_L3_eventOfARedirectedLink() throws {
        let e = try event("https://shop.example/account?from=mail", coldStart: true)
        XCTAssertEqual(e.incoming.absoluteString, "https://shop.example/account?from=mail")
        // The rule's target; the asked query is gone, the target's is there.
        XCTAssertEqual(e.resolvedLocation, "/login?why=link")
        XCTAssertEqual(e.pathParameters, [:])
        XCTAssertEqual(e.queryParameters, ["why": "link"])
        XCTAssertTrue(e.wasRedirected)
        XCTAssertTrue(e.isColdStart)

        let allowed = try event("https://shop.example/account?from=mail", loggedIn: true)
        XCTAssertEqual(allowed.resolvedLocation, "/account?from=mail")
        XCTAssertEqual(allowed.queryParameters, ["from": "mail"])
        XCTAssertFalse(allowed.wasRedirected)
        XCTAssertFalse(allowed.isColdStart)
    }

    func test_L4_eventOfAnUnknownLink() throws {
        let e = try event("https://shop.example/nowhere/?x=1")
        XCTAssertEqual(e.resolvedLocation, "/nowhere?x=1")
        XCTAssertEqual(e.pathParameters, [:])
        XCTAssertEqual(e.queryParameters, ["x": "1"])
        XCTAssertFalse(e.wasRedirected)

        // A host alone: the empty path is "/", which is no redirect.
        let host = try event("orcashop://account")
        XCTAssertEqual(host.resolvedLocation, "/")
        XCTAssertFalse(host.wasRedirected)
    }

    // MARK: L3, L4 a link on a shell

    func test_L3_L4_aLinkIsAGoExceptToTheLocationOnScreen() {
        let none = TabShellChange(requested: [], dropped: [], tabIndexWrite: nil)
        let state: [String: JSONValue] = ["loggedIn": false]
        var shell = TabShell(table: table)
        _ = shell.go("/home", appState: state)

        // A go: the page is requested, what was shown is dropped.
        let order = shell.open(link: "/order/7?gift=1", appState: state)
        XCTAssertEqual(order.resolution, table.resolve("/order/7?gift=1", appState: state))
        XCTAssertEqual(order.change.requested.map(\.pagePath), ["order/7"])
        XCTAssertEqual(order.change.dropped.map(\.pagePath), ["home"])
        XCTAssertEqual(shell.location, "/order/7?gift=1")

        // The location on screen: nothing changes, the resolution is there.
        let before = shell.visible
        let again = shell.open(link: "/order/7?gift=1", appState: state)
        XCTAssertEqual(again.change, none)
        XCTAssertEqual(again.resolution, order.resolution)
        XCTAssertEqual(shell.visible, before)
        // Another query is another location.
        let other = shell.open(link: "/order/7?gift=2", appState: state)
        XCTAssertEqual(other.change.requested.map(\.pagePath), ["order/7"])
        XCTAssertEqual(shell.location, "/order/7?gift=2")

        // Redirected: the target is shown and requested.
        let account = shell.open(link: "/account?from=mail", appState: state)
        XCTAssertTrue(account.resolution.redirected)
        XCTAssertEqual(account.change.requested.map(\.pagePath), ["login"])
        XCTAssertEqual(shell.location, "/login?why=link")
        // Redirected onto the location on screen: nothing changes, and the
        // resolution is the link's, redirected.
        let shown = shell.visible
        let accountAgain = shell.open(link: "/account", appState: state)
        XCTAssertEqual(accountAgain.change, none)
        XCTAssertTrue(accountAgain.resolution.redirected)
        XCTAssertEqual(accountAgain.resolution.location, "/login?why=link")
        XCTAssertEqual(shell.visible, shown)

        // Unknown: the error entry, nothing requested, the location kept.
        let lost = shell.open(link: "/nowhere?x=1", appState: state)
        XCTAssertEqual(lost.resolution.kind, .error)
        XCTAssertEqual(lost.change.requested, [])
        XCTAssertEqual(lost.change.dropped.map(\.pagePath), ["login"])
        XCTAssertEqual(shell.location, "/nowhere?x=1")
        XCTAssertEqual(shell.visible.map(\.resolution.kind), [.error])
        let lostAgain = shell.open(link: "/nowhere?x=1", appState: state)
        XCTAssertEqual(lostAgain.change, none)
        XCTAssertEqual(lostAgain.resolution.kind, .error)

        // A fresh shell: the link is the boot.
        var cold = TabShell(table: table)
        let boot = cold.open(link: "/account?from=mail", appState: state)
        XCTAssertEqual(boot.change.requested.map(\.pagePath), ["login"])
        XCTAssertEqual(boot.change.dropped, [])
        XCTAssertEqual(cold.location, "/login?why=link")
    }
}
