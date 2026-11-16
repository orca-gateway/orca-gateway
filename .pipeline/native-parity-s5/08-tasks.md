# 08 · Tasks · native-parity-s5

## Front page

### In one breath
tasks: 17 in 8 groups · widest group: 3 · cases: 7 of 7 placed
Plan step 5 on both SDKs: ListView, GridView, PageView, Scrollbar, PullToRefresh, refetchPage.
G1 fixtures 44 and 48. G2 refetchPage reloads in place. G3 the executors run and advertise it.
G4 PageView (riskiest view). G5 ListView, GridView. G6 Scrollbar. G7 PullToRefresh, demo page.
G8 both SDKs advertise the five widgets (55 → 60). Hand checks on both devices follow.

### New for you
nothing new

### Trade-offs
All minor under the standing rule, decided by default. Closest to major: q5. refetchPage is
advertised in G3, before the widgets in G8. One caps task per SDK would need six files.

### Questions for you
1. Commands: every suite as at baseline; Swift on macOS and iOS 18.5. (default: as found)
2. One commit per task, one gate per group; nothing pushed before stage 10. (default: yes)
3. Hand checks on the iPhone and Android API 34 after G8 (iOS swipes by hand). (default: yes)
4. One Swift and one Kotlin task per group; reload first, then PageView. (default: yes)
5. refetchPage advertised in G3 with the executors' kinds; the five in G8. (default: yes)
6. Native action-fixture runners red at the G1 and G2 gates (48 waits for G3). (default: yes)
7. Swift reads Scrollbar and PullToRefresh in NodeView for all four scroll kinds. (default: yes)
8. No Scrollbar: iOS hides the indicator; macOS keeps it, as Flutter desktop. (default: yes)
9. If a nested list also starts a refresh (SwiftUI, Compose), it is documented. (default: yes)
10. Engine check "native vectors get the lists page whole" red at the G7 gate. (default: yes)
11. Rows as corrected (D9); the main session writes them into phase-a-tests.md. (default: yes)

## Appendix

