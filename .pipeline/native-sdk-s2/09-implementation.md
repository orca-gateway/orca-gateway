# 09 · Implementation · native-sdk-s2

## Front page

### In one breath
S2 is built on feat/native-sdk-s2: 6 commits, one per task plus a review fix, nothing pushed.
The counter runs on an iPhone 16 Pro simulator against the Bun server: 412, retry, 200; + counts;
Reset shows 0 and the snackbar. Tests: 71 core on macOS and Linux (5.10, 6.2), 76 on iOS.

### New for you
Nothing new.

### Trade-offs
1 needs you: unknown widget, Flutter's "Unsupported content" card vs T2.5's blank; default Flutter.
2 needs you: golden, compare on its own iOS runtime and skip elsewhere vs compare all; default skip.
3 needs you: recorded counter page, Schema CI re-records and diffs vs no check; default check (in).

### Questions for you
1. Push and open PR 3 at stage 10? (default: yes, as PR 2; nothing merged or published)
2. UAT at 10: you tap the counter in the simulator panel? (default: yes; server on :8097 here)
3. Stop or go on S3 after that? (default: asked at gate 10, as native-sdk gate 08 set)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Tasks 23b.15-19, status and evidence
| # | Status | Evidence |
|---|---|---|
| 23b.15 | done | `Client/` (HTTPTransport, URLSessionTransport, DeviceInfo, OrcaClient). T2.1: cases A to E of caps-412-protocol against a stub engine, plus "other 412s pass through", "appState in both POSTs", "500 carries the body". T2.2: the exact Flutter header map (`x-orca-platform: iOS`, sizes as whole points, density `3.0`). 11 tests; commit e6e8b60 |
| 23b.16 | done | `Render/PageRenderer.swift` (root first, ids, slots = props holding child ids, deep resolve), `WidgetRegistry` (unknown type: one report, Flutter FallbackPrompt), `State/ActionReducer.swift` (setState, actionGroup, showSnackbar 4000 ms, showToast 2000 ms). Action fixtures 01, 02, 07, 08, 13 pass; T2.3 on the recorded counter page (16 nodes, + + shows 2, Reset shows 0 and one snackbar effect); T2.5. Commit 5049bb8. Views: commit 7c7b4c4 |
| 23b.17 | done | `OrcaApp` (one NavigationStack, loading and error states, `DeviceInfo.current()`), `OrcaPageView` (toast overlay, duration from the effect), 15 widget views. T2.4 golden `Tests/Goldens/counter-home.png`; commit 7c7b4c4 |
| 23b.18 | done | `examples/app-ios/OrcaCounter.xcodeproj` (synchronized folder, local path dependency), `ORCA_SERVER_URL` override, README; `t example:ios:build`. Run on the simulator against `examples/server` on :8097; commit b941b51 |
| 23b.19 | done | `.github/workflows/sdk-swift-ui.yml` on macos-15: `xcodebuild test` of OrcaGateway-Package on a simulator (prefers iOS 18.5), build of app-ios, xcresult kept on failure; nightly, `sdk-swift-v*` tags, manual, PRs on sdk-swift/** or examples/app-ios/**. Commit 12dccea |

Also: `examples/server/record-page.ts` and `t sdk-swift:record` record a page through the Swift caps
handshake against a real engine. `gen-native-capabilities.ts` exports `swiftCapabilityVector()` for
the recorder; Generated.swift is unchanged. Schema CI re-records and diffs `sdk-swift/Tests/Pages`.

### Test results
| Where | Result |
|---|---|
| macOS, `swift test` | core 71/71, UI 4/4 (the golden is iOS only) |
| Linux, `swift:5.10-jammy` and `swift:6.2-noble` | build with no warnings, 71/71 |
| iOS 18.5 simulator, `xcodebuild test -scheme OrcaGateway-Package` | core 71/71, UI 5/5 with the golden |
| Live, iPhone 16 Pro simulator, example server | engine log: GET 412, POST 200; + + gives 2; Reset gives 0 and "Counter reset to 0" |
| `bun run schema/codegen.ts`, re-record | no drift |

Golden mutation check: the same runtime renders pixel-identical (0.0%). Setting the count to 5
changes 0.095%, and the limit is 0.01%, so the test fails with the actual image path. The file was
restored afterwards.

### Trade-off 1: what an unknown widget looks like
T2.5 (native-sdk 07) said "zero height, one warning". The Flutter renderer
(`component_renderer.dart:149-190`) draws a FallbackPrompt instead: "Unsupported content", warn
severity, and a body naming the type. It reports the type once per session and draws nothing only
when FallbackPrompt itself is missing. Swift does the same, for parity. Since gate 08 decided S2
draws a basic FallbackPrompt, the prompt can be shown. Alternative: a blank, which hides the gap
from users and testers alike.

### Trade-off 2: the golden
SwiftUI's ImageRenderer cannot draw a navigation bar. `drawHierarchy` gives a black image in a test
bundle without a host app. The test therefore hosts the page in a UIKit window and renders its layer
tree. Rendering belongs to the simulator runtime, so `counter-home.runtime` stores "iOS 18.5" and
the test skips on other runtimes. CI picks 18.5 when the runner has it. If it does not, the golden
skips and the job prints which runtime it used. Re-record with `ORCA_RECORD_GOLDENS=1`
(`TEST_RUNNER_` prefix through xcodebuild).

### Findings worth remembering
F1 T2.5 differs from Flutter on unknown widgets; Swift follows Flutter (trade-off 1).
F2 Port 8080 is held by a Docker container here and 8091 by another bun process. I started the
   example server on 8097 with `PORT`, and pointed the app at it with `SIMCTL_CHILD_ORCA_SERVER_URL`.
F3 Linux Foundation in Swift 5.10 does not mark URL Sendable. HTTPRequest and OrcaClient are
   `@unchecked Sendable`, with the reason in a comment.
F4 SwiftUI views are `@MainActor`, so calls into the main-actor page model compile with pre-iOS 18
   SDKs, where `View.body` was not isolated (commit 92a37dd).
F5 The engine's own `tsc -p` fails on `--ignoreDeprecations` (tsconfig.json:19). With explicit
   flags, the only error is in unchanged engine.ts:751 (Buffer as BodyInit). Both are on main
   already; my two TS files type-check.
F6 The Flutter AppBar builder ignores the engine's `actionTriggers`; Swift ignores them too.

### Not in S2
Drawers, end drawers, bottom sheets; lifecycle and scroll triggers (`onInit`, `onScroll*`); Text
`overflow` fade and clip (SwiftUI always ellipsizes); `spaceAround`, drawn as `spaceEvenly`; the
other eight action kinds, navigation, system and server adapters (S3); FallbackPrompt policies, 426
(S4); publishing (S5).

### Repos touched
open-source only, branch feat/native-sdk-s2, from main at 02b3c60: 34 files, +2995/−10, plus
`.pipeline/`. No `cloud/` change and no wire-format change: the schema, the engine types and the
fixtures are untouched; the Swift SDK only reads them.

### Verify
`t sdk-swift:test` · `t sdk-swift:test:ios` · `t example:ios:build` · `t sdk-swift:record && git diff
--exit-code sdk-swift/Tests/Pages` · run OrcaCounter against `t example:dev:server`.
