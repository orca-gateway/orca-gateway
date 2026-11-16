package com.orcagateway.core.render

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * The two pure helpers behind CustomScrollView (design brief
 * native-parity-s13-slivers, V1 and V3).
 *
 * C-items-K: [SliverItems] flattens a CustomScrollView's direct children
 * into the lazy items of one scroll view, as Flutter's builders nest them
 * (structure_builders.dart `_buildCustomScrollView` and the four sliver
 * builders).
 *
 * C-geo-K: [SliverAppBarGeometry] against the numbers Flutter draws: the
 * table `barCases` of sdk/test/sliver_widgets_test.dart, every case and
 * row in order, copied below. Viewport 800 x 600, toolbar 56, content far
 * taller than the viewport. The Swift core pins the same two tables.
 */
class SliverCoreTest {
    // ── C-items-K ───────────────────────────────────────────────────────────

    private fun node(id: String, type: String, children: List<String> = emptyList(), props: Map<String, JsonValue> = emptyMap()) =
        ResolvedNode(id, type, ComponentNode.Kind.Layout, props, children, emptyMap(), emptyMap(), emptyList())

    /** C-items-K: a SliverList is one box per child, in order, keyed by the child's id. */
    @Test
    fun c_items_k_listIsOneBoxPerChild() {
        val got = SliverItems.of(listOf(node("list", "SliverList", listOf("a", "b", "c"))))
        assertEquals(listOf<SliverItem>(SliverItem.Box("a"), SliverItem.Box("b"), SliverItem.Box("c")), got.items)
        assertEquals(listOf("a", "b", "c"), got.items.map { it.key })
        assertNull(got.collapsingBarId)
    }

    /** C-items-K: a SliverGrid is one item per line: 5 cells at 2 across are 3 lines, the last with 1 cell and no spacing after it. */
    @Test
    fun c_items_k_gridIsOneItemPerLine() {
        val grid = node("grid", "SliverGrid", listOf("c0", "c1", "c2", "c3", "c4"), mapOf("crossAxisCount" to JsonValue.Int(2)))
        assertEquals(
            listOf<SliverItem>(
                SliverItem.GridLine("grid", 0, listOf("c0", "c1"), isLast = false),
                SliverItem.GridLine("grid", 1, listOf("c2", "c3"), isLast = false),
                SliverItem.GridLine("grid", 2, listOf("c4"), isLast = true),
            ),
            SliverItems.of(listOf(grid)).items,
        )
    }

    /** C-items-K: 3 across (a whole number sent as a double too) fills whole lines; a grid of none has no item. */
    @Test
    fun c_items_k_gridCountsAcross() {
        val six = listOf("c0", "c1", "c2", "c3", "c4", "c5")
        for (count in listOf<JsonValue>(JsonValue.Int(3), JsonValue.Double(3.0))) {
            assertEquals(
                listOf<SliverItem>(
                    SliverItem.GridLine("grid", 0, listOf("c0", "c1", "c2"), isLast = false),
                    SliverItem.GridLine("grid", 1, listOf("c3", "c4", "c5"), isLast = true),
                ),
                SliverItems.of(listOf(node("grid", "SliverGrid", six, mapOf("crossAxisCount" to count)))).items,
                "$count",
            )
        }
        assertEquals(emptyList(), SliverItems.of(listOf(node("grid", "SliverGrid"))).items)
    }

    /** C-items-K: crossAxisCount absent (or JSON null) is 2; below 1 is 1, as GridCells. */
    @Test
    fun c_items_k_gridCrossAxisCountAbsentOrBelowOne() {
        val cells = listOf("c0", "c1", "c2")
        val two = listOf<SliverItem>(
            SliverItem.GridLine("grid", 0, listOf("c0", "c1"), isLast = false),
            SliverItem.GridLine("grid", 1, listOf("c2"), isLast = true),
        )
        assertEquals(two, SliverItems.of(listOf(node("grid", "SliverGrid", cells))).items)
        assertEquals(two, SliverItems.of(listOf(node("grid", "SliverGrid", cells, mapOf("crossAxisCount" to JsonValue.Null)))).items)
        for (count in listOf(0L, -3L)) {
            assertEquals(
                listOf<SliverItem>(
                    SliverItem.GridLine("grid", 0, listOf("c0"), isLast = false),
                    SliverItem.GridLine("grid", 1, listOf("c1"), isLast = false),
                    SliverItem.GridLine("grid", 2, listOf("c2"), isLast = true),
                ),
                SliverItems.of(listOf(node("grid", "SliverGrid", cells, mapOf("crossAxisCount" to JsonValue.Int(count))))).items,
                "crossAxisCount $count",
            )
        }
    }

    /** C-items-K: a SliverToBoxAdapter is its (first) child as a box; without a child it is no item. */
    @Test
    fun c_items_k_adapterWithAndWithoutChild() {
        val got = SliverItems.of(
            listOf(
                node("empty", "SliverToBoxAdapter"),
                node("adapter", "SliverToBoxAdapter", listOf("first")),
                node("two", "SliverToBoxAdapter", listOf("x", "y")),
            ),
        )
        assertEquals(listOf<SliverItem>(SliverItem.Box("first"), SliverItem.Box("x")), got.items)
    }

    /** C-items-K: a SliverAppBar that is the first direct child is a bar item and the collapsing bar. */
    @Test
    fun c_items_k_barFirstIsTheCollapsingBar() {
        val got = SliverItems.of(
            listOf(node("bar", "SliverAppBar", listOf("bar_title")), node("list", "SliverList", listOf("a"))),
        )
        assertEquals(listOf<SliverItem>(SliverItem.Bar("bar"), SliverItem.Box("a")), got.items)
        assertEquals("bar", got.collapsingBarId)
    }

    /** C-items-K: a SliverAppBar anywhere else is a bar item, but none collapses (it scrolls as a box). */
    @Test
    fun c_items_k_barNotFirstDoesNotCollapse() {
        val got = SliverItems.of(
            listOf(
                node("adapter", "SliverToBoxAdapter", listOf("first")),
                node("bar", "SliverAppBar"),
                node("bar2", "SliverAppBar"),
            ),
        )
        assertEquals(listOf<SliverItem>(SliverItem.Box("first"), SliverItem.Bar("bar"), SliverItem.Bar("bar2")), got.items)
        assertNull(got.collapsingBarId)
        // An adapter with no child before the bar is still the first direct child.
        assertNull(SliverItems.of(listOf(node("empty", "SliverToBoxAdapter"), node("bar", "SliverAppBar"))).collapsingBarId)
        assertNull(SliverItems.of(emptyList()).collapsingBarId)
    }

    /** C-items-K: any other widget as a direct child is a box of its own id (Flutter throws; we draw it). */
    @Test
    fun c_items_k_strayWidgetIsABox() {
        val got = SliverItems.of(
            listOf(node("text", "Text"), node("column", "Column", listOf("x", "y")), node("list", "SliverList", listOf("a"))),
        )
        assertEquals(listOf<SliverItem>(SliverItem.Box("text"), SliverItem.Box("column"), SliverItem.Box("a")), got.items)
    }

    /** C-items-K: keys are the node id, or the grid id and the line index; unique, and the same on every pass. */
    @Test
    fun c_items_k_keysAreStable() {
        val page = listOf(
            node("bar", "SliverAppBar"),
            node("adapter", "SliverToBoxAdapter", listOf("first")),
            node("grid", "SliverGrid", listOf("c0", "c1", "c2", "c3", "c4"), mapOf("crossAxisCount" to JsonValue.Int(3))),
            node("list", "SliverList", listOf("r0", "r1")),
            node("stray", "Text"),
        )
        val keys = SliverItems.of(page).items.map { it.key }
        assertEquals(listOf("bar", "first", "grid#0", "grid#1", "r0", "r1", "stray"), keys)
        assertEquals(keys.size, keys.toSet().size)
        assertEquals(keys, SliverItems.of(page).items.map { it.key })
        // A row added to the list leaves every other key as it was.
        val longer = page.map { if (it.id == "list") node("list", "SliverList", listOf("r0", "r1", "r2")) else it }
        assertEquals(listOf("bar", "first", "grid#0", "grid#1", "r0", "r1", "r2", "stray"), SliverItems.of(longer).items.map { it.key })
    }

