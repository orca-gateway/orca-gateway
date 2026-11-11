# 10 · UAT · native-sdk-s13

## Front page

### In one breath
PR #20 is open (feat/native-sdk-s13 → main), bound here, Auto-fix off; main had not moved.
At this card its CI read 0 passing, 2 pending, 0 failing; Swift on Linux runs there.
S13 adds no screen: the wire-text and encoder tests are its proof (Swift 147, iOS 54 + 147).
Epic row 23b.35 reads "S13 PR #20"; row 23b.36 holds the regex corners left.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #20 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT, optional: none to see; DevTools would show 4.0 where it showed 4. (default: skip it)
3. After A: 11 skipped by default; 12 reads PR #20's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #20
https://github.com/orca-gateway/orca-gateway/pull/20, opened at this stage after gate 09 was
approved under your standing rule (its only question, "approve and push", was minor). Bound to this
session, Auto-fix off, auto-merge off. Title "fix(sdk-swift): write a JSON 4.0 back as 4.0, as Dart
does (S13)". Before the push `origin/main` was 29d77e9 (PR #19's merge), already in the branch, so
nothing was merged (a plain fetch; the app's sync tool was off).
Over main, 7 commits: S12's two closing notes (cherry-picked), the S13 pipeline notes, and the code,
one commit per task — T1 f084f57, T2 ec1e057.
Read once at this card (`get_status`): open; 0 passing, 2 pending, 0 failing (just started).
Expected checks, by path filters (only `sdk-swift/` and `.pipeline/` change): SDK Swift (Core
tests, swift 5.10-jammy and 6.2-noble, linux) and SDK Swift UI (UI tests and example, iOS
simulator). The body is in the session scratchpad (`pr-s13.md`).

### What UAT covers here
No screen was added; the cases ran at 09:
- W1: JSONWriteTests' number table (Dart's printed text for 4.0, 100.0, -0.0, 1e-7, 1e21, …),
  escaping, key order, and a generator round trip that checks each number's kind.
- W3: the exact wire text of the page POST (both attempts), executeAction's params, pageState and
  appState, the executor's serverAction, and the DevTools envelopes (state_change, timing, action).
- W2: JSONValueEncoderTests: Value, BoolExpr, Transform, Action, the caps vector, DevTools'
  payload, `resolve` + `toString` → "4.0", NaN → `.null`, the containers against JSONEncoder.
Seeing it by eye means watching DevTools while a page sets a state to 4.0; no example page does.

### Epic plan (outside the repo)
- Row 23b.35: "S13 PR #20" (backup before S13's edits in the session scratchpad,
  `epics-before-s13.md`).
- Row 23b.36: unchanged, "After S12".

### Cleanup
- No server or emulator ran beyond the test runners; the iOS simulator stays booted as before.
- Logs and diffs are in the session scratchpad (`s13/`).
- Not touched: your Docker (its daemon is off today), the bun on 8091, your DevTools app on 6363.
- The untracked `sdk-kotlin/core/bin/` (an IDE's build output from 2026-11-08) is still yours to
  delete or ignore.

### Next
- 11 Release: skipped by default (config.json). The Swift fix ships with the next `sdk-swift-v*`
  release through `release.sh`.
- 12 Deploy watch: PR #20's checks, your merge.
