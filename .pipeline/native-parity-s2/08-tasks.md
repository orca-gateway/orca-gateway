# 08 · Tasks · native-parity-s2

## Front page

### In one breath
tasks: 10 in 4 groups · widest group: 3 · cases: 6 of 6 placed
Plan step 2 on both SDKs: lifecycle and scroll triggers, once/always/debugLog, the widget source.
G1 (contract): action fixtures 16-19 (new `steps` with a source), green on Flutter first; native
count pins; the engine filter looks inside once/always. Flutter emits a debugLog effect (additive).
G2: both executors gain source, once, always and debugLog and advertise them; demo page `lifecycle`.
G3: onInit, onVisible and onBackground/onForeground fire from a wrapper around each node.
G4: SingleChildScrollView fires the three scroll triggers with offset, extents and edges.

### New for you
nothing new

### Trade-offs
3 auto-decided (minor, standing rule): serial groups (q4); native fixture runners red from G1 to
G2, nothing pushed between (q5); Kotlin app events from ProcessLifecycleOwner, ON_STOP ~0.7 s late
(q7). On iOS 16-17 Swift finds the end of a scroll by waiting (D7).

### Questions for you
1. Commands: every suite as at baseline; Swift on macOS and iOS 18.5. (default: as found)
2. Commits: one per task on feat/native-parity-s2; nothing pushed before stage 10. (default: yes)
3. One gate per group, 4 groups. (default: yes)
4. One Swift and one Kotlin task per group (one build tree each), no worktree each. (default: yes)
5. Native action-fixture runners red from G1 until G2 lands (count 19, `steps`). (default: yes)
6. Rows as corrected: A2.2 onVisible once on mount; A2.6 Flutter emits debugLog. (default: yes)
7. Kotlin app events from ProcessLifecycleOwner, not the page's NavHost entry. (default: yes)
8. onInit/onVisible do not fire again when a covered page pops back, as Flutter. (default: yes)

## Appendix

### Where step 2 comes from
Plan `/Users/amrebada/.claude/plans/native-parity/plan.md`, Phase A step 2 ("Lifecycle and triggers", M). Stages
05-07 were skipped. The design in force is `.pipeline/native-parity-s2/design.md` (D1-D10, rows A2.1-A2.6 after
corrections). The gaps with file:line are in `.pipeline/native-parity-s2/inventory.md`. Branch feat/native-parity-s2
is stacked on feat/native-parity-s1 (PR #33).

### Groups
Paths are from the repo root. `sw`/`kt` mark the Swift/Kotlin half, `fx` the fixture half and `eng` the engine half.

| # | Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|---|
| 1 | 1 | F1 | Fixture steps, Flutter runner, debugLog effect | schema/action-fixture.schema.json · sdk/test/conformance/action_fixtures_test.dart · sdk/lib/src/state/action_executor.dart · schema/fixtures/actions/16_once_per_widget_trigger.json (new) · schema/fixtures/actions/17_always_and_debugLog.json (new) | A2.5 fx, A2.6 fx | M | — |
| 2 | 1 | F2 | Fixtures 18, 19 and native pins | schema/fixtures/actions/18_onInit_once.json (new) · schema/fixtures/actions/19_scroll_event_values.json (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt | A2.1 fx, A2.4 fx | M | — |
| 3 | 1 | E1 | Engine filter recurses into once/always | engine/src/core/capability-filter.ts · engine/test/capability-filter.test.ts | A2.5 eng (an unadvertised kind inside once still degrades) | S | — |
| 4 | 2 | S-exec | Swift executor source, once, always, debugLog | sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift · sdk-swift/Tests/OrcaGatewayCoreTests/ActionFixtureTests.swift · sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift | A2.5 sw (fx 16), A2.6 sw (fx 17), A2.1 sw (fx 18), A2.4 sw (fx 19) | M | F1, F2 |
| 5 | 2 | K-exec | Kotlin executor source, once, always, debugLog | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionFixtureTest.kt · sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt | A2.5 kt (fx 16), A2.6 kt (fx 17), A2.1 kt (fx 18), A2.4 kt (fx 19) | M | F1, F2 |
| 6 | 2 | D1 | Demo page lifecycle on parity-a | examples/server/parity-a.ts · examples/server/index.ts | A2.2 hand, A2.3 hand (sw and kt) | S | — |
| 7 | 3 | S-life | Swift lifecycle triggers, tap source, log | sdk-swift/Sources/OrcaGateway/Widgets/Lifecycle.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift · sdk-swift/Tests/OrcaGatewayTests/LifecycleTests.swift (new) | A2.1 sw (unit), A2.2 sw (unit), A2.3 sw (unit), A2.5 sw (second tap) | M | S-exec |
| 8 | 3 | K-life | Kotlin lifecycle triggers, tap source, log | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Lifecycle.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/NodeView.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageModel.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/LifecycleTest.kt (new) | A2.1 kt (unit), A2.2 kt (unit), A2.3 kt (unit), A2.5 kt (second tap) | M | K-exec |
| 9 | 4 | S-scroll | Swift scroll triggers with offsets | sdk-swift/Sources/OrcaGatewayCore/Render/ScrollEvent.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ScrollEventTests.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Layout.swift · sdk-swift/Tests/OrcaGatewayTests/ScrollTriggerTests.swift (new) | A2.4 sw (ui) | M | — |
| 10 | 4 | K-scroll | Kotlin scroll triggers with offsets | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/ScrollEvent.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/ScrollEventTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Layout.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ScrollTriggerTest.kt (new) | A2.4 kt (ui) | M | — |

Placed: A2.1 F2/S-exec/K-exec (fx) + S-life/K-life (unit) · A2.2, A2.3 S-life/K-life (unit) + D1 (hand) ·
A2.4 F2/S-exec/K-exec (fx) + S-scroll/K-scroll (ui) · A2.5 F1/S-exec/K-exec (fx) + E1 (eng) + S-life/K-life
(tap) · A2.6 F1/S-exec/K-exec (fx).

### Order, and why each boundary
- Each SDK has one build tree, so a group holds at most one Swift and one Kotlin task. F2 edits both SDKs' tests,
  so it takes both slots in G1.
- G1: the contract comes first. F1 adds `steps` (oneOf with `actions`; items {action, source? {widgetId, trigger},
  event?}) and the `debugLog` Effect {level, tag, message?, data?} to the schema. Flutter is the reference and runs
  16-19 green: its runner passes ActionSource and the per-step event, and its executor makes the additive `_emit`
  call before developer.log, inside its guard. F2's pins (15 → 19) count F1's two files as well, and Flutter's
  runner runs F2's fixtures, so F1 and F2 are checked together at the G1 gate. E1 recurses into `a.action` for
  once/always (capability-filter.ts:340-374). It must land before G2 advertises them.
- 1 → 2: S-exec and K-exec run 16-19 in their runners (steps, source, per-step event) and advertise the three
  kinds. Until then their ActionFixtureTests are red by design (q5). D1 cannot sit in G1:
  engine/test/demo-server.test.ts:15 starts examples/server/index.ts while E1 runs the engine suite.
- 2 → 3: S-life and K-life call `execute(action, eventData:, source:)` and ActionSource from G2, so fire passes
  (node.id, trigger).
- 3 → 4: only the build tree separates these groups. The scroll tasks use the existing `fire(trigger, on:,
  eventData:)`. The payload and the begin/scrolling/end order are pure logic and go in the cores (ScrollEvent).
  The UI only feeds it samples.
- Hand checks A2.2 and A2.3 (plus a look at A2.4-A2.6) run on D1's page `lifecycle` after G4, on the iPhone
  simulator and the Android emulator.

### Seams
- `bun run schema/gen-native-capabilities.ts` writes Generated.swift and Generated.kt in one run (:256-262).
  S-exec stages only Generated.swift and K-exec only Generated.kt; the last of the two reruns it, and both diffs
  are clean at the G2 gate.
- CapabilitiesTest.kt:80 asserts Swift's actionKinds equal Kotlin's. It goes green when both G2 tasks land.
- OrcaPageModel.swift belongs to S-life only and OrcaPageModel.kt to K-life only (source on fire, the debugLog
  print, the lifecycle guard).
- No golden is listed. If any golden moves, the task stops: wrappers apply only to nodes that carry a lifecycle
  trigger, and scroll observers add no layout.

### Findings (planner, checked against the code)
- More count pins than the runners: ModelRoundTripTests.swift:39, ModelRoundTripTest.kt:58 and
  FixturePathsTest.kt:14 all pin 15. The two round-trip tests read only `fixture["actions"]` (:42, :61) and must
  also read `steps[].action`. They assert that every advertised kind appears in a fixture (:65, :84), so fixtures
  16 and 17 must hold once, always and debugLog.
- CapabilitiesTests.swift:41,44 and CapabilitiesTest.kt:78,83 pin 15 kinds and require executor `kinds` ==
  advertised. The kinds and capabilities.json therefore change in the same task (15 → 18).
- Kotlin pages live in NavHost entries (OrcaApp.kt:364-371). There, LocalLifecycleOwner stops when a page is
  pushed, and the covered page's composition is disposed, so LaunchedEffect would fire onInit again on pop-back.
  Hence ProcessLifecycleOwner for app events (lifecycle-process is declared, SessionLifecycle.kt; q7) and a guard
  that survives the composition (page model or rememberSaveable; q8). Swift's `.task` restarts on reappear, so
  the guard is D5's @State.
- The engine has no fixture or effect type, and once/always/debugLog are already in action.ts, so the engine's
  only sync point is E1. Flutter's generated.dart already advertises all three (no gen-sdk-capabilities run).
- Kotlin Input.kt:137 already goes through `model.fire("onChange")`, so K-life's fire carries the source. Swift
  textChanged (OrcaPageModel.swift:107-123) calls run directly: S-life passes (node.id, "onChange").
- Swift ScrollNodeView (Layout.swift:248-281) has three ScrollView branches (plain, defaultScrollAnchor,
  ScrollViewReader). The observer goes on all three, and only when a scroll trigger is set (BH:46-71).
- debugLog belongs in the executor (it needs the resolver), and ActionReducer stays as it is. Unit tests (source
  restored after nested runs, once without a source, Flutter's shared-key limit pinned and documented) go in
  ActionFixtureTests.

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` (macOS) ·
`xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=DA7254F5-437C-4302-B8A0-A9CDBD4116A4'`
in sdk-swift (derived data in the session scratchpad) · `cd sdk-kotlin && ./gradlew :core:test :sdk:testDebugUnitTest`
lint: `cd sdk && flutter analyze` · `cd sdk-kotlin && ./gradlew build --console=plain` (warnings as errors) ·
codegen: `bun run schema/gen-native-capabilities.ts` leaves no diff.
baseline (feat/native-parity-s2 = step 1's final tree, b9e828e): engine 740 pass · Flutter 305, analyze clean ·
Kotlin sdk 219 + core 301, lint clean · Swift macOS 120 UI + 298 core · iOS 140 UI + 298 core, goldens unchanged.
commits: one per task, staged by path · gate: one per group

### Not planned
None: all 6 cases are placed. Uncovered on purpose (follow-ups): viewport-based onVisible for all three SDKs
(A2.2 corrected); scroll triggers on ListView, GridView and PageView (step 5); two Once wrappers under one widget
and trigger sharing a key (Flutter's limit, kept); debugLog include* flags only add to the host log line, never to
the effect (D3); Flutter's array of actions per trigger (native maps hold one).
