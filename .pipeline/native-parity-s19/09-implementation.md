# 09 · Implementation · native-parity-s19

## Front page

### In one breath
group 2 of 6 · tasks: 2 green, 0 blocked · cases: C19.7, C19.3, C19.4 green · every suite green
T6 Swift: OrcaDebugOptions (Flutter's names, defaults), the state and network gates, bodies.
T7 Kotlin: the same; one rework: an empty appState shows no requestBody, as Flutter and Swift.

### New for you
nothing new

### Trade-offs
1 auto-decided: options are read once per request, so one request never mixes settings

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 3 (resolveWithTrace and traced widget_rebuild in both cores). (default: go)

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

### Test run
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
nothing yet
