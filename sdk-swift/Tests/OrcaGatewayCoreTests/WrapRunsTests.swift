import XCTest

@testable import OrcaGatewayCore

/// A3.3: Wrap's runs and offsets against Flutter's `RenderWrap`
/// (rendering/wrap.dart: `_computeRuns`, `_RunMetrics.tryAddingNewChild`,
/// `_positionChildren`, `WrapAlignment._distributeSpace`) and the builder's
/// parsing (layout_builders.dart `_parseWrapAlignment`,
/// `_parseWrapCrossAlignment`). Sizes are (main, cross): a horizontal Wrap's
/// (width, height), a vertical one's (height, width). The same cases as
/// Kotlin's WrapRunsTest.
final class WrapRunsTests: XCTestCase {
    private func sizes(_ pairs: [(Double, Double)]) -> [WrapSize] {
        pairs.map { WrapSize(main: $0.0, cross: $0.1) }
    }

    private func assertLayout(_ size: (Double, Double), _ offsets: [(Double, Double)], _ actual: WrapLayout,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.size, WrapSize(main: size.0, cross: size.1), "size", file: file, line: line)
        XCTAssertEqual(actual.offsets.count, offsets.count, "offset count", file: file, line: line)
        for (index, (expected, got)) in zip(offsets, actual.offsets).enumerated() {
            XCTAssertEqual(got.main, expected.0, accuracy: 1e-9, "child \(index) main", file: file, line: line)
            XCTAssertEqual(got.cross, expected.1, accuracy: 1e-9, "child \(index) cross", file: file, line: line)
        }
    }

    /// Four children with a run of three that leaves 12 free in a Wrap 82
    /// wide (the first child, 82, fills a run alone): spacing 5.
    private func aligned(_ alignment: WrapAlignment) -> WrapLayout {
        WrapRuns.layout(sizes([(82, 10), (20, 10), (20, 10), (20, 10)]),
                        minMain: 0, maxMain: 100, minCross: 0, maxCross: 200, spacing: 5, alignment: alignment)
    }

    /// A3.3: a child that does not fit opens a new run, spacing between
    /// children, runSpacing between runs.
    func testA3_3AFullRunMovesTheNextChildToANewRunWithSpacingAndRunSpacing() {
        let layout = WrapRuns.layout(sizes([(40, 10), (40, 20), (40, 10)]),
                                     minMain: 0, maxMain: 100, minCross: 0, maxCross: 200,
                                     spacing: 10, runSpacing: 5)
        assertLayout((90, 35), [(0, 0), (50, 0), (0, 25)], layout)
    }

    /// A3.3: start puts a run's free space after it.
    func testA3_3AlignmentStart() {
        assertLayout((82, 20), [(0, 0), (0, 10), (25, 10), (50, 10)], aligned(.start))
    }

    /// A3.3: end puts it before.
    func testA3_3AlignmentEnd() {
        assertLayout((82, 20), [(0, 0), (12, 10), (37, 10), (62, 10)], aligned(.end))
    }

    /// A3.3: center halves it.
    func testA3_3AlignmentCenter() {
        assertLayout((82, 20), [(0, 0), (6, 10), (31, 10), (56, 10)], aligned(.center))
    }

    /// A3.3: spaceBetween shares it between the children, on top of the spacing.
    func testA3_3AlignmentSpaceBetween() {
        assertLayout((82, 20), [(0, 0), (0, 10), (31, 10), (62, 10)], aligned(.spaceBetween))
    }

    /// A3.3: spaceAround gives each child a share, half of it at each end.
    func testA3_3AlignmentSpaceAround() {
        assertLayout((82, 20), [(0, 0), (2, 10), (31, 10), (60, 10)], aligned(.spaceAround))
    }

    /// A3.3: spaceEvenly makes every gap and both ends equal.
    func testA3_3AlignmentSpaceEvenly() {
        assertLayout((82, 20), [(0, 0), (3, 10), (31, 10), (59, 10)], aligned(.spaceEvenly))
    }

    /// Two runs, the first two children (exactly 100) sharing one 30 tall,
    /// the third alone 20 tall below runSpacing 4.
    private func crossAligned(_ crossAlignment: WrapCrossAlignment) -> WrapLayout {
        WrapRuns.layout(sizes([(50, 10), (50, 30), (50, 20)]),
                        minMain: 0, maxMain: 100, minCross: 0, maxCross: 200,
                        runSpacing: 4, crossAlignment: crossAlignment)
    }

    /// A3.3: cross start puts each child at the top of its run.
    func testA3_3CrossAlignmentStart() {
        assertLayout((100, 54), [(0, 0), (50, 0), (0, 34)], crossAligned(.start))
    }

    /// A3.3: cross center puts it in the middle of its run's height.
    func testA3_3CrossAlignmentCenter() {
        assertLayout((100, 54), [(0, 10), (50, 0), (0, 34)], crossAligned(.center))
    }

    /// A3.3: cross end puts it at the bottom of its run.
    func testA3_3CrossAlignmentEnd() {
        assertLayout((100, 54), [(0, 20), (50, 0), (0, 34)], crossAligned(.end))
    }

    /// A3.3: a child overshooting the run by less than Flutter's
    /// precisionErrorTolerance (1e-10) still joins it; by more, it opens a
    /// new run.
    func testA3_3AChildWithinTheBreakToleranceJoinsTheRun() {
        let within = WrapRuns.layout(sizes([(50, 10), (50.00000000005, 10)]),
                                     minMain: 0, maxMain: 100, minCross: 0, maxCross: 200)
        assertLayout((100, 10), [(0, 0), (50, 0)], within)

        let beyond = WrapRuns.layout(sizes([(50, 10), (50.000000001, 10)]),
                                     minMain: 0, maxMain: 100, minCross: 0, maxCross: 200)
        assertLayout((50.000000001, 20), [(0, 0), (0, 10)], beyond)
    }

    /// A3.3: with no main limit (a horizontal scroll view) every child stays
    /// in one run.
    func testA3_3AnUnboundedMainAxisKeepsOneRun() {
        let layout = WrapRuns.layout(sizes([(300, 10), (400, 20)]),
                                     minMain: 0, maxMain: .infinity, minCross: 0, maxCross: 200, spacing: 10)
        assertLayout((710, 20), [(0, 0), (310, 0)], layout)
    }

    /// A3.3: spaceBetween with one child in its run places it as start does.
    func testA3_3SpaceBetweenWithOneChildIsStart() {
        let layout = WrapRuns.layout(sizes([(40, 10)]), minMain: 100, maxMain: 100, minCross: 0, maxCross: 200,
                                     alignment: .spaceBetween)
        assertLayout((100, 10), [(0, 0)], layout)
    }

    /// A3.3: a parent forcing the Wrap bigger than its runs makes it that
    /// size; the runs' free space follows `alignment`, and the runs stay at
    /// the top (runAlignment start).
    func testA3_3AParentForcingItBiggerSizesItAndSharesTheFreeSpace() {
        let layout = WrapRuns.layout(sizes([(40, 10)]), minMain: 100, maxMain: 100, minCross: 50, maxCross: 50,
                                     alignment: .center)
        assertLayout((100, 50), [(30, 0)], layout)
    }

    /// A3.3: with no children the Wrap is the parent's smallest size.
    func testA3_3NoChildrenIsTheSmallestSize() {
        let layout = WrapRuns.layout([], minMain: 30, maxMain: 100, minCross: 40, maxCross: 200)
        assertLayout((30, 40), [], layout)
    }

    /// A3.3: a vertical Wrap is the same function with the axes swapped:
    /// children (width, height) 10x40, 20x40, 10x40 in 100 of height,
    /// spacing 10, runSpacing 5, go down then into a second column; the
    /// Wrap is 35 wide and 90 tall.
    func testA3_3AVerticalWrapSwapsTheAxes() {
        let widthsByHeights: [(Double, Double)] = [(10, 40), (20, 40), (10, 40)]
        let layout = WrapRuns.layout(widthsByHeights.map { WrapSize(main: $0.1, cross: $0.0) },
                                     minMain: 0, maxMain: 100, minCross: 0, maxCross: 300,
                                     spacing: 10, runSpacing: 5)
        assertLayout((90, 35), [(0, 0), (50, 0), (0, 25)], layout)
        let xy = layout.offsets.map { [$0.cross, $0.main] }
        XCTAssertEqual(xy, [[0, 0], [0, 50], [25, 0]])
    }

    /// A3.3: the builder's names: the six alignments, start by default or
    /// when unknown; cross start, end and center, anything else (stretch,
    /// baseline, unknown) start.
    func testA3_3AlignmentsParseAsTheFlutterBuilder() {
        let alignments = ["start", "end", "center", "spaceBetween", "spaceAround", "spaceEvenly"]
        XCTAssertEqual(alignments.map { WrapAlignment.of($0) }, WrapAlignment.allCases)
        XCTAssertEqual(WrapAlignment.of(nil), .start)
        XCTAssertEqual(WrapAlignment.of("stretch"), .start)
        XCTAssertEqual(["start", "end", "center"].map { WrapCrossAlignment.of($0) }, [.start, .end, .center])
        for other in [nil, "stretch", "baseline", "middle"] as [String?] {
            XCTAssertEqual(WrapCrossAlignment.of(other), .start, "cross \(String(describing: other))")
        }
    }
}
