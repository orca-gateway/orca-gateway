# 09 · Implementation · native-sdk-s17

## Front page

### In one breath
group 1 of 4 · tasks: 2 green, 0 blocked · cases: 2 of 6 green (L1, C1) · suites green, 6 runners
T1 Swift: a letter or class under `i` of a class Linux's ICU lags on takes Dart's set, exactly.
T2 Kotlin: the same on the JVM; JDK 25's output is identical on all 32 575 probe rows.
Probe: 260 rows fixed on JDK 21 and Linux 6.2, 650 on JDK 17 and Linux 5.10; none worse anywhere.
Both read an escaped pair (two `\uHHHH`) with `u` as its letter (your standing rule, minor).

### New for you
nothing new

### Trade-offs
1 auto-decided: the escaped pair read as its letter, both SDKs (standing rule, minor).
2 quality findings fixed: a per-call cost under `i` in each SDK, cached once.

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 2, T3 Swift and T4 Kotlin: backreferences, two-unit stand-ins. (default: go)
3. Found, older than S17 and on macOS too: a class range with escaped-pair ends is refused (null);
   a 4-digit high half then a braced low half matches, Dart: two halves. Follow-ups. (default: yes)

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

### Blocked
none

### Not done
none

### Found in passing (older than S17, on macOS too; for the close)
- A class range whose two ends are escaped pairs, giu (e.g. `[` pair `-` pair `]`): Dart "#", Swift null
  (refused), 114 of 114 rows on macOS, 6.2 and 5.10 (T1's probe, `s17/t1r/`). Kotlin not probed.
- A 4-digit high-half escape then a braced low-half escape, giu: Dart reads two halves (unchanged), Swift
  matches ("#"), 114 of 114 on macOS, 70 of 114 on 6.2. Kotlin's row: Dart's value (T2's probe).

### For ship (stage 10) to know
nothing
