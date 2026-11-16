# native-parity-s4 · design in force (plan step 4, written at stage 08; 05-07 skipped)

Repo: /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/native-parity-phase-a-35cc97 (paths below from
there), branch feat/native-parity-s4 stacked on feat/native-parity-s3 at 2179ff2 (step 3 is PR #40, not merged yet; rebase when it is).
Flutter (`sdk/`) is the reference. Inventory with every file:line: .pipeline/native-parity-s4/inventory.md. Swift deploys
to iOS 16 / macOS 13; Kotlin minSdk 24.

## Cases (phase-a-tests.md rows, after corrections)
- A4.1 Opacity 0.5 is half transparent. RotatedBox with one quarter turn swaps the layout width and height. ui
- A4.2 ClipOval and ClipRect cut off overflow. DecoratedBox paints its decoration without adding padding. ui
- A4.3 ColorFiltered applies colour and blend mode. BackdropFilter and BlurView blur what is behind (a tinted scrim
  below Android 12; on iOS a system material whose strength follows the sigma; the natives clip the blur to the
  widget's box, documented). ui + hand  [note: iOS material, clip]
- A4.4 AbsorbPointer blocks taps for its child and for what is behind. IgnorePointer lets taps pass to what is behind.
  ui
- A4.5 InteractiveViewer zooms by pinch within minScale and maxScale (defaults 0.8 and 2.5), never out past where its
  child covers it (interactive_viewer.dart:652-658), and, once zoomed in, pans within its child's bounds (Flutter's boundaryMargin is zero, so at scale 1 nothing pans). hand + unit
  [corrected: pan bounds]

## Decisions
- D1 Contract. No wire change: all 11 are in the schema, the engine, the registry and Flutter. One render fixture
  `schema/fixtures/render/43_effects_and_touch.json` holding all 11 with every wire prop (Opacity 0.5, RotatedBox 1,
  ClipOval, ClipRect, DecoratedBox with color, radius, border, a shadow and position foreground, ColorFiltered with a
  colour and blendMode multiply, BackdropFilter 4/6, BlurView 8/8 with overlayColor and borderRadius, AbsorbPointer
  false, IgnorePointer (default), InteractiveViewer 0.5/4 pan false) and a `resolved` block. Pins 44 → 45 (Swift
  ModelRoundTripTests :10; Kotlin ModelRoundTripTest :32, FixturePathsTest :13).
- D2 Capabilities (A4.x unit). Both capabilities.json gain the 11 (44 → 55, sorted), one generator run; every pin
  moves (Swift StructureWidgetTests :258-277, CapabilitiesTests :41-46; Kotlin CapabilitiesTest :64-67,94,
  WidgetBuildersTest :15-22, WidgetBuilders.kt doc :102-111). Advertised once, in the last group. Engine test
  `engine/test/parity-a-effects.test.ts` (copy of parity-a-layout.test.ts): each native vector gets page `effects`
  whole.
- D3 Behaviour = Flutter's builder (inventory §2), defaults included: Opacity 1, hit-testable at any opacity; RotatedBox
  quarterTurns 0, laid out with flipped constraints, size swapped on odd turns, rotated about the centre; ClipRect
  hard edge, ClipOval the inscribed ellipse, both clip hits too; DecoratedBox draws the decoration behind (or in front
  with `foreground`) at the child's size, no border inset; ColorFiltered `mode(color, blendMode)`, 21 names, missing or
  unknown → srcATop, colour default transparent (so the child is unchanged); BackdropFilter blur 10/10 by default;
  BlurView = clip(radius) > blur behind > overlay colour > child; AbsorbPointer and IgnorePointer default true;
  InteractiveViewer 0.8/2.5, pan and scale on, scale clamped, pan bounded by the child's rect, clips its child.
- D4 Pure cores. `BlendModes` (the 21 names → an enum, default srcATop) and `ViewerTransform` (pinch scale clamped to
  [min, max], scaleEnabled false keeps 1; pan offset bounded so the scaled child always covers the viewport; at scale 1
  the offset is 0) in both cores with the same cases, like WrapRuns. The UI layers only draw and feed gestures.
- D5 Swift. `.opacity`; RotatedBox a Layout that proposes the flipped size, reports the swapped size and rotates by
  quarter turns about the centre; `.clipShape(Rectangle())` / `.clipShape(Ellipse())` plus `.contentShape` of the same
  shape; DecoratedBox `DecorationBackground` as `.background` or `.overlay` (no ContainerView); ColorFiltered: the
  colour composited over the child in a `compositingGroup` with SwiftUI's blend mode where one exists, srcIn as the
  colour masked by the child, dstIn as the child at the colour's alpha, dstATop and the rest by composition; backdrop
  blur by `Material` (strength from the sigma: ≤ 3 ultraThin, ≤ 8 thin, ≤ 16 regular, ≤ 24 thick, else ultraThick),
  BlurView clipped to its radius with the overlay colour above the material; AbsorbPointer the child
  `.allowsHitTesting(false)` under a clear layer that takes taps, IgnorePointer `.allowsHitTesting(false)`;
  InteractiveViewer `MagnifyGesture` (iOS 17+) / `MagnificationGesture` (iOS 16) + `DragGesture`, scale and offset from
  the core's ViewerTransform, clipped.
- D6 Kotlin. `graphicsLayer(alpha)`; RotatedBox a `Modifier.layout` measuring with swapped constraints and a
  rotationZ about the centre; `clip(RectangleShape / CircleShape-as-oval)` plus hit clipping; DecoratedBox draws with
  `drawBehind` / `drawWithContent` (foreground), reusing the decoration drawing without ContainerWidget's padding;
  ColorFiltered `graphicsLayer(compositingStrategy = Offscreen)` + `drawWithContent { drawContent(); drawRect(color,
  blendMode) }` (API < 29: only the modes Android maps, documented); backdrop blur: the page root records its content
  into a `GraphicsLayer`, a BackdropFilter/BlurView draws the part behind it blurred with a RenderEffect on API 31+ (a
  translucent scrim of the overlay colour below 31), skipping itself while recording; AbsorbPointer consumes every
  pointer event in the Initial pass over its box (child and siblings behind get nothing), IgnorePointer lets events
  through to what is behind and keeps them from its child (a CompositionLocal the SDK's tap builders read, or a node
  that does not take hits: the implementer proves the sibling-behind case in a test); InteractiveViewer
  `detectTransformGestures` fed into the core's ViewerTransform, clipped.
- D7 Demo. Page `effects` on parity-a (one section per row; colours as "#RRGGBB" strings, never `Color()`): Opacity
  over a checked background, RotatedBox in a measured box, clips around overflowing stripes, DecoratedBox beside a
  Container with the same decoration, ColorFiltered multiply and srcIn over a coloured logo, BackdropFilter and BlurView
  over stripes, AbsorbPointer and IgnorePointer over a counter button in a Stack above another counter button,
  InteractiveViewer around a numbered grid. Hand checks at the end on both devices.
- D8 Tests per row: Swift ImageRenderer pixels (alpha for Opacity; Pixels helper) and hosted UIWindow where materials,
  hits or gestures matter; Kotlin Robolectric `@GraphicsMode(NATIVE)` pixels and `performTouchInput`. Each row's check
  named `testA4_N…` / `a4_N_…`. No golden moves unless a task row lists it.
- D9 Row corrections: A4.3 note (iOS material, natives clip to the box; Flutter's BackdropFilter reaches the nearest
  ancestor clip, basic.dart:499-501), A4.5 corrected (pan bounded by the child, interactive_viewer.dart:515-526).
