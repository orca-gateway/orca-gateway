# 08 · Tasks · native-parity-s19

## Front page

### In one breath
tasks: 15 in 6 groups · widest group: 5 · cases: 7 of 7 placed (14 cells, Swift and Kotlin)
Plan step 19 on both native SDKs: resolver traces, traced rebuilds and setState, network
bodies, Flutter's two capture toggles, the debug overlay; fixtures validated against the schema.
G1 the shared fixtures, a schema validator and both builders (T3 lands before T4/T5);
G2 options and gates; G3 traces; G4 action traces; G5 the overlay; G6 demos, READMEs, hand checks.

### New for you
nothing new

### Trade-offs
3 auto-decided: rows C19.1-C19.7 corrected to Flutter (debugLog gets no new event type, as
Flutter); a bun validator test, no new dependency; X-Orca-Debug and server timing left out

### Questions for you
1. Commands: as step 18 (Swift on the iOS 18.5 simulator CI uses), plus Flutter, DevTools and
   the engine at G1 and G6. (default: as found)
2. Commits: one per task on feat/native-parity-s19 from main 6a7f0e0; PR after G6. (default: yes)
3. One gate per group, 6 groups. (default: yes)
4. Leave the X-Orca-Debug header and the server half of timing for a follow-up. (default: yes)

## Appendix

### Where step 19 comes from
Plan step 19 of /Users/amrebada/.claude/plans/native-parity/plan.md ("DevTools and debug parity", M): on-screen debug
overlay; prop traces and transform traces from the resolvers; affected widgets on action events; request and response
bodies; capture toggles; a debugLog sink. Core: resolveWithTrace in both resolvers. Rows C19.1-C19.7 in phase-c-tests.md.
Stages 01-07 skipped as covered by the plan (the Phase C brief). Branch feat/native-parity-s19 from origin/main 6a7f0e0
(PR #40), in the Phase C worktree once step 18's PR #38 is pushed.

### Checked before planning (2026-11-16)
A read-only pass over Flutter, the wire contract and both natives (session scratchpad `s19/facts.md`, file:line).
Flutter: OrcaDebugConfig showOverlay, logTimings, captureStateChanges, captureNetworkRequests, includeBodies
(orca_debug.dart:5-30); resolveWithTrace (value_resolver.dart:374-410: state, event, input and per-op steps, Dart
text); traced props of watched nodes sent as widget_rebuild when non-empty (component_renderer.dart:206-228); setState
transformTrace and exact-key affectedWidgets (action_executor.dart:258-298); bodies (appState, parsed JSON or raw
text) only with includeBodies, five headers redacted (orca_client.dart:370-501); the bottom-right chip overlay
(debug_overlay.dart:3-78); debugLog reaches Orca DevTools only as its action event (action_executor.dart:431-550).
Natives: no trace, empty propTraces on a watched change only, no action trace fields, no bodies, no toggles, no
overlay; debugLog already logs to os.Logger / logcat and sends the action event. No schema validator anywhere.

### Row corrections (to write into phase-c-tests.md with the evidence)
- C19.1: every resolution of a watched node (the first included) traces its Map-valued props; widget_rebuild is sent
  when some trace is non-empty; Flutter's step kinds and Dart text.
- C19.2: setState with a transform value carries its transformTrace; affectedWidgets = exact-key watchers
  {id, type, watches}; animate* not applicable (no native animate actions).
- C19.3: includeBodies (default off): requestBody (page fetch: the appState sent; other requests: their JSON body),
  responseBody (JSON, else raw text); the five headers always redacted; no size cap.
- C19.4: Flutter's two toggles: captureStateChanges, captureNetworkRequests (default on); nothing else gated.
- C19.5: showOverlay (default off, DevTools on): the bottom-right chip "<load>ms", tap expands Load / Components /
  Cache "-"; hand-checked on both devices.
- C19.6: a debugLog action reaches Orca DevTools as its action event (debugLog, family custom) and the platform log,
  as Flutter's; no new event type (the schema has none).
- C19.7: each event type has a fixture every SDK builds byte-equal; new fixtures for the new fields; every fixture
  validated against devtools-events.schema.json by a bun test.

### Design (written here; 05-07 skipped)
Session scratchpad `s19/design.md`: D1 debug options in the cores (Flutter's fields and defaults; gates in ElmStore
and OrcaClient; logTimings to the platform log), D2 resolveWithTrace (Flutter's steps, DartFormat.string text, not
reentrant), D3 traced widget_rebuild from the cores' PageRenderer (the UI's empty emission goes), D4 setState
transformTrace and affectedWidgets through a node hook the page sets, D5 network bodies in OrcaClient.send, D6 the
overlay in the UI layers, D7 fixtures (devtools: action-traced, network-bodies, widget_rebuild-traced; a new
schema/fixtures/traces/ folder run by all three SDKs) and a bun validator, D8 demos, READMEs, hand checks.

