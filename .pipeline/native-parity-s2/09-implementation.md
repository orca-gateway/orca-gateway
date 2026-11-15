# 09 · Implementation · native-parity-s2

## Front page

### In one breath
group 4 of 4 · tasks: 10 green, 0 blocked · A2.1 to A2.6 green in tests on all three SDKs
Both native SDKs now fire onInit, onVisible, background, foreground and the three scroll triggers
as Flutter does, with the widget source for once. Android hand-checked on the `lifecycle` page.
Main moved: #32 and #34 are merged and 19 files overlap, so stage 10 rebases first.

### New for you
nothing new

### Trade-offs
3 auto-decided (minor): Swift scroll edges allow 0.5 pt; on Android a flick at an edge that
moves nothing fires no begin or end; Android pages under a pushed page hear no app events.
The last two are follow-ups, listed in the PR body.

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: stage 10: rebase on main, iPhone hand checks, all suites, then open the PR. (default: go)

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

### Group 3
Commits: K-life 6d78062, S-life 74ae3f5 (staged by path). Nothing pushed. Group 2's card approved under the standing
rule (defaults). K-scroll (group 4) ran ahead of K-life on the Kotlin tree; files disjoint, one Kotlin task at a time.

#### Task S-life · Swift lifecycle triggers, tap source, log
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Lifecycle.swift` (new) · `.../OrcaGateway/NodeView.swift` ·
`.../OrcaGateway/OrcaPageModel.swift` · `sdk-swift/Tests/OrcaGatewayTests/LifecycleTests.swift` (new)
Cases: A2.1, A2.2, A2.3, A2.5 sw (ui), A2.6 host check → green (`swift test` 127 + 306; iOS scheme on DA7254F5 from
clean 146 + 306, TEST SUCCEEDED; no golden moved, 0 warnings). Red first: all 7 (A2.6 only on its log-line check).
Changed: LifecycleTriggers (nil without a lifecycle trigger) and a Lifecycle modifier: onInit then onVisible once per
mount (@State), .background fires the background trigger, .active fires foreground only after a .background,
.inactive nothing, onApp* wins. WatchedNode applies it only when needed, so plain nodes keep their tree. fire passes
ActionSource(node.id, trigger); textChanged passes (node.id, "onChange"); debugLog goes to os.Logger (subsystem
com.orcagateway, category = tag), then to effectHandler.
Decisions: scene phase driven through the environment in a test host (PhaseBox/PhaseHost); levels debug/info as is,
warn → .default, error → .error; swift-debuglog-public (privacy .public, as debugPrint and Log); the "shown again
while still mounted" test is macOS-only (the iOS test runner has no window scene; removing the guard fails it).
Review fit: pass · Review quality: pass

#### Task K-life · Kotlin lifecycle triggers, tap source, log
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Lifecycle.kt` (new) · `.../sdk/NodeView.kt` ·
`.../sdk/OrcaPageModel.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/LifecycleTest.kt` (new)
Cases: A2.1, A2.2, A2.3, A2.5 kt (ui) → green (`./gradlew build` sdk 226, core 309, lint clean; GoldenTest
unchanged). Red first: all 7 (D3 only on its Log assertion); with the guard off the covered-page test fails 2 vs 1.
Changed: LocalOrcaAppLifecycle (ProcessLifecycleOwner, swapped in tests), hasLifecycleTriggers and LifecycleTriggers:
onInit then onVisible from a LaunchedEffect behind a once-per-mount guard; ON_STOP fires background, ON_START fires
foreground only after an ON_STOP; onApp* wins; ProcessLifecycleOwner's ~700 ms ON_STOP delay documented. NodeView
wraps only nodes with a lifecycle trigger. fire passes ActionSource; debugLog goes to android.util.Log.
Decisions: kotlin-lifecycle-guard-page-model (a set on the page model); kotlin-covered-pages-app-events (a page under
a pushed page hears no app events; NavHost disposes it; follow-up).
Review fit: pass · Review quality: one finding (a test helper duplicated inside the Pages host), reworked (helpers
top-level), re-review pass.

#### Group 3 test run
Swift `swift test` 127 + 306, iOS scheme 146 + 306 · Kotlin `./gradlew build` sdk 232 (with K-scroll), core 319,
lint clean · no golden moved.

