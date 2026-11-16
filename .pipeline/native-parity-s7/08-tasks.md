# 08 · Tasks · native-parity-s7

## Front page

### In one breath
tasks: 21 in 7 groups · widest group: 4 · cases: 4 of 4 placed
Plan step 7 on both SDKs: RichText, SelectableText, DefaultTextStyle, ImageIcon, Circular and
Linear progress, Table. G1 fixture 46 and the two pure cores. G2-G4 RichText, DTS, progress,
ImageIcon. G5 SelectableText on iOS, G6 Table: both wait on you. G7 caps 82 → 89, page rich.

### New for you
nothing new

### Trade-offs
q1-q2 are major and wait on you; their tasks come last (G5, G6), so an answer moves only them.
Indeterminate progress stands still, as Flutter's builder paints it (one fixed arc, D9).
Icon with src changes on both SDKs: never enlarged; iOS loses its name-glyph fallback (D8).
An unstyled RichText draws white 14, as Flutter's engine does; the demo shows it on a dark box.

### Questions for you
1. A7.4 Table: Flutter's one-column table, no wire change; columns as a later step. (default: a)
2. SelectableText on iOS: a read-only, selectable UITextView (word select, Copy). (default: a)
3. Commands as at baseline; Swift on macOS and the iOS scheme on DA7254F5. (default: as found)
4. One commit per task, one gate per group; nothing pushed before stage 10. (default: yes)
5. Hand checks on both devices after G7: selection, progress, table border, DTS. (default: yes)
6. Page rich lands in G7; its whole-page test commits after both caps. (default: yes)
7. DTS stops at D7's five hosts; SliverAppBar, Drawer, BottomNav later. (default: yes)
8. Rebase on main when PR #50 merges; pins recounted in a commit of their own. (default: yes)

## Appendix

