# 09 · Implementation · native-sdk-s15

## Front page

### In one breath
group 6 of 6 · tasks: 1 green, 0 blocked · cases: 11 of 11 green · suites green
T11: render fixtures 35 (Annex B, strict `u`) and 36 (group names, unset refs, script values).
Count pins 34 -> 36 in Swift and Kotlin; every runner resolves both fixtures as Dart does.
Tests: engine 705, Flutter 243, Swift 198, iOS 54 + 198, Kotlin core 197, sdk 128, lint clean.
Stage: 11 of 11 tasks green over 6 groups, 0 blocked; committed on the branch, nothing pushed.

### New for you
nothing new

### Trade-offs
1 needs you: fixture size, 18 rows each (~23 KB) vs trim to ~15 (33-34 are 16-18 KB).
2 auto-decided: a script writes both fixtures; 19 repeat rows stay unit-test rows only.

### Questions for you
1. Fixtures 35-36: keep 18 rows each (~23 KB) or trim to ~15? (default: keep)
2. `A` approves the stage; ship (stage 10) pushes the branch and opens the PR. (default: go)

## Appendix

### Group 1
Commits: T1 7745123, T2 cd26087 (one per task, staged by path). Nothing pushed. Gate 08 approved with
your standing rule (every default; input masking moved to row 23b.38).

#### Task T1 · Swift: quantifiers on quantifiers, assertions
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: A3 → green (`swift test`: 171 tests, 0 failures; baseline 168 untouched, 3 new) · red first: 21
rows (`a++ a*+ a?+ a{1,2}+ a{1,}+ ^* $+ \b* \B+ (?i:\b+)` under g and gu, `^*a` with gm); the rows ICU
already refused (`a{1}{2}`, `{3}`, `a**`, `(?<=a)*`, `*a` …) passed before any code.
Changed: `asciiClasses` keeps a stack of `Group`s (its `i`, its kind, where its text starts in the
output) and the last token (`Last`); a quantifier after nothing, an assertion (`^ $ \b \B`, a
lookbehind) or another quantifier gives nil, one lazy `?` allowed; `quantifier()` reads `* + ?`,
`{n}`, `{n,}`, `{n,m}`; a doc bullet states the rule. Tests: `// MARK: S15 — quantifiers (row
23b.37)`, 3 table-driven tests (refused, kept, guards), values printed by Dart (`s15/oracle/t1/`).
Decisions: 1. a lookahead's `)` and a non-quantifier `{` are ordinary atoms for now; `a{2,1}` left to
ICU, which refuses it · 2. `Group.start` = `out.utf8.count` · 3. lookaround openers copied whole.
Review fit: pass
Review quality: pass

#### Task T2 · Kotlin: quantifiers on quantifiers, assertions
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: A3 → green (`./gradlew build`: core 156, sdk 128, 0 failures, lint no issues; baseline core
151 untouched, 5 new) · red first: 3 of the 5 new tests; rows the JVM already refused passed before.
Changed: the fast path (old :450) is gone; `open` holds `Group(fold, kind, start)`, `groupOpening`
returns one; `quantifierEnd` reads the quantifier forms; a `Last` state is set by every token; a
quantifier is null unless it follows an atom or is one lazy `?`; `^ $ \b \B` and a lookbehind's `)`
are assertions; `|` and an opening reset it; KDoc states the rule. Tests: `// MARK: S15 —
quantifiers (row 23b.37)`, a `refused(...)` helper, 5 tests, 31 extra rows printed by Dart.
Decisions: 1. fast path removed (same output) · 2. `{n,m}` bounds not compared; `a{2,1}` null by the
JVM · 3. a lookahead's `)` is an ordinary atom; `start` recorded for T4.
Review fit: pass
Review quality: enum entries in SCREAMING_CASE where sdk-kotlin uses PascalCase, fixed (one rework:
`Last { None, Assertion, Atom, Quantifier, Lazy }`, `GroupKind { Capturing, NonCapturing, Lookahead,
Lookbehind }`; core 156, sdk 128, lint clean after)

