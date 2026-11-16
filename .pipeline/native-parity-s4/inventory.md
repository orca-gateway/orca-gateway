# Step 4 inventory (visual effects and touch wrappers), checked 2026-11-16 on feat/native-parity-s3 0740362

## 1. Engine classes (engine/src/components/layout/*.ts)
All 11 extend SingleChildLayout (types/widget.ts:245-248), private ctor + static new, getProps() = {...this.props}; no engine
defaults; no `targets` (all four); exports layout/index.ts:24-36,52; no engine test mentions them. IgnorePointer is in
PASS_THROUGH_TYPES (types/widget.ts:197-204).
| Opacity (opacity.ts:11-30) | opacity: number (required) |
| RotatedBox (rotated-box.ts:11-30) | quarterTurns: number (required) |
| ClipOval (clip-oval.ts:9-28) / ClipRect (clip-rect.ts:9-28) | none |
| DecoratedBox (decorated-box.ts:13-32) | decoration: BoxDecorationData (required); position?: background|foreground |
| ColorFiltered (color-filtered.ts:12-31) | color?: string; blendMode?: string |
| BackdropFilter (backdrop-filter.ts:12-31) | blurX?, blurY?: number |
| BlurView (blur-view.ts:25-44) | blurX?, blurY? (doc default 10); overlayColor?: string; borderRadius?: number |
| AbsorbPointer (absorb-pointer.ts:11-30) | absorbing?: boolean |
| IgnorePointer (ignore-pointer.ts:11-30) | ignoring?: boolean |
| InteractiveViewer (interactive-viewer.ts:14-33) | minScale?, maxScale?: number; panEnabled?, scaleEnabled?: boolean |
BoxDecorationData helpers/box-decoration.ts:32-38 (color, borderRadius number|corners :4-9, border :11-15, boxShadow :17-22,
gradient :24-30). Engine Color() emits "0xAARRGGBB" (helpers/color.ts:12-16): parsers accept only #RRGGBB/#RRGGBBAA.

## 2. Flutter builders (sdk/lib/src/builders/layout_builders.dart; registered :37,49,50,53,54,58,59,66,67,68,75)
- Opacity :288-293 default 1. RenderOpacity proxy_box.dart:886, paint :961 skips at 0; no hitTest override (transparent
  child still takes taps).
- RotatedBox :523-528 propOr<int>('quarterTurns', 0). rotated_box.dart:24; odd → vertical (:41); performLayout :87-99 child
  laid out with constraints.flipped (:90), size = (child.h, child.w) (:91); rotates about centre by quarterTurns % 4
  (:92-95); no child → constraints.smallest (:97); hit tests through the transform (:103+).
- ClipRect :426-428 (FW Clip.hardEdge basic.dart:973; RenderClipRect proxy_box.dart:1620, rejects hits outside :1633-1637).
  ClipOval :430-432 (antiAlias basic.dart:1238; RenderClipOval :1900, inscribed oval :1915,1921, hit test in ellipse
  :1924-1938).
