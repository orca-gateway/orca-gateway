import Foundation
import XCTest

@testable import OrcaGatewayCore

/// C15.6: the telemetry sink receives unknown_widget_type, once per type per
/// process, whatever registry drew it. Ports sdk/test/safe_degrade_test.dart
/// at the render-tree level. The sink and the seen set are process-wide, so
/// every test starts and ends with both cleared.
final class OrcaTelemetryTests: XCTestCase {
    struct Event: Equatable {
        var name: String
        var data: [String: JSONValue]
    }

    var events: [Event] = []

    override func setUp() {
        super.setUp()
        OrcaTelemetry.resetForTesting()
        OrcaTelemetry.onEvent = nil
        events = []
    }

    override func tearDown() {
        OrcaTelemetry.resetForTesting()
        OrcaTelemetry.onEvent = nil
        super.tearDown()
    }

    func listen() {
        OrcaTelemetry.onEvent = { [unowned self] name, data in
            self.events.append(Event(name: name, data: data))
        }
    }

    func page(_ unknown: String) -> PageResponse {
        PageResponse(pageId: "p", title: "P", components: [
            ComponentNode(id: "0", type: "Column", kind: .layout, childMode: .multi, children: ["1", "2", "3"]),
            ComponentNode(id: "1", type: unknown, kind: .primitive, childMode: .none),
            ComponentNode(id: "2", type: unknown, kind: .primitive, childMode: .none),
            ComponentNode(id: "3", type: "Text", kind: .primitive, childMode: .none, props: ["data": "after"]),
        ])
    }

    func render(_ page: PageResponse, with registry: WidgetRegistry) throws {
        let tree = try XCTUnwrap(PageRenderer(page: page, registry: registry).tree(state: StoreState()))
        XCTAssertEqual(tree.children.map(\.type), ["FallbackPrompt", "FallbackPrompt", "Text"])
    }

    func reported(_ type: String) -> Event {
        Event(name: "unknown_widget_type", data: ["type": .string(type)])
    }

    func testC15_6_anUnknownTypeReachesTheSinkOncePerProcess() throws {
        listen()
        let registry = WidgetRegistry()
        try render(page("HoloDeck"), with: registry)
        XCTAssertEqual(events, [reported("HoloDeck")])

        try render(page("HoloDeck"), with: registry)
        try render(page("HoloDeck"), with: WidgetRegistry())
        XCTAssertEqual(events, [reported("HoloDeck")], "a second render or registry reports nothing more")

        try render(page("WarpCore"), with: WidgetRegistry())
        XCTAssertEqual(events, [reported("HoloDeck"), reported("WarpCore")])
    }

    func testC15_6_theRegistryCallbackStillFiresPerRegistry() throws {
        listen()
        var first: [String] = []
        var second: [String] = []
        try render(page("HoloDeck"), with: WidgetRegistry(onUnknownType: { first.append($0) }))
        try render(page("HoloDeck"), with: WidgetRegistry(onUnknownType: { second.append($0) }))
        XCTAssertEqual(first, ["HoloDeck"])
        XCTAssertEqual(second, ["HoloDeck"])
        XCTAssertEqual(events, [reported("HoloDeck")])
    }

    func testC15_6_dedupRunsWithNoSink() throws {
        try render(page("HoloDeck"), with: WidgetRegistry())
        listen()
        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        try render(page("HoloDeck"), with: WidgetRegistry())
        XCTAssertEqual(events, [], "seen while no sink was set, so never reported")
    }

    func testC15_6_resetForTestingLetsTheTypeReportAgain() {
        listen()
        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        XCTAssertEqual(events, [reported("HoloDeck")])

        OrcaTelemetry.resetForTesting()
        OrcaTelemetry.reportUnknownWidgetOnce("HoloDeck")
        XCTAssertEqual(events, [reported("HoloDeck"), reported("HoloDeck")])
    }
}
