# 12 · Deploy watch · native-sdk-s16

## Front page

### In one breath
PR #24 is merged into main as 2b4daeb (2026-11-13 20:17Z); all 13 check runs passed.
The CI fix (017811a, b175eef) made the U2 guards ask the platform first; Linux and JDK 17/21 green.
S16 deploys nothing and publishes nothing: the fixes ship with the next sdk-swift and sdk-kotlin.
Row 23b.38's done-when holds: a test row per corner with Dart's value, and fixture 37.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), S16 closed, row 23b.38 ✅ in the epic plan.
   (default: yes)
2. A new row 23b.40 for what the CI fix found: with `u` the SDKs fold letters above U+FFFF by the
   platform's Unicode, and JDK 17's backreference bug. (default: add it, "After S16")
3. The next slice (23b.39 Unicode 17, or 23b.40) starts on your word. (default: wait for you)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #24
https://github.com/orca-gateway/orca-gateway/pull/24
- Merged 2026-11-13T20:17:13Z as 2b4daeb (head e89cc33, the CI fix and its notes included). Gate 10
  approved with your words "Merged, go on"; 11 skipped by default.
- Read once at this card (`gh pr checks 24`): 13 passing, 0 failing, 0 pending.
- The checks: Core tests (swift 5.10-jammy, linux) and (swift 6.2-noble, linux), UI tests and example
  (iOS simulator), SDK tests and example (JDK 17, linux) and (JDK 21, linux), Codegen drift detection,
  and the `test` jobs (engine; Flutter 3.47.9 and stable). The Swift and Kotlin jobs show twice.
- One CI round at gate 10, on your "CI is failing on the PR. Find out why, fix it, and push.": the
  first run failed one guard per Swift Linux and Kotlin job (10-uat.md, "CI fix"). Test-only fix, one
  implementer per SDK, fit and quality passed, decision `ci-guard-platform-unicode` (standing rule, minor).

### Row 23b.38's done-when
"A TransformTests / TransformTest row per corner with Dart's printed value, or a render fixture where
the engine can express it":
- without `u`, UTF-16 code units (`.`, `[^a]`, `\S`, `[😀]`, `\uD83D`, empty matches between halves): T1
  (Swift), T2 (Kotlin);
- letters above U+FFFF fold only with `u` (`𐐀` gi on "𐐨"): T1, T2;
- Kotlin with `u`, the step over a pair after an empty match (`x*` gu): T2;
- backreferences under `i` (`(s)\1` gi on "sſ", `(.)\1` gi on "ßẞ", "ıI" on the JVM): T3, T4;
- fixture 37 pins 21 rows on the engine, Flutter, Swift and Kotlin: T5.
Every expected value was printed by Dart 3.14.0. The differences left are the row's known differences
(the `(?-i:…)` wording widened at gate 09).

### What ships when
Nothing is released by S16 (stage 11 skipped by default). The fixes reach apps with the next
`sdk-swift-v*` tag (the SwiftPM mirror) and `sdk-kotlin-v*` tag (Maven Central), through
`bash scripts/release.sh`. The engine is unchanged; the schema gained fixture 37.

### Proposed row 23b.40 (question 2)
With `u`, both SDKs hand letters above U+FFFF to the platform's engine as written, which folds them by
its own Unicode: Linux's Foundation ICU (before Unicode 14 with Swift 5.10, before 16 with 6.2), JDK 21
(15), JDK 17 (13), and Android's ICU by API level miss case pairs Dart has (Vithkuqi, Garay). JDK 17's
case-insensitive backreference never repeats a capture above U+FFFF and throws at the input's end
(`(.)\1` giu on two emoji; Android, on ICU, does not have the bug). Both were there before S16; the U2
guards now check only what the platform folds. A fix folds astral letters from Dart's classes, as the
BMP already is, and keeps JDK 17's backreference off astral captures.

### Cleanup
- Nothing of this session is running. Scratch logs and diffs stay in the session scratchpad (`s16/`).
  The Linux Swift runs used throwaway `docker run --rm` containers of the local swift images; nothing
  pulled, no other container touched.
- Not touched: Docker's other containers (holding :8080), the bun on 8091, DevTools on 6363, the
  orca-extender session's `flutter run` on the simulator.
- The untracked `sdk-kotlin/core/bin/` (an IDE's build output from 2026-11-08) is still here, left for you.
- feat/native-sdk-s16 is merged; this close note is on the local branch chore/native-sdk-s16-close
  (from 2b4daeb, not pushed), for the next slice to carry, as S15's was.

### What S16 leaves for later
- Row 23b.39: Dart 3.14 reads Unicode 17 (54 letters, four scripts); S16's cases leave them out.
- Row 23b.40 (question 2), above.
- Found while probing: under `gu`, once a `(?i:…)` group exists anywhere, Dart's `\w` outside it also
  matches ſ and the Kelvin sign; neither SDK does (3 probe rows).
- Small follow-ups: `letterStandIns` vs `lettersStandIns` naming in RegexMask.swift; Kept's doc
  (Transforms.swift) is incomplete; S15's list (`DartFoldTable`'s `u` column duplicates
  `DartFoldClasses`; Swift's `tableKept` comment; the S14 test name
  `p1_guard_scriptKeysLeaveTheValueToTheEngine`; S14's literal invisible characters in TransformTest.kt).
- `devtools/` still imports the old Material library.
- Not run anywhere: the Kotlin SDK's Android ICU path.
- Earlier carry-overs: 23b.27e (the Maven Central release is yours); a public builder hook for hosts
  (S9 08 F4); the DevTools compression reply (S8 F1); keeping the page stack across rotation (S7 F1);
  the example server's banner port (S9 F4); engine-dart's broken conformance test (S11 F13).

### Next
- On A: stages 13-16 skipped ("S16 has no deployed service; skipped by the default accepted at gate
  12"), S16 closed, row 23b.38 ✅ Done, row 23b.40 added "After S16".
- Then the next slice on your word.

### Closed (gate 12, your standing rule, 2026-11-13)
PR #24 merged as 2b4daeb with its 13 check runs green (read at this card). Gate 12 approved under your
standing rule (all three questions minor, all defaults); stages 13-16 skipped ("S16 has no deployed
service; skipped by the default accepted at gate 12 (standing rule, minor)"); S16 closed. Epic row
23b.38 reads ✅ Done; row 23b.40 (astral letters with `u` by Dart's classes, JDK 17's backreference
bug) is added after 23b.39, "After S16". The next slice starts on your word.
