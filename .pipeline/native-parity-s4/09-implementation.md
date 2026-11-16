# 09 · Implementation · native-parity-s4

## Front page

### In one breath
group 3 of 6 · tasks: 5 green, 0 blocked · A4.1, A4.2 and ColorFiltered (A4.3) green on both SDKs
Opacity, RotatedBox, the clips, DecoratedBox, ColorFiltered: pixels, sizes and taps as Flutter.

### New for you
nothing new

### Trade-offs
4 auto-decided (minor): Swift draws opacity below 0.02 invisibly so taps still land (Flutter keeps
them); DecoratedBox takes taps over its whole (rounded) box, filled or not; one shared hit fill on
Swift; Kotlin RotatedBox answers intrinsics with swapped axes (a Row sized it 300 tall, not 60).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 4, AbsorbPointer and IgnorePointer (running on both SDKs). (default: go)

## Appendix

Cases count: 5 rows split per SDK = 10 cells, plus the fixture half (F1) and the engine half (D1); a row is ticked in
phase-a-tests.md only when every half passes on both SDKs and the hand checks agree.

### Group 1
Commits: F1 2aac5b4 (staged by path). Nothing pushed. Gate 08 approved under the standing rule (all defaults, q3
adjusted). Baseline: feat/native-parity-s3 2179ff2 (engine 751, Flutter 331, Swift 240 + 368, Kotlin core 369, sdk 348).

#### Task F1 · Fixture 43 and native count pins
Files: `schema/fixtures/render/43_effects_and_touch.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift`
· `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `.../core/FixturePathsTest.kt`
Cases: A4.1-A4.5 fx → green. Red first: the three pins at 44 failed with 45. Engine conformance 45 pass, whole `bun
test` 752; Flutter `test/conformance/` all pass including "43_effects_and_touch.json · resolved props"; Swift
`ModelRoundTripTests|ResolverFixtureTests` 11/0, `swift test` 368 + 240; Kotlin `:core:check` 369/0.
Changed: a Column holding all 11, each around a Text, every wire prop (Opacity 0.5, RotatedBox 1, ClipOval, ClipRect,
DecoratedBox color/radius 8/border/shadow + position foreground, ColorFiltered #FF0000 multiply, BackdropFilter 4/6,
BlurView 8/8 #FFFFFF80 radius 12, AbsorbPointer false, IgnorePointer bound to pageState `ignore`, InteractiveViewer
0.5/4 pan false); `expected` is the engine's output unedited; `resolved` covers the 11 ids.
Decisions: overlay "#FFFFFF80" (RRGGBBAA, alpha last); no gradient on DecoratedBox (optional); `resolved` from a
scratchpad generator (wire props with the page-state Value replaced), checked by all three resolvers.
Review: main session (one reviewer, both lenses; a small, mechanical task): every wire prop in inventory §1 present
(checked with jq), `expected` engine-generated, runners green · pass
Not done: nothing.

### Group 2
Commits: S-blur 125b279, K-blur 9af6b77 (staged by path). Nothing pushed. Gate 09 group 1 approved under the standing
rule. Main moved meanwhile: PR #40 (step 3) and PR #37 merged; s3 closed (929c471); the rebase on main 6a7f0e0 waits
for a clean tree (no overlap: #37 touched only pin lines next to F1's).

#### Task S-blur · Swift BackdropFilter and BlurView, materials
Files: `sdk-swift/Sources/OrcaGateway/Widgets/Backdrop.swift` (new) · `.../OrcaGateway/NodeView.swift` ·
`sdk-swift/Tests/OrcaGatewayTests/BackdropTests.swift` (new)
Cases: A4.3 sw (BackdropFilter, BlurView) → green: BackdropTests 8/8 on the simulator (6 on macOS); `swift test` 246 +
368; iOS scheme 291 + 368, goldens unchanged, 0 warnings. Red first except the no-child test (a type with no builder
already drew nothing) and the BackdropFilter tap-through (Flutter's default already held).
Changed: `BackdropStrength` picks one of five materials from max(blurX, blurY) (10 when missing); BackdropFilter = the
child over the material (no taps) at the child's box, child not clipped (D9); BlurView = material, overlay, child cut
to RoundedRectangle(.circular), with an invisible rectangle fill outside the clip that takes every tap in the box.
Decisions: hit testing as Flutter (ColoredBox opaque, basic.dart:8392-8394; RenderClipRRect cuts hits only with a
custom clipper, proxy_box.dart:1736-1746); `.contentShape` did not cut hits on the UIKit-backed material, hence the
0.001 fill; no child → nothing drawn or laid out.
Review: fit (rework 2: my first rework cut BlurView hits to the radius, Flutter does not) · quality pass (nits folded:
shared Pixels.isRed, the fill's own comment) · pass
Not done: the blur itself (drawHierarchy fails in the SwiftPM host, layer.render omits CABackdropLayer): hand check.

#### Task K-blur · Kotlin blur behind via page recording
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Backdrop.kt` (new) · `.../sdk/OrcaPageView.kt` ·
`sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/BackdropTest.kt` (new)
Cases: A4.3 kt (BackdropFilter, BlurView) → green: BackdropTest 17/0; GoldenTest 3/0 and NativeWidgetsPageTest 3/0, no
golden moved; `./gradlew build` core 369, sdk 365, lint 0 errors. Red first except two pins of behaviour already right
(proven by mutation).
Changed: `backdropBlurs(apiLevel)` (31+), `blurRadius(sigma, density)` = (σ·d − 0.5)/0.57735; BackdropRecorder +
LocalBackdropRecorder; OrcaPageView wraps its root in BackdropRecording, which records the page into a Picture only
while it blurs and a backdrop is registered, and again on each nested scroll; each backdrop draws its part blurred in
its own GraphicsLayer (60% white scrim below 31 or without a recorder), skipping itself by the canvas it draws into.
BlurView clips drawing only and takes every tap over its rectangle; BackdropFilter takes none and does not clip its
child.
Decisions: s4-kotlin-picture-recording, s4-kotlin-scroll-rerecord, s4-blur-hit-testing, s4-kotlin-copy-limits.
Proven here: the software canvas replays the recording (the copy lines up, the red/blue edge at x=30); PixelCopy goes
through Robolectric's hardware renderer, so the blur, its clip and the scroll case are proven too.
Review: fit pass (notes: siblings above a backdrop show in its copy; translation only; box-sized edges: documented) ·
quality should-fix (KDoc claimed Flutter's copy) folded with two pins and two tidy-ups (rework 2) · pass
Not done: still stale behind a fixed backdrop: animations, code-driven scrolls, state changes inside a scroll view's
layer. Hand check: blur strength against Flutter's sigma, cost while scrolling, scrim on a real Android 11 (q3: forced
in unit tests only).

