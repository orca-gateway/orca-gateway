# 09 · Implementation · native-sdk-s15

## Front page

### In one breath
group 1 of 6 · tasks: 2 green, 0 blocked · cases: 2 of 11 green (A3 Swift, Kotlin) · suites green
T1 Swift quantifiers: `a++`, `^*`, `\b*`, `(?<=a)*` give nil; each open group knows its kind.
T2 Kotlin quantifiers: the same rules; the fast path that skipped `a++` and `{3}` is gone.
Tests: engine 703, Flutter 241, Swift 171, iOS 54 + 171, Kotlin core 156, sdk 128, lint clean.
Probe: all 39 A3 rows give Dart's value in both SDKs; quantified lookaheads wait for groups 2-3.

### New for you
nothing new

### Trade-offs
4 auto-decided: lookahead `)` an atom for now; offsets kept; fast path removed; `{2,1}` to engine.

### Questions for you
1. Next: group 2, Annex B without `u` (T3 Swift, T4 Kotlin)? (default: go; `A` starts it)

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

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing
