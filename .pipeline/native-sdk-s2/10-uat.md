# 10 · UAT · native-sdk-s2

## Front page

### In one breath
You confirmed the counter on the iOS SDK: "works perfectly". PR #4 is merged (022b45f), its last
commit passed all 8 checks, and main is green on all 4 workflows.
The iOS app cannot reach DevTools: the Swift SDK has no DevTools client, which the alpha cut.

### New for you
Nothing new.

### Trade-offs
1 done: UAT passed on your tap ("works perfectly") plus the tests.
2 needs you: engine and sdk changed since their last tags. Release now that #4 is in, or at S5?
  Default: now, at stage 11 (native-sdk 10 said "publish after S2"); you run release.sh, not me.
3 noted: #4 went in as a merge commit, not the squash native-sdk 12 chose; your call each time.
4 auto-decided: golden key = build SDK + runtime, Xcode pinned in CI (extends your S2 gate 09 call).
5 needs you: a Swift DevTools client in S3 (beside the executor), its own slice after S3, or stay
  cut (native-sdk 06)? Default: S3, about 500 lines of Swift; it also unblocks 23b.7's warnings.

### Questions for you
1. After A: 11 Release (trade-off 2), 12 records main green, 13-16 skipped: nothing is deployed.
2. Stop or go: S3 next (12 action kinds, navigation, share, server actions, DevTools per 5)?
   (default: go)
