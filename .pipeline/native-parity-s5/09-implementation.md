# 09 · Implementation · native-parity-s5

## Front page

### In one breath
group 3 of 8 · tasks: 6 green, 0 blocked · A5.6 fx green on both SDKs; both advertise 21 kinds
S-act, K-act: refetchPage is a known kind (no handler: nothing, no effect, as Flutter); one hash.
Fixture 48 now runs on Swift and Kotlin; the G1 reds are gone. A baseline Swift test that used
refetchPage as its "not implemented" example now uses animateForward, as its Kotlin twin.
Ahead of their groups: G4 (S-page, K-page) and K-list (G5) running.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 4 (PageView), already running. (default: go)

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

### Test run
engine `bun test` 755/0 · `flutter test` 352 pass · Swift core 397, 2 expected reds · Kotlin core 398, 2 expected reds

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing
