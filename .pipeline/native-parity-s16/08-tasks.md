# 08 · Tasks · native-parity-s16

## Front page

### In one breath
tasks: 14 in 5 groups · widest group: 4 · cases: 6 of 6 placed (12 cells, Swift and Kotlin)
Plan step 16 on both native SDKs: plugin contract, public widget and action registration,
Flutter's conflict errors, caps growth, and orca CLI stubs for Swift and Kotlin.
G1 merger and caps extensions per SDK. G2 action handlers + fixtures 45-47 (Flutter too).
G3 OrcaPlugin and public WidgetBuilders. G4 OrcaApp(plugins:) + the CLI generators.
G5 the generated google_map stubs compiled in both suites, demo plugins and READMEs.

### New for you
nothing new

### Trade-offs
3 auto-decided: one Swift and one Kotlin task per group; fixtures before native runners; a
fixture field `handlers` lets all three SDKs pin custom-action dispatch

### Questions for you
1. Commands: Swift swift test + the SwiftUI target on the simulator; ./gradlew build; Flutter in
   G2; dart test + analyze in G4-G5; engine at the end. (default: as found)
2. Commits: one per task on feat/native-parity-s16 (stacked on PR #31); PR after G5. (default: yes)
3. One gate per group, 5 groups. (default: yes)
4. Three action fixtures 45-47 and an optional fixture field `handlers` (test runners only, in
   Flutter, Swift and Kotlin; no SDK behaviour change in Flutter). (default: yes)

## Appendix

### Where step 16 comes from
Plan step 16 of /Users/amrebada/.claude/plans/native-parity/plan.md ("Plugin system", L): a plugin contract on
both SDKs (widgets, actions, triggers, capability extension); public widget and action registration; conflict
detection; `orca` CLI generates Swift and Kotlin stubs from `orca_plugin.yaml`. Swift: an `OrcaPlugin` protocol;
`WidgetView`'s closed switch gains a registry lookup. Kotlin: an `OrcaPlugin` interface; `WidgetBuilders.register`
becomes public. Test rows C16.1-C16.6 in phase-c-tests.md. Stages 01-07 skipped as covered by the plan (the
Phase C brief). Branch feat/native-parity-s16 from feat/native-parity-s15 (PR #31, open).

### Checked before planning (2026-11-15)
- Flutter: `OrcaPlugin`, `TriggerDefinition` (sdk/lib/src/plugins/orca_plugin.dart); `mergePlugins` and its four
  ArgumentError messages (plugins/plugin_merger.dart:23-108); `ActionExecutor.registerHandler` and the
  exact-then-bare `custom:` lookup with the raw action (state/action_executor.dart:153-207);
  `OrcaClient.registerCapabilityExtensions` (client/orca_client.dart:57-86); `OrcaApp` folds only plugin names
  into the caps (widgets/orca_app.dart:376-387) and merges in `_initRouter` inside the boot try.
- Flutter has no test for conflicts, `custom:` dispatch, caps extensions or triggers: the natives' tests and
  fixtures 45-47 become the first pins (fixtures run on Flutter too).
- Triggers are metadata only in Flutter (the merged map is never read); a builder fires `actions[name]`.
- The CLI has only a TypeScript generator, no generator tests; `orca plugin generate` needs a pubspec. Only
  plugins/orca_google_map/orca_plugin.yaml has a `schema:` block (GoogleMap + moveCamera).
- Natives today: Swift `WidgetView` is a closed switch (default draws nothing); Kotlin `WidgetBuilders` internal;
  both ActionExecutors drop any kind outside the built-in list; both clients' caps are fixed at init; both
  native fixture runners pin 15 action fixtures; `WidgetBuildersTest` pins `shared` to the advertised types.
- Plugin names cannot go in capabilities.json (gen-native-capabilities.ts validates them); no generated file
  changes in this step.

### Design (written here; 05-07 skipped)
The design in force is the session scratchpad's `s16/design.md`, summarised: D1 contract types
(`TriggerDefinition`, `OrcaActionHandler`); D2 `registerHandler` + exact-then-bare dispatch + raw action +
`resolve`; D3 `PluginMerger` with Flutter's four messages (Swift `OrcaPluginConflict`, Kotlin
`IllegalArgumentException`), keys in sorted order on both natives; D4
`OrcaClient.registerCapabilityExtensions` (bare + `custom:`, copies share the set, hash follows); U1
`OrcaPlugin` + public builder types; U2 public `WidgetBuilders` (Swift new, Kotlin made public, per app);
U3 `OrcaApp(plugins:, customActions:, widgets:)` on every initializer, merge once, a conflict shows the
error view; fixtures 45-47 with a `handlers` field; CLI `--lang swift|kotlin`, `--manifest`, `--package`;
demo on examples/server's `custom` app.

### Cases (07 rows of this slice; each has a Swift cell /S and a Kotlin cell /K)
| C16.1 | A host registers a plugin with a new widget type; the capability list grows; the server sends it; it draws. | unit + hand |
| C16.2 | A custom action handler runs with its params, including the custom: prefix dispatch. | unit |
| C16.3 | Two plugins claiming the same widget name fail the way Flutter's plugin merger does. | unit |
| C16.4 | A plugin-declared trigger can be fired. | unit |
| C16.5 | A plugin can override a built-in action handler. | unit |
| C16.6 | The orca CLI generates Swift and Kotlin stubs from orca_plugin.yaml that compile. | unit |

### Groups
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Swift contract, merger, capability extensions | sdk-swift/Sources/OrcaGatewayCore/Plugins/PluginMerger.swift (new) · sdk-swift/Sources/OrcaGatewayCore/Capabilities/CapabilityVector.swift · sdk-swift/Sources/OrcaGatewayCore/Client/OrcaClient.swift · sdk-swift/Tests/OrcaGatewayCoreTests/PluginMergerTests.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/OrcaClientTests.swift | C16.3/S | M | — |
| 1 | T2 | Kotlin contract, merger, capability extensions | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/plugins/PluginMerger.kt (new) · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/CapabilityVector.kt · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/OrcaClient.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/plugins/PluginMergerTest.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/OrcaClientTest.kt | C16.3/K | M | — |
| 2 | T3 | Fixtures 45-47, Flutter handlers runner | schema/fixtures/actions/45_custom_action_dispatch.json (new) · schema/fixtures/actions/46_custom_action_unhandled.json (new) · schema/fixtures/actions/47_handler_overrides_builtin.json (new) · sdk/test/conformance/action_fixtures_test.dart · schema/action-fixture.schema.json (added in 09) | fixtures of C16.2, C16.5 (Flutter run; enables /S, /K) | M | — |
| 2 | T4 | Swift handler registry, resolve, fixture runner | sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift · sdk-swift/Tests/OrcaGatewayCoreTests/ActionHandlerTests.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ActionFixtureTests.swift · sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift (added in 09) | C16.2/S | M | T1 |
| 2 | T5 | Kotlin handler registry, resolve, fixture runner | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionHandlerTest.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionFixtureTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt (added in 09) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt (added in 09) | C16.2/K | M | T2 |
| 3 | T6 | Swift OrcaPlugin, WidgetBuilders, plugin drawing | sdk-swift/Sources/OrcaGateway/OrcaPlugin.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift · sdk-swift/Tests/OrcaGatewayTests/PluginWidgetTests.swift (new) | C16.4/S | M | T1 |
| 3 | T7 | Kotlin OrcaPlugin, public WidgetBuilders | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPlugin.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/PluginWidgetTest.kt (new) | C16.4/K | M | T2 |
| 4 | T8 | Swift OrcaApp plugins, customActions, boot failure | sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Sources/OrcaGateway/Navigation/OrcaRouter.swift · sdk-swift/Sources/OrcaGateway/OrcaBoot.swift · sdk-swift/Sources/OrcaGateway/OrcaPluginHost.swift (new) · sdk-swift/Tests/OrcaGatewayTests/OrcaAppPluginTests.swift (new) | C16.1/S, C16.5/S | M | T1, T4, T6 |
| 4 | T9 | Kotlin OrcaApp plugins, customActions, boot failure | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/OrcaRouter.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaBoot.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPluginHost.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppPluginTest.kt (new) | C16.1/K, C16.5/K | M | T2, T5, T7 |
| 4 | T10 | CLI Swift/Kotlin generators, flags | cli/lib/src/generators/swift_generator.dart (new) · cli/lib/src/generators/kotlin_generator.dart (new) · cli/lib/src/commands/plugin_generate.dart · cli/test/plugin_generate_test.dart (new) · cli/README.md | C16.6 CLI part (--lang/--manifest/--package, ts unchanged, schema-less manifest; enables /S, /K) | M | T6, T7 |
| 5 | T11 | Swift google_map stubs, drift test | sdk-swift/Tests/OrcaGatewayTests/Generated/OrcaGoogleMapPlugin.swift (new) · sdk-swift/Tests/OrcaGatewayTests/GeneratedPluginTests.swift (new) · cli/test/swift_generator_test.dart (new) | C16.6/S | M | T1, T6, T10 |
| 5 | T12 | Kotlin google_map stubs, drift test | sdk-kotlin/sdk/src/test/kotlin/orca/plugins/OrcaGoogleMapPlugin.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/GeneratedPluginTest.kt (new) · cli/test/kotlin_generator_test.dart (new) | C16.6/K | M | T2, T7, T10 |
| 5 | T13 | iOS demo plugins, Swift docs | examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md · sdk-swift/README.md | C16.1 hand/S (enables) | M | T8 |
| 5 | T14 | Android demo plugins, Kotlin docs | examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/DemoPlugins.kt (new) · examples/app-android/README.md · sdk-kotlin/README.md | C16.1 hand/K (enables) | M | T9 |

### Order, and why each boundary
- Kind: feature, so there is no scaffold and no regression-first case. Each group has at most one Swift task and one
  Kotlin task (step 15's run constraint). That makes each SDK a lane of five tasks over five groups. CLI, fixture and
  example tasks run beside the lanes. Extra gate runs: `cd sdk && flutter test` in group 2, `cd cli && dart test &&
  dart analyze` in groups 4 and 5, everything (engine included) in group 5.
- 1 → 2: T4 and T5 register handlers typed `OrcaActionHandler`, which T1 and T2 create. T3 sits in group 2, not group
  1: the natives pin the fixture count at 15, so three new fixtures at the group-1 gate would turn both suites red.
  T3 is committed first in group 2; T4 and T5 raise the pin to 18 and read its files (a data coupling only).
- T1 and T2 also carry D1's `TriggerDefinition` and `OrcaActionHandler` (in PluginMerger.swift/.kt) and D4, the
  capability extensions, tested in OrcaClientTests/OrcaClientTest.
- 2 → 3: T6 and T7 build `OrcaPlugin` on T1's and T2's types; they come after T4/T5 only for the one-task-per-lane rule.
- 3 → 4: T8 and T9 merge with T1/T2, register caps through T1/T2's extensions, call T4/T5's `registerHandler` on each
  page's executor, and build per-app WidgetBuilders from T6/T7. T10's output targets the API T6 and T7 make public.
- 4 → 5: T11 and T12 commit T10's output for plugins/orca_google_map/orca_plugin.yaml and compile and merge it against
  T6/T7; their drift tests sit in separate cli/test files. T13 and T14 pass `plugins` and `customActions` to T8/T9's
  OrcaApp.

### Seams
none: no file is named by two tasks. Each file that sibling branches also edit goes to exactly one task: OrcaClient
(T1, T2), ActionExecutor (T4, T5), NodeView.swift (T6), WidgetBuilders.kt (T7), OrcaApp.swift/.kt (T8, T9).

### Done when
test: Swift `cd sdk-swift && swift build --build-tests && swift test` and `xcodebuild test -scheme OrcaGateway-Package
-destination 'id=04AFD6DE-2948-48F6-B402-1C3B39FEB88A' -only-testing:OrcaGatewayTests` · Kotlin `cd sdk-kotlin &&
./gradlew build --console=plain` · Flutter `cd sdk && flutter test` (G2, G5) · CLI `cd cli && dart test` (G4, G5) ·
engine `cd engine && bun test` (G5) · lint: the Gradle build, `dart analyze` (cli), 0 Swift warnings · typecheck: none
(compilers).
baseline: engine 737 pass · Flutter +246 · Swift core 284, SwiftUI 66 executed (62 + 4 golden skips), 0 failures,
0 warnings · Kotlin core 286, sdk 143, 0 failures, lint clean · CLI +17, analyze clean, 2026-11-15 (a6f609d).
commits: per task (feat/native-parity-s16) · gate: per group (answered at gate 08, 2026-11-15)

### Changed in 09 (group 2)
T3 found two more readers of the action fixtures: each native ModelRoundTripTests pins the count and decodes
every action and effect strictly, and schema/action-fixture.schema.json rejects the `handlers` field and handler
records. T4 and T5 take their round-trip test; T3 takes the fixture schema (5 files each at most still holds).

### Not planned
none: all 6 cases are placed. T1, T2 and T4-T9 hold ten unit cells, and T11/T12 hold C16.6/S and C16.6/K. T3 and T10
hold the shared fixture and CLI parts. T13/T14 make the two C16.1 hand cells checkable; the main session ticks them
after group 5 with ORCA_APP_ID=custom on the iOS simulator and the Android emulator.
