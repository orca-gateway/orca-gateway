# 09 · Implementation · native-parity-s16

## Front page

### In one breath
group 5 of 5 - tasks: 14 of 14 green, 0 blocked - cases: 6 of 6 green on both SDKs (C16.1-C16.6)
After the rebase onto main: Swift 325 + SwiftUI 99 (+4 golden skips), Kotlin 327 / 176,
engine 738, Flutter 306, cli 27, analyze clean; both example apps build.
T11/T12: the CLI's google_map stub compiles and runs in both SDKs' tests; drift tests in cli.
T13/T14: demo plugins in both example apps; C16.1 seen on the simulator and the emulator.
Rebased on origin/main (PRs #30 and #31): plugins now reach step 9's config-boot pages too.

### New for you
nothing new

### Trade-offs
3 auto-decided: drift tests run the CLI command; the iOS demo badge is a Button (the hand
check caught `.onTapGesture` dropping a held tap); demo actions log a line

### Questions for you
1. `A` approves the stage: stage 10 pushes the branch and opens the step 16 PR. (default: go)

## Appendix

### Group 1
Commits (staged by path, then rebased onto feat/native-parity-s15 at 9236afc): T1 53a039b · T2 48b35db.
Gate 08 approved under your standing rule. One Swift and one Kotlin implementer at once.

#### Task T1 · Swift contract, merger, capability extensions
Files: `sdk-swift/Sources/OrcaGatewayCore/Plugins/PluginMerger.swift` · `Capabilities/CapabilityVector.swift` ·
`Client/OrcaClient.swift` · `Tests/OrcaGatewayCoreTests/PluginMergerTests.swift` · `OrcaClientTests.swift`
Cases: C16.3/S → green (13 merger + 5 client tests) · baseline unchanged (core 302 = 284 + 18). Red first: compile.
Changed: `TriggerDefinition`, `OrcaActionHandler`, `PluginParts`, `PluginMergeResult`, `OrcaPluginConflict`,
`PluginMerger.merge` (Dart's order, the four messages verbatim, first conflict wins); `CapabilityVector.adding`
(sorted union, actions bare + `custom:`); OrcaClient's `capabilities`/`capsHash` computed from a lock-guarded box
copies share, recomputed on growth; public `registerCapabilityExtensions(widgets:actions:)`.
Decisions: 1. `[String]` parameters · 2. Result sets computed from `widgetOwners` · 3. Keys sorted (UTF-16), as
Kotlin; the 412 retry reads vector and hash once, so header and body agree.
Review fit: pass
Review quality: pass
Not done: `registerHandler` (T4) and the OrcaApp wiring (T8). Linux build left to CI (Foundation only).

#### Task T2 · Kotlin contract, merger, capability extensions
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/plugins/PluginMerger.kt` · `capabilities/CapabilityVector.kt` ·
`client/OrcaClient.kt` · `core/src/test/.../plugins/PluginMergerTest.kt` · `client/OrcaClientTest.kt`
Cases: C16.3/K → green (10 merger + 6 client tests) · baseline unchanged (core 302 = 286 + 16, sdk 143). Red first: compile.
Changed: the same types (`fun interface OrcaActionHandler`; `IllegalArgumentException` with the four messages);
`CapabilityVector.adding`; OrcaClient keeps today's public constructor, a private primary one takes a shared
synchronized holder that `copy(...)` passes on; `capabilities`/`capsHash` computed and cached; headers and the 412
body use the extended vector; `registerCapabilityExtensions`.
Decisions: 1. `copy(capabilities =)` changes the base and keeps the shared extensions · 2. The holder keeps names as
registered; `adding` doubles · 3. `widgetTypes` and `pluginWidgetTypes` are the same set (as Swift).
Review fit: pass
Review quality: pass
Not done: `registerHandler` (T5) and the OrcaApp wiring (T9).

### Group 2
Commits (staged by path): T3 71544df · T4 38d534b · T5 ec496a7. Group 1's card approved under your standing rule.
T3's first pass found two more readers of the action fixtures (the native round-trip tests and the fixture schema);
T4 and T5 took their round-trip test (T5 also a third count pin, FixturePathsTest), T3 took the schema.

#### Task T3 · Fixtures 45-47, Flutter handlers runner
Files: `schema/fixtures/actions/45_custom_action_dispatch.json` · `46_custom_action_unhandled.json` ·
`47_handler_overrides_builtin.json` · `sdk/test/conformance/action_fixtures_test.dart` · `schema/action-fixture.schema.json`
Cases: fixtures of C16.2 and C16.5 → green on Flutter (+18 in the runner; full flutter test 249 = 246 + 3). Red first:
45 had no effects and 47 emitted the built-in clipboard effect until the runner registered handlers; 46 pins today.
Changed: three fixtures from the spec; the runner registers a recording handler per `handlers` name (a copy of the
raw action); the schema gains optional `handlers` and a HandlerEffect record (oneOf beside Effect, unchanged).
Decisions: 1. Raw map copied · 2. oneOf for effect items (disjoint shapes) · 3. HandlerEffect.action a plain object.
Review fit: pass
Review quality: pass
Not done: no JSON Schema validator in the repo (checked by reading and a stdlib script, 18/18). Found, outside this
step: action.schema.json's oneOf ends in a catch-all CustomAction, so strict draft-07 rejects valid built-ins.

#### Task T4 · Swift handler registry, resolve, fixture runner
Files: `sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift` · `Tests/OrcaGatewayCoreTests/ActionHandlerTests.swift` ·
`ActionFixtureTests.swift` · `ModelRoundTripTests.swift`
Cases: C16.2/S → green (9 tests; fixtures 45-47 on Swift) · baseline unchanged (core 311 = 302 + 9). Red first: compile,
then the count and 45-47.
Changed: public `registerHandler` and `resolve`; before the kinds guard, the exact type then the type without
`custom:` finds a handler, which gets the raw JSON (built-ins re-encoded); otherwise today's path; `kinds` unchanged.
Runner and round trip: 18 files, recording handlers, handler records skipped, `.unknown` only for a handler name.
Decisions: 1. Handler runs report a DevTools action event (as Dart) · 2. "Every kind implemented" counts custom:
kinds and handler names · 3. The stricter round-trip allowance.
Review fit: pass
Review quality: pass
Not done: the OrcaApp wiring (T8).

#### Task T5 · Kotlin handler registry, resolve, fixture runner
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt` · `core/src/test/.../state/ActionHandlerTest.kt` ·
`state/ActionFixtureTest.kt` · `models/ModelRoundTripTest.kt` · `FixturePathsTest.kt`
Cases: C16.2/K → green (10 tests; fixtures 45-47 on Kotlin) · baseline unchanged (core 312 = 302 + 10, sdk 143). Red first:
compile.
Changed: the same as T4 (raw JsonObject; CancellationException not swallowed); runner, round trip and FixturePathsTest
at 18; the round-trip allowance scoped as Swift's.
Decisions: 1. DevTools action event for handler runs · 2. `{"type": kind}` if a typed action cannot re-encode (wire
JSON never does) · 3. FixturePathsTest's pin raised.
Review fit: pass
Review quality: pass
Not done: the OrcaApp wiring (T9).

### Group 3
Commits (staged by path): T7 c8d0639 · T6 6a28dc9. Group 2's card approved under your standing rule.

#### Task T6 · Swift OrcaPlugin, WidgetBuilders, plugin drawing
Files: `sdk-swift/Sources/OrcaGateway/OrcaPlugin.swift` · `NodeView.swift` · `OrcaPageModel.swift` ·
`Tests/OrcaGatewayTests/PluginWidgetTests.swift`
Cases: C16.4/S → green (3 tests) and C16.1's drawing part (4 tests) · baseline unchanged (core 311; SwiftUI 73
executed = 66 + 7, 4 golden skips). Red first: compile.
Changed: `OrcaWidgetBuilder`, `OrcaPlugin` (empty defaults; `parts` for the merger), a `@MainActor` `WidgetBuilders`
(register adds or replaces, `builder(for:)`, `types`); WidgetView's `default:` draws the model's builder for the type,
else nothing; OrcaPageModel gains a last init parameter `widgets`. Drawing checked with ImageRenderer (as FlexLayoutTests).
Decisions: 1. `WidgetBuilders.init()` nonisolated (a default argument) · 2. Lookup only in `default:` (built-in names
never reach a plugin; the merger rejects that clash) · 3. The `model.fire` test was red only through the compile.
Review fit: pass
Review quality: pass
Not done: the per-app registry, builders, caps and handlers in OrcaApp (T8).

#### Task T7 · Kotlin OrcaPlugin, public WidgetBuilders
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPlugin.kt` · `WidgetBuilders.kt` ·
`sdk/src/test/kotlin/com/orcagateway/sdk/PluginWidgetTest.kt`
Cases: C16.4/K → green (5 tests, with NodeView drawing a plugin builder) · baseline unchanged (core 312, sdk 148 =
143 + 5). Red first: compile.
Changed: `OrcaPlugin` (name; widgets/actions/triggers default empty) and `toParts()`; `WidgetBuilder`, `WidgetBuilders`,
`get`, `register`, `types`, `standard()` public with KDoc; `shared` and the logging helpers internal; `shared` untouched.
Decisions: 1. Only the design's members public · 2. `toParts` copies the widget names · 3. No internal type leaks into
the public signature; `OrcaPageModel.builders` stays internal for T9.
Review fit: pass
Review quality: pass
Not done: the per-app registry, builders, caps and handlers in OrcaApp (T9).

### Group 4
Commits (staged by path): T8 17dfcdb · T10 6cfcd9d · T9 7fe9e18. Group 3's card approved under your standing rule.
PR #31 merged meanwhile (c0b8645); this branch is still on 9236afc and rebases onto origin/main at stage 10.

#### Task T8 · Swift OrcaApp plugins, customActions, boot failure
Files: `sdk-swift/Sources/OrcaGateway/OrcaApp.swift` · `Navigation/OrcaRouter.swift` · `OrcaBoot.swift` ·
`OrcaPluginHost.swift` (new) · `Tests/OrcaGatewayTests/OrcaAppPluginTests.swift` (new)
Cases: C16.1/S unit part and C16.5/S → green (6 tests) · baseline unchanged (core 311; SwiftUI 79 executed = 73 + 6,
4 golden skips). Red first: compile.
Changed: internal `@MainActor OrcaPluginHost` (merges once, lazily; `failure`; `attach(_ router:)` registers only the
plugins' names; `page(...)` builds each page with the per-app registry and builders and the merged handlers); both
OrcaApp initializers take `plugins`, `customActions`, `widgets`; OrcaPageLoader builds every page (first and pushed)
through `router.plugins`; OrcaRouter `var plugins`; OrcaBoot `Phase.failed(String)` (no version request, no sessions)
and a BootErrorView.
Decisions: 1. The page error view's headline with the conflict message, no retry (asked you; minor, decided) · 2. No
plugin or host widget keeps `WidgetRegistry.shared` · 3. Tests drive the host, router and boot model OrcaApp wires.
Review fit: pass
Review quality: pass
Not done: C16.1's hand check (group 5).

#### Task T9 · Kotlin OrcaApp plugins, customActions, boot failure
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt` · `navigation/OrcaRouter.kt` · `OrcaBoot.kt` ·
`OrcaPluginHost.kt` (new) · `sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppPluginTest.kt` (new)
Cases: C16.1/K unit part and C16.5/K → green (4 tests) · baseline unchanged (core 312; sdk 152 = 148 + 4). Red first:
compile.
Changed: internal `OrcaPluginHost` (`merge(client, plugins, customActions, widgets)`, per-app registry and a new builders
instance, `install(model)`); both OrcaApp overloads take the three parameters; OrcaPageLoader installs it on every
page; RoutePage's error column becomes internal `OrcaErrorView(message, modifier, onRetry?)`; `OrcaBoot(..., prepare)`
with `Phase.Failed`; OrcaRouter `internal var plugins`.
Decisions: 1. Per-app builders a new instance (the host's `widgets` untouched) · 2. The error view without "Try again"
· 3. A per-app registry even with no plugins (FallbackPrompt's DevTools event once per app).
Review fit: pass
Review quality: pass
Not done: C16.1's hand check (group 5).

#### Task T10 · CLI Swift/Kotlin generators, flags
Files: `cli/lib/src/generators/swift_generator.dart` (new) · `kotlin_generator.dart` (new) ·
`cli/lib/src/commands/plugin_generate.dart` · `cli/test/plugin_generate_test.dart` (new) · `cli/README.md`
Cases: C16.6 generator part → green (8 tests) · baseline unchanged (`dart test` +25 = 17 + 8; analyze clean). Red first:
the test file did not load.
Changed: SwiftGenerator (`#if canImport(SwiftUI)`, `<W>Props`, `<A>Params`, `public struct <P>Plugin: OrcaPlugin`) and
KotlinGenerator (`package` first, used-only imports, `public class <P>Plugin : OrcaPlugin`); `--lang ts|swift|kotlin`
(unknown exits 64), `--manifest`, `--package`; TS output and the pubspec flow byte for byte unchanged; README section.
The Swift output compiled in a scratch package against HEAD's sdk-swift (Swift 5 and 6, warnings as errors).
Decisions: 1. `PluginGenerateCommand({root})` for temp-dir tests · 2. Kotlin header after `package` · 3. `--manifest`
ignores `--plugin`; the native langs write name-only stubs for schema-less plugins.
Review fit: pass
Review quality: pass
Not done: the Kotlin compile proof and both drift tests (T11, T12); keyword prop names are not escaped.

### Group 5
Commits (staged by path): T11 5d79d83 · T12 44815c2 · T14 5636a88 · T13 0af4d3a. Group 4's card approved under your
standing rule. T11 and T12 first (one Swift and one Kotlin build at a time), then T13 and T14.

#### Task T11 · Swift google_map stubs, drift test
Files: `sdk-swift/Tests/OrcaGatewayTests/Generated/OrcaGoogleMapPlugin.swift` (new) · `GeneratedPluginTests.swift` (new) ·
`cli/test/swift_generator_test.dart` (new)
Cases: C16.6/S → green (3 tests + the drift test) · baseline unchanged (core 311; SwiftUI 82 executed = 79 + 3, 4 golden
skips; cli +27). Red first: no stub, then the missing type.
Changed: the stub is the CLI's output, unchanged (no generator fix, no Package.swift change); the tests merge it, draw its
placeholder (ImageRenderer) and run its handler through a recording wrapper; the drift test runs the command into a temp
dir and compares with the committed file, printing the regenerate command.
Decisions: 1. The drift test runs the command · 2. UTF-8 string comparison for a readable diff · 3. A recording wrapper.
Review fit: pass
Review quality: pass
Not done: nothing.

#### Task T12 · Kotlin google_map stubs, drift test
Files: `sdk-kotlin/sdk/src/test/kotlin/orca/plugins/OrcaGoogleMapPlugin.kt` (new) · `.../sdk/GeneratedPluginTest.kt` (new) ·
`cli/test/kotlin_generator_test.dart` (new)
Cases: C16.6/K → green (3 tests + the drift test) · baseline unchanged (core 312; sdk 155 = 152 + 3). Red first: the
unresolved `orca.plugins` names, and no stub.
Changed: the stub is the CLI's output, unchanged; it compiles with warnings as errors (the generator's first Kotlin
compile, no fix needed); the same three tests and the drift test as Swift.
Decisions: 1. The drift test runs the command (covers the default package) · 2. Tests also read the props and params.
Review fit: the handler test never proved the handler ran (ActionExecutor returns quietly for an unhandled `custom:`
kind), fixed (a recording wrapper; red under a wrong name, then green)
Review quality: pass
Not done: nothing.

#### Task T13 · iOS demo plugins, Swift docs
Files: `examples/app-ios/OrcaCounter/OrcaCounterApp.swift` · `examples/app-ios/README.md` · `sdk-swift/README.md`
Cases: C16.1/S hand part enabled; no red step (an example app). App build 0 warnings; core 311 unchanged.
Changed: OrcaApp gets `plugins: [BadgePlugin(), DeviceActionsPlugin()]`; BadgePlugin draws ColoredBadge and fires its
onTap; DeviceActionsPlugin plays haptics and prints the other actions; a `custom` row and a Plugins section in the app
README; a Plugins section in sdk-swift's README.
Decisions: 1. `print` with a prefix · 2. processPayment only logs · 3. A hex parser in the app (the SDK's is internal).
Review fit: pass (both lenses passed again after the hand-check rework)
Review quality: pass
Hand check: the badge tap showed no snackbar: `.onTapGesture` drops a touch held about a second (the simulator tool's
tap); fixed by a rework (the badge is a plain-style Button, an accessibility button too), then seen on the simulator.
Not done: nothing.

#### Task T14 · Android demo plugins, Kotlin docs
Files: `examples/app-android/.../counter/MainActivity.kt` · `DemoPlugins.kt` (new) · `examples/app-android/README.md` ·
`sdk-kotlin/README.md`
Cases: C16.1/K hand part enabled; no red step. `./gradlew assembleDebug` (warnings as errors) green; sdk build unchanged.
Changed: `plugins = listOf(BadgePlugin(), DeviceActionsPlugin(window.decorView))`; DemoPlugins.kt (Compose badge;
haptics through the view; every demo action logs under `OrcaDemoPlugins`); README sections.
Decisions: 1. Haptics through the decor view, no permission · 2. Only a badge with onTap is clickable · 3. Log lines.
Review fit: the README said the engine's `Custom("hapticFeedback")` sends a `custom:` prefix; it sends the name as
given, fixed (`Custom("custom:hapticFeedback", ...)`)
Review quality: the colour parser also read `#AARRGGBB` (alpha first, unlike the SDK's `#RRGGBBAA`), fixed (`#RRGGBB` only)
Not done: nothing.

#### Seam task R1 · rebase onto origin/main (after PRs #30 and #31 merged)
Old tip 76d16df; 15 commits replayed, messages kept (T9's last sentence reworded after review: main's ErrorView becomes
internal with an optional retry). Swift: OrcaAppBoot gets the plugin host (advertises the plugin names before /config,
attaches it to the path router and to the config router); Kotlin: OrcaAppBoot is made before the gate, whose `prepare`
merges the plugins into it; one internal ErrorView. Fixture pins: actions 18, navigation 11. No generated file changed.
New tests: Swift `testC16_1_TheRoutersOrcaAppBootMakesBuildTheirPagesWithThePlugins`, Kotlin
`c16_1_anAppBootedFromTheConfigAsksItWithThePluginNamesAndItsPagesDrawThePluginWidget` (red without the wiring).
Review fit: the T9 message still named OrcaErrorView, fixed (reworded; trees identical)
Review quality: Swift kept BootErrorView as a copy of main's LoadError, fixed (LoadError internal with an optional
retry, BootErrorView deleted; commit `refactor(sdk-swift): one error view…`; swift 325, SwiftUI 103 / 4 skips, app builds)

#### R2 · Rebase onto origin/main 82e9027 (PR #33), and the Linux Swift 5.10 check
CI's "Core tests (swift 5.10-jammy, linux)" failed: Linux test discovery cannot call a synchronous `@MainActor` test
(`testC16_2_KindsStayTheBuiltInList`), now `async`; no other synchronous `@MainActor` test is left in the core tests.
Rebase conflicts: FixturePathsTest.kt (render 41 from main, actions 18 from here) and OrcaApp.kt (main's retained
ViewModel kept; the retained boot is made before the gate; plugins merged only while `plugins == null`, once per kept
router or boot, so a rotation does not merge again; `widgets` defaults to `WidgetBuilders.shared` so main's A1.13
probes still draw). Two recreation tests in OrcaAppPluginTest (red first: 2 widget reads became 4). No generated file
changed. Old tip 6564b9e, new tip ecf949c.
Review fit: pass
Review quality: pass

### Hand checks (C16.1)
Example server on :8094, app id `custom`. iOS simulator 04AFD6DE and Android emulator-5584: the three ColoredBadges are
drawn by the app's BadgePlugin (the server keeps them because the caps advertise ColoredBadge); a tap on CUSTOM BADGE
runs hapticFeedback (light) and shows "Badge tapped!"; Trigger Haptic runs hapticFeedback (heavy) and the counts go up
(Android logcat: `hapticFeedback light`, `hapticFeedback heavy`). Screenshots: session scratchpad
`s16/hand-c16-1-ios.png`, `s16/hand-c16-1-android.png`.

### Test run
After R2 (origin/main 82e9027): engine 740 · Flutter 308 · cli +27, analyze clean · Swift 0 warnings, `swift test`
325 · SwiftUI on the iOS 18.5 simulator CI uses: pass; on iOS 26.5 (04AFD6DE) 157 run, 4 golden skips, 4 of main's tests
fail as on origin/main alone (AppBarCardTests A1_9 ×3, ButtonTests D11) · Kotlin core 327, sdk 234 · both app builds.
After the rebase onto origin/main 81b4bc1 (R1, below): engine `bun test` 738 pass · Flutter 306 · cli +27, analyze
clean · Swift 0 warnings, `swift test` 325 · `xcodebuild test -only-testing:OrcaGatewayTests` 103 executed, 4 skipped
(goldens), 0 failures · Kotlin core 327, sdk 176 · iOS and Android example builds succeed. Group 5 (before the
rebase): engine 737 · Flutter 249 · cli +27, analyze clean · Swift 311 / SwiftUI 82 (4 skips) · Kotlin 312 / 155.
Group 4: cli `dart test` +25, `dart analyze` no issues · Swift `swift build --build-tests` 0 warnings, `swift test`
311, 0 failures · `xcodebuild test -only-testing:OrcaGatewayTests` 79 executed, 4 skipped (goldens), 0 failures · Kotlin
`./gradlew build` exit 0, core 312, sdk 152, 0 failures, 0 skipped. Group 3: Swift `swift build --build-tests` 0 warnings, `swift test` 311, 0 failures · `xcodebuild test
-only-testing:OrcaGatewayTests` 73 executed, 4 skipped (goldens), 0 failures · Kotlin `./gradlew build` BUILD SUCCESSFUL,
core 312, sdk 148, 0 failures, 0 skipped. Group 2: Flutter 249 · Swift 311 · Kotlin 312 / 143. Group 1: Swift 302 ·
Kotlin 302 / 143. Failures: none. Files changed: the tasks' files only.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
This branch is stacked on feat/native-parity-s15 (PR #31). OrcaClient's `capabilities`/`capsHash` become computed
on both SDKs (same names; source-compatible for readers). No config, env or migration so far.
PR #31 is merged (c0b8645): rebase onto origin/main before the PR; OrcaApp.swift/.kt also change in PR #30 (Phase B).
