# 08 · Tasks · native-parity-s9

## Front page

### In one breath
tasks: 10 in 5 groups · widest group: 2 · cases: 10 of 10 placed (3 hand legs wait for stage 10)
Step 9 of the parity plan: both native SDKs boot from the server's `/config`.
G1: the new `schema/fixtures/navigation/` family, proven on Flutter, beside the demo app.
G2: `NavConfig` and `fetchConfig` in both cores. G3: `RouteTable` passes the fixtures.
G4: both routers resolve, redirect, share app state, report route changes.
G5: `OrcaApp` boots from the config and draws the title bar. Swift and Kotlin run side by side.

### New for you
nothing new

### Trade-offs
2 auto-decided: fixtures take their expected values from Flutter's real router; `path` stays as an
optional host override, so today's hosts keep working.

### Questions for you
1. Commands: every suite as at native-sdk-s18, from the Taskfile. (default: as found)
2. Commits: one per task on `feat/native-parity-s9`; nothing pushed before stage 10. (default: yes)
3. One gate per group, 5 groups. (default: yes)
4. `OrcaApp(client:)` with no `path` now fetches the config instead of opening `home`; a host
   that passes `path` is unchanged. The plan asks for it. (default: yes)
5. A config with tabs runs as one stack until step 10 lands the tab shell. (default: yes)

## Appendix

### Where S9 comes from
Step 9 of `/Users/amrebada/.claude/plans/native-parity/plan.md` (Phase B, approved 2026-11-15), test rows
B9.1 to B9.10 of `phase-b-tests.md`. Stages 01-07 skipped as covered by the plan; the design and the cases are
in `design-brief.md` beside this file, checked against the Flutter source on 2026-11-15. Branch
`feat/native-parity-s9` from the worktree's start, which carries the unpushed local commit `5c6b57e`.

### Groups
Paths from the repo root. Case ids carry their leg: -F / -S / -K the Flutter / Swift / Kotlin fixture runner,
-CS / -CK the core client leg, -US / -UK the UI-layer test, -D the demo server, -H the hand check.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Navigation fixture contract, Flutter as oracle | `schema/navigation-fixture.schema.json` (new) · `schema/fixtures/navigation/*.json` (new) · `schema/fixtures/navigation/README.md` (new) · `sdk/test/conformance/navigation_fixtures_test.dart` (new) | B9.2-F, B9.3-F, B9.4-F, B9.5-F, B9.9-F, B9.10-F | M | none |
| 1 | T2 | Navigation demo app on the example server | `examples/server/navigation.ts` (new) · `examples/server/index.ts` · `examples/server/README.md` · `engine/test/demo-server.test.ts` | B9.4-D | M | none |
| 2 | T3 | Swift core: NavConfig model, fetchConfig | `sdk-swift/Sources/OrcaGatewayCore/Models/NavConfig.swift` (new) · `sdk-swift/Sources/OrcaGatewayCore/Client/OrcaClient.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/OrcaClientTests.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/Support/Fixtures.swift` | B9.1-CS | M | T1 |
| 2 | T4 | Kotlin core: NavConfig model, fetchConfig | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/models/NavConfig.kt` (new) · `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/OrcaClient.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/OrcaClientTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/support/Fixtures.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt` | B9.1-CK | M | T1 |
| 3 | T5 | Swift core: RouteTable passes the navigation fixtures | `sdk-swift/Sources/OrcaGatewayCore/Navigation/RouteTable.swift` (new) · `sdk-swift/Sources/OrcaGatewayCore/Navigation/RouteChangeEvent.swift` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/NavigationFixtureTests.swift` (new) | B9.2-S, B9.3-S, B9.4-S, B9.5-S, B9.9-S, B9.10-S | M | T1, T3 |
| 3 | T6 | Kotlin core: RouteTable passes the navigation fixtures | `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/navigation/RouteTable.kt` (new) · `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/navigation/RouteChangeEvent.kt` (new) · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/navigation/NavigationFixtureTest.kt` (new) | B9.2-K, B9.3-K, B9.4-K, B9.5-K, B9.9-K, B9.10-K | M | T1, T4 |
| 4 | T7 | Swift router: config, app state, onRouteChanged | `sdk-swift/Sources/OrcaGateway/Navigation/OrcaRouter.swift` · `sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift` · `sdk-swift/Tests/OrcaGatewayTests/RouterTests.swift` · `sdk-swift/Tests/OrcaGatewayTests/PageModelTests.swift` · `sdk-swift/README.md` | B9.6-US, B9.7-US | M | T5 |
| 4 | T8 | Kotlin router: config, app state, onRouteChanged | `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/OrcaRouter.kt` · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageModel.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/navigation/RouterTest.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/PageModelTest.kt` · `sdk-kotlin/README.md` | B9.6-UK, B9.7-UK | M | T6 |
| 5 | T9 | Swift OrcaApp: config boot, title bar | `sdk-swift/Sources/OrcaGateway/OrcaApp.swift` · `sdk-swift/Tests/OrcaGatewayTests/AppBootTests.swift` (new) · `examples/app-ios/OrcaCounter/OrcaCounterApp.swift` · `examples/app-ios/README.md` | B9.1-US, B9.5-US, B9.8-US | M | T3, T7 |
| 5 | T10 | Kotlin OrcaApp: config boot, top bar | `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt` · `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageView.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppTest.kt` · `examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt` · `examples/app-android/README.md` | B9.1-UK, B9.5-UK, B9.8-UK | M | T4, T8 |

### Order, and why each boundary
- 1 → 2: T3 / T4 decode the `config` of every file in `schema/fixtures/navigation/` and pin the file count, so
  the fixtures and their Flutter-proven expected values must exist first.
- 2 → 3: `RouteTable(config)` takes the `NavConfig` / `NavRoute` / `RedirectRule` types of T3 / T4.
- 3 → 4: `OrcaRouter.navigate` calls `RouteTable.resolve` and emits `RouteChangeEvent`, both from T5 / T6.
- 4 → 5: `OrcaApp` builds the router with a config, seeds through `setAppState`, forwards `onRouteChanged` and
  draws `scaffoldTitle` and the not-found page from the router's resolution; it also calls `fetchConfig`.
- Five groups, not four: each core and each UI layer needs six or seven files, over the five-file cap, so each
  is cut in two. T2 sits in group 1 because it imports only the engine. The example hosts ride with T9 / T10.
- "Page not found": the router half (no page request) is in T7 / T8; the drawn page in T9 / T10.

### Seams
none: inside every group the two tasks live in disjoint trees; files touched twice are touched in different
groups.

### Done when
- test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` ·
  `cd sdk-kotlin && ./gradlew build`
- lint: `cd sdk && flutter analyze` · Android lint inside `./gradlew build`
- typecheck: none (the compilers)
- baseline: engine 737 pass, 0 fail · Flutter +246 · Swift 234 · Kotlin core 228, sdk 132, BUILD SUCCESSFUL, 2026-11-15

### Not planned
- B9.1-H, B9.4-H, B9.8-H: hand checks on the iOS simulator and the Android emulator, at stage 10, against T2's
  demo app and the hosts of T9 / T10.
- commits: per task on `feat/native-parity-s9` · gate: per group (answered at gate 08, 2026-11-15, under the standing rule: every default)
