import XCTest

@testable import OrcaGatewayCore

/// B13.1 and B13.2, the core half of CustomScrollView and its slivers
/// (design brief native-parity-s13-slivers, V1 and V3).
///
/// C-items-S: `SliverItems` flattens a CustomScrollView's direct children
/// into the lazy items of one scroll view, as Flutter's builders lay them
/// out (structure_builders.dart `_buildCustomScrollView`, `_buildSliverList`,
/// `_buildSliverGrid`, `_buildSliverToBoxAdapter`, `_buildSliverAppBar`).
///
/// C-geo-S: `SliverAppBarGeometry` against the table `barCases` of the
/// Flutter widget test sdk/test/sliver_widgets_test.dart, row for row and
/// in its order: the numbers Flutter's SliverAppBar measures in an 800 x 600
/// viewport with a 56 toolbar. A row is (offset, paint, layout, box,
/// opacity); `rel` is the reading after the finger is lifted. The same
/// cases as Kotlin's SliverCoreTest.
final class SliverCoreTests: XCTestCase {
    // ── C-items-S ───────────────────────────────────────────────────────────

    private func node(_ id: String, _ type: String, _ childIds: [String] = [],
                      props: [String: JSONValue] = [:]) -> ResolvedNode {
        ResolvedNode(id: id, type: type, kind: .layout, props: props, childIds: childIds, slots: [:],
                     actions: [:], watches: [], degradedFrom: nil)
    }

    /// C-items-S: a SliverList gives one box per child, in order.
    func testCItemsSAListGivesOneBoxPerChild() {
        let items = SliverItems([node("list", "SliverList", ["a", "b", "c"])])
        XCTAssertEqual(items.items, [.box("a"), .box("b"), .box("c")])
        XCTAssertNil(items.collapsingBarId)
        XCTAssertEqual(SliverItems([node("list", "SliverList")]).items, [])
    }

    /// C-items-S: a SliverGrid gives one item per line of up to
    /// crossAxisCount cells: 5 cells at 2 across are 3 lines, the last with
    /// one cell, and only the last line is marked so (no spacing after it).
    func testCItemsSAGridGivesOneItemPerLine() {
        let cells = ["c0", "c1", "c2", "c3", "c4"]
        let items = SliverItems([node("grid", "SliverGrid", cells, props: ["crossAxisCount": .int(2)])])
        XCTAssertEqual(items.items, [
            .gridLine(grid: "grid", line: 0, cells: ["c0", "c1"], isLast: false),
            .gridLine(grid: "grid", line: 1, cells: ["c2", "c3"], isLast: false),
            .gridLine(grid: "grid", line: 2, cells: ["c4"], isLast: true),
        ])
        let three = SliverItems([node("grid", "SliverGrid", cells, props: ["crossAxisCount": .int(3)])])
        XCTAssertEqual(three.items, [
            .gridLine(grid: "grid", line: 0, cells: ["c0", "c1", "c2"], isLast: false),
            .gridLine(grid: "grid", line: 1, cells: ["c3", "c4"], isLast: true),
        ])
        XCTAssertEqual(SliverItems([node("grid", "SliverGrid", [], props: ["crossAxisCount": .int(2)])]).items, [])
    }

    /// C-items-S: crossAxisCount absent is 2; below 1 is 1, as GridCells.
    func testCItemsSCrossAxisCountAbsentIsTwoAndBelowOneIsOne() {
        let absent = SliverItems([node("grid", "SliverGrid", ["c0", "c1", "c2"])])
        XCTAssertEqual(absent.items, [
            .gridLine(grid: "grid", line: 0, cells: ["c0", "c1"], isLast: false),
            .gridLine(grid: "grid", line: 1, cells: ["c2"], isLast: true),
        ])
        for count in [0, -3] {
            let one = SliverItems([node("grid", "SliverGrid", ["c0", "c1"], props: ["crossAxisCount": .int(count)])])
            XCTAssertEqual(one.items, [
                .gridLine(grid: "grid", line: 0, cells: ["c0"], isLast: false),
                .gridLine(grid: "grid", line: 1, cells: ["c1"], isLast: true),
            ], "crossAxisCount \(count)")
        }
    }