- DecoratedBox :530-541 parseBoxDecoration (builder_helpers.dart:342-354; radius :356-371; border :373-387 black/1/solid;
  shadows :389-409 default 0x33000000; gradient :411-430); absent/invalid → const BoxDecoration(); foreground only for
  'foreground'. RenderDecoratedBox proxy_box.dart:2385 (size = child's, no padding); hitTestSelf = decoration.hitTest
  (:2464-2466); paints background before child (:2469-2472). Container adds decoration.padding (container.dart:378-384).
- ColorFiltered :543-550 ColorFilter.mode(color default 0x00000000, blendMode); _parseBlendMode :758-783 maps 21 names
  (srcOver srcIn srcATop dstOver dstIn dstATop multiply screen overlay darken lighten colorDodge colorBurn hardLight
  softLight difference exclusion hue saturation color luminosity); unknown/missing → srcATop.
- BackdropFilter :345-352 ImageFilter.blur(sigma blurX ?? 10, blurY ?? 10), NO clip: blur reaches the nearest ancestor
  clip or the whole screen (basic.dart:499-501).
- BlurView :354-370 SDK composite: ClipRRect(circular(borderRadius ?? 0)) > BackdropFilter(blur 10/10 default) >
  Container(color: overlayColor ?? transparent) > child.
- AbsorbPointer :455-460 absorbing default true; hitTest = absorbing ? size.contains(pos) : super (proxy_box.dart:3952-3953):
  counts as hit (siblings below get nothing), child never added.
- IgnorePointer :462-467 ignoring default true; hitTest = !ignoring && super (:3751-3752): falls through.
- InteractiveViewer :636-644 minScale 0.8, maxScale 2.5, panEnabled true, scaleEnabled true; boundaryMargin, constrained,
  clipBehavior not read (FW defaults hardEdge, PanAxis.free, EdgeInsets.zero, constrained true; interactive_viewer.dart
  :67,71-88). Scale clamped (:658); pan bounded by child rect + boundaryMargin (:515-526) → no pan at scale 1; enabled
  checks :680-681; scaleEnabled false forces scale 1 (:690).

## 3. Registry and capabilities
schema/widget-registry.json has all 11 (AbsorbPointer :7, BackdropFilter :424, BlurView :486, ClipOval :898, ClipRect :914,
ColorFiltered :954, DecoratedBox :1197, IgnorePointer :2022, InteractiveViewer :2198, Opacity :2460, RotatedBox :2850).
Neither native capabilities.json (44 each) lists any. Flutter kSupportedWidgets includes all (sdk/lib/src/capabilities/
generated.dart:21). Engine degrade: missing type → widget.<Type> (capability-filter.ts:209-211), graceful default
(fallback-policy.ts:50): node dropped, children hoisted (capability-filter.ts:400-437); structure slot child → warn
(:141-152). No per-widget substitute. Client unknown type → FallbackPrompt (Swift PageRenderer.swift:54-68,144-147;
Kotlin PageRenderer.kt:63, degradedFrom :196). Pins 44 → 55: Swift StructureWidgetTests.swift:258-263 (+ :266-277 branch
check), CapabilitiesTests.swift:41-46; Kotlin CapabilitiesTest.kt:64-67,94, WidgetBuildersTest.kt:15-22, WidgetBuilders.kt
:102-111 doc comment.

## 4. Native today: none drawn (Swift NodeView.swift:61-107 default :104-106; Kotlin WidgetBuilders.kt:112-158, missing
builder logged, NodeView.kt:47-55). Reuse: Swift BoxDecorationProps (Box.swift:66-137), DecorationBackground (:141-178)
as .background/.overlay (NOT ContainerView: border inset :208); Kotlin BoxDecorationProps.of (Decoration.kt:140-151),
Modifier.boxDecoration (:184-211, behind only; foreground needs drawWithContent); ContainerWidget adds border to padding
(Box.kt:47,54-61). Clip: Swift ClipRRectView .clipShape(CornersShape) (Stack.swift:174-182), ClipIf (Box.swift:240-250);
Kotlin ClipRRectWidget Modifier.clip (Box.kt:77-82). Colour Props.color (Swift Props.swift:10-21, Kotlin Props.kt:44-59).
Blend: Swift none; Kotlin ColorFilter.tint(c, SrcIn) in Image.kt:119. Opacity: Swift .opacity (Flow.swift:112); Kotlin
graphicsLayer (Motion.kt:136-157). Rotation paint-only: Swift TransformView rotationEffect (Motion.swift:146); Kotlin
graphicsLayer.rotationZ (Motion.kt:143-149). Custom measure patterns: Swift OffstageLayout (Flow.swift:121-136),
FittedLayout (Sizing.swift:334-353); Kotlin Modifier.layout (Motion.kt:168), Offstage MeasurePolicy (Flow.kt:178-196).
Hit testing: Swift .allowsHitTesting (Flow.swift:113), GestureNodeView contentShape+onTapGesture (Stack.swift:189-212);
Kotlin GestureDetectorWidget pointerInput detectTapGestures (Gesture.kt:31-56), CardWidget empty pointerInput takes
touches (Structure.kt:394-403). Blur: Swift only content blur (Box.swift:152), no Material; Kotlin none. Pinch: none
(Swift DragGesture only DrawerPanel.swift:250,295; Kotlin CFD Transformable.kt available).

## 5. Fixtures: 44 files (01-42, 60, 61); none holds the 11; next is 43_…; pins 44 → 45: Swift ModelRoundTripTests.swift:10,
Kotlin ModelRoundTripTest.kt:32, FixturePathsTest.kt:13; Flutter lists the dir (fixture_paths.dart:20-29), no pin.

## 6. Test patterns. Swift: Pixels (TextStyleTests.swift:243-300, premultiplied RGBA, pixel(x,y) :280-283 reads alpha,
bounds(of:) :294); isGreen/isBlue/isRed; LayoutTests.draw ImageRenderer scale 1 (:198-213), hosted UIWindow (:216-238);
no SwiftUI tap injection, only window.hitTest with a UIKit probe (FlowTests.swift:197-212, hosted :401-418). Kotlin:
Robolectric SDK 34, createComposeRule, @Config mdpi (LayoutTest.kt:34,37); BoxTest pixels need @GraphicsMode(NATIVE)
(:194), draw(view) software canvas on white (:230-235), assertPixel RGB only tol 0.05 (:237-249); captureToImage times out
(GoldenTest.kt:98-110); taps performTouchInput click (FlowTest.kt:340-363; GestureDetectorTest :67-160).

## 7. Demo: parity-a.ts header :52-58; imports :15-50; colours :60-65; helpers section :73, box :92, block :97-105,
caption :107; layoutPage :642-866; routes :917-927; index.ts URL lines :102-105; engine test model
engine/test/parity-a-layout.test.ts (WRAPPERS :11-25, PAGES :26, nativePage :54-67). New page `effects` +
parity-a-effects.test.ts.

## 8. Risks: Android blur below 12 ignored (Blur.kt:75-76), minSdk 24 → tinted scrim; Compose has no backdrop API (blur
behind needs capture). iOS: no sigma backdrop; Material only (fixed strengths) or content .blur; shaders iOS 17+ (floor
16). Flutter BackdropFilter unclipped vs natives clipped to bounds (document). Blend modes: SwiftUI view BlendMode lacks
srcIn/dstIn/dstATop (GraphicsContext has them, Canvas only); Compose below API 29 maps only Porter-Duff + a few
(AndroidBlendMode.android.kt:43-67). RotatedBox needs a measuring layout on both. AbsorbPointer: Compose child detectors
still get events (needs Initial-pass consume); SwiftUI blocking behind unverified; Swift tests cannot inject taps.
Opacity 0 still hit-testable in Flutter. InteractiveViewer: no pan at scale 1, clips hardEdge; gesture conflicts in
scroll views. Demo: use #RRGGBBAA strings, not Color().
