import Foundation
import XCTest

@testable import OrcaGatewayCore

/// T5: schema/fixtures/navigation through the Swift `RouteTable`, as the
/// Flutter runner (sdk/test/conformance/navigation_fixtures_test.dart) runs
/// them through the real GoRouter. Each case builds the `NavConfig` from the
/// file's `config`, lays the file's `appState` over `initialAppState`,
/// resolves the location and compares every field of `expected` as JSON.
final class NavigationFixtureTests: XCTestCase {
    func test_B9_2_paramMatch() throws {
        try run(prefixes: ["01_"])
    }

    func test_B9_3_unknownPath() throws {
        try run(prefixes: ["02_", "03_"])
    }

    func test_B9_4_redirect() throws {
        try run(prefixes: ["04_", "05_", "06_"])
    }

    func test_B9_5_initialAppState() throws {
        let cases = try run(prefixes: ["07_"])
        XCTAssertGreaterThan(cases.withAppState, 0, "07: no case carries expected.appState")
    }

    func test_B9_9_nestedChildren() throws {
        try run(prefixes: ["08_"])
    }

    func test_B9_10_everyNavigationFixturePasses() throws {
        let files = try Fixtures.navigation()
        XCTAssertEqual(files.count, 11)
        var total = 0
        for (name, fx) in files {
            let ran = try run(name, fx)
            XCTAssertGreaterThan(ran.cases, 0, "\(name): no cases")
            total += ran.cases
        }
        XCTAssertEqual(total, 56)
    }

    // MARK: - Runner