    /// C-items-S: a SliverToBoxAdapter gives its child as a box (its first,
    /// should it carry more); without a child it gives nothing.
    func testCItemsSAnAdapterGivesItsChildOrNothing() {
        let items = SliverItems([
            node("empty", "SliverToBoxAdapter"),
            node("adapter", "SliverToBoxAdapter", ["first"]),
            node("two", "SliverToBoxAdapter", ["x", "y"]),
        ])
        XCTAssertEqual(items.items, [.box("first"), .box("x")])
    }

    /// C-items-S: a SliverAppBar that is the first direct child is the bar
    /// item and the collapsing bar.
    func testCItemsSABarFirstIsTheCollapsingBar() {
        let items = SliverItems([
            node("bar", "SliverAppBar", ["bar_title"]),
            node("adapter", "SliverToBoxAdapter", ["first"]),
        ])
        XCTAssertEqual(items.items, [.bar("bar"), .box("first")])
        XCTAssertEqual(items.collapsingBarId, "bar")
    }

    /// C-items-S: a SliverAppBar anywhere else is still a bar item, but no
    /// bar collapses (the UI draws it as a box that scrolls away); a second
    /// bar after a first one does not replace it.
    func testCItemsSABarNotFirstDoesNotCollapse() {
        let items = SliverItems([
            node("empty", "SliverToBoxAdapter"),
            node("bar", "SliverAppBar"),
        ])
        XCTAssertEqual(items.items, [.bar("bar")])
        XCTAssertNil(items.collapsingBarId)

        let two = SliverItems([node("bar1", "SliverAppBar"), node("bar2", "SliverAppBar")])
        XCTAssertEqual(two.items, [.bar("bar1"), .bar("bar2")])
        XCTAssertEqual(two.collapsingBarId, "bar1")
        XCTAssertNil(SliverItems([]).collapsingBarId)
    }

    /// C-items-S: any other widget as a direct child is drawn as a box of
    /// its own (Flutter throws).
    func testCItemsSAStrayWidgetIsABoxOfItsOwn() {
        let items = SliverItems([
            node("text", "Text"),
            node("column", "Column", ["x", "y"]),
        ])
        XCTAssertEqual(items.items, [.box("text"), .box("column")])
    }

    /// C-items-S: every item has a key, the node's id or the grid's id and
    /// the line; keys are unique and the same on a second flattening, and a
    /// line keeps its key when cells are added after it.
    func testCItemsSKeysAreStable() {
        func page(_ cells: [String]) -> [ResolvedNode] {
            [
                node("bar", "SliverAppBar"),
                node("adapter", "SliverToBoxAdapter", ["first"]),
                node("grid", "SliverGrid", cells, props: ["crossAxisCount": .int(2)]),
                node("list", "SliverList", ["r0", "r1"]),
                node("stray", "Text"),
            ]
        }
        let keys = SliverItems(page(["c0", "c1", "c2"])).items.map(\.key)
        XCTAssertEqual(keys, ["bar", "first", "grid#0", "grid#1", "r0", "r1", "stray"])
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(SliverItems(page(["c0", "c1", "c2"])).items.map(\.key), keys)
        XCTAssertEqual(SliverItems(page(["c0", "c1", "c2", "c3", "c4"])).items.map(\.key),
                       ["bar", "first", "grid#0", "grid#1", "grid#2", "r0", "r1", "stray"])
        XCTAssertEqual(SliverItems(page(["c0"])).items.map(\.id), ["bar", "first", "grid#0", "r0", "r1", "stray"])
    }

    /// C-items-S: the grid's crossAxisCount is read from its props as Dart's
    /// `toInt()` (a whole number sent as a double too).
    func testCItemsSCrossAxisCountAsADouble() {
        let items = SliverItems([
            node("bar", "SliverAppBar"),
            node("grid", "SliverGrid", ["c0", "c1", "c2", "c3"], props: ["crossAxisCount": .double(3)]),
            node("plain", "SliverGrid", ["d0", "d1", "d2"]),
            node("list", "SliverList", ["r0"]),
        ])
        XCTAssertEqual(items.items, [
            .bar("bar"),
            .gridLine(grid: "grid", line: 0, cells: ["c0", "c1", "c2"], isLast: false),
            .gridLine(grid: "grid", line: 1, cells: ["c3"], isLast: true),
            .gridLine(grid: "plain", line: 0, cells: ["d0", "d1"], isLast: false),
            .gridLine(grid: "plain", line: 1, cells: ["d2"], isLast: true),
            .box("r0"),
        ])
        XCTAssertEqual(items.collapsingBarId, "bar")
    }

    // ── C-geo-S ─────────────────────────────────────────────────────────────

    /// One row of Flutter's table: `_At(offset, paint, layout, box, opacity)`.
    private struct At {
        var offset: Double
        var paint: Double
        var layout: Double
        var box: Double
        var opacity: Double
        var released = false
    }

    private func at(_ offset: Double, _ paint: Double, _ layout: Double, _ box: Double, _ opacity: Double) -> At {
        At(offset: offset, paint: paint, layout: layout, box: box, opacity: opacity)
    }

    /// `_At.released`: the reading after the finger is lifted, the offset unchanged.
    private func rel(_ offset: Double, _ paint: Double, _ layout: Double, _ box: Double, _ opacity: Double) -> At {
        At(offset: offset, paint: paint, layout: layout, box: box, opacity: opacity, released: true)
    }

    /// Runs one `_BarCase`: its rows in order on one bar.
    private func run(_ name: String, pinned: Bool = false, floating: Bool = false, snap: Bool = false,
                     expandedHeight: Double? = nil, collapsedHeight: Double? = nil, topPadding: Double = 0,
                     rows: [At], file: StaticString = #filePath, line: UInt = #line) {
        var bar = SliverAppBarGeometry(pinned: pinned, floating: floating, snap: snap,
                                       expandedHeight: expandedHeight, collapsedHeight: collapsedHeight,
                                       topPadding: topPadding)
        for (index, row) in rows.enumerated() {
            let frame = row.released ? bar.released() : bar.scrolled(to: row.offset)
            let label = "\(name), row \(index) (\(row.released ? "released at" : "at") \(row.offset))"
            XCTAssertEqual(bar.offset, row.offset, accuracy: 0.0001, "\(label) offset", file: file, line: line)
            XCTAssertEqual(frame.paint, row.paint, accuracy: 0.0001, "\(label) paint", file: file, line: line)
            XCTAssertEqual(frame.layout, row.layout, accuracy: 0.0001, "\(label) layout", file: file, line: line)
            XCTAssertEqual(frame.box, row.box, accuracy: 0.0001, "\(label) box", file: file, line: line)
            XCTAssertEqual(frame.toolbarOpacity, row.opacity, accuracy: 0.0001, "\(label) opacity",
                           file: file, line: line)
            XCTAssertEqual(bar.frame, frame, "\(label) frame", file: file, line: line)
        }
    }

