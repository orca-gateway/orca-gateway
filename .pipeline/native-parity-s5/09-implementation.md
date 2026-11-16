# 09 · Implementation · native-parity-s5

## Front page

### In one breath
All 9 groups done · 21 tasks green, 0 blocked · A5.1-A5.7 ticked on both SDKs and both devices.
Rebased twice on main (3518792, 644d5d8). On 644d5d8 a refetch keeps the pages mounted in SubPages,
as Flutter's now does; six tests on each SDK pin it (R-sub, red on a naive merge, then green).
Suites green on the final head. One Android oddity recorded as seen: 2 of 7 refetches during the
emulator's worst stall reached the server but never landed; the other 5 and the JVM tests are fine.

### New for you
nothing new

### Trade-offs
none new (the iOS and Android differences are in phase-a-tests.md A5.4-A5.7)

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: open the step 5 PR against main, then go on to step 6. (default: go)

## Appendix

Cases count: 7 rows split per SDK = 14 cells, plus the fixture half (F1/F2) and the engine half (D1); a row is ticked
in phase-a-tests.md only when every half passes on both SDKs and the hand checks agree.

### Group 1
Commits: F1 ff32205, F2 560f22f (staged by path; F2 after F1 so no commit has pins without fixtures). Nothing pushed.

#### Task F1 · Fixtures 44, 48 and Swift pins
Files: `schema/fixtures/render/44_lists_and_pages.json` (new) · `schema/fixtures/actions/48_refetchPage.json` (new) ·
`sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `.../ActionFixtureTests.swift`
Cases: A5.1-A5.5, A5.7 fx → green (engine `bun test` 755/0, was 754; `flutter test` 352, was 350) · A5.6 fx → Flutter
green; Swift red as planned (q6): `testA5_6_RefetchPageEmitsNothing_fixture48`, `testAllTwentyFiveActionFixturesPass`
fail at "48_refetchPage.json: every kind implemented" (state and effects already match). Red first on 45≠46, 24≠25.
Changed: 44 a Column of 27 nodes: ListView horizontal, padding, shrinkWrap, primary false, itemExtent 80, reverse
bound to page state, onScrollEnd setState from the event offset, no separator; GridView 2/8/4/1.5 and a horizontal
3/2/2/2; PageView vertical, snapping false, reverse; Scrollbar true/6 and PullToRefresh #6200EE/#FFFFFF/60 with
onRefresh refetchPage, each around a ListView. `expected` from encodeJsonTree, cross-checked against flatten. 48 runs
[refetchPage] on page {count 2}, app {visits 3}: state unchanged, effects [].
Decisions: PageView carries no actions (no triggers in the registry, the A5.4 correction); count test renamed
TwentyFour → TwentyFive as when the count last moved.
Review: self (fixture content against inventory §1, pins, the expected reds) · pass
Not done: engine-dart conformance not run (needs `dart pub get`; not in any CI workflow, as in s3/s4).

#### Task F2 · Kotlin count pins for 44, 48
Files: `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `.../FixturePathsTest.kt` ·
`.../state/ActionFixtureTest.kt`
Cases: A5.1-A5.5, A5.7 fx kt → green · A5.6 fx kt → red as planned (q6): `a5_6_refetchPageEmitsNothing`,
`allTwentyFiveActionFixturesPass` at "every kind implemented"; `:core:test` 398, 2 failed (only those). Red first.
Changed: render 45 → 46 ("01-44, 60-61"), action 24 → 25 ("45-48"), new `a5_6_refetchPageEmitsNothing`.
Review: self (diff read: counts, messages, the new check) · pass

### Group 2
Commits: K-refetch 588d818, S-refetch bcbf30c (staged by path). Nothing pushed. Gate 09 group 1 approved under the
standing rule.

