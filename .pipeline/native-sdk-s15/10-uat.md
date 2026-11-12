# 10 · UAT · native-sdk-s15

## Front page

### In one breath
Round 2: PR #22's two Linux Swift jobs failed; Linux's Foundation ships an older ICU than Apple's.
Fixed in a7f9eb8: the script tests ask the platform's ICU first, as Kotlin's do; Apple checks all.
Swift 198 and iOS 54 + 198 green here, pushed; CI re-runs, and Linux runs only there.
Epic row 23b.37 and the PR body gain the Linux ICU known difference; the merge is still yours.

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

### Round 2: the Linux CI failure (your words: "CI is failing on the PR. Find out why, fix it, and push.")
- Failing: "Core tests (swift 5.10-jammy, linux)" (31 failures) and "(swift 6.2-noble, linux)" (27), both
  in `testG4_guard_everyScriptValueDartAcceptsStaysValid` and `testG4_withUAScriptValueIsOneOfECMAScriptsExactly`.
  The other 6 checks passed (Kotlin JDK 17 and 21, the iOS simulator on iOS 18.5, engine, Flutter, codegen).
- Cause: Linux's Foundation uses an older ICU, before Unicode 14 on Swift 5.10 (refuses 104 = 26 names x
  4 keys) and before 16 on 6.2 (56). Newer scripts are null there, and U+0300 lacks Unicode 16's
  Script_Extensions. Apple's ICU and Dart have Unicode 16. Matching Dart would mean shipping Unicode data.
- Fix, a7f9eb8 (tests plus one doc sentence in RegexPropertyNames.swift): `icuKnows` probes the raw
  pattern; the Garay and Cpmn rows expect null where ICU lacks the script; the four U+0300 scx rows run
  only with Unicode 16; the guard (now `...TheICUKnowsStaysValid`) compiles every value ICU knows.
  Under `#if canImport(Darwin)` both tests assert nothing was gated, so Apple still checks every row.
- Reviews: quality found the gates could close quietly on an Apple runtime (fixed by the Darwin asserts,
  then pass). CI's iOS 18.5 job had passed the old strict tests, so those asserts hold there.
- Linux was not run here (Docker off). Forcing the probe false on macOS failed only the expected rows.

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
- The session scratchpad was cleared overnight: the probe and the S15 logs are gone; the CI logs of
  round 2 are in `s15/ci/`.
