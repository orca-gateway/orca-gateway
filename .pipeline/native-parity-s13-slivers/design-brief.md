# Design brief · native-parity-s13-slivers (CustomScrollView and the four sliver widgets)

Plan step 13, second part. Rows B13.1 and B13.2 of `native-parity/phase-b-tests.md`. Built on Phase A step 5
(ListView, GridView, the scroll triggers, the core `GridCells`), on main since 20611b2. Flutter (`sdk/`) is the
reference: `sdk/lib/src/builders/structure_builders.dart` `_buildCustomScrollView`, `_buildSliverList`,
`_buildSliverGrid`, `_buildSliverToBoxAdapter`, `_buildSliverAppBar`; the bar's own maths is
`~/.pub-cache/hosted/pub.dev/material_ui-1.11.0/lib/src/app_bar.dart` (`_SliverAppBarDelegate`) and Flutter's
`rendering/sliver_persistent_header.dart` (`/Users/amrebada/flutter/packages/flutter/lib/src/`).

## Wire facts (no wire change; all five are in the schema, the engine, the registry and Flutter)

- CustomScrollView: `slivers` arrive as `children`. Props `scrollDirection` ("horizontal", else vertical),
  `reverse` (false), `shrinkWrap` (false). Triggers onScrollBegin, onScrolling, onScrollEnd.
- SliverList: children, no props. SliverToBoxAdapter: one child (none = nothing), no props.
- SliverGrid: children; `crossAxisCount` (2 when absent), `mainAxisSpacing` 0, `crossAxisSpacing` 0,
  `childAspectRatio` 1.
- SliverAppBar: structure widget. Slots as props holding node ids: `title`, `leading`, `flexibleSpace`,
  `action_0` … `action_9` (stop at the first gap). Props `backgroundColor`, `elevation`, `centerTitle`, `floating`
  false, `pinned` false, `snap` false, `expandedHeight`, `collapsedHeight`. `flexibleSpace` is drawn raw behind the
  toolbar, filling the bar's current extent (no FlexibleSpaceBar).

## Decisions

V1. One scroll surface. A CustomScrollView is ONE lazy scroll view on each platform (Swift: `ScrollView` of a
    `LazyVStack`/`LazyHStack`; Kotlin: one `LazyColumn`/`LazyRow`). Its slivers are flattened by a pure core
    helper, `SliverItems`, into an ordered list of lazy items:
    - SliverList: one item per child (child forced to the cross extent, as ListView's rows).
    - SliverGrid: one item per grid LINE holding up to `crossAxisCount` cells; cell size from the core
      `GridCells` (same numbers as GridView); `mainAxisSpacing` between lines, not after the last.
    - SliverToBoxAdapter: one item (its child at the cross extent); no child, no item.
    - SliverAppBar: one `bar` item (see V3).
    - Any other widget as a direct child: one box item, as a SliverToBoxAdapter (Flutter throws; we draw it).
    Each item carries a stable key (node id, or grid id + line index). Same cases on both cores.
V2. `scrollDirection`, `reverse`, `shrinkWrap`, the unbounded-axis fallback (everything laid out, nothing
    scrolls) and the three scroll triggers behave as ListView's from step 5; reuse its helpers (Swift
    `LazyScroll`/`ScrollTriggers`, Kotlin `LazyScrollReports`), do not copy them. Metrics are exact with rows of
    one length, an estimate otherwise, as ListView's.
