import Foundation
import XCTest

@testable import OrcaGatewayCore

/// C19.1: `ValueResolver.resolveWithTrace` and the traced `widget_rebuild`.
/// The resolver records Flutter's steps (sdk/lib/src/state/value_resolver.dart
/// `resolveWithTrace`), pinned by schema/fixtures/traces, the files Flutter
/// runs in sdk/test/conformance/trace_fixtures_test.dart. The renderer
/// traces a watched node's Value props while DevTools is on and reports
/// them, as Flutter's component_renderer does on every WatchBuilder build.
final class PropTraceTests: XCTestCase {
    let recorder = EventRecorder()

    override func tearDown() {
        OrcaDebug.reporter = nil
        super.tearDown()
    }

    // MARK: resolveWithTrace

    /// Every file in schema/fixtures/traces, the way Flutter's runner reads
    /// it: app state, then page state over it, the optional event, the raw
    /// value; the resolved value and every step equal `expected`. Run twice
    /// on one resolver: a second call starts from an empty trace.
    func testC19_1_everyTraceFixtureResolvesWithItsTrace() throws {
        let files = try Fixtures.files("traces")
        XCTAssertGreaterThanOrEqual(files.count, 4, "\(files.map(\.name))")
        for (name, fixture) in files {
            let resolver = ValueResolver(
                page: fixture["state"]["page"].objectValue ?? [:],
                app: fixture["state"]["app"].objectValue ?? [:],
                eventData: fixture["event"].objectValue)
            let expected = fixture["expected"]
            for run in 1...2 {
                let (value, trace) = resolver.resolveWithTrace(fixture["value"])
                assertJSONEqual(value, expected["value"], "\(name) value, run \(run)")
                assertJSONEqual(.array(trace.map(\.json)), expected["trace"], "\(name) trace, run \(run)")
            }
            assertJSONEqual(resolver.resolveDeep(fixture["value"]), expected["value"], "\(name) untraced")
        }
    }

    // MARK: widget_rebuild

    func counter() throws -> PageResponse {
        try JSONDecoder().decode(PageResponse.self, from: try Fixtures.data("sdk-swift/Tests/Pages/counter-home.json"))
    }

    /// The payload of schema/fixtures/devtools/widget_rebuild-traced.json,
    /// with `count` at `value` (the fixture was built at 1).
    func tracedPayload(count value: Int) throws -> JSONValue {
        let fixture = try Fixtures.json("schema/fixtures/devtools/widget_rebuild-traced.json")
        let text = try wireText(fixture["payload"])
        let at = text.replacingOccurrences(of: "\"1\"", with: "\"\(value)\"")
        return try JSONValue.decode(Data(at.utf8))
    }

    /// The counter page's Text#5 watches `count`, and its `data` is a
    /// transform toString over it, the node of widget_rebuild-traced.json.
    /// Rendering the page reports that payload, from that node only; each
    /// later resolution reports again with the value it read. The props are
    /// the ones an untraced resolution gives.
    func testC19_1_aWatchedNodeReportsItsTracedPropsOnEveryResolution() throws {
        let page = try counter()
        let renderer = PageRenderer(page: page, registry: WidgetRegistry())
        let store = ElmStore()
        store.seed(page.state)
        store.dispatch(["count": 1])
        let untraced = try XCTUnwrap(renderer.resolve("5", state: store.state))
        OrcaDebug.reporter = recorder

        let tree = try XCTUnwrap(renderer.tree(state: store.state))
        XCTAssertEqual(tree.all.count, 16)
        let rebuilds = recorder.of("widget_rebuild")
        XCTAssertEqual(rebuilds.map { JSONValue.object($0.payload) }, [try tracedPayload(count: 1)])
        XCTAssertEqual(tree.first { $0.id == "5" }?.node, untraced)

        store.dispatch(["count": 2])
        let again = try XCTUnwrap(renderer.resolve("5", state: store.state))
        XCTAssertEqual(again["data"], "2")
        XCTAssertEqual(recorder.of("widget_rebuild").map { JSONValue.object($0.payload) },
                       [try tracedPayload(count: 1), try tracedPayload(count: 2)])
    }

    /// DevTools off: the node resolves as it always did and nothing is
    /// reported, now or later.
    func testC19_1_nothingIsReportedWhileDevToolsIsOff() throws {
        let page = try counter()
        let renderer = PageRenderer(page: page, registry: WidgetRegistry())
        let store = ElmStore()
        store.seed(page.state)
        XCTAssertFalse(OrcaDebug.isEnabled)
        let off = try XCTUnwrap(renderer.resolve("5", state: store.state))
        XCTAssertEqual(off["data"], "0")
        OrcaDebug.reporter = recorder
        XCTAssertEqual(recorder.events, [])
        XCTAssertEqual(renderer.resolve("5", state: store.state), off)
        XCTAssertEqual(recorder.of("widget_rebuild").count, 1)
    }

    /// A node without watches is never traced, even with a transform prop;
    /// a watching node whose props trace nothing (plain data, a static
    /// Value, a list) sends nothing either, as Flutter sends only when some
    /// prop traced.
    func testC19_1_noWatchesOrNoTracedPropReportsNothing() throws {
        let count: JSONValue = ["type": "state", "key": "count", "scope": "page"]
        let toText: JSONValue = ["type": "transform", "input": count, "by": [["type": "toString"]]]
        let json: JSONValue = [
            "pageId": "p", "title": "P", "state": [["key": "count", "scope": "page", "initial": 3]],
            "components": [
                ["id": "0", "type": "Column", "kind": "layout", "childMode": "multi",
                 "props": [:], "children": ["1", "2"], "watches": []],
                ["id": "1", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": ["data": toText], "children": [], "watches": []],
                ["id": "2", "type": "Text", "kind": "primitive", "childMode": "none",
                 "props": [
                    "data": ["type": "static", "value": "fixed"],
                    "style": ["fontSize": 12],
                    "items": [count],
                 ],
                 "children": [], "watches": ["count"]],
            ],
        ]
        let page = try json.decode(PageResponse.self)
        let renderer = PageRenderer(page: page, registry: WidgetRegistry())
        let store = ElmStore()
        store.seed(page.state)
        OrcaDebug.reporter = recorder
        let tree = try XCTUnwrap(renderer.tree(state: store.state))
        XCTAssertEqual(tree.first { $0.id == "1" }?.props["data"], "3")
        XCTAssertEqual(tree.first { $0.id == "2" }?.props["items"], [3])
        XCTAssertEqual(recorder.of("widget_rebuild"), [])
    }
}
