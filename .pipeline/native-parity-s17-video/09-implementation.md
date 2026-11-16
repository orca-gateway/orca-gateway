# 09 · Implementation · native-parity-s17-video

## Front page

### In one breath
group 1 of 4 · tasks: 3 green, 0 blocked · cases: 3 of 16 green · engine bun test: 806 pass
T1 schema: the yaml describes Flutter's VideoPlayer, five triggers, five actions; a test pins it.
T2 ignores: the pub archive leaves out ios/ and android/; native build outputs are ignored.
T3 Gradle: plugins/orca_video_player/android builds on the SDK's toolchain (empty module).
Every suite green; cli 43 (40 + 3); no generator drift; nothing under schema/ changed.

### New for you
nothing new

### Trade-offs
3 auto-decided: params required as Flutter acts only with them · build/ left to the root ignore ·
the voice's repoRoot test property kept so both packages stay alike

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 2, the generated types on both packages and the /video demo page. (default: go)

## Appendix

### Group 1
#### T1 · Video schema block pinned to Flutter (063e74d)
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

#### T2 · Pub and git ignore native dirs (27ab66e)
Files: plugins/orca_video_player/.pubignore (new) · plugins/orca_video_player/.gitignore (new)
Cases: P-pub → green (`flutter pub publish --dry-run` and `git check-ignore -v --no-index`: red first with dummy
files, the archive listed android/ and ios/; green: CHANGELOG, LICENSE, README, lib/, orca_plugin.yaml, pubspec.yaml;
the dry run's 1 warning (no CHANGELOG 0.2.1 entry) and 1 hint as before)
Changed: .pubignore leaves /ios/ and /android/ out and repeats .gitignore's entries; .gitignore ignores .build/,
.swiftpm/, Package.resolved, .gradle/, .kotlin/, local.properties; both byte-identical to the voice recorder's.
Decisions: build/ left to the root .gitignore (auto-decided, minor) · /ios/ and /android/ anchored to the package
(auto-decided, minor)
Review fit: pass · Review quality: pass

#### T3 · Android Gradle package on SDK toolchain (d3c20d1)
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

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- Stacked on PR #47 (feat/native-parity-s17-voice): rebase onto main once #47 merges, before the PR opens.
- After the merge, the user's (T15 writes how): the empty public repo orca-gateway/orca-video-player-swift, its own
  write deploy key, the secret ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY; release sdk-swift 0.1.0-alpha.2 and sdk-kotlin
  before rows 13-14.
