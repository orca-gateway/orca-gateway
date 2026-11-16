# 09 · Implementation · native-parity-s7

## Front page

### In one breath
groups 4-7 of 7 · tasks: 21 of 21 green, 0 blocked · step 7 done on both SDKs
SelectableText selects words and ranges and copies (UITextView on iOS); Material hosts reset a DTS.
Table draws Flutter's one-cell rows with TableBorder.all; both SDKs advertise 89 widgets, one hash.
Rebased on main 3880607; every suite green; hand checks pass on the iPhone and Android.

### New for you
nothing new

### Trade-offs
3 auto-decided (minor): a Table under unbounded width is 0 wide, as Flutter (D10 corrected);
an ImageIcon src also loads file:// and a null src draws the glyph (known differences);
Android: past the end of a maxLines box the drag scrolls the page (Compose; follow-up).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: tick A7.1-A7.4 and open the step 7 PR, stacked on PR #50. (default: go)

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

### Group 4
Commits: S-media cb4862f0, S-reset ccae0673, K-reset 580c5157, K-select ace94795 (hashes after the rebase on main
3880607). Each reviewed (fit and quality in one pass); S-media went back once (a copied test helper, the circular
corners, a stronger failed-load check). K-dts's `./gradlew --stop` killed a parallel build once; briefs now stop
daemons only at the very end.

#### Task S-media · Swift ImageIcon and progress painters
Files: `Media.swift` · `Progress.swift` (new) · `NodeView.swift` · `ImageIconTests.swift` (new) · `ProgressTests.swift`
(new). Cases: A7.3 sw and A7.4 sw (ImageIcon) → green, 9 testA7_3* and 8 testA7_4* (36 square and minHeight bar,
track then arc from twelve, one static indeterminate arc, ellipse in a forced box, 40 % bar, bare track, colours, RTL
from the left, nothing moves in a window; small image kept centred, big one shrunk, tint on opaque pixels only, the
foreground tint, size 24, empty while loading, an Icon with src is ImageIcon).
Changed: IconNodeView's src path is scaleDown at one point per image pixel, centred, srcIn; loading or failed draws
the empty square (no name glyph). Both indicators draw on a Canvas from ProgressGeometry.

#### Task S-reset / K-reset · the Material hosts reset the DTS
Files: `Structure` · `Buttons` · `Stack.swift` / `Gesture.kt` · `TextStyleResetTest(s)` (new).
Cases: A7.2 reset → green, the same 7 on both (Card, the three buttons, FAB, InkWell, AppBar title and actions,
Scaffold body reset; IconButton passes it through). Changed: each host draws its content under an empty DTS layer,
as Flutter's Material (MUI material.dart:470-474). Decided: IconButton passes it (Flutter's builder has no Material).
Follow-ups: Drawer, SliverAppBar (q7).

#### Task K-select · Kotlin SelectableText
Files: `SelectableText.kt` (new) · `Content.kt` (drawnStyle, lineLimit, DrawnText shared with Text; `layer` → `dts`) ·
`SelectableTextTest.kt` (new). Cases: A7.2 kt select → green, 6 a7_2_kt_* (a focusable SelectionContainer, a long
press selects a word, white 14 bold under a DTS, own fields win, maxLines 2 a two-line box that scrolls, maxLines 1
one line that scrolls sideways). Changed: Text's draw path inside a SelectionContainer in a scrolling box n lines
tall (minLines ?? maxLines, as Flutter), the 3 dp caret margin.

