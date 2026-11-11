# 12 · Deploy watch · native-sdk-s13

## Front page

### In one breath
PR #20 is merged into main as f9d3935 (2026-11-11 09:10Z); its 3 checks all passed.
Swift on Linux (5.10 and 6.2) and iOS UI: green, so the Linux run left to CI matches the Mac.
S13 deploys nothing and publishes nothing: the fix ships with the next sdk-swift release.
Row 23b.35's done-when holds: a Swift test per path pins 4.0 (body, typed Value, DevTools).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), S13 closed, row 23b.35 ✅ in the epic plan.
   (default: yes)
2. The next slice, row 23b.36 (the regex corners S12 left), starts on your "Start S14".
   (default: wait for you)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #20
https://github.com/orca-gateway/orca-gateway/pull/20
- Merged 2026-11-11T09:10:03Z as f9d3935 (head 52fdd1b, the stage 10 notes included), on your
  "Merged, go on" (gate 10 approved with those words; 11 skipped by default).
- Read once at this card (`get_status`, then `gh pr view` for the merge commit): merged; checks 3
  passing, 0 failing, 0 pending.
- The checks, as the path filters expected for an sdk-swift-only change: Core tests (swift
  5.10-jammy, linux), Core tests (swift 6.2-noble, linux), UI tests and example (iOS simulator).
  The two Linux runs are the ones this Mac could not do (Docker's daemon off).

### Row 23b.35's done-when
"A Swift test per path (request body, typed Value, DevTools payload) pins `4.0`":
- request body: JSONWriteTests pins the exact wire text of the page POST (both attempts) and of
  executeAction's params, pageState and appState, and the executor's serverAction;
- typed Value: JSONValueEncoderTests pins Value, BoolExpr, Transform and Action as `.double(4.0)`,
  and `resolve` + `toString` gives "4.0";
- DevTools payload: the action payload stays 4.0 (JSONValueEncoderTests), the state_change and
  timing envelopes carry `"value":4.0` (JSONWriteTests).

### What ships when
Nothing is released by S13 (stage 11 skipped by default). The fix reaches apps with the next
`sdk-swift-v*` tag (the SwiftPM mirror), through `bash scripts/release.sh`. Flutter, Kotlin, the
engine and the schema are unchanged.

### Cleanup
- Nothing running. Scratch logs, diffs and backups stay in the session scratchpad (`s13/`).
- Not touched: your Docker (daemon off), the bun on 8091, your DevTools app on 6363.
- The untracked `sdk-kotlin/core/bin/` (an IDE's build output from 2026-11-08) is still here, not
  committed, left for you.
- The worktree's branch feat/native-sdk-s13 is merged; the session can be archived when you like.

### What S13 leaves for later
- Row 23b.36: the regex corners S12 left (modifier-group scope; ß and ligature patterns under `i`
  in Swift; escaped letters and backreferences; Kotlin's long `\p{…}` names; patterns Dart rejects).
- Not bugs, kept as found: Kotlin writes a large double as "1.0E21" where Dart writes "1e+21" (both
  read back as doubles); no end-to-end DevTools WebSocket check (the envelope text is pinned in core).
- 23b.27e: the Maven Central release is yours (User_Actions "Maven Central publishing", Step 6).
- Earlier carry-overs: a public builder hook for hosts (S9 08 F4); the DevTools compression reply
  (S8 F1); keeping the page stack across rotation (S7 F1); the example server's banner port (S9 F4);
  engine-dart's broken conformance test (S11 F13).

### Next
- On your A: stages 13-16 skipped ("S13 has no deployed service; skipped by the default accepted at
  gate 12 (A)"), S13 closed, row 23b.35 ✅ Done (PR #20).
- Then row 23b.36 on your "Start S14".

### Closed (gate 12, your standing rule, 2026-11-11)
PR #20 merged as f9d3935 with its 3 checks green (read at this card). Gate 12 approved under your
standing rule (both questions minor, both defaults); stages 13-16 skipped ("S13 has no deployed
service; skipped by the default accepted at gate 12 (standing rule, minor)"); S13 closed. Epic row
23b.35 reads ✅ Done; row 23b.36 holds the regex corners, "After S12". The next slice starts on your
"Start S14".