3. DevTools events are ad-hoc JSON. Add a schema and fixtures before a 2nd sender? (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Round 4: works, but no DevTools
You wrote: "works perfectly, but is it still cannot connect to orca devtools". That settles Q1, and
UAT passed. On DevTools: correct, the iOS app cannot connect, by plan. Native-sdk 06 cut "devtools
WebSocket" from the alpha, and native-sdk 08 lists it under "Not in this epic". sdk-swift has no
DevTools code.

How DevTools works today. A subagent read the code, and I checked the main points:
- The DevTools desktop app is the server. It listens on WebSocket `ws://localhost:6363`, loopback
  only (`devtools/lib/server/ws_server.dart:20`); the port can be changed in Settings.
- The Flutter SDK is the client (`sdk/lib/src/debug/dev_tools_client.dart:43`). It is opt-in
  through `OrcaApp(debugConfig: OrcaDebugConfig(enabled: true))`, and reconnects with backoff.
- Events go one way, SDK to DevTools, in an envelope `{type, deviceId, timestamp, payload}`. The
  types are `device_info` (the handshake), `timing`, `state_change`, `action`, `network`,
  `widget_rebuild` and `error`. DevTools sends nothing back.
- The engine only adds the `X-Orca-Timing` header when a request sends `x-orca-debug: true`. It
  cannot show DevTools a client that does not connect itself.
- The protocol has no schema. The payloads are Dart classes in `sdk/lib/src/debug/debug_events.dart`,
  and DevTools reads raw maps.

What a Swift client takes:
- A `DevToolsClient` on `URLSessionWebSocketTask`, in the Apple-only `OrcaGateway` target.
- The seven event types.
- Hooks in `OrcaClient` (network, timing), `ElmStore` (state_change), the executor (action) and
  `NodeView` (widget_rebuild).
- About 500 lines plus tests. The Flutter side is 604 lines in `sdk/lib/src/debug/` plus about 170
  lines of hooks.
- The simulator shares the Mac's network, so `ws://localhost:6363` reaches DevTools on the Mac with
  no setup. A physical device needs the Mac's address, and the Flutter client cannot take one today
  either: its host is hardcoded to localhost.

Why the default is S3: S3 builds the ActionExecutor and the serverAction adapter, which is where
`action` and `network` events are emitted. Adding the hooks while the executor is written is cheaper
than adding them afterwards. It would be a new 23b task, numbered at S3's stage 08.

A gap I own: 23b.7 (DevTools lists off-target warnings) is still partial. Native-sdk 09 deferred it
to S2, "needs an SDK or response transport", but S2's tasks 23b.15-19 did not include it. A Swift
DevTools client is that transport for iOS, so trade-off 5 closes it too.

Question 3: two SDKs will send these events, so their shapes can drift. Defaulting to yes means a
`schema/devtools-events.schema.json` plus fixtures, as with the page wire format. Then the Dart
sender, the Swift sender and the DevTools reader all check against one definition.

### Round 3: you merged PR #4
PR #4 merged at 2026-11-06T14:22:45Z as 022b45f, a merge commit whose tree equals the PR head
521dd56. On 521dd56 all 8 checks passed:
- Codegen drift detection, with the counter page re-recorded and no drift.
- SDK Swift CI on Linux 5.10 and 6.2.
- The UI job (run 42231778860), on Xcode 16.4 and iPhone 16 Pro with iOS 18.5. The golden test
  passed and compared rather than skipped, and examples/app-ios built.
- The engine and SDK tests.

After the merge, main ran Engine CI, Schema CI, SDK Swift CI and SDK CI, and all four passed. The
UI workflow does not run on a push to main; it runs nightly at 03:00 UTC.

Local branch: 7a58a48 (gate 10 round 2) and this round are pipeline-only commits that are not on
main. As after S1, they go onto the next slice's branch, cut from main at 022b45f.

### Round 2: the golden failed on CI
You sent the failing job (run 42225697954). The core tests passed, 71 of them; the golden reported
"0.34% of pixels differ (limit 0.01%)". CI uses Xcode 16.4 with the iOS 18.5 SDK; I recorded with
Xcode 27.2, on the same iOS 18.5 runtime. I diffed CI's actual image against the golden: it is the
same page, moved 1 to 3 points (title, the count, button heights). SwiftUI picks bar and button
metrics by the SDK the tests are built with, so pinning the runtime was not enough.

Fix, in 521dd56:
- Goldens are `<name>.sdk-<SDK>.ios-<runtime>.png`; the SDK comes from the test bundle's
  `DTPlatformVersion`.
- `counter-home.sdk-18.5.ios-18.5.png` is the image the failed CI run produced, so it matches the
  CI toolchain by construction. `…sdk-27.2.ios-18.5.png` is the old golden, renamed.
- A toolchain with no golden skips the comparison, as your gate 09 call said for other runtimes.
  The UI job pins `DEVELOPER_DIR` to Xcode 16.4, so CI keeps comparing.
- I ruled out a looser limit: the toolchain shift (0.34%) is larger than a real change of the
  count (0.095%), so any limit that absorbed it would hide the count change too.

Checked here: the UI target passes 5 of 5 on the iOS 18.5 simulator with Xcode 27.2, and the golden
compared rather than skipped. The rerun on the PR is the check for CI's golden. Every other check
on PR #4 is green: 10 of them, including Linux 5.10 and 6.2 and the engine and SDK tests.

PR: https://github.com/orca-gateway/orca-gateway/pull/4, `feat/native-sdk-s2` → `main`. It has 7 code
commits (e6e8b60 … 521dd56) plus pipeline commits, and is mergeable. At opening, Codegen drift
detection (with the new re-record step) was green. Pending: SDK Swift CI on 5.10 and 6.2, the new SDK
Swift UI job on macOS, and the engine and SDK tests. Each workflow runs twice, once for the push and
once for the PR. The epic's PR map called this PR 3; #3 went to the formatDate fix, so every later
slice's number shifts by one.

On screen now: an iPhone 16 Pro on iOS 18.5. The app was launched with
`SIMCTL_CHILD_ORCA_SERVER_URL=http://localhost:8097 xcrun simctl launch … com.orcagateway.examples.counter`,
and the server is `PORT=8097 bun run index.ts` in `examples/server`. The engine log shows the
handshake from this launch: GET 412, then POST 200. I run the server and stop it at the next gate.
Ports 8080 (Docker) and 8091 (another bun) are left alone.

What I ran before this gate (stage 09): + + gives 2, and Reset gives 0 plus the snackbar. Core tests
pass 71/71 on macOS and on Linux (5.10, 6.2), and 76 pass on the iOS simulator, including the golden.

Release (trade-off 2): engine has 17 files changed since engine-v0.3.2, and sdk has 17 since
sdk-v0.3.1. Those are S0's fixtures and effect sink plus the formatDate fix in #3; S2 touches neither.
A release would be patches through `release.sh`, run by you after PR #4 merges. The Swift SDK is not
releasable until S5's mirror exists.

Next:
- 11 Release: depends on trade-off 2; it stays skipped if you choose S5.
- 12 Deploy watch: PR #4's CI.
- 13-16: S2 has no deployed surface, only a simulator. Asked at gate 12.
- S3 (23b.20-22): ActionExecutor for all 12 kinds; navigation, openUrl, clipboard, share and
  serverAction adapters; basic-actions and server-actions on a simulator.
