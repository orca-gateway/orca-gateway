# native-parity-s3 · design in force (plan step 3, written at stage 08; 05-07 skipped)

Repo: /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/native-parity-phase-a-35cc97 (paths below from
there), branch feat/native-parity-s3 from origin/main 3cdeef7 (step 2 merged as PR #36). Flutter (`sdk/`) is the
reference. Inventory with every file:line: .pipeline/native-parity-s3/inventory.md. Swift deploys to iOS 16 / macOS 13;
Kotlin minSdk 24.

## Cases (phase-a-tests.md rows, after corrections)
- A3.1 All 13 names are in both capability lists, and the server sends the real widget, not the fallback. unit
- A3.2 AspectRatio 16:9 in a 320-wide parent is 180 tall. FractionallySizedBox 0.5 takes half. ConstrainedBox keeps
  its child within its min and max inside the parent's constraints; LimitedBox caps an axis only where the parent
  leaves it unbounded (e.g. in a scroll view). fixture + ui  [corrected: LimitedBox, ConstrainedBox]
- A3.3 Wrap moves children to the next line when the row is full, with spacing and runSpacing. ui
- A3.4 Align honours alignment and size factors. Flexible is loose where Expanded is tight (inside a Row or Column).
  Baseline puts its child's text baseline `baseline` px below its own top, so two texts in Baselines with the same
  value line up. ui  [corrected: Baseline, Flexible scope]
- A3.5 IntrinsicHeight around a Row with crossAxisAlignment stretch makes its children as tall as the tallest;
  IntrinsicWidth around a Column with stretch makes them as wide as the widest. ui  [corrected: stretch]
- A3.6 Offstage (offstage true, the default) draws nothing, takes no taps and is as small as its parent allows (no
  space in a Column). SafeArea pads by the device insets, per edge flag. ui  [corrected: smallest size, default]
- A3.7 FittedBox scales its child with contain, cover and scaleDown, centred (Flutter does not read `alignment`). ui
  [note: alignment]

## Decisions
- D1 Contract. No wire change: all 13 are already in the schema, the engine, the registry and Flutter. One new render
  fixture `schema/fixtures/render/42_layout_wrappers.json` holding all 13 widgets with every wire prop (Align with
  factors, AspectRatio 16/9, Baseline 20 alphabetic, ConstrainedBox with all four bounds, FittedBox cover, Flexible flex
  2 loose, FractionallySizedBox 0.5, IntrinsicHeight, IntrinsicWidth with steps, LimitedBox, Offstage, SafeArea with
  top false, Wrap with spacing, runSpacing, alignment, crossAxisAlignment) and a `resolved` block so all four runners
  run it. Render fixture pins move 43 → 44 (Swift ModelRoundTripTests :10; Kotlin FixturePathsTest :13 and
  ModelRoundTripTest :32).
- D2 Capabilities (A3.1). Both `capabilities.json` gain the 13 (31 → 44, sorted), `schema/gen-native-capabilities.ts`
  regenerates Generated.swift and Generated.kt; every pin moves with them (Swift StructureWidgetTests :256-275 count and
  "every advertised type has a branch", Swift CapabilitiesTests, Kotlin CapabilitiesTest :41-76 count and Kotlin ==
  Swift, Kotlin WidgetBuildersTest standard() == advertised, the "31 widgets" comment). A name is advertised only with
  its implementation (plan rule 3). Engine test: a page holding all 13, served with each native vector, keeps every
  node: nothing dropped, no FallbackPrompt (pattern `demo-server.test.ts:326-347` `expectNativeDrawable` on the new demo
  page, or `todo-example.test.ts:330-376`).
- D3 Behaviour = Flutter's builder, defaults included (inventory §2): Align center + factors; AspectRatio default 1;
  Baseline 0 alphabetic, child without a baseline uses its height, size = child width × (baseline offset + child
  height); ConstrainedBox missing min 0 / max infinity, applied within the parent's constraints; FittedBox default
  contain, always centred; Flexible flex 1, loose unless "tight", outside a Row/Column it just draws its child (Flutter
  release behaviour); FractionallySizedBox factors as given, alignment default center; IntrinsicHeight tight height =
  max intrinsic height; IntrinsicWidth max intrinsic width rounded up to stepWidth/stepHeight; LimitedBox caps only an
  unbounded axis; Offstage default true, size = the parent's smallest, no paint, no hits, the child kept alive (state
  survives toggling); SafeArea each edge default true, pads by the insets that reach it (insets already consumed above,
  e.g. by a Scaffold's AppBar, are not added twice); Wrap spacing/runSpacing 0, alignment 6 values default start,
  crossAxisAlignment start/end/center (stretch, baseline, unknown → start), `direction` "vertical" read as Flutter does.
- D4 Swift. Each widget is a `struct XView: View` in the UI layer, dispatched in `NodeView.swift`. SwiftUI `Layout`
  (iOS 16) where a modifier cannot match Flutter exactly: Wrap, FractionallySizedBox, LimitedBox (reads an unbounded
  proposal), ConstrainedBox (clamps the proposal and the child's size), Intrinsic* (measures children with
  `.unspecified`), Baseline (child's first text baseline via alignment guides), Offstage (zero or forced size, hidden,
  `allowsHitTesting(false)`), FittedBox (child's ideal size scaled with `ImageFit` logic, `Media.swift:129-150`).
  Flexible joins `FlexView.flex(of:)` and `FlexLayout` with a loose fit (main axis up to its share, not forced);
  Expanded stays tight. SafeArea: edges flagged false ignore the container safe area, true ones keep it. Reuse
  `Props.alignment`/`unitPoint`, `TightAxes`/`orcaTight`, `CenterFactorLayout` for Align's factors.
- D5 Kotlin. Each widget a `@Composable internal fun XWidget(node, model, modifier)` registered in
  `WidgetBuilders.standard()`. Custom `Layout`/`MeasurePolicy` where Compose modifiers differ from Flutter (Wrap may use
  FlowRow only if spacing, runSpacing, alignment and cross alignment match Flutter exactly; otherwise a small Layout);
  ConstrainedBox via constrained measure within incoming constraints; LimitedBox checks `hasBoundedWidth/Height`;
  FractionallySizedBox and Align via measure policies (reuse `CenterMeasurePolicy` factors); Intrinsic* via
  `IntrinsicSize.Max` (step rounding in a policy); Offstage measures the child, places nothing, reports
  `constraints.min*`; SafeArea `windowInsetsPadding(WindowInsets.safeDrawing.only(flagged sides))` (respects insets
  already consumed); Flexible via `Modifier.flex(fill = false)` / `FlexFactorNode` loose in `FlexMeasurePolicy`
  (min 0, max share). Baseline with `FirstBaseline`. Payload sizes in dp.
- D6 Demo. Page `layout` on parity-a (one section per row A3.2-A3.7, all 13 widgets), imports the 13, one URL line in
  index.ts; the header comment's "avoid Wrap" note goes, since all three SDKs now draw it. Hand checks at the end of the
  step on the iPhone simulator and the Android emulator (SafeArea with a notch, Offstage toggled by a button, Wrap).
- D7 Tests per row: Swift `LayoutTests.swift`-style ImageRenderer frames (macOS + iOS) and hosted UIWindow where
  safe-area insets or hit testing matter; Kotlin Robolectric `layoutPage` bounds at mdpi, plus a WindowInsets test for
  SafeArea. Each row's check named `testA3_N…` / `a3_N_…`. No golden moves unless a task row lists it.
- D8 Row corrections (Flutter source in the inventory §2): A3.2, A3.4, A3.5, A3.6 reworded above, A3.7 noted; the
  corrections go into phase-a-tests.md with "Row corrected (step 3)" and the Flutter file:line. None weakens a check:
  each states what Flutter does.

## Constraints for the task plan
- Both SDKs in this one PR; logic in the cores only where it is pure (e.g. Wrap line breaking, fit maths, step
  rounding may live in the cores if both SDKs share the algorithm); drawing in the UI layers.
- One Swift and one Kotlin implementer at a time (one build tree each).
- Capability coupling: Kotlin CapabilitiesTest compares the Kotlin list with the Swift list, and Kotlin
  WidgetBuildersTest requires standard() == advertised; Generated.swift/kt come from one generator run over both lists.
  The plan must say where the 13 names are advertised (per group in both lists, or one caps task) and which tests are
  expected red inside the slice, as step 2's plan did.
- Fixtures first (D1) so the native tasks turn them green; the demo page before the hand checks.
