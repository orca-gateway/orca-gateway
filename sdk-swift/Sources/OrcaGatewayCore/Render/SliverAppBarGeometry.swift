import Foundation

/// What a SliverAppBar draws at one moment, in points along the scroll axis.
public struct SliverAppBarFrame: Equatable, Sendable {
    /// The bar's drawn extent: how much of it is on screen, from the scroll
    /// view's top edge (Flutter's `SliverGeometry.paintExtent`).
    public var paint: Double
    /// How far the bar pushes the content below it: max(0, maxExtent -
    /// offset) for every variant (`SliverGeometry.layoutExtent`). Smaller
    /// than `paint` when the bar lies over the content (pinned, or floated
    /// back in).
    public var layout: Double
    /// The height of the bar's own box (background, flexibleSpace). Its
    /// bottom edge sits at `paint`, so when `box` > `paint` the top of the
    /// box is cut off above the scroll view.
    public var box: Double
    /// The opacity of the toolbar row, 0 ... 1 (`AppBar.toolbarOpacity`).
    public var toolbarOpacity: Double

    public init(paint: Double, layout: Double, box: Double, toolbarOpacity: Double) {
        self.paint = paint
        self.layout = layout
        self.box = box
        self.toolbarOpacity = toolbarOpacity
    }
}

/// A SliverAppBar's extents as the view scrolls (design brief
/// native-parity-s13-slivers, V3): Flutter's `_SliverAppBarDelegate` and
/// `_SliverAppBarState.build` (material app_bar.dart) for a bar without a
/// `bottom`, over the four render objects of rendering/
/// sliver_persistent_header.dart: scrolling (neither), pinned, floating,
/// floating + pinned. The numbers are those of the Flutter widget test
/// sdk/test/sliver_widgets_test.dart (`barCases`).
///
/// It is a value that remembers the scroll: feed it every scroll offset
/// with `scrolled(to:)` and, when the scroll ends, call `released()`. A
/// floating bar depends on that history: it comes back as soon as the view
/// scrolls toward its start, wherever the view is. The bar is taken to be
/// the first sliver of a viewport taller than it (no clamp to the
/// viewport's remaining extent). The same as Kotlin's SliverAppBarGeometry.
public struct SliverAppBarGeometry: Equatable, Sendable {
    /// The toolbar row's height, Flutter's `kToolbarHeight`.
    public static let toolbarHeight: Double = 56

    /// `pinned`: the bar shrinks to `minExtent` and stays at the top.
    public var pinned: Bool
    /// `floating`: the bar comes back on any scroll toward the start.
    public var floating: Bool
    /// `snap`: a floating bar settles fully open or closed when the scroll
    /// ends. Without `floating` it does nothing (Flutter asserts).
    public var snap: Bool
    /// `expandedHeight`, top padding not included; nil is the toolbar's height.
    public var expandedHeight: Double?
    /// `collapsedHeight`, top padding not included; nil is the toolbar's
    /// height. Below the toolbar's height it is taken as given (Flutter
    /// asserts in debug only).
    public var collapsedHeight: Double?
    /// The safe-area top inset the bar reaches under (Flutter's
    /// `MediaQuery.padding.top`), else 0.
    public var topPadding: Double
    /// The toolbar row's height.
    public var toolbarHeight: Double

    /// The scroll offset last given to `scrolled(to:)`, 0 before any.
    public private(set) var offset: Double = 0
    /// How far a floating bar is scrolled away, Flutter's
    /// `_effectiveScrollOffset`: 0 fully open, `maxExtent` or more gone,
    /// never past the scroll offset. It follows the scroll, but a scroll
    /// toward the start takes it down from `maxExtent` at once. A bar that
    /// does not float has the scroll offset here.
    public private(set) var effectiveOffset: Double = 0
    /// The way the last scroll moved, nil before any and after a release:
    /// true toward the start (Flutter's `ScrollDirection.forward`).
    private var towardStart: Bool?

    public init(pinned: Bool = false, floating: Bool = false, snap: Bool = false,
                expandedHeight: Double? = nil, collapsedHeight: Double? = nil, topPadding: Double = 0,
                toolbarHeight: Double = SliverAppBarGeometry.toolbarHeight) {
        self.pinned = pinned
        self.floating = floating
        self.snap = snap
        self.expandedHeight = expandedHeight
        self.collapsedHeight = collapsedHeight
        self.topPadding = topPadding
        self.toolbarHeight = toolbarHeight
    }

