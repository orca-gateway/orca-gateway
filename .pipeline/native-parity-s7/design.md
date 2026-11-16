# native-parity-s7 · design in force (plan step 7, written at stage 08; 05-07 skipped)

Repo: /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/native-parity-phase-a-35cc97 (paths below from
there), branch feat/native-parity-s7 stacked on feat/native-parity-s6 (step 6 is PR #50, not merged yet; rebase when it
is). Flutter (`sdk/`) is the reference. Facts with every file:line: .pipeline/native-parity-s7/inventory.md (abbreviations
PB, LB, SB, BH, FW, MUI, ENG, SW, KT as there). Swift deploys to iOS 16 / macOS 13; Kotlin minSdk 24, Compose BOM
2026.05.01 (material3 1.4.0).

## Cases (phase-a-tests.md rows, after corrections)
- A7.1 RichText draws spans with different styles in one line, including nested spans. fixture + ui  [note: raw
  RichText (PB:325-348): no DefaultTextStyle, no text scaling, start, clip; root fields left unset are the engine's
  14 px and WHITE (ENG txt/src/txt/text_style.h:26,41); a child span starts from its parent's style (ENG
  paragraph_builder.cc:396) but a styled child is always upright unless italic (BH:103-105), and decoration "none"
  clears the parent's line (BH:141)]
- A7.2 SelectableText allows selection. DefaultTextStyle applies to Text below it and yields to a Text's own style.
  ui  [note: SelectableText is a read-only EditableText: long press or double tap selects a word, handles and a
  toolbar (MUI selectable_text.dart:705-799); its style is DTS.style merged with its own. DTS is the REPLACING ctor
  (LB:588-601, FW widgets/text.dart:63): the ambient bodyMedium is dropped; a Text merges DTS.style with its own field
  by field, its own textAlign/maxLines/overflow win (text.dart:723-772); RichText ignores DTS; every Material (Card,
  InkWell, Scaffold, buttons) resets it (MUI material.dart:470-474) and AppBar styles its own title]
- A7.3 Circular and Linear progress draw indeterminate, and determinate at value 0.4, with colours. ui  [note:
  Flutter paints its own (PB:302-323, 364-384, painters :435-513), not Material's, and nothing animates: an
  indeterminate Circular is ONE static arc (start -0.5 rad, sweep 4.5 rad, round cap), an indeterminate Linear the bare
  track; 0.4 is a 144° arc from 12 o'clock over a full track in color at alpha 0x33, and a 40 % bar from the left]
- A7.4 [corrected] Table draws each child as a one-cell row spanning the table, top-aligned, with TableBorder.all(
  border.color ?? black, border.width ?? 1) around and between the rows when border is sent; columnWidths and
  defaultColumnWidth change nothing (LB:646-666). ImageIcon is tinted and sized. ui  [the row as written ("honours
  column widths, border and cell alignment") needs a public wire change: no row model is on the wire and Flutter has no
  columns or cell alignment. The user's answer is pending; default (a) correct the row, wire change later as its own
  step. Table is built in the last group so (b) can still land here. ImageIcon: size ?? 24, scaleDown (never enlarges),
  centred, always tinted srcIn (FW widgets/image_icon.dart:91-119)]

## Decisions
- D1 Contract. No wire change (A7.4 default). Render fixture `schema/fixtures/render/46_rich_text_spans.json`
  (inventory §2: nested spans, a page-state Value in the innermost span, textAlign center, maxLines 1, overflow
  ellipsis; `watches` ["name"]; a `resolved` block). No action fixture. Count pins move on both SDKs (render 55 → 56).
- D2 Targets. All seven already target ios and android in the registry: no engine class, registry or orphan change.
- D3 Capabilities. Both capabilities.json gain the seven (82 → 89), sorted, one generator run, in the last group; no
  new action kind. Kotlin registers them in standard(). Engine test `engine/test/parity-a-rich.test.ts` (copy of
  parity-a-forms.test.ts): each native vector gets page `rich` whole (red until the caps group, so it lands with it).
- D4 Text style merging in pure cores (both SDKs, same cases): a `TextStyles` core over the wire style JSON with
  Flutter's rules: merge(parent, child) = the child's set fields win; a child that has a style always sets fontStyle
  (normal unless "italic"); decoration "none" clears; and `spans(root)` flattens a TextSpan tree into runs (text, merged
  style) in order, a non-object child becoming its string, a missing `text` an empty run. The UI layers map a merged
  style through their existing Props parsing (SW Style/Props.swift, KT style/Props.kt), extended with what the merge
  needs (an explicit upright fontStyle, decoration none).
- D5 RichText. Base style = Flutter's engine defaults (14, white, regular weight), never the ambient style or a DTS; no
  text scaling; textAlign start, softWrap true, overflow clip unless sent; maxLines. Swift: an AttributedString of the
  runs drawn through the Text path (OneLineLayout, LineCutLayout, FadeMask reused); Kotlin: an AnnotatedString of
  SpanStyles through the TextWidget path. Per-span custom lines (overline, double, dotted, dashed, wavy,
  decorationColor) are drawn by range (OQ7 a); background per run.
- D6 SelectableText. Style = DTS.style merged with its own (D4), textAlign own ?? DTS ?? start, maxLines own ?? DTS
  (past it the text scrolls, no ellipsis). Kotlin: SelectionContainer around the Text path. Swift: a read-only,
  selectable UITextView (word and range selection, handles, the system Copy menu) fed the same attributed text (OQ2 a;
  the plan names `.textSelection(.enabled)`, which on iOS only copies the whole text: major, sent to the user with
  default a; built in the last group).
- D7 DefaultTextStyle. A replacing ambient style (style, textAlign, maxLines, overflow ?? clip) that Text and
  SelectableText read and merge with their own (D4); unset fields fall to the engine defaults (14, white), as Flutter.
  Absent a DTS, Text keeps today's ambient look. Card, InkWell, the buttons, Scaffold's body and the AppBar title reset
  it, as Flutter's Material does. Swift: a new environment value; Kotlin: a new CompositionLocal (Compose's
  ProvideTextStyle merges, so it is not used for this).
- D8 ImageIcon = Icon with `src`, and the shared Icon src path is fixed on both SDKs (OQ6 a): size ?? 24 square,
  scaleDown (never enlarges), centred, tinted srcIn with color ?? the Icon default; a src that fails or is loading
  draws the empty box (Swift no longer falls back to the name glyph). Icon without src is unchanged.
- D9 Progress. Flutter's painters on a Canvas on both SDKs, from a pure `ProgressGeometry` core (same cases):
  Circular 36 x 36 unless constrained (a forced non-square box draws an ellipse), strokeWidth ?? 3 (<= 0 → 3), color
  ?? #2196F3, rect inset by strokeWidth / 2; value null or NaN → one static arc from -0.5 rad sweeping 4.5 rad, round
  cap; else value clamped 0..1, a full track in color at alpha 0x33, then an arc from 12 o'clock of 2π·v (none at 0),
  round cap. Linear: height minHeight ?? 4, corner radius height / 2, the parent's width, track backgroundColor ??
  #E0E0E0; value null → the track only; else a bar of width·clamp(v) from the LEFT (RTL too), color ?? #2196F3.
  Nothing animates (Flutter's indeterminate is static; documented, and listed for the user as a Flutter behaviour).
- D10 Table (A7.4 a). One column: each child a row the table's width wide (tight width, own height), top-aligned,
  rows stacked; width = the parent's max, unbounded → the min width constraint (0 in a horizontal scroll: FlexColumnWidth's maxIntrinsicWidth is 0, rendering/table.dart:212-214, :1123-1129; corrected at K-table). border sent → lines of
  border.width in border.color ?? black: the outer ones inside the rect, row lines centred on the boundary, painted
  over the cells (no inset). columnWidths and defaultColumnWidth are read by nothing.
- D11 Demo. Page `rich` on parity-a (after `forms`), one section per row: a RichText with nested spans and a span bound
  to page state (a button changes it); an unstyled RichText (the white-root case, on a dark box); a SelectableText; a
  DefaultTextStyle over two Texts (one with its own style) and a RichText; Circular and Linear progress, indeterminate
  and 0.4, default and coloured; a Table with border and three children and columnWidths sent; ImageIcon at two sizes
  and colours, one small image (scaleDown). The header drops "rich" from later steps.
- D12 Tests per row: Swift ImageRenderer for static looks (pixels and sizes), hosted UIWindow where selection or touch
  matters; Kotlin Robolectric compose tests (semantics, bounds, captured pixels). Each check named `testA7_N…` /
  `a7_N_…`; the cores' shared cases `a7_N_…` on both. No golden moves unless a task row lists it.
- D13 Row corrections (written by the main session): A7.4 as above (pending the user; default); notes on A7.1-A7.3.

## Open (from the inventory, decided by the standing rule unless marked)
OQ1 Table wire [major, with the user] → a. OQ2 SelectableText on iOS [major, with the user] → a, last group.
OQ3 unset root/DTS fields → Flutter's engine defaults. OQ4 progress → Flutter's static painters. OQ5 DTS stops at
Material → yes. OQ6 Icon src → fix the shared path. OQ7 per-span custom lines → by range. OQ8 RichText scaling →
none. OQ9 fixture → 46_rich_text_spans.json.
