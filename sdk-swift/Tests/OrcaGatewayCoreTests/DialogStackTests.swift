import XCTest

@testable import OrcaGatewayCore

/// A8.1 (Swift core): the sheets openDialog opens and closeDialog closes, as
/// Flutter's handlers (sdk/lib/src/widgets/orca_page.dart:323-374,
/// sdk/lib/src/state/action_executor.dart:894-919). The sheet's content is
/// the Dialog's children subtree, depth-first; Flutter's ComponentRenderer
/// draws the list from its first node (component_renderer.dart:44-54), the
/// Dialog's first child, so a second child is in the list but never drawn.
/// The same cases as Kotlin's DialogStackTest.
final class DialogStackTests: XCTestCase {
    private func node(_ id: String, _ type: String = "Column", _ children: [String] = []) -> ComponentNode {
        ComponentNode(id: id, type: type, kind: .layout, childMode: children.isEmpty ? .none : .multi,
                      children: children)
    }

    /// A page: Dialog `d` with children `a` (a Column of `a1` > `a1x`, and
    /// `a2`) and `b` (`b1`); an empty Dialog `e`; a Dialog `g` whose only
    /// child is not on the page.
    private var page: [String: ComponentNode] {
        let nodes = [
            node("root", "Column", ["d", "e", "g"]),
            node("d", "Dialog", ["a", "b"]),
            node("a", "Column", ["a1", "a2"]),
            node("a1", "Row", ["a1x"]),
            node("a1x", "Text"),
            node("a2", "Text"),
            node("b", "Column", ["b1"]),
            node("b1", "Text"),
            node("e", "Dialog"),
            node("g", "Dialog", ["ghost"]),
        ]
        return Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }

    /// A8.1: open puts one sheet on the stack holding the Dialog's children
    /// and all below them, depth-first in order (a missing child skipped, as
    /// Flutter's `collect`); its first node, the Dialog's first child, is the
    /// root the sheet draws, and the second child `b` comes after `a`'s
    /// subtree but nothing draws it.
    func testA8_1_OpenResolvesTheDialogsFirstChildAsTheSheetRootWithItsSubtreeDepthFirst() throws {
        var stack = DialogStack()
        let sheet = try XCTUnwrap(stack.open(dialogId: "d", heightFactor: 0.4, nodes: page))
        XCTAssertEqual(sheet.nodes.map(\.id), ["a", "a1", "a1x", "a2", "b", "b1"])
        XCTAssertEqual(sheet.rootId, "a")
        XCTAssertEqual(sheet.dialogId, "d")
        XCTAssertEqual(sheet.heightFactor, 0.4)
        XCTAssertEqual(sheet.nodes.first, page["a"])
        XCTAssertEqual(stack.sheets, [sheet])
        XCTAssertEqual(stack.top, sheet)

        var withGhost = page
        withGhost["d"] = node("d", "Dialog", ["ghost", "b"])
        var other = DialogStack()
        let skipped = try XCTUnwrap(other.open(dialogId: "d", heightFactor: nil, nodes: withGhost))
        XCTAssertEqual(skipped.nodes.map(\.id), ["b", "b1"])
        XCTAssertEqual(skipped.rootId, "b")
    }

    /// A8.1: an id the page lacks, a Dialog with no children, or one whose
    /// children are all missing opens nothing (orca_page.dart:329, :344).
    func testA8_1_AnUnknownIdOrNoChildrenOpensNothing() throws {
        var stack = DialogStack()
        XCTAssertNil(stack.open(dialogId: "nope", heightFactor: 0.5, nodes: page))
        XCTAssertNil(stack.open(dialogId: "e", heightFactor: 0.5, nodes: page))
        XCTAssertNil(stack.open(dialogId: "g", heightFactor: 0.5, nodes: page))
        XCTAssertNil(stack.open(dialogId: "d", heightFactor: 0.5, nodes: [:]))
        XCTAssertEqual(stack.sheets, [])
        XCTAssertNil(stack.top)

        // None of them left a sheet behind: the next real one is the only one.
        let sheet = try XCTUnwrap(stack.open(dialogId: "d", heightFactor: 0.5, nodes: page))
        XCTAssertEqual(stack.sheets, [sheet])
    }

    /// A8.1: no heightFactor is 0.5 (orca_page.dart:326); NaN or a negative
    /// one is 0.5 too; 0 and the rest stay as given.
    func testA8_1_HeightFactorDefaultsToHalfAndNaNOrNegativeIsHalf() throws {
        XCTAssertEqual(DialogStack.heightFactor(nil), 0.5)
        XCTAssertEqual(DialogStack.heightFactor(.nan), 0.5)
        XCTAssertEqual(DialogStack.heightFactor(-0.2), 0.5)
        XCTAssertEqual(DialogStack.heightFactor(0), 0)
        XCTAssertEqual(DialogStack.heightFactor(0.3), 0.3)
        XCTAssertEqual(DialogStack.heightFactor(1), 1)

        var stack = DialogStack()
        XCTAssertEqual(try XCTUnwrap(stack.open(dialogId: "d", heightFactor: nil, nodes: page)).heightFactor, 0.5)
        XCTAssertEqual(try XCTUnwrap(stack.open(dialogId: "d", heightFactor: .nan, nodes: page)).heightFactor, 0.5)
        XCTAssertEqual(try XCTUnwrap(stack.open(dialogId: "d", heightFactor: -1, nodes: page)).heightFactor, 0.5)
        XCTAssertEqual(try XCTUnwrap(stack.open(dialogId: "d", heightFactor: 0.3, nodes: page)).heightFactor, 0.3)
    }

    /// A8.1: closeDialog takes the top sheet away and gives it back; with no
    /// sheet open it does nothing, never a page (action_executor.dart
    /// :903-912).
    func testA8_1_ClosePopsTheTopSheetAndNoneOpenIsANoOp() throws {
        var stack = DialogStack()
        XCTAssertNil(stack.close())
        XCTAssertEqual(stack.sheets, [])

        let sheet = try XCTUnwrap(stack.open(dialogId: "d", heightFactor: nil, nodes: page))
        XCTAssertEqual(stack.close(), sheet)
        XCTAssertEqual(stack.sheets, [])
        XCTAssertNil(stack.close())
        XCTAssertEqual(stack.sheets, [])
    }

    /// A8.1: a barrier tap, a drag down or Back takes the top sheet away,
    /// whatever the Dialog's `dismissible` says (Flutter never reads it).
    func testA8_1_ADismissPopsTheTopSheet() throws {
        var pageWithProps = page
        pageWithProps["d"]?.props = ["dismissible": false]
        var stack = DialogStack()
        let first = try XCTUnwrap(stack.open(dialogId: "d", heightFactor: 0.5, nodes: pageWithProps))
        let second = try XCTUnwrap(stack.open(dialogId: "d", heightFactor: 0.3, nodes: pageWithProps))
        XCTAssertEqual(stack.dismiss(), second)
        XCTAssertEqual(stack.sheets, [first])
        XCTAssertEqual(stack.dismiss(), first)
        XCTAssertEqual(stack.sheets, [])
        XCTAssertNil(stack.dismiss())
    }

    /// A8.1: sheets stack in the order they open, the same Dialog twice
    /// being two sheets, and each close takes one, the newest first
    /// (progress_and_dialog_fixes_test.dart:76-140).
    func testA8_1_StackedSheetsCloseOnePerCall() throws {
        var stack = DialogStack()
        let one = try XCTUnwrap(stack.open(dialogId: "d", heightFactor: 0.5, nodes: page))
        let two = try XCTUnwrap(stack.open(dialogId: "d", heightFactor: 0.5, nodes: page))
        var withB = page
        withB["f"] = node("f", "Dialog", ["b"])
        let three = try XCTUnwrap(stack.open(dialogId: "f", heightFactor: 0.2, nodes: withB))
        XCTAssertNotEqual(one, two)
        XCTAssertEqual(stack.sheets, [one, two, three])
        XCTAssertEqual(stack.top, three)

        XCTAssertEqual(stack.close(), three)
        XCTAssertEqual(stack.sheets, [one, two])
        XCTAssertEqual(stack.close(), two)
        XCTAssertEqual(stack.sheets, [one])
        XCTAssertEqual(stack.top, one)
        XCTAssertEqual(stack.close(), one)
        XCTAssertNil(stack.close())
    }
}