#### Group 1 test run
Once after the group (logs `s15/g1-*.log`), before T2's rename (each implementer and the probe ran
after it):
- `cd engine && bun test` · 703 pass, 0 fail.
- `cd sdk && flutter test` · +241: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · 171 tests, 0 failures · iOS simulator · TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` · BUILD SUCCESSFUL · core 156, sdk 128, 0 failures · lint clean.
- Probe (`s15/reprobe.sh`): rows A3 39: Swift 0, Kotlin 0 differ (were 16 and 24). a1: Swift 317 of
  718 differ (was 333), Kotlin 345 (was 367); the quantifier cases left are quantified lookaheads
  (groups 2-3) and empty matches between a surrogate pair's halves (row 23b.38).

### Group 2
Commits: T3 1cd4648, T4 f4c0995 (one per task, staged by path). Nothing pushed. Group 1's card approved
with your standing rule (its one question, start group 2, minor); group 2's first card the same (retry
T4 once, then group 3).

#### Task T3 · Swift: pre-pass, Annex B without `u`
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: A1 (57 rows) and the `gu` rows `\0`, `[\0]` → green (`swift test`: 176 tests, 0 failures; the 171
of before pass) · red first: 6 tests, 184 failures; 12 of the 57 rows already gave Dart's value.
Changed: a pre-pass counts groups and collects names (the loop reuses its `opening()` test);
`character(inClass:)` reads Annex B escapes, legacy octal and NUL; `classSet` reads ranges (out of
order nil in both modes, a class escape in a range a union without `u`) and escapes ASCII
punctuation; `[]` is `(?!)`, `[^]` `[\s\S]`; without `u` a lone `{ } ]` is text and a quantified
lookahead is wrapped `(?:…)`; doc comment rewritten. Tests: 5 `testA1_*` tables (every A1 row, 58 more
Dart-printed rows, `s15/oracle/t3`); `testP1_guard_withoutUTheNameIsNotRead` now checks Dart's values
(F14, stricter than its non-null check).
Decisions: 1. every ASCII punctuation mark in a class escaped, control characters as `\x{H}` · 2.
with `u`, rows Dart refuses (`[[:alpha:]]`, `[]a]` …) give other wrong values until T5 · 3. F14's test
edited by design.
Review fit: pass
Review quality: dead guards in `dartFolded` (empty body, `^` first) and a `!unicode ||` once every
class punctuation mark is escaped, fixed (one rework: removed, comments made true; 176 unchanged)

#### Task T4 · Kotlin: pre-pass, Annex B without `u`
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: A1 (57 rows) and the `gu` rows `\0`, `[\0]` → green (`./gradlew build`: core 165, sdk 128, 0
failures, lint no issues; core 156 of before pass) · red first: 8 of 9 new tests (the lookahead guard
passed: the JVM reads quantified lookaheads).
Changed: a `captures` pre-pass (count, names); without `u` Annex B escapes (`spelled`, `octal`,
`backreference`); `\0` NUL in both modes; a non-syntax `{ } ]` literal; classes by `classAtom`: `[]`
`(?!)`, `[^]` `[\s\S]`, ASCII punctuation escaped, a class-escape range a union, an unclosed class
null; KDoc states the rules. Tests: 9 tests, 101 rows (43 Dart-printed extras, `s15/oracle/t4`).
Decisions: 1. `\c` + ASCII letter written as its code point in both modes (Java reads `\ca` as
U+0021) · 2. an unclosed class null at once · 3. quantified lookaheads left to the JVM, moved to
group 3 (below) · 4. (retry) the `unicode &&` guards in `escape` kept: its KDoc stays true alone.
Review fit: pass (the main session checked all 951 probe rows: none that matched Dart before differs);
after the retry, pass
Review quality: `literal()` repeated the fold-or-write of the escape branch, fixed (one rework: one
`Escape` path; probe output byte-identical) · re-review: the `'p', 'P'` branch of `escapeEnd` (:832) and
its KDoc are dead now that `spelled` and `property` take every `\p`/`\P` first, blocked · retry (your
standing rule): branch and KDoc removed, core 165, sdk 128, lint clean, probe byte-identical · re-review:
pass

#### Found during group 2, added to group 3 (T5 Swift, T6 Kotlin)
Printed by Dart (`s15/oracle/ctl`, `ctl2`); both SDKs differ:
- `\v` is U+000B only in Dart (`\v` g "a\u000B\n" → "a#\n"); ICU and the JVM read it as every
  vertical space, in and out of classes (`[\v]`, `[^\v]`).
- `\s` and `\S`: Dart's set holds U+FEFF and not U+0085 (`\s` g "a\uFEFFb" → "a#b"; "\u0085" not
  matched); both engines the reverse.
- A quantifier on `[]` or a lookahead: Swift's ICU refuses `(?!)*` (`[]*` g "ab": Dart "#a#b#", Swift
  null); Android's java.util.regex is ICU too, so Kotlin writes them the quantifiable way as well.

#### Group 2 test run
Once after the group (logs `s15/g2-*.log`), before the two reworks (each implementer re-ran its suite
after, same counts; T4's probe output byte-identical):
- `cd engine && bun test` · 703 pass, 0 fail.
- `cd sdk && flutter test` · +241: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · 176 tests, 0 failures · iOS simulator · 54 + 176, TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` · BUILD SUCCESSFUL · core 165, sdk 128, 0 failures · lint clean.
- Probe: rows A1 57: Swift 0, Kotlin 0 differ (were 45, 45); a1: Swift 190 of 718 (was 317), Kotlin
  183 (was 345); under `g` and `gi` the rows left are row 23b.38's emoji rows and group 4's
  references (`\1(a)`, named groups).