    /** C-items-K: the scroll view's children are found through the lookup, in order; an id the lookup does not know is skipped. */
    @Test
    fun c_items_k_childrenThroughALookup() {
        val nodes = listOf(
            node("scroll", "CustomScrollView", listOf("bar", "gone", "list")),
            node("bar", "SliverAppBar"),
            node("list", "SliverList", listOf("a", "b")),
        ).associateBy { it.id }
        val got = SliverItems.of(nodes.getValue("scroll")) { nodes[it] }
        assertEquals(listOf<SliverItem>(SliverItem.Bar("bar"), SliverItem.Box("a"), SliverItem.Box("b")), got.items)
        assertEquals("bar", got.collapsingBarId)
    }

    // ── C-geo-K ─────────────────────────────────────────────────────────────

    /** One row of Flutter's table: drag to [offset] (or, [released], lift the finger there) and read the bar. */
    private data class At(
        val offset: Double,
        val paint: Double,
        val layout: Double,
        val box: Double,
        val opacity: Double,
        val released: Boolean = false,
    )

    private fun at(offset: Number, paint: Number, layout: Number, box: Number, opacity: Number) =
        At(offset.toDouble(), paint.toDouble(), layout.toDouble(), box.toDouble(), opacity.toDouble())

    private fun rel(offset: Number, paint: Number, layout: Number, box: Number, opacity: Number) =
        at(offset, paint, layout, box, opacity).copy(released = true)

    private data class BarCase(
        val name: String,
        val pinned: Boolean = false,
        val floating: Boolean = false,
        val snap: Boolean = false,
        val expandedHeight: Double? = null,
        val collapsedHeight: Double? = null,
        val topPadding: Double = 0.0,
        val rows: List<At>,
    )

