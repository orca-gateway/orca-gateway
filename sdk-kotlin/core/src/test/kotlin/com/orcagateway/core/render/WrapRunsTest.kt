package com.orcagateway.core.render

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * A3.3: Wrap's runs and offsets against Flutter's `RenderWrap`
 * (rendering/wrap.dart: `_computeRuns`, `_RunMetrics.tryAddingNewChild`,
 * `_positionChildren`, `WrapAlignment._distributeSpace`) and the builder's
 * parsing (layout_builders.dart `_parseWrapAlignment`,
 * `_parseWrapCrossAlignment`). Sizes are (main, cross): a horizontal Wrap's
 * (width, height), a vertical one's (height, width). The same cases as
 * Swift's WrapRunsTests.
 */
class WrapRunsTest {
    private fun sizes(vararg pairs: Pair<Number, Number>): List<WrapSize> =
        pairs.map { (main, cross) -> WrapSize(main.toDouble(), cross.toDouble()) }

    private fun offsets(vararg pairs: Pair<Number, Number>): List<WrapOffset> =
        pairs.map { (main, cross) -> WrapOffset(main.toDouble(), cross.toDouble()) }

    private fun assertLayout(size: Pair<Number, Number>, offsets: List<WrapOffset>, actual: WrapLayout) {
        assertEquals(WrapSize(size.first.toDouble(), size.second.toDouble()), actual.size, "size")
        assertEquals(offsets.size, actual.offsets.size, "offset count")
        offsets.zip(actual.offsets).forEachIndexed { index, (expected, got) ->
            assertEquals(expected.main, got.main, 1e-9, "child $index main")
            assertEquals(expected.cross, got.cross, 1e-9, "child $index cross")
        }
    }

    /**
     * Four children with a run of three that leaves 12 free in a Wrap 82
     * wide (the first child, 82, fills a run alone): spacing 5.
     */
    private fun aligned(alignment: WrapAlignment): WrapLayout = WrapRuns.layout(
        sizes(82 to 10, 20 to 10, 20 to 10, 20 to 10),
        minMain = 0.0, maxMain = 100.0, minCross = 0.0, maxCross = 200.0,
        spacing = 5.0, alignment = alignment,
    )

    /** A3.3 (kt core): a child that does not fit opens a new run, spacing between children, runSpacing between runs. */
    @Test
    fun a3_3_kt_aFullRunMovesTheNextChildToANewRunWithSpacingAndRunSpacing() {
        val layout = WrapRuns.layout(
            sizes(40 to 10, 40 to 20, 40 to 10),
            minMain = 0.0, maxMain = 100.0, minCross = 0.0, maxCross = 200.0,
            spacing = 10.0, runSpacing = 5.0,
        )
        assertLayout(90 to 35, offsets(0 to 0, 50 to 0, 0 to 25), layout)
    }

    /** A3.3 (kt core): start puts a run's free space after it. */
    @Test
    fun a3_3_kt_alignmentStart() {
        assertLayout(82 to 20, offsets(0 to 0, 0 to 10, 25 to 10, 50 to 10), aligned(WrapAlignment.Start))
    }

    /** A3.3 (kt core): end puts it before. */
    @Test
    fun a3_3_kt_alignmentEnd() {
        assertLayout(82 to 20, offsets(0 to 0, 12 to 10, 37 to 10, 62 to 10), aligned(WrapAlignment.End))
    }

    /** A3.3 (kt core): center halves it. */
    @Test
    fun a3_3_kt_alignmentCenter() {
        assertLayout(82 to 20, offsets(0 to 0, 6 to 10, 31 to 10, 56 to 10), aligned(WrapAlignment.Center))
    }

    /** A3.3 (kt core): spaceBetween shares it between the children, on top of the spacing. */
    @Test
    fun a3_3_kt_alignmentSpaceBetween() {
        assertLayout(82 to 20, offsets(0 to 0, 0 to 10, 31 to 10, 62 to 10), aligned(WrapAlignment.SpaceBetween))
    }

    /** A3.3 (kt core): spaceAround gives each child a share, half of it at each end. */
    @Test
    fun a3_3_kt_alignmentSpaceAround() {
        assertLayout(82 to 20, offsets(0 to 0, 2 to 10, 31 to 10, 60 to 10), aligned(WrapAlignment.SpaceAround))
    }

    /** A3.3 (kt core): spaceEvenly makes every gap and both ends equal. */
    @Test
    fun a3_3_kt_alignmentSpaceEvenly() {
        assertLayout(82 to 20, offsets(0 to 0, 3 to 10, 31 to 10, 59 to 10), aligned(WrapAlignment.SpaceEvenly))
    }

    /**
     * Two runs, the first two children (exactly 100) sharing one 30 tall,
     * the third alone 20 tall below runSpacing 4.
     */
    private fun crossAligned(crossAlignment: WrapCrossAlignment): WrapLayout = WrapRuns.layout(
        sizes(50 to 10, 50 to 30, 50 to 20),
        minMain = 0.0, maxMain = 100.0, minCross = 0.0, maxCross = 200.0,
        runSpacing = 4.0, crossAlignment = crossAlignment,
    )

    /** A3.3 (kt core): cross start puts each child at the top of its run. */
    @Test
    fun a3_3_kt_crossAlignmentStart() {
        assertLayout(100 to 54, offsets(0 to 0, 50 to 0, 0 to 34), crossAligned(WrapCrossAlignment.Start))
    }

