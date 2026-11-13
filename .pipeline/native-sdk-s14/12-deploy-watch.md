# 12 · Deploy watch · native-sdk-s14

## Front page

### In one breath
PR #21 is merged into main as 95bd5c8 (2026-11-11 12:02Z); its 8 checks all passed.
Swift on Linux (5.10, 6.2), not run on this Mac, is green; so is Kotlin on JDK 17 and 21.
S14 deploys nothing and publishes nothing: the fixes ship with the next sdk-swift and sdk-kotlin.
Row 23b.36's done-when holds: a test row per corner with Dart's value, and fixtures 33-34.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), S14 closed, row 23b.36 ✅ in the epic plan.
   (default: yes)
2. The next slice, row 23b.37 (the regex corners S14 left), starts on your "Start S15".
   (default: wait for you)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #21
https://github.com/orca-gateway/orca-gateway/pull/21
- Merged 2026-11-11T12:02:48Z as 95bd5c8 (head 778a111, the stage 10 notes included), on your
  "Merged, go on" (gate 10 approved with those words; 11 skipped by default).
- Read once at this card (`get_status`, then `gh pr view` for the merge commit): merged; checks 8
  passing, 0 failing, 0 pending.
- The checks: Core tests (swift 5.10-jammy, linux), Core tests (swift 6.2-noble, linux), UI tests and
  example (iOS simulator), SDK tests and example (JDK 17, linux), SDK tests and example (JDK 21,
  linux), Codegen drift detection, and two `test` jobs (the engine and Flutter, which read `schema/`).
  The two Linux Swift runs are the ones this Mac could not do (Docker's daemon off).

### Row 23b.36's done-when
"A TransformTests / TransformTest row per corner with Dart's printed value, or a render fixture where
the engine can express it":
- modifier-group scope and the `(?` forms Dart refuses: the M1/M2 rows in both SDKs (T1, T2);
- ß and ligature patterns under `i` (the 217-letter fold table): the F1 rows and a loop over every
  table letter in both SDKs (T3, T4);
- escaped letters and `\u{…}`: Dart's 37 E1 rows in both SDKs (T5, T6);
- Kotlin's long `\p{…}` names and the names Dart rejects: the P1 rows and a loop over the 690 accepted
  forms (T7, T8);
- fixtures 33 and 34 pin a selection on the engine, Flutter, Swift and Kotlin (T9).
Every expected value was printed by Dart 3.12.2. Backreferences under `i`, also named in the row's
origin, were left for row 23b.37 by your answer at gate 08 ("A, leave them").

### What ships when
Nothing is released by S14 (stage 11 skipped by default). The fixes reach apps with the next
`sdk-swift-v*` tag (the SwiftPM mirror) and `sdk-kotlin-v*` tag (Maven Central), through
`bash scripts/release.sh`. Flutter and the engine are unchanged; the schema gained fixtures 33-34.

### Cleanup
- Nothing running. Scratch logs, diffs, the Dart probe and backups stay in the session scratchpad
  (`s14/`).
- Not touched: your Docker (daemon off), the bun on 8091, your DevTools app on 6363.
- The untracked `sdk-kotlin/core/bin/` (an IDE's build output from 2026-11-08) is still here, not
  committed, left for you.
- The worktree's branch feat/native-sdk-s14 is merged; the session can be archived when you like.

### What S14 leaves for later
- Row 23b.37: backreferences under `i`; UTF-16 units without `u`; Annex B and engine-only syntax
  (now also `\u{73}` without `u`, `\x{73}`, `[\p{L}-z]` with `u`); `\P{…}` and `[^\p{…}]` under `iu`;
  on the JVM `\p{Lt}`/`\p{ASCII}` under `iu`, Script_Extensions, 62 binary names with no exact JVM
  form (and the Emoji properties on JDK 17), `Script=Qaai`; loose script values.
- Not run anywhere: the Kotlin SDK's Android ICU path (names kept as written there).
- Kept as found: Xcode's SourceKit reads the SDK's `enum Regex` as Swift's own `Regex<Output>` in
  DartFoldTable.swift and RegexPropertyNames.swift, so the editor shows false errors; `swift build`
  and CI are clean.
- Earlier carry-overs: 23b.27e (the Maven Central release is yours); a public builder hook for hosts
  (S9 08 F4); the DevTools compression reply (S8 F1); keeping the page stack across rotation (S7 F1);
  the example server's banner port (S9 F4); engine-dart's broken conformance test (S11 F13).

### Next
- On your A: stages 13-16 skipped ("S14 has no deployed service; skipped by the default accepted at
  gate 12"), S14 closed, row 23b.36 ✅ Done (PR #21).
- Then row 23b.37 on your "Start S15".

### Closed (gate 12, your standing rule, 2026-11-11)
PR #21 merged as 95bd5c8 with its 8 checks green (read at this card). Gate 12 approved under your
standing rule (both questions minor, both defaults); stages 13-16 skipped ("S14 has no deployed
service; skipped by the default accepted at gate 12 (standing rule, minor)"); S14 closed. Epic row
23b.36 reads ✅ Done; row 23b.37 holds the regex corners left, "After S14". The next slice starts on
your "Start S15".
