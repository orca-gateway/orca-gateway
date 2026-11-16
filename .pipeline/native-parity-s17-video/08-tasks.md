# 08 · Tasks · native-parity-s17-video

## Front page

### In one breath
tasks: 15 in 4 groups · widest group: 5 · cases: 16 of 16 placed (C17.2, C17.5; template P1-P5)
Step 17, plugin 2 of 4: the video player as its own Swift and Gradle packages, as the voice's.
G1 the yaml schema and the package shells; G2 generated props and the /video demo page.
G3 the players on both platforms and the release, mirror and CI rows; G4 both demo apps, the docs.
No wire-format change, no generator change, no new library (AVFoundation; MediaPlayer on Android).

### New for you
nothing new

### Trade-offs
1 auto-decided: Android plays through the system MediaPlayer, not Media3 (no new library)

### Questions for you
1. Commands: as the voice slice, the video packages in place of the voice's. (default: as found)
2. Commits: one per task on feat/native-parity-s17-video, stacked on PR #47. (default: yes)
3. One gate per group. (default: yes)
4. After the merge, yours: the mirror repo, deploy key, secret (T15 writes how). (default: ok)

## Appendix

### Where step 17 video comes from
Plan step 17 of /Users/amrebada/.claude/plans/native-parity/plan.md (the four plugins on both natives), the user's
packaging answer B (2026-11-16: separate packages under plugins/<name>/, versioned and released on their own), and the
design in the session scratchpad (s17/design-video.md: rows C17.2 and C17.5 checked against Flutter, the package
template P1-P5 with the video's names, the video player W1-W8). Stages 01-07 were skipped as covered by the plan, that
answer and the voice recorder's template (PR #47). Flutter is the reference:
plugins/orca_video_player/lib/src/video_player_plugin.dart (video_player 2.11.1).

### Groups
Paths are from the repo root unless they start with /Users/. `VP/` = plugins/orca_video_player/, `KT/` =
VP/android/video-player/src/main/kotlin/com/orcagateway/plugins/videoplayer/, `KTT/` = the same path under src/test/.

| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Video schema block pinned to Flutter | VP/orca_plugin.yaml · cli/test/video_player_schema_test.dart (new) | C17.5/yaml | S | — |
| 1 | T2 | Pub and git ignore native dirs | VP/.pubignore (new) · VP/.gitignore (new) | P-pub | S | — |
| 1 | T3 | Android Gradle package on SDK toolchain | VP/android/settings.gradle.kts (new) · VP/android/gradle.properties (new) · VP/android/VERSION (new) · VP/android/gradlew (new, a symlink to ../../../sdk-kotlin/gradlew) · VP/android/video-player/build.gradle.kts (new) | P-pkg/K | M | — |
| 2 | T4 | SwiftPM package with generated props types | VP/ios/Package.swift (new) · VP/ios/VERSION (new) · VP/ios/Sources/OrcaVideoPlayer/Generated/OrcaVideoPlayerTypes.swift (new) · VP/ios/Tests/OrcaVideoPlayerTests/VideoPlayerPropsTests.swift (new) · cli/test/video_player_swift_props_test.dart (new) | C17.5/S, P-pkg/S | M | T1 |
| 2 | T5 | Kotlin generated props, params, drift test | KT/OrcaVideoPlayerTypes.kt (new) · KTT/VideoPlayerPropsTest.kt (new) · cli/test/video_player_kotlin_props_test.dart (new) | C17.5/K | M | T1, T3 |
| 2 | T6 | Demo /video page in custom app | examples/server/orca_video_player.ts (new, the CLI's TS output, imports as in orca_voice_recorder.ts) · examples/server/custom.ts · examples/server/README.md (its plugin-file row) · engine/test/video-demo.test.ts (new) | C17.2/page | M | T1 |
| 3 | T7 | Swift AVPlayer plugin, view, five actions | VP/ios/Sources/OrcaVideoPlayer/VideoPlayerPlugin.swift (new) · VP/ios/Sources/OrcaVideoPlayer/VideoPlayback.swift (new: the protocol and its AVPlayer) · VP/ios/Sources/OrcaVideoPlayer/PlayerLayerView.swift (new: AVPlayerLayer in a UI/NSViewRepresentable) · VP/ios/Sources/OrcaVideoPlayer/VideoPlayerView.swift (new: loading, error, ready, overlay) · VP/ios/Tests/OrcaVideoPlayerTests/VideoPlayerPluginTests.swift (new, fakes) | C17.2/S | M | T4 |
| 3 | T8 | Kotlin MediaPlayer plugin, TextureView, INTERNET | VP/android/video-player/src/main/AndroidManifest.xml (new, INTERNET) · KT/VideoPlayerPlugin.kt (new) · KT/VideoPlayback.kt (new: the interface and its MediaPlayer) · KT/VideoPlayerView.kt (new: TextureView in an AndroidView, overlay) · KTT/VideoPlayerPluginTest.kt (new, fakes, Robolectric @Config(sdk = [34])) | C17.2/K | M | T3, T5 |
| 3 | T9 | release.sh rows 13-14, scratch-repo test | scripts/release.sh · engine/test/launch-release.test.ts | P-release | S | T3, T4 |
| 3 | T10 | Mirror PACKAGES line, LICENSE, rehearsal | scripts/swift-mirror.sh · .github/workflows/sdk-swift-mirror.yml (only its header's list of mirrors and secrets) · VP/ios/LICENSE (new) | P-mirror | M | T4 |
| 3 | T11 | CI matrices gain the video player | .github/workflows/native-plugins.yml | P-ci | S | T3, T4 |
| 4 | T12 | iOS demo links and registers player | examples/app-ios/OrcaCounter.xcodeproj/project.pbxproj · examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md (the hand check) | C17.2/hand-S | M | T6, T7 |
| 4 | T13 | Android demo includes and registers player | examples/app-android/settings.gradle.kts · examples/app-android/app/build.gradle.kts · examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/README.md (the hand check) | C17.2/hand-K | M | T6, T8 |
| 4 | T14 | Native READMEs: install, register, ATS | VP/ios/README.md (new) · VP/android/README.md (new) · VP/README.md (its native apps section) | P-readme | M | T7, T8 |
| 4 | T15 | Outside repo: walkthrough, release table | /Users/amrebada/workspace/orca-gateway/docs/User_Actions.md · /Users/amrebada/workspace/orca-gateway/CLAUDE.md (both outside the git repo, not in the PR) | P-docs | S | T9, T10 |

### Order, and why each boundary
- Kind: feature. Two lanes run side by side: Swift T4 → T7 → T12 and Kotlin T3 → T5 → T8 → T13. The /video page (T6)
  and the release work (T9-T11) run beside them. Nothing changes under schema/. No new dependency: AVFoundation on
  iOS; on Android MediaPlayer on a TextureView with Compose from the SDK's catalog (no Media3, and no
  activity-compose: INTERNET is granted at install). The SDK's own Video widgets (sdk-swift
  Widgets/Video.swift: AVPlayer in an AVPlayerLayer; sdk-kotlin widgets/Video.kt: MediaPlayer on a TextureView) are
  the in-repo model for T7 and T8; they are internal, so their approach is copied, not imported.
- 1 → 2: T4 and T5 run the CLI's existing `--types-only` mode on T1's schema. Package.swift goes with the types
  because a SwiftPM target with no sources fails. T5 compiles inside T3's Gradle build. T6's TS classes are the CLI's
  output for T1's yaml.
- 2 → 3: T7 and T8 read props, params and trigger names through T4's and T5's types and build inside those packages.
  T9's rows read the VERSION files from T3 and T4, and release.sh's generic mirror and maven branches validate those
  two packages. T10 splits T4's package; swift-mirror.sh refuses a split with no LICENSE at its root. The rehearsal
  stops where the voice's did, at the split's standalone build (no orca-gateway-swift 0.1.0-alpha.2 yet), plus a
  stand-in run with local bare repos that goes to the end. T11 builds and tests T3's and T4's packages.
- 3 → 4: T12 and T13 import the plugins from T7 and T8 and open T6's /video page for the hand checks (network
  needed). T14 documents what T7 and T8 do. T15 writes down what T9 and T10 settle: rows 13-14,
  orca-gateway/orca-video-player-swift and ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY, under release.sh's own words "the
  orca_video_player Swift mirror".
