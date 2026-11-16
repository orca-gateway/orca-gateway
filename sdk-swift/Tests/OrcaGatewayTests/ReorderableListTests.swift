#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

#if canImport(UIKit)
import UIKit
#endif

/// B13.3 on iOS: a ReorderableListView draws its children in order, and a
/// drop runs `onReorder` with `{oldIndex, newIndex}`, `newIndex` Flutter's
/// raw value (layout_builders.dart:707-712). The order is the page's: the
/// list never moves a row itself. `move(from:to:)` is what the List's
/// `onMove` calls; a real finger is the hand check.
@MainActor
final class ReorderableListTests: XCTestCase {
    // MARK: the drop

    func test_B13_3_aMoveRunsOnReorderOnceWithTheRawIndices() async throws {
        for (from, slot) in [(0, 2), (0, 3), (2, 0)] {
            let model = try Self.model()
            await Self.view(model).move(from: IndexSet(integer: from), to: slot)?.value
            XCTAssertEqual(model.store.value("moves"), 1, "\(from) to \(slot)")
            XCTAssertEqual(model.store.value("from"), .int(from), "\(from) to \(slot)")
            XCTAssertEqual(model.store.value("to"), .int(slot), "\(from) to \(slot)")
        }
    }

    func test_B13_3_aMoveThatLeavesTheRowInPlaceRunsNothing() async throws {
        let model = try Self.model()
        for (from, slot) in [(1, 1), (1, 2), (0, 0), (0, 4), (3, 0)] {
            let run = Self.view(model).move(from: IndexSet(integer: from), to: slot)
            XCTAssertNil(run, "\(from) to \(slot) ran an action")
        }
        XCTAssertNil(Self.view(model).move(from: IndexSet(), to: 2))
        XCTAssertEqual(model.store.value("moves"), 0)
        XCTAssertEqual(model.store.value("from"), -1)
    }

    func test_B13_3_theOrderIsNotChangedLocally() async throws {
        let model = try Self.model()
        await Self.view(model).move(from: IndexSet(integer: 0), to: 3)?.value
        XCTAssertEqual(model.store.value("moves"), 1)
        XCTAssertEqual(model.renderer.node("list")?.children, ["a", "b", "c"])
        XCTAssertEqual(model.resolve("list")?.childIds, ["a", "b", "c"])
    }

    func test_B13_3_aListWithoutOnReorderRunsNothing() throws {
        let model = try Self.model(actions: [:])
        XCTAssertNil(Self.view(model).move(from: IndexSet(integer: 0), to: 3))
    }

    #if canImport(UIKit)
    // MARK: drawn

    /// Rows 30, 40 and 50 tall sit one under the other with nothing
    /// between them (no separator, no row inset, no minimum row height);
    /// the padding's top and bottom are in the first and last row.
    func test_B13_3_theRowsAreTheChildrenInOrder() throws {
        let model = try Self.model(props: ["padding": ["top": 8, "right": 16, "bottom": 6, "left": 16]])
        let hosted = Hosted(model)
        defer { hosted.close() }

        let cells = try XCTUnwrap(hosted.rows)
        XCTAssertEqual(cells.map(\.height), [38, 40, 56])
        XCTAssertEqual(cells.map(\.minY), [0, 38, 78])
        XCTAssertEqual(cells.map(\.width), [200, 200, 200])
    }

    /// The rows can be dragged as they are: no edit mode, no handles.
    func test_B13_3_theRowsDragWithoutEditMode() throws {
        let hosted = Hosted(try Self.model())
        defer { hosted.close() }
        let list = try XCTUnwrap(hosted.collectionView)
        XCTAssertFalse(list.isEditing)
        XCTAssertTrue(list.dragInteractionEnabled)
        XCTAssertNotNil(list.dragDelegate)
    }

    func test_B13_3_aDropOnScreenLeavesTheRowsWhereTheyWere() async throws {
        let model = try Self.model()
        let hosted = Hosted(model)
        defer { hosted.close() }
        await Self.view(model).move(from: IndexSet(integer: 0), to: 3)?.value
        hosted.pump(0.3)
        XCTAssertEqual(model.store.value("to"), 3)
        XCTAssertEqual(try XCTUnwrap(hosted.rows).map(\.height), [30, 40, 50])
    }

    /// Horizontal: a scrolling row of all the children, no list.
    func test_B13_3_aHorizontalListDrawsAllChildrenInARow() throws {
        let model = try Self.model(props: ["scrollDirection": "horizontal",
                                           "padding": ["top": 0, "right": 4, "bottom": 0, "left": 6]],
                                   horizontal: true)
        let hosted = Hosted(model)
        defer { hosted.close() }
        XCTAssertNil(hosted.collectionView)
        let scroll = try XCTUnwrap(hosted.scrollView)
        XCTAssertEqual(scroll.contentSize.width, 6 + 90 + 100 + 110 + 4)
    }

