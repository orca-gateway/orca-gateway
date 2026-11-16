# Step 7 inventory (RichText, SelectableText, DefaultTextStyle, ImageIcon, Circular/LinearProgressIndicator, Table)
# Checked 2026-11-16 on feat/native-parity-s7 6b8e365 (s6 on main d82ed11); replaces the 2026-11-15 draft. Both SDKs:
# 82 widgets, 26 action kinds (89 after); render fixtures 55 (01-45, 60-69), next 46_; action fixtures 32 (none needed).
PB, LB, SB = sdk/lib/src/builders/{primitive,layout,structure}_builders.dart, BH = …/builder_helpers.dart.
FW = ~/flutter/packages/flutter/lib/src, MUI = ~/.pub-cache/hosted/pub.dev/material_ui-1.11.0/lib/src (re-exports
flutter/widgets), ENG = ~/flutter/engine/src/flutter, SW = sdk-swift/Sources/OrcaGateway, KT = sdk-kotlin/sdk/src/main/
kotlin/com/orcagateway/sdk.

## 1. Engine classes (private ctor + static new, getProps() = {...props}, props Valueable, no defaults, triggers [])
| RichText primitive/rich-text.ts:6-38 | text (required) {text?, style?, children?} (:6-10); textAlign, maxLines, overflow |
| SelectableText primitive/selectable-text.ts:6-32 | data (required), style, textAlign, maxLines; no overflow |
| DefaultTextStyle layout/default-text-style.ts:6-34, single child | style (required), textAlign, maxLines, overflow |
| ImageIcon primitive/image-icon.ts:5-30 | src (required), size, color |
| CircularProgressIndicator primitive/circular-progress-indicator.ts:5-30 | color, strokeWidth, value. No size |
| LinearProgressIndicator primitive/linear-progress-indicator.ts:5-31 | value, color, backgroundColor, minHeight |
| Table layout/table.ts:5-32, multi child | columnWidths Record<number,number>, defaultColumnWidth, border {color?, width?} |
Registry widget-registry-gen.ts CPI :45, DTS :55, ImageIcon :74, LPI :80, RichText :91, SelectableText :97, Table :110;
all four targets (widget-registry.json :890, :1265, :2150, :2360, :2850, :3107, :3696), so widget-targets.test.ts:19
IOS_ORPHANS stays. Dart caps generated.dart:40,50,69,75,86,92,105; in no native capabilities.json; no per-widget schema.

## 2. Wire
- TextStyleData helpers/text-style.ts:6-20, all Valueable but `overflow`. Table columnWidths goes out as an object with
  string keys "0", "1" … and bare numbers (fixed or flex is undefined).
- Watches walk props deep (types/widget.ts:156-178, json-tree-encoder.ts:192-220): a state Value in any span adds its
  key to the RichText node. Server resolveDeep (core/value-resolver.ts:338-363) makes state-free Values plain and fills
  "{{…}}"; state Values stay. Clients resolve deep: Flutter component_context.dart:67-78, Swift Core Render/
  PageRenderer.swift:182, Kotlin core render/PageRenderer.kt:204.
