# 09 · Implementation · native-sdk-s3

## Front page

### In one breath
S3 is built on feat/native-sdk-s3: 5 commits, one per task (23b.20-22, 28, 29), nothing pushed.
On the simulator, basic-actions navigates, goes back, copies, opens a URL, shares and shows toasts.
server-actions adds cart rows, clears the cart and shows the server's snackbar.
The iOS app now sends DevTools events: handshake first, then network, timing, state and actions.
Tests: Swift core 102 (macOS, Linux 5.10 and 6.2, iOS), UI 21 to 22; Flutter 222; DevTools 11.

### New for you
Nothing new.

### Trade-offs
1 needs you: FallbackPrompt warning once per unknown type per session, not per draw; default once.
2 needs you: the 3 component kinds have no cross-SDK fixture (no node tree in one); default later.
3 needs you: Swift sends widget_rebuild with empty propTraces (no tracing); default empty.
4 needs you: app-ios starts DevTools in Debug builds; default on, `ORCA_DEVTOOLS=0` turns it off.

### Questions for you
1. Push and open the S3 PR at stage 10? (default: yes, as for S2; nothing merged or published)
2. UAT at 10: you try both apps and DevTools on the simulator? (default: yes; server on :8097)
3. Epic row 23b.20 still says "12 kinds"; S3 runs 15. Fix the row at 10? (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Tasks, status and evidence
| # | Status | Evidence |
|---|---|---|
| 23b.20 | done | `State/ActionExecutor.swift` runs the 15 kinds of capabilities.json plus the server-only `replaceComponent`. Effects are reported, then performed; serverAction POSTs `{action, params?, pageState?, appState?}` and runs the reply; a JSON error reply becomes a snackbar; component kinds go through `Render/ComponentMutation.swift` (Dart `ComponentStore`). T3.1: all 15 action fixtures; T3.3: 11 executor tests, 8 mutation tests. Caps vector gains addComponent, updateComponent, deleteComponent (gate 08, trade-off 2). Commit 4c39f13 |
| 23b.21 | done | `Navigation/OrcaRouter.swift` behind `NavigationStack(path:)`: a fetch and a store per route; navigate pushes; `replace` makes the route the only page (GoRouter `go`); goBack pops. App state is shared: commits update it, fetches carry it, a pop syncs the revealed page. `System/SystemActions.swift`: openUrl under `OrcaURLPolicy` (http, https, mailto), clipboard, share sheet. `OrcaPageModel` runs taps through the executor; mutations redraw via a structure revision. T3.2: 7 router tests and 6 page-model tests; policy and store tests in the core. Commit 44c4fcd |
| 23b.22 | done | `ORCA_APP_ID` and `ORCA_PATH` in app-ios (default counter, home), scheme entries, README table. T3.4 on an iPhone 16 Pro (iOS 18.5) against `examples/server` on :8097 (list below). Commit 59f0970 |
| 23b.28 | done | `schema/devtools-events.schema.json` (envelope, 7 payloads, if/then per type) and `schema/fixtures/devtools/` (8 files: one per type, plus the FallbackPrompt warning). Dart: `OrcaDebug.envelope`, `DevToolsClient.deviceInfoPayload`, `DebugErrorEvent.fallbackPrompt`, and the renderer's once-per-type warning. T3.5: `sdk/test/conformance/devtools_events_test.dart` (10), `devtools/test/fixture_parse_test.dart` (11). `t devtools:test` joins `t test:all`. Commit fb0cb4d |
| 23b.29 | done | Core `Debug/DevToolsEvent.swift` (builders, family table, header redaction, state diff) and `Debug/OrcaDebug.swift` (the reporter slot). Reports come from OrcaClient (network; error on failure or 4xx/5xx, not the handshake 412), ElmStore (`pageId`), executor, registry, NodeObserver and the page loader (timing on the first frame). UI target: `OrcaDebugConfig`, `OrcaDebug.start`, `DevToolsClient` on URLSessionWebSocketTask. T3.6: 10 core tests (every fixture rebuilt exactly) and 8 UI tests (a local Network.framework WebSocket stub: handshake first, events, reconnect after a restart, giving up after 10 tries; page hooks). Commit 1ca967d |

### T3.4 on the simulator (basic-actions, then server-actions)
- setState: + counts; navigate pushes About; Go Back (`goBack`) pops; Snackbar and Toast show.
- Copy Message: `simctl pbpaste` reads "Hello, Orca Gateway!". Open Flutter Docs opens Safari.
- Share Count opens the share sheet with "My counter is at 3!" (state interpolated).
- Add to Cart: "Adding..." while the server waits 3 s, then a new row (addComponent), the count,
  the stock and the server's snackbar. Add 3 to Cart (no lifecycle) does the same.
- Clear Cart: the list empties (replaceComponent) and the toast "Cart cleared!" shows.
- Two injected taps 100 ms apart counted once; slow taps counted one each. This is the tap tool's
  timing; one tap is one action in the unit tests.

### DevTools, end to end
A throwaway WebSocket listener on 127.0.0.1:6363 (not the DevTools app) received 13 events from
app-ios. First came `device_info` (iPhone17,1, "Orca Counter"), then network (Authorization
`<redacted>`), timing, 5 state_change, 3 action and 1 widget_rebuild. The example server sends no
`x-orca-timing` header, so `server` is left out, as the schema allows. Checking the real DevTools
app is yours (T3.6, by hand). The listener is stopped and 6363 is free.

### Test results
| Where | Result |
|---|---|
| macOS, `swift test` | core 102/102, UI 21/21 (the golden is iOS only) |
| Linux, `swift:5.10-jammy` and `swift:6.2-noble` | build with no warnings, 102/102 |
| iOS 18.5 simulator, `xcodebuild test -scheme OrcaGateway-Package` | core 102/102, UI 22/22 with the golden |
| Flutter, `t sdk:test` | 222 passed (includes the new devtools events test) |
| DevTools, `flutter test test/fixture_parse_test.dart` | 11/11 |
| `gen-native-capabilities.ts`, `gen-widget-registry.ts` | no drift after the commit |
| `flutter analyze` on the changed Dart files | no issues |

### Trade-off 1: how often the FallbackPrompt warning goes out
Gate 08 said each drawn FallbackPrompt is reported. Flutter builds a renderer on every build, so a
warning per draw would add a row to the Errors tab on every rebuild. Both SDKs report once per
unknown type per session, which is how Flutter's telemetry already counts them. Alternative: per
node per page load, which needs a dedupe key that survives rebuilds.

### Trade-off 2: component kinds without a cross-SDK fixture
An action fixture compares state and effects, not the node tree, so add, update, delete and
replace have no shared fixture. ComponentMutationTests pins Swift against Dart's ComponentStore
by reading. `ModelRoundTripTests` now skips the three kinds when it checks fixture coverage.
Alternative: a `components` field in action fixtures and support in the Dart runner, as a
separate change.

### Trade-off 3: empty prop traces
Flutter sends widget_rebuild only when its resolver traced a transform. The Swift resolver does
not trace, so Swift sends each watched rebuild with `propTraces: {}`, and DevTools shows the rebuild
without steps. Alternative: send nothing, as Flutter does without traces.

### Findings worth remembering
- F1 Swift 5.10's discovered-tests shim rejects synchronous `@MainActor` test methods; async ones
  pass. `ActionExecutor.kinds` and `implements` are `nonisolated`, so the caps test stays sync.
- F2 A default argument is evaluated outside the main actor, so `SystemActions.live` is the
  fallback inside the init, not the default value.
- F3 Dart's `updateComponent` keeps a node's watches; Swift matches.
- F4 Not tested: Flutter's once-per-type warning wiring. The SDK has no hook to capture what
  OrcaDebug sends. The event's text is pinned by the fixture.
- F5 Epic plan rows 23b.28 and 23b.29 added (outside the repo, approved at gate 08).

### For ship (stage 10) to know
Nothing to deploy. Push the branch and open the PR. CI covers the ubuntu core, the macOS UI job
(adapters, app-ios build), schema and SDK. DevTools has no CI job, so its test runs in
`t test:all`. The example server on :8097 stays up for UAT.
