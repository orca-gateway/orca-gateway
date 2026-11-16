import XCTest

@testable import OrcaGatewayCore

/// T1.1: every render fixture's expected nodes decode into `ComponentNode`
/// and encode back JSON-equal; the action fixtures do the same for `Action`.
final class ModelRoundTripTests: XCTestCase {
    func testAllRenderFixturesRoundTrip() throws {
        let files = try Fixtures.files("render")
        XCTAssertEqual(files.count, 51, "render fixtures 01-43, 60-67")
        var nodes = 0
        for (name, fixture) in files {
            let expected = fixture["expected"]
            guard case .array(let items) = expected else {
                XCTFail("\(name): expected is not an array")
                continue
            }
            let decoded = try decodeModel([ComponentNode].self, from: expected)
            XCTAssertEqual(decoded.count, items.count, name)
            assertJSONEqual(try jsonOf(decoded), expected, name)
            nodes += decoded.count
        }
        XCTAssertGreaterThan(nodes, 24)
    }

    func testRenderFixtureNodesDecodeTheirFields() throws {
        let fixture = try Fixtures.json("schema/fixtures/render/06_nested_state.json")
        let nodes = try decodeModel([ComponentNode].self, from: fixture["expected"])
        XCTAssertEqual(nodes.map(\.id), ["col", "lbl"])
        XCTAssertEqual(nodes[0].kind, .layout)
        XCTAssertEqual(nodes[0].childMode, .multi)
        XCTAssertEqual(nodes[0].children, ["lbl"])
        XCTAssertEqual(nodes[1].watches, ["count", "theme.color"])
        XCTAssertEqual(nodes[1].props["data"]?["key"], "theme.color")
    }

    func testAllActionFixturesRoundTrip() throws {
        let files = try Fixtures.files("actions")
        XCTAssertEqual(files.count, 26, "action fixtures 01-19, 30-33, 45-47")
        var kinds = Set<String>()
        for (name, fixture) in files {
            // A fixture runs either `actions` or `steps` [{action, source?, event?}].
            let steps = fixture["steps"].arrayValue
            XCTAssertNotEqual(fixture["actions"].isNull, steps == nil, "\(name): actions or steps, one of them")
            var lists: [JSONValue] = fixture["actions"].isNull ? [] : [fixture["actions"]]
            if let steps { lists.append(.array(steps.map { $0["action"] })) }
            if case .object(let responses) = fixture["serverResponses"] {
                lists += responses.values.map { $0["actions"] }.filter { !$0.isNull }
            }
            // A bare plugin type (fixture 45's `hapticFeedback`) is unknown to
            // the model by design; it may appear only where a handler runs it.
            let handled = Set((fixture["handlers"].arrayValue ?? []).compactMap(\.stringValue))
            for list in lists {
                let actions = try decodeModel([Action].self, from: list)
                assertJSONEqual(try jsonOf(actions), list, name)
                for action in actions {
                    XCTAssertFalse(isUnknown(action) && !handled.contains(action.kind),
                                   "\(name): \(action.kind) decoded as unknown")
                    collectKinds(action, into: &kinds)
                }
            }
            // State snapshots and effects are data too. `{"kind": "handler"}`
            // entries are the runner's handler records, not SDK effects.
            let state = try decodeModel(StoreState.self, from: fixture["expected"]["state"])
            assertJSONEqual(try jsonOf(state), fixture["expected"]["state"], name)
            let sdkEffects = JSONValue.array(try XCTUnwrap(fixture["expected"]["effects"].arrayValue, name)
                .filter { $0["kind"].stringValue != "handler" })
            let effects = try decodeModel([ActionEffect].self, from: sdkEffects)
            assertJSONEqual(.array(effects.map(\.json)), sdkEffects, name)
        }
        // Every advertised kind appears in the fixtures, except the three
        // component kinds: a fixture compares state and effects, not the node
        // tree, so ComponentMutationTests pins them against Dart's
        // ComponentStore instead.
        let structural: Set<String> = ["addComponent", "updateComponent", "deleteComponent"]
        XCTAssertTrue(kinds.isSuperset(of: Set(GeneratedCapabilities.actionKinds).subtracting(structural)),
                      "\(kinds)")
    }