- A7.1 fixture 46_rich_text_spans.json (shape of 40_text_style_polish.json): RichText t, text {text "Hello ", style
  {fontWeight bold, color #1E88E5}, children [{text "world", style {fontStyle italic, color #43A047}, children [{text
  V.pageState("name"), style {color #E53935, decoration underline}}]}, {text V.static("!")}]}, textAlign center,
  maxLines 1, overflow ellipsis → watches ["name"], "!" plain, resolved t.text.children[0].children[0].text "Ada".

## 3. Flutter builders (registered PB:12-28, LB:71,76)
- RichText PB:325-348: raw RichText, not Text.rich: no DefaultTextStyle, no text scaling (FW widgets/basic.dart:
  6522-6544: start, softWrap true, clip, TextScaler.noScaling). Span text via resolveStringValue ('' if absent,
  BH:436-447), a non-Map child is TextSpan('$c') (PB:344), no `text` an empty span (:332). Root fields left unset are
  the engine's: 14 px (FW painting/text_painter.dart:42) and WHITE (ENG txt/src/txt/text_style.h:26,41). A child span
  starts from its parent's style (ENG lib/ui/text/paragraph_builder.cc:396 PeekStyle), but parseTextStyle always sets
  fontStyle (BH:103-105): a styled child is upright under an italic parent; "none" clears a line (BH:141).
- SelectableText PB:350-362 → MUI SelectableText, a read-only EditableText (selectable_text.dart:767-799): style =
  DTS.style.merge(own) (:753-758), textAlign own ?? DTS ?? start (:779), maxLines own ?? DTS (:785; past it the text
  scrolls, no ellipsis), width = text + 3 px caret margin (forceLine false :783), MediaQuery scaling. Long press or
  double tap selects a word, handles, toolbar (cupertino on iOS); selection primary at 0.40 (:705-750); no cursor.
- DefaultTextStyle LB:588-601: the REPLACING ctor (FW widgets/text.dart:63), not .merge (:111): the ambient M3
  bodyMedium is dropped, so under a DTS without color or fontSize a Text draws white 14 (Text merges DTS.style with
  its own, text.dart:723-728). overflow ?? clip (LB:598). A Text's own style fields win and any own style resets
  italic (BH:103); own textAlign ?? DTS (text.dart:764), overflow own ?? style.overflow ?? DTS (:770), maxLines (:772).
  SelectableText takes it, RichText ignores it. Every Material resets it to textStyle ?? bodyMedium (MUI
  material.dart:470-474): Card (SB:141-143), InkWell (LB:620), Scaffold, buttons; AppBar styles its own title.
- ImageIcon PB:386-396 = Icon with src (PB:104-111). FW widgets/image_icon.dart:91-119: Image(size x size, size ?? 24,
  fit scaleDown: never enlarges, centred; color ?? IconTheme colour, srcIn FW rendering/image.dart:139): always tinted.
  IconTheme under Theme(ThemeData()) is 0xDD000000 (MUI theme_data.dart:620-622, constants.dart:69). Loading or failed:
  the empty box (debug: an error widget, FW widgets/image.dart:1422-1423).
- CircularProgressIndicator PB:302-323, painter :465-513 (not Material's): 36 x 36 (`size` is read but not an engine
  prop); strokeWidth ?? 3 (<= 0 → 3); color ?? #2196F3. Rect inset strokeWidth/2 (:480-486); a forced non-square box
  (stretch, Expanded) draws an ellipse. value null or NaN: ONE STATIC arc, start -0.5 rad sweep 4.5 rad (-28.6°,
  257.8°; 0 = 3 o'clock, clockwise), round cap (:495). value clamped 0..1 (:310): full-circle track in color.withAlpha
  (0x33) (alpha replaced, :500-504), then from 12 o'clock 2π·v, round cap, if v > 0 (:505-507); 0.4 → 144°. No RTL.
- LinearProgressIndicator PB:364-384, painter :435-463: height exactly minHeight ?? 4, ClipRRect radius minHeight/2,
  the parent's max width (unbounded, as in a Row, it fails). Track backgroundColor ?? #E0E0E0; value null → track
  only, no bar, no animation (:451); else a bar width·clamp(v, 0, 1) from the LEFT (RTL too), color ?? #2196F3.
- Table LB:646-666: each child is its own one-cell TableRow (:663); columnWidths, defaultColumnWidth never read;
  FlexColumnWidth(1), cells top-aligned (FW widgets/table.dart:124,127). Width = the parent's max; unbounded → the
  widest cell's max intrinsic width (FW rendering/table.dart:1086-1094). Cells tightFor(width) (:1377, :1398): full
  width, own height. border sent → TableBorder.all(color ?? #000000, width ?? 1) (LB:654-659), painted after the cells
  (:1509-1517), outer lines inside the rect, row lines centred on the boundary (table_border.dart:314-326); no inset.

## 4. Native today and what to build (none of the seven registered or advertised)
Registries SW NodeView.swift:91-184 (default plugin builder or EmptyView :181-183), KT WidgetBuilders.kt:159-246
(missing builder draws nothing, logged once, NodeView.kt:80-89). Text style parsing lives in the UI modules, not the
cores: SW Style/Props.swift:199-272, KT style/Props.kt:284-360.
- Text path. SW TextNodeView Widgets/Content.swift:12-96; TextKit.swift: kern runs :43-53, DecorationRenderer (iOS
  18, whole text) :91-133, OneLineLayout :154, LineCutLayout :171, FadeMask :188, JustifiedText + NSAttributedString
  :209-273. No style → SwiftUI .body 17, primary (Props.swift:244-255); background fills the box (Content.swift:23).
  KT TextWidget Content.kt:63-112 merges LocalTextStyle.current (:67; page bodyMedium, OrcaPageView.kt:75); lines,
  fade, word spacing whole-layout (TextDecorations.kt:44, :81-117, :147).
- Merge gaps. Both read italic as a bool and collapse decoration to flags (SW Props.swift:209,229,233-236; KT
  Props.kt:309,313-315, fontStyle null unless italic :353, decoration null for none and absent :341-346): a styled
  child cannot reset italic, "none" cannot clear a parent's line. Spans and DTS need set/unset fields + Flutter's merge.
- RichText: base = engine defaults (14, white), not the ambient style, no scaling (KT sp follows fontScale). SW
  AttributedString runs; per-span overline/double/wavy need run-aware drawing (iOS 18 TextAttribute). KT AnnotatedString
  + SpanStyle, lines by range. Reuse the Text overflow/maxLines/textAlign code with RichText's start and clip.
- SelectableText: SW TextNodeView + selection (OQ2); KT SelectionContainer { TextWidget(node) } (props match).
- DefaultTextStyle: SW has no Orca text environment (keys OrcaTheme.swift:68, Motion.swift:7,21, Flex.swift:16,39);
  AppBar titles use .font(.headline) (Structure.swift:312,413,422). KT ProvideTextStyle MERGES; buttons merge
  labelLarge (Buttons.kt:224,496); Card resets nothing on either. Build a replacing ambient style + textAlign,
  maxLines, overflow (SW new environment key; KT CompositionLocalProvider(LocalTextStyle provides …)).
- ImageIcon: the Icon src path. SW IconNodeView Media.swift:12-38: scaledToFit (:18-25) enlarges small images; a src
  that is not a URL falls to the name glyph (:26-32); reuse ImageFit.scaleDown (:147), ImageBox (:195). KT IconWidget
  Icon.kt:35-53: M3 Icon(bitmap) fills the box (doc :32-33); reuse TiledImage (Image.kt:133) + ContentScale.Inside
  (:218), SrcIn tint (:119), ImageLoader.shared (client/ImageLoader.kt:52,85). Untinted default: SW foreground
  (Media.swift:239), KT LocalContentColor (Icon.kt:38).
- Progress: draw §3's painters. SW Canvas (Media.swift:115), Circle stroke (Selection.swift:188); KT Canvas
  (Controls.kt:373), drawArc in degrees: start -28.648°, sweep 257.831°, Stroke(cap = Round); SwiftUI Path's
  `clockwise` is flipped. ProgressView (SubPage.swift:92) and M3 spinners (SubPage.kt:71, OrcaBoot.kt:179) stay.
- Table: a one-column stack of full-width rows, border over them. SW vertical FlexView + orcaTight (Flex.swift:39-55),
  border parse Box.swift:88-103 (color ?? black, width ?? 1); KT a fixed-width Layout, Decoration.kt:84-85,147-148.

## 5. Pins, tests, demo
- Widgets 82 → 89: Swift CapabilitiesTests.swift:43-56, StructureWidgetTests.swift:258-270; Kotlin CapabilitiesTest
  .kt:84-92, :120-136, WidgetBuildersTest.kt:16-22 (built == advertised). Both capabilities.json +7 sorted; regenerate
  Generated.swift and Generated.kt (schema/gen-native-capabilities.ts, target gate :104-111 passes).
- Render fixtures 55 → 56: Swift ModelRoundTripTests.swift:10, Kotlin ModelRoundTripTest.kt:32, FixturePathsTest.kt:13;
  runners list the directory (engine conformance.test.ts, render_resolved_test.dart, Resolver fixture tests).
- No native test, golden or degrade page names the seven (degrade uses UnregisteredPluginWidget since s6). 18_sub_page
  holds a CPI as SubPage's onLoading child: natives draw it once registered, as Flutter. Flutter pins stay (progress_
  and_dialog_fixes_test.dart:43-72; engine components.test.ts:574-590). Patterns: Swift TextStyleTests.swift,
  ImageTests.swift:168 (inject `image:`); Kotlin TextTest.kt, ImageTest.kt (MockWebServer :58).
- Demo examples/server/parity-a.ts (1595 lines): header :81-88 ("Later steps add rich" :85); imports :18-79; add
  `richPage` (id "rich") after formsPage :1437-1574, route after `{ path: "forms" }` :1587, URL in index.ts after
  :118; engine test from parity-a-forms.test.ts (WIDGETS :12-22, PAGE :23).

## A7 rows vs Flutter
- A7.1 holds as written (PB:325-348). Evidence names the 14/white root defaults, the italic and "none" resets.
- A7.2 holds. SelectableText selects (selectable_text.dart:705-750). DTS applies to Text and SelectableText below it
  and yields to a Text's own style field by field, its textAlign/maxLines/overflow winning (text.dart:723-772); it
  replaces the ambient style (LB:594), any own style resets italic (BH:103), RichText ignores it, a Material resets it.
- A7.3 holds. Indeterminate is static: Circular a fixed arc (PB:495), Linear the bare track (:451). 0.4: a 144° arc
  from 12 o'clock over a 0x33 track; a 40% bar from the left. Colours color/backgroundColor, #2196F3 and #E0E0E0.
- A7.4 Table needs a correction (major, sent): Flutter has no columns or cell alignment (LB:661-665). Proposed: "Table
  draws each child as a one-cell row spanning the table, top-aligned, with TableBorder.all(border.color ?? black,
  border.width ?? 1) around and between rows when border is sent; columnWidths and defaultColumnWidth change nothing
  (LB:646-666). ImageIcon is tinted and sized." ImageIcon holds (image_icon.dart:111-117, scaleDown never enlarges).

## Open questions
1. A7.4 Table [major: public wire, sent]. (a) correct the row to Flutter as above (default); (b) a row model, column
   width spec (fixed/flex/fraction) and vertical alignment in engine, registry, Flutter, both natives, a fixture.
2. SelectableText on iOS [major: approach; the plan names .textSelection(.enabled)]. (a) read-only selectable
   UITextView (word/range selection, handles, Copy) from TextKit's attributed text (default); (b) .textSelection:
   on iOS a long press copies the whole text, no range.
3. Fields an unstyled RichText root or a DTS leaves out [minor]. (a) Flutter's engine defaults, 14 white regular
   (default); (b) host style (merge). Not a theme value: tradeoff consistent-cross-platform-look does not cover it.
4. Progress [minor]. (a) Flutter's static painters on a Canvas (default); (b) ProgressView / M3 indicators as the
   plan's tool list says: animated, other size and track, so A7.3 would not match.
5. Where a DTS stops [minor]. (a) at Card, InkWell, buttons, AppBar title, as Flutter (default); (b) flows through.
6. Icon src [patch]. (a) scaleDown, no glyph fallback on the shared Icon/ImageIcon path (default); (b) ImageIcon only.
7. Per-span custom lines (overline, dashed, dotted, double, wavy, decorationColor) [minor]. (a) range-aware drawing
   (default); (b) per span only the platform's solid underline/line-through, documented.
8. RichText text scaling [patch]. (a) none, as Flutter (default); (b) scale as Text.
9. Fixture [patch]. 46_rich_text_spans.json, RichText only (the other rows are ui).
