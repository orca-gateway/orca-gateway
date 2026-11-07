# 08 · Tasks · native-sdk-s11

## Front page

### In one breath
tasks: 6 in 2 groups · widest group: 4 · cases: 10 of 10 placed (P1-P5 once per side)
S11 is 23b.33: Swift and Kotlin resolve strings as Dart does; Swift's flex, Kotlin's "!" too.
Group 1: six render fixtures (the spec, green on engine and Flutter), Swift flex, Kotlin Image.
Group 2: the Swift and Kotlin resolvers turn fixtures 25-29 green; red between groups by design.
Checked on Dart: no final-sigma rule ("ΟΔΟΣ" → "οδοσ"); Swift and Kotlin already match.

### New for you
1. Comparing strings by UTF-16 units or by characters → learning/utf16-code-units.md

### Trade-offs
2 needs you: Swift's split("") keeps emoji pairs whole; a live 4.0 still reads as 4 in Swift.
2 auto-decided: fixtures before the SDK fixes; `\d` `\w` rewritten to ASCII before compiling.
1 auto-decided (memory): follow Dart's lowercase, not the row's final-sigma wording.

### Questions for you
1. Commands: `bun test`, `flutter test`, `swift test` + the iOS simulator, `./gradlew build`.
   (default: as found)
2. Commits: one per task on feat/native-sdk-s11; nothing pushed before stage 10. (default: yes)
3. One gate per group? (default: yes, 2 gates)
4. Swift's split("") keeps a surrogate pair (an emoji) whole; Dart splits it, Swift can't hold
   half. Kotlin matches Dart exactly. (default: yes)
5. Swift's OrcaClient still reads a live JSON 4.0 as 4; S11 fixes the resolver only. (default: yes)
6. Row 23b.33 is corrected: Dart's lowercase has no final-sigma rule; fixture 30 pins "οδοσ".
   (default: yes)

## Appendix

### Where S11 comes from
Epic row 23b.33: the native SDKs match Dart in the corners found while porting.
- Six resolver corners, found at S6 gate 09 (`.pipeline/native-sdk-s6/09-implementation.md`,
  "Swift against Dart"). Kotlin follows Swift there, so both native SDKs differ from Flutter.
- Swift's flex layout, found at S7 gate 09 (`.pipeline/native-sdk-s7/09-implementation.md`).
  Kotlin's Flex already follows the Flutter SDK; Swift's `FlexView` does not.
- Kotlin's Image, found at S9 gate 10. Flutter's errorBuilder draws
  `SizedBox(width, height, child: Center(child: Text('!')))`
  (`sdk/lib/src/builders/primitive_builders.dart`); Swift draws "!"; Kotlin draws an empty box.
- Done when: "One render fixture per corner in `schema/fixtures/render/`, green on the engine,
  Flutter, Swift and Kotlin; a Swift layout test per flex case".
S11 started on your "Start S11" after native-sdk-s10 gate 12 (A); stages 01-07 skipped as covered
by native-sdk. Branch feat/native-sdk-s11 from main 07d5279, with S10's closing notes cherry-picked.

### Cases (from row 23b.33; the Flutter SDK, Dart, is the oracle)
Resolver corners: each is a render fixture whose Values read page state, so the engines emit them
unresolved with `watches`, and each SDK checks the fixture's `resolved` map.
- P1 `contains` with an empty needle is true: the string `contains` transform and the `contains`
  BoolExpr op. Swift and Kotlin say false today.
- P2 Strings compare by UTF-16 code units: `eq`, `contains` and `startsWith` between "é" (U+00E9)
  and "e" + U+0301 are false; `split("")` on "e" + U+0301 gives two parts. Swift compares Characters
  with canonical equivalence. Kotlin's behaviour is checked.
- P3 An empty regex pattern is accepted: a global replace of "" by "-" on "ab" gives "-a-b-".
- P4 Regex `\d` and `\w` are ASCII only: they skip Arabic-Indic digits and accented letters.
- P5 A JSON `4.0` in state stays a double: `toString` gives "4.0", and an int `4` still gives "4".
- P6 `toLowerCase` maps each code point on its own, as Dart's VM does: "ΟΔΟΣ" gives "οδοσ" (no
  final "ς"). The row and S6 said Dart applies final sigma; checked on Dart 2026-11-08, it does not (F12).
