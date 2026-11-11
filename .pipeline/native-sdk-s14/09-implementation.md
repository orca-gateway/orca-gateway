# 09 · Implementation · native-sdk-s14

## Front page

### In one breath
group 1 of 5 · tasks: 2 green, 0 blocked · cases: 2 of 6 green (M1, M2) · every suite green
T1 Swift: modifier groups keep their own `i`; every `(?` form Dart refuses gives null.
T2 Kotlin: the same; the JVM no longer folds ı and İ into `(?i:i)`; the fast path skips no group.
Each fit review found one missing guard row, `(?i-:a)`, fixed by one rework; quality passed.
Tests: Swift 153 (+6), iOS 54 + 153, Kotlin core 134 (+4), sdk 128, engine 701, Flutter 239.
Probe: modifier-group differences 76 → 16 (Swift), 80 → 4 (Kotlin); the rest are group 2's.

### New for you
nothing new

### Trade-offs
2 fixed: the `(?i-:a)` guard row missing in both SDKs (one rework each, test rows only).
5 auto-decided: plain `(?:` parsed as a modifier; sets per step; `(?i-:` valid; fast path; null.

### Questions for you
1. Next: group 2, Dart's 217-letter fold table (T3 Swift ∥ T4 Kotlin)? (default: go)

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

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing yet (groups 2-5 to come)
