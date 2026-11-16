# 09 · Implementation · native-parity-s19

## Front page

### In one breath
group 6 of 6 · tasks: 2 green, 0 blocked · cases: C19.1-C19.7 green (C19.5 by hand) · all green
T14 iOS, T15 Android: ORCA_OVERLAY and ORCA_BODIES demo switches; DevTools sections in the READMEs.
T15 one rework: its README named an x-api-key header the app never sends (it sends Authorization).
Hand checks on both devices: the chip, tap to expand, taps beside it reach the page; each event
sent (traced rebuild, traced setState with affectedWidgets, bodies) validates against the schema.

### New for you
nothing new

### Trade-offs
2 auto-decided: two demo switches only; events captured on :6363 (DevTools window control declined)

### Questions for you
1. Blocked tasks: none. (default: none)
2. `A` approves the stage; then ship: rebase on origin/main and open the step 19 PR. (default: go)

## Appendix

### Group 1
#### T1 · Bun validator for DevTools fixtures (1c49218)
Files: engine/test/devtools-events-schema.test.ts (new)
Cases: C19.7 schema part → green (16 tests; red first against a throwing stub; 19 with T3's fixtures)
Changed: a validator for the keywords the schema uses (type, required, properties, additionalProperties, items,
enum, const, allOf, if/then, $ref), a schema walk that fails on any other keyword, one case per fixture file, negative
cases with readable paths (missing pageId, family "nope", a numeric trace `out`, a string statusCode).
Decisions: only today's keywords (no else, no $defs: they fail loudly) · negatives built inline, not as fixture files
Review fit: pass · Review quality: pass
#### T2 · Trace fixtures, Flutter resolveWithTrace runner (a92ace6)
Files: schema/fixtures/traces/01_state_ref.json · 02_event_ref.json · 03_transform_pipeline.json · 04_nested_refs.json ·
sdk/test/conformance/trace_fixtures_test.dart (all new)
Cases: trace fixtures for C19.1/C19.2 → green on Flutter (+5; a deliberately wrong fixture failed)
Changed: format {name, description, state {page, app}, event?, value, expected {value, trace}}; 01 page and app refs;
02 an event ref; 03 state, input, add, an unknown op skipped, toString; 04 a conditional, a plain map, a missing key
(out "null"), add's `by` ref before add's step (no `in`). The runner reads every file in the folder.
Decisions: order-dependent refs sit in lists (Swift's JSONValue.object is unordered) · "static map" read as a plain
map resolveDeep walks. Note for T8/T9: 03 needs an unknown op skipped, 04 needs `add` to count null as 0.
Review fit: pass · Review quality: pass
#### T3 · DevTools fixtures for traces and bodies (16ff4bf)
Files: schema/fixtures/devtools/action-traced.json · network-bodies.json · widget_rebuild-traced.json (new) ·
sdk/test/conformance/devtools_events_test.dart
Cases: event fixtures of C19.1-C19.3 → green on Flutter (13 pass, all 11 fixtures byte-equal; red first on the bijection)
Changed: setState count + add 1 with transformTrace [state, input, add] and affectedWidgets Text#5, Container#8
{id,type,watches}; a page fetch POST 200 with requestBody (the appState), responseBody, the five headers redacted;
Text#5's propTraces.data [state, input, toString]. Both traces from a real resolveWithTrace run in the test.
Decisions: the trace over count 0 (no null step; T2 covers nulls) · redacted values written as network.json does
Review fit: pass · Review quality: pass
#### T4 · Swift builders: TraceStep, traced action, bodies (9b4dc06)
Files: sdk-swift/Sources/OrcaGatewayCore/Debug/DevToolsEvent.swift · sdk-swift/Tests/OrcaGatewayCoreTests/DevToolsEventTests.swift
Cases: C19.7/S → green (DevToolsEventTests 11; core 377 = 376 + 1; red first: did not compile)
Changed: public TraceStep {op, in?, out}; action transformTrace/affectedWidgets (omitted when empty); network
requestBody/responseBody (present when non-nil); widgetRebuild propTraces [String: [TraceStep]]; the three new fixtures
in the table; testC19_7_EmptyTracesAndMissingBodiesAreLeftOut.
Decisions: a JSON-null body left out as Dart's `!= null` · the old widget_rebuild entry builds a TraceStep (same fixture)
Review fit: pass · Review quality: pass
#### T5 · Kotlin builders: TraceStep, traced action, bodies (cb9ed8e)
Files: sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/debug/DevToolsEvent.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/debug/DevToolsEventTest.kt
Cases: C19.7/K → green (DevToolsEventTest 6/6; core 378 = 377 + 1; red first: compile)
Changed: top-level public TraceStep(op, input, output) written {op, in?, out}; action, network and widgetRebuild as T4;
the three new fixtures in e1; c19_7_emptyTracesNullBodiesAndMissingInAreLeftOut.
Decisions: `input`/`output` property names (`in` is a keyword; Flutter's TransformTrace names them so) · a JsonValue.Null
body left out
Review fit: pass · Review quality: pass

### Group 2
#### T6 · Swift debug options, gates, bodies (c30c4b3)
Files: sdk-swift/Sources/OrcaGatewayCore/Debug/OrcaDebug.swift · State/ElmStore.swift · Client/OrcaClient.swift ·
Tests/OrcaGatewayCoreTests/DebugOptionsTests.swift (new)
Cases: C19.3/S, C19.4/S → green (9 tests; core 386 = 377 + 9; red first: compile, then 7 assertion failures)
Changed: public Sendable OrcaDebugOptions {captureStateChanges, captureNetworkRequests (true), includeBodies, logTimings
(false)} through OrcaDebug.options behind the lock; ElmStore's state_change gated; OrcaClient.send(_:requestBody:) drops
the network event when capture is off (errors still go) and adds requestBody/responseBody with includeBodies (page
fetch: the appState, none when empty; JSON else raw text; none on transport failure).
Decisions: an empty or missing appState shows no requestBody (Flutter's page passes null) · options read once per request
Review fit: pass · Review quality: pass
#### T7 · Kotlin debug options, gates, bodies (63ea4cf, rework db49e6b)
Files: sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/debug/OrcaDebug.kt · state/ElmStore.kt · client/OrcaClient.kt ·
core/src/test/.../debug/DebugOptionsTest.kt (new)
Cases: C19.3/K, C19.4/K → green (7 tests; core 385 = 378 + 7; red first: compile, then 5 assertion failures)
Changed: public data class OrcaDebugOptions with Flutter's defaults, @Volatile OrcaDebug.options; the same gates and
bodies as T6; both handshake sends report the appState.
Decisions: options read once per request · a non-JSON request body falls back to its raw text (never happens today)
Review fit: an empty appState reported `requestBody: {}` where Flutter (orca_page.dart:163-167) and Swift show none,
fixed (db49e6b, new test c19_3_aPageFetchWithAnEmptyAppStateShowsNoRequestBody) · Review quality: pass

### Group 3
#### T8 · Swift resolveWithTrace, traced widget_rebuild (2929f60, rework a2891fe)
Files: sdk-swift/Sources/OrcaGatewayCore/Resolver/ValueResolver.swift · Render/PageRenderer.swift ·
Sources/OrcaGateway/OrcaPageModel.swift · Widgets/Structure.swift (rework, one line) · Tests/OrcaGatewayCoreTests/
PropTraceTests.swift (new) · Tests/OrcaGatewayTests/DevToolsClientTests.swift
Cases: C19.1/S → green (core 390 = 386 + 4; SwiftUI 258 = 257 + 1; red first: compile, then the observer's empty event)
Changed: resolveWithTrace → (value, trace) through a private recorder only the traced call holds (untraced: a nil
check); state, event, input and per-op steps in Dart's text; every traces fixture runs; PageRenderer reports
widgetRebuild with the non-empty traces of a watched node's object props on every build, the first included;
NodeObserver only redraws; the UI rebuild test moved to the new truth (stricter: the observer reports nothing).
Decisions: a nested traced call is an assert (Flutter) · objects-only props traced · a build entry that reports and a
silent entry for a parent's reads; the Scaffold appBar slot builds through the reporting one
Review fit: a parent's read of a watched child (AppBar title, flex/fit, Positioned) also reported, 2-3 per redraw where
Flutter sends one per WatchBuilder build, fixed (a2891fe, testC19_1_aWatchedNodeReportsOncePerBuildNeverOnItsParentsRead)
· Review quality: pass
#### T9 · Kotlin resolveWithTrace, traced widget_rebuild (f2b5e83)
Files: sdk-kotlin/core/.../resolver/ValueResolver.kt · core/.../render/PageRenderer.kt · sdk/.../OrcaPageModel.kt ·
core/src/test/.../debug/PropTraceTest.kt (new) · sdk/src/test/.../debug/DevToolsUiReportingTest.kt
Cases: C19.1/K → green (core 392 = 385 + 7; sdk 374, c6 renamed; red first: compile, then the redraw's report)
Changed: resolveWithTrace → Pair(value, trace) through a recorder field set for the call (a nested call throws;
cleared in finally); PageRenderer reports as T8 on every resolution (NodeView is its only caller: one per redraw);
NodeObserver only redraws; one @TestFactory case per traces file; c6 checks full traces at count 0 and 1.
Decisions: Pair return · JUnit5 @TestFactory (already on the classpath) · array props untraced (Flutter: Map only)
Review fit: pass · Review quality: pass (notes: resolvers are per call, so the recorder is never shared across threads)

### Group 4
#### T10 · Swift action trace, affectedWidgets, debugLog (6f4840f, rework 6977b2a)
Files: sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift · State/ActionReducer.swift ·
Sources/OrcaGateway/OrcaPageModel.swift · Tests/OrcaGatewayCoreTests/ActionTraceTests.swift (new) ·
Tests/OrcaGatewayTests/LifecycleTests.swift
Cases: C19.2/S, C19.6/S → green (core 398 = 390 + 8; SwiftUI 261 = 258 + 3; red first: compile, then the page test;
the C19.6 pins pass on today's code, as a pin should)
Changed: a public `pageNodes` hook on the executor, set by OrcaPageModel; each run keeps its own trace and affected
list, so only the setState's own event carries them; a transform value resolves once, through resolveWithTrace
while DevTools is on; exact-key watchers {id,type,watches} after the commit, in Flutter's nodeMap order (the model
keeps an ordered id list through add, replace, update, delete); debugLog: the action event only, plus os.Logger.
Decisions: the reducer's traced entry internal (one new public member) · computed only when the event will be sent
Review fit: server-action-added nodes sorted by id where Flutter keeps arrival order, fixed (6977b2a,
testC19_2_nodesServerActionsChangedKeepFluttersNodeMapOrder) · Review quality: pass
#### T11 · Kotlin action trace, affectedWidgets, debugLog (064393d)
Files: sdk-kotlin/core/.../state/ActionExecutor.kt · state/ActionReducer.kt · sdk/.../OrcaPageModel.kt ·
core/src/test/.../debug/ActionTraceTest.kt (new) · sdk/src/test/.../widgets/LifecycleTest.kt
Cases: C19.2/K, C19.6/K → green (core 399 = 392 + 7; sdk 376 = 374 + 2; red first: the 5 behaviour tests and the page
test; the off guard and C19.6 pins pass on today's code)
Changed: a public `pageNodes` hook set to the renderer's node map (a LinkedHashMap: Flutter's order through every
mutation); per-run trace and affected, cleared around each handler; internal reducer setState resolves a transform
once, traced while DevTools is on; logcat line plus the action event only for debugLog.
Decisions: the hook a plain var like onEffect/onMutation (set once at init, one thread) · affectedWidgets use the wire
type, not the degraded one (Flutter's node.type)
Review fit: pass · Review quality: pass

### Group 5
#### T12 · Swift overlay, debug config, logTimings (7b85c9d)
Files: sdk-swift/Sources/OrcaGateway/Debug/DebugOverlay.swift (new) · OrcaApp.swift · Debug/DevToolsClient.swift ·
Tests/OrcaGatewayTests/DebugOverlayTests.swift (new)
Cases: C19.5/S unit part → green (SwiftUI 268 = 261 + 7; core 398; red first: compile)
Changed: OrcaDebugConfig gains showOverlay, logTimings, captureStateChanges, captureNetworkRequests, includeBodies
(Flutter's defaults, after the old fields); start copies the four core ones and the overlay switch, stop resets both;
the loader keeps loadTimeMs (= renderComplete) and logs "[OrcaDebug] Timing: <pageId> - <path>" with logTimings;
OrcaPageView draws Flutter's chip bottom-right (under the toast) only while DevTools and showOverlay are on.
Decisions: the tap tested through DebugOverlayModel.tap() · the chip lives in OrcaPageView (a host-drawn page shows
"-ms") · the line through os.Logger category "OrcaDebug", tested via OSLogStore as A2.6
Review fit: pass (look, rounding, touch pass-through and z-order checked) · Review quality: pass
#### T13 · Kotlin overlay, debug config, logTimings (d27b49e)
Files: sdk-kotlin/sdk/.../debug/DebugOverlay.kt (new) · OrcaApp.kt · debug/DevToolsClient.kt ·
sdk/src/test/.../debug/DebugOverlayTest.kt (new)
Cases: C19.5/K unit part → green (sdk 385 = 376 + 9; core 399; red first: compile)
Changed: the five fields after appVersion; start/stop as T12; Phase.Loaded carries renderCompleteMs; the first-frame
hook sends the timing and, with logTimings, Log.i under the SDK's tag; RouteBody draws page and chip in a Box.
Decisions: drawn at the loader (stack, pushed and tab pages; OrcaPageView is the renderer below, as Flutter draws only
from OrcaPage) · INFO level (Flutter's debugPrint lands as I/flutter) · the loader always measures, so a chip shown
after DevTools starts late shows a real load where Flutter shows "-ms" (harmless)
Review fit: pass · Review quality: pass

### Group 6
#### T14 · iOS demo switches, Swift README (3ff62a1)
Files: examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md · sdk-swift/README.md
Cases: enables C19.5 hand/S and the iOS DevTools hand check (example builds, no warnings; core 398, SwiftUI 268)
Changed: ORCA_OVERLAY → showOverlay, ORCA_BODIES → includeBodies (Self.isOn, off by default); the app README's DevTools
section gains both with launch lines; sdk-swift/README.md gains a DevTools section (start/stop, the five options and
what each gates, what is never gated, the bodies warning, the redacted headers, the three traced things).
Decisions: the README names DevTools' own labels (Network › Body, Transform, Widgets, Prop pipelines) · no scheme edit
Review fit: pass · Review quality: pass
#### T15 · Android demo switches, Kotlin README (ffd2538, rework 4bf53ec)
Files: examples/app-android/.../MainActivity.kt · examples/app-android/README.md · sdk-kotlin/README.md
Cases: enables C19.5 hand/K and the Android DevTools hand check (assembleDebug green; core 399, sdk 385)
Changed: ORCA_OVERLAY / ORCA_BODIES boolean extras into OrcaDebugConfig; the app README's DevTools table, `-S` explained,
one adb line each; sdk-kotlin/README.md's DevTools sample and an options table, as T14.
Decisions: no ORCA_LOGTIMINGS switch · the sample keeps includeBodies = false so the docs don't suggest it
Review fit: the app README said an `x-api-key` header shows redacted; the app sends `Authorization: Bearer`, fixed
(4bf53ec) · Review quality: pass

### Hand checks (2026-11-16)
- Android emulator-5584 (API 34, cold-booted after its system process hung), counter app with ORCA_OVERLAY and
  ORCA_BODIES: chip "3027ms" bottom right; taps on + reach the page beside it; a tap expands "Load: 3027.4ms /
  Components: 16 / Cache: -".
- iOS 18.5 simulator FDE5D612: chip "62ms"; + works; a tap expands "Load: 62.3ms / Components: 16 / Cache: -".
- DevTools: screen control of the DevTools window was declined, so a listener on :6363 captured what each app sent
  and T1's validator checked every event: 9 events each (device_info, network with responseBody and Authorization
  <redacted>, state_change, widget_rebuild with propTraces [state, input, toString], timing, setState action with
  transformTrace [state, input, add] and affectedWidgets Text#5), 0 invalid on both. No requestBody: the app state
  was empty, as Flutter. Screenshots and captures: scratchpad s19/hand/.

### Test run
Group 6, final (..4bf53ec): engine `bun test` 770 pass · sdk `flutter test` 357 · devtools `flutter test` 20 ·
`swift build --build-tests` 0 warnings (type-check scan at 80 ms: only TransformTests.swift:2328, untouched) · `swift test`
core 398, SwiftUI 268 · `xcodebuild test` OrcaGateway-Package on iOS 18.5: core 398, SwiftUI 311, TEST SUCCEEDED ·
examples/app-ios build SUCCEEDED, 0 warnings · `./gradlew build` core 399, sdk 385 · examples/app-android assembleDebug
SUCCESSFUL · Files changed: the tasks' only (devtools' lock and analysis_options, rewritten by its run, restored).
Group 5 (..7b85c9d): `swift build --build-tests` 0 warnings · `swift test` core 398, SwiftUI 268, 0 failures ·
`./gradlew build` core 399, sdk 385, 0 failures · sdk `flutter test` 357 · Files changed: the tasks' only.
Group 4 (..6977b2a): `swift build --build-tests` 0 warnings · `swift test` core 398, SwiftUI 261, 0 failures ·
`./gradlew build` core 399, sdk 376, 0 failures · sdk `flutter test` 357 · Files changed: the tasks' only.
Group 3 (..a2891fe): `swift build --build-tests` 0 warnings · `swift test` core 390, SwiftUI 258, 0 failures ·
`./gradlew build` core 392, sdk 374, 0 failures · sdk `flutter test` 357 · Files changed: the tasks' only, plus T8's
one-line Structure.swift edit (the appBar slot's build entry; reviewed, fit pass).
Group 2 (..db49e6b): `swift build --build-tests` 0 warnings · `swift test` core 386, SwiftUI 257, 0 failures ·
`./gradlew build` core 385, sdk 374, 0 failures. Files changed: the tasks' only.
Group 1 (d3c2f38..9b4dc06): engine `bun test` 770 pass (751 + T1's 19) · sdk `flutter test` 357 (349 + 5 + 3) · devtools
`flutter test` 20 (17 + 3 fixtures) · `swift build --build-tests` 0 warnings · `swift test` core 377, SwiftUI 257, 0
failures · `./gradlew build` core 378, sdk 374, 0 failures. Files changed: the tasks' only (devtools' pubspec.lock and
analysis_options.yaml, rewritten by its test run, restored).

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- Hand checks: the chip on both devices (look, tap, touches pass through), DevTools showing a traced rebuild, a
  traced setState and bodies from both natives.
- PR body: a page a host draws itself outside OrcaApp shows "-ms" on iOS and no chip on Android (both fit D6).