    /// Runs the files whose name starts with one of `prefixes`; every prefix
    /// must name a file and every file must have cases.
    @discardableResult
    private func run(prefixes: [String], file: StaticString = #filePath, line: UInt = #line) throws
        -> (cases: Int, withAppState: Int) {
        let files = try Fixtures.navigation()
        var total = (cases: 0, withAppState: 0)
        for prefix in prefixes {
            let picked = files.filter { $0.name.hasPrefix(prefix) }
            XCTAssertEqual(picked.count, 1, "one navigation fixture named \(prefix)*", file: file, line: line)
            for (name, fx) in picked {
                let ran = try run(name, fx, file: file, line: line)
                XCTAssertGreaterThan(ran.cases, 0, "\(name): no cases", file: file, line: line)
                total.cases += ran.cases
                total.withAppState += ran.withAppState
            }
        }
        return total
    }

    /// One file: every case, a fresh state each (the seed, then the overlay).
    private func run(_ name: String, _ fx: JSONValue, file: StaticString = #filePath, line: UInt = #line) throws
        -> (cases: Int, withAppState: Int) {
        let config = try fx["config"].decode(NavConfig.self)
        let table = RouteTable(config)
        var withAppState = 0
        let cases = fx["cases"].arrayValue ?? []
        for c in cases {
            let label = "\(name) · \(c["name"].stringValue ?? "?")"
            guard let location = c["location"].stringValue, let expected = c["expected"].objectValue else {
                XCTFail("\(label): a case needs a location and an expected object", file: file, line: line)
                continue
            }
            var appState = config.initialAppState
            for (key, value) in fx["appState"].objectValue ?? [:] { appState[key] = value }

            let r = table.resolve(location, appState: appState)

            var actual: [String: JSONValue] = [
                "kind": .string(r.kind.rawValue),
                "location": .string(r.location),
                "redirected": .bool(r.redirected),
            ]
            if r.kind == .page {
                actual["pagePath"] = r.pagePath.map(JSONValue.string) ?? .null
                actual["routePath"] = r.routePath.map(JSONValue.string) ?? .null
                actual["params"] = .object(r.params.mapValues(JSONValue.string))
                actual["stack"] = .array(r.stack.map(JSONValue.string))
                actual["tabIndex"] = r.tabIndex.map(JSONValue.int) ?? .null
                actual["scaffoldTitle"] = r.scaffoldTitle.map(JSONValue.string) ?? .null
                XCTAssertEqual(r.stack.last, r.pagePath, "\(label): the top of the stack is the page", file: file, line: line)
            } else {
                // Nothing is requested on the error screen.
                XCTAssertNil(r.pagePath, "\(label): pagePath", file: file, line: line)
                XCTAssertNil(r.routePath, "\(label): routePath", file: file, line: line)
                XCTAssertEqual(r.params, [:], "\(label): params", file: file, line: line)
                XCTAssertEqual(r.stack, [], "\(label): stack", file: file, line: line)
                XCTAssertNil(r.tabIndex, "\(label): tabIndex", file: file, line: line)
                XCTAssertNil(r.scaffoldTitle, "\(label): scaffoldTitle", file: file, line: line)
                XCTAssertNil(r.transition, "\(label): transition", file: file, line: line)
            }
            // The state at resolve time is the one this runner passed in.
            if expected["appState"] != nil {
                actual["appState"] = .object(appState)
                withAppState += 1
            }
            assertJSONEqual(.object(actual), .object(expected), label, file: file, line: line)
        }
        return (cases.count, withAppState)
    }

    // MARK: - Beyond the fixtures

    func testResolutionCarriesTheTransitionAndTheQuery() {
        let config = NavConfig(initialRoute: "/home", flows: [NavFlow(name: "main", routes: [
            NavRoute(path: "home"),
            NavRoute(path: "product/:id", transition: RouteTransitionDef(type: "fade", duration: 150)),
        ])])
        let table = RouteTable(config)

        let product = table.resolve("/product/4%202?ref=home&q=a+b%21", appState: [:])
        XCTAssertEqual(product.kind, .page)
        XCTAssertEqual(product.location, "/product/4%202?ref=home&q=a+b%21")
        XCTAssertEqual(product.pagePath, "product/4%202")
        XCTAssertEqual(product.params, ["id": "4 2"])
        XCTAssertEqual(product.transition, RouteTransitionDef(type: "fade", duration: 150))
        XCTAssertEqual(product.queryParameters, ["ref": "home", "q": "a b!"])

        let home = table.resolve(config.initialRoute, appState: [:])
        XCTAssertNil(home.transition)
        XCTAssertEqual(home.queryParameters, [:])
        XCTAssertEqual(home, table.resolve("/home", appState: [:]))
    }

    /// Inputs no fixture pins, with the same values as the Kotlin twin's test.
    func test_unpinnedCornersAgreeWithKotlin() {
        // 1. routePath comes from the matched segments, not the config string.
        let plain = RouteTable(NavConfig(initialRoute: "/home", flows: [NavFlow(name: "main", routes: [
            NavRoute(path: "home/"),
            NavRoute(path: "product/:id"),
        ])]))
        XCTAssertEqual(plain.resolve("/home", appState: [:]).routePath, "/home")

        // 2. scaffoldTitle upper-cases the first UTF-16 unit only, as Dart.
        let tabbed = RouteTable(NavConfig(
            initialRoute: "/home",
            tabs: [TabDef(id: "home", label: "Home", icon: "home", initialRoute: "/home")],
            flows: [NavFlow(name: "main", routes: [
                NavRoute(path: "home"),
                NavRoute(path: "😀stats"),
                NavRoute(path: "ßeta"),
            ])]))
        XCTAssertEqual(tabbed.resolve("/😀stats", appState: [:]).scaffoldTitle, "😀stats")
        XCTAssertEqual(tabbed.resolve("/ßeta", appState: [:]).scaffoldTitle, "SSeta")

        // 3. Percent-decoding: valid escapes as UTF-8, an invalid part raw.
        XCTAssertEqual(plain.resolve("/product/😀%20x", appState: [:]).params, ["id": "😀 x"])
        XCTAssertEqual(plain.resolve("/product/%FF", appState: [:]).params, ["id": "%FF"])
        XCTAssertEqual(plain.resolve("/product/a?q=%FF&r=a+b", appState: [:]).queryParameters,
                       ["q": "%FF", "r": "a b"])
    }

    func testRouteChangeEvent() {
        let boot = RouteChangeEvent(location: "/home", type: .push)
        XCTAssertNil(boot.previousLocation)
        XCTAssertEqual(boot, RouteChangeEvent(location: "/home", previousLocation: nil, type: .push))
        XCTAssertNotEqual(boot, RouteChangeEvent(location: "/home", previousLocation: "/a", type: .push))
        XCTAssertEqual([RouteChangeType.push, .replace, .pop].map(\.rawValue), ["push", "replace", "pop"])
    }
}
