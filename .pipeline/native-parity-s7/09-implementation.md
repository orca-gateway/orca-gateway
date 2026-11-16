# 09 · Implementation · native-parity-s7

## Front page

### In one breath
groups 2-3 of 7 · tasks: 8 green, 0 blocked · RichText, DTS, span lines, progress, ImageIcon
RichText draws its spans on Flutter's engine base (14, white, no text scaling) on both SDKs.
DefaultTextStyle replaces the ambient style; a span's custom lines are drawn by range, as Skia.
Group 4 half in (Swift ImageIcon, progress, Material resets); K-reset, K-select, S-select running.

### New for you
nothing new

### Trade-offs
5 auto-decided (minor): IconButton passes a DTS through (Flutter's builder has no Material);
a justified RichText on iOS; an overline centred on the run's top edge (native SkParagraph);
Swift Text under a DTS draws a fixed 14 where Flutter scales (known difference);
an Icon src also loads file://, and a null src draws the glyph (known differences).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 4, then 5 (iOS SelectableText, q2 a) and 6 (Table, q1 a). (default: go)

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

### Group 2
Commits: K-icon 1142ac9, K-prog 72ab86a, S-rich 041ee5e, K-rich 5908877. Each reviewed (fit and quality in one pass);
K-rich went back once (the engine base made visible to K-dts, word spacing per run as Swift, a KDoc line on height).
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

#### Task K-prog · Kotlin progress painters
Files: `sdk-kotlin/sdk/.../widgets/Progress.kt` (new) · `.../ProgressTest.kt` (new). Commit 72ab86a. Review: pass.
Cases: A7.3 kt → green, 8 a7_3_kt_* (36 square, Linear minHeight across its parent, determinate track then the arc
from twelve, indeterminate one static arc and no track, forced non-square → ellipse, 40 % bar, bare track, colours and
sizes, RTL bar from the left); red 8/8 on an empty stub; build sdk 783, core 657, lint.
Changed: one Canvas each, every number from ProgressGeometry; drawArc in degrees; track butt cap, arc round cap.
Decided: no `size` prop (the engine has none); a Linear under unbounded width is 0 wide, Flutter throws (known).

#### Task S-rich · Swift RichText
Files: `sdk-swift/.../Style/Props.swift` · `.../Widgets/RichText.swift` (new) · `NodeView.swift` · `RichTextTests.swift`
(new). Commit 041ee5e. Review: pass.
Cases: A7.1 sw → green, 8 testA7_1* (white 14 root, three colours on one line, spacing and background, upright child,
none clears, maxLines clip / ellipsis, Dynamic Type and the ambient style change nothing, a page-state span redraws on
the iOS scheme); `swift test` UI 538, iOS 690.
Changed: a TextStyleProps extension (engineSize 14, engineColor white, engineFont fixed, engineRun) builds one
AttributedString of runs; Text untouched. Decided: no new upright / none fields (the core writes them); a span's height
is not drawn (no per-run line box in SwiftUI; known difference).

#### Task K-rich · Kotlin RichText
Files: `sdk-kotlin/sdk/.../style/Props.kt` · `.../widgets/RichText.kt` (new) · `RichTextTest.kt` (new). Commit 5908877.
Cases: A7.1 kt → green, 10 a7_1_kt_* (the Swift cases plus fade and word spacing); build sdk 784, core 657, lint.
Changed: ENGINE_TEXT_STYLE (14 sp, white, regular, upright) in Props.kt; spanStyle() with explicit Normal and None; an
AnnotatedString on the root span's style over the base, fontScale 1, LocalTextStyle ignored; fade as Text; a span's
wordSpacing on its spaces. Decided: the root's height applies to every line (Compose: per paragraph), a span's own
height is not drawn. A stuck wait script (a grep matching itself) cost an hour; scripts that poll `ps` are banned.

### Group 3
Commits: S-dts 6e4d84d, S-lines e4a7bf9, K-dts 6dd7294, K-lines f25e758. Each reviewed; S-lines went back once (dead
code, the overline position, the engine base reused). The overline position was checked against Skia's
Decorations.cpp (decision overline-position): centred on the run's top edge.

#### Task S-dts / K-dts · DefaultTextStyle over Text
Files: `DefaultTextStyle.swift` / `.kt` (new) · `Content.swift` / `.kt` · `NodeView.swift` · tests (new).
Cases: A7.2 → green, the same 7 cases on both (white 14 bold under DTS {bold}; own size, colour, align, maxLines win;
DTS center; DTS maxLines 1 + ellipsis; a nested DTS replaces; RichText unchanged; no DTS unchanged), Swift + 1 iOS
justify; `swift test` UI 545, iOS 698; Kotlin sdk 795.
Changed: an environment value / CompositionLocal of the DTS layer, replacing any outer one; Text lays its own fields
over it through TextStyles.layer on the engine base; without a DTS the old path. Decided: Kotlin keeps the font scale
under a DTS (Flutter, text.dart:753-758); Swift draws a fixed 14 there (its sent-size rule; known difference).

#### Task S-lines / K-lines · a span's custom lines by range
Files: `TextKit.swift` / `TextDecorations.kt` · `RichText.swift` / `.kt` · `SpanLinesTests.swift` / `SpanLinesTest.kt`.
Cases: A7.1 lines → green, the same 4 cases (overline straddles its own run's top only; double two rows under its run
only; wavy in decorationColor under its run only; none clears the parent's line for its run only), Swift + 1 iOS
justify; `swift test` UI 571, iOS 727; Kotlin sdk 795.
Changed: Swift RunLinesRenderer (iOS 18 / macOS 15; solid lines below) and JustifiedText(runs:); Kotlin a range form of
decorationLines from getPathForRange. Text's whole-text path unchanged on both. Decided (decision rich-justify-ios):
a justified RichText on iOS; Kotlin's run lines clip only on overflow (Flutter), Swift's maxLines path always clips.
Follow-ups: Text's renderers differ from Skia in small ways (wave end, metrics, Kotlin overline half a stroke low).

### Group 4 (in progress)
S-media 3858948 (ImageIcon scaleDown at scale 1, empty while loading; both progress painters; review went back once:
a copied test helper, circular corners, a stronger failed-load check) and S-reset c11c941 (Scaffold, AppBar, Card, the
buttons, FAB, InkWell reset the DTS; IconButton passes it, as Flutter's builder has no Material; review: pass) are in.
K-reset and K-select are running; G5's S-select started early (the Swift lane was free).

### Test run
G1 (final files): engine 823/0 · Flutter conformance 280 · `swift test` UI 531, core 639 · Kotlin core 657, sdk 766
(with K-icon), lint clean.
G2-G3 (each task's final files): `swift test` UI 571, core 639; iOS scheme UI 727, core 639 · Kotlin sdk 795,
core 657, lint clean. A full run of the whole tree comes at the end of group 4.
