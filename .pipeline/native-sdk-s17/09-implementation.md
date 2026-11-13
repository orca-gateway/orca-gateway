# 09 · Implementation · native-sdk-s17

## Front page

### In one breath
group 3 of 4 · tasks: 1 green, 0 blocked · cases: 5 of 6 green (all but X1) · 6 runners green
T5 Kotlin: on JDK 17, `i` with a backreference over a character above U+FFFF is written exact,
every fold-class letter masked; `\w \W \b \B` take the masked word letters' stand-ins.
G1: the U2 guard runs every row on every JDK; the lagging set is empty on JDK 24+ (asserted).
Probe, JDK 17: 2 923 rows fixed, 0 throws (were 1 754); left: properties, Dart's quirk row.
Swift, JDK 21 and 25 unchanged; both reviews passed on the first pass.

### New for you
nothing new

### Trade-offs
1 from memory: inside `(?-i:` the word stand-ins count too (your gate 08 limit, question 6).
3 auto-decided by the task (how a class tests a masked letter; ı and İ stay unmasked; a flag).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 4, T6: render fixture 38, the count pins 37 → 38. (default: go)
3. Your gate 08 limit shows on 6 JDK 17 rows outside the probe (`a(?i:(.)\1)` gu on "A" + two
   emoji → "#"; Dart: no match). Not pinned; written into row 23b.40 at close. (default: yes)

## Appendix

### Group 1
Commits: T1 17e2887, T2 bea0d78 (one per task, staged by path). Nothing pushed. Gate 08 approved under
your standing rule (every default; row 23b.40 covers every letter the platform's Unicode lacks, BMP
too; properties over such letters and JDK 17's wider `(?-i:…)` limit are known differences).

#### Task T1 · Swift: lagging classes, letters, classes
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/DartFoldClasses.swift` · `…/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: L1, C1 → green (`swift test`: 222 tests, 0 failures on macOS, swift:6.2-noble and swift:5.10-jammy;
0 build warnings on all three) · red first: the seam tests on macOS, the row tests on Linux; on macOS the
platform rows pass either way (Apple's ICU folds those pairs). Probe: L, L[], A[^], A[-], A(?i) match Dart
on all three; macOS 0 rows changed; 6.2 fixed 260 rows, 5.10 650; 0 worse.
Changed: DartFoldClasses.swift: `Regex.laggingLetters`, the NSLock-guarded seam `Regex.laggingOverride`,
`icuLagging` learned once (one compile per fold-class letter, the table's classes left out; empty on
macOS, asserted). Transforms.swift: `dartSet` at the 3 literal sites; `letterEscape()` reads a pair of
4-digit half escapes with `u` as its letter; `dartFolded` adds the lagging classes a class meets, from
`icuLaggingKept` built once per `unicode`. Tests: S17 section, 5 tests on the ICU's set and the seam's 67.
Decisions: 1. `dartSet` beside `dartFold`, the masks' callers unchanged until T3 · 2. a class adds only the
lagging classes it meets · 3. extra values (escapes, BMP `[^x]`, ranges, the pair rows) printed by Dart 3.14.
Review fit: pass (first pass and redraft)
Review quality: per-call rebuild of the lagging `Kept` in `dartFolded` on Linux, fixed (cached once per
`unicode`; built per call only while a test sets the seam)

#### Task T2 · Kotlin: lagging classes, letters, classes
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/DartFoldClasses.kt` · `…/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: L1, C1 → green (JDK 25 `./gradlew build`: core 221, sdk 128, lint no issues; `:core:test` JDK 17
and 21: core 221, 0 failures) · red first: JDK 17 283 + 471 rows, JDK 21 122 + 209, then 231 pair rows
each; on JDK 25 the seam tests. Probe: L, L[], A[^], A[-], A(?i) match Dart on 17, 21, 25; JDK 25 identical.
Changed: DartFoldClasses.kt: `lagging` (class indices, learned once with compileIcuLike CI|UC, the table's
classes left out: JDK 17 67, 21 27, 25 none) and `@Volatile internal var laggingForTests`. Transforms.kt:
`dartSet` (tests `n in DartFoldClasses.lagging`) at the literal and escape sites, with `u` above U+FFFF
and `surrogatePair` for two 4-digit half escapes; `dartClass` adds the lagging letters a class meets with
the one-pass probe shared with properties. Tests: `// MARK: S17`, 6 tests, 724 generated + 56 named rows.
Decisions: 1. the escaped pair (its first pass's "needs you"): read as its letter, your standing rule ·
2. values derived from the set computed per call, so they follow the seam · 3. on JDK 25 the seam tests
also compile each rewritten pattern case-sensitively · 4. only two 4-digit half escapes join.
Review fit: pass (first pass and redraft)
Review quality: `dartSet` built a boxed list from the lagging set for every letter under `i`, fixed
(`IntArray.contains`)

#### Group 1 test run
Once after the group, on the final code (logs `s17/g1/*.log`):
- `cd engine && bun test` · 704 pass, 1 fail (EADDRINUSE on :8080, Docker: as the baseline).
- `cd sdk && flutter test` · +244: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift build` · 0 warnings · `swift test` · 222 tests, 0 failures (217 before).
- iOS simulator · 54 + 222 tests, 0 failures · TEST SUCCEEDED.
- swift:6.2-noble and swift:5.10-jammy containers · 0 warnings · 222 tests, 0 failures each.
- `cd sdk-kotlin && ./gradlew build --rerun-tasks` on JDK 17, 21 and 25 · BUILD SUCCESSFUL · core 221,
  sdk 128, 0 failures each (core 215 before) · lint "No issues found".
- Probe (`s17/oracle/runs/*-g1.tsv`, Dart 3.14.0), rows ≠ Dart of 31 677 (Unicode 17 rows left out):
  macOS 3 and JDK 25 1 (unchanged: S16's `\B`, Dart's quirk); Linux 6.2 395 and JDK 21 393 (were 655 and
  653); Linux 5.10 995 and JDK 17 3 346 (were 1 645 and 3 996; JDK 17 still throws on 1 412). What is
  left: the backreference groups (B, B., ABmid, AB.mid, A(?i)B: group 2), JDK 17's J rows (group 3),
  properties (APLu, APLl, A[PL]: not planned), Dart's quirk, S16's `\B`.

### Group 2
Commits: T3 80bf0f0, T4 66f297e (one per task, staged by path). Nothing pushed. Group 1's card approved
under your standing rule (every default; the two older escape corners are follow-ups at close). T4 was
blocked at the round 2 card; your standing rule chose "retry once with the reviewer's fix" (round 3).

#### Task T3 · Swift: two-unit stand-ins, backreferences, guards
Files: `…/Resolver/RegexMask.swift` · `…/Resolver/Transforms.swift` · `…/OrcaGatewayCoreTests/TransformTests.swift`
Cases: R1, G1, J1 → green (`swift test`: 225 tests, 0 failures on macOS, swift:6.2-noble, swift:5.10-jammy;
0 warnings) · red first: macOS the seam test (10 assertions); Linux 6.2 1 348 R1 rows and 88 U2 rows, 5.10
3 268 and 228; on macOS R1 and U2 passed before the code (Apple's ICU folds those pairs), J1 everywhere.
Probe: B, B., ABmid, AB.mid, A(?i)B match Dart on all three; 6.2 fixed 260, 5.10 650, macOS 0; 0 worse.
Changed: RegexMask.swift: under `i` with a backreference the input's lagging letters are masked too (above
U+FFFF only with `u`), one stand-in per `dartSet` class; `Pool.takeWide` gives two-unit stand-ins (U+F0000-
FFFFD, then U+100000-10FFFD), skipping what input and pattern hold, an escaped pair included; letter
stand-ins and the copy by code point, the copy keeps its length. Transforms.swift: the masked `Kept` uses
`dartSet` (F5). Tests: U2 without `icuFolds`/`skipped`, `icuLagging` empty on Darwin; R1 over the 134
lagging pairs both ways (platform set and seam), the copy, the pool, `$1`; J1 405 rows, Dart's quirk out.
Decisions: 1. with `u` an escaped pair is held as its character · 2. S16's limit pinned for astral lagging
letters under the seam (memory "regex-mask-extra-dart-classes") · 3. values outside the probe by Dart 3.14.
Review fit: pass
Review quality: R1's loop copied T1's `differs` helper line for line, fixed (a defaulted `replacement`)

#### Task T4 · Kotlin: two-unit stand-ins, backreferences
Files: `…/resolver/RegexMask.kt` · `…/resolver/Transforms.kt` · `…/resolver/TransformTest.kt`
Cases: R1 → green (JDK 25 `./gradlew build`: core 223, sdk 128, lint no issues; `:core:test` JDK 17, 21:
223, 0 failures; no compile warnings) · red first: JDK 25 the seam test 636 rows; JDK 21 344 in each R1
test; JDK 17 209 each; the escaped-pair row red on JDK 25 (seam) and 21. Probe: JDK 21 B, B., ABmid,
AB.mid, A(?i)B match Dart; JDK 25 unchanged; JDK 17 fixed 80 (every BMP lagging row); what is left there
is over characters above U+FFFF (CIBackRef, T5's): 342 of those rows now throw instead of a wrong value.
Changed: RegexMask.kt: letters and stand-ins by code point (IntArrays); `letterSets` adds the input's
lagging letters through `dartSet` (BMP only without `u`), each class looked up once per call;
`StandInPool.takeWide` two-unit stand-ins; `escapedValues` also passes the character an escaped pair
spells. Transforms.kt: stand-ins by code point, `dartSet` in `withStandIns` and `dartClass`'s masked part
(no `!!`), an escaped pair under `u` takes its stand-in; `dartSet` internal. Tests: R1, 770 pair rows, 54
other rows, 9 `$1` steps, platform and seam; JDK 17's astral rows behind `jvmRepeats`; U2 guard untouched.
Decisions: 1. a literal astral letter and an escaped pair in a masked run take the stand-in · 2. JDK 17's
interim throws kept until T5 (its "needs you"; your standing rule, minor) · 3. the pool holds an escaped
pair's character beside both halves · 4. the U2 guard stays for T5 (the retry).
Review fit: a stand-in could equal an escaped pair's character, fixed; then the baseline U2 guard was
edited (08 F14 gives it to T5), blocked; retried on your standing rule (the guard as at bea0d78): pass
Review quality: `letterSets` built a lagging class's set for every letter of the input, fixed (once per
class per call)

#### Group 2 test run
Once more after the reworks and the retry, on the final code of both tasks (logs `s17/g2f/*.log`; the first
run, `s17/g2/`, on the first passes, gave the same counts and the same probe rows, byte for byte):
- `cd engine && bun test` · 704 pass, 1 fail (EADDRINUSE on :8080, Docker: as the baseline).
- `cd sdk && flutter test` · +244: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift build` · 0 warnings · `swift test` · 225 tests, 0 failures (222 before).
- iOS simulator · 54 + 225 tests, 0 failures · TEST SUCCEEDED.
- swift:6.2-noble and swift:5.10-jammy containers · 0 warnings · 225 tests, 0 failures each.
- `cd sdk-kotlin && ./gradlew build --rerun-tasks` on JDK 17, 21 and 25 · BUILD SUCCESSFUL · core 223,
  sdk 128, 0 failures each (core 221 before) · lint "No issues found".
- Probe (`s17/oracle/runs/*-g2f.tsv`), rows ≠ Dart of 31 677, row by row against group 1: macOS 3 and JDK 25
  1 (unchanged); Linux 6.2 135 and JDK 21 133 (260 fixed each); Linux 5.10 345 (650 fixed); JDK 17 3 266
  (80 fixed, 342 now throw, 1 754 throws). Worse: none. Left: properties (not planned), Dart's quirk,
  S16's `\B`, and on JDK 17 the rows over characters above U+FFFF (CIBackRef: group 3).

### Group 3
Commits: T5 9bc3774 (staged by path). Nothing pushed. Group 2's card (round 3) approved under your
standing rule (every default).

#### Task T5 · Kotlin: JDK 17 exact backreferences, guards
Files: `…/resolver/Transforms.kt` · `…/resolver/RegexMask.kt` · `…/resolver/TransformTest.kt`
Cases: J1, G1 → green (JDK 25 `./gradlew build`: core 226, sdk 128, lint no issues, no warnings;
`:core:test` JDK 17 and 21: 226, 0 failures) · red first: on JDK 17 the 3 new J1 tests, the U2 guard and
both R1 tests threw StringIndexOutOfBoundsException; on JDK 25 the J1 seam test (`(.)\1` written as is).
Probe: JDK 17 only properties and Dart's quirk row left, 0 throws; JDK 21, 25 byte-identical to group 2.
Changed: Transforms.kt: `repeatsAboveFfff`, learned once (seam `repeatsAboveFfffForTests`); `search` takes
the JDK 17 path (a reference under `i`, `u`, a pair in the input, the probe false): the all-letters mask
and `compile(…, exactReferences = true)`, also when the mask is null; the reader writes `(?-i:\N)` and
`(?-i:(?:\1|\2))`; outside a class `\w \W \b \B` take the masked ASCII letters' stand-ins (`wordStandIns`);
`dartClass` under `i` matches a stand-in by its whole set; S16's word-rule docs updated. RegexMask.kt:
`withAllLetters`, one stand-in per class, sets built once per class per call. Tests: G1 (`u2GuardRows` on
every JDK, lagging empty on 24+), T4's R1 filter gone, J1 404 probe rows, 28 word rows (F13), 30 class,
property and name rows, two seam tests.
Decisions: 1. `dartClass` tests a masked letter by every letter sharing its stand-in · 2. the all-letters
mask leaves ı/İ unmasked (the exact reference compares them as Dart) · 3. inside `(?-i:` the word stand-ins
count (memory "regex-jdk17-exact-backreferences", gate 08 question 6) · 4. its own exact-references flag (F11).
Review fit: pass
Review quality: pass

#### Group 3 test run
Once after the group, on the final code (logs `s17/g3/*.log`):
- `cd engine && bun test` · 704 pass, 1 fail (EADDRINUSE on :8080, Docker: as the baseline).
- `cd sdk && flutter test` · +244: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift build` · 0 warnings · `swift test` · 225 tests, 0 failures (unchanged).
- iOS simulator · 54 + 225 tests, 0 failures · TEST SUCCEEDED.
- swift:6.2-noble and swift:5.10-jammy containers · 0 warnings · 225 tests, 0 failures each.
- `cd sdk-kotlin && ./gradlew build --rerun-tasks` on JDK 17, 21 and 25 · BUILD SUCCESSFUL · core 226,
  sdk 128, 0 failures each (core 223 before) · lint "No issues found" · no Kotlin warnings.
- Probe (`s17/oracle/runs/*-g3.tsv`), rows ≠ Dart of 31 677, row by row against group 2: JDK 17 342 (fixed
  2 923, worse 0, 0 throws; were 3 266 and 1 754); Swift (macOS 3, 6.2 135, 5.10 345), JDK 21 133 and
  JDK 25 1 byte-identical. Left on every runner: properties (not planned), Dart's quirk row, S16's `\B` (Swift).
- The gate 08 limit (question 6), JDK 17 only, outside the probe (T5's own check, Dart 3.14's values):
  "#" where Dart leaves the input in `a(?i:(.)\1)` gu on "A😀😀", `(?-i:a)(.)\1` giu on "A😀😀",
  `(?-i:\w)(.)\1` giu on "ſ😀😀", `(?-i:A)(.)\1` giu on "a😀😀"; "#😀" in `(?i:(.)\1)a` gu on "bBA😀"
  and `(?i:(.)\1)|a` gu on "A😀". None pinned.

### Blocked
none (group 3) · group 2: T4 was blocked at round 2 on its second fit finding (the U2 guard edit);
retried once on your standing rule with the reviewer's fix, then fit and quality passed

### Not done
none

### Found in passing (older than S17, on macOS too; for the close)
- A class range whose two ends are escaped pairs, giu (e.g. `[` pair `-` pair `]`): Dart "#", Swift null
  (refused), 114 of 114 rows on macOS, 6.2 and 5.10 (T1's probe, `s17/t1r/`). Kotlin not probed.
- A 4-digit high-half escape then a braced low-half escape, giu: Dart reads two halves (unchanged), Swift
  matches ("#"), 114 of 114 on macOS, 70 of 114 on 6.2. Kotlin's row: Dart's value (T2's probe).

### For ship (stage 10) to know
nothing
