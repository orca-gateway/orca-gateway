# 10 · UAT · native-sdk-s14

## Front page

### In one breath
PR #21 is open (feat/native-sdk-s14 → main), bound here, Auto-fix off; main had not moved.
At this card its CI read 0 checks (just queued); Swift on Linux runs there, not here.
S14 adds no screen: TransformTests, fixtures 33-34 and the Dart probe are its proof.
Epic row 23b.36 reads "S14 PR #21"; row 23b.37 holds the corners left.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #21 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT, optional: nothing to see; no example page uses these regex corners. (default: skip)
3. After A: 11 skipped by default; 12 reads PR #21's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #21
https://github.com/orca-gateway/orca-gateway/pull/21, opened at this stage after gate 09 was
approved under your standing rule (its last question, "approve the stage; stage 10 pushes and opens
the PR", was minor). Bound to this session, Auto-fix off, auto-merge off. Title "fix(sdk-swift,
sdk-kotlin): regex corners match Dart: modifier scope, fold table, escapes, property names (S14)".
Before the push `origin/main` was f9d3935 (PR #20's merge), already in the branch, so nothing was
merged (a plain fetch; the app's sync tool was off).
Over main, the S13 close note, the S14 pipeline notes, and the code, one commit per task:
T1 282f32e, T2 bbaae14, T3 57b82e4, T4 d056388, T5 079e08a, T6 44d6a2c, T7 5315c4f, T8 790d4df,
T9 e346688.
Read once at this card (`get_status`): open; 0 passing, 0 pending, 0 failing (the checks had not
registered yet).
Expected checks, by path filters (`sdk-swift/`, `sdk-kotlin/`, `schema/` and `.pipeline/` change):
SDK Swift (core tests, swift 5.10-jammy and 6.2-noble, linux), SDK Swift UI (iOS simulator), SDK
Kotlin (JDK 17 and 21, linux), and the engine and Flutter jobs that read `schema/`. The body is in the
session scratchpad (`pr-s14.md`).

### What UAT covers here
No screen was added; the cases ran at 09 (09-implementation.md, five groups):
- M1, M2: modifier-group scope and the `(?` forms Dart refuses (TransformTests / TransformTest).
- F1: the 217-letter fold table, every letter alone and in a class under gi and giu.
- E1: Dart's 37 escape rows; P1: property names, the 690 accepted forms looped.
- X1: render fixtures 33 and 34 on the engine, Flutter, Swift and Kotlin.
- The probe (session scratchpad, `s14/oracle/`): 8 991 cases run through Dart, Swift and Kotlin;
  every difference left is row 23b.37's.
Seeing it by eye means a page whose regex uses one of these corners; no example page does.

### Epic plan (outside the repo)
- Row 23b.36: "S14 PR #21" (backup before S14's edits in the session scratchpad, `epics-before-s14.md`).
- Row 23b.37, "After S14": during 09 it gained `\u{73}` without `u` and `\x{73}`, `[\p{L}-z]` with
  `u`, the JVM's 62 binary names and the Emoji properties on JDK 17, and `\p{Script=Qaai}`.

### Cleanup
- No server or emulator ran beyond the test runners; the iOS simulator stays booted as before.
- Logs, diffs and the probe are in the session scratchpad (`s14/`).
- Not touched: your Docker (its daemon is off today), the bun on 8091, your DevTools app on 6363.
- The untracked `sdk-kotlin/core/bin/` (an IDE's build output from 2026-11-08) is still yours to
  delete or ignore.

### Next
- 11 Release: skipped by default (config.json). The fixes ship with the next `sdk-swift-v*` and
  `sdk-kotlin-v*` releases through `release.sh`.
- 12 Deploy watch: PR #21's checks, your merge.
