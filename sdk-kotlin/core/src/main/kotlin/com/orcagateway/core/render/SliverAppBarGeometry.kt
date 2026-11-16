package com.orcagateway.core.render

import kotlin.math.max
import kotlin.math.min

/**
 * What a SliverAppBar draws at one scroll offset, in logical pixels.
 *
 * - [paint]: how much of the bar is on screen, from the top of the scroll
 *   view (Flutter's `SliverGeometry.paintExtent`).
 * - [layout]: how far the bar pushes the content below it,
 *   max(0, maxExtent - offset); below [paint] when the bar lies over the
 *   content (pinned, or floated back in).
 * - [box]: the height of the bar's own box (background, flexibleSpace).
 *   Its bottom edge sits at [paint], so with box > paint its top is cut
 *   off above the view.
 * - [toolbarOpacity]: the opacity of the toolbar row.
 */
public data class SliverAppBarFrame(
    public val paint: Double,
    public val layout: Double,
    public val box: Double,
    public val toolbarOpacity: Double,
)

/**
 * The maths of one SliverAppBar that is the first sliver of a vertical
 * scroll view, so the view holds none: Flutter's `_SliverAppBarDelegate`
 * and `_SliverAppBarState` (material app_bar.dart, no `bottom`) over the
 * four render objects of rendering/sliver_persistent_header.dart:
 * scrolling (neither flag), [pinned], [floating], and both. [snap] counts
 * only with [floating], as in Flutter.
 *
 * It keeps what a floating bar needs between scrolls (the effective
 * scroll offset Flutter keeps, the last offset and the last direction),
 * so make one per bar, feed it every scroll offset in order with
 * [scrollTo], and call [released] when the scroll ends. The viewport is
 * taken to be taller than the bar. The numbers are pinned by Flutter's
 * widget test (sdk/test/sliver_widgets_test.dart `barCases`); the Swift
 * twin (`SliverAppBarGeometry.swift`) pins the same table.
 */
public class SliverAppBarGeometry(
    public val pinned: Boolean = false,
    public val floating: Boolean = false,
    public val snap: Boolean = false,
    public val expandedHeight: Double? = null,
    public val collapsedHeight: Double? = null,
    /** The safe-area top inset the bar reaches under, Flutter's `MediaQuery.padding.top`. */
    public val topPadding: Double = 0.0,
    public val toolbarHeight: Double = TOOLBAR_HEIGHT,
) {
    /** The bar fully collapsed: `collapsedHeight` (else the toolbar) plus the top padding. */
    public val minExtent: Double = (collapsedHeight ?: toolbarHeight) + topPadding

    /** The bar fully open: `expandedHeight` (else the toolbar) plus the top padding, never below [minExtent]. */
    public val maxExtent: Double = max(topPadding + (expandedHeight ?: toolbarHeight), minExtent)

    /** The scroll offset of the last [scrollTo]; 0 before the first. */
    public var offset: Double = 0.0
        private set

    /**
     * How far a floating bar is scrolled away, Flutter's
     * `_effectiveOffset`: 0 fully open, [maxExtent] or more gone,
     * never past the scroll offset. A bar that does not float has the
     * scroll offset here.
     */
    public var effectiveOffset: Double = 0.0
        private set

    /** The last scroll went back toward the start (Flutter's ScrollDirection.forward); null before any, and once [released]. */
    private var towardStart: Boolean? = null

    /**
     * The bar with the view scrolled to [offset] (negative, an overscroll,
     * is 0). A floating bar goes by the change since the last call: it
     * comes back in as the offset falls and leaves as it grows.
     */
    public fun scrollTo(offset: Double): SliverAppBarFrame {
        val now = max(offset, 0.0)
        val last = this.offset
        if (!floating) {
            effectiveOffset = now
        } else if (now < last || effectiveOffset < maxExtent) {
            // Coming back from off screen starts at the bar's far edge.
            if (now < last && effectiveOffset > maxExtent) effectiveOffset = maxExtent
            effectiveOffset = (effectiveOffset - (last - now)).coerceIn(0.0, now)
        } else {
            effectiveOffset = now
        }
        if (now != last) towardStart = now < last
        this.offset = now
        return frame
    }

    /**
     * The bar once the scroll has ended, the scroll offset unchanged. Only
     * a floating bar with [snap] moves: fully open when the last scroll
     * went back toward the start, fully closed when it went on (Flutter's
     * `maybeStartSnapAnimation`; a UI animates to it, Flutter over 200 ms
     * ease-out), and never further closed than the view has scrolled.
     */
    public fun released(): SliverAppBarFrame {
        val open = towardStart
        if (floating && snap && open != null) {
            effectiveOffset = if (open) 0.0 else max(effectiveOffset, min(maxExtent, offset))
            towardStart = null
        }
        return frame
    }

    /** The bar as it is now: what the last [scrollTo] or [released] returned. */
    public val frame: SliverAppBarFrame get() {
        val shrink = min(effectiveOffset, maxExtent)
        val box = max(minExtent, maxExtent - shrink)
        val paint = when {
            pinned && floating -> max(maxExtent - effectiveOffset, minExtent)
            pinned -> box
            else -> max(maxExtent - effectiveOffset, 0.0)
        }
        // What collapsedHeight adds over the toolbar stays below it as the bar closes.
        val extraToolbar = max(minExtent - topPadding - toolbarHeight, 0.0)
        val visibleToolbar = maxExtent - shrink - topPadding - extraToolbar
        val opacity = if (pinned || toolbarHeight <= 0.0) 1.0 else (visibleToolbar / toolbarHeight).coerceIn(0.0, 1.0)
        return SliverAppBarFrame(paint = paint, layout = max(0.0, maxExtent - offset), box = box, toolbarOpacity = opacity)
    }

    public companion object {
        /** Flutter's kToolbarHeight. */
        public const val TOOLBAR_HEIGHT: Double = 56.0
    }
}
