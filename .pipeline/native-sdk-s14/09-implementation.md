# 09 · Implementation · native-sdk-s14

## Front page

### In one breath
group 4 of 5 · tasks: 2 green, 0 blocked · cases: 5 of 6 green (M1-P1) · every suite green
T7 Swift: with `u`, `\p{…}` names Dart refuses (`IsLatin`, `Han`, `script=latin`) give null.
T8 Kotlin: the same, and the JVM now reads Dart's long names (`Lowercase_Letter`, `Alphabetic`).
Reviews passed first time; Kotlin also green on JDK 17 and 21, the two CI runs.
Tests: Swift 168 (+5), iOS 54 + 168, Kotlin core 151 (+5), sdk 128, engine 701, Flutter 239.
Probe: property rows 76 · 123 → 60 · 73; every `u` row left is row 23b.37's.

### New for you
nothing new

### Trade-offs
5 auto-decided: script values to the engine; `javaMirrored`; runtime flag once; two smaller.
Gap, to row 23b.37: the JVM has no exact form for 62 binary names and Script_Extensions (null).

### Questions for you
1. Next: group 5, fixtures 33-34 on all four runners (T9)? (default: go)

## Appendix

### Group 1
Commits: T1 282f32e, T2 bbaae14. Nothing pushed. Gate 08 answered "A, leave them" (every default;
backreferences under `i` left for row 23b.37).

#### Task T1 · Swift modifier scope and `(?` rejects
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: M1, M2 → green (`swift test`: 153 tests, 0 failures; baseline 147 all pass) · red first: 79
failing assertions (19 M1 rows, the 15 refused forms under g and 12 under gi, the `matches` guard).
Changed: `asciiClasses` returns `String?` (`compile` gives nil); a stack holds each open group's `i`
(`(` pushes the enclosing value, a modifier group its own, an unescaped `)` outside a class pops,
never an empty stack); the ten letters, classes and `\w \W \b \B` (ſ and K with `u`) follow it;
`modifiers(_:)` follows Dart's grammar, nil for any other `(?` form. Doc comment states both rules.
Tests: `assertRegex` takes `expected: String?`; six tests under `// MARK: S14 — modifier scope and
(? forms (row 23b.36)`, every expected value printed by Dart (the guards checked by the main session).
Decisions: 1. plain `(?:` goes through `modifiers()` (no flags, inherits `i`) · 2. word sets and
edges built from the active `i` at each step (patterns ≤ 200 units) · 3. `(?i-:a)` valid, as Dart.
Review fit: the `(?i-:a)` guard row had no test, fixed (one rework: one assertion, 153 unchanged)
Review quality: pass

