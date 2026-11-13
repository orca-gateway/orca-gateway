# 10 · UAT · native-sdk-s16

## Front page

### In one breath
PR #24 is open: Swift and Kotlin now match Dart on the regex input side (row 23b.38).
Without `u` a pattern reads UTF-16 units; under `i` a backreference folds letters as Dart does.
5 tasks, 5 code commits, fixture 37; local suites green; its 8 checks were pending at this card.
The merge is yours; nothing is published (the SDKs ship with their next release tags).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #24 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT, optional: nothing to see; no example page uses these regex corners. (default: skip)
3. After A: 11 skipped by default; 12 reads PR #24's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #24
https://github.com/orca-gateway/orca-gateway/pull/24, opened at this stage after gate 09 was approved
under your standing rule (its last question, "approve the stage; ship pushes the branch and opens the
PR", was minor, as at S15's gate 09). Bound to this session, Auto-fix off, auto-merge off. Title
"fix(sdk-swift, sdk-kotlin): regex input side matches Dart: UTF-16 units without u, backreferences
under i (S16)". Before the push `origin/main` was d3229af (PR #23's merge), already in the branch.
Over main: the S15 close note (24e5872), the S16 pipeline notes, and the code, one commit per task:
T1 54a2d26, T2 47bf415, T3 e38e838, T4 6825fad, T5 83b56e8.
Read once at this card (`get_status`): open, mergeable; 0 passing, 8 pending, 0 failing.
Expected checks, by path filters (`sdk-swift/`, `sdk-kotlin/`, `schema/` and `.pipeline/` change): SDK
Swift (core tests, swift 5.10-jammy and 6.2-noble, linux), SDK Swift UI (iOS simulator), SDK Kotlin
(JDK 17 and 21, linux), and the engine and Flutter jobs that read `schema/`. The body is in the
session scratchpad (`s16/pr-s16.md`).

### What reviewers will find in the body
- How: a masked run (a same-length copy with private-use stand-ins, read back from the original),
  only for patterns that need it.
- T1/T2: UTF-16 units without `u`; Kotlin's step over a pair after an empty match with `u`.
- T3/T4: backreferences under `i`; Swift's 104 full-folding letters, Kotlin's ı and İ and 3 more classes.
- T5: fixture 37, 21 rows; fails 14 rows (Swift) and 15 (Kotlin) on the SDKs from before S16.
- Known differences (row 23b.38): Swift's U+FFFD per lone half; Swift's `\B` with `u` inside a pair;
  a part read without `i` over letters sharing a stand-in; 4 350+ private-use characters run unmasked.

### CI fix (2026-11-13, on your word "CI is failing on the PR. Find out why, fix it, and push.")
- Failing: Swift Linux 5.10 and 6.2, Kotlin JDK 17 and 21; one test each, the `u` half of the U2 guards
  (`testU2_withoutULettersAboveFFFFNeverFold`, `u2_guard_withULettersAboveTheBmpFold`). The other 5 checks passed.
- Cause, reproduced locally: with `u` both SDKs hand letters above U+FFFF to the platform's engine as written
  (as before S16). Linux's Foundation ICU (before Unicode 14 with 5.10, before 16 with 6.2), JDK 21 (Unicode 15)
  and JDK 17 (Unicode 13) do not fold the newer pairs (Vithkuqi, Garay). JDK 17's case-insensitive backreference
  also never repeats a capture above U+FFFF and throws at the input's end (JDK 21 and 25 are fine).
- Fix, test-only, one implementer per SDK, fit and quality passed: the `u` rows run where the raw platform engine
  folds the pair (Kotlin: backreference rows also where JDK 17's bug is absent); Apple's ICU and JDK 24+ (Unicode
  16) must leave nothing out. Minor, approved under the standing rule (decision `ci-guard-platform-unicode`).
- Left out: Linux 6.2 44 pairs, 5.10 114; JDK 21 176 rows, JDK 17 1 358; macOS and JDK 25 none.
- Runs: Swift 217/0 on macOS and in swift:6.2-noble and swift:5.10-jammy containers, 0 warnings. Kotlin
  `./gradlew build` on JDK 17, 21 and 25: core 215, sdk 128, 0 failures, lint ran.
- Found, not fixed (before S16, follow-up): JDK 17 throws on `(.)\1` giu over two emoji; with `u` the SDKs fold
  astral letters by the platform's Unicode, not Dart's.

### Not run locally
- Android's ICU path (full folding, like Swift): no test runs it anywhere.

### Next
- On your merge and `A`: 11 skipped by default (config.json), 12 reads PR #24's checks once, then S16
  closes and row 23b.38 reads ✅ Done in the epic plan.
- Row 23b.39 (Unicode 17) waits for your word.
