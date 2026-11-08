# 08 · Tasks · native-sdk-s12

## Front page

### In one breath
tasks: 7 in 2 groups · widest group: 5 · cases: 4 of 4 placed (R1, R2, C1 once per side)
S12 is 23b.34: regex word edges and the `i` flag as Dart; a failed Image's alt; Swift's live 4.0.
Group 1: fixtures 31-32 (green on engine, Flutter), the Image label, Swift reads a live 4.0.
Group 2: the Swift and Kotlin regex rewrites turn fixtures 31-32 green; red between by design.
Checked first: Flutter drops a failed Image's alt (only "!" is read), so the row's premise was off.

### New for you
1. Case-insensitive regex: engines fold letters differently → learning/regex-case-folding.md

### Trade-offs
2 needs you: a failed Image keeps its alt (Flutter changes) or reads "!"; Swift writes 4.0 as 4.
2 auto-decided: fixtures before the SDK fixes; a rewrite for the four letters, not a full engine.

### Questions for you
1. Commands: `bun test`, `flutter test` + `flutter analyze`, `swift test` + the iOS simulator,
   `./gradlew build`. (default: as found)
2. Commits: one per task on feat/native-sdk-s12; nothing pushed before stage 10. (default: yes)
3. One gate per group? (default: yes, 2 gates)
4. A failed Image: Flutter reads "!" only, Swift the alt, Kotlin both. All read the alt as an
   image, "!" hidden (Flutter's Image builder changes)? Else all read "!". (default: the alt)
5. Swift also writes a 4.0 back as 4 (request bodies, typed Values). Note it as row 23b.35, or
   fix it now as T8 in group 2? (default: note it, as your S11 call kept 4.0 to the resolver)

## Appendix

### Where S12 comes from
Epic row 23b.34, written at S11 gate 09 from what S11 left: regex `\b`/`\B`, the `i` flag's ſ/K/ı/İ,
Kotlin's failed-Image "!" and the accessibility label, Swift `OrcaClient`'s live 4.0 inside Codable
models. Done when: "A render fixture per regex corner in `schema/fixtures/render/`, green on the
engine, Flutter, Swift and Kotlin; an ImageTest for the label; an OrcaClient test for the live 4.0".
S12 started on your "Start S12" after native-sdk-s11 gate 12 (A); stages 01-07 skipped as covered by
native-sdk. Branch feat/native-sdk-s12 from main c394c5b (PR #18's merge), with S11's closing notes
cherry-picked (5aa03f5, fefd208).

### Checked before planning (2026-11-08)
Dart VM via Flutter 3.44.7, a scratch program; Swift's NSRegularExpression (ICU) on macOS; Java 25
`java.util.regex` with Kotlin's flags (CASE_INSENSITIVE | UNICODE_CASE | UNICODE_CHARACTER_CLASS).
- `\b` replaced by "|" on "café x": Dart "|caf|é |x|" (all flag sets); ICU and Java "|café| |x|".
  `\B` on "café": Dart "c|a|fé|"; ICU and Java "c|a|f|é". With u+i Dart counts ſ and K as word
  characters: `\b` on "ſK" gives "|ſK|", otherwise "ſK".
- `i` without `u`: Dart matches none of ſ, K, ı, İ with `[a-z]`, `[A-Z]`, `s`, `k`, `i`, `I`; `[^a-z]`
  matches all four. `u`+`i`: ſ matches `[a-z]`, `[A-Z]`, `s`; K matches `[a-z]`, `[A-Z]`, `k`; ı and İ
  match no ASCII letter; `[^a-z]` matches ı and İ only.
- ICU with `.caseInsensitive`: ſ↔s and K↔k always (Dart's u+i), ı and İ never. Java (JVM): all four
  fold to ASCII. Android's java.util.regex is ICU, so Kotlin on a phone behaves like Swift.
- A failed Image: Flutter's `Image` returns the errorBuilder's widget early
  (`flutter/lib/src/widgets/image.dart` ~1378), before the `Semantics(image, label: alt)` it wraps a
  loaded image in, so a screen reader gets only "!". Swift (`Media.swift` 59-61) reads the alt as an
  image and hides "!". Kotlin (S11) reads the alt box, then "!" as its own node. My S11 note ("Flutter
  merges '!' into the alt label") was wrong, and so is row 23b.34's wording.

### Cases (the Flutter SDK, Dart, is the oracle unless question 4 says otherwise)
- R1 `\b` and `\B` are ASCII word edges, as in Dart; with flags u+i, ſ and K are word characters
  too. Inside a class, `[\b]` is a backspace, as in Dart (Java rejects `\b` in a class today).
- R2 With `i`, the four letters that Unicode folds into ASCII (ſ U+017F, K U+212A, ı U+0131, İ U+0130)
  follow Dart: without `u` none matches an ASCII letter, class or `\w`, and `[^a-z]` matches all four;
  with `u` ſ ≡ s and K ≡ k, ı and İ still match no ASCII letter. Guard: é ≡ É under `i` in both modes.
- A1 (question 4, default) A failed Image (404, empty or non-http `src`) is read by screen readers as
  its alt with the image role; "!" stays drawn but hidden from them. Flutter and Kotlin change;
  Swift already does it.
- C1 Swift's `OrcaClient` keeps a live JSON 4.0 a double inside models: the page fetch, the 426 page,
  server-action responses and the executor's component decoding (all via `JSONValue.decode<T>`).
  Kotlin already does (its models parse through `JsonValue.parse`): a pin test only.

### Groups
Paths from the repo root.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Fixtures 31-32: word edges, ASCII folding | `schema/fixtures/render/31_regex_ascii_word_boundary.json` (new) · `schema/fixtures/render/32_regex_ignore_case_ascii_fold.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` | R1, R2 (engine, Flutter) | M | none |
| 1 | T2 | Flutter failed Image announces its alt | `sdk/lib/src/builders/primitive_builders.dart` · `sdk/test/image_error_semantics_test.dart` (new) | A1 (Flutter) | M | none |
| 1 | T3 | Kotlin failed Image hides "!" | `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Image.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ImageTest.kt` | A1 (Kotlin) | S | none |
| 1 | T4 | Swift client keeps a live 4.0 | `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValueDecoder.swift` (new) · `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValue.swift` · `sdk-swift/Sources/OrcaGatewayCore/Client/OrcaClient.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/OrcaClientTests.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/ActionExecutorTests.swift` | C1 (Swift) | M | none |
| 1 | T5 | Kotlin pin: live 4.0 stays a double | `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/OrcaClientTest.kt` | C1 (Kotlin, pin) | S | none |
| 2 | T6 | Swift regex: ASCII edges, Dart folding | `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/TransformTests.swift` | R1, R2 (Swift) | S | T1 |
| 2 | T7 | Kotlin regex: ASCII edges, Dart folding | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/resolver/TransformTest.kt` | R1, R2 (Kotlin) | S | T1 |
R1 and R2 are each placed once per side: T1 (engine, Flutter), T6 (Swift), T7 (Kotlin). C1 once per
SDK: T4 fixes Swift, T5 pins Kotlin. A1 in each SDK that changes: T2, T3. A case is done when every
side passes. Fixed by hand after the planner: T2 no longer lists `sdk/CHANGELOG.md` (entries are
written at release time, as 0.3.3's was), and R1 gained `[\b]` (planner's F5).

### Order, and why each boundary
- 1 → 2: T6 and T7 are accepted by T1's fixtures (all four runners scan `schema/fixtures/render/`),
  and group 1's engine and Flutter runs check both fixtures against Dart before either SDK changes.
  Between the groups Swift's ResolverFixtureTests and Kotlin's ResolverFixtureTest fail on 31-32 by
  design; nothing else may. T2-T5 need nothing from T1, so they widen group 1 (five tasks: launched
  as four, then one).

### Seams
none: no file is in two tasks. T1 owns all three fixture-count pins (Swift `ModelRoundTripTests.swift`
:10 and :151, Kotlin `ModelRoundTripTest.kt` :30 and :176, `FixturePathsTest.kt` :10) and sets 32,
"01-32". T4 touches no Resolver file, T6 no JSON file.

### Findings while planning
F1 C1, the read path: T4 fixes `OrcaClient.swift:89` (JSONDecoder on the page body) and, through
   `JSONValue.decode<T>`, `:112`, `:143` and `ActionExecutor.swift:145,150` (ActionExecutor itself is
   untouched; ActionExecutorTests pins addComponent). Tests that call `.decode(T.self)` reach the new
   decoder too (`NativeWidgetTests.swift:208`, ModelRoundTripTests), so T4 runs `swift test` and iOS.
   `ActionStub.swift:46` builds bodies with `encoded()`, so T4's tests serve raw JSON text.
F2 C1, the write path (question 5): `JSONValue.encoded()` and `JSONValue(encoding:)` use JSONEncoder,
   which writes a whole Double as `4`; so Swift sends 4 in the page POST's appState and in
   executeAction's params and states (`OrcaClient.swift:137, :209, :222`), where Dart and Kotlin send
   4.0, and `Value.json`, `BoolExpr.json`, `Transform.json`, `Action.json` turn a typed 4.0 into
   `.int(4)` (public `ValueResolver.resolve(_: Value)`, DevTools' action payload). The bun engine reads
   4 and 4.0 alike; engine-dart would not. If you choose T8: `JSONValue.swift`, a new
   `JSON/JSONValueEncoder.swift`, a new test file; group 2, size M, after T4.
F3 R1 and R2 are one mechanism per SDK (the S11 rewriters: Swift `Regex.compile`, Transforms.swift
   ~401; Kotlin `RegexSupport.compile`, Transforms.kt ~389). The word set replacing `\b`, `\B`, `\w`,
   `\W` must be fold-proof under `i` (e.g. `(?-i:…)`): ICU closes `[A-Za-z0-9_]` over case (adds ſ, K),
   the JVM adds ı and İ too. Neither compile reads the `u` flag today; u+i needs it. Dart's `matches` op
   takes no flags (`value_resolver.dart:171`), so R1 reaches it and R2 does not.
F4 Likely further corner, settled by one TransformTests row in T6: ICU folds case-insensitive
   literal strings fully, so under `i` Swift (and Kotlin on Android) may match `ss` against "ß" or
   `fi` against "ﬁ"; Dart never does; the JVM compares char by char like Dart. If it holds, it is
   noted for later, not fixed in S12.
F5 Kotlin's regression guard matters: dropping UNICODE_CASE to stop ı and İ on the JVM would also
   stop é ≡ É; and no test runs Kotlin's regex on Android's ICU (Robolectric uses the JVM's), so Android
   stays right only if the rewrite does not lean on the engine's folding for the four letters.
F6 Kotlin's ResolverFixtureTest stops at its first failure; 31-32 sort last, so between the groups they
   hide no older fixture. T7 turns both green together.
F7 A1: Kotlin's `ImageTest.kt:261` finds "!" with `hasText("!") and hasParent(hasContentDescription(alt))`
   in the merged tree, so T3 rewrites that lookup; `native-widgets-home.png` stays as it is. Under
   flutter_test every HTTP GET answers 400, so T2's test reaches the errorBuilder with no mock; T2
   changes Dart code, so `flutter analyze` (0 issues) is one of its checks.
F8 Kotlin's models keep 4.0 a double already: `OrcaClient.kt:115` decodes PageResponse with kotlinx
   `Json`; every JsonValue field goes through `JsonValueSerializer.deserialize` → `fromJsonElement` →
   `parseNumber` (S11), and `encoded()` writes "4.0". No client test pins it: T5.

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` · `cd sdk-swift
&& xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=FDE5D612-86BA-4138-A1BD-1AB2CF9E8773'`
· `cd sdk-kotlin && ./gradlew build --console=plain` · lint: Kotlin's inside its build, `cd sdk &&
flutter analyze` · typecheck: none · baseline (2026-11-08, main c394c5b, the same code as S11's final
run): engine 697 pass, 1 fail (`test/server.test.ts` wants port 8080, held by your Docker;
environmental); Flutter 235 passed; Swift core 116, 0 failures; iOS UI 54 + core 116, TEST SUCCEEDED;
Kotlin core 118, sdk 128, lint 0. Green at 09: a task's cases pass and nothing that passed here fails
(fixtures 31-32 on Swift and Kotlin are red between the groups by design).

### Not planned
- A1 on Swift: Swift already reads the alt as an image and hides "!" (`Media.swift` 59-61). No Swift
  test reads SwiftUI's accessibility tree (NativeWidgetTests measures frames), so a pin needs a new
  harness; not in S12.
- C1's write path (F2): question 5; T8 if you choose it.
- F4 (ICU's full folding of strings like "ß"): checked by T6, noted for later if it holds.
- `sdk/CHANGELOG.md`: the Flutter SDK's next release writes its entry.

### Commits on feat/native-sdk-s12 (conventional, per task on your yes to question 2)
1. chore(pipeline): native-sdk-s11 closing notes (done, cherry-picked)
2. chore(pipeline): native-sdk-s12 stage 08
3. one `test(…)`/`feat(…)`/`fix(…)` commit per task, in the order they pass review
4. chore(pipeline): stage 09 onward
