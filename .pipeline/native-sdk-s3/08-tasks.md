# 08 · Tasks · native-sdk-s3

## Front page

### In one breath
S3 is rows 23b.20-22 plus two new DevTools rows, 23b.28-29. The iOS SDK gets all 12 action kinds,
page-to-page navigation, system actions, server actions, and an opt-in DevTools client. Done means
basic-actions and server-actions run on a simulator and the iOS app shows up in DevTools.

### New for you
Nothing new.

### Trade-offs
1 needs you: 23b.7's warnings. SDKs send each FallbackPrompt they draw to DevTools, or the page
  response gets a `_debug` list (a wire change)? Default: SDK side, no wire change.
2 auto-decided: add the 4 component kinds server-actions returns (S2 gate 08: pull a demo's needs).
3 auto-decided: a failed server action shows Flutter's snackbar, not T3.3's OrcaError (S2 gate 09).
4 auto-decided: DevTools fixtures rebuilt exactly by tests, no validator dependency (S1, S2 g10).

### Questions for you
1. Branch feat/native-sdk-s3 off main at 5a2dbf9, with S2's closing as its first commit? (done)
2. Add rows 23b.28 and 23b.29 to the epic plan, outside the repo? (default: yes, at stage 09)
3. The example app picks its app through ORCA_APP_ID and ORCA_PATH. (default: yes; counter/home)
4. Swift DevTools takes a host as well as a port, so a real iPhone reaches the Mac? (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Rows
These come from `.pipeline/native-sdk/08-tasks.md` lines 57-59, plus the DevTools scope you approved at
native-sdk-s2 gate 10 (A).

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 23b.20 | ActionExecutor: the 8 remaining kinds on the S1 reducer seam, with effects out. conditionalAction picks its first true branch, otherwise `else`. lifecycle runs onLoading, then the action, then onSuccess, with onError on a throw and onComplete always. Also navigate, goBack, openUrl, copyToClipboard, share and serverAction. The executor becomes async for serverAction and lifecycle. | T3.1: all 15 action fixtures pass in Swift. Fixture 15 runs through a stub transport that replays its `serverResponses`. |
| 23b.21 | Adapters. Navigation: `NavigationStack(path:)` with one page model and store per route and a shared app-state store; navigate pushes, `replace` swaps, goBack pops. System: openUrl under Flutter's policy (http, https, mailto), the clipboard, the share sheet. serverAction: `POST /api/v1/app/{appId}/action` with `{action, params?, pageState?, appState?}`, then runs the `{actions}` it gets back. Also addComponent, replaceComponent, updateComponent and deleteComponent on the render tree (trade-off 2). | T3.2: mocked adapters. T3.3: the POST shape; response actions applied, with setState defaulting to page scope; an error shows a snackbar with the server's `error` (trade-off 3). |
| 23b.22 | basic-actions (home, about, product, ecommerce, checkout) and server-actions (shop) on a simulator. app-ios reads `ORCA_APP_ID` and `ORCA_PATH` from its scheme. | T3.4: you run both against `t example:dev:server`. |
| 23b.28 | DevTools events contract. `schema/devtools-events.schema.json` covers the envelope `{type, deviceId, timestamp, payload}` and the 7 types (device_info, timing, state_change, action, network, widget_rebuild, error). `schema/fixtures/devtools/` holds one fixture per type. | T3.5: a Dart test builds each event with `debug_events.dart` and equals its fixture. A DevTools test parses every fixture. |
| 23b.29 | Swift DevTools client in the `OrcaGateway` target, on `URLSessionWebSocketTask`. It is opt-in (`OrcaDebugConfig`: enabled, host `localhost`, port 6363, appName) and sends `device_info` first. Reconnect follows Flutter's backoff: 1, 2, 4 … 30 s, 10 tries. Events come from OrcaClient (network, timing), the store (state_change), the executor (action), NodeView (widget_rebuild), and errors and FallbackPrompts (error with a warn context; trade-off 1, and Flutter does the same). | T3.6: Swift events equal the 23b.28 fixtures. A local WebSocket stub receives `device_info`, then events. By hand: the iOS app appears in DevTools. |

### Trade-off 1 in detail: how off-target warnings reach DevTools (23b.7)
23b.7 asked that the DevTools error screen list off-target warnings. Today the engine only calls
`console.warn` when a page declares `targets` (`target-check.ts`, `pipeline.ts:171`), and nothing
reaches a client. Native-sdk 09 deferred this ("needs an SDK or response transport").
- **Default, SDK side.** Each SDK reports every FallbackPrompt it draws as a DevTools `error` event
  whose context contains "warn". That covers both kinds: the server's synthesized prompts ("Some
  content needs an update", severity warn or blocking) and the client's own unknown-type degrade.
  `error_screen.dart:125-133` already shows "warn" entries as warnings. It costs one call in each
  renderer and needs no wire change. It shows what this device actually degraded, not the page's
  declared targets.
- **Alternative, wire side.** When `x-orca-debug` is sent, the page response gets
  `_debug.offTarget` from `findOffTargetWidgets`. That is the 5-sync-point change: schema, engine
  types, both SDK models, encoder, and a fixture. It reports the author's static check even on a
  client that renders everything.

### Trade-off 2: the four component kinds
server-actions' `addToCart` returns addComponent into "cart-list", and `clearCart` returns
replaceComponent. Neither kind is among the 12 the Swift vector advertises, so on iOS the cart
count would change but the list would not. At S2 gate 08 you pulled forward what a slice's demo
needs, so S3 adds addComponent, replaceComponent, updateComponent and deleteComponent. They are one
mechanism: edit the renderer's node map with the flattened `components` the engine sends.
`capabilities.json` gains the four, and `Generated.swift` and the caps hash are regenerated. Schema CI
checks both. closeDialog stays out, since S3 has no dialogs.

### Trade-off 3: server action errors
For a non-200 response, Flutter throws `OrcaClientException(json.error ?? 'Server action failed')`.
The handler then shows that message in a snackbar and does not rethrow, so lifecycle `onError` never
fires for HTTP errors. T3.3 said "error renders OrcaError". As at S2 gate 09, Swift follows Flutter:
- the same snackbar;
- the same non-rethrow.
- On a 500 the engine sends `{error, actions: [showSnackbar]}`. Flutter ignores those actions, and
  Swift does too.

### Trade-off 4: checking DevTools events
The repo's JSON schemas are not machine-validated in CI; the fixtures are the executable spec.
Following S1 (no third-party test dependencies) and your S2 gate 10 call (schema and fixtures first),
each fixture gives one exact message. The Dart and Swift tests build the same event from the same
values and compare it to the fixture. DevTools' `event_parser.dart` must accept each fixture. The
schema documents the shapes for readers and future ports.

### Findings while planning
F1 Server actions skip the caps handshake. `handleAction` never checks capabilities, and Flutter
   never retries an action, so Swift sends the caps headers and does not retry.
F2 navigate's `params` are emitted (fixture 04) but Flutter never passes them to the router. Swift
   emits them the same way. Routes in basic-actions have no leading slash ("about"), and each one is
   a page fetch.
F3 share sends `{text: message, subject: title}`, and `url` is ignored (fixture 11). openUrl drops a
   blocked scheme silently, after emitting the effect.
F4 The S2 test `testUnimplementedKindsChangeNothing` uses goBack as its unimplemented example. It
   moves to a kind no SDK advertises.
F5 basic-actions and server-actions use only the 15 Swift widgets, so nothing degrades in the demo.
F6 DevTools sends nothing back, so the Swift client only writes and drops incoming frames, as
   Flutter does. Flutter's host is hardcoded to localhost; giving it a host setting is out of
   scope here.

### Package additions
```
sdk-swift/Sources/OrcaGatewayCore/
  State/    ActionExecutor (async; runs reducers, emits effects, awaits serverAction), Lifecycle,
            Conditional; RenderMutation (add/replace/update/deleteComponent on the node map)
  Client/   OrcaClient.executeAction (POST /action), ActionResponse
  Debug/    DevToolsEvent (envelope + 7 payloads, Codable, equals the fixtures)
sdk-swift/Sources/OrcaGateway/
  Navigation/ OrcaRouter (route stack, page model per route, shared app store)
  System/     URLOpener, Clipboard, ShareSheet (protocols + UIKit adapters)
  Debug/      DevToolsClient (URLSessionWebSocketTask), OrcaDebugConfig
schema/devtools-events.schema.json, schema/fixtures/devtools/*.json
sdk/test/conformance/devtools_events_test.dart, devtools/test/fixture_parse_test.dart
sdk/lib/src/rendering/component_renderer.dart: one DevTools warn event per FallbackPrompt
```

### Tests (T3 group)
- T3.1: all 15 action fixtures, plus a stub transport for `serverResponses`.
- T3.2: navigation push, replace and pop on the router model; openUrl allowed and blocked; clipboard
  and share through mock adapters.
- T3.3: the POST path, headers and body keys; a response's setState lands in page scope and its
  showToast runs; a 403, 404 and 500 each show the server's `error` in a snackbar; the
  component-mutation unit tests.
- T3.4: basic-actions and server-actions, run by you on a simulator.
- T3.5: Dart events equal the fixtures, and DevTools parses each fixture.
- T3.6: Swift events equal the fixtures; the WebSocket client against a local stub (device_info
  first, reconnect after the stub restarts); the iOS app appearing in DevTools, checked by you.

### CI
No new jobs:
- The ubuntu core job runs T3.1, T3.3, T3.5 for Swift and the event-model tests.
- The macOS job runs T3.2's UIKit adapters and builds app-ios.
- SDK CI runs the Dart test. DevTools' own CI, if it has one, runs its parse test; otherwise
  `t test:all` covers it.

### Commits on feat/native-sdk-s3 (conventional)
1. chore(pipeline): native-sdk-s2 gate 12, S2 closed (done)
2. chore(pipeline): native-sdk-s3 stages 01-08
3. feat(sdk-swift): ActionExecutor for the 12 kinds (23b.20)
4. feat(sdk-swift): navigation, system and server action adapters (23b.21)
5. feat(examples): app-ios runs basic-actions and server-actions (23b.22)
6. feat(schema): DevTools events schema and fixtures (23b.28)
7. feat(sdk-swift): DevTools client (23b.29)
8. chore(pipeline): stage 09 onward

### Not in S3
- Dialogs, closeDialog, refetchPage and the other deferred kinds.
- Drawers and bottom sheets.
- FallbackPrompt looks and policies, and 426 (S4).
- The six extra widgets (S4).
- release.sh's mirror (S5).
- DevTools sending messages back.
- A host setting for Flutter's DevTools client.
