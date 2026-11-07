# 09 · Implementation · native-sdk-s8

## Front page

### In one breath
group 3 of 3 · tasks: 2 green, 0 blocked · cases: 25 of 25 green · build: 176 green, lint 0
S8.4b View reporting: node rebuilds, page timing on the first frame, thrown actions (c64b24a).
S8.5 Example and READMEs: app-android joins DevTools at 10.0.2.2; how to run the apps (778c06a).
All 7 tasks of S8 are green and committed; the example's debug build is green too.
Not done yet: U1, the emulator run (basic-actions, server-actions, DevTools), at stage 10.

### New for you
nothing new

### Trade-offs
4 auto-decided: error text "$e", DevTools once per process, version read by API level, app label.

### Questions for you
1. `A` approves stage 09; stage 10 pushes the branch, opens the PR and runs U1. (default: go)
2. U1: the example server from this branch on :8097, your DevTools on :6363 untouched. (default: ok)

## Appendix

### Group 1

#### Task S8.1a · DevTools events and OrcaDebug
Files: core `debug/DevToolsEvent.kt` (new, 263 lines) · `debug/OrcaDebug.kt` (new, 34) · test
`debug/DevToolsEventTest.kt` (new, 155)
Cases: E1 E2 E3 E4 E5 → green (core 93 → 98, 0 failing) · red first: the compile failed on the
unresolved `OrcaDebug` and `DevToolsEvent`
Changed: `DevToolsEvent(type, payload)` with `envelope(deviceId, timestamp)`, `ClientTiming`,
`NetworkPhase` and Swift's builders (deviceInfo, timing, stateChange(s), action, family, network,
redactedHeaders, sanitize, widgetRebuild, error, fallbackPrompt). `OrcaDebug`: a `@Volatile`
reporter, `isEnabled`, an inline `report {}` and `now()` in monotonic ms.
Decisions: 1. `report` is a public inline fun: no lambda object, no event without a reporter ·
2. key order and family matching go through core's SwiftText helpers · 3. Int status, Long time
Review fit: pass · Review quality: pass · Commit: 0370b1d
Not done: Swift's other five DevToolsEventTests are S8.1b's E6-E10 (group 2).

#### Task S8.3 · System actions
Files: sdk `system/SystemActions.kt` (new, 70 lines) · test `system/SystemActionsTest.kt` (new, 121)
Cases: Y1 Y2 → green (sdk 48 → 52, 0 failing) · red first: "Unresolved reference 'SystemActions'"
Changed: `SystemActions(open, copy, share, urlPolicy)`; `perform(effect)` is true for openUrl (a
blocked URL is dropped silently), copyToClipboard and share, false for anything else.
`SystemActions.android(context)`: a view intent, the clipboard, the share chooser (text/plain,
EXTRA_TEXT, EXTRA_SUBJECT when given); NEW_TASK outside an Activity. Tests: recording lambdas for
Swift's two cases, Robolectric for the started intents and the clipboard text.
Decisions: 1. the factory is `android(context)` (kept at gate 09 group 1, "A") · 2. one helper
starts both intents and drops ActivityNotFoundException · 3. `toUri()` from androidx.core (lint)
Review fit: pass · Review quality: pass · Commit: dcc5762
Not done: wiring it into OrcaApp and the router is S8.2 (group 2).

Group 1 test run: `./gradlew build` with `--rerun` on `:core:test`, `:sdk:testDebugUnitTest`,
`:sdk:lintAnalyzeDebug`, `:sdk:lintDebug` · BUILD SUCCESSFUL · core 98, sdk 52, 0 failures · lint 0.
Gate 09 (group 1) answered "A", 2026-11-07: the factory stays `android(context)`; a card per group.

### Group 2

#### Task S8.1b · Reporting from the core
Files: core `state/ElmStore.kt` · `state/ActionExecutor.kt` · `client/OrcaClient.kt` ·
`render/PageRenderer.kt` · test `debug/DevToolsReportingTest.kt` (new, 251 lines)
Cases: E6 E7 E8 E9 E10 → green (core 98 → 106) · red first: `fetchPageTimed` missing; the rework's
two tests got 2 status-0 network events and 3 action events where none was expected
Changed: the store reports its page's changed keys; the executor every finished or thrown action
run; the renderer a FallbackPrompt once per type; the client a network event per request with
redacted headers, an error for a status ≥ 400, a transport failure or a refused caps vector (as
Dart; the first 412 is only a network event, as Swift). `fetchPageTimed` and `PageLoadTiming`.
Decisions: 1. `fetchPageTimed` returns a Pair · 2. the refused-vector error names the refused POST
(needs you, question 4) · 3. a cancelled fetch or action run is never reported (finding, fixed)
Review fit: pass · Review quality: cancellation reported as "Network request failed", fixed
Commit: 33bf323

#### Task S8.2 · OrcaRouter on NavHost
Files: sdk `navigation/OrcaRouter.kt` (new, 134 lines) · `OrcaApp.kt` · test
`navigation/RouterTest.kt` (new, 341)
Cases: R1-R5 → green, plus on-screen push and back, system actions, the two rework cases (sdk 52 →
58 → 60 → 62 of this task) · red first each pass (`OrcaRouter` missing; clipboard null; a spinner)
Changed: `OrcaRoute` (a new id per push) and `OrcaRouter` (root and stack as Compose state, one
loader per route closed when it leaves, the shared app scope, navigation effects; the rest go to
`system`). `OrcaApp(client, path, system)` and `OrcaApp(router)`: a NavHost that follows the stack,
system back pops the router, `SystemActions.android` filled in while shown.
Decisions: 1. the router is the only writer, so no predictive-back preview (question 2) · 2. a load
cancelled mid-fetch fetches again when shown · 3. a page landing after its route left joins nothing
Review fit: a host-built router dropped openUrl, clipboard and share, fixed · Review quality: a
cancelled load stayed a spinner forever, fixed · Commit: 3fbd70a

#### Task S8.4a · DevTools client
Files: sdk `debug/DevToolsClient.kt` (new, 208 lines) · test `debug/DevToolsClientTest.kt` (new,
179) · `gradle/libs.versions.toml` · `sdk/build.gradle.kts`
Cases: C1 C2 C3 C4 C5 → green (sdk + 5, 0.5 s, 5 of 5 reruns) · red first: the API was missing
Changed: `OrcaDebugConfig` (enabled, host, port 6363, appName, appVersion), `OrcaDebug.start` and
`stop`, `DevToolsClient` on OkHttp's WebSocket: device_info first on every connect, then envelopes;
backoff 1, 2, 4 … 30 s, gives up after ten tries. `mockwebserver` 4.12.0, tests only.
Decisions: 1. app version from the config, no Context (question 3) · 2. events while disconnected
are dropped, as Swift and Flutter · 3. one single-thread executor holds the client's state
Review fit: pass · Review quality: pass · Commit: b3830cc

Group 2 test run (after the last rework): fresh `:core:test`, `:sdk:testDebugUnitTest` and lint ·
BUILD SUCCESSFUL · core 106 (98 + 8), sdk 67 (52 + 10 router + 5 client), 0 failures · lint 0.
Gate 09 (group 2) answered "A", 2026-11-07: router as the only writer (no predictive-back preview),
`appVersion` in the config, the refused-vector error names the POST.

### Group 3

#### Task S8.4b · Reporting from the views
Files: sdk `OrcaPageModel.kt` · `OrcaApp.kt` · test `debug/DevToolsUiReportingTest.kt` (new, 131)
Cases: C6 C7 C8 → green (sdk 67 → 70) · red first: no `widget_rebuild`, no `timing`, a null error
context
Changed: a thrown action (not a cancelled one) sends an `error` with context "action <kind> on
<pageId>", then `onError` as before; a watching node's rebuild sends `widget_rebuild` when DevTools
is on; `OrcaPageLoader.reload` uses `fetchPageTimed`, marks the render start and end, and sends
`timing` once on the first frame. Group 2's cancellation reset, `closed` check and attach kept.
Decisions: 1. the error text is Kotlin's "$e"; tests check the context, as Swift's · 2. the
first-frame hook is set on every load · 3. C6 drives the node observer directly, as Swift's test
Review fit: pass · Review quality: pass · Commit: c64b24a

#### Task S8.5 · Example and READMEs
Files: `examples/app-android/.../MainActivity.kt` · `examples/app-android/README.md` ·
`sdk-kotlin/README.md`
Cases: none (prepares U1) · the example's `assembleDebug` and the SDK build green
Changed: MainActivity reads `ORCA_DEVTOOLS` (on in debuggable builds) and `ORCA_DEVTOOLS_HOST`
(default 10.0.2.2) and calls `OrcaDebug.start(OrcaDebugConfig(...))` with the app label and its
versionName. App README: a table of APP and PAGE values (counter; basic-actions home, about,
product, ecommerce, checkout; server-actions shop) and a DevTools section. SDK README: S8 status.
Decisions: 1. DevTools starts once per process, so a rotation keeps it · 2. versionName through
the API 33 call, the old one below it · 3. appName is the label "Orca Counter", as app-ios
Review fit: pass · Review quality: pass · Commit: 778c06a

### Test run
`cd sdk-kotlin && ./gradlew build :core:test --rerun :sdk:testDebugUnitTest --rerun
:sdk:lintAnalyzeDebug --rerun :sdk:lintDebug --rerun --console=plain` · BUILD SUCCESSFUL · core 106,
sdk 70 (67 + 3), 0 failures, 0 errors, 0 skipped · lint: 0 issues · failures: none.
`cd examples/app-android && ./gradlew :app:assembleDebug --rerun-tasks --console=plain` · BUILD
SUCCESSFUL (56 tasks executed) · app-debug.apk 12.7 MB.
File check: `git status` showed only the two tasks' files outside `.pipeline/`.
S8 in all: 7 tasks, 7 commits, cases E1-E10, Y1-Y2, R1-R5, C1-C8 green (25 of 25); core 93 → 106,
sdk 48 → 70.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- Nothing deploys or publishes (Maven Central is S10).
- U1 by hand on the Pixel 3a API 34 emulator: `examples/server` from this branch on :8097;
  `task example:android:run URL=http://10.0.2.2:8097 APP=basic-actions PAGE=home` (then about,
  product, ecommerce, checkout) and `APP=server-actions PAGE=shop`; the user's DevTools on :6363
  should list the app (the emulator reaches it at 10.0.2.2). Docker on 8080, the bun on 8091 and
  DevTools on 6363 are not touched.
- CI: `sdk-kotlin.yml` runs `./gradlew build` and the example's `assembleDebug` on JDK 17 and 21;
  mockwebserver 4.12.0 downloads there (tests only).
- A configuration change rebuilds the router at the root (S7 F1, 08 F4): noted, not built.
