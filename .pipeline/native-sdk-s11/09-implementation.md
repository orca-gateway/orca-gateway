# 09 · Implementation · native-sdk-s11

## Front page

### In one breath
group 1 of 2 · tasks: 4 green, 0 blocked · cases: 5 of 10 green · P1-P5 on engine, Flutter only
T1 fixtures 25-27: contains "" is true, UTF-16 compares, empty regex; green on engine, Flutter.
T2 fixtures 28-30: ASCII `\d` `\w`, 4.0 stays "4.0", "ΟΔΟΣ" → "οδοσ"; 30 green on all 4.
T3 Swift flex: spaceAround's half ends, a gap spaced like a child, Column baseline as start.
T4 Kotlin Image: a 404, empty or non-http src draws "!" centred in its box; golden re-recorded.
Tests: engine 697 + 1 fail (port 8080, as baseline), Flutter 235, iOS UI 54, Kotlin sdk 128.
Red by design until group 2: Swift and Kotlin resolvers on fixtures 25-29 (15 sub-cases).
Commits: c9cab82, 4b2dfdb, 882fce6, 8b219b5 on feat/native-sdk-s11. Nothing pushed.

### New for you
nothing new

### Trade-offs
1 needs you: Kotlin's "!" is its own screen-reader node; Flutter merges it into the alt label.
3 auto-decided: a gap of 0 is boxed, as Flutter; Swift keeps its spacer stack; fixture shape.

### Questions for you
1. Next: group 2, T5 Swift resolver and T6 Kotlin resolver, turning fixtures 25-29 green.
   (default: go; `A` starts it)
2. Kotlin's "!" after a failed load: keep it a separate accessibility node, or merge it into the
   Image's label as Flutter does? (default: keep it, note it for later)

## Appendix

### Group 1
Commits, one per task, in the order they passed review: T1 c9cab82, T4 4b2dfdb, T2 882fce6,
T3 8b219b5. Nothing pushed.

#### Task T1 · Fixtures 25-27: contains, UTF-16, empty regex
Files: `schema/fixtures/render/25_contains_empty_needle.json`, `26_utf16_code_units.json`,
`27_regex_empty_pattern.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift`
Cases: P1, P2, P3 → green on engine and Flutter (235 = 229 + 6) · red first: the Swift count (30 vs 24).
Sub-cases (Dart / Swift today): 25 transform true / false · 25 op "yes" / "no" · 26 eq, contains,
startsWith "no" / "yes" · 26 split ["e","́"] / ["é"] · 27 global "-a-b-" / null · 27 first "-ab" / null.
Changed: each fixture a Column of keyed Texts, every input in page state, `expected` the engine's
own output; Swift's render-fixture count 30 ("01-30").
Decisions: 1. non-global "-ab" added, checked on the Dart VM · 2. precomposed "é" in state, the
decomposed form a static needle · 3. split pinned as the list itself.
Review fit: pass
Review quality: pass

#### Task T2 · Fixtures 28-30: ASCII classes, double, lowercase
Files: `schema/fixtures/render/28_regex_ascii_classes.json`, `29_state_double_to_string.json`,
`30_lowercase_per_code_point.json` (new) · Kotlin `ModelRoundTripTest.kt`, `FixturePathsTest.kt`
Cases: P4, P5 → green on engine and Flutter; P6 → green on all four · red first: Kotlin counts 30 vs 24.
Values, flags g, replacement "[{{value}}]" (Dart / Swift and Kotlin today): `\d+` on "٣ 4" "٣ [4]" /
"[٣] [4]" · `\D+` "[٣ ]4" / "٣[ ]4" · `\w+` on "café_1" "[caf]é[_1]" / "[café_1]" · `\W+` "caf[é]_1"
/ "café_1" · `[\w]+` as `\w+` · `matches ^\d+$` on "٣٤٥" "not digits" / "digits" · 4.0 "4.0" / "4"
· 4 "4" / "4" · "ΟΔΟΣ" "οδοσ" on all four.
Decisions: 1. replace mode with brackets so each match shows · 2. non-ASCII as `\u` escapes, 4.0
literal in pageState only · 3. one sub-case each for the in-class form and P6.
Review fit: pass
Review quality: pass

