# 12 · Deploy watch · native-sdk-s17

## Front page

### In one breath
PR #25 is merged into main as cbc4b0f (2026-11-14 00:39Z); all 17 check runs passed.
Linux Swift 5.10 and 6.2, JDK 17 and 21 ran the U2 guards and fixture 38 with no row left out.
S17 deploys and publishes nothing: the fixes ship with the next sdk-swift and sdk-kotlin tags.
Row 23b.40's done-when holds: a test row per platform gap with Dart's value, on every runner.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), S17 closed, row 23b.40 ✅ with its six JDK 17 rows.
   (default: yes)
2. A new row 23b.41 for three corners older than S17: Dart's `(?i:(.)\1|x)` quirk and two
   escaped-pair corners Swift reads unlike Dart. (default: add it, "After S17")
3. The next slice (23b.39 Unicode 17, or 23b.41) starts on your word. (default: wait for you)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #25
https://github.com/orca-gateway/orca-gateway/pull/25
- Merged 2026-11-14T00:39:34Z as cbc4b0f (a merge commit; head 76dbea4, the gate 09 approval). Gate 10
  approved with your words "Merged, go on"; 11 skipped by default.
- Read once at this card (`get_status`, `gh pr checks 25`): 17 passing, 0 failing, 0 pending.
- The checks: Core tests (swift 5.10-jammy, linux) and (swift 6.2-noble, linux), UI tests and example
  (iOS simulator), SDK tests and example (JDK 17, linux) and (JDK 21, linux), Codegen drift detection,
  and the `test` jobs (engine; Flutter 3.47.9 and stable). All but the iOS job show twice.
- No CI round this time: the first run was green. PR #24's CI is where the gap was found; the guards it
  filtered by platform now run every row on the same four Linux runners.

### Row 23b.40's done-when
"A TransformTests / TransformTest row per platform gap with Dart's printed value, run on Swift 5.10 and
6.2 on Linux and on JDK 17 and 21 with nothing left out":
- letters and classes under `i` written as Dart's set (the 10 BMP pairs, Vithkuqi, Garay): T1 (Swift),
  T2 (Kotlin);
- backreferences under `i` over those letters, two-unit stand-ins above U+FFFF: T3 (Swift), T4 (Kotlin);
  the U2 guards run every row on every platform again (Swift in T3, Kotlin in T5);
- JDK 17's backreference over characters above U+FFFF, written exact, no throw: T5 (Kotlin);
- fixture 38 pins 30 rows on the engine, Flutter, Swift and Kotlin: T6.
Every expected value was printed by Dart 3.14.0. CI ran all of it on the four named runners (check
names above). The differences left are the row's known differences, plus the six JDK 17 rows below.

### What ships when
Nothing is released by S17 (stage 11 skipped by default). The fixes reach apps with the next
`sdk-swift-v*` tag (the SwiftPM mirror) and `sdk-kotlin-v*` tag (Maven Central), through
`bash scripts/release.sh`. The engine is unchanged; the schema gained fixture 38.

### Row 23b.40's known differences gain (question 1)
Seen at group 3 on JDK 17, outside the probe, not pinned: "#" where Dart leaves the input in
`a(?i:(.)\1)` gu on "A😀😀", `(?-i:a)(.)\1` giu on "A😀😀", `(?-i:\w)(.)\1` giu on "ſ😀😀", `(?-i:A)(.)\1`
giu on "a😀😀"; "#😀" in `(?i:(.)\1)a` gu on "bBA😀" and `(?i:(.)\1)|a` gu on "A😀". All are the limit
accepted at gate 08: on JDK 17, a part read without `i` cannot tell apart letters of one class.

### Proposed row 23b.41 (question 2)
Three corners older than S17, on macOS too, none a platform gap:
- Dart's quirk: inside `(?i:A|B)`, a backreference in the first alternative compares case-sensitively
  in Dart (`(?i:(.)\1|x)` gu on "Aa": Dart leaves it); both SDKs fold (1 probe row on every runner).
- With `u`, Swift refuses a class range whose two ends are escaped surrogate pairs; Dart matches ("#").
  114 of 114 rows on macOS, 6.2 and 5.10 (T1's probe). Kotlin not probed.
- With `u`, a 4-digit high-half escape then a braced low-half escape: Dart reads two halves (no match),
  Swift reads one letter ("#"). 114 of 114 on macOS, 70 of 114 on 6.2 (T1's probe); Kotlin gives Dart's
  value (T2's probe).
A fix is pattern-side, in each SDK's translator. Done when: a test row per corner with Dart's value.

### Cleanup
- Nothing of this session is running. Scratch logs, probes and the PR body stay in the session
  scratchpad (`s17/`). The Linux Swift runs used throwaway `docker run --rm` containers of the local
  swift images; nothing pulled, no other container touched.
- The iPhone 18 Pro simulator T6 booted (8AFF09C9) is shut down again. Not touched: Docker's other
  containers (holding :8080), the bun on 8091, DevTools on 6363, the orca-extender session's
  `flutter run` on simulator D3CED13C.
- The untracked `sdk-kotlin/core/bin/` (an IDE's build output from 2026-11-08) is still here, left for you.
- feat/native-sdk-s17 is merged; this close note is on the local branch chore/native-sdk-s17-close
  (from cbc4b0f, not pushed), for the next slice to carry, as S16's was.

### What S17 leaves for later
- Row 23b.39: Dart 3.14 reads Unicode 17 (54 letters, four scripts); S17's probe left them out.
- Row 23b.41 (question 2), above.
- Probe rows still ≠ Dart after S17: macOS 3, JDK 25 1, Linux 6.2 135, JDK 21 133, Linux 5.10 345,
  JDK 17 342. They are properties over letters the platform lacks (a known difference), Dart's quirk,
  and S16's two `\B` rows in Swift (a known difference of 23b.38).
- Not run anywhere: the Kotlin SDK's Android ICU path.
- S16's carry-overs stand as its 12-deploy-watch.md lists them (`\w` after a `(?i:…)` group, naming
  nits, devtools' old Material import, the earlier slices' items).

### Next
- On A: stages 13-16 skipped ("S17 has no deployed service; skipped by the default accepted at gate
  12"), S17 closed, row 23b.40 ✅ Done with the six rows, row 23b.41 added "After S17".
- Then the next slice on your word.

### Closed (gate 12, your standing rule, 2026-11-14)
PR #25 merged as cbc4b0f with its 17 check runs green (read at this card). Gate 12 approved under your
standing rule (all three questions minor, all defaults); stages 13-16 skipped ("S17 has no deployed
service; skipped by the default accepted at gate 12 (standing rule, minor)"); S17 closed. Epic row
23b.40 reads ✅ Done, its known differences with the six JDK 17 rows; row 23b.41 (Dart's quirk and
Swift's two escaped-pair corners) is added after 23b.40, "After S17". The next slice starts on your word.
