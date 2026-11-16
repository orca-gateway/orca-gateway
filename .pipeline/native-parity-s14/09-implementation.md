# 09 · Implementation · native-parity-s14

## Front page

### In one breath
group 4 of 7 · tasks: 2 green, 0 blocked · cases: C14.1-C14.5 green, by hand too · all green
T6/T7 demos: ORCA_PRELOAD runs the host's preload; the READMEs say what offline does.
Hand check, both devices: offline boot, unvisited static pages open, dynamic fail, 4->5 refetch.

### New for you
nothing new

### Trade-offs
2 auto-decided: a host preload error is a plain line; a deep link in its splash is not held

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: groups 5-7 need decision 3: persistState/clearState in all 3 SDKs, or drop. (default: wait)

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

### Test run
Group 1 (..6835ab0): sdk `flutter test` 364, `flutter analyze` clean · engine `bun test` 751 · Swift and Kotlin
unchanged (no file of theirs touched). Files changed: the task's only.
Group 2 (..576584c): `swift build --build-tests && swift test`: core 400, SwiftUI 257, 0 failures, 0 warnings ·
`./gradlew build`: core 399, sdk 374, 0 failures, 0 skipped · Flutter and engine untouched · no stray file.
Group 3 (..6be2e62): `swift test`: SwiftUI 275, core 400, 0 failures, 0 warnings · `xcodebuild test` on the
iOS 18.5 simulator: TEST SUCCEEDED · `./gradlew build`: core 399, sdk 388, 0 failures · no stray file.
Group 4 (..7bf081b): iOS demo xcodebuild BUILD SUCCEEDED, 0 Swift warnings · Android demo assembleDebug BUILD
SUCCESSFUL (warnings as errors) · `swift test` core 400 · `./gradlew build` core 399, sdk 388 · no stray file.

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
- G5-G7 wait on the user's decision 3 (persistState/clearState).
- New public API: Swift OrcaApp(preloadedConfig:staticFlowManager:), FileKeyValueStore.applicationSupport(), core
  preload/PreloadResult/OfflineBootError/StaticFlowManager/FileKeyValueStore; Kotlin the same, offlineStore(context).
- Rows C14.1-C14.5 tick with this branch; C14.6 waits on decision 3 (G5-G7), so the step's PR waits too.
