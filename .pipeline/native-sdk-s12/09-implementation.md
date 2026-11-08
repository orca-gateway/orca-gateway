# 09 · Implementation · native-sdk-s12

## Front page

### In one breath
group 2 of 2 · tasks: 2 green · cases: 4 of 4 green (R1, R2, A1, C1) · every suite green
T6 Swift: `\b` `\B` are ASCII edges, `[\b]` a backspace; under `i` letters fold as in Dart.
T7 Kotlin: the same rule; a modifier group like `(?-i:s)` works again under `i` (one rework).
T6's retry (your A): F4 told; `ss` and `fi` no longer match "ß" and "ﬁ", pinned by a test.
Tests: Swift 130, iOS UI 54 + 130, Kotlin core 130, sdk 128, lint 0; Flutter 239, analyze 0.
Engine 699 pass + 1 fail (port 8080, your Docker, as at baseline). Nothing pushed.

### New for you
1. Why only four letters need rewriting (regex case folding) → learning/regex-case-folding.md

### Trade-offs
1 your call (A): modifier scope is a known limit, noted for later in epic row 23b.36.
3 auto-decided: the ten-letter rule, modifier headers copied as is, `\p{…}` copied as is.

### Questions for you
1. `A` approves stage 09; then 10: push, open the PR, read its CI once. (default: yes)
2. Epic row 23b.36 holds what is left: modifier scope, `ß` and ligature patterns under `i`,
   escaped letters, Kotlin's long `\p{…}` names, patterns Dart rejects. (default: as written)

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
Commits in the order they passed review: T7 42d9636, T7's rework 3c919bc, T6 88583cf (after its
retry on your "A" at round 2). Nothing pushed. T6 and T7 ran in parallel, each blind to the other's
SDK; their reworks read the other's code for parity.

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
Cases: R1, R2 (Swift) → green (`swift test` 130; iOS UI 54 + core 130; Linux swift 5.10 and 6.2:
129 before the retry's one test) · red first: 6 tests; the rework's 22 + 10 assertions; the F4 test
green at once (the rework already closed those rows; raw ICU gives "#" on all four).
Changed: `asciiClasses(_:ignoreCase:unicode:)` tracks class context; `\b \B \w \W` as in Kotlin;
`[\b]` is U+0008. The rework takes Kotlin's ten-letter rule (literal → Dart's case set; class C →
`(?:(?!T)C|(?-i:[M]))`, M by compiling C case-sensitively, no range parsing), under `u` too, and
copies `\p{…}` and modifier headers unchanged. The retry: two doc-comment lines naming F4's
remaining cases. Tests: 6 + `testR2_aClassNamingOneOfTheFourFollows…` (39 rows) +
`testR2_F4_sharpSAndLigatures…` (gi, giu); every expected value printed by the Dart VM.
Decisions: 1. ten letters with i and I: ICU's full folding made `[İ]` match "i̇" (i + U+0307) ·
2. `\p{…}` copied under `u` · 3. headers copied; inside one, letters follow the global `i` (your A:
a known limit, row 23b.36) · 4. F4 rows pinned only where Swift gives Dart's value.
F4 (Dart / Swift now, gi and giu alike): pinned `ss` on "ß" ß/ß · `SS` on "ß" ß/ß · `fi` on "ﬁ" ﬁ/ﬁ ·
`st` on "ﬆ" ﬆ/ﬆ; still ICU, for row 23b.36: `ß` on "ss" ss/# · `ff` on "ﬀ" ﬀ/# · `ﬁ` on "fi" fi/# ·
`ß` on "SS" SS/# · gi only, `ß` on "ẞ" ẞ/#.
Review fit: `[ſ]` folded the ICU way under gi (`[^ſ]` missed s), fixed (one rework); then F4 untold
after the rework, blocked at round 2; retried on your "A": pass
Review quality: pass (again after the retry: pass)

### Test run
Once after the group (logs in the session scratchpad, `s12/g2-*.log`), Swift and Kotlin again after
the reworks (`s12/g2b-*.log`), Swift and iOS once more after T6's retry (`s12/g2c-*.log`):
- `cd engine && bun test` · 699 pass, 1 fail · `test/server.test.ts`: EADDRINUSE on 8080, your
  Docker; the baseline's environmental failure.
- `cd sdk && flutter test` · +239: All tests passed! · `flutter analyze` · No issues found.
- `cd sdk-swift && swift test` · Executed 130 tests, with 0 failures.
- `xcodebuild test … id=FDE5D612…` · OrcaGatewayTests 54, OrcaGatewayCoreTests 130, 0 failures,
  TEST SUCCEEDED.
- `cd sdk-kotlin && ./gradlew build` (core and sdk tests forced to rerun) · core 130, sdk 128,
  0 failures · lint "No issues found".
Engine and Flutter files did not change after their run. Every changed file sits in T6's or T7's
Files; no stray file. Your Docker services kept running.

### Blocked
none (T6 was blocked at round 2 — F4 untold after its rework — and cleared on its retry)

### Not done
none

### Found for later (epic row 23b.36, added on your "A" at round 2)
- Modifier scope: letters inside `(?-i:…)` or `(?i:…)` follow the global `i`, in both SDKs
  (`(?-i:s)` gi on "sS": Dart "#S", ours "##"; `(?i:s)` g on "ſsS": Dart "ſ##", Kotlin "###").
- F4's rest: a pattern holding ß or a ligature still folds the ICU way in Swift (`ß` matches "ss",
  "SS", "ẞ"; `ff` "ﬀ"; `ﬁ` "fi"), and likely in Kotlin on Android; Dart matches none.
- Letters written as escapes (`\x73`) and backreferences keep the engine's folding, in both SDKs.
- Kotlin: java.util.regex knows no long property names (`\p{Lowercase_Letter}` under giu: null;
  Dart "##1").
- Patterns Dart rejects (`(?i)a`, `(?-:a)`, `(?u:a)`) still run in Kotlin (Swift not checked).
The epic plan (outside the repo) has the row; its backup before the edit is in the session
scratchpad (`epics-before-s12-g2.md`).

### For ship (stage 10) to know
Nothing deploys and nothing is published. The Flutter SDK changes (T2), so its next release's
`sdk/CHANGELOG.md` gets an entry then. The Swift and Kotlin fixes reach apps with their next
releases through release.sh. Nothing is pushed until stage 09 is approved. Over main c394c5b (not
moved, fetched at this card): 13 commits, 8 of code (T1-T7, T7's rework) and 5 of pipeline notes
(S11's two closing notes among them).