### Cases (07 rows of this slice; each has a Swift cell /S and a Kotlin cell /K)
C19.1 (fixture) traced widget_rebuild · C19.2 (fixture) traced setState and affectedWidgets · C19.3 (unit) bodies
and redaction · C19.4 (unit) capture toggles · C19.5 (hand) overlay with timings · C19.6 (unit) debugLog to DevTools ·
C19.7 (fixture) events validate against the schema.

### Groups
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Bun validator for DevTools fixtures | engine/test/devtools-events-schema.test.ts (new) | C19.7 schema part (shared by /S and /K) | S | — |
| 1 | T2 | Trace fixtures, Flutter resolveWithTrace runner | schema/fixtures/traces/01_state_ref.json · 02_event_ref.json · 03_transform_pipeline.json · 04_nested_refs.json (new) · sdk/test/conformance/trace_fixtures_test.dart (new) | trace fixtures of C19.1, C19.2 | M | — |
| 1 | T3 | DevTools fixtures for traces and bodies (lands first in G1) | schema/fixtures/devtools/action-traced.json · network-bodies.json · widget_rebuild-traced.json (new) · sdk/test/conformance/devtools_events_test.dart | event fixtures of C19.1-C19.3 | M | — |
| 1 | T4 | Swift builders: TraceStep, traced action, bodies | sdk-swift/Sources/OrcaGatewayCore/Debug/DevToolsEvent.swift · sdk-swift/Tests/OrcaGatewayCoreTests/DevToolsEventTests.swift | C19.7/S | S | T3 (same group, after it) |
| 1 | T5 | Kotlin builders: TraceStep, traced action, bodies | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/debug/DevToolsEvent.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/debug/DevToolsEventTest.kt | C19.7/K | S | T3 (same group, after it) |
| 2 | T6 | Swift debug options, gates, bodies | sdk-swift/Sources/OrcaGatewayCore/Debug/OrcaDebug.swift · State/ElmStore.swift · Client/OrcaClient.swift · sdk-swift/Tests/OrcaGatewayCoreTests/DebugOptionsTests.swift (new) | C19.3/S, C19.4/S | M | T3, T4 |
| 2 | T7 | Kotlin debug options, gates, bodies | sdk-kotlin/core/.../debug/OrcaDebug.kt · state/ElmStore.kt · client/OrcaClient.kt · core/src/test/.../debug/DebugOptionsTest.kt (new) | C19.3/K, C19.4/K | M | T3, T5 |
| 3 | T8 | Swift resolveWithTrace, traced widget_rebuild | sdk-swift/Sources/OrcaGatewayCore/Resolver/ValueResolver.swift · Render/PageRenderer.swift · sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift · Tests/OrcaGatewayCoreTests/PropTraceTests.swift (new) · Tests/OrcaGatewayTests/DevToolsClientTests.swift | C19.1/S | M | T2, T3, T4 |
| 3 | T9 | Kotlin resolveWithTrace, traced widget_rebuild | sdk-kotlin/core/.../resolver/ValueResolver.kt · render/PageRenderer.kt · sdk/.../OrcaPageModel.kt · core/src/test/.../debug/PropTraceTest.kt (new) · sdk/src/test/.../debug/DevToolsUiReportingTest.kt | C19.1/K | M | T2, T3, T5 |
| 4 | T10 | Swift action trace, affectedWidgets, debugLog | sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift · State/ActionReducer.swift · sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift · Tests/OrcaGatewayCoreTests/ActionTraceTests.swift (new) · Tests/OrcaGatewayTests/LifecycleTests.swift | C19.2/S, C19.6/S | M | T3, T4, T8 |
| 4 | T11 | Kotlin action trace, affectedWidgets, debugLog | sdk-kotlin/core/.../state/ActionExecutor.kt · state/ActionReducer.kt · sdk/.../OrcaPageModel.kt · core/src/test/.../debug/ActionTraceTest.kt (new) · sdk/src/test/.../widgets/LifecycleTest.kt | C19.2/K, C19.6/K | M | T3, T5, T9 |
| 5 | T12 | Swift overlay, debug config, logTimings | sdk-swift/Sources/OrcaGateway/Debug/DebugOverlay.swift (new) · OrcaApp.swift · Debug/DevToolsClient.swift · Tests/OrcaGatewayTests/DebugOverlayTests.swift (new) | C19.5/S unit part | M | T6 |
| 5 | T13 | Kotlin overlay, debug config, logTimings | sdk-kotlin/sdk/.../debug/DebugOverlay.kt (new) · OrcaApp.kt · debug/DevToolsClient.kt · sdk/src/test/.../debug/DebugOverlayTest.kt (new) | C19.5/K unit part | M | T7 |
| 6 | T14 | iOS demo switches, Swift README | examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md · sdk-swift/README.md | C19.5 hand/S, DevTools hand check iOS (enables) | M | T12 |
| 6 | T15 | Android demo switches, Kotlin README | examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/README.md · sdk-kotlin/README.md | C19.5 hand/K, DevTools hand check Android (enables) | M | T13 |

