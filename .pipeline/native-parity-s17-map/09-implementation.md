# 09 · Implementation · native-parity-s17-map

## Front page

### In one breath
group 1 of 4 · tasks: 3 green, 0 blocked · cases: 3 of 17 green · engine bun test: 822 pass
T1 Map schema: the yaml gains Flutter's defaults, trigger payloads and moveCamera; a test pins it.
T2 Ignore files: the native folders stay out of pub.dev and their build output out of git.
T3 Android package: a Gradle build on the SDK's toolchain with Maps Compose 8.3.0, green empty.

### New for you
nothing new

### Trade-offs
5 auto-decided (minor, your standing rule): the appendix's decisions under each digest.

### Questions for you
1. Next: group 2 of 4, the Swift package, the Kotlin props and the /map demo page? (default: go)

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

(GM/ = plugins/orca_google_map/)

### Test run
The full run on T1-T3 (before T1's two reworks), every Done-when command that applies so far:
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

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- Maps Compose 8.3.0 is the first library outside the SDK's catalog; it pulls play-services-maps 20.0.0 from
  google(). 8.3.1 and later need compileSdk 37: raise it when the SDK moves to 37.
- examples/server/orca_google_map.ts already differs from the generator's output (its imports and
  `targetId: Value | string`); T6 regenerates it with the new schema.