    func testEveryActionKindRoundTrips() throws {
        // One instance per kind, including the 16 the alpha executor skips.
        let samples: [Action] = [
            .navigate(.init(route: "/detail", params: ["id": ["type": "static", "value": 7]], replace: true)),
            .goBack,
            .switchTab(.init(tabId: "home")),
            .openDrawer,
            .openDialog(.init(dialogId: "confirm", heightFactor: 0.5)),
            .closeDialog,
            .setState(.init(key: "count", scope: .app, value: 3)),
            .clearState(.init(key: "count", scope: .page)),
            .persistState(.init(key: "token", scope: .app, storage: "local")),
            .serverAction(.init(id: "save", params: ["a": ["type": "state", "key": "a", "scope": "page"]])),
            .showSnackbar(.init(message: "Saved", duration: 3000, action: "Undo")),
            .showToast(.init(message: "Hi", duration: 2000)),
            .updateComponent(.init(id: "n1", props: ["data": "x"])),
            .deleteComponent(.init(id: "n1")),
            .addComponent(.init(parentId: "root", node: ["type": "Text"], position: 0)),
            .copyToClipboard(.init(text: "copied")),
            .share(.init(title: "T", message: "M", url: "https://example.com")),
            .openUrl(.init(url: "https://example.com")),
            .actionGroup(.init(mode: "sequential", actions: [.goBack, .refetchPage])),
            .conditionalAction(.init(
                branches: [.init(when: .eq(left: 1, right: 1), then: .goBack)], else: .closeDialog)),
            .animateForward(.init(animationId: "fade")),
            .animateReverse(.init(animationId: "fade")),
            .refetchPage,
            .updateSubPage(.init(subPageId: "tab", pageId: "feed", params: nil, mode: "replace")),
            .lifecycle(.init(
                action: .goBack, onLoading: .single(.showToast(.init(message: "…"))),
                onSuccess: .many([.goBack, .refetchPage]))),
            .debugLog(.init(level: "info", message: "hello", tag: "t", includeState: true)),
            .once(.init(action: .goBack)),
            .always(.init(action: .refetchPage)),
            .custom(["type": "custom:confetti", "count": 3]),
            .unknown(["type": "teleport", "to": "mars"]),
        ]
        XCTAssertEqual(
            Set(samples.map(\.kind)).intersection(Action.kinds).count, 28, "all 28 kinds covered")
        for action in samples {
            let json = try jsonOf(action)
            XCTAssertEqual(json["type"].stringValue, action.kind)
            XCTAssertEqual(try decodeModel(Action.self, from: json), action, action.kind)
        }
        XCTAssertEqual(
            try decodeModel(Action.self, from: ["type": "custom:confetti", "count": 3]),
            .custom(["type": "custom:confetti", "count": 3]))
    }

    func testPageResponseKeepsExtraMembers() throws {
        let render = try Fixtures.json("schema/fixtures/render/07_scaffold_slots.json")
        let body: JSONValue = [
            "pageId": "home",
            "title": "Home",
            "state": [
                ["key": "count", "scope": "page", "initial": 0],
                ["key": "user", "scope": "app", "initial": nil],
            ],
            "components": render["expected"],
            "capabilityWarnings": ["degraded": ["Checkbox"]],
        ]
        let page = try decodeModel(PageResponse.self, from: body)
        XCTAssertEqual(page.pageId, "home")
        XCTAssertEqual(page.state[1].initial, .null)
        XCTAssertEqual(page.extra.keys.sorted(), ["capabilityWarnings"])
        XCTAssertEqual(page.nodesById.count, page.components.count)
        assertJSONEqual(try jsonOf(page), body)
    }

    func testTypedValueAndExpressionsDecodeFixtureProps() throws {
        // Every Value object found in fixture props decodes as a typed Value
        // and encodes back equal (modulo the default `scope: page`).
        var count = 0
        for (name, fixture) in try Fixtures.files("render") {
            for node in fixture["expected"].arrayValue ?? [] {
                for value in valueObjects(in: node["props"]) {
                    let typed = try decodeModel(Value.self, from: value)
                    XCTAssertEqual(try decodeModel(Value.self, from: typed.json), typed, name)
                    count += 1
                }
            }
        }
        XCTAssertGreaterThanOrEqual(count, 9, "Value objects in fixtures 01-41")
    }

    // MARK: B9.1-CS the navigation fixtures' configs are /config bodies

    func testB9_1_CS_EveryNavigationFixtureConfigDecodes() throws {
        let files = try Fixtures.navigation()
        XCTAssertEqual(files.count, 15, "navigation fixtures 01-15")
        var routes = 0
        for (name, fixture) in files {
            let json = fixture["config"]
            guard case .object(let object) = json else {
                XCTFail("\(name): config is not an object")
                continue
            }
            let config = try decodeModel(NavConfig.self, from: json)
            assertJSONEqual(config.raw, json, name)
            XCTAssertNil(config.rawBody, name)
            XCTAssertEqual(config.initialRoute, object["initialRoute"]?.stringValue ?? "/", name)
            XCTAssertEqual(config.tabs.count, object["tabs"]?.arrayValue?.count ?? 0, name)
            XCTAssertEqual(config.tabs.map(\.initialRoute),
                           (object["tabs"]?.arrayValue ?? []).compactMap { $0["initialRoute"].stringValue }, name)
            XCTAssertEqual(config.drawerItems.count, object["drawerItems"]?.arrayValue?.count ?? 0, name)
            assertJSONEqual(.object(config.initialAppState), object["initialAppState"] ?? .object([:]), name)
            let flows = object["flows"]?.arrayValue ?? []
            XCTAssertEqual(config.flows.map(\.name), flows.compactMap { $0["name"].stringValue }, name)
            for (flow, raw) in zip(config.flows, flows) {
                XCTAssertEqual(paths(flow.routes), rawPaths(raw["routes"]), name)
                routes += paths(flow.routes).count
            }
        }
        XCTAssertGreaterThan(routes, 11)
    }

