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
        XCTAssertEqual(files.count, 14)
        var total = 0
        var sessions = (sessions: 0, steps: 0)
        for (name, fx) in files {
            let ran = try run(name, fx)
            let played = try runSessions(name, fx)
            XCTAssertGreaterThan(ran.cases + played.sessions, 0, "\(name): no cases and no sessions")
            total += ran.cases
            sessions.sessions += played.sessions
            sessions.steps += played.steps
        }
        XCTAssertEqual(total, 56)
        XCTAssertEqual(sessions.sessions, 15)
        XCTAssertEqual(sessions.steps, 87)
    }

    func test_B10_2_tabSessions() throws {
        let ran = try runSessions(prefixes: ["12_"])
        XCTAssertEqual(ran.sessions, 5)
        XCTAssertEqual(ran.steps, 36)
    }

    func test_B10_3_tabIndexStateAndSwitchTab() throws {
        let ran = try runSessions(prefixes: ["13_", "14_"])
        XCTAssertEqual(ran.sessions, 10)
        XCTAssertEqual(ran.steps, 51)
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

    // MARK: - Session runner

    /// Runs the sessions of the files whose name starts with one of
    /// `prefixes`; every prefix must name a file and every file must have
    /// sessions.
    private func runSessions(prefixes: [String], file: StaticString = #filePath, line: UInt = #line) throws
        -> (sessions: Int, steps: Int) {
        let files = try Fixtures.navigation()
        var total = (sessions: 0, steps: 0)
        for prefix in prefixes {
            let picked = files.filter { $0.name.hasPrefix(prefix) }
            XCTAssertEqual(picked.count, 1, "one navigation fixture named \(prefix)*", file: file, line: line)
            for (name, fx) in picked {
                let ran = try runSessions(name, fx, file: file, line: line)
                XCTAssertGreaterThan(ran.sessions, 0, "\(name): no sessions", file: file, line: line)
                total.sessions += ran.sessions
                total.steps += ran.steps
            }
        }
        return total
    }

    /// One file: every session on a fresh `TabShell`, booted with a `go` to
    /// the config's `initialRoute` over the seeded app state. The runner owns
    /// app state: it applies each `tabIndexWrite`, and hands a `setAppState`
    /// of `_tabIndex` to `tabIndexChanged`. After the boot and after every
    /// step: `location`, `tabIndex`, the listed `appState` keys and the page
    /// paths of the entries the step created.
    private func runSessions(_ name: String, _ fx: JSONValue, file: StaticString = #filePath, line: UInt = #line)
        throws -> (sessions: Int, steps: Int) {
        let config = try fx["config"].decode(NavConfig.self)
        let table = RouteTable(config)
        let sessions = fx["sessions"].arrayValue ?? []
        var steps = 0
        for session in sessions {
            let title = "\(name) · \(session["name"].stringValue ?? "?")"
            var shell = TabShell(table: table)
            var appState = config.initialAppState

            func check(_ change: TabShellChange, _ expected: JSONValue, _ label: String) {
                if let index = change.tabIndexWrite { appState["_tabIndex"] = .int(index) }
                guard let wanted = expected["appState"].objectValue,
                      let requests = expected["pageRequests"].arrayValue, expected["location"].stringValue != nil,
                      expected.objectValue?["tabIndex"] != nil else {
                    XCTFail("\(label): expected needs location, tabIndex, appState and pageRequests",
                            file: file, line: line)
                    return
                }
                var seen: [String: JSONValue] = [:]
                for key in wanted.keys { seen[key] = appState[key] }
                let actual: JSONValue = .object([
                    "location": .string(shell.location),
                    "tabIndex": shell.tabIndex.map(JSONValue.int) ?? .null,
                    "appState": .object(seen),
                    "pageRequests": .array(change.requested.map { .string($0.pagePath) }),
                ])
                XCTAssertEqual(seen.count, wanted.count, "\(label): an expected app state key is not set",
                               file: file, line: line)
                XCTAssertEqual(requests.count, change.requested.count, "\(label): pageRequests", file: file, line: line)
                assertJSONEqual(actual, expected, label, file: file, line: line)
                // The page path is the location without its query.
                let path = shell.location.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
                    .first.map { String($0.dropFirst()) }
                XCTAssertEqual(shell.visible.last.map(\.pagePath), shell.location.isEmpty ? nil : path,
                               "\(label): the page on top is the location", file: file, line: line)
            }

            check(shell.go(config.initialRoute, appState: appState), session["boot"]["expected"], "\(title) · boot")
            for (index, step) in (session["steps"].arrayValue ?? []).enumerated() {
                let op = step["op"].stringValue ?? "?"
                let label = "\(title) · step \(index + 1) \(op)"
                let change: TabShellChange
                switch op {
                case "go":
                    change = shell.go(step["location"].stringValue ?? "", appState: appState)
                case "push":
                    change = shell.push(step["location"].stringValue ?? "", appState: appState)
                case "back":
                    change = shell.pop()
                case "tapTab":
                    change = shell.selectTab(step["index"].intValue ?? -1, appState: appState)
                case "switchTab":
                    change = shell.switchTab(step["tabId"].stringValue ?? "", appState: appState)
                case "setAppState":
                    let key = step["key"].stringValue ?? ""
                    appState[key] = step["value"]
                    change = key == "_tabIndex"
                        ? shell.tabIndexChanged(step["value"], appState: appState)
                        : TabShellChange(requested: [], dropped: [], tabIndexWrite: nil)
                default:
                    XCTFail("\(label): unknown op", file: file, line: line)
                    continue
                }
                check(change, step["expected"], label)
                steps += 1
            }
        }
        return (sessions.count, steps)
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

    /// Tab shell inputs no session pins (Flutter throws or asserts there),
    /// with the same answers as the Kotlin twin's test.
    func test_unpinnedTabCornersAgreeWithKotlin() {
        let none = TabShellChange(requested: [], dropped: [], tabIndexWrite: nil)
        let routes = [NavFlow(name: "main", routes: [
            NavRoute(path: "home", children: [NavRoute(path: "home/product/:id")]),
            NavRoute(path: "search"),
            NavRoute(path: "settings"),
        ])]
        let tabbed = RouteTable(NavConfig(
            initialRoute: "/home",
            tabs: [TabDef(id: "home", label: "Home", icon: "home", initialRoute: "/home"),
                   TabDef(id: "search", label: "Search", icon: "search", initialRoute: "/search")],
            flows: routes))
        let plain = RouteTable(NavConfig(initialRoute: "/home", flows: routes))

        var shell = TabShell(table: tabbed)
        var ids: [Int] = []
        func note(_ change: TabShellChange) -> TabShellChange {
            ids += change.requested.map(\.id)
            return change
        }
        let boot = note(shell.go("/home/product/7", appState: [:]))
        XCTAssertEqual(boot.requested.map(\.pagePath), ["home", "home/product/7"])
        XCTAssertEqual(boot.requested.map(\.isTop), [false, true])
        XCTAssertEqual(boot.tabIndexWrite, 0)
        XCTAssertTrue(shell.hasShell)

        // 1. selectTab with an out-of-range index: no change.
        for index in [-1, 2, 99] {
            let before = shell
            XCTAssertEqual(shell.selectTab(index, appState: [:]), none)
            XCTAssertEqual(shell.visible, before.visible)
            XCTAssertEqual(shell.tabIndex, 0)
        }

        // 2. tabIndexChanged with an out-of-range int: no change, no write.
        for index in [-1, 2, 99] {
            XCTAssertEqual(shell.tabIndexChanged(.int(index), appState: [:]), none)
            XCTAssertEqual(shell.location, "/home/product/7")
            XCTAssertEqual(shell.tabIndex, 0)
        }

        // 3. pop() at a tab root with nothing over: no change.
        let popped = shell.pop()
        XCTAssertEqual(popped.requested, [])
        XCTAssertEqual(popped.dropped.map(\.pagePath), ["home/product/7"])
        XCTAssertEqual(shell.location, "/home")
        XCTAssertEqual(shell.pop(), none)
        XCTAssertEqual(shell.location, "/home")
        XCTAssertEqual(shell.visible.map(\.pagePath), ["home"])

        // 4. pop() at the root of a no-tabs app: no change.
        var single = TabShell(table: plain)
        let chain = single.go("/home/product/7", appState: [:])
        XCTAssertEqual(chain.requested.map(\.pagePath), ["home", "home/product/7"])
        XCTAssertNil(chain.tabIndexWrite)
        XCTAssertFalse(single.hasShell)
        XCTAssertNil(single.tabIndex)
        XCTAssertEqual(single.over.map(\.pagePath), ["home", "home/product/7"])
        XCTAssertEqual(single.push("/home/product/8", appState: [:]).requested.map(\.pagePath), ["home/product/8"])
        XCTAssertEqual(single.pop().dropped.map(\.pagePath), ["home/product/8"])
        XCTAssertEqual(single.pop().dropped.map(\.pagePath), ["home/product/7"])
        XCTAssertEqual(single.pop(), none)
        XCTAssertEqual(single.location, "/home")

        // 5. switchTab in a config with no tabs: no change.
        XCTAssertEqual(single.switchTab("home", appState: [:]), none)
        XCTAssertEqual(single.selectTab(0, appState: [:]), none)
        XCTAssertEqual(single.tabIndexChanged(.int(0), appState: [:]), none)
        XCTAssertEqual(single.visible.map(\.pagePath), ["home"])

        // 6. selectTab of another tab under a pushed non-tab route: the
        //    pushed route is dropped and the tab shown, as a `_tabIndex`
        //    write does.
        _ = note(shell.push("/home/product/9", appState: [:]))
        _ = note(shell.selectTab(1, appState: [:]))
        let covered = note(shell.push("/settings", appState: [:]))
        XCTAssertEqual(shell.over.map(\.pagePath), ["settings"])
        XCTAssertEqual(shell.tabIndex, 1)
        let back = note(shell.selectTab(0, appState: [:]))
        XCTAssertEqual(back.requested, [])
        XCTAssertEqual(back.dropped, covered.requested)
        XCTAssertEqual(back.tabIndexWrite, 0)
        XCTAssertEqual(shell.over, [])
        XCTAssertEqual(shell.location, "/home/product/9")
        XCTAssertEqual(shell.visible.map(\.pagePath), ["home", "home/product/9"])

        // 7. Entry ids are unique and increasing across every operation.
        _ = note(shell.go("/settings", appState: [:]))
        XCTAssertFalse(shell.hasShell)
        XCTAssertEqual(shell.tabStacks, [[], []])
        _ = note(shell.switchTab("search", appState: [:]))
        _ = note(shell.tabIndexChanged(.int(0), appState: [:]))
        _ = note(shell.go("/nowhere", appState: [:]))
        XCTAssertEqual(shell.visible.map(\.resolution.kind), [.error])
        _ = note(shell.go("/home", appState: [:]))
        XCTAssertEqual(ids.count, 9)
        XCTAssertEqual(ids, ids.sorted())
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(shell.visible.map(\.id), [ids[ids.count - 1]])

        // Corners 8 to 14: three tabs and one route outside them.
        let three = RouteTable(NavConfig(
            initialRoute: "/home",
            tabs: [TabDef(id: "home", label: "Home", icon: "home", initialRoute: "/home"),
                   TabDef(id: "search", label: "Search", icon: "search", initialRoute: "/search"),
                   TabDef(id: "more", label: "More", icon: "more", initialRoute: "/more")],
            flows: [NavFlow(name: "main", routes: [
                NavRoute(path: "home", children: [NavRoute(path: "home/product/:id")]),
                NavRoute(path: "search"),
                NavRoute(path: "more"),
                NavRoute(path: "settings"),
            ])]))
        var tabs = TabShell(table: three)

        // 8. Entry ids start at 1 and grow by 1 per created entry.
        // 10. location is "" before the first go; a location without a
        //     leading slash gets one; a parent's location is "/" + pagePath.
        XCTAssertEqual(tabs.location, "")
        let first = tabs.go("home/product/7", appState: [:])
        XCTAssertEqual(first.requested.map(\.id), [1, 2])
        XCTAssertEqual(first.requested.map(\.location), ["/home", "/home/product/7"])
        XCTAssertEqual(first.requested.map(\.resolution.location), ["/home/product/7", "/home/product/7"])
        XCTAssertEqual(first.tabIndexWrite, 0)
        XCTAssertEqual(tabs.location, "/home/product/7")

        // 9. A push of an unknown location: an error entry over the shell,
        //    on the stack, not requested, with an id of its own.
        let lost = tabs.push("/nowhere/x?y=1", appState: [:])
        XCTAssertEqual(lost, none)
        XCTAssertEqual(tabs.over.map(\.id), [3])
        XCTAssertEqual(tabs.over.map(\.resolution.kind), [.error])
        XCTAssertEqual(tabs.over.map(\.isTop), [true])
        XCTAssertEqual(tabs.over.map(\.pagePath), ["nowhere/x"])
        XCTAssertEqual(tabs.over.map(\.location), ["/nowhere/x?y=1"])
        XCTAssertEqual(tabs.location, "/nowhere/x?y=1")
        XCTAssertTrue(tabs.hasShell)
        XCTAssertEqual(tabs.tabIndex, 0)
        XCTAssertEqual(tabs.tabStacks.map { $0.map(\.id) }, [[1, 2], [], []])

        // 12. With something over the shell every push goes onto `over`,
        //     a tab's route too.
        XCTAssertEqual(tabs.push("/settings", appState: [:]).requested.map(\.id), [4])
        let tabOver = tabs.push("/search", appState: [:])
        XCTAssertEqual(tabOver.requested.map(\.id), [5])
        XCTAssertNil(tabOver.tabIndexWrite)
        XCTAssertEqual(tabs.over.map(\.id), [3, 4, 5])
        XCTAssertEqual(tabs.tabStacks.map { $0.map(\.id) }, [[1, 2], [], []])
        XCTAssertEqual(tabs.tabIndex, 0)
        //     Reselect drops what is over and pops the tab to its root.
        let reselect = tabs.selectTab(0, appState: [:])
        XCTAssertEqual(reselect.requested, [])
        XCTAssertEqual(reselect.dropped.map(\.id), [2, 3, 4, 5])
        XCTAssertNil(reselect.tabIndexWrite)
        XCTAssertEqual(tabs.visible.map(\.id), [1])
        XCTAssertEqual(tabs.over, [])
        XCTAssertEqual(tabs.location, "/home")

        // 9. A go to an unknown location unmounts the shell.
        let gone = tabs.go("nowhere?z=2", appState: [:])
        XCTAssertEqual(gone.requested, [])
        XCTAssertEqual(gone.dropped.map(\.id), [1])
        XCTAssertNil(gone.tabIndexWrite)
        XCTAssertFalse(tabs.hasShell)
        XCTAssertNil(tabs.tabIndex)
        XCTAssertEqual(tabs.tabStacks, [[], [], []])
        XCTAssertEqual(tabs.over.map(\.id), [6])
        XCTAssertEqual(tabs.over.map(\.resolution.kind), [.error])
        XCTAssertEqual(tabs.over.map(\.isTop), [true])
        XCTAssertEqual(tabs.over.map(\.pagePath), ["nowhere"])
        XCTAssertEqual(tabs.location, "/nowhere?z=2")

        // 12. With no shell every push goes onto `over`, a tab's route too.
        let tabLoose = tabs.push("/search", appState: [:])
        XCTAssertEqual(tabLoose.requested.map(\.id), [7])
        XCTAssertNil(tabLoose.tabIndexWrite)
        XCTAssertEqual(tabs.over.map(\.id), [6, 7])
        XCTAssertFalse(tabs.hasShell)
        XCTAssertEqual(tabs.tabStacks, [[], [], []])

        // 13. With no shell tabIndexChanged changes nothing, and go makes
        //     every entry of the chain fresh.
        XCTAssertEqual(tabs.tabIndexChanged(.int(1), appState: [:]), none)
        XCTAssertEqual(tabs.over.map(\.id), [6, 7])
        let outside = tabs.go("/settings", appState: [:])
        XCTAssertEqual(outside.requested.map(\.id), [8])
        XCTAssertEqual(outside.dropped.map(\.id), [6, 7])
        let outsideAgain = tabs.go("/settings", appState: [:])
        XCTAssertEqual(outsideAgain.requested.map(\.id), [9])
        XCTAssertEqual(outsideAgain.dropped.map(\.id), [8])
        XCTAssertNil(outsideAgain.tabIndexWrite)
        var loose = TabShell(table: plain)
        XCTAssertEqual(loose.go("/home/product/7", appState: [:]).requested.map(\.id), [1, 2])
        let looseAgain = loose.go("/home/product/7", appState: [:])
        XCTAssertEqual(looseAgain.requested.map(\.id), [3, 4])
        XCTAssertEqual(looseAgain.dropped.map(\.id), [1, 2])
        XCTAssertNil(looseAgain.tabIndexWrite)

        // 11. A go into a tab keeps an entry with the same page path at the
        //     same position, whatever the query: the top one takes the new
        //     resolution under the same id and nothing is requested.
        let queryA = tabs.go("/search?q=a", appState: [:])
        XCTAssertEqual(queryA.requested.map(\.id), [10])
        XCTAssertEqual(queryA.dropped.map(\.id), [9])
        XCTAssertEqual(queryA.tabIndexWrite, 1)
        XCTAssertEqual(tabs.go("/search?q=a", appState: [:]), none)
        XCTAssertEqual(tabs.visible.map(\.id), [10])
        let queryB = tabs.go("/search?q=b", appState: [:])
        XCTAssertEqual(queryB.requested, [])
        XCTAssertEqual(queryB.dropped, [])
        XCTAssertNil(queryB.tabIndexWrite)
        XCTAssertEqual(tabs.visible.map(\.id), [10])
        XCTAssertEqual(tabs.visible.map(\.location), ["/search?q=b"])
        XCTAssertEqual(tabs.visible.map(\.resolution.location), ["/search?q=b"])
        XCTAssertEqual(tabs.visible.map(\.isTop), [true])
        XCTAssertEqual(tabs.location, "/search?q=b")
        //     A parent that becomes the top stays and its child is dropped;
        //     the child is requested again, as a new entry over a parent
        //     that is no longer the top.
        let child = tabs.go("/home/product/7", appState: [:])
        XCTAssertEqual(child.requested.map(\.id), [11, 12])
        XCTAssertEqual(child.tabIndexWrite, 0)
        let parent = tabs.go("/home", appState: [:])
        XCTAssertEqual(parent.requested, [])
        XCTAssertEqual(parent.dropped.map(\.id), [12])
        XCTAssertNil(parent.tabIndexWrite)
        XCTAssertEqual(tabs.visible.map(\.id), [11])
        XCTAssertEqual(tabs.visible.map(\.isTop), [true])
        XCTAssertEqual(tabs.visible.map(\.location), ["/home"])
        XCTAssertEqual(tabs.location, "/home")
        let childAgain = tabs.go("/home/product/7", appState: [:])
        XCTAssertEqual(childAgain.requested.map(\.id), [13])
        XCTAssertEqual(childAgain.requested.map(\.pagePath), ["home/product/7"])
        XCTAssertEqual(childAgain.dropped, [])
        XCTAssertEqual(tabs.visible.map(\.id), [11, 13])
        XCTAssertEqual(tabs.visible.map(\.isTop), [false, true])
        XCTAssertEqual(tabs.visible.map(\.location), ["/home", "/home/product/7"])

        // 13. tabIndexChanged: another valid tab is written; the current
        //     index or a non-int changes nothing.
        let toMore = tabs.tabIndexChanged(.int(2), appState: [:])
        XCTAssertEqual(toMore.requested.map(\.id), [14])
        XCTAssertEqual(toMore.requested.map(\.pagePath), ["more"])
        XCTAssertEqual(toMore.dropped, [])
        XCTAssertEqual(toMore.tabIndexWrite, 2)
        for value in [JSONValue.int(2), .string("1"), .double(1.5), .bool(true), .null, nil] {
            XCTAssertEqual(tabs.tabIndexChanged(value, appState: [:]), none)
            XCTAssertEqual(tabs.tabIndex, 2)
            XCTAssertEqual(tabs.location, "/more")
        }
        XCTAssertEqual(tabs.tabIndexChanged(.int(1), appState: [:]),
                       TabShellChange(requested: [], dropped: [], tabIndexWrite: 1))
        XCTAssertEqual(tabs.location, "/search?q=b")
        //     _tabIndex is written when the current tab changes; a go
        //     inside the current tab writes nothing.
        let toHome = tabs.go("/home", appState: [:])
        XCTAssertEqual(toHome.requested, [])
        XCTAssertEqual(toHome.dropped.map(\.id), [13])
        XCTAssertEqual(toHome.tabIndexWrite, 0)
        let inside = tabs.go("/home/product/3", appState: [:])
        XCTAssertEqual(inside.requested.map(\.id), [15])
        XCTAssertEqual(inside.dropped, [])
        XCTAssertNil(inside.tabIndexWrite)
        XCTAssertEqual(tabs.visible.map(\.id), [11, 15])
        XCTAssertEqual(tabs.tabStacks.map { $0.map(\.id) }, [[11, 15], [10], [14]])

        // 14. An error entry's page path drops a fragment as well as the
        //     query.
        var lostAgain = TabShell(table: three)
        XCTAssertEqual(lostAgain.go("/nowhere/x?y=1#frag", appState: [:]), none)
        XCTAssertEqual(lostAgain.over.map(\.resolution.kind), [.error])
        XCTAssertEqual(lostAgain.over.map(\.pagePath), ["nowhere/x"])
        var lostBare = TabShell(table: three)
        _ = lostBare.go("/nowhere/x#frag", appState: [:])
        XCTAssertEqual(lostBare.over.map(\.pagePath), ["nowhere/x"])
    }

    func testRouteChangeEvent() {
        let boot = RouteChangeEvent(location: "/home", type: .push)
        XCTAssertNil(boot.previousLocation)
        XCTAssertEqual(boot, RouteChangeEvent(location: "/home", previousLocation: nil, type: .push))
        XCTAssertNotEqual(boot, RouteChangeEvent(location: "/home", previousLocation: "/a", type: .push))
        XCTAssertEqual([RouteChangeType.push, .replace, .pop].map(\.rawValue), ["push", "replace", "pop"])
    }
}
