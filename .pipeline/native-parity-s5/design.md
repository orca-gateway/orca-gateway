# native-parity-s5 · design in force (plan step 5, written at stage 08; 05-07 skipped)

Repo: /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/native-parity-phase-a-35cc97 (paths below from
there), branch feat/native-parity-s5 stacked on feat/native-parity-s4 at d16d855 (step 4 is PR #44, not merged yet;
rebase when it is). Flutter (`sdk/`) is the reference. Inventory with every file:line: .pipeline/native-parity-s5/
inventory.md. Swift deploys to iOS 16 / macOS 13; Kotlin minSdk 24, Compose BOM 2026.05.01 (material3 1.4.0).

## Cases (phase-a-tests.md rows, after corrections)
- A5.1 A ListView of 1,000 children builds only the rows near the screen. ui
- A5.2 ListView honours horizontal direction, padding and reverse. ui
- A5.3 GridView with crossAxisCount 2 lays out two columns with spacing and child aspect ratio. ui
- A5.4 PageView moves one page per swipe when pageSnapping (default true) and scrolls freely when false, honours
  vertical and reverse, and its onScrollEnd reports offset = page × viewport extent. ui + hand
  [corrected: Flutter's builder passes no onPageChanged and PageView declares no such trigger (LB:668-684,
  page-view.ts:13-15, action.ts:303-326); it fires onScrollBegin/onScrolling/onScrollEnd (LB:675)]
- A5.5 PullToRefresh runs onRefresh and hides its spinner when the action finishes; it starts only from a pull at the
  top of the scroll view it wraps directly. ui + hand  [note: depth 0, MUI refresh_indicator.dart:461-475]
- A5.6 refetchPage reloads the current page in place (no loading screen), keeps app state and resets page state to
  the new page's initial values; it emits no effect. fixture + ui  [note: orca_page.dart:276-297,
  state_manager.dart:19-28, action_executor.dart:812-818]
- A5.7 Scrollbar shows a scroll indicator while scrolling (always with thumbVisibility); without a Scrollbar there is
  none, as in Flutter on mobile. hand  [note: scroll_configuration.dart:160-172]

## Decisions
- D1 Contract. No wire change: the five widgets and refetchPage are in the schema, the engine, the registry and
  Flutter. Render fixture `schema/fixtures/render/44_lists_and_pages.json` holding the five with every wire prop
  (ListView horizontal, padding, reverse, itemExtent, shrinkWrap; GridView 2/8/4/1.5 and a horizontal one; PageView
  vertical, reverse, pageSnapping false; Scrollbar thumbVisibility and thickness; PullToRefresh colours, displacement
  and an onRefresh of RefetchPage) and a `resolved` block; action fixture `schema/fixtures/actions/48_refetchPage.json`
  (or the next free number) pinning Flutter's executor contract: no effect, state unchanged when no reload is wired.
  Count pins move on both SDKs (render 45 → 46, actions 24 → 25). ListView `separator` is out: the engine sends a raw
  widget where Flutter reads a node id, so Flutter's builder throws on it (widget.ts:124-131, BH:25-29); the natives
  ignore the prop and the engine fix is a follow-up.
- D2 Capabilities. Both capabilities.json gain the five widgets (55 → 60) and the action kind refetchPage (20 → 21),
  sorted, one generator run, in the last group: the engine drops a node whose action kind is not advertised
  (capability-filter.ts:216-219), so PullToRefresh and refetchPage land together. Kotlin registers the five in
  standard() there. Engine test `engine/test/parity-a-lists.test.ts` (copy of parity-a-effects.test.ts): each native
  vector gets page `lists` whole (red until the caps group).
