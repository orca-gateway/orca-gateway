# 08 · Tasks · native-parity-s6

## Front page

### In one breath
tasks: 21 in 8 groups · widest group: 3 · cases: 7 of 7 placed
Plan step 6 on both SDKs: Checkbox, Radio, Switch, Slider, Form, TextFormField, IconButton, FAB,
InkWell. G1 fixture 45, cores, pins. G2 Checkbox, Radio, binding. G3 Switch, Slider, TFF, Form.
G4 IconButton, FAB. G5 InkWell. G6-G7 degrade pages off Checkbox. G8 caps 68 → 77, forms page.
The four Epic 23b iOS orphans gain ios in G2 and G4. Hand checks on both devices follow G8.

### New for you
nothing new

### Trade-offs
All minor under the standing rule, decided by default. Closest to major: q4-q5. Degrade tests move
off Checkbox to CustomScrollView (after step 8 only slivers stay unadvertised); two DevTools tests
and four degrade goldens move with them. D2 is two engine tasks to stay within 5 files per task.

### Questions for you
1. Commands as at baseline; Swift on macOS and the iOS scheme on DA7254F5. (default: as found)
2. One commit per task, one gate per group; nothing pushed before stage 10. (default: yes)
3. Hand checks on the iPhone 16 Pro and Android API 34 after G8 (FAB, InkWell). (default: yes)
4. Degrade case: CustomScrollView (shrinkWrap) holding a SliverToBoxAdapter. (default: yes)
5. Re-record degrade-warn and degrade-require goldens on both SDKs, no others. (default: yes)
6. D2 as two engine tasks (G2, G4); the pins it moves are narrowed in G1. (default: yes)
7. The forms page lands with the caps in G8, so its whole-page check is never red. (default: yes)
8. Android long press at Flutter's 500 ms through the view configuration. (default: yes)
9. The cloud's Go registry (targets) is yours to regenerate after merge. (default: yes)
10. Rows as corrected (D10); the main session writes them into phase-a-tests.md. (default: yes)

## Appendix

### Where step 6 comes from
Plan /Users/amrebada/.claude/plans/native-parity/plan.md:91-101 (Phase A step 6, M, 9 widgets). The iOS decision there
(:99-100) was settled as "draw them" at :219-222. Stages 05-07 were skipped. The design in force is
.pipeline/native-parity-s6/design.md (D1-D10, rows A6.1-A6.7 after corrections) and the facts are in
.pipeline/native-parity-s6/inventory.md, checked against the code by the planner (corrections in Risks 2, 3 and 6).

The design departs from the plan's hints in three places:
- Kotlin draws Radio and IconButton in Flutter's own look, not as M3 RadioButton or IconButton, because Flutter uses
  neither (IB:139-194, BB:93-163).
- The iOS FAB takes Flutter's M3 shape, not a round button (D6).
- The builders do read "stateKey + onChange", but no engine class sends stateKey, so the demo binds by value (D8).

