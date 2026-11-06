import Foundation
import XCTest

@testable import OrcaGatewayCore

/// T2.3 and T2.5 on the render tree, the layer the SwiftUI views draw.
final class RenderTreeTests: XCTestCase {
    func counter() throws -> PageResponse {
        try JSONDecoder().decode(PageResponse.self, from: try Fixtures.data("sdk-swift/Tests/Pages/counter-home.json"))
    }

    /// The text of a node: its own `data` (a Text) or the text under it.
    func text(of node: RenderNode) -> String? {
        node.first { $0.type == "Text" }?.props["data"]?.stringValue
    }

    func button(_ label: String, in tree: RenderNode) -> RenderNode? {
        tree.first { $0.type == "ElevatedButton" && text(of: $0) == label }
    }

    // MARK: T4.4 native-widgets page

    /// Every node of the S4 demo page is a widget this build draws, so
    /// nothing degrades to a FallbackPrompt.
    func testTheNativeWidgetsPageDrawsWithoutDegrading() throws {
        let page = try JSONDecoder().decode(
            PageResponse.self, from: try Fixtures.data("sdk-swift/Tests/Pages/native-widgets-home.json"))
        let registry = WidgetRegistry()
        let renderer = PageRenderer(page: page, registry: registry)
        let store = ElmStore()
        store.seed(page.state)
        let tree = try XCTUnwrap(renderer.tree(state: store.state))
        XCTAssertEqual(tree.all.count, page.components.count)
        XCTAssertEqual(tree.all.filter { $0.node.degradedFrom != nil }.map(\.type), [])
        XCTAssertEqual(registry.reportedTypes, [])
        let types = Set(tree.all.map(\.type))
        for added in ["Icon", "Image", "Container", "Expanded", "Spacer", "TextField",
                      "Stack", "Positioned", "ClipRRect", "GestureDetector"] {
            XCTAssertTrue(types.contains(added), "\(added) is not on the page")
        }
        // The favourite icon follows its state: bowl starts on, pizza off.
        let icons = tree.all.filter { $0.type == "Icon" }.compactMap { $0.props["name"]?.stringValue }
        XCTAssertTrue(icons.contains("favorite"))
        XCTAssertTrue(icons.contains("favorite_border"))
    }

    // MARK: T2.3 counter page

    func testCounterPageCountsAndResetsWithASnackbar() throws {
        let page = try counter()
        let renderer = PageRenderer(page: page)
        let store = ElmStore()
        store.seed(page.state)
        let reducer = ActionReducer().reducer

        var tree = try XCTUnwrap(renderer.tree(state: store.state))
        XCTAssertEqual(tree.all.count, 16)
        XCTAssertEqual(tree.type, "Scaffold")
        let appBar = try XCTUnwrap(tree.slots["appBar"])
        XCTAssertEqual(appBar.slots["title"]?.props["data"], "Counter Example")
        let countText = { (t: RenderNode) in t.first { $0.node.watches == ["count"] } }
        XCTAssertEqual(countText(tree)?.props["data"], "0")

        let plus = try XCTUnwrap(button("+", in: tree)?.node.actions["onTap"])
        store.apply(plus, with: reducer)
        store.apply(plus, with: reducer)
        tree = try XCTUnwrap(renderer.tree(state: store.state))
        XCTAssertEqual(countText(tree)?.props["data"], "2")

        let minus = try XCTUnwrap(button("-", in: tree)?.node.actions["onTap"])
        store.apply(minus, with: reducer)
        XCTAssertEqual(store.value("count"), 1)

        let reset = try XCTUnwrap(button("Reset", in: tree)?.node.actions["onTap"])
        let effects = store.apply(reset, with: reducer)
        tree = try XCTUnwrap(renderer.tree(state: store.state))
        XCTAssertEqual(countText(tree)?.props["data"], "0")
        XCTAssertEqual(effects, [ActionEffect("showSnackbar", ["message": "Counter reset to 0", "duration": 4000])])
    }

