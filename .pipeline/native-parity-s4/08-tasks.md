# 08 · Tasks · native-parity-s4

## Front page

### In one breath
tasks: 12 in 6 groups · widest group: 3 · cases: 5 of 5 placed
Plan step 4 on both SDKs: the 11 effect and touch wrappers, drawn and hit-tested as Flutter does.
G1 fixture 43. G2 BackdropFilter, BlurView (riskiest first). G3 Opacity, RotatedBox, clips,
DecoratedBox, ColorFiltered. G4 AbsorbPointer, IgnorePointer. G5 InteractiveViewer, demo page.
G6 both SDKs advertise the 11 (44 → 55). Hand checks on both devices follow.

### New for you
nothing new

### Trade-offs
All minor under the standing rule, decided by default. Closest to major: q6, Android's page
root records the page so a blur can draw what is behind (OrcaPageView.kt:73-74; goldens guard it).

### Questions for you
1. Commands: every suite as at baseline; Swift on macOS and iOS 18.5. (default: as found)
2. One commit per task, one gate per group; nothing pushed before stage 10. (default: yes)
3. Hand checks on the iPhone and Android API 34; below-12 scrim proven in unit tests. (default: yes)
4. One Swift and one Kotlin task per group; blur first; touch and zoom separate. (default: yes)
5. Advertise the 11 once, in G6; Kotlin registers them in standard() there too. (default: yes)
6. Android records the page root only while a BackdropFilter or BlurView is on it. (default: yes)
7. Below Android 12, a white scrim at 60% replaces the blur; the overlay sits above. (default: yes)
8. Swift's material strength follows the larger of blurX and blurY (10 → regular). (default: yes)
9. A4.5 as Flutter: no zoom out past where the child covers the viewer; no fling. (default: yes)
10. Engine check "each native vector gets the effects page whole" red from G5 to G6. (default: yes)
11. Rows as corrected (D9 + q9); the main session writes them into phase-a-tests.md. (default: yes)

## Appendix