### Order, and why each boundary
- One Swift and one Kotlin task per group; the shared-file tasks (T1-T3) only in G1, never beside a native task's files.
- G1 alone, T3 first: its three fixtures break the Flutter, Swift and Kotlin bijections until each SDK builds them,
  so T3 (with Flutter's builders) lands, then T4 and T5 build them; DevTools' fixture test picks them up unedited; T1
  checks all eleven fixtures. G1's run adds `flutter test` (sdk, devtools) and `bun test`.
- 1 → 2: T6/T7 send bodies through the builders T4/T5 extend; compared with network-bodies.json.
- 2 → 3: T8/T9 return T4/T5's TraceStep, run T2's trace fixtures and match widget_rebuild-traced.json; the tests that
  expected empty propTraces move to the new truth.
- 3 → 4: T10/T11 trace a setState transform with T8/T9's resolveWithTrace; OrcaPageModel goes T8 then T10.
- 4 → 5: OrcaDebug.start copies the toggles, includeBodies and logTimings into T6/T7's core options; showOverlay is the
  UI's.
- 5 → 6: the demos' ORCA_OVERLAY and ORCA_BODIES switches; G6 runs every suite, then the session's hand checks.

### Seams
none: no file is named by two tasks of one group. OrcaPageModel goes T8 → T10 (Swift), T9 → T11 (Kotlin).

### Done when
test: `cd sdk-swift && swift build --build-tests && swift test` (0 warnings) · `cd sdk-swift && xcodebuild test -scheme
OrcaGateway-Package -destination 'id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773' -only-testing:OrcaGatewayTests` (iOS 18.5,
CI's runtime) · `cd sdk-kotlin && ./gradlew build --console=plain` · at G1 and G6 also `cd sdk && flutter test`, `cd
devtools && flutter test`, `cd engine && bun test`; at G6 both example builds
lint: in the Gradle build; Swift warnings counted · typecheck: none
baseline: engine 751 · Flutter 349 · DevTools 17 · Swift core 376, SwiftUI (macOS) 257, 0 warnings · Kotlin core 377,
sdk 374 (origin/main 6a7f0e0, 2026-11-16)
Green at 09: the task's cases pass and nothing that passed here fails.

commits: per task (feat/native-parity-s19) · gate: per group (answered at gate 08, 2026-11-16, standing rule)

### Not planned
none: all 7 cases are placed (14 cells); the session runs C19.5's hand cells and the DevTools hand check after G6.
Follow-ups, not cases: the X-Orca-Debug header and server timing; Flutter's firstFrameMs (always 0); network scope
(natives report every request); animate* affectedWidgets (no native animate actions).
