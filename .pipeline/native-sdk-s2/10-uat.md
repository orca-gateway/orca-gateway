# 10 · UAT · native-sdk-s2

## Front page

### In one breath
The counter runs in the simulator panel against the example server on :8097 (GET 412, POST 200).
Tap + twice, then Reset: you should see 2, then 0 and the snackbar "Counter reset to 0".
PR #4 is open against main: 6 code commits plus .pipeline/, mergeable, CI running, nothing merged.

### New for you
Nothing new.

### Trade-offs
1 auto-decided: UAT is your tap in the panel plus the tests (your call, 2026-11-06, S2 gate 09).
2 needs you: engine and sdk changed since their last tags. Release after PR #4 merges, or at S5?
  Default: after the merge (native-sdk 10 said "publish after S2"); you run release.sh, not me.
3 auto-decided: squash-merge, one commit per slice (your call, 2026-11-06, native-sdk 12).

### Questions for you
1. Tap + + then Reset in the simulator panel: 2, then 0 and the snackbar? (default: A = it worked)
2. Turn on Auto-fix for PR #4, as for PR 2? (default: yes, on approve)
3. Stop or go: S3 next (all 12 action kinds, navigation, share, server actions)? (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

PR: https://github.com/orca-gateway/orca-gateway/pull/4, `feat/native-sdk-s2` → `main`. It has 6 code
commits (e6e8b60 … 92a37dd) and 5 pipeline commits, and is mergeable. At opening, Codegen drift
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
