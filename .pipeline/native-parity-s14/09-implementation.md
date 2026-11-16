# 09 · Implementation · native-parity-s14

## Front page

### In one breath
group 3 of 7 · tasks: 2 green, 0 blocked · cases: C14.1, C14.2, C14.5 green in both · all green
T4 SwiftUI: OrcaApp boots offline via preload, takes a preloaded config, loads pages cache-first.
T5 Compose: the same; OrcaAppBoot keeps its public surface, the new inputs stay internal.
Both: a public helper hands the host OrcaApp's own store, so preload and OrcaApp share one cache.

### New for you
nothing new

### Trade-offs
4 auto-decided: Phase unchanged; a public store helper; Swift cache under the bundle id; IO thread

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 4 (demo apps gain ORCA_PRELOAD; READMEs say what offline does). (default: go)
3. needs: decision 3 for G5-G7: persistState/clearState in all three SDKs, or drop. (default: wait)

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

### Test run
Group 1 (..6835ab0): sdk `flutter test` 364, `flutter analyze` clean · engine `bun test` 751 · Swift and Kotlin
unchanged (no file of theirs touched). Files changed: the task's only.
Group 2 (..576584c): `swift build --build-tests && swift test`: core 400, SwiftUI 257, 0 failures, 0 warnings ·
`./gradlew build`: core 399, sdk 374, 0 failures, 0 skipped · Flutter and engine untouched · no stray file.
Group 3 (..6be2e62): `swift test`: SwiftUI 275, core 400, 0 failures, 0 warnings · `xcodebuild test` on the
iOS 18.5 simulator: TEST SUCCEEDED · `./gradlew build`: core 399, sdk 388, 0 failures · no stray file.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- G5-G7 wait on the user's decision 3 (persistState/clearState).
- New public API: Swift OrcaApp(preloadedConfig:staticFlowManager:), FileKeyValueStore.applicationSupport(), core
  preload/PreloadResult/OfflineBootError/StaticFlowManager/FileKeyValueStore; Kotlin the same, offlineStore(context).
- The core's Swift FileKeyValueStore doc comment still names the old folder: T6 fixes it (a doc line only).
