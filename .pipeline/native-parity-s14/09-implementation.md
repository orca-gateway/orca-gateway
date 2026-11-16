# 09 · Implementation · native-parity-s14

## Front page

### In one breath
group 5 of 7 · tasks: 6 green, 0 blocked · cases: C14.1-C14.5 green, C14.6's parts in
T8-T11: persistState/clearState in Flutter, the engine, Swift and Kotlin, alike (decision 3 A).
Rebased on main with #38: one boot screen over preload; T17/T18 moved 7 tests, no bug.
Row C14.2 fixed to Flutter: nothing saved shows "Something Went Wrong"; redo by hand later.
Planned red until group 6: "every advertised kind has a fixture" in Swift and Kotlin.

### New for you
nothing new

### Trade-offs
4 auto-decided: clear nulls the key · public session hooks · push home · tests cache in memory

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 6, fixtures 48-50 on all three SDKs (they end the planned red). (default: go)

## Appendix

### Group 1
#### T1 · Offline fixtures, Flutter as oracle (6835ab0)
Files: schema/offline-fixture.schema.json (new) · schema/fixtures/offline/01_static_flow_boot.json (new) ·
schema/fixtures/offline/README.md (new) · sdk/test/conformance/offline_fixtures_test.dart (new) ·
schema/navigation-config.schema.json
Cases: C14.1/F-C14.5/F → green (flutter test 364 = 349 + 15; analyze clean; red first; 7 deliberate breaks caught)
Changed: a draft-07 format; 14 cases (first boot, fresh, fresh with no saved config, stale, offline with a saved
config, a /version 500 is offline, offline with nothing saved, forceUpdate, cleanup, an unversioned removed flow keeps
its pages, a dynamic route never served, the cache never reads the config's pages, the unversioned-flow quirk, a stale
/config failure with no fallback); the runner drives Flutter's real OrcaApp.preload + StaticFlowManager over MockClient
and an in-memory SharedPreferencesAsync; forceUpdate's schema description now says it blocks with its screen.
Decisions: the store fake implements SharedPreferencesAsync (no new dependency) · a /config failure as {status} ·
the store after checked by key set, exact versions, pages by path set
Review fit: pass · Review quality: pass

