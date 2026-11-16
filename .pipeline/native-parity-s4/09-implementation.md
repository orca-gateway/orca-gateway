# 09 · Implementation · native-parity-s4

## Front page

### In one breath
group 2 of 6 · tasks: 3 green, 0 blocked · A4.3 blur half green on both SDKs (unit + ui)
S-blur: a system material by sigma, cut to the radius. K-blur: the page recorded, then blurred.

### New for you
nothing new

### Trade-offs
4 auto-decided (minor): Kotlin records the page into a Picture (the design's GraphicsLayer copy
vanished inside scroll views); a nested-scroll hook re-records it so a fixed bar follows a list;
BlurView takes taps over its whole box, BackdropFilter none (Flutter's hit rules); the Kotlin copy's
limits are documented (siblings above show in it; translation only).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 3, Opacity, RotatedBox, clips, DecoratedBox, ColorFiltered (running). (default: go)

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