### Where step 5 comes from
Plan /Users/amrebada/.claude/plans/native-parity/plan.md:83-89 (Phase A step 5, M, 5 widgets + 1 action); stages 01-07
skipped. Design in force: .pipeline/native-parity-s5/design.md (D1-D9, rows A5.1-A5.7 after corrections). Facts:
.pipeline/native-parity-s5/inventory.md. The design changes two of the plan's hints: the paging TabView becomes Swift's
own pager (TabView(.page) is horizontal only, no reverse, no free scroll), and "refetchPage effect wired to the loader's
reload" becomes a quiet in-place swap that emits no effect (Flutter emits none, action_executor.dart:814-818). Branch
feat/native-parity-s5 on feat/native-parity-s4 d16d855 (PR #44, not merged; rebase when it is). No wire change.
Planner: pipeline:build-task-planner (fresh); plan accepted as returned. Baseline: the suites run at a2b0bd5 (s4, only
pipeline records since): engine 754, Flutter 350 + analyze clean, swift test green, Kotlin core 397 / sdk 436.

### Groups (paths from the repo root; sw/kt = Swift/Kotlin half, fx fixture, eng engine, hand device check)
| # | Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|---|
| 1 | 1 | F1 | Fixtures 44, 48 and Swift pins | schema/fixtures/render/44_lists_and_pages.json (new) · schema/fixtures/actions/48_refetchPage.json (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift · sdk-swift/Tests/OrcaGatewayCoreTests/ActionFixtureTests.swift | A5.1-A5.5, A5.7 fx (44: engine, Flutter, Swift); A5.6 fx (48: Flutter; Swift check red to G3) | M | — |
| 2 | 1 | F2 | Kotlin count pins for 44, 48 | sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionFixtureTest.kt | A5.1-A5.5, A5.7 fx kt (44); A5.6 fx kt (check red to G3) | M | — |
| 3 | 2 | S-refetch | Swift refetchPage reloads in place | sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift · sdk-swift/Tests/OrcaGatewayTests/RefetchTests.swift (new) | A5.6 sw (ui) | M | — |
| 4 | 2 | K-refetch | Kotlin refetchPage swaps tree in place | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageModel.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/RefetchTest.kt (new) | A5.6 kt (ui) | M | — |
| 5 | 3 | S-act | Swift executor runs, advertises refetchPage | sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift · sdk-swift/Tests/OrcaGatewayCoreTests/ActionHandlerTests.swift · sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift | A5.6 fx sw (48 runs), caps unit sw (21 kinds) | M | F1, S-refetch |
| 6 | 3 | K-act | Kotlin executor runs, advertises refetchPage | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionHandlerTest.kt · sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt | A5.6 fx kt (48 runs), caps unit kt (21 kinds) | M | F1, F2, K-refetch |
| 7 | 4 | S-page | Swift PageView pager and PageSnap | sdk-swift/Sources/OrcaGatewayCore/Render/PageSnap.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/PageSnapTests.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Pager.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/PagerTests.swift (new) | A5.4 sw (core unit + ui) | M | — |
| 8 | 4 | K-page | Kotlin PageView pagers and PageSnap | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/PageSnap.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/PageSnapTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Pager.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/PagerTest.kt (new) | A5.4 kt (core unit + ui) | M | — |
| 9 | 5 | S-list | Swift ListView, GridView and GridCells | sdk-swift/Sources/OrcaGatewayCore/Render/GridCells.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/GridCellsTests.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Lists.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/ListTests.swift (new) | A5.1 sw, A5.2 sw, A5.3 sw (core unit + ui) | M | — |
| 10 | 5 | K-list | Kotlin lazy lists, grids, GridCells | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/GridCells.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/GridCellsTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Lists.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ListTest.kt (new) | A5.1 kt, A5.2 kt, A5.3 kt (core unit + ui) | M | — |
| 11 | 6 | S-bar | Swift Scrollbar, indicators hidden otherwise | sdk-swift/Sources/OrcaGateway/Widgets/Scrollbar.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/ScrollbarTests.swift (new) | A5.7 sw (ui, every scroll kind) | M | S-page, S-list |
| 12 | 6 | K-bar | Kotlin Scrollbar thumb and ScrollbarThumb | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/ScrollbarThumb.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/ScrollbarThumbTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Scrollbar.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Layout.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ScrollbarTest.kt (new) | A5.7 kt (core unit + ui, SingleChildScrollView) | M | — |
| 13 | 7 | S-pull | Swift PullToRefresh through refreshable | sdk-swift/Sources/OrcaGateway/Widgets/Refresh.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/RefreshTests.swift (new) | A5.5 sw (ui) | M | S-bar |
| 14 | 7 | K-pull | Kotlin PullToRefresh; Scrollbar on lists | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Refresh.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/RefreshTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Lists.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Pager.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ScrollbarTest.kt | A5.5 kt (ui), A5.7 kt (ui: ListView, GridView, PageView) | M | K-bar, K-list, K-page |
| 15 | 7 | D1 | Demo page lists on parity-a | examples/server/parity-a.ts · examples/server/index.ts · engine/test/parity-a-lists.test.ts (new) | A5.x eng, A5.1-A5.7 hand | M | — |
| 16 | 8 | S-caps | Swift advertises the five widgets | sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift | A5.x caps unit sw (60 widgets) | M | S-act, S-page, S-list, S-bar, S-pull |
| 17 | 8 | K-caps | Kotlin registers and advertises the five | sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt | A5.x caps unit kt (60 widgets) | M | K-act, K-page, K-list, K-bar, K-pull |

Placed: A5.1-A5.3 F1/F2 (fx), then S-list/K-list (core unit + ui); A5.4 F1/F2, then S-page/K-page (core unit + ui);
A5.5 F1/F2, then S-pull/K-pull (ui); A5.6 F1/F2 (fx, red on the natives until G3), S-refetch/K-refetch (ui),
S-act/K-act (fx runs); A5.7 F1/F2, S-bar (ui), K-bar (core unit + ui), K-pull (lists, pages); caps S-act/K-act (kinds),
S-caps/K-caps (widgets); eng D1; hand checks (A5.4, A5.5, A5.7, plus A5.1 and A5.6) on D1's page after G8. Test names
`testA5_N…` / `a5_N_…`.

### Order and expected reds
- G1. F1 writes fixture 44 (the five with every wire prop per D1, ListView without `separator`, a `resolved` block, one
  prop bound to page state, colours "#RRGGBB") and fixture 48 in the shape of 05_goBack.json (actions [refetchPage],
  state unchanged, effects []); moves the Swift pins (ModelRoundTripTests.swift:10 45 → 46, :39; ActionFixtureTests.swift
  :23-27 24 → 25); adds `testA5_6_RefetchPageEmitsNothing_fixture48`. F2 moves ModelRoundTripTest.kt:32, :79,
  FixturePathsTest.kt:13-14, ActionFixtureTest.kt:89-94 and adds `a5_6_refetchPageEmitsNothing`; its pins count F1's
  files, so both are checked together at the gate. Engine and Flutter list the directories and run 44 and 48 green
  (Flutter awaits a null onRefetchPage and emits nothing). D1 cannot sit in G1: demo-server.test.ts:15 spawns index.ts
  while F1 runs the engine suite. Red at the gate (q6): both native action-fixture loops and the two a5_6 checks (the
  runners assert every kind is implemented, ActionFixtureTests.swift:199, ActionFixtureTest.kt:53).
- G2 (riskiest first: every page has a model). S-refetch: the loader registers a `refetchPage` handler on each model
  it makes (OrcaApp.swift:94-96; registerHandler ActionExecutor.swift:82); the handler fetches its path with
  router.appState (:90-92) and hands the page to a new model method that swaps the renderer (OrcaPageModel.swift:24),
  sets store.pageId, calls store.seed (page state reset, app kept, ElmStore.swift:136-148) and bumps
  structureRevision (:187-190); no `.loading` phase, no effect; a failed fetch throws out of the action as Flutter's
  does and the page stays. K-refetch the same without closing the model (reload's close, OrcaApp.kt:114, would cancel
  the Job awaiting the refetch, OrcaPageModel.kt:144-146); the renderer (val :65) becomes Compose state; seed as at
  :98; structureRevision :75. Tests through the loader with a stub client: the fired Task/Job ends after the second
  fetch; the phase stays loaded with the same model; an app key kept, a page key back to its initial value; onEffect
  sees nothing. Red at the gate: G1's (q6).
- G3 (q5). S-act adds refetchPage to ActionExecutor.kinds (:40-45; with no handler the switch's default returns, :242,
  as Flutter with no onRefetchPage; the loader's handler runs first, :138-148), to capabilities.json (sorted) and
  Generated.swift (one generator run); moves CapabilitiesTests.swift:84 (20 → 21) and ActionHandlerTests.swift
  :118-128; adds an `a5_6` caps check. K-act the same in ActionExecutor.kt:401-405 (`else -> return` :258),
  CapabilitiesTest.kt:129, :137, ActionHandlerTest.kt:171-179; CapabilitiesTest.kt:134 (Swift's kinds equal Kotlin's)
  is red until both land. Fixture 48 runs on both. Red at the gate: none.
- G4 (riskiest view). PageSnap in both cores, same cases: target page from offset, viewport extent and release
  velocity; past Flutter's minimum fling velocity page ± 0.5 by direction then round, below it round; never more than
  one page per fling (page_view.dart:603-611); nil when snapping is off; reverse mirrored. S-page: Pager.swift builds
  only the pages within one viewport of the offset; a drag follows the finger and settles on PageSnap's target with an
  animation; onScroll* through the core ScrollObserver (ScrollEvent.swift:65,80) with offset and viewportDimension;
  pageSnapping false a ScrollView of viewport-sized pages with ScrollTriggers (Layout.swift:352, as is). Tests:
  ImageRenderer frames (page 0 fills the box, vertical, reverse), a hosted settle through an internal entry point
  (onScrollEnd offset = page × width, one page per settle, at most 2 pages built), free mode by setContentOffset; the
  swipe itself by hand (q3). K-page: HorizontalPager/VerticalPager (reverseLayout, beyondViewportPageCount 0) with a
  fling behaviour on PageSnap; free mode a LazyRow/LazyColumn of viewport-sized items; onScroll* from the pager state;
  Robolectric swipe and fast fling each move one page, a free fling goes further, vertical, reverse, onScrollEnd
  offset. Red at the gate: none.
- G5. GridCells in both cores, same cases: cross = (extent − crossSpacing·(n − 1)) / n, main = cross / ratio,
  horizontal reads the ratio as height / width (sliver_grid.dart:394-399), position by index with mainAxisSpacing,
  defaults 2 / 1 / 0, padding taken off first. S-list: ListView a ScrollView with LazyVStack/LazyHStack (spacing 0),
  padding inside, reverse as Layout.swift:310-319, itemExtent a main-axis frame, shrinkWrap an eager stack in HugLayout
  (:283-284), onScroll* via ScrollTriggers; GridView LazyVGrid/LazyHGrid with cells framed to GridCells' size.
  K-list: LazyColumn/LazyRow (reverseLayout, contentPadding, itemExtent), an eager Column/Row when shrinkWrap or the
  axis is unbounded (D6); lazy grids GridCells.Fixed(n), cells sized by the core; onScroll* from the lazy state on the
  core ScrollObserver (Layout.kt's ScrollTriggers are private and take a ScrollState, :159-175). Tests: 1,000 rows
  build only those near the viewport (counted from onInit or frames, hosted on iOS); horizontal, padding and reverse
  frames; 2 columns with spacing and ratio. Red at the gate: none.
- G6. S-bar: ScrollbarView sets an environment value; WidgetView applies one modifier to the four scroll kinds
  (NodeView.swift:81 and G4-G5's cases): `.scrollIndicators(.visible)` at depth 0 under a Scrollbar, else `.hidden` on
  iOS (macOS keeps its default, q8); cleared for nested scroll views (q7). Hosted checks read
  showsVertical/HorizontalScrollIndicator on each kind's UIScrollView with a Scrollbar, without one, nested; the
  thumbVisibility thumb and the fade by hand. K-bar: ScrollbarThumb (thumb extent from viewport and content with
  Flutter's minimum length, offset, fade after 600 ms over 300 ms, shown while scrolling or always with
  thumbVisibility, none when nothing scrolls); Scrollbar.kt provides a local the depth-0 scroll view reports to and
  clears; ScrollWidget (Layout.kt:131-150) reports to it; the wrapper draws the thumb (thickness prop, default 4).
  Robolectric pixels (@GraphicsMode NATIVE): a thumb while scrolling, gone after the fade (mainClock), kept with
  thumbVisibility, none without a Scrollbar. Red at the gate: none.
- G7. S-pull: PullToRefreshView sets an environment value holding its onRefresh; G6's path applies `.refreshable {
  await model.fire("onRefresh", on:)?.value }` to the depth-0 vertical scroll kind (fire returns its Task,
  OrcaPageModel.swift:78-83); hosted: that UIScrollView has a refreshControl, sendActions(.valueChanged) runs
  onRefresh, isRefreshing holds until a gated handler returns. K-pull: PullToRefreshBox, isRefreshing while the fired
  Job runs, indicator colours from the props, resting at displacement; ListView, GridView and both PageView modes
  report to the Scrollbar local (Lists.kt, Pager.kt); Robolectric swipeDown at the top runs onRefresh and the spinner
  waits for the Job, swipeDown away from the top does nothing, thumbs on a list, a grid and a pager. D1: page `lists`
  per D7 (header parity-a.ts:64-71 names lists as a later step; routes :1166-1177; URL after index.ts:102-106; test
  copies parity-a-effects.test.ts); the fetch count is a module counter read in getInfoData, fresh per fetch because
  cachePolicy defaults to "none" (engine/src/core/page.ts:33-34). Red at the gate (q10): "A5 each native vector gets
  the lists page whole".
- G8. S-caps adds the five (sorted), runs the generator, moves CapabilitiesTests.swift:42-49 and
  StructureWidgetTests.swift:259-265 to 60 (the branch check :267-279 then covers the five), adds an `a5` check.
  K-caps registers the five in standard() (re-read WidgetBuilders.kt; s4 moved its lines) in the commit that lists
  them, moves its doc comment and CapabilitiesTest.kt:66-101 to 60, adds an `a5` check (WidgetBuildersTest.kt:15-23
  compares sets, no edit). c1 red until both land; D1's red clears with both. Hand checks follow.

### Seams
- gen-native-capabilities.ts writes Generated.swift and Generated.kt in one run: S-act/K-act (G3) and S-caps/K-caps
  (G8) each stage only their own; whichever finishes last reruns the generator so both are clean at the gate.
- NodeView.swift: S-page, S-list, S-bar, S-pull, one per group; S-caps never touches it. Layout.swift: no task
  (ScrollTriggers reused; a task that must change them stops and reports).
- Kotlin: Layout.kt only K-bar; Lists.kt K-list then K-pull; Pager.kt K-page then K-pull; ScrollbarTest.kt K-bar then
  K-pull. OrcaApp and OrcaPageModel (both): only the refetch tasks. ActionExecutor and ActionHandlerTests: only the
  act tasks. capabilities.json, Generated, CapabilitiesTests: act tasks (G3), then caps (G8). WidgetBuilders.kt: K-caps.
- No golden listed; if one moves (S-bar hides iOS indicators by default), the task stops.

### Risks (planner, checked against the code)
1. Both clients degrade types they lack: G4-G7 tests widen the registry (Swift as PluginWidgetTests.swift:67, Kotlin
   as BoxTest.kt:56), Kotlin builders test-local with a testTag (FlowTest.kt:88-110), as in s4.
2. iOS 16 pager: no paging ScrollView; S-page builds its own; its drag must leave a vertical list inside a horizontal
   page scrollable; fling feel and threshold proven only in PageSnap and by hand.
3. In-place swap keeps the model and executor, so `once` keys and onInit guards survive; rows keep their ids and are
   not mounted again (likely as Flutter reuses elements); after a refetch the demo's "rows built" (page state, reset)
   may read 0 on all three; the hand check compares with Flutter.
4. Lazy onScroll*: LazyListState has no pixel offset or content extent and SwiftUI lazy stacks estimate theirs:
   offsets exact with itemExtent or equal rows, maxExtent otherwise estimated (documented); tests use equal rows.
5. Kotlin's core GridCells shares a name with Compose's `GridCells`: Lists.kt imports one under an alias.
6. Refresh depth 0 may not hold (q9): SwiftUI hands `refresh` to nested scroll views (no setter), Compose chains
   nested scrolls up to PullToRefreshBox; tests show which, documented; only vertical kinds start a refresh.
7. iOS Scrollbar is the system indicator: no thickness, persistent thumb unverified (may need flashScrollIndicators);
   a snapping iOS PageView is not a ScrollView, so no indicator and no refresh (documented); Kotlin draws for pagers.
8. ListView with null padding adds the safe-area inset on its scroll axis (scroll_view.dart:913-944): SwiftUI's
   ScrollView does so at a screen edge, Compose needs the window insets; a list inside a box gets none.
9. GridView cells are tight in Flutter, LazyVGrid only proposes sizes: S-list frames each cell to GridCells' size.

### Done when
engine `bun test`; `flutter test` + `flutter analyze`; `swift test` (macOS) and the iOS scheme on DA7254F5; Kotlin
`./gradlew build --console=plain`; generators leave no diff; goldens unchanged; one commit per task, staged by path;
one gate per group; hand checks after G8 (q3).

### Not planned (on purpose)
ListView `separator` (engine wire bug, follow-up, D1); `primary` on ListView and GridView (no native counterpart, as
SingleChildScrollView); PageView initialPage, viewportFraction, onPageChanged (not on the wire); iOS PullToRefresh
colour, background, displacement and iOS Scrollbar thickness (system controls, documented); Kotlin PullToRefreshBox's
pull threshold (Compose's own; the indicator rests at displacement); dragging the Scrollbar thumb (Flutter's Material
thumb is not interactive, MUI scrollbar.dart:244); Flutter's throw on an unbounded list (natives draw it eagerly, D6).