    func testOnlyTheCountTextWatchesCount() throws {
        let page = try counter()
        let watchers = page.components.filter { $0.watches.contains("count") }.map(\.id)
        XCTAssertEqual(watchers, ["5"])
    }

    func testPropsResolveDeepAndStructureSlotsAreIds() throws {
        let renderer = PageRenderer(page: try counter())
        let state = StoreState(page: ["count": 7])
        let scaffold = try XCTUnwrap(renderer.resolve("0", state: state))
        XCTAssertEqual(scaffold.slots, ["appBar": "1", "body": "3"])
        XCTAssertEqual(scaffold.childIds, [])
        let text = try XCTUnwrap(renderer.resolve("5", state: state))
        XCTAssertEqual(text["data"], "7")
        XCTAssertEqual(text["style"]?["fontSize"], 48)
        let column = try XCTUnwrap(renderer.resolve("4", state: state))
        XCTAssertEqual(column.childIds, ["5", "6", "7", "13", "14"])
    }

    // MARK: T2.5 unknown widget types degrade safely

    func page(_ components: [ComponentNode]) -> PageResponse {
        PageResponse(pageId: "p", title: "P", components: components)
    }

    func testUnknownTypeBecomesAFallbackPromptAndIsReportedOnce() throws {
        var events: [String] = []
        let registry = WidgetRegistry(onUnknownType: { events.append($0) })
        let renderer = PageRenderer(page: page([
            ComponentNode(id: "0", type: "Column", kind: .layout, childMode: .multi, children: ["1", "2", "3"]),
            ComponentNode(id: "1", type: "HoloDeck", kind: .primitive, childMode: .none, props: ["x": 1]),
            ComponentNode(id: "2", type: "HoloDeck", kind: .primitive, childMode: .none),
            ComponentNode(id: "3", type: "Text", kind: .primitive, childMode: .none, props: ["data": "after"]),
        ]), registry: registry)

        let tree = try XCTUnwrap(renderer.tree(state: StoreState()))
        let kinds = tree.children.map(\.type)
        XCTAssertEqual(kinds, ["FallbackPrompt", "FallbackPrompt", "Text"])
        let prompt = tree.children[0].node
        XCTAssertEqual(prompt.degradedFrom, "HoloDeck")
        XCTAssertEqual(prompt["title"], "Unsupported content")
        XCTAssertEqual(prompt["severity"], "warn")
        XCTAssertEqual(prompt["body"]?.stringValue?.contains("\"HoloDeck\""), true)
        XCTAssertEqual(events, ["HoloDeck"])
        XCTAssertEqual(registry.reportedTypes, ["HoloDeck"])
    }

    func testWithoutAFallbackPromptAnUnknownTypeDrawsNothing() throws {
        let registry = WidgetRegistry(types: ["Column"])
        let renderer = PageRenderer(page: page([
            ComponentNode(id: "0", type: "Column", kind: .layout, childMode: .multi, children: ["1"]),
            ComponentNode(id: "1", type: "HoloDeck", kind: .primitive, childMode: .none),
        ]), registry: registry)
        let tree = try XCTUnwrap(renderer.tree(state: StoreState()))
        XCTAssertEqual(tree.children.map(\.type), [WidgetRegistry.emptyType])
    }

    func testMissingChildIdsAndCyclesAreSkipped() throws {
        let renderer = PageRenderer(page: page([
            ComponentNode(id: "0", type: "Column", kind: .layout, childMode: .multi, children: ["9", "1"]),
            ComponentNode(id: "1", type: "Center", kind: .layout, childMode: .single, children: ["0"]),
        ]))
        let tree = try XCTUnwrap(renderer.tree(state: StoreState()))
        XCTAssertEqual(tree.children.map(\.id), ["1"])
        XCTAssertEqual(tree.children[0].children.count, 0)
    }

    func testEmptyPageHasNoTree() {
        XCTAssertNil(PageRenderer(page: page([])).tree(state: StoreState()))
    }
}
