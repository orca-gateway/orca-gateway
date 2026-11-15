# 08 · Tasks · native-parity-s10

## Front page

### In one breath
tasks: 17 in 5 groups · widest group: 4 · cases: 36 of 36 placed
Fixtures first, proven on the real Flutter app (group 1), then executors and pure tab cores
(2), routers and widgets (3), the tab shells and demos (4), drawers and state keeping (5).
Swift and Kotlin run side by side in every group. Hand-checks wait for stage 10.
Group 1 leaves the native count pins red by design; group 2 turns all four suites green again.

### New for you
nothing new

### Trade-offs
5 auto-decided: openDrawer opens the nearest drawer where Flutter throws · server bar repaints
on app state · bad `_tabIndex` ignored · Flutter emits debug effects for the two actions ·
engine Drawer gains the `ios` target (your decision 1). Details: design-brief.md, section 2.

### Questions for you
1. Commands as found: bun test, flutter test + analyze, swift test, gradlew build. (default: yes)
2. Commits by the plugin: one per task, no push before stage 10. (default: per task, as S9)
3. One gate per group. (default: yes)
4. Navigation fixtures gain "sessions" (steps with expected state after each). (default: yes)

## Appendix

### Where S10 comes from
Plan `/Users/amrebada/.claude/plans/native-parity/plan.md`, step 10; cases B10.1-B10.8 of `phase-b-tests.md`.
Stages 01-07 were skipped as covered by the plan; `design-brief.md` in this folder is the design in force and its
section 5 is the case list. Flutter behaviour was read from `navigation_handler.dart`, `orca_shell.dart`,
`action_executor.dart` and `structure_builders.dart`. Branch `feat/native-parity-s10`, stacked on
`feat/native-parity-s9` (PR #30).

### Groups
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Navigation sessions, Flutter as oracle | `schema/navigation-fixture.schema.json` · `schema/fixtures/navigation/12_tab_sessions.json` (new) · `schema/fixtures/navigation/13_tab_index_state.json` (new) · `schema/fixtures/navigation/14_switch_tab.json` (new) · `sdk/test/conformance/navigation_fixtures_test.dart` | B10.2-F, B10.3-F | M | — |
| 1 | T2 | Action fixtures 30/31, Flutter debug effects | `schema/fixtures/actions/30_switch_tab.json` (new) · `schema/fixtures/actions/31_open_drawer.json` (new) · `sdk/lib/src/state/action_executor.dart` · `sdk/test/conformance/action_fixtures_test.dart` | B10.3-A/F, B10.5-A/F | M | — |
| 1 | T3 | Render fixtures 60/61, sessions README | `schema/fixtures/render/60_bottom_navigation_bar.json` (new) · `schema/fixtures/render/61_scaffold_drawers.json` (new) · `schema/fixtures/navigation/README.md` | B10.6-R/F | M | — |
| 1 | T4 | Engine: Drawer gains the ios target | `engine/src/components/structure/drawer.ts` · `engine/src/core/widget-registry-gen.ts` · `schema/widget-registry.json` · `engine/test/widget-targets.test.ts` · `engine/test/target-check.test.ts` | B10.C-S/E | M | — |
| 2 | T5 | Swift executor: switchTab, openDrawer, 17 kinds | `sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift` · `sdk-swift/capabilities.json` · `sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/ActionFixtureTests.swift` | B10.3-A/S, B10.5-A/S | M | T2, T4 |
| 2 | T6 | Kotlin executor: switchTab, openDrawer, 17 kinds | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt` · `sdk-kotlin/capabilities.json` · `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionFixtureTest.kt` | B10.3-A/K, B10.5-A/K | M | T2 |
| 2 | T7 | Swift core: TabShell passes the sessions | `sdk-swift/Sources/OrcaGatewayCore/Navigation/TabShell.swift` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/NavigationFixtureTests.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` | B10.2-CS, B10.3-CS, B10.6-R/S | M | T1, T2, T3 |
| 2 | T8 | Kotlin core: TabShell passes the sessions | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/navigation/TabShell.kt` (new) · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/navigation/NavigationFixtureTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` | B10.2-CK, B10.3-CK, B10.6-R/K | M | T1, T2, T3 |
| 3 | T9 | Swift router: tabs, _tabIndex, drawer state | `sdk-swift/Sources/OrcaGateway/Navigation/OrcaRouter.swift` · `sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift` · `sdk-swift/Tests/OrcaGatewayTests/RouterTests.swift` | B10.2-S, B10.3-S | M | T5, T7 |
| 3 | T10 | Kotlin router: tabs, _tabIndex, drawer state | `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/OrcaRouter.kt` · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageModel.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/navigation/RouterTest.kt` | B10.2-K, B10.3-K | M | T6, T8 |
| 3 | T11 | Swift widgets: bar, item, Drawer; 31 | `sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift` · `sdk-swift/Sources/OrcaGateway/NodeView.swift` · `sdk-swift/capabilities.json` · `sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift` · `sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift` (new) | B10.6-S, B10.C-S | M | T3, T4, T5 |
| 3 | T12 | Kotlin widgets: bar, item, Drawer; 31 | `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Structure.kt` · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt` · `sdk-kotlin/capabilities.json` · `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt` | B10.C-K | M | T3, T6 |
| 4 | T13 | Swift OrcaApp: TabView shell, server bar | `sdk-swift/Sources/OrcaGateway/OrcaApp.swift` · `sdk-swift/Sources/OrcaGateway/Navigation/TabShellView.swift` (new) · `sdk-swift/Tests/OrcaGatewayTests/TabShellTests.swift` (new) · `sdk-swift/Tests/OrcaGatewayTests/AppBootTests.swift` · `examples/app-ios/README.md` | B10.1-S, B10.4-S | M | T9 |
| 4 | T14 | Kotlin OrcaApp: NavigationBar shell, back | `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt` · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/TabShellScreen.kt` (new) · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/navigation/TabShellScreenTest.kt` (new) · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppTest.kt` · `examples/app-android/README.md` | B10.1-K, B10.4-K, B10.7-K | M | T10 |
| 4 | T15 | Demo apps tabs and tabs-server | `examples/server/tabs.ts` (new) · `examples/server/index.ts` · `examples/server/README.md` · `engine/test/demo-server.test.ts` | B10.D | M | — |
| 5 | T16 | Swift drawer: shell panel, page drawers | `sdk-swift/Sources/OrcaGateway/Widgets/DrawerPanel.swift` (new) · `sdk-swift/Sources/OrcaGateway/OrcaApp.swift` · `sdk-swift/Sources/OrcaGateway/Navigation/TabShellView.swift` · `sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift` · `sdk-swift/Tests/OrcaGatewayTests/TabShellTests.swift` | B10.5-S, B10.8-S | M | T11, T13 |
| 5 | T17 | Kotlin drawer: shell drawer, page drawers | `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt` · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/TabShellScreen.kt` · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Structure.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/navigation/TabShellScreenTest.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/StructureTest.kt` (new) | B10.5-K, B10.6-K, B10.8-K | M | T12, T14 |

Kind: feature. Legs: `/F` `/S` `/K` are the Flutter, Swift and Kotlin legs of a shared fixture case (B10.3-A, B10.5-A, B10.6-R); `B10.C-S/E` is the engine half of B10.C-S (Drawer has `ios` in the manifest, both registries regenerated). B10.7-K here is its unit half.

### Order, and why each boundary
- 1 → 2: the cores run the session, action and render files T1-T3 prove on Flutter, and Swift may only advertise what T4's manifest gives `ios`. **Group 1 ends with engine and Flutter green and the native suites red by design**: the count pins (render 39, actions 15, navigation 11), the two action fixtures (`ActionExecutor.implements`), and the Swift "Drawer is not an iOS widget" line. Group 2 restores all four suites: T5 fixes the orphan line and the 15 → 17 pin, T7 / T8 move the pins to 41 / 17 / 14 (a pin moved to the new truth, to be said in the digest).
- Inside 2: T5 and T6 add the two action kinds together, so Kotlin's "same kinds as Swift" test is green at the group's end. The cores emit the effects from group 2; nothing performs them until group 3 (branch unpushed until stage 10). T5 / T6 also move the two tests that use `openDrawer` as the unimplemented example to a kind that stays unsupported.
- 2 → 3: `OrcaRouter` owns a `TabShell` (T7 / T8) and performs the `switchTab` / `openDrawer` effects of T5 / T6. T11 / T12 share no code with the routers; they sit here because they write the capability files after T5 / T6 and must flip 28 → 31 in one group (Kotlin's "same widgets as Swift" and `WidgetBuildersTest`).
- 3 → 4: the tab shells draw from the router's `tabs`, `currentTab`, `selectTab`, `switchTab`. T15 imports only the engine and rides here to keep groups at four.
- 4 → 5: the drawers extend the shell files of T13 / T14 (one writer per file per group) and draw the `Drawer` widget of T11 / T12; the router's `isDrawerOpen` / `openDrawer()` / `closeDrawer()` already exist from T9 / T10.
- B10.6-K waits for T17: T12 is at five files with the capability flip, so its tap test lands in `StructureTest.kt`. T13 drops the whole "tabs and the drawer are not drawn yet" sentence from the iOS README.

### Seams
- `sdk-swift/capabilities.json`, `Generated.swift`, `CapabilitiesTests.swift` → T5 (group 2), then T11 (group 3); the 31-widget assertion goes in T11's new test file.
- `sdk-kotlin/capabilities.json`, `Generated.kt`, `CapabilitiesTest.kt` → T6 (group 2), then T12 (group 3).
- `schema/gen-native-capabilities.ts` writes both generated files in one run: each of T5 / T6 and T11 / T12 commits only its own SDK's file.
- `OrcaRouter` → T9 / T10 only. `OrcaApp` and the shell view → T13 / T14, then T16 / T17. `Structure.swift` / `Structure.kt` → T11 / T12, then T16 / T17.
- Risk to check at T5 / T6: the property generators (`Support/Generator.swift`, `support/Generator.kt`) produce `openDrawer`; if a property test fails, that file is a sixth and needs a card.

### Not planned
- B10.7-S, B10.8-H, the hand half of B10.7-K and the hand halves of the ui cases: hand checks by the main session at stage 10, on the simulator and the emulator with T15's demo (pointing the example hosts at the `tabs` app is part of that check).
- `tools/gen-go-registry.ts`: writes into `cloud/`, outside this repo; said in the PR.
- Otherwise none: all other §5 cases are placed.

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` · `cd sdk-kotlin && ./gradlew build`
lint: `cd sdk && flutter analyze` (Kotlin lint runs inside `./gradlew build`) · typecheck: none
baseline: engine 738 pass 0 fail · Flutter +303, analyze clean · Swift core 248 + UI 74, 0 failures · Kotlin build
successful, core 243, sdk 152, 2026-11-15
commits: per task (answered at gate 08, 2026-11-15)
gate: per group (answered at gate 08, 2026-11-15)
