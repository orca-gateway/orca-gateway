# 09 · Implementation · native-parity-s17-video

## Front page

### In one breath
group 2 of 4 · tasks: 3 green, 0 blocked · cases: 7 of 16 green · engine bun test: 812 pass
T4 Swift package: plugins/orca_video_player/ios builds the CLI's generated types, pinned to Flutter.
T5 Kotlin types: the Gradle package compiles the generated types, pinned to Flutter.
T6 demo: the /video page plays an MP4 with five buttons and keeps the position in page state.
Rebased onto main 677d114 (your merge of PR #47); every suite green; no generator drift.

### New for you
nothing new

### Trade-offs
1 auto-decided: a voice demo test already in main now lists /home's new /video button (still exact)

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 3, the players on both platforms and the release, mirror and CI rows. (default: go)

## Appendix

### Group 1
#### T1 · Video schema block pinned to Flutter (3803525)
Files: plugins/orca_video_player/orca_plugin.yaml · cli/test/video_player_schema_test.dart (new)
Cases: C17.5/yaml → green (cli 43 = 40 + 3, analyze clean; the 3 tests red first on "orca_plugin.yaml has a schema:
section"; 14 hand mutations of the yaml each caught, the yaml restored byte for byte)
Changed: the yaml gains `schema:` in the voice's format: VideoPlayer (url "", autoPlay false, looping false,
showControls true, aspectRatio number with no default (the video's own), playerId defaulting to the node's id),
the five triggers in Flutter's order (onProgress and onError payloads in `event_data:`; onPlay/onPause only from the
overlay tap), the five actions with playerId and their value params; the platform blocks untouched; the test parses
it with the CLI's parser and checks names, reads, types, defaults and fired event data against Flutter's source.
Decisions: position, volume and speed required (Flutter does nothing without them) · "missing does nothing" ·
the looping and seek-clamp notes come from video_player 2.11.1, not the Dart source (all auto-decided, minor)
Review fit: pass · Review quality: pass

#### T2 · Pub and git ignore native dirs (0d4f1a6)
Files: plugins/orca_video_player/.pubignore (new) · plugins/orca_video_player/.gitignore (new)
Cases: P-pub → green (`flutter pub publish --dry-run` and `git check-ignore -v --no-index`: red first with dummy
files, the archive listed android/ and ios/; green: CHANGELOG, LICENSE, README, lib/, orca_plugin.yaml, pubspec.yaml;
the dry run's 1 warning (no CHANGELOG 0.2.1 entry) and 1 hint as before)
Changed: .pubignore leaves /ios/ and /android/ out and repeats .gitignore's entries; .gitignore ignores .build/,
.swiftpm/, Package.resolved, .gradle/, .kotlin/, local.properties; both byte-identical to the voice recorder's.
Decisions: build/ left to the root .gitignore (auto-decided, minor) · /ios/ and /android/ anchored to the package
(auto-decided, minor)
Review fit: pass · Review quality: pass

#### T3 · Android Gradle package on SDK toolchain (c1e0ceb)
Files: plugins/orca_video_player/android/settings.gradle.kts · gradle.properties · VERSION · gradlew (a symlink to
../../../sdk-kotlin/gradlew) · video-player/build.gradle.kts (all new)
Cases: P-pkg/K → green (`./gradlew build --continue`: BUILD SUCCESSFUL on the empty module; red first: no settings
file; throwaway probes showed explicitApi, -Werror and lint NewApi each fail the build, and a probe with OrcaPlugin,
MediaPlayer, TextureView in an AndroidView, material3, createComposeRule, runTest and Robolectric built and passed;
the staged POM is com.orcagateway:orca-video-player:0.1.0-alpha.1 on com.orcagateway:sdk:0.1.0-alpha.1; voice 25 green)
Changed: the voice's settings, properties and module with the video's names (root orca-video-player-android,
project :orca-video-player, namespace com.orcagateway.plugins.videoplayer); the sdk as api, Compose ui, foundation,
material3, the voice's test set; explicitApi, warnings as errors, minSdk 24, JVM 17; publishing as the voice's.
Decisions: no activity-compose (no runtime permission) · the voice's `orca.repoRoot` test property kept, pointed at
the video plugin (auto-decided, minor) · no placeholder source or manifest: the empty module builds (auto-decided, minor)
Review fit: pass · Review quality: pass

### Group 2
#### T4 · SwiftPM package with generated props types (6cd6c05)
Files: plugins/orca_video_player/ios/Package.swift · VERSION · Sources/OrcaVideoPlayer/Generated/
OrcaVideoPlayerTypes.swift · Tests/OrcaVideoPlayerTests/VideoPlayerPropsTests.swift (all new) ·
cli/test/video_player_swift_props_test.dart (new)
Cases: P-pkg/S, C17.5/S → green (swift test 5, 0 warnings from a clean build; xcodebuild build and test on the iOS
18.5 simulator, 4 there: the manifest test is macOS only; cli 45; red first: no Package.swift, an empty target,
"No types at …")
Changed: the voice's manifest with the video's names: tools 5.9, iOS 16 / macOS 13, package, product and module
OrcaVideoPlayer; the SDK by path in the monorepo, else orca-gateway-swift from 0.1.0-alpha.2, from
`Context.packageDirectory`; VERSION 0.1.0-alpha.1; the types file is the CLI's output, unedited; the tests pin the
six props, Flutter's five triggers in order, the five actions' params, and both manifest branches (the URL matched
as a whole JSON string, per the voice's review fix); the drift test regenerates and names the command.
Decisions: the macOS-only dump-package test kept · the test target lists OrcaGateway · a Value-typed param reads
nil, so T7 resolves from the raw action as Flutter (all auto-decided, minor)
Review fit: pass · Review quality: pass

#### T5 · Kotlin generated props, params, drift test (e4d9625)
Files: plugins/orca_video_player/android/video-player/src/main/kotlin/com/orcagateway/plugins/videoplayer/
OrcaVideoPlayerTypes.kt (new) · the same path under src/test/: VideoPlayerPropsTest.kt (new) ·
cli/test/video_player_kotlin_props_test.dart (new)
Cases: C17.5/K → green (the plugin's Gradle build, VideoPlayerPropsTest 6/6, lint ran; the drift test 1/1; red
first: "Unresolved reference 'VideoPlayerProps'", "No types at …")
Changed: the types file is the CLI's --types-only output, unedited, and compiles under explicitApi and warnings as
errors (no generator fix); the test pins exactly the six props Flutter reads (an integer aspectRatio reads as a
Double, absent or null props read null), Flutter's five triggers in order, the five actions' params (playerId a
string, position, volume and speed numbers); the drift test regenerates in a temp dir and names the command.
Decisions: the voice's T6 shape (plain JUnit, Java reflection, "custom:<name>" raw actions) · no Value-object test
here: T8 resolves playerId and the numbers from the raw action, as Flutter (both auto-decided, minor)
Review fit: pass · Review quality: pass

#### T6 · Demo /video page in custom app (a716522, 0dbb02f rework)
Files: examples/server/orca_video_player.ts (new) · examples/server/custom.ts · examples/server/README.md ·
engine/test/video-demo.test.ts (new) · engine/test/voice-demo.test.ts (added at 09: its home-targets pin)
Cases: C17.2/page → green (6 new tests, red first: /video 404, no home target; engine 812 = 806 + 6)
Changed: the CLI's TS output for the yaml, its two imports pointed at ../../engine/src/types (the header says so);
home gains "Go to Video Page"; /video holds a VideoPlayer (playerId "demo", butterfly.mp4, answered 200) whose
onProgress sets videoPosition to `V.event("position")` and onComplete sets videoDone; Play, Pause, Seek 0, Volume
0.5, Speed 1.5 from the generated classes; Texts of both keys; the test pins state, props, triggers, params, watches.
Rework 0dbb02f: the baseline voice-demo pin of home's targets, red after the new button, now the exact
["/map", "/video", "/voice"] (decision baseline-voice-pin-edited; still exact, nothing else changed).
Decisions: the onComplete flag kept for the hand checks · two Rows of buttons for a phone · examples/server tsc
errors 25 → 36, all of kinds already there, left as the voice's (all auto-decided, minor)
Review fit: blocks (the baseline voice pin edit not recorded), fixed by the decision record · Review quality: pass

### Test run
Group 1, on feat/native-parity-s17-video after T1-T3 (SC/s17v/g1run): `cd cli && dart test` 43 pass (40 + T1's 3) ·
`dart analyze` no issues · `cd engine && bun test` 806 pass, 0 fail · `cd sdk && flutter test` 517 pass · `flutter
analyze` no issues · `cd sdk-swift && swift build --build-tests && swift test` core 585, SwiftUI 489, 0 failures, 0
compiler warnings (the 6 runtime SwiftUI notes of the C18 tests, as at baseline) · `cd sdk-kotlin && ./gradlew build
--continue` BUILD SUCCESSFUL, up to date (no input changed since the baseline's core 607, sdk 666) · voice packages:
swift test 24, Gradle BUILD SUCCESSFUL (25 at baseline, up to date) · `cd plugins/orca_video_player/android &&
./gradlew build --continue` BUILD SUCCESSFUL (no sources yet) · the generators leave no diff · `flutter pub publish
--dry-run` in plugins/orca_video_player: the same 1 warning (no CHANGELOG 0.2.1 entry) and 1 hint as at baseline, no
ios/ or android/ file in the archive.

Group 2, after T4-T6 and T6's rework, on feat/native-parity-s17-video rebased onto origin/main 677d114 (PR #47
merged; no conflict, every commit id here is the one on 677d114) (SC/s17v/g2run): `cd cli && dart test` 45 pass ·
`dart analyze` no issues · `cd engine && bun test` 812 pass, 0 fail (after the rework; before it 811 and 1 fail, the
voice-demo home-targets pin) · `cd sdk && flutter test` 517 pass · `flutter analyze` no issues · sdk-swift core 585,
SwiftUI 489, 0 failures, 0 compiler warnings · sdk-kotlin BUILD SUCCESSFUL · voice packages: swift test 24, Gradle
BUILD SUCCESSFUL · `cd plugins/orca_video_player/ios && swift build --build-tests && swift test` 5 pass, 0 warnings ·
`xcodebuild test -scheme OrcaVideoPlayer` on the iOS 18.5 simulator 4 pass, TEST SUCCEEDED · `cd
plugins/orca_video_player/android && ./gradlew build --continue` BUILD SUCCESSFUL, 6 tests · the generators leave no
diff · the pub dry run as at baseline.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- PR #47 merged (677d114) and this branch is on it; rebase again before the PR if main moves (PR #48 is open).
- After the merge, the user's (T15 writes how): the empty public repo orca-gateway/orca-video-player-swift, its own
  write deploy key, the secret ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY; release sdk-swift 0.1.0-alpha.2 and sdk-kotlin
  before rows 13-14.
