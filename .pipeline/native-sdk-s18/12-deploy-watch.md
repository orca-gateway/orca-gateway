# 12 · Deploy watch · native-sdk-s18

## Front page

### In one breath
PR #26 is merged into main as 0a878be (2026-11-14 02:00Z); all 17 check runs passed.
Swift on Linux 5.10 and 6.2 and iOS ran fixture 39 and the new rows green; Kotlin and the rest too.
S18 deploys and publishes nothing: the Swift fixes ship with the next sdk-swift tag.
Row 23b.41's done-when holds: a test row per corner with Dart's value, and fixture 39.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), S18 closed, row 23b.41 ✅ with Dart's bug noted.
   (default: yes)
2. Two new rows "After S18": 23b.42 Flutter reads `|` in modifier groups as the spec; 23b.43 the
   run-time unset backreference in both SDKs. (default: add both)
3. The next slice (23b.39 Unicode 17, 23b.42 or 23b.43) starts on your word. (default: wait)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #26
https://github.com/orca-gateway/orca-gateway/pull/26
- Merged 2026-11-14T02:00:46Z as 0a878be (a merge commit; head e2eb746, the gate 09 approval). Gate 10 approved
  with your words "Merged, go on"; 11 skipped by default.
- Read once at this card (`gh pr checks 26`): 17 passing, 0 failing, 0 pending.
- The checks: Core tests (swift 5.10-jammy, linux) and (swift 6.2-noble, linux), UI tests and example (iOS
  simulator), SDK tests and example (JDK 17, linux) and (JDK 21, linux), Codegen drift detection, and the `test`
  jobs (engine; Flutter 3.47.9 and stable). All but the iOS job show twice. No CI round: the first run was green.

### Row 23b.41's done-when
"A TransformTests / TransformTest row per corner with Dart's printed value":
- with `u`, a class range whose end is an escaped pair (two `\uHHHH`): T1 (Swift), 14 patterns × giu/gu × 9 inputs;
- with `u`, lone halves spelled with a braced escape, which ICU joined: T2 (Swift), the 9 probe patterns and the
  planner's F7 rows;
- Kotlin gave Dart's value on every such row on JDK 17, 21 and 25: no code; fixture 39 runs on it (T3);
- fixture 39 pins 28 rows on the engine, Flutter, Swift and Kotlin: T3;
- Dart's quirk: not a corner to follow but Dart's bug (gate 08, question 4): no SDK change; both SDKs' test comments
  now call it a known difference, and the row says so.
Every expected value was printed by Dart 3.14.0.

### What ships when
Nothing is released by S18 (stage 11 skipped by default). The Swift fixes reach apps with the next `sdk-swift-v*`
tag (the SwiftPM mirror), through `bash scripts/release.sh`. Kotlin and the engine are unchanged; the schema gained
fixture 39.

### Proposed rows (question 2)
- **23b.42 Flutter SDK reads `|` in modifier groups as ECMAScript.** Dart 3.14 reads every alternative but the last
  of a `|` inside `(?i:…)`, `(?-i:…)`, `(?s:…)` or `(?m:…)` with the flags outside the group (classes and `.` the
  other way round, plus its disjunction optimizations' exceptions): `(?i:a|x)` g on "A" does not match. The engine
  and both native SDKs follow ECMAScript. A fix in `sdk/` rewrites such a pattern so that no `|` sits inside a
  modifier group, moving the group's flags onto each alternative (Dart reads `(?:(?i:a)|(?i:x))` right), or the
  bug goes to Dart's tracker (yours to file). Done when: Flutter gives bun's value on S18's probe rows.
- **23b.43 Both SDKs: a backreference to a group that takes part only at run time matches empty when it did not.**
  `(?:(a)|b)\1` on "b" and `(a)?b\1`: Dart and bun "#", both SDKs unchanged (ICU and the JVM fail a reference to an
  unset group); a known difference since S15. Idea, not tried: an empty marker group inside the group, and
  `(?:\M\N|(?!\M))` for the reference; the hard parts are renumbering the groups (replacement `$N`, named groups)
  and Dart's reset of a quantified group's captures on each pass.

### Cleanup
- Nothing of this session is running. Scratch logs, probes and the PR body stay in the session scratchpad (`s18/`).
  The Linux Swift runs used throwaway `docker run --rm` containers of the local swift images; nothing pulled, no
  other container touched. The iOS runs used the iPhone 16 Pro simulator (FDE5D612).
- Not touched: Docker's other containers (holding :8080), the bun on 8091, DevTools on 6363, the orca-extender
  session's `flutter run` on simulator D3CED13C.
- The untracked `sdk-kotlin/core/bin/` (an IDE's build output from 2026-11-08) is still here, left for you.
- feat/native-sdk-s18 is merged; this close note is on the local branch chore/native-sdk-s18-close (from 0a878be,
  not pushed), for the next slice to carry, as S17's was.

### What S18 leaves for later
- Row 23b.39: Dart 3.14 reads Unicode 17 (54 letters, four scripts).
- Rows 23b.42 and 23b.43 (question 2), above.
- A group name with a pair spelled as two 4-digit escapes (Transforms.swift's doc): not probed.
- Not run anywhere: the Kotlin SDK's Android ICU path.
- S16's and S17's carry-overs stand as their 12-deploy-watch.md list them.

### Next
- On A: stages 13-16 skipped ("S18 has no deployed service; skipped by the default accepted at gate 12"), S18
  closed, row 23b.41 ✅ Done with Dart's bug as its known difference, rows 23b.42 and 23b.43 added "After S18".
- Then the next slice on your word.

### Closed (gate 12, your standing rule, 2026-11-14)
PR #26 merged as 0a878be with its 17 check runs green (read at this card). Gate 12 approved under your standing
rule (all three questions minor, all defaults); stages 13-16 skipped ("S18 has no deployed service; skipped by the
default accepted at gate 12 (standing rule, minor)"); S18 closed. Epic row 23b.41 reads ✅ Done, Dart's
modifier-group bug its known difference; rows 23b.42 (Flutter reads `|` in modifier groups as ECMAScript) and
23b.43 (the run-time unset backreference in both SDKs) are added after 23b.41, "After S18". The next slice starts
on your word.