    /** A3.3 (kt core): cross center puts it in the middle of its run's height. */
    @Test
    fun a3_3_kt_crossAlignmentCenter() {
        assertLayout(100 to 54, offsets(0 to 10, 50 to 0, 0 to 34), crossAligned(WrapCrossAlignment.Center))
    }

    /** A3.3 (kt core): cross end puts it at the bottom of its run. */
    @Test
    fun a3_3_kt_crossAlignmentEnd() {
        assertLayout(100 to 54, offsets(0 to 20, 50 to 0, 0 to 34), crossAligned(WrapCrossAlignment.End))
    }

    /**
     * A3.3 (kt core): a child overshooting the run by less than Flutter's
     * precisionErrorTolerance (1e-10) still joins it; by more, it opens a
     * new run.
     */
    @Test
    fun a3_3_kt_aChildWithinTheBreakToleranceJoinsTheRun() {
        val within = WrapRuns.layout(
            sizes(50 to 10, 50.00000000005 to 10),
            minMain = 0.0, maxMain = 100.0, minCross = 0.0, maxCross = 200.0,
        )
        assertLayout(100 to 10, offsets(0 to 0, 50 to 0), within)

        val beyond = WrapRuns.layout(
            sizes(50 to 10, 50.000000001 to 10),
            minMain = 0.0, maxMain = 100.0, minCross = 0.0, maxCross = 200.0,
        )
        assertLayout(50.000000001 to 20, offsets(0 to 0, 0 to 10), beyond)
    }

    /** A3.3 (kt core): with no main limit (a horizontal scroll view) every child stays in one run. */
    @Test
    fun a3_3_kt_anUnboundedMainAxisKeepsOneRun() {
        val layout = WrapRuns.layout(
            sizes(300 to 10, 400 to 20),
            minMain = 0.0, maxMain = Double.POSITIVE_INFINITY, minCross = 0.0, maxCross = 200.0,
            spacing = 10.0,
        )
        assertLayout(710 to 20, offsets(0 to 0, 310 to 0), layout)
    }

    /** A3.3 (kt core): spaceBetween with one child in its run places it as start does. */
    @Test
    fun a3_3_kt_spaceBetweenWithOneChildIsStart() {
        val layout = WrapRuns.layout(
            sizes(40 to 10),
            minMain = 100.0, maxMain = 100.0, minCross = 0.0, maxCross = 200.0,
            alignment = WrapAlignment.SpaceBetween,
        )
        assertLayout(100 to 10, offsets(0 to 0), layout)
    }

    /**
     * A3.3 (kt core): a parent forcing the Wrap bigger than its runs makes
     * it that size; the runs' free space follows `alignment`, and the runs
     * stay at the top (runAlignment start).
     */
    @Test
    fun a3_3_kt_aParentForcingItBiggerSizesItAndSharesTheFreeSpace() {
        val layout = WrapRuns.layout(
            sizes(40 to 10),
            minMain = 100.0, maxMain = 100.0, minCross = 50.0, maxCross = 50.0,
            alignment = WrapAlignment.Center,
        )
        assertLayout(100 to 50, offsets(30 to 0), layout)
    }

    /** A3.3 (kt core): with no children the Wrap is the parent's smallest size. */
    @Test
    fun a3_3_kt_noChildrenIsTheSmallestSize() {
        val layout = WrapRuns.layout(emptyList(), minMain = 30.0, maxMain = 100.0, minCross = 40.0, maxCross = 200.0)
        assertLayout(30 to 40, offsets(), layout)
    }

    /**
     * A3.3 (kt core): a vertical Wrap is the same function with the axes
     * swapped: children (width, height) 10x40, 20x40, 10x40 in 100 of
     * height, spacing 10, runSpacing 5, go down then into a second column;
     * the Wrap is 35 wide and 90 tall.
     */
    @Test
    fun a3_3_kt_aVerticalWrapSwapsTheAxes() {
        val widthsByHeights = listOf(10 to 40, 20 to 40, 10 to 40)
        val layout = WrapRuns.layout(
            widthsByHeights.map { (width, height) -> WrapSize(main = height.toDouble(), cross = width.toDouble()) },
            minMain = 0.0, maxMain = 100.0, minCross = 0.0, maxCross = 300.0,
            spacing = 10.0, runSpacing = 5.0,
        )
        assertLayout(90 to 35, offsets(0 to 0, 50 to 0, 0 to 25), layout)
        val xy = layout.offsets.map { it.cross to it.main }
        assertEquals(listOf(0.0 to 0.0, 0.0 to 50.0, 25.0 to 0.0), xy)
    }

    /**
     * A3.3 (kt core): the builder's names: the six alignments, start by
     * default or when unknown; cross start, end and center, anything else
     * (stretch, baseline, unknown) start.
     */
    @Test
    fun a3_3_kt_alignmentsParseAsTheFlutterBuilder() {
        val alignments = listOf("start", "end", "center", "spaceBetween", "spaceAround", "spaceEvenly")
        assertEquals(WrapAlignment.entries.toList(), alignments.map { WrapAlignment.of(it) })
        assertEquals(WrapAlignment.Start, WrapAlignment.of(null))
        assertEquals(WrapAlignment.Start, WrapAlignment.of("stretch"))
        assertEquals(
            listOf(WrapCrossAlignment.Start, WrapCrossAlignment.End, WrapCrossAlignment.Center),
            listOf("start", "end", "center").map { WrapCrossAlignment.of(it) },
        )
        for (other in listOf(null, "stretch", "baseline", "middle")) {
            assertEquals(WrapCrossAlignment.Start, WrapCrossAlignment.of(other), "cross $other")
        }
    }
}