#### Task K-refetch · Kotlin refetchPage swaps tree in place
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt` · `.../OrcaPageModel.kt` · `.../RefetchTest.kt` (new)
Cases: A5.6 kt → green: `a5_6_kt_refetchPageSwapsTheTreeInPlaceKeepingAppStateAndResettingPageState`,
`a5_6_kt_aFailedRefetchThrowsOutOfTheActionAndLeavesThePage`; `./gradlew build` sdk 438/0, lint clean; core 398 with
F2's two expected reds. Red first (no second fetch; nothing thrown).
Changed: `renderer` Compose state with a private setter; `replacePage(page)` swaps it, sets store.pageId, seeds (page
state reset, unset app keys only) and bumps structureRevision through a shared `structureChanged()`; the loader
registers a `refetchPage` handler before `plugins.install` (a host's wins) that fetches `path` with the app state and
calls `replacePage` on the same model, never through reload/close (whose close would cancel the awaiting Job).
Decisions: a failed fetch throws out of execute, `model.run` passes it to onError, so a fired Job still ends; nodes
keeping their id do not run onInit again (firstMount guard), as Flutter's kept elements.
Review: self (diff read: seed semantics checked in ElmStore.kt:130-140; every renderer reader re-reads per revision) ·
pass

#### Task S-refetch · Swift refetchPage reloads in place
Files: `sdk-swift/Sources/OrcaGateway/OrcaApp.swift` · `.../OrcaPageModel.swift` · `.../RefetchTests.swift` (new)
Cases: A5.6 sw → green: 5 tests (`testA5_6_RefetchPageSwapsTheTreeInPlaceWithoutLoading`, `…KeepsAppStateAndResets
PageState`, `…EmitsNoEffect`, `testA5_6_FailedRefetchKeepsThePageAndThrowsOutOfTheAction`,
`testA5_6_AHostRefetchPageHandlerWinsOverTheBuiltIn`); `swift test` UI 292/0, core 397 with F1's two expected reds.
Changed: the model's init registers a built-in `refetchPage` awaiting `onRefetchPage` (Flutter's
`ActionExecutor.onRefetchPage`), before a plugin host adds its handlers; the loader sets the hook (fetch path with the
app state, `replacePage`); `replacePage` swaps renderer, page id, seeds, bumps structureRevision; no loading phase.
Decisions: the hook lives on the model because the plugin host makes the model and adds handlers in one call; a model
without a loader runs refetchPage as a no-op (Flutter with a null onRefetchPage).
Review: self, fit rework (a host's `refetchPage` was overridden by the loader's; now it wins, test added) · pass

### Group 3
Commits: K-act 4c60939, S-act adab6f9 (staged by path; the generator rerun after both leaves no diff, both vectors
hash d10bad06…). Nothing pushed. Gate 09 group 2 approved under the standing rule.

#### Task K-act · Kotlin executor runs, advertises refetchPage
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt` · `.../ActionHandlerTest.kt` ·
`sdk-kotlin/capabilities.json` · `.../capabilities/Generated.kt` (regenerated) · `.../CapabilitiesTest.kt`
Cases: A5.6 fx kt + caps unit kt → green: `a5_6_refetchPageEmitsNothing`, `allTwentyFiveActionFixturesPass`, new
`a5_6_refetchPageIsAdvertisedAndRunByTheExecutor`, `actionKindsMatchTheImplementedList` (21),
`c16_2_kindsStayTheBuiltInList`; `./gradlew build` core 399/0, sdk 438/0, lint clean. Red first (5 for the right reasons).
Changed: "refetchPage" in `kinds` (falls through `else -> return`: nothing, no effect), in actionKinds (sorted).
Review: self (diff read; mechanical) · pass