#### Task T2 · Kotlin modifier scope and `(?` rejects
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: M1, M2 → green (`./gradlew build`: core 134, sdk 128, 0 failures, lint no issues) · red
first: 3 of 4 new tests (m1 scope 15 of 16 rows, nested 5 of 10, m2 rejects 16 of 30; Java already
refused `(?#`, `(?P<`, `(?'`, `(?^:`); the `matches` assertion follows the rows, so its red was unseen.
Changed: the same stack and grammar (`groupOpening` replaces `isModifiers`); `asciiClasses` returns
`String?`, `compile` null when refused; the fast path now needs no `\`, `[` or `(`; KDoc states the
rules, the old "rewritten by the pattern's flags" sentence is gone; rows :513-514 comments only.
Tests: four under `// MARK: S14 — modifier scope and (? forms (row 23b.36)`; the 18 guard rows
(g and gi) checked against Dart by the main session.
Decisions: 1. fast path kept, narrowed · 2. null for a refused form, not a pattern that fails to
compile · 3. `(?i-:` valid, as Dart.
Review fit: the `(?i-:a)` guard rows had no test, fixed (one rework: two rows, 134 unchanged)
Review quality: pass

#### Group 1 test run
Once after the group (logs in the session scratchpad, `s14/g1-*.log`), before the two one-line
reworks (test rows only; each implementer re-ran its suite after: Swift 153, Kotlin 134 + 128):
- `cd engine && bun test` · 701 pass, 0 fail.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · Executed 153 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, OrcaGatewayCoreTests 153, TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` (tests rerun) · core 134, sdk 128, 0 failures · lint "No issues
  found".
- Probe (`s14/oracle/reprobe.sh`, `s14/g1-probe.txt`): `(?` forms 6 → 0 in both; modifier groups
  76 → 16 (Swift), 80 → 4 (Kotlin): every one left is ß or `ff` inside `(?i:` (group 2's table);
  syntax 81 → 59, all Annex B (row 23b.37) or `\u{61}` (group 3).
Every changed file sits in T1's or T2's Files; the untracked `sdk-kotlin/core/bin/` predates S14.

### Group 2
Commits: T4 d056388, T3 57b82e4. Nothing pushed. Group 1's card was answered under your standing rule
(its only question, "go on to group 2", was minor).

#### Task T3 · Swift: Dart's 217-letter fold table
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/DartFoldTable.swift` (new) · `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: F1 → green (`swift test`: 159 tests, 0 failures, no warnings; the 153 of group 1 still pass) ·
red first: 4 of 6 new tests (45 failures); with the table wired and escapes unchanged, the hex guard
went red on 6 rows (`\x0a` `\x7F` `\xff` `\x4a` `\xAF` `￿`): planner finding F1 was real.
Changed: `Regex.foldTable`, the 217 rows as one literal parsed once (`letter: set`, `/ set with u`
on the 78 rows where they differ; checked equal to Dart's fold-table.tsv). `foldLetters` = its keys,
`dartFold` a lookup; the lookahead and the 217-letter string are built once; `dartFolded` runs a
class over the 217 letters in one `matches` call, a leading `^` of the body escaped (first scalar);
`\xHH` and `\uHHHH` copied whole. The `asciiClasses` doc describes the table.
Tests: `// MARK: S14 — Dart's fold table (row 23b.36)`, 6 `testF1_…` tests, one a loop over every
key (`c` and `[c]`, gi and giu; 868 runs, 0.22 s); the `[^^a]` and `[^^\u{301}…]` rows are Dart's.
Decisions: 1. escape a leading `^` (`[^^a]`) · 2. `\u{…}` left to T5 (ICU refuses it either way) ·
3. compact rows.
Review fit: pass
Review quality: `hasPrefix("^")` compared Characters, so `[^^\u{301}a]` under `i` lost its members,
fixed (one rework: the first scalar, 5 Dart rows; 159 unchanged)

#### Task T4 · Kotlin: Dart's 217-letter fold table
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/DartFoldTable.kt` (new) · `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: F1 → green (`./gradlew build`: core 141, sdk 128, 0 failures, lint no issues) · red first:
3 of 30 TransformTest tests (154 rows of the loop, Å Ω ϴ ẞ ᾀ å, ß and ﬅ under giu); with the table
wired and `escapeEnd` unchanged, the escape guard went red on 11 rows (F1 again).
Changed: `DartFoldTable`, an internal object, the 217 rows as one hex row per letter, as Dart printed
them, parsed once (`letters`, `set(c, unicode)`). `FOLD_LETTERS` and `dartFold` are gone;
`characterClass` tests each letter once (one reused Matcher), a leading `^` of the body escaped;
`escapeEnd` reads `\xHH` and `\uHHHH` whole. KDoc on `RegexSupport` and `asciiClasses` updated.
Tests: the same MARK, 7 `f1_…` tests, one a loop over every letter (alone and in a class, gi, giu).
Decisions: 1. one hex row per letter · 2. `\u{…}` left to T6 (the JVM refuses it either way) ·
3. `\x`/`\u` without exactly 2 or 4 hex digits read as before (Annex B, row 23b.37).
Review fit: `[^^a]` under `i` lost f and F (the main session's check of the group: `[^a]` was
compiled for the members), fixed (one rework: the leading `^` escaped, 7 Dart rows; core 140 → 141)
Review quality: pass

#### Group 2 test run
Once after the group (logs `s14/g2-*.log`), before T3's one-line rework (Swift re-run after: 159):
- `cd engine && bun test` · 701 pass, 0 fail.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · Executed 159 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, OrcaGatewayCoreTests 159, TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` (tests rerun) · core 141, sdk 128, 0 failures · lint "No issues
  found".
- Probe (`s14/g2-probe.txt`), group 1 → group 2, Swift · Kotlin: modifier groups 16 · 4 → 0 · 0;
  single letters 65 · 65 → 0 · 0; classes 65 · 65 → 0 · 0; full foldings 150 · 12 → 0 · 0; escapes
  17 · 17 → 16 · 16 (group 3). The `^` checks (`s14/oracle/caret*/`, 13 rows): both match Dart.
- Group 3's start (`s14/oracle/e1/`, Dart's 37 escape rows): Swift 26 differ, Kotlin 23.
Every changed file sits in T3's or T4's Files; the untracked `sdk-kotlin/core/bin/` predates S14.

### Group 3
Commits: T5 079e08a, T6 44d6a2c. Nothing pushed. Group 2's card was answered under your standing rule
(its only question, "go on to group 3", was minor).

#### Task T5 · Swift escaped letters, `\u{…}` with `u`
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: E1 (Swift), Dart's 37 rows → green (`swift test`: 163 tests, 0 failures, no warnings; the 159
of group 2 still pass) · red first: 27 rows; the 10 right before stayed green.
Changed: `hexEscape()` reads `\xHH`, `\uHHHH` and, with `u`, `\u{H…}`; `braced()` writes ICU's
`\x{H}` without leading zeros (ICU takes six digits at most). Under `i` an escape that spells a table
letter is that letter's set; with `u` `\u{…}` is `\x{…}` in and out of a class, and one Dart refuses
gives nil (`classSet` returns an optional). The doc comment: only backreferences keep ICU's folding.
Tests: `// MARK: S14 — escaped letters and \u{…} (row 23b.36)`, 4 `testE1_…` tests (the 37 rows).
Decisions: 1. every malformed `\u{` under `u` is nil · 2. short `\x`/`\u`, and `\u{…}` without
`u`, take the old path (Annex B) · 3. a surrogate value goes to ICU as `\x{D800}`.
Review fit: pass
Review quality: pass

#### Task T6 · Kotlin escaped letters, `\u{…}` with `u`
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: E1 (Kotlin) → green (`./gradlew build`: core 146, sdk 128, 0 failures, lint no issues) · red
first: 4 of 5 new tests; the one of `\u{110000}`, `\u{}`, `\u{g}` (null) passed before.
Changed: one `escape()` helper (an `Escape` class) reads `\xHH`, `\uHHHH` and, with `u`, `\u{H…}`
for the outside branch and `characterClass` both; the rest as T5 (`\x{H}` without leading zeros, null
for a form Dart refuses); `characterClass` takes `fold` and `unicode` apart and returns `Int?`; KDoc.
Tests: the same MARK, 5 `e1_…` tests: the 37 rows and 19 guard rows the implementer printed with Dart
(`\xe9`, `\u{e9}`, ranges, `\u{0}`, `\u{0010FFFF}`, unclosed `\u{73`, a trailing `a\`, …).
Decisions: 1. the 19 guard rows · 2. one helper, so T8 hooks `\p{` in one place · 3. without `u`,
the old `escapeEnd` path.
Review fit: pass
Review quality: pass

#### Group 3 test run
Once after the group (logs `s14/g3-*.log`):
- `cd engine && bun test` · 701 pass, 0 fail.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · Executed 163 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, OrcaGatewayCoreTests 163, TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` (tests rerun, JDK 25) · core 146, sdk 128, 0 failures · lint "No
  issues found".
- `./gradlew :core:test --rerun` on JDK 17 and on JDK 21 (CI's two): core 146, 0 failures, each
  (`s14/g3-kotlin-jdk17.log`, `-jdk21.log`); groups 1-2 had run on JDK 25 only.
- Probe (`s14/g3-probe.txt`), group 2 → group 3, Swift · Kotlin: escapes 16 · 16 → 4 · 4 (the four
  `\u{…}` rows without `u`, Annex B); syntax 59 · 59 → 58 · 58; every other corner unchanged, none
  worse. Dart's 37 E1 rows (`s14/oracle/e1/`): 0 · 0 differ (26 · 23 before).
- 38 more braced corners (`s14/oracle/e1b/`: ranges, quantifiers, `[^\u{17F}]`, `\u{5D}`, unclosed
  forms …): 36 match Dart in both. The two left, `\x{73}` under g and gu, the engines read as a braced
  escape (Dart refuses it with `u`, and without reads `x{73}`): so before S14, now named in row 23b.37.
Every changed file sits in T5's or T6's Files; the untracked `sdk-kotlin/core/bin/` predates S14.

### Group 4
Commits: T7 5315c4f, T8 790d4df. Nothing pushed. Group 3's card was answered under your standing rule
(its only question, "go on to group 4", was minor).

#### Task T7 · Swift rejects non-ECMAScript property names
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/RegexPropertyNames.swift` (new) · `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: P1 (Swift: the rejects) → green (`swift test`: 168 tests, 0 failures, no new warnings; the 163
of group 3 still pass) · red first: 2 of 5 new tests; the 3 guards passed before.
Changed: `Regex.dartAcceptsProperty(_:)` and two Sets built once (80 General_Category values, bare or
after `General_Category=`/`gc=`; 96 binary properties; `Script=`/`sc=`/`Script_Extensions=`/`scx=`
with a value, left to ICU). With `u`, `\p{…}`/`\P{…}` is nil when Dart refuses the name, outside a
class and inside one (`propertyEscape()`); without `u` nothing changes. Doc comments updated.
Tests: `// MARK: S14 — property names (row 23b.36)`, 5 `testP1_…` tests: refused names (the 7 binary
names Dart refuses too), in classes and groups, a no-`u` guard, a loop over all 690 accepted forms.
Decisions: 1. script values go to ICU once non-empty (F9) · 2. a `\p{` with no `}` is nil from the
rewrite · 3. the test holds its own copy of Dart's 176 names.
Review fit: pass
Review quality: pass

#### Task T8 · Kotlin property names: rejects, JVM spellings
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/RegexPropertyNames.kt` (new) · `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt`
Cases: P1 (Kotlin) → green (`./gradlew build`: core 151, sdk 128, 0 failures, lint no issues;
`:core:test` 151 on JDK 17, 21 and 25) · red first: the 4 new p1 tests and the new `r2` row.
Changed: `RegexPropertyNames`, built once: the same names, `accepts(name)` and `jvm(name, negated)`:
a category to its short name, a binary to `IsX`, `javaMirrored` or an exact class (Hex_Digit as
ranges, Any, Assigned as `[\P{Cn}]`). With `u`, T6's `escape()` hands `\p` to `property()`: null
without `{…}`, for a name Dart refuses, or with no exact JVM spelling; Android keeps names as written.
UNICODE_CHARACTER_CLASS is learned once (`unicodeClasses`), and `compileIcuLike` reads the flag.
Tests: the same MARK, 4 `p1_…` tests and a guard; Emoji rows expect Dart's value where the runtime
has `\p{IsEmoji}` (not JDK 17), else null; F10's note at :521-522 is now a row (added, not changed).
Decisions: 1. Bidi_Mirrored as `\p{javaMirrored}` (checked on every code point) · 2. `Script=X` as
written (the JVM lowercases the key) · 3. the runtime flag once.
Not on the JVM (row 23b.37): 130 of the 690 forms Dart accepts stay null (62 binary names with their
aliases, and Script_Extensions); 152 on JDK 17 (the six Emoji properties too).
Review fit: pass
Review quality: pass

#### Group 4 test run
Once after the group (logs `s14/g4-*.log`):
- `cd engine && bun test` · 701 pass, 0 fail.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · Executed 168 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, OrcaGatewayCoreTests 168, TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` (tests rerun, JDK 25) · core 151, sdk 128, 0 failures · lint "No
  issues found". `:core:test --rerun` on JDK 17 and on JDK 21: 151, 0 failures, each.
- Probe (`s14/g4-probe.txt`), group 3 → group 4, Swift · Kotlin: property rows 76 · 123 → 60 · 73;
  syntax 58 · 58 → 58 · 57 (`\pL`); every other corner unchanged, none worse. The 690 accepted forms
  (`s14/oracle/pnames/`): Swift 0 differ, Kotlin 130 null (above), every other one as Dart. Every `u`
  property row left is row 23b.37's: `\P{Ll}` giu (both), the JVM's `\p{Lt}` and `\p{ASCII}` giu,
  Script_Extensions, ID_Start, CWCF, Cased, Dash, Math, `[\p{L}-z]`, `Script=latin`, `Script=Qaai`.
  The rows without `u` are Annex B (`\p` is the letter p).
Every changed file sits in T7's or T8's Files; the untracked `sdk-kotlin/core/bin/` predates S14.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing yet (group 5 to come)
