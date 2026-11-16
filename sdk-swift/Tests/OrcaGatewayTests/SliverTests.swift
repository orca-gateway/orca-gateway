#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// B13.1 and B13.2, the UI half of CustomScrollView and the four sliver
/// widgets against Flutter's builders (structure_builders.dart
/// `_buildCustomScrollView` ... `_buildSliverAppBar`) and the extents its
/// widget test measures (sdk/test/sliver_widgets_test.dart `barCases`, a
/// viewport of 800 x 600 there; here the views are 300 or 320 wide and 400
/// high, which changes no extent of the bar). The views that scroll are
/// hosted in a UIKit window and moved through their UIScrollView, as
/// ListTests does; a view with no limit on its axis and the slivers met
/// outside a CustomScrollView do not scroll and are drawn by ImageRenderer
/// (macOS and iOS). Rows count themselves into page key `built` on init.
/// The same cases as Kotlin's SliverTest.
@MainActor
final class SliverTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    override func tearDown() {
        ScrollNodeView.usesScrollPhase = true
        super.tearDown()
    }

    // MARK: C-fallback-S (ImageRenderer)

    /// C-fallback-S: a SliverList outside a CustomScrollView (Flutter
    /// throws) draws its children one below the other, each as wide as it.
    func testCFallbackSASliverListOutsideDrawsItsChildrenOneBelowTheOther() throws {
        let pixels = try draw([
            node("l", "SliverList", [:], ["a", "b"]),
            box("a", Self.redHex, width: 40, height: 40), box("b", Self.blueHex, height: 30),
        ], width: 300, height: 400)
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 40, width: 300, height: 30))
    }

    /// C-fallback-S: a SliverGrid outside a CustomScrollView draws every
    /// cell where GridCells puts it (2 across by default, square).
    func testCFallbackSASliverGridOutsideDrawsAnEagerGrid() throws {
        let pixels = try draw([
            node("g", "SliverGrid", ["mainAxisSpacing": 10], ["c0", "c1", "c2"]),
            box("c0", Self.redHex), box("c1", Self.greenHex), box("c2", Self.blueHex),
        ], width: 300, height: 400)
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 150, height: 150))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 150, y: 0, width: 150, height: 150))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 160, width: 150, height: 150))
    }

    /// C-fallback-S: a SliverToBoxAdapter outside a CustomScrollView draws
    /// its child; with no child, nothing.
    func testCFallbackSASliverToBoxAdapterOutsideDrawsItsChild() throws {
        let pixels = try draw([
            node("a", "SliverToBoxAdapter", [:], ["c"]), box("c", Self.redHex, width: 50, height: 40),
        ], width: 300, height: 400)
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 50, height: 40))

        let empty = try draw([node("a", "SliverToBoxAdapter")], width: 100, height: 100)
        XCTAssertNil(empty.bounds(of: { $0.a > 20 }), "an adapter with no child drew something")
    }

    /// C-fallback-S: a SliverAppBar outside a CustomScrollView is a box as
    /// tall as it is fully open (expandedHeight 120), as wide as offered,
    /// with its slots.
    func testCFallbackSASliverAppBarOutsideIsABoxOfItsExpandedHeight() throws {
        let pixels = try draw([
            bar("bar", ["backgroundColor": .string(Self.magentaHex), "expandedHeight": 120], ["leading": "lead"]),
            box("lead", Self.yellowHex),
        ], width: 300, height: 400)
        assertFrame(pixels.bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 120))
        assertFrame(pixels.bounds(of: Self.yellow), CGRect(x: 0, y: 0, width: 56, height: 56))

        let plain = try draw([bar("bar", ["backgroundColor": .string(Self.magentaHex)])], width: 300, height: 400)
        assertFrame(plain.bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 56))
    }

    // MARK: B13.1-S no limit on the scroll axis (ImageRenderer)

    /// B13.1-S: in a Column (no height limit) the view lays out every item,
    /// as long as its content, as ListView does there: the bar as a box, the
    /// adapter, two grid lines, the rows, then the Column's next child.
    func testB13_1SWithNoLimitEveryItemIsLaidOut() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "stretch"], ["s", "after"]),
            node("s", "CustomScrollView", [:], ["bar", "ad", "g", "l"]),
            bar("bar", ["backgroundColor": .string(Self.magentaHex), "pinned": true, "expandedHeight": 100]),
            node("ad", "SliverToBoxAdapter", [:], ["head"]), box("head", Self.redHex, height: 20),
            node("g", "SliverGrid", ["crossAxisCount": 3, "mainAxisSpacing": 10, "childAspectRatio": 2],
                 ["c0", "c1", "c2", "c3"]),
            box("c0", Self.greyHex), box("c1", Self.greyHex), box("c2", Self.greyHex), box("c3", Self.greenHex),
            node("l", "SliverList", [:], ["r0", "r1"]),
            box("r0", Self.greyHex, height: 40), box("r1", Self.blueHex, height: 40),
            box("after", Self.yellowHex, height: 20),
        ], width: 300, height: 600)
        assertFrame(pixels.bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 100))
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 100, width: 300, height: 20))
        // Cells 100 x 50; the second line after the first and its spacing.
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 180, width: 100, height: 50))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 270, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.yellow), CGRect(x: 0, y: 310, width: 300, height: 20))
    }

    #if canImport(UIKit)
    // MARK: B13.1-S one lazy scroll view (hosted)

    /// B13.1-S: a bar, an adapter, a list of 200, a grid and a closing
    /// adapter are ONE scroll view that builds only the rows near the
    /// screen (7 on screen; Flutter adds its 250 px cache); scrolled to the
    /// end, the closing adapter sits at the bottom edge and the rows passed
    /// over were never built.
    func testB13_1SABarAListOf200AGridAndAdaptersAreOneLazyScrollView() throws {
        let rows = (0..<200).map { "r\($0)" }
        let cells = (0..<6).map { "c\($0)" }
        let hosted = try HostedSlivers([
            node("s", "CustomScrollView", [:], ["bar", "ad", "l", "g", "end"]),
            bar("bar", ["backgroundColor": .string(Self.magentaHex), "expandedHeight": 100]),
            node("ad", "SliverToBoxAdapter", [:], ["head"]), box("head", Self.redHex, height: 40),
            node("l", "SliverList", [:], rows),
            node("g", "SliverGrid", ["crossAxisCount": 3], cells),
            node("end", "SliverToBoxAdapter", [:], ["last"]), box("last", Self.blueHex, height: 40),
        ] + rows.map { box($0, Self.greyHex, height: 40, actions: ["onInit": Self.count("built")]) }
            + cells.map { box($0, Self.greenHex) }, width: 300, height: 400)
        defer { hosted.close() }

        XCTAssertEqual(hosted.scrollViews.count, 1, "not one scroll view")
        assertFrame(hosted.scrollFrame, CGRect(x: 0, y: 0, width: 300, height: 400))
        let first = hosted.built
        XCTAssertTrue((5...30).contains(first), "built \(first)")
        let top = try hosted.pixels()
        assertFrame(top.bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 100))
        assertFrame(top.bounds(of: Self.red), CGRect(x: 0, y: 100, width: 300, height: 40))

        hosted.scrollToEnd()

        let end = try hosted.pixels()
        assertFrame(end.bounds(of: Self.blue), CGRect(x: 0, y: 360, width: 300, height: 40))
        // The two grid lines of 100 x 100 cells right above it.
        assertFrame(end.bounds(of: Self.green), CGRect(x: 0, y: 160, width: 300, height: 200))
        XCTAssertNil(end.bounds(of: Self.magenta), "a bar that neither pins nor floats is still drawn")
        XCTAssertTrue(hosted.built < 80, "built \(hosted.built) of 200 rows")
        XCTAssertEqual(hosted.scrollViews.count, 1)
    }

    /// B13.1-S: grid cells have GridCells' size and place: 3 across in 320
    /// with crossAxisSpacing 10 are 100 wide, ratio 2 makes them 50 high,
    /// mainAxisSpacing 8 between the two lines and none after the last.
    func testB13_1SGridCellsHaveGridCellsSizeAndPlace() throws {
        let props: [String: JSONValue] = ["crossAxisCount": 3, "mainAxisSpacing": 8, "crossAxisSpacing": 10,
                                          "childAspectRatio": 2]
        let hosted = try HostedSlivers([
            node("s", "CustomScrollView", [:], ["ad", "g", "l"]),
            node("ad", "SliverToBoxAdapter", [:], ["head"]), box("head", Self.greyHex, height: 50),
            node("g", "SliverGrid", props, ["c0", "c1", "c2", "c3", "c4"]),
            box("c0", Self.redHex, width: 10, height: 10), box("c1", Self.greyHex), box("c2", Self.yellowHex),
            box("c3", Self.greenHex), box("c4", Self.blueHex),
            node("l", "SliverList", [:], ["r0"]), box("r0", Self.magentaHex, height: 40),
        ], width: 320, height: 400)
        defer { hosted.close() }
        let cells = GridCells(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 10, childAspectRatio: 2)
        func cell(_ index: Int) -> CGRect {
            let frame = cells.frame(index, width: 320, height: 0)
            return CGRect(x: frame.x, y: 50 + frame.y, width: frame.width, height: frame.height)
        }
        XCTAssertEqual(cell(4), CGRect(x: 110, y: 108, width: 100, height: 50))
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), cell(0))
        assertFrame(pixels.bounds(of: Self.yellow), cell(2))
        assertFrame(pixels.bounds(of: Self.green), cell(3))
        assertFrame(pixels.bounds(of: Self.blue), cell(4))
        assertFrame(pixels.bounds(of: Self.magenta), CGRect(x: 0, y: 158, width: 320, height: 40))

        // No props: two square columns.
        let plain = try HostedSlivers([
            node("s", "CustomScrollView", [:], ["g"]), node("g", "SliverGrid", [:], ["c0", "c1", "c2"]),
            box("c0", Self.redHex), box("c1", Self.greenHex), box("c2", Self.blueHex),
        ], width: 300, height: 400)
        defer { plain.close() }
        let squares = try plain.pixels()
        assertFrame(squares.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 150, height: 150))
        assertFrame(squares.bounds(of: Self.green), CGRect(x: 150, y: 0, width: 150, height: 150))
        assertFrame(squares.bounds(of: Self.blue), CGRect(x: 0, y: 150, width: 150, height: 150))
    }

    /// B13.1-S: the view runs onScrollBegin, onScrolling and onScrollEnd
    /// with ListView's metrics (100 rows of 40 in a view of 400 scroll
    /// 3,600), on iOS 18's scroll phase and on the iOS 16-17 probe.
    func testB13_1SScrollingRunsTheScrollTriggers() throws {
        for phased in [true, false] {
            ScrollNodeView.usesScrollPhase = phased
            let rows = (0..<100).map { "r\($0)" }
            let hosted = try HostedSlivers([
                node("s", "CustomScrollView", [:], ["l"], actions: Self.triggers), node("l", "SliverList", [:], rows),
            ] + rows.map { box($0, Self.greyHex, height: 40) }, width: 300, height: 400)
            defer { hosted.close() }
            XCTAssertEqual(hosted.value("begins"), 0, "a trigger ran on the first build, phased \(phased)")

            hosted.scroll(to: 1000)

            XCTAssertEqual(hosted.value("begins"), 1, "phased \(phased)")
            XCTAssertEqual(hosted.value("ends"), 1, "phased \(phased)")
            XCTAssertEqual(hosted.value("endOffset"), 1000, "phased \(phased)")
            XCTAssertEqual(hosted.value("maxExtent"), 3600, "phased \(phased)")
            XCTAssertEqual(hosted.value("viewport"), 400, "phased \(phased)")
            XCTAssertEqual(hosted.value("endAtEnd"), false, "phased \(phased)")

            hosted.scroll(to: 3600)

            XCTAssertEqual(hosted.value("ends"), 2, "phased \(phased)")
            XCTAssertEqual(hosted.value("endOffset"), 3600, "phased \(phased)")
            XCTAssertEqual(hosted.value("endAtEnd"), true, "phased \(phased)")
        }
    }

    /// B13.1-S: the triggers fire as well on a view whose bar collapses
    /// (both read the same scroll samples), and the bar still collapses.
    func testB13_1STheScrollTriggersFireOnAViewWithACollapsingBar() throws {
        for phased in [true, false] {
            ScrollNodeView.usesScrollPhase = phased
            let hosted = try HostedSlivers(barPage(["pinned": true, "expandedHeight": 200], actions: Self.triggers),
                                           width: 300, height: 400)
            defer { hosted.close() }

            hosted.scroll(to: 600)

            XCTAssertEqual(hosted.value("begins"), 1, "phased \(phased)")
            XCTAssertEqual(hosted.value("ends"), 1, "phased \(phased)")
            XCTAssertEqual(hosted.value("endOffset"), 600, "phased \(phased)")
            XCTAssertEqual(hosted.value("viewport"), 400, "phased \(phased)")
            assertFrame(try hosted.pixels().bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 56),
                        "phased \(phased)")
        }
    }

    /// B13.1-S: a horizontal view runs across, each child as tall as the
    /// view (ListView's test); a grid line there is a column of cells.
    func testB13_1SAHorizontalViewRunsAcrossAndFillsItsHeight() throws {
        let hosted = try HostedSlivers([
            node("s", "CustomScrollView", ["scrollDirection": "horizontal"], ["ad", "l", "g"]),
            node("ad", "SliverToBoxAdapter", [:], ["a"]), box("a", Self.redHex, width: 50),
            node("l", "SliverList", [:], ["b"]), box("b", Self.greenHex, width: 60),
            node("g", "SliverGrid", ["crossAxisSpacing": 20], ["c0", "c1"]),
            box("c0", Self.blueHex), box("c1", Self.yellowHex),
        ], width: 300, height: 100)
        defer { hosted.close() }
        XCTAssertEqual(hosted.scrollViews.count, 1)
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 50, height: 100))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 50, y: 0, width: 60, height: 100))
        // Two cells down the 100 with 20 between: 40 x 40.
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 110, y: 0, width: 40, height: 40))
        assertFrame(pixels.bounds(of: Self.yellow), CGRect(x: 110, y: 60, width: 40, height: 40))
    }

    /// B13.1-S: reverse puts the first sliver at the far end, offset 0
    /// there (ListView's test); horizontal, it starts at the right. A bar
    /// in a reversed view is a plain box.
    func testB13_1SReverseStartsAtTheFarEnd() throws {
        let vertical = try HostedSlivers([
            node("s", "CustomScrollView", ["reverse": true], ["bar", "ad", "l"]),
            bar("bar", ["backgroundColor": .string(Self.magentaHex), "pinned": true, "expandedHeight": 100]),
            node("ad", "SliverToBoxAdapter", [:], ["a"]), box("a", Self.redHex, height: 40),
            node("l", "SliverList", [:], ["b", "c"]),
            box("b", Self.greenHex, height: 40), box("c", Self.blueHex, height: 40),
        ], width: 300, height: 400)
        defer { vertical.close() }
        let pixels = try vertical.pixels()
        assertFrame(pixels.bounds(of: Self.magenta), CGRect(x: 0, y: 300, width: 300, height: 100))
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 260, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 220, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 180, width: 300, height: 40))

        let horizontal = try HostedSlivers([
            node("s", "CustomScrollView", ["scrollDirection": "horizontal", "reverse": true], ["l"]),
            node("l", "SliverList", [:], ["a", "b"]),
            box("a", Self.redHex, width: 50), box("b", Self.greenHex, width: 60),
        ], width: 300, height: 100)
        defer { horizontal.close() }
        let row = try horizontal.pixels()
        assertFrame(row.bounds(of: Self.red), CGRect(x: 250, y: 0, width: 50, height: 100))
        assertFrame(row.bounds(of: Self.green), CGRect(x: 190, y: 0, width: 60, height: 100))
    }

    /// B13.1-S: shrinkWrap sizes the view to its content on the scroll
    /// axis, never past its parent, and stays lazy (ListView's test).
    func testB13_1SShrinkWrapHugsItsContent() throws {
        let short = try HostedSlivers([
            node("s", "CustomScrollView", ["shrinkWrap": true], ["ad", "l"]),
            node("ad", "SliverToBoxAdapter", [:], ["a"]), box("a", Self.greenHex, height: 40),
            node("l", "SliverList", [:], ["b", "c"]),
            box("b", Self.greyHex, height: 40), box("c", Self.blueHex, height: 40),
        ], width: 300, height: 400)
        defer { short.close() }
        assertFrame(short.scrollFrame, CGRect(x: 0, y: 0, width: 300, height: 120))
        assertFrame(try short.pixels().bounds(of: Self.blue), CGRect(x: 0, y: 80, width: 300, height: 40))

        let rows = (0..<1000).map { "r\($0)" }
        let long = try HostedSlivers([
            node("s", "CustomScrollView", ["shrinkWrap": true], ["l"]), node("l", "SliverList", [:], rows),
        ] + rows.map { box($0, Self.greyHex, height: 40, actions: ["onInit": Self.count("built")]) },
            width: 300, height: 400)
        defer { long.close() }
        assertFrame(long.scrollFrame, CGRect(x: 0, y: 0, width: 300, height: 400))
        XCTAssertTrue((10...30).contains(long.built), "built \(long.built)")
    }

    // MARK: B13.2-S the bar's extents (hosted)

    /// One row of Flutter's `barCases`: the view at `offset`, the bar drawn
    /// `paint` high.
    typealias At = (offset: CGFloat, paint: CGFloat)

    /// B13.2-S: a bar that neither pins nor floats scrolls away with the
    /// content and stays away (Flutter's "neither" cases).
    func testB13_2SABarThatNeitherPinsNorFloatsScrollsAway() throws {
        try assertBar(["expandedHeight": 200], maxExtent: 200, [(0, 200), (100, 100), (600, 0), (580, 0)])
        try assertBar([:], maxExtent: 56, [(0, 56), (30, 26), (600, 0), (580, 0)])
        try assertBar(["expandedHeight": 200, "collapsedHeight": 80], maxExtent: 200,
                      [(0, 200), (100, 100), (150, 50), (600, 0)])
    }

    /// B13.2-S: a pinned bar shrinks to the toolbar's 56, or to
    /// `collapsedHeight`, and stays over the content.
    func testB13_2SAPinnedBarShrinksToItsCollapsedHeightAndStays() throws {
        try assertBar(["pinned": true, "expandedHeight": 200], maxExtent: 200,
                      [(0, 200), (100, 100), (600, 56), (580, 56)])
        try assertBar(["pinned": true], maxExtent: 56, [(0, 56), (30, 56), (600, 56), (580, 56)])
        try assertBar(["pinned": true, "expandedHeight": 200, "collapsedHeight": 80], maxExtent: 200,
                      [(0, 200), (100, 100), (150, 80), (600, 80)])
        try assertBar(["pinned": true, "collapsedHeight": 80], maxExtent: 80, [(0, 80), (600, 80)])
    }

    /// B13.2-S: a floating bar is gone once scrolled away and comes back
    /// as far as the view scrolls toward its start, wherever the view is;
    /// on iOS 18's scroll geometry and on the iOS 16-17 probe.
    func testB13_2SAFloatingBarReEntersOnAReverseScroll() throws {
        for phased in [true, false] {
            ScrollNodeView.usesScrollPhase = phased
            try assertBar(["floating": true, "expandedHeight": 200], maxExtent: 200,
                          [(0, 200), (100, 100), (600, 0), (580, 20), (500, 100), (520, 80)], "phased \(phased)")
            try assertBar(["floating": true], maxExtent: 56,
                          [(0, 56), (30, 26), (600, 0), (580, 20), (500, 56), (520, 36)], "phased \(phased)")
            try assertBar(["floating": true, "pinned": true, "expandedHeight": 200], maxExtent: 200,
                          [(0, 200), (100, 100), (600, 56), (580, 56), (500, 100), (520, 80)], "phased \(phased)")
            try assertBar(["floating": true, "pinned": true, "expandedHeight": 200, "collapsedHeight": 80],
                          maxExtent: 200, [(0, 200), (600, 80), (580, 80), (500, 100)], "phased \(phased)")
        }
    }

    /// B13.2-S: the toolbar row fades as its own 56 points leave: Flutter's
    /// 0.4643 with 26 of a plain bar's 56 left, 0.3571 with 20 of a floating
    /// bar back, 1 fully open and always 1 when pinned. The title is a
    /// black box over the magenta bar, so its pixels read the opacity.
    func testB13_2STheToolbarFadesAsItLeaves() throws {
        func title(_ props: [String: JSONValue], at offsets: [CGFloat], x: Int, y: Int) throws -> Double {
            let hosted = try HostedSlivers(barPage(props, slots: ["title": "title"])
                + [box("title", "#000000", width: 20, height: 20)], width: 300, height: 400)
            defer { hosted.close() }
            for offset in offsets { hosted.move(to: offset) }
            // Black at `opacity` over (255, 0, 255) leaves 255 x (1 - opacity) of red.
            return 1 - Double(try hosted.pixels().pixel(x, y).r) / 255
        }
        // The title is centred in the toolbar: rows 18 ..< 38 of the bar's box.
        XCTAssertEqual(try title([:], at: [], x: 150, y: 28), 1, accuracy: 0.03)
        // 30 scrolled: the box's rows 30 ..< 56 are on screen, the title's last 8 at the top.
        XCTAssertEqual(try title([:], at: [30], x: 150, y: 4), 0.4643, accuracy: 0.03)
        XCTAssertEqual(try title(["pinned": true], at: [30], x: 150, y: 28), 1, accuracy: 0.03)
        // Floated 20 back in: the box's rows 36 ..< 56, the title's last 2.
        XCTAssertEqual(try title(["floating": true, "expandedHeight": 200], at: [600, 580], x: 150, y: 1),
                       0.3571, accuracy: 0.03)
        XCTAssertEqual(try title(["expandedHeight": 200], at: [100], x: 150, y: 28), 1, accuracy: 0.03,
                       "100 of 200 left: the toolbar is whole")
    }

    /// B13.2-S: `snap` settles a floating bar when the scroll ends: fully
    /// open after a scroll toward the start, fully away after one toward
    /// the end (Flutter's "floating + snap" case), the scroll offset
    /// unchanged.
    func testB13_2SASnapBarSettlesWhenTheScrollEnds() throws {
        for phased in [true, false] {
            ScrollNodeView.usesScrollPhase = phased
            let hosted = try HostedSlivers(barPage(["floating": true, "snap": true, "expandedHeight": 200]),
                                           width: 300, height: 400)
            defer { hosted.close() }
            // Short pumps: on the iOS 16-17 path a view at rest for 0.15 s has ended its scroll.
            hosted.beginDrag()
            hosted.move(to: 600, pump: 0.04)
            hosted.move(to: 580, pump: 0.04)
            assertPaint(try hosted.pixels(), 20, "dragged back 20, phased \(phased)")

            hosted.endDrag()

            assertPaint(try hosted.pixels(), 200, "released after a scroll toward the start, phased \(phased)")
            XCTAssertEqual(hosted.offset, 580, accuracy: 0.5, "the settle moved the view")

            hosted.beginDrag()
            hosted.move(to: 600, pump: 0.04)
            assertPaint(try hosted.pixels(), 180, "dragged on 20, phased \(phased)")
            hosted.endDrag()

            assertPaint(try hosted.pixels(), 0, "released after a scroll toward the end, phased \(phased)")
        }
    }

    /// B13.2-S: the slots are drawn as Flutter lays them out: `leading` a
    /// 56 box at the leading edge, the title centred in the 56-high
    /// toolbar, the actions in order at the trailing edge (stopping at the
    /// first gap: `action_2` without `action_1` is not drawn), and
    /// `flexibleSpace` behind them as wide as the bar, up to its height
    /// (Flutter's loose height: a box with no height of its own fills the
    /// bar, 200 high open and 56 collapsed; one 20 high stays 20, at the
    /// top). The bar's own onInit fires once.
    func testB13_2STheSlotsAreDrawn() throws {
        let slots = ["leading": "lead", "title": "title", "flexibleSpace": "space", "action_0": "a0",
                     "action_2": "a2"]
        let hosted = try HostedSlivers(
            barPage(["pinned": true, "expandedHeight": 200], slots: slots, barActions: ["onInit": Self.count("built")])
                + [box("lead", Self.yellowHex), box("title", "#000000", width: 20, height: 20),
                   box("space", Self.blueHex), box("a0", Self.redHex, width: 24, height: 24),
                   box("a2", Self.cyanHex, width: 24, height: 24)],
            width: 300, height: 400)
        defer { hosted.close() }
        XCTAssertEqual(hosted.built, 1, "the bar's onInit")
        let open = try hosted.pixels()
        assertFrame(open.bounds(of: Self.blue), CGRect(x: 0, y: 0, width: 300, height: 200))
        assertFrame(open.bounds(of: Self.yellow), CGRect(x: 0, y: 0, width: 56, height: 56))
        assertFrame(open.bounds(of: Self.black), CGRect(x: 140, y: 18, width: 20, height: 20))
        assertFrame(open.bounds(of: Self.red), CGRect(x: 260, y: 16, width: 24, height: 24))
        XCTAssertNil(open.bounds(of: Self.cyan), "action_2 drawn across the gap at action_1")
        XCTAssertNil(open.bounds(of: Self.magenta), "the flexibleSpace does not cover the bar's box")

        hosted.move(to: 300)

        let collapsed = try hosted.pixels()
        // The whole 56 of the box, seen beside the leading box that now covers its first 56 across.
        assertFrame(collapsed.bounds(of: Self.blue), CGRect(x: 56, y: 0, width: 244, height: 56))
        assertFrame(collapsed.bounds(of: Self.yellow), CGRect(x: 0, y: 0, width: 56, height: 56))
        assertFrame(collapsed.bounds(of: Self.black), CGRect(x: 140, y: 18, width: 20, height: 20))
        XCTAssertEqual(hosted.built, 1, "the bar's onInit fired again")

        // A flexibleSpace with a height of its own keeps it, as wide as the bar, at its top.
        let low = try HostedSlivers(
            barPage(["pinned": true, "expandedHeight": 200], slots: ["flexibleSpace": "space"])
                + [box("space", Self.blueHex, width: 40, height: 20)],
            width: 300, height: 400)
        defer { low.close() }
        let short = try low.pixels()
        assertFrame(short.bounds(of: Self.blue), CGRect(x: 0, y: 0, width: 300, height: 20))
        assertFrame(short.bounds(of: Self.magenta), CGRect(x: 0, y: 20, width: 300, height: 180))

        // Two actions, in order, both after a title that is not centred.
        let two = try HostedSlivers(
            barPage(["centerTitle": false], slots: ["title": "title", "action_0": "a0", "action_1": "a1"])
                + [box("title", "#000000", width: 20, height: 20), box("a0", Self.redHex, width: 24, height: 24),
                   box("a1", Self.cyanHex, width: 24, height: 24)],
            width: 300, height: 400)
        defer { two.close() }
        let pixels = try two.pixels()
        assertFrame(pixels.bounds(of: Self.black), CGRect(x: 16, y: 18, width: 20, height: 20))
        assertFrame(pixels.bounds(of: Self.cyan), CGRect(x: 260, y: 16, width: 24, height: 24))
        let first = try XCTUnwrap(pixels.bounds(of: Self.red))
        XCTAssertLessThan(first.maxX, 260.5, "action_0 is not before action_1")
        XCTAssertGreaterThan(first.minX, 36, "action_0 is not after the title")
    }

    /// B13.2-S: under the status bar (a top safe-area inset of 24) the bar
    /// reaches the top of the screen and is 24 taller, the toolbar below
    /// the inset: Flutter's "top padding 24" cases, 224 open and 80 pinned.
    func testB13_2SUnderTheStatusBarTheBarIsTallerByTheInset() throws {
        let hosted = try HostedSlivers(
            barPage(["pinned": true, "expandedHeight": 200], slots: ["leading": "lead"])
                + [box("lead", Self.yellowHex)],
            width: 300, height: 400, insets: UIEdgeInsets(top: 24, left: 0, bottom: 0, right: 0))
        defer { hosted.close() }
        XCTAssertEqual(hosted.scrollViews.count, 1)
        let open = try hosted.pixels()
        assertFrame(open.bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 224))
        assertFrame(open.bounds(of: Self.yellow), CGRect(x: 0, y: 24, width: 56, height: 56))
        assertFrame(open.bounds(of: Self.green), CGRect(x: 0, y: 224, width: 300, height: 50))

        hosted.move(to: 100)
        assertFrame(try hosted.pixels().bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 124))
        assertFrame(try hosted.pixels().bounds(of: Self.green), CGRect(x: 0, y: 124, width: 300, height: 50))

        hosted.move(to: 600)
        let pinned = try hosted.pixels()
        assertFrame(pinned.bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 80))
        assertFrame(pinned.bounds(of: Self.yellow), CGRect(x: 0, y: 24, width: 56, height: 56))
    }

    /// B13.2-S: the collapsing bar is in the scroll view's content, as
    /// Flutter's is a sliver of the one Scrollable, so a touch on it is the
    /// scroll view's (a drag that starts there scrolls the view): UIKit's
    /// hit test at a point on the bar answers the UIScrollView or a view
    /// inside it, open, pinned at 56 and in a top bounce; on iOS 18's
    /// scroll geometry and on the iOS 16-17 probe.
    func testB13_2SATouchOnTheBarIsTheScrollViews() throws {
        for phased in [true, false] {
            ScrollNodeView.usesScrollPhase = phased
            let hosted = try HostedSlivers(barPage(["pinned": true, "expandedHeight": 200]), width: 300, height: 400)
            defer { hosted.close() }
            assertPaint(try hosted.pixels(), 200, "open, phased \(phased)")
            XCTAssertTrue(hosted.hitsScrollView(CGPoint(x: 150, y: 100)), "open, phased \(phased)")
            XCTAssertTrue(hosted.hitsScrollView(CGPoint(x: 150, y: 300)), "a row, phased \(phased)")

            hosted.move(to: 600)

            assertPaint(try hosted.pixels(), 56, "pinned, phased \(phased)")
            XCTAssertTrue(hosted.hitsScrollView(CGPoint(x: 150, y: 28)), "pinned, phased \(phased)")

            // Past the start, as a bounce: the bar stays at the top of the view, the content 30 lower.
            hosted.move(to: -30)

            let bounced = try hosted.pixels()
            assertPaint(bounced, 200, "bounced, phased \(phased)")
            assertFrame(bounced.bounds(of: Self.green), CGRect(x: 0, y: 230, width: 300, height: 50),
                        "bounced, phased \(phased)")
            XCTAssertTrue(hosted.hitsScrollView(CGPoint(x: 150, y: 100)), "bounced, phased \(phased)")
        }
    }

    /// B13.2-S: the bar moves with the scroll in the same layout pass, not
    /// a frame behind: the offset set and the window laid out, with no turn
    /// of the run loop, the pinned bar is still the top 56 of the view (a
    /// bar a pass behind would be 20 up, 36 of it showing); on iOS 18's
    /// scroll geometry and on the iOS 16-17 probe.
    func testB13_2SThePinnedBarDoesNotLagTheScroll() throws {
        for phased in [true, false] {
            ScrollNodeView.usesScrollPhase = phased
            let hosted = try HostedSlivers(barPage(["pinned": true, "expandedHeight": 200]), width: 300, height: 400)
            defer { hosted.close() }
            hosted.move(to: 600)
            for offset: CGFloat in [620, 640, 660, 640, 700] {
                hosted.jump(to: offset)
                assertPaint(try hosted.pixels(), 56, "at \(offset) with no run loop turn, phased \(phased)")
            }
        }
    }

    // MARK: B13.1-S inside an AnimatedSwitcher (hosted)

    /// B13.1-S: a CustomScrollView that is the child of an AnimatedSwitcher
    /// and is replaced fades out whole: the slivers it flattens (an
    /// adapter, a list, a grid) are in the switcher's record with their
    /// children, so the outgoing copy still draws its rows and cells.
    func testB13_1SAReplacedCustomScrollViewFadesOutWithItsRows() throws {
        // A fade far longer than the test: the outgoing layer stays opaque.
        let hosted = try HostedSlivers([
            node("w", "AnimatedSwitcher", ["duration": 3_600_000], ["s"]),
            node("s", "CustomScrollView", [:], ["ad", "l", "g"]),
            node("ad", "SliverToBoxAdapter", [:], ["a"]), box("a", Self.redHex, height: 40),
            node("l", "SliverList", [:], ["b"]), box("b", Self.greenHex, height: 40),
            node("g", "SliverGrid", [:], ["c"]), box("c", Self.blueHex),
        ], width: 300, height: 400)
        defer { hosted.close() }
        func assertRows(_ message: String) throws {
            let pixels = try hosted.pixels()
            assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 300, height: 40), message)
            assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 40, width: 300, height: 40), message)
            assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 80, width: 150, height: 150), message)
        }
        try assertRows("live")

        hosted.model.apply(.replace(targetId: "s", components: [
            try box("n", Self.yellowHex, width: 20, height: 20).decode(ComponentNode.self),
        ]))
        hosted.pump(0.3)

        XCTAssertNil(hosted.model.resolve("s"), "the replace left the old child on the page")
        XCTAssertNil(hosted.model.resolve("l"))
        try assertRows("the outgoing copy")
    }

    // MARK: C-fallback-S (hosted)

    /// C-fallback-S: a widget that is no sliver, directly in a
    /// CustomScrollView (Flutter throws), is drawn as an adapter's child:
    /// at the cross extent, in its place.
    func testCFallbackSAStrayChildInsideIsDrawnAsABox() throws {
        let hosted = try HostedSlivers([
            node("s", "CustomScrollView", [:], ["ad", "stray", "l"]),
            node("ad", "SliverToBoxAdapter", [:], ["a"]), box("a", Self.greenHex, height: 40),
            box("stray", Self.redHex, width: 50, height: 30),
            node("l", "SliverList", [:], ["b"]), box("b", Self.blueHex, height: 40),
        ], width: 300, height: 400)
        defer { hosted.close() }
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 40, width: 300, height: 30))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 70, width: 300, height: 40))
    }

    /// C-fallback-S: a bar that is not the first sliver is a box of its
    /// expanded height in its place that scrolls away with the content,
    /// pinned or not; so is a bar in a horizontal view.
    func testCFallbackSABarThatIsNotFirstIsABoxThatScrollsAway() throws {
        let rows = (0..<20).map { "r\($0)" }
        let hosted = try HostedSlivers([
            node("s", "CustomScrollView", [:], ["ad", "bar", "l"]),
            node("ad", "SliverToBoxAdapter", [:], ["a"]), box("a", Self.greenHex, height: 50),
            bar("bar", ["backgroundColor": .string(Self.magentaHex), "pinned": true, "expandedHeight": 100]),
            node("l", "SliverList", [:], rows),
        ] + rows.map { box($0, Self.greyHex, height: 40) }, width: 300, height: 400)
        defer { hosted.close() }
        assertFrame(try hosted.pixels().bounds(of: Self.magenta), CGRect(x: 0, y: 50, width: 300, height: 100))

        hosted.move(to: 80)
        assertFrame(try hosted.pixels().bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: 70))

        hosted.move(to: 300)
        XCTAssertNil(try hosted.pixels().bounds(of: Self.magenta), "the bar stayed")

        let across = try HostedSlivers([
            node("s", "CustomScrollView", ["scrollDirection": "horizontal"], ["bar", "l"]),
            bar("bar", ["backgroundColor": .string(Self.magentaHex), "pinned": true, "expandedHeight": 80]),
            node("l", "SliverList", [:], ["a"]), box("a", Self.greenHex, width: 60),
        ], width: 300, height: 100)
        defer { across.close() }
        let row = try across.pixels()
        let drawn = try XCTUnwrap(row.bounds(of: Self.magenta), "the bar is not drawn")
        XCTAssertEqual(drawn.minX, 0, accuracy: Self.accuracy)
        XCTAssertEqual(drawn.height, 80, accuracy: Self.accuracy)
        XCTAssertEqual(try XCTUnwrap(row.bounds(of: Self.green)).minX, drawn.maxX, accuracy: Self.accuracy)
    }

    // MARK: C-fix (hosted)

    /// C-fix: render fixture 69 is drawn by the real widgets: the five
    /// types are advertised (none degraded to the fallback prompt), its two
    /// CustomScrollViews are two scroll views, the bar is 200 high with its
    /// flexibleSpace over it, and its onInit ran.
    func testCFixFixture69IsDrawnNotDegraded() throws {
        let url = swiftRoot.appendingPathComponent("../schema/fixtures/render/69_custom_scroll_view_slivers.json")
        let fixture = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
        let components = try XCTUnwrap(fixture["expected"].arrayValue)
        var state: [JSONValue] = []
        if case .object(let pageState) = fixture["context"]["pageState"] {
            state = pageState.map { ["key": .string($0.key), "scope": "page", "initial": $0.value] }
        }
        let model = OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(state), "components": .array(components),
        ]).decode(PageResponse.self))
        for id in ["scroll", "bar", "adapter", "grid", "list", "strip"] {
            let resolved = try XCTUnwrap(model.resolve(id), id)
            XCTAssertNil(resolved.degradedFrom, "\(id) (\(resolved.type)) was degraded")
            XCTAssertTrue(GeneratedCapabilities.widgets.contains(resolved.type), "\(resolved.type) is not advertised")
        }

        let hosted = try HostedSlivers(model: model, root: "page", width: 300, height: 500)
        defer { hosted.close() }
        XCTAssertEqual(hosted.scrollViews.count, 2)
        // flexibleSpace #3949AB over the bar's #1A237E.
        assertFrame(try hosted.pixels().bounds(of: Self.colour(0x39, 0x49, 0xAB)),
                    CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertEqual(model.store.value("barReady"), true)
    }

    // MARK: bar pages

    /// CustomScrollView `s` > [SliverAppBar `bar` (magenta), SliverToBoxAdapter
    /// (`first`, green, 50 high), SliverList of 40 grey rows 50 high]: the
    /// page of Flutter's `_barPage`.
    func barPage(_ props: [String: JSONValue], slots: [String: String] = [:], actions: [String: JSONValue] = [:],
                 barActions: [String: JSONValue] = [:]) -> [JSONValue] {
        let rows = (0..<40).map { "r\($0)" }
        var barProps = props
        barProps["backgroundColor"] = .string(Self.magentaHex)
        return [
            node("s", "CustomScrollView", [:], ["bar", "ad", "l"], actions: actions),
            bar("bar", barProps, slots, actions: barActions),
            node("ad", "SliverToBoxAdapter", [:], ["first"]), box("first", Self.greenHex, height: 50),
            node("l", "SliverList", [:], rows),
        ] + rows.map { box($0, Self.greyHex, height: 50) }
    }

    /// The bar `props` at each row's offset in turn (moved there as a drag
    /// moves a view, one offset after the other): the bar is drawn
    /// `paint` high from the top, and the first content sits `maxExtent`
    /// less the offset down, under the bar where the bar lies over it.
    func assertBar(_ props: [String: JSONValue], maxExtent: CGFloat, _ rows: [At], _ message: String = "",
                   file: StaticString = #filePath, line: UInt = #line) throws {
        let hosted = try HostedSlivers(barPage(props), width: 300, height: 400)
        defer { hosted.close() }
        XCTAssertEqual(hosted.scrollViews.count, 1, file: file, line: line)
        for row in rows {
            hosted.move(to: row.offset)
            let pixels = try hosted.pixels()
            let note = "\(props) at \(row.offset) \(message)"
            assertPaint(pixels, row.paint, note, file: file, line: line)
            // `layout`: the first content's top, max(0, maxExtent - offset) while it is on screen.
            let top = max(maxExtent - row.offset, row.paint), bottom = maxExtent - row.offset + 50
            if bottom - top >= 1 {
                assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: top, width: 300, height: bottom - top),
                            "first content, \(note)", file: file, line: line)
            } else {
                XCTAssertNil(pixels.bounds(of: Self.green), "first content, \(note)", file: file, line: line)
            }
        }
    }

    /// The magenta bar is drawn `paint` high from the top, or not at all.
    func assertPaint(_ pixels: Pixels, _ paint: CGFloat, _ message: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        if paint == 0 {
            XCTAssertNil(pixels.bounds(of: Self.magenta), "the bar is drawn, \(message)", file: file, line: line)
        } else {
            assertFrame(pixels.bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 300, height: paint),
                        "the bar, \(message)", file: file, line: line)
        }
    }
    #endif

    // MARK: pages

    static let redHex = "#FF0000", greenHex = "#00FF00", blueHex = "#0000FF", yellowHex = "#FFFF00"
    static let magentaHex = "#FF00FF", cyanHex = "#00FFFF", greyHex = "#808080"
    static let keys = ["built", "begins", "scrolls", "ends", "endOffset", "endAtEnd", "viewport", "maxExtent"]

    /// As ListTests': begin counts; onScrolling counts and writes maxExtent;
    /// end counts and writes where it settled, whether at the end, and the
    /// viewport.
    static var triggers: [String: JSONValue] {
        [
            "onScrollBegin": count("begins"),
            "onScrolling": sequence([count("scrolls"), write("maxExtent", "maxExtent")]),
            "onScrollEnd": sequence([count("ends"), write("endOffset", "offset"), write("endAtEnd", "atEnd"),
                                     write("viewport", "viewportDimension")]),
        ]
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

    /// A wire node: a CustomScrollView, SliverList, SliverGrid, Column or
    /// Row holds many children, the rest (an AnimatedSwitcher) at most one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:], _ children: [String] = [],
              actions: [String: JSONValue] = [:]) -> JSONValue {
        let multi = ["CustomScrollView", "SliverList", "SliverGrid", "Column", "Row"].contains(type)
        return [
            "id": .string(id), "type": .string(type), "kind": "layout",
            "childMode": .string(multi ? "multi" : children.isEmpty ? "none" : "single"),
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
            "actions": .object(actions),
        ]
    }

    /// A SliverAppBar as the encoder sends it: a structure node whose slots
    /// are props holding node ids, the same ids its children.
    func bar(_ id: String, _ props: [String: JSONValue] = [:], _ slots: [String: String] = [:],
             actions: [String: JSONValue] = [:]) -> JSONValue {
        var all = props
        for (name, slot) in slots { all[name] = .string(slot) }
        return [
            "id": .string(id), "type": "SliverAppBar", "kind": "structure", "childMode": "none",
            "props": .object(all), "children": .array(slots.keys.sorted().map { .string(slots[$0] ?? "") }),
            "watches": [], "actions": .object(actions),
        ]
    }

    /// A Container of `hex`, `width` by `height` when set.
    func box(_ id: String, _ hex: String, width: Double? = nil, height: Double? = nil,
             actions: [String: JSONValue] = [:]) -> JSONValue {
        var props: [String: JSONValue] = ["color": .string(hex)]
        if let width { props["width"] = .double(width) }
        if let height { props["height"] = .double(height) }
        return node(id, "Container", props, actions: actions)
    }

    /// The page of `nodes`, its keys at 0.
    static func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": .array(keys.map { ["key": .string($0), "scope": "page", "initial": 0] }),
            "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page)
    }

    static func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    // MARK: helpers

    typealias Pixel = (r: UInt8, g: UInt8, b: UInt8, a: UInt8)

    static func colour(_ r: Int, _ g: Int, _ b: Int) -> (Pixel) -> Bool {
        { p in p.a > 250 && abs(Int(p.r) - r) < 12 && abs(Int(p.g) - g) < 12 && abs(Int(p.b) - b) < 12 }
    }

    static let red = colour(255, 0, 0)
    static let green = colour(0, 255, 0)
    static let blue = colour(0, 0, 255)
    static let yellow = colour(255, 255, 0)
    static let magenta = colour(255, 0, 255)
    static let cyan = colour(0, 255, 255)
    static let black = colour(0, 0, 0)

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, _ message: String = "",
                     file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected) \(message)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected) \(message)", file: file, line: line)
        }
    }

    /// The first node drawn by ImageRenderer at scale 1 in a `width` by
    /// `height` box from the top leading corner.
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat) throws -> Pixels {
        let view = NodeView(id: try Self.rootId(nodes), model: try Self.model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}

#if canImport(UIKit)
/// A node in a light UIKit window `width` by `height` (scale 1 pixels),
/// kept on screen until `close`. Without `insets` the node is laid out over
/// the whole window, safe area or not, as ListTests hosts a list; with
/// them, as OrcaPageView lays a page out: filling the window inside its
/// safe area, here `insets`, in a window away from the screen's own.
@MainActor
private final class HostedSlivers {
    let model: OrcaPageModel
    private let window: UIWindow

    convenience init(_ nodes: [JSONValue], width: CGFloat, height: CGFloat, insets: UIEdgeInsets? = nil) throws {
        try self.init(model: try SliverTests.model(nodes), root: try SliverTests.rootId(nodes),
                      width: width, height: height, insets: insets)
    }

    init(model: OrcaPageModel, root: String, width: CGFloat, height: CGFloat, insets: UIEdgeInsets? = nil) throws {
        self.model = model
        let host: UIViewController
        if let insets {
            host = UIHostingController(rootView: NodeView(id: root, model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
            host.additionalSafeAreaInsets = insets
        } else {
            host = UIHostingController(rootView: NodeView(id: root, model: model)
                .frame(width: width, height: height, alignment: .topLeading)
                .ignoresSafeArea())
        }
        // Away from the screen's edges, so the device's own insets (the
        // status bar, the home indicator) do not reach it.
        window = UIWindow(frame: CGRect(x: 0, y: 200, width: width, height: height))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        pump(0.3)
    }

    func value(_ key: String) -> JSONValue { model.store.value(key) }

    /// Whether UIKit's hit test at `point` of the window answers the scroll
    /// view or a view inside it: a touch there is the scroll view's.
    func hitsScrollView(_ point: CGPoint) -> Bool {
        guard let scrollView, let hit = window.hitTest(point, with: nil) else { return false }
        return hit.isDescendant(of: scrollView)
    }

    /// How many nodes have run their counting onInit.
    var built: Int { value("built").dartInt ?? -1 }

    /// Every UIScrollView in the window.
    var scrollViews: [UIScrollView] {
        func find(_ view: UIView) -> [UIScrollView] {
            ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap(find)
        }
        return find(window)
    }

    private var scrollView: UIScrollView? { scrollViews.first }

    /// The scroll view's frame in the window.
    var scrollFrame: CGRect? { scrollView.map { $0.convert($0.bounds, to: window) } }

    /// The scroll offset from the content's start.
    var offset: CGFloat {
        guard let scrollView else { return -1 }
        return scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    }

    private func point(_ offset: CGFloat) -> CGPoint {
        CGPoint(x: 0, y: offset - (scrollView?.adjustedContentInset.top ?? 0))
    }

    /// `setContentOffset` with no scroll in progress (a jump), then a pump.
    func scroll(to offset: CGFloat) {
        scrollView?.setContentOffset(point(offset), animated: false)
        pump(0.5)
    }

    /// The offset set as a drag or a fling sets it, then a pump long enough
    /// for the lazy stack to lay out there.
    func move(to offset: CGFloat, pump seconds: Double = 0.25) {
        scrollView?.contentOffset = point(offset)
        pump(seconds)
    }

    /// The offset set and the window laid out, the run loop not turned.
    func jump(to offset: CGFloat) {
        scrollView?.contentOffset = point(offset)
        window.layoutIfNeeded()
    }

    /// To the end of the content: twice, as a lazy stack learns its length
    /// from the rows it has built.
    func scrollToEnd() {
        for _ in 0..<3 {
            guard let scrollView else { return }
            let end = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom
                - scrollView.bounds.height
            scrollView.setContentOffset(CGPoint(x: 0, y: end), animated: false)
            pump(0.5)
        }
    }

    /// The delegate call UIKit makes when a finger starts dragging the view.
    func beginDrag() {
        guard let scrollView else { return }
        scrollView.delegate?.scrollViewWillBeginDragging?(scrollView)
        pump(0.1)
    }

    /// The delegate calls UIKit makes when the finger lifts with no fling
    /// to follow, then a pump past the settle wait and the snap's 300 ms.
    func endDrag() {
        guard let scrollView else { return }
        var target = scrollView.contentOffset
        scrollView.delegate?.scrollViewWillEndDragging?(scrollView, withVelocity: .zero, targetContentOffset: &target)
        scrollView.delegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: false)
        pump(0.8)
    }

    func pixels() throws -> Pixels {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }

    func pump(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func close() {
        window.isHidden = true
    }
}
#endif
#endif