- D3 Behaviour = Flutter's builders (inventory §2), defaults included. ListView: vertical unless "horizontal", padding
  inside the scroll extent (null padding adds the safe-area inset on the scroll axis, scroll_view.dart:913-944),
  reverse = children in reverse order anchored at the far end, itemExtent forces each child's main extent,
  shrinkWrap sizes to the content, lazy (only rows near the viewport exist; Flutter's cache is 250 px), the three
  onScroll* triggers as SingleChildScrollView's. GridView: fixed crossAxisCount (default 2), cell cross extent =
  (extent − crossSpacing × (n − 1)) / n, main extent = cross / childAspectRatio (default 1; horizontal reads it as
  height / width), cells tight, lazy, onScroll*. PageView: horizontal unless "vertical", initial page 0, each page the
  viewport's size, pageSnapping true moves at most one page per fling by Flutter's PageScrollPhysics (page ± 0.5 by
  fling direction, then round; a slow release rounds), false scrolls freely, reverse, only visible pages built,
  onScroll* with offset and viewportDimension. Scrollbar: on iOS Flutter draws CupertinoScrollbar (thickness 3,
  fades), on Android a Material thumb (thickness 4, fades after 600 ms over 300 ms), thumbVisibility keeps it shown;
  no Scrollbar, no indicator. PullToRefresh: wraps the scroll view, starts on a pull at its top edge (depth 0 only),
  runs onRefresh and keeps the spinner until the action completes; colour, backgroundColor, displacement 40.
  refetchPage: fetch the current path with the app state (as the loader does), then swap the page tree in place:
  app state kept, page state reset to the new page's initial values, no loading screen, no effect; the awaiting
  action (the spinner) finishes when the fetch has landed.
- D4 Pure cores (both SDKs, same cases, like WrapRuns): `GridCells` (cell size and position from extent, count,
  spacings, ratio and axis) and `PageSnap` (target page from offset, viewport extent, release velocity and Flutter's
  minimum fling velocity; free when snapping is off). Kotlin alone: `ScrollbarThumb` (thumb extent and offset from
  content, viewport and offset with Flutter's minimum length; fade timing), since iOS draws its system indicator.
  The UI layers only measure, draw and feed gestures.
- D5 Swift. ListView: `ScrollView(axis)` with `LazyVStack`/`LazyHStack` (spacing 0) of the children, padding inside,
  reverse as SingleChildScrollView does it (reversed order, anchored at the end; iOS 16 fallback as in Layout.swift
  :310-319), itemExtent a fixed main-axis frame, shrinkWrap an eager stack sized to its content; onScroll* through the
  existing ScrollTriggers/ScrollTracker. GridView: `LazyVGrid`/`LazyHGrid` with cells framed to GridCells' size.
  PageView: one pager view (iOS 16 floor: no paging ScrollView) laying out only the pages near the offset, a drag that
  follows the finger and settles on PageSnap's target with an animation; pageSnapping false a plain ScrollView of
  viewport-sized pages. Scrollbar: an environment value read by the scroll views (`.scrollIndicators(.visible)` when
  set, `.hidden` when not, so SingleChildScrollView loses iOS's default indicator to match Flutter on mobile;
  thickness not settable, documented). PullToRefresh: an environment value carrying the refresh action, applied as
  `.refreshable` by the first scroll view below it and cleared for scroll views nested inside (depth 0); the action
  awaits the fired Task; colour, background and displacement not settable on iOS, documented. refetchPage: a handler
  registered on the page model's executor that asks the loader to fetch and swap the tree in place (no `.loading`
  phase), awaitable.
- D6 Kotlin. ListView `LazyColumn`/`LazyRow` (reverseLayout, contentPadding, itemExtent a fixed main size), shrinkWrap
  or an unbounded main axis an eager Column/Row (Flutter throws there; the natives degrade instead of crashing,
  documented); onScroll* from LazyListState (offset from the first visible item and its offset, extents from the
  layout info). GridView `LazyVerticalGrid`/`LazyHorizontalGrid` with `GridCells.Fixed(n)` and cells sized from the
  core. PageView `HorizontalPager`/`VerticalPager` (reverseLayout, beyondViewportPageCount 0) with a fling behaviour that
  settles on PageSnap's target; pageSnapping false a LazyRow/LazyColumn of viewport-sized items. Scrollbar a
  CompositionLocal read by the scroll builders, which draw the thumb from their state with ScrollbarThumb (Material
  defaults; thickness prop honoured). PullToRefresh `PullToRefreshBox` with indicator colours from the props,
  isRefreshing true while the fired Job runs; only the scroll view directly inside starts it, where Compose allows,
  else documented. refetchPage: a handler that fetches and swaps the tree inside the same OrcaPageModel (its scope
  stays alive, so the Job awaiting it is not cancelled); the renderer becomes swappable.
- D7 Demo. Page `lists` on parity-a, one section per row; every list, grid and pager in a box with a set height (page
  bodies are SingleChildScrollViews). A 1,000-row ListView whose rows count themselves on init into a page-state
  "rows built" text; a horizontal ListView with padding; a reversed one; a GridView 2 columns with spacing and ratio
  1.5; a PageView of three coloured pages showing onScrollEnd's offset, a vertical one and a free one; a Scrollbar
  around a list (thumbVisibility true) beside a list without one; a PullToRefresh around a list whose onRefresh is
  RefetchPage, the page showing a server fetch count and an app-state counter (kept) beside a page-state counter
  (reset). The fetch count must change per fetch: check the engine's page cache does not serve a cached render.
- D8 Tests per row: Swift hosted UIWindow where laziness, scrolling, paging or refreshing matter (find the
  UIScrollView as ScrollTriggerTests do), ImageRenderer for static layout; Kotlin Robolectric compose tests
  (`performTouchInput`, `performScrollToIndex`, LazyListState). Each row's check named `testA5_N…` / `a5_N_…`. No
  golden moves unless a task row lists it.
- D9 Row corrections (written by the main session): A5.4 rewritten, A5.5, A5.6 and A5.7 notes as in the cases above.