Swift flex layout (Kotlin already matches; a Swift layout test per case, beside `StackTests`):
- L1 `spaceAround` as Flutter: half-size space at both ends, not `spaceEvenly`'s equal spaces.
- L2 `gap` with `spaceEvenly` and with `spaceAround`, placed as the Flutter SDK inserts it.
- L3 a Column's cross-axis `baseline` acts as `start`; Swift centres it today.
Kotlin Image:
- I1 an Image whose load fails, or whose `src` is empty, draws "!" centred in a box of its width
  and height, as Flutter's errorBuilder does.


### Groups
Paths from the repo root.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Fixtures 25-27: contains, UTF-16, empty regex | `schema/fixtures/render/25_contains_empty_needle.json` (new), `schema/fixtures/render/26_utf16_code_units.json` (new), `schema/fixtures/render/27_regex_empty_pattern.json` (new), `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` | P1, P2, P3 (engine, Flutter) | M | none |
| 1 | T2 | Fixtures 28-30: ASCII classes, double, lowercase | `schema/fixtures/render/28_regex_ascii_classes.json` (new), `schema/fixtures/render/29_state_double_to_string.json` (new), `schema/fixtures/render/30_lowercase_per_code_point.json` (new), `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt`, `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` | P4, P5 (engine, Flutter); P6 (all four) | M | none |
| 1 | T3 | Swift flex: spaceAround, gap, baseline | `sdk-swift/Sources/OrcaGateway/Widgets/Layout.swift`, `sdk-swift/Sources/OrcaGateway/Widgets/Flex.swift`, `sdk-swift/Tests/OrcaGatewayTests/FlexLayoutTests.swift` (new) | L1, L2, L3 | M | none |
| 1 | T4 | Kotlin failed Image draws "!" | `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Image.kt`, `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ImageTest.kt`, `sdk-kotlin/sdk/src/test/resources/goldens/native-widgets-home.png` | I1 | M | none |
| 2 | T5 | Swift resolver: Dart's corners | `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValue.swift`, `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift`, `sdk-swift/Sources/OrcaGatewayCore/Resolver/ValueResolver.swift`, `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift` | P1-P5 (Swift) | M | T1, T2 |
| 2 | T6 | Kotlin resolver: Dart's corners | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/json/JsonValue.kt`, `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/json/SwiftText.kt`, `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt`, `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/ValueResolver.kt`, `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt` | P1-P5 (Kotlin) | M | T1, T2 |
P1-P5 are each placed once per side: the fixture task (engine, Flutter) and T5 (Swift) and T6
(Kotlin); a case is done when all three are green (F1). P6 needs no SDK change (F12).

### Order, and why each boundary
- 1 → 2: T5 and T6 are tested by T1's and T2's fixtures (all four runners scan
  `schema/fixtures/render/`), and group 1's Flutter run checks each fixture against Dart before
  either SDK changes. Between the groups, Swift's ResolverFixtureTests and Kotlin's
  ResolverFixtureTest fail on fixtures 25-29 by design; nothing else may fail. T3 and T4 need
  nothing, so they widen group 1.

### Seams
none: no file is in two tasks. Three tests pin the fixture count at 24 (Swift
`ModelRoundTripTests.swift:10`, Kotlin `ModelRoundTripTest.kt:30`, `FixturePathsTest.kt:10`); T1 owns
the Swift one, T2 the Kotlin two, and each sets 30, which counts both tasks' fixtures (green once
both of group 1 land).

### Findings while planning
F1 Each of P1-P5 needs a fixture, a Swift change and a Kotlin change; no task of five files holds
   all three, so each is placed once per side. Fixtures first: they are the spec and Flutter (Dart)
   checks them before any SDK changes. The other order (SDK unit tests first, fixtures last) keeps
   every gate green but would show a wrong case only after both SDKs changed.
F2 No engine, Flutter, schema or other sync-point change: every op and transform exists in
   `value.schema.json`; the four runners scan the folder; the engine leaves page-state Values
   unresolved. So every corner's input lives in pageState (a static or info input collapses in the
   engine, as 23_regex_replace does, and no SDK would ever resolve it).
F3 The three fixture-count tests above (why T1 and T2 own them).
F4 P5 in Swift: JSONDecoder reads `4.0` and `4` alike, so `JSONValue.decode(Data)` needs a parse
   that sees the number's text (JSONSerialization's NSNumber type, or a scanner). `OrcaClient`
   decodes PageResponse through Codable, so a live 4.0 in page state still reads as 4; that is
   outside T5's files. The bun engine never writes 4.0; engine-dart can. Question 5.