### Group 2
#### T2 · Swift core store, flow cache, preload (57a8fab)
Files: sdk-swift/Sources/OrcaGatewayCore/Client/FileKeyValueStore.swift (new) · Client/StaticFlowManager.swift (new) ·
Client/Preload.swift (new) · Tests/OrcaGatewayCoreTests/StaticFlowManagerTests.swift (new) · OfflineFixtureTests.swift (new)
Cases: C14.3/S, C14.4/S + all 14 offline fixture cases → green (core 400 = 376 + 24, SwiftUI 257, 0 warnings; red
first; 3 deliberate breaks caught: fresh refetching, the dynamic set ignored, no cleanup)
Changed: the file store (one file per key, atomic, nil removes, locked); Flutter's StaticFlowManager over any
KeyValueStore (three keys, memory copies, saves finish before return); preload(client:cache:), PreloadResult,
OfflineBootError (Flutter's text); the runner runs every case of every file in schema/fixtures/offline.
Decisions: clearAll clears the flows it knows (auto-decided, minor) · file names keep [a-z0-9_-], the rest %XX
(case-insensitive disks) · getCachedPage(_:flows:) keeps Flutter's flows argument
Review fit: pass · Review quality: pass

#### T3 · Kotlin core store, flow cache, preload (b7ff80b, 41b3378, 576584c)
Files: sdk-kotlin/core/.../client/FileKeyValueStore.kt (new) · StaticFlowManager.kt (new) · Preload.kt (new) ·
core/src/test/.../client/StaticFlowManagerTest.kt (new) · OfflineFixtureTest.kt (new)
Cases: C14.3/K, C14.4/K + all 14 offline fixture cases → green (core 399 = 377 + 22, sdk 374; red first; a
deliberate break of fresh caught by 3 fixture tests)
Changed: the same three parts as Swift, one to one with Flutter; suspend preload(client, cache), PreloadResult,
OfflineBootException (Flutter's text); the file store on java.io (minSdk 24), never throws.
Decisions: clearAll as Swift (auto-decided, minor) · a failed write keeps the old value, a failed read is null ·
getCachedPage(path, flows) as Flutter
Review fit: the store used java.nio.file, absent below Android API 26 (minSdk 24), fixed · Review quality: the runner listed and parsed its own files instead of Fixtures.files, fixed

### Group 3
#### T4 · SwiftUI offline boot, cache-first pages (3ced587, dff590e)
Files: sdk-swift/Sources/OrcaGateway/OrcaApp.swift · OrcaBoot.swift · Navigation/OrcaRouter.swift ·
Tests/OrcaGatewayTests/OfflineBootTests.swift (new) · OrcaBootTests.swift
Cases: C14.1/S, C14.2/S, C14.5/S → green (SwiftUI 275 = 257 + 18, core 400, 0 warnings; iOS 18.5 simulator: TEST
SUCCEEDED; red first: the new inputs did not exist)
Changed: OrcaApp takes preloadedConfig and staticFlowManager (Flutter's names); a preloaded config is the router at
once, no request; enableOffline runs preload (forceUpdate → the force-update view, the no-network text → the error
view with retry); pages ask the cache first (no request, no timing on a hit); public
FileKeyValueStore.applicationSupport() (Application Support/<bundle id>/OrcaGateway) shared with a host's preload.
Decisions: the public Phase unchanged, force-update via an internal flag · the gate's version check stays for path
mode and init(router:) only · the cache folder under the bundle id (auto-decided, minor)
Review fit: pass · Review quality: pass

#### T5 · Compose offline boot, cache-first pages (4f191e8, d82c458, 6be2e62)
Files: sdk-kotlin/sdk/.../OrcaApp.kt · OrcaBoot.kt · navigation/OrcaRouter.kt · sdk/src/test/.../OfflineBootTest.kt
(new) · OrcaBootTest.kt
Cases: C14.1/K, C14.2/K, C14.5/K → green (sdk 388 = 374 + 14, core 399; red first: did not compile; a mutant
building the preloaded router in an effect fails the first-frame test)
Changed: the same as Swift: preloadedConfig and staticFlowManager on OrcaApp, preload under enableOffline, pages
cache-first; public offlineStore(context) (filesDir/orca_gateway) shared with a host's preload; the router keeps its
first route event until shown, so a preloaded boot reports /home as the online boot does.
Decisions: Phase unchanged, force-update via an internal flag (auto-decided, minor) · preload and cache reads under
Dispatchers.IO
Review fit: pass · Review quality: the public OrcaAppBoot constructor gained inputs a host could not use, fixed (internal)

### Group 4
#### T6 · iOS demo ORCA_PRELOAD, offline docs (82f3387)
Files: examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md · sdk-swift/README.md ·
sdk-swift/Sources/OrcaGatewayCore/Client/FileKeyValueStore.swift (doc comment only, a group 3 leftover)
Cases: C14.1/hand-S, C14.2/hand-S → the demo builds (BUILD SUCCEEDED, 0 Swift warnings); SDK suite unchanged
(core 400, SwiftUI 275); the hand check below
Changed: ORCA_PRELOAD (config mode only): the host's splash awaits preload over FileKeyValueStore.applicationSupport(),
then OrcaApp(preloadedConfig:staticFlowManager:); forceUpdate → "Update required"; an error → its text. Both
READMEs gain an "Offline" section (Flutter's rules, the quirk, a sample, a hand check); the gap notes are gone.
Decisions: a preload error is a plain line, a relaunch retries · a link during the host splash is not held
Review fit: pass · Review quality: pass

#### T7 · Android demo ORCA_PRELOAD, offline docs (ace2eec, 3ab5b2c, 89a7bcb, 7bf081b)
Files: examples/app-android/.../MainActivity.kt · examples/app-android/README.md · sdk-kotlin/README.md ·
sdk-kotlin/sdk/.../OrcaBoot.kt (KDoc only, a group 3 leftover)
Cases: C14.1/hand-K, C14.2/hand-K → the demo builds (assembleDebug, warnings as errors); SDK suite unchanged
(core 399, sdk 388); the hand check below
Changed: the extra ORCA_PRELOAD (config mode only): PreloadedApp's splash awaits preload over offlineStore(context)
on Dispatchers.IO, then OrcaApp with preloadedConfig and the same manager; forceUpdate → "Update required"; an
error → its message. The READMEs' offline sections boot from the config; the gap notes are gone.
Decisions: preload from composition (produceState) · the host catches any Exception, rethrows cancellation
Review fit: the README told hosts to catch only the offline error; a failed /config throws too, fixed ·
Review quality: the READMEs said saved versions are sent to /version (they are compared on the device), fixed

### Group 5
Decision 3 answered A by you (relayed by the parent session, 2026-11-16): persistState and clearState are defined and
implemented in Flutter, Swift and Kotlin. The saved-state contract S1-S8 (scratchpad s14/g5-common.md) holds for all
three: entries `orca_saved_app` / `orca_saved_page_<pageId>` as JSON objects; local survives a restart, session lives
in a process-wide map; persist is a snapshot and keeps one saved copy per key; clear nulls the live key and every
saved copy; a scope's set-up restores its entry; no effect is emitted.

#### T9 · Engine PersistState builder, saved-state demo (c61cb78)
Files: engine/src/types/action.ts · engine/src/types/index.ts · engine/test/types.test.ts ·
examples/server/saved-state.ts (new) · examples/server/index.ts
Cases: C14.6/hand enabled → `bun test` 775 (773 + 2 red first); the demo app compiles and serves /config and its pages
Changed: `PersistState(key, scope = "page", storage = "local")` beside ClearState, both documented (S3, S4) and
exported · app `saved-state`: Count +1 / Save on device / Save for this session / Forget, Visits "+1 and save", a note
under each button, an `other` page and back
Decisions: visits is an app-scoped definition on home, so it works with or without a config · `initialRoute: /home`
for ORCA_BOOT=config · leaving and coming back pushes a fresh home, whose set-up runs the restore (main session's call)
Review fit: pass · Review quality: pass

#### T8 · Flutter persist/clear handlers, restore (fcdd8e2)
Files: sdk/lib/src/state/action_executor.dart · sdk/lib/src/state/state_manager.dart · sdk/lib/src/widgets/orca_app.dart ·
sdk/test/saved_state_test.dart (new)
Cases: C14.6/F enabled → `flutter test` 385 (12 new, red first), `flutter analyze` clean; dropping the boot's
`loadSaved` turns the OrcaApp test red
Changed: `SavedState` in state_manager.dart (static session map, lazy SharedPreferencesAsync, local mirror, error-
swallowing write-through) · `StateManager({saved})`: loadSaved, restoreApp, persistState, clearState; initPage restores
· the two handlers (defaults page / local) · OrcaApp awaits loadSaved before every boot branch, restores app state
after `initialAppState`
Decisions: the test injects an in-memory SharedPreferencesAsync, as the offline runner does · clearState nulls the live
key even when never held · the handlers await the local write
Review fit: pass · Review quality: pass

#### T10 · Swift core saved state, advertise both (7e2aa06)
Files: State/SavedState.swift (new) · State/ActionExecutor.swift · capabilities.json · Capabilities/Generated.swift ·
Tests: SavedStateTests.swift (new), CapabilitiesTests.swift, ActionHandlerTests.swift (one pin, accepted at this gate)
Cases: C14.6/S enabled → SavedStateTests 10 (red first); core green but for the planned
ModelRoundTripTests "every advertised kind has a fixture" red until group 6; 0 warnings
Changed: `public final class SavedState` (NSLock): persist / clear / restore(into:) / restorePage(into:pageId:), local
mirror and write-through, public sessionEntries / resetSession (documented: sign-out, tests) · executor
`savedState`, both kinds handled and advertised (22 actions)
Decisions: clearState keeps the key as null (same as Flutter and Kotlin) · page scope without a pageId does nothing
Review fit: pass · Review quality: pass

#### T11 · Kotlin core saved state, advertise both (09ccb55)
Files: core/state/SavedState.kt (new) · core/state/ActionExecutor.kt · capabilities.json · capabilities/Generated.kt ·
tests: SavedStateTest.kt (new), CapabilitiesTest.kt, ActionHandlerTest.kt (one pin, accepted at this gate)
Cases: C14.6/K enabled → SavedStateTest 12 (red first); core green but for the planned ModelRoundTripTest red
until group 6; sdk green; explicitApi, warnings as errors clean
Changed: SavedState as Swift's in Kotlin terms (lock, mirror, write-through, java.io only), public sessionEntries /
resetSession documented · executor `savedState`, both kinds handled and advertised (22)
Decisions: as T10 · T10 committed before T11 (the cross-SDK capabilities check), reordered by the main session
Review fit: pass · Review quality: pass

Then the branch was rebased onto main 3518792 (your merge of #38, step 18): the T4 and T5 rework commits were folded
into one commit per task, the boots merged by the main session (step 18's host views and OrcaErrorView over step 14's
preload; one boot screen over /version and /config, as Flutter), the capability vectors regenerated (56 widgets,
22 actions, one hash). Three Swift and four Kotlin tests of steps 14 and 18 then failed: T17 and T18 below.

#### T17 · Swift: step 18's AppShellTests after the merge (d493a95)
Files: sdk-swift/Tests/OrcaGatewayTests/AppShellTests.swift (no product change: no merge bug)
Cases: C18.1, C18.3, C14.2 → `swift test` SwiftUI 347, `xcodebuild test` on the iOS 18.5 simulator 409, 0 failures;
core 483 with the planned red; 0 warnings
Changed: one splash over the preload (version, config, page in that order, the splash alone on screen as both go out);
two new C14.2 tests: preload's forceUpdate through the host's view, and nothing saved drawing Flutter's "Something
Went Wrong" with Try again re-running preload; test boots with enableOffline get an in-memory cache
Decisions: the real Application Support cache leaked a saved config between test runs, so the tests no longer use it
Review fit: pass · Review quality: pass

#### T18 · Kotlin: AppShellTest and OfflineBootTest after the merge (660825d)
Files: sdk-kotlin/sdk/src/test/.../AppShellTest.kt · OfflineBootTest.kt (no product change: no merge bug)
Cases: C18.1, C14.1, C14.2 → `./gradlew build --continue`: sdk 489, 0 failures (3 forced reruns stable); core 477 with
the planned red
Changed: the C18.1 tests wait for the preload's /version (sent off the main thread) with the splash still up; the
offline tests read Flutter's texts ("Connection Failed", "Something Went Wrong"), keep the order and the retry
Decisions: one test renamed, its name no longer true
Review fit: pass · Review quality: pass

### Test run
Group 1 (..6835ab0): sdk `flutter test` 364, `flutter analyze` clean · engine `bun test` 751 · Swift and Kotlin
unchanged (no file of theirs touched). Files changed: the task's only.
Group 2 (..576584c): `swift build --build-tests && swift test`: core 400, SwiftUI 257, 0 failures, 0 warnings ·
`./gradlew build`: core 399, sdk 374, 0 failures, 0 skipped · Flutter and engine untouched · no stray file.
Group 3 (..6be2e62): `swift test`: SwiftUI 275, core 400, 0 failures, 0 warnings · `xcodebuild test` on the
iOS 18.5 simulator: TEST SUCCEEDED · `./gradlew build`: core 399, sdk 388, 0 failures · no stray file.
Group 4 (..7bf081b): iOS demo xcodebuild BUILD SUCCEEDED, 0 Swift warnings · Android demo assembleDebug BUILD
SUCCESSFUL (warnings as errors) · `swift test` core 400 · `./gradlew build` core 399, sdk 388 · no stray file.
Group 5 Before the rebase (..09ccb55): engine 775 · Flutter 385, analyze clean · Swift core 452, SwiftUI 316, 0 warnings ·
Kotlin core 453, sdk 461 · red only the planned "every advertised kind has an action fixture" test in Swift and Kotlin.
After the rebase and T17/T18 (..d493a95): engine 775 · Flutter 385 · Swift core 483, SwiftUI 347 (409 on the iOS 18.5
simulator), 0 warnings · Kotlin core 477, sdk 489 · the same planned red, which group 6's fixtures 48-50 turn green ·
generators: no drift · no stray file.

### Hand check (both devices, 2026-11-16; server :8094, static-flows at version 4)
1 nothing saved, server down: the boot error with "No network and no cached config available" (iOS "Could not
start the app", Android "Could not load this app") · 2 first online boot: Home; /version + /config, no page
request · 3 relaunch: /version only · 4 server down: Home from the saved config, About (never shown) opens, Profile
(dynamic) "Could not load this page" · 5 ORCA_PRELOAD offline: Home · 6 ORCA_PRELOAD nothing saved: the host's
plain line · 7 version 4 → 5: /version + /config, then /version only. Screenshots: scratchpad s14/hand/.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- Decision 3 = A (2026-11-16): persistState/clearState in all three SDKs; the saved-state contract S1-S8 is pinned by
  action fixtures 48-50 in group 6. New public API: Swift and Kotlin core `SavedState` (persist, clear, restore,
  restorePage, sessionEntries, resetSession) and `ActionExecutor.savedState`; engine `PersistState`; Flutter
  `SavedState`, `StateManager({saved})`, loadSaved, restoreApp.
- Row C14.2 corrected again against Flutter after step 18 (Flutter's "Something Went Wrong" screen for the offline boot
  with nothing saved); its hand-check step is redone with C14.6.
- Follow-up seen, not this step's: step 18's testC18_3_UnderALightSchemeAScaffoldPageLooksAsUnderADarkOne is flaky on
  macOS (fails about 1 run in 4, also on the unchanged baseline), green on the simulator.
- New public API: Swift OrcaApp(preloadedConfig:staticFlowManager:), FileKeyValueStore.applicationSupport(), core
  preload/PreloadResult/OfflineBootError/StaticFlowManager/FileKeyValueStore; Kotlin the same, offlineStore(context).
- Rows C14.1-C14.5 tick with this branch; C14.6 waits on decision 3 (G5-G7), so the step's PR waits too.