    /// C-geo-S: expandedHeight 200, the four variants.
    func testCGeoSExpanded200() {
        run("neither, expanded 200", expandedHeight: 200, rows: [
            at(0, 200, 200, 200, 1),
            at(100, 100, 100, 100, 1),
            at(600, 0, 0, 56, 0),
            at(580, 0, 0, 56, 0),
        ])
        run("pinned, expanded 200", pinned: true, expandedHeight: 200, rows: [
            at(0, 200, 200, 200, 1),
            at(100, 100, 100, 100, 1),
            at(600, 56, 0, 56, 1),
            at(580, 56, 0, 56, 1),
        ])
        run("floating, expanded 200", floating: true, expandedHeight: 200, rows: [
            at(0, 200, 200, 200, 1),
            at(100, 100, 100, 100, 1),
            at(600, 0, 0, 56, 0),
            at(580, 20, 0, 56, 0.3571),
            at(500, 100, 0, 100, 1),
            at(520, 80, 0, 80, 1),
            rel(520, 80, 0, 80, 1),
        ])
        run("floating + pinned, expanded 200", pinned: true, floating: true, expandedHeight: 200, rows: [
            at(0, 200, 200, 200, 1),
            at(100, 100, 100, 100, 1),
            at(600, 56, 0, 56, 1),
            at(580, 56, 0, 56, 1),
            at(500, 100, 0, 100, 1),
            at(520, 80, 0, 80, 1),
        ])
    }

    /// C-geo-S: no expandedHeight, the bar is the toolbar (56).
    func testCGeoSNoExpandedHeight() {
        run("neither, no expanded", rows: [
            at(0, 56, 56, 56, 1),
            at(30, 26, 26, 56, 0.4643),
            at(600, 0, 0, 56, 0),
            at(580, 0, 0, 56, 0),
        ])
        run("pinned, no expanded", pinned: true, rows: [
            at(0, 56, 56, 56, 1),
            at(30, 56, 26, 56, 1),
            at(600, 56, 0, 56, 1),
            at(580, 56, 0, 56, 1),
        ])
        run("floating, no expanded", floating: true, rows: [
            at(0, 56, 56, 56, 1),
            at(30, 26, 26, 56, 0.4643),
            at(600, 0, 0, 56, 0),
            at(580, 20, 0, 56, 0.3571),
            at(500, 56, 0, 56, 1),
            at(520, 36, 0, 56, 0.6429),
        ])
        run("floating + pinned, no expanded", pinned: true, floating: true, rows: [
            at(0, 56, 56, 56, 1),
            at(30, 56, 26, 56, 1),
            at(600, 56, 0, 56, 1),
            at(580, 56, 0, 56, 1),
        ])
    }

    /// C-geo-S: collapsedHeight 80.
    func testCGeoSCollapsedHeight80() {
        run("neither, expanded 200, collapsed 80", expandedHeight: 200, collapsedHeight: 80, rows: [
            at(0, 200, 200, 200, 1),
            at(100, 100, 100, 100, 1),
            at(150, 50, 50, 80, 0.4643),
            at(600, 0, 0, 80, 0),
        ])
        run("pinned, expanded 200, collapsed 80", pinned: true, expandedHeight: 200, collapsedHeight: 80, rows: [
            at(0, 200, 200, 200, 1),
            at(100, 100, 100, 100, 1),
            at(150, 80, 50, 80, 1),
            at(600, 80, 0, 80, 1),
        ])
        run("floating + pinned, expanded 200, collapsed 80", pinned: true, floating: true,
            expandedHeight: 200, collapsedHeight: 80, rows: [
            at(0, 200, 200, 200, 1),
            at(600, 80, 0, 80, 1),
            at(580, 80, 0, 80, 1),
            at(500, 100, 0, 100, 1),
        ])
        run("pinned, no expanded, collapsed 80", pinned: true, collapsedHeight: 80, rows: [
            at(0, 80, 80, 80, 1),
            at(600, 80, 0, 80, 1),
        ])
        run("neither, no expanded, collapsed 80", collapsedHeight: 80, rows: [
            at(0, 80, 80, 80, 1),
            at(30, 50, 50, 80, 0.4643),
            at(600, 0, 0, 80, 0),
        ])
    }