#### Task S-act · Swift executor runs, advertises refetchPage
Files: `sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift` · `.../ActionHandlerTests.swift` ·
`sdk-swift/capabilities.json` · `.../Capabilities/Generated.swift` (regenerated) · `.../CapabilitiesTests.swift`;
approved outside the row: `.../ActionFixtureTests.swift` (one baseline assertion, below)
Cases: A5.6 fx sw + caps unit sw → green: `testA5_6_RefetchPageEmitsNothing_fixture48`,
`testAllTwentyFiveActionFixturesPass`, new `testA5_6_RefetchPageIsAdvertisedAndKnownToTheExecutor`,
`testActionKindsMatchTheImplementedList`, `testC16_2_KindsStayTheBuiltInList`; `swift test` core 398/398, UI 292/292;
iOS scheme UI 353/353, goldens unchanged (run before the one-line edit). Engine caps-reading tests 31/31.
Changed: "refetchPage" in `kinds` and actionKinds; `testImplementsLooksInsideOnceAndAlways` used refetchPage as its
example of a kind not run, now `.animateForward("fade")` (not in kinds, no handler; Kotlin's twin uses the same).
Review: self, rework (the baseline assertion above) · pass

### Group 4
Commits: K-page 7fdb45d, S-page 7135698 then its rework 419d366 (staged by path). Nothing pushed. Both reviewed
(fit and quality, one reviewer each); each went back once. Group 4 approved under the standing rule.

#### Task K-page · Kotlin PageView pagers and PageSnap
Files: `sdk-kotlin/core/.../render/PageSnap.kt` (new) · `.../render/PageSnapTest.kt` (new) ·
`sdk-kotlin/sdk/.../widgets/Pager.kt` (new) · `.../widgets/PagerTest.kt` (new)
Cases: A5.4 kt → green: 8 core `a5_4_*`, 11 UI `a5_4_kt_*`; `./gradlew build` core 427 / sdk 474, lint clean; baseline
unchanged. Red first, each against a stub that compiled.
Changed: PageSnap.target(offset, viewportExtent, velocity, travel, pageCount, pageSnapping, minFlingVelocity,
minFlingDistance): a fling only past |v| > 50 dp/s (Android) and |travel| > 18 (kTouchSlop), then page ± 0.5 and
round, clamped; null when snapping is off. Pager.kt: HorizontalPager/VerticalPager (reverseLayout,
beyondViewportPageCount 0) with an own TargetedFlingBehavior on PageSnap; ReleaseTravel samples the touch on the
Initial pass (Flutter's Android window: 100 ms, cut at 40 ms gaps, last 20); free mode a LazyRow/LazyColumn of
viewport-sized items; an unbounded main axis lays every page out eagerly instead of crashing.
Rework (review): the fling-distance gate was missing; an unused import.
Not done: free mode keeps Compose's own fling (no Flutter gates); Compose prefetches the next page while scrolling.

#### Task S-page · Swift PageView pager and PageSnap
Files: `sdk-swift/Sources/OrcaGatewayCore/Render/PageSnap.swift` (new) · `.../PageSnapTests.swift` (new) ·
`sdk-swift/Sources/OrcaGateway/Widgets/Pager.swift` (new) · `NodeView.swift` · `.../PagerTests.swift` (new)
Cases: A5.4 sw → green: 13 core `testA5_4…`, 18 UI (12 on macOS, all 18 hosted on iOS); `swift test` UI 306 / core 419;
iOS scheme on DA7254F5 UI 386 / core 419, goldens unchanged. Red first on a stub each pass.
Changed: PageSnap.target with the same arguments as Kotlin (iOS 100 pt/s, 18 pt); `IOSFlingTracker`, a port of
Flutter's IOSScrollViewFlingVelocityTracker (velocity_tracker.dart:295-397: last 20 samples, 0.6/0.35/0.05 of the
last three pair speeds, travel newest − oldest, 0 after a 40 ms stop); `flingVelocity` caps at 8000. PagerView builds
the 1-2 pages in sight; PagerFeed samples from touch-down, takes the drag past 18 pt along the axis, follows the finger,
settles on Flutter's spring and ends exactly on page × extent; keepWithinPages clamps a page past a shrunk count;
an extent change mid-settle ends the settle on its page. FreePager (pageSnapping false) a ScrollView of a lazy stack.
Rework (review, checked against Flutter): samples began after the slop, so 18-36 pt swipes never paged; the release
used Android's windowed tracker where Flutter on iOS uses the iOS one; the page was not clamped when the count shrank
(refetchPage keeps the view); a settle could be left set when the extent changed.
Decided (main session): edges stop with no bounce; the drag is simultaneous, so a same-axis scroll view inside a page
moves with the pager (follow-up); Kotlin keeps its windowed tracker and Compose's own velocity cap (Android's).
Not done: FreePager copies Layout.swift's private scrollView/phased helpers (follow-up); the nested-scroll case and
real swipes stay on the hand check (q3).

