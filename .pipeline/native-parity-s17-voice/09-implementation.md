# 09 · Implementation · native-parity-s17-voice

## Front page

### In one breath
group 3 of 4 · tasks: 5 green, 0 blocked · cases: 15 of 19 green · engine bun test: 804 pass
T8 Swift plugin: records, plays, draws Flutter's view and runs its nine actions on AVFoundation.
T9 Kotlin plugin: the same on MediaRecorder and MediaPlayer; the mic is asked from the view.
T10 release.sh: rows 11 and 12 release both native packages; the numbers people type stay.
T11 Swift mirror: a plugin tag splits its package to its own mirror repo, one queue per mirror.
T12 Maven and CI: plugin tags publish to Central; a new workflow builds both packages on PRs.
Rebased onto main 20611b2 (step 5) with no conflict; every suite is green there.

### New for you
nothing new

### Trade-offs
3 auto-decided: playback position every 200 ms · a queue per mirror · rerun a plugin's mirror run

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 4 (both demo apps, the native READMEs, the walkthrough)? (default: go)

## Appendix

### Group 1
#### T1 · Voice schema block; no-schema test retargeted (6ae7715)
Files: plugins/orca_voice_recorder/orca_plugin.yaml · cli/test/plugin_generate_test.dart ·
cli/test/voice_recorder_schema_test.dart (new)
Cases: C17.5/yaml → green (cli 36 with T2's tests; analyze clean; the 3 new tests red first; 8 hand mutations of
the yaml each caught; the moved C16.6 test green before and after)
Changed: the yaml gains `schema:` in google_map's format: VoiceRecorder (recorderId string, showAmplitude boolean
default true), triggers onAmplitudeChange, onStateChange, onRecordingComplete (declared, never fired, said in its
description), the 9 actions with Flutter's params, required, defaults, scope enum page|app; the new test parses it
with the CLI's parser and checks it against voice_recorder_plugin.dart's source names, reads, types and defaults;
the C16.6 no-schema case writes its own temp manifest.
Decisions: trigger payloads in an `event_data:` block the parser ignores · no `format` param on startRecording
(Flutter reads none, V3) · triggers in Flutter's registration order
Review fit: pass · Review quality: pass

#### T2 · CLI --types-only; full stubs byte-identical (21af33d, 4dd5c78 rework)
Files: cli/lib/src/commands/plugin_generate.dart · cli/lib/src/generators/swift_generator.dart ·
cli/lib/src/generators/kotlin_generator.dart · cli/test/swift_generator_test.dart · cli/test/kotlin_generator_test.dart
Cases: C17.5/gen → green (6 new tests; the 4 --types-only tests red first; the 2 byte-for-byte pins green before
the change, as pins of today's output)
Changed: `--types-only` writes `<Pascal>Types.swift` / `.kt` with the props, params and trigger names and no plugin
stub; the Swift types file imports only OrcaGateway (no SwiftUI, no #if), the Kotlin one only ResolvedNode,
JsonValue, JsonObject; outside the suite the full stubs match the old generator for 5 manifests, and the voice
types compile in Swift 5/6 with warnings as errors and in Kotlin with explicitApi and warnings as errors.
Decisions: no schema writes nothing, as TS · `--lang ts` ignores the flag · the Swift types build on Linux too
Review fit: pass · Review quality: the Kotlin import block checked typesOnly in four places, fixed (4dd5c78)

#### T3 · Pub archive and git ignore native dirs (750454c)
Files: plugins/orca_voice_recorder/.pubignore (new) · plugins/orca_voice_recorder/.gitignore (new)
Cases: P-pub → green (`flutter pub publish --dry-run` and `git check-ignore`: red first with dummy files, the
archive listed android/ and ios/; green: CHANGELOG, LICENSE, README, lib/, orca_plugin.yaml, pubspec.yaml; the dry
run's warning and hint as before)
Changed: .pubignore leaves /ios/ and /android/ out and repeats .gitignore's entries; .gitignore ignores .build/,
.swiftpm/, Package.resolved, .gradle/, .kotlin/, local.properties; tracked package files stay tracked.
Decisions: build/ left to the root .gitignore (covers git and pub) · /ios/ and /android/ anchored to the package
Review fit: pass · Review quality: pass

#### T4 · Android Gradle package on SDK toolchain (23e758b)
Files: plugins/orca_voice_recorder/android/settings.gradle.kts · gradle.properties · VERSION · gradlew (a symlink to
../../../sdk-kotlin/gradlew) · voice-recorder/build.gradle.kts (all new)
Cases: P-pkg/K → green (`./gradlew build --continue` on the empty module with sdk-kotlin's :sdk built from source;
explicitApi, warnings as errors, minSdk 24, JVM 17 each shown failing a throwaway file; the staged POM depends on
com.orcagateway:sdk:0.1.0-alpha.1)
Changed: the SDK's catalog and includeBuild("../../../sdk-kotlin"); an Android library com.orcagateway.plugins
.voicerecorder published as com.orcagateway:orca-voice-recorder at VERSION 0.1.0-alpha.1; the sdk as api, Compose
and activity-compose as implementation; the SDK's test set (junit4, robolectric, compose ui-test, coroutines-test).
Decisions: the Gradle project is orca-voice-recorder, so an includeBuild substitutes it with no rule (T14) ·
group, version, staging repo and signing in the module file (no root build file planned) · the sdk as api
Review fit: pass · Review quality: pass

#### T16 · TS string action params take a Value (622e7ad; added at 09)
Files: cli/lib/src/generators/typescript_generator.dart · cli/test/typescript_generator_test.dart (new)
Cases: C17.3/ts → green (cli 38; both new tests red first on `path: string;`; engine 795 unchanged)
Changed: a plain string action param is `Value | string`, as numbers and booleans are `Value | T`; enums, widget
props, objects, arrays and the JSON unchanged; the tests pin one whole inline output and the voice yaml's
`PlayRecording(path: Value | string, ...)`.
Decisions: every plain string param, state-key params included (Flutter resolves strings as values) ·
examples/server/orca_google_map.ts not regenerated
Review fit: pass · Review quality: pass

Why T16 (decision ts-string-action-params-take-values): T1 found that the TS generator typed string action params as
plain `string`, while Flutter resolves them as values (`executor.resolveString`). The /voice page of group 2 must
play the path stopRecording saved in page state; a cast or a hand-built action would bypass the generated classes.
A minor plan change under the standing rule: one S task in group 1, T7 now depends on it, C17.3/ts its case.
Group 2's T7 also gains examples/server/README.md (its plugin-file row), a doc row.

### Group 2
#### T5 · SwiftPM package with generated props types (14d3cfc, b8d9adf rework)
Files: plugins/orca_voice_recorder/ios/Package.swift · VERSION · Sources/OrcaVoiceRecorder/Generated/
OrcaVoiceRecorderTypes.swift · Tests/OrcaVoiceRecorderTests/VoiceRecorderPropsTests.swift (all new) ·
cli/test/voice_recorder_swift_props_test.dart (new)
Cases: P-pkg/S, C17.5/S → green (swift test 6, 0 warnings from a clean build; xcodebuild build and test on the
iOS 18.5 simulator, 5 there: the manifest test is macOS only; cli 40; red first: no Package.swift, an empty target,
"No types at …")
Changed: tools 5.9, iOS 16 / macOS 13 as the SDK; package, product and module OrcaVoiceRecorder; the SDK dependency
chosen from `Context.packageDirectory`: ../../../sdk-swift by path in the monorepo, else orca-gateway-swift
from 0.1.0-alpha.2 (the first release that can carry the step 16 plugin API; the header says sdk-swift goes first);
VERSION 0.1.0-alpha.1; the types file is the CLI's --types-only output; the tests pin the props, the three
trigger names and the nine actions' params; the drift test regenerates and names the command on a difference.
Decisions: a `swift package dump-package` test of both manifest branches, kept (auto-decided, minor: the only check
of the mirror branch before a release) · the test target lists OrcaGateway explicitly · a Value-typed `path`
reads nil from the params type, so T8 resolves path, recorderId and position from the raw action, as Flutter
Review fit: pass · Review quality: the manifest test read SwiftPM's internal URL encoding (remote[0].urlString), fixed (b8d9adf)

#### T6 · Kotlin generated props, params, drift test (4eeca5c)
Files: plugins/orca_voice_recorder/android/voice-recorder/src/main/kotlin/com/orcagateway/plugins/voicerecorder/
OrcaVoiceRecorderTypes.kt (new) · the same path under src/test/: VoiceRecorderPropsTest.kt (new) ·
cli/test/voice_recorder_kotlin_props_test.dart (new)
Cases: C17.5/K → green (the plugin's Gradle build, VoiceRecorderPropsTest 7/7; the drift test 1/1; red first:
"Unresolved reference 'VoiceRecorderProps'", "No types at …")
Changed: the types file is the generator's output, unedited, and compiles under explicitApi and warnings as errors
(no generator fix); the test pins exactly recorderId and showAmplitude, absent props null, Flutter's three
triggers, the nine actions' param names and types; the drift test runs --types-only --package
com.orcagateway.plugins.voicerecorder in a temp dir and compares the one file written byte for byte.
Decisions: "exactly" by plain Java reflection (no kotlin-reflect) · plain JUnit (no Android API) · raw actions as
"custom:<name>", as sdk-kotlin's GeneratedPluginTest
Review fit: pass · Review quality: pass

#### T7 · Demo /voice page in custom app (3716a89)
Files: examples/server/orca_voice_recorder.ts (new) · examples/server/custom.ts · examples/server/README.md ·
engine/test/voice-demo.test.ts (new)
Cases: C17.3/page → green (5 new tests, red first: /voice 404, no button; engine 800 = 795 + 5)
Changed: the CLI's TS output for the yaml with its two imports pointed at ../../engine/src/types (the header says
so and how to regenerate); home gains "Go to Voice Page"; /voice holds a VoiceRecorder (recorderId "demo"), Start,
Stop (pathKey voicePath, durationKey voiceDuration) and Play (`V.pageState("voicePath")`) from the generated
classes, and Texts of both keys; the test renders /voice and /home through the engine and pins the node, the
actions' params, the Texts' watches and the buttons.
Decisions: the home button copies the map's `Custom("navigate", { path })` · pathKey/durationKey plain strings
(Flutter reads them `as String?`) · examples/server is outside the engine's tsconfig; its tsc errors (11 → 24) are
of two kinds already there (`Custom("<name>")` vs `custom:${string}`, generated actions vs CustomAction): left
as orca_google_map.ts is, a follow-up (auto-decided, minor; decision ts-generated-actions-vs-custom-type)
Review fit: pass · Review quality: pass

### Group 3
#### T8 · Swift recorder, playback, view, nine actions (bdcccc5, 44049bb and a69aece rework)
Files: VR/ios/Sources/OrcaVoiceRecorder/{VoiceRecorderPlugin,Recorder,Player,VoiceRecorderView}.swift (new) ·
VR/ios/Tests/OrcaVoiceRecorderTests/VoiceRecorderPluginTests.swift (new)
Cases: C17.3/S → green (swift test 24 = 6 + 18, 0 warnings · xcodebuild test on the iOS 18.5 simulator 23 = 5 + 18;
red first: "cannot find type 'VoiceRecorderPlugin' in scope"; sdk-swift untouched)
Changed: `VoiceRecorderPlugin: OrcaPlugin` with Flutter's name, widget, nine actions and three triggers; one recorder
per recorderId and one player per plugin instance; recorderId, path and position resolved through executor.resolve,
the other params as sent through T5's types · small @MainActor Recorder/Player protocols over AVAudioRecorder (AAC-LC
44.1 kHz, 128 kbit/s, 2 channels, record's defaults; averagePower every 200 ms, stopped while paused) and AVAudioPlayer
(.playback first) · the view draws Flutter's dot, bar and label and fires through model.fire · tests with fakes and an
injected clock. Rework 44049bb: `.allowBluetoothHFP` from Swift 6.2 (the 26 SDKs), `.allowBluetooth` before (CI's
Xcode 16.4). Rework a69aece: the trigger test hosts the view in a real window, so the view's own onReceive is tested
(red with it deleted). Decisions: state per plugin instance, not Flutter's statics · position every 200 ms (minor)
Review fit: .allowBluetoothHFP exists only in the 26 SDKs, CI pins Xcode 16.4, fixed (44049bb) ·
Review quality: no test reached the view's onReceive (deleting it left 18 green), fixed (a69aece)
#### T9 · Kotlin recorder, playback, view, mic permission (ee0e4a4, 00299ea rework)
Files: VR/android/voice-recorder/src/main/AndroidManifest.xml (new) · KT/VoiceRecorderPlugin.kt (new) ·
KT/VoiceRecorder.kt (new) · KT/VoiceRecorderView.kt (new) · KTT/VoiceRecorderPluginTest.kt (new)
Cases: C17.3/K → green (VoiceRecorderPluginTest 18 of 18, lint clean, explicitApi, warnings as errors; red first:
"Unresolved reference 'VoiceRecorderPlugin'"; VoiceRecorderPropsTest 7 of 7 kept)
Changed: RECORD_AUDIO in the manifest · `VoiceRecorderPlugin(context) : OrcaPlugin` as the Swift one; MediaRecorder
(MPEG_4/AAC .m4a in cacheDir, 20·log10(maxAmplitude/32767) dBFS every 200 ms, -160 for silence as record's floor) and
MediaPlayer behind internal interfaces; the mic asked through the launcher the view registers
(rememberLauncherForActivityResult), a refusal or no view on screen returns silently · tests with fakes, a TestScope
for the ticks, Compose and Robolectric @Config(sdk = [34]). Rework 00299ea: pause stops the amplitude ticks and resume
starts them, as record does. Decisions: the plugin takes a Context (T14 passes applicationContext)
Review fit: pass · Review quality: pauseRecording kept the amplitude ticks running while paused, fixed (00299ea)
#### T10 · release.sh rows 11-12, scratch-repo test (4676d85)
Files: scripts/release.sh · engine/test/launch-release.test.ts
Cases: P-release → green (launch-release 4 pass, also under /bin/bash 3.2; red first: "index out of range: 11")
Changed: rows 11 `orca_voice_recorder-ios` and 12 `orca_voice_recorder-android`, so the numbers people type stay the
same; the plugin's mirror is orca-gateway/orca-voice-recorder-swift (override ORCA_VOICE_RECORDER_SWIFT_MIRROR_URL,
sdk-swift keeps SWIFT_MIRROR_URL), its validation swift build then swift test, its artifact
com.orcagateway:orca-voice-recorder, no capability regeneration · the test runs 11 (next) and 12 (kept) through with
stubs and a local bare mirror: the listing, the mirror, the JDK check, the commit, both publish messages, both tags.
Decisions: names derived from the row, no table · the selection order is the publish order (sdk-swift first is the
user's, as sdk before pub plugins) · an unreachable mirror points to User_Actions.md "the orca_voice_recorder Swift
mirror" (T15 titles its section so)
Review fit: pass · Review quality: pass
#### T11 · Swift mirror split per plugin tag (4452443, c49a655 change, e322111 rework)
Files: scripts/swift-mirror.sh · .github/workflows/sdk-swift-mirror.yml · VR/ios/LICENSE (new)
Cases: P-mirror → green (rehearsal 8 of 8; red first: "tag must start with sdk-swift-v"; sdk-swift-v0.1.0-alpha.1
unchanged: the same split 94aa6ca, refs and messages; bash -n, shellcheck clean; the YAML parses)
Stops at: the plugin's split builds alone only once sdk-swift 0.1.0-alpha.2 is on orca-gateway-swift ("no versions
match 0.1.0-alpha.2..<1.0.0"); nothing pushed. A stand-in run (local bare repos, a scratch HOME) went to the end.
Changed: a PACKAGES table (tag prefix, directory, mirror, deploy key secret, library) with sdk-swift and the voice
recorder; publish takes its directory from the tag; verify builds a scratch package importing the plugin; the
workflow also runs on `orca_*-ios-v*`, a resolve job reads the table (`info <tag>`), publish queues per mirror and
runs on macos-15 for a plugin; the missing-secret error names the secret and docs/User_Actions.md · LICENSE is the
repo's BSL 1.1. Change c49a655: one queue per mirror. Rework e322111: runs-on from resolve's plugin output.
Review fit: pass · Review quality: publish read plugin-or-not from the tag prefix beside the table, fixed (e322111)
#### T12 · Maven plugin tags, package CI workflow (5643b9a)
Files: .github/workflows/sdk-kotlin-publish.yml · .github/workflows/native-plugins.yml (new)
Cases: P-maven, P-ci → green (check.rb 89 ok, red first 24 failed; both parse; the tag, version and Central steps run
locally with curl stubbed; `publishAndReleaseToMavenCentral --dry-run` lists only :orca-voice-recorder; the POM is
com.orcagateway:orca-voice-recorder:0.1.0-alpha.1 on com.orcagateway:sdk:0.1.0-alpha.1)
Changed: sdk-kotlin-publish.yml also runs on `orca_*-android-v*`: the tag gives the directory and artifacts, the
VERSION and Central checks and the upload take them, same four secrets; verify (maven-verify.sh) for sdk-kotlin tags
only · native-plugins.yml: on main and PRs touching plugins/*/ios, plugins/*/android, sdk-swift, sdk-kotlin or
itself; macos-15 on Xcode 16.4 (swift test, xcodebuild test on a simulator) and ubuntu with JDK 17 (./gradlew build);
two matrices, so a new plugin adds one entry to each.
Decisions: tags match ^orca_[a-z0-9_]+-android-v<semver> · the artifact is the plugin name with dashes
Review fit: pass · Review quality: pass

### Test run
Group 1, on feat/native-parity-s17-voice after T1-T4 and T16 (before T2's rework):
`cd cli && dart test` 38 pass · `dart analyze` no issues · `cd engine && bun test` 795 pass, 0 fail ·
`cd sdk && flutter test` 485 pass · `flutter analyze` no issues · `cd sdk-swift && swift build --build-tests &&
swift test` core 523, SwiftUI 433, 0 failures, 0 compiler warnings · `cd sdk-kotlin && ./gradlew build --continue`
core 535, sdk 586, 0 failures · `cd plugins/orca_voice_recorder/android && ./gradlew build --continue` BUILD
SUCCESSFUL (no tests yet) · `bun run schema/gen-widget-registry.ts` and `gen-native-capabilities.ts`: no diff.
After T2's rework (4dd5c78, kotlin_generator.dart only): `cd cli && dart test` 38 pass · `dart analyze` no issues;
the full and types-only Kotlin output for the voice and google_map yamls identical before and after (`diff -r`).

Group 2, after T5-T7: `cd cli && dart test` 40 pass · `dart analyze` no issues · `cd engine && bun test` 800 pass,
0 fail · `cd sdk && flutter test` 485 pass · `flutter analyze` no issues · sdk-swift core 523, SwiftUI 433, 0
failures, 0 compiler warnings · sdk-kotlin core 535, sdk 586 · `cd plugins/orca_voice_recorder/ios && swift build
--build-tests && swift test` 6 pass, 0 warnings · `xcodebuild test -scheme OrcaVoiceRecorder` on the iOS 18.5
simulator 5 pass, TEST SUCCEEDED · `cd plugins/orca_voice_recorder/android && ./gradlew build --continue` 7 pass ·
the generators leave no diff.
After T5's rework (b8d9adf, the test file only): the Swift package's swift test 6 pass, 0 warnings.

Group 3, after T8-T12, on feat/native-parity-s17-voice rebased onto origin/main 20611b2 (step 5; no conflict, no file
of this slice touched upstream; every commit id in this record is the rebased one): `cd cli && dart test` 40 pass · `dart analyze` no issues · `cd engine && bun test`
804 pass, 0 fail · `cd sdk && flutter test` 487 pass · `flutter analyze` no issues · sdk-swift core 548, SwiftUI 456,
0 failures, 0 compiler warnings; on the iOS 18.5 simulator 548 and 560, TEST SUCCEEDED · sdk-kotlin core 570, sdk 642
· `cd plugins/orca_voice_recorder/ios && swift build --build-tests && swift test` 24 pass, 0 warnings · `xcodebuild
test -scheme OrcaVoiceRecorder` on the iOS 18.5 simulator 23 pass, TEST SUCCEEDED · `cd plugins/orca_voice_recorder/
android && ./gradlew build --continue` 25 pass, lint clean · the generators leave no diff · every workflow parses ·
the mirror rehearsal (SC/s17/t11/rehearse.sh, parts A and B) 4 of 4, SwiftPM's fingerprint store unchanged.
After T8's second rework (a69aece, the test file only): the Swift package's swift test 24, xcodebuild test 23.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- The user, after the merge: create the empty public repository orca-gateway/orca-voice-recorder-swift, a deploy key
  with write access on it, and its private half as the Actions secret ORCA_VOICE_RECORDER_SWIFT_DEPLOY_KEY (T15
  writes the walkthrough: "Native parity step 17: the orca_voice_recorder Swift mirror").
- Release order: sdk-swift 0.1.0-alpha.2 (the plugin API; the plugin's Package.swift asks for it) and sdk-kotlin
  (its first Central release; the plugin's POM depends on it) first, each run green, then release.sh rows 11 and 12.
- The Xcode 16.4 compile (CI's pin) is proven only by CI: this machine has Xcode 27.2 (T8's `#if compiler(>=6.2)`).
- actionlint is not installed here: the workflows are YAML-parsed and their run steps rehearsed, not linted.