### Group 3
Commits: S-paint 0d2f8d5, K-paint f7f4030 (staged by path). Nothing pushed. Gate 09 group 2 approved under the
standing rule. S-paint started while K-blur was in rework (disjoint files); the rebase on main still waits for a clean
tree.

#### Task S-paint · Swift opacity, rotation, clips, decoration, filter
Files: `sdk-swift/Sources/OrcaGatewayCore/Render/BlendModes.swift` (new) · `.../OrcaGatewayCoreTests/BlendModesTests.swift`
(new) · `sdk-swift/Sources/OrcaGateway/Widgets/Effects.swift` (new) · `.../NodeView.swift` ·
`sdk-swift/Tests/OrcaGatewayTests/EffectsTests.swift` (new); approved outside the row: `Widgets/Backdrop.swift`
(hitFill) and `OrcaGatewayTests/BackdropTests.swift` (empty renders over a page colour).
Cases: A4.1 sw, A4.2 sw, A4.3 sw (ColorFiltered, core) → green: BlendModesTests 4, EffectsTests 22; `swift test` 259 +
372; iOS scheme 313 + 372, 0 warnings, no golden moved. Red first, except guards that pinned behaviour already right
(clips take no taps of their own, the mapping table, the white-page blend).
Changed: OrcaBlendMode (21 names, srcATop otherwise); HitTestableOpacity; RotatedLayout (flipped proposal, tight and
unbounded axes swapped on odd turns, turned about the centre, smallest size with no child); ClipRect/ClipOval
(clipShape + contentShape, which takes no tap itself); DecoratedBoxView (one chain: background or overlay, no border
inset, Shape.hitFill over the (rounded) box); ColorFilteredView (SwiftUI blend modes, srcIn/dstIn/dstATop composed).
Decisions: s4-swift-opacity-floor, s4-decoratedbox-hits, s4-hitfill-helper; core enum named OrcaBlendMode (no clash
with SwiftUI's); srcIn without a mask (child drawn once). Intrinsics: IntrinsicHeight probes through sizeThatFits,
which RotatedLayout already swaps.
Review: fit pass (notes folded: foreground radius hit case, clip tap-through test) · quality rework (orcaUnbounded swap,
white-page blend test, one DecoratedBox chain, Color spelling, mapping table, hitFill, BackdropTests page colour) · pass
Not done: nothing. ImageRenderer can return a stale image for an empty render: "nothing drawn" checks draw over a
page colour.

#### Task K-paint · Kotlin opacity, rotation, clips, decoration, filter
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/BlendModes.kt` (new) · `.../render/BlendModesTest.kt`
(new) · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Effects.kt` (new) · `.../sdk/style/Decoration.kt` ·
`sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/EffectsTest.kt` (new)
Cases: A4.1 kt, A4.2 kt, A4.3 kt (ColorFiltered, core) → green: BlendModesTest 4, EffectsTest 12; `./gradlew build`
core 373, sdk 377, lint clean; GoldenTest and BoxTest unchanged, no golden moved. Red first (by compile, then the
intrinsics case: 300 tall before the fix).
Changed: OrcaBlendMode (same cases as Swift's); OpacityWidget (graphicsLayer alpha, taps kept at 0);
RotatedBoxMeasurePolicy (swapped constraints and intrinsics, placeWithLayer only when turned); ClipRect/ClipOval
(clip, oval by addOval); DecoratedBox (boxDecoration or the new foregroundDecoration, no padding; a matchParentSize
clip(shape).pointerInput {} node takes the taps); ColorFiltered (offscreen layer + drawRect in the mode; the 21 mapped
to Compose; below API 29 only PorterDuff modes, documented). Decoration.kt: boxDecoration's body moved into `surface`,
drawing exactly as before.
Decisions: s4-decoratedbox-hits, s4-kotlin-rotated-intrinsics; foreground shadows drawn after the child.
Review: fit pass (48 dp note) · quality pass with one should-fix (intrinsics) and nits, folded · pass
Not done: nothing. Known: ColorFiltered's layer is the box's size (a child's overflow is cut; Flutter's is unbounded);
below API 29 "multiply" paints the colour over the child (Modulate would be closer: follow-up); Compose's 48 dp
minimum touch target can give a small target a tap just outside its shape, SDK-wide.
