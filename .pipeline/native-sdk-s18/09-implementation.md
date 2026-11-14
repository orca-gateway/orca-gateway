# 09 · Implementation · native-sdk-s18

## Front page

### In one breath
group 1 of 3 · tasks: 1 green, 0 blocked · cases: 1 of 4 green · Swift 228, 4 runners green
T1: with `u`, an escaped pair in a class is one member, its code point, so a range compares them.
`[`pair(𐐀)`-`pair(𐐧)`]` giu on 𐐨 gives "#" as in Dart; Swift refused it before.
Probe: every class-range row now gives Dart's value on macOS, Linux 6.2 and 5.10.
Left for group 2: lone halves that ICU joins into a letter (T2); then fixture 39 (T3).

### New for you
nothing new

### Trade-offs
2 auto-decided: a pair member written braced; one guard row left out (S16's U+FFFD).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 2, T2 (lone halves match nothing with `u`)? (default: go)

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

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing yet