F5 (Superseded by F12.) Whether Dart applies final sigma was to be settled by T2's Flutter run.
F6 P2's `split("")` cannot match Dart outside the BMP in Swift: Dart returns lone surrogates, which a
   Swift String cannot hold (they become U+FFFD), and PropertyTests' split/join round trip (its
   alphabet has 🙂) would break. Default: Swift splits by code unit but keeps each surrogate pair
   whole; Kotlin matches Dart exactly; fixture 26 uses BMP text only. Question 4.
F7 P4: ICU (Swift, and Android at run time) has no ASCII switch for `\d` and `\w`, so T5 and T6
   rewrite `\d \w \D \W` (inside character classes too) before compiling. Only dropping Kotlin's
   UNICODE_CHARACTER_CLASS would pass the JVM fixture but differ on Android, and would make `\s`
   ASCII too, where Dart's `\s` is Unicode.
F8 Kotlin matches none of P1-P5 today: `JsonValue.kt` compares strings by canonical equivalence and
   reads "3.0" as an int, and `SwiftText.kt` copies Swift's rules, on purpose at S6 (trade-off 2,
   "Kotlin follows Swift"). Row 23b.33 moves both to Dart. Kotlin's Flex already matches L1-L3;
   Swift already draws "!".
F9 I1 and L1-L3 cannot be render fixtures (a fixture pins flat nodes, not drawing): L1-L3 get
   FlexLayoutTests on the iOS simulator, I1 an ImageTest under Robolectric. In Flutter a non-http
   `src` is also a failed load ("!"); while loading the box stays empty. ImageTest's i2 pins the
   empty box for a 404 and a non-http src, so it changes; test G3 empties every Image src, so
   `native-widgets-home.png` is re-recorded.
F10 L2: Flutter's `_addGaps` inserts SizedBox children between the real ones; with n children,
   spaceEvenly splits the free space into 2n slots and spaceAround spaces 2n−1 children. No recorded
   page uses spaceAround, spaceEvenly, gap or baseline, so Swift's five goldens stay valid if
   FlexView keeps its stack layout for the other alignments.
F11 `FlexView` lives in Layout.swift and `FlexLayout` (the RenderFlex port) in Flex.swift; T3 is the
   UI target, T5 the core: no shared file.
F12 Checked on Dart (VM, 2026-11-08, a scratch program): `"ΟΔΟΣ".toLowerCase()` is "οδοσ" (U+03C3),
   so Dart does not apply final sigma; Swift's `lowercased()` gives the same, and Kotlin's
   `SwiftText.lowercased` maps per code point too (plain Java `toLowerCase` would give "ς"). So all
   four already agree: fixture 30 pins "οδοσ", T5 and T6 leave lowercase alone, and row 23b.33's
   "applies the final-sigma rule" is corrected (question 6). The same run confirmed the other five:
   `contains('')` true; "é" == "e"+U+0301 false; `split('')` of "e"+U+0301 gives 2; `replaceAll(RegExp(''),
   '-')` on "ab" gives "-a-b-"; `\d+` on "٣ 4" finds only "4"; `\w+` on "café_1" finds "caf", "_1";
   `4.0.toString()` is "4.0".
F13 engine-dart's `dart test` does not load on main (its conformance test imports
   `package:orca_engine`; the package is `orca_gateway_engine`) and no workflow runs it. Out of S11.

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` · `cd sdk-swift
&& xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773'`
(iPhone 16 Pro; by id, the name alone does not match) · `cd sdk-kotlin && ./gradlew build
--console=plain` · lint: Kotlin's inside its build (no Dart code changes, so no `flutter analyze`) ·
typecheck: none · baseline (2026-11-08, main 07d5279): engine 691 pass, 1 fail (`test/server.test.ts`
wants port 8080, held by your Docker; environmental, untouched); Flutter 229 passed; Swift core 111
tests, 0 failures; iOS: UI 50 + core 111, TEST SUCCEEDED; Kotlin core 113, sdk 127, lint 0.
Green at 09: a task's cases pass and nothing that passed here fails (fixtures 25-29 on Swift and
Kotlin are red between the groups by design).

### Not planned
none: all 10 cases are placed. Out of S11: Swift's `OrcaClient` number decoding (F4), engine-dart's
broken test (F13), Swift's flex for the alignments no page uses beyond L1-L3.

### Commits on feat/native-sdk-s11 (conventional, per task on your yes to question 2)
1. chore(pipeline): native-sdk-s10 closing notes (done, cherry-picked)
2. chore(pipeline): native-sdk-s11 stage 08
3. one `test(…)`/`feat(…)`/`fix(…)` commit per task, in group order
4. chore(pipeline): stage 09 onward
