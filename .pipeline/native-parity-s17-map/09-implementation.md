# 09 · Implementation · native-parity-s17-map

## Front page

### In one breath
group 2 of 4 · tasks: 6 green, 0 blocked · cases: 7 of 17 green · engine bun test: 827 pass
T4 Swift package: OrcaGoogleMap builds the CLI's generated types, pinned to Flutter.
T5 Kotlin types: the generated props and params compile under explicitApi, pinned to Flutter.
T6 /map page: it keeps a tapped marker's id and a long press's spot, each shown in a Text.

### New for you
nothing new

### Trade-offs
3 auto-decided (minor, your standing rule): the appendix's decisions under each digest.

### Questions for you
1. Next: group 3 of 4, the MapKit and Maps Compose plugins, release and CI? (default: go)

## Appendix

### Group 1
#### T1 · Map schema block pinned to Flutter (93a17543, reworks 865dbbe2, 635eb3b6)
Files: plugins/orca_google_map/orca_plugin.yaml (its `schema:` block and a notes header) · cli/test/google_map_schema_test.dart (new)
Cases: C17.5/yaml → green (cli 49 = 45 + 4, analyze clean; red first on the old block: "latitude required", "MapMarker.id
required", no `event_data`, an empty targetId note; 20 hand mutations each caught, yaml restored; C16.6 stub diffs green)
Changed: GoogleMap gains Flutter's defaults (latitude, longitude 0, zoom 14, mapType normal, myLocationEnabled false,
zoomControlsEnabled true); the camera props noted as the initial camera only (later, only moveCamera moves it); MapMarker
id "", latitude and longitude required (a marker without both is skipped), title "", snippet; the four triggers' payloads
in `event_data:`; moveCamera targetId (the node's id), latitude and longitude required, zoom 14
Decisions: `required` dropped where Flutter defaults · each note says what Flutter does with a wrong type (`as T?` throws
in the build) · the SDK's reads pinned by signature and key expression, never word for word (all minor, auto-decided)
Review fit: a non-number marker latitude was said to be skipped; Flutter throws; notes fixed (865dbbe2), fixed · Review
quality: resolveString's body was pinned word for word; now sliced as prop's, checked for `?.toString()` (635eb3b6), fixed

#### T2 · Pub and git ignore native dirs (e5f517a)
Files: plugins/orca_google_map/.pubignore (new) · plugins/orca_google_map/.gitignore (new)
Cases: P-pub → green (red first: dummies under ios/ and android/ in the `flutter pub publish --dry-run` archive, none
of .build/, .swiftpm/, Package.resolved, .gradle/, .kotlin/, local.properties ignored; green: ios/ and android/ out of
the archive, all six ignored, build/ by the root .gitignore, Package.swift, settings.gradle.kts and lib/ not ignored;
the dry run from "Publishing" on as before: 1 warning (no CHANGELOG 0.2.1 entry), 1 hint, exit 65 both times)
Changed: .pubignore leaves /ios/ and /android/ out and repeats .gitignore's entries; .gitignore ignores the six build
outputs; both byte-identical to the video player's (cmp); the map had neither file before
Decisions: the video's files exactly · the dummies deleted by exact path, the empty folders by rmdir (both minor)
Review fit: pass · Review quality: pass

#### T3 · Android Gradle package, needs: maps-compose (d1f3f399)
Files: GM/android/{settings.gradle.kts, gradle.properties, VERSION, gradlew (a symlink to ../../../sdk-kotlin/gradlew),
google-map/build.gradle.kts} (all new)
Cases: P-pkg/K → green (`./gradlew build --continue` BUILD SUCCESSFUL on the empty module; red first: "does not contain a
Gradle build"; explicitApi, -Werror and lint NewApi probes each failed the build; a probe using OrcaPlugin, GoogleMap,
Marker, MapProperties, createComposeRule, runTest and Robolectric built and passed, then deleted; the staged POM is
com.orcagateway:orca-google-map:0.1.0-alpha.1 on com.orcagateway:sdk and maps-compose 8.3.0; video and voice green)
Changed: the video's build with the map's names (orca-google-map-android, :orca-google-map, google-map,
com.orcagateway.plugins.googlemap); the sdk as api, maps-compose, Compose ui/foundation/material3, the video's test set
Decisions: maps-compose 8.3.0, the newest whose AAR needs compileSdk 36 (8.3.1-9.0.1 need 37), Apache 2.0, bringing
play-services-maps 20.0.0 from google() · maps-compose lifts coroutines 1.9.0 → 1.10.2 in this build only (both minor, auto-decided)
Review fit: pass · Review quality: pass

(GM/ = plugins/orca_google_map/, KT/ and KTT/ = the map's Kotlin main and test package folders)

### Group 2
#### T4 · SwiftPM package with generated props types (18309ee9)
Files: GM/ios/{Package.swift, VERSION, Sources/OrcaGoogleMap/Generated/OrcaGoogleMapTypes.swift, Tests/OrcaGoogleMapTests/
GoogleMapPropsTests.swift} (all new) · cli/test/google_map_swift_props_test.dart (new)
Cases: P-pkg/S, C17.5/S → green (swift test 5, 0 warnings from a clean build; xcodebuild build and test on the iOS 18.5
simulator, 4 there: the manifest test is macOS only; cli 51 with T5's; red first: "No types at …", no Package.swift)
Changed: the video's manifest with the map's names (tools 5.9, iOS 16 / macOS 13, OrcaGoogleMap; the SDK by path in the
monorepo, else orca-gateway-swift from 0.1.0-alpha.2, from `Context.packageDirectory`); VERSION 0.1.0-alpha.1; the types
are the CLI's output, unedited, `markers` a raw `JSONValue?`; the test pins the seven props (a marker's fields by key,
whole numbers as Double, Values resolved inside markers), absent props nil, Flutter's four triggers in order,
moveCamera's four params, both manifest branches (the URL as a whole JSON string); the drift test as the video's
Decisions: a Value-object param reads nil, left in the raw action for T7 · the video's macOS-only manifest test (minor)
Review fit: pass · Review quality: pass

#### T5 · Kotlin generated props, params, drift test (f47854c6)
Files: KT/OrcaGoogleMapTypes.kt (new) · KTT/GoogleMapPropsTest.kt (new) · cli/test/google_map_kotlin_props_test.dart (new)
Cases: C17.5/K → green (the map's Gradle build, GoogleMapPropsTest 7/7, lint ran, explicitApi and -Werror; the drift
test 1/1; cli 51 with T4's; sdk-kotlin green; red first: "Unresolved reference 'GoogleMapProps'", "No types at …")
Changed: the types file is the CLI's --types-only output, unedited, and compiles as generated (no generator fix); it
types `markers` as `JsonValue?` (the raw array). The test pins the seven props Flutter reads (whole numbers read as
Double), a marker's id, latitude, longitude, title and snippet read by key through JsonValue, absent or null props
read null, Flutter's four triggers in order, moveCamera's targetId (string) and latitude, longitude, zoom (numbers),
and that a Value-object param reads null, left in the raw action for T8 to resolve as Flutter does
Decisions: the video's T5 shape (plain JUnit, Java reflection, raw "custom:<name>" actions) · the Value-param pin the
video's Kotlin test lacks, matching the Swift side (both minor, auto-decided)
Review fit: pass · Review quality: pass

#### T6 · Demo /map page for hand checks (bfd80acf)
Files: examples/server/{orca_google_map.ts, custom.ts, README.md} · engine/test/map-demo.test.ts (new)
Cases: C17.1/page → green (engine 827 = 822 + 5; red first in 3 of 5: page state, the four triggers, the Texts; the
other 2 pin what /map already had; examples/server tsc 36 errors before and after, the same kinds, none new)
Changed: orca_google_map.ts is the CLI's TS for T1's yaml (latitude, longitude and a marker's id optional, targetId
`Value | string`), its imports on ../../engine/src/types, its header says so and how to regenerate; /map's onLongPress
sets latLongPress and lngLongPress, onMarkerTap sets markerTapId (`V.event`), shown in three new Texts; the test pins
the state, the node "main-map" with its props and markers, the four triggers' keys and fields, moveCamera's targetId
equal to the node's id, the Texts' watches; the README row says what /map shows; no new home button
Decisions: the page does not scroll (about 540 of 720+ high; a scroll view would take the map's drags in Flutter) · the
page's own naming for the new keys (both minor, auto-decided)
Review fit: pass · Review quality: pass


### Test run
Group 1: the full run on T1-T3 (before T1's two reworks), every Done-when command that applies so far:
- cli `dart test` 49 pass (45 + 4), `dart analyze` no issues · engine `bun test` 822 pass, 0 fail
- Flutter `flutter test` 543 pass, `flutter analyze` no issues
- sdk-swift `swift test` 604 pass (its six `warning:` lines are SwiftUI runtime notices from step 18's tests,
  not compiler warnings) · sdk-kotlin `./gradlew build` BUILD SUCCESSFUL
- voice recorder: ios 24 pass, android BUILD SUCCESSFUL · video player: ios 26 pass, android BUILD SUCCESSFUL
- map android `./gradlew build --continue` BUILD SUCCESSFUL
- the generators (widget registry, native capabilities) leave no diff · release.sh and swift-mirror.sh parse,
  shellcheck clean · every workflow yml parses
- map `flutter pub publish --dry-run`: exit 65 with 1 warning (no CHANGELOG entry for 0.2.1) and 1 hint, as
  at baseline
After the reworks (865dbbe2, 635eb3b6: only the yaml's notes and the cli test): cli 49 pass, analyze clean.
Failures: none.

Group 2, after T4-T6 (SC/s17m/g2run), on the branch head: cli `dart test` 51 pass (49 + T4's and T5's drift tests),
`dart analyze` no issues · engine `bun test` 827 pass, 0 fail (822 + T6's 5) · Flutter 543 pass, analyze clean ·
sdk-swift `swift test` 604 pass · sdk-kotlin BUILD SUCCESSFUL · voice: ios 24, android green · video: ios 26, android
green · map ios `swift test` 5 pass, 0 warnings, `xcodebuild test` on the iOS 18.5 simulator 4 pass (TEST SUCCEEDED) ·
map android BUILD SUCCESSFUL (up to date: T5's run had built it and passed GoogleMapPropsTest 7/7) · the generators
leave no diff · scripts and workflows parse · pub dry run as at baseline (1 warning, 1 hint) · examples/server tsc 36
errors before and after T6, the same kinds. Failures: none.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- Maps Compose 8.3.0 is the first library outside the SDK's catalog; it pulls play-services-maps 20.0.0 from
  google(). 8.3.1 and later need compileSdk 37: raise it when the SDK moves to 37.
- examples/server/orca_google_map.ts is now the generator's output for the new schema (T6): the widget's latitude
  and longitude and a marker's id are optional in TypeScript, as Flutter defaults them.
