# 09 · Implementation · native-parity-s17-video

## Front page

### In one breath
group 3 of 4 · tasks: 5 green, 0 blocked · cases: 12 of 16 green · engine bun test: 813 pass
T7 Swift player: AVPlayer, Flutter's five triggers and actions; 25 tests, 24 on the simulator.
T8 Kotlin player: MediaPlayer on a TextureView, the same; 19 tests; INTERNET in its manifest.
T9 release.sh rows 13-14; T10 the mirror line, LICENSE and rehearsal; T11 the CI matrices.
Reviews fixed: Swift now fails a non-number param as Flutter and Kotlin do; dead fields removed.

### New for you
nothing new

### Trade-offs
3 auto-decided: a covered page stops its video (Flutter plays on) · the play mark follows the
player · a voice release test already in main now ends its list at row 15 (still exact)

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 4: both demo apps, the READMEs, your walkthrough; then hand checks. (default: go)

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

### Group 3
#### T7 · Swift AVPlayer plugin, view, five actions (753ec43; 0eaf4d5 and 976cb40 rework)
Files: VP/ios/Sources/OrcaVideoPlayer/{VideoPlayerPlugin,VideoPlayback,PlayerLayerView,VideoPlayerView}.swift ·
VP/ios/Tests/OrcaVideoPlayerTests/VideoPlayerPluginTests.swift (all new)
Cases: C17.2/S → green (swift test 25 = 5 + 20, 0 warnings; xcodebuild test 24 on the iOS 18.5 simulator; red
first: "cannot find type 'VideoPlayerPlugin'"; each view modifier removed in turn turned a test red; no network)
Changed: `VideoPlayerPlugin: OrcaPlugin` with Flutter's name, widget, five actions, five triggers, a playerId
registry · VideoController ports video_player's (seek clamp, play at the end from 0, volume clamp, speed while
playing, speed ≤ 0 throws Dart's text) · registers once ready, fires through model.fire, unregisters on a new url
or the view leaving · AVPlayer behind VideoPlayback · AVPlayerLayer that lets taps through · W5's UI.
Decisions: the play mark follows the player · the player goes when the view leaves (both auto-decided, minor)
Review fit: a non-number param did nothing, now fails as Flutter and Kotlin (0eaf4d5) · Review quality: two unused
fields in the port's value, removed (976cb40)