### Group 5
Commit: S-select bca709d9 (started early in group 4, the Swift lane was free). Reviewed; went back once (a redraw
dropped the selection: updateUIView now keeps selectedRange while the string is unchanged, red first).
#### Task S-select · Swift SelectableText (q2 a)
Files: `SelectableText.swift` (new) · `TextKit.swift` (attributed(_:paragraph:font:), platformFont(at:)) ·
`NodeView.swift` · `SelectableTextTests.swift` (new). Cases: A7.2 sw select → green, 7 testA7_2Selectable* (a
read-only selectable UITextView with the caret margin; styled as a Text without a DTS; white 14 bold under one, own
fields win; a word and a range selected and copied in a hosted window; maxLines 2 two lines tall, scrolls, no
ellipsis; keeps its selection while its data is unchanged; macOS draws a Text's pixels with .textSelection).
Changed: iOS draws a non-editable, selectable UITextView fed the same attributed text as Text (LineTextView sizes it to
n lines); macOS keeps Text with `.textSelection(.enabled)`.

### Group 6
Commits: K-table cf66e654, S-table bb42f155. Reviewed: pass. K-table found Flutter's unbounded-width case: 0 wide
(FlexColumnWidth.maxIntrinsicWidth is 0, rendering/table.dart:212-214, :1123-1129); D10 corrected, decision
table-unbounded-width.
#### Task S-table / K-table · one-column Table with border (q1 a)
Files: `Table.swift` / `.kt` (new) · `NodeView.swift` · `TableTest(s)` (new). Cases: A7.4 table → green, the same 6
on both (each child a full-width row at its own height; outer lines inside, row lines centred over the cells; an empty
border black and 1 wide; no border no lines; columnWidths and defaultColumnWidth change nothing; unbounded width 0).
Follow-ups: the 0-width hairline is untested; Swift repeats TightForLayout.limits.

### Group 7
Commits: D-rich b7afb069, K-caps 3eacf2c6, S-caps f3a39002, the engine test 67f74a8f. Reviewed: pass. The D-rich
review found an engine bug for the user: ImageIcon is not exported from the engine barrels (follow-up, own PR).
#### Task S-caps / K-caps · advertise the seven
Files: both `capabilities.json` (82 → 89, sorted) · `Generated.swift` / `.kt` (one gen-native-capabilities run) ·
`CapabilitiesTest(s)` · `StructureWidgetTests.swift` · `WidgetBuilders.kt` (seven registered; ImageIcon → IconWidget) ·
both READMEs · the DefaultTextStyle doc names its resets. Cases: A7.x caps → green on both (89, the same list and
caps hash 8d06076b…; Kotlin standard() equals the vector; the Swift switch draws each).
#### Task D-rich · demo page rich
Files: `examples/server/parity-a.ts` (page `rich`) · `index.ts` · `engine/test/parity-a-rich.test.ts` (new). Cases:
A7.x eng → green after the caps tasks (the page holds all seven; each native vector gets it whole, no FallbackPrompt or
caps banner); red before them.

### Rebase
On main 3880607 (PR #49, the video player packages): clean, no conflicts. Refs backup/native-parity-s7-pre-rebase-388,
-s6base-388 (90f88e13, step 6's tip inside this branch), -post-rebase-388.

### Test run (rebased head, before the pipeline commit)
engine `bun test` 832 pass · Flutter 545 pass, analyze clean · `swift test` UI 578, core 640 · iOS scheme on DA7254F5
UI 739, core 640 · Kotlin `./gradlew cleanTest :sdk:cleanTestDebugUnitTest build --no-build-cache` core 658, sdk 814,
lint clean · app-ios and app-android build · the three generators leave no diff · no golden moved in step 7.

### Hand checks (page `rich`, iPhone 16 Pro simulator and Android API 34 emulator)
A7.1 spans, lines by run, "name = Grace" changes only its span, the white root: pass on both. A7.2 a long press
selects a word, the handle widens it, Copy then Paste gives the same text (iOS "press or double t", Android "or double
tap"); the maxLines 2 box scrolls; the DTS look, its yield to an own colour, RichText ignoring it, Card and button
reset, IconButton "Aa" red: pass on both. A7.3 both indicators static, as Flutter: pass. A7.4 Table rows and border,
ImageIcon sizes, tint and scaleDown: pass. Notes in the scratchpad s7/hand-checks.md.