### Group 3
Commits: T5 f1e7fbe, T6 be6c8ff (one per task, staged by path). Nothing pushed. Group 2's card approved
with your standing rule (start group 3, minor); group 3's first card the same (retry T6 once, then
group 4).

#### Task T5 · Swift: strict grammar under `u`
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: A2 (49 rows) → green (`swift test`: 182 tests, 0 failures; iOS 54 + 182; the 176 of before pass)
· red first: 4 of 5 new tests, 376 assertions (the guard of 40 still-valid rows passed before).
Changed: with `u`, `strict(inClass:)` at every escape gives nil where Dart refuses; a lone `{ } ]`, a
class range with a set at either end and a quantified lookahead nil; in both modes `\s`/`\S` are
ECMAScript's set, `\v` U+000B (`\x{B}`), `[]` `(?:(?!))`; doc comment updated. Tests: `// MARK: S15 —
strict u`, 6 tables, ~300 Dart-printed rows (`s15/oracle/t5`, 227 extra).
Decisions: 1. one strict check at the escape, not spread through the readers · 2. `\v` through
`character()` like `\0` · 3. with `u`, `\k<name>` passes only for a pre-pass name; group 4 extends it.
Review fit: pass
Review quality: `strict` re-read a decimal escape `character()` already read, fixed (one rework: one
`decimal()`, also one `groupName()` and `meaningful()`; a past-Int guard test; probe byte-identical)

#### Task T6 · Kotlin: strict grammar under `u`
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: A2 (49 rows) → green (`./gradlew build`: core 179, sdk 128, 0 failures, lint no issues; core
165 of before pass) · red first: 10 of 14 new tests; 12 rows (`\c`, `\x6`, `[\k]`, `{` …) were null only
because the JVM threw, and the rewriter now refuses them itself.
Changed: with `u`, `escape()` refuses every escape Dart refuses, plus a lone `{ } ]`, a class range
with a set at either end and a quantified lookahead; in both modes `\v` U+000B, `\s`/`\S` ECMAScript's
set (`SPACE`), `[]` `(?:(?!))`, a quantified lookahead `(?:(?=a))*` (Android's ICU); KDocs updated.
Tests: `// MARK: S15 — strict u`, 14 tests, written patterns pinned too (`s15/oracle/t6`, 202 extra).
Decisions: 1. the strict check in `escape()` · 2. a lookahead wrapped only when a quantifier follows ·
3. `\v` read in `spelled` as U+000B · 4. (rework) the general "escaped character stays" sentence kept ·
5. (retry) the `unicode &&` guards on `\u{` and `\p` kept: live branches, KDoc says "with [unicode]".
Review fit: `backreference`'s KDoc still said "Without `u`", fixed (one rework: three KDocs, comments
only); after the retry, pass
Review quality: `spelled` still listed `s`, `S`, dead once both callers take them, fixed (one rework:
`"fnrt"`; probe byte-identical) · re-review: `escapeEnd`'s `\c` arm (:864) computes an end no caller
reads now, blocked · retry (your standing rule): arm and `\cX` KDoc removed, every other `escapeEnd`
and `escape` branch traced live; core 179, sdk 128, lint clean, probe byte-identical · re-review: pass

