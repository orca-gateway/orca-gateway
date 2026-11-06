import Foundation
import XCTest

@testable import OrcaGatewayCore

/// The four structural changes on a page's node map, against the Flutter
/// `ComponentStore` behaviour they port.
final class ComponentMutationTests: XCTestCase {
    private func node(_ id: String, _ type: String = "Text", children: [String] = [],
                      props: [String: JSONValue] = [:]) -> ComponentNode {
        ComponentNode(id: id, type: type, kind: children.isEmpty ? .primitive : .layout,
                      childMode: children.isEmpty ? .none : .multi, props: props, children: children)
    }

    /// root (Column) → list (Column) → [a, b]
    private func renderer() -> PageRenderer {
        PageRenderer(page: PageResponse(pageId: "shop", title: "Shop", components: [
            node("root", "Column", children: ["list"]),
            node("list", "Column", children: ["a", "b"]),
            node("a", props: ["data": "A"]),
            node("b", props: ["data": "B"]),
        ]))
    }

    private func texts(_ r: PageRenderer, under id: String = "list") -> [String] {
        r.tree(state: StoreState(), from: id)?.children.compactMap { $0.props["data"]?.stringValue } ?? []
    }

    func testUpdateMergesProps() {
        var r = renderer()
        r.apply(.update(id: "a", props: ["data": "A2", "style": ["fontSize": 12]]))
        XCTAssertEqual(r.nodes["a"]?.props, ["data": "A2", "style": ["fontSize": 12]])
        r.apply(.update(id: "nope", props: ["x": 1]))
        XCTAssertNil(r.nodes["nope"])
    }

    func testDeleteRemovesTheSubtreeAndTheParentLink() {
        var r = renderer()
        r.apply(.delete(id: "list"))
        XCTAssertEqual(r.nodes["root"]?.children, [])
        XCTAssertNil(r.nodes["list"])
        XCTAssertNil(r.nodes["a"])
        XCTAssertNil(r.nodes["b"])
    }

    func testAddInsertsAtAPositionOrAppends() {
        var r = renderer()
        r.apply(.add(parentId: "list", components: [node("c", props: ["data": "C"])], position: 0))
        r.apply(.add(parentId: "list", components: [node("d", props: ["data": "D"])], position: 99))
        r.apply(.add(parentId: "list", components: [node("e", props: ["data": "E"])], position: nil))
        XCTAssertEqual(texts(r), ["C", "A", "B", "D", "E"])
    }

    func testAddWithASubtreeKeepsItsChildren() {
        var r = renderer()
        r.apply(.add(parentId: "list", components: [
            node("row", "Row", children: ["row-t"]), node("row-t", props: ["data": "inner"]),
        ], position: nil))
        let row = r.tree(state: StoreState(), from: "row")
        XCTAssertEqual(row?.children.first?.props["data"], "inner")
    }

    func testAddToAMissingParentOrWithNothingChangesNothing() {
        var r = renderer()
        let before = r.nodes
        r.apply(.add(parentId: "ghost", components: [node("c")], position: nil))
        r.apply(.add(parentId: "list", components: [], position: nil))
        XCTAssertEqual(r.nodes, before)
    }

    func testReplaceSwapsInPlace() {
        var r = renderer()
        r.apply(.replace(targetId: "a", components: [node("z", props: ["data": "Z"])]))
        XCTAssertEqual(texts(r), ["Z", "B"])
        XCTAssertNil(r.nodes["a"])
    }

    func testReplaceASubtreeDropsTheOldChildren() {
        var r = renderer()
        r.apply(.replace(targetId: "list", components: [
            node("list2", "Column", children: ["q"]), node("q", props: ["data": "Q"]),
        ]))
        XCTAssertEqual(r.nodes["root"]?.children, ["list2"])
        XCTAssertNil(r.nodes["a"])
        XCTAssertEqual(texts(r, under: "list2"), ["Q"])
    }

    func testReplacingTheRootLeavesNothingToDraw() {
        var r = renderer()
        r.apply(.replace(targetId: "root", components: [node("x")]))
        XCTAssertNil(r.tree(state: StoreState()))
    }
}
