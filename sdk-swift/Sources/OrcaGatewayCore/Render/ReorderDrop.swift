import Foundation

/// Where a dragged row of a reorderable list is dropped, as Flutter's
/// `ReorderableListView.onReorder` reports it (layout_builders.dart:707-712).
///
/// A list of `count` rows has `count + 1` drop slots: slot `i` is the gap
/// above row `i`, slot `count` the end. The slot is Flutter's raw
/// `newIndex`: the insertion index counted before the dragged row is
/// removed. Row 0 of three dropped at the end gives 3, below row 1 gives 2,
/// the last row dropped at the top gives 0.
public enum ReorderDrop {
    /// The raw `newIndex` of row `from` dropped in `slot`; nil when the row
    /// stays where it was (the slot above or below itself), when `from` or
    /// `slot` is out of range, and when the list has fewer than two rows.
    public static func newIndex(from: Int, slot: Int, count: Int) -> Int? {
        guard count > 1, (0..<count).contains(from), (0...count).contains(slot),
              slot != from, slot != from + 1 else { return nil }
        return slot
    }

    /// What `onReorder` fires with, read by `V.event`: `{oldIndex, newIndex}`;
    /// nil when `newIndex(from:slot:count:)` is.
    public static func event(from: Int, slot: Int, count: Int) -> [String: JSONValue]? {
        newIndex(from: from, slot: slot, count: count).map { ["oldIndex": .int(from), "newIndex": .int($0)] }
    }
}
