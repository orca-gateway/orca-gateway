# 08 · Tasks · native-parity-s14

## Front page

### In one breath
tasks: 16 in 7 groups · widest group: 4 · cases: 6 of 6 placed (24 cells; C14.6's under option A)
Plan step 14 on both native SDKs: Flutter's static flow cache, the saved config for an offline boot,
the version check with saved versions, cleanup, preload(); offline fixtures Flutter also runs.
G1 the fixtures; G2 the two cores; G3 the two UI layers; G4 demos and READMEs, then hand checks.
G5-G7 (persistState/clearState) are planned for "define in all three" and wait on your answer.

### New for you
nothing new

### Trade-offs
3 auto-decided: rows C14.1-C14.5 corrected to Flutter (pages cached from /config at boot, preload
is the host's call); no connectivity monitor, as Flutter; Flutter's unversioned-flow quirk kept

### Questions for you
1. Commands: as step 19 (Swift also on the iOS 18.5 simulator CI uses). (default: as found)
2. Commits: one per task on feat/native-parity-s14 from main 6a7f0e0; PR at the end. (default: yes)
3. One gate per group. (default: yes)
4. needs: decision 3 for G5-G7: persistState/clearState in all three SDKs, or drop. (default: wait)

## Appendix

### Where step 14 comes from
Plan step 14 of /Users/amrebada/.claude/plans/native-parity/plan.md ("Offline and saved state", L, 2 actions): static
flow cache with cache-first loading; config saved for offline boot; flow version check; preload() for a host splash;
actions persistState, clearState (plan decision 3: define and implement in all three SDKs by default, or drop them
from Flutter's advertised list; the Phase C brief makes it the user's call before any Flutter change). Rows
C14.1-C14.6 in phase-c-tests.md. Stages 01-07 skipped as covered by the plan. Branch feat/native-parity-s14 from
origin/main 6a7f0e0, in the Phase C worktree after step 19's PR #43.

### Checked before planning (2026-11-16)
A read-only pass over Flutter, the engine and both natives (session scratchpad `s14/facts.md`, file:line). Flutter:
StaticFlowManager over SharedPreferencesAsync with keys orca_nav_config, orca_flow_versions, orca_pages_<flow>
(static_flow_manager.dart:10-12); "offline" = any /version failure, no connectivity monitor (version_checker.dart:73);
OrcaApp.preload (orca_app.dart:193-232): forceUpdate | offline (saved config or throw) | fresh (saved config, no
/config request) | stale (whole /config fetched and saved); static pages come pre-rendered in /config and are saved
at boot (static_flow_manager.dart:125-151), a network page is never cached (orca_page.dart:162-174); dynamic routes
skipped on both ends; cleanup of versioned flows gone from a refetched config. Natives: the version check only, run
with no saved versions; models already decode isStatic, pages, version, isDynamic and keep rawBody; KeyValueStore
exists; no cache, no saved config, no preload. persistState/clearState: in the schema and engine types, advertised by
Flutter with no handler, decoded and ignored by the natives (s14/decision3.md).

### Row corrections (to write into phase-c-tests.md with the evidence)
- C14.1: a static flow's pages, pre-rendered in /config, are saved at boot; any static page, visited or not, opens
  from the cache with no request, also offline and after a restart; network pages are never cached.
- C14.2: after one online boot; with nothing saved, the boot error "No network and no cached config available".
- C14.3: versions equal → the saved config, no /config request; one differs → the whole /config fetched and saved.
- C14.4: dynamic routes never served from the cache; versioned flows gone from a refetched config are deleted.
- C14.5: preload() is awaited by the host; an OrcaApp given its config and cache fetches nothing on its first frame.
- C14.6: per decision 3.

### Repo
Layout: sdk-swift (OrcaGatewayCore Foundation-only, Linux 5.10 and 6.2 in CI; OrcaGateway SwiftUI), sdk-kotlin (core
pure JVM; sdk Compose + Robolectric), sdk (Flutter, the reference; tests under sdk/test, conformance runners under
sdk/test/conformance), schema (JSON schemas, fixtures), engine (Bun), examples (server, app-ios, app-android).
Conventions: test names start with the row (`testC14_<n>_` Swift, `c14_<n>_` Kotlin); one commit per task; never
`git add -A`; capability names only in the implementing PR, then `bun run schema/gen-native-capabilities.ts`.
Commands: see Done when. Baseline below (origin/main 6a7f0e0, measured 2026-11-16 at step 19's start).

### Groups
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Offline fixtures, Flutter as oracle | schema/offline-fixture.schema.json (new) · schema/fixtures/offline/01_static_flow_boot.json (new) · schema/fixtures/offline/README.md (new) · sdk/test/conformance/offline_fixtures_test.dart (new) · schema/navigation-config.schema.json | C14.1/F, C14.2/F, C14.3/F, C14.4/F, C14.5/F | M | — |
| 2 | T2 | Swift core store, flow cache, preload | sdk-swift/Sources/OrcaGatewayCore/Client/FileKeyValueStore.swift (new) · Client/StaticFlowManager.swift (new) · Client/Preload.swift (new) · Tests/OrcaGatewayCoreTests/StaticFlowManagerTests.swift (new) · Tests/OrcaGatewayCoreTests/OfflineFixtureTests.swift (new) | C14.3/S, C14.4/S | M | T1 |
| 2 | T3 | Kotlin core store, flow cache, preload | sdk-kotlin/core/.../client/FileKeyValueStore.kt (new) · client/StaticFlowManager.kt (new) · client/Preload.kt (new) · core/src/test/.../client/StaticFlowManagerTest.kt (new) · core/src/test/.../client/OfflineFixtureTest.kt (new) | C14.3/K, C14.4/K | M | T1 |
| 3 | T4 | SwiftUI offline boot, cache-first pages | sdk-swift/Sources/OrcaGateway/OrcaApp.swift · OrcaBoot.swift · Navigation/OrcaRouter.swift · Tests/OrcaGatewayTests/OfflineBootTests.swift (new) · Tests/OrcaGatewayTests/OrcaBootTests.swift | C14.1/S, C14.2/S, C14.5/S | M | T2 |
| 3 | T5 | Compose offline boot, cache-first pages | sdk-kotlin/sdk/.../OrcaApp.kt · OrcaBoot.kt · navigation/OrcaRouter.kt · sdk/src/test/.../OfflineBootTest.kt (new) · sdk/src/test/.../OrcaBootTest.kt | C14.1/K, C14.2/K, C14.5/K | M | T3 |
| 4 | T6 | iOS demo ORCA_PRELOAD, offline docs | examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md · sdk-swift/README.md | C14.1/hand-S, C14.2/hand-S | M | T2, T4 |
| 4 | T7 | Android demo ORCA_PRELOAD, offline docs | examples/app-android/.../MainActivity.kt · examples/app-android/README.md · sdk-kotlin/README.md | C14.1/hand-K, C14.2/hand-K | M | T3, T5 |
| 5 | T8 | Flutter persist/clear handlers, restore (needs: user's decision 3) | sdk/lib/src/state/action_executor.dart · state/state_manager.dart · widgets/orca_app.dart · sdk/test/saved_state_test.dart (new) | enables C14.6/F | M | — |
| 5 | T9 | Engine PersistState builder, saved-state demo (needs: user's decision 3) | engine/src/types/action.ts · engine/src/types/index.ts · engine/test/types.test.ts · examples/server/saved-state.ts (new) · examples/server/index.ts | enables C14.6/hand | M | — |
| 5 | T10 | Swift core saved state, advertise both (needs: user's decision 3) | sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift · State/SavedState.swift (new) · sdk-swift/capabilities.json · Capabilities/Generated.swift · Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift | enables C14.6/S | M | — |
| 5 | T11 | Kotlin core saved state, advertise both (needs: user's decision 3) | sdk-kotlin/core/.../state/ActionExecutor.kt · state/SavedState.kt (new) · sdk-kotlin/capabilities.json · capabilities/Generated.kt · core/src/test/.../capabilities/CapabilitiesTest.kt | enables C14.6/K | M | — |
| 6 | T12 | Action fixtures 48-50, Flutter runner (needs: user's decision 3) | schema/action-fixture.schema.json · schema/fixtures/actions/48_persist_state.json (new) · 49_clear_state.json (new) · 50_restore_saved_state.json (new) · sdk/test/conformance/action_fixtures_test.dart | C14.6/F | M | T8 |
| 6 | T13 | Swift action runner: saved, restore (needs: user's decision 3) | sdk-swift/Tests/OrcaGatewayCoreTests/ActionFixtureTests.swift · ModelRoundTripTests.swift | C14.6/S | S | T10 |
| 6 | T14 | Kotlin action runner: saved, restore (needs: user's decision 3) | sdk-kotlin/core/src/test/.../state/ActionFixtureTest.kt · models/ModelRoundTripTest.kt · FixturePathsTest.kt | C14.6/K | M | T11 |
| 7 | T15 | SwiftUI restore at boot, page load (needs: user's decision 3) | sdk-swift/Sources/OrcaGateway/OrcaApp.swift · Navigation/OrcaRouter.swift · OrcaPageModel.swift · Tests/OrcaGatewayTests/SavedStateTests.swift (new) · examples/app-ios/README.md | C14.6/hand-S | M | T4, T9, T10 |
| 7 | T16 | Compose restore at boot, page load (needs: user's decision 3) | sdk-kotlin/sdk/.../OrcaApp.kt · navigation/OrcaRouter.kt · OrcaPageModel.kt · sdk/src/test/.../SavedStateTest.kt (new) · examples/app-android/README.md | C14.6/hand-K | M | T5, T9, T11 |

### Order, and why each boundary
- Each group has at most one Swift and one Kotlin task, so each SDK is a lane from G2 to G7. Extra runs: `flutter
  test` at G1, G5, G6; `bun test` at G5.
- 1 → 2: T2/T3's runners read T1's format and file (each case: the saved store, the /version answer or a failure,
  the /config answer; expected requests, result, store after, paths the cache serves). Flutter runs them through
  StaticFlowManager + OrcaApp.preload with http's MockClient and a fake SharedPreferencesAsync; no lib change.
- 2 → 3: T4/T5 call T2/T3's preload, StaticFlowManager (initDynamicPaths, getCachedPage) and FileKeyValueStore in the
  directory the UI layer picks; they drop the gap notes (OrcaApp.swift:280-283, OrcaApp.kt:292-295).
- 3 → 4: T6/T7 await preload in the host splash (`ORCA_PRELOAD`) and pass its config and cache to OrcaApp's new
  input. The main session hand-checks C14.1/C14.2 after G4 with `ORCA_BOOT=config ORCA_APP_ID=static-flows`.
- 4 → 5: G5-G7 wait on decision 3 (planned for option A) and come last, so G1-G4 stand either way. T10/T11 ship
  the handlers with capabilities.json, Generated and the count tests (20 → 22) together; commit T10 before T11
  (CapabilitiesTest.kt:108 compares Swift's capabilities.json with Kotlin's).
- 5 → 6: T12's fixtures pass in Flutter only with T8; T13/T14 run them through T10/T11 and raise the action-fixture
  pins 24 → 27; commit T12 first in G6.
- 6 → 7: T15/T16 hand SavedState on the file store to each page model (restore before seed) and the router (app
  state at boot); their READMEs point to T9's demo. The main session hand-checks C14.6 after G7.

### Seams
none: no file is named by two tasks of one group. OrcaApp and OrcaRouter come back in G7 (T4/T5 then T15/T16), the
example READMEs in G4 then G7, one task per group. The capabilities generator writes both Generated files; each
follows its own capabilities.json, so T10 commits only the Swift file and T11 only the Kotlin one.

### Not planned
- Option B shrinks G5-G7 to one task: add both kinds to SKIP_ACTION_KINDS in schema/gen-sdk-capabilities.ts:58 and
  regenerate generated.dart; C14.6 becomes "not applicable".
- The design's follow-ups: the unversioned-flow quirk, a fallback to the saved config when /config fails, config
  edits outside flow versions. An engine-dart persistState builder (decision 3 names the TS builder only).

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift build --build-tests && swift test`
(and `xcodebuild test -scheme OrcaGateway-Package` on the iOS 18.5 simulator before the PR) · `cd sdk-kotlin &&
./gradlew build --console=plain`
lint: 0 Swift warnings; Kotlin explicitApi and warnings as errors (in the build) · typecheck: the builds
baseline: engine 751 pass · Flutter 349 · DevTools 17 · Swift core 376, SwiftUI 257, 0 warnings · Kotlin core 377,
sdk 374 (origin/main 6a7f0e0, 2026-11-16)

commits: per task (feat/native-parity-s14) · gate: per group (answered at gate 08, 2026-11-16) · G5-G7: wait for the user's decision 3
