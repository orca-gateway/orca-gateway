# 09 · Implementation · native-parity-s5

## Front page

### In one breath
group 1 of 8 · tasks: 2 green, 0 blocked · fixtures 44 and 48 green on engine (755), Flutter (352)
F1 fixtures 44 (the five, every wire prop) and 48 (refetchPage: no effect); Swift pins 46 and 25.
F2 Kotlin pins 46 and 25. Native fixture-48 checks red until G3, as planned (q6).
Ahead of their groups: K-refetch committed; S-refetch in a short rework; G3 (S-act, K-act) running.

### New for you
nothing new

### Trade-offs
2 auto-decided (minor), documented: after a refetch the natives keep `once` keys (Flutter resets
them because it builds a new executor on every page build) and show the new page's title (Flutter
keeps the first page's).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 2 (refetchPage in place); G3 already running, files disjoint. (default: go)

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

### Test run
engine `bun test` 755/0 · `flutter test` 352 pass · Swift core 397, 2 expected reds · Kotlin core 398, 2 expected reds

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing
