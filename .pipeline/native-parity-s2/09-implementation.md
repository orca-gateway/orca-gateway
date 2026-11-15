# 09 · Implementation · native-parity-s2

## Front page

### In one breath
group 2 of 4 · tasks: 6 green, 0 blocked · fixtures 16-19 now green on all three SDKs
Both native executors know which widget and trigger fired an action (ActionSource), and run once,
always and debugLog as Flutter does; capabilities advertise the three kinds (15 → 18).
Demo page `lifecycle` on parity-a is ready for the hand checks after group 4.
Group 3 (lifecycle triggers) is already running on both SDKs.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 3 (onInit, onVisible, background and foreground), already running. (default: go)

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

### Group 2
Commits: D1 fe1d439, S-exec 1c65566, K-exec 74f5831 (staged by path). Nothing pushed. Group 1's card approved under
the standing rule (defaults).

#### Task S-exec · Swift executor source, once, always, debugLog
Files: `sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift` · `.../Tests/OrcaGatewayCoreTests/ActionFixtureTests.swift` ·
`.../CapabilitiesTests.swift` · `sdk-swift/capabilities.json` · `.../Capabilities/Generated.swift`
Cases: A2.5 sw (fx 16), A2.6 sw (fx 17), A2.1 sw (fx 18), A2.4 sw (fx 19) → green (`swift test` 306, 0 failures,
no warnings). Red first: no ActionSource (build), and the old runner failed on 16-19.
Changed: public ActionSource {widgetId, trigger, dedupeKey}; execute/executeAll take a defaulted source, inherited by
nested runs and restored by the eventData defer; once with per-executor fired keys (Flutter's shared-key limit
documented), always, debugLog emitting {level, tag, message?, data?}; kinds +3, implements looks inside
once/always; the runner runs steps; 4 per-case and 4 unit tests; capabilities 15 → 18, regenerated.
Decisions: debugLog data object resolved per entry as Dart; no "<unresolvable>" branch (the Swift resolver never
throws; documented).
Review fit: pass · Review quality: pass

#### Task K-exec · Kotlin executor source, once, always, debugLog
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt` · `.../state/ActionFixtureTest.kt` ·
`sdk-kotlin/capabilities.json` · `.../capabilities/Generated.kt` · `.../capabilities/CapabilitiesTest.kt`
Cases: A2.5 kt, A2.6 kt, A2.1 kt, A2.4 kt → green (`./gradlew build` core 309, sdk 219, lint clean; the Swift ==
Kotlin kinds check green). Red first except A2.4 (fx 19 passed once the runner read steps).
Changed: the same as S-exec in Kotlin (source restored in finally; debugLog never throws, cancellation
propagates); a unit test covers a nested execute from perform.
Decisions: a message that fails to resolve falls back to its raw text, as Dart's toString(); Generated.swift as
written from the Swift list (byte-identical to the Swift task's own run; the generator rerun shows no diff).
Review fit: pass · Review quality: pass

#### Task D1 · Demo page lifecycle on parity-a
Files: `examples/server/parity-a.ts` · `examples/server/index.ts`
Cases: A2.2 hand, A2.3 hand → page ready (GET /api/v1/app/parity-a/page/lifecycle 200, 88 components; 404 before;
`bun test` 743 pass)
Changed: page `lifecycle`: onInit/onVisible counters with a debugLog (level info, tag parity); onBackground/
onForeground on one Column and onAppBackground/onAppForeground on another; a 200x160 SingleChildScrollView of 30
lines showing offset, maxExtent, atEnd, delta, the last trigger and begin/end counts; once, always and +1
buttons. index.ts: one URL line. Built with the file's existing helpers, .new() and V.* only.
Review fit: pass · Review quality: pass

#### Group 2 test run
engine 743 pass · Flutter 309 (no file changed since group 1) · Swift `swift test` 306, 0 failures · Kotlin
`./gradlew build` core 309, sdk 219, lint clean · generators: no diff.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Rebase on origin/main before the PR (PR #32 and #34 touch OrcaApp; main moves).
