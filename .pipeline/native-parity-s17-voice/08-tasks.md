# 08 · Tasks · native-parity-s17-voice

## Front page

### In one breath
tasks: 15 in 4 groups · widest group: 5 · cases: 17 of 17 placed (C17.3, C17.5; template P1-P5)
Step 17, plugin 1 of 4: the voice recorder as its own Swift and Gradle packages (your answer B).
G1 the yaml schema, the CLI's types-only mode, package shells; G2 generated props, the demo page.
G3 the recorders on both platforms and the release, mirror and CI rows; G4 both demo apps, the docs.
No wire-format change; no new library (system audio APIs, the SDK's catalog only).

### New for you
nothing new

### Trade-offs
1 auto-decided: the Gradle package uses the SDK's wrapper by symlink (one Gradle version)

### Questions for you
1. Commands: as step 14, plus `dart test` in cli/ and both new packages' builds. (default: as found)
2. Commits: one per task on feat/native-parity-s17-voice; PR at the end. (default: yes)
3. One gate per group. (default: yes)
4. After the merge, yours: the mirror repo, deploy key, secret (T15 writes how). (default: ok)

## Appendix

### Where step 17 voice comes from
Plan step 17 of /Users/amrebada/.claude/plans/native-parity/plan.md (the four plugins on both natives), the user's
packaging answer B (2026-11-16: separate packages, each plugin's native packages under plugins/<name>/, versioned and
released on their own), and the design in the session scratchpad (s17/design-voice.md: rows C17.3 and C17.5 checked
against Flutter, the package template P1-P5, the voice recorder V1-V8). Stages 01-07 were skipped as covered by the
plan and that answer. Flutter is the reference: plugins/orca_voice_recorder/lib/src/voice_recorder_plugin.dart.

### Groups
Paths are from the repo root unless they start with /Users/. `VR/` = plugins/orca_voice_recorder/, `KT/` =
VR/android/voice-recorder/src/main/kotlin/com/orcagateway/plugins/voicerecorder/, `KTT/` = the same path under src/test/.

| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Voice schema block; no-schema test retargeted | VR/orca_plugin.yaml · cli/test/plugin_generate_test.dart · cli/test/voice_recorder_schema_test.dart (new) | C17.5/yaml | M | — |
| 1 | T2 | CLI --types-only; full stubs byte-identical | cli/lib/src/commands/plugin_generate.dart · cli/lib/src/generators/swift_generator.dart · cli/lib/src/generators/kotlin_generator.dart · cli/test/swift_generator_test.dart · cli/test/kotlin_generator_test.dart | C17.5/gen | M | — |
| 1 | T3 | Pub archive and git ignore native dirs | VR/.pubignore (new) · VR/.gitignore (new) | P-pub | S | — |
| 1 | T4 | Android Gradle package on SDK toolchain | VR/android/settings.gradle.kts (new) · VR/android/gradle.properties (new) · VR/android/VERSION (new) · VR/android/gradlew (new, a symlink to ../../../sdk-kotlin/gradlew: "the SDK's wrapper", P1) · VR/android/voice-recorder/build.gradle.kts (new) | P-pkg/K | M | — |
| 1 | T16 | TS string action params take a Value (added at 09: Flutter resolves them; T7 needs it) | cli/lib/src/generators/typescript_generator.dart · cli/test/typescript_generator_test.dart (new) | C17.3/ts | S | — |
| 2 | T5 | SwiftPM package with generated props types | VR/ios/Package.swift (new) · VR/ios/VERSION (new) · VR/ios/Sources/OrcaVoiceRecorder/Generated/OrcaVoiceRecorderTypes.swift (new) · VR/ios/Tests/OrcaVoiceRecorderTests/VoiceRecorderPropsTests.swift (new) · cli/test/voice_recorder_swift_props_test.dart (new) | C17.5/S, P-pkg/S | M | T1, T2 |
| 2 | T6 | Kotlin generated props, params, drift test | KT/OrcaVoiceRecorderTypes.kt (new) · KTT/VoiceRecorderPropsTest.kt (new) · cli/test/voice_recorder_kotlin_props_test.dart (new) | C17.5/K | M | T1, T2, T4 |
| 2 | T7 | Demo /voice page in custom app | examples/server/orca_voice_recorder.ts (new, TS generator output, imports as in orca_google_map.ts) · examples/server/custom.ts · examples/server/README.md (its plugin-file row) · engine/test/voice-demo.test.ts (new) | C17.3/page | M | T1, T16 |
| 3 | T8 | Swift recorder, playback, view, nine actions | VR/ios/Sources/OrcaVoiceRecorder/VoiceRecorderPlugin.swift (new) · VR/ios/Sources/OrcaVoiceRecorder/Recorder.swift (new) · VR/ios/Sources/OrcaVoiceRecorder/Player.swift (new) · VR/ios/Sources/OrcaVoiceRecorder/VoiceRecorderView.swift (new) · VR/ios/Tests/OrcaVoiceRecorderTests/VoiceRecorderPluginTests.swift (new) | C17.3/S | M | T5 |
| 3 | T9 | Kotlin recorder, playback, view, mic permission | VR/android/voice-recorder/src/main/AndroidManifest.xml (new) · KT/VoiceRecorderPlugin.kt (new) · KT/VoiceRecorder.kt (new) · KT/VoiceRecorderView.kt (new) · KTT/VoiceRecorderPluginTest.kt (new) | C17.3/K | M | T4, T6 |
| 3 | T10 | release.sh rows 11-12, scratch-repo test | scripts/release.sh · engine/test/launch-release.test.ts | P-release | S | T4, T5 |
| 3 | T11 | Swift mirror split per plugin tag | scripts/swift-mirror.sh · .github/workflows/sdk-swift-mirror.yml · VR/ios/LICENSE (new) | P-mirror | M | T5 |
| 3 | T12 | Maven plugin tags, package CI workflow | .github/workflows/sdk-kotlin-publish.yml · .github/workflows/native-plugins.yml (new) | P-maven, P-ci | S | T4, T5 |
| 4 | T13 | iOS demo links, registers, mic plist | examples/app-ios/OrcaCounter.xcodeproj/project.pbxproj · examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/Info.plist · examples/app-ios/README.md (the hand check) | C17.3/hand-S | M | T7, T8 |
| 4 | T14 | Android demo includes and registers plugin | examples/app-android/settings.gradle.kts · examples/app-android/app/build.gradle.kts · examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/README.md (the hand check) | C17.3/hand-K | M | T7, T9 |
| 4 | T17 | Native package READMEs: install, register, mic (added at 09) | VR/ios/README.md (new) · VR/android/README.md (new) · VR/README.md (a native apps section) | P-readme | S | T8, T9 |
| 4 | T15 | Outside repo: walkthrough, release table | /Users/amrebada/workspace/orca-gateway/docs/User_Actions.md · /Users/amrebada/workspace/orca-gateway/CLAUDE.md (both outside the git repo, not in the PR) | P-docs | S | T10, T11 |

### Order, and why each boundary
- Kind: feature. Two lanes run side by side: Swift T5 → T8 → T13 and Kotlin T4 → T6 → T9 → T14. The server page (T7)
  and the release work (T10-T12) run beside them. Nothing touches schema/, so the wire format stays unchanged. No new
  dependency: Swift uses system frameworks only; Kotlin uses only libraries already in the SDK's catalog
  (activity-compose for the permission launcher; robolectric, junit4 and coroutines-test for the tests).
- 1 → 2: T5 and T6 run T2's new `--types-only` mode (props, params and trigger names, no plugin stub; it writes
  `<Pascal>Types.swift` / `.kt`) on T1's schema. The current generator also writes a placeholder
  `OrcaVoiceRecorderPlugin`, which a shipped package must not carry. T6 compiles inside T4's Gradle build, and T7's TS
  classes come from T1's yaml.
- 2 → 3: T8 and T9 draw and act through the props, params and trigger names from T5 and T6. T10 reads both new
  VERSION files (T4, T5) and has release.sh validate both packages; launch-release.test.ts builds a scratch repo from
  the manifests release.sh reads, so it must hold the two new ones. T11 splits T5's package; swift-mirror.sh refuses a
  split with no LICENSE at its root, hence VR/ios/LICENSE. The split's standalone build needs an sdk-swift release on
  orca-gateway-swift that has the step 16 plugin API (P3 ordering), so P-mirror can only be rehearsed up to that
  build. T12 builds, tests and publishes T4's and T5's packages.
- 3 → 4: T13 and T14 import the plugins from T8 and T9 and open T7's /voice page for the hand checks. T15 writes down
  the rows, the mirror repo and the `ORCA_VOICE_RECORDER_SWIFT_DEPLOY_KEY` secret that T10 and T11 settled.
- Rebased onto main 644d5d8 (steps 12 and 13) before this plan was written: of the planned files only the two demo
  apps' entry files (OrcaCounterApp.swift, MainActivity.kt) changed upstream; T13 and T14 work on them as they are now.

### Seams
- VR/orca_plugin.yaml → T1: the Swift, Kotlin and TS generators (T5, T6, T7) all read it.
- cli/test/plugin_generate_test.dart → T1: its C16.6 test uses this yaml as the "manifest without schema" case and
  breaks once the schema lands, so T1 moves that test to a temp manifest. T2 puts its own tests in the generator
  test files.
- VR/.gitignore and VR/.pubignore → T3: both lanes' build outputs (.build/, .swiftpm/, Package.resolved, .gradle/,
  .kotlin/, local.properties). pub reads .pubignore instead of .gitignore, so .pubignore must list those too.
- VR/android/voice-recorder/build.gradle.kts → T4: T6 and T9 compile in it, so T4 declares every dependency and test
  dependency they need up front.
- VR/ios/Package.swift → T5: T8, T11, T12 and T13 build on it.
- examples/server/custom.ts → T7: both hand checks need its /voice page.
- scripts/release.sh → T10: one owner, even though both platform rows land in it.

### Three checks (main session)
- Every case in exactly one task: 17 cases, 17 placements, none twice.
- No file in two tasks of one group: the Files cells of each group are disjoint sets.
- No task over five files or beyond M; Depends on names earlier groups only.

### Not planned
none: all 17 cases are placed. These are the user's after the merge, not cases: the release.sh runs, the sdk-swift and
sdk-kotlin releases with the step 16 API (they must come before the plugin's), creating
orca-gateway/orca-voice-recorder-swift with its deploy key and secret, and the C17.3 and C17.5 rows at stage 10.

### Done when
test: `cd cli && dart test` · `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift build
--build-tests && swift test` · `cd sdk-kotlin && ./gradlew build --continue --console=plain` · from G2:
`cd plugins/orca_voice_recorder/ios && swift build --build-tests && swift test` (and `xcodebuild test` on the iOS 18.5
simulator before the PR) · `cd plugins/orca_voice_recorder/android && ./gradlew build --continue --console=plain`
lint: `dart analyze` in cli/ · `flutter analyze` in sdk/ · 0 Swift warnings · Kotlin explicitApi and warnings as
errors (in the build) · typecheck: the builds
baseline: cli 27 · engine 795 pass · Flutter 485, analyze clean · Swift core 523, SwiftUI 433 (501 on the iOS 18.5
simulator), 0 warnings · Kotlin core 535, sdk 586 · generators: no drift (origin/main 644d5d8, 2026-11-16)

commits: per task (feat/native-parity-s17-voice) · gate: per group (answered at gate 08, 2026-11-16)
