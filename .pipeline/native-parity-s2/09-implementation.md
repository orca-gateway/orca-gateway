# 09 · Implementation · native-parity-s2

## Front page

### In one breath
group 1 of 4 · tasks: 3 green, 0 blocked · the contract for step 2 is in place
Action fixtures can run steps with a widget source; fixtures 16-19 pin once, always, debugLog,
onInit-once and the scroll event values; Flutter runs all 19 green and emits a debugLog effect.
The engine's capability filter now looks inside once and always. Native pins count 19 fixtures.
The Swift and Kotlin fixture runners stay red until group 2 (planned, nothing pushed).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 2 (both executors and the demo page), already running. (default: go)

## Appendix

Cases count: 6 rows split per SDK = 12 cells, plus their fixture halves (A2.1, A2.4, A2.5, A2.6) checked with the
row's first native cell; a row is ticked in phase-a-tests.md only when every half passes on both SDKs.

### Group 1
Commits: E1 8fc52d8, F1 527a522, F2 0acbfbd (staged by path). Nothing pushed. Gate 08 approved under the standing
rule (all defaults). Baseline: step 1's final tree (engine 740, Flutter 305, Kotlin sdk 219 + core 301, Swift
macOS 120 + 298, iOS 140 + 298).

#### Task F1 · Fixture steps, Flutter runner, debugLog effect
Files: `schema/action-fixture.schema.json` · `sdk/test/conformance/action_fixtures_test.dart` ·
`sdk/lib/src/state/action_executor.dart` · `schema/fixtures/actions/16_once_per_widget_trigger.json` (new) ·
`schema/fixtures/actions/17_always_and_debugLog.json` (new)
Cases: A2.5 fx, A2.6 fx → green (`flutter test` +309 all passed, analyze clean). Red first: 16/17 failed (the runner
read only `actions`); after the runner change 17 failed on effects (no debugLog effect); then both pass.
Changed: the schema holds `actions` or `steps` (oneOf, additionalProperties false), Step {action, source?
{widgetId, trigger}, event?}, Effect "debugLog" {level, tag, message?, data?}. The runner runs `actions` as
source-less steps through the same loop. Flutter's executor emits the debugLog effect inside its guard, before the
log line (additive; no timestamp, no include* data). 16: once counters same widget+trigger 1, other trigger 1,
other widget 1, no source 2. 17: always twice 2; debugLog defaults {debug, orca, "count is 2"}; a second with
warn/checkout, data and includeState true (include* never reach the effect).
Review fit: pass · Review quality: pass
Not done: no schema validator in the repo; two baseline `dart format` lines left alone.

#### Task F2 · Fixtures 18, 19 and native pins
Files: `schema/fixtures/actions/18_onInit_once.json` (new) · `schema/fixtures/actions/19_scroll_event_values.json`
(new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` ·
`sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `.../core/FixturePathsTest.kt`
Cases: A2.1 fx, A2.4 fx → green (Swift ModelRoundTripTests 9/9; Kotlin ModelRoundTripTest + FixturePathsTest 9/9;
Flutter runs 18/19 green). Red first: 17 files found, 19 expected. Expected red until group 2: Swift
ActionFixtureTests and Kotlin ActionFixtureTest (count 15, no `steps`).
Changed: 18 = once(setState inits +1) run twice from source {w, onInit} → inits 1. 19 = onScrollBegin, onScrolling
twice, onScrollEnd from widget "scroll", each with its own event shaped as Flutter's _scrollEventData (delta only on
onScrolling); offset, maxExtent, atEnd, delta copied into page state. Round-trip tests count 19, decode
`steps[].action`, assert exactly one of actions or steps, keep the every-advertised-kind check.
Review fit: pass · Review quality: pass

#### Task E1 · Engine filter recurses into once/always
Files: `engine/src/core/capability-filter.ts` · `engine/test/capability-filter.test.ts`
Cases: A2.5 eng → green (capability-filter tests 14 pass; `bun test` 743 pass 0 fail; `tsc --noEmit` on src
clean). Red first: Once(OpenUrl) and Always(OpenUrl) left openUrl out of droppedFeatures.
Changed: walkSingleAction checks once/always's inner action as if unwrapped and returns (a Value kind inside it is
not counted twice). 3 tests "A2.5 eng": wrapped OpenUrl filters exactly as OpenUrl alone; Once(SetState) passes.
Review fit: pass · Review quality: pass

#### Group 1 test run
engine 743 pass 0 fail · Flutter 309 passed, analyze clean · Swift core: all green except ActionFixtureTests
(expected until S-exec) · Kotlin core: all green except ActionFixtureTest (expected until K-exec). No UI file
changed.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Rebase on origin/main before the PR (PR #32 and #34 touch OrcaApp; main moves).