    /** sdk/test/sliver_widgets_test.dart `barCases`, the same cases and rows in the same order. */
    private val barCases = listOf(
        // expandedHeight 200
        BarCase(
            "neither, expanded 200", expandedHeight = 200.0,
            rows = listOf(at(0, 200, 200, 200, 1), at(100, 100, 100, 100, 1), at(600, 0, 0, 56, 0), at(580, 0, 0, 56, 0)),
        ),
        BarCase(
            "pinned, expanded 200", pinned = true, expandedHeight = 200.0,
            rows = listOf(at(0, 200, 200, 200, 1), at(100, 100, 100, 100, 1), at(600, 56, 0, 56, 1), at(580, 56, 0, 56, 1)),
        ),
        BarCase(
            "floating, expanded 200", floating = true, expandedHeight = 200.0,
            rows = listOf(
                at(0, 200, 200, 200, 1),
                at(100, 100, 100, 100, 1),
                at(600, 0, 0, 56, 0),
                at(580, 20, 0, 56, 0.3571),
                at(500, 100, 0, 100, 1),
                at(520, 80, 0, 80, 1),
                rel(520, 80, 0, 80, 1),
            ),
        ),
        BarCase(
            "floating + pinned, expanded 200", floating = true, pinned = true, expandedHeight = 200.0,
            rows = listOf(
                at(0, 200, 200, 200, 1),
                at(100, 100, 100, 100, 1),
                at(600, 56, 0, 56, 1),
                at(580, 56, 0, 56, 1),
                at(500, 100, 0, 100, 1),
                at(520, 80, 0, 80, 1),
            ),
        ),
        // no expandedHeight (the bar is the toolbar: 56)
        BarCase(
            "neither, no expanded",
            rows = listOf(at(0, 56, 56, 56, 1), at(30, 26, 26, 56, 0.4643), at(600, 0, 0, 56, 0), at(580, 0, 0, 56, 0)),
        ),
        BarCase(
            "pinned, no expanded", pinned = true,
            rows = listOf(at(0, 56, 56, 56, 1), at(30, 56, 26, 56, 1), at(600, 56, 0, 56, 1), at(580, 56, 0, 56, 1)),
        ),
        BarCase(
            "floating, no expanded", floating = true,
            rows = listOf(
                at(0, 56, 56, 56, 1),
                at(30, 26, 26, 56, 0.4643),
                at(600, 0, 0, 56, 0),
                at(580, 20, 0, 56, 0.3571),
                at(500, 56, 0, 56, 1),
                at(520, 36, 0, 56, 0.6429),
            ),
        ),
        BarCase(
            "floating + pinned, no expanded", floating = true, pinned = true,
            rows = listOf(at(0, 56, 56, 56, 1), at(30, 56, 26, 56, 1), at(600, 56, 0, 56, 1), at(580, 56, 0, 56, 1)),
        ),
        // collapsedHeight 80
        BarCase(
            "neither, expanded 200, collapsed 80", expandedHeight = 200.0, collapsedHeight = 80.0,
            rows = listOf(at(0, 200, 200, 200, 1), at(100, 100, 100, 100, 1), at(150, 50, 50, 80, 0.4643), at(600, 0, 0, 80, 0)),
        ),
        BarCase(
            "pinned, expanded 200, collapsed 80", pinned = true, expandedHeight = 200.0, collapsedHeight = 80.0,
            rows = listOf(at(0, 200, 200, 200, 1), at(100, 100, 100, 100, 1), at(150, 80, 50, 80, 1), at(600, 80, 0, 80, 1)),
        ),
        BarCase(
            "floating + pinned, expanded 200, collapsed 80",
            floating = true, pinned = true, expandedHeight = 200.0, collapsedHeight = 80.0,
            rows = listOf(at(0, 200, 200, 200, 1), at(600, 80, 0, 80, 1), at(580, 80, 0, 80, 1), at(500, 100, 0, 100, 1)),
        ),
        BarCase(
            "pinned, no expanded, collapsed 80", pinned = true, collapsedHeight = 80.0,
            rows = listOf(at(0, 80, 80, 80, 1), at(600, 80, 0, 80, 1)),
        ),
        BarCase(
            "neither, no expanded, collapsed 80", collapsedHeight = 80.0,
            rows = listOf(at(0, 80, 80, 80, 1), at(30, 50, 50, 80, 0.4643), at(600, 0, 0, 80, 0)),
        ),
        // snap (floating + snap): the bar settles when the scroll ends
        BarCase(
            "floating + snap, expanded 200", floating = true, snap = true, expandedHeight = 200.0,
            rows = listOf(
                at(0, 200, 200, 200, 1),
                at(600, 0, 0, 56, 0),
                at(580, 20, 0, 56, 0.3571),
                rel(580, 200, 0, 200, 1),
                at(600, 180, 0, 180, 1),
                rel(600, 0, 0, 56, 0),
            ),
        ),
        BarCase(
            "floating + pinned + snap, expanded 200", floating = true, pinned = true, snap = true, expandedHeight = 200.0,
            rows = listOf(
                at(0, 200, 200, 200, 1),
                at(600, 56, 0, 56, 1),
                at(580, 56, 0, 56, 1),
                rel(580, 200, 0, 200, 1),
                at(600, 180, 0, 180, 1),
                rel(600, 56, 0, 56, 1),
            ),
        ),
        // top padding 24 (the bar reaches under the status bar)
        BarCase(
            "neither, expanded 200, top padding 24", expandedHeight = 200.0, topPadding = 24.0,
            rows = listOf(at(0, 224, 224, 224, 1), at(100, 124, 124, 124, 1), at(600, 0, 0, 80, 0), at(580, 0, 0, 80, 0)),
        ),
        BarCase(
            "pinned, expanded 200, top padding 24", pinned = true, expandedHeight = 200.0, topPadding = 24.0,
            rows = listOf(at(0, 224, 224, 224, 1), at(100, 124, 124, 124, 1), at(600, 80, 0, 80, 1), at(580, 80, 0, 80, 1)),
        ),
        BarCase(
            "floating, expanded 200, top padding 24", floating = true, expandedHeight = 200.0, topPadding = 24.0,
            rows = listOf(
                at(0, 224, 224, 224, 1),
                at(100, 124, 124, 124, 1),
                at(600, 0, 0, 80, 0),
                at(580, 20, 0, 80, 0),
                at(500, 100, 0, 100, 1),
            ),
        ),
        BarCase(
            "floating + pinned, expanded 200, top padding 24",
            floating = true, pinned = true, expandedHeight = 200.0, topPadding = 24.0,
            rows = listOf(
                at(0, 224, 224, 224, 1),
                at(100, 124, 124, 124, 1),
                at(600, 80, 0, 80, 1),
                at(580, 80, 0, 80, 1),
                at(500, 100, 0, 100, 1),
            ),
        ),
        BarCase(
            "pinned, no expanded, top padding 24", pinned = true, topPadding = 24.0,
            rows = listOf(at(0, 80, 80, 80, 1), at(600, 80, 0, 80, 1)),
        ),
        BarCase(
            "pinned, expanded 200, collapsed 80, top padding 24",
            pinned = true, expandedHeight = 200.0, collapsedHeight = 80.0, topPadding = 24.0,
            rows = listOf(at(0, 224, 224, 224, 1), at(600, 104, 0, 104, 1)),
        ),
    )

    private fun geometry(case: BarCase) = SliverAppBarGeometry(
        pinned = case.pinned,
        floating = case.floating,
        snap = case.snap,
        expandedHeight = case.expandedHeight,
        collapsedHeight = case.collapsedHeight,
        topPadding = case.topPadding,
    )

    /** C-geo-K: every row of Flutter's table, each case run in order on one bar (a floating bar depends on its history). */
    @Test
    fun c_geo_k_everyRowOfFluttersTable() {
        assertEquals(21, barCases.size)
        for (case in barCases) {
            val bar = geometry(case)
            case.rows.forEachIndexed { index, row ->
                val frame = if (row.released) bar.released() else bar.scrollTo(row.offset)
                val label = "${case.name}, row $index ($row)"
                assertEquals(row.paint, frame.paint, DELTA, "$label paint")
                assertEquals(row.layout, frame.layout, DELTA, "$label layout")
                assertEquals(row.box, frame.box, DELTA, "$label box")
                assertEquals(row.opacity, frame.toolbarOpacity, DELTA, "$label opacity")
            }
        }
    }

    /** C-geo-K: minExtent is collapsedHeight (else the toolbar) plus the top padding; maxExtent the padded expandedHeight, never below it. */
    @Test
    fun c_geo_k_extents() {
        fun extents(expanded: Double? = null, collapsed: Double? = null, top: Double = 0.0) =
            SliverAppBarGeometry(expandedHeight = expanded, collapsedHeight = collapsed, topPadding = top).let { it.minExtent to it.maxExtent }
        assertEquals(56.0 to 56.0, extents())
        assertEquals(56.0 to 200.0, extents(expanded = 200.0))
        assertEquals(80.0 to 200.0, extents(expanded = 200.0, collapsed = 80.0))
        assertEquals(80.0 to 80.0, extents(collapsed = 80.0))
        assertEquals(80.0 to 224.0, extents(expanded = 200.0, top = 24.0))
        assertEquals(104.0 to 224.0, extents(expanded = 200.0, collapsed = 80.0, top = 24.0))
        // An expandedHeight below the collapsed one: the bar never shrinks.
        assertEquals(80.0 to 80.0, extents(expanded = 40.0, collapsed = 80.0))
    }