V3. SliverAppBar is drawn by the SDK, not by the system navigation bar. The plan said "large-title navigation
    bar" (Swift) and "LargeTopAppBar with a scroll behaviour" (Kotlin); neither can honour `expandedHeight`,
    `collapsedHeight`, `floating` or a raw `flexibleSpace`, which row B13.2 asks for. So:
    - Pure core `SliverAppBarGeometry` (both cores, same cases, numbers taken from a Flutter widget test):
      inputs `pinned`, `floating`, `snap`, `expandedHeight?`, `collapsedHeight?`, `topPadding`, toolbar height 56;
      gives `maxExtent`, `minExtent`, and for a scroll offset (plus, for floating, the running effective offset
      updated by each scroll delta) the bar's visible extent, its shrink offset and the toolbar opacity; and
      for `snap`, the offset to settle on when a scroll ends. It mirrors `_SliverAppBarDelegate` and
      RenderSliverPersistentHeader's four variants (scrolling, pinned, floating, floating + pinned).
    - UI: when the bar is the FIRST sliver of a vertical, non-reversed CustomScrollView, the lazy list's first
      item is a spacer of `maxExtent` and the bar is drawn over the top of the scroll view at the extent the
      core gives: background (`backgroundColor`, else the platform bar surface), `flexibleSpace` filling it,
      and a 56 pt toolbar row at the top under `topPadding` with `leading`, `title` (`centerTitle`), actions,
      faded by the toolbar opacity. `elevation` casts the shadow the native AppBar widget casts. The toolbar
      row reuses the existing native AppBar's item drawing where it can.
    - Anywhere else (not first, horizontal, reversed, or outside a CustomScrollView) the bar is a plain box item
      of `maxExtent` that scrolls with the content. Stated limit.
    - `topPadding` is the safe-area top inset at the scroll view's top edge when it reaches under the status
      bar, else 0 (Flutter: `MediaQuery.padding.top`).
    - `snap` on a platform where a programmatic settle is not practical may be left as plain floating; say so.
V4. Sliver widgets outside a CustomScrollView (Flutter throws): SliverList draws its children one below the
    other, SliverGrid as an eager grid, SliverToBoxAdapter its child, SliverAppBar the box of V3. No crash.
V5. Contract: render fixture `schema/fixtures/render/69_custom_scroll_view_slivers.json` with the five widgets
    and every wire prop and a `resolved` block; count pins move on Flutter, Swift and Kotlin. Both
    `capabilities.json` gain the five names (sorted), one run of the three generators, in the UI task of each
    SDK. Engine test `engine/test/parity-b-slivers.test.ts` in the shape of `parity-a-lists.test.ts`: each
    native capability vector gets the `slivers` demo page whole (red until both capability lists have the names).
V6. Flutter: no behaviour change. A widget test `sdk/test/sliver_widgets_test.dart` pins what the builders
    draw and the bar's extent at chosen offsets for pinned, floating, both, neither, with `expandedHeight`
    and `collapsedHeight`: those numbers are the core cases of V3.
V7. Demo: `slivers` app in `examples/server` (registered in `index.ts`, README): three tabs so no route is
    wrapped in a second bar. Each tab is a CustomScrollView with a SliverAppBar (tab 1 pinned, expandedHeight
    200, a coloured flexibleSpace; tab 2 floating; tab 3 neither), a SliverToBoxAdapter heading, a SliverGrid of
    6 cells (3 across, spacing 8, ratio 1.5), a SliverList of 40 rows and a closing SliverToBoxAdapter.

## Cases

- C-fix: fixture 69 passes the Flutter, Swift and Kotlin conformance suites.
- C-items-S / C-items-K (core): `SliverItems` flattens list, grid lines (5 cells at 2 across = 3 lines), adapter
  with and without a child, bar, a stray widget; keys are stable.
- C-geo-S / C-geo-K (core): `SliverAppBarGeometry` gives Flutter's extents for the four variants, with
  expandedHeight, collapsedHeight, topPadding, floating re-entry on a reverse scroll, snap target.
- C-flutter: the Flutter widget test of V6.
- B13.1-S / B13.1-K (ui): a CustomScrollView with a bar, a list of 200, a grid and an adapter is one scroll
  view; only items near the screen are built; scrolling to the end shows the last adapter; grid cells have
  GridCells' size; the scroll triggers fire; horizontal, reverse and shrinkWrap as ListView.
- B13.2-S / B13.2-K (ui): the drawn bar's height at offsets 0, mid and far for pinned, floating (re-enters on a
  reverse scroll) and neither; expandedHeight and collapsedHeight honoured; slots drawn.
- C-fallback-S / C-fallback-K (ui): each sliver outside a CustomScrollView and a stray child inside draw.
- C-caps: the engine parity test of V5. C-demo: the `slivers` app, with an engine test in the shape of
  `engine/test/reorder-example.test.ts`.
- Hand (stage 10): the demo on the iOS simulator and the Android emulator, rows B13.1 and B13.2.