### Group 4
Commits: K-scroll c8512e9, S-scroll c4f7280 (staged by path). Nothing pushed. Group 3 recorded with group 4.

#### Task S-scroll · Swift scroll triggers with offsets
Files: `sdk-swift/Sources/OrcaGatewayCore/Render/ScrollEvent.swift` (new) · `.../OrcaGatewayCoreTests/ScrollEventTests.swift`
(new) · `sdk-swift/Sources/OrcaGateway/Widgets/Layout.swift` · `sdk-swift/Tests/OrcaGatewayTests/ScrollTriggerTests.swift` (new)
Cases: A2.4 sw → green (13 core, 11 hosted iOS; `swift test` 319 core + 127 UI; iOS scheme on DA7254F5 156 UI + 319
core, 4 goldens unchanged, 0 warnings; scroll tests 3-4 runs in a row). Red first: both test files did not compile.
Changed: ScrollMetrics, ScrollEvent.triggers and ScrollObserver with Kotlin's names and logic. Only a
SingleChildScrollView whose node has a scroll trigger gets the ScrollTriggers modifier (plain ones keep their
ScrollView); a ScrollTracker keeps the observer between redraws. iOS 18 / macOS 15: onScrollGeometryChange and
onScrollPhaseChange. iOS 16-17: a GeometryReader probe in a named coordinate space, a simultaneous DragGesture
starts the scroll, it ends once the offset holds still 0.15 s. Horizontal uses x.
Decisions: an internal `usesScrollPhase` switch runs the iOS 16-17 path on the 18.5 simulator;
swift-scroll-reverse-offset; swift-scroll-edge-tolerance (0.5 pt; SwiftUI geometry is fractional).
Review fit: pass · Review quality: one finding (the iOS 16-17 settle wait outlived the view and could fire
onScrollEnd after it was gone), reworked (stop on disappear; a view back after leaving mid-scroll begins its next
scroll), 2 tests red first; re-review pass.
Not covered by tests (hand check or iOS 16/17 device): a real finger, animated scrolls, the DragGesture start.

#### Task K-scroll · Kotlin scroll triggers with offsets
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/ScrollEvent.kt` (new) ·
`.../core/render/ScrollEventTest.kt` (new) · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Layout.kt` ·
`sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ScrollTriggerTest.kt` (new)
Cases: A2.4 kt → green (10 core, 6 UI; core 309 → 319, sdk 226 → 232; lint, goldens clean; UI tests 3 reruns
green). Red first: all but the no-trigger guard.
Changed: ScrollMetrics (eventData = Flutter `_scrollEventData`), ScrollEvent.TRIGGERS and ScrollObserver (begin,
onScrolling with delta, end; a jump yields all three; no throttling). ScrollWidget adds ScrollTriggers only when the
node sets a scroll trigger: a LaunchedEffect with snapshotFlow over value, maxValue, viewport and
isScrollInProgress, in dp. Plain scroll views keep their tree.
Decisions: onScrollBegin carries the metrics from before the move (Flutter's drag and animateTo);
kotlin-edge-flick-no-begin (hand check: a flick at an edge that moves nothing fires no begin/end; follow-up).
Review fit: pass · Review quality: pass

### Blocked
none

### Not done
none

### Android hand checks (emulator-5594, API 34, app built from 74ae3f5)
Open: onInit 1, onVisible 1, the four app counters 0; logcat `I parity: visible 1`. once x3 → 1, always x3 → 3,
+1 x2 → redraws 2, onInit/onVisible stay 1 (A2.2). Home and back twice: all four app counters 1, then 2 (A2.3).
Scroll box: slow drag offset 82.5, maxExtent 442.2, delta 1.5, one begin, one end; drag then fling to the end:
atEnd true, one more begin and end (no end-then-begin); a slow drag at an edge fires begin/end; a fast flick at an
edge that moves nothing fires none (kotlin-edge-flick-no-begin). The first emulator boot thrashed (2.5 GB, system
and GMS ANRs); the scroll checks ran after a cold restart.

### For ship (stage 10) to know
Rebase on origin/main 96094da first (#32 tabs and drawer, #34 plugin system merged; 19 files overlap: both
executors, all three fixture runners, schema, capabilities). Brief ready: scratchpad s2/brief-rebase.md. Then the
iPhone hand checks and a short Android recheck on the rebased tree, all suites, the three generators.