#### Group 3 test run
Once after the group (logs `s15/g3-*.log`), before the reworks (each implementer re-ran its suite after:
Swift 182 with T5's guard test, Kotlin core 179, sdk 128; every probe output byte-identical):
- `cd engine && bun test` · 703 pass, 0 fail.
- `cd sdk && flutter test` · +241: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · 181 tests, 0 failures · iOS simulator · 54 + 181, TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` · BUILD SUCCESSFUL · core 179, sdk 128, 0 failures · lint clean.
- Probe: rows A2 49: Swift 0, Kotlin 0 differ (were 26, 23); ctl 0 of 28 both (was 14); ctl2 Kotlin 0,
  Swift 2 of 18 (the `\S` rows on "\u{FEFF}\u{85}": the probe's JSONSerialization drops the leading
  U+FEFF; the unit test, a Swift literal, gives Dart's value); a1: Swift 72 of 718 (was 190), Kotlin 83
  (was 183). Left: group 4 (named, unset, fwd, `\1(a)`, rows G3), group 5 (negiu, script, rows G4),
  row 23b.38 (emoji rows under quant, cls). No case that matched Dart before differs.

### Group 4
Commits: T7 023adc7; T8 036a741, then 3a5ecfd (the approved redraft). Nothing pushed. Group 3's card
approved with your standing rule (start group 4, minor); group 4's first card the same (all four
questions minor, defaults taken: retry T7, negative lookarounds in T7 and T8, known differences).

#### Task T7 · Swift: drop names, empty unset backreferences
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: G3 (48 planned rows) → green (`swift test`: 188 tests, 0 failures; iOS 54 + 188; the 182 of
before pass) · red first: 5 of 6 new tests, 196 assertions (the guard passed before).
Changed: `(?<name>` written `(`; `groupName()` decodes a name (`\u` escapes) and refuses a non-
identifier; a name twice refused unless in different alternatives; one `reference()` for `\N` and
`\k<name>` writes `(?:\1|\2)` with the groups it can see, `(?:)` for none, all of them in a lookbehind;
with a named group, `\k` without a group's name nil, in a class too. Tests: `// MARK: S15 — group
names, unset references`, 6 tests, written patterns pinned (`s15/oracle/t7`, 188 extra).
Decisions: 1. `\N` written `(?:\N)` like `\k<name>`, one helper · 2. needs you: a group in a negative
lookaround (`(?!(a))\1b`) copied, Dart's reference matches empty (question 2) · 3. a name spelled
with two `\u` surrogate escapes nil (Dart accepts it).
Review fit: the doc comment said every name Dart accepts works (decision 3 says not), fixed (one
rework: three sentences made true) · re-review: its example was the literal letter, which works, not
the escape text `\uD835\uDC9C` (tool input had turned the text into the letter), blocked ·
retry with the approved change (your standing rule): line 512 written as escape text (checked by
bytes); a group inside a negative lookaround unset after it (`unset`, filled at its `)`), 3 tests,
191 in all, probe changed only to Dart's values · re-review: pass
Review quality: pass

#### Task T8 · Kotlin: drop names, empty unset backreferences
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: G3 (48 planned rows) → green (`./gradlew build`: core 186, sdk 128, 0 failures, lint no issues;
core 179 of before pass) · red first: 5 of 7 new tests (names the JVM refused, and the guard, passed).
Changed: `(?<name>` written `(`; `\k<name>` `(?:\N)` or `(?:\1|\2)`; a reference that can only see
its group unset `(?:)`, copied in a lookbehind; the `Group` stack records the groups closed in the
current alternative; `captures` maps names to numbers; `backreference` returns (end, number); new
`groupName`, `identifier`; dead `'k'` arms of `escapeEnd` and the strict check, and `escape`'s
`names`, removed. Tests: 7 `g3_` tests, written patterns pinned (`s15/oracle/t8`, `t8b`, 264 extra).
Decisions: 1. escaped surrogate pairs in a name null, as Swift · 2. names checked with the JVM's
`isUnicodeIdentifierStart/Part` (minus ignorables, U+2E2F), not a Dart table · 3. a visible `\N`
copied as written.
Review fit: pass
Review quality: pass
Redraft (your standing rule, group 4 card): a reference from outside a negative lookaround to one of
its groups `(?:)` (`Group.negative`, a pattern-wide `unset` set; decision: not the closed sets, which
also drive the syntactic duplicate-name check); one test, 26 rows; this slice's 41 literal invisible
characters in TransformTest.kt strings written as `\u` escapes. Core 187, sdk 128, lint clean. Review
fit: pass · Review quality: pass. Commit 3a5ecfd.

#### Group 4 test run
Once after the group (logs `s15/g4-*.log`), before T7's rework (comments only; 188 after):
- `cd engine && bun test` · 703 pass, 0 fail.
- `cd sdk && flutter test` · +241: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · 188 tests, 0 failures · iOS simulator · 54 + 188, TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` · BUILD SUCCESSFUL · core 186, sdk 128, 0 failures · lint clean.
- Probe: rows G3 52: Swift 4, Kotlin 4 differ (were 29, 28), the four not planned; a1: Swift 43 of 718
  (was 72), Kotlin 55 (was 83); `named`, `fwd`, `dec` 0 in both. On the tasks' extra rows (452) both
  SDKs differ from Dart on the same rows: a group in a negative lookaround; a reference inside a
  lookbehind (ICU and the JVM refuse it: nil where Dart gives a value); escaped surrogate pairs in a
  name; run-time unset. No case that matched Dart before differs.
- After the T7 retry and T8 redraft (logs `s15/g4b-*.log`): engine 703, Flutter +241, analyze clean,
  Swift 191, iOS 54 + 191, Kotlin core 187, sdk 128, lint clean. a1 and rows unchanged (43 / 55, 20 /
  20); the negative-lookaround rows now match Dart; on the 566 extra rows (t7, t7c, t8, t8b, t8c)
  Swift and Kotlin give the same output on every row. Left in this group's area, both SDKs alike: a
  reference inside a lookbehind (ICU and the JVM refuse it), a name written as two surrogate escapes,
  run-time unset (not planned).

### Group 5
Commits: T9 47bf87a, T10 adf246f (one per task, staged by path, the new files included). Nothing
pushed. Group 4's card approved with your standing rule (start group 5, minor).

#### Task T9 · Swift: `iu` properties, exact script values
Files: `…/Resolver/Transforms.swift` · `…/Resolver/RegexPropertyNames.swift` · `…/Resolver/DartFoldClasses.swift` (new) · `…/TransformTests.swift`
Cases: G4 (36 rows) → green (`swift test`: 198 tests, 0 failures; iOS 54 + 198; the 191 of before
pass) · red first: 5 row tests on 63 of 159 Dart rows (96 already right, kept as guards).
Changed: `DartFoldClasses.swift`, Dart's 1 454 fold classes (2 938 letters, 564 above U+FFFF), one row
per line of the oracle file, parsed once; under `iu` a class or escape holding `\p`/`\P` written
`(?:(?!L)(?-i:C)|(?-i:[M]))` over every letter with a partner; script values only Dart's 336;
`spelled` writes `\x{H}` (ranges for runs). Tests: `// MARK: S15 — iu properties, script values`,
7 tests (`s15/oracle/t9`, 150 extra, Deseret, Osage, Adlam). With `u` the 217 table letters' sets
are their fold classes (173) or themselves (44), pinned.
Decisions: 1. both `dartFolded` paths through one reader, `Kept.matched` (`notFoldLetter`,
`foldLetterText` removed) · 2. `\x{H}` with ranges · 3. the 336 values pinned by a separate
Dart-printed list. Cost: the 690-pattern giu test 0.30 s → 0.75 s (2.5x; first version 2.10 s).
Review fit: pass
Review quality: pass (nits left: `tableKept`'s comment also covers `propertyKept`; DartFoldTable's
`u` column now duplicates the classes, a test pins they agree, trimming it is outside T9's files)

#### Task T10 · Kotlin: `iu` properties, scripts, JVM aliases
Files: `…/resolver/Transforms.kt` · `…/resolver/RegexPropertyNames.kt` · `…/resolver/DartFoldClasses.kt` (new) · `…/resolver/TransformTest.kt`
Cases: G4 (35 planned rows) → green (`./gradlew build`: core 197, sdk 128, 0 failures, lint no
issues; core 187 of before pass) · red first: a compile failure, then 8 of 10 new tests.
Changed: `DartFoldClasses.kt` keyed by code point; under `iu` a class holding `\p`/`\P` and a lone
`\p`/`\P` go through a new `dartClass` (S14's 217-letter path shares it), written `(?-i:[CK])` /
`(?-i:[^CK])`; script values only Dart's 336 under all four keys; the JVM gets Qaai as Inherited,
Qaac as Coptic. Tests: 10 tests, 151 Dart-printed rows (`s15/oracle/t10`).
Decisions: 1. `(?-i:[CK])`, K the letters of the classes meeting C, for the design's `(?!L)` form
(same output, K ⊆ L; drops L's 142 ranges) · 2. Zinh left as written (the JDK reads it) · 3. one pass
of C over all letters. Cost: bench of 690 giu patterns 10.2 → 32.5 ms (3.2x; first version 98.4 ms).
Review fit: pass
Review quality: pass

#### Group 5 test run
Once after the group (logs `s15/g5-*.log`):
- `cd engine && bun test` · 703 pass, 0 fail.
- `cd sdk && flutter test` · +241: All tests passed · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · 198 tests, 0 failures (cost test 0.741 s) · iOS · 54 + 198, SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` · BUILD SUCCESSFUL · core 197, sdk 128, 0 failures · lint clean.
- Probe: rows G4 36: Swift 0, Kotlin 1 differ (were 16, 16; Kotlin's is `\p{scx=Qaai}`, not planned);
  a1: Swift 15 of 718 (was 43), Kotlin 32 (was 55): negiu, script 0 in Swift; in Kotlin only
  `\P{Cased}` and `scx=` (desktop-JVM names, not planned). Every earlier extra-case set (ctl … t8c)
  as before in both; on t9 Kotlin differs only on JVM-only names (Cased, Changes_When_*, scx).
  Left in all: row 23b.38's emoji rows, run-time unset. No case that matched Dart before differs.
- F11's "282 above U+FFFF" counts classes; the code points above U+FFFF are 564.

### Group 6
Commit: T11 f4381a3 (staged by path). Nothing pushed. Group 5's card approved with your standing
rule (start group 6, minor).

#### Task T11 · Fixtures 35-36, counts pinned at 36
Files: `schema/fixtures/render/35_regex_annex_b_strict_unicode.json` (new) · `schema/fixtures/render/36_regex_group_names_script_values.json` (new) · `…/ModelRoundTripTests.swift` · `…/models/ModelRoundTripTest.kt` · `…/FixturePathsTest.kt`
Cases: X1 → green on all four · red first: with the fixtures in and the pins at 34, Swift failed only
ModelRoundTripTests:10 and Kotlin only FixturePathsTest and allRenderFixturesRoundTrip (36 vs 34);
the engine and every resolved-value runner (Flutter, Swift, Kotlin) already passed 35 and 36.
Changed: fixture 35, 18 rows: Annex B without `u` (9), the strict-`u` nulls (4), 2 kept with `u`,
`a++` null in both modes, `\s+` over ECMAScript's white space, `[]*`. Fixture 36, 18 rows: 3 names
Dart accepts, 2 it refuses, 3 unset references matching empty, 4 refused script values, 6 kept.
The pins move 34 → 36 at five seams, "01-36" in the messages.
Decisions: 1. 18 rows each (23.1 KB, 23.3 KB; 33-34 are 16-18 KB): one row per kind, repeats
dropped; keep vs trim to ~15 (card question 1) · 2. a script writes both files (`expected` from the
engine's encodeJsonTree via bun, json.dumps ASCII); it rebuilds 33-34 byte for byte · 3. 19 repeat
candidates stay TransformTests rows only; none was left out because a runner could not express it.
Review fit: pass
Review quality: fixture 36's description called script values "Unicode's long names or four-letter
codes" yet listed Hrkt as null, fixed (now ECMAScript's table, less Hrkt, plus Qaai and Qaac; the
rows, `expected` and `resolved` unchanged)

#### Group 6 test run
Once after the group (logs `s15/g6-*.log`), then again by the rework, the same counts:
- `cd engine && bun test` · 705 pass, 0 fail (703 + the two fixtures).
- `cd sdk && flutter test` · +243: All tests passed (35, 36 run in render_resolved_test.dart) ·
  `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · 198 tests, 0 failures · iOS · 54 + 198, TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` · BUILD SUCCESSFUL · core 197, sdk 128, 0 failures · lint clean.
- Stage: 11 of 11 tasks green over 6 groups, 0 blocked, 0 skipped; every 07 case green.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- Row 23b.37's known differences (epic plan) gain (approved at group 4's card): a backreference inside
  a lookbehind (ICU and the JVM refuse it) and a group name spelled with two `\u` surrogate escapes.
- Tool input in this session turns backslash-u-hex text into the character: S14's TransformTest.kt
  still has U+00A0 ×2, U+2003 ×2, U+0301 ×3 written literally (left: baseline lines).
- Follow-ups, outside this row: `DartFoldTable`'s `u` column duplicates `DartFoldClasses` (a test pins
  they agree); Swift's `tableKept` comment also covers `propertyKept`; the S14 test name
  `p1_guard_scriptKeysLeaveTheValueToTheEngine` no longer says what it checks.
