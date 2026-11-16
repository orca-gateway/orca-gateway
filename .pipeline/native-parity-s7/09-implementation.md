# 09 · Implementation · native-parity-s7

## Front page

### In one breath
group 1 of 7 · tasks: 3 green, 0 blocked · fixture 46 and the two pure cores, reviewed and in
F1 fixture 46: RichText's nested spans and a page-state span; render pins 55 → 56 on both SDKs.
S-core / K-core: twin TextStyles and ProgressGeometry cores, 20 shared cases, same inputs.
G2 has begun: K-icon is in (Icon with src scales down only); S-rich, K-rich, K-prog are running.

### New for you
nothing new

### Trade-offs
2 auto-decided (minor): overflow falls back to the merged style's overflow, as Flutter's
text.dart:794 (a DTS style's overflow beats the DTS's own); a NaN or negative minHeight is 0.

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: groups 2-4 (RichText, DTS, progress, ImageIcon, resets). (default: go)

## Appendix

Cases: 4 rows split per SDK = 8 cells, plus the fixture half (F1), the cores' shared cases and the engine half
(D-rich); a row is ticked in phase-a-tests.md only when every half passes on both SDKs and the hand checks agree.
Rows A7.4 (Table) and the iOS half of A7.2 (SelectableText) wait on the user's answers to q1 and q2 of gate 08.

### Group 1
Commits: F1 738c1d2, K-core a4559d2, S-core 2f98f94 (staged by path). Nothing pushed. S-core and K-core reviewed together
(fit and quality, against Flutter and against each other): both went back once (a NaN minHeight gave 0 in Swift and
NaN in Kotlin; Swift's Arc lacked drawsArc; each side's tests lacked the other's inputs). F1 self-reviewed (a fixture
and three count pins). Group 1 approved under the standing rule.

#### Task F1 · Fixture 46 and render pins
Files: `schema/fixtures/render/46_rich_text_spans.json` (new) · `sdk-swift/.../ModelRoundTripTests.swift` ·
`sdk-kotlin/core/.../ModelRoundTripTest.kt` · `.../FixturePathsTest.kt`
Cases: A7.1 fx → green: the three pins red at 55 ≠ 56 first; engine `bun test` 823/0 (822 + the conformance case for
46); `flutter test test/conformance/` 280; Swift core 619/0; Kotlin core 637/0; 46's `resolved` runs unedited through
the Flutter, Swift and Kotlin resolver runners.
Changed: RichText "t": "Hello " bold #1E88E5, children "world" italic #43A047 nesting a page-state "name" span (#E53935,
underline), and "!" (V.static); center, maxLines 1, ellipsis; expected = encodeJsonTree (watches ["name"], the state
Value kept), cross-checked against flatten; resolved inner text "Ada". A corrupted copy failed the engine and Flutter
(and Swift's resolver runner on a wrong resolved text), then the file was restored byte-identical.
Decided: the engine runner never reads `resolved`, so its bite comes from corrupted `expected` props.

#### Task S-core / K-core · Twin TextStyles and ProgressGeometry cores
Files: `sdk-swift/Sources/OrcaGatewayCore/Render/{TextStyles,ProgressGeometry}.swift` (new) + tests (new) ·
`sdk-kotlin/core/.../render/{TextStyles,ProgressGeometry}.kt` (new) + tests (new)
Cases: A7.1-A7.3 core → green, the same 20 cases by name on both (11 TextStyles, 9 ProgressGeometry), red on stub
assertions first; `swift test` core 639, UI 531; Kotlin core 657.
Changed: TextStyles.merge (the child's set fields win; a styled child is upright unless italic, BH:103-105; "none"
clears, BH:141), spans (depth-first runs with merged styles; a non-object child its string; a missing text an empty
run; a missing root one empty run), layer (DTS layering, text.dart:723-796). ProgressGeometry: circularStroke (?? 3,
<= 0 → 3), circularRect (36 square, inset stroke/2), circularArc (indeterminate -0.5 / 4.5 rad; else -π/2, 2π·v;
drawsArc), trackColor (alpha replaced by 0x33), linearHeight (?? 4, not above 0 → 0), linearRadius, linearBar.
Rework (twin review): one linearHeight rule; Swift Arc fields startRad / sweepRad + drawsArc (red first); each side's
tests gained the other's inputs (all passed). layer() keeps a different shape per SDK (Swift a parsed Layer, Kotlin
raw props), same results.
Decided: overflow follows Flutter's text.dart:794 over the brief; a value Flutter's parser would drop still wins the
merge (malformed wire only; the engine's types allow valid values); a NaN bar is full (Dart's clamp).

### Group 2 (in progress)
#### Task K-icon · Kotlin ImageIcon on Icon's src path
Files: `sdk-kotlin/sdk/.../widgets/Icon.kt` · `.../widgets/ImageIconTest.kt` (new). Commit 1142ac9. Reviewed (fit and
quality): pass.
Cases: A7.4 kt (ImageIcon) → green, 7 a7_4_kt_*; red 3 of 7 (the image was enlarged), 4 pins passed before
(big image, tint, no colour, failed src); build with lint: sdk 766, core 657.
Changed: the src path draws on a Canvas, one dp per image pixel (NetworkImage scale 1.0), ContentScale.Inside
(never enlarged), centred, tinted SrcIn with color or LocalContentColor; empty while loading or failed.
Decided: the draw is inline in Icon.kt, not Image.kt's TiledImage (which rounds a source rect and crops; decision
kotlin-icon-src-inline-draw). The default colour is Kotlin's Icon default (LocalContentColor), Flutter's IconTheme is
0xDD000000 on both paths alike (pre-existing, follow-up).

### Test run
G1 (final files): engine 823/0 · Flutter conformance 280 · `swift test` UI 531, core 639 · Kotlin core 657, sdk 766
(with K-icon), lint clean.