    private var top: Double { topPadding.isFinite ? topPadding : 0 }

    /// The smallest the bar gets: the collapsed height (else the toolbar's)
    /// plus the top padding. `_SliverAppBarDelegate.minExtent`.
    public var minExtent: Double {
        let collapsed = collapsedHeight.flatMap { $0.isFinite ? $0 : nil } ?? toolbarHeight
        return collapsed + top
    }

    /// The bar fully open: the expanded height (else the toolbar's) plus
    /// the top padding, never below `minExtent`. `_SliverAppBarDelegate.maxExtent`.
    public var maxExtent: Double {
        let expanded = expandedHeight.flatMap { $0.isFinite ? $0 : nil } ?? toolbarHeight
        return max(top + expanded, minExtent)
    }

    /// The view scrolled to `offset` (points from its start; before the
    /// start, as in a bounce, is 0; not finite is ignored): what the bar
    /// draws now. RenderSliverFloatingPersistentHeader.performLayout for a
    /// floating bar: the scroll's delta from the last offset moves the
    /// bar's own offset, kept within 0 ... `offset`; a bar wholly away
    /// starts back from `maxExtent` on a scroll toward the start.
    @discardableResult
    public mutating func scrolled(to offset: Double) -> SliverAppBarFrame {
        guard offset.isFinite else { return frame }
        let new = max(offset, 0)
        let last = self.offset
        if new != last { towardStart = new < last }
        if floating, new < last || effectiveOffset < maxExtent {
            // Coming back from off screen starts at the bar's far edge.
            if new < last, effectiveOffset > maxExtent { effectiveOffset = maxExtent }
            effectiveOffset = min(max(effectiveOffset - (last - new), 0), new)
        } else {
            effectiveOffset = new
        }
        self.offset = new
        return frame
    }

    /// The scroll ended (finger lifted and the view at rest): where a
    /// `floating` + `snap` bar settles, the scroll offset unchanged. After a
    /// scroll toward the start it opens fully; after one toward the end it
    /// closes fully, never further than the view has scrolled
    /// (RenderSliverFloatingPersistentHeader
    /// .maybeStartSnapAnimation, which Flutter animates over 300 ms with
    /// Curves.ease; the UI animates from `frame` before to the one
    /// returned). Any other bar, and a bar never scrolled, stays as it is.
    @discardableResult
    public mutating func released() -> SliverAppBarFrame {
        guard floating, snap, let towardStart else { return frame }
        self.towardStart = nil
        // Closed is `maxExtent` or more, kept within `offset`.
        effectiveOffset = towardStart ? 0 : max(effectiveOffset, min(maxExtent, offset))
        return frame
    }

    /// What the bar draws now: fully open before any scroll.
    public var frame: SliverAppBarFrame {
        let minExtent = self.minExtent
        let maxExtent = self.maxExtent
        // The offset the bar's box is built for: `layoutChild`'s shrinkOffset.
        let shrink = min(effectiveOffset, maxExtent)
        let box = max(minExtent, maxExtent - shrink)
        let paint: Double
        switch (floating, pinned) {
        case (true, true): paint = max(maxExtent - effectiveOffset, minExtent)
        case (false, true): paint = box
        case (_, false): paint = max(maxExtent - effectiveOffset, 0)
        }
        return SliverAppBarFrame(paint: paint, layout: max(0, maxExtent - offset), box: box,
                                 toolbarOpacity: toolbarOpacity(shrink: shrink))
    }

    /// `_SliverAppBarDelegate.build`: a pinned bar's toolbar stays opaque;
    /// any other fades as the toolbar's own 56 points leave: the visible
    /// height less the top padding and less what `collapsedHeight` adds
    /// over the toolbar, over the toolbar's height.
    private func toolbarOpacity(shrink: Double) -> Double {
        guard !pinned, toolbarHeight > 0 else { return 1 }
        let extra = max(minExtent - top - toolbarHeight, 0)
        return min(max((maxExtent - shrink - top - extra) / toolbarHeight, 0), 1)
    }
}