Branch feat/native-parity-s6 on feat/native-parity-s5 a289936 (PR #45 is open; rebase when it merges). No wire change
(D1). Planner: pipeline:build-task-planner (fresh, read only); plan accepted as returned. Baseline is s5's last run
(code at f66edac; a289936 adds only pipeline records): engine 798/0; Flutter 487, analyze clean; Kotlin core 570 /
sdk 642; swift test UI 456 / core 548; iOS scheme UI 560 / core 548.

### Groups (paths from the repo root; sw/kt = Swift/Kotlin half, fx fixture, eng engine, tgt targets, deg degrade)
| # | Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|---|
| 1 | 1 | F1 | Fixture 45 and target-check pins | schema/fixtures/render/45_form_controls.json (new) · engine/test/target-check.test.ts | A6.1-A6.7 fx (45: engine, Flutter); A6.x tgt eng (holds before and after D2) | S | — |
| 2 | 1 | S-core | Swift FormControls core and fixture pins | sdk-swift/Sources/OrcaGatewayCore/Render/FormControls.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/FormControlsTests.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift | A6.1, A6.2, A6.3 core unit sw; A6.1-A6.7 fx sw (45 resolves, 53 → 54); A6.x tgt sw (orphans narrowed) | M | — |
| 3 | 1 | K-core | Kotlin FormControls core and fixture pins | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/FormControls.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/FormControlsTest.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt | A6.1, A6.2, A6.3 core unit kt; A6.1-A6.7 fx kt (53 → 54) | M | — |
| 4 | 2 | E-ios1 | Checkbox and Radio gain ios | engine/src/components/input/checkbox.ts · engine/src/components/input/radio.ts · engine/src/core/widget-registry-gen.ts · schema/widget-registry.json · engine/test/widget-targets.test.ts | A6.1 eng ("drawn on iOS": the target), A6.2 eng; A6.x tgt | M | — |
| 5 | 2 | S-check | Swift Checkbox, Radio and value binding | sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift · sdk-swift/Tests/OrcaGatewayTests/NativeWidgetTests.swift · sdk-swift/Sources/OrcaGateway/Widgets/Selection.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/CheckboxRadioTests.swift (new) | A6.1 sw, A6.2 sw (unit + ui); A6.7 sw (Checkbox, Radio) | M | S-core |
| 6 | 2 | K-check | Kotlin Checkbox, Radio and value binding | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Input.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Selection.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/CheckboxRadioTest.kt (new) | A6.1 kt, A6.2 kt (ui); A6.7 kt (Checkbox, Radio) | M | K-core |
| 7 | 3 | D-deg | Degrade demo page off Checkbox | examples/server/capability-demo.ts · examples/server/index.ts · examples/app-android/README.md | A6.x deg eng (the page the four deg tasks record) | M | — |
| 7b | 3 | D-deg2 | Degrade demo page on a made-up type (rework of D-deg, decision degrade-widget) | examples/server/capability-demo.ts · examples/server/index.ts · examples/app-android/README.md | A6.x deg eng (the page the four deg tasks record) | S | D-deg |
| 8 | 3 | S-switch | Swift Switch, Slider, TextFormField, Form | sdk-swift/Sources/OrcaGateway/Widgets/Controls.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/SwitchSliderTests.swift (new) · sdk-swift/Tests/OrcaGatewayTests/FormFieldTests.swift (new) | A6.3 sw, A6.4 sw (ui); A6.7 sw (Switch, Slider, TextFormField) | M | S-core, S-check |
| 9 | 3 | K-switch | Kotlin Switch, Slider, TextFormField, Form | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Controls.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/SwitchSliderTest.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/FormFieldTest.kt (new) | A6.3 kt, A6.4 kt (ui); A6.7 kt (Switch, Slider, TextFormField) | M | K-core, K-check |
| 10 | 4 | E-ios2 | FAB and InkWell gain ios | engine/src/components/button/floating-action-button.ts · engine/src/components/layout/ink-well.ts · engine/src/core/widget-registry-gen.ts · schema/widget-registry.json · engine/test/widget-targets.test.ts | A6.5 eng, A6.6 eng (the target); A6.x tgt | M | — |
| 11 | 4 | S-tap | Swift IconButton and FloatingActionButton | sdk-swift/Sources/OrcaGateway/Widgets/Buttons.swift · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/IconButtonFabTests.swift (new) | A6.5 sw (ui); A6.7 sw (IconButton, FAB) | M | — |
| 12 | 4 | K-tap | Kotlin IconButton and FloatingActionButton | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Buttons.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/IconButtonFabTest.kt (new) | A6.5 kt (ui); A6.7 kt (IconButton, FAB) | S | — |
| 13 | 5 | S-ink | Swift InkWell with press highlight | sdk-swift/Sources/OrcaGateway/Widgets/Stack.swift · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/InkWellTests.swift (new) | A6.6 sw (ui); A6.7 sw (InkWell) | M | — |
| 14 | 5 | K-ink | Kotlin InkWell with ripple | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Gesture.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/InkWellTest.kt (new) | A6.6 kt (ui); A6.7 kt (InkWell) | S | — |
| 14b | 5 | K-theme | One shared Flutter light scheme for the Kotlin widgets (added at 09, K-tap review) | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Selection.kt · Structure.kt · Buttons.kt · Controls.kt · FlutterTheme.kt (new) | A6.x look | S | K-tap, K-switch |
| 15 | 6 | S-deg-a | Swift warn and graceful pages re-recorded | sdk-swift/Tests/Pages/degrade-warn.json · sdk-swift/Tests/Pages/degrade-graceful.json · sdk-swift/Tests/OrcaGatewayCoreTests/DegradeTests.swift · sdk-swift/Tests/Goldens/degrade-warn.sdk-27.2.ios-18.5.png · sdk-swift/Tests/OrcaGatewayTests/GoldenTests.swift | A6.x deg sw (T4.1/T4.2 warn, graceful and the warn golden kept green) | M | D-deg |
| 16 | 6 | K-deg-a | Kotlin warn and graceful pages re-recorded | sdk-kotlin/sdk/src/test/resources/pages/degrade-warn.json · sdk-kotlin/sdk/src/test/resources/pages/degrade-graceful.json · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/DegradeTest.kt · sdk-kotlin/sdk/src/test/resources/goldens/degrade-warn.png · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/GoldenTest.kt | A6.x deg kt (d1, d2, g1 kept green) | M | D-deg |
| 17 | 7 | S-deg-b | Swift require page, DevTools test | sdk-swift/Tests/Pages/degrade-require.json · sdk-swift/Tests/Goldens/degrade-require.sdk-27.2.ios-18.5.png · sdk-swift/Tests/OrcaGatewayCoreTests/DevToolsEventTests.swift | A6.x deg sw (require golden, fallback reported once kept green) | M | D-deg |
| 18 | 7 | K-deg-b | Kotlin require page, DevTools test | sdk-kotlin/sdk/src/test/resources/pages/degrade-require.json · sdk-kotlin/sdk/src/test/resources/goldens/degrade-require.png · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/debug/DevToolsReportingTest.kt | A6.x deg kt (g2, e8 kept green) | M | D-deg |
| 19 | 8 | S-caps | Swift advertises the nine widgets | sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift | A6.x caps unit sw (77 widgets) | M | E-ios1, E-ios2, S-check, S-switch, S-tap, S-ink, S-deg-a, S-deg-b |
| 20 | 8 | K-caps | Kotlin registers and advertises the nine | sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt | A6.x caps unit kt (77 widgets) | M | K-check, K-switch, K-tap, K-ink, K-deg-a, K-deg-b |
| 21 | 8 | D-forms | Demo page forms on parity-a | examples/server/parity-a.ts · examples/server/index.ts · engine/test/parity-a-forms.test.ts (new) | A6.x eng (page whole on both vectors); A6.1-A6.7 hand | M | — |

### Where each case is placed
- A6.1: F1 (fx); S-core and K-core (45 resolves; checkboxNext); E-ios1 (the "drawn on iOS" target); S-check and
  K-check (ui: the write is page scope and comes before onChange, the tick redraws through watches, tristate, the label
  row).
- A6.2: F1; the cores (radioSelected); E-ios1; S-check and K-check (ui).
- A6.3: F1; the cores (sliderValue, sliderFraction); S-switch and K-switch (ui).
- A6.4: F1; S-switch and K-switch (ui).
- A6.5: F1; E-ios2; S-tap and K-tap (ui); hand.
- A6.6: F1; E-ios2; S-ink and K-ink (ui); hand.
- A6.7: F1 (enabled false is in the fixture), then by widget: S-check / K-check Checkbox, Radio; S-switch / K-switch
  Switch, Slider, TextFormField; S-tap / K-tap IconButton at 0.38 and no touches without a handler, FAB unchanged;
  S-ink / K-ink no `enabled`, live without a handler.
- Beside the rows: A6.x tgt F1, S-core, E-ios1, E-ios2; A6.x deg D-deg, S/K-deg-a, S/K-deg-b; A6.x caps S-caps,
  K-caps; A6.x eng D-forms. Every row is hand-checked on D-forms' page after G8.
Test names are `testA6_N…` (Swift) and `a6_N_…` (Kotlin).

### Order, and why each boundary; expected reds
- G1.
  - F1 writes 45_form_controls.json per D1: every control bound as the demo binds (value V.pageState(k), onChange
    SetState(k, V.event('value'))); a tristate Checkbox, an enabled-false one, a Form around a TextFormField, IconButton
    padding/alignment/constraints/tooltip, FAB mini/colours/elevation/tooltip, InkWell borderRadius/colours with all
    three triggers. `expected` from encodeJsonTree, cross-checked against flatten; a `resolved` block; numbers the same
    JSON on every side (no 50 vs 50.0, inventory §8).
  - F1 also moves target-check.test.ts:8-17 (FAB → Tooltip) and :28-31 (Checkbox → Video on ["flutter","web"], which
    misses both). Both hold before and after D2.
  - S-core and K-core build FormControls per D5 with the same cases: checkboxNext false → true → null (or false),
    null → false (FW toggleable.dart:247-252); radioSelected string equality, both empty selects (BH:440); sliderValue
    clamps, then snaps to min + round(t·d)·(max − min)/d (MUI slider.dart:815-816); sliderFraction clamped, 0 when
    max == min.
  - S-core moves ModelRoundTripTests.swift:10 (53 → 54, "01-45, 60-68") and narrows CapabilitiesTests.swift:29-33 to
    SnackBar and Tooltip. K-core moves ModelRoundTripTest.kt:32 and FixturePathsTest.kt:13.
  - 45's resolved block runs unedited on both cores (ResolverFixtureTests.swift:12, ResolverFixtureTest.kt:24). The
    pins count F1's file, so the three are checked together at the gate.
  - Red first: the cores on stubs, the pins on 53 ≠ 54. Red at the gate: none.
- G1 → G2: S-check and K-check call the cores. E-ios1 waits for G1 because F1 runs the engine suite (one engine-suite
  task per group) and because S-core and F1 narrow the pins it moves.
  - E-ios1: checkbox.ts:19-20 and radio.ts:18-19 drop the Epic 23b line and take all four targets; `bun run
    schema/gen-widget-registry.ts` regenerates; widget-targets.test.ts:16 (and its header :2-8) becomes FAB, InkWell,
    SnackBar, Tooltip, red first.
  - S-check, binding: `valueChanged(JSONValue, on:)` generalises textChanged (OrcaPageModel.swift:321-347) and
    textChanged calls it: setState on stateKey (page scope), then onChange {value}, chained on one Task; nil without a
    binding or when inert. NativeWidgetTests covers a bool, a double and a string, as at :156-198.
  - S-check, views: Selection.swift per D6. Checkbox SF Symbols square, checkmark.square.fill, minus.square.fill; the
    whole label row taps. Radio 20 pt, IB:165-190's colours, fires only when enabled and unselected (IB:153). The value
    from the store at stateKey, else the prop; no @State. NodeView.swift gets the cases. Tests hosted in a UIWindow
    (TextFieldTests.swift:125-138) with a widened registry.
  - K-check: Input.kt's edit and pageText (:134-144) become internal and take a JsonValue; TextFieldWidget calls through
    and TextFieldTest stays green. Selection.kt draws an M3 Checkbox, a labelled row, and Radio's own circle.
    Robolectric tests with test-local builders check toggle-state semantics and that a watching Text redraws.
  - Red at the gate: none.
- G2 → G3: S-switch and K-switch call the binding and sliderValue. D-deg takes the engine lane.
  - D-deg: capability-demo.ts:200-231 swaps the Checkbox for CustomScrollView(shrinkWrap) holding one
    SliverToBoxAdapter(Text), texts and comments to match; also index.ts:99 and app-android README.md:69.
  - D-deg2 (added at 09, decision degrade-widget): the page moves again, to a local PrimitiveWidget subclass of type
    UnregisteredPluginWidget (no props) between "Above the plugin widget." and "Below the plugin widget."; no host
    registers it, so every SDK degrades it for good. The deg tasks record D-deg2's page.
  - S-switch: Controls.swift per D6. Switch a Toggle, activeColor the tint. Slider a SwiftUI Slider: min ?? 0,
    max ?? 1, step (max − min)/divisions, drawn clamped, the write and onChange on every drag update (D7). NodeView.swift:
    "TextFormField" beside "TextField" (:127); "Form" → ChildView (:177-186). Toggle and Slider tested through their
    UIKit target actions if they are UISwitch/UISlider (RefreshTests.swift:351-360), otherwise through the binding.
    TextFormField tested as TextFieldTests.swift:70-89. Disabled already works (Input.swift:125, :140).
  - K-switch: M3 Switch with IB:274-281's mapping; M3 Slider (steps = divisions − 1, the label only with divisions,
    trackHeight); FormWidget draws its child. Tests: toggle, a swipe with progress semantics, TextFormField, Form.
  - Red: none.