    /** C-geo-K: a release moves only a floating bar with snap, and only after a scroll; twice is once. */
    @Test
    fun c_geo_k_releaseWithoutSnapOrScrollStays() {
        val plain = SliverAppBarGeometry(floating = true, expandedHeight = 200.0)
        plain.scrollTo(600.0)
        val shown = plain.scrollTo(580.0)
        assertEquals(shown, plain.released())

        // snap without floating is not a snap bar (Flutter makes no snap configuration).
        val notFloating = SliverAppBarGeometry(snap = true, expandedHeight = 200.0)
        assertEquals(notFloating.scrollTo(100.0), notFloating.released())

        val snap = SliverAppBarGeometry(floating = true, snap = true, expandedHeight = 200.0)
        assertEquals(SliverAppBarFrame(200.0, 200.0, 200.0, 1.0), snap.released())
        snap.scrollTo(600.0)
        snap.scrollTo(580.0)
        val open = snap.released()
        assertEquals(SliverAppBarFrame(200.0, 0.0, 200.0, 1.0), open)
        assertEquals(open, snap.released())
        assertEquals(open, snap.frame)
        assertEquals(580.0, snap.offset)
        assertEquals(0.0, snap.effectiveOffset)
        // Scrolling on from the snapped state shrinks the open bar.
        assertEquals(190.0, snap.scrollTo(590.0).paint, DELTA)
    }

    /**
     * C-geo-K: a snap bar let go near the top cannot close further than the
     * view has scrolled: Flutter's layout keeps the effective offset within
     * 0 .. scroll offset (sliver_persistent_header.dart performLayout), so
     * the part that still pushes the content stays drawn.
     */
    @Test
    fun c_geo_k_snapNearTheTopStaysWithinTheScrollOffset() {
        val snap = SliverAppBarGeometry(floating = true, snap = true, expandedHeight = 200.0)
        snap.scrollTo(0.0)
        val partly = snap.scrollTo(50.0)
        assertEquals(SliverAppBarFrame(150.0, 150.0, 150.0, 1.0), partly)
        assertEquals(partly, snap.released())
    }

    /**
     * C-geo-K: a collapsedHeight below the toolbar's, and a negative top
     * padding, are taken as given: `_SliverAppBarDelegate.minExtent` is
     * `collapsedHeight` fed raw (app_bar.dart; the `>= toolbarHeight` check
     * is a debug assert).
     */
    @Test
    fun c_geo_k_collapsedHeightBelowTheToolbarAndNegativeTopPadding() {
        val bar = SliverAppBarGeometry(pinned = true, expandedHeight = 200.0, collapsedHeight = 40.0)
        assertEquals(40.0 to 200.0, bar.minExtent to bar.maxExtent)
        assertEquals(SliverAppBarFrame(200.0, 200.0, 200.0, 1.0), bar.scrollTo(0.0))
        assertEquals(SliverAppBarFrame(40.0, 0.0, 40.0, 1.0), bar.scrollTo(600.0))

        val under = SliverAppBarGeometry(expandedHeight = 200.0, topPadding = -10.0)
        assertEquals(46.0 to 190.0, under.minExtent to under.maxExtent)
    }

    /**
     * C-geo-K: effectiveOffset as Flutter keeps it: a bar that does not
     * float has the scroll offset there; a floating bar gone past its far
     * edge keeps the scroll offset through a release that closes it.
     */
    @Test
    fun c_geo_k_effectiveOffset() {
        val plain = SliverAppBarGeometry(expandedHeight = 200.0)
        assertEquals(0.0, plain.effectiveOffset)
        listOf(0.0, 600.0, 580.0).forEach { plain.scrollTo(it) }
        assertEquals(580.0, plain.effectiveOffset)

        val snap = SliverAppBarGeometry(floating = true, snap = true, expandedHeight = 200.0)
        listOf(0.0, 600.0, 620.0).forEach { snap.scrollTo(it) }
        assertEquals(620.0, snap.effectiveOffset)
        assertEquals(SliverAppBarFrame(0.0, 0.0, 56.0, 0.0), snap.released())
        assertEquals(620.0, snap.effectiveOffset)
        // Back toward the start, the bar comes in from its far edge.
        assertEquals(20.0, snap.scrollTo(600.0).paint, DELTA)
        assertEquals(180.0, snap.effectiveOffset)
        assertEquals(200.0, snap.released().paint, DELTA)
        assertEquals(0.0, snap.effectiveOffset)
    }

    private companion object {
        const val DELTA = 0.0001
    }
}
