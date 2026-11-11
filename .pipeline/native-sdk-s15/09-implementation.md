# 09 · Implementation · native-sdk-s15

## Front page

### In one breath
group 4 of 6 · tasks: 2 green, 0 blocked · cases: 8 of 11 green (A3, A1, A2, G3) · suites green
T7 Swift: names dropped, `\k<name>` its numbers, unset refs empty (negative lookarounds too).
T8 Kotlin: the same, in a redraft on top; this slice's invisible test characters now escapes.
Tests: engine 703, Flutter 241, Swift 191, iOS 54 + 191, Kotlin core 187, sdk 128, lint clean.
G3: only the 4 run-time rows differ; on 566 extra rows Swift and Kotlin agree on every row.

### New for you
nothing new

### Trade-offs
5 auto-decided: `\N` wrapped or copied; escaped surrogate names nil; identifiers; `unset` set; …
1 you decided (standing rule): negative-lookaround references empty, as in Dart.

### Questions for you
1. Next: group 5, `iu` properties and exact script values (T9 Swift, T10 Kotlin)? (default: go)

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

### Blocked
none (T7 green after one retry)

### Not done
none

### For ship (stage 10) to know
- Row 23b.37's known differences (epic plan) gain (approved at group 4's card): a backreference inside
  a lookbehind (ICU and the JVM refuse it) and a group name spelled with two `\u` surrogate escapes.
- Tool input in this session turns backslash-u-hex text into the character: S14's TransformTest.kt
  still has U+00A0 ×2, U+2003 ×2, U+0301 ×3 written literally (left: baseline lines).
