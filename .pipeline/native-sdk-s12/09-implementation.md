# 09 · Implementation · native-sdk-s12

## Front page

### In one breath
group 2 of 2 · tasks: 1 green (T7), 1 blocked (T6) · cases: 2 of 4 green (A1, C1)
T7 Kotlin: `\b` `\B` are ASCII edges, `[\b]` a backspace; under `i` letters fold as in Dart.
T6 Swift: the same rule, tests green (129), but blocked at its second fit review: F4 untold.
T6's rework found a T7 bug: under `i`, `(?-i:s)` broke Java's regex. Fixed; both reviews pass.
R1, R2: green on the engine, Flutter and Kotlin; Swift's half waits on T6.
Tests: Swift 129, iOS UI 54, Kotlin core 130, sdk 128, lint 0; Flutter 239, analyze 0.

### New for you
1. Why only four letters need rewriting (regex case folding) → learning/regex-case-folding.md

### Trade-offs
1 needs you: inside `(?-i:…)` letters follow the global `i` (Dart "#S", ours "##"): fix or note
3 auto-decided: the ten-letter rule, modifier headers copied as is, `\p{…}` copied as is.

### Questions for you
1. T6 blocked: after its rework the digest drops F4 (ICU folds `ss` to "ß"); no row pins it.
   Retry once: an F4 line (Dart vs Swift, gi and giu), a row with Dart's value. (default: retry)
2. Modifier scope: fix it in both SDKs now, or note it for later with F4 in epic row 23b.36.
   (default: note it)
3. Then T6's two reviews and this card again; `A` there approves stage 09. (default: yes)

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

#### Group 1 test run
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
Every changed file sat in a task's Files; no stray file. Your Docker services kept running.

### Group 2
Commits in the order they passed review: T7 42d9636, T7's rework 3c919bc. T6 is blocked and stays
uncommitted in the tree. Nothing pushed. T6 and T7 ran in parallel, each blind to the other's SDK;
their reworks read the other's code for parity.

#### Task T7 · Kotlin regex: ASCII edges, Dart folding
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/resolver/Transforms.kt` · `TransformTest.kt`
Cases: R1, R2 (Kotlin) → green (core 130, ResolverFixtureTest over all 32; sdk 128; lint 0) · red
first: 6 of 7 tests (the é guard passed before, as a guard should); the rework's 18 of 20 rows.
Changed: `compile` reads `u`; `\b \B \w \W` are case-sensitive ASCII sets (ſ and K added under `iu`);
`[\b]` is `\x08`, a `[` inside a class a literal. Under `i` ten letters (s, k, i in either case; ſ,
K, ı, İ) skip the engine's folding: a literal becomes Dart's case set `(?-i:[..])`, a class C becomes
`(?:(?!T)C|(?-i:[M]))`, M the letters C matches in Dart, found by testing C case-sensitively. The
rework copies a modifier header (`(?-i:`, `(?s:`) unchanged. Tests: R1 ×4, R2 ×3, 20 modifier rows,
38 of Swift's 39 class rows (`\p{Lowercase_Letter}` left out: Java does not know the long name).
Decisions: 1. the ten-letter rule over the plan's lookahead guard (the guard misses `[^ſ]` on s; the
JVM does not match K to `[A-Z]`); 228 of 232 Dart cases alike · 2. headers read as Swift reads them ·
3. limits in the KDoc: escaped letters (`\x73`), backreferences, letters inside a modifier group.
Review fit: pass; then a finding from T6's rework (confirmed here: under `i`, `(?-i:s)`, `(?i:k)`,
`(?s:a.b)` compiled to null where Dart answers "#S", "##", "#"), fixed (one rework)
Review quality: pass (again after the rework: pass)

#### Task T6 · Swift regex: ASCII edges, Dart folding
Files: `sdk-swift/Sources/OrcaGatewayCore/Resolver/Transforms.swift` · `TransformTests.swift`
Cases: R1, R2 (Swift) → tests green (`swift test` 129; iOS UI 54 + core 129; Linux swift 5.10 and
6.2: 129) but the task is blocked at review · red first: 6 tests; the rework's 22 + 10 assertions.
Changed: `asciiClasses(_:ignoreCase:unicode:)` tracks class context; `\b \B \w \W` as in Kotlin;
`[\b]` is U+0008. The rework takes Kotlin's ten-letter rule (literal → Dart's case set; class C →
`(?:(?!T)C|(?-i:[M]))`, M by compiling C case-sensitively, no range parsing), under `u` too, and
copies `\p{…}` and modifier headers unchanged. Tests: 6 + `testR2_aClassNamingOneOfTheFourFollows…`
(39 rows); every expected value printed by the Dart VM.
Decisions: 1. ten letters with i and I: ICU's full folding made `[İ]` match "i̇" (i + U+0307) ·
2. `\p{…}` copied under `u` · 3. headers copied; inside one, letters follow the global `i` (question 2).
F4 (first pass, before the rework): held — under giu `ss`, `fi`, `ff`, `st` matched "ß", "ﬁ", "ﬀ",
"ﬆ", and `ß` matched "ss"; under gi only `ss`, `SS`, `st` stopped. Dart matches none. Not re-told.
Review fit: `[ſ]` folded the ICU way under gi (`[^ſ]` missed s), fixed (one rework); then the digest
drops F4 though the rework rewrites s and i, and no row pins it, blocked
Review quality: pass

### Test run
Once after the group (logs in the session scratchpad, `s12/g2-*.log`), Swift and Kotlin again after
the reworks (`s12/g2b-*.log`):
- `cd engine && bun test` · 699 pass, 1 fail · `test/server.test.ts`: EADDRINUSE on 8080, your
  Docker; the baseline's environmental failure.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · Executed 129 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, OrcaGatewayCoreTests 129, 0 failures,
  TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` (core and sdk tests forced to rerun) · core 130, sdk 128,
  0 failures · lint "No issues found".
Engine and Flutter files did not change after their run. Every changed file sits in T6's or T7's
Files; no stray file. Your Docker services kept running.

### Blocked
T6 · fit, after one rework: the digest drops F4 (ICU's full folding of `ss`, `fi`) although the rework
now rewrites s, S, i, I under gi and giu, and no TransformTests row pins it · tried: one rework (the
`[ſ]` finding, fixed). Its code is green and passed quality; it stays uncommitted until it clears.

### Not done
none

### Found for later (epic row 23b.36 on question 2's default)
- Modifier scope: letters inside `(?-i:…)` or `(?i:…)` follow the global `i`, in both SDKs
  (`(?-i:s)` gi on "sS": Dart "#S", ours "##"; `(?i:s)` g on "ſsS": Dart "ſ##", Kotlin "###").
- F4: ICU folds strings fully (`ss` ≡ "ß", `fi` ≡ "ﬁ"): Swift, and Kotlin on Android; T6's retry
  says which the rework now closes.
- Kotlin: java.util.regex knows no long property names (`\p{Lowercase_Letter}` under giu: null;
  Dart "##1").
- Patterns Dart rejects (`(?i)a`, `(?-:a)`, `(?u:a)`) still run in Kotlin (Swift not checked).

### For ship (stage 10) to know
Nothing deploys and nothing is published. The Flutter SDK changes (T2), so its next release's
`sdk/CHANGELOG.md` gets an entry then. The Swift and Kotlin fixes reach apps with their next
releases through release.sh. Nothing is pushed until stage 09 is approved.