#### T8 · Kotlin MediaPlayer plugin, TextureView, INTERNET (ef91b87, 02f7a48 rework)
Files: VP/android/video-player/src/main/AndroidManifest.xml · KT/{VideoPlayerPlugin,VideoPlayback,VideoPlayerView}.kt ·
KTT/VideoPlayerPluginTest.kt (all new)
Cases: C17.2/K → green (Gradle build: VideoPlayerPluginTest 19/19, props 6/6, lint no issues; red first: "Unresolved
reference 'VideoPlayback'"; no voice or SDK file touched)
Changed: INTERNET in the manifest (tested) · `VideoPlayerPlugin()` with Flutter's name, widget, five actions, five
triggers; ready players by playerId; playerId and the numbers resolved from the raw action · VideoController ports
video_player 2.11.1 (100 ms ticks while playing, seek clamp, play at the end from 0, volume clamp, speed > 0 while
playing, the end pauses at the duration); MediaPlayer behind VideoPlayback · TextureView in an AndroidView, W5's UI;
onPlay/onPause only from the tap, onComplete once and re-armed · fakes, plus one ShadowMediaPlayer test (no network).
Decisions: a non-number or speed ≤ 0 fails the action, as Dart · onError from the exception or what/extra (minor)
Review fit: pass · Review quality: an unused error field in the port's value, removed (02f7a48)

#### T9 · release.sh rows 13-14, scratch-repo test (16953fd)
Files: scripts/release.sh · engine/test/launch-release.test.ts
Cases: P-release → green (`bun test test/launch-release.test.ts` 5 pass, also under /bin/bash 3.2; red first: "index
out of range: 13"; engine 813 = 812 + 1; `bash -n` clean; shellcheck's 3 SC2005 notes on untouched lines as before)
Changed: two rows appended and nothing else: 13 `orca_video_player-ios` (mirror, `orca_video_player-ios-v`,
ios/VERSION), 14 `orca_video_player-android` (maven, `orca_video_player-android-v`); the script derives the mirror
orca-gateway/orca-video-player-swift, the override ORCA_VIDEO_PLAYER_SWIFT_MIRROR_URL, the artifact
com.orcagateway:orca-video-player, swift build + swift test, and "the orca_video_player Swift mirror"; the scratch
repo gains both VERSION files; a full stubbed release of 13 (next) and 14 (kept) against a local bare mirror checks
the rows, mirror and JDK checks, publish messages, commit and both tags.
Decisions: the voice test's list-end check moved from row 13 to row 15, still as strict (decision
baseline-voice-release-list-end-edited) · a full stubbed run, not a list-only check (both auto-decided, minor)
Review fit: pass · Review quality: pass

#### T10 · Mirror PACKAGES line, LICENSE, rehearsal (89cdb9f, 38a006e rework)
Files: scripts/swift-mirror.sh · .github/workflows/sdk-swift-mirror.yml (header only) · VP/ios/LICENSE (new)
Cases: P-mirror → green (rehearsal SC/s17v/t10/rehearse.sh 12 of 12; red first: "tag must start with one of
sdk-swift-v orca_voice_recorder-ios-v", then "the split has no LICENSE"; the YAML parses). Part B, against a local
bare mirror, stops at the split's own build: "no versions of 'orca-gateway-swift' match … 0.1.0-alpha.2" (not
released yet), nothing pushed; part C, on a stand-in sdk-swift 0.1.0-alpha.2, publishes and verifies to the end;
sdk-swift's split, refs and messages unchanged; SwiftPM's real fingerprint store unchanged.
Changed: the PACKAGES line orca_video_player-ios-v → orca-gateway/orca-video-player-swift,
ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY, OrcaVideoPlayer · the workflow's secrets paragraph names the video's · LICENSE
is the voice's BSL. Decisions: the stand-in under a scratch HOME and CFFIXED_USER_HOME · `info` and the workflow's
tag regex checked in the rehearsal (both auto-decided, minor)
Review fit: pass · Review quality: the tag row had listed every mirror, back to its one example, fixed (38a006e)

#### T11 · CI matrices gain the video player (cc6bed4)
Files: .github/workflows/native-plugins.yml
Cases: P-ci → green (the YAML parses; a scratch check of both matrices 14 of 14, red first: both listed only the voice
recorder; the video steps run locally: swift build + swift test --skip-build 5, 0 warnings; xcodebuild test 4 on the
iOS 18.5 simulator, TEST SUCCEEDED; the Gradle build BUILD SUCCESSFUL; actionlint not installed)
Changed: the ios matrix gains `plugin: orca_video_player, module: OrcaVideoPlayer`; the android matrix is
[orca_voice_recorder, orca_video_player]; nothing else needs the video (the path filters, working directories,
job and artifact names, scheme and report globs all come from the matrix).
Decisions: the video entries after the voice's, in release-row order · the header comment kept, it already says a
plugin adds one entry per matrix (both auto-decided, minor)
Review fit: pass · Review quality: pass

### Group 4
#### T7 · Swift player, group 4 additions (63ccee93 audio, 1db399da rework; e969c949 loading)
Files: VP/ios/Sources/OrcaVideoPlayer/{VideoPlayerPlugin,VideoPlayback,VideoPlayerView}.swift ·
VP/ios/Tests/OrcaVideoPlayerTests/VideoPlayerPluginTests.swift
Cases: C17.2/S → green (swift test 26, 0 warnings; xcodebuild test on the iOS 18.5 simulator 27; red first: the
session test before the port, 566 vs 32 for the loading view in the demo's Column; the hand check after a rebuild)
Changed: on iOS the first player to initialize upgrades the shared AVAudioSession to .playback as
video_player_avfoundation 2.9.4 does (record kept as playAndRecord, options kept, nothing set when right, once per
plugin, a failure logged) · the loading and error views take the full width and their own height, as Flutter's
Center in a Column (they took the free height of a Column drawn as a VStack)
Decisions: the audio port (T14's question, standing rule) · never fill the height: in a height-bounding box the
transient disc or text sits at the top (filling a real bound needs an sdk-swift API; follow-up) (minor)
Review fit: pass (audio), pass (loading) · Review quality: the once test passed without its guard, fixed (1db399da);
loading pass
#### T8 · Kotlin player, group 4 addition (a603163f first frame)
Files: VP/android/video-player/src/main/kotlin/com/orcagateway/plugins/videoplayer/VideoPlayback.kt ·
VP/android/video-player/src/test/kotlin/com/orcagateway/plugins/videoplayer/VideoPlayerPluginTest.kt
Cases: C17.2/K → green (`./gradlew build --continue` BUILD SUCCESSFUL, 20 + 6 tests, lint and warnings as errors
clean; red first `expected:<[0]> but was:<[]>`; on emulator-5584 the first frame under the ▶, Position 0 ms)
Changed: MediaPlayerPlayback.setSurface seeks to the player's position when a surface comes while it is prepared and
not playing, so the box shows the first frame before any play as Flutter's ExoPlayer and the Swift plugin do (a
MediaPlayer on a TextureView draws nothing until start or a seek); interface, fake and controller unchanged
Decisions: the seek at the surface, not at prepare (no surface yet then) · in MediaPlayerPlayback, as ExoPlayer does it
on its own · a new surface while paused gets the current frame (on API 24-25 the nearest sync frame) (all minor)
Review fit: pass · Review quality: pass
#### T12 · iOS demo links and registers player (cfdf0d0, 3790c88 rework)
Files: examples/app-ios/OrcaCounter.xcodeproj/project.pbxproj · examples/app-ios/OrcaCounter/OrcaCounterApp.swift ·
examples/app-ios/README.md · examples/app-ios/OrcaVideoPlayer (new, a git symlink to ../../plugins/orca_video_player/
ios; added at 09)
Cases: C17.2/hand-S → green (`xcodebuild clean build` BUILD SUCCEEDED, 0 Swift warnings; red first: "Missing package
product 'OrcaVideoPlayer'", the first pass blocked on it: SwiftPM names a local package after its folder, and both
plugins' are `ios`; the app opened /video on the simulator: the video, ▶, the five buttons, Position 0, Finished false)
Changed: the pbxproj links the video through ./OrcaVideoPlayer (resolved locally, the SDK by path, one OrcaGateway) ·
the app registers `VideoPlayerPlugin()` beside the voice's · the README says why the link, names four plugins and
the video's row, and walks the "### Video player" hand check (needs the network; https needs no plist entry).
Decisions: the link (decision swiftpm-local-package-identity) · the hand check's notes from the code (minor)
Review fit: pass · Review quality: the README gave the link twice, now one sentence (3790c88), fixed
#### T13 · Android demo includes and registers player (5bf993a)
Files: examples/app-android/settings.gradle.kts · examples/app-android/app/build.gradle.kts ·
examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/README.md
Cases: C17.2/hand-K → green (`./gradlew :app:assembleDebug` BUILD SUCCESSFUL, warnings as errors; red first:
"Unresolved reference 'VideoPlayerPlugin'"; the build installs on emulator-5584 and /video opens with the plugin's
view; `bun test test/launch-readmes.test.ts` 6 pass)
Changed: settings includes ../../plugins/orca_video_player/android as `orca-video-player-android` (one sdk-kotlin build
serves the app and both plugins) · the app depends on com.orcagateway:orca-video-player at the plugin's VERSION ·
registers `VideoPlayerPlugin()` after the voice's · INTERNET arrives by the manifest merger, the app's manifest
unchanged · the README's "### The video player" hand check (the network, the ORCA_PATH shortcut, five steps).
Decisions: the video's build named `orca-video-player-android` (Gradle refused two builds at `:android`, the same
folder-name clash as SwiftPM's) · `--es ORCA_PATH video` as the shortcut (both auto-decided, minor)
Review fit: pass · Review quality: pass
#### T14 · Native READMEs: install, register, ATS (fa5a43e5; 749e5163 rework)
Files: VP/ios/README.md (new) · VP/android/README.md (new) · VP/README.md (its native apps section)
Cases: P-readme → green (scratch check of 217 facts against the yaml, the Swift and Kotlin sources, release.sh,
swift-mirror.sh, the workflows and every link; red first 96 fail before the READMEs, then 9 fail on the new Sound
checks; `flutter pub publish --dry-run` the same 1 warning and 1 hint before and after, no ios/ or android/ file)
Changed: ios/README.md, the mirror's front page (SwiftPM from orca-video-player-swift 0.1.0-alpha.1, which brings
orca-gateway-swift from 0.1.0-alpha.2; `VideoPlayerPlugin()`; https as is, http through the narrowest ATS exception;
Sound: the plugin sets `.playback` on its first player as Flutter's video_player does; the tables; LICENSE) ·
android/README.md (Maven Central, `VideoPlayerPlugin()` without Context, INTERNET merged, cleartext by the app's own
network security config) · the pub README's "Native apps (Swift and Kotlin SDKs)" section, absolute links
Decisions: three wrong Flutter facts fixed in the pub README (`^0.1.0` → `^0.3.0` and `^0.2.0`, the class name
`VideoPlayerPlugin`) · the narrowest http exceptions, not Flutter's NSAllowsArbitraryLoads (both auto-decided, minor)
· the missing iOS audio session became T7's change 63ccee93 (standing rule) and this README's Sound section
Review fit: pass · Review quality: pass
#### T15 · Outside repo: walkthrough, release table (not in git, not in the PR)
Files: /Users/amrebada/workspace/orca-gateway/docs/User_Actions.md · /Users/amrebada/workspace/orca-gateway/CLAUDE.md
Cases: P-docs → green (SC/s17v/t15/check.py 95 of 95, red first 37 of 91: every doc check failing, every code check
passing; the code checks run release.sh's own mirror_url, maven_artifacts, check_swift_mirror (git stubbed), bump_pre
and tag_exists, swift-mirror.sh `info`, both workflows' tag patterns, Package.swift, build.gradle.kts, the VERSIONs)
Changed: User_Actions.md gains "## Native parity step 17: the orca_video_player Swift mirror (GitHub repository +
deploy key)" after the voice's: its 7 steps with orca-video-player-swift, its own key pair, the secret
ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY, sdk-swift 0.1.0-alpha.2 and sdk-kotlin first (Step 5 points to the voice's), then
`13,14`, the failures and fixes · CLAUDE.md: rows 13-14, "1-14", the video in steps 2, 6 and 9, its pre-req, the
Order bullet for `11,12` or `13,14`. Decisions: one script run per plugin · one staging path pattern · row 14 without
the sdk dependency, the Order bullet carries it (all auto-decided, minor)
Review fit: pass · Review quality: Step 5 copied the voice's sub-steps, now a pointer as Step 6 is, fixed
#### Hand checks (2026-11-16)
- iOS 18.5 simulator FDE5D612 and emulator-5584 (API 34), the demo's /video on :8094: the overlay tap plays and
  pauses with the ▶ following the player; Play, Pause, Seek 0 (the frame moves, Position holds while paused, as
  Flutter's onProgress fires only while playing); Speed 1.5 measured ≈1.4-1.5×; the end: the last frame, the ▶,
  Finished true; play at the end starts from 0. Volume 0.5 not audible there (the unit tests pin it).
- Two gaps from Flutter found and fixed: the iOS loading view took a Column's free height (e969c949), the Android
  box was blank until the first play (a603163f); both seen fixed after a rebuild. Notes: SC/s17v/hand/C17.2-hand.md.

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

Group 3, after T7-T11 (T10's rework included), on main 677d114 (SC/s17v/g3run): `cd cli && dart test` 45 pass ·
`dart analyze` no issues · `cd engine && bun test` 813 pass, 0 fail · `cd sdk && flutter test` 517 pass · `flutter
analyze` no issues · sdk-swift core 585, SwiftUI 489, 0 failures, 0 compiler warnings · sdk-kotlin BUILD SUCCESSFUL ·
voice packages: swift test 24, Gradle BUILD SUCCESSFUL · the video Swift package's swift test 25, 0 warnings;
xcodebuild test on the iOS 18.5 simulator 24, TEST SUCCEEDED · the video Gradle package BUILD SUCCESSFUL, 25 tests
(19 + 6), lint clean · the generators leave no diff · `bash -n` of release.sh and swift-mirror.sh, shellcheck clean
on swift-mirror.sh · every workflow parses · the pub dry run as at baseline.
After T7's rework (0eaf4d5) and T8's (02f7a48), the two video packages again (SC/s17v/g3run2): swift test 25, 0
warnings · xcodebuild test on the iOS 18.5 simulator 24, TEST SUCCEEDED · the Gradle package BUILD SUCCESSFUL, 19 + 6.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- PR #47 merged (677d114) and this branch is on it; rebase again before the PR if main moves (PR #48 is open).
- After the merge, the user's (T15 writes how): the empty public repo orca-gateway/orca-video-player-swift, its own
  write deploy key, the secret ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY; release sdk-swift 0.1.0-alpha.2 and sdk-kotlin
  before rows 13-14.
- T15's two files are outside the repo (docs/User_Actions.md, CLAUDE.md at the workspace root): not in the PR.
- Follow-ups for the PR body: sdk-swift's own Center and Align fill a Column's leftover height when the Column has no
  flex child (drawn as a VStack), where Flutter's shrink to the child (measured by T7's rework); an sdk-swift way for
  a plugin to tell a real height bound from that share; renaming the plugins' Swift and Gradle package folders so
  they no longer clash (instead of the ./OrcaVideoPlayer link and the named Gradle build) before map and push.