- The voice plan's grouping is reused (voice → video): T1→T1, T3→T2, T4→T3, T5→T4, T6→T5, T7→T6, T8→T7, T9→T8,
  T10→T9, T11→T10, T12→T11, T13→T12, T14→T13, T17→T14, T15→T15. Where it does not fit:
  - Nothing matches the voice's T2 or T16: the generators need no change. Every type in the video yaml is one they
    already emit (number widget props, number action params, string params as `Value | string`).
  - T1 is S: cli/test/plugin_generate_test.dart stays as it is; no CLI test reads the video yaml
    (plist_patcher_test.dart copies its plist shape inline, checked).
  - T11 is only the two matrix entries. sdk-kotlin-publish.yml and sdk-swift-mirror.yml need nothing to run (their
    tag patterns are generic, the secret is read by name), so there is no P-maven case; T10 only adds the video to
    the mirror workflow's header list.
  - T12 has no Info.plist change: nothing needs permission and the demo uses an https MP4, which ATS lets through.
    Flutter's NSAllowsArbitraryLoads is for http URLs; T14 says so. T13 leaves the app manifest alone because
    INTERNET merges in from T8's manifest.
- Stacked on PR #47: T6 and T9-T13 edit files #47 adds or changes. If #47 changes in review or merges, rebase before
  the group that touches those files.

### Seams
- VP/orca_plugin.yaml → T1: the Swift, Kotlin and TS generators (T4, T5, T6) all read it.
- VP/.gitignore and VP/.pubignore → T2: both lanes' build outputs (.build/, .swiftpm/, Package.resolved, .gradle/,
  .kotlin/, local.properties); pub reads .pubignore instead of .gitignore, so .pubignore repeats those and leaves
  /ios/ and /android/ out of the archive.
- VP/android/video-player/build.gradle.kts → T3: T5 and T8 compile in it, so T3 declares everything they need up
  front, all from the SDK's catalog (the sdk as api, Compose, junit4, robolectric, compose ui-test, coroutines-test).
- VP/ios/Package.swift → T4: T7, T10, T11 and T12 build on it.
- examples/server/custom.ts → T6: both hand checks need its /video page.
- scripts/release.sh → T9: one owner for both platform rows.

### Three checks (main session)
- Every case in exactly one task: 16 cases, 16 placements, none twice.
- No file in two tasks of one group: the Files cells of each group are disjoint sets (group 3 has five tasks, so it
  launches in two batches, T7-T10 then T11).
- No task over five files or beyond M; Depends on names earlier groups only.

### Not planned
none: all 16 cases are placed. These are the user's after the merge, not cases: creating
orca-gateway/orca-video-player-swift with its deploy key and the secret ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY; releasing
sdk-swift 0.1.0-alpha.2 and sdk-kotlin before rows 13-14; the C17.2 and C17.5 rows at stage 10. Switching Android to
Media3 is a later needs: question, not this PR (W4).

### Done when
test: `cd cli && dart test` · `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift build
--build-tests && swift test` · `cd sdk-kotlin && ./gradlew build --continue --console=plain` · both voice packages
(`swift test`, `./gradlew build`) · from G2: `cd plugins/orca_video_player/ios && swift build --build-tests && swift
test` (and `xcodebuild test` on the iOS 18.5 simulator before the PR) · `cd plugins/orca_video_player/android &&
./gradlew build --continue --console=plain`
lint: `dart analyze` in cli/ · `flutter analyze` in sdk/ · 0 Swift warnings · Kotlin explicitApi and warnings as
errors (in the build) · typecheck: the builds
baseline: cli 40 · engine 806 pass · Flutter 517, analyze clean · Swift core 585, SwiftUI 489 (585 and 593 on the iOS
18.5 simulator), 0 warnings · Kotlin core 607, sdk 666 · voice Swift 24 (23 on the simulator), voice Gradle 25 ·
generators: no drift (feat/native-parity-s17-voice 56316c9 on main 941e789, 2026-11-16)

commits: per task (feat/native-parity-s17-video, stacked on PR #47) · gate: per group (answered at gate 08, 2026-11-16, standing rule)