    /// Horizontal: the scroll triggers of a SingleChildScrollView.
    func test_B13_3_aHorizontalListRunsTheScrollTriggers() throws {
        let model = try Self.model(
            props: ["scrollDirection": "horizontal"],
            actions: ["onScrollEnd": Self.sequence([Self.count("ends"), Self.write("offset", "offset")])],
            horizontal: true)
        let hosted = Hosted(model)
        defer { hosted.close() }
        let scroll = try XCTUnwrap(hosted.scrollView)
        scroll.setContentOffset(CGPoint(x: 100, y: 0), animated: false)
        hosted.pump(0.5)
        XCTAssertEqual(model.store.value("ends"), 1)
        XCTAssertEqual(model.store.value("offset"), 100)
    }

    /// Vertical, iOS 18 and later: the list's scroll geometry and phase.
    func test_B13_3_aVerticalListRunsTheScrollTriggersOnIOS18() throws {
        guard #available(iOS 18, *) else { throw XCTSkip("the scroll phase is iOS 18") }
        let model = try Self.model(
            actions: ["onScrollEnd": Self.sequence([Self.count("ends"), Self.write("offset", "offset")])],
            heights: [90, 100, 110])
        let hosted = Hosted(model)
        defer { hosted.close() }
        let list = try XCTUnwrap(hosted.collectionView)
        XCTAssertEqual(model.store.value("ends"), 0, "a trigger ran on the first build")
        list.setContentOffset(CGPoint(x: 0, y: 150), animated: false)
        hosted.pump(0.5)
        XCTAssertEqual(model.store.value("ends"), 1)
        XCTAssertEqual(model.store.value("offset"), 150)
    }
    #endif

    // MARK: helpers

    static func view(_ model: OrcaPageModel) -> ReorderableListNodeView {
        ReorderableListNodeView(node: model.resolve("list")!, model: model)
    }

    /// `onReorder` counts in `moves` and writes the event's indices to
    /// `from` and `to`.
    static var onReorder: [String: JSONValue] {
        ["onReorder": sequence([count("moves"), write("from", "oldIndex"), write("to", "newIndex")])]
    }

    static func sequence(_ actions: [JSONValue]) -> JSONValue {
        ["type": "actionGroup", "mode": "sequential", "actions": .array(actions)]
    }

    /// setState `key` to the event's `field`.
    static func write(_ key: String, _ field: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": ["type": "event", "key": .string(field)]]
    }

    /// setState `key` to itself plus 1.
    static func count(_ key: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": [
            "type": "transform", "input": ["type": "state", "key": .string(key), "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]
    }

    /// A ReorderableListView `list` over SizedBoxes `a`, `b`, `c`, 30, 40
    /// and 50 along the list's axis.
    static func model(props: [String: JSONValue] = [:], actions: [String: JSONValue]? = nil,
                      heights: [Double] = [30, 40, 50], horizontal: Bool = false) throws -> OrcaPageModel {
        let rows: [JSONValue] = zip(["a", "b", "c"], horizontal ? [90, 100, 110] : heights).map { id, length in
            let size: [String: JSONValue] = horizontal ? ["width": .double(length), "height": 20]
                : ["width": 20, "height": .double(length)]
            return ["id": .string(id), "type": "SizedBox", "kind": "layout", "childMode": "single",
                    "props": .object(size), "children": [], "watches": []]
        }
        return try OrcaPageModel(page: JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "moves", "scope": "page", "initial": 0], ["key": "ends", "scope": "page", "initial": 0],
                      ["key": "from", "scope": "page", "initial": -1], ["key": "to", "scope": "page", "initial": -1]],
            "components": .array([
                ["id": "list", "type": "ReorderableListView", "kind": "layout", "childMode": "multi",
                 "props": .object(props), "children": ["a", "b", "c"], "watches": [], "actions": .object(actions ?? onReorder)],
            ] + rows),
        ]).decode(PageResponse.self))
    }
}

#if canImport(UIKit)
/// The node `list` drawn 200 by 200 in a UIKit window until `close`.
@MainActor
private final class Hosted {
    private let window: UIWindow

    init(_ model: OrcaPageModel) {
        let frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        let host = UIHostingController(rootView: NodeView(id: "list", model: model)
            .frame(width: 200, height: 200, alignment: .topLeading)
            .ignoresSafeArea())
        window = UIWindow(frame: frame)
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = frame
        host.view.layoutIfNeeded()
        pump(0.3)
    }

    private func find<V: UIView>(_ type: V.Type, in view: UIView) -> V? {
        if let found = view as? V { return found }
        return view.subviews.lazy.compactMap { self.find(type, in: $0) }.first
    }

    /// The UICollectionView SwiftUI draws a List with.
    var collectionView: UICollectionView? { find(UICollectionView.self, in: window) }

    var scrollView: UIScrollView? { find(UIScrollView.self, in: window) }

    /// The rows' frames in the list's content, top to bottom.
    var rows: [CGRect]? {
        guard let list = collectionView else { return nil }
        list.layoutIfNeeded()
        return list.indexPathsForVisibleItems.sorted().compactMap { list.cellForItem(at: $0)?.frame }
    }

    func pump(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }
}
#endif
#endif
