import XCTest

@testable import OrcaGatewayCore

/// B13.3: where a dragged row is dropped becomes Flutter's raw `newIndex`,
/// the insertion index before the row is removed
/// (`ReorderableListView.onReorder`), or nothing when the row did not move.
/// The Kotlin twin pins the same table.
final class ReorderDropTests: XCTestCase {
    func test_B13_3_aDropSlotIsFluttersRawNewIndex() {
        XCTAssertEqual(ReorderDrop.newIndex(from: 0, slot: 2, count: 3), 2, "item 0 below item 1")
        XCTAssertEqual(ReorderDrop.newIndex(from: 0, slot: 3, count: 3), 3, "item 0 at the end")
        XCTAssertEqual(ReorderDrop.newIndex(from: 2, slot: 0, count: 3), 0, "last to top")
    }

    func test_B13_3_aDropThatLeavesTheRowInPlaceIsNothing() {
        XCTAssertNil(ReorderDrop.newIndex(from: 1, slot: 1, count: 3), "above itself")
        XCTAssertNil(ReorderDrop.newIndex(from: 1, slot: 2, count: 3), "below itself")
        XCTAssertNil(ReorderDrop.newIndex(from: 0, slot: 0, count: 3))
    }

    func test_B13_3_outOfRangeAndShortListsAreNothing() {
        XCTAssertNil(ReorderDrop.newIndex(from: -1, slot: 2, count: 3))
        XCTAssertNil(ReorderDrop.newIndex(from: 3, slot: 0, count: 3))
        XCTAssertNil(ReorderDrop.newIndex(from: 0, slot: -1, count: 3))
        XCTAssertNil(ReorderDrop.newIndex(from: 0, slot: 4, count: 3))
        XCTAssertNil(ReorderDrop.newIndex(from: 0, slot: 0, count: 0))
        XCTAssertNil(ReorderDrop.newIndex(from: 0, slot: 1, count: 1))
        XCTAssertNil(ReorderDrop.newIndex(from: 0, slot: 0, count: 1))
    }

    func test_B13_3_theEventCarriesOldIndexAndNewIndex() {
        XCTAssertEqual(ReorderDrop.event(from: 0, slot: 3, count: 3), ["oldIndex": .int(0), "newIndex": .int(3)])
        XCTAssertEqual(ReorderDrop.event(from: 2, slot: 0, count: 3), ["oldIndex": .int(2), "newIndex": .int(0)])
        XCTAssertNil(ReorderDrop.event(from: 1, slot: 2, count: 3))
        XCTAssertNil(ReorderDrop.event(from: 5, slot: 0, count: 3))
    }
}