### Where step 4 comes from
Plan /Users/amrebada/.claude/plans/native-parity/plan.md:74-81 (Phase A step 4, S, 11 widgets); stages 01-07 skipped.
Design in force: .pipeline/native-parity-s4/design.md (D1-D9, rows A4.1-A4.5 after corrections). Facts:
.pipeline/native-parity-s4/inventory.md. Branch feat/native-parity-s4 on feat/native-parity-s3 2179ff2 (PR #40). No
wire change. Planner: pipeline:build-task-planner (fresh); plan accepted, with q3 changed by the main session: no
Android 11 (API 30) system image is installed here (only 34, 36, 37), and fetching one is a ~1 GB download, so the
below-12 path is proven in unit tests by forcing it, and a device check on Android 11 is left optional for the user.

### Groups (paths from the repo root; sw/kt = Swift/Kotlin half, fx fixture, eng engine, hand device check)
| # | Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|---|
| 1 | 1 | F1 | Fixture 43 and native count pins | schema/fixtures/render/43_effects_and_touch.json (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt | A4.1-A4.5 fx | M | — |
| 2 | 2 | S-blur | Swift BackdropFilter and BlurView, materials | sdk-swift/Sources/OrcaGateway/Widgets/Backdrop.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/BackdropTests.swift (new) | A4.3 sw (BackdropFilter, BlurView) | M | — |
| 3 | 2 | K-blur | Kotlin blur behind via page recording | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Backdrop.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageView.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/BackdropTest.kt (new) | A4.3 kt (BackdropFilter, BlurView) | M | — |
| 4 | 3 | S-paint | Swift opacity, rotation, clips, decoration, filter | sdk-swift/Sources/OrcaGatewayCore/Render/BlendModes.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/BlendModesTests.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Effects.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/EffectsTests.swift (new) | A4.1 sw, A4.2 sw, A4.3 sw (ColorFiltered, core) | M | — |
| 5 | 3 | K-paint | Kotlin opacity, rotation, clips, decoration, filter | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/BlendModes.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/BlendModesTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Effects.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/style/Decoration.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/EffectsTest.kt (new) | A4.1 kt, A4.2 kt, A4.3 kt (ColorFiltered, core) | M | — |
| 6 | 4 | S-touch | Swift AbsorbPointer and IgnorePointer | sdk-swift/Sources/OrcaGateway/Widgets/Touch.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/TouchTests.swift (new) | A4.4 sw | M | — |
| 7 | 4 | K-touch | Kotlin AbsorbPointer and IgnorePointer | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Touch.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/TouchTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Gesture.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Buttons.kt | A4.4 kt | M | — |
| 8 | 5 | S-zoom | Swift InteractiveViewer and ViewerTransform | sdk-swift/Sources/OrcaGatewayCore/Render/ViewerTransform.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ViewerTransformTests.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Viewer.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/ViewerTests.swift (new) | A4.5 sw (core unit + ui) | M | — |
| 9 | 5 | K-zoom | Kotlin InteractiveViewer and ViewerTransform | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/ViewerTransform.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/ViewerTransformTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Viewer.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ViewerTest.kt (new) | A4.5 kt (core unit + ui) | M | — |
| 10 | 5 | D1 | Demo page effects on parity-a | examples/server/parity-a.ts · examples/server/index.ts · engine/test/parity-a-effects.test.ts (new) | A4.x eng, A4.1-A4.5 hand | M | — |
| 11 | 6 | S-caps | Swift advertises the 11 wrappers | sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift | A4.x unit sw (caps) | M | S-blur, S-paint, S-touch, S-zoom |
| 12 | 6 | K-caps | Kotlin registers and advertises the 11 | sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt | A4.x unit kt (caps) | M | K-blur, K-paint, K-touch, K-zoom |

Placed: A4.1, A4.2 F1 then S-paint/K-paint; A4.3 F1, S-blur/K-blur, S-paint/K-paint (ColorFiltered); A4.4 F1 then
S-touch/K-touch; A4.5 F1 then S-zoom/K-zoom (unit + ui); caps S-caps/K-caps; eng D1; hand on D1's page after G6. Test
names `testA4_N…` / `a4_N_…`.

### Order and expected reds
- G1: F1 moves the three pins 44 → 45 (Swift ModelRoundTripTests.swift:10; Kotlin ModelRoundTripTest.kt:32,
  FixturePathsTest.kt:13; red), then writes fixture 43 (green): all 11 with every wire prop (D1), a `resolved` block,
  one prop bound to page state, colours as "#RRGGBB". Engine and Flutter runners list the directory
  (fixture_paths.dart:20-29). D1 cannot share G1 (demo-server.test.ts:15 spawns index.ts while F1 runs the engine
  suite). Red at the gate: none.
- G2 (riskiest first; groups exist only for one build tree per SDK). S-blur: the material choice is a unit-tested
  function (≤3 ultraThin, ≤8 thin, ≤16 regular, ≤24 thick, else ultraThick, from the larger sigma, default 10, q8);
  ImageRenderer pixels with sized children (box = child's size, nothing drawn outside, BlurView's overlay above with
  its child on top, cut to borderRadius); a hosted UIWindow snapshot (drawHierarchy) for "the stripes behind blur only
  inside the box" (FlowTests' layer.render, FlowTests.swift:420-427, does not draw backdrop layers; if the simulator's
  snapshot shows no material, that check moves to the hand check). K-blur: Backdrop.kt holds a recorder provided by
  OrcaPageView around NodeView (:73-74) and both builders; a backdrop skips itself while recording. Robolectric (SDK 34,
  @GraphicsMode(NATIVE), software draw, GoldenTest.kt:105-110) proves: the API split as a pure function and, on the
  scrim path (forced), the scrim drawn; the layer order (clip, copy, overlay, child, cut to borderRadius); the overlay
  drawn once (50% red over white reads #FF8080, not #FF4040: the copy holds no backdrop); taps reach the child; sigma
  → radius; pages without a backdrop draw as before (GoldenTest.kt:48-79, three goldens, unchanged); whether the copy
  lines up with the page beneath only if the software canvas draws a recorded GraphicsLayer (the digest says which).
  It cannot prove the blur itself (no RenderEffect in software), its strength against Flutter's sigma, the copy
  following scroll and animation, cost per frame, or a real Android 11: hand checks on page `effects` (q3). Red at
  the gate: none (caps pins stay 44).
- G3: BlendModes in both cores, same cases (21 names; missing, unknown, wrong case → srcATop). S-paint/K-paint:
  Opacity 0.5 half alpha (Swift Pixels alpha; Kotlin RGB on white), default 1, still takes taps at 0 (Flutter, see
  Findings 6); RotatedBox 1 turn lays out a 60×20 Container as 20×60, 2 turns keep its size, no child takes the
  smallest size; ClipRect/ClipOval cut an 80×80 Container in a 40×40 box, hits outside the oval miss; DecoratedBox
  exactly the child's size, no border inset (unlike ContainerView, Box.swift:212), foreground over the child;
  ColorFiltered multiply, srcIn, dstIn, dstATop, srcATop on a two-colour child, the transparent default leaves it
  unchanged. Swift hit cases in a hosted UIWindow. Red: none.
- G4: S-touch tests only in a hosted UIWindow with UITextField probes (FlowTests.swift:200-213, :401-418): a Stack, a
  sized Container with a field behind, the wrapper around a sized Container with a field; a hit in the overlap finds
  no field (Absorb), the child's (absorbing false), the one behind (Ignore), the child's (ignoring false). K-touch:
  the same with performTouchInput and counters; children a GestureDetector and an ElevatedButton; the IgnorePointer
  route is open (Findings 4). Red: none.
- G5: ViewerTransform in both cores, same cases (Findings 5). S-zoom: no gesture injection; draws at rest and at a
  preset transform (internal initial state) with a sized child bigger than the viewer, clipped. K-zoom: Robolectric
  pinch and swipe: pinch stops at maxScale; a swipe at scale 1 moves nothing; zoomed in, the pan stops at the
  child's edge; the flags turn pinch and pan off. D1: page `effects` per D7 ("#RRGGBB" strings, helpers/color.ts:12-16;
  the numbered grid from Wrap, Row, Container, Text; header parity-a.ts:55, route beside :924-925, URL after
  index.ts:105; test copies parity-a-layout.test.ts :11-26, :54-68, :79-98). Expected red at the G5 gate: "A4 each
  native vector gets the effects page whole, no FallbackPrompt" (both vectors list 44); "the effects page holds all
  11" passes.
- G6: S-caps adds the 11 (sorted), runs the generator, moves CapabilitiesTests.swift:39-46 and
  StructureWidgetTests.swift:256-264 to 55 (the branch check :266-278 then covers the 11). K-caps registers the 11 in
  standard() (WidgetBuilders.kt:112-159) in the same commit as the list, moves the doc comment :102-111 and
  CapabilitiesTest.kt:59-67, :84-94 (WidgetBuildersTest.kt:15-23 compares sets, no edit). Each adds `a4` caps checks
  red first; c1 red until both land; D1's red waits for both. Red at the gate: none. Hand checks follow.

### Seams
- gen-native-capabilities.ts writes both Generated files in one run (:237,244,261); S-caps stages only Generated.swift,
  K-caps only Generated.kt; whichever finishes last reruns the generator so both are clean at the G6 gate.
- NodeView.swift: S-blur, S-paint, S-touch, S-zoom (one per group). WidgetBuilders.kt: only K-caps. OrcaPageView.kt:
  only K-blur. Decoration.kt: only K-paint. Gesture.kt, Buttons.kt: only K-touch. No golden listed; if one moves, the
  task stops.

### Findings (planner)
1. Both clients degrade types they lack, so G2-G5 tests widen the registry (Swift as PluginWidgetTests.swift:67,
   Kotlin as BoxTest.kt:56); Kotlin builders test-local with a testTag (FlowTest.kt:88-110). Swift's switch check is
   one-way (StructureWidgetTests.swift:266-278); Kotlin's both ways (WidgetBuildersTest.kt:15-23).
2. Kotlin goldens draw through OrcaPageView (GoldenTest.kt:52-55, :88-95), so K-blur's recorder is under their guard
   (q6). The copy holds only what OrcaPageView draws: a route title bar (OrcaApp.kt:490-501) is outside it. A test
   hosting NodeView directly (FlowTest.kt:111-116) has no recorder, so K-blur's tests wrap their page in one.
3. Flutter blurs by sigma; Swift's shadows convert radius to sigma (0.57735·r + 0.5, Box.swift:151-152); K-blur
   inverts that for RenderEffect.
4. Compose: a pointer node takes the touch and hides what is behind (Card on purpose, Structure.kt:394-403). Switching
   off the SDK's tap builders (Gesture.kt:42-52, Buttons.kt:78,97,113) may still leave surfaces taking hits; K-touch's
   IgnorePointer test with a sibling behind decides the route; if none passes, K-touch stops and reports.
5. Flutter's InteractiveViewer: the scale is clamped after a floor of max(viewport/child) (interactive_viewer.dart
   :652-658), so a child filling the viewer never goes below 1 whatever minScale says; the focal point stays put
   (:753-765); no pan at scale 1 (:591-624); a child larger on one axis pans on that axis only (:619-638); flags read
   at :680-681, :690.
