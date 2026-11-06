# 08 · Tasks · native-sdk-s2

## Front page

### In one breath
S2 is PR 3: rows 23b.15 to 23b.19 from native-sdk 08. It adds OrcaClient with the 412 handshake,
a renderer for the 15 widgets, an OrcaApp root view, an iOS example app and a macOS CI job. Done
means the counter page counts on a simulator and you call stop or go. Approving unlocks code.

### New for you
Nothing new.

### Trade-offs
1 needs you: + and Reset need 3 S3 actions, pull them into S2 vs taps do nothing; default pull in.
2 needs you: UI tests, render tree on Linux + 1 golden vs ViewInspector + snapshots; default tree.
3 needs you: app-ios, a checked-in .xcodeproj vs an XcodeGen project.yml; default .xcodeproj.
4 needs you: macOS CI, nightly + tags (gate 07) vs also PRs on sdk-swift/**; default add PRs (free).

### Questions for you
1. Branch? (default: feat/native-sdk-s2 off main, S1's closing gates as its first commit, done)
2. FallbackPrompt is advertised since S1: draw a basic one now? (default: yes; S4 finishes it)
3. Simulator for the demo and the golden? (default: iPhone 16 Pro, iOS 18.5; no iPhone 15 here)
4. Stop or go after S2's UAT, as set at native-sdk gate 08? (default: yes; S3 only on go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Rows, reused from `.pipeline/native-sdk/08-tasks.md` lines 52-56, amended by trade-off 1
| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 23b.15 | `OrcaClient`: headers and the 412 caps handshake | T2.1, T2.2 against a stub transport |
| 23b.16 | Renderer, Registry, the 15 core widgets, safe degrade; setState, actionGroup, showSnackbar and showToast pulled forward from 23b.20 | T2.3, T2.5; action fixtures 01, 02, 07, 08, 13 pass in Swift |
| 23b.17 | `OrcaApp` root view, one NavigationStack, toast presentation | Counter page on a simulator; T2.4 golden |
| 23b.18 | `examples/app-ios` Xcode project on a path dependency | Opens and runs counter against `t example:dev:server` |
| 23b.19 | macOS CI job, nightly and on release tags | T2 green on macOS |

### Trade-off 1 in detail: the counter needs three actions S3 owns
The counter page's + and - buttons are `setState`, and Reset is `Sequential(setState 0,
showSnackbar)`, which is `actionGroup` on the wire. The executor is S3 (23b.20). If S2 holds the line,
the counter page draws but every tap does nothing, and the stop-or-go after S2 judges a still
picture. Default: S2 brings `setState`, `actionGroup` (sequential and parallel), `showSnackbar` and
`showToast` as reducers on the S1 seam. They are proved by action fixtures 01, 02, 07, 08 and the
counter scenario 13. S3 keeps the other eight kinds and the adapters (navigation, system, POST).

### Trade-off 2: how the UI is tested
T2.3 and T2.4 named ViewInspector and a snapshot library: two third-party test dependencies, and
both need macOS. Default: split the renderer in two. A pure `RenderTree` in the core resolves a page
plus the store into nodes (type, resolved props, children, slots, action handlers). It runs in the
existing ubuntu job, so T2.3 and T2.5 run on every PR. The SwiftUI views only draw those nodes, and a
single golden of the counter page uses SwiftUI's own `ImageRenderer` (iOS 16, macOS 13) with a small
pixel tolerance. There are no new dependencies, as in S1. The cost is that tap wiring in the views
is checked by the golden plus a manual run, not by a test that taps.

### Trade-off 3: the example project
`examples/app-ios/OrcaCounter.xcodeproj` uses Xcode 16's synchronized folders (objectVersion 77). Its
project file stays at about 150 lines and does not change when files are added. XcodeGen and Tuist
are installed here, but every contributor and the CI job would need one of them too. A
`.swiftpm` app package cannot run tests with xcodebuild. Default: the checked-in project, with a
local path dependency on `../../sdk-swift`, a base URL of `http://localhost:8080` (the simulator
reaches the host) and app id `counter`.

### Trade-off 4: when the macOS job runs
Gate 07 of native-sdk set the macOS job to run nightly and on release tags, to save macOS minutes. The
repo is public, so GitHub-hosted macOS minutes are free. The real cost is queue time of about 5 to
10 minutes per run. Default: nightly, release tags, `workflow_dispatch`, and PRs touching
`sdk-swift/**` or `examples/app-ios/**`. The ubuntu core job stays the fast gate.

### Package additions
```
sdk-swift/Sources/OrcaGatewayCore/
  Client/   HTTPTransport (protocol), URLSessionTransport (FoundationNetworking on Linux),
            DeviceInfo (screen, safe area, locale, timezone), OrcaClient: GET
            /api/v1/app/{appId}/page/{path}; on 412 caps_vector_unknown, one retry as POST with
            {_orcaCapsVector}; never a second retry (mirror of orca_client.dart lines 177-240)
  Render/   RenderTree, RenderNode, Registry (type -> builder), UnknownTypeLog (one warning per type)
  State/    Reducers: setState, actionGroup, showSnackbar, showToast (effects as data)
sdk-swift/Sources/OrcaGateway/   (SwiftUI, behind canImport)
  OrcaApp (root view, one NavigationStack, toast overlay), NodeView (subscribes to its watches),
  Widgets/ the 15: Column->VStack, Row->HStack, Center, Padding, SizedBox->frame, Text, Elevated,
  Outlined and TextButton, Card, Divider, AppBar->navigation title, Scaffold, ScrollView, FallbackPrompt
examples/app-ios/   OrcaCounter.xcodeproj, OrcaCounterApp.swift
```

### Tests (T2 group)
T2.1 handshake cases A to E from `engine/test/caps-412-protocol.test.ts`, against a stub transport.
T2.2 headers from a fixed DeviceInfo: x-orca-sdk-version, x-orca-caps-hash, x-orca-platform `iOS`,
     x-orca-os-version, screen width, height and density, the four safe-area values, locale, timezone.
T2.3 counter page, recorded once from the Bun server into the test resources (refreshed by a Taskfile
     task): 16 nodes, title "Counter Example"; + twice shows "2"; Reset shows "0" and emits one
     showSnackbar effect "Counter reset to 0", 4000 ms.
T2.4 one golden of the counter page at 393x852 pt, light, compared within a tolerance (macOS job).
T2.5 unknown widget type: no throw, zero height, one warning per type (mirror of safe_degrade_test).
Fixtures: action fixtures 01, 02, 07, 08 and 13 pass through the Swift reducers.

### Findings while planning
F1 The engine parses `x-orca-platform` as `iOS` or `Android` (`request-info.ts:32`). T2.2 wrote `ios`.
   Swift sends `iOS`, as Flutter does.
F2 The counter's Reset sends no duration, so the Dart default of 4000 ms applies. T2.3 said two
   seconds; the test uses the Dart value.
F3 FallbackPrompt has been in the Swift caps vector since S1, so the server may send one. S2 draws a
   basic one (title, message, button that opens the URL). S4 adds the three looks and the policies.

### CI
`sdk-swift.yml` gains a `ui` job on `macos-15`: `xcodebuild test` for the `OrcaGateway` scheme on an
iOS simulator, then `xcodebuild build` of `examples/app-ios`. Triggers follow trade-off 4. The ubuntu
`core` job also runs the new Linux-safe tests (T2.1, T2.2, T2.3, T2.5, the action fixtures).

### Commits on feat/native-sdk-s2 (conventional)
1 chore(pipeline): native-sdk-s1 gates 10-16 (done, dcf9f6b) · 2 chore(pipeline): native-sdk-s2
stages 01-08 · 3 feat(sdk-swift): OrcaClient and the 412 handshake (23b.15) · 4 feat(sdk-swift):
render tree, registry and the counter's reducers (23b.16) · 5 feat(sdk-swift): SwiftUI widgets and
OrcaApp (23b.16, 23b.17) · 6 feat(examples): app-ios counter (23b.18) · 7 ci(sdk-swift): macOS UI
job (23b.19) · 8 chore(pipeline): stage 09 onward.

### Verify
`t sdk-swift:test` (macOS and both Linux containers) · `xcodebuild test -scheme OrcaGateway
-destination 'platform=iOS Simulator,name=iPhone 16 Pro'` · `t example:dev:server`, then run
OrcaCounter on the simulator: + counts, Reset shows the toast.

### Not in S2
The other eight action kinds, navigation and system adapters, serverAction POST (S3); FallbackPrompt
looks and the three policies, the 426 page, the six extra widgets (S4); release.sh and the mirror (S5).
