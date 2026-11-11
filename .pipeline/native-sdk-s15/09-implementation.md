# 09 · Implementation · native-sdk-s15

## Front page

### In one breath
group 2 of 6 · tasks: 2 green, 0 blocked · cases: 4 of 11 green (A3, A1) · suites green
T3 Swift Annex B: `\A` is "A", `\p{L}` is "p{L}", `{` literal, octal, `[]`, `[^]`; 57 A1 rows green.
T4 Kotlin Annex B: the same 57 rows green; its retry removed a dead `\p` branch (probe unchanged).
Tests: engine 703, Flutter 241, Swift 176, iOS 54 + 176, Kotlin core 165, sdk 128, lint clean.
Found: `\v`, `\s` (U+FEFF, U+0085) and `[]*` differ in both SDKs; added to group 3.

### New for you
nothing new

### Trade-offs
4 auto-decided: class punctuation escaped; `\c` as code points; corners to group 3; guards kept.

### Questions for you
1. Next: group 3, strict `u` plus `\v`, `\s`, `[]*` (T5 Swift, T6 Kotlin)? (default: go)

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

### Blocked
none (T4 green after one retry)

### Not done
none

### For ship (stage 10) to know
nothing
