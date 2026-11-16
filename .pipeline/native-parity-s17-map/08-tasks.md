# 08 · Tasks · native-parity-s17-map

## Front page

### In one breath
tasks: 15 in 4 groups · widest group: 5 · cases: 17 of 17 placed (C17.1, C17.5; template P1-P6)
Step 17, plugin 3 of 4: the map as its own Swift and Gradle packages, as the video's.
G1 the yaml schema and the package shells; G2 generated props and the /map demo page.
G3 the maps on both platforms and the release, mirror and CI rows; G4 both demo apps, the docs.
MapKit on iOS (no key); Maps Compose on Android, the plan's choice and the first outside library.

### New for you
nothing new

### Trade-offs
1 needs you (plan-approved): Android adds maps-compose (brings play-services-maps), the plan's pick

### Questions for you
1. Commands: as the video slice, the map packages in place of the video's. (default: as found)
2. Commits: one per task on feat/native-parity-s17-map, stacked on PR #49. (default: yes)
3. One gate per group. (default: yes)
4. needs: maps-compose in the map's own Gradle build, as plan step 17 names it. (default: add it)
5. After the merge, yours: mirror repo, key, secret; an Android Maps key for tiles. (default: ok)

## Appendix

### Where step 17 map comes from
Plan step 17 of /Users/amrebada/.claude/plans/native-parity/plan.md ("Map: MapKit on iOS, Maps Compose on Android"),
the user's packaging answer B (2026-11-16), and the design in the session scratchpad (s17/design-map.md: rows C17.1
and C17.5 checked against Flutter, the package template P1-P6 with the map's names, the map M1-M8). Stages 01-07 were
skipped as covered by the plan, that answer and the voice recorder's template (PR #47). Flutter is the reference:
plugins/orca_google_map/lib/src/google_map_plugin.dart (google_maps_flutter 2.17.0). The planner's plan below is
the video player's (PR #49), task for task, with the map's names and the map's differences.

### Groups
Paths are from the repo root unless they start with /Users/. `GM/` = plugins/orca_google_map/, `SW/` = GM/ios/Sources/OrcaGoogleMap/, `SWT/` = GM/ios/Tests/OrcaGoogleMapTests/, `KT/` = GM/android/google-map/src/main/kotlin/com/orcagateway/plugins/googlemap/, `KTT/` = the same path under src/test/.

| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Map schema block pinned to Flutter | GM/orca_plugin.yaml (its `schema:` block and a notes header only) · cli/test/google_map_schema_test.dart (new) | C17.5/yaml | S | — |
| 1 | T2 | Pub and git ignore native dirs | GM/.pubignore (new) · GM/.gitignore (new) | P-pub | S | — |
| 1 | T3 | Android Gradle package, needs: maps-compose | GM/android/settings.gradle.kts (new) · GM/android/gradle.properties (new) · GM/android/VERSION (new) · GM/android/gradlew (new, a symlink to ../../../sdk-kotlin/gradlew) · GM/android/google-map/build.gradle.kts (new) | P-pkg/K | M | — |
| 2 | T4 | SwiftPM package with generated props types | GM/ios/Package.swift (new) · GM/ios/VERSION (new) · SW/Generated/OrcaGoogleMapTypes.swift (new) · SWT/GoogleMapPropsTests.swift (new) · cli/test/google_map_swift_props_test.dart (new) | C17.5/S, P-pkg/S | M | T1 |
| 2 | T5 | Kotlin generated props, params, drift test | KT/OrcaGoogleMapTypes.kt (new) · KTT/GoogleMapPropsTest.kt (new) · cli/test/google_map_kotlin_props_test.dart (new) | C17.5/K | M | T1, T3 |
| 2 | T6 | Demo /map page for hand checks | examples/server/orca_google_map.ts (regenerated for T1's yaml, its imports kept on ../../engine/src/types) · examples/server/custom.ts (/map gains onMarkerTap's markerId and onLongPress's coordinate in page state, with Texts) · examples/server/README.md (its orca_google_map.ts row) · engine/test/map-demo.test.ts (new) | C17.1/page | M | T1 |
| 3 | T7 | Swift MapKit plugin, view, moveCamera | SW/GoogleMapPlugin.swift (new: the plugin, the node-id registry, moveCamera) · SW/MapSurface.swift (new: the protocol, mapType, markers, Google zoom to and from a MapKit span) · SW/MapKitView.swift (new: MKMapView in a UI/NSViewRepresentable, its delegate, registered on create, removed on leave) · SWT/GoogleMapPluginTests.swift (new, fakes) · SWT/MapKitViewTests.swift (new, the real view in a window) | C17.1/S | M | T4 |
| 3 | T8 | Kotlin Maps Compose plugin, location permissions | GM/android/google-map/src/main/AndroidManifest.xml (new, ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION) · KT/GoogleMapPlugin.kt (new) · KT/MapSurface.kt (new: the interface, the props mapping, the permission check) · KT/GoogleMapView.kt (new: GoogleMap, CameraPositionState, MapProperties, MapUiSettings, Marker) · KTT/GoogleMapPluginTest.kt (new, fakes, Robolectric @Config(sdk = [34])) | C17.1/K | M | T3, T5 |
| 3 | T9 | release.sh rows 15-16, scratch-repo test | scripts/release.sh · engine/test/launch-release.test.ts | P-release | S | T3, T4 |
| 3 | T10 | Mirror PACKAGES line, LICENSE, rehearsal | scripts/swift-mirror.sh · .github/workflows/sdk-swift-mirror.yml (only its header's list of mirrors and secrets) · GM/ios/LICENSE (new) | P-mirror | M | T4 |
| 3 | T11 | CI matrices gain the map | .github/workflows/native-plugins.yml | P-ci | S | T3, T4 |
| 4 | T12 | iOS demo links and registers map | examples/app-ios/OrcaCounter.xcodeproj/project.pbxproj · examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/Info.plist (NSLocationWhenInUseUsageDescription) · examples/app-ios/OrcaGoogleMap (new, a git symlink to ../../plugins/orca_google_map/ios) · examples/app-ios/README.md (the hand check) | C17.1/hand-S | M | T6, T7 |
| 4 | T13 | Android demo includes map, reads key | examples/app-android/settings.gradle.kts · examples/app-android/app/build.gradle.kts · examples/app-android/app/src/main/AndroidManifest.xml (the API key meta-data) · examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/README.md (the hand check) | P-key, C17.1/hand-K | M | T6, T8 |
| 4 | T14 | Native READMEs: install, register, location | GM/ios/README.md (new) · GM/android/README.md (new) · GM/README.md (a native apps section) | P-readme | M | T7, T8 |
| 4 | T15 | Outside repo: walkthroughs, release table | /Users/amrebada/workspace/orca-gateway/docs/User_Actions.md · /Users/amrebada/workspace/orca-gateway/CLAUDE.md (both outside the git repo, not in the PR) | P-docs | S | T9, T10 |
### Order, and why each boundary
- Kind: feature. This is the video player's plan, task for task (T1-T15), with the map's names. It has two lanes, Swift T4 → T7 → T12 and Kotlin T3 → T5 → T8 → T13. The /map page (T6) and the release work (T9-T11) run beside them. Nothing changes under schema/ and no generator changes: every type in the map yaml is one the generators already emit, and markers are read as raw JSON. There is one new library, on Android only: maps-compose, which brings play-services-maps. It is the first library outside the SDK's catalog, so T3 declares it in its own build and its title flags it. iOS uses MapKit: no dependency, no key.
- 1 → 2: T4 and T5 run the CLI's `--types-only` mode on T1's yaml. Package.swift goes with the types, because a SwiftPM target with no sources fails. T5 compiles inside T3's build. T6's TS is the CLI's output for T1's yaml. If T1 drops `required` where Flutter has a default (the widget's latitude and longitude, a marker's id), that output changes and T6 regenerates the file. No test diffs examples/server/orca_google_map.ts (checked).
- 2 → 3: T7 and T8 read props, params and trigger names through T4's and T5's types, and build inside those packages. T9's rows read T3's and T4's VERSION files. T10 splits T4's package, and a split with no LICENSE is refused. Its rehearsal stops where the video's did, at the split's own build (there is no orca-gateway-swift 0.1.0-alpha.2 yet); a stand-in run then goes to the end. T11 builds and tests T3's and T4's packages.
- 3 → 4: T12 and T13 import T7's and T8's plugins and open T6's /map page for the hand checks. T14 documents what T7 and T8 do and the gaps: on iOS, terrain draws .standard and zoomControlsEnabled has no effect. T15 writes down what T9 and T10 settle: rows 15-16, orca-gateway/orca-google-map-swift and ORCA_GOOGLE_MAP_SWIFT_DEPLOY_KEY, under release.sh's own words "the orca_google_map Swift mirror". It also adds the Android Maps API key walkthrough.
- Where the map differs from the video:
  - T1 stays S even though three CLI tests read this yaml. plugin_generate_test.dart builds its TS live. swift_generator_test.dart and kotlin_generator_test.dart diff the C16.6 stubs committed in sdk-swift/Tests/OrcaGatewayTests/Generated/ and sdk-kotlin/sdk/src/test/kotlin/orca/plugins/. Those two generators read only names, types and enums (not `required`, not the notes), and the yaml's names, types and enums already match Flutter's, so neither stub drifts. If one ever did, its stub would be T1's. T1 leaves the platform, env and preview blocks alone: they are Flutter's (M8). There is no map schema test yet, so T1 creates it.
  - T8: Robolectric cannot draw Google Maps, so T8's tests drive the MapSurface seam with fakes. The real GoogleMap composable is seen only at hand-K (M5). T7 also hosts its real MKMapView in a window (a 09 finding). T8's manifest merges the yaml's two location permissions. Neither plugin ever asks for them, as google_maps_flutter does not, and Android sets isMyLocationEnabled only while the app holds the permission.
  - T12 adds NSLocationWhenInUseUsageDescription, with the yaml's own text, to the demo's Info.plist. /map sets myLocationEnabled: true, and iOS gives an app location only when it has that key. The app still never asks: the hand check grants location with `xcrun simctl privacy booted grant location` and sets a simulated location. The yaml's Google key and GMSServices lines are Flutter's; MapKit needs neither.
  - T13 gives the app the meta-data com.google.android.geo.API_KEY through a manifest placeholder, read from `GOOGLE_MAPS_ANDROID_API_KEY` in local.properties. That is the yaml's env name, fixed here so T13 and T15 agree without a dependency between them. The P-key case: the app builds, and /map opens without a crash, with or without the key (the Maps SDK throws when the meta-data is missing). The hand check needs an emulator image with Google Play. Without a key it sees markers, taps and the camera Texts, but no tiles.
  - 09's findings carry over. Swift 6.2-only APIs go under `#if compiler(>=6.2)` for CI's Xcode 16.4. moveCamera resolves its targetId and numbers through the SDK's resolver, and a non-number fails the action. The map fills the box /map gives it (a Container 300 high), checked in sdk-swift's real Column.
  - T9 moves the voice test's list-end check from row 15 to row 17, as the video's T9 moved it from 13 to 15. That edits a baseline test, so record it as a decision.
- Stacked on PR #49: T6 and T9-T13 edit files that #49 adds or changes. If #49 changes in review or merges, rebase before the group that touches them.
### Seams
- GM/orca_plugin.yaml → T1: the Swift, Kotlin and TS generators (T4, T5, T6) and the C16.6 tests all read it.
- GM/.gitignore and GM/.pubignore → T2: they cover both lanes' build outputs, byte-identical to the video's. pub reads .pubignore instead of .gitignore, so .pubignore repeats those entries and leaves /ios/ and /android/ out; lib/, preview/, assets/ and the rest stay in the archive.
- GM/android/google-map/build.gradle.kts → T3: T5 and T8 compile in it. So T3 declares everything they need up front: the sdk as api, maps-compose, and from the SDK's catalog Compose plus the voice's test set (junit4, robolectric, compose ui-test, coroutines-test).
- GM/ios/Package.swift → T4: T7, T10, T11 and T12 build on it.
- examples/server/custom.ts → T6: both hand checks open its /map page.
- scripts/release.sh → T9: one owner for both platform rows.
### Not planned
none: all 17 cases are placed: the video's 16 with the map's names, plus P-key. These are the user's, not cases:
- After the merge: create the empty repo orca-gateway/orca-google-map-swift, its own deploy key and the secret ORCA_GOOGLE_MAP_SWIFT_DEPLOY_KEY.
- A Google Maps API key for Android tiles. T15 writes how; the hand check runs without one.
- Release sdk-swift 0.1.0-alpha.2 and sdk-kotlin before rows 15-16.
- The C17.1 and C17.5 rows at stage 10.
- Renaming the plugins' Swift and Gradle folders, which would replace the ./OrcaGoogleMap link and the named orca-google-map-android build, stays a follow-up of its own (P6).

### Three checks (main session)
- Every case in exactly one task: 17 cases (the video's 16 with the map's names, and P-key), 17 placements.
- No file in two tasks of one group: each group's Files cells are disjoint sets (group 3 has five tasks: it launches
  in two batches, T7-T10 then T11).
- No task over five files or beyond M (T7, T8, T12, T13 have five); Depends on names earlier groups only.

### Done when
test: `cd cli && dart test` · `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift build
--build-tests && swift test` · `cd sdk-kotlin && ./gradlew build --continue --console=plain` · the voice and video
packages (`swift test`, `./gradlew build`) · from G2: `cd plugins/orca_google_map/ios && swift build --build-tests &&
swift test` (and `xcodebuild test` on the iOS 18.5 simulator before the PR) · `cd plugins/orca_google_map/android &&
./gradlew build --continue --console=plain`
lint: `dart analyze` in cli/ · `flutter analyze` in sdk/ · 0 Swift warnings · Kotlin explicitApi and warnings as
errors (in the build) · typecheck: the builds
baseline: cli 45 · engine 822 pass · Flutter 543, analyze clean · Swift core 604, SwiftUI 494, 0 warnings · Kotlin
BUILD SUCCESSFUL · voice Swift 24, voice Gradle green · video Swift 26 (27 on the iOS 18.5 simulator), video Gradle
26 · both demo apps build · generators: no drift (feat/native-parity-s17-video 8eb855c4 on main d82ed11, 2026-11-16)

commits: per task (feat/native-parity-s17-map, stacked on PR #49) · gate: per group (answered at gate 08, 2026-11-16, standing rule) · needs: maps-compose added (plan step 17)
