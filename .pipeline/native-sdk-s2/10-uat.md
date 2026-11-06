# 10 · UAT · native-sdk-s2

## Front page

### In one breath
The counter runs in the simulator panel against the example server on :8097 (GET 412, POST 200).
Tap + twice, then Reset: you should see 2, then 0 and the snackbar "Counter reset to 0".
PR #4: the golden failed on CI (0.34% off; Xcode 16.4 lays out 1-3 pt apart from my Xcode 27.2).
Fix pushed (521dd56): goldens named by SDK and runtime, CI pins Xcode 16.4. 10 checks green.

### New for you
Nothing new.

### Trade-offs
1 auto-decided: UAT is your tap in the panel plus the tests (your call, 2026-11-06, S2 gate 09).
2 needs you: engine and sdk changed since their last tags. Release after PR #4 merges, or at S5?
  Default: after the merge (native-sdk 10 said "publish after S2"); you run release.sh, not me.
3 auto-decided: squash-merge, one commit per slice (your call, 2026-11-06, native-sdk 12).
4 auto-decided: golden key = build SDK + runtime, Xcode pinned in CI (extends your S2 gate 09 call).

### Questions for you
1. Tap + + then Reset in the simulator panel: 2, then 0 and the snackbar? (default: A = it worked)
2. Turn on Auto-fix for PR #4, as for PR 2? (default: yes, on approve)
3. Stop or go: S3 next (all 12 action kinds, navigation, share, server actions)? (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

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
