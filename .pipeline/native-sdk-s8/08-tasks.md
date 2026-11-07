# 08 · Tasks · native-sdk-s8

## Front page

### In one breath
S8 is 23b.27c, Swift's S3 in Kotlin: page-to-page navigation, the system actions (open a URL,
copy, share), DevTools events and the DevTools client. Done: basic-actions and server-actions
run on the Pixel 3a, and the Android app shows up in your DevTools. T6.4 green on ubuntu.

### New for you
Nothing new.

### Trade-offs
1 needs you: the DevTools client tests need a WebSocket server; OkHttp's mockwebserver as a test
  dependency, or a small hand-written one. Default: mockwebserver (tests only).
2 auto-decided: navigation is a NavHost back stack, so Android's back gesture is goBack too.
3 auto-decided: Kotlin reports a refused caps vector to DevTools, as Dart does (Swift skips it).
4 auto-decided: the DevTools client rides OkHttp's WebSocket; no new runtime library.

### Questions for you
1. UAT: the emulator app joins your DevTools on :6363 (10.0.2.2 from the emulator). (default: ok)
2. The example takes ORCA_DEVTOOLS and ORCA_DEVTOOLS_HOST extras, as app-ios does. (default: yes)
3. Branch feat/native-sdk-s8 from main, S7's close commits first. (default: yes, done)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Where S8 comes from
`.pipeline/native-sdk-s6/08-tasks.md`, slice plan: S8 adapters is "navigation, system (openUrl,
clipboard, share), serverAction POST, DevTools client and its 8 event fixtures; basic-actions and
server-actions (S3)", done when "T6.4 green". Epic row 23b.27c. The serverAction POST already landed
in S7 (core's `OrcaClient.executeAction`, the restored executor test), so S8 has the rest.

### What Swift's S3 had, and what S8 takes
| Swift S3 (23b.20-22, 28, 29) | Kotlin S8 |
|---|---|
| Executor, 12 kinds (23b.20) | in core since S6 |
| `OrcaRouter` on `NavigationStack(path:)`: a page model and store per route, one shared app-state store; navigate pushes, `replace` swaps, goBack pops (117 lines) | `OrcaRouter` on `NavHost`: the same rules; the system back gesture pops too |
| `SystemActions`: openUrl under the URL policy (http, https, mailto), clipboard, share sheet (87) | `SystemActions` with an Android implementation: `ACTION_VIEW`, `ClipboardManager`, `ACTION_SEND` chooser |
| serverAction POST, component mutations (23b.21) | done in S6 (mutations) and S7 (POST) |
| `DevToolsEvent`, `OrcaDebug` in core (221 + 42); reporting from the store, executor, client, renderer | the same in core `debug/`, wired into the S6 and S7 code where its S8 comments wait |
| `DevToolsClient` on `URLSessionWebSocketTask` (224): opt-in, `device_info` first, Flutter's backoff (1, 2, 4 … 30 s, 10 tries); NodeView rebuilds, page timing, thrown actions | `DevToolsClient` on OkHttp's `WebSocket`, the same rules |
| app-ios reads `ORCA_APP_ID`, `ORCA_PATH`, `ORCA_DEVTOOLS`, `ORCA_DEVTOOLS_HOST` | app-android: the first two since S7, the DevTools two now |

### Tasks for S8
| # | Task | Acceptance criteria |
|---|------|---------------------|
| S8.1 | Core `debug/`: `DevToolsEvent` builders for the 7 types and the FallbackPrompt warning, `OrcaDebug` (a reporter, nothing built without one). Reporting from `ElmStore` (state_change of its page's changed keys), `ActionExecutor` (action), `OrcaClient` (network, redacted headers; `fetchPageTimed` and its timing; the refused vector as an error, trade-off 3), `PageRenderer` (a FallbackPrompt once per type). | T6.4.5: Swift's 10 `DevToolsEventTests`; every fixture in `schema/fixtures/devtools/` rebuilt exactly. |
| S8.2 | `OrcaRouter` on `NavHost`: one page model and store per route, a shared app-state store, navigate (push, `replace`), goBack and the system back gesture; `OrcaApp` builds on it. | T6.4.2: Swift's `RouterTests` (navigation and app-state cases) under Robolectric. |
| S8.3 | `SystemActions` and its Android implementation: openUrl through the URL policy, the clipboard, the share chooser; `OrcaApp` uses it unless the host passes its own. | T6.4.2: Swift's openUrl-policy and clipboard-and-share cases under Robolectric (the started intents, the clipboard text). |
| S8.4 | `DevToolsClient` on OkHttp's WebSocket: `OrcaDebugConfig` (enabled, host, port 6363, appName), `device_info` first, reconnect with Flutter's backoff, then events from NodeView (widget_rebuild), the page loader (timing) and thrown actions (error). | T6.4.6: Swift's 8 `DevToolsClientTests` against a WebSocket stub (trade-off 1). |
| S8.5 | app-android: `ORCA_DEVTOOLS` (default on in debug) and `ORCA_DEVTOOLS_HOST` (default `10.0.2.2`); README for basic-actions, server-actions and DevTools. | T6.4.4: basic-actions (home, about, product, ecommerce, checkout) and server-actions (shop) on the Pixel 3a; the app appears in DevTools. |
| S8.6 | README status; Taskfile and CI unchanged unless a test needs it. | `t sdk-kotlin:build` and CI green on the S8 PR. |

### Tests (T6.4, Swift's T3 in Kotlin)
Swift's S3 tests to port: RouterTests 7, DevToolsEventTests 10, DevToolsClientTests 8 (25). T6.4.1
(executor kinds) and T6.4.3 (the POST shape, a refused action's snackbar) are green since S6 and
S7. The S7 Robolectric tests keep running.

### Findings while planning
F1 Port 6363 is held by your DevTools app here; the UAT points the emulator at it, nothing else
   binds it.
F2 OkHttp 4.12 has WebSocket support built in; mockwebserver 4.12.0 (its WebSocket upgrade) is not
   cached and downloads for the tests.
F3 The S7 commits left `// DevTools reporting arrives with the adapters slice (S8).` at each spot
   to wire: ElmStore commit, the executor's run, the renderer's degrade path, the client's send and
   fetch, NodeObserver, the page loader.
F4 From S7 F1: a new activity fetches its page again. S8 keeps the router in `remember`, like
   Swift's `StateObject`; keeping the stack across a configuration change (a ViewModel or saved
   state) is noted, not built.

### Commits on feat/native-sdk-s8 (conventional)
1. chore(pipeline): native-sdk-s7 stages 10 and 12, S7 closed (done: 2def978, b9a0c0d, fee8e61)
2. chore(pipeline): native-sdk-s8 stage 08
3. feat(sdk-kotlin): DevTools events in core (S8.1)
4. feat(sdk-kotlin): OrcaRouter on NavHost (S8.2)
5. feat(sdk-kotlin): system actions (S8.3)
6. feat(sdk-kotlin): DevTools client (S8.4)
7. feat(examples): app-android DevTools and the other example apps (S8.5)
8. chore(pipeline): stage 09 onward

### Not in S8
FallbackPrompt looks, the three policies, the drawn 426 page, the ten extra widgets, theme hooks
(S9). Maven Central (S10).

### Groups (derived at the start of 09)
This 08 predates the pipeline-build module, so its tasks had no groups. At 09 entry they are split
so that no two tasks of a group share a file and no task has more than five files; S8.1 and S8.4
split in two, S8.6 joins S8.5. Case ids are Swift's S3 tests: E (DevToolsEventTests), Y (system
cases of RouterTests), R (RouterTests), C (DevToolsClientTests).
| Group | Task | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|
| 1 | S8.1a DevTools events and OrcaDebug | core `debug/DevToolsEvent.kt`, `debug/OrcaDebug.kt`, test `debug/DevToolsEventTest.kt` | E1 every fixture rebuilt, E2 action families as Dart, E3 headers redacted, E4 state changes diff both scopes, E5 nothing built without a reporter | M | none |
| 1 | S8.3 System actions | sdk `system/SystemActions.kt`, test `system/SystemActionsTest.kt` | Y1 openUrl follows the policy, Y2 clipboard and share | S | none |
| 2 | S8.1b Reporting from the core | core `state/ElmStore.kt`, `state/ActionExecutor.kt`, `client/OrcaClient.kt`, `render/PageRenderer.kt`, test `debug/DevToolsReportingTest.kt` | E6 the store reports its page's changed keys, E7 the executor reports every action, E8 a FallbackPrompt once per type, E9 the client reports requests and failures (the refused vector too), E10 a timed fetch reads the server timing | M | S8.1a |
| 2 | S8.2 OrcaRouter on NavHost | sdk `navigation/OrcaRouter.kt`, `OrcaApp.kt`, test `navigation/RouterTest.kt` | R1 navigate pushes, replace resets, goBack pops; R2 the same path twice is two pages; R3 a popped route loses its page; R4 page actions drive the router; R5 app state shared across pages | M | S8.3 |
| 2 | S8.4a DevTools client | sdk `debug/DevToolsClient.kt`, test `debug/DevToolsClientTest.kt`, `gradle/libs.versions.toml`, `sdk/build.gradle.kts` | C1 device_info first, then events; C2 reconnects after DevTools restarts; C3 a refused client gives up after ten tries; C4 delays follow Flutter; C5 opt-in | M | S8.1a |
| 3 | S8.4b Reporting from the views | sdk `OrcaPageModel.kt`, `OrcaApp.kt`, test `debug/DevToolsUiReportingTest.kt` | C6 a watching node reports its rebuild, C7 a loaded page reports its timing once, C8 a thrown action is reported as an error | S | S8.2, S8.4a |
| 3 | S8.5 Example and READMEs | `examples/app-android/.../MainActivity.kt`, `examples/app-android/README.md`, `sdk-kotlin/README.md` | (prepares U1) | S | S8.2, S8.4a |
Not planned for an implementer: U1, basic-actions and server-actions on the Pixel 3a and the app in
DevTools, is the stage 10 run by hand.

### Done when
test: `cd sdk-kotlin && ./gradlew build --console=plain` (compile with warnings as errors, core and
sdk tests, lint) · lint: inside that build (`:sdk:lintDebug`) · typecheck: none (the Kotlin compile
is in the build) · baseline: core 93 and sdk 48 tests green, lint 0 warnings, 2026-11-07 ·
commits: per task (the approved commit list above) · gate: per group (the default; not asked at 08,
answered at gate 08 with "A", 2026-11-07).
