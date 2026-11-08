# 09 · Implementation · native-sdk-s12

## Front page

### In one breath
group 1 of 2 · tasks: 5 green, 0 blocked · cases: 2 of 4 green (A1, C1) · R1, R2 half done
T1 fixtures 31-32: `\b` edges, `[\b]`, the `i` flag's four letters; green on engine and Flutter.
T2 Flutter: a failed Image reads as its alt with the image role; "!" is drawn but hidden.
T3 Kotlin: the same; "!" is no longer its own screen-reader node. No screenshot changed.
T4 Swift: a live 4.0 stays a double in pages and actions; also passed on Linux (Swift 5.10, 6.2).
T5 Kotlin: three tests pin that its client already keeps a live 4.0.
Tests: engine 699 + 1 fail (port 8080), Flutter 239, analyze 0, iOS UI 54, Kotlin sdk 128.
Red by design until group 2: Swift and Kotlin resolvers on fixtures 31-32 (14 sub-cases).

### New for you
nothing new

### Trade-offs
1 review finding, fixed: T4 copied two test helpers into two files; they are shared now.
3 auto-decided: where Kotlin clears "!", Flutter's semantics shape, an internal Swift decoder.

### Questions for you
1. Next: group 2, T6 Swift regex and T7 Kotlin regex, turning fixtures 31-32 green.
   (default: go; `A` starts it)

## Appendix

### Group 1
Commits, one per task, in the order they passed review: T2 43eeb8c, T5 40beb48, T1 7a29224,
T3 ebd78eb, T4 8f69742. Nothing pushed. T5 was launched after T2 returned (four at once).

#### Task T1 · Fixtures 31-32: word edges, ASCII folding
Files: `schema/fixtures/render/31_regex_ascii_word_boundary.json`, `32_regex_ignore_case_ascii_fold.json`
(new) · Swift `ModelRoundTripTests.swift` · Kotlin `ModelRoundTripTest.kt`, `FixturePathsTest.kt`
Cases: R1, R2 → green on engine (conformance 32/0) and Flutter · red first: the counts, 30 vs 32.
31 (Dart / Swift today): `\b` g, gi, gu on "café x" "|caf|é |x|" / "|café| |x|" · `\B` on "café"
"c|a|fé|" / "c|a|f|é" · giu `\b` on "ſK" "|ſK|" (passes) · g on "ſK" "ſK" / "|ſK|" · `[\b]` on
"a\u0008b" "a-b" / "a\u0008-" (Swift reads `[\b]` as the letter b) · `matches \bcaf\b` on "café" yes / no.
32, gi (Dart / Swift): `[a-z]` on "ſKıİsk" "ſKıİ##" / "##ıİ##" · `s` "ſ#" / "##" · `k` "K#" / "##" ·
`\w` "ſK#" / "###" · `[^a-z]` "####a" / "ſK##a" · é guard "#". giu: Swift already matches Dart.
Decisions: 1. `expected` from the engine's encodeJsonTree; every non-ASCII and control character as
`\u` escapes · 2. the é guard uses a static pattern · 3. counts 32, "01-32".
Review fit: pass
Review quality: pass

#### Task T2 · Flutter failed Image announces its alt
Files: `sdk/lib/src/builders/primitive_builders.dart` · `sdk/test/image_error_semantics_test.dart` (new)
Cases: A1 (Flutter) → green (+2 tests; `flutter analyze` 0) · red first: both failed at the image role.
Changed: the errorBuilder wraps its `SizedBox(width, height)` in `Semantics(container: alt != null,
image: true, label: alt ?? '')`, the wrap Flutter 3.44.7 gives a loaded Image, with "!" inside
`ExcludeSemantics` (still drawn, same box). The test renders an Orca Image through ComponentRenderer
(HTTP 400 under flutter_test): an image node "Photo" (or "" with no alt), no label containing "!",
the "!" text still drawn, the Image still 120x80.
Decisions: 1. "!" absence checked by RegExp, so a merged "Photo\n!" fails too · 2. the loaded-image
layering, so both states read alike.
Review fit: pass
Review quality: pass