- G3 → G4, G4 → G5: nothing imported; the lane sets the order (one Swift task per group; NodeView.swift is a seam).
  - E-ios2: floating-action-button.ts:22-23 and ink-well.ts:15-16 take ios; regenerate; IOS_ORPHANS → SnackBar,
    Tooltip.
  - S-tap: Buttons.swift per D6. IconButton (BB:93-163): a size + 16 box, colour only when set, 0.38 when disabled, a
    gesture only when enabled and given a handler. FAB (BB:193-223): 56/16 or mini 40/12, #EADDFF and #4F378B, a shadow,
    tappable whenever enabled, a long press. Tests: hit tests, both triggers, the slot frame at bottom-trailing 16
    (Structure.swift:41, :52-53).
  - K-tap: IconButton in Flutter's box with no ripple; M3 FloatingActionButton / SmallFloatingActionButton with a long
    press on a wrapper (BB:219-220). Tests: click, longClick, bottom-end bounds (Structure.kt:259).
  - S-ink: InkWellView in Stack.swift next to GestureNodeView, reusing the private Taps and LongPress (:215-240). All
    three triggers always attached (LB:628-630); highlightColor ?? #66BCBCBC while pressed; clipped to borderRadius.
  - K-ink: combinedClickable with all three set, a ripple in splashColor, clipped. Tests: click after the 300 ms
    double-tap timeout (mainClock), doubleClick, longClick (q8).
  - Red: none.
- G5 → G6: the deg tasks record D-deg's page and sit after the widget lane.
  - S-deg-a re-records only the warn and graceful lines (Taskfile.yml:109-110), moves DegradeTests.swift:6-10 and
    :28-54 to CustomScrollView, re-records the warn golden on DA7254F5 (TEST_RUNNER_ORCA_RECORD_GOLDENS=1,
    GoldenTests.swift:21-23, then a comparing run), and updates the doc at :40-42.
  - K-deg-a the same with Taskfile.yml:137-138, DegradeTest.kt:20-28 and :45-77, degrade-warn.png
    (-Porca.recordGoldens=true, GoldenTest.kt:38-39); doc at :60-66.
  - Red first: the test edits on the old pages. Red: none. The require page stays the old recording until G7 and is
    green: d3 does not read the registry.
- G6 → G7: the lane, plus the five-file limit.
  - S-deg-b: Taskfile.yml:111, the require golden, DevToolsEventTests.swift:237-255 to CustomScrollView; degrade-426
    re-recorded only to see no diff.
  - K-deg-b: Taskfile.yml:139, degrade-require.png, DevToolsReportingTest.kt:137-153.
  - Red: none.
- G7 → G8: the caps list only what has the ios target (gen-native-capabilities.ts:106-111) and what the switch draws
  (StructureWidgetTests.swift:270-282). No degrade test still uses an advertised widget.
  - S-caps: the nine, sorted, one generator run; CapabilitiesTests.swift:38-52 and StructureWidgetTests.swift:256-268
    move to 77, plus a new `testA6…` check.
  - K-caps: standard() (WidgetBuilders.kt:141-211) registers the nine (TextFormField → TextFieldWidget) in the commit
    that lists them; CapabilitiesTest.kt:52-108 (c1) and :110-126 move to 77, plus an `a6_x_` check.
    WidgetBuildersTest.kt:15-23 needs no edit.
  - D-forms: page `forms` per D8, after `lists` (parity-a.ts:1218-1358, before parityFlow :1360); route after :1370;
    header :75-78; URL after index.ts:114; the test a copy of parity-a-lists.test.ts.
  - c1 and D-forms' "page whole" check are red until both caps land, and green at the gate (q7). Hand checks follow.

### Seams
- NodeView.swift: S-check, S-switch, S-tap, S-ink, one per group (G2-G5); S-caps never touches it. Owned by one task
  each: OrcaPageModel.swift and NativeWidgetTests.swift (S-check), Input.kt (K-check), Stack.swift (S-ink), Gesture.kt
  (K-ink), Buttons.swift (S-tap), Buttons.kt (K-tap).
- Engine registry: widget-registry-gen.ts, widget-registry.json and widget-targets.test.ts go to E-ios1 (G2), then
  E-ios2 (G4), each with one generator run.
- Capabilities: CapabilitiesTests.swift is S-core (G1), then S-caps (G8). One gen-native-capabilities run writes
  Generated.swift and Generated.kt; each caps task stages its own, and whichever finishes last reruns the generator.
- Demo server: index.ts is D-deg (G3), then D-forms (G8). capability-demo.ts belongs to D-deg alone; the four deg tasks
  record from it.
- Degrade tests: DegradeTests.swift, DegradeTest.kt, GoldenTests.swift and GoldenTest.kt go only to the deg-a tasks.
- One engine-suite task per group (F1, E-ios1, D-deg, E-ios2, D-forms). Each suite imports the generated registry and,
  through demo-server.test.ts:15, every example app. No examples/server edit in G6-G7, because record-page.ts loads
  every app (:27-32, :56).
- Goldens: only degrade-warn and degrade-require move, two per SDK. Any other golden moving stops the task.

### Risks (checked against the code by the planner)
1. Degrade widget. Flutter advertises 93 widgets (sdk/lib/src/capabilities/generated.dart:21-115), the natives 68
   (sdk-swift/capabilities.json:3-71). Steps 6-8 add 20, leaving only CustomScrollView, SliverAppBar, SliverGrid,
   SliverList and SliverToBoxAdapter (plan.md:157-165, step 13). A bare sliver in the demo's Column
   (capability-demo.ts:221-227) throws on Flutter; CustomScrollView takes shrinkWrap (custom-scroll-view.ts:9). The
   banner will name two features.
2. Tests the inventory missed: DevToolsEventTests.swift:237-255 and DevToolsReportingTest.kt:137-153 also use Checkbox,
   on WidgetRegistry(), whose default is the vector (PageRenderer.swift:17, PageRenderer.kt:25).
3. Early red: CapabilitiesTests.swift:29-33 reads the manifest (:9-17), so it would turn red at E-ios1's gate, not at
   caps; target-check.test.ts too. Kotlin checks only the android target (CapabilitiesTest.kt:41-50).
4. Goldens: the prompt draws its body (Content.swift:136), and that body names the type (PageRenderer.swift:62-63).
   Swift's degrade goldens exist only for sdk-27.2.ios-18.5, so CI's Xcode 16.4 skips them (GoldenTests.swift:15-23).
   Kotlin's .runtime marker stays robolectricSdk=34. degrade-426 holds no widget (:9-22).
5. Recording: record only the degrade lines (Taskfile.yml:109-111, 137-139). CI re-records counter-home and diffs
   Pages/ (.github/workflows/schema.yml:86-94).
6. Stale inventory lines (they predate the rebase). Current: Swift switch NodeView.swift:87-165 (TextField :127,
   GestureDetector :131, default :162-164); textChanged OrcaPageModel.swift:330-347; Kotlin standard()
   WidgetBuilders.kt:141-211 (TextField :160, GestureDetector :161); edit Input.kt:134-138.
7. Before G8 the renderers degrade the nine. Tests widen the registry (RefreshTests.swift:319,
   PluginWidgetTests.swift:67, RefreshTest.kt:83). Kotlin builders stay test-local, because standard() must equal the
   vector (WidgetBuildersTest.kt:15-23).
8. Swift cannot inject a tap (TouchTests.swift:15). Whether Toggle and Slider are backed by UISwitch and UISlider is not
   verified. The InkWell highlight and the 300 ms wait are checked by hand.
9. Timing. Swift's Taps chains onTapGesture(count: 2) before count 1 (Stack.swift:222), so SwiftUI sets the wait;
   LongPressGesture defaults to 0.5 s (:238). Compose takes its long press from the platform's ViewConfiguration, which
   may be below Flutter's 500 ms (gestures/constants.dart:29), hence q8.
10. stateKey: no engine class sends it (inventory §8). Tests set it by hand (TextFieldTests.swift:72). A node redraws
    only through its watches (NodeView.swift:41).
11. FAB: the slot already draws on both SDKs (Structure.swift:52-53, Structure.kt:259); no Structure change is planned.
    M3 FloatingActionButton has only onClick, so the Kotlin long press needs its own pointer input.
12. Generated outputs: D2 reaches the cloud's Go registry (tools/gen-go-registry.ts:133, q9). Flutter's vector and
    engine-dart's registry (its generator reads no targets) do not move.

### Done when
- Suites: engine `bun test`; `flutter test` and `flutter analyze`; `swift test` and the iOS scheme on DA7254F5; Kotlin
  `./gradlew cleanTest build --no-build-cache --console=plain`.
- Generators: gen-widget-registry, gen-native-capabilities and gen-sdk-capabilities leave no diff, nor does the
  counter-home re-record. Only the four degrade goldens moved. examples/app-ios and examples/app-android build.
- One commit per task, staged by path; one gate per group; hand checks after G8; a row ticked only when both SDKs agree.

### Not planned (on purpose)
- stateKey on the engine classes (wire bug, inventory §8, follow-up). Switch `label` (read at IB:252; the engine class
  has none). TextFormField `validator`, and Form validation or save (Flutter has none, LB:481-483).
- Props Flutter never reads: Checkbox inactiveColor, Radio focus and hover, IconButton splash and highlight, FAB
  isExtended and heroTag. On iOS: Switch inactiveColor, Slider label and trackHeight, and a ripple (D6).
- The Tooltip and SnackBar targets (step 8). An action fixture (D1). The cloud's Go registry (another repo).
  engine/CHANGELOG.md (written at release). The inline warn page in sdk/test/caps_warn_wrapper_test.dart:17-37 (Flutter
  draws Checkbox, so it stays valid).
