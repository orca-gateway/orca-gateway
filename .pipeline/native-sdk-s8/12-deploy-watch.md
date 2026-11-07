# 12 · Deploy watch · native-sdk-s8

## Front page

### In one breath
PR #14 is merged (0627f29) with S8's code and the DevTools fix; SDK Kotlin CI passed on main.
The e-commerce stock fix (edca923) missed it: I pushed it 10 minutes after your merge, so main's
demo can still go below zero. It needs a small follow-up PR. Nothing deploys or releases.
The UAT server and the emulator are stopped; your DevTools app stays open.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Open a PR for the stock fix (fix/basic-actions-stock), with S8's notes? (default: yes)
2. After A: 13-16 skipped (nothing runs as a service), S8 closed, 23b.27c ticked. (default: yes)
3. Next: S9 (23b.27d): FallbackPrompt, policies, 426 page, 10 widgets, theme hooks. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #14
https://github.com/orca-gateway/orca-gateway/pull/14, merged at 12:39:32Z as 0627f29, head
7878ecb. Its checks at 7878ecb: SDK Kotlin CI on JDK 17 and 21, push and PR, 4 of 4 success on
ubuntu (the reconnect test's Linux failure at d78a0a7 is fixed). On main after the merge, at
0627f29: SDK Kotlin CI success. Schema, Engine, SDK and Swift workflows did not trigger (no paths).
The merged PR holds S8.1a-S8.5 (0370b1d, dcc5762, b3830cc, 33bf323, 3fbd70a, c64b24a, 778c06a), the
DevTools fix 7878ecb, and the pipeline commits up to d78a0a7.

### What missed the merge
On feat/native-sdk-s8 after 7878ecb: 0ef7469 (stage 10 notes), edca923 (the e-commerce stock
fix, both reviews passed, checked on the emulator), b4a7e6b (gate 10 round 2 notes), and this
stage's commit. PR #14's description first listed the stock fix; it now says the fix comes in a
follow-up PR. On your yes, branch `fix/basic-actions-stock` from this branch's tip carries those
commits (one code commit, `examples/server/basic-actions.ts`), and the S8 close commits after A.
Its CI: no Kotlin or Swift paths change, so only the workflows that watch `examples/server`, if any.

### Cleanup
- The example server on :8097 is stopped (it was restarted twice for the stock fix); the emulator
  is closed (`adb emu kill`). Docker on 8080 and the other bun on 8091 were not touched.
- The Orca Gateway DevTools app (127.0.0.1:6363) was not running at stage 10; I opened it for U1
  and left it open.
- The API 34 system image stays installed; mockwebserver 4.12.0 is in the Gradle cache.

### What S8 leaves for later
- The stock fix PR (question 1).
- F1 at 10: dart:io's DevTools server replies against RFC 7692; `ws_server.dart` with compression
  off would help any OkHttp client. A DevTools follow-up, not S8.
- A rotation rebuilds the router at the root (S7 F1, 08 F4).
- 23b.33 (after S10): the six Dart corners and Swift's three flex drifts.
- Predictive-back preview, given up for one source of truth (gate 09 group 2, "A").

### Next
On A: the stock-fix PR opens (when question 1 is yes), stages 13-16 are skipped with the reason
"S8 has no deployed surface; skipped by the default accepted at gate 12 (A)", S8 is closed and
row 23b.27c is ticked. S9 starts from main on your go.
