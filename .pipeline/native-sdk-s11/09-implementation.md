# 09 · Implementation · native-sdk-s11

## Front page

### In one breath
group 2 of 2 · tasks: 6 of 6 green, 0 blocked · cases: 10 of 10 green · all suites green
T5 Swift resolver: Dart's contains "", UTF-16 compares, empty regex, ASCII classes, 4.0 as "4.0".
T6 Kotlin resolver: the same five, with split("") per UTF-16 unit exactly as Dart.
Fixtures 25-30 now pass on all four runners: engine, Flutter, Swift, Kotlin.
Tests: engine 697 + 1 fail (port 8080, as baseline), Flutter 235, Swift 116, iOS UI 54,
Kotlin core 118, sdk 128, lint 0. Linux Swift runs in the PR's CI (not here).
Commits: f30a150 (T5), 847e7ec (T6), after group 1's four. Nothing pushed.

### New for you
nothing new

### Trade-offs
3 auto-decided: Swift reads JSON numbers by their text (your "resolver only" call); nested
regex sets; Kotlin keeps Swift's rules outside P1-P5.

### Questions for you
1. Last group: `A` approves stage 09; stage 10 pushes feat/native-sdk-s11, opens the PR
   (Auto-fix off) and reads its CI once. (default: yes)
2. Left for later, both SDKs: `\b` word edges and the `i` flag's ſ/K still differ from Dart;
   plus Kotlin's "!" label. Add them as a follow-up row in the epic plan? (default: yes)

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

#### Group 1 test run
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

### Group 2
Commits, one per task, in the order they passed review: T6 847e7ec, T5 f30a150. Nothing pushed.
At group 2's start you answered group 1's card with "A": the Kotlin "!" stays its own
accessibility node, noted for later (question 2's default).

#### Task T5 · Swift resolver: Dart's corners
Files: `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValue.swift` · `Resolver/Transforms.swift` ·
`Resolver/ValueResolver.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift`
Cases: P1-P5 (Swift) → green (`swift test` 116 = 111 + 5, ResolverFixtureTests over all 30, PropertyTests
green; iOS core 116) · red first: each new test, and fixtures 25-29's 15 sub-cases.
Changed: `JSONValue.decode(Data)` runs a small pure-Swift parser that reads each number's text (4.0
`.double`, 4 `.int`; Codable models still go through JSONDecoder); string `==` by code units ·
`DartString` (contains, hasPrefix, split by UTF-16 units; `split("")` keeps a pair whole) · `Regex.compile`
accepts "" as `(?:)` and rewrites `\d \w \D \W` to ASCII sets, `\\` and `\s` left alone.
Decisions: 1. the parser reads JSON as `jsonDecode` does: a trailing comma throws, a repeated key keeps
its last value (memory "swift-client-double-decoding": resolver JSON only) · 2. a non-empty separator
splits by code units too ("éx" on "é" was ["", "x"]; Dart ["éx"]) · 3. nested ICU sets inside a class.
Review fit: pass
Review quality: pass

#### Task T6 · Kotlin resolver: Dart's corners
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/json/JsonValue.kt` · `json/SwiftText.kt` ·
`resolver/Transforms.kt` · `resolver/ValueResolver.kt` · test `resolver/TransformTest.kt`
Cases: P1-P5 (Kotlin) → green (core 118 = 113 + 5, 0 failures; ResolverFixtureTest over all 30;
sdk 128; lint 0) · red first: the 5 new tests and ResolverFixtureTest at fixture 25.
Changed: strings equal by UTF-16 code units; `parseNumber` as `jsonDecode` (an integer literal in Int64
is an int; a fraction, exponent or bigger integer a double) · `split("")` per code unit, `contains` by
code units, empty pattern accepted, `RegexSupport.asciiClasses` in `compile` (UNICODE_CHARACTER_CLASS
kept, so `\s` stays Unicode and Android matches the JVM) · SwiftText's unused `canonical` removed; KDocs
and port notes say what still follows Swift and what follows Dart.
Decisions: 1. nested classes inside a class; the rewrite only for page patterns · 2. outside P1-P5 Swift's
Characters stay (tween colour `#`, lerpColor, `$n`, Action and DevTools prefixes) · 3. `-0` an int and
an integer past Int64 a double, checked with `dart run`.
Review fit: pass
Review quality: pass

### Test run
Once, after group 2, on the tree with all six tasks (logs in the session scratchpad, `s11/g2-*.log`):
- `cd engine && bun test` · 697 pass, 1 fail · `test/server.test.ts`: EADDRINUSE on 8080, your Docker;
  the baseline's environmental failure.
- `cd sdk && flutter test` · +235: All tests passed!
- `cd sdk-swift && swift test` · Executed 116 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, 0 failures; OrcaGatewayCoreTests 116,
  0 failures · ** TEST SUCCEEDED **
- `cd sdk-kotlin && ./gradlew build --continue` · BUILD SUCCESSFUL · core 118, 0 failures · sdk
  testDebugUnitTest 128, 0 failures, 0 skipped · lint "No issues found".
Against the 08 baseline: Flutter +6, Swift core +5, iOS UI +4, Kotlin core +5, sdk +1; nothing that
passed fails. Every changed file sits in a task's Files; no stray file.

### Blocked
none

### Not done
none. Left outside S11, found while building (question 2):
- `\b` and `\B` follow Unicode word characters in both SDKs; Dart's are ASCII ("café": Dart finds
  edges at 0 and 3, Swift and Kotlin at 0 and 4).
- With the `i` flag, `[A-Za-z]` also matches ſ, K (Kelvin sign), ı and İ in Kotlin (ICU and the JVM
  fold them; Dart does not). Swift's ICU likely does the same; not checked.
- Kotlin's "!" after a failed Image load is its own accessibility node; Flutter merges it into the
  alt label (your group 1 answer: keep, note for later).
- Swift's `OrcaClient` still decodes Codable models through JSONDecoder, so a live 4.0 inside a
  model reads as 4 (your gate 08 answer). Kotlin's live client now reads it as Dart does.

### For ship (stage 10) to know
Nothing deploys and nothing is published. Push feat/native-sdk-s11 and open the PR (Auto-fix off).
CI to expect: Engine (conformance over 30 fixtures), SDK (Flutter), Schema, SDK Swift on ubuntu
(5.10 and 6.2: the first Linux run of T5's parser), SDK Swift UI, SDK Kotlin (JDK 17 and 21).