### Group 5
Commits: K-list 5727426, S-list 316da40 (staged by path). Nothing pushed. Both reviewed (fit and quality); K-list went
back once for doc wording, S-list passed with nits. Group 5 approved under the standing rule.

#### Task K-list · Kotlin ListView, GridView and GridCells
Files: `sdk-kotlin/core/.../render/GridCells.kt` (new) · `.../render/GridCellsTest.kt` (new) ·
`sdk-kotlin/sdk/.../widgets/Lists.kt` (new) · `.../widgets/ListTest.kt` (new)
Cases: A5.1 kt, A5.2 kt, A5.3 kt → green: 8 core `a5_3_kt_*`, 16 UI; `./gradlew build` green, lint clean. Red first.
Changed: GridCells (frame, contentExtent): cross extent (extent − spacing × (n − 1)) / n, main = cross / ratio,
horizontal reads the ratio along the scroll axis; values Flutter only asserts on fall back (count < 1 → 1, ratio <= 0
→ 1, negative spacing → 0). ListViewWidget LazyColumn/LazyRow (reverseLayout, contentPadding, itemExtent), GridViewWidget
LazyVerticalGrid/LazyHorizontalGrid with cells from GridCells; onScroll* from the lazy state. shrinkWrap in a bounded
parent stays lazy and hugs its content (Flutter's ShrinkWrappingViewport is lazy); only an unbounded scroll axis lays
out eagerly (Flutter throws there).
Rework (review): KDoc gave the wrong reason for no cache window; GridView KDoc lacked the safe-area note.
Not done: Compose builds only rows on screen plus its prefetch (Flutter's 250 px cache builds a few more); a
LazyLayoutCacheWindow was tried and built no extra rows, so it was reverted. Null padding adds no safe-area inset.

#### Task S-list · Swift ListView, GridView and GridCells
Files: `sdk-swift/Sources/OrcaGatewayCore/Render/GridCells.swift` (new) · `.../GridCellsTests.swift` (new) ·
`sdk-swift/Sources/OrcaGateway/Widgets/Lists.swift` (new) · `NodeView.swift` · `.../ListTests.swift` (new)
Cases: A5.1 sw, A5.2 sw, A5.3 sw → green: 8 core `testA5_3…` (Kotlin's inputs and numbers), 15 UI (2 on macOS, 13
hosted on iOS); on HEAD plus its five files, `swift test` UI 303 / core 415, iOS scheme UI 382 / core 415, goldens
unchanged. Red first (core did not compile; every UI test drew nothing).
Changed: GridCells shaped like Kotlin's. ListNodeView a ScrollView of LazyVStack/LazyHStack (spacing 0), padding
inside, reverse as SingleChildScrollView does it (iOS 16 fallback), itemExtent a fixed main frame; GridNodeView
LazyVGrid/LazyHGrid with fixed items framed by GridCells; shrinkWrap stays lazy (HugLayout around the ScrollView), as
Kotlin and Flutter; an unbounded scroll axis lays out eagerly (EagerGridLayout). onScroll* through the existing
ScrollTriggers; Layout.swift unchanged.
Not done: SwiftUI builds only rows on screen (10 rows, 6 cells where Flutter builds 17 and 10), documented. Not
checked: the iOS 16 reverse fallback, a list inside a same-axis SingleChildScrollView (hand check).
Review nits kept as follow-ups: LazyScroll is a third copy of the reversible ScrollView (Layout.swift, Pager.swift);
an eager grid in right-to-left puts left padding on the right on both SDKs (Flutter's EdgeInsets are absolute).

### Group 6
Commits: K-bar 3119760 then its rework ab82739, S-bar b12b4b8 then a test control 63cefcb (staged by path). Nothing
pushed. Both reviewed (fit and quality); K-bar went back once, S-bar passed with nits. Group 6 approved under the
standing rule.

#### Task K-bar · Kotlin Scrollbar thumb and ScrollbarThumb
Files: `sdk-kotlin/core/.../render/ScrollbarThumb.kt` (new) · `.../render/ScrollbarThumbTest.kt` (new) ·
`sdk-kotlin/sdk/.../widgets/Scrollbar.kt` (new) · `.../widgets/Layout.kt` · `.../widgets/ScrollbarTest.kt` (new)
Cases: A5.7 kt → green; after the rework `./gradlew build` core 431 / sdk 490, lint clean. Red first each pass.
Changed: ScrollbarThumb.span gives Flutter's ScrollbarPainter numbers on Android (minLength 48, margins 0,
thickness 4, opaque #BCBCBC); ScrollbarFade 600 ms wait, 300 ms fastOutSlowIn fade, thumbVisibility keeps it
shown. ScrollbarWidget provides LocalScrollbarHost; the scroll view directly inside reports (ScrollWidget here, the
lazy views in K-pull) and clears the local for its content; right-to-left puts the thumb on the left.
Rework (review, checked against Flutter, widgets/scrollbar.dart:2027-2036): the thumb showed only when the offset
moved; Flutter also shows it on OverscrollNotification, so a drag against an edge now shows it. Turning
thumbVisibility off now fades the thumb out (didUpdateWidget); the 600 ms wait delays instead of asking for frames.
Decided: no shrink on overscroll; no system-bar margin (documented).

#### Task S-bar · Swift Scrollbar, indicators hidden otherwise
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Scrollbar.swift` (new) · `NodeView.swift` · `.../ScrollbarTests.swift` (new)
Cases: A5.7 sw → green: 7 iOS-hosted `testA5_7…` plus 1 macOS; `swift test` UI 307 / core 419; iOS scheme UI 393 /
core 419, goldens unchanged. Red first (no Scrollbar drawn; iOS showed its default indicator; no flash).
Changed: ScrollbarView passes thumbVisibility in `orcaScrollbar`; ScrollIndicators on the four scroll kinds shows the
iOS indicator under a Scrollbar and hides it otherwise on iOS (Flutter on mobile draws none; macOS keeps its
default), clearing the value for nested scroll views; thumbVisibility flashes the indicator on appear (iOS 17+) and at
each scroll end (iOS 18). The scroll-end test gained a thumbVisibility-false control (review nit).
Decided (main session): iOS cannot keep its system indicator shown, so thumbVisibility flashes it (no timer per view);
thickness is not settable on iOS (documented). The flash tests read UIKit's private indicator view (CI pins iOS 18.5).

### Group 7
Commits: D1 e7ccb2b (ahead of its group), K-pull f6a983b, S-pull 22c08a2 then its fix cd57d64 (staged by path).
Nothing pushed. K-pull and S-pull reviewed (fit and quality); each went back once. Group 7 approved under the
standing rule.

#### Task D1 · Demo page lists on parity-a
Files: `examples/server/parity-a.ts` · `examples/server/index.ts` · `engine/test/parity-a-lists.test.ts` (new)
Cases: A5.x eng → the shape case green; "A5 each native vector gets the lists page whole" red by plan until G8, green
after S-caps (2/2). Changed: page `lists` per D7: a 1,000-row ListView counting the rows it builds, horizontal and
reversed lists, a 2-column GridView, three PageViews (onScrollEnd offset shown, vertical, free), a Scrollbar beside a
list without one, and a PullToRefresh whose onRefresh is RefetchPage beside a server fetch count, an app-state counter
(kept) and a page-state counter (reset). The fetch count changes per fetch (cachePolicy defaults to "none").

#### Task K-pull · Kotlin PullToRefresh; Scrollbar on lists
Files: `sdk-kotlin/sdk/.../widgets/Refresh.kt` (new) · `.../RefreshTest.kt` (new) · `.../widgets/Lists.kt` ·
`.../widgets/Pager.kt` · `.../widgets/ScrollbarTest.kt`
Cases: A5.5 kt (8), A5.7 kt on ListView, GridView and PageView (6) → green; `./gradlew build` sdk 488, core 427.
Changed: PullToRefreshWidget a material3 PullToRefreshBox, spinner while the fired Job runs, colours from the props,
the circle resting at displacement + 4. EdgeStart (reset on each finger down) lets only a drag begun at the top start
it, as Flutter's onEdge, and takes only leftover going down, so the bottom stretch stays. LazyScrollReports replaces
LazyScrollTriggers and PageTriggers: onScroll* plus the Scrollbar report; the eager fallbacks clear the Scrollbar local.
Rework (review): EdgeStart took overscroll both ways; its flag could outlive a refresh into the next gesture; the
eager fallbacks passed the Scrollbar local down.
Decided: a vertical list nested in the wrapped one also starts it (Compose's nested scroll does not say where a scroll
came from; tested, documented, q9); Compose's 160 dp pull threshold kept (Flutter: a sixth of the height); a drag
begun below the top that passes it shows no top stretch (documented).

#### Task S-pull · Swift PullToRefresh through refreshable
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Refresh.swift` (new) · `NodeView.swift` · `.../RefreshTests.swift` (new)
Cases: A5.5 sw → green: 9 iOS-hosted `testA5_5…` plus 1 macOS; `swift test` UI 308 / core 420; iOS scheme UI 401 /
core 420, goldens unchanged. Red first each pass.
Changed: `orcaRefresh` set by PullToRefreshView; RefreshOnPull adds `refreshable` to the vertical scroll view directly
inside (a PageView only vertical and free; a ListView/GridView only when it has a scroll view, not unbounded) and
clears it for scroll views nested inside; the action awaits the fired Task. NodeView routes the four scroll kinds
through one helper (ScrollIndicators, then RefreshOnPull). Depth 0 holds on iOS (nested views get no control).
Rework (review): an unbounded list has no ScrollView, so `refreshable` passed on to a scroll view nested in it.
Decided (main session): UIRefreshControl also refreshes a drag begun below the top that carries past it, where
Flutter's Material RefreshIndicator (onEdge, on every platform) does not; kept native, documented. Colour, background
and displacement are not settable through refreshable (documented).

### Group 8
Commits: K-caps 38368d7, S-caps 7d92ba3 (staged by path). Nothing pushed. Self-reviewed (mechanical). Group 8 approved
under the standing rule.

#### Task K-caps · Kotlin registers and advertises the five
Files: `sdk-kotlin/capabilities.json` · `.../capabilities/Generated.kt` · `.../CapabilitiesTest.kt` · `.../WidgetBuilders.kt`
Cases: A5.x caps unit kt → green (`a5_x_theFiveScrollWidgetsAreAdvertisedAndLetThrough`, red first); pins 55 → 60;
c1 red by plan until S-caps, green after. standard() registers the five; Generated.kt from the generator (hash
a954169b…), Generated.swift byte-identical.

#### Task S-caps · Swift advertises the five widgets
Files: `sdk-swift/capabilities.json` · `.../Capabilities/Generated.swift` · `.../CapabilitiesTests.swift` ·
`.../StructureWidgetTests.swift`
Cases: A5.x caps unit sw → green (`testA5TheFiveScrollWidgetsAreAdvertised`, red first); pins 55 → 60; same hash as
Kotlin; Generated.kt byte-identical. `bun test test/parity-a-lists.test.ts` 2/2: no native vector drops a node.

### Group 9
Hand-check fixes, the rebases and their fallout. Commits: S-nest 253258d, its rework 525cae2, merge fallout c90c9f3,
R-sub f66edac (staged by path). Nothing pushed. S-nest reviewed (fit and quality; went back once, RTL); R-sub
reviewed (fit and quality, passed). Group 9 approved under the standing rule.

#### Task S-nest · Swift: a nested refresh list keeps its pull; a pager's drag stays with it
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Pager.swift` · `.../Widgets/Refresh.swift` · `.../PagerTests.swift` ·
`.../RefreshTests.swift`
Cases: A5.5 sw nested (found by the hand check: a pull at the top of the list inside the page's scroll view moved the
page) and A5.4 sw (a drag along a pager no longer also scrolls the view around it) → green, red first.
Changed: KeepPullAnchor finds the list's UIScrollView by its frame in the window and, on iOS 17.4+, stops the
outer one taking the edge drag; the pager makes the outer pans wait for its own. Rework (review): the frame match
used minX in right-to-left layouts; now maxX there (525cae2). iOS 16-17.3 keep UIKit's hand-off (no public switch).

#### Task Merge · refetchPage onto main's SubPage (main session, in the rebase on 644d5d8)
Files: `sdk-kotlin/core/.../render/PageRenderer.kt` (`replace(page, keep)`) · `sdk-kotlin/sdk/.../OrcaPageModel.kt`
(`replacePage`) · `sdk-swift/Sources/OrcaGatewayCore/Render/PageRenderer.swift` (`replacing(with:keep:)`) ·
`sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift` (`replacePage`) · count pins and the unknown-kind tests.
Changed: as Flutter's onRefetchPage and ComponentStore.init: page-state keys under a sub-page prefix are carried over,
nodes under a mounted prefix stay (the new page wins on a shared id), the root is the new first node, and a SubPage
whose node did not come back is unmounted. The not-yet-implemented kind in the executor tests is now closeDialog
(refetchPage is implemented here). Decisions: refetch-keeps-subpages, unknown-kind-in-tests,
reorderable-list-scroll-wrappers (main's ReorderableListView is not wired to Scrollbar/PullToRefresh here: follow-up).

#### Task R-sub · tests for the merge, both SDKs
Files: `sdk-kotlin/core/.../render/RenderTreeTest.kt` · `sdk-kotlin/sdk/.../widgets/SubPageTest.kt` ·
`sdk-swift/Tests/OrcaGatewayCoreTests/RenderTreeTests.swift` · `sdk-swift/Tests/OrcaGatewayTests/SubPageTests.swift`
Cases: A5.6 with SubPages → 6 cases (Flutter's `sub_page_widget_test.dart:860-902` ported with its data; an unmount
case; a renderer unit case), each red on a temporary naive merge, then green with the sources restored. No fix needed.
Decided: the host loads through the real OrcaPageLoader; Swift's unmount case shows the SubPage is forgotten by
bringing its node back and seeing `detail/a` fetched again (its controllers are private); page state keeps the carried
key after an unmount, as Flutter's (`component_store.dart:96-103` removes nodes only).

### Rebases
Onto 3518792, then 644d5d8 (main's Phase B steps 12-13: animation, Hero, transitions, reorderable lists, SubPage).
Generated files were regenerated (`schema/gen-native-capabilities.ts`), never hand-merged; the capability lists are
the union of both sides. Pins after: 68 widgets (63 on main), 24 action kinds (23 on main), render fixtures 53,
action fixtures 29. The hashes in groups 1-8 are from before the rebases; the rebased commits keep their messages
(`git log origin/main..HEAD`, 34 commits). Backups: `backup/native-parity-s5-pre-rebase`, `…-pre-rebase2`.

### Test run
On 525cae2, then f66edac for the native suites: engine `bun test` 798/0 · `flutter test` 487 pass, `flutter analyze`
clean · Kotlin `./gradlew cleanTest build --no-build-cache`: core 570, sdk 642, 0 failures, lint clean · `swift test`
UI 456, core 548 · iOS scheme on the simulator UI 560, core 548, TEST SUCCEEDED · app-ios and app-android build.
Hand checks (both devices, before and after the rebases): $SP/s5/hand-checks.md; evidence in phase-a-tests.md A5.

### Blocked
none

### Not done
none. Not checkable by hand on this host: Android's fast fling (adb flings never reached the pager on the overloaded
emulator; a slow swipe turns one page with offset = viewport) rests on `a5_4_kt_aFastFlingMovesOnePage`.

### For ship (stage 10) to know
Known differences and follow-ups go in the PR body: ListView separator wire bug; Flutter Scrollbar without a
controller; same-axis nested drag in the Swift pager; KeepDrag for every nested scroll kind; duplicate Layout.swift
helpers (FreePager/LazyScroll); RTL padding on eager grids; Gradle core:test undeclared inputs; ReorderableListView not
wired to Scrollbar/PullToRefresh; the Android refetch oddity above; from s4: LocalPointerBlocked, InertButton, Modulate.
