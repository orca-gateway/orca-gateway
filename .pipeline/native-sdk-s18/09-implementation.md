# 09 · Implementation · native-sdk-s18

## Front page

### In one breath
group 3 of 3 · tasks: 1 green, 0 blocked · cases: 4 of 4 green · every suite green on 9 runners
T3: render fixture 39, 28 rows Dart, bun and both SDKs agree on everywhere; counts pinned at 39.
S18 in all, escape rows ≠ Dart: Swift macOS 262 → 0, Linux 6.2 262 → 0, Linux 5.10 251 → 0.
Kotlin had none and has no code change. Nothing without `u` and no quirk row changed.
Dart's modifier-group bug stays a known difference of the Flutter SDK (gate 08, question 4).

### New for you
nothing new

### Trade-offs
1 auto-decided: the fixture takes only rows every runner agrees on (memory, S17).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. A approves the stage: ship pushes feat/native-sdk-s18 and opens the PR. (default: go)

## Appendix

### Group 1
Commit: T1 5e729f8 (staged by path). Nothing pushed. Gate 08 approved under your standing rule (every default;
question 4: both SDKs stay on ECMAScript where Dart's modifier groups err, a known difference of the Flutter SDK).

#### Task T1 · Swift: an escaped pair is one member in a class
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: E1 → green (`swift test`: 228 tests, 0 failures, 0 warnings on macOS, Linux 6.2 and 5.10) · baseline
unchanged (225 pass; 3 added). Red first: 25 failures, every row where a pair end makes Swift refuse.
Changed: Transforms.swift: `classMember` reads escapes with `letterEscape()`: with `u` a high half's escape then a
low half's is one member, written `\x{H…}`, so a range compares code points; without `u` the reading is as before.
`letterEscape`'s and `classMember`'s comments reworded; a doc bullet after the `\u{H…}` one. TransformTests.swift:
`// MARK: S18` before `testDoubleToStringMatchesDart`, 3 tests: `testE1_withUAnEscapedPairIsOneMemberInAClass`
(14 patterns × giu/gu × 9 inputs, Dart 3.14.0's values via `differs`), `testE1_guard_withoutUTheHalvesStayUnits`
(g/gi refused as today), `testE1_anEscapedPairInAClassIsWrittenBracedWithU` (the text); pairs via `Self.escapes`.
Probe: the 3 108-row s18 probe on macOS changed on 180 E rows only, each now Dart's value.
Decisions: 1. A pair member is written braced, `\x{10400}` (the design) · 2. The without-`u` guard passes before
the fix on purpose; it leaves out the braced-end range g/gi, S16's U+FFFD known difference · 3. The new tests
share the `testE1_` prefix with S14's E1 tests (`--filter testE1` runs both).
Review fit: pass
Review quality: pass
Not done: lone halves left for T2; helpers `pairLetters`, `pairText`, `pairs` kept for T2.

#### Group 1 test run
- Swift macOS: `swift build --build-tests` 0 warnings; `swift test` 228 tests, 0 failures.
- iOS simulator (iPhone 16 Pro, FDE5D612): UI 54 and core 228, 0 failures, TEST SUCCEEDED.
- swift:6.2-noble and swift:5.10-jammy: 228 tests, 0 failures, 0 warnings.
- Engine, Flutter, Kotlin: not run (no file of theirs changed); they run in group 3.
- Probe after group 1 (`s18/g1-*.tsv`): no class-range (E1) row differs from Dart on macOS, Linux 6.2 or 5.10.
  E2's lone-half rows still differ (T2), as do S16's U+FFFD rows without `u`.
- Files changed: the task's two only (`git status`), plus pipeline notes; `sdk-kotlin/core/bin/` untracked, nobody's.

### Group 2
Commit: T2 032955d (staged by path). Nothing pushed. Group 1's card approved under your standing rule.

#### Task T2 · Swift: with `u` a lone half matches nothing
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: E2, G1 → green (`swift test`: 232 tests, 0 failures, 0 warnings on macOS, Linux 6.2 and 5.10) · baseline
unchanged (228 pass). Red first: 3 new E2 tests and the S17 written-text pin; the G1 guard and some F7 rows passed before.
Changed: Transforms.swift: with `u`, a half `letterEscape` did not pair is written `(?:(?!))` outside a class (`now`
stays `.atom`, so a quantifier may follow); in a class `classMember` gives it no text; `classSet` writes a range
over D800-DFFF as its parts outside the block, braced (`[a-\u{D801}]` → `[\x{61}-\x{D7FF}]`); T1's doc bullet and
`classMember`'s comment state the rule with an example. TransformTests.swift: four `testE2_…` tests (helpers `lone`,
`loneText`, `loneInputs`, `loneHalves`): the 9 probe patterns and the F7 rows, Dart 3.14.0's values; the two S17
written-text pins (question 5) now expect `(?:(?!))` and `(?:(?!))(?:(?!))`; the J1 comment reads "Dart's bug, a
known difference (row 23b.41)".
Decisions: 1. Only those two written-text pins changed; no value row loosened or deleted; K1 rows pin values only,
untouched · 2. F7's Dart values from a new Dart run on 10 inputs; rerun over 400 E2 and 1 560 F7 rows on macOS: every
`u` row equals Dart, no row without `u` changed · 3. F7 rows that matched Dart before stay as guards.
Review fit: pass
Review quality: pass
Not done: nothing. Its probe inputs, Dart outputs and logs: `s18/t2/`.

#### Group 2 test run
- Swift macOS: `swift build --build-tests` 0 warnings; `swift test` 232 tests, 0 failures.
- iOS simulator (iPhone 16 Pro, FDE5D612): UI 54 and core 232, 0 failures, TEST SUCCEEDED.
- swift:6.2-noble and swift:5.10-jammy: 232 tests, 0 failures, 0 warnings.
- Engine, Flutter, Kotlin: not run (no file of theirs changed); they run in group 3.
- Probe after group 2 (`s18/g2-*.tsv`): no E row differs from Dart on macOS, Linux 6.2 or 5.10 (S16's U+FFFD rows
  without `u` aside). Since before S18: 262 rows changed on macOS and 6.2, 251 on 5.10, all E rows with `u`; no
  quirk (Q) row and no row without `u` changed.
- Files changed: the task's two only, plus pipeline notes.

### Group 3
Commit: T3 47b4914 (staged by path). Nothing pushed. Group 2's card approved under your standing rule.

#### Task T3 · Fixture 39, counts pinned at 39 (+ Kotlin's quirk comment, added by hand)
Files: `schema/fixtures/render/39_regex_escaped_pairs_lone_halves.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: X1 → green (red first: the count tests said 38 where 39 was expected, Swift and both Kotlin). bun test 706
pass and the known EADDRINUSE fail; conformance 39 pass; flutter +246, analyze clean; swift 232; gradlew build green.
Changed: fixture 39, 28 rows from the candidates every runner agrees on: 16 E1 (the range giu and gu, negated,
braced / literal / mixed ends, `[a…b]`, `[\w…]`, pair to the same pair, the emoji range, `+`), 11 E2 (each lone-half
spelling, with `+`, in `(?i:…)`, after `x`, the emoji halves, the class), 1 control row (the pair as two `\uHHHH`
is "#" on 𐐀). Every pattern holds a real backslash-u; a deliberately wrong value made Swift's ResolverFixtureTests
fail (restored byte-identical). Pins 39 / "01-39" at the five places. TransformTest.kt's J1 KDoc reads "Dart's bug,
a known difference (row 23b.41)", in T2's words, comment only.
Decisions: 1. Laid out like 38 (2-space indent, ASCII with JSON escapes, `col` then the children reversed),
`expected` from the engine's encodeJsonTree · 2. Candidate kinds not on the plan's list left out (halves split by
`(?:…)`, a lone high-to-low range, the lowercase range, a class with one pair) · 3. The description writes letters as
characters and patterns as written, with Dart's values.
Review fit: pass
Review quality: pass
Not done: nothing. Generator scripts in the scratchpad (`s18/gen39.py`, `s18/expected39.ts`).

#### Group 3 test run (every suite, every runner, on the final tree)
- engine `bun test`: 706 pass, 1 fail (EADDRINUSE on :8080, a local Docker container; as baseline).
- Flutter `flutter test`: +246, all passed. `flutter analyze`: no issues.
- Swift macOS: 0 build warnings, 232 tests, 0 failures. iOS simulator (iPhone 16 Pro): UI 54, core 232, TEST
  SUCCEEDED. swift:6.2-noble and swift:5.10-jammy: 232, 0 failures, 0 warnings.
- Kotlin `./gradlew build --rerun-tasks` on JDK 25, 17 and 21: core 226, sdk 128, 0 failures; lint "No issues found".
- Probe (`s18/g3-*.tsv`), rows ≠ Dart of 3 108, before S18 → after:
| Runner | E rows (escape corners) | E rows, U+FFFD without `u` (S16) | Q rows (Dart's bug) |
|---|---|---|---|
| Swift macOS | 262 → 0 | 40 → 40 | 277 → 277 |
| Swift Linux 6.2 | 262 → 0 | 40 → 40 | 277 → 277 |
| Swift Linux 5.10 | 251 → 0 | 40 → 40 | 277 → 277 |
| Kotlin JDK 17 / 21 / 25 | 0 → 0 | 0 → 0 | 273 → 273 |
  The Q rows are Dart's modifier-group bug (both SDKs give bun's value, ECMAScript's), plus the run-time unset
  backreference known since S15 and, in Swift, S16's U+FFFD.

### S18 against the baseline (2026-11-14)
Swift 225 → 232 tests (T1 3, T2 4); Kotlin unchanged in code, tests 226 / 128 as before; engine 705 → 706 pass
(fixture 39); Flutter +245 → +246. No baseline test loosened; T2 changed two S17 written-text pins (question 5).

### Blocked
none

### Not done
none

### Found in passing (for the close)
- Dart's modifier-group bug (question 4): a row for the Flutter SDK to read `|` inside `(?i:…)`, `(?s:…)` and
  `(?m:…)` as ECMAScript does (a pattern rewrite that moves the group's flags onto each alternative, since Dart reads
  `(?:(?i:a)|(?i:x))` right), or a bug report to Dart: yours to choose (question 6 of gate 08).
- The run-time unset backreference (`(?:(a)|b)\1` on "b": Dart and bun "#", both SDKs unchanged), a known difference
  since S15: an empty marker group inside the group and `(?:\M\N|(?!\M))` for the reference may close it on ICU and
  the JVM (not tried; renumbering groups and Dart's per-iteration reset are the hard parts).

### For ship (stage 10) to know
- Branch feat/native-sdk-s18 holds S17's close note (from chore/native-sdk-s17-close), not yet on main: the PR
  carries it.
- Expected CI by path (`sdk-swift/`, `sdk-kotlin/`, `schema/`, `.pipeline/`): SDK Swift (5.10-jammy and 6.2-noble),
  SDK Swift UI (iOS), SDK Kotlin (JDK 17 and 21), engine and Flutter (they read `schema/`), codegen drift.
- At close: row 23b.41 done; its text records Dart's bug as a known difference of the Flutter SDK; the two
  follow-ups above proposed at gate 12.