#### Task T3 · Kotlin failed Image hides "!"
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Image.kt` · `ImageTest.kt`
Cases: A1 (Kotlin) → green (sdk 128, lint 0; golden tests pass without recording) · red first: three
"!" nodes found.
Changed: "!" is `Text("!", Modifier.clearAndSetSemantics {})`, drawn with no semantics; the alt box's
description and Role.Image unchanged. ImageTest i1: no node with text "!" in either tree; an alt node
with Role Image for Missing, Empty and Asset; a non-white pixel in the box; the centre check kept
through an unmerged lookup; sizes and the null load kept.
Decisions: 1. clear on the "!" Text, not the box (a box clear still shows "!" unmerged) · 2. "drawn"
is any ink in the box (the glyph's ink is not vertically centred in its line).
Review fit: pass
Review quality: pass

#### Task T4 · Swift client keeps a live 4.0
Files: `sdk-swift/Sources/OrcaGatewayCore/JSON/JSONValueDecoder.swift` (new) · `JSON/JSONValue.swift` ·
`Client/OrcaClient.swift` · Tests `OrcaClientTests.swift`, `ActionExecutorTests.swift`
Cases: C1 (Swift) → green (core 122 = 116 + 6; iOS core 122; Linux swift:5.10 and 6.2 images already
on this Mac: 122) · red first: six tests ".int(4) is not .double(4.0)".
Changed: a Decoder over a JSONValue tree; `JSONValue.init(from:)` takes the node whole under it;
`decode<T>` uses it (no JSONEncoder round trip); the page fetch parses the body first. The 426 page,
server actions and ActionExecutor's components follow through `decode<T>`. Write path untouched.
Decisions: 1. the decoder is internal · 2. number reads copy JSONDecoder's · 3. NaN in a hand-built
tree now decodes (a parsed tree never holds one).
Review fit: pass
Review quality: copied test helpers in two files, fixed (one rework: shared at file scope)

#### Task T5 · Kotlin pin: live 4.0 stays a double
Files: `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/OrcaClientTest.kt`
Cases: C1 (Kotlin) → green at once (a pin); a mutation check (4.0 → 4) turned all three red, reverted.
Changed: three tests on raw JSON text — a 200 page, the 426 page, a server action (setState,
updateComponent, addComponent) — each: `JsonValue.Double`, toString "4.0", `encoded()` "4.0", 4 stays
an int.
Decisions: 1. ActionStub's `raw` entry keeps the body raw · 2. update and add pinned too.
Review fit: pass
Review quality: pass

### Test run
Once, after the group (before T4's helper rework, which T4's own runs then covered; logs in the
session scratchpad, `s12/g1-*.log`):
- `cd engine && bun test` · 699 pass, 1 fail · `test/server.test.ts`: EADDRINUSE on 8080, your
  Docker (app-server); the baseline's environmental failure.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · 122 tests, 14 failures, all ResolverFixtureTests sub-cases of
  fixtures 31 and 32. By design until group 2.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, 0 failures; OrcaGatewayCoreTests 122 with
  the same 14.
- `cd sdk-kotlin && ./gradlew build --continue` · core 121, 1 failure: ResolverFixtureTest stops at
  `31_regex_ascii_word_boundary.json b.data` (actual "|café| |x|") · sdk 128, 0 failures · lint
  "No issues found".
- T4's rework: `swift test` 122 with the same 14; xcodebuild UI 54, core 122 with the same 14.
Every changed file sits in a task's Files; no stray file. Your Docker services kept running.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Nothing deploys and nothing is published. The Flutter SDK changes (T2), so its next release's
`sdk/CHANGELOG.md` gets an entry then. Between the groups the branch is red on Swift and Kotlin by
design; nothing is pushed before group 2.
