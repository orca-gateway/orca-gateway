# 09 · Implementation · native-parity-s5

## Front page

### In one breath
group 6 of 8 · tasks: 12 green, 0 blocked · A5.7 green on both SDKs (core and UI)
K-bar, S-bar: Kotlin draws Flutter's Android thumb (48 min, 4 thick, 600 + 300 ms fade) from a pure
ScrollbarThumb core; iOS shows its own indicator only under a Scrollbar and hides it elsewhere, as
Flutter on mobile. thumbVisibility keeps the Kotlin thumb shown; iOS can only flash its indicator.
Ahead: K-pull, S-pull (G7) and both caps tasks (G8) committed; one S-pull fix running.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 7 (PullToRefresh), one Swift fix in progress. (default: go)

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

### Test run
engine `bun test` 755/0 · `flutter test` 352 pass · Swift core 397, 2 expected reds · Kotlin core 398, 2 expected reds

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing
