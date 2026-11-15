# 09 · Implementation · native-parity-s1

## Front page

### In one breath
group 2 of 7 · tasks: 3 green, 0 blocked · cases: 10 of 26 green · every suite green
S-text: Swift Text draws line height, word spacing, overline/dotted/dashed/double/wavy, decoration
colour, the four overflow modes and justify; left/right stay absolute in RTL; absolute insets.
K-text: Compose Text draws the same; decorations from the text layout, built once per layout.
D1: demo app `parity-a`, page `polish`: every step 1 prop, a pushed page, one with no back arrow.
iOS runs now use a new iPhone 16 Pro (iOS 18.5) simulator: the plain iPhone 16 failed 9 old tests.

### New for you
nothing new

### Trade-offs
3 auto-decided: overline at the font ascent (Flutter); Swift overline/double/wavy need iOS 18;
D1 draws no Wrap (native SDKs lack it until step 3).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 3 (S-flex, K-flex: flex directions, Center factors, scroll)? (default: go)

## Appendix

Cases count: 26 = the 13 rows split per SDK, plus the fixture halves of A1.1 and A1.10 (counted with
the row's first SDK cell they unblock); a row is ticked in phase-a-tests.md only when both its halves pass.

### Group 1
Commit: C1 (below). Nothing pushed. Gate 08 approved under the standing rule (all defaults).

#### Task C1 · Fixtures 40, 41 and count pins
Files: `schema/fixtures/render/40_text_style_polish.json` (new) · `schema/fixtures/render/41_flex_direction_center_factors.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt`
Cases: A1.1 fx, A1.10 fx → green (engine `bun test` 739 pass 0 fail; Flutter conformance +49, full +248; Swift
`swift test` 234 tests 0 failures; Kotlin `:core:test` 228 tests 0 failures; `:core:build` successful) · baseline
unchanged (737/+246/234/228 plus 2 new engine and 2 new Flutter tests). Red first: with the pins at 39, Swift
ModelRoundTripTests:10 and Kotlin ModelRoundTripTest, FixturePathsTest failed (41 vs 39).
Changed: 40 = Text "t" with style {fontSize 16, height 1.5, wordSpacing 4, decoration overline, decorationStyle
dashed, decorationColor #E53935, overflow fade}, overflow fade, textAlign justify, maxLines 1; `resolved` pins the
five props. 41 = Column "col" (verticalDirection up, textDirection rtl) > Row "row" (rtl; Texts first, second) +
Center "center" (widthFactor 0.5, heightFactor 2). `expected` from `encodeJsonTree` (scratchpad script), not by
hand. Render pins 39 → 41 (Swift :10, :151; Kotlin ModelRoundTripTest :30, :176; FixturePathsTest :10).
Decisions: 1. Fixture 40's `data` comes from page state `caption`, so its resolved map checks a real resolution
· 2. The engine accepted every prop as spelled; nothing renamed.
Review fit: pass
Review quality: pass
Not done: nothing

### Group 2
Commits: D1 7aa9f7c, K-text 2194109, S-text c23bd3c (staged by path). Nothing pushed. Group 1's card approved
under the standing rule.

#### Task D1 · Demo app parity-a, page polish
Files: `examples/server/parity-a.ts` (new) · `examples/server/index.ts` · `examples/server/record-page.ts`
Cases: A1.13 sw (hand, later) → page ready (`bun test` 739 pass 0 fail, demo-server.test.ts included); a
scratchpad script started index.ts and fetched polish, polish-pushed, polish-no-back: 200 each (polish 206
components; 404 before the change). Swift and Kotlin recordings equal the unfiltered page (nothing stripped).
Changed: parityAApp (id parity-a), flow "parity", routes array, page constants per step; polish has sections
A1.1-A1.12, an AppBar (elevation 4, shadowColor, leadingWidth 72, centerTitle false, a leading Icon), a page-state
counter, Navigate buttons to polish-pushed (default back arrow) and polish-no-back (automaticallyImplyLeading
false, a GoBack button). Registered in index.ts (import, apps, URL line) and record-page.ts.
Decisions: 1. No Wrap (the native SDKs lack it; the filter would hoist its children) · 2. A1.8 has 3 TextFields
(Flutter hides helperText when errorText is set) · 3. leading Icon so leadingWidth shows; repeat image with fit
none; the passthrough Stack's Container holds a Text.
Review fit: pass
Review quality: pass
Not done: examples/server/README.md row for parity-a (not a task file).

#### Task K-text · Kotlin text style, decorations, fade
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/style/Props.kt` · `…/sdk/widgets/Content.kt` · `…/sdk/widgets/TextDecorations.kt` (new) · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/style/PropsTest.kt` · `…/sdk/widgets/TextTest.kt` (new)
Cases: A1.1 kt, A1.2 kt, A1.3 kt, A1.11 kt (decorationColor) → green (`:sdk:testDebugUnitTest` 148 tests 0
failures; `./gradlew build` clean, core 228) · baseline unchanged (132 + 16 new; no golden moved). Red first: 10
tests (8 TextTest, 2 PropsTest), then the overline-at-ascent test in the rework; 5 pins passed before (clip,
ellipsis, visible, justify, left/right RTL: Compose already did these).
Changed: TextStyleProps reads height (lineHeight height.em, centred, Trim.None), wordSpacing, overline,
decorationStyle, style.overflow, `drawsDecoration`; TextWidget: overflow → style.overflow → clip, word spacing,
Compose's decoration off when drawn by hand, `drawWithCache` builds the decoration Path (one stroke, dash effect,
double gap, wave) and fade brush per layout; fade = saveLayer + DstIn only when cut. Overline at baseline − font
ascent (Flutter's paragraph).
Decisions: 1. Props.overflow keeps Clip for fade; textStyle() keeps Compose's underline/line-through (PropsTest
pins unchanged) · 2. fade on maxLines cuts fades the bottom half of the ellipsis height; RTL fades the left end
(as RenderParagraph) · 3. decoration metrics from Skia defaults (thickness fontSize/14, dash 4/2, dots 1/1.5,
double +3dp, wavy quadratic), line-through 0.265em · 4. overline at the font ascent (main-session decision,
Flutter parity) · 5. ascent measured on "H" in the main font (a fallback font with a taller ascent is slightly
off) · 6. wavy overline offset thickness/2 (Flutter uses the full thickness; left).
Review fit: pass
Review quality: per-draw allocations in the Text draw path (Content.kt drawWithContent, TextDecorations.kt),
fixed (drawWithCache)
Not done: TextField gets the line height through textStyle() but not word spacing or the hand-drawn decorations
(TextField task, G7).

#### Task S-text · Swift text style, overflow, align
Files: `sdk-swift/Sources/OrcaGateway/Style/Props.swift` · `…/Widgets/Content.swift` · `…/Widgets/TextKit.swift` (new) · `sdk-swift/Tests/OrcaGatewayTests/TextStyleTests.swift` (new)
Cases: A1.1 sw, A1.2 sw, A1.3 sw, A1.11 sw (decorationColor), D4 → green (macOS `swift test` UI 59/0, core
234/0; iOS 16 Pro 18.5 UI 63/0, core 234/0, goldens included; no warnings) · baseline unchanged. Red first: all
four cases failed at run time, D4 failed to compile; the plain-path assertion failed before the rework.
Changed: TextStyleProps gains height, wordSpacing, overline, decorationStyle, overflow; `apply` draws dotted and
dashed lines via Text.LineStyle and returns early with no decoration; `textAlignment(_:direction:)` keeps
left/right absolute in RTL; D4 `Props.insets(_:direction:fallback:)` and `View.orcaPadding(_:fallback:)`.
TextKit.swift: font metrics, line-box leading, `text(_:)` (plain Text without wordSpacing, kern on spaces with
it), DecorationRenderer (overline/double/wavy, iOS 18), one-line and N-line layouts without ellipsis, fade mask,
a justified UILabel on iOS. Content.swift: line box only when height is set; overflow → style.overflow → clip;
justify on iOS. A plain Text keeps the same view tree as before.
Decisions: 1. textRenderer needs iOS 18 / macOS 15 (the compiler; design said 17/14): before it no overline,
double/wavy solid · 2. overline at the font ascent (main-session decision) · 3. documented gaps: extra leading
split half/half (Flutter by ascent/descent); ≤0.2pt/line pixel drift; a height below the font's line only shrinks
the outer padding; with maxLines fade cuts like clip; the justified UILabel draws no overline and cuts fade and
visible like clip · 4. StyledText became a method (no extra view around a plain Text) · 5. the plain path drops
the baseline's `.lineLimit(nil)` (nothing above a Text sets a line limit; reviewed).
Review fit: pass
Review quality: plain-Text path built an AttributedString every body (TextKit.swift), fixed
Not done: the other files' call sites move to `orcaPadding` in their own tasks.

#### Group 2 test run
engine 739 pass 0 fail · Swift macOS UI 59 + core 234, 0 failures · iOS (Orca PhaseA iPhone 16 Pro, iOS 18.5,
DA7254F5) UI 63 + core 234, 0 failures, goldens included · Kotlin `./gradlew build` successful (core 228, sdk 148,
lint clean). Flutter: no file of its changed (fixtures unchanged since G1).
Simulator note: on the plain iPhone 16 (iOS 18.5) a clean tree fails 4 goldens and 4 layout tests (its safe area
differs); CI and the goldens use an iPhone 16 Pro, so this session made its own 16 Pro.

### Test run
engine 739 pass 0 fail · Flutter +248 all passed · Swift macOS 234 tests 0 failures · Kotlin core 228, sdk 132,
0 failures. Lint: not run (no lint-relevant source changed; G2 onward runs `./gradlew build` and `flutter analyze`).

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing
