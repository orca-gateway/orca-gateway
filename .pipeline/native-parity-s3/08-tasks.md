# 08 · Tasks · native-parity-s3

## Front page

### In one breath
tasks: 10 in 5 groups · widest group: 3 · cases: 7 of 7 placed
Plan step 3 on both SDKs: the 13 layout and sizing wrappers, drawn the way Flutter draws them.
G1 (contract): render fixture 42 holds all 13 with every wire prop and passes on all four runners.
G2: Align, AspectRatio, ConstrainedBox, FittedBox, FractionallySizedBox, LimitedBox.
G3: Flexible (loose in a Row or Column), IntrinsicHeight, IntrinsicWidth, Baseline.
G4: Wrap (line breaking in both cores), Offstage, SafeArea; demo page `layout` on parity-a.
G5: both SDKs advertise the 13 (31 → 44) and regenerate. Hand checks on both devices follow.

### New for you
nothing new

### Trade-offs
4 auto-decided (minor, standing rule): the names go out once, in G5 (q5); Wrap's maths lives in
the cores (q6); the engine's native-vector check stays red from G4 to G5 (q7); native Baseline
`ideographic` draws as alphabetic, documented (q8).

### Questions for you
1. Commands: every suite as at baseline; Swift on macOS and iOS 18.5. (default: as found)
2. Commits: one per task on feat/native-parity-s3; nothing pushed before stage 10. (default: yes)
3. One gate per group, 5 groups; hand checks after G5. (default: yes)
4. One Swift and one Kotlin task per group (one build tree each), no worktree each. (default: yes)
5. Advertise the 13 once, in G5; Kotlin registers them in standard() there too. (default: yes)
6. Wrap's line breaking and placement in both cores (WrapRuns), tested on Linux/JVM. (default: yes)
7. Engine check "each native vector gets the layout page whole" red from G4 to G5. (default: yes)
8. Native Baseline `ideographic` drawn as alphabetic (no such guide natively). (default: yes)
9. Rows as corrected (D8); the main session writes them into phase-a-tests.md. (default: yes)

## Appendix

### Where step 3 comes from
Plan `/Users/amrebada/.claude/plans/native-parity/plan.md`, Phase A step 3 ("Layout and sizing wrappers", S, 13
widgets); stages 01-07 skipped. Design in force `.pipeline/native-parity-s3/design.md` (D1-D8, rows A3.1-A3.7 after
corrections); facts in `.pipeline/native-parity-s3/inventory.md`. Branch feat/native-parity-s3 from origin/main
3cdeef7. No wire change. Planner: pipeline:build-task-planner (fresh), plan accepted as returned.

### Groups (paths from the repo root; sw/kt = Swift/Kotlin half, fx fixture, eng engine, hand device check)
| # | Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|---|
| 1 | 1 | F1 | Fixture 42 and native count pins | schema/fixtures/render/42_layout_wrappers.json (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt | A3.2 fx | M | — |
| 2 | 2 | S-size | Swift sizing boxes, Align, FittedBox | sdk-swift/Sources/OrcaGateway/Widgets/Sizing.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Layout.swift · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/SizingTests.swift (new) | A3.2 sw, A3.4 sw (Align), A3.7 sw | M | — |
| 3 | 2 | K-size | Kotlin sizing boxes, Align, FittedBox | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Sizing.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Layout.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/SizingTest.kt (new) | A3.2 kt, A3.4 kt (Align), A3.7 kt | M | — |
| 4 | 3 | S-flex | Swift Flexible, Intrinsic*, Baseline | sdk-swift/Sources/OrcaGateway/Widgets/Flex.swift · sdk-swift/Sources/OrcaGateway/Widgets/Layout.swift · sdk-swift/Sources/OrcaGateway/Widgets/Intrinsic.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/FlexibleIntrinsicTests.swift (new) | A3.4 sw (Flexible, Baseline), A3.5 sw | M | — |
| 5 | 3 | K-flex | Kotlin Flexible, Intrinsic*, Baseline | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Flex.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Intrinsic.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/FlexibleIntrinsicTest.kt (new) | A3.4 kt (Flexible, Baseline), A3.5 kt | M | — |
| 6 | 4 | S-flow | Swift Wrap, Offstage, SafeArea | sdk-swift/Sources/OrcaGatewayCore/Render/WrapRuns.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/WrapRunsTests.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Flow.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/FlowTests.swift (new) | A3.3 sw (core + ui), A3.6 sw | M | — |
| 7 | 4 | K-flow | Kotlin Wrap, Offstage, SafeArea | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/WrapRuns.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/WrapRunsTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Flow.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/FlowTest.kt (new) | A3.3 kt (core + ui), A3.6 kt | M | — |
| 8 | 4 | D1 | Demo page layout on parity-a | examples/server/parity-a.ts · examples/server/index.ts · engine/test/parity-a-layout.test.ts (new) | A3.1 eng, A3.2-A3.7 hand | M | — |
| 9 | 5 | S-caps | Swift advertises the 13 wrappers | sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift | A3.1 sw | M | S-size, S-flex, S-flow |
| 10 | 5 | K-caps | Kotlin registers and advertises the 13 | sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt | A3.1 kt | M | K-size, K-flex, K-flow |

Placed: A3.1 S-caps/K-caps (unit) + D1 (eng); A3.2 F1 (fx) + S-size/K-size; A3.3 S-flow/K-flow; A3.4 S-size/K-size
(Align) + S-flex/K-flex (Flexible, Baseline); A3.5 S-flex/K-flex; A3.6 S-flow/K-flow; A3.7 S-size/K-size; hand on D1's
page after G5. Test names `testA3_N…` / `a3_N_…`.

### Order and expected reds
- G1: F1 moves the three native pins 43 → 44 (red), then writes fixture 42 (green): all 13 with every wire prop, a
  `resolved` block, one prop bound to page state. Engine and Flutter runners list the directory (no file change). D1
  cannot share G1 (demo-server.test.ts spawns index.ts while F1 runs the engine suite). Red at the gate: none.
- G2: sizing boxes and FittedBox per Flutter's builders (D3). Align adds an alignment (default center) to
  CenterFactorLayout / CenterMeasurePolicy (made internal). FittedBox reuses ImageFit / `imageFit()`, always centred.
  Tests use a widened registry. Red: none (caps pins stay 31).
- G3: Flexible joins FlexLayout / FlexMeasurePolicy with a loose fit (min 0, up to its share); Expanded stays tight;
  outside a Row/Column it draws its child. IntrinsicWidth rounds up to stepWidth/stepHeight. Compose may need
  intrinsic overrides on FlexMeasurePolicy if A3.5 fails. Red: none.
- G4: WrapRuns in both cores (6 alignments, 3 cross alignments, spacing, runSpacing, `direction` read as Flutter);
  Offstage keeps its child alive, draws nothing, takes no hits; SafeArea skips flagged-false edges and never adds
  insets twice. D1 joins G4. Expected red at the G4 gate: `parity-a-layout.test.ts` "A3.1 each native vector gets
  the layout page whole, no FallbackPrompt" (both vectors still list 31); "A3.1 the layout page holds all 13
  wrappers" passes.
- G5: S-caps advertises the 13 (sorted), regenerates, moves StructureWidgetTests 31 → 44 (the :264-275 branch check
  then covers the 13). K-caps registers the K-size/K-flex/K-flow builders in `standard()` and lists them in the same
  commit, moves CapabilitiesTest.kt:59-77 and the "31 widgets" comment. Each adds `a3_1` checks red first. Inside G5,
  `c1_kotlinAdvertisesTheSame44WidgetsAsSwift` is red until S-caps lands; D1's red waits for both. Red at the gate:
  none.
- Hand checks after G5 on page `layout`: SafeArea under a notch, Offstage toggled by a button, Wrap, A3.2-A3.7.

### Seams
- `gen-native-capabilities.ts` writes Generated.swift and Generated.kt in one run; S-caps stages only Generated.swift,
  K-caps only Generated.kt; whichever finishes last reruns the generator so both are clean at the G5 gate.
- NodeView.swift changes in S-size, S-flex, S-flow (one per group); Layout.swift in S-size, S-flex; WidgetBuilders.kt
  only in K-caps. No golden listed: if one moves, the task stops.

### Findings (planner)
- Both clients degrade every type their registry lacks (Swift PageRenderer.swift:17-24,144-147; Kotlin
  PageRenderer.kt:22-23,73), so G2-G4 UI tests pass a widened registry (`OrcaPageModel(page:registry:)`,
  OrcaPageModel.swift:43-44; Kotlin `OrcaPageModel(page, registry =)`, :59-62).
- Swift's switch check is one-way (advertised ⇒ branch); Kotlin's WidgetBuildersTest checks both ways, so Kotlin
  registrations land in K-caps and K-task tests register their own builders with a testTag (LayoutTest.kt:46-58).
- D1's engine test is a new in-process file (todo-example.test.ts:37-43, :331-350 pattern); it drops the "no Wrap"
  note in the parity-a header.

### Done when
engine `bun test`; `flutter test` + `flutter analyze`; `swift test` (macOS) and the iOS scheme on DA7254F5; Kotlin
`./gradlew build --console=plain` (tests, lint, warnings as errors); the three generators leave no diff; goldens
unchanged; one commit per task by path; one gate per group; hand checks after G5.

### Not planned (on purpose)
Wrap runAlignment, textDirection, verticalDirection, clipBehavior (not on the wire); `direction` read but not
authorable; SafeArea minimum, maintainBottomViewPadding (not on the wire, Flutter ignores them); FittedBox
alignment (Flutter ignores it; a fix belongs in all three SDKs); Flexible outside a Row/Column follows Flutter's
release behaviour; Baseline ideographic drawn as alphabetic (q8). Row corrections: written into phase-a-tests.md by
the main session (done at stage 08).
