# 09 · Implementation · native-parity-s1

## Front page

### In one breath
group 6 of 7 · tasks: 11 green, 0 blocked · cells: 20 of 26 green (recounted per SDK cell)
S-button: Swift buttons keep the native iOS look; padding inside, elevation shadow, splash and
highlight overlay and autofocus apply only when sent. Every Stack fit takes forced axes (Flutter).
K-button: Kotlin ripple colours and autofocus; every Image at one dp per image pixel, repeat tiles.
Group 7: K-field committed (de91c6d); S-media running. Android hand checks A1.9, A1.13 pass.

### New for you
nothing new

### Trade-offs
4 auto-decided: Swift buttons stay native (your gate-03 call) not a Material face; Kotlin autofocus
only outside touch mode; a loose Swift Stack fills a tight parent (Flutter); host theme still wins.

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: finish group 7 (S-media), then the step's full run and iOS hand checks? (default: go)

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


### Group 3
Commits: K-flex c184b56, S-flex ccf5327 (staged by path). Nothing pushed. Group 2's card approved under the
standing rule. K-router (group 4) was started while S-flex was in review: Kotlin-only, no dependency.

#### Task K-flex · Kotlin flex directions, Center, scroll
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Flex.kt` · `…/sdk/widgets/Layout.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/FlexLayoutTest.kt` · `…/sdk/widgets/LayoutTest.kt` (new)
Cases: A1.10 kt, A1.12 kt → green (11 new tests: rtl Row on an ltr page and ltr Row on an rtl page, Column up,
up/rtl cross flips, a Text in an rtl Row keeps the page direction, Center factors and no factor, reverse starts at
the far end, short reversed content at the far end, shrinkWrap hugs; `./gradlew build` clean).
Changed: FlexMeasurePolicy takes the flex's own textDirection and `up` and computes positions from them (not
LocalLayoutDirection); Center is a small Layout sizing by widthFactor/heightFactor; ScrollWidget reverseScrolling
and scrolledContent keep the content's own length on the scroll axis.
Decisions: 1. shrinkWrap and primary need nothing on Android (documented): the scroll view already wraps its
content where the parent allows.
Review fit: pass
Review quality: pass
Not done: nothing

#### Task S-flex · Swift flex directions, Center, scroll
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Layout.swift` · `…/Widgets/Flex.swift` · `sdk-swift/Tests/OrcaGatewayTests/FlexLayoutTests.swift` · `…/LayoutTests.swift` (new)
Cases: A1.10 sw, A1.12 sw, D4 → green (macOS `swift test` green; iOS 16 Pro 18.5 UI 75/0, core 234/0, goldens
unchanged, 0 warnings). Red first except two regression guards (a Text child keeps the ambient direction;
shrinkWrap stops at the bounds).
Changed: FlexView sets the layout direction on the stack/FlexLayout only when textDirection is sent and gives
each child the ambient direction back; Column up reverses with start/end swapped; Row up swaps cross start/end
(stack and FlexLayout paths); CenterFactorLayout when a factor is sent; Padding and scroll use `orcaPadding`;
ScrollNodeView reverse (iOS 17 defaultScrollAnchor, iOS 16 ScrollViewReader to the end) and shrinkWrap
(HugLayout: hugs, never grows past the offer); `primary` documented as a known difference.
Decisions: 1. rtl relies on SwiftUI mirroring the flex under its own direction (tests: same output on both
paths) · 2. HugLayout over plain fixedSize (bounded like Flutter's IntrinsicHeight) · 3. an unknown
textDirection value counts as absent.
Review fit: Row baseline added to FlexLayout outside the task (moved a no-text child from Flutter's top),
fixed (removed, baseline stays at the top as before)
Review quality: every plain Row/Column got 1 + N environment layers, fixed (only when textDirection is sent)
Not done: iOS 16 reverse fallback leaves short content at the start (doc comment; CI and goldens run 18.5).
For later: Row baseline alignment in Swift FlexLayout (no case row covers it).

#### Group 3 test run
engine 739 pass 0 fail (no engine file changed) · Swift macOS `swift test` green · iOS (DA7254F5) UI 75 + core
234, 0 failures, goldens unchanged · Kotlin `./gradlew build` successful at c184b56 (K-flex's run; lint clean); the
full Kotlin counts are re-run with group 4 (K-router is using the tree now). Flutter: no file changed.


### Group 4
Commits: K-router 6ff7679, S-box 6a7f87f (staged by path). Nothing pushed. Group 3's card approved under the
standing rule. Group 5's K-bar was started after K-router's commit and S-bar after S-box's (one Swift and one
Kotlin task at a time, as before).

#### Task K-router · Kotlin router retained, can-pop local
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt` · `…/sdk/navigation/OrcaRouter.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppTest.kt` (libs.versions.toml and build.gradle.kts unchanged)
Cases: A1.13 kt → green (7 new `a1_13_kt_*` tests through a HostActivity recreated with Robolectric
`ActivityController.recreate()`; OrcaAppTest 9/9; `./gradlew build` sdk 166/0, core 228/0, lint clean; baseline
sdk 159). 5 red first; the outside-OrcaApp default passed once the local existed; the host-system test was added
after green.
Changed: OrcaApp(client) keeps its router in an internal `RetainedRouter` ViewModel (closed in onCleared); the
host's `system` is set on the router by a DisposableEffect while shown; OrcaApp(router) saves the pushed route
ids next to the NavController (rememberSaveable) and after a recreation keeps the shared bottom, pops the rest,
pushes the missing; `OrcaNavigation(router?, canPop)` + `LocalOrcaNavigation` (default: no router, can-pop false).
Decisions: 1. ViewModel keyed by `currentCompositeKeyHashCode` (two OrcaApp in one activity get two routers) ·
2. route ids saved with rememberSaveable because NavController.currentBackStack is @RestrictTo (lint) · 3. the
host's `system` is no longer passed to the router's constructor (no public signature changed) · 4.
lifecycle-viewmodel-compose comes with navigation-compose; nothing declared.
Review fit: pass
Review quality: pass
Not done: the AppBar arrow (K-bar, group 5); the rotation check on the emulator (hand, at the end of the step).

#### Task S-box · Swift Container border inset, clip
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Box.swift` · `sdk-swift/Tests/OrcaGatewayTests/BoxTests.swift` (new) (golden native-widgets-home unchanged: it still passes)
Cases: A1.4 sw, D4 → green (4 tests: a 4pt border insets by 4, border + padding 10 insets by 14, the clip cuts
the child but not the shadow, padding/margin left stay left in RTL; macOS `swift test` green; iOS UI 79/0, core
234/0, goldens unchanged, 0 warnings). All 4 red first.
Changed: BoxDecorationProps `borderInset` (the border width, default 1); ContainerView insets the child by the
border plus `orcaPadding(padding)`; ClipIf moved inside the background so it clips the padded child and the
shadows stay outside; margin via `orcaPadding`.
Decisions: 1. a border with style none still insets by its width (Flutter's Border.dimensions ignores the style) ·
2. the border inset is its own `.padding(width)` (0 for a plain Container: no layout change) · 3. clipBehavior
with no decoration clips to a rectangle (existing behaviour; Flutter asserts there).
Review fit: pass
Review quality: the test borrowed a `FlexLayoutTests()` instance and added its own frames struct instead of the
shared `Pixels`, fixed
Not done: nothing

#### Group 4 test run
engine 739 pass 0 fail (no engine file changed since G3) · Swift macOS `swift test` green · iOS (DA7254F5) UI 79 +
core 234, 0 failures, goldens unchanged · Kotlin `./gradlew build` successful (sdk 166, core 228, lint clean).
Flutter: no file changed.


### Group 5
Commits: K-bar 7829473 + fix b99fc9c, S-bar 6488fcb (staged by path). Nothing pushed. Group 4's card approved
under the standing rule. Group 6's K-button started after K-bar's commit, S-button after S-bar's.

#### Task K-bar · Kotlin AppBar, back arrow, Card
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Structure.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/AppBarCardTest.kt` (new) · `sdk-kotlin/sdk/src/test/resources/goldens/{counter-home,degrade-warn,native-widgets-home}.png`
Cases: A1.9 kt, A1.11 kt (Card) → green (AppBarCardTest 8/0; `./gradlew build` sdk 180, core 228, lint clean;
baseline 166 + 228). 6 of 7 red first (the root-shows-no-arrow guard passed before); the fix's test red first.
Changed: AppBar default height 56; back arrow (Icons.AutoMirrored.Filled.ArrowBack, "Back") → LocalOrcaNavigation
.goBack() when the page can pop, automaticallyImplyLeading is not false and no leading slot; leading box
leadingWidth × bar height, title 16 past it; elevation + shadowColor → Modifier.shadow (none without
shadowColor). Card: a Box (shadow + shape background) that clips only when clipBehavior is sent; surfaceTint
overlay by the M3 table. Goldens: only the bar height moved (rows match the old ones shifted 0/8/16 px at 2x).
Decisions: 1. Flutter geometry by cancelling M3's 4dp insets (padding(end = 8).offset(x = -4)) · 2. the Card Box
keeps Surface's content colour, touch blocking and traversal group · 3. the bar's shadow is read through its
inspector in the test (a software canvas draws no shadows) · 4. no AppBar shadow without shadowColor
(app_bar.dart:2541 `_AppBarDefaultsM3.shadowColor` transparent; ThemeData() is M3).
Review fit: pass; after commit the main session found the black default shadow (Flutter M3: transparent),
fixed in b99fc9c, re-review pass
Review quality: pass
Not done: the M3 AppBar surface tint by elevation (not drawn on either SDK).

#### Task S-bar · Swift AppBar and Card
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift` · `sdk-swift/Tests/OrcaGatewayTests/AppBarCardTests.swift` (new)
Cases: A1.9 sw, A1.11 sw (Card), D4 → green (12 tests, all red first; macOS `swift test` 78 UI + 234 core; iOS UI
91/0, core 234/0, goldens unchanged, 0 warnings).
Changed: AppBarChrome: centerTitle false → title in a `.navigationBarLeading` item after the back button; a
leading slot replaces the back button; automaticallyImplyLeading false hides it; leadingWidth sizes the leading
item; elevation + shadowColor → a shadow strip at the top of the content (AppBarShadow, shared). AppBarView: 56
high, Flutter's toolbar layout (leading box leadingWidth ?? 56, title 16 after it). CardView: tint by the M3
table; clip only when sent, not the shadow; orcaPadding.
Decisions: 1. no shadow without shadowColor (Flutter M3; the brief's black default was wrong) · 2. the strip is
`elevation` pt tall, shadowColor at 25% fading to clear; no global UINavigationBarAppearance · 3. in the nav bar
leadingWidth applies only when sent (UIKit's margin stands in for 56).
Review fit: pass
Review quality: pass
Not done: M3 AppBar elevation tint; Card default colour stays white; hiding the back button also turns off
swipe-back (doc comment; hand check).

#### Group 5 test run
engine 739 pass 0 fail (no engine file changed) · Swift macOS `swift test` 78 UI + 234 core green · iOS (DA7254F5)
UI 91 + core 234, 0 failures, goldens unchanged · Kotlin `./gradlew build` successful (sdk 180, core 228, lint
clean; K-button's uncommitted files were in the tree and green). Flutter: no file changed.


### Group 6
Commits: K-button 207e143, S-button 4d05802 (staged by path). Nothing pushed. Group 5's card approved under the
standing rule. Group 7's K-field (de91c6d) started after K-button's commit; S-media after S-button's.

#### Task K-button · Kotlin button ripple, autofocus, Image repeat
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Buttons.kt` · `…/widgets/Image.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ButtonTest.kt` (new) · `…/widgets/ImageTest.kt`
Cases: A1.5 kt, A1.7 kt, A1.11 kt (autofocus) → green (ButtonTest 4, ImageTest 10; `./gradlew build` sdk 181, core
228, lint clean). Red first: autofocus, splash/highlight, repeat, the xhdpi fit test; padding, elevation and the
mdpi fits passed before (pins).
Changed: own interaction source per button; splash/highlight as a LocalRippleConfiguration (splash pressed,
highlight otherwise); autofocus FocusRequester + LaunchedEffect once; every Image drawn by one `TiledImage` painter
(applyBoxFit, aligned, one dp per image pixel; noRepeat = one clipped tile; repeat/repeatX/repeatY tile as
Flutter's _generateImageTileRects).
Decisions: 1. autofocus only outside touch mode (Compose's rule; Flutter shows no highlight on touch; KDoc) · 2.
one ripple carries both colours (press ripple capped at 50% alpha; overlay over the label) · 3. repeat as a drawn
grid · 4. source rects cut to whole image pixels.
Review fit: the touch-mode limit was not in the KDoc, fixed
Review quality: non-tiled images drew at one device pixel per image pixel (wrong above mdpi), fixed (one painter,
xhdpi test)
Not done: nothing

#### Task S-button · Swift buttons and Stack passthrough
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Buttons.swift` · `…/Widgets/Stack.swift` · `sdk-swift/Tests/OrcaGatewayTests/ButtonTests.swift` (new) · `…/StackTests.swift` (golden counter-home unchanged)
Cases: A1.5 sw, A1.6 sw, A1.11 sw (autofocus) → green (macOS `swift test` 84 + 234; iOS UI 98/0, core 234/0, goldens
unchanged, 0 warnings). All red first.
Changed: a button with no style props keeps HEAD's native look (borderedProminent + tint / OutlinedStyle /
borderless; OrcaTheme host style wins); padding pads the label inside (absolute sides; the system's own insets
remain, documented); elevation → shadow (none when absent or disabled); splash/highlight → `OverlayFace` copying
the native metrics (prominentInsets, prominentShape) with the overlay under the label; autofocus once on appear
(iOS 17 / macOS 14). Stack: every fit takes the parent's forced axes; passthrough hands them to ordinary children.
Decisions: 1. native look kept (the user's native-sdk gate 03 call, decisions.jsonl:26); the first attempt's
Material 3 face for every button, 64x40 minimum and default elevation-1 shadow were removed · 2. a disabled button
never takes OverlayFace · 3. every Stack fit takes forced axes (Flutter stack.dart:628-629) · 4. a host OrcaTheme
style still wins over elevation/splash/highlight (serverStyleProps unchanged; for later).
Review fit: first attempt redrew every button in Material 3, reversing the user's platform-idiom call, fixed
(native look); the Stack sizing beyond passthrough was kept as a decision (Flutter's RenderStack)
Review quality: an unnamed copied corner radius with a bounds-only test, fixed (named static, corner pixel check);
the macOS TextButton comparison matched ImageRenderer's yellow placeholder by luck, fixed (exact predicate)
Not done: CI's Xcode 16.4 golden needs no re-record (no golden moved). For later: OrcaTheme.serverStyleProps.

#### Group 6 test run
engine 739 pass 0 fail (no engine file changed) · Swift macOS `swift test` 84 UI + 234 core green · iOS (DA7254F5)
UI 98 + core 234, 0 failures, goldens unchanged · Kotlin `./gradlew build` successful (sdk 181, core 228; then sdk
187 with K-field). Flutter: no file changed.

### Test run
engine 739 pass 0 fail · Flutter +248 all passed · Swift macOS 234 tests 0 failures · Kotlin core 228, sdk 132,
0 failures. Lint: not run (no lint-relevant source changed; G2 onward runs `./gradlew build` and `flutter analyze`).

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing
