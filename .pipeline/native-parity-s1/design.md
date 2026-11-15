# native-parity-s1 · design in force (plan step 1, written at stage 08; 05-07 skipped)

Repo: /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/native-parity-phase-a-35cc97 (paths below
from there). Flutter (`sdk/`) is the reference; Swift UI layer `sdk-swift/Sources/OrcaGateway/` (SW), Kotlin UI
layer `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/` (KT). Flutter builders: `sdk/lib/src/builders/`
(BH = builder_helpers.dart, PB/LB/SB/BB/IB = primitive_/layout_/structure_/button_/input_builders.dart).
No new widget, no capability change: every prop below is already on the wire (engine classes under
`engine/src/components/`). Swift deploys to iOS 16 / macOS 13; Kotlin minSdk 24, compileSdk 36.

## Cases (phase-a-tests.md rows; "ui" = an SDK UI test, "fixture" = a shared file under schema/fixtures)
- A1.1 Text with line height 1.5, word spacing 4, overline and a dashed decoration draws all four. fixture + ui
- A1.2 Text on one line with overflow clip, fade, ellipsis and visible draws each mode as Flutter does. ui
- A1.3 Text align justify, left and right are honoured; left and right stay absolute in RTL. ui
- A1.4 A Container with a 4px border insets its child by 4px. ui
- A1.5 ElevatedButton draws its elevation shadow; its padding is inside the button. ui
- A1.6 Stack with fit passthrough hands the parent's constraints to its children. ui
- A1.7 Image fit fitWidth, fitHeight, scaleDown match Flutter; scaleDown never enlarges; repeat tiles. ui
- A1.8 Read-only TextField can be focused and its text selected, not edited. hintStyle, helperStyle, errorStyle,
  isDense apply. ui
- A1.9 AppBar honours elevation, shadowColor, leadingWidth, centerTitle false. A pushed page shows a back arrow
  unless automaticallyImplyLeading is false. ui + hand
- A1.10 Row and Column honour textDirection rtl and verticalDirection up. Center honours widthFactor and
  heightFactor. fixture + ui
- A1.11 Text decorationColor is drawn. Card honours surfaceTintColor and clipBehavior. Buttons honour autofocus.
  (Row corrected: "and tooltip" removed. The engine sends no `tooltip` on ElevatedButton/OutlinedButton/
  TextButton (engine/src/components/button/*.ts); Flutter's builders read none. IconButton and
  FloatingActionButton carry it: step 6.) ui
- A1.12 SingleChildScrollView with reverse starts at the far end; primary and shrinkWrap behave as Flutter. ui
- A1.13 On Android the open page stack survives a rotation without the host keeping its own router. hand
  (Swift: iOS does not rebuild the scene on rotation; the @StateObject router survives; checked by hand.)

## Gap inventory (checked against the code, 2026-11-15)
1 Text. Wire: style.{height, wordSpacing, decoration none|underline|overline|lineThrough, decorationColor,
  decorationStyle solid|double|dotted|dashed|wavy, overflow clip|fade|ellipsis|visible} (engine
  helpers/text-style.ts); Text: data, style, textAlign left|right|center|justify|start|end, maxLines, overflow,
  softWrap, semanticsLabel. Flutter: BH:96-170 passes all; PB:30-48 Text; overflow defaults to style.overflow,
  then clip; PB:400-410 textAlign: left/right absolute (do not flip in RTL), start/end follow Directionality,
  justify stretches all lines but the last. `height` is a multiple of fontSize (line box = height × fontSize).
  - Swift: TextStyleProps (SW Style/Props.swift:160-210) lacks height, wordSpacing, overline, decorationStyle,
    style.overflow. Text (SW Widgets/Content.swift:12-24) ignores overflow (SwiftUI always ellipsizes; Flutter's
    default is clip); Props.textAlignment (Props.swift:91-98) maps left/justify→leading, right→trailing (flips in
    RTL; justify not justified).
  - Kotlin: TextStyleProps (KT style/Props.kt:272-316) reads decorationColor but never draws it (269-270);
    lacks height, wordSpacing, overline, decorationStyle, style.overflow. Props.overflow (Props.kt:154-158): fade
    falls back to clip. textAlign absolute and justify OK.
2 Container (wire: padding, margin, decoration{color, borderRadius, border{width,color,style}, boxShadow,
  gradient}, width, height, alignment, color, clipBehavior). Flutter: the border insets the child
  (decoration.padding added to padding); clipBehavior clips the child, not the decoration.
  - Swift (SW Widgets/Box.swift:189-211): child NOT inset by the border (198); clip at 209 also clips shadows;
    Props.insets (Props.swift:51) maps left/right to leading/trailing (flips in RTL; Flutter EdgeInsets are
    absolute). Kotlin (KT widgets/Box.kt:39-67): all correct.
3 Buttons. Wire: Elevated enabled, color, backgroundColor, foregroundColor, elevation, borderRadius, padding,
  splashColor, highlightColor, autofocus; Outlined enabled, color, borderColor, splash, highlight, autofocus;
  Text enabled, color, splash, highlight, autofocus; triggers onTap, onLongPress. Flutter BB:29-91, 165-245:
  M3 min size 64x40, padding is content padding, elevation shadow, splash = pressed overlay, highlight = hovered
  overlay, autofocus passed through, disabled → M3 disabled colours, elevation 0.
  - Swift (SW Widgets/Buttons.swift): `padding` applied outside the button (line 61) = a margin; elevation,
    splash/highlight, autofocus, 64x40 minimum missing. Kotlin (KT widgets/Buttons.kt:38-100): splash/highlight
    (ripple colour) and autofocus missing.
4 Stack (fit loose|expand|passthrough, alignment default center, clipBehavior default none). Swift (SW
  Widgets/Stack.swift:115-129) treats passthrough as loose. Kotlin (KT widgets/Stack.kt:45-80) correct.
5 Image (src, fit default cover, width, height, alt, alignment, repeat noRepeat|repeat|repeatX|repeatY, color →
  srcIn tint). Flutter PB:50-97, PB:422-433; with no width/height the image takes its pixel size.
  - Swift (SW Widgets/Media.swift:47-108): contain/fitWidth/fitHeight/scaleDown all drawn as `.fit` (100); a
    resizable image fills the space offered instead of its intrinsic size; repeat ignored (45-46).
  - Kotlin (KT widgets/Image.kt:65-145): fits and intrinsic size correct; repeat ignored (53-54).
6 TextField. Flutter IB:34-84, 433-500; BH:270-301 parseInputDecoration passes labelStyle, hintStyle,
  helperStyle, errorStyle, isDense. With a decoration: readOnly stays focusable and selectable, not editable;
  maxLines N (no minLines) is a fixed N-line height.
  - Swift (SW Widgets/Input.swift): readOnly → `.disabled` (101, 117: not focusable/selectable); hint fixed
    #9E9E9E (103); helper/error fixed 12pt grey/red (205-214); isDense ignored.
  - Kotlin (KT widgets/Input.kt:61-228): hintStyle, helperStyle, errorStyle, isDense ignored; maxLines>1 sets
    only maxLines (95-96) so the field grows from one line (needs minLines = maxLines).
7 AppBar. Wire props backgroundColor, elevation, centerTitle, toolbarHeight, leadingWidth,
  automaticallyImplyLeading, shadowColor; slots title, leading, action_N. Flutter SB:85-120 (M3): centerTitle null
  → platform default (Android: start; iOS: centred when < 2 actions); automaticallyImplyLeading default true; the
  back arrow shows when the route was pushed; a `leading` slot replaces it. Scaffold's AppBar height 56.
  - Swift (SW Widgets/Structure.swift:70-147): in a Scaffold the AppBar is the NavigationStack bar; title always
    `.principal` (centerTitle false ignored); elevation, shadowColor, leadingWidth ignored; back button is
    NavigationStack's own (router.stack non-empty: SW OrcaApp.swift:130, Navigation/OrcaRouter.swift:31,60);
    automaticallyImplyLeading false ignored; a leading slot is added next to the back button instead of
    replacing it. Standalone AppBar default height 44 (Flutter 56).
  - Kotlin (KT widgets/Structure.kt:116-148): default height M3 64dp (Flutter 56); centerTitle true →
    CenterAligned, else start (Android default, fine); elevation, shadowColor, leadingWidth,
    automaticallyImplyLeading ignored; NO implied back arrow (only system back via BackHandler, OrcaApp.kt:178);
    the AppBar cannot see the router.
8 Row/Column (textDirection ltr|rtl, verticalDirection up|down, textBaseline) and Center (widthFactor,
  heightFactor). Flutter LB:119-158, 257-263: rtl makes a Row's main axis start at the right and flips a Column's
  cross start/end; up makes a Column lay out bottom-to-top (start = bottom) and flips a Row's cross start/end;
  textDirection does NOT change the children's own Directionality. Center's size = child size × factor
  (per axis given; otherwise fill).
  - Swift (SW Widgets/Layout.swift:14-117, Widgets/Flex.swift): neither direction prop read; FlexLayout treats
    baseline as start (Flex.swift:136-143); Center (Layout.swift:119-129) ignores factors.
  - Kotlin (KT widgets/Flex.kt:42-224): direction props ignored (follows ambient LayoutDirection); Center (KT
    widgets/Layout.kt:31-35) fillMaxSize, ignores factors.
9 Card (elevation default 1, padding, margin default 4, color, shadowColor, surfaceTintColor, borderRadius
  default 12, clipBehavior default none). Flutter SB:122-159 (M3). surfaceTintColor: M3 tint overlay by
  elevation (ElevationOverlay.applySurfaceTint: opacity 0 at 0, .05 at 1, .08 at 3, .11 at 6, .12 at 8, .14 at
  12, interpolated) over the card colour; clip only when clipBehavior is sent.
  - Swift (SW Widgets/Structure.swift:152-169): never clips; no surfaceTint. Kotlin (KT widgets/Structure.kt:
    158-177): M3 Surface always clips; no surfaceTint.
10 SingleChildScrollView (scrollDirection, reverse, padding, primary, shrinkWrap; triggers are step 2). Flutter
  LB:203-228: reverse = offset 0 at the far end (starts there; short content sits at the far end); primary
  passed through (iOS status-bar tap); shrinkWrap wraps the view in IntrinsicHeight (IntrinsicWidth when
  horizontal), so it hugs its content instead of filling.
  - Swift (SW Widgets/Layout.swift:162-174) and Kotlin (KT widgets/Layout.kt:70-85): reverse, primary,
    shrinkWrap ignored.
11 Kotlin router (A1.13): OrcaApp(client, …) builds the router with plain `remember` (KT OrcaApp.kt:139, doc
  129-130: "a new activity starts again at [path]"); router state is plain mutableStateOf
  (navigation/OrcaRouter.kt:49,52); NavController restores, then `popBackStack(ROOT_ROUTE…)` (OrcaApp.kt:181)
  drops the restored entries. After a rotation without configChanges the stack and every page's state are lost
  (Flutter keeps them: its activity handles orientation itself). The host-owned `OrcaApp(router, modifier)`
  overload (155-188) stays as it is.

## Decisions (agent defaults, logged at 08)
D1 Contract: two render fixtures, Phase A's numbers (40-59 reserved for phase A):
   `schema/fixtures/render/40_text_style_polish.json` (a Text with style {height 1.5, wordSpacing 4, decoration
   overline, decorationStyle dashed, decorationColor "#E53935", overflow fade}, overflow "fade", textAlign
   "justify", maxLines 1) and `41_flex_direction_center_factors.json` (a Column verticalDirection up and
   textDirection rtl with a Row textDirection rtl, a Center widthFactor 0.5 heightFactor 2). Each: `input`
   (engine JSON tree), `expected` (what the engine encodes: run the engine's encoder to produce it, never hand-
   write), and a `resolved` map pinning the props above. Green on the engine (engine/test/conformance.test.ts),
   Flutter (sdk/test/conformance/render_resolved_test.dart), Swift (ResolverFixtureTests, ModelRoundTripTests)
   and Kotlin (ResolverFixtureTest, ModelRoundTripTest). Count pins 39 → 41: SW Tests ModelRoundTripTests.swift
   (:10 and any "01-39" text), KT core ModelRoundTripTest.kt (:30), FixturePathsTest.kt (:10).
D2 Swift text drawing. Word spacing: AttributedString `kern` on the space characters. Dashed/dotted/solid
   underline and strikethrough with colour: `Text.LineStyle(pattern:color:)` (iOS 16). Overline, double and
   wavy: drawn per line with a `TextRenderer` (iOS 17 / macOS 14 and later); on iOS 16 they fall back to solid
   (documented, `#available`). Line height: the line box is height × fontSize as Flutter (line spacing plus half
   the extra leading above the first and below the last line). Overflow, one line: clip = the text laid out at
   its full width and clipped to the box (no ellipsis; Flutter's default when overflow is absent); fade = clip
   plus a horizontal fade over the last ellipsis-width of the box; ellipsis = `.truncationMode(.tail)`;
   visible = full width, not clipped. Multi-line (maxLines N) clip/fade cut at N lines with no ellipsis.
   Justify: on iOS a UIKit label/text view (`NSTextAlignment.justified`) wrapped for SwiftUI (sizeThatFits);
   macOS falls back to leading. left/right absolute: under `.rightToLeft` left maps to trailing and right to
   leading (multilineTextAlignment and frame alignment).
D3 Kotlin text drawing. lineHeight = height.em with a centred LineHeightStyle, Trim.None (Flutter's line box).
   wordSpacing: an AnnotatedString with SpanStyle(letterSpacing += wordSpacing) on each space. Decorations: when
   the style asks for anything Compose's TextDecoration cannot draw (overline, a non-solid style, a
   decorationColor), draw every decoration line from the TextLayoutResult (per line: underline below the
   baseline, overline at the line top, line-through at mid x-height) with the style's PathEffect (dashed, dotted),
   two lines for double, a sine path for wavy, in decorationColor (default: the text colour). fade = clip plus a
   DstIn gradient over the last ellipsis-width when the layout overflows. style.overflow is read when
   `overflow` is absent.
D4 Swift Props.insets becomes absolute (left is left in RTL), as Flutter's EdgeInsets.
D5 Kotlin A1.13: OrcaApp(client, …) keeps its router across configuration changes in a retained holder
   (a ViewModel in the activity's ViewModelStore; `androidx.lifecycle:lifecycle-viewmodel-compose` is already on
   the classpath through navigation-compose — declare it in the catalog only if the build needs it; any other new
   artifact is a question for the user). The NavController's back stack is rebuilt from the router's stack
   instead of being popped to the root. The router is closed when the activity finishes, not on rotation.
D6 Kotlin AppBar back arrow: OrcaApp provides a CompositionLocal (can-pop + go-back) that the AppBar reads; an
   AppBar with automaticallyImplyLeading true (default), no leading slot and a pushed page shows a back arrow
   (Icons.AutoMirrored.Filled.ArrowBack) that pops. Swift: automaticallyImplyLeading false →
   `.navigationBarBackButtonHidden(true)`; a leading slot replaces the back button (hidden when leading is set).
D7 AppBar default heights 56 (Kotlin TopAppBar expandedHeight 56.dp unless toolbarHeight; Swift standalone
   AppBar 56). Swift centerTitle false puts the title at the leading edge (`.topBarLeading` item); default
   (absent) stays centred as Flutter on iOS with < 2 actions; Kotlin default stays start-aligned.
D8 Card surfaceTint on both: the M3 overlay opacity table in item 9 over the card colour. Clip only when
   clipBehavior is sent (Props.clips). Swift default colour stays white (not in a row; noted for later).
D9 Swift Stack passthrough: non-positioned children get the Stack's incoming tight axes (orcaTight) and the
   proposed size on those axes, as loose otherwise.
D10 Swift Image: contain = fit, cover = fill, fill = stretch, fitWidth = scale to the box width (height follows
   the aspect, overflow clipped), fitHeight likewise, none = natural size centred by alignment and clipped,
   scaleDown = min(1, contain scale): never enlarges. With no width/height the image takes its pixel size (as
   Kotlin already does, KT Image.kt:95-134). repeat: the image at its fitted size, then tiled from its aligned
   position over the box (repeatX / repeatY one axis). Kotlin repeat: the same with a tiled ShaderBrush or a
   drawn grid.
D11 Buttons: Swift padding moves inside (content padding), M3 minimum 64x40, elevation draws a shadow (y
   offset ≈ elevation/2, radius ≈ elevation, 0 when disabled), splash = pressed overlay colour,
   highlight = hover overlay (pointer only). Kotlin: ripple colour from splashColor (LocalRippleConfiguration /
   ripple(color)), highlightColor for hover/focus via the interaction source. autofocus on both: request focus
   once on first composition / appear (Kotlin FocusRequester + LaunchedEffect; Swift `@FocusState` with
   `.focusable()` where the OS supports it, iOS 17+; a no-op before, documented).
D12 Scroll: reverse → starts at the far end and short content sits at the far end (Swift: iOS 17
   `defaultScrollAnchor(.bottom/.trailing)`, iOS 16 a ScrollViewReader scrollTo on appear; Kotlin:
   `reverseScrolling = true`). shrinkWrap → the view hugs its content up to the bounds (Swift fixedSize on the
   scroll axis; Kotlin wrap content). primary: Flutter passes it to the iOS status-bar tap; SwiftUI exposes no
   switch (documented as a known difference); Kotlin has no counterpart (no-op, documented).
D13 Row/Column direction props: scoped to the flex's own layout; children keep the ambient layout direction
   (Swift: apply the direction to the stack/FlexLayout and restore the outer direction on each child; Kotlin:
   compute positions in FlexMeasurePolicy from the prop, not from LocalLayoutDirection). verticalDirection up:
   children laid out bottom-to-top with start at the bottom. Center factors: size = child size × factor on each
   given axis, child centred (a small custom Layout on both).

## Constraints for every task
- Work only in the task's files. Do not touch capabilities.json, the widget registry, generated files, versions.
- Two implementers run at the same time: one Swift, one Kotlin. Never run the other SDK's build. Swift build
  tree is shared by the Swift task only; Kotlin by the Kotlin task only.
- Swift UI tests: `swift test` on macOS runs core and the macOS-capable UI tests (ImageRenderer style,
  FlexLayoutTests.swift). UIKit-only tests (NativeWidgetTests' `layout{}` host, goldens) run on the iOS simulator:
  `xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=F8CA6558-39C5-42D2-838F-5D04ED93750D' -derivedDataPath /private/tmp/claude-501/-Users-amrebada-workspace-orca-gateway-open-source--claude-worktrees-native-parity-phase-a-35cc97/ab7954f0-d0b4-4fcc-9f1e-a3ec6d37e995/scratchpad/dd-swift`
  (iPhone 16, iOS 18.5, reserved for this session; other sessions use other simulators). Golden PNGs must not
  change unless the task's row demands it.
- Kotlin UI tests: Robolectric + compose rule, @Config(qualifiers = "mdpi"), helpers in
  sdk/src/test/kotlin/com/orcagateway/sdk/support/Pages.kt; pixel tests with @GraphicsMode(NATIVE).
- New Swift test files must compile on macOS (guard UIKit-only code with `#if canImport(UIKit)`), on iOS, and on
  Linux (whole UI test target is SwiftUI-only; follow the existing `#if canImport(SwiftUI)` guards).
- Kotlin `./gradlew build` runs lint with warnings as errors: keep it clean.
