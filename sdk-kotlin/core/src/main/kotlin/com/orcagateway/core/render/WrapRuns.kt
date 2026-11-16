package com.orcagateway.core.render

import kotlin.math.max

/**
 * Flutter `WrapAlignment`: where a run's free main-axis space goes, read by
 * the builder's `_parseWrapAlignment` (start when missing or unknown).
 */
public enum class WrapAlignment(public val wire: String) {
    Start("start"),
    End("end"),
    Center("center"),
    SpaceBetween("spaceBetween"),
    SpaceAround("spaceAround"),
    SpaceEvenly("spaceEvenly"),
    ;

    /**
     * Flutter `WrapAlignment._distributeSpace`, not flipped: the space
     * before a run's first child and between two children, out of [free]
     * for [count] children. spaceBetween with one child is start.
     */
    internal fun distribute(free: Double, spacing: Double, count: Int): Pair<Double, Double> = when (this) {
        Start -> 0.0 to spacing
        End -> free to spacing
        Center -> free / 2 to spacing
        SpaceBetween -> if (count < 2) 0.0 to spacing else 0.0 to free / (count - 1) + spacing
        SpaceAround -> free / count / 2 to free / count + spacing
        SpaceEvenly -> free / (count + 1) to free / (count + 1) + spacing
    }

    public companion object {
        public fun of(value: String?): WrapAlignment = entries.firstOrNull { it.wire == value } ?: Start
    }
}

/**
 * Flutter `WrapCrossAlignment`: where a child sits in its run's cross
 * extent, read by the builder's `_parseWrapCrossAlignment` (stretch,
 * baseline and anything else are start).
 */
public enum class WrapCrossAlignment(public val wire: String, internal val factor: Double) {
    Start("start", 0.0),
    End("end", 1.0),
    Center("center", 0.5),
    ;

    public companion object {
        public fun of(value: String?): WrapCrossAlignment = entries.firstOrNull { it.wire == value } ?: Start
    }
}

/** A size along a Wrap's axes: a horizontal Wrap's (width, height), a vertical one's (height, width). */
public data class WrapSize(public val main: Double, public val cross: Double)

/** A child's offset from the Wrap's origin along its axes. */
public data class WrapOffset(public val main: Double, public val cross: Double)

/** The Wrap's own size and each child's offset, in the children's order. */
public data class WrapLayout(public val size: WrapSize, public val offsets: List<WrapOffset>)

/**
 * Flutter `RenderWrap`'s layout (rendering/wrap.dart `performLayout`,
 * `_computeRuns`, `_positionChildren`) for a Wrap that is left to right and
 * top down with runAlignment start, as the Flutter builder makes it, in
 * any one unit. A vertical Wrap is the same with the axes swapped; the
 * caller lays each child out loosely first (main axis up to the incoming
 * maximum, cross axis unbounded) and passes its size.
 */
public object WrapRuns {
    /** Flutter's `precisionErrorTolerance`: a child overshooting a run by no more than this still joins it. */
    public const val PRECISION_ERROR_TOLERANCE: Double = 1e-10

    /**
     * Breaks [children] into runs no longer than [maxMain] (which may be
     * infinite), [spacing] between the children of a run and [runSpacing]
     * between runs. The Wrap hugs its widest run and the runs' summed cross
     * extents, brought within [minMain]..[maxMain] and
     * [minCross]..[maxCross]; with no children it is the smallest size. In
     * each run [alignment] shares the free main-axis space and
     * [crossAlignment] places each child in the run's cross extent.
     */
    public fun layout(
        children: List<WrapSize>,
        minMain: Double,
        maxMain: Double,
        minCross: Double,
        maxCross: Double,
        spacing: Double = 0.0,
        runSpacing: Double = 0.0,
        alignment: WrapAlignment = WrapAlignment.Start,
        crossAlignment: WrapCrossAlignment = WrapCrossAlignment.Start,
    ): WrapLayout {
        if (children.isEmpty()) return WrapLayout(WrapSize(minMain, minCross), emptyList())

        val runs = ArrayList<Run>()
        var current: Run? = null
        for ((index, child) in children.withIndex()) {
            val run = current
            if (run == null || run.main + spacing + child.main - maxMain > PRECISION_ERROR_TOLERANCE) {
                current = Run(index, child.main, child.cross).also { runs += it }
            } else {
                run.main += spacing + child.main
                run.cross = max(run.cross, child.cross)
                run.count += 1
            }
        }

        val childrenMain = runs.maxOf { it.main }
        val childrenCross = runs.sumOf { it.cross } + runSpacing * (runs.size - 1)
        val size = WrapSize(childrenMain.coerceIn(minMain, maxMain), childrenCross.coerceIn(minCross, maxCross))

        val offsets = ArrayList<WrapOffset>(children.size)
        var runCross = 0.0
        for (run in runs) {
            val free = max(0.0, size.main - run.main)
            val (leading, between) = alignment.distribute(free, spacing, run.count)
            var main = leading
            for (index in run.first until run.first + run.count) {
                val child = children[index]
                offsets += WrapOffset(main, runCross + crossAlignment.factor * (run.cross - child.cross))
                main += child.main + between
            }
            runCross += run.cross + runSpacing
        }
        return WrapLayout(size, offsets)
    }

    /** Flutter `_RunMetrics`: a run's first child, its children, and its extent with the spacings. */
    private class Run(val first: Int, var main: Double, var cross: Double) {
        var count = 1
    }
}