6. Flutter's Opacity 0 still takes taps (RenderOpacity has no hitTest override, proxy_box.dart:886); UIKit's hitTest
   skips views with alpha below 0.01, so S-paint's hosted case decides. Offstage pairs both on purpose
   (Flow.swift:112-113).
7. K-paint: boxDecoration draws only behind the content (Decoration.kt:184-207, :202); the foreground needs a
   drawWithContent variant there. Swift reuses DecorationBackground (Box.swift:141-178).

### Done when
engine `bun test`; `flutter test` + `flutter analyze`; `swift test` (macOS) and the iOS scheme on DA7254F5; Kotlin
`./gradlew build --console=plain`; the three generators leave no diff; goldens unchanged; one commit per task by path,
one gate per group; hand checks after G6 (q3).

### Not planned (on purpose)
Flutter's unclipped BackdropFilter (natives clip to the box, D9, documented); Kotlin drawers, snackbars and a route
title bar do not show through a blur, and a backdrop under another one is seen unblurred in the upper copy; Kotlin
ColorFiltered below API 29 only the modes Android maps (documented; Robolectric runs SDK 34 only,
robolectric.properties:1); Swift blur strength in five material steps (iOS 16 floor); InteractiveViewer boundaryMargin,
constrained, clipBehavior, panAxis, callbacks (Flutter's builder reads none, layout_builders.dart:636-644), fling
inertia (interactive_viewer.dart:811+, q9), wheel zoom (:893-964), rotation (off in Flutter, :513). Row corrections:
written into phase-a-tests.md by the main session.