### Where step 7 comes from
Plan /Users/amrebada/.claude/plans/native-parity/plan.md:102-108 (step 7, S, 7 widgets). Stages 05-07 skipped. Design in
force: .pipeline/native-parity-s7/design.md (D1-D13, rows A7.1-A7.4 after corrections); facts:
.pipeline/native-parity-s7/inventory.md. The design departs from the plan's hints in four places: `.textSelection` →
a UITextView (q2); ProgressView / M3 indicators → Flutter's static painters (OQ4); `Grid` and measured column widths →
a one-column table (q1); `ProvideTextStyle` → a CompositionLocal of its own (ProvideTextStyle merges, Flutter's DTS
replaces). Branch feat/native-parity-s7 on feat/native-parity-s6 (PR #50 open). No wire change (D1). Baseline = s6's
last run (no code changed since 4b3ed14): engine 822/0 · Flutter 544, analyze clean · `swift test` UI 531, core 619 ·
iOS scheme UI 682, core 619 · Kotlin core 637, sdk 759.

### Groups (paths from the repo root)
| # | G | Task | Title | Files | Cases | Size | Depends |
|---|---|---|---|---|---|---|---|
| 1 | 1 | F1 | Fixture 46 and render pins | schema/fixtures/render/46_rich_text_spans.json (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt | A7.1 fx (engine, Flutter, both resolver runners; render 55 → 56) | M | — |
| 2 | 1 | S-core | Swift text and progress cores | sdk-swift/Sources/OrcaGatewayCore/Render/TextStyles.swift (new) · …/Render/ProgressGeometry.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/TextStylesTests.swift (new) · …/ProgressGeometryTests.swift (new) | A7.1, A7.2 core sw (merge, spans, DTS layering); A7.3 core sw | M | — |
| 3 | 1 | K-core | Kotlin text and progress cores | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/TextStyles.kt (new) · …/render/ProgressGeometry.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/TextStylesTest.kt (new) · …/ProgressGeometryTest.kt (new) | A7.1-A7.3 core kt (same cases) | M | — |
| 4 | 2 | S-rich | Swift RichText runs on engine defaults | sdk-swift/Sources/OrcaGateway/Style/Props.swift · sdk-swift/Sources/OrcaGateway/Widgets/RichText.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/RichTextTests.swift (new) | A7.1 sw ui (runs on one line, 14/white root, no scaling, start, clip, maxLines, a state span redraws) | M | S-core |
| 5 | 2 | K-rich | Kotlin RichText runs on engine defaults | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/style/Props.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/RichText.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/RichTextTest.kt (new) | A7.1 kt ui (same) | M | K-core |
| 6 | 2 | K-prog | Kotlin Flutter progress painters | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Progress.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ProgressTest.kt (new) | A7.3 kt ui | S | K-core |
| 7 | 2 | K-icon | Kotlin ImageIcon on Icon's src path | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Icon.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ImageIconTest.kt (new) | A7.4 kt ui (ImageIcon) | S | — |
| 8 | 3 | S-dts | Swift DefaultTextStyle over Text | sdk-swift/Sources/OrcaGateway/Widgets/DefaultTextStyle.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Content.swift · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/DefaultTextStyleTests.swift (new) | A7.2 sw ui (replaces the ambient style, own fields win, RichText ignores it) | M | S-core, S-rich |
| 9 | 3 | S-lines | Swift span custom lines by range | sdk-swift/Sources/OrcaGateway/Widgets/TextKit.swift · sdk-swift/Sources/OrcaGateway/Widgets/RichText.swift · sdk-swift/Tests/OrcaGatewayTests/SpanLinesTests.swift (new) | A7.1 sw ui (lines by range, OQ7 a) | M | S-rich |
| 10 | 3 | K-dts | Kotlin DefaultTextStyle over Text | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/DefaultTextStyle.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Content.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/DefaultTextStyleTest.kt (new) | A7.2 kt ui (same) | M | K-core, K-rich |
| 11 | 3 | K-lines | Kotlin span custom lines by range | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/TextDecorations.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/RichText.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/SpanLinesTest.kt (new) | A7.1 kt ui (lines by range) | M | K-rich |
| 12 | 4 | S-media | Swift ImageIcon and progress painters | sdk-swift/Sources/OrcaGateway/Widgets/Media.swift · sdk-swift/Sources/OrcaGateway/Widgets/Progress.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/ImageIconTests.swift (new) · sdk-swift/Tests/OrcaGatewayTests/ProgressTests.swift (new) | A7.3 sw ui; A7.4 sw ui (ImageIcon) | M | S-core |
| 13 | 4 | S-reset | Swift Material hosts reset the DTS | sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Sources/OrcaGateway/Widgets/Buttons.swift · sdk-swift/Sources/OrcaGateway/Widgets/Stack.swift · sdk-swift/Tests/OrcaGatewayTests/TextStyleResetTests.swift (new) | A7.2 sw ui (stops at Card, InkWell, buttons, Scaffold body, AppBar title) | M | S-dts |
| 14 | 4 | K-reset | Kotlin Material hosts reset the DTS | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Structure.kt · …/widgets/Buttons.kt · …/widgets/Gesture.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/TextStyleResetTest.kt (new) | A7.2 kt ui (same) | M | K-dts |
| 15 | 4 | K-select | Kotlin SelectableText in SelectionContainer | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/SelectableText.kt (new) · …/widgets/Content.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/SelectableTextTest.kt (new) | A7.2 kt ui (selects, DTS merge, maxLines scrolls) | M | K-dts |
| 16 | 5 | S-select | Swift SelectableText, read-only UITextView (q2) | sdk-swift/Sources/OrcaGateway/Widgets/SelectableText.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/TextKit.swift · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/SelectableTextTests.swift (new) | A7.2 sw ui (word and range selection, Copy, DTS merge) | M | S-dts |
| 17 | 6 | S-table | Swift one-column Table with border (q1) | sdk-swift/Sources/OrcaGateway/Widgets/Table.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/TableTests.swift (new) | A7.4 sw ui (Table, as corrected) | M | — |
| 18 | 6 | K-table | Kotlin one-column Table with border (q1) | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Table.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/TableTest.kt (new) | A7.4 kt ui (Table, as corrected) | S | — |
| 19 | 7 | S-caps | Swift advertises the seven | sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift · sdk-swift/README.md | A7.x caps sw (89; the switch draws each) | M | all S tasks |
| 20 | 7 | K-caps | Kotlin registers and advertises the seven | sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt · sdk-kotlin/README.md | A7.x caps kt (89; standard() == vector) | M | all K tasks |
| 21 | 7 | D-rich | Demo page rich on parity-a | examples/server/parity-a.ts · examples/server/index.ts · engine/test/parity-a-rich.test.ts (new) | A7.x eng (page whole on both vectors); A7.1-A7.4 hand | M | — (its test commits after S-caps and K-caps) |

### Where each case is placed
- A7.1: F1 (fixture); S-core, K-core (merge, upright reset, "none", spans); S-rich, K-rich (ui); S-lines, K-lines
  (custom lines by range); hand.
- A7.2: S-core, K-core (DTS layering); S-dts, K-dts; S-reset, K-reset (where a DTS stops); K-select, S-select; hand.
- A7.3: S-core, K-core (geometry); K-prog, S-media (painters); hand.
- A7.4: K-icon, S-media (ImageIcon); S-table, K-table (Table as corrected, q1); hand.
- Beside the rows: A7.x caps in S-caps, K-caps; A7.x eng in D-rich. Test names `testA7_N…` (Swift) and `a7_N_…`
  (Kotlin); the cores' shared cases carry the same names on both SDKs.

### Order, and why each boundary; expected reds
G1
- F1 writes 46 per D1 and inventory §2 in the shape of 40_text_style_polish.json: `expected` from encodeJsonTree and
  cross-checked against flatten; watches ["name"]; "!" plain; `resolved` t.text.children[0].children[0].text "Ada";
  numbers the same JSON on every side. Moves ModelRoundTripTests.swift:10 and ModelRoundTripTest.kt:32 ("01-46, 60-69")
  and FixturePathsTest.kt:13 to 56. Red first: the three pins at 55 ≠ 56; a corrupted copy of 46 must fail both the
  engine and Flutter runners, then the file is regenerated byte-identical. Runs engine `bun test`, `flutter test
  test/conformance/`, the Swift core suite and the Kotlin core suite.
- S-core and K-core, red first on stubs, the same case names on both SDKs.
  TextStyles (D4): merge, the child's set fields win; a child with a style sets fontStyle, normal unless "italic"
  (BH:103-105); "none" clears a line (BH:141); spans(root) runs in order, a non-object child its string (PB:344), a
  missing `text` an empty run (:332); DTS layering (text.dart:723-772): textAlign own ?? DTS ?? start, maxLines own ??
  DTS, overflow own ?? style.overflow ?? DTS ?? clip.
  ProgressGeometry (D9): Circular 36 square unless constrained, strokeWidth ?? 3 (<= 0 → 3), rect inset stroke / 2;
  null or NaN → start -0.5 rad sweep 4.5 rad; value clamped; track alpha 0x33; arc from -π/2 over 2π·v, none at 0.
  Linear height minHeight ?? 4, radius h / 2, bar w·clamp(v) from the left, RTL too. Colours #2196F3, #E0E0E0.
- Red at the gate: none.
G1 → G2: the rich tasks call merge and spans, K-prog calls ProgressGeometry; K-icon needs nothing (free Kotlin slot).
- S-rich: TextStyleProps (Props.swift:201-272; today .body 17 at :244-255) gains the engine base (14, white,
  regular), an explicit upright and decoration none. RichText.swift draws the runs as one Text through OneLineLayout,
  LineCutLayout, FadeMask (TextKit.swift:154, :171, :188); start, softWrap and clip unless sent; maxLines; fixed sizes
  (no Dynamic Type). Background, solid underline and line-through per run (Props.swift:266-269). NodeView gets
  "RichText". Tests: ImageRenderer sizes and pixels (a white root on a dark box, three colours on one line, the italic
  reset, a cleared underline); a hosted page where SetState("name") redraws the inner run (TouchTests.swift:152-156).
- K-rich: TextStyleProps (Props.kt:284-360; fontStyle null unless italic :353; decoration null for none :341-346)
  gains a SpanStyle with explicit Normal and None. RichText.kt draws an AnnotatedString of SpanStyles through the Text
  path on TextStyle(14 sp at fontScale 1, White): start, clip, maxLines. Robolectric with a test-local builder: text
  semantics, pixel colour per run, fontScale 2 changes nothing.
- K-prog: a Canvas as Controls.kt:373: drawArc start -28.648°, sweep 257.831°, Stroke(cap Round); 36 dp unless
  constrained; Linear fills the width, clipped round. Tests: bounds 36 x 36 and 4 dp; pixels of the 0x33 track, the
  arc, the 40 % bar.
- K-icon: the src path (Icon.kt:45-52) through TiledImage (Image.kt:133) with ContentScale.Inside (:218), centred,
  tinted SrcIn (:119); empty box while loading or after a failure; KDoc :29-33 rewritten. MockWebServer as
  ImageTest.kt:58: a small image keeps its size, a big one fits, the tint.
- Red: none.
G2 → G3: DTS lays its style on the engine base the rich tasks added; the lines tasks extend RichText.
- S-dts: an environment value (style, textAlign, maxLines, overflow ?? clip, LB:588-601); DefaultTextStyle.swift
  sets it around ChildView; TextNodeView (Content.swift:13-96) merges the DTS with its own style through TextStyles
  on the engine base; without a DTS it draws as today. NodeView gets "DefaultTextStyle". Tests: an unstyled Text under
  DTS {fontWeight bold} draws white, 14, bold; the Text's own size, colour, textAlign and maxLines win; a RichText under
  the DTS is unchanged.
- S-lines: DecorationRenderer (TextKit.swift:91-133, whole text today) draws overline, double, wavy, dotted, dashed and
  decorationColor under each run's range only, on iOS 18 / macOS 15; below 18 a run keeps SwiftUI's solid line
  (documented). Tests: the pixel rows under one run show the line, the neighbouring run is clean.
- K-dts: a CompositionLocal of its own (ProvideTextStyle merges, OrcaPageView.kt:75); TextWidget (Content.kt:64-112,
  merge at :67) bases on the engine defaults under a DTS and on LocalTextStyle without one. Tests as Swift's.
- K-lines: decorationLines (TextDecorations.kt:81-117) takes a range per span; RichText.kt hands each run's lines.
  Tests as Swift's.
- Red: none.
G3 → G4: the resets and K-select read the DTS value; S-media takes the NodeView lane (needs only S-core).
- S-media: IconNodeView (Media.swift:12-38) draws src through ImageFit.scaleDown (:147) in the size box, centred,
  template-tinted; no glyph fallback while src is set (:26-32); an `image:` hook for tests (as ImageTests.swift:168).
  Progress.swift: a Canvas from ProgressGeometry (SwiftUI's `clockwise` is flipped). NodeView: "ImageIcon" →
  IconNodeView, both progress types.
- S-reset clears the DTS value at Card (Structure.swift:461), the Scaffold body (:46-47), the AppBar titles (:312,
  :413, :422), Buttons (Buttons.swift:22), IconButton (:394), FAB (:489), InkWell (Stack.swift:247). Tests: a DTS (red,
  30) over a Card, a button and an InkWell: each Text inside draws as with no DTS.
- K-reset clears it at CardWidget (Structure.kt:394), ScaffoldWidget (:134), AppBarWidget (:306), ButtonWidget
  (Buttons.kt:100), IconButton (:319), FAB (:380), InkWellWidget (Gesture.kt:101).
- K-select: a SelectionContainer around the Text path (Content.kt) with D6's style, textAlign and maxLines; past
  maxLines a box of that many lines that scrolls, no ellipsis. Tests: selection semantics, a long press selects a word,
  the DTS merge.
- Red: none.
G4 → G5: the NodeView lane; S-select reads the DTS value; G5 holds S-select alone because q2 reshapes only it.
- S-select: a UITextView, not editable, selectable, no insets or line padding, no scroll until maxLines; it takes the
  attributed text JustifiedText builds (TextKit.swift:239-273, made shared) and keeps the 3 px caret margin. On macOS a
  Text with `.textSelection(.enabled)`. NodeView gets "SelectableText". Tests on the iOS scheme, hosted: a UITextView,
  not editable, selectable; its attributes; a selectedRange over a word; its size. Long press, handles and Copy by hand.
- Red: none.
G5 → G6: the lane; Table last, waiting on q1. If the answer is (b), engine, registry, Flutter and fixture tasks are
inserted before G6.
- S-table (D10): children stacked, each proposed the table's width (orcaTight, Flex.swift:51), top-aligned;
  unbounded → the widest child's ideal width; the border drawn over the cells, outer lines inside the rect, row lines
  centred on the boundaries; colour ?? black, width ?? 1, parsed as Box.swift:88-103. NodeView gets "Table".
- K-table: a Layout with fixed-width constraints; lines drawn after the children (Decoration.kt:84-85, :147-148).
- Tests on both: row frames, border pixels, columnWidths sent changes nothing.
- Red: none.
G6 → G7: the vectors list what both SDKs draw.
- S-caps: the seven into capabilities.json, sorted; `bun run schema/gen-native-capabilities.ts` once;
  CapabilitiesTests.swift:43-55 and StructureWidgetTests.swift:256-267 to 89, plus a `testA7_x` check; the
  switch-draws check (:279) passes; README.md:4 → 89.
- K-caps: standard() (WidgetBuilders.kt:159-246, KDoc :140) registers the seven (ImageIcon → IconWidget); c1
  (CapabilitiesTest.kt:83-117, renamed for 89) and :135 to 89, plus an `a7_x_` check; README.md:5 and :91 → 89;
  WidgetBuildersTest.kt:15-22 needs no edit.
- D-rich: page `rich` per D11 after formsPage (parity-a.ts:1437-1574), its route after :1587, the header (:84-88)
  drops "rich", its URL after index.ts:118; the test a copy of parity-a-forms.test.ts (WIDGETS :12-22, PAGE :23); the
  test commits last in the group (q6).
- Kotlin's c1 compares against Swift's list (CapabilitiesTest.kt:89-91), so it is red between the two caps commits,
  as in s6. Green at the gate. The hand checks follow.

### Seams
- NodeView.swift: S-rich (G2), S-dts (G3), S-media (G4), S-select (G5), S-table (G6); S-caps never touches it.
- TextKit.swift: S-lines (G3), then S-select (G5). RichText.swift / RichText.kt: the rich tasks (G2), then the lines
  tasks (G3). Content.kt: K-dts (G3), then K-select (G4).
- One task each: Props.swift and Props.kt (S-rich, K-rich); Content.swift (S-dts); Media.swift (S-media); Icon.kt
  (K-icon); Structure, Buttons, Stack.swift and Gesture.kt (the reset tasks).
- Pins: the render count is F1's alone; widget counts, READMEs and Generated files belong to the caps tasks alone; one
  generator run writes both Generated files, each caps task stages its own, the last one reruns it and sees no diff.
- Engine lane: F1 (G1) and D-rich (G7); parity-a.ts and index.ts belong to D-rich alone.
- Goldens: none move; a golden that moves stops the task.

### Risks (checked against the code on 6b8e365)
1. Rebase: when PR #50 merges, recount the render pins (ModelRoundTripTests.swift:10, ModelRoundTripTest.kt:32,
   FixturePathsTest.kt:13) and the widget pins in a commit of their own (in s6 both sides had moved one pin and the
   rebase kept one, 4b3ed14). Renumber 46 if main has taken it.
2. The seven are unregistered until G7: Swift tests widen the registry (CheckboxRadioTests.swift:332) or build the view
   directly; Kotlin builders stay test-local (standard() must equal the vector, WidgetBuildersTest.kt:15-22).
3. iOS 16 floor: DecorationRenderer is iOS 18 / macOS 15 only (TextKit.swift:91-92); below 18 a run's custom lines fall
   back to SwiftUI's solid line.
4. Text must not change without a DTS: the .body 17 base (Props.swift:244-255) and bodyMedium (Content.kt:67,
   OrcaPageView.kt:75) stay; TextStyleTests.swift and TextTest.kt guard it.
5. Kotlin hosts merge LocalTextStyle (Buttons.kt:224, :496; Slivers.kt:460; TabShellScreen.kt:500), so the DTS needs
   a local of its own. SliverAppBar, Drawer and BottomNavigationBar do not reset it (q7).
6. The shared Icon src path changes (Media.swift:18-32, Icon.kt:45-52); no test pins the old enlarging or the glyph
   fallback (searched).
7. iOS selection: UITextView exists only in UIKit, so macOS `swift test` builds the fallback; the gestures are checked
   by hand. s6's iOS InkWell took three hand-check reworks: expect rounds here too.
8. Kotlin text scaling: sp follows fontScale, RichText must not scale (D5); tested at fontScale 2.
9. CPI is already in fixtures (18_sub_page.json:19, :58; subpage/03_merge_state_refs.json:84, :360): after G7 the
   natives draw Flutter's arc there; the SDKs' own spinners stay (SubPage.swift:92, SubPage.kt:71, OrcaBoot.kt:179,
   OrcaApp.kt:1086).
10. Pixel tests: sample inside strokes, away from caps and antialiased edges.
11. Build contention: one SwiftPM or Gradle build per worktree at a time (the .build lock); at most 4 tasks per group.

### Hand checks (after G7, page `rich`, iPhone 16 Pro DA7254F5 and Android API 34, against Flutter)
A7.1 nested spans, the state span changing, the white root. A7.2 long press and double tap select a word; handles;
Copy; the DTS look and that it stops at a Card and a button. A7.3 both indicators, indeterminate and at 0.4, default
and coloured. A7.4 the table's rows and border; ImageIcon sizes, tint and scaleDown.

### Done when
Suites: engine `bun test`; `flutter test`, `flutter analyze`; `swift test` and the iOS scheme on DA7254F5; Kotlin
`./gradlew cleanTest :sdk:cleanTestDebugUnitTest build --no-build-cache`. gen-widget-registry, gen-native-capabilities
and gen-sdk-capabilities leave no diff; no golden moved; examples/app-ios and examples/app-android build. One commit per
task, staged by path; one gate per group; hand checks after G7; a row ticked only when both SDKs match Flutter.

### Not planned (on purpose)
Table rows, column widths and cell alignment on the wire (q1 b) unless you pick it; `.textSelection` on iOS (q2 b).
Props Flutter never reads: Table columnWidths and defaultColumnWidth (LB:646-666), the CPI `size` (not an engine prop);
progress animation (Flutter's is static). DTS resets at SliverAppBar, Drawer and BottomNavigationBar (follow-up, q7);
per-run overline, double and wavy on iOS 16-17. No engine class, registry, target or Flutter change (D2), so the cloud's
Go registry has nothing to regenerate. No action fixture (D1). engine/CHANGELOG.md is written at release.
