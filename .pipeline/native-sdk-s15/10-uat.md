# 10 · UAT · native-sdk-s15

## Front page

### In one breath
PR #22 is open (feat/native-sdk-s15 → main), bound here, Auto-fix off; main had not moved.
At this card its CI read 0 checks (just queued); Swift on Linux runs there, not here.
S15 adds no screen: TransformTests, fixtures 35-36 and the Dart probe are its proof.
Epic row 23b.37 reads "S15 PR #22", its known differences extended; row 23b.38 is next.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #22 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT, optional: nothing to see; no example page uses these regex corners. (default: skip)
3. After A: 11 skipped by default; 12 reads PR #22's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #22
https://github.com/orca-gateway/orca-gateway/pull/22, opened at this stage after gate 09 was
approved under your standing rule (its last question, "approve the stage; ship pushes the branch and
opens the PR", was minor). Bound to this session, Auto-fix off, auto-merge off. Title "fix(sdk-swift,
sdk-kotlin): regex corners match Dart: Annex B, strict u, group names, iu properties, script values
(S15)". Before the push `origin/main` was 95bd5c8 (PR #21's merge), already in the branch, so
nothing was merged (a plain fetch).
Over main: the S14 close note, the S15 pipeline notes, and the code, one commit per task:
T1 7745123, T2 cd26087, T3 1cd4648, T4 f4c0995, T5 f1e7fbe, T6 be6c8ff, T7 023adc7, T8 036a741 and
3a5ecfd (its redraft), T9 47bf87a, T10 adf246f, T11 f4381a3.
Read once at this card (`get_status`): open; 0 passing, 0 pending, 0 failing (the checks had not
registered yet).
Expected checks, by path filters (`sdk-swift/`, `sdk-kotlin/`, `schema/` and `.pipeline/` change):
SDK Swift (core tests, swift 5.10-jammy and 6.2-noble, linux), SDK Swift UI (iOS simulator), SDK
Kotlin (JDK 17 and 21, linux), and the engine and Flutter jobs that read `schema/`. The body is in the
session scratchpad (`pr-s15.md`).

### What UAT covers here
No screen was added; the cases ran at 09 (09-implementation.md, six groups):
- A3: quantifiers on quantifiers and assertions refused (T1, T2).
- A1, A2: Annex B without `u`, the pre-pass (T3, T4); G3: the strict grammar with `u` (T5, T6).
- Group names, unset references matching empty (T7, T8); G4: `iu` properties, script values (T9, T10).
- X1: render fixtures 35 and 36 on the engine, Flutter, Swift and Kotlin (T11).
- The probe (session scratchpad, `s15/oracle/`): a1 718 and rows 233 cases through Dart, Swift and
  Kotlin, plus the extra sets ctl … t10; every difference left is a known difference, not planned,
  or row 23b.38's.
Seeing it by eye means a page whose regex uses one of these corners; no example page does.

### Epic plan (outside the repo)
- Row 23b.37: "S15 in progress" → "S15 PR #22" (backup in the session scratchpad,
  `epics-before-s15-ship.md`).
- Its known differences gain, as approved at group 4's card: a backreference inside a lookbehind
  (ICU and the JVM refuse it) and a group name spelled with two surrogate escapes.
- Row 23b.38 (S16, the input side: backreferences under `i`, UTF-16 units without `u`) is unchanged.

### Follow-ups, outside row 23b.37
- `DartFoldTable`'s `u` column duplicates `DartFoldClasses` (a test pins they agree).
- Swift's `tableKept` comment also covers `propertyKept`.
- The S14 test name `p1_guard_scriptKeysLeaveTheValueToTheEngine` (TransformTest.kt) no longer says
  what it checks.
- S14's TransformTest.kt still holds U+00A0 ×2, U+2003 ×2 and U+0301 ×3 written literally.

### Cleanup
- No server or emulator ran beyond the test runners; the iOS simulator stays booted as before.
- Logs, diffs and the probe are in the session scratchpad (`s15/`).