    func testB9_1_CS_AMissingRequiredKeyIsADecodeError() {
        let noTabId: JSONValue = ["tabs": [["label": "Home", "icon": "home", "initialRoute": "/home"]]]
        XCTAssertThrowsError(try decodeModel(NavConfig.self, from: noTabId)) {
            XCTAssertTrue($0 is DecodingError, "\($0)")
        }
        let noPath: JSONValue = ["flows": [["name": "main", "routes": [["requiredAppState": []]]]]]
        XCTAssertThrowsError(try decodeModel(NavConfig.self, from: noPath))
        let noFlowName: JSONValue = ["flows": [["routes": []]]]
        XCTAssertThrowsError(try decodeModel(NavConfig.self, from: noFlowName))
        let noRedirectTarget: JSONValue = [
            "flows": [["name": "m", "routes": [["path": "a", "redirect": ["when": "k", "equals": 1]]]]]
        ]
        XCTAssertThrowsError(try decodeModel(NavConfig.self, from: noRedirectTarget))
        let noTransitionType: JSONValue = [
            "flows": [["name": "m", "routes": [["path": "a", "transition": ["duration": 100]]]]]
        ]
        XCTAssertThrowsError(try decodeModel(NavConfig.self, from: noTransitionType))
    }

    func testB9_1_CS_AnEmptyConfigTakesTheFlutterDefaults() throws {
        let config = try decodeModel(NavConfig.self, from: [:])
        XCTAssertEqual(config.initialRoute, "/")
        XCTAssertEqual(config.tabs, [])
        XCTAssertEqual(config.drawerItems, [])
        XCTAssertEqual(config.initialAppState, [:])
        XCTAssertEqual(config.tabBarComponents, [])
        XCTAssertEqual(config.drawerComponents, [])
        XCTAssertEqual(config.flows, [])
        let flow = try decodeModel(NavFlow.self, from: ["name": "main"])
        XCTAssertEqual(flow, NavFlow(name: "main"))
        XCTAssertNil(flow.version)
        XCTAssertFalse(flow.isStatic)
        XCTAssertNil(flow.pages)
        let route = try decodeModel(NavRoute.self, from: ["path": "home", "transition": ["type": "fade"]])
        XCTAssertEqual(route.children, [])
        XCTAssertNil(route.redirect)
        XCTAssertFalse(route.isDynamic)
        XCTAssertEqual(route.transition, RouteTransitionDef(type: "fade", duration: 300, curve: "easeInOut"))
    }

    // MARK: helpers

    /// Every route path of a tree, a node before its children.
    private func paths(_ routes: [NavRoute]) -> [String] {
        routes.flatMap { [$0.path] + paths($0.children) }
    }

    private func rawPaths(_ routes: JSONValue) -> [String] {
        (routes.arrayValue ?? []).flatMap { [$0["path"].stringValue ?? "?"] + rawPaths($0["children"]) }
    }

    private func isUnknown(_ action: Action) -> Bool {
        if case .unknown = action { return true }
        return false
    }

    private func collectKinds(_ action: Action, into kinds: inout Set<String>) {
        kinds.insert(action.kind)
        switch action {
        case .actionGroup(let g): g.actions.forEach { collectKinds($0, into: &kinds) }
        case .conditionalAction(let c):
            c.branches.forEach { collectKinds($0.then, into: &kinds) }
            if let e = c.else { collectKinds(e, into: &kinds) }
        case .lifecycle(let l):
            collectKinds(l.action, into: &kinds)
            for list in [l.onLoading, l.onSuccess, l.onError, l.onComplete].compactMap({ $0 }) {
                list.actions.forEach { collectKinds($0, into: &kinds) }
            }
        case .once(let w), .always(let w): collectKinds(w.action, into: &kinds)
        default: break
        }
    }

    /// Top-most Value objects inside a props tree.
    private func valueObjects(in json: JSONValue) -> [JSONValue] {
        switch json {
        case .object(let o):
            if let t = o["type"]?.stringValue, ValueResolver.valueTypes.contains(t) { return [json] }
            return o.values.flatMap(valueObjects)
        case .array(let a):
            return a.flatMap(valueObjects)
        default:
            return []
        }
    }
}