#### Task T3 · Swift flex: spaceAround, gap, baseline
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Layout.swift` · `sdk-swift/Tests/OrcaGatewayTests/FlexLayoutTests.swift`
(new) · `Flex.swift` listed, unchanged (not needed)
Cases: L1, L2, L3 → green (iOS UI 54 = 50 + 4; the five goldens untouched) · red first: all four.
Measured before → after: L1 Row spaceAround [60,140,220] → [40,140,240] · L2 spaceEvenly gap 10
[60,150,240] → [40,150,260], Column spaceAround gap 10 → [24,150,276] · L3 Column baseline x 20 → 0.
Changed: spaceAround gets two spacers between items; under spaceAround and spaceEvenly a set gap
is an item with spacers, as `_addGaps`; a Column's baseline is `.leading`; doc comment fixed.
Decisions: 1. the spacer stack kept, not FlexLayout (same output, goldens untouched) · 2. a gap of 0
is boxed too: Flutter's `_addGaps` and Kotlin's Flex run for any set gap; the engine sends gap only
when a page sets it (my brief said "> 0"; the case says "as the Flutter SDK", so the oracle wins).
Review fit: pass
Review quality: pass

#### Task T4 · Kotlin failed Image draws "!"
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Image.kt` · `ImageTest.kt` ·
`sdk-kotlin/sdk/src/test/resources/goldens/native-widgets-home.png`
Cases: I1 → green (sdk 128 = 127 + 1, lint 0) · red first: no "!" node under the failed Image.
Changed: a `failed` state when the load returns null; a 404, an empty or a non-http src draws
`Text("!")` centred in a box of the Image's width and height; loading stays an empty box. The old
empty-box test is split: loading (unchanged checks) and failed (a "!" centred within 1 dp, sizes kept).
Golden re-recorded: a small "!" in each card's photo box (it was under the 0.01% tolerance anyway).
Decisions: 1. a missing side fills the bounded space, as Flutter's Center · 2. "!" in Kotlin's Text
defaults · 3. needs you: "!" a separate accessibility node; Flutter merges it into the alt label.
Review fit: pass
Review quality: pass

### Test run
Once, after the group, on the tree with all four tasks (logs in the session scratchpad, `s11/g1-*.log`):
- `cd engine && bun test` · 697 pass, 1 fail · `test/server.test.ts` (unnamed): EADDRINUSE on 8080,
  your Docker; the baseline's environmental failure.
- `cd sdk && flutter test` · +235: All tests passed!
- `cd sdk-swift && swift test` · 111 tests, 15 failures, all `ResolverFixtureTests.testResolvedMapsMatch`
  on 25 (transform, op), 26 (eq, contains, startsWith, split), 27 (global, first), 28 (d, nd, w, nw,
  cls, m), 29 (dbl). By design until group 2.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54 tests, 0 failures; OrcaGatewayCoreTests 111
  with the same 15. ** TEST FAILED ** only for those.
- `cd sdk-kotlin && ./gradlew build --continue` · core 113, 1 failure: ResolverFixtureTest stops at its
  first, `25_contains_empty_needle.json transform.data` actual false, expected true (by design) · sdk
  testDebugUnitTest 128, 0 failures, 0 skipped · lint "No issues found".
Every changed file sits in a task's Files; no stray file.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Nothing deploys and nothing is published. Between the groups the branch is red on Swift and
Kotlin by design, so nothing is pushed before group 2. On the PR: Engine (conformance), SDK
(Flutter), Schema, SDK Swift and SDK Swift UI, and SDK Kotlin should all run (the PR touches
`schema/fixtures/render/`, both SDKs).