    /// C-geo-S: snap (floating + snap), the bar settles when the scroll
    /// ends: fully open after a scroll back, fully closed after a scroll on.
    func testCGeoSSnap() {
        run("floating + snap, expanded 200", floating: true, snap: true, expandedHeight: 200, rows: [
            at(0, 200, 200, 200, 1),
            at(600, 0, 0, 56, 0),
            at(580, 20, 0, 56, 0.3571),
            rel(580, 200, 0, 200, 1),
            at(600, 180, 0, 180, 1),
            rel(600, 0, 0, 56, 0),
        ])
        run("floating + pinned + snap, expanded 200", pinned: true, floating: true, snap: true,
            expandedHeight: 200, rows: [
            at(0, 200, 200, 200, 1),
            at(600, 56, 0, 56, 1),
            at(580, 56, 0, 56, 1),
            rel(580, 200, 0, 200, 1),
            at(600, 180, 0, 180, 1),
            rel(600, 56, 0, 56, 1),
        ])
    }

    /// C-geo-S: top padding 24, the bar reaches under the status bar.
    func testCGeoSTopPadding24() {
        run("neither, expanded 200, top padding 24", expandedHeight: 200, topPadding: 24, rows: [
            at(0, 224, 224, 224, 1),
            at(100, 124, 124, 124, 1),
            at(600, 0, 0, 80, 0),
            at(580, 0, 0, 80, 0),
        ])
        run("pinned, expanded 200, top padding 24", pinned: true, expandedHeight: 200, topPadding: 24, rows: [
            at(0, 224, 224, 224, 1),
            at(100, 124, 124, 124, 1),
            at(600, 80, 0, 80, 1),
            at(580, 80, 0, 80, 1),
        ])
        run("floating, expanded 200, top padding 24", floating: true, expandedHeight: 200, topPadding: 24, rows: [
            at(0, 224, 224, 224, 1),
            at(100, 124, 124, 124, 1),
            at(600, 0, 0, 80, 0),
            at(580, 20, 0, 80, 0),
            at(500, 100, 0, 100, 1),
        ])
        run("floating + pinned, expanded 200, top padding 24", pinned: true, floating: true,
            expandedHeight: 200, topPadding: 24, rows: [
            at(0, 224, 224, 224, 1),
            at(100, 124, 124, 124, 1),
            at(600, 80, 0, 80, 1),
            at(580, 80, 0, 80, 1),
            at(500, 100, 0, 100, 1),
        ])
        run("pinned, no expanded, top padding 24", pinned: true, topPadding: 24, rows: [
            at(0, 80, 80, 80, 1),
            at(600, 80, 0, 80, 1),
        ])
        run("pinned, expanded 200, collapsed 80, top padding 24", pinned: true, expandedHeight: 200,
            collapsedHeight: 80, topPadding: 24, rows: [
            at(0, 224, 224, 224, 1),
            at(600, 104, 0, 104, 1),
        ])
    }

    /// C-geo-S: the extents, `_SliverAppBarDelegate.minExtent` and
    /// `maxExtent` as `_SliverAppBarState.build` feeds them: the collapsed
    /// height (else the toolbar's 56) plus the top padding, and the expanded
    /// height (else 56) plus the top padding, never below the first.
    func testCGeoSMinAndMaxExtent() {
        func extents(expanded: Double? = nil, collapsed: Double? = nil, top: Double = 0) -> [Double] {
            let bar = SliverAppBarGeometry(expandedHeight: expanded, collapsedHeight: collapsed, topPadding: top)
            return [bar.minExtent, bar.maxExtent]
        }
        XCTAssertEqual(extents(), [56, 56])
        XCTAssertEqual(extents(expanded: 200), [56, 200])
        XCTAssertEqual(extents(expanded: 200, collapsed: 80), [80, 200])
        XCTAssertEqual(extents(collapsed: 80), [80, 80])
        XCTAssertEqual(extents(expanded: 200, top: 24), [80, 224])
        XCTAssertEqual(extents(expanded: 200, collapsed: 80, top: 24), [104, 224])
        // An expanded height below the collapsed one: the bar never shrinks.
        XCTAssertEqual(extents(expanded: 40), [56, 56])
        // A collapsed height below the toolbar's is taken as given (Flutter only asserts).
        XCTAssertEqual(extents(expanded: 200, collapsed: 40), [40, 200])
        // A negative top padding is taken as given.
        XCTAssertEqual(extents(expanded: 200, top: -10), [46, 190])
        XCTAssertEqual(SliverAppBarGeometry.toolbarHeight, 56)
    }

    /// C-geo-S: before any scroll the bar is fully open, and letting go
    /// then moves nothing; a bar without `snap`, or `snap` without
    /// `floating` (Flutter asserts), never settles.
    func testCGeoSBeforeAnyScrollAndWithoutSnapNothingSettles() {
        var fresh = SliverAppBarGeometry(floating: true, snap: true, expandedHeight: 200)
        XCTAssertEqual(fresh.frame, SliverAppBarFrame(paint: 200, layout: 200, box: 200, toolbarOpacity: 1))
        XCTAssertEqual(fresh.released(), SliverAppBarFrame(paint: 200, layout: 200, box: 200, toolbarOpacity: 1))

        var plain = SliverAppBarGeometry(snap: true, expandedHeight: 200)
        _ = plain.scrolled(to: 600)
        _ = plain.scrolled(to: 580)
        XCTAssertEqual(plain.released(), SliverAppBarFrame(paint: 0, layout: 0, box: 56, toolbarOpacity: 0))
    }

    /// C-geo-S: a collapsed height below the toolbar's is the bar's smallest
    /// extent as given: `_SliverAppBarDelegate.minExtent` is `collapsedHeight`
    /// fed raw (app_bar.dart; the `>= toolbarHeight` check is a debug assert).
    func testCGeoSCollapsedHeightBelowTheToolbar() {
        run("pinned, expanded 200, collapsed 40", pinned: true, expandedHeight: 200, collapsedHeight: 40, rows: [
            at(0, 200, 200, 200, 1),
            at(600, 40, 0, 40, 1),
        ])
    }

    /// C-geo-S: `effectiveOffset` as Flutter keeps it: a bar that does not
    /// float has the scroll offset there; a floating bar gone past its far
    /// edge keeps the scroll offset through a release that closes it.
    func testCGeoSEffectiveOffset() {
        var plain = SliverAppBarGeometry(expandedHeight: 200)
        XCTAssertEqual(plain.effectiveOffset, 0)
        for offset in [0.0, 600, 580] { plain.scrolled(to: offset) }
        XCTAssertEqual(plain.effectiveOffset, 580)

        var snap = SliverAppBarGeometry(floating: true, snap: true, expandedHeight: 200)
        for offset in [0.0, 600, 620] { snap.scrolled(to: offset) }
        XCTAssertEqual(snap.effectiveOffset, 620)
        XCTAssertEqual(snap.released(), SliverAppBarFrame(paint: 0, layout: 0, box: 56, toolbarOpacity: 0))
        XCTAssertEqual(snap.effectiveOffset, 620)
        // Back toward the start, the bar comes in from its far edge.
        XCTAssertEqual(snap.scrolled(to: 600).paint, 20)
        XCTAssertEqual(snap.effectiveOffset, 180)
        XCTAssertEqual(snap.released().paint, 200)
        XCTAssertEqual(snap.effectiveOffset, 0)
    }

    /// C-geo-S: a scroll offset pulled before the start (iOS's bounce) is
    /// the start: Flutter's sliver constraints never carry a negative
    /// scroll offset.
    func testCGeoSAnOffsetBeforeTheStartIsTheStart() {
        var bar = SliverAppBarGeometry(floating: true, expandedHeight: 200)
        XCTAssertEqual(bar.scrolled(to: -40), SliverAppBarFrame(paint: 200, layout: 200, box: 200, toolbarOpacity: 1))
        XCTAssertEqual(bar.offset, 0)
    }
}
